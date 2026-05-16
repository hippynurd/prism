#!/usr/bin/env python3
"""
PRISM setup backend.

This service exposes truthful setup state and an allowlisted job runner for
first boot. Iris can request facts and trigger named jobs, but it cannot run
freeform shell commands.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import threading
import time
import uuid
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


HOST = "127.0.0.1"
PORT = 5000

STATE_DIR = Path(os.environ.get("PRISM_STATE_DIR", "/var/lib/prism"))
SETUP_COMPLETE_FILE = STATE_DIR / "setup-complete"
SETUP_STATE_FILE = STATE_DIR / "setup-state.json"
JOB_DIR = STATE_DIR / "jobs"
JOB_LOG_DIR = Path(os.environ.get("PRISM_JOB_LOG_DIR", "/var/log/prism-jobs"))
SCRIPT_DIR = Path(os.environ.get("PRISM_SETUP_JOB_SCRIPT_DIR", "/usr/local/lib/prism/setup-jobs"))

DEFAULT_MODEL = "llama3.2:1b"
MODEL_ALLOWLIST = {"llama3.2:1b", "llama3.2:3b", "llama3.1:8b"}
REDACTED = "[REDACTED]"
MAC_RE = re.compile(r"(?i)^(?:[0-9a-f]{2}:){5}[0-9a-f]{2}$")
UUID_RE = re.compile(r"(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
API_KEY_RE = re.compile(r"(?i)^(?:sk|pk|ghp|github_pat|xox[baprs])-?[a-z0-9_\\-]{16,}$")
SENSITIVE_KEY_RE = re.compile(
    r"(?i)(serial|mac|mac_address|wwn|uuid|by_id|password|passwd|token|cookie|private_key|api[_-]?key)"
)


ALLOWED_JOBS: dict[str, dict[str, str]] = {
    "probe_hardware": {
        "script": "probe_hardware.sh",
        "description": "Refresh PRISM setup hardware and runtime state.",
    },
    "install_model": {
        "script": "install_model.sh",
        "description": "Pull an allowed Ollama model for Iris.",
    },
    "install_nvidia_runtime": {
        "script": "install_nvidia_runtime.sh",
        "description": "Install Debian NVIDIA runtime packages when supported.",
    },
    "enable_gpu_for_iris": {
        "script": "enable_gpu_for_iris.sh",
        "description": "Verify NVIDIA runtime and restart Ollama for GPU use.",
    },
    "reload_nginx": {
        "script": "reload_nginx.sh",
        "description": "Validate and reload nginx.",
    },
    "install_vaultwarden": {
        "script": "install_vaultwarden.sh",
        "description": "Install and verify Vaultwarden.",
    },
    "mark_setup_complete": {
        "script": "mark_setup_complete.sh",
        "description": "Write the setup completion marker for firstboot handoff.",
    },
}

JOB_LOCK = threading.Lock()


def now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime())


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore").strip()
    except OSError:
        return ""


def run_capture(command: list[str], timeout: int = 20) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(command, capture_output=True, text=True, check=False, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return subprocess.CompletedProcess(command, 127, "", str(exc))


def detect_ram_mb() -> int:
    for line in read_text(Path("/proc/meminfo")).splitlines():
        if line.startswith("MemTotal:"):
            return int(int(line.split()[1]) / 1024)
    return 0


def detect_root_disk() -> str:
    source = run_capture(["findmnt", "-n", "-o", "SOURCE", "/"]).stdout.strip()
    if not source:
        return ""
    parent = run_capture(["lsblk", "-no", "PKNAME", source]).stdout.strip().splitlines()
    return parent[0] if parent else Path(source).name


def detect_extra_disks() -> list[dict[str, str]]:
    boot_disk = detect_root_disk()
    result = run_capture(["lsblk", "-J", "-d", "-o", "NAME,PATH,SIZE,MODEL,SERIAL,TYPE"])
    try:
        devices = json.loads(result.stdout).get("blockdevices", [])
    except json.JSONDecodeError:
        devices = []
    disks: list[dict[str, str]] = []
    for device in devices:
        if device.get("type") != "disk" or device.get("name") == boot_disk:
            continue
        disks.append(
            {
                "name": str(device.get("name") or ""),
                "path": str(device.get("path") or ""),
                "size": str(device.get("size") or ""),
                "model": str(device.get("model") or "").strip(),
                "serial": str(device.get("serial") or "").strip(),
            }
        )
    return disks


def detect_nics() -> list[dict[str, Any]]:
    sys_class_net = Path("/sys/class/net")
    nics: list[dict[str, Any]] = []
    for iface in sorted(sys_class_net.iterdir() if sys_class_net.exists() else []):
        if not iface.is_dir():
            continue
        name = iface.name
        if name == "lo":
            continue
        nics.append(
            {
                "name": name,
                "mac": read_text(iface / "address"),
                "operstate": read_text(iface / "operstate") or "unknown",
                "carrier": read_text(iface / "carrier") == "1",
            }
        )
    return nics


def pci_display_devices() -> list[dict[str, str]]:
    devices: list[dict[str, str]] = []
    if shutil.which("lspci"):
        output = run_capture(["lspci", "-mm"]).stdout.splitlines()
        for line in output:
            lower = line.lower()
            if "vga compatible controller" in lower or "3d controller" in lower or "display controller" in lower:
                devices.append({"source": "lspci", "description": line})
        return devices

    for device in Path("/sys/bus/pci/devices").glob("*"):
        pci_class = read_text(device / "class")
        if pci_class.startswith(("0x0300", "0x0301", "0x0302")):
            vendor = read_text(device / "vendor")
            dev = read_text(device / "device")
            devices.append({"source": "sysfs", "description": f"{device.name} vendor={vendor} device={dev}"})
    return devices


def detect_gpu_driver() -> str | None:
    if Path("/proc/driver/nvidia/version").exists():
        return "nvidia"
    modules = read_text(Path("/proc/modules"))
    if "nvidia " in modules or "nvidia_drm " in modules:
        return "nvidia"
    if "nouveau " in modules:
        return "nouveau"
    return None


def detect_ollama_models() -> set[str]:
    result = run_capture(["curl", "-fsS", "http://127.0.0.1:11434/api/tags"], timeout=20)
    if result.returncode != 0:
        return set()
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return set()
    names: set[str] = set()
    for item in payload.get("models", []):
        name = str(item.get("name") or item.get("model") or "")
        if name:
            names.add(name)
            names.add(name.split(":", 1)[0])
    return names


def detect_ollama_model_installed(model: str) -> bool:
    return model in detect_ollama_models()


def detect_ollama_gpu_ready() -> bool:
    if not shutil.which("nvidia-smi"):
        return False
    smi = run_capture(["nvidia-smi"], timeout=20)
    if smi.returncode != 0:
        return False
    if shutil.which("systemctl"):
        active = run_capture(["systemctl", "is-active", "ollama"], timeout=10)
        if active.returncode != 0:
            return False
    return True


def collect_state() -> dict[str, Any]:
    nics = detect_nics()
    gpu_devices = pci_display_devices()
    gpu_driver = detect_gpu_driver()
    gpu_usable = bool(gpu_driver == "nvidia" and shutil.which("nvidia-smi") and run_capture(["nvidia-smi"], timeout=20).returncode == 0)
    ram_mb = detect_ram_mb()
    recommended_model = choose_recommended_model(ram_mb)
    state = {
        "setup_complete": SETUP_COMPLETE_FILE.exists(),
        "total_ram_mb": ram_mb,
        "nics": nics,
        "nic_count": len(nics),
        "extra_disks": detect_extra_disks(),
        "gpu_present": bool(gpu_devices),
        "gpu_devices": gpu_devices,
        "gpu_usable": gpu_usable,
        "gpu_driver": gpu_driver,
        "ollama_model_installed": detect_ollama_model_installed(recommended_model),
        "ollama_gpu_ready": detect_ollama_gpu_ready(),
        "recommended_model": recommended_model,
        "allowed_jobs": public_allowed_jobs(),
        "last_probe_timestamp": now_iso(),
    }
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    SETUP_STATE_FILE.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    return state


def should_redact_value(key: str, value: Any) -> bool:
    if not isinstance(value, str):
        return False
    lower_key = key.lower()
    if lower_key == "address" and MAC_RE.match(value):
        return True
    if lower_key == "id" and (UUID_RE.match(value) or value.startswith("0x") or len(value) >= 16):
        return True
    return (
        MAC_RE.match(value) is not None
        or UUID_RE.match(value) is not None
        or "/dev/disk/by-id" in value
        or API_KEY_RE.match(value) is not None
        or "-----BEGIN " in value
    )


def sanitize_public_state(value: Any, key: str = "") -> Any:
    if isinstance(value, dict):
        sanitized: dict[str, Any] = {}
        for item_key, item_value in value.items():
            if SENSITIVE_KEY_RE.search(item_key) or should_redact_value(item_key, item_value):
                sanitized[item_key] = REDACTED
            else:
                sanitized[item_key] = sanitize_public_state(item_value, item_key)
        return sanitized
    if isinstance(value, list):
        return [sanitize_public_state(item, key) for item in value]
    if should_redact_value(key, value):
        return REDACTED
    return value


def collect_public_state() -> dict[str, Any]:
    return sanitize_public_state(collect_state())


def choose_recommended_model(ram_mb: int) -> str:
    if ram_mb >= 28000:
        return "llama3.1:8b"
    if ram_mb >= 12000:
        return "llama3.2:3b"
    return "llama3.2:1b"


def public_allowed_jobs() -> list[dict[str, str]]:
    return [{"name": name, "description": meta["description"]} for name, meta in ALLOWED_JOBS.items()]


def job_metadata_path(job_id: str) -> Path:
    return JOB_DIR / f"{job_id}.json"


def load_job(job_id: str) -> dict[str, Any] | None:
    path = job_metadata_path(job_id)
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def write_job(metadata: dict[str, Any]) -> None:
    JOB_DIR.mkdir(parents=True, exist_ok=True)
    tmp = job_metadata_path(metadata["job_id"]).with_suffix(".json.tmp")
    tmp.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    tmp.replace(job_metadata_path(metadata["job_id"]))


def job_receipt(metadata: dict[str, Any]) -> dict[str, Any]:
    return {
        "job_id": metadata["job_id"],
        "job_name": metadata["job_name"],
        "status": metadata["status"],
        "created_at": metadata["created_at"],
        "started_at": metadata.get("started_at"),
        "finished_at": metadata.get("finished_at"),
        "exit_code": metadata.get("exit_code"),
        "log_path": metadata["log_path"],
        "metadata_path": str(job_metadata_path(metadata["job_id"])),
        "error": metadata.get("error"),
    }


def validate_job_payload(job_name: str, payload: dict[str, Any]) -> dict[str, str]:
    env: dict[str, str] = {}
    if job_name == "install_model":
        model = str(payload.get("model") or DEFAULT_MODEL)
        if model not in MODEL_ALLOWLIST:
            raise ValueError(f"model is not allowlisted: {model}")
        env["PRISM_MODEL"] = model
    return env


def run_job(job_id: str, env_overrides: dict[str, str]) -> None:
    metadata = load_job(job_id)
    if metadata is None:
        return

    script = SCRIPT_DIR / ALLOWED_JOBS[metadata["job_name"]]["script"]
    metadata["started_at"] = now_iso()
    metadata["status"] = "running"
    write_job(metadata)

    env = os.environ.copy()
    env.update(env_overrides)
    env["PRISM_JOB_ID"] = job_id
    env["PRISM_JOB_NAME"] = metadata["job_name"]
    env["PRISM_JOB_LOG"] = metadata["log_path"]
    env["PRISM_STATE_FILE"] = str(SETUP_STATE_FILE)
    env["PRISM_SETUP_COMPLETE_FILE"] = str(SETUP_COMPLETE_FILE)

    with open(metadata["log_path"], "ab", buffering=0) as log:
        log.write(f"[{now_iso()}] starting {metadata['job_name']} as {job_id}\n".encode("utf-8"))
        if not script.exists() or not os.access(script, os.X_OK):
            message = f"job script missing or not executable: {script}\n"
            log.write(message.encode("utf-8"))
            metadata["status"] = "failed"
            metadata["exit_code"] = 127
            metadata["error"] = message.strip()
            metadata["finished_at"] = now_iso()
            write_job(metadata)
            return

        process = subprocess.Popen([str(script)], stdout=log, stderr=subprocess.STDOUT, env=env)
        exit_code = process.wait()
        metadata["exit_code"] = exit_code
        metadata["finished_at"] = now_iso()
        metadata["status"] = "succeeded" if exit_code == 0 else "failed"
        if exit_code != 0:
            metadata["error"] = f"{metadata['job_name']} exited {exit_code}"
        write_job(metadata)
        if exit_code == 0:
            collect_state()
        log.write(f"[{now_iso()}] finished {metadata['job_name']} exit_code={exit_code}\n".encode("utf-8"))


def start_job(job_name: str, payload: dict[str, Any]) -> dict[str, Any]:
    if job_name not in ALLOWED_JOBS:
        raise KeyError(job_name)
    env_overrides = validate_job_payload(job_name, payload)

    JOB_DIR.mkdir(parents=True, exist_ok=True)
    JOB_LOG_DIR.mkdir(parents=True, exist_ok=True)
    job_id = f"{int(time.time())}-{uuid.uuid4().hex[:12]}"
    metadata = {
        "job_id": job_id,
        "job_name": job_name,
        "status": "queued",
        "created_at": now_iso(),
        "started_at": None,
        "finished_at": None,
        "exit_code": None,
        "log_path": str(JOB_LOG_DIR / f"{job_id}-{job_name}.log"),
        "request": {k: v for k, v in payload.items() if k in {"model"}},
    }
    write_job(metadata)

    thread = threading.Thread(target=run_job, args=(job_id, env_overrides), daemon=True)
    thread.start()
    return job_receipt(metadata)


class Handler(BaseHTTPRequestHandler):
    server_version = "PrismSetupBackend/0.2"

    def _json(self, payload: Any, status: int = HTTPStatus.OK) -> None:
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        if not raw:
            return {}
        return json.loads(raw.decode("utf-8"))

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path.rstrip("/") or "/"

        if path in {"/setup/public-state", "/public-state"}:
            self._json(collect_public_state())
            return

        if path in {"/state", "/setup/state", "/hardware", "/setup/hardware"}:
            self._json(collect_state())
            return

        if path in {"/jobs", "/setup/jobs"}:
            self._json({"allowed_jobs": public_allowed_jobs()})
            return

        for prefix in ("/jobs/", "/setup/jobs/"):
            if path.startswith(prefix):
                job_id = path[len(prefix) :]
                metadata = load_job(job_id)
                if metadata is None:
                    self._json({"error": "job not found"}, status=HTTPStatus.NOT_FOUND)
                    return
                self._json(job_receipt(metadata))
                return

        self._json({"error": "not found"}, status=HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path.rstrip("/") or "/"
        payload = self._read_json()

        for prefix in ("/jobs/", "/setup/jobs/"):
            if path.startswith(prefix):
                job_name = path[len(prefix) :]
                with JOB_LOCK:
                    try:
                        receipt = start_job(job_name, payload)
                    except KeyError:
                        self._json({"error": "job not allowlisted", "allowed_jobs": public_allowed_jobs()}, status=HTTPStatus.NOT_FOUND)
                        return
                    except ValueError as exc:
                        self._json({"error": str(exc)}, status=HTTPStatus.BAD_REQUEST)
                        return
                self._json(receipt, status=HTTPStatus.ACCEPTED)
                return

        self._json({"error": "not found"}, status=HTTPStatus.NOT_FOUND)

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"[prism-setup-backend] {fmt % args}")


def main() -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    JOB_DIR.mkdir(parents=True, exist_ok=True)
    JOB_LOG_DIR.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"[prism-setup-backend] listening on http://{HOST}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()

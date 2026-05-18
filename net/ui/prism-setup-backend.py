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
import tempfile
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
CHECK_INSTALL_READINESS_SCRIPT = SCRIPT_DIR / "check_install_readiness.sh"
DIAGNOSE_INSTALL_BLOCKERS_SCRIPT = SCRIPT_DIR / "diagnose_install_blockers.sh"
CHECK_AI_RUNNER_READINESS_SCRIPT = SCRIPT_DIR / "check_ai_runner_readiness.sh"
ANALYZE_CAPABILITIES_SCRIPT = SCRIPT_DIR / "analyze_capabilities.sh"

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
    "check_prism_status": {
        "script": "check_prism_status.sh",
        "description": "Return a read-only sanitized PRISM status snapshot.",
    },
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
ALLOWED_CAPABILITY_GOALS = {
    "privacy",
    "passwords",
    "ad_blocking",
    "private_search",
    "files_backups",
    "local_ai",
    "coding_helpers",
    "image_generation",
    "media_music",
    "home_automation",
    "router_firewall_lab",
    "kiosk_factory",
    "not_sure",
}
CAPABILITY_GOAL_ALIASES = {
    "ad blocking": "ad_blocking",
    "private search": "private_search",
    "files": "files_backups",
    "backups": "files_backups",
    "files/backups": "files_backups",
    "local ai": "local_ai",
    "coding_helper_agents": "coding_helpers",
    "coding helpers": "coding_helpers",
    "helper_agents": "coding_helpers",
    "image generation": "image_generation",
    "media/music": "media_music",
    "home automation": "home_automation",
    "router/firewall/lab": "router_firewall_lab",
    "kiosk/factory": "kiosk_factory",
    "kiosk_factory_workflows": "kiosk_factory",
    "i'm not sure": "not_sure",
    "im not sure": "not_sure",
    "not sure": "not_sure",
}


def now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime())


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore").strip()
    except OSError:
        return ""


def run_capture(command: list[str], timeout: int = 20, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(command, capture_output=True, text=True, check=False, timeout=timeout, env=env)
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
            sensitive_key = SENSITIVE_KEY_RE.search(item_key) and not isinstance(item_value, (bool, dict, list))
            if sensitive_key or should_redact_value(item_key, item_value):
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


def job_result_path(job_id: str) -> Path:
    return JOB_DIR / f"{job_id}.result.json"


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
    receipt = {
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
    result_path = Path(str(metadata.get("result_path") or ""))
    if result_path.exists():
        try:
            result = json.loads(result_path.read_text(encoding="utf-8"))
            receipt["result"] = sanitize_public_state(result)
        except json.JSONDecodeError:
            receipt["result_error"] = "job result is not valid JSON"
    return receipt


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
    env["PRISM_JOB_RESULT"] = metadata["result_path"]
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
        if exit_code == 0 and metadata["job_name"] != "check_prism_status":
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
        "result_path": str(job_result_path(job_id)),
        "request": {k: v for k, v in payload.items() if k in {"model"}},
    }
    write_job(metadata)

    thread = threading.Thread(target=run_job, args=(job_id, env_overrides), daemon=True)
    thread.start()
    return job_receipt(metadata)


def run_public_check_prism_status(timeout_seconds: float = 20.0) -> dict[str, Any]:
    receipt = start_job("check_prism_status", {})
    job_id = str(receipt["job_id"])
    deadline = time.time() + timeout_seconds
    metadata = load_job(job_id)

    while time.time() < deadline:
        metadata = load_job(job_id)
        if metadata and metadata.get("status") in {"succeeded", "failed"}:
            break
        time.sleep(0.25)

    if metadata is None:
        return {
            "job_name": "check_prism_status",
            "status": "failed",
            "read_only": True,
            "summary": "Backend could not load check_prism_status job metadata.",
            "changed_files": [],
            "changed_services": [],
            "rollback_hint": "No changes made; read-only job.",
        }

    receipt = job_receipt(metadata)
    result = receipt.get("result")
    if isinstance(result, dict):
        result["backend_job"] = {
            "job_id": receipt["job_id"],
            "status": receipt["status"],
            "started_at": receipt.get("started_at"),
            "finished_at": receipt.get("finished_at"),
            "exit_code": receipt.get("exit_code"),
        }
        return sanitize_public_state(result)

    return sanitize_public_state(
        {
            "job_name": "check_prism_status",
            "status": receipt["status"],
            "read_only": True,
            "summary": "check_prism_status did not return a structured result before the timeout.",
            "backend_job": {
                "job_id": receipt["job_id"],
                "status": receipt["status"],
                "started_at": receipt.get("started_at"),
                "finished_at": receipt.get("finished_at"),
                "exit_code": receipt.get("exit_code"),
                "error": receipt.get("error"),
            },
            "changed_files": [],
            "changed_services": [],
            "rollback_hint": "No changes made; read-only job.",
        }
    )


def run_public_check_install_readiness(timeout_seconds: int = 30) -> dict[str, Any]:
    if not CHECK_INSTALL_READINESS_SCRIPT.exists() or not os.access(CHECK_INSTALL_READINESS_SCRIPT, os.X_OK):
        return {
            "endpoint": "check-install-readiness",
            "job_name": "check_install_readiness",
            "status": "failed",
            "read_only": True,
            "changed_files": [],
            "changed_services": [],
            "overall": "blocked",
            "summary": "Install readiness check script is unavailable.",
            "checks": {},
            "service_readiness": {
                "adguard": {"status": "unknown", "reasons": ["readiness check script is unavailable"]},
                "vaultwarden": {"status": "unknown", "reasons": ["readiness check script is unavailable"]},
                "searxng": {"status": "unknown", "reasons": ["readiness check script is unavailable"]},
            },
            "next_step": "No install was performed. Restore the read-only readiness check before continuing.",
            "rollback_hint": "No changes made; read-only check.",
        }

    with tempfile.TemporaryDirectory(prefix="prism-install-readiness-") as tmpdir:
        result_path = Path(tmpdir) / "result.json"
        env = os.environ.copy()
        env["PRISM_JOB_RESULT"] = str(result_path)
        process = run_capture([str(CHECK_INSTALL_READINESS_SCRIPT)], timeout=timeout_seconds, env=env)
        if process.returncode == 0:
            try:
                result = json.loads(result_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                result = None
            if isinstance(result, dict):
                return sanitize_public_state(result)

        return sanitize_public_state(
            {
                "endpoint": "check-install-readiness",
                "job_name": "check_install_readiness",
                "status": "failed",
                "read_only": True,
                "changed_files": [],
                "changed_services": [],
                "overall": "blocked",
                "summary": "Install readiness check failed or did not return structured JSON.",
                "checks": {},
                "service_readiness": {
                    "adguard": {"status": "unknown", "reasons": ["readiness check failed"]},
                    "vaultwarden": {"status": "unknown", "reasons": ["readiness check failed"]},
                    "searxng": {"status": "unknown", "reasons": ["readiness check failed"]},
                },
                "error": process.stderr.strip() or process.stdout.strip() or f"exit {process.returncode}",
                "next_step": "No install was performed. Iris should report that readiness is unavailable.",
                "rollback_hint": "No changes made; read-only check.",
            }
        )


def run_public_diagnose_install_blockers(payload: dict[str, Any] | None = None, timeout_seconds: int = 30) -> dict[str, Any]:
    payload = payload or {}
    service = str(payload.get("service") or "all").strip().lower()
    if service not in {"adguard", "vaultwarden", "searxng", "all"}:
        service = "all"

    if not DIAGNOSE_INSTALL_BLOCKERS_SCRIPT.exists() or not os.access(DIAGNOSE_INSTALL_BLOCKERS_SCRIPT, os.X_OK):
        return {
            "endpoint": "diagnose-install-blockers",
            "job_name": "diagnose_install_blockers",
            "status": "failed",
            "read_only": True,
            "changed_files": [],
            "changed_services": [],
            "service": service,
            "overall": "unknown",
            "summary": "Blocker diagnosis script is unavailable.",
            "blockers": [],
            "safe_next_steps": ["Restore the read-only blocker diagnosis script before continuing."],
            "checks": {},
            "rollback_hint": "No changes made; read-only diagnosis.",
        }

    with tempfile.TemporaryDirectory(prefix="prism-blocker-diagnosis-") as tmpdir:
        result_path = Path(tmpdir) / "result.json"
        env = os.environ.copy()
        env["PRISM_JOB_RESULT"] = str(result_path)
        env["PRISM_BLOCKER_SERVICE"] = service
        process = run_capture([str(DIAGNOSE_INSTALL_BLOCKERS_SCRIPT)], timeout=timeout_seconds, env=env)
        if process.returncode == 0:
            try:
                result = json.loads(result_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                result = None
            if isinstance(result, dict):
                return sanitize_public_state(result)

        return sanitize_public_state(
            {
                "endpoint": "diagnose-install-blockers",
                "job_name": "diagnose_install_blockers",
                "status": "failed",
                "read_only": True,
                "changed_files": [],
                "changed_services": [],
                "service": service,
                "overall": "unknown",
                "summary": "Blocker diagnosis failed or did not return structured JSON.",
                "blockers": [],
                "safe_next_steps": ["Tell the user the blocker diagnosis failed or was unavailable."],
                "error": process.stderr.strip() or process.stdout.strip() or f"exit {process.returncode}",
                "rollback_hint": "No changes made; read-only diagnosis.",
            }
        )


def run_public_check_ai_runner_readiness(timeout_seconds: int = 30) -> dict[str, Any]:
    if not CHECK_AI_RUNNER_READINESS_SCRIPT.exists() or not os.access(CHECK_AI_RUNNER_READINESS_SCRIPT, os.X_OK):
        return {
            "endpoint": "check-ai-runner-readiness",
            "job_name": "check_ai_runner_readiness",
            "status": "failed",
            "read_only": True,
            "changed_files": [],
            "changed_services": [],
            "overall": "unknown",
            "summary": "AI runner readiness script is unavailable.",
            "gpu_devices": [],
            "model_runtime": {"ollama_active": False, "installed_models": [], "recommended_model": "unknown"},
            "assignments": {
                "iris_gpu": "unknown",
                "agent_gpu": "unknown",
                "assignment_verified": False,
                "iris_gpu_config_path": "/etc/prism/iris-gpu",
                "agent_gpu_config_path": "/etc/prism/agent-gpu",
            },
            "recommended_roles": ["local Iris assistant", "helper LLM", "coding/log/script runner"],
            "warnings": ["AI runner readiness script is unavailable."],
            "safe_next_steps": ["Restore the read-only AI runner readiness script before continuing."],
            "rollback_hint": "No changes made; read-only check.",
        }

    with tempfile.TemporaryDirectory(prefix="prism-ai-runner-readiness-") as tmpdir:
        result_path = Path(tmpdir) / "result.json"
        env = os.environ.copy()
        env["PRISM_JOB_RESULT"] = str(result_path)
        process = run_capture([str(CHECK_AI_RUNNER_READINESS_SCRIPT)], timeout=timeout_seconds, env=env)
        if process.returncode == 0:
            try:
                result = json.loads(result_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                result = None
            if isinstance(result, dict):
                return sanitize_public_state(result)

        return sanitize_public_state(
            {
                "endpoint": "check-ai-runner-readiness",
                "job_name": "check_ai_runner_readiness",
                "status": "failed",
                "read_only": True,
                "changed_files": [],
                "changed_services": [],
                "overall": "unknown",
                "summary": "AI runner readiness check failed or did not return structured JSON.",
                "gpu_devices": [],
                "model_runtime": {"ollama_active": False, "installed_models": [], "recommended_model": "unknown"},
                "assignments": {
                    "iris_gpu": "unknown",
                    "agent_gpu": "unknown",
                    "assignment_verified": False,
                    "iris_gpu_config_path": "/etc/prism/iris-gpu",
                    "agent_gpu_config_path": "/etc/prism/agent-gpu",
                },
                "recommended_roles": ["local Iris assistant", "helper LLM", "coding/log/script runner"],
                "warnings": ["AI runner readiness check failed."],
                "safe_next_steps": ["Tell the user the AI runner readiness check failed or was unavailable."],
                "error": process.stderr.strip() or process.stdout.strip() or f"exit {process.returncode}",
                "rollback_hint": "No changes made; read-only check.",
            }
        )


def normalize_capability_goals(payload: dict[str, Any] | None) -> list[str]:
    raw_goals = (payload or {}).get("goals", [])
    if isinstance(raw_goals, str):
        raw_goals = [raw_goals]
    if not isinstance(raw_goals, list):
        raw_goals = []

    goals: list[str] = []
    for item in raw_goals:
        key = str(item or "").strip().lower().replace("-", "_")
        key = CAPABILITY_GOAL_ALIASES.get(key, key)
        key = key.replace(" ", "_")
        if key in ALLOWED_CAPABILITY_GOALS and key not in goals:
            goals.append(key)
    return goals


def parse_size_to_gb(value: Any) -> float:
    if isinstance(value, (int, float)):
        return round(float(value) / (1024**3), 2) if float(value) > 1000000 else float(value)
    text = str(value or "").strip().upper().replace(" ", "")
    if not text:
        return 0.0
    match = re.match(r"^([0-9]+(?:\.[0-9]+)?)([KMGTPE]?)(?:I?B)?$", text)
    if not match:
        return 0.0
    amount = float(match.group(1))
    unit = match.group(2)
    multipliers = {"": 1 / (1024**3), "K": 1 / (1024**2), "M": 1 / 1024, "G": 1, "T": 1024, "P": 1024 * 1024, "E": 1024 * 1024 * 1024}
    return round(amount * multipliers.get(unit, 0), 2)


def tier_value(recommended: bool = False, possible: bool = False, not_recommended: bool = False) -> str:
    if recommended:
        return "recommended"
    if possible:
        return "possible"
    if not_recommended:
        return "not_recommended"
    return "unknown"


def append_unique(items: list[Any], item: Any) -> None:
    if item not in items:
        items.append(item)


def service_recommendation(
    service_id: str,
    label: str,
    fit: str,
    why: str,
    requires: list[str] | None = None,
    blocked_by: list[str] | None = None,
    risk: str = "low",
) -> dict[str, Any]:
    return {
        "id": service_id,
        "label": label,
        "fit": fit,
        "why": why,
        "requires": requires or [],
        "blocked_by": blocked_by or [],
        "risk": risk,
        "installable_now": False,
        "read_only_recommendation": True,
    }


def extract_blocker_summaries(blocker_result: dict[str, Any]) -> list[str]:
    blockers: list[str] = []
    for item in blocker_result.get("blockers", []) if isinstance(blocker_result.get("blockers"), list) else []:
        if isinstance(item, dict):
            summary = str(item.get("summary") or item.get("message") or item.get("type") or "").strip()
            service = str(item.get("service") or "").strip()
            if summary and service:
                append_unique(blockers, f"{service}: {summary}")
            elif summary:
                append_unique(blockers, summary)
        elif item:
            append_unique(blockers, str(item))

    service_readiness = blocker_result.get("service_readiness")
    if isinstance(service_readiness, dict):
        for service, details in service_readiness.items():
            if not isinstance(details, dict):
                continue
            status = str(details.get("status") or "").lower()
            reasons = details.get("reasons") if isinstance(details.get("reasons"), list) else []
            if status in {"blocked", "warning"}:
                reason_text = "; ".join(str(reason) for reason in reasons if reason)
                append_unique(blockers, f"{service}: {reason_text or status}")
    return blockers


def analyze_capabilities(payload: dict[str, Any] | None = None) -> dict[str, Any]:
    goals = normalize_capability_goals(payload)
    state = collect_public_state()
    status_result = run_public_check_prism_status()
    readiness = run_public_check_install_readiness()
    ai_readiness = run_public_check_ai_runner_readiness()

    readiness_overall = str(readiness.get("overall") or readiness.get("status") or "unknown").lower()
    blocker_result: dict[str, Any] = {}
    if readiness_overall in {"warning", "blocked", "limited", "failed", "unknown"}:
        blocker_result = run_public_diagnose_install_blockers({})

    ram_mb = int(state.get("total_ram_mb") or 0)
    ram_gb = round(ram_mb / 1024, 1) if ram_mb else 0
    extra_disks = state.get("extra_disks") if isinstance(state.get("extra_disks"), list) else []
    extra_storage_gb = sum(parse_size_to_gb(disk.get("size")) for disk in extra_disks if isinstance(disk, dict))
    nics = state.get("nics") if isinstance(state.get("nics"), list) else []
    nic_count = int(state.get("nic_count") or len(nics))
    gpu_devices = state.get("gpu_devices") if isinstance(state.get("gpu_devices"), list) else []
    ai_gpu_devices = ai_readiness.get("gpu_devices") if isinstance(ai_readiness.get("gpu_devices"), list) else []
    gpu_count = max(len(gpu_devices), len(ai_gpu_devices))
    gpu_present = bool(state.get("gpu_present") or gpu_count)
    gpu_usable = bool(state.get("gpu_usable") or state.get("ollama_gpu_ready") or ai_readiness.get("overall") in {"ready", "warning"})
    gpu_driver = str(state.get("gpu_driver") or "").lower()
    ollama_gpu_ready = bool(state.get("ollama_gpu_ready"))

    ram_tier = "unknown"
    if ram_mb:
        if ram_mb >= 64000:
            ram_tier = "very_high"
        elif ram_mb >= 28000:
            ram_tier = "high"
        elif ram_mb >= 12000:
            ram_tier = "medium"
        else:
            ram_tier = "low"

    storage_tier = "unknown"
    if extra_storage_gb >= 2000:
        storage_tier = "storage_heavy"
    elif extra_storage_gb >= 500:
        storage_tier = "good_extra_storage"
    elif extra_disks:
        storage_tier = "some_extra_storage"
    else:
        storage_tier = "boot_disk_only_or_unknown"

    gpu_tier = "none_verified"
    if gpu_count >= 2 and gpu_usable:
        gpu_tier = "multi_gpu_ready"
    elif gpu_count >= 2:
        gpu_tier = "multi_gpu_present"
    elif gpu_count == 1 and gpu_usable:
        gpu_tier = "single_gpu_ready"
    elif gpu_count == 1 or gpu_present:
        gpu_tier = "gpu_present_unverified"

    network_tier = "unknown"
    if nic_count >= 2:
        network_tier = "multi_nic"
    elif nic_count == 1:
        network_tier = "single_nic"

    hardware_unknowns: list[str] = []
    if not ram_mb:
        hardware_unknowns.append("RAM amount was not reported.")
    if storage_tier == "boot_disk_only_or_unknown":
        hardware_unknowns.append("Only extra disk inventory is available; total disk layout is not fully described.")
    if gpu_tier in {"none_verified", "gpu_present_unverified", "multi_gpu_present"}:
        hardware_unknowns.append("GPU assignment or usability is not fully verified.")
    if network_tier == "unknown":
        hardware_unknowns.append("Network interface count is unknown.")
    hardware_unknowns.append("Wi-Fi and Bluetooth capability are not verified by this planner.")

    blockers = extract_blocker_summaries(readiness) + extract_blocker_summaries(blocker_result)
    if "adguard" in json.dumps(readiness).lower() and "port 53" in json.dumps(readiness).lower():
        append_unique(blockers, "AdGuard may be blocked because port 53 is in use.")
    if "port 53" in json.dumps(blocker_result).lower():
        append_unique(blockers, "AdGuard may be blocked because port 53 is in use.")

    recommended_roles: list[str] = []
    if ram_mb >= 28000 and gpu_count >= 2:
        recommended_roles.extend(["PRISM dev server", "local AI/helper runner", "coding/helper agent host", "factory/control-plane candidate"])
    elif ram_mb >= 12000 and gpu_present:
        recommended_roles.extend(["local AI/helper runner", "privacy services host"])
    elif extra_storage_gb >= 500:
        recommended_roles.extend(["files/backups host", "privacy services host"])
    else:
        recommended_roles.extend(["privacy basics host", "lightweight PRISM services host"])
    if nic_count >= 2:
        append_unique(recommended_roles, "router/firewall lab candidate")
    append_unique(recommended_roles, "Iris operator assistant host")

    capability_tiers = {
        "privacy_basics": tier_value(recommended=True),
        "local_ai": tier_value(recommended=(gpu_usable and ram_mb >= 28000), possible=(gpu_present or ram_mb >= 12000), not_recommended=(ram_mb and ram_mb < 12000 and not gpu_present)),
        "files_backups": tier_value(recommended=extra_storage_gb >= 500, possible=bool(extra_disks) or ram_mb >= 12000),
        "kiosk_factory": tier_value(recommended=(ram_mb >= 12000 and nic_count >= 1), possible=ram_mb > 0),
    }

    recommended_services = [
        service_recommendation("private_search", "Private search", "recommended", "Good privacy-first service once basic networking is ready."),
        service_recommendation("vaultwarden", "Password manager", "recommended", "Useful early PRISM service for user-controlled passwords and secrets."),
    ]
    possible_services = [
        service_recommendation("adguard_home", "Ad blocking DNS", "possible", "Useful privacy basic, but DNS port ownership must be confirmed.", ["available port 53 or a planned DNS handoff"], ["port 53 in use"] if any("port 53" in item.lower() for item in blockers) else []),
        service_recommendation("home_automation", "Home automation", "possible", "A good fit when the user wants local device coordination."),
    ]
    not_recommended_services: list[dict[str, Any]] = []

    if capability_tiers["files_backups"] == "recommended":
        recommended_services.append(service_recommendation("files_backups", "Files and backups", "recommended", "Extra storage makes this machine a good candidate for files, backups, media, or archives."))
    else:
        possible_services.append(service_recommendation("files_backups", "Files and backups", "possible", "May be useful, but extra storage is limited or not verified."))

    if capability_tiers["local_ai"] == "recommended":
        recommended_services.append(service_recommendation("local_ai_runner", "Local AI/helper runner", "recommended", "RAM and GPU signals make this a strong candidate for helper models and coding agents."))
        possible_services.append(service_recommendation("image_generation", "Image generation", "possible", "One possible GPU workload if the user wants it; GPU assignment still needs explicit planning.", ["verified GPU readiness"], []))
    elif capability_tiers["local_ai"] == "possible":
        possible_services.append(service_recommendation("local_ai_runner", "Local AI/helper runner", "possible", "Some AI signals are present, but GPU assignment or capacity is not fully verified."))
        possible_services.append(service_recommendation("image_generation", "Image generation", "possible", "Only consider this after GPU readiness and VRAM are verified."))
    else:
        not_recommended_services.append(service_recommendation("image_generation", "Image generation", "not_recommended", "No usable GPU was verified for image generation.", ["verified GPU"], []))

    if nic_count < 2:
        not_recommended_services.append(service_recommendation("router_firewall_lab", "Router/firewall lab", "not_recommended", "A router/firewall role usually needs verified network interface planning.", ["verified network interfaces"], []))
    else:
        possible_services.append(service_recommendation("router_firewall_lab", "Router/firewall lab", "possible", "Multiple NICs make lab routing possible, but this needs explicit network planning."))

    if "not_sure" in goals or not goals:
        questions = [
            "What matters most first: privacy basics, files/backups, local AI, coding helpers, media/music, home automation, router/lab work, or kiosk/factory workflows?",
        ]
    else:
        questions = ["Should Iris prioritize these goals first: " + ", ".join(goals) + "?"]
    if gpu_present and not ollama_gpu_ready:
        questions.append("Should GPU setup remain advisory until you explicitly choose a local AI goal?")

    hardware_upgrade_suggestions: list[str] = []
    if ram_mb and ram_mb < 12000:
        hardware_upgrade_suggestions.append("More RAM would improve local AI and multi-service use.")
    if not gpu_present and any(goal in goals for goal in ("local_ai", "coding_helpers", "image_generation")):
        hardware_upgrade_suggestions.append("A supported GPU would help local AI, coding helper models, and optional image generation.")
    if not extra_disks and any(goal in goals for goal in ("files_backups", "media_music")):
        hardware_upgrade_suggestions.append("Additional storage would make files, backups, and media workflows safer.")
    if nic_count < 2 and "router_firewall_lab" in goals:
        hardware_upgrade_suggestions.append("A second verified network interface would make router/firewall lab work more realistic.")

    overall = "unknown"
    if readiness_overall in {"blocked", "failed"} or blockers:
        overall = "warning"
    elif ram_mb or gpu_present or extra_disks:
        overall = "ready"
    elif ram_mb and ram_mb < 12000:
        overall = "limited"

    summary_parts = []
    if ram_mb:
        summary_parts.append(f"{ram_gb}GB RAM")
    if extra_storage_gb:
        summary_parts.append(f"about {round(extra_storage_gb / 1024, 1)}TB extra storage")
    if gpu_count >= 2:
        summary_parts.append(f"{gpu_count} GPU devices reported")
    elif gpu_present:
        summary_parts.append("GPU present")
    if not summary_parts:
        summary_parts.append("limited verified hardware detail")
    summary = "This machine reports " + ", ".join(summary_parts) + ". "
    if gpu_count >= 2 and ram_mb >= 28000:
        summary += "It is a good candidate for PRISM dev/local AI/helper runner work, with image generation only as an optional GPU use."
    elif extra_storage_gb >= 500:
        summary += "It is a good candidate for privacy basics plus files/backups."
    else:
        summary += "It is best treated as a privacy-basics or lightweight PRISM host until more capability is verified."
    if blockers:
        summary += " Some readiness blockers or warnings need attention before install planning."

    confidence = "high" if ram_mb and (gpu_present or extra_disks) else "medium" if ram_mb else "low"
    if hardware_unknowns:
        confidence = "medium" if confidence == "high" else confidence

    next_safe_action = "Ask the user which goals matter most, then explain a read-only recommended plan. Do not start installs."
    if blockers:
        next_safe_action = "Explain the blockers and ask which goal to plan around first. Do not start installs."

    response = {
        "endpoint": "analyze-capabilities",
        "read_only": True,
        "changed_files": [],
        "changed_services": [],
        "overall": overall,
        "summary": summary,
        "hardware_summary": {
            "ram_tier": ram_tier,
            "storage_tier": storage_tier,
            "gpu_tier": gpu_tier,
            "network_tier": network_tier,
            "unknowns": hardware_unknowns,
        },
        "capability_tiers": capability_tiers,
        "recommended_roles": recommended_roles,
        "recommended_services": recommended_services,
        "possible_services": possible_services,
        "not_recommended_services": not_recommended_services,
        "blockers": blockers,
        "questions_for_user": questions,
        "hardware_upgrade_suggestions": hardware_upgrade_suggestions,
        "next_safe_action": next_safe_action,
        "confidence": confidence,
        "inputs": {
            "goals": goals,
            "status_overall": status_result.get("status") or status_result.get("overall") or "unknown",
            "readiness_overall": readiness.get("overall") or "unknown",
            "ai_runner_overall": ai_readiness.get("overall") or "unknown",
            "blocker_diagnosis_included": bool(blocker_result),
        },
    }
    return sanitize_public_state(response)


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

        if path == "/setup/check-prism-status":
            self._json(run_public_check_prism_status())
            return

        if path == "/setup/check-install-readiness":
            self._json(run_public_check_install_readiness())
            return

        if path == "/setup/diagnose-install-blockers":
            self._json(run_public_diagnose_install_blockers(payload))
            return

        if path == "/setup/check-ai-runner-readiness":
            self._json(run_public_check_ai_runner_readiness())
            return

        if path == "/setup/analyze-capabilities":
            self._json(analyze_capabilities(payload))
            return

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

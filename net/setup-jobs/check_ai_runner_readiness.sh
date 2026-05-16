#!/usr/bin/env bash
set -euo pipefail

result_path="${PRISM_JOB_RESULT:-}"
if [[ -z "$result_path" ]]; then
  echo "PRISM_JOB_RESULT is required" >&2
  exit 2
fi

tmp_result="${result_path}.tmp"

python3 - "$tmp_result" <<'PY'
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


REDACTED = "[REDACTED]"
MAC_RE = re.compile(r"(?i)(?:[0-9a-f]{2}:){5}[0-9a-f]{2}")
UUID_RE = re.compile(r"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b")
API_KEY_RE = re.compile(r"(?i)\b(?:sk|pk|ghp|github_pat|xox[baprs])-?[a-z0-9_\-]{16,}\b")
SENSITIVE_KEY_RE = re.compile(
    r"(?i)(serial|mac|mac_address|wwn|uuid|by_id|password|passwd|token|cookie|private_key|api[_-]?key)"
)

STATE_FILE = Path("/var/lib/prism/setup-state.json")
AGENT_GPU_FILE = Path("/etc/prism/agent-gpu")
IRIS_GPU_FILE = Path("/etc/prism/iris-gpu")
OLLAMA_DROPIN_FILE = Path("/etc/systemd/system/ollama.service.d/prism-gpu.conf")


def run(command: list[str], timeout: int = 10) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(command, capture_output=True, text=True, check=False, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return subprocess.CompletedProcess(command, 127, "", str(exc))


def redact_text(value: str) -> str:
    value = MAC_RE.sub(REDACTED, value)
    value = UUID_RE.sub(REDACTED, value)
    value = API_KEY_RE.sub(REDACTED, value)
    value = value.replace("/dev/disk/by-id", REDACTED)
    if "-----BEGIN " in value:
        return REDACTED
    return value


def sanitize(value: Any, key: str = "") -> Any:
    if isinstance(value, dict):
        cleaned: dict[str, Any] = {}
        for item_key, item_value in value.items():
            item_key_text = str(item_key)
            if SENSITIVE_KEY_RE.search(item_key_text) and not isinstance(item_value, (bool, dict, list)):
                cleaned[item_key] = REDACTED
            else:
                cleaned[item_key] = sanitize(item_value, item_key_text)
        return cleaned
    if isinstance(value, list):
        return [sanitize(item, key) for item in value]
    if isinstance(value, str):
        return redact_text(value)
    return value


def read_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore").strip()
    except OSError:
        return ""


def disk_check(path: str = "/") -> dict[str, Any]:
    usage = shutil.disk_usage(path)
    return {
        "path": path,
        "total_bytes": usage.total,
        "free_bytes": usage.free,
        "free_gb": round(usage.free / (1024 ** 3), 2),
        "percent_free": round((usage.free / usage.total) * 100, 1) if usage.total else 0,
    }


def ram_check() -> dict[str, Any]:
    meminfo = read_text(Path("/proc/meminfo"))
    values: dict[str, int] = {}
    for line in meminfo.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[1].isdigit():
            values[parts[0].rstrip(":")] = int(parts[1])
    total_mb = int(values.get("MemTotal", 0) / 1024)
    available_mb = int(values.get("MemAvailable", 0) / 1024)
    return {
        "total_mb": total_mb,
        "available_mb": available_mb,
        "available_gb": round(available_mb / 1024, 2),
    }


def service_state(service: str) -> dict[str, Any]:
    if not shutil.which("systemctl"):
        return {"available": False, "active": False, "state": "unknown"}
    result = run(["systemctl", "is-active", service], timeout=5)
    state = result.stdout.strip() or result.stderr.strip() or "unknown"
    return {"available": True, "active": result.returncode == 0, "state": redact_text(state)}


def query_ollama_models() -> list[str]:
    try:
        with urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=15) as response:
            payload = json.loads(response.read().decode("utf-8", errors="replace"))
    except Exception:
        return []
    names: set[str] = set()
    for item in payload.get("models", []):
        name = str(item.get("name") or item.get("model") or "").strip()
        if name:
            names.add(name)
    return sorted(names)


def recommended_model(ram_mb: int, gpu_count: int) -> str:
    if gpu_count and ram_mb >= 28000:
        return "llama3.1:8b"
    if ram_mb >= 12000:
        return "llama3.2:3b"
    return "llama3.2:1b"


def load_setup_state() -> dict[str, Any]:
    return read_json(STATE_FILE) if STATE_FILE.exists() else {}


def parse_int(text: str) -> int | None:
    try:
        return int(str(text).strip())
    except Exception:
        return None


def nvidia_smi_available() -> bool:
    return shutil.which("nvidia-smi") is not None and run(["nvidia-smi"], timeout=20).returncode == 0


def driver_present() -> bool:
    state = read_text(Path("/proc/modules"))
    if Path("/proc/driver/nvidia/version").exists():
        return True
    return "nvidia " in state or "nvidia_drm " in state


def gpu_devices(state: dict[str, Any]) -> list[dict[str, Any]]:
    gpus = state.get("nvidia_gpus") or []
    result: list[dict[str, Any]] = []
    gpu_count = len(gpus)
    if gpus:
        for idx, gpu in enumerate(gpus):
            try:
                index = int(gpu.get("index"))
            except Exception:
                index = idx
            name = str(gpu.get("name") or "unknown").strip()
            vram = gpu.get("vram_mb")
            try:
                vram_mb = int(vram) if vram is not None else None
            except Exception:
                vram_mb = None
            if gpu_count == 1:
                role = "primary_iris_or_helper_model"
            elif index == 0:
                role = "primary_iris_or_helper_model"
            elif index == 1:
                role = "agent_or_backend_runner"
            else:
                role = "overflow_helper_gpu"
            confidence = "high" if vram_mb is not None else "medium"
            result.append(
                {
                    "index": index,
                    "name": name,
                    "vram_mb": vram_mb,
                    "usable": bool(state.get("gpu_usable")),
                    "candidate_role": role,
                    "confidence": confidence,
                }
            )
    else:
        for idx, gpu in enumerate(state.get("gpu_devices") or []):
            desc = str(gpu.get("description") or gpu.get("name") or "unknown").strip()
            role = "primary_iris_or_helper_model" if idx == 0 else "agent_or_backend_runner"
            result.append(
                {
                    "index": idx,
                    "name": desc,
                    "vram_mb": None,
                    "usable": bool(state.get("gpu_usable")),
                    "candidate_role": role,
                    "confidence": "low",
                }
            )
    return result


def read_gpu_assignment(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"present": False, "value": "unknown"}
    raw = read_text(path)
    if raw == "":
        return {"present": True, "value": "unknown"}
    parsed = parse_int(raw)
    return {"present": True, "value": parsed if parsed is not None else redact_text(raw)}


def read_ollama_dropin() -> dict[str, Any]:
    if not OLLAMA_DROPIN_FILE.exists():
        return {"present": False, "value": "unknown"}
    text = read_text(OLLAMA_DROPIN_FILE)
    match = re.search(r"CUDA_VISIBLE_DEVICES\s*=\s*([0-9,]+)", text)
    if match:
        return {"present": True, "value": match.group(1)}
    return {"present": True, "value": "unknown"}


def runner_service_presence() -> dict[str, Any]:
    service_names = ["prism-agent", "prism-runner", "aider", "codex", "runner"]
    result: dict[str, Any] = {}
    seen = []
    for service in service_names:
        state = service_state(service)
        if state.get("active"):
            seen.append(service)
        result[service] = state
    return {"services": result, "active_services": seen}


def public_surface() -> dict[str, Any]:
    def fetch_status(url: str, method: str = "GET") -> dict[str, Any]:
        req = urllib.request.Request(url, method=method)
        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                body = response.read(64 * 1024).decode("utf-8", errors="replace")
                return {"reachable": True, "status": response.status, "body": body}
        except urllib.error.HTTPError as exc:
            body = exc.read(64 * 1024).decode("utf-8", errors="replace")
            return {"reachable": True, "status": exc.code, "body": body}
        except Exception as exc:
            return {"reachable": False, "error": redact_text(str(exc))}

    state = fetch_status("http://127.0.0.1/setup/state")
    jobs = fetch_status("http://127.0.0.1/setup/jobs")
    hardware = fetch_status("http://127.0.0.1/hardware")
    setup_hardware = fetch_status("http://127.0.0.1/setup/hardware")
    text = json.dumps(json.loads(state.get("body") or "{}"), sort_keys=True) if state.get("status") == 200 else ""
    return {
        "setup_state": {
            "status": state.get("status"),
            "sanitized": state.get("status") == 200,
            "privacy": {
                "raw_mac_addresses_present": bool(MAC_RE.search(text)),
                "disk_serial_values_present": '"serial": "[REDACTED]"' not in text and '"serial"' in text,
                "wwn_values_present": '"wwn": "[REDACTED]"' not in text and '"wwn"' in text,
                "uuid_like_hardware_id_values_present": bool(UUID_RE.search(text)),
                "dev_disk_by_id_paths_present": "/dev/disk/by-id" in text,
                "password_token_cookie_private_key_values_present": bool(
                    re.search(r"(?i)(password|passwd|token|cookie|private_key|api[_-]?key|-----BEGIN )", text)
                ),
            },
        },
        "jobs": {"status": jobs.get("status"), "blocked": jobs.get("status") == 403},
        "hardware": {"status": hardware.get("status"), "blocked": hardware.get("status") == 403},
        "setup_hardware": {"status": setup_hardware.get("status"), "blocked": setup_hardware.get("status") == 403},
    }


def model_runtime(state: dict[str, Any], gpu_count: int) -> dict[str, Any]:
    ollama_active = service_state("ollama")
    models = query_ollama_models()
    recommended = str(state.get("recommended_model") or recommended_model(int(state.get("total_ram_mb") or 0), gpu_count))
    return {
        "ollama_active": bool(ollama_active.get("active")),
        "ollama_state": ollama_active.get("state"),
        "installed_models": models,
        "recommended_model": recommended,
        "ollama_gpu_ready": bool(state.get("ollama_gpu_ready")),
        "nvidia_smi_available": nvidia_smi_available(),
        "nvidia_driver_present": bool(state.get("gpu_driver") == "nvidia" or driver_present()),
    }


def collect_ai_readiness() -> dict[str, Any]:
    state = load_setup_state()
    disk = disk_check("/")
    ram = ram_check()
    gpu_list = gpu_devices(state)
    gpu_count = len(gpu_list)
    model_info = model_runtime(state, gpu_count)
    assignments = {
        "iris_gpu": "unknown",
        "agent_gpu": "unknown",
        "assignment_verified": False,
        "iris_gpu_config_path": str(IRIS_GPU_FILE),
        "agent_gpu_config_path": str(AGENT_GPU_FILE),
        "iris_gpu_config_present": IRIS_GPU_FILE.exists(),
        "agent_gpu_config_present": AGENT_GPU_FILE.exists(),
        "ollama_gpu_dropin_path": str(OLLAMA_DROPIN_FILE),
        "ollama_gpu_dropin_present": OLLAMA_DROPIN_FILE.exists(),
    }

    iris_assignment = read_gpu_assignment(IRIS_GPU_FILE)
    agent_assignment = read_gpu_assignment(AGENT_GPU_FILE)
    dropin = read_ollama_dropin()

    if iris_assignment["present"]:
        assignments["iris_gpu"] = iris_assignment["value"]
    elif dropin["present"] and dropin["value"] != "unknown":
        assignments["iris_gpu"] = dropin["value"]

    if agent_assignment["present"]:
        assignments["agent_gpu"] = agent_assignment["value"]
    elif state.get("agent_gpu_index") is not None:
        assignments["agent_gpu"] = state.get("agent_gpu_index")

    assignments["assignment_verified"] = bool(assignments["iris_gpu"] != "unknown" or assignments["agent_gpu"] != "unknown")

    runner_services = runner_service_presence()
    warnings: list[str] = []
    safe_next_steps: list[str] = []
    overall = "unknown"

    if gpu_count == 0 and not model_info["ollama_active"]:
        overall = "blocked"
        warnings.append("No visible GPUs and Ollama is not active.")
    elif not model_info["ollama_active"]:
        overall = "warning"
        warnings.append("Ollama is inactive.")
    elif not assignments["assignment_verified"]:
        overall = "warning"
        warnings.append("GPU assignment is not yet verified.")
    else:
        overall = "ready"

    if not model_info["nvidia_smi_available"] and model_info["nvidia_driver_present"]:
        warnings.append("NVIDIA driver appears present, but nvidia-smi is unavailable.")
    if ram["available_mb"] < 4096:
        warnings.append("Available RAM is low for comfortable local AI helpers.")
    if disk["free_gb"] < 15:
        warnings.append("Free disk space is low for local AI model work.")
    if not model_info["installed_models"]:
        warnings.append("No Ollama models were reported as installed.")
    if gpu_count > 1 and not assignments["assignment_verified"]:
        warnings.append("Multiple GPUs are visible, but brain/brawn assignment is not verified.")
    if runner_services["active_services"]:
        warnings.append("A runner-related service already appears to be present.")

    if gpu_count > 0:
        safe_next_steps.append("Ask the user whether they want local AI helper/runners enabled.")
        safe_next_steps.append("Do not change GPU assignment until the user confirms.")
    else:
        safe_next_steps.append("Ask the user whether they want CPU-only local AI helpers or a GPU plan.")
        safe_next_steps.append("Do not change services or drivers until the user confirms.")

    roles = ["local Iris assistant", "helper LLM", "coding/log/script runner"]
    if gpu_count > 0:
        roles.append("backend runner")
        roles.append("optional image generation workload")
    elif ram["total_mb"] >= 16000:
        roles.append("backend runner")

    result = {
        "endpoint": "check-ai-runner-readiness",
        "job_name": "check_ai_runner_readiness",
        "read_only": True,
        "changed_files": [],
        "changed_services": [],
        "overall": overall,
        "summary": "AI runner readiness check completed without making changes.",
        "gpu_devices": gpu_list,
        "model_runtime": model_info,
        "assignments": assignments,
        "recommended_roles": roles,
        "warnings": warnings,
        "safe_next_steps": safe_next_steps,
        "checks": {
            "system": {"disk": disk, "ram": ram},
            "services": runner_services["services"],
            "public_surface": public_surface(),
            "setup_state": {
                "exists": STATE_FILE.exists(),
                "gpu_count": gpu_count,
                "gpu_usable": bool(state.get("gpu_usable")),
                "primary_gpu_index": state.get("primary_gpu_index"),
                "agent_gpu_index": state.get("agent_gpu_index"),
                "ollama_gpu_ready": state.get("ollama_gpu_ready"),
                "recommended_model": state.get("recommended_model"),
                "last_probe_timestamp": state.get("last_probe_timestamp"),
            },
        },
        "rollback_hint": "No changes made; read-only check.",
        "redactions": ["mac", "serial", "wwn", "uuid", "token", "password", "cookie", "private_key", "api_key"],
    }
    Path(sys.argv[1]).write_text(json.dumps(sanitize(result), indent=2) + "\n", encoding="utf-8")
    print("check_ai_runner_readiness completed read-only AI readiness collection")
    return 0


def main() -> int:
    return collect_ai_readiness()


if __name__ == "__main__":
    raise SystemExit(main())
PY

mv "$tmp_result" "$result_path"

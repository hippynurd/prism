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


def run(command: list[str], timeout: int = 10) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(command, capture_output=True, text=True, check=False, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return subprocess.CompletedProcess(command, 127, "", str(exc))


def redact_text(value: str) -> str:
    value = MAC_RE.sub(REDACTED, value)
    value = UUID_RE.sub(REDACTED, value)
    value = API_KEY_RE.sub(REDACTED, value)
    value = value.replace("[REDACTED_BY_ID_PATH]", REDACTED)
    if "-----BEGIN " in value:
        return REDACTED
    return value


def sanitize(value: Any, key: str = "") -> Any:
    if isinstance(value, dict):
        cleaned: dict[str, Any] = {}
        for item_key, item_value in value.items():
            if SENSITIVE_KEY_RE.search(item_key) and not isinstance(item_value, (bool, dict, list)):
                cleaned[item_key] = REDACTED
            else:
                cleaned[item_key] = sanitize(item_value, item_key)
        return cleaned
    if isinstance(value, list):
        return [sanitize(item, key) for item in value]
    if isinstance(value, str):
        return redact_text(value)
    return value


def is_active(service: str) -> dict[str, Any]:
    result = run(["systemctl", "is-active", service])
    state = result.stdout.strip() or result.stderr.strip() or "unknown"
    return {"active": result.returncode == 0, "state": redact_text(state)}


def http_json(url: str, timeout: int = 10) -> dict[str, Any]:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            body = response.read().decode("utf-8", errors="replace")
            parsed = json.loads(body)
            return {
                "reachable": True,
                "status": response.status,
                "content_type": response.headers.get("Content-Type", ""),
                "json": sanitize(parsed),
            }
    except (OSError, urllib.error.URLError, json.JSONDecodeError) as exc:
        return {"reachable": False, "error": redact_text(str(exc))}


def http_status(url: str, method: str = "GET", timeout: int = 10) -> dict[str, Any]:
    request = urllib.request.Request(url, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return {
                "reachable": True,
                "status": response.status,
                "content_type": response.headers.get("Content-Type", ""),
            }
    except urllib.error.HTTPError as exc:
        return {
            "reachable": True,
            "status": exc.code,
            "content_type": exc.headers.get("Content-Type", ""),
        }
    except OSError as exc:
        return {"reachable": False, "error": redact_text(str(exc))}


def ollama_models() -> dict[str, Any]:
    payload = http_json("http://127.0.0.1:11434/api/tags", timeout=10)
    names: list[str] = []
    for item in payload.get("json", {}).get("models", []):
        name = str(item.get("name") or item.get("model") or "")
        if name:
            names.append(redact_text(name))
    return {
        "reachable": payload.get("reachable", False),
        "count": len(names),
        "models": sorted(set(names)),
    }


def listening_ports() -> dict[str, Any]:
    if not shutil.which("ss"):
        return {"available": False, "listeners": []}
    result = run(["ss", "-lntH"], timeout=10)
    listeners: list[dict[str, Any]] = []
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        local = parts[3]
        port = local.rsplit(":", 1)[-1] if ":" in local else local
        if port.isdigit():
            listeners.append({"proto": parts[0], "port": int(port)})
    unique = sorted({(item["proto"], item["port"]) for item in listeners})
    return {
        "available": result.returncode == 0,
        "listeners": [{"proto": proto, "port": port} for proto, port in unique],
    }


def public_state_privacy() -> dict[str, bool]:
    payload = http_json("http://127.0.0.1:5000/setup/public-state", timeout=10)
    text = json.dumps(payload.get("json", {}), sort_keys=True)
    return {
        "raw_mac_addresses_present": bool(MAC_RE.search(text)),
        "uuid_like_ids_present": bool(UUID_RE.search(text)),
        "dev_disk_by_id_paths_present": "[REDACTED_BY_ID_PATH]" in text,
        "serial_fields_redacted": '"serial": "[REDACTED]"' in text or '"serial"' not in text,
    }


def marker(path: str) -> bool:
    return Path(path).exists()


def main() -> int:
    setup_state_path = Path("/var/lib/prism/setup-state.json")
    public_state = http_json("http://127.0.0.1:5000/setup/public-state", timeout=10)
    raw_state = http_status("http://127.0.0.1:5000/setup/state", timeout=10)
    public_setup_state = http_status("http://127.0.0.1/setup/state", timeout=10)
    public_jobs = http_status("http://127.0.0.1/setup/jobs", timeout=10)

    result = {
        "job_name": "check_prism_status",
        "status": "succeeded",
        "read_only": True,
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime()),
        "finished_at": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime()),
        "exit_code": 0,
        "summary": "Read-only PRISM status snapshot collected by approved backend job.",
        "checks": {
            "prism_setup_backend": is_active("prism-setup-backend"),
            "nginx": is_active("nginx"),
            "ollama": is_active("ollama"),
            "setup_state": {
                "exists": setup_state_path.exists(),
                "raw_state_reachable_locally": raw_state.get("status") == 200,
                "public_state_reachable_locally": public_state.get("reachable") is True,
                "public_state_via_nginx_status": public_setup_state.get("status"),
                "privacy": public_state_privacy(),
            },
            "models": ollama_models(),
            "ports": listening_ports(),
            "markers": {
                "setup_complete": marker("/var/lib/prism/setup-complete"),
                "firstboot_done": marker("/var/lib/prism/firstboot.done"),
                "setup_mode": marker("/etc/prism/setup-mode"),
            },
            "public_api": {
                "/setup/state": "sanitized" if public_setup_state.get("status") == 200 else "unreachable",
                "/setup/jobs": "blocked_by_nginx" if public_jobs.get("status") == 403 else f"unexpected_status_{public_jobs.get('status')}",
            },
        },
        "stdout": "",
        "stderr": "",
        "redactions": ["mac", "serial", "wwn", "uuid", "token", "password", "cookie", "private_key", "api_key"],
        "changed_files": [],
        "changed_services": [],
        "rollback_hint": "No changes made; read-only job.",
    }
    Path(sys.argv[1]).write_text(json.dumps(sanitize(result), indent=2) + "\n", encoding="utf-8")
    print("check_prism_status completed read-only status collection")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY

mv "$tmp_result" "$result_path"

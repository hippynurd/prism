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

APPROVED_MODELS = {"llama3.2:1b", "llama3.2:3b", "llama3.1:8b"}


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


def http_status(url: str, method: str = "GET", timeout: int = 10) -> dict[str, Any]:
    request = urllib.request.Request(url, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read(256 * 1024).decode("utf-8", errors="replace")
            return {
                "reachable": True,
                "status": response.status,
                "content_type": response.headers.get("Content-Type", ""),
                "body": redact_text(body),
            }
    except urllib.error.HTTPError as exc:
        body = exc.read(64 * 1024).decode("utf-8", errors="replace")
        return {
            "reachable": True,
            "status": exc.code,
            "content_type": exc.headers.get("Content-Type", ""),
            "body": redact_text(body),
        }
    except OSError as exc:
        return {"reachable": False, "error": redact_text(str(exc)), "body": ""}


def http_json(url: str, timeout: int = 10) -> dict[str, Any]:
    result = http_status(url, "GET", timeout)
    if result.get("status") != 200:
        return {k: v for k, v in result.items() if k != "body"}
    try:
        parsed = json.loads(str(result.get("body") or "{}"))
    except json.JSONDecodeError as exc:
        return {"reachable": True, "status": result.get("status"), "json": None, "error": redact_text(str(exc))}
    return {
        "reachable": True,
        "status": result.get("status"),
        "content_type": result.get("content_type", ""),
        "json": sanitize(parsed),
    }


def service_state(service: str) -> dict[str, Any]:
    if not shutil.which("systemctl"):
        return {"available": False, "active": False, "state": "unknown"}
    result = run(["systemctl", "is-active", service], timeout=5)
    state = result.stdout.strip() or result.stderr.strip() or "unknown"
    return {"available": True, "active": result.returncode == 0, "state": redact_text(state)}


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
    meminfo = Path("/proc/meminfo").read_text(encoding="utf-8", errors="ignore")
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


def lock_status(paths: list[str]) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    fuser = shutil.which("fuser")
    for path in paths:
        exists = Path(path).exists()
        held: bool | None = None
        if fuser and exists:
            held = run(["fuser", "-s", path], timeout=5).returncode == 0
        results.append({"path": path, "exists": exists, "held": held})
    return results


def listening_ports() -> dict[str, Any]:
    ports: set[int] = set()
    if shutil.which("ss"):
        result = run(["ss", "-lntH"], timeout=10)
        for line in result.stdout.splitlines():
            parts = line.split()
            if len(parts) < 4:
                continue
            local = parts[3]
            port = local.rsplit(":", 1)[-1] if ":" in local else local
            if port.isdigit():
                ports.add(int(port))
        return {"available": result.returncode == 0, "ports": sorted(ports)}
    return {"available": False, "ports": []}


def service_presence(terms: list[str], unit_names: list[str], commands: list[str]) -> dict[str, Any]:
    active_units = {name: service_state(name) for name in unit_names}
    command_hits = [cmd for cmd in commands if shutil.which(cmd)]
    process_hits: list[str] = []
    ps = run(["ps", "-eo", "comm="], timeout=10)
    if ps.returncode == 0:
        comms = {line.strip().lower() for line in ps.stdout.splitlines() if line.strip()}
        for term in terms:
            if any(term.lower() in comm for comm in comms):
                process_hits.append(term)
    unit_file_hits = []
    for base in (Path("/etc/systemd/system"), Path("/lib/systemd/system"), Path("/usr/lib/systemd/system")):
        if base.exists():
            for term in terms:
                if any(base.glob(f"*{term}*.service")):
                    unit_file_hits.append(term)
    return {
        "active_units": active_units,
        "command_hits": sorted(set(command_hits)),
        "process_terms_seen": sorted(set(process_hits)),
        "unit_file_terms_seen": sorted(set(unit_file_hits)),
        "appears_present": bool(command_hits or process_hits or unit_file_hits or any(item.get("active") for item in active_units.values())),
    }


def ollama_models() -> dict[str, Any]:
    payload = http_json("http://127.0.0.1:11434/api/tags", timeout=10)
    names: list[str] = []
    for item in (payload.get("json") or {}).get("models", []):
        name = str(item.get("name") or item.get("model") or "")
        if name:
            names.append(redact_text(name))
    experimental = sorted({name for name in names if name not in APPROVED_MODELS})
    return {
        "reachable": payload.get("reachable", False),
        "count": len(set(names)),
        "models": sorted(set(names)),
        "approved_models": sorted(APPROVED_MODELS),
        "experimental_models": experimental,
    }


def ollama_storage() -> dict[str, Any]:
    paths = [
        Path("/usr/share/ollama/.ollama/models"),
        Path("/var/lib/ollama"),
        Path("/root/.ollama"),
    ]
    home = Path("/home")
    if home.exists():
        paths.extend(home.glob("*/.ollama"))
    found: list[dict[str, Any]] = []
    total_bytes = 0
    for path in paths:
        if not path.exists():
            continue
        du = run(["du", "-sb", str(path)], timeout=20)
        size = 0
        if du.returncode == 0 and du.stdout.split():
            try:
                size = int(du.stdout.split()[0])
            except ValueError:
                size = 0
        total_bytes += size
        manifests: list[dict[str, Any]] = []
        manifest_root = path / "manifests"
        if manifest_root.exists():
            for item in sorted(manifest_root.rglob("*"))[:200]:
                if item.is_file():
                    stat = item.stat()
                    manifests.append(
                        {
                            "relative_path": redact_text(str(item.relative_to(path))),
                            "size_bytes": stat.st_size,
                            "modified_at": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(stat.st_mtime)),
                        }
                    )
        found.append(
            {
                "path": redact_text(str(path)),
                "size_bytes": size,
                "size_gb": round(size / (1024 ** 3), 2),
                "manifest_files": manifests,
            }
        )
    return {
        "paths": found,
        "total_size_bytes": total_bytes,
        "total_size_gb": round(total_bytes / (1024 ** 3), 2),
    }


def public_state_privacy() -> dict[str, bool]:
    payload = http_json("http://127.0.0.1/setup/state", timeout=10)
    text = json.dumps(payload.get("json", {}), sort_keys=True)
    return {
        "status": payload.get("status"),
        "raw_mac_addresses_present": bool(MAC_RE.search(text)),
        "disk_serials_present": '"serial": "[REDACTED]"' not in text and '"serial"' in text,
        "wwns_present": '"wwn": "[REDACTED]"' not in text and '"wwn"' in text,
        "uuid_like_hardware_ids_present": bool(UUID_RE.search(text)),
        "dev_disk_by_id_paths_present": "/dev/disk/by-id" in text,
        "passwords_tokens_cookies_private_keys_present": bool(
            re.search(r"(?i)(password|passwd|token|cookie|private_key|api[_-]?key|-----BEGIN )", text)
        ),
        "useful_readiness_info_present": all(key in text for key in ("setup_complete", "total_ram_mb")),
    }


def checkpoint_state() -> dict[str, Any]:
    candidates = [
        Path("/vault/pve-media/projects/prism/checkpoints"),
        Path("/var/lib/prism/checkpoints"),
        Path("/var/backups/prism"),
    ]
    return {
        "candidates": [{"path": str(path), "exists": path.exists()} for path in candidates],
        "any_exists": any(path.exists() for path in candidates),
    }


def marker(path: str) -> bool:
    return Path(path).exists()


def status_from_reasons(blockers: list[str], warnings: list[str]) -> str:
    if blockers:
        return "blocked"
    if warnings:
        return "warning"
    return "ready"


def main() -> int:
    started_at = time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime())
    disk = disk_check("/")
    ram = ram_check()
    locks = lock_status(["/var/lib/dpkg/lock", "/var/lib/dpkg/lock-frontend", "/var/lib/apt/lists/lock", "/var/cache/apt/archives/lock"])
    lock_blockers = [item["path"] for item in locks if item.get("held") is True]
    ports = listening_ports()
    port_set = set(ports.get("ports", []))
    public_state = public_state_privacy()
    endpoint_statuses = {
        "/setup/state": http_status("http://127.0.0.1/setup/state"),
        "/setup/jobs": http_status("http://127.0.0.1/setup/jobs"),
        "/hardware": http_status("http://127.0.0.1/hardware"),
        "/setup/hardware": http_status("http://127.0.0.1/setup/hardware"),
    }
    models = ollama_models()
    services = {
        "nginx": service_state("nginx"),
        "prism_setup_backend": service_state("prism-setup-backend"),
        "ollama": service_state("ollama"),
        "adguard": service_presence(["adguard", "adguardhome"], ["AdGuardHome", "adguardhome"], ["AdGuardHome", "adguardhome"]),
        "vaultwarden": service_presence(["vaultwarden"], ["vaultwarden"], ["vaultwarden"]),
        "searxng": service_presence(["searxng"], ["searxng"], ["searxng"]),
    }
    markers = {
        "setup_complete": marker("/var/lib/prism/setup-complete"),
        "firstboot_done": marker("/var/lib/prism/firstboot.done"),
        "setup_mode": marker("/etc/prism/setup-mode"),
    }
    checkpoint = checkpoint_state()

    global_blockers: list[str] = []
    global_warnings: list[str] = []
    if disk["free_gb"] < 5:
        global_blockers.append("root disk has less than 5GB free")
    elif disk["free_gb"] < 15:
        global_warnings.append("root disk has less than 15GB free")
    if ram["available_mb"] < 512:
        global_blockers.append("less than 512MB RAM currently available")
    elif ram["total_mb"] < 2048:
        global_warnings.append("system has less than 2GB total RAM")
    if lock_blockers:
        global_blockers.append("apt/dpkg lock appears held")
    for name in ("nginx", "prism_setup_backend", "ollama"):
        if not services[name].get("active"):
            global_warnings.append(f"{name} is not active")
    if endpoint_statuses["/setup/jobs"].get("status") != 403:
        global_blockers.append("/setup/jobs is not blocked publicly")
    if endpoint_statuses["/hardware"].get("status") != 403:
        global_blockers.append("/hardware is not blocked publicly")
    if endpoint_statuses["/setup/hardware"].get("status") != 403:
        global_blockers.append("/setup/hardware is not blocked publicly")
    if public_state.get("status") != 200:
        global_blockers.append("/setup/state is not reachable")
    if any(public_state.get(key) for key in (
        "raw_mac_addresses_present",
        "disk_serials_present",
        "wwns_present",
        "uuid_like_hardware_ids_present",
        "dev_disk_by_id_paths_present",
        "passwords_tokens_cookies_private_keys_present",
    )):
        global_blockers.append("/setup/state privacy check failed")
    if models.get("experimental_models"):
        global_warnings.append("experimental Ollama models are present")
    if not checkpoint.get("any_exists"):
        global_warnings.append("no checkpoint or rollback directory found")
    if not markers["setup_complete"] or not markers["firstboot_done"] or markers["setup_mode"]:
        global_warnings.append("setup markers are not in finalized post-firstboot shape")

    service_readiness: dict[str, dict[str, Any]] = {}

    adguard_reasons: list[str] = []
    adguard_warnings: list[str] = []
    if services["adguard"].get("appears_present"):
        adguard_reasons.append("AdGuard Home already appears present or running")
    if 53 in port_set:
        adguard_reasons.append("port 53 is already in use")
    if 3000 in port_set:
        adguard_warnings.append("port 3000 is already in use")
    service_readiness["adguard"] = {
        "status": status_from_reasons(adguard_reasons, global_blockers + adguard_warnings),
        "reasons": adguard_reasons + adguard_warnings + global_blockers,
    }

    vaultwarden_reasons: list[str] = []
    if services["vaultwarden"].get("appears_present"):
        vaultwarden_reasons.append("Vaultwarden already appears present or running")
    service_readiness["vaultwarden"] = {
        "status": status_from_reasons(vaultwarden_reasons, global_blockers),
        "reasons": vaultwarden_reasons + global_blockers,
        "port_note": "internal app port not defined by this readiness check",
    }

    searxng_reasons: list[str] = []
    if services["searxng"].get("appears_present"):
        searxng_reasons.append("SearXNG already appears present or running")
    service_readiness["searxng"] = {
        "status": status_from_reasons(searxng_reasons, global_blockers),
        "reasons": searxng_reasons + global_blockers,
        "port_note": "internal app port not defined by this readiness check",
    }

    overall = status_from_reasons(global_blockers, global_warnings)
    result = {
        "endpoint": "check-install-readiness",
        "job_name": "check_install_readiness",
        "read_only": True,
        "changed_files": [],
        "changed_services": [],
        "started_at": started_at,
        "finished_at": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime()),
        "overall": overall,
        "summary": "Install readiness check completed without making changes.",
        "checks": {
            "system": {
                "disk": disk,
                "ram": ram,
                "apt_dpkg_locks": locks,
                "ollama_storage": ollama_storage(),
            },
            "security_surface": {
                "endpoints": {key: {k: v for k, v in value.items() if k != "body"} for key, value in endpoint_statuses.items()},
                "setup_state_privacy": public_state,
            },
            "ports": {
                "available": ports.get("available"),
                "adguard": {"dns_53_in_use": 53 in port_set, "setup_3000_in_use": 3000 in port_set},
                "vaultwarden": {"internal_app_port": "unknown"},
                "searxng": {"internal_app_port": "unknown"},
            },
            "services": services,
            "models": models,
            "markers": markers,
            "checkpoint": checkpoint,
        },
        "service_readiness": service_readiness,
        "blockers": global_blockers,
        "warnings": global_warnings,
        "next_step": "No install was performed. Iris may ask the user which service to prepare next.",
        "rollback_hint": "No changes made; read-only check.",
        "redactions": ["mac", "serial", "wwn", "uuid", "token", "password", "cookie", "private_key", "api_key"],
    }
    Path(sys.argv[1]).write_text(json.dumps(sanitize(result), indent=2) + "\n", encoding="utf-8")
    print("check_install_readiness completed read-only install readiness collection")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY

mv "$tmp_result" "$result_path"

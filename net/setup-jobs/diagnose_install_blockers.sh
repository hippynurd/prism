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
ALLOWED_SERVICES = {"adguard", "vaultwarden", "searxng", "all"}

SERVICE_PORTS = {
    "adguard": [("tcp", 53), ("udp", 53), ("tcp", 3000)],
    "vaultwarden": [("tcp", 8080)],
    "searxng": [("tcp", 8888)],
}

BLOCKER_SERVICES = ["systemd-resolved", "dnsmasq", "named", "bind9", "unbound", "nginx", "apache2", "caddy"]


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
            body = response.read(128 * 1024).decode("utf-8", errors="replace")
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


def http_json(url: str, method: str = "GET", timeout: int = 10) -> dict[str, Any]:
    result = http_status(url, method=method, timeout=timeout)
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


def parse_request() -> str:
    raw = os.environ.get("PRISM_BLOCKER_SERVICE", "").strip().lower()
    return raw if raw in ALLOWED_SERVICES else "all"


def service_state(service: str) -> dict[str, Any]:
    if not shutil.which("systemctl"):
        return {"available": False, "active": False, "state": "unknown"}
    result = run(["systemctl", "is-active", service], timeout=5)
    state = result.stdout.strip() or result.stderr.strip() or "unknown"
    return {"available": True, "active": result.returncode == 0, "state": redact_text(state)}


def process_names_for_service(term: str) -> list[str]:
    ps = run(["ps", "-eo", "comm="], timeout=10)
    if ps.returncode != 0:
        return []
    comms = {line.strip().lower() for line in ps.stdout.splitlines() if line.strip()}
    if term == "adguard":
        hits = [name for name in ("adguard", "adguardhome") if any(name in comm for comm in comms)]
    else:
        hits = [term] if any(term in comm for comm in comms) else []
    return sorted(set(hits))


def port_listeners(port: int) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    commands = [("tcp", ["ss", "-H", "-lntp"]), ("udp", ["ss", "-H", "-lnup"])]
    for proto, command in commands:
        if not shutil.which("ss"):
            continue
        result = run(command, timeout=10)
        if result.returncode != 0:
            continue
        for line in result.stdout.splitlines():
            parts = line.split()
            if len(parts) < 4:
                continue
            local = parts[3]
            local_port = local.rsplit(":", 1)[-1] if ":" in local else local
            if not local_port.isdigit() or int(local_port) != port:
                continue
            process_matches = sorted(set(re.findall(r'"([^"]+)",pid=\d+', line)))
            results.append(
                {
                    "protocol": proto,
                    "local": redact_text(local),
                    "owner_processes": [redact_text(name) for name in process_matches],
                    "confidence": "high" if process_matches else "low",
                }
            )
    return results


def public_surface() -> dict[str, Any]:
    state = http_json("http://127.0.0.1/setup/state")
    jobs = http_status("http://127.0.0.1/setup/jobs")
    hardware = http_status("http://127.0.0.1/hardware")
    setup_hardware = http_status("http://127.0.0.1/setup/hardware")
    text = json.dumps(state.get("json", {}), sort_keys=True)
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
                "useful_blocker_diagnosis_info_present": all(key in text for key in ("setup_complete", "total_ram_mb")),
            },
        },
        "jobs": {"status": jobs.get("status"), "blocked": jobs.get("status") == 403},
        "hardware": {"status": hardware.get("status"), "blocked": hardware.get("status") == 403},
        "setup_hardware": {"status": setup_hardware.get("status"), "blocked": setup_hardware.get("status") == 403},
    }


def readiness_check() -> dict[str, Any]:
    result = http_json("http://127.0.0.1/setup/check-install-readiness", method="POST", timeout=20)
    if not result.get("reachable"):
        return {"available": False, "error": result.get("error", "unavailable")}
    data = result.get("json") or {}
    return {
        "available": True,
        "overall": data.get("overall"),
        "adguard": (data.get("service_readiness") or {}).get("adguard", {}),
        "vaultwarden": (data.get("service_readiness") or {}).get("vaultwarden", {}),
        "searxng": (data.get("service_readiness") or {}).get("searxng", {}),
    }


def blocker_for_service(service: str, ports: dict[int, list[dict[str, Any]]], services: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    blockers: list[dict[str, Any]] = []
    if service in {"adguard", "all"}:
        if ports.get(53):
            owners = sorted({owner for item in ports[53] for owner in item.get("owner_processes", [])}) or ["unknown"]
            blockers.append(
                {
                    "type": "port_in_use",
                    "port": 53,
                    "protocol": "tcp/udp",
                    "owner": ", ".join(owners),
                    "confidence": "high" if owners != ["unknown"] else "low",
                    "safe_options": [
                        "Review DNS ownership before installing AdGuard.",
                        "Do not stop the existing DNS service until the user confirms a DNS plan.",
                    ],
                }
            )
        if ports.get(3000):
            owners = sorted({owner for item in ports[3000] for owner in item.get("owner_processes", [])}) or ["unknown"]
            blockers.append(
                {
                    "type": "port_in_use",
                    "port": 3000,
                    "protocol": "tcp",
                    "owner": ", ".join(owners),
                    "confidence": "medium" if owners != ["unknown"] else "low",
                    "safe_options": [
                        "Verify the current AdGuard web port ownership before installing or reconfiguring anything.",
                    ],
                }
            )
        if services["adguardhome"]["active"] or services["adguardhome"]["processes"]:
            blockers.append(
                {
                    "type": "service_already_present",
                    "service": "adguardhome",
                    "confidence": "medium",
                    "safe_options": [
                        "Confirm whether AdGuard Home is already the intended DNS service before planning any install.",
                    ],
                }
            )
    if service in {"vaultwarden", "all"}:
        if ports.get(8080):
            owners = sorted({owner for item in ports[8080] for owner in item.get("owner_processes", [])}) or ["unknown"]
            blockers.append(
                {
                    "type": "port_in_use",
                    "port": 8080,
                    "protocol": "tcp",
                    "owner": ", ".join(owners),
                    "confidence": "medium" if owners != ["unknown"] else "low",
                    "safe_options": [
                        "Confirm whether port 8080 is already committed to another local service before installing Vaultwarden.",
                    ],
                }
            )
        if services["vaultwarden"]["active"] or services["vaultwarden"]["processes"]:
            blockers.append(
                {
                    "type": "service_already_present",
                    "service": "vaultwarden",
                    "confidence": "medium",
                    "safe_options": [
                        "Confirm whether Vaultwarden is already present before attempting a new install.",
                    ],
                }
            )
    if service in {"searxng", "all"}:
        if ports.get(8888):
            owners = sorted({owner for item in ports[8888] for owner in item.get("owner_processes", [])}) or ["unknown"]
            blockers.append(
                {
                    "type": "port_in_use",
                    "port": 8888,
                    "protocol": "tcp",
                    "owner": ", ".join(owners),
                    "confidence": "medium" if owners != ["unknown"] else "low",
                    "safe_options": [
                        "Confirm whether port 8888 is already committed to another local service before installing SearXNG.",
                    ],
                }
            )
        if services["searxng"]["active"] or services["searxng"]["processes"]:
            blockers.append(
                {
                    "type": "service_already_present",
                    "service": "searxng",
                    "confidence": "medium",
                    "safe_options": [
                        "Confirm whether SearXNG is already present before attempting a new install.",
                    ],
                }
            )
    if service in {"adguard", "all"} and ports.get(80):
        owners = sorted({owner for item in ports[80] for owner in item.get("owner_processes", [])}) or ["unknown"]
        blockers.append(
            {
                "type": "port_in_use",
                "port": 80,
                "protocol": "tcp",
                "owner": ", ".join(owners),
                "confidence": "medium" if owners != ["unknown"] else "low",
                "safe_options": [
                    "Review the current web service before changing the LAN-facing HTTP port.",
                ],
            }
        )
    if service in {"adguard", "all"} and ports.get(443):
        owners = sorted({owner for item in ports[443] for owner in item.get("owner_processes", [])}) or ["unknown"]
        blockers.append(
            {
                "type": "port_in_use",
                "port": 443,
                "protocol": "tcp",
                "owner": ", ".join(owners),
                "confidence": "medium" if owners != ["unknown"] else "low",
                "safe_options": [
                    "Review the current HTTPS owner before planning a web service install that needs 443.",
                ],
            }
        )
    return blockers


def services_snapshot() -> dict[str, Any]:
    snapshot: dict[str, Any] = {}
    for name in ["systemd-resolved", "dnsmasq", "named", "bind9", "unbound", "nginx", "apache2", "caddy"]:
        state = service_state(name)
        snapshot[name] = state
    for key in ["adguardhome", "vaultwarden", "searxng"]:
        state = service_state(key)
        proc = run(["pgrep", "-af", key], timeout=5)
        processes = []
        if proc.returncode == 0:
            for line in proc.stdout.splitlines():
                line = line.strip()
                if not line:
                    continue
                processes.append(redact_text(re.sub(r"^\d+\s+", "", line)))
        snapshot[key] = {**state, "processes": processes}
    return snapshot


def service_target_info(service: str) -> dict[str, Any]:
    if service == "adguard":
        return {"name": "adguard", "display": "AdGuard"}
    if service == "vaultwarden":
        return {"name": "vaultwarden", "display": "Vaultwarden"}
    if service == "searxng":
        return {"name": "searxng", "display": "SearXNG"}
    return {"name": "all", "display": "All services"}


def overall_status(blockers: list[dict[str, Any]], readiness: dict[str, Any]) -> str:
    if blockers:
        return "blocked"
    if readiness.get("available") and readiness.get("overall") == "warning":
        return "warning"
    if readiness.get("available") and readiness.get("overall") == "clear":
        return "clear"
    return "unknown"


def summarize(service: str, blockers: list[dict[str, Any]], readiness: dict[str, Any]) -> str:
    if service == "adguard":
        if any(item.get("type") == "port_in_use" and item.get("port") == 53 for item in blockers):
            return "AdGuard is blocked because port 53 is already in use."
        if blockers:
            return "AdGuard has install blockers that need review."
        return "No AdGuard-specific blocker was found."
    if service == "vaultwarden":
        if blockers:
            return "Vaultwarden has install blockers that need review."
        return "No Vaultwarden-specific blocker was found."
    if service == "searxng":
        if blockers:
            return "SearXNG has install blockers that need review."
        return "No SearXNG-specific blocker was found."
    if blockers:
        return "One or more install blockers were found."
    return "No install blockers were found."


def next_steps(service: str, blockers: list[dict[str, Any]]) -> list[str]:
    if service == "adguard" and any(item.get("type") == "port_in_use" and item.get("port") == 53 for item in blockers):
        return [
            "Ask the user whether PRISM should use AdGuard for DNS.",
            "If yes, prepare a DNS transition plan before changing services.",
            "Do not stop the existing DNS service until the plan is approved.",
        ]
    if service == "vaultwarden":
        return [
            "Ask the user whether Vaultwarden should be prepared now.",
            "Review the current local port owners before any install is attempted later.",
        ]
    if service == "searxng":
        return [
            "Ask the user whether SearXNG should be prepared now.",
            "Review the current local port owners before any install is attempted later.",
        ]
    return [
        "Ask the user which service should be investigated next.",
        "If a port conflict is present, review ownership before changing services.",
    ]


def main() -> int:
    started_at = time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime())
    requested_service = parse_request()
    target = service_target_info(requested_service)
    services = services_snapshot()
    public = public_surface()
    readiness = readiness_check()

    port_map: dict[int, list[dict[str, Any]]] = {}
    for port in {53, 80, 443, 3000, 8080, 8888}:
        port_map[port] = port_listeners(port)

    service_specific = requested_service if requested_service in {"adguard", "vaultwarden", "searxng"} else "all"
    blockers = blocker_for_service(service_specific, port_map, services)
    overall = overall_status(blockers, readiness)
    result = {
        "endpoint": "diagnose-install-blockers",
        "job_name": "diagnose_install_blockers",
        "read_only": True,
        "changed_files": [],
        "changed_services": [],
        "service": target["name"],
        "started_at": started_at,
        "finished_at": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime()),
        "overall": overall,
        "summary": summarize(target["name"], blockers, readiness),
        "blockers": blockers,
        "safe_next_steps": next_steps(target["name"], blockers),
        "checks": {
            "ports": port_map,
            "services": services,
            "public_surface": public,
            "readiness_check": readiness,
        },
        "rollback_hint": "No changes made; read-only diagnosis.",
        "redactions": ["mac", "serial", "wwn", "uuid", "token", "password", "cookie", "private_key", "api_key"],
    }
    Path(sys.argv[1]).write_text(json.dumps(sanitize(result), indent=2) + "\n", encoding="utf-8")
    print("diagnose_install_blockers completed read-only blocker diagnosis")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY

mv "$tmp_result" "$result_path"

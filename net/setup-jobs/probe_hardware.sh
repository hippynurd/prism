#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${PRISM_STATE_FILE:-/var/lib/prism/setup-state.json}"
SETUP_COMPLETE_FILE="${PRISM_SETUP_COMPLETE_FILE:-/var/lib/prism/setup-complete}"

mkdir -p "$(dirname "$STATE_FILE")"

python3 - "$STATE_FILE" "$SETUP_COMPLETE_FILE" <<'PY'
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

state_file = Path(sys.argv[1])
setup_complete_file = Path(sys.argv[2])

def run(command, timeout=20):
    try:
        return subprocess.run(command, capture_output=True, text=True, check=False, timeout=timeout)
    except Exception as exc:
        return subprocess.CompletedProcess(command, 127, "", str(exc))

def text(path):
    try:
        return Path(path).read_text(encoding="utf-8", errors="ignore").strip()
    except OSError:
        return ""

def ram_mb():
    for line in text("/proc/meminfo").splitlines():
        if line.startswith("MemTotal:"):
            return int(int(line.split()[1]) / 1024)
    return 0

def root_disk():
    source = run(["findmnt", "-n", "-o", "SOURCE", "/"]).stdout.strip()
    if not source:
        return ""
    parent = run(["lsblk", "-no", "PKNAME", source]).stdout.strip().splitlines()
    return parent[0] if parent else Path(source).name

def extra_disks():
    boot = root_disk()
    result = run(["lsblk", "-J", "-d", "-o", "NAME,PATH,SIZE,MODEL,SERIAL,TYPE"])
    try:
        devices = json.loads(result.stdout).get("blockdevices", [])
    except json.JSONDecodeError:
        devices = []
    return [
        {
            "name": str(d.get("name") or ""),
            "path": str(d.get("path") or ""),
            "size": str(d.get("size") or ""),
            "model": str(d.get("model") or "").strip(),
            "serial": str(d.get("serial") or "").strip(),
        }
        for d in devices
        if d.get("type") == "disk" and d.get("name") != boot
    ]

def nics():
    devices = []
    for iface in sorted(Path("/sys/class/net").iterdir() if Path("/sys/class/net").exists() else []):
        if not iface.is_dir():
            continue
        if iface.name == "lo":
            continue
        devices.append({
            "name": iface.name,
            "mac": text(iface / "address"),
            "operstate": text(iface / "operstate") or "unknown",
            "carrier": text(iface / "carrier") == "1",
        })
    return devices

def gpu_devices():
    devices = []
    if shutil.which("lspci"):
        for line in run(["lspci", "-mm"]).stdout.splitlines():
            lower = line.lower()
            if "vga compatible controller" in lower or "3d controller" in lower or "display controller" in lower:
                devices.append({"source": "lspci", "description": line})
        return devices
    for device in Path("/sys/bus/pci/devices").glob("*"):
        klass = text(device / "class")
        if klass.startswith(("0x0300", "0x0301", "0x0302")):
            devices.append({"source": "sysfs", "description": f"{device.name} vendor={text(device / 'vendor')} device={text(device / 'device')}"})
    return devices

def gpu_driver():
    if Path("/proc/driver/nvidia/version").exists():
        return "nvidia"
    modules = text("/proc/modules")
    if "nvidia " in modules or "nvidia_drm " in modules:
        return "nvidia"
    if "nouveau " in modules:
        return "nouveau"
    return None

def ollama_models():
    result = run(["curl", "-fsS", "http://127.0.0.1:11434/api/tags"], timeout=20)
    if result.returncode != 0:
        return set()
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return set()
    names = set()
    for item in payload.get("models", []):
        name = str(item.get("name") or item.get("model") or "")
        if name:
            names.add(name)
            names.add(name.split(":", 1)[0])
    return names

def model_installed(model):
    names = ollama_models()
    return model in names

def recommended_model(memory_mb):
    if memory_mb >= 28000:
        return "llama3.1:8b"
    if memory_mb >= 12000:
        return "llama3.2:3b"
    return "llama3.2:1b"

driver = gpu_driver()
gpu_ok = bool(driver == "nvidia" and shutil.which("nvidia-smi") and run(["nvidia-smi"]).returncode == 0)
ollama_gpu_ready = False
if gpu_ok:
    active = run(["systemctl", "is-active", "ollama"], timeout=10) if shutil.which("systemctl") else subprocess.CompletedProcess([], 0, "", "")
    ollama_gpu_ready = active.returncode == 0

memory_mb = ram_mb()
network = nics()
recommended = recommended_model(memory_mb)
state = {
    "setup_complete": setup_complete_file.exists(),
    "total_ram_mb": memory_mb,
    "nics": network,
    "nic_count": len(network),
    "extra_disks": extra_disks(),
    "gpu_present": bool(gpu_devices()),
    "gpu_devices": gpu_devices(),
    "gpu_usable": gpu_ok,
    "gpu_driver": driver,
    "ollama_model_installed": model_installed(recommended),
    "ollama_gpu_ready": ollama_gpu_ready,
    "recommended_model": recommended,
    "last_probe_timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime()),
}
state_file.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
print(json.dumps(state, indent=2))
PY

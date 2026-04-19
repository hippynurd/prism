#!/usr/bin/env python3
"""
PRISM Net setup backend.

Why this backend exists:
- Iris should guide setup in the browser while a local service performs the real
  hardware detection and native installs.
- The browser needs simple HTTP endpoints for hardware facts, install actions,
  progress streaming, and a completion signal.
- The implementation stays intentionally plain so PRISM remains inspectable and
  easy to debug on recycled hardware.
"""

from __future__ import annotations

import json
import os
import queue
import shutil
import subprocess
import threading
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


HOST = "127.0.0.1"
PORT = 5000
STATE_DIR = Path("/var/lib/prism")
SETUP_COMPLETE_FILE = STATE_DIR / "setup-complete"


class SetupState:
    """Shared state for one running setup session."""

    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.progress: list[dict[str, Any]] = []
        self.install_thread: threading.Thread | None = None
        self.install_running = False
        self.install_error: str | None = None
        self.final_model: str | None = None

    def publish(self, stage: str, message: str, level: str = "info") -> None:
        event = {
            "time": time.time(),
            "stage": stage,
            "level": level,
            "message": message,
        }
        with self.lock:
            self.progress.append(event)


STATE = SetupState()


def detect_ram_mb() -> int:
    with open("/proc/meminfo", "r", encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("MemTotal:"):
                return int(int(line.split()[1]) / 1024)
    return 0


def detect_root_disk() -> str:
    source = subprocess.run(
        ["findmnt", "-n", "-o", "SOURCE", "/"],
        capture_output=True,
        text=True,
        check=False,
    ).stdout.strip()
    if not source:
        return ""
    return subprocess.run(
        ["lsblk", "-no", "PKNAME", source],
        capture_output=True,
        text=True,
        check=False,
    ).stdout.strip().splitlines()[0] if subprocess.run(
        ["lsblk", "-no", "PKNAME", source],
        capture_output=True,
        text=True,
        check=False,
    ).stdout.strip() else ""


def detect_extra_disks() -> list[str]:
    boot_disk = detect_root_disk()
    disks = subprocess.run(
        ["lsblk", "-dno", "NAME,TYPE"],
        capture_output=True,
        text=True,
        check=False,
    ).stdout.splitlines()
    names: list[str] = []
    for line in disks:
        parts = line.split()
        if len(parts) == 2 and parts[1] == "disk" and parts[0] != boot_disk:
            names.append(parts[0])
    return names


def detect_gpu() -> bool:
    output = subprocess.run(
        ["lspci"],
        capture_output=True,
        text=True,
        check=False,
    ).stdout.lower()
    return any(token in output for token in ("vga", "3d", "display"))


def detect_nics() -> list[str]:
    output = subprocess.run(
        ["ip", "-o", "link", "show"],
        capture_output=True,
        text=True,
        check=False,
    ).stdout.splitlines()
    nics: list[str] = []
    for line in output:
        if ": lo:" in line:
            continue
        name = line.split(": ", 2)[1].split("@", 1)[0]
        nics.append(name)
    return nics


def choose_recommended_model(ram_mb: int) -> str:
    if ram_mb >= 28000:
        return "llama3.1:8b"
    if ram_mb >= 12000:
        return "llama3.2:3b"
    return "llama3.2:1b"


def hardware_report() -> dict[str, Any]:
    ram_mb = detect_ram_mb()
    extra_disks = detect_extra_disks()
    nics = detect_nics()
    return {
        "ram_mb": ram_mb,
        "extra_disks": extra_disks,
        "gpu_detected": detect_gpu(),
        "nics": nics,
        "second_nic": len(nics) > 1,
        "recommended_model": choose_recommended_model(ram_mb),
    }


def run_command(command: list[str], stage: str, why: str) -> None:
    """Run a native install command and publish both intent and failure honestly."""
    STATE.publish(stage, why)
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        stderr = (result.stderr or result.stdout).strip()
        raise RuntimeError(f"{stage} failed: {stderr}")


def ensure_virtualenv(target: Path) -> None:
    if not target.exists():
        run_command(["python3", "-m", "venv", str(target)], "venv", f"Creating virtualenv at {target}")


def install_adguard_home() -> None:
    run_command(
        ["bash", "-lc", "curl -fsSL https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh"],
        "adguard",
        "Installing AdGuard Home natively for private DNS and blocking.",
    )


def install_vaultwarden() -> None:
    install_dir = Path("/opt/prism/vaultwarden")
    install_dir.mkdir(parents=True, exist_ok=True)
    archive = install_dir / "vaultwarden.tar.gz"
    run_command(
        ["wget", "-O", str(archive), "https://github.com/dani-garcia/vaultwarden/releases/latest/download/vaultwarden-x86_64-unknown-linux-gnu.tar.gz"],
        "vaultwarden",
        "Downloading Vaultwarden native binary release.",
    )
    run_command(
        ["tar", "-xzf", str(archive), "-C", str(install_dir)],
        "vaultwarden",
        "Extracting Vaultwarden into /opt/prism/vaultwarden.",
    )


def install_searxng() -> None:
    venv_dir = Path("/opt/prism/searxng-venv")
    ensure_virtualenv(venv_dir)
    pip = venv_dir / "bin" / "pip"
    run_command(
        [str(pip), "install", "searxng"],
        "searxng",
        "Installing SearXNG into an isolated Python virtualenv.",
    )


def install_paperless() -> None:
    venv_dir = Path("/opt/prism/paperless-venv")
    ensure_virtualenv(venv_dir)
    pip = venv_dir / "bin" / "pip"
    run_command(
        [str(pip), "install", "paperless-ngx"],
        "paperless",
        "Installing Paperless-ngx into an isolated Python virtualenv.",
    )


def install_headscale() -> None:
    binary = Path("/usr/local/bin/headscale")
    run_command(
        ["wget", "-O", str(binary), "https://github.com/juanfont/headscale/releases/latest/download/headscale_linux_amd64"],
        "headscale",
        "Downloading Headscale native binary.",
    )
    binary.chmod(0o755)


def install_jellyfin() -> None:
    run_command(
        ["bash", "-lc", "curl -fsSL https://repo.jellyfin.org/install-debuntu.sh | bash"],
        "jellyfin",
        "Installing Jellyfin because extra storage was detected and the owner opted in.",
    )


def install_stable_diffusion() -> None:
    STATE.publish(
        "stable-diffusion",
        "Stable Diffusion install is not implemented yet. GPU support still needs a native PRISM-specific path.",
        level="warning",
    )


def install_gateway_mode() -> None:
    STATE.publish(
        "gateway",
        "Gateway mode is not implemented yet. The second NIC was detected, but the native gateway path still needs design work.",
        level="warning",
    )


INSTALLERS = {
    "adguard": install_adguard_home,
    "vaultwarden": install_vaultwarden,
    "searxng": install_searxng,
    "paperless": install_paperless,
    "headscale": install_headscale,
    "jellyfin": install_jellyfin,
    "stable-diffusion": install_stable_diffusion,
    "gateway": install_gateway_mode,
}


def install_worker(request: dict[str, Any]) -> None:
    try:
        services = request.get("services", [])
        final_model = request.get("final_model") or choose_recommended_model(detect_ram_mb())
        STATE.final_model = final_model
        STATE.publish("setup", "Setup started. Iris will report progress here.")

        for service in services:
            installer = INSTALLERS.get(service)
            if installer is None:
                STATE.publish(service, f"Skipping unknown service '{service}'.", level="warning")
                continue
            installer()
            STATE.publish(service, f"{service} install step finished.")

        if final_model != "llama3.2:1b":
            run_command(
                ["/usr/local/bin/ollama", "pull", final_model],
                "model",
                f"Pulling the final Iris model {final_model} for normal use.",
            )
        STATE.publish("setup", "Service installation finished. Waiting for final completion handoff.")
    except Exception as exc:  # pragma: no cover - defensive path
        STATE.install_error = str(exc)
        STATE.publish("error", str(exc), level="error")
    finally:
        with STATE.lock:
            STATE.install_running = False


class Handler(BaseHTTPRequestHandler):
    """HTTP API for setup UI, hardware facts, progress, and completion signals."""

    server_version = "PrismSetupBackend/0.1"

    def _json(self, payload: Any, status: int = HTTPStatus.OK) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/hardware":
            self._json(hardware_report())
            return

        if self.path == "/progress":
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.end_headers()
            last_index = 0
            while True:
                with STATE.lock:
                    events = STATE.progress[last_index:]
                    done = not STATE.install_running and last_index < len(STATE.progress)
                for event in events:
                    self.wfile.write(f"data: {json.dumps(event)}\n\n".encode("utf-8"))
                    self.wfile.flush()
                    last_index += 1
                if done and last_index >= len(STATE.progress):
                    break
                time.sleep(1)
            return

        self._json({"error": "not found"}, status=HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        payload = json.loads(raw.decode("utf-8") or "{}")

        if self.path == "/install":
            with STATE.lock:
                if STATE.install_running:
                    self._json({"error": "install already running"}, status=HTTPStatus.CONFLICT)
                    return
                STATE.install_running = True
                STATE.install_error = None
                STATE.progress.clear()
            STATE.install_thread = threading.Thread(target=install_worker, args=(payload,), daemon=True)
            STATE.install_thread.start()
            self._json({"status": "started"})
            return

        if self.path == "/complete":
            STATE_DIR.mkdir(parents=True, exist_ok=True)
            SETUP_COMPLETE_FILE.write_text("complete\n", encoding="utf-8")
            STATE.publish("complete", "Setup completion signal written for firstboot handoff.")
            self._json({"status": "complete"})
            return

        self._json({"error": "not found"}, status=HTTPStatus.NOT_FOUND)

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"[prism-setup-backend] {fmt % args}")


def main() -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"[prism-setup-backend] listening on http://{HOST}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()

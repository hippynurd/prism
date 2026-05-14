#!/usr/bin/env bash
set -euo pipefail

# PRISM Net First Boot Script
# Option B: complete silent hardware setup before Iris opens in the browser.
# Iris reports what was done; firstboot owns hardware detection, GPU assignment,
# initial model selection, HTTP startup, and the local console banner.

STATE_DIR="/var/lib/prism"
STATE_FILE="$STATE_DIR/firstboot.done"
SETUP_STATE_FILE="$STATE_DIR/setup-state.json"
SETUP_COMPLETE_FILE="$STATE_DIR/setup-complete"
PERSONALITY_FILE="/etc/prism/iris-personality"
LOG_FILE="/var/log/prism-firstboot.log"
ASSET_DIR="/usr/local/share/prism"
SETUP_MODE_FILE="/etc/prism/setup-mode"
GPU_COMPLETE_FILE="/etc/prism/firstboot-gpu-complete"
AGENT_GPU_FILE="/etc/prism/agent-gpu"
OLLAMA_DROPIN_DIR="/etc/systemd/system/ollama.service.d"
OLLAMA_DROPIN_FILE="$OLLAMA_DROPIN_DIR/prism-gpu.conf"
SETUP_JOBS_DIR="/usr/local/lib/prism/setup-jobs"
PROBE_SCRIPT="$SETUP_JOBS_DIR/probe_hardware.sh"

OLLAMA_BIN="/usr/local/bin/ollama"
OLLAMA_SERVICE="ollama"
SETUP_SITE_LINK="/etc/nginx/sites-enabled/prism-setup"
IRIS_SITE_LINK="/etc/nginx/sites-enabled/prism-iris"

mkdir -p "$STATE_DIR" /etc/prism
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

# Exit cleanly if first boot already completed.
if [[ -f "$STATE_FILE" ]]; then
  exit 0
fi

echo "[prism] PRISM Net first boot starting at $(date -Is)"

# Setup mode is a boot-time internal state only. Hardware setup must finish
# before nginx exposes Iris to the browser.
printf 'setup\n' > "$SETUP_MODE_FILE"
rm -f "$SETUP_COMPLETE_FILE"
rm -f "$GPU_COMPLETE_FILE" "$AGENT_GPU_FILE"

# Record a default personality early so every later component has a sane value,
# even before Iris helps the user pick the final tone in the browser.
printf 'Friendly\n' > "$PERSONALITY_FILE"

log() {
  printf '[prism] %s\n' "$1"
}

warn() {
  printf '[prism] WARNING: %s\n' "$1" >&2
}

json_value() {
  local key="$1"
  python3 - "$SETUP_STATE_FILE" "$key" <<'PY' 2>/dev/null || true
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
key = sys.argv[2]
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    sys.exit(0)
value = data.get(key)
if value is None:
    sys.exit(0)
print(value)
PY
}

recommended_model_for_ram() {
  local ram_mb="$1"
  if (( ram_mb >= 28000 )); then
    printf 'llama3.1:8b\n'
  elif (( ram_mb >= 12000 )); then
    printf 'llama3.2:3b\n'
  else
    printf 'llama3.2:1b\n'
  fi
}

wait_for_ollama() {
  local attempts="${1:-30}"
  local i
  for ((i = 1; i <= attempts; i++)); do
    if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

start_ollama_cpu_temporarily() {
  log "PHASE 1: starting Ollama on CPU temporarily"
  if [[ ! -x "$OLLAMA_BIN" ]]; then
    warn "expected baked Ollama binary missing at $OLLAMA_BIN; Iris will open without local model service"
    return 1
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable "$OLLAMA_SERVICE" || warn "could not enable $OLLAMA_SERVICE"
    systemctl start "$OLLAMA_SERVICE" || warn "could not start $OLLAMA_SERVICE"
  fi
  wait_for_ollama 30 || warn "Ollama did not answer during temporary CPU startup"
}

run_hardware_probe() {
  log "PHASE 1: probing hardware"
  if [[ ! -x "$PROBE_SCRIPT" ]]; then
    warn "probe script missing at $PROBE_SCRIPT"
    return 1
  fi
  PRISM_STATE_FILE="$SETUP_STATE_FILE" PRISM_SETUP_COMPLETE_FILE="$SETUP_COMPLETE_FILE" "$PROBE_SCRIPT" || {
    warn "hardware probe failed"
    return 1
  }
}

configure_ollama_gpu() {
  local primary_index="$1"
  local agent_index="$2"
  local primary_name="$3"
  local primary_vram="$4"
  local agent_name="$5"
  local agent_vram="$6"

  log "PHASE 1: assigning NVIDIA GPU $primary_index to Ollama (${primary_name}, ${primary_vram}MB)"
  install -d "$OLLAMA_DROPIN_DIR"
  cat > "$OLLAMA_DROPIN_FILE" <<EOF
[Service]
Environment=OLLAMA_HOST=127.0.0.1:11434
Environment=CUDA_VISIBLE_DEVICES=${primary_index}
EOF
  if [[ -n "$agent_index" ]]; then
    printf '%s\n' "$agent_index" > "$AGENT_GPU_FILE"
    log "PHASE 1: reserving NVIDIA GPU $agent_index for agent workloads (${agent_name}, ${agent_vram}MB)"
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || warn "systemd daemon-reload failed after GPU assignment"
    systemctl restart "$OLLAMA_SERVICE" || {
      warn "Ollama restart failed after GPU assignment"
      return 1
    }
  fi
  wait_for_ollama 60 || {
    warn "Ollama did not confirm running after GPU assignment"
    return 1
  }
  log "PHASE 1: Ollama confirmed running on assigned GPU"
}

gpu_plan() {
  python3 - "$SETUP_STATE_FILE" <<'PY' 2>/dev/null || true
import json
import sys
from pathlib import Path

try:
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
except Exception:
    sys.exit(0)
gpus = data.get("nvidia_gpus") or []
if not data.get("gpu_usable") or not gpus:
    sys.exit(0)
primary = gpus[0]
agent = gpus[1] if len(gpus) > 1 else {}
print("|".join([
    str(primary.get("index", "")),
    str(agent.get("index", "")),
    str(primary.get("name", "")),
    str(primary.get("vram_mb", "")),
    str(agent.get("name", "")),
    str(agent.get("vram_mb", "")),
]))
PY
}

pull_model_if_needed() {
  local model="$1"
  if [[ -z "$model" ]]; then
    warn "no model selected; skipping model pull"
    return 0
  fi
  if [[ ! -x "$OLLAMA_BIN" ]]; then
    warn "Ollama binary missing; skipping model pull"
    return 0
  fi
  wait_for_ollama 30 || {
    warn "Ollama unavailable; skipping model pull for $model"
    return 0
  }
  if "$OLLAMA_BIN" list | awk -v model="$model" 'NR > 1 && $1 == model { found = 1 } END { exit found ? 0 : 1 }'; then
    log "PHASE 1: model already present: $model"
    return 0
  fi
  log "PHASE 1: pulling model $model"
  PRISM_MODEL="$model" "$SETUP_JOBS_DIR/install_model.sh" || warn "model pull failed for $model"
}

start_ollama_cpu_temporarily || true
run_hardware_probe || true

memory_mb="$(json_value total_ram_mb)"
memory_mb="${memory_mb:-0}"
recommended_model="$(json_value recommended_model)"
recommended_model="${recommended_model:-$(recommended_model_for_ram "$memory_mb")}"
gpu_details="$(gpu_plan)"

if [[ -n "$gpu_details" ]]; then
  IFS='|' read -r primary_gpu_index agent_gpu_index primary_gpu_name primary_gpu_vram agent_gpu_name agent_gpu_vram <<< "$gpu_details"
  configure_ollama_gpu "$primary_gpu_index" "$agent_gpu_index" "$primary_gpu_name" "$primary_gpu_vram" "$agent_gpu_name" "$agent_gpu_vram" || true
else
  if (( memory_mb < 8000 )); then
    log "PHASE 1: no usable GPU and ${memory_mb}MB RAM; skipping Ollama and using scripted fallback"
    recommended_model=""
    systemctl stop "$OLLAMA_SERVICE" || warn "could not stop $OLLAMA_SERVICE for scripted fallback"
  elif (( memory_mb < 12000 )); then
    recommended_model="llama3.2:1b"
    log "PHASE 1: no usable GPU and ${memory_mb}MB RAM; choosing CPU model $recommended_model"
  elif (( memory_mb < 28000 )); then
    recommended_model="llama3.2:3b"
    log "PHASE 1: no usable GPU and ${memory_mb}MB RAM; choosing CPU model $recommended_model"
  else
    recommended_model="llama3.1:8b"
    log "PHASE 1: no usable GPU and ${memory_mb}MB RAM; choosing CPU model $recommended_model"
  fi
fi

pull_model_if_needed "$recommended_model"
printf 'complete\n' > "$GPU_COMPLETE_FILE"
log "PHASE 1: firstboot hardware setup complete"

# Credential policy: first boot must not silently change passwords.
# The current documented temporary console bootstrap is root / prism, set by
# the image build. Mothership SSH key access remains available when the image
# is factory-provisioned.
echo "[prism] Leaving documented bootstrap credentials unchanged"

# PHASE 2: open Iris only after silent hardware setup has completed.
log "PHASE 2: switching nginx to Iris normal mode"
rm -f /etc/nginx/sites-enabled/default "$SETUP_SITE_LINK"
if [[ -f /etc/nginx/sites-available/prism-iris ]]; then
  ln -sf /etc/nginx/sites-available/prism-iris "$IRIS_SITE_LINK"
else
  warn "Iris nginx site missing at /etc/nginx/sites-available/prism-iris"
fi
if command -v nginx >/dev/null 2>&1; then
  nginx -t && {
    systemctl enable nginx || warn "could not enable nginx"
    if systemctl is-active --quiet nginx; then
      systemctl reload nginx || warn "could not reload nginx"
    else
      systemctl restart nginx || warn "could not start nginx"
    fi
  } || warn "nginx configuration validation failed"
else
  warn "nginx not found; HTTP will not be available"
fi

# First boot is complete. Remove setup markers so future boots go directly to
# the normal PRISM experience.
printf 'complete\n' > "$SETUP_COMPLETE_FILE"
touch "$STATE_FILE"
rm -f "$SETUP_MODE_FILE"
echo "[prism] First boot marked complete"

# Play the clip once. Audio failure should never block a usable system.
mpg123 -q "$ASSET_DIR/llama.mp3" 2>/dev/null || true

# Display the final banner and documented bootstrap policy on the local console.
if [[ -w /dev/tty1 ]]; then
  exec 3>/dev/tty1
  printf '\n' >&3
  printf '\033[1;35m  ██████╗ \033[1;31m██████╗ \033[1;33m██╗\033[1;32m███████╗\033[1;36m███╗   ███╗\033[0m\n' >&3
  printf '\033[1;35m  ██╔══██╗\033[1;31m██╔══██╗\033[1;33m██║\033[1;32m██╔════╝\033[1;36m████╗ ████║\033[0m\n' >&3
  printf '\033[1;35m  ██████╔╝\033[1;31m██████╔╝\033[1;33m██║\033[1;32m███████╗\033[1;36m██╔████╔██║\033[0m\n' >&3
  printf '\033[1;35m  ██╔═══╝ \033[1;31m██╔══██╗\033[1;33m██║\033[1;32m╚════██║\033[1;36m██║╚██╔╝██║\033[0m\n' >&3
  printf '\033[1;35m  ██║     \033[1;31m██║  ██║\033[1;33m██║\033[1;32m███████║\033[1;36m██║ ╚═╝ ██║\033[0m\n' >&3
  printf '\033[1;35m  ╚═╝     \033[1;31m╚═╝  ╚═╝\033[1;33m╚═╝\033[1;32m╚══════╝\033[1;36m╚═╝     ╚═╝\033[0m\n' >&3
  printf '\n' >&3
  printf '\033[1;32m  Your PRISM is ready.\033[0m\n' >&3
  printf '\n' >&3
  printf '  Iris personality : \033[1;36m%s\033[0m\n' "$(cat "$PERSONALITY_FILE" 2>/dev/null || echo Friendly)" >&3
  printf '  Model            : \033[1;36m%s\033[0m\n' "${recommended_model:-scripted fallback}" >&3
  printf '\n' >&3
  printf '  Console login    : \033[1;33mroot / prism\033[0m\n' >&3
  printf '  SSH access       : mothership factory key when provisioned\n' >&3
  printf '  First boot does not randomize or silently change credentials.\n' >&3
  printf '\n' >&3
  printf '  Open browser to \033[1;32mhttp://prism.local\033[0m to meet Iris.\n' >&3
  printf '\n' >&3
  exec 3>&-
else
  warn "/dev/tty1 not writable; skipping local console banner"
fi

echo "[prism] PRISM Net first boot finished at $(date -Is)"

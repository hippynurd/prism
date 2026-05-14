#!/usr/bin/env bash
set -euo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "enable_gpu_for_iris must run as root" >&2; exit 1; }
command -v nvidia-smi >/dev/null 2>&1 || { echo "nvidia-smi not found" >&2; exit 1; }
nvidia-smi

install -d /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/prism-gpu.conf <<'EOF'
[Service]
Environment=OLLAMA_HOST=127.0.0.1:11434
Environment=CUDA_VISIBLE_DEVICES=0
EOF

systemctl daemon-reload
systemctl restart ollama
systemctl is-active --quiet ollama
curl -fsS http://127.0.0.1:11434/api/tags >/dev/null
nvidia-smi
echo "Ollama restarted with PRISM GPU override"

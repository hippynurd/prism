#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_HOST="${PRISM_CHECKPOINT_HOST:-prism-115}"
STAMP="$(date +%Y%m%d-%H%M%S)"
CHECKPOINT_ROOT="$REPO_ROOT/checkpoints"
CHECKPOINT_DIR="$CHECKPOINT_ROOT/${STAMP}-lightweight"
LIVE_DIR="$CHECKPOINT_DIR/live-115"
COMMAND_DIR="$CHECKPOINT_DIR/commands"
ENDPOINT_DIR="$CHECKPOINT_DIR/endpoints"
DOCS_DIR="$CHECKPOINT_DIR/docs"
MAX_BYTES=$((25 * 1024 * 1024))
MAX_COPY_BYTES=$((2 * 1024 * 1024))

mkdir -p "$LIVE_DIR" "$COMMAND_DIR" "$ENDPOINT_DIR" "$DOCS_DIR"

redact_file() {
  local path="$1"
  perl -0pi \
    -e 's/\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b/[REDACTED_MAC]/g;' \
    -e 's/\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b/[REDACTED_UUID]/g;' \
    -e 's#/dev/disk/by-id/[^\s",]+#[REDACTED_DISK_BY_ID]#g;' \
    -e 's/\b(?:sk|pk|ghp|github_pat|xox[baprs])-?[A-Za-z0-9_\-]{16,}\b/[REDACTED_TOKEN]/g;' \
    -e 's/(password|passwd|token|cookie|private_key|api[_-]?key)(["'"'"']?\s*[:=]\s*["'"'"']?)[^"'"'"'\s,}]+/$1$2[REDACTED]/gi;' \
    "$path"
}

write_text() {
  local path="$1"
  shift
  printf '%s\n' "$@" > "$path"
}

safe_remote_copy() {
  local remote_path="$1"
  local local_name="$2"
  local dest="$LIVE_DIR/$local_name"
  local size
  size="$(ssh "$TARGET_HOST" "if [ -f '$remote_path' ]; then stat -c %s '$remote_path'; fi" 2>/dev/null || true)"
  if [[ -z "$size" ]]; then
    write_text "$dest.missing" "missing: $remote_path"
    return 0
  fi
  if (( size > MAX_COPY_BYTES )); then
    write_text "$dest.skipped" "skipped: $remote_path" "size_bytes: $size" "reason: exceeds $MAX_COPY_BYTES byte lightweight copy limit"
    return 0
  fi
  scp -q "$TARGET_HOST:$remote_path" "$dest"
  redact_file "$dest"
}

safe_remote_glob_copy() {
  local remote_glob="$1"
  local subdir="$2"
  local dest_dir="$LIVE_DIR/$subdir"
  mkdir -p "$dest_dir"
  ssh "$TARGET_HOST" "for f in $remote_glob; do [ -f \"\$f\" ] && printf '%s\\n' \"\$f\"; done" 2>/dev/null |
    while IFS= read -r remote_path; do
      [[ -n "$remote_path" ]] || continue
      local base
      base="$(basename "$remote_path")"
      local size
      size="$(ssh "$TARGET_HOST" "stat -c %s '$remote_path'" 2>/dev/null || true)"
      if [[ -z "$size" ]]; then
        continue
      fi
      if (( size > MAX_COPY_BYTES )); then
        write_text "$dest_dir/$base.skipped" "skipped: $remote_path" "size_bytes: $size" "reason: exceeds $MAX_COPY_BYTES byte lightweight copy limit"
        continue
      fi
      scp -q "$TARGET_HOST:$remote_path" "$dest_dir/$base"
      redact_file "$dest_dir/$base"
    done
}

capture_remote_command() {
  local name="$1"
  shift
  local dest="$COMMAND_DIR/$name.txt"
  ssh "$TARGET_HOST" "$*" > "$dest" 2>&1 || true
  redact_file "$dest"
}

capture_endpoint_summary() {
  local name="$1"
  local method="$2"
  local path="$3"
  local body="${4:-}"
  local dest="$ENDPOINT_DIR/$name.txt"
  python3 - "$method" "http://192.168.14.115$path" "$body" > "$dest" <<'PY'
import json
import sys
import urllib.error
import urllib.request

method, url, body = sys.argv[1], sys.argv[2], sys.argv[3]
data = body.encode("utf-8") if body else None
headers = {"Content-Type": "application/json"} if body else {}
request = urllib.request.Request(url, data=data, headers=headers, method=method)
try:
    with urllib.request.urlopen(request, timeout=30) as response:
        status = response.status
        content_type = response.headers.get("Content-Type", "")
        raw = response.read(1024 * 1024).decode("utf-8", errors="replace")
except urllib.error.HTTPError as exc:
    status = exc.code
    content_type = exc.headers.get("Content-Type", "")
    raw = exc.read(64 * 1024).decode("utf-8", errors="replace")
except Exception as exc:
    print(f"status: unavailable")
    print(f"content_type: unknown")
    print(f"error_type: {type(exc).__name__}")
    raise SystemExit(0)

print(f"status: {status}")
print(f"content_type: {content_type}")

summary = {}
if "application/json" in content_type.lower():
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        payload = {}
    for key in (
        "endpoint",
        "read_only",
        "overall",
        "status",
        "summary",
        "changed_files",
        "changed_services",
        "confidence",
        "next_safe_action",
    ):
        if key in payload:
            summary[key] = payload[key]
    if "hardware_summary" in payload:
        summary["hardware_summary"] = payload["hardware_summary"]
    if "capability_tiers" in payload:
        summary["capability_tiers"] = payload["capability_tiers"]
    print("json_summary:")
    print(json.dumps(summary, indent=2, sort_keys=True))
PY
  redact_file "$dest"
}

{
  echo "timestamp: $(date -Is)"
  echo "repo: $REPO_ROOT"
  echo "head: $(git -C "$REPO_ROOT" rev-parse HEAD)"
  echo
  echo "git status:"
  git -C "$REPO_ROOT" status --short
  echo
  echo "recent tags:"
  git -C "$REPO_ROOT" tag --list '*202605*' --sort=creatordate
} > "$COMMAND_DIR/git-summary.txt"

cp "$REPO_ROOT/AGENTS.md" "$DOCS_DIR/AGENTS.md"
cp "$REPO_ROOT/docs/PRISM_CURRENT_STATE.md" "$DOCS_DIR/PRISM_CURRENT_STATE.md"
cp "$REPO_ROOT/docs/PRISM_CAPABILITY_PLANNER_HAND_20260517.md" "$DOCS_DIR/PRISM_CAPABILITY_PLANNER_HAND_20260517.md"

safe_remote_copy "/usr/local/bin/prism-setup-backend" "prism-setup-backend"
safe_remote_copy "/var/www/prism-chat/index.html" "index.html"
safe_remote_copy "/etc/nginx/sites-available/prism-iris" "prism-iris.nginx"
safe_remote_copy "/etc/update-motd.d/10-prism" "10-prism.motd"
safe_remote_glob_copy "/usr/local/lib/prism/setup-jobs/*.sh" "setup-jobs"

capture_remote_command "systemctl-is-active" "systemctl is-active prism-setup-backend nginx ollama"
capture_remote_command "nginx-test" "nginx -t"

capture_endpoint_summary "setup-state" "GET" "/setup/state"
capture_endpoint_summary "check-prism-status" "POST" "/setup/check-prism-status"
capture_endpoint_summary "check-install-readiness" "POST" "/setup/check-install-readiness"
capture_endpoint_summary "diagnose-install-blockers" "POST" "/setup/diagnose-install-blockers"
capture_endpoint_summary "check-ai-runner-readiness" "POST" "/setup/check-ai-runner-readiness"
capture_endpoint_summary "analyze-capabilities" "POST" "/setup/analyze-capabilities" '{"goals":["privacy","local_ai"]}'
capture_endpoint_summary "setup-jobs-blocked" "GET" "/setup/jobs"
capture_endpoint_summary "hardware-blocked" "GET" "/hardware"
capture_endpoint_summary "setup-hardware-blocked" "GET" "/setup/hardware"

find "$CHECKPOINT_DIR" -type f -print0 | sort -z | xargs -0 sha256sum > "$CHECKPOINT_DIR/SHA256SUMS"

total_bytes="$(du -sb "$CHECKPOINT_DIR" | awk '{print $1}')"
{
  echo "# PRISM Lightweight Checkpoint"
  echo
  echo "- timestamp: $(date -Is)"
  echo "- checkpoint_dir: $CHECKPOINT_DIR"
  echo "- target_host: $TARGET_HOST"
  echo "- repo_head: $(git -C "$REPO_ROOT" rev-parse HEAD)"
  echo "- size_bytes: $total_bytes"
  echo "- size_warning: $([[ "$total_bytes" -gt "$MAX_BYTES" ]] && echo "exceeds_25MB" || echo "ok")"
  echo
  echo "## Safety Note"
  echo
  echo "This checkpoint is intended to contain only small text/config files and redacted summaries."
  echo "It must not contain disk images, VM images, ISOs, model blobs, Tiny Iris artifacts, private keys, tokens, cookies, passwords, raw MACs, disk serials, WWNs, or UUID-like hardware IDs."
  echo
  echo "## Files"
  echo
  find "$CHECKPOINT_DIR" -type f | sed "s#^$CHECKPOINT_DIR/##" | sort | sed 's/^/- /'
  echo
  echo "## Checksums"
  echo
  echo "See SHA256SUMS."
} > "$CHECKPOINT_DIR/MANIFEST.md"

if (( total_bytes > MAX_BYTES )); then
  echo "WARNING: checkpoint exceeds 25MB: $total_bytes bytes" >&2
fi

echo "$CHECKPOINT_DIR"

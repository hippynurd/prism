#!/usr/bin/env bash
set -euo pipefail

result_path="${PRISM_JOB_RESULT:-}"
if [[ -z "$result_path" ]]; then
  echo "PRISM_JOB_RESULT is required" >&2
  exit 2
fi

tmp_result="${result_path}.tmp"
cat > "$tmp_result" <<'JSON'
{
  "endpoint": "analyze-capabilities",
  "read_only": true,
  "changed_files": [],
  "changed_services": [],
  "status": "unavailable",
  "summary": "Capability analysis is implemented by the PRISM setup backend endpoint, not by this script."
}
JSON
mv "$tmp_result" "$result_path"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

failures=0

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

required_files=(
  "$REPO_ROOT/Makefile"
  "$REPO_ROOT/configs/packages.base"
  "$REPO_ROOT/configs/packages.net"
  "$REPO_ROOT/scripts/build-prism-image.sh"
  "$REPO_ROOT/scripts/build-prism-net.sh"
  "$REPO_ROOT/scripts/install-prism-assets.sh"
  "$REPO_ROOT/scripts/install-prism-net-assets.sh"
  "$REPO_ROOT/scripts/validate-repo.sh"
  "$REPO_ROOT/net/first-boot/prism-firstboot.sh"
  "$REPO_ROOT/net/nginx/prism-setup.conf"
  "$REPO_ROOT/net/nginx/prism-iris.conf"
  "$REPO_ROOT/net/motd/10-prism"
  "$REPO_ROOT/net/ui/index.html"
  "$REPO_ROOT/net/ui/prism-setup-backend.py"
  "$REPO_ROOT/net/installers/install-ollama.sh"
  "$REPO_ROOT/net/installers/install-adguard.sh"
  "$REPO_ROOT/net/installers/install-vaultwarden.sh"
  "$REPO_ROOT/net/installers/install-searxng.sh"
  "$REPO_ROOT/net/installers/install-paperless.sh"
  "$REPO_ROOT/net/installers/install-headscale.sh"
)

echo "[validate] Checking required files"
for file in "${required_files[@]}"; do
  if [[ -e "$file" ]]; then
    pass "required file present: ${file#$REPO_ROOT/}"
  else
    fail "required file missing: ${file#$REPO_ROOT/}"
  fi
done

echo "[validate] Checking for hard-coded /vault paths"
vault_pattern="/vault""/pve-media"
if grep -RIn "$vault_pattern" "$REPO_ROOT" >/tmp/prism-validate-vault-hits.txt; then
  while IFS= read -r line; do
    fail "hard-coded path found: $line"
  done </tmp/prism-validate-vault-hits.txt
else
  pass "no hard-coded /vault paths remain"
fi
rm -f /tmp/prism-validate-vault-hits.txt

echo "[validate] Checking shell scripts"
mapfile -t shell_scripts < <(find "$REPO_ROOT" -type f \( -name '*.sh' -o -path '*/10-prism' \) | sort)
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "${shell_scripts[@]}"; then
    pass "shellcheck passed"
  else
    fail "shellcheck reported issues"
  fi
else
  pass "shellcheck not installed; skipped"
fi

echo "[validate] Checking Python syntax"
mapfile -t python_files < <(find "$REPO_ROOT" -type f -name '*.py' | sort)
for file in "${python_files[@]}"; do
  if python3 -m py_compile "$file"; then
    pass "python syntax ok: ${file#$REPO_ROOT/}"
  else
    fail "python syntax failed: ${file#$REPO_ROOT/}"
  fi
done

if (( failures > 0 )); then
  echo "VALIDATION RESULT: FAIL ($failures issue(s))" >&2
  exit 1
fi

echo "VALIDATION RESULT: PASS"

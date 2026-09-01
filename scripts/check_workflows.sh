#!/usr/bin/env bash
set -euo pipefail

if command -v actionlint >/dev/null 2>&1; then
  actionlint_bin="$(command -v actionlint)"
else
  actionlint_version="1.7.12"
  case "$(uname -s)-$(uname -m)" in
    Linux-aarch64|Linux-arm64)
      actionlint_platform="linux_arm64"
      actionlint_sha256="325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6"
      ;;
    Linux-x86_64)
      actionlint_platform="linux_amd64"
      actionlint_sha256="8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8"
      ;;
    Darwin-arm64)
      actionlint_platform="darwin_arm64"
      actionlint_sha256="aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f"
      ;;
    Darwin-x86_64)
      actionlint_platform="darwin_amd64"
      actionlint_sha256="5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644"
      ;;
    *)
      echo "Unsupported actionlint platform: $(uname -s)-$(uname -m)" >&2
      exit 1
      ;;
  esac

  workflow_lint_tmp="$(mktemp -d)"
  trap 'rm -rf -- "$workflow_lint_tmp"' EXIT
  actionlint_archive="${workflow_lint_tmp}/actionlint.tar.gz"
  curl --fail --location --silent --show-error --retry 3 \
    --output "${actionlint_archive}" \
    "https://github.com/rhysd/actionlint/releases/download/v${actionlint_version}/actionlint_${actionlint_version}_${actionlint_platform}.tar.gz"
  python3 - "${actionlint_archive}" "${actionlint_sha256}" <<'PY'
import hashlib
import sys
from pathlib import Path

archive = Path(sys.argv[1])
expected = sys.argv[2]
actual = hashlib.sha256(archive.read_bytes()).hexdigest()
if actual != expected:
    raise SystemExit(f"actionlint archive SHA-256 mismatch: expected {expected}, got {actual}")
PY
  tar -xzf "${actionlint_archive}" -C "${workflow_lint_tmp}" actionlint
  actionlint_bin="${workflow_lint_tmp}/actionlint"
fi

export ACTIONLINT_BIN="${actionlint_bin}"
python3 tools/check_release_workflow_contract.py
python3 tools/check_workflow_contract.py

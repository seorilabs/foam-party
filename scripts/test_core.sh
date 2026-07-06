#!/usr/bin/env bash
set -euo pipefail

required_dirs=(
  "packages/product-core/src/domain"
  "packages/product-core/src/use_cases"
  "packages/product-core/src/ports"
  "packages/product-core/tests"
)

for dir in "${required_dirs[@]}"; do
  if [ ! -d "${dir}" ]; then
    echo "Missing core directory: ${dir}" >&2
    exit 1
  fi
done

godot_bin="${GODOT_BIN:-godot}"
project="${GODOT_PROJECT:-godot}"
core_scene="${CORE_TEST_SCENE:-res://tests/core_test.gd}"
timeout_secs="${CORE_TEST_TIMEOUT:-120}"

log_dir="${CORE_TEST_LOG_DIR:-}"
if [ -z "${log_dir}" ]; then
  log_dir="$(mktemp -d)"
else
  mkdir -p "${log_dir}"
fi
log_file="${log_dir}/core_test.log"

run_with_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "${timeout_secs}" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "${timeout_secs}" "$@"
  else
    "$@"
  fi
}

echo "[test-core] running pure core tests: ${core_scene}" >&2
set +e
run_with_timeout "${godot_bin}" --headless --path "${project}" --script "${core_scene}" 2>&1 | tee "${log_file}"
status="${PIPESTATUS[0]}"
set -e

if [ "${status}" -ne 0 ]; then
  echo "[test-core] core tests failed with exit ${status}. Log: ${log_file}" >&2
  exit "${status}"
fi

# Mirror scripts/godot_quality_gate.sh: fail on any error/FAIL log line even if
# Godot exited zero.
if grep -E "^(CORE TEST FAIL|SCRIPT ERROR|ERROR:)" "${log_file}" >/dev/null; then
  echo "[test-core] core tests reported errors. Log: ${log_file}" >&2
  grep -E "^(CORE TEST FAIL|SCRIPT ERROR|ERROR:)" "${log_file}" >&2 || true
  exit 1
fi

if ! grep -q "CORE TESTS PASSED" "${log_file}"; then
  echo "[test-core] core tests did not report success. Log: ${log_file}" >&2
  exit 1
fi

echo "[test-core] core tests passed. Log: ${log_file}" >&2

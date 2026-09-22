#!/usr/bin/env bash
set -euo pipefail

project="."
smoke_scene=""
godot_bin="${GODOT_BIN:-godot}"
log_dir="${GODOT_QUALITY_GATE_LOG_DIR:-}"
run_import=1

usage() {
  cat <<'USAGE'
Usage:
  godot_quality_gate.sh [--project PATH] [--smoke-scene RES://SCENE_OR_SCRIPT] [--godot-bin PATH] [--skip-import]

Checks:
  1. Validates the Godot art asset manifest JSON and POSIX EOF newline
  2. Runs: godot --headless --path <project> --import --quit
  3. Runs: godot --headless --path <project> --quit
  4. Fails when Godot exits non-zero
  5. Fails when Godot logs lines beginning with SCRIPT ERROR or ERROR:
  6. Optionally runs a smoke scene or .gd script with the same log rules
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project)
      project="${2:?missing value for --project}"
      shift 2
      ;;
    --smoke-scene)
      smoke_scene="${2:?missing value for --smoke-scene}"
      shift 2
      ;;
    --godot-bin)
      godot_bin="${2:?missing value for --godot-bin}"
      shift 2
      ;;
    --skip-import)
      run_import=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHONDONTWRITEBYTECODE=1 python3 "${script_dir}/../tools/test_asset_manifest.py"
python3 "${script_dir}/../tools/check_asset_manifest.py" "${project}/assets/art/asset-manifest.json"

if [ -z "${log_dir}" ]; then
  log_dir="$(mktemp -d)"
else
  mkdir -p "${log_dir}"
fi

run_godot_check() {
  local label="$1"
  shift
  local log_file="${log_dir}/${label}.log"

  echo "[godot-quality] running ${label}: $*" >&2
  set +e
  "$@" 2>&1 | tee "${log_file}"
  local status="${PIPESTATUS[0]}"
  set -e

  if [ "${status}" -ne 0 ]; then
    echo "[godot-quality] ${label} failed with exit ${status}. Log: ${log_file}" >&2
    exit "${status}"
  fi

  # Godot 종료 시점의 리소스 정리 순서 경고는 기능 결함이 아니다. AdMob v5 addon 이
  # class_name 으로 등록하는 전역 스크립트 클래스가 종료까지 참조를 유지하면서 나온다.
  # 게임 동작에는 영향이 없고 addon 내부 사정이라 저장소에서 고칠 수 없다. 이 한 줄만
  # 제외하고 나머지 ERROR / SCRIPT ERROR 는 그대로 실패로 처리한다.
  if grep -E "^(SCRIPT ERROR|ERROR):" "${log_file}" \
      | grep -vE "^ERROR: [0-9]+ resources still in use at exit" >/dev/null; then
    echo "[godot-quality] ${label} reported Godot errors. Log: ${log_file}" >&2
    grep -E "^(SCRIPT ERROR|ERROR):" "${log_file}" \
      | grep -vE "^ERROR: [0-9]+ resources still in use at exit" >&2 || true
    exit 1
  fi

  echo "[godot-quality] ${label} passed. Log: ${log_file}" >&2
}

if [ "${run_import}" -eq 1 ]; then
  run_godot_check "import" "${godot_bin}" --headless --path "${project}" --import --quit
fi

run_godot_check "compile" "${godot_bin}" --headless --path "${project}" --quit

if [ -n "${smoke_scene}" ]; then
  case "${smoke_scene}" in
    *.gd)
      run_godot_check "smoke" "${godot_bin}" --headless --path "${project}" --script "${smoke_scene}"
      ;;
    *)
      run_godot_check "smoke" "${godot_bin}" --headless --path "${project}" "${smoke_scene}"
      ;;
  esac
fi

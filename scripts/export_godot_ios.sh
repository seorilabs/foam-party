#!/usr/bin/env bash
set -euo pipefail

# iOS Xcode 프로젝트 export (아카이브 전 단계).
#
# Godot 의 iOS export 는 Xcode 프로젝트를 산출한다(헤드리스/Linux/macOS 동작, Team ID 필요).
# 실제 .xcarchive 아카이브와 App Store Connect 업로드는 macOS/Xcode runner 에서
# 재사용 워크플로우 godot-deploy-app-store.yml 가 수행한다.
#
# 재사용 워크플로우가 주입하는 env(우선) / 로컬 실행용 GODOT_* env(폴백):
#   PROJECT_DIR       / GODOT_PROJECT_DIR   : Godot 프로젝트 경로 (기본 godot)
#   IOS_EXPORT_PRESET / GODOT_IOS_PRESET    : 프리셋 이름 (기본 iOS)
#   IOS_OUTPUT        / GODOT_IOS_OUTPUT     : Xcode 프로젝트 출력 경로 prefix (기본 build/ios/foam-party)
#   IOS_BUNDLE_ID     / GODOT_IOS_BUNDLE_ID  : 번들 ID (기본 com.seorilabs.foamparty)
#   APPLE_TEAM_ID                            : Apple Developer Team ID (기본 HCDUXX4Z3X)
#   GODOT_VERSION / GODOT_STATUS
#
# 산출물: <repo>/<IOS_OUTPUT>.xcodeproj (재사용 워크플로우가 이 경로에서 xcodebuild archive).

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

project_dir="${PROJECT_DIR:-${GODOT_PROJECT_DIR:-godot}}"
preset="${IOS_EXPORT_PRESET:-${GODOT_IOS_PRESET:-iOS}}"
output_rel="${IOS_OUTPUT:-${GODOT_IOS_OUTPUT:-build/ios/foam-party}}"
bundle_id="${IOS_BUNDLE_ID:-${GODOT_IOS_BUNDLE_ID:-com.seorilabs.foamparty}}"
app_name="${GODOT_IOS_APP_NAME:-폼 파티}"
team_id="${APPLE_TEAM_ID:-HCDUXX4Z3X}"
log_dir="${GODOT_IOS_LOG_DIR:-${repo_root}/build/logs}"

# godot 은 상대 export 경로를 --path 프로젝트 기준으로 해석하므로 절대 경로로 정규화한다.
case "${output_rel}" in
  /*) output_abs="${output_rel}" ;;
  *)  output_abs="${repo_root}/${output_rel}" ;;
esac
xcodeproj_target="${output_abs%.xcodeproj}.xcodeproj"

preset_file="${project_dir}/export_presets.cfg"
backup_file=""
preset_was_created=0

cleanup() {
  if [ -n "${backup_file}" ] && [ -f "${backup_file}" ]; then
    cp "${backup_file}" "${preset_file}"
    rm -f "${backup_file}"
  elif [ "${preset_was_created}" -eq 1 ]; then
    rm -f "${preset_file}"
  fi
}
trap cleanup EXIT

fail() {
  echo "[godot-ios] $1" >&2
  exit 1
}

[ -n "${team_id}" ] || fail "APPLE_TEAM_ID 가 필요하다."
command -v godot >/dev/null 2>&1 || fail "godot 바이너리가 PATH 에 없다. scripts/ensure_godot.sh 참고."

mkdir -p "${log_dir}" "$(dirname "${xcodeproj_target}")"

if [ -f "${preset_file}" ]; then
  backup_file="$(mktemp)"
  cp "${preset_file}" "${backup_file}"
else
  preset_was_created=1
fi

next_index() {
  if [ ! -f "${preset_file}" ]; then printf '0\n'; return; fi
  awk '
    /^\[preset\.[0-9]+\]$/ {
      v = $0; gsub(/^\[preset\.|\]$/, "", v)
      if (v + 0 >= max) max = v + 1
    }
    END { print max + 0 }
  ' "${preset_file}"
}

# 프로젝트에 iOS 프리셋이 없을 때만 임시로 생성한다(foam-party 는 이미 "iOS" 프리셋 보유 → skip).
if ! { [ -f "${preset_file}" ] && grep -q "^name=\"${preset}\"$" "${preset_file}" && grep -q '^platform="iOS"$' "${preset_file}"; }; then
  index="$(next_index)"
  cat >> "${preset_file}" <<EOF

[preset.${index}]

name="${preset}"
platform="iOS"
runnable=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="${output_rel}.ipa"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.${index}.options]

application/app_store_team_id="${team_id}"
application/bundle_identifier="${bundle_id}"
application/name="${app_name}"
application/short_version="0.1.0"
application/version="1"
application/min_ios_version="13.0"
application/export_method_release=0
application/export_project_only=true
EOF
fi

import_log="${log_dir}/godot-ios-import.log"
export_log="${log_dir}/godot-ios-export.log"

echo "[godot-ios] importing resources" >&2
set +e
godot --headless --path "${project_dir}" --import --quit 2>&1 | tee "${import_log}"
import_status="${PIPESTATUS[0]}"
set -e
[ "${import_status}" -eq 0 ] || fail "import failed (exit ${import_status}). Log: ${import_log}"
if grep -E "^(SCRIPT ERROR|ERROR):" "${import_log}" >/dev/null; then
  grep -E "^(SCRIPT ERROR|ERROR):" "${import_log}" >&2 || true
  fail "import 중 Godot 오류. Log: ${import_log}"
fi

echo "[godot-ios] exporting ${preset} -> ${xcodeproj_target}" >&2
set +e
godot --headless --path "${project_dir}" --export-release "${preset}" "${xcodeproj_target}" 2>&1 | tee "${export_log}"
export_status="${PIPESTATUS[0]}"
set -e
[ "${export_status}" -eq 0 ] || fail "export failed (exit ${export_status}). Log: ${export_log}"
if grep -E "^(SCRIPT ERROR|ERROR):" "${export_log}" >/dev/null; then
  grep -E "^(SCRIPT ERROR|ERROR):" "${export_log}" >&2 || true
  fail "export 중 Godot 오류. Log: ${export_log}"
fi

[ -d "${xcodeproj_target}" ] || fail "Xcode 프로젝트가 생성되지 않았다: ${xcodeproj_target}"
echo "[godot-ios] Xcode 프로젝트 생성 완료: ${xcodeproj_target}" >&2

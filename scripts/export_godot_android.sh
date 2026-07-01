#!/usr/bin/env bash
set -euo pipefail

# Android release AAB export (로컬/수동 빌드용).
#
# Godot 쪽 동작은 헤드리스로 검증한다(프리셋 키, gradle 빌드 템플릿 설치 인식,
# editor settings 의 android_sdk_path/java_sdk_path 를 통한 SDK 인식). 실제 서명된
# AAB 산출에는 Android SDK(platform-tools/build-tools) 와 릴리스 keystore 가 필요하며,
# 이 값들은 CI 에서 secret/runner 로 주입한다.
#
# 참고: org 재사용 워크플로우 godot-deploy-google-play.yml 는 Android export 를 인라인으로
# 수행하므로 이 스크립트를 직접 호출하지는 않는다. 이 스크립트는 로컬 재현/수동 빌드용이다.
#
# 필요한 환경 변수:
#   ANDROID_SDK_ROOT 또는 ANDROID_HOME  : Android SDK 경로 (platform-tools/build-tools 포함)
#   ANDROID_KEYSTORE_PATH 또는 ANDROID_KEYSTORE_BASE64 : 릴리스 keystore
#   ANDROID_KEYSTORE_USER               : keystore alias
#   ANDROID_KEYSTORE_PASSWORD           : keystore/alias 비밀번호
# 선택:
#   JAVA_HOME                           : JDK 경로 (미설정 시 java 위치로 추정)
#   PROJECT_DIR / GODOT_PROJECT_DIR     : Godot 프로젝트 경로 (기본 godot)
#   GODOT_ANDROID_PRESET                : 프리셋 이름 (기본 "Android")
#   GODOT_ANDROID_OUTPUT                : 산출물 경로 (기본 build/android/foam-party.aab)
#   GODOT_ANDROID_PACKAGE               : 패키지명 (기본 com.seorilabs.foamparty)
#   GODOT_VERSION / GODOT_STATUS        : export template 버전 (기본 4.6.3 / stable)

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

project_dir="${PROJECT_DIR:-${GODOT_PROJECT_DIR:-godot}}"
preset="${GODOT_ANDROID_PRESET:-Android}"
output_rel="${GODOT_ANDROID_OUTPUT:-build/android/foam-party.aab}"
package_name="${GODOT_ANDROID_PACKAGE:-com.seorilabs.foamparty}"
app_name="${GODOT_ANDROID_APP_NAME:-폼 파티}"
log_dir="${GODOT_ANDROID_LOG_DIR:-${repo_root}/build/logs}"
godot_version="${GODOT_VERSION:-4.6.3}"
godot_status="${GODOT_STATUS:-stable}"

case "${output_rel}" in
  /*) output_abs="${output_rel}" ;;
  *)  output_abs="${repo_root}/${output_rel}" ;;
esac

preset_file="${project_dir}/export_presets.cfg"
backup_file=""
preset_was_created=0
keystore_tmp=""

cleanup() {
  if [ -n "${backup_file}" ] && [ -f "${backup_file}" ]; then
    cp "${backup_file}" "${preset_file}"
    rm -f "${backup_file}"
  elif [ "${preset_was_created}" -eq 1 ]; then
    rm -f "${preset_file}"
  fi
  if [ -n "${keystore_tmp}" ] && [ -f "${keystore_tmp}" ]; then
    rm -f "${keystore_tmp}"
  fi
}
trap cleanup EXIT

fail() {
  echo "[godot-android] $1" >&2
  exit 1
}

# --- 입력 검증 -------------------------------------------------------------
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[ -n "${sdk_root}" ] || fail "ANDROID_SDK_ROOT(또는 ANDROID_HOME)가 필요하다."
[ -d "${sdk_root}/platform-tools" ] || fail "Android SDK platform-tools 가 없다: ${sdk_root}/platform-tools"
[ -d "${sdk_root}/build-tools" ] || fail "Android SDK build-tools 가 없다: ${sdk_root}/build-tools"

keystore_path="${ANDROID_KEYSTORE_PATH:-}"
if [ -z "${keystore_path}" ] && [ -n "${ANDROID_KEYSTORE_BASE64:-}" ]; then
  keystore_tmp="$(mktemp /tmp/release-keystore.XXXXXX.jks)"
  printf '%s' "${ANDROID_KEYSTORE_BASE64}" | base64 -d > "${keystore_tmp}"
  keystore_path="${keystore_tmp}"
fi
[ -n "${keystore_path}" ] || fail "ANDROID_KEYSTORE_PATH 또는 ANDROID_KEYSTORE_BASE64 가 필요하다."
[ -f "${keystore_path}" ] || fail "keystore 파일을 찾을 수 없다: ${keystore_path}"
keystore_path="$(cd "$(dirname "${keystore_path}")" && pwd)/$(basename "${keystore_path}")"
[ -n "${ANDROID_KEYSTORE_USER:-}" ] || fail "ANDROID_KEYSTORE_USER(keystore alias)가 필요하다."
[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ] || fail "ANDROID_KEYSTORE_PASSWORD 가 필요하다."

java_home="${JAVA_HOME:-}"
if [ -z "${java_home}" ] && command -v java >/dev/null 2>&1; then
  java_home="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
fi
[ -n "${java_home}" ] || fail "JAVA_HOME(또는 java)가 필요하다."

command -v godot >/dev/null 2>&1 || fail "godot 바이너리가 PATH 에 없다. scripts/ensure_godot.sh 참고."

mkdir -p "${log_dir}" "$(dirname "${output_abs}")"

# --- editor settings 에 SDK/JDK 경로 주입 ----------------------------------
config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/godot"
mkdir -p "${config_dir}"
echo "[godot-android] materializing editor settings" >&2
godot --headless --editor --quit-after 2 --path "${project_dir}" >/dev/null 2>&1 || true

settings_file="$(ls -1 "${config_dir}"/editor_settings-*.tres 2>/dev/null | sort | tail -n 1 || true)"
if [ -z "${settings_file}" ]; then
  minor="${godot_version%.*}"
  settings_file="${config_dir}/editor_settings-${minor}.tres"
  cat > "${settings_file}" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
EOF
fi

python3 - "$settings_file" "$sdk_root" "$java_home" <<'PY'
import re, sys
path, sdk, java = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "r", encoding="utf-8") as fh:
    text = fh.read()

def upsert(text, key, value):
    line = f'{key} = "{value}"'
    pattern = re.compile(rf'^{re.escape(key)} = .*$', re.MULTILINE)
    if pattern.search(text):
        return pattern.sub(line, text)
    if "[resource]" in text:
        return text.rstrip() + "\n" + line + "\n"
    return text.rstrip() + "\n[resource]\n" + line + "\n"

text = upsert(text, "export/android/android_sdk_path", sdk)
text = upsert(text, "export/android/java_sdk_path", java)
with open(path, "w", encoding="utf-8") as fh:
    fh.write(text)
print(f"[godot-android] editor settings updated: {path}")
PY

# --- Android gradle 빌드 템플릿 설치 ---------------------------------------
template_root="${XDG_DATA_HOME:-${HOME}/.local/share}/godot/export_templates/${godot_version}.${godot_status}"
android_source="${template_root}/android_source.zip"
[ -f "${android_source}" ] || fail "Android export template 이 없다: ${android_source} (ensure_godot.sh --with-export-templates 필요)"

build_dir="${project_dir}/android/build"
if [ ! -f "${build_dir}/.build_version" ]; then
  echo "[godot-android] installing Android build template" >&2
  mkdir -p "${build_dir}"
  unzip -q -o "${android_source}" -d "${build_dir}"
  echo "${godot_version}.${godot_status}" > "${build_dir}/.build_version"
  touch "${project_dir}/android/.gdignore"
fi

# --- export preset 생성 -----------------------------------------------------
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

# 릴리스용 "Android"(gradle build) 프리셋이 없으면 임시 생성한다.
if ! { [ -f "${preset_file}" ] && grep -q "^name=\"${preset}\"$" "${preset_file}" && grep -q '^platform="Android"$' "${preset_file}"; }; then
  index="$(next_index)"
  cat >> "${preset_file}" <<EOF

[preset.${index}]

name="${preset}"
platform="Android"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="${output_rel}"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.${index}.options]

gradle_build/use_gradle_build=true
gradle_build/export_format=0
gradle_build/min_sdk=""
gradle_build/target_sdk=""
architectures/arm64-v8a=true
package/unique_name="${package_name}"
package/name="${app_name}"
package/signed=true
version/code=1
version/name="0.1.0"
keystore/release="${keystore_path}"
keystore/release_user="${ANDROID_KEYSTORE_USER}"
keystore/release_password="${ANDROID_KEYSTORE_PASSWORD}"
EOF
fi

# --- import + export --------------------------------------------------------
import_log="${log_dir}/godot-android-import.log"
export_log="${log_dir}/godot-android-export.log"

echo "[godot-android] importing resources" >&2
set +e
godot --headless --path "${project_dir}" --import --quit 2>&1 | tee "${import_log}"
import_status="${PIPESTATUS[0]}"
set -e
[ "${import_status}" -eq 0 ] || fail "import failed (exit ${import_status}). Log: ${import_log}"
if grep -E "^(SCRIPT ERROR|ERROR):" "${import_log}" >/dev/null; then
  grep -E "^(SCRIPT ERROR|ERROR):" "${import_log}" >&2 || true
  fail "import 중 Godot 오류. Log: ${import_log}"
fi

echo "[godot-android] exporting ${preset} -> ${output_abs}" >&2
set +e
godot --headless --path "${project_dir}" --export-release "${preset}" "${output_abs}" 2>&1 | tee "${export_log}"
export_status="${PIPESTATUS[0]}"
set -e
[ "${export_status}" -eq 0 ] || fail "export failed (exit ${export_status}). Log: ${export_log}"
if grep -E "^(SCRIPT ERROR|ERROR):" "${export_log}" >/dev/null; then
  grep -E "^(SCRIPT ERROR|ERROR):" "${export_log}" >&2 || true
  fail "export 중 Godot 오류. Log: ${export_log}"
fi

[ -f "${output_abs}" ] || fail "산출물이 없다: ${output_abs}"
echo "[godot-android] export complete: ${output_abs} ($(du -h "${output_abs}" | cut -f1))" >&2

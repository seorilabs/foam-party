#!/usr/bin/env bash
set -euo pipefail

addon_dir="godot/addons/seorilabs_platform"
checksum_file="${addon_dir}/CHECKSUM"
version_file="${addon_dir}/VERSION"
source_file="${addon_dir}/SOURCE"
client_file="${addon_dir}/platform_client.gd"
export_presets_file="godot/export_presets.cfg"

for required_file in "${checksum_file}" "${version_file}" "${source_file}" "${client_file}"; do
  if [ ! -f "${required_file}" ]; then
    echo "Missing vendored Platform SDK file: ${required_file}" >&2
    exit 1
  fi
done

actual_checksum="$({
  cd "${addon_dir}"
  find . -name '*.gd' -not -path './tools/*' -print0 \
    | LC_ALL=C sort -z \
    | while IFS= read -r -d '' file; do
        printf '%s ' "${file}"
        shasum -a 256 "${file}" | awk '{print $1}'
      done \
    | shasum -a 256 \
    | awk '{print $1}'
})"
expected_checksum="$(tr -d '[:space:]' < "${checksum_file}")"
if [ "${actual_checksum}" != "${expected_checksum}" ]; then
  echo "Vendored Platform SDK checksum mismatch." >&2
  exit 1
fi

version="$(tr -d '[:space:]' < "${version_file}")"
client_version="$(sed -n 's/^const SDK_VERSION := "\([^"]*\)"$/\1/p' "${client_file}")"
if [ -z "${version}" ] || [ "${version}" != "${client_version}" ]; then
  echo "Vendored Platform SDK VERSION does not match platform_client.gd." >&2
  exit 1
fi

source="$(tr -d '\r\n' < "${source_file}")"
if [ "${source}" != "https://github.com/seorilabs/platform/tree/main/sdk-gdscript" ]; then
  echo "Vendored Platform SDK SOURCE is not canonical." >&2
  exit 1
fi

ios_include_filter="$(awk '
  $0 == "[preset.0]" { in_ios_preset = 1; next }
  in_ios_preset && /^\[/ { exit }
  in_ios_preset && /^include_filter=/ {
    sub(/^include_filter="/, "")
    sub(/"$/, "")
    print
    exit
  }
' "${export_presets_file}")"
case ",${ios_include_filter}," in
  *,GoogleService-Info.plist,*) ;;
  *)
    echo "iOS export must include GoogleService-Info.plist in the Godot resource pack." >&2
    exit 1
    ;;
esac

echo "Platform SDK ${version} provenance and checksum passed."

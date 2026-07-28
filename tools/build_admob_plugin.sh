#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

# The verified Poing v4.3.1/Godot 4.6.3 binaries are vendored. This hook is
# called by the Seorilabs Google Play reusable workflow and only applies the
# build-environment IDs plus verifies that the native payload is intact.
ADMOB_REQUIRE_PRODUCTION="${ADMOB_REQUIRE_PRODUCTION:-0}" \
ADMOB_TARGET_PLATFORM="${ADMOB_TARGET_PLATFORM:-Android}" \
  python3 tools/configure_native_ads.py

required_files=(
  "godot/addons/admob/android/bin/ads/libs/poing-godot-admob-ads-debug.aar"
  "godot/addons/admob/android/bin/ads/libs/poing-godot-admob-ads-release.aar"
  "godot/addons/admob/android/bin/ads/libs/poing-godot-admob-core-debug.aar"
  "godot/addons/admob/android/bin/ads/libs/poing-godot-admob-core-release.aar"
  "godot/ios/plugins/poing-godot-admob-ads.gdip"
)

for file in "${required_files[@]}"; do
  [ -s "${file}" ] || { echo "Missing native AdMob payload: ${file}" >&2; exit 1; }
done

echo "Vendored Poing AdMob v4.3.1 payload ready."

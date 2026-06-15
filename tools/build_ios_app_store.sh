#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

targeted_device_family_from_preset() {
  local preset_value
  preset_value="$(awk -F= '/application\/targeted_device_family=/{print $2; exit}' godot/export_presets.cfg | tr -d '"[:space:]')"
  case "$preset_value" in
    0|"") printf "1" ;;
    1) printf "2" ;;
    2) printf "1,2" ;;
    *) printf "%s" "$preset_value" ;;
  esac
}

team_id="${FOAM_PARTY_IOS_TEAM_ID:-HCDUXX4Z3X}"
bundle_id="${FOAM_PARTY_IOS_BUNDLE_ID:-com.seorilabs.foamparty}"
profile_value="${FOAM_PARTY_IOS_PROFILE_SPECIFIER:-${FOAM_PARTY_IOS_PROFILE_UUID:-${GODOT_APPLE_PLATFORM_PROFILE_SPECIFIER_RELEASE:-${GODOT_APPLE_PLATFORM_PROVISIONING_PROFILE_UUID_RELEASE:-${GODOT_IOS_PROVISIONING_PROFILE_UUID_RELEASE:-}}}}}"
signing_identity="${FOAM_PARTY_IOS_SIGNING_IDENTITY:-Apple Distribution: Seori Labs (${team_id})}"
targeted_device_family="${FOAM_PARTY_IOS_TARGETED_DEVICE_FAMILY:-$(targeted_device_family_from_preset)}"
build_dir="build/ios"
project_name="foam-party"
archive_path="${build_dir}/${project_name}.xcarchive"
export_options="${build_dir}/ExportOptions-app-store.plist"

mkdir -p "$build_dir"
godot --headless --path godot --export-release iOS "../${build_dir}/${project_name}.ipa"

if [[ "${1:-}" == "--project-only" ]]; then
  find "$build_dir" -maxdepth 1 \( -name "*.xcodeproj" -o -name "$project_name" \) -print
  exit 0
fi

if [[ "${1:-}" == "--unsigned-build" ]]; then
  xcodebuild \
    -project "${build_dir}/${project_name}.xcodeproj" \
    -scheme "$project_name" \
    -sdk iphoneos \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    build \
    CODE_SIGNING_ALLOWED=NO \
    TARGETED_DEVICE_FAMILY="$targeted_device_family"
  exit 0
fi

if [[ -z "$profile_value" ]]; then
  cat >&2 <<'MSG'
App Store provisioning profile is required.
Create an App Store provisioning profile for com.seorilabs.foamparty, then rerun:

  export FOAM_PARTY_IOS_PROFILE_SPECIFIER="<profile name or uuid>"
  tools/build_ios_app_store.sh
MSG
  exit 2
fi

rm -rf "$archive_path"

xcodebuild \
  -project "${build_dir}/${project_name}.xcodeproj" \
  -scheme "$project_name" \
  -sdk iphoneos \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  archive \
  -archivePath "$archive_path" \
  DEVELOPMENT_TEAM="$team_id" \
  PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$signing_identity" \
  PROVISIONING_PROFILE_SPECIFIER="$profile_value" \
  TARGETED_DEVICE_FAMILY="$targeted_device_family"

cat > "$export_options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>Apple Distribution</string>
  <key>teamID</key>
  <string>${team_id}</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>${bundle_id}</key>
    <string>${profile_value}</string>
  </dict>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
PLIST

xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportOptionsPlist "$export_options" \
  -exportPath "$build_dir"

find "$build_dir" -maxdepth 1 \( -name "*.ipa" -o -name "*.xcarchive" -o -name "*.xcodeproj" \) -print

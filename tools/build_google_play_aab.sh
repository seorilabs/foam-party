#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_DIR="godot"
PRESET="${GOOGLE_PLAY_GODOT_PRESET:-Android Release}"
AAB_PATH="${GOOGLE_PLAY_AAB_PATH:-build/android/foam-party-internal.aab}"
KEYSTORE_PATH="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}"
KEY_ALIAS="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-${GOOGLE_PLAY_UPLOAD_KEY_ALIAS:-}}"
STORE_PASSWORD="${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-${GOOGLE_PLAY_UPLOAD_KEYSTORE_PASSWORD:-}}"
KEY_PASSWORD="${GODOT_ANDROID_KEYSTORE_RELEASE_KEY_PASSWORD:-${GOOGLE_PLAY_UPLOAD_KEY_PASSWORD:-}}"

if [[ -z "$KEYSTORE_PATH" ]]; then
  KEYSTORE_PATH="/Users/syous/Documents/Codex/2026-06-08/seorilabs-github-repository-secrets-organization/work/secrets/seorilabs-google-play-upload.jks"
fi

if [[ -z "$STORE_PASSWORD" ]]; then
  password_file="/Users/syous/Documents/Codex/2026-06-08/seorilabs-github-repository-secrets-organization/work/secrets/seorilabs-google-play-upload-password.txt"
  if [[ -f "$password_file" ]]; then
    STORE_PASSWORD="$(tr -d '\r\n' < "$password_file")"
  fi
fi

if [[ ! -f "$KEYSTORE_PATH" ]]; then
  echo "Missing Google Play upload keystore: $KEYSTORE_PATH" >&2
  exit 2
fi

if [[ -z "$STORE_PASSWORD" ]]; then
  echo "Missing Google Play upload keystore password." >&2
  exit 2
fi

if [[ -z "$KEY_ALIAS" ]]; then
  KEY_ALIAS="$(keytool -list -keystore "$KEYSTORE_PATH" -storepass "$STORE_PASSWORD" 2>/dev/null | awk -F',' '/PrivateKeyEntry/ { print $1; exit }')"
fi

if [[ -z "$KEY_ALIAS" ]]; then
  echo "Could not detect Google Play upload key alias." >&2
  exit 2
fi

if [[ -z "$KEY_PASSWORD" ]]; then
  KEY_PASSWORD="$STORE_PASSWORD"
fi

tools/install_android_build_template.sh "$PROJECT_DIR"
mkdir -p "$(dirname "$AAB_PATH")"

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE_PATH"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KEY_ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$STORE_PASSWORD"
export GODOT_ANDROID_KEYSTORE_RELEASE_KEY_PASSWORD="$KEY_PASSWORD"

godot --headless --path "$PROJECT_DIR" --export-release "$PRESET" "../$AAB_PATH"

if [[ ! -f "$AAB_PATH" ]]; then
  echo "AAB was not created: $AAB_PATH" >&2
  exit 1
fi

ls -lh "$AAB_PATH"

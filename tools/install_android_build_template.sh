#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Godot 프로젝트는 godot/ 하위이므로 gradle build 템플릿도 godot/android/build 에 설치한다
# (godot --path godot --export-release Android 가 참조하는 경로).
ANDROID_DIR="$ROOT_DIR/godot/android"
ANDROID_BUILD_DIR="$ANDROID_DIR/build"

resolve_template_version() {
  if [ -n "${GODOT_VERSION:-}" ]; then
    if [ -n "${GODOT_STATUS:-}" ]; then
      printf '%s.%s\n' "$GODOT_VERSION" "$GODOT_STATUS"
    else
      printf '%s.stable\n' "$GODOT_VERSION"
    fi
    return 0
  fi

  if ! command -v godot >/dev/null 2>&1; then
    echo "GODOT_VERSION is not set and godot was not found on PATH." >&2
    return 1
  fi

  godot --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?\.[^.]+).*/\1/'
}

find_android_source_zip() {
  local template_version="$1"
  local candidate
  local candidates=(
    "$HOME/.local/share/godot/export_templates/$template_version/android_source.zip"
    "$HOME/Library/Application Support/Godot/export_templates/$template_version/android_source.zip"
  )

  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  echo "android_source.zip was not found for Godot export templates $template_version." >&2
  echo "Install export templates first, then run this script again." >&2
  return 1
}

template_version="$(resolve_template_version)"
android_source_zip="$(find_android_source_zip "$template_version")"

rm -rf "$ANDROID_BUILD_DIR"
mkdir -p "$ANDROID_BUILD_DIR"
unzip -q "$android_source_zip" -d "$ANDROID_BUILD_DIR"
chmod +x "$ANDROID_BUILD_DIR/gradlew"
python3 "$ROOT_DIR/tools/patch_android_build_template.py" "$ANDROID_BUILD_DIR"
printf '%s\n' "$template_version" > "$ANDROID_DIR/.build_version"

if [ ! -x "$ANDROID_BUILD_DIR/gradlew" ]; then
  echo "Android build template install failed: gradlew was not created." >&2
  exit 1
fi

echo "Android build template installed from $android_source_zip"

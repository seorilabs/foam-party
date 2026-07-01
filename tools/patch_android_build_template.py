#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ANDROID_BUILD_DIR = ROOT / "godot" / "android" / "build"


def replace_once(path, old, new):
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count == 1:
        path.write_text(text.replace(old, new), encoding="utf-8")
        return
    if count == 0 and new in text:
        return
    if count != 1:
        raise RuntimeError(f"Expected exactly one match in {path}, found {count}.")


def patch_config_gradle(android_build_dir):
    path = android_build_dir / "config.gradle"
    old = """ext.getReleaseKeyAlias = { ->
    String keyAlias = project.hasProperty("release_keystore_alias") ? project.property("release_keystore_alias") : ""
    return keyAlias
}

ext.isAndroidStudio = { ->
"""
    new = """ext.getReleaseKeyAlias = { ->
    String keyAlias = project.hasProperty("release_keystore_alias") ? project.property("release_keystore_alias") : ""
    return keyAlias
}

ext.getReleaseKeyPassword = { ->
    String keyPassword = project.hasProperty("release_keystore_key_password") ? project.property("release_keystore_key_password") : ""
    if (keyPassword == null || keyPassword.isEmpty()) {
        keyPassword = System.getenv("GODOT_ANDROID_KEYSTORE_RELEASE_KEY_PASSWORD")
    }
    if (keyPassword == null || keyPassword.isEmpty()) {
        keyPassword = getReleaseKeystorePassword()
    }
    return keyPassword
}

ext.isAndroidStudio = { ->
"""
    replace_once(path, old, new)


def patch_build_gradle(android_build_dir):
    path = android_build_dir / "build.gradle"
    replace_once(path, "                keyPassword getReleaseKeystorePassword()\n", "                keyPassword getReleaseKeyPassword()\n")


def main():
    parser = argparse.ArgumentParser(description="Patch Godot Android build template for Foam Party release signing.")
    parser.add_argument("android_build_dir", nargs="?", default=str(DEFAULT_ANDROID_BUILD_DIR))
    args = parser.parse_args()

    android_build_dir = Path(args.android_build_dir)
    patch_config_gradle(android_build_dir)
    patch_build_gradle(android_build_dir)
    print(f"Android build template patched for release key password support: {android_build_dir}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"Failed to patch Android build template: {error}", file=sys.stderr)
        sys.exit(1)

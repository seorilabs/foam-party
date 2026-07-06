#!/usr/bin/env python3
import argparse
import json
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "play-store" / "google-play.config.json"
EXPORT_PRESETS = ROOT / "godot" / "export_presets.cfg"


def load_config():
    with CONFIG_PATH.open(encoding="utf-8") as file:
        return json.load(file)


def add(checks, name, status, message):
    checks.append({"name": name, "status": status, "message": message})


def has_placeholder(value):
    if isinstance(value, str):
        return "확정 필요" in value
    if isinstance(value, list):
        return any(has_placeholder(item) for item in value)
    if isinstance(value, dict):
        return any(has_placeholder(item) for item in value.values())
    return False


def parse_android_release_preset():
    text = EXPORT_PRESETS.read_text(encoding="utf-8")
    match = re.search(r'\[preset\.(\d+)\]\n\nname="Android Release".*?\[preset\.\1\.options\]\n\n(?P<options>.*?)(?=\n\[preset\.|\Z)', text, re.S)
    if not match:
        return None
    options = {}
    for line in match.group("options").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            options[key.strip()] = value.strip().strip('"')
    return options


def inspect_aab(aab_path):
    if not aab_path.exists():
        return {"exists": False}
    result = {"exists": True, "has_arm64": False, "has_google_services": False, "has_ads_or_firebase": False}
    with zipfile.ZipFile(aab_path) as archive:
        names = archive.namelist()
    result["has_arm64"] = any(name.startswith("base/lib/arm64-v8a/") for name in names)
    result["has_google_services"] = any("google-services.json" in name for name in names)
    result["has_ads_or_firebase"] = any("play-services-ads" in name or "firebase" in name for name in names)
    return result


def main():
    parser = argparse.ArgumentParser(description="Check Google Play release readiness.")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    config = load_config()
    checks = []

    package_name = config.get("packageName", "")
    add(checks, "package-name", "pass" if package_name == "com.seorilabs.foamparty" else "blocker", package_name or "missing")

    preset = parse_android_release_preset()
    if preset is None:
        add(checks, "android-release-preset", "blocker", "Android Release preset missing")
    else:
        add(checks, "android-release-preset", "pass", "Android Release preset exists")
        add(checks, "aab-export-format", "pass" if preset.get("gradle_build/export_format") == "1" else "blocker", f"export_format={preset.get('gradle_build/export_format')}")
        add(checks, "application-id", "pass" if preset.get("package/unique_name") == package_name else "blocker", preset.get("package/unique_name", "missing"))
        target_sdk = 36
        add(checks, "target-sdk", "pass" if target_sdk >= 35 else "blocker", f"targetSdk={target_sdk}")
        add(checks, "version-code", "pass" if preset.get("version/code", "").isdigit() else "blocker", preset.get("version/code", "missing"))

    release = config.get("release", {})
    aab_path = ROOT / release.get("aabPath", "build/android/foam-party-internal.aab")
    aab = inspect_aab(aab_path)
    if aab["exists"]:
        add(checks, "aab", "pass", str(aab_path.relative_to(ROOT)))
        add(checks, "aab-arm64", "pass" if aab["has_arm64"] else "blocker", "arm64-v8a present" if aab["has_arm64"] else "arm64-v8a missing")
        add(checks, "aab-google-services", "pass" if aab["has_google_services"] else "blocker", "google-services.json present" if aab["has_google_services"] else "google-services.json missing")
        add(checks, "aab-ads-firebase", "pass" if aab["has_ads_or_firebase"] else "blocker", "AdMob/Firebase artifacts present" if aab["has_ads_or_firebase"] else "AdMob/Firebase artifacts missing")
    else:
        add(checks, "aab", "blocker", f"missing: {aab_path.relative_to(ROOT)}")

    if has_placeholder(config.get("storeListing", {})):
        add(checks, "store-listing", "blocker", "store listing text has unresolved placeholders")
    else:
        add(checks, "store-listing", "pass", "store listing text present")

    if has_placeholder(config.get("assets", {})):
        add(checks, "store-assets", "blocker", "store assets have unresolved placeholders")
    else:
        add(checks, "store-assets", "pass", "store asset paths present")

    if has_placeholder(config.get("contentDeclarations", {})):
        add(checks, "policy-declarations", "blocker", "policy declarations have unresolved placeholders")
    else:
        add(checks, "policy-declarations", "pass", "policy declarations present")

    last_upload = release.get("lastInternalUpload", {})
    if last_upload.get("status") in {"draft", "completed"}:
        add(checks, "internal-upload", "pass", f"versionCode={last_upload.get('versionCode')}")
    elif last_upload.get("status"):
        reason = last_upload.get("reason", "upload is not successful")
        add(checks, "internal-upload", "blocker", f"{last_upload.get('status')}: {reason}")
    else:
        add(checks, "internal-upload", "blocker", "no successful internal draft upload recorded")

    blockers = [check for check in checks if check["status"] == "blocker"]
    result = {"status": "blocked" if blockers else "ready", "checks": checks}
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        for check in checks:
            print(f"[{check['status']}] {check['name']}: {check['message']}")
    return 1 if blockers else 0


if __name__ == "__main__":
    sys.exit(main())

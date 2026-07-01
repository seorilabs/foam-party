#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG_PATH = ROOT / "play-store" / "google-play.config.json"
# Godot 프로젝트는 godot/ 하위에 있다(deploy-google-play caller: project_dir=godot).
DEFAULT_PRESETS_PATH = ROOT / "godot" / "export_presets.cfg"
ANDROID_VERSION_CODE_MAX = 2_100_000_000
SEMVER_PATTERN = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
SEMVER_MINOR_OR_PATCH_MAX = 999


def parse_version_name(raw_value):
    if raw_value is None:
        raise ValueError("versionName is required.")

    version_name = str(raw_value).strip()
    match = SEMVER_PATTERN.fullmatch(version_name)
    if not match:
        raise ValueError(f"versionName must be stable SemVer x.y.z: {raw_value}")

    major, minor, patch = (int(part) for part in match.groups())
    if minor > SEMVER_MINOR_OR_PATCH_MAX or patch > SEMVER_MINOR_OR_PATCH_MAX:
        raise ValueError(
            "versionName minor and patch must be between 0 and "
            f"{SEMVER_MINOR_OR_PATCH_MAX} to derive Android versionCode: {version_name}"
        )

    return version_name, major, minor, patch


def derive_version_code(version_name):
    _version_name, major, minor, patch = parse_version_name(version_name)
    version_code = major * 1_000_000 + minor * 1_000 + patch

    if version_code < 1 or version_code > ANDROID_VERSION_CODE_MAX:
        raise ValueError(
            f"Derived versionCode must be between 1 and {ANDROID_VERSION_CODE_MAX}: "
            f"{version_code}"
        )

    return version_code


def parse_version_code(raw_value):
    try:
        version_code = int(raw_value)
    except (TypeError, ValueError) as error:
        raise ValueError(f"versionCode must be an integer: {raw_value}") from error

    if version_code < 1 or version_code > ANDROID_VERSION_CODE_MAX:
        raise ValueError(
            f"versionCode must be between 1 and {ANDROID_VERSION_CODE_MAX}: {version_code}"
        )

    return version_code


def update_export_presets(path, version_name, version_code, dry_run):
    text = path.read_text(encoding="utf-8")
    updated_text, code_count = re.subn(
        r"(?m)^version/code=\d+$",
        f"version/code={version_code}",
        text,
    )
    updated_text, name_count = re.subn(
        r'(?m)^version/name="[^"]*"$',
        f'version/name="{version_name}"',
        updated_text,
    )

    if code_count != 1:
        raise RuntimeError(
            f"Expected exactly one Android version/code entry in {path}, found {code_count}."
        )

    if name_count != 1:
        raise RuntimeError(
            f"Expected exactly one Android version/name entry in {path}, found {name_count}."
        )

    if not dry_run:
        path.write_text(updated_text, encoding="utf-8")

    return {"versionCodeEntries": code_count, "versionNameEntries": name_count}


def load_google_play_config(path):
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def update_google_play_config(path, config, version_name, version_code, dry_run):
    release = config.setdefault("release", {})
    release["versionName"] = version_name
    release["versionCode"] = version_code

    if not dry_run:
        with path.open("w", encoding="utf-8") as file:
            json.dump(config, file, ensure_ascii=False, indent=2)
            file.write("\n")


def main():
    parser = argparse.ArgumentParser(description="Set Google Play versionName/versionCode for Android export.")
    parser.add_argument(
        "--version-name",
        help="Stable SemVer versionName to write. If omitted, play-store config release.versionName is used.",
    )
    parser.add_argument(
        "--version-code",
        help="Android versionCode to write. If omitted, it is derived from versionName as major*1000000 + minor*1000 + patch.",
    )
    parser.add_argument("--config-path", default=str(DEFAULT_CONFIG_PATH))
    parser.add_argument("--export-presets-path", default=str(DEFAULT_PRESETS_PATH))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    config_path = Path(args.config_path)
    presets_path = Path(args.export_presets_path)
    config = load_google_play_config(config_path)

    raw_version_name = args.version_name or config.get("release", {}).get("versionName")
    version_name, _major, _minor, _patch = parse_version_name(raw_version_name)
    version_code_derived = args.version_code is None
    if version_code_derived:
        version_code = derive_version_code(version_name)
    else:
        version_code = parse_version_code(args.version_code)

    export_updates = update_export_presets(presets_path, version_name, version_code, args.dry_run)
    update_google_play_config(config_path, config, version_name, version_code, args.dry_run)

    print(
        json.dumps(
            {
                "versionName": version_name,
                "versionCode": version_code,
                "versionCodeDerived": version_code_derived,
                "configPath": str(config_path),
                "exportPresetsPath": str(presets_path),
                "exportUpdates": export_updates,
                "dryRun": args.dry_run,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"Failed to set Google Play versionCode: {error}", file=sys.stderr)
        sys.exit(1)

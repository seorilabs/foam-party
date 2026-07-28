#!/usr/bin/env python3
"""Apply optional build-environment overrides to the native AdMob bundle."""

import argparse
import json
import os
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "godot" / "config" / "native_ads.json"
ANDROID_PLUGIN_CONFIG = ROOT / "godot" / "addons" / "admob" / "android" / "config.gd"
IOS_GDIP = ROOT / "godot" / "ios" / "plugins" / "poing-godot-admob-ads.gdip"

APP_ID_PATTERN = re.compile(r"^ca-app-pub-\d+~\d+$")
UNIT_ID_PATTERN = re.compile(r"^ca-app-pub-\d+/\d+$")
GOOGLE_TEST_PUBLISHER = "ca-app-pub-3940256099942544"
PLATFORMS = ("Android", "iOS")
INCOMPATIBLE_REWARDED_UNIT_IDS = {
    "ca-app-pub-2444587584524186/5440739953",
    "ca-app-pub-2444587584524186/7557772414",
}


def first_environment_value(*names):
    for name in names:
        value = os.environ.get(name, "").strip()
        if value:
            return value, name
    return "", ""


def set_nested(config, platform, format_name, placement, value):
    config["platforms"][platform]["units"][format_name][placement] = value


def validate(config):
    for platform, platform_config in config["platforms"].items():
        app_id = platform_config.get("appId", "")
        if not APP_ID_PATTERN.fullmatch(app_id):
            raise SystemExit(f"Invalid {platform} AdMob app ID")
        for format_name, placements in platform_config.get("units", {}).items():
            for placement, unit_id in placements.items():
                if not UNIT_ID_PATTERN.fullmatch(unit_id):
                    raise SystemExit(f"Invalid {platform} {format_name}/{placement} ad unit ID")
                if (
                    format_name == "rewarded"
                    and unit_id in INCOMPATIBLE_REWARDED_UNIT_IDS
                ):
                    raise SystemExit(
                        f"Invalid {platform} rewarded/{placement} ad unit ID: "
                        "AdMob console format is rewarded interstitial, "
                        "but the app uses RewardedAdLoader"
                    )


def environment_flag(name):
    return os.environ.get(name, "").strip().lower() in {"1", "true", "yes", "on"}


def parse_platforms(cli_platforms):
    requested = list(cli_platforms or [])
    if not requested:
        requested = [
            value.strip()
            for value in os.environ.get("ADMOB_TARGET_PLATFORM", "").split(",")
            if value.strip()
        ]
    if not requested:
        return set(PLATFORMS)

    invalid = sorted(set(requested) - set(PLATFORMS))
    if invalid:
        raise SystemExit(
            "Invalid AdMob target platform: "
            + ", ".join(invalid)
            + f" (expected one of {', '.join(PLATFORMS)})"
        )
    return set(requested)


def replace_once(path, pattern, replacement):
    original = path.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, original, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"Could not update AdMob application ID in {path.relative_to(ROOT)}")
    if updated != original:
        path.write_text(updated, encoding="utf-8")


def test_id_slots(config, platforms):
    slots = []
    for platform in PLATFORMS:
        if platform not in platforms:
            continue
        platform_config = config["platforms"][platform]
        if GOOGLE_TEST_PUBLISHER in platform_config["appId"]:
            slots.append(f"godot/config/native_ads.json: {platform} appId")
        for format_name, placements in platform_config.get("units", {}).items():
            for placement, unit_id in placements.items():
                if GOOGLE_TEST_PUBLISHER in unit_id:
                    slots.append(
                        "godot/config/native_ads.json: "
                        f"{platform} {format_name}/{placement}"
                    )

    artifact_patterns = {
        "Android": (
            ANDROID_PLUGIN_CONFIG,
            r'^const APPLICATION_ID := "([^"]+)"',
            "Android plugin applicationId",
        ),
        "iOS": (
            IOS_GDIP,
            r'^GADApplicationIdentifier:string_input="([^"]+)"',
            "iOS plugin GADApplicationIdentifier",
        ),
    }
    for platform in PLATFORMS:
        if platform not in platforms:
            continue
        path, pattern, label = artifact_patterns[platform]
        match = re.search(pattern, path.read_text(encoding="utf-8"), re.MULTILINE)
        if not match:
            slots.append(f"{path.relative_to(ROOT)}: {label} missing")
        elif GOOGLE_TEST_PUBLISHER in match.group(1):
            slots.append(f"{path.relative_to(ROOT)}: {label}")
    return slots


def require_production_ids(config, platforms):
    slots = test_id_slots(config, platforms)
    if not slots:
        return
    print(
        "Native AdMob production guard failed; Google test publisher IDs remain:",
        file=sys.stderr,
    )
    for slot in slots:
        print(f"- {slot}", file=sys.stderr)
    raise SystemExit(1)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-production",
        action="store_true",
        help="fail when the selected platform still contains Google test IDs",
    )
    parser.add_argument(
        "--platform",
        action="append",
        choices=PLATFORMS,
        help="platform to validate; repeat to validate both (default: both)",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    platforms = parse_platforms(args.platform)
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    applied = []

    app_overrides = {
        "Android": first_environment_value("ADMOB_ANDROID_APP_ID", "ADMOB_APP_ID"),
        "iOS": first_environment_value("ADMOB_IOS_APP_ID"),
    }
    unit_overrides = {
        ("Android", "interstitial", "game_over"): first_environment_value(
            "ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID", "ADMOB_INTERSTITIAL_AD_UNIT_ID"
        ),
        ("iOS", "interstitial", "game_over"): first_environment_value(
            "ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID"
        ),
        ("Android", "rewarded", "foam_bomb_free"): first_environment_value(
            "ADMOB_ANDROID_FOAM_BOMB_REWARDED_AD_UNIT_ID",
            "ADMOB_FOAM_BOMB_REWARDED_AD_UNIT_ID",
            "ADMOB_REWARDED_AD_UNIT_ID",
        ),
        ("Android", "rewarded", "level_reward_2x"): first_environment_value(
            "ADMOB_ANDROID_LEVEL_REWARD_REWARDED_AD_UNIT_ID",
            "ADMOB_LEVEL_REWARD_REWARDED_AD_UNIT_ID",
        ),
        ("iOS", "rewarded", "foam_bomb_free"): first_environment_value(
            "ADMOB_IOS_FOAM_BOMB_REWARDED_AD_UNIT_ID"
        ),
        ("iOS", "rewarded", "level_reward_2x"): first_environment_value(
            "ADMOB_IOS_LEVEL_REWARD_REWARDED_AD_UNIT_ID"
        ),
    }

    for platform, (value, source) in app_overrides.items():
        if value:
            config["platforms"][platform]["appId"] = value
            applied.append(source)
    for (platform, format_name, placement), (value, source) in unit_overrides.items():
        if value:
            set_nested(config, platform, format_name, placement, value)
            applied.append(source)

    validate(config)
    if applied:
        config["mode"] = "environment-overrides"
        CONFIG_PATH.write_text(
            json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    android_app_id = config["platforms"]["Android"]["appId"]
    ios_app_id = config["platforms"]["iOS"]["appId"]
    replace_once(
        ANDROID_PLUGIN_CONFIG,
        r'^const APPLICATION_ID := "[^"]+"',
        f'const APPLICATION_ID := "{android_app_id}"',
    )
    replace_once(
        IOS_GDIP,
        r'^GADApplicationIdentifier:string_input="[^"]+"',
        f'GADApplicationIdentifier:string_input="{ios_app_id}"',
    )

    if args.require_production or environment_flag("ADMOB_REQUIRE_PRODUCTION"):
        require_production_ids(config, platforms)

    if applied:
        print("Native AdMob environment overrides applied: " + ", ".join(sorted(set(applied))))
    else:
        print("Native AdMob uses Google official test IDs")


if __name__ == "__main__":
    main()

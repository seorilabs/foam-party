#!/usr/bin/env python3
"""Apply optional build-environment overrides to the native AdMob bundle."""

import json
import os
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "godot" / "config" / "native_ads.json"
ANDROID_PLUGIN_CONFIG = ROOT / "godot" / "addons" / "admob" / "android" / "config.gd"
IOS_GDIP = ROOT / "godot" / "ios" / "plugins" / "poing-godot-admob-ads.gdip"

APP_ID_PATTERN = re.compile(r"^ca-app-pub-\d+~\d+$")
UNIT_ID_PATTERN = re.compile(r"^ca-app-pub-\d+/\d+$")


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


def replace_once(path, pattern, replacement):
    original = path.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, original, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"Could not update AdMob application ID in {path.relative_to(ROOT)}")
    if updated != original:
        path.write_text(updated, encoding="utf-8")


def main():
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

    if applied:
        print("Native AdMob environment overrides applied: " + ", ".join(sorted(set(applied))))
    else:
        print("Native AdMob uses Google official test IDs")


if __name__ == "__main__":
    main()

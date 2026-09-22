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
# AdMob v5 는 app id 를 ProjectSettings(`admob/general/<platform>/app_id`)로 읽는다.
# v4 의 `addons/admob/android/config.gd` 상수와 iOS `.gdip` plist 치환은 사라졌다.
PROJECT_GODOT = ROOT / "godot" / "project.godot"

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


def upsert_project_setting(path, key, value):
    """`[admob]` 섹션의 key 를 value 로 맞춘다. 없으면 만든다.

    `godot --import` 는 등록되지 않은 커스텀 ProjectSettings 를 저장 시 버린다.
    그래서 app id 는 저장소에 보관할 수 없고 빌드마다 다시 주입해야 한다.
    """
    original = path.read_text(encoding="utf-8")
    pattern = rf'^{re.escape(key)}="[^"]*"'
    updated, count = re.subn(
        pattern, f'{key}="{value}"', original, count=1, flags=re.MULTILINE
    )
    if count == 0:
        if "[admob]" in original:
            updated = original.replace("[admob]\n", f'[admob]\n\n{key}="{value}"\n', 1)
        else:
            updated = original.rstrip("\n") + f'\n\n[admob]\n\n{key}="{value}"\n'
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

    # 최종 산출물의 app id 는 ProjectSettings 한 곳에 모인다(AdMob v5).
    artifact_patterns = {
        "Android": (
            PROJECT_GODOT,
            r'^general/android/app_id="([^"]+)"',
            "admob/general/android/app_id",
        ),
        "iOS": (
            PROJECT_GODOT,
            r'^general/ios/app_id="([^"]+)"',
            "admob/general/ios/app_id",
        ),
    }
    for platform in PLATFORMS:
        if platform not in platforms:
            continue
        path, pattern, label = artifact_patterns[platform]
        match = re.search(pattern, path.read_text(encoding="utf-8"), re.MULTILINE)
        # 설정이 없으면 AdMob v5 가 Google 테스트 ID 를 기본값으로 쓴다.
        if not match or GOOGLE_TEST_PUBLISHER in match.group(1):
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
    upsert_project_setting(PROJECT_GODOT, "general/android/app_id", android_app_id)
    upsert_project_setting(PROJECT_GODOT, "general/ios/app_id", ios_app_id)

    if args.require_production or environment_flag("ADMOB_REQUIRE_PRODUCTION"):
        require_production_ids(config, platforms)

    if applied:
        print("Native AdMob environment overrides applied: " + ", ".join(sorted(set(applied))))
    else:
        print("Native AdMob uses Google official test IDs")


if __name__ == "__main__":
    main()

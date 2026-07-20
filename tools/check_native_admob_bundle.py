#!/usr/bin/env python3
"""Static contract check for the vendored Android/iOS AdMob integration."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise SystemExit(f"Native AdMob contract failed: {message}")


def require_payload(relative_path):
    path = ROOT / relative_path
    require(path.is_file() and path.stat().st_size > 1024, f"missing payload {relative_path}")


def main():
    plugin_cfg = (ROOT / "godot/addons/admob/plugin.cfg").read_text(encoding="utf-8")
    require('version="v4.3.1"' in plugin_cfg, "Poing plugin version must be v4.3.1")

    for path in [
        "godot/addons/admob/android/bin/ads/libs/poing-godot-admob-ads-debug.aar",
        "godot/addons/admob/android/bin/ads/libs/poing-godot-admob-ads-release.aar",
        "godot/addons/admob/android/bin/ads/libs/poing-godot-admob-core-debug.aar",
        "godot/addons/admob/android/bin/ads/libs/poing-godot-admob-core-release.aar",
        "godot/ios/plugins/poing-godot-admob/bin/poing-godot-admob-ads.debug.xcframework/ios-arm64/libpoing-godot-admob-ads.arm64-ios.release_debug.a",
        "godot/ios/plugins/poing-godot-admob/bin/poing-godot-admob-ads.release.xcframework/ios-arm64/libpoing-godot-admob-ads.arm64-ios.release.a",
    ]:
        require_payload(path)

    android_exporter = (
        ROOT / "godot/addons/admob/android/bin/ads/poing_godot_admob_ads.gd"
    ).read_text(encoding="utf-8")
    require("play-services-ads:24.9.0" in android_exporter, "Android Ads SDK version drift")

    ios_gdip = (ROOT / "godot/ios/plugins/poing-godot-admob-ads.gdip").read_text(
        encoding="utf-8"
    )
    require("swift-package-manager-google-mobile-ads.git@exact:13.3.0" in ios_gdip, "iOS Ads SDK version drift")
    require("google-user-messaging-platform.git@exact:3.1.0" in ios_gdip, "iOS UMP SDK missing")
    ios_package = (ROOT / "godot/ios/plugins/package.gd").read_text(encoding="utf-8")
    require('VERSION := "v4.3.1"' in ios_package, "iOS platform package version drift")

    presets = (ROOT / "godot/export_presets.cfg").read_text(encoding="utf-8")
    require("plugins/AdMob=true" in presets, "iOS export plugin disabled")
    project = (ROOT / "godot/project.godot").read_text(encoding="utf-8")
    require("res://addons/admob/plugin.cfg" in project, "AdMob editor/export plugin disabled")
    ios_builder = (ROOT / "tools/build_ios_app_store.sh").read_text(encoding="utf-8")
    require("patch_ios_admob_project.py" in ios_builder, "iOS SPM post-export patch missing")

    config = json.loads((ROOT / "godot/config/native_ads.json").read_text(encoding="utf-8"))
    require(config["platforms"]["iOS"]["nonPersonalizedAds"] is True, "iOS must default to NPA")
    require(
        config["platforms"]["Android"]["units"]["interstitial"]["game_over"]
        == "ca-app-pub-3940256099942544/1033173712",
        "Android test interstitial ID drift",
    )
    require(
        config["platforms"]["iOS"]["units"]["rewarded"]["foam_bomb_free"]
        == "ca-app-pub-3940256099942544/1712485313",
        "iOS test rewarded ID drift",
    )

    service = (ROOT / "godot/scripts/services/ad_service.gd").read_text(encoding="utf-8")
    for contract in [
        "OnUserEarnedRewardListener",
        'request.extras["npa"] = "1"',
        '"ad_rewarded_request"',
        '"ad_rewarded_granted"',
        '"ad_interstitial_impression"',
    ]:
        require(contract in service, f"service contract missing {contract}")

    print("Native AdMob bundle contract passed.")


if __name__ == "__main__":
    main()

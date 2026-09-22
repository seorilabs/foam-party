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
    require('version="5.1.0"' in plugin_cfg, "Poing plugin version must be 5.1.0")

    # v5 는 네이티브 바이너리를 addon 안(android/bin, ios/bin)에 둔다. v4 의
    # res://ios/plugins/poing-godot-admob* 배치는 v5 exporter 가 충돌로 거부한다.
    for path in [
        "godot/addons/admob/android/bin/ads/libs/poing-godot-admob-ads-debug.aar",
        "godot/addons/admob/android/bin/ads/libs/poing-godot-admob-ads-release.aar",
        "godot/addons/admob/android/bin/ads/libs/poing-godot-admob-core-debug.aar",
        "godot/addons/admob/android/bin/ads/libs/poing-godot-admob-core-release.aar",
        "godot/addons/admob/ios/bin/ads/libs/poing-godot-admob-ads.debug.xcframework/ios-arm64/libpoing-godot-admob-ads.arm64-ios.release_debug.a",
        "godot/addons/admob/ios/bin/ads/libs/poing-godot-admob-ads.release.xcframework/ios-arm64/libpoing-godot-admob-ads.arm64-ios.release.a",
    ]:
        require_payload(path)

    for legacy in [
        "godot/ios/plugins/poing-godot-admob",
        "godot/ios/plugins/poing-godot-admob-ads.gdip",
    ]:
        require(
            not (ROOT / legacy).exists(),
            f"legacy v4 AdMob artifact must be removed: {legacy}",
        )

    android_exporter = (
        ROOT / "godot/addons/admob/android/bin/ads/poing_godot_admob_ads.gd"
    ).read_text(encoding="utf-8")
    require(
        "ads-mobile-sdk:1.4.0" in android_exporter, "Android Ads SDK version drift"
    )

    ios_package = (ROOT / "godot/addons/admob/ios/bin/package.gd").read_text(
        encoding="utf-8"
    )
    require('VERSION := "5.1.0"' in ios_package, "iOS platform package version drift")

    project = (ROOT / "godot/project.godot").read_text(encoding="utf-8")
    require("res://addons/admob/plugin.cfg" in project, "AdMob editor/export plugin disabled")
    # v5 는 app id 를 ProjectSettings 로 읽는다. `godot --import` 가 등록되지 않은
    # 커스텀 설정을 저장 시 버리므로 저장소에는 두지 않고 빌드마다 주입한다.
    # 설정이 없으면 v5 가 Google 테스트 ID 를 기본값으로 쓰고,
    # ADMOB_REQUIRE_PRODUCTION=1 이 릴리스 경로에서 그것을 막는다.

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

    presets = (ROOT / "godot/export_presets.cfg").read_text(encoding="utf-8")
    # Firebase 3.1.0 의 privacy-safe defaults 는 analytics 수집을 기본으로 끈다.
    # 2.4.1 에는 없던 동작이라 켜면 계측이 조용히 멈춘다. EEA/UK 동의 흐름을
    # 갖추기 전까지 끈 상태를 유지한다.
    require(
        presets.count("firebase/privacy_safe_defaults=false") == 2,
        "privacy-safe defaults must stay disabled on both iOS and Android presets",
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

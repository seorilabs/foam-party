#!/usr/bin/env python3
"""Regression tests for production AdMob ID injection and release guards."""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
CONFIGURE_SCRIPT = REPO_ROOT / "tools" / "configure_native_ads.py"
ANDROID_BUILD = REPO_ROOT / "tools" / "build_admob_plugin.sh"
IOS_POST_CLONE = REPO_ROOT / "build" / "ios" / "ci_scripts" / "ci_post_clone.sh"

TEST_PUBLISHER = "ca-app-pub-3940256099942544"
PRODUCTION_PUBLISHER = "ca-app-pub-1234567890123456"


class ConfigureNativeAdsTest(unittest.TestCase):
    def setUp(self) -> None:
        fixture_dir = tempfile.TemporaryDirectory()
        self.addCleanup(fixture_dir.cleanup)
        self.root = Path(fixture_dir.name)
        (self.root / "tools").mkdir(parents=True)
        (self.root / "godot/config").mkdir(parents=True)
        (self.root / "godot/addons/admob/android").mkdir(parents=True)
        (self.root / "godot/ios/plugins").mkdir(parents=True)
        shutil.copy2(CONFIGURE_SCRIPT, self.root / "tools/configure_native_ads.py")

        self.config_path = self.root / "godot/config/native_ads.json"
        self.config_path.write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "mode": "google-test-defaults",
                    "platforms": {
                        "Android": {
                            "appId": f"{TEST_PUBLISHER}~3347511713",
                            "units": {
                                "interstitial": {
                                    "game_over": f"{TEST_PUBLISHER}/1033173712"
                                },
                                "rewarded": {
                                    "foam_bomb_free": f"{TEST_PUBLISHER}/5224354917",
                                    "level_reward_2x": f"{TEST_PUBLISHER}/5224354917",
                                },
                            },
                        },
                        "iOS": {
                            "appId": f"{TEST_PUBLISHER}~1458002511",
                            "units": {
                                "interstitial": {
                                    "game_over": f"{TEST_PUBLISHER}/4411468910"
                                },
                                "rewarded": {
                                    "foam_bomb_free": f"{TEST_PUBLISHER}/1712485313",
                                    "level_reward_2x": f"{TEST_PUBLISHER}/1712485313",
                                },
                            },
                        },
                    },
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        self.android_config = self.root / "godot/addons/admob/android/config.gd"
        self.android_config.write_text(
            f'const APPLICATION_ID := "{TEST_PUBLISHER}~3347511713"\n',
            encoding="utf-8",
        )
        self.ios_gdip = self.root / "godot/ios/plugins/poing-godot-admob-ads.gdip"
        self.ios_gdip.write_text(
            f'GADApplicationIdentifier:string_input="{TEST_PUBLISHER}~1458002511"\n',
            encoding="utf-8",
        )

    def run_configure(self, overrides=None, *args):
        environment = {
            key: value
            for key, value in os.environ.items()
            if not key.startswith("ADMOB_")
        }
        environment.update(overrides or {})
        return subprocess.run(
            [
                sys.executable,
                str(self.root / "tools/configure_native_ads.py"),
                *args,
            ],
            cwd=self.root,
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )

    def test_default_mode_preserves_google_test_ids(self) -> None:
        """AC: strict 미설정 시 기존 Google 테스트 기본값 경로가 그대로 통과한다."""
        result = self.run_configure()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("uses Google official test IDs", result.stdout)
        config = json.loads(self.config_path.read_text(encoding="utf-8"))
        self.assertEqual(config["mode"], "google-test-defaults")
        self.assertIn(
            TEST_PUBLISHER,
            config["platforms"]["Android"]["units"]["rewarded"]["foam_bomb_free"],
        )

    def test_strict_android_reports_every_remaining_test_slot(self) -> None:
        """AC: strict Android에서 테스트 ID가 남은 slot을 stderr로 밝히고 실패한다."""
        result = self.run_configure(
            {
                "ADMOB_REQUIRE_PRODUCTION": "1",
                "ADMOB_TARGET_PLATFORM": "Android",
                "ADMOB_ANDROID_APP_ID": f"{PRODUCTION_PUBLISHER}~1000000001",
                "ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID": (
                    f"{PRODUCTION_PUBLISHER}/2000000001"
                ),
                "ADMOB_ANDROID_FOAM_BOMB_REWARDED_AD_UNIT_ID": (
                    f"{PRODUCTION_PUBLISHER}/3000000001"
                ),
            }
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Android rewarded/level_reward_2x", result.stderr)
        self.assertNotIn("iOS rewarded", result.stderr)

    def test_strict_android_passes_after_all_ids_are_injected(self) -> None:
        """AC: strict Android에서 app/interstitial/rewarded 전량 실ID 주입 시 통과한다."""
        result = self.run_configure(
            {
                "ADMOB_REQUIRE_PRODUCTION": "1",
                "ADMOB_TARGET_PLATFORM": "Android",
                "ADMOB_ANDROID_APP_ID": f"{PRODUCTION_PUBLISHER}~1000000001",
                "ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID": (
                    f"{PRODUCTION_PUBLISHER}/2000000001"
                ),
                "ADMOB_ANDROID_FOAM_BOMB_REWARDED_AD_UNIT_ID": (
                    f"{PRODUCTION_PUBLISHER}/3000000001"
                ),
                "ADMOB_ANDROID_LEVEL_REWARD_REWARDED_AD_UNIT_ID": (
                    f"{PRODUCTION_PUBLISHER}/3000000002"
                ),
            }
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        config = json.loads(self.config_path.read_text(encoding="utf-8"))
        android = config["platforms"]["Android"]
        self.assertNotIn(TEST_PUBLISHER, json.dumps(android))
        self.assertIn(
            f'{PRODUCTION_PUBLISHER}~1000000001',
            self.android_config.read_text(encoding="utf-8"),
        )
        self.assertIn(
            TEST_PUBLISHER,
            config["platforms"]["iOS"]["units"]["rewarded"]["foam_bomb_free"],
        )

    def test_require_production_cli_flag_is_supported(self) -> None:
        """AC: env 없이 --require-production 플래그로도 strict 검증을 켤 수 있다."""
        result = self.run_configure(
            {"ADMOB_TARGET_PLATFORM": "Android"},
            "--require-production",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Android appId", result.stderr)

    def test_rewarded_interstitial_id_is_rejected_for_rewarded_loader(self) -> None:
        """콘솔 형식이 다른 production ID가 strict를 우회하지 못한다."""
        result = self.run_configure(
            {
                "ADMOB_ANDROID_FOAM_BOMB_REWARDED_AD_UNIT_ID": (
                    "ca-app-pub-2444587584524186/5440739953"
                )
            }
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("AdMob console format is rewarded interstitial", result.stderr)


class ReleaseScriptContractTest(unittest.TestCase):
    def test_google_play_build_passes_strict_flag_to_android(self) -> None:
        script = ANDROID_BUILD.read_text(encoding="utf-8")
        self.assertIn('ADMOB_REQUIRE_PRODUCTION="${ADMOB_REQUIRE_PRODUCTION:-0}"', script)
        self.assertIn('ADMOB_TARGET_PLATFORM="${ADMOB_TARGET_PLATFORM:-Android}"', script)

    def test_xcode_cloud_passes_strict_flag_to_ios(self) -> None:
        script = IOS_POST_CLONE.read_text(encoding="utf-8")
        self.assertIn('ADMOB_REQUIRE_PRODUCTION="${ADMOB_REQUIRE_PRODUCTION:-0}"', script)
        self.assertIn('ADMOB_TARGET_PLATFORM="${ADMOB_TARGET_PLATFORM:-iOS}"', script)


if __name__ == "__main__":
    unittest.main(verbosity=2)

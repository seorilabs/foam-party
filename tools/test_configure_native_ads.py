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
IOS_PREPARE = REPO_ROOT / "tools" / "prepare_ios_native_ads.sh"
APP_STORE_CALLER = REPO_ROOT / ".github" / "workflows" / "deploy-app-store.yml"
ANALYTICS_DOCS = REPO_ROOT / "docs" / "analytics-events.md"
APP_STORE_RELEASE_DOCS = REPO_ROOT / "docs" / "app-store-release.md"
PLAY_STORE_CONFIG = REPO_ROOT / "play-store" / "google-play.config.json"
APP_STORE_CONFIG = REPO_ROOT / "app-store" / "app-store.config.json"
RETAINED_PUBLISHER_ID = "pub-9932778305312246"

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
        self.project_godot = self.root / "godot/project.godot"
        self.project_godot.write_text(
            "[admob]\n\n"
            f'general/android/app_id="{TEST_PUBLISHER}~3347511713"\n'
            f'general/ios/app_id="{TEST_PUBLISHER}~1458002511"\n',
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
            self.project_godot.read_text(encoding="utf-8"),
        )
        self.assertIn(
            TEST_PUBLISHER,
            config["platforms"]["iOS"]["units"]["rewarded"]["foam_bomb_free"],
        )

    def test_test_id_defaults_and_production_strict_boundary_are_preserved(self) -> None:
        """AC-4: 테스트 ID 기본값과 운영 strict 주입 경계를 유지한다."""
        default_result = self.run_configure()
        default_config = json.loads(self.config_path.read_text(encoding="utf-8"))

        self.assertEqual(default_result.returncode, 0, default_result.stderr)
        self.assertEqual(default_config["mode"], "google-test-defaults")
        self.assertIn(TEST_PUBLISHER, json.dumps(default_config["platforms"]["Android"]))
        self.assertIn(TEST_PUBLISHER, json.dumps(default_config["platforms"]["iOS"]))

        strict_result = self.run_configure(
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
        strict_config = json.loads(self.config_path.read_text(encoding="utf-8"))

        self.assertEqual(strict_result.returncode, 0, strict_result.stderr)
        self.assertEqual(strict_config["mode"], "environment-overrides")
        self.assertNotIn(TEST_PUBLISHER, json.dumps(strict_config["platforms"]["Android"]))
        self.assertIn(TEST_PUBLISHER, json.dumps(strict_config["platforms"]["iOS"]))

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

    def test_app_store_build_passes_strict_flag_to_ios(self) -> None:
        """iOS 운영 ID 주입은 App Store caller 가 넘기는 준비 스크립트가 책임진다."""
        script = IOS_PREPARE.read_text(encoding="utf-8")
        self.assertIn("ADMOB_TARGET_PLATFORM=iOS", script)
        self.assertIn("--require-production", script)

        caller = APP_STORE_CALLER.read_text(encoding="utf-8")
        self.assertIn("prepare_project_script: tools/prepare_ios_native_ads.sh", caller)

    def test_docs_record_production_variables_and_org_workflow_handoff(self) -> None:
        """AC: 운영에 필요한 전체 변수와 org 재사용 workflow 변경을 문서화한다."""
        docs = ANALYTICS_DOCS.read_text(encoding="utf-8")
        required_variables = [
            "ADMOB_REQUIRE_PRODUCTION",
            "ADMOB_ANDROID_APP_ID",
            "ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID",
            "ADMOB_ANDROID_FOAM_BOMB_REWARDED_AD_UNIT_ID",
            "ADMOB_ANDROID_LEVEL_REWARD_REWARDED_AD_UNIT_ID",
            "ADMOB_IOS_APP_ID",
            "ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID",
            "ADMOB_IOS_FOAM_BOMB_REWARDED_AD_UNIT_ID",
            "ADMOB_IOS_LEVEL_REWARD_REWARDED_AD_UNIT_ID",
        ]
        for variable in required_variables:
            with self.subTest(variable=variable):
                self.assertIn(variable, docs)
        self.assertIn("seorilabs/.github", docs)
        self.assertIn("godot-deploy-google-play.yml", docs)
        self.assertIn("Google Play `google-play` environment", docs)
        self.assertIn("app-store/app-store.config.json", docs)

    def test_release_environment_registration_state_is_recorded_in_repo(self) -> None:
        """AC-3: Xcode Cloud와 Google Play 릴리스 환경 반영 상태가 repo 원장에 남는다."""
        play = json.loads(PLAY_STORE_CONFIG.read_text(encoding="utf-8"))["adMob"]
        app_store = json.loads(APP_STORE_CONFIG.read_text(encoding="utf-8"))["adMob"]
        docs = ANALYTICS_DOCS.read_text(encoding="utf-8")

        self.assertEqual(
            play["productionUnitVerification"]["githubEnvironment"],
            "google-play",
        )
        self.assertEqual(
            app_store["productionUnitVerification"]["githubWorkflow"],
            "Deploy to App Store",
        )
        self.assertTrue(
            app_store["productionUnitVerification"]["strictProductionGuard"]
        )
        self.assertIn("Google Play `google-play` environment", docs)
        self.assertIn("app-store/app-store.config.json", docs)

    def test_console_verified_production_units_are_recorded_by_platform(self) -> None:
        """AC: 콘솔 확인한 운영 ID가 각 플랫폼의 실제 loader 형식 아래 기록된다."""
        play = json.loads(PLAY_STORE_CONFIG.read_text(encoding="utf-8"))["adMob"]
        app_store = json.loads(APP_STORE_CONFIG.read_text(encoding="utf-8"))["adMob"]

        self.assertEqual(play["publisherId"], RETAINED_PUBLISHER_ID)
        self.assertEqual(app_store["publisherId"], RETAINED_PUBLISHER_ID)

        self.assertEqual(
            play["androidInterstitialAdUnits"]["game_over"],
            "ca-app-pub-9932778305312246/6583552731",
        )
        self.assertEqual(
            play["androidRewardedAdUnits"]["foam_bomb_free"],
            "ca-app-pub-9932778305312246/1257319840",
        )
        self.assertEqual(
            play["androidRewardedAdUnits"]["level_reward_2x"],
            "ca-app-pub-9932778305312246/6318074836",
        )
        self.assertEqual(
            app_store["iosInterstitialAdUnits"]["game_over"],
            "ca-app-pub-9932778305312246/1584622900",
        )
        self.assertEqual(
            app_store["iosRewardedAdUnits"]["foam_bomb_free"],
            "ca-app-pub-9932778305312246/3266379398",
        )
        self.assertEqual(
            app_store["iosRewardedAdUnits"]["level_reward_2x"],
            "ca-app-pub-9932778305312246/3883483180",
        )

        release_docs = APP_STORE_RELEASE_DOCS.read_text(encoding="utf-8")
        for unit_id in (
            "ca-app-pub-9932778305312246/1584622900",
            "ca-app-pub-9932778305312246/3266379398",
            "ca-app-pub-9932778305312246/3883483180",
        ):
            with self.subTest(unit_id=unit_id):
                self.assertIn(unit_id, release_docs)


if __name__ == "__main__":
    unittest.main(verbosity=2)

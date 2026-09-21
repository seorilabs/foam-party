#!/usr/bin/env python3
"""Regression tests for the App Store AdMob SPM link patch.

headless CLI export 는 AdMob export 플러그인의 deferred pbxproj 패치를 실행하지
않으므로, export 직후 tools/prepare_ios_xcode_project.sh 가 이 스크립트로
결정론적으로 패치한다. GoogleMobileAds/UMP 링크가 다시 깨지지 않도록 링크 삽입과
idempotency 를 고정한다.
"""

from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_ios_package_resolved import EXPECTED_VERSIONS, validate_package_resolved
from patch_ios_admob_project import BUILD_FILE, LOCAL_REF, patch

REPO_ROOT = Path(__file__).resolve().parents[1]
POST_EXPORT_PREPARE = REPO_ROOT / "tools" / "prepare_ios_xcode_project.sh"
APP_STORE_CALLER = REPO_ROOT / ".github" / "workflows" / "deploy-app-store.yml"


# Godot 4.6.3 iOS export 가 굽는 pbxproj 의 최소 재현본. patch() 가 의존하는 앵커를
# 모두 포함한다: PBXBuildFile/PBXGroup 섹션 주석, PBXFrameworksBuildPhase 의 files
# 리스트, PBXProject 의 productRefGroup, PBXNativeTarget 의 buildRules.
GODOT_PBXPROJ_FIXTURE = """\
// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tobjectVersion = 56;
\tobjects = {

/* Begin PBXBuildFile section */
\t\t1FF8DBB11FBA9DE1009DE660 /* dummy.cpp in Sources */ = {isa = PBXBuildFile; fileRef = 1FF8DBB01FBA9DE1009DE660 /* dummy.cpp */; };
/* End PBXBuildFile section */

/* Begin PBXFrameworksBuildPhase section */
\t\t90B4C2B32680C7E90039117A /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t9039D3BE24C093AC0020482C /* MoltenVK.xcframework in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t90B4C2AD2680C7E90039117A = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t90B4C2B52680C7E90039117A /* foam-party */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = "foam-party";
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t90B4C2AE2680C7E90039117A /* Project object */ = {
\t\t\tisa = PBXProject;
\t\t\tproductRefGroup = 90B4C2B72680C7E90039117A /* Products */;
\t\t\ttargets = (
\t\t\t\t90B4C2B52680C7E90039117A /* foam-party */,
\t\t\t);
\t\t};
/* End PBXProject section */
\t};
\trootObject = 90B4C2AE2680C7E90039117A /* Project object */;
}
"""


class PatchIosAdMobProjectTest(unittest.TestCase):
    def _write_fixture(self, content: str = GODOT_PBXPROJ_FIXTURE) -> Path:
        fixture_dir = tempfile.TemporaryDirectory()
        self.addCleanup(fixture_dir.cleanup)
        fixture_path = Path(fixture_dir.name) / "project.pbxproj"
        fixture_path.write_text(content, encoding="utf-8")
        return fixture_path

    def test_patch_links_local_swift_package(self) -> None:
        """AC: patch 가 PoingGodotAdMobDeps(→ GoogleMobileAds/UMP) 를 링크한다."""
        path = self._write_fixture()
        patch(path)
        patched = path.read_text(encoding="utf-8")

        # 로컬 SPM 패키지 참조와 product dependency 가 정의된다.
        self.assertIn("isa = XCLocalSwiftPackageReference;", patched)
        self.assertIn('relativePath = ".";', patched)
        self.assertIn("isa = XCSwiftPackageProductDependency;", patched)
        self.assertIn('productName = "PoingGodotAdMobDeps";', patched)

        # PBXProject.packageReferences 와 PBXNativeTarget.packageProductDependencies
        # 가 새로 생겨 각각 로컬 참조/프로덕트를 담는다.
        self.assertIn("packageReferences = (", patched)
        self.assertIn("packageProductDependencies = (", patched)

        # Frameworks 빌드 페이즈 files 리스트에 실제로 링크 엔트리가 들어간다.
        frameworks_at = patched.find("isa = PBXFrameworksBuildPhase;")
        entry_at = patched.find(
            f"{BUILD_FILE} /* PoingGodotAdMobDeps in Frameworks */,"
        )
        self.assertNotEqual(entry_at, -1, "링크 엔트리가 files 리스트에 없음")
        self.assertGreater(entry_at, frameworks_at)

    def test_patch_is_idempotent(self) -> None:
        """AC: 패치는 재실행에 안전하다(두 번째 실행은 no-op)."""
        path = self._write_fixture()
        patch(path)
        once = path.read_text(encoding="utf-8")
        patch(path)
        twice = path.read_text(encoding="utf-8")

        self.assertEqual(once, twice, "재실행이 pbxproj 를 다시 변경함")
        # marker/frameworks 엔트리가 중복 삽입되지 않는다.
        self.assertEqual(twice.count(f"package = {LOCAL_REF}"), 1)
        self.assertEqual(
            twice.count(f"{BUILD_FILE} /* PoingGodotAdMobDeps in Frameworks */"),
            2,  # 정의 1 + files 리스트 참조 1
        )

    def test_missing_anchor_fails_loudly(self) -> None:
        """앵커가 없으면 조용히 통과하지 않고 실패한다."""
        broken = GODOT_PBXPROJ_FIXTURE.replace("/* End PBXGroup section */", "")
        path = self._write_fixture(broken)
        with self.assertRaises(SystemExit):
            patch(path)


class AppStoreExportOrchestrationTest(unittest.TestCase):
    """App Store 빌드가 export 전후로 올바른 스크립트를 부르는지 고정한다.

    headless export 는 AdMob export 플러그인의 deferred pbxproj 패치를 실행하지 않으므로
    export 후 patch_ios_admob_project.py 호출이 반드시 있어야 GAD*/UMP* 링크가 성공한다.
    광고 ID 는 export 시점의 .gdip 를 읽으므로 광고 ID 주입은 export 전에 끝나야 한다.
    export 와의 상대 순서는 중앙 워크플로우(godot-deploy-app-store.yml)가 caller input
    이름으로 소유하므로, caller 배선과 스크립트 내부 단계 순서를 각각 고정한다.
    """

    def setUp(self) -> None:
        self.script = POST_EXPORT_PREPARE.read_text(encoding="utf-8")
        self.caller = APP_STORE_CALLER.read_text(encoding="utf-8")

    def test_patches_pbxproj_after_export(self) -> None:
        """AC-1: export 후 스크립트가 tools/patch_ios_admob_project.py 로 pbxproj 를 패치한다."""
        self.assertIn("tools/patch_ios_admob_project.py", self.script)
        self.assertIn(
            "post_export_project_script: tools/prepare_ios_xcode_project.sh",
            self.caller,
        )

    def test_configures_native_ads_before_export(self) -> None:
        """AC-2: export 전 준비 스크립트가 광고 ID 를 확정한다."""
        self.assertIn(
            "prepare_project_script: tools/prepare_ios_native_ads.sh", self.caller
        )
        prepare = (REPO_ROOT / "tools" / "prepare_ios_native_ads.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("tools/configure_native_ads.py", prepare)
        self.assertIn("--require-production", prepare)

    def test_resolves_packages_after_pbxproj_patch(self) -> None:
        """AC-3: pbxproj 패치 후 package resolve 와 lockfile 검증을 수행한다."""
        patch_at = self.script.find("tools/patch_ios_admob_project.py")
        swift_resolve_at = self.script.find(
            'swift package --package-path "$package_dir" resolve'
        )
        copy_at = self.script.find(
            'cp "$swift_resolved" "${resolved_dir}/Package.resolved"'
        )
        xcode_resolve_at = self.script.find("-resolvePackageDependencies")
        locked_xcode_at = self.script.find("-onlyUsePackageVersionsFromResolvedFile")
        version_check_at = self.script.find("tools/check_ios_package_resolved.py")

        self.assertNotEqual(patch_at, -1, "patch_ios_admob_project.py 호출이 없음")
        self.assertNotEqual(swift_resolve_at, -1, "SwiftPM resolve 호출이 없음")
        self.assertNotEqual(copy_at, -1, "SwiftPM lockfile 복사가 없음")
        self.assertNotEqual(xcode_resolve_at, -1, "Xcode package resolve 호출이 없음")
        self.assertNotEqual(locked_xcode_at, -1, "Xcode lockfile 강제가 없음")
        self.assertNotEqual(version_check_at, -1, "resolved SDK 버전 검증이 없음")
        self.assertGreater(
            swift_resolve_at,
            patch_at,
            "SwiftPM resolve 는 pbxproj 패치 뒤에서 실행돼야 함",
        )
        self.assertGreater(
            copy_at,
            swift_resolve_at,
            "lockfile 복사는 SwiftPM resolve 뒤에서 실행돼야 함",
        )
        self.assertGreater(
            xcode_resolve_at,
            copy_at,
            "Xcode resolve 는 project lockfile 복사 뒤에서 실행돼야 함",
        )
        self.assertGreater(
            locked_xcode_at,
            xcode_resolve_at,
            "Xcode resolve 는 copied lockfile만 사용해야 함",
        )
        self.assertGreater(
            version_check_at,
            locked_xcode_at,
            "resolved SDK 버전 검증은 locked Xcode resolve 뒤에서 실행돼야 함",
        )


class IosPackageResolvedValidationTest(unittest.TestCase):
    def _write_resolved(self, versions: dict[str, str]) -> Path:
        fixture_dir = tempfile.TemporaryDirectory()
        self.addCleanup(fixture_dir.cleanup)
        path = Path(fixture_dir.name) / "Package.resolved"
        path.write_text(
            json.dumps(
                {
                    "version": 3,
                    "pins": [
                        {
                            "identity": identity,
                            "kind": "remoteSourceControl",
                            "location": f"https://example.invalid/{identity}.git",
                            "state": {
                                "revision": "fixture",
                                "version": version,
                            },
                        }
                        for identity, version in versions.items()
                    ],
                }
            ),
            encoding="utf-8",
        )
        return path

    def test_accepts_exact_admob_and_ump_versions(self) -> None:
        """AC-3: 실제 lockfile 의 Ads 13.3.0 및 UMP 3.1.0을 직접 검증한다."""
        path = self._write_resolved(EXPECTED_VERSIONS)
        resolved = validate_package_resolved(path)

        self.assertEqual(
            resolved["swift-package-manager-google-mobile-ads"], "13.3.0"
        )
        self.assertEqual(
            resolved["swift-package-manager-google-user-messaging-platform"],
            "3.1.0",
        )

    def test_rejects_resolved_version_drift(self) -> None:
        drifted = dict(EXPECTED_VERSIONS)
        drifted["swift-package-manager-google-mobile-ads"] = "99.0.0"
        path = self._write_resolved(drifted)

        with self.assertRaisesRegex(
            SystemExit,
            "expected 13.3.0, got 99.0.0",
        ):
            validate_package_resolved(path)


if __name__ == "__main__":
    unittest.main(verbosity=2)

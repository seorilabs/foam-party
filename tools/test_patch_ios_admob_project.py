#!/usr/bin/env python3
"""Regression tests for the Xcode Cloud AdMob SPM link patch.

headless CLI export 는 AdMob export 플러그인의 deferred pbxproj 패치를 실행하지
않으므로, ci_post_clone.sh 가 export 후 이 스크립트로 결정론적으로 패치한다.
GoogleMobileAds/UMP 링크가 다시 깨지지 않도록 링크 삽입과 idempotency 를 고정한다.
"""

from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

from patch_ios_admob_project import BUILD_FILE, LOCAL_REF, patch


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


if __name__ == "__main__":
    unittest.main(verbosity=2)

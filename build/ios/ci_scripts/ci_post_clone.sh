#!/bin/sh

# Xcode Cloud — Foam Party(Godot) iOS 빌드 사전 준비.
#
# Foam Party는 Godot 게임이라 Xcode 프로젝트를 저장소에 커밋하지 않고 export 때
# 생성한다. Xcode Cloud 는 저장소 클론 직후(이 스크립트) build/ios/foam-party.xcodeproj
# 를 만들어야 이어지는 archive 단계가 그 scheme(foam-party)을 빌드할 수 있다.
# (Xcode Cloud 워크플로 container = build/ios/foam-party.xcodeproj)
#
# ci_scripts 는 컨테이너(.xcodeproj) 인접 디렉터리 build/ios/ci_scripts/ 에 둔다.
# Xcode Cloud 는 ci_scripts 를 프로젝트 인접에서 찾으므로 저장소 루트에 두면 실행되지
# 않는다(build 3 검증). build/ 는 gitignore 지만 이 경로만 예외로 추적한다.
# 코드 서명은 Xcode Cloud 매니지드 서명이 처리하므로 여기서 다루지 않는다.
# Godot 설치 + export templates + import + export 는 build 1003 을 성공적으로 올린
# org godot-deploy-app-store.yml 과 동일한 방식(특히 templates 경로는 검증된
# scripts/ensure_godot.sh 에 위임)이다.

set -e

GODOT_VERSION="4.6.3"
GODOT_STATUS="stable"
BASE="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_STATUS}"

# Xcode Cloud 는 ci_scripts 디렉터리에서 실행한다. 저장소 루트로 이동.
REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../../.." && pwd)}"
cd "${REPO}"

echo "▸ Node 설치(Homebrew) — 릴리즈 버전 resolver(ci_pre_xcodebuild)용"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
brew install node || true

echo "▸ Godot ${GODOT_VERSION}-${GODOT_STATUS} 설치(macOS universal) → PATH"
curl -fsSL "${BASE}/Godot_v${GODOT_VERSION}-${GODOT_STATUS}_macos.universal.zip" -o /tmp/godot.zip
unzip -q -o /tmp/godot.zip -d /tmp/godotapp
mkdir -p "${HOME}/.local/bin"
ln -sf /tmp/godotapp/Godot.app/Contents/MacOS/Godot "${HOME}/.local/bin/godot"
PATH="${HOME}/.local/bin:${PATH}"
export PATH
godot --version

echo "▸ Godot export templates 설치(검증된 scripts/ensure_godot.sh — macOS 경로 처리 포함)"
GODOT_VERSION="${GODOT_VERSION}" GODOT_STATUS="${GODOT_STATUS}" \
  bash scripts/ensure_godot.sh --with-export-templates

echo "▸ Godot 프로젝트 import"
godot --headless --path godot --import --quit-after 1

echo "▸ 네이티브 AdMob ID 설정(ADMOB_* 환경 변수 오버라이드 또는 native_ads.json 기본값)"
# .gdip 의 GADApplicationIdentifier 와 광고 유닛 ID 를 export 전에 확정한다. 이 단계를
# 생략하면 커밋된 테스트 ID 가 그대로 아카이브된다. tools/build_ios_app_store.sh 와 동일.
ADMOB_REQUIRE_PRODUCTION="${ADMOB_REQUIRE_PRODUCTION:-0}" \
ADMOB_TARGET_PLATFORM="${ADMOB_TARGET_PLATFORM:-iOS}" \
  python3 "${REPO}/tools/configure_native_ads.py"

echo "▸ iOS Xcode 프로젝트 export → build/ios/foam-party.xcodeproj"
mkdir -p build/ios
godot --headless --path godot --export-release iOS "${REPO}/build/ios/foam-party.xcodeproj"
[ -d "${REPO}/build/ios/foam-party.xcodeproj" ] || {
  echo "  Xcode 프로젝트가 생성되지 않음: build/ios/foam-party.xcodeproj" >&2
  exit 1
}

echo "▸ AdMob SPM 로컬 패키지를 Xcode 프로젝트에 링크"
# AdMob export 플러그인은 pbxproj 패치를 call_deferred 로 예약하는데, headless CLI
# export 는 deferred 콜을 처리하기 전에 종료하므로 패치가 실행되지 않는다. 그러면
# PoingGodotAdMobDeps(→ GoogleMobileAds/UMP) 가 링크되지 않아 GAD*/UMP* Undefined
# symbol 로 링크가 실패한다. Package.swift/PoingGodotAdMobDeps 는 export 시 동기로
# 생성되므로, export 후 pbxproj 만 결정론적으로 패치한다(로컬 빌드 경로와 동일).
python3 "${REPO}/tools/patch_ios_admob_project.py" "${REPO}/build/ios/foam-party.xcodeproj/project.pbxproj"

echo "▸ SwiftPM lockfile 생성 및 Xcode 프로젝트에 고정"
# Xcode Cloud 워크플로는 자동 package resolution 을 비활성화하므로 lockfile 없는
# xcodebuild resolver 자체가 exit 74로 실패한다. 먼저 SwiftPM CLI로 로컬 패키지의
# Package.resolved 를 만든 뒤 Xcode project workspace 경로에 복사하고, Xcode에는
# lockfile에 기록된 exact 버전만 사용하도록 요구한다.
swift package --package-path "${REPO}/build/ios" resolve
SWIFT_PACKAGE_RESOLVED="${REPO}/build/ios/Package.resolved"
[ -f "${SWIFT_PACKAGE_RESOLVED}" ] || {
  echo "  SwiftPM lockfile 이 생성되지 않음: ${SWIFT_PACKAGE_RESOLVED}" >&2
  exit 1
}
PACKAGE_RESOLVED_DIR="${REPO}/build/ios/foam-party.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "${PACKAGE_RESOLVED_DIR}"
PACKAGE_RESOLVED="${PACKAGE_RESOLVED_DIR}/Package.resolved"
cp "${SWIFT_PACKAGE_RESOLVED}" "${PACKAGE_RESOLVED}"
xcodebuild \
  -resolvePackageDependencies \
  -project "${REPO}/build/ios/foam-party.xcodeproj" \
  -scheme foam-party \
  -onlyUsePackageVersionsFromResolvedFile
[ -f "${PACKAGE_RESOLVED}" ] || {
  echo "  Xcode project lockfile 이 생성되지 않음: ${PACKAGE_RESOLVED}" >&2
  exit 1
}
python3 "${REPO}/tools/check_ios_package_resolved.py" "${PACKAGE_RESOLVED}"

echo "▸ 생성된 scheme 확인"
xcodebuild -list -project "${REPO}/build/ios/foam-party.xcodeproj" || true

echo "✅ ci_post_clone 완료"

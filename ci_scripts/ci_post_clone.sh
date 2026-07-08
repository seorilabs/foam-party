#!/bin/sh

# Xcode Cloud — Foam Party(Godot) iOS 빌드 사전 준비.
#
# Foam Party는 Godot 게임이라 Xcode 프로젝트를 저장소에 커밋하지 않고 export 때
# 생성한다. Xcode Cloud 는 저장소 클론 직후(이 스크립트) build/ios/foam-party.xcodeproj
# 를 만들어야 이어지는 archive 단계가 그 scheme(foam-party)을 빌드할 수 있다.
# (Xcode Cloud 워크플로 container = build/ios/foam-party.xcodeproj)
#
# ci_scripts 는 저장소 루트에 둔다(build/ 는 gitignore 대상이라 프로젝트 인접 불가).
# 코드 서명은 Xcode Cloud 매니지드 서명이 처리하므로 여기서 다루지 않는다.
# Godot 설치 + export templates + import + export 는 build 1003 을 성공적으로 올린
# org godot-deploy-app-store.yml 과 동일한 방식(특히 templates 경로는 검증된
# scripts/ensure_godot.sh 에 위임)이다.

set -e

GODOT_VERSION="4.6.3"
GODOT_STATUS="stable"
BASE="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_STATUS}"

# Xcode Cloud 는 ci_scripts 디렉터리에서 실행한다. 저장소 루트로 이동.
REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
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

echo "▸ iOS Xcode 프로젝트 export → build/ios/foam-party.xcodeproj"
mkdir -p build/ios
godot --headless --path godot --export-release iOS "${REPO}/build/ios/foam-party.xcodeproj"
[ -d "${REPO}/build/ios/foam-party.xcodeproj" ] || {
  echo "  Xcode 프로젝트가 생성되지 않음: build/ios/foam-party.xcodeproj" >&2
  exit 1
}

echo "▸ 생성된 scheme 확인"
xcodebuild -list -project "${REPO}/build/ios/foam-party.xcodeproj" || true

echo "✅ ci_post_clone 완료"

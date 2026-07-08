#!/bin/sh

# Xcode Cloud — archive 직전 릴리즈 버전 설정.
#
# 태그(vX.Y.Z) 트리거 빌드일 때 scripts/resolve-release-version.mjs 로
# CFBundleShortVersionString(marketing)/CFBundleVersion(build number)을 산출해
# Godot 이 export 한 프로젝트의 Info.plist 에 반영한다. 이 조정을 안 하면
# export_presets 의 기본값(0.1.1 / build 1)이 그대로 아카이브돼 App Store Connect
# 의 기존 build train(마지막 론칭 4) 과 충돌한다.
# GH 배포(godot-deploy-app-store.yml)와 동일한 resolver 를 써서 빌드번호가 일치한다.
# (node 는 ci_post_clone 에서 이미 설치됨.)

set -e

REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../../.." && pwd)}"

if [ -z "${CI_TAG:-}" ]; then
  echo "▸ CI_TAG 없음 — 릴리즈 버전 조정 생략(검증/브랜치 빌드는 프로젝트 기본값 유지)"
  exit 0
fi

echo "▸ 릴리즈 버전 산출 (tag=${CI_TAG})"
OUTFILE="$(mktemp)"
GITHUB_OUTPUT="${OUTFILE}" node "${REPO}/scripts/resolve-release-version.mjs" \
  --tag "${CI_TAG}" --github-output --quiet
MARKETING="$(grep '^apple_marketing_version=' "${OUTFILE}" | cut -d= -f2)"
BUILD="$(grep '^apple_build_number=' "${OUTFILE}" | cut -d= -f2)"

if [ -z "${MARKETING}" ] || [ -z "${BUILD}" ]; then
  echo "  릴리즈 버전 산출 실패 (tag=${CI_TAG})" >&2
  exit 1
fi
echo "  marketing=${MARKETING} build=${BUILD}"

# Godot iOS export 산출 앱 Info.plist 를 찾아 버전 키를 덮어쓴다.
# Godot 은 앱 메인 plist 를 <export_basename>-Info.plist(= foam-party-Info.plist)로
# 굽는다. 광고(GADApplicationIdentifier)·프레임워크·PrivacyInfo 등 다른 plist 를
# 잘못 매칭하지 않도록 정확한 이름만 대상으로 한다.
INFO_PLIST="$(find "${REPO}/build/ios" -maxdepth 3 -name 'foam-party-Info.plist' 2>/dev/null | head -n 1)"
if [ -z "${INFO_PLIST}" ] || [ ! -f "${INFO_PLIST}" ]; then
  echo "  앱 Info.plist(foam-party-Info.plist)를 build/ios 에서 찾지 못함" >&2
  echo "  build/ios 하위 plist 목록:" >&2
  find "${REPO}/build/ios" -maxdepth 3 -name '*.plist' >&2 2>/dev/null || true
  exit 1
fi
echo "  Info.plist=${INFO_PLIST}"

plutil -replace CFBundleShortVersionString -string "${MARKETING}" "${INFO_PLIST}"
plutil -replace CFBundleVersion -string "${BUILD}" "${INFO_PLIST}"
echo "✅ 버전 설정 완료: ${MARKETING} (${BUILD})"

#!/bin/sh

# Xcode Cloud — archive 직전 릴리즈 버전 주입.
#
# 버전 authority 는 stable SemVer 태그(vX.Y.Z)의 exact commit 하나다. 저장소는 버전을
# 계산하지 않는다. 불변 중앙 commit 의 org 정본 helper 를 내려받아 sha256 을 검증한 뒤
# 실행하고, helper 가 CFBundleShortVersionString/CFBundleVersion 을 Info.plist 에 주입한
# 다음 다시 읽어 대조한다. 주입하지 않으면 export_presets 기본값이 그대로 아카이브돼
# App Store Connect build train 과 충돌한다. (org 계약: release-version-authority-v1)
#
# node 는 ci_post_clone 에서 이미 설치된다.

set -e

SEORI_AUTHORITY_SHA="9afa357f9ba6c8d6a813c7cec7ad3d35c626bdd5"
SEORI_AUTHORITY_BASE="https://raw.githubusercontent.com/seorilabs/.github/${SEORI_AUTHORITY_SHA}/scripts/release"
SEORI_SHA256_TAG_VERSION_AUTHORITY="ca9ef5b4fe326323840b171f9e6ed069cb182d2aee8e88b72e352c57514d466b"
SEORI_SHA256_XCODE_CLOUD_APPLY="b399afde0016e23947e173437e266aa83071079d1345b41ff580ebfe63357d6f"

REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../../.." && pwd)}"

if [ -z "${CI_TAG:-}" ]; then
  echo "▸ CI_TAG 없음 — 릴리즈 버전 주입 생략(검증/브랜치 빌드는 프로젝트 기본값 유지)"
  exit 0
fi

echo "▸ 릴리즈 버전 주입 (tag=${CI_TAG})"

# helper 는 HEAD 가 refs/tags/<tag> 의 commit 과 같은지 검증한다. Xcode Cloud 는 얕게
# 클론하므로 태그 ref 가 없으면 원격에서 그 태그만 가져온다. 값은 여전히 태그가 정한다.
if ! git -C "${REPO}" rev-parse "refs/tags/${CI_TAG}^{commit}" >/dev/null 2>&1; then
  echo "  로컬에 태그 ref 없음 — origin 에서 ${CI_TAG} 만 가져옴"
  git -C "${REPO}" fetch --no-tags --depth 1 origin "refs/tags/${CI_TAG}:refs/tags/${CI_TAG}"
fi

AUTHORITY_DIR="$(mktemp -d)"
trap 'rm -rf "${AUTHORITY_DIR}"' EXIT

fetch_authority_file() {
  name="$1"
  expected="$2"
  curl -fsSL "${SEORI_AUTHORITY_BASE}/${name}" -o "${AUTHORITY_DIR}/${name}"
  actual="$(shasum -a 256 "${AUTHORITY_DIR}/${name}" | cut -d' ' -f1)"
  if [ "${actual}" != "${expected}" ]; then
    echo "  org 정본 ${name} sha256 불일치: expected=${expected} actual=${actual}" >&2
    exit 1
  fi
}

# xcode-cloud-apply-tag-version.mjs 가 같은 디렉터리의 tag-version-authority.mjs 를 import 한다.
fetch_authority_file "tag-version-authority.mjs" "${SEORI_SHA256_TAG_VERSION_AUTHORITY}"
fetch_authority_file "xcode-cloud-apply-tag-version.mjs" "${SEORI_SHA256_XCODE_CLOUD_APPLY}"

# Godot 은 앱 메인 plist 를 <export_basename>-Info.plist(= foam-party-Info.plist)로 굽는다.
# 광고(GADApplicationIdentifier)·프레임워크·PrivacyInfo 등 다른 plist 를 잘못 매칭하지
# 않도록 정확한 이름만 대상으로 한다.
INFO_PLIST="$(find "${REPO}/build/ios" -maxdepth 3 -name 'foam-party-Info.plist' 2>/dev/null | head -n 1)"
if [ -z "${INFO_PLIST}" ] || [ ! -f "${INFO_PLIST}" ]; then
  echo "  앱 Info.plist(foam-party-Info.plist)를 build/ios 에서 찾지 못함" >&2
  echo "  build/ios 하위 plist 목록:" >&2
  find "${REPO}/build/ios" -maxdepth 3 -name '*.plist' >&2 2>/dev/null || true
  exit 1
fi
echo "  Info.plist=${INFO_PLIST}"

node "${AUTHORITY_DIR}/xcode-cloud-apply-tag-version.mjs" \
  --tag "${CI_TAG}" \
  --repository "${REPO}" \
  --info-plist "${INFO_PLIST}"

echo "✅ 릴리즈 버전 주입 완료"

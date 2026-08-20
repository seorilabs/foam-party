#!/usr/bin/env bash
#
# 서명된 Google Play AAB 를 만든다. 이 스크립트가 이 repo 의 Android 빌드 정의다.
#
# 계약: seorilabs/.github docs/ci-cd/build-toolchain-contract.md
#
# 로컬·GitHub Actions·Cloud Build 가 모두 이 스크립트를 같은 빌더 이미지에서 부른다.
# 그래서 CI 실패를 로컬에서 그대로 재현할 수 있다.
#
#   docker run --rm -v "$PWD:/workspace" -w /workspace \
#     -e ANDROID_VERSION_NAME=1.2.3 \
#     -e GOOGLE_PLAY_UPLOAD_KEYSTORE_BASE64 -e GOOGLE_PLAY_UPLOAD_KEYSTORE_PASSWORD \
#     asia-northeast3-docker.pkg.dev/seorilabs-ci/builders/godot-android-builder:4.7.2 \
#     bash scripts/build-android.sh
#
# 툴체인(Godot, JDK, Android SDK)은 이미지가 제공한다. 없으면 설치하지 않고 실패한다.
# 여기서 설치하기 시작하면 실행 위치마다 도구가 갈려 재현성이 사라진다.
#
# 입력은 환경변수로 받는다.
#   필수  ANDROID_VERSION_NAME                    stable SemVer (예: 1.2.3)
#         GOOGLE_PLAY_UPLOAD_KEYSTORE_BASE64      업로드 키스토어
#         GOOGLE_PLAY_UPLOAD_KEYSTORE_PASSWORD
#   선택  ANDROID_VERSION_CODE                    비우면 versionName 에서 파생
#         GOOGLE_PLAY_UPLOAD_KEY_ALIAS / _KEY_PASSWORD
#         GODOT_ANALYTICS_CONFIG_JSON_BASE64      미설정이면 GA4 비활성 빌드
#         ADMOB_APP_ID / ADMOB_INTERSTITIAL_AD_UNIT_ID
#
# 출력은 build.env 의 AAB_PATH 고정 경로.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

[ -f build.env ] || { echo "build.env 가 없다. 툴체인 선언이 있어야 한다." >&2; exit 1; }
# shellcheck disable=SC1091
set -a; . ./build.env; set +a

require_env() {
  local name="$1"
  [ -n "${!name:-}" ] || { echo "필수 환경변수 없음: $name" >&2; exit 1; }
}

require_tool() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || {
    echo "툴체인에 $name 이 없다. 빌더 이미지가 잘못됐다 — 여기서 설치하지 않는다." >&2
    exit 1
  }
}

# ── 0. 전제 확인 ─────────────────────────────────────────────────────────────
for tool in godot java keytool python3; do require_tool "$tool"; done
require_env ANDROID_VERSION_NAME
require_env GOOGLE_PLAY_UPLOAD_KEYSTORE_BASE64
require_env GOOGLE_PLAY_UPLOAD_KEYSTORE_PASSWORD
[ -d "$PROJECT_DIR" ] || { echo "PROJECT_DIR 없음: $PROJECT_DIR" >&2; exit 1; }

# 이미지의 엔진이 build.env 선언과 다르면 조용히 다른 버전으로 빌드된다.
engine="$(godot --headless --version | head -1)"
case "$engine" in
  "${GODOT_VERSION}.${GODOT_STATUS}"*) ;;
  *) echo "엔진 불일치: 이미지=$engine, build.env=${GODOT_VERSION}.${GODOT_STATUS}" >&2; exit 1 ;;
esac
echo "godot $engine"

# ── 1. 버전 확정 ─────────────────────────────────────────────────────────────
version_args=(--version-name "$ANDROID_VERSION_NAME")
[ -n "${ANDROID_VERSION_CODE:-}" ] && version_args+=(--version-code "$ANDROID_VERSION_CODE")
python3 "$SCRIPTS_DIR/set_google_play_version_code.py" "${version_args[@]}" > /tmp/gp-version.json
cat /tmp/gp-version.json

# ── 2. GA4 설정 복원 ─────────────────────────────────────────────────────────
# 미설정은 애널리틱스 비활성 빌드로 통과시킨다. 손상된 값은 조용히 넘기지 않는다.
if [ -n "${GODOT_ANALYTICS_CONFIG_JSON_BASE64:-}" ]; then
  tmp="$(mktemp)"
  if printf '%s' "$GODOT_ANALYTICS_CONFIG_JSON_BASE64" | base64 --decode > "$tmp" 2>/dev/null ||
     printf '%s' "$GODOT_ANALYTICS_CONFIG_JSON_BASE64" | base64 -D > "$tmp" 2>/dev/null; then
    :
  else
    rm -f "$tmp"; echo "GODOT_ANALYTICS_CONFIG_JSON_BASE64 디코드 실패" >&2; exit 1
  fi
  [ -s "$tmp" ] && [ "$(head -c1 "$tmp")" = "{" ] || {
    rm -f "$tmp"; echo "복원된 analytics.config.json 이 비었거나 JSON 이 아니다" >&2; exit 1
  }
  mv "$tmp" "$PROJECT_DIR/analytics.config.json"
  echo "analytics.config.json 복원"
else
  echo "GODOT_ANALYTICS_CONFIG_JSON_BASE64 미설정 — GA4 비활성 빌드"
fi

# ── 3. AdMob 값 검증 ─────────────────────────────────────────────────────────
# 테스트 광고 ID 로 스토어 빌드가 나가면 수익이 0 이 되고 정책 위반이 된다.
if [ -n "${ADMOB_APP_ID:-}" ]; then
  [ "$ADMOB_APP_ID" != "ca-app-pub-3940256099942544~3347511713" ] || {
    echo "ADMOB_APP_ID 가 테스트 ID 다" >&2; exit 1; }
  [ "${ADMOB_INTERSTITIAL_AD_UNIT_ID:-}" != "ca-app-pub-3940256099942544/1033173712" ] || {
    echo "ADMOB_INTERSTITIAL_AD_UNIT_ID 가 테스트 ID 다" >&2; exit 1; }
fi

# ── 4. 프로젝트 import ───────────────────────────────────────────────────────
godot --headless --path "$PROJECT_DIR" --import --quit-after 1

# ── 5. Android 빌드 템플릿과 AdMob 플러그인 ──────────────────────────────────
[ -f "$SCRIPTS_DIR/install_android_build_template.sh" ] &&
  bash "$SCRIPTS_DIR/install_android_build_template.sh"
[ -f "$SCRIPTS_DIR/build_admob_plugin.sh" ] &&
  bash "$SCRIPTS_DIR/build_admob_plugin.sh"

# ── 6. 서명 AAB export ───────────────────────────────────────────────────────
keystore="$(mktemp /tmp/upload-keystore.XXXXXX.jks)"
trap 'rm -f "$keystore"' EXIT
printf '%s' "$GOOGLE_PLAY_UPLOAD_KEYSTORE_BASE64" | base64 --decode > "$keystore" 2>/dev/null ||
  printf '%s' "$GOOGLE_PLAY_UPLOAD_KEYSTORE_BASE64" | base64 -D > "$keystore"
[ -s "$keystore" ] || { echo "키스토어 디코드 실패" >&2; exit 1; }

# alias 는 키스토어에서 읽는다. repo 변수와 어긋나도 실제 키를 따른다.
alias="$(keytool -list -v -keystore "$keystore" -storepass "$GOOGLE_PLAY_UPLOAD_KEYSTORE_PASSWORD" |
  awk -F': ' '/^Alias name: /{print $2; exit}')"
[ -n "$alias" ] || { echo "업로드 키 alias 탐지 실패" >&2; exit 1; }

key_password="$GOOGLE_PLAY_UPLOAD_KEYSTORE_PASSWORD"
if [ -n "${GOOGLE_PLAY_UPLOAD_KEY_ALIAS:-}" ] && [ "$alias" = "$GOOGLE_PLAY_UPLOAD_KEY_ALIAS" ] &&
   [ -n "${GOOGLE_PLAY_UPLOAD_KEY_PASSWORD:-}" ]; then
  key_password="$GOOGLE_PLAY_UPLOAD_KEY_PASSWORD"
fi

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$alias"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$GOOGLE_PLAY_UPLOAD_KEYSTORE_PASSWORD"
export GODOT_ANDROID_KEYSTORE_RELEASE_KEY_PASSWORD="$key_password"

mkdir -p "$(dirname "$AAB_PATH")"
godot --headless --path "$PROJECT_DIR" --export-release Android "$repo_root/$AAB_PATH"

# ── 7. 산출물 검증 ───────────────────────────────────────────────────────────
# export 가 조용히 실패해도 종료 코드가 0 인 경우가 있어 파일로 끊는다.
[ -s "$repo_root/$AAB_PATH" ] || { echo "AAB 가 생성되지 않았다: $AAB_PATH" >&2; exit 1; }
if [ -f "$SCRIPTS_DIR/check_google_play_readiness.py" ]; then
  python3 "$SCRIPTS_DIR/check_google_play_readiness.py"
fi

echo "AAB 완료: $AAB_PATH ($(wc -c < "$repo_root/$AAB_PATH") bytes)"

#!/usr/bin/env bash
# Godot import 전에 실행한다. iOS 네이티브 AdMob ID 를 운영값으로 확정한다.
#
# godot/config/native_ads.json 의 커밋된 기본값은 Google 테스트 ID 다. 그대로
# archive 하면 테스트 광고가 실린 빌드가 App Store 에 올라간다.
#
# 운영 ID 는 비밀값이 아니다. 배포된 앱 바이너리에 그대로 들어가고 AdMob 콘솔에서
# 공개 식별자로 다룬다. 그래서 시크릿이 아니라 app-store/app-store.config.json 의
# adMob 절을 정본으로 읽는다. 값이 한 곳에만 있어 CI 변수와 어긋날 일이 없다.
#
# --require-production 으로 테스트 ID 가 하나라도 남으면 빌드를 멈춘다.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="${repo_root}/app-store/app-store.config.json"
[ -f "$config" ] || { echo "[ios-ads] 설정을 찾을 수 없다: ${config}" >&2; exit 1; }

eval "$(python3 - "$config" <<'PY'
import json, shlex, sys

admob = json.load(open(sys.argv[1])).get("adMob") or {}
interstitial = admob.get("iosInterstitialAdUnits") or {}
rewarded = admob.get("iosRewardedAdUnits") or {}

wanted = {
    "ADMOB_IOS_APP_ID": admob.get("iosAppId"),
    "ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID": interstitial.get("game_over"),
    "ADMOB_IOS_FOAM_BOMB_REWARDED_AD_UNIT_ID": rewarded.get("foam_bomb_free"),
    "ADMOB_IOS_LEVEL_REWARD_REWARDED_AD_UNIT_ID": rewarded.get("level_reward_2x"),
}

missing = [k for k, v in wanted.items() if not v]
if missing:
    sys.exit("[ios-ads] app-store.config.json adMob 절에 빠진 값: " + ", ".join(missing))

for key, value in wanted.items():
    print(f"export {key}={shlex.quote(value)}")
PY
)"

echo "[ios-ads] iOS 운영 AdMob ID 주입 (app ${ADMOB_IOS_APP_ID})"
ADMOB_TARGET_PLATFORM=iOS \
  python3 "${repo_root}/tools/configure_native_ads.py" --require-production

echo "[ios-ads] 완료"

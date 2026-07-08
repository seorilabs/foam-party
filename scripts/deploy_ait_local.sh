#!/usr/bin/env bash
# 로컬에서 폼 파티 AIT(.ait) 빌드 + AppsInToss 배포.
# 자격증명: ~/.config/seorilabs/apps-in-toss.env (APPS_IN_TOSS_API_KEY). 키는 출력/로그 금지.
# CI 경로(godot-deploy-ait.yml)와 동일한 순서: web export → sync → build:web → ait build → ait deploy.
#
# 사용:
#   scripts/deploy_ait_local.sh                 # export부터 배포까지 전체
#   SKIP_EXPORT=1 scripts/deploy_ait_local.sh   # 기존 build/web 재사용
#   MEMO="핫픽스" scripts/deploy_ait_local.sh    # 배포 메모 지정
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wrapper_dir="${repo_root}/ait/apps-in-toss-web"
env_file="${APPS_IN_TOSS_ENV_FILE:-${HOME}/.config/seorilabs/apps-in-toss.env}"

if [ ! -f "${env_file}" ]; then
  echo "[ait-deploy] 자격증명 파일 없음: ${env_file}" >&2
  echo "[ait-deploy] AppsInToss 개발자센터에서 API Key를 받아 APPS_IN_TOSS_API_KEY 로 저장하세요." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "${env_file}"

if [ -z "${APPS_IN_TOSS_API_KEY:-}" ]; then
  echo "[ait-deploy] ${env_file} 에 APPS_IN_TOSS_API_KEY 가 없습니다." >&2
  exit 1
fi

memo="${MEMO:-local $(git -C "${repo_root}" rev-parse --abbrev-ref HEAD)@$(git -C "${repo_root}" rev-parse --short HEAD)}"

if [ "${SKIP_EXPORT:-0}" != "1" ]; then
  echo "[ait-deploy] Godot Web export → build/web" >&2
  GODOT_WEB_OUTPUT_DIR=build/web "${repo_root}/scripts/export_godot_web.sh"
fi

cd "${wrapper_dir}"
[ -d node_modules ] || npm ci
echo "[ait-deploy] sync:godot" >&2
npm run sync:godot
echo "[ait-deploy] build:web" >&2
npm run build:web
echo "[ait-deploy] ait build" >&2
npm run build
echo "[ait-deploy] ait deploy (memo: ${memo})" >&2
npm run deploy -- --api-key "${APPS_IN_TOSS_API_KEY}" --memo "${memo}"
echo "[ait-deploy] 완료" >&2

#!/usr/bin/env bash
set -euo pipefail

# Godot Web export를 apps/ait/dist 로 산출한다.
# `ait build`(granite.config.ts의 web.commands.build)가 이 결과를 .ait로 패키징한다.
#
# foam-party는 Godot 프로젝트가 repo 루트가 아니라 godot/ 하위에 있으므로
# GODOT_PROJECT_DIR를 <repo>/godot 로 지정한다(lizard는 프로젝트가 루트라 <repo>였다).

ait_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(cd "${ait_dir}/../.." && pwd)"

# Godot 헤드리스 바이너리 + Web export 템플릿 확보(ensure_godot는 ~/.local/bin/godot 심볼릭 링크 생성).
bash "${repo_root}/scripts/ensure_godot.sh" --with-export-templates
export PATH="${HOME}/.local/bin:${PATH}"

# godot/ 프로젝트를 export하되 출력만 apps/ait/dist 로 돌린다(outdir=dist 와 일치).
GODOT_PROJECT_DIR="${repo_root}/godot" \
GODOT_WEB_OUTPUT_DIR="${ait_dir}/dist" \
GODOT_WEB_LOG_DIR="${ait_dir}/dist/.logs" \
  bash "${repo_root}/scripts/export_godot_web.sh"

echo "[ait] web export ready: ${ait_dir}/dist"

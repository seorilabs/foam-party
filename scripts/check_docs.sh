#!/usr/bin/env bash
set -euo pipefail

required_files=(
  "docs/README.md"
  "docs/01-planning/product-spec.md"
  "docs/02-decisions/0001-docs-as-source-of-truth.md"
  "docs/03-architecture/clean-architecture.md"
  "docs/analytics-events.md"
  "docs/05-markets/google-play.md"
  "docs/05-markets/app-store.md"
  "docs/05-markets/apps-in-toss.md"
  "docs/06-release/release-checklist.md"
  "docs/07-qa/test-strategy.md"
  "docs/08-ops/dependencies.md"
)

for file in "${required_files[@]}"; do
  if [ ! -f "${file}" ]; then
    echo "Missing docs source file: ${file}" >&2
    exit 1
  fi
done

analytics_contracts=(
  'title_screen_view'
  'level_load_start'
  'level_load_complete'
  'play_tap'
  'tutorial_step_view'
  'tutorial_complete'
  'app_info.version'
  'first_open → title_screen_view → level_load_complete → play_tap → level_start → tutorial_complete'
)

contains_literal() {
  local needle="$1"
  local file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg --fixed-strings --quiet -- "${needle}" "${file}"
  else
    grep --fixed-strings --quiet -- "${needle}" "${file}"
  fi
}

for contract in "${analytics_contracts[@]}"; do
  if ! contains_literal "${contract}" docs/analytics-events.md; then
    echo "Missing analytics docs contract: ${contract}" >&2
    exit 1
  fi
done

echo "Docs source-of-truth structure check passed."

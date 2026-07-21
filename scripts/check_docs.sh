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

python3 tools/check_analytics_docs_contract.py

if ! grep -Fq 'min(최고 콤보, 15)×2' docs/game-spec.md; then
  echo "Game spec must record the combo-15 completion reward curve." >&2
  exit 1
fi

if ! grep -Fq '기본 완료 약 3.3회분' docs/game-spec.md; then
  echo "Game spec must record the foam-bomb price target." >&2
  exit 1
fi

echo "Docs source-of-truth structure check passed."

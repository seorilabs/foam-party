# Dependencies

## Runtime

- Godot: 4.6.3 stable
- Node for repo checks: 24.x

## GitHub Actions

- `actions/checkout@v6`
- `actions/setup-node@v6`
- `actions/configure-pages@v6`
- `actions/upload-pages-artifact@v5`
- `actions/deploy-pages@v5`

GitHub Actions 버전을 바꿀 때는 GitHub 공식 release page/API를 source of truth로 확인한다.

## Local Tools

- Godot CLI: `godot`
- macOS App Store build path: `tools/build_ios_app_store.sh`
- App Store readiness: `tools/check_app_store_readiness.py`

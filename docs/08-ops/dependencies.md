# Dependencies

## Runtime

- Godot: 4.7.2 stable
- Node for repo checks: 24.x
- Poing AdMob: `5.1.0`
  - source: `https://github.com/poingstudios/godot-admob-plugin` (releases `poing-godot-admob-v5.1.0.zip`, `ios-template-v4.7.2.zip`, `android-template-v4.7.2.zip`)
  - vendored path: `godot/addons/admob` (네이티브 바이너리는 `android/bin`, `ios/bin`)
  - 네이티브 템플릿은 Godot 버전별로 배포된다. 엔진을 올리면 같은 버전의 템플릿으로 교체한다.
- godotx Firebase: `3.1.0`
  - source: `https://github.com/godot-x/firebase` (release asset `godotx_firebase.zip`)
  - vendored path: `godot/addons/godotx_firebase`, `godot/android/firebase_*`, `godot/ios/plugins/firebase_*`
  - Godot 4.7 이상 전용이다.
- Seorilabs Platform GDScript SDK: `0.6.3`
  - source: `https://github.com/seorilabs/platform/tree/main/sdk-gdscript`
  - vendored path: `godot/addons/seorilabs_platform`
  - `VERSION`과 `CHECKSUM`을 함께 고정한다.

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

# Dependencies

## Runtime

- Godot: 4.7.2 stable
- Node for repo checks: 24.x
- Poing AdMob: `5.1.0`
  - source: `https://github.com/poingstudios/godot-admob-plugin` (releases `poing-godot-admob-v5.1.0.zip`, `ios-template-v4.7.2.zip`, `android-template-v4.7.2.zip`)
  - vendored path: `godot/addons/admob` (네이티브 바이너리는 `android/bin`, `ios/bin`)
  - 네이티브 템플릿은 Godot 버전별로 배포된다. 엔진을 올리면 같은 버전의 템플릿으로 교체한다.
  - 플러그인이 `addons/admob/{ios,android}/.gitignore` 에 `/bin` 무시 줄을 넣어 둔다.
    이 저장소는 바이너리를 vendoring 하므로 그 줄을 지운 상태를 유지한다. 플러그인을
    다시 받으면 같은 조치가 필요하다.
- godotx Firebase: `3.1.0`
  - source: `https://github.com/godot-x/firebase` (release asset `godotx_firebase.zip`)
  - vendored path: `godot/addons/godotx_firebase`, `godot/android/firebase_*`, `godot/ios/plugins/firebase_*`
  - Godot 4.7 이상 전용이다.
- Seorilabs Platform GDScript SDK: `0.6.5`
  - source: `https://github.com/seorilabs/platform/tree/main/sdk-gdscript`
  - vendored path: `godot/addons/seorilabs_platform`
  - `VERSION`과 `CHECKSUM`을 함께 고정한다. `CHECKSUM`은 `scripts/check_platform_sdk.sh`와
    같은 방식(addon 안의 `*.gd`를 경로와 함께 해시)으로 재계산한다. 상류의 `tools/`는
    vendoring 하지 않고 checksum에서도 제외된다.
  - `core/presence_client.gd`는 RPI Edge heartbeat다. 기본 opt-in은 `false`이며
    활성화는 중앙 게이트(seorilabs/platform#78) 통과 후 별도 릴리스에서 한다.

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

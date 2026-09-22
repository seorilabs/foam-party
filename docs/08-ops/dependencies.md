# Dependencies

## Runtime

- Godot: 4.7.2 stable
- Node for repo checks: 24.x
- AppsInToss web framework: `3.5.0`
  - 설정 정본은 `ait/apps-in-toss-web/apps-in-toss.config.ts`다. 2.x의 `granite.config.ts`는
    `ait migrate v3`로 변환했다.
  - 3.x는 `webBundleDir`을 그대로 패킹한다. `ait build` 전에 웹 빌드가 끝나 있어야 하므로
    `build` 스크립트가 `build:web → ait build → check:no-google-api-key` 순이다.
  - `brand`에는 `primaryColor`만 남는다. 표기명은 `index.html`의 `<title>`이, 아이콘은 콘솔
    등록 이미지가 정본이다.
  - **3.x로 출시하면 2.x로 롤백할 수 없다.** 콘솔 QR로 확인한 뒤 출시한다.
  - Godot Web 로더 후처리는 `src/godotLoaderSanitizer.ts` 가 소유하고, 각 단계는 패치 후
    불변식으로 판정한다. 엔진을 올릴 때 로더 최소화 규칙이 바뀌면 sync 가 실패하도록 두고
    조용히 넘어가게 두지 않는다. 경위는 `godot-4.7-upgrade.md` 의 AIT 웹 로더 항목에 있다.
  - 3.x부터 CORS 허용 도메인이 `*.apps.tossmini.com`에서 `*.web.tossmini.com`으로 바뀐다.
    AIT에서 Platform API를 호출하게 되면 `seorilabs/platform` 레지스트리의 `cors_origins`를
    먼저 갱신해야 한다. 현재 AIT 경로는 Platform 인증을 쓰지 않는다.
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

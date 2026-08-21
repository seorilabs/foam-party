# Release Checklist

## Common

- [ ] `npm run test:core`
- [ ] `npm run check:architecture`
- [ ] `npm run test:godot`
- [ ] `npm run check:docs`
- [ ] `npm run check:native-ads`
- [ ] `npm run build:godot:web`
- [ ] `npm run check:release`
- [ ] Privacy/policy answers confirmed
- [ ] Release notes confirmed

## Firebase / Platform identity

- [x] `foam-party` Platform registry와 custom-token bridge 운영 반영
- [x] Firebase Auth 초기화 후 `signInWithCustomToken` 성공 확인
- [x] Android/iOS 실기기에서 Platform 세션과 재실행 UID 유지 확인
- [x] custom token·Firebase ID token 비영속화 로그/파일 확인

## Google Play

- [ ] Play Console `Account Details` 한국 법률 추가 정보 완료 및 403 해소
- [ ] AAB built on x64 Linux release path
- [ ] Signing confirmed
- [ ] Internal testing upload ready
- [ ] Data safety confirmed
- [x] Android production AdMob app ID와 `game_over`/`foam_bomb_free`/`level_reward_2x` unit ID 콘솔 형식 확인 및 `google-play` environment 등록
- [ ] release AAB 최종 산출물의 Android production AdMob ID 주입 확인
- [ ] 실제 Android 기기에서 load → impression → dismiss/earned 이벤트 확인
- [ ] 승인된 태그로 `google_play_track=production`, `google_play_release_status=completed` dispatch
- [ ] Android Publisher API 또는 Play Console에서 production versionName/versionCode/status readback

## App Store

- [ ] `npm run check:app-store`
- [x] Xcode/macOS build path confirmed - Xcode Cloud Release run 25
- [x] Signing/provisioning confirmed - App Store Connect build 25 VALID
- [ ] TestFlight notes ready
- [x] Privacy labels confirmed - User ID=App Functionality, linked=yes, tracking=no
- [x] iOS production AdMob app/unit ID 콘솔 형식 확인 및 Xcode Cloud `Release` workflow 등록
- [x] Xcode Cloud archive 최종 산출물의 iOS production AdMob ID 주입 확인 - v1.3.12 build 24 Archive/VALID
- [ ] ATT 비활성 + NPA 기본값 검토, EEA/UK용 UMP privacy message/동의 흐름 확정
- [ ] 실제 iPhone에서 load → impression → dismiss/earned 이벤트 확인
- [x] Screenshot set captured - version 1.3.16에 en-US iPhone 세트 승계

## AppsInToss

- [ ] Godot Web export ready
- [ ] Wrapper build ready
- [ ] `.ait` artifact generated
- [ ] Sandbox QA completed
- [ ] Registration images ready

## GitHub Pages

- [x] GitHub Pages source is Actions workflow
- [ ] `Deploy Godot Web Pages` succeeds on `main`
- [ ] Published URL smoke-tested

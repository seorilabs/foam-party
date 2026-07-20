# App Store Registration

폼 파티의 App Store Connect 등록 원본은 `app-store/app-store.config.json`이다. 이 문서는 콘솔 입력과 수동 gate를 추적하기 위한 요약이다.

## 앱 정보 후보

| 항목 | 값 | 상태 |
| --- | --- | --- |
| 앱 이름 | `Foam Party` | 확정 |
| SKU | `foam-party` | 후보 |
| Bundle ID | `com.seorilabs.foamparty` | 확정 필요 |
| Primary locale | `en-US` | 확정 |
| Availability | Worldwide | 확정 |
| Category | `Games` / `Casual` | 확정 필요 |
| Support email | `cs@seorilabs.com` | 기본값 |
| Support URL | `확정 필요` | App Review 필수 |
| Marketing URL | 선택 사항 | 미정 |
| DSA trader status | `확정 필요` | Worldwide/EU 배포 gate |

## 메타데이터 한도

- Promotional text: 170자 이하
- Description: 4000자 이하
- Keywords: 100자 이하

초기 등록은 `app-store/app-store.config.json`의 `en-US` 문구를 콘솔 입력 원본으로 사용한다. 한국어 문구는 후속 현지화 후보로만 보관한다.

## 출시 범위

- 초기 App Store 출시는 전세계 배포로 진행한다.
- 게임 규칙 이해에 긴 문장이 필요하지 않은 캐주얼 게임이므로 영어 메타데이터와 영어 UI 기준으로 스크린샷을 준비한다.
- 한국어 현지화는 출시 후 필요할 때 별도 localization으로 추가한다.
- 전세계 배포는 EU를 포함하므로 App Store Connect에서 DSA trader 여부와 표시 연락처 요구사항을 확인한다.

## 현재 바이너리 기준 질문지 후보

현재 소스는 Firebase Analytics와 Poing AdMob v4.3.1을 포함한다. IAP, 계정, 채팅, UGC, 외부 웹 접근, 도박, 랜덤박스, Game Center는 없다. 게임 진행 자체는 `user://foam_party_save.cfg` 로컬 파일에 저장하지만 분석/광고 SDK는 네트워크를 사용한다.

| 항목 | 후보 답변 | 근거 |
| --- | --- | --- |
| App Privacy | 재작성 필요 | AdMob 및 Firebase Analytics 도입 |
| Tracking / ATT | 아니오 후보 | ATT 비활성, iOS 광고 요청 `npa=1` 기본값 |
| Age Rating | 재확정 필요 | 광고 포함 답변을 다음 버전 설문에 반영 |
| Content Rights | 자체 에셋 + 외부 SDK | Poing plugin MIT, Google Mobile Ads/UMP 의존성 |
| Export Compliance | `ITSAppUsesNonExemptEncryption=false` 후보 | custom cryptography 없음 |

NPA 요청만으로 EEA/UK 동의 요건이 끝나지 않는다. App Store 다음 버전 제출 전 AdMob privacy message와 UMP 동의 흐름, production 광고 ID, 실제 iPhone QA를 확정한다.

## 필수 남은 항목

- App Store Connect app shell 생성
- Bundle ID/App ID 최종 확정
- `FOAM_PARTY_IOS_PROFILE_SPECIFIER`용 App Store provisioning profile 생성
- Support URL / Privacy Policy URL 확정
- App Privacy 입력
- Age Rating 설문 입력
- DSA trader status 입력
- Content Rights / Export Compliance 입력
- Review contact phone 입력
- iPhone 6.9-inch `en-US` screenshot 세트 캡처
- TestFlight 업로드, processing 확인, build selection
- 최종 Submit for Review

## 참고

- Apple screenshot specs: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Apple upload builds: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds
- Apple app privacy: https://developer.apple.com/app-store/app-privacy-details/
- Apple export compliance: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance

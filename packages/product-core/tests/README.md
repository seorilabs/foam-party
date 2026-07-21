# Product Core Tests

`packages/product-core`로 추출한 순수 규칙 테스트를 둔다.

`godot/tests/core_test.gd`가 `godot/core` 심볼릭 링크를 통해 순수 도메인·유스케이스 규칙을 실제 실행한다. `npm run test:core`는 scaffold와 import 경계를 확인한 뒤 이 실행형 테스트를 수행한다.

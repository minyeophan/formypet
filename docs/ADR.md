# Architecture Decision Records

## 철학
MVP 속도 최우선. 로컬 데이터만으로 동작하는 완전한 프론트엔드 MVP 먼저. 외부 의존성 최소화. Expo managed workflow에서 벗어나지 않는다.

---

### ADR-001: React Native + Expo (managed workflow)
**결정**: Flutter/네이티브 대신 React Native + Expo managed workflow 선택
**이유**: 팀이 React 경험 보유. Expo Go로 물리 기기 즉시 테스트 가능. managed workflow는 Xcode/Android Studio 없이 개발 가능.
**트레이드오프**: 네이티브 모듈 직접 추가 불가 (bare workflow 전환 필요). 성능은 Flutter보다 낮을 수 있음.

### ADR-002: Expo Router v3 (파일 기반 라우팅)
**결정**: React Navigation 대신 Expo Router v3 선택
**이유**: 파일 시스템 = 라우트 구조. `(tabs)` 그룹으로 탭 네비게이션 자동 설정. 웹 개발 경험 재사용 가능.
**트레이드오프**: Expo Router는 React Navigation 위에 빌드되어 있어 고급 커스텀은 더 복잡. 에러 메시지가 추상화되어 디버깅 어려울 수 있음.

### ADR-003: NativeWind v4
**결정**: React Native StyleSheet / styled-components 대신 NativeWind v4 선택
**이유**: 기존 웹 Tailwind 클래스 지식 재사용. 빠른 프로토타이핑. className 기반으로 가독성 좋음.
**트레이드오프**: metro.config.js + nativewind-env.d.ts 등 초기 설정 필요. 일부 Tailwind 클래스는 RN에서 미지원.

### ADR-004: @gorhom/bottom-sheet
**결정**: RN Modal / react-native-modalize 대신 @gorhom/bottom-sheet 선택
**이유**: 네이티브 제스처 기반 (react-native-gesture-handler). 부드러운 스냅 포인트 애니메이션. 탭 바 위에 레이어링 가능.
**트레이드오프**: react-native-reanimated + react-native-gesture-handler peer deps 필수. babel.config.js 플러그인 필요.

### ADR-005: AsyncStorage (로컬 전용)
**결정**: SQLite / MMKV / 백엔드 API 대신 AsyncStorage 선택
**이유**: MVP는 로컬 데이터만으로 충분. 설치/설정이 가장 단순. 향후 백엔드 연동 시 마이그레이션 쉬움.
**트레이드오프**: 비동기 — 초기 로딩 타이밍 관리 필요 (isLoading 패턴). 대용량 데이터에 부적합 (MVP는 무관).

### ADR-006: react-hook-form + Controller 패턴
**결정**: Formik / 직접 useState 대신 react-hook-form 선택
**이유**: React Native TextInput은 ref 기반 `register()`가 불가 — Controller 패턴 필수. 성능 최적화 (비제어 컴포넌트).
**트레이드오프**: `<Controller>` 보일러플레이트가 웹보다 많음. Zod 없이 기본 validation만 사용 (MVP).

### ADR-007: react-native-gifted-charts
**결정**: Victory Native / react-native-chart-kit 대신 react-native-gifted-charts 선택
**이유**: react-native-svg 기반으로 managed workflow 완전 호환. `xAxisLabelTexts` prop으로 날짜 포맷 커스텀 가능. API가 단순.
**트레이드오프**: react-native-svg peer dep 필요. 그라디언트 채우기는 react-native-linear-gradient 필요하나 MVP에서는 사용 안 함.

### ADR-008: 단일 PetContext (전역 상태)
**결정**: Redux / Zustand / 여러 Context 대신 단일 React Context 선택
**이유**: MVP 규모 (pets + records + modal 상태)에 Context로 충분. 외부 라이브러리 의존성 없음. 단순한 트리 구조.
**트레이드오프**: 컨텍스트 값 변경 시 전체 소비자 리렌더. 앱이 커지면 Zustand 등으로 마이그레이션 필요.

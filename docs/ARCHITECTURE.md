# 아키텍처

## 디렉토리 구조
```
app/                         # Expo Router 파일 기반 라우팅
├── _layout.tsx              # 루트 레이아웃 (PetProvider, GestureHandler, 폰트, SplashScreen)
├── onboarding.tsx           # 온보딩 화면 (첫 실행 시)
├── records.tsx              # 기록 화면
├── routine.tsx              # 루틴 화면
├── growth.tsx               # 성장 기록 화면
├── record-edit/[id].tsx     # 기록 수정 화면
├── pet/[id].tsx             # 펫 상세 화면
├── pet/[id]/edit.tsx        # 펫 수정 화면
└── (tabs)/
    ├── _layout.tsx          # 탭 레이아웃 + RecordModal (탭 바 위에 렌더)
    ├── index.tsx            # 홈 탭
    ├── community.tsx        # 커뮤니티 탭
    └── my.tsx               # 마이 탭

src/
├── types/index.ts           # TypeScript 타입 정의 (Pet, ActivityRecord, Post)
├── lib/
│   ├── colors.ts            # 색상 상수 + PET_COLORS 쌍 (accent + bgLight)
│   ├── record-types.ts      # QUICK_TYPES (활동 유형) + SPECIES_EMOJI
│   ├── auth-context.tsx     # JWT 인증 상태와 사용자 프로필 상태
│   ├── utils.ts             # date-fns 헬퍼 (D+day, 달력, 날짜 포맷)
│   └── pet-context.tsx      # PetContext (전역 상태 + 백엔드 API 연동)
├── services/
│   ├── api.ts               # /api/v1 클라이언트와 JWT 저장
│   └── records.ts           # 기록 필터/집계 로직 (getWeightHistory 등)
└── components/
    ├── shared/
    │   ├── AppText.tsx       # Noto Sans KR 폰트 래퍼
    │   └── RecordModal.tsx   # 기록 추가 바텀 시트 (2단계: 유형선택 → 입력)
    ├── onboarding/
    │   └── PetRegisterForm.tsx
    ├── home/
    │   ├── PetSelector.tsx   # 상단 펫 전환 (FlatList horizontal)
    │   ├── HeroCard.tsx      # 펫 정보 카드 (expo-linear-gradient)
    │   ├── AlertBanner.tsx   # 주의 알림
    │   ├── QuickRecord.tsx   # 빠른 기록 버튼
    │   ├── ActivityCalendar.tsx
    │   └── RecentRecords.tsx
    ├── records/
    │   ├── RecordList.tsx    # SectionList (날짜 그룹)
    │   ├── ActivityTab.tsx
    │   ├── HealthTab.tsx
    │   └── GrowthTab.tsx     # react-native-gifted-charts
    ├── community/
    │   └── PostCard.tsx
    └── my/
        └── PetList.tsx
```

## 패턴
- **Expo Router 파일 기반**: 디렉토리 구조 = 라우트 구조. `(tabs)` 그룹 = 탭 네비게이션.
- **모든 화면은 Client Component**: React Native에는 Server Component 개념 없음.
- **AppText 강제 사용**: 모든 텍스트는 `<AppText>`로 — Noto Sans KR 폰트 일관성 보장.
- **FlatList/SectionList**: 스크롤 가능한 리스트는 반드시 FlatList 또는 SectionList 사용 (ScrollView + map() 금지 — 성능).

## 데이터 흐름
```
사용자 액션 (Pressable)
    → PetContext/AuthContext 함수 호출
      → /api/v1 백엔드 API 요청
        → 상태 업데이트
          → 전체 소비자 리렌더
```

앱 시작 흐름:
```
SplashScreen.preventAutoHideAsync() [모듈 레벨]
  → AuthProvider/PetProvider useEffect: 저장된 토큰과 서버 데이터 로드
    → isLoading = false
      → useFonts 완료
        → SplashScreen.hideAsync()
          → hasOnboarded 확인 → 온보딩 or 홈
```

## 상태 관리
- **AuthContext**: 인증 토큰, 사용자 정보, 프로필 상태
- **PetContext**: pets, activePetId, records, routines, modalOpen, selectedType, isLoading, hasOnboarded
- **로컬 UI 상태**: 탭 선택, 폼 입력값 등은 useState로 컴포넌트 내부 관리
- **AsyncStorage**: 토큰과 최소한의 클라이언트 상태 유지

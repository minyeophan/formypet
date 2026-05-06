# 아키텍처

## 디렉토리 구조
```
app/                         # Expo Router 파일 기반 라우팅
├── _layout.tsx              # 루트 레이아웃 (PetProvider, GestureHandler, 폰트, SplashScreen)
├── onboarding.tsx           # 온보딩 화면 (첫 실행 시)
└── (tabs)/
    ├── _layout.tsx          # 탭 레이아웃 + RecordModal (탭 바 위에 렌더)
    ├── index.tsx            # 홈 탭
    ├── records.tsx          # 기록 탭
    ├── community.tsx        # 커뮤니티 탭
    └── my.tsx               # 마이 탭

src/
├── types/index.ts           # TypeScript 타입 정의 (Pet, ActivityRecord, Post)
├── lib/
│   ├── colors.ts            # 색상 상수 + PET_COLORS 쌍 (accent + bgLight)
│   ├── record-types.ts      # QUICK_TYPES (활동 유형) + SPECIES_EMOJI
│   ├── mock-data.ts         # MOCK_PETS, MOCK_RECORDS, MOCK_POSTS
│   ├── utils.ts             # date-fns 헬퍼 (D+day, 달력, 날짜 포맷)
│   └── pet-context.tsx      # PetContext (전역 상태 + AsyncStorage)
├── services/
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
    │   ├── PostCard.tsx
    │   └── PostFeed.tsx      # FlatList
    └── my/
        ├── PetList.tsx
        └── AddPetForm.tsx    # @gorhom/bottom-sheet
```

## 패턴
- **Expo Router 파일 기반**: 디렉토리 구조 = 라우트 구조. `(tabs)` 그룹 = 탭 네비게이션.
- **모든 화면은 Client Component**: React Native에는 Server Component 개념 없음.
- **AppText 강제 사용**: 모든 텍스트는 `<AppText>`로 — Noto Sans KR 폰트 일관성 보장.
- **FlatList/SectionList**: 스크롤 가능한 리스트는 반드시 FlatList 또는 SectionList 사용 (ScrollView + map() 금지 — 성능).

## 데이터 흐름
```
사용자 액션 (Pressable)
  → PetContext 함수 호출 (addRecord, openModal 등)
    → 상태 업데이트 (useState)
      → AsyncStorage.setItem() 동기 저장
        → 전체 소비자 리렌더
```

앱 시작 흐름:
```
SplashScreen.preventAutoHideAsync() [모듈 레벨]
  → PetProvider useEffect: AsyncStorage.getItem (pets, records, hasOnboarded)
    → isLoading = false
      → useFonts 완료
        → SplashScreen.hideAsync()
          → hasOnboarded 확인 → 온보딩 or 홈
```

## 상태 관리
- **PetContext** (단일 전역): pets, activePetId, records, modalOpen, selectedType, isLoading, hasOnboarded
- **로컬 UI 상태**: 탭 선택, 폼 입력값 등은 useState로 컴포넌트 내부 관리
- **AsyncStorage**: 앱 재시작 후 데이터 유지 — pets, records, hasOnboarded 키로 저장

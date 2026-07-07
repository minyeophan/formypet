# 현재 컨텍스트

## 2026-07-06 LoadedMedia contentType null 계약

- main 진단 감사의 최우선 후보였던 `LoadedMedia.contentType` record component에 Spring `@NonNull`을 적용하고 `LocalMediaStorage.load()`가 null content type을 파일 접근 전에 `IllegalArgumentException`으로 거부하도록 했다.
- null 입력이 기존에는 `NoSuchFileException`까지 진행되는 RED를 확인한 뒤 guard 적용으로 GREEN을 확인했다. storage·media·profile 선택 테스트와 backend 전체 compile/test가 통과했다.
- Java Problems는 336개(main 29, test 307)에서 최종 안정 snapshot 2회 333개(main 26, test 307)로 감소했다. controller 경고 3개만 제거됐고 신규 진단과 storage·constructor·test로의 경고 이동은 없다.
- 감사와 파일럿 산출물은 `C:\tmp\paa-java-main-diagnostics-audit-b1e6857-20260706-164131`, 분류 보고서는 `docs/superpowers/specs/2026-07-06-java-main-diagnostics-audit.md`에 있다.

## 2026-07-06 main Java 진단 29개 정밀 감사

- commit `b1e6857`의 fresh Problems는 Workspace·Java 336개(main 29, test 307)이며 이전 안정 snapshot과 완전히 일치했다. 필수 JSON 필드 누락과 중복·누락 진단은 없다.
- main 29개를 BLOCKER 0, ACTIONABLE 0, CONTRACT_CANDIDATE 8, EXTERNAL_BOUNDARY 21, UNKNOWN 0으로 분류했다. 외부 경계는 JDK·Spring·JDBC generic 또는 null annotation 차이이며 cast·suppression·`Objects.requireNonNull`로 보정하지 않는다.
- 다음 우선 후보는 DB `content_type NOT NULL`과 storage load 경로로 근거가 명확한 `LoadedMedia.contentType` 계약이다. controller 3곳의 String 경계를 단일 record annotation으로 개선할 수 있는지 별도 snapshot으로 검증한다.
- production·test 코드는 수정하지 않았고 감사 보고서는 `docs/superpowers/specs/2026-07-06-java-main-diagnostics-audit.md`, 원본 산출물은 `C:\tmp\paa-java-main-diagnostics-audit-b1e6857-20260706-164131`에 있다.

## 2026-07-06 auth.domain factory 반환 null 계약

- `User.create()`·`createOAuth()`, `RefreshToken.create()`, `OAuthAccount.create()` 반환에만 Spring `@NonNull`을 적용했다. JPA ID와 `profileMediaId`의 실제 nullable 상태를 보존하기 위해 package `@NonNullApi`와 field·parameter 계약은 추가하지 않았다.
- fresh baseline은 Java 340개(main 33, test 307), 최종 안정 snapshot 2회는 336개(main 29, test 307)로 일치했다. `AuthService`와 `OAuthSignupService`의 factory 반환 경고 4개가 제거됐고 신규 진단은 없다.
- 변경 전 `AuthIntegrationTest`, Java compile, 변경 후 `AuthIntegrationTest`와 backend 전체 테스트가 모두 통과했다. suppression, cast, `Objects.requireNonNull`, JDT 설정과 dependency는 변경하지 않았다.
- 감사 산출물은 `C:\tmp\paa-auth-domain-factory-null-23f9123-20260706-161649`에 있다.

## 2026-07-06 auth.client Spring null annotation 재적용

- `com.petyilgi.auth.client`에 Spring `@NonNullApi`를 적용하고 `KakaoUserInfo.email`·`nickname`, `RestClientKakaoUserClient`의 실제 nullable 입출력 경계만 `@Nullable`로 선언했다. test package, 다른 main package, dependency와 JDT 설정은 변경하지 않았다.
- fresh baseline은 Java 338개(main 32, test 306), 최종 안정 snapshot 2회는 340개(main 33, test 307)로 일치했다. 신규 3개와 제거 1개는 모두 `16778128` NON_BLOCKING 경계 진단이며, `OAuthSignupService` 잠재 NPE 2개는 재발하지 않았다.
- 신규 진단은 `AuthService`의 access token 전달, `RestClientKakaoUserClient`의 빈 map 반환, `AuthIntegrationTest`의 JSON content 전달 경계에서 각각 1개다. 기존 request factory 경고 1개는 제거됐다. suppression, cast와 `Objects.requireNonNull`은 추가하지 않았다.
- 변경 전 선택 테스트, Java compile, 변경 후 선택 테스트와 backend 전체 테스트가 모두 통과했다. 감사 산출물은 `C:\tmp\paa-auth-client-null-annotations-8dea4a8-20260706-154846`에 있다.

## 2026-07-06 OAuth nullable 소비자 정리

- `OAuthSignupService`가 nullable인 Kakao email·nickname accessor를 조건식에서 반복 호출하지 않고 지역 변수에 한 번만 저장하도록 정리했다. verified, null, blank, 기존 email 중복 검사 순서와 내부 email·기본 nickname fallback은 유지했다.
- `AuthIntegrationTest`에서 정상 nickname 보존, verified null profile, non-null unverified email, blank profile, 기존 email 중복 동작을 고정했다. 새 시나리오의 반복 MockMvc 설정은 공용 helper로 모아 JDT NON_BLOCKING 진단이 증가하지 않게 했다.
- fresh baseline과 최종 안정 snapshot 2회는 모두 Java 338개(main 32, test 306)였고 path·code·severity·message multiset 차이와 신규 ACTIONABLE·BLOCKER는 없다.
- 변경 전·characterization 보강 후·production 변경 후 선택 테스트와 최종 `compileJava compileTestJava test --rerun-tasks --warning-mode all`이 모두 통과했다. 감사 산출물은 `C:\tmp\paa-oauth-nullable-consumer-a84e62c-20260706-152121`에 있다.

## 2026-07-06 Spring 6.2 null annotation 파일럿

- 최신 `develop`의 Java Problems baseline은 341개(main 35, test 306)였다. `JwtAuthFilter`의 `jakarta.annotation.Nonnull`을 Spring `@NonNull`로 교체한 결과 override 경고 3개가 제거됐고, 안정화 snapshot 2회가 338개(main 32, test 306)로 일치했다. 신규 ACTIONABLE·BLOCKER는 없다.
- `com.petyilgi.auth.client`에 `@NonNullApi`와 실제 nullable 경계를 적용한 중간 파일럿은 안정화 snapshot에서 343개로 증가했다. `KakaoUserInfo.email()`·`nickname()`의 nullable 계약이 `OAuthSignupService`의 반복 accessor 호출에서 잠재 NPE 2개를 새로 드러냈으므로 롤백 기준에 따라 package 적용을 원복했다.
- package 단위 null 계약 확대는 중단했다. 후속 작업에서는 `OAuthSignupService` 소비자 코드를 별도 PR로 정리한 뒤 `auth.client` 파일럿을 다시 검토한다. suppression, JDT 설정, dependency, test package는 변경하지 않았다.
- 변경 전후 auth 선택 테스트와 최종 `compileJava compileTestJava test --rerun-tasks --warning-mode all`이 모두 `BUILD SUCCESSFUL`이었다. 감사 산출물은 `C:\tmp\paa-spring-null-pilot-5d7d884-20260706-103928`에 있다.

## 2026-07-06 Java ACTIONABLE 진단 정리

- fresh Problems 기준선은 Workspace 347개, Backend Java 347개(main 38, test 309), ACTIONABLE 6개, BLOCKER 0개였다. `CommunityService.createComment()` 경고는 null request가 기존 content 검증에서 먼저 거부되어 실제 NPE가 발생하는 버그가 아니라 JDT의 제어 흐름 추론 한계였다.
- direct service null request characterization test를 production 변경 전에 추가해 기존 `IllegalArgumentException`과 오류 문구를 고정했다. 이후 `createComment()`의 null 검증만 별도 분기하고, `WalletExpenseService`의 미사용 import·private method와 `MediaIntegrationTest`의 미사용 import를 제거했다.
- Java indexing 완료 후 after-2와 after-3 snapshot은 341개(main 35, test 306), ACTIONABLE 0개, BLOCKER 0개로 동일했다. 위치를 제외한 multiset 비교에서도 기존 ACTIONABLE 6개가 사라진 것 외에 신규 진단은 없었다.
- Community characterization test는 구현 전후 통과했고 Community·Wallet·Media 선택 테스트와 최종 `compileJava compileTestJava test --rerun-tasks --warning-mode all`이 `BUILD SUCCESSFUL`로 종료했다. 감사 산출물은 `C:\tmp\paa-java-actionable-fix-fa6e3c4-20260706-100236`에 있다.

## 2026-07-05 Community 개발용 mock 제거

- 개발 전용 `/community/mock`, `/community/mock/posts/:postId` 라우트와 인증·온보딩 우회 조건을 제거했다. 삭제된 URL에는 호환 리다이렉트나 별도 오류 화면 계약을 추가하지 않았다.
- `frontend/lib/screens/community/mock/` 구현 5개와 전용 widget 테스트를 삭제하고, router 테스트에서 mock 공개 경로 검증만 제거했다. 실제 Community 목록·상세·댓글·글쓰기 라우트와 인증 계약은 유지한다.
- `docs/SCREEN_V2_STATUS.md`에서 mock 화면 2개를 제외해 Community 화면은 5개, 전체 화면은 39개로 갱신했다. `/community`와 카테고리 화면은 Chrome 수동 검증 전이므로 `[X]`를 유지한다.
- 변경 후 router·Community 목록·상세 선택 테스트 85개와 Flutter 전체 테스트 354개가 통과했고, `flutter analyze`는 `No issues found!`로 종료했다.

## 2026-07-04 커뮤니티 게시글 상세 모바일 V2 구현

- `/community/posts/:postId`를 Plus Jakarta Sans, V2 배경·색상·divider, 60px header, 최대 672px 본문, 댓글 launcher 구조로 전환했다. 상세 screen은 게시글·댓글 요청과 오류·mutation 잠금을 담당하고 `community_detail_widgets.dart`가 article·이미지 pager·투표·통계·댓글 preview를 담당한다.
- 댓글 preview는 root 3개·reply 2개 요청/중복 제거 제한을 사용한다. 이미지 4:3 pager, 투표 pending 보존, 좋아요·댓글 통계, flat 댓글 row, keyboard focus 2px outline을 반영했다. 댓글 전용 route와 Backend 계약은 변경하지 않았다.
- 검증: Flutter 전체 367개 테스트 GREEN, `flutter analyze` No issues, Backend `CommunityIntegrationTest --rerun-tasks` GREEN, 한글 깨짐 검사·외부 HTML URL 검색·`git diff --check` GREEN. Chrome 수동 검증은 미실행이므로 `docs/SCREEN_V2_STATUS.md`의 상세 route는 `[X]`를 유지한다.

## 2026-07-03 커뮤니티 홈·카테고리 HTML V2 재구현

- Home과 동일한 `AppV2Tokens.background(#F9F9FF)`를 Community 홈·카테고리 Scaffold, bespoke header, feed와 상태 영역에 적용했다. 카테고리 header는 공용 `AppBackButton`을 사용하고 direct URL에서는 `/community`로 복귀한다.
- 홈은 12개 카테고리의 5열·2행 2페이지 grid를 유지하면서 외곽 surface panel을 제거했다. 카테고리는 route 기반 12개 가로 chip, 활성 chip button/selected semantics와 자동 노출, route 변경 시 재접힘되는 4개 항목 guide를 사용한다.
- 공용 `PostCard`는 Card/elevation/margin 없는 flat row로 변경했다. 좌우 20px·상하 16px padding, 하단 V2 divider, 20px 2줄 제목, 선택적 80px thumbnail, 32px avatar, 분리된 좋아요 동작과 focus outline을 사용하며 본문 preview는 생성하지 않는다. skeleton은 image/text/image 패턴이다.
- 최신 자동 검증: Flutter 전체 361개 테스트 GREEN, `flutter analyze` No issues, Backend `CommunityIntegrationTest --rerun-tasks` GREEN. in-app browser 제어 도구가 노출되지 않아 Chrome 수동 검증은 남아 있으며, 이 때문에 `SCREEN_V2_STATUS` 완료 표시는 보류했다.

## 2026-07-02 커뮤니티 카테고리 V2·제목 계약

- 새 게시글 제목은 Backend와 Flutter 모두 최대 30자로 제한한다. DB `VARCHAR(120)`과 기존 긴 제목 데이터는 유지한다.
- 메인·카테고리 공용 `PostCard`는 제목만 최대 2줄로 표시하며, 빈 제목은 `제목 없음`을 사용한다. 본문은 상세·검색에서 유지한다.
- `/community/category/:category`는 route feed key를 렌더링 기준으로 사용한다. 12개 가로 chip, route 교체, 활성 chip 자동 노출, 접이식 이용 가이드, 단일 sliver scroll과 feed별 상태·pagination을 사용한다.
- 잘못된 category direct URL은 provider/API 호출 없이 `/community`로 redirect한다.
- 당시 검증: Backend 전체 테스트 GREEN, Flutter 전체 360개 GREEN, Community·Router·Home 선택 테스트 110개 GREEN, `flutter analyze` No issues.

## 2026-07-02 커뮤니티 메인 V2 구현

- `/community`를 고정 헤더와 최대 672px 본문, 카테고리 5열 2행 PageView 2페이지, 페이지 표시점, 단일 세로 `CustomScrollView`, 공용 V2 게시글 카드 구조로 전환했다. 검색과 알림은 기존 `준비중` 안내를 유지하며 상세·댓글·글쓰기·라우터·`MainScaffold` 계약은 변경하지 않았다.
- 카테고리 첫 페이지는 전체·인기·케어·사료/간식·산책·자랑·질문·자유·입양·구조, 두 번째 페이지는 뉴스·이벤트를 앞쪽에 표시한다. Flutter Web에서도 마우스 drag가 동작하도록 이 PageView 범위에 mouse·touch·stylus·trackpad 입력을 허용하고 회귀 테스트를 추가했다.
- 피드 상태는 initial·refresh·loadMore 요청을 feed key별로 분리하고, 오류도 해당 feed와 요청 종류별로 보존한다. 세로 최상위 스크롤이 하단에 접근했을 때만 pagination을 실행하며 loadMore 결과는 게시글 ID 기준으로 중복 제거한다.
- 게시글 카드는 category·투표 badge, 상대 시간, 제목·본문 fallback, 96px 썸네일, 32px 작성자 avatar와 `communityPaw` fallback, 좋아요·댓글 통계를 표시한다. 좋아요는 게시글별 중복 요청을 막고 처리 중 접근성 상태와 실패 안내를 제공한다.
- 공통 색상·gutter·Plus Jakarta Sans 값을 `AppV2Tokens`로 분리하고 `HomeV2Tokens`는 Home 고유 radius·sectionGap을 유지한 채 공통 값만 위임한다. `docs/SCREEN_V2_STATUS.md`에서는 `/community`만 `[O]`로 갱신했다.
- 검증: 전체 Flutter 테스트 357건 GREEN, Community widget/provider 선택 테스트 28건 GREEN, 마우스 drag 재현 테스트 RED→GREEN, 전체 Dart analyze `No issues found!`, 한글 깨짐 검사와 `git diff --check` GREEN. 백엔드 코드는 변경하지 않았으며 `CommunityIntegrationTest`는 격리 worktree의 Gradle 배포본 다운로드가 샌드박스 네트워크에 차단되어 재실행하지 못했다. Chrome 320·360·412px 수동 비교는 미실행이다.

## 2026-07-01 화면 V2 전환 현황 문서

- `docs/SCREEN_V2_STATUS.md`에 라우터 기준 41개 사용자 화면의 V2 상태를 정리했다. Home V2만 `[O]`, 나머지 40개 화면은 `[X]`로 시작한다.
- 공통 V2 기반 후 커뮤니티, My·펫, 기록, 루틴, 지갑, 정보성 화면 순서로 진행하도록 Phase를 정했다.
- 로딩·오류·빈 상태·새로고침·입력·수정·삭제·확인 경고·뒤로가기·접근성 검증을 `C01`~`C33` 공통 체크로 분리해 디자인 변경 시 한곳에서 갱신할 수 있게 했다.
- 이번 작업은 문서만 변경했으며 애플리케이션 코드, 마이그레이션, 테스트, `DESIGN.md`는 수정하지 않았다.

## 2026-07-01 Home V2 구현

- Home을 고정 `ForMyPet` 헤더, 반려동물 프로필 pager, 빠른 메뉴, 정적 뉴스 3개, 실제 인기글 3개, 하단 배너 순서로 재구성했다. 기존 오늘 관리·오늘 타임라인·최근 건강 상태 UI는 제거했으며 기존 라우트와 `MainScaffold` 하단 내비게이션 계약은 유지한다.
- 홈 인기글은 별도 auto-dispose provider가 `popular`, `limit: 3`으로 조회한다. 초기 로딩·빈 결과·초기 오류/재시도·데이터 보존 새로고침 오류를 분리하고 중복 요청을 하나의 Future로 합친다.
- `PetNotifier.refreshPets()`를 추가했다. 기존 active pet 유지, 삭제된 active pet 교체 시 상세 데이터 원자 적용, 상세 실패 시 이전 pet 데이터 제거, 빈 목록 온보딩 복귀, 중복 요청 차단과 늦은 상세 응답 방어를 적용했다.
- Plus Jakarta Sans variable TTF와 OFL을 로컬 asset으로 포함했다. 뉴스와 배너는 AppVisual 의미 ID의 Material/emoji fallback만 사용하며 외부 이미지 요청은 없다. `ui-reference/`는 Git ignore 대상이다.
- 검증: Flutter 관련 선택 테스트 84건과 전체 `flutter test` 348건 GREEN, 전체 `dart analyze` `No issues found!`, 백엔드 `CommunityIntegrationTest --rerun-tasks` Exit 0, 한글 깨짐 검사와 `git diff --check` GREEN. Home 위젯 테스트는 320·360·412px viewport overflow를 확인했다. 이 세션에는 브라우저 자동화 실행 도구가 노출되지 않아 실제 스크린샷 비교는 수행하지 못했다.

## 2026-06-30 CORS·로그아웃 안정화와 커뮤니티 검색 통합 검증

- 로컬 개발 origin의 CORS preflight에 `PATCH`를 허용하고 사용자 프로필 및 루틴 완료 API 경로를 통합 테스트로 고정했다.
- `PetNotifier.clearForSignedOutUser()`가 quick type 환경설정 로드를 기다리지 않고 즉시 signed-out 상태를 정리하도록 바꿨다. 환경설정 로드 실패는 기본 상태를 유지하며, 지연 중이거나 실패해도 로그아웃을 막지 않는다.
- 커뮤니티 게시글 검색 백엔드와 pagination 보완을 `develop`에 통합하고, Flutter `CommunityService.getFeed()`가 trim한 선택 `keyword`를 기존 category·sort·cursor·limit와 함께 전달하도록 연결했다. null·빈 문자열·공백 keyword는 요청에서 생략한다.
- 최종 검증: 백엔드 `.\gradlew.bat test --rerun-tasks` `BUILD SUCCESSFUL`, Flutter `flutter test` GREEN(339 tests), `flutter analyze` `No issues found!`, 한글 깨짐 검사와 `git diff --check` GREEN.

## 2026-06-29 커뮤니티 게시글 검색 및 pagination 보완

- `GET /api/v1/posts`에 선택 `keyword`를 추가했다. 검색어는 trim 후 Unicode code point 기준 2~20자이며 제목 또는 본문에 포함되는 글을 조회하고, category와 AND로 조합한다.
- `!`, `%`, `_`를 MySQL `LIKE ... ESCAPE '!'` 규칙에 맞게 escape하고 제목·본문 pattern을 prepared parameter로 전달한다. 빈 검색어는 기존 피드로 처리하며 잘못된 길이는 `INVALID_INPUT` 400을 반환한다.
- latest와 popular 피드는 `limit + 1`개를 조회해 실제 다음 행이 있을 때만 마지막 반환 항목 기준 cursor를 발급한다. keyword, category, sort가 바뀌면 클라이언트가 기존 cursor를 폐기해야 한다.
- 검증 상태: `CommunityIntegrationTest` GREEN. 당시 wallet summary SQL 실패는 `a725638`에서 수정됐고, 2026-06-30 통합 후 백엔드 전체 테스트도 GREEN이다.

## 2026-06-27 커뮤니티 댓글·답글 최종 검증

- `V19__add_post_comment_replies.sql`로 `post_comments.parent_comment_id`, self FK `ON DELETE CASCADE`, thread cursor 인덱스를 추가했다. root 댓글과 한 단계 답글만 허용하며 다른 게시글 parent, 존재하지 않는 parent, 답글을 parent로 지정하는 요청을 구분해 거부한다.
- 댓글 목록은 root cursor와 root별 최신 답글을 함께 반환하고, thread 단건 조회와 이전 답글 cursor 조회 API를 제공한다. 게시글·댓글 작성자 프로필 이미지 URL과 전체 댓글·답글 합산 `commentsCount`를 반환한다.
- Flutter는 thread 보기와 답글 작성 route query를 분리하고, target 조회 중 작성 차단, root/reply 병합, root별 답글 추가 조회, 상세 답글 3개 preview와 남은 개수 표시를 지원한다.
- 최종 검증: `flutter test` GREEN(326 tests), `flutter analyze` `No issues found!`, `CommunityIntegrationTest`와 `FlywayMigrationTest` `--rerun-tasks` GREEN, 한글 깨짐 검사와 `git diff --check` GREEN.

## 2026-06-25 커뮤니티 상세·댓글·투표 참여 연동

- 커뮤니티 피드 카드는 제목 1줄, 본문 2줄 preview로 정리했고, 첫 첨부 이미지를 오른쪽 썸네일로 표시한다. 이미지가 2장 이상이면 썸네일 위에 전체 개수를 표시하며, 투표 글은 제목 왼쪽에 작은 `투표` badge를 표시한다. 카드 열기와 좋아요 tap 영역은 분리했다.
- 실제 상세 route `/community/posts/:postId`를 인증 ShellRoute 안에 추가했다. 상세 화면은 전체 제목·본문·이미지·좋아요·투표·댓글을 한 화면에서 표시하고, direct URL 진입 시 뒤로갈 수 없으면 `/community`로 돌아간다.
- 백엔드는 게시글 상세 조회, 댓글 cursor 목록 조회, 댓글 작성 API를 추가했다. `post_comments` 테이블은 새 `V17__create_post_comments.sql`로 추가했고, 댓글 작성과 `posts.comments_count` 증가는 하나의 트랜잭션으로 처리한다. 없는 게시글은 상세·댓글 API 모두 `POST_NOT_FOUND` 404를 반환한다.
- Flutter `CommunityService`와 `CommunityProvider`에 상세 조회, 투표 참여, 댓글 목록, 댓글 작성을 연결했다. 좋아요·투표·댓글 작성 결과는 피드 목록과 상세 캐시에 함께 반영하며, 댓글 수는 댓글 작성 응답의 서버 `commentsCount`를 사용한다. 투표 option 파서는 백엔드의 `label` 필드도 읽는다.
- 검증 상태: `.\gradlew.bat test --tests com.petyilgi.community.CommunityIntegrationTest` GREEN. Flutter 선택 검증은 `flutter test test\models\post_test.dart test\services\community_service_test.dart test\screens\community\community_screen_test.dart test\router\app_router_test.dart` GREEN(66 tests), 선택 파일 `dart analyze` Exit 0(info 2건), `git diff --check` whitespace 오류 없음, 한글 깨짐 검사 GREEN. 전체 `flutter test`는 기존/범위 밖 실패 4건(`community_mock_screen_test.dart` 3건, `records_screen_test.dart` 1건)으로 GREEN 아님.

## 2026-06-23 레거시 기록 타입 영구 삭제 계획(현재 코드 미반영)

- `V20__remove_deprecated_activity_types.sql`로 `play`, `sleep`, `checkup` 기록의 미디어 storage key를 `media_cleanup_queue`에 먼저 보존하고, 관련 루틴 참조를 null 처리한 뒤 대상 루틴·완료 이력·기록·타입을 영구 삭제한다. `bath`, `groom`, 일정·지갑의 `grooming`, 병원 방문 사유 `checkup`은 보존한다.
- 앱 시작 `MediaCleanupRunner`는 queue의 파일을 먼저 삭제하고 성공한 key만 queue에서 제거한다. 로컬 저장소 삭제는 `deleteIfExists`라 멱등이며, 파일 또는 DB queue 삭제 실패는 다음 시작에서 재시도한다.
- 백엔드는 create/list filter와 루틴 create/update에서 제거 타입을 400으로 거부한다. Flutter는 타입 정의, quick type preference, 루틴 선택지, 홈/health 표시 및 직접 URL redirect를 9개 타입 기준으로 맞춘다. 일정·지갑 `grooming`과 병원 방문 사유 `checkup`은 유지한다.
- 검증 상태: V20 정상·부분 재시도와 빈 DB V1→V20, runner·기록·루틴·CareSchedule·Wallet을 포함한 backend 전체 테스트가 통과했다. Flutter 전체 353개 테스트, analyze, web build, `git diff --check`, 한글 깨짐 검사도 통과했고 `pubspec.lock` 변경은 없다.

## 2026-06-05 PetEdit 입력 UI 보정

- 공통 `PetDateField`를 추가해 PetEdit 생년월일/함께한 날, Onboarding 생년월일을 read-only `TextField`가 아닌 `Material + InkWell` 날짜 선택 필드로 바꿨다. 캘린더 아이콘과 `생년월일을 몰라요` 동작은 유지했다.
- PetEdit 기본 프로필의 종 선택은 3열 `GridView`로 고정하고, 성별/중성화는 각각 `Row + Expanded 2개`, 특수상태는 dense `PetChoiceButton` 4개 한 줄로 보정했다. 중성화 활성 정책과 저장 payload 보존 정책은 변경하지 않았다.
- `PetTextField`는 RecordScreen 입력과 맞춰 흰 배경, muted hint, 14px semibold 텍스트, `AppColors.primary` cursor/focused border, 14px radius, tap outside unfocus를 사용한다. selection highlight/handle theme은 바꾸지 않았다.
- 테스트는 구조 기준으로 보강했다. PetEdit 종 3열 grid, 날짜 필드 타입과 date picker sheet 진입, 성별/중성화/특수상태 row 구조, `PetTextField` focused border 색상을 확인하고 Onboarding 생년월일이 `PetDateField`로 렌더링되는지 확인한다.

## 2026-06-05 기록 입력 날짜 흐름 및 기타 기록 연동

- `/records?date=YYYY-MM-DD`와 `/records/{type}/new?date=YYYY-MM-DD`를 지원한다. route date는 strict `YYYY-MM-DD` 검증 후 유효할 때만 사용하고, 없거나 잘못된 값이면 오늘 날짜로 fallback한다.
- 기록 메인에서 선택한 날짜를 급식 및 카테고리 입력 화면으로 전달한다. 입력 화면의 날짜 picker는 제거하고 읽기 전용 날짜 라벨만 표시하며, `현재 시간으로 설정`은 날짜를 바꾸지 않고 시간만 현재 시간으로 갱신한다.
- 급식/카테고리 기록 저장 성공 후에는 `/records?date=<저장 날짜>`로 돌아가 저장한 날짜의 기록 목록을 유지한다. 저장 CTA는 상단 헤더가 아니라 스크롤 콘텐츠 최하단의 `RecordFormSubmitButton`으로 통일했다.
- `etc` 활동 타입을 추가해 `기타` TypeCard가 전체 화면 입력으로 진입한다. `etc`는 `diary`와 같은 note-only 타입이며 detail 테이블 없이 `activity_records.note`만 사용한다. 빠른 기록용 `record_modal.dart`와 지출 날짜 선택 흐름은 유지했다.
- 백엔드는 `V13__add_etc_activity_type.sql`, `ActivityRecordService.SUPPORTED_TYPES`, test seed, `ActivityRecordIntegrationTest`에 `etc` create/get/delete note-only 흐름을 반영했다.

## 2026-06-02 My 메뉴 · 설정 · 로그아웃 구현

- My 메인의 설정, 전체 펫, 프로필 편집 진입점을 `/my/settings`, `/my/pets`, `/my/profile`로 연결했다. 대표 펫은 `activePet ?? pets.firstOrNull`을 사용하고 전체 목록에서는 active pet에만 `현재 선택` badge를 표시한다.
- 인증이 필요한 이미지 bytes 로딩을 `AuthenticatedNetworkImage`로 추출해 Home, My 펫 카드, My 프로필 기존 이미지에 적용했다.
- 로그아웃은 서비스 호출 직후 loading lock을 걸고, 실패 시 기존 인증 상태를 복원한다. 성공, 인증 만료, 저장 토큰 검증 실패는 펫 정리 실패를 기록하고도 signed-out 상태를 보장하는 공통 helper를 사용한다.
- 후속 작업: `PetNotifier.clearForSignedOutUser()` 환경설정 Future 실패/무한 대기 방어, 백엔드 사용자 응답과 `UserProfile.id` 매핑 정리, 프로필 저장 API 연결.

## 2026-06-02 사용자 접근 화면 현황 문서 동기화

- `docs/FRONTEND_STATUS.md`를 파일 존재 여부가 아니라 현재 사용자 동선 기준으로 정리했다. `🚧 부분 구현`, `🧭 진입점 없음` 상태를 추가하고 Home, Community, My, Records, Wallet, Routine의 placeholder와 미연결 화면을 표로 기록했다.
- 기록 문서에서 이전 `QuickRecordRow`, `RecordModal`, records 탭 위젯을 현재 기능처럼 설명하던 내용을 정정했다. 현재 `/records`에서 접근 가능한 타입, 숨겨진 타입, `기타` placeholder, 상세·수정·삭제 UI 부재, 급식 전용 사진 첨부 범위를 분리했다.
- 루틴 일정 목록은 고정 샘플, 일정 저장과 지도 검색은 `준비중`, 지출 저장과 항목·사진 추가는 미구현, Community 게시글 상세·댓글·이미지/투표 표시와 참여는 미연결, My 메뉴 대부분과 로그아웃 UI는 진입점 없음으로 기록했다.
- `docs/ARCHITECTURE.md`에서 실제로 없는 `pet_selector.dart` 참조를 제거하고 현재 라우터에서 호출되지 않는 legacy 위젯 경계를 명시했다. 애플리케이션 코드, 테스트, `DESIGN.md`는 수정하지 않았다.

## 2026-06-02 Home · Community · My 헤더 색상 및 액션 아이콘 통일

- 탭 헤더 규칙을 `DESIGN.md`에 추가했다. 탭 헤더는 `AppColors.background`, 제목은 `AppColors.text`, 우측 액션은 `38x38` surface와 `20px` `AppColors.textSecondary` 아이콘을 사용한다. 탐색 역할의 뒤로가기 아이콘은 기존 `28px`를 유지한다.
- `AppHeaderIconButton.onTap`을 nullable로 바꿔 표시 전용 비활성 액션도 공용 surface를 사용할 수 있게 했다. Home 알림 버튼은 `home-notification-button` key와 바깥 `48x48` 슬롯을 유지한 채 공용 버튼으로 교체했다.
- Community 메인/카테고리 공유 헤더는 `AppColors.background` 배경, border 없음, `AppColors.text` 제목으로 맞췄다. My는 기존 `AppHeader`와 설정 액션을 그대로 유지했다.
- 관련 회귀 검증: 2026-06-02 `flutter test test/widgets/app_header_test.dart test/screens/home/home_screen_test.dart test/screens/community/community_screen_test.dart test/screens/my/my_screen_test.dart` GREEN(33 tests).

## 2026-06-01 화면 헤더 역할별 통일 및 복귀 안정화

- `frontend/lib/widgets/app_header.dart`에 Scaffold `appBar`용 `AppHeader`, 조회형 body 헤더 `AppInlineHeader`, 입력형 body 헤더 `AppFormHeader`를 구분했다. 공용 헤더는 UI만 담당하고 화면별 `pop()` 우선, direct URL fallback, 키보드 dismiss 정책은 각 화면에 남겼다.
- 기록, 성장곡선, 지갑, 지출 리포트, 루틴, 기록 입력, 비용 추가, 온보딩, 펫 상세·수정 화면에 역할별 헤더를 적용했다. 커뮤니티 메인/카테고리와 글쓰기는 bespoke 헤더를 유지하되 direct URL fallback을 보강했다.
- `/records`는 active pet이 없어도 헤더와 뒤로가기를 유지하고 `전체 기록` 액션만 숨긴다. `/pet/:id`는 로딩과 없는 ID를 구분하며, `/pet/:id/edit`는 provider late hydration 중 예외 없이 spinner를 표시하고 같은 ID rebuild가 사용자 편집값을 덮어쓰지 않는다.
- 마지막 반려동물 삭제 시 상세 화면은 추가 `pop()`을 호출하지 않고 router redirect에 맡긴다. 반려동물이 남아 있을 때만 상세 화면을 이탈한다.

## 2026-06-01 기록 입력, 지갑, 루틴 화면 변경

- `RecordTypeGrid`에서 `checkup` 카드는 숨기고, `water`, `diary`는 전체 화면 입력 route로 연결했다. `checkup` 백엔드 타입과 기존 표시 config는 유지한다.
- `RecordCategoryFormScreen`은 `water`의 필수 음수량(`ml`), `diary`의 필수 메모, `poop`의 선택 메모를 저장 payload에 반영한다.
- `MealRecordScreen`은 섭취율 아래에 메모 필드를 항상 표시하고 payload `note`에 저장한다. 급식/카테고리 기록 저장 성공 후에는 `/records`로 이동한다.
- 백엔드는 `V12__add_diary_activity_type.sql`로 `diary` 타입을 추가했다. `diary`는 전용 detail 테이블 없이 `activity_records.note`만 사용한다.
- 홈 메뉴에서 `지갑`이 `/wallet`로 연결되고, `/wallet/report`, `/records/expense/new` 화면이 추가됐다. 지출 저장은 아직 `준비중`이며 백엔드 `expense` 타입은 확정되지 않았다.
- 루틴 메인은 달력/일정 탭과 월간 달력으로 정리됐다. `/routine/new`는 서버 `label`과 `note` 의미를 분리하고 반복 요일을 포함해 루틴 생성 API에 연결된다. `/routine/schedule/new`는 로컬 일정 입력 UI를 제공하며 저장은 아직 `준비중`이다.

## 2026-05-27 커뮤니티 글쓰기 화면 변경

- `frontend/lib/screens/community/write_screen.dart`는 mock 기반 글쓰기 화면으로 변경됐다.
- 상단은 `취소 / 자유 / 등록` 커스텀 바를 사용한다. 게시판 기본값은 `FREE`이고 표시 라벨은 `자유`다.
- 게시판 선택은 `CupertinoPicker` bottom sheet로 열리며, 선택 완료 시에만 `_category`가 갱신된다.
- 제목은 필수다. 제목이 비면 `제목을 입력해 주세요`, 본문이 비면 `내용을 입력해 주세요`를 표시하고 등록하지 않는다.
- 하단 이미지/투표 버튼과 기존 provider/service 계약은 유지한다. 백엔드, DB, API service 변경은 없다.
- 투표 버튼을 누르면 글쓰기 화면 안에 mock 투표 패널이 표시된다. 패널은 `[체크] 투표`, 닫기 `X`, 기본 `항목 입력` 2개, `항목 추가`, `* 글 등록 이후에는 투표를 수정할 수 없어요.` 안내문으로 구성된다.
- 투표 항목 추가는 클라이언트 입력 컨트롤만 늘린다. 등록 payload는 기존 `PollDraft` 경로를 유지하며, 항목이 2개 이상 입력된 경우 question은 임시로 `투표`를 보낸다.
- 검증: 2026-05-27 `flutter test test/screens/community/community_screen_test.dart` GREEN, `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN.

## 5줄 현황 요약

1. 현재 상태: Flutter 마이그레이션 완료. `frontend/`는 React Native → Flutter (Riverpod + go_router)로 전환됐다.
2. 마지막 확인된 검증: 2026-07-03 프론트 `flutter test` GREEN(361 tests), `flutter analyze` `No issues found!`; 백엔드 `CommunityIntegrationTest --rerun-tasks` GREEN. 마지막 확인된 웹 빌드는 2026-06-02 성공이다.
3. 최신 스키마: Flyway `V1`부터 `V20__remove_deprecated_activity_types.sql`까지 존재한다. 기존 마이그레이션은 수정하지 않는다.
4. 최근 변경 흐름: 로컬 CORS `PATCH`, 로그아웃 시 펫 상태 정리, 커뮤니티 제목·본문 검색과 피드 pagination, Flutter service keyword 전달을 보강했다.
5. 다음 우선순위: 커뮤니티 검색 UI·알림·카테고리 필터, 댓글·답글 수동 회귀, 기록 direct URL 예외 확인, 루틴 수정 UI 순서로 남은 사용자 동선을 완성한다.

## 마지막 검증

- 백엔드 전체 테스트: 2026-05-18 `.\gradlew.bat clean test` GREEN.
- 프론트 정적 분석: 2026-05-18 `flutter analyze --no-fatal-infos` Exit 0 (info 4건만, 경고/오류 없음).
- 프론트 테스트: 2026-05-18 `flutter test` GREEN.
- 프론트 웹 빌드: 2026-05-18 `flutter build web` → `√ Built build\web` 성공. `flutter_secure_storage_web` 관련 wasm dry-run 경고만 출력됨.
- 한글 깨짐 검사: 2026-05-18 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN.
- 공통 네비게이션 위젯 반영 후 부분 검증: 2026-05-23 `C:\flutter\bin\cache\dart-sdk\bin\dart.exe analyze` Exit 0 (info 3건만), 한글 깨짐 검사 GREEN. 단, `flutter.bat --version`과 `flutter test test/widgets/app_navigation_test.dart`는 로컬 Flutter wrapper가 응답하지 않아 timeout.
- 기록 입력 패널 통일 후 부분 검증: 2026-05-25 `flutter test test/widgets/record_inputs/record_picker_values_test.dart`, `flutter test test/widgets/record_inputs/record_input_pickers_test.dart`, `flutter test test/screens/records/meal_record_screen_test.dart`, `flutter test test/screens/records/record_category_form_screen_test.dart` GREEN. `flutter analyze --no-fatal-infos` Exit 0 (기존 info 3건만). 한글 깨짐 검사 GREEN.
- 기록 타입 그리드 라벨/순서 표시 변경 후 검증: 2026-05-26 한글 깨짐 검사 GREEN. 사용자 요청에 따라 테스트/분석 명령은 실행하지 않음.
- 숫자 키패드 preview 및 캘린더 연도 범위 변경 후 부분 검증: 2026-05-26 `flutter test test/core/calendar_ranges_test.dart`, `flutter test test/widgets/record_inputs/record_input_pickers_test.dart`, `flutter test test/widgets/record_inputs/record_picker_values_test.dart`, `flutter test test/screens/records/meal_record_screen_test.dart`, `flutter test test/screens/records/record_category_form_screen_test.dart`, `flutter test test/screens/expense/expense_add_screen_test.dart` GREEN. `flutter analyze --no-fatal-infos` Exit 0 (기존 info 3건만). 한글 깨짐 검사 GREEN.
- 기록 TypeCard 전체 화면 입력 변경 후 부분 검증: 2026-06-01 `flutter test test/screens/records/records_screen_test.dart`, `flutter test test/screens/records/meal_record_screen_test.dart`, `flutter test test/screens/records/record_category_form_screen_test.dart`, `flutter test test/router/app_router_test.dart`, `.\gradlew.bat test --tests com.petyilgi.record.ActivityRecordIntegrationTest` GREEN. 한글 깨짐 검사 GREEN.
- 루틴 상태 안정화 후 전체 검증: 2026-06-01 `flutter test` GREEN(151 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `flutter build web` GREEN, `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN. 루틴 화면 분리 테스트와 날짜 고정 기록 캘린더 fixture 안정화도 함께 반영했다.
- 화면 헤더 역할별 통일 및 복귀 안정화 후 전체 검증: 2026-06-01 `flutter test` GREEN(171 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `flutter build web` GREEN, `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN, `git diff --check` whitespace 오류 없음. 직접 `AppBar`, records private 헤더, 오래된 위젯 맵 참조 검색도 빈 결과다.
- Home · Community · My 헤더 색상 및 액션 아이콘 통일 후 전체 검증: 2026-06-02 `flutter test` GREEN(172 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `flutter build web` GREEN(`flutter_secure_storage_web` wasm dry-run 경고만 출력), `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN, `git diff --check` whitespace 오류 없음.
- 사용자 접근 화면 현황 문서 동기화 후 검증: 2026-06-02 오래된 화면 현황 참조 `rg` 검색 빈 결과, `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN, `git diff --check`, `git diff --cached --check` whitespace 오류 없음, `git status --short backend frontend DESIGN.md` 빈 결과. 문서 전용 작업이므로 애플리케이션 테스트는 다시 실행하지 않았다.
- My 메뉴 · 설정 · 로그아웃 구현 후 전체 검증: 2026-06-02 `flutter test` GREEN(191 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `flutter build web` GREEN(`flutter_secure_storage_web` wasm dry-run 경고만 출력), `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN, `git diff --check`, `git diff --cached --check` whitespace 오류 없음.
- 기록 입력 날짜 흐름 및 기타 기록 연동 후 부분 검증: 2026-06-05 `.\gradlew.bat test --tests com.petyilgi.record.ActivityRecordIntegrationTest` GREEN, `flutter test test/screens/records/records_screen_test.dart test/screens/records/meal_record_screen_test.dart test/screens/records/record_category_form_screen_test.dart test/router/app_router_test.dart` GREEN(67 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN, `git diff --check` whitespace 오류 없음(CRLF 경고만 출력).
- PetEdit 입력 UI 보정 후 부분 검증: 2026-06-05 `flutter test test/screens/pet/pet_screen_test.dart test/screens/onboarding/onboarding_screen_test.dart` GREEN(24 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN.
- 커뮤니티 상세·댓글·투표 연동 후 부분 검증: 2026-06-25 `.\gradlew.bat test --tests com.petyilgi.community.CommunityIntegrationTest` GREEN, `flutter test test\models\post_test.dart test\services\community_service_test.dart test\screens\community\community_screen_test.dart test\router\app_router_test.dart` GREEN(66 tests), 선택 파일 `dart analyze` Exit 0(info 2건), `git diff --check` whitespace 오류 없음, `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN. 전체 `flutter test`는 기존/범위 밖 `community_mock_screen_test.dart` 3건과 `records_screen_test.dart` 1건 실패로 통과하지 않았다.
- 루틴 일정 서버 연동 후 부분 검증: 2026-06-26 `.\gradlew.bat test --tests com.petyilgi.routine.CareScheduleIntegrationTest` GREEN, `flutter test test\services\care_schedule_service_test.dart` GREEN, `flutter test test\providers\pet_provider_test.dart test\screens\routine\routine_schedule_create_screen_test.dart test\screens\routine\routine_screen_test.dart test\router\app_router_test.dart` GREEN(72 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 4건).
- 기록 CRUD 수동 검증 및 배변 옵션 카드 보정: 2026-06-27 타입별 기록 생성, 목록→상세→수정·삭제 기본 동선이 정상 동작함을 확인했다. 배변 옵션 카드의 Flutter Web hover/focus 회색 잔상을 제거하고 대변·소변 색상 그리드 상태를 분리했다. `flutter test test/screens/records/record_category_form_screen_test.dart` GREEN(19 tests), `git diff --check` whitespace 오류 없음.
- 커뮤니티 댓글·답글 최종 검증: 2026-06-27 `flutter test` GREEN(326 tests), `flutter analyze` `No issues found!`, `.\gradlew.bat test --rerun-tasks --tests com.petyilgi.community.CommunityIntegrationTest --tests com.petyilgi.support.FlywayMigrationTest` GREEN, 한글 깨짐 검사와 `git diff --check` GREEN.
- CORS·로그아웃 안정화와 커뮤니티 검색 통합 검증: 2026-06-30 `.\gradlew.bat test --rerun-tasks` `BUILD SUCCESSFUL`, `flutter test` GREEN(339 tests), `flutter analyze` `No issues found!`, 한글 깨짐 검사와 `git diff --check` GREEN.

## 다음 행동

- 문서 정리 작업이면 `AGENTS.md`, `docs/AI_WORKFLOW.md`, `docs/BACKEND_RULES.md`, `docs/AI_MISTAKES.md` 기준을 우선 확인한다.
- 백엔드 작업이면 `docs/BACKEND_RULES.md`와 `docs/FRONTEND_STATUS.md`를 읽고 TDD 순서를 따른다.
- Flutter UI 작업이면 `DESIGN.md`를 먼저 읽고 디자인 시스템 준수 여부를 성공 기준에 포함한다.
- 앱 검증 작업이면 백엔드(`./gradlew.bat bootRun`)와 Flutter(`flutter run`)를 함께 실행한 뒤 회원가입/로그인, 펫 온보딩, 기록 CRUD, 루틴 CRUD, 커뮤니티 피드/좋아요, 배변 사진 업로드/표시, 로그아웃 후 재진입을 확인한다.

## 주의사항

- `backend/src/main/resources/db/migration/V1`부터 `V20`까지 기존 Flyway 파일은 수정하지 않는다.
- 새 DB 변경은 다음 번호의 새 마이그레이션으로만 추가한다.
- 문서 정리만 하는 작업에서는 `backend/`, `frontend/`, `DESIGN.md`를 수정하지 않는다.
- 기존 dirty worktree 변경은 사용자 또는 이전 작업자의 작업으로 보고 되돌리지 않는다.
- Windows 콘솔의 기본 출력만 보고 한글 파일이 깨졌다고 판단하지 않는다.
- 한글 문서를 편집한 뒤에는 한글 깨짐 검사를 실행한다.
- 배포, S3, MinIO, LocalStack, 도메인, SSL, 운영 스토리지는 별도 배포 단계까지 보류한다.

## 최신 Handover

- Goal: main 진단 감사의 `LoadedMedia.contentType` 계약 후보를 실제 null guard와 단일 record annotation으로 검증한다.
- Done: null 입력 RED 테스트를 먼저 확인하고 storage guard와 component `@NonNull`을 적용했다. Java snapshot은 336개에서 333개로 감소했고 controller 경고 3개만 제거됐으며 신규 진단은 없다. 선택·전체 backend 테스트가 통과했다.
- Remaining: Java 진단은 333개(main 26, test 307)다. main에는 CONTRACT_CANDIDATE 5개와 EXTERNAL_BOUNDARY 21개가 남아 있다.
- Next step: 남은 후보 중 `KakaoLoginRequest.accessToken` 1개는 validation 전 객체 상태를, `petId` 4개는 전체 호출 체인을 먼저 설계한 뒤 진행 여부를 결정한다.
- Warnings: 외부 경계 21개는 숫자만 줄이기 위해 수정하지 않는다. private helper만 annotation해 경고를 호출자로 이동시키지 말아야 하며 `.worktrees`는 Java import에서 제외된다.

## 이전 Handover

- Goal: backend-roadmap의 지갑 지출 1차 백엔드, 프론트 전환, cleanup, 최종 검증 문서 흐름을 구현자가 바로 따라갈 수 있게 03~11번 문서 계약과 작업 순서로 정리한다.
- Done: `docs/backend-roadmap/03_TARGET_ERD.md`~`08_BACKEND_IMPLEMENTATION_TASKS.md`에 `itemName` nullable, DELETE `204 No Content`, `ProblemDetail.errorCode`, 공통 `ApiException`, pet 검증 순서, `INVALID_INPUT`/`VALIDATION_FAILED` 구분, base64url opaque cursor, soft delete pet 정책, V16 migration 계획, 통합 테스트 기대값, 백엔드 Red-Green 구현 순서를 반영했다. 이어서 `docs/backend-roadmap/09_FRONTEND_INTEGRATION_PLAN.md`를 템플릿에서 실제 프론트 연결 계획으로 교체했고, `WalletExpense` 모델/service/provider, route `recordId -> expenseId`, `ActivityRecord.typeId == "expense"` 분리, wallet 화면/테스트/FRONTEND_STATUS 갱신 순서를 구체화했다. `docs/backend-roadmap/10_DEAD_CODE_CLEANUP_PLAN.md`는 `/records/expense/new`, `ExpenseFormData.toRecordBody()`, `ActivityRecord.typeId == "expense"` 필터, `expense_record_utils.dart`, wallet 테스트 fixture 제거 기준과 검증 명령을 포함한 확정 초안으로 구체화했다. 이번 작업에서는 `bath`/`groom`을 10번 지갑 cleanup이 아닌 별도 기록 cleanup 후보로 분리했고, `docs/backend-roadmap/11_VERIFICATION_PLAN.md`를 백엔드 선택/전체 테스트, 프론트 선택/전체 테스트, cleanup 역참조 검색, 문서/변경 범위 검증, 최종 보고 형식을 포함한 확정 초안으로 교체했다.
- Remaining: 실제 `V16__create_wallet_expenses.sql`, `init-test.sql`, 백엔드 구현 코드, 통합 테스트 코드, Flutter 모델/service/provider/screen/test 코드는 아직 작성하지 않았다.
- Next step: 문서를 계속 점검한다면 01~11번 전체를 다시 읽고 누락/충돌을 확인한다. 구현으로 넘어가면 08번의 `WalletExpenseIntegrationTest` 첫 Red 테스트부터 시작한다.
- Warnings: `docs/backend-roadmap/`는 `.gitignore`에 의해 ignored 상태라 일반 `git status --short`에는 문서 변경이 보이지 않는다. 현재 tracked 변경으로는 기존 `.gitignore`와 `docs/CONTEXT.md`가 보인다. 문서 정리 중에는 애플리케이션 코드, migration, test 파일을 수정하지 않았다.

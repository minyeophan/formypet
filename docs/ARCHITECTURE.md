# 아키텍처와 구현 점검

코드 대조 기준일: 2026-09-29. 외부 콘솔과 운영 서버의 실제 상태는 확인하지 않았습니다.

## 시스템 구성

Flutter 화면 → Riverpod provider → service → Dio → Spring Controller → Service → JPA/JdbcTemplate → MySQL 흐름입니다. 파일은 LocalMediaStorage에 저장하고, 일정 푸시는 Firebase Admin, 고객지원 메일은 SMTP로 전달합니다.

| 위치 | 책임 |
| --- | --- |
| `frontend/lib/core` | HTTP·토큰·테마·활동 타입·공통 값 |
| `frontend/lib/models,services,providers` | DTO 모델, API 호출, 화면 상태·계정 변경 처리 |
| `frontend/lib/router/app_router.dart` | 인증·온보딩 리다이렉트와 화면 경로 |
| `frontend/lib/screens` | auth, onboarding, home, records, wallet, routine, community, my, notification, pet 등 |
| `frontend/lib/widgets` | 공통 헤더·입력 패널·아이콘·이탈 확인 등 |
| `backend/src/main/java/com/formypet` | auth, pet, record, routine, wallet, community, user, media, notification, support |
| `backend/src/main/resources/db/migration` | Flyway V1–V37 |
| `backend/docker` | 개발용 MySQL Compose와 초기 설정 |

사용자·반려동물·인증은 JPA repository를 사용하며, 활동 기록·커뮤니티·지갑·일정·알림·고객지원 등에는 JdbcTemplate SQL이 함께 사용됩니다. 전체 백엔드가 JPA만으로 구성된 것은 아닙니다.

## 인증과 앱 시작

1. `main()`이 비웹 Firebase와 로컬 알림을 초기화합니다.
2. API 주소를 웹 localhost / 비웹 Android 에뮬레이터 주소로 지정합니다.
3. `KAKAO_NATIVE_APP_KEY`를 확인하고 Kakao SDK를 초기화합니다. 누락 시 runApp 전에 예외가 발생합니다.
4. AuthNotifier가 저장 토큰으로 사용자 프로필을 조회하고, 인증 후 반려동물 데이터를 불러옵니다.
5. 라우터는 인증·펫 로딩 중 전환을 보류하고, 미인증은 auth, 최초 펫 등록 전은 onboarding으로 보냅니다. 인증 복원 오류는 splash 재시도 화면, 펫 조회 오류는 home의 오류 상태로 처리합니다.
6. 인증된 UI 표시 후 기기 푸시 토큰을 등록합니다.

Dio는 일반 Interceptor를 사용합니다. GET 일시 장애는 한 번 재시도하며, 401 토큰 갱신은 공유 Future와 credential revision으로 중복·이전 계정 응답을 제어합니다. 예전 문서의 QueuedInterceptorsWrapper 설명은 현재 구현과 다릅니다.

성공 JSON은 `{data, message}`이며 success 필드는 없습니다. 오류는 ProblemDetail 계열입니다. SecurityConfig가 직접 작성하는 인증 오류에는 instance가 없으므로 모든 오류 필드가 완전히 통일됐다고 볼 수 없습니다.

## 화면 경계

ShellRoute에는 home, community 목록·검색·카테고리, my와 하위 정보 화면이 있습니다. 게시글 상세·댓글, notifications, 문의 작성, 기록·지갑·루틴·펫 상세 화면은 ShellRoute 밖입니다.

`/records/all`은 `/records`로 redirect합니다. 지갑 화면은 `screens/wallet/`에 있습니다. 수정 화면 전체를 별도 클래스로 만드는 대신 루틴·일정 등은 생성 화면에 편집 정보를 전달해 재사용합니다. 정확한 등록 경로는 `app_router.dart`가 기준입니다.

공통 헤더는 AppHeader / AppInlineHeader / AppFormHeader를 사용합니다. 뒤로가기의 pop 및 fallback 목적지는 호출 화면이 관리합니다. 기록 날짜·시간·숫자 입력은 `widgets/record_inputs/`를 사용합니다.

## 데이터와 비동기 작업

- 활동 기록 API의 지원 타입: meal, water, poop, walk, medicine, weight, vet, diary, etc.
- 기록 목록은 date/type/optional limit 방식이며 모든 목록이 cursor 기반인 것은 아닙니다. 커뮤니티·지출·알림은 cursor 목록을 제공합니다.
- 월 예산은 WalletBudgetService가 SharedPreferences에 계정·월 단위로 보관합니다. 서버 예산 API와 다중 기기 동기화는 없습니다.
- 미디어는 기본 상대 경로 storage에 저장됩니다. 운영 시 영속 경로와 백업 또는 공유 저장소 정책이 필요합니다.
- 루틴·일정 알림은 1분 주기, 최근 5분 범위를 검사하고 DB 커밋 후 푸시를 보냅니다.
- 고객지원은 접수와 support_mail_outbox 저장을 같은 트랜잭션으로 처리합니다. 메일 worker에는 lease와 최대 5회 시도, 1·5·30·120분 재시도가 있습니다.
- Flyway는 V37까지 존재합니다. V26 내 활동 인덱스, V27 관리자 역할, V28 문의·메일 큐, V29 차단, V30 미사용 공간 데이터 제거, V31 비밀번호 복구, V32 계정 탈퇴, V33 신고 작성자 추적, V34 OAuth 수명주기 잠금, V35 동의 이력, V36 카카오 가입 의도, V37 게시된 정책 버전 보존이 반영됐습니다. 기존 migration 파일은 수정·삭제 대상이 아닙니다.

## 미완성 및 출시 전 확인 항목

| 우선순위 | 항목 | 코드 근거와 판단 |
| --- | --- | --- |
| 높음 | 카카오 키·플랫폼 연결 | SDK 로그인과 서버 `/auth/kakao`는 구현돼 있고 Android 에뮬레이터에서 운영용 카카오 앱 설정으로 로그인을 확인했습니다. TEST 앱 설정과 실기기·취소·재로그인 검증은 남았습니다. 현재 실기기는 없습니다. |
| 높음 | 운영 접속·배포 | main.dart의 개발 주소 고정, SecurityConfig의 localhost CORS, Android debug 서명 release 설정. 추적 파일에 앱 Dockerfile·배포 pipeline·운영 proxy·IaC가 없습니다. 외부에서 별도로 구축했는지는 미확인입니다. |
| 높음 | 운영 데이터·비밀값 | 로컬 파일 저장, 개발 MySQL Compose만 존재합니다. HTTPS, DB/파일 백업·복원, 영속 볼륨, 환경별 secret 주입과 배포·롤백 절차를 구체화해야 합니다. |
| 높음 | 정책 전문 | 비로그인 공개 정책 페이지와 가입 동의 흐름은 구현돼 있습니다. `policies/catalog.json`은 현재 `published: false`, 문서 목록도 비어 있습니다. 운영 주체·연락처·운영 인프라 등 실제 정보를 확정해 전문을 게시하고 동의 검증을 활성화해야 합니다. |
| 범위 결정 | 계정 수명주기 | 이메일·비밀번호 및 카카오 가입/로그인, 토큰 갱신·로그아웃, 비밀번호 복구 API와 회원 탈퇴 API/UI가 있습니다. 비밀번호 복구는 기본 비활성화이며 SMTP·HTTPS·비밀값 설정과 운영 검증이 남았습니다. 이메일 소유 확인 기능은 확인되지 않았고, 카카오 연결 해제는 비동기 재시도 정리가 남을 수 있습니다. |
| 범위 결정 | 사용자 알림 설정 | 계정별 알림 설정 화면과 서버 GET/PATCH API가 있습니다. 실제 Firebase 발송과 여러 기기 동작 검증은 남았습니다. OS 권한·기기 토큰 등록은 별도 기능입니다. |
| 범위 결정 | 홈 반려로그 | home_screen.dart의 QuickMenu에서 onPreparing으로 연결됩니다. 지원하지 않는 기록 타입의 fallback과 커뮤니티의 router 없는 테스트 환경 fallback은 실제 미완성 기능으로 중복 집계하지 않았습니다. |
| 운영 준비 | 문의·신고 처리 | 접수·메일 큐는 구현, 기본 메일 발송은 false. SMTP 실전송과 운영자의 답변·신고 처리 절차가 필요하며 관리 화면/API는 없습니다. |
| 운영 준비 | 관측·성능 | health API는 실행 스레드 정보 응답이며 DB/FCM/SMTP readiness 확인이 아닙니다. DEBUG SQL 로그 기본값, 알림 대상 전체 조회 및 기록 대량 조회의 부하 검증이 남았습니다. |
| 신뢰성 | 일정 푸시 | 영속 푸시 큐·자동 재시도가 없습니다. 커밋 후 발송 전 종료, 5분 초과 중단, 일시 전송 실패는 유실 가능성이 있습니다. 메일 큐는 이미 있어 구분해야 합니다. |
| 플랫폼 | iOS·웹 | iOS Info.plist에 카카오 URL scheme·앱 조회 scheme·사진/카메라 권한 설명이 없습니다. 비웹 Firebase 초기화와 고정 API 주소까지 포함해 별도 검증이 필요합니다. 웹 인증·푸시와 iOS/APNs는 완료로 판단하지 않습니다. |

카카오 서버 클라이언트는 /v2/user/me 응답으로 사용자를 확인하지만 앱 ID를 비교하는 코드는 없습니다. 토큰의 자사 앱 소속 검증 필요성은 후속 인증 검토 항목입니다. 이 점검에서 다른 앱 토큰을 이용한 재현은 수행하지 않았습니다.

지도 검색·지출 사진·다중 기기 예산 동기화는 현재 없는 기능입니다. 제품 출시 범위에 포함하는 경우에만 추가 구현 과제로 잡습니다.

## 점검 범위와 파일 정리

주요 Controller/Service, Flutter service/provider/router 및 해당 화면, 플랫폼 설정, migration 목록·테스트를 점검했습니다. 모든 실행 경로와 실제 외부 시스템을 검증한 전수 보증은 아닙니다.

기존 Markdown 7개를 최신화했습니다. 존재하지 않는 AI_MISTAKES 문서 참조, Expo/RN 기반 설명, 잘못된 마이그레이션 최신 버전, 문의 API 부재 표기, 중복/잘못된 라우트 설명을 정리했습니다. 로컬 상태 문서의 기존 Git 제외 정책은 유지합니다.

이미지 폴더에는 추적 중인 `brand_logo.png`가 있습니다. 로컬 비밀값 파일, 사용자 업로드 storage, worktree, migration, 테스트·라이선스·플랫폼 파일은 보존합니다.

## 2026-09-22 검증 기록

당시 백엔드 전체 테스트 213개(29 suites), 실패·오류·건너뜀 0. Flutter 정적 분석 문제 없음, 전체 단위·위젯 테스트 1,043개 통과. 이 기록은 이후 변경분을 포함한 현재 전체 테스트 결과가 아닙니다. Android 통합 테스트와 실제 푸시·메일·운영 배포 검증도 별도입니다.

추가 운영 점검: PetNotifier가 기록 목록을 limit 없이 가져오고 ActivityRecordService는 각 행의 상세를 추가 조회합니다. 데이터 증가 시 전체 로딩과 N+1 비용을 측정할 필요가 있습니다. MediaCleanupRunner는 시작 시 정리 큐를 처리하므로 실패 파일의 주기적 재처리는 별도 개선 항목입니다.

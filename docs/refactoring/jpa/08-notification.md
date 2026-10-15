# 08. 알림 JPA 전환

## 현재 상태
- 기준 develop: 7936cb86cd95a8a6cb2884d01d865b17adf7b032 (약관 PR105 실제 머지 후 검증 완료).
- 브랜치 refactor/jpa-notification. 선행 커밋881e1e0은 약관 완료 증적만 포함.
- 구현/관련46개 테스트/전체481개 테스트/독립 리뷰/MuMu 전체 및 재실행 통과. PR 생성 준비.
- QA55551/PID34692는 현재 알림 구현 jar, API18083/격리 MySQL3318, scheduler=true/1000ms. MuMu16384의 mediatest 앱 사용. 외부 FCM 자격 증명 없음.

## 보존 계약
- V22/V23 notifications: IDENTITY, recipient/actor/post/comment FK 및 삭제 cascade; actor/post nullable; 예약 unique(recipient,source_type,source_id,scheduled_for,type).
- V25 device_tokens: token 전역 unique, user FK cascade, created/updated DATETIME6; token 등록은 원자 upsert로 소유자 이전/재활성화.
- feed id DESC/cursor id<, limit1~50, size+1, 최근30일 DB CURRENT_TIMESTAMP6 경계. count/read/readAll 동일 차단 visibility(행위자 및 게시물 작성자).
- created/read는 UTC Instant JSON, scheduled_for는 알림 timezone의 LocalDateTime. TIME/DATETIME 변환과 마이크로초 보존.
- 자기 자신 및 차단된 활동은 알림 생성 생략. 커뮤니티 트랜잭션과 생성 원자성 유지.
- 예약 생성은 사용자 FOR UPDATE 후 최신 enabled 확인, INSERT IGNORE 결과1일 때만 afterCommit 발송. 롤백/중복 발송 없음.
- dispatcher REQUIRES_NEW, ACTIVE+enabled 사용자 잠금, 현재 일정/루틴 재검증 후 발송. invalid token은 recipient/token/updated_at snapshot 일치 시에만 disable(동일 계정 재등록 및 계정 이전 보호).
- 설정 변경/토큰 변경은 SessionGuard.lockCurrent. 알림 활성화 때 정책 동의 확인. 설정 변경은 notification_enabled와 updated_at만 변경.
- deletePendingReminders는 미읽음/해당source/예약시간>=알림timezone now만 삭제. 과거 전달 이력 보존.
- 루틴 daily/weekly/biweekly/monthly와 날짜경계, lookback 양끝 포함, 잘못된 JSON/시간의 기존 skip 의미 보존. 케어 null time09:00, 한글/영문 reminder offset 보존.
- Firebase generic privacy payload, 500단위 batch, 영구 UNREGISTERED만 disable, 부분/일시 실패 처리 유지.
- scheduler/cleanup enable 조건 및 주기/cron 유지.

## 목표 구조
- domain.notification.controller.NotificationController
- entity.Notification, DeviceToken, NotificationType. HTTP DTO 의존 금지.
- dto/request(DeviceTokenRequest,NotificationSettingsRequest), dto/response(기존 세 응답).
- repository NotificationRepository/DeviceTokenRepository: JPA entity 기본 저장/조회/상태 조작.
- repository/query: typed feed 및 타 도메인 조인 snapshot. visibility/DB시계/native SQL 유지 이유 명시.
- repository/jdbc: 원자 reminder insert/token upsert, 사용자 current-read lock 및 토큰 conditional invalidation. 필요 SQL만 보존.
- service 인터페이스 + impl: feed/설정, 토큰, reminder 생성 및 스케줄 평가, dispatcher 책임 분리. 기존 외부 호출용 NotificationService facade 유지 가능.
- scheduling: 세 Job; client: PushSender/PushSendResult/FirebasePushSender; config: NotificationProperties/Configuration.
- 반복 일정 규칙은 DB row mapper 밖의 순수 규칙으로 추출. 조회 결과는 Map 대신 typed snapshot.

## 순서와 검증
1. [x] 기존 알림 기준선 terminal/XML 기록. 기존 테스트 전체 내용 및 frontend 알림 흐름 읽기.
2. [x] 엔티티 매핑/UTC/nullable/FK/unique/시간정밀도 RED→GREEN. 기본 알림 JPA 저장, typed feed와 visibility 읽음 계약.
3. [x] token upsert/snapshot invalidation, setting stale entity 및 사용자 락 회귀 RED→GREEN. SQL 저장소 격리.
4. [x] 예약 생성 afterCommit/중복/rollback 및 타 도메인 snapshot 조회, 순수 recurrence 분리. 기존 테스트의 mock만 새 경계에 맞춰 수정하고 동작 assertion 유지.
5. [x] domain 패키지/인터페이스/Job/client/config 이동. 외부 호출 import 수정. 서비스 SQL/Map 행매핑 잔여 검색.
6. [x] 관련+전체backend/조회비용/독립 최종 리뷰. MuMu 목록/읽음/전체읽음/설정/예약 이력/앱 재실행; FCM 실외부 발송은 mock 검증과 구분.
7. [ ] refactor : 알림 도메인 JPA 전환 및 발송 처리 분리 커밋/push/develop PR, head CI 전부 통과 후 머지.
8. [ ] 실제 merge jar 재빌드, MuMu 전체+기존+공통, develop CI 및 로그 후 다음 support.
- 기준선26602 성공1분45초, XML33/0/0/0. 엔티티/저장소 RED84699는 새 타입 부재6건으로 실패. Notification/DeviceToken 매핑 및 JpaRepository 추가 후 GREEN11525 실행 중. 아직 기존 서비스는 변경하지 않았다.
- 저장소 RED26760은 신규 메서드 부재로 실패. GREEN52544는39개 중1개 실패: JPA native interface projection의 read_at이 기대 UTC LocalDateTime보다 정확히9시간 뒤로 변환됨. JDBC 직접 LocalDateTime 추출을 하는 JPA repository fragment(NotificationFeedImpl)로 조회를 격리하고 재검증4154 실행 중.
- 조회 수정4154 성공2분, XML39/0. 서비스 연결55565 성공2분2초, XML39/0. NotificationService 및 DeviceTokenService의 직접 SQL 제거. 예약 대상/순수 규칙 RED45778은 신규 타입 부재21건으로 실패. ReminderSchedule/typed candidate 조회 저장소 추가 후49596 검증 중.
- 예약 생성/dispatcher 연결20973 성공2분9초, XML42개/실패0/오류0/스킵0. 알림 프로덕션 서비스 전체에서 직접 SQL/JdbcTemplate/Map 행 매핑 검색 결과 없음. 다음은 서비스 책임 분리·인터페이스 및 domain.notification 패키지 이동, 케어/실제 commit 회귀 보강이다.

- 최종 관련 테스트82124 성공2분4초, XML46/실패0/오류0/스킵0. 실제 commit/rollback·care 기본시간/경계·조회비용 검증 포함. 독립 리뷰 수정 필요 사항 없음. MuMu 테스트 analyzer43041 통과. bootJar8510 성공24초. QA55551/PID34692에서 실제 스케줄러 활성화. 전체backend8146 및 MuMu59187 실행 중.

## 구현 결과와 SQL 유지 근거
| 기존 책임 | 새 위치 | 저장 방식/이유 |
|---|---|---|
| 활동 알림 생성 | service/impl/NotificationServiceImpl, entity/Notification | JpaRepository.saveAndFlush로 호출자 트랜잭션에 참여 |
| 목록/읽음/정리 | NotificationQueryServiceImpl, repository/NotificationRepository | 목록은 typed JDBC fragment로 DATETIME 직접 추출, count/cleanup은 DB 현재시각 조건 유지 |
| 읽음 표시 | repository/jdbc/NotificationCommands | visibility와 COALESCE를 한 UPDATE에 적용해 권한 및 최초 읽음 시각을 원자적으로 보존 |
| 알림 설정 | NotificationSettingsServiceImpl | 사용자 세션 잠금 후 선호도 열만 갱신; 오래된 User 엔티티의 덮어쓰기 방지 |
| 예약 생성 | NotificationReminderServiceImpl | 사용자 최신 설정 잠금+INSERT IGNORE; 삽입 성공 시 afterCommit만 발송 |
| 토큰 등록/해제 | DeviceTokenServiceImpl, NotificationCommands | 전역 unique token 원자 upsert 및 소유자 일치 조건 유지 |
| 발송 대상/무효 토큰 | ReminderPushDispatcherImpl, DeviceTokenRepository | REQUIRES_NEW와 JPQL scalar snapshot; 사용자/토큰/updatedAt 일치 시에만 해제 |
| 루틴/케어 예약 계산 | 두 ReminderServiceImpl, entity/ReminderSchedule | typed 타 도메인 조회와 순수 반복/offset 규칙 분리 |
| FCM/작업/설정 | client, scheduling, config | 기존 배치/재시도 구분, enable 조건, cron 및 설정 이름 유지 |

모든 변경은 기존 스키마 V43에 동작한다. 추가 Flyway migration이나 운영 설정 변경은 없다. SQL은 repository 하위에만 남기며 Service/Controller의 SQL/JdbcTemplate/Map 행 매핑 검색 결과는 없다.

## MuMu 브랜치 검증
- 대상: 127.0.0.1:16384, com.formypet.frontend.mediatest, http://127.0.0.1:18083, 격리 MySQL3318.
- 59187 전체 시나리오26초 통과: 댓글/좋아요4건, 커서 중복 없음, 타 사용자 읽음404, 토큰 등록/해제, 설정off 동안 예약 없음, on 후 실제 루틴/케어2건 생성 및 중복 없음, UTC/예약시간, 화면 읽음/모두읽음, 차단 visibility.
- 83982 재실행5초 통과: 같은 사용자/알림ID/최초readAt/전체읽음/설정off 및 화면 보존. 두 실행 모두 --no-uninstall.
- 외부 FCM 실발송은 QA 자격 증명 부재로 수행하지 않았다. 기존 FirebasePushSender 모의 테스트와 실제 DB afterCommit/rollback/invalid-token commit 테스트로 서버 발송 계약을 검증했다.
- develop 머지와 실제 merge SHA의 MuMu 재검증은 아직 수행 전이다.

- 전체8146은481개 중 reflection 경로 오류1건으로 실패. 테스트 문자열을 새 패키지로 수정한 전체10713은8분39초 성공, 최신 XML481/실패0/오류0/스킵0 및 TimeModelTest1/0 확인. QA55551 로그 요청 오류 없음. 최신 origin/develop7936cb8 확인.

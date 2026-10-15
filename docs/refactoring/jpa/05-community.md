# 05. 커뮤니티 JPA 전환

## 상태와 기준

- 상태: 완료 — PR #103 머지 및 머지 SHA의 CI/재실행/전체/공통 MuMu 검증 통과
- 기준 develop: `509bb551af7e7d0f3a2855fe9e688f340acc2462` (기록 PR #102 머지 및 MuMu 검증 완료)
- 브랜치: `refactor/jpa-community`
- PR: https://github.com/minyeophan/formypet/pull/103
- 검증 head: `980bebb442b933870022bb0cd6c54e0d4ae4057a`
- merge SHA: `607299ef2ac662173b62d7d16d49392817ec70a8` (검증 head와 tree 동일)
- 기준선: `gradlew.bat test --tests 'com.formypet.community.*' --no-daemon`, 세션 79235, 1분 56초 성공. XML 43 tests / 0 failures / 0 errors / 0 skipped.

## 파일과 책임

기존 `com.formypet.community`를 `com.formypet.domain.community`로 이동한다.

| 기존 | 목표 및 책임 |
|---|---|
| CommunityController, MyActivityController | controller/ 아래 동일 API, 인증 주체와 요청 검증 유지 |
| dto/* | dto/request 및 dto/response, JSON 필드와 enum 값 유지. 신고 사유 enum은 dto에 유지 |
| CommunityService | service 인터페이스와 impl 분리, 게시글·댓글·좋아요/투표·내 활동 유스케이스별 조율 |
| 서비스 INSERT/UPDATE/DELETE | entity/Post, PostComment, PostCommentReport, PostMedia, PostLike, PostPoll, PostPollOption, PostPollVote 및 JPA repository |
| 피드/댓글 트리/내 활동 SQL | repository/query 전용 조회. SQL 결과 매핑도 여기에서 수행 |
| 원자적 카운터 및 조건부 쓰기 | repository 내 명시적 연산. 조회 엔티티의 오래된 카운터를 덮어쓰지 않도록 flush/refresh 설계 |
| 커뮤니티 테스트 | domain/community로 이동, user 차단 및 시간 직렬화 테스트 import 갱신 |

엔티티는 API DTO에 의존하지 않는다. 다른 도메인 ID는 scalar로 유지하고, 기존 FK cascade를 보존한다. 스키마 변경 없이 기존 DATETIME(6)를 UTC LocalDateTime + 직접 JDBC 타입으로 매핑한다.

## 반드시 보존할 계약

- 게시글 생성은 제목/본문 원문을 보존하고 수정은 trim한다. 제목 최대 30자, 사진 최대 5개, 투표 선택지 2~5개. 파일 업로드 전 전체 입력 검증을 끝낸다.
- NEWS 작성 및 기존 NEWS 수정은 관리자만 가능하다. 소유권·존재 여부·검증의 기존 예외 우선순위를 보존한다.
- 피드: 최신 id DESC, 인기 likes_count DESC/id DESC. 검색은 Unicode code point 2~20자, LIKE 특수문자 literal 처리. 페이지 제한과 기존 cursor 형식 유지.
- 내 활동: written/liked/commented, 활동 시각 DESC/post id DESC, 댓글은 살아 있는 최신 댓글 하나를 표시. type 포함 Base64 URL cursor, 256자 제한과 동률 처리 유지.
- 차단은 조회자 → 작성자 방향이다. 차단된 게시글은 404/피드 제외. 기존 좋아요 취소는 차단 이후에도 가능하다. 차단 댓글은 내용/작성자를 숨기되 트리와 개수는 유지한다.
- 댓글: trim, 1~1000자, 1단계 답글만 허용. 댓글 작성자와 게시글 작성자가 삭제 가능. 삭제는 soft delete, 살아 있는 답글이 있는 부모는 tombstone으로 표시.
- 댓글 목록은 root id DESC, 답글은 최신 N개를 선택한 후 ASC로 표시. 부모별 ROW_NUMBER 제한과 다음 cursor를 유지한다.
- 신고: 자기 댓글 거부, OTHER 상세 필수, snapshot 보존, 중복 409. JPA 예외 변환 후에도 기존 오류 코드 유지.
- 좋아요/댓글/투표 카운터는 병행 변경을 덮어쓰지 않는다. 같은 선택지 재투표는 변경/알림 없음, 선택 변경은 이전 감소+새 선택 증가를 한 트랜잭션으로 처리.
- 게시글 삭제 flush 후 미참조 미디어를 정리한다. 알림 생성과 rollback/afterCommit 계약은 기존 notification 구현을 유지한다.
- 입력 파싱/검증은 repository AOP 밖에서 수행해 IllegalArgumentException의 HTTP 400이 500으로 변환되지 않게 한다.

## 검증 및 진행 순서

- [x] 기존 코드, 스키마 V6/V10/V17/V19/V21/V26, 호출부 및 테스트 목록 확인
- [x] 커뮤니티 기존 43개 테스트 통과
- [x] 엔티티 규칙 단위 테스트 RED → GREEN
- [x] JPA 기본 쓰기와 유스케이스 서비스 분리
- [x] SQL projection/조건부 원자 연산 repository 격리; service/controller SQL 제거
- [x] UTC, 동시성, rollback, 사진 순서, 차단/댓글 트리, cursor 회귀 보강
- [x] 관련 테스트 및 전체 backend Asia/Seoul 통과
- [x] 독립 코드 리뷰 해결
- [x] MuMu 작성/편집/삭제, 대댓글, 좋아요/투표, 차단, 내 활동/페이지 이동 및 앱 재실행
- [x] refactor : 커밋, develop PR, 최신 head의 전체 CI 통과
- [x] squash merge 후 실제 develop SHA 빌드/기동
- [x] 머지 SHA의 MuMu 재실행/전체 시나리오/공통 smoke 및 서버 로그 확인
- [x] 증적 기록 후 media 시작

현재 QA 백엔드는 머지 SHA607299e의 forced bootJar98525, 세션51889/PID22584이다. MuMu 127.0.0.1:16384, mediatest 앱, --no-uninstall, 격리 API18083/DB3318만 사용한다.

## 구현 기록

- Post, PostComment, PostCommentReport, PostLike, PostMedia, PostPoll, PostPollOption, PostPollVote를 기존 테이블에 매핑했다. 외래 키는 scalar ID이며 기존 cascade를 유지한다.
- PostService, CommentService, ReactionService, ActivityService 인터페이스/구현과 CommunityAccess를 분리했다. 기존 호출부 호환용 CommunityService는 위 서비스로 위임한다.
- PostProjectionRepository: 게시글 상세/피드/내 활동 및 미디어/투표 projection. 윈도 함수, 복합 정렬과 기존 커서/차단 조건을 보존하기 위해 JDBC를 사용한다.
- CommentProjectionRepository: 댓글 tree/tombstone/차단 마스킹과 부모별 최신 N개 답글의 ROW_NUMBER 조회. 서비스에는 타입이 있는 CommentSnapshot을 반환한다.
- PostCounterRepository: likes/comments/votes의 원자적 산술 UPDATE. 엔티티의 카운터는 updatable=false로 선언해 수정 시 이전 값으로 덮어쓰지 않는다.
- PostRelationsRepository: JPA로 미디어/투표 연결을 저장하고, 게시글 잠금, 기존 투표 변경, JPQL 좋아요 삭제를 수행한다.
- ReactionInsertRepository: 좋아요/투표의 신규 행은 JDBC INSERT 후 중복 키만 처리한다. 존재하지 않는 복합 키를 먼저 잠그면 REPEATABLE READ gap lock 때문에 서로 다른 게시글에서도 데드락이 발생함을 테스트로 확인했다. 실패한 persist가 JPA context를 오염시키는 것도 피한다. 원자적 삽입 예외이며 서비스에는 SQL이 없다.
- 신고 중복은 기존 UNIQUE 제약을 유지한다. 일반 중복은 사전 조회, 경합 시 MySQL 1062만 기존 409로 변환한다. 다른 무결성 오류를 중복으로 숨기지 않는다.
- 커서 숫자 파싱은 서비스에서 수행한다. 댓글 조회의 잘못된 페이지 인자는 동일한 400/detail을 갖는 InvalidInputException으로 반환해 repository 예외 변환으로 500이 되지 않게 한다.

## 검증 기록

### 조회 비용 및 인덱스 점검

- develop의 CommunityService와 전환 후 PostProjectionRepository를 비교했다. 피드/내 활동의 사진·투표 projection은 동일하게 게시글마다 추가 조회하며 새 ORM 연관 lazy load는 없다. 피드 본문 1회 + 게시글당 미디어/투표 2회 + 투표가 있는 글당 선택지 1회(인증 조회 별도)이다. 기존 N+1 형태는 이번 저장 방식 전환에서 그대로 유지하며 배치 조회 개선을 완료했다고 주장하지 않는다.
- 격리 MySQL의 대표 predicate EXPLAIN: 최신 피드는 idx_post_id_desc, 사진 순서는 idx_post_media_order, 투표는 post_id unique, 댓글은 idx_post_comment_cursor를 사용했다. 테스트 데이터가 적으므로 운영 규모 실행시간의 증거는 아니다. WHERE/커서/정렬은 기존 쿼리와 동일하게 보존했다.
- 반응 결과에만 current read를 적용했으며 일반 목록에 잠금을 추가하지 않았다. 새 엔티티는 scalar FK를 사용해 연관 그래프의 의도하지 않은 조회를 방지한다.

- 4281: 게시글 JPA CRUD 및 stale-counter 회귀 포함 55개 성공, 2분 46초.
- 83705: 댓글 JPA와 패키지 이동 회귀 성공, 2분 15초.
- 67583: 게시글 projection 분리와 malformed cursor 400 회귀 성공, 2분 18초.
- 86967: 관계 엔티티와 댓글 projection 포함 67개 성공, 2분 23초.
- 73108: 서비스 책임 분리 및 신고 JPA 회귀 성공, 2분 10초.
- 독립 리뷰: 동일 선택지 동시 투표의 두 번째 요청이 잠금 전 REPEATABLE READ snapshot으로 응답할 수 있다는 P2 발견. 다른 확정 지적 없음.
- 4077: 실제 MySQL 병렬 트랜잭션 7개 중 동일 선택지 응답 검증 1개 실패, 나머지 6개 성공. reviewer 지적 재현. 일반 상태 검사만으로는 발견되지 않으므로 각 응답의 votedByMe/votesCount를 검사한다.
- 수정: 반응 응답에만 명시적 FOR SHARE current-read projection을 사용하고, EXISTS 대신 JOIN으로 좋아요/투표 상태도 같은 current read에 포함. 일반 피드는 기존 읽기 트랜잭션 유지.
- 45569: 동일 투표 응답 회귀는 통과했으나 서로 다른 게시글의 좋아요 INSERT에서 데드락을 재현했다. ReactionInsertRepository로 없는 행의 선행 잠금 조회를 제거했다.
- 98507: 위 수정 후 커뮤니티/차단/시간 직렬화 선별 테스트 성공, 2분 16초. 독립 재리뷰에서 미해결 지적 없음.
- 이후 독립 투표 동시 실행, 차단 이후 기존 좋아요 취소 및 새 좋아요 rollback 테스트를 추가했다. 33514 전체 회귀 432개 중 TimeModelTest 문자열 클래스 경로 1개만 실패(7분44초). 동시성10개는 성공. 경로 수정 후74498 재실행 도중 최종 패키지 정리를 반영하기 위해 중단하고79200으로 전체 재실행 중이다.
- 계획의 공통 구조에 맞춰 dto/request,response와 repository/query,jdbc로 세분화하고 import/리플렉션 문자열을 함께 갱신했다. 업무 로직 변경 없음.
- bootJar 17029 성공 28초. 커뮤니티 QA 서버 49846/PID12004, 포트18083, 스키마43 정상 기동. 최종 패키지 이동 전 빌드이므로 최종 gate에는 재빌드가 필요하다.
- MuMu62021: 게시글 생성 후 동일 key를 내부 위젯에도 전달하는 UI 구조 때문에 테스트 finder 중복 실패. 바깥 컨트롤 선택으로 테스트를 수정했다.
- MuMu18676: 게시글 작성/수정, 좋아요, 투표 변경, 댓글/답글/수정/삭제 표시를 통과한 뒤 메모리 XFile의 확장자 누락으로 사진 업로드400. 실제 PNG 파일을 저장해 업로드하도록 테스트를 수정했고40213 재실행 중이다.
- 테스트는 별도 게시글의 부모22개/답글21개 페이지 이동, 독립 HTTP 계정의 중복 신고409, 화면에서 작성자 차단 및 댓글 마스킹도 검증한다. 독립 리뷰에서 테스트의 API/기대값 문제 없음. 최종 전체 성공과 재실행 보존 검증은 아직 미완료다.
- MuMu40213의 lazy finder 조기 평가를 수정한62156은 페이지 이동/차단/신고 전체를 통과했다. 마지막 댓글 재조회에서 테스트가 같은 댓글 route의 postId만 교체해 기존 화면 상태가 재사용되었다. 기존 CommunityCommentsScreen은 didUpdateWidget이 없으며 이번 Java 변경 범위 밖이므로, 실제 사용자 흐름인 상세 → 댓글 열기로 테스트를 변경했다. 직접 route 교체의 이 제한은 해결했다고 주장하지 않는다.
- MuMu11060은 수정된 실제 진입 흐름으로 재실행 보존 검증 성공(8초): 저장된 인증/게시글/좋아요/투표/삭제 부모 및 답글/사진 실제 디코딩. 전체 시나리오82173과 backend79200은 실행 중이다.
- 최종 결과: backend79200 성공9분13초, XML432 tests/0 failures/0 errors/0 skipped(Asia/Seoul). MuMu82173 전체 성공1분2초, COMMUNITY_PAGINATION_BLOCK_REPORT_VERIFIED 및 COMMUNITY_UI_VERIFIED. 재실행11060 성공8초. Flutter analyze46233 성공15.1초. 최종 패키지 이동 재리뷰도 미해결 지적 없음. 서버50305 요청 오류 로그 없음. PR/CI/머지 및 머지 후 MuMu는 별도 미완료 단계다.
- PR103 검증 head의 push38787205507와 PR38787282793 모두 backend/Flutter/monitoring 성공(6개). GitHub 리뷰 지적 없음. squash merge607299e를 fetch 및 UI로 확인했다. 이전 QA50305 종료, 머지 SHA forced bootJar98525 실행 중. develop CI38787977229와 머지 후 MuMu는 아직 진행 단계다.
- 머지 SHA forced bootJar98525 성공43초, QA51889/PID22584 health200/schema43. develop CI38787977229 전체3개 성공. 머지 후 MuMu 기존 데이터52727 성공7초, 전체31940 성공1분2초. 공통 android_ux17980 진행 중이며 마지막 gate와 서버 로그 확인 후 완료 처리한다.
- 공통 android_ux17980 성공50초: 주요18개 화면, 지출 저장/실패/재시도 검증. 서버51889 요청 오류 로그 없음. 커뮤니티 전환의 모든 gate 완료. 다음 도메인은 최신 develop607299e 기준 media이다.

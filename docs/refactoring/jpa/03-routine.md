# 03 루틴 및 돌봄 일정 전환

상태: 구현·전체 backend·독립 리뷰·MuMu 첫 실행 통과, 재실행 및 PR 검증 진행. 기준 develop 0de22531e3148069c1f5e279bb09f54292fd2ec0.
브랜치: refactor/jpa-routine.

## 설계 계약
- routine 패키지를 domain/routine 아래 controller, dto/request, dto/response, entity, repository, service 및 service/impl로 이동한다.
- Routine, RoutineCompletion, CareSchedule을 기존 테이블에 매핑한다. 스키마/API 변경 없이 CRUD는 JPA를 사용한다.
- 완료 처리는 UNIQUE(routine_id, scheduled_date)의 원자적 upsert와 INSERT IGNORE를 전용 Repository에 유지한다. activity_record_id를 덮어쓰지 않는다.
- 반복 날짜 판단은 기존 시작일 기준 주/월 계산을 유지한다. 월말 보정, 시간별 완료 분리 등 기능 변경은 하지 않는다.
- 돌봄 일정의 사용자 존재 → 펫 존재 → 소유권 → 삭제 여부 오류 순서와 루틴의 기존 접근 거부 계약을 각각 보존한다.
- 돌봄 목록은 날짜, 시간이 있는 행 우선, 시간, ID 순서. TIME은 JVM 시간대 변환 없이 직접 LocalTime JDBC 매핑하고 저장 후 DB 정밀도로 재조회한다.
- 돌봄 생성 시 created_at은 DB 기본값, 수정 시 updated_at은 기존 UTC 저장 방식 유지. 알림 삭제의 트랜잭션과 호출 순서 유지.
- 반복 규칙, 완료 상태 및 일정 값 정규화는 HTTP DTO에 의존하지 않는 도메인 모델에 둔다.

## 검증 계획
- [x] 기존 RoutineIntegrationTest/CareScheduleIntegrationTest 기준선: 56096, 1분27초 성공
- [x] 엔티티 반복 규칙/일정 정규화 RED → GREEN
- [ ] JPA CRUD/정렬/UTC 및 Seoul 시간/알림 삭제/완료 중복/레코드 연결 회귀
- [x] 전체 backend 회귀 및 독립 코드 리뷰
- [ ] MuMu 반복 목록, 완료/취소/건너뜀, 일정 등록/수정/삭제 및 재실행
- [ ] PR 최신 head CI, develop 머지, 실제 머지 SHA 재빌드 및 MuMu

현재 돌봄 엔티티 테스트35323 RED 실행 중. 운영 소스 변경 전.
- 돌봄 엔티티 RED35323 대상 클래스 부재 확인 후 JPA CRUD 구현. GREEN34820 Asia/Seoul 성공(1분40초). 후속86384에서 legacy UTC/time/NULL 정렬 및 TimeModelTest 포함 재검사 중. 반복 RoutineService는 아직 이전 구현이며 PR 전 전체 전환 필요.
- Care 후속86384 성공(1분47초). RoutineTest RED48351 클래스 부재 확인 후 Routine/RoutineCompletion 모델 및 JPA Repository 구현. 완료 upsert는 원래 JdbcTemplate LocalDateTime 바인딩을 보존하며 flush 후 native 변경, clear 후 JPA 재조회한다. 독립 pet_review 소스 리뷰에서 actionable finding 없음. GREEN26297 진행 중; 이후 추가 완료 상태/UTC/기록 연결 테스트 포함 재실행 필요.
- 루틴 대상 GREEN26297 성공(1분48초), 31개 테스트 실패0. Service/controller 직접 SQL 검색 결과 없음. 추가 완료/UTC/기록 연결 테스트를 포함한 전체 backend46283 Asia/Seoul 실행 중. UI 서버는 아직 이전 pet 머지 SHA이므로 루틴 MuMu 전 재빌드·기동 필요.
- MuMu 시나리오 추가 및 정적 분석37349 통과. 화면에서 루틴/일정 등록·수정·삭제 취소/확정, 반복 목록·상세를 확인한다. 완료·취소·건너뜀은 현재 UI 컨트롤이 없어 MuMu의 앱 서비스/API로 검증하며 UI 버튼 검증으로 표기하지 않는다. 저장된 시작일로 조회해 재실행 날짜 변화에 독립적이다. 읽기 전용 테스트 리뷰 지적 없음. bootJar82842 성공, 서버17438/PID36936/18083 및 schema43 확인. MuMu44282 진행 중.
- 전체 backend46283: Asia/Seoul 394개 테스트, 실패/오류/skip 0, 7분44초 성공. MuMu44282는 없는 water 카테고리 선택자로 실패하여 meal로 수정. 17371은 CRUD/API/저장값 검사를 지나 lazy 상세 버튼 대기에서 실패하여 표시된 제목과 시간 스크롤 검사로 수정. 제품 변경 없음. 재실행89253 진행 중.
- MuMu89253 ROUTINE_UI_VERIFIED31초 통과, analyzer48887 성공. 새 프로세스98457 VERIFY_EXISTING_ROUTINE=true 검증 중. 서버17438 요청 오류 없음. 기준 develop0de2253 변경 없음.
- 재실행98457 ROUTINE_RESTART_VERIFIED7초 통과. 앱 데이터 보존, 신규 fixture 생성 없이 기존 로그인/반복 루틴/완료 summary/시간/종일 일정·장소·메모/화면 상세를 검증했다. PR CI 및 실제 머지 SHA MuMu는 별도 미완료.

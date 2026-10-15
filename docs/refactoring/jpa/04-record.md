# 활동 기록 JPA 전환 Implementation Plan

> 실행: superpowers:executing-plans. 사용자가 전체 순차 실행을 승인했으므로 동일한 PR/검증 절차로 진행한다.

**Goal:** 활동 기록 9개 유형과 상세 테이블 7개를 domain/record의 JPA 모델로 전환한다.
**Architecture:** ActivityRecord와 각 상세 모델은 기존 테이블을 그대로 사용한다. Service는 권한과 트랜잭션을 조율하고 Repository가 영속화를 맡는다.
**Tech Stack:** Java21, Spring Data JPA, Hibernate6.6.53, MySQL8, Flutter/MuMu.
**Spec:** plan.md의 전역 제약 및 record 행.
**Base:** c54556879aa4589d014c9d5ac70fd563de70d80c, refactor/jpa-record.

## 계약과 Review Focus

- typeId는 meal/water/medicine/poop/walk/weight/vet/diary/etc. 타입 변경 기능은 추가하지 않는다.
- 수정 시 null date/time/routineId/note는 기존 값 보존, 빈 note는 지우기. detail 생략은 보존, 제공한 detail은 전체 교체하며 빠진 상세 필드는 null.
- 목록은 date DESC, id DESC. time으로 정렬하지 않는다. 날짜/유형/limit 필터 및 빈 유형 처리 유지.
- LocalTime 직접 JDBC 매핑, createdAt/updatedAt UTC LocalDateTime 직접 매핑. 저장 응답은 flush/refresh하여 DB TIME/DECIMAL 정밀도와 일치시킨다.
- 기존 사용자→펫 소유권 확인, 기록 존재→루틴 소유권 확인 순서 유지. 삭제는 미디어 정리 후 기록 삭제와 flush. FK cascade 및 completion.activity_record_id SET NULL 유지.
- 숫자 문자열 BigDecimal, Number.intValue(), 문자열 toString, 날짜 ISO parsing의 기존 상세 변환 유지. 삭제된 공간 필드와 알 수 없는 키는 저장·반환하지 않는다.
- 상세 행 없는 legacy 기록은 빈 detail. diary/etc도 빈 detail. null 상세 열은 응답에 기존 키와 null 유지.
- 목록 조회는 유형별 상세 일괄 조회와 미디어 일괄 조회로 건수에 비례한 쿼리 증가를 피한다. 상세 행의 스칼라 recordId를 사용한다.

## 파일 구조

기존 backend/src/main/java/com/formypet/record를 domain/record로 이동한다.
- controller/ActivityRecordController.java: 기존 API/멱등성 유지.
- dto/request/ActivityRecordCreateRequest.java, ActivityRecordUpdateRequest.java; dto/response/ActivityRecordResponse.java.
- entity/ActivityRecord.java: create(petId,typeId,date,time,routineId,note), update(date,time,routineId,note), validateType(typeId).
- entity/detail/{Meal,Water,Medicine,Poop,Walk,Weight,Vet}RecordDetail.java: 기존 열 매핑, from(recordId,Map), toMap(). 공통 DetailValues가 변환을 담당한다. RecordDetail.from은 타입별 모델을 만들며 Repository 프록시 밖에서 실행하여 기존 입력 오류 응답을 보존한다.
- repository/ActivityRecordRepository.java: JpaRepository, 동적 목록 fragment, refresh fragment.
- repository/RecordDetailRepository.java: EntityManager 기반 상세 replace(RecordDetail) 및 batch 조회. 기존 행은 merge로 전체 필드 교체, 없는 행은 생성한다.
- repository/RecordMediaQueryRepository.java: media_resources의 id/record_id만 조회하는 전용 SQL. 미디어 도메인 아직 미전환이므로 소유권/삭제는 기존 MediaService 유지.
- service/ActivityRecordService.java, service/impl/ActivityRecordServiceImpl.java: 기존 5개 public 메서드 계약. 루틴 확인은 RoutineRepository 사용.
- 테스트는 backend/src/test/java/com/formypet/domain/record 및 entity 하위.

## 실행 단계

- [x] 기준선23912: gradlew test --tests com.formypet.record.* --no-daemon 성공 확인.
- [x] ActivityRecordTest에 null 보존/빈 메모/타입 거부/UTC 생성 시간 테스트 작성, 없는 모델로 RED 확인.
- [x] ActivityRecord 및 상세 모델 구현. DetailValuesTest로 숫자/날짜/null/미지원 키 변환 확인.
- [x] 패키지 이동 및 JPA CRUD·동적 목록·상세 batch·미디어 projection 구현. 서비스 직접 SQL 제거.
- [x] 기존 통합 테스트 이동. 모든 유형 create/update/detail 누락·빈값, DECIMAL 반올림, TIME(0), UTC legacy read/update, 동률 정렬/limit, 삭제 cascade/completion/미디어, 롤백/타인·삭제 펫 거부 추가.
- [x] gradlew test --tests com.formypet.domain.record.* -PtestTimezone=Asia/Seoul --no-daemon 통과 후 전체 backend test.
- [x] 독립 리뷰, 화면 쿼리 수 확인, flutter 정적 분석. 수정 후 영향 테스트 재실행.
- [x] MuMu record_migration_test.dart: 9유형 등록/수정/조회/삭제, 사진 첨부·삭제, 루틴 연결 및 삭제 상태, 필터·상세·재실행. 화면 없는 연결 상태는 API/DB 증적 구분.
- [x] refactor : 활동 기록 도메인 JPA 전환 커밋/push, develop PR 생성·첨부, 최신 head 전체 CI·리뷰 후 squash.
- [x] 실제 merge SHA forced build/서버 교체, MuMu existing→full→common, develop CI와 서버 로그 확인 후 완료 기록.

## 증적

현재 기준선23912 실행 중. 구현 전.
- 기준선23912 성공1분31초. ActivityRecordTest RED24225 클래스 부재 확인. 기본 엔티티 구현 후 GREEN78573 Asia/Seoul에서 기존 통합 테스트와 함께 실행 중. 서비스/상세 테이블 전환은 아직 미완료.
- GREEN78573 기본 모델/기존 통합 성공1분49초. 상세 모델 RED85942 확인 후 JPA 상세7개, 목록 fragment, batch 조회, Service 인터페이스/구현 이동 완료. GREEN45421 실행 중. 서비스/컨트롤러 직접 SQL 및 이전 record 패키지 참조 검색 결과 없음. 추가 회귀4개 재실행 필요, pet_review 독립 리뷰 요청.

- 집중 테스트26307(record+MediaIntegration) 성공1분58초. 독립 source 리뷰 무결함. 전체 backend12608 실행 중. MuMu5277은 lazy Sliver 하단 버튼 대기 실패로 테스트 reveal 수정; 재실행30676 중. 테스트 리뷰의 응답 키 및 미노출 completion link assertion 수정 반영.
- 롤백 테스트71007 RED(숫자 변환 Repository 예외 번역으로400→500) 확인. 타입별 상세 생성 factory를 도메인 모델로 옮겨 서비스 트랜잭션 내에서 Repository 호출 전에 평가. GREEN87291 기록35개 통과. 독립 재리뷰 무결함. 수정 후 전체75394 실행 중.
- MuMu23406 성공3분57초: 9유형 화면 등록/수정/상세/삭제 취소·확정, API 필터/limit/루틴 상태, 사진 업로드·실제 decode·삭제. 재실행6054 진행 중. analyzer13274 clean.
- MuMu 재실행6054 성공7초: 기존 계정/기록/이미지 보존 확인. 최종 전체75394 결과 대기 후 PR.
- 최종 전체75394 성공7분48초:408 tests/0 failures/0 errors/0 skipped (Asia/Seoul). PR 전 검증 완료. 머지 후 검증은 별도 진행.

- PR #102 head9d8b0e6의 push/PR 검사6개 통과 후 squash509bb551af7e7d0f3a2855fe9e688f340acc2462. 테스트 head와 tree 동일. 머지 버전 forced build34379 성공44초, 서버9473/PID1916/18083. 기존 데이터 MuMu81885 성공8초, develop CI3개 성공. 전체1325 실행 중이며 공통 검증은 다음 단계.

## 최종 완료
- PR #102 squash509bb55. 머지 버전 기존 데이터81885(8초), 전체 기록1325(3분56초), 공통5776(51초) 모두 통과.
- develop CI run38777175987의3개 검사 성공. 서버9473 로그 요청 오류 없음. 기록 단계 완료.

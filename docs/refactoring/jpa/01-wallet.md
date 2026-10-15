# 01 Wallet 전환 상세 체크리스트

상태: 구현·독립 리뷰·브랜치 MuMu 검증 완료. PR #99 최종 CI 및 머지 대기.

## 파일 매핑
- wallet/WalletExpenseController.java → domain/wallet/controller/WalletExpenseController.java
- wallet/WalletExpenseService.java → domain/wallet/service/WalletExpenseService.java 인터페이스 및 service/impl/WalletExpenseServiceImpl.java
- wallet/dto/*Request.java → domain/wallet/dto/request/
- wallet/dto/*Response.java 및 WalletExpenseCategorySummary.java → domain/wallet/dto/response/
- 추가 entity/WalletExpense.java: 기존 wallet_expenses 테이블 매핑. userId/petId는 스칼라 참조. created_at/updated_at은 기존 DB 생성/갱신 의미 유지.
- 추가 repository/WalletExpenseRepository.java: JpaRepository, findByIdAndPetId 기반 CRUD.
- 추가 repository/query/WalletExpenseQueryRepository.java: 필터·커서·통계. DB 행 매핑은 이 계층에서 처리.
- 추가 repository/query/WalletPetAccessRepository.java: 현재 pets 삭제 상태와 사용자 존재 여부를 읽는 projection. 기존 PetRepository의 soft-delete 필터로 오류 우선순위가 바뀌지 않도록 유지.
- 이동 test wallet/WalletExpenseIntegrationTest.java → domain/wallet/WalletExpenseIntegrationTest.java. 다른 테스트의 import 참조도 검색.

## 계약
- API 경로 /api/v1/pets/{petId}/wallet/expenses 유지.
- Service 공개 create/list/summary/get/update/delete 매개변수 및 응답 구조 유지.
- 다른 도메인 테이블 수정/패키지 이동 없음. 후속 pet 단계에서 접근 계약 통합 여부 검토.
- amount 1..999999999, KRW 기본값/제한, 기존 7개 category 및 nullable text trim 규칙은 엔티티 생성/변경 경로에서 일관되게 적용.
- 지출 목록 expense_date DESC, NULL 시간 후순위, expense_time DESC, id DESC 유지.
- 읽기 조회와 JPA 쓰기 사이 flush를 명시적으로 고려. create/update는 Repository에서 flush/refresh 후 엔티티로 응답을 구성해 DB TIME(0) 정밀도를 유지한다.
- LocalTimeJdbcType으로 JVM Asia/Seoul에서도 기존 JDBC의 시각 의미를 유지한다.

## 검증
- [x] 기존 WalletExpenseIntegrationTest 12개와 전체 backend 기준선 통과.
- [x] 새 엔티티 규칙 테스트: 기본 KRW, 잘못된 통화/분류/금액 거부, 텍스트 정리, 수정 시 null로 비우기.
- [x] 기존 API CRUD/통계/기간·분류 필터/에러 코드 테스트 유지.
- [x] 동일 날짜·시간 및 NULL 시간이 섞인 페이지 경계에서 중복/누락 없음.
- [x] 타인 펫, 삭제 펫, 존재하지 않는 지출의 기존 오류 응답 유지.
- [x] 실제 커밋 후 새 트랜잭션에서 수정/삭제 결과 재조회 (기존 테스트는 @Transactional이므로 별도 확인 필요).
- [x] Asia/Seoul에서 JDBC 기존 행과 JPA 생성/수정의 시각·정밀도 회귀 검증 (session 36238).
- [ ] 전체 backend 및 CI 통과.
- [x] 브랜치 MuMu 등록/수정/삭제/필터/통계 및 재실행 데이터 유지 확인.
- [ ] develop PR 리뷰·검사·머지.
- [ ] 머지 SHA 백엔드의 MuMu 동일 시나리오와 앱 재실행 후 저장 결과 확인.

## 환경 기록
Docker 로그에서 sailor-ingest.sock rename/access 실패 확인. 자동 승인 검토가 프로세스 종료·소켓 제거·재시작 작업을 거부하여 해당 복구 작업을 수행하지 않음. 사용자에게 Docker 정상 기동 요청. 대체 경로로 이 거부를 우회하지 않는다.

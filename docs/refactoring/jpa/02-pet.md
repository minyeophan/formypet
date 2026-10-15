# 02 반려동물 전환

상태: 완료. PR #100 develop 머지 및 머지 SHA MuMu 검증 완료. 기준 develop e482cf28bd9bbc9f7ab7ea4821bc7715b341d434.
브랜치: refactor/jpa-pet. 이전 wallet PR #99 머지 후 검증 완료.

## 변경 계약
- pet/PetController → domain/pet/controller, PetService → service 인터페이스 + service/impl 구현.
- pet/domain → domain/pet/entity, dto → dto/request 및 dto/response. StrictBigDecimalDeserializer는 request에 배치.
- PetRepository의 JPA CRUD와 soft-delete SQLRestriction 유지. 다른 도메인은 import만 변경.
- HTTP 경로/JSON/오류 우선순위/트랜잭션/소유권/삭제 시 미디어 정리 호출 순서 유지.
- 대표 사진 조회 SQL은 repository/query/PetProfileImageQueryRepository로 이동. STORED/PET_PROFILE/record_id IS NULL 및 created_at DESC,id DESC 유지.
- 생일 미상=true는 날짜 제거, 날짜 생략은 유지. species 생략 및 색상 blank는 기존 값 유지. 나머지 nullable 프로필 필드는 생략 시 null이라는 기존 PUT 의미 유지.
- 색상 기본값 순환과 변경 규칙을 엔티티에 두고 HTTP DTO 의존은 만들지 않는다.
- wallet 접근 정책은 별도 유지: wallet은 삭제된 행도 읽고 NOT_FOUND/FORBIDDEN 오류를 구분한다. Pet의 SQLRestriction과 403 정책으로 통일하면 API 계약이 바뀐다.
- 기존 사진 조회 횟수는 이번 추출에서 증가시키지 않는다. 기본 CRUD는 이미 JPA이므로 중복 모델/스키마 변경 없음.

## 검증
- [x] PetIntegrationTest/PetWeightDeserializerTest 기준선
- [x] 엔티티 생일·색상 규칙 테스트
- [x] 이동 후 pet/wallet/media 연계 및 전체 backend 회귀
- [x] 독립 코드 리뷰 및 PR CI
- [x] MuMu 등록/수정/삭제/사진/생일 미상/체중/wallet 연계
- [x] develop 머지 후 동일 SHA 실행·MuMu·재실행 확인

## 현재 증적
- 기준선52790 성공, 새 엔티티 테스트 RED85055(대상 패키지 부재), GREEN72206(pet/wallet) 성공.
- bootJar10106 성공. pet 구현 서버61430/PID19968/18083, health 성공. 전용 DB3318/schema43.
- 독립 리뷰 pet_review: 백엔드 동작 비교에서 actionable finding 없음. CI 및 MuMu는 별도 확인 필요.
- 전체13426에서 TimeModelTest의 부분 클래스명 문자열 pet.domain.Pet이 ClassNotFoundException 발생. domain.pet.entity.Pet으로 갱신했고 전체 실행 종료 후 재검증 예정.
- 새 MuMu 시나리오 정적 분석49858 성공. 별도 패키지·DB 가드, 등록/수정/삭제 취소·확정/생일 미상/체중 보존/사진 표시/wallet 연결/재실행 확인. 사진은 업로드 API와 렌더링을 검사하며 네이티브 사진 선택기 검증을 의미하지 않는다.
- MuMu72968: PET_UI_VERIFIED, 27초 통과. 재실행17364: PET_RESTART_VERIFIED, 12초 통과. --no-uninstall로 앱 데이터 보존, 기존 모드는 fixture 생성 없이 로그인/프로필/사진/연결 지출 조회 검증. 최종 정적 분석28531 성공.
- 전체 재검사42692: BUILD SUCCESSFUL, 12분14초. 기존 클래스명 문자열 수정까지 포함. 서버61430의 MuMu 요청 오류 없음. PR CI와 머지된 SHA의 재검증은 아직 미완료.
- PR #100 생성, 최초 head6a45ba0. 최종 테스트 리뷰의 P3 반영: 사진 위젯 존재 대신 RawImage.image 비-null로 디코딩 성공까지 검사. 보강 후 MuMu90256 PET_UI_VERIFIED18초, 정적 분석55706 성공.
- 보강 후 재실행7073 PET_RESTART_VERIFIED5초 통과. 리뷰어 P3 해소 확인, 잔여 지적 없음.

- 최종 head b4d0f7d CI 6개 통과 후 PR #100 squash merge. 머지 SHA 0de22531e3148069c1f5e279bb09f54292fd2ec0, 테스트 head와 소스 트리 동일.
- 머지 SHA bootJar19872 강제 빌드 성공(42초), 서버31441/PID25092/18083, DB3318/schema43. 기존 데이터 재실행80247 PET_RESTART_VERIFIED6초 통과. 전체 UI64471 및 공통 smoke/develop CI 진행 예정.
- 최종 머지 후 증적: 기존 데이터80247(6초), 전체 반려동물64471(18초), 공통 화면·지출 CRUD40091(51초) 모두 통과. develop CI 3개 성공. 서버31441 요청 오류 없음. 다음: routine.

# 백엔드 상태

## 현재 구현

| 영역 | 상태 | 범위 |
| --- | --- | --- |
| 인증 | 완료 | 이메일 인증, JWT, OAuth 로그인, refresh token rotation |
| 사용자·반려동물 | 완료 | 프로필, 반려동물 CRUD, 프로필 미디어 |
| 활동 기록 | 완료 | 지원 기록 타입 생성·조회·수정·삭제 |
| 루틴·일정 | 완료 | 루틴, 완료 체크, care schedule CRUD |
| 커뮤니티 | 완료 | 게시글, 이미지, 좋아요, 투표, 댓글·답글, 신고 |
| 지갑 | 완료 | 지출 CRUD, 목록 cursor, 요약 |
| 미디어 | 완료 | 로컬 저장, 접근 제어, 정리 처리 |
| 인앱 알림 | 완료 | API, 댓글·답글·좋아요·최초 투표 이벤트, 30일 보존 |

## 보류 범위

- 외부 푸시와 예약 발송
- 알림 Flutter UI 연동
- 루틴 수정 UI 진입
- 지도 검색

## 데이터베이스

- Flyway migration 최신 버전: `V22`
- V22: `notifications` 테이블 및 recipient cursor/unread 인덱스
- 기존 migration 파일은 수정하지 않고 다음 버전 migration을 추가한다.

## 검증

```powershell
cd backend
.\gradlew.bat test --tests com.petyilgi.support.FlywayMigrationTest
.\gradlew.bat test
```

통합 테스트는 Testcontainers와 Docker Desktop이 실행 중이어야 한다.

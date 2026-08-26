# 프론트엔드 상태

## 현재 구현

Flutter 앱은 인증, 홈, 반려동물, 활동 기록, 루틴·일정, 커뮤니티, 지갑, My 화면을 제공한다. 백엔드 API가 연결된 핵심 CRUD 흐름은 동작하며, 공통 토큰·헤더·입력 위젯과 Riverpod 상태 관리를 사용한다.

| 영역 | 상태 | 비고 |
| --- | --- | --- |
| 인증·온보딩 | 연동 | 로그인, 회원가입, OAuth, 펫 등록 |
| 홈 | V2 완료 | 요약, 빠른 진입, 최근 활동 |
| 반려동물 | 연동 | 목록, 상세, 등록·수정, 이미지 |
| 활동 기록 | 연동 | 목록, 생성, 상세, 수정·삭제 |
| 루틴·일정 | 연동 | 생성, 완료, 일정 CRUD; 루틴 수정 진입은 보류 |
| 커뮤니티 | 연동 | 피드, 카테고리, 상세, 작성, 댓글·답글 |
| 지갑 | 연동 | 요약, 리포트, 지출 CRUD |
| My·정보 화면 | 부분 | 프로필, 설정, 정책·공지·고객지원 |
| 알림 UI | 보류 | 백엔드만 완료; 별도 요청 전 진행하지 않음 |

## 보류 범위

- Flutter 알림 목록 UI
- 외부 푸시·예약 발송
- 루틴 수정 UI
- 지도 검색
- 화면 전체 V2 polish와 수동 반응형 회귀

## 라우팅

주요 경로는 `/home`, `/community`, `/community/posts/:postId`, `/my`, `/records`, `/wallet`, `/routine`, `/pet/:id`이다. `/records/all`은 `/records`로 이동하는 호환 redirect다.

## 검증

```powershell
cd frontend
flutter test
flutter analyze --no-fatal-infos
```

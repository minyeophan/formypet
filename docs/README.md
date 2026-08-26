# Documentation

이 폴더는 현재 프로젝트 구조와 구현 상태를 빠르게 확인하기 위한 문서 모음이다.

## 주요 문서

- `ARCHITECTURE.md`: Flutter 앱 구조, 라우팅, 상태 관리, 데이터 흐름
- `BACKEND_STATUS.md`: 백엔드 도메인·migration·검증 상태
- `FRONTEND_STATUS.md`: 프론트엔드 화면·API 연동·보류 범위
- `NOTIFICATIONS_STATUS.md`: 인앱 알림 구현 및 보류 범위

## 참고 문서

- `ERD.md`: 데이터 모델 참고 자료
- `BACKEND_RULES.md`: 백엔드 migration·테스트 규칙
- `backend-roadmap/`: 과거 설계·구현 계획 및 검증 기록
- `superpowers/specs/`: 작업별 진단·설계 기록

## 검증 스크립트

한글 UI 텍스트와 Markdown 문서의 인코딩 회귀를 막기 위해 루트의 `scripts/check-korean-mojibake.ps1`를 사용한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1
```

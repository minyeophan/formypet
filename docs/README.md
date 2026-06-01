# Documentation

이 폴더는 프로젝트 구조, API 연동 상태, 개발 규칙을 빠르게 확인하기 위한 문서 모음이다.

## 주요 문서

- `ARCHITECTURE.md`: Flutter 앱 구조, 라우팅, 상태 관리, 데이터 흐름 정리
- `FRONTEND_STATUS.md`: 프론트엔드 기능 구현 현황과 백엔드 API 연동 상태
- `CONTEXT.md`: 현재 작업 상태와 최근 검증 기록
- `BACKEND_RULES.md`: 백엔드 작업 시 지켜야 할 마이그레이션, 테스트, API 규칙
- `ERD.md`, `ADR.md`: 데이터 모델과 주요 기술 결정 기록

## 작업 보조 문서

- `AI_WORKFLOW.md`, `AI_MISTAKES.md`는 AI 보조 개발을 사용할 때 작업 범위와 검증 절차를 일관되게 유지하기 위한 내부 운영 문서다.
- `AGENTS.md`는 저장소 루트에서 AI 작업자가 세션 시작 시 읽는 라우터 역할을 한다.

## 검증 스크립트

한글 UI 텍스트와 Markdown 문서의 인코딩 회귀를 막기 위해 루트의 `scripts/check-korean-mojibake.ps1`를 사용한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1
```

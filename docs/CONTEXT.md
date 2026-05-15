# 현재 컨텍스트

## 5줄 현황 요약

1. 현재 상태: Flutter 마이그레이션 완료. `frontend/`는 React Native → Flutter (Riverpod + go_router)로 전환됐다.
2. 마지막 확인된 전체 검증: 2026-05-15 `flutter analyze --no-fatal-infos` Exit 0, `flutter build web` 성공 (√ Built build/web).
3. 최신 스키마: Flyway `V1`부터 `V10__extend_community_posts.sql`까지 존재한다. 기존 마이그레이션은 수정하지 않는다.
4. 최근 변경 흐름: React Native 전체 삭제 → Flutter 프로젝트 생성 → 모든 화면/상태/API 레이어 구현.
5. 다음 우선순위: Android 에뮬레이터 또는 기기에서 백엔드 실행 후 수동 E2E 검증 (회원가입, 펫 등록, 기록 CRUD, 루틴, 커뮤니티).

## 마지막 검증

- 백엔드 전체 테스트: 2026-05-10 `./gradlew.bat test` GREEN 기록.
- 프론트 정적 분석: 2026-05-15 `flutter analyze --no-fatal-infos` Exit 0 (info 4건만, 경고/오류 없음).
- 프론트 웹 빌드: 2026-05-15 `flutter build web` → `√ Built build/web` 성공.
- 한글 깨짐 검사: 2026-05-10 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN 기록.

## 다음 행동

- 문서 정리 작업이면 `AGENTS.md`, `docs/AI_WORKFLOW.md`, `docs/BACKEND_RULES.md`, `docs/AI_MISTAKES.md` 기준을 우선 확인한다.
- 백엔드 작업이면 `docs/BACKEND_RULES.md`와 `docs/FRONTEND_STATUS.md`를 읽고 TDD 순서를 따른다.
- Flutter UI 작업이면 `DESIGN.md`를 먼저 읽고 디자인 시스템 준수 여부를 성공 기준에 포함한다.
- 앱 검증 작업이면 백엔드(`./gradlew.bat bootRun`)와 Flutter(`flutter run`)를 함께 실행한 뒤 회원가입/로그인, 펫 온보딩, 기록 CRUD, 루틴 CRUD, 커뮤니티 피드/좋아요, 배변 사진 업로드/표시, 로그아웃 후 재진입을 확인한다.

## 주의사항

- `backend/src/main/resources/db/migration/V1`부터 `V10`까지 기존 Flyway 파일은 수정하지 않는다.
- 새 DB 변경은 다음 번호의 새 마이그레이션으로만 추가한다.
- 문서 정리만 하는 작업에서는 `backend/`, `frontend/`, `DESIGN.md`를 수정하지 않는다.
- 기존 dirty worktree 변경은 사용자 또는 이전 작업자의 작업으로 보고 되돌리지 않는다.
- Windows 콘솔의 기본 출력만 보고 한글 파일이 깨졌다고 판단하지 않는다.
- 한글 문서를 편집한 뒤에는 한글 깨짐 검사를 실행한다.
- 배포, S3, MinIO, LocalStack, 도메인, SSL, 운영 스토리지는 별도 배포 단계까지 보류한다.

## 최신 Handover

- Goal: React Native → Flutter 전환 완료. 모든 화면, 상태 관리, API 연동 레이어가 구현됐다.
- Done: frontend/ 삭제 → `flutter create frontend --org com.petyilgi` → pubspec.yaml (13개 의존성) → lib/ 전체 구현 → `flutter analyze` Exit 0, `flutter build web` 성공.
- Remaining: Android 에뮬레이터/기기에서 백엔드와 함께 실제 E2E 검증 미실시.
- Next step: `flutter run` (Android 에뮬레이터) + 백엔드 실행 후 E2E 수동 검증. 이후 미세 디자인 조정 요청.
- Warnings: `main.dart`의 `initApiClient('http://10.0.2.2:8080')` — Android 에뮬레이터용 주소. 물리 기기는 PC IP로 변경 필요.

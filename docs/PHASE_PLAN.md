# Phase 계획 요약

세부 실행 계획은 완료되어 제거 대상이다. 현재 문서는 Phase 이력과 보류 사항만 남긴다.

## 완료 Phase 요약

| Phase | 요약 | 주요 검증 |
|-------|------|-----------|
| 0 | 거버넌스와 초기 문서 체계 정립 | 문서 기준 수립 |
| 1 | Java 21, Spring Boot, Gradle, Testcontainers, MySQL Spatial 기반 구축 | `SpatialQueryIntegrationTest` GREEN |
| 2 | JWT 인증, 회원가입, 로그인, 토큰 갱신, 로그아웃 구현 | `AuthIntegrationTest` GREEN |
| 3 | 펫 CRUD와 사용자별 소유권 검증 구현 | `PetIntegrationTest` GREEN |
| 4 | 활동 기록 CRUD와 typeId별 상세 기록 구현 | `ActivityRecordIntegrationTest` GREEN |
| 5 | 루틴 CRUD, 오늘 루틴, 완료 상태 변경 구현 | `RoutineIntegrationTest` GREEN |
| 6 | 커뮤니티 포스트, 피드, 좋아요 토글 구현 | `CommunityIntegrationTest` GREEN |
| 7 | 로컬 미디어 저장소, 기록/펫 이미지 업로드와 조회 구현 | `MediaIntegrationTest` GREEN |
| 8 | Expo 프론트와 인증, 펫, 기록, 루틴, 커뮤니티 API 연동 | `npx.cmd tsc --noEmit` GREEN |

## 현재 상태

- Phase 8 이후 유지보수 단계다.
- 최신 마이그레이션은 `V10__extend_community_posts.sql`이다.
- 사용자 프로필, 루틴 기록 템플릿, 커뮤니티 확장, 미디어 정합성 보강이 반영되어 있다.
- Expo 기기/에뮬레이터 수동 검증은 계속 남아 있다.

## 배포/클라우드 보류 사항

- 운영 배포
- 도메인과 SSL
- S3, MinIO, LocalStack 또는 다른 클라우드 객체 저장소
- 운영 환경 보안 강화
- 푸시 알림 운영 구성

## 재진입 조건

배포 단계는 Expo 앱에서 회원가입/로그인, 펫 온보딩, 기록 CRUD, 루틴 CRUD, 커뮤니티 피드/좋아요, 배변 사진 업로드/표시, 로그아웃 후 재진입을 수동 확인한 뒤 시작한다.

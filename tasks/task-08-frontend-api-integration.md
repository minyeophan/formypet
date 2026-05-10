# Phase 8 - Frontend API Integration

**Verify:** `npx.cmd tsc --noEmit` in `frontend/`.

## Scope
- [x] Add a typed frontend API client for `/api/v1`.
- [x] Store JWT tokens in AsyncStorage and attach them to authenticated requests.
- [x] Replace pet, record, routine, and community mock/local data calls with backend API calls.
- [x] Upload selected record images to Phase 7 local media APIs and use returned media URLs in app state.
- [x] Keep local UI state such as selected pet and quick record shortcuts on-device.
- [x] Defer production deployment and cloud storage decisions to the separate deployment phase.

## Phases
1. [x] API/auth client -> verify: TypeScript compile.
2. [x] Pet/record/routine context integration -> verify: TypeScript compile.
3. [x] Community feed/like integration -> verify: TypeScript compile.
4. [x] Record media upload integration -> verify: TypeScript compile.

## Warnings
- Do not touch backend migrations for Phase 8.
- Do not add S3, MinIO, LocalStack, deployment, domain, or SSL work in this phase.

## Current Status
- Phase 8 is complete by CLI verification; Expo device/emulator manual verification is still pending.
- Backend logout is available at `POST /api/v1/auth/logout` with `{ "refreshToken": "..." }` and returns `204 No Content`.
- For Expo on a physical device, set `EXPO_PUBLIC_API_BASE_URL=http://<PC-LAN-IP>:8080`; device `localhost` does not point at the backend running on the PC.

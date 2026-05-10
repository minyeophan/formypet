# Task 06 - Community Domain

### Phase 6 - Community
**Verify:** `./gradlew test --tests "com.petyilgi.community.CommunityIntegrationTest"` passes, then `./gradlew test --rerun-tasks` passes.

1. [x] RED: Add `CommunityIntegrationTest`
   - Verify: community tests fail before implementation.
2. [x] GREEN: Add community schema and API
   - Verify: `CommunityIntegrationTest` passes.
3. [x] Regression: Run all backend tests
   - Verify: `./gradlew test --rerun-tasks` passes.

## Notes
- Added `V6__add_community.sql` because the current migration set ended at `V5__add_routines.sql`.
- Implemented `POST /api/v1/posts`, `GET /api/v1/posts?cursor=&limit=20`, and `POST /api/v1/posts/{id}/like`.
- `frontend/` was not modified.

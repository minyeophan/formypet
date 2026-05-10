# Task 07 - Local Media Storage

### Phase 7 - Local Media
**Verify:** `./gradlew test --tests "com.petyilgi.media.MediaIntegrationTest"` passes, then `./gradlew test --rerun-tasks` passes.

1. [x] RED: Add `MediaIntegrationTest`
   - Verify: media upload and retrieval tests fail before implementation.
2. [x] GREEN: Add `media_resources` schema and local storage API
   - Verify: upload -> DB row -> local file -> URL response flow passes.
3. [x] Regression: Run all backend tests
   - Verify: `./gradlew test --rerun-tasks` passes.

## Scope
- Use local filesystem storage only.
- Do not add S3, MinIO, LocalStack, or paid cloud storage in this phase.
- Store files under `backend/storage/{userId}/{petId}/{yyyyMM}/{uuid}.{ext}`.
- Keep a `MediaStorage` interface so S3 can be added later without changing controllers.

## Notes
- The next migration must be `V7__add_media_resources.sql` because `V5` and `V6` are already used.
- Deployment is explicitly deferred until after frontend API integration.

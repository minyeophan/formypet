# Task 05 - Routine Domain

### Phase 5 - Routine
**Verify:** `./gradlew test --tests "com.petyilgi.routine.RoutineIntegrationTest"` passes, then `./gradlew test` passes.

1. [x] RED: Add `RoutineIntegrationTest`
   - Verify: routine tests fail before implementation.
2. [x] GREEN: Add routine schema and API
   - Verify: `RoutineIntegrationTest` passes.
3. [x] Regression: Run all backend tests
   - Verify: `./gradlew test` passes.

## Notes
- Added `V5__add_routines.sql` because the current migration set ended at `V4__add_activity_records.sql`.
- `frontend/` was not modified.
- Phase 4 media upload remains outside this task.

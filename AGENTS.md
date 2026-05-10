# AGENTS.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.
- Always read `docs/AI_MISTAKES.md` before coding. If the same mistake repeats 3 or more times, record it there with the cause and required future verification.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## Korean / UTF-8 Text Safety

**Korean text must stay readable UTF-8.**

- Keep Korean UI text, comments, and Markdown readable. Do not leave mojibake such as `좏`, `猷`, `留`, `쒓`, or replacement characters.
- Prefer `apply_patch` for manual edits to files containing Korean text.
- If a bulk rewrite is unavoidable on Windows, explicitly read and write the file as UTF-8. Do not use PowerShell `Set-Content` without `-Encoding utf8`, and do not rely on the default Windows code page.
- After editing Korean text, run a mojibake scan for suspicious fragments before finishing.
- Do not romanize Korean or replace it with broken text to avoid encoding issues; preserve the original Korean wording.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Session Continuity

**Work context must survive session breaks.**

At the start of a new session:
- First identify the current working directory and open files.
- If a previous Handover summary exists, read it before doing anything else.
- Don't guess state — if uncertain, ask the user.

When a session interruption is likely:
- Immediately document the current work state.
- Clearly separate what is done from what is not.
- Specify the re-entry point for the next session (file, function, command).

## 6. Context Handover

**At session end, leave a summary for the next worker (AI or human).**

A Handover summary must include:
- **Goal**: What this session was trying to solve
- **Done**: Work actually completed (include file and function names)
- **Remaining**: What's left and why it wasn't finished
- **Next step**: The first concrete action to take when resuming
- **Warnings**: Things not to touch, known bugs, temporary workarounds

Example format:
```
## Handover
- Goal: Add validation to the login form
- Done: Email format check implemented in `LoginForm.tsx`
- Remaining: Password strength check (needs to be added in src/validators.ts)
- Next step: Write `validatePassword()` then wire it into LoginForm
- Warnings: Auth token logic is mid-refactor — do not touch
```

## 7. Phased Execution

**Ship one verified phase before starting the next.**

Each phase must have a single clear Verify condition. Do not start the next phase until the current phase's verify passes.

Phase structure:
```
### Phase N — [name]
**Verify:** [one concrete check — run command, see output, test in app]

[numbered steps]
```

Rules:
- If a step fails, fix it before continuing. Do not accumulate broken state.
- Each phase should leave the codebase in a runnable state.
- Mark phases complete in the plan file as you finish them.
- If a phase's Verify is unclear, rewrite it before starting.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## 백엔드 전용 규칙 (Java 21 / Spring Boot)

### [TDD 강제]
구현 코드보다 테스트 코드가 반드시 먼저 작성된다.
1. **Red**: 실패하는 테스트를 먼저 작성한다. 컴파일조차 안 되어도 된다.
2. **Green**: 테스트를 통과하는 최소한의 코드만 작성한다.
3. **Refactor**: 동작을 유지하면서 코드를 정리한다.

위 순서를 건너뛰는 구현은 즉시 중단하고 테스트 작성으로 되돌아간다.

### [맥락 동기화]
새 세션 또는 새 작업 시작 시 반드시 이 순서로 읽는다:
1. `docs/CONTEXT.md` — 현재 Phase, 마지막 통과 테스트, 다음 목표
2. `docs/FRONTEND_STATUS.md` — 프론트 요구 API 확인
3. 현재 Phase의 `tasks/task-XX-*.md` — 세부 실행 계획

읽지 않고 코드부터 작성하는 것은 금지한다.

### [Java 21 최적화]
- `synchronized` 블록/메서드 **금지** — Virtual Thread Pinning 발생. `ReentrantLock` 사용.
- `record` 타입을 DTO에 적극 활용. `of(Entity)` / `from(Request)` 정적 팩토리 패턴 강제.
- `@Transactional` readOnly 분리: 조회는 `readOnly = true`, 변경은 기본값.
- Testcontainers는 `@Container` + `static` 필드로 컨테이너 재사용 (속도).
- Entity → DTO 변환 로직은 DTO record 내부에만 위치. Service에 변환 코드 없음.

### [API 표준]
- 모든 엔드포인트: `/api/v1/` 접두사 고정.
- 성공 응답: `record ApiResponse<T>(T data, String message)` 공통 래퍼.
- 오류 응답: RFC 7807 `ProblemDetail` (`type`, `title`, `status`, `detail`, `instance`).
- 페이지네이션: 커서 기반 (`?cursor=&limit=20`). offset 방식 금지.

### [Flyway 마이그레이션]
- Entity 필드 추가/변경/삭제 시 반드시 `V{n+1}__describe_change.sql` 신규 파일 작성.
- 기존 `V*.sql` 파일 **절대 수정 금지** — Flyway checksum 오류로 앱 시작 불가.
- `ddl-auto: create` / `ddl-auto: update` 프로덕션·스테이징 환경 금지. `validate` 또는 `none` 사용.
- 테스트 프로파일(`application.yml`의 `test` profile)에서는 Flyway disabled + `ddl-auto: none` + `init-test.sql`.

### [테스트 격리]
- 통합 테스트 클래스에 `@Transactional` 적용 → 각 테스트 종료 후 자동 롤백.
- Testcontainers 컨테이너는 `static @Container` 필드로 선언 → 클래스 내 전체 재사용.
- `@BeforeEach`에서 `repository.deleteAll()` 명시적 정리 — `@Transactional` 롤백으로 커버되지 않는 외부 상태(파일, 메시지큐) 대응.
- `maxParallelForks = 1` 유지 — Testcontainers 병렬 실행 시 포트 충돌 방지.

### [Surgical Action — 백엔드 적용]
- 프론트엔드 코드(`frontend/`)는 백엔드 Phase 완료 전까지 수정 금지.
- 기존 통과 테스트가 깨지면 즉시 수정 후 진행. 테스트 무력화 금지.

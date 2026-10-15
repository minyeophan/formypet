# JPA migration progress
Plan: docs/refactoring/jpa/plan.md
Current domain: wallet (1/12)
Status: baseline verification
Base: origin/develop 8413dcb
Branch: refactor/jpa-wallet
MuMu ADB: 127.0.0.1:16384
Docker was stopped; Docker Desktop startup requested.
No implementation, PR or merge yet.
Ruling: Use this persistent tracked ledger for the multi-PR goal; each domain begins only after preceding merged-version UI verification.
Baseline Gradle execution session: 86336 (still running at last observation; Java/test compilation succeeded).
Docker diagnostic: sailor-ingest.sock rename/access failure prevents engine startup. Requested non-destructive `docker desktop restart`, session 43869; poll live sessions before retrying.
MuMu UI has not been tested; only ADB connectivity confirmed.
Docker recovery operation was rejected by automatic approval review. Requested user to restore Docker Desktop; do not bypass. Baseline integration failures are DockerClientProviderStrategy initialization failures, not implementation regressions. Detailed wallet mapping and verification checklist saved in 01-wallet.md.
Docker restored by user; docker info returned ServerVersion 29.8.0. Baseline rerun session 7607 is live; MySQL and Ryuk Testcontainers are running. Await terminal result before starting a second Gradle invocation.
Prepared WalletExpenseTest (new entity contract, not yet executed); no production code changes yet. Existing Gradle baseline compiled tests before this new file was written.
Goal tool still reports blocked; tool API does not support resuming status. User/UI resume is needed to restore automatic goal continuations; user has authorized continuing work.
Baseline session 7607 completed BUILD SUCCESSFUL (9m29s), before wallet changes.
WalletExpenseTest RED verified missing entity compile failure (75084), then GREEN verified (58666).
Wallet source moved to domain/wallet, entity+JpaRepository added, Service interface/impl connected, JDBC reads extracted. Current wallet integration test session 42498 still running; poll before launching another Gradle build. Minor import/format cleanup applied after launch, so rerun compilation as needed.
No PR, merge or UI verification yet. Remaining: clean ownership policy placement and duplicate category rules, extend boundary/persistence integration coverage, complete tests/review/UI cycle.
Wallet targeted suite session 42498 passed (2m27s). Afterwards ownership policy moved to Service and new tie/NULL cursor + commit visibility regression cases added.
Implementation committed: 0c1a6bb (refactor : 지출 도메인 패키지 정리 및 JPA 전환).
Current full regression session: 57110, live. Flutter debug APK build session: 37070, live, API_BASE_URL=http://127.0.0.1:18083.
Dedicated disposable UI DB container: formypet-jpa-wallet-mysql, host 127.0.0.1:3318, database formypet_jpa. Local test credentials only; container created, backend not yet launched.
Independent read-only reviewer agent /root/wallet_review is reviewing 8413dcb..0c1a6bb. Review pending. No PR or merge yet.
Reviewer /root/wallet_review final: no critical; important LocalTime non-UTC mapping and mutation response TIME(0) precision mismatch; minor trim/isBlank compatibility. No-op updated_at considered and not a defect. Other domains/UI/CI outside review scope remain required gates.
Added regression tests (not run yet) for Unicode/control trim and JDBC/JPA wall-clock precision under Asia/Seoul. Full suite 57110 still runs pre-regression-test snapshot; wait for its exit before RED run. APK 37070 also live.
Confirmed cached Hibernate 6.6.53 provides LocalTimeJdbcType. Intended fix after RED: direct Java time JDBC mapping, trim-then-empty semantics, DB-normalized response via repository refresh (not SQL in Service). Do not assume fixes implemented.
APK first build 37070 failed only because google-services.json was absent in new worktree. Copied existing ignored C:/formypet/frontend/android/app/google-services.json to matching worktree path without reading/exposing contents. APK retry session 21905 is live. Wrong-cwd Flutter command exited without build; corrected command running in frontend.
Full backend regression session 57110 remains live. No restart. New review regressions not compiled in that snapshot. Next: wait for final full-suite result, run wallet tests with -PtestTimezone=Asia/Seoul to verify RED, then apply fixes and rerun.
APK retry 21905 succeeded. adb install -r failed INSTALL_FAILED_VERSION_DOWNGRADE (installed version 6, built 5); app not removed. Rebuilding debug APK with --build-number=7, session 54493. ADB reverse tcp:18083 -> tcp:18083 set successfully.
Full suite 57110 still live; jcmd showed Test worker executing Flyway via MySQL, output.bin continued growing. Do not restart based on quiet console. GitHub connector get_repo confirms repository accessible with push permission, default develop; branch protection not yet inspected.
Full regression 57110 completed BUILD SUCCESSFUL (12m23s), before review fixes/new regression tests. Starting wallet RED suite with Asia/Seoul.
Full suite 57110: 378 tests, 0 failures. Seoul RED suite 25377: 19 tests, 2 failures (wall clock legacy-row read and trim semantics), confirmed review findings.
Applied direct LocalTimeJdbcType mapping, original trim semantics, JPA repository refresh fragment for DB-normalized mutation responses. GREEN not run yet.
APK version7 54493 built, installation failed signature mismatch against existing app. Existing app preserved. Found existing ISOLATED_MEDIA_TEST build option; building separate com.formypet.frontend.mediatest via session 99677. No frontend code changes required.
Isolated APK build 99677 succeeded; adb install succeeded for com.formypet.frontend.mediatest. Original com.formypet.frontend remains installed. Test API target http://127.0.0.1:18083 via adb reverse.
Seoul GREEN test session 36238 live, compile succeeded. Starting bootJar with unchanged production sources to prepare local UI backend; no further source mutation until both builds complete.
Seoul GREEN suite 36238 passed (2m59s); bootJar 20945 passed. UI backend starting with isolated DB on port 18083, JVM Asia/Seoul, live session 77406. First unquoted JVM arg invocation failed before startup; corrected quoted invocation is the only live server.

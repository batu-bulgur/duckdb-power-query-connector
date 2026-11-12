# Connector development

Primary upstream: `motherduckdb/duckdb-power-query-connector`. Keep its ODBC
connector, public function signature, resources, and `DuckDB.proj` compatible.
The local `origin` is `batu-bulgur/duckdb-power-query-connector` (the personal
fork); `upstream` is MotherDuck. The standing delivery authorization below
applies only to this personal fork.

Use 64-bit PowerShell 7.2 or newer on Windows:

```powershell
./tools/dev.ps1 bootstrap
./tools/dev.ps1 doctor
./tools/dev.ps1 build
./tools/dev.ps1 test
./tools/dev.ps1 test-folding
./tools/dev.ps1 verify
```

- Read `docs/development.md` and `docs/upstream-review.md` before changing folding.
- Reproduce failures with the actual SDK and ODBC driver before changing capabilities.
- Keep fixes narrow and add correct-result, SQL, and ODBC-row regression assertions.
  PQTest exit code zero alone is not success. Never regenerate baselines in test runs.
- For text folding changes, read `docs/text-folding.md`. Preserve the additive
  VARCHAR/NVARCHAR conversion and the negative EndsWith escape regression until
  actual driver folding is demonstrated. Driver source/build work is a separate scope.
- Use only synthetic fixtures. Never use MAW or production data in automated tests.
- Put downloads, substituted queries, fixture databases, credentials, logs, and
  ad-hoc research under `/.agent/`. Never stage that directory or `/outputs/`.
  `bin/AnyCPU/Debug/DuckDB.mez` is the intentional, ignored build output.
- Preserve the upstream MSBuild build. The headless SDK build must package the
  exact same allowlisted resources from `DuckDB.proj` and load with `PQTest info`.
- Do not modify installed ODBC drivers, DSNs, system locale, security policies,
  user Excel/Power BI sessions, or custom-connector trust settings as a test shortcut.
- Keep SDK-only compatibility adjustments in `tools/Initialize-Sdk.ps1`, never
  in connector runtime code. Keep environment-specific experiments separate.
- ADBC remains a research track (`docs/experiments/adbc.md`); no migration without
  measured folding, correctness, performance, and maintainability evidence.
- Host integration is a final, separate check. SDK success does not prove Excel
  custom-connector support or Power BI Desktop GUI integration.

## Autonomous feature delivery

All GitHub-facing development content must be in English: documentation,
commit messages, PR/issue titles and descriptions, reviews, release notes,
and ordinary code comments. The conversation language does not change this
policy. Preserve Turkish/Unicode fixture data, identifiers, examples and
test-specific commentary when they exercise or explain language behavior.

The user has authorized the complete delivery loop for explicitly requested
implementation work in this repository. Do not ask again to commit, push, open
a PR, or enable auto-merge for that work in the personal fork. Read-only
research/review requests do not authorize implementation or delivery.

- Read [docs/workflow.md](docs/workflow.md) before delivering work. Start each
  independent change from current `origin/main` on a short-lived `codex/<topic>`
  branch. Local `main` tracks `origin/main`; `upstream/main` remains the upstream
  reference. Never work directly on main.
- Inspect worktrees and dirty files first. Use an isolated worktree whenever
  another chat owns the checkout. Never switch, reset, stash, rebase, commit,
  clean, or change files in another active chat's checkout. A chat can deliver
  several sequential features, each on a fresh branch after the preceding merge.
- Keep one independently reviewable behavior per PR. Include its tests and
  necessary documentation. Split shared infrastructure from independent feature
  families when practical; record dependencies instead of hiding them.
- Apply [docs/versioning.md](docs/versioning.md): increment VERSION and connector
  metadata for packaged changes, add the matching release notes and CHANGELOG
  entry, and validate the transition against origin/main. Use patch for fixes,
  minor for new compatible features/folding, and major for contract breaks.
- Run relevant focused tests during development and `./tools/Verify-Change.ps1
  -BaseRef origin/main -Connector <artifact>` on the final source/artifact before
  delivery. It requires the full `dev.ps1 verify -Parallel` suite for connector,
  test, fixture, runner, SDK/ODBC or unknown changes. Documentation and explicitly
  classified release/validation tooling use focused version/publisher tests,
  exact package/source checks and SDK loading. Do not repeat the unchanged M
  suites for those changes. Inspect actual result, SQL and
  ODBC-row evidence. Never bless baselines or weaken tests to get green CI.
- Review the diff, run `git diff --check`, and stage only this task's changes.
  Commit with a meaningful message, push only to origin, and open/update a PR
  with the explicit target `batu-bulgur/duckdb-power-query-connector:main`.
  A draft PR may be used while work continues; mark ready only after local
  validation and code review. Do not assume a push without a PR runs CI.
- Enable squash auto-merge for ready, locally verified PRs. Follow the actual
  GitHub Actions run through completion, repair failures within scope, and
  verify that the PR merged and the resulting main build passed. Required
  checks are `build` and `smoke-test`; unresolved discussions block merging.
  Do not bypass branch protection, use admin merge, force-push, or merge failed,
  missing, stale, cancelled, or skipped required validation. An AI review is
  additional evidence, not a substitute for tests.
- After squash merge, start the next feature from the updated origin/main.
  Preserve branches/worktrees still used by active chats. Remove an owned
  finished worktree or branch only after verifying all work is preserved and
  any required cleanup authorization is present.
- Report the PR link, merge commit, tests and material remaining limits. If
  authentication, permissions, conflicts or external CI prevent completion,
  explain the concrete blocker; never report an unobserved success.
- The user also authorizes automatic personal-fork releases for every SemVer
  increment after successful main CI. Follow `Publish fork release` to completion
  and report its release/download link; never overwrite a published version.
- Never push to MotherDuck or open/comment on an upstream issue/PR without a
  separate explicit request. Personal release authorization does not authorize
  upstream publication or changing host trust/security policy.

# Development and delivery in the personal fork

## Repository roles

- `origin`: `https://github.com/batu-bulgur/duckdb-power-query-connector.git`.
- `upstream`: `https://github.com/motherduckdb/duckdb-power-query-connector.git`.
- `origin/main`: the tested integration branch for this fork.
- `upstream/main`: MotherDuck's independent reference; integration into the fork
  happens through a reviewed PR, preserving local improvements.

The original project directory is the primary checkout. It stays clean on
`main`, tracking `origin/main`; it is not a feature checkout, even when only one
chat is working. All implementation, fix, documentation, build and experiment
work belongs in a separate linked worktree on `codex/<topic>`. Do not detach
primary HEAD or check out a topic branch there. Linked worktrees must not claim
`main`, so it remains available in the primary directory.

Fetch `origin/main` and fast-forward primary `main` before starting work and after
each PR merge, before the final delivery report. Coordinate primary syncs when
chats finish together. Only a clean primary on `main` with no local-only commits
may be fast-forwarded. If the branch, source status or history is unexpected,
report it and preserve the files; do not reset, stash or overwrite to force sync.
Remote changes can advance between these boundaries; entering the directory does
not itself fetch or pull. Primary remains on `main` and may temporarily be behind.

Fetching remote refs does not require changing an active feature checkout.
Never switch branches in a directory owned by another chat. Preserve ignored
SDK caches, junction targets and evidence in the primary `.agent` directory;
linked worktrees can depend on them. Retired source snapshots are recovery
material, not feature development checkouts.

## Default delivery loop

Write all GitHub-facing development content in English, regardless of the
language used in chat. This includes commits, PRs, issues, reviews, documentation,
release notes and ordinary code comments. Turkish/Unicode test inputs, identifiers,
examples and test-specific commentary are appropriate when they exercise or
explain language behavior; do not translate away that coverage.

1. Inspect status and worktrees, fetch origin/main and fast-forward clean primary
   `main`. Always create a separate linked worktree with a short-lived
   `codex/<topic>` branch from that origin/main commit. Begin from a committed
   dependency only when necessary and document it; primary still stays on main.
2. Implement one coherent behavior with correct-result regression tests, SQL
   folding and ODBC transfer assertions where applicable. Use synthetic data.
3. Run focused tests while iterating; run `./tools/Verify-Change.ps1 -BaseRef
   origin/main -Connector <artifact>` before delivery. Connector, test, fixture,
   runner and toolchain changes require full runtime verification. Documentation
   and classified release/validation tooling run version/publisher guards,
   package/source integrity and SDK loading without unchanged M/folding suites.
   Unknown changes require full validation. Do not regenerate expected outputs.
4. Review the diff and `git diff --check`; explicitly stage only task-owned
   files. Commit and push to origin under the standing authorization in AGENTS.md.
   A connected GitHub tool may publish the exact reviewed tree if CLI credentials
   are unavailable; fetch back and verify tree identity and branch tracking.
5. Open a PR explicitly targeting this fork's main. Describe the problem,
   resulting behavior, coverage, SDK/driver versions and remaining limits.
   Draft PRs provide early CI; only ready PRs may enter auto-merge.
6. Enable squash auto-merge after local validation and code review. Watch the
   latest PR checks, fix failures within scope, and confirm the resulting merge
   and main push build. A pending run, exit-zero command, or queued auto-merge is
   not completion. Never bypass a failed/missing check or branch protection.
7. Fetch origin/main and fast-forward the clean primary main after merge. Verify
   its branch, clean status and equality with the fetched origin/main. Start the
   next independent feature in a separate worktree from updated origin/main,
   even when continuing the same chat. Squashed feature branches are not reused
   for new PRs.
8. After required CI/release verification, preserve needed ignored evidence in
   primary `.agent/archives/<topic>` and remove the delivered worktree and local
   topic branch. Verify squash-merge preservation and live dependencies first.
   Use the managed archive tool for managed worktrees. Active worktrees stay
   until their owner releases them; completed features do not remain checked out
   merely as archives. Recheck the final worktree list and clean primary main.

PR size follows behavior and dependencies, not a fixed line count. Shared
infrastructure may precede separate text/numeric function families. Each PR
should be understandable and reversible without unrelated work. Preserve old
branches while an active chat or unmerged work still depends on them.

## GitHub controls

Main requires a PR, successful `build` and `smoke-test` checks against the current
base, resolved conversations and linear history. The rules apply to admins too.
Force pushes and deletions are disabled. Required human approvals are zero for
this solo-maintained fork; this does not waive code review or CI. Auto-merge is
enabled repository-wide and selected separately on each ready PR. Feature PRs
use squash merge. No workflow automatically accepts arbitrary contributors' PRs.

Both jobs remain required for every PR/main head. `smoke-test` uses the scope
selected from the actual Git diff and project resource allowlist. Metadata-only
changes do not install ODBC or seed million-row fixtures; their current build is
still source/hash checked and loaded by the pinned SDK. Runtime/test/toolchain or
unknown changes retain the full strict suite. Changes to the build runner image,
action versions or detected SDK/driver setup lines also require full validation.
Manual workflow dispatch always
forces full verification. Scope tests cover mixed, renamed/deleted, packaged,
unknown and empty changes; metadata work is not represented by a skipped check.

Automatically delete head branches is enabled for merged PRs. This removes remote
PR branches; it does not remove local branches or worktrees. Local cleanup is a
required delivery step under the user's standing authorization. Check ownership,
dirty/untracked files, squash-merge preservation and live dependencies. Keep
active chats' branches and checkouts. Archive completed managed worktrees through
Codex so their non-ignored work remains recoverable; preserve needed ignored
files separately before archiving. Do not keep completed worktrees or branches
in the active tree after their work and verification have finished.

Build connector runs on PRs to main, main pushes and manual dispatch. A feature
branch push without a PR does not trigger it. Windows jobs build with the
unchanged upstream MSBuild project and test that artifact using the pinned SDK
and ODBC version from tools/toolchain.json. A local driver's success does not
prove the pinned hosted driver's success. Logs and synthetic diagnostics are
workflow artifacts; credentials, MAW data and production records are excluded.

## Upstream contributions and releases

The standing permission ends at the personal fork. Sending code, comments or
issues to MotherDuck requires a separate explicit request. Prepare upstream
contributions from current upstream/main with only
the relevant fix, tests and portable documentation. Discuss broad architecture
before proposing a large parity implementation; disclose undocumented SDK
dependencies and independently measured compatibility limits.

Every SemVer increment automatically publishes a personal-fork release from
that successful main push build's artifact, with curated notes and checksums;
see [versioning](versioning.md). CI success is SDK/ODBC evidence, not a claim that
Excel or Power BI Desktop GUI integration passed. Host validation stays separate
and must preserve user sessions and existing trust/security policy.

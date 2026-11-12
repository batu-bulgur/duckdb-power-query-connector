# Development and delivery in the personal fork

## Repository roles

- `origin`: `https://github.com/batu-bulgur/duckdb-power-query-connector.git`.
- `upstream`: `https://github.com/motherduckdb/duckdb-power-query-connector.git`.
- `origin/main`: the tested integration branch for this fork.
- `upstream/main`: MotherDuck's independent reference; integration into the fork
  happens through a reviewed PR, preserving local improvements.

Local main tracks origin/main. Fetching remote refs does not require changing an
active checkout. Never switch branches in a directory owned by another chat.
The original `fix/endswith-folding` checkout and its in-progress parity files
must be preserved during the initial migration.

## Default delivery loop

Write all GitHub-facing development content in English, regardless of the
language used in chat. This includes commits, PRs, issues, reviews, documentation,
release notes and ordinary code comments. Turkish/Unicode test inputs, identifiers,
examples and test-specific commentary are appropriate when they exercise or
explain language behavior; do not translate away that coverage.

1. Inspect status, worktrees and current origin/main. Create a short-lived
   `codex/<topic>` branch from origin/main, using a separate worktree for parallel
   work. Begin from a committed dependency only when necessary and document it.
2. Implement one coherent behavior with correct-result regression tests, SQL
   folding and ODBC transfer assertions where applicable. Use synthetic data.
3. Run focused tests while iterating; run `./tools/dev.ps1 verify` against the
   final source/artifact before delivery. Do not regenerate expected outputs.
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
7. Start the next independent feature from updated origin/main, even when
   continuing the same chat. Squashed feature branches are not reused for new PRs.

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

Automatically delete head branches is enabled for merged PRs. This removes remote
PR branches; it does not remove local branches or worktrees. Before local cleanup,
check chat ownership, dirty/untracked files and squash-merge preservation. Keep
active chats' branches and checkouts. Archive unused managed worktrees through
Codex so their non-ignored work remains recoverable; preserve needed ignored
files separately before archiving.

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

# Personal fork versioning and releases

The user authorizes automatic versioned releases in
`batu-bulgur/duckdb-power-query-connector` after successful main CI. This does not
authorize publishing to MotherDuck or changing host trust/security policy.

## Version contract

`VERSION`, the `[Version = "..."]` metadata in `DuckDB.pq`, and the current
`docs/release-notes/<version>.md` must agree. Use normal SemVer `MAJOR.MINOR.PATCH`
without leading zeroes. Prerelease/build-metadata support requires separate
packaging validation before adoption. Versions below 1.0 remain experimental.

- Patch: backward-compatible defect correction.
- Minor: new backward-compatible feature or measured folding capability.
- Major: incompatible public contract change; reset minor and patch.
- The public contract includes `DuckDB.Contents` arguments, authentication,
  navigation/schema, and the M result semantics of supported operations.
- Docs/test-only changes can keep the version when packaged resources do not
  change. Any connector resource change requires an increment. Every increment
  requires a new release note file and yields a downloadable release.
- Put `<!-- release-type: patch|minor|major -->` with the chosen single value at
  the top of the new notes. The transition checker enforces that increment/reset.
- Update CHANGELOG with the new release's features and explicit folding scope.
  Preserve old note files. Behavior changes belong in a subsequent release;
  explicitly requested metadata-only corrections may use the reviewed exact
  before/after Git blob pairs in `docs/release-note-corrections.json`.
- Release notes must be in English, with `Added`, `Query folding`,
  `Known limitations` and `Validation` sections. Include `Fixed` when applicable.
  Test data may retain Turkish/Unicode text when needed for language coverage.

The first tracked fork version is 0.3.0, following the upstream v0.2.0 base. The
pre-existing connector metadata still said 0.1.7 despite that upstream tag; this
bootstrap synchronizes it with VERSION. Earlier commits are not retroactively
presented as published personal releases.

## Validation and publication

Run `./tools/Test-Version.ps1 -BaseRef origin/main`, then the normal final
`./tools/dev.ps1 verify`. CI runs version policy regression tests, checks the
transition against the actual PR base/main-push parent, and compares the built
MEZ's allowlisted resources with source. The same tests and row budgets apply to
versioned artifacts; release preparation never regenerates test baselines.

`Publish fork release` runs after successful **main push** `Build connector`
runs, only in the named personal fork. It checks the triggering event, branch,
workflow, success conclusion and exact SHA again. PR events cannot publish.
The workflow checks out the validated SHA and downloads that run's artifact;
it does not rebuild. A main commit without a VERSION change produces no release.
Main builds and releases use per-commit concurrency groups so a newer version
cannot cancel an older version waiting for a runner. Superseded PR checks may
still be cancelled. Pre-versioning main commits are ignored by the release workflow.

Each `fork-v<version>` release includes:

- `duckdb-power-query-connector.mez` for trying that exact version.
- `SHA256SUMS` for download integrity.
- `release-manifest.json` with version, commit, source build URL, SDK/ODBC
  versions and artifact SHA-256.
- Curated notes explaining additions, fixes, verified folding, domain/overload
  limits and validation. Distinguish newly added behavior from the cumulative
  folding table available in that version. Do not claim GUI support from SDK evidence.

Published versions/tags/assets are not overwritten. Re-running the same successful
release recognizes the same tag/commit with complete assets. An incomplete draft
or conflicting tag fails explicitly and requires diagnosis; it is not a successful
release. Keep following the release workflow until publication and asset digest
verification finish. The original upstream manual release workflow is retained
for compatibility and is not the personal fork's automatic path.

## Published note corrections

A language or factual metadata correction must not change the published tag,
commit, binary or checksums, or imply that an unreleased feature was included.
Record the note path, exact original/corrected Git blob IDs and an English reason
in `docs/release-note-corrections.json`. The transition check accepts only that
exact content pair; other historical edits still fail. Review the correction in
a normal PR and update the existing GitHub release description to match. A
documentation-only correction does not increment VERSION or produce a new binary.

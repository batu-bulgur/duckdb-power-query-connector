# Headless Windows development

The prototype extends the existing upstream ODBC connector. It does not add a
second runtime or change `DuckDB.Contents` arguments, authentication, or navigation.

## Prerequisites and commands

Use Windows x64, PowerShell 7.2 or newer, .NET Framework 4.7.2 or newer, and an installed
64-bit `DuckDB Driver`. Existing driver installations are reused; no administrator
rights, Visual Studio, .NET SDK, NuGet CLI, Excel, or Power BI process is needed
for the local development loop. An absent/blocked driver is a prerequisite error,
not permission to alter endpoint policies or install a machine-wide driver.

```powershell
./tools/dev.ps1 bootstrap     # Pinned Microsoft SDK package, SHA-256 verified
./tools/dev.ps1 doctor        # SDK version, real ODBC engine, pagination SQL
./tools/dev.ps1 build         # MakePQX compile, PQTest info, archive/source hashes
./tools/dev.ps1 test          # Three original upstream functional baselines
./tools/dev.ps1 test-folding  # Results + strict folding + SQL/ODBC row contracts
./tools/dev.ps1 verify        # Build, runner checks, both suites, negative controls
```

Commands exit nonzero on failure. `test` and `test-folding` build from current
source by default. To verify an already-built artifact or isolate a regression:

```powershell
./tools/dev.ps1 test-folding -Connector ./bin/AnyCPU/Debug/DuckDB.mez -Case skip_take
```

The SDK is installed under `.agent/tools/sdk/2.155.2`, pinned to upstream CI's
version in `tools/toolchain.json`. The download is about 129 MiB. The NuGet package's
MakePQX configuration omits a binding redirect for its shipped
`System.Threading.Tasks.Extensions` assembly (reference 4.2.0.1, shipped 4.2.1.0).
`Initialize-Sdk.ps1` applies that single redirect to the project-owned tool copy.
It does not change .NET machine configuration or connector behavior.

## Packaging

`MakePQX compile` receives a staging directory populated from `DuckDB.proj`'s
`MezContent` allowlist. Tests, credentials, SDK binaries, and logs cannot enter
the package. Build then loads the extension with `PQTest info` and checks every
archive resource's SHA-256 against the current source. The final development
artifact is `bin/AnyCPU/Debug/DuckDB.mez`. Upstream `msbuild DuckDB.proj` remains
available and unchanged; CI continues to build with it.

## Test isolation and correctness

Each run creates an isolated directory under `.agent/test/` and a fresh synthetic
`fixture.db`. Fixtures are seeded through the same ODBC driver as the connector.
This avoids storage-format mismatches when a separately installed DuckDB CLI is
newer than ODBC. All read tests use `read_only=true`. No DSN, user database, or
MAW catalog is read or modified. Anonymous PQTest credentials are isolated with
`--CredentialsFilePath` inside that run directory.

Committed query/baseline pairs stay unchanged. The runner substitutes only the
database path in run-local copies, requires an existing `.pqout`, rejects error
baselines, and uses `--failOnMissingOutputFile`. It never blesses new expected
results automatically.

## Folding is an evidence contract

`test-folding` adds `--failOnFoldingFailure` and captures ODBC diagnostics. A test
passes only when all of the following hold:

1. PQTest exits zero and both its outer JSON status and comparison status are
   `Passed`, with no source/output errors.
2. The expected data matches the committed baseline.
3. Exactly one matching ODBC query-start/query-finish pair is observed without
   an ODBC exception.
4. The SQL includes the required projection, predicate, aggregation, order, or
   pagination clauses in `test/folding/contracts.json`.
5. The driver-reported row count is within the case's transfer budget.

The extra checks are necessary. On SDK 2.155.2, `compare` can exit zero while its
JSON says `Failed`; it can also report success for a partially local expression
with `--failOnFoldingFailure`. Thus the flag alone does not establish folding.
SQL assertions are deliberately scoped to each case, while correct-result tests
catch bound-parameter and escaping errors that SQL shape alone would miss.

Coverage includes numeric/date/text predicates, selected columns, SUM, grouped
COUNT, total row count, DISTINCT, LIMIT, LIMIT/OFFSET, standalone OFFSET, zero
skip, skip beyond the table, Contains/StartsWith, apostrophes,
and literal `%`/`_` in text matching. The fixture contains one million rows.
This is a folding regression fixture, not a throughput or peak-memory benchmark.

`verify` also tests the runner against exit-zero/failed-JSON, missing diagnostics,
incorrect query identifiers, missing SQL, and excessive row counts. Four real
negative controls return correct data but must be rejected by the folding guard:
`Table.AddIndexColumn` followed by `FirstN`, `Text.EndsWith`, equality to the Unicode
literal `İstanbul`, and filtering an upstream
`Value.NativeQuery(..., [EnableFolding=true])` result. The latter remains an
upstream limitation: its `Odbc.Query` handler ignores subsequent folding.
Strict EndsWith and Unicode predicates currently produce a generic SDK
NullReferenceException. Their negative controls first evaluate the correct result
without the strict flag, then prove the missing predicates and excess transfer
are rejected. Expected rejection of these controls verifies the guard; it does not claim those
operations have gained folding support.

Known limitations are explicitly outside the supported folding suite. To make a
known unsupported query fail the normal test command (exit 1), run:

```powershell
./tools/dev.ps1 test-folding -IncludeKnownLimitations -Case native_filter
./tools/dev.ps1 test-folding -IncludeKnownLimitations -Case text_ends
./tools/dev.ps1 test-folding -IncludeKnownLimitations -Case text_unicode
```

`-IncludeKnownLimitations` without `-Case` includes these queries and is expected
to fail until their capabilities are implemented. Do not convert their failures
into passing folding expectations.

## Contribution boundaries and host integration

Runtime changes are two capability declarations: `LimitOffset` and
`SupportsStringLiterals`. They are independent of local paths and business data.
The ODBC architecture and string-function escape suppression from upstream PR #72
remain in place. Review the reproduction evidence in `upstream-review.md`.

The SDK/fixture/runner tooling is a generally reusable, separate contribution.
ADBC research and any future Excel-specific experiment must stay separate from
those changes. Do not add machine paths or business-specific code to the connector.

The generated MEZ is an unsigned development artifact. Desktop integration is a
separate final step using the applicable existing organizational trust policy;
the tools never weaken security settings, copy into user connector folders, or
restart user applications. Microsoft documents self-distributed MEZ loading for
[Power BI Desktop and its gateway](https://learn.microsoft.com/en-us/power-query/install-sdk).
Do not infer that it loads in Excel. Excel's built-in ODBC route is a separate
integration target whose folding must be measured in that host. Neither Excel
nor Power BI GUI integration is established by PQTest alone.

CI uses the same `verify` command against the artifact from upstream's MSBuild
job. Its isolated hosted runner retains upstream's pinned ODBC 1.4.4.0 installation;
this is not an installation procedure for corporate machines. CI records synthetic
test evidence as an artifact. Local results must be distinguished from an actual
GitHub Actions run; changing the workflow alone does not verify hosted CI.

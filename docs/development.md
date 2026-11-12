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
./tools/dev.ps1 test          # Upstream functional, schema and comparer baselines
./tools/dev.ps1 test-folding  # Results + strict folding + SQL/ODBC row contracts
./tools/dev.ps1 test-parity   # Pure M references, then matching scalar folding cases
./tools/dev.ps1 verify        # Build, runner, functional, M-reference, folding, negatives
./tools/dev.ps1 verify -Parallel # Same complete suite in six isolated test processes
./tools/Verify-Change.ps1 -BaseRef origin/main -Connector ./bin/AnyCPU/Debug/DuckDB.mez # Required scope for this change
```

Commands exit nonzero on failure. `test` and `test-folding` build from current
source by default. To verify an already-built artifact or isolate a regression:

```powershell
./tools/dev.ps1 test-folding -Connector ./bin/AnyCPU/Debug/DuckDB.mez -Case skip_take
./tools/dev.ps1 test-parity -Case 'parity_round*'
```

Use `Verify-Change.ps1` for delivery. Its allowlist selects focused metadata checks
for docs and release/validation tooling, while any packaged resource, project,
VERSION, M test/baseline, fixture, runner, SDK/ODBC or unknown change selects the
full suite. Package contents must match the current checkout and load with SDK
`info` in either scope. `-ForceFull` and manual CI dispatch request the complete
suite explicitly. This avoids replaying unchanged M calculations for release-note
edits without dropping either required GitHub check.

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
   pagination clauses in `test/folding/contracts.json`, and matches none of the
   optional `forbiddenPatterns` (for example ODBC `{ fn ... }` escapes).
5. The driver-reported row count is within the case's transfer budget.

Date cases requiring physical timestamp classification declare one extra small
`duckdb_columns()` request. Catalog success/identifiers/SQL/rows are checked
separately; the calculation retains one data query and its own transfer budget.
Undeclared metadata or retries fail. See [date parity](date-parity.md).

The extra checks are necessary. On SDK 2.155.2, `compare` can exit zero while its
JSON says `Failed`; it can also report success for a partially local expression
with `--failOnFoldingFailure`. Thus the flag alone does not establish folding.
SQL assertions are deliberately scoped to each case, while correct-result tests
catch bound-parameter and escaping errors that SQL shape alone would miss.

Coverage includes numeric/date/text predicates, selected columns, SUM, grouped
COUNT, sample standard deviation, total row count, DISTINCT, LIMIT, LIMIT/OFFSET, standalone OFFSET, zero
skip, skip beyond the table, Contains/StartsWith, apostrophes,
and literal `%`/`_` in text matching. Unicode equality is covered with Turkish
letters, dotted/dotless I and case variants, apostrophes, supplementary-plane
characters, and an empty result. Each of the main and Unicode folding tables
contains one million rows; the Unicode equality case must transfer just one row.
This is a folding regression fixture, not a throughput or peak-memory benchmark.

Standard deviation uses the existing ODBC `AstVisitor.Functions`/`Invocation`
hooks. The shared visitor registers `List.StandardDeviation` and `Text.EndsWith`,
and dispatches each invocation to its own mapping. A direct numeric column in a
global or grouped aggregate is translated to
`CASE COUNT(column) WHEN 1 THEN 0 ELSE STDDEV_SAMP(column) END`. M ignores nulls,
returns zero for a singleton, and returns null for empty/all-null inputs; the
COUNT/CASE wrapper preserves those semantics. The existing visitor resolves and
quotes the column; no source SQL or identifiers are assembled from user text.
Other argument shapes and non-numeric columns keep their existing local behavior.
No public connector parameters, driver capabilities, ODBC drivers, or installed
Power BI binaries/configuration are changed for this mapping.

Six folding cases check sample-versus-population results, direct list aggregation,
global and grouped aggregation, integer/decimal/double columns, negative and constant values, nulls,
singletons, an empty input, a large numeric offset, and Turkish/quoted identifiers.
The million-row case compares SD to the independent equally-spaced sample
formula within an absolute tolerance of `0.000001`, then returns the source count
only when the check passes. This avoids exact floating-point snapshots. Its SQL
must contain `STDDEV_SAMP` and `COUNT`, and ODBC may return at most one row.
`stddev_semantics` also compares the small fixture's connector results to the
same calculations over `Table.Buffer`, which forces the reference into M.
These are aggregate folding checks; Power BI's full column-profiling UI still
requires a separate host integration check.

EndsWith additionally covers literal `%`/`_`, apostrophes, backslashes, Unicode
and case/dotted-I distinctions, an emoji suffix, no matches, and an empty suffix
against a table containing NULL and empty labels. Its million-row case must
transfer at most three rows. Separate cases compose it with grouped COUNT and
LIMIT/OFFSET. New baselines were hand-selected and checked through independent
ODBC `suffix(...)` queries, rather than generated from the connector's output.

The [scalar parity suite](scalar-parity.md) extends the initial EndsWith visitor
to thirteen candidates in explicitly bounded argument/value domains. It adds
source-free M references, UTF-16 text handling, padding without truncation,
M whitespace, decimal rounding, and logical projection/filter transport. These
are scoped mappings, not universal overload parity; the matrix and index work
are documented there.

`verify` also tests the runner against exit-zero/failed-JSON, missing diagnostics,
incorrect query identifiers, missing SQL, forbidden escapes and excessive row
counts. Current negatives cover native-query transforms, SDK-inaccessible
row-dependent structural equality and opaque culture comparers. Each must return
the correct M result before its folding claim is rejected. Indexing, lone UTF-16
surrogates and the expanded Round domains now have positive measured coverage;
their former negative cases are historical, not current limitations.

`verify -Parallel` checks one immutable, source-matched package with independent
functional and reference/control processes plus four folding partitions. The
partitions select sorted case positions modulo four; the coordinator rejects
missing, duplicate or unexpected completed case names and rechecks package hashes.
Every partition must finish successfully. Logs and completion evidence live in
`.agent/verification/`; no baseline is regenerated. The default sequential
`verify` remains available and runs the same suites.

Known limitations are explicitly outside the supported folding suite. To make a
known unsupported query fail the normal test command (exit 1), run:

```powershell
./tools/dev.ps1 test-folding -IncludeKnownLimitations -Case native_filter
```

`-IncludeKnownLimitations` without `-Case` includes these queries and is expected
to fail until their capabilities are implemented. Do not convert their failures
into passing folding expectations.

## Contribution boundaries and host integration

Runtime changes comprise `LimitOffset`, `SupportsStringLiterals`, the relational calculation/index view, the scoped
[scalar visitor](scalar-parity.md), and a narrow Unicode type-info correction.
The driver reports both SQL_VARCHAR and SQL_WVARCHAR
as `VARCHAR`; the Unicode row is renamed to DuckDB's `NVARCHAR` alias and an
additive implicit conversion lets it compare to UTF-8 `VARCHAR` columns. This
does not replace the driver's existing conversion masks or cast the source column.
Table schema and native type names are separately checked. These changes are
independent of local paths and business data.
The ODBC architecture and string-function escape suppression from upstream PR #72
remain in place. Review the reproduction evidence in `upstream-review.md`.

The initial `Text.EndsWith` fix with the default comparer used a narrowly registered ODBC
`AstVisitor` invocation handler to emit native `right(column, length(suffix)) =
suffix`. It delegates argument translation and quoting to the existing engine;
that initial change added no navigation wrapper or SQL text rewriter. `SQL_STRING_FUNCTIONS=0`
stays intact. The subsequent relational parity path also maps explicit Ordinal
and OrdinalIgnoreCase comparers; see `scalar-parity.md` for its measured domain
and the separate opaque culture-comparer boundary.

`AstVisitor` is documented, but its `Functions`/`Invocation` members and SQL AST
record shape are not described by the public ODBC parameter reference. This
implementation is measured on SDK 2.155.2, not an assurance about every Mashup
version. Strict result/SQL/row tests must gate SDK changes. The official ODBC
2.0.0.1 escape diagnostic remains historical evidence; the complete new mapping
has been tested locally with the installed engine v1.5.4. Hosted CI's ODBC
1.4.4.0 and Desktop/Excel hosts require their own runs. Driver source/build
changes remain out of scope. See [text folding evidence](text-folding.md).

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

CI validates the artifact from upstream's MSBuild job. Full scope runs the same
`verify -Parallel` command and installs the pinned ODBC 1.4.4.0 driver. Metadata
scope runs package/source integrity and SDK loading after version/publisher guards;
it does not install ODBC or run the unchanged M suites. Hosted runner setup is
separate from installation procedures for corporate machines. CI records synthetic
test evidence as an artifact. Local results must be distinguished from an actual
GitHub Actions run; changing the workflow alone does not verify hosted CI.

The [GUI text-shaping suite](text-shaping-parity.md) uses exact UTF-16/list/error
transport and checks each final SQL alias in its paired matrices. Shared helpers
emit Python-style SQL lambdas compatible with the measured 1.4.4/2.0 engines.

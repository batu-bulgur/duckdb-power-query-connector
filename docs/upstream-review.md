# Upstream review and reproduced regressions

Review date: 2026-11-11. Primary upstream:
[motherduckdb/duckdb-power-query-connector](https://github.com/motherduckdb/duckdb-power-query-connector),
base `e6161e6388903b7186435da2751f20010ad19086` (PR #75).
The personal fork is `batu-bulgur/duckdb-power-query-connector`.

## Existing implementation and infrastructure

- `DuckDB.pq` builds an `Odbc.DataSource` navigation table. The public optional
  arguments and authentication remain as upstream. Its Table.View native-query
  handler calls `Odbc.Query`; its comment explicitly states that subsequent
  folding is ignored.
- `DuckDB.proj` packages 12 allowlisted resources with MSBuild's ZipDirectory.
- `.github/workflows/build.yaml` builds the MEZ and tests three committed
  smoke/no-token/native-query baselines. Before these changes it did not enforce
  folding, inspect ODBC transfer counts, or reject failed PQTest JSON independently
  of the process exit code. It also substituted paths directly in tracked queries.
- `.github/workflows/release.yaml` requires a green main build before releasing
  an artifact. This release architecture is retained.
- Upstream main's build and release runs were successful when inspected; this
  does not establish that the newly added tests have run on GitHub.

Relevant prior work and reports were inspected before changing capabilities:

| Source | Relevance |
| --- | --- |
| [Issue #32](https://github.com/motherduckdb/duckdb-power-query-connector/issues/32) | DirectQuery/filter folding failures; latest comment recommends retesting the new release. |
| [Issue #60](https://github.com/motherduckdb/duckdb-power-query-connector/issues/60) | Text and numeric filter behavior. |
| [PR #72](https://github.com/motherduckdb/duckdb-power-query-connector/pull/72) | Suppresses unsupported ODBC string-function escapes; preserved. |
| [PR #73](https://github.com/motherduckdb/duckdb-power-query-connector/pull/73) | Optional local token and safe trace defaults; preserved. |
| [PR #74](https://github.com/motherduckdb/duckdb-power-query-connector/pull/74) | Adds native-query handler with local downstream transformations; preserved. |
| [PR #71](https://github.com/motherduckdb/duckdb-power-query-connector/pull/71), [PR #75](https://github.com/motherduckdb/duckdb-power-query-connector/pull/75) | Existing build and release jobs. |
| [Issue #63](https://github.com/motherduckdb/duckdb-power-query-connector/issues/63) | ADBC request; tracked separately, not a reason to rewrite ODBC. |
| [ODBC PR #478](https://github.com/duckdb/duckdb-odbc/pull/478) | SQL_C_WCHAR buffers bound against SQL_VARCHAR are misread on affected driver versions. |

## Actual local environment

Windows x64; PowerShell 7.6.9; Power Query SDK 2.155.2, Mashup engine 2.155.504.0;
installed ODBC engine reports DuckDB v1.5.4. The separately installed CLI reports
v2.0.0. Creating a fixture with that CLI first reproduced an unreadable storage
version error in ODBC. Fixtures now use the same ODBC engine throughout.

## Regression 1: Skip causes full transfer

For a synthetic million-row table, this UI-style M chain:

```powerquery
Table.FirstN(Table.Skip(Table.Sort(data, {{"id", Order.Ascending}}), 5), 3)
```

returned the correct three result rows with upstream, but diagnostics showed an
unbounded `SELECT` and **1,000,000 ODBC rows**. `LimitClauseKind.Limit` advertised
no OFFSET support, so the sort/skip/take chain fell back locally. The strict SDK
flag alone did not reject it.

The narrow fix is `LimitClauseKind.LimitOffset`. The same chain now generates
`ORDER BY "id" LIMIT 3 OFFSET 5` and returns **3 ODBC rows**. Standalone OFFSET,
zero skip, and an offset past the last row are separately covered. The fixture
checks DuckDB's three LIMIT/OFFSET syntax forms through ODBC before tests start.
See Microsoft's [ODBC sample capability descriptions](https://github.com/microsoft/DataConnectors/blob/master/samples/ODBC/SqlODBC/SqlODBC.pq).

## Regression 2: folded text equality returns no rows

`[category] = "odd" and [id] >= 999990` should yield odd IDs beginning at 999991.
Upstream generated a string-bound `"category" = ?` and returned no rows in the
verified local driver. This reproduces the behavior described in ODBC PR #478.

Declaring `SupportsStringLiterals=true` makes the existing Mashup SQL generator
quote string literals (`"category" = 'odd'`). The same test then returns the
expected three rows. Numeric/date binding remains enabled. This change also lets
Contains/StartsWith generate supported LIKE predicates without enabling
the ODBC `{fn ...}` escapes suppressed by upstream PR #72. Regression tests verify
apostrophe quoting and escaping of literal `%` and `_` characters. Unicode equality
is separately retained as a known unsupported case, not reported as folded.

## Known limits

The prototype does not claim every M operation folds. The negative controls
demonstrate local indexing, EndsWith, Unicode equality, and downstream native-query folding are still rejected
by the test guard. No ADBC migration, production-data benchmark, hosted CI run, or
Excel/Power BI GUI validation follows from these SDK results. Keep these claims
separate when preparing upstream pull requests.

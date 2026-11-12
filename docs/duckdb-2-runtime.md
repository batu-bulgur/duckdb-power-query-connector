# DuckDB 2 runtime contract

The personal fork's primary tested Windows AMD64 runtime is DuckDB engine
**2.0.0** through the official **ODBC 2.0.0.1** package, with Power Query SDK
**2.155.2**. Connector release 0.6.1 versions this transition independently of
DuckDB's and the ODBC package's version numbers.

## Exact identity

The driver package is the official
[2.0.0.1 release](https://github.com/duckdb/duckdb-odbc/releases/tag/v2.0.0.1).
Its engine reports `SELECT version()` as `v2.0.0`. The Windows DLL version field
is `200.00.00.00`, which does not identify the ODBC package patch by itself.
The installed local DLL was compared with the official downloaded DLL:

| Item | SHA-256 |
| --- | --- |
| Official Windows AMD64 ZIP | `0319071a1d1f5eab93ae01a69d9aa7d39c772ebcf3ff4e856fc5ad654460e63e` |
| Official DLL and installed local DLL | `9fa507ac3a43d0664c0e5214ba34551e9ea26a17f71415b3ffe18cc698fae563` |

`tools/toolchain.json` pins the package version and ZIP digest. CI checks the
digest before extracting and registering the driver in its disposable runner.
Local validation uses the existing installed driver; it does not change driver
registration, DSNs, locale, application sessions or trust settings.

## Compatibility and release classification

The preceding text release was tested locally on engine 2.0.0 and separately in
CI on ODBC 1.4.4.0. This release aligns hosted validation with the primary 2.0
runtime. Historical 1.4.4 receipts remain dated evidence for the earlier release.

The public DuckDB.Contents arguments, authentication, navigation/schema and
supported M result semantics are preserved. Version 0.6.1 is a patch for the
runtime/validation alignment. The package carries the same calculation modules
as 0.6.0, with an updated connector version. Python-style SQL lambdas already
handle 2.0's parser change; no legacy-lambda session flag is needed.

## Required evidence

Both local and hosted full validation must pass for this source/artifact:

- 189 distinct strict folding cases, with expected results, the SDK folding
  flag, SQL shape, successful ODBC query count and row-transfer budgets.
- 42 functional tests, including 217,707 paired M value/error comparisons.
- 120 independent source-free M references, seven correct-result negative
  folding controls, four native failure reproducers and 16 runner controls.
- All 20 packaged resources matching source, with successful SDK loading.

CI fixture receipts must report `v2.0.0`; workflow success and download version
alone are insufficient evidence. The main build and published release additionally
require tag/commit identity, asset checksums and package/source verification.
Excel and Power BI Desktop GUI integration remain separate host checks.

## Follow-up SQL simplification

The 2.0 baseline is the starting point for measured simplification. For each
candidate, compare the existing expression with the native alternative over
the same M oracle and boundary cases, then measure SQL size, execution time,
plan and transferred rows. A shorter expression alone is insufficient.

The UTF-16 transport, decimal rounding/conversion rules, error precedence and
fixed-offset temporal behavior encode M semantics. Each can be simplified only
where the replacement preserves its contract. The SDK's opaque expression and
handler-dispatch boundaries are independent of DuckDB's available SQL functions.

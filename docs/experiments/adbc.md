# ADBC research boundary

Status: research only, 2026-11-11. No ADBC code or dependency is in the connector
or its MEZ. ODBC remains the supported implementation in this fork.

Upstream [issue #63](https://github.com/motherduckdb/duckdb-power-query-connector/issues/63)
requests ADBC investigation. Microsoft now documents an
[ADBC connector SQL-generator architecture](https://learn.microsoft.com/en-us/power-query/adbc-sql-generator)
with source-specific capabilities and function mappings. This shows that query
folding still requires a correct SQL-generation layer; columnar transport alone
does not prove better folding.

Any experiment belongs in a separate branch/directory and must compare the same
synthetic fixture and M transformations against the ODBC baseline. A migration
proposal needs evidence for:

- Correct results, NULL/type semantics, string escaping, and Unicode.
- Complete folding coverage and explicit failure for unsupported operations.
- Rows/bytes transported, elapsed time, and peak process memory at comparable
  cold/warm runs, with driver and host versions recorded.
- Local read-only file concurrency, packaging, signing/trust, refresh/cancellation,
  and deployment without administrator rights.
- Power BI and Excel host availability separately; SDK availability is not proof
  of support in either host.
- Maintenance cost and compatibility with upstream's public API and release flow.

The current million-row-to-three-row improvement comes from an ODBC capability
correction. It supplies no evidence that changing the transport architecture is
necessary. No production warehouse data is needed for the initial comparison.

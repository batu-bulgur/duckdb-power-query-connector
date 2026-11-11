# Unicode equality and EndsWith evidence

Date: 2026-11-11. Scope: the existing ODBC connector and its SDK tests. No change
to installed drivers, DSNs, host trust policy, or the ODBC architecture.

## Unicode equality: fixed

On SDK 2.155.2 with the installed DuckDB ODBC engine 1.5.4, Unicode literal
equality previously returned correct data only after local evaluation. Strict
folding produced a generic SDK NullReferenceException.

The actual type-info table reports SQL_VARCHAR (12) and SQL_WVARCHAR (-9) with
the same TYPE_NAME, `VARCHAR`. Renaming only the wide row to the valid DuckDB
`NVARCHAR` alias and adding an implicit conversion between VARCHAR and NVARCHAR
lets the existing folding engine compare the types directly. This uses the
[documented ODBC extension points](https://learn.microsoft.com/en-us/power-query/odbc-parameters)
and Microsoft's [implicit-conversion table format](https://github.com/microsoft/DataConnectors/blob/master/samples/ODBC/RedshiftODBC/RedshiftODBC.pq).
No replacement conversion bitmask, manual SQL-literal writer, new transport, or
new query planner is introduced.

The folded predicate is:

```sql
where "label" = 'İstanbul' and "label" is not null
```

The public column schema still reports VARCHAR; there is no CAST around the
column. Existing ASCII equality, Contains/StartsWith, quote/wildcard escaping,
numeric/date binding, grouping, and pagination stay in the regression suite.

Six positive cases cover the original Istanbul equality, Turkish characters,
Unicode plus an apostrophe, a supplementary-plane emoji plus Turkish text,
zero matches, and one match in a million-row table. The fixture includes distinct
`İstanbul`, `istanbul`, `Istanbul`, and `ıstanbul` rows, so the expected singleton
also protects case/dotted-I semantics. A separate functional test preserves
column names, M kinds, and native type names. The pre-fix connector at `78235eb`
fails the promoted equality test, while the fixed connector passes strict SDK,
correct-result, SQL-shape, and transfer-budget checks.

## Text.EndsWith: driver boundary retained

With ODBC string-function escapes suppressed as upstream PR #72 requires, the
engine cannot fold EndsWith. Enabling just SQL_FN_STR_RIGHT produces:

```sql
where { fn right("label", ?) } = 'y'
```

The installed driver rejects the escaped call with SQLSTATE 42000. PQTest can
then retry an unbounded SELECT and report Passed, even with its strict folding
flag enabled. The SQL/query-count/row guard rejects this retry. On the million-row
fixture, it transfers one million rows to return three result rows. Consequently
the RIGHT capability was not enabled in the shipped connector.

The official [ODBC 2.0.0.1 release](https://github.com/duckdb/duckdb-odbc/releases/tag/v2.0.0.1)
was downloaded into ignored `.agent/`, verified against its GitHub asset digest
`0319071a1d1f5eab93ae01a69d9aa7d39c772ebcf3ff4e856fc5ad654460e63e`, and loaded
without driver registration for a direct ODBC ABI check. Its engine reports 2.0.0:

| ODBC call | ODBC 1.5.4 | Official ODBC 2.0.0.1 |
| --- | --- | --- |
| `SELECT {fn RIGHT('abc', 2)}` | 42000 parser error | 42000 parser error |
| `SELECT { fn right('abc', 2) }` | 42000 parser error | 42000 parser error |
| `SELECT RIGHT('abc', 2)` | `bc` | `bc` |

This is a direct driver diagnostic, not a PQTest/GUI integration claim for the
unregistered new driver. The normal connector test suite continues to use the
installed driver. A newer driver alone does not resolve the escaped-function
translation failure. Connector AST/function-override experiments did not provide
a working native mapping on this SDK and were kept out of tracked runtime code.

Driver source/build changes were explicitly excluded from this task. EndsWith
therefore remains a documented negative control, not a passing folding case:

```powershell
./tools/dev.ps1 test-folding -IncludeKnownLimitations -Case text_ends
```

The command must exit 1. `verify` separately checks that the correct ordinary
result is still rejected as local evaluation. Future work can promote the case
only after both correctness and real ODBC folding/transfer assertions pass.

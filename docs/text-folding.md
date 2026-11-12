# Unicode equality and EndsWith evidence

Updated: 2026-11-12. Scope: the existing ODBC connector and its SDK tests. No change
to installed drivers, DSNs, host trust policy, or the ODBC architecture.

The EndsWith sections below record the initial `de8c503` implementation and its
measured SQL. The subsequent [scalar and relational parity implementation](scalar-parity.md)
adds thirteen scalar mappings and an ordered index plan, with explicit value/error
transport. Its current SQL can therefore differ from the historical direct
predicate shown here. Current comparer coverage and test evidence are in that document.

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

## Text.EndsWith: native SQL mapping

Without a custom visitor, with ODBC string-function escapes suppressed as
upstream PR #72 requires, the engine cannot fold EndsWith. Enabling just
SQL_FN_STR_RIGHT produces:

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
translation failure. No driver upgrade, driver source/build change, or capability
bit enabling escapes is part of the fix below.

### What was investigated

Earlier experiments under ignored `.agent/unicode-ends/` were inspected first.
`AstVisitor.FunctionOverrides` with Text.End/EndsWith entries did not register
an ODBC function visitor. Other experiments tried callback names `Invocation`,
`Function`, `FunctionInvocation`, and `OdbcFunction`, but omitted the `Functions`
registration list. Those results do not establish that a registered invocation
visitor is ineffective.

The following are real SDK 2.155.2 / installed ODBC v1.5.4 measurements, not
inferences from the existence of an option. The reusable ad-hoc probes and raw
ODBC diagnostics are under `.agent/endswith-folding/` (not packaged or committed).

| Approach | SQL / observation | Decision |
| --- | --- | --- |
| `SQL_SQL92_STRING_FUNCTIONS=255`, `SQL_LIKE_ESCAPE_CLAUSE="Y"`, keeping `SQL_STRING_FUNCTIONS=0` | Unbounded `select "id", "category", "label", "amount", "event_date" from "fixture"."main"."folding"`; 1,000,000 rows, no WHERE | Does not select a suffix-LIKE implementation. |
| `SqlCapabilities.ReturnEscapeClause=false` | Same unbounded SELECT and 1,000,000 rows | Does not supply an EndsWith visitor. |
| Read-only inspection of the shipped SDK's visitor implementation | Built-in EndsWith requires the RIGHT string-function bit; unlike StartsWith/Contains it has no LIKE fallback | Do not invent additional capability flags or re-enable escapes. |
| `AstVisitor.Functions={Text.StartsWith}` plus `Invocation` returning a deliberately different column-equality AST | `where "label" = "label" ... limit 3`; intentionally wrong IDs 0,1,2 | Controlled proof that the registered callback changes SQL generation; never shipped. |
| Registered native `suffix(...)` invocation returning a nullable logical scalar | First query starts with `where suffix("label", '99999') = ? and suffix("label", '99999') is not null ... limit 3`, then an unbounded SELECT transfers 1,000,000 rows | Rejected even though strict PQTest reports Passed; two query starts / local retry fail the evidence contract. |
| Registered native RIGHT/LENGTH invocation returning an equality predicate | `where right("label", length('99999')) = '99999' ... limit 3`; exactly one start/finish, 3 rows, correct result | Chosen; no `{ fn ... }`, logical parameter, or local retry. |

The callback signature is `(visitor, rowType, groupKeys, ast)`. Each native
function argument is a SQL AST parameter record `[Expression=visitor(...),
Type=...]`, not a bare translated expression. These two details explain the
earlier unsuccessful AST attempts. The native function reference uses
`[Kind="Function", Name="right"]`; it does not use an ODBC escape reference.

### Narrow runtime change and compatibility

Text.EndsWith and List.StandardDeviation share one `AstVisitor.Functions`
registration in the integrated fork. The invocation callback dispatches using
`ast[Function][Value]`, preserving the independent scalar and aggregate mappings.
The EndsWith handler translates the two arguments using the existing visitor
and returns the SQL AST for:

```sql
right(column, length(suffix)) = suffix
```

The existing generator still owns identifier/literal quoting, parameters,
navigation and all surrounding filter/projection/group/order/pagination SQL.
DuckDB calculates the suffix length, so an emoji is counted in the same units
as native RIGHT. `%`, `_`, backslashes and apostrophes remain literal characters;
there is no manual LIKE pattern builder or SQL text concatenation. SQL NULL
propagates, and an empty suffix matches every non-NULL label including `''`.
Explicit comparer overloads are not mapped to ordinal SQL; the functional
`text_ends_comparer` case verifies the case-insensitive M result instead.

This adds one small function visitor, rather than a Table.View query planner.
`SQL_STRING_FUNCTIONS=0`, Unicode type-info normalization, additive implicit
conversions, the native-query handler, public arguments and resources stay intact.
No SDK binary/configuration adjustment was needed for this mapping.

The public [ODBC parameter reference](https://learn.microsoft.com/en-us/power-query/odbc-parameters)
documents AstVisitor, but does not document the `Functions`/`Invocation` members
or their SQL AST schema. These members are implemented and exercised in SDK
2.155.2; this narrower dependency is an upstream maintenance consideration,
not a promise of compatibility with every Mashup release. Correct-result,
single-query, SQL-shape, escape-exclusion and row-budget tests must gate upgrades.
The full new mapping has not been run against CI's ODBC 1.4.4.0 or a Power BI /
Excel host. The earlier direct 2.0.0.1 escape diagnostic is not such a run.

### Regression contract and pre-fix proof

`text_ends` is promoted from `test/negative/` to `test/folding/` with its unchanged
expected IDs **99999, 199999, 299999**. The fixture still contains one million rows.
The query must project only ID, contain native RIGHT/LENGTH in WHERE, retain
ORDER BY/LIMIT 3, contain no `\{\s*fn\b`, and transfer at most three rows.
The guard's new optional `forbiddenPatterns` field is itself covered by a
must-reject test, even when an escaped query has a WHERE and only three rows.

Building the runtime unchanged from `d41d670` and applying the promoted test:

```powershell
./tools/dev.ps1 test-folding -Connector <pre-fix-mez> -Case text_ends
```

exits **1** (strict SDK Failed / NullReferenceException). Ordinary evaluation
returns the correct baseline but has no WHERE/LIMIT and transfers **1,000,000**
ODBC rows. The new connector passes the same query with the single native query:

```sql
select "id"
from "fixture"."main"."folding"
where right("label", length('99999')) = '99999'
order by "id"
limit 3
```

Positive suffix cases and independently verified expected IDs are:

| Case | Suffix / composition | Expected IDs or result | Max ODBC rows |
| --- | --- | --- | ---: |
| `text_ends` | `99999`, million rows, first 3 | 99999,199999,299999 | 3 |
| `text_ends_wildcards` | literal `%_y`, with wildcard-lookalike distractors | 3 | 1 |
| `text_ends_quote` | `'Brien` | 1 | 1 |
| `text_ends_unicode` | `bul` | 2,7,8,9 | 4 |
| `text_ends_uppercase` | `BUL` | 14 | 1 |
| `text_ends_dotted` | `İ` | 15 | 1 |
| `text_ends_dotless` | `ı` | 10,16 | 2 |
| `text_ends_emoji` | `😀` | 13 | 1 |
| `text_ends_no_match` | `ABSENT-ş` | empty | 0 |
| `text_ends_empty` | `""`, with empty label ID 5 and NULL ID 6 | all 19 non-NULL IDs, including 5, excluding 6 | 19 |
| `text_ends_backslash` | `\slash` | 4 | 1 |
| `text_ends_offset` | `99999`, skip 2 / take 3 | 299999,399999,499999 | 3 |
| `text_ends_group` | `99999`, grouped COUNT | odd: 10 | 1 |

Expected baselines were selected by hand and checked with independent
`SELECT id ... WHERE suffix(label, '...') ORDER BY id` queries through ODBC,
plus independent COUNT and pagination queries. The suite never regenerates
baselines. Every folding case asserts native RIGHT/LENGTH equality in WHERE and
forbids ODBC function escapes. Index folding was subsequently implemented and
promoted to positive coverage. Current negative controls cover native-query
transforms, inaccessible structural constructors and opaque culture comparers;
see `scalar-parity.md` for the current implementation and evidence.

Historical initial default-comparer receipt (before the expanded parity work): on 2026-11-12, `./tools/dev.ps1 verify` exited **0**: the MEZ loaded with all
12 source-matched resources, 10 runner must-reject checks passed, all 5
functional/schema/comparer tests and all 34 folding tests passed, and both
remaining negative controls were rejected. All 13 EndsWith cases above produced
exactly one successful ODBC query within their row budgets. This is a local SDK /
installed-driver result, not a hosted CI or GUI integration claim.

The subsequent integration with sample standard deviation passed local
`./tools/dev.ps1 verify` on the same SDK/installed driver: 6 functional tests,
40 folding contracts, 10 runner rejection checks and 2 expected negative controls.
Both registrations remain active; the earlier standalone totals above describe
the original EndsWith commit. Hosted compatibility is verified separately by
the integration PR's Windows CI run.

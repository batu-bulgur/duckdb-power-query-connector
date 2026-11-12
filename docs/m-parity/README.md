# M function inventory and DuckDB parity research

This is the initial research snapshot, dated **2026-11-12**. Later implementation
and measured boundaries are tracked in [scalar-parity.md](../scalar-parity.md)
and [first14-status.csv](first14-status.csv). The next GUI date group is tracked in
[date-parity.md](../date-parity.md) and [gui-date-status.csv](gui-date-status.csv). The GUI text group is tracked in
[text-shaping-parity.md](../text-shaping-parity.md) and [gui-text-status.csv](gui-text-status.csv).
Research-only status and zero-parity
counts below describe this snapshot, not the later implementation.

The published Microsoft Learn reference yielded **660 named functions and 7
intrinsic constructors: 667 callable entries**. Its union with functions exposed
by the installed SDK contains **705 unique entries**. This is not a count of all
functions supported by every Excel/Power BI version. Research itself changed no
connector runtime, driver, DSN or user application, and established zero new
complete-parity or connector-folding claims.

## Artifacts

| File | Contents |
| --- | --- |
| [function-names.md](function-names.md) | All 667 documented callable entries by reference category, with official links |
| [functions.csv](functions.csv) | 705 entries: documentation/SDK presence, documented signature, SDK parameters, required count, source commit, initial priority and review status |
| [non-functions.csv](non-functions.csv) | 43 enum/constant/dynamic-value reference pages excluded from the callable count; not a count of enum members |
| [candidates.csv](candidates.csv) | 67 SQL candidates with input domains, semantic risks and M/DuckDB sources |
| [evidence.json](evidence.json) | Source versions/hashes, counts, documentation/SDK differences and actual semantic probe results |

CSVs use UTF-8 BOM. Opening a CSV in Excel is not an Excel host folding test.

## Source coverage and counting

Excel and Power BI share the [M language reference](https://learn.microsoft.com/en-us/powerquery-m/).
The [function reference](https://learn.microsoft.com/en-us/powerquery-m/power-query-m-function-reference),
24 categories and published [TOC](https://learn.microsoft.com/en-us/powerquery-m/toc.json)
form the inventory's backbone. [Excel Power Query help](https://support.microsoft.com/en-us/excel/power-query-for-excel-help)
points to the same reference.

All 770 TOC pages were downloaded in Microsoft Learn's Markdown format:
2,541,008 bytes, zero failures. Coverage includes grammar, operators, evaluation,
types, errors, culture, enums and constants. Every callable category link was
accounted for. Downloading and extracting signatures does not establish manual
semantic review of all 770 pages.

Only entries with call signatures were counted as callable. `Number.PI`,
`Number.NaN`, `Order.Type`, `Culture.Current` and `RowExpression.Row` are values.
`#binary`, `#date`, `#datetime`, `#datetimezone`, `#duration`, `#table` and `#time`
are callable constructors. `let`, `each`, `if`, `try`, `otherwise`, `=`, `<>`,
`and`, `or` and `??` are language forms/operators requiring separate translation.
The reference's general “over 700 functions” statement was not used as a count:
667 callable entries plus 43 noncallable pages totals 710 reference entries.

Categories follow Microsoft's layout rather than namespaces; Table includes
`#table`, `ItemExpression.From` and RowExpression helpers.

| Reference category | Callable entries |
| --- | ---: |
| Accessing data | 89 |
| Binary | 40 |
| Combiner | 5 |
| Comparer | 4 |
| Date | 58 |
| DateTime | 26 |
| DateTimeZone | 16 |
| Duration | 13 |
| Error handling | 4 |
| Expression | 3 |
| Function values | 6 |
| Lines | 4 |
| List | 71 |
| Logical | 3 |
| Number | 52 |
| Record | 23 |
| Replacer | 2 |
| Splitter | 10 |
| Table | 119 |
| Text | 44 |
| Time | 10 |
| Type | 24 |
| Uri | 4 |
| Value | 37 |
| **Total** | **667** |

## SDK comparison and uncertainty

SDK `2.155.2.0`, Mashup engine `2.155.504.0`, exposed 886 `#shared` records,
including 691 function values, with zero inspection errors. No connector was
loaded and no inventoried function was invoked during metadata inspection.
[`#shared`](https://learn.microsoft.com/en-us/powerquery-m/m-spec-sections)
reflects that evaluation environment's global section.

| Set | Count |
| --- | ---: |
| Documented callable entries | 667 |
| SDK shared functions | 691 |
| Overlap | 653 |
| SDK-only | 38 |
| Documentation-only | 14 |
| Union | 705 |

Seven documentation-only entries are intrinsic constructors; absence from
`#shared` does not mean the syntax is unavailable. The remaining seven are
`Arrow.Document`, `Arrow.FromBinary`, `Arrow.ToBinary`, `Excel.CurrentWorkbook`,
`FabricAI.Prompt`, `Json.SchemaFromType` and `Table.ClearDown`.

SDK-only entries include Binary.End, Parquet.Document/Metadata, Value.ToText and
test infrastructure such as Fact, PQTest and Theory. Do not assume all are
published, supported Excel/Power BI APIs. Internal-use-only documentation is
flagged separately in the CSV. This inventory is not a closed list of every
connector SDK API, private connector or host-version API.

The TOC spells `Table.PartionKey`, while the page/signature use
[`Table.PartitionKey`](https://learn.microsoft.com/en-us/powerquery-m/table-partitionkey).
The catalog keeps the signature name and original TOC label. Correcting this
identity reduced a provisional union of 706 to the verified **705**.

## Meaning of parity

The target is equivalent results and errors for explicitly supported
transformations over DuckDB tables. It is not a promise that each M function in
every context maps to one DuckDB function.

- [Table.StopFolding](https://learn.microsoft.com/en-us/powerquery-m/table-stopfolding)
  deliberately prevents downstream folding. Removing that behavior breaks parity.
- [Table.Buffer](https://learn.microsoft.com/en-us/powerquery-m/table-buffer)
  has M buffering/isolation behavior and blocks downstream folding; a SQL CTE is
  not an automatic equivalent.
- Excel.CurrentWorkbook, Web.Contents, File.Contents and Sql.Database have source,
  authentication and host contracts. DuckDB file readers do not reproduce them all.
- Function.InvokeAfter, dynamic Expression.Evaluate, randomness, local time and
  arbitrary functions involve timing, effects, closures or host context. Some
  pure/specialized forms may translate; general support cannot be assumed.
- Overloads matter: numeric FirstN differs from its predicate overload; List.Sum
  over a table column differs from a list constructed in a row expression.

The M engine still establishes connections, parses expressions and manages result
types. The goal is to move supported data calculations to DuckDB. Microsoft's
[folding overview](https://learn.microsoft.com/en-us/power-query/query-folding-basics)
explains local evaluation of unsupported transformations.

## Connector architecture at the research baseline

These observations and the CSV's existing-case fields refer to initially clean
commit `d41d670e6f150f4166e4b5ce8c33197a6a854019`. Concurrent runtime/test changes,
including an EndsWith visitor experiment, were observed later but were not
modified or validated by the inventory research. Current linked files may have
advanced; consult the later implementation receipt separately.

The baseline [connector](../../DuckDB.pq) used Odbc.DataSource, driver capabilities,
SqlCapabilities, SQLGetInfo and type mappings, without a general M-to-SQL registry.
The documented [AstVisitor surface](https://learn.microsoft.com/en-us/power-query/odbc-parameters)
and LimitClause example do not by themselves establish unlimited scalar overrides.
Do not invent hook names as evidence of support.

[Table.View](https://learn.microsoft.com/en-us/powerquery-m/table-view) and its
[official handlers example](https://learn.microsoft.com/en-us/power-query/samples/trippin/10-tableview1/readme)
provide another extension point, requiring expression analysis, handlers, query
state, types/schema, ordering, binding and SQL generation. The inventory did not
authorize an architecture rewrite or transport migration.

Baseline regression documentation covered filters, projection, grouping, counts,
DISTINCT, text and pagination; the inventory did not rerun it. CSV fields explicitly
say `existing ... not rerun`. The baseline EndsWith ODBC escape barrier was not
resolved merely by finding an SQL suffix function. Its concurrent implementation
was outside this research receipt. Value.NativeQuery used Odbc.Query and did not
fold downstream transformations. ADBC remains a separate research track.

## Candidate priorities

The [67 candidates](candidates.csv) are development hypotheses, not a support list:

1. **14 initial targets:** Text.EndsWith, Text.Length, Text.Middle, Text.Range,
   Text.PositionOf, Text.PadStart, Text.PadEnd, Text.Trim, Text.TrimStart,
   Text.TrimEnd, Number.Round, Table.AddIndexColumn, Value.Equals and
   Value.NullableEquals. Priority reflects known barriers and semantic traps,
   not ease; ordering makes AddIndexColumn particularly demanding.
2. **47 follow-ups:** wider filter/projection/sort/group support; text, numeric and
   date calculations; JOIN, UNION ALL and basic list aggregates. A general table
   operator such as AddColumn also requires support for its inner expression.
3. **6 broader candidates:** Table.FillDown, Table.Pivot, Table.Unpivot,
   List.Contains, List.Transform and List.Select, requiring ordering, dynamic
   schema, list representation, comparer or lambda analysis.

Each row records a possible input domain and unresolved risks. Substring aliases
need unit/boundary validation; round_even is only a starting point for ToEven.

## Independent semantic probes

The same SDK evaluated 12 constant M expressions. Independently, 17 SQL probes
used the installed ODBC engine **1.5.4** and a separate synthetic database. No MAW
or production data was used. These SQL statements were not emitted by the
connector and do not prove folding.

| Probe | M result | Direct SQL result | Implication |
| --- | --- | --- | --- |
| Length of a😀b | 4 | 3 | UTF-16 units differ from Unicode code points |
| Range(abcdef,4,99) / substr | Error | ef | Preserve range bounds and error behavior |
| Middle(abcdef,4,99) / substr | ef | ef | Middle and Range differ |
| PadStart(abcdef,3,0) / lpad | abcdef | abc | Prevent SQL truncation |
| Trim tab + space + abc + space + newline | abc | Tab/newline remain | Whitespace sets differ |
| Round(2.5) / round | 2 | 3 | Default tie breaking differs |
| Round(-2.5) / round | -2 | -3 | Negative ties require validation |
| null = null / NULL = NULL | true | NULL | Null-safe equality differs from SQL equality |
| PositionOf(abc,z) / strpos | -1 | 0 | Translate the not-found convention |
| Combine({a,null,b},-) / concat_ws | a-b | a-b | One matching case; order/empty lists still matter |
| Empty sum | null | NULL | This boundary matched |
| Monday-based DayOfWeek for Monday | 0 | 0 | Preserve firstDayOfWeek |

Five additional SQL probes checked positive/negative round_even, null-safe
equality, nontruncating CASE padding and guarded range failure. SQL error(...)
may abort the whole query and was not accepted as proof of M cell-error/try parity.

Sources use DuckDB **1.5** [text](https://duckdb.org/docs/1.5/sql/functions/text),
[numeric](https://duckdb.org/docs/1.5/sql/functions/numeric),
[date](https://duckdb.org/docs/1.5/sql/functions/date),
[aggregate](https://duckdb.org/docs/1.5/sql/functions/aggregates),
[list](https://duckdb.org/docs/1.5/sql/functions/list) and
[NULL](https://duckdb.org/docs/1.5/sql/data_types/nulls) references. The stable URL
redirected to 2.0 during research; those documents were not silently conflated
with measured 1.5 behavior.

## Acceptance for future implementations

Specify overloads, optional/null/default arguments, types, culture/comparer,
Unicode, empty inputs, numeric precision, ordering, nulls and errors. Function
name similarity is insufficient. Compare M, direct DuckDB and connector results
on synthetic inputs; verify emitted SQL and actual ODBC row budgets. Exit code
and folding flags alone are insufficient. Keep negative controls until actual
folding is demonstrated. Excel/Power BI host validation is a final, separate step.

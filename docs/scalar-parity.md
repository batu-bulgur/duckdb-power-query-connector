# First 14 M targets: implementation and measured boundaries

The target is calculations and GUI transformations over DuckDB data. The local
controls and host/source acquisition functions discussed in the inventory are
outside this SQL translation path. This document describes the current code;
the inventory remains its dated 705-entry research snapshot.

This is **not a declaration of complete M-language parity**. The 14 targets now
have substantially wider implementations, including a relational index plan.
Known SDK and native-engine failures are executable tests, not successful folding
cases. Unimplemented M expressions/table operators still decline translation;
there is no claim that every possible composition of these functions folds.

## SQL paths and transport

`DuckDB.pq` retains the existing ODBC source, public signature, authentication,
Unicode VARCHAR/NVARCHAR correction and string-escape suppression. Ordinary
supported operations continue through the SDK's native planner. The legacy
scalar visitor is a conservative fallback adapter; its old limits are not the
domain of the newer SQL calculation path.

`RelationalFolding.pqm` tracks projection, renaming, filtering, sorting, take/skip,
column calculations, grouping, distinct and index invocation. It keeps logical M
column names separate from generated SQL aliases. Empty names, case-only name
differences and unpaired UTF-16 names therefore do not become SQL identifiers.
This is a compiler for the exercised expression forms, not a general M VM.
It supports homogeneous conditional expressions and tracks inferred value types
separately from user-provided table-column annotations.

SQL result values can carry a value, its numeric representation and an error
channel. UTF-16 text is computed as integer units; JSON Unicode escapes preserve
unpaired surrogates across ODBC. Lists and logical values also have explicit
transport decoding. The client reconstructs values and native M error records;
it does not rerun the original per-row text/rounding/equality/index calculation.
Constant argument validation and the intentionally buffered M test oracles are
separate from those row calculations.

Predicate failures travel as a separate hidden row-error channel. Projection,
later filters, take/skip, sorting, grouping, distinct and index plans retain it.
This preserves both a prefix that stops before a failure and operations that
must encounter that failure. Count restores the native record through
[`Table.ViewError`](https://learn.microsoft.com/en-us/powerquery-m/table-viewerror),
preventing an error from triggering a local retry. Eight paired oracles require
one SQL calculation and one buffered M read, including full error-record equality.

## Function behavior now covered

| Function | Implementation and checks |
| --- | --- |
| Text.EndsWith | Native scalar path for ordinary default-comparer calls; UTF-16 SQL path for encoded text, unusual literals and explicit Ordinal/OrdinalIgnoreCase. Logical projections and predicates are checked. |
| Text.Length | UTF-16 units, nullable input, supplementary characters and encoded intermediate text. |
| Text.Middle | SQL unit slicing, dynamic start/count, omitted/null count, clipping, half-surrogate results, exact normal error records and validation precedence. One native CLR overflow family is guarded. |
| Text.Range | Separate offset/count bounds and validation order; dynamic values, null/omitted count, half-surrogates and full normal error records. |
| Text.PositionOf | First, Last, All, dynamic occurrence, empty needles, nonoverlapping All matches and UTF-16 offsets. Ordinal and OrdinalIgnoreCase are mapped. The native behavior of other numeric occurrence values is also tested. |
| Text.PadStart / Text.PadEnd | Dynamic target/pad, no truncation, UTF-16 target length, default/null space, NUL/unpaired-surrogate pad characters, normal range/character errors. |
| Text.Trim / Text.TrimStart / Text.TrimEnd | Exact M whitespace set; constant character/list or dynamic character; UTF-16 units including NUL and surrogates. Invalid constant argument types remain M validation. Row-dependent list construction has the SDK boundary below. |
| Number.Round | All five modes; dynamic digits/mode; entire Int32 digits endpoints; fractional/nonfinite/out-of-range digits follow M's original-value behavior; normal/subnormal/huge/nonfinite values; decimal sources and nested arithmetic/conditionals. Numeric representation is preserved. |
| Value.Equals / Value.NullableEquals | Type-tagged equality, null/NaN distinctions, default/explicit/dynamic numeric precision, primitive values, constant structures and lists produced by PositionOf. Boolean nesting, BLOB values, Int64 precision and 100 ns time-literal distinctions are tested. Arbitrary row-dependent constructors have the SDK boundary below. |
| Table.AddIndexColumn | Default/custom initial/increment/type; order before/after index; filter placement; take/skip; group/distinct prefixes; multiple indices; names and numeric precision. |

The old fixed Round limits (`-9..15`, `1e-14 <= abs(x) < 1e9`) and the old
constant-only substring/padding restrictions are not imposed by the main path.
This does not imply support for every other M function that can occur inside an
argument or before/after a target call.

## Numeric and index details

`RoundScalar.pqm` follows the pinned SDK's decimal conversion and 96-bit decimal
arithmetic, including its exact Int64 fast path and the effects of adding one
half at the decimal precision limit. Simply using DuckDB ROUND/ROUND_EVEN or a
15-digit formatted double did not match the M matrix. SQL integer coefficients
and explicit scale/mode handling preserve those results. Original DOUBLE return
paths are distinguished from normal DECIMAL results during decoding.

`IndexSql.pqm` uses ROW_NUMBER to represent positions while retaining a hidden
input ordinal. A sort establishes a new ordinal; filtering before an index
renumbers its input, while filtering afterward preserves the assigned values.
Safe integer ranges use direct arithmetic. Other increments use a recursive SQL
sequence with one IEEE-754 addition per step, matching M rather than assuming
`initial + ordinal * increment`. A following direct take bounds that sequence.
Large absorbed increments and the initial value's representation are handled
separately. An unordered source is indexed in its observed scan order; no
synthetic fixture ID is substituted for that order.

Text ordering uses UTF-16 units. Numeric ordering handles null, NaN, infinities
and Double comparison ties. Group/distinct tracking also preserves M's separate
NaN groups/rows. The module does not yet track every table operator in the M
library (for example, arbitrary join/pivot/unpivot plans); such compositions
must not be reported as complete index folding without a measured test.

## Reproducible external boundaries

1. **Row-dependent List/Record construction is unavailable through the pinned
   public expression hook.** Both
   `RowExpression.From(each Value.Equals({[id],1},{1,1}))` and the analogous
   record constructor fail with `We can't get the expression for the specified
   value.` The calculation itself works in M. `parity_blocker_ast` proves the
   extraction failure without ODBC; `structural_equals` proves a correct local
   result and rejects its SQL folding claim. Constant structures and known list
   results are distinct from this inaccessible constructor case. Full support
   needs an SDK expression/constructor hook, or a separately designed explicit
   query/AST interface; claiming the existing scalar hook already exposes it is
   incorrect.
2. **Culture comparers capture opaque context.** An exposed
   `Comparer.FromCulture("tr-TR",true)` is a function with empty metadata and is
   neither Ordinal nor OrdinalIgnoreCase. Its culture/options/body are not in
   that constant AST. A fixed DuckDB collation cannot be selected from this
   payload while promising the M contract. `parity_blocker_culture` and the
   `culture_comparer` negative reproduce this. A serializable culture/comparer
   contract and an M-compatible collation implementation are still required.
3. **Native Round CLR failure:** even
   `try Number.Round(7.92281625142643e28,-28,RoundingMode.Up)` fails the SDK
   evaluation with inner error `Value was either too large or too small for a
   Decimal.` It does not produce a normal catchable M error record. The five
   such mode combinations are retained as a separate failure boundary rather
   than silently treated as successful values.
4. **Native Middle CLR failure:** even
   `try Text.Middle("abc",1,2147483647)` fails evaluation with an uncatchable
   CLR length exception. Positive starts within the string whose start+count
   overflows Int32 form the reproduced family. The SQL guard prevents a silent
   successful slice. The 60 affected Middle matrix pairs are excluded from
   normal value comparison; Range is separately checked on those same pairs.

The native failures are in `test/boundaries` and checked by
`tools/Test-NativeBoundaries.ps1`. Any change in these failures deliberately
fails verification so the guards and matrix exclusions can be reassessed.
There is no claim that a DuckDB DataSource.Error is identical to an uncatchable
CLR exception from the M engine.

OrdinalIgnoreCase is implemented separately from culture comparers.
`OrdinalIgnoreCase.pqm` contains 973 equal-case pairs measured by the pinned SDK
across all 1,112,064 Unicode scalar values. The all-pair/exclusion test exercises
980 inputs and folds its seven false results down to seven ODBC rows. It retains
M distinctions for Turkish I, long s, sigma variants, Kelvin sign and supplementary
case pairs; substituting DuckDB UPPER would change those results. This mapping
is versioned evidence for this SDK/host, not a promise about all future NLS/M
versions.

## Verification contract

- `test-parity`: source-free M references plus corresponding connector cases.
- `test-folding`: exact result/type baselines, strict folding, exactly one
  successful ODBC query, SQL algorithm assertions and row budgets.
- Buffered differential oracles: one actual SQL calculation read and one raw
  source read for normal M calculation; retries/extra requests are rejected.
  They include 41,595 Round value cases, 6,040 slice value/error cases, 60 Range
  boundary cases, 140 REAL/UInt64/DECIMAL(38) cases, 45 complete error-record
  cases, eight predicate-error composition cases and index precision/type cases.
- Negative controls: native-query transform, inaccessible structural constructor
  and culture comparer. A correct M result must pass before folding is rejected.
- Native failure checks: the two uncatchable SDK failures above.
- Build: exact project resource allowlist/source hashes, extension load and
  parsing of every packaged module. Baselines are never regenerated by tests.

## 0.4.0 delivery integration

The delivery audit rebases the completed research snapshot onto the tested
personal-fork main, preserving the 0.3.0 standard-deviation mapping, version
policy and CI gates. The scalar visitor explicitly retains the aggregate's
Double result type; treating it as text caused the million-row aggregate/filter
case to retry locally. That regression still requires one ODBC row and one query.
An additional index-then-standard-deviation case verifies both paths together.

The integrated suite contains 27 functional cases, 100 pure M references and
142 folding cases: all 40 released core cases, the 101 parity cases and that
additional integration regression. The existing 3 negative controls, 2 native
failure reproducers, 10 runner rejections and version/package guards also remain
required. The six-process coordinator checks exhaustive, disjoint completion
and hashes of one immutable 18-resource package. Fresh Windows child processes
explicitly decode PQTest JSON as UTF-8; no system locale is changed.

The following receipt belongs to the earlier uncommitted snapshot. Its package
hash is not the versioned 0.4.0 artifact identity. Final delivery uses fresh local
verification, followed by the exact PR/main CI runs and successful-main release
manifest. The versioned GitHub release and manifest are the authority for its
downloadable binary, commit, hosted toolchain and checksum.

## Original measured receipt — 2026-11-12

All `verify` sub-suites passed on one immutable MEZ, SHA-256
`72CD0002919E2AD43C61229B0DFD045A5FAFF1DAB999A5C191B7B649388C5D88`.
The independent suites ran in parallel; this receipt is for the complete set of
sub-suites, rather than a claim that a single sequential `verify` invocation
completed. The normal `./tools/dev.ps1 verify` runs the same checks sequentially.

| Check | Result |
| --- | --- |
| Functional cases | 26 passed, including 47,938 buffered differential value/error checks |
| Source-free M references | 100 passed, including executable SDK boundary probes |
| Strict folding cases | 135 passed: 101 parity cases and all 34 existing core cases |
| Index folding cases, included above | 24 passed, including logical/text annotations followed by numeric sorting |
| Negative controls | 3 correct-result cases rejected as folding successes |
| Native failure reproducers | 2 expected uncatchable failures reproduced without ODBC |
| Runner failure controls | 10 invalid result/SQL/row-evidence scenarios rejected |
| Package integrity | 18 allowlisted archive resources matched current source hashes |
| Test integrity | All 264 baselines and 279 test/tool files unchanged during the measured run |

The four disjoint folding partitions were `parity_[a-m]*` (53),
`parity_[n-z]*` (48), `[a-o]*` (5), and `[q-z]*` (29). Their union was checked
against all 135 folding query files with no omission or duplicate. A final audit
re-read the result JSON and SQL/ODBC evidence for every folding case.

Raw evidence is intentionally ignored under `.agent/`: functional run
`test/20261112-042339-e3b797e0`; folding runs `test/20261112-042339-bada7fb9`,
`test/20261112-042339-66827610`, `test/20261112-042340-c0fdb10e`, and
`test/20261112-042439-6e45b87a`; reference run
`parity-reference/e7f307aa13634ca2b26d6f83c09bccc7`; negative controls
`negative-controls/a5ccdb9b38ac4cc5b12dc6ff2610fdcb`; native failures
`native-boundaries/ff370ebb3bee4e539381029898dc369d`. The immutable identity and
audit receipt are in `full-parity/release/1bd9e9ac025d40a1a5e37e1f84434d09/`.
The intentional build output is `bin/AnyCPU/Debug/DuckDB.mez` with the same hash.

SDK 2.155.2 and installed DuckDB ODBC engine v1.5.4 are the measured local
environment. Power BI Desktop GUI, Excel integration, hosted CI and other engine
versions remain separate checks. No installed driver, DSN, trust setting or user
app session was changed. The boundaries above remain open; these successful
tests do not mark the entire M language or all possible compositions complete.

## Historical first-subset receipt

The preceding iteration (before this expansion) passed 8 functional cases, 37 M
references, 70 folding cases, 5 negatives and 10 runner rejection checks. Its
12-resource MEZ hash was
`9C31FEFB446E0B2F2971E681C500A29E3CA9462680CAE29FE1B4B3AFED4BD930`.
That receipt does not establish the later code's behavior. The old raw receipt
remains ignored under `.agent/first14`.

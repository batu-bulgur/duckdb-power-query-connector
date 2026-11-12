# GUI text extraction, replacement, splitting and combining

## Implemented functions

The next inventory group contains Text.Start, Text.End, Text.Replace,
Text.Split and Text.Combine. These are priority-two text candidates after the
first scalar/index group and date group. Selection reflects common GUI
operations, not measured usage telemetry.

`TextShape.pqm` performs extraction and ordinal matching on UTF-16 units.
It preserves supplementary characters, isolated surrogates, embedded NUL,
empty strings and nullable text. Start/End clamp a valid count to the available
length. Counts use M's Int32 validation, including exact encoded decimal
integrality rather than a lossy DOUBLE test. Replace and Split use the same
nonoverlapping match positions. An empty old/separator produces unchanged
text/a one-element list, matching the measured M behavior.

Split lists retain ordered UTF-16 items and item error channels. Combine
ignores null items, preserves empty items, accepts omitted/null separators and
supports dynamic separators. The SQL backend determines errors and their
precedence. The client reconstructs values and native type-error records with
typed identity validators; it does not rerun Start/End/Replace/Split/Combine.
Type errors retain nullable versus nonnullable target types, Message, Detail,
format/parameters and ErrorCode. Non-text constant list elements, invalid
scalar arguments and nested errors are covered by paired M comparisons.

SQL supports list consumers Count, First and Last for represented text lists.
These adapters do not claim general parity for every List function/overload.
Text-to-text identity conversion preserves encoded text through GUI type
annotations. GUI TransformColumns, ReplaceValue with ReplaceText, and
CombineColumns with the ordinary delimiter combiner are tested separately.

## Expression extraction and genuine SDK boundaries

The regular RowExpression extractor rejects row-list constructors with error
10593. The compiler also attempts `Value.Expression(Value.Optimize(fn))` and
validates direct row-field bindings before translating the resulting syntax.
Constant-separator column merges can thereby remain in SQL, including the
normal GUI CombineColumns path. No expression is inferred from sample outputs.

The pinned SDK has an earlier dispatch boundary as well. The standalone
`parity_shape_handler_contract` reference returns a sentinel from OnAddColumns.
It proves that Start, constant lists and fixed-separator column lists reach the
handler, whereas a field-list constructor with a row-dependent separator and
list `{index}` access do not. The optimized expression API can expose these
syntax nodes in isolation, but it does not make the table operation dispatch
them to the connector. Their correct-result negative controls must reject a
folding-success claim. Indexed split consumption can use the separately tested
First/Last adapters where their semantics are appropriate.

GUI Table.SplitColumn with its generated splitter is also a correct-result
negative. Its closure does not expose a sound delimiter/quote contract to the
current compiler. Full GUI splitting needs an engine-supported expression/
handler contract or another explicit, verifiable representation. The entire
GUI split/merge family is not marked complete by this scalar implementation.

## Current driver compatibility

At this task's start, the installed driver reported engine v2.0.0. It rejects
the old single-arrow SQL lambda syntax by default. An actual SDK/ODBC call
reproduced the rejection before changes. SQL emission now uses the Python-style
`lambda x: ...` syntax for both the new module and shared UTF-16/equality
helpers. This syntax is supported by the separately pinned CI ODBC 1.4.4.0;
the official [1.4 lambda documentation](https://duckdb.org/docs/1.4/sql/functions/lambda)
describes both forms. No driver registration, DSN or session setting is changed.

The first hosted run also caught a 1.4.4 nested-list reduction defect: repeated
identical text/pattern rows could produce different accepted match positions.
The consumers matrix reported 43 mismatches out of 5,760 comparisons, while its
local 2.0.0 counterpart passed. Replaying the captured SQL directly in 1.4.4
reproduced inconsistent overlap positions. The reducer now keeps only scalar
fields (last match and an internal comma-separated position string), then
converts those positions back to a BIGINT list. The repeated-overlap strict
case and the original unchanged differential expectations guard this fix.

## Validation contract

Six paired matrices compare 28,335 values/errors against independently
buffered M input, including every output's physical SQL alias. This prevents a
partially local calculation from passing because an earlier column folded.
The matrix sources are synthetic: UTF-16 edge strings, overlapping patterns,
empty/null delimiters and replacements, dynamic counts, Int32 extremes,
NaN/infinity, and decimals immediately either side of an integer.

Strict cases additionally check expected data, the SDK folding flag, one
successful SQL/ODBC query and its transfer budget. They include surrogate
boundaries, GUI paths, grouping/distinct/index chains and a million-row filter.
Source-free M references and correct-result negative controls remain separate.
The required complete suite contains 189 distinct strict folding cases,
42 functional tests, 120 source-free references, seven negative controls,
four native failure reproducers and 16 runner rejection controls. The new group
contributes 27 strict cases and 28,335 paired comparisons; total paired scalar
coverage is 217,707. The million-row filter has a one-row transfer budget.
All 20 allowlisted package resources must match the source and load in the SDK.

Local complete verification uses SDK 2.155.2 and installed ODBC engine v2.0.0.
Hosted PR/main verification independently uses pinned ODBC 1.4.4.0. Both must
pass before delivery; final source/hash receipts and hosted results are linked
from [PR #10](https://github.com/batu-bulgur/duckdb-power-query-connector/pull/10).
Ignored `.agent` receipts remain local evidence. Published assets have separate
checksums and source-integrity verification against the release commit.

SDK/ODBC evidence does not establish Excel or Power BI Desktop GUI integration.
Existing native TIMESTAMPTZ/UTC-range boundaries remain in date-parity.md.

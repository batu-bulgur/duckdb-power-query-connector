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
The final local complete suite passed on 2026-11-13 with SDK 2.155.2 and the
installed ODBC engine v2.0.0: 188 distinct strict folding cases, 42 functional
tests, 119 source-free references, seven negative controls, four native failure
reproducers and 16 runner rejection controls. The new group contributes 26 strict
cases and 28,335 paired comparisons; total paired scalar coverage is 217,707.
The million-row filter transfers one ODBC row. All 20 allowlisted package
resources match the source and the SDK loads the artifact.

The local complete-suite receipt is
`.agent/verification/aac4fdab323f4585a68920d45fac192d/summary.json`, with MEZ SHA256
`976B92EC608225A4F624B36D35CC3118E2317AF175FE1DC7EE8F0139F47FF6B4`.
These ignored files are local evidence, not published assets. Hosted PR/main
verification must independently pass with pinned ODBC 1.4.4.0 before release;
its published artifact has separate checksums and source-integrity verification.

SDK/ODBC evidence does not establish Excel or Power BI Desktop GUI integration.
Existing native TIMESTAMPTZ/UTC-range boundaries remain in date-parity.md.

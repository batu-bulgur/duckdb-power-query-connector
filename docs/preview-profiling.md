# Preview profiling and aggregate folding

## Trigger and root cause

Power Query can evaluate column profiles separately from the displayed preview.
The observed host operations were `TableResultColumnProfiles` and
`DetailsPaneColumnProfiles`. Their aggregate expressions include
`List.Count([column])`, `List.Count(List.Distinct([column]))` and
`List.Count(List.Select([column], predicate))`, combined with the ordinary
minimum, maximum, average and standard deviation calculations in `Table.Profile`.

Before this change, the relational compiler did not represent these native
column count expressions. The combined group therefore fell back to local M
evaluation and read source rows through ODBC. A preview limit on a separate
evaluation does not bound that read. Large local profiling reads can also lead
to allocation failures and retries. The connector does not initiate the host's
profiling requests; it determines whether those requests can execute in SQL.

The original interactive timing was an overall editor completion time, not an
isolated DuckDB execution time. SDK/ODBC evidence does not establish the final
Power BI Desktop editor latency after this change.

## Representation

An aggregate group containing an unencoded native column count enters a separate
profile compiler. Supported counts use `COUNT(*)`, filtered counts and distinct
counts with an explicit NULL contribution. Existing scalar text-list counts and
ordinary aggregate groups retain their existing compilation path.

All aggregates in the group must be represented. Unknown overloads, transformed
encoded columns, unguarded numeric classifiers, unsupported predicates, native
TIMESTAMPTZ, DECIMAL/NUMERIC columns and unsupported additional aggregates decline this path. Decimal-to-double conversion differs between M and native SQL at precision boundaries, so these columns retain M evaluation. In
particular, a nested `Table.RowCount(Table.SelectRowsWithErrors(...))` must not
become `COUNT(*)`: an error count is not a row count.

The SQL preserves the relevant M/ODBC value semantics:

- NaN is unequal to itself in M, so each NaN contributes to distinct count.
  A NaN precedes ordinary numbers for minimum; maximum ignores NaNs when an
  ordinary non-NULL number exists. Non-finite standard deviation yields NaN,
  and a single finite non-NULL value has zero standard deviation.
- Numeric comparisons/distinctness and default arithmetic use M's double precision. Numeric extrema retain the first original value on a comparison tie, including adjacent Int64 values above 2^53.
- Text extrema compare UTF-16 units, including supplementary-plane characters.
- Native BOOLEAN values use the existing ODBC text representation. Native TIME
  extrema/counts use the existing whole-second representation; TIME average
  remains outside this path.
- Date and datetime averages use HUGEINT 100 ns ticks from year 1 and truncate
  the quotient, matching M. Datetime averages travel through the existing
  temporal decoder so their seventh fractional digit is retained. Native
  timestamp calibration, including TIMESTAMP_NS normalization, happens before
  equality, ordering and aggregation.
- Guarded numeric classification predicates preserve the M null error boundary.
  `Number.IsEven` and `Number.IsOdd` use floor, including negative fractions;
  NaN and infinities match neither parity. These primitives are enabled only
  inside the profile predicate compiler.
- Empty profiles retain M's scalar-default evaluation. No request limit is
  silently added to an entire-dataset profile, and existing filters and samples
  remain in the aggregate SQL.

## Regression evidence

The synthetic fixture contains one million ordinary rows plus small edge
tables. Strict folding contracts check correct M results, required SQL, one
data-query start/finish pair and ODBC rows. Profiles return one aggregate row;
timestamp cases separately declare their small catalog/calibration request.

The same million-row numeric profile was replayed against an artifact built
from the unchanged 0.6.1 base: both versions returned the expected result, while
ODBC reported 1,000,000 transferred rows before the change and one after it.

The cases cover a full numeric profile, a 1,000-row sample, a filtered profile,
NaN/NULL/UTF-16/BOOLEAN/date/datetime values, stable Int64 comparison ties, custom numeric
counters, negative fractional parity, and year-1/year-9999/submicrosecond
datetime averages. Functional controls cover empty input, nested error counts
and unguarded null errors. A source-free M oracle checks 18 datetime average
precision cases independently of SQL.

Run the final verification with:

```powershell
./tools/Verify-Change.ps1 -BaseRef origin/main -Connector bin/AnyCPU/Debug/DuckDB.mez
```

Host integration is separate. This change does not change the New Power Query
experience, column profiling preferences, custom connector trust settings,
installed drivers or DSNs. Delivery uses the versioned GitHub release artifact.

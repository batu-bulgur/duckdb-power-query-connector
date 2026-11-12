# GUI date calculations and measured boundaries

## Selection and scope

The next inventory group covers eight date-menu operations. Selection follows
the inventory's priority-two candidates and common GUI workflows, not measured
user telemetry. Existing first-14 work remains in [scalar-parity.md](scalar-parity.md).

| M function | GUI operation | SQL calculation |
| --- | --- | --- |
| [Date.Year](https://learn.microsoft.com/en-us/powerquery-m/date-year) | Extract year | YEAR over the represented local date |
| [Date.Month](https://learn.microsoft.com/en-us/powerquery-m/date-month) | Extract month | MONTH |
| [Date.Day](https://learn.microsoft.com/en-us/powerquery-m/date-day) | Extract day | DAY |
| [Date.DayOfWeek](https://learn.microsoft.com/en-us/powerquery-m/date-dayofweek) | Day of week | DOW adjusted by explicit or host-captured first day |
| [Date.AddDays](https://learn.microsoft.com/en-us/powerquery-m/date-adddays) | Add/subtract days | Bounded Gregorian day ordinal |
| [Date.AddMonths](https://learn.microsoft.com/en-us/powerquery-m/date-addmonths) | Add/subtract months | Bounded month ordinal and clipping |
| [Date.StartOfMonth](https://learn.microsoft.com/en-us/powerquery-m/date-startofmonth) | Start of month | DATE_TRUNC and kind restoration |
| [Date.EndOfMonth](https://learn.microsoft.com/en-us/powerquery-m/date-endofmonth) | End of month | LAST_DAY and exact final M tick |

Mappings cover known date, datetime and explicit-offset M datetimezone values,
nulls, dynamic numeric arguments, nested calculations, date conditionals and
ordinary M errors. M still validates arguments outside the declared number
parameter type. Existing unavailable AST constructors and other untranslated
surrounding expressions are not claimed as supported.

## Representation and errors

`DateScalar.pqm` performs calendar arithmetic in SQL with day/month ordinals
bounded to years 1 through 9999. Fractional, nonfinite and out-of-Int32 arguments
follow M's validation order. Encoded decimals are checked from coefficient/scale
text, avoiding an inexact DOUBLE test or an overflowing scientific-string cast.
Default DayOfWeek captures the active M host's first-day behavior at compile time;
it does not change locale or assume that every host starts on Sunday.

ISO transport retains seven fractional digits and an explicit fixed offset.
EndOfMonth for datetime/zone produces `23:59:59.9999999`; passing it through
DuckDB's microsecond TIMESTAMP would change the answer. The client restores the
temporal kind and value without rerunning the target date operation. Temporal
comparisons/equality/sorting use compatible keys, including UTC instant keys for
explicit M datetimezone. Same-kind date conditionals and nullable branches work.

Native error templates preserve Reason, Message, Detail, format/parameters and
ErrorCode. Date and DateTime range errors differ. DayOfWeek validates its day
before rejecting a non-date value; other functions use their own ordering.

Owned SQL views use `Table.View(null, handlers)`: GetType/GetRows supply their
result. A native shadow base made the SDK attempt an untranslatable native index
before reaching the owned SQL handlers. The date/filter/sort/index regression
checks the correction with strict folding enabled.

## Native ODBC input conversion

Parity is against values M actually reads. On the pinned SDK/measured driver,
BOOLEAN is read as text, TIME loses its fraction, and TIMESTAMP_NS is converted
to microseconds by truncating the epoch count toward zero. Examples:

- BOOLEAN TRUE becomes the M text `"true"`.
- TIME `12:34:56.123456` becomes `#time(12,34,56)`.
- NS `.123456700` becomes `.123457` before the Unix epoch and `.123456` after it.

Operands mirror those conversions. The old time-equality baseline had assumed
the SQL TIME fraction survived the driver. Its expected result changes from true
to false, with a matching source-free input correction and a buffered-native-value
oracle. The expectation is based on actual M input, not regenerated SQL output.

## Native TIMESTAMPTZ context boundary

ODBC exposes TIMESTAMP and TIMESTAMPTZ with the same native schema name. A cached,
table-scoped `duckdb_columns()` lookup separates their physical types. It is one
separately checked catalog request, not a per-row query. DATE and explicit M
datetimezone inputs do not need that lookup.

Native TIMESTAMPTZ requires the M host's timezone rules. On the measured Windows
Istanbul host, a synthetic 1900 value rendered as `12:34:56.123456` using DuckDB's
IANA conversion but `12:38:00.123456` when M read it using Windows rules. A CAST
or server timezone selection cannot promise the same historical local clock.
The public ODBC schema does not serialize the host's full rule context. General
folding needs that context and an equivalent backend conversion.

This path explicitly stops folding and uses M. The `date_native_timezone`
negative checks 20,196 buffered result/error comparisons before rejecting folding.
It is portable across hosts where the specific historical offsets agree; the
classification guard remains explicit. Failed physical-type discovery also
declines safely rather than assuming a timezone conversion.

## Native UTC-range failure

Even M `try` cannot catch the pinned engine's CLR offset failure for:

```powerquery
try Date.StartOfMonth(#datetimezone(1,1,15,0,0,0,14,0))
try Date.EndOfMonth(#datetimezone(9999,12,1,0,0,0,-14,0))
```

Both fail with `The UTC time represented when the offset is applied must be
between year 0 and 10,000.` and parameter `offset`. Reproducers live in
`test/boundaries/date_zone_native_min.pq` and `date_zone_native_max.pq`.
Row-dependent SQL guards this range instead of returning a successful value.
A backend DataSource.Error is not claimed identical to the uncatchable CLR error.

## Validation

Focused coverage includes 20 strict result/SQL/data-row folding cases, eight
source-free M baselines and nine paired oracles. Seven 2,244-row matrices check
141,372 values/errors over dates, timestamps, NS input, invalid primitives and
three explicit offsets. Extra oracles check native values and exact decimal
arguments. The million-row filter transfers three rows. Complete-suite evidence
is recorded after final artifact verification.

Timestamp catalog traffic has separate successful identifiers, SQL shape and
small row budgets. The calculation retains its own transfer budget; the SDK's
cumulative counter is adjusted only by validated catalog rows. Existing contracts
keep their one-query requirement. Runner controls reject extra/failed/oversized
catalog reads and invalid adjusted row counts.

SDK/ODBC tests do not establish Excel or Power BI Desktop GUI integration.
Installed drivers, DSNs, sessions, locale and trust settings are unchanged.

## Local complete-suite receipt — 2026-11-12

`Verify-Change.ps1 -BaseRef origin/main -Connector bin/AnyCPU/Debug/DuckDB.mez`
selected full scope and completed all six parallel partitions successfully.
The checked package has 19 source-matched resources and SHA-256
`AC45D7B9C54D5DB1DA593F5DABB0FD7EBAFEFC81976916C3C671F517333552D9`.

| Check | Result |
| --- | --- |
| Functional cases | 36 passed |
| Direct buffered M value/error checks | 189,372 passed, including 141,434 new date/input checks |
| Source-free M references | 108 passed |
| Strict SQL/data-row folding cases | 162 distinct cases passed, including 20 new date cases |
| Negative controls | 4 correct-result cases rejected as folding successes |
| Native failure reproducers | 4 expected failures reproduced without ODBC |
| Evidence-runner rejection controls | 15 passed |
| Validation-scope policy cases | 33 passed |

The coordinator rechecked package/source hashes and rejected missing, duplicate
or unexpected completed folding case names. Local evidence is intentionally
ignored under `.agent/verification/5c7595bcbf584c429c90e6d1fc1b7cf5/`.
The functional run is `.agent/test/20261112-124255-3003743f/`, references are in
`.agent/parity-reference/ce2505463f084239a8cd347c3a04800b/`, negatives in
`.agent/negative-controls/9e23f073eb5a41e88d102507a5f7b226/`, and native failures
in `.agent/native-boundaries/b75e2a2658ed459a85dcfcd7a9db57e0/`.
Measured environment: SDK 2.155.2, installed ODBC engine v1.5.4. Hosted CI's
pinned ODBC 1.4.4.0 is a separate required run, not inferred from this receipt.

// For n consecutive equally spaced numbers, sample SD = step * sqrt(n * (n + 1) / 12).
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="folding"]}[Data],
    stats = Table.Group(data, {}, {
        {"sd", each List.StandardDeviation([amount]), type nullable number},
        {"rows", each Table.RowCount(_), Int64.Type}
    }),
    // Independently calculated SD is 360844.09866543015. Use an absolute
    // tolerance of 0.000001 for floating-point aggregation, not a driver snapshot.
    checked = Table.SelectRows(stats, each [sd] > 360844.09866443015 and [sd] < 360844.09866643015),
    result = Table.SelectColumns(checked, {"rows"})
in
    result

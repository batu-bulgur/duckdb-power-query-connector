// Sample SD, nulls, singleton, constants, large offset, numeric types, and quoted identifiers.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="stddev_cases"]}[Data],
    grouped = Table.Group(data, {"grup"}, {
        {"sd", each List.StandardDeviation([#"ölçüm""değeri"]), type nullable number},
        {"integer_sd", each List.StandardDeviation([integer_value]), type nullable number},
        {"decimal_sd", each List.StandardDeviation([decimal_value]), type nullable number}
    }),
    result = Table.Sort(grouped, {{"grup", Order.Ascending}})
in
    result

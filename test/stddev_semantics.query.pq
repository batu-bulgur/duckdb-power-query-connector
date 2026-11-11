// Table.Buffer forces the reference calculation into M; the small fixture has no customer data.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="stddev_cases"]}[Data],
    calculate = (input) => Table.Sort(Table.Group(input, {"grup"}, {
        {"sd", each List.StandardDeviation([#"ölçüm""değeri"]), type nullable number},
        {"integer_sd", each List.StandardDeviation([integer_value]), type nullable number},
        {"decimal_sd", each List.StandardDeviation([decimal_value]), type nullable number}
    }), {{"grup", Order.Ascending}}),
    folded = Table.ToRows(calculate(data)),
    local = Table.ToRows(calculate(Table.Buffer(data)))
in
    #table(type table [matches_local_M = logical], {{folded = local}})

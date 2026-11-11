// Three equally spaced values at the end of the million-row fixture have sample SD 1.25.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="folding"]}[Data],
    tail = Table.SelectRows(data, each [id] >= 999997),
    result = Table.Group(tail, {}, {{"sd", each List.StandardDeviation([amount]), type nullable number}})
in
    result

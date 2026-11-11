// UI-style table transformations; no SQL in the analysis query.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="folding"]}[Data],
    result = Table.Sort(Table.Group(data, {"category"}, {{"total", each List.Sum([amount]), type nullable number}}), {{"category", Order.Ascending}})
in
    result

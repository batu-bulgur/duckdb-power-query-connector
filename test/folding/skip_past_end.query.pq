// UI-style table transformations; no SQL in the analysis query.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="folding"]}[Data],
    result = Table.Skip(Table.Sort(Table.SelectColumns(data, {"id", "amount"}), {{"id", Order.Ascending}}), 1000005)
in
    result

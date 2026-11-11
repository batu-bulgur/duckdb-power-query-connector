// UI-style table transformations; no SQL in the analysis query.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="folding"]}[Data],
    result = Table.FirstN(Table.Sort(Table.SelectColumns(Table.SelectRows(data, each [category] = "odd" and [id] >= 999990), {"id"}), {{"id", Order.Ascending}}), 3)
in
    result

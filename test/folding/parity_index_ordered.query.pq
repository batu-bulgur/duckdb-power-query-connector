// Preserve an explicit unique order and custom initial/increment in SQL.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="negative-control"]),
    data = src{[Item="folding"]}[Data],
    ordered = Table.Sort(Table.SelectColumns(data, {"id"}), {{"id", Order.Ascending}}),
    indexed = Table.AddIndexColumn(ordered, "index", 10, 5, Int64.Type)
in
    Table.FirstN(indexed, 3)

// Deliberate local operation: the SQL evidence guard must reject it.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="negative-control"]),
    data = src{[Item="smoke"]}[Data],
    indexed = Table.AddIndexColumn(data, "index", 0, 1, Int64.Type)
in
    Table.FirstN(indexed, 3)

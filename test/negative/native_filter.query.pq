// Upstream's native-query handler explicitly does not support subsequent folding.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="negative-control"]),
    data = Value.NativeQuery(src, "SELECT id FROM folding", null, [EnableFolding=true]),
    filtered = Table.SelectRows(data, each [id] >= 999990)
in
    Table.FirstN(Table.Sort(filtered, {{"id", Order.Ascending}}), 3)

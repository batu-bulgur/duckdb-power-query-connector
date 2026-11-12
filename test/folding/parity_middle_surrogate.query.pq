// A lone UTF-16 unit crosses ODBC through the encoded result transport.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="negative-control"]),
    data = src{[Item="parity_text"]}[Data],
    one = Table.SelectRows(data, each [id] = 1),
    result = Table.AddColumn(one, "value", each Text.Middle([label], 2, 1), type text)
in
    Table.SelectColumns(result, {"id", "value"})

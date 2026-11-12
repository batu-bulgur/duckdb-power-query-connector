let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="scalar-parity-regression"]),
    data = src{[Item="parity_text"]}[Data]
in
let
    filtered = data,
    calculated = Table.AddColumn(filtered, "value", each Text.EndsWith([label],"b"), type nullable logical),
    result = Table.Sort(Table.SelectColumns(calculated, {"id", "value"}), {{"id", Order.Ascending}})
in result

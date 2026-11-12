let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="scalar-parity-regression"]),
    data = src{[Item="parity_text"]}[Data]
in
let
    filtered = Table.SelectRows(data, each [id]<>11),
    calculated = Table.AddColumn(filtered, "value", each Number.Round([amount],0,RoundingMode.Down), type nullable number),
    result = Table.Sort(Table.SelectColumns(calculated, {"id", "value"}), {{"id", Order.Ascending}})
in result

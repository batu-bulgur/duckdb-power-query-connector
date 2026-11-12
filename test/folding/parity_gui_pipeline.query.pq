let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="scalar-parity-regression"]),
    data = src{[Item="parity_text"]}[Data]
in
let
    trimmed=Table.TransformColumns(data, {{"label",Text.Trim,type nullable text}}),
    padded=Table.TransformColumns(trimmed, {{"label",each Text.PadStart(_,5,"0"),type nullable text}}),
    measured=Table.AddColumn(padded,"n",each Text.Length([label]),Int64.Type),
    selected=Table.SelectRows(measured, each [n]=5),
    result=Table.Sort(Table.SelectColumns(selected,{"id","label"}),{{"id",Order.Ascending}})
in result

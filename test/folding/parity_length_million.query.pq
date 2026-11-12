let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="scalar-parity-regression"]),
    data=src{[Item="folding"]}[Data]
in
Table.FirstN(Table.Sort(Table.SelectColumns(Table.SelectRows(data, each Text.Length([label])=11 and Text.EndsWith([label],"999999")), {"id"}), {{"id",Order.Ascending}}),3)

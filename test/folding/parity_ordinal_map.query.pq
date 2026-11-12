let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="ordinal-map-regression"]),
    data=src{[Item="parity_ordinal_pairs"]}[Data],
    calculated=Table.AddColumn(data,"eq",each Text.EndsWith([label],[other_label],Comparer.OrdinalIgnoreCase),type logical)
in Table.Sort(Table.SelectColumns(Table.SelectRows(calculated,each [eq]=false),{"id","eq"}),{{"id",Order.Ascending}})

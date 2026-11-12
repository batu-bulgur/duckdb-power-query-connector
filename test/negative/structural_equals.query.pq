// The pinned SDK cannot expose a row-dependent List/Record constructor AST.
let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="structural-boundary"]),
    data=Table.SelectRows(src{[Item="parity_text"]}[Data],each [id]<=2),
    calculated=Table.AddColumn(data,"eq",each Value.Equals({[id]},{1}),type logical)
in Table.Sort(Table.SelectColumns(calculated,{"id","eq"}),{{"id",Order.Ascending}})

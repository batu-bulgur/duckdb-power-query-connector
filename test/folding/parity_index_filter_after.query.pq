let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="index-parity"]), data=Table.SelectColumns(src{[Item="folding"]}[Data],{"id"}) in
Table.SelectRows(Table.AddIndexColumn(Table.Sort(data,{{"id",Order.Ascending}}),"ix",10,5,Int64.Type),each [id]>=999997)

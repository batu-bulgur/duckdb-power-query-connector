let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="index-parity"]), data=Table.SelectColumns(src{[Item="folding"]}[Data],{"id"}) in
Table.FirstN(Table.AddIndexColumn(Table.Sort(data,{{"id",Order.Descending}}),"ix",-5,-2,Int64.Type),3)

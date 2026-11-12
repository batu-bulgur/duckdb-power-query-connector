let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="index-parity"]), data=Table.SelectColumns(src{[Item="folding"]}[Data],{"id"}) in
Table.FirstN(Table.Skip(Table.AddIndexColumn(Table.Sort(data,{{"id",Order.Ascending}}),"ix"),999997),2)

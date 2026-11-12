let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="index-parity"]), data=Table.SelectColumns(src{[Item="folding"]}[Data],{"id"}) in
Table.FirstN(Table.AddIndexColumn(Table.Sort(data,{{"id",Order.Ascending}}),"ix",0.5,0.1,type number),3)

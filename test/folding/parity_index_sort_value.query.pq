let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="index-precision"]),data=src{[Item="smoke"]}[Data] in
Table.FirstN(Table.Sort(Table.AddIndexColumn(data,"ix",0,2),{{"ix",Order.Descending}}),3)

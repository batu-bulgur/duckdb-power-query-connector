let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="ordering-parity"]),data=src{[Item="parity_ordering"]}[Data] in
Table.SelectColumns(Table.AddIndexColumn(Table.Sort(data,{{"amount",Order.Ascending}}),"ix"),{"id","ix"})

let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="ordering-parity"]),data=src{[Item="parity_ordering"]}[Data] in
Table.SelectColumns(Table.AddIndexColumn(Table.Sort(Table.Distinct(Table.SelectColumns(data,{"amount"})),{{"amount",Order.Ascending}}),"ix"),{"ix"})

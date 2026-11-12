let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="ordering-parity"]),data=src{[Item="parity_ordering"]}[Data] in
Table.SelectColumns(Table.AddIndexColumn(Table.Sort(Table.Group(data,{"amount"},{{"n",each Table.RowCount(_),Int64.Type}}),{{"amount",Order.Ascending}}),"ix"),{"n","ix"})

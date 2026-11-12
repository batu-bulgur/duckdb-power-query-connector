let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="index-gui-prefix"]),data=src{[Item="folding"]}[Data] in
Table.AddIndexColumn(Table.Sort(Table.Group(data,{"category"},{{"n",each Table.RowCount(_),Int64.Type}}),{{"category",Order.Ascending}}),"ix")

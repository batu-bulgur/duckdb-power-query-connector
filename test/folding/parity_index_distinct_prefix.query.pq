let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="index-gui-prefix"]),data=src{[Item="folding"]}[Data] in
Table.AddIndexColumn(Table.Sort(Table.Distinct(Table.SelectColumns(data,{"category"})),{{"category",Order.Ascending}}),"ix")

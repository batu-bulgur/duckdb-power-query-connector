let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="full-parity"]), data=src{[Item="parity_text"]}[Data] in
Table.Sort(Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]<=2),"value",each Text.PadStart([label],[id]+4,"x"),type text),{"id","value"}),{{"id",Order.Ascending}})

let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="full-parity"]), data=src{[Item="parity_text"]}[Data] in
Table.Sort(Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]=1 or [id]=4),"value",each Text.PositionOf([label],"",Occurrence.All),type list),{"id","value"}),{{"id",Order.Ascending}})

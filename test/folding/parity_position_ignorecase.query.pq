let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="full-parity"]), data=src{[Item="parity_text"]}[Data] in
Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]=2),"value",each Text.PositionOf([label],"CD",Occurrence.All,Comparer.OrdinalIgnoreCase),type list),{"id","value"})

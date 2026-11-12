let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="full-parity"]), data=src{[Item="parity_text"]}[Data] in
Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]=11),"value",each Text.PositionOf([label],"😀",Occurrence.Last),type number),{"id","value"})

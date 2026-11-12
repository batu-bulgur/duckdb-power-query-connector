let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="expression-parity"]),data=src{[Item="parity_text"]}[Data] in
Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]<=2),"value",each Number.Round([amount]/2,1),type number),{"id","value"})

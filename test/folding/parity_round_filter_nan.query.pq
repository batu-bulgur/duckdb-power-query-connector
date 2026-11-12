let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="expression-parity"]),data=src{[Item="parity_text"]}[Data] in
Table.SelectColumns(Table.SelectRows(Table.AddColumn(data,"rounded",each Number.Round([amount],0),type number),each [rounded]<0),{"id"})

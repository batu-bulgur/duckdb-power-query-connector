let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="full-parity"]), data=src{[Item="parity_text"]}[Data] in
Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]=8),"value",each Value.Equals([amount],1.015,Precision.Decimal),type logical),{"id","value"})

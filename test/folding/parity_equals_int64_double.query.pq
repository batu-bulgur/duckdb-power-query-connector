let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="typed-parity"]),data=src{[Item="parity_types"]}[Data] in
Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]=1),"value",each Value.Equals([a],[b]),type logical),{"id","value"})

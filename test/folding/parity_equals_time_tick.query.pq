let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="time-tick-parity"]),data=src{[Item="parity_types"]}[Data] in
Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]=1),"value",each Value.Equals([event_time],#time(12,34,56.1234561)),type logical),{"id","value"})

let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="expression-parity"]),data=src{[Item="parity_text"]}[Data] in
Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]<=2),"value",each Number.Round(if [id]=1 then [amount] else 1.015,2),type number),{"id","value"})

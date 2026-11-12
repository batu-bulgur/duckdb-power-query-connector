let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="expression-parity"]),data=src{[Item="parity_text"]}[Data] in
Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]=1),"value",each Text.PositionOf([label],"b",99),type list),{"id","value"})

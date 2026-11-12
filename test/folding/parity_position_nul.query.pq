let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="nul-parity"]),data=src{[Item="parity_utf16_edges"]}[Data] in
Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]=1),"value",each Text.PositionOf([label],"#(0000)"),type number),{"id","value"})

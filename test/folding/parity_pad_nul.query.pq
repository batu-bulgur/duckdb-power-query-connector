let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="nul-parity"]),data=src{[Item="parity_utf16_edges"]}[Data] in
Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]=2),"value",each Text.PadStart([label],3,"#(0000)"),type text),{"id","value"})

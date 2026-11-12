let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="expression-parity"]),data=src{[Item="parity_text"]}[Data] in
let added=Table.AddColumn(Table.SelectRows(data,each [id]<=2),"calculated",each [amount]/2) in Table.SelectColumns(Table.AddColumn(added,"value",each Number.Round([calculated],1),type number),{"id","value"})

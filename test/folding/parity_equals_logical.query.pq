let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="logical-equality"]),
    data=Table.SelectRows(src{[Item="parity_text"]}[Data],each [id]<=2),
    calculated=Table.AddColumn(data,"value",each Value.Equals(Value.Equals([label],[other_label]),true),type logical)
in Table.SelectColumns(calculated,{"id","value"})

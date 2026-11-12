let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="binary-equality"]),
    data=Table.SelectRows(src{[Item="parity_types"]}[Data],each [id]<=2),
    calculated=Table.AddColumn(data,"value",each Value.Equals([payload],Binary.FromList({0,1,255})),type logical)
in Table.SelectColumns(calculated,{"id","value"})

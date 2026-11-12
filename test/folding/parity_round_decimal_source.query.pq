let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="typed-parity"]),data=src{[Item="parity_types"]}[Data] in
Table.Sort(Table.SelectColumns(Table.AddColumn(data,"value",each Number.Round([amount],2),type nullable number),{"id","value"}),{{"id",Order.Ascending}})

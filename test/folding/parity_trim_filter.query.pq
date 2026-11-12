let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="expression-parity"]),data=src{[Item="parity_text"]}[Data] in
Table.SelectColumns(Table.SelectRows(Table.TransformColumns(data,{{"label",Text.Trim,type nullable text}}),each [label]="x"),{"id","label"})

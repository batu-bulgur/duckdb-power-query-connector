let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="index-precision"]),data=src{[Item="smoke"]}[Data] in
Table.SelectRows(Table.AddIndexColumn(data,"ix",0,1),each [ix]>=7)

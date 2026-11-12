let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="index-precision"]),data=src{[Item="smoke"]}[Data] in
Table.FirstN(Table.AddIndexColumn(Table.AddIndexColumn(data,"ix",0,1),"ix2",10,-2),3)

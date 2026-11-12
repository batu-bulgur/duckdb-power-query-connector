let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="index-name-parity"]),data=src{[Item="smoke"]}[Data] in
Table.FirstN(Table.AddIndexColumn(data,"__duckdb_pq_order_0"),3)

let data=#table(type table[n=number],List.Transform({0..9},each {_})) in
Table.FirstN(Table.AddIndexColumn(data,"__duckdb_pq_order_0"),3)

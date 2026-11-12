let data=#table(type table[id=number],List.Transform({0..999999},each {_})) in
Table.SelectRows(Table.AddIndexColumn(Table.Sort(data,{{"id",Order.Ascending}}),"ix",10,5,Int64.Type),each [id]>=999997)

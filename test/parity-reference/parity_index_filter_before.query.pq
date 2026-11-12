let data=#table(type table[id=number],List.Transform({0..999999},each {_})) in
Table.AddIndexColumn(Table.Sort(Table.SelectRows(data,each [id]>=999997),{{"id",Order.Ascending}}),"ix",10,5,Int64.Type)

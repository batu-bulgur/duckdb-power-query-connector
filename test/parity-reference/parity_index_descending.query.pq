let data=#table(type table[id=number],List.Transform({0..999999},each {_})) in
Table.FirstN(Table.AddIndexColumn(Table.Sort(data,{{"id",Order.Descending}}),"ix",-5,-2,Int64.Type),3)

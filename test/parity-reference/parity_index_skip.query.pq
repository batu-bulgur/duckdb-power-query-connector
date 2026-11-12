let data=#table(type table[id=number],List.Transform({0..999999},each {_})) in
Table.FirstN(Table.Skip(Table.AddIndexColumn(Table.Sort(data,{{"id",Order.Ascending}}),"ix"),999997),2)

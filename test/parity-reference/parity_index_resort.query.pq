let data=#table(type table[id=number],List.Transform({0..999999},each {_})) in
Table.FirstN(Table.Sort(Table.AddIndexColumn(Table.Sort(data,{{"id",Order.Descending}}),"ix"),{{"id",Order.Ascending}}),3)

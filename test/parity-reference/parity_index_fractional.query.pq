let data=#table(type table[id=number],List.Transform({0..999999},each {_})) in
Table.FirstN(Table.AddIndexColumn(Table.Sort(data,{{"id",Order.Ascending}}),"ix",0.5,0.1,type number),3)

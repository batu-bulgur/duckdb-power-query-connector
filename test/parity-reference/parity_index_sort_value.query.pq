let data=#table(type table[n=number],List.Transform({0..9},each {_})) in
Table.FirstN(Table.Sort(Table.AddIndexColumn(data,"ix",0,2),{{"ix",Order.Descending}}),3)

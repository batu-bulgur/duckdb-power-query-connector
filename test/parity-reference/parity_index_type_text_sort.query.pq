let t=#table(type table[n=number],List.Transform({0..9},each {_})) in Table.SelectColumns(Table.FirstN(Table.Sort(Table.AddIndexColumn(t,"i",1,1,type text),{{"i",Order.Descending}}),3),{"n"})

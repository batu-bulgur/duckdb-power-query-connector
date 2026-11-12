let data=#table(type table[n=number],List.Transform({0..9},each {_})) in
Table.FirstN(Table.AddIndexColumn(data,""),3)

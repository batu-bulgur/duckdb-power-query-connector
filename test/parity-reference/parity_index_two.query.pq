let data=#table(type table[n=number],List.Transform({0..9},each {_})) in
Table.FirstN(Table.AddIndexColumn(Table.AddIndexColumn(data,"ix",0,1),"ix2",10,-2),3)

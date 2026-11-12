let data=#table(type table[n=number],List.Transform({0..9},each {_})) in
Table.SelectRows(Table.AddIndexColumn(data,"ix",0,1),each [ix]>=7)

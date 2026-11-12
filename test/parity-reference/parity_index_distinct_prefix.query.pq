let data=#table(type table[id=number,category=text,amount=number],List.Transform({0..999999},each {_,if Number.Mod(_,2)=0 then "even" else "odd",_*1.25})) in
Table.AddIndexColumn(Table.Sort(Table.Distinct(Table.SelectColumns(data,{"category"})),{{"category",Order.Ascending}}),"ix")

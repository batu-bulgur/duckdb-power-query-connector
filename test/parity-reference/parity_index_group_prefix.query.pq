let data=#table(type table[id=number,category=text,amount=number],List.Transform({0..999999},each {_,if Number.Mod(_,2)=0 then "even" else "odd",_*1.25})) in
Table.AddIndexColumn(Table.Sort(Table.Group(data,{"category"},{{"n",each Table.RowCount(_),Int64.Type}}),{{"category",Order.Ascending}}),"ix")

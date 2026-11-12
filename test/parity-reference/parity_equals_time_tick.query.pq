let data=#table(type table[id=number,event_time=nullable time],{{1,#time(12,34,56.123456)}}) in
Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]=1),"value",each Value.Equals([event_time],#time(12,34,56.1234561)),type logical),{"id","value"})

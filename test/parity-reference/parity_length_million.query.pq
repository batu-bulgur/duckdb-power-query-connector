let data=#table(type table [id=number,label=text], {{99999,"item-99999"},{999998,"item-999998"},{999999,"item-999999"}}) in
Table.FirstN(Table.Sort(Table.SelectColumns(Table.SelectRows(data, each Text.Length([label])=11 and Text.EndsWith([label],"999999")), {"id"}), {{"id",Order.Ascending}}),3)

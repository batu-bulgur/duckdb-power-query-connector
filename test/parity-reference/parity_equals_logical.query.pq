let data=#table(type table[id=number,label=text,other_label=text],{{1,"a😀b","a😀b"},{2,"abcdef","ABCDEF"}}),
    calculated=Table.AddColumn(data,"value",each Value.Equals(Value.Equals([label],[other_label]),true),type logical)
in Table.SelectColumns(calculated,{"id","value"})

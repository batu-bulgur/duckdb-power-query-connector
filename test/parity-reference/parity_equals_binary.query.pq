let data=#table(type table[id=number,payload=binary],{{1,Binary.FromList({0,1,255})},{2,Binary.FromList({})}}),
    calculated=Table.AddColumn(data,"value",each Value.Equals([payload],Binary.FromList({0,1,255})),type logical)
in Table.SelectColumns(calculated,{"id","value"})

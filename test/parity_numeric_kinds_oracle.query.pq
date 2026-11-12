let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="numeric-kinds-oracle"]),
    data=src{[Item="parity_numeric_kinds"]}[Data],
    Calculate=(t)=>let a=Table.AddColumn(t,"f",each Number.Round([real_value],[digits],[mode]),type number),
        b=Table.AddColumn(a,"u",each Number.Round([unsigned_value],[digits],[mode]),type number),
        c=Table.AddColumn(b,"d",each Number.Round([decimal_value],[digits],[mode]),type number),
        d=Table.AddColumn(c,"e",each Number.Round([fine_value],[digits],[mode]),type number)
        in Table.SelectColumns(d,{"id","f","u","d","e"}),
    folded=Table.Buffer(Table.Sort(Calculate(data),{{"id",Order.Ascending}})),local=Table.Buffer(Table.Sort(Calculate(Table.Buffer(data)),{{"id",Order.Ascending}})),
    l=List.Buffer(Table.ToRecords(folded)),r=List.Buffer(Table.ToRecords(local)),
    checks=List.Combine(List.Transform(List.Positions(l),(i)=>List.Transform({"f","u","d","e"},(n)=>Value.Equals(Record.Field(l{i},n),Record.Field(r{i},n),Precision.Decimal))))
in #table(type table[cases=number,mismatches=number],{{List.Count(checks),List.Count(List.Select(checks,each not _))}})

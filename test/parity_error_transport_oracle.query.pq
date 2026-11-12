let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="error-record-oracle"]),
    data=Table.SelectRows(src{[Item="parity_text"]}[Data],each [id]<=5),
    Calculate=(t)=>
        let a=Table.AddColumn(t,"middle",each Text.Middle([label],-[id]),type nullable text),
            b=Table.AddColumn(a,"fraction",each Text.Middle([label],[id]+0.5),type nullable text),
            c=Table.AddColumn(b,"offset",each Text.Range([label],99),type nullable text),
            d=Table.AddColumn(c,"count",each Text.Range([label],0,99),type nullable text),
            e=Table.AddColumn(d,"pad",each Text.PadStart([label],-[id]),type nullable text),
            f=Table.AddColumn(e,"padChar",each Text.PadEnd([label],10,"xx"),type nullable text),
            g=Table.AddColumn(f,"trimChar",each Text.Trim([label],"xx"),type nullable text),
            h=Table.AddColumn(g,"roundMode",each Number.Round([amount],1,[id]+98),type nullable number),
            i=Table.AddColumn(h,"precision",each Value.Equals([label],[other_label],[id]+98),type logical)
        in Table.SelectColumns(i,{"id","middle","fraction","offset","count","pad","padChar","trimChar","roundMode","precision"}),
    folded=Table.Buffer(Calculate(data)), local=Table.Buffer(Calculate(Table.Buffer(data))),
    l=List.Buffer(Table.ToRecords(folded)),r=List.Buffer(Table.ToRecords(local)),
    columns={"middle","fraction","offset","count","pad","padChar","trimChar","roundMode","precision"},
    checks=List.Combine(List.Transform(List.Positions(l),(i)=>List.Transform(columns,(n)=>
        let a=try Record.Field(l{i},n),b=try Record.Field(r{i},n)
        in if a[HasError]<>b[HasError] then false else if a[HasError] then Value.Equals(a[Error],b[Error],Precision.Decimal) else Value.Equals(a[Value],b[Value]))))
in #table(type table[cases=number,mismatches=number],{{List.Count(checks),List.Count(List.Select(checks,each not _))}})

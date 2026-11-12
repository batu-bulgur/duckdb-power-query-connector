// Folded values/errors are compared with the independently buffered M input.
let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="gui-text-oracle"]),
    data=src{[Item="gui_text_extract"]}[Data],
    ref=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="gui-text-reference"]),reference=ref{[Item="gui_text_extract"]}[Data],
    Calculate=(input,f)=>let t=Table.SelectRows(input,each [id]>=1), a0=Table.AddColumn(t,"item",each Text.Split([label],"a"){[n]},type any),
        a1=Table.AddColumn(a0,"optional",each Text.Split([label],"a"){[n]}?,type any),
        a2=Table.AddColumn(a1,"replacedItem",each Text.Replace(Text.Split([label],"a"){[n]}?,"b","😀"),type any) in Table.SelectColumns(a2,{"id","item","optional","replacedItem"}),
    folded=Table.Buffer(Table.Sort(Calculate(data,true),{{"id",Order.Ascending}})),
    local=Table.Buffer(Table.Sort(Calculate(Table.Buffer(reference),false),{{"id",Order.Ascending}})),
    l=List.Buffer(Table.ToRecords(folded)),r=List.Buffer(Table.ToRecords(local)),
    Same=(u,v)=>
        if u is number and v is number then if Number.IsNaN(u) then Number.IsNaN(v) else if Number.IsNaN(v) then false else if Number.Abs(u)>=7.922816251426434e28 or Number.Abs(v)>=7.922816251426434e28 then Value.Equals(u,v) else Value.Equals(u,v,Precision.Decimal)
        else if u is record and v is record then let ns=Record.FieldNames(u) in List.Sort(ns)=List.Sort(Record.FieldNames(v)) and List.AllTrue(List.Transform(ns,each CompareTry(try Record.Field(u,_),try Record.Field(v,_))))
        else if u is list and v is list then List.Count(u)=List.Count(v) and List.AllTrue(List.Transform(List.Positions(u),each CompareTry(try u{_},try v{_})))
        else if (u is date and v is date) or (u is datetime and v is datetime) or (u is datetimezone and v is datetimezone) then Text.FromBinary(Json.FromValue(u))=Text.FromBinary(Json.FromValue(v))
        else if u is type and v is type then u=v
        else Value.Equals(u,v,Precision.Decimal),
    CompareTry=(a,b)=>if a[HasError]<>b[HasError] then false else if a[HasError] then Same(a[Error],b[Error]) else Same(a[Value],b[Value]),
    ns={"item","optional","replacedItem"},checks=List.Combine(List.Transform(List.Positions(l),(i)=>List.Transform(ns,(n)=>CompareTry(try Record.Field(l{i},n),try Record.Field(r{i},n)))))
in #table(type table[cases=number,mismatches=number],{{List.Count(checks),List.Count(List.Select(checks,each not _))}})
let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="date-precision-oracle"]),data=src{[Item="gui_date_numeric"]}[Data],
 Calculate=(t)=>let a=Table.AddColumn(t,"r",each Number.Round([n],28),type number),
 b=Table.AddColumn(a,"days",each Date.AddDays(#date(2024,1,1),[r]),type date),
 c=Table.AddColumn(b,"months",each Date.AddMonths(#date(2024,1,31),[r]),type date),
 d=Table.AddColumn(c,"week",each Date.DayOfWeek(#date(2024,1,1),[r]),type number),
 e=Table.AddColumn(d,"bad",each Date.Year([integer_value]),type number) in Table.SelectColumns(e,{"id","days","months","week","bad"}),
 folded=Table.Buffer(Table.Sort(Calculate(data),{{"id",Order.Ascending}})),local=Table.Buffer(Table.Sort(Calculate(Table.Buffer(data)),{{"id",Order.Ascending}})),
 l=List.Buffer(Table.ToRecords(folded)),r=List.Buffer(Table.ToRecords(local)),
    Same=(x,y)=>
        if x is number and y is number then
            if Number.IsNaN(x) then Number.IsNaN(y) else if Number.IsNaN(y) then false
            else if Number.Abs(x)>=7.922816251426434e28 or Number.Abs(y)>=7.922816251426434e28 then Value.Equals(x,y)
            else Value.Equals(x,y,Precision.Decimal)
        else if x is record and y is record then
            let ns=Record.FieldNames(x) in List.Sort(ns)=List.Sort(Record.FieldNames(y)) and List.AllTrue(List.Transform(ns,each @Same(Record.Field(x,_),Record.Field(y,_))))
        else if x is list and y is list then List.Count(x)=List.Count(y) and List.AllTrue(List.Transform(List.Positions(x),each @Same(x{_},y{_})))
        else if (x is date and y is date) or (x is datetime and y is datetime) or (x is datetimezone and y is datetimezone) then Text.FromBinary(Json.FromValue(x))=Text.FromBinary(Json.FromValue(y))
        else Value.Equals(x,y,Precision.Decimal),

 ns={"days","months","week","bad"},checks=List.Combine(List.Transform(List.Positions(l),(i)=>List.Transform(ns,(n)=>let a=try Record.Field(l{i},n),b=try Record.Field(r{i},n) in if a[HasError]<>b[HasError] then false else if a[HasError] then Same(a[Error],b[Error]) else Same(a[Value],b[Value]))))
in #table(type table[cases=number,mismatches=number],{{List.Count(checks),List.Count(List.Select(checks,each not _))}})
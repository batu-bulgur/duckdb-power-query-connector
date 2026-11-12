// The buffered branch is an independent M oracle. SQL/ODBC evidence is required.
let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="gui-date-oracle"]),
    data=src{[Item="gui_date_matrix"]}[Data],
    Calculate=(t)=>let
        seed=Table.AddColumn(t,"seed",each Date.AddDays(#datetimezone(2024,1,31,12,34,56.1234567,-3,-30),[delta]),type datetimezone),
        a0=Table.AddColumn(seed,"year",each Date.Year([seed]),type any),
        a1=Table.AddColumn(a0,"month",each Date.Month([seed]),type any),
        a2=Table.AddColumn(a1,"day",each Date.Day([seed]),type any),
        a3=Table.AddColumn(a2,"weekday",each Date.DayOfWeek([seed],[first_day]),type any),
        a4=Table.AddColumn(a3,"addDays",each Date.AddDays([seed],[delta]),type any),
        a5=Table.AddColumn(a4,"addMonths",each Date.AddMonths([seed],[delta]),type any),
        a6=Table.AddColumn(a5,"startMonth",each Date.StartOfMonth([seed]),type any),
        a7=Table.AddColumn(a6,"endMonth",each Date.EndOfMonth([seed]),type any),
        a8=Table.AddColumn(a7,"defaultWeekday",each Date.DayOfWeek([seed]),type any)
        in Table.SelectColumns(a8,{"id","year","month","day","weekday","addDays","addMonths","startMonth","endMonth","defaultWeekday"}),
    folded=Table.Buffer(Table.Sort(Calculate(data),{{"id",Order.Ascending}})),
    local=Table.Buffer(Table.Sort(Calculate(Table.Buffer(data)),{{"id",Order.Ascending}})),
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
    ns={"year","month","day","weekday","addDays","addMonths","startMonth","endMonth","defaultWeekday"},
    checks=List.Combine(List.Transform(List.Positions(l),(i)=>List.Transform(ns,(n)=>
        let a=try Record.Field(l{i},n),b=try Record.Field(r{i},n)
        in if a[HasError]<>b[HasError] then false else if a[HasError] then Same(a[Error],b[Error]) else Same(a[Value],b[Value]))))
in #table(type table[cases=number,mismatches=number],{{List.Count(checks),List.Count(List.Select(checks,each not _))}})
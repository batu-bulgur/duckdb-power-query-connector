let src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="native-value-oracle"]),
    data=Table.SelectRows(src{[Item="gui_date_matrix"]}[Data],each [base_id]>=5 and [base_id]<=10 and [delta]=0 and [first_day]=0),
    Calculate=(t)=>Table.SelectColumns(Table.AddColumn(Table.AddColumn(Table.AddColumn(t,"year",each Date.Year([d]),type number),"clockEq",each Value.Equals([clock],#time(12,34,56.123456)),type logical),"flagEq",each Value.Equals([flag],true),type logical),{"id","flag","clock","dt_ns","dz","year","clockEq","flagEq"}),
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

    ns={"flag","clock","dt_ns","dz","year","clockEq","flagEq"},
    checks=List.Combine(List.Transform(List.Positions(l),(i)=>List.Transform(ns,(n)=>Same(Record.Field(l{i},n),Record.Field(r{i},n)))))
in #table(type table[cases=number,mismatches=number],{{List.Count(checks),List.Count(List.Select(checks,each not _))}})
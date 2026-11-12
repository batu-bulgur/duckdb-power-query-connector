let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="utf16-boundary-oracle"]),
    // The 60 excluded pairs crash the native Middle implementation despite M try.
    // Range is still checked for those pairs in parity_range_overflow_oracle.
    data=Table.SelectRows(src{[Item="parity_slice_matrix"]}[Data],each not ([label]<>null and [offset_value]<>null and [offset_value]<>1.5 and [count_value]=2147483647 and [offset_value]>0 and [offset_value]<=Text.Length([label]))),
    Calculate=(t)=>Table.SelectColumns(Table.AddColumn(Table.AddColumn(t,"middle",each Text.Middle([label],[offset_value],[count_value]),type nullable text),"range",each Text.Range([label],[offset_value],[count_value]),type nullable text),{"id","middle","range"}),
    folded=Table.Buffer(Table.Sort(Calculate(data),{{"id",Order.Ascending}})),local=Table.Buffer(Table.Sort(Calculate(Table.Buffer(data)),{{"id",Order.Ascending}})),
    l=List.Buffer(Table.ToRecords(folded)),r=List.Buffer(Table.ToRecords(local)),
    checks=List.Combine(List.Transform(List.Positions(l),(i)=>List.Transform({"middle","range"},(n)=>
        let a=try Record.Field(l{i},n),b=try Record.Field(r{i},n)
        in if a[HasError]<>b[HasError] then false else if a[HasError] then Value.Equals(a[Error],b[Error],Precision.Decimal) else Value.Equals(a[Value],b[Value]))))
in #table(type table[cases=number,mismatches=number],{{List.Count(checks),List.Count(List.Select(checks,each not _))}})

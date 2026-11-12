let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="range-int32-boundary"]),
    data=Table.SelectRows(src{[Item="parity_slice_matrix"]}[Data],each [label]<>null and [offset_value]<>null and [offset_value]<>1.5 and [count_value]=2147483647 and [offset_value]>0 and [offset_value]<=Text.Length([label])),
    Calculate=(t)=>Table.SelectColumns(Table.AddColumn(t,"range",each Text.Range([label],[offset_value],[count_value]),type nullable text),{"id","range"}),
    folded=Table.Buffer(Table.Sort(Calculate(data),{{"id",Order.Ascending}})),local=Table.Buffer(Table.Sort(Calculate(Table.Buffer(data)),{{"id",Order.Ascending}})),
    l=List.Buffer(folded[range]),r=List.Buffer(local[range]),
    checks=List.Transform(List.Positions(l),(i)=>let a=try l{i},b=try r{i} in a[HasError] and b[HasError] and Value.Equals(a[Error],b[Error],Precision.Decimal))
in #table(type table[cases=number,mismatches=number],{{List.Count(checks),List.Count(List.Select(checks,each not _))}})

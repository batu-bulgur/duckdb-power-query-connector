let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    data = source{[Item="folding"]}[Data],
    custom = {
        {"ZeroCount", (t)=>Type.Is(t,type nullable number), (values)=>List.Count(List.Select(values,each _=0))},
        {"NaNCount", (t)=>Type.Is(t,type nullable number), (values)=>List.Count(List.Select(values,each _<>null and Number.IsNaN(_)))},
        {"EvenCount", (t)=>Type.Is(t,type nullable number), (values)=>List.Count(List.Select(values,each _<>null and Number.IsEven(_)))},
        {"OddCount", (t)=>Type.Is(t,type nullable number), (values)=>List.Count(List.Select(values,each _<>null and Number.IsOdd(_)))}
    },
    profile = Table.Buffer(Table.Profile(Table.FirstN(Table.SelectColumns(data,{"amount"}),8),custom))
in
    Table.SelectColumns(profile,{"Column","Count","ZeroCount","NaNCount","EvenCount","OddCount"})

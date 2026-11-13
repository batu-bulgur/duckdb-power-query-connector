let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    data = source{[Item="parity_ordering"]}[Data],
    profile = Table.Buffer(Table.Profile(Table.SelectColumns(data,{"large"}),{
        {"Even",each true,(xs)=>List.Count(List.Select(xs,each _<>null and Number.IsEven(_)))},
        {"Odd",each true,(xs)=>List.Count(List.Select(xs,each _<>null and Number.IsOdd(_)))}
    })),
    p=profile{0}
in #table({"min","max","average","sd","distinct","nulls","count","even","odd"},
    {{Text.From(p[Min]),Text.From(p[Max]),Text.From(p[Average]),p[StandardDeviation],p[DistinctCount],p[NullCount],p[Count],p[Even],p[Odd]}})

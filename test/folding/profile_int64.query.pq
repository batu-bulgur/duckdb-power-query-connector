let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    data = source{[Item="parity_types"]}[Data],
    profile = Table.Buffer(Table.Profile(Table.SelectColumns(data,{"b"}))){0}
in
    #table({"exactMax","count","nulls","distinct"},{{Value.Equals(profile[Max],Int64.From("9007199254740993"),Precision.Decimal),profile[Count],profile[NullCount],profile[DistinctCount]}})

let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    data = source{[Item="profile_temporal"]}[Data],
    profile = Table.Buffer(Table.Profile(data)),
    average = (name)=>DateTime.ToText(profile{[Column=name]}[Average],[Format="yyyy-MM-ddTHH:mm:ss.fffffff"])
in
    #table({"early","modern","late","ns","date","count","distinct","nulls"},
        {{average("early"),average("modern"),average("late"),average("ns"),profile{[Column="day"]}[Average]=#date(1,1,2),profile{[Column="ns"]}[Count],profile{[Column="ns"]}[DistinctCount],profile{[Column="ns"]}[NullCount]}})

let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    data = source{[Item="profile_edges"]}[Data],
    profile = Table.Buffer(Table.Profile(data)),
    n = profile{[Column="n"]},
    t = profile{[Column="t"]},
    d = profile{[Column="day"]},
    stamp = profile{[Column="stamp"]}
in
    #table({"minNaN","max","averageNaN","sdNaN","distinct","nulls","textMin","textMax","textDistinct","dateAverage","timestampAverage"},
        {{Number.IsNaN(n[Min]),n[Max],Number.IsNaN(n[Average]),Number.IsNaN(n[StandardDeviation]),n[DistinctCount],n[NullCount],t[Min]="😀",t[Max]=Character.FromNumber(57344),t[DistinctCount],d[Average]=#date(2026,1,2),stamp[Average]=#datetime(2026,1,2,4,0,0)}})

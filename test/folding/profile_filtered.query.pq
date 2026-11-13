let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    data = source{[Item="folding"]}[Data],
    filtered = Table.SelectRows(data, each [category]="odd" and [id]>=999990),
    profile = Table.Buffer(Table.Profile(Table.SelectColumns(filtered, {"amount"})))
in
    Table.SelectColumns(profile, {"Column", "Min", "Max", "Average", "Count", "NullCount", "DistinctCount"})

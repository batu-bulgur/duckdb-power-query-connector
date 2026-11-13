let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    data = source{[Item="folding"]}[Data],
    profile = Table.Buffer(Table.Profile(Table.FirstN(data, 1000))),
    result = Table.SelectColumns(profile, {"Column", "Min", "Max", "Count"})
in
    result

let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    data = source{[Item="folding"]}[Data],
    profile = Table.Buffer(Table.Profile(Table.SelectColumns(data, {"amount"}))),
    result = Table.TransformColumns(profile, {{"StandardDeviation", each Number.Round(_, 6), type nullable number}})
in
    result

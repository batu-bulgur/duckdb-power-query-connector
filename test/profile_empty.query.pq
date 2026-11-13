// Empty input also exercises Table.Profile's separate scalar-default queries.
let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    data = source{[Item="folding"]}[Data],
    empty = Table.SelectRows(Table.SelectColumns(data,{"amount"}),each [amount]<0),
    profile = Table.Buffer(Table.Profile(empty))
in
    Table.SelectColumns(profile,{"Column","Min","Max","Count","NullCount","DistinctCount"})

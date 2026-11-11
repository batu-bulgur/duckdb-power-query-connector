// Suffix folding must compose with projection, sort, OFFSET and LIMIT.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="folding"]}[Data],
    filtered = Table.SelectColumns(Table.SelectRows(data, each Text.EndsWith([label], "99999")), {"id"}),
    result = Table.FirstN(Table.Skip(Table.Sort(filtered, {{"id", Order.Ascending}}), 2), 3)
in
    result

// Suffix folding must compose with grouped aggregation.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="folding"]}[Data],
    filtered = Table.SelectRows(data, each Text.EndsWith([label], "99999")),
    result = Table.Sort(Table.Group(filtered, {"category"}, {{"count", each Table.RowCount(_), Int64.Type}}), {{"category", Order.Ascending}})
in
    result

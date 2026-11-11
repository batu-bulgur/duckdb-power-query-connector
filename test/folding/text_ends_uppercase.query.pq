// Native suffix folding; NULL and empty labels remain in the source table.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="string_cases"]}[Data],
    result = Table.Sort(Table.SelectColumns(Table.SelectRows(data, each Text.EndsWith([label], "BUL")), {"id"}), {{"id", Order.Ascending}})
in
    result

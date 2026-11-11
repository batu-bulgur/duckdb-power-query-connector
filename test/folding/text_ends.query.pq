// Million-row regression: native suffix predicate and only three ODBC rows.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="folding"]}[Data],
    result = Table.FirstN(Table.Sort(Table.SelectColumns(Table.SelectRows(data, each Text.EndsWith([label], "99999")), {"id"}), {{"id", Order.Ascending}}), 3)
in
    result

// Regression: Unicode constant comparison must stay in DuckDB.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="unicode_folding"]}[Data],
    result = Table.SelectColumns(Table.SelectRows(data, each [label] = "İstanbul"), {"id"})
in
    result

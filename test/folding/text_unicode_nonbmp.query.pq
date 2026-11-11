// Regression: Unicode constant comparison must stay in DuckDB.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="string_cases"]}[Data],
    result = Table.SelectColumns(Table.SelectRows(data, each [label] = "prefix-😀-ş"), {"id"})
in
    result

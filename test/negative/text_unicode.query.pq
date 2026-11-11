// Known limitation: Unicode literal equality still falls back locally.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="string_cases"]}[Data],
    result = Table.SelectColumns(Table.SelectRows(data, each [label] = "İstanbul"), {"id"})
in
    result

// Column statistics can invoke the list aggregate directly, without Table.Group.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="folding"]}[Data],
    tail = Table.SelectRows(data, each [id] >= 999997)
in
    List.StandardDeviation(tail[amount])

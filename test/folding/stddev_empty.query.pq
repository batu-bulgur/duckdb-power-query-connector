let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="folding"]}[Data],
    empty = Table.SelectRows(data, each [id] < 0),
    result = Table.Group(empty, {}, {{"sd", each List.StandardDeviation([amount]), type nullable number}})
in
    result

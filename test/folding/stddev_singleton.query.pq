let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="folding"]}[Data],
    singleton = Table.SelectRows(data, each [id] = 999999),
    result = Table.Group(singleton, {}, {{"sd", each List.StandardDeviation([amount]), type nullable number}})
in
    result

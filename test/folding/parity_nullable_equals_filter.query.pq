let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="scalar-parity-regression"]),
    data = src{[Item="parity_text"]}[Data]
in
Table.Sort(Table.SelectColumns(Table.SelectRows(data, each Value.NullableEquals([label],[other_label])),{"id"}),{{"id",Order.Ascending}})

// A non-default comparer must retain M semantics, never ordinal SQL equality.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="string_cases"]}[Data],
    result = Table.Sort(Table.SelectColumns(Table.SelectRows(data, each Text.EndsWith([label], "BUL", Comparer.OrdinalIgnoreCase)), {"id"}), {{"id", Order.Ascending}})
in
    result

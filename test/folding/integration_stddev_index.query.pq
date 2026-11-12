// Verify that the scalar/index plan retains the previously released aggregate.
let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="integration-regression"]),
    data = source{[Item="folding"]}[Data],
    first = Table.FirstN(Table.Sort(Table.SelectColumns(data, {"id"}), {{"id", Order.Ascending}}), 3),
    indexed = Table.AddIndexColumn(first, "position"),
    result = Table.Group(indexed, {}, {{"sd", each List.StandardDeviation([position]), type number}})
in
    result

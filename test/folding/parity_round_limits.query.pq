// Tiny and huge values follow the full decimal/original-value calculation paths.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="negative-control"]),
    data = src{[Item="parity_round_limits"]}[Data],
    calculated = Table.AddColumn(data, "value", each Number.Round([amount], 15), type nullable number)
in Table.Sort(Table.SelectColumns(calculated, {"id", "value"}), {{"id", Order.Ascending}})

// UI-style table transformations; no SQL in the analysis query.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="folding-regression"]),
    data = src{[Item="folding"]}[Data],
    result = Table.Sort(Table.SelectColumns(Table.SelectRows(data, each [event_date] >= #date(2026, 1, 29) and [id] >= 999970), {"id"}), {{"id", Order.Ascending}})
in
    result

// Buffer is an intentional oracle boundary: Round is calculated by SQL, then
// M checks its NaN result without PQTest's NaN = NaN baseline-comparison issue.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="parity-nan-oracle"]),
    data = src{[Item="parity_text"]}[Data],
    one = Table.SelectRows(data, each [id] = 11),
    calculated = Table.AddColumn(one, "rounded", each Number.Round([amount], 2), type nullable number),
    materialized = Table.Buffer(Table.SelectColumns(calculated, {"id", "rounded"})),
    checked = Table.AddColumn(materialized, "isNaN", each Number.IsNaN([rounded]), type logical)
in Table.SelectColumns(checked, {"id", "isNaN"})

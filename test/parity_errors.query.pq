// Check M's per-cell errors and try recovery after a refused/failed SQL mapping.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="parity-errors"]),
    data = src{[Item="parity_text"]}[Data],
    calculated = Table.AddColumn(data, "slice", each Text.Range([label], 0, 99), type nullable text),
    checked = Table.AddColumn(calculated, "hasError", each (try [slice])[HasError], type logical),
    result = Table.Sort(Table.SelectColumns(checked, {"id", "hasError"}), {{"id", Order.Ascending}})
in result

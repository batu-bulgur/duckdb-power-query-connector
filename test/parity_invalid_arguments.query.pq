// Invalid parameter types must keep M errors, not become successful SQL casts.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="parity-type-errors"]),
    data = src{[Item="parity_text"]}[Data],
    flagged = Table.AddColumn(data, "flag", each Value.Equals([label],[other_label]), type logical),
    badPad = Table.AddColumn(flagged, "badPad", each Text.PadStart([label],5,{"0"}), type nullable text),
    badRound = Table.AddColumn(badPad, "badRound", each Number.Round([flag]), type nullable number),
    padCheck = Table.AddColumn(badRound, "padError", each (try [badPad])[HasError], type logical),
    roundCheck = Table.AddColumn(padCheck, "roundError", each (try [badRound])[HasError], type logical)
in Table.Sort(Table.SelectColumns(roundCheck,{"id","padError","roundError"}),{{"id",Order.Ascending}})

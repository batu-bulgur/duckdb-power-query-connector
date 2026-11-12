// Deliberate buffered M oracle. The runner independently requires one folded
// Round SQL request and one raw oracle read; neither can mask extra retries.
let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="round-matrix-oracle"]),
    // Five cases make the pinned SDK throw an uncatchable CLR Decimal overflow;
    // retain their separate failure reproducer instead of treating them as values.
    data=Table.SelectRows(src{[Item="parity_round_matrix"]}[Data],each not ([amount]=7.92281625142643e28 and [digits] = -28)),
    folded=Table.Buffer(Table.Sort(Table.SelectColumns(Table.AddColumn(data,"value",each Number.Round([amount],[digits],[mode]),type nullable number),{"id","value"}),{{"id",Order.Ascending}})),
    local=Table.Buffer(Table.Sort(Table.AddColumn(Table.Buffer(data),"value",each Number.Round([amount],[digits],[mode]),type nullable number),{{"id",Order.Ascending}})),
    l=List.Buffer(folded[value]), r=List.Buffer(local[value]),
    Same=(x,y)=>if Number.IsNaN(x) then Number.IsNaN(y) else if Number.IsNaN(y) then false
        else if Number.Abs(x)>7.92281625142643e28 or Number.Abs(y)>7.92281625142643e28 then Value.Equals(x,y)
        else Value.Equals(x,y,Precision.Decimal),
    mismatches=List.Select(List.Positions(l),each not Same(l{_},r{_}))
in #table(type table[cases=number,mismatches=number],{{List.Count(l),List.Count(mismatches)}})

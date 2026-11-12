// Both sides use a buffered transport; only the oracle computes indices in M.
let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="index-precision-oracle"]),
    data=src{[Item="smoke"]}[Data],
    initial=9223372036854775807, increment=1,
    folded=Table.Buffer(Table.AddIndexColumn(data,"ix",initial,increment,type number)),
    local=Table.Buffer(Table.AddIndexColumn(Table.Buffer(data),"ix",initial,increment,type number)),
    l=List.Buffer(folded[ix]),r=List.Buffer(local[ix]),
    mismatch=List.Count(List.Select(List.Positions(l),each not Value.Equals(l{_},r{_},Precision.Decimal)))
in #table(type table[cases=number,mismatches=number],{{List.Count(l),mismatch}})

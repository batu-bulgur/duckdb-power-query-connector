let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    names={"parity_ordering","parity_numeric_kinds","profile_edges","profile_temporal","profile_classify","positive_infinity","negative_infinity","only_null"},
    equal=(x,y)=>if x is number and y is number then if Number.IsNaN(x) then Number.IsNaN(y) else if Number.IsNaN(y) then false else if Number.Abs(x)=#infinity or Number.Abs(y)=#infinity then x=y else Value.Equals(x,y,Precision.Decimal) else Value.Equals(x,y,Precision.Decimal),
    rows=List.Transform(names,(name)=>
        let data=if name="positive_infinity" then Table.SelectRows(source{[Item="profile_classify"]}[Data],each [n]=#infinity) else if name="negative_infinity" then Table.SelectRows(source{[Item="profile_classify"]}[Data],each [n]=-#infinity) else if name="only_null" then Table.SelectRows(source{[Item="profile_classify"]}[Data],each [n]=null) else source{[Item=name]}[Data],
            sql=Table.Buffer(Table.Profile(data)),
            reference=Table.Buffer(Table.Profile(Table.Buffer(data))),
            matches=List.Transform(Table.ToRecords(reference),(r)=>
                let actual=sql{[Column=r[Column]]}
                in List.AllTrue(List.Transform(Record.FieldNames(r),(field)=>equal(Record.Field(actual,field),Record.Field(r,field)))))
        in {name,Table.RowCount(reference),List.AllTrue(matches)})
in #table({"fixture","columns","equal"},rows)

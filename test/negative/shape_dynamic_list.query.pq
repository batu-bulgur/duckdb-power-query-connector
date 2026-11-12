let s=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="shape-dynamic-list-negative"]),data=s{[Item="gui_text_base"]}[Data],
    Calculate=(t)=>Table.SelectColumns(Table.AddColumn(t,"v",each Text.Combine({[label],[other_label]},[other_label]),type text),{"id","v"}),
    a=List.Buffer(Table.ToRecords(Table.Sort(Table.Buffer(Calculate(data)),{{"id",Order.Ascending}}))),
    b=List.Buffer(Table.ToRecords(Table.Sort(Calculate(Table.Buffer(data)),{{"id",Order.Ascending}})))
in #table(type table[cases=number,mismatches=number],{{List.Count(a),List.Count(List.Select(List.Positions(a),each a{_}[v]<>b{_}[v]))}})

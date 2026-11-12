// FromCulture captures an opaque culture in a native function with empty metadata.
let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="culture-boundary"]),
    data=Table.SelectRows(src{[Item="string_cases"]}[Data],each [id]>=15 and [id]<=18),
    calculated=Table.AddColumn(data,"eq",each Text.EndsWith([label],"i",Comparer.FromCulture("tr-TR",true)),type logical)
in Table.Sort(Table.SelectColumns(calculated,{"id","eq"}),{{"id",Order.Ascending}})

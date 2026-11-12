let
    src=DuckDB.Contents("__DB_PATH__",null,true,false,"single",[custom_user_agent="filter-error-oracle"]),
    data=Table.SelectRows(src{[Item="parity_text"]}[Data],each [id]<=3),
    Calculate=(t)=>let x=Table.SelectRows(t,each if [id]=1 then true else Text.Length(Text.Range([label],99))=0) in Table.FirstN(x,1){0}[id],
    Capture=(t)=>Json.Document(Binary.Buffer(Json.FromValue(try Calculate(t)))),
    folded=Capture(data),local=Capture(Table.Buffer(data)),
    same=if folded[HasError]<>local[HasError] then false else if folded[HasError] then Value.Equals(folded[Error],local[Error],Precision.Decimal) else Value.Equals(folded[Value],local[Value],Precision.Decimal)
in #table(type table[cases=number,mismatches=number],{{1,if same then 0 else 1}})

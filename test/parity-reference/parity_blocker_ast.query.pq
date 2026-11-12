let
    list=try RowExpression.From(each Value.Equals({[id],1},{1,1})),
    record=try RowExpression.From(each Value.Equals([a=[id],b="x"],[a=1,b="x"]))
in #table(type table[kind=text,hasError=logical,message=text],{
    {"list",list[HasError],list[Error][Message]},
    {"record",record[HasError],record[Error][Message]}})

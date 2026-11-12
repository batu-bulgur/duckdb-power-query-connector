let
    c=Comparer.FromCulture("tr-TR",true),
    ast=RowExpression.From(each Text.EndsWith([label],"i",c)),
    exposed=ast[Arguments]{2}[Value]
in #table(type table[hasCultureMetadata=logical,ordinal=logical,ordinalIgnoreCase=logical,correctTurkishResult=logical],{{
    Record.FieldCount(Value.Metadata(exposed))>0,exposed=Comparer.Ordinal,exposed=Comparer.OrdinalIgnoreCase,Text.EndsWith("İ","i",exposed)}})

let data = #table(type table [id=number,label=nullable text,other_label=nullable text,amount=nullable number], {{1,"a😀b","a😀b",2.5},{2,"abcdef","ABCDEF",-2.5},{3,"#(tab) abc #(lf)",null,1.25},{4,"","",null},{5,null,null,3.5},{6,"Şİı","Şİı",-3.5},{7,"😀#(0001)b","😀#(0001)b",1.005},{8,"ab%_c'd\x","ab%_c'd\x",1.015},{9,"  x  ","x",12.345},{10,"  ","",-12.345},{11,"😀😀b","😀😀B",#nan},{12,"x#(0001)😀#(0001)z","x#(0001)😀#(0001)z",#infinity}}) in
let
    trimmed=Table.TransformColumns(data, {{"label",Text.Trim,type nullable text}}),
    padded=Table.TransformColumns(trimmed, {{"label",each Text.PadStart(_,5,"0"),type nullable text}}),
    measured=Table.AddColumn(padded,"n",each Text.Length([label]),Int64.Type),
    selected=Table.SelectRows(measured, each [n]=5),
    result=Table.Sort(Table.SelectColumns(selected,{"id","label"}),{{"id",Order.Ascending}})
in result

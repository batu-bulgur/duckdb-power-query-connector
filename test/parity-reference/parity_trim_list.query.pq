let data = #table(type table [id=number,label=nullable text,other_label=nullable text,amount=nullable number], {{1,"a😀b","a😀b",2.5},{2,"abcdef","ABCDEF",-2.5},{3,"#(tab) abc #(lf)",null,1.25},{4,"","",null},{5,null,null,3.5},{6,"Şİı","Şİı",-3.5},{7,"😀#(0001)b","😀#(0001)b",1.005},{8,"ab%_c'd\x","ab%_c'd\x",1.015},{9,"  x  ","x",12.345},{10,"  ","",-12.345},{11,"😀😀b","😀😀B",#nan},{12,"x#(0001)😀#(0001)z","x#(0001)😀#(0001)z",#infinity}}) in
let
    filtered = data,
    calculated = Table.AddColumn(filtered, "value", each Text.Trim([label],{"a","b"}), type nullable text),
    result = Table.Sort(Table.SelectColumns(calculated, {"id", "value"}), {{"id", Order.Ascending}})
in result

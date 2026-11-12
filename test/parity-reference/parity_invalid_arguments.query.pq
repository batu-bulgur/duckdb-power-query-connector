let data = #table(type table [id=number,label=nullable text,other_label=nullable text,amount=nullable number], {{1,"a😀b","a😀b",2.5},{2,"abcdef","ABCDEF",-2.5},{3,"#(tab) abc #(lf)",null,1.25},{4,"","",null},{5,null,null,3.5},{6,"Şİı","Şİı",-3.5},{7,"😀#(0001)b","😀#(0001)b",1.005},{8,"ab%_c'd\x","ab%_c'd\x",1.015},{9,"  x  ","x",12.345},{10,"  ","",-12.345},{11,"😀😀b","😀😀B",#nan},{12,"x#(0001)😀#(0001)z","x#(0001)😀#(0001)z",#infinity}}) in
let
    flagged = Table.AddColumn(data, "flag", each Value.Equals([label],[other_label]), type logical),
    badPad = Table.AddColumn(flagged, "badPad", each Text.PadStart([label],5,{"0"}), type nullable text),
    badRound = Table.AddColumn(badPad, "badRound", each Number.Round([flag]), type nullable number),
    padCheck = Table.AddColumn(badRound, "padError", each (try [badPad])[HasError], type logical),
    roundCheck = Table.AddColumn(padCheck, "roundError", each (try [badRound])[HasError], type logical)
in Table.Sort(Table.SelectColumns(roundCheck,{"id","padError","roundError"}),{{"id",Order.Ascending}})

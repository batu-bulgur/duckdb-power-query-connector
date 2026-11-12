let data=#table(type table[id=number,label=nullable text],{{1,"a#(0000)b"},{2,"#(0000)"},{3,"#(FFFF)"},{4,"#(FEFF)x#(FEFF)"},{5,"#(tab)#(00A0)#(2003)x#(202F)#(3000)"},{6,""},{7,null},{8,"😀#(0001)b"}}) in
Table.SelectColumns(Table.AddColumn(Table.SelectRows(data,each [id]=2),"value",each Text.PadStart([label],3,"#(0000)"),type text),{"id","value"})

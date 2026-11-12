// This standalone view proves which expressions reach the pinned SDK handler.
let V=()=>Table.View(null,[GetType=()=>type table[a=text,n=number],GetRows=()=>#table(type table[a=text,n=number],{{"x,y",0}}),
        OnAddColumns=(cs)=>Table.AddColumn(#table(type table[a=text,n=number],{{"HANDLER",0}}),cs{0}[Name],each "HIT",cs{0}[Type])]),
    cases={
        [name="start",fn=each Text.Start([a],1)],
        [name="constant-list",fn=each Text.Combine({"a","b"},[a])],
        [name="field-list-fixed-separator",fn=each Text.Combine({[a],[a]},",")],
        [name="field-list-dynamic-separator",fn=each Text.Combine({[a],[a]},[a])],
        [name="element-constant",fn=each Text.Split([a],","){0}],
        [name="element-dynamic",fn=each Text.Split([a],","){[n]}]},
    rows=List.Transform(cases,(c)=>let t=Table.AddColumn(V(),"value",c[fn],type any) in {c[name],Table.Buffer(t){0}[a]="HANDLER"})
in #table(type table[name=text,handler=logical],rows)

let
    bases={"0001-01-01T00:00:00.","2026-01-01T00:00:00.","9999-01-01T00:00:00."},
    sets={{0,0,10},{0,10,10},{0,0,0,10},{0,0,10,20},{10,20},{10,20,30}},
    expected={"0000003","0000006","0000002","0000007","0000015","0000020"},
    matches=List.Combine(List.Transform(bases,(b)=>List.Transform(List.Positions(sets),(i)=>
        let values=List.Transform(sets{i},each DateTime.FromText(b&Text.PadStart(Text.From(_),7,"0")))
        in DateTime.ToText(List.Average(values),[Format="yyyy-MM-ddTHH:mm:ss.fffffff"])=b&expected{i})))
in #table({"comparisons","passed"},{{List.Count(matches),List.AllTrue(matches)}})

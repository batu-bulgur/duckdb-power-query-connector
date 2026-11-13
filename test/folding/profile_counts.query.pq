let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    data = source{[Item="profile_edges"]}[Data]
in
    Table.Group(data,{}, {
        {"count",each List.Count([n]),Int64.Type},
        {"distinct",each List.Count(List.Distinct([n])),Int64.Type},
        {"nan",each List.Count(List.Select([n],each _<>null and Number.IsNaN(_))),Int64.Type},
        {"even",each List.Count(List.Select([n],each _<>null and Number.IsEven(_))),Int64.Type},
        {"odd",each List.Count(List.Select([n],each _<>null and Number.IsOdd(_))),Int64.Type},
        {"emptyText",each List.Count(List.Select([t],each _="")),Int64.Type},
        {"nullText",each List.Count(List.Select([t],each _=null)),Int64.Type}
    })

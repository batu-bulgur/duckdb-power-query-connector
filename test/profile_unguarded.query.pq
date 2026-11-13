let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    data = source{[Item="profile_classify"]}[Data],
    grouped = Table.Group(data,{}, {
        {"count",each List.Count([n]),Int64.Type},
        {"nan",each List.Count(List.Select([n],each Number.IsNaN(_))),Int64.Type}
    }),
    result = try Table.Buffer(grouped){0}[nan]
in #table({"nullErrorPreserved"},{{result[HasError]}})

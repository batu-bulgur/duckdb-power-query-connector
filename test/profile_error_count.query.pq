let
    source = DuckDB.Contents("__DB_PATH__", null, true, false, "single", []),
    data = source{[Item="profile_edges"]}[Data],
    profile = Table.Buffer(Table.Profile(Table.SelectColumns(data,{"n"}),{
        {"ErrorCount",each true,(values)=>Table.RowCount(Table.SelectRowsWithErrors(Table.FromValue(values,[DefaultColumnName="Value"]),{"Value"}))}
    }))
in
    Table.SelectColumns(profile,{"Column","Count","ErrorCount"})

// Unicode type-info normalization must preserve the public table schema.
let
    src = DuckDB.Contents("__DB_PATH__", null, true, false, "single", [custom_user_agent="text-metadata-regression"]),
    data = src{[Item="string_cases"]}[Data],
    schema = Table.Schema(data)
in
    Table.SelectColumns(schema, {"Name", "Kind", "NativeTypeName"})

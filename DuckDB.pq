// This file contains your Data Connector logic
[Version = "0.4.0"]
section DuckDB;

// When set to true, additional trace information will be written out to the User log.
// This should be set to false before release. Tracing is done through a call to
// Diagnostics.LogValue(). When EnableTraceOutput is set to false, the call becomes a
// no-op and simply returns the original value.
// Off by default: the traced connection string carries the MotherDuck token, which
// must not reach the user log.
EnableTraceOutput = false;

// The name of the ODBC driver
Config_DriverName = "DuckDB Driver";

// Set to null to determine the value from the driver.
Config_SqlConformance = null;

// DuckDB supports LIMIT, LIMIT ... OFFSET, and OFFSET without LIMIT.
// Advertising LIMIT only makes Table.Skip fall back to local evaluation.
Config_LimitClauseKind = LimitClauseKind.LimitOffset;

// DuckDB does not support standard username/password
// handling through the UID and PWD connection string parameters.
Config_DefaultUsernamePasswordHandling = false;

// If the driver supports parameter bindings, then set this to true.
Config_UseParameterBindings = null;

// Override this setting to force the character escape value.
Config_StringLiterateEscapeCharacters = null;

// Override this if the driver expects the use of CAST instead of CONVERT.
Config_UseCastInsteadOfConvert = null;

// Set this to true to enable Direct Query in addition to Import mode.
Config_EnableDirectQuery = true;

// Default custom user agent
DefaultCustomUserAgent = "powerbi/v0.0(DuckDB)";

[DataSource.Kind="DuckDB", Publish="DuckDB.Publish"]
shared DuckDB.Contents = (
    database as text,
    optional motherduck_token as text,
    optional read_only as logical,
    optional saas_mode as logical,
    optional attach_mode as text,
    optional options as record
) =>
    let
        Config_DriverName = Config_DriverName,
        // Read-only
        AccessMode = if (read_only = true)
        then
            "read_only"
        else if (read_only = false)
        then
            "read_write"
        else if (Record.HasFields(options, "access_mode") = true)
        then
            options[access_mode]
        else
            "automatic",
        // Custom user agent
        CustomUserAgent = if (Record.HasFields(options, "custom_user_agent") = true)
        then
            Text.Combine({DefaultCustomUserAgent, options[custom_user_agent]}, " ")
        else
            DefaultCustomUserAgent,
        Credential = Extension.CurrentCredential(),
        // A wrong/expired token can surface as a non-text credential; coercing it during
        // connection-string building yields a cryptic "cannot convert Record to Text".
        // Fail with a clear message instead.
        token =
            let raw = try Credential[Password] otherwise motherduck_token in
                if raw = null then null
                else if raw is text then raw
                else error Error.Record("DataSource.Error", "MotherDuck token must be text. Check the configured token."),
        // The ODBC connection string
        ConnectionString = options & [
            Driver = Config_DriverName,
            Database = GetFullPath(database, token, saas_mode, attach_mode),
            access_mode = AccessMode,
            custom_user_agent = CustomUserAgent
        ],
        //
        // Configuration options for the call to Odbc.DataSource
        //
        defaultConfig = Diagnostics.LogValue("BuildOdbcConfig", BuildOdbcConfig()),
        SqlCapabilities = Diagnostics.LogValue(
            "SqlCapabilities_Options", defaultConfig[SqlCapabilities] & [
                SupportsTop = false,
                // Older DuckDB ODBC releases misread SQL_C_WCHAR string parameters
                // bound to SQL_VARCHAR (duckdb/duckdb-odbc#478). DuckDB supports
                // SQL string literals; let the engine quote them while retaining
                // parameter bindings for other types.
                SupportsStringLiterals = true,
                SupportsDerivedTable = true,
                Sql92Conformance = 8 /* SQL_SC_SQL92_FULL */,
                GroupByCapabilities = 4 /* SQL_GB_NO_RELATION */,
                FractionalSecondsScale = 3,
                // Enable Native query
                Sql92Translation = "PassThrough"
            ]
        ),
        // Please refer to the ODBC specification for SQLGetInfo properties and values.
        // https://github.com/Microsoft/ODBC-Specification/blob/master/Windows/inc/sqlext.h
        SQLGetInfo = Diagnostics.LogValue(
            "SQLGetInfo_Options",
            defaultConfig[SQLGetInfo]
                & [
                    // Place custom overrides here
                    // The values below are required for the SQL Native Client ODBC driver, but might
                    // not be required for your data source.
                    SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
                    SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All],
                    // The DuckDB ODBC driver does not translate ODBC {fn ...} scalar-function
                    // escapes, so advertise none. Otherwise the engine folds Text.Contains to
                    // {fn LOCATE(...)}, which reaches DuckDB verbatim and fails to parse.
                    // With no escapes advertised the engine folds to LIKE
                    // or evaluates client-side.
                    SQL_STRING_FUNCTIONS = 0
                ]
        ),
        // SQLGetTypeInfo can be specified in two ways:
        // 1. A #table() value that returns the same type information as an ODBC
        //    call to SQLGetTypeInfo.
        // 2. A function that accepts a table argument, and returns a table. The
        //    argument will contain the original results of the ODBC call to SQLGetTypeInfo.
        //    Your function implementation can modify/add to this table.
        //
        // For details of the format of the types table parameter and expected return value,
        // please see: https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/sqlgettypeinfo-function
        //
        // The sample implementation provided here will simply output the original table
        // to the user trace log, without any modification.
        SQLGetTypeInfo = (driverTypes) =>
            let
                // DuckDB reports SQL_VARCHAR and SQL_WVARCHAR with the same
                // TYPE_NAME. Give the Unicode row its valid DuckDB alias so the
                // folding engine can distinguish Unicode constants from columns.
                types = Table.FromRecords(
                    Table.TransformRows(driverTypes, each
                        if [DATA_TYPE] = ODBC[SQL_TYPE][WVARCHAR] and [TYPE_NAME] = "VARCHAR" then
                            _ & [TYPE_NAME = "NVARCHAR"]
                        else
                            _),
                    Value.Type(driverTypes)
                )
            in
            if (EnableTraceOutput <> true) then
                types
            else
                let
                    // Outputting the entire table might be too large, and result in the value being truncated.
                    // We can output a row at a time instead with Table.TransformRows()
                    rows = Table.TransformRows(types, each Diagnostics.LogValue("SQLGetTypeInfo " & _[TYPE_NAME], _)),
                    toTable = Table.FromRecords(rows)
                in
                    Value.ReplaceType(toTable, Value.Type(types)),
        Options = [
                // A logical (true/false) that sets whether to view the tables grouped by their schema names
                HierarchicalNavigation = false,
                // Keep SQL quoting/parameters and the relational planner in the
                // existing engine. Only registered scalar invocations are replaced.
                AstVisitor = DuckDB.ScalarAstVisitor,
                // Allows upconversion of numeric types
                SoftNumbers = true,
                // Allow upconversion / resizing of numeric and string types
                TolerateConcatOverflow = true,
                // Enables connection pooling via the system ODBC manager
                ClientConnectionPooling = false,
                // DuckDB VARCHAR is UTF-8; comparison to its NVARCHAR alias is
                // lossless. Add this conversion without replacing driver casts.
                ImplicitTypeConversions = #table(
                    {"Type1", "Type2", "ResultType"},
                    {{"VARCHAR", "NVARCHAR", "NVARCHAR"}}
                ),
                // Other configuration options
                SqlCapabilities = SqlCapabilities,
                SQLGetInfo = SQLGetInfo,
                SQLGetTypeInfo = SQLGetTypeInfo
            ],
        // Create and return the ODBC data source
        OdbcDatasource = Odbc.DataSource(
            ConnectionString,
            Options
        ),
        RelationalDatasource = DuckDB.RelationalFolding(ConnectionString, OdbcDatasource, DuckDB.ScalarAstVisitor,
            (a,t,c,r)=>DuckDB.AdvancedScalar(a,t,c,r,DuckDB.OrdinalIgnoreCase), DuckDB.RoundScalar, DuckDB.EqualityScalar, DuckDB.IndexSql),
        // Value.NativeQuery support. EnableFolding is ignored: transforms evaluate client-side.
        NativeQueryView = Table.View(RelationalDatasource, [
            OnNativeQuery = (query, parameters, queryOptions) =>
                if parameters <> null then
                    error Error.Record("Expression.Error", "The DuckDB connector does not support native query parameters.")
                else
                    Odbc.Query(ConnectionString, query)
        ])
    in
        NativeQueryView;

// Conservative native-ODBC scalar adapter. The relational calculation modules
// provide the expanded mappings; retain safe fallback behavior here. Unsupported
// argument shapes deliberately decline folding rather than approximate M.
DuckDB.ScalarAstVisitor = [
    Functions = {
        Text.EndsWith, Text.Length, Text.Middle, Text.Range, Text.PositionOf,
        Text.PadStart, Text.PadEnd, Text.Trim, Text.TrimStart, Text.TrimEnd,
        Number.Round, Value.Equals, Value.NullableEquals, List.StandardDeviation
    },
    Invocation = (visitor, rowType, groupKeys, ast) =>
        let
            f = ast[Function][Value],
            args = ast[Arguments],
            argc = List.Count(args),
            Decline = () => error Error.Record("Expression.Error", "This invocation has no equivalent DuckDB folding mapping."),
            Arg = (i) => visitor(args{i}),
            Literal = (v) => visitor([Kind = "Constant", Value = v]),
            // Only validated integral compiler constants use SQL numeric literals.
            // User text and identifiers always go through the existing visitor.
            Integer = (v) => [Kind = "Literal", Value = Number.ToText(v, "0", "en-US")],
            Cast = (value, sqlType) => [Kind = "Cast", Expression = value, Type = sqlType],
            Constant = (i, fallback) =>
                if i >= argc then fallback
                else if args{i}[Kind] = "Constant" then args{i}[Value]
                else Decline(),
            Natural = (v) =>
                if v is number and v >= 0 and v <= 2147483647 and Number.RoundDown(v) = v then v else Decline(),
            ArgumentType = (i) =>
                if args{i}[Kind] = "Constant" then Value.Type(args{i}[Value])
                else if args{i}[Kind] = "FieldAccess" then Record.Field(Type.RecordFields(rowType), args{i}[MemberName])[Type]
                else Decline(),
            Primitive = (t) =>
                if t = type null then "null"
                else if Type.Is(t, type nullable number) then "number"
                else if Type.Is(t, type nullable text) then "text"
                else Decline(),
            Call = (name, values, types) => [
                Kind = "Invocation", Function = [Kind = "Function", Name = name],
                Arguments = List.Transform(List.Positions(values), (i) => [Expression = values{i}, Type = types{i}])
            ],
            TextCall = (name, values) => Call(name, values, List.Repeat({type nullable text}, List.Count(values))),
            Numeric = (name, a, b) => Call(name, {a, b}, {type nullable number, type nullable number}),
            Compare = (operator, a, b) => [Kind = "BinaryLogicalOperation", Operator = operator, Left = a, Right = b],
            IsNull = (value) => [Kind = "UnaryLogicalOperation", Operator = "IsNull", Expression = value],
            And = (a, b) => [Kind = "ConditionOperation", Operator = "And", Left = a, Right = b],
            Choose = (condition, yes, no) => [
                Kind = "Case", Case = null,
                Conditions = {[When = if List.Contains({"BinaryLogicalOperation", "ConditionOperation", "UnaryLogicalOperation"}, condition[Kind]) then condition
                                      else Compare("Equals", condition, [Kind = "Literal", Value = "TRUE"]), Then = yes]},
                Else = no
            ],
            FailText = () => TextCall("error", {Literal("The requested UTF-16 text range cannot be represented as DuckDB VARCHAR.")}),
            Supplementary = "[\x{10000}-\x{10FFFF}]",
            // Add one marker after each supplementary character. Its positions
            // now count UTF-16 units. An original marker remains distinguishable:
            // only the marker immediately after a supplementary code point is removed.
            EncodeUnits = (text) => TextCall("regexp_replace", {text, Literal("(" & Supplementary & ")"), Literal("\1" & Character.FromNumber(1)), Literal("g")}),
            DecodeUnits = (text) => TextCall("regexp_replace", {text, Literal("(" & Supplementary & ")\x01"), Literal("\1"), Literal("g")}),
            LengthUnits = (text) => TextCall("length", {EncodeUnits(text)}),
            Whitespace = List.Combine({{9..13}, {32, 133, 160, 5760}, {8192..8202}, {8232, 8233, 8239, 8287, 12288}}),
            TrimCharacters = (value) =>
                let
                    items = if value = null then List.Transform(Whitespace, Character.FromNumber)
                            else if value is text then {value}
                            else if value is list then value else Decline()
                in
                    if List.AllTrue(List.Transform(items, each _ is text and Text.Length(_) = 1 and (Character.ToNumber(_) < 55296 or Character.ToNumber(_) > 57343)))
                    then Text.Combine(items) else Decline(),
            Result =
                if f = List.StandardDeviation then
                    let
                        column = if groupKeys <> null and argc = 1 and args{0}[Kind] = "FieldAccess"
                            and args{0}[Expression] = RowExpression.Row then Arg(0) else Decline(),
                        aggregate = (name) => Call(name, {column}, {null})
                    in
                        if not Type.Is(Type.NonNullable(column[Type]), type number) then Decline()
                        else Choose(Compare("Equals", aggregate("COUNT"), Integer(1)), Integer(0), aggregate("STDDEV_SAMP")) & [Type=Double.Type]
                else if f = Text.EndsWith then
                    if argc <> 2 then Decline()
                    else Compare("Equals", Call("right", {Arg(0), TextCall("length", {Arg(1)})}, {type nullable text, Int64.Type}), Arg(1))
                else if f = Text.Length then LengthUnits(Arg(0))
                else if f = Text.Middle or f = Text.Range then
                    let
                        offset = Natural(Constant(1, null)),
                        rawCount = Constant(2, null),
                        count = if rawCount = null then null else Natural(rawCount),
                        text = EncodeUnits(Arg(0)),
                        slice = if count = null then Call("substr", {text, Integer(offset + 1)}, {type nullable text, Int64.Type})
                                else Call("substr", {text, Integer(offset + 1), Integer(count)}, {type nullable text, Int64.Type, Int64.Type}),
                        badStart = if offset = 0 or count = 0 then null
                                   else TextCall("regexp_matches", {Call("substr", {text, Integer(offset), Integer(1)}, {type nullable text, Int64.Type, Int64.Type}), Literal(Supplementary)}),
                        badEnd = TextCall("regexp_matches", {slice, Literal(Supplementary & "$")}),
                        checkedEnd = Choose(badEnd, FailText(), DecodeUnits(slice)),
                        validSlice = if badStart = null then checkedEnd else Choose(badStart, FailText(), checkedEnd),
                        bounds = offset + (if count = null then 0 else count)
                    in
                        if f = Text.Range then Choose(Compare("LessThan", TextCall("length", {text}), Integer(bounds)), FailText(), validSlice)
                        else validSlice
                else if f = Text.PositionOf then
                    if Constant(2, Occurrence.First) <> null and Constant(2, Occurrence.First) <> Occurrence.First or argc > 3 then Decline()
                    else
                        let
                            position = TextCall("strpos", {Arg(0), Arg(1)}),
                            prefix = Call("substr", {Arg(0), Integer(1), Numeric("subtract", position, Integer(1))}, {type text, Int64.Type, Int64.Type}),
                            found = Choose(Compare("Equals", position, Integer(0)), Integer(-1), LengthUnits(prefix))
                        in Choose(IsNull(Arg(0)), FailText(), Choose(IsNull(Arg(1)), FailText(), found))
                else if f = Text.PadStart or f = Text.PadEnd then
                    let
                        count = Natural(Constant(1, null)),
                        rawPad = Constant(2, null),
                        pad = if rawPad = null then " " else if rawPad is text then TrimCharacters(rawPad) else Decline(),
                        validPad = if Text.Length(pad) = 1 then pad else Decline(),
                        extra = Numeric("greatest", Numeric("subtract", Integer(count), LengthUnits(Arg(0))), Integer(0)),
                        target = Numeric("add", TextCall("length", {Arg(0)}), extra)
                    in
                        Call(if f = Text.PadStart then "lpad" else "rpad", {Arg(0), Cast(target, "INTEGER"), Literal(validPad)}, {type nullable text, Int64.Type, type text})
                else if f = Text.Trim or f = Text.TrimStart or f = Text.TrimEnd then
                    TextCall(if f = Text.Trim then "trim" else if f = Text.TrimStart then "ltrim" else "rtrim", {Arg(0), Literal(TrimCharacters(Constant(1, null)))})
                else if f = Number.Round then
                    let
                        inputType = ArgumentType(0),
                        facets = if Type.Is(inputType, type nullable number) then Type.Facets(inputType) else Decline(),
                        binaryDouble = Record.FieldOrDefault(facets, "NumericPrecisionBase", null) = 2 and Record.FieldOrDefault(facets, "NumericPrecision", null) = 53,
                        whole = Record.FieldOrDefault(facets, "NumericScale", null) = 0,
                        rawDigits = Constant(1, null),
                        digits = if rawDigits = null then 0 else rawDigits,
                        rawMode = Constant(2, null),
                        mode = if rawMode = null then RoundingMode.ToEven else rawMode,
                        // M Round first converts binary doubles to System.Decimal
                        // (15 significant digits). Direct round_even(DOUBLE) does
                        // not match e.g. 1.015 at two places. DECIMAL(38,28) retains
                        // .NET's maximum scale, within an explicit magnitude guard.
                        decimal = Cast(TextCall("printf", {Literal("%.15g"), Arg(0)}), "DECIMAL(38,28)"),
                        UnitText = (multiplier) =>
                            if digits = 0 then Text.From(multiplier, "en-US")
                            else if digits > 0 then "0." & Text.Repeat("0", digits - 1) & Text.From(multiplier, "en-US")
                            else Text.From(multiplier, "en-US") & Text.Repeat("0", -digits),
                        DecimalLiteral = (text) => Cast([Kind = "Literal", Value = text], "DECIMAL(38,28)"),
                        unit = DecimalLiteral(UnitText(1)),
                        twoUnits = DecimalLiteral(UnitText(2)),
                        half = DecimalLiteral(if digits >= 0 then "0." & Text.Repeat("0", digits) & "5" else "5" & Text.Repeat("0", -digits - 1)),
                        // ROUND changes DECIMAL's declared scale. Restore it
                        // before MOD/arithmetic to prevent mixed-scale promotion
                        // back to floating point (1.02 % 0.02 must be exactly zero).
                        away = Cast(Call("round", {decimal, Integer(digits)}, {type nullable number, Int64.Type}), "DECIMAL(38,28)"),
                        tie = Compare("Equals", Call("abs", {Numeric("mod", decimal, unit)}, {type number}), half),
                        odd = Compare("NotEqualTo", Numeric("mod", away, twoUnits), Integer(0)),
                        toward = Numeric("subtract", away, Numeric("multiply", Call("sign", {decimal}, {type number}), unit)),
                        tieResult = if mode = RoundingMode.ToEven then Choose(odd, toward, away)
                                    else if mode = RoundingMode.TowardZero then toward
                                    else if mode = RoundingMode.Up then Choose(Compare("LessThan", decimal, Integer(0)), Numeric("add", away, unit), away)
                                    else if mode = RoundingMode.Down then Choose(Compare("GreaterThan", decimal, Integer(0)), Numeric("subtract", away, unit), away)
                                    else away,
                        // DuckDB round_even's macro performs a floating-point tie
                        // check even for DECIMAL. Test the remainder exactly instead.
                        rounded = Choose(tie, tieResult, away),
                        magnitude = Call("abs", {Arg(0)}, {type number}),
                        tooSmall = And(Compare("GreaterThan", magnitude, Integer(0)), Compare("LessThan", magnitude, DecimalLiteral("0.00000000000001"))),
                        rangeError = TextCall("error", {Literal("Number.Round exceeds the verified decimal folding range.")}),
                        guarded = Choose(IsNull(Arg(0)), Literal(null),
                            Choose(Compare("Equals", Call("isfinite", {Arg(0)}, {type number}), [Kind = "Literal", Value = "FALSE"]), Arg(0),
                                Choose(Compare("GreaterThanOrEqual", magnitude, Integer(1000000000)), rangeError,
                                    Choose(tooSmall, rangeError, rounded))))
                    in
                        if not (digits is number) or digits < -9 or digits > 15 or Number.RoundDown(digits) <> digits then Decline()
                        else if List.Contains({RoundingMode.Up, RoundingMode.Down, RoundingMode.AwayFromZero, RoundingMode.TowardZero, RoundingMode.ToEven}, mode) then
                            if whole and digits >= 0 then Arg(0)
                            else if binaryDouble then guarded
                            else Decline()
                        else Decline()
                else if f = Value.Equals or f = Value.NullableEquals then
                    if argc > 2 then Decline()
                    else
                        let
                            leftKind = Primitive(ArgumentType(0)),
                            rightKind = Primitive(ArgumentType(1)),
                            compatible = leftKind = rightKind or leftKind = "null" or rightKind = "null",
                            // DuckDB list equality is NULL-safe. Restrict primitive
                            // kinds to prevent SQL coercion of e.g. number and text.
                            equal = if not compatible then Decline()
                                    else if f = Value.NullableEquals then Compare("Equals", Arg(0), Arg(1))
                                    else Compare("Equals", Call("list_value", {Arg(0)}, {type any}), Call("list_value", {Arg(1)}, {type any})),
                            NotNaN = (value) => Compare("Equals", Call("isnan", {Numeric("coalesce", value, Integer(0))}, {type number}), [Kind = "Literal", Value = "FALSE"])
                        in
                            if leftKind = "number" or rightKind = "number" then And(equal, And(NotNaN(Arg(0)), NotNaN(Arg(1)))) else equal
                else Decline(),
            BooleanCase =
             if f = Text.EndsWith then Choose(IsNull(Arg(1)), FailText(), Choose(IsNull(Arg(0)), Literal(null), Choose(Result, Integer(1), Integer(0))))
             else if f = Value.Equals then Choose(Result, Integer(1), Integer(0))
             else if f = Value.NullableEquals then
                Choose(IsNull(Arg(0)), Literal(null), Choose(IsNull(Arg(1)), Literal(null), Choose(Result, Integer(1), Integer(0))))
             else null,
            Output = if BooleanCase = null then Result else [
                // DuckDB accepts 0/1/NULL as predicates. Keep the AST classified
                // as a condition to avoid a bound BIT parameter in WHERE, while
                // projecting INTEGER so the driver does not return BOOLEAN text.
                Kind = "UnaryLogicalOperation",
                Operator = [Kind = "Literal", Value = "", IsPrefix = true],
                Expression = BooleanCase
            ]
        in
            Output & [Type =
                if f = List.StandardDeviation then Double.Type
                else if f = Text.Length or f = Text.PositionOf or f = Number.Round then type nullable number
                else if f = Text.EndsWith or f = Value.NullableEquals then type nullable logical
                else if f = Value.Equals then type logical
                else type nullable text]
];

// Data Source Kind description
DuckDB = [
    // Set the TestConnection handler to enable gateway support.
    // The TestConnection handler will invoke your data source function to
    // validate the credentials the user has provider. Ideally, this is not
    // an expensive operation to perform. By default, the dataSourcePath value
    // will be a json string containing the required parameters of your data
    // source function. These should be parsed and parsed as individual parameters
    // to the specified data source function.
    TestConnection = (dataSourcePath) =>
        let
            params = Json.Document(dataSourcePath),
            database = params[database],
            // Optional now: local DuckDB files need no token.
            motherduck_token = try params[motherduck_token] otherwise null,
            // optional parameters are not stored in dataSourcePath so we will set default values here
            read_only = true,
            saas_mode = false,
            attach_mode = "single",
            options = try params[options] otherwise [custom_user_agent="On-premises Data Gateway Test Connection"]
        in
            {"DuckDB.Contents", database, motherduck_token, read_only, saas_mode, attach_mode, options},
    // Set supported types of authentication
    Authentication = [
        Anonymous = [],
        UsernamePassword = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
DuckDB.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SupportsDirectQuery = Config_EnableDirectQuery,
    SourceImage = DuckDB.Icons,
    SourceTypeImage = DuckDB.Icons
];

DuckDB.Icons = [
    Icon16 = { Extension.Contents("duckdb-logo-16.png"), Extension.Contents("duckdb-logo-20.png"), Extension.Contents("duckdb-logo-24.png"), Extension.Contents("duckdb-logo-32.png") },
    Icon32 = { Extension.Contents("duckdb-logo-32.png"), Extension.Contents("duckdb-logo-40.png"), Extension.Contents("duckdb-logo-48.png"), Extension.Contents("duckdb-logo-64.png") }
];

// Get the full DuckDB path to pass to the ODBC driver
GetFullPath = (database as text, optional motherduck_token as text, optional saas_mode as logical, optional attach_mode as text) as text =>
    let
        attach_mode = if (attach_mode = null or attach_mode = "")
            then "single"
            else attach_mode,
        // Pick the right separator: a database that already carries a query string
        // (e.g. "md:db?x=1") must continue with "&", not a second "?".
        sep = if Text.Contains(database, "?") then "&" else "?",
        params = List.Combine({
            {"motherduck_token=" & motherduck_token},
            if saas_mode = true then {"saas_mode=true"} else {},
            {"attach_mode=" & attach_mode}
        }),
        path = if IsMotherDuckDatabase(database)
            then database & sep & Text.Combine(params, "&")
            else database
    in
        if IsMotherDuckDatabase(database) and (motherduck_token = null or motherduck_token = "")
        then
            error Error.Record("Expression.Error",
            "Cannot connect to MotherDuck database:
            Please enter your connection token.
            Go to http://app.motherduck.com/ and copy
            it from your User Settings.")
        else
            path;

// Check if the database is a MotherDuck database
IsMotherDuckDatabase = (database as text) as logical =>
    let
        result = Text.StartsWith(database, "md:")
    in
        result;

// build settings based on configuration variables
BuildOdbcConfig = () as record =>
    let
        Merge = (previous as record, optional caps as record, optional funcs as record, optional getInfo as record) as record =>
            let
                newCaps = if (caps <> null) then previous[SqlCapabilities] & caps else previous[SqlCapabilities],
                newFuncs = if (funcs <> null) then previous[SQLGetFunctions] & funcs else previous[SQLGetFunctions],
                newGetInfo = if (getInfo <> null) then previous[SQLGetInfo] & getInfo else previous[SQLGetInfo]
            in
                [SqlCapabilities = newCaps, SQLGetFunctions = newFuncs, SQLGetInfo = newGetInfo],
        defaultConfig = [
            SqlCapabilities = [],
            SQLGetFunctions = [],
            SQLGetInfo = []
        ],
        withParams =
            if (Config_UseParameterBindings = false) then
                let
                    caps = [
                        SupportsNumericLiterals = true,
                        SupportsStringLiterals = true,
                        SupportsOdbcDateLiterals = true,
                        SupportsOdbcTimeLiterals = true,
                        SupportsOdbcTimestampLiterals = true
                    ],
                    funcs = [
                        SQL_API_SQLBINDPARAMETER = false
                    ]
                in
                    Merge(defaultConfig, caps, funcs)
            else
                defaultConfig,
        withEscape =
            if (Config_StringLiterateEscapeCharacters <> null) then
                let
                    caps = [
                        StringLiteralEscapeCharacters = Config_StringLiterateEscapeCharacters
                    ]
                in
                    Merge(withParams, caps)
            else
                withParams,
        withLimitClauseKind = let caps = [
            LimitClauseKind = Config_LimitClauseKind
        ] in Merge(withEscape, caps),
        withCastOrConvert =
            if (Config_UseCastInsteadOfConvert <> null) then
                let
                    value =
                        if (Config_UseCastInsteadOfConvert = true) then
                            ODBC[SQL_FN_CVT][SQL_FN_CVT_CAST]
                        else
                            ODBC[SQL_FN_CVT][SQL_FN_CVT_CONVERT],
                    getInfo = [
                        SQL_CONVERT_FUNCTIONS = value
                    ]
                in
                    Merge(withLimitClauseKind, null, null, getInfo)
            else
                withLimitClauseKind,
        withSqlConformance =
            if (Config_SqlConformance <> null) then
                let
                    getInfo = [
                        SQL_SQL_CONFORMANCE = Config_SqlConformance
                    ]
                in
                    Merge(withCastOrConvert, null, null, getInfo)
            else
                withCastOrConvert
    in
        withSqlConformance;

ValidateOptions = (options as nullable record, validOptionsMap as table) as record =>
    let
        ValidKeys = Table.Column(validOptionsMap, "Name"),
        InvalidKeys = List.Difference(Record.FieldNames(options), ValidKeys),
        InvalidKeysText =
            if List.IsEmpty(InvalidKeys) then
                null
            else
                Text.Format(
                    "'#{0}' are not valid options. Valid options are: '#{1}'",
                    {Text.Combine(InvalidKeys, ", "), Text.Combine(ValidKeys, ", ")}
                ),
        ValidateValue = (name, optionType, description, default, validate, value) =>
            if
                (value is null and (Type.IsNullable(optionType) or default <> null))
                or (Type.Is(Value.Type(value), optionType) and validate(value))
            then
                null
            else
                Text.Format(
                    "This function does not support the option '#{0}' with value '#{1}'. Valid value is #{2}.",
                    {name, value, description}
                ),
        InvalidValues = List.RemoveNulls(
            Table.TransformRows(
                validOptionsMap,
                each
                    ValidateValue(
                        [Name],
                        [Type],
                        [Description],
                        [Default],
                        [Validate],
                        Record.FieldOrDefault(options, [Name], [Default])
                    )
            )
        ),
        DefaultOptions = Record.FromTable(
            Table.RenameColumns(Table.SelectColumns(validOptionsMap, {"Name", "Default"}), {"Default", "Value"})
        ),
        NullNotAllowedFields = List.RemoveNulls(
            Table.TransformRows(
                validOptionsMap,
                each
                    if not Type.IsNullable([Type]) and null = Record.FieldOrDefault(options, [Name], [Default]) then
                        [Name]
                    else
                        null
            )
        ),
        NormalizedOptions = DefaultOptions & Record.RemoveFields(options, NullNotAllowedFields, MissingField.Ignore)
    in
        if null = options then
            DefaultOptions
        else if not List.IsEmpty(InvalidKeys) then
            error Error.Record("Expression.Error", InvalidKeysText)
        else if not List.IsEmpty(InvalidValues) then
            error Error.Record("Expression.Error", Text.Combine(InvalidValues, ", "))
        else
            NormalizedOptions;

//
// Load common library functions
//
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name), asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");

DuckDB.RelationalFolding = Extension.LoadFunction("RelationalFolding.pqm");
DuckDB.AdvancedScalar = Extension.LoadFunction("AdvancedScalar.pqm");
DuckDB.RoundScalar = Extension.LoadFunction("RoundScalar.pqm");
DuckDB.EqualityScalar = Extension.LoadFunction("EqualityScalar.pqm");
DuckDB.OrdinalIgnoreCase = Extension.LoadFunction("OrdinalIgnoreCase.pqm");
DuckDB.IndexSql = Extension.LoadFunction("IndexSql.pqm");

Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;

// OdbcConstants contains numeric constants from the ODBC header files, and a
// helper function to create bitfield values.
ODBC = Extension.LoadFunction("OdbcConstants.pqm");

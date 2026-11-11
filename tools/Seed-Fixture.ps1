param([Parameter(Mandatory)][string]$DatabasePath)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $DatabasePath) { throw "Refusing to overwrite existing database: $DatabasePath" }
# Use the same installed ODBC engine as the connector, avoiding CLI/driver storage drift.
$builder = [System.Data.Odbc.OdbcConnectionStringBuilder]::new()
$builder.Driver = 'DuckDB Driver'
$builder['Database'] = $DatabasePath
$builder['access_mode'] = 'read_write'
$connection = [System.Data.Odbc.OdbcConnection]::new($builder.ConnectionString)
try {
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = 'SELECT version()'
    $version = $command.ExecuteScalar()
    $command.CommandText = @'
CREATE TABLE smoke AS SELECT * FROM range(10) t(n);
CREATE TABLE folding AS
SELECT i::INTEGER AS id,
       CASE WHEN i % 2 = 0 THEN 'even' ELSE 'odd' END AS category,
       ('item-' || i::VARCHAR) AS label,
       (i * 1.25)::DOUBLE AS amount,
       DATE '2026-01-01' + (i % 30)::INTEGER AS event_date
FROM range(1000000) t(i);
CREATE TABLE stddev_cases("grup" VARCHAR, "ölçüm""değeri" DOUBLE, integer_value INTEGER, decimal_value DECIMAL(12,2));
INSERT INTO stddev_cases VALUES
    ('sample', 1, 1, 1.25), ('sample', 2, 2, 2.50), ('sample', 3, 3, 3.75), ('sample', NULL, NULL, NULL),
    ('negative', -1, -1, -1.25), ('negative', 0, 0, 0), ('negative', 1, 1, 1.25),
    ('singleton', 7, 7, 7), ('singleton', NULL, NULL, NULL),
    ('all_null', NULL, NULL, NULL), ('all_null', NULL, NULL, NULL),
    ('constant', 4, 4, 4), ('constant', 4, 4, 4), ('constant', 4, 4, 4),
    ('offset', 1000000000001, 1, 1), ('offset', 1000000000002, 2, 2), ('offset', 1000000000003, 3, 3);
CREATE TABLE string_cases(id INTEGER, label VARCHAR);
INSERT INTO string_cases VALUES (1, 'O''Brien'), (2, 'İstanbul'), (3, 'x%_y'), (4, 'back\slash'), (5, ''), (6, NULL);
INSERT INTO string_cases VALUES
    (7, 'istanbul'), (8, 'Istanbul'), (9, 'ıstanbul'),
    (10, 'ÇığÖŞÜçöşüİı'), (11, 'İzmir''in'), (12, 'prefix-😀-ş'),
    (13, 'tail-😀'), (14, 'tail-BUL'), (15, 'tail-İ'), (16, 'tail-ı'),
    (17, 'tail-I'), (18, 'tail-i'), (19, 'not-xAB_y'), (20, 'not-x%Ay');
CREATE TABLE unicode_folding AS
SELECT i::INTEGER AS id,
       CASE WHEN i = 999997 THEN 'İstanbul' ELSE 'other' END AS label
FROM range(1000000) t(i);
'@
    [void]$command.ExecuteNonQuery()
    # Check all three pagination forms before advertising LIMIT/OFFSET support.
    foreach ($sql in @('SELECT id FROM folding ORDER BY id LIMIT 3', 'SELECT id FROM folding ORDER BY id LIMIT 3 OFFSET 5', 'SELECT id FROM folding ORDER BY id OFFSET 999997')) {
        $command.CommandText = $sql
        $reader = $command.ExecuteReader()
        try {
            $count = 0
            while ($reader.Read()) { $count++ }
            if ($count -ne 3) { throw "Unexpected row count for pagination syntax: $sql" }
        } finally { $reader.Dispose() }
    }
    foreach ($table in @('folding', 'unicode_folding')) {
        $command.CommandText = "SELECT count(*) FROM $table"
        if ($command.ExecuteScalar() -ne 1000000) { throw "Fixture count mismatch: $table" }
    }
    [pscustomobject]@{ Engine=$version; Rows=1000000; Database=$DatabasePath }
} finally {
    if ($command) { $command.Dispose() }
    $connection.Dispose()
}

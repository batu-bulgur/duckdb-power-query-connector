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
CREATE TABLE string_cases(id INTEGER, label VARCHAR);
INSERT INTO string_cases VALUES (1, 'O''Brien'), (2, 'İstanbul'), (3, 'x%_y'), (4, 'back\slash'), (5, ''), (6, NULL);
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
    $command.CommandText = 'SELECT count(*) FROM folding'
    if ($command.ExecuteScalar() -ne 1000000) { throw 'Fixture count mismatch.' }
    [pscustomobject]@{ Engine=$version; Rows=1000000; Database=$DatabasePath }
} finally {
    if ($command) { $command.Dispose() }
    $connection.Dispose()
}

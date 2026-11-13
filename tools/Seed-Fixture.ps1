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
CREATE TABLE parity_text(id INTEGER, label VARCHAR, other_label VARCHAR, amount DOUBLE);
INSERT INTO parity_text VALUES
    (1, 'a😀b', 'a😀b', 2.5),
    (2, 'abcdef', 'ABCDEF', -2.5),
    (3, chr(9) || ' abc ' || chr(10), NULL, 1.25),
    (4, '', '', NULL),
    (5, NULL, NULL, 3.5),
    (6, 'Şİı', 'Şİı', -3.5),
    (7, '😀' || chr(1) || 'b', '😀' || chr(1) || 'b', 1.005),
    (8, 'ab%_c''d\x', 'ab%_c''d\x', 1.015),
    (9, '  x  ', 'x', 12.345),
    (10, chr(160) || chr(8195), '', -12.345),
    (11, '😀😀b', '😀😀B', 'NaN'::DOUBLE),
    (12, 'x' || chr(1) || '😀' || chr(1) || 'z', 'x' || chr(1) || '😀' || chr(1) || 'z', 'Infinity'::DOUBLE);
CREATE TABLE parity_round_limits(id INTEGER, amount DOUBLE);
INSERT INTO parity_round_limits VALUES (1,1000000000.5),(2,5.0000000000005e-16),(3,1e308);
CREATE TABLE parity_round_matrix AS
WITH valueset AS (
 SELECT i,
  CASE WHEN i<26 THEN ([0.0,-0.0,1.005,1.015,2.5,-2.5,12.345,-12.345,5.0000000000005e-16,1e-28,5e-29,1e-308,1e308,-1e308,
   9007199254740992.0,9007199254740994.0,9223372036854774784.0,7.92281625142643e28,'NaN'::DOUBLE,'Infinity'::DOUBLE,'-Infinity'::DOUBLE,1000000000.5,0.49999999999999994,0.5000000000000001,79228162514264337593543950336.0,-79228162514264337593543950336.0]::DOUBLE[])[i+1]
  ELSE ((hash(i)%2000001)::DOUBLE-1000000)/1000000 * pow(10,(i%59)::INTEGER-30) END AS amount
 FROM range(320) t(i)
), digits AS (SELECT unnest([-100,-29,-28,-20,-15,-9,-2,-1,0,1,2,9,15,20,28,29,100,1.5,-2147483648,2147483647,-2147483649,2147483648,'NaN'::DOUBLE,'Infinity'::DOUBLE,'-Infinity'::DOUBLE,1.0000000000000002]::DOUBLE[]) AS digits)
SELECT row_number() OVER ()::INTEGER AS id, amount, digits, mode::INTEGER AS mode
FROM valueset CROSS JOIN digits CROSS JOIN range(5) t(mode);
CREATE TABLE parity_types(id INTEGER, a BIGINT, b BIGINT, event_date DATE, event_time TIME, amount DECIMAL(28,12),payload BLOB);
INSERT INTO parity_types VALUES
 (1,9007199254740992,9007199254740993,DATE '2026-01-01',TIME '12:34:56.123456',1.015000000000,from_hex('0001ff')),
 (2,0,0,NULL,NULL,-12.345000000000,from_hex('')),
 (3,NULL,NULL,DATE '2026-01-03',TIME '00:00:00',NULL,NULL);
CREATE TABLE profile_edges(id INTEGER,n DOUBLE,t VARCHAR,day DATE,stamp TIMESTAMP,flag BOOLEAN);
INSERT INTO profile_edges VALUES
 (1,'NaN'::DOUBLE,'😀',DATE '2026-01-01',TIMESTAMP '2026-01-01 00:00:00',NULL),
 (2,'NaN'::DOUBLE,chr(57344),DATE '2026-01-02',TIMESTAMP '2026-01-02 12:00:00',TRUE),
 (3,NULL,NULL,NULL,NULL,FALSE),
 (4,1,'😀',DATE '2026-01-03',TIMESTAMP '2026-01-03 00:00:00',TRUE);
CREATE TABLE profile_temporal(early TIMESTAMP,modern TIMESTAMP,late TIMESTAMP,ns TIMESTAMP_NS,day DATE);
INSERT INTO profile_temporal VALUES
 (TIMESTAMP '0001-01-01',TIMESTAMP '2026-01-01',TIMESTAMP '9999-01-01',make_timestamp_ns(epoch_ns(TIMESTAMP '2026-01-01')+700),DATE '0001-01-01'),
 (TIMESTAMP '0001-01-01',TIMESTAMP '2026-01-01',TIMESTAMP '9999-01-01',make_timestamp_ns(epoch_ns(TIMESTAMP '2026-01-01')+1700),DATE '0001-01-02'),
 (TIMESTAMP '0001-01-01 00:00:00.000001',TIMESTAMP '2026-01-01 00:00:00.000001',TIMESTAMP '9999-01-01 00:00:00.000001',make_timestamp_ns(epoch_ns(TIMESTAMP '2026-01-01')+2700),DATE '0001-01-04'),
 (NULL,NULL,NULL,NULL,NULL);
CREATE TABLE profile_classify(n DOUBLE);
INSERT INTO profile_classify VALUES (NULL),('NaN'::DOUBLE),('Infinity'::DOUBLE),('-Infinity'::DOUBLE),(-1.5),(-2.5),(1.5),(2.5),(0);
CREATE TABLE parity_ordering(id INTEGER,label VARCHAR,amount DOUBLE,large BIGINT);
INSERT INTO parity_ordering VALUES
 (1,'😀','NaN'::DOUBLE,9007199254740993),(2,'','NaN'::DOUBLE,9007199254740992),
 (3,'𐐀','-Infinity'::DOUBLE,NULL),(4,'B',NULL,NULL),(5,'a',1,NULL),(6,'',-1,NULL),
 (7,NULL,'Infinity'::DOUBLE,NULL),(8,'İ',9007199254740992,NULL),(9,'ı',9007199254740992,NULL),
 (10,'Ş',0,NULL),(11,'i',-0.0,NULL),(12,'I',NULL,NULL);
CREATE TABLE parity_utf16_edges(id INTEGER,label VARCHAR);
CREATE TABLE parity_numeric_kinds AS
SELECT row_number() OVER ()::INTEGER AS id,1.015::REAL AS real_value,18446744073709551615::UBIGINT AS unsigned_value,
 123456789012345678.1234567890::DECIMAL(38,10) AS decimal_value,1.2345678901234567890123456789::DECIMAL(38,28) AS fine_value,
 digits,mode::INTEGER AS mode FROM (SELECT unnest([-2,0,2,15,25,28,29]::INTEGER[]) AS digits) AS d CROSS JOIN range(5) AS m(mode);
INSERT INTO parity_utf16_edges VALUES (1,'a'||chr(0)||'b'),(2,chr(0)),(3,chr(65535)),
 (4,chr(65279)||'x'||chr(65279)),(5,chr(9)||chr(160)||chr(8195)||'x'||chr(8239)||chr(12288)),
 (6,''),(7,NULL),(8,'😀'||chr(1)||'b');
CREATE TABLE parity_slice_matrix AS
SELECT row_number() OVER ()::INTEGER AS id,label,offset_value,count_value
FROM (SELECT label FROM parity_text UNION ALL SELECT label FROM parity_utf16_edges) AS t
CROSS JOIN (SELECT unnest([-1,0,1,2,3,4,5,99,1.5,NULL,-2147483648,-2147483649,2147483647,2147483648]::DOUBLE[]) AS offset_value) AS o
CROSS JOIN (SELECT unnest([-1,0,1,2,5,NULL,1.5,-2147483648,-2147483649,2147483647,2147483648]::DOUBLE[]) AS count_value) AS c;
CREATE TABLE gui_date_base(id INTEGER,d DATE);
CREATE TABLE gui_date_numeric(id INTEGER,n DECIMAL(38,28),integer_value UBIGINT);
INSERT INTO gui_date_numeric VALUES (1,0.9999999999999999999999999999,18446744073709551615),
 (2,1.0000000000000000000000000001,18446744073709551615),(3,-0.0000000000000000000000000001,18446744073709551615),
 (4,1,18446744073709551615),(5,NULL,18446744073709551615);
INSERT INTO gui_date_base VALUES (1,DATE '0001-01-01'),(2,DATE '0001-01-31'),(3,DATE '1582-10-04'),
 (4,DATE '1600-02-29'),(5,DATE '1700-02-28'),(6,DATE '1900-02-28'),(7,DATE '2000-02-29'),
 (8,DATE '2023-01-31'),(9,DATE '2024-01-31'),(10,DATE '2024-02-29'),(11,DATE '9999-12-31'),(12,NULL);
CREATE TABLE gui_date_matrix AS
SELECT row_number() OVER ()::INTEGER AS id,b.id AS base_id,d,
 CAST(d AS TIMESTAMP)+INTERVAL '12 hours 34 minutes 56.123456 seconds' AS dt,
 CASE WHEN d BETWEEN DATE '1678-01-01' AND DATE '2261-12-31' THEN CAST(d AS TIMESTAMP_NS)+INTERVAL '12 hours 34 minutes 56.123456 seconds' ELSE NULL END::TIMESTAMP_NS AS dt_ns,
 CASE WHEN d BETWEEN DATE '1900-01-01' AND DATE '2100-01-01' THEN CAST(CAST(d AS TIMESTAMP)+INTERVAL '12 hours 34 minutes 56.123456 seconds' AS TIMESTAMPTZ) ELSE NULL END AS dz,
 delta,first_day,'not a date'::VARCHAR AS label,TRUE AS flag,TIME '12:34:56.123456' AS clock,from_hex('0001ff') AS payload
FROM gui_date_base b
CROSS JOIN (SELECT unnest([NULL,-2147483649,-2147483648,-365,-31,-1,0,1,2,31,365,1.5,1.0000000000000002,2147483647,2147483648,'NaN'::DOUBLE,'Infinity'::DOUBLE]::DOUBLE[]) AS delta) n
CROSS JOIN (SELECT unnest([NULL,0,1,2,3,4,5,6,-1,7,1.5]::DOUBLE[]) AS first_day) w;
UPDATE gui_date_matrix SET dt_ns=make_timestamp_ns(epoch_ns(dt_ns)+700) WHERE dt_ns IS NOT NULL;
CREATE TABLE gui_text_base(id INTEGER,label VARCHAR,other_label VARCHAR);
INSERT INTO gui_text_base VALUES
 (1,'a😀b','B'),(2,'aaaaa','aa'),(3,'',''),(4,NULL,NULL),(5,',a,,b,','x'),
 (6,'ababa','aba'),(7,'İıIişŞ','İ'),(8,'a'||chr(0)||'b',chr(0)),
 (9,chr(9)||chr(160)||' x '||chr(10),NULL),(10,'😀😀b','😀'),
 (11,'e'||chr(769)||'é','e'),(12,'a"b''c\d%_','"'),
 (13,chr(65535)||chr(57344),'z'),(14,'x'||chr(1)||'😀'||chr(1)||'z',chr(1)),
 (15,'aaabaaa','aaa'),(16,'abc--def--','--');
CREATE TABLE gui_text_extract AS
SELECT row_number() OVER ()::INTEGER AS id,b.id AS base_id,b.label,b.other_label,n.n
FROM gui_text_base b CROSS JOIN
 (SELECT unnest([NULL,-2147483649,-2147483648,-9,-1,-0.5,0,0.5,1,1.5,2,3,4,5,8,64,2147483647,2147483648,'NaN'::DOUBLE,'Infinity'::DOUBLE,'-Infinity'::DOUBLE,1.0000000000000002]::DOUBLE[]) AS n) n;
CREATE TABLE gui_text_replace AS
SELECT row_number() OVER ()::INTEGER AS id,b.id AS base_id,b.label,b.other_label,p.id AS pattern_id,p.needle,r.id AS replacement_id,r.replacement
FROM gui_text_base b CROSS JOIN
 (SELECT row_number() OVER ()::INTEGER AS id,unnest([NULL,'','a','aa','aaa','aba',',','--','😀',chr(0),chr(1),'İ','not-found','half-high','half-low']) AS needle) p CROSS JOIN
 (SELECT row_number() OVER ()::INTEGER AS id,unnest([NULL,'','X','😀',chr(0),',','half-high','half-low']) AS replacement) r;
'@
    [void]$command.ExecuteNonQuery()
    $ordinalMap=(Get-Content (Join-Path (Split-Path $PSScriptRoot) 'OrdinalIgnoreCase.pqm') | Select-Object -Last 1).Trim().Trim('"')
    if($ordinalMap -notmatch '^map\(\[[0-9,]+\]::BIGINT\[\],\[[0-9,]+\]::BIGINT\[\]\)$'){throw 'Invalid generated ordinal map fixture SQL.'}
    $command.CommandText="CREATE TABLE parity_ordinal_pairs AS SELECT row_number() OVER ()::INTEGER AS id,chr(entry.key::INTEGER) AS label,chr(entry.value::INTEGER) AS other_label FROM unnest(map_entries($ordinalMap)) AS t(entry)"
    [void]$command.ExecuteNonQuery()
    $command.CommandText="INSERT INTO parity_ordinal_pairs VALUES (974,chr(305),'I'),(975,chr(304),'i'),(976,chr(223),chr(7838)),(977,chr(383),'S'),(978,chr(962),chr(963)),(979,chr(8490),'k'),(980,chr(66560),chr(66600))"
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
    $command.CommandText='SELECT count(*) FROM gui_date_matrix'
    if($command.ExecuteScalar() -ne 2244){throw 'Date matrix fixture count mismatch.'}
    foreach($entry in @(@('gui_text_extract',352),@('gui_text_replace',1920))){
        $command.CommandText='SELECT count(*) FROM '+$entry[0]
        if($command.ExecuteScalar() -ne $entry[1]){throw 'Text-shaping matrix fixture count mismatch.'}
    }
    [pscustomobject]@{ Engine=$version; Rows=1000000; Database=$DatabasePath }
} finally {
    if ($command) { $command.Dispose() }
    $connection.Dispose()
}

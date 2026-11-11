function Assert-PqTestResult {
    param([Parameter(Mandatory)]$Result, [int]$ExitCode = 0)
    if ($ExitCode -ne 0) { throw "PQTest exited with code $ExitCode." }
    $items = @($Result)
    if ($items.Count -eq 0) { throw 'PQTest returned no test results.' }
    foreach ($item in $items) {
        if ($item.Status -cne 'Passed') { throw "PQTest failed: $($item.Name) [$($item.Status)] $($item.Details)" }
        if (@($item.Output).Count -eq 0) { throw 'PQTest returned no comparison output.' }
        foreach ($output in $item.Output) {
            if ($output.Status -cne 'Passed' -or $output.SourceError -or $output.OutputError) {
                throw "PQTest comparison failed: $($output.Status) $($output.SourceError) $($output.OutputError)"
            }
        }
    }
}

function Assert-FoldingEvidence {
    param([Parameter(Mandatory)]$Result, [Parameter(Mandatory)]$Contract)
    $events = @($Result.DiagnosticEvents.Odbc)
    $starts = @($events | Where-Object EventName -eq 'QueryStart')
    $finishes = @($events | Where-Object EventName -eq 'QueryFinish')
    if ($starts.Count -ne 1 -or $finishes.Count -ne 1) { throw 'Expected exactly one ODBC query with complete diagnostics.' }
    if ($starts[0].Properties.Identifier -ne $finishes[0].Properties.Identifier) { throw 'ODBC diagnostic query identifiers do not match.' }
    if ($finishes[0].Properties.ExceptionMessage) { throw "ODBC query failed: $($finishes[0].Properties.ExceptionMessage)" }
    $sql = $starts[0].Properties.Command
    foreach ($pattern in $Contract.sqlPatterns) {
        if ($sql -notmatch $pattern) { throw "Folding contract missing SQL pattern '$pattern'. Actual SQL: $sql" }
    }
    if ($Contract.PSObject.Properties.Name -contains 'forbiddenPatterns') {
        foreach ($pattern in $Contract.forbiddenPatterns) {
            if ($sql -match $pattern) { throw "Folding contract forbids SQL pattern '$pattern'. Actual SQL: $sql" }
        }
    }
    $rows = $finishes[0].Properties.RowCount
    if ($null -eq $rows -or $rows -lt 0 -or $rows -gt $Contract.maxRows) {
        throw "ODBC returned $rows rows; allowed maximum is $($Contract.maxRows)."
    }
    [pscustomobject]@{ Query=$Contract.name; Status='Passed'; Rows=$rows; Sql=$sql }
}

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Test-Result.ps1')
function Must-Reject([string]$Name, [scriptblock]$Check) {
    $rejected = $false
    try { & $Check | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw "Runner accepted invalid evidence: $Name" }
    Write-Host "PASS runner rejects $Name"
}
$good = [pscustomobject]@{
    Name='fixture'; Status='Passed'; Details=''
    Output=@([pscustomobject]@{Status='Passed';SourceError=$null;OutputError=$null})
}
Assert-PqTestResult $good
Must-Reject 'nonzero exit' { Assert-PqTestResult $good -ExitCode 1 }
Must-Reject 'empty results' { Assert-PqTestResult -Result @() }
$failed = [pscustomobject]@{Name='fixture';Status='Failed';Details='simulated folding error';Output=$good.Output}
Must-Reject 'Failed JSON with exit code zero' { Assert-PqTestResult $failed -ExitCode 0 }
$badOutput = [pscustomobject]@{Name='fixture';Status='Passed';Details='';Output=@([pscustomobject]@{Status='Error';SourceError='error';OutputError=$null})}
Must-Reject 'nested comparison error' { Assert-PqTestResult $badOutput }
$emptyOutput = [pscustomobject]@{Name='fixture';Status='Passed';Details='';Output=@()}
Must-Reject 'empty comparison output' { Assert-PqTestResult $emptyOutput }
$contract = [pscustomobject]@{name='pagination';sqlPatterns=@('limit 3 offset 5');maxRows=3}
$evidence = [pscustomobject]@{DiagnosticEvents=[pscustomobject]@{Odbc=@(
    [pscustomobject]@{EventName='QueryStart';Properties=[pscustomobject]@{Identifier='query-1';Command='select id from folding limit 3 offset 5'}},
    [pscustomobject]@{EventName='QueryFinish';Properties=[pscustomobject]@{Identifier='query-1';ExceptionMessage=$null;RowCount=3}}
)}}
Assert-FoldingEvidence $evidence $contract | Out-Null
$evidence.DiagnosticEvents.Odbc[0].Properties.Command='select id from folding'
Must-Reject 'client evaluation without LIMIT/OFFSET' { Assert-FoldingEvidence $evidence $contract }
$evidence.DiagnosticEvents.Odbc[0].Properties.Command='select id from folding limit 3 offset 5'
$evidence.DiagnosticEvents.Odbc[1].Properties.RowCount=1000000
Must-Reject 'million-row transfer despite correct output' { Assert-FoldingEvidence $evidence $contract }
$evidence.DiagnosticEvents.Odbc[1].Properties.RowCount=3
$escapeContract = [pscustomobject]@{name='suffix';sqlPatterns=@('where');forbiddenPatterns=@('\{\s*fn\b');maxRows=3}
$evidence.DiagnosticEvents.Odbc[0].Properties.Command='select id from folding where { fn right(label, 5) } = ''99999'' limit 3'
Must-Reject 'ODBC escape despite a WHERE and small row count' { Assert-FoldingEvidence $evidence $escapeContract }
$evidence.DiagnosticEvents.Odbc[0].Properties.Command='select id from folding limit 3 offset 5'
$evidence.DiagnosticEvents.Odbc[1].Properties.Identifier='different-query'
Must-Reject 'mismatched diagnostic identifiers' { Assert-FoldingEvidence $evidence $contract }
$evidence.DiagnosticEvents.Odbc=@()
Must-Reject 'missing ODBC diagnostics' { Assert-FoldingEvidence $evidence $contract }

#requires -Version 7.2
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Connector,[Parameter(Mandatory)][string]$PqTest)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
. (Join-Path $PSScriptRoot 'Versioning.ps1')
Assert-PackageSources -Root $root -Connector $Connector
$packageHash = (Get-FileHash -LiteralPath $Connector).Hash
$run = Join-Path $root ('.agent/verification/' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $run)
$expected = @(Get-ChildItem (Join-Path $root 'test/folding') -Filter '*.query.pq' | Sort-Object Name | ForEach-Object { $_.Name -replace '\.query\.pq$','' })
$kinds = @('functional','references-controls','folding-0','folding-1','folding-2','folding-3')
$jobs = @()
try {
    foreach ($kind in $kinds) {
        $jobs += Start-Job -Name $kind -ArgumentList $root,$Connector,$PqTest,$run,$kind -ScriptBlock {
            param($root,$connector,$pqtest,$run,$kind)
            $ErrorActionPreference = 'Stop'
            # A fresh Windows job may otherwise decode PQTest's UTF-8 JSON as OEM.
            $OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
            Set-Location -LiteralPath $root
            & {
                if ($kind -eq 'functional') { ./tools/dev.ps1 test -Connector $connector }
                elseif ($kind -eq 'references-controls') {
                    ./tools/Test-Versioning.ps1
                    ./tools/Test-Runner.ps1
                    ./tools/Test-ParityReference.ps1 -PqTest $pqtest -Connector $connector
                    ./tools/Test-NegativeControls.ps1 -Connector $connector -PqTest $pqtest
                    ./tools/Test-NativeBoundaries.ps1 -Connector $connector -PqTest $pqtest
                } else {
                    ./tools/dev.ps1 test-folding -Connector $connector -ShardIndex ([int]$kind.Substring(8)) -ShardCount 4
                }
            } *> (Join-Path $run "$kind.log")
            if ($LASTEXITCODE -gt 0) { throw "Verification partition exited $LASTEXITCODE" }
            'Passed' | Set-Content -LiteralPath (Join-Path $run "$kind.passed")
        }
    }
    $pending = @($jobs)
    while ($pending.Count) {
        $finished = @($pending | Wait-Job -Any -Timeout 15)
        foreach ($job in $finished) {
            Write-Host "Finished verification partition $($job.Name): $($job.State)"
            $pending = @($pending | Where-Object Id -ne $job.Id)
        }
    }
    foreach ($job in $jobs) {
        $null = Receive-Job $job -ErrorAction Continue
        if ($job.State -ne 'Completed' -or -not (Test-Path -LiteralPath (Join-Path $run "$($job.Name).passed"))) {
            Get-Content -LiteralPath (Join-Path $run "$($job.Name).log") -Tail 30
            throw "Verification failed: $($job.Name). Evidence: $run"
        }
    }
    # Verify actual completed case names, not merely process exit status or counts.
    $actual = @(foreach ($index in 0..3) {
        $lines = Get-Content -LiteralPath (Join-Path $run "folding-$index.log")
        if (@($lines | Where-Object { $_ -match '^Passed \d+ tests\. Evidence:' }).Count -ne 1) { throw 'A folding partition did not complete.' }
        foreach ($line in $lines) { if ($line -match '^PASS (\S+) \(ODBC rows: \d+\)$') { $Matches[1] } }
    })
    if ($actual.Count -ne $expected.Count -or @($actual | Select-Object -Unique).Count -ne $expected.Count -or
        @(Compare-Object $expected ($actual | Sort-Object)).Count -ne 0) { throw 'Folding partitions have missing, duplicate or unexpected cases.' }
    Assert-PackageSources -Root $root -Connector $Connector
    if ((Get-FileHash -LiteralPath $Connector).Hash -ne $packageHash) { throw 'Verification artifact changed.' }
    [pscustomobject]@{Status='Passed';SHA256=$packageHash;FoldingCases=$actual.Count;Partitions=$kinds;Evidence=$run} |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run 'summary.json')
    Write-Host "PASS complete parallel verification: $($actual.Count) distinct folding cases, all functional/reference/control suites. Evidence: $run"
} finally {
    # Do not abandon running tests when a sibling fails; preserve their evidence.
    if ($jobs.Count) { $null = $jobs | Wait-Job; $jobs | Remove-Job -Force }
}

#requires -Version 7.2
param([Parameter(Mandatory)][string]$Connector)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
. (Join-Path $PSScriptRoot 'Versioning.ps1')
$state = Get-ReleaseState $root
Assert-PackageSources -Root $root -Connector $Connector
$toolchain = Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$pqtest = Join-Path $root ".agent/tools/sdk/$($toolchain.sdkVersion)/tools/PQTest.exe"
$raw = & $pqtest info -e (Resolve-Path -LiteralPath $Connector).Path
if ($LASTEXITCODE -ne 0) { throw 'Package failed SDK loading.' }
$info = @(($raw -join "`n") | ConvertFrom-Json)
if ($info.Count -ne 1 -or $info[0].Name -ne 'DuckDB' -or $info[0].ErrorStatus) { throw 'Package is not a valid DuckDB extension.' }
$output = Join-Path $root '.agent/package-checks'
[void](New-Item -ItemType Directory -Path $output -Force)
[pscustomobject]@{Status='Passed';Version=$state.Version;SHA256=(Get-FileHash -LiteralPath $Connector).Hash;SDK=$toolchain.sdkVersion} |
    ConvertTo-Json | Set-Content (Join-Path $output 'summary.json')
Write-Host 'PASS package/source integrity and SDK extension loading; no ODBC fixture or M/folding suite needed for metadata changes.'

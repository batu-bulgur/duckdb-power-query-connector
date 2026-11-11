#requires -Version 7.2
[CmdletBinding()]
param([string]$BaseRef,[string]$Connector)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path $PSScriptRoot
. (Join-Path $PSScriptRoot 'Versioning.ps1')
$state = Get-ReleaseState $root
if ($BaseRef) {
    $baseSha = & git -C $root rev-parse --verify "$BaseRef^{commit}"
    if ($LASTEXITCODE -ne 0 -or $baseSha -notmatch '^[a-f0-9]{40}$') { throw 'Invalid version comparison base.' }
    $previousText = & git -C $root show ('{0}:VERSION' -f $baseSha) 2>$null
    $previous = if ($LASTEXITCODE -eq 0) { ($previousText -join "`n").Trim() } else { '0.2.0' }
    $changed = @(& git -C $root diff --name-only $baseSha --)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect versioned changes.' }
    [xml]$project = Get-Content -LiteralPath (Join-Path $root 'DuckDB.proj') -Raw
    $resources = @($project.Project.ItemGroup.MezContent | ForEach-Object { [string]$_.Include })
    $runtimeChanged = @($changed | Where-Object { $_ -in $resources }).Count -gt 0
    Assert-VersionTransition -Previous $previous -Current $state.Version -Kind $state.Kind -RuntimeChanged $runtimeChanged
    Assert-ReleaseNotesChanges -Previous $previous -Current $state.Version -Paths $changed
}
if ($Connector) { Assert-PackageSources -Root $root -Connector $Connector }
Write-Host "PASS version $($state.Version), metadata, notes and requested package/transition checks."

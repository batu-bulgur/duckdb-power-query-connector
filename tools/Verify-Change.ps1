#requires -Version 7.2
[CmdletBinding()]
param([string]$BaseRef='origin/main',[string]$Connector,[switch]$ScopeOnly,[switch]$ForceFull,[switch]$GitHubOutput)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path $PSScriptRoot
. (Join-Path $PSScriptRoot 'ValidationScope.ps1')
$baseSha = & git -C $root rev-parse --verify "$BaseRef^{commit}"
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the validation base; do not assume a metadata-only change.' }
$paths = @(& git -C $root diff --no-renames --name-only $baseSha --)
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect changed files.' }
$untracked = @(& git -C $root ls-files --others --exclude-standard)
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect untracked files.' }
$paths = @($paths + $untracked | Sort-Object -Unique)
[xml]$project = Get-Content (Join-Path $root 'DuckDB.proj') -Raw
$resources = @($project.Project.ItemGroup.MezContent | ForEach-Object { [string]$_.Include })
$workflowDiff = @(& git -C $root diff --no-color --unified=0 $baseSha -- .github/workflows/build.yaml)
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect workflow environment changes.' }
$scope = Get-ValidationScope -Paths $paths -Resources $resources -ForceFull:$ForceFull -RuntimeEnvironmentChanged:(Test-RuntimeWorkflowChange $workflowDiff)
if ($GitHubOutput) { "scope=$scope" | Add-Content -LiteralPath $env:GITHUB_OUTPUT }
if ($ScopeOnly) { return $scope }
& (Join-Path $PSScriptRoot 'Test-ValidationScope.ps1')
& (Join-Path $PSScriptRoot 'Test-Version.ps1') -BaseRef $baseSha
if ($scope -eq 'full') {
    Write-Host 'Validation scope: full (connector, test, toolchain, manual request or unknown changes).'
    $options = @{Parallel=$true}
    if ($Connector) { $options.Connector = $Connector }
    & (Join-Path $PSScriptRoot 'dev.ps1') verify @options
    if ($LASTEXITCODE -ne 0) { throw 'Full verification failed.' }
} else {
    Write-Host 'Validation scope: metadata (version/publisher guards, package integrity and SDK loading).'
    & (Join-Path $PSScriptRoot 'Test-Versioning.ps1')
    & (Join-Path $PSScriptRoot 'dev.ps1') bootstrap
    if ($LASTEXITCODE -ne 0) { throw 'SDK bootstrap failed.' }
    if (-not $Connector) {
        & (Join-Path $PSScriptRoot 'dev.ps1') build
        if ($LASTEXITCODE -ne 0) { throw 'Package build failed.' }
        $Connector = Join-Path $root 'bin/AnyCPU/Debug/DuckDB.mez'
    }
    & (Join-Path $PSScriptRoot 'Test-ConnectorPackage.ps1') -Connector $Connector
}

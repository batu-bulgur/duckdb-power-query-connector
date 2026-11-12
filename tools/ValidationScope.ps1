# Pure change classification. Unknown files fail closed to full validation.
function Test-RuntimeWorkflowChange {
    param([string[]]$DiffLines)
    return @($DiffLines | Where-Object {
        $_ -match '^[+-](?![+-])' -and $_ -notmatch '^[+-]\s*#' -and
        $_ -match '(runs-on\s*:|container\s*:|uses\s*:|windows-|ubuntu-|macos-|architecture\s*:|ciOdbcVersion|duckdb_odbc|ODBCINST|DuckDB Driver|sdkVersion|api\.nuget|\bbootstrap\b)'
    }).Count -gt 0
}

function Get-ValidationScope {
    param([string[]]$Paths,[string[]]$Resources,[switch]$ForceFull,[switch]$RuntimeEnvironmentChanged)
    if ($ForceFull -or $RuntimeEnvironmentChanged) { return 'full' }
    $metadataTools = @(
        'tools/Versioning.ps1','tools/Test-Version.ps1','tools/Test-Versioning.ps1',
        'tools/Publish-ForkRelease.ps1','tools/Test-ReleasePublisher.ps1',
        'tools/ValidationScope.ps1','tools/Test-ValidationScope.ps1',
        'tools/Verify-Change.ps1','tools/Test-ConnectorPackage.ps1'
    )
    foreach ($path in $Paths) {
        if ($path -in $Resources -or $path -in @('DuckDB.proj','VERSION')) { return 'full' }
        if ($path -in $metadataTools -or $path -in @('.github/workflows/build.yaml','.github/workflows/fork-release.yaml') -or
            $path -match '^docs/' -or $path -in @('README.md','CHANGELOG.md','AGENTS.md','CONTRIBUTING.md')) { continue }
        return 'full'
    }
    return 'metadata'
}

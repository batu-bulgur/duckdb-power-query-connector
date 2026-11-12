#requires -Version 7.2
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ValidationScope.ps1')
$resources = @('DuckDB.pq','RoundScalar.pqm','DuckDB16.png','docs/packaged-resource.txt')
$cases = @(
    @{paths=@('docs/release-notes/0.4.0.md');expected='metadata'},
    @{paths=@('docs/release-note-corrections.json','tools/Publish-ForkRelease.ps1');expected='metadata'},
    @{paths=@('tools/Test-ReleasePublisher.ps1','tools/Versioning.ps1');expected='metadata'},
    @{paths=@('AGENTS.md','CHANGELOG.md','README.md');expected='metadata'},
    @{paths=@('.github/workflows/build.yaml','tools/Verify-Change.ps1','tools/Test-ConnectorPackage.ps1','tools/ValidationScope.ps1','tools/Test-ValidationScope.ps1');expected='metadata'},
    @{paths=@('DuckDB.pq');expected='full'},
    @{paths=@('RoundScalar.pqm','docs/release-notes/0.5.0.md');expected='full'},
    @{paths=@('DuckDB16.png');expected='full'},
    @{paths=@('docs/packaged-resource.txt');expected='full'},
    @{paths=@('DuckDB.proj');expected='full'},
    @{paths=@('VERSION');expected='full'},
    @{paths=@('test/folding/contracts.json');expected='full'},
    @{paths=@('test/folding/example.query.pqout');expected='full'},
    @{paths=@('tools/Seed-Fixture.ps1');expected='full'},
    @{paths=@('tools/dev.ps1');expected='full'},
    @{paths=@('tools/Test-Result.ps1');expected='full'},
    @{paths=@('tools/Test-Runner.ps1');expected='full'},
    @{paths=@('tools/Invoke-ParallelVerification.ps1');expected='full'},
    @{paths=@('tools/Initialize-Sdk.ps1');expected='full'},
    @{paths=@('tools/toolchain.json');expected='full'},
    @{paths=@('.gitattributes');expected='full'},
    @{paths=@('.gitignore');expected='full'},
    @{paths=@('new-unknown-file.txt');expected='full'},
    @{paths=@('RoundScalar.pqm','docs/renamed-runtime.md');expected='full'},
    @{paths=@('test/deleted-case.query.pq');expected='full'},
    @{paths=@();expected='metadata'}
)
foreach ($case in $cases) {
    $scope = Get-ValidationScope -Paths $case.paths -Resources $resources
    if ($scope -ne $case.expected) { throw "Wrong scope for $($case.paths -join ', '): $scope" }
}
if ((Get-ValidationScope @('docs/only.md') $resources -ForceFull) -ne 'full') { throw 'Manual full verification was ignored.' }
foreach ($line in @('+ runs-on: windows-2022','+ uses: actions/checkout@v7','- $asset = "duckdb_odbc.zip"','+ ./tools/dev.ps1 bootstrap -new-option')) {
    if (-not (Test-RuntimeWorkflowChange @($line))) { throw "Missed runtime environment change: $line" }
}
if (Test-RuntimeWorkflowChange @('+++ b/.github/workflows/build.yaml','+ # ODBC metadata comment','+ if: needs.build.outputs.validation-scope == ''full''')) { throw 'Metadata routing was treated as an environment change.' }
if ((Get-ValidationScope @('.github/workflows/build.yaml') $resources -RuntimeEnvironmentChanged) -ne 'full') { throw 'Environment change did not require full validation.' }
Write-Host "PASS $($cases.Count + 7) validation-scope cases; runtime/test/toolchain/environment/unknown changes require full validation."

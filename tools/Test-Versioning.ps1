#requires -Version 7.2
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Versioning.ps1')
$checks = 0
function Must-Reject {
    param([string]$Name,[scriptblock]$Action)
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    if (-not $rejected) { throw "Versioning guard accepted: $Name" }
    $script:checks++
    Write-Host "PASS versioning rejects $Name"
}
Assert-VersionTransition '0.3.0' '0.3.1' 'patch' $true
Assert-VersionTransition '0.3.7' '0.4.0' 'minor' $true
Assert-VersionTransition '0.3.7' '1.0.0' 'major' $true
Assert-VersionTransition '0.3.0' '0.3.0' 'minor' $false
Must-Reject 'leading zero' { Get-SemVer '0.03.0' }
Must-Reject 'incomplete version' { Get-SemVer '0.3' }
Must-Reject 'version downgrade' { Assert-VersionTransition '0.3.0' '0.2.9' 'patch' $true }
Must-Reject 'runtime change without a bump' { Assert-VersionTransition '0.3.0' '0.3.0' 'minor' $true }
Must-Reject 'minor without resetting patch' { Assert-VersionTransition '0.3.7' '0.4.1' 'minor' $true }
Must-Reject 'major without resetting minor' { Assert-VersionTransition '0.3.7' '1.1.0' 'major' $true }
Must-Reject 'incorrect release classification' { Assert-VersionTransition '0.3.0' '0.4.0' 'patch' $true }
$goodRun = @{event='push';status='completed';conclusion='success';head_branch='main';head_sha=('a'*40);path='.github/workflows/build.yaml'}
Assert-ReleaseRun ([pscustomobject]$goodRun) ('a'*40) 'batu-bulgur/duckdb-power-query-connector'
foreach ($bad in @(@('event','pull_request'),@('conclusion','failure'),@('head_branch','codex/untrusted'),@('head_sha',('b'*40)),@('path','.github/workflows/other.yaml'))) {
    $candidate = $goodRun.Clone()
    $candidate[$bad[0]] = $bad[1]
    Must-Reject "untrusted release run $($bad[0])" { Assert-ReleaseRun ([pscustomobject]$candidate) ('a'*40) 'batu-bulgur/duckdb-power-query-connector' }
}
Must-Reject 'automatic upstream publication' { Assert-ReleaseRun ([pscustomobject]$goodRun) ('a'*40) 'motherduckdb/duckdb-power-query-connector' }
Assert-ReleaseNotesChanges '0.3.0' '0.4.0' @('docs/release-notes/0.4.0.md','README.md')
Must-Reject 'rewriting current published notes without a bump' { Assert-ReleaseNotesChanges '0.3.0' '0.3.0' @('docs/release-notes/0.3.0.md') }
Must-Reject 'rewriting older notes during a new release' { Assert-ReleaseNotesChanges '0.3.0' '0.4.0' @('docs/release-notes/0.3.0.md') }

# Exercise correction authorization against real Git blobs, including CRLF files.
$correctionRoot = Join-Path (Split-Path $PSScriptRoot) ('.agent/versioning-tests/correction-' + [guid]::NewGuid().ToString('N'))
$notePath = 'docs/release-notes/0.3.0.md'
[void](New-Item -ItemType Directory -Path (Join-Path $correctionRoot 'docs/release-notes') -Force)
$null = & git -C $correctionRoot init --quiet
if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize correction fixture.' }
'*.md text eol=lf' | Set-Content (Join-Path $correctionRoot '.gitattributes')
'Original published notes' | Set-Content (Join-Path $correctionRoot $notePath)
$null = & git -C $correctionRoot add -- .gitattributes $notePath
$fixtureTree = & git -C $correctionRoot write-tree
if ($LASTEXITCODE -ne 0) { throw 'Cannot write correction fixture tree.' }
$oldBlob = & git -C $correctionRoot rev-parse ('{0}:{1}' -f $fixtureTree,$notePath)
Assert-ReleaseNotesChanges '0.3.0' '0.3.0' @() $correctionRoot $fixtureTree
[IO.File]::WriteAllText((Join-Path $correctionRoot $notePath),"English correction`r`n")
$newBlob = & git -C $correctionRoot hash-object -- $notePath
Must-Reject 'historical correction without a ledger' { Assert-ReleaseNotesChanges '0.3.0' '0.3.0' @($notePath) $correctionRoot $fixtureTree }
$correction = @{path=$notePath;fromBlob=$oldBlob;toBlob=$newBlob;reason='Synthetic language correction'}
$ledgerPath = Join-Path $correctionRoot 'docs/release-note-corrections.json'
ConvertTo-Json -InputObject @($correction) | Set-Content $ledgerPath
Assert-ReleaseNotesChanges '0.3.0' '0.3.0' @($notePath) $correctionRoot $fixtureTree
foreach ($field in @('path','fromBlob','toBlob','reason')) {
    $invalid = $correction.Clone()
    $invalid[$field] = if ($field -eq 'reason') { '' } else { 'wrong' }
    ConvertTo-Json -InputObject @($invalid) | Set-Content $ledgerPath
    Must-Reject "correction with incorrect $field" { Assert-ReleaseNotesChanges '0.3.0' '0.3.0' @($notePath) $correctionRoot $fixtureTree }
}
ConvertTo-Json -InputObject @($correction) | Set-Content $ledgerPath
'Unexpected later rewrite' | Set-Content (Join-Path $correctionRoot $notePath)
Must-Reject 'later edit reusing a translation authorization' { Assert-ReleaseNotesChanges '0.3.0' '0.3.0' @($notePath) $correctionRoot $fixtureTree }

$run = Join-Path (Split-Path $PSScriptRoot) ('.agent/versioning-tests/' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $run 'source'
[void](New-Item -ItemType Directory -Path $source -Force)
'<Project><ItemGroup><MezContent Include="DuckDB.pq"/><MezContent Include="helper.pqm"/></ItemGroup></Project>' | Set-Content (Join-Path $run 'DuckDB.proj')
'[Version = "0.3.0"]' | Set-Content (Join-Path $source 'DuckDB.pq')
'synthetic helper' | Set-Content (Join-Path $source 'helper.pqm')
Copy-Item (Join-Path $source '*') $run
$package = Join-Path $run 'fixture.mez'
[IO.Compression.ZipFile]::CreateFromDirectory($source,$package)
Assert-PackageSources $run $package
'changed synthetic helper' | Set-Content (Join-Path $run 'helper.pqm')
Must-Reject 'stale package resource' { Assert-PackageSources $run $package }
$archive = [IO.Compression.ZipFile]::Open($package,[IO.Compression.ZipArchiveMode]::Update)
try { $null = $archive.CreateEntry('unexpected.txt') } finally { $archive.Dispose() }
Must-Reject 'extra packaged resource' { Assert-PackageSources $run $package }
$noteDirectory = Join-Path $run 'docs/release-notes'
[void](New-Item -ItemType Directory -Path $noteDirectory -Force)
'0.3.0' | Set-Content (Join-Path $run 'VERSION')
"<!-- release-type: minor -->`n## Added`nSynthetic`n## Query folding`nSynthetic`n## Known limitations`nSynthetic`n## Validation`nSynthetic" | Set-Content (Join-Path $noteDirectory '0.3.0.md')
$null = Get-ReleaseState $run
'[Version = "0.2.0"]' | Set-Content (Join-Path $run 'DuckDB.pq')
Must-Reject 'version/connector metadata mismatch' { Get-ReleaseState $run }
'0.3.1' | Set-Content (Join-Path $run 'VERSION')
'[Version = "0.3.1"]' | Set-Content (Join-Path $run 'DuckDB.pq')
Must-Reject 'version increment without release notes' { Get-ReleaseState $run }
Write-Host "Version transitions/package checks and $checks rejection checks passed."

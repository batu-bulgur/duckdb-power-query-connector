#requires -Version 7.2
$ErrorActionPreference = 'Stop'
$root = Join-Path (Split-Path $PSScriptRoot) ('.agent/publisher-tests/' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path (Join-Path $root 'tools'),(Join-Path $root 'docs/release-notes'),(Join-Path $root 'package'))
foreach ($file in @('Versioning.ps1','Test-Version.ps1','Publish-ForkRelease.ps1')) { Copy-Item (Join-Path $PSScriptRoot $file) (Join-Path $root "tools/$file") }
$null = & git -C $root init --quiet
'0.4.0' | Set-Content (Join-Path $root 'VERSION')
'[Version = "0.4.0"]' | Set-Content (Join-Path $root 'DuckDB.pq')
'<Project><ItemGroup><MezContent Include="DuckDB.pq"/></ItemGroup></Project>' | Set-Content (Join-Path $root 'DuckDB.proj')
Copy-Item (Join-Path $root 'DuckDB.pq') (Join-Path $root 'package/DuckDB.pq')
$oldNotes = "<!-- release-type: minor -->`n## Added`nSynthetic`n## Query folding`nSynthetic`n## Known limitations`nSynthetic`n## Validation`n[scope](../scope.md)`n"
$notesPath = Join-Path $root 'docs/release-notes/0.4.0.md'
[IO.File]::WriteAllText($notesPath,$oldNotes)
$null = & git -C $root add -- VERSION DuckDB.pq DuckDB.proj docs/release-notes/0.4.0.md
$tree = & git -C $root write-tree
$originalSha = & git -C $root -c user.name=Fixture -c user.email=fixture@example.invalid commit-tree $tree -m Initial
$null = & git -C $root update-ref HEAD $originalSha
$fromBlob = & git -C $root hash-object -- docs/release-notes/0.4.0.md
$newNotes = $oldNotes.Replace('../scope.md','https://example.com/scope.md')
[IO.File]::WriteAllText($notesPath,$newNotes)
$toBlob = & git -C $root hash-object -- docs/release-notes/0.4.0.md
ConvertTo-Json -InputObject @(@{path='docs/release-notes/0.4.0.md';fromBlob=$fromBlob;toBlob=$toBlob;reason='Synthetic user-approved link correction'}) |
    Set-Content (Join-Path $root 'docs/release-note-corrections.json')
$null = & git -C $root add -- docs
$tree = & git -C $root write-tree
$currentSha = & git -C $root -c user.name=Fixture -c user.email=fixture@example.invalid commit-tree $tree -p $originalSha -m Correction
$null = & git -C $root update-ref HEAD $currentSha $originalSha
$null = & git -C $root update-ref refs/remotes/origin/main $currentSha
if ($LASTEXITCODE -ne 0) { throw 'Cannot construct publisher fixture history.' }
[IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $root 'package'),(Join-Path $root 'fixture.mez'))
$hash = (Get-FileHash (Join-Path $root 'fixture.mez')).Hash.ToLowerInvariant()
$manifest = @{version='0.4.0';commit=$originalSha;sha256=$hash;buildRun='1'}
$originalRelease = [pscustomobject]@{id=10;tag_name='fork-v0.4.0';target_commitish=$originalSha;name='Synthetic release';published_at='2026-01-01';draft=$false;prerelease=$false;body=$oldNotes;assets=@(
    [pscustomobject]@{id=11;name='duckdb-power-query-connector.mez';size=1;digest="sha256:$hash"},
    [pscustomobject]@{id=12;name='release-manifest.json';size=2;digest='synthetic'},
    [pscustomobject]@{id=13;name='SHA256SUMS';size=3;digest='synthetic'})}
$fixture = @{Release=$originalRelease;Edits=0;Mutate=$false}
function gh {
    $global:LASTEXITCODE = 0
    if ($args[0] -eq 'api') {
        $path = $args[1]
        if ($path -match '/actions/runs/([12])$') {
            return (@{event='push';status='completed';conclusion='success';head_branch='main';path='.github/workflows/build.yaml';head_sha=if($Matches[1] -eq '1'){$originalSha}else{$currentSha}} | ConvertTo-Json -Compress)
        }
        if ($path -like '*/git/ref/tags/*') { return (@{object=@{type='commit';sha=$originalSha}} | ConvertTo-Json -Compress) }
        if ($path -like '*/releases/tags/*') { return ($fixture.Release | ConvertTo-Json -Depth 6 -Compress) }
    }
    if (($args[0] -eq 'run' -or $args[0] -eq 'release') -and $args[1] -eq 'download') {
        $destination = $args[[array]::IndexOf($args,'--dir')+1]
        [void](New-Item -ItemType Directory -Path $destination -Force)
        Copy-Item (Join-Path $root 'fixture.mez') (Join-Path $destination 'duckdb-power-query-connector.mez')
        if ($args[0] -eq 'release') { $manifest | ConvertTo-Json | Set-Content (Join-Path $destination 'release-manifest.json') }
        return
    }
    if ($args[0] -eq 'release' -and $args[1] -eq 'edit') {
        if ('--notes-file' -notin $args -or '--verify-tag' -notin $args -or '--target' -in $args -or '--tag' -in $args) { throw 'Unexpected release mutation.' }
        $fixture.Edits++
        $fixture.Release.body = [IO.File]::ReadAllText($args[[array]::IndexOf($args,'--notes-file')+1])
        if ($fixture.Mutate) { $fixture.Release.assets[0].size++ }
        return
    }
    throw "Unmocked GitHub command; network execution is forbidden in this fixture: $($args -join ' ')"
}
$originalRepository = $env:GITHUB_REPOSITORY
try {
    $env:GITHUB_REPOSITORY = 'batu-bulgur/duckdb-power-query-connector'
    & (Join-Path $root 'tools/Publish-ForkRelease.ps1') -SourceRunId 2 -HeadSha $currentSha
    if ($fixture.Edits -ne 1 -or $fixture.Release.body -cne $newNotes) { throw 'Publisher did not apply the exact note correction.' }
    & (Join-Path $root 'tools/Publish-ForkRelease.ps1') -SourceRunId 2 -HeadSha $currentSha
    if ($fixture.Edits -ne 1) { throw 'Publisher repeated an already completed correction.' }
    Write-Host 'PASS publisher applies reviewed correction once without replacing assets or tag.'
    $fixture.Release.body = 'Unexpected user edit'
    $rejected = $false
    try { & (Join-Path $root 'tools/Publish-ForkRelease.ps1') -SourceRunId 2 -HeadSha $currentSha } catch { $rejected = $true }
    if (-not $rejected -or $fixture.Edits -ne 1) { throw 'Publisher overwrote an unexpected user edit.' }
    Write-Host 'PASS publisher refuses unexpected published-note edits.'
    $fixture.Release.body = $oldNotes
    $fixture.Mutate = $true
    $rejected = $false
    try { & (Join-Path $root 'tools/Publish-ForkRelease.ps1') -SourceRunId 2 -HeadSha $currentSha } catch { $rejected = $true }
    if (-not $rejected) { throw 'Publisher missed changed asset identity.' }
    Write-Host 'PASS publisher detects changed assets after a note edit.'
} finally { $env:GITHUB_REPOSITORY = $originalRepository }

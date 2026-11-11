#requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[0-9]+$')][string]$SourceRunId,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$HeadSha
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repository = 'batu-bulgur/duckdb-power-query-connector'
if ($env:GITHUB_REPOSITORY -ne $repository) { throw 'Automatic publishing is restricted to the personal fork.' }
$root = Split-Path $PSScriptRoot
. (Join-Path $PSScriptRoot 'Versioning.ps1')
function Invoke-GhJson {
    param([string[]]$Arguments)
    $raw = & gh @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI request failed.' }
    ($raw -join "`n") | ConvertFrom-Json
}
$run = Invoke-GhJson -Arguments @('api',"repos/$repository/actions/runs/$SourceRunId")
Assert-ReleaseRun -Run $run -HeadSha $HeadSha -Repository $env:GITHUB_REPOSITORY
if ((& git -C $root rev-parse HEAD) -ne $HeadSha) { throw 'Checkout differs from the validated build commit.' }
& git -C $root merge-base --is-ancestor $HeadSha origin/main
if ($LASTEXITCODE -ne 0) { throw 'Release commit is not on main.' }
$versionChanged = @(& git -C $root diff --name-only HEAD^ HEAD -- VERSION)
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the version change.' }
if ('VERSION' -notin $versionChanged) { Write-Host 'No version increment in this commit; no release needed.'; return }
& (Join-Path $PSScriptRoot 'Test-Version.ps1') -BaseRef HEAD^
$state = Get-ReleaseState $root
$tag = $state.Tag
$output = Join-Path $root ".agent/fork-release/$SourceRunId"
[void](New-Item -ItemType Directory -Path $output -Force)
& gh run download $SourceRunId --repo $repository --name duckdb-power-query-connector --dir $output
if ($LASTEXITCODE -ne 0) { throw 'Could not download the validated artifact.' }
$mez = Join-Path $output 'duckdb-power-query-connector.mez'
Assert-PackageSources $root $mez
$hash = (Get-FileHash -LiteralPath $mez -Algorithm SHA256).Hash.ToLowerInvariant()
$existing = & gh api "repos/$repository/releases/tags/$tag" 2>$null
if ($LASTEXITCODE -eq 0) {
    $release = ($existing -join "`n") | ConvertFrom-Json
    $tagRef = Invoke-GhJson -Arguments @('api',"repos/$repository/git/ref/tags/$tag")
    $missingAssets = @(@('duckdb-power-query-connector.mez','SHA256SUMS','release-manifest.json') | Where-Object { $_ -notin $release.assets.name })
    $asset = @($release.assets | Where-Object name -eq 'duckdb-power-query-connector.mez')
    if ($release.draft -or $tagRef.object.type -ne 'commit' -or $tagRef.object.sha -ne $HeadSha -or
        $missingAssets.Count -gt 0 -or $release.assets.Count -ne 3 -or $asset.Count -ne 1) {
        throw 'Existing release is incomplete or targets another commit; never overwrite a published version.'
    }
    # Rebuilding the same source can change ZIP timestamps. Validate the existing
    # published bytes and manifest rather than replacing them with a new build.
    $published = Join-Path $output 'published'
    & gh release download $tag --repo $repository --dir $published
    if ($LASTEXITCODE -ne 0) { throw 'Could not verify the existing release assets.' }
    $publishedMez = Join-Path $published 'duckdb-power-query-connector.mez'
    Assert-PackageSources $root $publishedMez
    $publishedHash = (Get-FileHash -LiteralPath $publishedMez -Algorithm SHA256).Hash.ToLowerInvariant()
    $publishedManifest = Get-Content (Join-Path $published 'release-manifest.json') -Raw | ConvertFrom-Json
    if ($publishedManifest.commit -ne $HeadSha -or $publishedManifest.version -ne $state.Version -or
        $publishedManifest.sha256 -ne $publishedHash -or $asset[0].digest -ne "sha256:$publishedHash") {
        throw 'Existing published artifact/manifest digest verification failed.'
    }
    Write-Host "Already published: $($release.html_url)"
    return
}
$tagResult = & gh api "repos/$repository/git/ref/tags/$tag" 2>$null
if ($LASTEXITCODE -eq 0) {
    $tagRef = ($tagResult -join "`n") | ConvertFrom-Json
    if ($tagRef.object.type -ne 'commit' -or $tagRef.object.sha -ne $HeadSha) { throw 'Existing tag points elsewhere.' }
}
$checksums = Join-Path $output 'SHA256SUMS'
[IO.File]::WriteAllText($checksums,"$hash  duckdb-power-query-connector.mez`n",[Text.UTF8Encoding]::new($false))
$toolchain = Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$manifest = Join-Path $output 'release-manifest.json'
[ordered]@{version=$state.Version;tag=$tag;commit=$HeadSha;buildRun=$SourceRunId;buildUrl=$run.html_url;
    sdkVersion=$toolchain.sdkVersion;odbcVersion=$toolchain.ciOdbcVersion;sha256=$hash} |
    ConvertTo-Json | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM
& gh release create $tag $mez $checksums $manifest --repo $repository --target $HeadSha --title "DuckDB Power Query Connector - fork $($state.Version)" --notes-file $state.Notes
if ($LASTEXITCODE -ne 0) { throw 'Release publication failed; inspect draft/upload state before retrying.' }
$release = Invoke-GhJson -Arguments @('api',"repos/$repository/releases/tags/$tag")
$asset = @($release.assets | Where-Object name -eq 'duckdb-power-query-connector.mez')
$missingAssets = @(@('duckdb-power-query-connector.mez','SHA256SUMS','release-manifest.json') | Where-Object { $_ -notin $release.assets.name })
$tagRef = Invoke-GhJson -Arguments @('api',"repos/$repository/git/ref/tags/$tag")
if ($release.draft -or $missingAssets.Count -gt 0 -or $asset.Count -ne 1 -or $asset[0].digest -ne "sha256:$hash" -or
    $tagRef.object.type -ne 'commit' -or $tagRef.object.sha -ne $HeadSha) { throw 'Published artifact/tag verification failed.' }
Write-Host "Published and verified: $($release.html_url)"

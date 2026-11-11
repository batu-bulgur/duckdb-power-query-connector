# Shared pure validation; no network calls or installed-application changes.
function Get-SemVer {
    param([Parameter(Mandatory)][string]$Text)
    if ($Text -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
        throw "Expected a normal MAJOR.MINOR.PATCH version without leading zeroes: $Text"
    }
    [pscustomobject]@{Major=[bigint]$Matches[1];Minor=[bigint]$Matches[2];Patch=[bigint]$Matches[3]}
}

function Assert-VersionTransition {
    param([string]$Previous,[string]$Current,[string]$Kind,[bool]$RuntimeChanged)
    $before = Get-SemVer $Previous
    $after = Get-SemVer $Current
    if ($Previous -eq $Current) {
        if ($RuntimeChanged) { throw 'Connector resources changed without a version increment.' }
        return
    }
    $valid = switch ($Kind) {
        'patch' { $after.Major -eq $before.Major -and $after.Minor -eq $before.Minor -and $after.Patch -eq ($before.Patch + 1) }
        'minor' { $after.Major -eq $before.Major -and $after.Minor -eq ($before.Minor + 1) -and $after.Patch -eq 0 }
        'major' { $after.Major -eq ($before.Major + 1) -and $after.Minor -eq 0 -and $after.Patch -eq 0 }
        default { $false }
    }
    if (-not $valid) { throw "Invalid $Kind transition: $Previous -> $Current" }
}

function Get-ReleaseState {
    param([string]$Root)
    $version = (Get-Content -LiteralPath (Join-Path $Root 'VERSION') -Raw).Trim()
    $null = Get-SemVer $version
    $source = Get-Content -LiteralPath (Join-Path $Root 'DuckDB.pq') -Raw
    if ($source -notmatch '\[Version\s*=\s*"([^"]+)"\]') { throw 'Connector version metadata is missing.' }
    if ($Matches[1] -ne $version) { throw 'VERSION and DuckDB.pq metadata differ.' }
    $notes = Join-Path $Root "docs/release-notes/$version.md"
    if (-not (Test-Path -LiteralPath $notes)) { throw "Missing release notes for $version" }
    $text = Get-Content -LiteralPath $notes -Raw
    if ($text -notmatch '<!-- release-type: (patch|minor|major) -->') { throw 'Release notes require a release-type marker.' }
    $kind = $Matches[1]
    foreach ($heading in @('Eklenenler','Query folding','Sınırlar','Doğrulama')) {
        if ($text -notmatch "(?m)^## $heading\s*$") { throw "Release notes are missing section: $heading" }
    }
    [pscustomobject]@{Version=$version;Kind=$kind;Notes=$notes;Tag="fork-v$version"}
}

function Assert-PackageSources {
    param([string]$Root,[string]$Connector)
    [xml]$project = Get-Content -LiteralPath (Join-Path $Root 'DuckDB.proj') -Raw
    $resources = @($project.Project.ItemGroup.MezContent | ForEach-Object { [string]$_.Include })
    $zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Connector).Path)
    try {
        if ($zip.Entries.Count -ne $resources.Count) { throw 'Package resource count differs from DuckDB.proj.' }
        foreach ($name in $resources) {
            $entry = $zip.GetEntry($name)
            if (-not $entry) { throw "Package is missing resource: $name" }
            $stream = $entry.Open()
            try { $actual = (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash }
            finally { $stream.Dispose() }
            if ($actual -ne (Get-FileHash -LiteralPath (Join-Path $Root $name) -Algorithm SHA256).Hash) {
                throw "Package resource differs from the versioned source: $name"
            }
        }
    } finally { $zip.Dispose() }
}

function Assert-ReleaseRun {
    param($Run,[string]$HeadSha,[string]$Repository)
    if ($Repository -ne 'batu-bulgur/duckdb-power-query-connector' -or
        $Run.event -ne 'push' -or $Run.status -ne 'completed' -or $Run.conclusion -ne 'success' -or
        $Run.head_branch -ne 'main' -or $Run.head_sha -ne $HeadSha -or $Run.path -ne '.github/workflows/build.yaml') {
        throw 'Release requires the successful personal-fork main push build for the exact commit.'
    }
}

function Assert-ReleaseNotesChanges {
    param([string]$Previous,[string]$Current,[string[]]$Paths)
    foreach ($path in $Paths) {
        if ($path -like 'docs/release-notes/*.md' -and
            ($Current -eq $Previous -or $path -ne "docs/release-notes/$Current.md")) {
            throw "Previous release notes are immutable; record the correction in a new release: $path"
        }
    }
}

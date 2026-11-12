#requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory)]
    [ValidateSet('bootstrap','doctor','build','test','test-folding','test-parity','verify')][string]$Command,
    [string]$Connector,
    [string]$Case,
    [switch]$IncludeKnownLimitations,
    [switch]$Parallel,
    [ValidateRange(0,3)][int]$ShardIndex = 0,
    [ValidateRange(1,4)][int]$ShardCount = 1
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false
$repo = Split-Path $PSScriptRoot
$toolchain = Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$sdkRoot = Join-Path $repo ".agent/tools/sdk/$($toolchain.sdkVersion)"
$sdk = Join-Path $sdkRoot 'tools'
$pqtest = Join-Path $sdk 'PQTest.exe'
$defaultMez = Join-Path $repo 'bin/AnyCPU/Debug/DuckDB.mez'
. (Join-Path $PSScriptRoot 'Test-Result.ps1')

function Invoke-PqJson {
    param([string[]]$Arguments, [string]$LogPath)
    $raw = & $pqtest @Arguments
    $nativeExit = $LASTEXITCODE
    $text = $raw -join [Environment]::NewLine
    if ($LogPath) { [IO.File]::WriteAllText($LogPath, $text) }
    if ($nativeExit -ne 0) { throw "PQTest exited $nativeExit. $text" }
    if ([string]::IsNullOrWhiteSpace($text)) { throw 'PQTest returned empty output.' }
    try { return ConvertFrom-Json -InputObject $text } catch { throw "PQTest returned invalid JSON: $text" }
}

function Assert-Sdk {
    if (-not (Test-Path -LiteralPath $pqtest)) { throw 'SDK missing. Run: ./tools/dev.ps1 bootstrap' }
    & (Join-Path $PSScriptRoot 'Initialize-Sdk.ps1') -ToolsPath $sdk
    $version = Invoke-PqJson -Arguments @('version')
    if ($version.Application -ne "$($toolchain.sdkVersion).0") { throw 'SDK version does not match toolchain.json.' }
}

function Build-Connector {
    # Use the upstream .proj's allowlist so tests, logs, and credentials never enter the MEZ.
    [xml]$project = Get-Content (Join-Path $repo 'DuckDB.proj')
    $source = Join-Path $repo ('.agent/build/' + [guid]::NewGuid().ToString('N') + '/source')
    [void](New-Item -ItemType Directory -Path $source -Force)
    $entries = @($project.Project.ItemGroup.MezContent)
    foreach ($entry in $entries) {
        $file = [string]$entry.Include
        if ([IO.Path]::GetFileName($file) -ne $file) { throw "Review non-flat project resource: $file" }
        Copy-Item -LiteralPath (Join-Path $repo $file) -Destination $source
    }
    $output = Split-Path $defaultMez
    [void](New-Item -ItemType Directory -Path $output -Force)
    $compiled = & (Join-Path $sdk 'MakePQX.exe') compile $source -d $output -t DuckDB
    if ($LASTEXITCODE -ne 0) { throw 'MakePQX compile failed.' }
    $compileResult = ($compiled -join "`n") | ConvertFrom-Json
    if ($compileResult.TargetMezRootPath -ne $defaultMez -or -not (Test-Path -LiteralPath $defaultMez)) { throw 'Unexpected MakePQX output path.' }
    $modules = @(Invoke-PqJson -Arguments @('info','-e',$defaultMez))
    if ($modules.Count -ne 1 -or $modules[0].Name -ne 'DuckDB' -or $modules[0].ErrorStatus) { throw 'Built connector did not load as a valid DuckDB extension.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($defaultMez)
    try {
        if ($archive.Entries.Count -ne $entries.Count) { throw 'MEZ resource count differs from DuckDB.proj.' }
        foreach ($entry in $entries) {
            $packed = $archive.GetEntry([string]$entry.Include)
            if (-not $packed) { throw "MEZ resource missing: $($entry.Include)" }
            $stream = $packed.Open()
            try {
                $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream))
                if ($hash -ne (Get-FileHash (Join-Path $repo $entry.Include) -Algorithm SHA256).Hash) { throw "Stale MEZ resource: $($entry.Include)" }
            } finally { $stream.Dispose() }
        }
    } finally { $archive.Dispose() }
    # info loads the main section lazily; parse every packaged module as well.
    $moduleFiles=@($entries | Where-Object {[string]$_.Include -like '*.pqm'})
    $moduleTexts=@($moduleFiles | ForEach-Object {'"'+(Get-Content (Join-Path $repo $_.Include) -Raw).Replace('#','#(#)').Replace('"','""')+'"'})
    $syntaxQuery=Join-Path (Split-Path $source) 'parse-modules.pq'
    ('let values={'+($moduleTexts -join ',')+'}, parsed=List.Transform(values,each Expression.Evaluate(_,#shared)), forced=List.Sum(List.Transform(parsed,each if Value.Is(_,type any) then 1 else 0)) in #table({"parsed"},{{forced}})') | Set-Content $syntaxQuery -Encoding utf8
    $parsed=@(Invoke-PqJson -Arguments @('run-test','-e',$defaultMez,'-q',$syntaxQuery))
    if($parsed.Count -ne 1 -or $parsed[0].Status -ne 'Passed' -or $parsed[0].Output[0].parsed -ne $moduleFiles.Count){throw 'A packaged module failed syntax validation.'}
    Write-Host "Built and loaded $defaultMez ($($entries.Count) verified resources)."
}

function Invoke-RegressionSuite {
    param([switch]$Folding, [switch]$Parity)
    $run = Join-Path $repo ('.agent/test/' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    [void](New-Item -ItemType Directory -Path $run -Force)
    $fixture = & (Join-Path $PSScriptRoot 'Seed-Fixture.ps1') -DatabasePath (Join-Path $run 'fixture.db')
    $fixture | ConvertTo-Json | Set-Content (Join-Path $run 'fixture.json')
    Write-Host "Fixture: $($fixture.Rows) synthetic rows via DuckDB ODBC $($fixture.Engine)."
    $credentials = Join-Path $run 'credentials'
    $contracts = @(Get-Content (Join-Path $repo 'test/folding/contracts.json') -Raw | ConvertFrom-Json)
    $directory = if ($Folding) { Join-Path $repo 'test/folding' } else { Join-Path $repo 'test' }
    $files = @(Get-ChildItem -LiteralPath $directory -Filter '*.query.pq' | Sort-Object Name)
    if ($Folding -and $IncludeKnownLimitations) {
        $files += @(Get-ChildItem (Join-Path $repo 'test/negative') -Filter '*.query.pq' | Sort-Object Name)
        $contracts += @(Get-Content (Join-Path $repo 'test/negative/contracts.json') -Raw | ConvertFrom-Json)
    }
    if ($Parity) { $files = @($files | Where-Object Name -like 'parity_*.query.pq') }
    if ($Case) { $files = @($files | Where-Object Name -like "$Case.query.pq") }
    if ($ShardIndex -ge $ShardCount) { throw 'ShardIndex must be smaller than ShardCount.' }
    if ($ShardCount -gt 1) {
        if (-not $Folding) { throw 'Only folding cases may be partitioned.' }
        $files = @($files | Where-Object { ([array]::IndexOf($files, $_) % $ShardCount) -eq $ShardIndex })
    }
    if ($files.Count -eq 0) { throw 'No matching test cases; refusing an empty test suite.' }
    $summary = [Collections.Generic.List[object]]::new()
    foreach ($file in $files) {
        $name = $file.Name -replace '\.query\.pq$',''
        $query = Join-Path $run $file.Name
        $baseline = [IO.Path]::ChangeExtension($file.FullName, '.pqout')
        if (-not (Test-Path -LiteralPath $baseline)) { throw "Missing committed baseline: $baseline" }
        $baselineText = Get-Content -LiteralPath $baseline -Raw
        if ($baselineText -match 'serialize failed|/\*|^\s*error\b') { throw "Invalid/error baseline: $baseline" }
        Copy-Item -LiteralPath $baseline -Destination ([IO.Path]::ChangeExtension($query, '.pqout'))
        # Escape M text delimiters. Backslashes are literal in M.
        $dbText = $fixture.Database.Replace('"','""')
        (Get-Content -LiteralPath $file.FullName -Raw).Replace('__DB_PATH__',$dbText) | Set-Content -LiteralPath $query -Encoding utf8
        $template = Invoke-PqJson -Arguments @('credential-template','-e',$Connector,'-q',$query,'-ak','Anonymous')
        $credentialRaw = ($template | ConvertTo-Json -Depth 10 -Compress) | & $pqtest set-credential -e $Connector -q $query -cfp $credentials
        $credentialExit = $LASTEXITCODE
        $credentialResult = ($credentialRaw -join "`n") | ConvertFrom-Json
        if ($credentialExit -ne 0 -or $credentialResult.Status -ne 'Success') { throw 'Could not configure isolated anonymous test credentials.' }
        $arguments = @('compare','-e',$Connector,'-q',$query,'-cfp',$credentials,'--failOnMissingOutputFile')
        if ($Folding -or $name -eq 'parity_round_nan' -or $name -like 'parity_*_oracle') {
            $diagnostics = Join-Path $run "$name-diagnostics"
            [void](New-Item -ItemType Directory -Path $diagnostics)
            $arguments += @('--diagnosticsFolderPath',$diagnostics)
            if ($Folding) { $arguments += '--failOnFoldingFailure' }
        }
        $result = @(Invoke-PqJson -Arguments $arguments -LogPath (Join-Path $run "$name.json"))
        try {
            Assert-PqTestResult -Result $result
            if ($Folding) {
                $contract = @($contracts | Where-Object name -eq $name)
                if ($contract.Count -ne 1) { throw "Missing/duplicate folding contract for $name" }
                $dataResult=if($contract[0].PSObject.Properties.Name -contains 'metadataMaxRows'){Get-CatalogSeparatedEvidence -Result $result[0] -MetadataRows $contract[0].metadataMaxRows}else{$result[0]}
                $evidence = Assert-FoldingEvidence -Result $dataResult -Contract $contract[0]
                $summary.Add($evidence)
                Write-Host "PASS $name (ODBC rows: $($evidence.Rows))"
            } else {
                if ($name -eq 'parity_round_nan') {
                    # The final M IsNaN call is an oracle, deliberately after a
                    # buffer. Still require the preceding Round to execute in SQL.
                    Assert-FoldingEvidence -Result $result[0] -Contract ([pscustomobject]@{
                        name=$name;maxRows=1;sqlPatterns=@('round_even\(', 'HUGEINT')
                    }) | Out-Null
                }
                $oracle=if($name -eq 'parity_round_matrix_oracle'){@{maxRows=41595;pattern='round_even\(';patterns=@('round_even\(','HUGEINT')}}
                    elseif($name -eq 'parity_date_native_values_oracle'){@{maxRows=6;pattern='date_value';patterns=@('date_value','struct_pack')}}
                    elseif($name -eq 'parity_date_precision_oracle'){@{maxRows=5;pattern='date_value';patterns=@('date_value','HUGEINT','integer_parts','rtrim')}}
                    elseif($name -like 'parity_date_*_oracle'){@{maxRows=2244;pattern='date_value';patterns=@('date_value','struct_pack','safe_target')}}
                    elseif($name -like 'parity_filter_error_*_oracle'){@{maxRows=3;pattern='__duckdb_pq_error_';patterns=@('__duckdb_pq_error_','list_slice','coalesce')}}
                    elseif($name -like 'parity_index_*_oracle'){@{maxRows=10;pattern='WITH RECURSIVE';patterns=@('WITH RECURSIVE','pq_index_values')}}
                    elseif($name -eq 'parity_slice_matrix_oracle'){@{maxRows=3020;pattern='list_slice';patterns=@('list_slice','struct_pack')}}
                    elseif($name -eq 'parity_numeric_kinds_oracle'){@{maxRows=35;pattern='HUGEINT';patterns=@('HUGEINT','struct_pack')}}
                    elseif($name -eq 'parity_range_overflow_oracle'){@{maxRows=60;pattern='list_slice';patterns=@('list_slice','struct_pack')}}
                    elseif($name -eq 'parity_error_transport_oracle'){@{maxRows=5;pattern='struct_pack';patterns=@('list_slice','list_resize','struct_pack')}}else{$null}
                if ($oracle) {
                    $events=@($result[0].DiagnosticEvents.Odbc)
                    $starts=@($events | Where-Object EventName -eq QueryStart)
                    $metadata=@($starts|Where-Object {$_.Properties.Command -match 'FROM duckdb_columns\(\)'})
                    $expectedMetadata=if($name -in 'parity_date_dt_oracle','parity_date_dt_ns_oracle'){1}else{0}
                    if($starts.Count -ne (2+$expectedMetadata) -or $metadata.Count -ne $expectedMetadata){throw 'Differential oracle requires one folded query, one buffered M read, and only its declared catalog query.'}
                    $metadataRows=0
                    foreach($meta in $metadata){
                        $metaEvents=@($events|Where-Object {$_.Properties.Identifier -eq $meta.Properties.Identifier})
                        Assert-FoldingEvidence -Result ([pscustomobject]@{DiagnosticEvents=[pscustomobject]@{Odbc=$metaEvents}}) -Contract ([pscustomobject]@{name=$name;maxRows=16;sqlPatterns=@('SELECT column_name,data_type FROM duckdb_columns\(')})|Out-Null
                        $metadataRows+=@($metaEvents|Where-Object EventName -eq QueryFinish)[0].Properties.RowCount
                    }
                    $folded=@($starts|Where-Object {$_.Properties.Command -match $oracle.pattern})
                    if($folded.Count -ne 1){throw 'Differential oracle did not run exactly one target SQL query.'}
                    $identifier=$folded[0].Properties.Identifier
                    $slice=[pscustomobject]@{DiagnosticEvents=[pscustomobject]@{Odbc=@($events|Where-Object {$_.Properties.Identifier -eq $identifier})}}
                    if($metadataRows){
                        # The SDK reports cumulative rows within this activity.
                        # Validate catalog transfer separately, then the data delta.
                        $slice.DiagnosticEvents.Odbc=@($slice.DiagnosticEvents.Odbc|ForEach-Object {
                            $e=$_;if($e.EventName -eq 'QueryFinish'){$props=@{};foreach($p in $e.Properties.PSObject.Properties){$props[$p.Name]=$p.Value};$props.RowCount-=$metadataRows;[pscustomobject]@{EventName=$e.EventName;Properties=[pscustomobject]$props}}else{$e}
                        })
                    }
                    Assert-FoldingEvidence -Result $slice -Contract ([pscustomobject]@{name=$name;maxRows=$oracle.maxRows;sqlPatterns=$oracle.patterns}) | Out-Null
                }
                $summary.Add([pscustomobject]@{Query=$name;Status='Passed'})
                Write-Host "PASS $name"
            }
            $summary[$summary.Count-1] | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $run "$name.verdict.json")
        } catch {
            [pscustomobject]@{Query=$name;Status='Failed';Reason=$_.Exception.Message} |
                ConvertTo-Json -Depth 5 | Set-Content (Join-Path $run "$name.verdict.json")
            throw
        }
    }
    $summary | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $run 'summary.json')
    Write-Host "Passed $($files.Count) tests. Evidence: $run"
}

try {
    if (-not $IsWindows -or -not [Environment]::Is64BitProcess) { throw 'Use 64-bit PowerShell 7 on Windows.' }
    if ($Command -eq 'bootstrap') {
        if (-not (Test-Path -LiteralPath $pqtest)) {
            $downloads = Join-Path $repo '.agent/downloads'
            [void](New-Item -ItemType Directory -Path $downloads -Force)
            $archive = Join-Path $downloads "Microsoft.PowerQuery.SdkTools.$($toolchain.sdkVersion).nupkg"
            if (-not (Test-Path -LiteralPath $archive)) {
                $ProgressPreference = 'SilentlyContinue'
                Write-Host "Downloading pinned Microsoft SDK $($toolchain.sdkVersion) (~129 MiB) into .agent."
                Invoke-WebRequest "https://api.nuget.org/v3-flatcontainer/microsoft.powerquery.sdktools/$($toolchain.sdkVersion)/microsoft.powerquery.sdktools.$($toolchain.sdkVersion).nupkg" -OutFile $archive
            }
            if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $toolchain.sdkSha256) { throw 'SDK checksum mismatch; package will not be extracted.' }
            if (Test-Path -LiteralPath $sdkRoot) { throw 'Partial SDK directory exists; inspect it before retrying.' }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [IO.Compression.ZipFile]::ExtractToDirectory($archive,$sdkRoot)
        }
        Assert-Sdk
        Write-Host 'SDK ready. No administrator rights, Visual Studio, or .NET SDK required.'
    } elseif ($Command -eq 'doctor') {
        Assert-Sdk
        Get-Command git | Select-Object Name,Source | Format-List
        Invoke-PqJson -Arguments @('version') | Format-List
        $run = Join-Path $repo ('.agent/doctor/' + [guid]::NewGuid().ToString('N'))
        [void](New-Item -ItemType Directory -Path $run -Force)
        & (Join-Path $PSScriptRoot 'Seed-Fixture.ps1') -DatabasePath (Join-Path $run 'fixture.db') | Format-List
        Write-Host '64-bit ODBC, all three pagination SQL forms, fixture counts, and SDK verified.'
    } else {
        Assert-Sdk
        & (Join-Path $PSScriptRoot 'Test-Version.ps1')
        if (-not $Connector) { Build-Connector; $Connector = $defaultMez }
        else { $Connector = (Resolve-Path -LiteralPath $Connector).Path }
        switch ($Command) {
            'build' { }
            'test' { Invoke-RegressionSuite }
            'test-folding' { Invoke-RegressionSuite -Folding }
            'test-parity' {
                & (Join-Path $PSScriptRoot 'Test-ParityReference.ps1') -PqTest $pqtest -Connector $Connector -Case $Case
                Invoke-RegressionSuite -Folding -Parity
            }
            'verify' {
                if ($Parallel) {
                    if ($Case -or $IncludeKnownLimitations -or $ShardCount -ne 1) { throw 'Parallel verification requires the complete supported suite.' }
                    & (Join-Path $PSScriptRoot 'Invoke-ParallelVerification.ps1') -Connector $Connector -PqTest $pqtest
                    break
                }
                & (Join-Path $PSScriptRoot 'Test-Versioning.ps1')
                & (Join-Path $PSScriptRoot 'Test-Runner.ps1')
                Invoke-RegressionSuite
                & (Join-Path $PSScriptRoot 'Test-ParityReference.ps1') -PqTest $pqtest -Connector $Connector
                Invoke-RegressionSuite -Folding
                & (Join-Path $PSScriptRoot 'Test-NegativeControls.ps1') -Connector $Connector -PqTest $pqtest
                & (Join-Path $PSScriptRoot 'Test-NativeBoundaries.ps1') -Connector $Connector -PqTest $pqtest
            }
        }
    }
} catch {
    Write-Error -Message $_ -ErrorAction Continue
    exit 1
}

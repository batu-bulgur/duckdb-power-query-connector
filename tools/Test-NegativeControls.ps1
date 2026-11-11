param([Parameter(Mandatory)][string]$Connector, [Parameter(Mandatory)][string]$PqTest)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-Result.ps1')
$repo=Split-Path $PSScriptRoot
$run=Join-Path $repo ('.agent/negative-controls/'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $run -Force)
$fixture=& (Join-Path $PSScriptRoot 'Seed-Fixture.ps1') -DatabasePath (Join-Path $run 'fixture.db')
$credentials=Join-Path $run 'credentials'
foreach($name in @('local_index','native_filter','text_ends')) {
    $source=Join-Path $repo "test/negative/$name.query.pq"
    $query=Join-Path $run "$name.query.pq"
    (Get-Content $source -Raw).Replace('__DB_PATH__',$fixture.Database.Replace('"','""')) | Set-Content $query -Encoding utf8
    Copy-Item ([IO.Path]::ChangeExtension($source,'.pqout')) ([IO.Path]::ChangeExtension($query,'.pqout'))
    $template=& $PqTest credential-template -e $Connector -q $query -ak Anonymous
    if($LASTEXITCODE -ne 0) { throw 'Negative control credential discovery failed.' }
    $credentialRaw=$template | & $PqTest set-credential -e $Connector -q $query -cfp $credentials
    $credentialExit=$LASTEXITCODE
    if($credentialExit -ne 0 -or (($credentialRaw -join "`n")|ConvertFrom-Json).Status -ne 'Success') { throw 'Negative control credential setup failed.' }
    $diagnostics=Join-Path $run "$name-diagnostics"
    [void](New-Item -ItemType Directory -Path $diagnostics)
    $arguments=@('compare','-e',$Connector,'-q',$query,'-cfp',$credentials,'-fomof','-dfp',$diagnostics)
    # The SDK gives a generic NullReferenceException for strict EndsWith.
    # First prove correct ordinary results, then detect fallback through SQL/rows.
    if($name -ne 'text_ends') { $arguments+='-foff' }
    $raw=& $PqTest @arguments
    $nativeExit=$LASTEXITCODE
    $raw | Set-Content (Join-Path $run "$name.json")
    $result=@(($raw -join "`n")|ConvertFrom-Json)
    # These return correct data and exit zero. Only actual SQL/row evidence detects fallback.
    Assert-PqTestResult $result -ExitCode $nativeExit
    $patterns=if($name -eq 'local_index') {@('limit 3')} else {@('where','limit 3')}
    $contract=[pscustomobject]@{name=$name;sqlPatterns=$patterns;maxRows=3}
    $rejected=$false
    try { Assert-FoldingEvidence $result[0] $contract | Out-Null } catch { $rejected=$true }
    if(-not $rejected) { throw "Negative control unexpectedly folded: $name. Review and replace the control." }
    Write-Host "PASS negative control rejected $name"
}
Write-Host "Negative control evidence: $run"

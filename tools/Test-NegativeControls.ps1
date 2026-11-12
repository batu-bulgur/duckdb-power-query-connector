param([Parameter(Mandatory)][string]$Connector, [Parameter(Mandatory)][string]$PqTest)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-Result.ps1')
$repo=Split-Path $PSScriptRoot
$run=Join-Path $repo ('.agent/negative-controls/'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $run -Force)
$fixture=& (Join-Path $PSScriptRoot 'Seed-Fixture.ps1') -DatabasePath (Join-Path $run 'fixture.db')
$credentials=Join-Path $run 'credentials'
$contracts=@(Get-Content (Join-Path $repo 'test/negative/contracts.json') -Raw | ConvertFrom-Json)
foreach($name in $contracts.name) {
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
    # Ordinary evaluation also verifies the exact lone-surrogate M result.
    # Its deliberately failing SQL guard must be rejected as fallback.
    if($name -eq 'native_filter') { $arguments+='-foff' }
    $raw=& $PqTest @arguments
    $nativeExit=$LASTEXITCODE
    $raw | Set-Content (Join-Path $run "$name.json")
    $result=@(($raw -join "`n")|ConvertFrom-Json)
    # These return correct data and exit zero. Only actual SQL/row evidence detects fallback.
    Assert-PqTestResult $result -ExitCode $nativeExit
    $matching=@($contracts|Where-Object name -eq $name)
    if($matching.Count -ne 1){throw "Missing/duplicate negative contract: $name"}
    $contract=$matching[0]
    $rejected=$false
    try { Assert-FoldingEvidence $result[0] $contract | Out-Null } catch { $rejected=$true }
    if(-not $rejected) { throw "Negative control unexpectedly folded: $name. Review and replace the control." }
    Write-Host "PASS negative control rejected $name"
}
Write-Host "Negative control evidence: $run"

#requires -Version 7.2
param([Parameter(Mandatory)][string]$PqTest,[Parameter(Mandatory)][string]$Connector,[string]$Case)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot
. (Join-Path $PSScriptRoot 'Test-Result.ps1')
$run=Join-Path $repo ('.agent/parity-reference/'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory $run -Force)
$queries=@(Get-ChildItem (Join-Path $repo 'test/parity-reference') -Filter '*.query.pq' | Sort-Object Name)
if($Case){$queries=@($queries|Where-Object Name -Like "$Case.query.pq")}
if($queries.Count -eq 0){throw 'No matching pure M parity references.'}
foreach($file in $queries){
    $baseline=[IO.Path]::ChangeExtension($file.FullName,'.pqout')
    if(-not(Test-Path -LiteralPath $baseline)){throw "Missing parity reference baseline: $baseline"}
    Copy-Item -LiteralPath $file.FullName -Destination $run
    Copy-Item -LiteralPath $baseline -Destination $run
    $log=Join-Path $run ($file.BaseName+'.json')
    # PQTest compare requires an extension even for source-free expressions.
    $raw=& $PqTest compare -e $Connector -q (Join-Path $run $file.Name) -fomof
    $code=$LASTEXITCODE
    $raw | Set-Content -LiteralPath $log -Encoding utf8
    $result=($raw -join "`n") | ConvertFrom-Json
    Assert-PqTestResult -Result $result -ExitCode $code
    foreach($item in @($result)) {
        if(@($item.DiagnosticEvents.PSObject.Properties | ForEach-Object Name) -contains 'Odbc') { throw 'Pure M reference unexpectedly accessed ODBC.' }
    }
    Write-Host "PASS pure M $($file.BaseName)"
}
Write-Host "Passed $($queries.Count) pure M parity references. Evidence: $run"

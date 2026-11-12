#requires -Version 7.2
param([Parameter(Mandatory)][string]$PqTest,[Parameter(Mandatory)][string]$Connector)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot
$run=Join-Path $repo ('.agent/native-boundaries/'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory $run -Force)
foreach($case in @(@('round_native_overflow','Value was either too large or too small for a Decimal.'),@('middle_native_overflow',"Index and length must refer to a location within the string.`r`nParameter name: length"),@('date_zone_native_min',"The UTC time represented when the offset is applied must be between year 0 and 10,000.`r`nParameter name: offset"),@('date_zone_native_max',"The UTC time represented when the offset is applied must be between year 0 and 10,000.`r`nParameter name: offset"))){
    $query=Join-Path $repo ('test/boundaries/'+$case[0]+'.pq')
    $raw=& $PqTest run-test -e $Connector -q $query
    $exitCode=$LASTEXITCODE
    $raw|Set-Content (Join-Path $run ($case[0]+'.json')) -Encoding utf8
    $result=@(($raw -join [Environment]::NewLine)|ConvertFrom-Json)
    if($exitCode -ne 0 -or $result.Count -ne 1 -or $result[0].Status -ne 'Failed' -or $result[0].Error.InnerException.Message -ne $case[1]){
        throw "The documented native failure changed: $($case[0]). Reassess its SQL guard and excluded matrix cases."
    }
    if(@($result[0].DiagnosticEvents.PSObject.Properties.Name) -contains 'Odbc'){throw 'Native failure reproducer unexpectedly accessed ODBC.'}
    Write-Host "PASS reproduced uncatchable native failure $($case[0])."
}
Write-Host "Native failure evidence: $run"

# Execute the real consumer finally blocks; no Lab, SQL or provider is contacted.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$passed=0
foreach($name in @('Invoke-AnalyzeAdapterQuickScenario.ps1','Invoke-Ops005LinkedServerScenario.ps1','Start-AnalyzeExample.ps1')){
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root ('TestLab/'+$name)),[ref]$null,[ref]$null)
    $blocks=@($ast.EndBlock.Statements|Where-Object {$_ -is [Management.Automation.Language.TryStatementAst] -and $_.Finally.Extent.Text -match 'Remove-SqlServerLab'})
    if($blocks.Count -ne 1){throw "Cleanup boundary changed: $name"}
    $text=$blocks[0].Finally.Extent.Text;$body=[scriptblock]::Create($text.Substring(1,$text.Length-2))
    foreach($status in @('REMOVED','RECOVERY_REQUIRED','NOT_FOUND','throws','keep','primary-and-cleanup')){
        $lab=[pscustomobject]@{RunId='synthetic-run'};$StateRoot='synthetic-state';$adapterPath='synthetic-adapter';$SaPassword=[Security.SecureString]::new()
        $failed=$status -eq 'keep';$KeepOnFailure=$status -eq 'keep';$worker=$null;$scripts=$null;$Mode='Verify'
        $originalDockerConfig=$env:DOCKER_CONFIG;$originalDockerHost=$env:DOCKER_HOST;$originalTemp=$env:TEMP;$originalTmp=$env:TMP
        $scenarioFailure=if($status -eq 'primary-and-cleanup'){[InvalidOperationException]::new('synthetic primary failure')}else{$null}
        $script:removals=0
        function Install-SqlServerLabAdapter {param($Path,$RunId,$InstanceId,$SaPassword,$Entrypoint,$StateRoot)[pscustomobject]@{Success=$true;Status='ADAPTER_APPLIED'}}
        function Remove-SqlServerLab {param($RunId,$StateRoot,[switch]$Force,[switch]$Confirm)
            $script:removals++
            if($status -in @('throws','primary-and-cleanup')){throw 'synthetic provider unavailable'}
            [pscustomobject]@{Status=$status}
        }
        if($name -eq 'Start-AnalyzeExample.ps1'){$env:DOCKER_CONFIG='synthetic-changed';$env:DOCKER_HOST='synthetic-changed';$env:TEMP='synthetic-changed';$env:TMP='synthetic-changed'}
        $blocked=$false;try{. $body}catch{$blocked=$true;if($scenarioFailure -and ($_.Exception.Message -cne 'synthetic primary failure' -or -not $_.Exception.Data.Contains('InfrastructureCleanupFailure'))){throw 'Primary or cleanup failure lost'}}
        if($blocked -ne ($status -in @('RECOVERY_REQUIRED','NOT_FOUND','throws','primary-and-cleanup'))){throw "Cleanup status was hidden: $name/$status"}
        if($script:removals -ne $(if($status -eq 'keep'){0}else{1})){throw "Wrong removal count: $name/$status"}
        if($name -eq 'Start-AnalyzeExample.ps1' -and ($env:TEMP -ne $originalTemp -or $env:TMP -ne $originalTmp -or $env:DOCKER_HOST -ne $originalDockerHost -or $env:DOCKER_CONFIG -ne $originalDockerConfig)){throw 'Environment not restored after cleanup failure'}
        $passed++
    }
}
Write-Output "ANALYZE LAB CLEANUP STATUS: PASS ($passed actual-finally scenarios)"

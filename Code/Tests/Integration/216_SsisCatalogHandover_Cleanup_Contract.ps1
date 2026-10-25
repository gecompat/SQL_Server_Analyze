# Führt ausschließlich den echten Finally-AST mit isolierten I/O-Blättern aus.
# Unbestätigte Mutation und geschlossener Kanal dürfen keinen Cleanup-PASS liefern.
$ErrorActionPreference='Stop'
$path=Join-Path $PSScriptRoot '216_SsisCatalogHandover_Native_Contract.ps1'
$ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$null,[ref]$null)
$blocks=@($ast.FindAll({param($node)$node -is [Management.Automation.Language.TryStatementAst] -and $null -ne $node.Finally -and $node.Finally.Extent.Text.Contains('$cleanupErrors=[Collections.Generic.List[string]]::new()')},$true))
if($blocks.Count -ne 1){throw 'NATIVE_CLEANUP_CHARACTERIZATION_SCOPE_CHANGED'}
$body=$blocks[0].Finally.Extent.Text;$cleanup=[scriptblock]::Create($body.Substring(1,$body.Length-2))
$cases=0
function Save-Record {}
function Windows-Query {throw 'CHARACTERIZATION_EXTERNAL_SOURCE_FORBIDDEN'}
function Query {param($Sql,$Parameters);$state.Queries++;$d=[Data.DataSet]::new();$t=[Data.DataTable]::new();[void]$t.Columns.Add('Id',[int]);[void]$t.Rows.Add([DBNull]::Value);[void]$d.Tables.Add($t);return ,$d}
foreach($scenario in @('FOLDER_RESPONSE_UNCERTAIN','DATABASE_CHANNEL_CLOSED','DATABASE_REMOVED')) {
 $record=[ordered]@{Phase='FAILED_TEST_SCOPE';FolderAttempted=($scenario -ceq 'FOLDER_RESPONSE_UNCERTAIN');FolderId=0L;ProjectAttempted=$false;ProjectId=0L;DatabaseAttempted=($scenario -cne 'FOLDER_RESPONSE_UNCERTAIN');Cleanup='PENDING'}
 $databaseCreated=$scenario -cne 'FOLDER_RESPONSE_UNCERTAIN';$database='SyntheticCharacterization';$state=[pscustomobject]@{Queries=0;Disposed=$false;Cleared=$false}
 $connection=[pscustomobject]@{State=$(if($scenario -ceq 'DATABASE_CHANNEL_CLOSED'){'Closed'}else{'Open'})}
 $connection|Add-Member ScriptMethod Dispose {$state.Disposed=$true};$connection|Add-Member ScriptMethod ChangeDatabase {param($Name)}
 $builder=[pscustomobject]@{};$builder|Add-Member ScriptMethod Clear {$state.Cleared=$true}
 $failed=$false
 try {& $cleanup} catch {if($_.Exception.Message -cne 'SSIS_NATIVE_CLEANUP_UNCONFIRMED_ENTIRE_OWN_RUN_RECOVERY_REQUIRED'){throw};$failed=$true}
 if($scenario -ceq 'DATABASE_REMOVED') {if($failed -or $record.Cleanup -cne 'CONFIRMED_OWN_OBJECTS_REMOVED' -or $state.Queries -ne 3){throw 'NATIVE_CLEANUP_CONFIRMED_ORACLE_FAILED'}}
 else {if(-not $failed -or $record.Cleanup -cne 'UNCONFIRMED_RECOVERY_REQUIRED' -or $state.Queries -ne 0){throw 'NATIVE_CLEANUP_UNCERTAINTY_ORACLE_FAILED'}}
 if(-not $state.Disposed -or -not $state.Cleared){throw 'NATIVE_CLEANUP_DISPOSAL_FAILED'}
 $cases++
}
Write-Output "SSIS_NATIVE_CLEANUP_CHARACTERIZATION_PASS cases=$cases; actual Finally AST; external I/O mocked, no native qualification claim."

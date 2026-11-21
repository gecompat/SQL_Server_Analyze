Set-StrictMode -Version Latest
# Interne Registrierung für den qualifizierten lokalen Zulieferworkflow.
# ALTER-Autorität ist die explizite Vertrauenswurzel; diese Funktion ersetzt
# weder die unabhängige Buildfreigabe noch einen qualifizierten Quellenleser.
function Register-SsisHandover {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory)][string]$ModelJson,
        [Parameter(Mandatory)][byte[]]$PackageBytes,
        [string]$ExecutionSnapshotJson,
        [ValidateRange(1,24)][int]$ValidHours=1,
        [ValidateRange(1,90)][int]$CommandTimeoutSeconds=90
    )
    $check=$Connection.CreateCommand();$check.CommandText='SELECT @@TRANCOUNT;';$check.CommandTimeout=10
    try {if($check.ExecuteScalar() -ne 0){throw 'SSIS_HANDOVER_CALLER_TRANSACTION_NOT_ALLOWED'}} finally {$check.Dispose()}
    $modelId=[guid]::NewGuid();$runtimeId=if($ExecutionSnapshotJson){[guid]::NewGuid()}else{$null}
    $command=$Connection.CreateCommand();$command.CommandTimeout=$CommandTimeoutSeconds
    $command.CommandText=@'
EXEC [monitor].[InternalManageSsisHandoverReceipt]
     @Action='REGISTER_MODEL',@HandoverId=@ModelId,@RuntimeHandoverId=@RuntimeId,
     @ModelJson=@Model,@PackageBytes=@Bytes,@CaptureJson=@Snapshot,@ValidHours=@Hours;
'@
    [void]$command.Parameters.Add('@Model',[Data.SqlDbType]::NVarChar,-1);$command.Parameters['@Model'].Value=$ModelJson
    [void]$command.Parameters.Add('@Bytes',[Data.SqlDbType]::VarBinary,-1);$command.Parameters['@Bytes'].Value=[byte[]]$PackageBytes
    [void]$command.Parameters.Add('@Snapshot',[Data.SqlDbType]::NVarChar,-1);$command.Parameters['@Snapshot'].Value=if($ExecutionSnapshotJson){$ExecutionSnapshotJson}else{[DBNull]::Value}
    [void]$command.Parameters.Add('@ModelId',[Data.SqlDbType]::UniqueIdentifier);$command.Parameters['@ModelId'].Value=$modelId
    [void]$command.Parameters.Add('@RuntimeId',[Data.SqlDbType]::UniqueIdentifier);$command.Parameters['@RuntimeId'].Value=if($null -ne $runtimeId){$runtimeId}else{[DBNull]::Value}
    [void]$command.Parameters.Add('@Hours',[Data.SqlDbType]::Int);$command.Parameters['@Hours'].Value=$ValidHours
    # Attention/Clienttimeout kann den T-SQL-CATCH umgehen. Die nachweislich
    # eigene Transaktion wird dann zurückgerollt; eine unklare Verbindung
    # darf nicht mit gehaltenen Metadatensperren weiterverwendet werden.
    try {[void]$command.ExecuteNonQuery()}
    catch {
        if($Connection.State -eq 'Open') {
            $rollback=$Connection.CreateCommand();$rollback.CommandText='IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;';$rollback.CommandTimeout=10
            try {[void]$rollback.ExecuteNonQuery()} catch {$Connection.Close();throw 'SSIS_HANDOVER_ROLLBACK_UNCONFIRMED'} finally {$rollback.Dispose()}
        }
        throw
    } finally {$command.Dispose()}
    [pscustomobject]@{LocalHandoverId=$modelId;RuntimeHandoverId=$runtimeId}
}
Export-ModuleMember -Function Register-SsisHandover

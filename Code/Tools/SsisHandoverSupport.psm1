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
IF @@TRANCOUNT<>0 THROW 57400,N'SSIS_HANDOVER_CALLER_TRANSACTION_NOT_ALLOWED',1;
IF HAS_PERMS_BY_NAME(N'monitor.USP_SsisPackageModelAnalysis',N'OBJECT',N'ALTER')<>1 THROW 57400,N'SSIS_HANDOVER_ALTER_AUTHORITY_REQUIRED',1;
DECLARE @Status varchar(40);
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@PackageBytes=@Bytes,@ResultSetArt='NONE',@StatusCodeOut=@Status OUTPUT;
IF @Status<>'AVAILABLE_LIMITED' THROW 57400,N'SSIS_HANDOVER_MODEL_REJECTED',1;
IF @Snapshot IS NOT NULL AND (ISJSON(@Snapshot)<>1 OR DATALENGTH(@Snapshot)>16777216) THROW 57400,N'SSIS_HANDOVER_SNAPSHOT_REJECTED',1;
DECLARE @Issued datetime2(3)=SYSUTCDATETIME(),@Receipt nvarchar(3000),@RuntimeReceipt nvarchar(3000);
SET @Receipt=(SELECT 'ssis-local-handover' AS [contract],'1.0.0' AS [version],'QUALIFIED_HOST_SNAPSHOT' AS [method],
 CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Model)),2) AS [modelSha256],JSON_VALUE(@Model,'$.source.packageSha256') AS [packageSha256],DATALENGTH(@Bytes) AS [byteLength],
 JSON_VALUE(@Model,'$.producer.buildSha256') AS [buildSha256],JSON_VALUE(@Model,'$.producer.sourceCommit') AS [sourceCommit],
 CONVERT(varchar(24),@Issued,127)+'Z' AS [issuedUtc],CONVERT(varchar(24),DATEADD(hour,@Hours,@Issued),127)+'Z' AS [expiresUtc] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
IF @Snapshot IS NOT NULL SET @RuntimeReceipt=(SELECT 'ssis-local-runtime-handover' AS [contract],'1.0.0' AS [version],
 CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Snapshot)),2) AS [snapshotSha256],
 CONVERT(varchar(24),@Issued,127)+'Z' AS [issuedUtc],CONVERT(varchar(24),DATEADD(hour,@Hours,@Issued),127)+'Z' AS [expiresUtc] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
BEGIN TRY
 BEGIN TRANSACTION;
 EXEC [sys].[sp_addextendedproperty] @name=@ModelName,@value=@Receipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
 IF @Snapshot IS NOT NULL EXEC [sys].[sp_addextendedproperty] @name=@RuntimeName,@value=@RuntimeReceipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
'@
    [void]$command.Parameters.Add('@Model',[Data.SqlDbType]::NVarChar,-1);$command.Parameters['@Model'].Value=$ModelJson
    [void]$command.Parameters.Add('@Bytes',[Data.SqlDbType]::VarBinary,-1);$command.Parameters['@Bytes'].Value=[byte[]]$PackageBytes
    [void]$command.Parameters.Add('@Snapshot',[Data.SqlDbType]::NVarChar,-1);$command.Parameters['@Snapshot'].Value=if($ExecutionSnapshotJson){$ExecutionSnapshotJson}else{[DBNull]::Value}
    [void]$command.Parameters.Add('@ModelName',[Data.SqlDbType]::NVarChar,128);$command.Parameters['@ModelName'].Value='SSIS_HANDOVER_'+$modelId.ToString('D').ToLowerInvariant()
    [void]$command.Parameters.Add('@RuntimeName',[Data.SqlDbType]::NVarChar,128);$command.Parameters['@RuntimeName'].Value=if($null -ne $runtimeId){'SSIS_RUNTIME_'+$runtimeId.ToString('D').ToLowerInvariant()}else{[DBNull]::Value}
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

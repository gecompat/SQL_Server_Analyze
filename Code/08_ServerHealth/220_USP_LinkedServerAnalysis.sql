USE [DeineDatenbank];
GO

/* OPS-005: local inventory by default; connectivity is explicit double opt-in. */
CREATE OR ALTER PROCEDURE [monitor].[USP_LinkedServerAnalysis]
      @ConnectivityTestEnabled bit            = 0
    , @HighImpactConfirmed     bit            = 0
    , @MaxZeilen               int            = 2000
    , @ResultSetArt            varchar(16)    = 'CONSOLE'
    , @ResultTablesJson        nvarchar(max)  = NULL
    , @JsonErzeugen            bit            = 0
    , @Json                    nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen          bit            = 1
    , @Hilfe                   bit            = 0
    , @StatusCodeOut           varchar(40)    = NULL OUTPUT
    , @IsPartialOut            bit            = NULL OUTPUT
    , @ErrorNumberOut          int            = NULL OUTPUT
    , @ErrorMessageOut         nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET @Json=NULL;
    DECLARE @Status varchar(40)='AVAILABLE',@Partial bit=0,@Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL;
    IF @Hilfe=1 BEGIN PRINT N'monitor.USP_LinkedServerAnalysis'; PRINT N'Default ist lokales Inventar. Remote-Test nur mit @ConnectivityTestEnabled=1 und @HighImpactConfirmed=1.'; RETURN; END;
    DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @RestoreLockTimeoutSql nvarchar(100);
    SET LOCK_TIMEOUT 0;
    DECLARE @TableResultRequested bit=CASE WHEN @Mode='TABLE' THEN 1 ELSE 0 END,@TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 BEGIN EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'linkedServers',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1; SET @Mode='NONE'; END;
    CREATE TABLE [#LinkedServerAnalysis_Linked]
    (
      [ServerName] sysname NOT NULL,[Product] nvarchar(128) NULL,[Provider] nvarchar(128) NULL,
      [IsDataAccessEnabled] bit NULL,[IsRpcOutEnabled] bit NULL,[IsCollationCompatible] bit NULL,
      [ConnectivityStatus] varchar(40) NOT NULL,[StatusCode] varchar(40) NOT NULL,[EvidenceLimit] nvarchar(1000) NOT NULL
    );
    IF @MaxZeilen<0 OR @Mode NOT IN('CONSOLE','RAW','NONE') OR @ConnectivityTestEnabled IS NULL OR @HighImpactConfirmed IS NULL
      SELECT @Status='INVALID_PARAMETER',@Partial=1,@ErrorMessage=N'Ungültiger Parameter.';
    IF @Status='AVAILABLE'
    BEGIN
      INSERT [#LinkedServerAnalysis_Linked]
      SELECT [name],[product],[provider],[is_data_access_enabled],[is_rpc_out_enabled],[is_collation_compatible],
             CASE WHEN @ConnectivityTestEnabled=0 THEN 'NOT_EXECUTED' WHEN @HighImpactConfirmed=0 THEN 'AUTHORIZATION_REQUIRED' ELSE 'PENDING' END,
             'AVAILABLE',N'Endpunkt und Datenquelle werden nicht ausgegeben; Erreichbarkeit ist ohne opt-in unbekannt.'
      FROM [sys].[servers] WITH (NOLOCK) WHERE [is_linked]=1;
      IF @ConnectivityTestEnabled=1 AND @HighImpactConfirmed=0 SELECT @Status='AUTHORIZATION_REQUIRED',@Partial=1,@ErrorMessage=N'Remotezugriff benötigt @HighImpactConfirmed=1.';
      IF @ConnectivityTestEnabled=1 AND @HighImpactConfirmed=1
      BEGIN
        DECLARE @Server sysname;
        DECLARE [s] CURSOR LOCAL FAST_FORWARD FOR SELECT [ServerName] FROM [#LinkedServerAnalysis_Linked];
        OPEN [s]; FETCH NEXT FROM [s] INTO @Server;
        WHILE @@FETCH_STATUS=0 BEGIN
          BEGIN TRY EXEC [master].[dbo].[sp_testlinkedserver] @servername=@Server; UPDATE [#LinkedServerAnalysis_Linked] SET [ConnectivityStatus]='SUCCEEDED' WHERE [ServerName]=@Server; END TRY
          BEGIN CATCH UPDATE [#LinkedServerAnalysis_Linked] SET [ConnectivityStatus]='FAILED',[StatusCode]='SOURCE_UNAVAILABLE',[EvidenceLimit]=CONCAT(N'Remote-Testfehler ',ERROR_NUMBER(),N': ',LEFT(ERROR_MESSAGE(),800)) WHERE [ServerName]=@Server; SET @Partial=1; END CATCH;
          FETCH NEXT FROM [s] INTO @Server;
        END; CLOSE [s]; DEALLOCATE [s];
      END;
      IF NOT EXISTS(SELECT 1 FROM [#LinkedServerAnalysis_Linked]) SET @Status='AVAILABLE_EMPTY'; ELSE IF @Partial=1 AND @Status='AVAILABLE' SET @Status='AVAILABLE_LIMITED';
    END;
    IF @JsonErzeugen=1 SELECT @Json=(SELECT TOP(CASE WHEN @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END)* FROM [#LinkedServerAnalysis_Linked] ORDER BY [ServerName] FOR JSON PATH);
    IF @Mode IN('CONSOLE','RAW') BEGIN SELECT @Status [StatusCode],@Partial [IsPartial],COUNT_BIG(*) [LinkedServerCount],@ErrorMessage [ErrorMessage] FROM [#LinkedServerAnalysis_Linked]; SELECT TOP(CASE WHEN @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END)* FROM [#LinkedServerAnalysis_Linked] ORDER BY [ServerName]; SELECT [wait_type],[waiting_tasks_count],[wait_time_ms] FROM [sys].[dm_os_wait_stats] WITH (NOLOCK) WHERE [wait_type] LIKE 'OLEDB%' OR [wait_type] LIKE 'REMOTE%' ORDER BY [wait_time_ms] DESC; END;
    IF @PrintMeldungen=1 AND @Mode='NONE' PRINT CONCAT(N'Status: ',@Status);
    IF @TableResultRequested=1 EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#LinkedServerAnalysis_Linked',@TargetTable=@TableTarget,@ThrowOnError=1;
    SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
    SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
END;
GO

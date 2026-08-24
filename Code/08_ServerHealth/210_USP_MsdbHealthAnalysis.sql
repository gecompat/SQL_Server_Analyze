USE [DeineDatenbank];
GO

/* OPS-008: bounded msdb history and size inventory; never deletes history. */
CREATE OR ALTER PROCEDURE [monitor].[USP_MsdbHealthAnalysis]
      @MaxZeilen       int            = 2000
    , @ResultSetArt    varchar(16)    = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen    bit            = 0
    , @Json            nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen  bit            = 1
    , @Hilfe           bit            = 0
    , @StatusCodeOut   varchar(40)    = NULL OUTPUT
    , @IsPartialOut    bit            = NULL OUTPUT
    , @ErrorNumberOut  int            = NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET @Json=NULL;
    DECLARE @Status varchar(40)='AVAILABLE',@Partial bit=0,@Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL;
    IF @Hilfe=1 BEGIN PRINT N'monitor.USP_MsdbHealthAnalysis'; PRINT N'Inventarisiert msdb-Größe und sichtbare Historien; führt keine Bereinigung aus.'; RETURN; END;
    DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @RestoreLockTimeoutSql nvarchar(100);
    SET LOCK_TIMEOUT 0;
    DECLARE @TableResultRequested bit=CASE WHEN @Mode='TABLE' THEN 1 ELSE 0 END,@TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 BEGIN EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'msdbHealth',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1; SET @Mode='NONE'; END;
    CREATE TABLE [#MsdbHealthAnalysis_Health]
    (
          [Area] varchar(40) NOT NULL,[SourceObject] nvarchar(256) NOT NULL
        , [RowCount] bigint NULL,[OldestUtc] datetime2(3) NULL,[NewestUtc] datetime2(3) NULL
        , [SizeMb] decimal(19,2) NULL,[StatusCode] varchar(40) NOT NULL
        , [EvidenceLimit] nvarchar(1000) NOT NULL
    );
    IF @MaxZeilen<0 OR @Mode NOT IN('CONSOLE','RAW','NONE') SELECT @Status='INVALID_PARAMETER',@Partial=1,@ErrorMessage=N'Ungültiger Parameter.';
    IF @Status='AVAILABLE' AND NOT EXISTS (SELECT 1 FROM [sys].[databases] WITH (NOLOCK) WHERE [database_id]=4)
        SELECT @Status='UNSUPPORTED',@Partial=1,@ErrorMessage=N'msdb ist nicht verfügbar.';
    IF @Status='AVAILABLE'
    BEGIN
        INSERT [#MsdbHealthAnalysis_Health]
        SELECT 'DATABASE_SIZE',N'master.sys.master_files',NULL,NULL,NULL,
               CONVERT(decimal(19,2),SUM(CONVERT(bigint,[size]))*8.0/1024.0),'AVAILABLE',
               N'Aktuelle Dateigröße; kein Wachstums- oder freier Speicherplatznachweis.'
        FROM [sys].[master_files] WITH (NOLOCK) WHERE [database_id]=4;
        DECLARE @Defs TABLE([Area] varchar(40),[ObjectName] sysname,[DateColumn] sysname NULL);
        INSERT @Defs VALUES
          ('BACKUP_HISTORY','backupset','backup_finish_date'),('RESTORE_HISTORY','restorehistory','restore_date'),
          ('AGENT_HISTORY','sysjobhistory',NULL),('DATABASE_MAIL','sysmail_allitems','send_request_date'),
          ('MAINTENANCE_PLAN','sysmaintplan_log','start_time');
        DECLARE @Area varchar(40),@Obj sysname,@Date sysname,@Sql nvarchar(max),@Source nvarchar(256);
        DECLARE [d] CURSOR LOCAL FAST_FORWARD FOR SELECT [Area],[ObjectName],[DateColumn] FROM @Defs;
        OPEN [d]; FETCH NEXT FROM [d] INTO @Area,@Obj,@Date;
        WHILE @@FETCH_STATUS=0
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM [msdb].[sys].[objects] AS [o] WITH (NOLOCK)
                INNER JOIN [msdb].[sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
                WHERE [s].[name]=N'dbo' AND [o].[name]=@Obj AND [o].[type]=N'U'
            )
                INSERT [#MsdbHealthAnalysis_Health] VALUES(@Area,N'msdb.dbo.'+@Obj,NULL,NULL,NULL,NULL,'UNSUPPORTED',N'Quelle ist auf dieser Instanz nicht vorhanden.');
            ELSE BEGIN TRY
                SET @Source=N'msdb.dbo.'+@Obj;
                SET @Sql=N'INSERT [#MsdbHealthAnalysis_Health] SELECT @Area,@Source,COUNT_BIG(*),' +
                    CASE WHEN @Date IS NULL THEN N'NULL,NULL' ELSE N'MIN('+QUOTENAME(@Date)+N'),MAX('+QUOTENAME(@Date)+N')' END +
                    N',NULL,''AVAILABLE'',N''Retentionbewertung ist kontextabhängig; es wird nichts gelöscht.'' FROM [msdb].[dbo].'+QUOTENAME(@Obj)+N' WITH (NOLOCK);';
                EXEC [sys].[sp_executesql] @Sql,N'@Area varchar(40),@Source nvarchar(256)',@Area,@Source;
            END TRY BEGIN CATCH
                INSERT [#MsdbHealthAnalysis_Health] VALUES(@Area,N'msdb.dbo.'+@Obj,NULL,NULL,NULL,NULL,'SOURCE_UNAVAILABLE',CONCAT(N'Fehler ',ERROR_NUMBER(),N': ',LEFT(ERROR_MESSAGE(),800)));
                SET @Partial=1;
            END CATCH;
            FETCH NEXT FROM [d] INTO @Area,@Obj,@Date;
        END; CLOSE [d]; DEALLOCATE [d];
        IF @Partial=1 SET @Status='AVAILABLE_LIMITED';
    END;
    IF @JsonErzeugen=1 SELECT @Json=(SELECT TOP(CASE WHEN @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END)* FROM [#MsdbHealthAnalysis_Health] ORDER BY [Area] FOR JSON PATH);
    IF @Mode IN('CONSOLE','RAW') BEGIN SELECT @Status [StatusCode],@Partial [IsPartial],COUNT_BIG(*) [EvidenceRows],@ErrorMessage [ErrorMessage] FROM [#MsdbHealthAnalysis_Health]; SELECT TOP(CASE WHEN @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END)* FROM [#MsdbHealthAnalysis_Health] ORDER BY [Area]; END;
    IF @PrintMeldungen=1 AND @Mode='NONE' PRINT CONCAT(N'Status: ',@Status);
    IF @TableResultRequested=1 EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#MsdbHealthAnalysis_Health',@TargetTable=@TableTarget,@ThrowOnError=1;
    SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
    SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
END;
GO

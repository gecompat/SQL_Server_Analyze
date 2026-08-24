USE [DeineDatenbank];
GO

/* OPS-006: read-only portability evidence; no automatic DDL. */
CREATE OR ALTER PROCEDURE [monitor].[USP_DatabasePortabilityAnalysis]
      @DatabaseName    sysname        = NULL
    , @MaxZeilen       int            = 2000
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
    SET NOCOUNT ON;
    SET @Json = NULL;
    DECLARE @Status varchar(40) = 'AVAILABLE', @Partial bit = 0;
    DECLARE @ErrorNumber int = NULL, @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Mode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_DatabasePortabilityAnalysis';
        PRINT N'Inventarisiert persistierte Edition-Features und uncontained dependencies sichtbarer Datenbanken.';
        PRINT N'Es wird keine DDL erzeugt oder ausgeführt. @ResultSetArt=CONSOLE|RAW|NONE.';
        RETURN;
    END;
    DECLARE @PreviousLockTimeout int=@@LOCK_TIMEOUT,@RestoreLockTimeoutSql nvarchar(100); SET LOCK_TIMEOUT 0;
    DECLARE @TableResultRequested bit=CASE WHEN @Mode='TABLE' THEN 1 ELSE 0 END,@TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 BEGIN EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'portability',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1; SET @Mode='NONE'; END;

    CREATE TABLE [#DatabasePortabilityAnalysis_Portability]
    (
          [DatabaseName] sysname NOT NULL
        , [EvidenceType] varchar(40) NOT NULL
        , [FeatureName] nvarchar(256) NULL
        , [FeatureType] nvarchar(256) NULL
        , [StatementType] nvarchar(256) NULL
        , [SourceObject] nvarchar(256) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [EvidenceLimit] nvarchar(1000) NOT NULL
    );

    IF @MaxZeilen < 0 OR @Mode NOT IN ('CONSOLE','RAW','NONE')
        SELECT @Status='INVALID_PARAMETER', @Partial=1,
               @ErrorMessage=N'Ungültiger Zeilen- oder Ausgabeparameter.';

    IF @Status = 'AVAILABLE'
    BEGIN
        DECLARE @Db sysname, @Sql nvarchar(max);
        DECLARE [dbs] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [name]
            FROM [sys].[databases] WITH (NOLOCK)
            WHERE [state] = 0 AND [database_id] > 4
              AND HAS_DBACCESS([name]) = 1
              AND (@DatabaseName IS NULL OR [name] = @DatabaseName)
            ORDER BY [name];
        OPEN [dbs]; FETCH NEXT FROM [dbs] INTO @Db;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                SET @Sql = N'
INSERT [#DatabasePortabilityAnalysis_Portability]
SELECT @Db, ''PERSISTED_SKU_FEATURE'', [feature_name], NULL, NULL,
       N''sys.dm_db_persisted_sku_features'', ''AVAILABLE'',
       N''Persistiertes Feature ist ein Migrationshinweis; Zielunterstützung separat prüfen.''
FROM ' + QUOTENAME(@Db) + N'.[sys].[dm_db_persisted_sku_features];

INSERT [#DatabasePortabilityAnalysis_Portability]
SELECT @Db, ''UNCONTAINED_ENTITY'', [feature_name], [feature_type_name], [statement_type],
       N''sys.dm_db_uncontained_entities'', ''AVAILABLE'',
       N''Metadatenfund ohne automatische Umschreibung oder DDL-Anweisung.''
FROM ' + QUOTENAME(@Db) + N'.[sys].[dm_db_uncontained_entities];';
                EXEC [sys].[sp_executesql] @Sql, N'@Db sysname', @Db=@Db;
            END TRY
            BEGIN CATCH
                INSERT [#DatabasePortabilityAnalysis_Portability]
                VALUES (@Db,'SOURCE_STATUS',NULL,NULL,NULL,N'sys.dm_db_*','SOURCE_UNAVAILABLE',
                        CONCAT(N'Fehler ',ERROR_NUMBER(),N': ',LEFT(ERROR_MESSAGE(),800)));
                SET @Partial=1;
            END CATCH;
            FETCH NEXT FROM [dbs] INTO @Db;
        END;
        CLOSE [dbs]; DEALLOCATE [dbs];
        IF @DatabaseName IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [sys].[databases] WITH (NOLOCK) WHERE [name]=@DatabaseName)
            SELECT @Status='NOT_FOUND', @Partial=1, @ErrorMessage=N'Datenbank nicht gefunden.';
        ELSE IF NOT EXISTS(SELECT 1 FROM [#DatabasePortabilityAnalysis_Portability])
            SET @Status='AVAILABLE_EMPTY';
        ELSE IF @Partial=1 SET @Status='AVAILABLE_LIMITED';
    END;

    IF @JsonErzeugen=1
        SELECT @Json=(SELECT TOP (CASE WHEN @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END) *
                      FROM [#DatabasePortabilityAnalysis_Portability] ORDER BY [DatabaseName],[EvidenceType],[FeatureName] FOR JSON PATH);
    IF @Mode IN('CONSOLE','RAW')
    BEGIN
        SELECT @Status AS [StatusCode],@Partial AS [IsPartial],COUNT_BIG(*) AS [EvidenceRows],
               @ErrorMessage AS [ErrorMessage] FROM [#DatabasePortabilityAnalysis_Portability];
        SELECT TOP (CASE WHEN @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END) *
        FROM [#DatabasePortabilityAnalysis_Portability] ORDER BY [DatabaseName],[EvidenceType],[FeatureName];
    END;
    IF @PrintMeldungen=1 AND @Mode='NONE' PRINT CONCAT(N'Status: ',@Status);
    IF @TableResultRequested=1 EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#DatabasePortabilityAnalysis_Portability',@TargetTable=@TableTarget,@ThrowOnError=1;
    SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';'; EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql; SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
END;
GO

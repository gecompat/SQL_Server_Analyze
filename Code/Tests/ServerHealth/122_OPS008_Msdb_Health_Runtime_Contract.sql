USE [DeineDatenbank];
GO

/* Die Fixture prüft Quellenstatus, Begrenzung und eingeschränkten Zugriff und entfernt die einzige eigene, kurzzeitig angelegte PBM-Kategorie wieder. */
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
    THROW 54974,N'OPS-008 PBM category fixture requires an isolated remote CI sysadmin caller without an ambient transaction.',1;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;
DECLARE @Status varchar(40) = NULL;
DECLARE @Partial bit = NULL;

EXEC [monitor].[USP_MsdbHealthAnalysis]
      @MaxZeilen = 1
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0
    , @StatusCodeOut = @Status OUTPUT
    , @IsPartialOut = @Partial OUTPUT;

IF COALESCE(ISJSON(@Json), 0) <> 1
   OR @Status NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) > 1
    THROW 54870, N'Der begrenzte msdb-Health-Vertrag ist verletzt.', 1;

SET @Json = NULL;
EXEC [monitor].[USP_MsdbHealthAnalysis]
      @MaxZeilen = 100
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF NOT EXISTS
(
    SELECT 1 FROM OPENJSON(@Json)
    WITH ([Area] varchar(40) '$.Area', [StatusCode] varchar(40) '$.StatusCode', [EvidenceLimit] nvarchar(1000) '$.EvidenceLimit') AS [j]
    WHERE [j].[Area] = 'DATABASE_SIZE'
      AND [j].[StatusCode] IN ('AVAILABLE', 'SOURCE_UNAVAILABLE')
      AND NULLIF([j].[EvidenceLimit], N'') IS NOT NULL
)
    THROW 54871, N'Die msdb-Größen- oder Quellenstatusevidenz fehlt.', 1;

IF EXISTS
(
    SELECT [ExpectedArea]
    FROM (VALUES
        ('BACKUP_HISTORY'),
        ('RESTORE_HISTORY'),
        ('AGENT_HISTORY'),
        ('DATABASE_MAIL'),
        ('MAINTENANCE_PLAN')
    ) AS [e]([ExpectedArea])
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM OPENJSON(@Json)
        WITH
        (
              [Area] varchar(40) '$.Area'
            , [RowCount] bigint '$.RowCount'
            , [StatusCode] varchar(40) '$.StatusCode'
        ) AS [j]
        WHERE [j].[Area] = [e].[ExpectedArea]
    )
)
    THROW 54873, N'Eine erwartete msdb-Historienquelle fehlt im Resultset.', 1;

IF EXISTS
(
    SELECT 1
    FROM OPENJSON(@Json)
    WITH
    (
          [Area] varchar(40) '$.Area'
        , [RowCount] bigint '$.RowCount'
        , [StatusCode] varchar(40) '$.StatusCode'
    ) AS [j]
    WHERE [j].[Area] IN
          ('BACKUP_HISTORY','RESTORE_HISTORY','AGENT_HISTORY','DATABASE_MAIL','MAINTENANCE_PLAN')
      AND
      (
          [j].[StatusCode] NOT IN ('AVAILABLE','UNSUPPORTED','SOURCE_UNAVAILABLE')
          OR ([j].[StatusCode] = 'AVAILABLE' AND [j].[RowCount] IS NULL)
          OR ([j].[StatusCode] = 'UNSUPPORTED' AND [j].[RowCount] IS NOT NULL)
          OR ([j].[StatusCode] = 'SOURCE_UNAVAILABLE' AND [j].[RowCount] IS NOT NULL)
      )
)
    THROW 54874, N'Der msdb-Historienquellenstatus ist nicht konsistent.', 1;

/* Die vorhandene Database-Mail-View muss als lesbare Quelle erkannt werden. */
IF OBJECT_ID(N'msdb.dbo.sysmail_allitems', N'V') IS NOT NULL
   AND EXISTS
   (
       SELECT COUNT_BIG(*), CONVERT(datetime2(3), MIN([send_request_date])),
              CONVERT(datetime2(3), MAX([send_request_date]))
       FROM [msdb].[dbo].[sysmail_allitems] WITH (NOLOCK)
       EXCEPT
       SELECT [j].[RowCount], [j].[OldestUtc], [j].[NewestUtc]
       FROM OPENJSON(@Json)
       WITH
       (
             [Area] varchar(40) '$.Area'
           , [SourceObject] nvarchar(256) '$.SourceObject'
           , [RowCount] bigint '$.RowCount'
           , [OldestUtc] datetime2(3) '$.OldestUtc'
           , [NewestUtc] datetime2(3) '$.NewestUtc'
           , [StatusCode] varchar(40) '$.StatusCode'
       ) AS [j]
       WHERE [j].[Area] = 'DATABASE_MAIL'
         AND [j].[SourceObject] = N'msdb.dbo.sysmail_allitems'
         AND [j].[StatusCode] = 'AVAILABLE'
   )
    THROW 54875, N'Die vorhandene Database-Mail-View fehlt als verfügbare Aggregatquelle.', 1;

/* Agent-Historie zählt Job- und Stepzeilen; Zeitgrenzen werden nicht ermittelt. */
IF EXISTS
(
    SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory] WITH (NOLOCK)
    EXCEPT
    SELECT [j].[RowCount] FROM OPENJSON(@Json)
    WITH ([Area] varchar(40), [RowCount] bigint, [StatusCode] varchar(40)) AS [j]
    WHERE [j].[Area] = 'AGENT_HISTORY' AND [j].[StatusCode] = 'AVAILABLE'
)
    THROW 54876, N'Die Agent-Historienanzahl stimmt nicht mit der nativen Quelle überein.', 1;
IF EXISTS
(
    SELECT 1 FROM OPENJSON(@Json)
    WITH ([Area] varchar(40), [OldestUtc] datetime2(3), [NewestUtc] datetime2(3)) AS [j]
    WHERE [j].[Area] = 'AGENT_HISTORY'
      AND ([j].[OldestUtc] IS NOT NULL OR [j].[NewestUtc] IS NOT NULL)
)
    THROW 54877, N'Der Agent-Aggregatvertrag darf keine unbelegten Zeitgrenzen ausgeben.', 1;

/* NULL und 0 liefern alle Quellen; positive Limits gelten für jeden Consumer. */
DECLARE @ExpectedRows int = (SELECT COUNT(*) FROM OPENJSON(@Json));
DECLARE @LimitCase int = 0, @Limit int, @TableJson nvarchar(max), @ConsoleJson nvarchar(max);
CREATE TABLE [#MsdbConsole122]
(
    [Ergebnis] nvarchar(200), [Area] varchar(40), [SourceObject] nvarchar(256),
    [RowCount] bigint, [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
    [SizeMb] decimal(19,2), [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000)
);
WHILE @LimitCase < 3
BEGIN
    SET @Limit = CASE @LimitCase WHEN 0 THEN NULL WHEN 1 THEN 0 ELSE 1 END;
    CREATE TABLE [#MsdbTable122] ([Dummy] int);
    EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = @Limit,
        @ResultSetArt = 'TABLE', @ResultTablesJson = N'{"msdbHealth":"#MsdbTable122"}',
        @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
    EXEC [sys].[sp_executesql]
        N'SELECT @RowsJson = (SELECT * FROM [#MsdbTable122] ORDER BY [Area] FOR JSON PATH);',
        N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
    IF @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS <> @Json COLLATE SQL_Latin1_General_CP1_CS_AS
       OR (SELECT COUNT(*) FROM OPENJSON(@Json)) <> CASE WHEN @Limit = 1 THEN 1 ELSE @ExpectedRows END
        THROW 54878, N'Die TABLE-/JSON-Limitparität ist verletzt.', 1;
    DROP TABLE [#MsdbTable122];

    TRUNCATE TABLE [#MsdbConsole122];
    INSERT [#MsdbConsole122]
    EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = @Limit,
        @ResultSetArt = 'CONSOLE', @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
    SELECT @ConsoleJson = (SELECT [Area], [SourceObject], [RowCount], [OldestUtc],
        [NewestUtc], [SizeMb], [StatusCode], [EvidenceLimit]
        FROM [#MsdbConsole122] ORDER BY [Area] FOR JSON PATH);
    IF @ConsoleJson COLLATE SQL_Latin1_General_CP1_CS_AS <> @Json COLLATE SQL_Latin1_General_CP1_CS_AS
       OR @ConsoleJson COLLATE SQL_Latin1_General_CP1_CS_AS <> @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS
       OR EXISTS (SELECT 1 FROM [#MsdbConsole122] WHERE [Ergebnis] IS NULL OR [Ergebnis] <> N'msdbHealth')
        THROW 54879, N'Die CONSOLE-/TABLE-/JSON-Limitparität ist verletzt.', 1;
    SET @LimitCase += 1;
END;
DROP TABLE [#MsdbConsole122];

EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = -1,
    @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT,
    @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT, @IsPartialOut = @Partial OUTPUT;
IF @Status <> 'INVALID_PARAMETER' OR @Partial <> 1 OR @Json <> N'[]'
    THROW 54950, N'Das negative Mengenlimit muss als Parameterstatus mit leerem JSON enden.', 1;

IF USER_ID(N'ExampleOps008RestrictedUser') IS NOT NULL
    THROW 54960,N'OPS-008 restricted fixture user name collision.',1;
DECLARE @RestrictedUserCreated bit=0,@RestrictedMsdbVisible bigint=0;
BEGIN TRY
    CREATE USER [ExampleOps008RestrictedUser] WITHOUT LOGIN;
    SET @RestrictedUserCreated=1;
    GRANT EXECUTE ON [monitor].[USP_MsdbHealthAnalysis] TO [ExampleOps008RestrictedUser];
    EXECUTE AS USER = N'ExampleOps008RestrictedUser';
    SELECT @RestrictedMsdbVisible=COUNT_BIG(*) FROM [sys].[databases] WHERE [database_id]=4;
    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL;
    EXEC [monitor].[USP_MsdbHealthAnalysis]
          @MaxZeilen = 20
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT
        , @IsPartialOut = @Partial OUTPUT;
    REVERT;
    IF COALESCE(ISJSON(@Json), 0) <> 1
        THROW 54872, N'Der eingeschränkte msdb-Pfad lieferte kein gültiges JSON.', 1;
    IF @RestrictedMsdbVisible<>0 OR COALESCE(@Status,'')<>'UNSUPPORTED'
       OR COALESCE(@Partial,0)<>1 OR DATALENGTH(@Json)<>4 OR @Json<>N'[]'
        THROW 54975,N'OPS-008 database-scoped loginless caller must retain hidden-msdb preflight semantics.',1;
END TRY
BEGIN CATCH
    IF USER_NAME() = N'ExampleOps008RestrictedUser' REVERT;
    IF @RestrictedUserCreated=1 DROP USER IF EXISTS [ExampleOps008RestrictedUser];
    THROW;
END CATCH;
IF @RestrictedUserCreated=1 DROP USER [ExampleOps008RestrictedUser];
IF USER_ID(N'ExampleOps008RestrictedUser') IS NOT NULL
    THROW 54973,N'OPS-008 restricted fixture user remained after cleanup.',1;

DECLARE @PbmOwnLogin sysname=N'ExampleOps008PbmDeniedLogin',
        @PbmOwnUser sysname=N'ExampleOps008PbmDeniedUser';
IF EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmOwnLogin COLLATE SQL_Latin1_General_CP1_CS_AS)
   OR EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmOwnUser COLLATE SQL_Latin1_General_CP1_CS_AS)
   OR EXISTS(SELECT 1 FROM [msdb].[sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmOwnUser COLLATE SQL_Latin1_General_CP1_CS_AS)
    THROW 54976,N'OPS-008 owned PBM login or user name collision.',1;
DECLARE @PbmOwnLoginCreated bit=0,@PbmOwnFrameworkUserCreated bit=0,
        @PbmOwnMsdbUserCreated bit=0,@PbmOwnImpersonated bit=0,
        @PbmOwnLoginId int,@PbmOwnFrameworkUserId int,@PbmOwnMsdbUserId int,
        @PbmOwnSid varbinary(85),@PbmOwnSidHex varchar(32),@PbmOwnCredential nvarchar(128),
        @PbmOwnSql nvarchar(max),@PbmVisible bigint=0,
        @PbmDirectCount bigint,@PbmDirectError int,@PbmDeniedCount int=0,
        @PbmOriginalLogin sysname=SUSER_SNAME(),@PbmOriginalUser sysname=USER_NAME(),
        @PbmOriginalLock int=@@LOCK_TIMEOUT,
        @PbmOriginalAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
        @PbmOriginalTran int,@PbmOriginalXact int;
SELECT @PbmOriginalTran=@@TRANCOUNT;
SELECT @PbmOriginalXact=XACT_STATE();
BEGIN TRY
    SET @PbmOwnSid=CRYPT_GEN_RANDOM(16);
    SET @PbmOwnSidHex=CONVERT(varchar(32),@PbmOwnSid,2);
    IF @PbmOwnSid IS NULL OR DATALENGTH(@PbmOwnSid)<>16
       OR EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [sid]=@PbmOwnSid)
        THROW 54976,N'OPS-008 owned PBM login SID collision or generation failure.',1;
    SET @PbmOwnCredential=N'Example!'+CONVERT(nvarchar(36),NEWID());
    SET @PbmOwnSql=N'CREATE LOGIN '+QUOTENAME(@PbmOwnLogin)
        +N' WITH PASSWORD '+N'= '+QUOTENAME(@PbmOwnCredential,'''')
        +N',SID=0x'+@PbmOwnSidHex+N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';
    EXEC [master].[sys].[sp_executesql] @PbmOwnSql;
    SET @PbmOwnLoginCreated=1;
    SET @PbmOwnCredential=NULL; SET @PbmOwnSql=NULL;
    SELECT @PbmOwnLoginId=[principal_id]
    FROM [sys].[server_principals]
    WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS
         =@PbmOwnLogin COLLATE SQL_Latin1_General_CP1_CS_AS
      AND [sid]=@PbmOwnSid;
    IF @PbmOwnLoginId IS NULL
        THROW 54977,N'OPS-008 owned PBM login identity binding failed.',1;
    CREATE USER [ExampleOps008PbmDeniedUser] FOR LOGIN [ExampleOps008PbmDeniedLogin];
    SET @PbmOwnFrameworkUserCreated=1;
    SELECT @PbmOwnFrameworkUserId=[principal_id]
    FROM [sys].[database_principals]
    WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS
         =@PbmOwnUser COLLATE SQL_Latin1_General_CP1_CS_AS
      AND [sid]=@PbmOwnSid;
    IF @PbmOwnFrameworkUserId IS NULL
        THROW 54978,N'OPS-008 owned PBM framework user SID binding failed.',1;
    EXEC [msdb].[sys].[sp_executesql]
        N'CREATE USER [ExampleOps008PbmDeniedUser] FOR LOGIN [ExampleOps008PbmDeniedLogin];';
    SET @PbmOwnMsdbUserCreated=1;
    SELECT @PbmOwnMsdbUserId=[principal_id]
    FROM [msdb].[sys].[database_principals]
    WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS
         =@PbmOwnUser COLLATE SQL_Latin1_General_CP1_CS_AS
      AND [sid]=@PbmOwnSid;
    IF @PbmOwnMsdbUserId IS NULL
        THROW 54980,N'OPS-008 owned PBM msdb user SID binding failed.',1;
    GRANT EXECUTE ON [monitor].[USP_MsdbHealthAnalysis] TO [ExampleOps008PbmDeniedUser];
    EXEC [master].[sys].[sp_executesql]
        N'GRANT VIEW ANY DATABASE TO [ExampleOps008PbmDeniedLogin];';
    EXEC [msdb].[sys].[sp_executesql]
        N'DENY SELECT ON OBJECT::[dbo].[syspolicy_policies] TO [ExampleOps008PbmDeniedUser];
          DENY SELECT ON OBJECT::[dbo].[syspolicy_conditions] TO [ExampleOps008PbmDeniedUser];
          DENY SELECT ON OBJECT::[dbo].[syspolicy_policy_categories] TO [ExampleOps008PbmDeniedUser];
          DENY SELECT ON OBJECT::[dbo].[backupset] TO [ExampleOps008PbmDeniedUser];
          DENY SELECT ON OBJECT::[dbo].[sysmail_allitems] TO [ExampleOps008PbmDeniedUser];';
    EXECUTE AS LOGIN=N'ExampleOps008PbmDeniedLogin';
    SET @PbmOwnImpersonated=1;
    SELECT @PbmVisible=COUNT_BIG(*) FROM [sys].[databases] WHERE [database_id]=4;
    IF @PbmVisible<>1
        THROW 54981,N'OPS-008 owned login must see msdb before PBM denial probe.',1;
    SET @PbmDirectError=0;
    BEGIN TRY
        EXEC [sys].[sp_executesql]
            N'SELECT @Count=COUNT_BIG(*) FROM [msdb].[dbo].[syspolicy_policies];',
            N'@Count bigint OUTPUT',@Count=@PbmDirectCount OUTPUT;
    END TRY
    BEGIN CATCH
        SET @PbmDirectError=ERROR_NUMBER();
    END CATCH;
    IF @PbmDirectError<>229
        THROW 54979,N'OPS-008 each owned-login PBM view SELECT must fail with SQL 229.',1;
    SET @PbmDeniedCount+=1;
    SET @PbmDirectError=0;
    BEGIN TRY
        EXEC [sys].[sp_executesql]
            N'SELECT @Count=COUNT_BIG(*) FROM [msdb].[dbo].[syspolicy_conditions];',
            N'@Count bigint OUTPUT',@Count=@PbmDirectCount OUTPUT;
    END TRY
    BEGIN CATCH
        SET @PbmDirectError=ERROR_NUMBER();
    END CATCH;
    IF @PbmDirectError<>229
        THROW 54979,N'OPS-008 each owned-login PBM view SELECT must fail with SQL 229.',1;
    SET @PbmDeniedCount+=1;
    SET @PbmDirectError=0;
    BEGIN TRY
        EXEC [sys].[sp_executesql]
            N'SELECT @Count=COUNT_BIG(*) FROM [msdb].[dbo].[syspolicy_policy_categories];',
            N'@Count bigint OUTPUT',@Count=@PbmDirectCount OUTPUT;
    END TRY
    BEGIN CATCH
        SET @PbmDirectError=ERROR_NUMBER();
    END CATCH;
    IF @PbmDirectError<>229
        THROW 54979,N'OPS-008 each owned-login PBM view SELECT must fail with SQL 229.',1;
    SET @PbmDeniedCount+=1;
    IF @PbmDeniedCount<>3
        THROW 54982,N'OPS-008 three owned-login PBM denials were not observed.',1;

    IF (SELECT COUNT_BIG(*)
        FROM [msdb].[sys].[objects] AS [o]
        INNER JOIN [msdb].[sys].[schemas] AS [s] ON [s].[schema_id]=[o].[schema_id]
        WHERE [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'dbo'
          AND [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS IN (N'backupset',N'sysmail_allitems')
          AND [o].[type] COLLATE SQL_Latin1_General_CP1_CS_AS IN (N'U',N'V'))=2
        THROW 54954,N'OPS-008 neither denied optional source is hidden from the catalog.',1;
    SET @PbmDirectError=0;
    BEGIN TRY
        EXEC [sys].[sp_executesql]
            N'SELECT @Count=COUNT_BIG(*) FROM [msdb].[dbo].[backupset];',
            N'@Count bigint OUTPUT',@Count=@PbmDirectCount OUTPUT;
    END TRY
    BEGIN CATCH
        SET @PbmDirectError=ERROR_NUMBER();
    END CATCH;
    IF @PbmDirectError<>229
        THROW 54951,N'OPS-008 native backup history SELECT must fail with SQL 229.',1;
    SET @PbmDirectError=0;
    BEGIN TRY
        EXEC [sys].[sp_executesql]
            N'SELECT @Count=COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_allitems];',
            N'@Count bigint OUTPUT',@Count=@PbmDirectCount OUTPUT;
    END TRY
    BEGIN CATCH
        SET @PbmDirectError=ERROR_NUMBER();
    END CATCH;
    IF @PbmDirectError<>229
        THROW 54952,N'OPS-008 native Mail history SELECT must fail with SQL 229.',1;

    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL;
    EXEC [monitor].[USP_MsdbHealthAnalysis]
          @MaxZeilen=20,@ResultSetArt='NONE',@JsonErzeugen=1,
          @Json=@Json OUTPUT,@PrintMeldungen=0,
          @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    REVERT;
    SET @PbmOwnImpersonated=0;
    IF COALESCE(@Status,'')<>'AVAILABLE_LIMITED' OR COALESCE(@Partial,0)<>1
       OR COALESCE(ISJSON(@Json),0)<>1
        THROW 54987,N'OPS-008 owned-login PBM source-error module status is not limited and partial.',1;
    IF (SELECT COUNT_BIG(DISTINCT [j].[Area]) FROM OPENJSON(@Json)
        WITH ([Area] varchar(40),[SourceObject] nvarchar(256),[RowCount] bigint,
              [OldestUtc] datetime2(3),[NewestUtc] datetime2(3),[SizeMb] decimal(19,2),
              [StatusCode] varchar(40),[EvidenceLimit] nvarchar(1000)) AS [j]
        WHERE (([j].[Area]='BACKUP_HISTORY' AND [j].[SourceObject]=N'msdb.dbo.backupset')
               OR ([j].[Area]='DATABASE_MAIL' AND [j].[SourceObject]=N'msdb.dbo.sysmail_allitems'))
          AND [j].[StatusCode]='SOURCE_UNAVAILABLE' AND [j].[EvidenceLimit] LIKE N'Fehler 229:%'
          AND [j].[RowCount] IS NULL AND [j].[OldestUtc] IS NULL AND [j].[NewestUtc] IS NULL
          AND [j].[SizeMb] IS NULL)<>2
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
           WITH ([Area] varchar(40)) AS [j]
           WHERE [j].[Area] IN ('BACKUP_HISTORY','DATABASE_MAIL'))<>2
        THROW 54953,N'OPS-008 denied optional history sources must be unavailable with unknown counts.',1;
    IF EXISTS
    (
        SELECT 1 FROM
        (VALUES ('PBM_POLICIES',N'msdb.dbo.syspolicy_policies'),
                ('PBM_CONDITIONS',N'msdb.dbo.syspolicy_conditions'),
                ('PBM_CATEGORIES',N'msdb.dbo.syspolicy_policy_categories'))
            AS [e]([Area],[SourceObject])
        WHERE (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
               WITH ([Area] varchar(40),[SourceObject] nvarchar(256),[RowCount] bigint,
                     [OldestUtc] datetime2(3),[NewestUtc] datetime2(3),
                     [SizeMb] decimal(19,2),[StatusCode] varchar(40)) AS [j]
               WHERE [j].[Area] COLLATE SQL_Latin1_General_CP1_CS_AS
                     =[e].[Area] COLLATE SQL_Latin1_General_CP1_CS_AS
                 AND [j].[SourceObject] COLLATE SQL_Latin1_General_CP1_CS_AS
                     =[e].[SourceObject] COLLATE SQL_Latin1_General_CP1_CS_AS
                 AND [j].[StatusCode]='SOURCE_UNAVAILABLE' AND [j].[RowCount] IS NULL
                 AND [j].[OldestUtc] IS NULL AND [j].[NewestUtc] IS NULL
                 AND [j].[SizeMb] IS NULL)<>1
    )
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
           WITH ([Area] varchar(40)) AS [j]
           WHERE [j].[Area] IN ('PBM_POLICIES','PBM_CONDITIONS','PBM_CATEGORIES'))<>3
    BEGIN
        DECLARE @PbmDiagJsonValid int=COALESCE(ISJSON(@Json),0),
                @PbmDiagTotalRows bigint,
                @PbmDiagRows bigint,
                @PbmDiagExactUnknown bigint,
                @PbmDiagAvailable bigint,
                @PbmDiagUnsupported bigint,
                @PbmDiagMessage nvarchar(2048);
        SELECT @PbmDiagTotalRows=COUNT_BIG(*) FROM OPENJSON(@Json);
        SELECT
              @PbmDiagRows=COUNT_BIG(*)
            , @PbmDiagAvailable=COALESCE(SUM(CASE WHEN [j].[StatusCode]='AVAILABLE' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END),0)
            , @PbmDiagUnsupported=COALESCE(SUM(CASE WHEN [j].[StatusCode]='UNSUPPORTED' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END),0)
        FROM OPENJSON(@Json) WITH ([Area] varchar(40),[StatusCode] varchar(40)) AS [j]
        WHERE [j].[Area] IN ('PBM_POLICIES','PBM_CONDITIONS','PBM_CATEGORIES');
        SELECT @PbmDiagExactUnknown=COUNT_BIG(*)
        FROM OPENJSON(@Json)
             WITH ([Area] varchar(40),[SourceObject] nvarchar(256),[RowCount] bigint,
                   [OldestUtc] datetime2(3),[NewestUtc] datetime2(3),
                   [SizeMb] decimal(19,2),[StatusCode] varchar(40)) AS [j]
        INNER JOIN (VALUES ('PBM_POLICIES',N'msdb.dbo.syspolicy_policies'),
                           ('PBM_CONDITIONS',N'msdb.dbo.syspolicy_conditions'),
                           ('PBM_CATEGORIES',N'msdb.dbo.syspolicy_policy_categories'))
            AS [e]([Area],[SourceObject])
            ON [j].[Area] COLLATE SQL_Latin1_General_CP1_CS_AS
                =[e].[Area] COLLATE SQL_Latin1_General_CP1_CS_AS
           AND [j].[SourceObject] COLLATE SQL_Latin1_General_CP1_CS_AS
                =[e].[SourceObject] COLLATE SQL_Latin1_General_CP1_CS_AS
        WHERE [j].[StatusCode]='SOURCE_UNAVAILABLE' AND [j].[RowCount] IS NULL
          AND [j].[OldestUtc] IS NULL AND [j].[NewestUtc] IS NULL
          AND [j].[SizeMb] IS NULL;
        SET @PbmDiagMessage=CONCAT(N'OPS-008 restricted PBM unknown diagnostic: jsonValid=',
            @PbmDiagJsonValid,N'; totalRows=',@PbmDiagTotalRows,
            N'; pbmRows=',@PbmDiagRows,N'; exactUnknown=',@PbmDiagExactUnknown,
            N'; available=',@PbmDiagAvailable,N'; unsupported=',@PbmDiagUnsupported);
        RAISERROR(@PbmDiagMessage,10,1) WITH NOWAIT;
        THROW 54961,N'OPS-008 restricted PBM views must remain unknown rather than unsupported or zero.',1;
    END;
    IF @PbmOwnMsdbUserCreated=1
    BEGIN
        IF NOT EXISTS(SELECT 1 FROM [msdb].[sys].[database_principals]
                      WHERE [principal_id]=@PbmOwnMsdbUserId AND [sid]=@PbmOwnSid
                        AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS
                            =@PbmOwnUser COLLATE SQL_Latin1_General_CP1_CS_AS)
            THROW 54986,N'OPS-008 owned PBM msdb user binding changed before cleanup.',1;
        EXEC [msdb].[sys].[sp_executesql] N'DROP USER [ExampleOps008PbmDeniedUser];';
        SET @PbmOwnMsdbUserCreated=0;
    END;
    IF @PbmOwnFrameworkUserCreated=1
    BEGIN
        IF NOT EXISTS(SELECT 1 FROM [sys].[database_principals]
                      WHERE [principal_id]=@PbmOwnFrameworkUserId AND [sid]=@PbmOwnSid
                        AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS
                            =@PbmOwnUser COLLATE SQL_Latin1_General_CP1_CS_AS)
            THROW 54986,N'OPS-008 owned PBM framework user binding changed before cleanup.',1;
        DROP USER [ExampleOps008PbmDeniedUser];
        SET @PbmOwnFrameworkUserCreated=0;
    END;
    IF @PbmOwnLoginCreated=1
    BEGIN
        IF NOT EXISTS(SELECT 1 FROM [sys].[server_principals]
                      WHERE [principal_id]=@PbmOwnLoginId AND [sid]=@PbmOwnSid
                        AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS
                            =@PbmOwnLogin COLLATE SQL_Latin1_General_CP1_CS_AS)
            THROW 54986,N'OPS-008 owned PBM login binding changed before cleanup.',1;
        EXEC [master].[sys].[sp_executesql] N'DROP LOGIN [ExampleOps008PbmDeniedLogin];';
        SET @PbmOwnLoginCreated=0;
    END;
END TRY
BEGIN CATCH
    IF @PbmOwnImpersonated=1 REVERT;
    SET @PbmOwnCredential=NULL; SET @PbmOwnSql=NULL;
    IF @PbmOwnMsdbUserCreated=1
       AND EXISTS(SELECT 1 FROM [msdb].[sys].[database_principals]
                  WHERE (@PbmOwnMsdbUserId IS NULL OR [principal_id]=@PbmOwnMsdbUserId) AND [sid]=@PbmOwnSid
                    AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS
                        =@PbmOwnUser COLLATE SQL_Latin1_General_CP1_CS_AS)
        EXEC [msdb].[sys].[sp_executesql] N'DROP USER [ExampleOps008PbmDeniedUser];';
    IF @PbmOwnFrameworkUserCreated=1
       AND EXISTS(SELECT 1 FROM [sys].[database_principals]
                  WHERE (@PbmOwnFrameworkUserId IS NULL OR [principal_id]=@PbmOwnFrameworkUserId) AND [sid]=@PbmOwnSid
                    AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS
                        =@PbmOwnUser COLLATE SQL_Latin1_General_CP1_CS_AS)
        DROP USER [ExampleOps008PbmDeniedUser];
    IF @PbmOwnLoginCreated=1
       AND EXISTS(SELECT 1 FROM [sys].[server_principals]
                  WHERE (@PbmOwnLoginId IS NULL OR [principal_id]=@PbmOwnLoginId) AND [sid]=@PbmOwnSid
                    AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS
                        =@PbmOwnLogin COLLATE SQL_Latin1_General_CP1_CS_AS)
        EXEC [master].[sys].[sp_executesql] N'DROP LOGIN [ExampleOps008PbmDeniedLogin];';
    IF EXISTS(SELECT 1 FROM [sys].[server_principals]
              WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmOwnLogin COLLATE SQL_Latin1_General_CP1_CS_AS OR ([sid]=@PbmOwnSid AND (@PbmOwnLoginId IS NULL OR [principal_id]=@PbmOwnLoginId)))
       OR EXISTS(SELECT 1 FROM [sys].[database_principals]
                 WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmOwnUser COLLATE SQL_Latin1_General_CP1_CS_AS OR ([sid]=@PbmOwnSid AND (@PbmOwnFrameworkUserId IS NULL OR [principal_id]=@PbmOwnFrameworkUserId)))
       OR EXISTS(SELECT 1 FROM [msdb].[sys].[database_principals]
                 WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmOwnUser COLLATE SQL_Latin1_General_CP1_CS_AS OR ([sid]=@PbmOwnSid AND (@PbmOwnMsdbUserId IS NULL OR [principal_id]=@PbmOwnMsdbUserId)))
        THROW 54986,N'OPS-008 owned PBM principal remained after cleanup.',1;
    IF SUSER_SNAME() COLLATE SQL_Latin1_General_CP1_CS_AS
           <>@PbmOriginalLogin COLLATE SQL_Latin1_General_CP1_CS_AS
       OR USER_NAME() COLLATE SQL_Latin1_General_CP1_CS_AS
           <>@PbmOriginalUser COLLATE SQL_Latin1_General_CP1_CS_AS
       OR @@LOCK_TIMEOUT<>@PbmOriginalLock
       OR CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END<>@PbmOriginalAbort
        THROW 54983,N'OPS-008 owned-login caller identity or options changed.',1;
    IF @@TRANCOUNT<>@PbmOriginalTran
        THROW 54984,N'OPS-008 owned-login caller transaction count changed.',1;
    IF XACT_STATE()<>@PbmOriginalXact
        THROW 54985,N'OPS-008 owned-login caller transaction state changed.',1;
    THROW;
END CATCH;
IF EXISTS(SELECT 1 FROM [sys].[server_principals]
          WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmOwnLogin COLLATE SQL_Latin1_General_CP1_CS_AS OR ([sid]=@PbmOwnSid AND (@PbmOwnLoginId IS NULL OR [principal_id]=@PbmOwnLoginId)))
   OR EXISTS(SELECT 1 FROM [sys].[database_principals]
             WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmOwnUser COLLATE SQL_Latin1_General_CP1_CS_AS OR ([sid]=@PbmOwnSid AND (@PbmOwnFrameworkUserId IS NULL OR [principal_id]=@PbmOwnFrameworkUserId)))
   OR EXISTS(SELECT 1 FROM [msdb].[sys].[database_principals]
             WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmOwnUser COLLATE SQL_Latin1_General_CP1_CS_AS OR ([sid]=@PbmOwnSid AND (@PbmOwnMsdbUserId IS NULL OR [principal_id]=@PbmOwnMsdbUserId)))
    THROW 54986,N'OPS-008 owned PBM principal remained after cleanup.',1;
IF SUSER_SNAME() COLLATE SQL_Latin1_General_CP1_CS_AS
       <>@PbmOriginalLogin COLLATE SQL_Latin1_General_CP1_CS_AS
   OR USER_NAME() COLLATE SQL_Latin1_General_CP1_CS_AS
       <>@PbmOriginalUser COLLATE SQL_Latin1_General_CP1_CS_AS
   OR @@LOCK_TIMEOUT<>@PbmOriginalLock
   OR CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END<>@PbmOriginalAbort
    THROW 54983,N'OPS-008 owned-login caller identity or options changed.',1;
IF @@TRANCOUNT<>@PbmOriginalTran
    THROW 54984,N'OPS-008 owned-login caller transaction count changed.',1;
IF XACT_STATE()<>@PbmOriginalXact
    THROW 54985,N'OPS-008 owned-login caller transaction state changed.',1;


DECLARE @PbmCategoryName sysname=N'ExampleOps008Pbm_'+LEFT(REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),20),
        @PbmCategoryId int=NULL,@PbmAddReturn int=NULL,@PbmDeleteReturn int=NULL,
        @PbmBaseline bigint=NULL,@PbmAfter bigint=NULL,@PbmFailure int=NULL,
        @PbmCleanupFailure int=NULL,@PbmOwnedName bit=0,
        @PbmTableJson nvarchar(max)=NULL,@PbmFailureMessage nvarchar(2048),
        @PbmCallerUser sysname=USER_NAME(),@PbmCallerLogin sysname=SUSER_SNAME(),
        @PbmCallerLock int=@@LOCK_TIMEOUT,
        @PbmCallerAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
        @PbmAfterTransactionCount int,@PbmAfterXactState int;
BEGIN TRY
    SELECT @PbmBaseline=COUNT_BIG(*) FROM [msdb].[dbo].[syspolicy_policy_categories];
    IF EXISTS(SELECT 1 FROM [msdb].[dbo].[syspolicy_policy_categories]
              WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmCategoryName COLLATE SQL_Latin1_General_CP1_CS_AS)
        THROW 54962,N'OPS-008 owned PBM category name collision.',1;
    SET @PbmOwnedName=1;
    EXEC [msdb].[sys].[sp_executesql]
        N'EXEC @Result=dbo.sp_syspolicy_add_policy_category
              @name=@Name,@mandate_database_subscriptions=0,
              @policy_category_id=@Id OUTPUT;',
        N'@Name sysname,@Id int OUTPUT,@Result int OUTPUT',
        @Name=@PbmCategoryName,@Id=@PbmCategoryId OUTPUT,
        @Result=@PbmAddReturn OUTPUT;
    IF COALESCE(@PbmAddReturn,-1)<>0 OR @PbmCategoryId IS NULL
        THROW 54963,N'OPS-008 documented owned PBM category creation failed.',1;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[syspolicy_policy_categories]
        WHERE [policy_category_id]=@PbmCategoryId AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmCategoryName COLLATE SQL_Latin1_General_CP1_CS_AS
          AND [mandate_database_subscriptions]=0)<>1
       OR EXISTS(SELECT 1 FROM [msdb].[dbo].[syspolicy_policies]
                 WHERE [policy_category_id]=@PbmCategoryId)
       OR EXISTS(SELECT 1 FROM [msdb].[dbo].[syspolicy_policy_category_subscriptions]
                 WHERE [policy_category_id]=@PbmCategoryId)
        THROW 54964,N'OPS-008 owned PBM category identity or non-mandated isolation failed.',1;
    SELECT @PbmAfter=COUNT_BIG(*) FROM [msdb].[dbo].[syspolicy_policy_categories];
    IF @PbmAfter<>@PbmBaseline+1
        THROW 54965,N'OPS-008 owned PBM category native count did not increase by one.',1;

    CREATE TABLE [#MsdbPbmTable122] ([Seed] int NULL);
    SET @Json=NULL;
    EXEC [monitor].[USP_MsdbHealthAnalysis]
        @MaxZeilen=0,@ResultSetArt='TABLE',
        @ResultTablesJson=N'{"msdbHealth":"#MsdbPbmTable122"}',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    EXEC [sys].[sp_executesql]
        N'SELECT @RowsJson=(SELECT * FROM [#MsdbPbmTable122] ORDER BY [Area] FOR JSON PATH);',
        N'@RowsJson nvarchar(max) OUTPUT',@RowsJson=@PbmTableJson OUTPUT;
    IF COALESCE(ISJSON(@Json),0)<>1 OR @PbmTableJson IS NULL
       OR DATALENGTH(@PbmTableJson)<>DATALENGTH(@Json)
       OR @PbmTableJson COLLATE SQL_Latin1_General_CP1_CS_AS
          <>@Json COLLATE SQL_Latin1_General_CP1_CS_AS
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json))<>9
       OR COALESCE(@Status,'') NOT IN ('AVAILABLE','AVAILABLE_LIMITED')
       OR (@Status='AVAILABLE' AND COALESCE(@Partial,1)<>0)
       OR (@Status='AVAILABLE_LIMITED' AND COALESCE(@Partial,0)<>1)
        THROW 54966,N'OPS-008 owned PBM category TABLE and JSON output contract failed.',1;
    IF EXISTS
    (
        SELECT 1 FROM
        (VALUES
            ('PBM_POLICIES',N'msdb.dbo.syspolicy_policies',
             (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[syspolicy_policies])),
            ('PBM_CONDITIONS',N'msdb.dbo.syspolicy_conditions',
             (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[syspolicy_conditions])),
            ('PBM_CATEGORIES',N'msdb.dbo.syspolicy_policy_categories',@PbmAfter)
        ) AS [e]([Area],[SourceObject],[NativeCount])
        WHERE (SELECT COUNT_BIG(*)
               FROM OPENJSON(@Json)
               WITH ([Area] varchar(40),[SourceObject] nvarchar(256),
                     [RowCount] bigint,[OldestUtc] datetime2(3),[NewestUtc] datetime2(3),
                     [SizeMb] decimal(19,2),[StatusCode] varchar(40),
                     [EvidenceLimit] nvarchar(1000)) AS [j]
               WHERE [j].[Area] COLLATE SQL_Latin1_General_CP1_CS_AS
                     =[e].[Area] COLLATE SQL_Latin1_General_CP1_CS_AS
                 AND [j].[SourceObject] COLLATE SQL_Latin1_General_CP1_CS_AS
                     =[e].[SourceObject] COLLATE SQL_Latin1_General_CP1_CS_AS
                 AND [j].[RowCount]=[e].[NativeCount]
                 AND [j].[OldestUtc] IS NULL AND [j].[NewestUtc] IS NULL
                 AND [j].[SizeMb] IS NULL AND [j].[StatusCode]='AVAILABLE'
                 AND NULLIF([j].[EvidenceLimit],N'') IS NOT NULL)<>1
    )
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
           WITH ([Area] varchar(40)) AS [j]
           WHERE [j].[Area] IN ('PBM_POLICIES','PBM_CONDITIONS','PBM_CATEGORIES'))<>3
        THROW 54967,N'OPS-008 PBM source counts, null bounds or named areas differ from native views.',1;
    DROP TABLE [#MsdbPbmTable122];
END TRY
BEGIN CATCH
    SET @PbmFailure=ERROR_NUMBER();
END CATCH;

BEGIN TRY
    IF @PbmOwnedName=1
       AND EXISTS(SELECT 1 FROM [msdb].[dbo].[syspolicy_policy_categories]
                  WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmCategoryName COLLATE SQL_Latin1_General_CP1_CS_AS
                    AND (@PbmCategoryId IS NULL OR [policy_category_id]=@PbmCategoryId))
    BEGIN
        IF @PbmCategoryId IS NULL
            EXEC [msdb].[sys].[sp_executesql]
                N'EXEC @Result=dbo.sp_syspolicy_delete_policy_category @name=@Name;',
                N'@Name sysname,@Result int OUTPUT',
                @Name=@PbmCategoryName,@Result=@PbmDeleteReturn OUTPUT;
        ELSE
            EXEC [msdb].[sys].[sp_executesql]
                N'EXEC @Result=dbo.sp_syspolicy_delete_policy_category @policy_category_id=@Id;',
                N'@Id int,@Result int OUTPUT',
                @Id=@PbmCategoryId,@Result=@PbmDeleteReturn OUTPUT;
        IF COALESCE(@PbmDeleteReturn,-1)<>0
            THROW 54968,N'OPS-008 documented owned PBM category deletion failed.',1;
    END;
    DROP TABLE IF EXISTS [#MsdbPbmTable122];
    IF @PbmOwnedName=1
       AND EXISTS(SELECT 1 FROM [msdb].[dbo].[syspolicy_policy_categories]
                  WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@PbmCategoryName COLLATE SQL_Latin1_General_CP1_CS_AS)
        THROW 54969,N'OPS-008 owned PBM category remained after cleanup.',1;
    IF @PbmBaseline IS NOT NULL
       AND (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[syspolicy_policy_categories])<>@PbmBaseline
        THROW 54970,N'OPS-008 PBM category count was not restored.',1;
    SELECT @PbmAfterTransactionCount=@@TRANCOUNT;
    SELECT @PbmAfterXactState=XACT_STATE();
    IF @PbmAfterTransactionCount<>0 OR @PbmAfterXactState<>0
       OR USER_NAME()<>@PbmCallerUser OR SUSER_SNAME()<>@PbmCallerLogin
       OR @@LOCK_TIMEOUT<>@PbmCallerLock
       OR CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END<>@PbmCallerAbort
        THROW 54971,N'OPS-008 PBM fixture caller state was not restored.',1;
END TRY
BEGIN CATCH
    SET @PbmCleanupFailure=ERROR_NUMBER();
END CATCH;
IF @PbmFailure IS NOT NULL OR @PbmCleanupFailure IS NOT NULL
BEGIN
    SET @PbmFailureMessage=N'OPS-008 PBM fixture failed: native='
        +COALESCE(CONVERT(nvarchar(20),@PbmFailure),N'NULL')
        +N'; cleanup='+COALESCE(CONVERT(nvarchar(20),@PbmCleanupFailure),N'NULL');
    THROW 54972,@PbmFailureMessage,1;
END;
GO

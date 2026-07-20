USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentOverview
Version      : 3.2.0
Stand        : 2026-07-21
Zweck        : Orchestriert jedes aktivierte Current-State-Child genau einmal,
               übernimmt dessen expliziten Status und materialisiert Daten für
               CONSOLE, JSON und benannte TABLE-Exporte ohne erneute Systemlese.
CONSOLE      : SUMMARY ist der Default. RELEVANT und ALL ergänzen ausschließlich
               nicht leere Childdetails; Children erhalten niemals CONSOLE.
TABLE-Namen  : moduleStatus, sessions, requests, blocking, waits, transactions,
               memoryGrants, tempdbSessions, io, logs und warnings.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentOverview]
      @SessionIds                    nvarchar(max)  = NULL
    , @DatabaseNames                 nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen  bit            = 0
    , @DatabaseNamePattern           nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @ToolHintergrundabfragenEinbeziehen bit          = 0
    , @Detailgrad                    varchar(16)     = 'SUMMARY'
    , @MitSessions                   bit             = 1
    , @MitRequests                   bit             = 1
    , @MitBlocking                   bit             = 1
    , @BlockingObjektTiefe           varchar(16)     = 'STANDARD'
    , @MaxObjektAufloesungen         int             = 100
    , @MitWaits                      bit             = 1
    , @MitTransactions               bit             = 1
    , @MitMemoryGrants               bit             = 1
    , @MitTempDB                     bit             = 1
    , @MitIO                         bit             = 1
    , @MitLog                        bit             = 1
    , @MitSqlText                    bit             = 1
    , @GesamtenSqlTextEinbeziehen    bit             = 0
    , @InputBufferEinbeziehen        bit             = 0
    , @ModulInfoEinbeziehen          bit             = 1
    , @MaxSqlTextZeichen             int             = 4000
    , @SampleSeconds                 tinyint         = 0
    , @MaxZeilen                     int             = 500
    , @ResultSetArt                  varchar(16)     = 'CONSOLE'
    , @ResultTablesJson              nvarchar(max)   = NULL
    , @JsonErzeugen                  bit             = 0
    , @Json                          nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                bit             = 1
    , @Hilfe                         bit             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,N''))));
    DECLARE @DetailMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@Detailgrad,N''))));
    DECLARE @BlockingObjectDepth varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@BlockingObjektTiefe,N''))));

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CurrentOverview';
        PRINT N'Ohne Datenbankfilter werden alle sichtbaren, online befindlichen Benutzerdatenbanken berücksichtigt.';
        PRINT N'@ToolHintergrundabfragenEinbeziehen=0 blendet erkannte Tool-Hintergrundaktivität in Sessions, Requests, Blocking-Blättern und aktuellen Waiting Tasks aus; 1 zeigt sie samt Klassifikation.';
        PRINT N'@Detailgrad=SUMMARY (Default)|RELEVANT|ALL. Leere Childdetails erzeugen kein Grid.';
        PRINT N'@BlockingObjektTiefe=NONE|STANDARD|DEEP; DEEP benötigt LOCKS_DEEP und @HighImpactConfirmed=1.';
        PRINT N'@MaxObjektAufloesungen begrenzt die Blocking-Ressourcenauflösung auf 1 bis 1000 Kandidaten.';
        PRINT N'Children werden genau einmal und nie mit CONSOLE aufgerufen.';
        PRINT N'@ResultSetArt=CONSOLE|RAW|TABLE|NONE; TABLE verwendet ausschließlich @ResultTablesJson.';
        PRINT N'TABLE-Namen: moduleStatus, sessions, requests, blocking, waits, transactions, memoryGrants, tempdbSessions, io, logs, warnings.';
        RETURN;
    END;

    DECLARE @StartedAtUtc datetime2(3)=SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40)='AVAILABLE';
    DECLARE @ErrorMessage nvarchar(2048)=NULL;
    DECLARE @ExecutedModules int=0;
    DECLARE @FailedModules int=0;
    DECLARE @PartialModules int=0;
    DECLARE @Message nvarchar(2048);
    DECLARE @ChildJson nvarchar(max);
    DECLARE @ChildStartedAtUtc datetime2(3);
    DECLARE @ChildDurationMs bigint;

    CREATE TABLE [#CurrentOverview_ResultTableMap]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE
    );

    CREATE TABLE [#CurrentOverview_ModulePayload]
    (
          [ModuleOrdinal] int NOT NULL PRIMARY KEY
        , [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ModuleName] sysname NOT NULL
        , [SourceTable] sysname NOT NULL
        , [IsEnabled] bit NOT NULL
        , [IsRelevant] bit NOT NULL
        , [IsMaterialized] bit NOT NULL
        , [DurationMs] bigint NOT NULL
        , [JsonValue] nvarchar(max) NULL
        , [ExecutionError] nvarchar(2048) NULL
    );

    CREATE TABLE [#CurrentOverview_ModuleStatus]
    (
          [ModuleOrdinal] int NOT NULL
        , [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ModuleName] sysname NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL
        , [ReturnedRowCount] bigint NOT NULL
        , [DurationMs] bigint NOT NULL
        , [ErrorMessage] nvarchar(2048) NULL
        , PRIMARY KEY ([ModuleOrdinal])
    );

    CREATE TABLE [#CurrentOverview_Warnings]
    (
          [ModuleName] sysname NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [Message] nvarchar(2048) NULL
    );

    CREATE TABLE [#CurrentOverview_Sessions]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_Requests]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_Blocking]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_Waits]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_Transactions]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_MemoryGrants]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_TempDBSessions]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_IO]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_Logs]([Seed] bit NULL);

    IF @OutputMode NOT IN ('RAW','CONSOLE','TABLE','NONE')
       OR @DetailMode NOT IN ('SUMMARY','RELEVANT','ALL')
       OR @BlockingObjectDepth NOT IN ('NONE','STANDARD','DEEP')
       OR @MaxObjektAufloesungen IS NULL OR @MaxObjektAufloesungen NOT BETWEEN 1 AND 1000
       OR @SampleSeconds > 60
       OR @MaxZeilen < 0
       OR @MaxSqlTextZeichen < 0
       OR @JsonErzeugen IS NULL OR @JsonErzeugen NOT IN (0,1)
       OR @SystemdatenbankenEinbeziehen IS NULL OR @SystemdatenbankenEinbeziehen NOT IN (0,1)
       OR @MitSessions IS NULL OR @MitSessions NOT IN (0,1)
       OR @MitRequests IS NULL OR @MitRequests NOT IN (0,1)
       OR @MitBlocking IS NULL OR @MitBlocking NOT IN (0,1)
       OR @MitWaits IS NULL OR @MitWaits NOT IN (0,1)
       OR @MitTransactions IS NULL OR @MitTransactions NOT IN (0,1)
       OR @MitMemoryGrants IS NULL OR @MitMemoryGrants NOT IN (0,1)
       OR @MitTempDB IS NULL OR @MitTempDB NOT IN (0,1)
       OR @MitIO IS NULL OR @MitIO NOT IN (0,1)
       OR @MitLog IS NULL OR @MitLog NOT IN (0,1)
       OR @MitSqlText IS NULL OR @MitSqlText NOT IN (0,1)
       OR @HighImpactConfirmed IS NULL OR @HighImpactConfirmed NOT IN (0,1)
       OR @ToolHintergrundabfragenEinbeziehen IS NULL OR @ToolHintergrundabfragenEinbeziehen NOT IN (0,1)
       OR @GesamtenSqlTextEinbeziehen IS NULL OR @GesamtenSqlTextEinbeziehen NOT IN (0,1)
       OR @InputBufferEinbeziehen IS NULL OR @InputBufferEinbeziehen NOT IN (0,1)
       OR @ModulInfoEinbeziehen IS NULL OR @ModulInfoEinbeziehen NOT IN (0,1)
       OR (@OutputMode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SET @StatusCode='INVALID_PARAMETER';
        SET @ErrorMessage=N'Mindestens ein Parameter besitzt einen ungültigen Wert.';
    END;

    IF @StatusCode='AVAILABLE' AND @OutputMode='TABLE'
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'moduleStatus|sessions|requests|blocking|waits|transactions|memoryGrants|tempdbSessions|io|logs|warnings'
            , @MappingTable=N'#CurrentOverview_ResultTableMap'
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @ThrowOnError=1;
    END;

    IF @StatusCode<>'AVAILABLE'
    BEGIN
        INSERT [#CurrentOverview_ModuleStatus]
        VALUES(0,N'moduleStatus',N'USP_CurrentOverview',@StatusCode,1,0,0,@ErrorMessage);
        GOTO BuildOutputs;
    END;

    /* Sessions */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitSessions=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentSessions]
                  @SessionIds=@SessionIds
                , @ToolHintergrundabfragenEinbeziehen=@ToolHintergrundabfragenEinbeziehen
                , @MitSqlText=@MitSqlText
                , @MaxSqlTextZeichen=@MaxSqlTextZeichen
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"sessions":"#CurrentOverview_Sessions"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(10,N'sessions',N'USP_CurrentSessions',N'#CurrentOverview_Sessions',1,0,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(10,N'sessions',N'USP_CurrentSessions',N'#CurrentOverview_Sessions',1,0,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(10,N'sessions',N'USP_CurrentSessions',N'#CurrentOverview_Sessions',0,0,0,0,NULL,NULL);

    /* Requests */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitRequests=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentRequests]
                  @SessionIds=@SessionIds
                , @ToolHintergrundabfragenEinbeziehen=@ToolHintergrundabfragenEinbeziehen
                , @MitSqlText=@MitSqlText
                , @GesamtenSqlTextEinbeziehen=@GesamtenSqlTextEinbeziehen
                , @InputBufferEinbeziehen=@InputBufferEinbeziehen
                , @ModulInfoEinbeziehen=@ModulInfoEinbeziehen
                , @MaxSqlTextZeichen=@MaxSqlTextZeichen
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"requests":"#CurrentOverview_Requests"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(20,N'requests',N'USP_CurrentRequests',N'#CurrentOverview_Requests',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(20,N'requests',N'USP_CurrentRequests',N'#CurrentOverview_Requests',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(20,N'requests',N'USP_CurrentRequests',N'#CurrentOverview_Requests',0,1,0,0,NULL,NULL);

    /* Blocking */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitBlocking=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentBlocking]
                  @SessionIds=@SessionIds
                , @ToolHintergrundabfragenEinbeziehen=@ToolHintergrundabfragenEinbeziehen
                , @MitSqlText=@MitSqlText
                , @MaxSqlTextZeichen=@MaxSqlTextZeichen
                , @BlockingObjektTiefe=@BlockingObjectDepth
                , @MaxObjektAufloesungen=@MaxObjektAufloesungen
                , @HighImpactConfirmed=@HighImpactConfirmed
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"blockingChains":"#CurrentOverview_Blocking"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(30,N'blocking',N'USP_CurrentBlocking',N'#CurrentOverview_Blocking',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(30,N'blocking',N'USP_CurrentBlocking',N'#CurrentOverview_Blocking',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(30,N'blocking',N'USP_CurrentBlocking',N'#CurrentOverview_Blocking',0,1,0,0,NULL,NULL);

    /* Waits */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitWaits=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentWaits]
                  @SessionIds=@SessionIds
                , @ToolHintergrundabfragenEinbeziehen=@ToolHintergrundabfragenEinbeziehen
                , @MitSqlText=@MitSqlText
                , @MaxSqlTextZeichen=@MaxSqlTextZeichen
                , @SampleSeconds=@SampleSeconds
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"currentTasks":"#CurrentOverview_Waits"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(40,N'waits',N'USP_CurrentWaits',N'#CurrentOverview_Waits',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(40,N'waits',N'USP_CurrentWaits',N'#CurrentOverview_Waits',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(40,N'waits',N'USP_CurrentWaits',N'#CurrentOverview_Waits',0,1,0,0,NULL,NULL);

    /* Transactions */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitTransactions=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentTransactions]
                  @SessionIds=@SessionIds
                , @MitSqlText=@MitSqlText
                , @MaxSqlTextZeichen=@MaxSqlTextZeichen
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"transactions":"#CurrentOverview_Transactions"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(50,N'transactions',N'USP_CurrentTransactions',N'#CurrentOverview_Transactions',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(50,N'transactions',N'USP_CurrentTransactions',N'#CurrentOverview_Transactions',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(50,N'transactions',N'USP_CurrentTransactions',N'#CurrentOverview_Transactions',0,1,0,0,NULL,NULL);

    /* Memory grants */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitMemoryGrants=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentMemoryGrants]
                  @SessionIds=@SessionIds
                , @MitSqlText=@MitSqlText
                , @MaxSqlTextZeichen=@MaxSqlTextZeichen
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"memoryGrants":"#CurrentOverview_MemoryGrants"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(60,N'memoryGrants',N'USP_CurrentMemoryGrants',N'#CurrentOverview_MemoryGrants',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(60,N'memoryGrants',N'USP_CurrentMemoryGrants',N'#CurrentOverview_MemoryGrants',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(60,N'memoryGrants',N'USP_CurrentMemoryGrants',N'#CurrentOverview_MemoryGrants',0,1,0,0,NULL,NULL);

    /* TempDB */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitTempDB=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentTempDB]
                  @SessionIds=@SessionIds
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"sessions":"#CurrentOverview_TempDBSessions"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(70,N'tempdbSessions',N'USP_CurrentTempDB',N'#CurrentOverview_TempDBSessions',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(70,N'tempdbSessions',N'USP_CurrentTempDB',N'#CurrentOverview_TempDBSessions',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(70,N'tempdbSessions',N'USP_CurrentTempDB',N'#CurrentOverview_TempDBSessions',0,1,0,0,NULL,NULL);

    /* I/O */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitIO=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentIO]
                  @DatabaseNames=@DatabaseNames
                , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @SampleSeconds=@SampleSeconds
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"files":"#CurrentOverview_IO"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(80,N'io',N'USP_CurrentIO',N'#CurrentOverview_IO',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(80,N'io',N'USP_CurrentIO',N'#CurrentOverview_IO',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(80,N'io',N'USP_CurrentIO',N'#CurrentOverview_IO',0,1,0,0,NULL,NULL);

    /* Transaction log */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitLog=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentLog]
                  @DatabaseNames=@DatabaseNames
                , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"logs":"#CurrentOverview_Logs"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(90,N'logs',N'USP_CurrentLog',N'#CurrentOverview_Logs',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(90,N'logs',N'USP_CurrentLog',N'#CurrentOverview_Logs',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(90,N'logs',N'USP_CurrentLog',N'#CurrentOverview_Logs',0,1,0,0,NULL,NULL);

    INSERT [#CurrentOverview_ModuleStatus]
    (
          [ModuleOrdinal],[ResultName],[ModuleName],[StatusCode],[IsPartial]
        , [ReturnedRowCount],[DurationMs],[ErrorMessage]
    )
    SELECT
          [p].[ModuleOrdinal]
        , [p].[ResultName]
        , [p].[ModuleName]
        , [x].[StatusCode]
        , CONVERT(bit,CASE
              WHEN [p].[IsEnabled]=0 THEN 0
              WHEN [x].[StatusCode]='AVAILABLE'
               AND COALESCE(JSON_VALUE([p].[JsonValue],N'$.meta.isPartial'),N'false')=N'false'
                  THEN 0
              ELSE 1 END)
        , [x].[ReturnedRows]
        , [p].[DurationMs]
        , COALESCE([p].[ExecutionError],JSON_VALUE([p].[JsonValue],N'$.warnings[0].message'))
    FROM [#CurrentOverview_ModulePayload] AS [p]
    CROSS APPLY
    (
        SELECT
              [StatusCode]=CONVERT(varchar(40),CASE
                    WHEN [p].[IsEnabled]=0 THEN 'SKIPPED'
                    WHEN [p].[ExecutionError] IS NOT NULL THEN 'ERROR_HANDLED'
                    WHEN ISJSON([p].[JsonValue])<>1 THEN 'STATUS_UNAVAILABLE'
                    WHEN JSON_VALUE([p].[JsonValue],N'$.meta.statusCode') IS NULL THEN 'STATUS_UNAVAILABLE'
                    WHEN COALESCE
                         (
                             TRY_CONVERT(bigint,JSON_VALUE([p].[JsonValue],N'$.meta.returnedRows')),
                             TRY_CONVERT(bigint,JSON_VALUE([p].[JsonValue],N'$.meta.currentTaskRows'))
                         ) IS NULL THEN 'STATUS_UNAVAILABLE'
                    ELSE JSON_VALUE([p].[JsonValue],N'$.meta.statusCode') END)
            , [ReturnedRows]=CONVERT(bigint,CASE
                    WHEN [p].[IsEnabled]=0 THEN 0
                    ELSE COALESCE
                         (
                             TRY_CONVERT(bigint,JSON_VALUE([p].[JsonValue],N'$.meta.returnedRows')),
                             TRY_CONVERT(bigint,JSON_VALUE([p].[JsonValue],N'$.meta.currentTaskRows')),
                             0
                         ) END)
    ) AS [x];

    INSERT [#CurrentOverview_Warnings]([ModuleName],[StatusCode],[Message])
    SELECT [ModuleName],[StatusCode],[ErrorMessage]
    FROM [#CurrentOverview_ModuleStatus]
    WHERE [IsPartial]=1 OR [StatusCode] NOT IN ('AVAILABLE','SKIPPED');

    SELECT
          @FailedModules=COALESCE(SUM(CASE WHEN [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED') THEN 1 ELSE 0 END),0)
        , @PartialModules=COALESCE(SUM(CASE WHEN [IsPartial]=1 THEN 1 ELSE 0 END),0)
    FROM [#CurrentOverview_ModuleStatus];

    SET @StatusCode=CASE
        WHEN @ExecutedModules=0 THEN 'AVAILABLE'
        WHEN @FailedModules=0 AND @PartialModules=0 THEN 'AVAILABLE'
        WHEN @FailedModules<@ExecutedModules THEN 'AVAILABLE_LIMITED'
        ELSE 'ERROR_HANDLED' END;

BuildOutputs:
    IF @PrintMeldungen=1 AND (@FailedModules>0 OR @PartialModules>0)
    BEGIN
        SET @Message=FORMATMESSAGE(N'HINWEIS USP_CurrentOverview: %d Modul(e) fehlgeschlagen, %d Modul(e) partiell; %d aktiviert.',@FailedModules,@PartialModules,@ExecutedModules);
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;

    IF @OutputMode IN ('CONSOLE','RAW')
    BEGIN
        SELECT
              [ModuleName]
            , [StatusCode]
            , [IsPartial]
            , [ReturnedRowCount]
            , [DurationMs]
            , [ErrorMessage]
        FROM [#CurrentOverview_ModuleStatus]
        ORDER BY [ModuleOrdinal];
    END;

    IF @OutputMode='RAW'
    BEGIN
        SELECT [ModuleName],[StatusCode],[Message]
        FROM [#CurrentOverview_Warnings]
        ORDER BY [ModuleName];
    END;

    IF @OutputMode='CONSOLE' AND @DetailMode IN ('RELEVANT','ALL')
    BEGIN
        DECLARE @DetailSourceTable sysname;
        DECLARE @DetailSql nvarchar(max);

        DECLARE [DetailCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [p].[SourceTable]
            FROM [#CurrentOverview_ModulePayload] AS [p]
            INNER JOIN [#CurrentOverview_ModuleStatus] AS [s]
              ON [s].[ModuleOrdinal]=[p].[ModuleOrdinal]
            WHERE [p].[IsEnabled]=1
              AND [p].[IsMaterialized]=1
              AND [s].[ReturnedRowCount]>0
              AND [s].[StatusCode] IN ('AVAILABLE','AVAILABLE_LIMITED')
              AND (@DetailMode='ALL' OR [p].[IsRelevant]=1)
            ORDER BY [p].[ModuleOrdinal];

        OPEN [DetailCursor];
        FETCH NEXT FROM [DetailCursor] INTO @DetailSourceTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @DetailSql=N'SELECT * FROM '+QUOTENAME(@DetailSourceTable)+N';';
            EXEC [sys].[sp_executesql] @DetailSql;
            FETCH NEXT FROM [DetailCursor] INTO @DetailSourceTable;
        END;
        CLOSE [DetailCursor];
        DEALLOCATE [DetailCursor];
    END;

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=
        (
            SELECT
                  N'CurrentOverview' AS [resultName]
                , 3 AS [schemaVersion]
                , @StartedAtUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , CONVERT(bit,CASE WHEN @PartialModules>0 OR @FailedModules>0 THEN 1 ELSE 0 END) AS [isPartial]
                , @ExecutedModules AS [executedModules]
                , @FailedModules AS [failedModules]
                , @PartialModules AS [partialModules]
                , @ToolHintergrundabfragenEinbeziehen AS [toolBackgroundQueriesIncluded]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
        );
        DECLARE @ModuleStatusJson nvarchar(max)=
        (
            SELECT [ResultName],[ModuleName],[StatusCode],[IsPartial],[ReturnedRowCount],[DurationMs],[ErrorMessage]
            FROM [#CurrentOverview_ModuleStatus]
            ORDER BY [ModuleOrdinal]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @WarningsJson nvarchar(max)=
        (
            SELECT [ModuleName],[StatusCode],[Message]
            FROM [#CurrentOverview_Warnings]
            ORDER BY [ModuleName]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @ChildProperties nvarchar(max)=
        (
            SELECT STRING_AGG
            (
                CONVERT(nvarchar(max),CONCAT(N'"',STRING_ESCAPE([ResultName],'json'),N'":',
                    CASE WHEN ISJSON([JsonValue])=1 THEN [JsonValue] ELSE N'null' END)),
                N','
            ) WITHIN GROUP (ORDER BY [ModuleOrdinal])
            FROM [#CurrentOverview_ModulePayload]
            WHERE [IsEnabled]=1
        );

        SET @Json=CONCAT
        (
              N'{"meta":',COALESCE(@MetaJson,N'{}')
            , N',"moduleStatus":',COALESCE(@ModuleStatusJson,N'[]')
            , CASE WHEN NULLIF(@ChildProperties,N'') IS NULL THEN N'' ELSE N','+@ChildProperties END
            , N',"warnings":',COALESCE(@WarningsJson,N'[]'),N'}'
        );
    END;

    IF @OutputMode='TABLE'
    BEGIN
        DECLARE @ExportResultName sysname;
        DECLARE @ExportTargetTable sysname;
        DECLARE @ExportSourceTable sysname;
        DECLARE @CanExport bit;

        DECLARE [ExportCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [ResultName],[TargetTable]
            FROM [#CurrentOverview_ResultTableMap]
            ORDER BY [ResultName];

        OPEN [ExportCursor];
        FETCH NEXT FROM [ExportCursor] INTO @ExportResultName,@ExportTargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SELECT
                  @ExportSourceTable=CASE
                      WHEN @ExportResultName=N'moduleStatus' THEN N'#CurrentOverview_ModuleStatus'
                      WHEN @ExportResultName=N'warnings' THEN N'#CurrentOverview_Warnings'
                      ELSE NULL END
                , @CanExport=CASE WHEN @ExportResultName IN (N'moduleStatus',N'warnings') THEN 1 ELSE 0 END;

            IF @ExportSourceTable IS NULL
                SELECT
                      @ExportSourceTable=[SourceTable]
                    , @CanExport=[IsMaterialized]
                FROM [#CurrentOverview_ModulePayload]
                WHERE [ResultName]=@ExportResultName;

            IF @CanExport=1
                EXEC [monitor].[InternalWriteResultTable]
                      @SourceTable=@ExportSourceTable
                    , @TargetTable=@ExportTargetTable
                    , @ThrowOnError=1;

            FETCH NEXT FROM [ExportCursor] INTO @ExportResultName,@ExportTargetTable;
        END;
        CLOSE [ExportCursor];
        DEALLOCATE [ExportCursor];
    END;
END;
GO

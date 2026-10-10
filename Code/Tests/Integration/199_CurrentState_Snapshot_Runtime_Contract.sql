USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 199_CurrentState_Snapshot_Runtime_Contract.sql
Zweck        : Prüft den vollständigen DIAG-004-Vertrag mit genau einem
               laufinternen Primär-Snapshot für alle acht Shared Consumer.
               Zusätzliche Sessions-only-Aufrufe prüfen den positiven
               Quellenzähler vor Childfilter und Ausgabelimit sowie getrennte
               Snapshot-Identitäten, ohne einen weiteren Owner anzulegen.
Daten        : Keine Fixture mit realen Namen oder Nutzdaten. Es werden nur
               flüchtige Systemmetadaten im aktuellen Testaufruf gelesen.
Nebenwirkung : Ausschließlich lokale Temp-Tabellen.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;

CREATE TABLE [#CurrentStateSnapshotRuntimeContract_SnapshotStatus]([Seed] bit NULL);

DECLARE @OverviewJson nvarchar(max);
EXEC [monitor].[USP_CurrentOverview]
      @MitSessions=1
    , @MitRequests=1
    , @MitBlocking=1
    , @MitWaits=1
    , @MitTransactions=1
    , @MitMemoryGrants=1
    , @MitTempDB=1
    , @MitIO=1
    , @MitLog=0
    , @MitSqlText=0
    , @GesamtenSqlTextEinbeziehen=0
    , @InputBufferEinbeziehen=0
    , @ModulInfoEinbeziehen=0
    , @MaxZeilen=20
    , @ResultSetArt='TABLE'
    , @ResultTablesJson=N'{"snapshotStatus":"#CurrentStateSnapshotRuntimeContract_SnapshotStatus"}'
    , @JsonErzeugen=1
    , @Json=@OverviewJson OUTPUT
    , @PrintMeldungen=0;

IF EXISTS
(
    SELECT [Expected].[SourceCode]
    FROM
    (
        VALUES
          ('SESSIONS'),('REQUESTS'),('CONNECTIONS'),('WAITING_TASKS')
        , ('MEMORY_GRANTS'),('RESOURCE_SEMAPHORES')
        , ('WORKLOAD_GROUPS'),('RESOURCE_POOLS')
        , ('TASKS'),('SCHEDULERS')
        , ('SESSION_TRANSACTIONS'),('ACTIVE_TRANSACTIONS')
        , ('DATABASE_TRANSACTIONS')
        , ('TEMPDB_SESSION_USAGE'),('TEMPDB_TASK_USAGE')
        , ('TRADITIONAL_VERSION_STORE'),('PERSISTENT_VERSION_STORE')
    ) AS [Expected]([SourceCode])
    EXCEPT
    SELECT [SourceCode]
    FROM [#CurrentStateSnapshotRuntimeContract_SnapshotStatus]
)
    THROW 52199,N'Mindestens eine angeforderte Primärquelle fehlt im snapshotStatus.',1;

IF EXISTS
(
    SELECT 1
    FROM [#CurrentStateSnapshotRuntimeContract_SnapshotStatus]
    WHERE [SnapshotId] IS NULL
       OR [CapturedAtUtc] IS NULL
       OR [CompletedAtUtc] IS NULL
       OR [CapturedRowCount] < 0
       OR [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','NOT_COLLECTED')
)
BEGIN
    DECLARE @SnapshotStatusDiagnostic nvarchar(2048)=
    (
        SELECT STUFF
        (
            (
                SELECT
                      N'; '+CONVERT(nvarchar(40),[s].[SourceCode])
                    + N'='+CONVERT(nvarchar(40),[s].[StatusCode])
                    + N'/'+COALESCE(CONVERT(nvarchar(20),[s].[ErrorNumber]),N'-')
                FROM [#CurrentStateSnapshotRuntimeContract_SnapshotStatus] AS [s]
                WHERE [s].[SnapshotId] IS NULL
                   OR [s].[CapturedAtUtc] IS NULL
                   OR [s].[CompletedAtUtc] IS NULL
                   OR [s].[CapturedRowCount] < 0
                   OR [s].[StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','NOT_COLLECTED')
                ORDER BY [s].[SourceOrdinal]
                FOR XML PATH(N''),TYPE
            ).value(N'.',N'nvarchar(1800)')
            ,1,2,N''
        )
    );
    SET @SnapshotStatusDiagnostic=CONCAT
    (
        N'snapshotStatus enthält einen ungültigen Zeit-, Mengen- oder Statuswert: '
      , COALESCE(@SnapshotStatusDiagnostic,N'UNBEKANNT')
    );
    THROW 52199,@SnapshotStatusDiagnostic,1;
END;

IF ISJSON(@OverviewJson)<>1
   OR JSON_QUERY(@OverviewJson,N'$.snapshotStatus') IS NULL
   OR JSON_VALUE(@OverviewJson,N'$.meta.statusCode') NOT IN ('AVAILABLE','AVAILABLE_LIMITED')
    THROW 52199,N'Der JSON-Vertrag enthält keinen gültigen Snapshotstatus.',1;

IF (SELECT COUNT(DISTINCT [SnapshotId]) FROM [#CurrentStateSnapshotRuntimeContract_SnapshotStatus])<>1
    THROW 52199,N'snapshotStatus enthält keine eindeutige Snapshot-ID.',1;

DECLARE @StatusTableJson nvarchar(max);
EXEC [sys].[sp_executesql]
    N'SELECT @pJson=(SELECT * FROM [#CurrentStateSnapshotRuntimeContract_SnapshotStatus] ORDER BY [SourceOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);',
    N'@pJson nvarchar(max) OUTPUT',@pJson=@StatusTableJson OUTPUT;
IF COALESCE(@StatusTableJson,N'[]') COLLATE Latin1_General_100_BIN2
    <> COALESCE(JSON_QUERY(@OverviewJson,N'$.snapshotStatus'),N'') COLLATE Latin1_General_100_BIN2
    THROW 52199,N'Die elf Snapshotstatusfelder stimmen zwischen TABLE und JSON nicht überein.',1;

IF NOT EXISTS
(
    SELECT 1 FROM [#CurrentStateSnapshotRuntimeContract_SnapshotStatus]
    WHERE [SourceCode]='SESSIONS'
      AND [CapturedRowCount]>=1
      AND [CapturedRowCount]>=(SELECT COUNT_BIG(*) FROM OPENJSON(@OverviewJson,N'$.sessions.sessions'))
)
    THROW 52199,N'Der SESSIONS-Quellenzähler ist kleiner als die materialisierte Consumer-Menge.',1;

DECLARE @StatusSnapshotId nvarchar(36)=
(
    SELECT TOP (1) CONVERT(nvarchar(36),[SnapshotId])
    FROM [#CurrentStateSnapshotRuntimeContract_SnapshotStatus]
);

DECLARE @SessionSnapshotId nvarchar(36)=
    JSON_VALUE(@OverviewJson,N'$.sessions.meta.evidenceSnapshotId');
DECLARE @RequestSnapshotId nvarchar(36)=
    JSON_VALUE(@OverviewJson,N'$.requests.meta.evidenceSnapshotId');
DECLARE @BlockingSnapshotId nvarchar(36)=
    JSON_VALUE(@OverviewJson,N'$.blocking.meta.evidenceSnapshotId');
DECLARE @WaitSnapshotId nvarchar(36)=
    JSON_VALUE(@OverviewJson,N'$.waits.meta.evidenceSnapshotId');
DECLARE @TransactionSnapshotId nvarchar(36)=
    JSON_VALUE(@OverviewJson,N'$.transactions.meta.evidenceSnapshotId');
DECLARE @MemoryGrantSnapshotId nvarchar(36)=
    JSON_VALUE(@OverviewJson,N'$.memoryGrants.meta.evidenceSnapshotId');
DECLARE @TempDbSnapshotId nvarchar(36)=
    JSON_VALUE(@OverviewJson,N'$.tempdbSessions.meta.evidenceSnapshotId');
DECLARE @IoSnapshotId nvarchar(36)=
    JSON_VALUE(@OverviewJson,N'$.io.meta.evidenceSnapshotId');

IF @StatusSnapshotId IS NULL
   OR @SessionSnapshotId IS NULL
   OR @RequestSnapshotId IS NULL
   OR @BlockingSnapshotId IS NULL
   OR @WaitSnapshotId IS NULL
   OR @TransactionSnapshotId IS NULL
   OR @MemoryGrantSnapshotId IS NULL
   OR @TempDbSnapshotId IS NULL
   OR @IoSnapshotId IS NULL
   OR @StatusSnapshotId<>@SessionSnapshotId
   OR @SessionSnapshotId<>@RequestSnapshotId
   OR @RequestSnapshotId<>@BlockingSnapshotId
   OR @BlockingSnapshotId<>@WaitSnapshotId
   OR @WaitSnapshotId<>@TransactionSnapshotId
   OR @TransactionSnapshotId<>@MemoryGrantSnapshotId
   OR @MemoryGrantSnapshotId<>@TempDbSnapshotId
   OR @TempDbSnapshotId<>@IoSnapshotId
    THROW 52199,N'Die acht Shared Consumer verwenden nicht dieselbe Snapshot-ID.',1;

DECLARE @OwnSessionList nvarchar(20)=CONVERT(nvarchar(20),@@SPID);
DECLARE @AllSourceCount int=(SELECT COUNT(*) FROM [#CurrentStateSnapshotRuntimeContract_SnapshotStatus]);
DECLARE @PreviousSnapshotId uniqueidentifier=TRY_CONVERT(uniqueidentifier,@StatusSnapshotId);
CREATE TABLE [#CurrentStateSnapshotRuntimeContract_Sessions0]([Seed] bit NULL);
CREATE TABLE [#CurrentStateSnapshotRuntimeContract_Sessions1]([Seed] bit NULL);
DECLARE @SessionOnlyStatus TABLE
(
      [SourceOrdinal] int NOT NULL
    , [SnapshotId] uniqueidentifier NOT NULL
    , [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [CapturedAtUtc] datetime2(3) NOT NULL
    , [CompletedAtUtc] datetime2(3) NOT NULL
    , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [IsPartial] bit NOT NULL
    , [CapturedRowCount] bigint NOT NULL
    , [ErrorNumber] int NULL
    , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
DECLARE @SessionOnlyCase int=0;
WHILE @SessionOnlyCase<2
BEGIN
    DELETE FROM @SessionOnlyStatus;
    DECLARE @SessionOnlyTarget sysname=CASE WHEN @SessionOnlyCase=0
        THEN N'#CurrentStateSnapshotRuntimeContract_Sessions0'
        ELSE N'#CurrentStateSnapshotRuntimeContract_Sessions1' END;
    DECLARE @SessionOnlyMapping nvarchar(max)=N'{"snapshotStatus":"'+@SessionOnlyTarget+N'"}';
    DECLARE @SessionOnlyLimit int=CASE WHEN @SessionOnlyCase=0 THEN 0 ELSE 1 END;
    DECLARE @SessionOnlyJson nvarchar(max);
    EXEC [monitor].[USP_CurrentOverview]
          @SessionIds=@OwnSessionList
        , @ToolHintergrundabfragenEinbeziehen=1
        , @MitSessions=1,@MitRequests=0,@MitBlocking=0,@MitWaits=0
        , @MitTransactions=0,@MitMemoryGrants=0,@MitTempDB=0,@MitIO=0,@MitLog=0
        , @MitSqlText=0,@GesamtenSqlTextEinbeziehen=0
        , @InputBufferEinbeziehen=0,@ModulInfoEinbeziehen=0
        , @MaxZeilen=@SessionOnlyLimit
        , @ResultSetArt='TABLE'
        , @ResultTablesJson=@SessionOnlyMapping
        , @JsonErzeugen=1,@Json=@SessionOnlyJson OUTPUT,@PrintMeldungen=0;

    SET @StatusTableJson=NULL;
    DECLARE @SessionOnlySql nvarchar(max)=N'SELECT @pJson=(SELECT * FROM '
        +QUOTENAME(@SessionOnlyTarget)+N' ORDER BY [SourceOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);';
    EXEC [sys].[sp_executesql] @SessionOnlySql,
        N'@pJson nvarchar(max) OUTPUT',@pJson=@StatusTableJson OUTPUT;
    IF COALESCE(@StatusTableJson,N'[]') COLLATE Latin1_General_100_BIN2
        <> COALESCE(JSON_QUERY(@SessionOnlyJson,N'$.snapshotStatus'),N'') COLLATE Latin1_General_100_BIN2
        THROW 52199,N'Die elf Sessions-only-Snapshotstatusfelder stimmen zwischen TABLE und JSON nicht überein.',1;
    INSERT @SessionOnlyStatus
    SELECT * FROM OPENJSON(@StatusTableJson) WITH
    (
          [SourceOrdinal] int '$.SourceOrdinal'
        , [SnapshotId] uniqueidentifier '$.SnapshotId'
        , [SourceCode] varchar(40) '$.SourceCode'
        , [SourceObject] nvarchar(256) '$.SourceObject'
        , [CapturedAtUtc] datetime2(3) '$.CapturedAtUtc'
        , [CompletedAtUtc] datetime2(3) '$.CompletedAtUtc'
        , [StatusCode] varchar(40) '$.StatusCode'
        , [IsPartial] bit '$.IsPartial'
        , [CapturedRowCount] bigint '$.CapturedRowCount'
        , [ErrorNumber] int '$.ErrorNumber'
        , [ErrorMessage] nvarchar(2048) '$.ErrorMessage'
    );

    IF ISJSON(@SessionOnlyJson)<>1
       OR JSON_VALUE(@SessionOnlyJson,N'$.meta.statusCode') NOT IN ('AVAILABLE','AVAILABLE_LIMITED')
       OR (SELECT COUNT(*) FROM @SessionOnlyStatus)<>3
       OR EXISTS
       (
           SELECT [SourceCode] FROM @SessionOnlyStatus
           EXCEPT SELECT [SourceCode] FROM (VALUES('SESSIONS'),('REQUESTS'),('CONNECTIONS')) AS [Expected]([SourceCode])
       )
       OR EXISTS
       (
           SELECT [SourceCode] FROM (VALUES('SESSIONS'),('REQUESTS'),('CONNECTIONS')) AS [Expected]([SourceCode])
           EXCEPT SELECT [SourceCode] FROM @SessionOnlyStatus
       )
        THROW 52199,N'Der Sessions-only-Aufruf enthält nicht genau seine drei angeforderten Primärquellen.',1;

    DECLARE @SessionOnlySnapshotId uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@SessionOnlyJson,N'$.meta.evidenceSnapshotId'));
    IF @SessionOnlySnapshotId IS NULL OR @SessionOnlySnapshotId=@PreviousSnapshotId
       OR EXISTS
       (
           SELECT 1 FROM @SessionOnlyStatus
           WHERE [SnapshotId]<>@SessionOnlySnapshotId
              OR [CapturedAtUtc] IS NULL OR [CompletedAtUtc] IS NULL
              OR [CompletedAtUtc]<[CapturedAtUtc] OR [CapturedRowCount]<0
              OR [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED')
       )
       OR JSON_VALUE(@SessionOnlyJson,N'$.sessions.meta.evidenceSnapshotId') IS NULL
       OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@SessionOnlyJson,N'$.sessions.meta.evidenceSnapshotId'))<>@SessionOnlySnapshotId
        THROW 52199,N'Die getrennten Overview-Aufrufe behalten keine eigenen gültigen Snapshot-Identitäten.',1;

    IF (SELECT COUNT(*) FROM OPENJSON(@SessionOnlyJson,N'$.sessions.sessions'))<>0
       OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@SessionOnlyJson,N'$.sessions.meta.returnedRows')),-1)<>0
       OR NOT EXISTS
       (
           SELECT 1 FROM @SessionOnlyStatus
           WHERE [SourceCode]='SESSIONS' AND [CapturedRowCount]>=1
             AND [SourceObject]=N'sys.dm_exec_sessions'
       )
        THROW 52199,N'Der Sessions-only-Aufruf verliert den positiven Quellenzähler oder schließt die aktuelle Session nicht aus.',1;
    SET @PreviousSnapshotId=@SessionOnlySnapshotId;
    SET @SessionOnlyCase+=1;
END;

DECLARE @InvalidSnapshotId uniqueidentifier=NEWID();
DECLARE @SessionJson nvarchar(max);
EXEC [monitor].[USP_CurrentSessions]
      @ParentCurrentStateSnapshotId=@InvalidSnapshotId
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@SessionJson OUTPUT
    , @PrintMeldungen=0;

IF JSON_VALUE(@SessionJson,N'$.meta.statusCode')<>'INVALID_PARENT_SNAPSHOT'
    THROW 52199,N'USP_CurrentSessions akzeptiert eine fremde Parent-Snapshot-ID.',1;

DECLARE @RequestJson nvarchar(max);
EXEC [monitor].[USP_CurrentRequests]
      @ParentCurrentStateSnapshotId=@InvalidSnapshotId
    , @MitSqlText=0
    , @ModulInfoEinbeziehen=0
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@RequestJson OUTPUT
    , @PrintMeldungen=0;

IF JSON_VALUE(@RequestJson,N'$.meta.statusCode')<>'INVALID_PARENT_SNAPSHOT'
    THROW 52199,N'USP_CurrentRequests akzeptiert eine fremde Parent-Snapshot-ID.',1;

DECLARE @BlockingJson nvarchar(max);
EXEC [monitor].[USP_CurrentBlocking]
      @ParentCurrentStateSnapshotId=@InvalidSnapshotId
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@BlockingJson OUTPUT
    , @PrintMeldungen=0;

IF JSON_VALUE(@BlockingJson,N'$.meta.statusCode')<>'INVALID_PARENT_SNAPSHOT'
    THROW 52199,N'USP_CurrentBlocking akzeptiert eine fremde Parent-Snapshot-ID.',1;

DECLARE @WaitJson nvarchar(max);
EXEC [monitor].[USP_CurrentWaits]
      @ParentCurrentStateSnapshotId=@InvalidSnapshotId
    , @SampleSeconds=0
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@WaitJson OUTPUT
    , @PrintMeldungen=0;

IF JSON_VALUE(@WaitJson,N'$.meta.statusCode')<>'INVALID_PARENT_SNAPSHOT'
    THROW 52199,N'USP_CurrentWaits akzeptiert eine fremde Parent-Snapshot-ID.',1;

DECLARE @TransactionJson nvarchar(max);
EXEC [monitor].[USP_CurrentTransactions]
      @ParentCurrentStateSnapshotId=@InvalidSnapshotId
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@TransactionJson OUTPUT
    , @PrintMeldungen=0;

IF JSON_VALUE(@TransactionJson,N'$.meta.statusCode')<>'INVALID_PARENT_SNAPSHOT'
    THROW 52199,N'USP_CurrentTransactions akzeptiert eine fremde Parent-Snapshot-ID.',1;

DECLARE @MemoryGrantJson nvarchar(max);
EXEC [monitor].[USP_CurrentMemoryGrants]
      @ParentCurrentStateSnapshotId=@InvalidSnapshotId
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@MemoryGrantJson OUTPUT
    , @PrintMeldungen=0;

IF JSON_VALUE(@MemoryGrantJson,N'$.meta.statusCode')<>'INVALID_PARENT_SNAPSHOT'
    THROW 52199,N'USP_CurrentMemoryGrants akzeptiert eine fremde Parent-Snapshot-ID.',1;

DECLARE @TempDbJson nvarchar(max);
EXEC [monitor].[USP_CurrentTempDB]
      @ParentCurrentStateSnapshotId=@InvalidSnapshotId
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@TempDbJson OUTPUT
    , @PrintMeldungen=0;

IF JSON_VALUE(@TempDbJson,N'$.meta.statusCode')<>'INVALID_PARENT_SNAPSHOT'
    THROW 52199,N'USP_CurrentTempDB akzeptiert eine fremde Parent-Snapshot-ID.',1;

DECLARE @IoJson nvarchar(max);
EXEC [monitor].[USP_CurrentIO]
      @ParentCurrentStateSnapshotId=@InvalidSnapshotId
    , @SampleSeconds=0
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@IoJson OUTPUT
    , @PrintMeldungen=0;

IF JSON_VALUE(@IoJson,N'$.meta.statusCode')<>'INVALID_PARENT_SNAPSHOT'
    THROW 52199,N'USP_CurrentIO akzeptiert eine fremde Parent-Snapshot-ID.',1;

SELECT
      CAST('AVAILABLE' AS varchar(40)) AS [StatusCode]
    , CAST(0 AS bit) AS [IsPartial]
    , @AllSourceCount AS [SnapshotSourceCount]
    , @SessionOnlyCase AS [SessionSourceCountCases]
    , N'Current-State-Primärsnapshot, Sessions-Quellenzähler und acht Consumer-Grenzen erfolgreich geprüft.' AS [Detail];
GO

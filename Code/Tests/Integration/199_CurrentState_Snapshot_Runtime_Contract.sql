USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 199_CurrentState_Snapshot_Runtime_Contract.sql
Zweck        : Prüft den ersten DIAG-004-Slice mit genau einem laufinternen
               Primär-Snapshot für CurrentSessions und CurrentRequests.
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
    , @MitBlocking=0
    , @MitWaits=0
    , @MitTransactions=0
    , @MitMemoryGrants=0
    , @MitTempDB=0
    , @MitIO=0
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
        , ('MEMORY_GRANTS'),('WORKLOAD_GROUPS'),('RESOURCE_POOLS')
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
       OR [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED')
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
                   OR [s].[StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED')
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

DECLARE @StatusSnapshotId nvarchar(36)=
(
    SELECT TOP (1) CONVERT(nvarchar(36),[SnapshotId])
    FROM [#CurrentStateSnapshotRuntimeContract_SnapshotStatus]
);

DECLARE @SessionSnapshotId nvarchar(36)=
    JSON_VALUE(@OverviewJson,N'$.sessions.meta.evidenceSnapshotId');
DECLARE @RequestSnapshotId nvarchar(36)=
    JSON_VALUE(@OverviewJson,N'$.requests.meta.evidenceSnapshotId');

IF @StatusSnapshotId IS NULL
   OR @SessionSnapshotId IS NULL
   OR @RequestSnapshotId IS NULL
   OR @StatusSnapshotId<>@SessionSnapshotId
   OR @SessionSnapshotId<>@RequestSnapshotId
    THROW 52199,N'Die primären Consumer verwenden nicht dieselbe Snapshot-ID.',1;

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

SELECT
      CAST('AVAILABLE' AS varchar(40)) AS [StatusCode]
    , CAST(0 AS bit) AS [IsPartial]
    , CONVERT(int,(SELECT COUNT(*) FROM [#CurrentStateSnapshotRuntimeContract_SnapshotStatus])) AS [SnapshotSourceCount]
    , N'Current-State-Primärsnapshot und Consumer-Grenze erfolgreich geprüft.' AS [Detail];
GO

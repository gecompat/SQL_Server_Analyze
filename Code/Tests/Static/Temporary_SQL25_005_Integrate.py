#!/usr/bin/env python3
from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def write(path: str, text: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8", newline="\n")


def replace_once(text: str, old: str, new: str, path: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected exactly one match, found {count}: {old[:120]!r}")
    return text.replace(old, new, 1)


def insert_before(text: str, marker: str, block: str, path: str) -> str:
    return replace_once(text, marker, block + marker, path)


def append_csv_rows(path: str, rows: list[list[str]], key_columns: tuple[int, ...]) -> None:
    target = ROOT / path
    with target.open(encoding="utf-8-sig", newline="") as handle:
        existing = list(csv.reader(handle))
    keys = {tuple(row[index] for index in key_columns) for row in existing[1:]}
    for row in rows:
        key = tuple(row[index] for index in key_columns)
        if key not in keys:
            existing.append(row)
            keys.add(key)
    with target.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerows(existing)


# -----------------------------------------------------------------------------
# Installer
# -----------------------------------------------------------------------------
path = "Code/Install/Install_All.sql"
text = read(path)
text = insert_before(text, ":r ../05_QueryStore/010_USP_QueryStoreStatus.sql\n", ":r ../05_QueryStore/005_TVF_QueryStoreReplicaRoleInfo.sql\n", path)
text = insert_before(text, ":r ../05_QueryStore/080_USP_QueryStoreAnalysis.sql\n", ":r ../05_QueryStore/100_USP_QueryStoreReplicaAnalysis.sql\n", path)
write(path, text)


# -----------------------------------------------------------------------------
# New procedure: framework CONSOLE contract
# -----------------------------------------------------------------------------
path = "Code/05_QueryStore/100_USP_QueryStoreReplicaAnalysis.sql"
text = read(path)
text = replace_once(
    text,
    "    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));\n",
    "    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));\n"
    "    DECLARE @ConsoleResultRequested bit=CONVERT(bit,CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END);\n"
    "    IF @ConsoleResultRequested=1 SET @OutputMode='NONE';\n",
    path,
)
start = text.index("    IF @OutputMode='RAW'\n")
console = text.index("    ELSE IF @OutputMode='CONSOLE'\n", start)
table = text.index("    ELSE IF @OutputMode='TABLE'\n", console)
raw_block = text[start:console]
raw_block = raw_block.replace("    IF @OutputMode='RAW'\n", "    ELSE IF @OutputMode='RAW'\n", 1)
console_renderer = (
    "    IF @ConsoleResultRequested=1\n"
    "    BEGIN\n"
    "        EXEC [monitor].[InternalEmitConsoleResult]\n"
    "              @SourceTable=N'#QueryStoreReplicaAnalysis_ModuleStatus'\n"
    "            , @ResultLabel=N'QueryStoreReplicaAnalysis'\n"
    "            , @EmptyMessage=N'Keine Query-Store-Replica-Evidenz im sichtbaren Scope';\n"
    "    END\n"
)
text = text[:start] + console_renderer + raw_block + text[table:]
write(path, text)


# -----------------------------------------------------------------------------
# Query Store orchestrator
# -----------------------------------------------------------------------------
path = "Code/05_QueryStore/080_USP_QueryStoreAnalysis.sql"
text = read(path)
text = text.replace("Version      : 2.1.0", "Version      : 2.2.0", 1)
text = text.replace("Stand        : 2026-07-17", "Stand        : 2026-07-27", 1)
text = text.replace(
    "Änderungen   : 2.1.0 - IQP-Evidenz als kostenbewusstes opt-in Teilmodul.",
    "Änderungen   : 2.2.0 - SQL25-005 Replica-Kontext als versionsadaptives Standardteilmodul.\n"
    "                2.1.0 - IQP-Evidenz als kostenbewusstes opt-in Teilmodul.",
    1,
)
text = replace_once(
    text,
    "    , @MitHints                         bit            = 0\n    , @MitIQP                           bit            = 0\n",
    "    , @MitHints                         bit            = 0\n    , @MitReplicaKontext                bit            = 1\n    , @MitIQP                           bit            = 0\n",
    path,
)
text = replace_once(
    text,
    "    DECLARE @HintsJson nvarchar(max);\n    DECLARE @IqpJson nvarchar(max);\n",
    "    DECLARE @HintsJson nvarchar(max);\n    DECLARE @ReplicaJson nvarchar(max);\n    DECLARE @ReplicaStatus varchar(40)=NULL;\n    DECLARE @ReplicaPartial bit=NULL;\n    DECLARE @ReplicaErrorNumber int=NULL;\n    DECLARE @ReplicaErrorMessage nvarchar(2048)=NULL;\n    DECLARE @IqpJson nvarchar(max);\n",
    path,
)
text = replace_once(
    text,
    "        PRINT N'@ResultSetArt = RAW, CONSOLE, TABLE oder NONE; optional JSON über @Json OUTPUT.';\n",
    "        PRINT N'@MitReplicaKontext=1 ergänzt SQL25-005 mit rollengetrennter Query-Store-Evidenz; vor SQL Server 2025 kontrolliert UNAVAILABLE_VERSION.';\n"
    "        PRINT N'@ResultSetArt = RAW, CONSOLE, TABLE oder NONE; optional JSON über @Json OUTPUT.';\n",
    path,
)
text = text.replace(
    "AND @MitForcedPlans = 0 AND @MitHints = 0 AND @MitIQP = 0)",
    "AND @MitForcedPlans = 0 AND @MitHints = 0 AND @MitReplicaKontext = 0 AND @MitIQP = 0)",
    1,
)
replica_block = """
    IF @StatusCode = 'AVAILABLE' AND @MitReplicaKontext = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_QueryStoreReplicaAnalysis]
                  @QueryStoreDatabaseNames = @QueryStoreDatabaseNames
                , @QueryStoreDatabaseNamePattern = @QueryStoreDatabaseNamePattern
                , @HighImpactConfirmed = @HighImpactConfirmed
                , @VonUtc = @VonUtc
                , @BisUtc = @BisUtc
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ReplicaJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ReplicaStatus OUTPUT
                , @IsPartialOut = @ReplicaPartial OUTPUT
                , @ErrorNumberOut = @ReplicaErrorNumber OUTPUT
                , @ErrorMessageOut = @ReplicaErrorMessage OUTPUT;

            INSERT @ModuleStatus VALUES
            (8, N'USP_QueryStoreReplicaAnalysis', COALESCE(@ReplicaStatus, 'ERROR_HANDLED'), @ReplicaErrorNumber, @ReplicaErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (8, N'USP_QueryStoreReplicaAnalysis', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

"""
text = insert_before(text, "    IF @StatusCode = 'AVAILABLE' AND @MitIQP = 1\n", replica_block, path)
text = text.replace("(8, N'USP_IntelligentQueryProcessingAnalysis'", "(9, N'USP_IntelligentQueryProcessingAnalysis'", 1)
text = text.replace("VALUES (8, N'USP_IntelligentQueryProcessingAnalysis'", "VALUES (9, N'USP_IntelligentQueryProcessingAnalysis'", 1)
for old, new in [
    ("NOT IN ('EXECUTED','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE')", "NOT IN ('EXECUTED','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE','UNAVAILABLE_VERSION','UNAVAILABLE_FEATURE','FEATURE_DISABLED')"),
]:
    text = text.replace(old, new)
text = replace_once(
    text,
    "            , N',\"queryHints\":', COALESCE(JSON_QUERY(@HintsJson), N'null')\n            , N',\"intelligentQueryProcessing\":', COALESCE(JSON_QUERY(@IqpJson), N'null')\n",
    "            , N',\"queryHints\":', COALESCE(JSON_QUERY(@HintsJson), N'null')\n"
    "            , N',\"replicaContext\":', COALESCE(JSON_QUERY(@ReplicaJson), N'null')\n"
    "            , N',\"intelligentQueryProcessing\":', COALESCE(JSON_QUERY(@IqpJson), N'null')\n",
    path,
)
write(path, text)


# -----------------------------------------------------------------------------
# Analysis catalog, search terms and relations
# -----------------------------------------------------------------------------
path = "Code/01_Common/021_VW_AnalysisCatalog.sql"
text = read(path)
row = "        , (N'USP_QueryStoreReplicaAnalysis',N'Query-Store-Evidenz nach Replica-Rolle','QUERY_STORE',N'Query Store und Regressionen','FOLLOW_UP','DATABASE','PERSISTED_HISTORY','LOW_MEDIUM','QUERY_STORE_CURRENT',1,0,0,'CORE',NULL,N'Trennt Runtime-, Wait- und Plan-Forcing-Evidenz nach Query-Store-Replica-Rolle und weist fehlende Rollenzuordnung explizit aus.',N'SQL Server 2025 und sichtbarer Query Store erforderlich; historische Rollen sind keine aktuelle AG-Healthaussage.',N'EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @QueryStoreDatabaseNames = N''[ExampleDatabase]'', @MaxZeilen = 100, @ResultSetArt = ''CONSOLE'';',N'Documentation/Analysis_Guides/Procedures/USP_QueryStoreReplicaAnalysis.md',NULL)\n"
text = insert_before(text, "        , (N'USP_QueryStoreStatus'", row, path)
write(path, text)

path = "Code/01_Common/022_VW_AnalysisSearchTerm.sql"
text = read(path)
terms = (
    "        , (N'USP_QueryStoreReplicaAnalysis',N'Query Store Secondary Replica Rolle','de',100,N'Trennt Query-Store-Laufzeit- und Wait-Evidenz nach beobachteter Replica-Rolle.')\n"
    "        , (N'USP_QueryStoreReplicaAnalysis',N'query store readable secondary replica role','en',100,N'Replica-aware Query Store runtime, waits and forcing context.')\n"
)
marker = "        , (N'USP_QueryStoreStatus'"
text = text.replace(marker, terms + marker, 1)
write(path, text)

path = "Code/01_Common/023_VW_AnalysisRelation.sql"
text = read(path)
relations = (
    "        , (N'USP_QueryStoreStatus','REFINE_WITH',N'USP_QueryStoreReplicaAnalysis',2,N'Ab SQL Server 2025 Query-Store-Zustand um beobachtete Primary-, Secondary- und Named-Replica-Evidenz ergänzen.')\n"
    "        , (N'USP_QueryStoreReplicaAnalysis','CONFIRM_WITH',N'USP_QueryStoreRuntimeStats',1,N'Rollengetrennte Aggregate gegen Query- und Plan-Details im gleichen Zeitraum prüfen.')\n"
    "        , (N'USP_QueryStoreReplicaAnalysis','CONFIRM_WITH',N'USP_QueryStoreWaitStats',2,N'Rollengetrennte Waitaggregate mit der querybezogenen Waitsicht abgleichen.')\n"
    "        , (N'USP_QueryStoreAnalysis','REFINE_WITH',N'USP_QueryStoreReplicaAnalysis',3,N'Bei SQL Server 2025 Query-Store-Evidenz nach beobachteter Replica-Rolle trennen.')\n"
)
text = text.replace("        , (N'USP_QueryStoreRuntimeStats'", relations + "        , (N'USP_QueryStoreRuntimeStats'", 1)
write(path, text)


# -----------------------------------------------------------------------------
# Framework version and count contracts
# -----------------------------------------------------------------------------
path = "Code/01_Common/077_FrameworkVersion.sql"
text = read(path)
text = text.replace("1.1.0-special.19", "1.1.0-special.20")
text = text.replace("Stand        : 2026-07-23", "Stand        : 2026-07-27", 1)
text = text.replace("[ReleaseDate]='20260723'", "[ReleaseDate]='20260727'")
text = text.replace("[ContractVersion]='1.23'", "[ContractVersion]='1.24'")
text = text.replace("N'API 1.23: SQL25-004 ergänzt Statistikdefinitionen um capability-adaptive Herkunfts- und Replikatmetadaten für lesbare Secondaries.'", "N'API 1.24: SQL25-005 ergänzt Query Store um capability-adaptive Replica-Rollen-, Runtime-, Wait- und Plan-Forcing-Evidenz.'")
text = text.replace("'20260723',15,\n        '1.23'", "'20260727',15,\n        '1.24'")
write(path, text)

path = "Code/Tests/Integration/110_Smoke_Test.sql"
text = read(path)
text = insert_before(text, "(N'monitor.USP_QueryStoreAnalysis','P'),\n", "(N'monitor.TVF_QueryStoreReplicaRoleInfo','IF'),\n(N'monitor.USP_QueryStoreReplicaAnalysis','P'),\n", path)
text = text.replace("'1.1.0-special.19'", "'1.1.0-special.20'")
text = text.replace("<> 98", "<> 99")
text = text.replace("alle 98 öffentlichen Procedures", "alle 99 öffentlichen Procedures")
write(path, text)

for path in [
    "Code/Tests/Integration/196_Analysis_Navigator_Runtime_Contract.sql",
    "Code/Tests/Static/905_Validate_Analysis_Navigator.py",
]:
    text = read(path)
    text = text.replace("98 öffentliche Procedures", "99 öffentliche Procedures")
    text = text.replace("expected 98", "expected 99")
    text = text.replace("<> 98", "<> 99")
    text = text.replace("!= 98", "!= 99")
    write(path, text)

path = "Code/Tests/Integration/189_Framework_Output_Runtime_Contract.sql"
text = read(path)
text = text.replace("<>93", "<>94")
text = text.replace("genau 93 Vertragsobjekte", "genau 94 Vertragsobjekte")
write(path, text)


# -----------------------------------------------------------------------------
# Runtime contract and release gate
# -----------------------------------------------------------------------------
runtime_test = r'''USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 121_SQL25_Replica_Query_Store_Runtime_Contract.sql
Zweck        : Prüft SQL25-005 versionsadaptiv, ohne Querytexte, Pläne,
               Replikatidentitäten oder Runtimepayloads zu persistieren.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

CREATE TABLE [#SQL25ReplicaQueryStore_Failure]
(
      [TestName] sysname NOT NULL
    , [Detail] nvarchar(2048) NOT NULL
);

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](1)
    WHERE [RoleTypeDesc]='PRIMARY' AND [RoleClass]='READ_WRITE_ROLE'
      AND [IsPrimaryRole]=1 AND [IsSecondaryRole]=0
)
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'ROLE_PRIMARY',N'role_type 1 wurde nicht als PRIMARY eingeordnet.');

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](2)
    WHERE [RoleTypeDesc]='SECONDARY' AND [RoleClass]='READ_ONLY_ROLE'
      AND [IsSecondaryRole]=1
)
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'ROLE_SECONDARY',N'role_type 2 wurde nicht als SECONDARY eingeordnet.');

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](5)
    WHERE [RoleTypeDesc]='NAMED_REPLICA' AND [IsNamedReplica]=1
)
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'ROLE_NAMED',N'role_type >= 5 wurde nicht als Named Replica eingeordnet.');

BEGIN TRY
    EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @Hilfe=1;
END TRY
BEGIN CATCH
    INSERT [#SQL25ReplicaQueryStore_Failure]
    VALUES(N'HELP',CONCAT(N'@Hilfe ist fehlgeschlagen: ',ERROR_NUMBER(),N'.'));
END CATCH;

DECLARE @Status varchar(40),@Partial bit,@ErrorNumber int,@ErrorMessage nvarchar(2048),@Json nvarchar(max);
EXEC [monitor].[USP_QueryStoreReplicaAnalysis]
      @MaxZeilen=-1
    , @ResultSetArt='NONE'
    , @PrintMeldungen=0
    , @StatusCodeOut=@Status OUTPUT
    , @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT
    , @ErrorMessageOut=@ErrorMessage OUTPUT;
IF @Status<>'INVALID_PARAMETER'
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'INVALID_PARAMETER',CONCAT(N'Erwartet INVALID_PARAMETER, erhalten ',COALESCE(@Status,N'NULL'),N'.'));

SET LOCK_TIMEOUT 731;
EXEC [monitor].[USP_QueryStoreReplicaAnalysis]
      @QueryStoreDatabaseNames=N'[DeineDatenbank]'
    , @MaxZeilen=5
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0
    , @StatusCodeOut=@Status OUTPUT
    , @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT
    , @ErrorMessageOut=@ErrorMessage OUTPUT;
IF @@LOCK_TIMEOUT<>731
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'LOCK_TIMEOUT',N'Der ursprüngliche LOCK_TIMEOUT wurde nicht restauriert.');
SET LOCK_TIMEOUT -1;

IF ISJSON(@Json)<>1
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'JSON_VALID',N'Die JSON-Ausgabe ist ungültig.');
IF JSON_QUERY(@Json,N'$.moduleStatus') IS NULL OR JSON_QUERY(@Json,N'$.replicas') IS NULL
   OR JSON_QUERY(@Json,N'$.runtimeByReplica') IS NULL OR JSON_QUERY(@Json,N'$.waitsByReplica') IS NULL
   OR JSON_QUERY(@Json,N'$.forcingByReplica') IS NULL OR JSON_QUERY(@Json,N'$.sourceStatus') IS NULL
   OR JSON_QUERY(@Json,N'$.warnings') IS NULL
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'JSON_SHAPE',N'Mindestens ein kanonisches JSON-Array fehlt.');

DECLARE @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
IF @Major<17 AND @Status<>'UNAVAILABLE_VERSION'
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'VERSION_GATE',CONCAT(N'Vor SQL Server 2025 wurde ',COALESCE(@Status,N'NULL'),N' statt UNAVAILABLE_VERSION geliefert.'));
IF @Major>=17 AND @Status NOT IN('AVAILABLE','AVAILABLE_LIMITED','NOT_APPLICABLE')
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'SQL2025_STATUS',CONCAT(N'Unerwarteter SQL-Server-2025-Status: ',COALESCE(@Status,N'NULL'),N'.'));

CREATE TABLE [#SQL25Replica_Module]([Seed] bit NULL);
CREATE TABLE [#SQL25Replica_Replicas]([Seed] bit NULL);
CREATE TABLE [#SQL25Replica_Runtime]([Seed] bit NULL);
CREATE TABLE [#SQL25Replica_Waits]([Seed] bit NULL);
CREATE TABLE [#SQL25Replica_Forcing]([Seed] bit NULL);
CREATE TABLE [#SQL25Replica_Sources]([Seed] bit NULL);
CREATE TABLE [#SQL25Replica_Warnings]([Seed] bit NULL);

BEGIN TRY
    EXEC [monitor].[USP_QueryStoreReplicaAnalysis]
          @QueryStoreDatabaseNames=N'[DeineDatenbank]'
        , @MaxZeilen=5
        , @ResultSetArt='TABLE'
        , @ResultTablesJson=N'{"moduleStatus":"#SQL25Replica_Module","replicas":"#SQL25Replica_Replicas","runtimeByReplica":"#SQL25Replica_Runtime","waitsByReplica":"#SQL25Replica_Waits","forcingByReplica":"#SQL25Replica_Forcing","sourceStatus":"#SQL25Replica_Sources","warnings":"#SQL25Replica_Warnings"}'
        , @PrintMeldungen=0;
END TRY
BEGIN CATCH
    INSERT [#SQL25ReplicaQueryStore_Failure]
    VALUES(N'TABLE_EXECUTION',CONCAT(N'TABLE ist fehlgeschlagen: ',ERROR_NUMBER(),N'.'));
END CATCH;

IF NOT EXISTS(SELECT 1 FROM [#SQL25Replica_Module])
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'TABLE_MODULE',N'moduleStatus wurde nicht geschrieben.');
IF NOT EXISTS(SELECT 1 FROM [#SQL25Replica_Sources] WHERE [SourceName]=N'replicaCatalog')
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'TABLE_SOURCES',N'replicaCatalog fehlt im sourceStatus.');
IF @Major<17 AND EXISTS
(
    SELECT 1 FROM [#SQL25Replica_Sources]
    WHERE [SourceName] IN(N'replicaCatalog',N'runtimeByReplica',N'waitsByReplica',N'forcingByReplica')
      AND [StatusCode]<>'UNAVAILABLE_VERSION'
)
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'PRE17_SOURCES',N'Eine versionsspezifische Quelle liefert vor SQL Server 2025 keinen UNAVAILABLE_VERSION-Status.');

DECLARE @Definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'monitor.USP_QueryStoreReplicaAnalysis'));
IF @Definition LIKE N'%query_sql_text%' OR @Definition LIKE N'%query_plan]%' OR @Definition LIKE N'%ALTER DATABASE%'
   OR @Definition LIKE N'%sp_query_store_force_plan%' OR @Definition LIKE N'%sp_query_store_set_hints%'
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'READ_ONLY_PRIVACY',N'Die Definition referenziert ausgeschlossene Payload- oder Mutationspfade.');
IF @Definition NOT LIKE N'%query_store_replicas%' OR @Definition NOT LIKE N'%replica_group_id%'
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'REPLICA_CONTRACT',N'Die Replica-Katalog- oder Gruppierungsreferenz fehlt.');

DECLARE @ParentJson nvarchar(max);
EXEC [monitor].[USP_QueryStoreAnalysis]
      @QueryStoreDatabaseNames=N'[DeineDatenbank]'
    , @MitStatus=0
    , @MitRuntimeStats=0
    , @MitReplicaKontext=1
    , @MaxZeilen=5
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@ParentJson OUTPUT
    , @PrintMeldungen=0;
IF ISJSON(@ParentJson)<>1 OR JSON_QUERY(@ParentJson,N'$.replicaContext') IS NULL
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'PARENT_JSON',N'Der Query-Store-Orchestrator enthält keinen gültigen replicaContext.');

IF EXISTS(SELECT 1 FROM [#SQL25ReplicaQueryStore_Failure])
BEGIN
    SELECT * FROM [#SQL25ReplicaQueryStore_Failure] ORDER BY [TestName];
    THROW 56905,N'SQL25-005 Replica Query Store Runtime Contract fehlgeschlagen.',1;
END;

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],CAST(0 AS bit) AS [IsPartial],
       N'SQL25_REPLICA_QUERY_STORE_RUNTIME_CONTRACT PASS' AS [Detail];
GO
'''
write("Code/Tests/QueryStore/121_SQL25_Replica_Query_Store_Runtime_Contract.sql", runtime_test)

path = "Code/Tests/Run_Release_Gate.sql"
text = read(path)
text = insert_before(text, "\nRAISERROR(N'RELEASE_GATE 32/34: Extended Events'", "\n:r QueryStore/121_SQL25_Replica_Query_Store_Runtime_Contract.sql\n", path)
write(path, text)

path = "Code/Tests/QueryStore/110_Test_und_Abnahme_Phase4.sql"
text = read(path)
if "USP_QueryStoreReplicaAnalysis" not in text:
    text += "\nEXEC [monitor].[USP_QueryStoreReplicaAnalysis] @Hilfe=1;\nGO\n"
write(path, text)


# -----------------------------------------------------------------------------
# Inventories
# -----------------------------------------------------------------------------
append_csv_rows(
    "Metadata/Inventory/Objects.csv",
    [
        ["FUNCTION","TVF_QueryStoreReplicaRoleInfo","Code/05_QueryStore/005_TVF_QueryStoreReplicaRoleInfo.sql"],
        ["PROCEDURE","USP_QueryStoreReplicaAnalysis","Code/05_QueryStore/100_USP_QueryStoreReplicaAnalysis.sql"],
    ],
    (0,1),
)

parameters = [
    ["USP_QueryStoreReplicaAnalysis","QueryStoreDatabaseNames","nvarchar(max)","NULL"],
    ["USP_QueryStoreReplicaAnalysis","QueryStoreDatabaseNamePattern","nvarchar(4000)","NULL"],
    ["USP_QueryStoreReplicaAnalysis","HighImpactConfirmed","bit","0"],
    ["USP_QueryStoreReplicaAnalysis","ReplicaGroupIds","nvarchar(max)","NULL"],
    ["USP_QueryStoreReplicaAnalysis","VonUtc","datetime2(7)","NULL"],
    ["USP_QueryStoreReplicaAnalysis","BisUtc","datetime2(7)","NULL"],
    ["USP_QueryStoreReplicaAnalysis","MaxZeilen","int","200"],
    ["USP_QueryStoreReplicaAnalysis","LockTimeoutMs","int","0"],
    ["USP_QueryStoreReplicaAnalysis","ResultSetArt","varchar(16)","'CONSOLE'"],
    ["USP_QueryStoreReplicaAnalysis","ResultTablesJson","nvarchar(max)","NULL"],
    ["USP_QueryStoreReplicaAnalysis","JsonErzeugen","bit","0"],
    ["USP_QueryStoreReplicaAnalysis","Json","nvarchar(max)","NULL OUTPUT"],
    ["USP_QueryStoreReplicaAnalysis","PrintMeldungen","bit","1"],
    ["USP_QueryStoreReplicaAnalysis","Hilfe","bit","0"],
    ["USP_QueryStoreReplicaAnalysis","StatusCodeOut","varchar(40)","NULL OUTPUT"],
    ["USP_QueryStoreReplicaAnalysis","IsPartialOut","bit","NULL OUTPUT"],
    ["USP_QueryStoreReplicaAnalysis","ErrorNumberOut","int","NULL OUTPUT"],
    ["USP_QueryStoreReplicaAnalysis","ErrorMessageOut","nvarchar(2048)","NULL OUTPUT"],
]
append_csv_rows("Metadata/Inventory/Parameters.csv", parameters, (0,1))

result_rows = [
    ["USP_QueryStoreReplicaAnalysis","moduleStatus","1","1","1","#QueryStoreReplicaAnalysis_ModuleStatus","1","[ModuleName] sysname NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [ProductMajorVersion] int NULL , [CrossDatabaseRequested] bit NOT NULL , [DatabaseCount] int NOT NULL , [ReplicaRowCount] bigint NOT NULL , [RuntimeRowCount] bigint NOT NULL , [WaitRowCount] bigint NOT NULL , [ForcingRowCount] bigint NOT NULL , [HasMoreReplicaRows] bit NOT NULL , [HasMoreRuntimeRows] bit NOT NULL , [HasMoreWaitRows] bit NOT NULL , [HasMoreForcingRows] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL","Keine Query-Store-Replica-Evidenz im sichtbaren Scope"],
    ["USP_QueryStoreReplicaAnalysis","replicas","0","1","1","#QueryStoreReplicaAnalysis_Replicas","1","[CapturedAtUtc] datetime2(3) NOT NULL , [DatabaseId] int NOT NULL , [DatabaseName] sysname NOT NULL , [CurrentQueryStoreStateDesc] nvarchar(60) NULL , [CurrentConnectionRoleDesc] varchar(40) NOT NULL , [ReplicaGroupId] bigint NOT NULL , [RoleType] tinyint NULL , [RoleTypeDesc] varchar(40) NOT NULL , [RoleClass] varchar(24) NOT NULL , [ReplicaName] nvarchar(4000) NULL , [IsPrimaryRole] bit NOT NULL , [IsSecondaryRole] bit NOT NULL , [IsNamedReplica] bit NOT NULL , [StatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL",""],
    ["USP_QueryStoreReplicaAnalysis","runtimeByReplica","0","1","1","#QueryStoreReplicaAnalysis_RuntimeByReplica","1","[CapturedAtUtc] datetime2(3) NOT NULL , [DatabaseId] int NOT NULL , [DatabaseName] sysname NOT NULL , [CurrentConnectionRoleDesc] varchar(40) NOT NULL , [ReplicaGroupId] bigint NULL , [RoleType] tinyint NULL , [RoleTypeDesc] varchar(40) NOT NULL , [RoleClass] varchar(24) NOT NULL , [ReplicaName] nvarchar(4000) NULL , [MappingStatusCode] varchar(40) NOT NULL , [RecordedRows] bigint NOT NULL , [QueryCount] bigint NOT NULL , [PlanCount] bigint NOT NULL , [ExecutionCount] bigint NOT NULL , [FirstExecutionTimeUtc] datetimeoffset NULL , [LastExecutionTimeUtc] datetimeoffset NULL , [TotalDurationMs] decimal(38,3) NULL , [TotalCpuMs] decimal(38,3) NULL , [TotalLogicalReads] decimal(38,3) NULL , [TotalLogicalWrites] decimal(38,3) NULL , [EvidenceLimit] nvarchar(1000) NOT NULL",""],
    ["USP_QueryStoreReplicaAnalysis","waitsByReplica","0","1","1","#QueryStoreReplicaAnalysis_WaitsByReplica","1","[CapturedAtUtc] datetime2(3) NOT NULL , [DatabaseId] int NOT NULL , [DatabaseName] sysname NOT NULL , [CurrentConnectionRoleDesc] varchar(40) NOT NULL , [ReplicaGroupId] bigint NULL , [RoleType] tinyint NULL , [RoleTypeDesc] varchar(40) NOT NULL , [RoleClass] varchar(24) NOT NULL , [ReplicaName] nvarchar(4000) NULL , [MappingStatusCode] varchar(40) NOT NULL , [ExecutionTypeDesc] nvarchar(128) NULL , [WaitCategory] tinyint NULL , [WaitCategoryDesc] nvarchar(128) NULL , [RecordedRows] bigint NOT NULL , [FirstIntervalStartUtc] datetimeoffset NULL , [LastIntervalEndUtc] datetimeoffset NULL , [TotalQueryWaitTimeMs] bigint NULL , [MaxQueryWaitTimeMs] bigint NULL , [EvidenceLimit] nvarchar(1000) NOT NULL",""],
    ["USP_QueryStoreReplicaAnalysis","forcingByReplica","0","1","1","#QueryStoreReplicaAnalysis_ForcingByReplica","1","[CapturedAtUtc] datetime2(3) NOT NULL , [DatabaseId] int NOT NULL , [DatabaseName] sysname NOT NULL , [CurrentConnectionRoleDesc] varchar(40) NOT NULL , [ReplicaGroupId] bigint NULL , [RoleType] tinyint NULL , [RoleTypeDesc] varchar(40) NOT NULL , [RoleClass] varchar(24) NOT NULL , [ReplicaName] nvarchar(4000) NULL , [MappingStatusCode] varchar(40) NOT NULL , [ForcingLocationCount] bigint NOT NULL , [ForcedQueryCount] bigint NOT NULL , [ForcedPlanCount] bigint NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL",""],
    ["USP_QueryStoreReplicaAnalysis","sourceStatus","0","1","1","#QueryStoreReplicaAnalysis_SourceStatus","1","[SourceOrdinal] int NOT NULL , [DatabaseId] int NULL , [DatabaseName] sysname NULL , [SourceName] sysname NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [ReturnedRowCount] bigint NOT NULL , [RequiredPermission] nvarchar(256) NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL , [EvidenceLimit] nvarchar(1000) NOT NULL",""],
    ["USP_QueryStoreReplicaAnalysis","warnings","0","1","1","#QueryStoreReplicaAnalysis_Warnings","1","[WarningOrdinal] int NOT NULL , [DatabaseName] sysname NULL , [SourceName] sysname NOT NULL , [StatusCode] varchar(40) NOT NULL , [ErrorNumber] int NULL , [Message] nvarchar(2048) NOT NULL",""],
]
append_csv_rows("Metadata/Inventory/ResultSets.csv", result_rows, (0,1))


# -----------------------------------------------------------------------------
# Documentation
# -----------------------------------------------------------------------------
procedure_page = r'''# [monitor].[USP_QueryStoreReplicaAnalysis]

`USP_QueryStoreReplicaAnalysis` trennt Query-Store-Runtime-, Wait- und
Plan-Forcing-Evidenz nach `replica_group_id` und ordnet sie den in
`sys.query_store_replicas` sichtbaren Rollen zu. Die Procedure ist auf SQL
Server 2019 und 2022 installierbar, referenziert dort aber keine
SQL-Server-2025-Kataloge und liefert kontrolliert `UNAVAILABLE_VERSION`.

## Eine Zeile bedeutet

Eine Zeile in `replicas` beschreibt eine vom Query Store beobachtete Rolle einer
Datenbank. Eine Zeile in `runtimeByReplica` beschreibt die über das gewählte
Zeitfenster aggregierten Runtimeintervalle einer `replica_group_id`.
`waitsByReplica` ergänzt Ausführungstyp und Waitkategorie.
`forcingByReplica` inventarisiert nur sichtbare Plan-Forcing-Locations.

## So lesen

1. Zuerst `moduleStatus` auf Version, Partialität und Ausgabegrenzen prüfen.
2. Danach `sourceStatus` je Datenbank und Quelle lesen.
3. `replicas` trennt beobachtete Rolle und aktuelle Verbindungsrolle.
4. `runtimeByReplica` und `waitsByReplica` nur innerhalb desselben Zeitfensters vergleichen.
5. `MappingStatusCode` prüfen, bevor eine Messung einer Rolle zugeschrieben wird.
6. `EvidenceLimit` bei jeder Interpretation mitlesen.

Mehrere beobachtete Rollen können nach Failover korrekt sein. Die aktuelle
Verbindungsrolle und die historische Query-Store-Rolle sind bewusst getrennt.

## Warum kann das problematisch sein?

Ohne Trennung nach Replica-Rolle können Laufzeit- oder Waitaggregate aus
Primary-, Secondary- und Named-Replica-Ausführungen vermischt werden. Dadurch
kann eine Verschiebung des Read-Workloads wie eine allgemeine Queryregression
erscheinen. Eine fehlende Rollenzuordnung kann außerdem zu falschen
Healthaussagen führen, wenn Messwerte stillschweigend dem Primary zugeschrieben
werden.

## Wann ist es kein Problem?

Unterschiedliche Laufzeitwerte zwischen Primary und Secondary sind nicht
automatisch ein Fehler. Hardware, Cachezustand, Parallelität, Datenbewegung,
Read-Intent-Routing und zeitlich unterschiedlicher Workload können die Werte
legitim unterscheiden. Eine beobachtete frühere Rolle nach Failover ist
ebenfalls kein aktueller Störungsnachweis.

## Sicherer Einstieg

```sql
DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_QueryStoreReplicaAnalysis]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = DATEADD(HOUR,-1,SYSUTCDATETIME())
    , @BisUtc = SYSUTCDATETIME()
    , @MaxZeilen = 100
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT;

SELECT @Json AS [QueryStoreReplicaAnalysisJson];
```

`@ReplicaGroupIds` kann eine numerische Pipe-, Beistrich- oder
Strichpunktliste enthalten. `@MaxZeilen = 0` bedeutet unbegrenzt und ist für den
Ersteinstieg nicht empfohlen.

## Technische Vertiefung

### Leitfrage

Welche Query-Store-Evidenz wurde auf welcher beobachteten Replica-Rolle
erfasst, und ist die Zuordnung vollständig genug für einen Rollenvergleich?

### Technischer Hintergrund

SQL Server 2025 ergänzt die Query-Store-Runtime- und Waitquellen um
`replica_group_id`. `sys.query_store_replicas` ordnet diese Gruppen beobachteten
Rollen zu. `sys.query_store_plan_forcing_locations` hält replica-spezifische
Forcing-Locations. Die Procedure liest keine Querytexte, Plan-XMLs oder
Hint-Payloads.

### Datenkette

Je Zieldatenbank werden zuerst Product Major Version, Query-Store-Zustand,
Systemobjekte und Pflichtspalten geprüft. Erst danach werden die
versionsspezifischen Quellen dynamisch referenziert. Jede Quelle wird höchstens
einmal pro Datenbank gelesen und lokal materialisiert. Runtimewerte werden mit
`count_executions` gewichtet; Waitwerte bleiben nach Ausführungstyp und
Waitkategorie getrennt.

### Source Select

```sql
SELECT
      [rs].[replica_group_id]
    , SUM([rs].[count_executions]) AS [ExecutionCount]
    , SUM(CONVERT(float,[rs].[avg_cpu_time])*[rs].[count_executions]) AS [CpuWeighted]
FROM [sys].[query_store_runtime_stats] AS [rs]
JOIN [sys].[query_store_runtime_stats_interval] AS [i]
  ON [i].[runtime_stats_interval_id]=[rs].[runtime_stats_interval_id]
WHERE [i].[end_time]>@VonUtc
  AND [i].[start_time]<@BisUtc
GROUP BY [rs].[replica_group_id];
```

**Wichtig für die Eigenlast:** Datenbank- und Zeitfilter werden vor der
Aggregation angewendet. `@MaxZeilen` begrenzt die Ausgabe; breite Zeitfenster
und viele Datenbanken erhöhen CPU und I/O des Query-Store-Katalogzugriffs.

### Zeit- und Scope-Modell

`CapturedAtUtc` ist der aufrufweite Erfassungszeitpunkt. Runtime- und Waitwerte
stammen aus Query-Store-Intervallen innerhalb von `@VonUtc` und `@BisUtc`.
`replicas` ist sichtbarer Katalogzustand zum Lesezeitpunkt. Die Quellen bilden
keine transaktional atomare Momentaufnahme.

### Bewertung und Gegenprobe

Rollenunterschiede zuerst mit Ausführungszahl, Zeitraum, Routing und
`USP_QueryStoreRuntimeStats` gegenprüfen. Bei Planwechseln oder Regressionen
anschließend `USP_QueryStorePlanChanges` beziehungsweise
`USP_QueryStoreRegressions` verwenden. Aktuelle AG-Synchronität und Routing
werden separat über die Availability-Group-Analysen geprüft.

### Typische Fehlinterpretation

`SECONDARY` bedeutet nicht, dass die aktuelle Verbindung gerade auf einer
Secondary läuft. Es ist die beobachtete Rolle der gespeicherten
Query-Store-Evidenz. `REPLICA_METADATA_MISSING` bedeutet ebenfalls nicht, dass
die Messung ungültig ist; nur die Rollenzuschreibung bleibt unvollständig.

### Folgeanalyse

`USP_QueryStoreRuntimeStats` liefert Query- und Plandetails im gleichen
Zeitfenster. `USP_QueryStoreWaitStats` vertieft Waitkategorien.
`USP_AvailabilityGroups` und `USP_AvailabilityDeepAnalysis` ergänzen aktuelle
Replica-, Routing- und Datenbewegungsevidenz.

## Primärquellen

- [sys.query_store_replicas](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-replicas?view=sql-server-ver17)
- [Query Store for secondary replicas](https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-for-secondary-replicas?view=sql-server-ver17)
- [sys.query_store_runtime_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql?view=sql-server-ver17)
- [sys.query_store_wait_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-wait-stats-transact-sql?view=sql-server-ver17)
- [sys.query_store_plan_forcing_locations](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-plan-forcing-locations-transact-sql?view=sql-server-ver17)

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)
'''
write("Documentation/Analysis_Guides/Procedures/USP_QueryStoreReplicaAnalysis.md", procedure_page)

path = "Documentation/Analysis_Guides/Procedures/README.md"
text = read(path)
text = text.replace("Strukturelle Abdeckung:** 98 Procedures", "Strukturelle Abdeckung:** 99 Procedures")
text = insert_before(text, "- [USP_QueryStoreStatus]", "- [USP_QueryStoreReplicaAnalysis](USP_QueryStoreReplicaAnalysis.md)\n", path)
write(path, text)

for path in ["Documentation/README.md", "Documentation/Analysis_Guides/Object_Index.md"]:
    text = read(path)
    text = text.replace("98 öffentlichen Procedures", "99 öffentlichen Procedures")
    text = text.replace("98 öffentliche Procedures", "99 öffentliche Procedures")
    text = text.replace("98 Procedures", "99 Procedures")
    text = text.replace("166 Objekte", "168 Objekte")
    text = text.replace("27 Table-Valued Functions", "28 Table-Valued Functions")
    if path.endswith("Object_Index.md") and "USP_QueryStoreReplicaAnalysis" not in text:
        text += "\n- [USP_QueryStoreReplicaAnalysis](Procedures/USP_QueryStoreReplicaAnalysis.md) – Query-Store-Evidenz nach beobachteter Replica-Rolle.\n"
    write(path, text)

path = "Documentation/Analysis_Guides/05_Query_Store.md"
text = read(path)
if "USP_QueryStoreReplicaAnalysis" not in text:
    text += """

## Replica-aware Query Store ab SQL Server 2025

`USP_QueryStoreReplicaAnalysis` trennt Runtime-, Wait- und Plan-Forcing-Evidenz
nach `replica_group_id`. Der Query-Store-Orchestrator aktiviert diesen Kontext
standardmäßig. Vor SQL Server 2025 liefert das Modul kontrolliert
`UNAVAILABLE_VERSION`, ohne neuere Kataloge zu referenzieren. Historische
Query-Store-Rollen sind von der aktuellen AG-Rolle und von Health- oder
Synchronitätsaussagen zu trennen.
"""
write(path, text)

path = "Documentation/Reference/Procedure_Reference.md"
text = read(path)
if "## `[monitor].[USP_QueryStoreReplicaAnalysis]`" not in text:
    text += r'''

## `[monitor].[USP_QueryStoreReplicaAnalysis]`

Quelle: `Code/05_QueryStore/100_USP_QueryStoreReplicaAnalysis.sql`

```sql
@QueryStoreDatabaseNames          nvarchar(max)  = NULL
    , @QueryStoreDatabaseNamePattern    nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @ReplicaGroupIds                  nvarchar(max)  = NULL
    , @VonUtc                           datetime2(7)   = NULL
    , @BisUtc                           datetime2(7)   = NULL
    , @MaxZeilen                        int            = 200
    , @LockTimeoutMs                    int            = 0
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @ResultTablesJson                 nvarchar(max)  = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
    , @StatusCodeOut                    varchar(40)    = NULL OUTPUT
    , @IsPartialOut                     bit            = NULL OUTPUT
    , @ErrorNumberOut                   int            = NULL OUTPUT
    , @ErrorMessageOut                  nvarchar(2048) = NULL OUTPUT
```
'''
text = text.replace("Stand: 2026-07-23", "Stand: 2026-07-27", 1)
write(path, text)


# -----------------------------------------------------------------------------
# Maturity, status and backlog
# -----------------------------------------------------------------------------
append_csv_rows(
    "Metadata/Inventory/Module_Maturity.csv",
    [["Secondary Replica Query Store","USP_QueryStoreReplicaAnalysis","COMPLETE","YES","YES","YES","","FULL","SQL25-005 mit versionsadaptiver Replica-Rollen-, Runtime-, Wait- und Forcing-Evidenz"]],
    (0,1),
)

path = "Metadata/Quality/Implementation_Status.csv"
text = read(path)
old = "SQL25-005,RESEARCHED_NOT_IMPLEMENTED,Replica-aware Query Store scope and acceptance boundaries researched,Implementation against sys.query_store_replicas plus primary secondary disabled unsupported denied partial cleanup and three-version evidence,AI_Metadata/Internal_Documentation/Architecture/Operational_Diagnostic_Gap_Backlog.md"
new = "SQL25-005,IMPLEMENTED_ACTIONS_GATE,Capability-adaptive Query Store replica catalog runtime wait and plan-forcing evidence with explicit role mapping missing-metadata partial version and false-positive boundaries,,Documentation/Analysis_Guides/Procedures/USP_QueryStoreReplicaAnalysis.md"
text = replace_once(text, old, new, path)
write(path, text)

path = "Metadata/Quality/Future_Enhancement_Backlog.csv"
text = read(path)
old = 'SQL25-005,P2,Secondary replica Query Store,"Make Query Store analyses replica-aware instead of detecting sys.query_store_replicas only as a capability",Query Store modules|sys.query_store_replicas,MEDIUM,RESEARCHED_NOT_IMPLEMENTED,"Primary secondary disabled unsupported cleanup denied and partial replica evidence cases"'
new = 'SQL25-005,P2,Secondary replica Query Store,"Make Query Store analyses replica-aware instead of detecting sys.query_store_replicas only as a capability",USP_QueryStoreReplicaAnalysis|USP_QueryStoreAnalysis|sys.query_store_replicas|sys.query_store_runtime_stats|sys.query_store_wait_stats|sys.query_store_plan_forcing_locations,MEDIUM,IMPLEMENTED_ACTIONS_GATE,"2019 2022 unavailable-version; 2025 primary secondary named missing-metadata empty disabled unsupported denied partial JSON TABLE orchestrator and lock-timeout cases"'
text = replace_once(text, old, new, path)
write(path, text)

path = "AI_Metadata/Internal_Documentation/Architecture/Operational_Diagnostic_Gap_Backlog.md"
text = read(path)
text = text.replace("Status: `PARTIALLY_IMPLEMENTED` – `OPS-001` bis `OPS-004` sowie `SQL25-001` bis `SQL25-004` sind `IMPLEMENTED_ACTIONS_GATE`", "Status: `PARTIALLY_IMPLEMENTED` – `OPS-001` bis `OPS-004` sowie `SQL25-001` bis `SQL25-005` sind `IMPLEMENTED_ACTIONS_GATE`")
text = text.replace("| `SQL25-005` | P2 | Query Store auf Secondary Replicas | Query-Store-Module replica-aware machen | fehlende Replica-Evidenz nicht als gesunden Zustand behandeln |", "| `SQL25-005` | P2 | Query Store auf Secondary Replicas | implementiert: `monitor.USP_QueryStoreReplicaAnalysis` und Orchestratorintegration | fehlende Replica-Evidenz nicht als gesunden Zustand behandeln |")
text = text.replace("### SQL25-005 – Replica-aware Query Store\n\nQuery-Store-Auswertungen sollen `sys.query_store_replicas` fachlich verwenden,\nstatt dessen Existenz nur als Capability zu erkennen. Primary-, Secondary- und\nunvollständige Evidenz dürfen nicht vermischt werden.", "### SQL25-005 – Replica-aware Query Store\n\n`monitor.USP_QueryStoreReplicaAnalysis` verwendet `sys.query_store_replicas`, die Replica-Spalten der Runtime- und Waitquellen sowie `sys.query_store_plan_forcing_locations` capability-adaptiv. Der Orchestrator aktiviert den Replica-Kontext standardmäßig. Primary-, Secondary-, Geo- und Named-Replica-Rollen bleiben getrennt; fehlende Metadaten erzeugen einen Partialstatus statt einer stillen Primary-Zuschreibung. Querytexte, Pläne und Mutationen sind ausgeschlossen.")
text = text.replace("3. Offen: `SQL25-005`.\n4. `OPS-005`, `OPS-006` und `OPS-008`.\n5. `OPS-007` und `OPS-009`", "3. Abgeschlossen: `SQL25-005`.\n4. Offen: `OPS-005`, `OPS-006` und `OPS-008`.\n5. `OPS-007` und `OPS-009`")
write(path, text)

path = "AI_Metadata/Internal_Documentation/Quality/Next_Steps.md"
text = read(path)
text = text.replace("### Priorität 1 – SQL25-005\n\nQuery-Store-Auswertungen sollen replica-aware werden und `sys.query_store_replicas` nicht nur als Capability erkennen. Erforderlich sind getrennte Primary-, Secondary-, deaktivierte, nicht unterstützte, eingeschränkt sichtbare und partielle Evidenzpfade.\n\n### Priorität 2 – zusätzliche Betriebsdiagnosen", "### Abgeschlossen – SQL25-005\n\n`USP_QueryStoreReplicaAnalysis` und der Query-Store-Orchestrator trennen SQL-Server-2025-Runtime-, Wait- und Plan-Forcing-Evidenz nach beobachteter Replica-Rolle. SQL Server 2019 und 2022 liefern versionssicher `UNAVAILABLE_VERSION`.\n\n### Priorität 1 – zusätzliche Betriebsdiagnosen")
text = text.replace("### Priorität 3 – SSIS-001", "### Priorität 2 – SSIS-001")
text = text.replace("1. `SQL25-005` implementieren und dreiversionig testen.\n2. `ANALYZE-LAB-001`", "1. `ANALYZE-LAB-001`")
text = text.replace("3. RUNTIME-001-", "2. RUNTIME-001-")
text = text.replace("4. `OPS-005`", "3. `OPS-005`")
text = text.replace("5. SSIS-001", "4. SSIS-001")
text = text.replace("6. `COLL-001`", "5. `COLL-001`")
text = text.replace("7. P3-Erweiterungen", "6. P3-Erweiterungen")
write(path, text)

path = "Documentation/Architecture/Implementation_Status_Model.md"
text = read(path)
text = text.replace("SQL25-001 bis SQL25-004", "SQL25-001 bis SQL25-005")
if "SQL25-005 ergänzt" not in text:
    text += "\nSQL25-005 ergänzt den Query-Store-Orchestrator um eine eigenständige, versionsadaptive Replica-Analyse. Rollen-, Runtime-, Wait- und Plan-Forcing-Evidenz werden nach `replica_group_id` getrennt, ohne Querytexte oder Planpayloads zu lesen.\n"
write(path, text)

path = "Metadata/Quality/Analysis_Documentation_Review.csv"
with (ROOT / path).open(encoding="utf-8-sig", newline="") as handle:
    rows = list(csv.reader(handle))
header = rows[0]
if not any(row and row[0]=="USP_QueryStoreReplicaAnalysis" for row in rows[1:]):
    template = next(row for row in rows[1:] if row[0]=="USP_VectorIndexAnalysis")
    row = template.copy()
    row[0] = "USP_QueryStoreReplicaAnalysis"
    if len(row)>1:
        row[1] = "Documentation/Analysis_Guides/Procedures/USP_QueryStoreReplicaAnalysis.md"
    rows.append(row)
with (ROOT / path).open("w", encoding="utf-8", newline="") as handle:
    csv.writer(handle, lineterminator="\n").writerows(rows)

print("SQL25-005 integration files updated")

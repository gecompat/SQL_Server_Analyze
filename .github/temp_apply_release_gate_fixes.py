from pathlib import Path
import re


def replace_once(path_name: str, old: str, new: str) -> None:
    path = Path(path_name)
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path_name}: expected one anchor, found {count}: {old[:120]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8", newline="\n")


for path_name in (
    "Code/01_Common/060_VW_FrameworkFeatureCatalog.sql",
    "Code/01_Common/070_USP_CheckFrameworkCapabilities.sql",
):
    path = Path(path_name)
    text = path.read_text(encoding="utf-8")
    text = text.replace(
        "Definitionen. $(DATABASE) wird in der Prüf-USP mit QUOTENAME ersetzt.",
        "Definitionen. Der Datenbank-Platzhalter wird in der Prüf-USP mit QUOTENAME ersetzt.",
    )
    text = text.replace("$(DATABASENAME)", "' + N'$' + N'(DATABASENAME)")
    text = text.replace("$(DATABASE)", "' + N'$' + N'(DATABASE)")
    path.write_text(text, encoding="utf-8", newline="\n")

remaining = []
token = re.compile(r"\$\([A-Za-z_][A-Za-z0-9_]*\)")
for path in Path("Code").rglob("*.sql"):
    if token.search(path.read_text(encoding="utf-8")):
        remaining.append(path.as_posix())
if remaining:
    raise RuntimeError(f"Unescaped SQLCMD-style runtime placeholders remain: {remaining!r}")

raiserror_targets = (
    ("Code/08_ServerHealth/110_USP_DatabaseIntegrityAnalysis.sql", "USP_DatabaseIntegrityAnalysis"),
    ("Code/08_ServerHealth/120_USP_DatabaseCapacityAnalysis.sql", "USP_DatabaseCapacityAnalysis"),
    ("Code/08_ServerHealth/130_USP_PerformanceCounters.sql", "USP_PerformanceCounters"),
    ("Code/08_ServerHealth/140_USP_CriticalEngineEvents.sql", "USP_CriticalEngineEvents"),
)
for path_name, procedure_name in raiserror_targets:
    replace_once(
        path_name,
        "    DECLARE @ErrorMessage nvarchar(2048) = NULL;\n",
        "    DECLARE @ErrorMessage nvarchar(2048) = NULL;\n    DECLARE @MonitorPrintMessage nvarchar(2048) = NULL;\n",
    )
    replace_once(
        path_name,
        "    IF @PrintMeldungen = 1 AND @StatusCode <> 'AVAILABLE'\n"
        f"        RAISERROR(N'{procedure_name}: %s', 10, 1, COALESCE(@ErrorMessage, @StatusCode)) WITH NOWAIT;\n",
        "    IF @PrintMeldungen = 1 AND @StatusCode <> 'AVAILABLE'\n"
        "    BEGIN\n"
        "        SET @MonitorPrintMessage = COALESCE(@ErrorMessage, CONVERT(nvarchar(2048), @StatusCode));\n"
        f"        RAISERROR(N'{procedure_name}: %s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;\n"
        "    END;\n",
    )

replace_once(
    "Code/09_VersionAdaptive/040_USP_TemporalAnalysis.sql",
    "           AND [f].[Severity]='WARN') THEN 'REVIEW' ELSE 'AVAILABLE' END;\n\n    UPDATE [ds]",
    "           AND [f].[Severity]='WARN') THEN 'REVIEW' ELSE 'AVAILABLE' END\n    FROM [#TemporalTable] AS [tt];\n\n    UPDATE [ds]",
)

replace_once(
    "Code/Tests/Integration/165_Filter_Output_Contract.sql",
    "FROM [monitor].[TVF_ParseFullObjectNameList](N'[DeineDatenbank].[dbo].[A|B]|[dbo].[C]')",
    "FROM [monitor].[TVF_ParseFullObjectNameList](N'[ExampleDatabase].[dbo].[A|B]|[dbo].[C]')",
)
replace_once(
    "Code/Tests/Integration/165_Filter_Output_Contract.sql",
    "WHERE [ItemOrdinal]=1 AND [DatabaseName]=N'DeineDatenbank' AND [SchemaName]=N'dbo' AND [ObjectName]=N'A|B' AND [IsValid]=1",
    "WHERE [ItemOrdinal]=1 AND [DatabaseName]=N'ExampleDatabase' AND [SchemaName]=N'dbo' AND [ObjectName]=N'A|B' AND [IsValid]=1",
)

replace_once(
    "Code/Tests/Integration/167_Special_Case_API_Contract.sql",
    """IF @TemporalDefinition NOT LIKE N'%[[]sys[]].[[]periods[]]%'
 OR @TemporalDefinition NOT LIKE N'%[[]history_table_id[]]%'
 OR @TemporalDefinition NOT LIKE N'%[[]dm_db_partition_stats[]]%'
    THROW 54107,N'Die Temporal-Tables-Analyse besitzt nicht alle erwarteten read-only Metadatenquellen.',1;
""",
    """DECLARE @MissingTemporalSources nvarchar(2048)=NULL;
IF CHARINDEX(N'[sys].[periods]',@TemporalDefinition COLLATE SQL_Latin1_General_CP1_CS_AS)=0
    SET @MissingTemporalSources=N'sys.periods';
IF CHARINDEX(N'[history_table_id]',@TemporalDefinition COLLATE SQL_Latin1_General_CP1_CS_AS)=0
    SET @MissingTemporalSources=CONCAT_WS(N', ',@MissingTemporalSources,N'history_table_id');
IF CHARINDEX(N'[sys].[dm_db_partition_stats]',@TemporalDefinition COLLATE SQL_Latin1_General_CP1_CS_AS)=0
    SET @MissingTemporalSources=CONCAT_WS(N', ',@MissingTemporalSources,N'sys.dm_db_partition_stats');
IF @MissingTemporalSources IS NOT NULL
BEGIN
    DECLARE @TemporalSourceMessage nvarchar(2048)=CONCAT(N'Die Temporal-Tables-Analyse besitzt nicht alle erwarteten read-only Metadatenquellen: ',@MissingTemporalSources,N'.');
    THROW 54107,@TemporalSourceMessage,1;
END;
""",
)
replace_once(
    "Code/Tests/Integration/167_Special_Case_API_Contract.sql",
    """IF @BrokerDefinition NOT LIKE N'%[[]sys[]].[[]service_queues[]]%'
 OR @BrokerDefinition NOT LIKE N'%[[]sys[]].[[]transmission_queue[]]%'
 OR @BrokerDefinition NOT LIKE N'%[[]sys[]].[[]conversation_endpoints[]]%'
 OR @BrokerDefinition NOT LIKE N'%[[]sys[]].[[]dm_broker_queue_monitors[]]%'
    THROW 54110,N'Die Service-Broker-Analyse besitzt nicht alle erwarteten read-only Metadatenquellen.',1;
""",
    """DECLARE @MissingBrokerSources nvarchar(2048)=NULL;
IF CHARINDEX(N'[sys].[service_queues]',@BrokerDefinition COLLATE SQL_Latin1_General_CP1_CS_AS)=0
    SET @MissingBrokerSources=N'sys.service_queues';
IF CHARINDEX(N'[sys].[transmission_queue]',@BrokerDefinition COLLATE SQL_Latin1_General_CP1_CS_AS)=0
    SET @MissingBrokerSources=CONCAT_WS(N', ',@MissingBrokerSources,N'sys.transmission_queue');
IF CHARINDEX(N'[sys].[conversation_endpoints]',@BrokerDefinition COLLATE SQL_Latin1_General_CP1_CS_AS)=0
    SET @MissingBrokerSources=CONCAT_WS(N', ',@MissingBrokerSources,N'sys.conversation_endpoints');
IF CHARINDEX(N'[sys].[dm_broker_queue_monitors]',@BrokerDefinition COLLATE SQL_Latin1_General_CP1_CS_AS)=0
    SET @MissingBrokerSources=CONCAT_WS(N', ',@MissingBrokerSources,N'sys.dm_broker_queue_monitors');
IF @MissingBrokerSources IS NOT NULL
BEGIN
    DECLARE @BrokerSourceMessage nvarchar(2048)=CONCAT(N'Die Service-Broker-Analyse besitzt nicht alle erwarteten read-only Metadatenquellen: ',@MissingBrokerSources,N'.');
    THROW 54110,@BrokerSourceMessage,1;
END;
""",
)

runner = Path("Code/Tests/Run_Release_Gate.sql")
runner_text = runner.read_text(encoding="utf-8")
runner_text, count = re.subn(
    r"PRINT N'(RELEASE_GATE [^']+)';",
    r"RAISERROR(N'\1',10,1) WITH NOWAIT;",
    runner_text,
)
if count != 12:
    raise RuntimeError(f"Expected 12 release-gate progress messages, changed {count}.")
runner.write_text(runner_text, encoding="utf-8", newline="\n")

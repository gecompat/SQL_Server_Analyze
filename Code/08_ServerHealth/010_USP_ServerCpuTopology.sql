USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ServerCpuTopology
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Liefert die CPU-, Scheduler- und NUMA-Topologie mit der
               momentanen Schedulerlast.
Datenquellen : sys.dm_os_sys_info, sys.dm_os_schedulers, sys.dm_os_nodes
Vertrag      : Resultset 1 ist immer Modulstatus; @ResultSetArt=NONE unterdrückt Resultsets; RAW und CONSOLE liefern unterschiedliche Projektionen. Optional JSON.
===============================================================================
*/

CREATE OR ALTER PROCEDURE [monitor].[USP_ServerCpuTopology]
 @PrintMeldungen bit=1,@Hilfe bit=0,@ResultSetArt varchar(16)='CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen bit=0,@Json nvarchar(max)=NULL OUTPUT,
 @StatusCodeOut varchar(40)=NULL OUTPUT,@IsPartialOut bit=NULL OUTPUT,@ErrorNumberOut int=NULL OUTPUT,@ErrorMessageOut nvarchar(2048)=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON;SET @Json=NULL;DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'cpuTopology',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE'; IF @Hilfe=1 BEGIN PRINT N'monitor.USP_ServerCpuTopology: Server-Health-Snapshot; read-only, nicht atomar.';
        PRINT N'Parameter: @PrintMeldungen bit=1 gibt Meldungen aus (0 unterdrückt sie); @Hilfe bit=0 (0/1) druckt bei 1 diese Hilfe vor den Quellen. Bei TABLE läuft der Ziel-Preflight vorher. @ResultSetArt varchar(16)=CONSOLE: CONSOLE, RAW, TABLE oder NONE; Groß-/Kleinschreibung wird normalisiert.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL ist für TABLE erforderlich; außerhalb von TABLE sind nur NULL oder leere Werte zulässig. Der unten genannte Ergebnisname muss auf eine vorhandene, leere lokale #temp-Tabelle mit genau einer Platzhalterspalte (z.B. Seed bit NULL) zeigen; kein fertiges Ausgabeschema voranlegen.';
        PRINT N'@JsonErzeugen bit=0 (0/1) erzeugt bei 1 das JSON-Dokument in @Json nvarchar(max)=NULL OUTPUT. @StatusCodeOut varchar(40)=NULL liefert den Modulstatus, @IsPartialOut bit=NULL die Teilstatuskennzeichnung, @ErrorNumberOut int=NULL die Quellfehlernummer und @ErrorMessageOut nvarchar(2048)=NULL den Fehlertext; alle sind OUTPUT.';
        PRINT N'Ausgabe: RAW liefert drei Fachergebnissets; CONSOLE zeigt die CPU-Topologie; TABLE exportiert nur cpuTopology; JSON enthält die drei Arrays. JSON-Schlüssel: cpuTopology, schedulers, numaNodes; Modulstatus beschreibt Verfügbarkeit/Fehler.';
        PRINT N'Quelle und Umfang: CPU-, Scheduler- und NUMA-Topologie samt momentaner Schedulerlast aus sys.dm_os_sys_info, sys.dm_os_schedulers und sys.dm_os_nodes. Kleine, ungefilterte Server-Snapshots ohne Zeilenlimit; Schedulerzeilen mit scheduler_id >= 1048576 und ONLINE DAC-Nodes sind ausgeschlossen.';
        PRINT N'Rechte und Plattform: Sichtbarkeit der SQL-Server-DMVs richtet sich nach Engineversion und Berechtigungen; Quellfehler können DENIED_PERMISSION/TIMEOUT oder Teilstatus ergeben. Momentaufnahme, keine Workload- oder Trenddiagnose.';
        PRINT N'Beispiel: EXEC [monitor].[USP_ServerCpuTopology] @ResultSetArt=''CONSOLE'';';
        PRINT N'TABLE-Beispiel (nur bei Bedarf): CREATE TABLE [#ServerCpuTopology_HelpExample]([Seed] bit NULL); EXEC [monitor].[USP_ServerCpuTopology] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"cpuTopology":"#ServerCpuTopology_HelpExample"}''; DROP TABLE [#ServerCpuTopology_HelpExample];';RETURN;END;
 DECLARE @T datetime2(3)=SYSUTCDATETIME(),@S varchar(40)='AVAILABLE',@P bit=0,@E int=NULL,@M nvarchar(2048)=NULL;
 IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') SELECT @S='INVALID_PARAMETER',@P=1,@M=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
 CREATE TABLE [#ServerCpuTopology_I]([cpu_count] int,[scheduler_count] int,[hyperthread_ratio] int,[socket_count] int,[cores_per_socket] int,[numa_node_count] int,[softnuma_configuration_desc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[sqlserver_start_time] datetime,[affinity_type_desc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS);
 CREATE TABLE [#ServerCpuTopology_Sch]([parent_node_id] int,[status] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[SchedulerCount] bigint,[VisibleOnlineSchedulers] bigint,[OnlineSchedulers] bigint,[CurrentTasks] bigint,[RunnableTasks] bigint,[ActiveWorkers] bigint,[LoadFactor] bigint,[Finding] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS);
 CREATE TABLE [#ServerCpuTopology_N]([node_id] int,[node_state_desc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[memory_node_id] int,[online_scheduler_count] int,[idle_scheduler_count] int,[active_worker_count] int,[avg_load_balance] bigint);
 SET LOCK_TIMEOUT 0;
 BEGIN TRY
  INSERT [#ServerCpuTopology_I] SELECT [cpu_count],[scheduler_count],[hyperthread_ratio],[socket_count],[cores_per_socket],[numa_node_count],[softnuma_configuration_desc],[sqlserver_start_time],[affinity_type_desc] FROM [sys].[dm_os_sys_info] WITH (NOLOCK);
  INSERT [#ServerCpuTopology_Sch] SELECT [parent_node_id],[status],COUNT_BIG(*),SUM(CONVERT(bigint,CASE WHEN [status]='VISIBLE ONLINE' THEN 1 ELSE 0 END)),SUM(CONVERT(bigint,[is_online])),SUM(CONVERT(bigint,[current_tasks_count])),SUM(CONVERT(bigint,[runnable_tasks_count])),SUM(CONVERT(bigint,[active_workers_count])),SUM(CONVERT(bigint,[load_factor])),
   CASE WHEN SUM([runnable_tasks_count])>0 THEN 'RUNNABLE_TASKS_PRESENT' WHEN SUM(CASE WHEN [status]='VISIBLE ONLINE' THEN 1 ELSE 0 END)=0 THEN 'NO_VISIBLE_SCHEDULER' ELSE 'OK_SNAPSHOT' END
  FROM [sys].[dm_os_schedulers] WITH (NOLOCK) WHERE [scheduler_id]<1048576 GROUP BY [parent_node_id],[status];
  INSERT [#ServerCpuTopology_N] SELECT [node_id],[node_state_desc],[memory_node_id],[online_scheduler_count],[idle_scheduler_count],[active_worker_count],[avg_load_balance] FROM [sys].[dm_os_nodes] WITH (NOLOCK) WHERE [node_state_desc]<>'ONLINE DAC';
 END TRY BEGIN CATCH SELECT @S=CASE WHEN ERROR_NUMBER() IN(229,297,300,371) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,@P=1,@E=ERROR_NUMBER(),@M=ERROR_MESSAGE(); END CATCH;
  SELECT @StatusCodeOut=@S,@IsPartialOut=@P,@ErrorNumberOut=@E,@ErrorMessageOut=@M;
 IF @PrintMeldungen=1 AND @S<>'AVAILABLE' RAISERROR(N'USP_ServerCpuTopology: %s',10,1,@M) WITH NOWAIT;
 IF @ResultSetArtNormalisiert<>'NONE' BEGIN SELECT CAST('2.0' AS varchar(16)) [ContractVersion],@T [CollectionTimeUtc],N'monitor.USP_ServerCpuTopology' [ModuleName],@S [StatusCode],@P [IsPartial],@E [ErrorNumber],@M [ErrorMessage];IF @ResultSetArtNormalisiert='RAW' BEGIN SELECT * FROM [#ServerCpuTopology_I] ;SELECT * FROM [#ServerCpuTopology_Sch] ORDER BY [parent_node_id],[status];SELECT * FROM [#ServerCpuTopology_N] ORDER BY [node_id]; END ELSE BEGIN SELECT N'cpuTopology' [Ergebnis],[x].* FROM [#ServerCpuTopology_I] [x] ;SELECT N'schedulers' [Ergebnis],[x].* FROM [#ServerCpuTopology_Sch] [x] ORDER BY [parent_node_id],[status];SELECT N'numaNodes' [Ergebnis],[x].* FROM [#ServerCpuTopology_N] [x] ORDER BY [node_id]; END;END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'ServerCpuTopology' [resultName],1 [schemaVersion],@T [generatedAtUtc],@S [statusCode],@P [isPartial],@E [errorNumber],@M [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@J0 nvarchar(max)=(SELECT * FROM [#ServerCpuTopology_I]  FOR JSON PATH,INCLUDE_NULL_VALUES),@J1 nvarchar(max)=(SELECT * FROM [#ServerCpuTopology_Sch] ORDER BY [parent_node_id],[status] FOR JSON PATH,INCLUDE_NULL_VALUES),@J2 nvarchar(max)=(SELECT * FROM [#ServerCpuTopology_N] ORDER BY [node_id] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"cpuTopology":',COALESCE(@J0,N'[]'),N',"schedulers":',COALESCE(@J1,N'[]'),N',"numaNodes":',COALESCE(@J2,N'[]'),N',"warnings":[]}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ServerCpuTopology_I'
            , @ResultLabel=N'ServerCpuTopology'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ServerCpuTopology_I'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

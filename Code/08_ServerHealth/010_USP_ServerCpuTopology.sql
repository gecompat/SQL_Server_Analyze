USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ServerCpuTopology
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Die Procedure liefert CPU-, Scheduler- und NUMA-Topologie
               einschließlich der momentanen Schedulerlast.
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
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE'; IF @Hilfe=1 BEGIN PRINT N'monitor.USP_ServerCpuTopology';
        PRINT N'Server-Health-Momentaufnahme; read-only und nicht atomar.';
        PRINT N'Parameter: @PrintMeldungen schaltet Statusmeldungen; @Hilfe druckt diese Hilfe nach TABLE-Preflight und vor Quellzugriff. @ResultSetArt akzeptiert CONSOLE, RAW, TABLE oder NONE (trim/UPPER).';
        PRINT N'@ResultTablesJson ordnet für TABLE genau cpuTopology einer leeren lokalen #temp-Zieltabelle mit einer Seed-Spalte zu; sonst nur NULL/Leerwert. @JsonErzeugen steuert unabhängig davon das JSON in @Json.';
        PRINT N'RAW und eine ungültige ResultSetArt liefern zuerst Modulstatus (ContractVersion, CollectionTimeUtc, ModuleName, StatusCode, IsPartial, ErrorNumber, ErrorMessage); CONSOLE/TABLE verwenden ihre Ausgabehelper und liefern kein separates Statusresultset. JSON enthält meta mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage, danach `cpuTopology`, `schedulers`, `numaNodes` sowie warnings als leeres Array.';
        PRINT N'Status und Quellumfang: CPU-, Scheduler- und NUMA-Topologie einschließlich Scheduler-Snapshots. DMVs bleiben abhängig von Engineversion, Sichtbarkeit und Berechtigungen; Quellfehler werden klassifiziert. Snapshot ohne Workload-/Trenddiagnose.';
        PRINT N'@PrintMeldungen bit; Default: 1. Bei 1 (auch Default) wird bei einem Status ungleich AVAILABLE eine Meldung niedriger Severity mit dem Fehlertext ausgegeben; 0 unterdrückt sie. NULL löst die IF-Bedingung ebenfalls nicht aus. Die Meldung erfolgt nach Befüllung der OUTPUT-Parameter und vor den Resultsets. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1.';
        PRINT N'@Hilfe bit; Default: 0. 0 oder NULL nimmt den normalen Analysepfad. 1 gibt die PRINT-Hilfe aus und kehrt vor Quellzugriff, regulärer Statusinitialisierung und allen vier Status-/Fehler-OUTPUT-Zuweisungen zurück. Zuvor laufen ein angeforderter TABLE-Preflight oder die Ablehnung eines nicht leeren TABLE-Mappings außerhalb TABLE; diese können bereits werfen. @Json ist beim Eintritt auf NULL gesetzt. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Trim von U+0020-Leerzeichen und UPPER gelten CONSOLE, RAW, TABLE und NONE; NULL wird wie leer behandelt. CONSOLE gibt nur die Console-Helferausgabe der ersten Fachquelle aus, ohne separates Modulstatusresultset; eine Leerzeile des Helfers hat hier NULL für Status und Hinweis. RAW gibt Modulstatus und unbeschriftete Fachresultsets aus. TABLE schreibt ausschließlich die benannte Fachmenge in das gemappte Ziel und gibt kein separates Modulstatusresultset aus. NONE unterdrückt Resultsets. CONSOLE und TABLE werden vor dem regulären Ausgabezweig intern zu NONE. Andere Texte, leer und NULL ergeben INVALID_PARAMETER/IsPartial=1; der nicht normalisierte ungültige Modus gibt dennoch Modulstatus und beschriftete Fachresultsets des ELSE-Zweigs aus. JSON ist davon unabhängig.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Als TABLE-Eingabe ist ein JSON-Objekt mit genau einem Mapping für den registrierten Namen cpuTopology auf eine vorhandene, leere lokale #temp-Tabelle nötig; diese muss genau eine Seed-/Platzhalterspalte besitzen. Das Ziel wird vor Hilfe und Quellerhebung geprüft; fehlerhafte oder fehlende TABLE-Ziele werfen beim Preflight Fehler 51011, daher werden Status-OUTPUTs nicht regulär gesetzt. Außerhalb von TABLE sind nur NULL, leer oder Leerzeichen erlaubt; jeder andere Inhalt wirft Fehler 51011 vor Hilfe und OUTPUT-Zuweisung.';
        PRINT N'@JsonErzeugen bit; Default: 0. Im normalen Pfad erzeugt 1 unabhängig von @ResultSetArt das JSON-Dokument in @Json; 0 oder NULL erzeugt keines. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück. Leere Fachmengen werden als leere Arrays ausgegeben. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Empfänger für das JSON-Dokument; bei Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Bindung erfolgt optional mit @Json=@Empfaenger OUTPUT; die Empfängervariable muss nvarchar(max) sein. Ohne OUTPUT-Bindung wird kein Rückgabewert an eine Aufrufervariable übertragen.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für AVAILABLE, INVALID_PARAMETER, DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED. AVAILABLE bedeutet kein abgefangener Quellfehler und keine festgestellte ungültige Eingabe; INVALID_PARAMETER bezeichnet ungültige ResultSetArt; DENIED_PERMISSION klassifiziert Quellfehler 229, 297, 300 oder 371; TIMEOUT klassifiziert Fehler 1222; ERROR_HANDLED steht für sonstige im Quell-TRY abgefangene Fehler. Bei Quellfehlern ist IsPartial=1. Bindung z.B. @StatusCodeOut=@Status OUTPUT mit varchar(40)-Variable. Zuweisung geschieht nach Quellversuch/Validierung, vor Meldung und Resultsetausgabe; bei frühem Preflight-THROW oder Hilfe keine reguläre Zuweisung. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER und bei abgefangenen Quellfehlern. Das Bit bezeichnet den implementierten Status-/Fehlerpfad, nicht Vollständigkeit einzelner leerer Quellgruppen. Bindung z.B. @IsPartialOut=@Partial OUTPUT mit bit-Variable; Zuweisung gemeinsam mit StatusCodeOut vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für die SQL-Fehlernummer eines im Quell-TRY abgefangenen Fehlers; bei AVAILABLE und INVALID_PARAMETER bleibt der Wert NULL. Die bekannten Berechtigungs-/Timeoutnummern werden zugleich klassifiziert. Bindung z.B. @ErrorNumberOut=@ErrorNumber OUTPUT mit int-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für den Text des im Quell-TRY abgefangenen Fehlers oder die konkrete INVALID_PARAMETER-Begründung; bei AVAILABLE bleibt er NULL. Bindung z.B. @ErrorMessageOut=@ErrorMessage OUTPUT mit nvarchar(2048)-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.';
        PRINT N'EXEC [monitor].[USP_ServerCpuTopology] @ResultSetArt=N''CONSOLE'';';
        PRINT N'EXEC [monitor].[USP_ServerCpuTopology] @ResultSetArt=N''RAW'';';
        PRINT N'EXEC [monitor].[USP_ServerCpuTopology] @JsonErzeugen=1,@ResultSetArt=N''NONE'';';
        PRINT N'CREATE TABLE [#ServerCpuTopology_HelpExample]([Seed] bit NULL); EXEC [monitor].[USP_ServerCpuTopology] @ResultSetArt=N''TABLE'',@ResultTablesJson=N''{"cpuTopology":"#ServerCpuTopology_HelpExample"}''; DROP TABLE [#ServerCpuTopology_HelpExample];';
        PRINT N'EXEC [monitor].[USP_ServerCpuTopology] @Hilfe=1;';







        RETURN;END;
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

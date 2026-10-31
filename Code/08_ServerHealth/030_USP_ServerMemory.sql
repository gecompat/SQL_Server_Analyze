USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ServerMemory
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Die Procedure liefert Angaben zu Betriebssystem-, Prozess-
               und SQL-Speicher, Memory Model, Clerks und Grants.
Datenquellen : sys.dm_os_sys_memory, sys.dm_os_process_memory, sys.dm_os_sys_info, sys.configurations, sys.dm_os_memory_clerks, sys.dm_exec_query_memory_grants
Vertrag      : Resultset 1 ist immer Modulstatus; @ResultSetArt=NONE unterdrückt Resultsets; RAW und CONSOLE liefern unterschiedliche Projektionen. Optional JSON.
===============================================================================
*/

CREATE OR ALTER PROCEDURE [monitor].[USP_ServerMemory]
 @MaxZeilen int=100,@PrintMeldungen bit=1,@Hilfe bit=0,@ResultSetArt varchar(16)='CONSOLE'
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
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'summary',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;IF @Hilfe=1
 BEGIN
        PRINT N'monitor.USP_ServerMemory';
        PRINT N'Server-Health-Momentaufnahme; read-only und nicht atomar.';
        PRINT N'Parameter: @PrintMeldungen schaltet Statusmeldungen; @Hilfe druckt diese Hilfe nach TABLE-Preflight und vor Quellzugriff. @ResultSetArt akzeptiert CONSOLE, RAW, TABLE oder NONE (trim/UPPER).';
        PRINT N'@ResultTablesJson ordnet für TABLE genau summary einer leeren lokalen #temp-Zieltabelle mit einer Seed-Spalte zu; sonst nur NULL/Leerwert. @JsonErzeugen steuert unabhängig davon das JSON in @Json.';
        PRINT N'RAW und eine ungültige ResultSetArt liefern zuerst Modulstatus (ContractVersion, CollectionTimeUtc, ModuleName, StatusCode, IsPartial, ErrorNumber, ErrorMessage); CONSOLE/TABLE verwenden ihre Ausgabehelper und liefern kein separates Statusresultset. JSON enthält meta mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage, danach `summary`, `memoryClerks`, `memoryGrants` sowie warnings als leeres Array.';
        PRINT N'Status und Quellumfang: OS-, SQL-Prozess-, SQL-Memory-Manager-, Clerk- und Query-Grant-Snapshots. DMVs bleiben abhängig von Engineversion, Sichtbarkeit und Berechtigungen; Quellfehler werden klassifiziert. Snapshot ohne Workload-/Trenddiagnose.';
        PRINT N'@MaxZeilen int; Default: 100. int-Eingabe: NULL oder 0 bedeutet unbegrenzt; positive Werte von 1 bis 2147483647 begrenzen die ausgewählten Clerk-Typgruppen. Die TOP-Mitgliedschaft wird nach absteigender Summe aus pages_kb und virtual_memory_committed_kb gewählt; die materialisierten Clerk-Zeilen werden anschließend nach pages_kb DESC ausgegeben beziehungsweise im JSON geordnet. TOP folgt auf den vollständigen Scan und GROUP BY von sys.dm_os_memory_clerks und begrenzt daher weder Scan noch Aggregationsaufwand. Summary und Grants bleiben ungekürzt. Negative Werte setzen INVALID_PARAMETER/IsPartial=1 und überspringen sämtliche Quellabfragen; Hilfe kehrt vor dieser Prüfung zurück.';
        PRINT N'@PrintMeldungen bit; Default: 1. Bei 1 (auch Default) wird bei einem Status ungleich AVAILABLE eine Meldung niedriger Severity mit dem Fehlertext ausgegeben; 0 unterdrückt sie. NULL löst die IF-Bedingung ebenfalls nicht aus. Die Meldung erfolgt nach Befüllung der OUTPUT-Parameter und vor den Resultsets. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1.';
        PRINT N'@Hilfe bit; Default: 0. 0 oder NULL nimmt den normalen Analysepfad. 1 gibt die PRINT-Hilfe aus und kehrt vor Quellzugriff, regulärer Statusinitialisierung und allen vier Status-/Fehler-OUTPUT-Zuweisungen zurück. Zuvor laufen ein angeforderter TABLE-Preflight oder die Ablehnung eines nicht leeren TABLE-Mappings außerhalb TABLE; diese können bereits werfen. @Json ist beim Eintritt auf NULL gesetzt. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Trim von U+0020-Leerzeichen und UPPER gelten CONSOLE, RAW, TABLE und NONE; NULL wird wie leer behandelt. CONSOLE gibt nur die Console-Helferausgabe der ersten Fachquelle aus, ohne separates Modulstatusresultset; eine Leerzeile des Helfers hat hier NULL für Status und Hinweis. RAW gibt Modulstatus und unbeschriftete Fachresultsets aus. TABLE schreibt ausschließlich die benannte Fachmenge in das gemappte Ziel und gibt kein separates Modulstatusresultset aus. NONE unterdrückt Resultsets. CONSOLE und TABLE werden vor dem regulären Ausgabezweig intern zu NONE. Andere Texte, leer und NULL ergeben INVALID_PARAMETER/IsPartial=1; der nicht normalisierte ungültige Modus gibt dennoch Modulstatus und beschriftete Fachresultsets des ELSE-Zweigs aus. JSON ist davon unabhängig.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Als TABLE-Eingabe ist ein JSON-Objekt mit genau einem Mapping für den registrierten Namen summary auf eine vorhandene, leere lokale #temp-Tabelle nötig; diese muss genau eine Seed-/Platzhalterspalte besitzen. Das Ziel wird vor Hilfe und Quellerhebung geprüft; fehlerhafte oder fehlende TABLE-Ziele werfen beim Preflight Fehler 51011, daher werden Status-OUTPUTs nicht regulär gesetzt. Außerhalb von TABLE sind nur NULL, leer oder Leerzeichen erlaubt; jeder andere Inhalt wirft Fehler 51011 vor Hilfe und OUTPUT-Zuweisung.';
        PRINT N'@JsonErzeugen bit; Default: 0. Im normalen Pfad erzeugt 1 unabhängig von @ResultSetArt das JSON-Dokument in @Json; 0 oder NULL erzeugt keines. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück. Leere Fachmengen werden als leere Arrays ausgegeben. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Empfänger für das JSON-Dokument; bei Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Bindung erfolgt optional mit @Json=@Empfaenger OUTPUT; die Empfängervariable muss nvarchar(max) sein. Ohne OUTPUT-Bindung wird kein Rückgabewert an eine Aufrufervariable übertragen.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für AVAILABLE, INVALID_PARAMETER, DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED. AVAILABLE bedeutet kein abgefangener Quellfehler und keine festgestellte ungültige Eingabe; INVALID_PARAMETER bezeichnet ungültige ResultSetArt oder negatives @MaxZeilen; DENIED_PERMISSION klassifiziert Quellfehler 229, 297, 300 oder 371; TIMEOUT klassifiziert Fehler 1222; ERROR_HANDLED steht für sonstige im Quell-TRY abgefangene Fehler. Bei Quellfehlern ist IsPartial=1. Bindung z.B. @StatusCodeOut=@Status OUTPUT mit varchar(40)-Variable. Zuweisung geschieht nach Quellversuch/Validierung, vor Meldung und Resultsetausgabe; bei frühem Preflight-THROW oder Hilfe keine reguläre Zuweisung. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER und bei abgefangenen Quellfehlern. Das Bit bezeichnet den implementierten Status-/Fehlerpfad, nicht Vollständigkeit einzelner leerer Quellgruppen. Bindung z.B. @IsPartialOut=@Partial OUTPUT mit bit-Variable; Zuweisung gemeinsam mit StatusCodeOut vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für die SQL-Fehlernummer eines im Quell-TRY abgefangenen Fehlers; bei AVAILABLE und INVALID_PARAMETER bleibt der Wert NULL. Die bekannten Berechtigungs-/Timeoutnummern werden zugleich klassifiziert. Bindung z.B. @ErrorNumberOut=@ErrorNumber OUTPUT mit int-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für den Text des im Quell-TRY abgefangenen Fehlers oder die konkrete INVALID_PARAMETER-Begründung; bei AVAILABLE bleibt er NULL. Bindung z.B. @ErrorMessageOut=@ErrorMessage OUTPUT mit nvarchar(2048)-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.';
        PRINT N'EXEC [monitor].[USP_ServerMemory] @ResultSetArt=N''CONSOLE'';';
        PRINT N'EXEC [monitor].[USP_ServerMemory] @ResultSetArt=N''RAW'';';
        PRINT N'EXEC [monitor].[USP_ServerMemory] @JsonErzeugen=1,@ResultSetArt=N''NONE'';';
        PRINT N'CREATE TABLE [#ServerMemory_HelpExample]([Seed] bit NULL); EXEC [monitor].[USP_ServerMemory] @ResultSetArt=N''TABLE'',@ResultTablesJson=N''{"summary":"#ServerMemory_HelpExample"}''; DROP TABLE [#ServerMemory_HelpExample];';
        PRINT N'EXEC [monitor].[USP_ServerMemory] @Hilfe=1;';










        RETURN;
 END;
 DECLARE @T datetime2(3)=SYSUTCDATETIME(),@S varchar(40)='AVAILABLE',@P bit=0,@E int=NULL,@M nvarchar(2048)=NULL;
 IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') SELECT @S='INVALID_PARAMETER',@P=1,@M=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
 CREATE TABLE [#ServerMemory_Summary]([total_physical_memory_kb] bigint,[available_physical_memory_kb] bigint,[system_memory_state_desc] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[physical_memory_in_use_kb] bigint,[locked_page_allocations_kb] bigint,[large_page_allocations_kb] bigint,[process_physical_memory_low] bit,[process_virtual_memory_low] bit,[committed_kb] bigint,[committed_target_kb] bigint,[visible_target_kb] bigint,[sql_memory_model_desc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[min_server_memory_mb] bigint,[max_server_memory_mb] bigint,[LPIMAssessment] varchar(50) COLLATE SQL_Latin1_General_CP1_CS_AS,[MemoryFinding] varchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS);
 CREATE TABLE [#ServerMemory_C]([type] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[pages_kb] bigint,[virtual_memory_committed_kb] bigint,[awe_allocated_kb] bigint,[shared_memory_committed_kb] bigint);
 CREATE TABLE [#ServerMemory_G]([ActiveOrWaitingGrants] bigint,[RequestedMemoryKb] bigint,[GrantedMemoryKb] bigint,[UsedMemoryKb] bigint,[WaitingGrantCount] bigint);
 IF @MaxZeilen<0 SELECT @S='INVALID_PARAMETER',@P=1,@M=N'@MaxZeilen darf nicht negativ sein; NULL/0 bedeutet unbegrenzt.';
 ELSE BEGIN SET LOCK_TIMEOUT 0;BEGIN TRY
  INSERT [#ServerMemory_Summary]
  SELECT [sm].[total_physical_memory_kb],[sm].[available_physical_memory_kb],[sm].[system_memory_state_desc],[pm].[physical_memory_in_use_kb],[pm].[locked_page_allocations_kb],[pm].[large_page_allocations_kb],[pm].[process_physical_memory_low],[pm].[process_virtual_memory_low],[si].[committed_kb],[si].[committed_target_kb],[si].[visible_target_kb],[si].[sql_memory_model_desc],
    MIN(CASE WHEN [c].[name]='min server memory (MB)' THEN CONVERT(bigint,[c].[value_in_use]) END),MAX(CASE WHEN [c].[name]='max server memory (MB)' THEN CONVERT(bigint,[c].[value_in_use]) END),
    CASE WHEN [si].[sql_memory_model_desc] LIKE '%LOCK%' OR [pm].[locked_page_allocations_kb]>0 THEN 'LOCKED_PAGES_IN_USE_OR_MODEL' ELSE 'LPIM_NOT_CONFIRMED_BY_RUNTIME' END,
    CASE WHEN [pm].[process_physical_memory_low]=1 OR [pm].[process_virtual_memory_low]=1 THEN 'PROCESS_MEMORY_LOW' WHEN [si].[committed_target_kb]<[si].[committed_kb] THEN 'TARGET_BELOW_COMMITTED' WHEN [sm].[available_physical_memory_kb]<1048576 THEN 'LOW_OS_FREE_MEMORY_REVIEW' ELSE 'OK_SNAPSHOT' END
  FROM [sys].[dm_os_sys_memory] sm WITH (NOLOCK) CROSS JOIN [sys].[dm_os_process_memory] pm WITH (NOLOCK) CROSS JOIN [sys].[dm_os_sys_info] si WITH (NOLOCK) CROSS JOIN [sys].[configurations] c WITH (NOLOCK)
  WHERE [c].[name] IN('min server memory (MB)','max server memory (MB)') GROUP BY [sm].[total_physical_memory_kb],[sm].[available_physical_memory_kb],[sm].[system_memory_state_desc],[pm].[physical_memory_in_use_kb],[pm].[locked_page_allocations_kb],[pm].[large_page_allocations_kb],[pm].[process_physical_memory_low],[pm].[process_virtual_memory_low],[si].[committed_kb],[si].[committed_target_kb],[si].[visible_target_kb],[si].[sql_memory_model_desc];
  INSERT [#ServerMemory_C] SELECT TOP (@EffectiveMaxZeilen)[type],SUM([pages_kb]),SUM([virtual_memory_committed_kb]),SUM([awe_allocated_kb]),SUM([shared_memory_committed_kb]) FROM [sys].[dm_os_memory_clerks] WITH (NOLOCK) GROUP BY [type] ORDER BY SUM([pages_kb])+SUM([virtual_memory_committed_kb])DESC OPTION(MAXDOP 1);
  INSERT [#ServerMemory_G] SELECT COUNT_BIG(*),SUM(CONVERT(bigint,[requested_memory_kb])),SUM(CONVERT(bigint,[granted_memory_kb])),SUM(CONVERT(bigint,[used_memory_kb])),SUM(CONVERT(bigint,CASE WHEN [grant_time] IS NULL THEN 1 ELSE 0 END)) FROM [sys].[dm_exec_query_memory_grants] WITH (NOLOCK);
 END TRY BEGIN CATCH SELECT @S=CASE WHEN ERROR_NUMBER()IN(229,297,300,371)THEN'DENIED_PERMISSION'WHEN ERROR_NUMBER()=1222 THEN'TIMEOUT'ELSE'ERROR_HANDLED'END,@P=1,@E=ERROR_NUMBER(),@M=ERROR_MESSAGE();END CATCH;END;
 SELECT @StatusCodeOut=@S,@IsPartialOut=@P,@ErrorNumberOut=@E,@ErrorMessageOut=@M;IF @PrintMeldungen=1 AND @S<>'AVAILABLE'RAISERROR(N'USP_ServerMemory: %s',10,1,@M) WITH NOWAIT;
 IF @ResultSetArtNormalisiert<>'NONE' BEGIN SELECT CAST('2.0' AS varchar(16)) [ContractVersion],@T [CollectionTimeUtc],N'monitor.USP_ServerMemory' [ModuleName],@S [StatusCode],@P [IsPartial],@E [ErrorNumber],@M [ErrorMessage];IF @ResultSetArtNormalisiert='RAW' BEGIN SELECT * FROM [#ServerMemory_Summary] ;SELECT * FROM [#ServerMemory_C] ORDER BY [pages_kb] DESC;SELECT * FROM [#ServerMemory_G] ; END ELSE BEGIN SELECT N'summary' [Ergebnis],[x].* FROM [#ServerMemory_Summary] [x] ;SELECT N'memoryClerks' [Ergebnis],[x].* FROM [#ServerMemory_C] [x] ORDER BY [pages_kb] DESC;SELECT N'memoryGrants' [Ergebnis],[x].* FROM [#ServerMemory_G] [x] ; END;END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'ServerMemory' [resultName],1 [schemaVersion],@T [generatedAtUtc],@S [statusCode],@P [isPartial],@E [errorNumber],@M [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@J0 nvarchar(max)=(SELECT * FROM [#ServerMemory_Summary]  FOR JSON PATH,INCLUDE_NULL_VALUES),@J1 nvarchar(max)=(SELECT * FROM [#ServerMemory_C] ORDER BY [pages_kb] DESC FOR JSON PATH,INCLUDE_NULL_VALUES),@J2 nvarchar(max)=(SELECT * FROM [#ServerMemory_G]  FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"summary":',COALESCE(@J0,N'[]'),N',"memoryClerks":',COALESCE(@J1,N'[]'),N',"memoryGrants":',COALESCE(@J2,N'[]'),N',"warnings":[]}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ServerMemory_Summary'
            , @ResultLabel=N'ServerMemory'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ServerMemory_Summary'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

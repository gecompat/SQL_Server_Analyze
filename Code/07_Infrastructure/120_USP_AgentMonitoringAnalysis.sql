USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_AgentMonitoringAnalysis
Version      : 1.1.0
Stand        : 2026-07-18
Zweck        : Die Procedure prüft SQL-Agent-/Alert-/Operator-/Job- und Database-Mail-Evidenz.
Datenquellen : sys.dm_server_services, msdb.dbo.sysalerts,
               msdb.dbo.sysoperators, msdb.dbo.sysnotifications,
               msdb.dbo.sysjobs, msdb.dbo.sysjobschedules,
               msdb.dbo.sysschedules, msdb.dbo.sysjobhistory und
               msdb.dbo.sysmail_allitems.
Methodik     : Alert-Routing, Jobzustand und aggregierter Mailstatus werden über
               dieselben reinen Interpretationsfunktionen klassifiziert, die
               der deterministische Laufzeitvertrag verwendet.
Datenschutz  : Liest keine Mailadressen, Empfänger, Betreffzeilen,
               Jobschrittbefehle oder Fehlermeldungstexte.
Grenzen      : Fehlende Standardalarme sind ein Prüfauftrag; externe
               Monitoringwege können die Alarmierung anderweitig abdecken.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_AgentMonitoringAnalysis]
      @HistoryHours       int             = 24
    , @MitJobStatus       bit             = 1
    , @MitDatabaseMail    bit             = 1
    , @MaxZeilen          int             = 1000
    , @ResultSetArt       varchar(16)     = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen       bit             = 0
    , @Json               nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen     bit             = 1
    , @Hilfe              bit             = 0
    , @StatusCodeOut      varchar(40)     = NULL OUTPUT
    , @IsPartialOut       bit             = NULL OUTPUT
    , @ErrorNumberOut     int             = NULL OUTPUT
    , @ErrorMessageOut    nvarchar(2048)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'findings',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Limit bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
                                 THEN CONVERT(bigint, 9223372036854775807)
                                 ELSE CONVERT(bigint, @MaxZeilen) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_AgentMonitoringAnalysis';
        PRINT N'Die Procedure erstellt einen lesenden Snapshot des SQL-Agent-Dienstes, der erforderlichen Alertabdeckung, des Alert-Routings, der Operatoren, des letzten sichtbaren Gesamtoutcomes je Job und optional aggregierter Database-Mail-Status. Sie liest keine Mailadressen, Empfänger, Betreffzeilen, Jobschrittbefehle oder Meldungstexte und führt keine Agent- oder Mailaktion aus.';
        PRINT N'Voraussetzung sind die Procedure und ihre Interpretations- und TABLE-Helper im Schema monitor sowie ausreichende Lesesicht auf sys.dm_server_services und die verwendeten msdb-Kataloge. Fehlende Sichtbarkeit wird soweit abgefangen als AVAILABLE_LIMITED mit erster Fehlernummer und Fehlermeldung ausgewiesen. Für die TABLE-Ausgabe muss zusätzlich ein gültiges lokales Ziel vorhanden sein.';
        PRINT N'Alertaktivität und Mailzeilen verwenden einen lokalen Cutoff; der Jobpfad liest dagegen den letzten sichtbaren Gesamtoutcome ohne Zeitfilter. Die Erhebung ist kein atomarer Snapshot und belegt weder erfolgreiche Zustellung noch eine vollständige Jobausführungsreihe oder externe Alarmierung.';
        PRINT N'@HistoryHours int=24; Default: 24. Ganze Stundenzahl für das lokale Historienfenster der Alertaktivität und Database-Mail-Zeilen; erlaubt sind 1 bis 8760. Nach dem Hilfezweig wird der Cutoff mit DATEADD(HOUR, -@HistoryHours, GETDATE()) vor der Bereichsprüfung berechnet. NULL sowie Werte außerhalb des erlaubten Bereichs setzen INVALID_PARAMETER und IsPartial=1 und überspringen die Fachquellen, sofern die Cutoff-Berechnung erfolgreich war. Extreme int-Werte können vorher ungefangen an Negation oder datetime-Überlauf scheitern; dabei werden die Status-/Fehler-OUTPUTs nicht zugewiesen. Jobhistory wird ohne Zeitfilter nach dem letzten Gesamtoutcome durchsucht; der Cutoff klassifiziert nur diesen letzten Lauf. Übergeben Sie eine ganze Zahl oder eine int-Variable. Andere Literalformen durchlaufen zunächst die SQL-Typkonvertierung; eine leere Zeichenfolge ist kein eigener Leerwert des Prozedurcodes. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MitJobStatus bit=1; Default: 1. Steuert, ob Jobzustand, letzter Gesamtoutcome und Schedule-Zahlen aus msdb erhoben werden. Genau 1 aktiviert den Pfad. 0 und NULL lassen ihn aus; andere ursprüngliche Werte werden bereits beim Binden an bit durch SQL Server konvertiert oder abgewiesen. Der Jobpfad liest die vollständige sichtbare Gesamtzeilen-History ohne @HistoryHours-Filter und klassifiziert danach den letzten Outcome relativ zum Cutoff. Er führt keine Jobs aus oder ändert deren Zustand. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MitDatabaseMail bit=1; Default: 1. Steuert die Aggregation der Database-Mail-Zeilen aus msdb innerhalb des mit @HistoryHours gebildeten Cutoffs. Genau 1 aktiviert den Pfad; 0 und NULL lassen ihn aus. Andere Eingaben durchlaufen vor Prozedurbeginn die SQL-Konvertierung zu bit oder schlagen bei der Bindung fehl. Der Pfad liest nur Status, Anzahl und älteste/neuste Anforderungszeit; Adressen, Empfänger, Betreff und Nachrichtentext werden nicht ausgewertet. Ein Lesefehler setzt Partialstatus. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MaxZeilen int=1000; Default: 1000. Begrenzt die ausgegebenen Findings und Jobzeilen. NULL oder 0 bedeutet unbegrenzt; positive ganze Werte von 1 bis 2147483647 sind die Zeilenobergrenze; negative Werte setzen INVALID_PARAMETER und IsPartial=1 und überspringen die Quellen. Findings werden vor einer positiven Begrenzung nach HIGH, MEDIUM, INFO, Kategorie und Scope-Name gereiht; Jobs werden nach Jobname gereiht. Das Limit reduziert keine vorherige Katalog- oder Historyaggregation. Services und Mailstatus werden nicht mit dieser Zeilengrenze gekürzt. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. Nach Entfernen äußerer Leerzeichen und Umwandlung in Großbuchstaben sind ausschließlich RAW, CONSOLE, NONE und TABLE erlaubt. NULL wird wie leer behandelt und ist ungültig. RAW liefert fünf Resultsets: Modulstatus, Services, begrenzte Findings, begrenzte Jobs und Mailaggregation. CONSOLE liefert genau eine Findingsausgabe mit verständlicher Hinweiszeile bei leerer Menge; es gibt dabei keine zusätzlichen Service- oder Modulstatus-Resultsets. NONE unterdrückt fachliche Resultsets. TABLE schreibt ausschließlich findings in das vorgeprüfte Ziel. JSON über @JsonErzeugen und die Status-/Fehler-OUTPUTs sind davon unabhängig. Ungültige Werte führen nach dem Hilfezweig zu INVALID_PARAMETER mit IsPartial=1. Eingaben werden zunächst an varchar(16) gebunden. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL; Default: NULL. Enthält ausschließlich für TABLE die JSON-Zuordnung des einen exportierbaren Resultsets findings, in der Form {"findings":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel mit dem lokalen Zielnamen als JSON-Stringwert, keine weiteren Eigenschaften. Der Zielname darf höchstens 116 Zeichen lang sein. Das Ziel muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale ##Temp-Tabellen, permanente Tabellen, das reservierte Präfix #Monitor, unbekannte oder doppelte Namen/Ziele, nichtstringige Werte, leere Ziele und zusätzliche Schlüssel sind unzulässig. Das JSON muss ein Objekt sein; NULL, leer oder nur Leerzeichen ist kein gültiges TABLE-Mapping. Außerhalb TABLE sind NULL/leer/Leerzeichen zulässig; jeder nichtleere Wert löst Fehler 51011 aus. TABLE-Mapping und Ziel werden vor der Hilfeausgabe vorgeprüft, sodass ein ungültiges Mapping auch mit @Hilfe=1 fehlschlägt. Der Helper erwartet OPENJSON-kompatibles JSON und installiertes Framework. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit=0; Default: 0. Aktiviert die zusätzliche JSON-Erzeugung nur bei exakt 1; 0 und NULL überspringen sie. SQL Server bindet Eingaben zuerst an bit und konvertiert oder verwirft abweichende Formen. Bei Aktivierung enthält @Json das Objekt meta sowie die vier Arrays services, findings, jobs und mailStatus. Die Arrays verwenden INCLUDE_NULL_VALUES; meta wird ohne INCLUDE_NULL_VALUES serialisiert, sodass NULL-Eigenschaften dort entfallen. meta enthält UTC-Erstellungszeit, Status, Partialflag und @HistoryHours. Findings und Jobs folgen @MaxZeilen; Services und Mailstatus bleiben vollständige getrennte Arrays. Die Ausgabe enthält keine Mailadressen, Empfänger, Betreffzeilen, Jobbefehle oder Meldungstexte. @Json wird am Prozedureintritt auf NULL gesetzt und bleibt bei deaktiviertem Schalter oder vorzeitigem Hilfe-RETURN NULL. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT; Default: NULL. Empfängt bei @JsonErzeugen=1 das erzeugte JSON nvarchar(max) mit meta-, services-, findings-, jobs- und mailStatus-Elementen. Der Wert wird zu Beginn immer auf NULL gesetzt und nur nach abgeschlossener Erhebung bei aktiviertem JSON-Schalter befüllt; bei Hilfe-RETURN und Fehlern vor der Erzeugung bleibt er NULL. NULL-Werte werden in den Kontextarrays erhalten. Findings und Jobs verwenden die Begrenzung aus @MaxZeilen. Status-/Fehler-OUTPUTs werden bei Hilfe-RETURN nicht aktualisiert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@PrintMeldungen bit=1; Default: 1. Wird in der Implementierung nicht gelesen und steuert daher weder PRINT-Ausgaben noch Resultsets. Die fest codierten PRINT-Zeilen der Hilfeausgabe erscheinen bei @Hilfe=1 unabhängig von diesem Schalter. NULL sowie 0 oder 1 ändern das Verhalten nicht; eine Bit-Konvertierung oder ein Konvertierungsfehler geschieht vor dem Prozedurcode. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit=0; Default: 0. Bei exakt 1 gibt die Procedure ihre Hilfe mit PRINT aus und kehrt vor der Analyse mit RETURN zurück. 0 und NULL führen in den normalen Ablauf; abweichende Formen werden beim Binden an bit konvertiert oder abgewiesen. @Json wird zuvor auf NULL gesetzt. Die Status-, Partial- und Fehler-OUTPUTs werden im Hilfezweig nicht belegt und behalten ihre Eingangs-/Bindungswerte. Die Ausgabeoptionen werden vor diesem Zweig geprüft: ein ungültiger Nicht-TABLE-Wert von @ResultTablesJson oder ein fehlerhafter TABLE-Preflight kann daher trotz Hilfe einen Fehler auslösen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. Empfängt genau einen der vier Modulstatuswerte: INVALID_PARAMETER bei einem nach erfolgreicher Cutoff-Berechnung erkannten ungültigen Historien-, Zeilen- oder Ausgabewert; AVAILABLE_LIMITED bei mindestens einem abgefangenen Quellenfehler; AVAILABLE_WITH_FINDING bei mindestens einem HIGH-/MEDIUM-Finding oder einem nicht laufenden sichtbaren Agentdienst ohne Quellenfehler; AVAILABLE sonst, auch bei ausschließlich INFO-Findings. Der Status wird vor der Ausgabegrenze auf der vollständigen Erhebung bestimmt. Binden Sie eine varchar(40)-Variable mit OUTPUT. Bei @Hilfe=1 sowie bei einem Fehler des frühen TABLE-Preflights oder der Cutoff-Berechnung bleibt die Eingangs-/Bindungsvariable unverändert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@IsPartialOut bit=NULL OUTPUT; Default: NULL. Empfängt das Partialflag: 0 bei vollständiger Erhebung, 1 bei ungültigem Historien-/Zeilen-/Ausgabewert oder einem abgefangenen Fehler eines Quellenpfads. Ein ausgelassener optionaler Job- oder Mailpfad allein setzt das Flag nicht. Bei @Hilfe=1 sowie bei Fehlern im frühen Ausgabepreflight wird der Wert vor Abbruch/RETURN nicht beschrieben. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@ErrorNumberOut int=NULL OUTPUT; Default: NULL. Empfängt die erste abgefangene SQL-Quellenfehlernummer oder NULL, wenn kein Quellenfehler erfasst wurde. Ein ungültiger Analyseparameter setzt keinen Fehlernummernwert. Bei @Hilfe=1 und bei einem Fehler des frühen Output-Mappings erfolgt keine Zuweisung. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. Empfängt NULL ohne abgefangenen Quellenfehler oder den ersten abgefangenen SQL-Fehler mit einem quellenspezifischen Präfix in nvarchar(2048). Bei ungültigen Analyseparametern steht hier eine generische Parameterfehlermeldung; spätere Quellenfehler überschreiben die erste gespeicherte Fehlermeldung nicht. Die Texte können SQL-Fehlerdetails enthalten, umfassen aber keine gelesenen Mail- oder Jobnachrichten. Bei Hilfe-RETURN und frühem Mappingfehler erfolgt keine Zuweisung. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_AgentMonitoringAnalysis] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_AgentMonitoringAnalysis] @HistoryHours=24, @MaxZeilen=100, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3: DECLARE @AgentMonitoringJson nvarchar(max), @AgentMonitoringStatus varchar(40), @AgentMonitoringPartial bit, @AgentMonitoringError int, @AgentMonitoringMessage nvarchar(2048); EXEC [monitor].[USP_AgentMonitoringAnalysis] @HistoryHours=24, @MaxZeilen=100, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@AgentMonitoringJson OUTPUT, @StatusCodeOut=@AgentMonitoringStatus OUTPUT, @IsPartialOut=@AgentMonitoringPartial OUTPUT, @ErrorNumberOut=@AgentMonitoringError OUTPUT, @ErrorMessageOut=@AgentMonitoringMessage OUTPUT; SELECT @AgentMonitoringStatus AS [StatusCode], @AgentMonitoringPartial AS [IsPartial], @AgentMonitoringError AS [ErrorNumber], @AgentMonitoringMessage AS [ErrorMessage], @AgentMonitoringJson AS [Json];';
        PRINT N'Beispiel 4: CREATE TABLE #AgentMonitoring_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentMonitoringAnalysis] @MaxZeilen=100, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"findings":"#AgentMonitoring_HelpExample"}''; SELECT * FROM #AgentMonitoring_HelpExample; DROP TABLE #AgentMonitoring_HelpExample; END TRY BEGIN CATCH DROP TABLE #AgentMonitoring_HelpExample; THROW; END CATCH;';
        PRINT N'Beispiel 5: EXEC [monitor].[USP_AgentMonitoringAnalysis] @HistoryHours=24, @MitJobStatus=0, @MitDatabaseMail=0, @MaxZeilen=100, @ResultSetArt=''RAW'';';
        RETURN;
    END;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @CutoffLocal datetime = CASE WHEN @HistoryHours IS NULL THEN NULL ELSE DATEADD(HOUR, -@HistoryHours, GETDATE()) END;
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;

    CREATE TABLE [#AgentMonitoringAnalysis_Services]
    (
          [ServiceName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StartupTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LastStartupTime] datetimeoffset(7) NULL
        , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#AgentMonitoringAnalysis_Findings]
    (
          [Category] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ScopeType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ScopeName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MetricValue] bigint NULL
        , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#AgentMonitoringAnalysis_Jobs]
    (
          [JobId] uniqueidentifier NOT NULL
        , [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsEnabled] tinyint NOT NULL
        , [LatestRunDateTime] datetime NULL
        , [LatestRunStatus] int NULL
        , [LatestRunDuration] int NULL
        , [ScheduleCount] bigint NOT NULL
        , [EnabledScheduleCount] bigint NOT NULL
        , [FindingCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#AgentMonitoringAnalysis_Mail]
    (
          [SentStatus] varchar(8) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ItemCount] bigint NOT NULL
        , [OldestRequestDate] datetime NULL
        , [NewestRequestDate] datetime NULL
    );

    IF @HistoryHours IS NULL OR @HistoryHours < 1 OR @HistoryHours > 8760 OR @MaxZeilen < 0
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER', @IsPartial = 1,
               @ErrorMessage = N'Ungültiger Historien-, Zeilen- oder Ausgabeparameter.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        BEGIN TRY
            INSERT [#AgentMonitoringAnalysis_Services]
            SELECT [servicename], [status_desc], [startup_type_desc], [last_startup_time],
                   CASE WHEN [status_desc] = N'Running' THEN 'AGENT_SERVICE_RUNNING'
                        ELSE 'AGENT_SERVICE_NOT_RUNNING' END
            FROM [sys].[dm_server_services] WITH (NOLOCK)
            WHERE [servicename] LIKE N'SQL Server Agent%';
        END TRY
        BEGIN CATCH
            SELECT @IsPartial = 1, @ErrorNumber = ERROR_NUMBER(),
                   @ErrorMessage = CONCAT(N'Dienststatus nicht lesbar: ', ERROR_MESSAGE());
        END CATCH;

        BEGIN TRY
            ;WITH [RequiredAlerts] AS
            (
                SELECT 'MESSAGE_823' AS [Code], 823 AS [MessageId], 0 AS [Severity]
                UNION ALL SELECT 'MESSAGE_824', 824, 0
                UNION ALL SELECT 'MESSAGE_825', 825, 0
                UNION ALL SELECT CONCAT('SEVERITY_', [n]), 0, [n]
                FROM (VALUES (19),(20),(21),(22),(23),(24),(25)) AS [v]([n])
            )
            INSERT [#AgentMonitoringAnalysis_Findings]
            SELECT
                  'ALERT_COVERAGE', 'REQUIRED_AGENT_ALERT_MISSING', 'HIGH', N'ALERT_REQUIREMENT'
                , [r].[Code], NULL
                , CONCAT(N'Kein aktivierter SQL-Agent-Alert für message_id=', [r].[MessageId],
                         N' beziehungsweise severity=', [r].[Severity], N' gefunden.')
                , N'Externe Alarmierung kann die Anforderung erfüllen; Monitoringarchitektur vor Anlage eines Alerts prüfen.'
            FROM [RequiredAlerts] AS [r]
            WHERE NOT EXISTS
            (
                SELECT 1 FROM [msdb].[dbo].[sysalerts] AS [a] WITH (NOLOCK)
                WHERE [a].[enabled] = 1
                  AND (([r].[MessageId] > 0 AND [a].[message_id] = [r].[MessageId])
                    OR ([r].[Severity] > 0 AND [a].[severity] = [r].[Severity]))
            );

            INSERT [#AgentMonitoringAnalysis_Findings]
            SELECT
                  'ALERT_ROUTING', [route].[FindingCode], [route].[FindingSeverity], N'ALERT', [a].[name]
                , CONVERT(bigint, [a].[occurrence_count])
                , N'Aktivierter Alert besitzt weder Operatorbenachrichtigung noch Jobaktion.'
                , N'Externe Weiterleitung und absichtlich rein protokollierende Alerts separat prüfen.'
            FROM [msdb].[dbo].[sysalerts] AS [a] WITH (NOLOCK)
            OUTER APPLY
            (
                SELECT [NotificationCount]=COUNT_BIG(*)
                FROM [msdb].[dbo].[sysnotifications] AS [n] WITH (NOLOCK)
                WHERE [n].[alert_id]=[a].[id]
            ) AS [notifications]
            CROSS APPLY [monitor].[TVF_InterpretAgentAlertRoute]
            (
                  CONVERT(bit,[a].[enabled])
                , CONVERT(bit,CASE WHEN [a].[job_id]<>CONVERT(uniqueidentifier,'00000000-0000-0000-0000-000000000000') THEN 1 ELSE 0 END)
                , [notifications].[NotificationCount]
            ) AS [route]
            WHERE [route].[FindingCode]='ENABLED_ALERT_WITHOUT_ACTION';

            INSERT [#AgentMonitoringAnalysis_Findings]
            SELECT
                  'ALERT_ROUTING', 'ALERT_TARGET_OPERATOR_DISABLED', 'HIGH', N'OPERATOR', [o].[name]
                , COUNT_BIG(*)
                , N'Mindestens ein aktivierter Alert verweist auf einen deaktivierten Operator.'
                , N'Externe Zustellung und Bereitschaftsmodell separat prüfen; Adressdaten werden nicht gelesen.'
            FROM [msdb].[dbo].[sysoperators] AS [o] WITH (NOLOCK)
            JOIN [msdb].[dbo].[sysnotifications] AS [n] WITH (NOLOCK) ON [n].[operator_id] = [o].[id]
            JOIN [msdb].[dbo].[sysalerts] AS [a] WITH (NOLOCK) ON [a].[id] = [n].[alert_id]
            WHERE [a].[enabled] = 1 AND [o].[enabled] = 0
            GROUP BY [o].[name];

            INSERT [#AgentMonitoringAnalysis_Findings]
            SELECT
                  'ALERT_ACTIVITY', 'ALERT_OCCURRED_IN_WINDOW', 'MEDIUM', N'ALERT', [a].[name]
                , CONVERT(bigint, [a].[occurrence_count])
                , N'Der Alert besitzt eine Auftretenshistorie; Meldungstext wird nicht gelesen.'
                , N'occurrence_count kann seit einem früheren Reset kumulativ sein; Zeitstempel und externes Monitoring korrelieren.'
            FROM [msdb].[dbo].[sysalerts] AS [a] WITH (NOLOCK)
            WHERE [a].[enabled] = 1 AND [a].[occurrence_count] > 0
              AND [a].[last_occurrence_date] > 0
              AND [msdb].[dbo].[agent_datetime]
                  ([a].[last_occurrence_date], [a].[last_occurrence_time]) >= @CutoffLocal;
        END TRY
        BEGIN CATCH
            SELECT @IsPartial = 1;
            IF @ErrorNumber IS NULL
                SELECT @ErrorNumber = ERROR_NUMBER(),
                       @ErrorMessage = CONCAT(N'Alert-/Operatorstatus nicht lesbar: ', ERROR_MESSAGE());
        END CATCH;

        IF @MitJobStatus = 1
        BEGIN
            DECLARE @JobCollectionXactAbort int = @@OPTIONS & 16384;
            SET XACT_ABORT OFF;
            BEGIN TRY
                ;WITH [LatestOutcome] AS
                (
                    SELECT [h].[job_id], [h].[run_status], [h].[run_duration],
                           [msdb].[dbo].[agent_datetime]([h].[run_date], [h].[run_time]) AS [RunDateTime],
                           ROW_NUMBER() OVER
                           (PARTITION BY [h].[job_id] ORDER BY [h].[instance_id] DESC) AS [rn]
                    FROM [msdb].[dbo].[sysjobhistory] AS [h] WITH (NOLOCK)
                    WHERE [h].[step_id] = 0 AND [h].[run_date] > 0
                ),
                [Schedules] AS
                (
                    SELECT [js].[job_id], COUNT_BIG(*) AS [ScheduleCount],
                           SUM(CONVERT(bigint, CASE WHEN [s].[enabled] = 1 THEN 1 ELSE 0 END)) AS [EnabledCount]
                    FROM [msdb].[dbo].[sysjobschedules] AS [js] WITH (NOLOCK)
                    JOIN [msdb].[dbo].[sysschedules] AS [s] WITH (NOLOCK) ON [s].[schedule_id] = [js].[schedule_id]
                    GROUP BY [js].[job_id]
                )
                INSERT [#AgentMonitoringAnalysis_Jobs]
                SELECT
                      [j].[job_id], [j].[name], [j].[enabled], [o].[RunDateTime], [o].[run_status]
                    , [o].[run_duration], COALESCE([s].[ScheduleCount], 0), COALESCE([s].[EnabledCount], 0)
                    , [state].[FindingCode], [state].[FindingSeverity]
                FROM [msdb].[dbo].[sysjobs] AS [j] WITH (NOLOCK)
                LEFT JOIN [LatestOutcome] AS [o] ON [o].[job_id] = [j].[job_id] AND [o].[rn] = 1
                LEFT JOIN [Schedules] AS [s] ON [s].[job_id] = [j].[job_id]
                CROSS APPLY [monitor].[TVF_InterpretAgentJobState]
                (
                      [j].[enabled], [o].[run_status], [o].[RunDateTime], @CutoffLocal
                    , COALESCE([s].[ScheduleCount],0), COALESCE([s].[EnabledCount],0)
                ) AS [state];
            END TRY
            BEGIN CATCH
                SELECT @IsPartial = 1;
                IF @ErrorNumber IS NULL
                    SELECT @ErrorNumber = ERROR_NUMBER(),
                           @ErrorMessage = CONCAT(N'Jobstatus nicht lesbar: ', ERROR_MESSAGE());
            END CATCH;
            IF @JobCollectionXactAbort = 0 SET XACT_ABORT OFF; ELSE SET XACT_ABORT ON;
        END;

        IF @MitDatabaseMail = 1
        BEGIN
            BEGIN TRY
                INSERT [#AgentMonitoringAnalysis_Mail]
                SELECT [sent_status], COUNT_BIG(*), MIN([send_request_date]), MAX([send_request_date])
                FROM [msdb].[dbo].[sysmail_allitems] WITH (NOLOCK)
                WHERE [send_request_date] >= @CutoffLocal
                GROUP BY [sent_status];
            END TRY
            BEGIN CATCH
                SELECT @IsPartial = 1;
                IF @ErrorNumber IS NULL
                    SELECT @ErrorNumber = ERROR_NUMBER(),
                           @ErrorMessage = CONCAT(N'Database-Mail-Status nicht lesbar: ', ERROR_MESSAGE());
            END CATCH;
        END;

        INSERT [#AgentMonitoringAnalysis_Findings]
        SELECT 'JOB_ACTIVITY', [FindingCode], [FindingSeverity],
               N'JOB', [JobName], NULL,
               CONCAT(N'Letzter Status=', COALESCE(CONVERT(nvarchar(20), [LatestRunStatus]), N'NULL'),
                      N'; Schedules=', [ScheduleCount], N'; aktive Schedules=', [EnabledScheduleCount], N'.'),
               N'On-demand Jobs und externe Scheduler können einen fehlenden SQL-Agent-Zeitplan erklären.'
        FROM [#AgentMonitoringAnalysis_Jobs]
        WHERE [FindingCode] <> 'JOB_STATE_INFORMATIONAL';

        INSERT [#AgentMonitoringAnalysis_Findings]
        SELECT 'DATABASE_MAIL', [state].[FindingCode], [state].[FindingSeverity],
               N'MAIL_STATUS', [m].[SentStatus], [m].[ItemCount],
               CONCAT(N'Database-Mail-Elemente mit Status ', [m].[SentStatus], N' im Sichtfenster.'),
               N'Empfänger, Betreff und Nachrichtentext werden bewusst nicht gelesen; Mailserver separat prüfen.'
        FROM [#AgentMonitoringAnalysis_Mail] AS [m]
        CROSS APPLY [monitor].[TVF_InterpretDatabaseMailStatus]([m].[SentStatus]) AS [state]
        WHERE [state].[FindingSeverity] IN ('HIGH','MEDIUM');

        IF @IsPartial = 1
            SET @StatusCode = 'AVAILABLE_LIMITED';
        ELSE IF EXISTS
                (
                    SELECT 1 FROM [#AgentMonitoringAnalysis_Findings] WHERE [Severity] IN ('HIGH', 'MEDIUM')
                    UNION ALL
                    SELECT 1 FROM [#AgentMonitoringAnalysis_Services] WHERE [FindingCode] = 'AGENT_SERVICE_NOT_RUNNING'
                )
            SET @StatusCode = 'AVAILABLE_WITH_FINDING';
    END;

    SELECT @StatusCodeOut = @StatusCode, @IsPartialOut = @IsPartial,
           @ErrorNumberOut = @ErrorNumber, @ErrorMessageOut = @ErrorMessage;

    ;WITH [RankedFindings] AS
    (
        SELECT *,ROW_NUMBER() OVER
        (ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
                  [Category],[ScopeName]) AS [OutputOrdinal]
        FROM [#AgentMonitoringAnalysis_Findings]
    )
    DELETE FROM [RankedFindings] WHERE [OutputOrdinal]>CASE WHEN @Limit<0 THEN 0 ELSE @Limit END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
            (SELECT N'AgentMonitoringAnalysis' AS [resultName], 1 AS [schemaVersion],
                    @Now AS [generatedAtUtc], @StatusCode AS [statusCode], @IsPartial AS [isPartial],
                    @HistoryHours AS [historyHours]
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        DECLARE @ServicesJson nvarchar(max) = (SELECT * FROM [#AgentMonitoringAnalysis_Services] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @FindingsJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#AgentMonitoringAnalysis_Findings]
             ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
                      [Category], [ScopeName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @JobsJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#AgentMonitoringAnalysis_Jobs] ORDER BY [JobName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @MailJson nvarchar(max) =
            (SELECT * FROM [#AgentMonitoringAnalysis_Mail] ORDER BY [SentStatus] FOR JSON PATH, INCLUDE_NULL_VALUES);
        SET @Json = CONCAT(N'{"meta":', COALESCE(@MetaJson, N'{}'),
                           N',"services":', COALESCE(@ServicesJson, N'[]'),
                           N',"findings":', COALESCE(@FindingsJson, N'[]'),
                           N',"jobs":', COALESCE(@JobsJson, N'[]'),
                           N',"mailStatus":', COALESCE(@MailJson, N'[]'), N'}');
    END;

    IF @OutputMode = 'RAW'
    BEGIN
        SELECT N'USP_AgentMonitoringAnalysis' AS [ModuleName], @Now AS [CollectionTimeUtc],
               @StatusCode AS [StatusCode], @IsPartial AS [IsPartial],
               @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage],
               N'Keine Adressen, Empfänger, Jobbefehle oder Nachrichtentexte gelesen.' AS [Detail];
        SELECT * FROM [#AgentMonitoringAnalysis_Services];
        SELECT TOP (@Limit) * FROM [#AgentMonitoringAnalysis_Findings]
        ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
                 [Category], [ScopeName];
        SELECT TOP (@Limit) * FROM [#AgentMonitoringAnalysis_Jobs] ORDER BY [JobName];
        SELECT * FROM [#AgentMonitoringAnalysis_Mail] ORDER BY [SentStatus];
    END
    ELSE IF @OutputMode = 'CONSOLE'
    BEGIN
        SELECT N'Agent- und Alert-Monitoring' AS [Ergebnis], @Now AS [Stand_UTC],
               @StatusCode AS [Status], @IsPartial AS [Teilweise], @ErrorMessage AS [Hinweis];
        SELECT N'SQL-Agent-Dienst' AS [Ergebnis], [ServiceName] AS [Dienst],
               [StatusDesc] AS [Status], [StartupTypeDesc] AS [Starttyp],
               [LastStartupTime] AS [Letzter_Start], [FindingCode] AS [Befund]
        FROM [#AgentMonitoringAnalysis_Services];
        SELECT TOP (@Limit) N'Monitoring-Befund' AS [Ergebnis], [Category] AS [Kategorie],
               [ScopeType] AS [Bereichstyp], [ScopeName] AS [Bereich],
               [FindingCode] AS [Befund], [Severity] AS [Prioritaet],
               [MetricValue] AS [Messwert], [Evidence] AS [Evidenz], [EvidenceLimit] AS [Grenze]
        FROM [#AgentMonitoringAnalysis_Findings]
        ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
                 [Category], [ScopeName];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#AgentMonitoringAnalysis_Findings'
            , @ResultLabel=N'AgentMonitoringAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#AgentMonitoringAnalysis_Findings'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

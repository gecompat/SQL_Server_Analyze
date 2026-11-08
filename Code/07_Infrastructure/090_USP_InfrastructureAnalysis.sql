USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_InfrastructureAnalysis
Version      : 2.1.0
Stand        : 2026-07-17
Typ          : Stored Procedure
Zweck        : Orchestriert die Phase-6-Module fehlertolerant.
SQL-Version  : SQL Server 2019 oder neuer.
Datenbankscope: @DatabaseNames ist eine bracket-aware Pipe-Liste; NULL bedeutet
               alle zulässigen Datenbanken. @DatabaseNamePattern ist alternativ.
Resultsets   : Je aktiviertem Modul RAW oder CONSOLE sowie Modulstatus;
               NONE unterdrückt alle fachlichen Resultsets.
JSON         : meta und benannte Modulobjekte agent, agentJobs,
               resourceGovernor, availabilityGroups, backupRecovery,
               logShipping, replication, dataCapture sowie warnings.
Berechtigung : Das Framework vergibt keine Rechte und ändert keine Konfiguration.
Änderungen   : 2.1.0 - Backupketten, tiefe AG- und Agent-Monitoring-Evidenz
                         als opt-in Teilmodule ergänzt.
               2.0.0 - @AlleDatenbanken entfernt; einheitlicher Datenbankscope,
                         Ausgabeadapter und JSON-Orchestrierung.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_InfrastructureAnalysis]
      @MitAgent                       bit            = 1
    , @MitAgentJobs                   bit            = 1
    , @MitResourceGovernor            bit            = 1
    , @MitAvailabilityGroups          bit            = 1
    , @MitBackupRecovery              bit            = 1
    , @MitLogShipping                 bit            = 1
    , @MitReplication                 bit            = 1
    , @MitDataCapture                 bit            = 1
    , @MitReplicationDetails          bit            = 0
    , @MitBackupChain                 bit            = 0
    , @MitAvailabilityDeep            bit            = 0
    , @MitAgentMonitoring             bit            = 0
    , @DatabaseNames                  nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @MaxZeilen                      int            = 2000
    , @ResultSetArt                   varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                   bit            = 0
    , @Json                           nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                 bit            = 1
    , @Hilfe                          bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'moduleStatus',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_InfrastructureAnalysis';
        PRINT N'@MitAgent bit. Default ist 1. Schaltet monitor.USP_AgentStatus ein (1) oder aus (0). NULL wirkt wegen der IF-Prüfung wie aus. sonstige bit-konvertierbare Werte werden vor Eintritt von SQL Server zu bit konvertiert (ungleich 0 wird 1), Konvertierungsfehler treten davor auf. Bei Auslassung gilt 1.';
        PRINT N'@MitAgentJobs bit. Default ist 1. Schaltet monitor.USP_AgentJobs ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.';
        PRINT N'@MitResourceGovernor bit. Default ist 1. Schaltet monitor.USP_ResourceGovernorAnalysis ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.';
        PRINT N'@MitAvailabilityGroups bit. Default ist 1. Schaltet monitor.USP_AvailabilityGroups ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.';
        PRINT N'@MitBackupRecovery bit. Default ist 1. Schaltet monitor.USP_BackupRecovery ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.';
        PRINT N'@MitLogShipping bit. Default ist 1. Schaltet monitor.USP_LogShippingStatus ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.';
        PRINT N'@MitReplication bit. Default ist 1. Schaltet monitor.USP_ReplicationStatus ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.';
        PRINT N'@MitDataCapture bit. Default ist 1. Schaltet monitor.USP_DataCaptureStatus ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.';
        PRINT N'@MitReplicationDetails bit. Default ist 0. Der bit-Parameter nimmt 0, 1 oder NULL an; bei Auslassung gilt 0. 0 fordert nur sichtbare Replikationsrollen an. 1 fordert zusätzlich Publikations-, Subscription- und Fehlerdetails aus einer online sichtbaren lokalen Distribution-Datenbank an, einschließlich der letzten Agent-Historyzeile je Subscription. Der Child prüft den ENTERPRISE_TOPOLOGY_DEEP-Pfad mit Bestätigung, Gruppe und Berechtigung; die Bestätigung allein gibt den Pfad nicht frei. Eine fehlende online sichtbare Distribution-Datenbank ergibt Partialstatus oder, ohne Basiszeilen, UNAVAILABLE_FEATURE. NULL wird weitergereicht, aber nicht geprüft und fordert keine Details an. Der Parent reicht den Wert nur bei @MitReplication=1 als @MitDistributionDetails an USP_ReplicationStatus weiter; dieser Schalter aktiviert das Modul nicht.';
        PRINT N'@MitBackupChain bit. Default ist 0. Schaltet das optionale Child USP_BackupChainAnalysis ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 0.';
        PRINT N'@MitAvailabilityDeep bit. Default ist 0. Schaltet das optionale Child USP_AvailabilityDeepAnalysis ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 0.';
        PRINT N'@MitAgentMonitoring bit. Default ist 0. Schaltet das optionale Child USP_AgentMonitoringAnalysis ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 0.';
        PRINT N'@DatabaseNames nvarchar(max). Default ist NULL. Pipe-Liste exakter einteiliger SQL-Namen für BackupRecovery, DataCaptureStatus und BackupChainAnalysis. Eckige Klammern schützen enthaltene Pipe-Zeichen und ]] maskiert eine schließende Klammer. Die Empfänger behandeln NULL, Leertext und reine Leerzeichen als keine exakte Einschränkung. Ungültige Einträge werden abgelehnt. Der Parent lehnt jede Kombination aus nicht-NULL-Liste und nicht-NULL-Muster ab.';
        PRINT N'@SystemdatenbankenEinbeziehen bit. Default ist 0. Gibt die Einbeziehung von Systemdatenbanken an Backup-, Data-Capture- und Backup-Chain-Children weiter. NULL und 0 werden weitergereicht und sind keine Parent-seitige Freigabe. fachliche Wirkung entscheidet der jeweilige Child. Bit-Konvertierungsfehler entstehen vor dem Prozeduraufruf. Bei Auslassung gilt 0.';
        PRINT N'@DatabaseNamePattern nvarchar(4000). Default ist NULL. Alternatives Muster für die datenbankbezogenen Empfänger. Ohne Präfix oder mit LIKE: gilt SQL LIKE mit % und _. REGEX: berücksichtigt Groß- und Kleinschreibung, REGEXI: ignoriert sie. Regex benötigt SQL Server 2025 und Compatibility Level 170. NULL deaktiviert das Muster. Leere Muster sind ungültig. Nicht mit einer nicht-NULL-Liste kombinieren.';
        PRINT N'@HighImpactConfirmed bit. Default ist 0. Der Parent reicht den Wert an BackupRecovery, DataCaptureStatus, BackupChainAnalysis und ReplicationStatus weiter. BackupRecovery und BackupChain aktivieren damit keine Analyseklasse. DataCapture prüft HA_DR_CURRENT ohne High-Impact-Pflicht. Replication prüft bei aktivierten Distributiondetails den geschützten Topologiepfad. 1 bestätigt dessen hohen Aufwand. 0 bestätigt ihn nicht. NULL kann beim Empfänger als ungültig abgelehnt werden.';
        PRINT N'@MaxZeilen int. Default ist 2000. Eine positive ganze Zahl begrenzt die Ergebnisse der jeweiligen Empfänger. NULL oder 0 bedeutet dort unbegrenzt. AgentStatus erhält den Parameter nicht. Negative Werte ergeben bereits im Parent INVALID_PARAMETER. Die Modulstatusliste wird nicht gekürzt.';
        PRINT N'@ResultSetArt varchar(16). Default ist ''CONSOLE''. NULL wird zunächst zu leerem Text normalisiert. andernfalls werden äußere Leerzeichen getrimmt und der Vergleich erfolgt groß-/kleinschreibungsunabhängig. Zulässig sind RAW, CONSOLE, TABLE, NONE. RAW liefert Summary und Modultabelle mit technischen Spalten. CONSOLE lässt den internen Console-Adapter beschriftete Ergebnisse ausgeben. NONE unterdrückt fachliche Resultsets. TABLE exportiert ausschließlich moduleStatus in das Ziel aus @ResultTablesJson. Vor den Children werden TABLE und CONSOLE intern zu NONE normalisiert und dämpfen damit Childresultsets. Andere Werte ergeben INVALID_PARAMETER, außer der vorherige Hilfezweig kehrt zurück. Bei Auslassung gilt CONSOLE.';
        PRINT N'@ResultTablesJson nvarchar(max). Default ist NULL. Nur bei @ResultSetArt=TABLE wird ein nichtleeres JSON-Objekt benötigt, mit genau dem case-sensitiven Schlüssel "moduleStatus" und Stringwert des Zielnamens, z.B. {"moduleStatus":"#InfraExample"}. Ziel muss eine bereits angelegte, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein. globale ##-, #Monitor*- oder überlange Ziele sind unzulässig. Der Helper validiert das einzelne Ziel und wirft bei Fehlern 51011 vor Hilfezweig/Childzugriff. Außerhalb TABLE werden NULL, leerer oder nur aus Leerzeichen bestehender Text ignoriert. nichtleere Werte lösen 51011 aus, ebenfalls vor Hilfe. Bei Auslassung gilt NULL.';
        PRINT N'@JsonErzeugen bit. Default ist 0. Bei 1 erzeugt der Parent @Json OUTPUT einschließlich meta, benannter Childfelder und warnings. deaktivierte/fehlende Childobjekte stehen als JSON null. Bei 0 oder NULL wird kein JSON erzeugt und @Json bleibt NULL. Child-JSON wird ebenfalls nur angefordert, wenn dieser Schalter 1 ist. SQL-Bitkonvertierung erfolgt vor Eintritt. bei Auslassung gilt 0.';
        PRINT N'@Json nvarchar(max) OUTPUT. Default ist NULL. OUTPUT-Parameter: mit einer nvarchar(max)-Variablen als @Json=@Variable OUTPUT binden. Der Parent setzt ihn zu Beginn auf NULL und befüllt ihn nur bei @JsonErzeugen=1. Ohne OUTPUT-Bindung wird kein Wert in eine Aufrufervariable kopiert.';
        PRINT N'@PrintMeldungen bit. Default ist 1. Wird an alle aktivierten Children weitergereicht und steuert dortige Meldungen. der Parent leitet daraus keine eigene Meldung ab. NULL wird weitergereicht. Bit-Konvertierung geschieht vor Eintritt. bei Auslassung gilt 1.';
        PRINT N'@Hilfe bit. Default ist 0. Bei 1 gibt die Procedure ihre knappe Hilfe mit PRINT aus und kehrt vor Childaufrufen zurück. NULL wirkt wie 0. SQL konvertiert vor Eintritt zu bit. TABLE-Zuordnung wird vorher geprüft. bei TABLE ist der Preflight somit auch im Hilfemodus aktiv, und ein nichtleeres ResultTablesJson außerhalb TABLE löst ebenfalls vorher Fehler 51011 aus. Ungültige normale Parameter werden nach diesem Hilfe-Rücksprung erst als INVALID_PARAMETER gemeldet. Bei Auslassung gilt 0.';
        PRINT N'Beispiel 1. EXEC [monitor].[USP_InfrastructureAnalysis] @Hilfe=1;';
        PRINT N'Beispiel 2. EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];';
        PRINT N'Beispiel 4. CREATE TABLE #InfrastructureAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"moduleStatus":"#InfrastructureAnalysis_HelpExample"}''; SELECT * FROM #InfrastructureAnalysis_HelpExample; DROP TABLE #InfrastructureAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #InfrastructureAnalysis_HelpExample; THROW; END CATCH;';
        RETURN;
    END;

    CREATE TABLE [#InfrastructureAnalysis_ModuleStatus]
    (
          [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    DECLARE @AgentJson nvarchar(max) = NULL;
    DECLARE @AgentJobsJson nvarchar(max) = NULL;
    DECLARE @ResourceGovernorJson nvarchar(max) = NULL;
    DECLARE @AvailabilityGroupsJson nvarchar(max) = NULL;
    DECLARE @BackupRecoveryJson nvarchar(max) = NULL;
    DECLARE @LogShippingJson nvarchar(max) = NULL;
    DECLARE @ReplicationJson nvarchar(max) = NULL;
    DECLARE @DataCaptureJson nvarchar(max) = NULL;
    DECLARE @BackupChainJson nvarchar(max) = NULL;
    DECLARE @AvailabilityDeepJson nvarchar(max) = NULL;
    DECLARE @AgentMonitoringJson nvarchar(max) = NULL;
    DECLARE @ChildStatus varchar(40) = NULL;
    DECLARE @ChildPartial bit = NULL;
    DECLARE @ChildErrorNumber int = NULL;
    DECLARE @ChildErrorMessage nvarchar(2048) = NULL;

    IF @MaxZeilen < 0
       OR @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR (@DatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL)
    BEGIN
        INSERT [#InfrastructureAnalysis_ModuleStatus]
        VALUES
        (
              N'USP_InfrastructureAnalysis'
            , 'INVALID_PARAMETER'
            , NULL
            , N'Ungültige Scope-, Grenzwert- oder Ausgabeparameter.'
        );
    END;
    ELSE
    BEGIN
        IF @MitAgent = 1
        BEGIN TRY
            EXEC [monitor].[USP_AgentStatus]
                  @ResultSetArt = @ResultSetArtNormalisiert
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @AgentJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_AgentStatus', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_AgentStatus', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;

        IF @MitAgentJobs = 1
        BEGIN TRY
            EXEC [monitor].[USP_AgentJobs]
                  @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @ResultSetArtNormalisiert
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @AgentJobsJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_AgentJobs', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_AgentJobs', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;

        IF @MitResourceGovernor = 1
        BEGIN TRY
            EXEC [monitor].[USP_ResourceGovernorAnalysis]
                  @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @ResultSetArtNormalisiert
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ResourceGovernorJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_ResourceGovernorAnalysis', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_ResourceGovernorAnalysis', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;

        IF @MitAvailabilityGroups = 1
        BEGIN TRY
            EXEC [monitor].[USP_AvailabilityGroups]
                  @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @ResultSetArtNormalisiert
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @AvailabilityGroupsJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_AvailabilityGroups', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_AvailabilityGroups', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;

        IF @MitBackupRecovery = 1
        BEGIN TRY
            EXEC [monitor].[USP_BackupRecovery]
                  @DatabaseNames = @DatabaseNames
                , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @ResultSetArtNormalisiert
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @BackupRecoveryJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_BackupRecovery', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_BackupRecovery', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;

        IF @MitLogShipping = 1
        BEGIN TRY
            EXEC [monitor].[USP_LogShippingStatus]
                  @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @ResultSetArtNormalisiert
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @LogShippingJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_LogShippingStatus', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_LogShippingStatus', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;

        IF @MitReplication = 1
        BEGIN TRY
            EXEC [monitor].[USP_ReplicationStatus]
                  @MitDistributionDetails = @MitReplicationDetails
                , @MaxZeilen = @MaxZeilen
                , @HighImpactConfirmed = @HighImpactConfirmed
                , @ResultSetArt = @ResultSetArtNormalisiert
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ReplicationJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_ReplicationStatus', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_ReplicationStatus', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;

        IF @MitDataCapture = 1
        BEGIN TRY
            EXEC [monitor].[USP_DataCaptureStatus]
                  @DatabaseNames = @DatabaseNames
                , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @ResultSetArtNormalisiert
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @DataCaptureJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_DataCaptureStatus', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_DataCaptureStatus', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;

        IF @MitBackupChain = 1
        BEGIN TRY
            SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
            EXEC [monitor].[USP_BackupChainAnalysis]
                  @DatabaseNames = @DatabaseNames
                , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @ResultSetArtNormalisiert
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @BackupChainJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT, @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT, @ErrorMessageOut = @ChildErrorMessage OUTPUT;
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES
            (N'USP_BackupChainAnalysis', COALESCE(@ChildStatus, 'ERROR_HANDLED'), @ChildErrorNumber, @ChildErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_BackupChainAnalysis', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;

        IF @MitAvailabilityDeep = 1
        BEGIN TRY
            SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
            EXEC [monitor].[USP_AvailabilityDeepAnalysis]
                  @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @ResultSetArtNormalisiert
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @AvailabilityDeepJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT, @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT, @ErrorMessageOut = @ChildErrorMessage OUTPUT;
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES
            (N'USP_AvailabilityDeepAnalysis', COALESCE(@ChildStatus, 'ERROR_HANDLED'), @ChildErrorNumber, @ChildErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_AvailabilityDeepAnalysis', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;

        IF @MitAgentMonitoring = 1
        BEGIN TRY
            SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
            EXEC [monitor].[USP_AgentMonitoringAnalysis]
                  @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @ResultSetArtNormalisiert
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @AgentMonitoringJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT, @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT, @ErrorMessageOut = @ChildErrorMessage OUTPUT;
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES
            (N'USP_AgentMonitoringAnalysis', COALESCE(@ChildStatus, 'ERROR_HANDLED'), @ChildErrorNumber, @ChildErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT [#InfrastructureAnalysis_ModuleStatus] VALUES (N'USP_AgentMonitoringAnalysis', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    DECLARE @OverallStatus varchar(40) =
        CASE WHEN EXISTS
                  (SELECT 1 FROM [#InfrastructureAnalysis_ModuleStatus]
                   WHERE [StatusCode] NOT IN ('EXECUTED','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE'))
             THEN 'AVAILABLE_LIMITED'
             WHEN EXISTS (SELECT 1 FROM [#InfrastructureAnalysis_ModuleStatus] WHERE [StatusCode] = 'AVAILABLE_WITH_FINDING')
             THEN 'AVAILABLE_WITH_FINDING'
             ELSE 'AVAILABLE' END;
    DECLARE @IsPartial bit = CONVERT(bit,
        CASE WHEN EXISTS
             (SELECT 1 FROM [#InfrastructureAnalysis_ModuleStatus]
              WHERE [StatusCode] NOT IN ('EXECUTED','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE'))
             THEN 1 ELSE 0 END);

    IF @ResultSetArtNormalisiert <> 'NONE'
    BEGIN
        SELECT
              @CollectionTimeUtc AS [CollectionTimeUtc]
            , CAST(N'monitor.USP_InfrastructureAnalysis' AS nvarchar(256)) AS [ModuleName]
            , @OverallStatus AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , CONVERT(bigint, (SELECT COUNT_BIG(*) FROM [#InfrastructureAnalysis_ModuleStatus])) AS [ModuleCount]
            , CONVERT(bigint, (SELECT COUNT_BIG(*) FROM [#InfrastructureAnalysis_ModuleStatus]
                               WHERE [StatusCode] NOT IN ('EXECUTED','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE'))) AS [ProblemModuleCount];

        IF @ResultSetArtNormalisiert = 'RAW'
        BEGIN
            SELECT [ModuleName], [StatusCode], [ErrorNumber], [ErrorMessage]
            FROM [#InfrastructureAnalysis_ModuleStatus]
            ORDER BY [ModuleName];
        END;
        ELSE
        BEGIN
            SELECT
                  N'Infrastruktur-Modul' AS [Ergebnis]
                , [ModuleName] AS [Modul]
                , [StatusCode] AS [Status]
                , [ErrorNumber] AS [Fehlernummer]
                , [ErrorMessage] AS [Fehlermeldung]
            FROM [#InfrastructureAnalysis_ModuleStatus]
            ORDER BY [ModuleName];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT
                  N'InfrastructureAnalysis' AS [resultName]
                , 1 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @OverallStatus AS [statusCode]
                , @IsPartial AS [isPartial]
                , @MaxZeilen AS [requestedMaxRows]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @WarningsJson nvarchar(max) =
            (SELECT * FROM [#InfrastructureAnalysis_ModuleStatus]
             WHERE [StatusCode] NOT IN ('EXECUTED','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE')
             ORDER BY [ModuleName] FOR JSON PATH, INCLUDE_NULL_VALUES);

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"agent":', COALESCE(JSON_QUERY(@AgentJson), N'null')
            , N',"agentJobs":', COALESCE(JSON_QUERY(@AgentJobsJson), N'null')
            , N',"resourceGovernor":', COALESCE(JSON_QUERY(@ResourceGovernorJson), N'null')
            , N',"availabilityGroups":', COALESCE(JSON_QUERY(@AvailabilityGroupsJson), N'null')
            , N',"backupRecovery":', COALESCE(JSON_QUERY(@BackupRecoveryJson), N'null')
            , N',"logShipping":', COALESCE(JSON_QUERY(@LogShippingJson), N'null')
            , N',"replication":', COALESCE(JSON_QUERY(@ReplicationJson), N'null')
            , N',"dataCapture":', COALESCE(JSON_QUERY(@DataCaptureJson), N'null')
            , N',"backupChain":', COALESCE(JSON_QUERY(@BackupChainJson), N'null')
            , N',"availabilityDeep":', COALESCE(JSON_QUERY(@AvailabilityDeepJson), N'null')
            , N',"agentMonitoring":', COALESCE(JSON_QUERY(@AgentMonitoringJson), N'null')
            , N',"warnings":', COALESCE(@WarningsJson, N'[]')
            , N'}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#InfrastructureAnalysis_ModuleStatus'
            , @ResultLabel=N'InfrastructureAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#InfrastructureAnalysis_ModuleStatus'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

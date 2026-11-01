USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_AuditConfigurationAnalysis
Version      : 1.0.0
Stand        : 2026-09-19
Zweck        : Die Procedure inventarisiert die sichtbare SQL-Server-Auditkonfiguration
               und deren zur Laufzeit gemeldeten Zustand. Datenbankspezifikationen
               werden je ausgewählter sichtbarer Online-Datenbank gelesen.
Datenquellen : sys.server_audits, sys.server_audit_specifications,
               sys.server_audit_specification_details,
               sys.database_audit_specifications,
               sys.database_audit_specification_details, optional
               sys.dm_server_audit_status.
Datenschutz  : Liest weder Auditdateien noch Auditlog-Payloads, Dateipfade,
               Ereignisinhalte oder überwachte Nutzdaten.
Nebenwirkung : Read-only. Es werden keine Auditobjekte erstellt, gestartet,
               gestoppt, geändert oder gelöscht.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_AuditConfigurationAnalysis]
      @DatabaseNames                nvarchar(max) = NULL
    , @SystemdatenbankenEinbeziehen bit           = 0
    , @DatabaseNamePattern          nvarchar(4000)= NULL
    , @HighImpactConfirmed          bit           = 0
    , @AuditNames                   nvarchar(max) = NULL
    , @AuditNamePattern             nvarchar(4000)= NULL
    , @NurProblematisch             bit           = 0
    , @MaxZeilen                    int           = 1000
    , @LockTimeoutMs                int           = 0
    , @ResultSetArt                 varchar(16)   = 'CONSOLE'
    , @ResultTablesJson             nvarchar(max) = NULL
    , @JsonErzeugen                 bit           = 0
    , @Json                         nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen               bit           = 1
    , @Hilfe                        bit           = 0
    , @StatusCodeOut                varchar(40)   = NULL OUTPUT
    , @IsPartialOut                 bit           = NULL OUTPUT
    , @ErrorNumberOut               int           = NULL OUTPUT
    , @ErrorMessageOut              nvarchar(2048)= NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME();
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableRequested bit=CASE WHEN @OutputMode='TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0,@ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@CrossDatabaseRequested bit=0;
    DECLARE @AuditPatternMode varchar(8),@AuditPatternValue nvarchar(4000),@AuditPatternFlags varchar(8),@AuditPatternValid bit;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_AuditConfigurationAnalysis';
        PRINT N'Inventarisiert sichtbare Auditkonfiguration, Spezifikationen und verfügbaren Runtimezustand; Dateien, Pfade, Ereignisinhalte und überwachte Nutzdaten werden nicht gelesen.';
        PRINT N'Datenbank- und Auditnamenfilter sind jeweils exklusiv mit ihrem Pattern. Auditpattern unterstützen nur LIKE.';
        PRINT N'@MaxZeilen begrenzt jedes Fachresultat; Status und Warnings bleiben ungekürzt.';
        PRINT N'RAW, CONSOLE, TABLE und NONE steuern Resultsets; JSON wird mit @JsonErzeugen angefordert.';
        PRINT N'@Hilfe=1 druckt Hilfe und kehrt ohne Analyse zurück.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Filter für lokale Spezifikationen. NULL, Leertext oder nur U+0020-Leerzeichen: sichtbare, zugreifbare ONLINE-Benutzerdatenbanken ohne Datenbanksnapshots; Systemdatenbanken nur mit Opt-in. Sonst bracket-aware Pipe-Liste exakter SQL-Namen; Pipes in [Klammern] trennen nicht, ]] maskiert ]. Leere/ungültige Segmente oder Namen sind ungültig. Nur eine aktive, nichtleere Liste ist mit einem nicht-NULL-Pattern unvereinbar. Fehlende, offline oder nicht zugängliche Namen erzeugen interne Kandidatenwarnungen, die diese Procedure nicht ausgibt und nicht allein in ihre Partialitätsbewertung übernimmt. Eine leere Spezifikationsmenge belegt deshalb keine vollständige Auswahl.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt master, tempdb, model und msdb aus; 1 erlaubt sie. NULL ist im Kandidatenhelper ungültig und setzt INVALID_PARAMETER. Explizit angeforderte Systemdatenbanken ohne Opt-in erzeugen intern SYSTEM_DATABASE_EXCLUDED; diese Auswahlwarnung wird nicht ausgegeben. Weitergabe an den Kandidatenhelper. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Alternativer Datenbankfilter, unvereinbar mit einer aktiven nichtleeren Datenbankliste. NULL: kein Pattern. Helper trimmt außen; erkennt LIKE:, REGEX:, REGEXI: ohne Beachtung der Großschreibung, sonst LIKE. Rest wird nicht erneut getrimmt. REGEX arbeitet case-sensitiv (Flag c), REGEXI ohne Beachtung der Groß-/Kleinschreibung (Flag i); leerer Rest ungültig. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE; Syntax wird nicht vorab geprüft. Eine fehlerhafte Regex kann bei REGEXP_LIKE im Kandidatenhelper einen nicht abgefangenen Fehler auslösen und den normalen Modulabschluss umgehen.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. 0 und 1 sind gültige Bestätigungswerte, werden in diesem Aufruf aber keinem Analyseklassen-/Gruppengate vorgelegt: AnalysisClass ist fest NULL. Beide Werte aktivieren dasselbe lesende Inventar. NULL ist im Kandidatenhelper ungültig und setzt INVALID_PARAMETER; der Wert ist keine Berechtigungserteilung. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@AuditNames nvarchar(max); Default: NULL. Exakte Auditnamen für audits und beide Spezifikationsscopes als bracket-aware Pipe-Liste; NULL: kein Filter. Pipes in [Klammern] trennen nicht, ]] maskiert ]. Leere Segmente und ungültige SQL-Namen sind ungültig; gültige Werte werden dedupliziert. Exklusiv mit @AuditNamePattern. Vergleich ist SQL_Latin1_General_CP1_CS_AS (case-sensitive); kein Treffer erzeugt keinen eigenen Fehlerstatus.';
        PRINT N'@AuditNamePattern nvarchar(4000); Default: NULL. Alternativer Auditnamenfilter mit LIKE, exklusiv mit @AuditNames. NULL: kein Filter. Parser trimmt außen, entfernt optional LIKE: ohne Groß-/Kleinschreibung und trimmt danach nicht erneut. REGEX:/REGEXI: werden erkannt, aber von dieser Procedure als INVALID_PARAMETER zurückgewiesen. Leerwert/Leerrest ungültig. Vergleich case-sensitive. Dieses Pattern begrenzt ausschließlich audits; serverSpecifications und databaseSpecifications werden dadurch nicht gefiltert. Für einen Namensfilter in allen drei Fachmengen ist stattdessen @AuditNames zu verwenden.';
        PRINT N'@NurProblematisch bit; Default: 0. 0 lässt INFO und MEDIUM in den drei Fachresultaten zu. 1 entfernt INFO; NULL entfernt INFO ebenfalls und wirkt wie 1. Quellenstatus und Warnings bleiben ungefiltert; Warnings entstehen vor diesem INFO-Filter. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@MaxZeilen int; Default: 1000. Obergrenze je Fachresultat einzeln. Reihenfolge: AuditName/AuditId, SpecificationName/SpecificationId, DatabaseName/SpecificationName/DatabaseId/SpecificationId. NULL oder 0 unbegrenzt; negative Werte INVALID_PARAMETER. Quellenstatus, Warnings und Statusresultat bleiben ungekürzt.';
        PRINT N'@LockTimeoutMs int; Default: 0. Wird nur auf negative Werte geprüft; im Body aber nicht zum Setzen eines Timeouts genutzt. NULL besteht den Negativtest und wird nicht angewendet. Die Procedure setzt danach LOCK_TIMEOUT 0; SET-Werte werden bei Rückkehr aus der Procedure zurückgenommen.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Entfernen äußerer U+0020-Leerzeichen und Großschreibung sind genau RAW, CONSOLE, TABLE und NONE erlaubt. RAW liefert Modulstatus und danach audits, serverSpecifications, databaseSpecifications, sourceStatus, warnings. CONSOLE wird intern auf NONE normalisiert und zeigt ausschließlich die beschriftete audits-Ansicht, ohne separates Modulstatusresultset. TABLE schreibt nur zugeordnete Gruppen, NONE liefert keine regulären Resultsets. JSON wird unabhängig gesteuert. NULL, Leertext und andere Werte sind ungültig.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE; gültiges JSON-Objekt mit mindestens einer Zuordnung aus exakt audits, serverSpecifications, databaseSpecifications, sourceStatus, warnings zu einem Ziel. Keys binär exakt, keine doppelten Keys/Ziele. Ziel: vorhandene leere lokale #Temp mit genau einer Seed-Spalte, max. 116 Zeichen, kein ##- oder reserviertes #Monitor-Präfix. Mapping wird vor fachlichem Zugriff validiert; Bei einem ungültigen Ziel kann der Helper mit Fehler 51011 abbrechen; dann ist die abschließende Zuweisung der Modul-OUTPUTs nicht garantiert. audits bedeutet Auditkonfigurationen, serverSpecifications Serverspezifikationen, databaseSpecifications Datenbankspezifikationen, sourceStatus Quellenstatus und warnings Warnungen. In TABLE sind NULL, Leertext und ein leeres Objekt ungültig. Außerhalb von TABLE bleiben NULL, Leertext und nur U+0020-Leerzeichen unbeachtet; ein anderer nichtleerer Wert kann vor der Analyse Fehler 51011 auslösen.';
        PRINT N'@JsonErzeugen bit; Default: 0. 1 erstellt JSON in @Json; 0 oder NULL erzeugt keines. Unabhängig von Resultsetart; für JSON ohne Resultsets NONE verwenden. Dokument enthält meta und fünf Arrays audits, serverSpecifications, databaseSpecifications, sourceStatus, warnings. meta: resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, crossDatabaseRequested. Facharrays wenden Filter und Limit an; Status/Warnungen bleiben vollständig. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Empfänger. Zu Beginn NULL; bei JsonErzeugen=1 Dokument, sonst NULL. OUTPUT-Variable nvarchar(max) mit OUTPUT im EXEC binden. Hilfe kehrt vorher zurück und lässt den Wert NULL. Der Empfänger kann ausgelassen werden, wenn kein JSON empfangen werden soll.';
        PRINT N'@PrintMeldungen bit; Default: 1. Der Parameter wird im Procedure-Body nicht gelesen und beeinflusst weder PRINT-Meldungen noch Resultsets. Der Hilfezweig gibt seine PRINT-Zeilen unabhängig von diesem Eingabewert aus. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Hilfe bit; Default: 0. 1 gibt PRINT-Hilfe aus und kehrt ohne Analyse und abschließende OUTPUT-Zuweisung zurück. Die Hilfe erklärt Zweck, Parameterverträge und Beispielaufrufe. 0 führt aus; NULL löst Früh-Rückkehr nicht aus. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Bei regulärem Abschluss: AVAILABLE ohne gemeldeten Befund, AVAILABLE_WITH_FINDING bei MEDIUM-Warnungen ohne Partialität, AVAILABLE_LIMITED bei partiellen Quellen, INVALID_PARAMETER bei ungültigen Modul-/Kandidatenparametern, INTERNAL_ERROR bei internem Kandidatenschemafehler, UNAVAILABLE_FEATURE bei fehlender Regex-Voraussetzung. Behandelte Quellenfehler stehen in Quellenstatus/Warnungen; Partialität setzt AVAILABLE_LIMITED. Zuweisung erfolgt am normalen Ende. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Im Hilfezweig bleibt ein anfänglicher NULL- oder anderer Empfängerwert erhalten.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. OUTPUT-Bit der Partialität: 0 ohne partielle Quellenlesung, 1 bei behandelten unvollständigen Lesungen. Normale Endzuweisung; Hilfe weist nicht zu. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Im Hilfezweig bleibt ein anfänglicher NULL- oder anderer Empfängerwert erhalten. Interne Kandidatenwarnungen über fehlende oder ausgeschlossene Namen werden hierbei nicht ausgewertet; 0 belegt keine vollständige Datenbanksicht.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT int der zuerst gespeicherten behandelten Serverquellen-Fehlernummer. Zweiter Server-CATCH setzt nur bei noch NULL. Datenbank-CATCHes setzen Partialität und schreiben interne, nicht ausgegebene Warnungen, aber keine Modulnummer. Parameterfehler haben keine Fehlernummer; Hilfe weist nicht zu. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Im Hilfezweig bleibt ein anfänglicher NULL- oder anderer Empfängerwert erhalten.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT nvarchar(2048) zur zuerst gespeicherten Serverquellenstörung; spätere Serverfehler überschreiben sie nicht. Datenbankfehler setzen Partialität und schreiben interne, nicht ausgegebene Warnungen statt einer Modulmeldung. Ungültige Parameter liefern Validierungstext; Hilfe weist nicht zu. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Im Hilfezweig bleibt ein anfänglicher NULL- oder anderer Empfängerwert erhalten.';
        PRINT N'EXEC [monitor].[USP_AuditConfigurationAnalysis] @ResultSetArt=''RAW'', @MaxZeilen=100;';
        PRINT N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_AuditConfigurationAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'CREATE TABLE [#AuditConfigurationAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N''{"audits":"#AuditConfigurationAnalysis_HelpExample"}'';
BEGIN TRY
    EXEC [monitor].[USP_AuditConfigurationAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@Map;
    SELECT * FROM [#AuditConfigurationAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#AuditConfigurationAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#AuditConfigurationAnalysis_HelpExample];
    THROW;
END CATCH;';
        PRINT N'EXEC [monitor].[USP_AuditConfigurationAnalysis] @Hilfe=1;';




        RETURN;
    END;

    CREATE TABLE [#AuditConfigurationAnalysis_ResultTables]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    IF @TableRequested=1
        EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
             @AllowedResultNames=N'audits|serverSpecifications|databaseSpecifications|sourceStatus|warnings',
             @MappingTable=N'#AuditConfigurationAnalysis_ResultTables',@ThrowOnError=1;
    IF @TableRequested=1 OR @ConsoleResultRequested=1 SET @OutputMode='NONE';

    CREATE TABLE [#AuditConfigurationAnalysis_DatabaseCandidates]
    (
        [DatabaseId] int NOT NULL PRIMARY KEY,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsReadOnly] bit NULL,[CompatibilityLevel] tinyint NULL,
        [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsSystemDatabase] bit NULL,[RequestedOrdinal] int NULL
    );
    CREATE TABLE [#AuditConfigurationAnalysis_DatabaseWarnings]([RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#AuditConfigurationAnalysis_AuditFilter]([NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY);
    CREATE TABLE [#AuditConfigurationAnalysis_Audits]
    (
        [AuditId] uniqueidentifier NOT NULL PRIMARY KEY,[AuditName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [AuditTargetType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[OnFailure] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QueueDelayMilliseconds] int NULL,
        [IsEnabled] bit NULL,[RuntimeStatus] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RuntimeStatusTime] datetime NULL,
        [ServerSpecificationCount] bigint NULL,[DatabaseSpecificationCount] bigint NULL,[FindingCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#AuditConfigurationAnalysis_ServerSpecifications]
    (
        [SpecificationId] int NOT NULL PRIMARY KEY,[SpecificationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [AuditId] uniqueidentifier NULL,[AuditName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsEnabled] bit NULL,[ActionCount] bigint NULL,
        [HasAllServerScope] bit NULL,[FindingCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#AuditConfigurationAnalysis_DatabaseSpecifications]
    (
        [DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SpecificationId] int NOT NULL,[SpecificationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [AuditId] uniqueidentifier NULL,[AuditName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsEnabled] bit NULL,[ActionCount] bigint NULL,
        [HasAllDatabaseScope] bit NULL,[FindingCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        PRIMARY KEY([DatabaseId],[SpecificationId])
    );
    CREATE TABLE [#AuditConfigurationAnalysis_SourceStatus]
    (
        [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,
        [ReturnedRowCount] bigint NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#AuditConfigurationAnalysis_Warnings]
    (
        [WarningScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[AuditName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[WarningSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    SELECT @AuditPatternMode=[PatternMode],@AuditPatternValue=[PatternValue],@AuditPatternFlags=[RegexFlags],@AuditPatternValid=[IsValid]
    FROM [monitor].[TVF_ParsePattern](@AuditNamePattern);
    IF @MaxZeilen<0 OR @LockTimeoutMs<0 OR @OutputMode NOT IN('RAW','CONSOLE','NONE')
       OR @AuditPatternValid=0 OR @AuditPatternMode IN('REGEX','REGEXI')
       OR (@AuditNames IS NOT NULL AND @AuditNamePattern IS NOT NULL)
       OR (@AuditNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@AuditNames) WHERE [IsValid]=0))
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'Ungueltiger Ausgabe-, Limit-, Auditnamen- oder Patternparameter. Regex wird von dieser Procedure nicht unterstuetzt.';

    IF @AuditNames IS NOT NULL
        INSERT [#AuditConfigurationAnalysis_AuditFilter]([NameValue])
        SELECT [NameValue] FROM [monitor].[TVF_ParseSqlNameList](@AuditNames) WHERE [IsValid]=1 GROUP BY [NameValue];

    IF @StatusCode='AVAILABLE'
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,
              @DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed,@AnalysisClass=NULL,
              @StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,
              @CandidateTable=N'#AuditConfigurationAnalysis_DatabaseCandidates',@WarningTable=N'#AuditConfigurationAnalysis_DatabaseWarnings';

    SET LOCK_TIMEOUT 0;
    IF @StatusCode='AVAILABLE'
    BEGIN
        BEGIN TRY
            INSERT [#AuditConfigurationAnalysis_Audits]
            ([AuditId],[AuditName],[AuditTargetType],[OnFailure],[QueueDelayMilliseconds],[IsEnabled],[RuntimeStatus],[RuntimeStatusTime],[ServerSpecificationCount],[DatabaseSpecificationCount],[FindingCode],[FindingSeverity],[EvidenceLimit])
            SELECT [a].[audit_guid],[a].[name],[a].[type_desc],[a].[on_failure_desc],[a].[queue_delay],[a].[is_state_enabled],
                   [r].[status_desc],[r].[status_time],
                   (SELECT COUNT_BIG(*) FROM [sys].[server_audit_specifications] [ss] WITH(NOLOCK) WHERE [ss].[audit_guid]=[a].[audit_guid]),
                   NULL,
                   CASE WHEN [a].[is_state_enabled]=0 THEN 'AUDIT_DISABLED' WHEN [r].[status_desc] IS NOT NULL AND [r].[status_desc] NOT IN(N'STARTED',N'RUNNING') THEN 'AUDIT_RUNTIME_NOT_STARTED' ELSE 'AUDIT_CONFIGURED' END,
                   CASE WHEN [a].[is_state_enabled]=0 THEN 'MEDIUM' WHEN [r].[status_desc] IS NOT NULL AND [r].[status_desc] NOT IN(N'STARTED',N'RUNNING') THEN 'MEDIUM' ELSE 'INFO' END,
                   N'Auditziele, Dateipfade und Auditereignisse werden nicht gelesen oder ausgegeben.'
            FROM [sys].[server_audits] [a] WITH(NOLOCK)
            LEFT JOIN [sys].[dm_server_audit_status] [r] WITH(NOLOCK) ON [r].[audit_id]=[a].[audit_id]
            WHERE (@AuditNames IS NULL OR EXISTS(SELECT 1 FROM [#AuditConfigurationAnalysis_AuditFilter] [f] WHERE [f].[NameValue]=[a].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))
              AND (@AuditPatternMode IN('NONE','REGEX','REGEXI') OR [a].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @AuditPatternValue COLLATE SQL_Latin1_General_CP1_CS_AS);
            INSERT [#AuditConfigurationAnalysis_SourceStatus] VALUES(N'sys.server_audits + sys.dm_server_audit_status','AVAILABLE',0,@@ROWCOUNT,N'Konfiguration und sichtbarer Runtimezustand; keine Auditpayloads oder Pfade.');
        END TRY
        BEGIN CATCH
            INSERT [#AuditConfigurationAnalysis_SourceStatus] VALUES(N'sys.server_audits + sys.dm_server_audit_status',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,15562) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,NULL,N'Auditkonfiguration oder Runtimezustand war nicht vollstaendig lesbar.');
            SELECT @IsPartial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
        END CATCH;

        BEGIN TRY
            INSERT [#AuditConfigurationAnalysis_ServerSpecifications]
            ([SpecificationId],[SpecificationName],[AuditId],[AuditName],[IsEnabled],[ActionCount],[HasAllServerScope],[FindingCode],[FindingSeverity],[EvidenceLimit])
            SELECT [s].[server_specification_id],[s].[name],[s].[audit_guid],[a].[name],[s].[is_state_enabled],COUNT_BIG([d].[audit_action_id]),
                   CONVERT(bit,MAX(CASE WHEN [d].[audit_action_name] LIKE N'%ALL SERVER%' THEN 1 ELSE 0 END)),
                   CASE WHEN [s].[is_state_enabled]=0 THEN 'SERVER_SPECIFICATION_DISABLED' WHEN COUNT_BIG([d].[audit_action_id])=0 THEN 'SERVER_SPECIFICATION_WITHOUT_ACTION' ELSE 'SERVER_SPECIFICATION_CONFIGURED' END,
                   CASE WHEN [s].[is_state_enabled]=0 OR COUNT_BIG([d].[audit_action_id])=0 THEN 'MEDIUM' ELSE 'INFO' END,
                   N'Nur Aktionsanzahl und Scopehinweis; keine Auditereignisse oder ueberwachten Nutzdaten.'
            FROM [sys].[server_audit_specifications] [s] WITH(NOLOCK)
            LEFT JOIN [sys].[server_audits] [a] WITH(NOLOCK) ON [a].[audit_guid]=[s].[audit_guid]
            LEFT JOIN [sys].[server_audit_specification_details] [d] WITH(NOLOCK) ON [d].[server_specification_id]=[s].[server_specification_id]
            WHERE @AuditNames IS NULL OR EXISTS(SELECT 1 FROM [#AuditConfigurationAnalysis_AuditFilter] [f] WHERE [f].[NameValue]=[a].[name] COLLATE SQL_Latin1_General_CP1_CS_AS)
            GROUP BY [s].[server_specification_id],[s].[name],[s].[audit_guid],[a].[name],[s].[is_state_enabled];
            INSERT [#AuditConfigurationAnalysis_SourceStatus] VALUES(N'sys.server_audit_specifications + sys.server_audit_specification_details','AVAILABLE',0,@@ROWCOUNT,N'Serverseitige Spezifikationsmetadaten werden aggregiert; Detailaktionen werden nicht ausgegeben.');
        END TRY
        BEGIN CATCH
            INSERT [#AuditConfigurationAnalysis_SourceStatus] VALUES(N'sys.server_audit_specifications + sys.server_audit_specification_details',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,15562) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,NULL,N'Serverseitige Spezifikationsmetadaten waren nicht vollstaendig lesbar.');
            SELECT @IsPartial=1,@ErrorNumber=COALESCE(@ErrorNumber,ERROR_NUMBER()),@ErrorMessage=COALESCE(@ErrorMessage,ERROR_MESSAGE());
        END CATCH;

        DECLARE @DatabaseId int,@DatabaseName sysname,@Sql nvarchar(max),@HasAuditNames bit=CASE WHEN @AuditNames IS NULL THEN 0 ELSE 1 END;
        DECLARE [audit_database_cursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId],[DatabaseName] FROM [#AuditConfigurationAnalysis_DatabaseCandidates] WHERE [StateDesc]=N'ONLINE' ORDER BY [DatabaseId];
        OPEN [audit_database_cursor]; FETCH NEXT FROM [audit_database_cursor] INTO @DatabaseId,@DatabaseName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            BEGIN TRY
                SET @Sql=N'INSERT [#AuditConfigurationAnalysis_DatabaseSpecifications]([DatabaseId],[DatabaseName],[SpecificationId],[SpecificationName],[AuditId],[AuditName],[IsEnabled],[ActionCount],[HasAllDatabaseScope],[FindingCode],[FindingSeverity],[EvidenceLimit])
                SELECT @pDatabaseId,@pDatabaseName,[s].[database_specification_id],[s].[name],[s].[audit_guid],[a].[name],[s].[is_state_enabled],COUNT_BIG([d].[audit_action_id]),CONVERT(bit,MAX(CASE WHEN [d].[audit_action_name] LIKE N''%ALL DATABASE%'' THEN 1 ELSE 0 END)),
                CASE WHEN [s].[is_state_enabled]=0 THEN ''DATABASE_SPECIFICATION_DISABLED'' WHEN COUNT_BIG([d].[audit_action_id])=0 THEN ''DATABASE_SPECIFICATION_WITHOUT_ACTION'' ELSE ''DATABASE_SPECIFICATION_CONFIGURED'' END,
                CASE WHEN [s].[is_state_enabled]=0 OR COUNT_BIG([d].[audit_action_id])=0 THEN ''MEDIUM'' ELSE ''INFO'' END,N''Nur Aktionsanzahl und Scopehinweis; keine Auditereignisse oder ueberwachten Nutzdaten.''
                FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[database_audit_specifications] [s] WITH(NOLOCK)
                LEFT JOIN [sys].[server_audits] [a] WITH(NOLOCK) ON [a].[audit_guid]=[s].[audit_guid]
                LEFT JOIN '+QUOTENAME(@DatabaseName)+N'.[sys].[database_audit_specification_details] [d] WITH(NOLOCK) ON [d].[database_specification_id]=[s].[database_specification_id]
                WHERE (@pAuditNames=0 OR EXISTS(SELECT 1 FROM [#AuditConfigurationAnalysis_AuditFilter] [f] WHERE [f].[NameValue]=[a].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))
                GROUP BY [s].[database_specification_id],[s].[name],[s].[audit_guid],[a].[name],[s].[is_state_enabled];';
                EXEC [sys].[sp_executesql] @Sql,N'@pDatabaseId int,@pDatabaseName sysname,@pAuditNames bit',@pDatabaseId=@DatabaseId,@pDatabaseName=@DatabaseName,@pAuditNames=@HasAuditNames;
            END TRY
            BEGIN CATCH
                SET @IsPartial=1;
                INSERT [#AuditConfigurationAnalysis_DatabaseWarnings] VALUES(@DatabaseName,CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916,15562) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,N'Datenbank-Auditspezifikationen waren fuer diese Datenbank nicht lesbar.');
            END CATCH;
            FETCH NEXT FROM [audit_database_cursor] INTO @DatabaseId,@DatabaseName;
        END;
        CLOSE [audit_database_cursor]; DEALLOCATE [audit_database_cursor];
        INSERT [#AuditConfigurationAnalysis_SourceStatus]
        SELECT N'sys.database_audit_specifications + sys.database_audit_specification_details',CASE WHEN @IsPartial=1 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END,@IsPartial,COUNT_BIG(*),N'Datenbanklokale Spezifikationsmetadaten werden je sichtbarer Online-Datenbank isoliert gelesen.'
        FROM [#AuditConfigurationAnalysis_DatabaseSpecifications];

        UPDATE [a] SET [DatabaseSpecificationCount]=[x].[CountValue]
        FROM [#AuditConfigurationAnalysis_Audits] [a]
        OUTER APPLY(SELECT COUNT_BIG(*) [CountValue] FROM [#AuditConfigurationAnalysis_DatabaseSpecifications] [d] WHERE [d].[AuditId]=[a].[AuditId]) [x];
        INSERT [#AuditConfigurationAnalysis_Warnings]
        SELECT 'AUDIT',NULL,[AuditName],[FindingCode],[FindingSeverity],[EvidenceLimit] FROM [#AuditConfigurationAnalysis_Audits] WHERE [FindingSeverity]<>'INFO'
        UNION ALL SELECT 'SERVER_SPECIFICATION',NULL,[AuditName],[FindingCode],[FindingSeverity],[EvidenceLimit] FROM [#AuditConfigurationAnalysis_ServerSpecifications] WHERE [FindingSeverity]<>'INFO'
        UNION ALL SELECT 'DATABASE_SPECIFICATION',[DatabaseName],[AuditName],[FindingCode],[FindingSeverity],[EvidenceLimit] FROM [#AuditConfigurationAnalysis_DatabaseSpecifications] WHERE [FindingSeverity]<>'INFO';

        IF EXISTS(SELECT 1 FROM [#AuditConfigurationAnalysis_SourceStatus] WHERE [IsPartial]=1) SELECT @StatusCode='AVAILABLE_LIMITED',@IsPartial=1;
        ELSE IF EXISTS(SELECT 1 FROM [#AuditConfigurationAnalysis_Warnings] WHERE [WarningSeverity]='MEDIUM') SET @StatusCode='AVAILABLE_WITH_FINDING';
    END;

    DELETE FROM [#AuditConfigurationAnalysis_Audits] WHERE (@NurProblematisch=1 OR @NurProblematisch IS NULL) AND [FindingSeverity]='INFO';
    DELETE FROM [#AuditConfigurationAnalysis_ServerSpecifications] WHERE (@NurProblematisch=1 OR @NurProblematisch IS NULL) AND [FindingSeverity]='INFO';
    DELETE FROM [#AuditConfigurationAnalysis_DatabaseSpecifications] WHERE (@NurProblematisch=1 OR @NurProblematisch IS NULL) AND [FindingSeverity]='INFO';

    ;WITH [RankedAudits] AS
    (
        SELECT *,ROW_NUMBER() OVER (ORDER BY [AuditName],[AuditId]) AS [OutputOrdinal]
        FROM [#AuditConfigurationAnalysis_Audits]
    )
    DELETE FROM [RankedAudits] WHERE [OutputOrdinal]>@Limit;
    ;WITH [RankedServerSpecifications] AS
    (
        SELECT *,ROW_NUMBER() OVER (ORDER BY [SpecificationName],[SpecificationId]) AS [OutputOrdinal]
        FROM [#AuditConfigurationAnalysis_ServerSpecifications]
    )
    DELETE FROM [RankedServerSpecifications] WHERE [OutputOrdinal]>@Limit;
    ;WITH [RankedDatabaseSpecifications] AS
    (
        SELECT *,ROW_NUMBER() OVER (ORDER BY [DatabaseName],[SpecificationName],[DatabaseId],[SpecificationId]) AS [OutputOrdinal]
        FROM [#AuditConfigurationAnalysis_DatabaseSpecifications]
    )
    DELETE FROM [RankedDatabaseSpecifications] WHERE [OutputOrdinal]>@Limit;

    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
    IF @JsonErzeugen=1
    BEGIN
        DECLARE @Meta nvarchar(max)=(SELECT N'AuditConfigurationAnalysis' [resultName],1 [schemaVersion],@Now [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@CrossDatabaseRequested [crossDatabaseRequested] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"audits":',COALESCE((SELECT TOP(@Limit) * FROM [#AuditConfigurationAnalysis_Audits] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [AuditName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),N',"serverSpecifications":',COALESCE((SELECT TOP(@Limit) * FROM [#AuditConfigurationAnalysis_ServerSpecifications] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [SpecificationName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),N',"databaseSpecifications":',COALESCE((SELECT TOP(@Limit) * FROM [#AuditConfigurationAnalysis_DatabaseSpecifications] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [DatabaseName],[SpecificationName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),N',"sourceStatus":',COALESCE((SELECT * FROM [#AuditConfigurationAnalysis_SourceStatus] ORDER BY [SourceName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),N',"warnings":',COALESCE((SELECT * FROM [#AuditConfigurationAnalysis_Warnings] ORDER BY [WarningScope],[DatabaseName],[AuditName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),N'}');
    END;
    IF @OutputMode='RAW'
    BEGIN
        SELECT N'USP_AuditConfigurationAnalysis' [ModuleName],@Now [CollectionTimeUtc],@StatusCode [StatusCode],@IsPartial [IsPartial],@ErrorNumber [ErrorNumber],@ErrorMessage [ErrorMessage];
        SELECT TOP(@Limit) * FROM [#AuditConfigurationAnalysis_Audits] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [AuditName];
        SELECT TOP(@Limit) * FROM [#AuditConfigurationAnalysis_ServerSpecifications] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [SpecificationName];
        SELECT TOP(@Limit) * FROM [#AuditConfigurationAnalysis_DatabaseSpecifications] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [DatabaseName],[SpecificationName];
        SELECT * FROM [#AuditConfigurationAnalysis_SourceStatus] ORDER BY [SourceName]; SELECT * FROM [#AuditConfigurationAnalysis_Warnings] ORDER BY [WarningScope],[DatabaseName],[AuditName];
    END
    ELSE IF @OutputMode='CONSOLE'
    BEGIN
        SELECT N'Auditkonfiguration' [Ergebnis],@Now [Stand_UTC],@StatusCode [Status],@IsPartial [Teilweise],@ErrorMessage [Hinweis];
        SELECT TOP(@Limit) N'Audit' [Ergebnis],[AuditName] [Audit],[AuditTargetType] [Zieltyp],[IsEnabled] [Aktiv],[RuntimeStatus] [Runtime_Status],[ServerSpecificationCount] [Server_Spezifikationen],[DatabaseSpecificationCount] [Datenbank_Spezifikationen],[FindingCode] [Befund],[FindingSeverity] [Prioritaet],[EvidenceLimit] [Evidenzgrenze] FROM [#AuditConfigurationAnalysis_Audits] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [AuditName];
        SELECT TOP(@Limit) N'Server-Auditspezifikation' [Ergebnis],[SpecificationName] [Spezifikation],[AuditName] [Audit],[IsEnabled] [Aktiv],[ActionCount] [Aktionsanzahl],[FindingCode] [Befund],[FindingSeverity] [Prioritaet] FROM [#AuditConfigurationAnalysis_ServerSpecifications] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [SpecificationName];
        SELECT TOP(@Limit) N'Datenbank-Auditspezifikation' [Ergebnis],[DatabaseName] [Datenbank],[SpecificationName] [Spezifikation],[AuditName] [Audit],[IsEnabled] [Aktiv],[ActionCount] [Aktionsanzahl],[FindingCode] [Befund],[FindingSeverity] [Prioritaet] FROM [#AuditConfigurationAnalysis_DatabaseSpecifications] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [DatabaseName],[SpecificationName];
        SELECT N'Quellenstatus' [Ergebnis],[SourceName] [Quelle],[StatusCode] [Status],[IsPartial] [Teilweise],[Detail] [Hinweis] FROM [#AuditConfigurationAnalysis_SourceStatus] ORDER BY [SourceName];
        SELECT N'Warnung' [Ergebnis],[WarningScope] [Scope],[DatabaseName] [Datenbank],[AuditName] [Audit],[WarningCode] [Code],[WarningSeverity] [Prioritaet],[Detail] [Hinweis] FROM [#AuditConfigurationAnalysis_Warnings] ORDER BY [WarningScope],[DatabaseName],[AuditName];
    END;
    IF @ConsoleResultRequested=1 EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#AuditConfigurationAnalysis_Audits',@ResultLabel=N'AuditConfigurationAnalysis',@EmptyMessage=N'Keine sichtbaren Auditkonfigurationen';
    IF @TableRequested=1
    BEGIN
        DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
        DECLARE [audit_table_cursor] CURSOR LOCAL FAST_FORWARD FOR SELECT [ResultName],[TargetTable] FROM [#AuditConfigurationAnalysis_ResultTables] ORDER BY [ResultName];
        OPEN [audit_table_cursor]; FETCH NEXT FROM [audit_table_cursor] INTO @ResultName,@TargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @SourceTable=CASE @ResultName WHEN N'audits' THEN N'#AuditConfigurationAnalysis_Audits' WHEN N'serverSpecifications' THEN N'#AuditConfigurationAnalysis_ServerSpecifications' WHEN N'databaseSpecifications' THEN N'#AuditConfigurationAnalysis_DatabaseSpecifications' WHEN N'sourceStatus' THEN N'#AuditConfigurationAnalysis_SourceStatus' ELSE N'#AuditConfigurationAnalysis_Warnings' END;
            EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,@ThrowOnError=1;
            FETCH NEXT FROM [audit_table_cursor] INTO @ResultName,@TargetTable;
        END;
        CLOSE [audit_table_cursor]; DEALLOCATE [audit_table_cursor];
    END;
END;
GO

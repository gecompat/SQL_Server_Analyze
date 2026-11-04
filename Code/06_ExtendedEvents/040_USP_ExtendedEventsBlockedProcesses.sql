USE [DeineDatenbank];
GO

SET QUOTED_IDENTIFIER ON;
GO

/*
===============================================================================
Objekt       : monitor.USP_ExtendedEventsBlockedProcesses
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Liest bereits erfasste blocked_process_report-Ereignisse aus
               vorhandenen Extended-Events-Targets und zerlegt die Reports in
               Summary-, Blocked- und Blocking-Process-Resultsets.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : vorhandene serverweite XE-Session mit blocked_process_report,
               event_file oder optional ring_buffer; sys.configurations lesend.
Parameter    : @ResolvedSourceExtendedEventSessionName, @Quelle, @FilePath, @VonUtc, @BisUtc,
               @MaxZeilen, @MitReportXml, @MitProcessXml,
               @BestaetigeTargetFlush, @PrintMeldungen, @Hilfe.
Resultsets   : 1. Modulstatus. 2. Report-Summary. 3. blocked process.
               4. blocking process. 5. Quellen-/Fehlerstatus.
Berechtigung : SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE
               STATE oder höher. Das Framework vergibt keine Rechte.
Eigenlast    : Event-Datei- und XML-abhängig; begrenzte Ergebnismenge und
               Vorfilter vor XML-Zerlegung. XEL-Dateien können dennoch vollständig
               gelesen werden müssen.
Locking      : LOCK_TIMEOUT 0; keine Benutzerobjekte und keine Änderungen.
Nebenwirkung : Ringbuffer-Lesen erfordert @BestaetigeTargetFlush=1.
Voraussetzung: Reports existieren nur, wenn blocked process threshold und eine
               erfassende Session bereits außerhalb des Frameworks konfiguriert sind.
Partial      : Fehlende Konfiguration, Session, Datei oder Rechte werden als Status
               gemeldet und brechen andere Monitoring-Funktionen nicht ab.
Beispiele    : EXEC monitor.USP_ExtendedEventsBlockedProcesses;
               EXEC monitor.USP_ExtendedEventsBlockedProcesses
                   @ResolvedSourceExtendedEventSessionName=N'MeineBlockingSession', @Quelle='EVENT_FILE';
               EXEC monitor.USP_ExtendedEventsBlockedProcesses @Hilfe=1;
Änderungen   : 1.0.0 - Erstfassung Phase 5.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ExtendedEventsBlockedProcesses]
      @SourceExtendedEventSessionName nvarchar(258)         = NULL
    , @Quelle                  varchar(20)     = 'AUTO'
    , @FilePath                nvarchar(4000)  = NULL
    , @VonUtc                  datetime2(7)    = NULL
    , @BisUtc                  datetime2(7)    = NULL
    , @MaxZeilen              int             = 200
    , @MitReportXml            bit             = 1
    , @MitProcessXml           bit             = 0
    , @BestaetigeTargetFlush   bit             = 0
    , @HighImpactConfirmed     bit             = 0
    , @ResultSetArt                   varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                   bit            = 0
    , @Json                            nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen          bit             = 1
    , @Hilfe                   bit             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;
    DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'reports',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @ResolvedSourceExtendedEventSessionName sysname=NULL;
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @MonitorPrintMessage nvarchar(2048);

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ExtendedEventsBlockedProcesses';
        PRINT N'@SourceExtendedEventSessionName nvarchar(258). Default ist NULL. Bezeichnet optional eine konkrete vorhandene Session mit blocked_process_report. NULL sucht automatisch nach einer passenden Session. Ein expliziter Wert muss genau einen gültigen, optional geklammerten sysname ergeben. ungültige oder mehrfache Namen führen zu INVALID_PARAMETER. Leertext ist ungültig.';
        PRINT N'@Quelle varchar(20). Default ist ''AUTO''. Geschlossene Auswahl: AUTO wählt EVENT_FILE, wenn ein expliziter oder konfigurierter Dateipfad vorliegt. andernfalls wird RING_BUFFER nur bei bestätigtem Target-Flush gewählt. EVENT_FILE erzwingt das Dateiziel, RING_BUFFER das laufende Ring-Buffer-Ziel. NULL, leer oder ein anderer Wert ist ungültig. Werte werden getrimmt und in Großbuchstaben umgewandelt.';
        PRINT N'@FilePath nvarchar(4000). Default ist NULL. Expliziter XEL-Pfad oder URL. NULL oder leer verwendet den Eventfile-Pfad aus der Sessiondefinition. Endet der Pfad auf .xel, wird die Endung durch *.xel ersetzt. andernfalls wird *.xel angehängt, sofern noch kein * enthalten ist.';
        PRINT N'@VonUtc datetime2(7). Default ist NULL. Untere UTC-Zeitgrenze einschließlich. NULL wird zur Laufzeit auf UTC jetzt minus 24 Stunden gesetzt.';
        PRINT N'@BisUtc datetime2(7). Default ist NULL. Obere UTC-Zeitgrenze ausschließlich. NULL lässt die Obergrenze offen. Sind beide Grenzen gesetzt, muss @VonUtc kleiner als @BisUtc sein.';
        PRINT N'@MaxZeilen int. Default ist 200. Begrenzt die ausgewählten Reports vor der XML-Zerlegung. NULL oder 0 bedeutet unbegrenzt. negative Werte sind ungültig. Die Begrenzung garantiert keinen frühen oder vollständigen Ausschluss des XEL-Dateiscans.';
        PRINT N'@MitReportXml bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert, ob das vollständige blocked_process_report-XML in der Summary ausgegeben wird. 0 unterdrückt die XML-Ausgabe, verhindert aber nicht das Parsing der strukturierten Prozessfelder.';
        PRINT N'@MitProcessXml bit. Default ist 0. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Ausgabe des vollständigen Prozess-XML in den Detailresultaten. 0 unterdrückt diese XML-Ausgabe. strukturierte Prozessfelder werden weiterhin extrahiert.';
        PRINT N'@BestaetigeTargetFlush bit. Default ist 0. 1 bestätigt den möglichen Target-Flush beim Ringbuffer-Lesen. 0 sperrt den expliziten Ringbufferzugriff. Beim expliziten Aufruf kann NULL die bestehende Prüfung auf 0 passieren. Verwenden Sie ausdrücklich 0 oder 1. AUTO wechselt nur bei 1 zum Ringbuffer.';
        PRINT N'@HighImpactConfirmed bit. Default ist 0. 1 bestätigt einen geschützten Pfad nach der aktiven Policy für EXTENDED_EVENTS_FORENSICS_DEEP. 0 bestätigt ihn nicht. NULL ist für die Gate-Prüfung ungültig. Die aktuelle Berechtigung wird zusätzlich geprüft.';
        PRINT N'@ResultSetArt varchar(16). Default ist ''CONSOLE''. Geschlossene Auswahl nach Trimmen und Umwandlung in Großbuchstaben: RAW gibt technische Rohresultate aus, CONSOLE dient der interaktiven Ausgabe, NONE unterdrückt Resultsets zugunsten des OUTPUT-JSON, TABLE schreibt das registrierte Fachresultat in ein bereitgestelltes Ziel. CONSOLE und TABLE werden intern auf NONE gesetzt. NULL, leer und andere Werte sind ungültig.';
        PRINT N'@ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem Schlüssel reports erforderlich. Der Wert benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und #Monitor als Präfix sind ausgeschlossen. Außerhalb von TABLE sind nur NULL, Leertext und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen.';
        PRINT N'@JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in @Json unabhängig von der Ausgabeart. 0 und NULL erzeugen kein Dokument.';
        PRINT N'@Json nvarchar(max) OUTPUT. Default ist NULL. OUTPUT-Parameter für das JSON-Ergebnis. Der Wert wird am Prozedurbeginn auf NULL gesetzt. NULL bedeutet, dass kein JSON geliefert wurde oder die Erzeugung nicht bis zu einem Ergebnis gelangte.';
        PRINT N'@PrintMeldungen bit. Default ist 1. 1 gibt bei Status außerhalb AVAILABLE und AVAILABLE_LIMITED eine Warnung mit Severity 10 aus. 0 unterdrückt sie. NULL verhält sich über die IF-Bedingung wie aus.';
        PRINT N'@Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der TABLE-Zuordnungsprüfung und beendet den Aufruf vor dem Quellzugriff. 0 und NULL setzen den normalen Aufruf fort.';
        PRINT N'Beispiel 1. EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @Hilfe=1;';
        PRINT N'Beispiel 2. DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @SourceExtendedEventSessionName=N''system_health'',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitReportXml=0,@MitProcessXml=0,@HighImpactConfirmed=1,@ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3. DECLARE @ExampleJson nvarchar(max); DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @SourceExtendedEventSessionName=N''system_health'',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitReportXml=0,@MitProcessXml=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS ExampleJson;';
        PRINT N'Beispiel 4. CREATE TABLE #ExampleBlockedReports ([Seed] int NULL); BEGIN TRY DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @SourceExtendedEventSessionName=N''system_health'',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitReportXml=0,@MitProcessXml=0,@HighImpactConfirmed=1,@ResultSetArt=''TABLE'',@ResultTablesJson=N''{"reports":"#ExampleBlockedReports"}''; SELECT * FROM #ExampleBlockedReports; DROP TABLE #ExampleBlockedReports; END TRY BEGIN CATCH DROP TABLE #ExampleBlockedReports; THROW; END CATCH;';
        RETURN;
    END;

    IF @SourceExtendedEventSessionName IS NULL OR (SELECT COUNT_BIG(*) FROM [monitor].[TVF_ParseSqlNameList](@SourceExtendedEventSessionName) WHERE [IsValid]=1)<>1 OR EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@SourceExtendedEventSessionName) WHERE [IsValid]=0)
    BEGIN SET @ResolvedSourceExtendedEventSessionName=NULL;END
    ELSE SELECT @ResolvedSourceExtendedEventSessionName=MIN([NameValue]) FROM [monitor].[TVF_ParseSqlNameList](@SourceExtendedEventSessionName) WHERE [IsValid]=1;

    DECLARE
        @CollectionTimeUtc datetime2(3)=SYSUTCDATETIME(),
        @StatusCode varchar(40)='AVAILABLE',
        @IsPartial bit=0,
        @ErrorNumber int=NULL,
        @ErrorMessage nvarchar(2048)=NULL,
        @RowCount bigint=0,
        @Allowed bit=1,
        @ResolvedSource varchar(20)=UPPER(LTRIM(RTRIM(COALESCE(@Quelle,'')))),
        @ResolvedSessionName sysname=@ResolvedSourceExtendedEventSessionName,
        @ConfiguredFilePath nvarchar(4000)=NULL,
        @ResolvedFilePath nvarchar(4000)=NULL,
        @TargetData xml=NULL,
        @BlockedProcessThresholdSeconds int=NULL;

    IF @VonUtc IS NULL SET @VonUtc=DATEADD(HOUR,-24,SYSUTCDATETIME());

    CREATE TABLE [#ExtendedEventsBlockedProcesses_Raw]([SourceType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TimestampUtc] datetime2(7) NULL,[FileName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[FileOffset] bigint NULL,[EventXml] xml NULL);
    CREATE TABLE [#ExtendedEventsBlockedProcesses_Reports]
    (
        [ReportId] int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [SourceType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ReportTimeUtc] datetime2(7) NULL,
        [FileName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [FileOffset] bigint NULL,
        [ReportXml] xml NULL
    );
    CREATE TABLE [#ExtendedEventsBlockedProcesses_SourceStatus]
    (
        [SourceType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SessionName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ResolvedPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @ResolvedSource NOT IN('AUTO','EVENT_FILE','RING_BUFFER')
    BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'@Quelle muss AUTO, EVENT_FILE oder RING_BUFFER sein.';END;
    IF @MaxZeilen<0 OR @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE')
    BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'@MaxZeilen darf nicht negativ sein; NULL/0 bedeutet unbegrenzt.';END;
    IF @VonUtc IS NOT NULL AND @BisUtc IS NOT NULL AND @VonUtc>=@BisUtc
    BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'@VonUtc muss kleiner als @BisUtc sein.';END;

    IF @StatusCode='AVAILABLE'
        EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='EXTENDED_EVENTS_FORENSICS_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode='AVAILABLE'
    BEGIN
        BEGIN TRY
            SELECT @BlockedProcessThresholdSeconds=TRY_CONVERT([int],[value_in_use])
            FROM [sys].[configurations] WITH (NOLOCK) WHERE [name]=N'blocked process threshold (s)';
        END TRY
        BEGIN CATCH
            SET @IsPartial=1;
        END CATCH;

        BEGIN TRY
            IF @ResolvedSessionName IS NULL
            BEGIN
                SELECT TOP(1) @ResolvedSessionName=[s].[name]
                FROM [sys].[server_event_sessions] AS s WITH (NOLOCK)
                JOIN [sys].[server_event_session_events] AS e WITH (NOLOCK)
                  ON [e].[event_session_id]=[s].[event_session_id] AND [e].[name]=N'blocked_process_report'
                ORDER BY CASE WHEN EXISTS
                (
                    SELECT 1 FROM [sys].[server_event_session_targets] AS t WITH (NOLOCK)
                    WHERE [t].[event_session_id]=[s].[event_session_id] AND [t].[name]=N'event_file'
                ) THEN 0 ELSE 1 END,[s].[name];
            END;

            IF @ResolvedSessionName IS NOT NULL
            BEGIN
                SELECT @ConfiguredFilePath=MAX(CONVERT(nvarchar(4000),[f].[value]))
                FROM [sys].[server_event_sessions] AS s WITH (NOLOCK)
                JOIN [sys].[server_event_session_targets] AS t WITH (NOLOCK)
                  ON [t].[event_session_id]=[s].[event_session_id] AND [t].[name]=N'event_file'
                LEFT JOIN [sys].[server_event_session_fields] AS f WITH (NOLOCK)
                  ON [f].[event_session_id]=[t].[event_session_id] AND [f].[object_id]=[t].[target_id] AND [f].[name]=N'filename'
                WHERE [s].[name]=@ResolvedSessionName;
            END;
        END TRY
        BEGIN CATCH
            SET @IsPartial=1;
            INSERT [#ExtendedEventsBlockedProcesses_SourceStatus] VALUES('CATALOG',@ResolvedSessionName,NULL,
                CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
                ERROR_NUMBER(),ERROR_MESSAGE(),N'Session- oder Pfadermittlung fehlgeschlagen.');
        END CATCH;

        IF @ResolvedSessionName IS NULL AND @FilePath IS NULL
        BEGIN
            SET @StatusCode='AVAILABLE_DISABLED';
            SET @ErrorMessage=N'Keine sichtbare Session mit blocked_process_report gefunden.';
            INSERT [#ExtendedEventsBlockedProcesses_SourceStatus] VALUES('CATALOG',NULL,NULL,@StatusCode,NULL,@ErrorMessage,
                CONCAT(N'blocked process threshold in use = ',COALESCE(CONVERT(nvarchar(20),@BlockedProcessThresholdSeconds),N'unbekannt'),N' Sekunden; das Framework ändert diese Einstellung nicht.'));
        END
        ELSE IF @ResolvedSource='AUTO'
        BEGIN
            IF @FilePath IS NOT NULL OR @ConfiguredFilePath IS NOT NULL SET @ResolvedSource='EVENT_FILE';
            ELSE IF @BestaetigeTargetFlush=1 SET @ResolvedSource='RING_BUFFER';
            ELSE BEGIN SET @StatusCode='AVAILABLE_DISABLED';SET @ErrorMessage=N'Kein event_file-Pfad; Ringbuffer ohne Bestätigung nicht gelesen.';END;
        END;
    END;

    IF @StatusCode='AVAILABLE' AND @ResolvedSource='EVENT_FILE'
    BEGIN
        SET @ResolvedFilePath=COALESCE(NULLIF(@FilePath,N''),NULLIF(@ConfiguredFilePath,N''));
        IF @ResolvedFilePath IS NULL
        BEGIN
            SET @StatusCode='UNAVAILABLE_OBJECT';SET @ErrorMessage=N'Kein event_file-Pfad verfügbar.';
            INSERT [#ExtendedEventsBlockedProcesses_SourceStatus] VALUES('EVENT_FILE',@ResolvedSessionName,NULL,@StatusCode,NULL,@ErrorMessage,N'Keine Datei gelesen.');
        END
        ELSE
        BEGIN
            IF (RIGHT(LOWER(@ResolvedFilePath),4) = N'.xel')
                SET @ResolvedFilePath=LEFT(@ResolvedFilePath,LEN(@ResolvedFilePath)-4)+N'*.xel';
            ELSE IF CHARINDEX(N'*',@ResolvedFilePath)=0
                SET @ResolvedFilePath=@ResolvedFilePath+N'*.xel';
            BEGIN TRY
                INSERT [#ExtendedEventsBlockedProcesses_Raw]
                SELECT TOP (@EffectiveMaxZeilen) 'EVENT_FILE',[r].[timestamp_utc],[r].[file_name],[r].[file_offset],CONVERT([xml],[r].[event_data])
                FROM sys.fn_xe_file_target_read_file(@ResolvedFilePath,NULL,NULL,NULL) AS r
                WHERE [r].[object_name]=N'blocked_process_report'
                  AND (@VonUtc IS NULL OR [r].[timestamp_utc]>=@VonUtc)
                  AND (@BisUtc IS NULL OR [r].[timestamp_utc]<@BisUtc)
                ORDER BY [r].[timestamp_utc] DESC,[r].[file_name] DESC,[r].[file_offset] DESC;
                INSERT [#ExtendedEventsBlockedProcesses_SourceStatus] VALUES('EVENT_FILE',@ResolvedSessionName,@ResolvedFilePath,'AVAILABLE',NULL,NULL,N'blocked_process_report aus XEL gelesen.');
            END TRY
            BEGIN CATCH
                SET @StatusCode=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN(6335,6336,6337) THEN 'XML_UNAVAILABLE_LIMIT' WHEN ERROR_NUMBER() BETWEEN 9400 AND 9431 THEN 'XML_INVALID' ELSE 'ERROR_HANDLED' END;
                SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();
                INSERT [#ExtendedEventsBlockedProcesses_SourceStatus] VALUES('EVENT_FILE',@ResolvedSessionName,@ResolvedFilePath,@StatusCode,@ErrorNumber,@ErrorMessage,N'XEL-Datei konnte nicht gelesen werden.');
            END CATCH;
        END;
    END;

    IF @StatusCode='AVAILABLE' AND @ResolvedSource='RING_BUFFER'
    BEGIN
        IF @BestaetigeTargetFlush=0
        BEGIN
            SET @StatusCode='AVAILABLE_DISABLED';SET @ErrorMessage=N'RING_BUFFER erfordert @BestaetigeTargetFlush=1.';
            INSERT [#ExtendedEventsBlockedProcesses_SourceStatus] VALUES('RING_BUFFER',@ResolvedSessionName,NULL,@StatusCode,NULL,@ErrorMessage,N'Targetdaten nicht gelesen.');
        END
        ELSE
        BEGIN
            BEGIN TRY
                SELECT @TargetData=CONVERT([xml],[t].[target_data])
                FROM [sys].[dm_xe_session_targets] AS t WITH (NOLOCK)
                JOIN [sys].[dm_xe_sessions] AS s WITH (NOLOCK) ON [s].[address]=[t].[event_session_address]
                WHERE [s].[name]=@ResolvedSessionName AND [t].[target_name]=N'ring_buffer';
                IF @TargetData IS NULL
                BEGIN
                    SET @StatusCode='UNAVAILABLE_OBJECT';SET @ErrorMessage=N'Kein lesbares laufendes ring_buffer-Target gefunden.';
                    INSERT [#ExtendedEventsBlockedProcesses_SourceStatus] VALUES('RING_BUFFER',@ResolvedSessionName,NULL,@StatusCode,NULL,@ErrorMessage,N'Session gestoppt oder kein Ringbuffer.');
                END
                ELSE
                BEGIN
                    INSERT [#ExtendedEventsBlockedProcesses_Raw]
                    SELECT TOP (@EffectiveMaxZeilen) 'RING_BUFFER',x.e.value('(@timestamp)[1]','datetime2(7)'),NULL,NULL,x.e.query('.')
                    FROM @TargetData.nodes('/RingBufferTarget/event[@name="blocked_process_report"]') AS [x]([e])
                    WHERE (@VonUtc IS NULL OR x.e.value('(@timestamp)[1]','datetime2(7)')>=@VonUtc)
                      AND (@BisUtc IS NULL OR x.e.value('(@timestamp)[1]','datetime2(7)')<@BisUtc)
                    ORDER BY x.e.value('(@timestamp)[1]','datetime2(7)') DESC;
                    INSERT [#ExtendedEventsBlockedProcesses_SourceStatus] VALUES('RING_BUFFER',@ResolvedSessionName,NULL,'AVAILABLE',NULL,NULL,N'Ringbuffer bewusst gelesen; Target-Flush möglich.');
                END;
            END TRY
            BEGIN CATCH
                SET @StatusCode=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN(6335,6336,6337) THEN 'XML_UNAVAILABLE_LIMIT' WHEN ERROR_NUMBER() BETWEEN 9400 AND 9431 THEN 'XML_INVALID' ELSE 'ERROR_HANDLED' END;
                SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();
                INSERT [#ExtendedEventsBlockedProcesses_SourceStatus] VALUES('RING_BUFFER',@ResolvedSessionName,NULL,@StatusCode,@ErrorNumber,@ErrorMessage,N'Ringbuffer konnte nicht gelesen werden.');
            END CATCH;
        END;
    END;

    IF @StatusCode='AVAILABLE'
    BEGIN
        INSERT [#ExtendedEventsBlockedProcesses_Reports]([SourceType],[ReportTimeUtc],[FileName],[FileOffset],[ReportXml])
        SELECT [SourceType],[TimestampUtc],[FileName],[FileOffset],
               EventXml.query('(/event/data[@name="blocked_process"]/value/blocked-process-report)[1]')
        FROM [#ExtendedEventsBlockedProcesses_Raw]
        WHERE EventXml.exist('/event/data[@name="blocked_process"]/value/blocked-process-report')=1;

        SELECT @RowCount=COUNT_BIG(*) FROM [#ExtendedEventsBlockedProcesses_Reports];
        IF @RowCount=0
        BEGIN SET @StatusCode='AVAILABLE_LIMITED';SET @IsPartial=1;SET @ErrorMessage=N'Quelle lesbar, aber keine passenden Blocked-Process-Reports gefunden.';END;
    END;

    IF @IsPartial=1 AND @StatusCode='AVAILABLE' SET @StatusCode='AVAILABLE_LIMITED';


    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE','AVAILABLE_LIMITED')
        BEGIN
    SET @MonitorPrintMessage = FORMATMESSAGE(N'WARNUNG USP_ExtendedEventsBlockedProcesses: %s - %s', @StatusCode, COALESCE(@ErrorMessage,N'Keine Details.'));
    RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
END;

    CREATE TABLE [#ExtendedEventsBlockedProcesses_ReportSummary]([ReportId] int,[SourceType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS,[ReportTimeUtc] datetime2(7),[FileName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS,[FileOffset] bigint,[MonitorLoop] bigint NULL,[BlockedSessionId] int NULL,[BlockingSessionId] int NULL,[WaitTimeMs] bigint NULL,[DatabaseId] int NULL,[DatabaseName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[WaitResource] nvarchar(1024) COLLATE SQL_Latin1_General_CP1_CS_AS,[RequestedLockMode] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS,[ReportXml] xml NULL);
    CREATE TABLE [#ExtendedEventsBlockedProcesses_BlockedProcesses]([ReportId] int,[ReportTimeUtc] datetime2(7),[SessionId] int NULL,[ExecutionContextId] int NULL,[ProcessStatus] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[WaitResource] nvarchar(1024) COLLATE SQL_Latin1_General_CP1_CS_AS,[WaitTimeMs] bigint NULL,[LockMode] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS,[DatabaseId] int NULL,[DatabaseName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[ClientApplication] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS,[HostName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS,[LoginName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS,[InputBuffer] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS,[ProcessXml] xml NULL);
    CREATE TABLE [#ExtendedEventsBlockedProcesses_BlockingProcesses]([ReportId] int,[ReportTimeUtc] datetime2(7),[SessionId] int NULL,[ExecutionContextId] int NULL,[ProcessStatus] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[WaitResource] nvarchar(1024) COLLATE SQL_Latin1_General_CP1_CS_AS,[WaitTimeMs] bigint NULL,[LockMode] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS,[DatabaseId] int NULL,[DatabaseName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[ClientApplication] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS,[HostName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS,[LoginName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS,[InputBuffer] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS,[ProcessXml] xml NULL);
    INSERT [#ExtendedEventsBlockedProcesses_ReportSummary] SELECT [r].[ReportId],[r].[SourceType],[r].[ReportTimeUtc],[r].[FileName],[r].[FileOffset],TRY_CONVERT(bigint,[r].[ReportXml].value('(/blocked-process-report/@monitorLoop)[1]','nvarchar(64)')),TRY_CONVERT(int,[r].[ReportXml].value('(/blocked-process-report/blocked-process/process/@spid)[1]','nvarchar(32)')),TRY_CONVERT(int,[r].[ReportXml].value('(/blocked-process-report/blocking-process/process/@spid)[1]','nvarchar(32)')),TRY_CONVERT(bigint,[r].[ReportXml].value('(/blocked-process-report/blocked-process/process/@waittime)[1]','nvarchar(64)')),TRY_CONVERT(int,[r].[ReportXml].value('(/blocked-process-report/blocked-process/process/@currentdb)[1]','nvarchar(32)')),[r].[ReportXml].value('(/blocked-process-report/blocked-process/process/@currentdbname)[1]','nvarchar(256)'),[r].[ReportXml].value('(/blocked-process-report/blocked-process/process/@waitresource)[1]','nvarchar(1024)'),[r].[ReportXml].value('(/blocked-process-report/blocked-process/process/@lockMode)[1]','nvarchar(64)'),CASE WHEN @MitReportXml=1 THEN [r].[ReportXml] END FROM [#ExtendedEventsBlockedProcesses_Reports] [r];
    INSERT [#ExtendedEventsBlockedProcesses_BlockedProcesses] SELECT [r].[ReportId],[r].[ReportTimeUtc],TRY_CONVERT(int,[p].[n].value('(@spid)[1]','nvarchar(32)')),TRY_CONVERT(int,[p].[n].value('(@ecid)[1]','nvarchar(32)')),[p].[n].value('(@status)[1]','nvarchar(128)'),[p].[n].value('(@waitresource)[1]','nvarchar(1024)'),TRY_CONVERT(bigint,[p].[n].value('(@waittime)[1]','nvarchar(64)')),[p].[n].value('(@lockMode)[1]','nvarchar(64)'),TRY_CONVERT(int,[p].[n].value('(@currentdb)[1]','nvarchar(32)')),[p].[n].value('(@currentdbname)[1]','nvarchar(256)'),[p].[n].value('(@clientapp)[1]','nvarchar(512)'),[p].[n].value('(@hostname)[1]','nvarchar(512)'),[p].[n].value('(@loginname)[1]','nvarchar(512)'),[p].[n].value('(inputbuf/text())[1]','nvarchar(4000)'),CASE WHEN @MitProcessXml=1 THEN [p].[n].query('.') END FROM [#ExtendedEventsBlockedProcesses_Reports] [r] CROSS APPLY [r].[ReportXml].nodes('/blocked-process-report/blocked-process/process') [p]([n]);
    INSERT [#ExtendedEventsBlockedProcesses_BlockingProcesses] SELECT [r].[ReportId],[r].[ReportTimeUtc],TRY_CONVERT(int,[p].[n].value('(@spid)[1]','nvarchar(32)')),TRY_CONVERT(int,[p].[n].value('(@ecid)[1]','nvarchar(32)')),[p].[n].value('(@status)[1]','nvarchar(128)'),[p].[n].value('(@waitresource)[1]','nvarchar(1024)'),TRY_CONVERT(bigint,[p].[n].value('(@waittime)[1]','nvarchar(64)')),[p].[n].value('(@lockMode)[1]','nvarchar(64)'),TRY_CONVERT(int,[p].[n].value('(@currentdb)[1]','nvarchar(32)')),[p].[n].value('(@currentdbname)[1]','nvarchar(256)'),[p].[n].value('(@clientapp)[1]','nvarchar(512)'),[p].[n].value('(@hostname)[1]','nvarchar(512)'),[p].[n].value('(@loginname)[1]','nvarchar(512)'),[p].[n].value('(inputbuf/text())[1]','nvarchar(4000)'),CASE WHEN @MitProcessXml=1 THEN [p].[n].query('.') END FROM [#ExtendedEventsBlockedProcesses_Reports] [r] CROSS APPLY [r].[ReportXml].nodes('/blocked-process-report/blocking-process/process') [p]([n]);
    IF @ResultSetArtNormalisiert<>'NONE'
    BEGIN SELECT N'USP_ExtendedEventsBlockedProcesses' [ModuleName],@CollectionTimeUtc [CollectionTimeUtc],@StatusCode [StatusCode],@IsPartial [IsPartial],@RowCount [RowCount],@ResolvedSessionName [SessionName],@ResolvedSource [ResolvedSource],@BlockedProcessThresholdSeconds [BlockedProcessThresholdSeconds],@ErrorNumber [ErrorNumber],@ErrorMessage [ErrorMessage];IF @ResultSetArtNormalisiert='RAW' BEGIN SELECT * FROM [#ExtendedEventsBlockedProcesses_ReportSummary] ORDER BY [ReportTimeUtc] DESC,[ReportId];SELECT * FROM [#ExtendedEventsBlockedProcesses_BlockedProcesses] ORDER BY [ReportTimeUtc] DESC,[ReportId];SELECT * FROM [#ExtendedEventsBlockedProcesses_BlockingProcesses] ORDER BY [ReportTimeUtc] DESC,[ReportId];SELECT * FROM [#ExtendedEventsBlockedProcesses_SourceStatus] ORDER BY [SourceType];END ELSE BEGIN SELECT N'Blocked Process Report' [Ergebnis],[x].* FROM [#ExtendedEventsBlockedProcesses_ReportSummary] [x] ORDER BY [ReportTimeUtc] DESC,[ReportId];SELECT N'Blockierter Prozess' [Ergebnis],[ReportId] [Report],[SessionId] [Session],[WaitTimeMs] [Wait ms],[WaitResource] [Wait-Ressource],[DatabaseName] [Datenbank],[LoginName] [Login],[HostName] [Host],[SessionId] [Session SQL],[InputBuffer] [SQL] FROM [#ExtendedEventsBlockedProcesses_BlockedProcesses] ORDER BY [ReportTimeUtc] DESC,[ReportId];SELECT N'Blockierender Prozess' [Ergebnis],[ReportId] [Report],[SessionId] [Session],[DatabaseName] [Datenbank],[LoginName] [Login],[HostName] [Host],[SessionId] [Session SQL],[InputBuffer] [SQL] FROM [#ExtendedEventsBlockedProcesses_BlockingProcesses] ORDER BY [ReportTimeUtc] DESC,[ReportId];SELECT N'Extended-Events Quelle' [Ergebnis],[x].* FROM [#ExtendedEventsBlockedProcesses_SourceStatus] [x] ORDER BY [SourceType];END;END;
    IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'ExtendedEventsBlockedProcesses' [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@RowCount [returnedRows],@ResolvedSessionName [sessionName],@ResolvedSource [source],@BlockedProcessThresholdSeconds [blockedProcessThresholdSeconds],@ErrorNumber [errorNumber],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@R nvarchar(max)=(SELECT [ReportId],[SourceType],[ReportTimeUtc],[FileName],[FileOffset],[MonitorLoop],[BlockedSessionId],[BlockingSessionId],[WaitTimeMs],[DatabaseId],[DatabaseName],[WaitResource],[RequestedLockMode],CONVERT(nvarchar(max),[ReportXml]) [ReportXml] FROM [#ExtendedEventsBlockedProcesses_ReportSummary] ORDER BY [ReportTimeUtc] DESC,[ReportId] FOR JSON PATH,INCLUDE_NULL_VALUES),@B nvarchar(max)=(SELECT [ReportId],[ReportTimeUtc],[SessionId],[ExecutionContextId],[ProcessStatus],[WaitResource],[WaitTimeMs],[LockMode],[DatabaseId],[DatabaseName],[ClientApplication],[HostName],[LoginName],[InputBuffer],CONVERT(nvarchar(max),[ProcessXml]) [ProcessXml] FROM [#ExtendedEventsBlockedProcesses_BlockedProcesses] ORDER BY [ReportTimeUtc] DESC,[ReportId] FOR JSON PATH,INCLUDE_NULL_VALUES),@G nvarchar(max)=(SELECT [ReportId],[ReportTimeUtc],[SessionId],[ExecutionContextId],[ProcessStatus],[WaitResource],[WaitTimeMs],[LockMode],[DatabaseId],[DatabaseName],[ClientApplication],[HostName],[LoginName],[InputBuffer],CONVERT(nvarchar(max),[ProcessXml]) [ProcessXml] FROM [#ExtendedEventsBlockedProcesses_BlockingProcesses] ORDER BY [ReportTimeUtc] DESC,[ReportId] FOR JSON PATH,INCLUDE_NULL_VALUES),@S nvarchar(max)=(SELECT * FROM [#ExtendedEventsBlockedProcesses_SourceStatus] ORDER BY [SourceType] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"reports":',COALESCE(@R,N'[]'),N',"blockedProcesses":',COALESCE(@B,N'[]'),N',"blockingProcesses":',COALESCE(@G,N'[]'),N',"sources":',COALESCE(@S,N'[]'),N',"warnings":[]}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ExtendedEventsBlockedProcesses_ReportSummary'
            , @ResultLabel=N'ExtendedEventsBlockedProcesses'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ExtendedEventsBlockedProcesses_ReportSummary'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_SsisCatalogExecutionAnalysis
Version      : 1.0.0
Stand        : 2026-10-16
Typ          : Stored Procedure
Zweck        : Liest strukturierte Metadaten einer expliziten SSISDB-Ausführung.
Datenschutz  : Keine Meldungs-, Parameter-, Pfad-, Host- oder Identitätswerte.
Grenze       : Keine Aktionen; Zeitbudget kooperativ zwischen sieben Quellen.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_SsisCatalogExecutionAnalysis]
      @ExecutionId bigint = NULL
    , @IncludeMessages bit = 1
    , @IncludeParameters bit = 1
    , @IncludePerformance bit = 1
    , @MaxZeilen int = 1000
    , @MaxDurationSeconds int = 30
    , @LockTimeoutMs int = 0
    , @ResultSetArt varchar(16) = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen bit = 0
    , @Json nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen bit = 1
    , @Hilfe bit = 0
    , @StatusCodeOut varchar(40) = NULL OUTPUT
    , @IsPartialOut bit = NULL OUTPUT
    , @ErrorNumberOut int = NULL OUTPUT
    , @ErrorMessageOut nvarchar(4000) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    IF COALESCE(@Hilfe,0)=1
    BEGIN
        PRINT N'monitor.USP_SsisCatalogExecutionAnalysis liest strukturierte Metadaten genau einer positiven Execution-ID aus lokaler SSISDB. Die Procedure startet oder stoppt keine Pakete. Meldungstexte, Parameterwerte, Pfade und Host- oder Identitätswerte werden nicht gelesen. Getrennte Katalogabfragen bilden keine atomare Gesamtsicht.';
        PRINT N'Die fünf OUTPUT-Parameter werden beim Eintritt auf NULL gesetzt; Hilfe kehrt vor TABLE-Vorprüfung, fachlicher Parametervalidierung und Quellenreads zurück. Bei normaler Analyse ist das Zeitbudget kooperativ und beendet keine bereits laufende Abfrage.';
        PRINT N'@ExecutionId bigint; Default: NULL. Einzelne positive Ganzzahl 1 bis 9223372036854775807 als bigint für genau eine lokale SSISDB-Ausführung. Keine Liste oder freie Textquelle. NULL, ausgelassen oder kleiner als 1 ist im normalen Analysepfad ungültig und verhindert fachliche Quellenzugriffe. Wert 1 in Beispielen ist synthetisch und muss durch eine bekannte sichtbare ID ersetzt werden. Ausgelassen gilt der deklarierte Default NULL.';
        PRINT N'@IncludeMessages bit; Default: 1. 1 fordert bei sichtbarer Ausführung und noch verfügbarem Zeitbudget den Read an: Ereignismetadaten aus catalog.event_messages; 0 überspringt die Quelle und markiert sie als nicht angefordert. NULL wird zu 1. Meldungstexte werden nicht gelesen. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.';
        PRINT N'@IncludeParameters bit; Default: 1. 1 fordert bei sichtbarer Ausführung und noch verfügbarem Zeitbudget den Read an: Definitionen und Flags aus catalog.execution_parameter_values; 0 überspringt die Quelle und markiert sie als nicht angefordert. NULL wird zu 1. Parameterwerte werden nicht gelesen. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.';
        PRINT N'@IncludePerformance bit; Default: 1. 1 liest Executable-Statistik, Executable-Namen, Phasen und Row-Flow, soweit die Ausführung sichtbar ist; 0 überspringt diese Quellen. NULL wird zu 1. Execution-, Meldungs- und Parameterquellen sind davon unabhängig. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.';
        PRINT N'@MaxZeilen int; Default: 1000. Einzelner SQL-int-Wert 0 bis 2147483647 oder NULL als Obergrenze je Detailquelle. Positives N liest höchstens N+1 geordnete Zeilen einschließlich Sentinel und gibt bei Überschreitung höchstens N zurück. NULL/0 bedeutet unbegrenzt; negativ ist ungültig. N+1 wird nach bigint-Konvertierung berechnet, daher kein int-Maximum-Überlauf. Betroffen sind nur Executable-Statistik, Executable-Namen, Meldungen, Parameter, Phasen und Row-Flow (Ordinale 2–7); nicht die einzelne Execution-Kopfzeile, Plattformprobe, Findings, warnings, sourceStatus oder moduleStatus. Ausgelassen gilt der deklarierte Default 1000.';
        PRINT N'@MaxDurationSeconds int; Default: 30. Einzelner SQL-int-Wert in Sekunden. Kooperatives Gesamtzeitbudget zwischen den sieben SSISDB-Quellen, Bereich 1–60 Sekunden. NULL oder außerhalb ist ungültig. Die Deadline wird zwischen Quellen geprüft; eine laufende SQL-Abfrage wird nicht hart abgebrochen. Erschöpfung kann spätere Quellen auslassen und Partialität verursachen. Ausgelassen gilt der deklarierte Default 30.';
        PRINT N'@LockTimeoutMs int; Default: 0. Einzelner SQL-int-Wert. Katalog-Sperrwartezeit in Millisekunden, Bereich 0–60000. NULL oder außerhalb ist ungültig. 0 bedeutet NOWAIT; positive Werte begrenzen die Wartezeit. Der eingehende LOCK_TIMEOUT wird nach dem Erfassungspfad wiederhergestellt. TABLE-Vorprüfung folgt zusätzlich dem Vertrag der internen Helfer. Ausgelassen gilt der deklarierte Default 0.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Textwert wird an varchar(16) gebunden und kann dabei auf diese Typbreite gekürzt werden; dann werden mit LTRIM/RTRIM U+0020-Randzeichen entfernt, UPPER angewandt und mit SQL_Latin1_General_CP1_CS_AS verglichen. Vollständige Wertemenge: CONSOLE = eine Übersicht; RAW = zehn geordnete Resultsets; TABLE = benannte lokale Temp-Tabellen; NONE = keine fachlichen Grids. Erst der nach Typzuweisung normalisierte Wert wird geprüft. NULL, leer oder nur U+0020 sind ungültig; weitere Whitespacezeichen werden nicht allgemein entfernt. Ausgelassen gilt der deklarierte Default ''CONSOLE''.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. JSON-Objekt mit Resultsetnamen als Schlüssel und lokalen #Temp-Tabellennamen als Stringwert. Alle erlaubten Schlüssel: moduleStatus (Modulstatus), execution (Ausführung), executables (Executable-Statistik), messages (Ereignismetadaten), parameters (Parameterdefinitionen), phases (Phasen), rowFlow (Datenflussstatistik), findings (Befunde), sourceStatus (Quellenstatus), warnings (Warnungen). Mindestens ein Schlüssel ist erforderlich; eine beliebige nichtleere Teilmenge dieser zehn Schlüssel genügt. Schlüssel werden binär einschließlich Groß-/Kleinschreibung verglichen; doppelte Schlüssel sind ungültig. Ziele müssen auch bei case-insensitivem Vergleich eindeutig sein, lokal und mit LEN höchstens 116, nicht ##Temp und nicht Präfix #Monitor. Jedes Ziel existiert bereits, ist leer und hat genau eine beliebige Seed-Spalte. TABLE verlangt gültige nichtleere Zuordnung; außerhalb TABLE sind NULL, leer oder nur U+0020-Leerzeichen erlaubt, nichtleerer Wert ungültig. Vorprüfung läuft nach Hilfe-Return, vor Hauptvalidierung, mit @ThrowOnError=1; Fehler können THROW entweichen und werden nicht als OUTPUT-Fehler garantiert. Ausgelassen gilt der deklarierte Default NULL.';
        PRINT N'@JsonErzeugen bit; Default: 0. 1 erzeugt JSON mit denselben zehn Mengen einschließlich NULL-Feldern und leeren Arrays; 0 erzeugt kein JSON. NULL wirkt wie 0. JSON kann zusätzlich zu jedem ResultSetArt-Modus angefordert werden. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionales nvarchar(max) OUTPUT für das durch @JsonErzeugen=1 erzeugte Objekt. Empfänger als nvarchar(max)-Variable mit OUTPUT binden. Wird zu Beginn auf NULL gesetzt und bleibt ohne JSON-Erzeugung sowie bei Hilfe NULL. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL.';
        PRINT N'@PrintMeldungen bit; Default: 1. Deklarierter bit-Eingabeparameter, nach der Signatur im Prozedurkörper nicht referenziert. Für 0, 1, NULL oder Auslassen ist daher keine Wirkung belegt; keine Funktion aus dem Namen ableiten. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.';
        PRINT N'@Hilfe bit; Default: 0. 0 oder NULL führt normal aus; NULL wird wie 0 behandelt. 1 druckt Hilfe und kehrt sofort zurück. Zuvor setzt die Procedure @Json, @StatusCodeOut, @IsPartialOut, @ErrorNumberOut und @ErrorMessageOut auf NULL. Hilfe umgeht TABLE-Vorprüfung, normale Parametervalidierung und Quellenzugriffe. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler varchar(40) OUTPUT für Sammelstatus; mit OUTPUT empfangen. Beim Eintritt NULL, bei Hilfe weiterhin NULL. Erreichbare Werte im normalen Ablauf: AVAILABLE (vollständig gesammelt), AVAILABLE_LIMITED (sichtbare Ausführung mit partieller Sammlung oder ohne nachweisbar sichtbare Ausführung nach leerem beziehungsweise wegen Zeitbudget ausgelassenem Kopfread), INVALID_PARAMETER (Hauptvalidierung verhindert Quellenzugriff), DENIED_PERMISSION (Zugriff verweigert), SOURCE_UNAVAILABLE (Katalog/Quelle nicht verfügbar), UNAVAILABLE_PLATFORM (nicht unterstützte Linux-Plattformbeobachtung), ERROR_HANDLED (behandelter sonstiger Fehler der Katalogsichtbarkeits- oder Execution-Quelle). TABLE-Preflight kann vorher THROW auslösen; dann ist kein Status-OUTPUT garantiert. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionaler bit OUTPUT für Partialität, mit OUTPUT empfangen. Beim Eintritt NULL und bei Hilfe NULL. Im normalen Ablauf 0 = vollständig, 1 = teilweise oder durch Hauptparameterfehler verhindert. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optionaler int OUTPUT für die maßgebliche erfasste SQL-Fehlernummer, mit OUTPUT empfangen. Beim Eintritt NULL und bei Hilfe NULL; bei fehlerfreier Sammlung NULL. TABLE-Vorprüfungsfehler können THROW auslösen statt diesen OUTPUT zu befüllen. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL. Die Quellenfolge bestimmt das erste tatsächliche Fehlerpaar; reine Hauptparameterfehler und reine Limit-/Sichtbarkeitswarnungen setzen keine synthetische Fehlernummer.';
        PRINT N'@ErrorMessageOut nvarchar(4000) OUTPUT; Default: NULL. Optionales nvarchar(4000) OUTPUT für die maßgebliche erfasste SQL-Fehlermeldung, mit OUTPUT empfangen. Beim Eintritt NULL und bei Hilfe NULL; bei fehlerfreier Sammlung NULL. TABLE-Vorprüfungsfehler sind nicht als hier abgefangene Ausgabe garantiert. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL. Zusammen mit @ErrorNumberOut wird das erste tatsächliche native Fehlerpaar nach Quellenfolge projiziert; eine reine Hauptparameterablehnung setzt hier keinen synthetischen Text.';
        PRINT N'Beispiel: EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @Hilfe=1;';
        PRINT N'Beispiel: EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=1, @MaxZeilen=200, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=1, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        RETURN;
    END;

    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))) COLLATE SQL_Latin1_General_CP1_CS_AS;
    DECLARE @TableRequested bit=CASE WHEN @OutputMode='TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @Now datetime2(3)=SYSUTCDATETIME(),@Deadline datetime2(3);
    DECLARE @PreviousLockTimeout int=@@LOCK_TIMEOUT,@PreviousXactAbort bit=CASE WHEN (16384 & @@OPTIONS)=16384 THEN 1 ELSE 0 END;
    DECLARE @RestoreLock nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@@LOCK_TIMEOUT)+N';';
    DECLARE @StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0,@ErrorNumber int=NULL,@ErrorMessage nvarchar(4000)=NULL;
    DECLARE @Take bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN 9223372036854775807 ELSE CONVERT(bigint,@MaxZeilen)+1 END;
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN 9223372036854775807 ELSE CONVERT(bigint,@MaxZeilen) END;
    SELECT @IncludeMessages=COALESCE(@IncludeMessages,1),@IncludeParameters=COALESCE(@IncludeParameters,1),@IncludePerformance=COALESCE(@IncludePerformance,1);

    CREATE TABLE [#SsisCatalogExecutionAnalysis_ResultTables]
    (
        [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    IF @TableRequested=1
        EXEC [monitor].[InternalPrepareResultTables]
            @ResultTablesJson=@ResultTablesJson,
            @AllowedResultNames=N'moduleStatus|execution|executables|messages|parameters|phases|rowFlow|findings|sourceStatus|warnings',
            @MappingTable=N'#SsisCatalogExecutionAnalysis_ResultTables',@ThrowOnError=1;

    CREATE TABLE [#SsisCatalogExecutionAnalysis_ModuleStatus]
    (
        [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SchemaVersion] int NOT NULL,
        [ExecutionId] bigint NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [ErrorNumber] int NULL,
        [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [CollectionTimeUtc] datetime2(3) NOT NULL
    );
    CREATE TABLE [#SsisCatalogExecutionAnalysis_Execution]
    (
        [ExecutionId] bigint NOT NULL,
        [FolderName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ProjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ProjectLsn] bigint NULL,
        [OperationType] smallint NULL,
        [ExecutionStatus] int NULL,
        [CreatedTime] datetimeoffset(7) NULL,
        [StartTime] datetimeoffset(7) NULL,
        [EndTime] datetimeoffset(7) NULL,
        [Use32BitRuntime] bit NULL
    );
    CREATE TABLE [#SsisCatalogExecutionAnalysis_Executables]
    (
        [StatisticsId] bigint NOT NULL,
        [ExecutionId] bigint NOT NULL,
        [ExecutableId] bigint NULL,
        [ExecutableName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [StartTime] datetimeoffset(7) NULL,
        [EndTime] datetimeoffset(7) NULL,
        [ExecutionDurationMs] int NULL,
        [ExecutionResult] smallint NULL
    );
    CREATE TABLE [#SsisCatalogExecutionAnalysis_Messages]
    (
        [EventMessageId] bigint NOT NULL,
        [ExecutionId] bigint NOT NULL,
        [MessageTime] datetimeoffset(7) NULL,
        [MessageType] smallint NULL,
        [MessageSourceType] smallint NULL,
        [PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [EventName] nvarchar(1024) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [MessageSourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SubcomponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [MessageCode] int NULL
    );
    CREATE TABLE [#SsisCatalogExecutionAnalysis_Parameters]
    (
        [ExecutionParameterId] bigint NOT NULL,
        [ExecutionId] bigint NOT NULL,
        [ObjectType] smallint NULL,
        [ParameterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ParameterDataType] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsSensitive] bit NULL,
        [IsRequired] bit NULL,
        [IsValueSet] bit NULL,
        [IsRuntimeOverride] bit NULL
    );
    CREATE TABLE [#SsisCatalogExecutionAnalysis_Phases]
    (
        [PhaseStatsId] bigint NOT NULL,
        [ExecutionId] bigint NOT NULL,
        [PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [TaskName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SubcomponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PhaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [StartTime] datetimeoffset(7) NULL,
        [EndTime] datetimeoffset(7) NULL
    );
    CREATE TABLE [#SsisCatalogExecutionAnalysis_RowFlow]
    (
        [DataStatsId] bigint NOT NULL,
        [ExecutionId] bigint NOT NULL,
        [PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [TaskName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SourceComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [DestinationComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [RowsSent] bigint NULL,
        [CreatedTime] datetimeoffset(7) NULL
    );
    CREATE TABLE [#SsisCatalogExecutionAnalysis_Findings]
    (
        [FindingOrdinal] int NOT NULL,
        [FindingCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ExecutionId] bigint NOT NULL,
        [EvidenceSource] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisCatalogExecutionAnalysis_SourceStatus]
    (
        [SourceOrdinal] int NOT NULL,
        [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [ObservedRowCount] bigint NULL,
        [ReturnedRowCount] bigint NULL,
        [IsTruncated] bit NOT NULL,
        [ErrorNumber] int NULL,
        [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CollectionTimeUtc] datetime2(3) NOT NULL
    );
    CREATE TABLE [#SsisCatalogExecutionAnalysis_Warnings]
    (
        [WarningOrdinal] int NOT NULL,
        [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisCatalogExecutionAnalysis_Names]
    (
        [ExecutableId] bigint NOT NULL,
        [ExecutionId] bigint NOT NULL,
        [ExecutableName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    INSERT [#SsisCatalogExecutionAnalysis_SourceStatus]
        ([SourceOrdinal],[SourceName],[StatusCode],[IsPartial],[IsTruncated],[Detail],[CollectionTimeUtc])
    VALUES (1,N'catalog.executions','AVAILABLE_LIMITED',0,0,N'SOURCE_NOT_REQUESTED',@Now),
           (2,N'catalog.executable_statistics','AVAILABLE_LIMITED',0,0,N'SOURCE_NOT_REQUESTED',@Now),
           (3,N'catalog.executables','AVAILABLE_LIMITED',0,0,N'SOURCE_NOT_REQUESTED',@Now),
           (4,N'catalog.event_messages','AVAILABLE_LIMITED',0,0,N'SOURCE_NOT_REQUESTED',@Now),
           (5,N'catalog.execution_parameter_values','AVAILABLE_LIMITED',0,0,N'SOURCE_NOT_REQUESTED',@Now),
           (6,N'catalog.execution_component_phases','AVAILABLE_LIMITED',0,0,N'SOURCE_NOT_REQUESTED',@Now),
           (7,N'catalog.execution_data_statistics','AVAILABLE_LIMITED',0,0,N'SOURCE_NOT_REQUESTED',@Now);

    IF @OutputMode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR (@OutputMode<>'TABLE' AND NULLIF(LTRIM(RTRIM(@ResultTablesJson)),N'') IS NOT NULL)
       OR @ExecutionId IS NULL OR @ExecutionId<1
       OR @MaxZeilen<0 OR @MaxDurationSeconds IS NULL OR @MaxDurationSeconds NOT BETWEEN 1 AND 60
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1;
        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
        SET [StatusCode]='INVALID_PARAMETER',[IsPartial]=1,[Detail]=N'PARAMETER_VALIDATION_PREVENTED_SOURCE_ACCESS';
    END
    ELSE
    BEGIN
        SET @Deadline=DATEADD(second,@MaxDurationSeconds,@Now);
        BEGIN TRY
            SET XACT_ABORT OFF;
            SET LOCK_TIMEOUT 0;
            DECLARE @SetLock nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';
            EXEC [sys].[sp_executesql] @SetLock;
            DECLARE @CatalogVisible bit=NULL,@VisibilityError int=NULL;
            BEGIN TRY
                SELECT @CatalogVisible=CASE WHEN EXISTS
                    (SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'SSISDB') THEN 1 ELSE 0 END;
            END TRY
            BEGIN CATCH
                SELECT @VisibilityError=ERROR_NUMBER(),@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@IsPartial=1;
                SET @StatusCode=CASE WHEN @ErrorNumber IN (229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                     WHEN @ErrorNumber IN (207,208,911,916) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END;
                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                SET [StatusCode]=@StatusCode,[IsPartial]=1,[ErrorNumber]=@ErrorNumber,[ErrorMessage]=@ErrorMessage,
                    [Detail]=N'CATALOG_VISIBILITY_PROBE_ERROR: master.sys.databases' WHERE [SourceOrdinal]=1;
            END CATCH;
            IF @VisibilityError IS NOT NULL
                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'SOURCE_NOT_READ_NO_VISIBLE_EXECUTION'
                WHERE (@IncludePerformance=1 AND [SourceOrdinal] IN (2,3,6,7))
                   OR (@IncludeMessages=1 AND [SourceOrdinal]=4) OR (@IncludeParameters=1 AND [SourceOrdinal]=5);
            ELSE IF @CatalogVisible=0
            BEGIN
                DECLARE @HostPlatform nvarchar(256)=NULL,@PlatformError int=NULL,@PlatformMessage nvarchar(4000)=NULL;
                BEGIN TRY
                    SELECT @HostPlatform=[host_platform] FROM [sys].[dm_os_host_info] WITH (NOLOCK);
                END TRY
                BEGIN CATCH
                    SELECT @PlatformError=ERROR_NUMBER(),@PlatformMessage=ERROR_MESSAGE();
                    SELECT @ErrorNumber=@PlatformError,@ErrorMessage=@PlatformMessage;
                END CATCH;
                SELECT @StatusCode=CASE WHEN @HostPlatform COLLATE SQL_Latin1_General_CP1_CS_AS=N'Linux' THEN 'UNAVAILABLE_PLATFORM' ELSE 'SOURCE_UNAVAILABLE' END,@IsPartial=1;
                INSERT [#SsisCatalogExecutionAnalysis_SourceStatus]
                    ([SourceOrdinal],[SourceName],[StatusCode],[IsPartial],[ObservedRowCount],[ReturnedRowCount],[IsTruncated],[ErrorNumber],[ErrorMessage],[Detail],[CollectionTimeUtc])
                VALUES (0,N'sys.dm_os_host_info',
                    CASE WHEN @PlatformError IN (229,262,297,300,371) THEN 'DENIED_PERMISSION'
                         WHEN @PlatformError IN (207,208,911,916) THEN 'SOURCE_UNAVAILABLE'
                         WHEN @PlatformError IS NOT NULL THEN 'ERROR_HANDLED'
                         WHEN @HostPlatform IS NULL THEN 'AVAILABLE_EMPTY' ELSE 'AVAILABLE' END,
                    CASE WHEN @PlatformError IS NOT NULL THEN 1 ELSE 0 END,
                    CASE WHEN @PlatformError IS NOT NULL THEN NULL WHEN @HostPlatform IS NULL THEN 0 ELSE 1 END,
                    CASE WHEN @PlatformError IS NOT NULL THEN NULL WHEN @HostPlatform IS NULL THEN 0 ELSE 1 END,
                    0,@PlatformError,@PlatformMessage,N'PLATFORM_PROBE_FOR_NONVISIBLE_CATALOG',SYSUTCDATETIME());
                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                SET [StatusCode]=@StatusCode,[IsPartial]=1,[Detail]=N'SSISDB_NOT_VISIBLE'
                WHERE [SourceOrdinal]=1 OR (@IncludePerformance=1 AND [SourceOrdinal] IN (2,3,6,7))
                   OR (@IncludeMessages=1 AND [SourceOrdinal]=4) OR (@IncludeParameters=1 AND [SourceOrdinal]=5);
            END
            ELSE
            BEGIN
                IF 1=1
                BEGIN
                    IF 1=0
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'SOURCE_NOT_READ_NO_VISIBLE_EXECUTION' WHERE [SourceOrdinal]=1;
                    ELSE IF SYSUTCDATETIME()>=@Deadline
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'TIME_BUDGET_EXHAUSTED' WHERE [SourceOrdinal]=1;
                    ELSE
                    BEGIN
                        BEGIN TRY
                            DECLARE @SourceSql1 nvarchar(max)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; INSERT [#SsisCatalogExecutionAnalysis_Execution] ([ExecutionId],[FolderName],[ProjectName],[PackageName],[ProjectLsn],[OperationType],[ExecutionStatus],[CreatedTime],[StartTime],[EndTime],[Use32BitRuntime]) SELECT TOP (2) [execution_id],[folder_name],[project_name],[package_name],[project_lsn],[operation_type],[status],[created_time],[start_time],[end_time],[use32bitruntime] FROM [SSISDB].[catalog].[executions] WITH (NOLOCK) WHERE [execution_id]=@ReadExecutionId ORDER BY [execution_id];';
                            EXEC [sys].[sp_executesql] @SourceSql1,
                                N'@ReadExecutionId bigint,@ReadTake bigint',@ReadExecutionId=@ExecutionId,@ReadTake=@Take;
                            IF EXISTS (SELECT [ExecutionId] FROM [#SsisCatalogExecutionAnalysis_Execution] GROUP BY [ExecutionId] HAVING COUNT_BIG(*)>1)
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [StatusCode]='SOURCE_UNAVAILABLE',[IsPartial]=1,[Detail]=N'DUPLICATE_SOURCE_KEY' WHERE [SourceOrdinal]=1;
                                DELETE FROM [#SsisCatalogExecutionAnalysis_Execution];
                            END
                            ELSE
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ObservedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Execution]),
                                    [StatusCode]=CASE WHEN EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Execution]) THEN 'AVAILABLE' ELSE 'AVAILABLE_EMPTY' END,
                                    [Detail]=N'VISIBLE_ROWS_OBSERVED' WHERE [SourceOrdinal]=1;
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Execution]) WHERE [SourceOrdinal]=1;
                            END;
                        END TRY
                        BEGIN CATCH
                            DELETE FROM [#SsisCatalogExecutionAnalysis_Execution];
                            UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                            SET [StatusCode]=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                                 WHEN ERROR_NUMBER() IN (207,208,911,916) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
                                [IsPartial]=1,[ObservedRowCount]=NULL,[ReturnedRowCount]=NULL,[IsTruncated]=0,
                                [ErrorNumber]=ERROR_NUMBER(),[ErrorMessage]=ERROR_MESSAGE(),[Detail]=N'NATIVE_SOURCE_ERROR'
                            WHERE [SourceOrdinal]=1;
                            IF @ErrorNumber IS NULL SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
                        END CATCH;
                    END;
                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus] SET [CollectionTimeUtc]=SYSUTCDATETIME() WHERE [SourceOrdinal]=1;
                END;
                IF NOT EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Execution])
                   AND EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_SourceStatus] WHERE [SourceOrdinal]=1 AND [StatusCode]='AVAILABLE_EMPTY')
                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                    SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'EXECUTION_NOT_VISIBLE_OR_ABSENT' WHERE [SourceOrdinal]=1;
                IF @IncludePerformance=1
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Execution])
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'SOURCE_NOT_READ_NO_VISIBLE_EXECUTION' WHERE [SourceOrdinal]=2;
                    ELSE IF SYSUTCDATETIME()>=@Deadline
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'TIME_BUDGET_EXHAUSTED' WHERE [SourceOrdinal]=2;
                    ELSE
                    BEGIN
                        BEGIN TRY
                            DECLARE @SourceSql2 nvarchar(max)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; INSERT [#SsisCatalogExecutionAnalysis_Executables] ([StatisticsId],[ExecutionId],[ExecutableId],[ExecutableName],[PackageName],[StartTime],[EndTime],[ExecutionDurationMs],[ExecutionResult]) SELECT TOP (@ReadTake) [statistics_id],[execution_id],[executable_id],NULL,NULL,[start_time],[end_time],[execution_duration],[execution_result] FROM [SSISDB].[catalog].[executable_statistics] WITH (NOLOCK) WHERE [execution_id]=@ReadExecutionId ORDER BY [statistics_id];';
                            EXEC [sys].[sp_executesql] @SourceSql2,
                                N'@ReadExecutionId bigint,@ReadTake bigint',@ReadExecutionId=@ExecutionId,@ReadTake=@Take;
                            IF EXISTS (SELECT [StatisticsId] FROM [#SsisCatalogExecutionAnalysis_Executables] GROUP BY [StatisticsId] HAVING COUNT_BIG(*)>1)
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [StatusCode]='SOURCE_UNAVAILABLE',[IsPartial]=1,[Detail]=N'DUPLICATE_SOURCE_KEY' WHERE [SourceOrdinal]=2;
                                DELETE FROM [#SsisCatalogExecutionAnalysis_Executables];
                            END
                            ELSE
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ObservedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Executables]),
                                    [StatusCode]=CASE WHEN EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Executables]) THEN 'AVAILABLE' ELSE 'AVAILABLE_EMPTY' END,
                                    [Detail]=N'VISIBLE_ROWS_OBSERVED' WHERE [SourceOrdinal]=2;
                                IF (SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Executables])>@Limit
                                BEGIN
                                    DELETE FROM [#SsisCatalogExecutionAnalysis_Executables] WHERE [StatisticsId] NOT IN (SELECT TOP (@Limit) [StatisticsId] FROM [#SsisCatalogExecutionAnalysis_Executables] ORDER BY [StatisticsId]);
                                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                    SET [StatusCode]='TRUNCATED',[IsPartial]=1,[IsTruncated]=1,[Detail]=N'N_PLUS_ONE_PREFIX_IS_NOT_TOTAL_COUNT' WHERE [SourceOrdinal]=2;
                                END;
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Executables]) WHERE [SourceOrdinal]=2;
                            END;
                        END TRY
                        BEGIN CATCH
                            DELETE FROM [#SsisCatalogExecutionAnalysis_Executables];
                            UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                            SET [StatusCode]=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                                 WHEN ERROR_NUMBER() IN (207,208,911,916) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
                                [IsPartial]=1,[ObservedRowCount]=NULL,[ReturnedRowCount]=NULL,[IsTruncated]=0,
                                [ErrorNumber]=ERROR_NUMBER(),[ErrorMessage]=ERROR_MESSAGE(),[Detail]=N'NATIVE_SOURCE_ERROR'
                            WHERE [SourceOrdinal]=2;
                            IF @ErrorNumber IS NULL SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
                        END CATCH;
                    END;
                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus] SET [CollectionTimeUtc]=SYSUTCDATETIME() WHERE [SourceOrdinal]=2;
                END;
                IF @IncludePerformance=1
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Execution])
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'SOURCE_NOT_READ_NO_VISIBLE_EXECUTION' WHERE [SourceOrdinal]=3;
                    ELSE IF SYSUTCDATETIME()>=@Deadline
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'TIME_BUDGET_EXHAUSTED' WHERE [SourceOrdinal]=3;
                    ELSE
                    BEGIN
                        BEGIN TRY
                            DECLARE @SourceSql3 nvarchar(max)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; INSERT [#SsisCatalogExecutionAnalysis_Names] ([ExecutableId],[ExecutionId],[ExecutableName],[PackageName]) SELECT TOP (@ReadTake) [executable_id],[execution_id],[executable_name],[package_name] FROM [SSISDB].[catalog].[executables] WITH (NOLOCK) WHERE [execution_id]=@ReadExecutionId ORDER BY [executable_id];';
                            EXEC [sys].[sp_executesql] @SourceSql3,
                                N'@ReadExecutionId bigint,@ReadTake bigint',@ReadExecutionId=@ExecutionId,@ReadTake=@Take;
                            IF EXISTS (SELECT [ExecutableId] FROM [#SsisCatalogExecutionAnalysis_Names] GROUP BY [ExecutableId] HAVING COUNT_BIG(*)>1)
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [StatusCode]='SOURCE_UNAVAILABLE',[IsPartial]=1,[Detail]=N'DUPLICATE_SOURCE_KEY' WHERE [SourceOrdinal]=3;
                                DELETE FROM [#SsisCatalogExecutionAnalysis_Names];
                            END
                            ELSE
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ObservedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Names]),
                                    [StatusCode]=CASE WHEN EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Names]) THEN 'AVAILABLE' ELSE 'AVAILABLE_EMPTY' END,
                                    [Detail]=N'VISIBLE_ROWS_OBSERVED' WHERE [SourceOrdinal]=3;
                                IF (SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Names])>@Limit
                                BEGIN
                                    DELETE FROM [#SsisCatalogExecutionAnalysis_Names] WHERE [ExecutableId] NOT IN (SELECT TOP (@Limit) [ExecutableId] FROM [#SsisCatalogExecutionAnalysis_Names] ORDER BY [ExecutableId]);
                                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                    SET [StatusCode]='TRUNCATED',[IsPartial]=1,[IsTruncated]=1,[Detail]=N'N_PLUS_ONE_PREFIX_IS_NOT_TOTAL_COUNT' WHERE [SourceOrdinal]=3;
                                END;
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Names]) WHERE [SourceOrdinal]=3;
                            END;
                        END TRY
                        BEGIN CATCH
                            DELETE FROM [#SsisCatalogExecutionAnalysis_Names];
                            UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                            SET [StatusCode]=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                                 WHEN ERROR_NUMBER() IN (207,208,911,916) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
                                [IsPartial]=1,[ObservedRowCount]=NULL,[ReturnedRowCount]=NULL,[IsTruncated]=0,
                                [ErrorNumber]=ERROR_NUMBER(),[ErrorMessage]=ERROR_MESSAGE(),[Detail]=N'NATIVE_SOURCE_ERROR'
                            WHERE [SourceOrdinal]=3;
                            IF @ErrorNumber IS NULL SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
                        END CATCH;
                    END;
                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus] SET [CollectionTimeUtc]=SYSUTCDATETIME() WHERE [SourceOrdinal]=3;
                END;
                IF @IncludeMessages=1
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Execution])
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'SOURCE_NOT_READ_NO_VISIBLE_EXECUTION' WHERE [SourceOrdinal]=4;
                    ELSE IF SYSUTCDATETIME()>=@Deadline
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'TIME_BUDGET_EXHAUSTED' WHERE [SourceOrdinal]=4;
                    ELSE
                    BEGIN
                        BEGIN TRY
                            DECLARE @SourceSql4 nvarchar(max)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; INSERT [#SsisCatalogExecutionAnalysis_Messages] ([EventMessageId],[ExecutionId],[MessageTime],[MessageType],[MessageSourceType],[PackageName],[EventName],[MessageSourceName],[SubcomponentName],[MessageCode]) SELECT TOP (@ReadTake) [event_message_id],[operation_id],[message_time],[message_type],[message_source_type],[package_name],[event_name],[message_source_name],[subcomponent_name],[message_code] FROM [SSISDB].[catalog].[event_messages] WITH (NOLOCK) WHERE [operation_id]=@ReadExecutionId ORDER BY [event_message_id];';
                            EXEC [sys].[sp_executesql] @SourceSql4,
                                N'@ReadExecutionId bigint,@ReadTake bigint',@ReadExecutionId=@ExecutionId,@ReadTake=@Take;
                            IF EXISTS (SELECT [EventMessageId] FROM [#SsisCatalogExecutionAnalysis_Messages] GROUP BY [EventMessageId] HAVING COUNT_BIG(*)>1)
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [StatusCode]='SOURCE_UNAVAILABLE',[IsPartial]=1,[Detail]=N'DUPLICATE_SOURCE_KEY' WHERE [SourceOrdinal]=4;
                                DELETE FROM [#SsisCatalogExecutionAnalysis_Messages];
                            END
                            ELSE
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ObservedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Messages]),
                                    [StatusCode]=CASE WHEN EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Messages]) THEN 'AVAILABLE' ELSE 'AVAILABLE_EMPTY' END,
                                    [Detail]=N'VISIBLE_ROWS_OBSERVED' WHERE [SourceOrdinal]=4;
                                IF (SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Messages])>@Limit
                                BEGIN
                                    DELETE FROM [#SsisCatalogExecutionAnalysis_Messages] WHERE [EventMessageId] NOT IN (SELECT TOP (@Limit) [EventMessageId] FROM [#SsisCatalogExecutionAnalysis_Messages] ORDER BY [EventMessageId]);
                                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                    SET [StatusCode]='TRUNCATED',[IsPartial]=1,[IsTruncated]=1,[Detail]=N'N_PLUS_ONE_PREFIX_IS_NOT_TOTAL_COUNT' WHERE [SourceOrdinal]=4;
                                END;
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Messages]) WHERE [SourceOrdinal]=4;
                            END;
                        END TRY
                        BEGIN CATCH
                            DELETE FROM [#SsisCatalogExecutionAnalysis_Messages];
                            UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                            SET [StatusCode]=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                                 WHEN ERROR_NUMBER() IN (207,208,911,916) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
                                [IsPartial]=1,[ObservedRowCount]=NULL,[ReturnedRowCount]=NULL,[IsTruncated]=0,
                                [ErrorNumber]=ERROR_NUMBER(),[ErrorMessage]=ERROR_MESSAGE(),[Detail]=N'NATIVE_SOURCE_ERROR'
                            WHERE [SourceOrdinal]=4;
                            IF @ErrorNumber IS NULL SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
                        END CATCH;
                    END;
                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus] SET [CollectionTimeUtc]=SYSUTCDATETIME() WHERE [SourceOrdinal]=4;
                END;
                IF @IncludeParameters=1
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Execution])
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'SOURCE_NOT_READ_NO_VISIBLE_EXECUTION' WHERE [SourceOrdinal]=5;
                    ELSE IF SYSUTCDATETIME()>=@Deadline
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'TIME_BUDGET_EXHAUSTED' WHERE [SourceOrdinal]=5;
                    ELSE
                    BEGIN
                        BEGIN TRY
                            DECLARE @SourceSql5 nvarchar(max)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; INSERT [#SsisCatalogExecutionAnalysis_Parameters] ([ExecutionParameterId],[ExecutionId],[ObjectType],[ParameterName],[ParameterDataType],[IsSensitive],[IsRequired],[IsValueSet],[IsRuntimeOverride]) SELECT TOP (@ReadTake) [execution_parameter_id],[execution_id],[object_type],[parameter_name],[parameter_data_type],[sensitive],[required],[value_set],[runtime_override] FROM [SSISDB].[catalog].[execution_parameter_values] WITH (NOLOCK) WHERE [execution_id]=@ReadExecutionId ORDER BY [execution_parameter_id];';
                            EXEC [sys].[sp_executesql] @SourceSql5,
                                N'@ReadExecutionId bigint,@ReadTake bigint',@ReadExecutionId=@ExecutionId,@ReadTake=@Take;
                            IF EXISTS (SELECT [ExecutionParameterId] FROM [#SsisCatalogExecutionAnalysis_Parameters] GROUP BY [ExecutionParameterId] HAVING COUNT_BIG(*)>1)
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [StatusCode]='SOURCE_UNAVAILABLE',[IsPartial]=1,[Detail]=N'DUPLICATE_SOURCE_KEY' WHERE [SourceOrdinal]=5;
                                DELETE FROM [#SsisCatalogExecutionAnalysis_Parameters];
                            END
                            ELSE
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ObservedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Parameters]),
                                    [StatusCode]=CASE WHEN EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Parameters]) THEN 'AVAILABLE' ELSE 'AVAILABLE_EMPTY' END,
                                    [Detail]=N'VISIBLE_ROWS_OBSERVED' WHERE [SourceOrdinal]=5;
                                IF (SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Parameters])>@Limit
                                BEGIN
                                    DELETE FROM [#SsisCatalogExecutionAnalysis_Parameters] WHERE [ExecutionParameterId] NOT IN (SELECT TOP (@Limit) [ExecutionParameterId] FROM [#SsisCatalogExecutionAnalysis_Parameters] ORDER BY [ExecutionParameterId]);
                                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                    SET [StatusCode]='TRUNCATED',[IsPartial]=1,[IsTruncated]=1,[Detail]=N'N_PLUS_ONE_PREFIX_IS_NOT_TOTAL_COUNT' WHERE [SourceOrdinal]=5;
                                END;
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Parameters]) WHERE [SourceOrdinal]=5;
                            END;
                        END TRY
                        BEGIN CATCH
                            DELETE FROM [#SsisCatalogExecutionAnalysis_Parameters];
                            UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                            SET [StatusCode]=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                                 WHEN ERROR_NUMBER() IN (207,208,911,916) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
                                [IsPartial]=1,[ObservedRowCount]=NULL,[ReturnedRowCount]=NULL,[IsTruncated]=0,
                                [ErrorNumber]=ERROR_NUMBER(),[ErrorMessage]=ERROR_MESSAGE(),[Detail]=N'NATIVE_SOURCE_ERROR'
                            WHERE [SourceOrdinal]=5;
                            IF @ErrorNumber IS NULL SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
                        END CATCH;
                    END;
                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus] SET [CollectionTimeUtc]=SYSUTCDATETIME() WHERE [SourceOrdinal]=5;
                END;
                IF @IncludePerformance=1
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Execution])
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'SOURCE_NOT_READ_NO_VISIBLE_EXECUTION' WHERE [SourceOrdinal]=6;
                    ELSE IF SYSUTCDATETIME()>=@Deadline
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'TIME_BUDGET_EXHAUSTED' WHERE [SourceOrdinal]=6;
                    ELSE
                    BEGIN
                        BEGIN TRY
                            DECLARE @SourceSql6 nvarchar(max)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; INSERT [#SsisCatalogExecutionAnalysis_Phases] ([PhaseStatsId],[ExecutionId],[PackageName],[TaskName],[SubcomponentName],[PhaseName],[StartTime],[EndTime]) SELECT TOP (@ReadTake) [phase_stats_id],[execution_id],[package_name],[task_name],[subcomponent_name],[phase],[start_time],[end_time] FROM [SSISDB].[catalog].[execution_component_phases] WITH (NOLOCK) WHERE [execution_id]=@ReadExecutionId ORDER BY [phase_stats_id];';
                            EXEC [sys].[sp_executesql] @SourceSql6,
                                N'@ReadExecutionId bigint,@ReadTake bigint',@ReadExecutionId=@ExecutionId,@ReadTake=@Take;
                            IF EXISTS (SELECT [PhaseStatsId] FROM [#SsisCatalogExecutionAnalysis_Phases] GROUP BY [PhaseStatsId] HAVING COUNT_BIG(*)>1)
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [StatusCode]='SOURCE_UNAVAILABLE',[IsPartial]=1,[Detail]=N'DUPLICATE_SOURCE_KEY' WHERE [SourceOrdinal]=6;
                                DELETE FROM [#SsisCatalogExecutionAnalysis_Phases];
                            END
                            ELSE
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ObservedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Phases]),
                                    [StatusCode]=CASE WHEN EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Phases]) THEN 'AVAILABLE' ELSE 'AVAILABLE_EMPTY' END,
                                    [Detail]=N'VISIBLE_ROWS_OBSERVED' WHERE [SourceOrdinal]=6;
                                IF (SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Phases])>@Limit
                                BEGIN
                                    DELETE FROM [#SsisCatalogExecutionAnalysis_Phases] WHERE [PhaseStatsId] NOT IN (SELECT TOP (@Limit) [PhaseStatsId] FROM [#SsisCatalogExecutionAnalysis_Phases] ORDER BY [PhaseStatsId]);
                                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                    SET [StatusCode]='TRUNCATED',[IsPartial]=1,[IsTruncated]=1,[Detail]=N'N_PLUS_ONE_PREFIX_IS_NOT_TOTAL_COUNT' WHERE [SourceOrdinal]=6;
                                END;
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_Phases]) WHERE [SourceOrdinal]=6;
                            END;
                        END TRY
                        BEGIN CATCH
                            DELETE FROM [#SsisCatalogExecutionAnalysis_Phases];
                            UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                            SET [StatusCode]=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                                 WHEN ERROR_NUMBER() IN (207,208,911,916) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
                                [IsPartial]=1,[ObservedRowCount]=NULL,[ReturnedRowCount]=NULL,[IsTruncated]=0,
                                [ErrorNumber]=ERROR_NUMBER(),[ErrorMessage]=ERROR_MESSAGE(),[Detail]=N'NATIVE_SOURCE_ERROR'
                            WHERE [SourceOrdinal]=6;
                            IF @ErrorNumber IS NULL SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
                        END CATCH;
                    END;
                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus] SET [CollectionTimeUtc]=SYSUTCDATETIME() WHERE [SourceOrdinal]=6;
                END;
                IF @IncludePerformance=1
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Execution])
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'SOURCE_NOT_READ_NO_VISIBLE_EXECUTION' WHERE [SourceOrdinal]=7;
                    ELSE IF SYSUTCDATETIME()>=@Deadline
                        UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                        SET [StatusCode]='AVAILABLE_LIMITED',[IsPartial]=1,[Detail]=N'TIME_BUDGET_EXHAUSTED' WHERE [SourceOrdinal]=7;
                    ELSE
                    BEGIN
                        BEGIN TRY
                            DECLARE @SourceSql7 nvarchar(max)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; INSERT [#SsisCatalogExecutionAnalysis_RowFlow] ([DataStatsId],[ExecutionId],[PackageName],[TaskName],[SourceComponentName],[DestinationComponentName],[RowsSent],[CreatedTime]) SELECT TOP (@ReadTake) [data_stats_id],[execution_id],[package_name],[task_name],[source_component_name],[destination_component_name],[rows_sent],[created_time] FROM [SSISDB].[catalog].[execution_data_statistics] WITH (NOLOCK) WHERE [execution_id]=@ReadExecutionId ORDER BY [data_stats_id];';
                            EXEC [sys].[sp_executesql] @SourceSql7,
                                N'@ReadExecutionId bigint,@ReadTake bigint',@ReadExecutionId=@ExecutionId,@ReadTake=@Take;
                            IF EXISTS (SELECT [DataStatsId] FROM [#SsisCatalogExecutionAnalysis_RowFlow] GROUP BY [DataStatsId] HAVING COUNT_BIG(*)>1)
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [StatusCode]='SOURCE_UNAVAILABLE',[IsPartial]=1,[Detail]=N'DUPLICATE_SOURCE_KEY' WHERE [SourceOrdinal]=7;
                                DELETE FROM [#SsisCatalogExecutionAnalysis_RowFlow];
                            END
                            ELSE
                            BEGIN
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ObservedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_RowFlow]),
                                    [StatusCode]=CASE WHEN EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_RowFlow]) THEN 'AVAILABLE' ELSE 'AVAILABLE_EMPTY' END,
                                    [Detail]=N'VISIBLE_ROWS_OBSERVED' WHERE [SourceOrdinal]=7;
                                IF (SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_RowFlow])>@Limit
                                BEGIN
                                    DELETE FROM [#SsisCatalogExecutionAnalysis_RowFlow] WHERE [DataStatsId] NOT IN (SELECT TOP (@Limit) [DataStatsId] FROM [#SsisCatalogExecutionAnalysis_RowFlow] ORDER BY [DataStatsId]);
                                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                    SET [StatusCode]='TRUNCATED',[IsPartial]=1,[IsTruncated]=1,[Detail]=N'N_PLUS_ONE_PREFIX_IS_NOT_TOTAL_COUNT' WHERE [SourceOrdinal]=7;
                                END;
                                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                                SET [ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisCatalogExecutionAnalysis_RowFlow]) WHERE [SourceOrdinal]=7;
                            END;
                        END TRY
                        BEGIN CATCH
                            DELETE FROM [#SsisCatalogExecutionAnalysis_RowFlow];
                            UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                            SET [StatusCode]=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                                 WHEN ERROR_NUMBER() IN (207,208,911,916) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
                                [IsPartial]=1,[ObservedRowCount]=NULL,[ReturnedRowCount]=NULL,[IsTruncated]=0,
                                [ErrorNumber]=ERROR_NUMBER(),[ErrorMessage]=ERROR_MESSAGE(),[Detail]=N'NATIVE_SOURCE_ERROR'
                            WHERE [SourceOrdinal]=7;
                            IF @ErrorNumber IS NULL SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
                        END CATCH;
                    END;
                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus] SET [CollectionTimeUtc]=SYSUTCDATETIME() WHERE [SourceOrdinal]=7;
                END;
                UPDATE [s] SET [ExecutableName]=[n].[ExecutableName],[PackageName]=[n].[PackageName]
                FROM [#SsisCatalogExecutionAnalysis_Executables] AS [s]
                LEFT JOIN [#SsisCatalogExecutionAnalysis_Names] AS [n] ON [s].[ExecutionId]=[n].[ExecutionId] AND [s].[ExecutableId]=[n].[ExecutableId];
                UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                SET [ReturnedRowCount]=(SELECT COUNT_BIG(DISTINCT [n].[ExecutableId]) FROM [#SsisCatalogExecutionAnalysis_Names] AS [n]
                     INNER JOIN [#SsisCatalogExecutionAnalysis_Executables] AS [s] ON [s].[ExecutionId]=[n].[ExecutionId] AND [s].[ExecutableId]=[n].[ExecutableId])
                WHERE [SourceOrdinal]=3 AND [StatusCode] IN ('AVAILABLE','AVAILABLE_EMPTY','TRUNCATED');
                IF EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Executables] AS [s]
                           LEFT JOIN [#SsisCatalogExecutionAnalysis_Names] AS [n] ON [s].[ExecutionId]=[n].[ExecutionId] AND [s].[ExecutableId]=[n].[ExecutableId]
                           WHERE [n].[ExecutableId] IS NULL)
                    UPDATE [#SsisCatalogExecutionAnalysis_SourceStatus]
                    SET [StatusCode]=CASE WHEN [StatusCode] IN ('AVAILABLE','AVAILABLE_EMPTY') THEN 'AVAILABLE_LIMITED' ELSE [StatusCode] END,
                        [IsPartial]=1,[Detail]=N'EXECUTABLE_METADATA_NOT_VISIBLE'
                    WHERE [SourceOrdinal]=3 AND [StatusCode] IN ('AVAILABLE','AVAILABLE_EMPTY');

                SELECT @IsPartial=CASE WHEN EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_SourceStatus] WHERE [IsPartial]=1) THEN 1 ELSE 0 END;
                SELECT @StatusCode=CASE WHEN EXISTS (SELECT 1 FROM [#SsisCatalogExecutionAnalysis_Execution])
                                       THEN CASE WHEN @IsPartial=1 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END
                                       ELSE [StatusCode] END
                FROM [#SsisCatalogExecutionAnalysis_SourceStatus] WHERE [SourceOrdinal]=1;
            END;
            EXEC [sys].[sp_executesql] @RestoreLock;
            IF @PreviousXactAbort=1 SET XACT_ABORT ON;
        END TRY
        BEGIN CATCH
            EXEC [sys].[sp_executesql] @RestoreLock;
            IF @PreviousXactAbort=1 SET XACT_ABORT ON;
            THROW;
        END CATCH;
    END;

    INSERT [#SsisCatalogExecutionAnalysis_Findings]
        ([FindingOrdinal],[FindingCode],[Severity],[ExecutionId],[EvidenceSource],[Detail])
    SELECT 1,CASE [ExecutionStatus] WHEN 1 THEN 'EXECUTION_NOT_STARTED' WHEN 3 THEN 'EXECUTION_CANCELED'
                 WHEN 4 THEN 'EXECUTION_FAILED' WHEN 6 THEN 'EXECUTION_ENDED_UNEXPECTEDLY' ELSE 'EXECUTION_NOT_TERMINAL' END,
           CASE WHEN [ExecutionStatus] IN (3,4,6) THEN 'WARNING' ELSE 'INFO' END,
           [ExecutionId],N'catalog.executions',N'Der native Ausführungsstatus ist ein beobachteter Zustand, keine Ursachen- oder Analyzerfehlerdiagnose.'
    FROM [#SsisCatalogExecutionAnalysis_Execution] WHERE [ExecutionStatus] IN (1,2,3,4,5,6,8);

    INSERT [#SsisCatalogExecutionAnalysis_Warnings]([WarningOrdinal],[WarningCode],[SourceName],[Detail])
    SELECT CONVERT(int,ROW_NUMBER() OVER (ORDER BY [SourceOrdinal])),'LOGGING_EVIDENCE_NOT_OBSERVED',[SourceName],
           N'Die aktivierte Performancequelle wurde erfolgreich leer gelesen. Daraus folgen weder Nullaufwand noch eine bestimmte Loggingstufe oder Ursache.'
    FROM [#SsisCatalogExecutionAnalysis_SourceStatus] WHERE [SourceOrdinal] IN (2,3,6,7) AND [StatusCode]='AVAILABLE_EMPTY';

    INSERT [#SsisCatalogExecutionAnalysis_ModuleStatus]
        ([ModuleName],[SchemaVersion],[ExecutionId],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[CollectionTimeUtc])
    VALUES (N'USP_SsisCatalogExecutionAnalysis',1,@ExecutionId,@StatusCode,@IsPartial,@ErrorNumber,@ErrorMessage,@Now);
    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;

    IF COALESCE(@JsonErzeugen,0)=1
        SELECT @Json=(SELECT
            JSON_QUERY(COALESCE((SELECT * FROM [#SsisCatalogExecutionAnalysis_ModuleStatus] ORDER BY [ModuleName] FOR JSON PATH, INCLUDE_NULL_VALUES),N'[]')) AS [moduleStatus]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisCatalogExecutionAnalysis_Execution] ORDER BY [ExecutionId] FOR JSON PATH, INCLUDE_NULL_VALUES),N'[]')) AS [execution]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisCatalogExecutionAnalysis_Executables] ORDER BY [StatisticsId] FOR JSON PATH, INCLUDE_NULL_VALUES),N'[]')) AS [executables]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisCatalogExecutionAnalysis_Messages] ORDER BY [EventMessageId] FOR JSON PATH, INCLUDE_NULL_VALUES),N'[]')) AS [messages]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisCatalogExecutionAnalysis_Parameters] ORDER BY [ExecutionParameterId] FOR JSON PATH, INCLUDE_NULL_VALUES),N'[]')) AS [parameters]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisCatalogExecutionAnalysis_Phases] ORDER BY [PhaseStatsId] FOR JSON PATH, INCLUDE_NULL_VALUES),N'[]')) AS [phases]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisCatalogExecutionAnalysis_RowFlow] ORDER BY [DataStatsId] FOR JSON PATH, INCLUDE_NULL_VALUES),N'[]')) AS [rowFlow]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisCatalogExecutionAnalysis_Findings] ORDER BY [FindingCode] FOR JSON PATH, INCLUDE_NULL_VALUES),N'[]')) AS [findings]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisCatalogExecutionAnalysis_SourceStatus] ORDER BY [SourceOrdinal] FOR JSON PATH, INCLUDE_NULL_VALUES),N'[]')) AS [sourceStatus]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisCatalogExecutionAnalysis_Warnings] ORDER BY [WarningOrdinal] FOR JSON PATH, INCLUDE_NULL_VALUES),N'[]')) AS [warnings]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    IF @TableRequested=1
    BEGIN
        DECLARE @TargetTable sysname;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisCatalogExecutionAnalysis_ResultTables] WHERE [ResultName]=N'moduleStatus'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisCatalogExecutionAnalysis_ModuleStatus',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisCatalogExecutionAnalysis_ResultTables] WHERE [ResultName]=N'execution'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisCatalogExecutionAnalysis_Execution',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisCatalogExecutionAnalysis_ResultTables] WHERE [ResultName]=N'executables'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisCatalogExecutionAnalysis_Executables',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisCatalogExecutionAnalysis_ResultTables] WHERE [ResultName]=N'messages'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisCatalogExecutionAnalysis_Messages',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisCatalogExecutionAnalysis_ResultTables] WHERE [ResultName]=N'parameters'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisCatalogExecutionAnalysis_Parameters',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisCatalogExecutionAnalysis_ResultTables] WHERE [ResultName]=N'phases'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisCatalogExecutionAnalysis_Phases',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisCatalogExecutionAnalysis_ResultTables] WHERE [ResultName]=N'rowFlow'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisCatalogExecutionAnalysis_RowFlow',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisCatalogExecutionAnalysis_ResultTables] WHERE [ResultName]=N'findings'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisCatalogExecutionAnalysis_Findings',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisCatalogExecutionAnalysis_ResultTables] WHERE [ResultName]=N'sourceStatus'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisCatalogExecutionAnalysis_SourceStatus',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisCatalogExecutionAnalysis_ResultTables] WHERE [ResultName]=N'warnings'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisCatalogExecutionAnalysis_Warnings',@TargetTable,@ThrowOnError=1;
    END;
    IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#SsisCatalogExecutionAnalysis_ModuleStatus] ORDER BY [ModuleName];
        SELECT * FROM [#SsisCatalogExecutionAnalysis_Execution] ORDER BY [ExecutionId];
        SELECT * FROM [#SsisCatalogExecutionAnalysis_Executables] ORDER BY [StatisticsId];
        SELECT * FROM [#SsisCatalogExecutionAnalysis_Messages] ORDER BY [EventMessageId];
        SELECT * FROM [#SsisCatalogExecutionAnalysis_Parameters] ORDER BY [ExecutionParameterId];
        SELECT * FROM [#SsisCatalogExecutionAnalysis_Phases] ORDER BY [PhaseStatsId];
        SELECT * FROM [#SsisCatalogExecutionAnalysis_RowFlow] ORDER BY [DataStatsId];
        SELECT * FROM [#SsisCatalogExecutionAnalysis_Findings] ORDER BY [FindingCode];
        SELECT * FROM [#SsisCatalogExecutionAnalysis_SourceStatus] ORDER BY [SourceOrdinal];
        SELECT * FROM [#SsisCatalogExecutionAnalysis_Warnings] ORDER BY [WarningOrdinal];
    END;
    IF @ConsoleResultRequested=1
    BEGIN
        CREATE TABLE [#SsisCatalogExecutionAnalysis_Console]
        (
            [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [Unvollständig] bit NOT NULL,
            [ExecutionId] bigint NULL,
            [PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ExecutionStatus] int NULL,
            [StartTime] datetimeoffset(7) NULL,
            [EndTime] datetimeoffset(7) NULL,
            [Hinweis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        INSERT [#SsisCatalogExecutionAnalysis_Console]
            ([Status],[Unvollständig],[ExecutionId],[PackageName],[ExecutionStatus],[StartTime],[EndTime],[Hinweis])
        SELECT @StatusCode,@IsPartial,
               [m].[ExecutionId],[e].[PackageName],[e].[ExecutionStatus],[e].[StartTime],[e].[EndTime],
               CASE WHEN [e].[ExecutionId] IS NULL THEN N'Keine sichtbare Ausführung; Quellenstatus und Fehlergrenzen beachten.'
                    ELSE N'Native Metadaten; Fehlerstatus und leere Loggingquellen sind keine Ursachendiagnose.' END AS [Hinweis]
        FROM [#SsisCatalogExecutionAnalysis_ModuleStatus] AS [m]
        LEFT JOIN [#SsisCatalogExecutionAnalysis_Execution] AS [e] ON [e].[ExecutionId]=[m].[ExecutionId];
        EXEC [monitor].[InternalEmitConsoleResult]
            @SourceTable=N'#SsisCatalogExecutionAnalysis_Console',
            @ResultLabel=N'SSISDB-Ausführung',@EmptyMessage=N'Keine sichtbare SSISDB-Ausführung';
    END;
END;
GO

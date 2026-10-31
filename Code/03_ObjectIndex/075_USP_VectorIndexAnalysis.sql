USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_VectorIndexAnalysis
Version      : 1.0.0
Stand        : 2026-07-23
Typ          : Stored Procedure
Zweck        : Inventarisiert sichtbare Vector-Indizes und korreliert deren
               aktuellen Hintergrundwartungszustand auf SQL Server 2025.
SQL-Version  : Installierbar ab SQL Server 2019. Vector-Quellen werden erst ab Product Major Version 17 nach Versions- und Schema-Prüfung dynamisch referenziert; ältere Versionen erhalten UNAVAILABLE_VERSION.
Datenquellen : Je Zieldatenbank höchstens einmal sys.vector_indexes und sys.dm_db_vector_indexes; Katalog- und Runtimequelle erhalten getrennte Status.
Abgrenzung   : Keine Vector-Nutzdaten, keine internen build_parameters, keine DDL-, Rebuild-, Such- oder Wartungsaktion. Staleness ist flüchtige Reviewevidenz und kein alleiniger Rebuildnachweis.
Kosten       : LOW_TO_HIGH_OPT_IN. Scopefilter begrenzen Datenbanken/Objekte. @MaxZeilen begrenzt vectorIndexes, maintenance und findings jeweils separat nur in RAW und JSON. CONSOLE und TABLE erhalten die vollständigen jeweiligen Quellen; die vorgelagerte Ermittlung bleibt ungekürzt.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_VectorIndexAnalysis]
      @DatabaseNames                  nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @HighImpactConfirmed            bit            = 0
    , @SchemaNames                    nvarchar(max)  = NULL
    , @SchemaNamePattern              nvarchar(4000) = NULL
    , @ObjectNames                    nvarchar(max)  = NULL
    , @ObjectNamePattern              nvarchar(4000) = NULL
    , @FullObjectNames                nvarchar(max)  = NULL
    , @IndexNames                     nvarchar(max)  = NULL
    , @IndexNamePattern               nvarchar(4000) = NULL
    , @StalenessReviewPercent         decimal(5,2)  = 15.00
    , @MaxZeilen                      int            = 2000
    , @LockTimeoutMs                  int            = 0
    , @ResultSetArt                   varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max)  = NULL
    , @JsonErzeugen                   bit            = 0
    , @Json                           nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                 bit            = 1
    , @Hilfe                          bit            = 0
    , @StatusCodeOut                  varchar(40)    = NULL OUTPUT
    , @IsPartialOut                   bit            = NULL OUTPUT
    , @ErrorNumberOut                 int            = NULL OUTPUT
    , @ErrorMessageOut                nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;

    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME();
    DECLARE @ProductMajorVersion int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ConsoleResultRequested bit=CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @StatusCode varchar(40)='AVAILABLE';
    DECLARE @IsPartial bit=0;
    DECLARE @ErrorNumber int=NULL;
    DECLARE @ErrorMessage nvarchar(2048)=NULL;
    DECLARE @CrossDatabaseRequested bit=0;
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0
                               THEN CONVERT(bigint,9223372036854775807)
                               ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @OriginalLockTimeout int = @@LOCK_TIMEOUT;
    DECLARE @LockTimeoutSql nvarchar(64);

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_VectorIndexAnalysis';
        PRINT N'Inventarisiert sichtbare Vector-Indizes und korreliert deren aktuelle Hintergrundwartung; keine Vector-Werte, Suche, DDL oder Wartung.';
        PRINT N'Vector-Systemquellen werden erst ab Product Major Version 17 nach Versions- und Schema-Prüfung dynamisch referenziert; ältere Engineversionen erhalten UNAVAILABLE_VERSION.';
        PRINT N'Katalog- und Runtimequelle besitzen getrennte Status. Wartungswerte sind flüchtige Evidenz und kein historischer Verlauf.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Optionaler einteiliger Datenbankname oder bracket-aware Pipe-Liste; | trennt außerhalb von [...], ]] maskiert ]; Elemente außen getrimmt und case-sensitive. NULL, N'''' oder nur Leerzeichen bedeutet keine exakte Auswahl und prüft alle zulässigen sichtbaren ONLINE-Benutzerdatenbanken. Nichtleere Liste ist mit nicht-NULL @DatabaseNamePattern exklusiv. Leere/ungültige Elemente, Duplikate, ungültiger PARSENAME-Name oder Rohsegment über 4000 UTF-16-Codeeinheiten sind INVALID_PARAMETER; LEN höchstens 128.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. 0 (Default) schließt master, model, msdb und tempdb aus; 1 lässt sie in die Auswahl zu. NULL INVALID_PARAMETER. Beim Binden an bit werden konvertierbare numerische Werte ungleich 0 auf 1 abgebildet.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Datenbankpattern; NULL kein Filter, leer/Whitespace oder Präfix ohne Inhalt ungültig. Außen trimmen; like:, regex:, regexi: ohne Beachtung der Großschreibung; Rest nicht erneut trimmen; ohne Präfix LIKE. LIKE nutzt %, _ und [...] case-sensitiv. regex: Flag c, regexi: Flag i; Syntax wird nicht vorgeprüft. Dieser Datenbankpatternpfad prüft Regex-Verfügbarkeit im Installationsdatenbankkontext (SQL Server 2025, Compatibility Level 170), sonst UNAVAILABLE_FEATURE. Nicht mit wirksamer nichtleerer Datenbankliste kombinieren.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. 0 (Default) bestätigt kein High-Impact-Gate; 1 bestätigt die Anforderung eines tatsächlich aktivierten Analysepfads. NULL INVALID_PARAMETER. Dieses Modul übergibt OBJECT_ANALYSIS_CURRENT an den Kandidatenhelfer. Bestätigung ersetzt weder Aktivierung/Freigabe noch die Prüfung, ob die Klasse ein Gruppengate verlangt. Bit-Bindung bildet konvertierbare numerische Nichtnullwerte auf 1 ab.';
        PRINT N'@SchemaNames nvarchar(max); Default: NULL. Optionale exakte einteilige Schemanamen als bracket-aware Pipe-Liste; | trennt außerhalb von [...], ]] maskiert ]; außen getrimmt und case-sensitive. NULL kein Filter; nicht-NULL leer/Whitespace, leere/ungültige Elemente, Duplikate, ungültiger PARSENAME-Name oder Rohsegment über 4000 UTF-16-Codeeinheiten ungültig. Teil 1 muss vorhanden, Teil 2 NULL und LEN höchstens 128 sein. Nicht mit nicht-NULL @SchemaNamePattern oder @FullObjectNames kombinieren.';
        PRINT N'@SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Schema-Pattern; NULL deaktiviert, leer/Whitespace oder leeres Präfix ungültig. Außen trimmen; Präfixe like:, regex:, regexi: ohne Beachtung der Großschreibung; Rest nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: c, regexi: i. Regex läuft in der jeweiligen Zieldatenbank ohne separate Versions-/Kompatibilitätsvorprüfung; fehlende Funktion kann als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit nicht-NULL @SchemaNames kombinieren.';
        PRINT N'@ObjectNames nvarchar(max); Default: NULL. Optionale exakte einteilige Objektnamen als bracket-aware Pipe-Liste; | trennt außerhalb von [...], ]] maskiert ]; außen getrimmt, case-sensitive. NULL kein Filter; nicht-NULL leere Liste, leere/ungültige Elemente, Duplikate, PARSENAME-Fehler oder Rohsegment über 4000 UTF-16-Codeeinheiten ungültig; LEN höchstens 128. Nicht mit nicht-NULL @ObjectNamePattern oder @FullObjectNames kombinieren.';
        PRINT N'@ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objektpattern; NULL deaktiviert, leer/Whitespace oder Präfix ohne Inhalt ungültig. Außen trimmen; Präfixe like:, regex:, regexi: case-insensitiv erkannt; Rest nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: c, regexi: i. Feldregex läuft in Zieldatenbank ohne eigene Versions-/Kompatibilitätsvorprüfung und kann je Datenbank als ERROR_HANDLED isoliert werden. Nicht mit nicht-NULL @ObjectNames kombinieren.';
        PRINT N'@FullObjectNames nvarchar(max); Default: NULL. Optionale bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. | trennt außerhalb von [...], ]] maskiert ]; geparst mit PARSENAME, case-sensitive, Rohsegment bis 4000 UTF-16-Codeeinheiten und Bestandteile sysname-limitiert. Datenbankteil braucht Schema; vier Teile unzulässig. NULL kein Filter; nicht-NULL leere Liste ungültig. Nicht angegebene Datenbank-/Schemaanteile bleiben offen. Mit nicht-NULL @SchemaNames oder @ObjectNames exklusiv.';
        PRINT N'@IndexNames nvarchar(max); Default: NULL. Optionale exakte einteilige Indexnamen als bracket-aware Pipe-Liste; | trennt außerhalb von [...], ]] maskiert ]; außen getrimmt und case-sensitive. NULL kein Filter; nicht-NULL leer/Whitespace, ungültige/leere Elemente, Duplikate oder ungültiger PARSENAME-/sysname-Wert INVALID_PARAMETER. Rohsegmente bis 4000 UTF-16-Codeeinheiten. Mit nicht-NULL @IndexNamePattern exklusiv.';
        PRINT N'@IndexNamePattern nvarchar(4000); Default: NULL. Optionales Indexpattern; NULL kein Filter, leer/Whitespace oder Präfix ohne Inhalt ungültig. Außen trimmen; like:, regex:, regexi: ohne Beachtung der Großschreibung; Rest danach nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: c, regexi: i. Regex wird in Zieldatenbank ohne separate Versions-/Kompatibilitätsvorprüfung ausgeführt und kann datenbankweise isoliert fehlschlagen. Nicht mit nicht-NULL @IndexNames kombinieren.';
        PRINT N'@StalenessReviewPercent decimal(5,2); Default: 15.00. Optionaler Reviewgrenzwert in Prozent, 0 bis 100 einschließlich; NULL deaktiviert nur das VECTOR_STALENESS_REVIEW-Finding. Default 15.00: Finding bei verfügbarer ungefährer Staleness >= Grenzwert. Kein universeller Fehler-/Rebuildgrenzwert.';
        PRINT N'@MaxZeilen int; Default: 2000. Nichtnegative int-Grenze; 0 oder NULL bedeutet unbegrenzt, negative Werte führen zu INVALID_PARAMETER. Nur in RAW und JSON begrenzt ein positiver Wert vectorIndexes, maintenance und findings jeweils separat; hasMore meldet weitere Zeilen. CONSOLE zeigt alle Findings, TABLE schreibt die vollständigen gemappten Quellen. Status-, Quellenstatus- und Warnmengen bleiben ungekürzt; Ermittlung und Korrelation werden dadurch nicht global begrenzt.';
        PRINT N'@LockTimeoutMs int; Default: 0. Lockwartezeit in Millisekunden von 0 bis 60000 einschließlich; 0 bedeutet NOWAIT, außerhalb INVALID_PARAMETER. Im Analysepfad wird der Wert dynamisch gesetzt; vor der Ausgabe wird aus dem zuvor gespeicherten @@LOCK_TIMEOUT ein separater Wiederherstellungsbatch gebildet. NULL wird von der Bereichsprüfung nicht als ungültig erkannt; die spätere dynamische SET-LOCK_TIMEOUT-Textbildung wird durch den NULL-Wert NULL. Ein konkreter Ausführungsstatus dieses NULL-Batches wird hier nicht zugesichert.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach TRIM/UPPER genau CONSOLE, RAW, TABLE oder NONE; NULL/leer wird ungültig. CONSOLE zeigt eine menschenlesbare Findings-Ansicht. RAW liefert sechs getrennte Mengen: moduleStatus, vectorIndexes, maintenance, findings, sourceStatus, warnings. TABLE schreibt gemappte Namen; NONE unterdrückt reguläre Resultsets. JSON-OUTPUT unabhängig über @JsonErzeugen.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE ein JSON-Objekt Resultsetname→vorhandene lokale #Temp-Tabelle. TABLE erfordert gültiges nichtleeres Objekt mit ausschließlich moduleStatus, vectorIndexes, maintenance, findings, sourceStatus oder warnings. Ziele eindeutig, lokal, leer und mit genau einer Seed-Spalte; der Helper prüft und wirft bei Fehler. Außerhalb TABLE führt nichtleerer Inhalt zu INVALID_PARAMETER; NULL/leer dort zulässig.';
        PRINT N'@JsonErzeugen bit; Default: 0. 0 unterdrückt JSON-Erzeugung; 1 befüllt @Json mit Schema 1 und Schlüsseln meta, vectorIndexes, maintenance, findings, sourceStatus, warnings. NULL ist INVALID_PARAMETER. JSON-Facharrays folgen der jeweiligen @MaxZeilen-Grenze; hasMore… zeigt weitere Zeilen an.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionaler nvarchar(max)-OUTPUT-Empfänger, zu Beginn auf NULL gesetzt; mit @JsonErzeugen=1 enthält er das JSON-Dokument. Zum Empfang Variable des passenden Typs mit OUTPUT binden; ohne OUTPUT kommt Zuweisung nicht beim Aufrufer an. Hilfe kehrt nach dem NULL-Set zurück.';
        PRINT N'@PrintMeldungen bit; Default: 1. 0 unterdrückt Severity-10-Statusmeldung; 1 (Default) sendet sie bei Abschluss außer bei AVAILABLE, AVAILABLE_WITH_FINDING und NOT_APPLICABLE. NULL INVALID_PARAMETER. Meldung ergänzt Status-/Warnings-Ausgaben.';
        PRINT N'@Hilfe bit; Default: 0. 1 druckt fünf Hilfezeilen und kehrt sofort vor Filter-, Ausgabe-, Datenbank- und Engineprüfungen sowie vor OUTPUT-Statuszuweisungen zurück. @Json ist zuvor bereits NULL. 0 normaler Ablauf; NULL wird nicht als 1 behandelt.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger varchar(40); erhält am regulären Ablaufende den finalen Modulstatus. Mit passender varchar(40)-Aufrufervariable samt OUTPUT binden; ohne OUTPUT erreicht die Zuweisung den Aufrufer nicht. Default NULL; bei frühem @Hilfe-Return unverändert. AVAILABLE bedeutet verfügbare Erhebung ohne Finding/Partialität; AVAILABLE_WITH_FINDING kennzeichnet mindestens ein WARN-Finding; AVAILABLE_LIMITED bedeutet partielle Erhebung; NOT_APPLICABLE: keine sichtbaren Vector-Indizes; UNAVAILABLE_VERSION: Product Major Version fehlt oder kleiner 17; UNAVAILABLE_FEATURE: keine verfügbare Vector-Quelle. Bei fehlendem erfolgreichem Katalogstatus kann zusätzlich der erste Katalogquellenstatus wie DENIED_PERMISSION, TIMEOUT, ERROR_HANDLED oder UNAVAILABLE_SOURCE_SCHEMA ausgegeben werden; ungültige Eingabe ergibt INVALID_PARAMETER. Quellenstatus bleibt separat in sourceStatus.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger bit; erhält am regulären Ablaufende den Partialitätsindikator. 1 kennzeichnet unvollständige/abgewiesene Erhebung; 0 eine nicht als partiell markierte Erhebung. Mit bit-Variable samt OUTPUT binden; ohne OUTPUT keine Rückgabe. Default NULL und bei frühem Hilfe-Return unverändert.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger int; erhält am normalen Ablaufende die gesetzte Fehlernummer oder NULL, wenn keine Fehlernummer für den Modulstatus gewählt wurde. Eine int-Variable mit OUTPUT bindet den Rückgabewert; ohne OUTPUT keine Rückgabe. Default NULL und bei Hilfe unverändert.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger nvarchar(2048); erhält am normalen Ablaufende die gewählte Fehler-/Warnmeldung oder NULL. Bei fehlendem expliziten Fehlertext wird die erste Warnmeldung gewählt. Eine nvarchar(2048)-Variable mit OUTPUT bindet den Rückgabewert; ohne OUTPUT keine Rückgabe. Default NULL und bei Hilfe unverändert.';
        PRINT N'EXEC [monitor].[USP_VectorIndexAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''[ExampleSchema].[ExampleTable]'', @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @VectorIndexAnalysis_JsonExample nvarchar(max); EXEC [monitor].[USP_VectorIndexAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @JsonErzeugen=1, @Json=@VectorIndexAnalysis_JsonExample OUTPUT; SELECT @VectorIndexAnalysis_JsonExample AS [JsonDocument];';
        PRINT N'EXEC [monitor].[USP_VectorIndexAnalysis] @Hilfe=1;';





        RETURN;
    END;

    CREATE TABLE [#VectorIndexAnalysis_ResultTableMap]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE
    );
    CREATE TABLE [#VectorIndexAnalysis_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL
        , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsSystemDatabase] bit NULL
        , [RequestedOrdinal] int NULL
    );
    CREATE TABLE [#VectorIndexAnalysis_CandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#VectorIndexAnalysis_NameFilters]
    (
          [FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ItemOrdinal] int NOT NULL
        , [NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#VectorIndexAnalysis_VectorIndexes]
    (
          [CapturedAtUtc] datetime2(3) NOT NULL
        , [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CompatibilityLevel] tinyint NULL
        , [PreviewFeaturesEnabled] bit NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectId] int NOT NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IndexId] int NOT NULL
        , [IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [VectorIndexType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DistanceMetric] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsDisabled] bit NOT NULL
        , [CatalogStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([DatabaseId],[ObjectId],[IndexId])
    );
    CREATE TABLE [#VectorIndexAnalysis_RuntimeRaw]
    (
          [DatabaseId] int NOT NULL
        , [ObjectId] int NOT NULL
        , [IndexId] int NOT NULL
        , [ApproximateStalenessPercent] decimal(10,2) NULL
        , [QuantizedKeysUsedPercent] decimal(10,2) NULL
        , [LastBackgroundTaskTime] datetime2(7) NULL
        , [LastBackgroundTaskSucceeded] bit NULL
        , [LastBackgroundTaskDurationSeconds] bigint NULL
        , [LastBackgroundTaskProcessedInserts] bigint NULL
        , [LastBackgroundTaskProcessedDeletes] bigint NULL
        , [LastBackgroundTaskErrorMessage] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , PRIMARY KEY ([DatabaseId],[ObjectId],[IndexId])
    );
    CREATE TABLE [#VectorIndexAnalysis_Maintenance]
    (
          [CapturedAtUtc] datetime2(3) NOT NULL
        , [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectId] int NOT NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IndexId] int NOT NULL
        , [IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ApproximateStalenessPercent] decimal(10,2) NULL
        , [QuantizedKeysUsedPercent] decimal(10,2) NULL
        , [LastBackgroundTaskTime] datetime2(7) NULL
        , [LastBackgroundTaskSucceeded] bit NULL
        , [LastBackgroundTaskDurationSeconds] bigint NULL
        , [LastBackgroundTaskProcessedInserts] bigint NULL
        , [LastBackgroundTaskProcessedDeletes] bigint NULL
        , [LastBackgroundTaskErrorMessage] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([DatabaseId],[ObjectId],[IndexId])
    );
    CREATE TABLE [#VectorIndexAnalysis_Findings]
    (
          [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricValue] decimal(38,4) NULL
        , [ThresholdValue] decimal(38,4) NULL
        , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#VectorIndexAnalysis_SourceStatus]
    (
          [SourceOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [DatabaseId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [ReturnedRowCount] bigint NOT NULL
        , [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#VectorIndexAnalysis_Warnings]
    (
          [WarningOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#VectorIndexAnalysis_ModuleStatus]
    (
          [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [ProductMajorVersion] int NULL
        , [CrossDatabaseRequested] bit NOT NULL
        , [DatabaseCount] int NOT NULL
        , [VectorIndexRowCount] bigint NOT NULL
        , [MaintenanceRowCount] bigint NOT NULL
        , [FindingRowCount] bigint NOT NULL
        , [HasMoreVectorIndexRows] bit NOT NULL
        , [HasMoreMaintenanceRows] bit NOT NULL
        , [HasMoreFindingRows] bit NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    DECLARE
          @SchemaPatternMode varchar(8),@SchemaPatternValue nvarchar(4000),@SchemaRegexFlags varchar(8),@SchemaPatternValid bit
        , @ObjectPatternMode varchar(8),@ObjectPatternValue nvarchar(4000),@ObjectRegexFlags varchar(8),@ObjectPatternValid bit
        , @IndexPatternMode varchar(8),@IndexPatternValue nvarchar(4000),@IndexRegexFlags varchar(8),@IndexPatternValid bit;
    SELECT @SchemaPatternMode=[PatternMode],@SchemaPatternValue=[PatternValue],@SchemaRegexFlags=[RegexFlags],@SchemaPatternValid=[IsValid]
    FROM [monitor].[TVF_ParsePattern](@SchemaNamePattern);
    SELECT @ObjectPatternMode=[PatternMode],@ObjectPatternValue=[PatternValue],@ObjectRegexFlags=[RegexFlags],@ObjectPatternValid=[IsValid]
    FROM [monitor].[TVF_ParsePattern](@ObjectNamePattern);
    SELECT @IndexPatternMode=[PatternMode],@IndexPatternValue=[PatternValue],@IndexRegexFlags=[RegexFlags],@IndexPatternValid=[IsValid]
    FROM [monitor].[TVF_ParsePattern](@IndexNamePattern);

    IF @MaxZeilen<0 OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @SystemdatenbankenEinbeziehen IS NULL OR @HighImpactConfirmed IS NULL
       OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
       OR @OutputMode NOT IN('CONSOLE','RAW','TABLE','NONE')
       OR (@OutputMode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
       OR (@SchemaNames IS NOT NULL AND @SchemaNamePattern IS NOT NULL)
       OR (@ObjectNames IS NOT NULL AND @ObjectNamePattern IS NOT NULL)
       OR (@IndexNames IS NOT NULL AND @IndexNamePattern IS NOT NULL)
       OR COALESCE(@SchemaPatternValid,0)=0 OR COALESCE(@ObjectPatternValid,0)=0 OR COALESCE(@IndexPatternValid,0)=0
       OR (@StalenessReviewPercent IS NOT NULL AND @StalenessReviewPercent NOT BETWEEN 0 AND 100)
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,
               @ErrorMessage=N'Ungültiger Filter-, Grenzwert-, Lock-Timeout- oder Ausgabeparameter.';
    END;

    IF @StatusCode='AVAILABLE' AND @OutputMode='TABLE'
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'moduleStatus|vectorIndexes|maintenance|findings|sourceStatus|warnings'
            , @MappingTable=N'#VectorIndexAnalysis_ResultTableMap'
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @ThrowOnError=1;

    IF @StatusCode='AVAILABLE'
        EXEC [monitor].[USP_PrepareNameFilters]
              @SchemaNames=@SchemaNames
            , @ObjectNames=@ObjectNames
            , @FullObjectNames=@FullObjectNames
            , @IndexNames=@IndexNames
            , @StatisticsNames=NULL
            , @ColumnNames=NULL
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @FilterTable=N'#VectorIndexAnalysis_NameFilters';

    IF @StatusCode='AVAILABLE'
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames=@DatabaseNames
            , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern=@DatabaseNamePattern
            , @HighImpactConfirmed=@HighImpactConfirmed
            , @AnalysisClass='OBJECT_ANALYSIS_CURRENT'
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT
            , @CandidateTable=N'#VectorIndexAnalysis_DatabaseCandidates'
            , @WarningTable=N'#VectorIndexAnalysis_CandidateWarnings';

    DECLARE @SchemaPredicate nvarchar(max)=N'';
    DECLARE @ObjectPredicate nvarchar(max)=N'';
    DECLARE @IndexPredicate nvarchar(max)=N'';

    SET @SchemaPredicate=N'
      AND (NOT EXISTS(SELECT 1 FROM [#VectorIndexAnalysis_NameFilters] WHERE [FilterType]=''SCHEMA'')
           OR EXISTS(SELECT 1 FROM [#VectorIndexAnalysis_NameFilters] AS [f]
                     WHERE [f].[FilterType]=''SCHEMA''
                       AND [f].[NameValue]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @ObjectPredicate=N'
      AND (NOT EXISTS(SELECT 1 FROM [#VectorIndexAnalysis_NameFilters] WHERE [FilterType]=''OBJECT'')
           OR EXISTS(SELECT 1 FROM [#VectorIndexAnalysis_NameFilters] AS [f]
                     WHERE [f].[FilterType]=''OBJECT''
                       AND [f].[NameValue]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))
      AND (NOT EXISTS(SELECT 1 FROM [#VectorIndexAnalysis_NameFilters] WHERE [FilterType]=''FULL_OBJECT'')
           OR EXISTS(SELECT 1 FROM [#VectorIndexAnalysis_NameFilters] AS [f]
                     WHERE [f].[FilterType]=''FULL_OBJECT''
                       AND ([f].[DatabaseName] IS NULL OR [f].[DatabaseName]=@pDatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS)
                       AND ([f].[SchemaName] IS NULL OR [f].[SchemaName]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS)
                       AND [f].[ObjectName]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @IndexPredicate=N'
      AND (NOT EXISTS(SELECT 1 FROM [#VectorIndexAnalysis_NameFilters] WHERE [FilterType]=''INDEX'')
           OR EXISTS(SELECT 1 FROM [#VectorIndexAnalysis_NameFilters] AS [f]
                     WHERE [f].[FilterType]=''INDEX''
                       AND [f].[NameValue]=[v].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';

    IF @SchemaPatternMode='LIKE'
        SET @SchemaPredicate+=N' AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @pSchemaPattern COLLATE SQL_Latin1_General_CP1_CS_AS';
    ELSE IF @SchemaPatternMode IN('REGEX','REGEXI')
        SET @SchemaPredicate+=N' AND REGEXP_LIKE([s].[name],@pSchemaPattern,@pSchemaFlags)';
    IF @ObjectPatternMode='LIKE'
        SET @ObjectPredicate+=N' AND [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @pObjectPattern COLLATE SQL_Latin1_General_CP1_CS_AS';
    ELSE IF @ObjectPatternMode IN('REGEX','REGEXI')
        SET @ObjectPredicate+=N' AND REGEXP_LIKE([o].[name],@pObjectPattern,@pObjectFlags)';
    IF @IndexPatternMode='LIKE'
        SET @IndexPredicate+=N' AND [v].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @pIndexPattern COLLATE SQL_Latin1_General_CP1_CS_AS';
    ELSE IF @IndexPatternMode IN('REGEX','REGEXI')
        SET @IndexPredicate+=N' AND REGEXP_LIKE([v].[name],@pIndexPattern,@pIndexFlags)';

    IF @StatusCode='AVAILABLE'
    BEGIN
        SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';
        EXEC [sys].[sp_executesql] @LockTimeoutSql;

        DECLARE
              @DatabaseId int
            , @DatabaseName sysname
            , @CompatibilityLevel tinyint
            , @PreviewFeaturesEnabled bit
            , @HasVectorCatalog bit
            , @HasVectorRuntime bit
            , @VectorCatalogSchemaValid bit
            , @VectorRuntimeSchemaValid bit
            , @ProbeSql nvarchar(max)
            , @CatalogSql nvarchar(max)
            , @RuntimeSql nvarchar(max)
            , @CatalogRows bigint
            , @RuntimeRows bigint;

        DECLARE [DatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId],[DatabaseName],[CompatibilityLevel]
            FROM [#VectorIndexAnalysis_DatabaseCandidates]
            ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];
        OPEN [DatabaseCursor];
        FETCH NEXT FROM [DatabaseCursor] INTO @DatabaseId,@DatabaseName,@CompatibilityLevel;
        WHILE @@FETCH_STATUS=0
        BEGIN
            IF @ProductMajorVersion IS NULL OR @ProductMajorVersion<17
            BEGIN
                INSERT [#VectorIndexAnalysis_SourceStatus]
                VALUES
                  (@DatabaseId,@DatabaseName,N'vectorCatalog',N'sys.vector_indexes',@CapturedAtUtc,'UNAVAILABLE_VERSION',0,0,N'Metadata Visibility',NULL,NULL,N'Vector-Indizes werden erst ab SQL Server 2025 referenziert.')
                , (@DatabaseId,@DatabaseName,N'vectorRuntime',N'sys.dm_db_vector_indexes',@CapturedAtUtc,'UNAVAILABLE_VERSION',0,0,N'VIEW DATABASE STATE',NULL,NULL,N'Die Runtime-DMV wird erst ab SQL Server 2025 referenziert.');
            END
            ELSE IF (@SchemaPatternMode IN('REGEX','REGEXI') OR @ObjectPatternMode IN('REGEX','REGEXI') OR @IndexPatternMode IN('REGEX','REGEXI'))
                    AND COALESCE(@CompatibilityLevel,0)<170
            BEGIN
                INSERT [#VectorIndexAnalysis_SourceStatus]
                VALUES
                  (@DatabaseId,@DatabaseName,N'vectorCatalog',N'sys.vector_indexes',@CapturedAtUtc,'UNAVAILABLE_PATTERN_CAPABILITY',1,0,N'Metadata Visibility',NULL,NULL,N'Regexfilter benötigen SQL Server 2025 und Compatibility Level 170.')
                , (@DatabaseId,@DatabaseName,N'vectorRuntime',N'sys.dm_db_vector_indexes',@CapturedAtUtc,'NOT_COLLECTED',1,0,N'VIEW DATABASE STATE',NULL,NULL,N'Die Runtimequelle wurde wegen des nicht ausführbaren Filters nicht gelesen.');
            END
            ELSE
            BEGIN
                SELECT
                      @PreviewFeaturesEnabled=NULL
                    , @HasVectorCatalog=0
                    , @HasVectorRuntime=0
                    , @VectorCatalogSchemaValid=0
                    , @VectorRuntimeSchemaValid=0;

                SET @ProbeSql=N'USE '+QUOTENAME(@DatabaseName)+N';
SELECT @pPreviewFeaturesEnabled=CONVERT(bit,MAX(CASE WHEN [name]=N''PREVIEW_FEATURES'' AND TRY_CONVERT(bit,[value])=1 THEN 1 ELSE 0 END))
FROM [sys].[database_scoped_configurations] WITH (NOLOCK);

SELECT @pHasVectorCatalog=CONVERT(bit,CASE WHEN EXISTS
(
    SELECT 1
    FROM [sys].[all_objects] AS [o] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
    WHERE [s].[name]=N''sys'' AND [o].[name]=N''vector_indexes''
) THEN 1 ELSE 0 END);

SELECT @pHasVectorRuntime=CONVERT(bit,CASE WHEN EXISTS
(
    SELECT 1
    FROM [sys].[all_objects] AS [o] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
    WHERE [s].[name]=N''sys'' AND [o].[name]=N''dm_db_vector_indexes''
) THEN 1 ELSE 0 END);

SELECT @pVectorCatalogSchemaValid=CONVERT(bit,CASE WHEN COUNT(DISTINCT [c].[name])=6 THEN 1 ELSE 0 END)
FROM [sys].[all_objects] AS [o] WITH (NOLOCK)
INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
INNER JOIN [sys].[all_columns] AS [c] WITH (NOLOCK) ON [c].[object_id]=[o].[object_id]
WHERE [s].[name]=N''sys'' AND [o].[name]=N''vector_indexes''
  AND [c].[name] IN(N''object_id'',N''index_id'',N''name'',N''vector_index_type'',N''distance_metric'',N''is_disabled'');

SELECT @pVectorRuntimeSchemaValid=CONVERT(bit,CASE WHEN COUNT(DISTINCT [c].[name])=10 THEN 1 ELSE 0 END)
FROM [sys].[all_objects] AS [o] WITH (NOLOCK)
INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
INNER JOIN [sys].[all_columns] AS [c] WITH (NOLOCK) ON [c].[object_id]=[o].[object_id]
WHERE [s].[name]=N''sys'' AND [o].[name]=N''dm_db_vector_indexes''
  AND [c].[name] IN
      (N''object_id'',N''index_id'',N''approximate_staleness_percent'',N''quantized_keys_used_percent'',
       N''last_background_task_time'',N''last_background_task_succeeded'',
       N''last_background_task_duration_seconds'',N''last_background_task_processed_inserts'',
       N''last_background_task_processed_deletes'',N''last_background_task_error_message'');';

                BEGIN TRY
                    EXEC [sys].[sp_executesql]
                          @ProbeSql
                        , N'@pPreviewFeaturesEnabled bit OUTPUT,@pHasVectorCatalog bit OUTPUT,@pHasVectorRuntime bit OUTPUT,@pVectorCatalogSchemaValid bit OUTPUT,@pVectorRuntimeSchemaValid bit OUTPUT'
                        , @pPreviewFeaturesEnabled=@PreviewFeaturesEnabled OUTPUT
                        , @pHasVectorCatalog=@HasVectorCatalog OUTPUT
                        , @pHasVectorRuntime=@HasVectorRuntime OUTPUT
                        , @pVectorCatalogSchemaValid=@VectorCatalogSchemaValid OUTPUT
                        , @pVectorRuntimeSchemaValid=@VectorRuntimeSchemaValid OUTPUT;
                END TRY
                BEGIN CATCH
                    INSERT [#VectorIndexAnalysis_SourceStatus]
                    VALUES
                      (@DatabaseId,@DatabaseName,N'vectorCatalog',N'sys.vector_indexes',@CapturedAtUtc,
                       CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                       1,0,N'Metadata Visibility',ERROR_NUMBER(),ERROR_MESSAGE(),N'Die Feature- und Schemaprüfung ist fehlgeschlagen; die versionsspezifische Quelle wurde nicht referenziert.')
                    , (@DatabaseId,@DatabaseName,N'vectorRuntime',N'sys.dm_db_vector_indexes',@CapturedAtUtc,'NOT_COLLECTED',1,0,N'VIEW DATABASE STATE',NULL,NULL,N'Die Runtimequelle wurde nach fehlgeschlagener Featureprüfung nicht gelesen.');
                    SELECT @HasVectorCatalog=0,@HasVectorRuntime=0,@VectorCatalogSchemaValid=0,@VectorRuntimeSchemaValid=0;
                END CATCH;

                IF @HasVectorCatalog=1 AND @VectorCatalogSchemaValid=1
                BEGIN
                    SET @CatalogSql=N'USE '+QUOTENAME(@DatabaseName)+N';
INSERT [#VectorIndexAnalysis_VectorIndexes]
([CapturedAtUtc],[DatabaseId],[DatabaseName],[CompatibilityLevel],[PreviewFeaturesEnabled],
 [SchemaName],[ObjectId],[ObjectName],[IndexId],[IndexName],[VectorIndexType],
 [DistanceMetric],[IsDisabled],[CatalogStatusCode],[EvidenceLimit])
SELECT @pCapturedAtUtc,@pDatabaseId,@pDatabaseName,@pCompatibilityLevel,@pPreviewFeaturesEnabled,
       [s].[name],[o].[object_id],[o].[name],[v].[index_id],[v].[name],
       CONVERT(varchar(20),[v].[vector_index_type]),CONVERT(varchar(20),[v].[distance_metric]),
       CONVERT(bit,[v].[is_disabled]),''AVAILABLE'',
       N''Sichtbarer Katalogzustand. Interne build_parameters und Vector-Nutzwerte werden nicht gelesen.''
FROM [sys].[vector_indexes] AS [v] WITH (NOLOCK)
INNER JOIN [sys].[objects] AS [o] WITH (NOLOCK) ON [o].[object_id]=[v].[object_id]
INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
WHERE [o].[is_ms_shipped]=0'
                        +@SchemaPredicate+@ObjectPredicate+@IndexPredicate+N'
OPTION (MAXDOP 1,RECOMPILE);';
                    BEGIN TRY
                        EXEC [sys].[sp_executesql]
                              @CatalogSql
                            , N'@pCapturedAtUtc datetime2(3),@pDatabaseId int,@pDatabaseName sysname,@pCompatibilityLevel tinyint,@pPreviewFeaturesEnabled bit,@pSchemaPattern nvarchar(4000),@pSchemaFlags varchar(8),@pObjectPattern nvarchar(4000),@pObjectFlags varchar(8),@pIndexPattern nvarchar(4000),@pIndexFlags varchar(8)'
                            , @pCapturedAtUtc=@CapturedAtUtc,@pDatabaseId=@DatabaseId,@pDatabaseName=@DatabaseName
                            , @pCompatibilityLevel=@CompatibilityLevel,@pPreviewFeaturesEnabled=@PreviewFeaturesEnabled
                            , @pSchemaPattern=@SchemaPatternValue,@pSchemaFlags=@SchemaRegexFlags
                            , @pObjectPattern=@ObjectPatternValue,@pObjectFlags=@ObjectRegexFlags
                            , @pIndexPattern=@IndexPatternValue,@pIndexFlags=@IndexRegexFlags;
                        SELECT @CatalogRows=COUNT_BIG(*) FROM [#VectorIndexAnalysis_VectorIndexes] WHERE [DatabaseId]=@DatabaseId;
                        INSERT [#VectorIndexAnalysis_SourceStatus]
                        VALUES(@DatabaseId,@DatabaseName,N'vectorCatalog',N'sys.vector_indexes',@CapturedAtUtc,
                               CASE WHEN @CatalogRows=0 AND @PreviewFeaturesEnabled=0 THEN 'NOT_ENABLED'
                                    WHEN @CatalogRows=0 THEN 'AVAILABLE_EMPTY' ELSE 'AVAILABLE' END,
                               0,@CatalogRows,N'Metadata Visibility',NULL,NULL,
                               N'Eine Zeile je sichtbarem Vector-Index; Nullzeilen beweisen bei eingeschränkter Metadatensicht keine serverweite Abwesenheit.');
                    END TRY
                    BEGIN CATCH
                        INSERT [#VectorIndexAnalysis_SourceStatus]
                        VALUES(@DatabaseId,@DatabaseName,N'vectorCatalog',N'sys.vector_indexes',@CapturedAtUtc,
                               CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                               1,0,N'Metadata Visibility',ERROR_NUMBER(),ERROR_MESSAGE(),N'Der Katalogfehler ist auf diese Datenbank begrenzt.');
                    END CATCH;
                END
                ELSE IF NOT EXISTS
                (
                    SELECT 1 FROM [#VectorIndexAnalysis_SourceStatus]
                    WHERE [DatabaseId]=@DatabaseId AND [SourceName]=N'vectorCatalog'
                )
                    INSERT [#VectorIndexAnalysis_SourceStatus]
                    VALUES(@DatabaseId,@DatabaseName,N'vectorCatalog',N'sys.vector_indexes',@CapturedAtUtc,
                           CASE WHEN @HasVectorCatalog=0 THEN 'UNAVAILABLE_FEATURE' ELSE 'UNAVAILABLE_SOURCE_SCHEMA' END,
                           CONVERT(bit,CASE WHEN @HasVectorCatalog=1 THEN 1 ELSE 0 END),
                           0,N'Metadata Visibility',NULL,NULL,N'Die Quelle oder ihr dokumentiertes Pflichtschema ist auf diesem SQL-Server-2025-Build nicht verfügbar.');

                IF @HasVectorRuntime=1 AND @VectorRuntimeSchemaValid=1
                BEGIN
                    SET @RuntimeSql=N'USE '+QUOTENAME(@DatabaseName)+N';
INSERT [#VectorIndexAnalysis_RuntimeRaw]
([DatabaseId],[ObjectId],[IndexId],[ApproximateStalenessPercent],[QuantizedKeysUsedPercent],
 [LastBackgroundTaskTime],[LastBackgroundTaskSucceeded],[LastBackgroundTaskDurationSeconds],
 [LastBackgroundTaskProcessedInserts],[LastBackgroundTaskProcessedDeletes],[LastBackgroundTaskErrorMessage])
SELECT @pDatabaseId,[object_id],[index_id],[approximate_staleness_percent],[quantized_keys_used_percent],
       [last_background_task_time],[last_background_task_succeeded],[last_background_task_duration_seconds],
       [last_background_task_processed_inserts],[last_background_task_processed_deletes],
       [last_background_task_error_message]
FROM [sys].[dm_db_vector_indexes] WITH (NOLOCK)
OPTION (MAXDOP 1,RECOMPILE);';
                    BEGIN TRY
                        EXEC [sys].[sp_executesql] @RuntimeSql,N'@pDatabaseId int',@pDatabaseId=@DatabaseId;
                        SELECT @RuntimeRows=COUNT_BIG(*) FROM [#VectorIndexAnalysis_RuntimeRaw] WHERE [DatabaseId]=@DatabaseId;
                        SELECT @CatalogRows=COUNT_BIG(*) FROM [#VectorIndexAnalysis_VectorIndexes] WHERE [DatabaseId]=@DatabaseId;
                        INSERT [#VectorIndexAnalysis_SourceStatus]
                        VALUES(@DatabaseId,@DatabaseName,N'vectorRuntime',N'sys.dm_db_vector_indexes',@CapturedAtUtc,
                               CASE WHEN @RuntimeRows=0 THEN 'AVAILABLE_EMPTY' ELSE 'AVAILABLE' END,
                               CONVERT(bit,CASE WHEN @CatalogRows>0 AND @RuntimeRows=0 THEN 1 ELSE 0 END),
                               @RuntimeRows,N'VIEW DATABASE STATE',NULL,NULL,
                               N'Flüchtiger aktueller Wartungszustand. Staleness, Taskstatus und Zähler besitzen keinen langfristigen Verlauf.');
                    END TRY
                    BEGIN CATCH
                        INSERT [#VectorIndexAnalysis_SourceStatus]
                        VALUES(@DatabaseId,@DatabaseName,N'vectorRuntime',N'sys.dm_db_vector_indexes',@CapturedAtUtc,
                               CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                               1,0,N'VIEW DATABASE STATE',ERROR_NUMBER(),ERROR_MESSAGE(),N'Der Runtimefehler ist auf diese Datenbank begrenzt; Katalogevidenz kann weiterhin gültig sein.');
                    END CATCH;
                END
                ELSE IF NOT EXISTS
                (
                    SELECT 1 FROM [#VectorIndexAnalysis_SourceStatus]
                    WHERE [DatabaseId]=@DatabaseId AND [SourceName]=N'vectorRuntime'
                )
                BEGIN
                    SELECT @CatalogRows=COUNT_BIG(*) FROM [#VectorIndexAnalysis_VectorIndexes] WHERE [DatabaseId]=@DatabaseId;
                    INSERT [#VectorIndexAnalysis_SourceStatus]
                    VALUES(@DatabaseId,@DatabaseName,N'vectorRuntime',N'sys.dm_db_vector_indexes',@CapturedAtUtc,
                           CASE WHEN @HasVectorRuntime=0 THEN 'UNAVAILABLE_FEATURE' ELSE 'UNAVAILABLE_SOURCE_SCHEMA' END,
                           CONVERT(bit,CASE WHEN @HasVectorRuntime=1 OR @CatalogRows>0 THEN 1 ELSE 0 END),
                           0,N'VIEW DATABASE STATE',NULL,NULL,N'Die Runtimequelle oder ihr dokumentiertes Pflichtschema ist auf diesem Build nicht verfügbar.');
                END;
            END;

            FETCH NEXT FROM [DatabaseCursor] INTO @DatabaseId,@DatabaseName,@CompatibilityLevel;
        END;
        CLOSE [DatabaseCursor];
        DEALLOCATE [DatabaseCursor];
    END;

    INSERT [#VectorIndexAnalysis_Maintenance]
    SELECT
          [v].[CapturedAtUtc],[v].[DatabaseId],[v].[DatabaseName],[v].[SchemaName]
        , [v].[ObjectId],[v].[ObjectName],[v].[IndexId],[v].[IndexName]
        , [r].[ApproximateStalenessPercent],[r].[QuantizedKeysUsedPercent]
        , [r].[LastBackgroundTaskTime],[r].[LastBackgroundTaskSucceeded]
        , [r].[LastBackgroundTaskDurationSeconds],[r].[LastBackgroundTaskProcessedInserts]
        , [r].[LastBackgroundTaskProcessedDeletes],[r].[LastBackgroundTaskErrorMessage]
        , CASE WHEN [r].[ObjectId] IS NOT NULL THEN 'AVAILABLE'
               WHEN [ss].[StatusCode] IN('AVAILABLE','AVAILABLE_EMPTY') THEN 'NOT_RETURNED'
               ELSE COALESCE([ss].[StatusCode],'NOT_COLLECTED') END
        , N'Runtimeevidenz ist eine Momentaufnahme. Eine fehlende Zeile, einzelne Stalenessmessung oder ein Taskfehler beweist weder dauerhafte Suchqualitäts- noch Storageprobleme.'
    FROM [#VectorIndexAnalysis_VectorIndexes] AS [v]
    LEFT JOIN [#VectorIndexAnalysis_RuntimeRaw] AS [r]
      ON [r].[DatabaseId]=[v].[DatabaseId]
     AND [r].[ObjectId]=[v].[ObjectId]
     AND [r].[IndexId]=[v].[IndexId]
    OUTER APPLY
    (
        SELECT TOP(1) [s].[StatusCode]
        FROM [#VectorIndexAnalysis_SourceStatus] AS [s]
        WHERE [s].[DatabaseId]=[v].[DatabaseId] AND [s].[SourceName]=N'vectorRuntime'
        ORDER BY [s].[SourceOrdinal] DESC
    ) AS [ss];

    INSERT [#VectorIndexAnalysis_Findings]
    ([DatabaseName],[SchemaName],[ObjectName],[IndexName],[Severity],[Confidence],[FindingCode],
     [MetricName],[MetricValue],[ThresholdValue],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],[SchemaName],[ObjectName],[IndexName],'INFO','HIGH','VECTOR_INDEX_DISABLED',
           'IS_DISABLED',1,NULL,N'Der sichtbare Vector-Index ist deaktiviert.',
           N'Der Katalogzustand ist aktuell, enthält aber keine Betriebsabsicht und keinen Nachweis zur Ursache der Deaktivierung.',
           N'Änderungshistorie, Deploymentzustand und beabsichtigte Nutzung prüfen; keine automatische Aktivierung ableiten.'
    FROM [#VectorIndexAnalysis_VectorIndexes]
    WHERE [IsDisabled]=1;

    INSERT [#VectorIndexAnalysis_Findings]
    ([DatabaseName],[SchemaName],[ObjectName],[IndexName],[Severity],[Confidence],[FindingCode],
     [MetricName],[MetricValue],[ThresholdValue],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],[SchemaName],[ObjectName],[IndexName],'WARN','HIGH','VECTOR_BACKGROUND_TASK_FAILED',
           'LAST_BACKGROUND_TASK_SUCCEEDED',0,1,N'Die letzte sichtbare Hintergrundwartung meldet einen Fehler.',
           N'Es handelt sich um den letzten sichtbaren Taskstatus. Wiederholung, aktueller Backlog und Suchwirkung werden nicht historisch gemessen.',
           N'Fehlermeldung, nachfolgende Taskläufe, Stalenessverlauf sowie messbare Recall- oder Performanceänderung gemeinsam prüfen.'
    FROM [#VectorIndexAnalysis_Maintenance]
    WHERE [StatusCode]='AVAILABLE' AND [LastBackgroundTaskSucceeded]=0;

    INSERT [#VectorIndexAnalysis_Findings]
    ([DatabaseName],[SchemaName],[ObjectName],[IndexName],[Severity],[Confidence],[FindingCode],
     [MetricName],[MetricValue],[ThresholdValue],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],[SchemaName],[ObjectName],[IndexName],'WARN','MEDIUM','VECTOR_STALENESS_REVIEW',
           'APPROXIMATE_STALENESS_PERCENT',[ApproximateStalenessPercent],@StalenessReviewPercent,
           N'Die aktuelle ungefähre Staleness erreicht den konfigurierten Review-Grenzwert.',
           N'Für Staleness existiert kein universeller Fehlergrenzwert. Batchloads können vorübergehend deutlich erhöhte Werte erzeugen; ein Einzelwert ist kein Rebuildnachweis.',
           N'Wert über Zeit, DML-Rate, Abschluss der Hintergrundwartung sowie messbare Recall- und Performanceentwicklung korrelieren.'
    FROM [#VectorIndexAnalysis_Maintenance]
    WHERE [StatusCode]='AVAILABLE'
      AND @StalenessReviewPercent IS NOT NULL
      AND [ApproximateStalenessPercent]>=@StalenessReviewPercent;

    INSERT [#VectorIndexAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
    SELECT [DatabaseName],[SourceName],[StatusCode],[ErrorNumber],COALESCE([ErrorMessage],N'Quelle unvollständig oder nicht verfügbar.')
    FROM [#VectorIndexAnalysis_SourceStatus]
    WHERE [IsPartial]=1;

    INSERT [#VectorIndexAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
    SELECT [RequestedName],N'databaseCandidates',[StatusCode],NULL,COALESCE([ErrorMessage],N'Datenbank nicht verarbeitet.')
    FROM [#VectorIndexAnalysis_CandidateWarnings];

    IF @StatusCode='AVAILABLE'
    BEGIN
        IF @ProductMajorVersion IS NULL OR @ProductMajorVersion<17
            SET @StatusCode='UNAVAILABLE_VERSION';
        ELSE IF EXISTS(SELECT 1 FROM [#VectorIndexAnalysis_Warnings])
        BEGIN
            SET @StatusCode='AVAILABLE_LIMITED';
            SET @IsPartial=1;
        END
        ELSE IF NOT EXISTS
        (
            SELECT 1 FROM [#VectorIndexAnalysis_SourceStatus]
            WHERE [SourceName]=N'vectorCatalog' AND [StatusCode] IN('AVAILABLE','AVAILABLE_EMPTY','NOT_ENABLED')
        )
        BEGIN
            SELECT TOP(1) @StatusCode=[StatusCode],@ErrorNumber=[ErrorNumber],@ErrorMessage=[ErrorMessage]
            FROM [#VectorIndexAnalysis_SourceStatus]
            WHERE [SourceName]=N'vectorCatalog'
            ORDER BY [SourceOrdinal];
            SET @StatusCode=COALESCE(@StatusCode,'UNAVAILABLE_FEATURE');
        END
        ELSE IF EXISTS(SELECT 1 FROM [#VectorIndexAnalysis_Findings] WHERE [Severity]='WARN')
            SET @StatusCode='AVAILABLE_WITH_FINDING';
        ELSE IF NOT EXISTS(SELECT 1 FROM [#VectorIndexAnalysis_VectorIndexes])
            SET @StatusCode='NOT_APPLICABLE';
    END;

    IF @StatusCode NOT IN('AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE','UNAVAILABLE_VERSION','UNAVAILABLE_FEATURE')
        SET @IsPartial=1;

    IF @ErrorMessage IS NULL
        SELECT TOP(1) @ErrorNumber=[ErrorNumber],@ErrorMessage=[Message]
        FROM [#VectorIndexAnalysis_Warnings]
        ORDER BY [WarningOrdinal];

    DECLARE @VectorRows bigint=(SELECT COUNT_BIG(*) FROM [#VectorIndexAnalysis_VectorIndexes]);
    DECLARE @MaintenanceRows bigint=(SELECT COUNT_BIG(*) FROM [#VectorIndexAnalysis_Maintenance]);
    DECLARE @FindingRows bigint=(SELECT COUNT_BIG(*) FROM [#VectorIndexAnalysis_Findings]);

    INSERT [#VectorIndexAnalysis_ModuleStatus]
    VALUES
    (
          N'USP_VectorIndexAnalysis',@CapturedAtUtc,@StatusCode,@IsPartial,@ProductMajorVersion
        , @CrossDatabaseRequested,(SELECT COUNT(*) FROM [#VectorIndexAnalysis_DatabaseCandidates])
        , CASE WHEN @VectorRows>@Limit THEN @Limit ELSE @VectorRows END
        , CASE WHEN @MaintenanceRows>@Limit THEN @Limit ELSE @MaintenanceRows END
        , CASE WHEN @FindingRows>@Limit THEN @Limit ELSE @FindingRows END
        , CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @VectorRows>@Limit THEN 1 ELSE 0 END)
        , CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @MaintenanceRows>@Limit THEN 1 ELSE 0 END)
        , CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @FindingRows>@Limit THEN 1 ELSE 0 END)
        , @ErrorNumber,@ErrorMessage
    );

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=
        (
            SELECT N'VectorIndexAnalysis' [resultName],1 [schemaVersion],@CapturedAtUtc [generatedAtUtc],
                   @StatusCode [statusCode],@IsPartial [isPartial],@ProductMajorVersion [productMajorVersion],
                   @StalenessReviewPercent [stalenessReviewPercent],
                   CASE WHEN @VectorRows>@Limit THEN @Limit ELSE @VectorRows END [vectorIndexRowCount],
                   CASE WHEN @MaintenanceRows>@Limit THEN @Limit ELSE @MaintenanceRows END [maintenanceRowCount],
                   CASE WHEN @FindingRows>@Limit THEN @Limit ELSE @FindingRows END [findingRowCount],
                   CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @VectorRows>@Limit THEN 1 ELSE 0 END) [hasMoreVectorIndexRows],
                   CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @MaintenanceRows>@Limit THEN 1 ELSE 0 END) [hasMoreMaintenanceRows],
                   CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @FindingRows>@Limit THEN 1 ELSE 0 END) [hasMoreFindingRows],
                   @ErrorNumber [errorNumber],@ErrorMessage [errorMessage]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
        );
        DECLARE @VectorIndexesJson nvarchar(max)=
        (
            SELECT TOP(@Limit) * FROM [#VectorIndexAnalysis_VectorIndexes]
            ORDER BY [DatabaseName],[SchemaName],[ObjectName],[IndexName]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @MaintenanceJson nvarchar(max)=
        (
            SELECT TOP(@Limit) * FROM [#VectorIndexAnalysis_Maintenance]
            ORDER BY [DatabaseName],[SchemaName],[ObjectName],[IndexName]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @FindingsJson nvarchar(max)=
        (
            SELECT TOP(@Limit) * FROM [#VectorIndexAnalysis_Findings]
            ORDER BY CASE [Severity] WHEN 'WARN' THEN 1 ELSE 2 END,[FindingOrdinal]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @SourceStatusJson nvarchar(max)=
        (
            SELECT * FROM [#VectorIndexAnalysis_SourceStatus]
            ORDER BY [SourceOrdinal]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @WarningsJson nvarchar(max)=
        (
            SELECT * FROM [#VectorIndexAnalysis_Warnings]
            ORDER BY [WarningOrdinal]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        SET @Json=CONCAT
        (
              N'{"meta":',COALESCE(@MetaJson,N'{}')
            , N',"vectorIndexes":',COALESCE(@VectorIndexesJson,N'[]')
            , N',"maintenance":',COALESCE(@MaintenanceJson,N'[]')
            , N',"findings":',COALESCE(@FindingsJson,N'[]')
            , N',"sourceStatus":',COALESCE(@SourceStatusJson,N'[]')
            , N',"warnings":',COALESCE(@WarningsJson,N'[]')
            , N'}'
        );
    END;

    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @LockTimeoutSql;

    IF @ConsoleResultRequested=1
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#VectorIndexAnalysis_Findings'
            , @ResultLabel=N'Vector-Index-Wartung'
            , @EmptyMessage=N'Keine Vector-Index-Wartungsauffälligkeit im sichtbaren Scope';
    ELSE IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#VectorIndexAnalysis_ModuleStatus];
        SELECT TOP(@Limit) * FROM [#VectorIndexAnalysis_VectorIndexes]
        ORDER BY [DatabaseName],[SchemaName],[ObjectName],[IndexName];
        SELECT TOP(@Limit) * FROM [#VectorIndexAnalysis_Maintenance]
        ORDER BY [DatabaseName],[SchemaName],[ObjectName],[IndexName];
        SELECT TOP(@Limit) * FROM [#VectorIndexAnalysis_Findings]
        ORDER BY CASE [Severity] WHEN 'WARN' THEN 1 ELSE 2 END,[FindingOrdinal];
        SELECT * FROM [#VectorIndexAnalysis_SourceStatus] ORDER BY [SourceOrdinal];
        SELECT * FROM [#VectorIndexAnalysis_Warnings] ORDER BY [WarningOrdinal];
    END
    ELSE IF @OutputMode='TABLE'
    BEGIN
        DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
        DECLARE [ResultCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [ResultName],[TargetTable]
            FROM [#VectorIndexAnalysis_ResultTableMap]
            ORDER BY [ResultName];
        OPEN [ResultCursor];
        FETCH NEXT FROM [ResultCursor] INTO @ResultName,@TargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @SourceTable=CASE @ResultName
                WHEN N'moduleStatus' THEN N'#VectorIndexAnalysis_ModuleStatus'
                WHEN N'vectorIndexes' THEN N'#VectorIndexAnalysis_VectorIndexes'
                WHEN N'maintenance' THEN N'#VectorIndexAnalysis_Maintenance'
                WHEN N'findings' THEN N'#VectorIndexAnalysis_Findings'
                WHEN N'sourceStatus' THEN N'#VectorIndexAnalysis_SourceStatus'
                WHEN N'warnings' THEN N'#VectorIndexAnalysis_Warnings' END;
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=@SourceTable
                , @TargetTable=@TargetTable
                , @ThrowOnError=1;
            FETCH NEXT FROM [ResultCursor] INTO @ResultName,@TargetTable;
        END;
        CLOSE [ResultCursor];
        DEALLOCATE [ResultCursor];
    END;

    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE')
    BEGIN
        DECLARE @PrintMessage nvarchar(2048)=LEFT(CONCAT(N'USP_VectorIndexAnalysis: ',@StatusCode,N'. ',COALESCE(@ErrorMessage,N'Siehe sourceStatus und warnings.')),2048);
        RAISERROR(N'%s',10,1,@PrintMessage) WITH NOWAIT;
    END;

    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,
           @ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
END;
GO

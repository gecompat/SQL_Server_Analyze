USE [DeineDatenbank];
GO

/*
Objekt       : monitor.USP_ExternalDataAnalysis
Version      : 1.0.0
Stand        : 2026-10-14
Zweck        : Die Procedure analysiert sichtbare lokale externe Katalogobjekte und Referenzen.
Eigenlast    : Lokale Katalogabfragen und aggregierte sichtbare Spalten je Datenbank.
Grenzen      : Keine Remote-, Location-, Credential-, Modellnamen- oder Payloadlesung.
               Fehlende sichtbare Referenzen beweisen keinen defekten Fremdschlüssel.
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ExternalDataAnalysis]
      @DatabaseNames nvarchar(max)=NULL
    , @DatabaseNamePattern nvarchar(4000)=NULL
    , @SystemdatenbankenEinbeziehen bit=0
    , @MaxZeilen int=2000
    , @ResultSetArt varchar(16)='CONSOLE'
    , @ResultTablesJson nvarchar(max)=NULL
    , @JsonErzeugen bit=0
    , @Json nvarchar(max)=NULL OUTPUT
    , @PrintMeldungen bit=1
    , @Hilfe bit=0
    , @StatusCodeOut varchar(40)=NULL OUTPUT
    , @IsPartialOut bit=NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;
    DECLARE @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
        @Status varchar(40)='AVAILABLE',@Partial bit=0,@Error int=NULL,@Message nvarchar(4000)=NULL,
        @CollectionTimeUtc datetime2(3)=SYSUTCDATETIME(),@Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),
        @PreviousLockTimeout int=@@LOCK_TIMEOUT,@PreviousXactAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
        @RestoreLock nvarchar(100),@CrossDatabaseRequested bit=0,
        @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ExternalDataAnalysis';
        PRINT N'Die Procedure erfasst ausschließlich caller-sichtbare lokale Katalogmetadaten ausgewählter Datenbanken; sie fragt keine Remotequelle oder externen Inhalte ab.';
        PRINT N'RAW liefert acht native Resultsets, TABLE die ausgewählten benannten Mengen und CONSOLE die Datenbankübersicht. NONE unterdrückt fachliche Resultsets; JSON wird unabhängig über @JsonErzeugen angefordert.';
        PRINT N'Quellstatus und Partialität sind gemeinsam zu lesen. Fehlende sichtbare Referenzen beweisen keinen defekten Fremdschlüssel; nicht gelesene oder ausgefallene Quellen erhalten keine erfundenen Werte.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. NULL, Leerstring oder ausschließlich äußere U+0020-Leerzeichen bedeuten keine exakte Einschränkung. Sonst eine bracket-aware Pipe-Liste: | trennt außerhalb von [...], ]] maskiert innen eine schließende Klammer; äußere U+0020-Leerzeichen je Element werden entfernt. Jedes rohe Segment darf höchstens 4000 UTF-16-Codeeinheiten umfassen. TVF_ParseSqlNameList prüft PARSENAME-Teil 1 auf einen nicht-NULL Namen, Teil 2 auf NULL und LEN(Teil 1) auf höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Dies ist keine vollständige SQL-Bezeichnergrammatik, Existenz- oder Berechtigungsprüfung. Leere/fehlerhaft geklammerte Elemente, Parserablehnung und case-sensitive doppelte gültige Namen ergeben INVALID_PARAMETER. Eine wirksame Liste und jeder nicht-NULL @DatabaseNamePattern-Wert sind zusammen ungültig. Nur sichtbare, ONLINE befindliche, zugreifbare Datenbanken ohne Snapshotmarkierung werden Kandidaten; Systemdatenbanken bleiben ohne Opt-in ausgeschlossen. Nicht verfügbare explizit angeforderte Namen können Auswahlwarnungen liefern. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. NULL oder ausgelassen bedeutet kein Pattern. Ein nicht-NULL Wert wird außen mit LTRIM/RTRIM getrimmt. Zulässige Eingabe ist ein LIKE-Pattern (case-sensitive SQL_Latin1_General_CP1_CS_AS; SQL-LIKE-Metazeichen %, _, [...] gelten) oder ein optionales Präfix LIKE:, REGEX: oder REGEXI:, dessen Erkennung nicht auf Groß-/Kleinschreibung achtet. Nach Entfernen des Präfixes wird der Rest nicht erneut getrimmt. Ein leerer oder nur aus U+0020-Leerzeichen bestehender Eingang oder leeres Präfixergebnis ist ungültig und führt zu INVALID_PARAMETER. Eine wirksame @DatabaseNames-Liste und jeder nicht-NULL Patternwert sind zusammen ungültig. REGEX verwendet Flag c, REGEXI Flag i; Regex-Syntax wird nicht vorab validiert. Regexausführung benötigt SQL Server 2025 (Major 17) und Compatibility Level 170 der Installationsdatenbank; andernfalls UNAVAILABLE_FEATURE. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. Numerische 0 schließt Systemdatenbanken mit IDs bis 4 (master, tempdb, model, msdb) aus; jeder numerische Wert ungleich 0 wird als 1 behandelt und lässt sie in die Auswahl ein. NULL ist ungültig und führt zu INVALID_PARAMETER; ausgelassen gilt 0. Ausgeschlossene explizit angeforderte Systemdatenbanken können als SYSTEM_DATABASE_EXCLUDED-Warnung gemeldet werden. Beeinflusst nur Kandidatenauswahl. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MaxZeilen int; Default: 2000. NULL oder 0 hebt das Ausgabelimit praktisch auf. Positive Werte begrenzen jeweils getrennt die ausgegebenen Zeilen in dataSources, fileFormats, externalTables, modelSummary, sourceStatus und warnings; die Sortierschlüssel sind Datenbankname plus jeweilige Kennung/Quelle beziehungsweise Warnung. Negative Werte führen zu INVALID_PARAMETER. Die Grenze steuert weder Datenbankscope, Sammelarbeit noch Counts: DataSourceCount, FileFormatCount, ExternalTableCount, ExternalModelCount und RowCount beruhen auf der Sammlung vor Ausgabelimits. moduleStatus und databaseStatus werden nicht durch dieses Detailgruppenlimit abgeschnitten. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. NULL wird wie leer behandelt, danach werden äußere Leerzeichen entfernt und in Großbuchstaben normalisiert; ausgelassen gilt CONSOLE. Zulässige endliche Werte: RAW gibt die acht nativen Resultsets aus (moduleStatus, databaseStatus, dataSources, fileFormats, externalTables, modelSummary, sourceStatus, warnings); TABLE schreibt die ausgewählten Resultsets in Caller-Temp-Tabellen; CONSOLE gibt eine menschenlesbare Ansicht von databaseStatus aus; NONE unterdrückt fachliche Resultsets. Jeder andere Wert einschließlich JSON führt zu INVALID_PARAMETER. JSON wird unabhängig davon mit @JsonErzeugen angefordert und kann zusätzlich zu jeder zulässigen Ausgabeart erzeugt werden. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. NULL, N'''' oder nur Leerzeichen bedeutet keine Zuordnung; ausgelassen gilt NULL. Nur TABLE darf eine nicht-leere JSON-Zuordnung erhalten; bei anderer @ResultSetArt wirft die Procedure Fehler 51011. Das JSON-Objekt muss mindestens ein Schlüssel-Wert-Paar enthalten; jeder Schlüssel muss exakt (case-sensitive, binärer Vergleich) einer der acht Namen moduleStatus, databaseStatus, dataSources, fileFormats, externalTables, modelSummary, sourceStatus oder warnings entsprechen. Jeder Wert muss eine nicht-leere Zeichenfolge mit dem Namen einer vorhandenen lokalen #Temp-Tabelle sein. Resultset-Schlüsseldubletten werden binär erkannt; doppelte Zieltabellennamen sind unter Latin1_General_100_CI_AS unzulässig. Zielname muss mit # beginnen, darf nicht ## sein, höchstens 116 Zeichen lang sein und nicht mit dem reservierten Präfix #Monitor beginnen (case-insensitive). Jede Zieltemp-Tabelle muss beim Aufruf leer sein und genau eine Seed-Spalte besitzen; die Vorprüfung erkennt dies, indem sie temporär eine Marker-Spalte hinzufügt und insgesamt zwei Spalten erwartet. Der Seedname/-typ wird dabei nicht als Quellschema vorgegeben: InternalWriteResultTable passt die leere Ein-Spalten-Tabelle an das native Schema des jeweiligen Resultsets an und fügt dessen Zeilen ein. Vorprüfung läuft für alle Ziele vor dem Schreiben. Schreibvorgänge erfolgen je Mapping nacheinander ohne behauptete Gesamttransaktion/atomare Mehrzieltabelle; ein späterer Fehler kann bereits geschriebene frühere Ziele belassen. Ungültige Zuordnung oder Ziele werden vor dem Schreiben mit 51011 abgelehnt. Alle acht Schlüssel mit jeweiligem Inhalt: moduleStatus liefert Modulstatus und Partialität; databaseStatus Datenbankstatus und ungekürzte Counts; dataSources sichtbare lokale Datenquellen; fileFormats sichtbare Dateiformate; externalTables externe Tabellen mit Referenzsichtbarkeit und Spaltenanzahl; modelSummary Modellanzahl und Modellquellenstatus; sourceStatus Quellenstatus mit nativen Fehlerfeldern; warnings Auswahl-/Quellenwarnungen. Jede nichtleere Teilmenge der acht Schlüssel genügt. Im TABLE-Modus sind NULL, Leerstring und ein leeres Objekt ungültig. Vorprüfungsablehnungen werfen 51011; Writerablehnungen werfen 51010. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit; Default: 0. Numerische 0 deaktiviert JSON; jeder numerische Wert ungleich 0 aktiviert es. NULL ist ungültig und führt zu INVALID_PARAMETER; ausgelassen gilt 0. Die JSON-Ausgabe ist zusätzlich zu RAW/TABLE/CONSOLE/NONE und enthält meta sowie stets acht Arrays: moduleStatus, databaseStatus, dataSources, fileFormats, externalTables, modelSummary, sourceStatus und warnings. Die sechs Detailgruppen dataSources, fileFormats, externalTables, modelSummary, sourceStatus und warnings sind bereits je @MaxZeilen begrenzt; JSON enthält NULL-Spalten ausdrücklich. Wird JSON nicht angefordert, wird @Json zu Beginn auf NULL gesetzt. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT nvarchar(max), ohne Eingabeparameterwirkung. Beim regulären Eintritt wird die Ausgabebindung vor dem Hilfezweig auf NULL gesetzt; bei @JsonErzeugen=1 wird sie am regulären JSON-Zweig mit dem JSON-Dokument belegt, sonst bleibt sie NULL. Zum Empfang muss eine Caller-Variable vom Typ nvarchar(max) mit OUTPUT gebunden werden; ohne OUTPUT-Bindung wird der Wert nicht zurückgegeben. Bei ungefangenen Fehlern ist keine reguläre Ausgabegarantie beschrieben. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@PrintMeldungen bit; Default: 1. Numerische 0 unterdrückt die Statusmeldung per RAISERROR severity 10; jeder numerische Wert ungleich 0 aktiviert sie. NULL ist ungültig und führt zu INVALID_PARAMETER; ausgelassen gilt 1. Eine Meldung wird nur erzeugt, wenn der abschließende Status nicht AVAILABLE ist, und enthält Status sowie Kurztext, nicht ein zusätzliches Resultset. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit; Default: 0. Numerische 0 führt die Analyse aus; jeder numerische Wert ungleich 0 aktiviert die Hilfe. NULL aktiviert die Hilfe nicht und wird in der anschließenden normalen Parameterprüfung als ungültig behandelt; ausgelassen gilt 0. Der Hilfezweig druckt die Hilfetexte, setzt @StatusCodeOut auf AVAILABLE und @IsPartialOut auf 0 und kehrt vor Katalogaufnahme zurück. @Json bleibt wegen der Initialisierung NULL. Der Zweig validiert keine übrigen Parameter. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT varchar(40). Regulärer Rückgabestatus nach Auswertung der Datenbank-/Quellenaufnahme; bei @Hilfe=1 ausdrücklich AVAILABLE. Sämtliche Modulstatuswerte und ihre Bedeutung/Priorität: AVAILABLE = regulärer Abschluss ohne festgestellte Partialität; AVAILABLE_LIMITED = mindestens ein Datenbank-/Quellenbefund ist partiell und mindestens eine Quelle ist AVAILABLE; sonst wird der erste partielle Datenbankstatus nach Datenbankname übernommen. INVALID_PARAMETER = ungültige Ausgabeart, negatives @MaxZeilen oder NULL in den geprüften Bitparametern; dieser Parameterfehlerstatus hat vor der Kandidatenermittlung Vorrang. INTERNAL_ERROR = der Kandidatenhelfer kann die erwartete Kandidatentabelle nicht verwenden; dieser Status wird unverändert übernommen. DENIED_PERMISSION = Kandidatenvorbereitung oder Quelle scheitert mit einer der explizit klassifizierten Berechtigungsfehlernummern 229, 262, 297, 300, 371. SOURCE_UNAVAILABLE = Fehler 207 oder 208 beim Kandidaten-/Quellenzugriff. ERROR_HANDLED = sonstiger abgefangener Fehler der Kandidatenvorbereitung/Quelle. DATABASE_UNAVAILABLE = explizit angeforderte Datenbank wurde nicht als Kandidat verarbeitet. UNAVAILABLE_FEATURE = Regex kann wegen fehlender SQL Server 2025-/Compatibility-Level-170-Voraussetzung nicht ausgeführt werden. Auf Quellenebene zusätzlich: UNAVAILABLE_VERSION = external_models wird bei ProductMajorVersion <17 nicht gelesen und allein daraus folgt keine Partialität; AVAILABLE bedeutet erfolgreiche Quellenabfrage, auch bei null Zeilen; DENIED_PERMISSION, SOURCE_UNAVAILABLE und ERROR_HANDLED kennzeichnen fehlgeschlagene Abfragen. Partielle Datenbank ohne erfolgreiche Quelle übernimmt den ersten nicht erfolgreichen Quellenstatus nach fester Quellenrangfolge; bei mindestens einer erfolgreichen Quelle wird sie AVAILABLE_LIMITED. Der erste native Fehlerwert für das Top-Level wird nach Datenbankname und Quellenrangfolge gewählt. Ausgabe-/Mapping-Preflight kann Fehler werfen (51011), bevor reguläre Outputzuweisung erfolgt; der äußere Catch wirft wieder und setzt keine Status-Outputs. Für den Empfang Caller-Variable varchar(40) mit OUTPUT binden; ohne OUTPUT wird der Wert nicht empfangen. SYSTEM_DATABASE_EXCLUDED ist hier ein Auswahlwarnungscode, kein zusätzlicher Modulstatus: die zugehörige nicht verarbeitete angeforderte Datenbank wird als DATABASE_UNAVAILABLE in databaseStatus aufgenommen und kann zur Modulaggregation DATABASE_UNAVAILABLE oder AVAILABLE_LIMITED beitragen. Die feste Klasse STANDARD_CURRENT verlangt im Katalog kein Gruppengate; ihr Freigabepfad ergänzt keine Gruppen-/High-Impact-Statuswerte. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine bit-Variable. Hilfe liefert ausdrücklich 0. Die lokale Prüfung von Ausgabeart, Zeilenlimit und geprüften Bit-NULLs setzt INVALID_PARAMETER und 1. Eine partielle Datenbank-/Quellenaufnahme setzt ebenfalls 1. Zurückgegebene Statuswerte des Kandidatenhelfers, darunter INVALID_PARAMETER, INTERNAL_ERROR und UNAVAILABLE_FEATURE, setzen die anfangs mit 0 belegte Partialvariable dagegen nicht automatisch auf 1. Ein solcher Status kann daher mit 0 enden; 0 allein ist kein Nachweis einer erfolgreichen vollständigen Aufnahme. Ohne OUTPUT-Bindung wird der Wert nicht empfangen. Bei geworfenen Fehlern einschließlich TABLE-Vorprüfungsfehlern ist keine reguläre abschließende OUTPUT-Zuweisung garantiert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'EXEC [monitor].[USP_ExternalDataAnalysis] @MaxZeilen=200, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_ExternalDataAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Json AS [DiagnosticJson];';
        PRINT N'CREATE TABLE [#ExternalDataAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ExternalDataAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"databaseStatus":"#ExternalDataAnalysis_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM [#ExternalDataAnalysis_HelpExample]; DROP TABLE IF EXISTS [#ExternalDataAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#ExternalDataAnalysis_HelpExample]; THROW; END CATCH;';
        PRINT N'EXEC [monitor].[USP_ExternalDataAnalysis] @Hilfe=1;';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN;
    END;
    CREATE TABLE [#ExternalDataAnalysis_moduleStatus](
        [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [ErrorNumber] int NULL,
        [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [CollectionTimeUtc] datetime2(3) NOT NULL
    );
    CREATE TABLE [#ExternalDataAnalysis_databaseStatus](
        [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [DataSourceCount] bigint NULL,
        [FileFormatCount] bigint NULL,
        [ExternalTableCount] bigint NULL,
        [ExternalModelCount] bigint NULL,
        [ErrorNumber] int NULL,
        [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ExternalDataAnalysis_dataSources](
        [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [DataSourceId] int NOT NULL,
        [DataSourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [TypeCode] tinyint NULL,
        [TypeDescription] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ExternalDataAnalysis_fileFormats](
        [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [FileFormatId] int NOT NULL,
        [FileFormatName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [FormatTypeCode] tinyint NULL
    );
    CREATE TABLE [#ExternalDataAnalysis_externalTables](
        [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ObjectId] int NOT NULL,
        [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [TableName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [DataSourceId] int NULL,
        [FileFormatId] int NULL,
        [DataSourceReferenceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [FileFormatReferenceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [VisibleColumnCount] bigint NULL
    );
    CREATE TABLE [#ExternalDataAnalysis_modelSummary](
        [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [VisibleModelCount] bigint NULL,
        [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExternalDataAnalysis_sourceStatus](
        [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ErrorNumber] int NULL,
        [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [CollectionTimeUtc] datetime2(3) NOT NULL
    );
    CREATE TABLE [#ExternalDataAnalysis_warnings](
        [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExternalDataAnalysis_Databases]
    ([DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
     [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsReadOnly] bit NULL,[CompatibilityLevel] tinyint NULL,
     [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsSystemDatabase] bit NULL,[RequestedOrdinal] int NULL);
    CREATE TABLE [#ExternalDataAnalysis_CandidateWarnings]
    ([RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#ExternalDataAnalysis_Map]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#ExternalDataAnalysis_TableRows]([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectId] int NOT NULL,[SchemaId] int NOT NULL,[TableName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[DataSourceId] int NULL,[FileFormatId] int NULL);
    CREATE TABLE [#ExternalDataAnalysis_SchemaRows]([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaId] int NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#ExternalDataAnalysis_ColumnRows]([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectId] int NOT NULL,[VisibleColumnCount] bigint NOT NULL);
    CREATE TABLE [#ExternalDataAnalysis_SourceResults]([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceRank] tinyint NOT NULL,[SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RowCount] bigint NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    BEGIN TRY
        SET XACT_ABORT OFF;
        IF @Mode NOT IN('RAW','TABLE','CONSOLE','NONE') OR @MaxZeilen<0 OR @SystemdatenbankenEinbeziehen IS NULL OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL OR @Hilfe IS NULL
            SELECT @Status='INVALID_PARAMETER',@Partial=1,@Message=N'Ungültiger Ausgabe-, Mengen- oder Bitparameter.';
        IF @Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL
            THROW 51011,N'@ResultTablesJson ist ausschließlich mit TABLE zulässig.',1;
        IF @Status='AVAILABLE' AND @Mode='TABLE'
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|databaseStatus|dataSources|fileFormats|externalTables|modelSummary|sourceStatus|warnings',
                @MappingTable=N'#ExternalDataAnalysis_Map',@StatusCode=@Status OUTPUT,@ErrorMessage=@Message OUTPUT,@ThrowOnError=1;
        IF @Status='AVAILABLE'
        BEGIN TRY
            EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,@DatabaseNamePattern=@DatabaseNamePattern,
                @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@AnalysisClass='STANDARD_CURRENT',@StatusCode=@Status OUTPUT,@ErrorMessage=@Message OUTPUT,
                @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,@CandidateTable=N'#ExternalDataAnalysis_Databases',@WarningTable=N'#ExternalDataAnalysis_CandidateWarnings';
        END TRY
        BEGIN CATCH
            DELETE FROM [#ExternalDataAnalysis_Databases];
            SELECT @Error=ERROR_NUMBER(),@Message=ERROR_MESSAGE(),@Partial=1,
                @Status=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER() IN(207,208) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END;
        END CATCH;
        SET LOCK_TIMEOUT 0;
        IF @Status='AVAILABLE'
        BEGIN
            DECLARE @Db sysname,@Rank tinyint,@Source sysname,@Sql nvarchar(max),@SourceStatus varchar(40),@SourceError int,@SourceMessage nvarchar(4000),@Rows bigint,
                @DbPartial bit,@DbStatus varchar(40),@DbError int,@DbMessage nvarchar(4000),@SourceCount bigint,@FormatCount bigint,@TableCount bigint,@ModelCount bigint;
            DECLARE [ExternalDataDatabases] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName] FROM [#ExternalDataAnalysis_Databases] ORDER BY [DatabaseName];
            OPEN [ExternalDataDatabases];FETCH NEXT FROM [ExternalDataDatabases] INTO @Db;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @Rank=1;
                WHILE @Rank<=6
                BEGIN
                    SELECT @Source=CASE @Rank WHEN 1 THEN N'sys.external_data_sources' WHEN 2 THEN N'sys.external_file_formats' WHEN 3 THEN N'sys.external_tables' WHEN 4 THEN N'sys.schemas' WHEN 5 THEN N'sys.columns' ELSE N'sys.external_models' END,
                        @SourceStatus='AVAILABLE',@SourceError=NULL,@SourceMessage=NULL,@Rows=NULL,@Sql=NULL;
                    IF @Rank=6 AND @Major<17 SET @SourceStatus='UNAVAILABLE_VERSION';
                    ELSE IF @Rank=6 AND @Major IS NULL SET @SourceStatus='SOURCE_UNAVAILABLE';
                    ELSE
                    BEGIN TRY
                        SET @Sql=CASE @Rank
                            WHEN 1 THEN N'INSERT [#ExternalDataAnalysis_dataSources] SELECT @pDb,[data_source_id],[name],[type],[type_desc] FROM '+QUOTENAME(@Db)+N'.[sys].[external_data_sources] WITH(NOLOCK); SET @pRows=@@ROWCOUNT;'
                            WHEN 2 THEN N'INSERT [#ExternalDataAnalysis_fileFormats] SELECT @pDb,[file_format_id],[name],[format_type] FROM '+QUOTENAME(@Db)+N'.[sys].[external_file_formats] WITH(NOLOCK); SET @pRows=@@ROWCOUNT;'
                            WHEN 3 THEN N'INSERT [#ExternalDataAnalysis_TableRows] SELECT @pDb,[object_id],[schema_id],[name],[data_source_id],[file_format_id] FROM '+QUOTENAME(@Db)+N'.[sys].[external_tables] WITH(NOLOCK); SET @pRows=@@ROWCOUNT;'
                            WHEN 4 THEN N'INSERT [#ExternalDataAnalysis_SchemaRows] SELECT @pDb,[schema_id],[name] FROM '+QUOTENAME(@Db)+N'.[sys].[schemas] WITH(NOLOCK) WHERE [schema_id] IN(SELECT [SchemaId] FROM [#ExternalDataAnalysis_TableRows] WHERE [DatabaseName]=@pDb); SET @pRows=@@ROWCOUNT;'
                            WHEN 5 THEN N'INSERT [#ExternalDataAnalysis_ColumnRows] SELECT @pDb,[object_id],COUNT_BIG(*) FROM '+QUOTENAME(@Db)+N'.[sys].[columns] WITH(NOLOCK) WHERE [object_id] IN(SELECT [ObjectId] FROM [#ExternalDataAnalysis_TableRows] WHERE [DatabaseName]=@pDb) GROUP BY [object_id]; SET @pRows=@@ROWCOUNT;'
                            ELSE N'SELECT @pRows=COUNT_BIG(*) FROM '+QUOTENAME(@Db)+N'.[sys].[external_models] WITH(NOLOCK);' END;
                        EXEC [sys].[sp_executesql] @Sql,N'@pDb sysname,@pRows bigint OUTPUT',@pDb=@Db,@pRows=@Rows OUTPUT;
                    END TRY
                    BEGIN CATCH
                        SELECT @SourceError=ERROR_NUMBER(),@SourceMessage=ERROR_MESSAGE(),@Rows=NULL,
                            @SourceStatus=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER() IN(207,208) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END;
                        IF @Rank=1 DELETE FROM [#ExternalDataAnalysis_dataSources] WHERE [DatabaseName]=@Db;
                        IF @Rank=2 DELETE FROM [#ExternalDataAnalysis_fileFormats] WHERE [DatabaseName]=@Db;
                        IF @Rank=3 DELETE FROM [#ExternalDataAnalysis_TableRows] WHERE [DatabaseName]=@Db;
                        IF @Rank=4 DELETE FROM [#ExternalDataAnalysis_SchemaRows] WHERE [DatabaseName]=@Db;
                        IF @Rank=5 DELETE FROM [#ExternalDataAnalysis_ColumnRows] WHERE [DatabaseName]=@Db;
                    END CATCH;
                    INSERT [#ExternalDataAnalysis_sourceStatus] VALUES(@Db,@Source,@SourceStatus,@SourceError,@SourceMessage,SYSUTCDATETIME());
                    INSERT [#ExternalDataAnalysis_SourceResults] VALUES(@Db,@Rank,@SourceStatus,@Rows,@SourceError,@SourceMessage);
                    IF @SourceStatus NOT IN('AVAILABLE','UNAVAILABLE_VERSION')
                        INSERT [#ExternalDataAnalysis_warnings] VALUES(@Db,'SOURCE_PARTIAL',LEFT(CONCAT(@Source,N': ',@SourceStatus,N'. ',COALESCE(@SourceMessage,N'Keine native Fehlernummer; Quelle nicht verfügbar.')),2000));
                    SET @Rank+=1;
                END;
                SELECT @SourceCount=MAX(CASE WHEN [SourceRank]=1 THEN [RowCount] END),@FormatCount=MAX(CASE WHEN [SourceRank]=2 THEN [RowCount] END),
                    @TableCount=MAX(CASE WHEN [SourceRank]=3 THEN [RowCount] END),@ModelCount=MAX(CASE WHEN [SourceRank]=6 THEN [RowCount] END),
                    @DbPartial=CONVERT(bit,MAX(CASE WHEN [SourceStatus] IN('AVAILABLE','UNAVAILABLE_VERSION') THEN 0 ELSE 1 END))
                FROM [#ExternalDataAnalysis_SourceResults] WHERE [DatabaseName]=@Db;
                SELECT @DbStatus='AVAILABLE',@DbError=NULL,@DbMessage=NULL;
                IF @DbPartial=1
                BEGIN
                    IF EXISTS(SELECT 1 FROM [#ExternalDataAnalysis_SourceResults] WHERE [DatabaseName]=@Db AND [SourceStatus]='AVAILABLE') SET @DbStatus='AVAILABLE_LIMITED';
                    ELSE SELECT TOP(1) @DbStatus=[SourceStatus] FROM [#ExternalDataAnalysis_SourceResults] WHERE [DatabaseName]=@Db AND [SourceStatus] NOT IN('AVAILABLE','UNAVAILABLE_VERSION') ORDER BY [SourceRank];
                END;
                SELECT TOP(1) @DbError=[ErrorNumber],@DbMessage=[ErrorMessage] FROM [#ExternalDataAnalysis_SourceResults] WHERE [DatabaseName]=@Db AND [ErrorNumber] IS NOT NULL ORDER BY [SourceRank];
                INSERT [#ExternalDataAnalysis_databaseStatus] VALUES(@Db,@DbStatus,@DbPartial,@SourceCount,@FormatCount,@TableCount,@ModelCount,@DbError,@DbMessage);
                INSERT [#ExternalDataAnalysis_modelSummary] SELECT @Db,@ModelCount,[SourceStatus] FROM [#ExternalDataAnalysis_SourceResults] WHERE [DatabaseName]=@Db AND [SourceRank]=6;
                INSERT [#ExternalDataAnalysis_externalTables]
                SELECT [t].[DatabaseName],[t].[ObjectId],[s].[SchemaName],[t].[TableName],[t].[DataSourceId],[t].[FileFormatId],
                    CASE WHEN COALESCE([t].[DataSourceId],0)=0 THEN 'NOT_APPLICABLE' WHEN [ds].[SourceStatus]<>'AVAILABLE' THEN 'SOURCE_UNAVAILABLE'
                         WHEN [d].[DataSourceId] IS NULL THEN 'NOT_VISIBLE_IN_SCOPE' ELSE 'VISIBLE' END,
                    CASE WHEN COALESCE([t].[FileFormatId],0)=0 THEN 'NOT_APPLICABLE' WHEN [fs].[SourceStatus]<>'AVAILABLE' THEN 'SOURCE_UNAVAILABLE'
                         WHEN [f].[FileFormatId] IS NULL THEN 'NOT_VISIBLE_IN_SCOPE' ELSE 'VISIBLE' END,
                    CASE WHEN [cs].[SourceStatus]='AVAILABLE' THEN COALESCE([c].[VisibleColumnCount],0) END
                FROM [#ExternalDataAnalysis_TableRows] [t]
                LEFT JOIN [#ExternalDataAnalysis_SchemaRows] [s] ON [s].[DatabaseName]=[t].[DatabaseName] AND [s].[SchemaId]=[t].[SchemaId]
                LEFT JOIN [#ExternalDataAnalysis_ColumnRows] [c] ON [c].[DatabaseName]=[t].[DatabaseName] AND [c].[ObjectId]=[t].[ObjectId]
                LEFT JOIN [#ExternalDataAnalysis_dataSources] [d] ON [d].[DatabaseName]=[t].[DatabaseName] AND [d].[DataSourceId]=[t].[DataSourceId]
                LEFT JOIN [#ExternalDataAnalysis_fileFormats] [f] ON [f].[DatabaseName]=[t].[DatabaseName] AND [f].[FileFormatId]=[t].[FileFormatId]
                JOIN [#ExternalDataAnalysis_SourceResults] [ds] ON [ds].[DatabaseName]=[t].[DatabaseName] AND [ds].[SourceRank]=1
                JOIN [#ExternalDataAnalysis_SourceResults] [fs] ON [fs].[DatabaseName]=[t].[DatabaseName] AND [fs].[SourceRank]=2
                JOIN [#ExternalDataAnalysis_SourceResults] [cs] ON [cs].[DatabaseName]=[t].[DatabaseName] AND [cs].[SourceRank]=5
                WHERE [t].[DatabaseName]=@Db;
                FETCH NEXT FROM [ExternalDataDatabases] INTO @Db;
            END;
            CLOSE [ExternalDataDatabases];DEALLOCATE [ExternalDataDatabases];
            INSERT [#ExternalDataAnalysis_databaseStatus]
                SELECT [RequestedName],'DATABASE_UNAVAILABLE',1,NULL,NULL,NULL,NULL,NULL,[ErrorMessage] FROM [#ExternalDataAnalysis_CandidateWarnings];
            INSERT [#ExternalDataAnalysis_warnings] SELECT [RequestedName],[StatusCode],LEFT(COALESCE([ErrorMessage],N'Datenbank nicht verarbeitet.'),2000) FROM [#ExternalDataAnalysis_CandidateWarnings];
            IF EXISTS(SELECT 1 FROM [#ExternalDataAnalysis_databaseStatus] WHERE [IsPartial]=1)
            BEGIN
                SET @Partial=1;
                IF EXISTS(SELECT 1 FROM [#ExternalDataAnalysis_SourceResults] WHERE [SourceStatus]='AVAILABLE') SET @Status='AVAILABLE_LIMITED';
                ELSE
                    SELECT TOP(1) @Status=[StatusCode] FROM [#ExternalDataAnalysis_databaseStatus] WHERE [IsPartial]=1 ORDER BY [DatabaseName];
            END;
            SELECT TOP(1) @Error=[ErrorNumber],@Message=[ErrorMessage] FROM [#ExternalDataAnalysis_SourceResults] WHERE [ErrorNumber] IS NOT NULL ORDER BY [DatabaseName],[SourceRank];
        END;
        ;WITH [Bounded] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseName],[DataSourceId]) [OutputOrdinal] FROM [#ExternalDataAnalysis_dataSources]) DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        ;WITH [Bounded] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseName],[FileFormatId]) [OutputOrdinal] FROM [#ExternalDataAnalysis_fileFormats]) DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        ;WITH [Bounded] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseName],[ObjectId]) [OutputOrdinal] FROM [#ExternalDataAnalysis_externalTables]) DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        ;WITH [Bounded] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseName]) [OutputOrdinal] FROM [#ExternalDataAnalysis_modelSummary]) DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        ;WITH [Bounded] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseName],[SourceName]) [OutputOrdinal] FROM [#ExternalDataAnalysis_sourceStatus]) DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        ;WITH [Bounded] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseName],[WarningCode],[Detail]) [OutputOrdinal] FROM [#ExternalDataAnalysis_warnings]) DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        INSERT [#ExternalDataAnalysis_moduleStatus] VALUES(N'USP_ExternalDataAnalysis',@Status,@Partial,@Error,@Message,@CollectionTimeUtc);
        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'ExternalDataAnalysis' [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@Status [statusCode],@Partial [isPartial],@Error [errorNumber],@Message [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=(SELECT * FROM [#ExternalDataAnalysis_moduleStatus] ORDER BY [ModuleName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_databaseStatus nvarchar(max)=(SELECT * FROM [#ExternalDataAnalysis_databaseStatus] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_dataSources nvarchar(max)=(SELECT * FROM [#ExternalDataAnalysis_dataSources] ORDER BY [DatabaseName],[DataSourceId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_fileFormats nvarchar(max)=(SELECT * FROM [#ExternalDataAnalysis_fileFormats] ORDER BY [DatabaseName],[FileFormatId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_externalTables nvarchar(max)=(SELECT * FROM [#ExternalDataAnalysis_externalTables] ORDER BY [DatabaseName],[ObjectId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_modelSummary nvarchar(max)=(SELECT * FROM [#ExternalDataAnalysis_modelSummary] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=(SELECT * FROM [#ExternalDataAnalysis_sourceStatus] ORDER BY [DatabaseName],[SourceName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=(SELECT * FROM [#ExternalDataAnalysis_warnings] ORDER BY [DatabaseName],[WarningCode],[Detail] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),N',"databaseStatus":',COALESCE(@Json_databaseStatus,N'[]'),N',"dataSources":',COALESCE(@Json_dataSources,N'[]'),N',"fileFormats":',COALESCE(@Json_fileFormats,N'[]'),N',"externalTables":',COALESCE(@Json_externalTables,N'[]'),N',"modelSummary":',COALESCE(@Json_modelSummary,N'[]'),N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;
        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#ExternalDataAnalysis_moduleStatus] ORDER BY [ModuleName];
            SELECT * FROM [#ExternalDataAnalysis_databaseStatus] ORDER BY [DatabaseName];
            SELECT * FROM [#ExternalDataAnalysis_dataSources] ORDER BY [DatabaseName],[DataSourceId];
            SELECT * FROM [#ExternalDataAnalysis_fileFormats] ORDER BY [DatabaseName],[FileFormatId];
            SELECT * FROM [#ExternalDataAnalysis_externalTables] ORDER BY [DatabaseName],[ObjectId];
            SELECT * FROM [#ExternalDataAnalysis_modelSummary] ORDER BY [DatabaseName];
            SELECT * FROM [#ExternalDataAnalysis_sourceStatus] ORDER BY [DatabaseName],[SourceName];
            SELECT * FROM [#ExternalDataAnalysis_warnings] ORDER BY [DatabaseName],[WarningCode],[Detail];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [ExternalDataOutput] CURSOR LOCAL FAST_FORWARD FOR SELECT [ResultName],[TargetTable] FROM [#ExternalDataAnalysis_Map] ORDER BY [ResultName];
            OPEN [ExternalDataOutput];FETCH NEXT FROM [ExternalDataOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#ExternalDataAnalysis_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,@ThrowOnError=1;
                FETCH NEXT FROM [ExternalDataOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [ExternalDataOutput];DEALLOCATE [ExternalDataOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#ExternalDataAnalysis_databaseStatus',@ResultLabel=N'Lokale External-Data-Kataloge: sichtbare Objektanzahlen',@EmptyMessage=N'Keine ausgewählte Datenbank mit sichtbarer External-Data-Katalogevidenz.';
        END;
        IF @PrintMeldungen=1 AND @Status<>'AVAILABLE'
        BEGIN
            DECLARE @PrintMessage nvarchar(2048)=LEFT(CONCAT(N'USP_ExternalDataAnalysis: ',@Status,N'. ',COALESCE(@Message,N'Siehe Quellenstatus und Warnungen.')),2048);
            RAISERROR(N'%s',10,1,@PrintMessage) WITH NOWAIT;
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON;
    END TRY
    BEGIN CATCH
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON;
        THROW;
    END CATCH;
END;
GO

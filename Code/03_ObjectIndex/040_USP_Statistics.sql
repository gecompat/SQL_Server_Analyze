USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_Statistics
Version      : 1.2.0
Stand        : 2026-07-23
Typ          : Stored Procedure
Zweck        : Analysiert Statistikdefinitionen, letzte Aktualisierung,
               Stichprobe, Modification Counter sowie versionsadaptiv die
               Herkunft persistierter Statistiken auf lesbaren Replikaten;
               vollständige ungezielte Scans sind gruppengeschützt.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : Je Datenbank sys.stats, sys.stats_columns, sys.columns,
               sys.objects, sys.tables, sys.schemas,
               sys.dm_db_stats_properties, sys.fn_hadr_is_primary_replica,
               auf SQL Server 2025 capability-geprüfte sys.stats-Spalten sowie
               optional sys.dm_db_incremental_stats_properties.
Parameter    : Die folgende Signatur enthält die öffentlichen Parameter und
               Defaults. Die eingebettete PRINT-Hilfe beschreibt jede
               Eingabeform, NULL-/Leerwertregel, Grenze und feste Option.
Resultsets   : 1. Modulstatus. 2. Status je Datenbank. 3. Statistikübersicht. 4. optionale inkrementelle Partitionsdetails.
Berechtigung : Metadata Visibility und SELECT auf Statistikspalten bzw. Eigentum/db_owner/db_ddladmin/sysadmin für dm_db_stats_properties.
Eigenlast    : Gezielte Abfrage moderat; VOLL und inkrementelle Details durch CATALOG_DEEP/Cross-Database geschützt und begrenzt.
Locking      : READUNCOMMITTED-Kataloge, LOCK_TIMEOUT und je Datenbank isolierter dynamischer Batch.
Partial      : Fehler je Datenbank bzw. Teilquelle werden isoliert; vorhandene
               Teilergebnisse bleiben erhalten. Das Framework vergibt keine Rechte.
Beispiele    :
  EXEC monitor.USP_Statistics @DatabaseNames=N'SampleDatabase', @SchemaNamePattern=N'dbo', @ObjectNamePattern=N'FactSales';
  EXEC monitor.USP_Statistics @DatabaseNames=N'SampleDatabase', @AnalyseModus='VOLL', @MinModificationPercent=10;
  EXEC monitor.USP_Statistics @Hilfe=1;
Änderungen   : 1.2.0 - SQL25-004 erhält IsTemporary, aktuelle Replica-Rolle
                         und die Herkunftsfelder replica_role_id,
                         replica_role_desc und replica_name versionsadaptiv.
                         Der äußere LOCK_TIMEOUT bleibt unverändert; jeder
                         Datenbankread setzt ihn nur im isolierten Dynamic SQL.
               1.1.0 - Inkrementelle Partitionsdetails werden bei aktiviertem
                         Schalter auch als Resultset und JSON-Array veröffentlicht.
               1.0.0 - Erstfassung Phase 2.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_Statistics]
      @DatabaseNames                  nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @SchemaNames                    nvarchar(max)  = NULL
    , @SchemaNamePattern              nvarchar(4000) = NULL
    , @ObjectNames                    nvarchar(max)  = NULL
    , @ObjectNamePattern              nvarchar(4000) = NULL
    , @FullObjectNames                nvarchar(max)  = NULL
    , @StatisticsNames                nvarchar(max)  = NULL
    , @StatisticsNamePattern          nvarchar(4000) = NULL
    , @AnalyseModus                   varchar(16)   = 'GEZIELT'
    , @MinModificationPercent         decimal(9,2)  = 0
    , @MinAlterTage                   int           = 0
    , @MitIncrementellenDetails       bit           = 0
    , @MaxZeilen                      int           = 10000
    , @LockTimeoutMs                  int           = 0
    , @ResultSetArt                  varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                  bit            = 0
    , @Json                          nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                 bit           = 1
    , @Hilfe                          bit           = 0
AS
BEGIN
 SET NOCOUNT ON;

    DECLARE @OriginalLockTimeout int = @@LOCK_TIMEOUT;
    DECLARE @ProductMajorVersion int =
        TRY_CONVERT(int, SERVERPROPERTY('ProductMajorVersion'));

    SET @Json = NULL;
    DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'statistics',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @DatabaseName sysname=NULL,@CrossDatabaseRequestedInternal bit=0,@DatenbankNameLike nvarchar(4000)=NULL;
    DECLARE @SchemaNameLike nvarchar(4000)=NULL,@ObjectNameLike nvarchar(4000)=NULL;
    DECLARE @StatisticsNameLike nvarchar(4000)=NULL;
    DECLARE @SchemaPatternMode varchar(8),@SchemaPatternValue nvarchar(4000),@SchemaRegexFlags varchar(8),@SchemaPatternValid bit;
    DECLARE @ObjectPatternMode varchar(8),@ObjectPatternValue nvarchar(4000),@ObjectRegexFlags varchar(8),@ObjectPatternValid bit;
    SELECT @SchemaPatternMode=[PatternMode],@SchemaPatternValue=[PatternValue],@SchemaRegexFlags=[RegexFlags],@SchemaPatternValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@SchemaNamePattern);
    SELECT @ObjectPatternMode=[PatternMode],@ObjectPatternValue=[PatternValue],@ObjectRegexFlags=[RegexFlags],@ObjectPatternValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ObjectNamePattern);
    IF @SchemaPatternMode='LIKE' SET @SchemaNameLike=@SchemaPatternValue;
    IF @ObjectPatternMode='LIKE' SET @ObjectNameLike=@ObjectPatternValue;
    DECLARE @IndexPatternMode varchar(8)='NONE',@IndexPatternValue nvarchar(4000)=NULL,@IndexRegexFlags varchar(8)=NULL,@IndexPatternValid bit=1;
    DECLARE @StatisticsPatternMode varchar(8),@StatisticsPatternValue nvarchar(4000),@StatisticsRegexFlags varchar(8),@StatisticsPatternValid bit;
    SELECT @StatisticsPatternMode=[PatternMode],@StatisticsPatternValue=[PatternValue],@StatisticsRegexFlags=[RegexFlags],@StatisticsPatternValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@StatisticsNamePattern);
    IF @StatisticsPatternMode='LIKE' SET @StatisticsNameLike=@StatisticsPatternValue;
    DECLARE @DatabaseListCount int=0;
    IF @DatabaseNames IS NOT NULL AND NULLIF(LTRIM(RTRIM(@DatabaseNames)),N'') IS NOT NULL
        SELECT @DatabaseListCount=COUNT(*),@DatabaseName=MIN([NameValue]) FROM [monitor].[TVF_ParseSqlNameList](@DatabaseNames) WHERE [IsValid]=1;
    SET @CrossDatabaseRequestedInternal=CONVERT(bit,CASE WHEN @DatabaseNames IS NULL OR @DatabaseNamePattern IS NOT NULL OR @DatabaseListCount>1 THEN 1 ELSE 0 END);
    SELECT @DatenbankNameLike=CASE WHEN [PatternMode]='LIKE' THEN [PatternValue] END FROM [monitor].[TVF_ParsePattern](@DatabaseNamePattern);
    CREATE TABLE [#Statistics_NameFilters]([FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ItemOrdinal] int NOT NULL,[NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#Statistics_DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsSystemDatabase] bit,[RequestedOrdinal] int);
    DECLARE @FilterStatus varchar(40)='AVAILABLE',@FilterError nvarchar(2048)=NULL,@CrossDatabaseRequested bit=0;
    EXEC [monitor].[USP_PrepareNameFilters] @SchemaNames=@SchemaNames,@ObjectNames=@ObjectNames,@FullObjectNames=@FullObjectNames,@IndexNames=NULL,@StatisticsNames=@StatisticsNames,@ColumnNames=NULL,@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@FilterTable=N'#Statistics_NameFilters';
    IF @FilterStatus='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed,@AnalysisClass='STATISTICS_TARGETED',@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,@CandidateTable=N'#Statistics_DatabaseCandidates';
    IF @FilterStatus='AVAILABLE' AND (UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,''))))='VOLL' OR @MitIncrementellenDetails=1)
        EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='CATALOG_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT;
    DECLARE @SchemaPredicateS nvarchar(max),@SchemaPredicateSch nvarchar(max),@ObjectPredicateO nvarchar(max),@FullObjectPredicateSO nvarchar(max),@IndexPredicateI nvarchar(max),@StatisticsPredicateSt nvarchar(max);
    SET @SchemaPredicateS=N' AND (NOT EXISTS(SELECT 1 FROM [#Statistics_NameFilters] WHERE [FilterType]=''SCHEMA'') OR EXISTS(SELECT 1 FROM [#Statistics_NameFilters] [f] WHERE [f].[FilterType]=''SCHEMA'' AND [f].[NameValue]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @SchemaPredicateSch=REPLACE(@SchemaPredicateS,N'[s].[name]',N'[sch].[name]');
    SET @ObjectPredicateO=N' AND (NOT EXISTS(SELECT 1 FROM [#Statistics_NameFilters] WHERE [FilterType]=''OBJECT'') OR EXISTS(SELECT 1 FROM [#Statistics_NameFilters] [f] WHERE [f].[FilterType]=''OBJECT'' AND [f].[NameValue]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @FullObjectPredicateSO=N' AND (NOT EXISTS(SELECT 1 FROM [#Statistics_NameFilters] WHERE [FilterType]=''FULL_OBJECT'') OR EXISTS(SELECT 1 FROM [#Statistics_NameFilters] [f] WHERE [f].[FilterType]=''FULL_OBJECT'' AND ([f].[DatabaseName] IS NULL OR [f].[DatabaseName]=@pDbName COLLATE SQL_Latin1_General_CP1_CS_AS) AND ([f].[SchemaName] IS NULL OR [f].[SchemaName]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS) AND [f].[ObjectName]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @IndexPredicateI=N' AND (NOT EXISTS(SELECT 1 FROM [#Statistics_NameFilters] WHERE [FilterType]=''INDEX'') OR EXISTS(SELECT 1 FROM [#Statistics_NameFilters] [f] WHERE [f].[FilterType]=''INDEX'' AND [f].[NameValue]=[i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @StatisticsPredicateSt=N' AND (NOT EXISTS(SELECT 1 FROM [#Statistics_NameFilters] WHERE [FilterType]=''STATISTICS'') OR EXISTS(SELECT 1 FROM [#Statistics_NameFilters] [f] WHERE [f].[FilterType]=''STATISTICS'' AND [f].[NameValue]=[st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    IF @SchemaPatternMode='LIKE' BEGIN SET @SchemaPredicateS+=N' AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';SET @SchemaPredicateSch+=N' AND [sch].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';END;
    IF @SchemaPatternMode IN('REGEX','REGEXI') BEGIN SET @SchemaPredicateS+=N' AND REGEXP_LIKE([s].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')';SET @SchemaPredicateSch+=N' AND REGEXP_LIKE([sch].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')';END;
    IF @ObjectPatternMode='LIKE' SET @ObjectPredicateO+=N' AND [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @ObjectPatternMode IN('REGEX','REGEXI') SET @ObjectPredicateO+=N' AND REGEXP_LIKE([o].[name],N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''','''+@ObjectRegexFlags+N''')';
    IF @IndexPatternMode='LIKE' SET @IndexPredicateI+=N' AND [i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@IndexPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @IndexPatternMode IN('REGEX','REGEXI') SET @IndexPredicateI+=N' AND REGEXP_LIKE([i].[name],N'''+REPLACE(@IndexPatternValue,N'''',N'''''')+N''','''+@IndexRegexFlags+N''')';
    IF @StatisticsPatternMode='LIKE' SET @StatisticsPredicateSt+=N' AND [st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@StatisticsPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @StatisticsPatternMode IN('REGEX','REGEXI') SET @StatisticsPredicateSt+=N' AND REGEXP_LIKE([st].[name],N'''+REPLACE(@StatisticsPatternValue,N'''',N'''''')+N''','''+@StatisticsRegexFlags+N''')';
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @MonitorPrintMessage nvarchar(2048); SET @AnalyseModus=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'GEZIELT'))));
 IF @Hilfe=1
 BEGIN
        PRINT N'monitor.USP_Statistics';
        PRINT N'Inventarisiert sichtbare Statistikdefinitionen und Update-Properties im ausgewählten Datenbank- und Objektumfang.';
        PRINT N'GEZIELT verlangt eine exakte Schema-, Objekt- oder Statistikliste, einen vollständigen Objektbezug oder ein Schema-/Objektpattern. VOLL und aktivierte inkrementelle Details prüfen zusätzlich CATALOG_DEEP.';
        PRINT N'CONSOLE liefert beschriftete Fachresultate; RAW liefert technische Resultsets; TABLE schreibt statistics; NONE unterdrückt Resultsets. JSON wird unabhängig über @JsonErzeugen erzeugt.';
        PRINT N'Beispiel: EXEC [monitor].[USP_Statistics] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''[ExampleSchema].[ExampleTable]'', @ResultSetArt=''RAW'';';
        PRINT N'JSON: DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_Statistics] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''[ExampleSchema].[ExampleTable]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT;';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Ein einzelner Datenbankname oder eine bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder eine nach äußerem Trimmen leere Eingabe bedeutet keine explizite Auswahl; der Kandidatenhelfer wählt alle zulässigen sichtbaren Online-Benutzerdatenbanken, soweit kein Pattern einschränkt. Pipe trennt nur außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt. Leere Elemente, ungültige SQL-Namen, case-sensitive Duplikate und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Eine nichtleere Liste ist mit einem nicht-NULL-Datenbankpattern exklusiv.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. Bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt deren Aufnahme, soweit sichtbar und online. NULL ist im Datenbankkandidatenhelfer ungültig. Beim Binden zu bit konvertierbare numerische Nichtnullwerte werden zu 0 oder 1 konvertiert.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Datenbanknamen-Pattern. NULL deaktiviert es; leer oder nach Präfixentfernung leer ist ungültig. Äußere Leerzeichen werden getrimmt; die Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt, ohne Präfix gilt LIKE; danach wird nicht erneut getrimmt. LIKE verwendet %, _ und [...] mit case-sensitiver Framework-Collation. regex: verwendet Flag c, regexi: Flag i. Für Datenbanknamen prüft der Kandidatenhelfer Regex-Unterstützung im Installationsdatenbankkontext; erforderlich sind SQL Server 2025 und Compatibility Level 170. Nicht mit einer nichtleeren @DatabaseNames-Liste kombinieren.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. SQL-bit-Bestätigung mit 0 oder 1; 0 bleibt 0, von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1. STATISTICS_TARGETED verlangt kein Gruppengate. VOLL oder @MitIncrementellenDetails=1 aktiviert zusätzlich CATALOG_DEEP und verlangt ausdrücklich 1; 0 bestätigt diesen Pfad nicht. NULL ist im normalen Datenbankauswahl-/Deep-Prüfpfad INVALID_PARAMETER. Bestätigung wird vor der Gruppen-/Tokenberechtigung geprüft: 1 verleiht keine Rolle und keine SQL-Rechte; ohne Berechtigung folgt DENIED_GROUP.';
        PRINT N'@SchemaNames nvarchar(max); Default: NULL. Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere oder nur aus Leerzeichen bestehende Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen validiert und case-sensitive verglichen. Doppelte Werte derselben Namensart und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit @SchemaNamePattern kombinieren; bei nicht-NULL @FullObjectNames ist diese Kombination ebenfalls ungültig.';
        PRINT N'@SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Pattern für Schemanamen. NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere Leerzeichen werden vor der Erkennung eines Präfixes like:, regex: oder regexi: entfernt; danach bleibt das Pattern unverändert. Ohne Präfix und mit like: gilt case-sensitives SQL-LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Feldregex wird inline in der jeweiligen Quelldatenbank ausgeführt; dafür gibt es keine eigene Versionsvorprüfung, sodass fehlende Unterstützung als datenbankweise isolierter Fehler auftreten kann. Nicht mit nicht-NULL @SchemaNames kombinieren.';
        PRINT N'@ObjectNames nvarchar(max); Default: NULL. Exakte einteilige Objektnamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, mit höchstens 128 Zeichen geprüft und case-sensitive verglichen. Doppelte Objektnamen und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit @ObjectNamePattern kombinieren; bei nicht-NULL @FullObjectNames ist diese Kombination ebenfalls ungültig.';
        PRINT N'@ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objektnamen-Pattern. NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere Leerzeichen werden vor dem Erkennen von like:, regex: oder regexi: entfernt; danach wird nicht erneut getrimmt. Ohne Präfix/like: gilt case-sensitives LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Feldregex läuft inline je Quelldatenbank ohne eigene Versionsvorprüfung; fehlende Unterstützung kann als isolierter Datenbankfehler erscheinen. Nicht mit nicht-NULL @ObjectNames kombinieren.';
        PRINT N'@FullObjectNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. Bei einem Datenbankteil ist das Schema erforderlich; vierteilige Linked-Server-Bezüge sind unzulässig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt und nach PARSENAME/sysname-Grenzen geprüft. NULL bedeutet kein Filter; ein leerer nvarchar-String ist EMPTY_LIST, Leerzeichen ergibt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemanamen bleiben offen. Duplikate und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit nicht-NULL @SchemaNames oder @ObjectNames kombinieren.';
        PRINT N'@StatisticsNames nvarchar(max); Default: NULL. Exakte einteilige Statistiknamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, als einteilige SQL-Namen bis 128 Zeichen validiert und case-sensitive verglichen. Duplikate sowie Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit nicht-NULL @StatisticsNamePattern kombinieren.';
        PRINT N'@StatisticsNamePattern nvarchar(4000); Default: NULL. Optionales Statistiknamen-Pattern. NULL deaktiviert den Filter; leere Eingabe oder leeres Präfix ist ungültig. Äußere Leerzeichen werden vor Erkennung von like:, regex: oder regexi: getrimmt; der Rest wird nicht erneut getrimmt. Ohne Präfix/like: gilt case-sensitives LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Regex wird im jeweiligen Quelldatenbankbatch ausgewertet und hat keine separate Versionsvorprüfung; Fehler können pro Datenbank isoliert werden. Nicht mit nicht-NULL @StatisticsNames kombinieren. Ein Statistikpattern allein erfüllt den GEZIELT-Filter von USP_Statistics nicht; ein zusätzlicher Schema-/Objektfilter ist erforderlich. Das gilt auch beim weitergereichten Aufruf aus der Verteilungsanalyse.';
        PRINT N'@AnalyseModus varchar(16); Default: ''GEZIELT''. Text wird getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind ausschließlich GEZIELT und VOLL; NULL wird als GEZIELT behandelt. Bei USP_Statistics verlangt GEZIELT mindestens eine exakte Schema-/Objekt-/Statistikliste, @FullObjectNames oder ein Schema-/Objektpattern; nur eine Datenbank genügt nicht. VOLL prüft CATALOG_DEEP. Die Verteilungsanalyse prüft CATALOG_DEEP unabhängig vom Modus; GEZIELT verlangt dort einen Objekt-, Schema- oder Statistikfilter. Ein gültiger Scope bleibt erforderlich.';
        PRINT N'@MinModificationPercent decimal(9,2); Default: 0. Mindestanteil geänderter Zeilen relativ zur Statistikzeilenzahl, decimal(9,2)-Wert von 0 bis 100 einschließlich; bei der Parameterbindung wird auf zwei Nachkommastellen konvertiert. Werte außerhalb dieses Bereichs werden als INVALID_PARAMETER abgewiesen; NULL ist nicht ausdrücklich abgewiesen und führt wegen des SQL-NULL-Vergleichs nicht zu dieser Bereichsverletzung. 0 lässt alle passenden Statistiken zu; höhere Werte filtern nach ModificationPercent. Bei Nullbasis wird der Anteil zu NULL und der Filterausdruck fällt aus der Auswahl.';
        PRINT N'@MinAlterTage int; Default: 0. Nichtnegative ganze Zahl von 0 bis 2147483647. 0 deaktiviert den Altersfilter; positive Werte vergleichen DATEDIFF(DAY,last_updated,SYSDATETIME()) mit dieser Untergrenze. Gezählt werden überschrittene Kalendertagsgrenzen gemäß der Serveruhr, nicht volle 24-Stunden-Perioden. Negative Werte sind INVALID_PARAMETER. NULL passiert den negativen Wertecheck als UNKNOWN; dann erfüllen nur Zeilen mit last_updated IS NULL den gesonderten Alterszweig. Solche NULL-Zeitpunkte passieren auch bei positiver Grenze, ohne dadurch ein gemessenes Alter zu belegen.';
        PRINT N'@MitIncrementellenDetails bit; Default: 0. Bit-Schalter: 0 lässt das zusätzliche Partitionsresultset und JSON-Array aus; 1 liest nach der Hauptabfrage inkrementelle Details nur für bereits materialisierte Ergebnisstatistiken mit IsIncremental=1. Aktivierung prüft CATALOG_DEEP und braucht gegebenenfalls die Gruppenfreigabe. NULL löst diese Zusatzabfrage nicht aus. Die Obergrenze gilt je Datenbank und Detailquery; fehlgeschlagene Detailquellen werden datenbankweise als Teilfehler markiert, während Basisstatistiken erhalten bleiben.';
        PRINT N'@MaxZeilen int; Default: 10000. Nichtnegative int-Obergrenze von 0 bis 2147483647. NULL oder 0 wird intern als unbegrenzt behandelt; negative Werte sind ungültig. Die TOP-Grenze gilt je Datenbank und je Haupt- beziehungsweise Detailabfrage, nicht global. Ergebnisse werden vor TOP nach ModificationPercent absteigend priorisiert; bei mehreren Datenbanken kann die Gesamtzahl die angegebene Zahl überschreiten.';
        PRINT N'@LockTimeoutMs int; Default: 0. Ganzzahlige Wartezeit für Metadatenlocks in Millisekunden, zulässig von 0 bis 60000 einschließlich. 0 wartet nicht; Werte außerhalb des Bereichs sind ungültig. Der Wert wird nur in isolierten dynamischen Datenbankbatches gesetzt. SET-Werte des Prozedur- oder dynamischen Batchscopes werden bei Rückkehr zurückgenommen; der eigenständige SET-Batch belegt keine weiterreichende Sessionwirkung.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Wird außen getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind CONSOLE, RAW, TABLE und NONE. CONSOLE liefert beschriftete Status- und Fachresultsets; RAW liefert dieselben Statusbereiche mit technischen Fachdaten; TABLE schreibt das typisierte Resultset statistics nach erfolgreichem Vorab-Preflight; NONE unterdrückt Resultsets. NULL/leer wird ungültig. @ResultTablesJson darf nur bei TABLE nichtleer sein. Die Konsolenausgabe erzeugt bei leerer Fachquelle eine verständliche Leerzeile.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. JSON-Konfiguration der lokalen TABLE-Zieltabelle; nur bei @ResultSetArt=TABLE darf der bereinigte Inhalt nichtleer sein. Für TABLE ist die Konfiguration erforderlich und muss den zulässigen Resultnamen statistics auf eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte abbilden. NULL/leer bei TABLE führt zum Preflightfehler; ungültige Ziele werfen einen Fehler vor der fachlichen Analyse. Bei anderen Ausgabearten ist ein nichtleerer Wert ein Fehler.';
        PRINT N'@JsonErzeugen bit; Default: 0. Bit-Schalter: 0 erzeugt kein JSON und lässt @Json nach seiner anfänglichen NULL-Zuweisung NULL; 1 erzeugt das JSON mit meta, statistics, incrementalStatistics und databaseStatus. NULL ist nicht als ungültig abgefangen und aktiviert die IF-Bedingung nicht.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter vom Typ nvarchar(max). Optional mit einer nvarchar(max)-OUTPUT-Variablen zu binden; eine fehlende Bindung verhindert den Prozeduraufruf nicht. Wird bei Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 erhält er das JSON-Objekt mit den Schlüsseln meta, statistics, incrementalStatistics und databaseStatus; sonst bleibt er NULL. Meta enthält resultName, schemaVersion=2, generatedAtUtc, statusCode, isPartial und rowCount.';
        PRINT N'@PrintMeldungen bit; Default: 1. Bit-Schalter für eine zusätzliche Warnmeldung via RAISERROR mit Severity 10 und NOWAIT. 1 gibt sie bei Status ungleich AVAILABLE aus; 0 unterdrückt diese Meldung. NULL aktiviert die IF-Bedingung nicht. Der Schalter ändert Status, Resultsets und JSON nicht.';
        PRINT N'@Hilfe bit; Default: 0. SQL-bit-Schalter: 1 druckt die PRINT-Hilfe und kehrt vor den eigentlichen Statistikabfragen und der Ergebniskonstruktion zurück; 0 führt den normalen Ablauf fort. Von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1, NULL aktiviert Hilfe nicht. Patternparsing, Namensfilter, Datenbankkandidaten und ein bedingt aktiviertes Deep-Gate laufen bereits davor. Auch TABLE-Preflight und die Abweisung einer nichtleeren TABLE-Zuordnung bei anderer Ausgabeart erfolgen vor Hilfe; Hilfe ist daher kein voraussetzungsloser Filter-/Berechtigungs-Bypass.';
        PRINT N'EXEC [monitor].[USP_Statistics] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''[ExampleSchema].[ExampleTable]'', @MaxZeilen=100, @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_Statistics] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''[ExampleSchema].[ExampleTable]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [ExampleJson];';
        PRINT N'CREATE TABLE [#ExampleStatistics]([Seed] int NULL); BEGIN TRY     EXEC [monitor].[USP_Statistics] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''[ExampleSchema].[ExampleTable]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"statistics":"#ExampleStatistics"}''; END TRY BEGIN CATCH     DROP TABLE [#ExampleStatistics];     THROW; END CATCH; DROP TABLE [#ExampleStatistics];';
        PRINT N'EXEC [monitor].[USP_Statistics] @Hilfe=1;';











        RETURN;
 END;

    DECLARE @ModuleName sysname = N'USP_Statistics';
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();

    DECLARE @OverallStatus varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @TotalRows bigint = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Detail nvarchar(2000) = NULL;

    CREATE TABLE [#Statistics_DatabaseStatus]
    (
          [DatabaseName]       sysname COLLATE SQL_Latin1_General_CP1_CS_AS        NULL
        , [StatusCode]         varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS    NOT NULL
        , [IsPartial]          bit            NOT NULL
        , [RowCount]           bigint         NOT NULL
        , [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS  NULL
        , [ErrorNumber]        int            NULL
        , [ErrorMessage]       nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Detail]             nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @FilterStatus<>'AVAILABLE' BEGIN SET @OverallStatus=@FilterStatus;SET @ErrorMessage=@FilterError;END;
    IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';END;
    IF @SchemaPatternValid=0 OR @ObjectPatternValid=0 OR @IndexPatternValid=0 OR @StatisticsPatternValid=0 OR (@SchemaNames IS NOT NULL AND @SchemaNamePattern IS NOT NULL) OR (@ObjectNames IS NOT NULL AND @ObjectNamePattern IS NOT NULL) OR (@StatisticsNames IS NOT NULL AND @StatisticsNamePattern IS NOT NULL) BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'Exakte Liste und Pattern derselben Eigenschaft sind gegenseitig exklusiv.';END;
IF @MaxZeilen<0 OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
    BEGIN
        SET @OverallStatus = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültiger Parameter: @MaxZeilen oder @LockTimeoutMs außerhalb des zulässigen Bereichs.';
    END


    IF @OverallStatus <> 'AVAILABLE'
    BEGIN
        INSERT [#Statistics_DatabaseStatus]([DatabaseName], [StatusCode], [IsPartial], [RowCount], [RequiredPermission], [ErrorNumber], [ErrorMessage], [Detail])
        VALUES(@DatabaseName, @OverallStatus, 1, 0, NULL, NULL, @ErrorMessage, N'Keine Datenbankanalyse ausgeführt.');
        SET @IsPartial = 1;
    END

 DECLARE @CatalogAllowed bit=1;
 IF @AnalyseModus='VOLL' OR @MitIncrementellenDetails=1 SELECT @CatalogAllowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0) FROM [monitor].[VW_AnalyseAccessCurrent] WHERE [AnalysisClass]='CATALOG_DEEP';
 CREATE TABLE [#Statistics_Result]
 (
  [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectId] int NOT NULL,
  [StatisticsId] int NOT NULL,[StatisticsName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsIndexStatistics] bit NOT NULL,[IsAutoCreated] bit NULL,[IsUserCreated] bit NULL,
  [IsFiltered] bit NULL,[FilterDefinition] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[NoRecompute] bit NULL,[IsIncremental] bit NULL,[HasPersistedSample] bit NULL,
  [IsTemporary] bit NULL,[CurrentReplicaRole] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CurrentReplicaRoleStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [ReplicaRoleId] tinyint NULL,[ReplicaRoleDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [ReplicaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ReplicaMetadataStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [StatisticsColumns] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[LastUpdated] datetime2 NULL,[Rows] bigint NULL,[RowsSampled] bigint NULL,[SamplePercent] decimal(9,4) NULL,
  [Steps] int NULL,[UnfilteredRows] bigint NULL,[ModificationCounter] bigint NULL,[ModificationPercent] decimal(19,4) NULL,
  [PersistedSamplePercent] float NULL,[DaysSinceLastUpdate] int NULL,[VisibilityOrState] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
 );
 CREATE TABLE [#Statistics_Incremental]
 (
  [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatisticsId] int NOT NULL,[StatisticsName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [PartitionNumber] int NOT NULL,[LastUpdated] datetime2 NULL,[Rows] bigint NULL,[RowsSampled] bigint NULL,[Steps] int NULL,
  [UnfilteredRows] bigint NULL,[ModificationCounter] bigint NULL,[ModificationPercent] decimal(19,4) NULL
 );
 IF @OverallStatus='AVAILABLE' AND (@AnalyseModus NOT IN ('GEZIELT','VOLL') OR @MinModificationPercent<0 OR @MinModificationPercent>100 OR @MinAlterTage<0)
 BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'Ungültige Statistikparameter.'; INSERT [#Statistics_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE' AND @AnalyseModus='GEZIELT' AND NOT EXISTS(SELECT 1 FROM [#Statistics_NameFilters]) AND @SchemaNamePattern IS NULL AND @ObjectNamePattern IS NULL
 BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'GEZIELT erfordert eine exakte Namensliste, @FullObjectNames oder ein Schema-/Objekt-Pattern.'; INSERT [#Statistics_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE' AND (@AnalyseModus='VOLL' OR @MitIncrementellenDetails=1) AND @CatalogAllowed=0
 BEGIN SET @OverallStatus='DENIED_GROUP'; SET @ErrorMessage=N'CATALOG_DEEP ist für VOLL bzw. inkrementelle Details nicht freigegeben.'; INSERT [#Statistics_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE'
 BEGIN
  DECLARE
        @DbId int
      , @DbName sysname
      , @Sql nvarchar(max)
      , @Rows bigint
      , @ReplicaMetadataColumnsAvailable bit
      , @ReplicaMetadataCapabilityStatus varchar(40)
      , @ReplicaProjection nvarchar(max)
      , @ReplicaCapabilitySql nvarchar(max)
      , @CurrentReplicaIsPrimary bit
      , @CurrentReplicaRole varchar(40)
      , @CurrentReplicaRoleStatus varchar(40)
      , @CurrentReplicaSql nvarchar(max);
  DECLARE dbcur CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseId],[DatabaseName] FROM [#Statistics_DatabaseCandidates];
  OPEN dbcur; FETCH NEXT FROM dbcur INTO @DbId,@DbName;
  WHILE @@FETCH_STATUS=0
   BEGIN
   BEGIN TRY
    SET @CurrentReplicaIsPrimary=NULL;
    SET @CurrentReplicaRole=NULL;
    SET @CurrentReplicaRoleStatus='NOT_APPLICABLE';

    IF COALESCE(CONVERT(int,SERVERPROPERTY('IsHadrEnabled')),0)<>1
        SET @CurrentReplicaRole='HADR_DISABLED';
    ELSE
    BEGIN
     BEGIN TRY
      SET @CurrentReplicaSql =
          N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs)
        + N'; USE ' + QUOTENAME(@DbName) + N';
SELECT @pIsPrimary=sys.fn_hadr_is_primary_replica(@pDbName);';

      EXEC [sys].[sp_executesql]
            @CurrentReplicaSql
          , N'@pDbName sysname,@pIsPrimary bit OUTPUT'
          , @pDbName=@DbName
          , @pIsPrimary=@CurrentReplicaIsPrimary OUTPUT;

      SET @CurrentReplicaRole=
          CASE
              WHEN @CurrentReplicaIsPrimary=1 THEN 'PRIMARY'
              WHEN @CurrentReplicaIsPrimary=0 THEN 'SECONDARY'
              ELSE 'NOT_IN_AG_OR_UNKNOWN'
          END;
      SET @CurrentReplicaRoleStatus='AVAILABLE';
     END TRY
     BEGIN CATCH
      SET @CurrentReplicaRole=NULL;
      SET @CurrentReplicaRoleStatus=
          CASE
              WHEN ERROR_NUMBER() IN (229,262,297,300,371,916)
                  THEN 'DENIED_PERMISSION'
              WHEN ERROR_NUMBER()=1222
                  THEN 'TIMEOUT'
              ELSE 'ERROR_HANDLED'
          END;
     END CATCH;
    END;

    SET @ReplicaMetadataColumnsAvailable=0;
    SET @ReplicaMetadataCapabilityStatus=
        CASE
            WHEN COALESCE(@ProductMajorVersion,0)<17 THEN 'UNAVAILABLE_VERSION'
            ELSE 'UNAVAILABLE_COLUMNS'
        END;

    IF COALESCE(@ProductMajorVersion,0)>=17
    BEGIN
     BEGIN TRY
      SET @ReplicaCapabilitySql =
          N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs)
        + N'; USE ' + QUOTENAME(@DbName) + N';
SELECT @pAvailable =
       CONVERT(bit,CASE WHEN COUNT_BIG(*)=3 THEN 1 ELSE 0 END)
FROM sys.all_views AS [v] WITH (NOLOCK)
JOIN sys.schemas AS [s] WITH (NOLOCK)
  ON [s].[schema_id]=[v].[schema_id]
JOIN sys.all_columns AS [c] WITH (NOLOCK)
  ON [c].[object_id]=[v].[object_id]
WHERE [s].[name]=N''sys''
  AND [v].[name]=N''stats''
  AND [c].[name] IN
      (N''replica_role_id'',N''replica_role_desc'',N''replica_name'');';

      EXEC [sys].[sp_executesql]
            @ReplicaCapabilitySql
          , N'@pAvailable bit OUTPUT'
          , @pAvailable=@ReplicaMetadataColumnsAvailable OUTPUT;

      SET @ReplicaMetadataCapabilityStatus=
          CASE
              WHEN @ReplicaMetadataColumnsAvailable=1 THEN 'AVAILABLE'
              ELSE 'UNAVAILABLE_COLUMNS'
          END;
     END TRY
     BEGIN CATCH
      SET @ReplicaMetadataColumnsAvailable=0;
      SET @ReplicaMetadataCapabilityStatus=
          CASE
              WHEN ERROR_NUMBER() IN (229,262,297,300,371,916)
                  THEN 'DENIED_METADATA'
              WHEN ERROR_NUMBER()=1222
                  THEN 'TIMEOUT'
              ELSE 'CAPABILITY_ERROR'
          END;
     END CATCH;
    END;

    SET @ReplicaProjection =
        CASE
            WHEN @ReplicaMetadataColumnsAvailable=1
            THEN N'
 [st].[is_temporary],
 @pCurrentReplicaRole,@pCurrentReplicaRoleStatus,
 [st].[replica_role_id],[st].[replica_role_desc],[st].[replica_name],
 CASE
      WHEN [st].[replica_role_id] IS NULL
       AND [st].[replica_role_desc] IS NULL
       AND [st].[replica_name] IS NULL
          THEN ''NOT_RECORDED''
      WHEN [st].[replica_role_id] BETWEEN 1 AND 4
       AND [st].[replica_role_desc] COLLATE Latin1_General_100_CI_AI=
           CASE [st].[replica_role_id]
                WHEN 1 THEN N''Primary''
                WHEN 2 THEN N''Secondary''
                WHEN 3 THEN N''Geo Secondary''
                WHEN 4 THEN N''Geo HA Secondary''
           END
       AND ([st].[replica_role_id]=1 OR [st].[replica_name] IS NOT NULL)
          THEN ''AVAILABLE''
      ELSE ''PARTIAL_METADATA''
 END'
            ELSE N'
 [st].[is_temporary],
 @pCurrentReplicaRole,@pCurrentReplicaRoleStatus,
 CONVERT(tinyint,NULL),CONVERT(nvarchar(60),NULL),CONVERT(sysname,NULL),
 @pReplicaMetadataStatus'
        END;

    SET @Sql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + N'; USE ' + QUOTENAME(@DbName) + N';
INSERT #Statistics_Result
SELECT TOP (@pMaxRows)
 @pDbName,[sch].[name],[o].[name],[o].[object_id],[st].[stats_id],[st].[name],CONVERT(bit,CASE WHEN [ix].[index_id] IS NULL THEN 0 ELSE 1 END),
 [st].[auto_created],[st].[user_created],[st].[has_filter],[st].[filter_definition],[st].[no_recompute],[st].[is_incremental],[st].[has_persisted_sample],
 '+@ReplicaProjection+N',
 [cols].[StatisticsColumns],[sp].[last_updated],[sp].[rows],[sp].[rows_sampled],
 CONVERT(decimal(9,4),[sp].[rows_sampled]*100.0/NULLIF([sp].[rows],0)),[sp].[steps],[sp].[unfiltered_rows],[sp].[modification_counter],
 CONVERT(decimal(19,4),[sp].[modification_counter]*100.0/NULLIF([sp].[rows],0)),[sp].[persisted_sample_percent],
 CASE WHEN [sp].[last_updated] IS NULL THEN NULL ELSE DATEDIFF(DAY,[sp].[last_updated],SYSDATETIME()) END,
 CASE WHEN [sp].[last_updated] IS NULL AND [sp].[rows] IS NULL THEN ''NOT_VISIBLE_OR_NOT_MATERIALIZED''
      WHEN [sp].[rows]=0 THEN ''EMPTY_OR_FILTER_NO_ROWS''
      ELSE ''VISIBLE'' END
FROM sys.stats AS [st] WITH (NOLOCK)
JOIN sys.objects AS [o] WITH (NOLOCK) ON [o].[object_id]=[st].[object_id]
JOIN sys.schemas AS [sch] WITH (NOLOCK) ON [sch].[schema_id]=[o].[schema_id]
LEFT JOIN sys.indexes AS [ix] WITH (NOLOCK) ON [ix].[object_id]=[st].[object_id] AND [ix].[index_id]=[st].[stats_id]
OUTER APPLY sys.dm_db_stats_properties([st].[object_id],[st].[stats_id]) AS [sp]
OUTER APPLY
(
 SELECT STUFF((SELECT N'', ''+QUOTENAME([c].[name])
               FROM sys.stats_columns AS [sc] WITH (NOLOCK)
               JOIN sys.columns AS [c] WITH (NOLOCK) ON [c].[object_id]=[sc].[object_id] AND [c].[column_id]=[sc].[column_id]
               WHERE [sc].[object_id]=[st].[object_id] AND [sc].[stats_id]=[st].[stats_id]
               ORDER BY [sc].[stats_column_id] FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,N'''') AS [StatisticsColumns]
) AS [cols]
WHERE [o].[type] IN (''U'',''V'') AND [o].[is_ms_shipped]=0
'+@SchemaPredicateSch+@ObjectPredicateO+REPLACE(@FullObjectPredicateSO,N'[s].[name]',N'[sch].[name]')+N'
'+@StatisticsPredicateSt+N'
 AND (COALESCE([sp].[modification_counter]*100.0/NULLIF([sp].[rows],0),0)>=@pMinModPct)
 AND (@pMinAge=0 OR [sp].[last_updated] IS NULL OR DATEDIFF(DAY,[sp].[last_updated],SYSDATETIME())>=@pMinAge)
ORDER BY COALESCE([sp].[modification_counter]*100.0/NULLIF([sp].[rows],0),0) DESC,[sp].[last_updated]
OPTION (MAXDOP 1, RECOMPILE);
IF @pWithIncremental=1
BEGIN
 BEGIN TRY
  INSERT #Statistics_Incremental
  SELECT TOP (@pMaxRows) @pDbName,[base].[SchemaName],[base].[ObjectName],[base].[StatisticsId],[base].[StatisticsName],[ip].[partition_number],[ip].[last_updated],[ip].[rows],[ip].[rows_sampled],[ip].[steps],[ip].[unfiltered_rows],[ip].[modification_counter],
         CONVERT(decimal(19,4),[ip].[modification_counter]*100.0/NULLIF([ip].[rows],0))
  FROM #Statistics_Result AS [base]
  CROSS APPLY sys.dm_db_incremental_stats_properties([base].[ObjectId],[base].[StatisticsId]) AS [ip]
  WHERE [base].[DatabaseName]=@pDbName
    AND [base].[IsIncremental]=1
  ORDER BY [ip].[modification_counter]*100.0/NULLIF([ip].[rows],0) DESC;
 END TRY
 BEGIN CATCH
  INSERT #Statistics_DatabaseStatus VALUES(@pDbName,
   CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN ''DENIED_PERMISSION'' WHEN ERROR_NUMBER()=1222 THEN ''TIMEOUT'' WHEN ERROR_NUMBER() IN (207,208,4121) THEN ''UNAVAILABLE_OBJECT'' ELSE ''ERROR_HANDLED'' END,
   1,0,N''SELECT auf Statistikspalten oder geeignete Rolle/Eigentum'',ERROR_NUMBER(),ERROR_MESSAGE(),N''Quelle STATS_INCREMENTAL fehlgeschlagen; Basisstatistiken bleiben erhalten.'');
 END CATCH;
END;';
    EXEC [sys].[sp_executesql]
          @Sql
        , N'@pDbName sysname,@pMaxRows bigint,@pSchemaLike nvarchar(256),@pObjectLike nvarchar(256),@pStatsLike nvarchar(256),@pMinModPct decimal(9,2),@pMinAge int,@pWithIncremental bit,@pCurrentReplicaRole varchar(40),@pCurrentReplicaRoleStatus varchar(40),@pReplicaMetadataStatus varchar(40)'
        , @pDbName=@DbName
        , @pMaxRows=@EffectiveMaxZeilen
        , @pSchemaLike=@SchemaNameLike
        , @pObjectLike=@ObjectNameLike
        , @pStatsLike=@StatisticsNameLike
        , @pMinModPct=@MinModificationPercent
        , @pMinAge=@MinAlterTage
        , @pWithIncremental=@MitIncrementellenDetails
        , @pCurrentReplicaRole=@CurrentReplicaRole
        , @pCurrentReplicaRoleStatus=@CurrentReplicaRoleStatus
        , @pReplicaMetadataStatus=@ReplicaMetadataCapabilityStatus;

    SET @Rows=
        (SELECT COUNT_BIG(*)
         FROM [#Statistics_Result]
         WHERE [DatabaseName]=@DbName);

    INSERT [#Statistics_DatabaseStatus]
    VALUES
    (
          @DbName
        , CASE
              WHEN @Rows>0
               AND @ReplicaMetadataCapabilityStatus IN
                   ('AVAILABLE','UNAVAILABLE_VERSION','UNAVAILABLE_COLUMNS')
               AND @CurrentReplicaRoleStatus IN ('AVAILABLE','NOT_APPLICABLE')
               AND NOT EXISTS
                   (
                       SELECT 1
                       FROM [#Statistics_Result]
                       WHERE [DatabaseName]=@DbName
                         AND [ReplicaMetadataStatus]='PARTIAL_METADATA'
                   )
                  THEN 'AVAILABLE'
              ELSE 'AVAILABLE_LIMITED'
          END
        , CONVERT(bit,CASE
              WHEN @Rows>0
               AND @ReplicaMetadataCapabilityStatus IN
                   ('AVAILABLE','UNAVAILABLE_VERSION','UNAVAILABLE_COLUMNS')
               AND @CurrentReplicaRoleStatus IN ('AVAILABLE','NOT_APPLICABLE')
               AND NOT EXISTS
                   (
                       SELECT 1
                       FROM [#Statistics_Result]
                       WHERE [DatabaseName]=@DbName
                         AND [ReplicaMetadataStatus]='PARTIAL_METADATA'
                   )
                  THEN 0
              ELSE 1
          END)
        , @Rows
        , N'SELECT [auf] [Statistikspalten] oder [Eigentum]/[db_owner]/[db_ddladmin]/[sysadmin]'
        , NULL
        , NULL
        , CONCAT
          (
              N'ReplicaMetadataStatus=',@ReplicaMetadataCapabilityStatus,
              N'; CurrentReplicaRoleStatus=',@CurrentReplicaRoleStatus,
              N'; RowScope=',CASE WHEN @Rows=0
                                  THEN N'EMPTY_OR_RESTRICTED'
                                  ELSE N'VISIBLE' END,
              N'; NULL-Werte können fehlende Sichtbarkeit, nicht aufgezeichnete Herkunft oder noch nicht materialisierte Statistiken bedeuten.'
          )
    );
   END TRY
   BEGIN CATCH
    INSERT [#Statistics_DatabaseStatus] VALUES(@DbName,CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,1,0,N'SELECT [auf] [Statistikspalten] oder [geeignete] [Rolle]/[Eigentum]',ERROR_NUMBER(),ERROR_MESSAGE(),N'Statistikfehler isoliert.');
   END CATCH;
   FETCH NEXT FROM dbcur INTO @DbId,@DbName;
  END; CLOSE dbcur; DEALLOCATE dbcur;
  IF NOT EXISTS(SELECT 1 FROM [#Statistics_DatabaseStatus]) INSERT [#Statistics_DatabaseStatus] VALUES(@DatabaseName,'DATABASE_UNAVAILABLE',1,0,NULL,NULL,N'Keine sichtbare Online-Zieldatenbank gefunden.',NULL);
 END;

    IF @@LOCK_TIMEOUT<>@OriginalLockTimeout
        THROW 51012,N'USP_Statistics hat den äußeren LOCK_TIMEOUT verändert.',1;

    IF @OverallStatus<>'AVAILABLE' SET @IsPartial=1;

    SELECT @TotalRows=(SELECT COUNT_BIG(*) FROM [#Statistics_Result])+(SELECT COUNT_BIG(*) FROM [#Statistics_Incremental]);

    IF @OverallStatus = 'AVAILABLE'
    BEGIN
        IF EXISTS (SELECT 1 FROM [#Statistics_DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
        BEGIN
            SET @OverallStatus = CASE WHEN @TotalRows > 0 THEN 'PARTIAL' ELSE (SELECT TOP (1) [StatusCode] FROM [#Statistics_DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE') ORDER BY [DatabaseName]) END;
            SET @IsPartial = 1;
        END
        ELSE IF EXISTS (SELECT 1 FROM [#Statistics_DatabaseStatus] WHERE [StatusCode] IN ('AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
        BEGIN
            SET @OverallStatus = CASE WHEN @TotalRows > 0 THEN 'AVAILABLE_LIMITED' ELSE 'SKIPPED' END;
            SET @IsPartial = 1;
        END;
    END;

    IF @PrintMeldungen = 1 AND @OverallStatus <> 'AVAILABLE'
        BEGIN
    SET @MonitorPrintMessage = FORMATMESSAGE(N'WARNUNG %s: %s', @OverallStatus, COALESCE(@ErrorMessage, @Detail, N'Teilergebnis oder eingeschränkte Sicht'));
    RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
END;

    IF @ResultSetArtNormalisiert<>'NONE' BEGIN
        SELECT @ModuleName [ModuleName],@CollectionTimeUtc [CollectionTimeUtc],@OverallStatus [StatusCode],@IsPartial [IsPartial],@TotalRows [RowCount],@ErrorNumber [ErrorNumber],@ErrorMessage [ErrorMessage],@Detail [Detail];
        SELECT [DatabaseName],[StatusCode],[IsPartial],[RowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[Detail] FROM [#Statistics_DatabaseStatus] ORDER BY [DatabaseName];
        IF @ResultSetArtNormalisiert='RAW'
            SELECT * FROM [#Statistics_Result] ORDER BY [ModificationPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[StatisticsName];
        ELSE
            SELECT N'Statistik' [Ergebnis],[r].* FROM [#Statistics_Result] [r] ORDER BY [ModificationPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[StatisticsName];

        IF @MitIncrementellenDetails=1
        BEGIN
            IF @ResultSetArtNormalisiert='RAW'
                SELECT * FROM [#Statistics_Incremental] ORDER BY [ModificationPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[PartitionNumber];
            ELSE
                SELECT N'Inkrementelle Statistikpartition' [Ergebnis],[i].* FROM [#Statistics_Incremental] [i] ORDER BY [ModificationPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[PartitionNumber];
        END;
    END;
    IF @JsonErzeugen=1 BEGIN
        DECLARE @JsonMeta nvarchar(max)=(SELECT @ModuleName [resultName],2 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@OverallStatus [statusCode],@IsPartial [isPartial],@TotalRows [rowCount] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @JsonDatabaseStatus nvarchar(max)=(SELECT * FROM [#Statistics_DatabaseStatus] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonData1 nvarchar(max)=(SELECT * FROM [#Statistics_Result] ORDER BY [ModificationPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[StatisticsName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonIncremental nvarchar(max)=(SELECT * FROM [#Statistics_Incremental] ORDER BY [ModificationPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[PartitionNumber] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@JsonMeta,N'{}'),N',"statistics":',COALESCE(@JsonData1,N'[]'),N',"incrementalStatistics":',COALESCE(@JsonIncremental,N'[]'),N',"databaseStatus":',COALESCE(@JsonDatabaseStatus,N'[]'),N'}');
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#Statistics_Result'
            , @ResultLabel=N'Statistics'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#Statistics_Result'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

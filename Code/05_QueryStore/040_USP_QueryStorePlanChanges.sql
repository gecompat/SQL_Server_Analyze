USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_QueryStorePlanChanges
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Liefert Abfragen mit mehreren Query-Store-Plänen und begrenzt
               die globale Ausgabe über lokale N+1-Kandidaten. Ein optionaler
               Filter beschränkt die Referenzdatenbanken.
Ausgabe      : RAW/CONSOLE/NONE sowie JSON mit meta, queries, plans, warnings.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames          nvarchar(max)  = NULL
    , @QueryStoreDatabaseNamePattern    nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @ReferencedDatabaseNames          nvarchar(max)  = NULL
    , @ReferencedDatabaseNamePattern    nvarchar(4000) = NULL
    , @QueryId                          bigint         = NULL
    , @QueryHash                        binary(8)      = NULL
    , @VonUtc                           datetime2(7)   = NULL
    , @NurMehrerePlaene                 bit            = 1
    , @MitPlanXml                       bit            = 0
    , @AnalyseModus                     varchar(16)    = 'TOP'
    , @MaxZeilen                        int            = 100
    , @MaxSqlTextZeichen                int            = 4000
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
AS
BEGIN
 SET NOCOUNT ON;SET @Json=NULL;SET @AnalyseModus=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'TOP'))));
 DECLARE @Out varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),@Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen>0 THEN @MaxZeilen ELSE 0 END,@Local bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen<2147483647 THEN CONVERT(bigint,@MaxZeilen)+1 ELSE @MaxZeilen END;
 CREATE TABLE [#QueryStorePlanChanges_SummaryExport]([QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[QueryId] bigint,[QueryHash] binary(8),[ObjectId] bigint NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanCount] bigint,[ForcedPlanCount] bigint,[DistinctPlanHashCount] bigint,[FirstCompileTimeUtc] datetimeoffset NULL,[LastCompileTimeUtc] datetimeoffset NULL,[LastExecutionTimeUtc] datetimeoffset NULL,[TotalCompiles] bigint,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    DECLARE @TableResultRequested bit = CASE WHEN @Out = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @Out = 'CONSOLE' THEN 1 ELSE 0 END;
    CREATE TABLE [#QueryStorePlanChanges_ResultTableMap]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1
    BEGIN
      DECLARE @TablePreflightStatus varchar(40),@TablePreflightError nvarchar(2048);
      EXEC [monitor].[InternalPrepareResultTables]
            @ResultTablesJson=@ResultTablesJson,@AllowedResultNames=N'queries|plans'
          , @MappingTable=N'#QueryStorePlanChanges_ResultTableMap'
          , @StatusCode=@TablePreflightStatus OUTPUT,@ErrorMessage=@TablePreflightError OUTPUT
          , @ThrowOnError=1;
    END;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @Out = 'NONE';
 IF @Hilfe=1
 BEGIN
        PRINT N'monitor.USP_QueryStorePlanChanges';
        PRINT N'monitor.USP_QueryStorePlanChanges wertet gespeicherte Query-Store-Metadaten sichtbarer Benutzerdatenbanken aus. Ausgabe sind historische Pläne und Querydaten, kein aktueller Laufzeitplan und kein Performance-/Gesundheitsnachweis.';
        PRINT N'@Hilfe=1 überspringt normale Parameterprüfung und Datenbankanalyse; SQL-Typbindung und die vorangestellte TABLE-Zielprüfung bleiben erforderlich. @Json wird beim Eintritt auf NULL gesetzt.';
        PRINT N'Die folgenden Validierungsregeln gelten im normalen Analysepfad. @Hilfe=1 beendet vorher; SQL-Typbindung und die vorangestellten Mappingprüfungen bleiben aktiv. Zeichenparameter unterliegen bereits bei der Bindung ihrer deklarierten SQL-Typbreite.';
        PRINT N'@QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'''' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N''[ExampleDatabase]|[OtherDatabase]''; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen.';
        PRINT N'@QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.';
        PRINT N'@ReferencedDatabaseNames nvarchar(max); Default: NULL. ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; | trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein; Teile 3/4 werden nicht gesondert geprüft. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus. Der Filter wirkt auf die Summaryaggregation; der Planexport enthält anschließend alle gespeicherten Pläne der ausgewählten Datenbank-/Querykeys.';
        PRINT N'@ReferencedDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert. Der Filter wirkt auf die Summaryaggregation; der Planexport enthält anschließend alle gespeicherten Pläne der ausgewählten Datenbank-/Querykeys.';
        PRINT N'@QueryId bigint; Default: NULL. Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch.';
        PRINT N'@QueryHash binary(8); Default: NULL. Ausgelassen/NULL: kein Hashfilter. Acht Byte als Binärwert übergeben, zum Beispiel 0x0123456789ABCDEF; exakter Vergleich ohne zusätzliche Werte- oder Existenzprüfung. SQL-Typkonvertierungen erfolgen vor dem Procedurekörper.';
        PRINT N'@VonUtc datetime2(7); Default: NULL. NULL ohne Zeitfilter. Sonst skalarer UTC-Grenzzeitpunkt; Query qualifiziert, wenn ein Plan last_compile_start_time >= Wert ODER last_execution_time >= Wert erfüllt. Keine relative Stunde/obere Grenze; Plandetails bleiben zeitlich unbeschränkt. Als datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T12:00:00.0000000 in UTC übergeben; keine Zeitzonenumrechnung. Keine Leerzeichenfolge als Datum verwenden.';
        PRINT N'@NurMehrerePlaene bit; Default: 1. 1 und NULL verlangen HAVING COUNT_BIG(*)>1; NULL wird nicht coalesced. 0 schließt auch Queries mit genau einem Plan ein. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. Gezählt werden Planzeilen nach Zeit-/Referenzfilter der Summaryaggregation; nicht zwingend gleichzeitig aktive oder verschiedene Planhashes.';
        PRINT N'@MitPlanXml bit; Default: 0. 1 fordert gespeicherte XML für alle lokal gesammelten Pläne an, parst/exportiert vor globalem Querylimit; Deep-Prüfung. 0 unterdrückt Ausgabe/Parsing mit NOT_REQUESTED. NULL unterdrückt ebenfalls, Status PENDING. Referenzfilter können XML unabhängig vom Export lesen. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. Gespeicherter historischer Showplan, kein aktueller Laufzeitplan. Ungültiges XML bleibt als Rohtext mit Fehler-/Partialhinweis erhalten.';
        PRINT N'@AnalyseModus varchar(16); Default: ''TOP''. Ausgelassen/NULL: TOP. Nach äußerem Trimmen von U+0020 und Großschreibungsnormalisierung sind genau TOP und VOLL erlaubt: TOP verwendet lokale N+1-Querykandidaten und das globale Querylimit; VOLL aktiviert QUERY_STORE_DEEP, hebt @MaxZeilen aber nicht auf. Leer, nur Leerzeichen oder andere Werte sind ungültig. Deep wird außerdem durch @MitPlanXml=1, ein normalisiertes Zeilenlimit über 1000 (einschließlich NULL/0 unbegrenzt) oder einen nicht-NULL Referenzfilter aktiviert; @VonUtc allein aktiviert Deep nicht.';
        PRINT N'@MaxZeilen int; Default: 100. Positiv: globales Limit an Query-Summaryzeilen. NULL/0 unbegrenzt; negativ ungültig. Je Quelle lokale N+1-Kandidaten (bei int.MaxValue N ohne Überlauf), danach globale Sortierung LastExecutionTimeUtc DESC, LastCompileTimeUtc DESC; gleiche Sortwerte nicht eindeutig. Limit zählt Queries, nicht Pläne; alle Pläne der Querykeys bleiben. >1000 sowie NULL/0 unbegrenzt aktivieren Deep.';
        PRINT N'@MaxSqlTextZeichen int; Default: 4000. Begrenzt nur QuerySqlText in Unicode-Zeichen/SC-Codepoints, nicht Grapheme und nicht Plan-XML. NULL/0 vollständig; negativ ungültig. Projektion/Truncationbewertung vor globaler Querybegrenzung.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Ausgelassen: CONSOLE. Nach U+0020-Trim/Großschreibung sind genau vier Werte erlaubt: RAW liefert vier Resultsets (Metadaten, Querysummaries, Plandetails, Warnungen); CONSOLE liefert die Querysummary und einen Formatierungshinweis; TABLE schreibt nur die angeforderte nichtleere Teilmenge queries/plans in geprüfte lokale Temp-Ziele; NONE unterdrückt normale Fachresultsets. JSON ist unabhängig. NULL, leer, nur Leerzeichen und andere Werte sind im normalen Analysepfad ungültig. Der TABLE-Preflight läuft bereits vor Hilfe und Fachvalidierung.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE. Nichtleerer Wert außerhalb TABLE löst vor Hilfe/Normalvalidierung Fehler aus. NULL/leer sind im TABLE-Aufruf ungültig. Erforderlich ist ein nichtleeres JSON-Objekt mit einem oder beiden Schlüsseln queries/plans; Werte sind unterschiedliche, vorhandene, leere lokale #Temp-Tabellen mit genau einer beliebigen Seed-Spalte. Resultsetnamen werden exakt und case-sensitiv geprüft; doppelte Namen, doppelte Ziele, unbekannte Namen, Nicht-Stringwerte, Zielnamen >116 Zeichen, ##-Ziele und Namen mit #Monitor-Präfix sind ungültig. Eine Seed-Zeile ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das jeweilige Ergebnisschema. queries bezeichnet die begrenzte Querysummary, plans alle gespeicherten Pläne ihrer ausgewählten Querykeys.';
        PRINT N'@JsonErzeugen bit; Default: 0. 1 erzeugt JSON unabhängig von ResultSetArt. 0 oder NULL deaktiviert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. Die JSON-Objekte heißen meta (Metadaten), queries (begrenzte Summaries), plans (alle Pläne ausgewählter Querykeys), warnings (Warnungen).';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter für JSON mit meta, queries, plans und warnings; beim Eintritt NULL, nur bei @JsonErzeugen=1 befüllt. Zum Empfang eine nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Ausgelassen wird kein Ergebnis an den Aufrufer zurückgegeben; ein Eingabewert wird überschrieben. Bei Hilfe bleibt NULL; bei einem ungefangenen THROW besteht keine Zusage einer OUTPUT-Rückübertragung. Summaries sind global begrenzt, Pläne vollständig je ausgewähltem Querykey.';
        PRINT N'@PrintMeldungen bit; Default: 1. ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.';
        PRINT N'@Hilfe bit; Default: 0. 1 gibt Hilfe aus und kehrt vor normaler Parameterprüfung/Datenbankverarbeitung zurück. Typbindung bleibt erforderlich; frühe TABLE-Mapping-Prüfung läuft vorher. 0/NULL normale Ausführung. @Json beim Eintritt auch für Hilfe NULL; PrintMeldungen steuert Hilfe-PRINTs nicht. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.';
        PRINT N'EXEC [monitor].[USP_QueryStorePlanChanges]
      @Hilfe = 1;';
        PRINT N'DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

EXEC [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames = N''[ExampleDatabase]''
    , @VonUtc = @ExampleVonUtc
    , @MaxZeilen = 100
    , @ResultSetArt = ''RAW'';';
        PRINT N'DECLARE @ExampleJson nvarchar(max);
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

EXEC [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames = N''[ExampleDatabase]''
    , @VonUtc = @ExampleVonUtc
    , @ResultSetArt = ''NONE''
    , @JsonErzeugen = 1
    , @Json = @ExampleJson OUTPUT;

SELECT @ExampleJson AS [Json];';
        PRINT N'CREATE TABLE [#QueryStorePlanChanges_HelpQueries]([Seed] int NULL);
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

BEGIN TRY
    EXEC [monitor].[USP_QueryStorePlanChanges]
          @QueryStoreDatabaseNames = N''[ExampleDatabase]''
        , @VonUtc = @ExampleVonUtc
        , @MaxZeilen = 100
        , @ResultSetArt = ''TABLE''
        , @ResultTablesJson = N''{"queries":"#QueryStorePlanChanges_HelpQueries"}'';

    SELECT * FROM [#QueryStorePlanChanges_HelpQueries];
    DROP TABLE IF EXISTS [#QueryStorePlanChanges_HelpQueries];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#QueryStorePlanChanges_HelpQueries];
    THROW;
END CATCH;';
  RETURN;
 END;
 DECLARE @Now datetime2(3)=SYSUTCDATETIME(),@Status varchar(40)='AVAILABLE',@Partial bit=0,@Error nvarchar(2048)=NULL,@Cross bit=0,@Allowed bit=1,@Db sysname,@Compat tinyint,@Sql nvarchar(max),@Count bigint=0,@HasMore bit=0,@Msg nvarchar(2048),@RefMode varchar(8),@RefValue nvarchar(4000),@RefFlags varchar(8),@RefValid bit,@RefPredicate nvarchar(max)=N'';
 SELECT @RefMode=[PatternMode],@RefValue=[PatternValue],@RefFlags=[RegexFlags],@RefValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ReferencedDatabaseNamePattern);
 CREATE TABLE [#QueryStorePlanChanges_DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsSystemDatabase] bit,[RequestedOrdinal] int);
 CREATE TABLE [#QueryStorePlanChanges_Summary]([QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryId] bigint,[QueryHash] binary(8),[ObjectId] bigint NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanCount] bigint,[ForcedPlanCount] bigint,[DistinctPlanHashCount] bigint,[FirstCompileTimeUtc] datetimeoffset NULL,[LastCompileTimeUtc] datetimeoffset NULL,[LastExecutionTimeUtc] datetimeoffset NULL,[TotalCompiles] bigint,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 CREATE TABLE [#QueryStorePlanChanges_Plans]([QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryId] bigint,[PlanId] bigint,[QueryPlanHash] binary(8),[EngineVersion] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS,[CompatibilityLevel] smallint,[IsParallelPlan] bit,[IsForcedPlan] bit,[PlanForcingTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[ForceFailureCount] bigint,[LastForceFailureReason] int,[LastForceFailureReasonDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[CountCompiles] bigint,[InitialCompileStartTimeUtc] datetimeoffset,[LastCompileStartTimeUtc] datetimeoffset,[LastExecutionTimeUtc] datetimeoffset,[AverageCompileDurationMs] decimal(38,3),[LastCompileDurationMs] decimal(38,3),[QueryPlanTextFallback] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanSourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanSourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanCapturedAtUtc] datetime2(3) NULL,[QueryPlanStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QueryPlanCharacters] bigint NULL,[QueryPlanBytes] bigint NULL,[QueryPlan] xml NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 CREATE TABLE [#QueryStorePlanChanges_Errors]([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS);
 IF @AnalyseModus NOT IN('TOP','VOLL') OR @MaxZeilen<0 OR @MaxSqlTextZeichen < 0 OR @Out NOT IN('RAW','CONSOLE','NONE') OR @RefValid=0 OR (@ReferencedDatabaseNames IS NOT NULL AND @ReferencedDatabaseNamePattern IS NOT NULL) OR (@ReferencedDatabaseNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@ReferencedDatabaseNames) WHERE [IsValid]=0)) BEGIN SET @Status='INVALID_PARAMETER';SET @Error=N'Ungültiger Parameter.';END;
 IF @Status='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@QueryStoreDatabaseNames,@SystemdatenbankenEinbeziehen=0,@DatabaseNamePattern=@QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed,@AnalysisClass='QUERY_STORE_CURRENT',@StatusCode=@Status OUTPUT,@ErrorMessage=@Error OUTPUT,@CrossDatabaseRequested=@Cross OUTPUT,@CandidateTable=N'#QueryStorePlanChanges_DatabaseCandidates';
 IF @Status='AVAILABLE' AND (@AnalyseModus='VOLL' OR @MitPlanXml=1 OR @Limit>1000 OR @ReferencedDatabaseNames IS NOT NULL OR @ReferencedDatabaseNamePattern IS NOT NULL) EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='QUERY_STORE_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@Status OUTPUT,@ErrorMessage=@Error OUTPUT;
 IF @ReferencedDatabaseNames IS NOT NULL SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) JOIN ' + QUOTENAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID())) + N'.[monitor].[TVF_ParseSqlNameList](@ReferencedNames) [rf] ON [rf].[IsValid]=1 AND [rf].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS=PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1) COLLATE SQL_Latin1_General_CP1_CS_AS)';
 ELSE IF @RefMode='LIKE' SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) WHERE PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1) COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @RefValue COLLATE SQL_Latin1_General_CP1_CS_AS)';
 ELSE IF @RefMode IN('REGEX','REGEXI') SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) WHERE REGEXP_LIKE(PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1),@RefValue,@RefFlags))';
 SET LOCK_TIMEOUT 0;
 IF @Status='AVAILABLE'
 BEGIN DECLARE [c] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName],[CompatibilityLevel] FROM [#QueryStorePlanChanges_DatabaseCandidates] ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];OPEN [c];FETCH NEXT FROM [c] INTO @Db,@Compat;WHILE @@FETCH_STATUS=0
 BEGIN
  IF @RefMode IN('REGEX','REGEXI') AND (TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17 OR @Compat<170) BEGIN INSERT [#QueryStorePlanChanges_Errors] VALUES(@Db,'UNAVAILABLE_FEATURE',NULL,N'Regex benötigt SQL Server 2025 und Compatibility Level 170.');SET @Partial=1;END
  ELSE BEGIN TRY
   SET @Sql=N'USE '+QUOTENAME(@Db)+N';IF EXISTS(SELECT 1 FROM [sys].[database_query_store_options] WITH (NOLOCK) WHERE [actual_state] IN(1,2,4))
BEGIN
;WITH [Q] AS
(
 SELECT [q].[query_id],[q].[query_hash],[q].[object_id],COUNT_BIG(*) [PlanCount],SUM(CONVERT(bigint,[p].[is_forced_plan])) [ForcedCount],COUNT(DISTINCT CONVERT(varchar(18),[p].[query_plan_hash],1)) [DistinctHashCount],MIN([p].[initial_compile_start_time]) [FirstCompile],MAX([p].[last_compile_start_time]) [LastCompile],MAX([p].[last_execution_time]) [LastExecution],SUM([p].[count_compiles]) [TotalCompiles],[qt].[query_sql_text]
 FROM [sys].[query_store_query] [q] WITH (NOLOCK) JOIN [sys].[query_store_query_text] [qt] WITH (NOLOCK) ON [qt].[query_text_id]=[q].[query_text_id] JOIN [sys].[query_store_plan] [p] WITH (NOLOCK) ON [p].[query_id]=[q].[query_id]
 WHERE (@QueryId IS NULL OR [q].[query_id]=@QueryId) AND (@QueryHash IS NULL OR [q].[query_hash]=@QueryHash) AND (@SinceUtc IS NULL OR [p].[last_compile_start_time]>=@SinceUtc OR [p].[last_execution_time]>=@SinceUtc)'+@RefPredicate+N'
 GROUP BY [q].[query_id],[q].[query_hash],[q].[object_id],[qt].[query_sql_text] HAVING @OnlyMultiple=0 OR COUNT_BIG(*)>1
)
INSERT [#QueryStorePlanChanges_Summary] ([QueryStoreDatabaseId],[QueryStoreDatabaseName],[QueryId],[QueryHash],[ObjectId],[ObjectName],[PlanCount],[ForcedPlanCount],[DistinctPlanHashCount],[FirstCompileTimeUtc],[LastCompileTimeUtc],[LastExecutionTimeUtc],[TotalCompiles],[QuerySqlText]) SELECT TOP(@TopRows) DB_ID(),(SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()),[query_id],[query_hash],[Q].[object_id],CASE WHEN [Q].[object_id]>0 THEN QUOTENAME([os].[name])+N''.''+QUOTENAME([oo].[name]) END,[PlanCount],[ForcedCount],[DistinctHashCount],[FirstCompile],[LastCompile],[LastExecution],[TotalCompiles],[query_sql_text] FROM [Q] LEFT JOIN [sys].[objects] AS [oo] WITH (NOLOCK) ON [oo].[object_id]=[Q].[object_id] LEFT JOIN [sys].[schemas] AS [os] WITH (NOLOCK) ON [os].[schema_id]=[oo].[schema_id] ORDER BY [LastExecution] DESC,[LastCompile] DESC;
INSERT [#QueryStorePlanChanges_Plans] ([QueryStoreDatabaseId],[QueryStoreDatabaseName],[QueryId],[PlanId],[QueryPlanHash],[EngineVersion],[CompatibilityLevel],[IsParallelPlan],[IsForcedPlan],[PlanForcingTypeDesc],[ForceFailureCount],[LastForceFailureReason],[LastForceFailureReasonDesc],[CountCompiles],[InitialCompileStartTimeUtc],[LastCompileStartTimeUtc],[LastExecutionTimeUtc],[AverageCompileDurationMs],[LastCompileDurationMs],[QueryPlanTextFallback]) SELECT DB_ID(),(SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()),[p].[query_id],[p].[plan_id],[p].[query_plan_hash],[p].[engine_version],[p].[compatibility_level],[p].[is_parallel_plan],[p].[is_forced_plan],[p].[plan_forcing_type_desc],[p].[force_failure_count],[p].[last_force_failure_reason],[p].[last_force_failure_reason_desc],[p].[count_compiles],[p].[initial_compile_start_time],[p].[last_compile_start_time],[p].[last_execution_time],CONVERT(decimal(38,3),[p].[avg_compile_duration]/1000.0),CONVERT(decimal(38,3),[p].[last_compile_duration]/1000.0),CASE WHEN @IncludePlan=1 THEN [p].[query_plan] END FROM [sys].[query_store_plan] [p] WITH (NOLOCK) JOIN [#QueryStorePlanChanges_Summary] [s] ON [s].[QueryStoreDatabaseId]=DB_ID() AND [s].[QueryId]=[p].[query_id];
END;';
   EXEC [sys].[sp_executesql] @Sql,N'@QueryId bigint,@QueryHash binary(8),@SinceUtc datetime2(7),@OnlyMultiple bit,@TopRows bigint,@TextChars int,@IncludePlan bit,@ReferencedNames nvarchar(max),@RefValue nvarchar(4000),@RefFlags varchar(8)',@QueryId,@QueryHash,@VonUtc,@NurMehrerePlaene,@Local,@MaxSqlTextZeichen,@MitPlanXml,@ReferencedDatabaseNames,@RefValue,@RefFlags;
  END TRY BEGIN CATCH INSERT [#QueryStorePlanChanges_Errors] VALUES(@Db,CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,ERROR_NUMBER(),ERROR_MESSAGE());SET @Partial=1;IF @PrintMeldungen=1 BEGIN SET @Msg=FORMATMESSAGE(N'WARNUNG USP_QueryStorePlanChanges [%s]: %s',@Db,ERROR_MESSAGE());RAISERROR(N'%s',10,1,@Msg) WITH NOWAIT;END;END CATCH;
  FETCH NEXT FROM [c] INTO @Db,@Compat;END;CLOSE [c];DEALLOCATE [c];END;
 UPDATE [s] SET [SourceType]='QUERY_STORE',[SourceObject]=N'sys.query_store_query|sys.query_store_plan|sys.query_store_query_text',[CapturedAtUtc]=@Now,[EvidenceScope]='DATABASE_QUERY',[QuerySqlTextCharacters]=[p].[OriginalCharacters],[QuerySqlTextBytes]=[p].[OriginalBytes],[QuerySqlTextIsTruncated]=[p].[IsTruncated],[QuerySqlText]=[p].[ProjectedValue],[EvidenceLimit]=N'Query-Store-Kompilierungs- und Ausführungsmetadaten; keine aktuelle Einzelausführung.' FROM [#QueryStorePlanChanges_Summary] [s] CROSS APPLY [monitor].[TVF_ProjectUnicodeText]([s].[QuerySqlText],@MaxSqlTextZeichen) [p];
 UPDATE [p] SET [PlanSourceType]='QUERY_STORE',[PlanSourceObject]=N'sys.query_store_plan',[PlanCapturedAtUtc]=@Now,[QueryPlanStatus]=CASE WHEN @MitPlanXml=0 THEN 'NOT_REQUESTED' ELSE 'PENDING' END,[EvidenceLimit]=N'Gespeicherter Query-Store-Plan; kein aktueller Laufzeitplan.' FROM [#QueryStorePlanChanges_Plans] [p];
 DECLARE @PlanDb int,@PlanQuery bigint,@PlanIdLocal bigint,@PlanText nvarchar(max),@PlanXml xml,@PlanStatus varchar(40),@PlanErr int,@PlanMsg nvarchar(2048);DECLARE [pc] CURSOR LOCAL FAST_FORWARD FOR SELECT [QueryStoreDatabaseId],[QueryId],[PlanId],[QueryPlanTextFallback] FROM [#QueryStorePlanChanges_Plans] WHERE @MitPlanXml=1;OPEN [pc];FETCH NEXT FROM [pc] INTO @PlanDb,@PlanQuery,@PlanIdLocal,@PlanText;WHILE @@FETCH_STATUS=0 BEGIN EXEC [monitor].[InternalParseXmlText] @XmlText=@PlanText,@XmlValue=@PlanXml OUTPUT,@StatusCode=@PlanStatus OUTPUT,@ErrorNumber=@PlanErr OUTPUT,@ErrorMessage=@PlanMsg OUTPUT;UPDATE [#QueryStorePlanChanges_Plans] SET [QueryPlanStatus]=@PlanStatus,[QueryPlanCharacters]=CASE WHEN @PlanText IS NULL THEN NULL ELSE CONVERT(bigint,LEN((@PlanText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1) END,[QueryPlanBytes]=CONVERT(bigint,DATALENGTH(@PlanText)),[QueryPlan]=@PlanXml,[QueryPlanTextFallback]=CASE WHEN @PlanStatus IN('AVAILABLE','XML_EMPTY','SOURCE_NULL') THEN NULL ELSE @PlanText END WHERE [QueryStoreDatabaseId]=@PlanDb AND [QueryId]=@PlanQuery AND [PlanId]=@PlanIdLocal;IF @PlanStatus IN('XML_INVALID','XML_UNAVAILABLE_LIMIT') BEGIN INSERT [#QueryStorePlanChanges_Errors] VALUES((SELECT TOP(1) [QueryStoreDatabaseName] FROM [#QueryStorePlanChanges_Plans] WHERE [QueryStoreDatabaseId]=@PlanDb),@PlanStatus,@PlanErr,@PlanMsg);SET @Partial=1;END;FETCH NEXT FROM [pc] INTO @PlanDb,@PlanQuery,@PlanIdLocal,@PlanText;END;CLOSE [pc];DEALLOCATE [pc];
 DECLARE @TruncatedValueCount bigint=0,@LargestRequiredCharacters bigint=NULL;SELECT @TruncatedValueCount=COUNT_BIG(*),@LargestRequiredCharacters=MAX([QuerySqlTextCharacters]) FROM [#QueryStorePlanChanges_Summary] WHERE [QuerySqlTextIsTruncated]=1;EXEC [monitor].[InternalEmitTruncationWarning] @TruncatedValueCount=@TruncatedValueCount,@ParameterName=N'@MaxSqlTextZeichen',@ParameterValue=@MaxSqlTextZeichen,@LargestRequiredCharacters=@LargestRequiredCharacters,@PrintMeldungen=@PrintMeldungen;
 SELECT @Count=COUNT_BIG(*) FROM [#QueryStorePlanChanges_Summary];SET @HasMore=CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @Count>@Limit THEN 1 ELSE 0 END);IF @Partial=1 AND @Status='AVAILABLE' SET @Status='AVAILABLE_LIMITED';
 INSERT [#QueryStorePlanChanges_SummaryExport] SELECT TOP(@Limit) * FROM [#QueryStorePlanChanges_Summary] ORDER BY [LastExecutionTimeUtc] DESC,[LastCompileTimeUtc] DESC;
 DELETE [p] FROM [#QueryStorePlanChanges_Plans] [p] WHERE NOT EXISTS(SELECT 1 FROM (SELECT [QueryStoreDatabaseId],[QueryId] FROM [#QueryStorePlanChanges_SummaryExport]) [k] WHERE [k].[QueryStoreDatabaseId]=[p].[QueryStoreDatabaseId] AND [k].[QueryId]=[p].[QueryId]);
 IF @Out<>'NONE' BEGIN SELECT N'USP_QueryStorePlanChanges' [ModuleName],@Now [CollectionTimeUtc],@Status [StatusCode],@Partial [IsPartial],CASE WHEN @Count>@Limit THEN @Limit ELSE @Count END [ReturnedRowCount],@HasMore [HasMoreRows],@Error [ErrorMessage];IF @Out='RAW' BEGIN SELECT * FROM [#QueryStorePlanChanges_SummaryExport] ORDER BY [LastExecutionTimeUtc] DESC,[LastCompileTimeUtc] DESC;SELECT * FROM [#QueryStorePlanChanges_Plans] ORDER BY [QueryStoreDatabaseName],[QueryId],[LastExecutionTimeUtc] DESC,[PlanId];END ELSE BEGIN SELECT N'Query-Store Planwechsel' [Ergebnis],[QueryStoreDatabaseName] [Query-Store-Datenbank],[QueryId] [Query],[PlanCount] [Pläne],[DistinctPlanHashCount] [verschiedene Plan-Hashes],[ForcedPlanCount] [erzwungene Pläne],[LastExecutionTimeUtc] [letzte Ausführung],[QueryStoreDatabaseName] [Quelle],[QuerySqlText] [SQL-Text] FROM [#QueryStorePlanChanges_SummaryExport] ORDER BY [LastExecutionTimeUtc] DESC,[LastCompileTimeUtc] DESC;SELECT N'Query-Store Plan' [Ergebnis],[QueryStoreDatabaseName] [Query-Store-Datenbank],[QueryId] [Query],[PlanId] [Plan],[IsForcedPlan] [erzwungen],[LastExecutionTimeUtc] [letzte Ausführung],[AverageCompileDurationMs] [Compile Ø ms],[QueryPlan] [Plan-XML] FROM [#QueryStorePlanChanges_Plans] ORDER BY [QueryStoreDatabaseName],[QueryId],[LastExecutionTimeUtc] DESC,[PlanId];END;SELECT * FROM [#QueryStorePlanChanges_Errors] ORDER BY [DatabaseName];END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'QueryStorePlanChanges' [resultName],2 [schemaVersion],@Now [generatedAtUtc],@Status [statusCode],@MaxZeilen [requestedMaxRows],CASE WHEN @Count>@Limit THEN @Limit ELSE @Count END [returnedRows],@HasMore [hasMoreRows] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@Queries nvarchar(max)=(SELECT * FROM [#QueryStorePlanChanges_SummaryExport] ORDER BY [LastExecutionTimeUtc] DESC,[LastCompileTimeUtc] DESC FOR JSON PATH,INCLUDE_NULL_VALUES),@Plans nvarchar(max)=(SELECT [QueryStoreDatabaseId],[QueryStoreDatabaseName],[QueryId],[PlanId],[QueryPlanHash],[EngineVersion],[CompatibilityLevel],[IsParallelPlan],[IsForcedPlan],[PlanForcingTypeDesc],[ForceFailureCount],[LastForceFailureReason],[LastForceFailureReasonDesc],[CountCompiles],[InitialCompileStartTimeUtc],[LastCompileStartTimeUtc],[LastExecutionTimeUtc],[AverageCompileDurationMs],[LastCompileDurationMs],[QueryPlanTextFallback],[PlanSourceType],[PlanSourceObject],[PlanCapturedAtUtc],[QueryPlanStatus],[QueryPlanCharacters],[QueryPlanBytes],CONVERT(nvarchar(max),[QueryPlan]) [QueryPlan],[EvidenceLimit] FROM [#QueryStorePlanChanges_Plans] ORDER BY [QueryStoreDatabaseName],[QueryId],[LastExecutionTimeUtc] DESC,[PlanId] FOR JSON PATH,INCLUDE_NULL_VALUES),@Warnings nvarchar(max)=(SELECT * FROM [#QueryStorePlanChanges_Errors] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"queries":',COALESCE(@Queries,N'[]'),N',"plans":',COALESCE(@Plans,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#QueryStorePlanChanges_SummaryExport'
            , @ResultLabel=N'QueryStorePlanChanges'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        DECLARE @TableResultName sysname,@TableTarget sysname,@TableSource sysname;
        DECLARE [TableResultCursor] CURSOR LOCAL FAST_FORWARD FOR
          SELECT [ResultName],[TargetTable] FROM [#QueryStorePlanChanges_ResultTableMap] ORDER BY [ResultName];
        OPEN [TableResultCursor];FETCH NEXT FROM [TableResultCursor] INTO @TableResultName,@TableTarget;
        WHILE @@FETCH_STATUS=0
        BEGIN
          SET @TableSource=CASE @TableResultName WHEN N'queries' THEN N'#QueryStorePlanChanges_SummaryExport' WHEN N'plans' THEN N'#QueryStorePlanChanges_Plans' END;
          EXEC [monitor].[InternalWriteResultTable] @SourceTable=@TableSource,@TargetTable=@TableTarget,@ThrowOnError=1;
          FETCH NEXT FROM [TableResultCursor] INTO @TableResultName,@TableTarget;
        END;
        CLOSE [TableResultCursor];DEALLOCATE [TableResultCursor];
    END;
END;
GO

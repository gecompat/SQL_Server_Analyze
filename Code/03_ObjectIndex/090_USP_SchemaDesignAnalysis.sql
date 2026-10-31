USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_SchemaDesignAnalysis
Version      : 1.0.0
Stand        : 2026-07-17
Zweck        : Leitet katalogbasierte Schema-/Designfindings je ausgewählter Datenbank ab.
Datenquellen : sys.foreign_keys, sys.foreign_key_columns,
               sys.check_constraints, sys.indexes, sys.index_columns,
               sys.identity_columns, sys.sequences, sys.schemas
               und sys.tables.
Prüfungen    : deaktivierte/nicht vertrauenswürdige Constraints,
               fehlender FK-Stützindex, hypothetische/deaktivierte und exakt
               gleiche Indizes sowie Identity-/Sequence-Wertebereich.
Grenzen      : Kein DDL und keine automatische Lösch-/Indexempfehlung. Nutzung,
               Workload, Filtersemantik und Änderungsrisiko separat prüfen.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_SchemaDesignAnalysis]
      @DatabaseNames                nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen bit            = 0
    , @DatabaseNamePattern          nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @IdentityWarnPercent          decimal(5,2)   = 80.00
    , @MaxZeilen                    int            = 1000
    , @ResultSetArt                 varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                 bit            = 0
    , @Json                         nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen               bit            = 1
    , @Hilfe                        bit            = 0
    , @StatusCodeOut                varchar(40)    = NULL OUTPUT
    , @IsPartialOut                 bit            = NULL OUTPUT
    , @ErrorNumberOut               int            = NULL OUTPUT
    , @ErrorMessageOut              nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
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
        PRINT N'monitor.USP_SchemaDesignAnalysis';
        PRINT N'Die Procedure liest katalogbasierte Schema-, Constraint-, Index-, Identity- und Sequence-Metadaten ausgewählter Datenbanken; sie erstellt oder ändert keine Constraints und Indizes.';
        PRINT N'Der Aufruf delegiert die Pfadprüfung als CATALOG_DEEP. Dessen aktueller Katalogeintrag sieht ein Gruppengate vor; @HighImpactConfirmed=1 bestätigt nur dieses Gate und ersetzt weder aktuelle Freigabe noch enge Scopewahl.';
        PRINT N'@Hilfe=1 beendet die Analyse nach den vorangestellten Ausgabeparameterprüfungen. @Json wird bei jedem Aufruf zuerst auf NULL gesetzt; die übrigen OUTPUT-Werte werden im Hilfezweig nicht zugewiesen.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Eingabe ist eine Pipe-Liste einteiliger Datenbanknamen. | trennt nur außerhalb von [ ]; ]] maskiert ] innerhalb einer Klammerung. Äußere U+0020-Elementleerzeichen werden entfernt. Jedes Rohsegment darf höchstens 4000 UTF-16-Codeeinheiten haben; leere Elemente, fehlerhafte Klammerung, ungültige PARSENAME-Namen über 128 Zeichen und case-sensitive Duplikate machen die Liste ungültig. NULL, leer oder nur äußere U+0020-Leerzeichen bedeutet keine exakte Einschränkung; ausgelassen = NULL. Eine wirksame Liste ist exklusiv zu @DatabaseNamePattern. Ungültige Liste ergibt INVALID_PARAMETER. Namen ohne passende Kandidaten erzeugen Warnungen statt eines Filterfehlers. Ohne wirksame Liste werden alle sichtbaren, online befindlichen Benutzerdatenbanken berücksichtigt, vorbehaltlich Systemdatenbank-Opt-in und Pattern.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. Bit-Eingabe 0 oder 1; 0 schließt master, tempdb, model und msdb aus, 1 lässt sie in die Kandidatenauswahl zu. NULL ist INVALID_PARAMETER; ausgelassen = 0. Wirkt auch auf Warnungen zu explizit angeforderten, ausgeschlossenen Systemdatenbanken. SQL Server bindet numerische 0 als bit 0 und von 0 verschiedene konvertierbare Zahlen als bit 1.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Ein LIKE-Muster (einschließlich SQL-LIKE-Wildcards %, _ und [...]) oder ein Pattern mit Präfix like:, regex: oder regexi:. Präfixerkennung ist ohne Beachtung der Großschreibung; äußere U+0020-Leerzeichen werden entfernt, der Rest nach Präfixentfernung nicht nochmals getrimmt. LIKE verwendet SQL_Latin1_General_CP1_CS_AS. regex: verwendet Flag c, regexi: Flag i; Regex-Syntax wird nicht vorgeprüft. Regex erfordert SQL Server 2025 (Major-Version 17) und Compatibility Level mindestens 170 der Installationsdatenbank; andernfalls UNAVAILABLE_FEATURE. Regex filtert Kandidaten nach deren Ermittlung. NULL/ausgelassen bedeutet kein Pattern. Leer, nur U+0020-Leerzeichen oder ein leeres Präfixergebnis ist ungültig; jedes nicht-NULL Pattern zusammen mit einer wirksamen @DatabaseNames-Liste ist INVALID_PARAMETER.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. Bit-Eingabe 0 oder 1. Die Procedure prüft den Analysepfad CATALOG_DEEP; dessen Katalogeintrag hat RequiresGroupGate=1. Bei einem tatsächlich aktivierten, gruppengeschützten Pfad führt 0 zum Status HIGH_IMPACT_CONFIRMATION_REQUIRED; 1 bestätigt nur diese Anforderung und erteilt keine Freigabe. Die aktuelle Pfadfreigabe wird separat geprüft und kann DENIED_GROUP ergeben. NULL ist INVALID_PARAMETER, auch wenn kein Pfad freigegeben ist; ausgelassen = 0. SQL Server bindet numerische 0 als bit 0 und von 0 verschiedene konvertierbare Zahlen als bit 1.';
        PRINT N'@IdentityWarnPercent decimal(5,2); Default: 80.00. Prozentschwelle nach Bindung an decimal(5,2), zulässiger Bereich 0 bis 100; außerhalb INVALID_PARAMETER. Ausgelassen = 80.00. Identity-UsedPercent nutzt den vollen Typbereich: tinyint 0–255, smallint −32768–32767, int −2147483648–2147483647, bigint −9223372036854775808–9223372036854775807. Bei Inkrement größer oder gleich 0 wird ab Typminimum, bei negativem Inkrement ab Typmaximum gemessen. Seed, Reseed und fachlicher Wertebereich sind darin nicht berücksichtigt. Sequence-UsedPercent nutzt dagegen die konfigurierten minimum_value und maximum_value mit gleicher Richtungsunterscheidung. Findings entstehen ab UsedPercent >= Schwelle; is_exhausted=1 erzeugt ein Sequence-Finding unabhängig von der Schwelle. HIGH gilt ab 95 Prozent oder bei erschöpfter Sequence, sonst MEDIUM. NULL passiert die Bereichsprüfung: Identity-Schwellenvergleiche liefern damit kein Finding; erschöpfte Sequences können weiterhin Findings liefern. Leertext muss vor Ausführung numerisch konvertierbar sein; NULL deaktiviert keine anderen Designregeln.';
        PRINT N'@MaxZeilen int; Default: 1000. Ganzzahliger Zeilenhöchstwert im int-Bereich: 0 bis 2147483647. NULL oder 0 bedeutet unbegrenzt; ausgelassen = 1000; negative Werte sind INVALID_PARAMETER. Nur RAW und JSON begrenzen Findings nach Priorität (HIGH, MEDIUM, übrige), DatabaseId, SchemaName, ObjectName und FindingCode. CONSOLE zeigt und TABLE schreibt alle Findings; NONE gibt keine Resultsets aus. Warnungen werden durch diesen Grenzwert nicht beschränkt. Das TOP-Limit begrenzt weder Katalogjoins, Findingregeln noch vorgelagerte Quellarbeit.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach LTRIM/RTRIM von U+0020-Leerzeichen und UPPER ausgewertet. Zulässig sind RAW (Status-Resultset, auf @MaxZeilen begrenzte Findings, danach alle Warnungen), CONSOLE (ein lesbares Resultset mit allen Findings, bei leerer Quelle eine verständliche Leerzeile; kein separates Status- oder Warnungsresultset), TABLE (schreibt alle Findings in das erforderliche Ziel und gibt kein Resultset aus) und NONE (keine Resultsets). NULL, Leerwert und andere Texte sind INVALID_PARAMETER; ausgelassen = CONSOLE. @JsonErzeugen wirkt unabhängig davon. TABLE benötigt ein gültiges @ResultTablesJson-Mapping; außerhalb TABLE löst ein nach Trim von U+0020 nicht leerer Mappingwert THROW 51011 aus.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Für TABLE ein JSON-Objekt mit genau dem Schlüssel findings und einem Stringwert für den Namen einer vorhandenen lokalen #Temp-Tabelle, z. B. N''{"findings":"#SchemaDesignAnalysis_HelpExample"}''. Das Ziel muss leer sein und genau eine Seed-Spalte besitzen; das Mapping darf keine fremden Namen/Ziele enthalten. NULL oder nach Trim von U+0020 leere Eingabe eignet sich nur außerhalb TABLE; bei TABLE schlägt der Preflight fehl. Bei RAW, CONSOLE oder NONE werden NULL/nach Trim von U+0020 leere Werte ignoriert; ein nicht leerer Wert löst Fehler 51011 aus. Ausgelassen = NULL.';
        PRINT N'@JsonErzeugen bit; Default: 0. Bit-Schalter: 1 erzeugt unabhängig von @ResultSetArt ein JSON-Dokument in @Json; 0 erzeugt keines. NULL wird nicht als ungültig abgewiesen und erfüllt die IF-Bedingung nicht; ausgelassen = 0. Leere Texteingabe ist nicht sinnvoll; eine explizite Nicht-Bit-Angabe muss bereits bei Parameterbindung in bit konvertierbar sein. SQL Server bindet numerische 0 als bit 0 und von 0 verschiedene konvertierbare Zahlen als bit 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Reiner OUTPUT-Parameter; Eingabewert ist nicht maßgeblich. Wird bei jedem Aufruf vor der Hilfe- und Parameterprüfung auf NULL gesetzt. Wenn @JsonErzeugen=1, enthält er ein Objekt mit meta, findings und warnings; Findings unterliegen @MaxZeilen, Warnings nicht. Sonst bleibt er NULL. Zum Empfang eine nvarchar(max)-Variable mit OUTPUT binden; bei Auslassen existiert kein empfangbarer Aufrufwert.';
        PRINT N'@PrintMeldungen bit; Default: 1. Unbenutzter bit-Parameter: 0, 1 und NULL beeinflussen weder Meldungen noch Resultsets; ausgelassen = 1. Konvertierbare numerische 0 bleibt bit 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Nicht konvertierbare Eingaben scheitern bei der Parameterbindung.';
        PRINT N'@Hilfe bit; Default: 0. Bit-Eingabe. 1 gibt die Hilfe per PRINT aus und kehrt vor Analyse, regulären Statuszuweisungen und Resultsetausgabe zurück; allerdings laufen vorher Modus-/Mappingprüfungen und @Json wird bereits auf NULL gesetzt. Andere OUTPUT-Parameter werden im Hilfezweig nicht zugewiesen. NULL wird nicht gesondert geprüft und nimmt wie 0 den normalen Analysepfad; ausgelassen = 0. 0 führt den normalen Pfad aus. Leere Texteingabe ist nicht sinnvoll; explizite Werte müssen bei Bindung in bit konvertierbar sein. SQL Server bindet numerische 0 als bit 0 und von 0 verschiedene konvertierbare Zahlen als bit 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang, etwa @StatusCodeOut=@Status OUTPUT mit einer varchar(40)-Variablen. Werte: AVAILABLE (Kandidatenlauf ohne Findings und Teilwarnungen), AVAILABLE_WITH_FINDING (Findings ohne Teilwarnungen), AVAILABLE_LIMITED (Warnungen oder Teilergebnisse), DATABASE_UNAVAILABLE (keine Kandidatendatenbank), INVALID_PARAMETER (ungültige lokale oder vorbereitete Eingabe), HIGH_IMPACT_CONFIRMATION_REQUIRED (erforderliche Bestätigung fehlt), DENIED_GROUP (Pfad nicht freigegeben), UNAVAILABLE_FEATURE (benötigtes Feature fehlt), INTERNAL_ERROR (interner Vorbereitungsvertrag verletzt). DENIED_PERMISSION und ERROR_HANDLED gehören zu datenbankweisen Warnzeilen und sind keine StatusCodeOut-Werte. Die reguläre Zuweisung erfolgt nach Vorbereitung und Statusaggregation. Hilfe lässt die Variable unverändert; ein früher THROW erreicht die Zuweisung nicht. Ausgelassen beziehungsweise NULL als Anfangswert ist zulässig; ohne OUTPUT-Bindung wird kein Wert empfangen.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang, etwa @IsPartialOut=@Partial OUTPUT mit einer bit-Variablen. 1 kennzeichnet lokale Parametervalidierungsfehler, Kandidatenwarnungen, datenbankweise Fehler oder fehlende Kandidatendatenbanken; im normalen Lauf ohne Teilfehler gilt 0. Ein abgewiesener delegierter Vorbereitungspfad, etwa HIGH_IMPACT_CONFIRMATION_REQUIRED oder DENIED_GROUP, kann 0 belassen, obwohl keine Analyse lief. Der Wert ist daher kein allgemeines Erfolgs- oder Vollständigkeitsbit. Die reguläre Zuweisung erfolgt erst nach Aggregation; Hilfe lässt die Variable unverändert und ein früher THROW umgeht die Zuweisung. Ausgelassen beziehungsweise NULL als Anfangswert ist zulässig; ohne OUTPUT-Bindung kein Empfang.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang, etwa @ErrorNumberOut=@ErrorNumber OUTPUT mit einer int-Variablen. Im aktuellen normalen Lauf bleibt die lokale Fehlernummer stets NULL; datenbankweise Fehlernummern stehen separat in warnings. Zuweisung am Ende der Vorbereitung und Aggregation, vor der Ausgabe. Hilfe lässt die Variable unverändert; ein früher THROW erreicht die Zuweisung nicht. Ausgelassen oder NULL als Anfangswert ist zulässig; ohne OUTPUT-Bindung kein Empfang.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang, etwa @ErrorMessageOut=@ErrorMessage OUTPUT mit einer nvarchar(2048)-Variablen. Der normale Lauf liefert die globale Vorbereitungs-/Parameterfehlermeldung oder NULL bei erfolgreicher Vorbereitung; datenbankweise Meldungen stehen separat in warnings. Zuweisung nach Vorbereitung und Aggregation, vor Ausgabe. Hilfe lässt die Variable unverändert; ein früher THROW erreicht die Zuweisung nicht. Ausgelassen oder NULL als Anfangswert ist zulässig; ohne OUTPUT-Bindung kein Empfang.';
        PRINT N'EXEC [monitor].[USP_SchemaDesignAnalysis] @DatabaseNames=N''[ExampleDatabase]'',@HighImpactConfirmed=1,@ResultSetArt=''RAW'';';
        PRINT N'DECLARE @SchemaDesignJson nvarchar(max); EXEC [monitor].[USP_SchemaDesignAnalysis] @DatabaseNames=N''[ExampleDatabase]'',@HighImpactConfirmed=1,@JsonErzeugen=1,@Json=@SchemaDesignJson OUTPUT; SELECT @SchemaDesignJson AS [SchemaDesignJson];';
        PRINT N'EXEC [monitor].[USP_SchemaDesignAnalysis] @Hilfe=1;';



        RETURN;
    END;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @CrossDatabaseRequested bit = 0;
    DECLARE @Db sysname;
    DECLARE @Sql nvarchar(max);

    CREATE TABLE [#SchemaDesignAnalysis_DatabaseCandidates]
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
    CREATE TABLE [#SchemaDesignAnalysis_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#SchemaDesignAnalysis_Findings]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RelatedObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MetricValue] decimal(38,4) NULL
        , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SchemaDesignAnalysis_Errors]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @MaxZeilen < 0
       OR @IdentityWarnPercent < 0 OR @IdentityWarnPercent > 100
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER', @IsPartial = 1,
               @ErrorMessage = N'Ungültiger Datenbank-, Grenzwert-, Zeilen- oder Ausgabeparameter.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames = @DatabaseNames
            , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

            , @AnalysisClass = 'CATALOG_DEEP'
            , @StatusCode = @StatusCode OUTPUT
            , @ErrorMessage = @ErrorMessage OUTPUT
            , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT,@CandidateTable=N'#SchemaDesignAnalysis_DatabaseCandidates',@WarningTable=N'#SchemaDesignAnalysis_DatabaseCandidateWarnings';
    END;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        DECLARE [database_cursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseName] FROM [#SchemaDesignAnalysis_DatabaseCandidates]
            ORDER BY COALESCE([RequestedOrdinal], [DatabaseId]), [DatabaseId];
        OPEN [database_cursor];
        FETCH NEXT FROM [database_cursor] INTO @Db;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                SET @Sql = N'USE ' + QUOTENAME(@Db) + N';
DECLARE @DatabaseId int = DB_ID();
DECLARE @DatabaseName sysname = (SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID());

INSERT [#SchemaDesignAnalysis_Findings]
SELECT @DatabaseId, @DatabaseName,
       CASE WHEN [fk].[is_disabled] = 1 THEN ''FOREIGN_KEY_DISABLED'' ELSE ''FOREIGN_KEY_NOT_TRUSTED'' END,
       CASE WHEN [fk].[is_disabled] = 1 THEN ''HIGH'' ELSE ''MEDIUM'' END,
       N''FOREIGN_KEY'', [s].[name], [t].[name], [fk].[name], NULL,
       CONCAT(N''is_disabled='', [fk].[is_disabled], N''; is_not_trusted='', [fk].[is_not_trusted]),
       N''Aktivierung beziehungsweise WITH CHECK erfordert fachliche Prüfung und ist nicht Bestandteil dieser Analyse.''
FROM [sys].[foreign_keys] AS [fk] WITH (NOLOCK)
JOIN [sys].[tables] AS [t] WITH (NOLOCK) ON [t].[object_id] = [fk].[parent_object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id] = [t].[schema_id]
WHERE [fk].[is_disabled] = 1 OR [fk].[is_not_trusted] = 1;

INSERT [#SchemaDesignAnalysis_Findings]
SELECT @DatabaseId, @DatabaseName,
       CASE WHEN [cc].[is_disabled] = 1 THEN ''CHECK_CONSTRAINT_DISABLED'' ELSE ''CHECK_CONSTRAINT_NOT_TRUSTED'' END,
       CASE WHEN [cc].[is_disabled] = 1 THEN ''HIGH'' ELSE ''MEDIUM'' END,
       N''CHECK_CONSTRAINT'', [s].[name], [t].[name], [cc].[name], NULL,
       CONCAT(N''is_disabled='', [cc].[is_disabled], N''; is_not_trusted='', [cc].[is_not_trusted]),
       N''Constraintdefinition und Datenqualität vor einer Änderung separat validieren.''
FROM [sys].[check_constraints] AS [cc] WITH (NOLOCK)
JOIN [sys].[tables] AS [t] WITH (NOLOCK) ON [t].[object_id] = [cc].[parent_object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id] = [t].[schema_id]
WHERE [cc].[is_disabled] = 1 OR [cc].[is_not_trusted] = 1;

INSERT [#SchemaDesignAnalysis_Findings]
SELECT @DatabaseId, @DatabaseName, ''FOREIGN_KEY_WITHOUT_SUPPORTING_INDEX'', ''MEDIUM'',
       N''FOREIGN_KEY'', [s].[name], [t].[name], [fk].[name],
       CONVERT(decimal(38,4), COUNT_BIG([fkc].[constraint_column_id])),
       N''Kein aktiver Index beginnt in gleicher Reihenfolge mit allen referenzierenden FK-Spalten.'',
       N''Workload, Selektivität, Schreibkosten und ein eventuell breiterer geeigneter Index müssen separat geprüft werden.''
FROM [sys].[foreign_keys] AS [fk] WITH (NOLOCK)
JOIN [sys].[tables] AS [t] WITH (NOLOCK) ON [t].[object_id] = [fk].[parent_object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id] = [t].[schema_id]
JOIN [sys].[foreign_key_columns] AS [fkc] WITH (NOLOCK) ON [fkc].[constraint_object_id] = [fk].[object_id]
WHERE [fk].[is_disabled] = 0
  AND NOT EXISTS
  (
      SELECT 1
      FROM [sys].[indexes] AS [i] WITH (NOLOCK)
      WHERE [i].[object_id] = [fk].[parent_object_id]
        AND [i].[index_id] > 0 AND [i].[is_disabled] = 0 AND [i].[is_hypothetical] = 0
        AND [i].[has_filter] = 0
        AND NOT EXISTS
        (
            SELECT 1
            FROM [sys].[foreign_key_columns] AS [fc] WITH (NOLOCK)
            LEFT JOIN [sys].[index_columns] AS [ic] WITH (NOLOCK)
              ON [ic].[object_id] = [i].[object_id] AND [ic].[index_id] = [i].[index_id]
             AND [ic].[key_ordinal] = [fc].[constraint_column_id]
            WHERE [fc].[constraint_object_id] = [fk].[object_id]
              AND ([ic].[column_id] IS NULL OR [ic].[column_id] <> [fc].[parent_column_id])
        )
  )
GROUP BY [s].[name], [t].[name], [fk].[name];

INSERT [#SchemaDesignAnalysis_Findings]
SELECT @DatabaseId, @DatabaseName,
       CASE WHEN [i].[is_hypothetical] = 1 THEN ''HYPOTHETICAL_INDEX'' ELSE ''INDEX_DISABLED'' END,
       CASE WHEN [i].[is_hypothetical] = 1 THEN ''INFO'' ELSE ''MEDIUM'' END,
       N''INDEX'', [s].[name], [t].[name], [i].[name], NULL,
       CONCAT(N''index_id='', [i].[index_id]),
       N''Nicht automatisch löschen oder aktivieren; Ursprung, Abhängigkeiten und Wartungsabsicht prüfen.''
FROM [sys].[indexes] AS [i] WITH (NOLOCK)
JOIN [sys].[tables] AS [t] WITH (NOLOCK) ON [t].[object_id] = [i].[object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id] = [t].[schema_id]
WHERE [i].[index_id] > 0 AND ([i].[is_hypothetical] = 1 OR [i].[is_disabled] = 1);

INSERT [#SchemaDesignAnalysis_Findings]
SELECT @DatabaseId, @DatabaseName, ''EXACT_INDEX_DEFINITION_DUPLICATE'', ''MEDIUM'',
       N''INDEX'', [s].[name], [t].[name], CONCAT([i1].[name], N'' | '', [i2].[name]), NULL,
       N''Schlüssel-/Include-Spalten, Sortierung, Eindeutigkeit und Filterdefinition sind katalogseitig gleich.'',
       N''Nutzung, Abhängigkeiten, Constraints, Kompression und betriebliche Anforderungen vor einer Änderung prüfen.''
FROM [sys].[indexes] AS [i1] WITH (NOLOCK)
JOIN [sys].[indexes] AS [i2] WITH (NOLOCK)
  ON [i2].[object_id] = [i1].[object_id] AND [i2].[index_id] > [i1].[index_id]
JOIN [sys].[tables] AS [t] WITH (NOLOCK) ON [t].[object_id] = [i1].[object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id] = [t].[schema_id]
WHERE [i1].[index_id] > 0
  AND [i1].[type] IN (1, 2) AND [i2].[type] = [i1].[type]
  AND [i1].[is_hypothetical] = 0 AND [i2].[is_hypothetical] = 0
  AND [i1].[is_disabled] = 0 AND [i2].[is_disabled] = 0
  AND [i1].[is_unique] = [i2].[is_unique]
  AND COALESCE([i1].[filter_definition], N'''') = COALESCE([i2].[filter_definition], N'''')
  AND NOT EXISTS
  (
      SELECT [column_id], [key_ordinal], [is_descending_key], [is_included_column]
      FROM [sys].[index_columns] WITH (NOLOCK) WHERE [object_id] = [i1].[object_id] AND [index_id] = [i1].[index_id]
      EXCEPT
      SELECT [column_id], [key_ordinal], [is_descending_key], [is_included_column]
      FROM [sys].[index_columns] WITH (NOLOCK) WHERE [object_id] = [i2].[object_id] AND [index_id] = [i2].[index_id]
  )
  AND NOT EXISTS
  (
      SELECT [column_id], [key_ordinal], [is_descending_key], [is_included_column]
      FROM [sys].[index_columns] WITH (NOLOCK) WHERE [object_id] = [i2].[object_id] AND [index_id] = [i2].[index_id]
      EXCEPT
      SELECT [column_id], [key_ordinal], [is_descending_key], [is_included_column]
      FROM [sys].[index_columns] WITH (NOLOCK) WHERE [object_id] = [i1].[object_id] AND [index_id] = [i1].[index_id]
  );

;WITH [IdentityRange] AS
(
    SELECT [ic].[object_id], [ic].[name], [ic].[system_type_id],
           TRY_CONVERT(decimal(38,0), [ic].[last_value]) AS [CurrentValue],
           TRY_CONVERT(decimal(38,0), [ic].[increment_value]) AS [IncrementValue],
           CONVERT(decimal(38,0), CASE [ic].[system_type_id]
                    WHEN 48 THEN 0 WHEN 52 THEN -32768 WHEN 56 THEN -2147483648
                    WHEN 127 THEN -9223372036854775808 END) AS [TypeMin],
           CONVERT(decimal(38,0), CASE [ic].[system_type_id]
                    WHEN 48 THEN 255 WHEN 52 THEN 32767 WHEN 56 THEN 2147483647
                    WHEN 127 THEN 9223372036854775807 END) AS [TypeMax]
    FROM [sys].[identity_columns] AS [ic] WITH (NOLOCK)
    WHERE [ic].[system_type_id] IN (48, 52, 56, 127) AND [ic].[last_value] IS NOT NULL
),
[IdentityUsage] AS
(
    SELECT [r].*, CONVERT(decimal(38,4),
           CASE WHEN [r].[IncrementValue] >= 0
                THEN 100.0 * ([r].[CurrentValue] - [r].[TypeMin]) / NULLIF([r].[TypeMax] - [r].[TypeMin], 0)
                ELSE 100.0 * ([r].[TypeMax] - [r].[CurrentValue]) / NULLIF([r].[TypeMax] - [r].[TypeMin], 0) END) AS [UsedPercent]
    FROM [IdentityRange] AS [r]
)
INSERT [#SchemaDesignAnalysis_Findings]
SELECT @DatabaseId, @DatabaseName, ''IDENTITY_TYPE_RANGE_USAGE'',
       CASE WHEN [u].[UsedPercent] >= 95 THEN ''HIGH'' ELSE ''MEDIUM'' END,
       N''IDENTITY_COLUMN'', [s].[name], [t].[name], [u].[name], [u].[UsedPercent],
       CONCAT(N''Typwertebereich genutzt: '', CONVERT(nvarchar(60), [u].[UsedPercent]), N'' Prozent.''),
       N''Berechnung nutzt den vollständigen numerischen Typwertebereich; Seed, Reseed, Zyklen und Fachsemantik separat prüfen.''
FROM [IdentityUsage] AS [u]
JOIN [sys].[tables] AS [t] WITH (NOLOCK) ON [t].[object_id] = [u].[object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id] = [t].[schema_id]
WHERE [u].[UsedPercent] >= @IdentityWarnPercent;

INSERT [#SchemaDesignAnalysis_Findings]
SELECT @DatabaseId, @DatabaseName, ''SEQUENCE_RANGE_USAGE'',
       CASE WHEN [q].[is_exhausted] = 1 OR [x].[UsedPercent] >= 95 THEN ''HIGH'' ELSE ''MEDIUM'' END,
       N''SEQUENCE'', [s].[name], [q].[name], NULL, [x].[UsedPercent],
       CONCAT(N''is_exhausted='', [q].[is_exhausted], N''; Typwertebereich genutzt: '',
              CONVERT(nvarchar(60), [x].[UsedPercent]), N'' Prozent.''),
       N''Cache, CYCLE, Sprünge und fachlich erlaubte Wertebereiche separat prüfen.''
FROM [sys].[sequences] AS [q] WITH (NOLOCK)
JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id] = [q].[schema_id]
CROSS APPLY
(
    SELECT CONVERT(decimal(38,4),
           CASE WHEN TRY_CONVERT(decimal(38,0), [q].[increment]) >= 0
                THEN 100.0 * (TRY_CONVERT(decimal(38,0), [q].[current_value]) - TRY_CONVERT(decimal(38,0), [q].[minimum_value]))
                   / NULLIF(TRY_CONVERT(decimal(38,0), [q].[maximum_value]) - TRY_CONVERT(decimal(38,0), [q].[minimum_value]), 0)
                ELSE 100.0 * (TRY_CONVERT(decimal(38,0), [q].[maximum_value]) - TRY_CONVERT(decimal(38,0), [q].[current_value]))
                   / NULLIF(TRY_CONVERT(decimal(38,0), [q].[maximum_value]) - TRY_CONVERT(decimal(38,0), [q].[minimum_value]), 0) END) AS [UsedPercent]
) AS [x]
WHERE [q].[is_exhausted] = 1 OR [x].[UsedPercent] >= @IdentityWarnPercent;';

                EXEC [sys].[sp_executesql]
                      @Sql
                    , N'@IdentityWarnPercent decimal(5,2)'
                    , @IdentityWarnPercent = @IdentityWarnPercent;
            END TRY
            BEGIN CATCH
                INSERT [#SchemaDesignAnalysis_Errors]
                VALUES (@Db,
                        CASE WHEN ERROR_NUMBER() IN (229, 262, 297, 300, 371, 916)
                             THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
                        ERROR_NUMBER(), ERROR_MESSAGE());
                SET @IsPartial = 1;
            END CATCH;

            FETCH NEXT FROM [database_cursor] INTO @Db;
        END;
        CLOSE [database_cursor];
        DEALLOCATE [database_cursor];

        INSERT [#SchemaDesignAnalysis_Errors]
        SELECT [RequestedName], [StatusCode], NULL, [ErrorMessage]
        FROM [#SchemaDesignAnalysis_DatabaseCandidateWarnings];
        IF EXISTS (SELECT 1 FROM [#SchemaDesignAnalysis_Errors]) SET @IsPartial = 1;

        IF NOT EXISTS (SELECT 1 FROM [#SchemaDesignAnalysis_DatabaseCandidates])
            SELECT @StatusCode = 'DATABASE_UNAVAILABLE', @IsPartial = 1;
        ELSE IF @IsPartial = 1
            SET @StatusCode = 'AVAILABLE_LIMITED';
        ELSE IF EXISTS (SELECT 1 FROM [#SchemaDesignAnalysis_Findings])
            SET @StatusCode = 'AVAILABLE_WITH_FINDING';
    END;

    SELECT @StatusCodeOut = @StatusCode, @IsPartialOut = @IsPartial,
           @ErrorNumberOut = @ErrorNumber, @ErrorMessageOut = @ErrorMessage;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
            (SELECT N'SchemaDesignAnalysis' AS [resultName], 1 AS [schemaVersion],
                    @Now AS [generatedAtUtc], @StatusCode AS [statusCode], @IsPartial AS [isPartial],
                    @IdentityWarnPercent AS [identityWarnPercent]
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        DECLARE @FindingsJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#SchemaDesignAnalysis_Findings]
             ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
                      [DatabaseId], [SchemaName], [ObjectName], [FindingCode]
             FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max) =
            (SELECT * FROM [#SchemaDesignAnalysis_Errors] ORDER BY [DatabaseName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        SET @Json = CONCAT(N'{"meta":', COALESCE(@MetaJson, N'{}'),
                           N',"findings":', COALESCE(@FindingsJson, N'[]'),
                           N',"warnings":', COALESCE(@WarningsJson, N'[]'), N'}');
    END;

    IF @OutputMode = 'RAW'
    BEGIN
        SELECT N'USP_SchemaDesignAnalysis' AS [ModuleName], @Now AS [CollectionTimeUtc],
               @StatusCode AS [StatusCode], @IsPartial AS [IsPartial],
               @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage],
               N'Read-only; Befunde sind Prüfaufträge, keine DDL-Anweisungen.' AS [Detail];
        SELECT TOP (@Limit) * FROM [#SchemaDesignAnalysis_Findings]
        ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
                 [DatabaseId], [SchemaName], [ObjectName], [FindingCode];
        SELECT * FROM [#SchemaDesignAnalysis_Errors] ORDER BY [DatabaseName];
    END
    ELSE IF @OutputMode = 'CONSOLE'
    BEGIN
        SELECT N'Schema- und Designkorrektheit' AS [Ergebnis], @Now AS [Stand_UTC],
               @StatusCode AS [Status], (SELECT COUNT_BIG(*) FROM [#SchemaDesignAnalysis_Findings]) AS [Befunde],
               @ErrorMessage AS [Hinweis];
        SELECT TOP (@Limit) N'Schema-Befund' AS [Ergebnis], [DatabaseName] AS [Datenbank],
               [SchemaName] AS [Schema], [ObjectName] AS [Objekt],
               [RelatedObjectName] AS [Bezug], [FindingCode] AS [Befund],
               [Severity] AS [Prioritaet], [MetricValue] AS [Messwert],
               [Evidence] AS [Evidenz], [EvidenceLimit] AS [Grenze]
        FROM [#SchemaDesignAnalysis_Findings]
        ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
                 [DatabaseId], [SchemaName], [ObjectName], [FindingCode];
        SELECT N'Schema-Warnung' AS [Ergebnis], [DatabaseName] AS [Datenbank],
               [StatusCode] AS [Status], [ErrorNumber] AS [Fehlernummer], [ErrorMessage] AS [Meldung]
        FROM [#SchemaDesignAnalysis_Errors] ORDER BY [DatabaseName];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#SchemaDesignAnalysis_Findings'
            , @ResultLabel=N'SchemaDesignAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#SchemaDesignAnalysis_Findings'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

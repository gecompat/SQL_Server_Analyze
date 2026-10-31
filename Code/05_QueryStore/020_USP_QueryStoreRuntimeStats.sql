USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_QueryStoreRuntimeStats
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Liefert Query-Store-Runtime-Statistiken aus einer oder mehreren
               Query-Store-Quelldatenbanken mit exaktem globalem Top-N.
SQL-Version  : SQL Server 2019 oder neuer.
Quelldatenbanken: @QueryStoreDatabaseNames bracket-aware Pipe-Liste;
               NULL/N'' = alle zulässigen Datenbanken.
Referenzfilter: @ReferencedDatabaseNames beziehungsweise
               @ReferencedDatabaseNamePattern filtern auf Datenbanken, die in
               gespeicherten Showplans referenziert werden.
Pattern      : LIKE (Default/like:), regex:, regexi:. Regex benötigt SQL Server
               2025 und Compatibility Level 170 der jeweils ausgewerteten DB.
Top-N        : Je Quelldatenbank werden höchstens N+1 lokale Kandidaten gelesen;
               anschließend wird daraus das exakte globale Top N gebildet.
Ausgabe      : RAW, CONSOLE, TABLE oder NONE; optionales JSON mit meta, runtimeStats
               und warnings.
Änderungen   : 2.0.0 - Quell-/Referenzdatenbanken getrennt, @AlleDatenbanken
                         entfernt, globale Top-N-Logik, Pattern und JSON.
               1.0.0 - Erstfassung Phase 4.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_QueryStoreRuntimeStats]
      @QueryStoreDatabaseNames          nvarchar(max)  = NULL
    , @QueryStoreDatabaseNamePattern    nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @ReferencedDatabaseNames          nvarchar(max)  = NULL
    , @ReferencedDatabaseNamePattern    nvarchar(4000) = NULL
    , @QueryId                          bigint         = NULL
    , @QueryHash                        binary(8)      = NULL
    , @TextPattern                      nvarchar(4000) = NULL
    , @VonUtc                           datetime2(7)   = NULL
    , @BisUtc                           datetime2(7)   = NULL
    , @Sortierung                       varchar(32)    = 'CPU_TOTAL'
    , @AnalyseModus                     varchar(16)    = 'TOP'
    , @MaxZeilen                        int            = 100
    , @MitPlanXml                       bit            = 0
    , @MaxSqlTextZeichen                int            = 4000
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    CREATE TABLE [#QueryStoreRuntimeStats_Export]
    (
          [QueryStoreDatabaseId] int NULL
        , [QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [QueryId] bigint NOT NULL
        , [PlanId] bigint NOT NULL
        , [QueryHash] binary(8) NULL
        , [QueryPlanHash] binary(8) NULL
        , [ObjectId] bigint NULL
        , [ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ExecutionTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FirstExecutionTimeUtc] datetimeoffset NULL
        , [LastExecutionTimeUtc] datetimeoffset NULL
        , [ExecutionCount] bigint NULL
        , [TotalDurationMs] decimal(38,3) NULL
        , [AverageDurationMs] decimal(38,3) NULL
        , [TotalCpuMs] decimal(38,3) NULL
        , [AverageCpuMs] decimal(38,3) NULL
        , [TotalLogicalReads] decimal(38,3) NULL
        , [AverageLogicalReads] decimal(38,3) NULL
        , [TotalLogicalWrites] decimal(38,3) NULL
        , [AverageLogicalWrites] decimal(38,3) NULL
        , [TotalPhysicalReads] decimal(38,3) NULL
        , [TotalMemoryGrantKb] decimal(38,3) NULL
        , [MaxMemoryGrantKb] decimal(38,3) NULL
        , [TotalRowCount] decimal(38,3) NULL
        , [TotalLogBytes] decimal(38,3) NULL
        , [TotalTempdbKb] decimal(38,3) NULL
        , [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CapturedAtUtc] datetime2(3) NULL
        , [EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [QuerySqlTextCharacters] bigint NULL
        , [QuerySqlTextBytes] bigint NULL
        , [QuerySqlTextIsTruncated] bit NULL
        , [QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [QueryPlanStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [QueryPlanCharacters] bigint NULL
        , [QueryPlanBytes] bigint NULL
        , [QueryPlan] xml NULL
        , [QueryPlanTextFallback] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    DECLARE @EffectiveMaxZeilen bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint, 9223372036854775807)
             WHEN @MaxZeilen > 0 THEN CONVERT(bigint, @MaxZeilen)
             ELSE CONVERT(bigint, 0) END;
    DECLARE @LocalCandidateRows bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint, 9223372036854775807)
             WHEN @MaxZeilen > 0 AND @MaxZeilen < 2147483647
             THEN CONVERT(bigint, @MaxZeilen) + 1
             WHEN @MaxZeilen > 0 THEN CONVERT(bigint, @MaxZeilen)
             ELSE CONVERT(bigint, 0) END;
    DECLARE @ResultSetArtNormalisiert varchar(16) =
        UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'runtimeStats',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    SET @Sortierung = UPPER(LTRIM(RTRIM(COALESCE(@Sortierung, 'CPU_TOTAL'))));
    SET @AnalyseModus = UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus, 'TOP'))));

    DECLARE @TextPatternMode varchar(8);
    DECLARE @TextPatternValue nvarchar(4000);
    DECLARE @TextRegexFlags varchar(8);
    DECLARE @TextPatternIsValid bit;
    DECLARE @ReferencedPatternMode varchar(8);
    DECLARE @ReferencedPatternValue nvarchar(4000);
    DECLARE @ReferencedRegexFlags varchar(8);
    DECLARE @ReferencedPatternIsValid bit;

    SELECT
          @TextPatternMode = [PatternMode]
        , @TextPatternValue = [PatternValue]
        , @TextRegexFlags = [RegexFlags]
        , @TextPatternIsValid = [IsValid]
    FROM [monitor].[TVF_ParsePattern](@TextPattern);

    SELECT
          @ReferencedPatternMode = [PatternMode]
        , @ReferencedPatternValue = [PatternValue]
        , @ReferencedRegexFlags = [RegexFlags]
        , @ReferencedPatternIsValid = [IsValid]
    FROM [monitor].[TVF_ParsePattern](@ReferencedDatabaseNamePattern);

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_QueryStoreRuntimeStats';
        PRINT N'Aggregiert persistierte Query-Store-Runtime- und Ressourcenwerte je Query, Plan und Ausführungstyp über Runtime-Intervalle.';
        PRINT N'Hilfe kehrt nach den frühen ResultTablesJson-Prüfungen vor der normalen Analyseparameter-Validierung zurück. Ungültige fachliche Filter oder Ausgabewerte werden im Hilfezweig nicht geprüft; Mappingfehler können die Hilfe weiterhin verhindern.';
        PRINT N'@QueryStoreDatabaseNames nvarchar(max); Default: NULL. Im normalen Analysepfad: Gibt exakte Query-Store-Quelldatenbanken als bracket-aware Pipe-Liste an; jedes Element ist ein einteiliger SQL-Name. Pipe trennt außerhalb von [...], ]] maskiert dort eine schließende Klammer, Rand-Leerzeichen je Element werden entfernt. Ausgelassen oder NULL sowie N'''' oder nur äußere Leerzeichen: keine Namenseinschränkung, also alle sichtbaren geeigneten Online-Benutzerdatenbanken. Nichtleere Liste: ungültige Elemente und doppelte gültige Namen ergeben INVALID_PARAMETER; Liste und @QueryStoreDatabaseNamePattern dürfen nicht gleichzeitig aktiv sein. Dies filtert Quell-Datenbanken, nicht Showplan-Referenzen. Ausgelassen gilt der deklarierte Default NULL. Die tatsächliche Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und höchstens 128 Zeichen für Teil 1; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.';
        PRINT N'@QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. Im normalen Analysepfad: Alternativer Patternfilter für Query-Store-Quelldatenbanken. NULL: kein Pattern. Äußere Leerzeichen werden getrimmt; optionale Präfixe LIKE/Regex werden ohne Beachtung der Großschreibung erkannt, der Patternwert danach nicht erneut getrimmt. Unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE; regex: case-sensitive (Flag c); regexi: case-insensitive (Flag i). Leer/U+0020-Leerzeichen und leeres Präfixergebnis sind ungültig. Nicht-NULL Pattern und wirksame exakte Quellliste schließen einander aus. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; der Auswahlhelfer führt den Regexfilter dort auf Kandidatennamen aus. Dies ist nicht die spätere Regexprüfung je Query-Store-Quelldatenbank. Filtert keine Showplan-Referenzen. Ausgelassen gilt der deklarierte Default NULL. LIKE verwendet %, _ und Zeichenklassen [...]. Präfix- und Eingabeformat sind Textwerte, zum Beispiel N''like:App%''; nach Präfixentfernung bleiben Inhalt und Groß-/Kleinschreibung erhalten.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. Im normalen Auswahlpfad: Bestätigt einen tatsächlich aktivierten High-Impact-Pfad mit 1. NULL ist INVALID_PARAMETER durch 083, unabhängig davon, ob die Analyseklasse ein Gruppengate verlangt; 0 lässt Bestätigung aus. QUERY_STORE_CURRENT verlangt derzeit kein Gruppengate; QUERY_STORE_DEEP hat RequiresGroupGate=1. Bestätigung aktiviert Deep nicht und gewährt keine Gruppen- oder SQL-Berechtigung; Freigabe und Rechte werden getrennt geprüft. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.';
        PRINT N'@ReferencedDatabaseNames nvarchar(max); Default: NULL. Im normalen Analysepfad: Filtert Querys anhand einteiliger Namen in gespeicherten Showplans, nicht die Quell-Datenbanken. NULL/ausgelassen: kein Referenzfilter. Nicht-NULL muss eine gültige bracket-aware Pipe-Liste sein; N''''/nur Leerzeichen und ungültige Parserwerte sind INVALID_PARAMETER. Gültige Duplikate sind zulässig; EXISTS vervielfacht Treffer nicht. Exakte Liste und @ReferencedDatabaseNamePattern dürfen nicht gleichzeitig non-NULL sein. Jedes gesetzte Referenzlistenfilter ist Deep und erfordert gespeicherte Showplan-XML. Ausgelassen gilt der deklarierte Default NULL. Die tatsächliche Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und höchstens 128 Zeichen für Teil 1; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.';
        PRINT N'@ReferencedDatabaseNamePattern nvarchar(4000); Default: NULL. Im normalen Analysepfad: Filtert nach in gespeicherten Showplans referenzierten Datenbanknamen; keine Quell-DB-Auswahl. NULL: kein Pattern. Unpräfigiert oder like: case-sensitive LIKE; regex: case-sensitive mit Flag c; regexi: case-insensitive mit Flag i. Äußere Leerzeichen werden vor Präfixerkennung getrimmt, danach der Inhalt nicht erneut. Leer/U+0020-Leerzeichen oder leeres Präfixergebnis ungültig. Jeder gesetzte Referenzpatternwert ist exklusiv zu @ReferencedDatabaseNames und löst Deep aus. Regex benötigt SQL Server 2025 und Compatibility Level 170 je Quelldatenbank. Ausgelassen gilt der deklarierte Default NULL. LIKE verwendet %, _ und Zeichenklassen [...]. Präfix- und Eingabeformat sind Textwerte, zum Beispiel N''like:App%''; nach Präfixentfernung bleiben Inhalt und Groß-/Kleinschreibung erhalten.';
        PRINT N'@QueryId bigint; Default: NULL. Filtert auf die exakte QueryId in jeder gewählten Query-Store-Quelldatenbank. NULL/ausgelassen: kein QueryId-Filter. Jeder signed-bigint-Wert ist zulässig; keine zusätzliche Positivitätsprüfung. Wirkung bleibt auf Quellen, Zeitfenster und übrige Filter beschränkt.';
        PRINT N'@QueryHash binary(8); Default: NULL. Filtert exakt auf den 8-Byte-QueryHash. NULL/ausgelassen: kein Hashfilter. Der Wert muss zu binary(8) konvertierbar sein; Hexwerte als 0x plus 16 Hexziffern angeben. Hash ersetzt nicht die Identität aus Quelldatenbank und QueryId.';
        PRINT N'@TextPattern nvarchar(4000); Default: NULL. Im normalen Analysepfad: Filtert den gespeicherten SQL-Text. NULL/ausgelassen: kein Filter. Unpräfigiert oder like: SQL-LIKE unter expliziter case-sensitive Framework-Collation; regex: case-sensitive Regex (Flag c); regexi: case-insensitive Regex (Flag i). Präfixerkennung case-insensitive; äußere Leerzeichen werden zuerst getrimmt, nach Präfixentfernung der Wert nicht erneut. Leerer/U+0020-Leerzeichen Wert oder leeres Präfixergebnis ungültig. Regex benötigt SQL Server 2025 und Compatibility Level 170 in jeder Quelldatenbank und aktiviert Deep; unpassende Quelle wird als unavailable/partial gemeldet. Ausgelassen gilt der deklarierte Default NULL. LIKE verwendet %, _ und Zeichenklassen [...]. Präfix- und Eingabeformat sind Textwerte, zum Beispiel N''like:App%''; nach Präfixentfernung bleiben Inhalt und Groß-/Kleinschreibung erhalten.';
        PRINT N'@VonUtc datetime2(7); Default: NULL. Im normalen Analysepfad: UTC-Untergrenze; caller liefert UTC, datetime2 hat keinen Offset und es erfolgt keine Zeitzonenkonvertierung. NULL wird nach Auflösung von @BisUtc auf BisUtc minus eine Stunde gesetzt. Erforderlich ist VonUtc < BisUtc; Gleichheit oder größer ist ungültig. Intervalle werden bei end_time > VonUtc und start_time < BisUtc vollständig berücksichtigt, ohne anteilige Kürzung; gemeldete Execution-Zeiten können außerhalb des Fensters liegen. Ausgelassen gilt der deklarierte Default NULL. Übergabeform zum Beispiel ''2026-01-01T12:00:00.0000000'' als UTC-datetime2(7); kein Offset wird umgerechnet.';
        PRINT N'@BisUtc datetime2(7); Default: NULL. UTC-Obergrenze; caller liefert UTC ohne Offsetkonvertierung. NULL/ausgelassen wird zu SYSUTCDATETIME() aufgelöst; zugleich NULLes @VonUtc ergibt eine Stunde Fenster. Muss größer als @VonUtc sein. Mit end_time > VonUtc und start_time < BisUtc schneiden Intervalle das Fenster; sie werden vollständig und nicht anteilig einbezogen. Ausgelassen gilt der deklarierte Default NULL. Übergabeform zum Beispiel ''2026-01-01T12:00:00.0000000'' als UTC-datetime2(7); kein Offset wird umgerechnet.';
        PRINT N'@Sortierung varchar(32); Default: ''CPU_TOTAL''. Im normalen Analysepfad: Werte werden getrimmt und großgeschrieben; NULL/ausgelassen wird CPU_TOTAL, leer oder unbekannt ist ungültig. Geschlossene Wertemenge mit tatsächlichem Rank-Ausdruck, jeweils DESC: CPU_TOTAL=TotalCpuMs (gesamte CPU ms); DURATION_TOTAL=TotalDurationMs (Gesamtdauer ms); READS_TOTAL=TotalLogicalReads (aggregierte logische Lesezugriffe); WRITES_TOTAL=TotalLogicalWrites (aggregierte logische Schreibzugriffe); EXECUTIONS=ExecutionCount (Ausführungsanzahl); MEMORY_MAX=MaxMemoryGrantKb (größter beobachteter Query-Speicherwert in KB); TEMPDB_TOTAL=TotalTempdbKb (aggregierte TempDB-Menge in KB); LOG_BYTES_TOTAL=TotalLogBytes (aggregierte Logbytes); LAST_EXECUTION=LastExecutionTimeUtc (letzte Ausführung). Im globalen Ranking folgen letzter Ausführungszeitpunkt DESC, Query-Store-Datenbankname, QueryId und PlanId; lokal wird nach Rang und gegebenenfalls letztem Ausführungszeitpunkt geordnet. Bestimmt den globalen Ausschnitt; RAW und JSON ordnen ausdrücklich. Für TABLE und die aktive CONSOLE besteht keine zusätzliche physische Reihenfolgegarantie. Ausgelassen gilt der deklarierte Default ''CPU_TOTAL''. Maßgeblich ist der bereits an varchar(32) zugewiesene Wert; eine längere Textangabe kann davor auf die Typbreite gekürzt werden. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen.';
        PRINT N'@AnalyseModus varchar(16); Default: ''TOP''. Im normalen Analysepfad: Werte werden getrimmt und großgeschrieben; NULL/ausgelassen wird TOP. Geschlossene Menge: TOP ist der Standard-Rankingpfad und fordert allein keinen Deep-Pfad an; VOLL aktiviert QUERY_STORE_DEEP und dessen High-Impact-/Zugriffsgate, hebt aber nicht das Zeilenlimit auf. Leer/unbekannt ist ungültig. Unabhängige Deep-Auslöser: MitPlanXml=1, effektives MaxZeilen >1000, DATEDIFF(HOUR,VonUtc,BisUtc)>24, nicht-NULL Referenznamen/-pattern oder Querytext-REGEX/REGEXI. Ausgelassen gilt der deklarierte Default ''TOP''. Maßgeblich ist der bereits an varchar(16) zugewiesene Wert; eine längere Textangabe kann davor auf die Typbreite gekürzt werden. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen.';
        PRINT N'@MaxZeilen int; Default: 100. Im normalen Analysepfad: Globales Ergebnislimit nach lokalem Ranking. Ausgelassen: 100; NULL/0 unbegrenzt; positiver int 1 bis 2147483647 begrenzt; negative Werte INVALID_PARAMETER. Je Quelle werden höchstens N+1 lokale Kandidaten gelesen, außer int-Maximum verwendet N; NULL/0 nutzt unbegrenzte lokale Kandidaten. Nach Quellenaggregation/-sortierung folgen Textprojektion, Plan-XML-Parsing, Warnungen und Zähler für alle Kandidaten vor dem globalen TOP. Effektives Limit >1000 sowie unbegrenzt (NULL/0) aktivieren Deep. ResultLimited/hasMoreRows zeigt global abgeschnittene Treffer an.';
        PRINT N'@MitPlanXml bit; Default: 0. Nur genau 1 aktiviert Planausgabe und XML-Parsen gespeicherter Plantexte für ausgewählte Kandidaten und löst Deep aus. 0 unterdrückt Planausgabe und XML-Parsen, QueryPlan bleibt NULL und QueryPlanStatus wird NOT_REQUESTED. NULL aktiviert weder Planausgabe/XML-Parsen noch Deep, erhält aber durch den Status-CASE PENDING statt NOT_REQUESTED. Nur bei 1 werden Plantexte tatsächlich geparst; XML-Inhalt kann AVAILABLE/XML_EMPTY/SOURCE_NULL oder Fehlerstatus liefern. Erhöht Quell- und Parseaufwand. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. Der Quell-CTE referenziert und gruppiert den gespeicherten Plantexteintrag unabhängig vom Schalter; 0 oder NULL garantiert deshalb keine Vermeidung nativer Plantexte-Zugriffe.';
        PRINT N'@MaxSqlTextZeichen int; Default: 4000. Im normalen Analysepfad: Maximale exportierte SQL-Textlänge je Treffer. Default 4000; NULL/0: vollständig; positiv: Grenze in Unicode-Zeichen unter SC-Collation, Surrogatpaar zählt als ein Zeichen und wird nicht geteilt; Graphemcluster werden nicht gezählt. Negativ ist INVALID_PARAMETER. QuerySqlTextCharacters/QuerySqlTextBytes bleiben verfügbar und QuerySqlTextIsTruncated kennzeichnet Kürzung. Eine zusammengefasste Warnung wird bei Kürzung nur mit @PrintMeldungen=1 ausgegeben. Die Grenze projiziert nach Materialisierung des Quelltexts. Ausgelassen gilt der deklarierte Default 4000.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Im normalen Analysepfad: Werte werden getrimmt und großgeschrieben, daher case-insensitiv. Geschlossene Menge: CONSOLE formatiert nur die fachliche Exportmenge oder bei Leere einen Hinweis; RAW liefert drei technische Resultsets (Metadaten, runtimeStats, Warnungen); TABLE schreibt nur runtimeStats ins benannte Ziel und unterdrückt Grids; NONE unterdrückt Resultsetgrids. JSON über @JsonErzeugen/@Json ist unabhängig davon. Nur TABLE erlaubt nichtleeres @ResultTablesJson. TABLE verlangt eine gültige Zuordnung und bestehende leere lokale #Temp-Zieltabelle mit genau einer beliebigen Seed-Spalte; Helper-Preflight erfolgt vor fachlichem Zugriff. NULL wird zu leer und ist wie leer/unbekannt ungültig. Ausgelassen gilt der deklarierte Default ''CONSOLE''. Maßgeblich ist der bereits an varchar(16) zugewiesene Wert; eine längere Textangabe kann davor auf die Typbreite gekürzt werden. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. JSON-Zuordnung für das einzelne TABLE-Resultset runtimeStats. Bei TABLE ist ein gültiges nichtleeres JSON-Objekt erforderlich; NULL/ausgelassen, leer/U+0020-Leerzeichen oder ungültiges JSON schlägt den Preflight fehl. Das Objekt muss genau den Schlüssel runtimeStats auf ein vorhandenes, eindeutiges lokales #Temp-Ziel abbilden; unbekannte/doppelte Namen oder Ziele sind ungültig. Ziel muss bereits existieren und leer sein, mit genau einer beliebigen Seed-Spalte; es braucht nicht die volle RuntimeStats-Zielstruktur. Preflight vor fachlichen Datenquellen. Nichtleeres Mapping ausschließlich mit TABLE; für andere ResultSetArt wird es vor dem fachlichen Zugriff abgewiesen. Ausgelassen gilt der deklarierte Default NULL. Schlüssel werden binär einschließlich Groß-/Kleinschreibung verglichen; doppelte Schlüssel sind ungültig. Zielnamen sind Strings mit LEN höchstens 116, beginnen mit #, aber nicht ## oder case-insensitiv #Monitor; doppelte Ziele werden case-insensitiv abgewiesen. Die einzelne Seed-Spalte hat einen beliebigen Namen und Typ; eine Seed-Zeile ist nicht zulässig. Sowohl diese TABLE-Vorprüfung als auch die Ablehnung eines nichtleeren Mappings außerhalb TABLE liegen vor dem Hilfezweig.';
        PRINT N'@JsonErzeugen bit; Default: 0. Nur genau 1 baut @Json als Objekt mit meta, runtimeStats und warnings. 0 oder NULL erzeugt kein JSON; der Parameter ist nicht abhängig von @ResultSetArt, daher auch mit NONE möglich. Die JSON-Daten reflektieren die gemeinsame Exportmenge, Sortierung und globale Begrenzung. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionale OUTPUT-Bindung zum Empfang des JSON. Beim Procedure-Eintritt wird der Ausgabewert immer auf NULL zurückgesetzt; ohne callerseitige OUTPUT-Bindung gibt es keinen empfangenen Wert. Nur mit @JsonErzeugen=1 wird das meta/runtimeStats/warnings-Objekt zugewiesen; ansonsten bleibt NULL. Im EXEC-Aufruf muss auch die empfangende Variable mit OUTPUT gebunden werden. Ausgelassen gilt der deklarierte Default NULL. Der Eingabewert dient nicht als Steuerwert; bei Hilfe bleibt der intern zurückgesetzte Wert NULL. Bei vorzeitigem THROW ist kein übernommener OUTPUT zugesichert.';
        PRINT N'@PrintMeldungen bit; Default: 1. Steuert Severity-10-Meldungen, nicht Warning-Datensätze oder JSON. Default/1: erlaubte Quellenfehler und Truncationwarnung werden als Meldungen ausgegeben. 0/NULL: Meldungen unterdrückt; Fehler-/Warning-Daten in RAW und JSON warnings bleiben erhalten; die aktive CONSOLE hat kein separates Warnungsresultset. Nur genau 1 aktiviert die Meldungsausgabe. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.';
        PRINT N'@Hilfe bit; Default: 0. Genau 1 druckt integrierte Parameterhilfe via PRINT und kehrt unmittelbar zurück, vor Zeitauflösung, Datenbankkandidaten, fachlichen Quellen und Ausgabe. Default/0 führt Analyse aus; NULL löst den Hilfezweig nicht aus. Hilfe erzeugt keine fachlichen Resultsets. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. Die nichtleere Mappingzuordnung außerhalb TABLE wird ebenso wie der TABLE-Zielpreflight bereits vor der Hilfe geprüft; ein Mappingfehler kann den Hilfereturn verhindern. Die normale Validierung von Ausgabemodus, Sortierung, Analysemodus, Namen, Pattern, Zeitfenster, Zeilen-/Textgrenzen und Analysefreigaben entfällt im Hilfezweig; die frühen Mappingprüfungen bleiben aktiv.';
        PRINT N'EXEC [monitor].[USP_QueryStoreRuntimeStats] @Hilfe=1;';
        PRINT N'EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'CREATE TABLE [#QueryStoreRuntimeStats_HelpExample] ([seed] int NULL); EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"runtimeStats":"#QueryStoreRuntimeStats_HelpExample"}''; SELECT * FROM [#QueryStoreRuntimeStats_HelpExample]; DROP TABLE [#QueryStoreRuntimeStats_HelpExample];';
        RETURN;
    END;

    IF @BisUtc IS NULL SET @BisUtc = SYSUTCDATETIME();
    IF @VonUtc IS NULL SET @VonUtc = DATEADD(HOUR, -1, @BisUtc);

    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Allowed bit = 1;
    DECLARE @Db sysname;
    DECLARE @DbCompatibilityLevel tinyint;
    DECLARE @Sql nvarchar(max);
    DECLARE @Order sysname;
    DECLARE @CandidateRowCount bigint = 0;
    DECLARE @RowCount bigint = 0;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @Deep bit = 0;
    DECLARE @CrossDatabaseRequested bit = 0;
    DECLARE @MonitorPrintMessage nvarchar(2048);
    DECLARE @TextPredicate nvarchar(max) = N'';
    DECLARE @ReferencedPredicate nvarchar(max) = N'';

    CREATE TABLE [#QueryStoreRuntimeStats_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL
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

    CREATE TABLE [#QueryStoreRuntimeStats_Result]
    (
          [QueryStoreDatabaseId] int NULL
        , [QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [QueryId] bigint NOT NULL
        , [PlanId] bigint NOT NULL
        , [QueryHash] binary(8) NULL
        , [QueryPlanHash] binary(8) NULL
        , [ObjectId] bigint NULL
        , [ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ExecutionTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FirstExecutionTimeUtc] datetimeoffset NULL
        , [LastExecutionTimeUtc] datetimeoffset NULL
        , [ExecutionCount] bigint NULL
        , [TotalDurationMs] decimal(38,3) NULL
        , [AverageDurationMs] decimal(38,3) NULL
        , [TotalCpuMs] decimal(38,3) NULL
        , [AverageCpuMs] decimal(38,3) NULL
        , [TotalLogicalReads] decimal(38,3) NULL
        , [AverageLogicalReads] decimal(38,3) NULL
        , [TotalLogicalWrites] decimal(38,3) NULL
        , [AverageLogicalWrites] decimal(38,3) NULL
        , [TotalPhysicalReads] decimal(38,3) NULL
        , [TotalMemoryGrantKb] decimal(38,3) NULL
        , [MaxMemoryGrantKb] decimal(38,3) NULL
        , [TotalRowCount] decimal(38,3) NULL
        , [TotalLogBytes] decimal(38,3) NULL
        , [TotalTempdbKb] decimal(38,3) NULL
        , [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CapturedAtUtc] datetime2(3) NULL
        , [EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [QuerySqlTextCharacters] bigint NULL
        , [QuerySqlTextBytes] bigint NULL
        , [QuerySqlTextIsTruncated] bit NULL
        , [QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [QueryPlanStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [QueryPlanCharacters] bigint NULL
        , [QueryPlanBytes] bigint NULL
        , [QueryPlan] xml NULL
        , [QueryPlanTextFallback] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#QueryStoreRuntimeStats_Errors]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    SET @Order = CASE @Sortierung
        WHEN 'CPU_TOTAL' THEN N'TotalCpuMs'
        WHEN 'DURATION_TOTAL' THEN N'TotalDurationMs'
        WHEN 'READS_TOTAL' THEN N'TotalLogicalReads'
        WHEN 'WRITES_TOTAL' THEN N'TotalLogicalWrites'
        WHEN 'EXECUTIONS' THEN N'ExecutionCount'
        WHEN 'MEMORY_MAX' THEN N'MaxMemoryGrantKb'
        WHEN 'TEMPDB_TOTAL' THEN N'TotalTempdbKb'
        WHEN 'LOG_BYTES_TOTAL' THEN N'TotalLogBytes'
        WHEN 'LAST_EXECUTION' THEN N'LastExecutionTimeUtc'
    END;

    IF @AnalyseModus NOT IN ('TOP', 'VOLL')
       OR @Order IS NULL
       OR @MaxZeilen < 0

       OR @MaxSqlTextZeichen < 0
       OR @VonUtc >= @BisUtc
       OR @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR @TextPatternIsValid = 0
       OR @ReferencedPatternIsValid = 0
       OR (@ReferencedDatabaseNames IS NOT NULL AND EXISTS
          (
              SELECT 1
              FROM [monitor].[TVF_ParseSqlNameList](@ReferencedDatabaseNames)
              WHERE [IsValid] = 0
          ))
       OR (@ReferencedDatabaseNames IS NOT NULL
           AND @ReferencedDatabaseNamePattern IS NOT NULL)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültiger Parameter oder Zeitraum.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames = @QueryStoreDatabaseNames
            , @SystemdatenbankenEinbeziehen = 0
            , @DatabaseNamePattern = @QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

            , @AnalysisClass='QUERY_STORE_CURRENT'
            , @StatusCode = @StatusCode OUTPUT
            , @ErrorMessage = @ErrorMessage OUTPUT
            , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT,@CandidateTable=N'#QueryStoreRuntimeStats_DatabaseCandidates';
    END;

    SET @Deep = CONVERT
    (
        bit,
        CASE WHEN @AnalyseModus = 'VOLL'
               OR @MitPlanXml = 1
               OR @EffectiveMaxZeilen > 1000
               OR DATEDIFF(HOUR, @VonUtc, @BisUtc) > 24
               OR @ReferencedDatabaseNames IS NOT NULL
               OR @ReferencedDatabaseNamePattern IS NOT NULL
               OR @TextPatternMode IN ('REGEX', 'REGEXI')
             THEN 1 ELSE 0 END
    );

    IF @StatusCode = 'AVAILABLE' AND @Deep = 1
    BEGIN
        EXEC [monitor].[InternalCheckAnalysisPath]
              @AnalysisClass='QUERY_STORE_DEEP'
            , @HighImpactConfirmed=@HighImpactConfirmed
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT;
    END;

    IF @TextPatternMode = 'LIKE'
        SET @TextPredicate = N' AND [qt].[query_sql_text] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @TextPatternValue COLLATE SQL_Latin1_General_CP1_CS_AS';
    ELSE IF @TextPatternMode IN ('REGEX', 'REGEXI')
        SET @TextPredicate = N' AND REGEXP_LIKE([qt].[query_sql_text], @TextPatternValue, @TextRegexFlags)';

    IF @ReferencedDatabaseNames IS NOT NULL
        SET @ReferencedPredicate = N'
 AND EXISTS
 (
     SELECT 1
     FROM (SELECT CONVERT(xml, [p].[query_plan]) AS [PlanXml]) AS [px]
     CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') AS [n]([ObjectNode])
     JOIN ' + QUOTENAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID())) + N'.[monitor].[TVF_ParseSqlNameList](@ReferencedDatabaseNames) AS [rf]
       ON [rf].[IsValid] = 1
      AND [rf].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS
        = PARSENAME([n].[ObjectNode].value(''@Database'', ''nvarchar(776)''), 1) COLLATE SQL_Latin1_General_CP1_CS_AS
 )';
    ELSE IF @ReferencedPatternMode = 'LIKE'
        SET @ReferencedPredicate = N'
 AND EXISTS
 (
     SELECT 1
     FROM (SELECT CONVERT(xml, [p].[query_plan]) AS [PlanXml]) AS [px]
     CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') AS [n]([ObjectNode])
     WHERE PARSENAME([n].[ObjectNode].value(''@Database'', ''nvarchar(776)''), 1) COLLATE SQL_Latin1_General_CP1_CS_AS
           LIKE @ReferencedPatternValue COLLATE SQL_Latin1_General_CP1_CS_AS
 )';
    ELSE IF @ReferencedPatternMode IN ('REGEX', 'REGEXI')
        SET @ReferencedPredicate = N'
 AND EXISTS
 (
     SELECT 1
     FROM (SELECT CONVERT(xml, [p].[query_plan]) AS [PlanXml]) AS [px]
     CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') AS [n]([ObjectNode])
     WHERE REGEXP_LIKE(PARSENAME([n].[ObjectNode].value(''@Database'', ''nvarchar(776)''), 1), @ReferencedPatternValue, @ReferencedRegexFlags)
 )';

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        DECLARE [c] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseName], [CompatibilityLevel]
            FROM [#QueryStoreRuntimeStats_DatabaseCandidates]
            ORDER BY COALESCE([RequestedOrdinal], [DatabaseId]), [DatabaseId];

        OPEN [c];
        FETCH NEXT FROM [c] INTO @Db, @DbCompatibilityLevel;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF (@TextPatternMode IN ('REGEX', 'REGEXI')
                OR @ReferencedPatternMode IN ('REGEX', 'REGEXI'))
               AND
               (
                   TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) < 17
                   OR @DbCompatibilityLevel < 170
               )
            BEGIN
                INSERT [#QueryStoreRuntimeStats_Errors]
                VALUES
                (
                      @Db
                    , 'UNAVAILABLE_FEATURE'
                    , NULL
                    , N'Regex benötigt SQL Server 2025 und Compatibility Level 170 in der Query-Store-Quelldatenbank.'
                );
                SET @IsPartial = 1;
            END
            ELSE
            BEGIN TRY
                SET @Sql = N'USE ' + QUOTENAME(@Db) + N';
IF EXISTS
(
    SELECT 1
    FROM [sys].[database_query_store_options] WITH (NOLOCK)
    WHERE [actual_state] IN (1, 2, 4)
)
BEGIN
    ;WITH [RI] AS
    (
        SELECT
              [rs].[plan_id]
            , [rs].[execution_type]
            , [rs].[execution_type_desc]
            , [rs].[runtime_stats_interval_id]
            , MIN([rs].[first_execution_time]) AS [first_execution_time]
            , MAX([rs].[last_execution_time]) AS [last_execution_time]
            , SUM([rs].[count_executions]) AS [count_executions]
            , SUM(CONVERT(float, [rs].[avg_duration]) * [rs].[count_executions]) AS [duration_weighted]
            , SUM(CONVERT(float, [rs].[avg_cpu_time]) * [rs].[count_executions]) AS [cpu_weighted]
            , SUM(CONVERT(float, [rs].[avg_logical_io_reads]) * [rs].[count_executions]) AS [reads_weighted]
            , SUM(CONVERT(float, [rs].[avg_logical_io_writes]) * [rs].[count_executions]) AS [writes_weighted]
            , SUM(CONVERT(float, [rs].[avg_physical_io_reads]) * [rs].[count_executions]) AS [physical_weighted]
            , SUM(CONVERT(float, [rs].[avg_query_max_used_memory]) * [rs].[count_executions]) AS [memory_weighted]
            , MAX(CONVERT(float, [rs].[max_query_max_used_memory])) AS [max_memory_pages]
            , SUM(CONVERT(float, [rs].[avg_rowcount]) * [rs].[count_executions]) AS [rows_weighted]
            , SUM(CONVERT(float, [rs].[avg_log_bytes_used]) * [rs].[count_executions]) AS [log_weighted]
            , SUM(CONVERT(float, [rs].[avg_tempdb_space_used]) * [rs].[count_executions]) AS [tempdb_weighted]
        FROM [sys].[query_store_runtime_stats] AS [rs] WITH (NOLOCK)
        JOIN [sys].[query_store_runtime_stats_interval] AS [rsi] WITH (NOLOCK)
          ON [rsi].[runtime_stats_interval_id] = [rs].[runtime_stats_interval_id]
        WHERE [rsi].[end_time] > @FromUtc
          AND [rsi].[start_time] < @ToUtc
        GROUP BY [rs].[plan_id], [rs].[execution_type],
                 [rs].[execution_type_desc], [rs].[runtime_stats_interval_id]
    ),
    [A] AS
    (
        SELECT
              [q].[query_id]
            , [p].[plan_id]
            , [q].[query_hash]
            , [p].[query_plan_hash]
            , [q].[object_id]
            , [RI].[execution_type_desc]
            , MIN([RI].[first_execution_time]) AS [first_execution_time]
            , MAX([RI].[last_execution_time]) AS [last_execution_time]
            , SUM([RI].[count_executions]) AS [executions]
            , SUM([RI].[duration_weighted]) AS [duration_weighted]
            , SUM([RI].[cpu_weighted]) AS [cpu_weighted]
            , SUM([RI].[reads_weighted]) AS [reads_weighted]
            , SUM([RI].[writes_weighted]) AS [writes_weighted]
            , SUM([RI].[physical_weighted]) AS [physical_weighted]
            , SUM([RI].[memory_weighted]) AS [memory_weighted]
            , MAX([RI].[max_memory_pages]) AS [max_memory_pages]
            , SUM([RI].[rows_weighted]) AS [rows_weighted]
            , SUM([RI].[log_weighted]) AS [log_weighted]
            , SUM([RI].[tempdb_weighted]) AS [tempdb_weighted]
            , [qt].[query_sql_text]
            , [p].[query_plan]
        FROM [RI]
        JOIN [sys].[query_store_plan] AS [p] WITH (NOLOCK)
          ON [p].[plan_id] = [RI].[plan_id]
        JOIN [sys].[query_store_query] AS [q] WITH (NOLOCK)
          ON [q].[query_id] = [p].[query_id]
        JOIN [sys].[query_store_query_text] AS [qt] WITH (NOLOCK)
          ON [qt].[query_text_id] = [q].[query_text_id]
        WHERE (@QueryId IS NULL OR [q].[query_id] = @QueryId)
          AND (@QueryHash IS NULL OR [q].[query_hash] = @QueryHash)' + @TextPredicate + @ReferencedPredicate + N'
        GROUP BY [q].[query_id], [p].[plan_id], [q].[query_hash],
                 [p].[query_plan_hash], [q].[object_id],
                 [RI].[execution_type_desc], [qt].[query_sql_text], [p].[query_plan]
    )
    INSERT [#QueryStoreRuntimeStats_Result]
    (
          [QueryStoreDatabaseId], [QueryStoreDatabaseName], [QueryId], [PlanId]
        , [QueryHash], [QueryPlanHash], [ObjectId], [ObjectName]
        , [ExecutionTypeDesc], [FirstExecutionTimeUtc], [LastExecutionTimeUtc]
        , [ExecutionCount], [TotalDurationMs], [AverageDurationMs]
        , [TotalCpuMs], [AverageCpuMs], [TotalLogicalReads]
        , [AverageLogicalReads], [TotalLogicalWrites], [AverageLogicalWrites]
        , [TotalPhysicalReads], [TotalMemoryGrantKb], [MaxMemoryGrantKb]
        , [TotalRowCount], [TotalLogBytes], [TotalTempdbKb]
        , [QuerySqlText], [QueryPlanTextFallback]
    )
    SELECT TOP (@TopRows)
          DB_ID()
        , (SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID())
        , [query_id]
        , [plan_id]
        , [query_hash]
        , [query_plan_hash]
        , [A].[object_id]
        , CASE WHEN [A].[object_id] > 0
               THEN QUOTENAME([os].[name]) + N''.'' + QUOTENAME([oo].[name]) END
        , [execution_type_desc]
        , [first_execution_time]
        , [last_execution_time] AS [LastExecutionTimeUtc]
        , [executions] AS [ExecutionCount]
        , CONVERT(decimal(38,3), [duration_weighted] / 1000.0) AS [TotalDurationMs]
        , CONVERT(decimal(38,3), [duration_weighted] / NULLIF([executions], 0) / 1000.0)
        , CONVERT(decimal(38,3), [cpu_weighted] / 1000.0) AS [TotalCpuMs]
        , CONVERT(decimal(38,3), [cpu_weighted] / NULLIF([executions], 0) / 1000.0)
        , CONVERT(decimal(38,3), [reads_weighted]) AS [TotalLogicalReads]
        , CONVERT(decimal(38,3), [reads_weighted] / NULLIF([executions], 0))
        , CONVERT(decimal(38,3), [writes_weighted]) AS [TotalLogicalWrites]
        , CONVERT(decimal(38,3), [writes_weighted] / NULLIF([executions], 0))
        , CONVERT(decimal(38,3), [physical_weighted])
        , CONVERT(decimal(38,3), [memory_weighted] * 8.0)
        , CONVERT(decimal(38,3), [max_memory_pages] * 8.0) AS [MaxMemoryGrantKb]
        , CONVERT(decimal(38,3), [rows_weighted])
        , CONVERT(decimal(38,3), [log_weighted]) AS [TotalLogBytes]
        , CONVERT(decimal(38,3), [tempdb_weighted] * 8.0) AS [TotalTempdbKb]
        , [query_sql_text]
        , CASE WHEN @IncludePlan = 1 THEN [query_plan] END
    FROM [A]
    LEFT JOIN [sys].[objects] AS [oo] WITH (NOLOCK)
      ON [oo].[object_id] = [A].[object_id]
    LEFT JOIN [sys].[schemas] AS [os] WITH (NOLOCK)
      ON [os].[schema_id] = [oo].[schema_id]
    ORDER BY ' + QUOTENAME(@Order) + N' DESC' + CASE WHEN @Order=N'LastExecutionTimeUtc' THEN N'' ELSE N', [last_execution_time] DESC' END + N';
END;';

                EXEC [sys].[sp_executesql]
                      @Sql
                    , N'@FromUtc datetime2(7), @ToUtc datetime2(7), @QueryId bigint,
                        @QueryHash binary(8), @TopRows bigint, @TextChars int,
                        @IncludePlan bit, @TextPatternValue nvarchar(4000),
                        @TextRegexFlags varchar(8), @ReferencedDatabaseNames nvarchar(max),
                        @ReferencedPatternValue nvarchar(4000), @ReferencedRegexFlags varchar(8)'
                    , @FromUtc = @VonUtc
                    , @ToUtc = @BisUtc
                    , @QueryId = @QueryId
                    , @QueryHash = @QueryHash
                    , @TopRows = @LocalCandidateRows
                    , @TextChars = @MaxSqlTextZeichen
                    , @IncludePlan = @MitPlanXml
                    , @TextPatternValue = @TextPatternValue
                    , @TextRegexFlags = @TextRegexFlags
                    , @ReferencedDatabaseNames = @ReferencedDatabaseNames
                    , @ReferencedPatternValue = @ReferencedPatternValue
                    , @ReferencedRegexFlags = @ReferencedRegexFlags;
            END TRY
            BEGIN CATCH
                INSERT [#QueryStoreRuntimeStats_Errors]
                VALUES
                (
                      @Db
                    , CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                           WHEN ERROR_NUMBER() = 1222 THEN 'TIMEOUT'
                           ELSE 'ERROR_HANDLED' END
                    , ERROR_NUMBER()
                    , ERROR_MESSAGE()
                );
                SET @IsPartial = 1;

                IF @PrintMeldungen = 1
                BEGIN
                    SET @MonitorPrintMessage = FORMATMESSAGE
                    (
                        N'WARNUNG USP_QueryStoreRuntimeStats [%s]: %s',
                        @Db,
                        ERROR_MESSAGE()
                    );
                    RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
                END;
            END CATCH;

            FETCH NEXT FROM [c] INTO @Db, @DbCompatibilityLevel;
        END;

        CLOSE [c];
        DEALLOCATE [c];

        UPDATE [r]
        SET [SourceType]='QUERY_STORE',
            [SourceObject]=N'sys.query_store_runtime_stats|sys.query_store_plan|sys.query_store_query_text',
            [CapturedAtUtc]=@CollectionTimeUtc,
            [EvidenceScope]='DATABASE_QUERY_PLAN_INTERVAL',
            [QuerySqlTextCharacters]=[projection].[OriginalCharacters],
            [QuerySqlTextBytes]=[projection].[OriginalBytes],
            [QuerySqlTextIsTruncated]=[projection].[IsTruncated],
            [QuerySqlText]=[projection].[ProjectedValue],
            [QueryPlanStatus]=CASE WHEN @MitPlanXml=0 THEN 'NOT_REQUESTED' ELSE 'PENDING' END,
            [EvidenceLimit]=N'Query Store liefert aggregierte Intervallwerte und den gespeicherten Plan; keine aktuelle Einzelausführung und keine vollständigen Runtimeparameter.'
        FROM [#QueryStoreRuntimeStats_Result] AS [r]
        CROSS APPLY [monitor].[TVF_ProjectUnicodeText]([r].[QuerySqlText],@MaxSqlTextZeichen) AS [projection];

        DECLARE @PlanDatabaseId int,@PlanQueryId bigint,@PlanId bigint,@PlanText nvarchar(max);
        DECLARE @PlanXml xml,@PlanStatus varchar(40),@PlanErrorNumber int,@PlanErrorMessage nvarchar(2048);
        DECLARE [PlanCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [QueryStoreDatabaseId],[QueryId],[PlanId],[QueryPlanTextFallback]
            FROM [#QueryStoreRuntimeStats_Result]
            WHERE @MitPlanXml=1
            ORDER BY [QueryStoreDatabaseId],[QueryId],[PlanId];
        OPEN [PlanCursor];
        FETCH NEXT FROM [PlanCursor] INTO @PlanDatabaseId,@PlanQueryId,@PlanId,@PlanText;
        WHILE @@FETCH_STATUS=0
        BEGIN
            EXEC [monitor].[InternalParseXmlText]
                  @XmlText=@PlanText,@XmlValue=@PlanXml OUTPUT,@StatusCode=@PlanStatus OUTPUT,
                  @ErrorNumber=@PlanErrorNumber OUTPUT,@ErrorMessage=@PlanErrorMessage OUTPUT;
            UPDATE [#QueryStoreRuntimeStats_Result]
            SET [QueryPlanStatus]=@PlanStatus,
                [QueryPlanCharacters]=CASE WHEN @PlanText IS NULL THEN NULL ELSE CONVERT(bigint,LEN((@PlanText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1) END,
                [QueryPlanBytes]=CONVERT(bigint,DATALENGTH(@PlanText)),
                [QueryPlan]=@PlanXml,
                [QueryPlanTextFallback]=CASE WHEN @PlanStatus IN('AVAILABLE','XML_EMPTY','SOURCE_NULL') THEN NULL ELSE @PlanText END
            WHERE [QueryStoreDatabaseId]=@PlanDatabaseId AND [QueryId]=@PlanQueryId AND [PlanId]=@PlanId;
            IF @PlanStatus IN('XML_INVALID','XML_UNAVAILABLE_LIMIT')
            BEGIN
                INSERT [#QueryStoreRuntimeStats_Errors]
                VALUES((SELECT TOP(1) [QueryStoreDatabaseName] FROM [#QueryStoreRuntimeStats_Result] WHERE [QueryStoreDatabaseId]=@PlanDatabaseId),@PlanStatus,@PlanErrorNumber,@PlanErrorMessage);
                SET @IsPartial=1;
            END;
            FETCH NEXT FROM [PlanCursor] INTO @PlanDatabaseId,@PlanQueryId,@PlanId,@PlanText;
        END;
        CLOSE [PlanCursor];
        DEALLOCATE [PlanCursor];

        DECLARE @TruncatedValueCount bigint=0,@LargestRequiredCharacters bigint=NULL;
        SELECT @TruncatedValueCount=COUNT_BIG(*),@LargestRequiredCharacters=MAX([QuerySqlTextCharacters])
        FROM [#QueryStoreRuntimeStats_Result]
        WHERE [QuerySqlTextIsTruncated]=1;
        EXEC [monitor].[InternalEmitTruncationWarning]
              @TruncatedValueCount=@TruncatedValueCount,@ParameterName=N'@MaxSqlTextZeichen',
              @ParameterValue=@MaxSqlTextZeichen,@LargestRequiredCharacters=@LargestRequiredCharacters,
              @PrintMeldungen=@PrintMeldungen;

        SELECT @CandidateRowCount = COUNT_BIG(*) FROM [#QueryStoreRuntimeStats_Result];
        SET @HasMoreRows = CONVERT(bit, CASE WHEN @CandidateRowCount > @EffectiveMaxZeilen THEN 1 ELSE 0 END);
        SET @RowCount = CASE WHEN @CandidateRowCount > @EffectiveMaxZeilen
                             THEN @EffectiveMaxZeilen ELSE @CandidateRowCount END;

        IF @RowCount = 0 AND EXISTS (SELECT 1 FROM [#QueryStoreRuntimeStats_Errors])
        BEGIN
            SET @StatusCode = 'AVAILABLE_LIMITED';
            SELECT TOP (1)
                  @ErrorNumber = [ErrorNumber]
                , @ErrorMessage = [ErrorMessage]
            FROM [#QueryStoreRuntimeStats_Errors]
            ORDER BY [DatabaseName];
        END
        ELSE IF @IsPartial = 1
            SET @StatusCode = 'AVAILABLE_LIMITED';
    END;

    INSERT [#QueryStoreRuntimeStats_Export]
    SELECT TOP (@EffectiveMaxZeilen) [r].*
        FROM [#QueryStoreRuntimeStats_Result] AS [r]
        ORDER BY
              CASE WHEN @Sortierung = 'LAST_EXECUTION' THEN [LastExecutionTimeUtc] END DESC
            , CASE WHEN @Sortierung = 'CPU_TOTAL' THEN [TotalCpuMs]
                   WHEN @Sortierung = 'DURATION_TOTAL' THEN [TotalDurationMs]
                   WHEN @Sortierung = 'READS_TOTAL' THEN [TotalLogicalReads]
                   WHEN @Sortierung = 'WRITES_TOTAL' THEN [TotalLogicalWrites]
                   WHEN @Sortierung = 'EXECUTIONS' THEN [ExecutionCount]
                   WHEN @Sortierung = 'MEMORY_MAX' THEN [MaxMemoryGrantKb]
                   WHEN @Sortierung = 'TEMPDB_TOTAL' THEN [TotalTempdbKb]
                   WHEN @Sortierung = 'LOG_BYTES_TOTAL' THEN [TotalLogBytes] END DESC
            , [LastExecutionTimeUtc] DESC
            , [QueryStoreDatabaseName]
            , [QueryId]
            , [PlanId];

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT
                  N'QueryStoreRuntimeStats' AS [resultName]
                , 1 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @IsPartial AS [isPartial]
                , @MaxZeilen AS [requestedMaxRows]
                , @RowCount AS [returnedRows]
                , @HasMoreRows AS [resultLimited]
                , @HasMoreRows AS [hasMoreRows]
                , @VonUtc AS [fromUtc]
                , @BisUtc AS [toUtc]
                , @Sortierung AS [sort]
                , @ErrorNumber AS [errorNumber]
                , @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @DataJson nvarchar(max) =
        (
                SELECT
                      [r].[QueryStoreDatabaseId],[r].[QueryStoreDatabaseName],[r].[QueryId],[r].[PlanId]
                    , [r].[QueryHash],[r].[QueryPlanHash],[r].[ObjectId],[r].[ObjectName]
                    , [r].[ExecutionTypeDesc],[r].[FirstExecutionTimeUtc],[r].[LastExecutionTimeUtc]
                    , [r].[ExecutionCount],[r].[TotalDurationMs],[r].[AverageDurationMs]
                    , [r].[TotalCpuMs],[r].[AverageCpuMs],[r].[TotalLogicalReads],[r].[AverageLogicalReads]
                    , [r].[TotalLogicalWrites],[r].[AverageLogicalWrites],[r].[TotalPhysicalReads]
                    , [r].[TotalMemoryGrantKb],[r].[MaxMemoryGrantKb],[r].[TotalRowCount]
                    , [r].[TotalLogBytes],[r].[TotalTempdbKb],[r].[SourceType],[r].[SourceObject]
                    , [r].[CapturedAtUtc],[r].[EvidenceScope],[r].[QuerySqlTextCharacters]
                    , [r].[QuerySqlTextBytes],[r].[QuerySqlTextIsTruncated],[r].[QuerySqlText]
                    , [r].[QueryPlanStatus],[r].[QueryPlanCharacters],[r].[QueryPlanBytes]
                    , CONVERT(nvarchar(max),[r].[QueryPlan]) AS [QueryPlan]
                    , [r].[QueryPlanTextFallback],[r].[EvidenceLimit]
                FROM [#QueryStoreRuntimeStats_Export] AS [r]
                ORDER BY
                      CASE WHEN @Sortierung = 'LAST_EXECUTION' THEN [LastExecutionTimeUtc] END DESC
                    , CASE WHEN @Sortierung = 'CPU_TOTAL' THEN [TotalCpuMs]
                           WHEN @Sortierung = 'DURATION_TOTAL' THEN [TotalDurationMs]
                           WHEN @Sortierung = 'READS_TOTAL' THEN [TotalLogicalReads]
                           WHEN @Sortierung = 'WRITES_TOTAL' THEN [TotalLogicalWrites]
                           WHEN @Sortierung = 'EXECUTIONS' THEN [ExecutionCount]
                           WHEN @Sortierung = 'MEMORY_MAX' THEN [MaxMemoryGrantKb]
                           WHEN @Sortierung = 'TEMPDB_TOTAL' THEN [TotalTempdbKb]
                           WHEN @Sortierung = 'LOG_BYTES_TOTAL' THEN [TotalLogBytes] END DESC
                    , [LastExecutionTimeUtc] DESC
                    , [QueryStoreDatabaseName]
                    , [QueryId]
                    , [PlanId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        DECLARE @WarningsJson nvarchar(max) =
            (SELECT [DatabaseName] AS [databaseName], [StatusCode] AS [code],
                    [ErrorNumber] AS [errorNumber], [ErrorMessage] AS [message]
             FROM [#QueryStoreRuntimeStats_Errors] ORDER BY [DatabaseName]
             FOR JSON PATH, INCLUDE_NULL_VALUES);

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"runtimeStats":', COALESCE(@DataJson, N'[]')
            , N',"warnings":', COALESCE(@WarningsJson, N'[]')
            , N'}'
        );
    END;

    IF @ResultSetArtNormalisiert = 'RAW'
    BEGIN
        SELECT
              N'USP_QueryStoreRuntimeStats' AS [ModuleName]
            , @CollectionTimeUtc AS [CollectionTimeUtc]
            , @StatusCode AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , @RowCount AS [RowCount]
            , @HasMoreRows AS [ResultLimited]
            , CASE WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) >= 16
                   THEN N'VIEW DATABASE PERFORMANCE STATE'
                   ELSE N'VIEW DATABASE STATE' END AS [RequiredPermission]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage]
            , CONCAT(N'Zeitraum UTC: ', CONVERT(nvarchar(30), @VonUtc, 126),
                     N' bis ', CONVERT(nvarchar(30), @BisUtc, 126),
                     N'; Deep=', @Deep) AS [Detail];

        SELECT [r].*
        FROM [#QueryStoreRuntimeStats_Export] AS [r]
        ORDER BY
              CASE WHEN @Sortierung = 'LAST_EXECUTION' THEN [LastExecutionTimeUtc] END DESC
            , CASE WHEN @Sortierung = 'CPU_TOTAL' THEN [TotalCpuMs]
                   WHEN @Sortierung = 'DURATION_TOTAL' THEN [TotalDurationMs]
                   WHEN @Sortierung = 'READS_TOTAL' THEN [TotalLogicalReads]
                   WHEN @Sortierung = 'WRITES_TOTAL' THEN [TotalLogicalWrites]
                   WHEN @Sortierung = 'EXECUTIONS' THEN [ExecutionCount]
                   WHEN @Sortierung = 'MEMORY_MAX' THEN [MaxMemoryGrantKb]
                   WHEN @Sortierung = 'TEMPDB_TOTAL' THEN [TotalTempdbKb]
                   WHEN @Sortierung = 'LOG_BYTES_TOTAL' THEN [TotalLogBytes] END DESC
            , [LastExecutionTimeUtc] DESC
            , [QueryStoreDatabaseName]
            , [QueryId]
            , [PlanId];

        SELECT * FROM [#QueryStoreRuntimeStats_Errors] ORDER BY [DatabaseName];
    END
    ELSE IF @ResultSetArtNormalisiert = 'CONSOLE'
    BEGIN
        SELECT
              N'Query Store Runtime Stats' AS [Ergebnis]
            , @CollectionTimeUtc AS [Stand_UTC]
            , @StatusCode AS [Status]
            , @RowCount AS [Zeilen]
            , @HasMoreRows AS [Ergebnis_begrenzt]
            , @VonUtc AS [Von_UTC]
            , @BisUtc AS [Bis_UTC]
            , @ErrorMessage AS [Hinweis];

        SELECT
              N'Query-Store-Abfrage' AS [Ergebnis]
            , [r].[QueryStoreDatabaseName] AS [QueryStore_Datenbank]
            , [r].[QueryId] AS [Query_ID]
            , [r].[PlanId] AS [Plan_ID]
            , [r].[ObjectName] AS [Objekt]
            , [r].[ExecutionTypeDesc] AS [Execution_Type]
            , [r].[ExecutionCount] AS [Ausführungen]
            , CONCAT(CONVERT(varchar(50), [r].[TotalCpuMs]), N' ms') AS [CPU_gesamt]
            , CONCAT(CONVERT(varchar(50), [r].[AverageCpuMs]), N' ms') AS [CPU_durchschnitt]
            , CONCAT(CONVERT(varchar(50), [r].[TotalDurationMs]), N' ms') AS [Dauer_gesamt]
            , CONCAT(CONVERT(varchar(50), [r].[AverageDurationMs]), N' ms') AS [Dauer_durchschnitt]
            , [r].[TotalLogicalReads] AS [Logical_Reads_gesamt]
            , [r].[AverageLogicalReads] AS [Logical_Reads_durchschnitt]

            , [r].[QueryId] AS [Query_ID_Memory]
            , CONCAT(CONVERT(varchar(50), [r].[MaxMemoryGrantKb] / 1024.0), N' MB') AS [Max_Memory_Grant]
            , CONCAT(CONVERT(varchar(50), [r].[TotalTempdbKb] / 1024.0), N' MB') AS [TempDB_gesamt]
            , [r].[LastExecutionTimeUtc] AS [Letzte_Ausführung_UTC]
            , [r].[QuerySqlText] AS [SQL_Text]
            , [r].[QueryPlan] AS [Query_Plan]
        FROM [#QueryStoreRuntimeStats_Export] AS [r]
        ORDER BY
              CASE WHEN @Sortierung = 'LAST_EXECUTION' THEN [LastExecutionTimeUtc] END DESC
            , CASE WHEN @Sortierung = 'CPU_TOTAL' THEN [TotalCpuMs]
                   WHEN @Sortierung = 'DURATION_TOTAL' THEN [TotalDurationMs]
                   WHEN @Sortierung = 'READS_TOTAL' THEN [TotalLogicalReads]
                   WHEN @Sortierung = 'WRITES_TOTAL' THEN [TotalLogicalWrites]
                   WHEN @Sortierung = 'EXECUTIONS' THEN [ExecutionCount]
                   WHEN @Sortierung = 'MEMORY_MAX' THEN [MaxMemoryGrantKb]
                   WHEN @Sortierung = 'TEMPDB_TOTAL' THEN [TotalTempdbKb]
                   WHEN @Sortierung = 'LOG_BYTES_TOTAL' THEN [TotalLogBytes] END DESC
            , [LastExecutionTimeUtc] DESC
            , [QueryStoreDatabaseName]
            , [QueryId]
            , [PlanId];

        SELECT
              N'Query-Store-Warnung' AS [Ergebnis]
            , [DatabaseName] AS [Datenbank]
            , [StatusCode] AS [Status]
            , [ErrorNumber] AS [Fehlernummer]
            , [ErrorMessage] AS [Meldung]
        FROM [#QueryStoreRuntimeStats_Errors]
        ORDER BY [DatabaseName];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#QueryStoreRuntimeStats_Export'
            , @ResultLabel=N'QueryStoreRuntimeStats'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#QueryStoreRuntimeStats_Export'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

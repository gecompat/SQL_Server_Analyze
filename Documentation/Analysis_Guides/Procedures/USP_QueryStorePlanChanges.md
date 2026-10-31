# [monitor].[USP_QueryStorePlanChanges]

**Bereich:** Query Store<br>
**Zweck:** Findet Queries mit mehreren Query-Store-Plänen und zeigt Compile- sowie Nutzungsmetadaten.<br>
**Beobachtungsart:** persistierte, retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Queries besitzen mehrere gespeicherte Pläne, und wodurch unterscheiden sich deren Lebenszyklus und Compilekontext?** Sie unterstützt die Entscheidung, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

`EXEC [monitor].[USP_QueryStorePlanChanges] @Hilfe = 1;` beschreibt alle Parameter, Filter- und Ausgabeoptionen sowie Beispielaufrufe direkt in der Procedure.

```sql
EXEC [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @NurMehrerePlaene = 1,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@QueryStoreDatabaseNames` | `nvarchar(max)` | `NULL` | Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]&#124;[OtherDatabase]'; &#124; trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen. |
| `@QueryStoreDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert. |
| `@HighImpactConfirmed` | `bit` | `0` | ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |
| `@ReferencedDatabaseNames` | `nvarchar(max)` | `NULL` | ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; &#124; trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein; Teile 3/4 werden nicht gesondert geprüft. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus. Der Filter wirkt auf die Summaryaggregation; der Planexport enthält anschließend alle gespeicherten Pläne der ausgewählten Datenbank-/Querykeys. |
| `@ReferencedDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert. Der Filter wirkt auf die Summaryaggregation; der Planexport enthält anschließend alle gespeicherten Pläne der ausgewählten Datenbank-/Querykeys. |
| `@QueryId` | `bigint` | `NULL` | Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch. |
| `@QueryHash` | `binary(8)` | `NULL` | Ausgelassen/NULL: kein Hashfilter. Acht Byte als Binärwert übergeben, zum Beispiel 0x0123456789ABCDEF; exakter Vergleich ohne zusätzliche Werte- oder Existenzprüfung. SQL-Typkonvertierungen erfolgen vor dem Procedurekörper. |
| `@VonUtc` | `datetime2(7)` | `NULL` | NULL ohne Zeitfilter. Sonst skalarer UTC-Grenzzeitpunkt; Query qualifiziert, wenn ein Plan last_compile_start_time &gt;= Wert ODER last_execution_time &gt;= Wert erfüllt. Keine relative Stunde/obere Grenze; Plandetails bleiben zeitlich unbeschränkt. Als datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T12:00:00.0000000 in UTC übergeben; keine Zeitzonenumrechnung. Keine Leerzeichenfolge als Datum verwenden. |
| `@NurMehrerePlaene` | `bit` | `1` | 1 und NULL verlangen HAVING COUNT_BIG(*)&gt;1; NULL wird nicht coalesced. 0 schließt auch Queries mit genau einem Plan ein. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. Gezählt werden Planzeilen nach Zeit-/Referenzfilter der Summaryaggregation; nicht zwingend gleichzeitig aktive oder verschiedene Planhashes. |
| `@MitPlanXml` | `bit` | `0` | 1 fordert gespeicherte XML für alle lokal gesammelten Pläne an, parst/exportiert vor globalem Querylimit; Deep-Prüfung. 0 unterdrückt Ausgabe/Parsing mit NOT_REQUESTED. NULL unterdrückt ebenfalls, Status PENDING. Referenzfilter können XML unabhängig vom Export lesen. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. Gespeicherter historischer Showplan, kein aktueller Laufzeitplan. Ungültiges XML bleibt als Rohtext mit Fehler-/Partialhinweis erhalten. |
| `@AnalyseModus` | `varchar(16)` | `'TOP'` | Ausgelassen/NULL: TOP. Nach äußerem Trimmen von U+0020 und Großschreibungsnormalisierung sind genau TOP und VOLL erlaubt: TOP verwendet lokale N+1-Querykandidaten und das globale Querylimit; VOLL aktiviert QUERY_STORE_DEEP, hebt @MaxZeilen aber nicht auf. Leer, nur Leerzeichen oder andere Werte sind ungültig. Deep wird außerdem durch @MitPlanXml=1, ein normalisiertes Zeilenlimit über 1000 (einschließlich NULL/0 unbegrenzt) oder einen nicht-NULL Referenzfilter aktiviert; @VonUtc allein aktiviert Deep nicht. |
| `@MaxZeilen` | `int` | `100` | Positiv: globales Limit an Query-Summaryzeilen. NULL/0 unbegrenzt; negativ ungültig. Je Quelle lokale N+1-Kandidaten (bei int.MaxValue N ohne Überlauf), danach globale Sortierung LastExecutionTimeUtc DESC, LastCompileTimeUtc DESC; gleiche Sortwerte nicht eindeutig. Limit zählt Queries, nicht Pläne; alle Pläne der Querykeys bleiben. &gt;1000 sowie NULL/0 unbegrenzt aktivieren Deep. |
| `@MaxSqlTextZeichen` | `int` | `4000` | Begrenzt nur QuerySqlText in Unicode-Zeichen/SC-Codepoints, nicht Grapheme und nicht Plan-XML. NULL/0 vollständig; negativ ungültig. Projektion/Truncationbewertung vor globaler Querybegrenzung. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Ausgelassen: CONSOLE. Nach U+0020-Trim/Großschreibung sind genau vier Werte erlaubt: RAW liefert vier Resultsets (Metadaten, Querysummaries, Plandetails, Warnungen); CONSOLE liefert die Querysummary mit Ergebnislabel, bei Leere eine Hinweiszeile; TABLE schreibt nur die angeforderte nichtleere Teilmenge queries/plans in geprüfte lokale Temp-Ziele; NONE unterdrückt normale Fachresultsets. JSON ist unabhängig. NULL, leer, nur Leerzeichen und andere Werte sind im normalen Analysepfad ungültig. Der TABLE-Preflight läuft bereits vor Hilfe und Fachvalidierung. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur TABLE. Nichtleerer Wert außerhalb TABLE löst vor Hilfe/Normalvalidierung Fehler aus. NULL/leer sind im TABLE-Aufruf ungültig. Erforderlich ist ein nichtleeres JSON-Objekt mit einem oder beiden Schlüsseln queries/plans; Werte sind unterschiedliche, vorhandene, leere lokale #Temp-Tabellen mit genau einer beliebigen Seed-Spalte. Resultsetnamen werden exakt und case-sensitiv geprüft; doppelte Namen, doppelte Ziele, unbekannte Namen, Nicht-Stringwerte, Zielnamen &gt;116 Zeichen, ##-Ziele und Namen mit #Monitor-Präfix sind ungültig. Eine Seed-Zeile ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das jeweilige Ergebnisschema. queries bezeichnet die begrenzte Querysummary, plans alle gespeicherten Pläne ihrer ausgewählten Querykeys. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt JSON unabhängig von ResultSetArt. 0 oder NULL deaktiviert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. Die JSON-Objekte heißen meta (Metadaten), queries (begrenzte Summaries), plans (alle Pläne ausgewählter Querykeys), warnings (Warnungen). |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Parameter für JSON mit meta, queries, plans und warnings; beim Eintritt NULL, nur bei @JsonErzeugen=1 befüllt. Zum Empfang eine nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Ausgelassen wird kein Ergebnis an den Aufrufer zurückgegeben; ein Eingabewert wird überschrieben. Bei Hilfe bleibt NULL; bei einem ungefangenen THROW besteht keine Zusage einer OUTPUT-Rückübertragung. Summaries sind global begrenzt, Pläne vollständig je ausgewähltem Querykey. |
| `@PrintMeldungen` | `bit` | `1` | ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |
| `@Hilfe` | `bit` | `0` | 1 gibt Hilfe aus und kehrt vor normaler Parameterprüfung/Datenbankverarbeitung zurück. Typbindung bleibt erforderlich; frühe TABLE-Mapping-Prüfung läuft vorher. 0/NULL normale Ausführung. @Json beim Eintritt auch für Hilfe NULL; PrintMeldungen steuert Hilfe-PRINTs nicht. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |

```sql
EXEC [monitor].[USP_QueryStorePlanChanges]
      @Hilfe = 1;
```

```sql
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

EXEC [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = @ExampleVonUtc
    , @MaxZeilen = 100
    , @ResultSetArt = 'RAW';
```

```sql
DECLARE @ExampleJson nvarchar(max);
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

EXEC [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = @ExampleVonUtc
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @ExampleJson OUTPUT;

SELECT @ExampleJson AS [Json];
```

```sql
CREATE TABLE [#QueryStorePlanChanges_HelpQueries]([Seed] int NULL);
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

BEGIN TRY
    EXEC [monitor].[USP_QueryStorePlanChanges]
          @QueryStoreDatabaseNames = N'[ExampleDatabase]'
        , @VonUtc = @ExampleVonUtc
        , @MaxZeilen = 100
        , @ResultSetArt = 'TABLE'
        , @ResultTablesJson = N'{"queries":"#QueryStorePlanChanges_HelpQueries"}';

    SELECT * FROM [#QueryStorePlanChanges_HelpQueries];
    DROP TABLE IF EXISTS [#QueryStorePlanChanges_HelpQueries];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#QueryStorePlanChanges_HelpQueries];
    THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `queries` mit 22 Feldern und `plans` mit 28 Feldern. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

RAW, CONSOLE, TABLE und JSON lesen denselben global begrenzten Queryexport. NULL oder 0 bei `@MaxZeilen` bedeutet unbegrenzt; negative Werte sind ungültig. Die Auswahl erfolgt nach `LastExecutionTimeUtc` und anschließend `LastCompileTimeUtc`, jeweils absteigend. Gleiche Sortwerte erlauben mehrere gültige Auswahlen. Die Planmenge wird anhand der tatsächlich exportierten Kombination aus `QueryStoreDatabaseId` und `QueryId` eingeschränkt, nicht durch eine zweite TOP-Auswahl. Das Zeilenlimit zählt Queries; es ist kein eigenständiges Limit für einzelne Planzeilen.

Alle sieben Summary- und neun Plantextspalten sind explizit `SQL_Latin1_General_CP1_CS_AS` collatiert. Beide `QueryStoreDatabaseName`-Spalten bleiben NOT NULL, die übrigen Felder sind nullable; beide Exporte besitzen keine Identity. Gesamtstatus, `hasMoreRows`, XML-Bewertung und Truncationwarnungen werden vor der globalen Begrenzung aus der lokal mit N+1 gesammelten Menge ermittelt.

## Eine Zeile bedeutet

Summary-Zeilen entsprechen Queries; Planzeilen entsprechen jeweils einer Query-Store-Plan-ID.

## So lesen

Vergleichen Sie PlanCount, Distinct Plan Hashes, Compile-/Executionzeiten, Engine-/Compatibility-Kontext und Forced-Status.

## Warum kann das problematisch sein?

Ein neuer Plan kann andere Kosten, Parallelität oder Zugriffspfade besitzen und zeitlich mit einer Regression zusammenfallen.

## Wann ist es kein Problem?

Mehrere Planzeilen mit demselben Hash oder alte, nicht mehr ausgeführte Pläne sind nicht automatisch relevant.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Vier PlanIds, aber nur zwei Hashes; einer seit Monaten inaktiv. Untersuchen Sie Aktive Varianten mit Runtime Stats, Regressionen und Planvergleich.

**Ähnlich aussehender Gegenfall:** Mehrere Planzeilen mit demselben Hash oder alte, nicht mehr ausgeführte Pläne sind nicht automatisch relevant. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Query Store kann nutzbar sein, obwohl das gewählte Fenster leer ist. Prüfen Sie zuerst Capturemodus, Read-only-Status, Retention und UTC-Fenster.

Für `USP_QueryStorePlanChanges` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, nur Queries mit mehreren Plänen, TOP 100 und `@MitPlanXml = 0`. `@VonUtc` ist standardmäßig NULL und setzt damit keine untere Zeitgrenze. |
| Teuerster Pfad | Viele Datenbanken, `VOLL`/unbegrenztes Limit, weit zurückliegendes `@VonUtc`, Plan XML und Referenzdatenbank-/Regexfilter mit XML-Shredding. |
| Haupttreiber | Zahl gewählter Query Stores, Queries und zugehöriger Pläne, die für Mehrplanerkennung gruppiert werden. `@VonUtc` begrenzt Compile-/Ausführungsmetadaten vor der Gruppierung; Referenzdatenbank-/Regexfilter können zusätzliche Showplanarbeit verursachen. Eine obere Zeitgrenze besitzt die Procedure nicht. |
| Skalierung | Aufwand wächst mit Queries und gefilterten Planvarianten seit `@VonUtc`. Plan-XML-Ausgabe oder Referenzfilter erhöhen XML-CPU, Speicher und Transfer. |
| Ressourcen | CPU/I/O auf Query-Store-Query-, Plan- und Textkatalogen, TempDB/Arbeitsspeicher für Gruppierung/Ranking; optional Plan-XML-Materialisierung. |
| Begrenzungswirkung | Datenbank, `@VonUtc`, QueryId/-Hash begrenzen die Quelle. Lokales N+1 wirkt erst nach Planaggregation und Ranking; die einmalige globale TOP-Auswahl begrenzt danach Queries in allen vier Ausgabearten und bestimmt die zugehörigen Planzeilen. Referenzfilter müssen Plan XML bereits vor dem TOP prüfen. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `QUERY_STORE_CURRENT`, `QUERY_STORE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, Queryselektor oder jüngerer Start, TOP 100 und kein XML. `VOLL`, Plan XML, Referenzfilter oder >1000/unbegrenzt nur nach Deep-Gate. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierte, retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Queries besitzen mehrere gespeicherte Pläne, und wodurch unterscheiden sich deren Lebenszyklus und Compilekontext?

### Technischer Hintergrund

`sys.query_store_plan` speichert PlanId, Plan Hash, Engine Version, Compatibility, Compilezeiten, IsParallel, Forced-Status und Plan XML. Mehrere PlanIds können strukturell gleichen Plan Hash besitzen; Recompile oder Kontextänderung kann neue Zeilen erzeugen.

### Datenkette

`sys.database_query_store_options`, `sys.objects`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.schemas`, `sys.sp_executesql`.

### Source Select

Planwechsel entstehen aus Query, Text und den dazugehörigen Planzeilen:

```sql
SELECT
      [q].[query_id]
    , [q].[query_hash]
    , COUNT_BIG(*) AS [PlanCount]
    , MIN([p].[initial_compile_start_time]) AS [FirstPlanCompile]
    , MAX([p].[last_compile_start_time]) AS [LastPlanCompile]
    , MAX([p].[last_execution_time]) AS [LastPlanExecution]
FROM [sys].[query_store_query] AS [q] WITH (NOLOCK)
JOIN [sys].[query_store_plan] AS [p] WITH (NOLOCK)
  ON [p].[query_id] = [q].[query_id]
WHERE [p].[last_compile_start_time] >= @VonUtc
   OR [p].[last_execution_time] >= @VonUtc
GROUP BY [q].[query_id], [q].[query_hash]
HAVING COUNT_BIG(*) > 1;
```

**Wichtig für die Eigenlast:** Setzen Sie Datenbank und Zeitfenster vor Plananzahl und Text- beziehungsweise XML-Anreicherung. Die Procedure materialisiert Plan-XML für die lokal gesammelte Kandidatenmenge vor der globalen Ausgabegrenze; mehrere Pläne sind zunächst nur ein Befund, keine Regression.

### Zeit- und Scope-Modell

Exakte `@ReferencedDatabaseNames` werden mit dem Parser der Frameworkdatenbank geprüft und in den dynamischen Quellabfragen über dessen dreigliedrigen Namen aufgelöst. Der Frameworkname wird vor `USE` aus `master.sys.databases` mit `NOLOCK` gelesen und mit `QUOTENAME` geschützt. Die Liste filtert Datenbankreferenzen im Showplan, nicht die Query-Store-Quelldatenbanken. `NULL` lässt diesen Referenzfilter weg; eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Gültige doppelte Namen bleiben erlaubt und vervielfachen wegen `EXISTS` keine Zeilen. Die dekodierten XML-Namen werden weiterhin mit der expliziten Framework-CS-Collation verglichen; LIKE- und Regexpfade behalten ihre bisherigen Verträge.

Die Auswertung berücksichtigt den persistierten Planbestand innerhalb der Query-Store-Retention. `@VonUtc` behält Planzeilen, deren letzte Kompilierung oder letzte Ausführung die untere Grenze erreicht; Referenzfilter wirken ebenfalls vor der Summaryaggregation. Für die ausgewählten Querykeys enthält `plans` anschließend alle gespeicherten Planzeilen. Deshalb kann die ausgegebene Plananzahl bei Zeit- oder Referenzfiltern von `PlanCount` abweichen. Last Execution zeigt Aktivität, aber keine dauerhafte Gültigkeit.

### Bewertung und Gegenprobe

Vergleichen Sie PlanCount, DistinctPlanHashCount, Compile-/Executionzeit, Engine/Compatibility, Forced-Status und Runtimewerte je Plan. Ein neuer Plan ist erst bei abweichender Wirkung relevant.

### Typische Fehlinterpretation

Mehrere Pläne bedeuten nicht automatisch Parameter Sensitivity oder Regression. Ein alter nie mehr ausgeführter Plan kann historisch, aber aktuell irrelevant sein.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Runtime Stats je Plan, Regressions, Forced Plans und Showplanvergleich.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#4-monitorusp_querystoreplanchanges)

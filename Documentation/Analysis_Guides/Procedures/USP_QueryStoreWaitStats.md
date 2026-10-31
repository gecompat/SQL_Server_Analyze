# [monitor].[USP_QueryStoreWaitStats]

**Bereich:** Query Store<br>
**Zweck:** Aggregiert historische Query-Store-Waitkategorien je Query und Plan.<br>
**Beobachtungsart:** persistierte, retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche groben Waitkategorien dominierten historisch je Query-Store-Plan?** Sie unterstützt die Entscheidung, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

EXEC [monitor].[USP_QueryStoreWaitStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @VonUtc = @ExampleVonUtc,
      @BisUtc = @ExampleBisUtc,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@QueryStoreDatabaseNames` | `nvarchar(max)` | `NULL` | Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]&#124;[OtherDatabase]'; &#124; trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen. |
| `@QueryStoreDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert. |
| `@HighImpactConfirmed` | `bit` | `0` | ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |
| `@ReferencedDatabaseNames` | `nvarchar(max)` | `NULL` | ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; &#124; trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein; Teile 3/4 werden nicht gesondert geprüft. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus. |
| `@ReferencedDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert. |
| `@QueryId` | `bigint` | `NULL` | Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch. |
| `@QueryHash` | `binary(8)` | `NULL` | Ausgelassen/NULL: kein Hashfilter. Acht Byte als Binärwert übergeben, zum Beispiel 0x0123456789ABCDEF; exakter Vergleich ohne zusätzliche Werte- oder Existenzprüfung. SQL-Typkonvertierungen erfolgen vor dem Procedurekörper. |
| `@WaitCategory` | `nvarchar(128)` | `NULL` | ausgelassen/NULL kein Filter. Einzelner Literalwert ohne Trim, Liste, LIKE oder Regex. wait_category_desc wird mit seiner nativen Quellcollation verglichen; keine allgemeine Case-Zusage. Zusätzlich vergleicht CONVERT(nvarchar(10),wait_category) explizit mit SQL_Latin1_General_CP1_CS_AS; 03 ist nicht 3. Leer-, Leerzeichen- und unbekannte Werte sind zulässige Literalfilter. Höchstens 128 Zeichen. Kein abgeschlossener Modul-Optionskatalog: native Beschreibung oder dezimaler Kategoriencode als Text, zum Beispiel N'3', werden als Filterwert verwendet. |
| `@VonUtc` | `datetime2(7)` | `NULL` | ausgelassen/NULL wird nach Ermittlung von @BisUtc auf @BisUtc minus eine Stunde gesetzt. UTC-Start muss kleiner als @BisUtc sein, sonst INVALID_PARAMETER. Überlappung: Intervallende &gt; @VonUtc und Intervallstart &lt; @BisUtc; vollständige Intervalle, keine anteilige Kürzung. Leerwert ist keine datetime2-Eingabe. Als datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T12:00:00.0000000 in UTC übergeben; keine Zeitzonenumrechnung. Keine Leerzeichenfolge als Datum verwenden. |
| `@BisUtc` | `datetime2(7)` | `NULL` | ausgelassen/NULL = SYSUTCDATETIME(). UTC-Überlappungsfenster mit @VonUtc; Intervallende &gt; Startparameter und Intervallstart &lt; Endparameter. @VonUtc &gt;= @BisUtc ist INVALID_PARAMETER; bei NULLem @VonUtc reicht das Fenster eine Stunde zurück. DATEDIFF(HOUR,@VonUtc,@BisUtc)&gt;24 fordert QUERY_STORE_DEEP an. Leerwert ist keine datetime2-Eingabe. Als datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T12:00:00.0000000 in UTC übergeben; keine Zeitzonenumrechnung. Keine Leerzeichenfolge als Datum verwenden. |
| `@AnalyseModus` | `varchar(16)` | `'TOP'` | ausgelassen/NULL = TOP; äußeres Trim und Großschreibungsnormalisierung. Geschlossene Wertemenge: TOP sammelt lokale N+1-Kandidaten je Datenbank und begrenzt danach global; VOLL fordert QUERY_STORE_DEEP an. VOLL hebt @MaxZeilen nicht auf. Leer/Leerzeichen/andere Werte sind ungültig. |
| `@MaxZeilen` | `int` | `100` | ausgelassen verwendet diesen Wert. NULL/0 global unbegrenzt; positiver int begrenzt global nach TotalQueryWaitTimeMs DESC, LastIntervalEndUtc DESC. Je DB bis N+1 lokale Kandidaten, bei INT_MAX ohne +1. Negative Werte INVALID_PARAMETER; keine Tie-Garantie. Unbegrenzt oder &gt;1000 fordert QUERY_STORE_DEEP an. VOLL hebt das Limit nicht auf. Zähler, HasMoreRows, Textprojektion und Warnungen entstehen vor dem globalen Limit. |
| `@MaxSqlTextZeichen` | `int` | `4000` | ausgelassen verwendet diesen Wert. NULL/0 vollständiger SQL-Text; positiver Wert begrenzt Zeichen und liefert Originalzeichen/-bytes sowie Truncation-Flag. Negativ = INVALID_PARAMETER mit leerer fachlicher Exportmenge. Kürzung erzeugt bei @PrintMeldungen=1 eine technische Severity-10-Warnung. NULL/0 löst allein kein QUERY_STORE_DEEP aus. Surrogatpaare zählen als ein SC-Zeichen, keine Grapheme. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | ausgelassen verwendet diesen Wert. Nach Trim/Upper exakt RAW (Metadaten, Rohdaten, Warnungen), CONSOLE (Waitdaten und Formatierungshinweis; keine zusätzlichen Metadaten-/Warnungsgrids), TABLE (nur waitStats ins geprüfte lokale Ziel) oder NONE (keine normalen Resultsets). NULL/leer/Leerzeichen/andere Werte ungültig. JSON wird separat gesteuert. TABLE-Preflight läuft vor Hilfe und Fachvalidierung. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | außerhalb TABLE nur NULL, leer oder Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel waitStats und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema. |
| `@JsonErzeugen` | `bit` | `0` | ausgelassen/0/NULL erzeugt kein JSON. 1 erzeugt @Json mit meta, waitStats und warnings aus der Exportmenge. Unabhängig von @ResultSetArt, auch mit NONE; erweitert den Scope nicht. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung. |
| `@PrintMeldungen` | `bit` | `1` | ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |
| `@Hilfe` | `bit` | `0` | ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |

```sql
EXEC [monitor].[USP_QueryStoreWaitStats]
      @Hilfe = 1;
```

```sql
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

EXEC [monitor].[USP_QueryStoreWaitStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = @ExampleVonUtc
    , @BisUtc = @ExampleBisUtc
    , @MaxZeilen = 100
    , @ResultSetArt = 'RAW';
```

```sql
DECLARE @ExampleJson nvarchar(max);
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

EXEC [monitor].[USP_QueryStoreWaitStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = @ExampleVonUtc
    , @BisUtc = @ExampleBisUtc
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @ExampleJson OUTPUT;

SELECT @ExampleJson AS [Json];
```

```sql
CREATE TABLE [#QueryStoreWaitStats_HelpExample]([Seed] int NULL);
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

BEGIN TRY
    EXEC [monitor].[USP_QueryStoreWaitStats]
          @QueryStoreDatabaseNames = N'[ExampleDatabase]'
        , @VonUtc = @ExampleVonUtc
        , @BisUtc = @ExampleBisUtc
        , @MaxZeilen = 100
        , @ResultSetArt = 'TABLE'
        , @ResultTablesJson = N'{"waitStats":"#QueryStoreWaitStats_HelpExample"}';

    SELECT * FROM [#QueryStoreWaitStats_HelpExample];
    DROP TABLE IF EXISTS [#QueryStoreWaitStats_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#QueryStoreWaitStats_HelpExample];
    THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `waitStats` mit 25 Feldern und acht explizit Framework-collatierten Textspalten. `QueryStoreDatabaseName` und `QuerySqlTextIsTruncated` sind NOT NULL; der Export besitzt keine Identity-Spalte. RAW, CONSOLE, TABLE und JSON lesen dieselbe spät materialisierte Menge. Ein positives `@MaxZeilen` begrenzt diese Menge global nach `TotalQueryWaitTimeMs DESC, LastIntervalEndUtc DESC`; NULL und 0 bleiben unbegrenzt. Bei gleichen Sortwerten ist keine bestimmte Auswahl zwischen mehreren Aufrufen zugesichert.

Zähler, `hasMoreRows`, Status und Truncationwarnung werden vorher aus allen gesammelten lokalen N+1-Kandidaten berechnet. Negative Zeilen- oder Textlimits ergeben `INVALID_PARAMETER` mit leerer Fachmenge; die Unicodeprojektion wird bei negativem Textlimit übersprungen. NULL und 0 als Textlimit erhalten den vollständigen Text. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Query-/Plan-/Waitkategorie-/Ausführungstyp-Aggregation über gespeicherte Intervalle. `RecordedRows` ist nicht die Zahl einzelner Waits oder Ausführungen.

## So lesen

Berücksichtigen Sie Waitkategorie, Totalzeit, Maxwert, Recorded Rows, Query-/Planidentität und Zeitintervalle gemeinsam.

## Warum kann das problematisch sein?

Hohe Totalzeit zeigt kumulative Auswirkung; hoher Maxwert kann einzelne Ausreißer anzeigen. Kategorien sind gröber als Live-Waittypen.

## Wann ist es kein Problem?

Viele Recorded Rows bedeuten viele gespeicherte Messpunkte, nicht automatisch viele Ausführungen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Lock-Wait dominiert nur ein Intervall: möglicher Burst. Täglich stundenlang dominant: systematisches Problem. Prüfen Sie Runtime, Planwechsel und bei Reproduktion Live-Blocking.

**Ähnlich aussehender Gegenfall:** Viele Recorded Rows bedeuten viele gespeicherte Messpunkte, nicht automatisch viele Ausführungen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Query Store kann nutzbar sein, obwohl das gewählte Fenster leer ist. Prüfen Sie zuerst Capturemodus, Read-only-Status, Retention und UTC-Fenster.

Für `USP_QueryStoreWaitStats` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Ohne expliziten Datenbankfilter werden alle sichtbaren, geeigneten Online-Benutzerdatenbanken betrachtet; das UTC-Fenster umfasst eine Stunde und das globale TOP 100 gilt ohne Referenzdatenbankfilter. Das Einstiegsbeispiel begrenzt diesen Scope ausdrücklich auf `ExampleDatabase`. |
| Teuerster Pfad | Viele Datenbanken, `VOLL`/unbegrenztes Limit, mehr als 24 Stunden und Referenzdatenbankfilter; letzterer lädt und zerlegt gespeicherte Showplan-XML, obwohl kein Plan-XML ausgegeben wird. |
| Haupttreiber | Zahl gewählter Query Stores, überlappender Intervalle, Query-/Plan-Kombinationen und Wait-Stats-Zeilen im UTC-Fenster. Referenzdatenbankfilter lädt zusätzlich gespeicherte Showplan-XML; das abschließende TOP spart diese Vorarbeit nicht. |
| Skalierung | Aufwand wächst mit Wait-Stat-Zeilen in überlappenden Intervallen, Plänen, Waitkategorien und Datenbanken. Referenzfilter addieren Showplan-XML-Parsing; SQL-Textbreite erhöht Transfer. |
| Ressourcen | CPU und I/O auf Query-Store-Wait-/Intervalltabellen, Speicher/TempDB für Gruppierung und Sortierung; optional XML-CPU für Referenzobjekte. |
| Begrenzungswirkung | UTC-, Query- und Waitkategoriefilter wirken vor der Aggregation. Das lokale N+1 greift erst nach Gruppierung/Sortierung je Datenbank, das globale TOP anschließend; beide begrenzen nicht alle gelesenen Intervallzeilen. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `QUERY_STORE_CURRENT`, `QUERY_STORE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, eine Stunde, TOP 100 und möglichst Query-/Waitfilter. Referenzdatenbankfilter, >24 Stunden, `VOLL` oder >1000 Zeilen nur bewusst mit `QUERY_STORE_DEEP`. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierte, retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche groben Waitkategorien dominierten historisch je Query-Store-Plan?

### Technischer Hintergrund

Query Store ordnet konkrete Waittypen Kategorien zu und speichert Total/Avg/Min/Max je Plan, Intervall und Execution Type. Es erfasst Waits während Queryausführung, nicht Compile-Waits. Der Frameworkcode mittelt die gespeicherten Record-Durchschnittswerte ungewichtet und summiert vollständig einbezogene Überlappungsintervalle. Ein Intervall wird mit `end_time > @VonUtc AND start_time < @BisUtc` ausgewählt; seine Werte und Grenzen werden vollständig übernommen, ohne zeitanteilige Kürzung.

### Datenkette

`sys.database_query_store_options`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.query_store_runtime_stats_interval`, `sys.query_store_wait_stats`, `sys.sp_executesql`.

### Source Select

Waitwerte werden über Intervall und Plan bis zur Query korreliert:

```sql
SELECT
      [q].[query_id]
    , [p].[plan_id]
    , [i].[start_time]
    , [i].[end_time]
    , [ws].[wait_category_desc]
    , [ws].[total_query_wait_time_ms]
    , [ws].[avg_query_wait_time_ms]
FROM [sys].[query_store_wait_stats] AS [ws] WITH (NOLOCK)
JOIN [sys].[query_store_runtime_stats_interval] AS [i] WITH (NOLOCK)
  ON [i].[runtime_stats_interval_id] = [ws].[runtime_stats_interval_id]
JOIN [sys].[query_store_plan] AS [p] WITH (NOLOCK)
  ON [p].[plan_id] = [ws].[plan_id]
JOIN [sys].[query_store_query] AS [q] WITH (NOLOCK)
  ON [q].[query_id] = [p].[query_id]
WHERE [i].[end_time] > @VonUtc
  AND [i].[start_time] < @BisUtc;
```

**Wichtig für die Eigenlast:** Begrenzen Sie Datenbank, Zeitfenster, Waitkategorie und optional Query-ID vor Textprojektion. Query Store speichert Kategorien, nicht jeden einzelnen Engine-Waittyp.

### Zeit- und Scope-Modell

Exakte `@ReferencedDatabaseNames` werden mit dem Parser der Frameworkdatenbank geprüft und in den dynamischen Quellabfragen über dessen dreigliedrigen Namen aufgelöst. Der Frameworkname wird vor `USE` aus `master.sys.databases` mit `NOLOCK` gelesen und mit `QUOTENAME` geschützt. Die Liste filtert Datenbankreferenzen im Showplan, nicht die Query-Store-Quelldatenbanken. `NULL` lässt diesen Referenzfilter weg; eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Gültige doppelte Namen bleiben erlaubt und vervielfachen wegen `EXISTS` keine Zeilen. Die dekodierten XML-Namen werden weiterhin mit der expliziten Framework-CS-Collation verglichen; LIKE- und Regexpfade behalten ihre bisherigen Verträge.

Die Auswertung verwendet persistierte Waitkategorien innerhalb der Retention und bei aktivem Wait Capture; die Werte sind datenbank- und planbezogen. Der Beschreibungsarm von `@WaitCategory` behält die native Vergleichscollation von `wait_category_desc`. Der numerische Arm vergleicht die konvertierte Kategorienummer auf beiden Seiten mit `SQL_Latin1_General_CP1_CS_AS`, damit unterschiedliche Quell- und Frameworkcollations keinen Konflikt erzeugen. Eine führende Null ist kein numerisch normalisierter Kategorienfilter: `N'03'` ist nicht `N'3'`.

Der synthetische Vertrag Common176 liest ausschließlich eine extern vorbereitete Fixture. Ein Record pro Gruppe belegt die Feldwerte und Aggregation dieses Scopes, aber keine Wirkung unterschiedlicher Recordgewichtung. Exakte Cross-DB-Referenzlisten, Regex, Berechtigungsfehler und eine vollständige Wait-Timeline gehören nicht zu diesem positiven Fixturevertrag.

### Bewertung und Gegenprobe

Korrelieren Sie Total, Max, Recorded Rows, Execution Type und Runtime-Ausführungen. Kategorien priorisieren den Troubleshootingpfad, liefern aber keinen konkreten Blocker oder Wait Resource.

### Typische Fehlinterpretation

`RecordedRows` sind Messzeilen, keine Waitanzahl. Die Average-Spalte ist kein execution-weighted Gesamtdurchschnitt.

### Folgeanalyse

Die kanonischen [Query-Store-Wait-Details](../05_Query_Store.md#3-monitorusp_querystorewaitstats) und das [Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md) verwenden; historische Kategorien bei Bedarf mit Current Waits und Requests validieren.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#3-monitorusp_querystorewaitstats)

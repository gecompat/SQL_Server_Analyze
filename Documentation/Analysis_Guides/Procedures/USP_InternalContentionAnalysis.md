# [monitor].[USP_InternalContentionAnalysis]

**Bereich:** Server Health<br>
**Zweck:** Vergleicht Latch- und optionale Spinlockzähler über ein Sample oder zeigt kumulative Werte seit Serverstart; optional ergänzt ein Snapshot aktuell wartender Seitenrequests die Analyse.<br>
**Beobachtungsart:** kumulativ + optionale Stichprobe<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Latches, Spinlocks, Tasks oder Hot Pages zeigen interne Synchronisationskonkurrenz?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_InternalContentionAnalysis]
      @SampleSeconds = 5,
      @MitPageDetails = 0,
      @MaxZeilen = 50,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@SampleSeconds` | `tinyint` | `5` | NULL oder eine ganze Zahl 0 bis 60 Sekunden. 0 überspringt WAITFOR und zeigt positive kumulative Zähler seit Serverstart; 1–60 fordert ein Intervalldelta an. Die tatsächliche Dauer zwischen Sammelzeitpunkten wird in Sekunden gemessen und für Raten verwendet. Werte über 60 sind INVALID_PARAMETER. NULL überspringt wegen der NULL-Vergleiche die Wartezeit und liefert keine Latch-/Spinlock-Deltazeilen; Raten bleiben unbekannt. Bei positivem Sample setzt ein fallender Zähler CounterResetDetected=1 und dessen Differenz/Rate bleibt NULL; ein NULL-Zähler wird nicht als Reset markiert. Bei exakt 0 bleiben die Raten im kumulativen Modus NULL, auch wenn eine tatsächliche Dauer gemessen wurde; der Interpreter fordert für RatePerSecond ein positives angefordertes Sample. |
| `@MitSpinlocks` | `bit` | `1` | NULL, 0 oder 1. Nur 1 liest sys.dm_os_spinlock_stats vor und nach dem Sample, aggregiert gleiche Namen und berechnet deren Werte. 0/NULL überspringt diese Quelle und erzeugt keine Spinlockzeilen; Latches und Hot Pages bleiben davon unabhängig. |
| `@MitHotPages` | `bit` | `1` | 0 oder NULL überspringt die Requestquelle. Nur 1 nimmt nach dem Sample einen Snapshot anderer Requests mit PAGELATCH% oder PAGEIOLATCH% auf. DatabaseId stammt direkt aus request.database_id; der Name wird dazu nachgeschlagen und kann bei fehlender Auflösung NULL bleiben. Nur FileId und PageId werden über TRY_CONVERT aus WaitResource geparst und können bei nicht auflösbaren Angaben NULL bleiben. Der Snapshot ist zeitlich nicht identisch mit dem Counterdelta. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1. |
| `@MitPageDetails` | `bit` | `0` | NULL, 0 oder 1. Nur 1 ergänzt gültige Hot-Page-Zeilen über sys.dm_db_page_info im Modus LIMITED um Seitentyp, Objekt und Index. Die Kombination @MitPageDetails=1 mit @MitHotPages=0 ist INVALID_PARAMETER. Bei @MitHotPages=NULL löst die Hot-Page-Sammlung wegen ihrer Gleichheitsprüfung nicht aus und es entstehen trotz Detailwert 1 keine Details. 0/NULL lässt die optionalen Metadatenaufrufe aus. |
| `@MaxZeilen` | `int` | `100` | int-Eingabe: NULL oder 0 bedeutet unbegrenzt, positive Werte bis 2147483647 begrenzen Zeilen je sortiertem Fachresultset nur in RAW und JSON. Negative Werte sind INVALID_PARAMETER. CONSOLE liefert die gesamte Latch-Fachmenge ohne dieses Ausgabelimit; TABLE schreibt ebenfalls alle Latches. Die Grenze wirkt nach Sammlung und Aggregation und begrenzt weder DMV-Snapshots noch Hot-Page-Ermittlung oder Page-Info-Aufrufe. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | NULL oder Text, der nach Trim und Umwandlung in Großbuchstaben CONSOLE, RAW, TABLE oder NONE ergibt. RAW liefert Statuskontext und drei Fachresultsets. CONSOLE wird intern zu NONE normalisiert und ruft danach den Console-Helper nur für Latches auf: bei Daten eine beschriftete Latchansicht, sonst eine verständliche Leerzeile. TABLE wird ebenfalls zu NONE normalisiert und schreibt ausschließlich Latches in die Zieltabellenzuordnung; NONE unterdrückt normale Resultsets. Die direkten CONSOLE-Resultsetzweige im Procedurekörper sind dadurch nicht erreichbar. NULL/Leertext und andere Werte sind INVALID_PARAMETER. Nichtleeres @ResultTablesJson außerhalb TABLE wirft Fehler 51011. Das TABLE-Mapping wird vor Hilfe und Parameterprüfung vorbereitet. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | NULL oder ein JSON-Objekt mit genau dem Schlüssel latches und einem Stringwert für den Namen einer vorhandenen lokalen #Temp-Tabelle, etwa N'{"latches":"#InternalContentionAnalysis_HelpExample"}'. Für TABLE muss das Ziel leer sein und genau eine beliebig typisierte Seed-Spalte besitzen. NULL, nach Trim von U+0020 leere Eingabe oder fehlerhaftes Mapping scheitern am Preflight vor @Hilfe und Sammlung. Der Preflight prüft das Ziel; erst beim TABLE-Schreiben werden seine Zielspalten eingerichtet. Außerhalb TABLE sind NULL oder nach diesem Trim leere Werte zulässig, sonst wird 51011 geworfen. Globale und permanente Tabellen sowie der reservierte #Monitor-Präfix sind unzulässig. |
| `@JsonErzeugen` | `bit` | `0` | NULL, 0 oder 1. Nur 1 erzeugt zusätzlich das JSON-Dokument im OUTPUT-Parameter @Json, unabhängig vom ResultSet-Modus; NULL/0 erzeugt es nicht. Das Dokument enthält meta, latches, spinlocks und hotPages. @MaxZeilen begrenzt die drei Facharrays, nicht meta. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Bindung nvarchar(max), mit vorab deklarierter nvarchar(max)-Variable und OUTPUT zu übergeben. Zu Beginn wird die gebundene Variable auf NULL gesetzt; nur bei @JsonErzeugen=1 wird sie nach der Erfassung mit dem JSON-Dokument belegt. Kein Eingabefilter. |
| `@PrintMeldungen` | `bit` | `1` | NULL, 0 oder 1. Der aktuelle Procedurekörper liest diesen Parameter nicht; er steuert keine PRINT-Ausgabe. Die Hilfe-PRINTs werden von @Hilfe gesteuert. |
| `@Hilfe` | `bit` | `0` | NULL, 0 oder 1. Nur 1 druckt Kurzangaben zu Objekt, Sample, PageDetails, Zeilenlimit und Modi und kehrt vor Sammlung und normaler Parameterprüfung zurück. Ein TABLE-Mapping wird vor diesem Rücksprung vorbereitet. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler varchar(40)-OUTPUT-Empfang. Werte und Bedeutungen: AVAILABLE (regulär abgeschlossen ohne gesetzten Finding- oder Fehlerstatus), AVAILABLE_WITH_FINDING (Counterreset erkannt oder mindestens eine Hot-Page-Zeile), INVALID_PARAMETER (Sample über 60, negatives Zeilenlimit, ungültiger Ausgabemodus oder Seitendetails bei @MitHotPages=0), DENIED_PERMISSION (klassifizierter Berechtigungsfehler bei der Quellsammlung), ERROR_HANDLED (sonstiger abgefangener Sammlungsfehler). Zuweisung nach Erfassung und vor JSON/Resultsets. Optional zum Empfang mit @StatusCodeOut=@Empfaenger OUTPUT und einer varchar(40)-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | OUTPUT-Bindung bit. 1 kennzeichnet INVALID_PARAMETER, DENIED_PERMISSION oder ERROR_HANDLED; 0 kennzeichnet den regulären Ablauf einschließlich AVAILABLE_WITH_FINDING. Mit bit-Variable und OUTPUT binden. Bei Hilfe erfolgt keine Zuweisung. Optional zum Empfang mit @IsPartialOut=@Empfaenger OUTPUT und einer bit-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | OUTPUT-Bindung int mit passender Variable und OUTPUT. Enthält bei abgefangenem Sammlungsfehler die SQL-Fehlernummer; im regulären Ablauf und bei ungültigen Parametern bleibt sie NULL. Bei Hilfe erfolgt keine Zuweisung. Optional zum Empfang mit @ErrorNumberOut=@Empfaenger OUTPUT und einer int-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | OUTPUT-Bindung nvarchar(2048) mit kompatibler Variable und OUTPUT. Enthält ggf. den abgefangenen Fehlertext oder Parameterhinweis; im fehlerfreien Ablauf NULL. Bei Hilfe erfolgt keine Zuweisung. Optional zum Empfang mit @ErrorMessageOut=@Empfaenger OUTPUT und einer nvarchar(2048)-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung. |

### Aufrufbeispiele

Alle Example-Werte und Tabellennamen sind synthetisch.

#### RAW

~~~sql
EXEC [monitor].[USP_InternalContentionAnalysis] @SampleSeconds=5,@MitSpinlocks=1,@MitHotPages=1,@MitPageDetails=0,@MaxZeilen=50,@ResultSetArt='RAW';
~~~

#### JSON

~~~sql
DECLARE @JsonOut nvarchar(max);
EXEC [monitor].[USP_InternalContentionAnalysis] @SampleSeconds=5,@JsonErzeugen=1,@Json=@JsonOut OUTPUT,@ResultSetArt='NONE';
SELECT @JsonOut AS [Json];
~~~

#### TABLE

Die Seed-Tabelle mit einer einzelnen Dummy-Spalte wird außerhalb des TRY-Blocks angelegt. Beide Pfade räumen sie mit DROP TABLE IF EXISTS auf.

~~~sql
CREATE TABLE [#InternalContentionAnalysis_HelpExample]([Seed] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_InternalContentionAnalysis] @ResultSetArt='TABLE',@ResultTablesJson=N'{"latches":"#InternalContentionAnalysis_HelpExample"}';
    SELECT * FROM [#InternalContentionAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#InternalContentionAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#InternalContentionAnalysis_HelpExample];
    THROW;
END CATCH;
~~~

#### Hilfe

~~~sql
EXEC [monitor].[USP_InternalContentionAnalysis] @Hilfe=1;
~~~

## Resultsets und Leserichtung

Der TABLE-Vertrag schreibt ausschließlich latches in das benannte vorhandene Ziel. CONSOLE gibt nur die lesbare Latch-Fachmenge aus; beide Modi liefern kein separates Modulstatusresultset. RAW enthält den technischen Modulstatus und getrennte Fachmengen. Angefordertes JSON und die OUTPUT-Parameter stellen den technischen Kontext gemäß ihren individuellen Parameterverträgen bereit. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Alle zwölf Textspalten der lokalen Latch-, Spinlock- und Hot-Page-Arbeitstabellen
verwenden explizit `SQL_Latin1_General_CP1_CS_AS`. Der TABLE-Export `latches`
übernimmt diese Frameworkcollation für Klassenname und Messart auch bei
abweichender Server- oder `tempdb`-Collation. Ein Intervall ohne veränderte
Latchzähler liefert weiterhin ein leeres Latcharray statt erfundener Aktivität.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Spinlockklasse, einem Latch-/Hot-Page-Kandidaten, Page Detail oder Finding.

## So lesen

Betrachten Sie Delta über Sample, Klasse, Waitdauer, Hot Page, Session-/Objektkontext und Wiederholung.

Delta-, Rate- und Resetlogik verwendet die reine Funktion `monitor.TVF_InterpretContentionCounter`. Fallende Zähler liefern weder eine Differenz noch eine Rate; die Procedure setzt stattdessen `CounterResetDetected=1`.

## Warum kann das problematisch sein?

Interne Synchronisationswartezeiten können CPU-Durchsatz begrenzen, obwohl einzelne Queries unauffällig wirken.

## Wann ist es kein Problem?

Hohe kumulative Zähler ohne aktuelles Delta sind schwach.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Dieselbe Hot Page in mehreren Samples mit wachsender Waitzeit: belastbare Contention. Ein einmaliger kleiner Peak nicht. Prüfen Sie TempDB-/Indexdesign, Insertmuster und Requests.

**Ähnlich aussehender Gegenfall:** Hohe kumulative Zähler ohne aktuelles Delta sind schwach. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_InternalContentionAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Fünfsekündiges Delta aller Latchklassen und Spinlocks; danach ein Snapshot aktuell auf `PAGELATCH%`/`PAGEIOLATCH%` wartender Requests. Hot Pages sind an, `sys.dm_db_page_info` ist mit `@MitPageDetails = 0` aus. |
| Teuerster Pfad | 60 Sekunden, Spinlocks und Hot Pages an, `@MitPageDetails = 1`, unbegrenzte Ausgabe und viele gleichzeitige Page-Waiter. Jede auflösbare Hot Page wird einzeln über `sys.dm_db_page_info(...,'LIMITED')` ergänzt. |
| Haupttreiber | Zahl der Latch-/Spinlockklassen ist instanzweit begrenzt; variabel sind parallele Aufrufer und aktuelle Page-Waiter. PageDetails skaliert mit diesen Waitern, nicht mit allen Datenbankseiten. |
| Skalierung | Latch- und Spinlock-DMVs werden jeweils zweimal vollständig gelesen und gruppiert. WAITFOR dominiert die Mindestdauer; Page-Info-Aufrufe und Ergebnisaufbereitung wachsen mit dem aktuellen Hot-Page-Snapshot. |
| Ressourcen | SQLOS-DMV-CPU, kleine Temp-Tabellen, eine wartende Session und optional Metadatenzugriffe per `sys.dm_db_page_info`. Keine Benutzerseiteninhalte, XEL-Dateien oder Historientabellen werden gelesen. |
| Begrenzungswirkung | `@MaxZeilen` greift nur bei Ausgabe/JSON je Resultset. Latch-/Spinlock-Snapshots, Hot-Page-Ermittlung und optionale Page-Info-Aufrufe finden vorher statt; das Limit ist daher kein Quellkostenschutz. `@SampleSeconds` ist auf 60 begrenzt. |
| Locking und Nebenwirkungen | Read-only; WAITFOR hält die Verbindung, aber keine absichtlich über das Intervall gehaltenen Nutzdatenlocks. Page- und Requestzustand kann sich nach dem Sample bereits geändert haben. |
| Schutzmechanismus | Kein High-Impact-Gate. Das Sample ist auf 60 Sekunden begrenzt; Spinlocks, Hot Pages und insbesondere die einzelnen Page-Info-Aufrufe lassen sich separat abschalten. `@MaxZeilen` begrenzt nur die Ausgabe und ersetzt diese Opt-outs nicht. |
| Sicherer Einsatz | Fünf Sekunden, PageDetails aus, `@MaxZeilen = 50` und nur ein Sampler. PageDetails erst aktivieren, wenn wiederholt dieselbe Waitressource sichtbar ist. |
| Aussagegrenze | Das Delta zeigt interne Konkurrenz, aber noch keine verursachende Abfrage. Hot Pages werden erst nach dem Intervall als Momentaufnahme ermittelt und sind zeitlich nicht exakt identisch zum Latchdelta; kumulative Werte bei Sample 0 sind seit Start und keine aktuelle Rate. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Latches, Spinlocks, Tasks oder Hot Pages zeigen interne Synchronisationskonkurrenz?

### Technischer Hintergrund

Latches schützen interne In-Memory-Strukturen/Pages, Spinlocks sehr kurze Critical Sections ohne sofortiges Schlafen. Hohe Konkurrenz erzeugt Waits, Spins/Backoffs oder Schedulerlast. Sampling zweier kumulativer DMVs lokalisiert aktuelle Deltas; Waiting Tasks/Resource Description können Hotspots zeigen.

### Datenkette

`sys.dm_db_page_info`, `sys.dm_exec_requests`, `sys.dm_os_latch_stats`, `sys.dm_os_spinlock_stats`, `sys.dm_os_sys_info`.

### Source Select

Das kumulative Grundselect beginnt bei den serverweiten Latch-Zählern und behält nur tatsächlich beobachtete Klassen:

```sql
SELECT
      [l].[latch_class]
    , [l].[waiting_requests_count]
    , [l].[wait_time_ms]
    , [l].[max_wait_time_ms]
FROM [sys].[dm_os_latch_stats] AS [l] WITH (NOLOCK)
WHERE [l].[waiting_requests_count] > 0
ORDER BY [l].[wait_time_ms] DESC;
```

**Wichtig für die Eigenlast:** Latch-/Spinlock-Schwellen vor Detailprojektion anwenden. Request- und `dm_db_page_info`-Korrelation ist ein separater, gezielter Momentaufnahmepfad und darf nicht breit für alle historischen Counter ausgeführt werden.

### Zeit- und Scope-Modell

Die Auswertung kombiniert ein kurzes Sampledelta mit einem Tasksnapshot; ein Reset oder Neustart macht das Delta ungültig.

### Bewertung und Gegenprobe

Korrelieren Sie Delta-Waitzeit/Count, Average, Spin/Backoff, CPU, Resource/Page und wiederholte Samples. PAGELATCH an TempDB Allocation unterscheidet sich von B-Tree Last-Page Contention.

### Typische Fehlinterpretation

Hohe kumulative Latchwerte seit langem Uptime sind kein aktueller Hotspot. Undokumentierte interne Namen/Verhalten können versionsabhängig sein.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Current Waits/TempDB/Requests, Page-/Objectauflösung und versionsspezifische Microsoftguidance.

## Primärquellen

- [sys.dm_os_latch_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-latch-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQLskills Wait Types Library – vertiefende Einordnung einzelner Waittypen](https://www.sqlskills.com/help/waits/)
- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../08_Server_Health.md#15-monitorusp_internalcontentionanalysis)

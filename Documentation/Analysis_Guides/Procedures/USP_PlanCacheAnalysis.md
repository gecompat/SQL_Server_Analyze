# [monitor].[USP_PlanCacheAnalysis]

**Bereich:** Plan Cache, Orchestrator<br>
**Zweck:** Orchestriert Query Stats, Query Hash, Cache Health und optional Showplan.<br>
**Beobachtungsart:** nicht atomarer Plan-Cache-Snapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Plan-Cache-Perspektiven sollen gemeinsam für Triage oder Deep Analysis ausgeführt werden?** Sie unterstützt die Entscheidung, welche aktuell gecachten Query-/Plan-Kandidaten vertieft werden sollen und welche Historienquelle die flüchtige Cachebeobachtung bestätigen muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige Workloadhistorie; evictete Pläne, nicht gecachte Statements und Ursachen außerhalb des Plans bleiben unsichtbar. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PlanCacheAnalysis]
      @MitQueryStats = 1,
      @MaxZeilen = 100,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Aktivieren Sie Showplan erst nach Kandidatenpriorisierung.

Der gezeigte Aufruf aktiviert nur Query Stats im Modus TOP mit höchstens 100 Zeilen. Dieser Pfad erfordert keine High-Impact-Bestätigung. Die im Beispiel gesetzte Bestätigung erweitert den Umfang nicht.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@MitQueryStats` | `bit` | `1` | 1 aktiviert QueryStats, 0 deaktiviert. TOP/100 ohne Hash ist nicht per se PLAN_CACHE_DEEP geschützt. NULL aktiviert Child nicht. |
| `@MitQueryHashAnalysis` | `bit` | `0` | 1 aktiviert Hash-Child. NULL QueryHash verlangt Deep-Gate. Einzelner Hash TOP <=1000 nicht. NULL deaktiviert Child. |
| `@MitPlanCacheHealth` | `bit` | `0` | 1 aktiviert Health. TOP wird SUMMARY, VOLL wird VOLL plus Datenbankverteilung und Deep-Gate. NULL deaktiviert Child. |
| `@MitShowplanAnalysis` | `bit` | `0` | 1 aktiviert Showplan. TOP wird GEZIELT, VOLL bleibt VOLL. NULL deaktiviert Child. |
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Pipe-Liste exakter einteiliger Datenbanknamen bis 128 Zeichen. &#124; trennt außerhalb [...], ]] maskiert ]. Segmentränder getrimmt. NULL/leer/Whitespace = kein Filter. Ungültig INVALID_PARAMETER. Nicht mit wirksamem DatabaseNamePattern kombinierbar. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt master/tempdb/model/msdb aus, 1 lässt zu. NULL kann bei aktivem Scope-Child ungültig sein. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | LIKE oder Präfix like:/regex:/regexi:. Case-insensitive Präfix, außen getrimmt, Rest nicht. NULL kein Filter, leer ungültig. Nicht mit DatabaseNames kombinierbar. Regex nur SQL Server 2025 + Installations-DB Compat 170. |
| `@HighImpactConfirmed` | `bit` | `0` | 1 bestätigt einen geschützten Pfad, wenn dessen Policy eine Bestätigung verlangt. Berechtigungen und Grenzwerte gelten weiterhin. 0 bestätigt den Pfad nicht und NULL ist für die Pfadprüfung ungültig. Der Parent prüft PLAN_CACHE_DEEP bei mindestens zwei Snapshot-Consumern, wenn ein Queryhash fehlt, VOLL gewählt ist oder das Zeilenlimit unbegrenzt beziehungsweise größer als 1000 ist. Die aufgerufenen Module prüfen ihre eigenen Gates. Als Snapshot-Consumer zählen Query Stats, Query Hash und Showplan ohne direkten Planhandle. Verweigert das Parent-Gate den gemeinsamen Zugriff, laufen die Module nicht. Schlägt die erlaubte Materialisierung fehl, können die Module frisch lesen. |
| `@QueryHash` | `binary(8)` | `NULL` | Optionaler exakter Queryhashfilter für QueryStats/Hash/Showplan. Hash-Child ohne Hash braucht Deep-Gate. Einzelner Hash mit TOP/<=1000 nicht. |
| `@QueryPlanHash` | `binary(8)` | `NULL` | Optionaler exakter Planhashfilter für QueryStats/Showplan. |
| `@PlanHandle` | `varbinary(64)` | `NULL` | Optionaler Handlefilter. Showplan fügt Nicht-NULL direkt als Kandidat hinzu. |
| `@TextPattern` | `nvarchar(4000)` | `NULL` | SQL-Textfilter, Präfix like:/regex:/regexi:, sonst LIKE. Außen getrimmt, Rest nicht. Leer ungültig, keine Pipe-Liste. LIKE %/_. Regex SQL Server 2025 + Compat 170. |
| `@Sortierung` | `varchar(32)` | `'CPU_TOTAL'` | Die unterstützten Ränge hängen vom aktivierten Modul ab. QueryStats, QueryHashAnalysis und ShowplanAnalysis verstehen CPU_TOTAL für gesamte CPU, ELAPSED_TOTAL für gesamte Laufzeit, READS_TOTAL für logische Reads, EXECUTIONS für Ausführungen und SPILLS_TOTAL für Spills. QueryStats und QueryHashAnalysis unterstützen zusätzlich WRITES_TOTAL für logische Writes. QueryStats und ShowplanAnalysis unterstützen GRANT_MAX für maximalen Grant und LAST_EXECUTION für die letzte Ausführung. Nur QueryStats unterstützt CPU_AVG, ELAPSED_AVG, READS_AVG und WRITES_AVG für den jeweiligen Mittelwert je Ausführung sowie ROWS_TOTAL für die Gesamtzahl der Zeilen. Nur QueryHashAnalysis unterstützt PLAN_VARIANTS für die Zahl der Planvarianten. PlanCacheHealth verwendet den Wert nicht. NULL entspricht CPU_TOTAL. Die Empfänger trimmen Leerzeichen und normalisieren die Groß- und Kleinschreibung. Leertext und nicht unterstützte Werte sind im jeweiligen Modul ungültig. |
| `@AnalyseModus` | `varchar(16)` | `'TOP'` | TOP => QueryStats/Hash TOP, Health SUMMARY, Showplan GEZIELT. VOLL => QueryStats/Hash VOLL, Health VOLL+Datenbankverteilung, Showplan VOLL. Trim/Upper, NULL TOP, leer/sonst ungültig. |
| `@MaxZeilen` | `int` | `100` | Je Child weitergereicht. Positiv begrenzt, NULL/0 unbegrenzt, negativ Parent INVALID_PARAMETER ohne Children. Unbegrenzt/>1000 oder VOLL kann Deep-Gate auslösen. SUMMARY Health nutzt den Wert nicht. |
| `@MaxAnalyseobjekte` | `int` | `20` | Showplan-Kandidatenlimit. Positiv begrenzt, 0/NULL unbegrenzt, negativ Parent INVALID_PARAMETER. >20/unbegrenzt kann Deep-Gate auslösen. VOLL zusätzlich SHOWPLAN_XML_DEEP. |
| `@MaxDurationSeconds` | `int` | `30` | Ganzzahl von 1 bis 3600 Sekunden. Der Parent lehnt Zahlen außerhalb des Bereichs ab. Das Zeitbudget gilt für Showplan und wird zwischen Kandidaten geprüft. Es unterbricht keine laufende XML-Analyse. NULL wird im Parent nicht ausdrücklich abgefangen. Die zentrale XML-Analyse weist NULL zurück. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | RAW gibt zuerst die Resultsets der aufgerufenen Module aus, gefolgt vom Parentstatus und der Modulstatusliste. CONSOLE zeigt die beschriftete Modulstatusliste. TABLE schreibt nur moduleStatus. NONE unterdrückt die fachlichen Resultsets. Die Module erhalten bei CONSOLE, TABLE und NONE intern NONE. JSON ist separat wählbar. Leerzeichen am Rand und die Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur TABLE: Objekt exakt mit moduleStatus und Stringziel. Ziel vorhandene leere lokale #Temp mit genau einer Seed-Spalte, <=116 Zeichen, kein ##/#Monitor. Andere Modi nur NULL/leer/Whitespace, sonst 51011. Preflight vor Hilfe-Return. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt zusätzlich @Json. 0/NULL erzeugt kein Dokument. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | bei Eintritt NULL. Bei JsonErzeugen=1 Dokument mit meta, queryStats, queryHashes, planCacheHealth, showplan, modules, warnings. Nicht verfügbare Childobjekte null. OUTPUT nvarchar(max) binden. |
| `@PrintMeldungen` | `bit` | `1` | 1 aktiviert informative Meldungen der aufgerufenen Module. 0 und NULL deaktivieren diese Meldungen. Der Parent reicht den Wert weiter. |
| `@Hilfe` | `bit` | `0` | 1 druckt Hilfe und RETURN vor Validierung/Analyse. Vorher @Json=NULL, Monitor-Temp-DDL, Locktimeout, TABLE-Mapping-Preflight. 0/NULL regulärer Ablauf. |

## Aufrufbeispiele

Hilfe anzeigen.

```sql
EXEC [monitor].[USP_PlanCacheAnalysis] @Hilfe=1;
```

Modulstatus als RAW lesen.

```sql
EXEC [monitor].[USP_PlanCacheAnalysis] @MitQueryStats=1, @MitQueryHashAnalysis=0, @MitPlanCacheHealth=0, @MitShowplanAnalysis=0, @QueryHash=0x0102030405060708, @MaxZeilen=50, @ResultSetArt='RAW';
```

Nur JSON ausgeben.

```sql
DECLARE @ResultJson nvarchar(max);
EXEC [monitor].[USP_PlanCacheAnalysis] @MitQueryStats=1, @MitQueryHashAnalysis=0, @MitPlanCacheHealth=0, @MitShowplanAnalysis=0, @QueryHash=0x0102030405060708, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT;
SELECT @ResultJson AS [Json];
```

Modulstatus in eine lokale Temp-Tabelle schreiben.

```sql
CREATE TABLE #PlanCacheAnalysis_HelpExample ([Seed] int NULL);
BEGIN TRY EXEC [monitor].[USP_PlanCacheAnalysis] @MitQueryStats=1, @MitQueryHashAnalysis=0, @MitPlanCacheHealth=0, @MitShowplanAnalysis=0, @QueryHash=0x0102030405060708, @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#PlanCacheAnalysis_HelpExample"}';
SELECT * FROM #PlanCacheAnalysis_HelpExample;
DROP TABLE #PlanCacheAnalysis_HelpExample;
END TRY BEGIN CATCH DROP TABLE #PlanCacheAnalysis_HelpExample;
THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `moduleStatus`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

TABLE und CONSOLE verwenden dieselbe vollständig materialisierte Modulstatusmenge mit fünf Feldern. Die drei Textfelder besitzen explizit `SQL_Latin1_General_CP1_CS_AS`. CONSOLE ergänzt bei vorhandenen Modulzeilen die Ergebnisbeschriftung; bei leerer Menge liefert es genau die bestehende dreifeldrige Leeranzeige. RAW liefert nach den aufgerufenen Modulen den Parentstatus mit Modulname, Erhebungszeit, Statuscode, Partialitätsflag und Detail sowie die Modulstatusliste. Im JSON steht der Parentstatus in `meta.statusCode`.

Das JSON-Array `modules` verwendet dieselbe Modulstatusmenge. `REUSED_PARENT_SNAPSHOT` beschreibt die laufinterne Wiederverwendung des Query-Stats-Snapshots.

## Eine Zeile bedeutet

In TABLE und CONSOLE bedeutet eine Modulstatuszeile einen tatsächlich aufgerufenen Childpfad mit seiner Aufrufreihenfolge und seinem Invocationstatus. Die fachlichen Childresultate in RAW und JSON behalten ihre jeweilige Granularität.

## So lesen

Beachten Sie den Modulstatus und die Reihenfolge: Query Stats findet Kandidaten, Query Hash erklärt Varianten, Health bewertet den Cache und Showplan erklärt den Planinhalt.

## Warum kann das problematisch sein?

Breite XML-Analyse kann selbst CPU erzeugen und sehr viele Findings ohne Priorisierung liefern.

## Wann ist es kein Problem?

Nicht aktivierte Children fehlen absichtlich; der Default ist bewusst leichtgewichtig.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Bestimmen Sie zuerst die Queries mit der höchsten CPU-Nutzung und parsen Sie danach nur wenige relevante Pläne. Prüfen Sie deren historische Relevanz anschließend im Query Store.

**Ähnlich aussehender Gegenfall:** Nicht aktivierte Children fehlen absichtlich; der Default ist bewusst leichtgewichtig. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Im Plan Cache kann leer bedeuten: evicted, nie gecacht, recompile, falscher Datenbank-/Hashfilter oder fehlender Text-/Planzugriff.

Für `USP_PlanCacheAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

`@MaxZeilen` wird an die dafür vorgesehenen Children weitergereicht; NULL und 0 bleiben ohne Zeilenlimit. Die Modulstatusmenge wird dadurch nicht gekürzt. Ein negativer Wert wird vor der Childausführung als `INVALID_PARAMETER` abgelehnt und lässt die Modulstatusmenge leer. Ein `EXECUTED`-Eintrag bestätigt den abgeschlossenen Childaufruf; dessen fachlicher Status ist zusätzlich im Child-JSON zu lesen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Query-Stats-Child, TOP 100 und CONSOLE. Ohne QueryHash ist bereits dieser unselektierte Parentpfad `PLAN_CACHE_DEEP`-geschützt; andere Children sind aus. |
| Teuerster Pfad | Alle vier Children, `@AnalyseModus = 'VOLL'`, `@MaxZeilen = 0`, unbegrenzte Analyseobjekte und hohe `@MaxDurationSeconds`: vollständige Cachegruppierung plus Showplan-XML für viele Kandidaten. Es gibt keine Datei-, `msdb`- oder Samplingquelle. |
| Haupttreiber | Zahl der Einträge in `sys.dm_exec_query_stats`/`sys.dm_exec_cached_plans`, Breite von SQL-Text und Planattributen sowie Zahl/Größe der für Showplan ausgewählten XML-Pläne. |
| Skalierung | Benötigen mehrere Children Query Stats, materialisiert der Parent diese DMV einmal laufgebunden und reicht den Snapshot weiter. Gruppierung, Sortierung und Showplan-Shredding bleiben childbezogen; Cache Health kann unabhängig den gesamten Cache aggregieren. |
| Ressourcen | Summe der Plan-Cache-Children: Cache-DMV-/Attribut-/Textzugriff, Gruppierung/Sortierung, TempDB/Arbeitsspeicher und optional Showplan-XML-CPU/Transfer. Kein msdb-, Datei- oder Benutzerdatenscan. |
| Begrenzungswirkung | `@MaxZeilen` gilt je Child, `@MaxAnalyseobjekte` nur für Showplan. `@MaxDurationSeconds` ist dessen kooperative Deadline und begrenzt weder Query Stats noch Cache Health. Text-/Hash-/Handlefilter können früh Kandidaten reduzieren; Top-N entsteht ansonsten erst nach Cachezugriff und Sortierung. |
| Locking und Nebenwirkungen | Der Parent ändert weder Nutzdaten noch Cachekonfiguration. Childaufrufe sind nacheinander und nicht atomar; Cacheeinträge können zwischen Query Stats, Hash, Health und Showplan evicted oder neu kompiliert werden. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `PLAN_CACHE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | TOP 100, nur Query Stats, möglichst Datenbank-/Hashselektor. Danach nur den auffälligen Childpfad separat vertiefen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „nicht atomarer Plan-Cache-Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Plan-Cache-Perspektiven sollen gemeinsam für Triage oder Deep Analysis ausgeführt werden?

### Technischer Hintergrund

Der Wrapper orchestriert Query Stats, Hashgruppen, Cache Health, Details und Showplanpfade. Wenn mindestens zwei der Consumer Query Stats, Query Hash und Showplan-Kandidatenauswahl aktiv sind, materialisiert er `sys.dm_exec_query_stats` einmal laufgebunden; die Children melden `REUSED_PARENT_SNAPSHOT`. Ein breiter gemeinsamer Read wird erst nach `PLAN_CACHE_DEEP`-Freigabe ausgeführt. Plan-XML und breite Cache-Scans erhöhen CPU, Memorytransfer und Resultsetgröße.

### Datenkette

Die Datenkette besteht aus frameworkinterner Orchestrierung; die Quellen liegen in den aufgerufenen Childmodulen.

### Source Select

Kein einzelnes Grundselect wird verwendet. Benötigen mindestens zwei aktivierte Children Query Stats, liest die Procedure `sys.dm_exec_query_stats` einmal in einen lauflokalen Snapshot für `USP_QueryStats`, `USP_QueryHashAnalysis` und gegebenenfalls `USP_ShowplanAnalysis`. `USP_PlanCacheHealth` nutzt diesen Snapshot nicht; es liest `sys.dm_exec_cached_plans` unabhängig und aggregiert seinen eigenen sichtbaren Cachebestand.

**Wichtig für die Eigenlast:** Query Hash, Handle, Zeit und Analysemodus vor Showplan-XML eingrenzen. Die zentrale Einmalkopie verhindert wiederholte Query-Stats-Scans; breite XML-Analyse bleibt ein separater High-Impact-Pfad.

### Zeit- und Scope-Modell

Query Stats, Query Hash und Showplan-Kandidatenauswahl verwenden im gemeinsamen Lauf denselben `dm_exec_query_stats`-Stand. Cache Health besitzt mit `dm_exec_cached_plans` eine eigene Quelle; Plan-XML wird später planweise geladen und kann nach Eviction fehlen. Einzelaufrufe lesen immer frisch.

### Bewertung und Gegenprobe

Prüfen Sie zuerst Status und Partialität. Wechseln Sie danach von den Gesamtkosten zur Hash- und Planebene und führen Sie erst anschließend den XML-Deep-Dive aus. Begrenzen Sie Scope und `MaxRows` eng.

### Typische Fehlinterpretation

Ein leerer Detailpfad kann durch Eviction nach dem gemeinsamen Kandidatensnapshot entstehen, nicht durch fehlende frühere Ausführung. Berücksichtigen Sie Snapshot-Fallback und partielle Planstatus nicht als vollständige Cache-Evidenz.

### Folgeanalyse

Verwenden Sie für historische Fragen den Query Store und für die aktuelle Ressourcenauswirkung die Current-State-Module.

## Primärquellen

- [Plan-Cache-DMVs](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/execution-related-dynamic-management-views-and-functions-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../04_Plan_Cache.md#6-monitorusp_plancacheanalysis)
Wenn `MitShowplanAnalysis=1` aktiv ist, enthält die Showplan-Childanalyse
zusätzlich die fünf DIAG-005-Ergebnisse `planWarnings`, `optimizerContext`,
`runtimeFeedback`, `queryStoreContext` und `feedbackAndVariants`. Der
Query-Stats-Snapshot und der daraus abgeleitete Cachekontext werden innerhalb
des Orchestratoraufrufs wiederverwendet.


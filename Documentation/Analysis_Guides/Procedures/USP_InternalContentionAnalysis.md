# [monitor].[USP_InternalContentionAnalysis]

**Bereich:** Server Health<br>
**Zweck:** Analysiert Spinlocks, Latches und Hot Pages über ein begrenztes Sample.<br>
**Beobachtungsart:** kumulativ + optionale Stichprobe<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Latches, Spinlocks, Tasks oder Hot Pages zeigen interne Synchronisationskonkurrenz?** Der dokumentierte Zweck ist: Analysiert Spinlocks, Latches und Hot Pages über ein begrenztes Sample. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Kurzes Sampledelta plus Tasksnapshot; Reset/Restart macht Delta ungültig. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_InternalContentionAnalysis]
      @SampleSeconds = 5,
      @MitPageDetails = 0,
      @MaxZeilen = 50,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `latches` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Spinlockklasse, einem Latch-/Hot-Page-Kandidaten, Page Detail oder Finding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Delta über Sample, Klasse, Waitdauer, Hot Page, Session-/Objektkontext und Wiederholung betrachten.

Delta-, Rate- und Resetlogik verwendet die reine Funktion `monitor.TVF_InterpretContentionCounter`. Fallende Zähler liefern weder eine Differenz noch eine Rate; die Procedure setzt stattdessen `CounterResetDetected=1`.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Interne Synchronisationswartezeiten können CPU-Durchsatz begrenzen, obwohl einzelne Queries unauffällig wirken.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Hohe kumulative Zähler ohne aktuelles Delta sind schwach.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Dieselbe Hot Page in mehreren Samples mit wachsender Waitzeit: belastbare Contention. Ein einmaliger kleiner Peak nicht. TempDB-/Indexdesign, Insertmuster und Requests prüfen.

**Ähnlich aussehender Gegenfall:** Hohe kumulative Zähler ohne aktuelles Delta sind schwach. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_InternalContentionAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

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

Kurzes Sampledelta plus Tasksnapshot; Reset/Restart macht Delta ungültig.

### Bewertung und Gegenprobe

Delta-Waitzeit/Count, Average, Spin/Backoff, CPU, Resource/Page und wiederholte Samples korrelieren. PAGELATCH an TempDB Allocation unterscheidet sich von B-Tree Last-Page Contention.

### Typische Fehlinterpretation

Hohe kumulative Latchwerte seit langem Uptime sind kein aktueller Hotspot. Undokumentierte interne Namen/Verhalten können versionsabhängig sein.

### Folgeanalyse

Current Waits/TempDB/Requests, Page-/Objectauflösung und versionsspezifische Microsoftguidance.

## Primärquellen

- [sys.dm_os_latch_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-latch-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQLskills Wait Types Library – vertiefende Einordnung einzelner Waittypen](https://www.sqlskills.com/help/waits/)
- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../08_Server_Health.md#15-monitorusp_internalcontentionanalysis)

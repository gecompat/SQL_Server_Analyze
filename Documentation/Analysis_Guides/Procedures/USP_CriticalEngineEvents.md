# [monitor].[USP_CriticalEngineEvents]

**Bereich:** Server Health<br>
**Zweck:** Liest schwere Engine-Ereignisse aus system_health und optionalen Diagnosequellen.<br>
**Beobachtungsart:** retentionbegrenzte Ereignishistorie + Diagnostiksnapshot<br>
**Kostenklasse:** MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche kritischen Engineereignisse sind in system_health, Ring Buffers oder Diagnostikquellen erhalten?** Der dokumentierte Zweck ist: Liest schwere Engine-Ereignisse aus system_health und optionalen Diagnosequellen. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Nur erhaltene Ereignisse seit Session-/Engine-/Rollovergrenze; aktueller Diagnostikstatus. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -24, SYSUTCDATETIME());

EXEC [monitor].[USP_CriticalEngineEvents]
      @VonUtc = @ExampleVonUtc,
      @MitEventXml = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `events` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem erfassten Engine-Ereignis; SourceStatus beschreibt die Verfügbarkeit der Quelle.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Eventtyp, Severity, Zeit, Quelle, Wiederholung und Begleitsymptome vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Schwere Fehler, Schedulerprobleme oder Dumps können Engine-, Hardware- oder I/O-Risiken anzeigen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein einzelnes altes Ereignis kann bereits behoben sein; aktuelle Wiederholung entscheidet über Dringlichkeit.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Mehrere Severity-20+-Fehler in kurzer Zeit plus suspect pages sind deutlich kritischer als ein einzelnes altes Ereignis. Error Log, Integrität und Infrastruktur prüfen.

**Ähnlich aussehender Gegenfall:** Ein einzelnes altes Ereignis kann bereits behoben sein; aktuelle Wiederholung entscheidet über Dringlichkeit. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_CriticalEngineEvents` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Eventfile-Lesen MEDIUM und begrenzt; XML-Transfer opt-in.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM |
| Standardpfad | Löst den `system_health`-Eventfilepfad auf, liest bis zu 500 passende schwere Ereignisse aus dessen Rolloverdateien und parst die benötigten XML-Felder. `@MitEventXml = 0` unterdrückt nur die vollständige XML-Ausgabe. |
| Teuerster Pfad | `@MaxZeilen = 0`, vollständige Event-XML und optional `sp_server_diagnostics`; XEL-Rollover-Dateien können vor TOP breit gelesen werden. |
| Haupttreiber | Zahl/Größe der durch den Wildcardpfad erfassten XEL-Rolloverdateien und passende Events im UTC-Fenster. `sp_server_diagnostics` ist ein einzelner zusätzlicher One-Shot-Aufruf. |
| Skalierung | XEL-Lesen kann mit der Rollovermenge wachsen, auch wenn TOP nur wenige neueste Treffer behält. XML wird für die ausgewählten Events immer in Fehler-, Severity-, Komponenten- und Meldungsfelder zerlegt; vollständige XML-Ausgabe erhöht danach primär Speicher/Transfer. |
| Ressourcen | Datei-I/O über das SQL-Server-Dienstkonto, CPU/Speicher für XML-Parsing, TempDB/Transfer für zerlegte Ereignisse. |
| Begrenzungswirkung | Expliziter `@FilePath` und UTC-Fenster bestimmen die relevante Quelle; `@MaxZeilen` ist TOP im gefilterten XEL-CTE, garantiert aber keinen frühen physischen Rollover-Stopp. `@MinErrorSeverity` wirkt erst nach dem TOP/Parsing auf `error_reported`. |
| Locking und Nebenwirkungen | Keine Änderung an XE-Sessions. Filezugriff konkurriert mit Storage-I/O; Runtimequellen sind flüchtig. Ein einmaliger server_diagnostics-Aufruf liest aktuellen Zustand. |
| Schutzmechanismus | Diese Procedure besitzt trotz XEL-Lesen kein High-Impact-Gate. Schutz liefern eine konkrete Quelle, ein enges UTC-Fenster, Severity-/Eventfilter, endliches Limit sowie ausgeschaltete Voll-XML- und Server-Diagnostics-Ausgabe; TOP garantiert dennoch keinen kleinen physischen Rollover-Scan. |
| Sicherer Einsatz | Standardlimit und `@MitEventXml = 0` beibehalten; `sp_server_diagnostics` nur bei konkreter Fragestellung aktivieren und breite XEL-Läufe betrieblich abstimmen. |
| Aussagegrenze | `system_health` enthält nur konfigurierte und noch nicht gerollte Ereignisse. TOP wird vor dem Severityfilter angewandt, sodass viele neuere niedrigere Fehler ältere relevante Fehler aus dem Kandidatenset verdrängen können; der Diagnostics-One-Shot ist ein anderer Messzeitpunkt. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche kritischen Engineereignisse sind in system_health, Ring Buffers oder Diagnostikquellen erhalten?

### Technischer Hintergrund

`system_health` erfasst ausgewählte Errors, Scheduler-/Memory-/Connectivity-/Deadlock- und Diagnoseereignisse. Ring Buffers/`sp_server_diagnostics` liefern Component States und begrenzte Historie. Event XML/Datafelder sind versionsabhängig.

### Datenkette

`sys.fn_xe_file_target_read_file`, `sys.server_event_session_fields`, `sys.server_event_session_targets`, `sys.server_event_sessions`, `sys.sp_server_diagnostics`.

### Zeit- und Scope-Modell

Nur erhaltene Ereignisse seit Session-/Engine-/Rollovergrenze; aktueller Diagnostikstatus.

### Bewertung und Gegenprobe

Eventtyp, Severity/State, Timestamp, Component, Wiederholung und gleichzeitige Errorlog/OS/Clusterereignisse korrelieren. Scheduler non-yielding, Memory Error oder I/O Stall unterschiedlich behandeln.

### Typische Fehlinterpretation

Keine Zeile ist keine Entwarnung. system_health ist bewusst begrenzt und kann Rollover/Targets verlieren.

### Folgeanalyse

XE Target Runtime/Read Events, Errorlog, OS/Cluster/Storagediagnostik.

## Primärquellen

- [system_health session](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/use-the-system-health-session?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#14-monitorusp_criticalengineevents)

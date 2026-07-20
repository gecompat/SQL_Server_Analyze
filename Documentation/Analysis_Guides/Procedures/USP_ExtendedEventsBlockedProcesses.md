# [monitor].[USP_ExtendedEventsBlockedProcesses]

**Bereich:** Extended Events<br>
**Zweck:** Liest historische Blocked-Process-Reports und zerlegt blockierte sowie blockierende Prozesse.<br>
**Beobachtungsart:** retentionbegrenzte Ereignishistorie<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Blockings überschritten den konfigurierten Threshold und wurden als Reports erfasst?** Der dokumentierte Zweck ist: Liest historische Blocked-Process-Reports und zerlegt blockierte sowie blockierende Prozesse. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob die konfigurierte Ereignisquelle die gesuchte Situation erfasst hat und welche einzelne Datei, Session oder XML-Struktur anschließend vertieft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ereignisse, die nicht konfiguriert, vor Sessionstart aufgetreten oder durch Rollover/Targetgrenzen verloren gegangen sind. Ihr Zeitvertrag lautet ausdrücklich: Historische Thresholdereignisse während aktiver Capture; keine lückenlose Lockhistorie. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

EXEC [monitor].[USP_ExtendedEventsBlockedProcesses]
      @Quelle = 'AUTO',
      @VonUtc = @ExampleVonUtc,
      @MitReportXml = 0,
      @MitProcessXml = 0,
      @MaxZeilen = 100,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Jeder fachliche Lauf ist als `EXTENDED_EVENTS_FORENSICS_DEEP` geschützt. Die Bestätigung ist für das Gruppengate nötig; Zeitfenster, Quelle und Ereignislimit bleiben die relevanten Schutzgrenzen.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `reports` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Summary-Zeile = ein Report; Process-Zeile = blockierte oder blockierende Prozessdarstellung innerhalb dieses Reports.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Konfigurierten Threshold, Waitdauer, Blocker/Blocked, Ressource, Statements und Wiederholungen über Zeit vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Wiederholte Reports derselben Kette zeigen persistierendes Blocking statt eines kurzen Snapshots.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein einzelner Report knapp über dem Threshold kann ein einmaliger langsamer Vorgang sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Alle fünf Sekunden derselbe Root Blocker über zwei Minuten: starke Evidenz. Live mit `USP_CurrentBlocking` und `USP_CurrentTransactions` korrelieren.

**Ähnlich aussehender Gegenfall:** Ein einzelner Report knapp über dem Threshold kann ein einmaliger langsamer Vorgang sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Eine laufende Session kann ohne passendes Ereignis leer sein; außerdem können Target, Dateipfad, Rollover, Flushzustand und Berechtigung die Sicht einschränken.

Für `USP_ExtendedEventsBlockedProcesses` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Threshold 0, fehlende XE-Konfiguration oder abgelaufene Retention erlauben keine Entwarnung.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Event-Datei- und XML-abhängig; begrenzte Ergebnismenge und Vorfilter vor XML-Zerlegung. XEL-Dateien können dennoch vollständig gelesen werden müssen.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | AUTO sucht eine Session mit `blocked_process_report`, bevorzugt deren Eventfile und liest bis zu 200 Reports. Report-XML ist standardmäßig in der Summary enthalten, Prozess-XML nicht; beide Prozessseiten werden dennoch strukturiert aus XML extrahiert. |
| Teuerster Pfad | Unbegrenzter XEL-Wildcard- oder großer Ring-Buffer-Pfad ohne Zeitfenster, `@MitReportXml = 1` und `@MitProcessXml = 1`; Ring Buffer benötigt zusätzlich bestätigten Target-Flush. |
| Haupttreiber | XEL-Rollovermenge beziehungsweise Ring-Buffer-Größe, Zahl ausgewählter Reports und XML-Größe der blockierten/blockierenden Prozessknoten. `sys.configurations` liefert nur den aktuellen Blocked-Process-Threshold. |
| Skalierung | Die Quelle wird auf Reports/UTC gefiltert und TOP-begrenzt, danach wird jeder Report in Summary, blockierten und blockierenden Prozess zerlegt. Vollständige Prozess-XML verbreitert Resultat und Transfer, spart bei `0` aber nicht das notwendige Strukturparsing. |
| Ressourcen | Datei-I/O über das SQL-Server-Dienstkonto, CPU/Speicher für XML-Parsing, TempDB/Transfer für zerlegte Ereignisse. |
| Begrenzungswirkung | UTC-Fenster und konkrete Datei/Session sind die wichtigsten Quellgrenzen. `@MaxZeilen` begrenzt Reports vor dem Prozess-Shredding, kann aber das vorgelagerte Lesen aller passenden Rolloverdateien nicht garantieren. XML-Schalter begrenzen hauptsächlich Ausgabe. |
| Locking und Nebenwirkungen | Keine Sessionkonfiguration wird geändert. Eventfilelesen verursacht Storage-I/O; nur Ring-Buffer-Zugriff liest `sys.dm_xe_session_targets` und kann nach `@BestaetigeTargetFlush = 1` Targetpuffer flushen. Es gibt keinen `sp_server_diagnostics`-Aufruf. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `EXTENDED_EVENTS_FORENSICS_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine bekannte `ExampleSession` oder enges UTC-Fenster, beide XML-Ausgabeschalter aus, `@MaxZeilen = 100` und High-Impact-Bestätigung. Ring Buffer nur nach separater Flushentscheidung. |
| Aussagegrenze | Reports existieren nur bei konfiguriertem Threshold und aktivem Event. Ein Prozess kann im Report bereits beendet sein; gleiche SPID in mehreren Reports ist ohne Zeit/Report-ID nicht dieselbe Ausführung. Rollover und TOP begrenzen historische Vollständigkeit. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Blockings überschritten den konfigurierten Threshold und wurden als Reports erfasst?

### Technischer Hintergrund

`blocked_process_report` entsteht nur bei positivem Blocked Process Threshold und passender XE-Erfassung. XML enthält Blocked/Blocking Process, Waitresource, Lockmode und SQL-/Inputbufferkontext zum Reportzeitpunkt. Lange Blockings können mehrere Reports erzeugen.

### Datenkette

`sys.configurations`, `sys.dm_xe_session_targets`, `sys.dm_xe_sessions`, `sys.fn_xe_file_target_read_file`, `sys.server_event_session_events`, `sys.server_event_session_fields`, `sys.server_event_session_targets`, `sys.server_event_sessions`.

### Zeit- und Scope-Modell

Historische Thresholdereignisse während aktiver Capture; keine lückenlose Lockhistorie.

### Bewertung und Gegenprobe

Dauer/Anzahl, Rootblocker, offene Transaktion, Ressourcenmuster und wiederholte Reports derselben Kette korrelieren. Mehrere Reports nicht ungeprüft als verschiedene Vorfälle zählen.

### Typische Fehlinterpretation

Blocking unter Threshold, vor Sessionstart oder nach Rollover fehlt. Reportzeit ist nicht zwingend Beginn/Ende der Blockierung.

### Folgeanalyse

Current Blocking/Transactions bei Reproduktion; Deadlockanalyse bei Zyklen.

## Primärquellen

- [Extended Events](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/extended-events?view=sql-server-ver17)

[Technische Detailbeschreibung](../06_Extended_Events.md#4-monitorusp_extendedeventsblockedprocesses)

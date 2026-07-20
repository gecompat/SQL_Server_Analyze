# [monitor].[USP_ExtendedEventsAnalysis]

**Bereich:** Extended Events, Orchestrator<br>
**Zweck:** Orchestriert Inventar, Targetruntime, generische Events, Deadlocks und Blocked Processes.<br>
**Beobachtungsart:** nicht atomarer Mix aus Runtime-Snapshot und Ereignishistorie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche XE-Konfigurations-, Runtime- und Ereignisperspektiven sollen gemeinsam geprüft werden?** Der dokumentierte Zweck ist: Orchestriert Inventar, Targetruntime, generische Events, Deadlocks und Blocked Processes. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob die konfigurierte Ereignisquelle die gesuchte Situation erfasst hat und welche einzelne Datei, Session oder XML-Struktur anschließend vertieft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ereignisse, die nicht konfiguriert, vor Sessionstart aufgetreten oder durch Rollover/Targetgrenzen verloren gegangen sind. Ihr Zeitvertrag lautet ausdrücklich: Nicht atomarer Mix aus aktuellem Zustand und Targethistorie. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExtendedEventsAnalysis]
      @MitSessionInventar = 1,
      @MitTargetRuntime = 0,
      @MitEvents = 0,
      @MitDeadlocks = 0,
      @MitBlockedProcesses = 0,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `moduleStatus` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Session, Target, Event, Deadlock, Prozess, Ressource oder Blocked-Process-Report.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Inventar und Source-/Targetstatus vor Ereignisparsern lesen. Childstatus bestimmt, ob leere Fachdaten interpretierbar sind.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Deadlock- oder Blockinganalyse ohne verlässliche Quelle kann falsche Entwarnung erzeugen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Nicht aktivierte Event-Children fehlen absichtlich.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Session gestoppt und Deadlockresultset leer bedeutet „keine Evidenz erfasst“, nicht „keine Deadlocks“. Vorhandene XEL-Dateien oder Konfiguration prüfen.

**Ähnlich aussehender Gegenfall:** Nicht aktivierte Event-Children fehlen absichtlich. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Eine laufende Session kann ohne passendes Ereignis leer sein; außerdem können Target, Dateipfad, Rollover, Flushzustand und Berechtigung die Sicht einschränken.

Für `USP_ExtendedEventsAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Nur `USP_ExtendedEventsSessions` ist aktiviert. Er inventarisiert Definition und Laufzeitstatus mit `@MaxZeilen = 100`, liest aber weder Ereignisdateien noch Targetdaten. |
| Teuerster Pfad | `@MitTargetRuntime`, `@MitEvents`, `@MitDeadlocks` und `@MitBlockedProcesses` gemeinsam: Eventdatei oder Ring Buffer werden je Forensik-Child separat gelesen und XML mehrfach für unterschiedliche Granularitäten zerlegt. Targetruntime kann zusätzlich einen ausdrücklich bestätigten Target-Flush auslösen. |
| Haupttreiber | Größe und Rollover der gewählten XEL-Dateien beziehungsweise des Ring Buffers, Anzahl der Ereignisse im Zeitfenster und XML-Komplexität von Deadlock-/Blocked-Process-Reports. Das Sessioninventar ist gegenüber diesen Pfaden meist klein. |
| Skalierung | Die Children laufen nacheinander und teilen keinen materialisierten Ereignissnapshot. Drei aktivierte Ereignis-Children können dieselbe Quelle daher dreimal lesen und parsen; breite Reports erhöhen CPU, Arbeitsspeicher, TempDB und Transfer. |
| Ressourcen | Im Standard nur XE-Katalog-/Runtime-CPU. Optional kommen Datei-I/O über `sys.fn_xe_file_target_read_file`, Ring-Buffer-/Targetzugriff und XML-Shredding hinzu; `msdb` und Datenbankscans gehören nicht zu diesem Orchestrator. |
| Begrenzungswirkung | Session-/Event-/Targetfilter gelten nicht für jedes Child gleich: Inventarfilter steuern Katalogresultsets, die Forensikchildren verwenden die einzelne `@SourceExtendedEventSessionName`, Quelle, Datei und Zeitgrenzen. `@MaxZeilen` wird an Ereignischildren weitergegeben, begrenzt aber nicht zwingend das vorgelagerte Datei- und XML-Lesen; Targetruntime besitzt kein Parent-Zeilenlimit. |
| Locking und Nebenwirkungen | Keine Nutzdatenänderung. Nur der Targetruntimepfad kann durch das Lesen von `sys.dm_xe_session_targets` einen Flush bewirken; er benötigt deshalb zusätzlich `@BestaetigeTargetFlush = 1`. Die sequenziellen Childresultate sind kein atomarer Ereignissnapshot. |
| Schutzmechanismus | Ereignisforensik und Targetruntime prüfen `EXTENDED_EVENTS_FORENSICS_DEEP` über `@HighImpactConfirmed`. Für Targetruntime ist die Flushbestätigung ein zweites, unabhängiges Gate. Keiner der beiden Schalter ist ein Laufzeit- oder Mengenlimit. |
| Sicherer Einsatz | Zuerst nur das Inventar ausführen. Danach genau ein Forensik-Child, eine `ExampleSession`, einen engen UTC-Zeitraum und ein kleines `@MaxZeilen` wählen; Targetruntime erst nach bewusster Flushentscheidung aktivieren. |
| Aussagegrenze | Ein erfolgreiches Inventar beweist keine Ereigniserfassung. Ein begrenztes Ereignisresultset beschreibt nur die noch vorhandene gewählte Quelle; Rollover, Drops und ein spätes Zeilenlimit können relevante Events unsichtbar machen. Childresultate dürfen wegen getrennter Lesezeitpunkte nicht als transaktional konsistent behandelt werden. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche XE-Konfigurations-, Runtime- und Ereignisperspektiven sollen gemeinsam geprüft werden?

### Technischer Hintergrund

Der Wrapper ruft Sessions, allgemeine Events, Deadlocks, Blocked Processes und Target Runtime auf. Eventlesen kann Datei-I/O und XML-Parsing verursachen; Filter/MaxRows begrenzen den Pfad.

### Datenkette

Frameworkinterne Orchestrierung; Quellen liegen in Childmodulen.

### Zeit- und Scope-Modell

Nicht atomarer Mix aus aktuellem Zustand und Targethistorie.

### Bewertung und Gegenprobe

Zuerst Session/Targetstatus, erst danach leere/gefüllte Ereignisresultsets bewerten. Spezialevents nach Triage separat vertiefen.

### Typische Fehlinterpretation

Ein leeres Gesamtbild kann durch deaktivierte Session oder Retention entstehen und ist keine Systemgesundheitsaussage.

### Folgeanalyse

Child gezielt mit Session, Zeitraum, Eventname und begrenzten Dateien erneut ausführen.

## Primärquellen

- [Extended Events](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/extended-events?view=sql-server-ver17)

[Technische Detailbeschreibung](../06_Extended_Events.md#6-monitorusp_extendedeventsanalysis)

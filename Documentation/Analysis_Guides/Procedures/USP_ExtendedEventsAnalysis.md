# [monitor].[USP_ExtendedEventsAnalysis]

**Bereich:** Extended Events, Orchestrator  
**Zweck:** Orchestriert Inventar, Targetruntime, generische Events, Deadlocks und Blocked Processes.

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

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Session, Target, Event, Deadlock, Prozess, Ressource oder Blocked-Process-Report.

## So lesen

Inventar und Source-/Targetstatus vor Ereignisparsern lesen. Childstatus bestimmt, ob leere Fachdaten interpretierbar sind.

## Warum kann das problematisch sein?

Deadlock- oder Blockinganalyse ohne verlässliche Quelle kann falsche Entwarnung erzeugen.

## Wann ist es kein Problem?

Nicht aktivierte Event-Children fehlen absichtlich.

## Beispiel und Folgeschritt

Session gestoppt und Deadlockresultset leer bedeutet „keine Evidenz erfasst“, nicht „keine Deadlocks“. Vorhandene XEL-Dateien oder Konfiguration prüfen.

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

[Technische Detailbeschreibung](../06_Extended_Events.md#6-monitorusp_extendedeventsanalysis)

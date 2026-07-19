# Technische Grundlagen für belastbare SQL-Server-Analysen

**Stand:** 19. Juli 2026
**Geltungsbereich:** alle 84 öffentlichen Procedures

Dieses Dokument beschreibt das gemeinsame Execution-, Zeit- und Evidenzmodell. Die Procedure-Seiten ergänzen es um ihre konkrete Datenkette, Bewertungslogik, Gegenproben und Folgeanalysen.

## 1. Von der Engine zur Bewertung

Eine Diagnose ist erst belastbar, wenn die gesamte Kette sichtbar bleibt:

```text
Engine-Mechanismus -> Messquelle -> Framework-Transformation -> Resultset -> Gegenprobe -> Bewertung
```

Ein einzelner Messwert ist zunächst Evidenz. Er kann Ursache, Symptom, Auswirkung oder nur ein Korrelationsschlüssel sein. Vor einer Änderung sind Scope, Zeitbezug, Datenmenge, zweite Evidenzquelle, Risiko und Rollbackweg zu bestimmen.

## 2. Beobachtungsarten und Zeitmodelle

| Beobachtungsart | Typischer Zeitbezug | Wichtige Aussagegrenze |
|---|---|---|
| Momentaufnahme | beim Lesen sichtbarer Zustand | kann Millisekunden später verschwunden sein |
| Session- oder Requestzähler | seit Session- oder Requestbeginn | Session-IDs können nach Ende wiederverwendet werden |
| kumulative DMV | seit Engine-Start, Reset oder Lebenszyklus der Struktur | frühere Last kann den aktuellen Zustand dominieren |
| Stichprobendelta | Differenz zwischen Messung A und B | Reset oder Restart im Fenster macht das Delta ungültig |
| Plan-Cache-Evidenz | seit Entstehung des Cacheeintrags | Eviction, Recompile, Restart und Cache-Clear verkürzen die Historie |
| Query-Store-Historie | persistierte Datenbankintervalle | Capture Mode, Cleanup, Retention und Randintervalle begrenzen die Aussage |
| Extended-Events-Ereignis | während aktiver Session erfasstes Einzelereignis | nicht erfasst oder rotiert bedeutet nicht, dass es nicht geschah |
| Katalog oder Konfiguration | aktuell sichtbarer Metadatenzustand | beweist weder Nutzung noch Gesundheit eines Features |
| Betriebsmetadaten | abhängig von Job und Aufbewahrung | fehlende Historie beweist keine fehlende Ausführung |

Für jedes Resultset sind deshalb Beobachtungsart, Scope, Messfenster, Resetbedingungen, Aggregationsstufe, Einheit, Nenner und partielle Verfügbarkeit mitzulesen.

## 3. Session, Request, Task, Worker und Scheduler

Eine Clientverbindung besitzt eine Session. Eine Session führt Requests aus. Ein Request wird in mindestens eine Task zerlegt; ein paralleler Plan kann mehrere Tasks besitzen. Eine Task wird durch einen Worker ausgeführt, den SQLOS kooperativ auf einem Scheduler einplant.

- `session_id` identifiziert den Sitzungskontext, nicht den einzelnen parallelen Task.
- `request_id` trennt Requests innerhalb einer Session.
- `exec_context_id` unterscheidet Tasks beziehungsweise Execution Contexts.
- Ein paralleler Request kann gleichzeitig verschiedene Waittypen auf mehreren Tasks besitzen.
- Summierte CPU- oder Task-Wartezeiten können deshalb größer als die Wanduhrzeit sein.

Ein Worker ist vereinfacht `RUNNING`, wartet als `SUSPENDED` auf eine Ressource oder ein Ereignis oder ist nach Ende des Waits `RUNNABLE` und wartet auf Schedulerzeit. Bei instanzweiten Wait Stats ist die Signalzeit in der gesamten Waitzeit enthalten:

```text
ResourceWaitTimeMs = WaitTimeMs - SignalWaitTimeMs
```

## 4. Ursache, Symptom und Auswirkung trennen

| Beobachtung | Zunächst gezeigt | Noch nicht bewiesen |
|---|---|---|
| `LCK_M_*` | ein Task erhält einen inkompatiblen Lock noch nicht | warum der Blocker den Lock hält |
| `PAGEIOLATCH_*` | eine benötigte Seite ist noch nicht aus I/O verfügbar | dass ausschließlich das Storage langsam ist |
| `RESOURCE_SEMAPHORE` | ein Request wartet auf Query Execution Memory | ob Schätzfehler, DOP, Konkurrenz oder Konfiguration Hauptursache sind |
| `SOS_SCHEDULER_YIELD` | ein Worker gab CPU kooperativ ab | dass zusätzliche CPUs die richtige Lösung sind |
| `ASYNC_NETWORK_IO` | SQL Server wartet auf die Abnahme von Ergebnisdaten | ob Netzwerk, Clientverarbeitung oder Ergebnismenge ursächlich sind |
| hohe Dateilatenz | I/O-Abschlüsse dauerten im Messfenster lange | ob Storage, Queueing, Backup, Filtersoftware oder Workloadform Hauptursache sind |

## 5. Verbindliches Bewertungsmuster

1. **Status und Vollständigkeit:** Modulstatus, Warnungen, ausgelassene Datenbanken und Rechte prüfen.
2. **Scope:** Instanz, Datenbank, Session, Request, Task, Query, Plan, Objekt oder Datei bestimmen.
3. **Zeit:** Snapshot, kumulativ, Sample oder persistierte Historie unterscheiden.
4. **Menge:** Ausführungen, Tasks, I/Os, Seiten oder Zeilen als Nenner bestimmen.
5. **Mechanismus:** erklären, welcher Enginevorgang den Wert erzeugen kann.
6. **Auswirkung:** Laufzeit, Durchsatz, SLA, Blocking oder Kapazität messen.
7. **Gegenprobe:** mindestens eine plausible Alternativerklärung prüfen.
8. **Bestätigung:** eine zweite, unabhängige Evidenzquelle verwenden.

Ein leeres Resultset ist nur für den dokumentierten Scope und Zeitpunkt leer. Es ist ohne Prüfung von Filtern, Rechten, Featurestatus, Capture und Retention weder ein Gesundheitsnachweis noch ein Beweis dafür, dass ein Ereignis nie stattgefunden hat.

## 6. Änderungsgrenze

Kein einzelnes Resultset rechtfertigt automatisch `KILL`, DDL, Rebuild, Plan Forcing, Konfigurationsänderung, Failover oder Repair. Solche Eingriffe benötigen eine bestätigte Ursachehypothese, erwartete Wirkung, Nebenwirkungsanalyse, Freigabe und einen getesteten Rollbackweg.

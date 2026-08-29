# [monitor].[USP_RunSnapshotCollectionCycle]

**Bereich:** Optionales Snapshot-/Baseline-Paket SC-023
**Zweck:** Führt denselben begrenzten Collection Cycle für MANUAL, EXTERNAL und SQL_AGENT aus.
**Beobachtungsart:** persistierender, restartbezogener Messzyklus
**Kostenklasse:** MEDIUM bis HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure wird eingesetzt, wenn die konfigurierte Snapshot-Datenbank einen neuen, zeitlich und resetbezogen interpretierbaren Performance-Counter-Messpunkt erhalten soll. Alle Schedulerarten verwenden denselben Procedurevertrag. Der Scheduler bestimmt nur den Aufrufzeitpunkt; Due-, Parallelitäts-, Budget- und Collectionentscheidungen bleiben innerhalb des Frameworkvertrags.

## Nicht beantwortete Fragen

Ein einzelner Messpunkt ist kein Trend und liefert keine automatische Kapazitäts- oder Konfigurationsempfehlung. Der aktuelle Slice sammelt nur Performance Counter. Er beweist weder kontinuierliche Schedulerverfügbarkeit noch Vollständigkeit externer Monitoringdaten. Reset-Epochen, Countertypen und Basiseinheiten müssen vor jeder Delta- oder Ratenbildung kompatibel sein.

## Sicherer Einstieg

Im ersten Slice wird ausschließlich `monitor.USP_PerformanceCounters` mit `@SampleSeconds=0` gelesen. `Install_All.sql` installiert diese Persistenzfunktion bewusst nicht.

```sql
EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @SchedulerType = 'MANUAL',
     @RunEvenIfNotDue = 0,
     @ResultSetArt = 'CONSOLE';
```

## Resultsets und Leserichtung

CONSOLE zeigt den priorisierten Laufstatus. RAW, TABLE und JSON trennen `run` und `modules`; persistierte Metrics werden nicht als zusätzliches Defaultresultset kopiert. Lesen Sie zuerst Status, Start, Ende, Schedulerart und `ResetEpochId`. Ordnen Sie danach den Modulstatus und dessen Partialität ein. `SKIPPED_NOT_DUE` und ein No-wait-Concurrency-Skip sind kontrollierte Zustände, keine erfolgreichen Messpunkte.

## Beispiele und Gegenbeispiele

Ein passender Example-Lauf verwendet `MANUAL`, eine aktivierte synthetische Zielkonfiguration und ein kleines `MaxRows`-Budget. Zwei aufeinanderfolgende Läufe innerhalb derselben Reset-Epoche können später verglichen werden. Ein Gegenbeispiel ist die Berechnung einer Rate über einen SQL-Server-Neustart oder die Deutung eines partiellen Moduls als vollständigen Snapshot.

## Leere oder partielle Ausgabe

Eine deaktivierte Konfiguration, ein nicht fälliger Lauf oder eine bereits gehaltene Applock-Ressource kann den Cycle ohne Metrics beenden. Ein Quellfehler bleibt im Modulstatus sichtbar und darf bereits geschriebene Statuszeilen nicht in einen erfolgreichen Vollcapture umdeuten. Payload kann bewusst deaktiviert sein, ohne dass typisierte Metrics fehlen.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `MEDIUM` bis `HIGH_OPT_IN` |
| Standardpfad | Due-Prüfung und ein begrenzter Performance-Counter-Snapshot |
| Teuerster Pfad | Purge plus Collection und optionale komprimierte Payloadpersistenz |
| Haupttreiber | Counterzahl, Retentionrückstand, Zeilenbudget und Ziel-I/O |
| Skalierung | Ein Cycle je lokaler Zielbeziehung; parallele Ausführung wird übersprungen |
| Ressourcen | DMV-Lesezugriff, JSON-Verarbeitung und typisierte Zielwrites |
| Begrenzungswirkung | Policy, `MaxRows`, Intervall, Budget und No-wait-Applock |
| Locking und Nebenwirkungen | Persistierende Inserts und begrenzter Purge im Ziel |
| Schutzmechanismus | Konfigurationsgate, Due-Check, Reset-Epoche und Abschlussstatus |
| Sicherer Einsatz | Manueller Einzelcycle mit kleinem Budget vor Scheduleraktivierung |
| Aussagegrenze | Ein erfolgreicher Cycle ist kein Trend- oder Schedulernachweis |

## Eine Zeile bedeutet

`run` entspricht einem begonnenen, übersprungenen oder abgeschlossenen Collection Cycle. `modules` entspricht dem Status des einen Collector-Moduls. Metric-Samples sind in der Snapshot-Datenbank normalisiert und werden nicht als zusätzliches Defaultresultset dupliziert.

## So lesen

Berücksichtigen Sie zuerst `StatusCode`, `IsPartial`, Start/Ende und `ResetEpochId`. Prüfen Sie danach `modules` auf fehlende Rechte oder Evidenzgrenzen. `SKIPPED_NOT_DUE`, `SKIPPED_CONCURRENT`, `DISABLED` und `STOPPED_SIZE_BUDGET` bedeuten ausdrücklich, dass kein Quellread stattfand.

## Warum kann das problematisch sein?

Snapshots erzeugen dauerhafte Daten-, Log- und Backupmenge. Parallel gestartete Sammler würden außerdem zeitlich unterschiedliche Quellenstände und doppelte Last erzeugen. Eine Applock mit Wartezeit null serialisiert deshalb Cycle und Purge.

## Wann ist es kein Problem?

Ein übersprungener Lauf ist kein Fehler, wenn Intervall, Parallelität oder Deaktivierung ihn erklären. Ein kumulativer Raw Counter ist nicht allein auffällig; erst mehrere Samples innerhalb derselben Reset-Epoche erlauben eine belastbare Veränderungsbetrachtung.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wurde ein vollständiger, zeitlich und restartbezogen interpretierbarer Messpunkt persistiert?

### Technischer Hintergrund

Der Quell-JSON-Vertrag ist nur während des autorisierten Aufrufs transient. Roh- und interpretierte Werte werden getrennt typisiert; konkrete Counteridentitäten bilden einen gehashten Scope, dessen JSON nur im lokalen Ziel liegt. Optionales Rohpayload wird verlustfrei GZIP-komprimiert und mit SHA-256 gebunden.

### Datenkette

Konfiguration → No-wait-Applock → begrenzter Purge → Due-/Budgetprüfung → `USP_PerformanceCounters` → Scope/MetricSample/Payload → CaptureRun/ModuleStatus.

### Source Select

Vor jeder Sammlung werden Singleton-Konfiguration und Zielzustand geprüft:

```sql
SELECT
      [c].[TargetDatabaseName]
    , [c].[IsEnabled]
    , [c].[DefaultSchedulerType]
    , [d].[state_desc]
    , [d].[is_read_only]
FROM [monitor].[SnapshotTargetConfiguration] AS [c] WITH (NOLOCK)
LEFT JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[name] = [c].[TargetDatabaseName]
WHERE [c].[ConfigurationId] = 1
  AND [c].[IsEnabled] = 1;
```

**Wichtig für die Eigenlast:** Danach ist der Pfad schreibend: No-wait-Applock, Due-/Budgetprüfung, genau ein Collector-Aufruf und typisierte Inserts in `snapshot.CaptureRun`, `ModuleStatus`, `MetricSample` und optional Payload. Collectorpolicy, `MaxRows` und Zeitintervall begrenzen die Arbeit; Parallelität wird übersprungen statt blockiert.

### Zeit- und Scope-Modell

Alle Laufzeiten sind UTC. `SqlServerStartTimeUtc` bestimmt die stabile `ResetEpochId`; Deltas oder Raten dürfen nie über einen Epochwechsel berechnet werden.

### Bewertung und Gegenprobe

Vergleichen Sie mehrere zeitlich getrennte Läufe mit identischer Epoche. Prüfen Sie auffällige Counter anhand von Current-State-, Wait-, I/O- oder OS-Evidenz gegen.

### Typische Fehlinterpretation

Fehlendes Sample ist weder Nullwert noch gesunder Zustand. `PARTIAL` darf nicht in eine scheinbar vollständige Trendlinie umgedeutet werden.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_PerformanceCounters`, `USP_PurgeSnapshotData` sowie passende Current-State- und Server-Health-Module.

## Primärquellen

- [sys.dm_os_performance_counters](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-performance-counters-transact-sql?view=sql-server-ver17)
- [sp_getapplock](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-getapplock-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../../Operations/Snapshot_Baseline_Operations.md)

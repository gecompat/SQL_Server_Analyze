# [monitor].[USP_InfrastructureAnalysis]

**Bereich:** Infrastruktur, Orchestrator  
**Zweck:** Orchestriert Agent, Resource Governor, HA, Backup, Log Shipping, Replikation und Data Capture.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_InfrastructureAnalysis]
      @ResultSetArt = 'CONSOLE';
```

Tiefenmodule nur bei konkreter Fragestellung aktivieren.

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Dienst, Job, Pool, Replica, Datenbank, Backup, Log-Shipping-Paar, Replikationsobjekt oder Capturefeature.

## So lesen

Childstatus zuerst; nicht verwendete Features von fehlenden Rechten oder Fehlern unterscheiden.

## Warum kann das problematisch sein?

Ein leeres Child kann „Feature nicht eingesetzt“ oder „Quelle nicht lesbar“ bedeuten. Beide Aussagen sind fachlich verschieden.

## Wann ist es kein Problem?

Keine AG-Zeilen auf einer Standalone-Instanz sind erwartbar.

## Beispiel und Folgeschritt

Backupchild partiell, AG-Child unavailable feature: Nur der Backupbereich benötigt Nacharbeit. Auffälliges Child gezielt erneut ausführen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Infrastrukturmodule sollen als Triage in einem kontrollierten Lauf zusammengeführt werden?

### Technischer Hintergrund

Der Wrapper orchestriert Agent, Resource Governor, AG, Backup, Log Shipping, Replication und Capture. Nicht konfigurierte Features sollen als Status statt Fehler behandelt werden; Deep Children bleiben opt-in.

### Datenkette

Frameworkinterne Orchestrierung; Quellen liegen in Childmodulen.

### Zeit- und Scope-Modell

Nicht atomare Mischung aus Snapshots und `msdb`-Historien.

### Bewertung und Gegenprobe

Modulstatus zuerst, dann nur konfigurierte/auffällige Komponenten vertiefen. Ein nicht vorhandenes Feature ist normal, sofern der Scope es nicht erwartet.

### Typische Fehlinterpretation

Leere Resultsets dürfen nicht familienübergreifend als gesund zusammengefasst werden; jede Quelle besitzt eigene Retention und Berechtigung.

### Folgeanalyse

Betroffenes Childmodul mit engem Scope.

[Technische Detailbeschreibung](../07_Infrastructure.md#12-monitorusp_infrastructureanalysis)

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

[Technische Detailbeschreibung](../07_Infrastructure.md#9-monitorusp_infrastructureanalysis)

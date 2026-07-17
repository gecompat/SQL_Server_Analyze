# [monitor].[USP_ServerHealthAnalysis]

**Bereich:** Server Health, Orchestrator  
**Zweck:** Orchestriert Topologie, Memory, TempDB, Konfiguration, OS und optionale Spezialmodule.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerHealthAnalysis]
      @ResultSetArt = 'CONSOLE';
```

Spezialmodule nur bei konkreter Frage aktivieren.

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: CPU, Scheduler, Node, Memory, Datei, Konfiguration, Ereignis oder Finding.

## So lesen

Childstatus zuerst und Symptome familienweise lesen. Eine Summenzeile ist keine vollständige Gesundheitsgarantie.

## Warum kann das problematisch sein?

Ein Child kann partiell sein; ein anderes zeigt nur Konfiguration statt aktueller Auswirkung.

## Wann ist es kein Problem?

Nicht aktivierte Spezialmodule fehlen absichtlich.

## Beispiel und Folgeschritt

Memorykonfiguration auffällig, aktuelle Memorywerte normal: Review, kein akuter Incident. Das betreffende Child fokussiert erneut ausführen.

[Technische Detailbeschreibung](../08_Server_Health.md#10-monitorusp_serverhealthanalysis)

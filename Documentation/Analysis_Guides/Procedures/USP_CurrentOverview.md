# [monitor].[USP_CurrentOverview]

**Bereich:** Current State, Orchestrator  
**Zweck:** Führt mehrere leichte Live-Analysen in definierter Reihenfolge aus.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentOverview]
      @ResultSetArt = 'CONSOLE';
```

Sampling und vollständige SQL-Texte nur gezielt aktivieren.

## Eine Zeile bedeutet

Die Granularität hängt vom Childresultset ab: Session, Request, Blockingkante, Wait, Transaktion, Grant, TempDB-Verbrauch, Datei-I/O oder Logzustand.

## So lesen

Zuerst Modulstatus, dann vom konkreten Symptom zum passenden Child wechseln. Resultsets nicht ungeprüft miteinander addieren.

## Warum kann das problematisch sein?

Ein Überblick verdichtet unterschiedliche Evidenzarten. Ein auffälliger Einzelwert ohne Childkontext kann zu einer falschen Ursache führen.

## Wann ist es kein Problem?

Nicht aktivierte Children fehlen absichtlich. Ein leeres Child ist nur bei erfolgreichem Status als „aktuell nichts sichtbar“ interpretierbar.

## Beispiel und Folgeschritt

Blocking und hohe Logauslastung können dieselbe alte Transaktion als Ursache haben. Mit Blocking- und Transaktionsprocedure fokussiert nachprüfen.

[Technische Detailbeschreibung](../02_Current_State.md#10-monitorusp_currentoverview)

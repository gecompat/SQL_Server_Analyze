# [monitor].[USP_DatabaseIntegrityAnalysis]

**Bereich:** Server Health  
**Zweck:** Korrelierte Integritätsevidenz aus Datenbankstatus, CHECKDB-Historie, suspect pages, Backups und HADR.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DatabaseIntegrityAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @MitPageDetails = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Datenbank, einer suspect page, Backup-/CHECKDB-Evidenz, HADR-Reparatur oder einem Finding.

## So lesen

Datenbankstatus, PAGE_VERIFY, Alter letzter Integritätsprüfung, suspect pages, Backupchecksums und HADR-Reparaturen gemeinsam lesen.

## Warum kann das problematisch sein?

Suspect Pages oder beschädigte Backupevidenz sind konkrete negative Indikatoren möglicher physischer oder inhaltlicher Schäden.

## Wann ist es kein Problem?

Keine negativen Indikatoren beweisen keine Integrität; die Procedure führt keinen vollständigen CHECKDB aus.

## Beispiel und Folgeschritt

`SuspectPageCount=0` heißt nur „Quelle meldet nichts“. `SuspectPageCount=3` ist konkrete negative Evidenz und verlangt Eskalation, CHECKDB-Strategie, Backupkette und Restore-Test.

[Technische Detailbeschreibung](../08_Server_Health.md#11-monitorusp_databaseintegrityanalysis)

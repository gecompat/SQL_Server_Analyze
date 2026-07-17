# [monitor].[USP_DataCaptureStatus]

**Bereich:** Infrastruktur  
**Zweck:** Zeigt CDC-, Change-Tracking- und weitere Data-Capture-Zustände.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DataCaptureStatus]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Datenbank, ein Capture-Feature, einen Job oder eine erfasste Tabelle.

## So lesen

Featurestatus, Capture-/Cleanup-Job, Retention, Datenbankzustand und Logkontext unterscheiden.

## Warum kann das problematisch sein?

Aktiviertes CDC ohne laufenden Capturejob kann Logrückstand erzeugen; Cleanupfehler lassen Capturetabellen wachsen.

## Wann ist es kein Problem?

Deaktiviertes CDC oder Change Tracking ist normal, wenn die Datenbank das Feature nicht benötigt.

## Beispiel und Folgeschritt

CDC enabled plus Capturejob disabled ist ein konkreter Fehlerzustand. Agentjobs, Logstatus und Featurekonfiguration prüfen.

[Technische Detailbeschreibung](../07_Infrastructure.md#8-monitorusp_datacapturestatus)

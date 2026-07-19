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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Change-Capture-Technologien sind aktiviert und grundsätzlich betriebsbereit?

### Technischer Hintergrund

CDC liest Transaction Log asynchron in Change Tables und räumt per Cleanupjob auf. Change Tracking speichert kompakte Änderungsinformationen mit Retention/Auto Cleanup, keine vollständigen historischen Werte. Replication besitzt eigenen Logreader-/Distributionspfad.

### Datenkette

`master.sys.databases`, `msdb.dbo.agent_datetime`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `sys.change_tracking_databases`, `sys.change_tracking_tables`, `sys.databases`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Zeit- und Scope-Modell

Aktueller Enablement-/Konfigurationszustand mit begrenzten Job-/LSN-/Versionmarken.

### Bewertung und Gegenprobe

Technologie, Captureinstanzen, Jobs, Retention, Min/Max LSN oder Change Tracking Versions und Tabellenabdeckung lesen. Consumerposition gegen Mindestversion/MinLSN prüfen.

### Typische Fehlinterpretation

`Enabled=1` beweist keinen aktuellen Durchsatz, keine lückenlose Retention und keine funktionierenden Consumer.

### Folgeanalyse

`USP_DataCaptureDeepAnalysis`, Agent Jobs und Consumercheckpoint.

[Technische Detailbeschreibung](../07_Infrastructure.md#8-monitorusp_datacapturestatus)

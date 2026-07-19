# [monitor].[USP_StartupParameters]

**Bereich:** Server Health  
**Zweck:** Zeigt SQL-Server-Startparameter, Pfade und dauerhaft aktivierte Flags.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_StartupParameters]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem Startparameter oder einer daraus abgeleiteten Konfigurationsinformation.

## So lesen

Parameterart, Pfade, Trace Flags, Startoptionen und Dienstkontext prüfen.

## Warum kann das problematisch sein?

Falsche Master-/Errorlog-/Startpfade oder unerwartete Flags können Start und Engineverhalten beeinflussen.

## Wann ist es kein Problem?

Abweichende Pfade sind häufig bewusstes Storage-Design.

## Beispiel und Folgeschritt

Ein Trace Flag als Startup-Parameter erklärt, warum es nach jedem Restart wieder aktiv ist. Trace-Flag-Dokumentation, Dateisystem und Dienstkonfiguration prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Mit welchen Service-/Engineparametern wurde die Instanz gestartet?

### Technischer Hintergrund

Startupparameter definieren unter anderem Master Data/Log, Errorlog, Trace Flags und weitere Engineoptionen. Registry-/Service-DMVs liefern konfigurierte Parameter; einige Änderungen benötigen Dienstneustart und können Startfähigkeit beeinflussen.

### Datenkette

`sys.dm_os_host_info`, `sys.dm_server_registry`.

### Zeit- und Scope-Modell

Konfiguration der laufenden Instanz; Wirkung seit letztem Start.

### Bewertung und Gegenprobe

Parameter, Quelle, Reihenfolge, Pfad-/Flagbedeutung und Abgleich mit Runtime Trace Flags/Errorlog prüfen. Abweichung von Standard kann bewusst sein.

### Typische Fehlinterpretation

Ein angezeigter Parameter beweist nicht, dass sein Zielpfad gesund oder noch erforderlich ist. Änderungen ohne Recoveryzugang können Instanzstart verhindern.

### Folgeanalyse

Trace Flags, OS/Filesystem und dokumentiertes Restart-/Rollbackrunbook.

[Technische Detailbeschreibung](../08_Server_Health.md#7-monitorusp_startupparameters)

# [monitor].[USP_TraceFlags]

**Bereich:** Server Health  
**Zweck:** Inventarisiert aktive globale und sessionbezogene Trace Flags.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_TraceFlags]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem aktiven Trace Flag und seinem Scope.

## So lesen

Flagnummer, global/session Scope, Aktivierungsquelle, Version und dokumentierte Bedeutung prüfen.

## Warum kann das problematisch sein?

Undokumentierte oder veraltete Flags können Optimizer- oder Engineverhalten unerwartet verändern.

## Wann ist es kein Problem?

Dokumentierte Flags können bewusste Workarounds oder Diagnosehilfen sein.

## Beispiel und Folgeschritt

Ein altes Kompatibilitätsflag nach Upgrade kann neue Standardverbesserungen überdecken. Startup Parameters, Microsoft-Dokumentation und Changehistorie prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche globalen oder sessionbezogenen Trace Flags sind aktiv und welche Engineverhaltensänderung ist damit verbunden?

### Technischer Hintergrund

Trace Flags aktivieren Diagnose- oder Verhaltenspfade auf globaler/sessionbezogener Scope. Manche wurden durch Database Scoped Configurations oder neuere Defaults ersetzt; Supportstatus ist versionsabhängig. Startupparameter können globale Flags früh setzen.

### Datenkette

Frameworkinterne Orchestrierung; Quellen liegen in Childmodulen.

### Zeit- und Scope-Modell

Aktueller Runtimezustand; Sessionflags gelten nur im Kontext, globale bis Deaktivierung/Restart.

### Bewertung und Gegenprobe

Flagnummer, Scope, Startupbezug, dokumentierter Zweck, Version und aktuelle Notwendigkeit prüfen. Undokumentierte Flags besonders vorsichtig behandeln.

### Typische Fehlinterpretation

Aktiv heißt nicht, dass jeder Workloadpfad betroffen ist. Ein früher notwendiges Flag kann nach Upgrade redundant oder schädlich sein.

### Folgeanalyse

`USP_StartupParameters`, Server Configuration und offizielle versionsspezifische Dokumentation.

[Technische Detailbeschreibung](../08_Server_Health.md#6-monitorusp_traceflags)

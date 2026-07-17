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

[Technische Detailbeschreibung](../08_Server_Health.md#6-monitorusp_traceflags)

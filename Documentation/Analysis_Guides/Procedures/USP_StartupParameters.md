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

[Technische Detailbeschreibung](../08_Server_Health.md#7-monitorusp_startupparameters)

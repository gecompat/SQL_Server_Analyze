# [monitor].[USP_CriticalEngineEvents]

**Bereich:** Server Health  
**Zweck:** Liest schwere Engine-Ereignisse aus system_health und optionalen Diagnosequellen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CriticalEngineEvents]
      @VonUtc = DATEADD(HOUR, -24, SYSUTCDATETIME()),
      @MitEventXml = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem erfassten Engine-Ereignis; SourceStatus beschreibt die Verfügbarkeit der Quelle.

## So lesen

Eventtyp, Severity, Zeit, Quelle, Wiederholung und Begleitsymptome vergleichen.

## Warum kann das problematisch sein?

Schwere Fehler, Schedulerprobleme oder Dumps können Engine-, Hardware- oder I/O-Risiken anzeigen.

## Wann ist es kein Problem?

Ein einzelnes altes Ereignis kann bereits behoben sein; aktuelle Wiederholung entscheidet über Dringlichkeit.

## Beispiel und Folgeschritt

Mehrere Severity-20+-Fehler in kurzer Zeit plus suspect pages sind deutlich kritischer als ein einzelnes altes Ereignis. Error Log, Integrität und Infrastruktur prüfen.

[Technische Detailbeschreibung](../08_Server_Health.md#14-monitorusp_criticalengineevents)

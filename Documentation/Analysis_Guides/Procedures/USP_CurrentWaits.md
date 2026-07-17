# [monitor].[USP_CurrentWaits]

**Bereich:** Current State  
**Zweck:** Zeigt aktuelle oder kurz gesampelte Waits und ordnet sie Waitgruppen zu.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentWaits]
      @SampleSeconds = 5,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile einen sichtbaren Wait beziehungsweise eine Aggregation nach Session, Request, Waittyp oder Gruppe. Im Samplemodus ist das Delta maßgeblich.

## So lesen

Waittyp und Waitgruppe mit Dauer, Anzahl, Session, Request und Samplemodus lesen. Gesamtzeit und Wiederholung vor Einzelspitzen priorisieren.

## Warum kann das problematisch sein?

Ein dominanter Wait zeigt, wo Zeit verloren geht. Relevant wird er durch hohe Gesamtdauer, Wiederholung und konkrete Workloadauswirkung.

## Wann ist es kein Problem?

Viele Waits sind normale Hintergrund- oder Koordinationszustände. Parallelitätswaits allein beweisen keine falsche MAXDOP-Konfiguration.

## Beispiel und Folgeschritt

Ein einzelner `PAGEIOLATCH_SH` über 20 ms beweist kein Storageproblem. Viele solche Waits plus hohe Datei-Latenz und langsame Requests bilden dagegen eine belastbare I/O-Spur. Danach `USP_CurrentIO` verwenden.

[Technische Detailbeschreibung](../02_Current_State.md#4-monitorusp_currentwaits)

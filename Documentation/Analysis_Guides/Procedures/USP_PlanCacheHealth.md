# [monitor].[USP_PlanCacheHealth]

**Bereich:** Plan Cache  
**Zweck:** Bewertet Cachegröße, Kategorien und Single-Use-Anteil.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PlanCacheHealth]
      @AnalyseModus = 'SUMMARY',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile den gesamten Cache, eine Cachekategorie, eine Datenbankaggregation oder einen einzelnen Single-Use-Plan.

## So lesen

Gesamtgröße, Plananzahl, Single-Use-Anteil, Use Counts, Planarten und aktuellen Memory Pressure gemeinsam lesen.

## Warum kann das problematisch sein?

Viele große Single-Use-Pläne belegen Cache für selten wiederverwendete Texte und können nützlichere Pläne oder Datenseiten verdrängen.

## Wann ist es kein Problem?

Hoher Single-Use-Anteil ohne Speicherdruck ist technische Schuld, aber möglicherweise kein akuter Engpass.

## Beispiel und Folgeschritt

70 % Single-Use bei reichlich freiem Speicher ist weniger dringend als 20 % bei starkem Memory Pressure. Textvarianz, Parametrisierung, Optimize for Ad Hoc und Servermemory prüfen.

[Technische Detailbeschreibung](../04_Plan_Cache.md#3-monitorusp_plancachehealth)

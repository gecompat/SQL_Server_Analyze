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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie viel Memory bindet der Plan Cache und welche Planarten/Use-Count-Muster dominieren?

### Technischer Hintergrund

Cache Stores und Cached Plans zeigen Planarten, Objekt-/Ad-hoc-Pläne, Größen und Use Counts. Viele Single-Use-Ad-hoc-Pläne können Kompilierungs-/Memorydruck erzeugen; Clock Hands und Memory Pressure steuern Eviction.

### Datenkette

`sys.configurations`, `sys.dm_exec_cached_plans`, `sys.dm_exec_plan_attributes`, `sys.dm_exec_sql_text`.

### Zeit- und Scope-Modell

Aktueller Cachebestand; flüchtig und durch Workload/Memorydruck verändert.

### Bewertung und Gegenprobe

Cachegröße relativ zu Servermemory, Single-Use-Anteil in Bytes und Count, Ad-hoc-Workload, Compile/sec und Parameterisierungsstrategie bewerten.

### Typische Fehlinterpretation

Viele Single-Use-Pläne sind nicht automatisch Hauptproblem. `optimize for ad hoc workloads` reduziert zunächst Stubgröße, behebt aber keine Querygenerierung oder Compileursache.

### Folgeanalyse

`USP_ServerMemory`, Performance Counters, Query Hash und Anwendung/Parameterisierung.

[Technische Detailbeschreibung](../04_Plan_Cache.md#3-monitorusp_plancachehealth)

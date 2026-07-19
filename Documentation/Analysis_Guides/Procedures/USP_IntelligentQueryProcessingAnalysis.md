# [monitor].[USP_IntelligentQueryProcessingAnalysis]

**Bereich:** Query Store und IQP  
**Zweck:** Zeigt Featureeignung, datenbankbezogene Konfiguration und aggregierte Feedbacksignale.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Datenbank, einer Configuration, Automatic-Tuning-Option oder einem aggregierten Signal.

## So lesen

Eligibility, Compatibility, Database-scoped Configurations, Query-Store-Zustand und Evidence Counts getrennt betrachten.

## Warum kann das problematisch sein?

Ein Feature kann versionsseitig geeignet, aber deaktiviert sein. Query Store OFF oder READ_ONLY kann persistentes Feedback begrenzen.

## Wann ist es kein Problem?

`EvidenceCount=0` beweist weder Erfolg noch Misserfolg; eventuell existierte keine geeignete Query oder keine persistierte Evidenz.

## Beispiel und Folgeschritt

PSP eligible, aber keine Query Variants: kein Fehler. Erst eine bekannte parameter-sensitive Query liefert eine sinnvolle Gegenprobe. Query Store und Showplan prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche IQP-Funktionen sind technisch möglich, konfiguriert und durch sichtbare Query-/Planfeedbacksignale belegt?

### Technischer Hintergrund

IQP umfasst unter anderem PSP, OPPO, Memory Grant Feedback, DOP/CE Feedback, Adaptive Joins, Deferred Compilation und weitere versions-/compatibilityabhängige Features. Database Scoped Configurations und Query-Store-basierte Feedbacks sind getrennte Ebenen.

### Datenkette

`sys.database_automatic_tuning_options`, `sys.database_query_store_options`, `sys.database_scoped_configurations`, `sys.databases`, `sys.dm_db_tuning_recommendations`, `sys.query_store_plan_feedback`, `sys.query_store_query_variant`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Version-/Compatibility-/Configurationzustand plus persistierte, sichtbare Feedback-/Variantenevidenz.

### Bewertung und Gegenprobe

`Eligible`, Configuration Value, Query Store State und Evidence Count trennen. Ein Signal führt zur konkreten Query-/Plananalyse, nicht zur pauschalen Aktivierung/Deaktivierung.

### Typische Fehlinterpretation

`Eligible=1` ist kein Wirksamkeitsbeweis; `EvidenceCount=0` beweist weder fehlendes Problem noch Featureversagen.

### Folgeanalyse

Query Store Runtime/PlanChanges, Showplan und konkrete Parameterworkload.

[Technische Detailbeschreibung](../05_Query_Store.md#8-monitorusp_intelligentqueryprocessinganalysis)

# [monitor].[USP_SchemaDesignAnalysis]

**Bereich:** Object und Index  
**Zweck:** Erzeugt normalisierte Findings zu Constraints, Foreign Keys, Indizes und Identity-Risiken.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SchemaDesignAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem Designfinding für ein betroffenes und gegebenenfalls verwandtes Objekt.

## So lesen

`FindingCode`, Severity, Objekt, Related Object, Metrik, Evidence und `EvidenceLimit` gemeinsam lesen.

## Warum kann das problematisch sein?

Nicht vertrauenswürdige Constraints, fehlende FK-Unterstützung oder fast erschöpfte Identitybereiche können Optimierung, DML und Verfügbarkeit beeinträchtigen.

## Wann ist es kein Problem?

Disabled oder ähnlich wirkende Objekte können Teil eines Lade-, Deployment- oder Constraintdesigns sein.

## Beispiel und Folgeschritt

Ein FK ohne passenden Index ist besonders relevant, wenn Parent-Änderungen große Childscans und Blocking erzeugen. Bei statischen Tabellen kann die Priorität niedriger sein. Usage, Pläne und Änderungsrisiko prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Schemamuster verdienen ein fachliches Designreview?

### Technischer Hintergrund

Die Procedure leitet normalisierte Findings aus Katalogmerkmalen ab, etwa Datentyp-, Schlüssel-, Index-, Nullable-, LOB- oder Constraintkonstellationen. Solche Regeln erkennen technische Gerüche, nicht die vollständige fachliche Semantik.

### Datenkette

`sys.check_constraints`, `sys.foreign_key_columns`, `sys.foreign_keys`, `sys.identity_columns`, `sys.index_columns`, `sys.indexes`, `sys.objects`, `sys.schemas`, `sys.sequences`, `sys.sp_executesql`, `sys.tables`.

### Zeit- und Scope-Modell

Aktueller Metadatenstand; keine Runtime-/Workloadhistorie, sofern nicht explizit angereichert.

### Bewertung und Gegenprobe

Severity/Confidence, Objektgröße, Workload, Datenqualität, Abhängigkeiten und Migrationsaufwand zusammen betrachten. Ein Finding mit hoher technischer Plausibilität kann fachlich bewusst sein.

### Typische Fehlinterpretation

Heuristik ist kein Beweis. Breite Spalten, fehlender PK oder bestimmter Datentyp können durch externe Verträge oder Stagingzweck begründet sein.

### Folgeanalyse

Object Inventory, Querypläne, Datenprofiling und fachliches Schemaowner-Review.

[Technische Detailbeschreibung](../03_Object_Index.md#10-monitorusp_schemadesignanalysis)

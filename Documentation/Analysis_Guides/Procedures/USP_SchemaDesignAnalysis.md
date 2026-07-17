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

[Technische Detailbeschreibung](../03_Object_Index.md#10-monitorusp_schemadesignanalysis)

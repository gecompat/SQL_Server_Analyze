# [monitor].[USP_RowLevelSecurityAndMaskingInventory]

**Bereich:** Server Health und Datenbanksicherheit
**Zweck:** Zeigt sichtbare RLS-Policies, Predicate-Metadaten und Masked Columns.
**Beobachtungsart:** getrennte lokale Katalogaufnahmen im Caller-Kontext
**Kostenklasse:** LOW_MEDIUM.

## Entscheidungsfrage und Grenzen

Welche Row-Level-Security-Policies, zugehörigen Predicate-Metadaten und Dynamic-Data-Masking-Spalten sind im gewählten Datenbankkontext sichtbar? Die Procedure liest ausschließlich lokale Katalogmetadaten. Sie liest keine geschützten Tabellenzeilen und gibt keine Predicate-Definitionen oder Maskingfunktionen aus.

Eine erfolgreiche leere Quelle belegt keine Abwesenheit, wenn Metadaten nur eingeschränkt sichtbar sind. Der Bericht bewertet weder Richtlinienwirksamkeit noch Gesundheit oder Vollständigkeit, berechnet keine effektiven Rechte und führt keine Zugriffsprobe aus. Die Procedure erstellt temporäre Tabellen für die Resultatmaterialisierung, ändert aber keine Zielobjekte dauerhaft und nimmt keine Berechtigungsänderungen vor. Sichtbare Policy- und Maskingzeilen beweisen keine Abdeckung aller Objekte oder Principals.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory]
    @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=200,
    @ResultSetArt='CONSOLE', @PrintMeldungen=0;
```

Der Beispielname ist synthetisch. Ohne Filter verwendet die Procedure die gemeinsame Kandidatenauswahl für sichtbare Online-Benutzerdatenbanken; Systemdatenbanken bleiben standardmäßig ausgeschlossen. `@DatabaseNames` und `@DatabaseNamePattern` bleiben getrennte Auswahlwege. Das globale Limit gilt unabhängig für jede der drei Fachmengen über alle ausgewählten Datenbanken. `NULL` oder 0 bedeutet unbegrenzt; negative Werte werden abgewiesen. Das Limit begrenzt die Ausgabe, nicht die Katalogarbeit.

## Resultsets

RAW liefert sieben Resultsets. TABLE exportiert dieselben Namen über `@ResultTablesJson`. JSON enthält die Arrays `moduleStatus`, `databaseContext`, `securityPolicies`, `securityPredicates`, `maskedColumns`, `sourceStatus` und `warnings`. CONSOLE zeigt Policies als einziges Standardinventar; die beiden anderen Inventare bleiben in RAW, TABLE und JSON verfügbar. NONE unterdrückt Resultsets und kann Status beziehungsweise JSON über OUTPUT zurückgeben.

| Resultset | Inhalt |
|---|---|
| `moduleStatus` | Aufrufstatus, Partialität und Summe der zurückgegebenen Policy-, Predicate- und Maskingzeilen. |
| `databaseContext` | Datenbankbindung, Zustand, Containment und Kontextstatus je ausgewähltem Ziel. |
| `securityPolicies` | Sichtbare Policy-ID, Name, Schema, Schalter und Zeitfelder; `IsSchemabindingEnabled` erhält den rohen Katalogwert einschließlich NULL. Wenn die Katalogansicht dieses Feld nicht bereitstellt, bleibt es NULL und `warnings` meldet `SOURCE_UNAVAILABLE` für `SECURITY_POLICIES`. |
| `securityPredicates` | Policy- und Predicate-IDs, Zielobjekt-ID, Typ und Operation. Definitionstext bleibt ausgeschlossen. |
| `maskedColumns` | Objekt-/Spalten-ID, sichtbare Schema-, Tabellen- und Spaltennamen sowie `IsMasked`. Maskingfunktion und Werte bleiben ausgeschlossen. |
| `sourceStatus` | Getrennte Zeitklammer, Status, Sichtbarkeitsgrenze und beobachtete beziehungsweise zurückgegebene Zeilen pro Quelle. |
| `warnings` | Ungekürzte Auswahl-, Quellen-, Limit- und Aussagegrenzen. |

Die stabilen Feldfolgen, Typen, Nullbarkeit und Collation stehen im [Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv). IDs sind nur mit Datenbank- und Aufnahmebindung interpretierbar. Nicht auflösbare Namen bleiben NULL; die native ID-Zeile wird erhalten.

## Eine Zeile bedeutet

Eine Policy-Zeile, Predicate-Zeile oder Masked-Column-Zeile ist ein im Caller-Kontext sichtbarer Katalogeintrag. Datenbank-, Objekt- und Spalten-IDs gelten nur innerhalb der zugehörigen Datenbank. Die drei Quellen werden getrennt gelesen und bilden keinen atomaren Snapshot.

## So lesen

Prüfen Sie zuerst `databaseContext`, `sourceStatus` und `warnings`. Danach ordnen Sie Fachzeilen über Datenbank- und native Objekt-IDs ein. `VISIBLE_ONLY` beschreibt die tatsächlich abgefragte Sicht; es bestätigt keine vollständige Metadatenberechtigung. `IsSchemabindingEnabled` bleibt der rohe Katalogwert einschließlich NULL; fehlt das Katalogfeld, kennzeichnet `SOURCE_UNAVAILABLE` in `warnings` die fehlende Metadatenangabe.

## Aufnahme und Datenschutz

`SECURITY_POLICIES`, `SECURITY_PREDICATES` und `MASKED_COLUMNS` werden je Datenbank isoliert gelesen. Fehler und Timeouts erzeugen Quellenstatus mit unbekannten Mengen und werden nicht als leere erfolgreiche Quelle ausgegeben. Eine erfolgreiche Aufnahme erhält `AVAILABLE_LIMITED` und `VISIBLE_ONLY`; eingeschränkte Metadatensicht bleibt dauerhaft unbewiesen.

Fehlertexte der Katalogabfragen werden nicht übernommen. Der Status enthält die Fehlernummer und eine feste Diagnoseformulierung. Die Procedure verändert weder Policies noch Berechtigungen. Sie erteilt keine Rechte und prüft keine effektiven Berechtigungen.

`@LockTimeoutMs` erlaubt 0 bis 60000 Millisekunden. Der vorherige `LOCK_TIMEOUT`- und `XACT_ABORT`-Zustand wird wiederhergestellt. Eine vorhandene Caller-Transaktion bleibt Caller-eigen; die Procedure führt weder Commit noch Rollback aus.

## Interpretation

`AVAILABLE_LIMITED` bezeichnet erfolgreich gelesene sichtbare Katalogzeilen. Leere Zeilenmengen oder ein sichtbarer Policy-Eintrag belegen keine vollständige Erfassung. `OUTPUT_LIMIT` weist die gekürzte Fachmenge aus; Kontext, Status und Warnungen bleiben ungekürzt.

## Warum kann das problematisch sein?

Eingeschränkte Katalogsicht kann Policies oder Spalten verbergen. Getrennte Quellen können außerdem unterschiedliche Zustände zu verschiedenen Aufnahmezeitpunkten zeigen. Ein sichtbarer Predicate-Eintrag belegt weder die tatsächliche Durchsetzung noch die Abdeckung aller Principals oder Tabellen.

## Wann ist es kein Problem?

Eine leere sichtbare Teilmenge ist ein gültiges Beobachtungsergebnis, wenn `sourceStatus` die Quelle als verfügbar kennzeichnet und die Ausgabegrenze erhalten bleibt. Ein gesetztes `OUTPUT_LIMIT` ist ebenfalls erwartbar, sofern die gekürzte Fachmenge nicht als vollständiger Bestand interpretiert wird.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Policy-, Predicate- und Masked-Column-Katalogzeilen sind im gewählten Caller-Kontext sichtbar?

### Technischer Hintergrund

Die Aufnahme liest drei getrennte lokale Katalogquellen. Sie gibt ausschließlich native Identitäten und ausgewählte beschreibende Metadaten aus. Die Procedure liest keine geschützten Tabellenwerte und übernimmt keine Ausdruckstexte in Resultsets, Warnungen oder Fehlerdiagnosen.

### Datenkette

`sys.security_policies`, `sys.schemas`, `sys.security_predicates`, `sys.masked_columns`, `sys.tables` und `USP_PrepareDatabaseCandidates`.

### Source Select

Der folgende Quellpfad zeigt Policy-Identitäten und sichtbare Schemanamen. Die beiden anderen Fachquellen werden separat abgefragt. Das optionale Katalogfeld `is_schemabinding_enabled` wird nur gelesen, wenn die Zielansicht es bereitstellt; andernfalls bleibt `IsSchemabindingEnabled` NULL und `warnings` nennt `SOURCE_UNAVAILABLE` für `SECURITY_POLICIES`.

```sql
SELECT
      [p].[object_id]
    , [p].[name]
    , [p].[schema_id]
    , [s].[name] AS [SchemaName]
    , [p].[is_enabled]
    , [p].[is_not_for_replication]
    , [p].[uses_database_collation]
    , [p].[create_date]
    , [p].[modify_date]
FROM [sys].[security_policies] AS [p] WITH (NOLOCK)
LEFT JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [p].[schema_id];
```

**Wichtig für die Eigenlast:** Die Katalogquellen werden je ausgewählter Datenbank separat gelesen und erst danach pro Inventar global begrenzt. Das Limit begrenzt die ausgegebenen Zeilen, nicht die Katalogabfrage.

### Zeit- und Scope-Modell

Der Scope folgt der gemeinsamen Datenbankauswahl. Jede Katalogquelle erhält eine eigene Zeitklammer; die drei Klammern sind kein gemeinsamer Transaktionssnapshot.

### Bewertung und Gegenprobe

Vergleichen Sie bei einer gezielten Prüfung die native Policy- und Objekt-ID mit der jeweiligen Datenbankkatalogsicht. Leiten Sie aus diesem Inventar keine Durchsetzungs- oder Zugriffsentscheidung ab.

### Typische Fehlinterpretation

Eine leere sichtbare Katalogmenge beweist keine Abwesenheit, wenn der Caller nur eingeschränkte Metadatensicht besitzt.

### Folgeanalyse

Verwenden Sie die [Datenbankprincipal-Analyse](USP_DatabasePrincipalAnalysis.md), wenn direkte Principals, Rollen oder explizite Rechte getrennt betrachtet werden müssen.

[Technische Detailbeschreibung](../../Reference/Procedure_Reference.md) · [Spezialfeatureinventur](USP_SpecialFeatureInventory.md) · [Datenbankprincipal-Analyse](USP_DatabasePrincipalAnalysis.md)

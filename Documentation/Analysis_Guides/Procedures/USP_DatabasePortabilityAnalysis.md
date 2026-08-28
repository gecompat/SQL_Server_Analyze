# [monitor].[USP_DatabasePortabilityAnalysis]

Inventarisiert sichtbare persistierte Edition-Features und uncontained dependencies je Benutzerdatenbank.

**Bereich:** Server Health und Datenbankportabilität
**Zweck:** Stellt zwei abgegrenzte Katalogklassen als Vorbereitung für Restore-, Editions-, Plattform- oder Containmentprüfungen bereit.
**Beobachtungsart:** sequenzielles datenbanklokales Kataloginventar
**Kostenklasse:** LOW bis MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure zeigt, welche sichtbaren Datenbankmerkmale vor einem Zielplattformtest fachlich eingeordnet werden müssen. `PERSISTED_SKU_FEATURE` stammt aus `sys.dm_db_persisted_sku_features`; `UNCONTAINED_ENTITY` stammt aus `sys.dm_db_uncontained_entities`. Beide Klassen sind Hinweise auf konkrete Gegenprüfungen. Sie ersetzen weder eine Ziel-Edition-Matrix noch Restore-, Upgrade-, Anwendungs- oder Performanceabnahmen.

## Nicht beantwortete Fragen

Ein leeres Ergebnis ist keine allgemeine Portabilitätsfreigabe. Die Procedure prüft beispielsweise keine Dateipfade, Betriebssystemabhängigkeiten, externe Endpunkte, Collationswirkung auf Anwendungslogik, SQL-Agent-Jobs oder proprietäre Deploymentprozesse. Ein Eintrag in der SKU-Feature-DMV ist versions- und editionsabhängig zu interpretieren; seit SQL Server 2016 SP1 sind mehrere früher editionsgebundene Funktionen breiter verfügbar. Uncontained-Metadaten beschreiben potenzielle Grenzüberschreitungen und können dynamisches Verhalten nicht vollständig beweisen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DatabasePortabilityAnalysis] @DatabaseNames = N'[DeineDatenbank]', @MaxZeilen = 200, @ResultSetArt = 'CONSOLE';
```

Verwenden Sie für den Einstieg eine bracket-aware Liste expliziter Testdatenbanken. Die Procedure scannt keine Nutzdaten und erzeugt keine DDL. Ein fehlender oder unsichtbarer expliziter Name wird als `NOT_FOUND` beziehungsweise partielle Quelle behandelt, statt stillschweigend durch einen anderen Datenbankscope ersetzt zu werden.

## Resultsets und Leserichtung

CONSOLE zeigt `portability`. RAW liefert Modulstatus und die begrenzten Evidenzzeilen. TABLE exportiert ausschließlich das stabile Resultset `portability`; JSON verwendet dieselbe materialisierte Datenbasis. Lesen Sie `DatabaseName`, `EvidenceType`, `SourceObject`, `StatusCode` und `EvidenceLimit` zuerst. `FeatureName`, `FeatureType` und `StatementType` erhalten ihre Bedeutung erst zusammen mit der jeweiligen Quellklasse.

## Beispiele und Gegenbeispiele

Eine neue synthetische Datenbank `ExamplePortableDatabase` ohne Zeilen in beiden DMVs ist ein zulässiger Leerfall. Eine synthetische Procedure mit einem expliziten Verweis auf `master.sys.databases` kann als `UNCONTAINED_ENTITY` erscheinen und begründet eine gezielte Reviewfrage. Ein Gegenbeispiel ist die Behauptung, jeder uncontained Eintrag verhindere eine Migration. Ebenso darf eine `Compression`-Zeile nicht ohne Zielversion und Ziel-Edition in eine Entfernungsempfehlung übersetzt werden.

## Leere oder partielle Ausgabe

`AVAILABLE_EMPTY` bedeutet nur, dass die beiden sichtbaren Quellen im gewählten Scope keine Zeilen lieferten. Eine Datenbank, die während der sequenziellen Verarbeitung offline, unsichtbar oder nicht lesbar ist, erzeugt eine `SOURCE_STATUS`-Zeile und kann `AVAILABLE_LIMITED` auslösen. Sind alle explizit angeforderten Datenbanken nicht verfügbar, bleibt die Abgrenzung als `NOT_FOUND` sichtbar.

Die Berechtigungsanforderung der SKU-Feature-DMV unterscheidet sich zwischen den Versionen. Ein fehlender Befund unter einem eingeschränkten Konto darf deshalb nicht mit dem administrativen Positiv- oder Leerfall zusammengeführt werden. Runtimeevidenz zeichnet Engineversion und Berechtigungsprofil getrennt auf.

Diese Trennung gilt auch für den dokumentierten Example-Leerfall.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `LOW` bis `MEDIUM` |
| Standardpfad | Zwei datenbanklokale DMV-Lesevorgänge je ausgewählter Datenbank |
| Teuerster Pfad | Breiter Scope über viele sichtbare Benutzerdatenbanken |
| Haupttreiber | Datenbankanzahl und Umfang der uncontained Metadaten |
| Skalierung | Sequenziell je Datenbank; keine parallele Katalogabfrage |
| Ressourcen | Katalog-CPU und Metadaten-I/O; kein Nutzdatenscan |
| Begrenzungswirkung | Datenbankfilter begrenzt Quellen; `@MaxZeilen` begrenzt Ausgabe |
| Locking und Nebenwirkungen | Read-only Katalogzugriff mit isolierten Quellfehlern |
| Schutzmechanismus | Vorabvalidierte Namensliste und per-Datenbank-Fehlerisolation |
| Sicherer Einsatz | Explizite Kandidatenliste vor einer isolierten Zielplattformprüfung |
| Aussagegrenze | Kataloghinweise sind keine Migrations- oder Restorefreigabe |

## Eine Zeile bedeutet

Eine Zeile steht für eine Portabilitätsevidenz aus genau einer Datenbank und Quellklasse.

## So lesen

Bewerten Sie Feature oder Abhängigkeit gegen Zielversion, Edition, Plattform und Anwendungsvertrag.

## Warum kann das problematisch sein?

Persistierte Features oder externe Abhängigkeiten können Restore, Attach oder Plattformwechsel erschweren.

## Wann ist es kein Problem?

Das Ziel kann das Feature vollständig unterstützen, oder die Abhängigkeit kann bewusst freigegeben sein.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Merkmale benötigen vor einer Migration einen Zielplattformtest?

### Technischer Hintergrund

Die Procedure liest zwei datenbanklokale Katalogsichten; Fehler einer Datenbank bleiben als partielle Quelle sichtbar.

### Datenkette

`master.sys.databases` → `sys.dm_db_persisted_sku_features` und `sys.dm_db_uncontained_entities` → Hinweise.

### Source Select

```sql
SELECT [feature_name] FROM [sys].[dm_db_persisted_sku_features] WITH (NOLOCK);
SELECT [class_desc], [statement_type], [feature_name] FROM [sys].[dm_db_uncontained_entities] WITH (NOLOCK);
```

**Wichtig für die Eigenlast:** Filtern Sie Datenbanken mit der bracket-aware Pipe-Liste `@DatabaseNames` vor dem Kontextwechsel; Nutzdaten werden nicht gescannt.

### Zeit- und Scope-Modell

Datenbanken werden nacheinander gelesen; die Ausgabe ist kein atomarer serverweiter Snapshot.

### Bewertung und Gegenprobe

Bestätigen Sie Befunde mit Zielversion, Restoretest und Anwendungstest.

### Typische Fehlinterpretation

`AVAILABLE_EMPTY` schließt nicht jede denkbare Portabilitätsgrenze aus.

### Folgeanalyse

Nutzen Sie Feature-Capabilities, Konfigurationsanalyse und einen isolierten Migrationstest.

## Primärquellen

- [sys.dm_db_persisted_sku_features](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-persisted-sku-features-transact-sql?view=sql-server-ver17)
- [Contained Databases und uncontained entities](https://learn.microsoft.com/en-us/sql/relational-databases/databases/contained-databases?view=sql-server-ver17)

[Technische Detailbeschreibung](../../../Code/08_ServerHealth/200_USP_DatabasePortabilityAnalysis.sql)

# [monitor].[USP_ExternalDataAnalysis]

**Bereich:** Versionsadaptive lokale Kataloge<br>
**Zweck:** Sichtbare externe Datenobjekte und lokale Referenzen einordnen.<br>
**Beobachtungsart:** Lokale Katalogaufnahme<br>
**Kostenklasse:** LOW_MEDIUM.

## Entscheidungsfrage und Einsatz

Die Procedure zeigt lokale Datenquellen, Dateiformate, externe Tabellen und eine aggregierte Modellanzahl je ausgewählter Datenbank. Datenbankfilter verwenden den bestehenden exklusiven Namens-/Patternvertrag. Ohne Filter werden sichtbare Online-Benutzerdatenbanken verarbeitet; Systemdatenbanken bleiben opt-in.

## Nicht beantwortete Fragen

Die Ausgabe prüft keine Verbindung, Authentifizierung, externen Dateninhalte oder Modellinferenz. Locations, Credentialkennungen und -namen, Remoteidentitäten, Modellnamen und Payloads bleiben ausgeschlossen. Eine lokale Definition beweist keine externe Nutzbarkeit.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExternalDataAnalysis]
      @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=200,
      @ResultSetArt='CONSOLE';
```

Es gibt keinen impliziten CURRENT-Scope, kein Datenbankanzahllimit und keinen aktivierten Remote- oder DDL-Pfad. Die Procedure vergibt keine Berechtigungen.

## Resultsets und Leserichtung

RAW liefert moduleStatus, databaseStatus, dataSources, fileFormats, externalTables, modelSummary, sourceStatus und warnings. TABLE exportiert dieselben benannten nativen Schemas; JSON verwendet Schema 1. CONSOLE liefert eine formatierte Datenbankübersicht, NONE unterdrückt fachliche Resultsets. Die vollständigen Schemas stehen im [freigegebenen Vertrag](../../Architecture/WI0009_External_Data_Public_Specification.md).

Prüfen Sie zuerst Quellenstatus und Partialität, danach die unlimitierten Datenbankcounts und schließlich die begrenzten Detailmengen. Eine fehlgeschlagene Quelle liefert NULL-Anzahlen und erhält die anderen Quellen. Die erste tatsächliche native Fehlerpaarung folgt Datenbankname und fester Quellenfolge.

## Eine Zeile bedeutet

Eine Quellen- oder Formatzeile beschreibt ein sichtbares lokales Katalogobjekt. Eine Tabellenzeile verbindet ausschließlich lokal sichtbare Kennungen. modelSummary zählt sichtbare Modelle ohne Modellidentitäten oder Inhalte.

## So lesen

VISIBLE bedeutet eine positive Kennung mit sichtbarer lokaler Gegenzeile. NOT_VISIBLE_IN_SCOPE beschreibt eine im erfolgreich gelesenen Katalog nicht sichtbare Gegenzeile. NULL/0-Kennungen sind NOT_APPLICABLE. Bei ausgefallener Referenzquelle erhalten positive Kennungen SOURCE_UNAVAILABLE. VisibleColumnCount zählt nur sichtbare sys.columns-Zeilen.

## Warum kann das problematisch sein?

Metadatenrechte begrenzen die Sichtbarkeit. Ein leerer erfolgreich gelesener Katalog belegt keine allgemeine Abwesenheit; eine nicht sichtbare Referenz beweist keinen defekten Fremdschlüssel. Ein Quellenfehler verhindert eine belastbare Anzahl dieser Quelle.

## Wann ist es kein Problem?

UNAVAILABLE_VERSION und NULL-Modellanzahl sind vor SQL Server 2025 erwartbar und setzen allein keine Partialität. NOT_APPLICABLE kann bei Quellen ohne Dateiformatreferenz korrekt sein. Keine dieser Aussagen erzeugt ein Gesundheitsurteil.

## Beispiele und Gegenbeispiele

```sql
DECLARE @ExampleJson nvarchar(max);
EXEC [monitor].[USP_ExternalDataAnalysis]
      @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE',
      @JsonErzeugen=1, @Json=@ExampleJson OUTPUT;
SELECT @ExampleJson AS [Json];
```

Eine sichtbare externe Tabelle ist eine lokale Definition. Ihre Zeile beweist weder erfolgreiche Abrufe noch erfolgreiche Authentifizierung.

## Leere oder partielle Ausgabe

Die sechs Quellen werden getrennt behandelt. Tatsächliche Fehlernummern und Meldungen bleiben erhalten. Warnungstexte dürfen verkürzt werden, während native Fehlerfelder vollständig bleiben. Ein unbekannter Major oder unerwartet fehlender aktueller Katalog ist SOURCE_UNAVAILABLE; eine leere sichtbare Menge ist AVAILABLE mit Anzahl 0. Ein leeres ungefiltertes Datenbankscope ist AVAILABLE; explizit fehlende Datenbanken bleiben DATABASE_UNAVAILABLE.

## Eigenlast und Grenzen

Die Eigenlast wächst mit der Zahl ausgewählter Datenbanken, Katalogzeilen und sichtbarer Spalten externer Tabellen. @MaxZeilen begrenzt Ausgaben, nicht die Sammlung oder Zahl der Datenbanken. Es gibt kein Sampling und keinen Remote-I/O-Pfad. Nonblocking-Katalogzugriffe und restaurierte LOCK_TIMEOUT-/XACT_ABORT-Werte begrenzen Nebenwirkungen; eine atomare Mehrquellenaufnahme wird nicht behauptet.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche lokalen externen Objekte und Referenzen sind im aktuellen sichtbaren Datenbankscope vorhanden?

### Technischer Hintergrund

Die Kataloge sind datenbanklokal. Schema- und Spaltenmetadaten werden getrennt aggregiert; die Modellquelle wird erst ab Major 17 dynamisch gelesen.

### Datenkette

sys.external_data_sources, sys.external_file_formats, sys.external_tables, sys.schemas, sys.columns und sys.external_models werden isoliert gesammelt. Counts beziehen sich auf die Sammlung vor Ausgabelimits.

### Source Select

```sql
SELECT [data_source_id], [name], [type], [type_desc]
FROM [sys].[external_data_sources] WITH(NOLOCK);
```

**Wichtig für die Eigenlast:** Die Quelle liest nur lokale Metadaten. Es wird weder eine externe Tabelle ausgewählt noch eine Location oder ein Credential gelesen.

### Zeit- und Scope-Modell

Quellenzeitpunkte beschreiben getrennte Katalogaufnahmen. Zwischen ihnen können Definitionen oder Sichtbarkeit wechseln. Die Ausgabe behauptet keinen atomaren Zustand und keine historische Nutzung.

### Bewertung und Gegenprobe

Vergleichen Sie native Kennungen und sichtbare Gegenzeilen im selben Datenbankscope. Eine gesondert autorisierte externe Nutzbarkeitsprüfung wäre eine andere Aufgabe und wird hier nicht ausgelöst.

### Typische Fehlinterpretation

Nicht sichtbare Referenzen sind keine nachgewiesenen Orphans. NULL-Anzahlen sind keine gemessenen Nullen. Erfolgreiche Metadatenabfragen sind keine erfolgreichen Remoteabfragen.

### Folgeanalyse

Die bestehende USP_SpecialFeatureInventory ergänzt aggregierten Featurekontext. Die neue Procedure verändert deren freigegebenen EXTERNAL_MODELS-Zeilenvertrag nicht.

## Primärquellen

- [Lokale Datenquellen](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-data-sources-transact-sql?view=sql-server-ver17)
- [Lokale Dateiformate](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-file-formats-transact-sql?view=sql-server-ver17)
- [Lokale externe Tabellen](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-tables-transact-sql?view=sql-server-ver17)
- [Lokale Modelle](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-models-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#monitorusp_externaldataanalysis)

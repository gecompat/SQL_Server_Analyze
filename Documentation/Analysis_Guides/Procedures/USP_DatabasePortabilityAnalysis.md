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

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Bracket-aware Pipe-Liste expliziter, einteiliger Datenbanknamen. NULL, leer oder nur U+0020-Leerzeichen wählt alle online befindlichen, zugänglichen Benutzerdatenbanken (database_id&gt;4). Ungültige/duplizierte Namen oder keine gültigen Namen ergeben INVALID_PARAMETER. Abgleich ist case-sensitiv unter SQL_Latin1_General_CP1_CS_AS; Systemdatenbanken sind ausgeschlossen. Sind alle explizit angeforderten Namen offline/unsichtbar, Status NOT_FOUND; bei teilweise fehlendem Scope AVAILABLE_LIMITED. Der Trenner &#124; wirkt außerhalb eckiger Klammern; ]] maskiert eine schließende Klammer. Äußere U+0020-Leerzeichen je Element werden entfernt. Leere Listenelemente sind ungültig; ein rohes Element ist auf 4.000 Zeichen und der ausgewertete Namensbestandteil auf 128 Zeichen begrenzt. |
| `@MaxZeilen` | `int` | `2000` | Positive Werte von 1 bis 2.147.483.647 begrenzen ausschließlich RAW- und JSON-Evidenzzeilen, sortiert nach DatabaseName, EvidenceType und FeatureName. 0 und NULL verwenden dort die technische Höchstgrenze 2.147.483.647 und bedeuten praktisch unbegrenzt. CONSOLE und TABLE übernehmen die gesamte materialisierte Evidenzmenge ohne dieses Limit; Status und Zählkopf beziehen sich ebenfalls auf die Vollmenge. Die Grenze reduziert die Quellabfragen nicht. Negative Werte sind ungültig, setzen INVALID_PARAMETER/IsPartial=1 und überspringen Quellenabfragen; RAW/JSON liefern dann eine leere Evidenzmenge mit sicherer TOP-Grenze 0. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel portability und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema. |
| `@JsonErzeugen` | `bit` | `0` | 0 lässt @Json NULL; 1 erzeugt nach DatabaseName, EvidenceType und FeatureName sortiertes Array mit derselben TOP-Grenze wie die Zeilenausgabe. NULL aktiviert IF nicht; leer wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben. |
| `@PrintMeldungen` | `bit` | `1` | 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@Hilfe` | `bit` | `0` | 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und OUTPUT-Zuweisungen, daher bleiben gebundene OUTPUT-Empfänger unverändert. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Im regulären Aufruf werden AVAILABLE (Quellen liefen), AVAILABLE_EMPTY (beide Evidenzquellen lieferten keine Zeile), AVAILABLE_LIMITED (mindestens eine Quelle/Datenbank eingeschränkt), NOT_FOUND (alle explizit genannten Benutzerdatenbanken offline oder unsichtbar) oder INVALID_PARAMETER (ungültige Zeilengrenze, Ausgabeart oder Namensliste) zurückgegeben. Die einzelnen Quellenzeilen haben zusätzlich AVAILABLE oder SOURCE_STATUS mit DENIED_PERMISSION, UNSUPPORTED_SOURCE, LOCK_TIMEOUT oder SOURCE_UNAVAILABLE. NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Bei regulärem Abschluss eine Meldung zu ungültigen Eingaben oder nicht verfügbaren angeforderten Datenbanken; sonst NULL. Einzelne Quellenfehler stehen in den Evidenzzeilen, ohne automatische Übernahme in diesen Parameter. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert. |

### RAW-Ausgabe

```sql
EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

### JSON-Ausgabe

```sql
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
```

### TABLE-Ausgabe

```sql
CREATE TABLE [#DatabasePortabilityAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N'{"portability":"#DatabasePortabilityAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#DatabasePortabilityAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];
    THROW;
END CATCH;
```

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_DatabasePortabilityAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

CONSOLE zeigt `portability`. RAW liefert Modulstatus und die begrenzten Evidenzzeilen. TABLE exportiert ausschließlich das stabile Resultset `portability`; JSON verwendet dieselbe materialisierte Datenbasis. Lesen Sie `DatabaseName`, `EvidenceType`, `SourceObject`, `StatusCode` und `EvidenceLimit` zuerst. `FeatureName`, `FeatureType` und `StatementType` erhalten ihre Bedeutung erst zusammen mit der jeweiligen Quellklasse.

## Beispiele und Gegenbeispiele

Eine neue synthetische Datenbank `ExamplePortableDatabase` ohne Zeilen in beiden DMVs ist ein zulässiger Leerfall. Eine synthetische Procedure mit einem expliziten Verweis auf `master.sys.databases` kann als `UNCONTAINED_ENTITY` erscheinen und begründet eine gezielte Reviewfrage. Ein Gegenbeispiel ist die Behauptung, jeder uncontained Eintrag verhindere eine Migration. Ebenso darf eine `Compression`-Zeile nicht ohne Zielversion und Ziel-Edition in eine Entfernungsempfehlung übersetzt werden.

## Leere oder partielle Ausgabe

`AVAILABLE_EMPTY` bedeutet nur, dass die beiden sichtbaren Quellen im gewählten Scope keine Zeilen lieferten. Fehler bleiben je Quelle als `SOURCE_STATUS`-Zeile mit `DENIED_PERMISSION`, `UNSUPPORTED_SOURCE`, `LOCK_TIMEOUT` oder `SOURCE_UNAVAILABLE` sichtbar und können `AVAILABLE_LIMITED` auslösen. Sind alle explizit angeforderten Datenbanken nicht verfügbar, bleibt die Abgrenzung als `NOT_FOUND` sichtbar.

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
| Begrenzungswirkung | Datenbankfilter begrenzt Quellen; `@MaxZeilen` begrenzt RAW/JSON, während CONSOLE/TABLE die vollständige materialisierte Evidenz übernehmen. |
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

Die Procedure liest zwei datenbanklokale Katalogsichten getrennt; ein Fehler einer Quelle unterdrückt die andere Quelle derselben Datenbank nicht.

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

## Laufzeitnachweis und offener Umfang

Am 5. Oktober 2026 bestand der erweiterte Vertrag
`121_OPS006_Database_Portability_Runtime_Contract.sql` zusammen mit dem
Framework-Smoke-Test in einem neu erzeugten SQL-Server-2025-Linux-Container
über Docker. Der Runner
`TestLab/Invoke-Ops006DatabasePortabilityScenario.ps1` installierte den
vollständigen Frameworkstand und entfernte anschließend seinen Container,
sein Volume und den temporären State. Die Instanz verwendete
`Latin1_General_100_CS_AS`; Framework- und Fixture-Datenbanken verwendeten
`SQL_Latin1_General_CP1_CS_AS`.

Eine synthetische Tabelle mit PAGE-Kompression lieferte `Compression` in
`sys.dm_db_persisted_sku_features`. Der Test verlangte anschließend dieselbe
Featureevidenz mit Datenbank, Quellname und `AVAILABLE`-Status im Analyzer-JSON.
Die vorhandenen Leer-, uncontained-, fehlenden und eingeschränkten Pfade
bestanden ebenfalls. Der ausgeführte SQL-Test hatte den SHA-256-Wert
`44dc7a165b92fffd2c990eea5f465fba052a974603de4cec60132cf69a9d5924`.

Der Nachweis ist lokale Worktree-Evidenz und kein Actions- oder Release-Gate.
Die Engine-Major-Version 17 wurde vom Lab verifiziert; die genaue
`ProductVersion` wurde für diesen Lauf nicht erfasst. Die neue Featureassertion
wurde auf SQL Server 2019 und 2022 nicht ausgeführt. Die
historischen Basisnachweise
bleiben davon getrennt. Eine auf der jeweiligen Engine tatsächlich nicht
verfügbare Systemquelle bleibt offen; der Status von `OPS-006` bleibt deshalb
`PARTIAL_PRODUCT_FUNCTION`.

## Primärquellen

- [sys.dm_db_persisted_sku_features](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-persisted-sku-features-transact-sql?view=sql-server-ver17)
- [Contained Databases und uncontained entities](https://learn.microsoft.com/en-us/sql/relational-databases/databases/contained-databases?view=sql-server-ver17)

[Technische Detailbeschreibung](../../../Code/08_ServerHealth/200_USP_DatabasePortabilityAnalysis.sql)

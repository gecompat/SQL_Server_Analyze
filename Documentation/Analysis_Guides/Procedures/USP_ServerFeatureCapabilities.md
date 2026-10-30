# [monitor].[USP_ServerFeatureCapabilities]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Zeigt versions-, editions-, plattform- und datenbankbezogene Featurefähigkeiten einschließlich SQL-Server-2025-JSON-Indexmetadaten.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche versions-, plattform- und datenbankabhängigen Diagnosepfade kann das Framework auf dieser Instanz verwenden, und welcher Fallback gilt?** Sie prüft Capability-Metadaten für Berechtigungsnamen, ZSTD, Resource Governor, Linux-Host-DMVs, Optimized Locking, Query-Store-Replikainformation sowie optionale Vector- und JSON-Indizes. Eine Capabilityzeile ist eine Routingentscheidung für Diagnosecode, kein Gesundheitsbefund.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein auffälliger Einzelwert ist eine Beobachtung, aber noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem tatsächliche Feature-Nutzung, Lizenzberechtigung außerhalb der ausgewiesenen Produktmetadaten, Funktionsfähigkeit eines End-to-End-Szenarios oder zukünftige Verfügbarkeit nach Upgrade/CU. `AVAILABLE` bedeutet, dass der implementierte Probe-Pfad die Capability als vorhanden einstuft; es ersetzt keine Berechtigungsprobe im späteren Aufruf und keine fachliche Validierung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerFeatureCapabilities]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

### JSON- und TABLE-Beispiele

JSON ist unabhängig von CONSOLE/RAW/TABLE/NONE; OUTPUT muss explizit gebunden werden:

```sql
DECLARE @FeatureJson nvarchar(max);
EXEC [monitor].[USP_ServerFeatureCapabilities] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@FeatureJson OUTPUT;
```

TABLE akzeptiert nur das Ziel capabilities. Ein vorhandenes leeres Einspalten-Dummyziel genügt; der gemeinsame Writer passt es an das Quellschema an, ohne Seed-Zeile:

```sql
CREATE TABLE #ServerFeatureCapabilities_HelpExample (Placeholder int NULL);
EXEC [monitor].[USP_ServerFeatureCapabilities] @ResultSetArt='TABLE', @ResultTablesJson=N'{"capabilities":"#ServerFeatureCapabilities_HelpExample"}';
```

Der registrierte OBJECT_ANALYSIS_CURRENT-Pfad hat RequiresGroupGate=0; @HighImpactConfirmed aktiviert hier kein Gate und erteilt keine Gruppenberechtigung. Der Kandidatenhelfer lehnt NULL dennoch ab. T-SQL konvertiert numerisch 0 zu bit 0 und jeden Nichtnullwert zu bit 1; Werte als 0/1 übergeben.

## Parametervertrag

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Ausgelassen = NULL. NULL, leer oder nur Leerzeichen: alle sichtbaren zulässigen Online-Datenbanken (Systemdatenbanken abhängig von @SystemdatenbankenEinbeziehen); sonst bracket-aware Pipe-Liste einteiliger SQL-Namen. Ein Pipe trennt nur außerhalb von [...]; ]] maskiert eine schließende Klammer, \| innerhalb [...] bleibt im Namen. Leere, ungültige, mehrteilige, zu lange oder doppelte Namen führen im Helfer zur Auswahlfehlermeldung. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | Ausgelassen = 0. 0 schließt master, tempdb, model und msdb aus; 1 lässt Systemdatenbanken im Kandidatenscope zu. NULL wird vom Kandidatenhelfer als INVALID_PARAMETER abgelehnt. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Ausgelassen = NULL. NULL lässt den Patternfilter aus; andernfalls alternativ zu @DatabaseNames. Äußere Leerzeichen werden entfernt; Präfixe werden ohne Beachtung der Groß-/Kleinschreibung erkannt: like: (SQL-LIKE), regex: (case-sensitive Regex, Flag c), regexi: (case-insensitive Regex, Flag i); ohne Präfix gilt SQL-LIKE. LIKE nutzt %, _ und SQL-Zeichenklassen [...] mit SQL_Latin1_General_CP1_CS_AS. Nach Präfixentfernung bleibt der Patterninhalt unverändert; leeres Pattern ist ungültig. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; Syntax und Treffer werden erst bei Ausführung bewertet. |
| `@HighImpactConfirmed` | `bit` | `0` | Ausgelassen = 0. Der Wert wird an USP_PrepareDatabaseCandidates übergeben. Die tatsächlich aktivierte Klasse OBJECT_ANALYSIS_CURRENT hat RequiresGroupGate=0; weder 0 noch 1 schaltet hier ein High-Impact-Gruppengate oder verleiht Gruppenberechtigung. NULL wird auch ohne aktives Gate als INVALID_PARAMETER abgelehnt. Numerisch 0 wird bit 0, jeder Nichtnullwert bit 1. |
| `@MitSpezialindizes` | `bit` | `1` | Ausgelassen = 1. 1 erfasst die optionalen Vector-/JSON-Spezialindizes; 0 und NULL lassen diesen Zweig aus. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1. |
| `@MitQueryStoreReplicas` | `bit` | `1` | Ausgelassen = 1. 1 erfasst Query-Store-Replica-Metadaten; 0 und NULL lassen diesen Zweig aus. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1. |
| `@MitPlattformdetails` | `bit` | `1` | Ausgelassen = 1. 1 ergänzt Linux-Host-DMV-Capabilities; 0 und NULL lassen diesen Zweig aus. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1. |
| `@MaxZeilen` | `int` | `5000` | Ausgelassen = 5000. NULL oder 0 bedeutet unbegrenzt; ein positiver Wert begrenzt nach der Erhebung unabhängig je capabilities-, databaseFeatures- und specialIndexes-Export in deren dokumentierter Sortierung. Ein negativer Wert setzt INVALID_PARAMETER. Das Limit reduziert keine Katalogprobes und kürzt keine Warnungen. |
| `@ResultSetArt` | `varchar(16)` | `CONSOLE` | Ausgelassen = CONSOLE. Äußere Leerzeichen werden entfernt und der Wert wird großgeschrieben. Zulässig sind vollständig: CONSOLE (eine formatierte Ausgabe pro Resultset, einschließlich Leerhinweis), RAW (technische Resultsets), TABLE (nur capabilities in Zieltabellen) und NONE (keine fachlichen Resultsets). NULL, leer und jeder andere Wert sind INVALID_PARAMETER. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Ausgelassen = NULL. Nur bei ResultSetArt=TABLE zulässig; das JSON-Objekt muss genau die registrierte Zuordnung capabilities auf eine vorhandene lokale #Temp-Tabelle enthalten. Nicht-TABLE mit nichtleerem Wert wirft Fehler 51011. TABLE-Preflight läuft vor Hilfe und Katalogprobes. Eine leere vorhandene lokale Tabelle mit einer beliebigen Dummyspalte wird vom Writer an das Quellschema angepasst; keine Seed-Zeile erforderlich. |
| `@JsonErzeugen` | `bit` | `0` | Ausgelassen = 0. 1 erzeugt JSON unabhängig von ResultSetArt; 0 und NULL erzeugen kein JSON. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Ausgelassen = NULL als OUTPUT-Parameter. Mit OUTPUT binden. Der Eingabewert wird beim Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 enthält der Rückgabewert meta, capabilities, databaseFeatures, specialIndexes und warnings. Hilfe kehrt nach dem TABLE-Preflight ebenfalls mit NULL zurück. |
| `@PrintMeldungen` | `bit` | `1` | Ausgelassen = 1. 1 gibt bei einem Status ungleich AVAILABLE die normale Statuswarnung aus; 0 und NULL unterdrücken diese Meldung. Die Hilfe-PRINT-Ausgabe wird dadurch nicht unterdrückt. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1. |
| `@Hilfe` | `bit` | `0` | Ausgelassen = 0. Nur 1 druckt Hilfe und kehrt vor Auswahl, Katalogprobes und normaler Parameter-/Filtervalidierung zurück; 0 und NULL führen den normalen Ablauf aus. @Json wird davor auf NULL gesetzt. Der TABLE-Zielpreflight und die Ablehnung eines nichtleeren @ResultTablesJson außerhalb von TABLE liegen davor. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1. |

## Resultsets und Leserichtung

RAW und CONSOLE liefern Aufrufstatus, serverweite Capabilities, datenbankbezogene Capabilities, optional Spezialindizes und zuletzt Warnungen. Die Datenbankresultsets sind nicht atomar zum Serverprobe; Statuswechsel während des Datenbankcursors sind möglich. TABLE exportiert ausschließlich das registrierte Resultset `capabilities` und enthält damit weder datenbankbezogene Features noch Spezialindizes. JSON ist für die vollständige maschinelle Hülle geeigneter und enthält `meta`, `capabilities`, `databaseFeatures`, `specialIndexes` und `warnings`.

Die sieben Textspalten des TABLE-Exports verwenden die Frameworkcollation
`SQL_Latin1_General_CP1_CS_AS`. Auch die übrigen lokalen Textspalten der
Kandidaten-, Warnungs-, Feature- und Indexmengen sind explizit collatiert.
Das serverweite Capabilitylimit wird nach der Erhebung und Statusbewertung
einheitlich in der Reihenfolge `(ScopeName, FeatureName)` angewandt.
TABLE, RAW, CONSOLE und JSON verwenden dadurch dieselbe begrenzte
Capabilitymenge. `NULL` und `0` liefern die vollständige Menge; Warnungen
werden durch ein positives Capabilitylimit nicht entfernt. Das Ausgabelimit
verringert die zuvor ausgeführten Katalogprobes nicht.

SQL25-002 ergänzt `JSON_INDEX_METADATA` in `databaseFeatures` und
`IndexFamily = JSON` in `specialIndexes`. Die Detailspalte enthält nur
Array-Suchoption, Pfadanzahl und Disabled-Status. Konkrete SQL/JSON-Pfade
bleiben dem enger gefilterten `USP_ObjectInventory` vorbehalten;
JSON-Dokumentwerte werden in keinem der beiden Pfade gelesen.

Die Erkennung von `sys.vector_indexes` und `sys.query_store_replicas`
verwendet `sys.all_views` mit dem Schemafilter `sys`, damit Systemviews
berücksichtigt werden. Ein vorhandener Vector-Katalog ohne sichtbare
Indexzeilen liefert keine `VECTOR`-Zeile in `specialIndexes`; diese leere
Menge führt nicht zu `UNAVAILABLE_VERSION`. Die Query-Store-Replica-Capability
wird bei vorhandenem Katalog als `AVAILABLE` gemeldet. Bei aktivierter
Replica-Option enthält `QUERY_STORE_REPLICA_GROUP_COUNT` die sichtbare
Gruppenzahl, einschließlich eines gemessenen Nullwerts.

## Eine Zeile bedeutet

Im Serverresultset identifiziert `(ScopeName, FeatureName)` eine Capability. Im Datenbankresultset gilt `(DatabaseName, FeatureName)`, im Spezialindexresultset eine konkrete Indexidentität aus Datenbank, Schema, Objekt und Index. Eine Warnungszeile steht für einen fehlgeschlagenen Datenbank- oder Selektionspfad; diese Granularitäten dürfen nicht miteinander gezählt oder gejoint werden, ohne den Resultsettyp zu erhalten.

## So lesen

Berücksichtigen Sie zuerst Gesamtstatus und Warnungen. Danach `AvailabilityStatus`, `LogicPath`, `SourceObject`, `RequiredPermission` und `Detail` als Einheit interpretieren: `UNAVAILABLE_VERSION` oder `UNAVAILABLE_PLATFORM` kann einen dokumentierten Fallback besitzen. Datenbank-Compatibility und `FeatureValue` sind separate Evidenz; die bloße Existenz einer Systemview beweist weder gefüllte Daten noch Zugriffsrecht.

## Warum kann das problematisch sein?

Ein Codepfad kann auf der Hauptversion existieren, aber wegen Plattform, Edition, Build oder Compatibility nicht nutzbar sein.

## Wann ist es kein Problem?

Ein nicht unterstütztes Feature ist kein Fehler, wenn es nicht benötigt wird.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** `ExampleDb` soll einen 2025-spezifischen Diagnosepfad verwenden, die Capability meldet jedoch `UNAVAILABLE_VERSION` oder einen nicht passenden Fallback. Der Aufrufer muss beim kompatiblen Pfad bleiben und darf die neuere Systemspalte nicht statisch referenzieren.

**Ähnlich aussehender Gegenfall:** Eine Linux-spezifische Host-DMV ist auf Windows erwartungsgemäß `UNAVAILABLE_PLATFORM`; der allgemeine OS-/SQL-Prozess-Fallback kann vollständig ausreichen. Das ist keine degradierte Servergesundheit.

## Leere oder partielle Ausgabe

Eine leere Spezialindexmenge kann korrekt bedeuten, dass die Sicht verfügbar ist, aber im gewählten Scope kein entsprechender Index existiert. Fehlt eine explizit angeforderte Datenbank oder scheitert ihr dynamischer Probe, steht dies im Warnungsresultset und `IsPartial` ist maßgeblich. Ein fehlendes datenbankbezogenes Resultset darf nicht aus einem vorhandenen Server-Capability-Resultset als Erfolg abgeleitet werden.

Für `USP_ServerFeatureCapabilities` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Eine `ExampleDatabase` mit kleinen server- und datenbankweiten Katalogprobes; standardmäßig werden Plattform, Query-Store-Replikasicht und verfügbare Spezialindexmetadaten geprüft. Es werden keine Benutzerdaten oder Historien gelesen. |
| Teuerster Pfad | Alle sichtbaren Datenbanken mit `@MitSpezialindizes = 1`, `@MitQueryStoreReplicas = 1` und Plattformdetails. Falls die SQL-Server-2025-Sichten vorhanden sind, werden alle sichtbaren Vector- und JSON-Indexzeilen im Scope materialisiert. |
| Haupttreiber | Zahl ausgewählter Datenbanken und – auf unterstützten Builds – Zahl sichtbarer Vector- und JSON-Indizes sowie JSON-Pfadzeilen. Die übrigen Capabilityprobes lesen kleine Katalogmengen beziehungsweise zählen Query-Store-Replikagruppen. |
| Skalierung | Der dynamische Probe wird einmal je Datenbank kompiliert/ausgeführt. Laufzeit wächst annähernd mit der Datenbankanzahl; Spezialindexmaterialisierung und Ergebnistransfer wachsen zusätzlich mit der Zahl entsprechender Indizes. |
| Ressourcen | Vor allem CPU und Katalogseiten, geringe TempDB-/Arbeitstabellenlast sowie dynamischer Compileaufwand je Datenbank. Kein Showplan-, XEL-, Payload- oder Benutzertabellenscan. |
| Begrenzungswirkung | Datenbankliste/-pattern begrenzen den Cursor früh. `@MaxZeilen` wird erst beim Ausgeben jedes fachlichen Resultsets angewandt; es begrenzt weder die Zahl geprüfter Datenbanken noch die zuvor materialisierten Spezialindizes. |
| Locking und Nebenwirkungen | Rein lesende `NOLOCK`-/Katalogprobes; keine Konfigurationsänderung. Parallel laufendes DDL, Upgrade oder Failover kann zwischen Server- und Datenbankprobe ein zeitlich uneinheitliches Ergebnis erzeugen. Der vorherige Session-`LOCK_TIMEOUT` wird nach dem Aufruf wiederhergestellt. |
| Schutzmechanismus | Der Kandidatenpfad nutzt OBJECT_ANALYSIS_CURRENT, dessen Klassenkatalog RequiresGroupGate=0 ausweist. @HighImpactConfirmed schaltet hier weder Gate noch Deep-Pfad frei und verleiht keine Gruppenberechtigung; der explizite Datenbankscope begrenzt die Auswahl. Der Helper lehnt NULL für den Parameter dennoch ab. |
| Sicherer Einsatz | Eine `ExampleDatabase`; bei reiner Serverroutingfrage optionale Spezialindizes und Query-Store-Replikaprobe deaktivieren. Erst nach vollständigem Status auf weitere Datenbanken erweitern. |
| Aussagegrenze | Capability und Systemobjektexistenz sind kein Nutzungs-, Berechtigungs- oder Funktionstest. Ein Outputlimit kann relevante spätere Zeilen verbergen, obwohl alle Quellen bereits gelesen wurden. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche versions-/editionsabhängigen Frameworkpfade sind auf dieser Instanz technisch möglich und lesbar?

### Technischer Hintergrund

Die Procedure verbindet Product Major Version, Edition/Engine Edition, Compatibility und die Existenz versionsabhängiger Systemobjekte/Spalten. Capability-Probes vermeiden Compilefehler durch statische Referenzen auf nicht vorhandene Quellen und führen optionale Abfragen geschützt dynamisch aus.

### Datenkette

`master.sys.all_objects`, `sys.databases`, `sys.dm_os_host_info`, `sys.json_indexes`, `sys.json_index_paths`, `sys.objects`, `sys.query_store_replicas`, `sys.resource_governor_configuration`, `sys.schemas`, `sys.sp_executesql`, `sys.vector_indexes`, `sys.views`.

### Source Select

Der datenbanklokale Capability-Kern prüft aktuelle Versionsmerkmale direkt am Datenbankkatalog:

```sql
-- Dieser Zweig gilt für SQL Server 2025 oder neuer.
SELECT
      [d].[name] AS [DatabaseName]
    , [d].[compatibility_level]
    , [d].[state_desc]
    , [d].[is_optimized_locking_on]
    , CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) AS [CurrentMajorVersion]
FROM [sys].[databases] AS [d] WITH (NOLOCK)
WHERE [d].[database_id] = DB_ID();
```

**Wichtig für die Eigenlast:** Legen Sie Datenbankscope vor Katalog-Existenz- und Probezugriffen fest. Die Spalte `is_optimized_locking_on` wird nur im SQL-Server-2025-Pfad kompiliert; versionsspezifische Sichten wie Vector-/JSON-Indizes und Query Store Replicas werden nur nach Versions-, Objekt- und Pflichtspaltenprüfung gelesen. `sys.json_indexes` und `sys.json_index_paths` werden je Zieldatenbank und Aufruf höchstens einmal ausgeführt; die alternative Indexabfrage ohne Pfadquelle ist zum Pfadzweig gegenseitig exklusiv.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Instanz- und Datenbankzustand. Ein Upgrade, ein Compatibilitywechsel, ein Failover oder eine Berechtigungsänderung können das Ergebnis ändern.

### Bewertung und Gegenprobe

Berücksichtigen Sie `AvailabilityStatus`, Objekt-/Viewexistenz, Plattform, Datenbank-Compatibility, benötigte Berechtigung und Fallbackpfad getrennt. Die Procedure besitzt kein generisches `Usable`-Bit; die konkrete Nutzbarkeit ergibt sich erst aus der Capabilityzeile plus Berechtigungs- und Aufrufkontext.

### Typische Fehlinterpretation

Version allein reicht nicht: SQL Server 2025 mit niedriger Compatibility kann Features nicht im Querykontext aktivieren. Objekt vorhanden beweist keine nutzbare Datenlage. Ein sichtbarer JSON-Index und seine Pfadzahl beweisen weder Nutzung noch Gesundheit, Nutzen oder Rebuildbedarf.

### Folgeanalyse

Verwenden Sie den betroffenen Diagnosepfad nur bei passendem `AvailabilityStatus`, Scope und passender Berechtigung. Nutzen Sie andernfalls den ausgewiesenen Fallback und bewahren Sie die Warnungen als Evidenz auf.

## Primärquellen

- [SQL-Server-Katalogsichten](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql?view=sql-server-ver17)
- [sys.json_indexes (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-json-indexes-transact-sql?view=sql-server-ver17)
- [sys.json_index_paths (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-json-index-paths-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#1-monitorusp_serverfeaturecapabilities)

[SQL-Server-2025-JSON-Index-Vertrag](../../Architecture/SQL_Server_2025_JSON_Index_Inventory.md)

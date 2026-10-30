# [monitor].[USP_SpecialFeatureInventory]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Erkennt leichtgewichtig verwendete Spezialfeatures und empfiehlt passende Tiefenanalysen.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche besonderen oder versionsabhängigen Datenbankfeatures sind im sichtbaren Scope erkannt oder lediglich konfiguriert, und welches spezialisierte Modul gehört dazu?** Sie ist eine leichtgewichtige Landkarte vor Migration, Upgrade, Betriebsübergabe oder gezielter Tiefenanalyse. Sie bewertet ausdrücklich nicht, ob ein erkanntes Feature gesund, performant oder fachlich noch genutzt ist.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein auffälliger Einzelwert ist eine Beobachtung, aber noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Featureinhalte, Objektdefinitionen, externe Locations, Credentials, Broker-Nachrichten, CLR-Binaries oder tatsächliche Laufzeitnutzung. Die Zähler fassen je Feature unterschiedliche Katalogobjekte zusammen und sind deshalb weder datenbankübergreifende Nutzungsmetriken noch untereinander vergleichbare Größen. Eine Nullzählung gilt nur für sichtbare Metadaten im gewählten Scope.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SpecialFeatureInventory]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurErkannteFeatures = 1,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und Aufrufbeispiele

| Parameter | Typ = Default | Verhalten |
|---|---|---|
| `@DatabaseNames` | `nvarchar(max) = NULL` | NULL, leer oder Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste einteiliger Namen; ungültige/duplizierte Namen ungültig. Liste und Pattern sind exklusiv. |
| `@SystemdatenbankenEinbeziehen` | `bit = 0` | 0 schließt `master`, `tempdb`, `model`, `msdb` aus; 1 lässt sie zu. NULL ungültig; numerische Nichtnullwerte konvertieren zu 1. |
| `@DatabaseNamePattern` | `nvarchar(4000) = NULL` | SQL-LIKE (`%`, `_`, Zeichenklassen) oder `regex:`/`regexi:`. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. |
| `@HighImpactConfirmed` | `bit = 0` | Wird an den Helfer übergeben. `@AnalysisClass = NULL`, also kein High-Impact-/Gruppengate für diese Procedure. NULL ungültig. |
| `@NurErkannteFeatures` | `bit = 0` | 1 behält `DETECTED` und `CONFIGURED_ONLY`; 0 zeigt auch nicht erkannte, versionsbedingt nicht verfügbare und fehlerhafte Quellzeilen. NULL ungültig. |
| `@MaxZeilen` | `int = 2000` | NULL/0 unbegrenzt; positiv begrenzt die sortierte Featureausgabe nach vollständiger Inventur; negativ `INVALID_PARAMETER`. Datenbankstatus und Vollzähler bleiben ungekürzt. |
| `@LockTimeoutMs` | `int = 0` | 0–60000 für Katalogpfade; vorheriger Sessionwert wird vor Ausgabe wiederhergestellt. Kein Berechtigungs- oder Warte-Opt-in. NULL/außerhalb ungültig. |
| `@ResultSetArt` | `varchar(16) = 'CONSOLE'` | Getrimmt/case-insensitiv: `CONSOLE`, `RAW`, `TABLE`, `NONE`; sonst `INVALID_PARAMETER`. |
| `@ResultTablesJson` | `nvarchar(max) = NULL` | Nur TABLE; registrierte Zuordnung `features` auf eine leere vorhandene lokale #Temp-Tabelle mit einer Seed-Spalte. Preflight läuft vor Hilfe und Inventur. |
| `@JsonErzeugen` | `bit = 0` | 1 erzeugt JSON unabhängig vom Resultsetmodus; 0 lässt es aus. NULL ungültig. |
| `@Json` | `nvarchar(max) = NULL OUTPUT` | OUTPUT-Bindung erforderlich; Objekt mit `meta`, `databaseStatus`, `features`. Wird beim Eintritt auf NULL gesetzt. |
| `@PrintMeldungen` | `bit = 1` | Steuert normale Statusmeldungen, nicht Hilfe-PRINTs. NULL ungültig. |
| `@Hilfe` | `bit = 0` | Nur 1 druckt Hilfe und kehrt früh zurück; NULL läuft normal. Vorher: JSON leeren und bei TABLE Mapping-Preflight. |
| `@StatusCodeOut`, `@IsPartialOut` | `varchar(40) = NULL OUTPUT`, `bit = NULL OUTPUT` | Normaler Status und Partialität; mit OUTPUT binden. Hilfe lässt übergebene Werte unverändert. |
| `@ErrorNumberOut`, `@ErrorMessageOut` | `int = NULL OUTPUT`, `nvarchar(2048) = NULL OUTPUT` | Normaler Fehlercode/-text beziehungsweise NULL; mit OUTPUT binden. Hilfe lässt übergebene Werte unverändert. |

Bitparameter unterliegen der T-SQL-Zahlkonvertierung: 0 ergibt 0, jeder Nichtnullwert ergibt 1. Die NULL-Regeln sind parameterabhängig.

`DETECTED` = sichtbarer Katalogmarker; `CONFIGURED_ONLY` = Konfiguration ohne belegte Laufzeitnutzung; `NOT_DETECTED_VISIBLE_SCOPE` = kein Marker im sichtbaren Scope; `UNAVAILABLE_VERSION` = versionsbedingt nicht verfügbar; `SOURCE_UNAVAILABLE` = Quellenfehler/Evidenzlücke. `DetectedItemCount` summiert je Feature unterschiedliche Metadatenarten. 0 ist ein sichtbarer Nullwert; NULL bedeutet unbekannt/nicht verfügbar. Erst Aufruf- und Datenbankstatus, dann DetectionStatus und EvidenceLimit lesen.

CONSOLE gibt Status-/Datenbankstatus-/Featureinformationen und die formatierte Featureausgabe aus. RAW liefert Aufrufstatus, Datenbankstatus und technische Featurezeilen. TABLE exportiert nur `features`; NONE unterdrückt fachliche Resultsets. JSON wird unabhängig über `@JsonErzeugen` erzeugt.

JSON-Aufruf mit unabhängigem OUTPUT-Wert:

```sql
DECLARE @FeatureJson nvarchar(max);
EXEC [monitor].[USP_SpecialFeatureInventory]
      @DatabaseNames=N'[ExampleDatabase]',
      @ResultSetArt='NONE',
      @JsonErzeugen=1,
      @Json=@FeatureJson OUTPUT;
```

TABLE-Aufruf mit leerem Einspaltenziel; der Writer ersetzt die Dummy-Spalte durch das registrierte Schema:

```sql
CREATE TABLE #SpecialFeatureInventory_HelpExample (Placeholder int NULL);
EXEC [monitor].[USP_SpecialFeatureInventory]
      @DatabaseNames=N'[ExampleDatabase]',
      @ResultSetArt='TABLE',
      @ResultTablesJson=N'{"features":"#SpecialFeatureInventory_HelpExample"}';
```

`ExampleDatabase` ist synthetisch; die Zieltemp-Tabelle muss leer sein.

## Resultsets und Leserichtung

CONSOLE liefert genau ein fachliches Feature-Resultset; eine leere Auswahl erhält die zentrale Console-Leerzeile. RAW liefert zuerst den Aufrufstatus, danach die Datenbankstatuszeilen und zuletzt die Featurezeilen mit technischen Spalten. TABLE exportiert ausschließlich das registrierte Resultset `features`; Datenbankstatus und Aufrufstatus müssen bei automatisierter Verarbeitung über OUTPUT-Parameter beziehungsweise einen separaten Kontrolllauf gesichert werden. JSON enthält dagegen `meta`, `databaseStatus` und `features` gemeinsam. Berücksichtigen Sie immer zuerst `StatusCode`, `IsPartial`, Datenbankstatus und erst danach `DetectionStatus`.

TABLE, CONSOLE, RAW und das JSON-Array `features` verwenden dieselbe nach
`(DatabaseName, FeatureCode)` sortierte Auswahl. `@NurErkannteFeatures = 1`
erhält nur `DETECTED` und `CONFIGURED_ONLY`; ein positiver Wert in
`@MaxZeilen` begrenzt anschließend diese Auswahl. `NULL` und `0` setzen kein
Zeilenlimit. Die Aufrufmetadaten und Datenbankstatuszähler beschreiben weiterhin
die vollständige Inventur vor dem Ausgabefilter. Die 21 Textspalten der vier
lokalen Quelltabellen und die neun TABLE-Textspalten verwenden ausdrücklich
`SQL_Latin1_General_CP1_CS_AS`; die öffentliche Feldstruktur bleibt erhalten.

## External Models

Die zusätzliche Featurezeile `EXTERNAL_MODELS` enthält ab SQL Server 2025 ausschließlich die sichtbare Anzahl aus `sys.external_models`. Modellnamen, Locations, Parameter, Besitzer, Credentialbezüge und Inhalte werden nicht gelesen. Die Procedure ruft keine AI-Funktion oder externe Verbindung auf. Ein positiver Katalogwert beweist weder Erreichbarkeit noch Ausführung oder Gesundheit.

Auf älteren Engines lautet der DetectionStatus `UNAVAILABLE_VERSION` mit einer unbekannten Anzahl. Eine unbekannte Engineversion oder ein tatsächlicher Quellenfehler erzeugt `SOURCE_UNAVAILABLE`, erhält andere Featurezeilen und macht den Datenbankstatus partiell. Tatsächliche Fehler bleiben mit ihrem ersten nativen Fehlerpaar an die betroffene Datenbank gebunden. Ein erfolgreicher Nullwert gilt ausschließlich für sichtbare Metadaten.

Die zusätzliche Defaultzeile verändert die Featurezähler und kann bei begrenzter Ausgabe andere Featurezeilen aus dem Ausschnitt verdrängen. `@NurErkannteFeatures=1` behält sie nur bei `DETECTED`; Sortierung, Felder, Ausgabearten und JSON-Schema 1 bleiben erhalten. Der vollständige Vertrag steht in der [WI-0007-Spezifikation](../../Architecture/WI0007_External_Model_Inventory_Public_Specification.md).

## Eine Zeile bedeutet

Im Feature-Resultset identifiziert `(DatabaseName, FeatureCode)` eine Zeile. `DetectedItemCount` kann je Code verschiedene Dinge addieren – etwa Tabellen plus Dateigruppen oder Kataloge plus Indizes – und darf daher nur innerhalb der dokumentierten Featuresemantik interpretiert werden. Im Datenbankstatus steht eine Zeile für den Auswertungsversuch einer Datenbank, nicht für ein Feature.

## So lesen

`DETECTED` bedeutet mindestens einen sichtbaren Katalogmarker; `CONFIGURED_ONLY` belegt nur eine Konfiguration; `NOT_DETECTED_VISIBLE_SCOPE` ist keine globale Abwesenheitsgarantie. `UNAVAILABLE_VERSION` und `SOURCE_UNAVAILABLE` sind Evidenzlücken, keine Nullmessungen. Berücksichtigen Sie danach `ConfigurationState`, `RecommendedModuleStatus` und besonders `EvidenceLimit`. `NOT_PLANNED` bedeutet nur, dass das Framework kein eigenes Deep-Dive-Modul anbietet. Die `VECTOR`-Zeile verweist bei sichtbaren nativen Vector-Spalten auf die implementierte `USP_VectorIndexAnalysis`. Die native `JSON`-Zeile verweist für sichtbare JSON-Index- und SQL/JSON-Pfadmetadaten auf das bestehende `USP_ObjectInventory`; dafür wurde bewusst keine eigene Procedure ergänzt.

## Warum kann das problematisch sein?

Spezialfeatures benötigen eigene Backup-, Kapazitäts-, Betriebs- und Performancebetrachtung, die Standardanalysen nicht vollständig abdecken.

## Wann ist es kein Problem?

Erkennung ist Inventar, kein Fehlerbefund.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Für eine Migration von `ExampleDb` werden Temporal Tables und CLR erkannt. Das ist kein Defekt, aber ein belastbarer Hinweis, Retention/History mit `USP_TemporalAnalysis` zu prüfen und die CLR-Abhängigkeit separat durch den zuständigen Owner zu verifizieren, bevor die Zielplattform festgelegt wird.

**Ähnlich aussehender Gegenfall:** `EXTERNAL_SCRIPTS = CONFIGURED_ONLY` beweist keine ausgeführte externe Sprache. Die serverweite Option kann absichtlich bereitstehen, obwohl `ExampleDb` keine entsprechende Laufzeitabhängigkeit besitzt.

## Leere oder partielle Ausgabe

Mit `@NurErkannteFeatures = 1` kann das Feature-Resultset korrekt leer sein, obwohl die Datenbank vollständig geprüft wurde. Ohne diesen Filter erscheinen nicht erkannte und versionsbedingt nicht verfügbare Codes ausdrücklich. Eine nicht auswertbare Datenbank steht im Datenbankstatus als Teilfehler; fehlende Metadata Visibility kann außerdem zu Nullzählungen führen, ohne einen technischen Fehler auszulösen.

Für `USP_SpecialFeatureInventory` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Eine explizit benannte `ExampleDatabase`; je unterstütztem Feature werden nur aggregierte Systemkatalogzählungen ausgeführt. Es gibt keine Benutzertabellen-, Payload-, Definitions- oder Runtime-History-Scans. |
| Teuerster Pfad | `@DatabaseNames = NULL` über alle sichtbaren Userdatenbanken, optional einschließlich Systemdatenbanken. Pro Datenbank laufen die festen Katalogzählungen für alle unterstützten Featurecodes; ein VOLL- oder Child-Deep-Pfad existiert nicht. |
| Haupttreiber | Zahl ausgewählter Datenbanken und Zahl sichtbarer Zeilen in Katalogen wie `sys.tables`, `sys.columns`, `sys.types`, `sys.assemblies` und den featureeigenen Katalogsichten. Die ausgegebenen Featurezeilen sind dagegen nahezu konstant je Datenbank. |
| Skalierung | Die Quellarbeit wächst ungefähr mit Datenbankanzahl und Kataloggröße. Dynamisches SQL wird einmal je Datenbank kompiliert/ausgeführt; die kleine Ergebnismenge und ihre Sortierung sind normalerweise nicht der dominante Anteil. |
| Ressourcen | Vor allem CPU und Katalogseiten im Buffer Pool; kleine temporäre Ergebnistabellen und wenig Ergebnistransfer. Keine XEL-Dateien, Query-Pläne, Benutzerdaten oder Featurepayloads werden materialisiert. |
| Begrenzungswirkung | `@DatabaseNames` beziehungsweise das Datenbankpattern begrenzen die Quellarbeit vor dem Datenbankcursor. `@NurErkannteFeatures` und `@MaxZeilen` wirken erst auf die bereits vollständig erzeugte Featureinventur und reduzieren daher primär Ausgabe/JSON, nicht die Katalogzählungen. |
| Locking und Nebenwirkungen | Rein lesende Katalogabfragen mit `NOLOCK`; keine Feature-, Daten- oder Konfigurationsänderung. Gleichzeitiges DDL kann einen zeitlich uneinheitlichen Katalogsnapshot erzeugen. Der angeforderte `LOCK_TIMEOUT` wird für die Katalogpfade verwendet und anschließend auf den vorherigen Sessionwert zurückgesetzt. |
| Schutzmechanismus | Der Kandidatenpfad verwendet absichtlich `@AnalysisClass = NULL`; es gibt kein Deep-Gate und `@HighImpactConfirmed` aktiviert hier keinen teureren Pfad. Schutz bieten der explizite Datenbankscope und `@LockTimeoutMs`, nicht die Bestätigung. |
| Sicherer Einsatz | Mit genau einer `ExampleDatabase` beginnen. Erst wenn deren Datenbankstatus vollständig ist und die Laufzeit zur Kataloggröße passt, den Scope datenbankweise erweitern. |
| Aussagegrenze | Katalogzählungen zeigen sichtbare Existenz oder Konfiguration, nicht Nutzung, Gesundheit oder Vollständigkeit. Outputfilter können Featurecodes ausblenden; Metadata Visibility kann trotz erfolgreichem Status zu Nullzählungen führen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche besonderen oder versionsabhängigen Datenbankfeatures und Objektarten sind im gewählten Scope konfiguriert?

### Technischer Hintergrund

Der Datenbankcursor führt einen festen Satz aggregierter Katalogzählungen für In-Memory OLTP, Temporal, Service Broker, Full-Text, Change Tracking, CDC, Verschlüsselung, CLR, External Tables/Models/Runtimes, FILESTREAM/FileTable, Graph, Spatial, XML, native JSON-/Vector-Typen und benutzerdefinierte Typen aus. Er liest keine Objektdefinition oder Nutzdaten. Jede Featurezeile trägt ihre konkrete Quellliste und Aussagegrenze selbst.

### Datenkette

`sys.assemblies`, `sys.change_tracking_databases`, `sys.change_tracking_tables`, `sys.column_encryption_keys`, `sys.column_master_keys`, `sys.columns`, `sys.configurations`, `sys.databases`, `sys.external_data_sources`, `sys.external_languages`, `sys.external_libraries`, `sys.external_models`, `sys.external_tables`, `sys.filegroups`, `sys.fulltext_catalogs`, `sys.fulltext_indexes`, `sys.objects`, `sys.service_queues`, `sys.services`, `sys.sp_executesql`, `sys.tables`, `sys.types`, `sys.xml_indexes`.

### Source Select

Die einzelnen Featuregruppen werden bewusst getrennt gezählt. Der reduzierte Tabellenzweig lautet:

```sql
SELECT
      SUM(CASE WHEN [t].[is_memory_optimized] = 1 THEN 1 ELSE 0 END)
        AS [MemoryOptimizedTableCount]
    , SUM(CASE WHEN [t].[temporal_type] = 2 THEN 1 ELSE 0 END)
        AS [SystemVersionedTableCount]
    , SUM(CASE WHEN [t].[is_tracked_by_cdc] = 1 THEN 1 ELSE 0 END)
        AS [CdcTableCount]
FROM [sys].[tables] AS [t] WITH (NOLOCK)
WHERE [t].[is_ms_shipped] = 0;
```

**Wichtig für die Eigenlast:** Legen Sie Datenbank vor den jeweiligen Katalogzweigen fest. Full-Text, Broker, Change Tracking, External Objects, Encryption, CLR, XML und Vector haben eigene Quellen; die Procedure zählt sie isoliert und vereinigt erst die aggregierten Befunde.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Metadatenbestand je zugänglicher Datenbank; sie führt keine Nutzungs- oder Historienmessung durch.

### Bewertung und Gegenprobe

Berücksichtigen Sie zuerst Datenbankstatus und `DetectionStatus`, dann die codespezifische Bedeutung von `DetectedItemCount`, Konfigurationsstatus und `EvidenceLimit`. Führen Sie nur bei passender Entscheidungssituation das empfohlene Deep-Modul aus. Das Inventar dient Migrations-/Upgrade-/Betriebsplanung, nicht der automatischen Fehlerbewertung.

### Typische Fehlinterpretation

Objekt vorhanden bedeutet nicht aktiv genutzt, performant oder korrekt konfiguriert. Null Zeilen kann durch Metadata Visibility oder ausgeschlossene Datenbanken entstehen.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Featurebezogene Deep Analysis, Query-/Dependencyanalyse und Ownerreview. Für `VECTOR` prüft `USP_VectorIndexAnalysis` sichtbare Indizes und aktuelle Hintergrundwartung, ohne Vector-Werte zu lesen. Für `JSON` liefert `USP_ObjectInventory` die capability-adaptiven Index- und Pfadmetadaten, ohne JSON-Dokumentwerte oder Benutzertabellenzeilen zu lesen; die Inventur ist kein Health- oder DDL-Befund.

## Primärquellen

- [SQL-Server-Katalogsichten](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#2-monitorusp_specialfeatureinventory)

[SQL-Server-2025-JSON-Index-Vertrag](../../Architecture/SQL_Server_2025_JSON_Index_Inventory.md)

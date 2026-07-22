# [monitor].[USP_SpecialFeatureInventory]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Erkennt leichtgewichtig verwendete Spezialfeatures und empfiehlt passende Tiefenanalysen.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche besonderen oder versionsabhängigen Datenbankfeatures sind im sichtbaren Scope erkannt oder lediglich konfiguriert, und welches spezialisierte Modul gehört dazu?** Sie ist eine leichtgewichtige Landkarte vor Migration, Upgrade, Betriebsübergabe oder gezielter Tiefenanalyse. Sie bewertet ausdrücklich nicht, ob ein erkanntes Feature gesund, performant oder fachlich noch genutzt ist.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Metadatenbestand je zugänglicher Datenbank; keine Nutzungs-/Historienmessung. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Featureinhalte, Objektdefinitionen, externe Locations, Credentials, Broker-Nachrichten, CLR-Binaries oder tatsächliche Laufzeitnutzung. Die Zähler fassen je Feature unterschiedliche Katalogobjekte zusammen und sind deshalb weder datenbankübergreifende Nutzungsmetriken noch untereinander vergleichbare Größen. Eine Nullzählung gilt nur für sichtbare Metadaten im gewählten Scope.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SpecialFeatureInventory]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurErkannteFeatures = 1,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

CONSOLE liefert zuerst den Aufrufstatus, danach genau eine Datenbankstatuszeile je ausgewählter oder explizit angeforderter Datenbank und zuletzt die Featurezeilen. RAW enthält dieselbe Reihenfolge mit technischen Spalten. TABLE exportiert ausschließlich das registrierte Resultset `features`; Datenbankstatus und Aufrufstatus müssen bei automatisierter Verarbeitung über OUTPUT-Parameter beziehungsweise einen separaten Kontrolllauf gesichert werden. JSON enthält dagegen `meta`, `databaseStatus` und `features` gemeinsam. Immer zuerst `StatusCode`, `IsPartial`, Datenbankstatus und erst danach `DetectionStatus` lesen.

## Eine Zeile bedeutet

Im Feature-Resultset identifiziert `(DatabaseName, FeatureCode)` eine Zeile. `DetectedItemCount` kann je Code verschiedene Dinge addieren – etwa Tabellen plus Dateigruppen oder Kataloge plus Indizes – und darf daher nur innerhalb der dokumentierten Featuresemantik interpretiert werden. Im Datenbankstatus steht eine Zeile für den Auswertungsversuch einer Datenbank, nicht für ein Feature.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

`DETECTED` bedeutet mindestens einen sichtbaren Katalogmarker; `CONFIGURED_ONLY` belegt nur eine Konfiguration; `NOT_DETECTED_VISIBLE_SCOPE` ist keine globale Abwesenheitsgarantie. `UNAVAILABLE_VERSION` und `SOURCE_UNAVAILABLE` sind Evidenzlücken, keine Nullmessungen. Danach `ConfigurationState`, `RecommendedModuleStatus` und besonders `EvidenceLimit` lesen. `NOT_PLANNED` bedeutet nur, dass das Framework kein eigenes Deep-Dive-Modul anbietet.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Spezialfeatures benötigen eigene Backup-, Kapazitäts-, Betriebs- und Performancebetrachtung, die Standardanalysen nicht vollständig abdecken.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Erkennung ist Inventar, kein Fehlerbefund.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Für eine Migration von `ExampleDb` werden Temporal Tables und CLR erkannt. Das ist kein Defekt, aber ein belastbarer Hinweis, Retention/History mit `USP_TemporalAnalysis` zu prüfen und die CLR-Abhängigkeit separat durch den zuständigen Owner zu verifizieren, bevor die Zielplattform festgelegt wird.

**Ähnlich aussehender Gegenfall:** `EXTERNAL_SCRIPTS = CONFIGURED_ONLY` beweist keine ausgeführte externe Sprache. Die serverweite Option kann absichtlich bereitstehen, obwohl `ExampleDb` keine entsprechende Laufzeitabhängigkeit besitzt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Mit `@NurErkannteFeatures = 1` kann das Feature-Resultset korrekt leer sein, obwohl die Datenbank vollständig geprüft wurde. Ohne diesen Filter erscheinen nicht erkannte und versionsbedingt nicht verfügbare Codes ausdrücklich. Eine nicht auswertbare Datenbank steht im Datenbankstatus als Teilfehler; fehlende Metadata Visibility kann außerdem zu Nullzählungen führen, ohne einen technischen Fehler auszulösen.

Für `USP_SpecialFeatureInventory` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Eine explizit benannte `ExampleDatabase`; je unterstütztem Feature werden nur aggregierte Systemkatalogzählungen ausgeführt. Es gibt keine Benutzertabellen-, Payload-, Definitions- oder Runtime-History-Scans. |
| Teuerster Pfad | `@DatabaseNames = NULL` über alle sichtbaren Userdatenbanken, optional einschließlich Systemdatenbanken. Pro Datenbank laufen die festen Katalogzählungen für alle unterstützten Featurecodes; ein VOLL- oder Child-Deep-Pfad existiert nicht. |
| Haupttreiber | Zahl ausgewählter Datenbanken und Zahl sichtbarer Zeilen in Katalogen wie `sys.tables`, `sys.columns`, `sys.types`, `sys.assemblies` und den featureeigenen Katalogsichten. Die ausgegebenen Featurezeilen sind dagegen nahezu konstant je Datenbank. |
| Skalierung | Die Quellarbeit wächst ungefähr mit Datenbankanzahl und Kataloggröße. Dynamisches SQL wird einmal je Datenbank kompiliert/ausgeführt; die kleine Ergebnismenge und ihre Sortierung sind normalerweise nicht der dominante Anteil. |
| Ressourcen | Vor allem CPU und Katalogseiten im Buffer Pool; kleine temporäre Ergebnistabellen und wenig Ergebnistransfer. Keine XEL-Dateien, Query-Pläne, Benutzerdaten oder Featurepayloads werden materialisiert. |
| Begrenzungswirkung | `@DatabaseNames` beziehungsweise das Datenbankpattern begrenzen die Quellarbeit vor dem Datenbankcursor. `@NurErkannteFeatures` und `@MaxZeilen` wirken erst auf die bereits vollständig erzeugte Featureinventur und reduzieren daher primär Ausgabe/JSON, nicht die Katalogzählungen. |
| Locking und Nebenwirkungen | Rein lesende Katalogabfragen mit `NOLOCK`; keine Feature-, Daten- oder Konfigurationsänderung. Gleichzeitiges DDL kann einen zeitlich uneinheitlichen Katalogsnapshot erzeugen. |
| Schutzmechanismus | Der Kandidatenpfad verwendet absichtlich `@AnalysisClass = NULL`; es gibt kein Deep-Gate und `@HighImpactConfirmed` aktiviert hier keinen teureren Pfad. Schutz bieten der explizite Datenbankscope und `@LockTimeoutMs`, nicht die Bestätigung. |
| Sicherer Einsatz | Mit genau einer `ExampleDatabase` beginnen. Erst wenn deren Datenbankstatus vollständig ist und die Laufzeit zur Kataloggröße passt, den Scope datenbankweise erweitern. |
| Aussagegrenze | Katalogzählungen zeigen sichtbare Existenz oder Konfiguration, nicht Nutzung, Gesundheit oder Vollständigkeit. Outputfilter können Featurecodes ausblenden; Metadata Visibility kann trotz erfolgreichem Status zu Nullzählungen führen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche besonderen oder versionsabhängigen Datenbankfeatures und Objektarten sind im gewählten Scope konfiguriert?

### Technischer Hintergrund

Der Datenbankcursor führt einen festen Satz aggregierter Katalogzählungen für In-Memory OLTP, Temporal, Service Broker, Full-Text, Change Tracking, CDC, Verschlüsselung, CLR, External Tables/Runtimes, FILESTREAM/FileTable, Graph, Spatial, XML, native JSON-/Vector-Typen und benutzerdefinierte Typen aus. Er liest keine Objektdefinition oder Nutzdaten. Jede Featurezeile trägt ihre konkrete Quellliste und Aussagegrenze selbst.

### Datenkette

`sys.assemblies`, `sys.change_tracking_databases`, `sys.change_tracking_tables`, `sys.column_encryption_keys`, `sys.column_master_keys`, `sys.columns`, `sys.configurations`, `sys.databases`, `sys.external_data_sources`, `sys.external_languages`, `sys.external_libraries`, `sys.external_tables`, `sys.filegroups`, `sys.fulltext_catalogs`, `sys.fulltext_indexes`, `sys.objects`, `sys.service_queues`, `sys.services`, `sys.sp_executesql`, `sys.tables`, `sys.types`, `sys.xml_indexes`.

### Source Select

Die einzelnen Featurefamilien werden bewusst getrennt gezählt. Der reduzierte Tabellenzweig lautet:

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

**Wichtig für die Eigenlast:** Datenbank vor den jeweiligen Katalogzweigen festlegen. Full-Text, Broker, Change Tracking, External Objects, Encryption, CLR, XML und Vector haben eigene Quellen; die Procedure zählt sie isoliert und vereinigt erst die aggregierten Befunde.

### Zeit- und Scope-Modell

Aktueller Metadatenbestand je zugänglicher Datenbank; keine Nutzungs-/Historienmessung.

### Bewertung und Gegenprobe

Zuerst Datenbankstatus und `DetectionStatus`, dann die codespezifische Bedeutung von `DetectedItemCount`, Konfigurationsstatus und `EvidenceLimit` lesen. Nur bei passender Entscheidungssituation das empfohlene Deep-Modul ausführen. Das Inventar dient Migrations-/Upgrade-/Betriebsplanung, nicht der automatischen Fehlerbewertung.

### Typische Fehlinterpretation

Objekt vorhanden bedeutet nicht aktiv genutzt, performant oder korrekt konfiguriert. Null Zeilen kann durch Metadata Visibility oder ausgeschlossene Datenbanken entstehen.

### Folgeanalyse

Featurebezogene Deep Analysis, Query-/Dependencyanalyse und Ownerreview.

## Primärquellen

- [SQL-Server-Katalogsichten](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#2-monitorusp_specialfeatureinventory)

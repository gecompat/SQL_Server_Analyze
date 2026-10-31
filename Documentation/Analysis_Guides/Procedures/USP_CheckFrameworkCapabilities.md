# [monitor].[USP_CheckFrameworkCapabilities]

**Bereich:** Common<br>
**Zweck:** Prüft Version, Policy, Berechtigung, Abfragbarkeit und Featurestatus für Diagnosepfade.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Ist ein Analysepfad auf dieser konkreten Instanz nicht nur theoretisch unterstützt, sondern tatsächlich nutzbar?** Sie unterstützt die Entscheidung, ob der gewünschte Analysepfad sicher und eindeutig vorbereitet ist oder der Fachaufruf wegen Policy, Capability oder ungültigem Scope unterbleiben muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Performance- oder Verfügbarkeitsursache und keine Aussage über Daten außerhalb des aktuellen Execution-Kontexts. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CheckFrameworkCapabilities]
      @NurNichtVerfuegbar = 1,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Hilfe und Parameter

@Hilfe=1 gibt den SQL-seitigen Hilfetext aus. @Json wird zu Beginn zurückgesetzt. Ein TABLE-Ziel wird zuvor validiert; ein fehlerhafter Preflight kann vor der Hilfe abbrechen.

| Parameter | Typ, Default, Eingabeform und Wirkung |
|---|---|
| `@DatabaseNames` | nvarchar(max), Default NULL. NULL, leer oder nur äußere U+0020 bedeutet keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger Datenbanknamen: &#124; trennt außerhalb [..], ]] maskiert darin ]; äußere U+0020 je Element werden entfernt. Elemente müssen als einzelner SQL-Name via PARSENAME erkennbar und höchstens 128 Zeichen (sysname) sein; Rohsegment höchstens 4000 UTF-16-Codeeinheiten. Leere/fehlerhafte Elemente, ungültige Namen und Duplikate nach SQL_Latin1_General_CP1_CS_AS-Vergleich ergeben INVALID_PARAMETER. Groß-/Kleinschreibung wird unterschieden. Keine Anzahlgrenze im Helper. Nur bei einer nach dieser Normalisierung nichtleeren Liste ist ein nicht-NULL @DatabaseNamePattern unzulässig. Ausgelassen = unbeschränkte Auswahl sichtbarer, onlineer, zugänglicher Benutzerdatenbanken. |
| `@SystemdatenbankenEinbeziehen` | bit, Default 0. 0 schließt master, tempdb, model und msdb aus; 1 erlaubt sie. NULL ergibt INVALID_PARAMETER. Numerische Argumente konvertiert SQL Server vor Eintritt in bit: 0 bleibt 0, jeder Nichtnullwert wird 1. Ausgelassen = ausschließen. |
| `@DatabaseNamePattern` | nvarchar(4000), Default NULL. NULL bedeutet kein Pattern. Sonst äußere U+0020 mit LTRIM/RTRIM trimmen; Präfix regexi:, regex: oder like: wird ohne Beachtung der Großschreibung erkannt und entfernt, sonst LIKE. Rest nach Präfix wird nicht nochmals getrimmt. LIKE ist case-sensitiv, unterstützt %, _, [Zeichenklassen]; regex: ist case-sensitiv, regexi: case-insensitiv. Leere Eingabe oder leerer Rest ist ungültig. Jedes nicht-NULL Pattern ist mit einer nichtleeren @DatabaseNames-Liste exklusiv. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; sonst UNAVAILABLE_FEATURE. Ausgelassen = keine Einschränkung. |
| `@HighImpactConfirmed` | bit, Default 0. 1 übergibt die Bestätigung an den Datenbankkandidaten-Helper; 0 bestätigt nicht. NULL ergibt INVALID_PARAMETER. Numerische Werte werden vorab in bit konvertiert (Nichtnull wird 1). Diese Procedure übergibt Analyseklasse NULL an den Helper; daher wird hier kein klassenabhängiges High-Impact-Gate ausgelöst. Ausgelassen = 0. |
| `@AnalyseKlasse` | varchar(64), Default NULL. NULL oder ausgelassen wählt alle Features. Sonst Vergleich mit VW_AnalyseClassCatalog unter SQL_Latin1_General_CP1_CS_AS, ohne LTRIM/RTRIM; Groß-/Kleinschreibung zählt, SQL-Gleichheit kann nachgestellte U+0020 auffüllen. Leer oder nicht passend ergibt INVALID_PARAMETER. Begrenzt Featurekombinationen vor den Probes. Zulässige Klassen mit Bedeutung:<br>`STANDARD_CURRENT` = leichte aktuelle Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O<br>`EXTENDED_CURRENT` = gezielte aktuelle Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung<br>`PLAN_CACHE_CURRENT` = begrenzte Query-Stats- und Plan-Cache-Auswertung ohne vollständiges XML-Shredding<br>`SHOWPLAN_TARGETED` = gezielte Showplan-Extraktion/XML-Analyse für gefilterte Planhandles oder Query Hashes<br>`OBJECT_ANALYSIS_CURRENT` = gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse einer Datenbank<br>`EXTERNAL_RUNTIME_CURRENT` = lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer Runtimes, ohne Testausführung<br>`CLR_CURRENT` = lesende SQL-CLR-, Host-, AppDomain-, Task-, Request- und Speicheranalyse, ohne Assemblyausführung<br>`MISSING_INDEX_CURRENT` = flüchtige begrenzte Missing-Index-Hinweise, keine automatische DDL<br>`STATISTICS_TARGETED` = gezielte Statistik-Eigenschaften gefilterter Objekte<br>`COLUMNSTORE_CURRENT` = gezielte Columnstore-Rowgroups aus Katalogen, kein Segment-/Dictionary-Vollscan<br>`LOCKS_DEEP` = detaillierte sys.dm_tran_locks-Materialisierung für relevante Sessions<br>`LOG_VLF_DEEP` = datenbankübergreifende VLF-Auswertung via sys.dm_db_log_info<br>`PLAN_CACHE_DEEP` = breite oder vollständige Query-Stats- und Plan-Cache-Analyse<br>`SHOWPLAN_XML_DEEP` = XML-Analyse gecachter/aktueller Showplans mit Warnings, Spills, Objekten, Statistiken<br>`CATALOG_DEEP` = breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse<br>`PHYSICAL_STATS_DEEP` = explizite sys.dm_db_index_physical_stats-Auswertung in gewähltem Modus<br>`INDEX_OPERATIONAL_DEEP` = breite kumulative Index-Operational-Stats mit Lock/Latch/I/O/Page-Splits<br>`QUERY_STORE_CURRENT` = gezielte lesende Query-Store-Status-, Runtime-, Wait-, Plan-/Force-Auswertung, enges Zeit-/Zeilenlimit<br>`EXTENDED_EVENTS_CURRENT` = leichte Inventarisierung von Extended-Events-Definitionen und laufenden Sessions, ohne Targetdaten/Historie<br>`QUERY_STORE_DEEP` = breite Query-Store-Historie, Regressionen, Planwechsel und Waits<br>`CROSS_DATABASE_DEEP` = datenbankübergreifende Inventarisierung und Diagnose<br>`COLUMNSTORE_DEEP` = breite Columnstore-Analyse mit Rowgroups, Deleted Rows, Dictionaries und Segmenten<br>`EXTENDED_EVENTS_FORENSICS_DEEP` = optionale Analyse vorhandener XE-Sessions/Dateien, nie Primärquelle des Standardlaufs<br>`SERVER_HEALTH_CURRENT` = CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand der Instanz<br>`SERVER_CONFIGURATION_CURRENT` = lesende Serverkonfiguration, Trace Flags und Startup-Parameter<br>`SECURITY_CONFIGURATION_CURRENT` = lesende sicherheits- und dienstbezogene Betriebsparameter<br>`SQL_AGENT_CURRENT` = lesender SQL-Agent-Status, Jobs, Schedules und Historie aus msdb<br>`RESOURCE_GOVERNOR_CURRENT` = lesende Resource-Governor-Konfiguration und Laufzeit<br>`HA_DR_CURRENT` = begrenzte lesende AG-, Backup-, Log-Shipping-, Replication-, CDC- und Change-Tracking-Analyse<br>`ENTERPRISE_TOPOLOGY_DEEP` = vertiefte enterpriseweite HA/DR- und Replication-Topologie/Distribution<br>`DATA_PLATFORM_ADAPTER_CURRENT` = optionale Current-State-Anreicherung aus kundenspezifischen Data-Platform-/ETL-Logs mit isolierter Existenz-/Rechteprüfung |
| `@NurNichtVerfuegbar` | bit, Default 0. 0 gibt alle Capabilityzeilen aus; 1 nur IsUsable=0. NULL wirkt wegen des tatsächlichen SQL-Prädikats ebenfalls als Filter auf IsUsable=0. Evaluation und Summary bleiben vollständig; der Filter spart keine Probes. Ausgelassen = 0. |
| `@MitGruppenpruefung` | bit, Default 1. 1 prüft je Feature die Access-View; bei Deny oder Prüfungsfehler wird die Probe übersprungen. 0 oder NULL überspringt die Gruppenprüfung. Numerische Nichtnullwerte werden vorab zu bit 1 konvertiert. Ausgelassen = 1. |
| `@ResultSetArt` | varchar(16), Default 'CONSOLE'. Werte: CONSOLE übergibt Capabilities dem Console-Renderer; RAW liefert Meta, Capabilities, Summary und Warnings; TABLE exportiert ausschließlich Capabilities; NONE unterdrückt fachliche Resultsets. Äußere U+0020 werden mit LTRIM/RTRIM entfernt, danach UPPER. NULL/sonst ungültig ergibt INVALID_PARAMETER. Ausgelassen = CONSOLE. |
| `@ResultTablesJson` | nvarchar(max), Default NULL. NULL/ausgelassen bedeutet keine Zuordnung. Für TABLE ist ein gültiges JSON-Objekt mit genau dem nach U+0020-Trimmen case-sensitiven Schlüssel "capabilities" und einem nach U+0020-Trimmen nichtleeren JSON-String als Ziel erforderlich; Schlüssel und Ziele müssen eindeutig sein. Ziel: vorhandene leere lokale #temp-Tabelle, kein ##, LEN höchstens 116, nicht #Monitor* (case-insensitiv), genau eine beliebig typisierte Seed-Spalte. Der Preflight fügt vorübergehend eine bit-NULL-Prüfspalte hinzu und entfernt sie; daraus folgt kein bit/NULL-Zwang für die Seed-Spalte. U+0020 außen wird für Objektklammern getrimmt. Leeres/ungültiges JSON-Objekt, falsche Schlüssel/Werttypen, leere Namen, Duplikate, unzulässige Namen oder fehlendes/gefülltes/mehrspaltiges Ziel schlagen im Preflight fehl (THROW 51011). Außerhalb TABLE führt eine nichtleere Zuordnung zu THROW 51011. |
| `@JsonErzeugen` | bit, Default 0. 1 erzeugt @Json mit meta, capabilities, summary und warnings; 0 oder NULL erzeugt keines. Ausgelassen = 0. |
| `@Json` | nvarchar(max), Default NULL OUTPUT. Als OUTPUT-Variable binden, um JSON zu empfangen; ohne Erzeugung bleibt NULL. Der Eingangswert wird vor TABLE-Preflight und Hilfe auf NULL gesetzt. Ausgelassen ist möglich, dann kann kein Ergebnis empfangen werden. |
| `@PrintMeldungen` | bit, Default 1. 1 gibt Severity 10 bei Gesamtfehler oder mindestens einer nicht nutzbaren Capability aus. 0/NULL unterdrückt nur diese Meldung, nicht Resultsets oder JSON. Ausgelassen = 1. |
| `@Hilfe` | bit, Default 0. 1 gibt Hilfe aus und beendet vor Kandidatenauswahl und Capability-Probes; NULL/0 führt normal aus. @Json wird zuvor auf NULL gesetzt. TABLE-Preflight liegt vor der Hilfe und kann TempDB-Metadaten ändern oder abbrechen. @PrintMeldungen unterdrückt Hilfe nicht. |

~~~sql
-- Hilfe und Standard
EXEC [monitor].[USP_CheckFrameworkCapabilities] @Hilfe=1;
EXEC [monitor].[USP_CheckFrameworkCapabilities];
-- Datenbank-/Klassen-Scope und RAW
EXEC [monitor].[USP_CheckFrameworkCapabilities] @DatabaseNames=N'[ExampleDb]', @AnalyseKlasse='STANDARD_CURRENT', @ResultSetArt='RAW';
-- JSON unabhängig von fachlichen Resultsets
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_CheckFrameworkCapabilities] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json;
-- TABLE exportiert nur capabilities
CREATE TABLE #CheckFrameworkCapabilities_HelpExample (Seed bit NULL);
DECLARE @Map nvarchar(max)=N'{"capabilities":"#CheckFrameworkCapabilities_HelpExample"}';
EXEC [monitor].[USP_CheckFrameworkCapabilities] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
DROP TABLE #CheckFrameworkCapabilities_HelpExample;
~~~

CONSOLE übergibt capabilities an den Console-Renderer. RAW liefert Meta, Capabilities, Summary und Warnings als vier Resultsets. TABLE schreibt ausschließlich capabilities; NONE unterdrückt fachliche Resultsets. Meldungen und JSON sind unabhängig von diesen Modi. JSON enthält meta, capabilities, summary und warnings, kein Datenbankstatus-Array.

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert ausschließlich `capabilities`. RAW beginnt mit dem Meta-Resultset und endet mit Datenbank-Warnings; das Capabilityresultset enthält den Scope pro Feature. CONSOLE übergibt die Capabilitydaten an den Console-Renderer. JSON erhält den technischen Kontext in `meta`, `capabilities`, `summary` und `warnings`. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

RAW, CONSOLE, TABLE und das JSON-Array `capabilities` verwenden denselben nach der vollständigen Prüfung materialisierten Export mit 27 Feldern und 15 explizit collatierten Textspalten. `@NurNichtVerfuegbar=1` beschränkt ihn auf `IsUsable=0`; auch ein NULL-Wert dieses Parameters erhält das bestehende Prädikat und zeigt nur diese Zeilen. Die Zusammenfassung und der Gesamtstatus bewerten weiterhin alle geprüften Capabilities. JSON enthält `meta`, `capabilities`, `summary` und `warnings`; ein zusätzliches Datenbankstatus-Array wird nicht ausgegeben.

## Eine Zeile bedeutet

Eine Capability-Zeile bewertet ein Feature in einem Server- oder Datenbank-Scope. Dieselbe Fähigkeit kann deshalb je Datenbank unterschiedlich ausfallen.

## So lesen

Lesen Sie die Angaben in dieser Reihenfolge: `VersionSupported` → `GroupAccessAllowed` → `HasRequiredPermission` → `IsQueryable` → `IsFeatureEnabled` → `IsUsable`.

## Warum kann das problematisch sein?

`HasRequiredPermission=1`, aber `IsQueryable=0` zeigt, dass eine formale Permission nicht genügt. Datenbankstatus, Plattform, Replica-Rolle oder Laufzeitfehler begrenzen den Pfad.

## Wann ist es kein Problem?

Ein deaktiviertes Feature ist kein Serverfehler, wenn es nicht benötigt wird. Es erklärt lediglich, warum die zugehörige Analyse keine Daten liefern kann.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Query Store kann versionsseitig unterstützt und lesbar, aber deaktiviert sein. Ein leeres Query-Store-Resultset sagt dann nichts über die Queryqualität. Nur Scopes mit `IsUsable=1` fachlich auswerten.

**Ähnlich aussehender Gegenfall:** Ein deaktiviertes Feature ist kein Serverfehler, wenn es nicht benötigt wird. Es erklärt lediglich, warum die zugehörige Analyse keine Daten liefern kann. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Leere Capability-Ausgaben sind anhand von Meta, Summary und Warnings zu lesen. Ohne auswählbare Datenbankkandidaten fehlen Datenbank-Scoped Zeilen; SERVER-Scoped Features können dennoch geprüft und ausgegeben werden, wenn die Kandidatenauswahl insgesamt verfügbar ist. Ein Feature mit DATABASE-Scope kann ohne Kandidat keine Zeile liefern. Explizit angeforderte, nicht verfügbare Datenbanken werden in Warnings ausgewiesen.

`@NurNichtVerfuegbar=1` filtert die ausgegebenen Capabilityzeilen auf `IsUsable=0`; NULL bewirkt durch das SQL-Prädikat denselben Filter. Summary und Gesamtstatus basieren auf allen gesammelten Capabilityzeilen. Deshalb kann die Capabilityausgabe leer sein, während Summary-Zeilen vorhanden sind. Ein ungültiger Analyseklassen- oder Scopeparameter ist am Status in `meta` (RAW oder JSON) zu erkennen; Kandidatenwarnungen beschreiben die konkret nicht auswählbaren Datenbanken. CONSOLE rendert nur Capabilities und zeigt bei leerer Ausgabe „Keine fachlichen Ergebnisse“. JSON enthält `meta`, `summary` und `warnings` zusätzlich zum `capabilities`-Array.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM; deklarative Einordnung, keine Laufzeitmessung. |
| Standardpfad | Ohne Scope werden alle sichtbaren Online-Benutzerdatenbanken mit allen Katalogfeatures kombiniert. Für jede Serverfeaturezeile und jede `(Datenbank, Feature)`-Zeile führt der Code die anwendbaren Versions-, Gruppen-, Berechtigungs-, Probe- und Enablementprüfungen aus. |
| Teuerster Pfad | Viele Datenbanken × viele Datenbankfeatures mit `@MitGruppenpruefung = 1`; jede Kombination kann dynamische Permission-, Probe- und Enablementstatements ausführen. Die Templates des Katalogs werden tatsächlich ausgeführt; ihre Kosten und ihr Zugriffsumfang sind ohne Einzelfallprüfung nicht aus der Featuredefinition abzuleiten. Dadurch wird kein Fachmodul allein wegen seiner Katalogzeile aufgerufen. |
| Haupttreiber | Produkt aus Zahl der ausgewählten Datenbanken und DATABASE-Features plus konstante SERVER-Features. Dynamisches SQL wird je Kombination kompiliert/ausgeführt. |
| Skalierung | Annähernd linear mit den Featurekombinationen. Eine einzelne Analyseklasse reduziert den Featurekatalog früh; Datenbankscope reduziert DATABASE-Kombinationen. JSON/Sortierung sind nachgeordnet. |
| Ressourcen | Frameworkkatalogviews, Datenbankkandidaten, Login-/Permissionchecks und SQL-Templates per `sp_executesql`; Temp-Tabellen für Capability- und Warningzeilen. |
| Begrenzungswirkung | `@DatabaseNames` und `@AnalyseKlasse` begrenzen tatsächliche Probeanzahl. `@NurNichtVerfuegbar` filtert erst die Ausgabe und spart keine Probe-/Enablementaufrufe.  |
| Locking und Nebenwirkungen | Die Procedure vergibt keine Rechte. Probe- und Enablementtemplates werden ausgeführt; ein Probeerfolg ist keine Aussage über Kosten, Vollständigkeit späterer Fachdaten oder externe Gesundheit. Datenbankstatus/Berechtigung kann sich während der Schleife ändern, daher sind Capabilityzeilen kein atomarer Snapshot. |
| Schutzmechanismus | Der Aufruf an `USP_PrepareDatabaseCandidates` verwendet bewusst `@AnalysisClass = NULL`; damit löst `@HighImpactConfirmed` hier kein Deep-Gate aus. Die ausgeführten Probe- und Enablementtemplates sind anhand ihrer konkreten SQL-Definitionen zu beurteilen. |
| Sicherer Einsatz | Eine `ExampleDatabase` und eine konkrete Analyseklasse prüfen; die vollständige Matrix nur für Inventar-/Upgradeaudits ausführen. `@NurNichtVerfuegbar` dient Lesbarkeit, nicht Lastreduktion. |
| Aussagegrenze | `IsUsable` bezeichnet das Ergebnis der katalogbasierten Prüfungen im aktuellen Kontext. Es garantiert weder Berechtigung auf jede spätere Fachzeile noch geringe Kosten, Datenvollständigkeit oder erfolgreiche Ausführung des eigentlichen Analysemoduls. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist ein Analysepfad auf dieser konkreten Instanz nicht nur theoretisch unterstützt, sondern tatsächlich nutzbar?

### Technischer Hintergrund

Version, Edition, Featurekonfiguration und formale Permission sind verschiedene Ebenen. Die Procedure führt capability-orientierte Prüfungen aus und kann geschützte Testabfragen dynamisch ausführen. Dadurch wird zwischen `supported`, `enabled`, `permitted`, `queryable` und `usable` unterschieden.

### Datenkette

`sys.sp_executesql`.

### Source Select

Die Capability-Prüfung startet mit dem deklarativen Featurekatalog; datenbankbezogene Einträge werden erst danach mit den ausgewählten Datenbanken vervielfacht:

```sql
SELECT
      [f].[FeatureCode]
    , [f].[ScopeType]
    , [f].[AnalysisClass]
    , [f].[MinimumMajorVersion]
    , [f].[ProbeSqlTemplate]
FROM [monitor].[VW_FrameworkFeatureCatalog] AS [f]
WHERE [f].[AnalysisClass] = 'STANDARD_CURRENT'
  AND [f].[MinimumMajorVersion]
      <= TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion'));
```

**Wichtig für die Eigenlast:** Analyseklasse und Datenbankscope vor dem Ausführen der Probe-Statements einschränken. Die Probes führen die im Katalog hinterlegten Templates aus. `TOP (0)` an einzelnen Stellen ist kein empirischer Kosten- oder Sicherheitstest; die Templates können je Datenbank wiederholt werden.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Umgebungszustand; Ergebnisse können sich nach Konfigurationsänderung, Failover, Datenbankstatuswechsel oder Berechtigungsänderung ändern.

### Bewertung und Gegenprobe

Berücksichtigen Sie die Prüfkette in der dokumentierten Reihenfolge. `HasRequiredPermission=1` bei `IsQueryable=0` weist auf eine zusätzliche Laufzeitgrenze hin. `IsFeatureEnabled=0` kann bei einem bewusst ungenutzten Feature normal sein.

### Typische Fehlinterpretation

Capability ist kein Nachweis, dass relevante Daten vorhanden sind. Query Store kann nutzbar, aber leer sein; XE kann abfragbar, aber ohne passende Session sein.

### Folgeanalyse

Starten Sie nur Fachmodule, deren benötigte Quelle nutzbar ist. Prüfen Sie bei einem Partialstatus die jeweilige Datenbank oder Quelle gezielt.

## Primärquellen

- [sys.sp_executesql](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-executesql-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../01_Common.md#3-monitorusp_checkframeworkcapabilities)

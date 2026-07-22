# [monitor].[USP_ServerFeatureCapabilities]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Zeigt versions-, editions-, plattform- und datenbankbezogene Featurefähigkeiten.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche versions-, plattform- und datenbankabhängigen Diagnosepfade kann das Framework auf dieser Instanz verwenden, und welcher Fallback gilt?** Sie prüft Capability-Metadaten für Berechtigungsnamen, ZSTD, Resource Governor, Linux-Host-DMVs, Optimized Locking, Query-Store-Replikainformation und optionale Vector-Indizes. Eine Capabilityzeile ist eine Routingentscheidung für Diagnosecode, kein Gesundheitsbefund.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Instanz-/Datenbankzustand. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem tatsächliche Feature-Nutzung, Lizenzberechtigung außerhalb der ausgewiesenen Produktmetadaten, Funktionsfähigkeit eines End-to-End-Szenarios oder zukünftige Verfügbarkeit nach Upgrade/CU. `AVAILABLE` bedeutet, dass der implementierte Probe-Pfad die Capability als vorhanden einstuft; es ersetzt keine Berechtigungsprobe im späteren Aufruf und keine fachliche Validierung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerFeatureCapabilities]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

RAW und CONSOLE liefern Aufrufstatus, serverweite Capabilities, datenbankbezogene Capabilities, optional Spezialindizes und zuletzt Warnungen. Die Datenbankresultsets sind nicht atomar zum Serverprobe; Statuswechsel während des Datenbankcursors sind möglich. TABLE exportiert ausschließlich das registrierte Resultset `capabilities` und enthält damit weder datenbankbezogene Features noch Spezialindizes. JSON ist für die vollständige maschinelle Hülle geeigneter und enthält `meta`, `capabilities`, `databaseFeatures`, `specialIndexes` und `warnings`.

## Eine Zeile bedeutet

Im Serverresultset identifiziert `(ScopeName, FeatureName)` eine Capability. Im Datenbankresultset gilt `(DatabaseName, FeatureName)`, im Spezialindexresultset eine konkrete Indexidentität aus Datenbank, Schema, Objekt und Index. Eine Warnungszeile steht für einen fehlgeschlagenen Datenbank- oder Selektionspfad; diese Granularitäten dürfen nicht miteinander gezählt oder gejoint werden, ohne den Resultsettyp zu erhalten.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst Gesamtstatus und Warnungen lesen. Danach `AvailabilityStatus`, `LogicPath`, `SourceObject`, `RequiredPermission` und `Detail` als Einheit interpretieren: `UNAVAILABLE_VERSION` oder `UNAVAILABLE_PLATFORM` kann einen dokumentierten Fallback besitzen. Datenbank-Compatibility und `FeatureValue` sind separate Evidenz; die bloße Existenz einer Systemview beweist weder gefüllte Daten noch Zugriffsrecht.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein Codepfad kann auf der Hauptversion existieren, aber wegen Plattform, Edition, Build oder Compatibility nicht nutzbar sein.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein nicht unterstütztes Feature ist kein Fehler, wenn es nicht benötigt wird.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** `ExampleDb` soll einen 2025-spezifischen Diagnosepfad verwenden, die Capability meldet jedoch `UNAVAILABLE_VERSION` oder einen nicht passenden Fallback. Der Aufrufer muss beim kompatiblen Pfad bleiben und darf die neuere Systemspalte nicht statisch referenzieren.

**Ähnlich aussehender Gegenfall:** Eine Linux-spezifische Host-DMV ist auf Windows erwartungsgemäß `UNAVAILABLE_PLATFORM`; der allgemeine OS-/SQL-Prozess-Fallback kann vollständig ausreichen. Das ist keine degradierte Servergesundheit.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Eine leere Spezialindexmenge kann korrekt bedeuten, dass die Sicht verfügbar ist, aber im gewählten Scope kein entsprechender Index existiert. Fehlt eine explizit angeforderte Datenbank oder scheitert ihr dynamischer Probe, steht dies im Warnungsresultset und `IsPartial` ist maßgeblich. Ein fehlendes datenbankbezogenes Resultset darf nicht aus einem vorhandenen Server-Capability-Resultset als Erfolg abgeleitet werden.

Für `USP_ServerFeatureCapabilities` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Eine `ExampleDatabase` mit kleinen server- und datenbankweiten Katalogprobes; standardmäßig werden Plattform, Query-Store-Replikasicht und verfügbare Spezialindexmetadaten geprüft. Es werden keine Benutzerdaten oder Historien gelesen. |
| Teuerster Pfad | Alle sichtbaren Datenbanken mit `@MitSpezialindizes = 1`, `@MitQueryStoreReplicas = 1` und Plattformdetails. Falls `sys.vector_indexes` vorhanden ist, werden alle sichtbaren Vector-Indexzeilen im Scope materialisiert. |
| Haupttreiber | Zahl ausgewählter Datenbanken und – auf unterstützten Builds – Zahl sichtbarer Vector-Indizes. Die übrigen Capabilityprobes lesen kleine Katalogmengen beziehungsweise zählen Query-Store-Replikagruppen. |
| Skalierung | Der dynamische Probe wird einmal je Datenbank kompiliert/ausgeführt. Laufzeit wächst annähernd mit der Datenbankanzahl; Spezialindexmaterialisierung und Ergebnistransfer wachsen zusätzlich mit der Zahl entsprechender Indizes. |
| Ressourcen | Vor allem CPU und Katalogseiten, geringe TempDB-/Arbeitstabellenlast sowie dynamischer Compileaufwand je Datenbank. Kein Showplan-, XEL-, Payload- oder Benutzertabellenscan. |
| Begrenzungswirkung | Datenbankliste/-pattern begrenzen den Cursor früh. `@MaxZeilen` wird erst beim Ausgeben jedes fachlichen Resultsets angewandt; es begrenzt weder die Zahl geprüfter Datenbanken noch die zuvor materialisierten Spezialindizes. |
| Locking und Nebenwirkungen | Rein lesende `NOLOCK`-/Katalogprobes; keine Konfigurationsänderung. Parallel laufendes DDL, Upgrade oder Failover kann zwischen Server- und Datenbankprobe ein zeitlich uneinheitliches Ergebnis erzeugen. |
| Schutzmechanismus | Der Kandidatenpfad nutzt `OBJECT_ANALYSIS_CURRENT`, dessen Katalogeintrag keine High-Impact-Bestätigung verlangt. `@HighImpactConfirmed` schaltet in dieser Procedure keinen zusätzlichen Deep-Pfad frei; der explizite Datenbankscope ist der wirksame Schutz. |
| Sicherer Einsatz | Eine `ExampleDatabase`; bei reiner Serverroutingfrage optionale Spezialindizes und Query-Store-Replikaprobe deaktivieren. Erst nach vollständigem Status auf weitere Datenbanken erweitern. |
| Aussagegrenze | Capability und Systemobjektexistenz sind kein Nutzungs-, Berechtigungs- oder Funktionstest. Ein Outputlimit kann relevante spätere Zeilen verbergen, obwohl alle Quellen bereits gelesen wurden. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche versions-/editionsabhängigen Frameworkpfade sind auf dieser Instanz technisch möglich und lesbar?

### Technischer Hintergrund

Die Procedure verbindet Product Major Version, Edition/Engine Edition, Compatibility und die Existenz versionsabhängiger Systemobjekte/Spalten. Capability-Probes vermeiden Compilefehler durch statische Referenzen auf nicht vorhandene Quellen und führen optionale Abfragen geschützt dynamisch aus.

### Datenkette

`master.sys.all_objects`, `sys.databases`, `sys.dm_os_host_info`, `sys.objects`, `sys.query_store_replicas`, `sys.resource_governor_configuration`, `sys.schemas`, `sys.sp_executesql`, `sys.vector_indexes`, `sys.views`.

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

**Wichtig für die Eigenlast:** Datenbankscope vor Katalog-Existenz- und Probezugriffen festlegen. Die Spalte `is_optimized_locking_on` wird nur im SQL-Server-2025-Pfad kompiliert; versionsspezifische Sichten wie Vector Indexes und Query Store Replicas werden nur nach Versions- und Objektprüfung gelesen.

### Zeit- und Scope-Modell

Aktueller Instanz-/Datenbankzustand. Upgrade, Compatibilitywechsel, Failover oder Permissionänderung können Ergebnis ändern.

### Bewertung und Gegenprobe

`AvailabilityStatus`, Objekt-/Viewexistenz, Plattform, Datenbank-Compatibility, benötigte Berechtigung und Fallbackpfad getrennt lesen. Die Procedure besitzt kein generisches `Usable`-Bit; die konkrete Nutzbarkeit ergibt sich erst aus der Capabilityzeile plus Berechtigungs- und Aufrufkontext.

### Typische Fehlinterpretation

Version allein reicht nicht: SQL Server 2025 mit niedriger Compatibility kann Features nicht im Querykontext aktivieren. Objekt vorhanden beweist keine nutzbare Datenlage.

### Folgeanalyse

Den betroffenen Diagnosepfad nur bei passendem `AvailabilityStatus`, Scope und Berechtigung verwenden; andernfalls den ausgewiesenen Fallback nutzen und Warnungen erhalten.

## Primärquellen

- [SQL-Server-Katalogsichten](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#1-monitorusp_serverfeaturecapabilities)

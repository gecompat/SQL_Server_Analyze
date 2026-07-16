# Anforderungen und verbindliche Entscheidungen

## 1. Ziel

In der Datenbank `DeineDatenbank` wird im Schema `monitor` ein umfassendes SQL-Server-Monitoring- und Diagnoseframework in reinem T-SQL erstellt.

Das Framework soll sowohl eine ressourcenschonende Standarddiagnose als auch vollständige, bewusst aktivierte Deep- und Forensik-Analysen anbieten. Es darf keine technisch sinnvolle Analyseklasse grundsätzlich ausschließen.

## 2. DDL- und Objektkonventionen

- DDL verwendet `CREATE OR ALTER`, soweit SQL Server dies für den jeweiligen Objekttyp unterstützt.
- Wo `CREATE OR ALTER` nicht verfügbar ist, wird eine wiederholbar ausführbare, idempotente Alternative eingesetzt.
- Jedes Objekt enthält einen ausführlichen Header mit mindestens:
  - Zweck und Funktionsbeschreibung,
  - Voraussetzungen und Berechtigungen,
  - Datenquellen,
  - Parameterbeschreibung,
  - Resultsets,
  - Nebenwirkungen und mögliche Eigenlast,
  - Versions- und Änderungshinweise,
  - Aufrufbeispiele.
- Jede öffentliche Stored Procedure enthält `@Hilfe bit = 0`.
- Bei `@Hilfe = 1` gibt die Procedure über `PRINT` alle Parameter, gültigen Werte, Aufrufvarianten und kurze Beschreibungen aus und beendet die fachliche Verarbeitung.

## 3. Performance- und Verfügbarkeitsprinzipien

- Monitoring darf das zu untersuchende System nicht unnötig belasten.
- Primär werden gezielte `SELECT`-Abfragen auf DMVs, DMFs, Katalog- und Systemtabellen verwendet.
- Teure Datenquellen werden nach Möglichkeit nur einmal gelesen und für weitere Auswertung begrenzt materialisiert.
- Filter und Top-N-Begrenzungen werden vor teuren XML-, Plan-, Katalog- oder Physical-Stats-Auswertungen angewandt.
- Breite Plan-Cache-, Query-Store-, Objekt- und Katalogscans sind ausdrücklich vorgesehen, aber nicht Bestandteil der gewöhnlichen Standardauswertung.
- Teure Analysen erhalten explizite Aktivierungsparameter, Grenzwerte, Laufzeitbudgets und Abbruchmöglichkeiten.
- Metadatenauflösung darf die Diagnose nicht blockieren. Direkte Aufrufe wie `OBJECT_NAME`, `OBJECT_ID`, `SCHEMA_NAME` oder vergleichbare Hilfsfunktionen werden nicht unkritisch in breiten oder hochfrequenten Pfaden verwendet, weil Metadatenzugriffe blockieren können.
- Wo fachlich vertretbar, werden Systemtabellen gezielt und mit geringer Blockierungswahrscheinlichkeit gelesen. Eine teilweise fehlende Objektauflösung ist besser als der Ausfall der gesamten Diagnose.
- Fehler einzelner optionaler Module, fehlende Rechte oder nicht verfügbare Features dürfen den restlichen Analyseablauf nicht abbrechen.
- `NOLOCK` beziehungsweise `READ UNCOMMITTED` ist kein pauschaler Standard für alle Datenquellen, sondern eine bewusst dokumentierte Ausnahme für geeignete Metadaten-/Diagnosepfade. Inkonsistente oder fehlende Ergebnisse müssen als solche erkennbar bleiben.

## 4. Analyseebenen

### STANDARD

Leichtgewichtige Live-Sicht auf Sessions, Requests, Blocking, Waits, offene Transaktionen, Memory Grants, Scheduler, CPU, TempDB, I/O und Transaktionslog.

### ERWEITERT

Gezielte Ergänzung um relevante Pläne, Query Store, Objekt-, Index-, Statistik-, Partitionierungs-, Columnstore- und Konfigurationsinformationen.

### DEEP

Opt-in ausführbare breite Analysen, unter anderem:

- vollständiger oder großer Plan-Cache-Scan,
- Showplan-XML-Analyse,
- Warnings, Spills, Missing Indexes, implicit conversions und plan-affecting converts,
- verwendete Objekte und Statistiken,
- Scans, Seeks, Join-Typen, Parallelism, Cardinality- und Row-Estimate-Abweichungen,
- Memory Grants, Parameter-Sensitivität und Planvarianten,
- vollständige Katalog-, Index-, Statistik-, Partitionierungs- und Columnstore-Analysen,
- datenbankübergreifende Bestandsaufnahme,
- breite Query-Store-Auswertung und Regressionsanalyse.

### FORENSIK

Historische und beweissichernde Analysen aus eigenen Snapshots, Query Store, vorhandenen Extended Events, `system_health`, Deadlock-Graphen, Blocking-Verläufen, Planwechseln sowie optionalen DWH-/ETL-Protokolldaten.

## 5. Datenquellen und Priorität

### Primär

- Live-DMVs und DMFs,
- System- und Katalogtabellen,
- aktuelle Plan-Cache-Daten,
- eigene persistente Snapshot-Tabellen,
- Query Store, sofern aktiviert und berechtigt.

### Extended Events

- Extended Events werden vollständig berücksichtigt, sind aber **nicht** die primäre Standardmethode.
- Standardmäßig werden alternative T-SQL-`SELECT`-Methoden verwendet.
- Vorhandene Sessions wie `system_health` können optional gelesen werden.
- Fehlende XE-Berechtigungen sind ein erwarteter Zustand und kein Gesamtfehler.
- Das Anlegen, Ändern, Starten oder Stoppen eigener XE-Sessions erfolgt ausschließlich über separate, explizit aufgerufene Administrationsmodule.
- Historische Deadlock-Graphen lassen sich ohne vorherige Erfassung nicht vollständig aus aktuellen DMVs rekonstruieren; das Framework muss diese Grenze klar ausweisen.

## 6. Fachlicher Umfang

Mindestens vorzusehen sind:

- Sessions, Requests, Connections und aktive Statements,
- Blocking Chains, Locks, Latches, Deadlocks und offene Transaktionen,
- Wait Statistics, waiting tasks, Scheduler, Worker Threads und CPU Pressure,
- Memory Clerks, Buffer Pool, Plan Cache, Memory Grants und Resource Semaphore,
- TempDB Space, Task-/Session-Verbrauch, Version Store und ADR/PVS,
- Daten-/Logdateien, I/O-Latenz, Dateiwachstum und Speicherplatz,
- Transaktionslog, VLFs, Log-Reuse-Wait und Logverbrauch,
- Plan Cache und vollständige Showplan-Analyse,
- Query Store einschließlich Runtime-, Wait- und Planhistorie,
- Index Usage, Missing Indexes, Operational und Physical Stats,
- Statistiken, Änderungszähler und Aktualitätsbewertung,
- Partitionen, Compression und Allocation,
- Columnstore Rowgroups, deleted rows, Delta Stores und Tuple Mover,
- Datenbank- und Instanzkonfiguration,
- Always On, Replikation und weitere verfügbare Enterprise-/HA-Komponenten,
- Data-Platform-/ETL-/SSIS-Integration und Laufzeitvergleich, sofern entsprechende Frameworkdaten vorhanden sind,
- persistente Snapshots, Deltas, Baselines und Retention,
- Berechtigungs- und Feature-Erkennung.

## 7. Filter und Bedienbarkeit

Vorzusehen sind unter anderem Filter für:

- eigene Sessions (`login_name`/`SUSER_SNAME()`-Bezug),
- Ausblenden von System-Sessions,
- einzelne Session, Request, Login, Host, Application, Database und Objekt,
- Zeitfenster und Mindestlaufzeiten,
- CPU, Reads, Writes, Waits, Memory, Row Count und Execution Count,
- Plan-/Query-Hash und Query Store IDs,
- Standard-/Erweitert-/Deep-/Forensik-Modus.

## 8. Lieferung

- Jede Lieferung erfolgt als ZIP.
- Im ZIP liegt ausschließlich der abgegrenzte Projektordner `20260714_StartNewChatProjektProject`.
- Dieser Ordner muss eigenständig und vollständig sein und alle Informationen enthalten, die für eine spätere Fortsetzung erforderlich sind.
- Gelöschte Dateien sind mit vollständigem relativem Pfad zu nennen.
- Jede Lieferung enthält eine Commit Message.
- Die Commit Message ist exakt einzeilig und enthält keine Zeilenumbrüche.

## 9. Herkunft dieser Konsolidierung

Die Anforderungen basieren auf:

- dem aktuellen Benutzerauftrag und den nachfolgenden Präzisierungen,
- den vorhandenen Pflichtenheften und technischen Spezifikationen im Ausgangsmaterial,
- den vorhandenen SQL-Versuchen,
- dem monolithischen Skript `historische Analysequelle`,
- der Architektur- und Umsetzungsplanung V4.

## 10. Verbindliche Präzisierungen vom 14. Juli 2026 – Phase 0

- Initial werden ausschließlich Abfrageobjekte für den aktuellen Zustand bereitgestellt, überwiegend Stored Procedures.
- Standardaufrufe speichern keine Ergebnisse und besitzen keine Retention.
- Persistenz wird nur für einen späteren, ausdrücklich aktivierten separaten oder parametrisierten Aufruf vorgesehen.
- Das spätere Snapshot-Intervall beträgt 30 Sekunden; ein Standardintervall darf höchstens eine Minute betragen.
- SQL-Agent-Skripte werden später als separates idempotentes DDL-Paket erstellt.
- Das Framework darf keinerlei Rechte, Rollenmitgliedschaften, Logins oder Benutzer vergeben oder verändern. Es dokumentiert lediglich benötigte effektive Rechte.
- Fehlende Berechtigungen, nicht unterstützte Serverversionen, nicht vorhandene Systemobjekte/Spalten oder deaktivierte Features dürfen nur das betroffene Teilmodul deaktivieren. Sinnvolle restliche Resultsets müssen weiter geliefert werden.
- Nichtsystemische Objekte, insbesondere DWH-/ETL-Loggingobjekte, sind ausschließlich optional und dynamisch zu adressieren. Fehlende Objekte oder Rechte erzeugen einen Status/eine Warnung, aber keinen Abbruch des Framework-Cores.
- Warnungen und abgefangene Fehlermeldungen dürfen ausgegeben werden; zusätzlich ist ein strukturierter Modulstatus bereitzustellen.
- Ressourcenintensive Analysen dürfen nur nach erfolgreicher Prüfung einer später konfigurierbaren Menge von 1 bis n AD-Gruppen ausgeführt werden. Die Prüfung muss vor dem ersten teuren Zugriff erfolgen.
- Empfohlene Gruppenprüfung ist ein set-basierter Abgleich konfigurierter Windows-Gruppen gegen `sys.login_token`. SQL-Logins werden für gruppengeschützte Analysen standardmäßig abgewiesen.
- Module Signing ist nicht Teil des Frameworks, weil dessen betrieblicher Nutzen die Anlage von Zertifikatsprinzipalen und Rechtevergaben voraussetzt. Das Framework selbst vergibt keine Rechte.



## Ergänzung Phase 1A – Festlegungen vom 2026-07-14

- Minimale unterstützte Version: **SQL Server 2019**.
- Namenskonventionen: `USP_CamelCase`, `TVF_CamelCase`, `SVF_CamelCase`, `VW_CamelCase`.
- Ressourcenintensive Analyseklassen werden über 1 bis n AD-Gruppen geschützt.
- `sysadmin` besitzt einen Bypass.
- Gruppenprüfung: primär `sys.login_token`, zusätzlich `IS_MEMBER` als Fallback.
- Solange keine aktive Gruppendefinition vorhanden ist, sind alle Analyseklassen erlaubt. Sobald aktive Definitionen vorhanden sind, dürfen gruppengeschützte Analysen nur passende Gruppen oder sysadmin ausführen.
- Das Framework vergibt unter keinen Umständen Rechte. Benötigte Rechte werden nur dokumentiert und geprüft.
- Eine öffentliche Hilfs-USP muss je Monitoring-Funktion ausgeben, ob sie technisch abfragbar, eingeschränkt abfragbar, deaktiviert oder nicht abfragbar ist.
- Der initiale Kern ist vollständig zustandslos und bildet nur das Jetzt ab. Persistenz ist ausschließlich ein späterer, explizit parametrisierter Zusatz.
- Für einen späteren Snapshot-Ausbau gilt 30 Sekunden als typische Frequenz und 60 Sekunden als empfohlene maximale Standardfrequenz.
- SQL-Agent-DDLs sind ein späteres separates Framework-Paket.


## Festlegungen Phase 1B (2026-07-14)

- Phase 1B ist ausschließlich zustandsloser Current-State-Core.
- Keine Aufbewahrung; Sampling nur explizit innerhalb eines Aufrufs.
- Öffentliche Namen: `USP_CamelCase`, `TVF_CamelCase`, `SVF_CamelCase`, `VW_CamelCase`.
- Ressourcenschutz: `LOCKS_DEEP` und `LOG_VLF_DEEP` sind gruppengeschützt.
- Fehlende Rechte, Versionen, Datenbanken und optionale Teilquellen erzeugen Warnungen/Status, aber keinen Abbruch anderer Module.
- SQL-Agent und persistente Snapshots folgen in einem späteren separaten Teil.


## Festlegungen Phase 2 (2026-07-14)

- Einzel-Datenbank-Analysen verwenden standardmäßig den gezielten Modus; breite Katalogläufe erfordern eine ausdrückliche Vollanalyse.
- Cross-Database-Analysen prüfen `CROSS_DATABASE_DEEP`, vollständige Katalogläufe `CATALOG_DEEP`.
- `sys.dm_db_index_physical_stats` wird nur explizit und nach Prüfung von `PHYSICAL_STATS_DEEP` aufgerufen; `LIMITED` ist der Defaultmodus.
- Breite `sys.dm_db_index_operational_stats`-Auswertungen prüfen `INDEX_OPERATIONAL_DEEP`. Eine fehlgeschlagene Objektauflösung darf niemals als unbeabsichtigter NULL-Wildcard-Aufruf an die DMF weitergegeben werden.
- Index Usage für memory-optimized Tabellen wird getrennt über `sys.dm_db_xtp_index_stats` ausgewertet. Spatial-Indizes werden nicht fälschlich als ungenutzt klassifiziert.
- Columnstore-Basisdaten und die optionalen Physical-/Segment-/Dictionary-Quellen werden separat und fehlertolerant verarbeitet. Detailquellen prüfen `COLUMNSTORE_DEEP`.
- Missing-Index-DDL ist ausschließlich ein gekennzeichneter Prüfvorschlag und wird niemals ausgeführt.
- Sämtliche Phase-2-Objekte bleiben zustandslos; keine Wartung, Persistenz, Jobanlage oder Rechtevergabe.

## Festlegungen Phase 5

- Extended Events sind eine optionale Zusatzquelle und keine Voraussetzung für Standardanalysen.
- Es werden nur bereits vorhandene Sessions, Targets, Eventfiles und Events gelesen.
- Das Framework erstellt, startet, stoppt, ändert oder löscht keine XE-Session.
- `sys.dm_xe_session_targets` darf wegen des möglichen Target-Flushs nur nach expliziter Bestätigung gelesen werden.
- `system_health` darf für vorhandene Deadlockdaten gelesen, aber nicht verändert werden.
- `blocked process threshold (s)` und andere Serveroptionen werden ausschließlich angezeigt, niemals geändert.

## Verbindliche API-Konsolidierung vom 2026-07-15

- Das Framework wird noch von niemandem verwendet. Daher werden inkonsistente öffentliche Parameter ohne Legacy-Alias und ohne Übergangsfrist bereinigt.
- Gleiche Funktionalität verwendet frameworkweit denselben Parameternamen, dieselbe exakte Schreibweise, denselben Datentyp und dieselbe Grundsemantik.
- Die Anzahl zurückgegebener Zeilen wird ausschließlich mit `@MaxZeilen int` gesteuert. Positive Werte begrenzen, `NULL` oder `0` bedeuten unbegrenzt, negative Werte sind ungültig.
- Mehrere Detail-Resultsets derselben Procedure verwenden denselben öffentlichen `@MaxZeilen`-Parameter.
- Die Anzahl zu analysierender Pläne beziehungsweise anderer ressourcenintensiver Quellobjekte wird getrennt mit `@MaxAnalyseobjekte int` gesteuert.
- Cross-Database-Scope verwendet `@DatabaseNames nvarchar(max)`, `@MaxDatenbanken int = 16` und `@SystemdatenbankenEinbeziehen bit = 0`. `NULL` bedeutet alle zulässigen Datenbanken; `N''` die aktuelle Datenbank.
- Patternfilter verwenden `@DatenbankNameLike` beziehungsweise `@TextLike`.
- Zeitintervalle verwenden `@VonUtc` und `@BisUtc` als `datetime2(7)`; parallele Vergleichsfenster verwenden fachliche Präfixe.
- Sortierparameter heißen `@Sortierung varchar(32)`.
- `@MaxSqlTextZeichen` verwendet frameworkweit dieselbe Semantik: positiver Wert kürzt die Darstellung, `NULL` oder `0` liefert den vollständigen Text, negative Werte sind ungültig.
- Parameterprüfung und Deep-Berechtigungsprüfung bleiben getrennt. Die technische Vollausgabe darf nicht durch einen unveränderbaren Höchstwert ausgeschlossen werden.

## Case-Sensitive-Zielsystem und Identifier-Vertrag

- **Dokumentiert:** Server, `tempdb` und `DeineDatenbank` verwenden `SQL_Latin1_General_CP1_CS_AS`.
- Sämtliche SQL-Identifier sind exakt case-sensitiv zu behandeln.
- Gleiche Funktionalität verwendet nicht nur denselben Namen, sondern dieselbe Groß-/Kleinschreibung.
- Reine Case-Varianten sind als Fehler zu behandeln und dürfen weder als Alias noch als Legacy-Kompatibilität bestehen bleiben.
- Preflight, statische Repository-Prüfung und installierter API-Katalogtest müssen diese Anforderung prüfen.


## Entscheidung 2026-07-15: Listen, Patterns, Ausgabe und Memory Grants

- `@AlleDatenbanken` entfällt; Datenbankscope erfolgt über `@DatabaseNames`.
- Listen sind bracket-aware und Pipe-getrennt; Patternfilter sind getrennte Parameter.
- Steuerwerte sind case-insensitiv, SQL-Namen bleiben case-sensitiv.
- Jede öffentliche Analyse unterstützt RAW/CONSOLE/NONE und optional JSON.
- Query Store unterscheidet Quelldatenbanken und referenzierte Datenbanken.
- Memory Grants enthalten Resource-Governor- und Semaphore-Grenzen sowie Prozentkennzahlen.

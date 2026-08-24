# Nächste Arbeitsschritte

**Stand:** 27. Juli 2026  
**Zweck:** aktueller, priorisierter Arbeitsstand für `gecompat/SQL_Server_Analyze`

## 1. Aktueller Produktstand

Der portable Framework-Kern ist für SQL Server 2019, 2022 und 2025 implementiert. Die kanonische Linux-Release-Evidenz steht in `Metadata/Quality/Test_Matrix.csv`. Die dort dokumentierte 34-Suite-Matrix deckt alle 17 P0-, 40 P1- und 124 P2-Fälle sowie die frameworkweiten Ausgabe- und Wellenverträge ab.

Für die Repository-Qualität bestehen keine offenen RQ-Aufgaben. `RQ-001` bis `RQ-006`, die Dokumentationsprüfung, das Repository- und ZIP-Datenschutzgate sowie der Commit-Message-Vertrag sind umgesetzt.

Die allgemeine Lab-Provisionierung und die QuickStart-Laufzeitumgebungen wurden nach `gecompat/SQL_Server_Lab` verlagert. `SQL_Server_Lab` stellt Docker- und Podman-Umgebungen bereit. In diesem Repository verbleiben Frameworkcode, Frameworkdokumentation, analyserbezogene Szenarien und künftig deren benutzerorientierte Beispielsteuerung.

## 2. Verbindliche Statusquellen

Die Statusquellen besitzen unterschiedliche Aufgaben und dürfen nicht gegeneinander interpretiert werden:

- `Metadata/Quality/Test_Matrix.csv` ist die kanonische Quelle für tatsächlich ausgeführte Zielsystem- und Release-Evidenz.
- `Metadata/Quality/Future_Enhancement_Backlog.csv` enthält priorisierte noch nicht implementierte Erweiterungen.
- `Metadata/Quality/Implementation_Status.csv` trennt gelieferten Umfang von noch offenem Umfang je Arbeitspaket.
- `Metadata/Inventory/Module_Maturity.csv` beschreibt den Reifegrad der sichtbaren Module und nennt fehlende Plattform- oder Laufzeitevidenz.
- `Metadata/Quality/Special_Case_Gap_Backlog.csv` dokumentiert die abgeschlossene P0-, P1- und P2-Special-Case-Matrix sowie die externen P3-Grenzen.

Ein grüner statischer Vertrag oder ein vorhandener SQL-Quellpfad ist kein Ersatz für einen dokumentierten Laufzeitnachweis.

## 3. Abgeschlossene Konsistenz- und Produktwelle

### FRAMEWORK-USAGE-001 – Frameworknutzung aus Query Store

`monitor.USP_FrameworkUsageFromQueryStore` besitzt nun den vollständigen öffentlichen Frameworkvertrag: kanonisches Objekt- und Resultsetinventar, `@Hilfe`, gewichtete Query-Store-Aggregation, sichtbare Quellenlage, CONSOLE, RAW, TABLE, NONE, JSON, Status-OUTPUT-Parameter und Wiederherstellung von `LOCK_TIMEOUT`. Der Begleitvertrag `Code/Tests/QueryStore/120_Framework_Usage_Runtime_Contract.sql` prüft den Vertrag auf SQL Server 2019, 2022 und 2025.

## 4. ANALYZE-LAB-001 – spielbare Analyze-Beispiele

Die Zielarchitektur ist in `Documentation/Architecture/SQL_Server_Lab_Example_Integration_Plan.md` verbindlich festgelegt.

`SQL_Server_Lab` verantwortet ausschließlich die allgemeine SQL-Server-Testumgebung, Provider, Ressourcen, Readiness, State und Cleanup. `SQL_Server_Analyze` verantwortet Beispielkatalog, Auswahl, Frameworkinstallation, synthetische Fixtures, Workloads, interaktive Sessionabläufe, Analyzer-Aufrufe, Assertions, projektspezifisches Cleanup und Anleitungen.

Die Realisierung bleibt insgesamt `PARTIAL_PRODUCT_FUNCTION`, der erste Slice `BLOCKING-001` ist jedoch vollständig abgenommen. Katalog, JSON-Schema, statischer Validator sowie Interactive-/Verify-Runner sind implementiert. Native Verify-Läufe haben unter Docker SQL Server 2019, 2022 und 2025 sowie unter Podman SQL Server 2022 jeweils Frameworkinstallation, Blocking-Invariante, Analyzer und Cleanup bestanden. Der getrennte Interactive-Pfad wurde unter Podman 2022 bis zur Rückgabe der Session-, Analyse- und Cleanup-Skripte geprüft und anschließend scopegebunden bereinigt. Sechs weitere Beispiele sind katalogisiert, aber noch nicht als vollständige Runtime-Slices freigegeben.

Vor jeder möglichen Änderung an `SQL_Server_Lab` muss eine konkrete Funktionslücke mit Schnittstelle, Auswirkungen und Begründung vorgelegt und ausdrücklich freigegeben werden. Ohne Freigabe wird ausschließlich in `SQL_Server_Analyze` gearbeitet.

Interne Verarbeitungsreihenfolge:

1. vorhandene Beispiele, Fixtures und Special-Case-Fälle inventarisieren;
2. Beispielkatalog und JSON-Schema festlegen;
3. statischen Katalogvalidator implementieren;
4. `BLOCKING-001` vollständig umsetzen – abgeschlossen;
5. Docker auf 2019, 2022 und 2025 sowie Podman auf mindestens einer unterstützten Version nativ abnehmen – abgeschlossen;
6. bestätigte Lab-Gaps nur nach ausdrücklicher Freigabe bearbeiten – Podman-Windows-Hostauflösung im Lab ergänzt;
7. die sechs weiteren katalogisierten Beispiele in kleinen fachlichen Wellen als Runtime-Slices übernehmen.

## 5. Priorisierte funktionale Erweiterungen

### Abgeschlossen – SQL25-005

`USP_QueryStoreReplicaAnalysis` und der Query-Store-Orchestrator trennen SQL-Server-2025-Runtime-, Wait- und Plan-Forcing-Evidenz nach beobachteter Replica-Rolle. SQL Server 2019 und 2022 liefern versionssicher `UNAVAILABLE_VERSION`.

### Priorität 1 – zusätzliche Betriebsdiagnosen

1. `OPS-005`: Linked-Server-Inventar mit standardmäßig deaktiviertem Remotezugriff und optional begrenztem Verbindungstest.
2. `OPS-006`: Datenbankportabilität über persistierte Edition Features und uncontained dependencies.
3. `OPS-008`: Größe, Wachstum und Retention der relevanten `msdb`-Historien ohne automatische Bereinigung.
4. `OPS-007`: begrenzte opt-in Cursor-Diagnostik.
5. `OPS-009`: sichtbare Benutzerobjekte in Systemdatenbanken ohne DDL-Aktion.

### Priorität 2 – SSIS-001

Phase 0 ist in `Documentation/Architecture/SSIS_001_Phase0_Public_Contract.md` abgeschlossen. Resultsetnamen, Schemaversionen, DTSX-Version 2, Expression-Grenzen, Komponentenprofile, Statuscodes, Lookup-Prüflimits, Datenschutzgrenzen, Installerstruktur und die separate Datei-/ISPAC-Adaptergrenze sind verbindlich festgelegt. Phase 1, der statische Parser, ist noch nicht implementiert.

## 6. Ausstehende externe und plattformspezifische Evidenz

### RUNTIME-001

Der portable read-only Kern für External Runtime und SQL CLR ist implementiert. Offen bleibt die Feature-Matrix mit aktivierten R-, Python-, Java-, C#- und Custom-Language-Extensions sowie SQL CLR mit einer synthetischen `SAFE`-Assembly.

### Windows und Azure SQL Managed Instance

Die Windows-Ziele in `Test_Matrix.csv` bleiben `NOT_EXECUTED`. Erforderlich sind kontrollierte, synthetische Nachweise für Windows-spezifische Features, aktive SQL-Server-Runtimes und gegebenenfalls Azure-MI-spezifische Capabilities.

### Kostenintensive opt-in Pfade

Separat nachzuweisen sind Page Details, Event-XML, Contention-Sampling, Buffer-Pool-Verteilung, Statistikverteilung, In-Memory-Hashketten, breite Cross-Database-Auswahl und RUNTIME-001-Sampling mit gültigem Delta und Resetgrenzen.

## 7. Größere zukünftige Architekturhärtung

### COLL-001 – Collation-Portabilität

Die Boundary-Klassen sind in `Metadata/Quality/Collation_Boundary_Inventory.csv` inventarisiert und klassifiziert. Per-Datei-Härtung und die gemischte Laufzeitmatrix auf SQL Server 2019, 2022 und 2025 bleiben offen. Bis dahin bleibt `SQL_Latin1_General_CP1_CS_AS` die garantierte Testgrenze.

### SC-023-Erweiterung

Der erste restart-sichere Performance-Counter-Baseline-Slice ist implementiert. Zusätzliche Collector, Rollups sowie optionale Scheduler- und Exportpakete bleiben eigenständige zukünftige Erweiterungen.

### SC-024 und SC-025

Fleet-Korrelation benötigt eine externe Komponente mit Mandanten-, Transport-, Aufbewahrungs- und Löschvertrag. Restore- und Hostnachweise benötigen eine ausdrücklich autorisierte isolierte Ausführungsumgebung. Diese Punkte sind keine fehlenden Funktionen des portablen T-SQL-Kerns.

## 8. Empfohlene Verarbeitungsreihenfolge

1. `ANALYZE-LAB-001` mit Inventar, Beispielkatalog und `BLOCKING-001` beginnen.
2. RUNTIME-001-, Windows- und weitere Feature-Evidenz nachziehen.
3. `OPS-005`, `OPS-006` und `OPS-008` umsetzen.
4. SSIS-001 Phase 0 abschließen.
5. `COLL-001` als eigene Querschnittswelle planen und umsetzen.
6. P3-Erweiterungen nur nach den jeweils erforderlichen externen Entscheidungen ausführen.

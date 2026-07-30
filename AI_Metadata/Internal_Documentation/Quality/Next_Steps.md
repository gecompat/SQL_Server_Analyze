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

Die Planungsphase ist dokumentiert, die Realisierung ist noch nicht begonnen. Der erste vollständige Vertical Slice ist `BLOCKING-001` mit getrenntem Interactive- und Verify-Modus für Docker, Podman sowie SQL Server 2019, 2022 und 2025.

Vor jeder möglichen Änderung an `SQL_Server_Lab` muss eine konkrete Funktionslücke mit Schnittstelle, Auswirkungen und Begründung vorgelegt und ausdrücklich freigegeben werden. Ohne Freigabe wird ausschließlich in `SQL_Server_Analyze` gearbeitet.

Interne Verarbeitungsreihenfolge:

1. vorhandene Beispiele, Fixtures und Special-Case-Fälle inventarisieren;
2. Beispielkatalog und JSON-Schema festlegen;
3. statischen Katalogvalidator implementieren;
4. `BLOCKING-001` vollständig umsetzen;
5. native Docker- und Podman-Läufe auf 2019, 2022 und 2025 durchführen;
6. bestätigte Lab-Gaps nur nach ausdrücklicher Freigabe bearbeiten;
7. weitere Beispiele in kleinen fachlichen Wellen übernehmen.

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

Vor der T-SQL-Implementierung ist Phase 0 abzuschließen. Festzulegen sind insbesondere Resultsetnamen, Schemaversionen, unterstützte DTSX-Versionen, Expression-Grenzen, Komponentenprofile, Statuscodes, Lookup-Prüflimits, Datenschutzgrenzen, Installerstruktur und die Abgrenzung eines optionalen Datei- oder ISPAC-Adapters.

## 6. Ausstehende externe und plattformspezifische Evidenz

### RUNTIME-001

Der portable read-only Kern für External Runtime und SQL CLR ist implementiert. Offen bleibt die Feature-Matrix mit aktivierten R-, Python-, Java-, C#- und Custom-Language-Extensions sowie SQL CLR mit einer synthetischen `SAFE`-Assembly.

### Windows und Azure SQL Managed Instance

Die Windows-Ziele in `Test_Matrix.csv` bleiben `NOT_EXECUTED`. Erforderlich sind kontrollierte, synthetische Nachweise für Windows-spezifische Features, aktive SQL-Server-Runtimes und gegebenenfalls Azure-MI-spezifische Capabilities.

### Kostenintensive opt-in Pfade

Separat nachzuweisen sind Page Details, Event-XML, Contention-Sampling, Buffer-Pool-Verteilung, Statistikverteilung, In-Memory-Hashketten, breite Cross-Database-Auswahl und RUNTIME-001-Sampling mit gültigem Delta und Resetgrenzen.

## 7. Größere zukünftige Architekturhärtung

### COLL-001 – Collation-Portabilität

Vor einer Erweiterung der freigegebenen Plattformgrenze sind sämtliche Collation-Grenzen zu inventarisieren und fachlich zu klassifizieren. Danach ist eine gemischte Laufzeitmatrix auf SQL Server 2019, 2022 und 2025 erforderlich. Bis dahin bleibt `SQL_Latin1_General_CP1_CS_AS` die garantierte Testgrenze.

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

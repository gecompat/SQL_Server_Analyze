# SQL-Server-Diagnoseabdeckung und Gap-Intake

**Referenz:** `WI-0010`

**Stand:** 29. August 2026

**Status:** `RESEARCHED_NOT_IMPLEMENTED`
**Maschinenlesbare Matrix:** `Metadata/Quality/Diagnostic_Coverage_Landscape.csv`

## Zweck

Diese Landkarte gleicht den aktuellen Umfang von SQL Server Analyze mit den relevanten Diagnose-, Betriebs-, Sicherheits-, Hochverfügbarkeits-, Datenfeature- und Integrationsbereichen von SQL Server ab. Sie hält auch bereits abgedeckte und ausdrücklich ausgeschlossene Bereiche fest. Dadurch bleibt ein fehlender Backlogeintrag nicht mit einer bewussten Produktgrenze verwechselbar.

Die Matrix ist ein Intake- und Planungsartefakt. Sie ist kein öffentlicher Produktvertrag, keine Zusage für neue Procedures und kein Beleg für Laufzeitabdeckung. Die semantischen `CoverageKey`-Werte sind stabile Matrixschlüssel, aber keine Referenzen aus der zentralen Artefaktregistrierung. Erst ein priorisiertes Dossier erhält eine eigene registrierte Referenz.

## Methodik

Der Abgleich verwendet vier Evidenzschichten:

1. die 104 öffentlichen Procedures sowie Objekt-, Resultset-, Quellen-, Berechtigungs- und Reifegradinventare;
2. die bestehende Spezialfallmatrix, den operativen Backlog und die langfristige Roadmap;
3. die aktuellen Microsoft-Übersichten zu SQL Server 2025, Database-Engine-Komponenten, DMVs, Sicherheit und Business Continuity;
4. gezielte Microsoft-Primärquellen für Kandidaten, deren Umfang nicht durch eine allgemeine Übersicht hinreichend bestimmbar ist.

Ein Texttreffer gilt nicht als Abdeckung. `IMPLEMENTED_DEEP` setzt ein spezialisiertes Modul oder einen nachgewiesenen vertieften Vertrag voraus. `IMPLEMENTED_BASELINE` bezeichnet Inventar- oder Konfigurationssicht ohne vollständige Betriebsdiagnose. `PARTIAL_PRODUCT_FUNCTION` übernimmt einen bereits maßgeblichen Teilstatus. `RESEARCHED_NOT_IMPLEMENTED` bezeichnet eine bestätigte Diagnosefrage ohne Implementierung. `EXTERNAL_EVIDENCE_REQUIRED` trennt T-SQL-sichtbare Evidenz von Host-, Netzwerk-, Remote- oder Wiederherstellungsnachweisen. `OUT_OF_SCOPE` nennt bewusst ausgeschlossene Produkte und Plattformen.

## Ergebnis

Die Matrix betrachtet 106 fachliche Bereiche. Der Frameworkkern deckt die zentralen Current-State-, Query-, Index-, Statistik-, Query-Store-, Extended-Events-, Kapazitäts-, Integritäts-, Backup-, Availability-Group-, Replikations-, Agent- und Spezialfeaturefragen bereits breit ab. Die Recherche bestätigt dennoch mehrere eigenständige Lückengruppen.

### Priorität P1

- Server- und Datenbankprincipals, Rollen, Ownership, explizite Berechtigungen und verwaiste Zuordnungen;
- Authentisierungs- und Login-Lifecycle einschließlich Entra-fähiger Principals, ohne Identitäten oder Secrets ungeschützt auszugeben;
- TDS-/TLS-, Zertifikats-, Extended-Protection- und Endpoint-Posture mit klarer Grenze zwischen SQL- und Hostevidenz;
- deprecated, discontinued und breaking Features als versionsbezogene Upgrade- und Migrationsfläche;
- Legacy-Datenbankspiegelung als weiterhin vorhandene, aber abgekündigte Betriebsrealität;
- verteilte Transaktionen und MSDTC einschließlich Recovery- und HADR-Kontext;
- Linux-, Container- und cgroup-Ressourcengrenzen, soweit SQL-eigene und externe Plattformwerte sicher korreliert werden können;
- Row-Level Security und Dynamic Data Masking als aktive Security-Policy-Fläche statt bloßer Objektinventur.

### Priorität P2

- Database Snapshots mit Source-Abhängigkeit, Sparse-File-Wachstum, Alter und Suspect-Grenzen;
- Policy-Based Management einschließlich Policies, Bedingungen, Evaluationsmodi und letzter Auswertung, ohne Regeln auszuführen oder zu erzwingen;
- Sensitivity Classification, Ledger-Digest-/Verifikationsstatus, EKM und Credentialabhängigkeiten;
- Failover Cluster Instances und WSFC-/Pacemaker-Hostevidenz als getrennter externer Adapter;
- unveränderbare URL-Backups und SQL-Server-2025-Backups auf Secondary Replicas;
- FILESTREAM/FileTable-Betrieb über die bestehende leichte Erkennung hinaus;
- Change Event Streaming, Fabric Mirroring und External REST Endpoint Invocation mit strikter Trennung lokaler Kataloge von externen Endpoints, Credentials und Payloads;
- Plan Guides sowie SQL-Agent-Proxies und deren Berechtigungsabhängigkeiten.

### Priorität P3 und bedingte Vertiefung

- Hybrid Buffer Pool und persistenter Speicher;
- Graph-, Spatial-, XML- und native JSON-Deep-Analysen nur bei nachgewiesener Nutzung und konkreter Betriebsfrage;
- Legacy SQL Trace beziehungsweise Default Trace als Migrations- und Observability-Abhängigkeit;
- DQS- und MDS-Restbestände als Upgradehinweis für Quellsysteme vor SQL Server 2025;
- DDL-, Datenbank- und Logon-Trigger als Security- und Betriebsoberfläche.

## Bewusste Grenzen

Die Landkarte erweitert die Roadmap nicht auf Azure SQL Database oder Azure SQL Managed Instance. SQL Server Analysis Services, Power BI Report Server, Clienttreiber, Connection Pools und Anwendungscode bleiben eigene Produkte oder externe Evidenzbereiche. SSIS behält sein bestehendes Paket `SSIS-001`. Externe Host-, Cluster-, Netzwerk-, Storage- und Restorebeweise bleiben außerhalb des portablen T-SQL-Kerns.

Eine vollständige Namensliste beweist weder vollständige Semantik noch Produktreife. Neue Kandidaten werden erst dann priorisiert, wenn Diagnosefrage, vorhandene Abdeckung, Datenquellen, Berechtigungen, Eigenlast, Datenschutz, Plattformen, False-Positive-Grenzen und Abnahmeevidenz in einem Dossier geklärt sind. Erweiterungen vorhandener Procedures haben weiterhin Vorrang vor neuen öffentlichen Procedures.

## Planungsübergabe

`WI-0010` bleibt als kontinuierliches Intake-Arbeitselement aktiv. Bei der späteren Planung gilt:

1. zuerst offene Reife- und Collationverträge der aktuellen Welle abschließen;
2. bereits registrierte `WI-0002` bis `WI-0009` nicht durch neue Kandidaten überspringen;
3. pro ausgewähltem `CoverageKey` die Überschneidung mit bestehenden Modulen erneut prüfen;
4. erst danach eine eigene Registryreferenz vergeben und Analyse, Spezifikation, Implementierung sowie Evidenz als getrennte Schritte planen;
5. abgelehnte Kandidaten mit Begründung als `OUT_OF_SCOPE` oder `EXTERNAL_EVIDENCE_REQUIRED` in der Matrix erhalten.

## Zentrale Primärquellen

- [What's new in SQL Server 2025](https://learn.microsoft.com/en-us/sql/sql-server/what-s-new-in-sql-server-2025?view=sql-server-ver17)
- [What is SQL Server?](https://learn.microsoft.com/en-us/sql/sql-server/what-is-sql-server?view=sql-server-ver17)
- [SQL Server Operating System related DMVs](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sql-server-operating-system-related-dynamic-management-views-transact-sql?view=sql-server-ver17)
- [SQL Server security best practices](https://learn.microsoft.com/en-us/sql/relational-databases/security/sql-server-security-best-practices?view=sql-server-ver17)
- [Business continuity and database recovery](https://learn.microsoft.com/en-us/sql/database-engine/sql-server-business-continuity-dr?view=sql-server-ver17)
- [Performance best practices for SQL Server on Linux](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-performance-best-practices?view=sql-server-ver17)
- [Microsoft SQL Assessment DefaultRuleset](https://github.com/microsoft/sql-server-samples/blob/master/samples/manage/sql-assessment-api/DefaultRuleset.csv)

Die zeilenspezifischen Primärquellen stehen in der maschinenlesbaren Matrix. Externe Vergleichskataloge liefern nur Kandidaten und werden nicht als Produktvertrag oder kopierter Regelcode verwendet.

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

## Toolbelt-Übergabe

**Abgleich:** 11. September 2026, Toolbelt [`f4fe237`](https://github.com/gecompat/SQL_Server_Toolbelt/commit/f4fe23721b203a2e540a7b421024e9cbd85f5f85) und Analyze [`6e46adc`](https://github.com/gecompat/SQL_Server_Analyze/commit/6e46adc22bb5deb6f6c14cd670d8f4023db44ce6).

Die statische Gegenprobe der Toolbelt-Modulübersicht, SQL-/C#-Quellen und relevanten Grenzfälle ergab keinen belegten Kandidaten für eine Codeverschiebung. Allgemeine Daten-, Parser-, Transformations- und Ausführungshilfen bleiben in Toolbelt. Dazu zählen eigene Ereignis- und Queue-Statussichten, Heartbeat und Recovery, Modulmarker, Korrelationskontext, kooperative Cancellation sowie Prüfungen eigener Provider und Deployments. Die fachliche Bewertung betrieblicher Zustände gehört gemäß der [Toolbelt-Repositorygrenze](https://github.com/gecompat/SQL_Server_Toolbelt/blob/main/Documentation/Architecture/REPOSITORY_BOUNDARIES.md) in Analyze.

Die folgende Übergabe ergänzt den bestehenden Intake `WI-0010`. Sie führt die Herkunft mit vorhandener Abdeckung zusammen und definiert die noch zu klärende Diagnosefrage. Die ausführliche Diagnoseplanung wird hier gepflegt; Toolbelt erhält Quell-ID, Abgrenzung und Rückverweis. Bestehende CoverageKeys, Prioritäten, registrierte Arbeitselemente und Implementierungsstatus bleiben unverändert. Diese Übergabe erzeugt keine neue Matrixzeile, Procedure oder Implementierungsfreigabe.

| Toolbelt-Quell-ID | Diagnoseanteil und vorhandene Abdeckung | Zuständigkeit und nächster Planungsschritt |
|---|---|---|
| [AC-2026-001](https://github.com/gecompat/SQL_Server_Toolbelt/blob/main/Backlog/SQL_SERVER_ANALYZE_CANDIDATES.md#ac-2026-001-read-only-security-feature-katalog) | Der kombinierte Security-Katalog betrifft die bestehenden CoverageKeys `PRINCIPALS_ROLE_PERMISSIONS`, `RLS_DYNAMIC_MASKING` und `SENSITIVITY_CLASSIFICATION`. Alle drei stehen auf `RESEARCHED_NOT_IMPLEMENTED`; allgemeine Security-Konfiguration und Feature-Inventur belegen keinen kombinierten Bericht. | Analyze `WI-0010` führt die drei bestehenden Themen weiter. Vor einer Priorisierung erneut die Teilabdeckung prüfen und mit dem Benutzer gemeinsame oder getrennte Berichte, Resultsets, Metadatensichtbarkeit und Aussagegrenzen klären. Kein zusätzliches Arbeitselement für dieselbe Planung eröffnen. |
| [RI-2026-140](https://github.com/gecompat/SQL_Server_Toolbelt/blob/main/Backlog/TOOLBELT_RESEARCH_INBOX.md) | Toolbelt stellt Parser, Referenzextraktion und definierte Transformation bereit. Daraus folgt keine Abdeckung bewertender Lint-Regeln. Vorhandene Analyze-Query-, Plan- und Schemaanalysen sind keine pauschale Zusage für einen Linter über beliebigen SQL-Text. | Analyze `WI-0010` hält Linting und Bad-Practice-Bewertung als offene Intake-Frage. Zuerst konkrete Regeln und Überschneidungen mit vorhandenen Findings bestimmen; Datenquellen, False Positives und die optionale Nutzung öffentlicher Toolbelt-Verträge bleiben zu klären. |
| [RI-2026-002](https://github.com/gecompat/SQL_Server_Toolbelt/blob/main/Backlog/TOOLBELT_RESEARCH_INBOX.md) | Der Vergleich zweier vorgegebener Schemazustände und ein überprüfbarer Änderungsplan bleiben Toolbelt. `SCHEMA_CONSTRAINTS` deckt mit `USP_ObjectInventory`, `USP_ObjectAnalysis` und `USP_SchemaDesignAnalysis` bereits Objekt- und Schemaanalysen ab; das beweist keine laufende Schemaüberwachung. | Analyze `WI-0010` klärt nur den zusätzlichen betrieblichen Überwachungs- und Bewertungsbedarf. Vor einer Formalisierung Capture, Zeitbezug, erwartete Änderungen und vorhandene Findings abgleichen. |
| [RI-2026-009](https://github.com/gecompat/SQL_Server_Toolbelt/blob/main/Backlog/TOOLBELT_RESEARCH_INBOX.md) | Neutrale Fingerprints bleiben Toolbelt. `TIME_SERIES_BASELINES` verweist auf den partiellen Performance-Counter-Slice von `SC-023`; daraus folgt kein Schema- oder Datenfingerprint-Monitor. | Analyze `WI-0010` klärt die konkrete betriebliche Baseline-Frage gegen `SC-023` und dessen bestehende Erweiterungsplanung. Reset-, Vergleichs- und Evidenzgrenzen sind vor einer Erweiterung festzulegen. |
| [RI-2026-019](https://github.com/gecompat/SQL_Server_Toolbelt/blob/main/Backlog/TOOLBELT_RESEARCH_INBOX.md) | Resultset-Metadaten und der Vergleich mit einem übergebenen Vertrag bleiben Toolbelt. Eine betriebliche Bewertung von Vertragsänderungen ist durch die vorhandene Objekt- und Schemaanalyse nicht automatisch abgedeckt. | Analyze `WI-0010` klärt, ob eine eigenständige Betriebsfrage vorliegt oder die Anforderung durch Toolbelt- beziehungsweise projektspezifische Contract-Tests erfüllt ist. Nur den nachgewiesenen Diagnosebedarf weiterführen. |
| [RI-2026-165](https://github.com/gecompat/SQL_Server_Toolbelt/blob/main/Backlog/TOOLBELT_RESEARCH_INBOX.md) | Neutrale Schema- und Objektrowsets für Generatoren bleiben Toolbelt. Analyze besitzt die Objekt- und Schemaanalysen unter `SCHEMA_CONSTRAINTS`. Instanzübergreifende Drift und Topologie berühren `FLEET_CORRELATION` und die externe Evidenzgrenze von `SC-024`. | Analyze `WI-0010` grenzt eine konkrete lokale Diagnose von Fleet-Korrelation ab. Vor einer Formalisierung bestehende Procedures und `SC-024` abgleichen; externe Erfassung, Transport und Retention nicht stillschweigend in den T-SQL-Kern aufnehmen. |

Maßgeblich für die genannten Statuswerte bleibt die [Abdeckungsmatrix](../../../Metadata/Quality/Diagnostic_Coverage_Landscape.csv). Die Übergabe autorisiert weder einen neuen öffentlichen SQL-Vertrag noch eine Toolbelt-Abhängigkeit. Beide Repositories bleiben eigenständig; die Zusammenarbeit erfolgt über öffentliche Verweise und ausdrücklich beauftragte Änderungen. Die statische Zuordnung ist kein SQL-Laufzeitnachweis.

## Zentrale Primärquellen

- [What's new in SQL Server 2025](https://learn.microsoft.com/en-us/sql/sql-server/what-s-new-in-sql-server-2025?view=sql-server-ver17)
- [What is SQL Server?](https://learn.microsoft.com/en-us/sql/sql-server/what-is-sql-server?view=sql-server-ver17)
- [SQL Server Operating System related DMVs](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sql-server-operating-system-related-dynamic-management-views-transact-sql?view=sql-server-ver17)
- [SQL Server security best practices](https://learn.microsoft.com/en-us/sql/relational-databases/security/sql-server-security-best-practices?view=sql-server-ver17)
- [Business continuity and database recovery](https://learn.microsoft.com/en-us/sql/database-engine/sql-server-business-continuity-dr?view=sql-server-ver17)
- [Performance best practices for SQL Server on Linux](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-performance-best-practices?view=sql-server-ver17)
- [Microsoft SQL Assessment DefaultRuleset](https://github.com/microsoft/sql-server-samples/blob/master/samples/manage/sql-assessment-api/DefaultRuleset.csv)

Die zeilenspezifischen Primärquellen stehen in der maschinenlesbaren Matrix. Externe Vergleichskataloge liefern nur Kandidaten und werden nicht als Produktvertrag oder kopierter Regelcode verwendet.

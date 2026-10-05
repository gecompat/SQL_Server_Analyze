# Nächste Arbeitsschritte

**Stand:** 5. Oktober 2026
**Zweck:** aktuelle ausführbare Entwicklungswelle für `gecompat/SQL_Server_Analyze`

## Maßgeblichkeit

Die [langfristige Weiterentwicklungsroadmap](../Architecture/Long_Term_Development_Roadmap.md) ordnet alle späteren Entwicklungsrichtungen, Abhängigkeiten und Exit-Kriterien. Dieses Dokument enthält ausschließlich den aktuellen Produktstand und die nächste ausführbare Welle.

Die Statusquellen besitzen getrennte Aufgaben:

- `Metadata/Quality/Implementation_Status.csv` trennt gelieferten und offenen Umfang je Arbeitselement.
- `Metadata/Inventory/Module_Maturity.csv` beschreibt sichtbare Modulreife und fehlende Evidenz.
- `Metadata/Quality/Test_Matrix.csv` dokumentiert tatsächlich ausgeführte Laufzeitnachweise.
- `Metadata/Quality/Future_Enhancement_Backlog.csv` enthält priorisierte noch nicht implementierte oder unvollständige Erweiterungen.

Ein vorhandener SQL-Quellpfad oder ein grüner statischer Vertrag ersetzt keinen dokumentierten Laufzeitnachweis.

## Auftrag zur autonomen Fortsetzung

Der Benutzer hat am 5. Oktober 2026 die autonome Entwicklung beauftragt und
die bereits in SQL_Server_Toolbelt und SQL_Server_Lab verwendeten
Autonomieregeln ausdrücklich herangezogen. Die Arbeit verwendet weiterhin
die vorhandene Roadmap und Statusquellen. Jeder kohärente Schritt umfasst
die betroffenen Verträge, Implementierung, Dokumentation und Tests. Es gibt
genau einen Implementierer je Schritt; ein unabhängiger Review prüft den
stabilen Stand. Vor der Fortsetzung werden `origin/main`, offene Pull Requests,
Regelkontext und vorhandene Evidenz abgeglichen. Geprüfte Schritte werden
über einen Pull Request mit erfolgreicher erforderlicher Head-CI integriert;
danach folgen Synchronisierung und ausschließlich eigener Cleanup. Nach
dem bestätigten PR-Merge nach `origin/main` werden auch die integrierten
lokalen Arbeitsbranches entfernt; der aktive Entwicklungsbranch bleibt erhalten.

Die bestehenden Produkt-, Datenschutz- und Testregeln dieses Repositorys
bleiben maßgeblich. Neue öffentliche Funktionsverträge werden vor ihrer
Implementierung konkretisiert und funktionsbezogen freigegeben. Bestehende
konkrete Freigaben werden nicht erneut abgefragt. Linked-Server-Verbindungen
zwischen ausschließlich neu erzeugten lokalen Testcontainern sind ausdrücklich
freigegeben. Bestehende, gemeinsam verwendete und produktive Systeme sind
nicht Teil dieser Freigabe. Secrets und konkrete Runtimeidentitäten bleiben
außerhalb der Repositoryartefakte.

Ein abgeschlossener Schritt oder ein zusätzlicher Benutzerauftrag beendet
die Gesamtwelle nicht. Unabhängige autorisierte Arbeit wird bei einem
isolierten Blocker fortgesetzt. Die automatische Fortsetzung dieses Chats
unterstützt die Entwicklung bis zum ausdrücklichen Benutzerstopp, regulären
Gesamtabschluss oder tatsächlichen Eingabebedarf; unveränderte,
nicht handlungsfähige Zustände erzeugen keine Statusmeldungen.

Der Fortsetzungsrhythmus ist keine Wartefrist für laufende autorisierte
Entwicklung. Sobald ein unabhängiger ausführbarer Schritt feststeht, beginnt
er unmittelbar nach den erforderlichen Vorprüfungen.

## Aktueller Produktstand

Der portable Frameworkkern ist für SQL Server 2019, 2022 und 2025 implementiert. Die allgemeine Lab-Provisionierung und deren Lifecycleverantwortung liegen in `gecompat/SQL_Server_Lab`. SQL Server Analyze enthält weiterhin Frameworkcode, Dokumentation, analyserspezifische Szenarien und die benutzerorientierte Beispielsteuerung.

Die kanonische Release-Evidenz umfasst alle 17 P0-, 40 P1- und 124 P2-Fälle. Die abgeschlossene P0-, P1- und P2-Special-Case-Matrix bleibt Bestandteil des bestätigten Produktstands.

### Abgeschlossen – SQL25-005

`USP_QueryStoreReplicaAnalysis` und der Query-Store-Orchestrator trennen SQL-Server-2025-Runtime-, Wait- und Plan-Forcing-Evidenz nach beobachteter Replica-Rolle. SQL Server 2019 und 2022 liefern versionssicher `UNAVAILABLE_VERSION`.

`ANALYZE-LAB-001` ist für den definierten Sieben-Beispiele-Umfang abgeschlossen. Die sechs zusätzlich katalogisierten Beispiele sind dokumentiert, über den gemeinsamen Interactive-/Verify-Runner auswählbar und auf SQL Server 2025 mit dem primären Docker-Provider runtimegeprüft. Der Project-Adapter-Slice `EXECUTION-PLAN-001` installiert zusätzlich den eigenständigen Execution-Plan-Analyse-Frameworkteil und bestand seinen SQL-Server-2025-Quick-Run unter Docker und Podman einschließlich scopegebundenem Cleanup.

Das registrierte Intake-Arbeitselement `WI-0010` hält in der neuen [Diagnoseabdeckung und Gap-Intake](../Research/SQL_Server_Diagnostic_Coverage_Landscape.md) darüber hinaus 106 implementierte, partielle, geplante, externe oder bewusst ausgeschlossene Themen fest. Es ändert die folgende ausführbare Reihenfolge nicht. Neue Kandidaten erhalten erst nach dem Reifeabschluss und einem eigenen Dossier eine Registryreferenz.

Alle 104 Procedure-Seiten besitzen den Status `DEEP_REVIEWED` nach Reviewvertrag 3. Dieser Dokumentationsanteil des Reifeabschlusses ist erledigt und ersetzt keine noch offene Laufzeitevidenz.

## Nächste ausführbare Welle: Reifeabschluss

Die nächste Welle erweitert keine öffentliche Diagnosefläche. Sie schließt die bereits implementierten Teilfunktionen und zugehörigen Reifeverträge ab.

1. `OPS-005` ergänzt die noch offene Providervarianz. Der kontrollierte MSOLEDBSQL-Verbindungserfolg zwischen zwei neuen lokalen SQL-Server-2025-Containern ist seit dem 5. Oktober 2026 belegt. Der synthetische TestLab-Adapter deckt bereits die Drei-Versionen-, Berechtigungs- und Timeoutfälle ab; zusätzliche native Erfolgsläufe folgen nur bei konkretem Versionsrisiko oder erforderlichem Release-Nachweis.
2. `OPS-006` schließt die verbleibende Evidenz einer tatsächlich nicht unterstützten Systemquelle. Der kontrollierte Feature-Nachweis auf nativen SQL Server 2019, 2022 und 2025 sowie die vorhandenen Berechtigungspfade werden nicht erneut als offene Arbeit geführt.
3. `OPS-008` ergänzt nicht leere Agent-, Mail- und Maintenance-Historien sowie tatsächlich fehlende optionale Quellen. Fünf kontrollierte Leerfälle, kurze und lange Backup- und Restorezeitfenster und kontrolliertes Dateiwachstum sind auf SQL Server 2025 belegt; die vorhandenen Berechtigungs- und Begrenzungsfälle bleiben bestätigt. Der Versuch einer optionalen Viewumbenennung scheiterte mit `15001` und schließt die Quellenabwesenheit nicht ab.
4. `OPS-007` ergänzt die verbleibende Hochlast-Evidenz. Die ressourcenpositive eigene zweite Session und der explizite Berechtigungsfehler sind auf SQL Server 2025 belegt. `OPS-009` besitzt einen nativen SQL-Server-2025-Nachweis für positives Inventar, exakte Begrenzung, eingeschränkte und selektive Sicht sowie Leerfall. Ein weiterer nativer SQL-Server-2022-Lauf folgt nur bei konkretem Versionsrisiko oder erforderlichem Release-Nachweis.
5. `COLL-001` setzt die begonnene objektbezogene Härtung fort. Die fünf OPS-Objekte, die Child-JSON-Aggregation von `USP_CurrentOverview` und der TABLE-Zielvertrag bilden den ersten statisch sowie auf der garantierten Collation nativ abgesicherten Slice. `USP_IndexOperationalStats` und `USP_Partitions` besitzen zusätzlich SQL-Server-2025-Nachweise mit abweichender Server-/`tempdb`-Collation für gezielte JSON-/TABLE-Ausgabe, Frameworkcollation im Export und native Gegenprüfung. Die lokalen Object-/Index-Arbeitstabellen sind explizit collatiert; 13 weitere TABLE-Exports und der normale ObjectAnalysis-Orchestrator bestehen auf SQL Server 2025 mit abweichender Server-/`tempdb`- und Quelldatenbankcollation. Die dabei gefundenen dynamischen Steuerwert-, JOIN- und CASE-Grenzen sind gehärtet. `USP_PerformanceCounters` besteht zusätzlich den gezielten Snapshot- und Ein-Sekunden-Samplevertrag mit TABLE-/JSON-Ausgabe und exaktem Counterfilter auf abweichender Server-/`tempdb`-Collation. `USP_BufferPoolAnalysis` besitzt zusätzlich den Memory-TABLE-/JSON-Nachweis sowie die Standard- und Opt-in-Verteilungsprüfung auf derselben gemischten Collation-Kombination. `USP_InternalContentionAnalysis` besteht zusätzlich den kumulativen und zeitbezogenen Latch-TABLE-/JSON-Vertrag mit nativer Klassenidentität und Prüfung der tatsächlichen Messdauer auf dieser Collation-Kombination. `USP_ServerSecurityConfiguration` besitzt zusätzlich einen TABLE-/JSON-Nachweis mit nativer Konfigurationsparität auf derselben gemischten Collation-Kombination. `USP_ServerHealthAnalysis` besteht zusätzlich den Modulstatus-Export und die gezielte Security- sowie erweiterte Child-JSON-Auswahl auf dieser Kombination. `USP_WorkerPressureAnalysis` besitzt zusätzlich sieben collatierte TABLE-Exporte, TABLE-/JSON-Parität und einen kontrollierten Zweikandidatenfall mit einheitlichem Requestlimit auf dieser Kombination. `USP_AuditConfigurationAnalysis` besitzt zusätzlich fünf collatierte TABLE-Exporte, native Spezifikationsparität und einheitliche TABLE-/JSON-Filter- und Limitverträge auf dieser Kombination. `USP_DatabaseIntegrityAnalysis` besitzt zusätzlich einen collatierten TABLE-Export, native Metadatenparität, einheitliche Integritätslimits und eine Gegenprüfung des optionalen LIMITED-Seitenheaders auf dieser Kombination. `USP_DatabaseCapacityAnalysis` besitzt zusätzlich neun collatierte TABLE-Textspalten, native Dateimetadatenparität auf einer eigenen schreibgeschützten Quelle und einheitliche TABLE-/JSON-Problemfilter und Limits auf dieser Kombination. `USP_CriticalEngineEvents` besitzt zusätzlich fünf collatierte TABLE-Textspalten, native XE-Ereignisparität und den vorhandenen Limit- und XML-Opt-in-Vertrag auf dieser Kombination. `USP_DiagnosticFindings` besitzt zusätzlich zehn collatierte TABLE-Textspalten, kontrollierte Parent-Zuordnung und partielle Wiederverwendung sowie einheitliche Prioritätsfilter und Limits bei unveränderten Zählern auf dieser Kombination. `USP_DatabaseConfigurationAnalysis` besitzt zusätzlich sechs collatierte TABLE-Exporte mit nativer Options- und Konfigurationsparität, kontrollierter Profilzuordnung, vollständigem dynamischem Katalogaufruf und einheitlichen Settings-/Driftlimits auf dieser Kombination. `USP_ErrorLogAnalysis` besitzt zusätzlich 22 collatierte TABLE-Textspalten und native Unicode-Logparität sowie einheitliche Detaillimits und das partielle Quelllimit auf dieser Kombination. `USP_BackupChainAnalysis` besitzt zusätzlich fünf collatierte TABLE-Textspalten und native Full-/Differentialmetadaten sowie einen positiven Ohne-Prüfsumme-Zähler und einheitliche Summary-/Backuplimits auf dieser Kombination. `USP_AgentStatus` und `USP_InfrastructureAnalysis` besitzen zusätzlich sechs collatierte TABLE-Textspalten, native Jobinventarparität und vier Modulstatus- und Child-JSON-Auswahlverträge auf dieser Kombination. `USP_ResourceGovernorAnalysis` besitzt zusätzlich fünf collatierte TABLE-Exporte mit 16 Textspalten, nativer Konfigurations-, Pool- und Gruppenparität sowie den vorhandenen Ausgabegrenzen und TempDB-Governance ohne konfiguriertes Limit auf dieser Kombination. Weitere Frameworkdateien und Verbrauchervarianten bleiben offen.

## Exit-Kriterien

Die Welle ist abgeschlossen, wenn:

- vorhandener und offener Produktumfang in den kanonischen Statusquellen übereinstimmen;
- die vorgesehenen positiven, leeren, eingeschränkten und fehlerisolierten Fälle tatsächlich ausgeführt wurden;
- betroffene Procedure-Seiten den dokumentierten Reviewstatus inhaltlich erfüllen;
- keine allgemeine Lab-Verantwortung in dieses Repository zurückverlagert wurde;
- die impact-basierten statischen und funktionalen Gates erfolgreich sind.

Die SQL-Server-2025-Erweiterungen `WI-0002` bis `WI-0007` beginnen erst, wenn der Reifeabschluss einschließlich `COLL-001` keine ungeklärte gemeinsame Vertragsabweichung hinterlässt.

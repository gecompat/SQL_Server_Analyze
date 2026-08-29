# Nächste Arbeitsschritte

**Stand:** 29. August 2026
**Zweck:** aktuelle ausführbare Entwicklungswelle für `gecompat/SQL_Server_Analyze`

## Maßgeblichkeit

Die [langfristige Weiterentwicklungsroadmap](../Architecture/Long_Term_Development_Roadmap.md) ordnet alle späteren Entwicklungsrichtungen, Abhängigkeiten und Exit-Kriterien. Dieses Dokument enthält ausschließlich den aktuellen Produktstand und die nächste ausführbare Welle.

Die Statusquellen besitzen getrennte Aufgaben:

- `Metadata/Quality/Implementation_Status.csv` trennt gelieferten und offenen Umfang je Arbeitselement.
- `Metadata/Inventory/Module_Maturity.csv` beschreibt sichtbare Modulreife und fehlende Evidenz.
- `Metadata/Quality/Test_Matrix.csv` dokumentiert tatsächlich ausgeführte Laufzeitnachweise.
- `Metadata/Quality/Future_Enhancement_Backlog.csv` enthält priorisierte noch nicht implementierte oder unvollständige Erweiterungen.

Ein vorhandener SQL-Quellpfad oder ein grüner statischer Vertrag ersetzt keinen dokumentierten Laufzeitnachweis.

## Aktueller Produktstand

Der portable Frameworkkern ist für SQL Server 2019, 2022 und 2025 implementiert. Die allgemeine Lab-Provisionierung und deren Lifecycleverantwortung liegen in `gecompat/SQL_Server_Lab`. SQL Server Analyze enthält weiterhin Frameworkcode, Dokumentation, analyserspezifische Szenarien und die benutzerorientierte Beispielsteuerung.

Die kanonische Release-Evidenz umfasst alle 17 P0-, 40 P1- und 124 P2-Fälle. Die abgeschlossene P0-, P1- und P2-Special-Case-Matrix bleibt Bestandteil des bestätigten Produktstands.

### Abgeschlossen – SQL25-005

`USP_QueryStoreReplicaAnalysis` und der Query-Store-Orchestrator trennen SQL-Server-2025-Runtime-, Wait- und Plan-Forcing-Evidenz nach beobachteter Replica-Rolle. SQL Server 2019 und 2022 liefern versionssicher `UNAVAILABLE_VERSION`.

`ANALYZE-LAB-001` ist für den definierten Sieben-Beispiele-Umfang abgeschlossen. Die sechs zusätzlich katalogisierten Beispiele sind dokumentiert, über den gemeinsamen Interactive-/Verify-Runner auswählbar und auf SQL Server 2025 mit dem primären Docker-Provider runtimegeprüft.

Das registrierte Intake-Arbeitselement `WI-0010` hält in der neuen [Diagnoseabdeckung und Gap-Intake](../Research/SQL_Server_Diagnostic_Coverage_Landscape.md) darüber hinaus 106 implementierte, partielle, geplante, externe oder bewusst ausgeschlossene Themen fest. Es ändert die folgende ausführbare Reihenfolge nicht. Neue Kandidaten erhalten erst nach dem Reifeabschluss und einem eigenen Dossier eine Registryreferenz.

Alle 104 Procedure-Seiten besitzen den Status `DEEP_REVIEWED` nach Reviewvertrag 3. Dieser Dokumentationsanteil des Reifeabschlusses ist erledigt und ersetzt keine noch offene Laufzeitevidenz.

## Nächste ausführbare Welle: Reifeabschluss

Die nächste Welle erweitert keine öffentliche Diagnosefläche. Sie schließt die bereits implementierten Teilfunktionen und zugehörigen Reifeverträge ab.

1. `OPS-005` erhält die noch fehlenden Drei-Versionen-, Berechtigungs-, Timeout- und kontrollierten Remote-Testnachweise. Der Defaultpfad führt weiterhin keinen Remotezugriff aus.
2. `OPS-006` erhält portable, featuregebundene, nicht unterstützte, unberechtigte und versionsübergreifende Evidenz.
3. `OPS-008` erhält Leer-, Retention-, Wachstum-, Berechtigungs- und Begrenzungsfälle für die sichtbaren `msdb`-Historien.
4. `OPS-007` und `OPS-009` folgen als kleinere, getrennt validierbare Slices.
5. `COLL-001` setzt die begonnene objektbezogene Härtung fort. Die fünf OPS-Objekte, die Child-JSON-Aggregation von `USP_CurrentOverview` und der TABLE-Zielvertrag bilden den ersten statisch sowie auf der garantierten Collation nativ abgesicherten Slice. Gemischte Server-, `tempdb`-, Framework- und Ziel-Collations bleiben offen.

## Exit-Kriterien

Die Welle ist abgeschlossen, wenn:

- vorhandener und offener Produktumfang in den kanonischen Statusquellen übereinstimmen;
- die vorgesehenen positiven, leeren, eingeschränkten und fehlerisolierten Fälle tatsächlich ausgeführt wurden;
- betroffene Procedure-Seiten den dokumentierten Reviewstatus inhaltlich erfüllen;
- keine allgemeine Lab-Verantwortung in dieses Repository zurückverlagert wurde;
- die impact-basierten statischen und funktionalen Gates erfolgreich sind.

Die SQL-Server-2025-Erweiterungen `WI-0002` bis `WI-0007` beginnen erst, wenn der Reifeabschluss einschließlich `COLL-001` keine ungeklärte gemeinsame Vertragsabweichung hinterlässt.

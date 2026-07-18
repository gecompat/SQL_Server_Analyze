# Bekannte Restpunkte

Stand: 2026-07-18

Die Version `1.1.0-special.9` besitzt für Commit `35cedea80cde7161569900d4aaeda6884a4cdd56` grüne Actions-Gates auf SQL Server 2019, 2022 und 2025. Die Evidence deckt den synthetischen Linux-Leerdatenbank-, Installer-, 13-Suite- und Berechtigungsscope ab; verbleibende `NOT_EXECUTED`-Zeilen sind Planungs- oder manuelle Positivfälle und kein Testergebnis.

Verbleibende Repository- und Evidenzpunkte:

- `RQ-001`: Datenschutzvertrag und dokumentierter Einzel-Audit sind vorhanden, aber aus dem Repository ist noch kein reproduzierbarer Repository- und ZIP-Scanner mit synthetischen Blockier-Fixtures und CI-Gate ausführbar. SC-001 bleibt bis zu dieser Operationalisierung offen; ein automatischer Treffer ersetzt die vorgeschriebene kontextbezogene Review und Rückfrage nicht.
- `RQ-002`: Die Evidence-Matrizen nennen noch Commit `35cedea80cde7161569900d4aaeda6884a4cdd56`. Der neuere funktional getestete Code-Commit `8ec618231709d86540d605995fed329ad06c9808` besitzt ebenfalls grüne Dokumentations- und SQL-Server-2019-/2022-/2025-Läufe einschließlich der neuen Regex-Matrix, ist aber noch nicht in allen Evidence-Dateien nachgeführt. Der Release-Audit nennt außerdem noch 300 Repository- und 126 SQL-Dateien statt des aktuellen Bestands von 304 versionierten und 127 SQL-Dateien.
- `RQ-003`: Die SQL-Server-2025-Regex-Matrix gibt `ExecutedContracts=7` aus, während die zugehörige Qualitätsdokumentation zehn Laufzeitverträge aufführt. Die statische Regex-Prädikatprüfung arbeitet außerdem zeilenweise und deckt mehrzeilige Fehlformen nicht zuverlässig ab.
- `RQ-004`: Die Linux-Gates verwenden bewegliche `2019-latest`-, `2022-latest`- und `2025-latest`-Images. Die technischen `ProductVersion`-Felder und Image-Digests fehlen in der maschinenlesbaren Evidence.
- `RQ-005`: Die verbindliche einzeilige Commit Message wird nicht automatisch geprüft; mehrere jüngere Commit-Nachrichten enthalten zusätzliche Textzeilen. Künftig ist dies per Liefergate zu verhindern, ohne die Historie umzuschreiben.
- `RQ-006`: 332 importierte Wait-Beschreibungen tragen weiterhin `DescriptionQuality = IMPORTED_REVIEW_REQUIRED` und benötigen schrittweise fachliche Kuratierung.

Verbleibende fachliche beziehungsweise betriebliche Punkte:

- Die automatisierten Linux-Leerzustands-/Vertragspfade ersetzen keine Feature-Positiv-, Grenzwert-, Last-, Windows- oder Azure-MI-Tests.
- Bei jeder weiteren Zielversion oder abweichenden Plattform sind Installer, Smoke Tests, Parametervertrag und `165_Filter_Output_Contract.sql` erneut auszuführen.
- Phase 7 liefert überwiegend Inventar- und Momentaufnahmen; zeitbasierte CPU-, NUMA- und Memory-Trends sind bewusst nicht Bestandteil dieses Ad-hoc-Pakets.
- DWH-/ETL-spezifische Adapter bleiben zurückgestellt.
- Die optionale Ausgabe des tatsächlichen Ausführungsplans bleibt bewusst außerhalb des Defaultpfads; Plan-XML kann groß und die Abfrage des Plans ressourcenintensiv sein.
- `USP_InMemoryOltpAnalysis` ist eine Momentaufnahme. Der Hashkettenpfad kann vollständige Tabellen scannen und bleibt opt-in; Defaultpool-Werte sind nicht datenbankgenau zurechenbar, Checkpointzustände und Transaktionsmengen benötigen Verlaufskorrelation.
- `USP_TemporalAnalysis` prüft keine Current- oder History-Zeilen. Periodenüberlappungen, tatsächlicher Cleanup-Fortschritt und nach `SYSTEM_VERSIONING=OFF` getrennte Tabellenpaare bleiben ohne zusätzliche, bewusst nicht ausgeführte Daten- oder Historienevidenz unbewiesen.
- `USP_ServiceBrokerAnalysis` liest keine Queue-Nutzdaten oder Nachrichtenkörper. Eine deaktivierte Queue, alte Transmission-Einträge, approximative Queue-Zeilen und Broker-DMV-Zustände beweisen weder eine Poison Message noch Routing-, Aktivierungs- oder Verarbeitungsursache; Laufzeitverlauf und kontrollierte externe Evidenz bleiben erforderlich.
- `USP_FullTextAnalysis` liest keine indizierten Inhalte, Keywords, Stopwords, Schlüsselwerte, Crawl-Logs oder Pfade. Population-, Batch- und FDHost-DMVs sind Momentaufnahmen; Alter, Fragmentzahl und Poolgröße benötigen Zeitreihe, Workload- und Suchlatenzkontext. Geschützte Laufzeitlogs dürfen nicht in Repositoryartefakte übernommen werden.
- `USP_DataCaptureDeepAnalysis` kann CT-Synchronisationsverlust nur für einen explizit gelieferten Consumer-Wasserstand bewerten. CDC-DMVs und Agenthistorien sind begrenzt und reset-/cleanup-abhängig. Remote Distributor, Pull-/Peer-to-Peer-Topologien und Subscriber-Netzpfade können außerhalb der lokalen Sicht liegen; eine Evidenzlücke ist kein gesunder Befund.
- `USP_EncryptionAnalysis` beweist weder den Besitz externer Schlüsselkopien noch Restorefähigkeit. TDE und explizite Backupverschlüsselung bleiben getrennt; Zertifikatablauf und lokaler Exportzeitpunkt sind Lebenszykluskontext.
- `USP_MaintenanceOperations` ist eine Momentaufnahme. Pause, Laufdauer, PVS-Größe und Jobüberlappung benötigen Betriebs- und Verlaufskontext; das Modul nimmt niemals selbst eine Wartungsänderung vor.
- SC-023 benötigt vor Persistenz ausdrückliche Retention-, Feld-, Größen-, Lösch-, Speicher- und Rechteentscheidungen. SC-024 und SC-025 benötigen externe autorisierte Komponenten beziehungsweise Ziele.

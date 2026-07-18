# Bekannte Restpunkte

Stand: 2026-07-18

Der frühere Stand `1.1.0-special.6` enthält ein reproduzierbares SQL-Server-2022-Linux-Release-Gate und dokumentiert einen erfolgreichen Gesamtinstaller- und Zwölf-Suite-Lauf auf einer synthetischen Testdatenbank. Dieser Nachweis umfasst `SC-018` und `SC-019` noch nicht. Die Version `1.1.0-special.8` ist deshalb weiterhin nicht durch dokumentierte Zielmatrixläufe als Laufzeit-Release nachgewiesen; SQL Server 2019 und 2025 bleiben ebenfalls offen.

Verbleibende fachliche beziehungsweise betriebliche Punkte:

- Die Zielumgebungen sind maschinenlesbar definiert; die verbindlichen Matrixzeilen einschließlich `SC-018` und `SC-019` besitzen noch keine vollständige Ausführungsevidenz und stehen auf `NOT_EXECUTED`.
- Bei jeder weiteren Zielversion oder abweichenden Plattform sind Installer, Smoke Tests, Parametervertrag und `165_Filter_Output_Contract.sql` erneut auszuführen.
- Importierte Wait-Beschreibungen mit `DescriptionQuality = IMPORTED_REVIEW_REQUIRED` sollten sukzessive fachlich kuratiert werden.
- Phase 7 liefert überwiegend Inventar- und Momentaufnahmen; zeitbasierte CPU-, NUMA- und Memory-Trends sind bewusst nicht Bestandteil dieses Ad-hoc-Pakets.
- DWH-/ETL-spezifische Adapter bleiben zurückgestellt.
- Die optionale Ausgabe des tatsächlichen Ausführungsplans bleibt bewusst außerhalb des Defaultpfads; Plan-XML kann groß und die Abfrage des Plans ressourcenintensiv sein.
- `USP_InMemoryOltpAnalysis` ist eine Momentaufnahme. Der Hashkettenpfad kann vollständige Tabellen scannen und bleibt opt-in; Defaultpool-Werte sind nicht datenbankgenau zurechenbar, Checkpointzustände und Transaktionsmengen benötigen Verlaufskorrelation.
- `USP_TemporalAnalysis` prüft keine Current- oder History-Zeilen. Periodenüberlappungen, tatsächlicher Cleanup-Fortschritt und nach `SYSTEM_VERSIONING=OFF` getrennte Tabellenpaare bleiben ohne zusätzliche, bewusst nicht ausgeführte Daten- oder Historienevidenz unbewiesen.
- `USP_ServiceBrokerAnalysis` liest keine Queue-Nutzdaten oder Nachrichtenkörper. Eine deaktivierte Queue, alte Transmission-Einträge, approximative Queue-Zeilen und Broker-DMV-Zustände beweisen weder eine Poison Message noch Routing-, Aktivierungs- oder Verarbeitungsursache; Laufzeitverlauf und kontrollierte externe Evidenz bleiben erforderlich.
- `USP_FullTextAnalysis` liest keine indizierten Inhalte, Keywords, Stopwords, Schlüsselwerte, Crawl-Logs oder Pfade. Population-, Batch- und FDHost-DMVs sind Momentaufnahmen; Alter, Fragmentzahl und Poolgröße benötigen Zeitreihe, Workload- und Suchlatenzkontext. Geschützte Laufzeitlogs dürfen nicht in Repositoryartefakte übernommen werden.
- `USP_DataCaptureDeepAnalysis` kann CT-Synchronisationsverlust nur für einen explizit gelieferten Consumer-Wasserstand bewerten. CDC-DMVs und Agenthistorien sind begrenzt und reset-/cleanup-abhängig. Remote Distributor, Pull-/Peer-to-Peer-Topologien und Subscriber-Netzpfade können außerhalb der lokalen Sicht liegen; eine Evidenzlücke ist kein gesunder Befund.

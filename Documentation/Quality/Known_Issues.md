# Bekannte Restpunkte

Stand: 2026-07-18

Die Version `1.1.0-special.9` besitzt für Commit `ffb95bd57c8e08300410ad268a92cc5379ee45f7` grüne Actions-Gates auf SQL Server 2019, 2022 und 2025. Die Evidence deckt Installer, 14 Suiten, die versionsspezifischen Berechtigungsmatrizen und 16 automatisierte P0-Fälle auf disposable synthetischen Linux-Zielen ab; verbleibende `NOT_EXECUTED`-Zeilen sind kein Testergebnis.

Verbleibende Repository- und Evidenzpunkte:

- Keine offenen RQ-Punkte. `RQ-006` ist mit 347 primärquellengeprüften, eindeutigen Wait Types und einem statischen Katalogvertrag abgeschlossen.
- Evidenzhinweis: Der nachfolgende direkte Dokumentationscommit `71f70830f4d9b8c6a0531c5eaf4116bd3806ac9d` enthielt zusätzlich zum Betreff einen Nachrichtentext und wurde vom Commit-Message-Gate erwartungsgemäß abgelehnt. Gemäß `RQ-005` wird bestehende Historie nicht umgeschrieben; er ist nicht der funktional ausgewiesene Release-Evidenzcommit.

Verbleibende fachliche beziehungsweise betriebliche Punkte:

- `PC-RESET` ist über den gemeinsam genutzten reinen Rechenpfad deterministisch automatisiert; die commitbezogenen SQL-Server-2019-/2022-/2025-Nachweise stehen noch aus.
- Die automatisierten synthetischen Linux-Vertragspfade ersetzen keine weiteren Feature-Positiv-, Grenzwert-, Last-, Windows- oder Azure-MI-Tests.
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

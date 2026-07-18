# Nächste Arbeitsschritte

Stand: 2026-07-18

Der Stand `1.1.0-special.9` schließt die lokalen P2-Module mit Verschlüsselungslebenszyklus und Wartungsoperationen. Drei GitHub-Actions-Gates installieren und führen denselben 13-Suite-Vertrag auf SQL Server 2019, 2022 und 2025 mit Compatibility Level 150, 160 und 170 aus. `NOT_EXECUTED` in manuellen Positiv-, Grenzwert- oder Lastfällen bleibt weiterhin kein Testnachweis.

Die vollständige Herleitung, Priorisierung und die False-Positive-Grenzen stehen in `Documentation/Research/Special_Case_Gap_Analysis.md`. Der maschinenlesbare Umsetzungsbacklog steht in `Metadata/Quality/Special_Case_Gap_Backlog.csv`.

Abgeschlossen:

1. Repository-Datenschutzvertrag und Liefergate dokumentiert.
2. Dokumentierbare Ziel-Testmatrix angelegt.
3. P0: Integrität, Kapazität, Performance Counter und kritische Engine-Ereignisse implementiert.
4. P1 vollständig: IQP, interne Contention, Buffer Pool, Backupketten, Schema-/Designkorrektheit, begrenzte Statistikverteilung, tiefe Availability-Evidenz, Agent-/Alert-Monitoring und zuletzt normalisierte Findings implementiert.
5. Installer, Orchestratoren, Inventare, Hilfe, Beispiele, Referenz und statische Verträge erweitert.
6. Statischen Release-Audit unter `Metadata/Quality/Special_Case_Release_Audit.json` dokumentiert und anschließend um commitbezogene Actions-Evidenz erweitert.
7. Reproduzierbaren SQLCMD-Runner für vier verbindliche Integrationsverträge und acht Bereichs-Smoke-Tests, eine rein synthetische Suite-Evidenzvorlage sowie ein Test-Runbook ergänzt.
8. P2 mit `USP_SpecialFeatureInventory` begonnen: sichtbare Nutzung beziehungsweise reine Konfiguration wird aggregiert, ohne daraus einen Gesundheitsbefund abzuleiten.
9. SC-015 mit `USP_InMemoryOltpAnalysis` umgesetzt: isolierte XTP-Quellen, opt-in Hashketten und explizite Evidenzgrenzen ohne automatische DDL.
10. SC-016 mit `USP_TemporalAnalysis` umgesetzt: sichtbare Current-/History-Zuordnung, Retention-Konfiguration, approximative Kapazität und Perioden-Indexbaseline ohne Zugriff auf Current-/History-Zeilen.
11. SC-017 mit `USP_ServiceBrokerAnalysis` umgesetzt: Queue-Schalter und approximative Kapazität, Aktivierungs-DMVs, gruppierte Transmission- und Conversation-Evidenz ohne Queue-Nutzdaten oder Nachrichtenkörper.
12. SC-018 mit `USP_FullTextAnalysis` umgesetzt: sichtbare Kataloge und Indizes, isolierte Population-, Batch-, Fragment-, Semantik-, Memory-Pool- und FDHost-Evidenz ohne Inhalte, Schlüsselwerte, Crawl-Logs, Pfade oder DDL.
13. SC-019 mit `USP_DataCaptureDeepAnalysis` umgesetzt: Consumer-spezifische CT-Version, isolierte CDC-Scan-/Fehler-/Job-/Cleanup-Evidenz und aggregierte lokale Replikationsagenten ohne Change-Zeilen, Commands, Credentials oder DDL.
14. SC-020 mit `USP_EncryptionAnalysis` umgesetzt: TDE, sichtbarer Schutzobjekt-Lebenszyklus, getrennte explizite Backupverschlüsselung und aggregierte Always-Encrypted-/Ledger-Evidenz ohne Schlüssel- oder Medieninhalte.
15. SC-022 mit `USP_MaintenanceOperations` umgesetzt: pausierte/aktive Wartung, ADR/PVS und explizit gefilterte Jobaktivität ohne SQL-/Jobinhalte und ohne operative Änderung.
16. Versionsharte Actions-Gates für SQL Server 2019, 2022 und 2025 sowie ein echter P2-Laufzeitvertrag ergänzt.
17. SC-023 bis SC-025 bis zur sicheren Repositorygrenze konkretisiert: Entscheidungs- und Schnittstellenverträge sowie externer Restore-/Host-Runbook, aber keine ungeklärte Persistenz oder Infrastruktur.
18. Commit `35cedea80cde7161569900d4aaeda6884a4cdd56` mit grünen Dokumentations- und SQL-Server-2019-/2022-/2025-Actions-Gates verifiziert und in der Ziel-, Suite- und Spezialfallmatrix nachgewiesen.

Nächste Freigabeschritte:

1. Pro manuellem Ziel `Code/Tests/Run_Release_Gate.sql` im SQLCMD-Modus aus `Code/Tests` ausführen; der Runner startet `110`, `163`, `165`, `167` und `168` in fester Reihenfolge und bricht beim ersten SQL-Fehler ab.
2. Für jedes neue Modul Capability-, Leerzustands-, Positiv-, Grenzwert-, Last-, Reset- und Berechtigungsfälle dokumentieren; reale Namen oder Strukturen nicht in die Nachweise übernehmen.
3. Kostenintensive opt-in Pfade separat testen: Page Details, Event-XML, Contention-Sample, Buffer-Pool-Verteilung, Schema-Design, Statistikverteilung, In-Memory-Hashketten und breite Cross-Database-Auswahl.
4. Erst nach vollständiger, anonym dokumentierter Zielmatrix den Stand als Laufzeit-Release freigeben.
5. Vor SC-023 die in `Snapshot_Baseline_Package_Contract.md` markierten Persistenzentscheidungen ausdrücklich freigeben; SC-024 benötigt einen externen Komponenten- und Isolationentscheid, SC-025 eine autorisierte isolierte Ausführungsumgebung.

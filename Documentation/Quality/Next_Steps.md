# Nächste Arbeitsschritte

Stand: 2026-07-18

Der Stand `1.1.0-special.9` schließt die lokalen P2-Module mit Verschlüsselungslebenszyklus und Wartungsoperationen. Der vierzehnteilige Release-Gate-Vertrag einschließlich aller 17 P0-Fälle ist auf SQL Server 2019, 2022 und 2025 mit Compatibility Level 150, 160 und 170 grün. `NOT_EXECUTED` ist weiterhin kein Testnachweis.

Die vollständige Herleitung, Priorisierung und die False-Positive-Grenzen stehen in `Documentation/Research/Special_Case_Gap_Analysis.md`. Der maschinenlesbare Umsetzungsbacklog steht in `Metadata/Quality/Special_Case_Gap_Backlog.csv`. Die einzelnen Spezialfalltests und Zielsysteme stehen in `Metadata/Quality/Special_Case_Test_Cases.csv` und `Metadata/Quality/Test_Matrix.csv`.

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
18. Commit `8ec618231709d86540d605995fed329ad06c9808` mit grünen Dokumentations- und SQL-Server-2019-/2022-/2025-Actions-Gates verifiziert und in der Ziel-, Suite- und Spezialfallmatrix nachgewiesen.
19. `RQ-001` / SC-001 operationalisiert: reproduzierbarer Repository- und ZIP-Scanner, generische Positiv- und Blockier-Selbsttests, pfad- und hashgebundene Ausnahmeprüfung sowie ein GitHub-Actions-Gate ergänzt. Trefferberichte geben ausschließlich Scope, Regelcode, Pfad und Anzahl aus; uneindeutige Funde bleiben eine manuelle Rückfrage- und Abbruchentscheidung.
20. `RQ-002` abgeschlossen: Ziel-, Suite-, Spezialfall- und Release-Audit-Evidenz auf den funktional getesteten Commit `8ec618231709d86540d605995fed329ad06c9808` und dessen grüne 2019-/2022-/2025-/Dokumentationsläufe synchronisiert, die Regex-Matrix als eigene Suite aufgenommen und den damaligen Bestand von 309 versionierten beziehungsweise 127 SQL-Dateien festgehalten.
21. `RQ-003` abgeschlossen: die SQL-Server-2025-Regex-Matrix meldet die zehn dokumentierten Laufzeitverträge; ein eigenständiger, selbstgetesteter Validator erkennt direkte, verschachtelte und mehrzeilige numerische Prädikatvergleiche und berichtet ohne Quellzeileninhalt.
22. `RQ-004` abgeschlossen: alle drei Linux-Gates lösen den beweglichen Pull-Tag in einen validierten `repo@sha256`-Digest auf, starten exakt diesen Digest und erfassen die technische `ProductVersion`; die grünen Läufe und vollständigen generischen Werte stehen in der maschinenlesbaren Zielmatrix.
23. `RQ-005` abgeschlossen: ein selbstgetestetes Pull-Request-, Main-Push- und manuelles Gate erzwingt exakt einzeilige, nicht leere UTF-8-Commit-Messages ausschließlich für neu eingebrachte Commits; der erste echte Push-Lauf ist grün und historische Nachrichten bleiben unverändert.
24. `RQ-006` abgeschlossen: alle 332 offenen Wait-Katalogzeilen wurden gegen den unveränderlich referenzierten Microsoft-Dokumentstand geprüft; 318 Namen blieben bestehen, vier wurden korrigiert und zehn unbelegte Alt-/Fehleinträge entfernt. Ein selbstgetesteter Offline-Vertrag bindet die 347 finalen eindeutigen Namen, Quellenstatus und Entscheidungsevidenz; Commit `ee244f05b4e299a9274f94b68f326a1b23ba981f` ist auf SQL Server 2019, 2022 und 2025 sowie in Dokumentations-, Datenschutz- und Commit-Gate grün.
25. P0-Automatisierung für 16 Fälle abgeschlossen und nachgewiesen: `169_P0_Runtime_Contract.sql` bildet im Evidenzcommit 14 Positiv-, Leer- und Grenzfälle mit rücksetzbaren synthetischen Fixtures ab. `INT-DENIED` und `CAP-DENIED` laufen zusätzlich unter einem tatsächlich eingeschränkten synthetischen Serverlogin in den versionsspezifischen Berechtigungsmatrizen. Commit `ffb95bd57c8e08300410ad268a92cc5379ee45f7` ist dafür auf SQL Server 2019, 2022 und 2025 grün; `PC-RESET` war in diesem Evidenzstand noch offen.
26. `PC-RESET` ohne unfortsetzbaren Serverneustart automatisiert und nachgewiesen: `monitor.TVF_InterpretPerformanceCounter` ist der gemeinsame reine Rechenpfad der Procedure und des Resettests. Ein fallender synthetischer Counter unterdrückt die Rate und meldet `COUNTER_RESET_DURING_SAMPLE`; Commit `7e3ba1a4e2fa79761c2daf24bee23dd73feed297` ist auf SQL Server 2019, 2022 und 2025 grün.

Unmittelbar offene Repository-Qualitätsaufgaben:

- Keine. `RQ-001` bis `RQ-006` sind im Repository umgesetzt; noch ausstehende Laufzeitnachweise stehen ausschließlich in der nachfolgenden Testreihenfolge.

Nächste Freigabeschritte:

1. Pro manuellem Ziel `Code/Tests/Run_Release_Gate.sql` im SQLCMD-Modus aus `Code/Tests` ausführen; der Runner startet `110`, `163`, `165`, `167`, `168` und `169` sowie acht Bereichssuiten in fester Reihenfolge und bricht beim ersten SQL-Fehler ab.
2. Die 155 noch offenen Spezialfälle in der festgelegten Reihenfolge abarbeiten: zuerst 40 P1-, anschließend 115 P2-Fälle. Capability-, Leerzustands-, Positiv-, Grenzwert-, Last-, Reset- und Berechtigungsfälle bleiben getrennte Nachweise; reale Namen oder Strukturen werden nicht übernommen.
3. Kostenintensive opt-in Pfade separat testen: Page Details, Event-XML, Contention-Sample, Buffer-Pool-Verteilung, Schema-Design, Statistikverteilung, In-Memory-Hashketten und breite Cross-Database-Auswahl.
4. Erst nach vollständiger, anonym dokumentierter Zielmatrix den Stand als Laufzeit-Release freigeben.
5. Vor SC-023 die in `Snapshot_Baseline_Package_Contract.md` markierten Persistenzentscheidungen ausdrücklich freigeben; SC-024 benötigt einen externen Komponenten- und Isolationentscheid, SC-025 eine autorisierte isolierte Ausführungsumgebung.

# Nächste Arbeitsschritte

Stand: 2026-07-18

Der direkte Vorgängerstand `1.1.0-special.6` dokumentiert einen erfolgreichen Gesamtinstaller- und Zwölf-Suite-Lauf auf einer synthetischen SQL-Server-2022-Linux-Datenbank. `SC-018` war dort noch nicht enthalten. Die neue Version `1.1.0-special.7` ist implementiert und statisch geprüft; ihre verbindlichen Matrixläufe sind noch nicht dokumentiert. `NOT_EXECUTED` in der Testmatrix darf nicht als Testnachweis interpretiert werden.

Die vollständige Herleitung, Priorisierung und die False-Positive-Grenzen stehen in `Documentation/Research/Special_Case_Gap_Analysis.md`. Der maschinenlesbare Umsetzungsbacklog steht in `Metadata/Quality/Special_Case_Gap_Backlog.csv`.

Abgeschlossen:

1. Repository-Datenschutzvertrag und Liefergate dokumentiert.
2. Dokumentierbare Ziel-Testmatrix angelegt.
3. P0: Integrität, Kapazität, Performance Counter und kritische Engine-Ereignisse implementiert.
4. P1 vollständig: IQP, interne Contention, Buffer Pool, Backupketten, Schema-/Designkorrektheit, begrenzte Statistikverteilung, tiefe Availability-Evidenz, Agent-/Alert-Monitoring und zuletzt normalisierte Findings implementiert.
5. Installer, Orchestratoren, Inventare, Hilfe, Beispiele, Referenz und statische Verträge erweitert.
6. Statischen Release-Audit unter `Metadata/Quality/Special_Case_Release_Audit.json` dokumentiert; Laufzeitstatus bleibt `NOT_EXECUTED`.
7. Reproduzierbaren SQLCMD-Runner für vier verbindliche Integrationsverträge und acht Bereichs-Smoke-Tests, eine rein synthetische Suite-Evidenzvorlage sowie ein Test-Runbook ergänzt.
8. P2 mit `USP_SpecialFeatureInventory` begonnen: sichtbare Nutzung beziehungsweise reine Konfiguration wird aggregiert, ohne daraus einen Gesundheitsbefund abzuleiten.
9. SC-015 mit `USP_InMemoryOltpAnalysis` umgesetzt: isolierte XTP-Quellen, opt-in Hashketten und explizite Evidenzgrenzen ohne automatische DDL.
10. SC-016 mit `USP_TemporalAnalysis` umgesetzt: sichtbare Current-/History-Zuordnung, Retention-Konfiguration, approximative Kapazität und Perioden-Indexbaseline ohne Zugriff auf Current-/History-Zeilen.
11. SC-017 mit `USP_ServiceBrokerAnalysis` umgesetzt: Queue-Schalter und approximative Kapazität, Aktivierungs-DMVs, gruppierte Transmission- und Conversation-Evidenz ohne Queue-Nutzdaten oder Nachrichtenkörper.
12. SC-018 mit `USP_FullTextAnalysis` umgesetzt: sichtbare Kataloge und Indizes, isolierte Population-, Batch-, Fragment-, Semantik-, Memory-Pool- und FDHost-Evidenz ohne Inhalte, Schlüsselwerte, Crawl-Logs, Pfade oder DDL.

Nächste Freigabeschritte:

1. Gesamtinstaller auf SQL Server 2019, 2022 und 2025 gemäß `Test_Matrix.csv` kompilieren und installieren.
2. Pro Ziel `Code/Tests/Run_Release_Gate.sql` im SQLCMD-Modus aus `Code/Tests` ausführen; der Runner startet `110`, `163`, `165` und `167` in fester Reihenfolge und bricht beim ersten SQL-Fehler ab.
3. Für jedes neue Modul Capability-, Leerzustands-, Positiv-, Grenzwert-, Last-, Reset- und Berechtigungsfälle dokumentieren; reale Namen oder Strukturen nicht in die Nachweise übernehmen.
4. Kostenintensive opt-in Pfade separat testen: Page Details, Event-XML, Contention-Sample, Buffer-Pool-Verteilung, Schema-Design, Statistikverteilung, In-Memory-Hashketten und breite Cross-Database-Auswahl.
5. Erst nach vollständiger, anonym dokumentierter Zielmatrix den Stand als Laufzeit-Release freigeben.
6. Die P2-Welle darf statisch weiterentwickelt werden; Laufzeitfreigabe bleibt dennoch blockiert. Als nächste Deep-Dive-Module kommen Change/Replication und Verschlüsselung ausschließlich bei erkannter Nutzung in Betracht.

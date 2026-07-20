# Nächste Arbeitsschritte

Stand: 2026-07-20

Der Stand `1.1.0-special.9` besitzt vollständige grüne Linux-Evidenz für alle 17 P0-, 40 P1- und 124 P2-Fälle. Die 31. Suite ist für Commit `40d54fdc195b5cfa0015e2cbe281da595e427ab0` auf SQL Server 2019, 2022 und 2025 nachgewiesen; die 115 zuvor offenen P2-Zeilen sind abgeschlossen.

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
27. Erste P1-Gruppe abgeschlossen: `170_P1_IQP_Runtime_Contract.sql` prüft SQL-Server-2019-Abgrenzung, PSP auf Compatibility Level 160, OPPO auf Level 170 und Query Store OFF mit rücksetzbaren Datenbankoptionen. Commit `0efeb1877ffa6b31fc8deb714ac7659b40db7cd6` ist auf allen drei SQL-Server-Versionen grün.
28. Zweite P1-Gruppe abgeschlossen: `171_P1_Contention_Runtime_Contract.sql` prüft Delta, kumulativen Modus, deterministischen Counterreset über denselben reinen Rechenpfad wie die Procedure und den begrenzten opt-in-Page-Detail-Pfad. Commit `e26f246e7b9e21b2d882ac69feaa32fb3f5f36c9` ist auf allen drei SQL-Server-Versionen grün; ein künstlicher aktueller PAGELATCH-Wait wurde nicht erzwungen.
29. Dritte P1-Gruppe abgeschlossen: `172_P1_Memory_Runtime_Contract.sql` prüft den leichten Defaultpfad, bedingte Low-Memory-Findings, einen vollständig strukturierten Resource-Semaphore-Snapshot und den ausdrücklich aktivierten, auf eine Ausgabezeile begrenzten Buffer-Descriptor-Scan. Commit `d9d7c5bb4ffb5b9b408c1781718364d5c7ac89a8` ist auf allen drei SQL-Server-Versionen grün; künstlicher Speicherdruck und künstliche Grant-Waiter wurden nicht erzeugt.
30. Vierte P1-Gruppe abgeschlossen: `173_P1_Backup_Runtime_Contract.sql` prüft fehlende Full-Evidenz, eine nicht mehr zur neuesten Fullbasis passende Differentialzeile, eine kontrolliert sichtbare Logkettenlücke und fehlende Restorehistorie. Die Suite verwendet eine generisch benannte Datei im Default-Backupverzeichnis des disposable Targets, bereinigt ihre synthetische `msdb`-Historie, stellt das Recovery Model wieder her und führt keinen Restore aus. Commit `f3d9c014adb3227ab39e21e16052dca7285a6a87` ist auf allen drei SQL-Server-Versionen grün.
31. Fünfte P1-Gruppe abgeschlossen: `174_P1_Schema_Runtime_Contract.sql` prüft nicht vertrauenswürdige Constraints, fehlende FK-Stützindizes, exakt gleiche Indexdefinitionen und einen Identity-Typwertebereich oberhalb der Schwelle. Alle generischen DDL-Fixtures werden im Erfolgs- und Fehlerpfad ausdrücklich entfernt. Commit `c405946d7806472f42cfc38430d5ada33620780c` ist auf allen drei SQL-Server-Versionen grün.
32. Sechste P1-Gruppe abgeschlossen: `175_P1_Statistics_Runtime_Contract.sql` prüft gleichmäßige, dominante und Tail-konzentrierte Histogramme, hohe Modification Counter, gefilterte und inkrementelle Statistiken, die Kandidatengrenze sowie einen tatsächlich verweigerten `CATALOG_DEEP`-Pfad. Die Umsetzung hat dabei eine Temp-Tabellen-Kollision, einen unzulässigen Histogramm-Query-Hint und eine fehlende Partial-Markierung im Restricted-Pfad offengelegt und korrigiert. Commit `f4bf1d4333e7f4a38814dea72a0799ca1d949364` ist auf SQL Server 2019, 2022 und 2025 grün.

33. Siebte P1-Gruppe abgeschlossen: `176_P1_Availability_Runtime_Contract.sql` prüft HADR-Abwesenheit sowie Suspend-, Queue- und Seedingklassifikation über die produktiv verwendeten reinen Interpretationsfunktionen, ohne Failover oder Konfigurationsänderung.
34. Achte P1-Gruppe abgeschlossen: `177_P1_Agent_Runtime_Contract.sql` prüft fehlende kritische Alerts sowie Routing-, Job- und Database-Mail-Klassifikation ohne Änderung von `msdb`- oder Agentobjekten.
35. Neunte P1-Gruppe abgeschlossen: `178_P1_Diagnostic_Findings_Runtime_Contract.sql` prüft die Feld-Whitelist, partielle Child-Evidenz, deaktivierte teure Defaults, Parent-Reuse, Standalone-Frischlesung und das vollständig rückgesetzte Compatibility-Gate.

36. Erste P2-Gruppe abgeschlossen: Suite `179` prüft 21 Feature-Inventurfälle mit echten portablen Katalogfixtures und version-adaptiven Verträgen.
37. Zweite P2-Gruppe abgeschlossen: Suite `180` prüft 14 XTP-Fälle ohne erzwungenen vollständigen Hash-DMV-Scan.
38. Dritte P2-Gruppe abgeschlossen: Suite `181` prüft 13 Temporal-Fälle ohne Current-/History-Nutzdaten.
39. Vierte P2-Gruppe abgeschlossen: Suite `182` prüft 15 Service-Broker-Fälle ohne Nachrichtenkörper oder Conversation-Mutation.
40. Fünfte P2-Gruppe abgeschlossen: Suite `183` prüft 16 Full-Text-Verträge ohne nichtportable Full-Text-DDL auf Linux.
41. Sechste P2-Gruppe abgeschlossen: Suite `184` prüft 25 Change-Tracking-, CDC- und Replikationsverträge ohne Change-Zeilen oder Commands.
42. Siebte P2-Gruppe abgeschlossen: Suite `185` prüft sieben zuvor offene Encryption-Verträge ohne Schlüssel-, Medien- oder Kontoinhalte.
43. Achte P2-Gruppe abgeschlossen: Suite `186` prüft vier zuvor offene Maintenance-Verträge ohne RESUME, ABORT, KILL oder Jobmutation.
44. Die technische Deep-Analysis-Dokumentation ist 84/84 integriert: jede öffentliche Procedure-Seite besitzt Leitfrage, Enginehintergrund, Datenkette, Zeit-/Scope-Modell, Gegenprobe, Fehlinterpretationsgrenze und Folgeanalyse; das gemeinsame Execution-/Evidenzmodell ist kanonisch zentralisiert.
45. Die neun durch das vollständige Actions-Gate erledigten Backlogzeilen SC-002 bis SC-010 sind auf `IMPLEMENTED_ACTIONS_GATE` abgeglichen. Ein versehentlich versioniertes Python-Cacheartefakt wurde entfernt und durch Repository-Ignore-Regeln gegen Wiederholung abgesichert.
46. Die Datenschutz-Allowlist enthält nun auch den bereits vorhandenen, zur Laufzeit synthetisch erzeugten Credential-Pfad des Statistics-Evidence-Workflows. Die Ausnahme ist wie alle übrigen Einträge an Regel, Pfad und Match-Hash gebunden.
47. Das Deep-Analysis-Authoring-Archiv ist konsolidiert: historische Roadmaps sind abgeschlossen markiert, kanonische Draft-Verweise entfernt, eine Versions-/Primärquellenmatrix ergänzt und dauerhaft verlorene externe Links werden automatisiert erkannt.
48. Der Wait-Type-Katalog beantwortet für alle 347 Framework-Waits Einordnung, Ursachenhypothesen, Wirkung, Gegenbeweise, Minderung, Queranalysen und Messgrenzen. Mindestens vier typisierte, aussagebezogene Quellen je Wait ersetzen den früheren pauschalen Einzelverweis; seltene interne Waits bleiben als begrenzte Evidenz sichtbar.

Unmittelbar offene Repository-Qualitätsaufgaben:

- Keine. `RQ-001` bis `RQ-006` sind im Repository umgesetzt; noch ausstehende Laufzeitnachweise stehen ausschließlich in der nachfolgenden Testreihenfolge.

Nächste Freigabeschritte:

1. Pro weiterem Ziel `Code/Tests/Run_Release_Gate.sql` im SQLCMD-Modus aus `Code/Tests` ausführen; der Runner umfasst 24 Integrationsverträge und acht Bereichssuiten und bricht beim ersten SQL-Fehler ab.
2. Es bestehen keine offenen P0-, P1- oder P2-Zeilen in der Repository-Testmatrix. Als nächste Evidence-Klassen folgen feature-positive Windows-/Azure-MI-Targets, kontrollierte Lastfälle und externe Restore-/Host-Nachweise.
3. Kostenintensive opt-in Pfade separat testen: Page Details, Event-XML, Contention-Sample, Buffer-Pool-Verteilung, Schema-Design, Statistikverteilung, In-Memory-Hashketten und breite Cross-Database-Auswahl.
4. Erst nach vollständiger, anonym dokumentierter Zielmatrix den Stand als Laufzeit-Release freigeben.
5. Der SC-023-Architekturentscheid ist freigegeben und dokumentiert; ein späterer eigener Umsetzungsauftrag beginnt mit einem kleinen vertikalen Sammler. SC-024 benötigt einen externen Komponenten- und Isolationentscheid, SC-025 eine autorisierte isolierte Ausführungsumgebung.

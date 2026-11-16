# Nächste Arbeitsschritte

**Stand:** 16. November 2026  
**Zweck:** aktueller Fortsetzungseinstieg für `gecompat/SQL_Server_Analyze`.

## Aktuelle Orchestrierung

Der neue konkrete Quellenbefund betrifft `USP_BackupChainAnalysis`: `@HistoryDays int = 35` soll Werte von 1 bis 3650 Tagen annehmen, doch NULL passiert bislang den Vergleichsguard. Der vorbereitete Kandidat weist NULL nach Hilfe und TABLE-Preflight, vor Kandidatenauswahl und Backuperhebung als `INVALID_PARAMETER` mit `IsPartial = 1` und leeren Fachmengen ab. Der gültige Zeitfenstervertrag, der jüngste nicht-copy-only Full außerhalb des Fensters, die zeitlich unbeschränkte optionale Restorehistory-Auswertung und `@MaxZeilen = NULL` bleiben erhalten. Der unabhängige Review der Quelle, des betroffenen Guide-Parametertexts und der Fixture-Ergänzung bestand. Die Fixture behält vier positive Fälle mit zwei eigenen Datenbanken, drei Backupsets und Cleanup-Pfaden; genau ein isolierter NULL-Negativfall ist vorbereitet. Der kanonische Generatorlauf [43836185847](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43836185847), Job 133193274189, Pushversuch 1, bestand. Die tatsächliche OPS-Kopie `038b603f8a9ab4590affe441057b7a764626992a` umfasst 6.740.414 Bytes, das Envelope `2332f02c6de398a6ffdd3fff34ac45561b886e34` 1.711.310 Bytes. Root und unabhängiger Reviewer prüften beide tatsächlichen Artefakte vollständig mit UTF-8-/Git-SHA-Bindung, ganzer Source100-Modulsubstitution, Rücksubstitution und unverändertem Rest. Der Helper-Restore `fb12d869315f06ffc6274390abd295c5de583ede` führte den ursprünglichen Baum `4df10207a1a5d94703a49257d1e24670b0211664` zurück; für das Restore lief kein Workflow. Der erste Head-Dokumentationslauf [43837048174](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43837048174), Job 133196174462, scheiterte an der 950-Regel: Die neue native NULL-Fixture erzeugte denselben Temp-Tabellennamen zweimal. Beide kanonischen Installervergleiche mit 584.191 und 6.740.414 Bytes bestanden; die vollständige 80-Validator-Suite bestand nicht, die nachfolgende Linkprüfung wurde nicht ausgeführt. Die Fixture-Korrektur verwendet nur für den neuen NULL-Fall einen eigenen Temp-Tabellennamen. Der erste funktionale Headlauf [43837048116](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43837048116), Runtime 133196324812 und Gate 133203046228, bestand das Deployment; das Impact-Gate scheiterte bei 4 von 12 ausgewählten Verträgen in Fixture 143 mit SQL 2714, Zeile 138, am bereits vorhandenen Objekt `#ExampleBackupChainSummary`. Der Fehler trat vor der Qualifikation der positiven und des neuen NULL-Falls auf; StopSynthetic bestand. Es gab keinen SQL-1222-Befund, keine Observerfehler und keine abgeschnittenen oder unvollständigen Diagnoseprotokolle. Die separate Temp-Zieltabelle des korrigierten Kandidaten adressiert genau die doppelte Fixture-Erzeugung; dessen Head- und Main-Abnahme stehen aus. Er belegt weder RPO noch Wiederherstellbarkeit.

PR #715 schloss den begrenzten Metadatenabgleich auf Main `66442647b2f19dd396069ac692531fd6d0709df9` ab. Die Dokumentationsläufe [43819882693](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43819882693) am Head und [43820324992](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43820324992) auf Main bestanden vier Workflows und vier Checks beziehungsweise drei Workflows und drei Checks. Je 80 Validatoren, der Regelkontextvertrag, 22 statische Deployment-Selbsttests und kanonische Installervergleiche mit 584.191 und 6.740.377 Bytes bestanden; die 25 Regelkontext-Selbsttests waren nicht ausgewählt. Links meldeten 102 beziehungsweise 161 transiente Warnungen. Die getrennten Datenschutzläufe prüften Repository und ZIP mit je 1.325 Dateien ohne Funde. Der Metadatenfilter führte keine funktionalen SQL-, Cleanup-, Stop- oder Generatorläufe aus. Der Repositoryinhaber ergänzte danach ausschließlich die `.gitignore`; dieser Nachtrag ist nicht Teil von PR #715. Der aktuelle Main ist `4d549bdee2ef9164053d4546d7bc97963ebf94cb`.

PR #714 ist auf Main `3ee43df5d30ecc1ab79cd4e833c7058d7676399e` regulär abgeschlossen. Head [43815670678](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43815670678) bestand sechs Workflows und acht Checks; Main [43817390950](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43817390950) bestand fünf Workflows und sieben Checks. Beide funktionalen Gates bestanden Deployment und acht SQL-Verträge auf SQL Server 2025 bei CL170, darunter Fixture 146 mit vier positiven und drei neuen NULL-Negativfällen; `@MaxZeilen = NULL` blieb gültig. StopSynthetic bestand. Die Dokumentationsläufe bestanden je 80 Validatoren, den Regelkontextvertrag, 22 statische Deployment-Selbsttests und kanonische Installervergleiche mit 584.191 und 6.740.377 Bytes; die 25 Regelkontext-Selbsttests waren nicht ausgewählt. Links meldeten 101 beziehungsweise 36 transiente Warnungen. Die Datenschutzläufe prüften Repository und ZIP mit je 1.325 Dateien ohne Funde; Cleanup bestand je 18 synthetische Finally-Szenarien. Weitere Compatibility Levels, Berechtigungs-/Regex-Matrizen, Standalone und native SQL-Server-2019-/2022-Läufe waren nicht ausgewählt. Die Prüfung belegt weder RPO oder Wiederherstellbarkeit noch einen historischen 1222-Ursachenfix.

Der kanonische Generatorlauf [43815074310](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43815074310), Job 133125161816, Pushversuch 1, bestand. Die tatsächliche OPS-Kopie `2fa68fdb7778f804724d04432e8f6f7a9e8e41bf` umfasst 6.740.377 Bytes, das Envelope `851a89232815ca9c8961ed63b7f6412009e207c2` 1.711.296 Bytes. Root und unabhängiger Reviewer prüften beide tatsächlichen Artefakte vollständig mit UTF-8-/Git-SHA-Bindung, ganzer Source050-Modulsubstitution, Rücksubstitution und unverändertem Rest. Der Helper-Restore `483b554e568921f0cf07f38dea7bc7f245cecba0` führte den ursprünglichen Baum `4df10207a1a5d94703a49257d1e24670b0211664` zurück; für das Restore lief kein Workflow.

Die anschließende begrenzte Quellenprüfung von `USP_ResourceGovernorAnalysis`, `USP_LogShippingStatus` und `USP_ReplicationStatus` ergab keinen weiteren Kandidaten dieser NULL-Guard-Klasse: In allen drei Signaturen ist `@MaxZeilen` der einzige numerische Grenzparameter, und NULL oder 0 ist jeweils ausdrücklich als unbegrenzte Ausgabe definiert. Ein weiterer Produktauftrag ist hier nicht ausgewählt; neue Arbeit benötigt einen konkreten Quellenbefund und eine eigene Autorisierung.

PR #713 ist auf Main `34c3607b300199bafd7ab3bd8323f0838ac4eeab` regulär abgeschlossen. Head [43776027315](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43776027315) bestand vier Workflows und vier Checks; Main [43776475755](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43776475755) bestand drei Workflows und drei Checks. Die ausgewählten Dokumentationsläufe bestanden je 80 Validatoren, den Regelkontextvertrag, 22 statische Deployment-Selbsttests und kanonische Installervergleiche mit 584.191 und 6.740.000 Bytes. Die 25 Regelkontext-Selbsttests waren nicht ausgewählt; Links meldeten je 175 transiente Warnungen. Die getrennten Datenschutzläufe prüften Repository und ZIP mit je 1.325 Dateien ohne Funde. Der reine Metadatenfilter löste keine funktionalen SQL-, Cleanup- oder Stop-Workflows aus; Source, Guide, Tests, OPS-Kopie, Scopeindex, Registry und Workflows blieben unverändert. PR #713 glich ausschließlich das [REST-Konfigurationsdossier](../Architecture/External_REST_Endpoint_Configuration_Dossier.md), den Research-Lieferstatus, eine Coverage-Evidenzzeile und diese beiden Fortsetzungsseiten mit der bereits in PR #710 qualifizierten SQL-Server-2025-/CL170-Konfigurationssicht ab. Die 106 Coverage-Zeilen und ihre Statusverteilung blieben erhalten; daraus folgt keine neue native SQL-Laufzeitqualifikation.

PR #712 ist auf Main `4b772ca1cbdbe95d8a58700f912eb9506cd96bc8` regulär abgeschlossen. Head [43772583850](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43772583850) bestand sechs Workflows und acht Checks; Main [43774040289](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43774040289) bestand fünf Workflows und sieben Checks. Beide SQL-Server-2025-/CL170-Gates bestanden Deployment und acht SQL-Verträge einschließlich Fixture 161 mit 29 TABLE-/JSON-Fällen, fünf neuen NULL-Negativfällen, dem weiterhin gültigen `@MaxZeilen = NULL`, sechs RAW-/CONSOLE-Routen und den bestehenden nativen PVS-Grenzen; StopSynthetic bestand. Dokumentation bestand je 80 Validatoren, den Regelkontextvertrag, 22 statische Deployment-Selbsttests und kanonische Installervergleiche mit 584.191 und 6.740.000 Bytes. Die 25 Regelkontext-Selbsttests waren nicht ausgewählt. Links meldeten 71 beziehungsweise 172 transiente Warnungen. Datenschutz prüfte Repository und ZIP mit je 1.325 Dateien ohne Funde; Cleanup bestand je 18 synthetische Finally-Szenarien. Weitere Compatibility Levels, Berechtigungs-/Regex-Matrizen, Standalone und native SQL-Server-2019-/2022-Läufe waren nicht ausgewählt. Echte Wartungsoperationen, Jobs, Hochlast und ein historischer 1222-Ursachenfix wurden nicht qualifiziert. Der kanonische Generatorlauf [43772099993](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43772099993), Job 132990057978, Pushversuch 1, und die unabhängige Prüfung der tatsächlichen OPS-Kopie `cb749aa3710a50493bcf1338ed2b4d33f046d6c0` (6.740.000 Bytes) sowie des Envelopes `6fe1c2936636f914056f978290c181e89257e39a` (1.711.290 Bytes) bestanden; der Helper wurde mit Restore `e3c3829e91e44b3cdcb408f3719e4c5199e9bafe` auf den ursprünglichen Baum `4df10207a1a5d94703a49257d1e24670b0211664` zurückgeführt.

PR #711 ist auf Main `09780258f88b74e4c48b788a67b76c0b97c4a03c` regulär abgeschlossen. Head [43768268749](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43768268749) bestand sechs Workflows und acht Checks; Main [43769590451](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43769590451) bestand fünf Workflows und sieben Checks. Beide funktionalen Gates bestanden Deployment und acht Verträge je auf SQL Server 2025 mit Compatibility Level 150, 160 und 170, einschließlich Fixture 160 mit 26 TABLE-/JSON-Fällen und vier RAW-/CONSOLE-Routen; StopSynthetic bestand. Dokumentation bestand je 80 Validatoren, den Regelkontextvertrag, 22 statische Deployment-Selbsttests und kanonische Installervergleiche mit 584.191 und 6.739.030 Bytes. Die 25 Regelkontext-Selbsttests waren nicht ausgewählt. Links meldeten am Head keine und auf Main 152 transiente Warnungen. Datenschutz prüfte Repository und ZIP mit je 1.325 Dateien ohne Funde; Cleanup bestand je 18 synthetische Finally-Szenarien. Berechtigungs-/Regex-Matrizen, Standalone und native SQL-Server-2019-/2022-Läufe waren nicht ausgewählt. Der native Vertrag belegt die vier neuen NULL-Negativfälle und das weiterhin gültige `@MaxZeilen = NULL`; TDE-, Zertifikats-, Backup- und Restore-Funktionen erhielten keine neue Abnahme. Der kanonische Generatorlauf [43767824614](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43767824614), Job 132976795789, Pushversuch 1, und die unabhängige Prüfung der tatsächlichen OPS-Kopie `808998727f01b7d6b0a14eebb503d34a0af81c64` (6.739.030 Bytes) sowie des Envelopes `c3806a505f7d8c7d799dc00b98b98f708f302e52` (1.711.198 Bytes) bestanden; der Helper wurde mit Restore `f5842d57f3e4edcb084c3d9625637dad515112cb` auf den ursprünglichen Baum `4df10207a1a5d94703a49257d1e24670b0211664` zurückgeführt.

PR #709 schloss den reinen Metadatenabgleich auf Main `44bff18d773dbb822c6ac3ae9ddc3384ac4ef102` ab. Head [43759640602](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43759640602) und Main [43760078637](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43760078637) bestanden die ausgewählten Dokumentations- und Datenschutzprüfungen: je 80 Validatoren, Regelkontextvertrag, 22 statische Deployment-Selbsttests, kanonische Installervergleiche mit 584.191 und 6.738.082 Bytes sowie 1.324 Repository- und ZIP-Dateien ohne Datenschutzfunde. Links meldeten 171 beziehungsweise 150 transiente Warnungen. Die 25 Regelkontext-Selbsttests waren nicht ausgewählt; SQL-, Cleanup- und Stop-Prüfungen liefen nicht.

PR #710 ist auf Main `e33b9549b1b828e396e1cbedf852d5666162af1a` regulär abgeschlossen. Head [43764003280](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43764003280) bestand sechs Workflows und acht Checks, Main [43765394674](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43765394674) fünf Workflows und sieben Checks. Beide SQL-Server-2025-/CL170-Gates bestanden Deployment und acht SQL-Tests einschließlich der nativen Konfigurations-Fixture 133; StopSynthetic bestand. Dokumentation bestand je 80 Validatoren, 25 Regelkontext-Selbsttests, den Regelkontextvertrag, 22 statische Deployment-Selbsttests und kanonische Installervergleiche mit 584.191 und 6.738.474 Bytes. Links meldeten 175 beziehungsweise 126 transiente Warnungen. Datenschutz prüfte Repository und ZIP mit je 1.325 Dateien ohne Funde; Cleanup bestand je 18 synthetische Finally-Szenarien. Berechtigungs-/Regex-Matrizen, Standalone und native SQL-Server-2019-/2022-Läufe waren nicht ausgewählt. Der begrenzte Nachweis betrifft allein die caller-sichtbare Konfigurationszeile `external rest endpoint enabled` und ihre native Wertparität; REST-Aufrufe, Endpoint-Erreichbarkeit, Berechtigungen, Credentials, Nutzung und Sicherheitswirkung wurden nicht geprüft. Das [REST-Konfigurationsdossier](../Architecture/External_REST_Endpoint_Configuration_Dossier.md) hält diese Grenze fest. Der kanonische Generatorlauf [43763564504](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43763564504), Job 132963517534, Pushversuch 1, und die unabhängige Prüfung der tatsächlichen OPS-Kopie `6dc8377366103accfec60ec2c862069f94556bf4` (6.738.474 Bytes) sowie des Envelopes `89944b2e7e9847b56736e44d58219ce75266682c` (1.711.238 Bytes) bestanden; der Helper wurde mit Restore `89eb04a8e03ca0a5934035912bf4a72cf64a397c` auf den ursprünglichen Baum `4df10207a1a5d94703a49257d1e24670b0211664` zurückgeführt.

PR #707 integrierte den begrenzten Abdeckungsabgleich für fünf bestehende Diagnosebereiche auf Main `650f277b49a7dadc1c0e3d372bbffbc1fe2e3752`. Die vier benannten Forschungszeilen und der Snapshot-Evidenztext wurden berichtigt; WI-0010-Intake, globale Reife und die historischen Producergrenzen blieben erhalten. Diese Metadatenlieferung ist keine neue SQL-Laufzeitabnahme.

PR #708 ist auf Main `ce5bfa4662b6c6baaa87f2d854b38001061a5f26` regulär abgeschlossen. Head [43755064720](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43755064720) bestand sechs Workflows und acht Checks; Main [43756735781](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43756735781) bestand fünf Workflows und sieben Checks. Beide SQL-Server-2025-/CL170-Gates bestanden Deployment und sechs SQL-Tests einschließlich Fixture 122; StopSynthetic bestand. Berechtigungs-/Regex-Matrizen und Standalone waren nicht ausgewählt. Die Fixture belegte den loginlosen `msdb`-Preflight (`UNSUPPORTED`, `IsPartial = 1`, `[]`), den eigenen Login mit sichtbarer `msdb`, drei direkten SQL-229-Verweigerungen und drei `SOURCE_UNAVAILABLE`-PBM-Zeilen mit unbekanntem Count bei `AVAILABLE_LIMITED`/Partial1 sowie die eigene nicht mandatierte Kategorie mit Countzuwachs um eins, TABLE-/JSON-Parität und normalem Rückbau. Dokumentation bestand je 80 Validatoren, 25 Regelkontext-Selbsttests und kanonische Installervergleiche (584.191 und 6.738.082 Bytes); Links meldeten 93 beziehungsweise 174 Warnungen. Datenschutz prüfte Repository und ZIP mit je 1.324 Dateien ohne Funde; Cleanup bestand je 18 synthetische Finally-Szenarien. Native SQL Server 2019/2022, positive echte Policy-/Condition-Objekte, Evaluation, Enforcement, Gesundheitsurteile, externe Berechtigungsmatrizen und absichtlich ausgelöste Fehler im eigenen Principal-Cleanup bleiben unqualifiziert.

Der abgeschlossene PBM-Auftrag erweiterte die bestehende msdb-Analyse um reine Zählwerte für PBM-Policies, -Conditions und -Categories. Das [PBM-Dossier](../Architecture/Policy_Based_Management_Count_Dossier.md) bindet den unveränderten Elf-Parameter- und Achtspaltenvertrag, Rechte- und NULL-Grenzen sowie einen ausschließlich eigenen, wieder zu entfernenden Kategorienfall. Produktseitig werden keine Policies ausgeführt oder verändert. Der initiale unabhängige Review von Kandidat und Generatorprotokoll bestand. Der kanonische Generatorlauf [43745480206](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43745480206), Job 132907718820, Pushversuch 1, bestand und erzeugte die OPS-005-Installationskopie `dc955519b80d20f25cc025ed8eb4d7ae65fa8c62` mit 6.738.082 Bytes sowie das Envelope `bd06b14b3177669da0c0f7fefc555fc8adc3968e` mit 1.711.024 Bytes. Root prüfte beide tatsächlichen Blobs vollständig und die ganze Source210-Modulsubstitution mit Rücksubstitution und unverändertem Rest; die unabhängige Prüfung der tatsächlichen Artefakte bestand. Eine gesonderte Gzip-Dekompression wurde nicht durchgeführt. Der exklusive Helper wurde mit Restore `f47b7e0d8b804709b4a8954435907375f73d4940` auf den ursprünglichen Baum `4df10207a1a5d94703a49257d1e24670b0211664` zurückgeführt; für das Restore lief kein Workflow. Der erste Headlauf [43745868599](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43745868599) bestand das Deployment und fünf weitere Workflows; der native Core-Vertrag 122 scheiterte beim eigenen Kategorieguard mit SQL 207 an der Referenz `policy_category`. StopSynthetic bestand. Die Dokumentation bestand 80 Validatoren, 25 Regelkontext-Selbsttests und die kanonischen Vergleiche mit 584.191 und 6.738.082 Bytes. Die [Microsoft-SMO-Quellbindung](https://github.com/microsoft/sqlmanagementobjects/blob/6b96c6e4e2394212aa054c2ca2bd632f0281a558/src/Microsoft/SqlServer/Management/PolicyEnum/xml/Policy.xml) verwendet für die Policy-Kategorie `policy_category_id`; die Microsoft-Learn-Tabellenbeschreibung nennt abweichend `policy_category`. Die Spaltenkorrektur erreichte im zweiten Headlauf [43748015925](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43748015925) das Deployment; der native Vertrag 122 scheiterte bei der unveränderten Assertion 54961 zum eingeschränkten PBM-Zählpfad. Die bestehende Fehlerausgabe schlüsselte die Zählwerte nicht auf; der positive eigene Kategorienfall wurde nicht erreicht. Fünf weitere Workflows bestanden, darunter Dokumentation mit 80 Validatoren, 25 Regelkontext-Selbsttests und kanonischen Vergleichen (584.191 und 6.738.082 Bytes); StopSynthetic bestand. Der dritte Headlauf [43750911363](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43750911363) bestand das Deployment und fünf weitere Workflows; der native Vertrag 122 meldete vor dem positiven eigenen Kategorienfall bei 54961 ausschließlich `jsonValid=1`, `totalRows=0`, `pbmRows=0`, `exactUnknown=0`, `available=0` und `unsupported=0`. Der loginlose datenbankgebundene Fixture-Caller sah die `msdb`-Zeile im globalen Preflight nicht; die PBM-Reads wurden dadurch nicht erreicht. Die anschließend qualifizierte Korrektur bewahrte diesen Preflight als eigenen Negativfall und prüfte die unveränderte 54961-Assertion unter einem kurzlebigen eigenen Login mit sichtbarer `msdb`, drei direkten SQL-229-Verweigerungen und vollständigem Principal-Rückbau. Die native SQL-Server-2025-/CL170-Qualifikation und Main-Abnahme sind im Abschlussabsatz belegt; SQL Server 2019/2022 und positive echte Policy-/Condition-Fälle bleiben unqualifiziert.

PR #706 ist auf Main `4a62f28e6ab702cf55824387dba2069ffa9d27bf` regulär abgeschlossen. Head [43734726951](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43734726951) bestand sechs Workflows und acht Checks, Main [43736807292](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43736807292) fünf Workflows und sieben Checks. Beide SQL-Server-2025-/CL170-Gates bestanden Deployment, vollständigen Core-Vertrag einschließlich 144, Berechtigungs-, Regex-, Standalone- und Stop-Prüfungen. Dokumentation bestand je 80 Validatoren, 25 Regelkontext-Selbsttests und kanonische Installervergleiche (584.191 und 6.736.049 Bytes); Links meldeten 173 beziehungsweise 81 Warnungen. Cleanup bestand je 18 Finally-Szenarien; Datenschutz prüfte Repository und ZIP mit je 1.323 Dateien ohne Funde. Die CONSOLE-Zellen sind indirekt über exakte Quellprojektion, gleichaufrufbezogenes JSON und das typisierte einzelne Resultset gebunden. SQL Server 2019/2022, kontrollierte native Rechteverweigerung und physische Sparse-Dateibelegung sind für dieses Modul nicht qualifiziert.

PR #705 ist als begrenzter Evidenzabgleich für drei vorhandene Inventare auf Main `adcf2aa8c6c745a061fd04c8d45e8832f2e38fc2` integriert. Vier Head- und drei Main-Checks bestanden; beide Dokumentationsläufe bestanden 80 Validatoren, Regelkontext und kanonische Installervergleiche (584.191 und 6.706.266 Bytes). Repository und ZIP wurden mit je 1.319 Dateien ohne Datenschutzfunde geprüft. Diese Metadatenwelle führte keine neue SQL-Laufzeit-, Linux-Nativ-, Cleanup- oder Stop-Prüfung aus. Die [historische Entwicklungsplanung](Development_Waves_2026-10.md#aktuelle-fortsetzung) enthält die vorherigen Nachweise und Grenzen.

PR #706 ergänzte [USP_DatabaseSnapshotInventory](../../../Documentation/Analysis_Guides/Procedures/USP_DatabaseSnapshotInventory.md) als lesenden Katalog-Slice für caller-sichtbare Datenbank-Snapshots und Sparse-Dateikatalogzeilen. Das [Dossier](../Architecture/Database_Snapshot_Inventory_Dossier.md) trennt maximale Sparse-Dateikapazität von physischer Belegung und den SQL-Datenbank-Snapshot vom optionalen Snapshot-/Baseline-Paket. Der Ausgangsstand von Quelle `Code/08_ServerHealth/340_USP_DatabaseSnapshotInventory.sql` und nativer Fixture `Code/Tests/ServerHealth/144_DatabaseSnapshotInventory_Runtime_Contract.sql` war statisch unabhängig geprüft; Installer, Inventare, Navigator, öffentliche Lesewege und Release-Gate wurden im ersten Head gebunden. Die eng korrigierten Quell- und Fixturebytes wurden begrenzt unabhängig geprüft. Der Produktpfad ändert keine persistenten Datenbank- oder Snapshot-Objekte; lokale Temp-DDL dient der Aufbereitung und TABLE-Ausgabe. Ein positiver eigener Snapshot wurde im freigegebenen SQL-Server-2025-/CL170-Container tatsächlich erzeugt, ausgelesen und mit sicherem Rückbau entfernt. Der kanonische Generatorlauf [43689747911](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43689747911), Job 132737675519, Pushversuch 1, bestand und erzeugte die OPS-005-Installationskopie `fca10711556297a263931514da17166088e76b0e` mit 6.735.863 Bytes sowie das Envelope `66a85e25e93e59066ddbcf3bbb54647072c5c97b` mit 1.711.114 Bytes. Root prüfte beide tatsächlichen Blobs vollständig auf Git-SHA, UTF-8, Länge und die unabhängige Sollableitung mit vier ganzen Modulgrenzen, Rücksubstitution und unverändertem Rest; die gesonderte unabhängige Prüfung der tatsächlichen Artefakte bestand ebenfalls. Der exklusive Helper wurde mit Restore `a38e3239fc04362c77cb93d51314c274b3b51b11` auf den ursprünglichen Baum `4df10207a1a5d94703a49257d1e24670b0211664` zurückgestellt; der Restore führte keinen Generatorlauf aus. Für diesen begrenzten Vertrag bestanden Head und Main auf SQL Server 2025/CL170 einschließlich Vertrag 144, Berechtigungs-, Regex-, Standalone- und Stop-Prüfungen. SQL Server 2019 und 2022 bleiben für dieses Modul nativ unqualifiziert.

Der erste funktionale Head-Lauf [43690245970](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43690245970), Runtime 132739253362 und Gate 132739540658, scheiterte beim Deployment der neuen Procedure mit SQL-Fehler 156 am ungeschützten Bezeichner `RowCount`; der eigene Vertrag 144 sowie Berechtigungs-, Regex- und Standalone-Prüfungen wurden nicht erreicht. Der synthetische Stop bestand. Die [Dokumentationsprüfung 43690245940](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43690245940), Job 132739192550, scheiterte in vier statischen Validatorbereichen: kanonische Quellenzahl 209 statt 210, Satzfragment im SQL-Zweckkopf, zwei nicht modulgebundene lokale Temp-Namen und fehlende Pflichtstruktur samt Links im neuen Procedure-Guide. Die beiden kanonischen Installervergleiche sowie 25 Regelkontext-Selbsttests und der Regelkontextvertrag bestanden innerhalb der insgesamt fehlgeschlagenen Statiksuite; nachfolgende separate Installerverträge und die Linkprüfung wurden nicht ausgeführt. Die Korrektur klammert `RowCount` in Source und RAW-Fixture, bindet die beiden Temp-Namen an den Modulnamen, vervollständigt Zweckkopf und Guide und erhöht ausschließlich die kanonische Quellenzahlerwartung. Die Generatorartefakte `fca10711556297a263931514da17166088e76b0e` und `66a85e25e93e59066ddbcf3bbb54647072c5c97b` sind für die korrigierte Quelle `STALE`. Der korrigierte kanonische [Generatorlauf 43692055992](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43692055992), Job 132744596524, Pushversuch 1, bestand und erzeugte die OPS-005-Kopie `e2265d084bd8f65bf3661d1dbc841cda1a304fd1` mit 6.736.049 Bytes sowie das Envelope `099af7a257d815b90985f507906af149c7011f1a` mit 1.710.334 Bytes. Root prüfte die tatsächlichen Blobs vollständig auf Git-SHA, UTF-8, Länge und die Sollableitung aus einem ganzen Source-Modul mit exakter Rücksubstitution; die gesonderte unabhängige Prüfung der tatsächlichen Korrekturartefakte bestand ebenfalls. Der Helper wurde mit Restore `b64d322640ca2991583db8058557e72e9baee908` auf den ursprünglichen Baum `4df10207a1a5d94703a49257d1e24670b0211664` zurückgestellt. Der zweite funktionale Head-Lauf [43696068638](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43696068638), Runtime 132756823960 und Gate 132761679452, bestand das Deployment, scheiterte aber im Core-Vertrag 144 mit SQL-Fehler 468 am Kollationskonflikt zwischen nativem Snapshot-Katalog und typisierter TABLE-Ausgabe. Vertrag 144, der eigene Fixture-Rückbau und nachfolgende Berechtigungs-, Regex- und Standalone-Gates sind damit nicht abgenommen; der synthetische Stop bestand. Die fünf übrigen Head-Workflows bestanden. Die Dokumentationsprüfung bestand 80 Validatoren, 25 Regelkontext-Selbsttests, die kanonischen Installervergleiche (584.191 und 6.736.049 Bytes) sowie die Linkprüfung mit 172 Warnungen. Cleanup bestand 18 Finally-Szenarien; die Datenschutzprüfung fand in Repository und ZIP mit je 1.323 Dateien keine Funde. Der eng korrigierte native Vertrag bindet die Textausdrücke der Katalog- und JSON-Vergleiche explizit an `SQL_Latin1_General_CP1_CS_AS`. Der dritte funktionale Head-Lauf [43730504669](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43730504669) bestand das Deployment und erreichte Vertrag 144, scheiterte aber mit äußerem Fehler 57759. Das vollständig ausgewertete Diagnosearchiv belegt darin den Fixturefehler 57763 beim CONSOLE-Orakel; welcher der drei bisherigen Zellvergleiche fehlschlug, ist daraus nicht ersichtlich. Die fünf übrigen Head-Workflows und der synthetische Stop bestanden. Der neue Testkandidat ruft die unveränderte CONSOLE-Ausgabe direkt mit einem vier Spalten umfassenden Resultsetvertrag auf und gleicht JSON und OUTPUTs desselben Aufrufs mit den zuvor nativ geprüften TABLE-Daten ab. Ein exakter Bindungscheck des installierten Projektionsblocks und eine `INSERT … EXEC`-Negativkontrolle erhalten die Aussage zu Snapshot-, Datei- und Quellenzeilen; direkte CONSOLE-Zellen werden dabei nicht erfasst. Der Transaktionsguard als Ursache des bisherigen Captures ist bis zum Negativnachweis eine Inferenz. Der spätere korrigierte Head und die erste Main-Abnahme bestanden; die vorherigen Fehlversuche bleiben historische Einzelfunde.

### Überholter PR-697-Vorlauf (nicht ausführbar)

PR #696 ist auf Main `86baf7ab6ac6f5ffce71fae5350250b21d71e159` mit Baum `e82a4b7ca4604cb62d829f927563497e3d844870` und den geordneten Eltern `85ef3d2c6ddfb64e331638c22d9b4e5fcc1ba715`, `4005dcb18287cd8939479b809b3350a55909d509` regulär abgeschlossen; PR-Merge, Main-Ref und Eltern wurden abgeglichen. Head [43452789887](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43452789887), Versuch 2, Runtime 131992568595 und Gate 132002296828, bestand sechs Workflows und acht Checks. Der Selector 131992644238 übernahm den ursprünglichen Start 15:27:30Z und wurde nicht erneut ausgeführt; die übrigen fünf Head-Workflows behielten Versuch 1. Main [43459804188](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43459804188), Versuch 1, Runtime 132003508046 und Gate 132015273258, bestand fünf Workflows und sieben Checks. Beide tatsächlichen SQL-Server-2025-/CL170-Gates umfassten Deployment, den Proxyvertrag 126, ausgewählte Berechtigungs-, Regex- und Standalone-Prüfungen sowie den Stop. Die Head-Dokumentation [43452790314](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43452790314) und Main-Dokumentation [43459804166](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43459804166) bestanden 80 Validatoren, Regelkontext, die kanonischen Installervergleiche mit 584.191 und 6.569.547 Bytes sowie die Linkprüfung mit 123 beziehungsweise 84 transienten Warnungen. Head-Cleanup [43452790011](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43452790011) und Main-Cleanup [43459804243](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43459804243) bestanden je 18 tatsächliche Finally-Szenarien. Es gibt keinen separat exportierten SQL-stdout-/126-PASS-Marker, keinen positiven Proxyfall, keine Windows-Proxy-Ausführung und keine Prüfung effektiver Rechte; weitere Engines und Compatibility Levels waren nicht ausgewählt. Die dokumentierten früheren Snapshot-/Legacyfehler bleiben mit Ursache `UNKNOWN` historische Einzelfunde und belegen keine kausale Korrektur.

Die aktuelle begrenzte WI-0010-Welle setzt den eigenständigen Sensitivity-Classification-Summary-Slice um. Das [Dossier](../Architecture/Sensitivity_Classification_Summary_Dossier.md) legt caller-sichtbare Tabellen- und Spaltenzählungen, das Datenbankrecht `VIEW ANY SENSITIVITY CLASSIFICATION`, Fehler-/NULL-Grenzen und die nichtatomare Aufnahme fest. Die kohärente Source-Implementierung umfasst `Code/08_ServerHealth/320_USP_SensitivityClassificationSummary.sql`, die synthetische Remote-Fixture `Code/Tests/ServerHealth/142_SensitivityClassificationSummary_Runtime_Contract.sql`, Installer, Inventare, Navigator, öffentliche Leserichtung und den kanonischen Release-Gate-Include. RLS/Masking 285 und Vertrag 139 bleiben unverändert. Die Abdeckungsmatrix führt den vorhandenen begrenzten Source-Slice als `PARTIAL_PRODUCT_FUNCTION`; `Module_Maturity` bleibt `PLANNED`. Die Source-Implementierung und ihr unabhängiger Source-Review sind abgeschlossen. Native Qualifikation, Main-Integration und Klassifikationsqualität sind vor dem exakten Remote-Head-Gate nicht belegt. Wegen der Änderung an `Code/Install/Install_All.sql` ist die vollständige funktionale SQL-Server-2025-/CL170-Suite einschließlich Vertrag 142 erforderlich; weitere native Engines und Compatibility Levels folgen nur einem konkreten Versionsrisiko. Der kanonische Generatorlauf [43472074764](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43472074764), Job 132046261731, erzeugte beim ersten Versuch die neue OPS-005-Installationskopie `ce2e89ef048c37fcc0f3de6f73904b8c8f8fd792` mit 6.608.402 Bytes und den Envelope `619e7a766d09f0ee31e6506144906c39be991164` mit 1.678.308 Bytes. Das vollständige Readback, die Modulbindung, der Rückbau und der unveränderte Rest wurden geprüft; die unabhängige Artefaktprüfung bestätigte den tatsächlichen OPS-/Envelope-/Job-Verbund mit PASS. Die Head-697-Dokumentations- und Privacy-Findings erfordern Korrekturen an der Procedure-Quelle und den zugehörigen Dokumenten. Die erste OPS-005-Kopie wurde durch die nachfolgende Quellenkorrektur für den damaligen Korrektur-Preview STALE und war bis zur erneuten Bindung NOT_PUBLISHABLE. Der korrigierte kanonische Generatorlauf [43477392017](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43477392017), Job 132064669583, erzeugte beim ersten Pushversuch die OPS-005-Installationskopie `8560a579bd68a08e31936ca7616c9dc28c6b494f` mit 6.608.483 Bytes und den Envelope `c325ce00878ec8c7235013cdb232b45be9029b13` mit 1.678.312 Bytes. Vollständiges tatsächliches Git-SHA-/UTF-8-Readback und der exakte Vergleich mit der erwarteten Gesamtdatei bestanden; der unabhängige Artefaktreview bestätigte den tatsächlichen OPS-/Envelope-/Job-Verbund und die vier Modulgrenzen mit PASS. Helper `2bec7a506907d5a8c5df75274f89347d3fdd0e09` wurde mit Restore `3896e16858ceeaf5afe06d09d813d51f876defef` auf Originalbaum `4df10207a1a5d94703a49257d1e24670b0211664` ohne Generatorlauf zurückgestellt. Native Head- und Main-Qualifikation für den korrigierten Stand sind offen. Der erste Head-697-Lauf [43473561937](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43473561937) erreichte nach erfolgreichem Deployment den nativen Vertrag 142 und scheiterte dort in Gate 132061221104 mit SQL-Fehler 57512 an der kombinierten Caller-State-Assertion; Runtime-Job 132051574778 schlug fehl; der Stop war erfolgreich, spätere Berechtigungs-, Regex- und Standalone-Phasen blieben SKIPPED. Der Befund trennt Transaktion, `LOCK_TIMEOUT` und `XACT_ABORT` nicht. Für den korrigierten Fixture-Stand liegt noch keine native Laufzeitevidenz vor. Der Generator führte kein SQL aus. Helper `4f322402557300bb871f993879bc6c308b65eff8` wurde mit Restore `3c257c9214dd0b3c1d2f99f2c8867d749bfc645e` auf den Originalbaum zurückgestellt; der Restore führte keinen Generatorlauf aus.

### Historischer PR-696-Verlauf (nicht ausführbar)

PR #695 schloss die Agent-History-Grenzfallwelle mit erster Head- und Main-Abnahme ab. Der reguläre Merge/Main `85ef3d2c6ddfb64e331638c22d9b4e5fcc1ba715` enthält Baum `ce6d321a709d40957b8f1b9f4ff2bb8f3cd1f2e9` und die geordneten Eltern `f89eeccc1a07292c93936c9d9c926f45c30ad952` und `d05cc888768db36f94c1e7c042e9fb95e5e309df`. Head [43420929679](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43420929679) bestand sechs Workflows und acht Checks; Main [43422837975](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43422837975) bestand fünf Workflows und sieben Checks. Beide Laufzeitgates bestätigten Deployment, MSDB-Vertrag 122, die tatsächliche Fixture mit 103 positiven Aufrufen und Stop auf SQL Server 2025 bei CL170. Die getrennte Kalender-/Uhrzeitsektion blieb bei 96 Aufrufen und 72 Rollbacks. Dokumentations- und Cleanup-Gates bestanden für Head und Main; die 25 Regelkontext-Selbsttests, zusätzliche Engines und Compatibility Levels waren nicht ausgewählt.

Das [Agent-Proxy-Dossier](../Architecture/Agent_Proxy_Dependency_Inventory_Dossier.md) begrenzt den Kandidaten. Die aktuelle ausführbare Welle entwickelt unter `AGENT_PROXIES_CREDENTIALS` eine eng begrenzte, lesende SQL-Agent-Proxy-Inventur. V1 erfasst Proxy- und Subsystemkatalog sowie Credential-ID und sichtbaren Credentialnamen; sie liest keine Credentialidentität, Secrets, SIDs, Loginzuordnungen, Jobsteps, Befehle oder Pfade und behauptet keine effektiven Rechte oder Proxy-Ausführung. Die Produktquelle, kanonische Registrierung, Installerableitung, öffentliche Leserichtung und der neue native Vertrag bilden einen kohärenten Änderungsschritt. Wegen der Änderung an `Code/Install/Install_All.sql` verlangt die CI-Teststrategie das vollständige funktionale SQL-Server-2025-Gate bei CL170; der spezifische Proxyvertrag gehört dazu und verengt den Gateumfang nicht. Zusätzliche native Engines oder eine Releasematrix folgen daraus nicht. Der frühere vollständige native Funktionslauf am Head `98b7c6f64fca5bb59f1f9e40d24e16a6a3599165` bestand auf SQL Server 2025 bei CL170; am aktuellen Head fehlen vollständige grüne Pflichtgates. Die Abdeckungsmatrix führt nur den vorhandenen Katalog-Slice als `PARTIAL_PRODUCT_FUNCTION`, `Module_Maturity` bleibt `PLANNED`. Ein positiver Proxy- oder Ausführungsfall ist damit nicht belegt. Der unabhängige Source- und Sicherheitsreview bestätigte die erste begrenzte Quelle (Blob `58a9935b045ae373018df8fe0a11bdfd1418b9bf`) und den weiterhin unveränderten Laufzeitvertrag (Blob `4def7ac5f456607c86ab2c69f9e9393e3845e082`) ohne blockierenden Befund. Die gezielte unabhängige Nachprüfung der korrigierten Quelle (Blob `8050eeb8bbf2bf6aaa2b46f49744ab310974db1a`) und Navigationskante (Blob `6ba2cdd8b1b5cc72c6ecf3e4a52de6387c957dbe`) bestand ohne blockierenden Befund. Verarbeitungsaufwand und private Verbrauchsgrenzen werden nicht im Repository veröffentlicht.

Der kanonische Korrekturlauf [43433468434](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43433468434), Job 131912505887, bestand beim ersten Versuch und erzeugte die OPS-005-Installationskopie `TestLab/Adapters/OPS-005/sql/install.sql` mit Blob `8dbd50441fc3bf48cba6a023013351abd08fda2b` (6.569.259 Bytes). Der vollständig gelesene Blob wurde gegen die drei geänderten Vollmodule und den unveränderten Rest gebunden; die eigenständige Installationskopie und Update-Kopie blieben kanonisch unverändert. Der unabhängige Schlussreview bestätigte die Artefaktbindung von OPS-Blob `8dbd50441fc3bf48cba6a023013351abd08fda2b` (6.569.259 Bytes), Generator-Envelope `94b3440c3d2c0c58311fbc9a166eb588e54567c0` (1.669.553 Bytes) und Lauf 43433468434/Job 131912505887 sowie die finalen Metadaten mit begrenztem Coverage-Status `PARTIAL_PRODUCT_FUNCTION`. Der erste Head-Lauf von PR #696 erreichte das native Pflichtgate nicht bis zu den Verträgen; eine Main-Abnahme hat noch nicht begonnen. Integration setzt grüne Pflichtgates voraus.

PR #696 am Head `4ac5af82d745eb059ef9a20e1bc590a5f8b29855` lieferte getrennte Befunde: [Dokumentation 43436965553](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43436965553), Job 131924468996, scheiterte an konkret benannten Regelkontext-, Quellabschluss-, Zähl-, Navigations-, Coverage-, Nonblocking- und Berechtigungsfehlerzuordnungsprüfungen. Der [funktionale Lauf 43436965541](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43436965541), Runtime 131924595344 und Gate 131928695709, scheiterte vorher beim Deployment in SnapshotSchema Stage 0 (NativeError 53935, SQL 1222, Zeile 816). `BLOCKER_NOT_CAPTURED`, null Beobachterfehler, gekürzte Summary und `wrapperIncomplete=false` belegen keinen Blocker; die Ursache bleibt `UNKNOWN`. Alle SQL-Verträge einschließlich Proxyvertrag 126 wurden übersprungen; der synthetische Stop bestand. Cleanup, Privacy, Registry und Commit bestanden getrennt. Das vollständige Runtimearchiv wurde nicht entpackt; eine Proxy-Laufzeitqualifikation oder kausale Fehlerbehebung folgt daraus nicht. Die Korrektur bindet die statischen Befunde eng. Die frühere OPS-Installationskopie `8dbd50441fc3bf48cba6a023013351abd08fda2b` bleibt die historische Bindung des ersten PR-Heads. Der einmalige kanonische Generatorlauf [43442822408](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43442822408), Job 131944527302, bestand beim ersten Versuch und erzeugte die neue OPS-Installationskopie `da3e6433b321d4abea6ae2cdff7521035f0d495a` (6.569.547 Bytes) aus den korrigierten Vollmodulen 021, 022, 023 und 025; die Generator-Envelope ist `7daf988c93e7c33120ad4345ea3bb4ff40773e0e` (1.669.914 Bytes). Die unabhängige Nachprüfung der neuen Artefakt- und Metadatenbindung mit OPS-Blob `da3e6433b321d4abea6ae2cdff7521035f0d495a`, Generator-Envelope `7daf988c93e7c33120ad4345ea3bb4ff40773e0e` und Lauf 43442822408/Job 131944527302 bestand. Ein vollständig grünes Head-Gate und die erste Main-Abnahme stehen noch aus. Der Generatorerfolg belegt keine SQL-Laufzeitqualifikation.

Am korrigierten Head `98b7c6f64fca5bb59f1f9e40d24e16a6a3599165` bestand der [funktionale Lauf 43443935686](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43443935686), Runtime 131948462202 und Gate 131959679777, im ersten Versuch: Deployment, ausgewählte Verträge und tatsächlicher Stop auf SQL Server 2025 bei CL170. Der Selector wählte die vollständige Release-Gate-Suite einschließlich Proxyvertrag 126 sowie Berechtigungs-, Regex- und Standalone-Prüfungen; die betroffenen Schritte bestanden. Einzelne SQL-stdout-/126-PASS-Marker wurden nicht exportiert. Die [Dokumentationsprüfung 43443935550](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43443935550), Job 131948360294, scheiterte an einer unklassifizierten Produktreferenz von Development_Waves auf die OPS-005-Installationskopie und an zwei veralteten `<>116`-Prüftokens in den Wave-2-/RUNTIME-001-Validatoren; die übrigen zuvor gemeldeten statischen Befunde entfielen, beide kanonischen Installervergleiche bestanden. Cleanup, Privacy, Registry und Commit bestanden getrennt. Der Regelkontext-Extractor erfasst denselben OPS-Pfad auch in Next_Steps; beide Planungsreferenzen sind im Korrekturkandidaten als `product-reference` klassifiziert. Die folgende CI-Prüfung am Head `97a6aa8dbc82a5497f65b1a96ba01e1dbd461636` bestätigte die Regelkontextkorrektur; eine erste Main-Abnahme fehlt. Die erfolgreiche Suite enthält keinen belegten positiven Proxyfall, keine Windows-Proxy-Ausführung und keine Prüfung effektiver Rechte.

Am aktuellen Head `97a6aa8dbc82a5497f65b1a96ba01e1dbd461636` bestand der Regelkontextvertrag. Die [Dokumentationsprüfung 43449334510](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43449334510), Job 131967065645, scheiterte nur noch an zwei festen `<>116`-/`116 Vertragsobjekte`-Erwartungen in `996_Validate_Wave2_Contracts.py` und `999_Validate_Runtime001_Contracts.py`; der installierte öffentliche Vertrag zählt bereits 117. Der [funktionale Lauf 43449335027](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43449335027), Runtime 131967212145 und Gate 131975269156, scheiterte im ersten Versuch nach erfolgreichem Deployment während des vollständigen Release-Gates: Legacy-Vertrag 202, Fall C012, Ordinal 13, meldete in `InternalWriteResultTable` Zeile 537 für `#ExampleSsisLegacy_moduleStatus` den SQL-Fehler 51010 `TABLE_EXPORT_LOCK_TIMEOUT` im Schritt `TARGET_SCHEMA_ADAPT`. Der synthetische Stop bestand. `BLOCKER_NOT_CAPTURED`, null Beobachterfehler, SQLCMD-Exitcode 1, ungekürzte Summary und `wrapperIncomplete=false` belegen weder einen tatsächlichen Blocker noch eine Ursache; diese bleibt `UNKNOWN`. Der Proxyvertrag 126 und die nachgelagerten Berechtigungs-, Regex- und Standalone-Prüfungen wurden in diesem Lauf nicht erreicht. Das vollständige Runtimearchiv wurde nicht entpackt. Die beiden veralteten statischen Prüftokens sind im Korrekturkandidaten auf 117 gebunden; das behebt keinen nachgewiesenen nativen Fehler. Korrigierte Head-Pflichtgates und eine erste Main-Abnahme bleiben ausstehend.

### Vorheriger Planstand (nicht ausführbar)

Die [Entwicklungsplanung](Development_Waves_2026-10.md) bleibt maßgeblich für Reihenfolge und Zuständigkeit. PR #693 qualifizierte die aktuelle technische Ausgangslage der OPS-008-AgentHistory-Fixture mit 95 positiven Consumeraufrufen, sechs Jobproblemfällen und zwölf Aufrufen. PR #694 änderte ausschließlich zwei interne Planungsseiten. Der reguläre Merge/Main `f89eeccc1a07292c93936c9d9c926f45c30ad952` mit Baum `ef44f57cc1046d03235f841b41bea2631fc303ec` und geordneten Eltern `8fd2de5ba33ed239d4af224bc977210e2b851dc2` und `bc492a585df6d241b22c9bf8f491bf98e8f00755` wurde mit PR und Main-Ref abgeglichen. Head bestand vier Workflows und vier Checks, Main drei Workflows und drei Checks. Die Head-Dokumentation [43402272353](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43402272353), Job 131807779794, und die Main-Dokumentation [43402832054](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43402832054), Job 131809703281, bestanden jeweils 80 Validatoren, den Regelkontextvertrag, die kanonischen Installervergleiche mit 584.191 und 6.549.703 Bytes sowie die Linkprüfung mit 163 beziehungsweise 109 transienten Warnungen. Die 25 Regelkontext-Selbsttests waren nicht ausgewählt. Für PR #694 waren keine funktionalen SQL-, Stop- oder Cleanup-Läufe ausgewählt; daraus folgt keine neue Laufzeitqualifikation.

Die nächste ausführbare Welle ergänzt die bestehende positive Fixture um vier `@MaxZeilen`-Fälle mit tatsächlichen Job- und Step-History-Werten: NULL, 0, 1 und 2. Je Fall werden NONE/JSON und TABLE/JSON geprüft, einschließlich der unabhängig begrenzten Stepmenge, der vollständigen Job-TABLE-/JSON-Parität und der unveränderten sechs MSDB-Quellen. Der geplante Umfang erhöht die positiven Consumeraufrufe von 95 auf 103; vier TABLE- und zwei tatsächliche NULL-Aufrufe kommen hinzu. Der gemeinsame Rollback und die separate Kalender-/Uhrzeitsektion mit 96 Aufrufen und 72 Rollbacks bleiben erhalten. Die Änderung ist bis zur erforderlichen nativen Head- und Main-Abnahme ein ausstehender Nachweis. Sie begründet keine allgemeine Aussage über History-Grenzen außerhalb dieser festen Fixture. Der frühere Verlauf bleibt im [Historienarchiv](Next_Steps_History_2026-11-08.md) erhalten.

Die Fortsetzung richtet sich nach der tatsächlich erteilten Benutzerautorisierung und deren privater Checkpointfortschreibung. Dieses Dokument veröffentlicht keine privaten Grenzen oder Verbrauchswerte. Heartbeat, Sessionwechsel und PR-Abschluss setzen die Fortschreibung nicht zurück. Bestehende Sicherheits-, Datenschutz-, Lizenz-, Identitäts-, Laufzeit- und Lieferbedingungen gelten.

## Historischer Index – nicht ausführbarer Kontext

Die folgenden Überschriften und bestehenden HTML-Anker bleiben für eingehende Verweise erhalten. Ihre früheren Auftrags- und Statusangaben sind archiviert und keine aktuelle Ausführungsvorgabe.

## Nächste ausführbare Welle: fünf XE-Modulschalter vollständig beschreiben

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#n%C3%A4chste-ausf%C3%BChrbare-welle-f%C3%BCnf-xe-modulschalter-vollst%C3%A4ndig-beschreiben).

<a id="nächste-ausführbare-welle-inaktive-null-modulschalter-im-plancache-wrapper"></a>

## Abgeschlossen: inaktive NULL-Modulschalter im PlanCache-Wrapper

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#abgeschlossen-inaktive-null-modulschalter-im-plancache-wrapper).

<a id="nächste-ausführbare-welle-null-dauergrenze-der-plancache-wrapper"></a>

## Abgeschlossen: NULL-Dauergrenze der PlanCache-Wrapper

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#abgeschlossen-null-dauergrenze-der-plancache-wrapper).

## Abgeschlossen: Timeoutbeschreibungen interner SSIS-Helfer

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#abgeschlossen-timeoutbeschreibungen-interner-ssis-helfer).

## Abgeschlossen: NULL-Kindstatus im SSIS-Kennzahlenconsumer

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#abgeschlossen-null-kindstatus-im-ssis-kennzahlenconsumer).

## Abgeschlossen: benachbarte SSIS-Timeout-Hilfeverträge

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#abgeschlossen-benachbarte-ssis-timeout-hilfevertr%C3%A4ge).

<a id="nächste-ausführbare-welle-wirksamer-ssis-locktimeout"></a>

## Abgeschlossen: SSIS-Locktimeoutvertrag und Wrapperkompatibilität

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#abgeschlossen-ssis-locktimeoutvertrag-und-wrapperkompatibilit%C3%A4t).

## NULL-Guards der internen Plananalyse

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#null-guards-der-internen-plananalyse).

## SSIS-LockTimeoutMs-Prüfung integriert

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#ssis-locktimeoutms-pr%C3%BCfung-integriert).

<a id="nächste-ausführbare-welle-ssis-maxdurationseconds-null-abweisung-schritt-212"></a>

## Abgeschlossener Verlauf: SSIS-MaxDurationSeconds und JSON-Paketarray

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#abgeschlossener-verlauf-ssis-maxdurationseconds-und-json-paketarray).

## Phasenbezogene File-IO-Fehlerausgänge

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#phasenbezogene-file-io-fehlerausg%C3%A4nge).

## Snapshot-Target-Diagnose 53781

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#snapshot-target-diagnose-53781).

## SSIS-Referenzabgleich vom 6. November 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#ssis-referenzabgleich-vom-6-november-2026).

## Quellenstand nach PR #633

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#quellenstand-nach-pr-633).

## Aktueller Stand nach Schritt 178

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-08.md#aktueller-stand-nach-schritt-178).


## Vorheriger Checkpoint nach Schritt 43

Der vorherige integrierte Checkpoint und seine damaligen Prüfbelege sind im [Historienarchiv](Next_Steps_History_2026-11-05.md#vorheriger-checkpoint-nach-schritt-43) erhalten.

## Aktueller Checkpoint nach PR #485

Der gebundene Checkpoint nach PR #485 und seine zugehörigen Head- und Main-Prüfungen sind im [Historienarchiv](Next_Steps_History_2026-11-05.md#aktueller-checkpoint-nach-pr-485) erhalten. Neue Änderungen werden gegen den aktuellen Main-Stand und die maßgebliche Planung abgeglichen.

## Lesepfad und technische Evidenzgrenzen

Öffentliche Anwenderdokumentation bleibt der maßgebliche Ort für Produktverhalten und Bedienung; interne Pläne und Nachweisarchive ersetzen sie nicht. Inventarvollständigkeit gilt nur für die jeweils gebundene Kohorte. Produkt-, Plattform-, Berechtigungs-, Transaktions- und Laufzeitaussagen benötigen jeweils die passende unabhängige Evidenz. Fehlende Infrastruktur oder nicht ausgeführte Prüfungen bleiben ausdrücklich offen.

Installation und Ausführung folgen den modularen, dokumentierten Installationspfaden und ihren Voraussetzungen.

Die Kerninstallation muss ohne LLM-Komponenten und deren Berechtigungen oder Netzwerkzugriff funktionieren. Künftige LLM-Funktionen sind separat wählbare Zusatzmodule; fehlende oder unzulässige Voraussetzungen dürfen eine gültige Kerninstallation nicht abbrechen oder zurückrollen. Der Zusatzmodulstatus ist getrennt und ehrlich auszuweisen. Bei Einführung solcher Funktionen sind Kerninstallation ohne LLM und nicht verfügbare beziehungsweise nicht erlaubte Zusatzkomponenten gezielt remote abzunehmen. Die Inventuren installieren oder aktivieren keine externen Laufzeiten oder CLR-Komponenten; Analyze bleibt CLR-frei.

Für jeden einzelnen Parameter sind Datentyp und Eingabeform, ein ausdrücklich als Default bezeichneter Vorgabewert sowie die Bedeutung von NULL, Leerwerten und relevanten Grenzen zu erklären. Geschlossene Wertemengen werden taxativ mit sämtlichen erlaubten Werten und der Bedeutung jedes Werts beschrieben; Beispiele ersetzen diese Aufzählung nicht. Diese Abnahme gilt auch für die Nachprüfung bereits überarbeiteter Hilfen.

Für jede Regel gilt die aktuell ausgewählte maßgebliche Quelle samt ihren semantischen Abhängigkeiten; Discoverylinks allein aktivieren keine weiteren Verträge oder Prüfungen.


## Erhaltene Rückblicke auf frühere Abnahmen

Die folgenden Verweise bewahren die konkreten historischen Nachweisscopes. Sie beschreiben damalige Abnahmen und sind keine globale oder aktuelle Vollständigkeitsbehauptung.

- Der damalige Release-Nachweis umfasst alle 17 P0-, 40 P1- und 124 P2-Fälle; die abgeschlossene P0-, P1- und P2-Special-Case-Matrix gehörte zu diesem bestätigten Produktstand. Dies ist datierte, scopegebundene Release-Evidenz und keine Aussage über den heutigen Gesamtumfang. [Historischer Nachweis](Next_Steps_History_2026-11-05.md#aktueller-produktstand).
- Der archivierte Abschnitt [Abgeschlossen – SQL25-005](Next_Steps_History_2026-11-05.md#abgeschlossen--sql25-005) enthält den damaligen Befund. Die dokumentierten Bereiche `ANALYZE-LAB-001`, `OPS-005`, `OPS-006`, `OPS-008` und `COLL-001` bleiben an ihre jeweiligen damaligen Scopes gebunden.
- Das Intake WI-0010 und sein dokumentierter Themenumfang sind in der [Diagnoseabdeckungs- und Gap-Matrix](../../../Metadata/Quality/Diagnostic_Coverage_Landscape.csv) nachgewiesen; der historische Planungsstand bleibt im [Archiv](Next_Steps_History_2026-11-05.md#aktueller-produktstand) erhalten.

## Historische Abschnitte und erhaltene Anker

Die folgenden Überschriften bewahren bislang veröffentlichte Abschnittsanker und führen zum unveränderten Originaltext im Archiv.

## Historischer SSIS-Auftrag: elfte Paketwelle

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historischer-ssis-auftrag-elfte-paketwelle).

## Historischer SSIS-Auftrag: zehnte Paketwelle

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historischer-ssis-auftrag-zehnte-paketwelle).

## Historischer SSIS-Auftrag: siebte Paketwelle

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historischer-ssis-auftrag-siebte-paketwelle).

## Aktueller Gesamtauftrag: priorisierte Entwicklungswellen

Die [Entwicklungsplanung](Development_Waves_2026-10.md) ist die maßgebliche Quelle für Zuständigkeit, Reihenfolge, Abschlussbedingungen und den nächsten ausführbaren Schritt. Die Fortsetzung bleibt innerhalb der tatsächlich erteilten Benutzerautorisierung; Checkpoints und Verbrauch werden im privaten Checkpointjournal fortgeschrieben und hier nicht mit privaten Zahlen veröffentlicht. Frühere Einzelaufträge, Grenzen und Statuswerte stehen im [Historienarchiv](Next_Steps_History_2026-11-08.md#n%C3%A4chste-arbeitsschritte). Sicherheits-, Datenschutz-, Lizenz-, Identitäts-, Laufzeit- und Liefergrenzen bleiben verbindlich.
## Abgeschlossen: fünf SSIS-Paketwellen vom 25. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-f%C3%BCnf-ssis-paketwellen-vom-25-oktober-2026).

## SSIS-Welle 6: iterationsgebundene Ausführungskorrelation

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#ssis-welle-6-iterationsgebundene-ausf%C3%BChrungskorrelation).

## Separater Auftrag: STAT-DOMINANT-Fehlerdiagnose (54901)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#separater-auftrag-stat-dominant-fehlerdiagnose-54901).

### Abgeschlossen: Diagnose aus PR #424

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-diagnose-aus-pr-424).

### Historische Freigabe und Abnahmegrenzen

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-abnahmegrenzen).

#### Freigegeben: STAT-DOMINANT-Fehlerdiagnose (54901)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegeben-stat-dominant-fehlerdiagnose-54901).

## Integriert: SSIS-001-Pipeline-Phasenbeginnmeldungen (PR #421); Main-Abnahme offen

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#integriert-ssis-001-pipeline-phasenbeginnmeldungen-pr-421-main-abnahme-offen).

### Historische Freigabe und lokale Abnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-lokale-abnahme).

#### Freigegebener begrenzter SSIS-001-Schritt: Pipeline-Phasenbeginnmeldungen

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebener-begrenzter-ssis-001-schritt-pipeline-phasenbeginnmeldungen).

## Abgeschlossen: SSIS-001-Final-Commit-Meldungen (PR #419)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-ssis-001-final-commit-meldungen-pr-419).

### Historische Freigabe und lokale Abnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-lokale-abnahme-1).

## Abgeschlossen: SSIS-001-Zeilenfluss-Durchsatz (PR #417)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-ssis-001-zeilenfluss-durchsatz-pr-417).

### Historische Freigabe und lokale Abnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-lokale-abnahme-2).

## Abgeschlossen: SSIS-001-Schreibmengen (PR #415)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-ssis-001-schreibmengen-pr-415).

### Historische Freigabe und lokale Abnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-lokale-abnahme-3).

## Abgeschlossen: Release v1.1.2

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-release-v112).

## Historische Freigaben und Sperrstände

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigaben-und-sperrst%C3%A4nde).

### Freigegebener Folge-PR: FIND-CORE-Diagnose

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebener-folge-pr-find-core-diagnose).

### Gestoppte Lieferung: Release 1.1.2

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#gestoppte-lieferung-release-112).

## Historische Welle: Release 1.1.0

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-welle-release-110).

## OPS-005-Quellenabgleich vom 23. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#ops-005-quellenabgleich-vom-23-oktober-2026).

## Erhaltener Stand: OPS-005-Lesepfad und Nachweishistorie

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#erhaltener-stand-ops-005-lesepfad-und-nachweishistorie).

### Dokumentationsaltlasten und Wiederaufnahme

Die drei damals bezeichneten Einstiege sind nachgeführt: Der Metadaten-Einstieg wurde mit PR #405 qualifiziert abgeschlossen. Das öffentliche TestLab-README trennt die OPS-005-Anleitung von der datierten Nachweischronologie. Der aktuelle Fortsetzungsstand ist mit dieser Migration von der erhaltenen Historie getrennt; die bisherigen Anker bleiben erreichbar. Diese Disposition betrifft ausschließlich die genannten Lesepfade und bestätigt keine vollständige Dokumentationskonformität. Die zuständigen Maintainer prüfen diese Einstiege erneut, wenn sich deren Verträge oder Pfadkonsumenten ändern. Der [damalige Altlastenstand](Next_Steps_History_2026-11-05.md#dokumentationsaltlasten-und-wiederaufnahme) bleibt historisch erhalten.

## Erhaltene Diagnosehistorie: OPS-005-Provider-Negativfall

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#erhaltene-diagnosehistorie-ops-005-provider-negativfall).

### Geplanter Windows-Fixturepfad für OPS-005

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#geplanter-windows-fixturepfad-f%C3%BCr-ops-005).

#### Plattform und Zuständigkeit

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#plattform-und-zust%C3%A4ndigkeit).

#### Voraussetzungen vor der Providerprobe

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#voraussetzungen-vor-der-providerprobe).

#### Fachlicher Abnahmeblock

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#fachlicher-abnahmeblock).

#### Cleanup, Nachweise und vorgeschlagene Freigabegrenze

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#cleanup-nachweise-und-vorgeschlagene-freigabegrenze).

#### Zulassung vor der Runanlage

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#zulassung-vor-der-runanlage).

#### Wiederaufnahme nach Integration der Lab-Korrektur

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#wiederaufnahme-nach-integration-der-lab-korrektur).

#### Windows-Abbruch am Aktivierungsintent

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#windows-abbruch-am-aktivierungsintent).

#### Zusatzrun endet an der Lab-Collation-Gastprobe

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#zusatzrun-endet-an-der-lab-collation-gastprobe).

#### Nachabnahme mit qualifizierter Lab-Korrektur

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#nachabnahme-mit-qualifizierter-lab-korrektur).

#### Markerkorrektur bestätigt; Installation am Kommentar-GO blockiert

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#markerkorrektur-best%C3%A4tigt-installation-am-kommentar-go-blockiert).

#### Installation bestätigt; Guardzustand 54890 unbekannt

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#installation-best%C3%A4tigt-guardzustand-54890-unbekannt).

#### Windows-Providerabnahme vom 22. Oktober 2026 bestanden

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#windows-providerabnahme-vom-22-oktober-2026-bestanden).

### Autorisierter Foundation-Folgeauftrag

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#autorisierter-foundation-folgeauftrag).

## Abgeschlossene Findings-Stabilisierung vom 20. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossene-findings-stabilisierung-vom-20-oktober-2026).

## Frühere Nichtqualifikation und integrierter OPS-005-Prüfschritt vom 20. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#fr%C3%BChere-nichtqualifikation-und-integrierter-ops-005-pr%C3%BCfschritt-vom-20-oktober-2026).

## Regelübernahme für Testbewertung vom 19. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#regel%C3%BCbernahme-f%C3%BCr-testbewertung-vom-19-oktober-2026).

## Freigegebene Lookup-/Cacheanalyse vom 19. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-lookup-cacheanalyse-vom-19-oktober-2026).

## Freigegebene Legacy-Lifecycle-Analyse vom 19. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-legacy-lifecycle-analyse-vom-19-oktober-2026).

## Lieferung der begrenzten Komponentenphasen-Erweiterung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#lieferung-der-begrenzten-komponentenphasen-erweiterung).

## Freigegebene PCT_EN_2-Fortsetzung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-pct_en_2-fortsetzung).

## Freigegebene Legacy-Komponentenphasenzeiten vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-legacy-komponentenphasenzeiten-vom-18-oktober-2026).

## Freigegebene ORPS_EN_2-Fortsetzung vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-orps_en_2-fortsetzung-vom-18-oktober-2026).

## Freigegebene Legacy-Zeilenflusserweiterung vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-legacy-zeilenflusserweiterung-vom-18-oktober-2026).

## Freigegebene Legacy-Taskerweiterung vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-legacy-taskerweiterung-vom-18-oktober-2026).

## Abgeschlossene begrenzte Legacy-Providerabnahme vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossene-begrenzte-legacy-providerabnahme-vom-18-oktober-2026).

## Ergänzender abgeschlossener Mail-Retentionsnachweis

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#erg%C3%A4nzender-abgeschlossener-mail-retentionsnachweis).

## Zurückgestellter SSIS-Backlog vom 16. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#zur%C3%BCckgestellter-ssis-backlog-vom-16-oktober-2026).

## Aktuelle SSIS-Kataloglieferung vom 16. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#aktuelle-ssis-kataloglieferung-vom-16-oktober-2026).

## WI-0009: qualifizierter portabler Kern und offenes Feature-Gate

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#wi-0009-qualifizierter-portabler-kern-und-offenes-feature-gate).

## Aktueller WI-0005-Abschluss vom 14. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#aktueller-wi-0005-abschluss-vom-14-oktober-2026).

## Aktueller Fertigstellungsauftrag vom 13. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#aktueller-fertigstellungsauftrag-vom-13-oktober-2026).

## Wiederaufnahme nach der Entwicklungspause

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#wiederaufnahme-nach-der-entwicklungspause).

## Maßgeblichkeit

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#ma%C3%9Fgeblichkeit).

## Auftrag zur autonomen Fortsetzung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#auftrag-zur-autonomen-fortsetzung).

### Voraussetzungen und Abnahmen der Fortsetzung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#voraussetzungen-und-abnahmen-der-fortsetzung).

## Sessionwechsel bei langer autonomer Entwicklung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#sessionwechsel-bei-langer-autonomer-entwicklung).

## Aktueller Produktstand

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#aktueller-produktstand).

### Abgeschlossen – SQL25-005

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen--sql25-005).

## Nächste ausführbare Welle: Reifeabschluss

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#n%C3%A4chste-ausf%C3%BChrbare-welle-reifeabschluss).

## Exit-Kriterien

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#exit-kriterien).

## Freigegebene SSIS-Legacy-Umsetzung vom 16. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-ssis-legacy-umsetzung-vom-16-oktober-2026).

## Begrenzte Taskerweiterung: lokaler Abnahmeabschluss

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#begrenzte-taskerweiterung-lokaler-abnahmeabschluss).

### Verarbeitungsaufwand der SSIS-Vertrauensausnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#verarbeitungsaufwand-der-ssis-vertrauensausnahme).

## Gesondert freigegebene SSIS-Dataflowkorrelation

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#gesondert-freigegebene-ssis-dataflowkorrelation).

## Freigegebene neunte SSIS-Welle

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-neunte-ssis-welle).

# Release Notes

## Stand 2026-07-18 – Verschlüsselung, Wartung und Drei-Versionen-Gate `1.1.0-special.9`

- `SC-020` durch `monitor.USP_EncryptionAnalysis` implementiert: TDE-Zustand/Scan, sichtbarer Zertifikatlebenszyklus, getrennte explizite Backupverschlüsselung sowie aggregierte Always-Encrypted-/Ledger-Anzahlen.
- Keine Schlüsselpfade, Signaturen, verschlüsselten Werte, Backupmedien, Konten oder privaten Schlüssel; Thumbprints werden nicht ausgegeben. Lokaler Exportzeitpunkt und Zertifikatablauf bleiben begrenzte Lebenszyklusevidenz.
- `SC-022` durch `monitor.USP_MaintenanceOperations` implementiert: resumierbare Indexoperationen, technische Wartungsrequests, SQL-Server-2022+-PVS-Details und nur explizit gefilterte Agentaktivität.
- Keine SQL-Texte, Jobschritte/-befehle, Meldungen, Konten, Clientdaten oder Wait-Ressourcen; keine Resume-, Abort-, Kill-, Cleanup-, Jobstart- oder Jobstop-Aktion.
- `168_Special_Case_Runtime_Contract.sql` führt alle P2-Module gegen die synthetische Testdatenbank aus und validiert Status und JSON.
- Drei Actions-Gates erzwingen SQL Server 2019/2022/2025, Compatibility Level 150/160/170, case-sensitive Collation, Installer, 13 Suiten und synthetische Berechtigungsfälle.
- Die drei Linux-Gates lösen den öffentlichen `*-latest`-Pull-Tag in einen validierten unveränderlichen Image-Digest auf, starten exakt diesen Digest und erfassen `SERVERPROPERTY('ProductVersion')`; Build und Digest werden als rein technische Evidence dokumentiert.
- Das SQL-Server-2025-Gate hat den Regex-Prädikatvertrag gehärtet: `REGEXP_LIKE(...)` und `NOT REGEXP_LIKE(...)` ersetzen repositoryweit unzulässige Vergleiche mit `0` oder `1`; ein statischer Check schützt vor Regression.
- Die Regex-Matrix meldet konsistent zehn Verträge. Der statische Check ist nun ein eigenständiger Validator mit acht generischen Selbsttests, erkennt mehrzeilige Fehlformen und gibt bei einem Fund keinen Quellzeileninhalt aus.
- Ein eigenes Actions-Gate erzwingt für neue Pull-Request- und Main-Commits exakt einzeilige Commit Messages, ohne historische Nachrichten umzuschreiben oder den Message-Inhalt in Fehlmeldungen auszugeben.
- SQL Server 2025 meldet fehlendes `VIEW SERVER PERFORMANCE STATE` zusätzlich mit Fehler 371. Alle isolierten Berechtigungsfehler-Zuordnungen behandeln ihn kontrolliert als `DENIED_PERMISSION`; ein statischer Check schützt die vollständige Zuordnung.
- SC-023 bis SC-025 besitzen sichere Repositoryverträge beziehungsweise ein externes Runbook; Persistenz, Fleet-Infrastruktur und echter Restore bleiben bis zu ausdrücklicher externer Autorisierung unimplementiert.

## Stand 2026-07-18 – Data-Capture-/Replikations-Deep-Dive `1.1.0-special.8`

- `SC-019` durch `monitor.USP_DataCaptureDeepAnalysis` als sechstes P2-Modul implementiert.
- Change Tracking bewertet `MinValidVersion` nur gegen einen explizit gelieferten Consumer-Wasserstand. Ohne Wasserstand wird kein Synchronisationsverlust behauptet; ein Wasserstand unter dem Minimum erzeugt einen hochkonfidenten Reinitialisierungsbefund.
- CDC-Capture-Instanzen, Drop-Pending, älteste verfügbare Zeitgrenze, Scan-Aggregat/neueste Sitzung, gruppierte Fehler und Capture-/Cleanup-Jobs sind isolierte read-only Quellen.
- Kontinuierliches und zeitgesteuertes CDC erhalten unterschiedliche Latenzeinordnung. Retention plus Cleanup-Toleranz bleibt eine Heuristik mit Workload- und Timinggrenze.
- Lokale Distribution-, Log-Reader- und Merge-Agenten werden mit aggregiertem Rückstand, neuester History, Subscription-Status, Konflikten und Retries ausgewertet.
- Remote oder unzugängliche Distributor-Topologien werden als Evidenzlücke und niemals als gesunder Zustand behandelt. Inaktive Subscription oder Fail/Retry beweisen für sich keine notwendige Reinitialisierung.
- Keine Change-Zeilen, Replikationsbefehle, Kommentare, Fehlertexte, LSNs, Credentials, Agentjob-Commands, Konfliktzeilen oder DDL.
- Installer, Frameworkvertrag, Smoke-/API-Test, Beispiele, Inventare, Referenzen, Analysehandbuch, Backlog und 25 neue Spezialfalltestfälle synchronisiert.
- Laufzeitstatus bleibt vollständig `NOT_EXECUTED`; der dokumentierte synthetische Vorgängerlauf umfasst `SC-019` nicht.

## Stand 2026-07-18 – Full-Text-Deep-Dive `1.1.0-special.7`

- `SC-018` durch `monitor.USP_FullTextAnalysis` als fünftes P2-Modul implementiert.
- Sichtbares Feature-Gate aus Full-Text-Komponentenstatus, Katalogen, Indizes und semantischen Indexspalten; bei negativem sichtbarem Scope werden keine abhängigen Laufzeitquellen aufgerufen.
- Kataloge und Indizes liefern Enablement, eindeutigen Schlüsselindex, Change Tracking, Crawl-Kontext, Spalten-/Semantikanzahl und aggregierte Fragmentevidenz ohne Tabelleninhalt oder Schlüsselwerte.
- Aktuelle Populationen, ausstehende Batches und semantische Ähnlichkeitspopulation werden als getrennte best-effort Quellen behandelt. Leere DMVs sind weder Historie noch Abschlussnachweis.
- Batches werden ohne Batch-IDs, Speicheradressen oder Inhalte nach Fehlercode und Retryzustand aggregiert; Dokumentfehler werden nur gezählt.
- Querybare Fragmente mit Status 4 oder 6 werden gezählt und größenmäßig aggregiert. Fragment-, Batch-, Laufzeit- und Größenwerte bleiben konfigurierbare Heuristiken ohne universellen Grenzwert.
- Full-Text-Memory-Pools und FDHosts liefern serverweiten Kontext; FDHosts werden ohne Hostnamen oder Prozess-IDs nach Typ aggregiert.
- Kein Zugriff auf Keywords, Stopwords, Parser-Eingaben, Crawl-Logs oder Pfade; kein `ALTER FULLTEXT`, kein Populationstart und keine Reorganisation.
- Installer, Frameworkvertrag, Smoke-/API-Test, Beispiele, Inventare, Referenzen, Analysehandbuch, Backlog und Spezialfalltestmatrix synchronisiert.
- Laufzeitstatus bleibt vollständig `NOT_EXECUTED`; die statische Implementierung ist keine Zielsystemfreigabe.

## Stand 2026-07-18 – Service-Broker-Deep-Dive `1.1.0-special.6`

- `SC-017` durch `monitor.USP_ServiceBrokerAnalysis` als viertes P2-Modul implementiert.
- Sichtbares Feature-Gate aus Datenbankschalter, benutzerdefinierten Queues und Services; negativer Scope ruft keine abhängigen Broker-Quellen auf und bleibt ausdrücklich kein vollständiger Abwesenheitsbeweis.
- Queue-Schalter, Aktivierungskonfiguration, Service-Zuordnungsanzahl und approximative Nachrichten-/Speicherwerte werden ohne Zugriff auf Queue-Nutzdaten ermittelt.
- Queue-Monitor und aktivierte Tasks sind getrennte, isolierte Server-DMV-Quellen; fehlende Rechte reduzieren nicht die zugängliche Katalog-, Transmission- oder Conversation-Evidenz.
- `sys.transmission_queue` wird ausschließlich nach nicht-payloadhaltigen Metadaten, Alter und Status gruppiert. Nachrichtenkörper und Conversation-Handles werden nicht referenziert.
- Conversation Endpoints werden nur nach Zustand, Initiator-/Systemflag und Lifetime aggregiert; Gruppen-IDs, Schlüsselkennungen und Nachrichteninhalt bleiben ausgeschlossen.
- RECEIVE-OFF kann Folge automatischer Poison-Message-Erkennung nach wiederholten Rollbacks oder manueller Konfiguration sein. Das Modul meldet deshalb einen Prüfhinweis und keine bewiesene Poison Message.
- Kein `RECEIVE`, keine Queue-Änderung, kein `END CONVERSATION` und keine automatische Routing-, Aktivierungs- oder Kapazitätsmaßnahme.
- Installer, Frameworkvertrag, Smoke-/API-Test, Beispiele, Inventare, Referenzen, Backlog und Spezialfalltestmatrix synchronisiert.
- Laufzeitstatus bleibt vollständig `NOT_EXECUTED`; die statische Implementierung ist keine Zielsystemfreigabe.

## Stand 2026-07-17 – Temporal-Tables-Deep-Dive `1.1.0-special.5`

- `SC-016` durch `monitor.USP_TemporalAnalysis` als drittes P2-Modul implementiert.
- Negatives Feature-Gate ruft keine abhängigen Quellen auf und bleibt auf den sichtbaren Metadatenscope begrenzt.
- Current-/History-Zuordnung, SYSTEM_TIME-Periodenspalten und datenbank-/tabellenweite Retention-Konfiguration werden aus `sys.tables`, `sys.periods`, `sys.columns` und `sys.databases` ermittelt.
- Approximative Zeilen- und Größenwerte stammen ausschließlich aus `sys.dm_db_partition_stats`; Current- und History-Zeilen werden nicht gelesen.
- Ein aktiver sichtbarer B-Tree-History-Index mit führendem Periodenende und Periodenstart wird als dokumentierte Baseline geprüft. Das Ergebnis ist kein automatischer DDL-Vorschlag und kein universelles Workload-Optimum.
- Endliche Retention bei deaktiviertem datenbankweitem Cleanup erzeugt einen Konfigurationshinweis. Der Schalter beweist weder Cleanup-Ausführung noch -Fortschritt.
- Periodenüberlappungen und sonstige Datenkonsistenz werden ohne Zeilenscan oder `DBCC CHECKCONSTRAINTS` nicht behauptet. Nach `SYSTEM_VERSIONING=OFF` getrennte Tabellen werden ohne erhaltene Zuordnung nicht erraten.
- Installer, Frameworkvertrag, Smoke-/API-Test, Beispiele, Inventare, Referenzen, Backlog und Spezialfalltestmatrix synchronisiert.
- Laufzeitstatus bleibt vollständig `NOT_EXECUTED`; die statische Implementierung ist keine Zielsystemfreigabe.

## Stand 2026-07-17 – In-Memory-OLTP-Deep-Dive `1.1.0-special.4`

- `SC-015` durch `monitor.USP_InMemoryOltpAnalysis` als zweites P2-Modul implementiert.
- Feature-Gate aus sichtbaren speicheroptimierten Tabellen, Tabellentypen und `MEMORY_OPTIMIZED_DATA`-Dateigruppen; negativer sichtbarer Scope bleibt ausdrücklich kein Abwesenheitsbeweis.
- Tabellen-/Indexspeicher, XTP-Memory-Consumer, Hashindexkatalog, Checkpointzustände, aktive Transaktionen und Resource-Governor-Poolkontext als getrennte best-effort Quellen integriert.
- Die potenziell vollständige Tabellen scannende Hashindex-Laufzeit-DMV ist standardmäßig deaktiviert und benötigt zusätzlich `CATALOG_DEEP`.
- Bucket-Leeranteil und Kettenlängen erzeugen nur konfigurierbare Prüfhinweise. Duplikate, Verteilung und Abfrageprädikate müssen vor jeder DDL-Entscheidung separat geprüft werden.
- Checkpointzustand `WAITING FOR LOG TRUNCATION`, aktive Transaktionsmenge und Poolauslastung werden nur als Momentaufnahme mit Gegenprüfung ausgewiesen; der Defaultpool wird nie einer Datenbank als Druckbefund zugerechnet.
- Keine Benutzertabellendaten, Moduldefinitionen, SQL-Texte, Checkpoint-Pfade, GUIDs, Session-, Benutzer- oder Transaktionskennungen werden gelesen.
- Installer, Frameworkvertrag, Smoke-/API-Test, Beispiele, Inventare, Referenzen, Backlog und Spezialfalltestmatrix synchronisiert.
- Laufzeitstatus bleibt vollständig `NOT_EXECUTED`; die statische Implementierung ist keine Zielsystemfreigabe.

## Stand 2026-07-17 – Beginn P2 `1.1.0-special.3`

- `SC-021` durch `monitor.USP_SpecialFeatureInventory` als erstes P2-Modul implementiert.
- 18 Featureklassen werden je ausgewählter Datenbank ausschließlich aus aggregierten, sichtbaren Systemkatalogen als `DETECTED`, `CONFIGURED_ONLY`, `NOT_DETECTED_VISIBLE_SCOPE`, `UNAVAILABLE_VERSION` oder `SOURCE_UNAVAILABLE` klassifiziert.
- Capability und Nutzung getrennt: Das vorhandene `USP_ServerFeatureCapabilities` bleibt für Plattformverfügbarkeit zuständig; die neue Procedure inventarisiert sichtbare Verwendung und empfiehlt passende, teils noch geplante Deep-Dive-Module.
- Externe Locations, Connection Options, Credentials, Service-Broker-Payloads, CLR-Binaries, Moduldefinitionen und Benutzertabellen werden nicht gelesen.
- Native JSON-/Vector-Nutzung wird nur über den jeweiligen Systemtyp erkannt; JSON in Zeichenketten oder Moduldefinitionen wird bewusst nicht behauptet.
- Installer, Frameworkvertrag, Smoke-/API-Test, Beispiele, Inventare, Referenz, Backlog und Spezialfalltestmatrix synchronisiert.
- Laufzeitstatus bleibt vollständig `NOT_EXECUTED`; die P2-Implementierung erweitert keine Laufzeitfreigabe.

## Stand 2026-07-17 – Abschluss P1 `1.1.0-special.2`

- SQLCMD-Runner `Code/Tests/Run_Release_Gate.sql` für vier verbindliche Integrationsverträge und acht Bereichs-Smoke-Tests, synthetische Suite-Evidenzvorlage und datenschutzkonformes Runbook ergänzt; alle Zielzeilen bleiben bis zur realen Ausführung `NOT_EXECUTED`.
- `SC-011` durch `monitor.USP_StatisticsDistributionAnalysis` geschlossen.
- Histogrammzugriff je Datenbank vorab auf 1–250 priorisierte Statistiken begrenzt und durch `CATALOG_DEEP` geschützt.
- Numerische Evidenz für dominante Histogrammschritte, Gleichheits-/Range-Skew, Tail-Konzentration, Änderungen seit dem Statistikstand und inkrementelle Partitionsvariation ergänzt.
- Konkrete Histogrammgrenzwerte werden für diese Kennzahlen nicht benötigt; das Modul liest keine Datenzeilen und führt kein `UPDATE STATISTICS` aus.
- Skew-, Tail- und Modification-Signale ausdrücklich als Prüfhinweis statt als Planursache oder Out-of-Range-Beweis klassifiziert.
- Objektorchestrator und normalisierte Findings um getrennte, standardmäßig deaktivierte Statistikverteilungs-Opt-ins erweitert.
- Installer, Smoke Test, Spezialfall-API-Vertrag, Inventare, Beispiele, Referenz, Backlog und Testmatrix synchronisiert.
- Widersprüchliche Aussage in `Known_Issues.md` korrigiert: real getestet ist der Basisstand; die Spezialfallwelle bleibt `NOT_EXECUTED`.

## Stand 2026-07-17 – Spezialfallwelle `1.1.0-special.1`

- Dokumentierbare, datenschutzkonforme Testmatrix mit explizitem `NOT_EXECUTED`-Planungsstatus ergänzt.
- P0-Module für Datenbankintegrität, Kapazität, korrekt typisierte Performance Counter und kritische Engine-Ereignisse implementiert.
- Die erste P1-Welle mit IQP, interner Contention, Buffer Pool, Backupketten, Schema-/Designkorrektheit, tiefer Availability-Evidenz, Agent-/Alert-Monitoring und normalisierten Findings umgesetzt; die noch offene Statistikverteilung wurde anschließend in `1.1.0-special.2` geschlossen.
- Kostenintensive oder detailreiche Pfade standardmäßig deaktiviert oder opt-in ausgeführt.
- `USP_DiagnosticFindings` aggregiert ausschließlich definierte JSON-Vertragsfelder und übernimmt keine SQL-/Plantexte, Pfade, Mailinhalte oder freien Meldungstexte.
- Gesamtinstaller, vier Orchestratoren, Objekt-/Parameter-/Systemquelleninventare, Referenzen, Hilfe, Beispiele, Smoke Test und Spezialfall-API-Vertrag erweitert.
- Der Standalone-Installer übernimmt die kanonische, abhängigkeitssichere Include-Reihenfolge direkt aus `Install_All.sql`.
- Performance-Counter-Quotienten verwenden Zähler- und Basisdeltas; Backup-, Quorum- und Orchestratorstatus wurden in der statischen Tiefenprüfung präzisiert.
- Der frühere Basisstand war real getestet; für diese neue Implementierungswelle liegen noch keine dokumentierten Zielmatrixläufe vor.

## Stand 2026-07-17 – Verbindlicher Repository-Datenschutzvertrag

- Datenschutz-Liefergate ausdrücklich auf Repository-, GitHub- und Downloadartefakte begrenzt.
- Klargestellt, dass Resultsets, OUTPUT-Parameter sowie RAW-, CONSOLE- und JSON-Ausgaben weder anonymisiert noch fachlich reduziert werden.
- Reale interne Datenbankstrukturen, Namenskonventionen und proprietäre Metadaten aus Screenshots, Hardcopys, Chats, Uploads, Skripten, Logs und Diagnoseausgaben ausdrücklich aus Repositoryartefakten ausgeschlossen.
- Festgelegt, dass auch Zustimmung oder vorhandener Zugriff das Repositoryverbot nicht aufheben.
- Automatische Musterprüfung als unterstützenden Filter statt als Sicherheitsbeweis eingeordnet; uneindeutige Funde halten den Schreib- und Lieferprozess an.

## Stand 2026-07-17 – Datenschutzpräzisierung und Spezialfallanalyse

- Datenschutzgrenze korrigiert: Diagnostisch erforderliche Identitäts- und Umgebungswerte dürfen in interaktiven Runtime-Ausgaben erscheinen, aber niemals in Repository-, Dokumentations-, Test- oder Downloadartefakte übernommen werden.
- Verbindlichen Prüf- und Fragevertrag für persistierbare Artefakte ergänzt.
- Vorhandene Analyseabdeckung erneut auf Objekt-, Systemquellen- und Capability-Ebene geprüft.
- Frühere pauschale Abdeckungsprozentwerte verworfen und durch eine evidenzbasierte Prioritäts-, Kosten- und Bedingtheitsmatrix ersetzt.
- 25 fehlende oder zu vertiefende Spezialfallklassen als maschinenlesbaren Backlog dokumentiert.
- Integrität, Kapazität, kritische Engine-Ereignisse und korrekt typisierte Performance-Counter als erste technische Ausbaustufe priorisiert.
- Aktuelle Microsoft-Primärquellen sowie öffentliche Prüfkataloge des SQL Tiger Toolbox und des SQL Server First Responder Kit abgeglichen; kein fremder Code übernommen.

## Stand 2026-07-17 – Real getesteter Gesamtstand

- Gesamtinstaller und Frameworkfunktionen wurden nach Angabe des Projektverantwortlichen vollumfänglich real getestet.
- Falsche Sortierspalte in `monitor.USP_IndexOperationalStats` korrigiert.
- Mehrdeutige Spaltenreferenzen im dynamischen SQL von `monitor.USP_QueryStoreRegressions` vollständig mit dem CTE-Alias qualifiziert.
- `SET QUOTED_IDENTIFIER ON` für die Extended-Events-Procedures mit XML-Methoden sowie für die Index-Operational-Stats-Procedure ergänzt.
- Integrationsprüfung `165_Filter_Output_Contract.sql` für Listen-, Pattern-, JSON- und öffentliche Procedure-Verträge ergänzt.
- Der getestete Gesamtstand ist die neue kanonische Projektbasis.

## Stand 2026-07-16 – Abschluss der Repositorymigration

- Datenbankplatzhalter aus ausführbarer interner Logik entfernt; aktuelle Installationsdatenbank wird über `DB_ID()` ermittelt.
- Letzten umgebungsspezifischen Präfixhinweis aus den Beispielen entfernt.
- Procedure-Referenz auf die kanonischen `Code/...`-Pfade umgestellt.
- Veraltete Installations-, Test- und Recherchepfade korrigiert.
- Das bisherige Dateihashmanifest entfernt; Git ist die maßgebliche Versions- und Integritätsquelle.
- Systemquellen-, Capability-, Abhängigkeits- und Performance-/Risikokatalog als abstrahierte Migrationsergebnisse ergänzt.
- Root-README und lokale Arbeitskopie mit dem aktuellen `LICENSE.md`-Stand synchronisiert.
- Datenschutz- und Portabilitätsprüfung erneut ausgeführt.

## Stand 2026-07-16 – Compilekorrektur und Installer-Neubau

- Beschädigtes Unicode-Stringliteral in `monitor.USP_CheckFrameworkCapabilities` korrigiert.
- Unzulässige CTE-Spaltenreferenz im `TOP`-Ausdruck von `monitor.TVF_DatabaseCandidates` durch parameterbasierte Berechnung ersetzt.
- `IF`-/`TRY`-/`CATCH`-Blöcke in `monitor.USP_PlanCacheAnalysis`, `monitor.USP_QueryStoreAnalysis`, `monitor.USP_ExtendedEventsAnalysis` und `monitor.USP_ServerHealthAnalysis` eindeutig strukturiert.
- Server-Health-Orchestrator setzt Child-Statusvariablen vor jedem Modulaufruf zurück.
- Phaseninstaller und Gesamtinstaller vollständig aus den korrigierten kanonischen Objektdateien neu aufgebaut.
- Statische Prüfung um String-, Block-, Parameter- und Installer-Synchronitätskontrollen erweitert.

## Stand 2026-07-15 – Filter-, Ausgabe- und Memory-Vertrag

- Öffentliche API auf case-sensitive Bezeichner und case-insensitive Steuerwerte konsolidiert.
- `@AlleDatenbanken` entfernt; Datenbankscope über bracket-aware `@DatabaseNames`/Patterns.
- Listenparser für SQL-Namen, Full Object Names, allgemeine Textwerte und numerische IDs ergänzt.
- `like:`, `regex:` und `regexi:` mit versionsadaptiver Regex-Ausführung ergänzt.
- RAW-, CONSOLE-, NONE- und JSON-Ausgaben für alle öffentlichen Analyse-Procedures vereinheitlicht.
- Query Store auf explizite Quelldatenbanken und referenzierte Datenbanken getrennt; lokales N+1 plus globales Top N.
- Memory-Grant-Ausgabe um Workload Group, Resource Pool, Resource Semaphore, maximalen Request-Grant und Prozentkennzahlen erweitert.
- `RequestMaxMemoryGrantPercent` verwendet die präzise DMV-Quelle, ohne Datentyp-Suffix im öffentlichen Namen.
- Sämtliche Phaseninstaller und der Gesamtinstaller aus 81 kanonischen Objektdateien neu aufgebaut.
- Referenzhandbuch, Beispielaufrufe, Parameterinventar und QA-Berichte aktualisiert.

## Teststatus

Der Basisstand vor `1.1.0-special.1` wurde nach Angabe des Projektverantwortlichen real getestet. Commit `08b2d9d8c7adbadbf0996058d6bbb35b08c96ad8` des Stands `1.1.0-special.9` hat die commitbezogenen Actions-Läufe für SQL Server 2019, 2022 und 2025 einschließlich der eigenständigen SQL-Server-2025-Regex-Matrix erfolgreich abgeschlossen. Die Freigabe gilt mit Einschränkungen für den synthetischen Linux-Leerdatenbank-Scope; manuelle Feature-Positiv-, Grenzwert-, Last-, Windows-, Azure-MI- und externe Fälle bleiben gesondert.

<!-- BEGIN API_15_STATEMENT_CONTEXT -->
## Stand 2026-07-16 – CONSOLE-Default und Statementkontext

- `CONSOLE` ist frameworkweit die Standardausgabe; `RAW` bleibt der explizite technische Vertrag.
- Zentrale Inline-TVF `monitor.TVF_StatementText` extrahiert das laufende Statement aus den Byte-Offsets eines Requests.
- Live-Request-Module verwenden denselben Offsetvertrag; `USP_CurrentBlocking` und `USP_CurrentTransactions` geben nicht mehr irrtümlich den vollständigen Batch als aktuelles Statement aus.
- `monitor.USP_CurrentRequests` zeigt Modulname und -typ, Byte-/Zeichenoffsets, Start-/Endzeilen und das exakte aktuelle Statement.
- Vollständiger Batch-/Modultext und Input Buffer sind separat opt-in; `@MaxSqlTextZeichen = NULL/0` liefert vollständige Texte.
- CONSOLE enthält ein eigenes schmales `SQL-Kontext`-Resultset; JSON verwendet die benannten Arrays `requests`, `statements`, `batches`, `inputBuffers` und `warnings`.
- Optionale Modul- und Input-Buffer-Auflösung erfolgt erst nach dem Ergebnislimit, um unnötige Arbeit zu vermeiden.
- Der technische Ausführungskontext umfasst unter anderem Verschachtelungsebene, Transaction-/Connection-ID, Scheduler/Task, Workload Group, Resource Pool sowie Statement-Handle und Statement-Context-ID.
- `@MaxSqlTextZeichen` ist frameworkweit vereinheitlicht: positiv kürzt, `NULL`/`0` liefert den vollständigen Text, negative Werte sind ungültig.
<!-- END API_15_STATEMENT_CONTEXT -->

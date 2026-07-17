# Release Notes

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

Der Basisstand vor `1.1.0-special.1` wurde nach Angabe des Projektverantwortlichen real getestet. Die Spezialfallwelle bis einschließlich `1.1.0-special.2` ist erst nach Ausführung und Dokumentation der Zielmatrix als laufzeitgetestet zu kennzeichnen.

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

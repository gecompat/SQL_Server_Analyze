# Release Notes

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

Der vorliegende Gesamtstand wurde nach Angabe des Projektverantwortlichen vollumfänglich real getestet. Die genaue Versions-, Editions-, Plattform- und Berechtigungsmatrix soll für weitere Freigaben separat dokumentiert werden.

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

# Testablauf für das Release-Gate

**Stand:** 18. Juli 2026  
**Runner:** `Code/Tests/Run_Release_Gate.sql`  
**Zielstatus vor Ausführung:** `NOT_EXECUTED`

## 0. Statische Repositoryprüfung

Vor Installation oder Runtime-Tests aus dem Repositoryroot ausführen:

```powershell
pwsh ./Code/Tests/Static/900_Validate_Analysis_Documentation.ps1
```

Erwartung:

- Prozess-Exitcode `0`.
- `Referenced procedures`, `Canonical source procedures` und `Procedure pages` ergeben jeweils `84`.
- Letzte Meldung: `Analysis documentation validation succeeded.`
- Bei einem Fehler keine Installation und kein SQL-Release-Gate starten, sondern zuerst Referenz, SQL-Signatur, Procedure-Seite, Beispielparameter oder Markdownlink korrigieren.

Der gleiche Test läuft in GitHub Actions für relevante Pull Requests und Änderungen an `main`. Ein grüner statischer Test ersetzt weder die Runtime-Tests noch die manuelle fachliche und datenschutzbezogene Prüfung.

## 0.1 Automatisiertes synthetisches Linux-Target für SQL Server 2022

Der Workflow `.github/workflows/sqlserver-2022-linux-release-gate.yml` führt für relevante T-SQL-Änderungen ein isoliertes Runtime-Gate gegen `mcr.microsoft.com/mssql/server:2022-latest` aus.

Dabei gilt:

- SQL Server 2022 Developer läuft nur für die Dauer des GitHub-Actions-Jobs in einem Container.
- Die Installationsdatenbank, das Kennwort und alle Laufzeitwerte werden erst im Job synthetisch erzeugt.
- Der Repositorybestand wird in ein temporäres Runnerverzeichnis kopiert; nur dort wird `[DeineDatenbank]` ersetzt.
- Der Container erhält die temporäre Codekopie schreibgeschützt.
- Installer und `Run_Release_Gate.sql` laufen mit `sqlcmd -b` und brechen beim ersten SQL-Fehler ab.
- Anschließend läuft die SQL-Server-2022-Berechtigungsmatrix im selben isolierten Container.
- Es werden keine vollständigen SQLCMD-Ausgaben oder Resultsets als dauerhaftes Artefakt gespeichert.
- Nach dem Lauf wird der Container auch bei Fehlern entfernt.

Dieses Target deckt SQL Server 2022 unter Linux mit Compatibility Level 160 und der case-sensitiven Collation `SQL_Latin1_General_CP1_CS_AS` ab. SQL Server 2019 und 2025 werden durch die separaten Targets in Abschnitt 0.3 und 0.4 geprüft. Nicht abgedeckt bleiben Windows, optionale Feature-Positivfälle und produktionsnahe Lastzustände.

## 0.2 Automatisierte SQL-Server-2022-Berechtigungsmatrix

Der Workflow führt nach dem allgemeinen Release-Gate `Code/Tests/Permissions/110_SQL_Server_2022_Permission_Matrix.sql` aus. Die Matrix erzeugt ausschließlich temporäre synthetische SQL-Logins, Datenbankbenutzer und eine Datenbankrolle. Das Kennwort entsteht erst im Job, wird maskiert und nicht im Repository gespeichert.

Geprüfte Szenarien:

1. vollständig eingeschränkter Login ohne Server- oder Database-State-Recht;
2. ausschließlich `VIEW SERVER STATE` als Legacy-Abgrenzung auf SQL Server 2022;
3. `VIEW SERVER PERFORMANCE STATE` mit vollständiger Current-Sessions-Sicht;
4. ausschließlich `VIEW DATABASE STATE` als Legacy-Abgrenzung;
5. `VIEW DATABASE PERFORMANCE STATE` für Query-Store-Capabilities;
6. synthetische Rollenmitgliedschaft über den `IS_MEMBER`-Fallback;
7. sysadmin-Bypass für eine aktive Gruppenpolicy.

Zusätzlich wird vor Aktivierung der synthetischen Policy bestätigt, dass die ausgelieferte leere Policy geschützte Analyseklassen mit `OPEN_POLICY` freigibt. Nach erfolgreichem Lauf wird die leere Standardpolicy wiederhergestellt und jeder synthetische Principal entfernt.

Verbindliche Erwartungen:

- eingeschränkte Current-Sessions-Sicht liefert kontrolliert `DENIED_PERMISSION` oder `AVAILABLE_LIMITED` und gültiges JSON statt eines unkontrollierten Abbruchs;
- die SQL-Server-2025-Fehlernummer 371 für fehlendes `VIEW SERVER PERFORMANCE STATE` wird kontrolliert als `DENIED_PERMISSION` klassifiziert;
- `VIEW SERVER STATE` umfasst auf SQL Server 2022 die neue Berechtigung `VIEW SERVER PERFORMANCE STATE`; umgekehrt entsteht kein `VIEW SERVER STATE`;
- `CURRENT_SESSIONS` ist capability-seitig mit `VIEW SERVER PERFORMANCE STATE` verfügbar, kann wegen weiterer geschützter Teilquellen aber weiterhin kontrolliert `AVAILABLE_LIMITED` liefern;
- `VIEW DATABASE STATE` umfasst `VIEW DATABASE PERFORMANCE STATE`; umgekehrt entsteht kein `VIEW DATABASE STATE`;
- beide Database-State-Szenarien erfüllen die geprüften Query-Store-Performance-Capabilities;
- nicht berechtigte geschützte Klassen liefern `NO_MATCH`, Rollenmitglieder `IS_MEMBER` und sysadmin `SYSADMIN`;
- sieben Szenarien werden vollständig ausgeführt und der Test endet mit `StatusCode=AVAILABLE`.

## 0.3 Automatisiertes synthetisches Linux-Target für SQL Server 2019

Der Workflow `.github/workflows/sqlserver-2019-linux-release-gate.yml` führt dieselbe Installation und dieselben dreizehn Release-Gate-Suiten gegen `mcr.microsoft.com/mssql/server:2019-latest` aus. Die synthetische Installationsdatenbank verwendet Compatibility Level 150 und dieselbe case-sensitive Collation wie die anderen Testtargets.

Anschließend wird `Code/Tests/Permissions/110_SQL_Server_2019_Permission_Matrix.sql` ausgeführt. Die Matrix prüft fünf vollständig synthetische Kontexte:

1. vollständig eingeschränkter Login;
2. Login mit `VIEW SERVER STATE`;
3. Benutzer mit `VIEW DATABASE STATE`;
4. Rollenmitglied über den `IS_MEMBER`-Fallback;
5. sysadmin-Bypass.

Verbindliche Erwartungen:

- der Feature- und Capability-Katalog verwendet vor SQL Server 2022 ausschließlich `VIEW SERVER STATE` und `VIEW DATABASE STATE`;
- kein SQL-Server-2022-Performance-State-Recht wird für die geprüften 2019-Capabilities vorausgesetzt;
- ein eingeschränkter Kontext liefert kontrollierte Limited-/Denied-Statuswerte und gültiges JSON;
- `VIEW SERVER STATE` macht die Current-Sessions-Capability verfügbar;
- `VIEW DATABASE STATE` erfüllt die geprüften Query-Store-Capabilities;
- offene Policy, `NO_MATCH`, `IS_MEMBER` und `SYSADMIN` werden getrennt bestätigt;
- fünf Szenarien werden vollständig ausgeführt und der Test endet mit `StatusCode=AVAILABLE`.

Das 2019-Target speichert keine vollständigen SQLCMD-Ausgaben oder Resultsets. Fehlerzusammenfassungen bleiben generisch, werden höchstens einen Tag aufbewahrt und der Container wird auch bei Fehlern entfernt.

## 0.4 Automatisiertes synthetisches Linux-Target für SQL Server 2025

Der Workflow `.github/workflows/sqlserver-2025-linux-release-gate.yml` verwendet das offizielle Image `mcr.microsoft.com/mssql/server:2025-latest`, erzwingt Product Major Version 17, Compatibility Level 170 und die gemeinsame case-sensitive Collation. Installer, 18-Suite-Release-Gate einschließlich P0-, P1-IQP-, P1-Contention-, P1-Speicher- und P1-Backupkettenvertrag und die SQL-Server-2022+-Berechtigungsmatrix laufen gegen ausschließlich synthetische Job- und Principalnamen.

Wie bei den anderen Targets werden Kennwort und Datenbank erst im Job erzeugt, vollständige Ausgaben nicht als Artefakt persistiert, Fehlerartefakte auf eine generische Kurzfassung und einen Tag Retention begrenzt und der Container immer entfernt.

## 1. Lokale Testkopie vorbereiten

1. Exakt den zu testenden Commit in eine lokale, nicht zur Veröffentlichung vorgesehene Arbeitskopie übernehmen.
2. In dieser lokalen Testkopie den generischen Platzhalter `[DeineDatenbank]` in den SQL-Dateien durch die Testdatenbank ersetzen.
3. Die ersetzten Dateien, SQLCMD-Ausgaben und Resultsets niemals committen oder als Repositoryartefakt speichern.
4. Für die Verbindung integrierte Authentifizierung oder eine sichere interaktive Anmeldung verwenden. Kennwörter gehören weder in Befehlszeilen noch in Nachweise.

## 2. Installation prüfen

Aus dem Verzeichnis `Code/Install` den Gesamtinstaller im SQLCMD-Modus mit Abbruch bei SQL-Fehlern ausführen. Generische Befehlsform:

```text
sqlcmd -S "<ZIEL>" -d "<INSTALLATIONSDATENBANK>" -E -b -i "Install_All.sql"
```

Erwartung:

- Prozess-Exitcode `0`.
- Kein unbehandelter SQL-Fehler.
- Keine fehlende Include-Datei.
- Keine lokale Installer- oder Konsolenausgabe in das Repository übernehmen.

## 3. Automatisiertes Release-Gate ausführen

Aus dem Verzeichnis `Code/Tests` ausführen:

```text
sqlcmd -S "<ZIEL>" -d "<INSTALLATIONSDATENBANK>" -E -b -i "Run_Release_Gate.sql"
```

Der Runner beendet sich beim ersten SQL-Fehler und führt folgende achtzehn Suiten aus:

1. Smoke Test
2. Parameter-API-Vertrag
3. Filter- und Ausgabe-Vertrag
4. Spezialfall-API-Vertrag
5. Spezialfall-Laufzeitvertrag
6. Synthetischer P0-Laufzeitvertrag mit 15 Positiv-, Leer-, Grenz- und Resetfällen; `INT-DENIED` und `CAP-DENIED` folgen anschließend in der versionsspezifischen Berechtigungsmatrix unter einem eingeschränkten Serverlogin
7. Versionsadaptiver P1-IQP-Laufzeitvertrag
8. P1-Contention-Laufzeitvertrag mit einer realen Ein-Sekunden-Messung und deterministischem Reset-Rechenvertrag
9. Read-only P1-Speicher-Laufzeitvertrag einschließlich ausdrücklich aktiviertem, begrenztem Buffer-Descriptor-Scan
10. Synthetischer P1-Backupketten-Laufzeitvertrag auf dem plattformspezifischen Nullgerät ohne Restore
11. Common
12. Current State
13. Object und Index
14. Plan Cache
15. Query Store
16. Extended Events
17. Infrastructure
18. Server Health

Erwartung bei vollständigem Erfolg:

- Prozess-Exitcode `0`.
- Letztes Resultset: `StatusCode=AVAILABLE`, `IsPartial=0`, `ExecutedSuites=18`.
- Kein `THROW`, kein unbehandelter Fehler und kein vorzeitiges Ende.

## 4. Spezialfallmatrix ausführen

Danach die für das Target anwendbaren Fälle aus `Metadata/Quality/Special_Case_Test_Cases.csv` ausführen. Capability-, Leerzustands-, Positiv-, Grenzwert-, Berechtigungs-, Reset- und Lastfälle bleiben getrennte Nachweise. Nicht vorhandene Features dürfen nicht als erfolgreicher Positivtest gewertet werden.

Für `USP_SpecialFeatureInventory` sind der vollständig sichtbare Leerzustand, eingeschränkte Metadatensichtbarkeit, die Ausgabegrenze und je ein positiver Fall für alle 18 Featurecodes getrennt vorgesehen. Eine Nullzählung gilt nicht als Abwesenheitsbeweis und `CONFIGURED_ONLY` nicht als Nutzungsnachweis.

Für `USP_InMemoryOltpAnalysis` müssen negativer Feature-Gate, schema-only Objekt, Tabellen-/Consumer-Speicher, Hashkatalog, kontrollierter Hashketten-Opt-in, Checkpointzustände, Transaktionsaggregate, benannter und Defaultpool, Quellberechtigungen, Filter und Ergebnisgrenzen getrennt dokumentiert werden. Hashketten nur gegen synthetische Testobjekte und unter kontrolliertem Lastbudget ausführen.

Für `USP_TemporalAnalysis` müssen negativer Feature-Gate, Current-/History-Zuordnung, sichtbare Periodenspalten, endliche und unendliche Retention, deaktivierter datenbankweiter Cleanup, approximative History-Größe/-Zeilen, Ratio-Grenze, vorhandene und fehlende Perioden-Indexbaseline, speicheroptimierte Current-Tabelle, Quellberechtigungen, Filter und Ergebnisgrenzen getrennt dokumentiert werden. Ein nach `SYSTEM_VERSIONING=OFF` getrenntes synthetisches Paar muss als bewusst nicht zuverlässig erkennbar bestätigt werden; keine echten Current- oder History-Zeilen als Evidenz speichern.

Für `USP_ServiceBrokerAnalysis` müssen negativer Feature-Gate, aktivierte Konfiguration ohne Objekte, deaktivierter Broker mit sichtbaren Objekten, Queue-Schalter, approximative Queue-Kapazität, Retention, interne Aktivierung, Transmission-Alter und gemeldeter Status, Conversation-Zustände und Lifetimes, isolierte Quellenberechtigungen, Filter und Ergebnisgrenzen getrennt dokumentiert werden. Der Contract-Test muss bestätigen, dass die Nachrichtenkörperspalte nicht referenziert und keine Queue- oder Conversation-Änderung ausgeführt wird. Testnachweise enthalten ausschließlich synthetische Zustände und niemals Queue-Nutzdaten.

Für `USP_FullTextAnalysis` müssen negativer Feature-Gate, Komponenten-/Katalogzustand, Indexschalter, aktuelle und lange/abgebrochene Populationen, Retry-/Fehlerbatches, Dokumentfehleraggregate, Fragmente, semantische Population, Memory-/FDHost-Kontext, isolierte Quellenberechtigungen, Filter, Ergebnisgrenzen und der statische Inhalts-/DDL-Ausschluss getrennt dokumentiert werden.

Für `USP_DataCaptureDeepAnalysis` müssen negativer Feature-Gate, CT ohne/mit gültigem/ungültigem/zukünftigem Consumer-Wasserstand, Auto-Cleanup, CDC-Capture-Instanzen, fehlende/disabled Jobs, kontinuierliche und zeitgesteuerte Latenz, Scanfehler, Cleanup-Alter und Drop-Pending sowie lokale Replikationsrückstände, Agentstatus, inaktive Subscription, Merge-Konflikt/Retry, mehrere lokale Distributionsdatenbanken, Remote-Distributor-Lücke, isolierte Berechtigungen, Filter, Ergebnisgrenzen und der statische Nutzdaten-/Credential-/Command-/DDL-Ausschluss getrennt dokumentiert werden. Es werden nur synthetische Zustände persistiert.

Für `USP_EncryptionAnalysis` sind No-TDE, Transition, suspendierter/abgebrochener Scan, Zertifikatsfenster, lokaler Exportnachweis, erwartete explizite Backupverschlüsselung, aggregierte Always-Encrypted-/Ledger-Metadaten, Version und Berechtigung getrennt zu prüfen. Schlüssel-, Medien- oder Kontoinhalte werden nicht in Testnachweise übernommen.

Für `USP_MaintenanceOperations` sind Leerzustand, aktive/pausierte resumierbare Operation, blockierter Request, Rollbackkontext, PVS-Verhalten auf 2019/2022/2025, `NOT_REQUESTED` ohne Jobfilter, ausdrücklich gewählte synthetische Jobüberlappung, Berechtigung und read-only Vertrag getrennt zu prüfen.

Kostenintensive Pfade nur kontrolliert und opt-in testen:

- Page Details und Event-XML
- Contention-Sampling
- Buffer-Pool-Verteilung
- Schema-Design
- Statistikverteilung
- In-Memory-OLTP-Hashketten
- breite Cross-Database-Auswahl

## 5. Ergebnis zurückmelden

Für die Rückmeldung genügen je Target:

- synthetische `TargetId`
- getesteter Commit-SHA
- Exitcode der statischen Repositoryprüfung
- Exitcode des Installers
- Exitcode des Release-Gates
- Ergebnis der Berechtigungsmatrix
- letzte erfolgreich gestartete Suite oder generischer Fehlercode
- `PASS`, `PASS_WITH_LIMITATIONS` oder `FAIL`
- generische Einschränkungen, beispielsweise `FEATURE_NOT_AVAILABLE` oder `DENIED_PERMISSION`

Nicht zurückmelden oder in Dateien übernehmen:

- Server-, Instanz-, Domain-, Benutzer-, Firmen-, Kunden- oder Datenbanknamen
- interne Objekt-, Schema- oder Jobnamen
- SQL-/Plantexte, Pfade, Mailadressen oder freie Runtime-Meldungen
- Screenshots oder Logs mit nicht vorab geprüften Inhalten

Die Vorlagen `Metadata/Quality/Test_Matrix.csv` und `Metadata/Quality/Release_Gate_Evidence.csv` bleiben bis zur bestätigten realen Ausführung auf `NOT_EXECUTED`. Bevor Testergebnisse in Git oder downloadbare Dateien übernommen werden, wird der konkrete, bereits bereinigte Inhalt gemeinsam geprüft.

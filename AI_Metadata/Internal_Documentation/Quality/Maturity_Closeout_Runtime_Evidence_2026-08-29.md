# Lokale Runtimeevidenz zum Reifeabschluss

**Stand:** 29. August 2026
**Status:** `LOCAL_WORKTREE_EVIDENCE`
**Datenbasis:** ausschließlich synthetische Fixtures

## Einordnung

Diese Evidenz beschreibt tatsächlich ausgeführte lokale Läufe des noch nicht commitgebundenen Arbeitsstands. Sie ersetzt weder die unabhängig verifizierte historische Release-Evidenz in `Metadata/Quality/Test_Matrix.csv` noch einen späteren Actions-Nachweis des resultierenden Commits. Konkrete Run-IDs, lokale Pfade, Credentials, Containerbezeichner und Laufzeitausgaben werden nicht im Repository gespeichert.

## Vollständige native Release-Gates

Der generierte Standalone-Installer umfasste 165 kanonische SQL-Dateien und wurde je Ziel vollständig installiert. Anschließend lief `Code/Tests/Run_Release_Gate.sql` mit 34 Suiten. Jede Umgebung verwendete `SQL_Latin1_General_CP1_CS_AS`, den Docker-Provider und ein scopegebundenes Cleanup.

| SQL Server | Plattform | Ergebnis | Cleanup |
|---|---|---|---|
| 2019 | Linux-Container über Docker | `PASS`, 34 Suiten | `CLEANUP_SUCCEEDED` |
| 2022 | Linux-Container über Docker | `PASS`, 34 Suiten | `CLEANUP_SUCCEEDED` |
| 2025 | Linux-Container über Docker | `PASS`, 34 Suiten | `CLEANUP_SUCCEEDED` |

Die Läufe bestätigen die in das Release-Gate aufgenommenen Basisverträge von `OPS-005` bis `OPS-009` sowie den TABLE-Collationvertrag auf den drei nativen Engineversionen. Sie bestätigen keine abweichende Server- oder `tempdb`-Collation.

## Analyze-Beispiele auf SQL Server 2025

Die sechs zuvor offenen Beispiele liefen mit ihrem katalogisierten Verify-Ablauf über den primären Docker-Provider. Jeder Lauf installierte den vollständigen Frameworkstand, führte Setup, Analyzer-Assertion und Cleanup aus und entfernte anschließend seine Labressourcen.

| Beispiel | Szenario | Ergebnis |
|---|---|---|
| `QUERY-STORE-001` | `LAB-QS-001` | `PASS` |
| `TEMPDB-001` | `LAB-TEMP-001` | `PASS` |
| `STATISTICS-001` | `LAB-PLAN-002` | `PASS` |
| `MEMORY-GRANTS-001` | `LAB-MEM-001` | `PASS` |
| `EXECUTION-PLAN-001` | `LAB-EXECPLAN-001` | `PASS` |
| `INDEX-USAGE-001` | `LAB-IDX-003` | `PASS` |

Zusammen mit der bereits vorhandenen Evidenz für `BLOCKING-001` ist der definierte Sieben-Beispiele-Umfang von `ANALYZE-LAB-001` umgesetzt. Die sechs neuen Beispiele benötigen nach der impact-basierten Teststrategie keine zusätzliche native Version oder einen zweiten Provider, weil ihre Änderungen keine provider- oder versionsspezifische Lifecyclelogik einführen.

## Durch Runtimeevidenz korrigierte Abweichungen

Die Läufe fanden und regressierten folgende Vertragsabweichungen:

- Der Runner bindet seine erlaubte temporäre Wurzel jetzt vor Änderungen an `TEMP` und `TMP`.
- Ein fehlgeschlagenes Interactive-Setup führt ohne `KeepOnFailure` ebenfalls das registrierte Cleanup aus.
- Das Query-Store-Fixture übergibt eine vorab berechnete Variable an `EXEC`.
- Die TempDB-Assertion unterscheidet aktive Task- und abgeschlossene Session-Allokation im expliziten `tempdb`-Kontext.
- Das Execution-Plan-Fixture übergibt keinen abgeleiteten Planquellenstatus als Eingabe und akzeptiert den öffentlichen Status `PARTIAL`.
- Die synthetische `OPS-006`-Procedure wird in einem eigenen dynamischen Batch erstellt.
- `USP_CurrentOverview` aggregiert Child-JSON über explizit collatierte temporäre Textfelder.

## Verbleibende Evidenzgrenzen

Die folgenden Fälle wurden nicht als bestanden verbucht:

- `OPS-005`: kontrollierter Remote-Erfolg, gesonderter Timeout, Providerabweichung und ein eigenständiger Berechtigungsfall;
- `OPS-006`: positiv featuregebundene persistierte SKU-Evidenz und eine tatsächlich nicht unterstützte Quelle;
- `OPS-007`: dormanter oder fremder ressourcenauffälliger Cursor und eigenständiger Berechtigungsfehler;
- `OPS-008`: kontrollierte kurze und lange Historien, Wachstum und fehlende optionale Quellen;
- `OPS-009`: expliziter Leerzustand und nachgewiesene partielle Metadatensichtbarkeit;
- `COLL-001`: abweichende Server-, `tempdb`- und Frameworkcollations sowie die vollständige per-Datei-Härtung;
- Podman-Läufe für die sechs neuen Analyze-Beispiele.

Diese Grenzen halten `OPS-005` bis `OPS-009` und `COLL-001` im Status `PARTIAL_PRODUCT_FUNCTION`. Sie erweitern die öffentliche Collationgarantie nicht.

## Ergänzende OPS-008-Viewgegenprobe vom 5. Oktober 2026

Ein neu erzeugter SQL-Server-2025-Linux-Container über Docker führte die
vollständige Frameworkinstallation und den erweiterten Runtimevertrag
`122_OPS008_Msdb_Health_Runtime_Contract.sql` aus. Die Instanz verwendete
`Latin1_General_100_CS_AS`, die Frameworkdatenbank
`SQL_Latin1_General_CP1_CS_AS`. Der Test veränderte keine `msdb`-Historie
und versendete keine Nachricht.

Die Baseline-Procedure erkannte ausschließlich Tabellen und klassifizierte
die vorhandene View `msdb.dbo.sysmail_allitems` als `UNSUPPORTED`.
Der neue Test reproduzierte diese Abweichung mit Fehler `54875`. Nach der
Korrektur auf Tabellen und Views bestand derselbe Vertrag im selben
isolierten Container. Der Test verlangte `AVAILABLE` für die Mailquelle
und verglich Zeilenanzahl sowie beide Zeitgrenzen mit der direkten View.
Die übrigen Quellenstatus-, Begrenzungs- und eingeschränkten Pfade
bestanden ebenfalls. Container, Volume und temporärer State wurden entfernt.

Die Engine-Major-Version 17 wurde vom Lab verifiziert; die genaue
ProductVersion wurde für diese Gegenprobe nicht erfasst. Der Nachweis
gilt ausschließlich für den beschriebenen lokalen Vertragsumfang.
Kontrollierte kurze und lange Historien, Wachstum und fehlende optionale
Quellen bleiben offen. Ein vollständiges Release-Gate und weitere native
Versionen wurden in dieser Gegenprobe nicht ausgeführt.

## Ergänzende OPS-008-Historiengegenprobe vom 5. Oktober 2026

`TestLab/Invoke-Ops008MsdbHistoryScenario.ps1` bestand in einem neuen
SQL-Server-2025-Linux-Docker-Container mit vollständiger Frameworkinstallation,
Smoke-Test und dem bestehenden Runtimevertrag `122`. Der zusätzliche Vertrag
`TestLab/Scenarios/OPS-008/history-window.sql` verlangte fünf leere
Historienquellen mit `AVAILABLE`, `RowCount = 0` und leeren Zeitgrenzen.

Drei native Backups einer eigenen synthetischen Datenbank erzeugten
kontrollierte Backupdatensätze. Nur deren Datumsfelder wurden auf festgelegte
Fixturewerte gesetzt. Die Analyzer-Aufrufe lieferten nacheinander eine,
zwei und drei Zeilen in der Backuphistorie sowie die exakten kurzen und
langen Zeitgrenzen. Eine begrenzte Erweiterung der `msdb`-Datendatei um
mindestens 8 MB wurde in `SizeMb` sichtbar und mit `sys.master_files`
abgeglichen. Der Analyzer veränderte die kontrollierte Historienanzahl nicht.

Die Instanz verwendete `Latin1_General_100_CS_AS`, die Frameworkdatenbank
`SQL_Latin1_General_CP1_CS_AS`. Das Lab verifizierte Engine-Major-Version 17;
die genaue ProductVersion wurde in diesem Lauf nicht erfasst. Container,
Volume einschließlich Backupdatei und temporärer State wurden entfernt.
Secrets und konkrete Runtimeidentitäten sind nicht Teil dieser Evidenz.

Der Nachweis gilt für kontrollierte Leerfälle aller fünf Quellen,
Backupanzahl und Backupzeitfenster sowie aktuelle Dateigröße nach einer
kontrollierten Erweiterung. Er belegt keine Retentionpolicy, Wachstumsrate,
Restorefähigkeit oder nicht leere Zeitfenster der vier weiteren Quellen.
Tatsächlich fehlende optionale Quellen bleiben offen. Der Lauf ist kein
vollständiges Release-Gate und kein Nachweis einer weiteren nativen Engine.

## Ergänzende OPS-008-Restoregegenprobe vom 5. Oktober 2026

Der erweiterte Runner bestand erneut mit Frameworkinstallation, Smoke-Test,
Runtimevertrag `122`, Backupzeitfenstern und Dateiwachstum. Zusätzlich
bestand `TestLab/Scenarios/OPS-008/restore-window.sql` auf einem neuen
SQL-Server-2025-Linux-Docker-Lab. Drei native Restores verwendeten
ausschließlich die eigene Fixture-Backupdatei und eine zu Beginn nicht
vorhandene Zieldatenbank. Die Historienzeitstempel der drei eigenen
Restoredatensätze wurden kontrolliert gesetzt. Der Analyzer lieferte die
exakten Anzahlen und kurzen beziehungsweise langen Restorezeitfenster.
Container, Volume und temporärer State wurden entfernt.

Ein vorangehender separater Versuch zur optionalen Quellenabwesenheit
scheiterte bei der Umbenennung von `msdb.dbo.sysmail_allitems` mit Fehler
`15001`. Auch dessen eigener Container, Volume und State wurden entfernt.
Dieser Abwesenheitsversuch wird nicht als bestanden gewertet und ist kein
Teil des reproduzierbaren Restorevertrags. Der Quellenabwesenheitsnachweis
bleibt offen.

Die Instanz- und Frameworkcollations entsprechen der vorangehenden
Historiengegenprobe. Das Lab verifizierte Major-Version 17; ProductVersion
wurde nicht erfasst. Der Lauf ist lokale Vertrags- und Fixtureevidenz,
kein vollständiger Release-Gate-Lauf oder Nachweis für fremde Backups.
Nicht leere Agent-, Mail- und Maintenance-Historien bleiben ebenfalls offen.

## Ergänzende OPS-008-Agent-Aggregatgegenprobe vom 8. Oktober 2026

Eine neue eigene SQL-Server-2025-Linux-Docker-Instanz bestand die vollständige
Coreinstallation, den Smoke-Test, Runtimevertrag `122` und die synthetische
Agent-Fixture [TEST-0001](../../../../TestLab/Scenarios/OPS-008/agent-history.sql).
Die Fixture erzeugte einen deaktivierten eigenen Job und injizierte in einer
eigenen Transaktion nacheinander eine, zwei und drei native `sysjobhistory`-
Zeilen einschließlich Job- und Stepzeilen. Der Analyzer lieferte jeweils die
exakte Anzahl, `AVAILABLE` und NULL für beide Zeitgrenzen. Der vollständige
Quellbestand einschließlich Identität, Meldung, Datum, Uhrzeit und Dauer blieb
unverändert. Die Fixturetransaktion wurde zurückgerollt; Job und Historyzeilen
waren danach nicht mehr vorhanden.

Die Gegenprobe am Original bestätigte drei bestehende Mengenlimitfehler:
NULL löste Fehler `1014` aus, ein negatives Limit im JSON-Pfad Fehler `127`.
Mit Limit 1 enthielten TABLE und CONSOLE jeweils sechs Quellenzeilen,
JSON dagegen eine. Die gezielte Korrektur normalisiert NULL auf 0 und begrenzt
den gemeinsamen temporären Ergebnisbestand vor der Ausgabe. Negative Werte
liefern `INVALID_PARAMETER` mit leeren fachlichen Ergebnissen. Die Quelltabellen
werden durch diese Begrenzung nicht verändert.

Runtimevertrag `122` prüft die vollständige TABLE-/CONSOLE-/JSON-Werteparität
für NULL, 0 und 1. Eine zusätzliche lokale DataReader-Gegenprobe bestand für
RAW und JSON mit NULL, 0, 1 und einem negativen Limit. Sie prüfte beide
RAW-Resultsets, die Feldreihenfolge, alle acht fachlichen Werte und den
Modulstatus. `EvidenceRows` erhält die Anzahl sämtlicher ermittelter Quellen
vor dem Ausgabelimit; dieser bestehende RAW-Vertrag bleibt erhalten.

Die Instanz verwendete `Latin1_General_100_CS_AS`, die Frameworkdatenbank
`SQL_Latin1_General_CP1_CS_AS`. Das Lab verifizierte Engine-Major-Version 17;
ProductVersion und Compatibility Level wurden nicht separat erfasst. Der eigene Run
und sein Volume wurden entfernt, die temporäre Secretdatei gelöscht und
sämtliche zuvor vorhandenen Hostressourcen unverändert wiedergefunden.
Runtimeidentitäten und Rohdaten bleiben außerhalb des Repositorys.

Der öffentliche Runner bestand danach mit `-Scenario AgentHistory` in einem
weiteren eigenen frischen SQL-2025-Lab einschließlich endgültigem Vertrag
`122`, positiver Fixture und `REMOVED`-Cleanup. Der Standardpfad für Backup
und Restore wurde in diesem Schritt nicht erneut ausgeführt. Ein lokaler
Fehlerpfadtest des tatsächlichen Runner-`finally` mit simuliert scheiternder
State-Löschung bestätigte die garantierte Mutexfreigabe und -entsorgung;
dieser Test ist Mockevidenz und startet keine native Runtime.

Diese injizierte Tabellenfixture belegt keine Agent-Ausführung, keine
Interpretation der Datums- oder Dauerfelder und keine Retentionpolicy.
Nicht leere Mail- und Maintenance-Historien, tatsächlich fehlende optionale
Quellen, weitere Plattformen und zusätzliche native Engines bleiben offen.
Der Lauf ist ein lokaler begrenzter Reifenachweis und kein Release-Gate.

## Ergänzende OPS-008-Mail-/Maintenance-Gegenprobe vom 8. Oktober 2026

Eine neue eigene SQL-Server-2025-Linux-Docker-Instanz bestand die vollständige
Coreinstallation, den Smoke-Test, Runtimevertrag `122` und die
[Mail-/Maintenance-Fixture](../../../../TestLab/Scenarios/OPS-008/mail-maintenance.sql)
am unveränderten Analyzerstand nach PR #271. Die Fixture verlangte leere
`sysmail_mailitems`-, `sysmail_allitems`- und `sysmaintplan_log`-Quellen sowie
deaktivierte Database-Mail-XPs. Sie injizierte innerhalb einer eigenen
Transaktion nacheinander eine, zwei und drei synthetische Zeilen je Tabelle.
Die Mailzeilen besaßen einen generischen Empfängertext ohne Adresse und
keine Profil-, Account- oder Queuebindung. Die Maintenancezeilen waren reine
Logzeilen ohne Plan-, Subplan- oder Jobbindung. Es wurde weder eine Nachricht
gesendet noch ein Maintenance- oder Agent-Job ausgeführt.

Die drei Zeitstufen wurden absichtlich außerhalb der Zeitreihenfolge
eingefügt. Je Stufe prüften NONE, TABLE und CONSOLE die vollständige Anzahl,
`MIN(send_request_date)` beziehungsweise `MIN(start_time)` und die
entsprechenden MAX-Werte gegen feste Erwartungen und native Aggregate.
Die neun Aufrufe bestätigten `AVAILABLE`, sechs Quellenzeilen und die
bestehenden Evidenzgrenzen. TABLE und CONSOLE besaßen vollständige Parität
aller acht Fachfelder mit JSON innerhalb desselben Aufrufs. Alle Quellspalten
wurden vor und nach jedem Aufruf mit stabiler Sortierung und
`INCLUDE_NULL_VALUES` NULL-sicher verglichen. Die Callertransaktion blieb
committable mit `@@TRANCOUNT=1`; `LOCK_TIMEOUT=137` blieb erhalten.
Der Rollback entfernte sämtliche injizierten Zeilen. Identitätszähler werden
durch einen Tabellenrollback nicht als zurückgesetzt behauptet; der eigene
Container samt Volume wurde anschließend entfernt.

Die native Schema- und FK-Vorprobe erfasste `ProductVersion=17.0.4075.5` und
Compatibility Level 170 der Frameworkdatenbank. Server und `tempdb` verwendeten
`Latin1_General_100_CS_AS`, die Frameworkdatenbank
`SQL_Latin1_General_CP1_CS_AS`. Die endgültige Runnerfassung erfasst Build und
Compatibility Level zusätzlich vor ihrem Cleanup. Runtimeidentitäten,
Secrets und Rohdaten bleiben außerhalb des Repositorys.

Ein erster Fixtureversuch scheiterte mit `242`, weil ein kompakter Datumstext
mit `T` an `datetime` übergeben wurde. Die Testliterale wurden auf
`yyyy-MM-ddTHH:mm:ss` mit Style 126 korrigiert; die Produktquellen blieben
unverändert. Auch der fehlgeschlagene eigene Run wurde vollständig entfernt.
Die anschließende Originalcharakterisierung über den öffentlichen Runner
mit `-Scenario MailMaintenance` bestand einschließlich `REMOVED`-Cleanup.
Die Testkomponente erhält keine eigenständige Artefaktreferenz; TEST-0001 und
die zugehörige Agent-Fixture bleiben unverändert.

Der Nachweis betrifft injizierte nicht leere native Quellen und bestehende
Analyseverträge. Die Feldnamen `OldestUtc` und `NewestUtc` ändern den nativen
Zeitbezug nicht; eine UTC-Konvertierung ist nicht belegt. Tatsächliche
Mail-/Maintenance-Ausführung, Queueverarbeitung, Agent-Ausführung,
Retentionpolicy, tatsächlich fehlende optionale Quellen, Windows und
zusätzliche native Engines bleiben offen. OPS-008 bleibt
`PARTIAL_PRODUCT_FUNCTION`; die Maturityflags und die historische
Release-Matrix bleiben unverändert.

## Ergänzende tatsächliche OPS-008-Agent-Ausführung vom 8. Oktober 2026

Der öffentliche Runner `Invoke-Ops008MsdbHistoryScenario.ps1` mit
`-Scenario AgentExecution` bestand auf einer neuen eigenen
SQL-Server-2025-Linux-Docker-Instanz die Coreinstallation, den Smoke-Test,
Runtimevertrag `122` und die
[Agent-Ausführungsfixture](../../../../TestLab/Scenarios/OPS-008/agent-execution.sql).
Der unveränderte Analyzerstand nach PR #272 wurde zuerst charakterisiert;
ein Produktfehler wurde nicht beobachtet und keine Produktkorrektur vorgenommen.
Der Runner erfasste tatsächlich `ProductVersion=17.0.4075.5` und
Compatibility Level 170 der Frameworkdatenbank.

Die Fixture verlangte eine leere Agent-Historie und einen freien eigenen
Jobnamen. Sie erstellte über die nativen Agent-Prozeduren einen eigenen
lokalen Job mit einem T-SQL-Schritt `SELECT 1`, ohne Zeitplan,
Wiederholungsversuch oder Benachrichtigung. `sp_start_job` löste seine
tatsächliche Ausführung aus. Ein auf 120 Polls mit jeweils einer Sekunde
Abstand begrenzter Wartepfad verlangte erfolgreiche native Step-0- und
Step-1-Historyrecords sowie einen gestarteten und beendeten Aktivitätsrecord
mit passender Historyidentität. Job-ID, Schritt-UID und getrennte
Historyidentitäten wurden unabhängig geprüft. Genau zwei native
Historyzeilen gehörten zum eigenen Job; zusätzliche oder erfolglose
Zeilen waren nicht zulässig. Nach dem Abschluss wurde der Job deaktiviert
und die vollständige Historie mit einem weiteren Abstand von zwei Sekunden
als stabil bestätigt. Es wurden keine Historyzeilen direkt injiziert.

NONE, TABLE und CONSOLE bestätigten danach `AVAILABLE`, sechs Quellenzeilen
und die Parität des Agent-Counts mit dem nativen `COUNT_BIG(*)`. Die
bestehenden Agent-Zeitgrenzen `OldestUtc` und `NewestUtc` blieben NULL.
TABLE und CONSOLE besaßen vollständige Parität aller acht Fachfelder mit
JSON innerhalb desselben Aufrufs. Alle Historyspalten wurden vor und nach
jedem Aufruf nach `instance_id` sortiert und mit `INCLUDE_NULL_VALUES`
NULL-sicher verglichen. Die eigene Callertransaktion blieb committable
mit `@@TRANCOUNT=1`; `LOCK_TIMEOUT=137` blieb erhalten.

Nach dem Analyzervergleich wurde die Callertransaktion zurückgerollt.
`sp_delete_job` entfernte ausschließlich den eigenen Job anhand seiner
Job-ID. Die Fixture bestätigte die Abwesenheit seiner Job-, Schritt-,
Server-, Schedule- und Aktivitätsrecords sowie der gesamten zuvor leeren
Historie. Der Fehlerpfad besitzt denselben identitätsgebundenen Cleanup
mit begrenztem Stop-Warten; sein tatsächlicher Fehlerlauf ist durch diesen
Erfolgsnachweis nicht belegt. Das äußere Labcleanup bleibt unabhängig vom
Szenarioergebnis erforderlich. Der native Lauf endete mit `PASS` und
`REMOVED`; Container und Volume wurden entfernt. Runtimeidentitäten,
native Zeitwerte, Secrets und Rohlogs bleiben außerhalb des Repositorys.

Der Nachweis betrifft einen erfolgreichen minimalen lokalen Agent-Job auf
SQL Server 2025 mit Docker. Er schließt weder Retention noch Jobdatums- oder
Dauerinterpretation ab. Tatsächliche Mail-/Maintenance-Ausführung,
Queueverarbeitung, fehlende optionale Quellen, Windows und weitere
Provider oder native Engines bleiben separat offen. TEST-0001, die
injizierte Agent-Fixture und die Registry bleiben unverändert; die neue
Fixture ist ein OPS-008-Testbestandteil ohne eigene Artefaktreferenz.
OPS-008 bleibt `PARTIAL_PRODUCT_FUNCTION`; Maturityflags und historische
Release-Matrix bleiben unverändert.

## Ergänzende native OPS-008-Agent-Historienretention vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario AgentRetention` bestand auf einem neuen
eigenen SQL-Server-2025-Linux-Docker-Lab die Coreinstallation, den Smoke-Test,
Runtimevertrag `122` und die
[Agent-Retentionfixture](../../../../TestLab/Scenarios/OPS-008/agent-retention.sql).
Er erfasste `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Das Original nach PR #273 blieb unverändert;
ein Produktfehler wurde nicht beobachtet und keine Produktkorrektur vorgenommen.

Die Fixture verlangte leere Agent-Historie und einen freien eigenen Jobnamen.
Ein eigener lokaler Job führte denselben minimalen T-SQL-Schritt `SELECT 1`
zweimal erfolgreich aus, ohne Zeitplan, Retry oder Benachrichtigung. Jede
Ausführung benötigte zwei getrennte erfolgreiche Historyidentitäten sowie
einen beendeten Aktivitätsrecord mit passender Summaryidentität. Je Ausführung
war der Wartepfad auf 120 Einsekundenpolls begrenzt. Die vier nativen
Historyzeilen wurden nicht direkt injiziert oder geändert. Der Job wurde
anschließend deaktiviert und die vollständige Historie nach zwei Sekunden
als stabil bestätigt.

Die nativen Ganzzahlfelder `run_date` und `run_time` wurden ausschließlich in
der Fixture in lokale Startzeitwerte umgerechnet. Zwei Sekunden nach der
spätesten ersten Startzeit bildeten die erste Retentiongrenze; beide jüngeren
Startzeiten mussten strikt danach liegen. Ein Abstand von vier Sekunden
zwischen den Ausführungen schuf die kontrollierte Trennung. Die native
Prozedur [`sp_purge_jobhistory`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-purge-jobhistory-transact-sql?view=sql-server-ver17)
erhielt die eigene Job-ID und diese explizite Datumsgrenze. Beide älteren
Historyzeilen wurden entfernt; sämtliche Spalten der beiden jüngeren Zeilen
blieben nach Sortierung und `INCLUDE_NULL_VALUES` NULL-sicher identisch.
Eine zweite, spätere Grenze entfernte die beiden verbleibenden eigenen
Historyzeilen. Job und Schritt blieben vor den Analyzerprüfungen vorhanden,
der Job deaktiviert und seine Aktivität beendet.

In jeder Phase mit vier, zwei und null Historyzeilen bestätigten NONE, TABLE
und CONSOLE `AVAILABLE`, sechs Quellenzeilen und den unabhängigen nativen
Count. Die bestehenden Agent-Zeitgrenzen blieben NULL und die Evidenzgrenze
vorhanden. TABLE und CONSOLE besaßen innerhalb desselben Aufrufs vollständige
Parität aller acht Fachfelder mit JSON. Alle Historyspalten blieben vor und
nach jedem der neun Analyzeraufrufe unverändert. Die eigene Callertransaktion
blieb committable mit `@@TRANCOUNT=1`; `LOCK_TIMEOUT=137` blieb erhalten und
wurde nach jeder Phase auf den Eintrittswert zurückgesetzt. Der Analyzer
löschte keine Historie.

Die abschließende identitätsgebundene Joblöschung bestätigte die Abwesenheit
aller eigenen Job-, Schritt-, Server-, Schedule- und Aktivitätsrecords sowie
der zuvor leeren Gesamthistorie. Der öffentliche Lauf endete mit `PASS` und
`REMOVED`; eigener Container, Volume und temporärer State wurden entfernt.
Runtimeidentitäten, native Zeitwerte, Secrets und Rohlogs bleiben außerhalb
von Git. Der unabhängige Review der funktionalen Fixture und Runnererweiterung
besitzt keine offenen Befunde.

Der Nachweis gilt ausschließlich für diese manuelle datumsgebundene native
Agent-Historienbereinigung. Automatische Agent-Aufbewahrung, Retention anderer
Historien, fremde Jobs, RAW-Capture, empirische Fehlercleanup-/Stop-Timeoutpfade,
Jobdauerinterpretation und ein Produktvertrag für Jobdatumsfelder sind damit
nicht belegt. Die Testumrechnung begründet keine UTC-Aussage. Tatsächliche
Mail-/Maintenance-Ausführung, Quellenabwesenheit, Windows, weitere Provider
und zusätzliche native Engines bleiben offen. OPS-008 bleibt
`PARTIAL_PRODUCT_FUNCTION`; Produkt-SQL, TEST-0001, Registry, Maturityflags und
historische Release-Matrix bleiben unverändert. Die neue Fixture ist ein
Bestandteil von OPS-008 ohne eigene Artefaktreferenz.

## Ergänzende native OPS-008-Backup-/Restore-Retention vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario BackupRestoreRetention` bestand auf
einem neuen eigenen SQL-Server-2025-Linux-Docker-Lab die Coreinstallation,
den Smoke-Test, Runtimevertrag `122` und die
[Backup-/Restore-Retentionfixture](../../../../TestLab/Scenarios/OPS-008/backup-restore-retention.sql).
Er erfasste `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert; eine
Produktkorrektur war nicht erforderlich.

Die acht Historientabellen `backupset`, `backupfile`, `backupfilegroup`,
`backupmediaset`, `backupmediafamily`, `restorehistory`, `restorefile` und
`restorefilegroup` mussten zu Beginn leer sein. Die Fixture erstellte eine
eigene leere Quelldatenbank, erzeugte drei tatsächliche Backups in getrennten
Medien und stellte jedes Backup in dieselbe eigene Restore-Datenbank wieder
her. Die eigenen Backup- und Restoreidentitäten wurden paarweise geprüft.
Nur ihre Historienzeitstempel wurden auf kontrollierte synthetische Werte
gesetzt; die drei Paare enthielten zwei ältere und ein jüngeres Paar.

Die native Prozedur
[`sp_delete_backuphistory`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-delete-backuphistory-transact-sql?view=sql-server-ver17)
besitzt einen globalen Datumsfilter ohne Datenbankfilter. Sie wurde deshalb
ausschließlich im neuen eigenen Lab mit zwei expliziten Datumsgrenzen
ausgeführt. Der erste Eingriff entfernte die beiden älteren Paare.
Sämtliche Spalten der jüngeren Zeilen in allen acht Tabellen blieben nach
Sortierung und `INCLUDE_NULL_VALUES` NULL-sicher identisch. Der zweite
Eingriff entfernte das verbleibende Paar; alle acht Tabellen waren leer.
Beide nativen Prozeduraufrufe lieferten Rückgabewert `0`.

In jeder Phase mit drei, einem und null Paaren bestätigten NONE, TABLE und
CONSOLE `AVAILABLE`, sechs Quellenzeilen sowie die unabhängigen nativen
Backup-/Restore-Counts und MIN-/MAX-Zeitgrenzen. Die Fixture prüfte die
nativen Werte zusätzlich gegen die kontrollierten Counts und Datumswerte.
TABLE und CONSOLE besaßen innerhalb desselben Aufrufs Parität aller acht
Fachfelder mit JSON. Die Evidenzgrenzen blieben vorhanden. Sämtliche Spalten
aller acht Historientabellen blieben vor und nach jedem der neun
Analyzeraufrufe NULL-sicher gleich. Die Callertransaktion blieb committable
mit `@@TRANCOUNT=1`; `LOCK_TIMEOUT=137` blieb erhalten und wurde nach jeder
Phase auf den Eintrittswert zurückgesetzt. Der Analyzer bereinigte keine
Historie.

Für beide eigenen Datenbanken blieben `database_id`, `name`, `create_date`,
`collation_name`, `state`, `user_access`, `recovery_model` und `is_read_only`
über die drei Phasen identisch. Die abschließende identitätsgebundene
Datenbanklöschung bestätigte ihre Abwesenheit. Der Lauf endete mit `PASS`
und `REMOVED`; eigener Container, Volume und temporärer State wurden
entfernt. Runtimeidentitäten, Secrets und Rohlogs bleiben außerhalb von Git.

Ein erster nativer Versuch scheiterte vor der Fixtureausführung mit Fehler
207, weil vier Sortierungen in `restorefilegroup` eine nicht vorhandene
Spalte `filegroup_id` verwendeten. Das äußere Labcleanup bestand auch für
diesen Versuch. Die Fixture verwendet anschließend die dokumentierte
Spalte [`filegroup_name`](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/restorefilegroup-transact-sql?view=sql-server-ver17).
Der zweite Lauf verwendete ein neues eigenes Lab und bestand. Der
Compilefehler belegt keinen inneren T-SQL-Fehlercleanup. Der unabhängige
Review des korrigierten funktionalen Standes besitzt keine offenen Befunde.

Der Nachweis betrifft ausschließlich die manuelle datumsgebundene native
Historienbereinigung mit kontrollierten Zeitstempeln. Automatische
Aufbewahrung, tatsächliches Alter oder UTC-Bezug, fremde Historien,
Konkurrenz, RAW-Capture, alle weiteren Datenbankoptionen, Benutzerdaten und
Integrität oder Aufbewahrung physischer Backupmedien sind damit nicht
belegt. Tatsächliche Mail-/Maintenance-Ausführung und deren Retention,
fehlende optionale Quellen, Windows, weitere Provider und zusätzliche
native Engines bleiben offen. OPS-008 bleibt `PARTIAL_PRODUCT_FUNCTION`;
TEST-0001, Registry, Maturityflags und historische Release-Matrix bleiben
unverändert. Die neue Fixture ist ein Bestandteil von OPS-008 ohne eigene
Artefaktreferenz.

## Ergänzende native OPS-008-Retention injizierter Mailhistorie vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario MailRetention` bestand auf einem neuen
eigenen SQL-Server-2025-Linux-Docker-Lab die Coreinstallation, den Smoke-Test,
Runtimevertrag `122` und die
[Mailretention-Fixture](../../../../TestLab/Scenarios/OPS-008/mail-retention.sql).
Er erfasste `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert; eine
Produktkorrektur war nicht erforderlich.

Die zugrunde liegende Mailitemtabelle, `sysmail_allitems` und die Anlagenview
mussten zu Beginn leer sein. Konfigurierte und effektive Mail-XPs waren
deaktiviert und blieben während der Analyzerprüfungen deaktiviert. Die
Fixture injizierte drei eigene Zeilen mit kontrollierten synthetischen
`send_request_date`- und `sent_date`-Werten und Statusmarkierung `failed`.
Die Markierung belegt keinen tatsächlich ausgelösten Versandfehler. Die
Einfügereihenfolge unterschied sich von der Zeitreihenfolge. Weder
Mailprofil, SMTP-Verbindung, Versand noch Queueverarbeitung wurden eingerichtet
oder ausgeführt; die Anlagenview blieb leer.

Die native Prozedur
[`sysmail_delete_mailitems_sp`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sysmail-delete-mailitems-sp-transact-sql?view=sql-server-ver17)
erhielt zwei explizite Datumsgrenzen und jeweils `@sent_status='failed'`.
Beide Aufrufe lieferten Rückgabewert `0`. Der erste Eingriff entfernte die
beiden älteren eigenen Zeilen; sämtliche Spalten der jüngeren Zeile blieben
nach Sortierung über `mailitem_id` und `INCLUDE_NULL_VALUES` NULL-sicher
gleich. Der zweite Eingriff entfernte die jüngere Zeile. Native Tabellen-
und Viewcounts bestätigten drei, eine und null Zeilen; MIN und MAX der
Requestzeitstempel entsprachen zusätzlich den kontrollierten Sollwerten
beziehungsweise NULL bei leerer Quelle.

In jeder Phase bestätigten NONE, TABLE und CONSOLE `AVAILABLE`, sechs
Quellenzeilen, die unabhängigen nativen Mailaggregate und eine vorhandene
Evidenzgrenze. TABLE und CONSOLE besaßen innerhalb desselben Aufrufs
Parität aller acht Fachfelder mit JSON. Sämtliche Spalten der Mailitemtabelle
blieben vor und nach jedem der neun Analyzeraufrufe NULL-sicher identisch.
Die gemeinsame Callertransaktion blieb committable mit `@@TRANCOUNT=1`;
`LOCK_TIMEOUT=137` blieb auch nach den nativen Purges erhalten. Der Analyzer
bereinigte keine Historie.

Ein abschließendes Rollback bestätigte die leeren Mailitem-, Allitems- und
Anlagenquellen sowie `@@TRANCOUNT=0`; `LOCK_TIMEOUT` wurde auf den Eintrittswert
zurückgesetzt. Der öffentliche Lauf endete mit `PASS` und `REMOVED`.
Eigener Container, Volume und temporärer State wurden entfernt.
Runtimeidentitäten, Secrets und Rohlogs bleiben außerhalb von Git. Der
unabhängige funktionale Review besitzt keine offenen Befunde.

Der Nachweis gilt ausschließlich für den manuellen nativen Purge der
injizierten Failed-Historie mit kontrollierten Zeitstempeln. Tatsächlicher
Mailversand oder Versandfehler, Profil-/SMTP-/Queueverhalten, andere
Mailstatus, automatische Aufbewahrung, Anlagen- und Logretention,
authentisches Alter oder UTC-Bezug, fremde Quellen und empirisches
Fehlercleanup sind damit nicht belegt. Maintenance-Ausführung und
Retention sowie fehlende optionale Quellen, Windows, weitere Provider und
zusätzliche native Engines bleiben offen. OPS-008 bleibt
`PARTIAL_PRODUCT_FUNCTION`; TEST-0001, Registry, Maturityflags und historische
Release-Matrix bleiben unverändert. Die neue Fixture ist ein Bestandteil
von OPS-008 ohne eigene Artefaktreferenz.

## Ergänzende native OPS-008-Retention injizierter Maintenancehistorie vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario MaintenanceRetention` bestand auf einem
neuen eigenen SQL-Server-2025-Linux-Docker-Lab die Coreinstallation, den
Smoke-Test, Runtimevertrag `122` und die
[Maintenanceretention-Fixture](../../../../TestLab/Scenarios/OPS-008/maintenance-retention.sql).
Er erfasste `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert.

Die Tabellen `sysmaintplan_log`, `sysmaintplan_logdetail`, `sysmaintplan_plans`
und `sysmaintplan_subplans` mussten zu Beginn leer sein. Die Fixture prüfte
in der installierten nativen Metadatenquelle die benötigten Parameternamen,
Typen und Längen von `sp_maintplan_delete_log`: `@plan_id` und `@subplan_id`
als `uniqueidentifier` sowie `@oldest_time` als `datetime`. Die Microsoft-
[Dokumentation zur Historienbereinigung](https://learn.microsoft.com/en-us/sql/relational-databases/maintenance-plans/use-the-maintenance-plan-wizard?view=sql-server-ver17)
nennt diese Prozedur; die konkrete Signatur wird hier durch den nativen
Preflight und die tatsächlichen Aufrufe belegt.

Die Fixture injizierte drei eigene Elternzeilen in `sysmaintplan_log` mit
jeweils eigener GUID, synthetischen Namen und kontrollierten Start- und
Endzeitstempeln. Die Erfolgsmarkierung belegt keine tatsächlich ausgeführte
Maintenance. Die Einfügereihenfolge unterschied sich von der Zeitreihenfolge.
Plans, Subplans und Detailhistorie blieben leer; Pläne, Jobs und SSIS-Aufgaben
wurden weder eingerichtet noch ausgeführt.

Die native Prozedur erhielt zwei explizite Datumsgrenzen sowie NULL für
beide Planfilter und lieferte jeweils Rückgabewert `0`. Diese globale
Datumsbereinigung ist ausschließlich durch das neue eigene leere Lab
begrenzt. Der erste Eingriff entfernte die beiden älteren eigenen Zeilen;
sämtliche Spalten der jüngeren Zeile blieben nach Sortierung über
`task_detail_id` und `INCLUDE_NULL_VALUES` NULL-sicher gleich. Der zweite
Eingriff entfernte die jüngere Zeile. Native Counts und MIN-/MAX-Startzeiten
bestätigten drei, eine und null Zeilen sowie die kontrollierten Zeitgrenzen
beziehungsweise NULL bei leerer Quelle.

In jeder Phase bestätigten NONE, TABLE und CONSOLE `AVAILABLE`, sechs
Quellenzeilen, die unabhängigen nativen Maintenanceaggregate und eine
vorhandene Evidenzgrenze. TABLE und CONSOLE besaßen innerhalb desselben
Aufrufs Parität aller acht Fachfelder mit JSON. Sämtliche Spalten der
Elternhistorie blieben vor und nach jedem der neun Analyzeraufrufe NULL-sicher
identisch. Die gemeinsame Callertransaktion blieb committable mit
`@@TRANCOUNT=1`; `LOCK_TIMEOUT=137` blieb auch nach den nativen Purges erhalten.
Der Analyzer bereinigte keine Historie.

Ein abschließendes Rollback bestätigte alle vier leeren Maintenancequellen
und `@@TRANCOUNT=0`; `LOCK_TIMEOUT` wurde auf den Eintrittswert zurückgesetzt.
Der öffentliche Lauf endete mit `PASS` und `REMOVED`. Eigener Container,
Volume und temporärer State wurden entfernt. Runtimeidentitäten, Secrets
und Rohlogs bleiben außerhalb von Git. Der unabhängige funktionale Review
besitzt keine offenen Befunde.

Der Nachweis gilt ausschließlich für die manuelle native Datumsbereinigung
injizierter Elternhistorie. Tatsächliche Maintenance-Ausführung,
SSIS-/Jobverhalten, positive Detailhistorienbereinigung, selektive
Plan-/Subplanfilter, automatische Aufbewahrung, authentisches Alter oder
UTC-Bezug, fremde Quellen und empirisches Fehlercleanup sind damit nicht
belegt. Tatsächliche Mailausführung, weitere Mailstatus, Anlagen- und
Logretention sowie fehlende optionale Quellen, Windows, weitere Provider
und zusätzliche native Engines bleiben offen. OPS-008 bleibt
`PARTIAL_PRODUCT_FUNCTION`; TEST-0001, Registry, Maturityflags und historische
Release-Matrix bleiben unverändert. Die neue Fixture ist ein Bestandteil
von OPS-008 ohne eigene Artefaktreferenz.

## Ergänzende native OPS-008-Retention für vier injizierte Mailstatus vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario MailStatusRetention` bestand auf einem
neuen eigenen SQL-Server-2025-Linux-Docker-Lab die Coreinstallation, den
Smoke-Test, Runtimevertrag `122` und die
[Mailstatusretention-Fixture](../../../../TestLab/Scenarios/OPS-008/mail-status-retention.sql).
Er erfasste `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert.

Die Fixture prüfte die vier expliziten Filter `unsent`, `sent`, `failed`
und `retrying` der nativen Prozedur
[`sysmail_delete_mailitems_sp`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sysmail-delete-mailitems-sp-transact-sql?view=sql-server-ver17).
Jeder Fall verwendete eine getrennte Callertransaktion mit drei eigenen
injizierten Zielzeilen und je einer älteren Gegenprobe der anderen drei
Status. Die native View bestätigte die Zuordnung der injizierten numerischen
Status zu den vier Textwerten. Kontrollierte Request- und Sentzeitstempel
waren gleich; natürliche Queue-/Retryzeiten oder tatsächliche Mailzustände
werden durch diese Injektion nicht belegt.

Zwei explizite Datumsgrenzen reduzierten je Fall ausschließlich die Zielmenge
von drei auf eine und null Zeilen. Die gesamte Mailmenge besaß sechs, vier
und drei Zeilen. Alle acht nativen Purges lieferten Rückgabewert `0`.
Sämtliche Spalten der jüngeren Zielzeile blieben nach dem ersten Eingriff
NULL-sicher gleich. Sämtliche Spalten der drei älteren Gegenproben blieben
nach beiden Eingriffen erhalten. Die Vergleiche sortierten über
`mailitem_id` und verwendeten `INCLUDE_NULL_VALUES`.

NONE, TABLE und CONSOLE bestätigten je Phase `AVAILABLE`, sechs Quellenzeilen,
unabhängige native Mailcounts und MIN-/MAX-Requestzeiten sowie eine vorhandene
Evidenzgrenze. TABLE und CONSOLE besaßen innerhalb desselben Aufrufs Parität
aller acht Fachfelder mit JSON. Sämtliche Spalten der Mailitemtabelle blieben
vor und nach jedem der 36 Analyzeraufrufe NULL-sicher identisch. Jede
Callertransaktion blieb committable mit `@@TRANCOUNT=1`; `LOCK_TIMEOUT=137`
blieb auch nach den nativen Purges erhalten. Der Analyzer bereinigte keine
Historie.

Mailitem-, Allitems- und Anlagenquellen mussten zu Beginn leer sein.
Konfigurierte und effektive Mail-XPs blieben deaktiviert; die Anlagenview
blieb leer. Mailprofil, SMTP-Verbindung, Versand und Queueverarbeitung
wurden weder eingerichtet noch ausgeführt. Jedes der vier Rollbacks
bestätigte erneut die leeren Quellen und `@@TRANCOUNT=0`; abschließend
wurde `LOCK_TIMEOUT` auf den Eintrittswert zurückgesetzt. Der öffentliche
Lauf endete mit `PASS` und `REMOVED`; eigener Container, Volume und temporärer
State wurden entfernt. Runtimeidentitäten, Secrets und Rohlogs bleiben
außerhalb von Git. Der unabhängige funktionale Review besitzt keine offenen
Befunde.

Der Nachweis gilt ausschließlich für die manuelle native Datums-/Status-
bereinigung der injizierten Mailitems. Tatsächlicher Versand oder
Versandfehler, SMTP-/Profil-/Queue-/Retryverhalten, automatische Aufbewahrung,
Anlagen- und Logretention, NULL- oder ungültige Filter, authentisches Alter
oder UTC-Bezug, fremde Quellen und empirisches Fehlercleanup sind damit
nicht belegt. Maintenance-Ausführung, positive Detailretention und selektive
Planfilter sowie fehlende optionale Quellen, Windows, weitere Provider und
zusätzliche native Engines bleiben offen. OPS-008 bleibt
`PARTIAL_PRODUCT_FUNCTION`; TEST-0001, Registry, Maturityflags und historische
Release-Matrix bleiben unverändert. Die neue Fixture ist ein Bestandteil
von OPS-008 ohne eigene Artefaktreferenz.

## Ergänzender nativer OPS-008-Mailfehler vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario MailExecutionFailure` bestand auf einem
neuen eigenen SQL-Server-2025-Linux-Docker-Lab die Coreinstallation, den
Smoke-Test, Runtimevertrag `122` und die
[Mailfehler-Fixture](../../../../TestLab/Scenarios/OPS-008/mail-execution-failure.sql).
Er erfasste `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert.

Die Fixture verlangte leere Mail-, Anlagen-, Log-, Profil- und Kontoquellen,
deaktivierte Mail-XPs und aktivierten Service Broker in `msdb`. Sie aktivierte
Mail-XPs und erfasste den nativen Queue-Eintrittsstatus. Ein eigenes Profil
verwendete ein eigenes anonymes SMTP-Konto für `localhost` auf Port 1.
Der zwölfspaltige native Kontocapture bestätigte Konto-ID, SMTP-Typ, lokalen
Host, Port, NULL-Benutzernamen sowie deaktivierte Defaultcredentials und SSL.
Sender und Empfänger waren synthetische Adressen unter der durch
[RFC 2606](https://www.rfc-editor.org/rfc/rfc2606.html) reservierten Domain
`.invalid`. Es gab weder einen externen SMTP-Host noch einen echten Empfänger.

`sp_send_dbmail` lieferte Rückgabewert `0` und die eigene Mailitem-ID.
Die Fixture wartete höchstens 120 Einsekundenpolls auf den nativen Status
`failed` und mindestens einen gebundenen Fehlerlogeintrag. Mailitem-ID und
Profil-ID mussten zur eigenen Quelle gehören; Request- und Sentzeit waren
vorhanden. Der Fehlerlogeintrag musste dieselbe Mailitem-ID, Typ `error`,
eine positive Prozesskennung, eine nicht leere Beschreibung und NULL-
`account_id` besitzen. Diese Bindung entspricht dem dokumentierten
[aggregierten endgültigen Mailfehler](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sysmail-event-log-transact-sql?view=sql-server-ver17).
Die Fixture verwendete ausschließlich nativ erzeugte Mailhistorie. Eine nicht leere
Logbeschreibung beweist keinen bestimmten SMTP-Protokollfehler oder dessen
Ursache; die 120 Polls begrenzen keine Gesamtlaufzeit der Fixture.

Vor den drei Analyzeraufrufen wurden Queue und Mail-XPs deaktiviert.
NONE, TABLE und CONSOLE bestätigten `AVAILABLE`, sechs Quellenzeilen,
unabhängige native Mailcounts und MIN-/MAX-Requestzeiten sowie eine vorhandene
Evidenzgrenze. TABLE und CONSOLE besaßen Parität aller acht Fachfelder mit
JSON. Sämtliche Spalten der Mailitemtabelle blieben vor und nach jedem Aufruf
NULL-sicher identisch. Die Callertransaktion blieb committable mit
`@@TRANCOUNT=1` und `LOCK_TIMEOUT=137`; Anlagen blieben leer und konfigurierte
sowie effektive Mail-XPs blieben während der Consumerprüfungen deaktiviert.
Der Analyzer bereinigte keine Historie.

Nach dem Callerrollback aktivierte die Fixture Mail-XPs erneut für das
native Cleanup. Der eigene Failed-Mailitem wurde mit Rückgabewert `0`
entfernt; Profil und Konto wurden über ihre eigenen IDs entfernt. Queue-
und Konfigurationseintrittswerte wurden wiederhergestellt und geprüft.
Native Logs verblieben bis zum äußeren identitygebundenen Labcleanup.
Der öffentliche Lauf endete mit `PASS` und `REMOVED`; eigener Container,
Volume und temporärer State wurden entfernt. Runtimeidentitäten, Secrets,
Mailinhalte und Rohlogs bleiben außerhalb von Git.

Der erste native Lauf scheiterte vor dem Queueauftrag, weil
`sysmail_help_status_sp` bei deaktivierten Mail-XPs mit `0x3BB1` blockiert
wurde. Coreinstallation, Smoke-Test und Runtimevertrag bestanden;
das äußere eigene Container- und Volumecleanup bestätigte zwei Schritte
mit null Fehlern. Statuscapture und natives Cleanup wurden daraufhin
innerhalb TRY bei aktivierten XPs angeordnet. Die Consumergrenze blieb
unverändert. Der korrigierte Lauf verwendete ein weiteres neues eigenes Lab.
Beide funktionalen Stände wurden unabhängig geprüft; der finale Review
besitzt keine offenen funktionalen Befunde.

Der Datenschutzscan erkannte die synthetischen Adressen und ein vorläufiges
NULL-Passwortargument. Das unnötige Argument wurde vor dem ersten nativen
Lauf entfernt. Zwei ausschließlich an Regel, Fixturepfad und Wertdigest
gebundene Ausnahmen erlauben die reservierten synthetischen Adressen;
der Scanner blieb unverändert. Self-Test und Repositoryscan bestanden.

Der Nachweis gilt für den eigenen nativen lokalen Mailfehler. Erfolgreiche
SMTP-Annahme oder Zustellung, ein bestimmter SMTP-Fehlergrund, authentischer
Retryverlauf, automatische Aufbewahrung, positive Anlagen- oder Logretention
und empirisches inneres Fehlercleanup sind damit nicht belegt. Maintenance-
Ausführung, positive Detailretention und selektive Planfilter sowie fehlende
optionale Quellen, Windows, weitere Provider und zusätzliche native Engines
bleiben offen. OPS-008 bleibt `PARTIAL_PRODUCT_FUNCTION`; TEST-0001, Registry,
Maturityflags und historische Release-Matrix bleiben unverändert. Die neue
Fixture ist ein Bestandteil von OPS-008 ohne eigene Artefaktreferenz.

## Ergänzende native OPS-008-Maillogretention vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario MailLogRetention` bestand auf einem
neuen eigenen SQL-Server-2025-Linux-Docker-Lab die Coreinstallation,
Smoke-Test, Runtimevertrag `122` und die
[Maillogretention-Fixture](../../../../TestLab/Scenarios/OPS-008/mail-log-retention.sql).
Er erfasste `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert.

Die Fixture verwendete anfangs leere Mail-, Anlagen-, Log-, Profil- und
Kontoquellen sowie einen aktivierten `msdb`-Broker. Sie erzeugte ein eigenes
anonymes Konto für `localhost` auf Port 1 und ein eigenes Profil. Der native
zwölfspaltige Kontocapture bestätigte die eigenen IDs und Konfigurationswerte.
Sender und Empfänger waren synthetische `.invalid`-Adressen; ein externer
SMTP-Host oder echter Empfänger wurde nicht verwendet. Drei getrennte native
`sp_send_dbmail`-Aufträge lieferten jeweils Rückgabewert `0` und eine eigene
Mailitem-ID. Jeder Auftrag wurde mit höchstens 120 Einsekundenpolls auf den
Status `failed` und mindestens einen gebundenen nativen Prozessfehler geprüft.
Die höchstens 360 Polls sind keine Grenze für die gesamte Fixturelaufzeit.
Die Fixture benötigte `send_request_date`, jedoch kein Versanddatum.

Gebundene Fehlerlogs besaßen Typ `error`, die eigene Mailitem-ID, NULL-
`account_id`, eine positive Prozesskennung und eine nicht leere Beschreibung.
Das entspricht der dokumentierten Bindung eines
[aggregierten endgültigen Mailfehlers](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sysmail-event-log-transact-sql?view=sql-server-ver17).
Aus den mindestens drei gebundenen Fehlerlogs wurde pro Mail genau die
kleinste native Log-ID als Retentionsziel gewählt. Zusätzliche gebundene
Fehlerlogs waren zulässig. Historienzeilen wurden nicht injiziert; eine
Beschreibung allein belegt keinen bestimmten SMTP-Fehlergrund.

Nach Queue-Stopp und Deaktivierung der Mail-XPs begann die Callertransaktion.
Die drei ausgewählten Fehlerlogzeiten wurden kontrolliert auf zwei
aufeinanderfolgende Tage und eine ältere Gegenprobe gesetzt. Eine nativ
vorhandene Informationszeile erhielt ebenfalls ein älteres Datum; ihr
Ereignistyp wurde aus der nativen Quelle übernommen. Die native erste
Integer-ID-Spalte wurde anhand des Viewkatalogs gebunden. Alle übrigen zu
diesem Zeitpunkt vorhandenen Log-IDs wurden als geschützter Scope erfasst;
später hinzukommende Logs gehören nicht zu diesem eingefrorenen Vergleich.

Zwei native `sysmail_delete_log_sp`-Aufrufe mit explizitem `error`-Filter und
Datumsgrenzen lieferten jeweils Rückgabewert `0`. Die ausgewählte Fehlerlogmenge
betrug vor, zwischen und nach den Purges drei, eine und null Zeilen. Der
jüngere ausgewählte Fehlerlog blieb nach dem ersten Purge mit sämtlichen
Spaltenwerten erhalten. Die ältere Informationsgegenprobe und alle erfassten
übrigen Logs blieben NULL-sicher identisch. Sämtliche Werte der drei Mailitems
blieben erhalten. Dieser empirische Teilumfang entspricht der dokumentierten
[Trennung von Log- und Mailitembereinigung](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sysmail-delete-log-sp-transact-sql?view=sql-server-ver17).

In allen drei Phasen bestätigten NONE, TABLE und CONSOLE native Mailcounts,
MIN-/MAX-Requestzeiten, sechs verfügbare Quellen und eine Evidenzgrenze.
TABLE und CONSOLE besaßen Parität aller acht Fachfelder mit JSON. Sämtliche
Mailitemwerte sowie ausgewählte und geschützte Logwerte blieben vor und nach
jedem der neun Aufrufe erhalten. Die Callertransaktion blieb committable mit
`@@TRANCOUNT=1` und `LOCK_TIMEOUT=137`; Anlagen blieben leer. Konfigurierte und
effektive Mail-XPs waren während der Purges und Consumerprüfungen deaktiviert.
Der Analyzer führte selbst keinen Purge aus und erhielt keinen neuen
Logquellenvertrag; sein Mailaggregat verwendet weiterhin `send_request_date`.

Das Callerrollback stellte sämtliche ursprünglichen Werte der drei
gewählten Fehlerlogs und der Informationszeile wieder her. Danach wurden
Mail-XPs für das native Cleanup aktiviert. Die eigenen Failed-Mailitems,
das eigene Profil und Konto wurden entfernt; Queue- und Konfigurationswerte
wurden wiederhergestellt und geprüft. Native Logs verblieben bis zum
äußeren identitygebundenen Labcleanup. Der Lauf endete mit `PASS` und
`REMOVED`; eigener Container, Volume und temporärer State wurden entfernt.
Runtimeidentitäten, Secrets, Mailinhalte und Rohlogs bleiben außerhalb von Git.

Zwei vorherige native Läufe scheiterten mit `55403` an der abschließenden
Mailbasisprüfung, bevor Logzeiten geändert oder Logpurges ausgeführt wurden.
Im zweiten Lauf bestanden die drei seriellen Einzelprüfungen. Die früheren
Prüfungen verlangten zusätzlich exakt einen Fehlerlog pro Mail und ein nicht
leeres Versanddatum. Diese für den Retentionvertrag nicht erforderlichen
Annahmen wurden durch die ausgewählten Log-IDs und das Requestdatum ersetzt.
Eine konkrete Ursache der beiden früheren Fehler ist damit nicht bewiesen.
Coreinstallation, Smoke-Test und Runtimevertrag bestanden in beiden Läufen;
das äußere Container- und Volumecleanup bestätigte jeweils zwei Schritte mit
null Fehlern. Der korrigierte dritte Lauf verwendete ein weiteres neues Lab.
Alle funktionalen Änderungen wurden vor ihrem Lauf unabhängig geprüft.

Zwei pfad-, regel- und wertdigestgebundene Datenschutz-Ausnahmen erlauben
nur die synthetischen Adressen dieser Fixture. Ein zunächst übernommener
Digest passte nicht zum neuen Pfad und wurde vor dem ersten nativen Lauf
korrigiert; der Scanner blieb unverändert. Self-Test und Repositoryscan bestanden.

Kontrollierte Logzeitstempel belegen kein authentisches Alter oder UTC-Verhalten.
Andere Ereignistypfilter, NULL- und ungültige Filter, Grenzwertgleichheit,
automatische Logaufbewahrung, erfolgreiche SMTP-Annahme oder Zustellung,
Anlagenretention und empirisches inneres Fehlercleanup bleiben offen.
Maintenance-Ausführung, positive Detailretention und selektive Planfilter,
fehlende optionale Quellen, Windows und zusätzliche native Engines bleiben
getrennte Nachweise. OPS-008 bleibt `PARTIAL_PRODUCT_FUNCTION`; TEST-0001,
Registry, Maturityflags und historische Release-Matrix bleiben unverändert.
Die Fixture gehört zu OPS-008 und benötigt keine eigene Artefaktreferenz.

## Ergänzende native OPS-008-Anlagenretention vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario MailAttachmentRetention` bestand auf
einem neuen eigenen SQL-Server-2025-Linux-Docker-Lab die Coreinstallation,
Smoke-Test, Runtimevertrag `122` und die
[Anlagenretention-Fixture](../../../../TestLab/Scenarios/OPS-008/mail-attachment-retention.sql).
Er erfasste `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert.

Die Fixture verlangte leere eigene Mail- und Anlagenquellen sowie deaktivierte
Mail-XPs. Vor der Callertransaktion wurden die sieben Namen und Typen des
nativen Anlagenviews sowie die für die synthetischen Werte nötigen
Mindestkapazitäten geprüft. Drei eigene Failed-Mailitems mit kontrollierten
Request- und Sentzeiten wurden injiziert. Je Mailitem wurden zwei eigene
Binäranlagen von neun Bytes über den nativen View injiziert. Die sechs
Anlagen besaßen gültige eigene Mailbindungen, passende Dateigrößen und
synthetische Dateinamen. Betriebssystemdateien, Profil, Konto, Mailversand
und Queueverarbeitung wurden von der Fixture nicht verwendet.

Zwei native `sysmail_delete_mailitems_sp`-Aufrufe mit explizitem Failed-Status
und Datumsgrenzen lieferten jeweils Rückgabewert `0`. Die Mailcounts betrugen
vor, zwischen und nach den Purges drei, eine und null; die zugehörigen
Anlagencounts betrugen sechs, zwei und null. Die Summe der Binärgrößen betrug
54, 18 und null Bytes. Verwaiste Anlagen verblieben nicht. Nach dem ersten
Purge blieben sämtliche Werte des jüngeren Mailitems und seiner beiden
Anlagen NULL-sicher identisch. Die Snapshots erfassten alle sieben Anlagenfelder
samt Binärinhalt. Der Nachweis entspricht der dokumentierten
[Mitbereinigung zugeordneter Anlagen](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sysmail-delete-mailitems-sp-transact-sql?view=sql-server-ver17)
und dem [nativen Anlagenview](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sysmail-mailattachments-transact-sql?view=sql-server-ver17).

In allen drei Phasen bestätigten NONE, TABLE und CONSOLE native Mailcounts,
MIN-/MAX-Requestzeiten, sechs verfügbare Quellen und eine Evidenzgrenze.
TABLE und CONSOLE besaßen Parität aller acht Fachfelder mit JSON. Alle
Mail- und Anlagenwerte blieben vor und nach jedem der neun Consumeraufrufe
NULL-sicher identisch. Anlagencounts, Bytezahlen und Mailbindungen wurden auch
nach den Aufrufen geprüft. Die Callertransaktion blieb committable mit
`@@TRANCOUNT=1` und `LOCK_TIMEOUT=137`; konfigurierte und effektive Mail-XPs
blieben deaktiviert. Der Analyzer führte keinen Purge aus und erhielt keinen
neuen Anlagenquellenvertrag; sein Mailaggregat verwendet weiterhin
`sysmail_allitems` und `send_request_date`.

Das abschließende Rollback entfernte sämtliche injizierten Mailitems und
Anlagen. Der öffentliche Lauf endete mit `PASS` und `REMOVED`; das äußere
identitygebundene Cleanup entfernte eigenen Container, Volume und temporären
State. Runtimeidentitäten, Secrets und Rohlogs bleiben außerhalb von Git.

Der erste native Lauf scheiterte vor der Injektion mit `55513` am starren
Namens-/Typ-/Längenvergleich des Anlagenviews. Die betroffene Spalte wurde
nicht protokolliert; eine konkrete abweichende Länge wird nicht behauptet.
Coreinstallation, Smoke-Test und Runtimevertrag bestanden; das äußere
Container- und Volumecleanup bestätigte zwei Schritte mit null Fehlern.
Die nicht benötigten exakten Längen wurden durch Mindestkapazitäten für
24 Unicode-Dateinamenzeichen, elf Benutzerzeichen und neun Binärbytes ersetzt.
Namen und Typen blieben exakt geprüft; eine erneute Abweichung erhält eine
Diagnose ausschließlich aus Systemspaltennamen, Typkennungen und Längen.
Der korrigierte Lauf verwendete ein weiteres neues eigenes Lab. Beide
funktionalen Stände wurden vor ihrem Lauf unabhängig geprüft. Datenschutz-
Self-Test und Repositoryscan bestanden ohne zusätzliche Ausnahmen.

Der Nachweis betrifft kontrollierte injizierte Anlagen und native datums- und
statusgebundene Mitbereinigung. Native Anlagenproduktion, Dateizugriff,
Versand oder Zustellung, authentisches Alter und automatische Aufbewahrung
sind damit nicht belegt. Weitere Anlagenfilterkombinationen, Grenzwertgleichheit
und empirisches inneres Fehlercleanup bleiben getrennte Nachweise.
Maintenance-Ausführung, positive Detailretention und selektive Planfilter,
fehlende optionale Quellen, Windows und zusätzliche native Engines bleiben
offen. OPS-008 bleibt `PARTIAL_PRODUCT_FUNCTION`; TEST-0001, Registry,
Maturityflags und historische Release-Matrix bleiben unverändert. Die Fixture
gehört zu OPS-008 und benötigt keine eigene Artefaktreferenz.

## Ergänzende native OPS-008-Maintenance-Detailretention vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario MaintenanceDetailRetention` bestand auf
einem neuen eigenen SQL-Server-2025-Linux-Docker-Lab die Coreinstallation,
Smoke-Test, Runtimevertrag `122` und die
[Detailretention-Fixture](../../../../TestLab/Scenarios/OPS-008/maintenance-detail-retention.sql).
Er erfasste `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert.

Eine getrennte native Metadatenabfrage in einem weiteren neuen eigenen Lab
ermittelte vor dem Fixtureentwurf 13 Detailfelder ohne Identity oder Computed
Columns und die Fremdschlüsselbindung von `sysmaintplan_logdetail.task_detail_id`
an `sysmaintplan_log.task_detail_id`. Die Fixture prüfte vor ihrer Transaktion
Feldnamen, Typen, Textkapazitäten und diese Bindung. Drei eigene Elternzeilen
mit kontrollierten Start- und Endzeiten wurden injiziert; je Elternzeile wurden
zwei eigene Details mit denselben Zeiten und synthetischen Inhalten injiziert.
Die Detailwerte enthielten positive Texte, NULL und Leertext. Plans und Subplans
blieben leer; Maintenance, SSIS und Jobs wurden nicht ausgeführt.

Zwei native `sp_maintplan_delete_log`-Aufrufe mit expliziten Datumsgrenzen und
NULL für `@plan_id` und `@subplan_id` lieferten jeweils Rückgabewert `0`.
Die Elterncounts betrugen vor, zwischen und nach den Purges drei, eine und
null; die Detailcounts betrugen sechs, zwei und null. Jede verbliebene
Elternzeile besaß zwei Details; verwaiste Details verblieben nicht. Nach dem
ersten Purge blieben sämtliche zehn Werte der jüngeren Elternzeile und alle
13 Werte ihrer beiden Details NULL-sicher identisch.

In allen drei Phasen bestätigten NONE, TABLE und CONSOLE native Elterncounts,
MIN-/MAX-Startzeiten, sechs verfügbare Quellen und eine Evidenzgrenze.
TABLE und CONSOLE besaßen Parität aller acht Fachfelder mit JSON. Sämtliche
Eltern- und Detailwerte blieben vor und nach jedem der neun Consumeraufrufe
NULL-sicher identisch. Detailcounts und Elternbindungen wurden auch nach den
Aufrufen geprüft. Die Callertransaktion blieb committable mit `@@TRANCOUNT=1`
und `LOCK_TIMEOUT=137`. Der Analyzer führte keinen Purge aus und erhielt
keinen neuen Detailquellenvertrag; sein Maintenanceaggregat verwendet
weiterhin `sysmaintplan_log` und `start_time`.

Das abschließende Rollback entfernte sämtliche injizierten Eltern und Details
und bestätigte alle vier Maintenancequellen als leer. Der öffentliche Lauf
endete mit `PASS` und `REMOVED`; das äußere identitygebundene Cleanup entfernte
eigenen Container, Volume und temporären State. Runtimeidentitäten, Secrets
und Rohlogs bleiben außerhalb von Git.

Die erste tatsächlich provisionierte Schemaabfrage scheiterte beim lokalen
Einlesen, weil `ExecuteScalar` nur den ersten JSON-Chunk des Resultsets las.
Ihr äußeres Cleanup bestätigte zwei Schritte mit null Fehlern. Der korrigierte
Reader setzte sämtliche Chunks unter einem Limit von 1.048.576 UTF-16-Zeichen
zusammen und wurde unabhängig geprüft. Die zweite Schemaabfrage bestand
auf einem weiteren neuen eigenen Lab und endete mit `REMOVED`.
Die unabhängige Fixturevorprüfung fand einen Katalogkontextfehler im
Fremdschlüsselguard. Die Spaltennamen wurden vor dem ersten Fixturelauf durch
Joins auf `msdb.sys.columns` gebunden; der korrigierte Stand wurde erneut
geprüft. Die separate Retentionfixture bestand ihren ersten nativen Lauf.

Der Nachweis betrifft kontrollierte injizierte Eltern und Details mit
übereinstimmenden Zeiten und native datumsgebundene Bereinigung. Er trennt
keine unabhängige Detaildatumssemantik und belegt weder selektive Planfilter
noch authentisches Alter, UTC-Umrechnung, automatische Aufbewahrung oder
Maintenance-/SSIS-Ausführung. Grenzwertgleichheit und empirisches inneres
Fehlercleanup bleiben getrennte Nachweise. Erfolgreiche Mail-Ausführung,
fehlende optionale Quellen, Windows und zusätzliche native Engines bleiben
offen. OPS-008 bleibt `PARTIAL_PRODUCT_FUNCTION`; TEST-0001, Registry,
Maturityflags und historische Release-Matrix bleiben unverändert. Die Fixture
gehört zu OPS-008 und benötigt keine eigene Artefaktreferenz.

## Ergänzende native OPS-008-Maintenance-Planfilterretention vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario MaintenancePlanRetention` bestand auf
einem neuen eigenen SQL-Server-2025-Linux-Docker-Lab die Coreinstallation,
Smoke-Test, Runtimevertrag `122` und die
[Planfilterretention-Fixture](../../../../TestLab/Scenarios/OPS-008/maintenance-plan-retention.sql).
Er erfasste `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert.

Die Fixture injizierte fünf eigene Elternzeilen mit je zwei gebundenen
Details. Drei Elternzeilen trugen denselben synthetischen Zielplan-GUID und
kontrollierte Startzeiten am 1. und 2. Januar 2025 sowie am 1. Januar 2000.
Zwei ältere Gegenproben vom 1. Januar 2000 trugen einen anderen Plan-GUID
beziehungsweise NULL. Sämtliche Subplan-IDs waren NULL. Plans und Subplans
blieben leer; die GUIDs waren ausschließlich injizierte Historienwerte.
Maintenance, SSIS und Jobs wurden nicht ausgeführt. Der Detailguard prüfte
13 Feldnamen und Typen, Textkapazitäten sowie die native Elternbindung.
Eltern und Details verwendeten jeweils übereinstimmende kontrollierte Zeiten.

Ein nativer `sp_maintplan_delete_log`-Aufruf mit nicht passendem Plan-GUID,
NULL-Subplanfilter und Datumsgrenze lieferte Rückgabewert `0` und erhielt
sämtliche Eltern- und Detailwerte NULL-sicher. Zwei weitere native Aufrufe
mit Zielplan-GUID, NULL-Subplanfilter und Datumsgrenzen lieferten ebenfalls
`0`. Die Zielcounts betrugen vor, zwischen und nach den beiden Zielpurges
drei, eins und null; die Gesamtcounts betrugen fünf, drei und zwei.
Die Detailcounts betrugen zehn, sechs und vier. Jede verbleibende Elternzeile
besaß zwei Details; verwaiste Details verblieben nicht. Sämtliche zehn Werte
der jüngeren Zielelternzeile und alle 13 Werte ihrer beiden Details blieben
nach dem ersten Zielpurge identisch. Die vollständigen älteren Gegenproben-
und Detailwerte blieben in allen drei Phasen identisch.

In allen drei Phasen bestätigten NONE, TABLE und CONSOLE native Elterncounts,
MIN-/MAX-Startzeiten, sechs verfügbare Quellen und eine Evidenzgrenze.
TABLE und CONSOLE besaßen Parität aller acht Fachfelder mit JSON. Sämtliche
Eltern- und Detailwerte blieben vor und nach jedem der neun Consumeraufrufe
NULL-sicher identisch. Detailcounts und Elternbindungen wurden auch nach den
Aufrufen geprüft. Die Callertransaktion blieb committable mit `@@TRANCOUNT=1`
und `LOCK_TIMEOUT=137`. Der Analyzer führte keinen Purge aus und erhielt
keinen neuen Plan- oder Detailquellenvertrag.

Das abschließende Rollback entfernte sämtliche injizierten Eltern und Details
und bestätigte alle vier Maintenancequellen als leer. Der öffentliche Lauf
endete mit `PASS` und `REMOVED`; das äußere identitygebundene Cleanup entfernte
eigenen Container, Volume und temporären State und bestätigte zwei Schritte
mit null Fehlern. Der funktionale Zweidateien-Slice wurde vor diesem ersten
nativen Charakterisierungslauf unabhängig geprüft. Runtimeidentitäten,
Secrets und Rohlogs bleiben außerhalb von Git.

Der Nachweis betrifft selektive Plan-ID-Filter bei NULL-Subplanfilter und
kontrollierter injizierter Historie. Er belegt weder selektive Subplanfilter
noch echte Plandefinitionen, Maintenance-/SSIS-Ausführung, unabhängige
Detaildatumssemantik, authentisches Alter, UTC-Umrechnung oder automatische
Aufbewahrung. Grenzwertgleichheit und empirisches inneres Fehlercleanup
bleiben getrennte Nachweise. Erfolgreiche Mail-Ausführung, weitere
Retentiongrenzen und fehlende optionale Quellen bleiben offen. OPS-008 bleibt
`PARTIAL_PRODUCT_FUNCTION`; TEST-0001, Registry, Maturityflags und historische
Release-Matrix bleiben unverändert. Die Fixture gehört zu OPS-008 und benötigt
keine eigene Artefaktreferenz.

## Ergänzende native OPS-008-Maintenance-Subplanfilterretention vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario MaintenanceSubplanRetention` bestand
auf einem neuen eigenen SQL-Server-2025-Linux-Docker-Lab die Coreinstallation,
Smoke-Test, Runtimevertrag `122` und die
[Subplanfilterretention-Fixture](../../../../TestLab/Scenarios/OPS-008/maintenance-subplan-retention.sql).
Er erfasste `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert.

Die Fixture prüfte acht native Subplanfelder, Textkapazitäten sowie die
Fremdschlüsselbindung der Elternhistorie an `subplan_id`. Innerhalb ihrer
Callertransaktion erzeugte `sp_add_job` einen deaktivierten eigenen Job mit
sämtlichen Benachrichtigungsleveln `0`, ohne Steps und ohne Serverzuordnung.
Drei injizierte Subplanmetadatensätze wurden an diesen Job gebunden.
Zwei Subpläne trugen denselben synthetischen Plan-GUID; der dritte trug
einen anderen Plan-GUID. Plans blieben leer. Diese Metadaten beschrieben
keine ausgeführten SSIS-Pläne; Maintenance, SSIS und Jobs wurden nicht ausgeführt.

Sechs eigene Elternzeilen erhielten je zwei gebundene Details. Drei
Elternzeilen trugen denselben Zielsubplan-GUID und kontrollierte Startzeiten
am 1. und 2. Januar 2025 sowie am 1. Januar 2000. Drei ältere Gegenproben vom
1. Januar 2000 trugen den anderen Subplan desselben Plans, den Subplan eines
anderen Plans beziehungsweise NULL für Plan und Subplan. Eltern und Details
verwendeten jeweils übereinstimmende kontrollierte Zeiten. Der Detailguard
prüfte 13 Feldnamen und Typen, Textkapazitäten sowie die native Elternbindung.

Ein nativer `sp_maintplan_delete_log`-Aufruf mit nicht passendem Subplan-GUID,
NULL-Planfilter und Datumsgrenze lieferte Rückgabewert `0` und erhielt sämtliche
Eltern- und Detailwerte NULL-sicher. Zwei weitere native Aufrufe mit
Zielsubplan-GUID, NULL-Planfilter und Datumsgrenzen lieferten ebenfalls `0`.
Die Zielcounts betrugen vor, zwischen und nach den beiden Zielpurges drei,
eins und null; die Gesamtcounts betrugen sechs, vier und drei. Die Detailcounts
betrugen zwölf, acht und sechs. Jede verbleibende Elternzeile besaß zwei
Details; verwaiste Details verblieben nicht. Sämtliche zehn Werte der jüngeren
Zielelternzeile und alle 13 Werte ihrer beiden Details blieben nach dem ersten
Zielpurge identisch. Die vollständigen älteren Gegenproben- und Detailwerte,
sämtliche drei Subplanmetadaten und die gesamte Jobquelle blieben in allen
drei Phasen identisch. Jobsteps, Serverzuordnung und Historie blieben leer.

In allen drei Phasen bestätigten NONE, TABLE und CONSOLE native Elterncounts,
MIN-/MAX-Startzeiten, sechs verfügbare Quellen und eine Evidenzgrenze.
TABLE und CONSOLE besaßen Parität aller acht Fachfelder mit JSON. Sämtliche
Eltern- und Detailwerte blieben vor und nach jedem der neun Consumeraufrufe
NULL-sicher identisch. Sämtliche Subplan- und Jobwerte waren nach jedem
Consumeraufruf gegenüber ihren vollständigen Ausgangssnapshots identisch.
Detailcounts und Elternbindungen wurden auch nach den Aufrufen geprüft. Die Callertransaktion blieb
committable mit `@@TRANCOUNT=1` und `LOCK_TIMEOUT=137`. Der Analyzer führte
keinen Purge aus und erhielt keinen neuen Plan- oder Detailquellenvertrag.

Das abschließende Rollback entfernte sämtliche injizierten Maintenancezeilen
und den eigenen Job; alle vier Maintenancequellen sowie Job- und Historyquelle
waren leer. Der öffentliche Lauf endete mit `PASS` und `REMOVED`; das äußere
identitygebundene Cleanup entfernte eigenen Container, Volume und temporären
State und bestätigte zwei Schritte mit null Fehlern. Der funktionale
Zweidateien-Slice wurde vor diesem ersten nativen Charakterisierungslauf
unabhängig geprüft. Runtimeidentitäten, Secrets und Rohlogs bleiben außerhalb
von Git.

Der Nachweis betrifft selektive Subplan-ID-Filter bei NULL-Planfilter und
kontrollierter injizierter Historie. Kombinierte Plan-/Subplanfilter, echte
SSIS-Pläne, Maintenance-Ausführung, unabhängige Detaildatumssemantik,
authentisches Alter, UTC-Umrechnung und automatische Aufbewahrung sind damit
nicht belegt. Grenzwertgleichheit und empirisches inneres Fehlercleanup
bleiben getrennte Nachweise. Erfolgreiche Mail-Ausführung, weitere
Retentiongrenzen und fehlende optionale Quellen bleiben offen. OPS-008 bleibt
`PARTIAL_PRODUCT_FUNCTION`; TEST-0001, Registry, Maturityflags und historische
Release-Matrix bleiben unverändert. Die Fixture gehört zu OPS-008 und benötigt
keine eigene Artefaktreferenz.

## Ergänzende native OPS-008-Maintenance-Filtergrenze vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario MaintenanceFilterBoundary` lieferte
auf einem neuen eigenen SQL-Server-2025-Linux-Docker-Lab `PASS` und `REMOVED`.
Coreinstallation, Smoke-Test, Runtimevertrag `122` und die
[Filtergrenzfixture](../../../../TestLab/Scenarios/OPS-008/maintenance-filter-boundary.sql)
bestanden. Der Lauf erfasste `ProductVersion=17.0.4075.5` und Framework-
Compatibility-Level 170. Server und `tempdb` verwendeten
`Latin1_General_100_CS_AS`, das Framework `SQL_Latin1_General_CP1_CS_AS`.
Produkt-SQL blieb unverändert.

Eine vorausgehende private Systemquellenabfrage auf einem getrennten neuen
Lab derselben nativen Version bestätigte den Ablehnungszweig vor dem DELETE:
Gleichzeitige nicht leere Plan- und Subplanparameter fordern Meldung `12980`
an. Vendorquelltext wurde ausschließlich privat gelesen und nicht in Git oder
GitHub übernommen. Zwei weitere private direkte SQL-Client-Gegenproben auf
jeweils neuen Labs bestätigten tatsächlich Fehler `2732`, Zeile 10. Die
Systemprozedur war als `is_ms_shipped` markiert und die englische Meldung
`12980` vorhanden. Beim datenbankübergreifenden Aufruf lautete
`ERROR_PROCEDURE()` exakt `msdb.dbo.sp_maintplan_delete_log`; bei
`XACT_ABORT ON` war die Callertransaktion danach uncommittable mit
`XACT_STATE()=-1` und `@@TRANCOUNT=1`. Beide Diagnoseproben erhielten vier
leere Maintenancequellen und endeten nach eigenem Cleanup mit `REMOVED`.
Die [Microsoft-Fehlerreferenz](https://learn.microsoft.com/en-us/sql/relational-databases/errors-events/database-engine-events-and-errors-2000-to-2999?view=sql-server-ver17)
beschreibt `2732` als ungültige Fehlernummer. Eine erfolgreiche Zustellung
der angeforderten Meldung `12980` ist damit ausdrücklich nicht belegt.

Die Fixture prüfte native Parameter-, Detail- und Subplanverträge sowie
Elternbindungen. Innerhalb ihrer Callertransaktion erzeugte sie einen
deaktivierten eigenen Job ohne Steps, Serverzuordnung oder Historie, drei
injizierte Subplanmetadaten und sechs Elternzeilen mit je zwei Details.
Drei Elternzeilen gehörten zum Zielsubplan; die älteren Gegenproben trugen
einen anderen Subplan desselben Plans, einen Subplan eines anderen Plans
beziehungsweise NULL für Plan und Subplan. Plans blieben leer.
Maintenance, SSIS und Jobs wurden nicht ausgeführt.

Bei `XACT_ABORT OFF` bestätigten je ein nativer Aufruf mit passenden und
widersprüchlichen Plan-/Subplan-IDs sowie Datumsgrenze Fehler `2732` aus der
exakt gebundenen Systemprozedur. Vollständige Eltern- und Detailsnapshots,
sämtliche Subplan- und Jobmetadaten, Counts sechs und zwölf sowie Zeitaggregate
blieben identisch. Die Callertransaktion blieb committable mit
`@@TRANCOUNT=1`, `LOCK_TIMEOUT=137` und `XACT_ABORT OFF`. Die Fehleraufrufe
belegen keinen positiven kombinierten Retentionfilter und keinen nativen
Rückgabewert.

In Baseline und beiden OFF-Ablehnungsphasen bestätigten NONE, TABLE und
CONSOLE sechs verfügbare Quellen, native Elternaggregate und eine Evidenzgrenze.
TABLE und CONSOLE besaßen Parität aller acht Fachfelder mit JSON. Sämtliche
Eltern- und Detailwerte blieben vor und nach jedem der neun Consumeraufrufe
NULL-sicher identisch. Subplan- und Jobwerte waren nach jedem Consumeraufruf
gegenüber ihren vollständigen Ausgangssnapshots identisch. Detailbindungen,
Callertransaktion, Locktimeout und OFF-Einstellung blieben erhalten.

Ein zusätzlicher nativer Aufruf mit passenden IDs bei `XACT_ABORT ON`
bestätigte denselben Fehler und den erwarteten uncommittable Callerzustand.
Die vollständigen vier erfassten Quellen blieben auch in diesem Zustand
lesend identisch; Counts betrugen weiterhin sechs Eltern und zwölf Details.
In der uncommittable Transaktion wurde kein Consumer aufgerufen. Das eigene
Rollback entfernte sämtliche Maintenancezeilen und den Job; vier
Maintenancequellen sowie Job- und Historyquelle waren danach leer.
Die Fixture verlangte vor Quellmutationen den Standardlocktimeout `-1`,
stellte ihn direkt im Callerbatch wieder her und prüfte abschließend auch
die ursprüngliche XACT_ABORT-Einstellung. Dynamische SET-Anweisungen werden
nach ihrer Rückkehr zurückgesetzt, wie die
[Microsoft-SET-Dokumentation](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-statements-transact-sql?view=sql-server-ver17)
beschreibt. Die entsprechend ältere Wiederherstellung in anderen Fixtures
wird als eigener Folgeschritt geprüft und korrigiert.

Vier öffentliche Vorläufe scheiterten vor dem vollständigen Abschluss:
zweimal an der zu engen 12980-Annahme, einmal an der unvollständigen
Prozedurbindung und einmal am letzten Calleroptionencheck. Ihr äußeres
Cleanup bestätigte jeweils zwei Schritte mit null Fehlern. Nach gezielten
Korrekturen und unabhängigen Reviews bestand der fünfte native Fixturelauf.
Ein nachgelagerter Shell-Ausgabefilter verwendete zunächst einen ungültigen
Parameter; die private Logprüfung bestätigte den bereits gelieferten
Runner-PASS, und die korrigierte Filterung lief erfolgreich. Der erfolgreiche
native Lauf wurde deshalb nicht wiederholt. Eigenes äußeres Cleanup entfernte
Container, Volume und temporären State mit zwei Schritten und null Fehlern.
Runtimeidentitäten, Secrets, Diagnosedaten und Rohlogs bleiben außerhalb von Git.

Der Nachweis betrifft die Parameterablehnung auf der tatsächlich geprüften
nativen Engine. Die drei Fehler werden gezielt innerhalb der Fixture behandelt;
ein ungeplanter äußerer Fixturefehler wird dadurch nicht simuliert.
Echte Maintenance-/SSIS-Ausführung, automatische Aufbewahrung, unabhängige
Detaildatumssemantik, weitere Retentiongrenzen und fehlende optionale Quellen
bleiben offen. OPS-008 bleibt `PARTIAL_PRODUCT_FUNCTION`; TEST-0001, Registry,
Maturityflags und historische Release-Matrix bleiben unverändert.
Die Fixture gehört zu OPS-008 und benötigt keine eigene Artefaktreferenz.

## Ergänzende OPS-008-Maintenance-Calleroptionen vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario MaintenanceCallerOptions` lieferte
auf einem neuen eigenen SQL-Server-2025-Linux-Docker-Lab `PASS` und `REMOVED`.
Coreinstallation mit 187 Batches, Smoke-Test `110`, Runtimevertrag `122`
und die vier bestehenden Maintenance-Retentionfixtures für Eltern, Details,
Plan-ID und Subplan-ID bestanden. Der Lauf erfasste
`ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert.

Der Slice korrigiert die ältere dynamische Locktimeoutwiederherstellung.
SET-Anweisungen in `sp_executesql` werden nach Rückkehr auf ihren
Ausgangswert zurückgesetzt, wie die
[Microsoft-SET-Dokumentation](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-statements-transact-sql?view=sql-server-ver17)
beschreibt. Jede betroffene Fixture verlangt vor Quelländerungen den
ursprünglichen Standardlocktimeout `-1`, erfasst XACT_ABORT vor einer Änderung
und setzt nach dem eigenen Rollback beide Optionen direkt im Callerbatch
zurück. Erfolg und Catch verwenden denselben begrenzten Wiederherstellungs-
umfang; Catch wirft den ursprünglichen Fehler nach dem Rollback erneut.
Die Abschlussassertion prüft neun Consumeraufrufe und die ursprünglichen
Locktimeout- und XACT_ABORT-Werte. Während der Consumeraufrufe wird zusätzlich
XACT_ABORT ON geprüft.

Die vorhandenen Retentionsorakel blieben erhalten. Eltern- und Detailfälle
bestätigten Counts drei, eins und null beziehungsweise sechs, zwei und null.
Der Plan-ID-Fall bestätigte Zielcounts drei, eins und null bei Gesamtcounts
fünf, drei und zwei und Details zehn, sechs und vier. Der Subplan-ID-Fall
bestätigte dieselben Zielcounts bei Gesamtcounts sechs, vier und drei und
Details zwölf, acht und sechs. Insgesamt 36 NONE-, TABLE- und CONSOLE-Aufrufe
bestätigten native Aggregate, Parität aller acht Fachfelder und die bestehenden
Quell-, Bindungs- und Callerzustandsprüfungen. Die vier eigenen Rollbacks
entfernten sämtliche injizierten Maintenancezeilen und im Subplanfall auch
den deaktivierten eigenen Job ohne Steps, Serverzuordnung oder Historie.
Alle vier Fixtures bestanden mit jeweils zwei Batches. Eigenes äußeres
Cleanup entfernte Container, Volume und temporären State mit zwei Schritten
und null Fehlern.

Eine zusätzliche private direkte SqlClient-Gegenprobe auf einem getrennten neuen
Lab derselben Version und desselben Frameworklevels bestand zwölf Fälle.
Jede Fixture wurde auf drei getrennten eigenen Verbindungen geprüft.
Zwei Varianten bestätigten zunächst die tatsächlichen ursprünglichen Optionen
und injizierten nach geprüftem Quellaufbau vor der ersten Consumerphase
`THROW 56090`. Die acht Fehlerfälle mit ursprünglichem XACT_ABORT OFF oder ON
bestätigten nach dem erneut geworfenen Fehler auf derselben offenen Verbindung
Locktimeout `-1`, den ursprünglichen XACT_ABORT-Wert und einen vor den
Quellabfragen erfassten Transaktionszustand null bei `@@TRANCOUNT=0`.
Sämtliche acht geprüften Maintenance-/Jobquellen waren leer, auch nach dem
Subplanaufbau mit eigenem Job. Vier weitere Varianten mit ursprünglichem
Locktimeout `31` und XACT_ABORT OFF bestätigten die jeweilige frühe Ablehnung
sowie unveränderte Optionen und leere Quellen ohne eigene Transaktion.

Die Fehlerprobe konsumierte die kanonischen SQL-Dateien mit genau einer
privaten Fehlerpunktinjektion je Fehlerfall. Skript, Quellenhashes, Diagnostik
und Ergebnisdatei bleiben außerhalb von Git. Es entstand weder ein öffentlicher
Fehlermodus noch eine kopierte fachliche Fixture. Die ersten beiden privaten
Vorläufe scheiterten an der zu engen Nachprüfung von XACT_STATE innerhalb des
datenlesenden Count-/JSON-SELECTs. Die zweite Diagnostik bestätigte bereits
Locktimeout `-1`, XACT_ABORT OFF, Transaktionscount null und acht leere Quellen,
während dieser SELECT XACT_STATE eins meldete. Nach getrennter Erfassung des
Transaktionszustands vor den Quellabfragen bestand die dritte Gegenprobe unverändert
gegen dieselben vier funktionalen Quellen. Jeder private Vorlauf und der
abschließende Gegenprobe entfernten das eigene Lab mit zwei Schritten und null
Fehlern; auch die erfolgreiche Gegenprobe entfernte den temporären State.
Der erfolgreiche öffentliche Retentionslauf wurde nicht wiederholt.

Der Nachweis betrifft die vier betroffenen Maintenance-Retentionfixtures,
Standardlocktimeout und XACT_ABORT sowie den gezielt injizierten Fehler vor
der ersten Consumerphase. Erfolgreiche Retention mit ursprünglich XACT_ABORT ON,
spätere Fehlerpunkte, NOCOUNT, allgemeine Temp-Tabellenbereinigung und zusätzliche
native Engines sind durch den privaten Probe nicht belegt. Die übrigen älteren
OPS-008-Fixtures benötigen eigene Korrektur- und Nachweisschritte; als Nächstes
folgen die vier injizierten Mailfixtures. Echte Maintenance-/SSIS-Ausführung,
automatische Aufbewahrung und weitere Retentiongrenzen bleiben offen.
OPS-008 bleibt `PARTIAL_PRODUCT_FUNCTION`; TEST-0001, Registry, Maturityflags
und historische Release-Matrix bleiben unverändert.


## Ergänzende OPS-008-Mail-Calleroptionen vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario MailCallerOptions` bestand auf einem
neuen eigenen SQL-Server-2025-Linux-Docker-Lab mit `PASS` und `REMOVED`.
Coreinstallation mit 187 Batches, Smoke-Test `110`, Runtimevertrag `122`
und die vier bestehenden injizierten Mailfixtures bestanden. Der Lauf
bestätigte `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert.

Die vier Fixtures verlangen vor Quelländerungen den ursprünglichen
Standardlocktimeout `-1`, erfassen XACT_ABORT vor einer Änderung und stellen
beide Optionen nach dem eigenen Rollback direkt im Callerbatch wieder her.
Der Catch-Pfad wirft den ursprünglichen Fehler nach Rollback und
Optionswiederherstellung erneut. Während der Consumeraufrufe werden
XACT_ABORT ON, Locktimeout 137 und eine committable eigene Transaktion geprüft.
Die Abschlussassertion prüft neun beziehungsweise 36 Consumeraufrufe und
die ursprünglichen beiden Optionen. Die Statusfixture restauriert ihre
Optionen abschließend nach allen vier getrennten Transaktionen.

Die gemischte Mail-/Maintenancefixture bestätigte Counts eins, zwei und drei
sowie die bestehenden nativen MIN-/MAX-Zeitwerte beider Quellen. Die
Failed-Mailretention bestätigte drei, eine und null Mailzeilen. Vier
Statusfälle für unsent, sent, failed und retrying bestätigten jeweils
Zielcounts drei, eins und null bei Gesamtcounts sechs, vier und drei;
vollständige jüngere Zielwerte und ältere andere Status blieben erhalten.
Die Anlagenretention bestätigte Mailcounts drei, eins und null,
Anlagenmengen sechs, zwei und null sowie Bytezahlen 54, 18 und null mit
vollständigen jüngeren Mail-/Anlagenwerten und erhaltenen Bindungen.
Insgesamt 63 NONE-, TABLE- und CONSOLE-Aufrufe bestanden die ursprünglichen
Aggregate, Paritäten aller acht Fachfelder und Quell-/Callerzustandsprüfungen.
Alle vier Fixtures bestanden mit jeweils zwei Batches. Sie führten weder
Mailversand noch Queueverarbeitung oder Maintenance aus. Sieben eigene
Rollbacks entfernten ihre injizierten Zeilen. Eigenes äußeres Cleanup entfernte
Container, Volume und temporären State mit zwei Schritten und null Fehlern.

Eine getrennte private direkte SqlClient-Gegenprobe auf einem weiteren neuen
Lab derselben nativen Kombination bestand zwölf Fälle. Jede Fixture lief
auf drei getrennten eigenen Verbindungen. Zwei Varianten bestätigten zuerst
die tatsächlichen ursprünglichen Optionen und injizierten nach geprüftem
Quellaufbau vor dem ersten Consumer `THROW 56090`. Der gemischte Fehlerpunkt
lag nach je einer Mail- und Maintenancezeile; die Failed-Mailfixture besaß
drei Mailzeilen, die Statusfixture im ersten unsent-Fall sechs Mailzeilen
und die Anlagenfixture drei Mailzeilen sowie sechs Anlagen mit 54 Bytes.
Die acht Fehlerfälle mit ursprünglich XACT_ABORT OFF oder ON bestätigten
nach dem erneut geworfenen Fehler auf derselben offenen Verbindung
Locktimeout `-1`, den ursprünglichen XACT_ABORT-Wert und vor Quellabfragen
erfassten Transaktionszustand null bei Transaktionscount null. Alle sieben
geprüften Mail-/Maintenancequellen waren leer; konfigurierte und aktive
Mail-XPs blieben deaktiviert. Vier frühe Locktimeout-31-Ablehnungen bei
ursprünglichem XACT_ABORT OFF bestätigten unveränderte Optionen und dieselben
leeren Quellen ohne eigene Transaktion.

Die Gegenprobe konsumierte die kanonischen SQL-Dateien mit genau einem
privaten Fehlerpunkt je Fehlerfall. Skript, Quellenhashes, Diagnostik und
Ergebnisdatei bleiben außerhalb von Git. Alle zwölf Ergebnisquellenhashes
entsprachen den geprüften vier SQL-Dateien. Die erste Gegenprobe bestand;
eigenes Cleanup entfernte ihr Lab und temporären State mit zwei Schritten
und null Fehlern. Der erfolgreiche öffentliche Lauf wurde nicht wiederholt.

Der Nachweis betrifft die vier injizierten Mailfixtures und die genannten
Fehlerpunkte. Spätere Fehlerpunkte, alle vier Status als getrennte Fehlerfälle,
erfolgreiche Retention mit ursprünglich XACT_ABORT ON, NOCOUNT,
Datenbankkontext und allgemeine Temp-Tabellenbereinigung bleiben unbelegt.
Fünf ältere dynamische Restores und der XACT_ABORT-Umfang der drei älteren
Fenster-/Agent-Aggregatfixtures benötigen getrennte Korrektur beziehungsweise
Prüfung; als Nächstes folgen die tatsächlichen Agent-Ausführungs- und
Agent-Retentionfixtures. Erfolgreicher Mailversand, tatsächliche Maintenance,
automatische Aufbewahrung, zusätzliche native Engines und weitere
Retentiongrenzen bleiben offen. OPS-008 bleibt `PARTIAL_PRODUCT_FUNCTION`;
TEST-0001, Registry, Maturityflags und historische Release-Matrix bleiben
unverändert.


## Ergänzende OPS-008-Agent-Calleroptionen vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario AgentCallerOptions` bestand auf einem
neuen eigenen SQL-Server-2025-Linux-Docker-Lab mit `PASS` und `REMOVED`.
Coreinstallation mit 187 Batches, Smoke-Test `110`, Runtimevertrag `122`
und beide bestehenden Agentfixtures bestanden. Der Lauf bestätigte
`ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170. Server
und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert.

Beide Fixtures verlangen vor Quelländerungen den ursprünglichen
Standardlocktimeout `-1` und erfassen XACT_ABORT vor einer Änderung.
XACT_ABORT wird im Try-Pfad vor der eigenen Joberzeugung aktiviert. Die
Consumer prüfen XACT_ABORT ON, Locktimeout 137 und eine committable eigene
Transaktion. Nach eigenem Rollback und Jobcleanup stellen Erfolg und Catch
beide Optionen direkt im Callerbatch wieder her; Catch wirft den
ursprünglichen Fehler erneut. Die Retentionfixture setzt nach jeder
Consumerphase den Locktimeout auf `-1` und erhält XACT_ABORT ON bis zum
abschließenden Jobcleanup. Finale Assertionen prüfen drei beziehungsweise
neun Consumeraufrufe sowie beide ursprünglichen Optionen.

Die Ausführungsfixture bestätigte einen erfolgreichen eigenen lokalen Job
mit einem T-SQL-Schritt und zwei nativen Historienzeilen. Die Retentionfixture
bestätigte zwei erfolgreiche eigene Ausführungen und vier, zwei sowie null
Historienzeilen nach gezielten nativen Job-ID-/Datumspurges. Vollständige
jüngere Historienwerte blieben erhalten. Insgesamt zwölf NONE-, TABLE- und
CONSOLE-Aufrufe bestanden Aggregate, Paritäten aller acht Fachfelder und
Quell-/Callerzustandsprüfungen. Beide Fixtures bestanden mit je zwei Batches;
sie injizierten keine Historie. Vier eigene Rollbacks und das abschließende
Jobcleanup entfernten sämtliche eigenen Job-, Step-, Server-, Schedule-,
Aktivitäts- und Historienzeilen. Das äußere Cleanup entfernte Container,
Volume und temporären State mit zwei Schritten und null Fehlern.

Eine getrennte private direkte SqlClient-Gegenprobe auf einem weiteren neuen
Lab derselben nativen Kombination bestand sechs Fälle. Jede Fixture lief
auf drei getrennten eigenen Verbindungen. Zwei Varianten bestätigten zuerst
die tatsächlichen ursprünglichen Optionen und injizierten `THROW 56090`
nach bestätigtem erfolgreichem Jobabschluss vor dem ersten Consumer.
Der Fehlerpunkt der Ausführungsfixture verlangte zwei native Historienzeilen,
derjenige der Retentionfixture vier Zeilen in Phase 1. Beide verlangten den
eigenen deaktivierten Job, einen Schritt, lokale Serverzuordnung, keine
Schedules und keine laufende eigene Aktivität. Jobhistorie wurde nicht
injiziert. Die vier Fehlerfälle mit ursprünglichem XACT_ABORT OFF oder ON
bestätigten nach erneutem Fehler auf derselben offenen Verbindung Locktimeout
`-1`, den ursprünglichen XACT_ABORT-Wert sowie vor Quellabfragen erfassten
Transaktionszustand null bei Transaktionscount null. Job-, Historien-, Step-,
Server-, Schedule- und Aktivitätsquellen waren leer. Zwei frühe
Locktimeout-31-Ablehnungen bei ursprünglichem OFF bestätigten unveränderte
Optionen und dieselben leeren Quellen ohne Joberzeugung.

Die private Gegenprobe konsumierte die kanonischen SQL-Dateien mit genau
einem eindeutigen Fehlerpunkt je Fehlerfall. Fixturebatches hatten ein
begrenztes Timeout von 300 Sekunden für die vorhandenen zwei Pollschleifen
mit je höchstens 120 einsekündigen Wartezyklen und das Catch-Jobcleanup.
Einzelabfragen und Verbindungsaufbau blieben auf 30 Sekunden begrenzt. Die sechs Ergebnisquellenhashes entsprachen
den geprüften zwei SQL-Dateien. Skript, Diagnostik und Ergebnisdatei bleiben
außerhalb von Git. Die erste Gegenprobe bestand; eigenes Cleanup entfernte
Container, Volume und temporären State mit zwei Schritten und null Fehlern.
Der erfolgreiche öffentliche Lauf wurde nicht wiederholt.

Der Nachweis betrifft die beiden Agentfixtures und Fehlerpunkte nach
abgeschlossenem Job. Bei Retention ist ausschließlich Phase 1 als Fehlerfall
belegt. Laufende Jobs, Stop-/Pollfehler, spätere Fehlerpunkte, erfolgreiche
Retention mit ursprünglichem XACT_ABORT ON, NOCOUNT, Datenbankkontext und
allgemeine Temp-Tabellenbereinigung bleiben unbelegt. Drei ältere dynamische
Restores bleiben offen; als Nächstes folgt die Backup-/Restore-Retentionfixture.
Der XACT_ABORT-Umfang der drei älteren Fenster-/Agent-Aggregatfixtures benötigt
eine getrennte Prüfung. Erfolgreicher Mailversand, tatsächliche Maintenance,
automatische Aufbewahrung, zusätzliche native Engines und weitere
Retentiongrenzen bleiben offen. OPS-008 bleibt `PARTIAL_PRODUCT_FUNCTION`;
TEST-0001, Registry, Maturityflags und historische Release-Matrix bleiben
unverändert.


## Ergänzende OPS-008-Backup-/Restore-Calleroptionen vom 8. Oktober 2026

Der öffentliche Runner mit `-Scenario BackupRestoreRetention` bestand auf
einem neuen eigenen SQL-Server-2025-Linux-Docker-Lab mit `PASS` und `REMOVED`.
Coreinstallation mit 187 Batches, Smoke-Test `110`, Runtimevertrag `122`
und die bestehende Backup-/Restore-Retentionfixture bestanden. Der Lauf
bestätigte `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Produkt-SQL blieb unverändert.

Die Fixture verlangt vor Quelländerungen den ursprünglichen
Standardlocktimeout `-1` und erfasst XACT_ABORT vor einer Änderung.
XACT_ABORT wird im Try-Pfad vor der eigenen Datenbankerzeugung aktiviert.
Die Consumer prüfen XACT_ABORT ON, Locktimeout 137 und eine committable
eigene Transaktion. Nach jeder Consumerphase wird der Locktimeout direkt
auf `-1` gesetzt; XACT_ABORT bleibt bis zum eigenen Erfolgscleanup aktiv.
Erfolg und Catch restaurieren beide ursprünglichen Optionen direkt im
Callerbatch. Der Erfolg prüft zusätzlich neun Consumeraufrufe; Catch wirft
den ursprünglichen Fehler nach eigenem Rollback und Optionswiederherstellung
erneut. Das bestehende äußere Labcleanup bleibt für fehlgeschlagene eigene
Backup-/Restore-Ressourcen verantwortlich.

Der native Lauf bestätigte drei tatsächliche Backups einer eigenen leeren
Datenbank und drei Restores in dieselbe eigene Restore-Datenbank. Kontrollierte
Zeitstempel und zwei native Datumsbereinigungen bestätigten drei, ein und
null eigene Paare. Jüngere vollständige Werte aller acht betroffenen
Historientabellen blieben erhalten. Neun NONE-, TABLE- und CONSOLE-Aufrufe
bestanden Counts, native MIN-/MAX-Zeitwerte, Paritäten aller acht Fachfelder
und Quell-/Callerzustandsprüfungen. Acht Katalogfelder beider Datenbanken
blieben nach drei eigenen Consumerrollbacks erhalten. Die Fixture bestand
mit zwei Batches und entfernte im Erfolgspfad beide genau gebundenen eigenen
Datenbanken. Das äußere Cleanup entfernte Container, Volume, Backupdateien
und temporären State mit zwei Schritten und null Fehlern.

Eine getrennte private direkte SqlClient-Gegenprobe bestand drei Fälle auf
zwei weiteren neuen Labs derselben nativen Kombination. Das erste Lab führte
auf getrennten eigenen Verbindungen eine frühe Locktimeout-31-Ablehnung bei
XACT_ABORT OFF und einen Fehler mit ursprünglichem OFF aus; das zweite Lab
führte den Fehler mit ursprünglichem ON aus. Die Fehlerfälle injizierten
`THROW 56090` nach drei tatsächlichen Backup-/Restore-Paaren vor dem ersten
Consumer in Phase 1. Ein privater Snapshot vor der Consumertransaktion erfasste
die vollständigen Werte aller acht Historienquellen und die acht bereits
öffentlich geprüften Datenbankkatalogfelder einschließlich beider eigenen
Datenbank-IDs. Der Snapshot blieb nach dem Consumerrollback verfügbar.

Nach erneutem Fehler bestätigte dieselbe offene Verbindung Locktimeout `-1`,
den ursprünglichen XACT_ABORT-Wert sowie vor Quellabfragen erfassten
Transaktionszustand null bei Transaktionscount null. Beide genau gebundenen
eigenen Datenbanken, sämtliche Historienwerte und alle acht Katalogfelder
blieben erhalten. Die beiden Fehlerfälle bestätigten Historiencounts drei,
sechs, drei, drei, drei, drei, sechs und drei für `backupset`, `backupfile`,
`backupfilegroup`, `backupmediaset`, `backupmediafamily`, `restorehistory`,
`restorefile` und `restorefilegroup`. Die frühe Ablehnung bestätigte unveränderte
Optionen, keine der beiden eigenen Datenbanken und alle acht leeren Quellen.
Dieser Befund belegt die vorhandene äußere Cleanupgrenze; der SQL-Catch
entfernt die außerhalb der Consumertransaktion erzeugten Ressourcen nicht.

Beide privaten Labs wurden anschließend einzeln durch das identitygebundene
äußere Cleanup entfernt: je zwei Schritte mit null Fehlern sowie entfernte
Container, Volumes und temporäre States. Die drei Ergebnisquellenhashes
entsprachen der geprüften kanonischen SQL-Datei. Genau ein eindeutiger Fehlerhook
und ein Snapshot vor der Consumertransaktion ergänzten die privat konsumierte
Quelle; Skript, Rohdaten und Ergebnisdatei bleiben außerhalb von Git.
Die erste Gegenprobe bestand. Fixturebatches waren auf 300 Sekunden begrenzt,
Einzelabfragen und Verbindungsaufbau auf 30 Sekunden. Der erfolgreiche
öffentliche Lauf wurde nicht wiederholt.

Der private Fehlernachweis betrifft ausschließlich den Punkt vor dem ersten
Consumer in Phase 1. Spätere Backup-/Restore- oder Purgefehler, erfolgreiche
Retention mit ursprünglichem XACT_ABORT ON, NOCOUNT, Datenbankkontext und
allgemeine Temp-Tabellenbereinigung bleiben unbelegt. Zwei ältere dynamische
Restores bleiben offen; als Nächstes folgen tatsächlicher Mailfehler und
Maillogretention. Der XACT_ABORT-Umfang der drei älteren Fenster-/Agent-
Aggregatfixtures benötigt eine getrennte Prüfung. Erfolgreicher Mailversand,
tatsächliche Maintenance, automatische Aufbewahrung, zusätzliche native Engines
und weitere Retentiongrenzen bleiben offen. OPS-008 bleibt
`PARTIAL_PRODUCT_FUNCTION`; TEST-0001, Registry, Maturityflags und historische
Release-Matrix bleiben unverändert.


## Ergänzende OPS-008-native Mail-Calleroptionen vom 8. Oktober 2026

Die bestehenden öffentlichen Szenarien `MailExecutionFailure` und
`MailLogRetention` bestanden nacheinander auf zwei getrennten neuen eigenen
SQL-Server-2025-Linux-Docker-Labs mit `PASS` und `REMOVED`. Beide Läufe
bestätigten `ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Je Lab bestanden Coreinstallation mit
187 Batches, Smoke-Test `110`, Runtimevertrag `122` und die jeweilige
bestehende Mailfixture mit zwei Batches. Produkt-SQL und Runner blieben
unverändert. Die Ausführungs-Fixture bestand in 62,7 Sekunden, die
Logretentions-Fixture in 185,0 Sekunden.

Beide Fixtures verlangen vor Quelländerungen den ursprünglichen
Standardlocktimeout `-1` und erfassen XACT_ABORT vor einer Änderung.
XACT_ABORT wird im Try-Pfad vor der ersten Konfigurationsänderung aktiviert.
Consumer prüfen eine committable eigene Transaktion, Locktimeout 137 und
XACT_ABORT ON. Erfolg und Catch restaurieren beide ursprünglichen Optionen
direkt im Callerbatch. Der Erfolg prüft zusätzlich drei beziehungsweise
neun Consumeraufrufe; Catch wirft den ursprünglichen Fehler nach eigenem
Rollback und Optionswiederherstellung erneut. Der SQL-Catch entfernt
Mail-, Profil- und Kontoressourcen nicht und restauriert Queue- oder
Konfigurationseintrittswerte nicht; das bestehende äußere Labcleanup
bleibt dafür erforderlich.

Der erste native Lauf bestätigte einen tatsächlichen eigenen lokalen
Queuefehler ohne Historieninjektion, nativen Failed-Status und gebundenes
Prozessfehlerlog. Drei NONE-, TABLE- und CONSOLE-Aufrufe bestanden native
Mailaggregate, Paritäten aller acht Fachfelder und Quell-/Callerzustands-
prüfungen bei deaktivierten Mail-XPs. Eigene Mailitems, Profil und Konto
wurden im Erfolg entfernt; Queue- und Konfigurationseintrittswerte wurden
wiederhergestellt.

Der zweite native Lauf bestätigte drei tatsächliche eigene lokale Mailfehler,
drei ausgewählte Prozessfehlerlogs und eine native Informationsgegenprobe.
Zwei typ- und datumsgebundene Logpurges bestätigten ausgewählte Counts drei,
eins und null. Vollständige jüngere und eingefrorene übrige Logwerte sowie
sämtliche Mailitemwerte blieben bei neun Consumeraufrufen erhalten. Das
Callerrollback stellte die ursprünglichen vier ausgewählten Logwerte wieder
her. Eigenes Mail-, Profil- und Kontocleanup sowie Queue- und
Konfigurationswiederherstellung bestanden. Native Logs blieben bis zum
äußeren Cleanup erhalten; deshalb wurden beide Szenarien in getrennten
neuen Labs ausgeführt. Jedes äußere Cleanup entfernte Container, Volume
und den eigenen Run mit zwei Schritten und null Fehlern. Beide eigenen
Stateverzeichnisse waren danach nicht mehr vorhanden.

Der erste private Fehlerlauf bestätigte die frühe Locktimeout-31-Ablehnung,
brach aber vor dem erwarteten injizierten Fehler mit einer zunächst nicht
nummeriert erfassten SQL-Ausnahme ab. Ein getrenntes neues Diagnoselab
identifizierte Fehler 515 beim Snapshotinsert: Die private Prüfspalte
`LogColumn sysname` erlaubte implizit kein NULL, obwohl die Ausführungs-
Fixture dort kein Logspaltenmerkmal benötigt. Die private Deklaration wurde
auf `sysname NULL` korrigiert; unerwartete Fehler werden anschließend nur
mit Nummer und Zeile erfasst. Der erste unabhängige Review hatte diese
Eigenschaft des Aliasdatentyps übersehen. Die beiden gescheiterten Labs
wurden jeweils mit zwei Schritten und null Fehlern entfernt; beide eigenen
Stateverzeichnisse waren danach nicht mehr vorhanden. Die geprüften
öffentlichen SQL-Fixtures wurden dafür nicht verändert und ihre bereits
erfolgreichen normalen Läufe nicht wiederholt.

Der korrigierte private Lauf bestand sechs Fälle auf vier getrennten neuen
eigenen SQL-Server-2025-Labs derselben Version und desselben Framework-
Compatibility-Levels. Je Fixture bestätigte eine frühe Ablehnung bei
Locktimeout 31 ursprüngliches XACT_ABORT OFF, leere Mail-, Anlagen-,
Profil-, Konto-, Bindungs- und Logquellen sowie deaktivierte Mail-XPs
auf derselben Verbindung. Vier weitere Fälle injizierten Fehler 56090
vor dem ersten Consumer mit ursprünglichem XACT_ABORT OFF oder ON.
Der Fehlerpunkt der Maillogretention lag ausschließlich in Phase 1 nach
kontrollierter Datumsanpassung; spätere Purgephasen sind nicht fehlergeprüft.

Alle vier Catchfälle warfen den ursprünglichen Fehler erneut und bestätigten
auf derselben Verbindung Locktimeout `-1`, die ursprüngliche XACT_ABORT-
Einstellung, null Transaktionen und XACT_STATE 0. Vollständige Werte der
einen beziehungsweise drei eigenen Failed-Mailitems, des Profils, Kontos
und der exakten Profil-/Kontobindung blieben erhalten. Gebundene native
Prozessfehlerlogs blieben vorhanden; Anlagen blieben leer und Mail-XPs
deaktiviert. Die beiden Logfälle bestätigten zusätzlich vollständige
Originalwerte derselben drei ausgewählten Fehlerlogs und Informationszeile
nach dem eigenen Rollback. Zusätzliche asynchrone Logzeilen wurden dabei
nicht als unveränderliche Gesamtquelle behandelt. Private Snapshots lagen
außerhalb der Consumertransaktion und wurden ausschließlich im SQL-Speicher
verglichen; ausgegebene Ergebnisse enthalten nur sanitisierte Metadaten,
Counts und Flags, keine Snapshotpayloads.
Je Lab bestand das äußere Cleanup mit zwei Schritten und null Fehlern.
Alle vier eindeutig eigenen Stateverzeichnisse waren abschließend nicht
mehr vorhanden. Queue- und Konfigurationseintrittswerte gelten dadurch
nicht als durch den SQL-Catch wiederhergestellt.

Rawlogs, private Snapshotwerte, Fehlerharness und eigene Laufidentitäten
bleiben außerhalb Git. Weder erfolgreicher Eintritt mit XACT_ABORT ON noch
Fehler nach späteren Logpurges, NOCOUNT, Datenbankkontext, allgemeines
Temp-Tabellen-Cleanup oder zusätzliche native Engines sind damit belegt.
Die drei älteren Fenster- und Agent-Aggregatfixtures benötigen weiterhin
eine getrennte XACT_ABORT-Prüfung. Erfolgreicher Mailversand, tatsächliche
Maintenance, automatische Aufbewahrung und weitere Retentiongrenzen
bleiben offen. OPS-008 bleibt `PARTIAL_PRODUCT_FUNCTION`; TEST-0001,
Registry, Maturityflags und historische Release-Matrix bleiben unverändert.


## Ergänzende OPS-008-Fenster- und Agent-Aggregat-Calleroptionen vom 8. Oktober 2026

Die bestehenden öffentlichen Szenarien `HistoryRestore` und `AgentHistory`
bestanden nacheinander auf zwei getrennten neuen eigenen SQL-Server-2025-
Linux-Docker-Labs mit `PASS` und `REMOVED`. Beide Läufe bestätigten
`ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Je Lab bestanden Coreinstallation mit 187 Batches, Smoke-Test `110`,
Runtimevertrag `122` und die ausgewählten bestehenden SQL-Fixtures mit
je zwei Batches. Produkt-SQL, Runner und TEST-0001-Kennung blieben unverändert.

Die drei Fixtures erfassen XACT_ABORT vor einer Änderung und aktivieren es
innerhalb des Try-Pfads. Erfolg und Catch restaurieren den ursprünglichen
Wert direkt im Callerbatch; Catch wirft den ursprünglichen Fehler erneut.
Die Fensterfixtures verlangen vor ihren Änderungen einen Caller ohne
offene Transaktion. Alle Consumer prüfen TX0 beziehungsweise die eigene
committable Agenttransaktion, den unveränderten ursprünglichen Locktimeout
und XACT_ABORT ON. Kein Fixture setzt oder beschränkt den Locktimeout.
Die Erfolgsprüfungen bestätigen fünf Backup-/Wachstumsaufrufe, drei
Restoreaufrufe und drei Agentstufen. Alle elf Consumer verwenden NONE.

Der normale Fensterlauf bestätigt drei tatsächliche eigene Backups und
drei Restores mit kontrollierten kurzen und langen Historienzeitfenstern.
Die eigene msdb-Dateierweiterung beträgt mindestens 8 MB bei einer
Zielfilegrenze von höchstens 128 MB; die ausgegebene aktuelle Größe stimmt
mit der nativen Quelle überein. Der Agentlauf bestätigt eine, zwei und drei
injizierte Job-/Stepzeilen mit erhaltenen vollständigen Historienwerten,
deaktiviertem eigenem Job ohne Ausführungsbindung und eigenem Rollback.
Jedes äußere Cleanup entfernte Container und Volume mit zwei Schritten
und null Fehlern. Beide eigenen Stateverzeichnisse waren danach nicht vorhanden.

Der erste normale Lauf brach nach dem ersten leeren NONE-Aufruf mit Fehler
55152 vor der Datenbankerzeugung ab; das Agentszenario wurde dabei nicht
ausgeführt. Eine zusätzliche neue private Diagnose erfasste nach diesem
Aufruf TX0 bei XACT_STATE 1, erhaltenem Locktimeout 31 und XACT_ABORT ON.
Die zunächst ergänzte XACT_STATE-0-Annahme außerhalb einer expliziten
Transaktion wurde aus den Fensterassertions entfernt. Innerhalb der eigenen
Agenttransaktion bleibt XACT_STATE 1 erforderlich. Die Diagnose scheiterte
zusätzlich am privaten Vergleich NULL gegen NULL für die leere Datenbank-
JSON-Menge; dieser Vergleich wurde NULL-sicher korrigiert. Nach Catch
erfasste die Diagnose TX0, XACT_STATE 0 und ursprüngliches XACT_ABORT OFF;
alle Historien-, Datenbank- und Agentcounts waren null. Die zwei gescheiterten
Labs wurden jeweils mit zwei Schritten und null Fehlern entfernt; beide
eigenen Stateverzeichnisse waren danach nicht vorhanden. Daraus wird kein
Produktfehler oder allgemeiner Enginefehler abgeleitet.

Der korrigierte private Fehlerlauf bestand neun Fälle in fünf getrennten
neuen eigenen Labs derselben Engineversion und desselben Framework-CL.
Je Fixture bestätigte eine frühe TX1-Ablehnung ursprüngliches XACT_ABORT
OFF, Locktimeout 31, eine unveränderte committable Callertransaktion und
vollständige vorhandene Quellen. Die Restore-Vorbereitung verwendete die
kanonische Fensterfixture mit drei tatsächlichen Backups und Dateiwachstum.
Das private äußere Rollback beendete ausschließlich seine eigene
Vorprüfungstransaktion. Die geprüften frühen Fehlernummern sind 55151,
55153 und 54943.

Sechs weitere Fälle injizierten Fehler 56090 mit ursprünglichem XACT_ABORT
OFF oder ON. Der Historyfehler folgt dem ersten tatsächlichen Backup und
seiner Datumsanpassung vor dem nächsten Consumer; ein anfänglicher leerer
Consumer war bereits erfolgt. Der Restorefehler folgt dem ersten
tatsächlichen Restore und seiner Datumsanpassung vor dem ersten Consumer.
Der Agentfehler folgt der ersten injizierten Historyzeile vor dem ersten
Consumer. Nach erneut geworfenem Fehler bestätigte dieselbe Verbindung
Locktimeout 31, ursprüngliches XACT_ABORT, TX0 und den vor Quellabfragen
erfassten XACT_STATE 0. Fensterfehler erhielten vollständige Werte aller
acht Historienquellen, acht Datenbankkatalogfelder und exakte eigene
Datenbankbindungen. Historyfälle behielten eine eigene Datenbank und ein
Backup; Restorefälle zwei eigene Datenbanken, drei Backups und einen
Restore. Das Agentrollback erhielt sämtliche ursprünglichen Werte der
sechs Agentquellen; diese waren leer. Private Snapshots wurden ausschließlich
im SQL-Speicher verglichen. Ausgegebene Ergebnisse enthalten sanitisierte
Metadaten, Counts und Flags, keine Snapshotpayloads.

Je Lab bestand das äußere Cleanup mit zwei Schritten und null Fehlern.
Alle fünf eigenen Stateverzeichnisse waren abschließend nicht vorhanden.
Fenster-Catchpfade entfernen Datenbanken, Dateien und native Historien
nicht; das äußere identitygebundene Labcleanup bleibt dafür erforderlich.
Rawlogs, private Snapshotwerte, Fehlerharness und eigene Laufidentitäten
bleiben außerhalb Git. Erfolgreicher Eintritt mit ursprünglichem ON,
spätere Fehlerpunkte, NOCOUNT, Datenbankkontext, allgemeines temporäres
Tabellencleanup und zusätzliche native Engines bleiben unbelegt.
Erfolgreicher Mailversand, tatsächliche Maintenance, automatische
Aufbewahrung und weitere Retentiongrenzen bleiben offen. OPS-008 bleibt
`PARTIAL_PRODUCT_FUNCTION`; Registry, Maturityflags und historische
Release-Matrix bleiben unverändert.

## Ergänzende OPS-008-NULL-Datumsretention für Failed-Mail vom 8. Oktober 2026

Das bestehende Szenario `MailRetention` bestand auf einem neuen eigenen
SQL-Server-2025-Linux-Docker-Lab mit `PASS` und `REMOVED`,
`ProductVersion=17.0.4075.5` und Framework-Compatibility-Level 170.
Coreinstallation mit 187 Batches, Smoke-Test `110`, Runtimevertrag `122`
und die bestehende SQL-Fixture mit zwei Batches bestanden. Produkt-SQL,
Runner, Szenarioname und TEST-0001-Kennung blieben unverändert.

Der erste datumsgebundene Fall bleibt mit drei, einer und null Failed-
Mailzeilen sowie neun NONE-/TABLE-/CONSOLE-Aufrufen erhalten. Ein zweiter
eigener Transaktionsfall ergänzt drei Failed-Zeilen aus 2000, 2025 und 2030
und je eine ältere unsent-, sent- und retrying-Gegenprobe aus 1999.
Die drei Gegenproben werden anhand ihrer bei INSERT erfassten eigenen IDs
gebunden. Die vollständigen ursprünglichen Mailitemwerte werden NULL-sicher
im SQL-Speicher verglichen. Die native Bereinigung verwendet ausdrücklich
`@sent_before=NULL` und `@sent_status='failed'` bei Returncode `0`.
Alle drei Failed-Zeilen verschwinden; die drei anderen Status bleiben
unverändert. Die Gesamtmenge fällt von sechs auf drei und die Failed-Menge
von drei auf null. Unabhängige native Statuscounts und MIN-/MAX-Zeitwerte
bestätigen die Auswahl. Sechs weitere Consumer prüfen native Aggregate,
vollständige TABLE-/CONSOLE-/JSON-Parität, Quellerhaltung und Callerzustand.
Die Mail-XPs bleiben konfiguriert und effektiv deaktiviert; Anlagen bleiben
leer. Die Fixture führt keinen Versand und keine Queueverarbeitung aus.

Insgesamt bestätigt die Fixture 15 Consumeraufrufe und zwei eigene Rollbacks.
Nach jedem Rollback müssen die drei Mailquellen leer und Transaktionen
geschlossen sein. Die sieben Summaryfelder bleiben unverändert;
`InitialRows`, `RetainedRows` und `FinalRows` bezeichnen weiterhin den ersten
Fall mit drei, einer und null Zeilen. `ConsumerCalls` beträgt nun 15.
Die Gruppe `MailCallerOptions` umfasst dadurch 69 geplante Aufrufe;
der historische gemeinsame Lauf mit 63 Aufrufen bleibt gültig, wurde aber
nicht als gemeinsamer 69-Aufruf-Lauf wiederholt.

Ein zusätzlicher privater Lauf in einem weiteren neuen eigenen Lab derselben
Engineversion und desselben Framework-CL bestätigt zwei erfolgreiche
Teilfälle. Der unveränderte Erfolg mit ursprünglichem XACT_ABORT ON prüft
die tatsächlich gelesenen sieben Summaryfelder einschließlich 15 Calls.
Eine ausschließlich im Speicher veränderte endliche Datumsgrenze 2026
lässt die Failed-Zeile aus 2030 stehen und wird mit 55185 in Fall 2,
Phase 2 nach zwölf abgeschlossenen Consumeraufrufen abgelehnt.
Nach beiden Teilfällen bestätigt dieselbe Verbindung ursprünglichen
Locktimeout -1, ursprüngliches XACT_ABORT, TX0 und vor Quellabfragen
erfassten XACT_STATE 0. Mailitems, Allitems und Anlagen sind leer;
konfigurierte und effektive Mail-XPs bleiben deaktiviert.

Der private Gesamtlauf endet mit FAIL und Fehler 56091 im dritten
Catchorakel; die Ergebnisdatei wird nicht geschrieben. Die Erwartung,
dass Datum NULL und Status NULL alle Zeilen löschen und danach 55185
auslösen, war falsch. Der native Microsoft-Parametervertrag verlangt
mindestens einen wirksamen Filter. Der private Catchhook verdeckte die
ursprüngliche Fehlernummer. Daraus wird kein Produkt- oder kanonischer
Fixturefehler abgeleitet. Die anschließend ausgeführten beiden getrennten
Diagnosefälle stehen im folgenden Nachweis; die zuvor bestandenen ON- und
endlichen Datumsfälle werden dabei nicht wiederholt.

Beide äußeren Cleanups des normalen und des fehlgeschlagenen privaten
Laufs entfernten Container und Volume mit je zwei Schritten und null
Fehlern. Beide eigenen Stateverzeichnisse waren abschließend nicht vorhanden.
Ein früherer normaler Versuch und der erste private Versuch scheiterten
vor Provisionierung und SQL-Ausführung an der belegten Host-Testlane.
Dafür wird kein Laufzeit- oder Cleanupnachweis behauptet; es entstanden
keine eigenen Labressourcen. Beide tatsächlichen Wiederholungen erfolgten
erst nach beobachteter Freigabe. Begrenzte Free-Beobachter fanden während
ihrer jeweiligen 45 Sekunden keine Freigabe und starteten keinen Lauf.
Kein Guard oder Timeout wurde abgeschwächt. Rawlogs, private Proben und
eigene Laufidentitäten bleiben außerhalb Git. Erfolgreicher Mailversand,
Maintenance-Ausführung, automatische Aufbewahrung und weitere Filter-/
Retentionsgrenzen bleiben offen. OPS-008 bleibt `PARTIAL_PRODUCT_FUNCTION`;
Registry, Maturityflags und historische Release-Matrix bleiben unverändert.

### OPS-008: ergänzende NULL-Datumsdiagnose der Mailretention

Am 8. Oktober 2026 beendet ein weiterer privater Lauf in einem neuen eigenen
SQL-Server-2025-Linux-Docker-Lab beide vorbereiteten Diagnosefälle mit
`COMPLETED`. ProductVersion ist 17.0.4075.5, der Framework-CL 170.
Die Coreinstallation besteht 187 Batches. Der zuvor bestandene normale
Fixturelauf, Smoke 110, Runtimevertrag 122 und die zwei erfolgreichen
Teilfälle des früheren privaten Laufs werden nicht wiederholt.

Die erste ausschließlich im Speicher veränderte Fassung verwendet in Fall 2
Datum NULL und Status NULL. Sie erfasst den ursprünglichen SQL-Fehler 14608,
Prozedur-Enum OTHER, Phase 2 und zwölf abgeschlossene Consumeraufrufe.
Vor dem Rollback bestätigt ein case-sensitiver vollständiger JSON-Vergleich
mit INCLUDE_NULL_VALUES dieselben sechs Mailitems und sämtliche ursprünglichen
Werte. OTHER bezeichnet einen erfassten Prozedurwert außerhalb der beiden
geprüften Purgenamen; der genaue Prozedurname wurde nicht übernommen und
wird nicht behauptet. Dieser Fall heißt `OBSERVED_REJECTION`, nicht PASS.

Die zweite getrennte Verbindung verwendet Datum 2031 und Status NULL.
Die gültige native Filterauswahl entfernt alle sechs eigenen Zeilen;
das bestehende Fixture-Orakel weist sie mit 55185 im Callerbatch zurück.
Fall 2, Phase 2, zwölf abgeschlossene Consumeraufrufe und null verbleibende
Mailitems vor dem Rollback sind bestätigt. Der vollständige Quellvergleich
ist erwartungsgemäß falsch. Diese Gegenprobe besteht mit PASS.

Nach jedem Fall bestätigt dieselbe jeweilige Verbindung ursprünglichen
Locktimeout -1, ursprüngliches XACT_ABORT OFF, TX0 und vor Quellabfragen
erfassten XACT_STATE 0. Mailitems, Allitems und Anlagen sind leer;
konfigurierte und effektive Mail-XPs bleiben deaktiviert. Der Catchhook
erfasst Fehler und Quellwerte vor dem kanonischen Rollback, speichert
ausschließlich Diagnosemetadaten nach dessen Ausführung und wirft den
ursprünglichen SQL-Fehler erneut. Der Harness bindet Hash und Mutationen
an denselben explizit als UTF8_LF normalisierten kanonischen Quelltext.

Das eigene äußere Cleanup entfernt Container und Volume mit zwei Schritten
und null Fehlern; das eigene Stateverzeichnis ist anschließend nicht vorhanden.
Die private Ergebnisdatei enthält beide Fälle; Rawlog, Harness, Payloads
und Laufidentitäten bleiben außerhalb Git. Der frühere private FAIL mit
Catchfehler 56091 und fehlender Ergebnisdatei bleibt als eigener Fehlversuch
erhalten. Die neue Diagnose macht ihn nicht nachträglich erfolgreich.

Produkt-SQL, Fixture, Runner, sieben Summaryfelder, Registry und historische
Release-Matrix bleiben unverändert. Der gemeinsame logische Gruppenvertrag
mit 69 Calls wird nicht als erneut ausgeführter Gruppenlauf ausgegeben.
OPS-008 bleibt PARTIAL_PRODUCT_FUNCTION. Erfolgreicher Mailversand,
Maintenance-Ausführung, automatische Aufbewahrung und weitere Filter-/
Retentionsgrenzen bleiben eigenständig offen.

## Ergänzende OPS-008-Agent-Datums- und Dauerinterpretation vom 8. Oktober 2026

Die bestehende TEST-0001-Fixture im öffentlichen `AgentHistory`-Runner behält
ihre drei ursprünglichen Aggregatstufen. Anschließend injiziert sie in
derselben eigenen Transaktion drei zusätzliche Joboutcomes mit `step_id=0`.
Historycounts vier, fünf und sechs werden durch Msdb-Aggregate bestätigt.
Ein deaktivierter eigener Job besitzt weiterhin keine Stepdefinition,
Serverzuordnung, Schedule oder tatsächliche Ausführung.

| run_date | run_time | run_duration | Lokaler Startzeitpunkt | AgentJobs-Sekunden | Monitoring-Rohdauer |
|---:|---:|---:|---|---:|---:|
| 20240229 | 0 | 0 | 2024-02-29 00:00:00 | 0 | 0 |
| 20240229 | 10203 | 125 | 2024-02-29 01:02:03 | 85 | 125 |
| 20250102 | 235959 | 1000000 | 2025-01-02 23:59:59 | 360000 | 1000000 |

Erwartete Zeitpunkte und Sekunden sind unabhängige Literale.
`USP_AgentJobs` wird exakt auf den eigenen Job gefiltert;
`USP_AgentMonitoringAnalysis` wird mit `HistoryHours=24` und deaktiviertem
Mailpfad aufgerufen und muss den eigenen Job im jobs-Array eindeutig liefern.
Die Outcomeauswahl folgt instance_id, auch gegenüber einer früher injizierten
Zeile mit neuerem Kalenderdatum. Die drei Datum-/Dauerpaare betreffen
Joboutcomes; das Steps-Array bleibt ohne Stepdefinition leer. Monitoring
liefert die codierte Rohdauer sowie JOB_STATE_INFORMATIONAL/INFO für den
deaktivierten Job. AVAILABLE_WITH_FINDING ist wegen vorhandener Findings
zulässig; Partialität oder Fehler sind nicht zulässig. Die Msdb-Agentzeitgrenzen
bleiben weiterhin NULL und werden nicht aus den Integerdatumswerten abgeleitet.

Alle zwölf NONE-/JSON-Consumeraufrufe prüfen vollständige Werte von sysjobs,
sysjobsteps, sysjobhistory, sysjobactivity, sysjobservers und sysjobschedules,
eine committable eigene Transaktion, ursprünglichen Locktimeout und
XACT_ABORT ON. Erfolg und Catch rollen die eigene Transaktion zurück und
restaurieren ursprüngliches XACT_ABORT direkt im Callerbatch. Der Erfolg
bestätigt den entfernten eigenen Job und leere Historie. Die bestehende
vierfeldrige Zusammenfassung bleibt unverändert; drei neue Fälle und zwölf
Aufrufe sind interne Abschlussbedingungen.

Der tatsächlich ausgeführte UTF-8/LF-Fixturestand besitzt SHA-256
`0B4A5FFA0843EEDA1DD4001064EF99D3A9ECC734F129E40182E200511304B415`.
Der erste neue Fixturelauf am Basisstand
`bbf407dd2598dc167bb8b8958f6f47f0e747090f` scheiterte mit SQL-Fehlern 2714/1750
am festen lokalen Temp-Constraintnamen PK_JobNameFilter in USP_AgentJobs.
Installation, Smoke und Runtimevertrag 122 bestanden davor; das eigene Lab
wurde mit zwei Cleanupschritten ohne Fehler entfernt. Dieser fehlgeschlagene
Lauf besitzt keinen erfolgreichen Ergebnisdatensatz und bleibt getrennt erhalten.

Eine anschließende private native Gegenprobe in einem weiteren neuen eigenen
Lab bestätigt zwei erfolgreiche Aufrufe ohne Callertransaktion. Innerhalb
derselben offenen Callertransaktion gelingt der erste Aufruf und hinterlässt
einen benannten Primärschlüssel; der zweite liefert 1750 bei XACT_STATE -1.
Das Rollback stellt TX0, leere History und null verbliebene benannte Schlüssel her.
Die anonyme Kandidatenvariante besteht jeweils zwei Aufrufe mit und ohne
Callertransaktion. Das eigene Gegenprobenlab wurde mit zwei Cleanupschritten
und null Fehlern entfernt. Parallele Sessions wurden nicht charakterisiert.

Die einzeilige Produktkorrektur entfernt ausschließlich den festen
Constraintnamen. Primärschlüssel, JobName-Spalte, Kollation, Signatur und
Ergebnisvertrag bleiben erhalten. Der korrigierte UTF-8/LF-Produktstand besitzt
SHA-256 `482E9B743476D6D33F39346ACBE375D9B08664790FF1E0F3BE8FFB60143BADBD`.
Der gekoppelte OPS-005-Installer wurde kanonisch neu erzeugt; sein Updateweg
bleibt normalisiert unverändert. Der öffentliche AgentHistory-Runner bleibt
unverändert. Eine private Ableitung ersetzt ausschließlich den Helperlocator
und ergänzt sechs weitere kanonisch ausgewählte Impacttests; Smoke110 wird
bereits im normalen Ablauf ausgeführt und nicht erneut gestartet.

Der korrigierte native Lauf bestätigt
SQL Server 2025 `17.0.4075.5`, Linux/Docker und Framework-CL170. Coreinstallation
mit 187 Batches, Smoke-Test 110, Runtimevertrag 122, die erweiterte Fixture und
alle sieben impact-basierten SQL-Dateien bestehen: Common124/144/167,
Infrastructure110 und Integration110/196/198. Common167 erhält keine neue
positive Unicode-Fixture; die zusätzliche Datumsgegenprobe stammt aus
AgentHistory. Ein neuer empirischer Catch-Nachweis wird nicht behauptet.
Das eigene Lab wurde entfernt; Runtimeidentitäten, Rohlogs und
vollständige Laufzeitausgaben bleiben außerhalb des Repositorys.

Dieser Nachweis prüft ausschließlich die beschriebenen NONE-/JSON-Felder
und injizierten positiven Joboutcomes. Vollständige RAW-/TABLE-/CONSOLE-
Schemaabnahme, Step-Dauern, ungültige Kalenderwerte, Überläufe, UTC- und
Endzeitinterpretation, Zeitfenstergrenzen, tatsächliche Agentdauer,
Berechtigungspfade, ältere native Engines und zusätzliche Compatibility
Levels werden damit nicht belegt. OPS-008 bleibt PARTIAL_PRODUCT_FUNCTION;
öffentliche Produktverträge, Registry, Reifeflags und historische Matrix
bleiben unverändert. Frühere unabhängige Nachweise und private Fehlerläufe
werden durch diesen begrenzten Lauf nicht ersetzt.

## Ergänzende OPS-008-Step-Datums- und Dauerinterpretation vom 8. Oktober 2026

Der folgende Stand erweitert TEST-0001 nach seinen bisherigen zwölf
Consumeraufrufen um zwei eigene TSQL-Stepdefinitionen. Der deaktivierte Job
besitzt keine Serverzuordnung, Schedule oder Aktivität und wird nicht gestartet.
Drei Fälle injizieren je einen Step-1-Outcome mit den bestehenden positiven
Datum-/Dauerliteralen und anschließend einen Step-2-Outcome mit konstanten
Gegenprobenwerten. Beide gespeicherten History-IDs müssen vorhanden sein und
die zweite muss höher sein. Msdb bestätigt Historycounts acht, zehn und zwölf.

| Step | Lokaler Startzeitpunkt | Codierte Dauer | Erwartete Sekunden | Gespeicherte Retries |
|---:|---|---:|---:|---:|
| 1, Fall 1 | 2024-02-29 00:00:00 | 0 | 0 | 0 |
| 1, Fall 2 | 2024-02-29 01:02:03 | 125 | 85 | 1 |
| 1, Fall 3 | 2025-01-02 23:59:59 | 1000000 | 360000 | 2 |
| 2, alle Fälle | 2000-12-31 11:22:33 | 253001 | 91801 | 0 |

AgentJobs liefert je Phase exakt zwei Steps für den eigenen exakt gefilterten
Job. Alle zehn bekannten JSON-Felder werden mit Anzahlprüfung und
bidirektionalem EXCEPT gegen unabhängige Sollwerte verglichen, einschließlich
synthetischer Stepnamen, TSQL-Subsystem, SUCCEEDED, gespeicherter Retryzahl
und synthetischer Meldung. Die jeweils spätere Step-2-Zeile besitzt ein älteres
Kalenderdatum und andere Dauerwerte. Sie darf den Step-1-Outcome nicht ersetzen.
Identische Step-2-Werte unterscheiden keine wechselnden Step-2-Outcomes.

Jobgesamtoutcome bleibt lokal 2025-01-02 23:59:59 mit 360.000 Sekunden,
Status 1 und StepCount 2. Monitoring liefert weiterhin denselben Jobgesamtstart
und die Rohdauer 1000000; Msdb-Agentzeitgrenzen bleiben NULL. Die neun neuen
Aufrufe und der Gesamtlauf mit 21 tatsächlichen NONE-/JSON-Consumeraufrufen
erhalten alle sechs vollständigen Agentquellen, ursprünglichen Locktimeout,
XACT_ABORT ON und eine committable eigene Transaktion. Das eigene Rollback
entfernt beide Stepdefinitionen, Job und Historie; der ursprüngliche Caller-
XACT_ABORT wird direkt restauriert. Die vierfeldrige Zusammenfassung bleibt
unverändert; drei Stepfälle und 21 Calls sind interne Abschlussbedingungen.

Der UTF-8/LF-Fixturestand besitzt SHA-256
`16DB16E166AA18D8715FD79A61B22578EC1FAD02D8FE6CEE155EDB3C22B869C5`.
Der öffentliche unveränderte AgentHistory-Runner bestätigt den neuen Lauf auf
SQL Server 2025 `17.0.4075.5`, Linux/Docker und Framework-CL170. Coreinstallation
mit 187 Batches, Smoke110, Runtimevertrag122 und die erweiterte Fixture bestehen.
Das eigene Lab wurde mit zwei Cleanupschritten ohne Fehler entfernt; sein
Stateverzeichnis ist nicht mehr vorhanden. Ein vorheriger Startversuch wurde
bei belegter gemeinsamer Testlane vor jeder Provisionierung zurückgestellt.
Runtimeidentitäten und Rohlogs bleiben außerhalb des Repositorys.

Produkt-SQL und gekoppelter Installer bleiben unverändert. Die sieben bereits
für den vorherigen Produktfix bestandenen Impacttests wurden nicht erneut
ausgeführt. Dieser Lauf bestätigt JSON-Feldwerte und injizierte Historie;
tatsächliche Stepausführung, Retryverhalten, wechselnde Step-2-Outcomes,
ungültige Daten, Überläufe, UTC-/Endzeit- und Zeitfensterinterpretation,
vollständige native Ausgabeschemaabnahme und ein neuer empirischer Catch-
Nachweis bleiben unbelegt. OPS-008 bleibt PARTIAL_PRODUCT_FUNCTION; bestehende
Reifeflags, Registry und historische Release-Matrix bleiben erhalten.

## Statischer OPS-008-Bereichsnachweis der Agentdauer vom 8. Oktober 2026

Dieser ergänzende Nachweis gehört zu PROJECT_SEMANTIC und ist keine neue
SQL-Server-Laufzeitevidenz. Am integrierten Stand von PR #295 enthält
`Code/07_Infrastructure/020_USP_AgentJobs.sql` die folgende Formel zweimal,
jeweils für `LastRunDurationSeconds int` der Job- und Stepmenge:

```text
(n / 10000) * 3600 + ((n % 10000) / 100) * 60 + (n % 100)
```

Voraussetzung ist der deklarierte `int`-Datentyp von
`msdb.dbo.sysjobhistory.run_duration`. Die Primärquellen im Zeitmodell der
AgentJobs-Referenz belegen Datentyp, Integerbereich, Abschneiden des
Divisionsbruchteils und Modulo als Divisionsrest; sie wurden am 8. Oktober
2026 geprüft. Die folgende Rechnung ist eine eigene statische Ableitung.
Sie gilt für alle Werte von -2.147.483.648 bis 2.147.483.647 und setzt keine
fachlich gültige HHmmss-Codierung voraus. Beträge werden mathematisch
betrachtet; SQL `ABS` auf dem kleinsten `int` ist kein Berechnungsschritt.

| Teilausdruck | Konservative obere Betragsschranke |
|---|---:|
| `n / 10000` | 214748 |
| `(n / 10000) * 3600` | 773092800 |
| `n % 10000` | 9999 |
| `(n % 10000) / 100` | 99 |
| `((n % 10000) / 100) * 60` | 5940 |
| `n % 100` | 99 |
| Erste Addition | 773098740 |
| Gesamtsumme | 773098839 |

Die Schranken folgen aus dem größten Eingabebetrag 2.147.483.648,
ganzzahliger Division und Restbeträgen kleiner als den positiven Divisoren.
Die Dreiecksungleichung begrenzt die Additionen. Alle Produkte, Quotienten,
Reste und Summen liegen innerhalb von `int`; Divisoren sind positiv und
ungleich null. Daher kann diese Dauerformel innerhalb der deklarierten
Quelle keinen Integerüberlauf erzeugen. NULL liefert in dieser Formel NULL.
Die Summenschranke ist konservativ und kein exakt erreichbares Maximum;
die einzelnen Teilschranken müssen nicht gleichzeitig erreichbar sein.

Eine lokale Python-Rechnung mit beliebig großen Ganzzahlen bestätigt alle
acht Schranken, ihre Lage innerhalb beider `int`-Grenzen, genau zwei
unveränderte Quellformeln und beide Zieldeklarationen. Der Quellstand wurde
gegen die zuvor geprüfte AgentJobs-Quelle gebunden. Es wurden keine native
SQL-Endpunktprobe und kein neuer Containerlauf ausgeführt.

Der Ausschluss betrifft nur Integerüberlauf dieser beiden Formeln. Negative
Dauern, Minuten- oder Sekundenkomponenten außerhalb 0 bis 59, tatsächliche
Agentdauer, `agent_datetime`, laufzeitbezogenes DATEDIFF, Zählerkonvertierungen,
Zeitfenster sowie UTC-/Endzeitinterpretation werden nicht validiert. Die
vorherigen Aussagen über ungeprüfte Überläufe beschreiben den jeweiligen
nativen Slice; sie werden durch diese getrennte statische Rechnung präzisiert.
Produkt, Installer, Fixture, Reifeflags, Registry, OpenScope und historische
Laufzeitmatrix bleiben unverändert; OPS-008 bleibt PARTIAL_PRODUCT_FUNCTION.

## Native OPS-008-Kalendergegenprobe vom 8. Oktober 2026

Eine getrennte private PROJECT_SEMANTIC-Gegenprobe am integrierten Stand
von PR #296 besteht auf SQL Server 2025 `17.0.4075.5`, Linux/Docker und
Framework-CL170. Produkt-SQL, Installer, öffentliche AgentHistory-Fixture
und Runner bleiben unverändert. Coreinstallation mit 187 Batches,
Smoke110 und Runtimevertrag122 bestehen vor der Gegenprobe.

Zunächst bestätigt ein leerer Monitoringaufruf mit Jobstatus an und
Database Mail aus AVAILABLE_WITH_FINDING, Partial false sowie NULL für
Fehlernummer und Fehlermeldung. Vollständige Quellwerte bleiben erhalten.
Danach werden vier getrennte Callertransaktionen mit XACT_ABORT OFF und
Locktimeout 31 verwendet. Jede erzeugt einen eigenen deaktivierten Job
und eine harmlose TSQL-Stepdefinition ohne Ausführung, Serverzuordnung
oder Schedule. Job-ID-Eingang wird vor jedem sp_add_job auf NULL gesetzt.

| Fall | Ungültiges Datum | Betroffene Historyzeile | Direkter nativer Fehler |
|---:|---:|---|---:|
| 1 | 20230229 | Joboutcome, Step-ID 0 | 242 |
| 2 | 20230229 | Stepoutcome, Step-ID 1 | 242 |
| 3 | 20240230 | Joboutcome, Step-ID 0 | 242 |
| 4 | 20240230 | Stepoutcome, Step-ID 1 | 242 |

Das direkte Orakel ruft agent_datetime mit dem jeweiligen Datum und
Uhrzeit 0 auf. Die tatsächliche Fehlernummer wird gemessen; 242 ist kein
vorab festgesetzter Sollfehler. Nach jedem Orakel bleiben TX1 und
XACT_STATE 1 erhalten. Je Fall folgen drei tatsächliche NONE-/JSON-Aufrufe
mit unbeschränkter Zeilenausgabe und ohne Meldungsdruck:

- MsdbHealth meldet AVAILABLE ohne Partial, Historycount eins bei
  ungültigem Job beziehungsweise zwei bei ungültigem Step, NULL für beide
  Agentzeitgrenzen und einen nicht leeren EvidenceLimit.
- AgentJobs verwendet eine exakte eigene Jobliste und meldet in allen
  vier Fällen ERROR_HANDLED, Partial true, den direkt gemessenen Fehler
  242 und eine nicht leere Fehlermeldung. Job- und Steparray sind bei
  ungültigem Joboutcome leer. Bei ungültigem Stepoutcome bleibt genau der
  gültige Joboutcome erhalten: lokal 2024-02-29 00:00:00, 85 Sekunden und
  StepCount eins; das Steparray bleibt leer.
- Monitoring verwendet Jobstatus an und Database Mail aus. Bei ungültigem
  Joboutcome meldet es AVAILABLE_LIMITED, Partial true, Fehler 242, eine
  nicht leere Fehlermeldung und ein leeres Jobarray. Bei ungültigem
  Stepoutcome bleibt genau der gültige eigene deaktivierte Job mit lokalem
  Start 2024-02-29 00:00:00, Rohdauer 125, Runstatus 1 und
  JOB_STATE_INFORMATIONAL/INFO erhalten. Der gemessene Modulstatus lautet
  AVAILABLE_WITH_FINDING, Partial false und Fehlernummer/-meldung NULL.

Alle zwölf Consumeraufrufe und vier direkte Orakel erhalten vollständige,
deterministisch geordnete JSON-Werte von sysjobs, sysjobsteps, sysjobhistory,
sysjobactivity, sysjobservers und sysjobschedules. Counts sowie
XACT_ABORT OFF, Locktimeout 31 und committable TX1 bleiben erhalten.
Vier eigene Rollbacks stellen jeweils sämtliche ursprünglichen sechs
Quellbestände wieder her. Die abschließende skalare Zustandsmessung vor
datenlesender Ausgabe bestätigt TX0, XACT_STATE 0, ursprüngliches OFF
und Locktimeout -1. Die zwölf erfassten Consumerzeilen werden vollständig
aus den begrenzten FOR-JSON-Chunks gelesen, ohne Kürzung.

Der private SQL-Stand besitzt SHA-256
`A74EA2016DD6B093C43135EF26AE60042BD08B6BA60B6E0214AAF4960E13CCB7`.
Der erfolgreiche Lauf bestätigt vier Kalenderfälle, vier native Fehler,
zwölf Fallconsumer, einen Baselineconsumer und vier Rollbacks. Das eigene
Lab ist mit zwei Cleanupschritten ohne Fehler entfernt; sein State ist
nicht mehr vorhanden. Rohlogs und Runtimeidentitäten bleiben privat.

Drei vorausgehende Läufe bleiben Fehlversuche. Der erste scheitert vor
den Fachaufrufen an der ungeklammerten RowCount-Spalte im privaten SQL.
Der zweite scheitert an der noch nicht aufgeteilten Baseline-Invariante;
seine Ursache ist nicht einzeln gemessen. Der dritte passiert die Baseline
und scheitert später mit der nativen MSX-Jobänderungsablehnung. Der nicht
zurückgesetzte OUTPUT-Job-ID-Eingang ist korrigiert; der konkrete native
MSX-Zweig ist nicht separat bewiesen. Alle drei eigenen Labs werden mit
zwei Cleanupschritten ohne Fehler entfernt. Keiner dieser Fehlversuche
erzeugt eine PASS-Ergebnisdatei oder wird als bestanden nachgetragen.

Diese Probe nimmt ausschließlich die beiden benannten ungültigen Daten
bei Uhrzeit 0 in NONE/JSON und XACT_ABORT OFF ab. Weitere ungültige Daten,
Uhrzeiten, NULL-/Null-Datum, XACT_ABORT ON, tatsächliche Step-/Retryausführung,
allgemeine Mengen-/Arithmetikgrenzen und UTC-/Endzeitinterpretation bleiben
offen. Ein vollständiger nativer Ausgabeschema- oder allgemeiner Catch-
Nachweis wird nicht beansprucht. OPS-008 bleibt PARTIAL_PRODUCT_FUNCTION;
Reifeflags, Registry, OpenScope und historische Laufzeitmatrix bleiben
erhalten. Der spätere SMTP-Auftrag ist noch keine gelieferte Funktion.

## Native OPS-008-Uhrzeitgegenprobe vom 8. Oktober 2026

Eine getrennte private RUNTIME_EMPIRICAL-Gegenprobe am integrierten Stand
von PR #297 besteht auf SQL Server 2025 `17.0.4075.5`, Linux/Docker und
Framework-CL170. Produkt, Installer und öffentliche Fixture bleiben erhalten.
Coreinstallation mit 187 Batches, Smoke110 und Runtimevertrag122 bestehen.
Die Monitoring-Baseline mit Jobstatus an und Database Mail aus meldet
AVAILABLE_WITH_FINDING ohne Partial und ohne Fehlernummer/-meldung.

Vier getrennte Callertransaktionen injizieren ausschließlich folgende
Uhrzeitwerte bei gültigem Datum 20240229. Jeder eigene Job bleibt deaktiviert;
die harmlose TSQL-Stepdefinition wird nicht ausgeführt. Serverzuordnung und
Schedule werden nicht angelegt. Der Job-ID-Eingang wird vor jedem Aufbau
auf NULL gesetzt.

| Fall | run_time | Betroffene Historyzeile | Direkter nativer Fehler |
|---:|---:|---|---:|
| 1 | 236060 | Joboutcome, Step-ID 0 | 242 |
| 2 | 236060 | Stepoutcome, Step-ID 1 | 242 |
| 3 | 240000 | Joboutcome, Step-ID 0 | 242 |
| 4 | 240000 | Stepoutcome, Step-ID 1 | 242 |

Das unabhängige Orakel ruft agent_datetime mit Datum und Uhrzeit des
jeweiligen Falls auf und misst die Fehlernummer. Je Fall folgen drei
NONE-/JSON-Consumeraufrufe. MsdbHealth meldet AVAILABLE ohne Partial,
Historycount eins beziehungsweise zwei, NULL-Agentzeitgrenzen und eine
nicht leere Evidenzgrenze. AgentJobs meldet ERROR_HANDLED mit Partial,
Fehler 242 und nicht leerer Meldung; bei ungültigem Job sind beide Arrays
leer. Bei ungültigem Step bleibt der gültige Joboutcome mit lokalem Start
2024-02-29 00:00:00, 85 Sekunden und StepCount eins erhalten, das Steparray
ist leer. Monitoring meldet bei ungültigem Job AVAILABLE_LIMITED mit
Partial, Fehler 242, Meldung und leerem Jobarray. Bei ungültigem Step
bleibt der gültige deaktivierte Job mit demselben Start, Rohdauer 125,
Runstatus 1 und JOB_STATE_INFORMATIONAL/INFO erhalten; Modulstatus ist
AVAILABLE_WITH_FINDING ohne Partial und ohne Fehlernummer/-meldung.

Vier direkte Orakel und zwölf Fallconsumer erhalten sämtliche geordneten
Werte der sechs im Kalendernachweis benannten Agentquellen, XACT_ABORT OFF,
Locktimeout 31 und committable TX1. Vier Rollbacks stellen die Originalquellen
und TX0/XACT_STATE 0 wieder her; Locktimeout bleibt dabei 31. Erst die finale
Wiederherstellung bestätigt ursprüngliches OFF und Locktimeout -1.
Der bounded Reader erfasst alle zwölf Beobachtungszeilen ohne FOR-JSON-Kürzung.
Die Ergebnisdatei wird nach eigenem Cleanup exklusiv neu angelegt und kann
keine vorhandene Datei überschreiben. Das eigene Lab ist mit zwei Schritten
ohne Fehler entfernt; sein State ist nicht mehr vorhanden. Rohlog und
Runtimeidentitäten bleiben privat.

Der ausgeführte private SQL-Stand besitzt SHA-256
`220BC17116759A525D23B4A5ADAA6B650048CB2D165B6265F312386D3BFCFB76`.
Der Lauf besteht mit vier Fällen, vier nativen Fehlern, zwölf Fallconsumern,
einem Baselineconsumer und vier Rollbacks. Der vorherige private Preflight
korrigiert ausschließlich den Ergebnis-Überschreibschutz vor der Ausführung;
es gibt für diesen Uhrzeitumfang keinen vorausgehenden nativen Fehlversuch.

236060 verändert Minuten und Sekunden gemeinsam und belegt keine isolierte
Teilfeldgrenze. Andere Uhrzeiten, NULL-/Null-Datum, XACT_ABORT ON, tatsächliche
Step-/Retryausführung, UTC-/Endzeitinterpretation und vollständige native
Ausgabeschemata bleiben ungeprüft. Statusflags, Registry, OpenScope und
historische Laufzeitmatrix bleiben erhalten; OPS-008 bleibt partiell.

## Tatsächliche OPS-008-Retrygegenprobe vom 8. Oktober 2026

Eine getrennte private RUNTIME_EMPIRICAL-Gegenprobe am integrierten Stand
von PR #298 besteht auf SQL Server 2025 `17.0.4075.5`, Linux/Docker und
Framework-CL170. Coreinstallation mit 187 Batches, Smoke110 und Runtime122
bestehen. Produkt, Installer und öffentliche Fixture werden nicht geändert.

Die Probe legt genau einen eigenen lokalen Job mit einem TSQL-Step ohne
Schedule und ohne Benachrichtigungen an. Der Step besitzt retry_attempts 1
und retry_interval 0. Sein erster Lauf liest ausschließlich die eigene native
Historie und löst ohne vorhandene Retryzeile den synthetischen Fehler 56151 aus.
Der Agent erzeugt die Retryzeile. Beim zweiten Lauf erkennt der Step diese
eigene native Zeile und endet erfolgreich. Es wird keine Historie injiziert;
der Step erzeugt keine Datenobjekte und versendet keine Nachrichten.
Nach gebundenem Activityabschluss wird der Job deaktiviert. Der Wrapper
begrenzt den privaten FOR-JSON-Reader auf 64 Chunks und 65.536 Zeichen.

Die unabhängigen Orakel bestätigen drei globale und eigene Historyzeilen
in steigender instance_id-Reihenfolge und den eigenen Job ohne Benachrichtigungen:

| Reihenfolge | step_id | run_status | sql_message_id | retries_attempted |
|---:|---:|---:|---:|---:|
| 1 | 1 | 2 | 56151 | 0 |
| 2 | 1 | 1 | 0 | 0 |
| 3 | 0 | 1 | 0 | 0 |

Die Statusfolge belegt den tatsächlichen Retry nach Erstfehler und den
anschließenden Step- und Joberfolg. retries_attempted ist in diesem Lauf
kein aus der Erfolgszeile ablesbarer Zähler der beiden Stepversuche.
Es wird weder eine allgemeine Zählersemantik noch eine Ursache des Werts 0
für andere Plattformen oder Retryintervalle abgeleitet.

Vier NONE-/JSON-Aufrufe bestätigen die folgenden begrenzten Fachwerte:

| Consumer | Modulstatus | Geprüfter fachlicher Zustand |
|---|---|---|
| MsdbHealth | AVAILABLE | AGENT_HISTORYcount drei, NULL-Zeitgrenzen und nicht leere EvidenceLimit. |
| AgentJobs mit NurProblematisch 0 | AVAILABLE | Ein deaktivierter eigener Job mit Runstatus 1 und StepCount eins; ein letzter erfolgreicher TSQL-Step mit LastRunRetries 0. |
| AgentJobs mit NurProblematisch 1 | AVAILABLE | Derselbe deaktivierte Job bleibt enthalten; das Steparray ist leer und übernimmt nicht den älteren Retryoutcome. |
| Monitoring mit Jobstatus an und Mail aus | AVAILABLE_WITH_FINDING | Ein eigener deaktivierter Job mit LatestRunStatus 1 und JOB_STATE_INFORMATIONAL/INFO. |

Alle vier Aufrufe melden keinen Partial- oder Fehlerstatus. Die Probe vergleicht
sämtliche geordneten Werte von sysjobs, sysjobsteps, sysjobhistory,
sysjobactivity, sysjobservers und sysjobschedules vor und nach jedem Consumer.
Die vorherige Stabilitätsgegenprobe erhält dieselben sechs Quellen nach
zwei Sekunden. Während der Consumer bleiben TX1/XACT_STATE 1, XACT_ABORT ON
und Locktimeout 31 erhalten. Ein Rollback erhält die tatsächliche History.
Die gebundene Entfernung des eigenen Jobs stellt sämtliche ursprünglichen
Werte der sechs Quellen wieder her. Abschließend sind ursprüngliches OFF,
Locktimeout -1, TX0 und separat vor der abschließenden Ergebnisabfrage
erfasstes XACT_STATE 0 bestätigt.
Die PASS-Ergebnisdatei wird exklusiv erst nach eigenem äußeren Cleanup erzeugt.
Das eigene Lab ist mit zwei Schritten ohne Fehler entfernt; State ist abwesend.

Zwei vorherige private Läufe scheitern mit Orakelfehler 56147 vor dem ersten
Consumer; sie erzeugen keine PASS-Ergebnisdatei. Der erste prüft unter anderem
retries_attempted 1 in der Erfolgszeile; seine einzelne verletzte Teilbedingung
wird nicht gesondert gemessen. Die zweite Diagnose misst die native
Statusfolge, drei Historyzeilen, deaktivierte Benachrichtigungen und tatsächlich
retries_attempted 0. Ausschließlich diese private Erfolgsrow-Erwartung und der
entsprechende AgentJobs-Wert werden vor dem Final auf 0 korrigiert.
Konfigurierter Retry, Quell- und Callerorakel sowie Lifecycle bleiben erhalten.
Beide eigenen fehlgeschlagenen Labs sind ebenfalls mit zwei Schritten ohne
Fehler entfernt; ihre Stateverzeichnisse sind abwesend. Alle Rohlogs und
konkreten Runtimeidentitäten bleiben privat. Daraus folgt kein Produktfehler.

Der bestandene private SQL-Stand besitzt SHA-256
`2854720B7AF8DC69AFAAC91EDD787F2B26CB85D0D508A61FC2A21C3E28F647EE`.
Er bestätigt einen eigenen ausgeführten Job, einen Step mit zwei beobachteten
Versuchen, einen konfigurierten Retry, drei native Historyzeilen, vier Consumer
und einen Rollback. Retryerschöpfung, positive Warteintervalle, Parallelität,
laufende Retryphase, tatsächliche Dauergrenzen, andere Engines und vollständige
Ausgabeschemata bleiben unbelegt. Der innere Catchcleanup erhält keine eigene
Fehlergegenprobe. Statusflags, Registry, OpenScope und historische Laufzeitmatrix
bleiben erhalten; OPS-008 bleibt partiell.

## Tatsächliche OPS-008-Retryerschöpfung vom 8. Oktober 2026

Eine getrennte private RUNTIME_EMPIRICAL-Gegenprobe am integrierten Stand
von PR #299 besteht auf SQL Server 2025 `17.0.4075.5`, Linux/Docker und
Framework-CL170. Coreinstallation mit 187 Batches, Smoke110 und Runtime122
bestehen. Produkt, Installer und öffentliche Fixture werden nicht geändert.

Die Probe legt einen eigenen aktivierten lokalen Job mit einem TSQL-Step,
retry_attempts 1 und retry_interval 0 an. Schedule und Benachrichtigungen
bleiben ausgeschlossen. Der Step wirft in beiden tatsächlichen Versuchen
ausschließlich den synthetischen Fehler 56161. Es gibt keine Historyinjektion,
Datenobjekte oder Nachrichten. Die gebundene native Activity bestätigt den
Jobabschluss; danach bleibt der Job für die Diagnose aktiviert.

Die unabhängigen Orakel bestätigen genau drei globale und eigene Historyzeilen
in steigender instance_id-Reihenfolge sowie den eigenen Job ohne Benachrichtigungen:

| Reihenfolge | step_id | run_status | sql_message_id | retries_attempted |
|---:|---:|---:|---:|---:|
| 1 | 1 | 2 | 56161 | 0 |
| 2 | 1 | 0 | 56161 | 1 |
| 3 | 0 | 0 | 0 | 0 |

Die letzte Step-Failurezeile liefert den gespeicherten Retrywert unabhängig
vom Consumer. Im beobachteten Lauf beträgt er 1. Der vorherige Erfolgsumfang
speicherte dagegen 0 in seiner letzten Stepzeile. Beide Beobachtungen werden
getrennt erhalten; eine allgemeine plattformübergreifende Zählersemantik oder
eine Ursache für den Unterschied wird nicht behauptet.

Vier NONE-/JSON-Aufrufe bestätigen die folgenden begrenzten Fachwerte:

| Consumer | Modulstatus | Geprüfter fachlicher Zustand |
|---|---|---|
| MsdbHealth | AVAILABLE | AGENT_HISTORYcount drei, NULL-Zeitgrenzen und nicht leere EvidenceLimit. |
| AgentJobs mit NurProblematisch 0 | AVAILABLE | Ein aktivierter eigener Job mit LastRunStatus 0 und StepCount eins; ein letzter failed TSQL-Step mit LastRunRetries 1. |
| AgentJobs mit NurProblematisch 1 | AVAILABLE | Derselbe Job und derselbe letzte failed Step bleiben enthalten. |
| Monitoring mit Jobstatus an und Mail aus | AVAILABLE_WITH_FINDING | Ein eigener aktivierter Job mit LatestRunStatus 0 und LATEST_JOB_RUN_FAILED_IN_WINDOW/HIGH. |

Alle vier Aufrufe melden keinen Partial- oder Consumerfehlerstatus. Der
erwartete native Jobfehler ist ein fachlicher Befund. Vor und nach jedem
Consumer bleiben sämtliche geordneten Werte von sysjobs, sysjobsteps,
sysjobhistory, sysjobactivity, sysjobservers und sysjobschedules erhalten.
Die vorgeschaltete Stabilitätsgegenprobe erhält dieselben sechs Quellen
nach zwei Sekunden. Die Consumer erhalten TX1/XACT_STATE 1, XACT_ABORT ON
und Locktimeout 31. Ein Rollback erhält die tatsächliche History; die gebundene
Entfernung des eigenen Jobs stellt sämtliche ursprünglichen Werte der sechs
Quellen wieder her. Finale Optionsrestauration bestätigt ursprüngliches OFF,
Locktimeout -1 und TX0. XACT_STATE 0 wird separat vor der abschließenden
Ergebnisabfrage erfasst. Die PASS-Ergebnisdatei wird exklusiv erst nach eigenem
äußeren Cleanup erzeugt. Das eigene Lab ist mit zwei Schritten ohne Fehler
entfernt; sein State ist abwesend. Alle Rohlogs und Runtimeidentitäten bleiben privat.

Der bestandene private SQL-Stand besitzt SHA-256
`2F1A05C9DCCE0042CF6A099F26849E4311760758B508685C5BD7ABC7947551A2`.
Er bestätigt einen eigenen ausgeführten Job, einen Step mit zwei beobachteten
Versuchen, einen ausgeschöpften konfigurierten Retry, drei native Historyzeilen,
vier Consumer und einen Rollback. Dieser Erschöpfungsumfang besitzt keinen
vorausgehenden nativen Fehlversuch. Positive Warteintervalle, Parallelität,
laufende Retryphase, tatsächliche Dauergrenzen, andere Engines und vollständige
Ausgabeschemata bleiben unbelegt. Der innere Catchcleanup erhält keine eigene
Fehlergegenprobe. Statusflags, Registry, OpenScope und historische Laufzeitmatrix
bleiben erhalten; OPS-008 bleibt partiell.

## Automatische OPS-008-Agentretention vom 8. Oktober 2026

Eine getrennte private RUNTIME_EMPIRICAL-Probe am integrierten Stand von
PR #300 besteht auf SQL Server 2025 `17.0.4075.5`, Linux/Docker und
Framework-CL170. Coreinstallation mit 187 Batches, Smoke110 und Runtime122
bestehen. Produktcode, Installer, öffentliche Fixture und Labquellen bleiben
unverändert. Die Probe verwendet ausschließlich ein neues eigenes Lab.

Der vorhandene custody- und rungebundene Lab-Transport setzt innerhalb
dieses Containers sqlagent.jobhistorymaxrows auf 64 und
sqlagent.jobhistorymaxrowsperjob auf 4. Beide Set-Aufrufe liefern Exit 0.
Der Datei-Readback parst die Konfiguration im eigenen Container und projiziert
ausschließlich Dateilesestatus, Abschnitt-/Keypräsenz und den kontrollierten
Wert. Beide Werte werden exakt bestätigt; ein öffentlicher Lab-Restart
meldet RUNNING ohne Readinessfehler. Es gibt keine neue allgemeine Labfunktion,
Hostkonfiguration oder Imagebeschaffung.

Ein eigener aktivierter lokaler Job enthält einen TSQL-Step mit SELECT 1,
keinen Schedule, keinen Retry und keine Benachrichtigung. Drei begrenzte
sp_start_job-Aufrufe erzeugen erfolgreiche native Step- und Gesamtoutcomes.
Je Lauf bindet die jüngste Agent-Session die abgeschlossene Activity an den
neuen Gesamtoutcome. Weder Historyinjektion noch manueller Purge werden verwendet.

| Abgeschlossener Lauf | Retained Historyzeilen | Gesamtoutcomes | Stepoutcomes |
|---:|---:|---:|---:|
| 1 | 2 | 1 | 1 |
| 2 | 4 | 2 | 2 |
| 3 | 4 | 2 | 2 |

Alle erfassten Outcomes sind erfolgreich. Jeder Lauf erzeugt zwei neue Zeilen;
nach dem dritten fehlen beide Zeilen des ersten instance_id-Paars. Sämtliche
gespeicherten Werte des zweiten Paars bleiben gegenüber ihrer Aufnahme nach
Lauf zwei identisch. Die globale Grenze 64 wird nicht erreicht und ihr
Grenzverhalten ist deshalb nicht belegt. Die beobachtete automatische Grenze
betrifft ausschließlich vier Zeilen dieses einen Jobs.

Vier NONE-/JSON-Consumer je Phase bestätigen folgende begrenzte Fachwerte:

| Consumer | Modulstatus | Geprüfter fachlicher Zustand |
|---|---|---|
| MsdbHealth | AVAILABLE | AGENT_HISTORYcount zwei beziehungsweise vier, NULL-Zeitgrenzen und nicht leere EvidenceLimit. |
| AgentJobs mit NurProblematisch 0 | AVAILABLE | Ein aktivierter eigener Job mit LastRunStatus 1 und StepCount eins; ein letzter erfolgreicher TSQL-Step mit LastRunRetries 0. |
| AgentJobs mit NurProblematisch 1 | AVAILABLE | Der schedulefreie Job bleibt enthalten; das Steparray bleibt leer. |
| Monitoring mit Jobstatus an und Mail aus | AVAILABLE_WITH_FINDING | Ein aktivierter eigener Job mit LatestRunStatus 1 und ENABLED_JOB_WITHOUT_SCHEDULE/INFO. |

Alle zwölf Aufrufe bleiben ohne Partial oder Consumerfehler. Jede Phase
vergleicht vor und nach allen vier Consumern sämtliche geordneten Werte von
sysjobs, sysjobsteps, sysjobhistory, sysjobactivity, sysjobservers und
sysjobschedules. Eine vorgeschaltete Stabilitätsgegenprobe erhält dieselben
Quellen nach zwei Sekunden. Die Consumer erhalten TX1/XACT_STATE 1,
XACT_ABORT ON und Locktimeout 31. Drei Rollbacks erhalten jeweils die
tatsächlichen Quellen; danach stellt der gebundene eigene Jobdelete die
ursprünglichen sechs Quellbestände wieder her. Finale Optionsrestauration
bestätigt ursprüngliches OFF, Locktimeout -1 und TX0. XACT_STATE 0 wird nach
dem abschließenden Quellvergleich separat vor der Ergebnisabfrage erfasst.
Die PASS-Datei entsteht exklusiv erst nach öffentlichem eigenem Labcleanup
mit zwei Schritten ohne Fehler und bestätigter Abwesenheit seines State.
Die containerlokale Testkonfiguration wird mit dem eigenen Lab entfernt.

Zwei frühere private Läufe scheitern am Konfigurationsreadbackguard vor
Restart, Coreinstallation, Smoke, Runtime122 und fachlicher SQL-Probe.
Der erste speichert keine ursprüngliche get-Rückgabe. Nur der zweite misst
Exit 0 mit einer Nichtgefundenmeldung für den globalen Schlüssel. Daraus
folgt keine gemessene gemeinsame Ursache beider Fehler und kein Produktfehler.
Im dritten neuen Lab bestätigt der direkte Datei-Readback beide gesetzten
Werte, bevor der unveränderte fachliche SQL-Stand läuft. Beide vorherigen
Labs werden ebenfalls mit zwei Schritten ohne Fehler entfernt; ihre
Stateverzeichnisse und Ergebnisdateien sind abwesend. Alle Rohlogs und
konkreten Runtimeidentitäten bleiben privat.

Der bestandene private SQL-Stand besitzt SHA-256
`8A49734982E70994F1482C3A671E3A4419B09C475C42BC9A5D2A3703C071A83E`.
Er belegt einen eigenen Job, einen Step, drei tatsächliche erfolgreiche Läufe,
sechs erzeugte und zuletzt vier erhaltene Historyzeilen, zwölf Consumer
und drei Rollbacks. Andere Grenzwerte, globale Überschreitung, Altersretention,
Parallelität, andere Engines und vollständige Ausgabeschemata bleiben ungeprüft.
Der innere Catchcleanup erhält keine eigene Fehlergegenprobe. Statusflags,
Registry, OpenScope und historische Laufzeitmatrix bleiben erhalten;
OPS-008 bleibt partiell.

## Globale OPS-008-Agentretention vom 8. Oktober 2026

Eine getrennte private RUNTIME_EMPIRICAL-Probe am integrierten Stand von
PR #301 besteht auf SQL Server 2025 `17.0.4075.5`, Linux/Docker und
Framework-CL170. Coreinstallation mit 187 Batches, Smoke110 und Runtime122
bestehen. Produktcode, Installer, öffentliche Fixtures und Labquellen bleiben
unverändert. Die Probe verwendet ausschließlich ein neues eigenes Lab.

Der bestehende custody- und rungebundene Lab-Transport setzt im eigenen
Container sqlagent.jobhistorymaxrows auf 6 und jobhistorymaxrowsperjob
im Abschnitt sqlagent auf 4. Beide Set-Aufrufe liefern Exit 0. Der
Datei-Readback bestätigt ausschließlich die beiden kontrollierten Werte,
Dateilesestatus und Abschnitt-/Keypräsenz. Ein öffentlicher Lab-Restart
meldet RUNNING ohne Readinessfehler. Hostkonfiguration, Imagebeschaffung
und neue öffentliche Labfunktionen gehören nicht zu dieser Probe.

Job A wird vor Phase 1 angelegt, Job B vor Phase 2. Beide eigenen
aktivierten lokalen Jobs enthalten jeweils einen TSQL-Step mit SELECT 1,
keinen Schedule, keinen Retry und keine Benachrichtigung. Vier begrenzte
sp_start_job-Aufrufe laufen sequenziell als A, B, A, B. Je Lauf bindet
die jüngste Agent-Session die abgeschlossene Activity an den neuen
erfolgreichen Gesamtoutcome nach instance_id. Je Ausführung werden genau
zwei neue Zeilen mit Step-ID 1 beziehungsweise 0 und Status 1 bestätigt.
Historie wird nicht injiziert; während der Retentionsphasen ruft die Probe
keine manuelle Purgeprozedur auf.

| Phase | Ausgeführter Job | History insgesamt | Job A | Job B |
|---|---|---:|---:|---:|
| 1 | A | 2 | 2 | 0 |
| 2 | B | 4 | 2 | 2 |
| 3 | A | 6 | 4 | 2 |
| 4 | B | 6 | 2 | 4 |

Die acht nativ erzeugten Zeilen würden die globale Grenze sechs
überschreiten. Kein Job erzeugt in diesem Ablauf mehr als vier Zeilen.
Nach Phase 4 ist das zuerst erzeugte A-Paar nicht mehr vorhanden.
Sämtliche geordneten Werte der vier jüngeren Zeilen aus Phase 2 und 3
bleiben identisch. Diese begrenzte Beobachtung trennt den globalen Umfang
vom vorausgehenden Einzeljobnachweis mit globaler Grenze 64; sie beschreibt
keinen allgemeinen Löschalgorithmus für andere Lasten oder Limits.

Je Phase bestehen vier NONE-/JSON-Aufrufe, insgesamt sechzehn:

- MsdbHealth meldet AVAILABLE ohne Partial oder Consumerfehler. Der
  AGENT_HISTORYcount entspricht zwei, vier, sechs beziehungsweise sechs;
  OldestUtc und NewestUtc bleiben NULL, EvidenceLimit bleibt nicht leer.
- AgentJobs im normalen Filter enthält jeden vorhandenen eigenen Job
  und dessen letzten erfolgreichen TSQL-Step mit Retrywert 0.
- AgentJobs im Problemfilter enthält die aktivierten schedulefreien Jobs;
  erfolgreiche Steps werden ausgeschlossen.
- AgentMonitoring meldet AVAILABLE_WITH_FINDING ohne Partial oder
  Consumerfehler. Jeder vorhandene Job erhält LatestRunStatus 1 und
  ENABLED_JOB_WITHOUT_SCHEDULE/INFO.

Sechs Quellen werden jeweils vollständig und geordnet als JSON mit
NULL-Werten verglichen: sysjobs, sysjobsteps, sysjobhistory, sysjobactivity,
sysjobservers und sysjobschedules. Vor den Consumeraufrufen bleibt jede
Phasenbasis über zwei Sekunden stabil. Nach jedem Consumer und nach
jedem der vier Rollbacks bleiben die Phasenquellen identisch.
XACT_ABORT ON, Locktimeout 31 und committable TX1 werden nach jedem
Consumer geprüft. Das Löschen beider eigenen Jobs über ihre gebundenen
IDs stellt die ursprünglichen sechs Quellen wieder her.

Abschließend werden ursprüngliches XACT_ABORT OFF, Locktimeout -1, TX0
und separat erfasster XACT_STATE 0 geprüft. Der äußere Labcleanup
besteht mit zwei Schritten ohne Fehler; der eigene Statepfad ist entfernt.
Erst danach wird das private PASS-JSON exklusiv mit CreateNew geschrieben.
Sieben unveränderte Quellpins werden vor und nach dem SQL-Lauf geprüft.

Der private SQL-Stand besitzt SHA-256
`19D593E6B737C726D9973876F0DA129EE20CFE932362642E1EA0712E9D7238DC`.
Dieser globale Umfang hat keinen vorausgehenden nativen Fehlversuch.
Andere globale oder Joblimits, Altersretention, Parallelität, andere
Engines und vollständige Ausgabeschemata bleiben ungeprüft. Der innere
Catchcleanup erhält keine eigene Fehlergegenprobe. Statusflags, OpenScope,
Registry und historische Laufzeitmatrix bleiben erhalten; OPS-008 bleibt
partiell. Die SMTP-Abhängigkeit gehört weiterhin zu SQL_Server_Lab.

## Positives OPS-008-Agent-Retryintervall vom 8. Oktober 2026

Eine getrennte private RUNTIME_EMPIRICAL-Probe am integrierten Stand von
PR #302 besteht auf SQL Server 2025 `17.0.4075.5`, Linux/Docker und
Framework-CL170. Core187, Smoke110 und Runtime122 bestehen. Die Probe
verwendet ausschließlich ein neues eigenes Lab; Produktcode, öffentliche
Fixtures, Installer und Labquellen bleiben unverändert.

Ein eigener aktivierter lokaler Job enthält einen TSQL-Step mit einem
konfigurierten Retry und retry_interval 1. Der vorhandene native Parameter
bezeichnet Minuten. Die gespeicherte Definition wird geprüft; der Job
besitzt keinen Schedule und keine Benachrichtigung. Der erste Versuch
erzeugt kontrolliert Fehler 56151. Erst bei vorhandener eigener nativer
Retryzeile mit Status 2 kann der nachfolgende Versuch SELECT 1 erfolgreich
ausführen. Historyzeilen werden nicht injiziert.

Die Probe pollt höchstens 180-mal mit Einsekunden-Waits. Bei vorhandener
Retryzeile und fehlendem erfolgreichen Step sowie Gesamtoutcome werden
60 Pollzyklen mit gestarteter, noch nicht abgeschlossener Activity
des eigenen Jobs erfasst. Vom ersten solchen Poll bis zur beobachteten
gebundenen Abschlussactivity werden 60059 Millisekunden gemessen.
Dies erfüllt die privaten Mindestguards von 50 Samples und 50 Sekunden;
es belegt keine exakte Timerpräzision oder allgemeine Schedulinggarantie.
Während dieses laufenden Zustands erfolgen keine Consumeraufrufe.

Der neue erfolgreiche Gesamtoutcome wird an die abgeschlossene Activity
der jüngsten Agent-Session gebunden. Genau drei eigene native Zeilen in
instance_id-Reihenfolge zeigen Step-Retry 2, Steperfolg 1 und Joberfolg 1.
Der gespeicherte letzte Stepwert retries_attempted beträgt 0 und wird
als beobachteter Wert übernommen; die tatsächliche Wiederholung wird durch
die native Statusfolge belegt. Nach Abschluss wird ausschließlich der
eigene Job deaktiviert.

Vier NONE-/JSON-Aufrufe bestehen:

- MsdbHealth meldet AVAILABLE ohne Partial oder Consumerfehler und
  AGENT_HISTORYcount drei mit NULL-Zeitgrenzen und nicht leerer EvidenceLimit.
- AgentJobs im normalen Filter erhält den eigenen deaktivierten
  erfolgreichen Job und den letzten erfolgreichen TSQL-Step. LastRunRetries
  entspricht dem gespeicherten nativen Wert 0.
- AgentJobs im Problemfilter enthält den deaktivierten Job, aber keinen
  Step; die ältere Retryzeile wird ausgeschlossen.
- AgentMonitoring meldet AVAILABLE_WITH_FINDING ohne Partial oder
  Consumerfehler, LatestRunStatus 1 und JOB_STATE_INFORMATIONAL/INFO.

Sechs vollständige geordnete Quellen einschließlich NULL-Werten werden
verglichen: sysjobs, sysjobsteps, sysjobhistory, sysjobactivity,
sysjobservers und sysjobschedules. Die abgeschlossene Consumerbasis bleibt
über zwei Sekunden stabil. Nach jedem Consumer und einem Rollback bleiben
sämtliche Werte identisch; ON, Locktimeout 31 und committable TX1 werden
nach jedem Consumer bestätigt. Eigenes Jobcleanup über die gebundene ID
restauriert die ursprünglichen sechs Quellen. Abschließend werden
ursprüngliches OFF, Locktimeout -1, TX0 und separat erfasster XACT_STATE 0
bestätigt. Der äußere eigene Labcleanup besteht mit zwei Schritten ohne
Fehler; der Statepfad ist entfernt. Erst danach wird das private PASS-JSON
exklusiv mit CreateNew geschrieben. Sieben Sourcepins bleiben erhalten.

Der private SQL-Stand besitzt SHA-256
`B51CB99B890918E20C49D968FB2F3628D67BFA2705584CE6CADAFFE87B51D0E5`.
Der kontrollierte Erstfehler gehört zum erwarteten Jobablauf. Andere
Intervalle, Retryerschöpfung mit positivem Intervall, laufende Consumer,
Parallelität, andere Engines, vollständige Ausgabeschemata und eine innere
Catchcleanup-Gegenprobe bleiben ungeprüft. Statusflags, OpenScope, Registry
und historische Laufzeitmatrix bleiben erhalten; OPS-008 bleibt partiell.

## OPS-008-Retryerschöpfung mit positivem Intervall vom 8. Oktober 2026

Eine getrennte private RUNTIME_EMPIRICAL-Probe am integrierten Stand von
PR #303 besteht auf SQL Server 2025 `17.0.4075.5`, Linux/Docker und
Framework-CL170. Core187, Smoke110 und Runtime122 bestehen. Ausschließlich
ein neues eigenes Lab wird verwendet; Produktcode, öffentliche Fixtures,
Installer und Labquellen bleiben unverändert.

Ein eigener aktivierter lokaler Job enthält einen TSQL-Step mit einem
konfigurierten Retry und retry_interval 1, dessen native Einheit Minuten
ist. Die gespeicherte Definition wird geprüft; Schedule und Benachrichtigung
fehlen. Beide Versuche erzeugen kontrolliert Fehler 56161. Es werden keine
Historyzeilen injiziert.

Die Probe pollt höchstens 180-mal mit Einsekunden-Waits. Bei vorhandener
Retryzeile, fehlendem finalen Stepfailure und fehlendem Gesamtoutcome werden
60 Pollzyklen mit gestarteter, noch nicht abgeschlossener Activity
des eigenen Jobs erfasst. Vom ersten solchen Poll bis zum beobachteten
gebundenen Abschluss werden 60059 Millisekunden gemessen. Dies erfüllt
die privaten Mindestguards von 50 Samples und 50 Sekunden; es belegt keine
exakte Timerpräzision oder allgemeine Schedulinggarantie. Während dieses
laufenden Zustands erfolgen keine Consumeraufrufe.

Der neue failed Gesamtoutcome wird an die abgeschlossene Activity der
jüngsten Agent-Session gebunden. Genau drei eigene native Zeilen in
instance_id-Reihenfolge zeigen Step-Retry 2, Stepfailure 0 und Jobfailure 0.
Die beiden Stepzeilen enthalten Fehler 56161. Der gespeicherte letzte
Stepwert retries_attempted beträgt 1; er wird als beobachteter Wert
übernommen. Die tatsächliche Wiederholung wird durch die native Statusfolge
belegt. Der Job bleibt bis zu seinem eigenen Cleanup aktiviert.

Vier NONE-/JSON-Aufrufe bestehen:

- MsdbHealth meldet AVAILABLE ohne Partial oder Consumerfehler und
  AGENT_HISTORYcount drei mit NULL-Zeitgrenzen und nicht leerer EvidenceLimit.
- AgentJobs im normalen Filter und im Problemfilter erhält jeweils den
  eigenen aktivierten failed Job und den letzten failed TSQL-Step.
  LastRunRetries entspricht dem gespeicherten nativen Wert 1.
- AgentMonitoring meldet AVAILABLE_WITH_FINDING ohne Partial oder
  Consumerfehler, LatestRunStatus 0 und LATEST_JOB_RUN_FAILED_IN_WINDOW/HIGH.

Sechs vollständige geordnete Quellen einschließlich NULL-Werten werden
verglichen: sysjobs, sysjobsteps, sysjobhistory, sysjobactivity,
sysjobservers und sysjobschedules. Die abgeschlossene Consumerbasis bleibt
über zwei Sekunden stabil. Nach jedem Consumer und einem Rollback bleiben
sämtliche Werte identisch; ON, Locktimeout 31 und committable TX1 werden
nach jedem Consumer bestätigt. Eigenes Jobcleanup über die gebundene ID
restauriert die ursprünglichen sechs Quellen. Abschließend werden
ursprüngliches OFF, Locktimeout -1, TX0 und separat erfasster XACT_STATE 0
bestätigt. Der äußere eigene Labcleanup besteht mit zwei Schritten ohne
Fehler; der Statepfad ist entfernt. Erst danach wird das private PASS-JSON
exklusiv mit CreateNew geschrieben. Sieben Sourcepins bleiben erhalten.

Der private SQL-Stand besitzt SHA-256
`90A38909E08CADD33003DE3F765902BA09334177CF2D3E1AB0044F333A4DD7BB`.
Die beiden kontrollierten Fehler gehören zum erwarteten Jobablauf. Weitere
Intervalle, laufende Consumer, Parallelität, andere Engines, vollständige
Ausgabeschemata und eine innere Catchcleanup-Gegenprobe bleiben ungeprüft.
Statusflags, OpenScope, Registry und historische Laufzeitmatrix bleiben
erhalten; OPS-008 bleibt partiell.

## OPS-008-Kalenderfehler mit XACT_ABORT ON vom 8. Oktober 2026

Eine getrennte private RUNTIME_EMPIRICAL-Charakterisierung am integrierten
Stand von PR #304 ist COMPLETED auf SQL Server 2025 `17.0.4075.5`,
Linux/Docker und Framework-CL170. Core187, Smoke110 und Runtime122 bestehen.
Es wird ausschließlich ein neues eigenes Lab verwendet. Produktcode,
öffentliche Fixtures, Installer, API und Labquellen bleiben unverändert.

20230229 und 20240230 werden jeweils als Job- und Stepoutcome injiziert.
Der eigene deaktivierte Job besitzt einen TSQL-Step und wird nie ausgeführt.
Bei ungültigem Step bleibt der injizierte Joboutcome auf 20240229 gültig.
Vier direkte native OFF-Orakel außerhalb sämtlicher Consumertransaktionen
messen Fehler 242. Die getrennte Monitoring-Baseline bei ON31TX0 liefert
AVAILABLE_WITH_FINDING ohne Partial oder Fehler und erhält alle sechs Quellen.
Jeder der zwölf NONE-/JSON-Consumer erhält eine neue eigene ON31TX1-
Transaktion mit vor dem Aufruf separat bestätigtem XACT_STATE 1.

| Consumer | Ungültiger Joboutcome, je zwei Fälle | Ungültiger Stepoutcome, je zwei Fälle |
|---|---|---|
| MsdbHealth | AVAILABLE ohne Partial oder Fehler; Historycount 1; Post-XACT 1 | AVAILABLE ohne Partial oder Fehler; Historycount 2; Post-XACT 1 |
| AgentJobs | ERROR_HANDLED/Partial mit 242; JSON gültig; Jobs 0 und Steps 0; Post-XACT -1 | ERROR_HANDLED/Partial mit 242; JSON gültig; Jobs 1 und Steps 0; Post-XACT -1 |
| AgentMonitoring | Entkommener Fehler 3930 aus Procedure-Enum AGENT_MONITORING; Statusoutputs und JSON fehlen; Post-XACT -1 | AVAILABLE_WITH_FINDING ohne Partial oder Fehler; Jobs 1; Post-XACT 1 |

ErrorMessagePresent ist bei den vier AgentJobs-Fehlern wahr. Die Probe bindet
auch beide öffentlichen Msdb-Erroroutputs; deren NULL-Werte sind beobachtet.
Die Statusoutputs nach entkommenem Monitoringfehler bleiben NULL und werden
nicht als AVAILABLE_LIMITED rekonstruiert. Sechs Callertransaktionen werden
uncommittable. Die vier direkten OFF-Orakel laufen vor den Consumertransaktionen
und können diese daher nicht vorab invalidieren. Das gleiche Verhalten wird
für beide Kalenderwerte beobachtet; andere Datums-/Uhrzeitwerte werden daraus
nicht abgeleitet.

Vor und nach jedem Consumer werden sämtliche Werte der sechs geordneten
Quellen einschließlich NULL-Werten verglichen: sysjobs, sysjobsteps,
sysjobhistory, sysjobactivity, sysjobservers und sysjobschedules. Alle Werte,
Transaktionsanzahl eins, ON und Locktimeout 31 bleiben erhalten. Post-XACT
wird vor jeder Beobachterabfrage separat erfasst. Der Beobachter führt keine
geloggten Writes in einer uncommittable Transaktion aus: Jeder Consumer wird
zurückgerollt, die ursprünglichen sechs Quellen und TX0/XACT_STATE 0 werden
bestätigt, erst danach wird die private Beobachterzeile geschrieben.

Zwölf Rollbacks entfernen sämtliche eigenen Jobs, Steps und injizierten
Historyzeilen. Abschließend werden ursprüngliches OFF, Locktimeout -1,
TX0 und separat erfasster XACT_STATE 0 bestätigt. Sieben Sourcepins bleiben
erhalten. Der äußere eigene Labcleanup besteht mit zwei Schritten ohne
Fehler; der Statepfad ist entfernt. Erst danach wird das COMPLETED-JSON
exklusiv mit CreateNew geschrieben. Der SQL-Stand besitzt SHA-256
`86E3AAED675C22B6F97133E510856435276D2BA1A90C962C7CE3E9D2797405C7`.

Die Charakterisierung hat keinen vorausgehenden nativen Fehlversuch.
COMPLETED bestätigt den abgeschlossenen privaten Beobachter und Cleanup,
nicht die funktionale Fehlerisolation. Die Korrektur der ON-Kalendergrenze
bleibt offen. Weitere ungültige Werte, vollständige Ausgabeschemata, RAW,
CONSOLE, TABLE, andere Engines und innere Catchcleanup-Gegenproben bleiben
ungeprüft. Statusflags, OpenScope, Registry und historische Laufzeitmatrix
bleiben erhalten; OPS-008 bleibt partiell.

## OPS-008-Korrektur der Agent-Kalenderfehlerisolation vom 8. Oktober 2026

Die nachfolgende Produktkorrektur des in PR #305 beobachteten Fehlers
besteht auf SQL Server 2025 `17.0.4075.5`, Linux/Docker und
Framework-CL170. Ausschließlich ein neues eigenes lokales Lab wird
verwendet. Core187 wird aus den kanonischen Quellen neu erzeugt und
installiert. Die beiden öffentlichen Signaturen und Ausgabeschemata,
Labquellen und Registry bleiben unverändert.

Der versionierte OPS-005-Adapterinstaller wird mit dem vorhandenen
Build-AdapterInstall-Weg regeneriert. Sein Delta enthält ausschließlich
dieselben acht Produktzeilen; der generierte Updatevertrag bleibt erhalten.
Der bestehende Adaptervalidator besteht einschließlich der öffentlichen
Lab-Adaptervalidierung. Eine zusätzliche native Linked-Server-Probe wird
für diese Quellkopplung nicht ausgeführt.

AgentJobs deaktiviert XACT_ABORT ausschließlich während der bestehenden
Job-/Stepcollection, AgentMonitoring während der bestehenden Jobcollection.
Beide stellen den ursprünglichen Optionswert unmittelbar nach TRY/CATCH
und vor weiteren Ausgabeschreiboperationen wieder her. Die bestehenden
242-/Partial-Verträge bleiben erhalten. Dies ist keine Reparatur bereits
uncommittable Callertransaktionen und keine allgemeine Zusicherung für
andere Collectionfehler.

Die getrennten privaten ON-/OFF-Gegenproben verwenden 20230229 und
20240230 als Job- und Stepoutcome. Ein eigener deaktivierter Job mit
einem TSQL-Step wird ausschließlich synthetisch befüllt und nicht
ausgeführt. Bei ungültigem Step ist der Joboutcome gültig. Je Mode messen
vier direkte native OFF-Orakel außerhalb sämtlicher Consumertransaktionen
Fehler 242. Je Mode bestehen eine unabhängige Monitoring-Baseline und
zwölf NONE-/JSON-Consumer mit jeweils frischer eigener schreibfähiger TX1.

| Consumer | Ungültiger Joboutcome, je Mode zwei Fälle | Ungültiger Stepoutcome, je Mode zwei Fälle |
|---|---|---|
| MsdbHealth | AVAILABLE ohne Partial oder Fehler; Historycount 1 | AVAILABLE ohne Partial oder Fehler; Historycount 2 |
| AgentJobs | ERROR_HANDLED/Partial/242 mit Message und gültigem JSON; Jobs 0 und Steps 0 | ERROR_HANDLED/Partial/242 mit Message und gültigem JSON; Jobs 1 und Steps 0 |
| AgentMonitoring | AVAILABLE_LIMITED/Partial/242 mit Message und gültigem JSON; Jobs 0 | AVAILABLE_WITH_FINDING ohne Partial oder Fehler; Jobs 1 |

Alle 24 Callertransaktionen bleiben schreibfähig mit XACT_STATE 1. Kein
Fehler entkommt; insbesondere fehlt die zuvor beobachtete 3930-Eskalation.
Die vollständigen Werte der sechs geordneten Agentquellen einschließlich
NULL-Werten, TX1, Locktimeout 31 und der jeweilige ON-/OFF-Wert bleiben
nach jedem Consumer erhalten. Je Mode stellen zwölf Rollbacks sämtliche
ursprünglichen Quellwerte wieder her. Abschließend bestehen ursprüngliches
OFF, Locktimeout -1, TX0 und separat erfasster XACT_STATE 0. Der Nachweis
gilt für diese vier Kalenderfälle und NONE/JSON auf dieser Engine.

Die bestehende registrierte TEST-0001-Fixture wird um zwölf ON-Kalender-
Consumer mit eigenen Transaktionen und Kalenderrollbacks erweitert.
Der Zustand wird direkt nach jedem Rollback vor dem Quellensnapshot
separat erfasst. Die native Ausführung der Fixture bestätigt 21 positive
und zwölf Kalenderaufrufe. Der private JSON-Ausgabetransport ergänzt
ausschließlich die Abschlusszeile; die ausgeführten Assertions stammen
aus der registrierten Fixture. Sämtliche zwölf Kalenderrollbacks bestehen.

Die 13 vom bestehenden Impactselektor ausgewählten direkten und
transitiven Runtimeverträge bestehen. Common148 bestätigt positive
Monitoring-TABLE-/JSON-Parität mit eigenen ungebundenen Jobdefinitionen.
Common167 bestätigt die allgemeinen TABLE-, Consumer-, Mapping- und
leeren CONSOLE-Verträge; ohne eigene positive Job-/Schedulefixture bleibt
sein positiver Block NOT_EXECUTED. Der vorhandene FIND-COMPAT-Vertrag in
Integration178 prüft CL120 auf derselben Engine und stellt CL170 wieder
her. Weitere native Engines oder eine zusätzliche allgemeine
Compatibility-Matrix werden nicht ausgeführt.

Der eigene äußere Labcleanup besteht mit zwei Schritten ohne Fehler;
der Statepfad ist entfernt. Erst danach wird das PASS-JSON exklusiv
mit CreateNew geschrieben. Ein vorausgehender nativer Fixlauf scheitert
beim Kompilieren des neuen Fixtureteils: Die Returnvariable @Return war
nicht deklariert. Core187, Smoke110 und Runtime122 waren zuvor erfolgreich.
Der Lauf liefert kein abschließendes PASS-JSON. Sein eigener äußerer
Labcleanup besteht mit zwei Schritten ohne Fehler; der Statepfad ist entfernt.
Rawprotokoll, damalige Fixture und Wrapper bleiben privat erhalten.
Die Korrektur deklariert ausschließlich @CalendarReturn im neuen Fixtureteil
und bindet dessen vier Verwendungen. Produktcode und private ON-/OFF-SQL
bleiben gegenüber diesem Fehlversuch unverändert. Der nachfolgende hier
beschriebene Gesamtlauf besteht. Der ON-SQL-Stand besitzt SHA-256
`3FEC7D56B96A4C0C2C4A22A21FEB2FEA0DE683EEB8811CE4B46908E1FD252FEC`,
der OFF-SQL-Stand
`67C15D4F2E62FABC7254A753B86573EB8C43BDBD00ABCC3C23B5C5CD167CA2E9`.
Die tatsächliche Abnahme wurde am `2026-10-08T15:03:47.0787718+00:00` erfasst.

Andere ungültige Datums-/Uhrzeitwerte, die ungültigen Kalenderfälle in
TABLE/RAW/CONSOLE und innere Fehlercleanup-Gegenproben bleiben ungeprüft.
Historische Laufzeitmatrix, Statusflags und OpenScope bleiben erhalten;
OPS-008 bleibt partiell. SMTP bleibt Aufgabe von SQL_Server_Lab.

## OPS-008-Regression ungültiger Agent-Uhrzeiten vom 8. Oktober 2026

Der integrierte Fehlerisolationsfix aus PR #306 wird für die ungültigen
Uhrzeiten 236060 und 240000 bei gültigem Datum 20240229 geprüft. Der
native Lauf besteht auf SQL Server 2025 `17.0.4075.5`,
Linux/Docker und Framework-CL170 in einem neuen eigenen lokalen Lab.
Der Scope erweitert ausschließlich die bestehende TEST-0001-Fixture
und ihre Dokumentation. Produktquellen, Signaturen, Ausgabeschemata,
Installer und Registry bleiben erhalten.

Die getrennten privaten ON-/OFF-Proben injizieren die zwei Uhrzeiten
jeweils als Job- und Stepoutcome eines eigenen deaktivierten Jobs mit
einer TSQL-Stepdefinition. Der Job wird nicht ausgeführt. Bei ungültigem
Step bleiben Jobdatum und Jobuhrzeit gültig. Je Mode messen vier direkte
native OFF-Orakel außerhalb jeder Consumertransaktion Fehler 242; eine
unabhängige Monitoring-Baseline bleibt fehlerfrei. Je Mode bestehen
zwölf NONE-/JSON-Consumeraufrufe mit jeweils frischer eigener
schreibfähiger TX1.

| Consumer | Ungültige Jobuhrzeit, je Mode zwei Fälle | Ungültige Stepuhrzeit, je Mode zwei Fälle |
|---|---|---|
| MsdbHealth | AVAILABLE ohne Partial oder Fehler; Historycount 1 | AVAILABLE ohne Partial oder Fehler; Historycount 2 |
| AgentJobs | ERROR_HANDLED/Partial/242 mit Message und gültigem JSON; Jobs 0 und Steps 0 | ERROR_HANDLED/Partial/242 mit Message und gültigem JSON; Jobs 1 und Steps 0 |
| AgentMonitoring | AVAILABLE_LIMITED/Partial/242 mit Message und gültigem JSON; Jobs 0 | AVAILABLE_WITH_FINDING ohne Partial oder Fehler; Jobs 1 |

Alle 24 Callertransaktionen bleiben schreibfähig mit XACT_STATE 1; kein
Fehler entkommt. Sechs vollständige geordnete Agentquellen einschließlich
NULL-Werten, TX1, Locktimeout 31 und der jeweilige ON-/OFF-Wert bleiben
nach jedem Consumer erhalten. Je Mode restaurieren zwölf eigene
Rollbacks sämtliche ursprünglichen Quellen. Abschließend bestehen
ursprüngliches OFF, Locktimeout -1, TX0 und separat erfasster XACT_STATE 0.

Die bestehende registrierte TEST-0001-Fixture behält ihre 21 positiven
Consumeraufrufe und zwölf Aufrufe für ungültige Datumswerte bei. Vier zusätzliche
Job-/Step-Uhrzeitfälle erweitern die negativen ON-Aufrufe auf 24 mit
jeweils eigener frischer Transaktion und geprüftem Rollback. Die native
Ausführung bestätigt 21 positive und 24 Kalender-/Uhrzeitaufrufe sowie
24 eigene Kalenderrollbacks. Der private JSON-Transport ergänzt nur
die Abschlusszeile; die fachlichen Assertions stammen aus der Fixture.

Die aus kanonischen Quellen neu erzeugte Coreinstallation besteht mit
187 Batches. Smoke110 besteht mit drei und Runtime122 mit zwei Batches.
Die im vorausgehenden Produktslice erfolgreich geprüften 13 Runtime-
verträge werden für die unveränderten Produktquellen nicht wiederholt.
Es wird keine weitere native Engine oder Compatibility-Matrix gestartet.
Der eigene äußere Labcleanup besteht mit zwei Schritten ohne Fehler;
der Statepfad ist entfernt. Erst danach wird das PASS-JSON exklusiv mit
CreateNew geschrieben. Dieser Umfang hat keinen vorausgehenden nativen
Fehlversuch. ON-SQL SHA-256 ist `153761B0FDD4F68C08A76E1F9998942699698DC28B7991FE603003BB18064FC5`;
OFF-SQL SHA-256 ist `1D26789280B80E349D7FB1F38FD05AB8DC6577C281849D88180FDDA896BB3597`.
Die tatsächliche Abnahme wurde am `2026-10-08T15:33:42.9771880+00:00` erfasst.

236060 verändert Minuten und Sekunden gemeinsam; isolierte Teilfeldgrenzen,
andere Uhrzeitwerte, fehlerhafte Dauerformate, tatsächliche Agentdauer
und ungültige Kalenderwerte in TABLE/RAW/CONSOLE bleiben ungeprüft.
Historische Laufzeitmatrix, Statusflags und OpenScope bleiben erhalten;
OPS-008 bleibt partiell. Die SMTP-Abhängigkeit wird ausschließlich durch
die öffentliche integrierte und nativ abgenommene Lab-Funktion erfüllt.

## OPS-008-Abnahme einer tatsächlichen kurzen Agentdauer vom 8. Oktober 2026

Ein neuer eigener lokaler SQL-2025-Labcontainer mit Linux/Docker,
Engine `17.0.4075.5` und Framework-CL170 führt einen eigenen
TSQL-Job mit genau einem Step aus. Die Stepdefinition wartet drei Sekunden
und führt SELECT 1 aus. Retry, Schedule und Benachrichtigungen fehlen;
der Job wird nach bestätigtem Abschluss deaktiviert. Die Probe bindet
zwei native erfolgreiche Historyzeilen an die eigene Job-ID, den Step,
die Reihenfolge und die abgeschlossene aktuelle Agent-Activity.
Es werden keine Historywerte injiziert.

Native History speichert 3 Sekunden für den Step und 4 Sekunden
für den Job. Der private Guard nimmt nur Werte von 3 bis 59 an: In diesem
Bereich ist der native HHmmss-Wert unmittelbar der Sekundenwert.
Die Referenz kopiert keine Dauerumrechnungsformel aus dem Produkt.
Native Startwerte werden unabhängig mit DATETIMEFROMPARTS aus run_date
und run_time gebildet; agent_datetime dient nicht als Referenz.
Beide gespeicherten Startwerte sind `2026-10-08T15:49:49` ohne Zeitzonenvertrag.

| NONE-/JSON-Aufruf | Tatsächlich bestätigter Umfang |
|---|---|
| MsdbHealth | AVAILABLE ohne Partial oder Fehler; Historycount 2, NULL-Zeitgrenzen und nicht leere EvidenceLimit |
| AgentJobs normal | AVAILABLE ohne Partial oder Fehler; ein deaktivierter erfolgreicher Job und ein erfolgreicher Step; LastRunDurationSeconds und LastRunDateTime entsprechen nativer History |
| AgentJobs Problemfilter | Ein deaktivierter erfolgreicher Job mit nativer Dauer und Startzeit; kein Step |
| AgentMonitoring | AVAILABLE_WITH_FINDING ohne Partial oder Fehler; eine erfolgreiche deaktivierte Jobzeile mit JOB_STATE_INFORMATIONAL/INFO; LatestRunDuration und LatestRunDateTime entsprechen nativer Jobhistory |

Sechs vollständige geordnete Agentquellen einschließlich NULL-Werten
bleiben nach Stabilitätsprüfung und jedem der vier Consumeraufrufe
erhalten. Die eigene Callertransaktion bleibt schreibfähig mit ON,
Locktimeout 31, TX1 und separat erfasstem XACT_STATE 1. Ein eigener
Rollback restauriert die vollständigen Quellen. Nach Löschen des eigenen
Jobs entsprechen sie der ursprünglichen Basis. Abschließend bestehen
ursprüngliches OFF, Locktimeout -1, TX0 und separat erfasster XACT_STATE 0.

Die aus kanonischen Quellen erzeugte Coreinstallation besteht mit
187 Batches, Smoke110 mit drei und Runtime122 mit zwei Batches. Der eigene
äußere Labcleanup besteht mit zwei Schritten ohne Fehler; der Statepfad
ist entfernt. Erst danach wird das PASS-JSON exklusiv mit CreateNew
geschrieben. Dieser Umfang hat keinen vorausgehenden nativen Fehlversuch.
Die tatsächliche Abnahme wurde am `2026-10-08T15:50:00.1641928+00:00` erfasst.
SQL-SHA-256 ist `EDCBACC9EB1FE9D462ED695EEE96B468B07715A68BF23D61328336A8EB0B812C`;
Wrapper-SHA-256 ist
`D7BC5E5AB430E84E2FDCBBBD35E2B27799FDDD0DC14F6CF8CC3DF6DEDD42245D`.

Der Umfang ergänzt ausschließlich sieben kanonische Dokumentationsquellen.
Produktquellen, öffentliche Verträge, Fixture und Installer bleiben erhalten.
Unveränderte Runtimeverträge und die Kalenderfixture werden nicht erneut
ausgeführt. Es wird keine zusätzliche native Engine oder Compatibility-
Matrix gestartet. Dies ist ein einzelner kurzer tatsächlicher Dauerwert;
keine exakte WAITFOR-Timinggarantie, Minuten-/Stundenübergänge, langen
Ausführungen, Durationparität in TABLE/RAW/CONSOLE oder empirische innere
Catchcleanup-Abnahme. Historische Laufzeitmatrix, Statusflags und OpenScope
bleiben erhalten; OPS-008 bleibt partiell. SMTP bleibt bis zur öffentlichen
integrierten und nativ abgenommenen Lab-Funktion zurückgestellt.

## OPS-008-Regression isolierter ungültiger Minuten und Sekunden vom 8. Oktober 2026

Eine weitere getrennte native Probe bestätigt den integrierten Fehlerisolationsfix
für isolierte ungültige Minuten und Sekunden. 6000 entspricht 00:60:00,
60 entspricht 00:00:60. Bei gültigem Datum 20240229 werden beide Werte als
Job- und Stepoutcome geprüft. Der neue eigene lokale Labcontainer verwendet
SQL Server 2025 `17.0.4075.5`, Linux/Docker und Framework-CL170.
Ein eigener deaktivierter Job besitzt eine TSQL-Stepdefinition ohne Ausführung.
Bei ungültigem Step bleiben Jobdatum und Jobuhrzeit gültig.

Je ON-/OFF-Mode messen vier direkte OFF-Orakel außerhalb jeder
Consumertransaktion Fehler 242. Eine unabhängige Monitoring-Baseline bleibt
fehlerfrei. Je zwölf NONE-/JSON-Aufrufe mit eigener frischer TX1 bestehen.

| Consumer | Ungültiger Joboutcome | Ungültiger Stepoutcome |
|---|---|---|
| MsdbHealth | AVAILABLE ohne Partial oder Fehler; Historycount 1 | AVAILABLE ohne Partial oder Fehler; Historycount 2 |
| AgentJobs | ERROR_HANDLED/Partial/242 mit Message und gültigem JSON; Jobs 0, Steps 0 | ERROR_HANDLED/Partial/242 mit Message und gültigem JSON; Jobs 1, Steps 0 |
| AgentMonitoring | AVAILABLE_LIMITED/Partial/242 mit Message und gültigem JSON; Jobs 0 | AVAILABLE_WITH_FINDING ohne Partial oder Fehler; Jobs 1 |

Alle 24 Callertransaktionen bleiben schreibfähig mit XACT_STATE 1; kein
Fehler entkommt. Sechs vollständige geordnete Agentquellen einschließlich
NULL-Werten, TX1, Locktimeout 31 und der jeweilige ON-/OFF-Wert bleiben
nach jedem Consumer erhalten. Je zwölf eigene Rollbacks restaurieren
die ursprünglichen Quellen. Abschließend bestehen ursprüngliches OFF,
Locktimeout -1, TX0 und separat erfasster XACT_STATE 0.

Die bestehende TEST-0001-Fixture erhält ihre 21 positiven Aufrufe und
24 bisherigen negativen Kalender-/Uhrzeitaufrufe. Vier weitere Job-/Stepfälle
für 6000 und 60 ergänzen zwölf negative ON-Aufrufe auf insgesamt 36 mit
je frischer eigener TX1 und geprüftem Rollback. Die native Ausführung
bestätigt 21 positive und 36 negative Aufrufe sowie 36 eigene Kalenderrollbacks.
Der private JSON-Transport ergänzt ausschließlich die Abschlusszeile;
fachliche Assertions stammen aus der registrierten Fixture.

Coreinstallation besteht mit 187 Batches, Smoke110 mit drei und Runtime122
mit zwei Batches. Unveränderte Produktverträge werden nicht pauschal wiederholt;
es wird keine weitere native Engine oder Compatibility-Matrix gestartet.
Der eigene äußere Labcleanup besteht mit zwei Schritten ohne Fehler;
der Statepfad ist entfernt. Erst danach wird das PASS-JSON exklusiv mit
CreateNew geschrieben. Dieser Umfang hat keinen vorausgehenden nativen
Fehlversuch. Die tatsächliche Abnahme wurde am `2026-10-08T16:02:44.3848858+00:00` erfasst.
ON-SQL-SHA-256 ist `5B329E69BBB136FF4CC028C26D5A4B5866858072E1A28E90015FC88858671194`;
OFF-SQL-SHA-256 ist `08C51C0E45C2AA3C877D95DE748B42B6F8316ECF2ABCB8C7CF5F7F5CD6B3902C`.

Der Umfang ändert ausschließlich die bestehende Fixture und sieben
kanonische Dokumentationsquellen. Produktquellen, öffentliche Verträge,
Installer und Registry bleiben erhalten. Andere Werte, ungültige Kalenderfälle
in TABLE/RAW/CONSOLE, weitere Dauergrenzen und empirische innere Catchcleanup-
Gegenproben bleiben ungeprüft. Historische Laufzeitmatrix, Statusflags und
OpenScope bleiben erhalten; OPS-008 bleibt partiell. Die SMTP-Abhängigkeit
benötigt weiterhin die öffentliche integrierte und nativ abgenommene Lab-Funktion.

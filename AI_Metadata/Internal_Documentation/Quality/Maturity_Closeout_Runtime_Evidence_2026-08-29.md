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

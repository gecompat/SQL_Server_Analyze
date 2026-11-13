# Nächste Arbeitsschritte

**Stand:** 13. November 2026  
**Zweck:** aktueller Fortsetzungseinstieg für `gecompat/SQL_Server_Analyze`.

## Aktuelle Orchestrierung

PR #695 schloss die Agent-History-Grenzfallwelle mit erster Head- und Main-Abnahme ab. Der reguläre Merge/Main `85ef3d2c6ddfb64e331638c22d9b4e5fcc1ba715` enthält Baum `ce6d321a709d40957b8f1b9f4ff2bb8f3cd1f2e9` und die geordneten Eltern `f89eeccc1a07292c93936c9d9c926f45c30ad952` und `d05cc888768db36f94c1e7c042e9fb95e5e309df`. Head [43420929679](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43420929679) bestand sechs Workflows und acht Checks; Main [43422837975](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43422837975) bestand fünf Workflows und sieben Checks. Beide Laufzeitgates bestätigten Deployment, MSDB-Vertrag 122, die tatsächliche Fixture mit 103 positiven Aufrufen und Stop auf SQL Server 2025 bei CL170. Die getrennte Kalender-/Uhrzeitsektion blieb bei 96 Aufrufen und 72 Rollbacks. Dokumentations- und Cleanup-Gates bestanden für Head und Main; die 25 Regelkontext-Selbsttests, zusätzliche Engines und Compatibility Levels waren nicht ausgewählt.

Das [Agent-Proxy-Dossier](../Architecture/Agent_Proxy_Dependency_Inventory_Dossier.md) begrenzt den Kandidaten. Die aktuelle ausführbare Welle entwickelt unter `AGENT_PROXIES_CREDENTIALS` eine eng begrenzte, lesende SQL-Agent-Proxy-Inventur. V1 erfasst Proxy- und Subsystemkatalog sowie Credential-ID und sichtbaren Credentialnamen; sie liest keine Credentialidentität, Secrets, SIDs, Loginzuordnungen, Jobsteps, Befehle oder Pfade und behauptet keine effektiven Rechte oder Proxy-Ausführung. Die Produktquelle, kanonische Registrierung, Installerableitung, öffentliche Leserichtung und der neue native Vertrag bilden einen kohärenten Änderungsschritt. Wegen der Änderung an `Code/Install/Install_All.sql` verlangt die CI-Teststrategie das vollständige funktionale SQL-Server-2025-Gate bei CL170; der spezifische Proxyvertrag gehört dazu und verengt den Gateumfang nicht. Zusätzliche native Engines oder eine Releasematrix folgen daraus nicht. Der vollständige native Head-Funktionslauf bestand auf SQL Server 2025 bei CL170, die Head-Dokumentationsprüfung noch nicht; die Abdeckungsmatrix führt nur den vorhandenen Katalog-Slice als `PARTIAL_PRODUCT_FUNCTION`, `Module_Maturity` bleibt `PLANNED`. Ein positiver Proxy- oder Ausführungsfall ist damit nicht belegt. Der unabhängige Source- und Sicherheitsreview bestätigte die erste begrenzte Quelle (Blob `58a9935b045ae373018df8fe0a11bdfd1418b9bf`) und den weiterhin unveränderten Laufzeitvertrag (Blob `4def7ac5f456607c86ab2c69f9e9393e3845e082`) ohne blockierenden Befund. Die gezielte unabhängige Nachprüfung der korrigierten Quelle (Blob `8050eeb8bbf2bf6aaa2b46f49744ab310974db1a`) und Navigationskante (Blob `6ba2cdd8b1b5cc72c6ecf3e4a52de6387c957dbe`) bestand ohne blockierenden Befund. Verarbeitungsaufwand und private Verbrauchsgrenzen werden nicht im Repository veröffentlicht.

Der kanonische Korrekturlauf [43433468434](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43433468434), Job 131912505887, bestand beim ersten Versuch und erzeugte die OPS-005-Installationskopie `TestLab/Adapters/OPS-005/sql/install.sql` mit Blob `8dbd50441fc3bf48cba6a023013351abd08fda2b` (6.569.259 Bytes). Der vollständig gelesene Blob wurde gegen die drei geänderten Vollmodule und den unveränderten Rest gebunden; die eigenständige Installationskopie und Update-Kopie blieben kanonisch unverändert. Der unabhängige Schlussreview bestätigte die Artefaktbindung von OPS-Blob `8dbd50441fc3bf48cba6a023013351abd08fda2b` (6.569.259 Bytes), Generator-Envelope `94b3440c3d2c0c58311fbc9a166eb588e54567c0` (1.669.553 Bytes) und Lauf 43433468434/Job 131912505887 sowie die finalen Metadaten mit begrenztem Coverage-Status `PARTIAL_PRODUCT_FUNCTION`. Der erste Head-Lauf von PR #696 erreichte das native Pflichtgate nicht bis zu den Verträgen; eine Main-Abnahme hat noch nicht begonnen. Integration setzt grüne Pflichtgates voraus.

PR #696 am Head `4ac5af82d745eb059ef9a20e1bc590a5f8b29855` lieferte getrennte Befunde: [Dokumentation 43436965553](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43436965553), Job 131924468996, scheiterte an konkret benannten Regelkontext-, Quellabschluss-, Zähl-, Navigations-, Coverage-, Nonblocking- und Berechtigungsfehlerzuordnungsprüfungen. Der [funktionale Lauf 43436965541](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43436965541), Runtime 131924595344 und Gate 131928695709, scheiterte vorher beim Deployment in SnapshotSchema Stage 0 (NativeError 53935, SQL 1222, Zeile 816). `BLOCKER_NOT_CAPTURED`, null Beobachterfehler, gekürzte Summary und `wrapperIncomplete=false` belegen keinen Blocker; die Ursache bleibt `UNKNOWN`. Alle SQL-Verträge einschließlich Proxyvertrag 126 wurden übersprungen; der synthetische Stop bestand. Cleanup, Privacy, Registry und Commit bestanden getrennt. Das vollständige Runtimearchiv wurde nicht entpackt; eine Proxy-Laufzeitqualifikation oder kausale Fehlerbehebung folgt daraus nicht. Die Korrektur bindet die statischen Befunde eng. Die frühere OPS-Installationskopie `8dbd50441fc3bf48cba6a023013351abd08fda2b` bleibt die historische Bindung des ersten PR-Heads. Der einmalige kanonische Generatorlauf [43442822408](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43442822408), Job 131944527302, bestand beim ersten Versuch und erzeugte die neue OPS-Installationskopie `da3e6433b321d4abea6ae2cdff7521035f0d495a` (6.569.547 Bytes) aus den korrigierten Vollmodulen 021, 022, 023 und 025; die Generator-Envelope ist `7daf988c93e7c33120ad4345ea3bb4ff40773e0e` (1.669.914 Bytes). Die unabhängige Nachprüfung der neuen Artefakt- und Metadatenbindung mit OPS-Blob `da3e6433b321d4abea6ae2cdff7521035f0d495a`, Generator-Envelope `7daf988c93e7c33120ad4345ea3bb4ff40773e0e` und Lauf 43442822408/Job 131944527302 bestand. Die korrigierte Head-Dokumentationsprüfung und die erste Main-Abnahme stehen noch aus. Der Generatorerfolg belegt keine SQL-Laufzeitqualifikation.

Am korrigierten Head `98b7c6f64fca5bb59f1f9e40d24e16a6a3599165` bestand der [funktionale Lauf 43443935686](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43443935686), Runtime 131948462202 und Gate 131959679777, im ersten Versuch: Deployment, ausgewählte Verträge und tatsächlicher Stop auf SQL Server 2025 bei CL170. Der Selector wählte die vollständige Release-Gate-Suite einschließlich Proxyvertrag 126 sowie Berechtigungs-, Regex- und Standalone-Prüfungen; die betroffenen Schritte bestanden. Einzelne SQL-stdout-/126-PASS-Marker wurden nicht exportiert. Die [Dokumentationsprüfung 43443935550](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43443935550), Job 131948360294, scheiterte allein an einer unklassifizierten Produktreferenz von Development_Waves auf die OPS-005-Installationskopie; die übrigen zuvor gemeldeten statischen Befunde entfielen, beide kanonischen Installervergleiche bestanden. Cleanup, Privacy, Registry und Commit bestanden getrennt. Der Regelkontext-Extractor erfasst denselben OPS-Pfad auch in Next_Steps; beide Planungsreferenzen sind im Korrekturkandidaten als `product-reference` klassifiziert. Für diese Scopekorrektur liegt noch keine neue CI-Prüfung vor; eine erste Main-Abnahme fehlt. Die erfolgreiche Suite enthält keinen belegten positiven Proxyfall, keine Windows-Proxy-Ausführung und keine Prüfung effektiver Rechte.

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

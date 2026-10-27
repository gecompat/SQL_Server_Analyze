# Nächste Arbeitsschritte

**Stand:** 27. Oktober 2026
**Zweck:** aktueller Auftragsstatus und historische Entwicklungswellen für `gecompat/SQL_Server_Analyze`

## Aktuelle Orchestrierung

Seit dem Benutzerauftrag vom 26. Oktober 2026 führt der
[Gesamtauftrag](#aktueller-gesamtauftrag-priorisierte-entwicklungswellen) die
Weiterentwicklung einschließlich verbleibender SSIS-Themen als einziger
Orchestrator. Die aktuelle Reihenfolge und der nächste ausführbare Schritt
stehen in der [Entwicklungsplanung](Development_Waves_2026-10.md).
Abgeschlossene SSIS-Wellen werden nicht wiederholt; die bestehende SSISDB
bleibt erhalten. Frühere separate Aufträge sind nachfolgend historisch geführt.

### Aktueller Checkpoint nach Schritt 40

Schritt 39 konkretisierte MSDTC im [Dossier](../Architecture/MSDTC_Distributed_Transaction_Inventory_Dossier.md); Schritt 40 implementiert den begrenzten SQL-sichtbaren read-only-Slice in `USP_DistributedTransactionInventory`. Die funktionale SQL-2025-Head-Prüfung für Commit `51c20d073ac0faceef3fad0fb7485f1b4c6e8178` bestand in [Run 40555564808](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40555564808); `full_suite=true`, Vertrag 140 ist genau einmal im kanonischen Phase-7-Fail-fast-Gate enthalten. SQL-Erfolgsstdout wurde nicht exportiert, ein separater PASS-Marker liegt nicht vor. Im CI1 scheiterte die Dokumentationsprüfung an der Source-Closure-Erwartung 202 statt 203; die Zählung ist lokal korrigiert und der fokussierte Test besteht. Dieser Absatz dokumentiert den CI1-Snapshot; der jeweilige Head- und Integrationsstatus wird in den [Livechecks von PR #479](https://github.com/gecompat/SQL_Server_Analyze/pull/479) nachverfolgt. Ein Modul-Reifeabschluss bleibt offen; die Coverage ist partiell, die Reifematrix PLANNED. Positive aktive DTC-Zeile, verteilte Commit-/Recovery-Evidenz und externe MSDTC-/Teilnehmergesundheit bleiben unqualifiziert; SQL-Server 2019/2022 wurden nicht separat qualifiziert.

Schritt 40 ist über [PR #479](https://github.com/gecompat/SQL_Server_Analyze/pull/479) regulär integriert. Mergecommit `42273a72927db419be185c030fa9f6c6de6d6544` besitzt den geprüften Baum `580c20e`; alle acht Head- und fünf Main-Prüfungen bestehen. Das funktionale SQL-2025-Head-Gate bestand in [Run 40561907132](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40561907132) am Commit `0de66635d36d7217eb042f2cd0470a9203a95ab6`; der getrennte Main-Lauf [40563959891](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40563959891) bestand am Mergecommit. Die Main-Prüfungen für [Dokumentation](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40563959893), [Datenschutz](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40563959899), [Commitnachrichten](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40563959952) und [TestLab](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40563959912) bestehen ebenfalls. Die frühere CI1-Fehlprüfung bleibt als Fehlerhistorie erhalten. Der Benutzer erweiterte die ursprüngliche Obergrenze von 40 um weitere 40 eigene PR-Schritte auf insgesamt 80; die bereits abgeschlossenen 40 bleiben angerechnet. Der Checkpoint liegt bei 70. `DATABASE_MIRRORING` ist der nächste WI-0010-Kandidat mit Intake-Status `RESEARCHED_NOT_IMPLEMENTED` und Priorität P1. Das Dossier steht noch aus; Implementierung und Qualifikation sind nicht erfolgt. Die positive aktive DTC-Zeile, verteilte Commit-/Recovery-Evidenz, externe MSDTC-/Teilnehmergesundheit und native SQL Server 2019/2022-Evidenz bleiben offen.


PR #464 schließt Schritt 26 ab. Source-Head `12bf7fff` und Merge `178a6b38`
bestehen sieben Head-Checks, den SQL-Server-2025-Lauf
[40332918187](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40332918187)
und alle vier getrennten Main-Gates. Der Common-159-Quelllauf ist belegt; sein
Erfolgsstdout wurde nicht separat exportiert, daher wird kein separat erfasster
PASS-Marker behauptet. Der TRUNCATE-/MinValidVersion-Fall belegt keine
zeitbasierte Retention oder Backgroundbereinigung. Lokale native Versuche
bleiben null.

Schritt 27 konkretisierte den Reader-Vertrag im
[Linux-cgroup-Dossier](../Architecture/Linux_Cgroup_Resource_Boundary_Dossier.md)
und in der öffentlichen
[Readerspezifikation](../../../Documentation/Analysis_Guides/Linux_Cgroup_Reader_Contract.md).
Schritt 28 bündelt Native-Primitiven, Reader/CLI, portable Wire-Oracles und den
gezielten Linux-Nativejob als PR-Kandidat. Unabhängiger Review, tatsächlicher
Linux-CI-Lauf und PR-Gates stehen aus; lokal erfolgte keine Nativeausführung.
Hostqualifikation, cgroup-Limitwirkung und SQL-Bindung bleiben offen. Die
Bearbeitung verwendet ECONOMICAL/LOCAL und eskaliert gezielt bei konkretem
ungeklärtem Vertrags- oder Prüfbedarf.

## Historischer SSIS-Auftrag: elfte Paketwelle

Die Welle ist über [PR #457](https://github.com/gecompat/SQL_Server_Analyze/pull/457)
mit Abnahme, unabhängigem Review und allen Head-/Main-Gates abgeschlossen.
Die folgenden Angaben beschreiben ihren damaligen begrenzten Auftrag.

Der Benutzer hat die [gebundene Mehrlauf-Baseline](../../../Documentation/Analysis_Guides/Procedures/USP_SsisExecutionBaseline.md) autonom einschließlich regulärer PR-Integration nach erfolgreicher Abnahme freigegeben. Der Umfang enthält eine explizite Kohorte mit bis zu 20 Basisläufen und einem Kandidaten, gemeinsame Kennzahlenprojektion mit dem Paarvergleich, exakte deskriptive Statistik, nachvollziehbare Ausschlüsse und INFO-Regeln ab fünf verwendbaren Basiswerten.

Ein Implementierer und ein unabhängiger Reviewer bearbeiten einen Analyze-PR. Die gemeinsame Grenze beträgt 16 native Rootversuche einschließlich Recovery mit Checkpoint bei zwölf; vorgesehen sind fünf Basisläufe und sechs Kandidaten. Vier begrenzte Reviewrunden bilden die Obergrenze für Erstprüfung und konkrete Befundnachprüfungen. Verlässliche Kostenmessung liegt nicht vor. Frühere Wellenzähler bleiben abgeschlossen. Die vorhandene SSISDB wird weiterverwendet und bleibt erhalten. Parser, Profile und Lineage verbleiben in Toolbelt; Analyze bleibt ohne SQL CLR eigenständig. Der Produktumfang ist implementiert und lokal abgenommen: 46 synthetische Baselinefälle, die 38 Paarvergleichsfälle, betroffene Scope-/Pipeline-Regressionen sowie vollständige Coreinstallation, Smoke-, Frameworkausgabe- und Navigationsverträge bestehen. Die native Abnahme verwendet zwei gebundene Kohorten mit insgesamt 16 Rootversuchen. Gleichstand, Verzögerung und Volumenänderung sowie Loggingwechsel, eigener SQL-Fehler und Abbruch sind anhand ihrer unveränderten nativen Captures auch mit dem abschließenden gemeinsamen Consumer geprüft. Ein anfänglicher Orakelfehler bei einer leeren PowerShell-Werteliste und ein privater Replay-Metadatenfehler bleiben als fehlgeschlagene Läufe erhalten; ihre erfolgreichen Teilfälle werden ausschließlich mit Quellenbindung und eigenständiger Abschlussprüfung zusammengeführt. Eigene Consumerobjekte sind bereinigt, die SSISDB bleibt erhalten. Der unabhängige Review ist nach einer gezielten Korrekturrunde ohne offene P1-/P2-Befunde abgeschlossen. Die regulären PR- und Main-Gates müssen den jeweiligen exakten Commit bestätigen. Nach erfolgreicher Integration enthält dieser begrenzte Auftrag keinen weiteren Entwicklungsschritt. Der separate Gesamtauftrag für andere Entwicklungsränge wird nicht übernommen.

## Historischer SSIS-Auftrag: zehnte Paketwelle

Der Benutzer hat den gebundenen Vergleich genau zweier Ausführungen autonom einschließlich regulärer PR-Integration nach erfolgreicher Abnahme freigegeben. Der Umfang umfasst eine native Vergleichs-API mit vier Ausgabegruppen, unabhängige lokale Capturebindungen, identische Modell-/Paketrevision, konservative Kontextprüfung und INFO-Regeln. Die [Anwenderseite](../../../Documentation/Analysis_Guides/Procedures/USP_SsisExecutionComparison.md) beschreibt den Vertrag.

Parser, Profile und Lineage bleiben in Toolbelt; Analyze bleibt ohne SQL CLR eigenständig. Die vorhandene SSISDB wird weiterverwendet und bleibt erhalten. Ein Implementierer und ein unabhängiger Reviewer bearbeiten einen Analyze-PR. Die gemeinsame Obergrenze beträgt 16 native Root-Ausführungsversuche einschließlich Recovery; vorgesehen sind acht Szenarien. Frühere Wellenzähler bleiben abgeschlossen. Kostenmessung liegt nicht vor. Die bestehende SQL2025-SSISDB besteht die acht vorgesehenen Szenarien über zwei gebundene Läufe: gleiche beobachtete Mengen mit unabhängigem Dauerorakel und RAW-/TABLE-/JSON-Parität sowie Verzögerung, Mengenänderung, Loggingwechsel, eigener SQL-Fehler, Abbruch und Versionsablehnung. Der abschließende Lauf besteht 8549 Assertions; insgesamt wurden 15 der höchstens 16 nativen Rootversuche verwendet. Die 38 synthetischen Vergleichsfälle und die bestehenden Iterations-, Scope-, Pipeline- und Diagnoseregressionen bestehen ebenfalls. Eigene Consumerobjekte sind nachgewiesen bereinigt; die SSISDB bleibt erhalten. Für die reguläre Integration gelten die PR- und Main-Gates; ihre Ergebnisse sind am jeweiligen Commit zu prüfen. Nach deren Abschluss enthält der begrenzte Auftrag keinen weiteren Entwicklungsschritt.

## Historischer SSIS-Auftrag: siebte Paketwelle

Die ausdrücklich freigegebene siebte Welle ergänzt feste projektlokale
Kind-/Enkelpaketaufrufe und die Handler `OnPreExecute`, `OnPostExecute`,
`OnError`. Parser, Komponentenprofile und Lineage bleiben in Toolbelt;
Analyze verarbeitet nur gebundene Modelle und Katalogbeobachtungen ohne SQL CLR.
Der [Anwendungsvertrag](../../../Documentation/Analysis_Guides/Procedures/USP_SsisPackageModelAnalysis.md#kindpaket-und-ereignishandlerkorrelation)
führt die konkrete Schnittstelle und ihre Grenzen.

Der endliche Umfang besteht aus je einem fachlichen PR in Toolbelt und Analyze,
einem Implementierer, einem unabhängigen Review mit gezielter Befundnachprüfung
und höchstens acht nativen Katalogversuchen. Verlässliche Kostenmessung liegt
nicht vor. Die bestehende SSISDB bleibt absichtlich erhalten; jeder Lauf
bereinigt nur seine nachgewiesenen Consumerobjekte. Die lokale Abnahme umfasst
native Windows-SQL2025-Läufe mit 217 Assertions im Erfolgsbaum und 16 Assertions
am tatsächlich ausgeführten OnError-Handler sowie 41 synthetische Empfängerfälle.
Drei P2-Befunde des unabhängigen Reviews sind mit gezielter Nachprüfung geschlossen.
Toolbelt [PR #427](https://github.com/gecompat/SQL_Server_Toolbelt/pull/427) ist
regulär integriert; seine Head- und Main-Gates sind erfolgreich. Die Analyze-
Integration benötigt die regulären Gates des zugehörigen W7-PRs und dessen
Main-Nachlauf. Danach enthält dieser begrenzte Auftrag keinen weiteren
Entwicklungsschritt. Diese Freigabe erweitert keine Zuständigkeit des separaten
Gesamtauftrags.

## Aktueller Gesamtauftrag: priorisierte Entwicklungswellen

Der Benutzer hat am 25. Oktober 2026 die Übernahme der priorisierten offenen
Entwicklungen und deren autonome Umsetzung mit unabhängigen Reviews, Tests
und regulärer PR-Integration nach `origin/main` beauftragt. Die maßgebliche
[Entwicklungsplanung](Development_Waves_2026-10.md) führt Reihenfolge,
Zuständigkeiten, Abschlussbedingungen und den nächsten ausführbaren Schritt.
Sie ersetzt für diesen Auftrag ältere allgemeine Aktivierungsfolgen und
Pausenhinweise, erhält jedoch deren historische Evidenz und konkrete Grenzen.

Seit dem 26. Oktober 2026 bündelt dieser Chat die gesamte Weiterentwicklung.
Die elfte Welle des bisherigen SSIS-Chats ist über PR #457 abgeschlossen.
Die erhaltene SSISDB bleibt bestehen; Parser und Lineage bleiben im Toolbelt,
Analyze bleibt CLR-frei. Neue SSIS-Slices zählen im bestehenden Gesamtbudget
mit. Die ursprüngliche Obergrenze von 40 PR-Schritten und der Checkpoint bei
30 bleiben als Historie erhalten. Die aktuelle, ausdrücklich erweiterte
Obergrenze beträgt 80 PR-Schritte mit Checkpoint bei 70. Der stündliche
Heartbeat dient weiterhin ausschließlich zur Wiederaufnahme bei tatsächlichem
unerwartetem Leerlauf.

Die Planung sowie die ersten Server- und Datenbankprincipal-Slices von Rang 6
sind regulär integriert. [PR #438](https://github.com/gecompat/SQL_Server_Analyze/pull/438)
besteht am Liefercommit `6e41c9fe` alle acht Head-Checks, das vollständige
SQL2025-Gate und gezielte native 2019-/2022-Prüfungen. Nachweise und Grenzen
stehen im [Datenbankprincipal-Dossier](../Architecture/Database_Principal_Analysis_Dossier.md).
Der erste Callerbericht ist über [PR #441](https://github.com/gecompat/SQL_Server_Analyze/pull/441)
mit acht bestandenen Head-Checks sowie SQL2025- und gezielter nativer SQL2019-
Abnahme integriert. Das [Callerrechte-Dossier](../Architecture/Caller_Permission_Analysis_Dossier.md)
führt die tatsächlichen Nachweise und verbleibenden Grenzen.

Der erste Endpoint-/Transport-Slice von Rang 7 ist über
[PR #443](https://github.com/gecompat/SQL_Server_Analyze/pull/443) mit acht
bestandenen Head-Checks, vollständigem SQL2025-Gate und gezielter nativer
SQL2019-Abnahme integriert. Das
[Endpoint-Dossier](../Architecture/Endpoint_Transport_Analysis_Dossier.md)
führt Nachweise und offene Host-/Handshake-/HADR-/MARS-Grenzen. Der getrennte
SQL2025-Main-Nachlauf besteht nach einem einmaligen begrenzten Wiederlauf
der fehlgeschlagenen Jobs; der ursprüngliche SSIS-Legacy-Metadatentimeout
bleibt ohne behauptete Sperrursache dokumentiert.

Die separate SSIS-Datenflusskorrelation ist über
[PR #445](https://github.com/gecompat/SQL_Server_Analyze/pull/445) integriert.
Die damalige Abnahme gehört zum abgeschlossenen SSIS-Auftrag. Seine
erhaltene SSISDB bleibt unverändert; künftige Wellen werden zentral geplant. Der
nächste unabhängige Rang 10 steht im
[Snapshot-Dossier](../Architecture/Snapshot_Expansion_Dossier.md):
Die datenbewahrende Schema-2-Vorbereitung ist über
[PR #447](https://github.com/gecompat/SQL_Server_Analyze/pull/447) integriert.
Alle acht Head-Checks, das vollständige SQL2025-Head- und Main-Gate sowie
die gezielte native SQL2019-Snapshot-Risikoqualifizierung bestehen.
Core-Release und dessen allgemeine native Berechtigungsmatrix gehören
nicht zu diesem zusätzlichen Risikoscope. Das Dossier bewahrt frühere
Vollrunfehler und die Grenzen getrennt vom Integrationserfolg.
Der genaue WAIT_CAPTURE_CONTEXT-Vertrag mit Typen, Mengen-, Rohwert-, Zeit-,
Epochen- und Retentionsbindungen ist unabhängig geprüft. Der Retentionsschutz im gemeinsamen Purge ist über
[PR #449](https://github.com/gecompat/SQL_Server_Analyze/pull/449) als
Targetpatch 1.1.1 einschließlich aller Head- und Main-Gates integriert.
Das interne Wait-Target 1.2.0 ist über PR #451 einschließlich aller sieben Head-Checks, vollständigem SQL2025-Head-/Main-Gate und gezielter nativer SQL2019-Snapshotprüfung integriert. Die öffentliche Frameworkaktivierung mit Targetpatch 1.2.1 ist über PR #453 einschließlich aller sieben Head-Checks, vollständigem SQL2025-Gate und gezielter nativer SQL2019-Abnahme integriert; alle vier getrennten Main-Prüfungen einschließlich des vollständigen SQL2025-Gates bestehen. Der [Datei-I/O-Vorvertrag](../Architecture/File_IO_Snapshot_Dossier.md) ist über PR #454 mit allen vier Head- und drei Main-Prüfungen integriert. Der [genaue Feld- und Migrationsvertrag](../Architecture/File_IO_Snapshot_Field_Contract.md) ist über PR #455 mit allen Head-/Main-Gates integriert. Das interne FILE_IO-Target 1.3.0 / Schema 3 und die notwendige Waitkompatibilität sind über [PR #456](https://github.com/gecompat/SQL_Server_Analyze/pull/456) integriert. Alle sieben Head-Prüfungen, das vollständige SQL2025-Gate, die gezielte native SQL2019-Risikoabnahme und alle vier getrennten Main-Gates bestehen. Der erste Main-Versuch scheiterte im Legacy-SSIS-TABLE-Fall 202/C008 mit Timeout; ein begrenzter Wiederlauf bestand ohne Produktänderung. BLOCKER_NOT_CAPTURED bleibt mit Ursache UNKNOWN erhalten. Die öffentliche native Datei-I/O-Aufnahme mit Targetpatch 1.3.1 / Schema 3 und Retentionsvertrag 3 ist über [PR #458](https://github.com/gecompat/SQL_Server_Analyze/pull/458) als 1a144251 integriert. Alle sieben Head-Checks, das vollständige SQL2025-Gate und die gezielte native SQL2019-Snapshot-Risikoabnahme bestehen am Head 23730d1d. Merge- und Headbaum sind identisch. Alle vier getrennten Main-Gates einschließlich des vollständigen SQL2025-Laufs 40273412551 bestehen. Der nächste unabhängige Rang 11 beginnt mit dem Upgrade-Usage-Vertrag.
Der erste Rang-11-Slice ist über PR #459 integriert. PR #460 bis PR #463
schließen Linux-cgroup-Vertrags- und Parser-Slices ab; PR #464 schließt den
begrenzten Common-159-TRUNCATE-/MinValidVersion-Fall ab. Schritt 27 präzisierte
den Reader-Vertrag im [Dossier](../Architecture/Linux_Cgroup_Resource_Boundary_Dossier.md)
und in der öffentlichen
[Readerspezifikation](../../../Documentation/Analysis_Guides/Linux_Cgroup_Reader_Contract.md).
Schritt 28 ist über [PR #466](https://github.com/gecompat/SQL_Server_Analyze/pull/466)
integriert. Head `18bf0d6e` und Merge `65174ea1` besitzen denselben Baum; alle
vier Head- und drei Main-Prüfungen bestehen. Linux x86_64 mit Python 3.11.17
besteht 223 portable Readerfälle, 113 Parserfälle und 19 native Fälle im
Head- und Main-Lauf. Das Dossier erhält den ursprünglichen CI-Fehllauf und
die begrenzte Testtreiberkorrektur. Lokal erfolgte keine Nativeausführung.
SQL-Import, kontrollierte cgroup-Limitwirkung, globale Hierarchievollständigkeit
und SQL-Instanzbindung bleiben offen. Schritt 29 ist über
[PR #467](https://github.com/gecompat/SQL_Server_Analyze/pull/467) einschließlich
aller Head- und Main-Prüfungen integriert. Der begrenzte
[COLL-B007-Consumernachweis](COLLB007_Filter_Identifier_Runtime_Evidence_2026-09-19.md#ergänzung-vom-26-oktober-2026-datenbankprincipal-consumer)
prüft exakte Datenbankauswahl und Groß-/Kleinschreibung; die garantierte
Collation bleibt unverändert. Schritt 30 ist über
[PR #468](https://github.com/gecompat/SQL_Server_Analyze/pull/468) mit allen
Head- und fünf Main-Prüfungen integriert. Head `dec8cdc7` und Merge `0c958e14`
besitzen denselben Baum. Der tatsächliche Marker der AgentHistory-Fixture,
Standalonevertrag 193, Snapshotverträge und Cleanup bestehen am Head und auf
Main. Der [Reifeevidenznachweis](Maturity_Closeout_Runtime_Evidence_2026-08-29.md#abschluss-des-korrigierten-testvertrags)
erhält alle Fehlläufe und die begrenzte Leerfallkorrektur; die Bestätigung gilt
für die SQL2025-CI-Baseline, nicht für weitere Collationkombinationen.

Der Checkpoint nach 30 Schritten wurde unter der damaligen Obergrenze von 40
Schritten neu bewertet. Die folgende Planung und ihre damalige Grenze von 40
Schritten sind historische Fortschreibung; der Benutzer erweiterte die
Obergrenze anschließend um weitere 40 Schritte auf insgesamt 80. Innerhalb der
damaligen Gesamtgrenze folgte als nächster unabhängiger geplanter Schritt der optionale
[Producervertrag für eigene SSIS-Kennzahlen](../../../Documentation/Architecture/SSIS_Custom_Metrics_Producer_Contract.md)
aus Rang 15. Der Vertragsentwurf ist über
[PR #469](https://github.com/gecompat/SQL_Server_Analyze/pull/469) mit allen
fünf Head- und vier Main-Prüfungen integriert. Head `2ee97df1` und Merge
`d8ca3cb7` besitzen denselben Baum. Schritt 32 integriert über
[PR #470](https://github.com/gecompat/SQL_Server_Analyze/pull/470) ein begrenztes
Offline-Berichtsprofil und einen rein lokalen Validator; vier Head- und drei Main-Prüfungen bestanden. Producer, native
Captureverifikation, SQL-Aufnahme, Aggregation und Vergleich sind damit nicht
implementiert; formatgültige Herkunftsangaben bleiben unbestätigt.
Das [zugehörige Dossier](../Architecture/SSIS_Custom_Metrics_Contract_Dossier.md)
führt Scope, Grenzen und den späteren Implementierungsweg. Externe
Quellenabnahmen, weitere Ausgabearten und andere offene Ränge bleiben erhalten;
es wird kein vollständiger Reifeabschluss behauptet.

Schritt 33 schließt die offene native SQL-Server-2022-Evidenz für `OPS-009`.
Der manuelle [Release-Workflow](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40403446152)
bestand auf Quellcommit `abb2324168e725583edcd22f3fa670c2c2ac5dab` mit
`target=2022` und `qualification_scope=FULL_RELEASE`: 34 Kern-Suites, die
native Berechtigungsmatrix und Cleanup bestanden. Das öffentliche
Engine-Metadatum bestätigt Hauptversion 16, ProductVersion 16.0.4305.5,
Compatibility Level 160 und Linux.
Der Quellstand des vollständigen Release-Gates enthält den OPS-009-Vertrag.
Ein einzelner testspezifischer PASS-Marker für Vertrag 123 wurde nicht exportiert.
Der OPS-009-Status ist `IMPLEMENTED_ACTIONS_GATE`; das Gate schließt den dokumentierten OpenScope. Der Lauf qualifiziert weder die vollständige native
Drei-Versionen-Matrix noch weitere Produktverträge.

PR #471 wurde mit vier bestandenen Head- und drei bestandenen Main-Prüfungen
integriert. Sein tatsächlicher Scope ist die native SQL-Server-2022-
`FULL_RELEASE`-Abnahme von OPS-009 auf Quellcommit
`abb2324168e725583edcd22f3fa670c2c2ac5dab`, einschließlich 34 Kern-Suites,
nativer Berechtigungsmatrix und Cleanup. Der [Evidenznachweis](OPS009_Empty_Inventory_Runtime_Evidence_2026-09-19.md)
bindet Ziel, Compatibility Level, fehlenden Einzelmarker und Grenzen; daraus
folgt keine native Drei-Versionen-Matrix.

Schritt 34 konkretisierte den ersten Rang-17-Slice im [Dossier für ein sichtbares RLS-/Masking-Inventar](../Architecture/RLS_and_Masking_Inventory_Dossier.md). Schritte 35–38 integrieren das begrenzte read-only-V1 regulär über [PR #473](https://github.com/gecompat/SQL_Server_Analyze/pull/473). Das Modul liefert 15 Parameter und sieben Resultsets für caller-sichtbare Policy-, Predicate- und Masked-Column-Katalogmetadaten. Predicate- und Masking-Expressions, geschützte Tabellenwerte, effektive Berechtigungen sowie Gesundheits- und Enforcement-Aussagen bleiben ausgeschlossen.

Der SQL-Server-2025-Funktionslauf [40534609883](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40534609883) bestand den vollständigen Release-Scope einschließlich 139 exakt einmal ausgeführter Verträge, CL170, Deployment, Berechtigungs-/Regexfällen, Standalone-Execution-Plan und Containercleanup. Der erfolgreiche SQL-stdout wurde unterdrückt; ein separat exportierter PASS-Marker-Transcript für Vertrag 139 liegt nicht vor. Der quellgebundene Laufzeit-PASS bleibt belegt. Eine kontrollierte Timeout-Probe wurde nicht ausgeführt; es erfolgte keine zusätzliche native Qualifikation auf SQL Server 2019 oder 2022. Alle acht Head-Prüfungen und alle fünf Main-Prüfungen bestanden.

Schritt 36 integriert über [PR #474](https://github.com/gecompat/SQL_Server_Analyze/pull/474) die statischen Bindungen für native Ergebnismengen 905; alle vier Head- und drei Main-Prüfungen bestanden. Schritt 37 integriert über [PR #475](https://github.com/gecompat/SQL_Server_Analyze/pull/475) den begrenzten CurrentRequests-Timeoutvertrag mit eigenem temporärem DDL, 1.000-ms-Timeout und Reset auf 0; acht Head- und fünf Main-Prüfungen bestanden. Dieser Vertrag belegt nicht die ursprüngliche Ursache eines früheren Blockers.

Die 13 Head-CI-Kandidaten für RLS einschließlich Wiederholungen bleiben als kompakte Fehlerhistorie erhalten: zwei veraltete Zählstände, Legacy-Lock-/Fixture-/Batch-/Schemafehler, statische 950-/Predicate-ID-, TABLE-Aggregat- und Modulstatuszählungsbefunde sowie getrennte Cleanup- und Frameworkfixturefehler; die einzelne Ursache wird nicht weiter abgeleitet. Schritt 38 gleicht Status und Evidenz ab und lässt den Coverage-Validator ausschließlich die explizit belegten Teilstatuswechsel von DEPRECATION_BREAKING_CHANGE und RLS_DYNAMIC_MASKING auf PARTIAL_PRODUCT_FUNCTION an den vorhandenen Mindestumfang anrechnen. Die Reifematrix bleibt PLANNED; eingeschränkte Katalogsicht ist dauerhaft AVAILABLE_LIMITED/partial. Klassifikation, Agent-Proxies, MSDTC und Legacy-Mirroring bleiben eigenständige offene Themen. Der Schritt-39-Stand zu MSDTC (DISTRIBUTED_TRANSACTIONS) ist im [Inventardossier](../Architecture/MSDTC_Distributed_Transaction_Inventory_Dossier.md). Der SQL-sichtbare Slice ist implementiert und als PARTIAL_PRODUCT_FUNCTION eingestuft; Der SQL-2025-Head-Lauf 40555564808 qualifizierte Commit 51c20d073ac0faceef3fad0fb7485f1b4c6e8178; Vertrag 140 lief genau einmal in Phase 7. Die separate Dokumentationsprüfung im CI1 deckte die lokal korrigierte Source-Closure-Erwartung 202 statt 203 auf; der aktuelle Head- und Integrationsstatus wird in den [Livechecks von PR #479](https://github.com/gecompat/SQL_Server_Analyze/pull/479) nachverfolgt. Externe DTC-Infrastruktur und positive native Distributed-Commit-Evidenz bleiben offen. DATABASE_MIRRORING ist der nächste getrennte WI-0010-Kandidat; eine Registryvergabe folgt nach dem Dossier gemäß bestehendem Prozess.

## Abgeschlossen: fünf SSIS-Paketwellen vom 25. Oktober 2026

Der Benutzer hat fachliche Paketsichten, objektbezogene Regeln, belegte
Modellherkunft und Paketversionsbindung, Design-/Laufzeitkorrelation und eine
ausdrücklich optionale SQL-Metadatenprüfung zur autonomen Umsetzung freigegeben.
Parser, Komponentenprofile und Lineage bleiben in Toolbelt; Analyze bleibt ohne
SQL CLR eigenständig nutzbar. Konsistente Entwicklungsstände dürfen nach
unabhängigem Review und den vorgeschriebenen Gates regulär per PR nach
`origin/main` gemergt werden. Diese Freigabe betrifft die fünf genannten Wellen
und ihre notwendige Integration, keine sonstigen pausierten Entwicklungsaufträge.

Die fünf freigegebenen Wellen sind integriert. Dieser Abschlusscheckpoint
ändert ausschließlich den Auftragsstatus; er beginnt keine neue fachliche
Welle und setzt die acht fachlichen PRs sowie verbrauchte Review- und
Nativebudgets nicht zurück.

Der [Austauschvertrag](../../../Documentation/Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)
führt den fachlichen Rahmen. Toolbelt PR #409 ist integriert. Analyze PR #423
ist als `0cf2ddf21e6f7e916276635342cb925c303f9717` integriert; sein Baum ist
identisch zum grün geprüften Head. Der automatische Main-Nachlauf ist ein
getrennter Nachweis; sein funktionaler Lauf 40146327300 ist ebenfalls grün.

Der endliche Arbeitsumfang besteht aus fünf fachlichen Wellen und der
vorhandenen Basisintegration, mit höchstens acht fachlichen PRs insgesamt.
Je Welle arbeiten ein Implementierer und höchstens ein unabhängiger Reviewer;
ein Folgeauftrag betrifft ausschließlich konkrete Befunde an geänderten Inputs.
Welle 3 besitzt zusätzlich einen begrenzten unabhängigen Check und einen
konkreten Befundfolgecheck der neu erforderlichen 950-Validatorausnahme. Die
lokale Vertrauensentscheidung benötigt committierte Metadaten statt NOLOCK.
Diese zusätzliche Frage entstand erst im statischen Gate; sie öffnet keinen
weiteren Produktreview.
Ein zusätzlicher begrenzter Integrationscheck prüft ausschließlich die
zusammengeführten Wellen 4/5 und den neu benötigten nativen Consumer-Test.
Auslöser sind die gemeinsamen Append-Schnittstellen und die ausdrückliche
Freigabe eines frischen SSISDB-Labs; geschlossene Produktbefunde werden nicht
erneut geprüft. Ein konkreter Cleanupbefund des nativen Tests ist mit drei
I/O-isolierten Gegenproben und einem Befundfolgecheck geschlossen. Die erste
echte Ausführung lieferte anschließend einen neuen fachlichen Befund zur
unterschiedlichen SSISDB-Paket-/Ausführungspfadwurzel. Genau ein begrenzter
Review dieser neuen Zuordnungsregel mit höchstens einem konkreten Folgecheck
ist zusätzlich vorgesehen; dies öffnet keine allgemeinen Reviewschleifen.
Ein Checkpoint folgt nach jeder integrierten Welle. Weitere Reviews, breite
Native-Versionsmatrizen und unveränderte Testwiederholungen benötigen einen
konkreten Auslöser. Verlässliche Token- und Kostenmessung liegt nicht vor.

1. Fachliche Paketsichten: als PR #425 nach vollständiger Head-CI regulär
   integriert (`9d0b018bc3a589e7ba20ae45e53ce425e2d94651`). Head- und
   Mergebaum sind identisch. Der gesonderte Main-Nachlauf 40149167584
   besteht ebenfalls. Lokal sind 79 Prüfungen und der unabhängige Review mit einem
   begrenzten Folgecheck abgeschlossen. Der mechanische Mergekonflikt erhielt
   den separaten Statistikdiagnoseauftrag aus PR #424 unverändert.
2. Objektbezogene Regeln: PR #426 ist nach vollständiger Head-CI als
   `9b301bca191b472b79d8cff5b100b37b1c7a40aa` integriert. Head-/Mergebaum
   sind identisch; Main-Nachlauf 40150237356 besteht. Lokal sind 83 Prüfungen,
   74 statische Validatoren sowie unabhängiger Review und ein Folgecheck
   abgeschlossen; zwei Abwesenheitsbefunde sind geschlossen.
3. Herkunft und Paketversionsbindung: PR #427 ist als
   `9adf33367a6adc775fefb3058486b0dded696146` integriert; Head- und Mergebaum
   sind identisch. Main-Nachlauf 40153793970 besteht. Ein optionaler lokaler Adapter
   qualifiziert einen unabhängig freigegebenen Hostsnapshot und registriert
   das konkrete validierte Modell über separate ALTER-Autorität. Native
   Prüfung bindet exakten JSON-String, Originalbytes, Build und Laufzeitgrenze.
   Der lokale SQL2025-Linux-Harness besteht 87 Prüfungen mit tatsächlichem
   Windows-Hostsnapshot, reinen EXECUTE-Rechten, abgewiesenem verändertem
   Modell und Eigentums-/Cleanup-Gegenfällen. Ein unabhängiger Review und ein
   Folgecheck schließen vier Adapter-/Testbefunde. Head-CI 40151017257
   besteht im zweiten Versuch. Nach erfolgreicher SSIS-Prüfung scheiterte der
   erste Versuch mit Lock-Timeout 1222 in der unveränderten Rechteprüfung von
   Current Sessions. Nach bestätigtem Containercleanup wurden ausschließlich
   die fehlgeschlagenen Jobs einmal begrenzt wiederholt; Produkt und Oracle
   blieben unverändert. Der zusätzliche 950-Guard-Review und sein konkreter
   Folgecheck sind ohne offene Befunde abgeschlossen. Die übrige lokale
   statische Suite besteht; der ursprüngliche einzige 950-Befund ist durch
   die eng gebundene Ausnahme mit positiven/negativen Selbsttests geschlossen.
4. Design-/Laufzeitkorrelation: PR #428 ist nach vollständiger Head-CI
   40162460898 als `e70510b9244ccfacd0703210d5050ee2e07db161` integriert.
   Head- und Mergebaum sind identisch. Der getrennte Main-Nachlauf
   40163073811 besteht ebenfalls. Toolbelt liefert native
   IDs und beobachtete Paketpfade aus demselben Kern. Analyze parst kein DTSX
   und ergänzt keine Lineage; sein Empfänger bindet zwei beobachtete
   Pfadwurzeln und unveränderte restliche Segmente innerhalb desselben Scopes.
   127 SQL2025-Empfängerprüfungen, 19 synthetische Transportprüfungen und drei
   I/O-isolierte Cleanupgegenproben bestehen. Diese Teilprüfungen bleiben von
   der echten Quellenabnahme getrennt.
   Der erste Zugriff auf die alte Quelle scheiterte beim Deployment mit SQL
   15581. Dort wurden nur eigene Ordner entfernt; Schlüssel-/Trust-/Labzustand
   blieben unverändert. Der Benutzer gab danach einen frischen öffentlichen
   SSISDB-Labaufbau frei. SQL2025 und SSIS17 wurden im eigenen Prepared-Run
   durch die Lab-API bereitgestellt. Der erste eigene Paketlauf bestätigte
   SDK-GUIDs, Paketpfade und Originalbytes, offenbarte aber die zu strenge
   Gleichheit von Paket- und Laufzeitwurzel. Der zweite Consumerlauf besteht
   nach Korrektur und unabhängigem Review alle elf nativen Prüfungen:
   echte Ausführung, SDK-Oracle, exakte Bytes, Objektkorrelation, Redeployment,
   Ausschluss falscher aktueller Paketbytes und Gültigkeit früherer Captures
   als zeitgebundene Evidenz. Eigene Consumerobjekte und die Analyze-Testdatenbank
   sind nachgewiesen entfernt; private Evidenz bindet fünf aktuelle Quelldateien
   ohne Abweichung. Die beiden frischen Consumerläufe bleiben verbraucht.
   Registrierungs-, Cleanup- und BIN2-Befunde sind mit jeweils konkretem
   Folgecheck geschlossen. Die erste Head-CI 40159105545 bleibt an ihren
   damaligen Stand gebunden. Ein Backslashliteral des Fixtureautors wurde
   für das Datenschutzgate gleichwertig umgeschrieben; acht Codecgegenproben
   bestätigen dieselben Werte. Die endgültigen Required Checks bestehen.
   Toolbelt PR #411 ist nach grüner Head-CI als
   `626283a51a569442e5a0cfb455fdf59e9be608d7` integriert; der Mergebaum ist
   identisch. Main-Nachläufe 40159164066 und 40159164077 bestehen.
   Der Benutzer will die neue SSISDB-Umgebung für weitere SSIS-Implementierung
   ausdrücklich behalten. Sie bleibt als bewusst persistenter Testbestand
   bereit; der Heartbeat darf sie nicht automatisch entfernen. Je Consumerlauf
   werden ausschließlich dessen eigene Objekte nachgewiesen bereinigt.
   Ein dauerhafter privater Environmentverweis und der hashgleiche qualifizierte
   Hostsnapshot liegen außerhalb von Git im lokalen Anwendungsdatenbereich.
   Der Verweis enthält keine Zugangsdaten; aktuelle Zugriffe verwenden weiter
   die gebundenen öffentlichen Lab-APIs.
5. SQL-Metadatenprüfung: PR #429 ist nach vollständiger Head-CI als
   `fb89385376573cd6e3188beef2fd03f7de388bba` integriert. Head- und Mergebaum
   sind identisch; funktionale Head-CI 40159405306 besteht. Die Basis ist Welle 3.
   Der SQL2025-Harness besteht 126 Prüfungen einschließlich RAW9/all15,
   nativer TABLE-Schemaparität, paketgebundener Spaltenzuordnung, vollständiger
   Unique-Key-Sätze und eingeschränkter Metadatensichtbarkeit. Parser, Typen-
   interpretation und Lineage bleiben in Toolbelt. Der unabhängige Review
   ist ohne materielle Befunde abgeschlossen; 74 statische Validatoren,
   Datenschutz- und Stilgate bestehen. Der separate Main-Nachlauf
   40159950842 besteht ebenfalls. Welle 5 benötigt keine SSISDB- oder CLR-Installation.

Der angeforderte 30-Minuten-Heartbeat dient ausschließlich als letzte Instanz
für Leerlauferkennung. Er startet keine parallele Umsetzung, setzt keine Budgets
zurück und wiederholt keine semantische Arbeit an unveränderten Blockern.
Nach Abschluss der fünf Wellen beginnt er keine weitere Entwicklung.
Der auf Benutzerwunsch erhaltene Testbestand erteilt keinen neuen
Entwicklungsauftrag und wird nicht durch einen Timer entfernt.

## SSIS-Welle 6: iterationsgebundene Ausführungskorrelation

Nach Abschluss der fünf Paketwellen hat der Benutzer diesen zusätzlichen
begrenzten Umfang ausdrücklich freigegeben. Die vorhandene SSISDB-Umgebung
wird weiterverwendet; eine zweite Provisionierung und eine Änderung am
Lab-Produkt gehören nicht zum Auftrag. Ein Implementierer verantwortet die
zwei gekoppelten Liefer-PRs für Toolbelt und Analyze. Ein unabhängiger Review
mit einem begrenzten Folgecheck ist abgeschlossen; ein Befund zu exakten
JSON-Pflichtschlüsseln wurde korrigiert und durch fünf Gegenfälle abgesichert.

Toolbelt PR #420 ergänzt ausschließlich den optionalen Identitätssidecar
1.1.0 mit zentral klassifizierter Iterationsrolle. Analyze verwendet diese
Rolle in seinem neuen Opt-in, erhält jede Statistikinstanz und ergänzt
`executionObjectSummary` sowie `executionCoverage`. Die bisherigen Exporte
und Standardschemata bleiben erhalten. Parser, Komponentenprofile und Lineage
werden nicht nach Analyze kopiert. Die
[Anleitung](../../../Documentation/Analysis_Guides/Procedures/USP_SsisPackageModelAnalysis.md#iterationsgebundene-ausführungskorrelation)
beschreibt Vorbereitung, Ausgabe und Aussagegrenzen.

Die lokale Abnahme auf Windows SQL2025 bestand getrennt mit Basic und Verbose,
jeweils 47 Assertions mit drei For- und zwei Foreach-Instanzen, nativer
Schema-/Ausgabeparität, tatsächlichem Redeployment und nachgewiesener
Bereinigung eigener Consumerobjekte. Die erfolgreiche Foreach-Fixture nutzt
zwei konstante XML-Knoten. Frühere Item-Enumerator-Fixtures bleiben bereinigte
Fehlversuche und sind kein Nachweis einer allgemeinen Enumeratorqualifikation.
Der native Testbestand und seine privaten Belege bleiben außerhalb von Git.
Der SQL-Empfänger bestand den bisherigen Capturevertrag und 30 neue
synthetische Iterationsfälle. Toolbelt bestand 97 gemeinsame Kernorakel,
Framework Full21 und die inkrementelle Konsistenzprüfung mit 46 gekoppelten
Tests. Das versionierte Adapterinstallationsskript wird aus den kanonischen
Quellen mitgeführt. Required Checks am aktuellen PR-Head und die erforderlichen
Main-Gates bleiben Voraussetzung des regulären automatischen Mergewegs.

Die SSISDB-Umgebung bleibt ausdrücklich erhalten. Neue Entwicklung beginnt
nur mit einem weiteren konkreten Auftrag; Kindpaket-/Ereignishandlerbindung,
vertiefte Lineage und allgemeine Laufvergleiche sind hier nicht freigegeben.

## Separater Auftrag: STAT-DOMINANT-Fehlerdiagnose (54901)

### Abgeschlossen: Diagnose aus PR #424

[PR #424](https://github.com/gecompat/SQL_Server_Analyze/pull/424) ist am
25. Oktober 2026 durch den gesonderten Mergeauftrag regulär als
`17a6ff0298d9cf2b1754e76a8c0786e8402ba72c` in `origin/main` integriert.
Alle sieben Head-Prüfungen bestehen auf
`e8113f0b5486fcaabe8c6b0a0e747b4f927139d2`, einschließlich der
[funktionalen Head-CI 40147540255](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40147540255)
im ersten und einzigen Versuch. Beide Durchgänge desselben unabhängigen
Reviewers sind ohne offene Befunde abgeschlossen; der konservativ gebuchte
Reviewaufwand beträgt zusammen vier aktive Minuten.

Die vier automatischen Main-Workflows für Commitnachrichten, Datenschutz,
Dokumentation und [funktionale Abnahme 40148210140](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40148210140)
bestehen jeweils im ersten Versuch auf dem Merge-Commit. Die funktionale
Abnahme umfasst Deployment-Regression, Test 175 mit acht Fachfällen und zwölf
synthetischen Diagnoseproben sowie das Functional Gate auf SQL Server 2025/CL170.
Head- und Merge-Tree sind identisch; die Nachweise bleiben an diese Revisionen
gebunden und werden nicht auf spätere Main-Stände übertragen.

Der Umsetzungsumfang beträgt drei Dateien mit 196 hinzugefügten oder gelöschten
Handzeilen. Verbraucht sind zwei Offlineblöcke, zwei Reviews, ein gebündelter
Korrekturpass und eine funktionale Head-Abnahme. Der erste Offlineblock brach
am privaten UTF-8-Lesehelfer ab; der zweite besteht nach dessen Korrektur und
der ergänzten Gegenprobe für widersprüchliche native Fehlernummern. Beim
Mergeabschluss war der eigene Checkout sauber auf Main synchronisiert;
der eigene lokale und Remote-Feature-Branch sind entfernt.

Der Diagnoseauftrag ist abgeschlossen. Der historische Main-Lauf 40124510785
bleibt fehlgeschlagen und seine Ursache UNKNOWN. Die Diagnoseproben sind
keine Reproduktion dieses Analyzerfehlers. Historische Nachweise und Budgets
bleiben erhalten und geschlossen. Die Dokumentationsnachführung erneuert
keine Lauf-, Review- oder sonstigen Budgets; die übrige autonome Verarbeitung
bleibt pausiert. Der eigenständige Auftrag zu den fünf SSIS-Paketwellen bleibt
durch diese Nachführung unverändert.

### Historische Freigabe und Abnahmegrenzen

Die folgenden Angaben halten den Stand vor Abnahme und Merge fest. Damals
noch ausstehende Gates sind oben mit ihren tatsächlichen Nachweisen abgeschlossen.
Die historischen Angaben sind keine aktuelle Ausführungsfreigabe.

#### Freigegeben: STAT-DOMINANT-Fehlerdiagnose (54901)

Die folgende Freigabe betrifft einen anderen Chat und wird hier unverändert erhalten.

Der Benutzer hat ausschließlich die Diagnose in Test 175 und die Nachführung
dieser Seite sowie des [Diagnosevertrags](Release_Gate_Runbook.md#stat-dominant-diagnose-54901)
freigegeben. Basis ist origin/main `0cf2ddf21e6f7e916276635342cb925c303f9717`;
PR #423 ergänzt gegenüber der Planbasis nur den SSIS-Modellaustausch und
ändert Test 175, seine Statistik-Procedures und die maßgeblichen Regeln nicht.
Der historische Main-Lauf 40124510785 auf `2f5f472b` bleibt fehlgeschlagen;
seine Ursache ist UNKNOWN. Die neue Diagnose qualifiziert keinen Produktfix.

Grenzen sind drei Dateien und 240 hinzugefügte oder gelöschte Handzeilen,
ein Implementierer, höchstens ein gebündelter Korrekturpass vor der einzigen
Head-Abnahme sowie zwei Offlineblöcke. Derselbe unabhängige Reviewer prüft
höchstens zweimal mit insgesamt 20 aktiven Minuten. Test 175 behält seine
acht Fachfälle und erhält zwölf synthetische Diagnoseproben. Die einmalige
Head-Abnahme auf SQL Server 2025/CL170 umfasst die bestehende Deployment-
Regression, Test 175 und die erforderlichen statischen PR-Prüfungen.

T0 ist 2026-10-25T00:25:23Z. Höchstens 60 aktive Minuten einschließlich Review
und Koordination sowie zwei Stunden Gesamtzeit gelten; die Gesamtfrist ist
2026-10-25T02:25:23Z. Nach 30 aktiven oder 60 gesamten Minuten folgt ein
Kontrollpunkt. Offene Reviewbefunde, zusätzliche Dateien oder Prüfblöcke,
CI-Fehler und Grenzüberschreitungen stoppen die Lieferung ohne Wiederholung.
Die Lieferung endet mit einem geprüften offenen PR. Merge, Main-Nachlauf,
weitere Engines, Release-/ZIP-, Paket-, SDK- und Providerläufe sind ausgeschlossen.
Historische Nachweise und Budgets bleiben geschlossen; die übrige autonome
Verarbeitung bleibt pausiert. Die Offline- und Head-Abnahme sind noch ausstehend.

## Integriert: SSIS-001-Pipeline-Phasenbeginnmeldungen (PR #421); Main-Abnahme offen

[PR #421](https://github.com/gecompat/SQL_Server_Analyze/pull/421) ist am
24. Oktober 2026 durch den gesonderten Mergeauftrag regulär als
`2f5f472bffab254d6b98a8f0ed72faf04b772455` in `origin/main` integriert.
Beide Durchgänge desselben unabhängigen Reviewers sind mit zusammen sieben
aktiven Minuten ohne offene Befunde abgeschlossen. Alle sieben Head-Prüfungen
bestehen auf `3547bc29b38cf570e720ea19f4a3d42aa1cb3745`, einschließlich der
[funktionalen Head-CI 40122884037](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40122884037)
im ersten und einzigen Versuch mit dem vollständigen SQL2025-Gate und Test 211.
Head- und Merge-Tree sind identisch.

Die automatischen Main-Workflows für Commitnachrichten, Datenschutz und
Dokumentation bestehen jeweils im ersten Versuch auf dem Merge-Commit.
Der [funktionale Main-Nachlauf 40124510785](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40124510785)
ist im ersten Versuch fehlgeschlagen: Der vorhandene Vertrag
`175_P1_Statistics_Runtime_Contract.sql` bricht mit Fehler 54901 und
`P1-Vertrag STAT-DOMINANT fehlgeschlagen.` ab. Die Ursache ist nicht
nachgewiesen. Das Gate beendet sich vor Test 211; dessen Ausführung ist
damit für diesen Main-Nachlauf nicht belegt. Die bestandene lokale und
Head-Abnahme bleibt an ihre ursprünglichen Quellen gebunden und ersetzt
keine erfolgreiche funktionale Main-Abnahme. Der Main-Nachlauf wurde nicht
wiederholt. Seine Diagnose, Korrektur oder Wiederholung benötigt einen
gesonderten Auftrag; die funktionale Main-Abnahme bleibt offen.

Beim Mergeabschluss war Main sauber synchronisiert. Der eigene lokale und
Remote-Branch sind entfernt; der Checkout blieb sauber am Merge-Commit
ohne Arbeitsbranch erhalten. Der Umsetzungsumfang beträgt 15 versionierte
Dateien mit 565 handgeänderten und 162 generierten Adapterzeilen. Verbraucht
sind zwei lokale Prüfblöcke, zwei Reviews, ein gebündelter Korrekturpass,
genau acht Restoreconsumer und eine funktionale Head-Abnahme. Der Korrekturpass
betraf Dokumentation und einen Testkommentar; Produktbytes blieben unverändert.

Die Lieferung und Integration von PR #421 sind abgeschlossen; die fehlgeschlagene
funktionale Main-Abnahme bleibt als offener Befund erhalten. Historische
Nachweise und Budgets bleiben unverändert und geschlossen. Native11/12 bleiben
FAILED_NOT_QUALIFIED, SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION und
WI-0009 GATE-0001 offen. Diese Dokumentationsnachführung erneuert keine Lauf-,
Review- oder sonstigen Budgets und erteilt keine weitere Ausführungsfreigabe.
Die übrige autonome Verarbeitung bleibt pausiert.

### Historische Freigabe und lokale Abnahme

Die folgenden Angaben halten die damalige Freigabe, ihre Grenzen und die
lokale Abnahme unverändert fest. Damals noch ausstehende Review- und Head-Gates
sind oben mit ihren tatsächlichen Nachweisen abgeschlossen; der später
gesondert beauftragte Main-Nachlauf bleibt fehlgeschlagen. Die historischen
Angaben sind keine aktuelle Ausführungsfreigabe.

#### Freigegebener begrenzter SSIS-001-Schritt: Pipeline-Phasenbeginnmeldungen

Der Benutzer hat alle sechs originalbelegten Profile zur begrenzten Umsetzung
und regulären PR-Lieferung freigegeben. Basis ist origin/main
a98dd3d002bc9f9efbc2bff445874aa996df8df6. Der [SSIS-Plan mit Vertragsverweis](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#pipeline-phasenbeginnmeldungen-begrenzte-lieferung-vom-24-oktober-2026)
bindet Position 29, SchemaVersion 10 und die 19-Feld-Menge. VALIDATION nutzt
nur VALIDATE-Kontext, die anderen fünf Phasen nur EXECUTE; es gibt keine
Ausweichregel oder Phasendauer. Weitergeleitete Berichte bleiben eigene Zeilen.

Die begrenzte lokale Abnahme ist auf Windows SQL Server 17.0.5015.4 mit
CL170 und Framework-/Loggingcollation SQL_Latin1_General_CP1_CS_AS bestanden:
40 SUT-Szenarien, 256 Flagkombinationen, zwei Opt-out-Proben, drei getrennte
quellgebundene Stufenfälle und genau acht Restoreconsumer. Duplicate/Miss
liefern 13/13/12; Miss mit Cap 22 liefert 7/7/2. Alle 19 Felder, nativen
Facetten, neun Originalfelder und Callerzustände sind unabhängig geprüft.
Die zwei eigenen Datenbanken sind entfernt; das Inventar ist wiederhergestellt,
Cleanup- und Retentionfehler sind 0. Die Stufen sind keine vollständigen
SUT-Fehlernachweise; nach der exakten Zählerabfrage wurde nur im privaten
Stufenharness eine abgelaufene Deadline gesetzt. Produkt und Test 211 sind
an die privaten Quellenhashes gebunden. Originale und Rohbelege bleiben privat.
Ergebnisreview und eine exakte Head-Abnahme bleiben eigene Liefergates.

Grenzen sind 15 versionierte Dateien, 1000 hinzugefügte oder gelöschte
Handzeilen und zusätzlich 500 generierte Adapterzeilen. Ein Implementierer,
ein gebündelter Korrekturpass, zwei Reviews desselben Reviewers mit zusammen
30 aktiven Minuten, zwei lokale Prüfblöcke, acht Restoreconsumer-Aufrufe und
eine funktionale Head-Abnahme sind die Obergrenzen. Drei aktive Stunden
einschließlich privater Helfer, Vorbereitung, Review und Koordination sowie
fünf Stunden Gesamtzeit gelten ab T0=2026-10-24T18:30:30Z. Die Gesamtfrist
endet 2026-10-24T23:30:30Z. Ein Kontrollpunkt folgt nach 90 aktiven oder
150 gesamten Minuten; ein Neustart setzt Grenzen nicht zurück. Das bestehende
vollständige SQL2025-Gate einschließlich Test 211 bleibt erforderlich.

Fehlende Quellenbindung, offene Reviewbefunde, fehlgeschlagene Abnahme oder
ausgeschöpfte Grenzen stoppen die Lieferung; danach erfolgen nur eigener
Cleanup und Befundübergabe. Eine unverändert fehlgeschlagene CI wird nicht
wiederholt. Neue Paket-/SDK-/Providerläufe, weitere Engines, Labentwicklung,
Merge, Main-Nachlauf und Release-/ZIP-Veröffentlichung sind ausgeschlossen.
Historische Nachweise und Budgets bleiben geschlossen;
die übrige autonome Verarbeitung bleibt pausiert.

## Abgeschlossen: SSIS-001-Final-Commit-Meldungen (PR #419)

[PR #419](https://github.com/gecompat/SQL_Server_Analyze/pull/419) ist am
24. Oktober 2026 als `0ce9fc560c56a559baba258a47e333ca00b92947` regulär in
`origin/main` integriert. Beide Durchgänge desselben unabhängigen Reviewers
sind ohne offene handlungsrelevante Befunde abgeschlossen. Alle sieben
erforderlichen Head-Prüfungen bestehen auf
`4f58d8a1bbb25c82bfc9c78eb88cd5486ef665b7`, einschließlich der
[funktionalen Head-CI 40115832878](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40115832878)
im ersten und einzigen Versuch mit dem vollständigen SQL2025-Gate und Test 210.

Die vier automatischen Main-Workflows für Commitnachrichten, Datenschutz,
Dokumentation und [funktionale Abnahme 40117308159](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40117308159)
bestehen jeweils im ersten Versuch auf dem Merge-Commit. Head- und Merge-Tree
sind identisch. Beim Abschluss war Main sauber synchronisiert; der eigene
lokale und Remote-Branch sind entfernt. Der Checkout blieb sauber am
Merge-Commit ohne Arbeitsbranch erhalten; die App schützt ihn als primären Checkout.

Der Umfang beträgt 15 versionierte Dateien mit 556 handgeänderten und
174 generierten Adapterzeilen. Verbraucht sind zwei lokale Prüfblöcke, zwei
Reviews mit zusammen rund zehn aktiven Minuten, acht Restoreconsumer und
eine funktionale Head-Abnahme. Ein Produktkorrekturpass wurde nicht benötigt.
Der begrenzte Final-Commit-Auftrag ist abgeschlossen.

Historische Nachweise bleiben an ihre ursprünglichen Quellen gebunden;
Native11/12 bleiben FAILED_NOT_QUALIFIED. SSIS-001 bleibt
PARTIAL_PRODUCT_FUNCTION und WI-0009 GATE-0001 offen. Das veröffentlichte
v1.1.2 und sein ZIP bleiben unverändert und enthalten PR #419 nicht.
Diese Dokumentationsnachführung erneuert keine Lauf-, Review- oder sonstigen
Budgets und erteilt keine weitere Ausführungsfreigabe.
Die übrige autonome Verarbeitung bleibt pausiert.

### Historische Freigabe und lokale Abnahme

Die folgenden Angaben halten die damalige Freigabe, deren Grenzen und die
lokale Abnahme unverändert fest. Damals noch ausstehende Liefergates sind
oben mit ihren tatsächlichen Nachweisen abgeschlossen. Die Angaben sind
keine aktuelle Ausführungsfreigabe.

Der Benutzer hat den begrenzten Teilschritt aus Schritt 5 anhand vorhandener
Originale zur Umsetzung und regulären PR-Lieferung freigegeben. Basis ist
origin/main f6a0dd17390ce7250b1013d901920aaee99ad1ba. Der
[SSIS-Plan mit Vertragsverweis](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#final-commit-meldungen-begrenzte-lieferung-vom-24-oktober-2026)
bindet Position 28, SchemaVersion 9, zwei Meldungsprofile und 19 Felder.
Die vier Duplicate-Berichte mit LogIds 58 bis 61 bleiben getrennt erhalten;
Commit-Paare, Dauern und Persistenzgarantien sind ausgeschlossen.

Die begrenzte Abnahme besteht auf Windows SQL Server 17.0.5015.4/CL170 mit
40 synthetischen SUT-Szenarien, 128 Flagkombinationen, zwei Opt-out-Proben,
drei getrennten quellgebundenen Stufenfällen und genau acht Restoreconsumern.
Alle 19 Felder, native Schemafacetten, Ausgabeparitäten und Callerzustände
sind unabhängig geprüft. Neun Originalfelder und das Datenbankinventar bleiben
erhalten; Cleanup- und Retentionfehler sind 0. Die Stufen sind keine vollständige
SUT-Fehlerqualifikation. Neue Paket-/SDK-/Providerläufe sind 0.
Ergebnisreview und exakte Head-CI bleiben eigene Liefergates.

Grenzen sind 15 versionierte Dateien, 1000 hinzugefügte oder gelöschte
Handzeilen und zusätzlich 500 generierte Adapterzeilen. Ein Implementierer,
ein Korrekturpass, zwei Reviews desselben Reviewers mit zusammen 30 aktiven
Minuten, zwei lokale Prüfblöcke und genau eine funktionale Head-Abnahme
bilden die Obergrenzen. Drei aktive Stunden einschließlich Review und
Koordination sowie fünf Stunden Gesamtzeit ab 24. Oktober 2026 18:53:30 Uhr
Wien gelten; Ende spätestens 24. Oktober 2026 23:53:30 Uhr Wien. Nach 90
aktiven oder 150 gesamten Minuten folgt ein Kontrollpunkt. Das bestehende
vollständige SQL2025-Gate einschließlich Test 210 bleibt erforderlich.

Fehlende Quellenbindung, offene Reviewbefunde, fehlgeschlagene Abnahme oder
ausgeschöpfte Grenzen stoppen die Lieferung. Eine unverändert fehlgeschlagene
CI wird nicht wiederholt. Neue Paket-/SDK-/Providerläufe, weitere Engines,
Labentwicklung, Merge, Main-Nachlauf und Release-/ZIP-Veröffentlichung sind
ausgeschlossen. Historische Nachweise und Budgets bleiben erhalten und
geschlossen; die übrige autonome Verarbeitung bleibt pausiert.

## Abgeschlossen: SSIS-001-Zeilenfluss-Durchsatz (PR #417)

[PR #417](https://github.com/gecompat/SQL_Server_Analyze/pull/417) ist am
24. Oktober 2026 als `6dffdb8e67b6f8030f43e54f8d184d67f5bdf0bd` regulär in
`origin/main` integriert. Der Ergebnisreview besitzt keine offenen P1/P2-Befunde.
Alle sieben erforderlichen Head-Prüfungen bestehen auf
`039bf0ae681d3e72efd18ca7db2762bcb183b144`. Die
[funktionale Head-CI 40102707829](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40102707829)
bestand im ausdrücklich freigegebenen zweiten Versuch auf unverändertem Head.
Das vollständige Gate enthält Test 209 mit 36 Fachfällen und 128 Flagkombinationen.
Der [erste SQL-Versuch](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40102707829/job/120897999970)
bleibt fehlgeschlagen: Der TABLE-Export-Timeout 1222 in
202/C012 besitzt weiterhin die Ursache UNKNOWN; elf Diagnosestichproben
erfassten keinen Blocker. Die Wiederholung verbrauchte den zweiten und
letzten Head-Abnahmeplatz und erneuerte keine weiteren Budgets.

Die vier automatischen Main-Workflows für Commitnachrichten, Datenschutz,
Dokumentation und [funktionale Abnahme 40105002784](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40105002784)
bestehen jeweils im ersten Versuch auf dem Merge-Commit. Head- und Merge-Tree
sind identisch; der SQL-Cleanup besteht. Beim Abschluss war Main sauber
synchronisiert; der eigene lokale und Remote-Branch sind entfernt.
Der bisherige Checkout blieb sauber am Merge-Commit ohne Arbeitsbranch
erhalten, weil die App seine Archivierung als primären Checkout ablehnt.

Der begrenzte Durchsatz-Auftrag ist abgeschlossen. Historische Nachweise
bleiben an ihre ursprünglichen Quellen gebunden; fehlgeschlagene lokale
Batches und Native11/12 bleiben FAILED_NOT_QUALIFIED. SSIS-001 bleibt
PARTIAL_PRODUCT_FUNCTION und WI-0009 GATE-0001 offen. Das veröffentlichte
v1.1.2 bleibt unverändert und enthält PR #417 nicht. Diese
Dokumentationsnachführung erneuert keine Lauf-, Review- oder sonstigen
Budgets und erteilt keine weitere Ausführungsfreigabe.
Die übrige autonome Verarbeitung bleibt pausiert.

### Historische Freigabe und lokale Abnahme

Die folgenden Angaben halten die damalige Freigabe, deren Grenzen und die
lokale Abnahme unverändert fest. Damals noch ausstehende Liefergates sind
oben mit ihren tatsächlichen Nachweisen abgeschlossen. Die Angaben sind
keine aktuelle Ausführungsfreigabe.

Der Benutzer hat den begrenzten Durchsatz-Slice anhand vorhandener Originale
zur Implementierung und regulären PR-Lieferung freigegeben. Basis ist
origin/main 7dc190f5cd0eac64e93b6d9bf0208ed98df62552. Der
[SSIS-Plan mit Vertragsverweis](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#zeilenfluss-durchsatz-begrenzte-lieferung-vom-24-oktober-2026)
bindet Position 27, SchemaVersion 8, die 33-Feld-Menge und acht Restoreconsumer.
Die gezielte lokale Restabnahme besteht auf Windows SQL17.0.5015.4/CL170 mit
19 noch offenen SUT-Fällen, allen 128 Flagkombinationen, drei getrennten
quellgebundenen Stufenfällen und genau acht Restoreconsumern. Alle 33 Felder,
nativen Facetten, Ausgaben und Callerzustände sind unabhängig geprüft;
neun Quellwerte und Datenbankinventar bleiben erhalten, Cleanupfehler sind 0.
Die Stufen sind keine vollständige SUT-Fehlerabnahme. Frühere Fehlerbatches
bleiben fehlgeschlagen; die vollständige 36-Fälle-Datei wird in der exakten
Head-CI separat ausgeführt. Ergebnisreview und Head-CI bleiben Liefergates.

Die ursprünglichen Grenzen waren 15 versionierte Dateien, 1400 handgeänderte Zeilen, ein
gebündelter Korrekturpass, zwei Reviews desselben Reviewers mit zusammen
40 aktiven Minuten, zwei lokale Prüfblöcke und höchstens zwei Head-Abnahmen.
Eine zweite Head-Abnahme benötigt einen geänderten Korrekturstand. Vier
aktive Stunden einschließlich Review und Koordination sowie sechs Stunden
Gesamtzeit ab 24. Oktober 2026 14:57:25 Uhr Wien gelten; Ende spätestens
24. Oktober 2026 20:57:25 Uhr Wien. Ein Kontrollpunkt folgt nach zwei aktiven
oder drei gesamten Stunden. Die Testeinbindung aktiviert das bestehende
vollständige SQL2025-Gate. Die Lieferung endet mit dem geprüften offenen PR;
Merge und Main-Nachlauf benötigen einen gesonderten Auftrag.

Direkte Folgefreigaben erlaubten den eng begrenzten Rundungspass, die
Datumsdarstellungs-/UTC-Korrektur und den unabhängig bestätigten Parallelsollsatz
11/31 samt konsistenter Testgenerierung. Dafür gelten insgesamt vier lokale
Prüfblöcke und drei Reviews desselben Reviewers; die übrigen Datei-, Zeilen-,
Head-, Zeit- und Umfangsgrenzen bleiben erhalten. Die Rundungskorrektur
betrifft 17 geänderte Handzeilen im Produkt und den kanonischen Adapter.
Neue Paket-/SDK-Aufrufe und Providerqualifikationen sind 0; weitere Engines,
Labentwicklung und Release-/ZIP-Veröffentlichung bleiben ausgeschlossen.
Bindungsfehler, fehlgeschlagene Originalabnahme, offene Reviewbefunde oder
ausgeschöpfte Grenzen stoppen die Lieferung. Historische Nachweise und
Budgets bleiben unverändert; die übrige autonome Verarbeitung bleibt pausiert.

## Abgeschlossen: SSIS-001-Schreibmengen (PR #415)

[PR #415](https://github.com/gecompat/SQL_Server_Analyze/pull/415) ist am
24. Oktober 2026 als `0e6f0325ecbfb1e984c59045f44ff11909628464` regulär in
`origin/main` integriert. Der Ergebnisreview besitzt keine offenen Befunde.
Alle sieben erforderlichen Head-Prüfungen bestehen auf
`ff79408efdca95156adfd9df8724c6f9e3328536`, einschließlich der
[funktionalen Head-CI 40009169508](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40009169508).
Die vier automatischen Main-Workflows für Commitnachrichten, Datenschutz,
Dokumentation und [funktionale Abnahme 40061402546](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40061402546)
bestehen jeweils im ersten Versuch auf dem Merge-Commit. Head- und Merge-Tree
sind identisch. Beim Abschluss war Main sauber synchronisiert; der eigene
lokale und Remote-Branch sind entfernt, der Worktree ist wiederherstellbar archiviert.

Der begrenzte Schreibmengen-Auftrag ist abgeschlossen. Historische Nachweise
bleiben an ihre ursprünglichen Quellen gebunden; Native11/12 bleiben
FAILED_NOT_QUALIFIED. SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION und
WI-0009 GATE-0001 offen. Das veröffentlichte v1.1.2 bleibt unverändert und
enthält PR #415 nicht. Diese Dokumentationsnachführung erneuert keine Lauf-,
Review- oder sonstigen Budgets und erteilt keine weitere Ausführungsfreigabe.
Die übrige autonome Verarbeitung bleibt pausiert.

### Historische Freigabe und lokale Abnahme

Die folgenden Angaben halten die damalige Freigabe, deren Grenzen und die
lokale Abnahme fest. Sie sind keine aktuelle Ausführungsfreigabe.

Der direkte Benutzer hat die Schreibmengen-Auswertung anhand vorhandener
Originaldaten zur begrenzten Umsetzung und regulären PR-Lieferung freigegeben.
Der [SSIS-Plan mit Vertragsverweis](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#schreibmengen-begrenzte-lieferung-vom-23-oktober-2026)
ergänzt genau ein englisches DTS_I_ROWS_WRITTEN-Profil, Position 26 und eine
21-Feld-Menge mit SchemaVersion 7. Einzelberichte bleiben getrennt; es gibt
keine Addition propagierter Meldungen und keine Commitgarantie.

Basis ist origin/main 2ddf5b341d4253780f299dfa766e2d6135d5de50. Vier bestehende
hashgebundene Originalaufnahmen enthalten 12/16/60/61 Zeilen; die letzten
beiden enthalten jeweils zwei Schreibberichte mit Werten 3/3 und 0/0.
Originale und Bindungen bleiben privat; historische Belege werden nicht auf
neuere Commits umgebunden. Vorbereitungs-/Partial-Cache-Profile bleiben offen.

Grenzen sind 15 versionierte Dateien, 1600 handgeänderte Zeilen, ein gebündelter
Korrekturpass, zwei Reviews desselben Reviewers mit zusammen 40 aktiven Minuten,
zwei lokale Prüfblöcke, genau acht Restoreconsumer und höchstens zwei Head-
Qualifikationen. Ein Main-Nachlauf setzt einen gesonderten Mergeauftrag voraus.
Vier aktive Stunden einschließlich Review und Koordination und sechs Stunden
Gesamtzeit ab 23. Oktober 2026 20:28:55 Uhr Wien gelten; Ende spätestens
24. Oktober 2026 02:28:55 Uhr Wien, Zwischenstand nach zwei aktiven Stunden.
Die Einbindung des Tests aktiviert das vorhandene vollständige SQL2025-Gate.

Der Vertragsreview ist abgeschlossen; Kontextpriorität und Ausschluss nur
der Release-/ZIP-Veröffentlichung sind geklärt. Die begrenzte lokale Abnahme
besteht auf Windows SQL17.0.5015.4/CL170 mit 45 vollständigen synthetischen
Fach-/Grenzfällen, drei getrennten quellgebundenen Stufenfällen, 64 Opt-in-
Kombinationen und genau acht Restoreconsumern. Alle 21 Felder, native Facetten,
Ausgabeparität, Callerzustände und neun Providerwerte sind geprüft; eigener
Cleanup und unverändertes Datenbankinventar sind bestätigt. Neue Paket-/SDK-
Aufrufe sind 0. Ein neuer direkter Vertragslink wird nach statischem Befund
über den bestehenden klassifizierten SSIS-Planpfad geführt. Ergebnisreview
und exakte Head-CI bleiben eigene Liefergates. Bei fehlender Bindung,
fehlgeschlagenem Originalconsumer oder ausgeschöpften Grenzen folgt der Stopp.
Neue Paket-/SDK-Ausführungen, Providerqualifikationen, weitere Engines,
Labentwicklung und Release-/ZIP-Veröffentlichung bleiben ausgeschlossen.
Historische Budgets bleiben geschlossen; übrige Autonomie bleibt pausiert.

## Abgeschlossen: Release v1.1.2

[v1.1.2](https://github.com/gecompat/SQL_Server_Analyze/releases/tag/v1.1.2)
ist seit dem 23. Oktober 2026 um 19:15:59 Uhr Wien veröffentlicht. Tag und
Produkt-ZIP sind an Main-Commit `fe24e7b496d2a1f221dbf44edfe96312dd4ed05a`
gebunden. PR #413 ist darin integriert; sein
[Main-Nachlauf 39975996941](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/39975996941)
bestand. Die historischen Fehlerläufe bleiben fehlgeschlagen und an ihre
ursprünglichen Commits gebunden; ihre Ursachen sind weiterhin ungeklärt.

Der einmalige [Matrixlauf 39986885609](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/39986885609)
bestand auf SQL Server 2019/CL150, 2022/CL160 und 2025/CL170 unter Linux.
Je Engine bestanden 34 Release-Suiten, Berechtigungsprüfung und Cleanup;
auf SQL Server 2025 bestanden zusätzlich die vorgesehenen Regex-, Deployment-,
Erhaltungs-, Snapshot-/Nebenläufigkeits- und Standalone-Verträge. Ein
unabhängiger Abschlussreview blieb ohne Befund. Builds und Plattformgrenzen
stehen im [Release-Nachweis](https://github.com/gecompat/SQL_Server_Analyze/releases/download/v1.1.2/release-evidence.json);
die beobachteten Builds beschränken die Installation nicht auf bestimmte Builds oder CUs.

Die vollständige `SQL_Server_Analyze-1.1.2.zip` enthält sechs fertige Installer
einschließlich des kombinierten Snapshot-/Baseline-Upgrades. Ihre SHA-256 lautet
`eb0944f95b227ddb5af240a3b4b327e09d299aa59033e62d1930f064a9e3045c`.
ZIP, Prüfsummendatei und Nachweis wurden nach Veröffentlichung heruntergeladen
und mit den geprüften Dateien abgeglichen. Der [Releaseabschluss](Release_Gate_Runbook.md#releaseabschluss-v112)
führt Paketbindung und Restbudget zusammen; die
[Installationsanleitung](../../../Documentation/Reference/Installation.md)
beschreibt den Einsatz der fertigen Installer.

Der gesondert freigegebene Restauftrag erlaubte null Repositoryänderungen,
einen CI-ZIP-Bau, einen Matrixdispatch ohne Jobwiederholung und höchstens
einen Abschlussreview von maximal zehn aktiven Minuten. Es galten 45 aktive Minuten
einschließlich Koordination und Review, vier Stunden Gesamtzeit sowie
spätestens der 23. Oktober 2026 um 22:00 Uhr Wien. Paketjob, Enginejobs und
Evidenzjob waren auf 15, jeweils 45 und zehn Minuten begrenzt. Ein Tag,
ein Releaseentwurf und eine Veröffentlichung waren zulässig. Der Restauftrag
ist innerhalb dieser Grenzen abgeschlossen; frühere Budgets wurden nicht erneuert.

Diese nachträgliche Dokumentationsänderung gehört nicht zum veröffentlichten
Quellcommit. Tag, ZIP, Prüfsumme und Release-Nachweis bleiben unverändert;
die beiden Statusdokumente im ZIP enthalten den damaligen Zwischenstand.
Es besteht kein weiterer autonomer Ausführungsauftrag. Die übrige autonome
Verarbeitung bleibt pausiert; Lauf-, Review- und OPS-005-Budgets werden nicht erneuert.

## Historische Freigaben und Sperrstände

Die folgenden Angaben dokumentieren frühere Auftragsstände und Grenzen.
Sie sind keine aktuelle Ausführungsfreigabe; der spätere Releaseabschluss
ist oben getrennt nachgeführt.

### Freigegebener Folge-PR: FIND-CORE-Diagnose

PR #412 ist als `73b9843a8cd799883d1b3d796992133020e38d97` integriert.
Der zweite Head-Lauf `39961104033` bestand auf `e2aa7e56`; der
[Main-Nachlauf 39962487724](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/39962487724)
scheiterte mit 55200 in FIND-CORE. Die verletzte Prüfbedingung und die Ursache
sind unbekannt. `NO_1222` schließt intern abgefangene Modulfehler nicht aus.
v1.1.2 ist unveröffentlicht; native Matrix und endgültiger CI-ZIP-Bau fehlen.

Freigegeben ist ausschließlich die Diagnose in Test 178 samt dieser
Statusnachführung und der [Abnahmebeschreibung](Release_Gate_Runbook.md#find-core-diagnose).
Die Grenze beträgt drei Dateien, 220 hinzugefügte oder gelöschte Handzeilen,
60 aktive Minuten einschließlich Review und Koordination sowie zwei Stunden
Gesamtzeit. Ein Implementierer bearbeitet einen Umsetzungspass und höchstens
einen gebündelten Korrekturpass vor der einzigen Head-Abnahme. Höchstens zwei
gezielte Offlineblöcke und zwei Durchgänge desselben unabhängigen Reviewers
sind zulässig; zweite Durchgänge benötigen geänderte Eingaben oder Befunde.
Die Lieferung endet mit dem geprüften Folge-PR. Merge, Main-Nachlauf,
ZIP-Bau, Release-Matrix und Veröffentlichung sind nicht freigegeben.
Fehler oder Grenzüberschreitung stoppen die Lieferung. Die verbrauchten
Releasebudgets und die ursprüngliche Releasefrist werden nicht erneuert;
die übrige autonome Verarbeitung bleibt pausiert.

### Gestoppte Lieferung: Release 1.1.2

Der Benutzer hat am 23. Oktober 2026 den Releaseplan für v1.1.2 samt enger
ZIP-Ausnahme und festen Grenzen freigegeben. Der Branch beginnt auf
Analyze-Main `e307fea3` einschließlich PR #410 und der OPS-005-Statusnachführung.
Die bereits integrierte TABLE-Timeout-Diagnose wird mit dem vollständigen
Produkt-ZIP und sechs vorbereiteten Installern ausgeliefert. Vertragsversion
`1.24`, Snapshot-Paketversion `1.0.0`/Schema 1 und die Plattformgrenzen bleiben
bestehen. Die [Releaseanleitung](Release_Gate_Runbook.md) führt durch Paketbau,
Abnahme, regulären PR-Merge und Veröffentlichung; der menschliche Download-
und Upgradeweg bleibt in der [Installationsanleitung](../../../Documentation/Reference/Installation.md).

Der Umfang ist auf 25 Dateien und 400 handgeschriebene geänderte Zeilen
begrenzt; nur die beiden kanonischen Adapterdiffs zählen nicht zur Zeilengrenze.
Ein Implementierer bearbeitet einen Umsetzungspass und höchstens drei
gebündelte Korrekturpässe; der letzte betrifft nur Validator und Budgettexte. Ein Reviewer prüft höchstens viermal.
Vier lokale Prüfblöcke mit insgesamt höchstens drei Prüfpaketen, zwei Head-
Qualifikationen, ein Main-Nachlauf, ein endgültiger CI-Paketbau und genau eine
native Linux-Matrix auf SQL Server 2019, 2022 und 2025 bilden die Abnahmegrenze.
Die zweite Head-Qualifikation setzt einen geänderten Korrekturstand voraus.
Die Matrix läuft sequenziell mit höchstens 45 Minuten je Enginejob.

Der erste Head-Lauf `39942902098` auf `ffb8ffa4` scheiterte mit Fehler 1222
im Standalone-Vertrag. Freigegeben ist nun ein zusätzlicher Temp-Setup-Fix
in neun Dateien mit höchstens 200 weiteren Handzeilen und 60 aktiven Minuten
innerhalb der ursprünglichen Gesamtgrenzen. Nur eigene Temp-DDL erhält 100 ms;
die Sperrursache bleibt unbelegt. Genau ein weiterer lokaler Block samt ZIP,
ein Review desselben Reviewers und der zweite Head sind dafür zulässig.
Die ursprüngliche Frist endet am 23. Oktober 2026 um 17:45 Uhr Wien.

Nach 120 Minuten aktiver Bearbeitung einschließlich Review und Koordination
oder fünf Stunden Gesamtzeit beginnt keine neue Arbeit; nach drei Stunden
erfolgt ein Kontrollpunkt. Ein Matrixfehler oder eine offene Daten-/Quellbindung
verhindert die Veröffentlichung. Nach bestandener Abnahme zeigt `v1.1.2` auf
den getesteten Main-Commit; veröffentlicht werden dieselben ZIP-Bytes mit
Prüfsumme und gebundenem Nachweis. Der Abschluss wird beim Release geführt.
Damit endet dieser Auftrag ohne Wiederholungsfreigabe. Die früheren Releases
bleiben unverändert. OPS-005-Windows-Abnahmen und deren verbrauchte Lauf-/
Reviewbudgets werden nicht erneuert. Die übrige autonome Verarbeitung bleibt pausiert.

## Historische Welle: Release 1.1.0

Der Releaseumfang ist auf die Konsolidierung des aktuellen Produktstands,
den Versionskatalog, ein commitgebundenes Produkt-ZIP mit fünf fertigen
Installern und die vorhandene native Linux-Matrix begrenzt. Neue
Fachfunktionen, Änderungen an Diagnose-APIs, Windows-SQL-Läufe und SSIS-Paketausführung
bleiben außerhalb dieses Auftrags. Die übrige autonome Verarbeitung bleibt
pausiert.

Der [Releaseablauf](Release_Gate_Runbook.md) beschreibt Paketbau, Prüfung,
Abnahme und Veröffentlichung. Der menschliche Lesepfad beginnt bei der
[Installationsanleitung](../../../Documentation/Reference/Installation.md);
die aktive Testauswahl bleibt in der
[CI-Teststrategie](../../../Documentation/Quality/CI_Test_Strategy.md).

Die Releasevorbereitung ist über PR #407 als `09060a6d` integriert. Head- und
Main-Gates bestehen; die erste native Matrix ist fehlgeschlagen. Der aktuelle
Korrekturschritt behebt ausschließlich die versionswidrigen Backup-Testoracles
für 2019/2022 und den von Test 198 an Folgetests vererbten NOWAIT-Zustand.
Die ursprünglichen Fehlernachweise bleiben erhalten. Eine neue Matrix prüft
den korrigierten Quellstand und dessen neu gebundenes Produkt-ZIP.

Für diesen Korrekturschritt gelten höchstens zwölf versionierte Dateien, ein PR, ein
Implementierer, ein unabhängiger Reviewer mit höchstens zwei Durchgängen und
ein gebündelter Korrekturpass. Zwei lokale Prüfblöcke, höchstens zwei
Head-Qualifikationen, ein Main-Nachlauf und genau eine native Matrix sind die
Ausführungsgrenzen. Die native Matrix führt maximal einen 45-Minuten-Job je
Engine aus. Nach drei Stunden wird ein Kontrollpunkt erreicht; nach vier
Stunden Gesamtzeit beginnt keine neue Arbeit. Ein Abnahmefehler oder eine
offene Datenschutzgrenze verhindert die Veröffentlichung.

Version und Datum werden vor der Abnahme eingefroren. Tag und Release müssen
auf den getesteten Main-Commit zeigen; das veröffentlichte ZIP bleibt
bytegleich zum abgenommenen Paket. Ein Produktversionswechsel auf 1.1.0
ändert weder die Vertragsversion 1.24 noch die Foundation-Version. Er führt
keine Build- oder CU-Bindung ein. Neue Nachweise werden nicht in historische
CSV-Zeilen zurückgeschrieben.

Sobald `v1.1.0` mit bestandener vollständiger Matrix und gebundenem Produkt-ZIP
veröffentlicht ist und der eigene Branch-Cleanup bei sauberem `origin/main`
abgeschlossen ist, ist diese Welle beendet. Dieser Eintrag erteilt danach
keine Wiederholungsfreigabe. Die übrige autonome Verarbeitung bleibt bis zu
einem neuen ausdrücklichen Auftrag pausiert.

## OPS-005-Quellenabgleich vom 23. Oktober 2026

Der ausschließlich lesende Quellenabgleich bestätigt Analyze-Main
[`59e6c9cc8e786828bc710ca6963121511aedb07a`](https://github.com/gecompat/SQL_Server_Analyze/commit/59e6c9cc8e786828bc710ca6963121511aedb07a)
und Lab-Main
[`2423ac75d7b07d29adbb63a2c218a6669db8363c`](https://github.com/gecompat/SQL_Server_Lab/commit/2423ac75d7b07d29adbb63a2c218a6669db8363c).
Lab entspricht damit dem übergebenen Referenzstand von PR #828. Dieser
Abgleich enthält keine neue native Ausführung.

Die [Windows-Providerabnahme](../../../Documentation/Quality/OPS005_Linked_Server_Evidence_2026-10-22.md#ops-005-linked-server)
bleibt am Analyze-Stand `7a578c85` mit Lab `1095f5ee` bestanden und über
PR #403 als `2874675a` integriert. Belegt sind 194 Installationsbatches,
fünf Analyzerfälle, eine native Provider-Vorprobe mit Fehler 7403,
Callerzustand und vollständiger eigener Cleanup. Dieser begrenzte Nachweis
ist abgeschlossen und wird weder erneut als offen geführt noch auf neuere
Commits umgebunden.

Die [Lab-Validierungsstrategie](https://github.com/gecompat/SQL_Server_Lab/blob/2423ac75d7b07d29adbb63a2c218a6669db8363c/Documentation/Quality/LOCAL_VALIDATION_STRATEGY.md#windows-prepared-collation-und-editierbarer-intentstandard)
bindet die Windows-Prepared-Collationabnahme mit 27 Prüfungen an `77fcf951`.
Die getrennte [HRESULT-Fehlerpfadabnahme](https://github.com/gecompat/SQL_Server_Lab/blob/2423ac75d7b07d29adbb63a2c218a6669db8363c/Documentation/Quality/LOCAL_VALIDATION_STRATEGY.md#windows-aktivierung-unter-hyper-v-native-hresult-fehlerpfadabnahme)
belegt drei kontrollierte Fälle mit 32 Prüfungen auf `44b63129`. Sie enthält
keinen echten `Activate`-Aufruf und qualifiziert weder Produktions-DHCP noch
externen Egress oder einen tatsächlichen Aktivierungsdienstausfall. Der
ursprüngliche historische Aktivierungsfehler bleibt ungeklärt.
[PR #828](https://github.com/gecompat/SQL_Server_Lab/pull/828) führt diesen
Status mit Dokumentations-, Privacy- und Pflicht-CI-Nachweisen nach; seine
Integration ist keine erneute native Abnahme.

Die Windows-Fixture wählt `SQL_Latin1_General_CP1_CS_AS` ausdrücklich.
Der editierbare interaktive Lab-Standard ersetzt diese Auswahl nicht;
Windows ohne Auswahl behält sein bisheriges Verhalten. Eigene Datenbank,
deren Collation und CL170 bleiben getrennte Postconditions. `NotRequested`
mit `Denied` attestiert keinen aktiven Windows-Lizenzzustand.
`AVAILABLE_EMPTY` und `[]` belegen nur einen leeren sichtbaren Bestand.
Docker, Podman und Hyper-V behalten getrennte Nachweise.

Die Kombination Analyze `59e6c9cc` mit Lab `2423ac75` ist nativ
`NOT_EXECUTED`. Analyzer, Windows-Worker, Vorbereiter und Provider-Fixture
sind gegenüber dem bestandenen Analyze-Stand unverändert. Die spätere
Lab-HRESULT-Korrektur betrifft den von dieser Fixture nicht angeforderten
Aktivierungspfad. Die geänderte TABLE-Ausgabe wird von den fünf
`NONE`-Analyzerfällen nicht aufgerufen. Daraus ergibt sich derzeit kein
fachlicher Zwang zur Wiederholung; eine aktuelle gemeinsame native
Qualifikation wird damit nicht behauptet.

Eine ausdrücklich gewünschte Wiederholungsabnahme benötigt einen gesonderten
Ausführungsauftrag: frischer eigener Run, neue private Vorbereitung und
Reservierung, exakte Quellbindungen, unveränderte fünf Analyzerfälle samt
nativer Vorprobe, Callerzustandsprüfungen und vollständiger eigener Cleanup
gemäß dem [Windows-Lesepfad](../../../TestLab/README.md#fehlenden-windows-provider-prüfen).
Assertions werden nicht zur Kompensation fehlender Evidence abgeschwächt.
Sieben Windows-Runs und neun Reviewprüfungen bleiben verbraucht; diese
Dokumentationsnachführung erneuert weder Lauf- noch Reviewbudgets.
SQL-, Analyzer- und Providerläufe sind nicht freigegeben. Die übrige
autonome Verarbeitung bleibt pausiert.

## Erhaltener Stand: OPS-005-Lesepfad und Nachweishistorie

OPS-005 ist über PR #403 als `2874675a` qualifiziert in `origin/main`
integriert. Vier Head-Gates und drei Main-Gates bestehen jeweils im ersten
Versuch; Head- und Merge-Tree sind identisch. Main ist sauber synchronisiert,
eigener lokaler und Remote-Branch sind entfernt und der Worktree ist
wiederherstellbar archiviert. Sieben Windows-Runs und neun Reviewprüfungen
bleiben verbraucht; weitere native OPS-005-Ausführung ist nicht freigegeben.

Foundation 1.25.0 aus dem kanonischen Source-Commit `9e1b9974` ist über
PR #404 als `13727913` qualifiziert in `origin/main` integriert. Vier Head-
und drei Main-Gates bestehen jeweils im ersten Versuch; Head- und Merge-Tree
sind identisch. Main ist sauber synchronisiert, beide eigenen Branches sind
entfernt und der eigene Worktree ist wiederherstellbar archiviert. Die
[aktuelle Bewertung](../Architecture/Foundation_1_25_Upgrade.md) erfasst das
eine neue Feature, menschliche Lesepfade, getrennte KI-Steuerung und die
Bewertung des tatsächlichen Verarbeitungsaufwands. Bestehende Produkt-,
Datenschutz-, Lizenz- und Registrierungsverträge bleiben erhalten. Diese
Übernahme enthält keine SQL- oder Lab-Ausführung.

Der [menschliche Einstieg in Metadata](../../../Metadata/README.md) ist über
PR #405 als `0d40d4c1` qualifiziert integriert. Vier Head- und drei Main-Gates
bestehen im ersten Versuch; Head- und Merge-Tree sind identisch. Eigene
Branches sind entfernt und der Worktree ist wiederherstellbar archiviert.

Der nächste bereits geplante Dokumentationsschritt trennt im öffentlichen
[Linked-Server-Lesepfad](../../../TestLab/README.md#ops-005-linked-server)
die Fallauswahl, Voraussetzungen, Ergebnisinterpretation und Cleanuphilfe
von der [datierten Nachweischronologie](../../../Documentation/Quality/OPS005_Linked_Server_Evidence_2026-10-22.md).
Der bisherige Abschnitt bleibt dort als gekennzeichnete historische Abschrift
erhalten; andere TestLab-Abschnitte und bestehende Anker bleiben unverändert.
Produktquellen, Runner, Assertions, Schemas und Laufzeitfreigaben werden
nicht geändert. Nach statischer Lesepfadprüfung und unabhängigem Review
folgen aktuelle Head-Gates, reguläre Integration, Mainprüfung und eigener
Cleanup. Weitere SQL- oder Lab-Ausführung ist damit nicht freigegeben.

### Dokumentationsaltlasten und Wiederaufnahme

| Betroffener Umfang | Verantwortliche Rolle | Konkreter Wiederaufnahmetrigger und Grenze |
|---|---|---|
| Einstieg in `Metadata/` | Maintainer der Metadatenverträge | Mit PR #405 qualifiziert abgeschlossen; die weitere Pflege folgt Änderungen an den beschriebenen Verträgen. Keine neuen Schemas, Registrytypen oder SQL-Läufe. |
| Öffentlicher OPS-005-Lesepfad im TestLab-README | Maintainer des TestLab-Vertrags | Gegenstand der aktuellen Dokumentationswelle: Anleitung und datierte Nachweise getrennt abnehmen. Native Belege und verbrauchte Grenzen bleiben erhalten; keine neue Runtimefreigabe. |
| Aktuelles Fortsetzungsdokument | Maintainer der Projektplanung | Nächste strukturelle Planungsbereinigung: erhaltene Historie in einen ausdrücklich historischen Nachweis verlagern und betroffene Anker beziehungsweise Pfadkonsumenten erhalten. Keine Umbenennung dauerhafter Kennungen und keine Reaktivierung abgeschlossener Wellen. |

Das Upgrade darf mit diesen konkret geplanten Altlasten abgeschlossen werden;
eine vollständige Dokumentationskonformität wird nicht behauptet. Der
abgegrenzte Metadaten-Dokumentationsschritt folgt auf die qualifizierte
Foundation-Integration und ihren bestätigten eigenen Cleanup. SQL-, Lab- und
Veröffentlichungsgrenzen werden dadurch nicht erneuert.

## Erhaltene Diagnosehistorie: OPS-005-Provider-Negativfall

Die folgenden offenen Integrationsschritte und Freigaben beschreiben die
jeweiligen damaligen Zwischenstände. Der oben dokumentierte Abschluss über
PR #403 und der [Quellenabgleich vom 23. Oktober 2026](#ops-005-quellenabgleich-vom-23-oktober-2026)
sind für die heutige Einordnung maßgeblich; die historischen Angaben
erneuern keine Ausführungs- oder Reviewbudgets.

Der vorherige Stream ist über [PR #399](https://github.com/gecompat/SQL_Server_Analyze/pull/399)
als `7359cf48` integriert. Lokale Abnahme, unabhängige Reviews, Head-CI und
Main-Nachlauf bestehen; der Merge-Tree entspricht dem geprüften Head.
Main ist synchron und sauber. Der eigene Worktree ist wiederherstellbar
archiviert, die beiden integrierten eigenen Arbeitszweige sind entfernt.

Der aktuelle Windows-Providerfall ist am Analyze-Stand `7a578c85` mit Lab-Main
`1095f5ee` nativ abgenommen. Alle fünf Analyzerfälle und eine Provider-Vorprobe
bestehen einschließlich vollständigem eigenen Cleanup. Produktquellen,
Vertrag 120, Linux-Adapter und Reifeflags bleiben unverändert. Der aktuelle
Lieferstand ergänzt den begrenzten Windows-Runner und seine Eingaben;
Head-CI, reguläre Integration und eigener Branch-Cleanup stehen noch aus.
Die folgenden Diagnose- und Planungsstände erhalten frühere Fehlversuche
und ihre damaligen Aussagegrenzen.

Die nächste Reifewelle untersucht einen synthetischen nicht verfügbaren
OLE-DB-Provider. Der lokale Entwurf `3eec56c4` ergänzt Vertrag 120 und seinen
kanonischen Updateadapter um Providername, Kollisionsschutz, einen sicheren
Default, native Vorprobe 7302/7403 und gebundene SOURCE_UNAVAILABLE-Evidenz
mit identitätsgebundenem Erfolgs- und Fehlercleanup. Der unabhängige erste
Review sowie Adapterprüfung mit acht Darstellungsfällen, Maturity-,
Datenschutz-, Stil- und Commitprüfung bestehen.

Die eine lokale SQL-Server-2025-Probe auf CL170 besteht Installation und
Smoke. Vertrag 120 scheitert anschließend mit 54868, State 1, am neuen
kombinierten Default-Inventaroracle, noch vor der Provider-Vorprobe. Die
Default-JSON-Werte, Status, Partialität, ErrorOut und die tatsächliche neue
Provider-Katalogzeile wurden nicht erfasst. Der Negativzustand ist nicht
nachgewiesen; die genaue Soll-Ist-Abweichung bleibt UNKNOWN. Ein Provideralias
oder eine Linux-Plattformursache werden nicht als festgestellt ausgewiesen.
Die Einstiegsprobe bleibt FAILED_NOT_QUALIFIED. Der eigene Container ist
identitätsgebunden entfernt; ein Providererfolg wird nicht behauptet.

Der nicht qualifizierte Testentwurf bleibt in der lokalen Git-Historie und
privat mit Quellbindung erhalten. Vertrag 120 und die generierten Adapter
sind im aktuellen Lieferstand wieder bytegleich mit dem qualifizierten
Main `7359cf48`. Produktprocedures, öffentliche Verträge und Reifeflags
bleiben unverändert. Gegen Main verbleibt nur dieses Status- und Planungsdokument;
ein neuer PR wurde nicht veröffentlicht.

Der begrenzte Einstieg mit einem nativen Block und zwei befundgebundenen
Prüfungen eines unabhängigen Reviewers ist ausgeschöpft. Beide Prüfungen
sind abgeschlossen; die zweite bestätigt die Nichtqualifikation und den
sicheren Folgezustand ohne weitere SQL-Ausführung.

Der Benutzer hat anschließend genau einen weiteren lokalen Diagnoseblock
und einen unabhängigen Review freigegeben. Dieser Diagnoseblock besteht
Installation und die getrennte Vorprüfung von Engine 17 sowie Server-,
Master- und TempDB-Collation auf SQL Server 2025 mit CL170. Nach dem
synthetischen `sp_addlinkedserver` findet der Einstieg keine Katalogzeile
unter dem angeforderten Namen und bricht mit `DIAG_CREATED_ROW_MISSING`
ab. Der anschließende Cleanup-Guard meldet `DIAG_FIXTURE_IDENTITY_LOST`.
Der Rückgabecode der Anlage und alternative neue Katalogzeilen fehlen.
Der Defaultaufruf wurde durch diese zu frühe Vorprüfung nicht erreicht;
54868 wurde in diesem Lauf nicht erneut ausgeführt. Die genaue Ursache
bleibt UNKNOWN. SQL-Fixturecleanup ist nicht belegt; die identitätsgebundene
Entfernung des eigenen Containers ist bestätigt.

Der zusätzliche native Block ist verbraucht. Der korrigierte private
Einstieg erfasst den Anlagerückgabecode, native Fehler und Katalogstände
vor und nach der Anlage. Er führt auch bei fehlender Fixture genau einen
Defaultaufruf ohne Remote-Opt-ins aus und erfasst dessen Outputs sowie die
Oracleprädikate getrennt. Fehlende Fixturevoraussetzungen bleiben als solche
ausgewiesen. SQL-Cleanup erfordert eine neue, eindeutig eigene Identität;
unerwartete Zeilen werden nicht übernommen. Der zusätzliche unabhängige
Review ist ohne offene materielle
Befunde abgeschlossen. Seine beiden Treiberbefunde zur Git-Quellbindung und
zu abschaltbaren Ownershipprüfungen sind behoben. Sieben ausschließlich
simulierte Treiberfälle bestehen mit normalem und optimiertem Python; sie
ersetzen keine native Prüfung.

Der anschließend ausdrücklich freigegebene einzelne Diagnoseblock führt
diesen unveränderten Einstieg auf SQL Server 2025, Version 17.0.5015.4,
mit CL170 und der vorgeprüften case-sensitiven Server-/Master-/TempDB-Collation
aus. Installation und Beobachtungserfassung bestehen. `sp_addlinkedserver`
liefert `1` ohne Exception; vor und nach der Anlage existiert ausschließlich
die lokale Katalogzeile mit `server_id=0`. Eine Providerfixture entsteht
nicht. Genau ein Defaultaufruf liefert `AVAILABLE_EMPTY`, JSON `[]`,
Partialität `0` und NULL für beide Fehleroutputs. Locktimeout, Sessionoptionen
und Transaktionszahl bleiben erhalten. Sechs der dreizehn getrennten
Prädikate scheitern an der Erwartung einer vorhandenen Providerzeile und
des globalen Status `AVAILABLE`. Es erfolgt kein SQL-Drop ohne eigene
Identität. Der abschließende Katalog entspricht dem Ausgangsstand; der
eigene Container ist identitätsgebunden entfernt.

Damit ist ein Fehlerpfad des Entwurfs belegt: Die nicht geprüfte
Anlagerückgabe lässt das Defaultoracle trotz fehlender Fixture laufen.
Die erfassten Werte würden dort 54868 auslösen. Der leere Default ist in
diesem Lauf vertragsgemäß; ein Produktfehler ist damit nicht belegt.
Die internen Gründe für Anlagerückgabe `1` und die nicht erfassten Werte des
ursprünglichen Fehlversuchs bleiben UNKNOWN. Microsoft dokumentiert
`1` als [Fehlerrückgabe der Anlage](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-addlinkedserver-transact-sql?view=sql-server-ver17)
und Nicht-SQL-Server-Datenquellen als [unter Linux nicht unterstützt](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-editions-and-components-2025?view=sql-server-ver17#unsupported-features-and-services).
Diese Plattformgrenze ersetzt keinen Nachweis des internen Fehlerpfads.

Ein privater Korrekturvorschlag prüft Anlagerückgabe und exakte Katalogidentität
vor dem Defaultoracle und meldet fehlende Voraussetzungen gesondert.
Die bisherigen Orakel und Cleanupbedingungen bleiben darin unverändert.
Dieser Vorschlag besitzt noch keine native Abnahme und keinen eigenen
unabhängigen Review; er ist nicht in Vertrag 120 oder seinen Adapter
übernommen. Der zuletzt freigegebene Diagnoseblock ist abgeschlossen und
verbraucht. Für die eigentliche Provider-Negativabnahme fehlt eine geeignete,
gesondert freigegebene Fixture. Weitere unveränderte Linux-Wiederholungen
werden daraus nicht abgeleitet. Zusätzliche Plattformen und fremde
Labressourcen bleiben außerhalb des Umfangs; die Providervarianz bleibt
unvollständig. Der Benutzer hat anschließend ausschließlich die konkrete
Planung einer gesondert freizugebenden OPS-005-Fixture ausgewählt. Dieser
Planungsschritt umfasst keine SQL-, Lab- oder weitere Reviewausführung.
Nach Abschluss der Planung hat der Benutzer den nachstehend begrenzten
Umsetzungsschritt gesondert freigegeben; dessen aktuelle Zulassung steht am
Ende dieses Abschnitts.

### Geplanter Windows-Fixturepfad für OPS-005

Der vorgeschlagene nächste Umsetzungsschritt prüft den fehlenden Provider
auf genau einer eigenen Windows-SQL-Server-2025-Instanz. Windows ist ein
Kandidat für die Anlage der synthetischen Registrierung; deren tatsächlicher
Erfolg bleibt bis zur Vorprüfung NOT_EXECUTED. Microsoft beschreibt
[Providerfehler erst beim Zugriff](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/linked-servers/ole-db-provider-errors).
Daraus wird kein garantierter Anlageerfolg für die konkrete Fixture abgeleitet.
Der Nachweis betrifft ausschließlich den Provider-Negativfall; erfolgreiche
Verbindungen mit weiteren Providern bleiben offen.

#### Plattform und Zuständigkeit

Die lesend geprüfte Revision `c175c2cf` von `SQL_Server_Lab` besitzt bereits
einen begrenzten [Hyper-V-Prepared-Image-Pfad](https://github.com/gecompat/SQL_Server_Lab/blob/c175c2cf858a969183d0cbf281416510eabd7503/Providers/HyperV/README.md)
für Windows Server 2025 und SQL Server 2025 Enterprise Developer.
Vorgeschlagen wird höchstens ein neuer Run mit einer frischen eigenen VM aus
einem vorhandenen, hashgebundenen `SQL_PREPARED_SEALED`-Artifact. Das
Ressourcenprofil soll auf vier vCPUs und acht GiB festen RAM begrenzt sein;
der vorhandene Host muss zusätzlich seine vorgeschriebene Reserve und den
Speicherplatz für die eigene differenzierende VHDX nachweisen. Ein passendes
Artifact, seine gültige Lizenzlaufzeit, die Hostkapazität und ein konkreter
Run sind derzeit nicht gebunden. Ihre Verfügbarkeit bleibt UNKNOWN.

Die erteilte Umsetzungsfreigabe umfasst den neuen Run und dessen vollständigen
eigenen Cleanup. Allgemeine Bereitstellung und Lifecycle bleiben
bei `SQL_Server_Lab`. Imagebau, Downloads, Lizenzaktivierung mit zusätzlichem
Netzzugang, neue Switches, Reconcile fremder Ressourcen und Änderungen am
Lab-Repository gehören nicht zu diesem Vorschlag. Es werden keine
zusätzlichen Daten-VHDX oder persistenten Data-Root-Laufwerke angelegt.
Der Test verwendet einen vorhandenen isolierten oder ausschließlich
hostgebundenen Netzpfad mit PowerShell Direct; NAT, LAN und externe NICs
gehören nicht zum Umfang.
Fehlt eine Voraussetzung, endet der Schritt vor der betroffenen Mutation.
Eine dadurch erforderliche allgemeine Lab-Erweiterung benötigt den
[gesonderten Änderungsvorschlag](../../CONTINUATION_GUIDE.md#lab-zentralisierung).

Der fachliche Runner soll den vorhandenen
[Windows-Skripttransport](https://github.com/gecompat/SQL_Server_Lab/blob/c175c2cf858a969183d0cbf281416510eabd7503/Public/Invoke-SqlServerLabScript.ps1)
über `Invoke-SqlServerLabScript`, explizite RunId, InstanceId und StateRoot,
`WindowsAuthentication` und `KeepConnection` verwenden. Die Ausführung bleibt
im gebundenen Gast; ein SQL-Auth-Fallback oder eine automatische Wiederholung
nach Versand ist ausgeschlossen. Vor späterer Ausführung werden die dann
maßgeblichen Lab-Anweisungen und die verwendete Revision erneut geprüft.
Der vorhandene OPS-005-Adapter verlangt `container-linux` und erhält durch
diesen Plan keine Windows-Capability. Der neue manuelle Analyze-Vertrag wird
getrennt von Vertrag 120 und dessen Linux-Adapter umgesetzt und vor seiner
Anlage gemäß Artefaktvertrag eingeordnet.
Produktprocedure, öffentliche Parameter und Statuscodes sowie Reifeflags
bleiben unverändert. Ein neuer Produktfehler erweitert diesen Umfang nicht
automatisch.

#### Voraussetzungen vor der Providerprobe

Vor SQL-Mutationen müssen RunId, ScopeId, InstanceId, VMId und die eigenen
Ressourcenpfade eindeutig gebunden sein. Der Gast muss bereits SQL_READY_RUN,
gültige Lizenzvoraussetzungen, Major-Version 17 sowie
`SQL_Latin1_General_CP1_CS_AS` für Server, Master und TempDB bestätigen.
ProductVersion, Edition und Plattform werden tatsächlich erfasst. Es dürfen
keine fremden Benutzerdatenbanken und keine Linked Server vorhanden sein.
Windows-Authentifizierung muss im isolierten Ziel die benötigten Rechte
besitzen; eine fehlende Berechtigung führt zum Abbruch statt zu einer
Rechteausweitung.
Der vorhandene Windows-Aktivierungsintent muss ausdrücklich
`Strategy=VerifyOnly` und `EgressPolicy=Denied` erhalten. Eine erforderliche
Aktivierung blockiert damit; `NotRequested` ersetzt keinen Lizenznachweis.

Der Runner erstellt genau eine eigene, markierte Frameworkdatenbank auf
CL170 und installiert eine privat gebundene Standalonefassung aus den
kanonischen Quellen. Der bestehende Standalonebuilder bleibt unverändert;
SQLCMD-Includes werden nicht als Unterstützung des Windows-Transports
vorausgesetzt. Quellhashes, installierte Definition und ABI des Analyzers
werden vor der Probe gebunden.

Ein pro Versuch neu erzeugter synthetischer Providername dient ausschließlich
diesem Run. Der Zielname und `example-provider.invalid` bleiben synthetisch.
Es werden weder ein Provider installiert noch Treiberregistrierungen verändert.
`sp_addlinkedserver` muss Rückgabecode `0` liefern und genau eine neue
`sys.servers`-Zeile mit passendem Namen, Provider, Produkt, Datenquelle und
`is_linked=1` erzeugen. Server-ID, `modify_date`, vorheriger Katalogstand und
Erstellungsintent werden privat erfasst.
Fehlt diese Voraussetzung, bleibt die Probe nicht qualifiziert und erreicht
keinen Consumer-Erfolgsstatus. Die ursprünglichen Fehlerbelege bleiben erhalten.

#### Fachlicher Abnahmeblock

Nach gültiger Anlage sind höchstens fünf gezielte Analyzer-Aufrufe und genau
eine unabhängige native `sp_testlinkedserver`-Vorprobe vorgesehen. Alle
Analyzer-Aufrufe verwenden JSON und NONE; Caller-Locktimeout, Sessionoptionen
und Transaktionszahl werden je Aufruf vor und nachher verglichen.

| Schritt | Schalter Connectivity/HighImpact | Erwartung |
|---|---|---|
| Sicherer Default | `0/0` | Genau die eigene Zeile, global `AVAILABLE`, Partialität `0`, Zeile `NOT_EXECUTED`/`AVAILABLE` und leere Fehleroutputs. |
| Nur HighImpact bestätigt | `0/1` | Derselbe sichere Inventarvertrag ohne aktivierten Verbindungstest. |
| Zweite Bestätigung fehlt | `1/0` | Global `AUTHORIZATION_REQUIRED`, Partialität `1`, Zeile `AUTHORIZATION_REQUIRED`/`AVAILABLE` und NULL als Fehlernummer. |
| Native Vorprobe und doppeltes Opt-in | `1/1` nach der Vorprobe | Die Vorprobe muss 7302 oder 7403 liefern. Der Analyzer muss dieselbe eigene Zeile als `FAILED`/`SOURCE_UNAVAILABLE`, global `AVAILABLE_LIMITED` und partiell liefern; Fehlernummer und `EvidenceLimit` müssen zur erfassten nativen Fehlernummer passen. |
| Default nach SQL-Cleanup | `0/0` | Keine Linked Server, global `AVAILABLE_EMPTY`, JSON `[]`, Partialität `0` und leere Fehleroutputs. |

Unmittelbar vor Vorprobe und doppeltem Opt-in muss weiterhin ausschließlich
die gebundene eigene Linked-Server-Zeile vorhanden sein. `@MaxZeilen` begrenzt
die Verbindungstests nicht. Timeout, Berechtigungsfehler, eine erfolgreiche
Vorprobe oder ein anderer Providerfehler erfüllen den Negativnachweis nicht.
Ein unerwarteter Befund beendet den fachlichen Block ohne automatische
Korrektur oder Wiederholung. Ein verlorener Transportreply bleibt UNKNOWN.

#### Cleanup, Nachweise und vorgeschlagene Freigabegrenze

Erfolgs- und Fehlerpfad dürfen nur die erneut gegen Server-ID, `modify_date`,
Namen, Provider, Produkt, Datenquelle und Erstellungsintent bestätigte Fixture
entfernen. Nach dem Drop werden Rückgabecode und Abwesenheit geprüft.
Unerwartete oder veränderte Identitäten bleiben unberührt. Die eigene
Frameworkdatenbank wird nur mit unverändertem Marker entfernt. Anschließend
erfolgt der [Lab-Cleanup](https://github.com/gecompat/SQL_Server_Lab/blob/c175c2cf858a969183d0cbf281416510eabd7503/Public/Remove-SqlServerLab.ps1)
mit expliziter RunId und StateRoot; Parent-Images und andere Runs bleiben
erhalten. Teilfehler bleiben als Recoverybedarf erhalten. SQL-Fixturecleanup,
Datenbankcleanup und Ressourcencleanup werden getrennt nachgewiesen.

Rohlogs, Zugangsdaten, Run- und Hostidentitäten bleiben privat. Eine spätere
Repositoryevidenz enthält nur bereinigte synthetische Aussagen mit Commit,
Engine, Version, Plattform, CL, Umfang, Ergebnis und Cleanupgrenzen.

Zur gesonderten Freigabe wird ein kohärenter Umsetzungsschritt mit einem
Implementierer, einem unabhängigen Reviewer mit höchstens zwei
befundgebundenen Prüfungen, höchstens einem neuen vorbereiteten Lab-Run und
genau einem nativen Windows-Abnahmeblock vorgeschlagen. Der fachliche
Gastaufruf erhält höchstens 120 Sekunden; Installation und Vorprüfung
erhalten jeweils höchstens 300 Sekunden. Der vorhandene Lab-Lifecycle muss
seine eigenen begrenzten Warte- und Recoveryverträge erfüllen. Jeder
begonnene Versuch zählt auch bei früherem Abbruch; ältere Budgets bleiben
unverändert verbraucht.

Vor Lieferung sind betroffene Offlineprüfungen, die gezielte native Abnahme
und aktuelle grüne Head-Gates erforderlich. Vorgeschlagen werden höchstens
ein PR-CI-Versuch und ein Main-Nachlauf gemäß kanonischer Impact-Auswahl.
Der reguläre Merge, Main-/Treevergleich, Synchronisierung und die Bereinigung
ausschließlich eigener integrierter Branches und Worktrees schließen einen
qualifizierten Slice ab.
Ein Fehlschlag oder eine fehlende Plattformvoraussetzung erlaubt keine
weiteren Versuche. Dieser Ausführungsumfang ist gesondert freigegeben;
Änderungen am Lab-Repository bleiben ausdrücklich ausgeschlossen.

#### Zulassung vor der Runanlage

Die lesende Quellenprüfung an `SQL_Server_Lab` Revision `c175c2cf` findet
eine fehlende Voraussetzung. Der öffentliche Prepared-Pfad reicht
`instance.collation` nicht an die Unattended-Provisionierung weiter.
`Complete-HyperVLabSqlImage` besitzt weder einen Collationparameter noch
`/SQLCOLLATION` in seinen Setupargumenten. Auch SQL_READY_RUN bestätigt dort
keine Collation. Das bestehende Manifestfeld allein gewährleistet daher
nicht die freigegebene Server-/Master-/TempDB-Collation. Eine passende
Eigenschaft eines vorhandenen Images ist bislang nicht belegt; weder eine
konkrete CI-Collation noch generelle Ungeeignetheit aller Images wird behauptet.

Der unabhängige Reviewer bestätigt diesen Befund in der ersten von höchstens
zwei Prüfungen. Die getrennte vollständige SQL-Installationskette unterstützt
Collation, ersetzt aber den freigegebenen Prepared-Pfad nicht. Externe
Aktivierung lässt sich dagegen mit dem vorhandenen ausdrücklichen
VerifyOnly-/Denied-Intent sperren; dafür ist keine Lab-Erweiterung erforderlich.
Es wurden kein neuer Run, kein nativer SQL-Block und kein CI-Versuch begonnen.
Die zweite Reviewprüfung sowie VM-, SQL-, PR- und Main-Budgets bleiben
ungenutzt. Die fehlende Collationbindung wird nicht durch eine abgeschwächte
Vorprüfung, private Setupaufrufe oder eine Neuinstallation umgangen.

Der kleinste Änderungsvorschlag für `SQL_Server_Lab` ist gesondert
freizugeben:

| Entscheidungspunkt | Vorgeschlagener begrenzter Umfang |
|---|---|
| Fehlende Funktion | Die ausdrücklich ausgewählte Instanzcollation muss den öffentlichen Prepared-/Unattended-Pfad bis SQL `CompleteImage` erreichen und danach tatsächlich geprüft werden. |
| Analyze-Anwendungsfall | Die eigene OPS-005-Providerfixture benötigt die bereits freigegebene case-sensitive Server-/Master-/TempDB-Kombination auf Windows SQL Server 2025. |
| Zuständigkeit | SQL-Instanzbereitstellung ist allgemeine Lab-Funktion. Analyze behält Fixture, fachliche Assertions und deren Cleanup. |
| Kleinste Schnittstelle | Das bestehende Collationintent wird in der Prepared-Kette erhalten und validiert an den von Microsoft dokumentierten CompleteImage-Parameter weitergegeben. Es entsteht kein zweiter Setupweg und keine nachträgliche Collationreparatur. |
| Providerwirkung | Die Korrektur bleibt in der Windows-/Hyper-V-Prepared-Kette; Docker, Podman, fremde Runs und bestehende SQL-Instanzen werden nicht verändert. |
| Kompatibilität und Prüfung | Ohne ausdrücklich gewählten Intent bleibt das bisherige Setupverhalten erhalten. Offlinegegenproben prüfen unveränderte Defaults, exakte Weitergabe, ungültige Werte, falsche VM-/Run-Bindung und fehlende Replayautorität. Der bereits reservierte eigene Windows-Run kann anschließend die tatsächlichen drei Collations und die Analyze-Fixture gemeinsam nachweisen; das ist noch NOT_EXECUTED. |
| Freigabe und gemeinsames Budget | Eine zusätzliche Lab-Änderungsfreigabe fehlt. Vorgeschlagen wird ein zusammenhängender Schritt in beiden Repositories mit der noch freien zweiten Prüfung desselben Reviewers und den unveränderten, bisher ungenutzten VM-/SQL-Grenzen. Für das zusätzliche Repository wären genau ein weiterer PR-CI-Versuch und ein weiterer Main-Nachlauf nötig; frühere Budgets werden nicht zurückgesetzt. |

Microsoft führt `/SQLCOLLATION` unter den
[CompleteImage-Parametern](https://learn.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt?view=sql-server-ver17#complete-image-parameters).
Die Quellkorrektur und ihr erforderlicher lokaler beziehungsweise nativer
Nachweis müssen vor Veröffentlichung und regulärer Integration vollständig
vorliegen. Bis zur gesonderten Entscheidung endet die Umsetzung vor der
Runanlage; das Lab-Repository bleibt unverändert.

#### Wiederaufnahme nach Integration der Lab-Korrektur

Die Collationkorrektur ist über
[Lab-PR #815](https://github.com/gecompat/SQL_Server_Lab/pull/815) unter
`c56e3783` in `origin/main` integriert. Der Merge-Tree entspricht dem
geprüften Head `8b0f4fd3`. Das ausgewählte
[PR-Gate](https://github.com/gecompat/SQL_Server_Lab/actions/runs/39578182570)
besteht auf diesem Head einschließlich der statischen Windows-/Ubuntuprüfungen
und der vorgesehenen Provider-Smokes. Dieser Nachweis bestätigt keine drei
tatsächlichen Windows-Collations; die eigene native Analyze-Abnahme bleibt
erforderlich. Dieser Chat hat das Lab-Repository nicht verändert.

Der Benutzer hat klargestellt, dass sein zwischenzeitlicher Stopp ausschließlich
die Übernahme von Lab-PR #815 betraf. OPS-005 wird innerhalb der bestehenden
Freigaben fortgesetzt. Geeignete SQL-2025-Prepared-Images sind vorhanden.
Ihre Integrität und die konkreten Run-, Lizenz- und Hostvoraussetzungen werden
vor beziehungsweise während der gebundenen Bereitstellung geprüft. Die
OOBE-Injektion benötigt einen erhöhten Runner. Der Benutzer hat dessen
Bereitstellung ausgewählt; ein fest gebundener privater Starter bestätigt
inzwischen das Administratortoken und dieselbe Benutzeridentität.
Eine neue VM oder ein nativer SQL-Block wurde noch nicht begonnen.

Die Analyze-Vorbereitung ergänzt einen separaten manuellen Windows-Fall unter
`TestLab/Scenarios/OPS-005/provider-unavailable.sql` und zwei zugehörige
PowerShell-Einstiege. Der Vorbereiter führt kein SQL aus. Er teilt die aus
171 kanonischen Quellen erzeugte Standalonefassung an vollständigen
Quellgrenzen in zwei Eingaben innerhalb der Transportlimits. Die erste Eingabe
enthält keine temporären Tabellen außerhalb gespeicherter Module; die beiden
Seed-Temptabellen liegen einschließlich ihrer Verbraucher in der zweiten
Eingabe. Datenbankkontext und erforderliche Sessionoptionen werden je Eingabe
gesetzt. Die kanonischen Produktquellen und der bestehende Linux-Adapter
bleiben unverändert.

Der native Runner verlangt einen sauberen, ausdrücklich gebundenen Analyze-
und integrierten Lab-Stand, private geprüfte Eingaben, den gleichen Hostbenutzer,
ein vorhandenes Prepared-Image sowie einen bestehenden internen Switch.
Eine persistierte Reservierung sperrt die erneute Runanlage. Die vorhandenen
Grenzen für fünf Analyzer-Aufrufe, eine native Provider-Vorprobe, Laufzeiten
und eigenen Cleanup bleiben erhalten. Ein verlorener Reply erzeugt keinen
Replay und keinen Erfolgsnachweis. Zehn simulierte Runnerfälle und drei
Offlinefälle des privaten erhöhten Starters bestehen. Der unabhängige
Abschlussreview ist mit Prüfung 2/2 ohne offene Befunde abgeschlossen.
PowerShell-, SQL-Parser- und simulierte Ablaufprüfungen sind Offlineprüfungen;
native Abnahme, Analyze-PR-CI und Main-Nachlauf sind noch offen.

Die erhöhte Vorprüfung des sauberen Analyze-Stands `1bde42da` scheitert vor
Imagezulassung und Runanlage mit `OPS005_HOST_RUNTIME_BUSY`. Die globale
Lab-Laufsperre ist auch in begrenzten lesenden Nachprüfungen belegt. Eine
anschließende native Owner-Abfrage identifiziert einen PowerShellprozess
mit der Elternkette `Runner.Worker.exe` und `Runner.Listener.exe` als Halter.
Die Zuordnung zum laufenden
[Podman-CI-Job von Lab-PR #816](https://github.com/gecompat/SQL_Server_Lab/actions/runs/39604195474/job/119236194763)
wird aus dieser Prozesskette und den sekundengleich passenden Prozess- und
Schrittstartzeiten abgeleitet. Die Abfrage öffnet die Sperre ausschließlich
zum Lesen ihrer Owner-Metadaten; sie wartet nicht auf die Sperre und gibt
sie nicht frei. Reale Prozesskennungen und Beobachtungsbelege bleiben privat.
Eine eigene Runreservierung, VM, Datenbank und aktive
Netzwerklease wurden nicht angelegt. Bis zu dieser Vorprüfungsgrenze lagen
neue Runs, native Abnahmeblöcke, Analyzer-Aufrufe und Provider-Vorproben
jeweils bei null. Beide unabhängigen Reviewprüfungen sind verbraucht;
PR-CI und Main-Nachlauf bleiben reserviert.

Die weitere Fortsetzung prüft die Lab-Laufsperre lesend. Nach einem kurzen
freien Fenster zwischen CI-Jobs werden die privaten Eingaben aus dem sauberen
Analyze-Commit `884c40a2` neu gebunden. Ein weiterer CI-Prozess hält die Sperre
vorübergehend erneut; der anschließend freie eigene Worker erwirbt sie regulär.
Der fehlgeschlagene Vorprüfungsbeleg bleibt erhalten; fremde Prozesse oder
Ressourcen werden weder beendet noch verändert.

#### Windows-Abbruch am Aktivierungsintent

Der einzige freigegebene Windows-Run startet mit vier vCPUs und acht GiB
festem RAM aus dem vorhandenen Prepared-Image. Parenthash und Schreibschutz,
Hostkapazität, Quellenbindung und OOBE bestehen. Vor SQL Setup meldet die
gebundene Gastprüfung jedoch `ACTIVATION_REQUIRED` mit `LicenseStatus = 2`.
Der ausgewählte `VerifyOnly`-/`Denied`-Intent blockiert deshalb mit
`WINDOWS_ACTIVATION_VERIFY_ONLY`. Die Inventareinstufung `EVALUATION_VALID`
belegt keinen bereits aktivierten Child-Gast. Eine abgelaufene Evaluation
oder ein Analyzerfehler ist damit nicht nachgewiesen. SQL-Readiness,
Engine-Build, Compatibility Level, tatsächliche Collations und Providerfälle
bleiben für diesen Run unbelegt.

Die Ursache liegt im für diesen Workload zu streng ausgewählten
Aktivierungsintent. Der bestehende
[Lab-Vertrag](https://github.com/gecompat/SQL_Server_Lab/blob/c56e378382cf47ea8fe3b5a1cf520f46ce3be541/Documentation/HowTo/WINDOWS_ACTIVATION.md)
erlaubt `NotRequested` mit `Denied`-Egress für einen konkreten Workload ohne
Aktivierungsbedarf. Die lokale Linked-Server-Providerprüfung verwendet keine
Windows-Aktivierungsfunktion. Der vorbereitete Analyze-Runner fordert deshalb
keine Windows-Aktivierung mehr an und attestiert keinen aktiven Lizenzstatus.
Die Inventarzulassung des vorhandenen Images sowie sämtliche SQL-,
Collation-, Ownership- und Cleanupprüfungen bleiben erhalten. Das
Lab-Repository wird nicht geändert.

Zehn simulierte Runnerfälle bestehen mit dem korrigierten Intent. Ein reines
Offline-Replay der vorhandenen Lab-Entscheidungsfunktion gegen den gespeicherten
Gastbefund bestätigt zusätzlich die bisherige Blockierung und den neuen
`WINDOWS_ACTIVATION_NOT_REQUESTED`-No-op ohne Netzwerkmutation. Das sind zwei
Offlinefälle und kein weiterer Gast- oder SQL-Aufruf. Der korrigierte Intent
besitzt noch keinen nativen Nachweis und keinen zusätzlichen unabhängigen Review.

Der gebundene Fehlercleanup entfernt den eigenen Run einschließlich VM und
Child-Disk. Es bleibt keine aktive eigene IPAM-Lease; Parenthash und
Schreibschutz sind unverändert. Eine Frameworkdatenbank oder Providerfixture
wurde nicht angelegt. Der aktuelle Verbrauch dieser Windows-Welle beträgt
einen von einem freigegebenen Run, einen von einem nativen Abnahmeblock und
zwei von zwei Reviewprüfungen. Analyzer-Aufrufe und Provider-Vorproben liegen
bei null; diese Teilmengen erlauben keinen zweiten Abnahmeblock. PR-CI und
Main-Nachlauf sind unverändert reserviert.

Der Benutzer hat für die vorbereitete Intentkorrektur genau einen zusätzlichen
unabhängigen Abschlussreview und höchstens einen weiteren eigenen Windows-Run
mit einem nativen Abnahmeblock freigegeben. Der zusätzliche Umfang bleibt bei
vier vCPUs, acht GiB festem RAM, vorhandenem Prepared-Image, höchstens fünf
Analyzer-Aufrufen und einer Provider-Vorprobe. Die bestehenden Laufzeit-,
Netzwerk- und Cleanupgrenzen bleiben erhalten. Der zusätzliche Review ist
ohne offene Befunde abgeschlossen. Der danach begonnene Run ist im folgenden
Abschnitt dokumentiert. Der ungenutzte PR-CI-Versuch und
Main-Nachlauf einschließlich regulärer Integration nach grünen Gates und
eigenem Cleanup bleiben reserviert. Alle bisherigen Fehlversuche und
Reservierungen bleiben bestehen. Lab-Codeänderungen, Imagebau, Downloads
und externe Netzanbindung bleiben ausgeschlossen.

#### Zusatzrun endet an der Lab-Collation-Gastprobe

Der zusätzliche Windows-Run bindet den sauberen Analyze-Stand `ef84b574`
und Lab `c56e3783`. Der korrigierte `NotRequested`-/`Denied`-Intent passiert
die bisherige Blockadestelle. OOBE, SQL CompleteImage, WMI und die
Konfiguration des Hostzugriffs werden erreicht; der gespeicherte
SQL-Completionstatus bleibt jedoch `COLLATION_PENDING`. Die anschließende
Collationverifikation endet mit `HYPERV_SQL_COLLATION_QUERY_FAILED`.

Das private native Transkript und ein gezielter Offlinevergleich belegen
eine konkrete Parameterbindungsabweichung in Lab:
[`Test-LabHyperVSqlCollationRuntimeEvidence`](https://github.com/gecompat/SQL_Server_Lab/blob/c56e378382cf47ea8fe3b5a1cf520f46ce3be541/Private/HyperVSqlCollation.ps1)
übergibt `-StateRoot` an
[`Invoke-HyperVPowerShellDirect`](https://github.com/gecompat/SQL_Server_Lab/blob/c56e378382cf47ea8fe3b5a1cf520f46ce3be541/Providers/HyperV/HyperVProvider.ps1).
Die tatsächliche Transportsignatur besitzt diesen Parameter nicht. Ihr
gesondertes `BuildStateRoot` gehört zur Build-Lane und ist kein belegter
Ersatz für die Run-Lane. Der Fehler tritt vor dem Gastblock der
Collationabfrage auf. Eine tatsächliche Collationabweichung oder ein
Analyzerfehler ist damit nicht nachgewiesen.

Zwei geschlossene Offlinefälle mit dem unveränderten produktiven ParamBlock
bestätigen die Zurückweisung von `StateRoot` und die Bindung ohne diesen
Parameter an einen ausschließlich geschlossenen Testbody. Der produktive
Transportbody, Gastaufrufe und SQL werden dabei nicht ausgeführt. Diese
Diagnose qualifiziert noch keinen Lab-Fix. Eine zusätzliche unentschiedene
Beobachtung betrifft unterschiedliche gespeicherte IPAM- und spätere
Hostzugriffsadressen. Weder eine Fremdbelegung noch die fachliche Ursache
dieser Differenz ist belegt. Die Netz-/Leasebindung gehört deshalb ebenfalls
in die getrennte Lab-Bewertung; eigene Netzkorrekturen erfolgen nicht.

Der Fehlercleanup entfernt auch den zweiten eigenen Run einschließlich VM
und Child-Disk. Die lesende Nachprüfung bestätigt den Zustand `REMOVED`,
fehlende VM und Child-Disk sowie null aktive eigene Leases. Parenthash und
Schreibschutz sind unverändert. Frameworkdatenbank, Analyzer-Aufrufe und
Provider-Vorprobe werden nicht erreicht; die eigentliche Providerabnahme
bleibt `NOT_EXECUTED`.

Damit sind beide freigegebenen Windows-Runs und nativen Abnahmeblöcke sowie
alle drei Reviewprüfungen verbraucht. Der eine PR-CI-Versuch und Main-Nachlauf
bleiben ungenutzt reserviert. Alle bisherigen Reservierungen und Fehlbelege
bleiben bestehen. Es gibt keinen PR und keine Integration dieses Slices.

Zum damaligen Zwischenstand waren eine getrennte Lab-Prüfung der
Parameterbindung und Netz-/Leasebeobachtung, eine gesonderte
Implementierungsfreigabe und eine weitere begrenzte native Freigabe
erforderlich. Diese Schritte wurden anschließend ausdrücklich beauftragt;
die folgenden Nachweise ersetzen keine früheren Fehlversuche.

#### Nachabnahme mit qualifizierter Lab-Korrektur

Die getrennte Lab-Prüfung bestätigt die ungültige Parameterbindung und den
Verlust der reservierten Gastadresse beim erneuten Auflösen des HostSQL-
Netzplans. Die gezielte Lab-Korrektur erhält Root-, Run-, Scope-, VM- und
Credentialbindungen sowie `NoRetry`, übernimmt die aktive reservierte
Gastadresse und unterscheidet fehlende Collation-Evidence von vorhandenen
abweichenden Werten. [Lab-PR #818](https://github.com/gecompat/SQL_Server_Lab/pull/818)
ist nach unabhängiger Prüfung, erfolgreicher Windows-/Ubuntu-Statik und
Hyper-V-Lifecycle-Smoke als `8b87d5b5` integriert. Getesteter Head und
Mergecommit besitzen denselben Tree. Der Lifecycle-Smoke ist kein nativer
SQL-Collationnachweis.

Der danach separat freigegebene eigene Windows-Run verwendet Analyze
`a8df379d`, das korrigierte Lab-Main und den unveränderten Runner. SQL
CompleteImage endet mit `COMPLETE`; die gebundene Gastabfrage bestätigt
`SQL_Latin1_General_CP1_CS_AS` für Server, `master` und `tempdb`, verfügbare
Katalogcollation, SQL-Major-Version 17 und Defaultinstanz. Der gespeicherte
Netzplan und die Verbindungsadresse entsprechen der eigenen Leaseadresse.
Die Providerabnahme wird trotzdem nicht erreicht: Der erste Consumerbatch
liefert `WINDOWS_SQL_SCRIPT_FAILED`, SQL-Fehler 206 und
`FAILED_UNCONFIRMED`. Analyzer-Aufrufe und Provider-Vorprobe liegen bei null.
Consumer-CL170 und vollständiger Engine-Build werden nicht bestätigt.

Der Analyze-Vorbereiter übergibt den externen Operationsparameter direkt an
`sp_addextendedproperty`. Der öffentliche Windows-Transport bindet Zeichenketten
als `nvarchar(max)`. Der `sql_variant`-Parameter der Systemprocedure kann
[diesen Typ nicht aufnehmen](https://learn.microsoft.com/en-us/sql/t-sql/data-types/sql-variant-transact-sql?view=sql-server-ver17).
Diese Quellenabweichung erklärt den erfassten Fehler 206; der Transportbericht
enthält keine zusätzliche native Statementzeile. Die vorbereitete Korrektur
übernimmt den bereits geprüften GUID-Wert zunächst als `nvarchar(36)` und
verwendet diese lokale Variable für den Ownershipmarker. Die beschreibende
Aktivierungsvoraussetzung entspricht außerdem dem bereits verwendeten
`NotRequested`-/`Denied`-Intent.

Die erste Markerkorrektur besteht dreizehn gezielte Offlineprüfungen. Sie
verwenden den tatsächlichen Lab-Parameterkonverter, dessen geschlossenen SqlClient-Parameterbindungsteil
und den TSql170-Parser. Sie bestätigen den ursprünglichen MAX-Typ, weisen
den alten direkten Übergang sowie MAX-, Verkürzungs- und Rückfallmutationen
ab und prüfen den begrenzten Marker. Alle übrigen Vorbereitungsstatements,
Guards, kanonischen Quellen sowie Installations-, Abnahme- und Cleanup-SQL-
Eingaben bleiben in diesem ersten Stand bytegleich. Diese Prüfung führt
weder Gast- noch SQL-Aufrufe aus und ersetzt keinen nativen Nachweis.

Der zusätzlich freigegebene unabhängige Review findet eine abweichende
Markerdarstellung: Die Speicherung verwendet den SQL-GUID-Roundtrip,
der Cleanup vergleicht zunächst mit dem ursprünglichen .NET-Text. Unter
CS_AS müssen Speicherung, Szenarioguard und Cleanup dieselbe Darstellung
verwenden. Der befundgebunden korrigierte Cleanupvergleich verwendet deshalb
ebenfalls `CONVERT(nvarchar(36),TRY_CONVERT(uniqueidentifier,@OperationId))`.
Zweiundzwanzig ergänzte Offlineprüfungen bestehen einschließlich kleiner,
großer und gemischter GUID-Hexschreibweise, gemeinsamer SQL-Kanonisierung
und negativer Cleanup-Rückfälle. Installations- und Provider-SQL bleiben
bytegleich; alle übrigen Cleanupstatements und Identitätsassertions bleiben
erhalten. Der befundgebundene Abschlussreview besteht ohne offene materielle
Befunde. Die anschließend freigegebene native Nachabnahme ist nachstehend
gesondert dokumentiert.

Der Datenbankstatus bleibt wegen des unbestätigten Batches
`CREATION_UNCONFIRMED`; es erfolgt kein ungebundenes SQL-DROP. Der gebundene
Run-Cleanup entfernt die eigene VM und Child-Disk. Eine lesende Nachprüfung
bestätigt `REMOVED`, fehlende Ressourcen und keine aktive eigene Lease;
Parenthash und Schreibschutz sind unverändert. Die zusätzliche native
Freigabe ist verbraucht. Der Benutzer hat anschließend den zusätzlichen
Review und einen weiteren eigenen gebundenen Windows-Run ausdrücklich
freigegeben. Dieser Run beginnt erst nach erfolgreichem Abschlussreview;
die früheren Fehlversuche und Reservierungen bleiben erhalten. Der
reservierte PR-CI-Versuch und Main-Nachlauf bleiben ungenutzt; der Slice ist
noch nicht veröffentlicht.

#### Markerkorrektur bestätigt; Installation am Kommentar-GO blockiert

Nachdem die Lab-Laufsperre frei ist, beginnt der zusätzlich freigegebene
Windows-Run mit Analyze `108c2063` und dem qualifizierten Lab-Main
`90cf416a`. Der zwischenzeitliche Lab-Commit ergänzt ausschließlich
Dokumentation; die verwendeten Runtimequellen entsprechen Lab-PR #818.
SQL CompleteImage, Server-, Master- und TempDB-Collation sowie die
Lease-/Hostadressbindung bestehen. Die korrigierte Datenbankvorbereitung
liefert `SUCCEEDED`, SQL Server `17.0.1000.7`, Enterprise Developer Edition,
Datenbankcollation `SQL_Latin1_General_CP1_CS_AS` und CL170.

Der erste Installationsteil scheitert nach zehn erfolgreich ausgeführten
Batches mit `WINDOWS_SQL_SCRIPT_FAILED`, SQL-Fehler 113 und
`FAILED_UNCONFIRMED`. Der unveränderte Windows-Transport trennt mit einem
zeilenbezogenen GO-Ausdruck ohne SQL-Kommentarkontext. Die gespeicherte
Eingabe enthält genau eine damit irrtümlich erkannte Trennstelle im
Blockkommentar von `Code/01_Common/030_VW_AnalyseAccessPolicy.sql`.
Transportbatch 11 enthält dadurch den geöffneten Kommentar ohne dessen
Abschluss. Der TSql170-Tokenizer bestätigt die Kommentarzugehörigkeit der
Trennstelle und reproduziert den fehlenden Kommentarabschluss offline.
Damit ist die konkrete Quellen-/Transportabweichung belegt; der native
Transportbericht enthält keine zusätzliche Statementzeile.

Der gebundene SQL-Cleanup entfernt die markierte eigene Datenbank. Der
Run-Cleanup entfernt VM und Child-Disk und gibt die eigene Lease frei;
Parenthash und Schreibschutz bleiben unverändert. Analyzer-Aufrufe und
Provider-Vorprobe liegen weiterhin bei null. Die eigentliche Providerabnahme
bleibt `NOT_EXECUTED`; es gibt keinen neuen PR und keine Integration.
Zu diesem Zwischenstand sind alle vier freigegebenen Windows-Runs und nativen
Blöcke sowie die fünf freigegebenen Reviewprüfungen verbraucht. PR-CI und Main-Nachlauf bleiben
ungenutzt reserviert. Frühere Fehlversuche und Reservierungen bleiben erhalten.

Die vorbereitete Analyze-Korrektur behandelt ausschließlich diese bekannte
Kommentarzeile in privaten Installationseingaben. Ein Hash des auf LF
normalisierten kanonischen Quelltexts und genau ein erwarteter Kommentarabschluss
binden das ergänzte Präfix `-- ` an den geprüften Stand. Abweichender
Quelltext oder eine andere Trefferzahl führen vor der Runanlage zu
`OPS005_POLICY_EXAMPLE_REVIEW_REQUIRED`. Ausführbare Tokens und tatsächliche
Batchgrenzen bleiben erhalten. Kanonische Quellen, Lab-Code, Worker,
Provideroracle und Cleanup werden nicht geändert. Ein zunächst untersuchter
allgemeiner Lexer wurde wegen seines unverhältnismäßigen Aufbereitungsumfangs
verworfen; seine abgebrochenen Offlineversuche bleiben privat erhalten.
Der gezielte Stand besteht 21 Offlineprüfungen. Sie reproduzieren den alten
Kommentarfehler, bestätigen identische ausführbare Tokens und echte
Batchgrenzen und prüfen alle 194 erzeugten Transportbatches auf geschlossene
lexikalische Bereiche. Gegen den vorherigen Stand kommen ausschließlich drei
Kommentarbytes hinzu; der zweite Installationsteil, alle 171 kanonischen
Quellbindungen, Datenbankvorbereitung, Cleanup und Provider-SQL bleiben
unverändert. Negative Quelltext- und Trefferzahlmutationen werden abgewiesen.
Diese Prüfung führt weder SQL noch Gastaufrufe aus.
Der gezielte neue Stand benötigt einen unabhängigen Review und eine gesondert
begrenzte native Nachabnahme; ein bisheriger Review deckt die neue
Aufbereitung nicht ab.

#### Installation bestätigt; Guardzustand 54890 unbekannt

Der Benutzer gibt anschließend einen weiteren unabhängigen Reviewer mit
höchstens zwei befundgebundenen Prüfungen sowie einen weiteren eigenen
Windows-Run frei. Der erste Review besteht am sauberen Analyze-Stand
`e47cdf3c` ohne offene materielle Befunde. Lab-Main `9be544f2` enthält
gegenüber `90cf416a` ausschließlich TLS-UI- und Dokumentationsänderungen;
die für OPS-005 verwendeten Runtimequellen sind identisch. Lab-PR #820
besitzt grüne ausgewählte Head-Gates und denselben Head-/Merge-Tree;
der Main-Nightlylauf besteht ebenfalls. Die Quellenkopie bleibt getrennt
vom fremden Lab-Checkout.

Der freigegebene Run bestätigt SQL Server `17.0.1000.7`, Enterprise Developer
Edition, CL170, alle vorgeschriebenen Collations sowie Datenbankvorbereitung
und Marker. Beide Installationsteile bestehen mit 153 und 41 Batches.
Damit ist die gezielte Kommentar-GO-Korrektur nativ bestätigt. Der folgende
Providerbatch scheitert jedoch mit `WINDOWS_SQL_SCRIPT_FAILED`,
`FAILED_UNCONFIRMED`, Fehlernummer 54890 und null abgeschlossenen Batches.
Der öffentliche Windows-Transport erfasst nur die Fehlernummer, keinen
SQL-Fehlerstate und keine Fehlermeldung. Die gespeicherten Resultsets sind leer.

54890 kommt in der tatsächlichen Eingabe ausschließlich in den sieben
Guards vor der Fixtureanlage vor. Die States unterscheiden Operationswert,
Datenbankmarker, native Voraussetzungen, Isolation, vorhandene Definition,
Definitionshash und 13-Parameter-ABI. Welcher Guard nativ scheitert, bleibt
UNKNOWN. Der erwartete Hash stimmt offline mit dem normalisierten tatsächlich
eingereichten Definitionsbatch überein. Der unveränderte Lab-Konverter liefert
VarBinary mit 32 Bytes; eine lokale Serialisierungssimulation erhält diese
Bytes. Das ersetzt keine Beobachtung der gespeicherten Moduldefinition oder
der tatsächlichen Parameter beim fehlgeschlagenen Aufruf. Der zweite
befundgebundene Review findet keinen statisch beweisbaren Implementierungsfehler
und bestätigt die fehlende State-Evidence auch im Operationsjournal.

Der eigene SQL-Cleanup entfernt die markierte Datenbank. VM und Child-Disk
sind entfernt, die eigene Lease ist freigegeben, Parenthash und Schreibschutz
sind unverändert. Der letzte gespeicherte Bericht behält seine vorsorglichen
Zähler `UNKNOWN_0_TO_5` und `UNKNOWN_0_TO_1`; sie werden nicht nachträglich
als erfolgreiche Aufrufe umgedeutet. Eine Providerabnahme wird nicht belegt.
Insgesamt sind fünf Windows-Runs und native Blöcke sowie sieben
Reviewprüfungen verbraucht. Der reservierte PR-CI-Versuch und Main-Nachlauf
bleiben ungenutzt. Der Stand wird weder veröffentlicht noch integriert.

Der kleinste zusätzliche native Discriminator ist `ERROR_STATE()` zur
Fehlernummer 54890. Ein gesondert gebundener, rein lesender Diagnosebatch
soll ausschließlich die unveränderten sieben Guards innerhalb `TRY/CATCH`
ausführen und genau eine begrenzte Ergebniszeile mit Fehlernummer und State
zurückgeben. Er erzeugt keine Providerfixture und ruft keinen Analyzer auf.
Höchstens eine zweite lesende Abfrage soll anschließend ausschließlich die
für den ermittelten State erforderlichen Werte erfassen. Ein Diagnoseerfolg
ist keine Providerabnahme; bei fehlendem oder nicht reproduzierbarem Befund
bleibt die Ursache offen. Lab-Code und sämtliche bestehenden Assertions,
Hash-, ABI-, Ownership- und Cleanupbedingungen bleiben geschützt.

Für die Fortsetzung wird ein gemeinsamer begrenzter Umfang vorgeschlagen:
höchstens ein eigener Windows-Diagnoserun und, erst nach belegter Ursache,
minimaler Korrektur, passenden Offlineprüfungen und unabhängigem Abschlussreview,
höchstens ein weiterer eigener Abnahmerun. Beide Runs verwenden das vorhandene
Prepared-Image mit vier vCPUs und acht GiB festem RAM und erhalten jeweils
ihren gebundenen Cleanup. Der Diagnoseblock erhält höchstens die beiden
genannten lesenden Abfragen und keine Analyzer-Aufrufe oder Provider-Vorprobe.
Der Abnahmeblock bleibt bei höchstens fünf Analyzer-Aufrufen und einer
Provider-Vorprobe. Ein unabhängiger Reviewer erhält höchstens zwei
befundgebundene Prüfungen für Diagnoseeinstieg und belegte Korrektur.
PR-CI und Main-Nachlauf werden nicht erweitert. Der Benutzer hat diesen
gemeinsamen Umfang ausdrücklich freigegeben. Imagebau, Downloads, externe Netzanbindung, Lab-Codeänderungen
und fremde Ressourcen bleiben ausgeschlossen.

Der vorbereitete Worker besitzt dafür den ausdrücklich gewählten Modus
`DiagnosePrerequisites`. Die sieben Guards stammen unverändert aus dem
gebundenen Providerfall; der zweite SQL-Einstieg verzweigt ausschließlich
nach dem erfassten State. Beide Eingaben werden gehasht und vor Runanlage
unabhängig regeneriert. Diagnose und Abnahme haben getrennte Ergebnisscopes.
Eine erfasste Diagnose verlangt vollständigen Cleanup und wird niemals
`PASSED`. Der reguläre Abnahmepfad behält seinen bisherigen Providerblock.

29 ausschließlich simulierte Workerfälle bestehen. Sie umfassen den bisherigen
Abnahmepfad, alle sieben Diagnosestates, nicht reproduzierte Fehler, ungültige
Antworten, verlorene Replies sowie fehlerhaften Cleanup und Parentbindung.
In sämtlichen Diagnosefällen bleiben Analyzer und Provider-Vorprobe bei null.
20 zusätzliche Strukturprüfungen bestätigen die unveränderten Guards,
syntaktisch gültige Diagnoseeingaben, ausschließlich lesende persistente
Zugriffe, den begrenzten zweiten Aufruf und unveränderte bisherige SQL-Eingaben
sowie kanonische Quellbindungen. Die kopierte ABI-Tabellenvariable bleibt lokal.
Diese Offlineprüfungen erzeugen weder Lab-Runs noch Gast- oder SQL-Aufrufe.
Der unabhängige erste Review besteht am Stand `695cc718` ohne offene
wesentliche Befunde. Ein zunächst durch die Lab-Laufsperre blockierter
Start erzeugt keinen Run. Der anschließend ausgeführte Diagnoserun erfasst
mit genau zwei lesenden Abfragen Fehler 54890, State 5. Das Modul ist vorhanden,
doch die Suche nach `CREATE OR ALTER PROCEDURE` liefert null. Der erwartete
Hash wird mit 32 Bytes übertragen. Der Diagnoseblock führt keinen Analyzer
und keine Provider-Vorprobe aus. Datenbank, VM und Child-Disk sind entfernt,
die eigene Lease ist freigegeben und das Parent bleibt unverändert.

Die vorhandene Moduldefinition beginnt wie der eingereichte Installationsbatch;
ihre Länge ist um 14 Bytes kürzer. Dies passt zur Ersetzung von
`CREATE OR ALTER PROCEDURE` durch `CREATE   PROCEDURE`, belegt aber noch nicht
den vollständigen gespeicherten Deklarationstext. Belegt ist der falsche
Erkennungsvertrag in Guard 5. Die vorbereitete TestLab-Korrektur akzeptiert
zusätzlich ausschließlich diese eng begrenzte Deklarationsform für das exakt
benannte Modul und rekonstruiert vor der Hashprüfung die kanonische Form.
Der erwartete SHA-256-Hash, der vollständige nachfolgende Definitionstext,
die 13-Parameter-ABI und alle übrigen Guards bleiben erhalten. Andere
Deklarationsformen und Änderungen am Parameter- oder Prozedurtext erhalten
keine Ausnahme. Produkt- und Lab-Code werden nicht geändert.

26 gezielte Offlineprüfungen bestätigen den unveränderten erwarteten Hash,
die Rekonstruktion beider eng begrenzten Formen und die Ablehnung veränderter
Parameter, Prozedurtexte, Namen und zusätzlicher Anweisungen. Der bisherige
Providerblock einschließlich Oracle und Cleanup sowie Worker und Preparer
bleiben unverändert. Der Längenvergleich ist als Inferenz gekennzeichnet;
die native Abnahme der Korrektur bleibt offen.

Vor der letzten Abnahme waren sechs Windows-Runs und native Blöcke sowie acht
Reviewprüfungen verbraucht. Der bedingte Abnahmerun bleibt bis zu passenden
Offlineprüfungen und der zweiten unabhängigen Prüfung reserviert. Seine
Ausführung muss die tatsächliche kanonische Definition einschließlich Hash
bestätigen; ein Diagnoseergebnis ersetzt diesen Nachweis nicht. PR-CI und
Main-Nachlauf bleiben ungenutzt.

#### Windows-Providerabnahme vom 22. Oktober 2026 bestanden

17 zusätzliche Struktur- und Bindungsprüfungen bestätigen den unveränderten
Installer, Datenbankvorbereitung, Cleanup und alle 171 kanonischen Quellen.
Der unabhängige Abschlussreview besteht am Korrekturstand `c7f00cdb` ohne
offene wesentliche Befunde und bestätigt die bedingte Zulassung. Zwei
Dokumentationsbefunde der statischen Gesamtsuite sind anschließend gezielt
korrigiert: Die Lab-Freigabegrenze verweist auf die kanonischen
Fortsetzungsregeln, Produktquellen sind als solche eingeordnet und das
öffentliche TestLab-README enthält keinen internen Dokumentationsverweis.
SQL, Worker, Preparer und sämtliche Ausführungseingaben bleiben dabei
bytegleich mit dem geprüften Korrekturstand. Die betroffenen Nachprüfungen
bestehen; die ursprünglichen Fehlbelege bleiben erhalten.

Der freigegebene eigene Abnahmerun besteht am Stand `7a578c85` auf Windows
mit SQL Server `17.0.1000.7`, Enterprise Developer Edition, CL170 und allen
vorgeschriebenen Collations. Beide Installerteile bestehen mit zusammen
194 Batches. Der Providerbatch besteht einschließlich ursprünglichem
vollständigem Definitionshash und 13-Parameter-ABI. Genau fünf Analyzerfälle
und eine native Provider-Vorprobe liefern die erwarteten Outputs; der
nicht registrierte synthetische Provider meldet 7403. Locktimeout,
Sessionoptionen und Transaktionszahl bleiben bei allen fünf Aufrufen erhalten.
Providerfixture, markierte Datenbank, VM und Child-Disk sind entfernt,
die eigene Lease ist freigegeben und der schreibgeschützte Parenthash ist
unverändert. Der abschließende Workerbericht meldet `PASSED`.

Damit sind sieben Windows-Runs und native Blöcke sowie neun Reviewprüfungen
verbraucht. Weitere native OPS-005-Läufe und Reviews sind nicht freigegeben.
Der reservierte PR-CI-Versuch und Main-Nachlauf bleiben für die Integration
dieses qualifizierten Stands verfügbar. Der Windows-Provider-Negativfall
ist kein vollständiger Provider-, Berechtigungs- oder Release-Nachweis.

### Autorisierter Foundation-Folgeauftrag

Nach qualifizierter Integration von OPS-005 in `origin/main` und eigenem
Branch- und Worktree-Cleanup wird die dann aktuelle AI-Repository-Foundation
autonom übernommen. Quelle und Version werden aktuell verifiziert;
projektspezifische Verträge, semantische Prüfung, Bewertung des tatsächlichen
Verarbeitungsaufwands und erforderlicher unabhängiger Review bleiben erhalten.
Die Übernahme wird nach erfolgreichen Gates regulär integriert und bereinigt.
Anschließend wird die bereits autorisierte autonome Entwicklung fortgesetzt.
Dieser Folgeauftrag erneuert keine bestehenden OPS-005- oder Lab-Budgets.

## Abgeschlossene Findings-Stabilisierung vom 20. Oktober 2026

Der Benutzer beauftragt die autonome Ursachenanalyse, Korrektur, Prüfung und
Bewertung bis zu einem stabilen Teststand. Der
[aktuelle Nachweis](../Architecture/Foundation_1_21_Upgrade.md#gezielte-findings-stabilisierung-vom-20-oktober-2026)
erhält frühere Fehlversuche und trennt Diagnose von kanonischer Abnahme.

Die kanonische lokale Abnahme an `88bf926e` besteht auf SQL Server 2025,
Compatibility Level 170: Deploymentregression, Full Gate, Callerzustände,
Berechtigungs- und Regexmatrix, Plan-Standalone sowie Snapshotlauf und
Nebenläufigkeit. Der unabhängige SSIS-Review und die 74 statischen Prüfer
sind qualifiziert; der anfänglich veraltete Adapterinstaller ist korrigiert.

Der anschließende [Head-Lauf](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/39437366372)
an `3fc20ae1` besteht Deployment, native Vierfallprobe und statische Checks,
scheitert jedoch in Full-Gate-Stufe 15 von 34 mit 1222, State 47, bei der
eigenen Temp-Anlage in `USP_DiagnosticFindings`. Ohne aktive Samples bleibt
der Blocker UNKNOWN. Dieser frühere letzte PR-Versuch bleibt verbraucht;
Main ist unverändert und sein reservierter Nachlauf ungenutzt.

Eine neue private Parallelprobe erfasst weitere Timeouts im EXEC-Kontext
mit State 71. Sie bleibt FAILED und für den ursprünglichen Mechanismus
INCONCLUSIVE. Der eigene Container ist entfernt. Die frühere Helper-Seed-
Sperre bleibt ebenfalls UNKNOWN. Ein lexikalischer Audit ähnlicher Stellen
begründet keinen pauschalen Eingriff in die übrigen Procedurequellen.

Der unabhängige Designreview bestätigt die gezielte Findings-Korrektur.
Version 1.2.1 schützt ausschließlich die eigene CREATE-Anweisung bei lokalem
NOWAIT mit bis zu 1000 ms und stellt den Wert bei Erfolg und Fehler wieder
her. Childaufrufe, Quellen und Caller-TABLE-Ziele liegen außerhalb. Vertrag
178 ergänzt drei Callerfälle für 0, 137 und -1 samt frühem Mappingfehler;
die bisherigen sechs Fälle bleiben erhalten. Der abhängige Installer ist
kanonisch neu erzeugt.

Der Kandidat `236e2b99` besteht alle 74 statischen Prüfer und den unabhängigen
Abschlussreview. Die kanonische lokale SQL-Server-2025-Abnahme auf CL170
besteht Deployment, Full Gate mit allen neun Findings-Fällen, Callerzustände,
Berechtigungen, Regex, Plan-Standalone sowie Snapshotlauf und Nebenläufigkeit.
Der eigene Container ist entfernt. Die
[Head-CI](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/39443291549)
und der separate [Main-Nachlauf](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/39444518793)
bestehen. Die zusätzliche Vierfallprobe ist gemäß Workflow auf Pull Requests
beschränkt und bleibt für Main NOT_APPLICABLE; ihr Head-Nachweis besteht.
Frühere Grenzen und Fehlversuche werden nicht zurückgesetzt. PR #399 ist
integriert; die anschließende OPS-005-Welle beginnt mit dem oben begrenzten
Provider-Negativfall.

## Frühere Nichtqualifikation und integrierter OPS-005-Prüfschritt vom 20. Oktober 2026

Der aktuelle Benutzerauftrag hebt die frühere allgemeine Entwicklungspause
auf. Der Benutzer hat anschließend den dritten unabhängigen Review und
eine gezielte Offlineprüfung für PR #399 freigegeben. Die elf Offlinecontracts,
Deploymentregression und statischen Gates bestehen; beide neuen nativen
PR-Abnahmeversuche bleiben FAILED. Der
[erste Lauf](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/39340302984)
und der [letzte freigegebene Lauf](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/39387700757)
erkennen jeweils Fehler 1222, Exitcode 1 und den positiven Testfall mit
2000 ms Lock-Timeout, aber null Stichproben erfüllen das Blocker- und
Ressourcenoracle. Auch die explizite Prozessentpufferung mit `stdbuf -o0 -e0`
ist damit keine nativ bestätigte Lösung. Die verbleibende Ursache ist UNKNOWN;
die Testdoubles bestätigen nur die Wrapperkonfiguration.

Die drei historischen SQL-Versuche und drei historischen Reviews bleiben
verbraucht. Zusätzlich sind beide neuen PR-SQL-Versuche und alle drei neuen
Reviewdurchgänge ausgeschöpft. Vollständiges funktionales Gate und übrige
synthetische Fälle wurden nicht ausgeführt. Der bestehende CI-Container-Cleanup
besteht; ein vollständiger qualifizierter Cleanupnachweis bleibt offen.
Der reservierte Main-Nachlauf wird ohne erfolgreiche PR-Abnahme weder
ausgeführt noch als weiterer PR-Versuch verwendet.

[PR #399](https://github.com/gecompat/SQL_Server_Analyze/pull/399) bleibt am
Head `2efabcb0cedbe0bae22129899422aff97d144666` unintegriert erhalten.
Diagnoseartefakte und der unübernommene Stand sind privat gesichert; der eigene
Arbeits-Worktree ist wiederherstellbar archiviert. Eine Fortsetzung benötigt
einen konkret abgegrenzten Diagnoseplan für die tatsächliche SQLCMD-Meldungs-
übertragung samt gesondert freigegebenen Review-, Offline- und SQL-Abnahmegrenzen.
Unveränderte Blocker lösen keine weiteren Ausführungen aus.

Der unabhängige statische OPS-005-Adaptervergleich ist über
[PR #401](https://github.com/gecompat/SQL_Server_Analyze/pull/401) integriert.
Die vorhandene Prüfung vergleicht Dateien byteweise, obwohl Git-Checkout
und Generator unter Windows unterschiedliche CRLF-/LF-Darstellungen erzeugen.
Die normalisierten Inhalte der beiden Adapterdateien stimmen mit ihren
kanonischen Quellen überein. Der frühere lokale FAIL bleibt dokumentiert.
Der neue Vergleich dekodiert strikt als UTF-8 und setzt ausschließlich CRLF
mit LF gleich. Inhalt, Groß-/Kleinschreibung, einzelne CR-Zeichen, BOM und
das abschließende Zeilenende bleiben prüfbar. Generierte SQL-Dateien,
Installerquellen, Produktprocedures und Git-Einstellungen werden nicht geändert.

Dieser getrennte Prüfschritt umfasst zwei Dateien, einen Implementierer,
einen unabhängigen Reviewer mit höchstens zwei befundgebundenen Prüfungen,
eine lokale Vertragsprüfung samt höchstens einer gezielten Fehlernachprüfung
und höchstens zwei PR-Prüfstände sowie einen Main-Nachlauf. Er erweitert keine
Grenze von PR #399. Acht synthetische Darstellungsfälle sichern den Vergleich;
die vorhandenen Adapter- und Integritätsprüfungen bleiben erhalten.
Die Dokumentations-CI führt die statische Gesamtsuite aus. Neue SQL- oder
Providerläufe sind für diesen statischen Umfang gemäß CI-Teststrategie nicht
erforderlich. Vollständige grüne Logs werden nicht an ein Modell übertragen;
Kosten und Kontingente bleiben UNKNOWN. Die regulären Head- und Mainchecks
bestehen; der Merge-Tree entspricht dem geprüften Head. Main ist synchron
und sauber. Der eigene abgeschlossene Branch ist entfernt, der Worktree
wiederherstellbar archiviert. Diese Lieferung qualifiziert PR #399 nicht.

## Regelübernahme für Testbewertung vom 19. Oktober 2026

Die [CI-Teststrategie](../../../Documentation/Quality/CI_Test_Strategy.md)
ergänzt deterministische lokale Bewertung, kompakte Erfolgsmeldungen,
Fehlerklassifikation und die Bedingungen einer möglichen lokalen
Evidenzwiederverwendung. Die [Aufwandsbewertung](../Architecture/Foundation_1_21_Upgrade.md#regelübernahme-vom-19-oktober-2026)
trennt vorhandene Mechanismen, übernommene Regeln und offene technische Punkte.
Ein vertrauenswürdiger Local-to-Remote-Pfad ist NOT_IMPLEMENTED; die
bestehende Remote-CI und die native Releasequalifikation bleiben erhalten.

Dieser Auftrag umfasst die Regelintegration. Er aktiviert weder eine
technische CI-Optimierung noch den gesondert vorgeschlagenen
1222-Diagnosebeobachter. Die pausierte autonome Produktarbeit wird durch die
Regeländerung nicht automatisch gestartet; ihre Fortsetzung verwendet den
integrierten Regelstand und die konkrete Benutzerfreigabe. Neue öffentliche
Verträge und bestehende offene Abnahmen behalten ihre bisherigen Grenzen.

## Freigegebene Lookup-/Cacheanalyse vom 19. Oktober 2026

Die vom direkten Benutzer freigegebene Lookup-/Cacheanalyse ist in
Produktversion 1.5.0 implementiert. Position 25, SchemaVersion 6, sechs
originalbelegte Profile und eine neue 23-Feld-Menge begrenzen den Umfang.
Integration207 besteht mit 207 Payloadfällen, 32 Flagkombinationen und
sieben Ausgabeprüfungen. Zwölf getrennte extrahierte Stufen und genau acht
Restoreconsumer aus den vier erhaltenen Originalaufnahmen sind qualifiziert.
Ein privater Fixturefehler 515 und eine mechanische Berichtszählerkorrektur
bleiben in der Evidenz erhalten; unveränderte bestandene Gruppen wurden
nicht wiederholt. 142 Offline-Negativkontrollen werden abgewiesen.

Die [begrenzte Abnahme](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#begrenzte-lookup-cacheabnahme-vom-19-oktober-2026)
trennt vollständige Analyzeraufrufe, restaurierte Originaldaten und
extrahierte Stufen. Neue Paketausführungen und SDK-Aufrufe sind 0. Alle neun
Providerwerte, Callerzustände und das Datenbankinventar bleiben erhalten;
eigene Ressourcen sind entfernt. Native11/12 bleiben insgesamt
FAILED_NOT_QUALIFIED. Vorbereitungs-/Partial-Cache-Operationsprofile,
allgemeine Rollen-/Versionsabdeckung und weitere Loggingquellen bleiben
offen. SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION; WI-0009 GATE-0001 bleibt offen.

Die neue Welle führt zwei Reviewphasen und die erforderlichen Liefergates.
Nach Ergebnisreview folgen exakte Head-CI, reguläre PR-Integration,
Treeidentität, Mainchecks und Synchronisierung. Historische Budgets bleiben
geschlossen; Kosten und Kontingente sind UNKNOWN.

## Freigegebene Legacy-Lifecycle-Analyse vom 19. Oktober 2026

Der direkte Benutzer hat L1–L9 samt begrenztem Abnahmeplan freigegeben und die
Implementierung mit regulärer PR-Lieferung beauftragt. Der bisherige
Vertragswartevermerk ist abgelöst. Der [freigegebene Umfang](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#freigegebene-ergänzende-legacy-lifecycle-methoden-vom-19-oktober-2026)
umfasst PCT_EN_3 für Validate, PreExecute und PostExecute, einen abhängigen
Opt-in an Position 24 und unveränderte 42 Felder mit methodenspezifischem
VALIDATE-/EXECUTE-Berichtskontext. Erhaltene Originalproviderzeilen werden
hashgebunden wiederhergestellt; Paketausführungen und SDK-Aufrufe bleiben 0.

Die neue Welle hat einen Autor, denselben Reviewer mit zwei begründeten
Prüfungen, höchstens zwei synthetische Versuche einschließlich extrahierter
Stufen, zwei Arrange-/Consumerversuche mit insgesamt sechs Consumeraufrufen
inklusive Fehlversuchen und vier CI-Qualifikationen einschließlich Pflicht-Main.
Historische Budgets und Fehler bleiben erhalten. Unveränderte bestandene Tests
werden nicht wiederholt. Die synthetische Abnahme besteht im ersten Versuch; die sechs neuen
Restoreconsumer sind mit 42 unabhängigen Feldern und 50 abgewiesenen
Offline-Mutationen qualifiziert. Originalmaterial, Caller und Datenbankinventar
sind erhalten; eigene Datenbanken sind entfernt, Cleanup-/Retentionfehler 0.
Es gab keine Paket- oder SDK-Ausführung. Die [kanonische Abnahme](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#legacy-lifecycle-methoden-begrenzte-consumerabnahme-vom-19-oktober-2026)
trennt aktuelle SUT-Aufrufe, neue extrahierte Kontextprüfungen und vier
unverändert wiederverwendete Stufenbelege. Nach dem abschließenden Ergebnisreview
folgen exakte Head-CI, regulärer MatchHead-Merge, Treeidentität, Mainchecks,
origin/main-Synchronisierung und nur eigenes Cleanup. Verbrauchte oder bestandene
Fälle werden nicht erneut gestartet. Kosten und Quoten bleiben UNKNOWN;
SSIS-001 bleibt partiell und WI-0009 GATE-0001 offen. Die nachfolgenden
Abschnitte dokumentieren frühere abgeschlossene Lieferungen.

## Lieferung der begrenzten Komponentenphasen-Erweiterung

Die menschlich freigegebene zusätzliche P-N02-Ausführung und genau zwei offene
Consumer sind erfolgreich aufgenommen und unabhängig qualifiziert. Die
[kanonische Abnahme](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#legacy-komponentenphasenzeiten-begrenzte-abnahme-vom-18-oktober-2026)
bindet sechs unveränderte frühere P-N01-Captures und zwei neue P-N02-Captures.
P-N01 wurde nicht wiederholt. Der frühere P-N02-Lauf und der spätere
Offline-Zielmengenfehler bleiben erhaltene Nichtqualifikationen; die korrigierte
Zielmengenerwartung folgt dem bereits gebundenen Paketfilter und hebt keine
Produktguards auf. Eigene Datenbanken sind entfernt, Caller und Quellen sind
erhalten, Cleanup- und Retentionfehler sind 0.

Der eine zusätzliche Abschlussreview ist ausdrücklich freigegeben. Nach seinem
Abschluss folgen exakte Head-CI einschließlich der neuen EN1-NUL-Regression,
regulärer MatchHead-Merge, Treeidentität, Mainchecks, origin/main-Synchronisierung
und nur eigenes Cleanup. Runtime2/2, Paket2/2 und Consumer8/8 sind verbraucht;
Synthetik2/2 bleibt geschlossen. Das bestehende CI-Budget von vier
Qualifikations-Heads einschließlich Main wird nicht zurückgesetzt. Weitere
Paket-/Consumerläufe oder grüne P-N01-Wiederholungen sind nicht autorisiert.

## Freigegebene PCT_EN_2-Fortsetzung

Der Benutzer hat B1–B7 samt begrenzter Folgeabnahme ausdrücklich freigegeben.
Der [kanonische Plan](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#zwischenstand-der-begrenzten-phasenumsetzung-vom-18-oktober-2026)
führt Ereignisform, NULL-IDs und berichtete Namensgruppen zusammen. Der alte
Freigabewartezustand ist abgelöst. P-N01 wird aus seinen erhaltenen Originaldaten
hashgebunden restauriert und nicht erneut ausgeführt. Die neue Grenze beträgt
zwei synthetische und zwei Arrange-/Runtimeversuche, insgesamt höchstens einen
erstmaligen P-N02-Paketlauf, acht Consumeraufrufe einschließlich Fehlern und
zwei begründete Prüfungen desselben Reviewers. Das bestehende ungenutzte
CI-Budget von vier Qualifikations-Heads einschließlich Main wird weitergeführt.

Frühere Synthetik3/3- und Native3/3-Historien bleiben geschlossen; die erste
Welle hat eine tatsächliche Paketausführung und keine Consumerqualifikation.
Abgeschlossene Tests werden gebunden wiederverwendet. Neue Profile erhalten
keine geratenen numerischen IDs. Nach begrenzter Qualifikation folgen exakte
Head-CI, regulärer MatchHead-Merge, Treeidentität, Main-Synchronisierung und nur
eigenes Cleanup. Weitere Vertragsgrenzen verlangen eine konkrete Entscheidung.

## Freigegebene Legacy-Komponentenphasenzeiten vom 18. Oktober 2026

Der Benutzer hat den geprüften P1–P9-Vertrag samt begrenztem Abnahmeplan
ausdrücklich zur Implementierung und regulären PR-Lieferung freigegeben.
Der bisherige Vertragsentwurf ist über SHA-256
9588CFA6925E7372A2986B59D516C7D169B05C1E7F7CFBC19DCD9E63889C05F3
gebunden. Der [freigegebene Vertrag](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#freigegebene-legacy-komponentenphasenzeiten-vom-18-oktober-2026)
begrenzt die Erweiterung auf IncludeComponentPhaseAnalysis an Position 23,
42 neue Felder und PCT_EN_1 für ProcessInput/PrimeOutput. Der vorherige
Wartezustand ist abgelöst. Die neue begrenzte Welle hat einen Implementierer,
denselben Reviewer mit höchstens drei begründeten Prüfungen, drei synthetische
und drei Arrange-/Runtimeversuche, insgesamt zwei tatsächliche Paketausführungen
und acht Consumeraufrufe einschließlich Fehlversuchen sowie höchstens vier
CI-Heads einschließlich Main. Historische Budgets bleiben geschlossen;
abgeschlossene unveränderte Tests werden nicht wiederholt. Tatsächliche
Ergebnisse werden getrennt gebunden, Kosten und Kontingente bleiben UNKNOWN.
SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION, WI-0009 GATE-0001 offen.

## Freigegebene ORPS_EN_2-Fortsetzung vom 18. Oktober 2026

Der Benutzer hat die konkrete ORPS_EN_2-Ergänzung samt begrenzter Folgeabnahme
und regulärer PR-Lieferung ausdrücklich freigegeben. Maßgeblich ist die
[Profilergänzung](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#tatsächliche-row-flow-abnahmegrenze-vom-18-oktober-2026).
Die Umsetzung verwendet erhaltene hashgebundene eigene Originalproviderzeilen
für eine neue isolierte Consumerabnahme. Es erfolgen keine erneuten
Paketausführungen, VM- oder Setupänderungen. Historische native Fehler und
Budgets bleiben geschlossen; erfolgreiche unveränderte Tests werden nicht
wiederholt. Die neue Welle hat höchstens zwei Arrange-/Consumerversuche mit
je höchstens acht definierten Konstellationen, zwei Delta-/Ergebnisreviews
desselben Reviewers und vier CI-Heads einschließlich Pflicht-Mainlauf.
Kosten und Kontingente sind UNKNOWN. Die neue Consumerabnahme besteht mit sechs geänderten Konstellationen,
4833 Prüfschritten, 14 abgewiesenen Mutationen und zwei zusätzlichen
Offlinekontrollen für fehlendes Feld beziehungsweise Array; neue
Paketausführungen: 0.
Eigene Datenbanken sind entfernt und das Inventar restauriert. Der finale
Ergebnisreview sowie exakte Head-CI, MatchHead-Integration, Treeidentität,
Main-Folgeprüfung, Synchronisierung und eigenes Cleanup bleiben Liefergates.
SSIS-001 bleibt insgesamt partiell.

## Freigegebene Legacy-Zeilenflusserweiterung vom 18. Oktober 2026

Der Benutzer hat den geprüften konkreten Vertrag für OnPipelineRowsSent
ausdrücklich freigegeben und Implementierung, begrenzte Abnahme sowie
reguläre PR-Lieferung beauftragt. Der geprüfte Entwurf ist über SHA-256
7DE38692D055EAAD9FF675F24D17E723BAB37254C9544326076D37A672E1C802 gebunden.
Der [freigegebene Vertrag](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#freigegebener-legacy-zeilenfluss-vom-18-oktober-2026)
begrenzt Position 22 IncludeRowFlowAnalysis, zwei neue Mengen mit 44 Feldern,
atomare Ableitung, 14 synthetische Gruppen sowie zwei neue native Szenarien
mit höchstens acht Consumeraufrufen. Der frühere Entwurfs-Wartezustand ist
abgelöst. Historische Budgets bleiben geschlossen; erfolgreiche unveränderte
Tests werden nicht wiederholt. SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION;
weitere vertiefte SSIS-Funktionen und WI-0009 GATE-0001 bleiben offen.

## Freigegebene Legacy-Taskerweiterung vom 18. Oktober 2026

Der Benutzer hat den geprüften konkreten Vertrag für Taskintervalle und
beobachtete Loggingabdeckung freigegeben und die Implementierung samt
Abnahmeplan und regulärer PR-Lieferung beauftragt. Der freigegebene Entwurf
besitzt SHA-256 7F53BD932056BA3F8796A5AE2ECFB9B9AC44D2F8A7F6B267FB650DED9C14321C.
Die [Erweiterungsspezifikation](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#priorisierte-entwicklungsreihenfolge-und-abnahme)
begrenzt die Lieferung auf Position 21 IncludeTaskAnalysis, zwei Zusatzmengen
und ihre Status-/Ausgabeverträge. Die vierzehn synthetischen Fallgruppen und
die zwei neuen nativen Szenarien sind getrennt zu qualifizieren. Die
abgeschlossenen Vierfälle-Providerprüfungen und ihre Budgets bleiben erhalten.
Eine Freigabe weiterer vertiefter Legacy- oder SSISDB-Funktionen folgt daraus
nicht. SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION; WI-0009 GATE-0001 bleibt offen.

## Abgeschlossene begrenzte Legacy-Providerabnahme vom 18. Oktober 2026

Die [kanonische Providerabnahme](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#legacy-providerabnahme-vom-18-oktober-2026)
bestätigt vier tatsächlich ausgeführte eigene synthetische Paketfälle auf
Windows SQL/SSIS 17.0.1000.7 mit zwölf gebundenen Cap-Einzelprüfungen.
Sechs erfolgreiche Belege aus Native11 und drei aus Native12 werden
unverändert wiederverwendet; drei Miss-Caps sowie RAW9/CONSOLE1/NONE0 und
vollständige erste Fehlertexte bestehen in Native13. Native11 und Native12
bleiben insgesamt FAILED_NOT_QUALIFIED. Ein neuer gemeinsamer Vierfällelauf
wird nicht behauptet. Produkt v1.0.0 und seine Abhängigkeiten bleiben unverändert.
Die geprüfte Produktbasis ist Commit `4b607a8e57b55dec3d52a0f69f37b103792319cd`;
die öffentliche Abnahme bindet die konkrete Produktfassung zusätzlich über SHA-256.

Analyze hat die eigenen Pakete, Referenzen und das Cleanup auf einer ausdrücklich
freigegebenen eigenen Umgebung verantwortet. Bereitstellung und Lifecycle
verwenden öffentliche Lab-Schnittstellen; die Paketausführung verwendet einen
eigenen PowerShell-Direct-/SDK-Adapter.
Eine zusätzliche vom Lab erstellte fachliche Legacy-Fixture ist keine
Voraussetzung. Die eigenen Runtimeobjekte, VM und virtuelle Festplatte sind
entfernt; eine verschlüsselte private Credentialdatei bleibt nach einer
automatischen Löschblockade ohne weiteren Löschversuch erhalten.
Originalevidenz und frühere Fehlhistorien bleiben privat erhalten.

Die aktuelle Dokumentationsintegration verändert keine Funktionsverträge,
Maturityflags oder historischen Abnahmebudgets und startet keine native
Prüfung. `SSIS-001` bleibt `PARTIAL_PRODUCT_FUNCTION`: weitere Parser- und
Interpretationsfunktionen, positive Task-/Schleifen-, Performance-/Verbose-,
Phasen-, RowFlow- und Least-Privilege-Nachweise bleiben offen. Der zurückgestellte
Backlog wird nicht aktiviert; neue öffentliche Verträge benötigen konkrete
menschliche Freigabe. WI-0009 GATE-0001 bleibt offen. Frühere Wartevermerke zur
Legacy-Providerquelle und zur Zuständigkeit für eigene Testfixtures sind für
die belegte Providererzeugung abgelöst; grüne Einzelprüfungen werden nicht wiederholt.

## Ergänzender abgeschlossener Mail-Retentionsnachweis

Die ergänzende private Retentionsfixture bestätigt auf SQL Server 2025
17.0.4075.5/CL170 genau eine tatsächlich gesendete eigene Mail. Zwei native
Purges mit ihrem unveränderten Requestzeitpunkt und derselben Grenze plus
einer Sekunde ergeben Mengen von eins, eins und null. Neun gespeicherte
NONE-/TABLE-/CONSOLE-Captures bestätigen native Aggregate, gleichaufrufbezogene
Parität und erhaltene Quellen; Rollback restauriert die ursprüngliche Mail
und den Caller. Vierzehn vor Assertion gespeicherte Evidenzzeilen sowie neun
abgewiesene tatsächliche Capturemutationen binden den begrenzten Nachweis.
Der einzige native Versuch besteht einschließlich eigenem Cleanup und
unveränderten Docker-/Statebeständen. Die private Baselinekorrektur und die
Aussagegrenzen stehen im kanonischen OPS-008-Laufzeitnachweis. Produktcode,
ABI, Versionen und Maturityflags bleiben unverändert; OPS-008 bleibt partiell.
Das neue Retentionsbudget ist mit einem von einem Versuch abgeschlossen.
Der frühere SMTP-Erfolg mit drei von drei Versuchen und das nicht qualifizierte
Multiple-Session-Budget mit zwei von zwei bleiben unverändert. Weitere
Mailfälle und tatsächliche Maintenance-Ausführung sind eigenständige offene
Teilumfänge; öffentliche neue Funktionsverträge bleiben freigabepflichtig.

## Zurückgestellter SSIS-Backlog vom 16. Oktober 2026

Der Benutzer hat die [vertiefte Legacy-Loganalyse](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#backlog-vertiefte-legacy-loganalyse-vom-16-oktober-2026)
unter `SSIS-001` ausschließlich für spätere Entwicklung vormerken lassen.
Der vollständige Plan und der Eintrag in
`Metadata/Quality/Future_Enhancement_Backlog.csv` umfassen Komponentenphasen,
Zeilenflüsse, Lookup-/Cachewerte, Provider- und Taskoperationen, Fehlerbezüge,
Transaktionen, Checkpoints sowie optionale historische Vergleiche und eigene
strukturierte Kennzahlen. Die bereits vorhandenen Legacy- und Katalogkerne,
gespeicherte Meldungen als Default, Parameter, Schemas und Statusflags werden
durch diese Dokumentationsablage nicht geändert. `SSIS-001` bleibt
`PARTIAL_PRODUCT_FUNCTION`. Dieser Backlogauftrag aktiviert weder Umsetzung
noch neue Runtimeversuche oder Labentwicklung; bestehende Abnahmegrenzen und
geschlossene Budgets bleiben erhalten. Die nachfolgenden früheren
Entwicklungsaufträge erteilen keine Freigabe für diese neue Erweiterung.

Am 17. Oktober 2026 wurde die
[priorisierte Entwicklungsreihenfolge](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#priorisierte-entwicklungsreihenfolge-und-abnahme)
mit acht Schritten, ihren Abhängigkeiten und den jeweiligen Abnahmekriterien
im selben Backlog ergänzt. Sie ersetzt die frühere grobe Vier-Schritte-Tabelle
und sieht Historie vor eigenen strukturierten Kennzahlen vor. Die tatsächlichen
Abhängigkeiten sind ausdrücklich nicht durchgehend linear. Auch dieser Auftrag
gilt ausschließlich für die Planungsablage; er aktiviert keinen der acht
Entwicklungsschritte und keine neue Runtimeabnahme.

## Aktuelle SSIS-Kataloglieferung vom 16. Oktober 2026

Die veröffentlichte Windows-/SSISDB-Lab-Abnahme liegt vor. Die verwendete
Lab-Quelle ist auf Commit `6de11919a5b2c6f05552c8b49979d08bd0268d1a` gebunden.
Der Benutzer hat den konkreten Katalogvertrag und die separate eigene Framework-Testdatenbank
ausdrücklich freigegeben. Die Katalogprocedure ist implementiert; der
[begrenzte Windowsnachweis](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#katalogkernabnahme-vom-16-oktober-2026)
bestätigt neun native Consumerfälle und die Ausgabearten auf SQL Server 2025.
Zwei private Orakelfehler bleiben FAILED_NOT_QUALIFIED; Versuch 3 besteht.
Das Budget 3/3 bleibt geschlossen, die eigene Testdatenbank ist entfernt,
Quelle und übriger Datenbankbestand sind unverändert. Erforderliche exakte
Head-CI und reguläre Integration gehören weiterhin zum Lieferabschluss.

SSIS-001 bleibt partiell. Die spätere begrenzte Legacy-Providerabnahme ist oben
getrennt dokumentiert. Positive Task-/Schleifen-, Performance-/Verbose-, Phasen-,
RowFlow- und Least-Privilege-Nachweise bleiben offen; diese Dokumentationsintegration
aktiviert keine neuen Umgebungen oder Testwellen. WI-0009 GATE-0001 bleibt offen.
Bereits abgeschlossene Slices und ihre geschlossenen Budgets werden nicht
erneut geprüft. Die älteren SSIS-Wartevermerke beschreiben den vorherigen Stand.

## WI-0009: qualifizierter portabler Kern und offenes Feature-Gate

Der freigegebene lokale Analyzer ist implementiert. Die native Abnahme auf
SQL Server 2025 und 2019 bestätigt leere Kataloge, acht Exportschemas und
Caller-/Quellenerhaltung. Private identitätsgebundene Projektionen prüfen
Referenzzustände und sechs getrennte Quellenfehlerpfade; sie werden nicht als
positive echte External-Table-Kataloge ausgegeben. Der
[begrenzte Nachweis](WI0009_Local_Metadata_Runtime_Evidence_2026-10-14.md)
benennt den erhaltenen ersten Fehlversuch und die Wiederverwendung seiner
fünf bestandenen Einzeltests. Das eigene Budget ist mit drei von drei
Versuchen abgeschlossen. Positive echte Tabellen- und Referenzdaten benötigen
eine eigene externe Quelle und geeignete Lab-Funktion; dieses Gate bleibt
offen. Die reguläre Integration über PR #385 und die Synchronisierung auf
main sind abgeschlossen.

## Aktueller WI-0005-Abschluss vom 14. Oktober 2026

Der freigegebene Zeitgrenzenvertrag ist implementiert und nativ qualifiziert.
Der siebte SQL-2025-Lauf besteht die fehlenden Fehler-, Berechtigungs- und
Uhrbasisproben mit gebundener Wiederverwendung früherer erfolgreicher
Einzeltests. Anschließend besteht der einzige SQL-2019-Fallback. Alle acht
tatsächlichen Versuche bleiben gezählt; die sechs früheren Primärläufe
bleiben nicht qualifiziert. Quellen, Caller, eigene SQL-Ressourcen und
öffentlicher Runtime-Cleanup sind geprüft. Der
[kanonische Laufzeitnachweis](WI0005_TimeBounds_Runtime_Evidence_2026-10-14.md)
benennt Bindungen und Aussagegrenzen. Die folgenden älteren Absätze halten
den Verlauf fest und erteilen keine weitere Runtimefreigabe. Die reguläre Integration über PR #383 und die Synchronisierung auf main sind abgeschlossen.

WI-0006/0007 sind implementiert und mit elf gezählten gemeinsamen Versuchen
nativ qualifiziert. Der [Nachweis](WI0006_WI0007_Runtime_Evidence_2026-10-14.md)
trennt neun erhaltene Gesamtfehler von den erfolgreichen Primär- und
Fallbackläufen sowie der gebundenen Wiederverwendung. Die reguläre Integration
über PR #384 ist abgeschlossen. Die Funktionsquellen 250 und 020 bleiben
gegenüber der nativen Abnahme unverändert; korrigierte gemeinsame Helfer
und Testfixtures bestehen das aktuelle funktionale Head-Gate.
WI-0009 ist mit qualifiziertem portablem Kern regulär geliefert; das positive
External-Table-Gate bleibt offen. SSIS wartet weiterhin auf die angeforderte
Windows-/SSISDB-Funktion einschließlich veröffentlichter ausgeführter Abnahme.

## Aktueller Fertigstellungsauftrag vom 13. Oktober 2026

Der Benutzer verlangt die Fertigstellung und priorisiert tatsächlich fehlende
Funktionen vor zusätzlichen Nachweisen bereits funktionierender Teilbereiche.
Dieser Auftrag ersetzt die nachstehende ältere Reife-zuerst-Reihenfolge.
Er setzt keine Sicherheits-, Datenschutz-, unabhängigen Review- oder
Liefergates außer Kraft. Die Funktionstests folgen weiterhin ausschließlich
der kanonischen CI-Teststrategie. Unveränderte erfolgreiche Prüfungen werden
nicht erneut ausgeführt.

Die Priorisierung beruht auf aktuellem Code und den fachlichen Zielverträgen.
Die Zahl RESEARCHED_NOT_IMPLEMENTED in der Statusliste ist keine verlässliche
Zahl fehlender Procedures: WI-0004 besitzt bereits die implementierte
geordnete Columnstore-Inventur; die freigegebene Segmentüberlappung ist nun ebenfalls nativ qualifiziert.
WI-0010 ist ein Intake, kein noch zu implementierendes Analyseverfahren.
Die Statusabweichungen werden bei der betroffenen fachlichen Lieferung
synchronisiert, ohne vorhandene Implementierung erneut zu entwickeln.

| Reihenfolge | Tatsächliche Funktionslücke | Nächster konkreter Abschluss |
|---|---|---|
| 1 | WI-0005: Der freigegebene Zeitgrenzenvertrag ist regulär geliefert. | Abgeschlossen; unveränderte erfolgreiche Nachweise werden nicht wiederholt. |
| 2 | SSIS-001: Katalog- und Legacy-Kern sind geliefert und begrenzt nativ geprüft; weitere Funktionen und Fachnachweise fehlen. | Die vier Legacy-Providerfälle sind mit zwölf gebundenen Einzelprüfungen abgeschlossen; zusätzliche Loggingquellen und der zurückgestellte Erweiterungsbacklog bleiben offen. |
| 3 | WI-0006: Compile-Kontext ist implementiert und nativ qualifiziert. | Über PR #384 regulär integriert; unveränderte erfolgreiche Nachweise werden nicht wiederholt. |
| 4 | WI-0007: Aggregierte External-Model-Inventur ist implementiert und nativ qualifiziert. | Gemeinsam mit WI-0006 über PR #384 regulär integriert. |
| 5 | WI-0009: Lokale External-Data-Analyse ist implementiert; der portable Kern ist nativ qualifiziert. | Über PR #385 regulär integriert; das positive External-Table-Gate bleibt bis zu einer geeigneten eigenen Quelle offen. |
| 6 | WI-0004: Der freigegebene begrenzte Opt-in-Vertrag ist implementiert und auf den erforderlichen nativen Engines qualifiziert. | [Abnahme und Grenzen](WI0004_Segment_Overlap_Runtime_Evidence_2026-10-15.md) sind dokumentiert; unveränderte erfolgreiche Nachweise werden nicht wiederholt. |

Die neue öffentliche Diagnosefläche bleibt konkret freigabepflichtig.
Für WI-0005 liegt die [Freigabevorlage](../../../Documentation/Architecture/WI0005_Time_Bound_Extended_Events_Public_Specification.md) vor.
Der Benutzer hat diesen Vertrag am 13. Oktober 2026 unmittelbar freigegeben.
Die übrigen neuen Verträge werden mit
Quellen-, Kosten-, Datenschutz- und Abnahmegrenzen vorgelegt; bereits
freigegebene Verträge werden nicht erneut zur Zustimmung gestellt.

Die lokale WI-0005-Implementierung ist noch nicht nativ qualifiziert oder
integriert. Im ersten SQL-Server-2025-Lauf bestanden die acht ausgewählten
Testdateien einschließlich der elf neuen TABLE-/JSON-Fälle, Neustart und
automatischer Beendigung. Danach scheiterte der private Adapter an einer
SQLCMD-Direktive; der Gesamtlauf bleibt nicht qualifiziert. Nach der engen
Adapterkorrektur scheiterte der zweite Lauf im ersten aktivierten Zeitgrenzenfall
an der kombinierten Prüfung von Katalogidentität und Runtime-Startzeit. Seine
Ursache bleibt unbekannt, weil die betroffene Quellenzeile vor dem Abbruch
nicht gespeichert wurde. Beide Läufe haben ihre eigenen Runtime-Ressourcen
entfernt und unveränderte Quellenpins sowie Dockerbestände bestätigt.
Das ursprüngliche 2025-Budget war mit zwei von zwei Versuchen ausgeschöpft. Die vorbereitete
Diagnose ergänzt Quellenklammern und Ausgabe vor Assertions, ohne den exakten
Zeitvergleich zu lockern. Ein weiterer nativer Lauf benötigt eine ausdrückliche
Budgeterweiterung; es wird kein Produktabschluss aus Teilprüfungen abgeleitet.
Der Benutzer hat anschließend höchstens sechs Gesamtversuche für WI-0005
freigegeben. Jeder weitere Versuch setzt einen konkreten Befund oder eine
gezielte Gegenprüfung mit begründeter Aussicht auf die Problemlösung voraus.
Die bisherigen zwei Versuche werden nicht zurückgesetzt. Die ergänzte
Quellenretention und ihre unverändert strengen Fehlerflags sind unabhängig
geprüft; der nächste Lauf soll die fehlenden Vergleichsdaten sichern oder
die Abnahme abschließen. Ein automatisches Ausschöpfen der Obergrenze ist
nicht autorisiert.

Der dritte tatsächliche Lauf bleibt ebenfalls nicht qualifiziert. Die ergänzte
Retention hat diesmal im Defaultfall unveränderte native Session-IDs und
Runtimeadressen bei geringfügig verschiedenen Startzeitwerten gesichert.
Der Abbruch entstand an der exakten Vorher-/Nachher-Zeitbedingung der Fixture.
Dieser Befund begründet einen begrenzten Orakelvergleich entsprechend
[Common151](../../../Code/Tests/Common/151_XESessions_Collation_Runtime_Contract.sql):
exakte Identitäts- und Adressbindung, erhaltene NULL-Regeln und höchstens
zehn Millisekunden Abweichung gegen beide Quellenaufnahmen. Die
gleichaufrufbezogene physische TABLE-/JSON-Parität bleibt exakt. Die neue
Korrektur und ihre Grenzproben werden vor weiterer Runtime eng geprüft.
Die konkrete Ursache des zweiten Laufs bleibt unbekannt; aus dem dritten
Lauf wird weder dessen Ursache noch eine allgemeine Zeitgarantie abgeleitet.
Eigener Runtime-Cleanup, Quellenpins und Bestandsvergleich bestanden erneut.
Das Gesamtbudget steht jetzt bei drei von höchstens sechs Versuchen über alle
Engines; die Zählung bleibt bei einem Versions- oder Lanewechsel erhalten.

Der vierte Lauf besteht die korrigierte Testdatei mit elf TABLE-/JSON-Fällen,
Neustart und automatischer Beendigung sowie die Regexmatrix und sechs
RAW-/CONSOLE-/NONE-Fälle. Der Gesamtlauf bleibt nicht qualifiziert, weil die
private Fehlerprobe mit `RAISERROR(1222, ...)` tatsächlich Fehler 2732 erzeugt
hat. Der Analyzer hat diesen tatsächlichen Fehler erhalten; die angenommene
Fehlererzeugung war ungeeignet. Die gezielte private Korrektur verwendet einen
gehaltenen Lock auf einer eigenen synthetischen Tabelle für Fehler 1222 und
einen dynamischen Zugriff mit explizitem SELECT-Verbot für Fehler 229.
Diese Fehler werden in privaten Procedurekopien erzeugt und belegen keine
tatsächlichen DMV-Berechtigungsfehler. Ein separater eingeschränkter Principal
prüft den unveränderten Analyzer. Quellen-, Caller- und Cleanupbindungen
werden vor dem nächsten Lauf eng geprüft. Unveränderte bestandene Testfälle
aus Lauf vier werden über ihre Quellen, gemeinsame Abhängigkeiten und
gespeicherten Ausgaben wiederverwendet. Das Gesamtbudget steht bei vier von
höchstens sechs tatsächlichen Versuchen; Lauf fünf ist noch nicht gestartet.
Für den versionsabhängigen Fallback ist anschließend ausschließlich eine
gezielte native SQL-Server-2019-Prüfung vorgesehen. Sie prüft den ältesten
unterstützten Zweig; SQL Server 2022 erhält keinen zusätzlichen Lauf ohne
einen eigenständigen Versionsbefund.

Der Benutzer hat auch den konkreten WI-0006-Vertrag unmittelbar freigegeben:
eine rein lesende `monitor.USP_CompileContextAnalysis` mit ausgewähltem
Datenbank-Konfigurationskontext sowie getrenntem serverweitem Counter-,
Compile-Wait- und Cachemetadatenkontext. Die bereits vorhandene generische
Konfigurationsausgabe und die typisierten Counter-Samples werden wiederverwendet;
sie sind keine fehlenden Produktfunktionen. Der neue Vertrag erlaubt optionales
Sampling von einer bis 60 Sekunden, keine SQL- oder Planinhalte und keine
automatische Ursachenbehauptung.

Die echte SSISDB-Abnahme wartet auf die vom Benutzer in SQL_Server_Lab
beauftragte Windows-/SSISDB-Testfunktion. Bis dieser öffentliche Pfad
einschließlich ausgeführtem Nachweis verfügbar ist, wird dieses Thema
zurückgestellt. Es wird keine Ersatzinstanz installiert oder eine Linuxquelle
als SSISDB-Abnahme ausgegeben. Unabhängige freigegebene Funktionen werden
weiterentwickelt.

Zusätzliche gemischte Mailstatus-Retention wird zunächst zurückgestellt.
Der integrierte SMTP-Erfolg mit Budget3/3, die integrierte Retention mit
Budget1/1 und der nicht qualifizierte Multiple-Session-Versuch mit Budget2/2
bleiben abgeschlossen beziehungsweise ausgeschöpft. Es gibt keinen
Budgetreset und keine neue Zählung desselben Versuchs.

Der Fertigstellungsnachweis trennt implementierte Produktfunktionen,
ausstehende Tests, externe Komponenten und optionale Zukunftsarbeit.
Fleet-Komponenten, isolierte Restore-/CHECKDB-Hostausführung sowie Datei- und
ISPAC-Adapter werden nicht stillschweigend in den SQL-Kern aufgenommen.
Benötigte Plattform- oder Infrastrukturfreigaben werden erst mit benanntem
Ziel und konkreter Aktion angefragt. Produktstatus wechselt ausschließlich
nach tatsächlich erfülltem Funktions- und Abnahmevertrag.

## Wiederaufnahme nach der Entwicklungspause

Der Benutzer hat nach Abschluss von WI-0011 einschließlich PR-Merge nach
`origin/main` eine Pause angeordnet und anschließend die autonome
Weiterentwicklung nach den bestehenden Regeln ausdrücklich wieder aufgenommen.
Die bestehende automatische Fortsetzung ist wieder aktiv. Der aktuelle
Wiedereinstieg erfolgt nach dem integrierten Stand von PR #271. Die Agent-
Historienaggregate von OPS-008 und die gemeinsamen Mengenlimits sind im
dokumentierten Teilumfang geprüft. Der anschließende begrenzte Reifeschritt
belegt injizierte nicht leere Mail- und Maintenance-Aggregate mit erhaltenen
Quellwerten und Callerzustand. Tatsächliche eigene Agent-Ausführung sowie
eine getrennte native datumsgebundene Agent-Historienbereinigung sind ebenfalls
belegt. Eine getrennte native Backup-/Restore-Historienbereinigung bestätigt
drei, ein und null eigene Paare mit kontrollierten Zeitstempeln und erhaltenen
jüngeren Historienwerten. Ein weiterer nativer Purge bestätigt drei, eine und
null injizierte Failed-Mailzeilen bei deaktivierten Mail-XPs und erhaltenen
jüngeren Mailitemwerten. Ein getrennter nativer Maintenance-Purge bestätigt
drei, eine und null injizierte Elternzeilen mit erhaltenen jüngeren Werten;
Plans, Subplans und Detailhistorie bleiben leer. Vier getrennte Mailstatusfälle
prüfen die injizierten Status unsent, sent, failed und retrying mit erhaltenen
älteren Gegenproben der jeweils anderen Status. Eine getrennte Fixture
bestätigt einen tatsächlichen eigenen lokalen Mailfehler mit nativem
Failed-Status, gebundenem Prozessfehlerlog, drei Consumerparitäten und
eigenem Mail-/Profil-/Kontocleanup. Eine getrennte native Logretentionfixture
bestätigt drei, eine und null ausgewählte Prozessfehlerlogs aus drei eigenen
Mailfehlern mit kontrollierten Logzeiten. Jüngere und erfasste übrige Logwerte
sowie sämtliche Mailitems bleiben bei neun Consumeraufrufen erhalten;
das Callerrollback stellt die ursprünglichen ausgewählten Logwerte wieder her.
Eine getrennte Anlagenfixture bestätigt native Mailpurges mit drei, einer
und null injizierten Mailzeilen sowie sechs, zwei und null Binäranlagen.
Vollständige jüngere Mail-/Anlagenwerte und neun Consumerparitäten bleiben
erhalten; das Rollback entfernt sämtliche injizierten Zeilen.
Eine getrennte Maintenance-Detailfixture bestätigt nach zwei nativen
Datums-/NULL-Planfilterpurges drei, eine und null injizierte Elternzeilen
sowie sechs, zwei und null verknüpfte Details. Vollständige jüngere Eltern-
und Detailwerte, neun Consumerparitäten und Callerzustand bleiben erhalten;
das Rollback entfernt sämtliche injizierten Zeilen.
Eine getrennte selektive Plan-ID-Fixture bestätigt Zielcounts drei, eins und
null bei Gesamtcounts fünf, drei und zwei sowie Detailcounts zehn, sechs und
vier. Vollständige jüngere Zielwerte, ältere Gegenproben mit anderem und
NULL-Plan sowie neun Consumerparitäten bleiben erhalten. Ein nicht passender
Planfilter erhält sämtliche Quellwerte; das Rollback entfernt alle Zeilen.
Eine getrennte selektive Subplan-ID-Fixture bestätigt Zielcounts drei, eins
und null bei Gesamtcounts sechs, vier und drei sowie Detailcounts zwölf,
acht und sechs. Jüngere Zielwerte, ältere Gegenproben und sämtliche Subplan-
und Jobmetadaten bleiben erhalten. Neun Consumerparitäten und Callerzustand
bleiben erhalten; das Rollback entfernt alle Zeilen und den deaktivierten
eigenen Job ohne Steps, Serverzuordnung oder Historie. Eine getrennte native
Filtergrenzfixture bestätigt die Ablehnung gleichzeitiger Plan-/Subplan-IDs
mit Fehler 2732 auf SQL Server 2025. Bei XACT_ABORT OFF bleiben Quellwerte,
neun Consumerparitäten und committable Callerzustand erhalten; ein zusätzlicher
ON-Fall bestätigt die uncommittable eigene Transaktion vor ihrem Rollback.
Die abschließende Wiederherstellung von Locktimeout und XACT_ABORT ist geprüft.
Die vier bestehenden Maintenance-Retentionfixtures stellen Locktimeout und
XACT_ABORT nun direkt im Callerbatch wieder her. Der gemeinsame native Lauf
bestätigt 36 Consumeraufrufe und die ursprünglichen beiden Optionen nach
vier Rollbacks. Eine getrennte private Probe bestätigt acht
Fehlerfälle mit ursprünglichem XACT_ABORT OFF oder ON sowie vier frühe
Locktimeout-31-Ablehnungen auf jeweils derselben Verbindung mit leeren Quellen.
Die vier injizierten Mailfixtures stellen beide Optionen nun ebenfalls direkt
im Callerbatch wieder her. Der gemeinsame native Lauf bestätigt 63
Consumeraufrufe und sieben Rollbacks; eine getrennte private Gegenprobe
bestätigt acht Fehlerfälle und vier frühe Ablehnungen bei erhaltenen Optionen,
sieben leeren Mail-/Maintenancequellen und deaktivierten Mail-XPs. Der
gemischte Fehlerpunkt liegt nach dem ersten Einzeilenaufbau; der Statusfehler
betrifft ausschließlich den ersten unsent-Fall. Die beiden tatsächlichen
Agentfixtures stellen nun ebenfalls beide Optionen direkt im Callerbatch
wieder her. Der gemeinsame native Lauf bestätigt zwölf Consumeraufrufe und
vier Rollbacks mit eigenem Jobcleanup. Eine getrennte private Gegenprobe
bestätigt vier Fehlerfälle mit ursprünglichem OFF oder ON und zwei frühe
Locktimeout-31-Ablehnungen mit erhaltenen Optionen und sechs leeren
Agentquellen auf derselben Verbindung. Die Fehlerpunkte folgen bestätigtem
Jobabschluss; bei Retention ist nur Phase 1 belegt. Die Backup-/Restore-
Retentionfixture restauriert beide Optionen nun ebenfalls direkt im Callerbatch.
Der native Lauf bestätigt neun Consumeraufrufe und drei Rollbacks mit eigenem
Erfolgscleanup. Eine getrennte private Gegenprobe bestätigt zwei Fehlerfälle
mit ursprünglichem OFF oder ON und eine frühe Locktimeout-31-Ablehnung in
zwei neuen Labs. Nach beiden Fehlern bleiben Optionen, genau gebundene eigene
Datenbanken, acht Historienquellen und acht Katalogfelder auf derselben
Verbindung erhalten; erst das äußere Labcleanup entfernt diese Ressourcen.
Der Fehlerpunkt betrifft ausschließlich Phase 1 vor dem ersten Consumer.
Die beiden tatsächlichen nativen Mailfixtures restaurieren beide Optionen nun
ebenfalls direkt im Callerbatch. Die getrennten normalen Läufe bestätigen zwölf
Consumeraufrufe, zwei Rollbacks, eigenes Erfolgscleanup sowie Queue- und
Konfigurationswiederherstellung. Eine getrennte private Gegenprobe bestätigt
vier Fehlerfälle mit ursprünglichem OFF oder ON und zwei frühe Locktimeout-31-
Ablehnungen in vier neuen Labs. Nach Fehlern bleiben Optionen, vollständige
eigene Mail-, Profil-, Konto- und genaue Bindungswerte auf derselben Verbindung
erhalten; beide Logfälle bestätigen zusätzlich Originalwerte derselben vier
ausgewählten Logs nach Rollback. Mail-XPs bleiben deaktiviert und Transaktionen
geschlossen; erst das äußere Labcleanup entfernt verbliebene Ressourcen.
Fehlerpunkte ausschließlich vor dem ersten Consumer und bei Logretention nur
Phase 1. Die älteren dynamischen Restores sind damit korrigiert. Die drei
älteren Fenster- und Agent-Aggregatfixtures restaurieren nun XACT_ABORT direkt
im Callerbatch und setzen keinen Locktimeout. Die beiden normalen Szenarien
bestätigen elf NONE-Aufrufe, unveränderten ursprünglichen Locktimeout,
kontrollierte Fenster und Dateiwachstum sowie das eigene Agentrollback.
Eine getrennte private Gegenprobe bestätigt neun Fälle in fünf neuen Labs:
drei frühe TX1-Ablehnungen mit ursprünglichem OFF sowie sechs injizierte Fehler
mit ursprünglichem OFF oder ON, jeweils bei Locktimeout 31. Optionen und
Callerbasis bleiben auf derselben Verbindung erhalten. Fensterfehler erhalten
acht vollständige Historienquellen, acht Datenbankkatalogfelder und genaue
eigene Datenbankbindungen; das Agentrollback erhält sechs ursprüngliche
Agentquellen. Die Fehlerpunkte betreffen nur das erste Backup, den ersten
Restore und die erste injizierte Agentzeile vor dem folgenden Consumer.
Das äußere Labcleanup entfernt verbliebene Fensterressourcen. Die
Failed-Mailretention ergänzt nun einen zweiten getrennten Fall mit explizitem
NULL-Datum und Failed-Statusfilter. Drei Zielzeilen aus 2000, 2025 und 2030
verschwinden; drei ältere unsent-, sent- und retrying-Gegenproben bleiben
mit sämtlichen Werten erhalten. Der normale Lauf bestätigt insgesamt 15
Consumeraufrufe und zwei Rollbacks. Ein privater Lauf bestätigt den
unveränderten Erfolg mit ursprünglichem XACT_ABORT ON und die Ablehnung
einer endlichen Datumsgrenze mit 55185. Optionen, TX0, drei leere Mailquellen
und deaktivierte Mail-XPs bleiben nach beiden Teilfällen auf derselben
Verbindung erhalten. Der Gesamtlauf scheitert am dritten privaten Orakel
mit 56091: Beide NULL-Filter sind keine gültige All-Delete-Auswahl. Beide
eigenen Labs wurden entfernt. Eine anschließende getrennte Diagnose erfasst
bei beiden NULL-Filtern den ursprünglichen SQL-Fehler 14608 und Prozedur-Enum
OTHER in Fall 2, Phase 2 nach zwölf Consumeraufrufen. Sechs vollständige
Mailitemwerte bleiben vor Rollback erhalten. Die gültige All-Status-Gegenprobe
mit Datum 2031 entfernt alle sechs Zeilen und wird mit 55185 im selben Slot
zurückgewiesen. Beide Fälle restaurieren ursprüngliches OFF, Locktimeout -1,
TX0, drei leere Mailquellen und deaktivierte Mail-XPs. Der Diagnoselauf ist
COMPLETED; sein eigenes Lab wurde mit zwei Cleanupschritten ohne Fehler
entfernt. Diese beiden vorbereiteten Nachweise sind damit ausgeführt.
Die bestehende AgentHistory-Fixture ergänzt drei synthetische Joboutcomes
für Schaltag, Uhrzeit und eine codierte Dauer von 100 Stunden. Zwölf
NONE-/JSON-Consumeraufrufe bestätigen sechs unveränderte Agentquellen,
Callerzustand und Rollback. AgentJobs liefert 0, 85 und 360.000 Sekunden;
AgentMonitoring erhält die codierten Rohdauern. Die lokalen Startzeitpunkte
folgen dem letzten Outcome nach instance_id; Msdb-Agentzeitgrenzen bleiben
NULL. Coreinstallation, Smoke und Runtimevertrag 122 bestehen auf SQL Server
2025 mit CL170; das eigene Lab ist entfernt. Der damalige Joboutcomeslice
belegt keine Step-Dauern. Der folgende Step-Slice ergänzt zwei TSQL-
Stepdefinitionen des deaktivierten eigenen Jobs und drei injizierte Step-
Datums-/Dauerfälle. Alle zehn
JSON-Felder beider Steps, Historycounts acht, zehn und zwölf sowie unveränderte
Joboutcomes bestehen bei 21 Consumeraufrufen auf SQL2025/CL170. Eine jeweils
jüngere Historyzeile des anderen Steps prüft die Auswahl getrennt je Step.
Eigene Steps, Job und Historie werden zurückgerollt; das neue eigene Lab ist
entfernt. Dieser injizierte Stepumfang belegt keine tatsächliche Stepausführung,
kein Retryverhalten und keine ungültigen Kalenderwerte. Weitere Datums-/Dauergrenzen
und tatsächliche Agentdauer bleiben für diesen Umfang offen.
Ein anschließender statischer Nachweis schließt Integerüberläufe ausschließlich
in den beiden identischen AgentJobs-Dauerformeln für den deklarierten
`int`-Bereich aus. Die konservative Betragsgrenze beträgt 773.098.839;
native Endpunktfälle, fehlerhafte Dauerformate und andere Datums- oder
Procedurearithmetik sind damit nicht belegt.
Eine getrennte private Kalendergegenprobe besteht auf SQL Server 2025
17.0.4075.5 mit CL170. 20230229 und 20240230 werden jeweils als Job- und
Stepoutcome injiziert. Vier direkte native Orakel messen Fehler 242;
zwölf Consumeraufrufe und eine fehlerfreie Monitoring-Baseline erhalten
sechs vollständige Agentquellen. AgentJobs meldet ERROR_HANDLED/Partial
in allen vier Fällen und erhält bei ungültigem Step den gültigen Joboutcome.
Monitoring meldet bei ungültigem Job AVAILABLE_LIMITED/Partial; bei
ungültigem Step bleibt der gültige Joboutcome ohne Partial erhalten.
Msdb liefert unveränderte Counts und NULL-Agentzeitgrenzen. XACT_ABORT OFF,
Locktimeout 31 und committable TX1 bleiben während der Fälle erhalten;
vier Rollbacks restaurieren die ursprünglichen Quellen. Abschließend
werden ursprüngliches OFF, Locktimeout -1 und TX0/XACT_STATE 0 bestätigt.
Eigenes Lab und State sind entfernt. Weitere ungültige Daten, Uhrzeiten,
XACT_ABORT ON und tatsächliche Stepausführung bleiben offen.
Eine anschließende private Uhrzeitgegenprobe bestätigt auf derselben
Engineversion mit CL170 vier Job-/Stepfälle für 236060 und 240000 bei
gültigem Datum 20240229. Vier native Fehler 242, zwölf Consumeraufrufe,
eine fehlerfreie Baseline, sechs vollständige Quellbestände und vier Rollbacks
bestätigen dieselben begrenzten Fehler- und Arrayzustände. Das eigene Lab
und State sind entfernt. 236060 verändert Minuten und Sekunden gemeinsam;
isolierte Teilfeldgrenzen, andere Uhrzeitwerte und XACT_ABORT ON bleiben offen.
Eine spätere private tatsächliche Agent-Retrygegenprobe besteht auf SQL2025
17.0.4075.5/Docker mit CL170. Ein eigener TSQL-Step mit einem konfigurierten
Retry und Intervall 0 erzeugt nach kontrolliertem Erstfehler nativ drei Zeilen:
Retrystatus 2, Steperfolg 1 und Joberfolg 1. retries_attempted ist in allen
drei Zeilen 0; AgentJobs erhält diesen gespeicherten Erfolgswert. Vier
NONE-/JSON-Aufrufe bestätigen Msdbcount drei, den letzten erfolgreichen Step,
dessen Ausschluss im Problemfilter und den informativen deaktivierten
Jobgesamtoutcome im Monitoring. Sechs vollständige Quellen und committable
TX1 mit XACT_ABORT ON und Locktimeout 31 bleiben erhalten. Ein Rollback,
eigenes Jobcleanup und finale Optionsrestauration bestehen; Lab und State
sind entfernt. Zwei vorherige private Läufe scheitern vor dem ersten Consumer
mit Orakelfehler 56147. Nur der zweite misst die tatsächliche
Statusfolge und den gespeicherten Wert 0; diese Orakelerwartung wird vor
dem Final korrigiert. Beide fehlgeschlagenen Labs sind ebenfalls entfernt.
Retryerschöpfung, positive Intervalle, Parallelität und innere Fehlercleanup-
Gegenproben bleiben offen. Weitere Filter- und Retentiongrenzen bleiben
eigenständig autorisiert.
Eine weitere private SQL2025-17.0.4075.5/Docker-Gegenprobe mit CL170
bestätigt Retryerschöpfung: Der TSQL-Step eines eigenen aktivierten Jobs
scheitert in beiden Versuchen mit einem konfigurierten Retry und Intervall 0.
Drei native Zeilen zeigen Retrystatus 2, Stepfailure 0 und Jobfailure 0;
die letzte Stepzeile speichert retries_attempted 1. Vier NONE-/JSON-Aufrufe
erhalten sechs vollständige Quellen und committable TX1 mit ON und
Locktimeout 31. Beide AgentJobs-Filter enthalten den letzten failed Step;
Monitoring meldet LATEST_JOB_RUN_FAILED_IN_WINDOW/HIGH ohne Consumerfehler.
Ein Rollback, eigenes Jobcleanup und finale Optionsrestauration bestehen.
Lab und State sind entfernt; dieser Umfang hat keinen vorausgehenden
nativen Fehlversuch. Positive Intervalle, Parallelität und innere
Fehlercleanup-Gegenproben bleiben offen.
Eine getrennte private SQL2025-17.0.4075.5/Docker-Probe mit CL170 bestätigt
automatische Agentretention mit vier Zeilen pro Job. Drei erfolgreiche
Läufe eines eigenen aktivierten Jobs mit einem TSQL-Step hinterlassen
zwei, vier und vier Historyzeilen. Das erste instance_id-Paar verschwindet;
sämtliche Werte des zweiten Paars bleiben erhalten. Zwölf NONE-/JSON-Aufrufe
erhalten sechs vollständige Quellen und ON31TX1. AgentJobs erhält den letzten
erfolgreichen Step; der Problemfilter zeigt keinen Step. Monitoring meldet
ENABLED_JOB_WITHOUT_SCHEDULE/INFO ohne Consumerfehler. Drei Rollbacks,
eigenes Jobcleanup, finale Optionsrestauration und äußerer Labcleanup bestehen.
Die Linuxkonfiguration wird im neuen eigenen Container gesetzt, aus der
Konfigurationsdatei zurückgelesen und mit öffentlichem Lab-Restart angewandt.
Zwei vorausgehende Readbackguards scheitern vor Restart und Frameworktest;
nur die zweite Diagnose misst beim bisherigen get-Aufruf Exit 0 mit der
Meldung, dass der Schlüssel nicht gefunden wird. Beide Labs sind entfernt.
Die globale Grenze 64 wird nicht erreicht; Altersretention, Parallelität
und innere Fehlercleanup-Gegenproben bleiben ungeprüft.

Eine getrennte private SQL2025-17.0.4075.5/Docker-Probe mit CL170 bestätigt
die globale Agent-Historiengrenze sechs bei einer Grenze vier pro Job.
Vier tatsächliche erfolgreiche Einstepläufe zweier eigener aktivierter Jobs
in der Reihenfolge A, B, A, B hinterlassen zwei, vier, sechs und sechs Zeilen.
Das erste A-Paar verschwindet; sämtliche Werte der beiden jüngeren Paare
bleiben erhalten. Kein Job überschreitet vier erzeugte Zeilen.
Sechzehn NONE-/JSON-Aufrufe erhalten sechs vollständige Quellen und
committable ON31TX1. AgentJobs erhält die letzten erfolgreichen Steps;
der Problemfilter zeigt keine Steps. Monitoring meldet für jeden vorhandenen
Job ENABLED_JOB_WITHOUT_SCHEDULE/INFO ohne Consumerfehler. Vier Rollbacks,
beide eigenen Jobcleanups, finale Optionsrestauration und äußerer Labcleanup
bestehen. Dieser Umfang hat keinen vorausgehenden nativen Fehlversuch.
Andere Limits, Altersretention, Parallelität und innere Fehlercleanup-
Gegenproben bleiben ungeprüft.

Eine getrennte private SQL2025-17.0.4075.5/Docker-Probe mit CL170 bestätigt
einen tatsächlichen erfolgreichen Retry bei Intervall einer Minute.
Ein eigener TSQL-Step erzeugt nach kontrolliertem Erstfehler nativ
Retrystatus 2, Steperfolg 1 und Joberfolg 1. Mindestens 50 getrennte
Pollzyklen erfassen den noch nicht abgeschlossenen Job bei vorhandener
Retryzeile; die gemessene Spanne bis zum beobachteten Abschluss beträgt
mindestens 50 Sekunden. Der erfolgreiche Step speichert retries_attempted
0; AgentJobs erhält diesen Wert und schließt den älteren Retry im
Problemfilter aus. Nach eigener Jobdeaktivierung meldet Monitoring
JOB_STATE_INFORMATIONAL/INFO ohne Consumerfehler. Vier NONE-/JSON-Aufrufe
erhalten sechs vollständige Quellen und committable ON31TX1. Ein Rollback,
eigenes Jobcleanup, finale Optionsrestauration und äußerer Labcleanup bestehen.
Consumer während des laufenden Jobs, andere Intervalle, positive
Retryerschöpfung, Parallelität und innere Fehlercleanup-Gegenproben bleiben
ungeprüft.

Eine getrennte private SQL2025-17.0.4075.5/Docker-Probe mit CL170 bestätigt
tatsächliche Retryerschöpfung bei Intervall einer Minute. Beide Versuche
eines eigenen TSQL-Steps scheitern kontrolliert; drei native Zeilen zeigen
Retry 2, Stepfailure 0 und Jobfailure 0. Mindestens 50 getrennte Pollzyklen
erfassen den noch nicht abgeschlossenen Job nach vorhandener Retryzeile;
die gemessene Spanne bis zum beobachteten Abschluss beträgt mindestens
50 Sekunden. Beide AgentJobs-Filter erhalten den letzten failed Step mit
gespeichertem retries_attempted-Wert 1. Monitoring meldet für den
weiterhin aktivierten Job LATEST_JOB_RUN_FAILED_IN_WINDOW/HIGH ohne
Consumerfehler. Vier NONE-/JSON-Aufrufe erhalten sechs vollständige Quellen
und committable ON31TX1. Ein Rollback, eigenes Jobcleanup, finale
Optionsrestauration und äußerer Labcleanup bestehen. Consumer während des
laufenden Jobs, weitere Intervalle, Parallelität und innere Fehlercleanup-
Gegenproben bleiben ungeprüft.

Eine spätere getrennte private SQL2025-17.0.4075.5/Docker-Kalenderprobe
mit CL170 und je frischer committable ON31TX1 erfasst eine Fehlergrenze.
Vier direkte OFF-Orakel außerhalb der Consumertransaktionen messen Fehler
242 für 20230229 und 20240230. Von zwölf Consumeraufrufen machen vier
AgentJobs-Aufrufe und zwei Monitoring-Aufrufe die eigene Transaktion
uncommittable. AgentJobs liefert weiterhin ERROR_HANDLED/Partial mit 242
und JSON; Monitoring reicht bei beiden ungültigen Joboutcomes Fehler 3930
weiter und liefert weder öffentliche Statusoutputs noch JSON. Ungültige
Stepoutcomes beeinträchtigen Monitoring in dieser Probe nicht. Msdb erhält
die Counts eins oder zwei und committable TX1. Sechs vollständige Quellen,
Transaktionsanzahl und ON31 bleiben erhalten. Zwölf Rollbacks, finale
Optionsrestauration und äußerer Labcleanup bestehen. Der private Lauf ist
COMPLETED mit beobachteter Grenze; ein funktionales PASS der Fehlerisolation
wird für diesen früheren Stand nicht behauptet.

Der nachfolgende Fix begrenzt XACT_ABORT OFF auf die AgentJobs-
Job-/Stepcollection und die Monitoring-Jobcollection; die ursprüngliche
Einstellung wird direkt danach vor der Ausgabe wiederhergestellt. Die
native Gegenprobe besteht 24 NONE-/JSON-Aufrufe bei ON und OFF mit
je eigener frischer TX1: Alle Callertransaktionen bleiben schreibfähig,
Fehler 242 bleibt in den bestehenden Statusverträgen abgefangen und
kein Fehler entkommt. Alle sechs Quellen und Locktimeout 31 bleiben
erhalten. Die erweiterte TEST-0001-Fixture besteht 21 positive und zwölf
Kalenderaufrufe, einschließlich zwölf eigener Kalenderrollbacks. Alle
13 impact-basierten Verträge und der eigene äußere Labcleanup bestehen.
Die nachgewiesene ON-Kalendergrenze ist damit korrigiert. Der nächste
unabhängige OPS-008-Schritt prüft weitere Uhrzeit-/Dauergrenzen; ungültige
Kalenderfälle in anderen Ausgabearten bleiben offen.

Eine anschließende getrennte native Uhrzeitgegenprobe bestätigt den
integrierten Fix für 236060 und 240000 bei gültigem Datum 20240229 als
Job- und Stepoutcome. Je zwölf NONE-/JSON-Aufrufe bei ON und OFF mit
frischer eigener TX1 bleiben schreibfähig; kein Fehler entkommt. Acht
direkte OFF-Orakel außerhalb der Consumertransaktionen messen Fehler 242.
Sechs vollständige Quellen, TX1 und Locktimeout 31 bleiben erhalten;
24 Rollbacks und finale Optionsrestauration bestehen. Die erweiterte
TEST-0001-Fixture besteht 21 positive und 24 Kalender-/Uhrzeitaufrufe mit
24 eigenen Kalenderrollbacks. Core187, Smoke110, Runtime122 und eigener
äußerer Labcleanup bestehen. Der Scope ändert ausschließlich die Fixture
und ihre Dokumentation; unveränderte Produktverträge werden nicht erneut
pauschal geprüft. Isolierte Uhrzeitteilfelder und ungültige Kalenderwerte
in anderen Ausgabearten bleiben offen. Der nächste unabhängige
OPS-008-Schritt prüft weitere Dauergrenzen beziehungsweise tatsächliche
Agentdauer; die SMTP-Welle bleibt bis zur öffentlichen Lab-Abnahme
zurückgestellt.

Eine anschließende getrennte native Dauerprobe bestätigt einen tatsächlich
ausgeführten eigenen TSQL-Job mit einem Step ohne Retry. Bei drei Sekunden
WAITFOR speichert SQL Server 3 Sekunden für den Step und 4 für den Job.
Vier NONE-/JSON-Aufrufe bestätigen Msdb-Historycount zwei, AgentJobs-
Dauer und Startzeit für Job und Step sowie Monitoring-Dauer und Startzeit
für den Job. Der Problemfilter enthält den deaktivierten Job, aber keinen
Step. Sechs vollständige Quellen und ON/31/TX1 bleiben erhalten; eigener
Rollback, Jobcleanup und ursprüngliche OFF/-1/TX0/XactState0-Restauration
bestehen. Core187, Smoke110, Runtime122 und äußerer Labcleanup bestehen.
Lange Ausführungen, Minuten-/Stundenübergänge und andere Ausgabearten
bleiben offen. Der nächste unabhängige OPS-008-Schritt prüft weitere
Dauergrenzen oder isolierte Uhrzeitteilfelder. SMTP bleibt bis zur
öffentlichen integrierten und nativ abgenommenen Lab-Funktion zurückgestellt.

Eine weitere getrennte native Gegenprobe isoliert ungültige Minuten und
Sekunden mit 6000 beziehungsweise 60 bei gültigem Datum 20240229. Beide
Werte werden als Job- und Stepoutcome geprüft. Je zwölf NONE-/JSON-Aufrufe
bei ON und OFF bleiben schreibfähig; kein Fehler entkommt. Acht direkte
OFF-Orakel außerhalb der Consumertransaktionen messen Fehler 242.
Sechs vollständige Quellen, TX1 und Locktimeout 31 bleiben erhalten;
24 Rollbacks und finale Optionsrestauration bestehen. TEST-0001 besteht
nun 21 positive und 36 Kalender-/Uhrzeitaufrufe mit 36 eigenen Rollbacks.
Core187, Smoke110, Runtime122 und äußerer Labcleanup bestehen. Andere
Werte und ungültige Kalenderfälle in anderen Ausgabearten bleiben offen.
Der nächste unabhängige OPS-008-Schritt prüft weitere Dauergrenzen;
SMTP bleibt bis zur öffentlichen integrierten Lab-Funktion samt nativer
Abnahme zurückgestellt.

Eine weitere tatsächliche native Dauerprobe führt einen eigenen TSQL-Job
mit einem Step und 63 Sekunden WAITFOR ohne Retry aus. Die erfolgreichen
Historyzeilen speichern HHmmss-Rohwerte 103 für den Step und 103 für den
Job. Der begrenzte unabhängige Sekundenbezug ergibt 63 beziehungsweise
63 Sekunden. Vier NONE-/JSON-Aufrufe bestätigen Historycount zwei,
AgentJobs-Sekunden für Job und Step sowie den unveränderten nativen
Jobrohwert in Monitoring. Startzeiten entsprechen unabhängig gebildeten
Referenzen. Sechs vollständige Quellen, ON/31/TX1, ein eigener Rollback,
Jobcleanup und ursprüngliche OFF/-1/TX0/XactState0-Restauration bestehen.
Core187, Smoke110, Runtime122 und äußerer Labcleanup bestehen. Dies belegt
die Minutenkomponente eins in dieser einzelnen tatsächlichen Probe;
Stundenwerte, weitere Dauergrenzen und andere Ausgabearten bleiben offen.
Der nächste unabhängige OPS-008-Schritt prüft weitere Dauergrenzen.
SMTP bleibt bis zur öffentlichen integrierten Lab-Funktion samt passender
nativer Abnahme zurückgestellt.

Eine getrennte native Dauergrenzprobe injiziert acht gültige HHmmss-
Rohwerte von 59 Sekunden bis 24 Stunden in Job- und Stepoutcomes eines
eigenen deaktivierten Jobs. Feste Sekundenliterale prüfen AgentJobs;
Monitoring erhält die Jobrohwerte. 32 NONE-/JSON-Aufrufe bestätigen
Historycount zwei und feste Startreferenzen. Sechs vollständige Quellen
und ON/31/TX1 bleiben erhalten. Acht eigene Rollbacks restaurieren die
ursprüngliche Basis; finale OFF/-1/TX0/XactState0-Restauration, Core187,
Smoke110, Runtime122 und äußerer Labcleanup bestehen. Es wird kein Job
ausgeführt. Tatsächliche Stundenläufe, fehlerhafte Dauerformate und andere
Ausgabearten bleiben offen. Der nächste unabhängige OPS-008-Schritt prüft
weitere Dauerformate oder bestehende Retentiongrenzen. SMTP bleibt bis zur
öffentlichen integrierten Lab-Funktion samt passender nativer Abnahme
zurückgestellt.

Eine getrennte native Probe charakterisiert drei injizierte nicht
kanonische positive run_duration-Werte 60, 6000 und 236060. AgentJobs
liefert für Job und Step 60, 3600 und 86460 Sekunden; Monitoring erhält
die Jobrohwerte. Zwölf NONE-/JSON-Aufrufe bestätigen Historycount zwei,
feste Startreferenzen sowie sechs vollständige Quellen und ON/31/TX1.
Drei eigene Rollbacks, finale OFF/-1/TX0/XactState0-Restauration, Core187,
Smoke110, Runtime122 und äußerer Labcleanup bestehen. Kein Job wird
ausgeführt. Formatvalidierung, Normalisierung, tatsächliche Dauer und
allgemeine semantische Zulässigkeit werden nicht belegt. Der nächste
unabhängige OPS-008-Schritt prüft bestehende Retentiongrenzen oder weitere
Agent-Historieninterpretation. SMTP bleibt bis zur öffentlichen integrierten
Lab-Funktion samt passender nativer Abnahme zurückgestellt.

Eine getrennte native selektive Agentretentionprobe bestätigt vier
frisch aufgebaute unabhängige Phasen mit injizierter History zweier eigener
deaktivierter Jobs. Gesamtcounts 8, 6, 4 und 2 entsprechen Zieljobcounts
6, 4, 2 und 0 bei unveränderten zwei Gegenprobezeilen. Native Purges prüfen
eine exakte Datumsgrenze, die um eine Sekunde erhöhte Grenze und NULL-Datum
für denselben ausgewählten Job. Vollständige Restwerte und fünf andere
Quellen bleiben erhalten. 16 NONE-/JSON-Aufrufe erhalten sechs Quellen
und ON/31/TX1; nach dem letzten Purge zeigen die Consumer NULL-Historywerte
des weiterhin definierten Zieljobs. Vier Rollbacks, finale Restauration,
Core187, Smoke110, Runtime122 und eigener äußerer Labcleanup bestehen.
Keine Jobs werden ausgeführt. Automatische Altersretention, allgemeine
Purgegarantien und andere Ausgabearten bleiben offen. Der nächste
unabhängige OPS-008-Schritt prüft weitere bestehende Retentiongrenzen.
SMTP bleibt bis zur öffentlichen integrierten Lab-Funktion samt passender
nativer Abnahme zurückgestellt.

Eine getrennte native datenbankselektive Backup-/Restore-Retentionsprobe
bestätigt zwei tatsächliche eigene Backups und Restores mit kontrollierten
Historienzeiten. Zwei native Purges im msdb-Kontext liefern Counts zwei,
eins und null. Die ältere Gegenprobe bleibt nach dem ersten Purge in allen
acht Historienquellen erhalten; anschließend sind alle acht leer. Neun
NONE-/TABLE-/CONSOLE-Aufrufe erhalten Quellwerte, acht Datenbankkatalogfelder
je eigener Datenbank und ON/137/TX1. Drei eigene Rollbacks erhalten die
jeweilige Retentionsphase; finale Restauration, eigenes Datenbankcleanup,
Core187, Smoke110, Runtime122 und äußerer Labcleanup bestehen. Automatische
Altersretention und allgemeine Purgegarantien bleiben offen. Der nächste
unabhängige OPS-008-Schritt prüft weitere bestehende Retentiongrenzen.
SMTP wartet weiterhin auf die integrierte öffentliche Lab-Funktion samt
passender nativer Abnahme.

Eine getrennte native Backup-/Restore-Altersgrenzprobe bestätigt zwei
tatsächliche eigene Backups und Restores mit kontrollierten Historienzeiten.
Ein nativer Purge am exakten Stichtag erhält sämtliche Werte des gleich
datierten Paars in allen acht Historienquellen und entfernt das ältere Paar.
Ein Stichtag eine Sekunde später leert alle acht Quellen. Neun
NONE-/TABLE-/CONSOLE-Aufrufe, drei Rollbacks, Quell- und Katalogerhaltung,
Callerrestauration, Core187, Smoke110, Runtime122 und eigener Cleanup
bestehen. Die Probe verwendet eine gemeinsame Zeitgrenze für Backup-Start,
Backup-Ende und Restorezeit; getrennte Zeitregeln und automatische
Altersretention bleiben offen. Der nächste unabhängige OPS-008-Schritt
prüft weitere bestehende Retentiongrenzen. SMTP wartet weiterhin auf die
integrierte öffentliche Lab-Funktion samt passender nativer Abnahme.

Eine getrennte native Mail-Altersgrenzprobe bestätigt für vier injizierte
Statusfälle die strikte send_request_date-Grenze. Am exakten Stichtag bleibt
die gleich datierte Zielzeile erhalten; eine Sekunde später verschwindet sie.
Gesamtcounts sechs, vier und drei sowie Zielcounts drei, eins und null
bestehen. Vollständige eigene Sollwerte werden vor den Purges gebunden;
36 NONE-/TABLE-/CONSOLE-Aufrufe, vier Rollbacks, Callerrestauration,
Core187, Smoke110, Runtime122 und eigener Cleanup bestehen. Mail-XPs
bleiben deaktiviert. Der nächste unabhängige OPS-008-Schritt prüft weitere
bestehende Retentionverträge. SMTP wartet weiterhin auf die integrierte
öffentliche Lab-Funktion samt passender nativer Abnahme.

Eine getrennte native Mailprobe mit gekreuzten synthetischen request/sent-Zeiten
bestätigt die Auswahl nach send_request_date für vier injizierte Statusfälle.
Sie prüft den exakten Stichtag, die Grenze eine Sekunde später und die
Bereinigung ohne Datumsgrenze bei weiterhin gesetztem Zielstatus. Die
Zielcounts drei, zwei, eins und null sowie Gesamtcounts sechs, fünf, vier
und drei bestehen. Jede Phase entspricht ihren vor dem ersten Purge
gebundenen vollständigen Sollwerten; die anderen Status bleiben unverändert.
Zwölf native Purges, 48 NONE-/TABLE-/CONSOLE-Aufrufe, vier Rollbacks,
Callerrestauration, Core187, Smoke110, Runtime122 und eigener Cleanup
bestehen. Die nächste unabhängige OPS-008-Probe prüft weitere bestehende
Retentionverträge. SMTP wartet weiterhin auf die integrierte öffentliche
Lab-Funktion samt passender nativer Abnahme.

Eine getrennte native Maintenanceprobe bestätigt die Auswahl nach start_time
und die strikte Gleichheitsgrenze für zwei injizierte Eltern. Beide end_time-
Werte liegen hinter den beiden Stichtagen. Counts zwei, eins und null,
zwei native Purges mit Rückgabe 0, neun NONE-/TABLE-/CONSOLE-Aufrufe,
vorab identitätsgebundene vollständige Sollwerte, Callerrestauration,
Core187, Smoke110, Runtime122 und eigener Cleanup bestehen. Zwei frühere
Läufe scheiterten mit 55205; der diagnostische Lauf belegte NULL für die
leeren Snapshots in Phase 3. Beide Fehlläufe bleiben getrennt erhalten; die
private Normalisierung auf [] korrigiert ausschließlich diese Testannahme. Details,
Plans und Subplans bleiben leer; tatsächliche Maintenanceausführung und
unabhängige Detaildatumssemantik sind damit nicht belegt. Die nächste
unabhängige OPS-008-Probe prüft weitere bestehende Retentionverträge.
SMTP wartet weiterhin auf die integrierte öffentliche Lab-Funktion samt
passender nativer Abnahme.

Eine getrennte native Maintenance-Detailprobe bestätigt für zwei injizierte
Eltern aus 2025 und vier gekreuzt datierte Details die Auswahl über die
Elternstartzeit. Details aus 2030 verschwinden mit A; Details aus 2000
bleiben mit B am exakten Stichtag vollständig erhalten. Eine Sekunde später
sind beide Quellen leer. Elterncounts zwei, eins und null sowie Detailcounts
vier, zwei und null, zwei native Purges mit Rückgabe 0, vollständige vorab
identitätsgebundene Sollwerte, neun Consumeraufrufe mit TABLE-/CONSOLE-/JSON-
Parität, Callerrestauration,
Core187, Smoke110, Runtime122 und eigener Cleanup bestehen. Tatsächliche
Maintenanceausführung, zeitliche Konsistenz einer realen Ausführung und
allgemeine unabhängige Detaildatumsregeln sind damit nicht belegt.
Die nächste unabhängige OPS-008-Probe prüft weitere bestehende
Retentionverträge. SMTP wartet weiterhin auf die integrierte öffentliche
Lab-Funktion samt passender nativer Abnahme.

Am 8. Oktober 2026 hat der Benutzer den SMTP-Testdienst einem gesonderten
Auftrag in SQL_Server_Lab zugeordnet. Dort liegen der öffentliche Vertrag,
die Implementierung und die Abnahme. In diesem Analyze-Auftrag werden weder
SMTP-Infrastruktur implementiert noch zugehörige Images beschafft.
Die SMTP-abhängige Analyze-Welle bleibt zurückgestellt, bis die benötigte
öffentliche Lab-Funktion in origin/main integriert ist und passende native
Abnahmen vorliegen. Anschließend wird diese Welle über die öffentliche
Lab-Konfiguration automatisch fortgesetzt. Ein Plan, ein offener PR oder
Code ohne die benötigten Nachweise erfüllt diese Abhängigkeit nicht.
Die übrigen autorisierten Analyze-Aufgaben werden einstweilen fortgesetzt.
Erfolgreiche Mail- und tatsächliche
Maintenance-Ausführung, weitere automatische Aufbewahrungsgrenzen und
weitere Retentiongrenzen bleiben offen.

Bei der Wiederaufnahme werden zuerst die aktuelle Anweisungskette,
`origin/main`, offene PRs und die kanonischen Statusquellen abgeglichen.
Der Deploymentstand und seine Grenzen stehen unter
[EXP-0001](WI0011_Deployment_Runtime_Evidence_2026-10-07.md).
Für den nächsten COLL-001-Schritt werden die verbleibenden gemeinsamen
Ausgabe-, Auswahl- und Reifeverträge anhand der kanonischen Statusquellen
und Exit-Kriterien eingegrenzt. PlanCacheHealth ist im dokumentierten
Teilumfang bereits geprüft. Vor einer Änderung sind Original, Fachwerte,
Ausgabeformen, Filter, Mengenlimits und Parentverbraucher zu prüfen. Die
nachstehende Reifeabschlussreihenfolge für OPS-005, OPS-006, OPS-008,
OPS-007 und COLL-001 bleibt maßgeblich. Frühere erfolgreiche Nachweise
werden nur bei neuer sachlicher Unsicherheit wiederholt.

Aktuelle erfolgreiche Security-Cloud-Evidenz bleibt offen. Für Deployment
sind weitere native Engines, Windows, Produktionsvolumen und Commitantwort-
verlust nicht belegt; zusätzliche Läufe folgen ausschließlich aus einem
konkreten Versionsrisiko oder freigegebenen weiteren Nachweisumfang.
Unbekannte Strukturmigrationen benötigen zuerst einen eigenen Vertrag.
Die übrigen offenen Reifeverträge und Statusflags bleiben erhalten; neue
Diagnosefläche und zusätzliche Snapshotowner benötigen weiterhin einen
eigenen fachlichen Auftrag.

Am 8. Oktober 2026 wurde zusätzlich der bestehende NULL-Zeilenlimitvertrag
von `USP_CurrentCursorAnalysis` repariert. Der ursprüngliche Quellenstand
lieferte bei explizitem NULL Fehler 1014 und `SOURCE_UNAVAILABLE`; die
0-Gegenprobe war positiv. Der reparierte Stand besteht sechs
impact-basierte Verträge auf SQL Server 2025 mit Compatibility Level 170.
Test 120 bestätigt sechs NULL-/0-/Minus-eins-Aufrufe über NONE und TABLE
mit nativen Cursoridentitäten, vollständiger zwölffeldriger TABLE-/JSON-Parität
in den positiven TABLE-Fällen sowie Quell- und Callererhaltung. Eine getrennte
SqlClient-Gegenprobe bestätigt den positiven NULL-/0-Pfad bei Locktimeout 137
und XACT_ABORT OFF. Alle eigenen Labs sind entfernt. Die beiden vorherigen
privaten Eintrittsguardfehler sind kein NULL-Produktnachweis; sie bleiben in
der [kanonischen Cursor-Evidenz](OPS007_Dormant_Cursor_Runtime_Evidence_2026-09-19.md)
getrennt dokumentiert. Fremde Hochlast und weitere gemeinsame Vertragsarbeit
bleiben offen; OPS-007 und COLL-001 behalten ihre partiellen Status.

Am 8. Oktober 2026 bestand zusätzlich ein kontrolliertes Inventar aus 250
eigenen Cursorn in einer zweiten Verbindung. Zehn NONE-/TABLE-Aufrufe
bestätigen Default 200, Grenzen 1 und 200 sowie vollständige 0-/NULL-Ausgabe,
native Rangmengen, alle zwölf Fachwerte, fünf physische Exportschemas und
Quell- sowie Callererhaltung auf gemischter SQL-Server-2025-Collation mit
Compatibility Level 170. Alle eigenen Cursor, Verbindungen, Labressourcen
und State sind bereinigt. Der begrenzte Nachweis steht in der bestehenden
[Cursor-Evidenz](OPS007_Dormant_Cursor_Runtime_Evidence_2026-09-19.md).
Fremde Hochlast und weitere gemeinsame Consumerverträge bleiben offen;
OPS-007 und COLL-001 behalten ihre partiellen Status. SMTP wartet weiterhin
auf die integrierte und passend nativ abgenommene öffentliche Lab-Funktion.

Am 8. Oktober 2026 bestand ein weiterer kontrollierter Cursorvergleich.
Eine eigene zweite Verbindung traversierte 200.000 synthetische Zeilen;
native WorkerTime und Reads lagen über einer Gegenprobe mit drei Zeilen.
Vier NONE-/TABLE-Aufrufe bestätigen native Rangauswahl, zwölf Fachwerte,
zwei physische Exportschemas sowie Quell- und Callererhaltung auf gemischtem
SQL Server 2025 mit Framework-Compatibility-Level 170. Eigene Cursor,
temporäre Quelle, Verbindungen, Labressourcen und State sind bereinigt.
Der begrenzte Nachweis steht in der bestehenden
[Cursor-Evidenz](OPS007_Dormant_Cursor_Runtime_Evidence_2026-09-19.md).
Fremde Hochlast und weitere gemeinsame Consumerverträge bleiben offen;
OPS-007 und COLL-001 behalten ihre partiellen Status. Die SMTP-Welle wartet
weiterhin auf Integration und passende native Abnahme in SQL_Server_Lab.

Am 8. Oktober 2026 bestand zusätzlich die direkte RAW-/CONSOLE-Abnahme der
Cursoranalyse. Zehn SqlClient-Aufrufe prüfen positive Limits, eigenen
Leerfall, negatives Limit und deaktiviertes Opt-in mit sämtlichen nativen
Resultsetschemas sowie zwölf Fachwerten gegen JSON derselben Materialisierung.
Zwei case-unterschiedliche Unicode-Cursor bleiben nativ und der Caller bleibt
unverändert. Der neue eigene gemischte SQL-Server-2025-Lauf auf CL170 besitzt
bestätigten Cursor-, Verbindungs-, Lab- und Statecleanup. Der begrenzte
Nachweis steht in der bestehenden
[Cursor-Evidenz](OPS007_Dormant_Cursor_Runtime_Evidence_2026-09-19.md).
Fremde Hochlast und weitere COLL-001-Verträge bleiben offen; die partiellen
Status bleiben erhalten. Die SMTP-Welle wartet weiterhin auf die öffentliche
Lab-Funktion mit integrierter passender nativer Abnahme.

## Maßgeblichkeit

Der begrenzte Benutzerauftrag zur Dokumentations- und Nachweisklarheit vom
7. Oktober 2026 ist in der
[zugehörigen Bewertung](Repository_Clarity_Assessment.md) dokumentiert.
Dieser begrenzte Auftrag selbst nahm die autonome Entwicklungswelle nicht
wieder auf; die oben dokumentierte spätere Wiederaufnahme gilt unabhängig davon.

Die [langfristige Weiterentwicklungsroadmap](../Architecture/Long_Term_Development_Roadmap.md) ordnet alle späteren Entwicklungsrichtungen, Abhängigkeiten und Exit-Kriterien. Dieses Dokument enthält ausschließlich den aktuellen Produktstand und die nächste ausführbare Welle.

Die Statusquellen besitzen getrennte Aufgaben:

- `Metadata/Quality/Implementation_Status.csv` trennt gelieferten und offenen Umfang je Arbeitselement.
- `Metadata/Inventory/Module_Maturity.csv` beschreibt sichtbare Modulreife und fehlende Evidenz.
- `Metadata/Quality/Test_Matrix.csv` dokumentiert tatsächlich ausgeführte Laufzeitnachweise.
- `Metadata/Quality/Future_Enhancement_Backlog.csv` enthält priorisierte noch nicht implementierte oder unvollständige Erweiterungen.

Ein vorhandener SQL-Quellpfad oder ein grüner statischer Vertrag ersetzt keinen dokumentierten Laufzeitnachweis.



Am 9. Oktober 2026 wurde eine native OAEP-Zertifikatlücke in Encryption080 korrigiert.
Fünf Typprüfungen behandeln `CERTIFICATE` und `CERTIFICATE_OAEP_256` gleich;
der native Typwert bleibt erhalten. Die unabhängige Baseline belegte zuvor NULL-
Protektorfelder und fälschlich konsistente TDE-Metadaten. Integration185 prüft
den installierten Join mit drei sowie die Befundausdrücke mit neun unabhängigen
Erwartungen; seine sieben bisherigen Fälle bleiben erhalten. Acht Impacttests
bestanden je Framework-CL150/160/170 auf SQL Server 2025, ebenso alle 77 statischen
Prüfungen. Zwei eigene verschlüsselte Unicode-Quellen lieferten tatsächlich
die gemessenen Typen bei CL160 und CL170; Zustand 3, Scanstatus 4, AES-128 und
Zertifikatsablauf 2099 wurden unabhängig gelesen. Fünfzehn TABLE-/RAW-/CONSOLE-
Fälle bestätigten alle 26 Werte, Schemas, Quellen, Warnfenster, Problemscope,
Limit und Callererhaltung; eigene SQL-Ressourcen, Lab und Statepfad wurden
entfernt. Weitere TDE-/Zertifikatpfade, explizite Backupverschlüsselung, AE,
Ledger und Restore bleiben offen. Der begrenzte Nachweis steht unter
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt partiell.
Die SMTP-abhängige Welle wartet weiter auf die integrierte öffentliche
Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestand ein getrennter nativer Zertifikatexport-Nachweis auf
dem unveränderten integrierten Encryption080. Der öffentliche Export ließ
den privaten Exportzeitpunkt NULL; der anschließende passwortgeschützte
private Export setzte ihn innerhalb unabhängig gemessener serverlokaler
Zeitgrenzen. Drei plus fünfzehn TABLE-/RAW-/CONSOLE-Aufrufe bestätigten alle
26 Fachwerte und Schemafacetten, Quellen und Caller. Die exportierte Quelle
lieferte im Defaultfenster TDE_METADATA_CONSISTENT, die unveränderte Gegenprobe
LOCAL_CERTIFICATE_EXPORT_EVIDENCE_MISSING. Beide blieben im großen Warnfenster
MEDIUM bei unterschiedlichen Evidenzgrenzen. Drei eigene Exportdateien blieben
ausschließlich im neuen SQL-Volume; eigenes SQL-/Lab-/Statecleanup bestand.
Externe Schlüsselkopie, Dateiintegrität und Restore werden nicht bewiesen.
Weitere Export-, TDE-, Backupverschlüsselungs-, AE- und Ledgerpfade bleiben offen.
Der begrenzte Nachweis steht unter
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt partiell.
Die SMTP-abhängige Welle wartet weiter auf die integrierte öffentliche
Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestand ein getrennter nativer Encryption-Nachweis mit drei
eigenen Full-Backups auf unverändertem Produktcode. Eine Quelle ohne TDE und
eine TDE-Quelle erhielten explizite AES-256-Backupverschlüsselung; die zweite
TDE-Quelle wurde ohne zusätzliche ENCRYPTION-Klausel gesichert. Drei plus
fünfzehn TABLE-/RAW-/CONSOLE-Aufrufe bestätigten alle 26 Fachwerte, Schemas,
Quellen und Caller. Der Verschlüsselungswert wurde unabhängig gegen die
ausgeführten Operationsmodi 1/0/1 geprüft. Native Werte aes_256 und
CERTIFICATE_OAEP_256 blieben unverändert. Drei neue eigene Dateien lagen
ausschließlich im neuen SQL-Volume; eigenes Historien-/SQL-/Lab-/Statecleanup
bestand. Erwartungs- und zusätzliche Berechtigungspfade sowie Dateiintegrität,
externe Schlüsselkopie und Restore bleiben unbelegt. Der begrenzte Nachweis
steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md);
COLL-001 bleibt partiell. Die SMTP-Welle wartet weiterhin auf die integrierte
öffentliche Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestand ein getrennter nativer Nachweis des bestehenden
Encryption-Backup-Erwartungsflags mit FALSE und TRUE auf unverändertem
Produktcode. Sechs Aufrufe vor und dreißig nach drei eigenen Full-Backups
bestätigten alle 26 Fachwerte, Ausgabeparität, Schemas, Quellen und Caller.
Das unabhängige Operationsorakel war 0/0/1. FALSE lieferte je Auswahl
3/3/2/1/0 Zeilen; TRUE lieferte 3/3/3/1/2. Fehlende explizite
Backupverschlüsselung erzeugte MEDIUM, auch wenn ein höher priorisierter
lokaler Zertifikatexportbefund den FindingCode bestimmte. Native Backupwerte
blieben unverändert. Eigenes Historien-/SQL-/Lab-/Statecleanup bestand.
Weitere Backupvarianten, Berechtigungen, Dateiintegrität, externe Schlüsselkopie
und Restore bleiben unbelegt. Der begrenzte Nachweis steht unter
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt
partiell. Die SMTP-Welle wartet weiterhin auf die integrierte öffentliche
Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener nativer Encryption-Nachweis die
Auswahl des neuesten regulären Full-Backups und den Ausschluss einer
späteren COPY_ONLY-Sicherung auf unverändertem Produktcode. Fünf eigene
Full-Backups und 60 TABLE-/RAW-/CONSOLE-Aufrufe prüften alle 26 Fachwerte,
Schemas, Ausgabeparität, Quellen und Caller. Bestätigte Operationsrollen
1/5/3 ergaben das unabhängige Auswahlorakel 0/1/1. FALSE behielt 3/3/2/1/0
Zeilen; TRUE wechselte auf 3/3/3/1/1. Kontrollquelle und zweite TDE-Quelle
blieben unverändert. Eigenes Historien-/SQL-/Lab-/Statecleanup bestand.
Lookbackgrenzen, exakte Finishzeit-Ties, weitere Backupvarianten,
Berechtigungen und Restore bleiben offen. Der begrenzte Nachweis steht
unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md);
COLL-001 bleibt partiell. Die SMTP-Welle wartet weiterhin auf die integrierte
öffentliche Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener nativer Encryption-Nachweis die
Auswahl des neuesten regulären Full-Backups und den Ausschluss einer
späteren Differential-Sicherung auf unverändertem Produktcode. Vier eigene Full-Backups, eine eigene Differential-Sicherung und 60 TABLE-/RAW-/CONSOLE-Aufrufe prüften alle 26 Fachwerte,
Schemas, Ausgabeparität, Quellen und Caller. Bestätigte Operationsrollen
1/5/3 ergaben das unabhängige Auswahlorakel 0/1/1. FALSE behielt 3/3/2/1/0
Zeilen; TRUE wechselte auf 3/3/3/1/1. Kontrollquelle und zweite TDE-Quelle
blieben unverändert. Eigenes Historien-/SQL-/Lab-/Statecleanup bestand.
Lookbackgrenzen, exakte Finishzeit-Ties, weitere Backupvarianten,
Berechtigungen und Restore bleiben offen. Der begrenzte Nachweis steht
unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md);
COLL-001 bleibt partiell. Die SMTP-Welle wartet weiterhin auf die integrierte
öffentliche Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener nativer Encryption-Nachweis
positive Ledger-Kataloganzahlen auf unverändertem Produktcode. Eine leere
Append-only-Tabelle und eine leere Updatable-Tabelle mit eigener History
lieferten das unabhängige Orakel 0/1/2 statt der Baseline 0/0/0.
30 TABLE-/RAW-/CONSOLE-Aufrufe bestätigten alle 26 Fachwerte, Schemas,
Ausgabeparität, Quellen und Caller. Nur LedgerTableCount wechselte;
Metadaten bestätigten die drei Tabellen leer. SQL-/Lab-/Statecleanup bestand.
Weitere Ledger-Varianten, Rollen, Metadatenfehler und Dropvarianten sowie
kryptographische Integrität und Restore bleiben unbelegt. Der begrenzte
Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md);
COLL-001 bleibt partiell. Die SMTP-Welle wartet weiterhin auf die integrierte
öffentliche Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener nativer Encryption-Nachweis
positive CMK-Metadatenanzahlen auf unverändertem Produktcode. Drei eigene
Katalogeinträge lieferten das unabhängige Orakel 0/1/2 statt der Baseline
0/0/0. Es existiert absichtlich kein echter CMK oder Schlüsselstore;
der verwendete Testclient besitzt keine AE-API. 30 TABLE-/RAW-/CONSOLE-
Aufrufe bestätigten alle 26 Fachwerte, Schemas, Ausgabeparität, Quellen und
Caller. Nur ColumnMasterKeyCount wechselte; CEK, verschlüsselte Spalten und
Ledger blieben 0. SQL-/Lab-/Statecleanup bestand. Positive CEK-/Spaltenanzahlen,
weitere CMK-Varianten, Rollen und Metadatenfehler sowie funktionsfähige AE
und Restore bleiben unbelegt. Der begrenzte Nachweis steht unter
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt
partiell. Die SMTP-Welle wartet weiterhin auf die integrierte öffentliche
Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener nativer Encryption-Nachweis
auf unverändertem Produktcode den abgeschlossenen Zustand nach genau
einem SET ENCRYPTION OFF. Die erste eigene TDE-Quelle lieferte
IsEncrypted 0 und EncryptionState 1 bei erhaltenem DEK und Protektor.
Vollständig verschlüsselte Quellen wechselten von zwei auf eine;
vorhandene DEKs blieben zwei. 30 TABLE-/RAW-/CONSOLE-Aufrufe bestätigten
alle 26 Fachwerte, Schemas, Ausgabeparität, Quellen und Caller.
Die fünf Auswahlmengen wechselten von 3/3/2/1/0 auf 3/3/1/1/0;
Limit 1 wählte danach die zweite TDE-Quelle. Kontrollquelle, zweite Quelle
und die übrigen Felder der ersten Quelle blieben erhalten.
SQL-/Lab-/Statecleanup bestand. Laufende, suspendierte, abgebrochene und
lange Übergänge, DEK-Entfernung, Wiederanschalten sowie weitere Encryption-
Grenzen bleiben offen. Physische Logentschlüsselung und Restore sind
unbelegt. Der begrenzte Nachweis steht unter
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt
partiell. Die SMTP-Welle wartet weiterhin auf die integrierte öffentliche
Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener nativer Encryption-Nachweis
auf unverändertem Produktcode das abgeschlossene Wiederanschalten von TDE
mit erhaltenem DEK. Nach dem eigenen Setup-OFF und bestätigtem Zustand 1 erreichte
die erste Quelle durch genau ein SET ENCRYPTION ON Zustand 3 und Scanstatus 4.
Vollständig verschlüsselte Quellen wechselten von einer auf zwei;
vorhandene DEKs blieben zwei. 30 TABLE-/RAW-/CONSOLE-Aufrufe bestätigten
alle 26 Fachwerte, Schemas, Ausgabeparität, Quellen und Caller.
Auswahlmengen wechselten von 3/3/1/1/0 auf 3/3/2/1/0; Limit 1 wechselte
von der zweiten zurück zur ersten Quelle. Kontrollquelle, zweite Quelle
und die übrigen Felder der ersten Quelle blieben erhalten.
SQL-/Lab-/Statecleanup bestand. DEK-Entfernung, laufende, suspendierte,
abgebrochene und lange Übergänge sowie weitere Encryption-Grenzen bleiben
offen. Physische Datei-/Logbytes und Restorefähigkeit sind unbelegt.
Der Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md);
COLL-001 bleibt partiell. Die SMTP-Welle wartet weiterhin auf die integrierte
öffentliche Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener nativer Encryption-Nachweis
auf unverändertem Produktcode die Entfernung des DEK nach abgeschalteter TDE.
Nach dem eigenen Setup-OFF und bestätigtem Zustand 1 entfernte genau ein
DROP DATABASE ENCRYPTION KEY die erste DEK-Zeile. IsEncrypted blieb 0;
zwölf DEK-/Protektorfelder wurden NULL. Die fehlende DMV-Zeile wurde nicht
als Zustand 0 interpretiert. Vorhandene DEKs wechselten von zwei auf einen;
eine vollständig verschlüsselte Quelle blieb erhalten. Beide Zertifikate
und der DMK blieben bis zum eigenen Cleanup erhalten. 30 TABLE-/RAW-/CONSOLE-
Aufrufe bestätigten alle 26 Fachwerte, Schemas, Ausgabeparität, Quellen und
Caller. Auswahlmengen blieben 3/3/1/1/0; Kontrollquelle, zweite Quelle und
übrige Felder der ersten Quelle blieben unverändert. SQL-/Lab-/Statecleanup
bestand. Laufende, suspendierte, abgebrochene und lange Übergänge sowie weitere
Encryption-Grenzen bleiben offen; physische Datei-/Logbytes, physische
Schlüssellöschung und Restorefähigkeit sind unbelegt. Der Nachweis steht
unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt
partiell. Die SMTP-Welle wartet weiterhin auf die integrierte öffentliche
Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener nativer Encryption-Nachweis
auf unverändertem Produktcode die CEK-Einwert-Metadatenanzahlen. Genau drei
eigene CEKs mit je einem verschlüsselten Wert änderten die Anzahlen von
0/0/0 auf 0/1/2; CMK-Anzahlen blieben 0/1/1. Die temporären RSA-2048-
Fixtures wurden im Prozess bereinigt. Es gab keinen registrierten oder
aufgerufenen AE-Provider und keinen Hostschlüsselspeicher. 30 TABLE-/RAW-/
CONSOLE-Aufrufe bestätigten alle 26 Fachwerte, Schemas, Ausgabeparität,
Quellen und Caller. Auswahlmengen blieben 3/3/2/1/0; im Phasenvergleich
änderte sich ausschließlich ColumnEncryptionKeyCount. SQL-/Lab-/Statecleanup
bestand. Weitere CEK-Varianten, verschlüsselte Spalten und AE-Funktions-
und Berechtigungsnachweise bleiben offen. Der Nachweis steht unter
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt
partiell. Die SMTP-Welle wartet weiterhin auf die integrierte öffentliche
Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener nativer Encryption-Nachweis
auf unverändertem Produktcode die CEK-Zählung bei zwei verschlüsselten Werten.
Genau ein ADD VALUE änderte Wertanzahlen von 0/1/2 auf 0/1/3; CMK- und CEK-
Anzahlen blieben 0/1/2. Alle drei CEK-IDs und ursprünglichen Wertbindungen
blieben erhalten. 30 TABLE-/RAW-/CONSOLE-Aufrufe bestätigten alle 26 Fachwerte,
Schemas, Ausgabeparität, Quellen und Caller. Alle 26 Fachwerte jeder Quelle
blieben im Phasenvergleich unverändert; Auswahlmengen waren 3/3/2/1/0.
Temporäre RSA-Fixtures sowie SQL-/Lab-/Statecleanup bestanden. Der Lauf
belegt keine funktionierende Rotation oder AE-Provider-Kompatibilität.
Weitere CEK-, verschlüsselte-Spalten- und Berechtigungsnachweise bleiben offen.
Der Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md);
COLL-001 bleibt partiell. Die SMTP-Welle wartet weiterhin auf die integrierte
öffentliche Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein eigener nativer SQL2025-Lauf auf unverändertem
Produktcode die Metadatenzählung verschlüsselter Spalten. Drei neue leere
Tabellen mit je einer verschlüsselten und einer unverschlüsselten nullable
int-Spalte änderten EncryptedColumnCount von 0/0/0 auf 0/1/2. CMK-Anzahlen
0/1/1, CEK-Anzahlen 0/1/2 und alle übrigen 25 Fachwerte blieben erhalten.
30 TABLE-/RAW-/CONSOLE-Aufrufe bestätigten Schemas, native Katalogbindungen,
Ausgabeparität, Quellen und Caller; Auswahlmengen waren 3/3/2/1/0. Temporäre
RSA-Fixtures und eigener SQL-/Lab-/Statecleanup bestanden. Keine Inhaltsabfrage,
DML oder AE-Provider-Verarbeitung wurde ausgeführt. Weitere Spaltenvarianten
und Berechtigungen bleiben offen. Der begrenzte Nachweis steht unter
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt partiell.
Die SMTP-Welle wartet weiter auf die integrierte öffentliche Lab-Funktion
samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener nativer Encryption-Nachweis
auf unverändertem Produktcode die abgeschlossene DEK-Regeneration von
AES-128 auf AES-256. Genau ein ALTER DATABASE ENCRYPTION KEY REGENERATE
änderte KeyLength ausschließlich an der ersten eigenen TDE-Quelle von
128 auf 256. Zustand 3, Scanstatus 4 und PercentComplete 0 bestanden;
die zweite Quelle blieb bei 128. 30 TABLE-/RAW-/CONSOLE-Aufrufe bestätigten
alle 26 Fachwerte, Schemas, Ausgabeparität, Quellen und Caller sowie
Auswahlmengen 3/3/2/1/0 in beiden Phasen. Alle übrigen 24 Fachwerte der
ersten Quelle und sämtliche 26 Werte der beiden Kontrollen blieben
erhalten; der Scanzeitwert der ersten Quelle durfte sich ändern.
SQL-/Lab-/Statecleanup bestand. Laufende, suspendierte, abgebrochene
und lange Übergänge sowie weitere Encryption-Grenzen bleiben offen.
Physische Datei-/Logbytes, Datennutzbarkeit und Restorefähigkeit sind
unbelegt. Der Nachweis steht unter
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt
partiell. Die SMTP-Welle wartet weiterhin auf die integrierte öffentliche
Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener nativer Encryption-Nachweis
auf unverändertem Produktcode einen abgeschlossenen DEK-Protektorwechsel.
Genau ein ALTER DATABASE ENCRYPTION KEY ENCRYPTION BY SERVER CERTIFICATE
band den ersten eigenen DEK an ein drittes eigenes Zertifikat. Native
Thumbprint-, ID-/Namens- und GUID-Bindungen bestanden. Zustand 3,
Scanstatus 4, PercentComplete 0 und KeyLength 128 blieben erhalten.
30 TABLE-/RAW-/CONSOLE-Aufrufe bestätigten alle 26 Fachwerte, Schemas,
Ausgabeparität, Quellen und Caller sowie Auswahlmengen 3/3/2/1/0 in
beiden Phasen. Ausschließlich ProtectorName der ersten Quelle wechselte;
deren Scanzeitwert durfte sich ändern. Alle übrigen 24 Fachwerte der
ersten Quelle und sämtliche 26 Werte der beiden Kontrollen blieben erhalten.
SQL-/Lab-/Statecleanup einschließlich aller drei eigenen Zertifikate
bestand. Laufende, suspendierte, abgebrochene und lange Übergänge sowie
weitere Encryption-Grenzen bleiben offen. Datennutzbarkeit und
Restorefähigkeit sind unbelegt. Der Nachweis steht unter
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt
partiell. Die SMTP-Welle wartet weiterhin auf die integrierte öffentliche
Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener Encryption-Nachweis auf
unverändertem Produktcode ein abgelaufenes eigenes TDE-Zertifikat im
bestehenden 90-Tage-Warnfenster. Genau ein Protektorwechsel band den ersten
eigenen DEK an das Zertifikat mit START_DATE 2000-01-01 und EXPIRY_DATE
2001-01-01. Native Identitäts- und Thumbprintbindungen bestanden; beide
DEKs behielten Zustand 3, Scanstatus 4, PercentComplete 0 und KeyLength 128.
30 TABLE-/RAW-/CONSOLE-Aufrufe bestätigten alle 26 Fachwerte, Schemas,
Ausgabeparität, Quellen und Caller. Auswahlcounts wechselten von
3/3/2/1/0 auf 3/3/2/1/1; der erste Default-Befund wurde
TDE_CERTIFICATE_EXPIRY_WINDOW/MEDIUM. Finalstatus war durchgehend
AVAILABLE_WITH_FINDING. Nur fünf erlaubte Fachwerte der ersten Quelle
waren variabel; deren andere 21 Werte und sämtliche Werte der beiden
Kontrollen blieben erhalten. SQL-/Lab-/Statecleanup bestand.
Datennutzbarkeit und Restorefähigkeit sowie weitere Zertifikat-,
Übergangs- und Berechtigungsvarianten bleiben unbelegt. Der Nachweis steht
unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md);
COLL-001 bleibt partiell. Die SMTP-Welle wartet weiter auf die integrierte
öffentliche Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte ein neuer eigener Encryption-Nachweis auf
unverändertem Produktcode ein noch gültiges eigenes TDE-Zertifikat bei
Warnfenstern von 1/90/36500 Tagen. Genau ein Protektorwechsel band den
ersten eigenen DEK an das Zertifikat mit START_DATE 2000-01-01 und
EXPIRY_DATE als UTC-Datum 30 Tage nach dem eigenen Erzeugungsanchor.
Receipt- und native Identitäts-/Thumbprintbindungen bestanden; beide DEKs
behielten Zustand 3, Scanstatus 4, PercentComplete 0 und KeyLength 128.
42 TABLE-/RAW-/CONSOLE-Aufrufe bestätigten alle 26 Werte, Schemas,
Ausgabeparität, Quellen und Caller. Auswahlcounts wechselten von
3/3/2/1/0/3/0 auf 3/3/2/1/1/3/0. Bei 90/36500 Tagen wurde die erste Quelle
mit TDE_CERTIFICATE_EXPIRY_WINDOW/MEDIUM gemeldet; bei einem Tag blieb sie
INFO und der Problemfilter leer. Finalstatus war bei langem und normalem
Warnfenster AVAILABLE_WITH_FINDING, bei kurzem Fenster AVAILABLE.
Die übrigen 21 Fachwerte der ersten Quelle und sämtliche Werte beider
Kontrollen blieben erhalten. SQL-/Lab-/Statecleanup bestand. Exakte
Datumsgleichheitsgrenzen, Datennutzbarkeit und Restorefähigkeit sowie
weitere Varianten bleiben unbelegt. Nachweis unter
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt
partiell. Die SMTP-Welle wartet weiter auf die integrierte öffentliche
Lab-Funktion samt tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte eine neue eigene SQL2025-Fixture auf unverändertem
Produktcode die isolierte SELECT-Verweigerung der Encryption-Backupquelle.
Ein eigener Login sah zunächst genau ein natives unverschlüsseltes Full-Backup;
nach DENY SELECT auf msdb.dbo.backupset bestätigten direkte Gegenproben Fehler 229.
30 TABLE-/RAW-/CONSOLE-Aufrufe erhielten alle 26 physischen nativen Quellwerte,
Auswahlmengen 3/3/2/1/0, Findings, Schemas und Ausgabeparität. Das getrennte
Zugriffsorakel bestätigte ausschließlich NULL in den vier nicht zugänglichen
Backupfeldern. TDE und Inventar blieben AVAILABLE; Backup war DENIED_PERMISSION,
Modul und JSON-meta waren AVAILABLE_LIMITED mit Partial 1. Fehlerpaar, Caller
und REVERT zum ursprünglichen Kontext bestanden. Principal-/History-/SQLcleanup,
öffentlicher Lab-Abbau, same-pin Ressourcenabwesenheit und Vor-/Nachschutz bestanden.
Weitere Berechtigungskontexte, andere Backupvarianten und Restore bleiben offen.
Der Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md);
COLL-001 bleibt partiell. Die SMTP-Welle wartet weiterhin auf die integrierte
öffentliche Lab-Funktion mit tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte eine neue eigene SQL2025-Fixture auf unverändertem
Produktcode die Auswahl bei gleichen nativen Abschlusszeiten verschlüsselter
Full-Backups. Von 2 tatsächlich erzeugten eigenen CHECKSUM-Backups
hatte das letzte AES128-/AES256-Paar dasselbe backup_finish_date; das zweite
AES256-Backup besaß die maximale Backupset-ID innerhalb der zeitgleichen
Historie. Native Abschlusszeiten wurden nicht zur Herbeiführung des Gleichstands
verändert; kein msdb-UPDATE wurde dafür ausgeführt. 30 TABLE-/RAW-/
CONSOLE-Aufrufe bestätigten alle 26 Fachwerte, Schemas, Ausgabeparität und
Auswahlmengen 3/3/2/1/0. Über 15 Fallpaare änderten sich ausschließlich die
vier Backupfelder der Kontrollquelle. History-/SQLcleanup, öffentlicher
Lab-Abbau, Ressourcenabwesenheit am selben Providerpin und Vor-/Nachschutz
bestanden. Lookback, weitere Backupvarianten, Berechtigungskontexte und
Restore bleiben offen. Der Nachweis steht unter
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt partiell.
Die SMTP-Welle wartet weiterhin auf die integrierte öffentliche Lab-Funktion
mit tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte eine neue eigene SQL2025-Fixture auf unverändertem
Produktcode den bestehenden AES192-Backupvertrag. Genau ein natives,
nicht Copy-only, CHECKSUM-Full-Backup einer leeren eigenen Kontrollquelle
wurde mit einem dritten eigenen Zertifikat erzeugt. Alle 30 TABLE-/RAW-/
CONSOLE-Aufrufe bestätigten den 26-Feld-Vertrag, Schemas, Ausgabeparität
und feste Auswahlmengen 3/3/2/1/0. Über 15 Phasenpaare änderten sich ausschließlich
die vier Kontroll-Backupfelder auf die tatsächliche Abschlusszeit, explizite
Verschlüsselung TRUE und native Algorithmus-/EncryptorType-Werte. TDE,
Inventare, Findings, Caller und alle übrigen Fachwerte blieben erhalten.
History-/SQLcleanup, öffentlicher Lab-Abbau, Ressourcenabwesenheit am selben
Providerpin und Vor-/Nachschutz bestanden. Dateiintegrität, Lookback, weitere
Backupvarianten, Berechtigungen und Restore bleiben offen. Der Nachweis steht
unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt
partiell. Die SMTP-Welle wartet weiterhin auf die integrierte öffentliche
Lab-Funktion mit tatsächlicher Abnahme.



Am 9. Oktober 2026 bestätigte eine neue eigene SQL2025-Fixture auf unverändertem
Produktcode den bestehenden TRIPLE_DES_3KEY-Backupvertrag. Genau ein natives,
nicht Copy-only, CHECKSUM-Full-Backup einer leeren eigenen Kontrollquelle
wurde mit einem dritten eigenen Zertifikat erzeugt. Alle 30 TABLE-/RAW-/
CONSOLE-Aufrufe bestätigten den 26-Feld-Vertrag, Schemas, Ausgabeparität
und feste Auswahlmengen 3/3/2/1/0. Über 15 Phasenpaare änderten sich ausschließlich
die vier Kontroll-Backupfelder auf die tatsächliche Abschlusszeit, explizite
Verschlüsselung TRUE und native Algorithmus-/EncryptorType-Werte. TDE,
Inventare, Findings, Caller und alle übrigen Fachwerte blieben erhalten.
History-/SQLcleanup, öffentlicher Lab-Abbau, Ressourcenabwesenheit am selben
Providerpin und Vor-/Nachschutz bestanden. Dateiintegrität, Lookback, weitere
Backupvarianten, Berechtigungen und Restore bleiben offen. Der Nachweis steht
unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt
partiell. Die SMTP-Welle wartet weiterhin auf die integrierte öffentliche
Lab-Funktion mit tatsächlicher Abnahme.



Am 11. Oktober 2026 bestätigte eine neue eigene SQL2025-Fixture auf unverändertem
Produktcode TDE_PROTECTOR_NOT_VISIBLE. Ein eigener minimaler Login sah nach
gezielter VIEW-DEFINITION-Verweigerung genau ein eigenes TDE-Zertifikat nicht
mehr; andere Quellen blieben zugänglich. 30 TABLE-/RAW-/CONSOLE-Aufrufe
bestanden mit allen 26 Fachwerten, Schemas und Ausgabeparität.
Default-Problemscope wählte final ausschließlich die erste TDE-Quelle.
Physische Quellen blieben über 15 Phasenpaare unverändert; nur vier Felder
der eingeschränkten Projektion konnten sich ändern. History-/Principal-/
SQLcleanup, öffentlicher Lab-Abbau, eigene Ressourcenabwesenheit und
Vor-/Nachschutz bestanden. Weitere Berechtigungskontexte und Restore bleiben
offen. Der Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md);
COLL-001 bleibt partiell. Der bestätigte SMTP-Versand in SQL_Server_Lab belegt eine Lab-Fähigkeit.
Die aktivierte öffentliche Manifestkonfiguration auf Lab-origin/main bleibt
vor der Provisionierung gesperrt; der dafür maßgebliche Gatewayumfang liegt
noch im offenen Draft-PR #738. Analyze wartet auf dessen öffentliche
Integration und prüft danach seine eigenen Consumer. Ein Lab-Versandnachweis
ersetzt keine Analyze-Abnahme.

## Auftrag zur autonomen Fortsetzung

Der neue Benutzerauftrag vom 11. Oktober 2026 nimmt die autonome Entwicklung
nach den bestehenden Projektregeln wieder auf und ersetzt die nachfolgend
beschriebene Abschlussbegrenzung vom 9. Oktober. Begonnene Wellen haben Vorrang.
Der bestehende DTSX-v2-Stand ist bis PR #361 integriert. Der Benutzer hat den separaten Variablenvertrag mit Schema v3 und `variables`
als dreizehntem RAW-Resultset ausdrücklich freigegeben. Die Umsetzung umfasst
Paket-, Container- und Taskdefinitionen mit gemeinsamem RAW-/TABLE-/JSON-Export;
Event-Handler-Scope und Variablenwerte bleiben ausgeschlossen. Der freigegebene Variablenvertrag ist implementiert und auf SQL Server 2025
mit Compatibility Level 170 nativ geprüft. Der bestätigte native
SMTP-Versand ist eine vorhandene Lab-Fähigkeit; Analyze prüft die öffentliche
Integration und seine eigenen Consumer getrennt.


Die SSIS-001-Abnahme vom 11. Oktober 2026 bestätigt den erweiterten
Integrationstest 200 im Gesamtframework und im separaten SSIS-Installer.
Geprüft sind Scopezuordnung, gleichnamige Variablen, Unicode, Metadatendefaults,
NULL-Felder, gemeinsame positive sowie NULL-/0-Limits, leere und ungültige
Eingaben sowie die partielle Behandlung von Event Handlern und fehlenden
Executable-Kennungen. Sechs zusätzliche SqlClient-Aufrufe bestätigen die
dreizehn RAW-Schemas, die acht Variablentypen und RAW-/JSON-Wertparität sowie
ein CONSOLE-Resultset und keine NONE-Resultsets. Die ersten zwölf Schemas und
ihre Reihenfolge sind gegenüber der Basis unverändert. Framework-Smoke und
alle 75 statischen Validatoren bestehen; der unabhängige fachliche Review
besitzt keine offenen Befunde.

Das eigene Lab einschließlich Container und Volume ist entfernt; der
abschließende Inventarvergleich bestätigt unveränderte fremde Dockerressourcen.
Die zuvor fehlgeschlagenen Versuche wegen einer nicht unterstützten
Labcollation, eines nicht Unicode-fähigen Fixtureliterals und des verletzten
TABLE-Seedvertrags bleiben Fehlversuche und sind keine Erfolgsnachweise.
Ein zusätzlicher Capturebefund zeigte ein fehlendes JSON-Array bei leerem
Variablenexport. Die explizite leere Projektion und gegen fehlende Schlüssel
verschärfte Regressionen beheben diesen Vertragsfehler.
Weitere Paketformate, Event-Handler-Variablen, Ausdrucksauflösung, SSISDB und
ältere native Engines bleiben unbelegt. Der allgemeine SSIS-Reifestatus
bleibt partiell.


Der Benutzer hat den laufenden Orchestrator am 9. Oktober 2026 auf die
dauerhafte Integration des Regelkontextcaches und den Abschluss bereits
begonnener Arbeiten einschließlich Merge nach `origin/main` begrenzt.
Anschließend endet dieser Orchestrator. Neue Reifeschritte werden in diesem
Abschlussumfang nicht begonnen. Die verbleibende Roadmap und ihre offenen
Evidenzgrenzen bleiben davon unberührt. Für zukünftige Entwicklungswellen
gilt der [Regelkontextcache](../../Rule_Context_Cache.md).
Tatsächlich blockierte Entwicklungen verhindern diesen Abschluss nicht.
Ihre Voraussetzungen, offenen Prüfungen und nicht ausgeführten Nachweise
werden vor dem Abschalten im Remote-Repository gesichert.

### Voraussetzungen und Abnahmen der Fortsetzung

Die SMTP-abhängige OPS-008-Welle benötigt die öffentliche
SMTP-Lab-Funktion in `SQL_Server_Lab` auf `origin/main` und
passende tatsächliche Abnahmen. Eine neue Fortsetzung prüft diese
Abhängigkeit lesend und verwendet anschließend ausschließlich die öffentliche
Lab-Konfiguration. Der separate Lab-Auftrag umfasst einen lokalen Empfänger
mit sichtbaren Nachrichten und Inhalten sowie verhindertem Versand nach außen.
Analyze implementiert dafür keine SMTP-Infrastruktur und beschafft keine Images.
Ein Plan, offener PR oder ungeprüfter Code erfüllt die Lieferbedingung nicht.

Der am 12. Oktober 2026 übernommene SMTP-Consumer-Kandidat umfasst
`MailExecutionSuccess` im OPS-008-Runner und eine synthetische SQL-Fixture.
Die Vorbereitung bleibt `NOT_EXECUTED`. Der erste unabhängige Review fand
eine ungültige skalare Collationdeklaration, NULL-offene Vergleiche,
unvollständige native Mailorakel und eine fehlende Statusgrenze in der
TestLab-Dokumentation. Die Korrekturen binden Mail und Profil samt
Zeitfeldern und synthetischem Inhalt, vergleichen die Mailprojektion mit
nativen Aggregaten und verwenden NULL-sichere Status- und Paritätsprüfungen.
Der Runner verlangt vor Hosttoolinitialisierung einen unveränderten
Lab-Arbeitsbaum auf dessen öffentlichem `origin/main`.
Die PowerShell-Syntaxprüfung und ein gezielter negativer Preflight bestehen;
der ältere ausgewählte Lab-Checkout wird vor Hosttools, Secrets und
Provisionierung abgelehnt. Der Korrekturreview besitzt keine offenen Befunde
im statisch geprüften Umfang und erteilt keine Laufzeitfreigabe.

Die Vorbereitung wird getrennt von der offenen Runtimeabnahme gesichert.
Vor Ausführung sind der endgültige öffentliche Profilvertrag, die
verhinderte Imagebeschaffung, die tatsächlich ausgeführte Lab-Abnahme sowie
Analyze-Versand-, Consumer- und Cleanup-Nachweise zu bestätigen. Die frühere
Barriere `SMTP_TEST_BACKEND_UNADMITTED` ist am 12. Oktober 2026 durch die
Integration von Lab-PR #744 auf dem öffentlichen Lab-Stand
`abf5cc099b4200f8c3b6d7d65dd15b33c0016bac` abgelöst. Die dortige
`LOCAL_VALIDATION_STRATEGY.md` dokumentiert die ausgeführte Docker-Abnahme
mit `New-SqlServerLab`, run-spezifischem Database-Mail-Profil, Zustellung an
Mailpit und erfolgreichem `Remove-SqlServerLab`.

Die lesende Prüfung dieses öffentlichen Stands zeigt zwei verbleibende
Voraussetzungen für den vorhandenen Analyze-Kandidaten. Die SMTP-Provisionierung
lehnt dessen OwnedHost-Policy mit `SMTP_TEST_OWNED_HOST_UNSUPPORTED` ab.
Außerdem baut sie das Gatewayimage bei jeder Provisionierung; der
Receiverstart erzwingt keine ausschließliche Verwendung vorhandener Images.
Ein öffentlicher SMTP-Pfad mit verhinderter Imagebeschaffung ist damit für
diesen Kandidaten nicht bestätigt. Analyze startet weder Provisionierung
noch Versand, übersteuert keine privaten Lab-Funktionen und bleibt
`NOT_EXECUTED`. Die öffentliche Lab-Abnahme ersetzt keine eigene
Analyze-Versand-, Consumer- oder Cleanup-Abnahme. Eine Fortsetzung benötigt
einen passenden öffentlichen Lab-Vertrag und prüft diese geänderten
Voraussetzungen vor jedem eigenen Runtimeversuch.

Am 13. Oktober 2026 ist Lab-PR #745 auf dem öffentlichen Stand
`5a7b28a32c0383d1f9bb04bb701c5f1d2cab3121` integriert. Der dortige
Manifestvertrag und die Implementierung ergänzen
`imageProvisioning=require-existing`: Vor SMTP-Ressourcenmutationen werden
Receiver und Gateway an vorhandene lokale unveränderliche Image-IDs gebunden;
beide Starts verwenden `--pull=never`, ohne Gateway-Build. Der OwnedHost-Pfad
verwendet das vorhandene Sendernetz und eigene Container-Intents und Receipts.
Die vorherige OwnedHost-Ablehnung ist für diesen Modus abgelöst.

Lab-PR #747 veröffentlicht auf dem öffentlichen Stand
`ecd535a7dd96f1307c1f4c20cca3b171b8f9a713` die ausgeführten Docker-Abnahmen
des strengen Modus einschließlich OwnedHost. Diese bestätigen vorhandene
gepinnte Images, `--pull=never`, den fehlenden Build, `READY` und Cleanup;
eine neue OwnedHost-Database-Mail-Nachricht ist darin nicht enthalten.
Der Analyze-Runner verwendet nun den strengen Modus und liest das Profil aus
der eigenen öffentlichen Run-`connection-info.json` mit Run-, Scope- und
Einzelsenderbindung.

Zwei tatsächliche Analyze-Versuche am 13. Oktober 2026 bleiben
`FAILED_NOT_QUALIFIED`. Der erste scheiterte an der falschen Annahme einer
SMTP-Eigenschaft im `New-SqlServerLab`-Rückgabeobjekt; der zweite nach dieser
Adapterkorrektur an zwei nativen Syntaxfehlern bei `SET LOCK_TIMEOUT` in der
SQL-Fixture. Die beiden Wiederherstellungen verwenden jetzt das vom
Eintrittsguard garantierte Literal `-1`. Neun lokale Profilgegenproben und die
engen unabhängigen Korrekturreviews bestehen. Eine zunächst noch alte aktive
Hashbindung ist vor dem zweiten Start korrigiert; die ursprüngliche Datei
bleibt erhalten. Der lokale SQL-Parser erkennt den ursprünglichen Fehler
nicht und qualifiziert daher keine native Ausführung.

Nach ausdrücklicher Benutzerfreigabe eines dritten Versuchs besteht der
korrigierte eigene Lauf auf SQL Server 2025 `17.0.4075.5` mit CL170. Eine
synthetische Mail erhält den nativen `sent`-Status; drei NONE-/TABLE-/CONSOLE-
Fälle bestätigen Ausgabeparität, Quellenerhaltung und Callerzustand.
Smoke110 und Runtime122 bestehen. Jeder der drei eigenen Runs ist mit fünf
Cleanupschritten ohne Fehler entfernt; getrennte Vergleiche bestätigen
unveränderte Docker- und Statebestände. Der unabhängige Ergebnisreview besitzt
keine offenen P1/P2-Befunde. Die Obergrenze von drei bleibt eingehalten;
das separate ausgeschöpfte Multiple-Session-Budget ist unverändert.

Die kanonische OPS-008-Evidenz erhält beide Fehlversuche und den begrenzten
Erfolg. DeliveredScope enthält diesen einen erfolgreichen Mailfall;
OpenScope bleibt für weitere Fälle und übrige Retentionverträge offen.
Produktcode, öffentliche Verträge und `PARTIAL_PRODUCT_FUNCTION` bleiben
unverändert. Receiverinhalte, allgemeine Zustellung und Retries sind nicht
belegt; aus dem Stock-Lab-Aufruf werden keine Resultset-Captures abgeleitet.
Die Lieferung verlangt die erforderliche exakte Head-CI und Integration von
PR #364 sowie Synchronisierung und eigenen Cleanup. Analyze beschafft
keine Images und erzeugt keine SMTP-Infrastruktur.

Die zuvor vorbereitete COLL-001-Abnahme für die Metadatensichtbarkeit eines
eigenen TDE-Zertifikats ist am 11. Oktober 2026 im begrenzten Umfang bestanden.
Der frühere Laneguard-Ausgang `DEFERRED_NO_PROVISIONING` bleibt ein nicht
ausgeführter Versuch; der neue eigene Lauf bestätigte 30 Consumerfälle,
unabhängige Orakel, identitätsgebundenes SQLcleanup und öffentlichen Lab-Abbau.
Der [Nachweis](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) beschreibt die
ausgeführten Fälle und den unabhängigen Ergebnisreview. COLL-001 bleibt
partiell. Andere Berechtigungspfade, Fehlercleanup-Gegenproben, ältere native
Engines, Restore und Hostbackingbytes bleiben unbelegt.

Die zusätzliche PlanDetails-Abnahme vom 12. Oktober 2026 bestätigt einen
positiven eigenen Last-Actual-Plan auf SQL Server 2025 mit CL170. Vier
Consumeraufrufe in NONE, TABLE, RAW und CONSOLE bestehen; alle zehn Planfelder
und XML werden gegen die native Quelle geprüft. Positive ActualRows,
TABLE-/RAW-JSON-Parität, Produktgridcounts und unveränderte Callerwerte
sowie die Erhaltung der eigenen 512 Quellzeilen und ihrer Konfiguration
sind belegt. Die drei vorherigen privaten Fehlversuche wegen eines
Typadapters und einer falschen XACT_STATE-Annahme bleiben Fehlversuche.
Produktcode, ABI, Versionen und Maturityflags bleiben unverändert.
Eigene Quelle, Lab, Volume und State sind entfernt; fremde Dockerressourcen
bleiben unverändert. Der [Nachweis](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md)
grenzt den geprüften einzelnen Handle von offenen positiven Live-Plänen,
Rollen-, Quellenfehler-, Timeout- und weiteren Plattformnachweisen ab.
COLL-001 bleibt partiell. Die SMTP-Welle wartet weiterhin auf ihre
öffentliche Lab-Integration samt tatsächlicher Abnahme.

Die zusätzliche positive Live-Plan-Abnahme vom 12. Oktober 2026 bestätigt
die vorhandene PlanDetails-Quelle an einer eigenen aktiven Session auf
SQL Server 2025 mit CL170. Vier Consumerfälle bestehen; native
Identitätsprüfungen, positive ActualRows innerhalb der Messklammern,
TABLE-/RAW-JSON-Parität, Gridcounts und unveränderte Callerwerte sind belegt.
Vier tatsächliche Capturemutationen werden abgewiesen. Der frühere
Fehlversuch wegen der fehlenden StatementText-XMLeigenschaft bleibt getrennt
erhalten. Produktcode, ABI, Versionen und Maturityflags bleiben unverändert.
Die eigene Workloadsession ist nativ abwesend; Quellzeilen und Konfiguration
bleiben erhalten. Quelle, Lab, Volume und State sind entfernt; fremde
Dockerressourcen bleiben unverändert. Der [Nachweis](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md)
grenzt den endlichen eigenen Stream von anderen Workloads, Rollen-,
Quellenfehler-, Timeout- und weiteren Plattformnachweisen ab. COLL-001 bleibt
partiell; SMTP wartet weiterhin auf seine öffentliche Lab-Abnahme.

Die zusätzliche PlanDetails-Abnahme vom 12. Oktober 2026 bestätigt 24
Consumerfälle für einen eigenen Login und Cacheeintrag auf SQL Server 2025
mit CL170. PlanHandle und SqlHandle werden in vier Ausgabemodi bei fehlendem,
erteiltem und ausdrücklich verweigertem VIEW SERVER PERFORMANCE STATE
geprüft. Konstante Datenbankrechte sind Schema-EXECUTE und gezieltes SELECT
auf TVF_ProjectUnicodeText. Modulfehler 300, Textquellenfehler 371, PARTIAL
beziehungsweise DENIED_PERMISSION und die acht positiven AVAILABLE-Ausgänge bestehen;
native Mengen-/Wertvergleiche, TABLE-/RAW-JSON-Parität, fünf tatsächliche
Mutationsablehnungen, Callerwerte und REVERT sind belegt. Eine getrennte
negative Probe bestätigt Fehler 229 ohne Helper-SELECT. Sieben frühere
native Fehlversuche bleiben erhalten; erst der achte Lauf besteht die
vollständige Matrix. Produktcode, ABI, Versionen und Maturityflags bleiben
unverändert. Eigene Principals, Quelle, Lab, Volume und State sind entfernt;
fremde Dockerressourcen bleiben unverändert. Der
[Nachweis](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) grenzt diesen Caller
von weiteren Rollen-, Session-, Actual-/Live-Berechtigungs-, Timeout- und
Plattformnachweisen ab. COLL-001 bleibt partiell; SMTP wartet weiterhin auf
seine öffentliche Lab-Integration und tatsächliche Abnahme.

Die zusätzliche PlanDetails-Abnahme vom 12. Oktober 2026 bestätigt zwölf
Sessionselektor-Consumerfälle auf SQL Server 2025 mit CL170. Eine eigene
endliche aktive Anfrage bleibt durch einen offenen Reader beobachtbar;
Actual und Live sind ausgeschaltet. Die vier Modi bestätigen bei fehlendem
oder ausdrücklich verweigertem Serverrecht die native leere Sichtbarkeit
ohne Fehler und AVAILABLE ohne Kandidaten. Mit erteiltem Recht bestehen
ein exakt gebundener Kandidat, 29 native Attribute, Compile-XML,
TABLE-/RAW-JSON-Parität und sechs tatsächliche Mutationsablehnungen.
Schema-EXECUTE und Helper-SELECT bleiben konstant; Callerzustand und
REVERT bestehen. Zwei Starts bleiben vor Provisionierung zurückgestellt;
erst der dritte atomar reservierte Lauf besteht Matrix und Abschluss.
Eigene Session, Principals, Quelle, Lab, Volume und State sind entfernt;
fremde Dockerressourcen bleiben unverändert. Der
[Nachweis](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) grenzt die
beobachtete Requestgeneration von weiteren Rollen-, Actual-/Live-Rechte-,
Timeout- und Plattformnachweisen ab. Produktcode, ABI, Versionen und
Maturityflags bleiben unverändert. COLL-001 bleibt partiell; SMTP wartet
weiterhin auf seine öffentliche Lab-Integration und tatsächliche Abnahme.

Die zusätzliche Live-Plan-Berechtigungsabnahme von PlanDetails am
12. Oktober 2026 bestätigt zwölf Consumerfälle auf SQL Server 2025 mit
CL170. Acht eingeschränkte Fälle verbinden native leere Requestsichtbarkeit
mit Livefehler 300: Die LIVE_XML-Planzeile erhält ERROR_HANDLED, CandidateId
NULL und den konkreten Fehler, während PARTIAL ohne Modulfehlerfelder
bestehen bleibt. Vier positive Fälle bestätigen dieselbe eigene endliche
aktive Anfrage, native Live-XML-Identitäten, ActualRows-Messklammern und
TABLE-/RAW-JSON-Parität. Schema-EXECUTE und Helper-SELECT bleiben konstant;
Callerzustand, REVERT und sechs tatsächliche Mutationsablehnungen bestehen.
Zwölf lokale synthetische Orakelproben und ein korrigierter erster
Testdoublefehler bleiben getrennt von der nativen Abnahme. Eigene Session,
Principals, Quelle, Lab, Volume und State sind entfernt; Fremdressourcen
bleiben unverändert. Der
[Nachweis](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) charakterisiert
die vorhandene Livefehlerdarstellung und ihre Grenzen, ohne einen neuen
öffentlichen Fehlervertrag festzulegen. Produktcode, ABI, Versionen und
Maturityflags bleiben unverändert. COLL-001 bleibt partiell; Last-Actual-
Berechtigungs-, weitere Rollen-, Timeout- und Plattformnachweise bleiben
offen. SMTP wartet weiterhin auf seine öffentliche Lab-Integration und
tatsächliche Abnahme.

Die zusätzliche Last-Actual-Berechtigungsabnahme von PlanDetails am
12. Oktober 2026 bestätigt zwölf PlanHandle-Consumerfälle auf SQL Server
2025 mit CL170. Acht eingeschränkte Fälle bewahren den Rohkandidaten,
LAST_ACTUAL_XML mit ERROR_HANDLED und den ersten Modulfehler 300;
der getrennte native Textfehler 371 ersetzt diesen Fehler nicht.
Vier positive Fälle bestätigen denselben eigenen Procedure-Cacheplan,
zehn Planfelder, XML mit ActualRows-Zählern, Textmetadaten und
TABLE-/RAW-JSON-Parität. Schema-EXECUTE und Helper-SELECT bleiben konstant;
Callerzustand, REVERT und fünf tatsächliche Mutationsablehnungen bestehen.
Zehn lokale synthetische Orakelproben bleiben von der nativen Abnahme
getrennt. Frühere Starts bleiben vor Provisionierung zurückgestellt;
der erste tatsächliche Runtimeversuch nach Freigabe der Lane besteht.
Eigene Principals, Quelle, Lab, Volume und State sind entfernt;
Fremdressourcen bleiben unverändert. Der
[Nachweis](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) grenzt den
kontrollierten abgeschlossenen Cacheplan von weiteren Rollen-, Timeout-,
Quellenfehler- und Plattformnachweisen ab. Produktcode, ABI, Versionen und
Maturityflags bleiben unverändert. COLL-001 bleibt partiell; SMTP wartet
weiterhin auf seine öffentliche Lab-Integration und tatsächliche Abnahme.

Die zusätzliche QueryHash-Berechtigungsabnahme von PlanDetails am
12. Oktober 2026 bestätigt zwölf Consumerfälle auf SQL Server 2025 mit
CL170. Acht eingeschränkte Fälle entsprechen dem nativen Auswahlfehler
300 mit DENIED_PERMISSION und leeren Kandidatenmengen. Vier GRANTED-Fälle
bestätigen die global eindeutige eigene Auswahl, alle 23 Kandidatenfelder,
UTF-16-Byteoffsets und Textmetriken sowie TABLE-/RAW-JSON-Parität.
Schema-EXECUTE und Helper-SELECT bleiben konstant; Callerzustand, REVERT,
sieben tatsächliche Capturemutationen und eigene Quellenbindungen
bestehen. 18 lokale synthetische Orakelproben bleiben von der nativen
ASCII-/BMP-Textabnahme getrennt. Der erste tatsächliche Runtimeversuch
besteht; eigene Principals, Quelle, Lab, Volume und State sind entfernt,
Fremdressourcen unverändert. Der
[Nachweis](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) begrenzt die
Beobachtung auf einen stabilen eigenen Cacheeintrag; mehrere Hash-Treffer,
weitere Rollen, Cache-Eviction, Textfehler nach positiver Auswahl und
Timeouts bleiben unbelegt. Produktcode, ABI, Versionen und Maturityflags
bleiben unverändert. COLL-001 bleibt partiell; SMTP wartet weiterhin auf
seine öffentliche Lab-Integration und tatsächliche Abnahme.

Die zusätzliche PlanDetails-Abnahme mit zwei eigenen QueryHash-Cacheplänen
am 12. Oktober 2026 bestätigt 24 Consumerfälle auf SQL Server 2025 mit
CL170. NULL/0/2 liefern beide eigenen Kandidaten, Limit 1 den nativen
Worker-Rang 1. Negatives Limit und unbestätigtes NULL-Limit bestätigen
INVALID_PARAMETER beziehungsweise HIGH_IMPACT_CONFIRMATION_REQUIRED mit
leerer Auswahl ohne Partialität. Der privilegierte Caller bleibt gebunden;
alle 23 Kandidatenfelder, UTF-16-Offsets, Textmetriken und TABLE-/RAW-JSON-
Parität stimmen mit stabilen nativen Vor- und Nachproben überein.
Acht tatsächliche Capturemutationen und 36 getrennte lokale synthetische
Orakelproben bestehen. Drei lokale Fehlaufrufe und ein vor Runtime
geschlossener PREEXEC-Wrapperbefund bleiben dokumentiert. Der erste
tatsächliche Runtimeversuch besteht; eigene Quelle, Lab, Volume und State
sind entfernt, Fremdressourcen unverändert. Der
[Nachweis](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) begrenzt die
Beobachtung auf genau zwei eigene Pläne mit strikter Worker-Rangfolge;
weitere Varianten, Sortgleichstände, eingeschränkte Rollen, Cache-Eviction
und Timeouts bleiben unbelegt. Produktcode, ABI, Versionen und Maturityflags
bleiben unverändert. COLL-001 bleibt partiell; SMTP wartet weiterhin auf
seine öffentliche Lab-Integration und tatsächliche Abnahme.

Die zusätzliche native PlanDetails-Textprojektion vom 12. Oktober 2026
bestätigt 24 Consumerfälle auf SQL Server 2025 mit CL170. Eigene BMP- und
Supplementary-Zeichen bleiben bei NULL/0 vollständig erhalten; positive
Grenzen vor und einschließlich eines Surrogate-Paars bestätigen exakte
Scalarprojektion bei unveränderten ursprünglichen Zeichen-/Bytemetriken
und korrekten Truncationbits. Zwei tatsächliche Batch-Endleerzeichen,
alle 23 Kandidatenfelder, TABLE-/RAW-/CONSOLE-JSON-Parität, Caller/SID,
acht Capturemutationen und stabile Quellenbindungen bestehen.
45 lokale synthetische Orakelproben bleiben getrennt; ein vor Runtime
geschlossener Leerzeichen-PREEXEC-Befund und der dadurch aufgefundene
lokale Testdoublefehler bleiben dokumentiert. Der erste native
Runtimeversuch besteht; eigene Quelle, Lab, Volume und State sind entfernt,
Fremdressourcen unverändert. Der
[Nachweis](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) begrenzt die
Beobachtung auf die eigene unveränderte Definition; andere Collations,
Unicodefolgen, Rollen, Quellenfehler und Timeouts bleiben unbelegt.
Produktcode, ABI, Versionen und Maturityflags bleiben unverändert.
COLL-001 bleibt partiell; SMTP wartet weiterhin auf seine öffentliche
Lab-Integration und tatsächliche Abnahme.

Die begrenzte Charakterisierung vorhandener PlanDetails-Selektorkombinationen
vom 12. Oktober 2026 bestätigt 24 Consumerfälle auf SQL Server 2025 mit
CL170. PlanHandle plus SqlHandle beziehungsweise QueryHash liefert bei
Limit 2 eine direkte Handlezeile und eine Statementzeile desselben eigenen
Plans; Limit 1 behält die Handlezeile. SqlHandle plus QueryHash liefert
in beiden Limits eine Statementzeile. Alle 23 Felder, nullable Metadaten,
Textgranularität, TABLE-/RAW-/CONSOLE-JSON-Parität und Caller/SID stimmen
mit gebundenen nativen Vor- und Nachproben überein. Acht Capturemutationen
und 42 getrennte lokale Fälle bestehen. Ein lokaler Testdoublefehler und
der erste native Adapterfehlversuch ohne Consumer-Capture bleiben erhalten;
der korrigierte private Parameterpfad wird separat geprüft. Der zweite
native Versuch besteht; eigene Quelle, Lab, Volume und State sind entfernt,
Fremdressourcen unverändert. Der
[Nachweis](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) ist kein neuer
allgemeiner Union-, Dedup- oder Prioritätsvertrag. Sessionkombinationen,
mehrere Statements, weitere Cachevarianten, Rollen und Timeouts bleiben
unbelegt. Produktcode, ABI, Versionen und Maturityflags bleiben unverändert.
COLL-001 bleibt partiell; SMTP wartet weiterhin auf seine öffentliche
Lab-Integration und tatsächliche Abnahme.

Die zusätzliche PlanDetails-Abnahme am 12. Oktober 2026 bestätigt zwei
unterschiedliche Statements in derselben einmalig ausgeführten eigenen
Cacheprocedure auf SQL2025 mit CL170. 24 Consumeraufrufe prüfen SqlHandle
mit Limit 1 und 2, jeden QueryHash einzeln und beide SqlHandle-/QueryHash-
Kombinationen. Ein Plan, zwei unterschiedliche Hashes und UTF-16-Offsets,
strikte native Workerrangfolge, alle 23 Kandidatenfelder, vollständige Texte
und ihre ursprünglichen Metriken sowie physische JSON-Parität sind belegt.
Callerbaseline 137/0/1/0 und die eigene SA-SID bleiben erhalten. Neun
tatsächliche Capturemutationen und 43 getrennte lokale Proben bestehen.
Ein lokaler Erwartungstypfehler und eine vor Runtime im unabhängigen Review
korrigierte XACT_STATE-Annahme bleiben dokumentiert. Der erste native
Versuch besteht; Quelle, Lab, Volume und State sind entfernt,
Fremdressourcen unverändert. Der unabhängige Ergebnisreview besitzt keine
offenen Befunde; alle 75 statischen Validatoren bestehen. Der
[Nachweis](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) charakterisiert
die bestehende Statementgranularität und erweitert keinen öffentlichen
Auswahlvertrag. Gleichstände, weitere Cachevarianten, Rollen,
Sessionkombinationen und Timeouts bleiben unbelegt. Produktcode, ABI,
Versionen und Maturityflags bleiben unverändert; COLL-001 bleibt partiell.

Lab-PR #744 ist inzwischen auf dem öffentlichen Stand
`abf5cc099b4200f8c3b6d7d65dd15b33c0016bac` integriert. Die dortige
`LOCAL_VALIDATION_STRATEGY.md` dokumentiert den ausgeführten vollständigen
Docker-Database-Mail-Lifecycle. Die frühere öffentliche SMTP-Barriere ist
damit abgelöst. Lab-PR #745 ergänzt auf dem öffentlichen Stand
`5a7b28a32c0383d1f9bb04bb701c5f1d2cab3121` den passenden
`imageProvisioning=require-existing`-Vertrag mit lokalen unveränderlichen
Image-IDs, `--pull=never`, fehlendem Gateway-Build und OwnedHost-Bindung über
das vorhandene Sendernetz. Lab-PR #747 veröffentlicht die ausgeführten
begrenzten Docker-/OwnedHost-Abnahmen dieses Pfads auf
`ecd535a7dd96f1307c1f4c20cca3b171b8f9a713`. Der Analyze-Runner ist angepasst;
zwei tatsächliche eigene Versuche bleiben nach getrennten Adapter- und
SQL-Fixturefehlern nicht qualifiziert. Nach den eng geprüften Korrekturen und
ausdrücklicher Freigabe besteht der dritte Lauf mit einer synthetischen Mail,
drei Consumerfällen und eigenem Cleanup auf SQL2025 `17.0.4075.5`/CL170.
Der begrenzte Nachweis erweitert keinen allgemeinen Versandvertrag;
OPS-008 bleibt partiell. Analyze implementiert keine
SMTP-Infrastruktur und übersteuert keine privaten Lab-Funktionen.
Unveränderte Voraussetzungen lösen keinen Runtimeversuch aus.

Die kanonische COLL-001-Zeile in
[Implementation_Status.csv](../../../Metadata/Quality/Implementation_Status.csv)
enthält zusätzlich die am 12. Oktober 2026 qualifizierten begrenzten
PlanDetails-Nachweise. DeliveredScope und OpenScope trennen die nachgewiesenen
Quellen-, Berechtigungs-, Text- und Selektorfälle von weiteren Cachegenerationen,
Evictionpfaden, systematischen Fehlern, Timeouts und zusätzlichen Kontexten.
`PARTIAL_PRODUCT_FUNCTION` bleibt unverändert; aus diesen Nachweisen folgt
kein allgemeiner Auswahl-, Fehler- oder atomarer Cross-call-Vertrag.

Der begrenzte eigene Cache-Eviction-Nachweis von USP_PlanDetails besteht
auf SQL2025 17.0.4075.5 und CL170 mit 24 Consumerfällen, neun tatsächlichen
Capturemutationen und 58 getrennten lokalen Proben. Nach gezielter Entfernung
des einmalig ausgeführten eigenen Plans sind seine gebundenen Cache- und
QueryStats-Mengen leer. PlanHandle und PlanHandle mit SqlHandle behalten
je einen Rohkandidaten ohne Text; alleiniger SqlHandle und QueryHash liefern
keine Kandidaten. Alle Modulstatus sind AVAILABLE. Die native SqlHandle-
Textquelle behält die eigene Definition; daraus folgt bei leerer Auswahl
kein Kandidat. Der erste native Versuch bleibt wegen eines korrigierten
privaten Handlelängenguards nicht qualifiziert; der zweite besteht.
Callerzustand, eigene Quelle, sichere Ressourcenbereinigung und unveränderte
Fremdressourcen sind belegt. Details und Grenzen stehen in
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md). Produktcode,
Verträge und Maturityflags bleiben unverändert; andere Evictionpfade,
Quellenfehler und systematische Timeouts bleiben offen.

Der begrenzte PlanDetails-Nachweis für Sessionselektorkombinationen besteht
auf SQL2025 17.0.4075.5 und CL170 mit 24 Consumerfällen, acht tatsächlichen
Capturemutationen und 43 getrennten lokalen Proben. Eine eigene endliche
aktive Request wird mit ihrem PlanHandle oder getrennten eigenen
Procedure-Cachequellen kombiniert. Native Request- und Cachebindungen,
alle 23 Kandidatenfelder, gleichaufrufbezogene physische JSON-Parität,
Mengenlimits und Callerzustand bestehen. Eigene Session, Quelle, Lab,
Volume und State sind entfernt; Fremdressourcen sind unverändert. Ein
lokaler Testdoublefehler und der vor Runtime korrigierte PREEXEC-Befund
zur Capturespeicherung bleiben erhalten. Details und Grenzen stehen in
[COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md). Produktcode,
Verträge und Maturityflags bleiben unverändert; weitere Kontexte,
Quellenfehler und systematische Timeouts bleiben offen.

Der Benutzer hat am 5. Oktober 2026 die autonome Entwicklung beauftragt und
die bereits in SQL_Server_Toolbelt und SQL_Server_Lab verwendeten
Autonomieregeln ausdrücklich herangezogen. Die Arbeit verwendet weiterhin
die vorhandene Roadmap und Statusquellen. Jeder kohärente Schritt umfasst
die betroffenen Verträge, Implementierung, Dokumentation und Tests. Es gibt
genau einen Implementierer je Schritt; ein unabhängiger Review prüft bei
fachlichem Risiko oder verbindlicher Unabhängigkeitsvorgabe den stabilen
Stand. Weitere Reviewer benötigen konkrete offene Risiken und Abnahmekriterien.
Mechanische Nachweise werden lokal geprüft; unveränderte erfolgreiche Tests
und abgeschlossene Reviews werden nicht ohne neuen Anlass wiederholt. Vor der Fortsetzung werden `origin/main`, offene Pull Requests,
Regelkontext und vorhandene Evidenz abgeglichen. Geprüfte Schritte werden
über einen Pull Request mit erfolgreicher erforderlicher Head-CI integriert;
danach folgen Synchronisierung und ausschließlich eigener Cleanup. Nach
dem bestätigten PR-Merge nach `origin/main` werden auch die integrierten
lokalen Arbeitsbranches entfernt; der aktive Entwicklungsbranch bleibt erhalten.

Die bestehenden Produkt-, Datenschutz- und Testregeln dieses Repositorys
bleiben maßgeblich. Neue öffentliche Funktionsverträge werden vor ihrer
Implementierung konkretisiert und funktionsbezogen freigegeben. Bestehende
konkrete Freigaben werden nicht erneut abgefragt. Linked-Server-Verbindungen
zwischen ausschließlich neu erzeugten lokalen Testcontainern sind ausdrücklich
freigegeben. Bestehende, gemeinsam verwendete und produktive Systeme sind
nicht Teil dieser Freigabe. Secrets und konkrete Runtimeidentitäten bleiben
außerhalb der Repositoryartefakte.

Ein abgeschlossener Schritt oder ein zusätzlicher Benutzerauftrag beendet
die Gesamtwelle nicht. Unabhängige autorisierte Arbeit wird bei einem
isolierten Blocker fortgesetzt. Die automatische Fortsetzung dieses Chats
unterstützt die Entwicklung bis zum ausdrücklichen Benutzerstopp, regulären
Gesamtabschluss oder tatsächlichen Eingabebedarf; unveränderte,
nicht handlungsfähige Zustände erzeugen keine Statusmeldungen.

Der Fortsetzungsrhythmus ist keine Wartefrist für laufende autorisierte
Entwicklung. Sobald ein unabhängiger ausführbarer Schritt feststeht, beginnt
er unmittelbar nach den erforderlichen Vorprüfungen.

## Sessionwechsel bei langer autonomer Entwicklung

Die logische Entwicklungsrolle bleibt über Sessionwechsel erhalten. Aktueller
Repositorystand, Arbeitselemente, Entscheidungen und Validierungsevidenz sind
die Fortsetzungsquellen. Ein Wechsel wird an einer natürlichen Arbeitsgrenze
oder auf ausdrücklichen Benutzerauftrag vorbereitet; er beendet die
beauftragte Entwicklungswelle nicht.

Entscheidungen verwenden ausschließlich verfügbare deterministische
Kontextmetadaten. Unbekannte Tokenzahlen und Kontextgrenzen bleiben unbekannt.
Dieses Projekt legt derzeit keine numerischen Soft-/Hard- oder
Checkpointschwellen fest und aktiviert keinen automatischen Lifecycle-Planner.
Antwortlatenz und wiederkehrende semantische Analyse des gesamten Chats sind
keine automatischen Wechseltrigger.

Bei einem tatsächlich gewählten Checkpoint werden geänderte bestätigte Fakten
in die kanonischen Projektquellen aufgenommen. Eine Fortsetzung erhält deren
Referenzen und höchstens einen autorisierten externen Delta-Handoff seit dem
vorherigen Checkpoint. Runtime-Sessionkennungen, vollständige Chats und
Handoffinhalte werden nicht ins Repository übernommen. Ein Nachfolger lädt
die native Anweisungskette und prüft den aktuellen Repositorystand erneut.

Der Benutzer hat am 6. Oktober 2026 die aufgabenbezogene Erzeugung neuer
Orchestrator-Chats freigegeben, wenn ein Wechsel angebracht ist. Ein Wechsel
wird an einer natürlichen Arbeitsgrenze vorbereitet und verwendet eine
verfügbare Clientfunktion. Erst ein vom Client als verfügbar bestätigter
Nachfolger mit tatsächlicher `threadId` belegt die Erzeugung; eine vorgemerkte
Einrichtung bleibt ausstehend.
Ohne verfügbare Clientfunktion bleibt die Erzeugung manuell. Eine Empfehlung
oder ein Handoff allein gilt nicht als ausgeführter Sessionwechsel.

Der Nachfolger übernimmt die logische Entwicklungsrolle und lädt die aktuelle
native Anweisungskette sowie die kanonischen Projektquellen erneut. Eine kurze
Übergabe verweist auf den bestätigten Projektstand, aktuelle Arbeit und offene
Punkte; Sessionkennungen und Handoffinhalte bleiben außerhalb von Git. Bei
einem tatsächlichen Wechsel wird die bestehende automatische Fortsetzung erst
nach dieser Bereitschaftsbestätigung dem Nachfolger zugeordnet, damit nur ein
Orchestrator die autonome Arbeit steuert.
Es werden keine zusätzliche periodische Rotation und keine numerischen
Kontextschwellen aktiviert.

## Aktueller Produktstand

Der portable Frameworkkern ist für SQL Server 2019, 2022 und 2025 implementiert. Die allgemeine Lab-Provisionierung und deren Lifecycleverantwortung liegen in `gecompat/SQL_Server_Lab`. SQL Server Analyze enthält weiterhin Frameworkcode, Dokumentation, analyserspezifische Szenarien und die benutzerorientierte Beispielsteuerung.

Die kanonische Release-Evidenz umfasst alle 17 P0-, 40 P1- und 124 P2-Fälle. Die abgeschlossene P0-, P1- und P2-Special-Case-Matrix bleibt Bestandteil des bestätigten Produktstands.

### Abgeschlossen – SQL25-005

`USP_QueryStoreReplicaAnalysis` und der Query-Store-Orchestrator trennen SQL-Server-2025-Runtime-, Wait- und Plan-Forcing-Evidenz nach beobachteter Replica-Rolle. SQL Server 2019 und 2022 liefern versionssicher `UNAVAILABLE_VERSION`.

`ANALYZE-LAB-001` ist für den definierten Sieben-Beispiele-Umfang abgeschlossen. Die sechs zusätzlich katalogisierten Beispiele sind dokumentiert, über den gemeinsamen Interactive-/Verify-Runner auswählbar und auf SQL Server 2025 mit dem primären Docker-Provider runtimegeprüft. Der Project-Adapter-Slice `EXECUTION-PLAN-001` installiert zusätzlich den eigenständigen Execution-Plan-Analyse-Frameworkteil und bestand seinen SQL-Server-2025-Quick-Run unter Docker und Podman einschließlich scopegebundenem Cleanup.

Das registrierte Intake-Arbeitselement `WI-0010` hält in der neuen [Diagnoseabdeckung und Gap-Intake](../Research/SQL_Server_Diagnostic_Coverage_Landscape.md) darüber hinaus 106 implementierte, partielle, geplante, externe oder bewusst ausgeschlossene Themen fest. Es ändert die folgende ausführbare Reihenfolge nicht. Neue Kandidaten erhalten erst nach dem Reifeabschluss und einem eigenen Dossier eine Registryreferenz.

Alle 104 Procedure-Seiten besitzen den Status `DEEP_REVIEWED` nach Reviewvertrag 3. Dieser Dokumentationsanteil des Reifeabschlusses ist erledigt und ersetzt keine noch offene Laufzeitevidenz.

## Nächste ausführbare Welle: Reifeabschluss

Die nächste Welle erweitert keine öffentliche Diagnosefläche. Sie schließt die bereits implementierten Teilfunktionen und zugehörigen Reifeverträge ab.

1. `OPS-005` ergänzt die noch offene Providervarianz. Der kontrollierte MSOLEDBSQL-Verbindungserfolg zwischen zwei neuen lokalen SQL-Server-2025-Containern ist seit dem 5. Oktober 2026 belegt. Der synthetische TestLab-Adapter deckt bereits die Drei-Versionen-, Berechtigungs- und Timeoutfälle ab; zusätzliche native Erfolgsläufe folgen nur bei konkretem Versionsrisiko oder erforderlichem Release-Nachweis.
2. `OPS-006` schließt die verbleibende Evidenz einer tatsächlich nicht unterstützten Systemquelle. Der kontrollierte Feature-Nachweis auf nativen SQL Server 2019, 2022 und 2025 sowie die vorhandenen Berechtigungspfade werden nicht erneut als offene Arbeit geführt.
3. `OPS-008` ergänzt tatsächlich fehlende optionale Quellen sowie Mail-/Maintenance-Ausführungs- und Retentionsevidenz. Fünf kontrollierte Leerfälle, kurze und lange Backup- und Restorezeitfenster und kontrolliertes Dateiwachstum sind auf SQL Server 2025 belegt. TEST-0001 ergänzt injizierte Agent-Job- und Stepaggregate mit unveränderten Quellwerten. Die getrennte Mail-/Maintenance-Fixture bestätigt nicht leere Counts und native MIN-/MAX-Zeitwerte in neun Consumeraufrufen mit Quell- und Callererhaltung; sie führt weder Mailversand noch Maintenance aus. Eine weitere getrennte Fixture belegt die tatsächliche erfolgreiche Ausführung eines eigenen minimalen lokalen Agent-Jobs mit einem Schritt auf SQL Server 2025/Docker, zwei nativen Historyzeilen, Consumerparität und Quell-/Callererhaltung. Sie injiziert keine Historie und entfernt den eigenen Job samt Historie. Eine getrennte native Retentionfixture bestätigt zwei erfolgreiche eigene Jobausführungen und vier, zwei sowie null Historyzeilen nach gezieltem sp_purge_jobhistory mit eigener Job-ID; jüngere Quellwerte, neun Consumerparitäten und Callerzustand bleiben erhalten. Die getrennte Backup-/Restore-Retentionfixture bestätigt drei, ein und null eigene native Paare nach sp_delete_backuphistory mit kontrollierten Historienzeitstempeln; die jüngeren vollständigen Werte aller acht betroffenen Historientabellen sowie neun Consumerparitäten und Callerzustand bleiben erhalten. Die getrennte Mailretention-Fixture bestätigt drei, eine und null injizierte Failed-Mailzeilen nach sysmail_delete_mailitems_sp mit expliziten Datumsgrenzen und Statusfilter; jüngere vollständige Mailitemwerte sowie neun Consumerparitäten und Callerzustand bleiben erhalten. Mail-XPs bleiben deaktiviert; das abschließende Rollback entfernt die Fixture. Die getrennte Maintenanceretention-Fixture bestätigt drei, eine und null injizierte Elternzeilen nach sp_maintplan_delete_log mit expliziten Datumsgrenzen und NULL-Planfiltern; jüngere vollständige Werte sowie neun Consumerparitäten und Callerzustand bleiben erhalten. Plans, Subplans und Detailhistorie bleiben leer; das abschließende Rollback entfernt die Fixture. Die getrennte Mailstatusretention-Fixture bestätigt für unsent, sent, failed und retrying je drei, eine und null injizierte Zielzeilen bei Gesamtcounts sechs, vier und drei; vollständige ältere Werte der jeweils anderen Status sowie 36 Consumerparitäten und Callerzustand bleiben erhalten. Vier getrennte Transaktionen werden zurückgerollt; Mail-XPs bleiben deaktiviert. Die getrennte Mailfehler-Fixture bestätigt ohne Historieninjektion einen eigenen nativen Queueauftrag mit Failed-Status und gebundenem Prozessfehlerlog; Drei Consumerparitäten, Quell- und Callererhaltung bei deaktivierten Mail-XPs, das eigene Mail-, Profil- und Kontocleanup sowie die Queue- und Konfigurationswiederherstellung sind belegt. Die getrennte native Maillogretention-Fixture bestätigt drei, eine und null ausgewählte Prozessfehlerlogs aus drei eigenen nativen Mailfehlern nach zwei typ- und datumsgebundenen Logpurges mit kontrollierten Logzeiten. Jüngere und erfasste übrige Logwerte einschließlich einer älteren Informationsgegenprobe sowie sämtliche Mailitems bleiben bei neun Consumeraufrufen und deaktivierten Mail-XPs erhalten; das Callerrollback stellt die ursprünglichen ausgewählten Logwerte wieder her. Die getrennte Anlagenretention-Fixture bestätigt nach zwei nativen Datums-/Failed-Statuspurges drei, eine und null injizierte Mailzeilen sowie sechs, zwei und null Binäranlagen mit Bytezahlen 54, 18 und null. Vollständige jüngere Mail-/Anlagenwerte sowie neun Consumerparitäten und Callerzustand bleiben erhalten; Mail-XPs bleiben deaktiviert und das Rollback entfernt sämtliche injizierten Zeilen. Die getrennte Maintenance-Detailretention-Fixture bestätigt nach zwei nativen Datums-/NULL-Planfilterpurges drei, eine und null injizierte Elternzeilen sowie sechs, zwei und null verknüpfte Details. Vollständige jüngere Zehnfeld-Eltern- und Dreizehnfeld-Detailwerte, Bindungen ohne verwaiste Details sowie neun Consumerparitäten und Callerzustand bleiben erhalten; Plans und Subplans bleiben leer und das Rollback entfernt sämtliche injizierten Zeilen. Die getrennte Planfilterretention-Fixture bestätigt nach zwei nativen Plan-ID-/Datumspurges Zielcounts drei eins null bei Gesamtcounts fünf drei zwei und Detailcounts zehn sechs vier. Vollständige jüngere Zielwerte und ältere Gegenproben mit anderem sowie NULL-Plan bleiben erhalten; ein nicht passender Planfilter erhält sämtliche Quellwerte. Neun Consumerparitäten und Callerzustand bleiben erhalten; Plans und Subplans bleiben leer und das Rollback entfernt sämtliche injizierten Zeilen. Die getrennte Subplanfilterretention-Fixture bestätigt nach zwei nativen Subplan-ID-/Datumspurges Zielcounts drei eins null bei Gesamtcounts sechs vier drei und Detailcounts zwölf acht sechs. Vollständige jüngere Zielwerte ältere Gegenproben sämtliche Subplan- und Jobmetadaten sowie neun Consumerparitäten und Callerzustand bleiben erhalten; ein nicht passender Subplanfilter erhält sämtliche Quellwerte. Das Rollback entfernt sämtliche injizierten Maintenancezeilen und den deaktivierten eigenen Job ohne Steps Serverzuordnung oder Historie. Die getrennte Filtergrenzfixture bestätigt die native Ablehnung gleichzeitiger Plan-/Subplan-IDs mit Fehler 2732 aus msdb.dbo.sp_maintplan_delete_log. Bei XACT_ABORT OFF bleiben sechs Eltern zwölf Details alle Metadaten neun Consumerparitäten und committable Callerzustand erhalten. Ein zusätzlicher ON-Fall bestätigt den uncommittable Callerzustand bei unveränderten Quellen vor eigenem Rollback; ursprünglicher Locktimeout und XACT_ABORT werden abschließend geprüft. Die vier Maintenance-Retentionfixtures stellen ursprünglichen Locktimeout und XACT_ABORT direkt im Callerbatch wieder her; der gemeinsame native Lauf bestätigt 36 Consumeraufrufe und vier Rollbacks. Eine getrennte private Probe bestätigt acht injizierte Fehlerfälle mit ursprünglichem OFF oder ON sowie vier frühe Locktimeout-31-Ablehnungen bei erhaltenen Optionen und acht leeren Quellen auf derselben Verbindung. Die vier injizierten Mailfixtures restaurieren beide Optionen direkt im Callerbatch mit 63 nativen Consumeraufrufen und sieben Rollbacks. Eine getrennte private Gegenprobe bestätigt acht Fehlerfälle und vier frühe Ablehnungen bei erhaltenen Optionen sieben leeren Mail-/Maintenancequellen und deaktivierten Mail-XPs; gemischter Fehlerpunkt nach erstem Einzeilenaufbau und Statusfehlerpunkt nur erster unsent-Fall. Die beiden tatsächlichen Agentfixtures restaurieren beide Optionen direkt im Callerbatch mit zwölf nativen Consumeraufrufen vier Rollbacks und eigenem Jobcleanup. Eine getrennte private Gegenprobe bestätigt vier Fehlerfälle mit ursprünglichem OFF oder ON und zwei frühe Locktimeout-31-Ablehnungen mit erhaltenen Optionen und sechs leeren Agentquellen auf derselben Verbindung; Fehlerpunkte nach bestätigtem Jobabschluss und bei Retention nur Phase 1. Die Backup-/Restore-Retentionfixture restauriert beide Optionen direkt im Callerbatch mit neun nativen Consumeraufrufen drei Rollbacks und eigenem Erfolgscleanup. Eine getrennte private Gegenprobe bestätigt zwei Fehlerfälle mit ursprünglichem OFF oder ON sowie eine frühe Locktimeout-31-Ablehnung in zwei neuen Labs; nach beiden Fehlern bleiben Optionen genau gebundene eigene Datenbanken vollständige Werte von acht Historienquellen und acht Katalogfelder auf derselben Verbindung erhalten; eigenes äußeres Labcleanup entfernt diese Ressourcen. Fehlerpunkt ausschließlich Phase 1 vor erstem Consumer. Die beiden tatsächlichen nativen Mailfixtures restaurieren ursprünglichen Standardlocktimeout und XACT_ABORT direkt im Callerbatch mit zwölf nativen Consumeraufrufen zwei Rollbacks eigenem Erfolgscleanup sowie Queue- und Konfigurationswiederherstellung. Eine getrennte private Gegenprobe bestätigt vier Fehlerfälle mit ursprünglichem OFF oder ON sowie zwei frühe Locktimeout-31-Ablehnungen in vier neuen Labs. Nach allen vier Fehlern bleiben Optionen vollständige eigene Mail- Profil- Konto- und genaue Bindungswerte auf derselben Verbindung erhalten; Mail-XPs bleiben deaktiviert und Transaktionen geschlossen. Beide Logfehlerfälle erhalten zusätzlich Originalwerte derselben vier ausgewählten Logs nach Rollback; äußeres Labcleanup entfernt verbliebene Ressourcen. Fehlerpunkte ausschließlich vor erstem Consumer und bei Logretention nur Phase 1. Die älteren dynamischen Restores sind korrigiert. Die drei älteren Fenster- und Agent-Aggregatfixtures restaurieren XACT_ABORT direkt im Callerbatch ohne Locktimeoutsetzung; elf normale NONE-Aufrufe und eigenes Agentrollback bestehen. Eine getrennte private Gegenprobe bestätigt neun Fälle in fünf neuen Labs: drei frühe TX1-Ablehnungen mit ursprünglichem OFF und sechs injizierte Fehler mit ursprünglichem OFF oder ON jeweils bei Locktimeout 31 mit erhaltenen Optionen und Callerbasis auf derselben Verbindung. Fensterfehler erhalten die vollständigen Werte von acht Historienquellen und acht Datenbankkatalogfeldern sowie genaue eigene Datenbankbindungen; das Agentrollback erhält sechs ursprüngliche Agentquellen. Die Fehlerpunkte betreffen ausschließlich das erste Backup beziehungsweise den ersten Restore sowie die erste injizierte Agentzeile vor dem folgenden Consumer; das äußere Labcleanup entfernt verbliebene Fensterressourcen. Die bestehende Failed-Mailretention ergänzt einen zweiten getrennten NULL-Datumsfall mit explizitem Failed-Statusfilter. Drei Zielzeilen aus 2000, 2025 und 2030 werden entfernt; drei ältere unsent-, sent- und retrying-Gegenproben bleiben mit sämtlichen Werten erhalten. Der normale SQL2025-Lauf bestätigt insgesamt 15 Consumeraufrufe und zwei Rollbacks. Ein privater Lauf bestätigt den unveränderten Erfolg mit ursprünglichem XACT_ABORT ON und die Ablehnung einer endlichen Datumsgrenze mit Fehler 55185. Nach beiden Teilfällen bleiben ursprüngliche Optionen, TX0, drei leere Mailquellen und deaktivierte Mail-XPs auf derselben Verbindung erhalten. Der Gesamtlauf scheitert am dritten privaten Orakel mit 56091 und erzeugt keine Ergebnisdatei; beide NULL-Filter sind keine gültige All-Delete-Auswahl. Beide eigenen Labs werden entfernt. Eine anschließende getrennte Diagnose auf SQL2025 mit ProductVersion 17.0.4075.5 und Framework-CL170 erfasst bei beiden NULL-Filtern den ursprünglichen SQL-Fehler 14608 und Prozedur-Enum OTHER in Fall 2 Phase 2 nach zwölf Consumeraufrufen; sechs vollständige Mailitemwerte bleiben vor Rollback erhalten. Die gültige All-Status-Gegenprobe mit Datum 2031 entfernt alle sechs Zeilen und wird mit 55185 im selben Slot zurückgewiesen. Beide Fälle restaurieren ursprüngliches OFF Locktimeout -1 TX0 vor Quellabfragen erfassten XACT_STATE 0 drei leere Mailquellen und deaktivierte Mail-XPs. Der Diagnoselauf ist COMPLETED mit einer OBSERVED_REJECTION und einer bestandenen Gegenprobe; sein eigenes Lab wird mit zwei Cleanupschritten ohne Fehler entfernt und das Stateverzeichnis ist anschließend nicht vorhanden. Erfolgreiche Mail- und tatsächliche Maintenance-Ausführung, automatische Aufbewahrung der Agenthistorie sowie der Backup-/Restore-, Mail- und Maintenancehistorien, weitere Anlagen- und Historienretention sowie noch unbelegte Jobdatums- und Dauerfälle bleiben offen. Die drei positiven Joboutcomes belegen lokale Startzeitpunkte und Dauerwerte; Dieser injizierte Joboutcomeumfang belegt keine tatsächliche Stepausführung und kein Retryverhalten; ungültige Kalenderwerte, Überläufe, Zeitfenstergrenzen sowie UTC- und Endzeitinterpretation bleiben für ihn ungeprüft. Der zusätzliche injizierte Step-Slice bestätigt drei positive Dauerfälle und die Auswahl getrennt je Step mit 21 Consumeraufrufen. Der spätere statische Bereichsnachweis schließt Integerüberlauf nur in den beiden identischen AgentJobs-Dauerformeln bei deklarierter int-Quelle aus; native Endpunktfälle, ungültige Dauerformate und andere Arithmetik bleiben unbelegt. Eine spätere private SQL2025/CL170-Kalendergegenprobe misst bei 20230229 und 20240230 jeweils als Job- und Stepoutcome nativ Fehler 242. Zwölf Consumeraufrufe plus fehlerfreie Monitoring-Baseline erhalten sechs vollständige Agentquellen und Callerzustand bei XACT_ABORT OFF; vier Rollbacks und eigenes Labcleanup bestehen. AgentJobs isoliert alle vier Fehler und erhält bei Stepfehlern den gültigen Joboutcome; Monitoring begrenzt ungültige Joboutcomes und behält bei Stepfehlern den gültigen Joboutcome. Andere ungültige Daten Uhrzeiten XACT_ABORT ON und tatsächliche Stepausführung bleiben für diesen Kalenderumfang offen. Eine spätere getrennte Uhrzeitgegenprobe bestätigt vier Job-/Stepfälle für 236060 und 240000 bei gültigem Datum 20240229 mit nativem Fehler 242 und denselben begrenzten Consumerzuständen. Zwölf Consumeraufrufe plus Baseline erhalten sechs vollständige Quellen bei OFF und Locktimeout 31; vier Rollbacks, finale Optionsrestauration und eigener Labcleanup bestehen. 236060 verändert Minuten und Sekunden gemeinsam; isolierte Teilfeldgrenzen und weitere Uhrzeitwerte bleiben offen. Eine spätere tatsächliche private Retrygegenprobe bestätigt einen eigenen TSQL-Step mit einem konfigurierten Retry und Intervall 0 auf SQL2025 17.0.4075.5/Docker und CL170. Drei native Zeilen zeigen Retrystatus 2 Steperfolg 1 Joberfolg 1 bei gespeicherten retries_attempted 0. Vier NONE/JSON-Consumer erhalten sechs vollständige Quellen und committable TX1 mit ON und Locktimeout 31; der Problemfilter erhält den deaktivierten Job und zeigt keinen problematischen Step. Ein Rollback eigenes Jobcleanup finale Optionsrestauration und Labcleanup bestehen. Zwei vorherige private Läufe scheitern vor Consumers mit Orakelfehler 56147; nur die zweite Diagnose misst die falsche Erfolgsrow-Erwartung retries_attempted 1 gegenüber dem gespeicherten Wert 0 und beide eigenen Labs sind entfernt. Retryerschöpfung positive Intervalle Parallelität und innere Fehlercleanup-Gegenproben bleiben für diesen Erfolgsumfang ungeprüft. Eine spätere getrennte SQL2025-17.0.4075.5/Docker-CL170-Gegenprobe bestätigt Erschöpfung eines konfigurierten Retries bei Intervall 0 mit dem TSQL-Step eines eigenen aktivierten Jobs. Drei native Zeilen zeigen Retry2 Stepfailed0 Jobfailed0; die letzte Stepzeile speichert retries_attempted 1. Vier NONE/JSON-Consumer erhalten sechs vollständige Quellen und ON31TX1; beide AgentJobs-Filter enthalten den letzten failed Step und Monitoring meldet LATEST_JOB_RUN_FAILED_IN_WINDOW/HIGH ohne Consumerfehler. Ein Rollback eigenes Jobcleanup finale Optionsrestauration und eigener Labcleanup bestehen. Dieser Erschöpfungsumfang hat keinen vorausgehenden nativen Fehlversuch; positive Intervalle Parallelität und innere Fehlercleanup-Gegenproben bleiben unbelegt. Eine getrennte private SQL2025-17.0.4075.5/Docker-CL170-Probe bestätigt automatische Vierzeilen-Retention pro Job mit drei erfolgreichen eigenen Einstepläufen und Historycounts zwei vier vier. Das erste instance_id-Paar verschwindet und vollständige zweite Paarwerte bleiben erhalten; zwölf NONE/JSON-Consumer erhalten sechs vollständige Quellen und ON31TX1. AgentJobs erhält den letzten erfolgreichen Step und zeigt im Problemfilter keinen Step; Monitoring meldet ENABLED_JOB_WITHOUT_SCHEDULE/INFO. Drei Rollbacks eigenes Jobcleanup finale Optionsrestauration und äußerer Labcleanup bestehen. Zwei vorausgehende Konfigurationsreadbackguards scheitern vor Restart und Frameworktests; nur der zweite misst get-Exit0 mit einer Nichtgefundenmeldung. Alle eigenen Labs sind entfernt. Die konfigurierte globale Grenze64 wird nicht erreicht; Altersretention Parallelität andere Engines und innere Fehlercleanup-Gegenproben bleiben unbelegt. Eine getrennte private SQL2025-17.0.4075.5/Docker-CL170-Probe bestätigt die globale Agent-Historiengrenze sechs bei einer Grenze vier pro Job. Vier tatsächliche erfolgreiche Einstepläufe zweier eigener aktivierter Jobs in der Reihenfolge A B A B hinterlassen zwei vier sechs sechs Zeilen; das erste A-Paar verschwindet und vollständige Werte der beiden jüngeren Paare bleiben erhalten. Kein Job überschreitet vier erzeugte Zeilen. Sechzehn NONE/JSON-Consumer erhalten sechs vollständige Quellen und committable ON31TX1. AgentJobs erhält letzte erfolgreiche Steps ohne Problemsteps; Monitoring meldet ENABLED_JOB_WITHOUT_SCHEDULE/INFO für jeden vorhandenen Job ohne Consumerfehler. Vier Rollbacks beide eigenen Jobcleanups finale ursprüngliche OFF/-1/TX0/XactState0-Restauration und eigener äußerer Labcleanup bestehen. Beide Linuxschlüssel werden ausschließlich im neuen eigenen Container gesetzt aus der Konfigurationsdatei zurückgelesen und durch öffentlichen Lab-Restart angewandt. Dieser Umfang hat keinen vorausgehenden nativen Fehlversuch. Andere Limits Altersretention Parallelität andere Engines und innere Fehlercleanup-Gegenproben bleiben ungeprüft. Eine getrennte private SQL2025-17.0.4075.5/Docker-CL170-Probe bestätigt tatsächlichen Retryerfolg bei einem konfigurierten Retry mit Intervall einer Minute. Ein eigener TSQL-Step erzeugt nativ Retry2 Steperfolg1 und Joberfolg1. Mindestens 50 durch Einsekunden-Waits getrennte Pollzyklen erfassen den noch nicht abgeschlossenen Job bei vorhandener Retryzeile; die gemessene Spanne bis zum beobachteten Abschluss beträgt mindestens 50 Sekunden. Der erfolgreiche Step speichert retries_attempted0; AgentJobs erhält diesen Wert und schließt den älteren Retry im Problemfilter aus. Nach eigener Jobdeaktivierung meldet Monitoring JOB_STATE_INFORMATIONAL/INFO ohne Consumerfehler. Vier NONE/JSON-Consumer erhalten sechs vollständige Quellen und committable ON31TX1. Ein Rollback eigenes Jobcleanup finale ursprüngliche OFF/-1/TX0/XactState0-Restauration und eigener äußerer Labcleanup bestehen. Consumer während des laufenden Jobs andere Intervalle positive Retryerschöpfung Parallelität andere Engines und innere Fehlercleanup-Gegenproben bleiben ungeprüft. Eine getrennte private SQL2025-17.0.4075.5/Docker-CL170-Probe bestätigt tatsächliche Retryerschöpfung bei einem konfigurierten Retry mit Intervall einer Minute. Beide Versuche eines eigenen TSQL-Steps scheitern kontrolliert; drei native Historyzeilen zeigen Retry 2, Stepfailure 0 und Jobfailure 0. Mindestens 50 durch Einsekunden-Waits getrennte Pollzyklen erfassen den noch nicht abgeschlossenen Job bei vorhandener Retryzeile; die gemessene Spanne bis zum beobachteten Abschluss beträgt mindestens 50 Sekunden. Beide AgentJobs-Filter erhalten den letzten failed Step mit gespeichertem retries_attempted-Wert 1. Monitoring meldet für den weiterhin aktivierten Job LATEST_JOB_RUN_FAILED_IN_WINDOW/HIGH ohne Consumerfehler. Vier NONE-/JSON-Aufrufe erhalten sechs vollständige Quellen und committable ON31TX1. Ein Rollback, eigenes Jobcleanup, finale ursprüngliche OFF/-1/TX0/XactState0-Restauration und eigener äußerer Labcleanup bestehen. Consumer während des laufenden Jobs, weitere Intervalle, Parallelität, andere Engines und innere Fehlercleanup-Gegenproben bleiben ungeprüft. NULL, 0, positive und negative Ausgabelimits wurden gezielt korrigiert und die Consumerparität geprüft. Der Versuch einer optionalen Viewumbenennung scheiterte mit `15001` und schließt die Quellenabwesenheit nicht ab. Eine getrennte private SQL2025-17.0.4075.5/Docker-CL170-Kalenderprobe mit ON31 und je frischer committable TX1 erfasst zwölf Consumeraufrufe. Vier direkte OFF-Orakel außerhalb der Consumertransaktionen messen Fehler 242 für 20230229 und 20240230. AgentJobs meldet in vier Job-/Stepfällen ERROR_HANDLED/Partial mit Fehler 242 und gültigem JSON, macht aber jede Callertransaktion uncommittable. AgentMonitoring reicht in beiden ungültigen Jobfällen Fehler 3930 weiter; öffentliche Statusoutputs und JSON fehlen, XACT_STATE ist -1. Beide ungültigen Stepfälle liefern AVAILABLE_WITH_FINDING ohne Partial oder Fehler, ein Jobarray mit einer Zeile und XACT_STATE 1. Msdb erhält Counts eins oder zwei und committable TX1. Sechs vollständige Quellen, Transaktionsanzahl und ON31 bleiben nach jedem Consumer erhalten. Zwölf eigene Rollbacks, finale ursprüngliche OFF/-1/TX0/XactState0-Restauration und äußerer Labcleanup bestehen. Der private Lauf ist COMPLETED mit sechs uncommittable Calls und zwei entkommenen Fehlern; er ist kein funktionales PASS dieser Fehlerisolation. Die gezielte Korrektur der ON-Kalenderfehlerisolation bleibt offen. Andere ungültige Werte, Ausgabeformen, Engines und innere Fehlercleanup-Gegenproben bleiben ungeprüft. Die nachfolgende Produktkorrektur begrenzt XACT_ABORT OFF auf AgentJobs-Job-/Stepcollection und Monitoring-Jobcollection mit direkter Wiederherstellung der ursprünglichen Einstellung vor Ausgabe. Eine neue eigene SQL-2025/Docker-CL170-Gegenprobe besteht 24 NONE-/JSON-Kalenderconsumeraufrufe bei ON und OFF mit vier Fällen und je frischer TX1. Alle bleiben schreibfähig mit XACT_STATE 1; kein Fehler entkommt. AgentJobs erhält ERROR_HANDLED/Partial/242 und Jobs null oder eins bei leeren Steps. Monitoring liefert bei ungültigem Job AVAILABLE_LIMITED/Partial/242 mit Message und gültigem JSON; ungültiger Step erhält AVAILABLE_WITH_FINDING ohne Fehler. Msdb erhält Counts eins oder zwei. Sechs volle Quellen und Locktimeout 31 bleiben erhalten; 24 Rollbacks und finale ursprüngliche OFF/-1/TX0-Restauration bestehen. Die erweiterte TEST-0001-Fixture besteht zusätzlich 21 positive und zwölf ON-Kalenderconsumeraufrufe sowie zwölf eigene Kalenderrollbacks. Alle 13 impact-basierten Verträge und der äußere eigene Labcleanup bestehen. Die zuvor beobachtete ON-Kalenderfehlerisolation ist für diesen Scope korrigiert. Common167 bestätigt ohne eigene positive Job-/Schedulefixture ausschließlich die allgemeinen Verträge; der positive Block bleibt NOT_EXECUTED. Andere Lesefehler und ungültige Kalenderfälle in TABLE/RAW/CONSOLE bleiben ungeprüft; bereits uncommittable Callertransaktionen werden nicht repariert. Statusflags und OpenScope bleiben unverändert. Eine nachfolgende getrennte native SQL2025/Docker-CL170-Uhrzeitgegenprobe bestätigt den integrierten Fehlerisolationsfix für 236060 und 240000 bei gültigem Datum 20240229 als Job- und Stepoutcome. Je zwölf NONE-/JSON-Aufrufe bei ON und OFF mit frischer eigener TX1 bleiben schreibfähig; kein Fehler entkommt. Acht direkte OFF-Orakel außerhalb der Consumertransaktionen messen Fehler 242. AgentJobs liefert ERROR_HANDLED/Partial/242 mit Message und Jobs null oder eins bei leeren Steps. Monitoring liefert beim Jobfehler AVAILABLE_LIMITED/Partial/242 mit Message und leerem Jobarray; beim Stepfehler AVAILABLE_WITH_FINDING ohne Partial oder Fehler und eine gültige Jobzeile. Msdb erhält Counts eins oder zwei. Sechs vollständige Quellen TX1 und Locktimeout31 bleiben erhalten; 24 Rollbacks finale ursprüngliche OFF/-1/TX0/XactState0-Restauration und eigener äußerer Labcleanup bestehen. Die erweiterte TEST-0001-Fixture besteht 21 positive und 24 Kalender-/Uhrzeitconsumeraufrufe einschließlich 24 eigener Kalenderrollbacks. Core187 Smoke110 und Runtime122 bestehen. Produktcode öffentliche APIs Installer und Registry bleiben erhalten. 236060 kombiniert ungültige Minuten und Sekunden; isolierte Teilfeldgrenzen andere Uhrzeiten fehlerhafte Dauerformate andere Ausgabearten und tatsächliche Agentdauer bleiben ungeprüft. Statusflags und OpenScope bleiben unverändert. Eine getrennte native SQL2025/Docker-CL170-Dauerprobe führt einen eigenen TSQL-Job mit einem Step und drei Sekunden WAITFOR ohne Retry aus. Die zwei erfolgreichen nativen Historyzeilen speichern Stepdauer 3 und Jobdauer 4 Sekunden. Vier NONE-/JSON-Aufrufe bestätigen Msdb-Historycount zwei mit NULL-Zeitgrenzen; AgentJobs bestätigt Job- und Stepdauer sowie Startzeiten gegen native History und unabhängig gebildete Datumswerte. Der Problemfilter enthält den deaktivierten Job mit korrekter Dauer und Startzeit aber keinen Step. Monitoring bestätigt AVAILABLE_WITH_FINDING ohne Partial oder Fehler mit einer erfolgreichen JOB_STATE_INFORMATIONAL/INFO-Jobzeile und nativer Dauer und Startzeit. Sechs vollständige Quellen ON/31/TX1 ein eigener Rollback Jobcleanup und ursprüngliche OFF/-1/TX0/XactState0-Restauration bleiben erhalten. Core187 Smoke110 Runtime122 und eigener äußerer Labcleanup bestehen. Dies belegt einen kurzen tatsächlichen positiven Dauerwert; keine exakte WAITFOR-Timinggarantie keine Minuten-/Stundenübergänge langen Läufe oder Dauerparität anderer Ausgabearten. Statusflags und OpenScope bleiben unverändert. Eine weitere getrennte native SQL2025/Docker-CL170-Probe isoliert ungültige Minuten mit 6000 und Sekunden mit 60 bei gültigem Datum 20240229 jeweils als Job- und Stepoutcome. Je zwölf NONE-/JSON-Aufrufe bei ON und OFF bleiben schreibfähig; kein Fehler entkommt. Acht direkte OFF-Orakel außerhalb der Consumertransaktionen messen 242. AgentJobs liefert ERROR_HANDLED/Partial/242 mit Message und Jobs null oder eins bei leeren Steps. Monitoring liefert beim Jobfehler AVAILABLE_LIMITED/Partial/242 mit Message und leerem Jobarray; beim Stepfehler AVAILABLE_WITH_FINDING ohne Partial oder Fehler und eine Jobzeile. Msdb erhält Historycounts eins oder zwei. Sechs vollständige Quellen TX1 und Locktimeout31 bleiben erhalten; 24 Rollbacks finale ursprüngliche OFF/-1/TX0/XactState0-Restauration und eigener äußerer Labcleanup bestehen. TEST-0001 besteht nun 21 positive und 36 Kalender-/Uhrzeitaufrufe mit 36 eigenen Kalenderrollbacks. Core187 Smoke110 und Runtime122 bestehen. Produktcode öffentliche APIs Installer und Registry bleiben erhalten. Andere Werte ungültige Kalenderfälle in anderen Ausgabearten und weitere Dauergrenzen bleiben ungeprüft; Statusflags und OpenScope bleiben unverändert. Eine weitere native SQL2025/Docker-CL170-Probe führt einen eigenen TSQL-Job mit einem Step und 63 Sekunden WAITFOR ohne Retry aus. Die zwei erfolgreichen Historyzeilen speichern HHmmss-Rohwerte 103 für den Step und 103 für den Job. Der private Guard begrenzt beide Werte auf 100 bis 159; die unabhängige Referenz 60 + (Rohwert - 100) ergibt 63 beziehungsweise 63 Sekunden. Vier NONE-/JSON-Aufrufe bestätigen Msdb-Historycount zwei mit NULL-Zeitgrenzen. AgentJobs bestätigt Job- und Stepsekunden sowie unabhängig gebildete Startzeiten; der Problemfilter enthält den deaktivierten erfolgreichen Job aber keinen Step. Monitoring bestätigt AVAILABLE_WITH_FINDING ohne Partial oder Fehler mit JOB_STATE_INFORMATIONAL/INFO und erhält den nativen HHmmss-Jobrohwert in LatestRunDuration. Sechs vollständige Quellen und ON/31/TX1 bleiben erhalten. Ein eigener Rollback, Jobcleanup, ursprüngliche OFF/-1/TX0/XactState0-Restauration, Core187, Smoke110, Runtime122 und äußerer Labcleanup bestehen. Dies belegt die Minutenkomponente eins in einer tatsächlichen Probe; Stundenwerte, weitere Dauergrenzen, exakte WAITFOR-Timinggarantien und andere Ausgabearten bleiben offen. Statusflags und OpenScope bleiben unverändert. Eine getrennte native SQL2025/Docker-CL170-Probe injiziert acht gültige Dauergrenzen in je zwei erfolgreiche Historyzeilen eines eigenen deaktivierten Jobs mit einem definierten Step. Die HHmmss-Rohwerte 59 100 159 200 5959 10000 235959 240000 entsprechen den festen Sekundenliteralen 59 60 119 120 3599 3600 86399 86400. AgentJobs bestätigt Job- und Stepsekunden sowie den festen Startwert 2024-02-29T01:02:03; der Problemfilter enthält den deaktivierten erfolgreichen Job aber keinen Step. Monitoring erhält den Jobrohwert und liefert AVAILABLE_WITH_FINDING ohne Partial oder Fehler mit JOB_STATE_INFORMATIONAL/INFO. 240000 ist hier eine gültige Dauer von 24 Stunden und keine Uhrzeit. 32 NONE-/JSON-Aufrufe bestätigen Msdb-Historycount zwei mit NULL-Zeitgrenzen sowie vollständige sechs Quellen und ON/31/TX1. Acht Rollbacks, finale OFF/-1/TX0/XactState0-Restauration, Core187, Smoke110, Runtime122 und eigener äußerer Labcleanup bestehen. Die History ist injiziert und kein Job wird ausgeführt; tatsächliche Stundenläufe, fehlerhafte Dauerformate und andere Ausgabearten bleiben ungeprüft. Produktquellen, öffentliche Verträge, Fixture, Installer, Statusflags und OpenScope bleiben erhalten. Eine getrennte native SQL2025/Docker-CL170-Probe charakterisiert drei injizierte nicht kanonische positive run_duration-Werte 60 6000 236060 in je zwei erfolgreichen Historyzeilen eines eigenen deaktivierten Jobs mit einem definierten Step. Feste Referenzen bestätigen AgentJobs-Job- und Stepsekunden 60 3600 86460 und den Startwert 2024-02-29T01:02:03. Monitoring erhält die Jobrohwerte mit AVAILABLE_WITH_FINDING ohne Partial oder Fehler und JOB_STATE_INFORMATIONAL/INFO. Zwölf NONE-/JSON-Aufrufe bestätigen Msdb-Historycount zwei mit NULL-Zeitgrenzen sowie vollständige sechs Quellen und ON/31/TX1. Drei Rollbacks, finale OFF/-1/TX0/XactState0-Restauration, Core187, Smoke110, Runtime122 und eigener äußerer Labcleanup bestehen. Kein Job wird ausgeführt; dies charakterisiert bestehende Arithmetik ohne Formatvalidierung oder Normalisierung. Tatsächliche Dauer, allgemeine semantische Zulässigkeit und andere Ausgabearten bleiben unbelegt. Produktquellen, öffentliche Verträge, Fixture, Installer, Statusflags und OpenScope bleiben erhalten. Eine getrennte native SQL2025/Docker-CL170-Probe charakterisiert selektive Agenthistorypurges in vier frisch aufgebauten unabhängigen Phasen mit zwei eigenen deaktivierten Jobs und acht anfänglich injizierten erfolgreichen Historyzeilen. Gesamtcounts 8 6 4 2 entsprechen Zieljobcounts 6 4 2 0 bei zwei unveränderten Gegenprobezeilen. Die exakte Datumsgrenze erhält die gleichzeitigen Zielzeilen; die um eine Sekunde erhöhte Grenze entfernt sie. NULL-Datum entfernt ausschließlich die History des ausgewählten Jobs. Vollständige erwartete Restwerte und die anderen fünf Quellen bleiben über native Purges erhalten. AgentJobs behält beide Job- und Stepdefinitionen mit NULL-Historienfeldern für den geleerten Zieljob; der Problemfilter enthält zwei deaktivierte Jobs und keine Steps. Monitoring erhält zwei informational Jobs mit NULL-Historywerten nur für den Zieljob. 16 NONE-/JSON-Aufrufe erhalten sechs Quellen und ON/31/TX1. Vier Rollbacks, finale OFF/-1/TX0/XactState0-Restauration, Core187, Smoke110, Runtime122 und eigener äußerer Labcleanup bestehen. Keine Jobs werden ausgeführt; automatische Altersretention, allgemeine Purgegarantien und andere Ausgabearten bleiben unbelegt. Produktquellen, öffentliche Verträge, Fixture, Installer, Statusflags und OpenScope bleiben erhalten. Eine getrennte native SQL2025/Docker-CL170-Probe bestätigt datenbankselektive Backup-/Restorehistorypurges nach zwei tatsächlichen eigenen COPY_ONLY-Backups und Restores unter demselben jeweiligen eigenen Datenbanknamen mit kontrollierten Historienzeiten. Zwei Purges im msdb-Kontext liefern Backup- und Restorecounts 2 1 0; sämtliche vollständigen älteren Gegenprobewerte der acht Quellen bleiben nach dem ersten erhalten, nach dem zweiten sind alle acht leer. Neun NONE-/TABLE-/CONSOLE-Aufrufe bestätigen native Counts und Zeitgrenzen, vollständige Ausgabeparität, erhaltene acht Quellen und acht Katalogfelder je eigener Datenbank sowie ON/137/TX1. Drei Rollbacks erhalten die jeweilige Historienphase; finale OFF/-1/TX0/XactState0-Restauration, eigenes Datenbankcleanup, Core187, Smoke110, Runtime122 und äußerer Labcleanup bestehen. Automatische Altersretention, allgemeine Purgegarantien und andere Engines bleiben unbelegt. Produktquellen, öffentliche Verträge, Fixture, Installer, Statusflags und OpenScope bleiben erhalten. Eine getrennte native SQL2025/Docker-CL170-Probe bestätigt die exakte Altersgrenze von sp_delete_backuphistory nach zwei tatsächlichen eigenen COPY_ONLY-Backups und Restores mit kontrollierten Historienzeiten. Am Cutoff 2025-01-01T12:00:00 bleiben sämtliche Werte des gleich datierten Paars aus acht Quellen erhalten und das ältere Paar verschwindet; bei Cutoff plus einer Sekunde sind alle acht Quellen leer. Die native Rückgabe ist jeweils 0 im msdb-Kontext bei TX0; neun NONE-/TABLE-/CONSOLE-Aufrufe bestätigen Counts 2 1 0, native MIN/MAX, vollständige Ausgabeparität und erhaltene Quellen-, Katalog- und ON/137/TX1-Callerwerte. Drei Rollbacks erhalten die jeweilige Phase; finale OFF/-1/TX0/XactState0-Restauration, eigenes Datenbankcleanup, Core187, Smoke110, Runtime122 und äußerer Labcleanup bestehen. Backup-Start, Backup-Ende und Restorezeit verwenden denselben kontrollierten Zeitpunkt je Paar; getrennte Zeitregeln, automatische Altersretention, physische Backupdateien und andere Engines bleiben unbelegt. Produktquellen, öffentliche Verträge, Fixture, Installer, Statusflags und OpenScope bleiben erhalten. Eine getrennte native SQL2025/Docker-CL170-Probe bestätigt die exakte Mail-Altersgrenze für vier injizierte Statusfälle: unsent, sent, failed und retrying. Die vorher privat gelesene und vor sowie nach dem Lauf hashgebundene native Prozedur verwendet send_request_date < sent_before. Am Cutoff 2025-01-02T12:00:00 bleibt die gleich datierte Zielzeile erhalten; eine Sekunde später verschwindet sie. Zielcounts drei, eins und null sowie Gesamtcounts sechs, vier und drei bestehen. Jede Phase entspricht ihren vorab gebundenen vollständigen Sollwerten; die älteren Zeilen der anderen Status bleiben unverändert. Acht native Purges liefern jeweils 0. 36 NONE-/TABLE-/CONSOLE-Aufrufe bestätigen Counts, MIN/MAX und vollständige Ausgabeparität; Mailitems und ON/137/TX1 bleiben erhalten. Vier Rollbacks, finale OFF/-1/TX0/XactState0-Restauration, Core187, Smoke110, Runtime122 und eigener äußerer Labcleanup bestehen. Mail-XPs bleiben deaktiviert; Mailitems, Allitems und Attachments sind nach Rollback leer. Injizierte Statuswerte und gleiche kontrollierte request/sent-Zeitfelder belegen weder tatsächlichen Mailversand noch unabhängige sent_date-Regeln, automatische Altersretention, Logretention oder andere Engines. Produktquellen, öffentliche Verträge, Fixture, Installer, Statusflags und OpenScope bleiben erhalten. Eine getrennte native SQL2025/Docker-CL170-Probe bestätigt die Auswahl nach send_request_date für vier injizierte Statusfälle: unsent, sent, failed und retrying. Bewusst zeitlich widersprüchliche synthetische request/sent-Werte trennen die Wirkung beider Zeitfelder. Eine alte request-Zeit führt trotz zukünftiger sent-Zeit zur Entfernung; die request-Zeit am Stichtag 2025-01-02T12:00:00 bleibt trotz älterer sent-Zeit erhalten und verschwindet eine Sekunde später. Ein abschließender NULL-Datum-Purge entfernt nur die restlichen Zeilen des weiterhin gesetzten Zielstatus. Zielcounts drei, zwei, eins und null sowie Gesamtcounts sechs, fünf, vier und drei bestehen. Jede Phase entspricht ihren vor dem ersten Purge gebundenen vollständigen Sollwerten; die drei anderen Status bleiben unverändert. Zwölf native Purges liefern jeweils 0; 48 NONE-/TABLE-/CONSOLE-Aufrufe bestätigen Counts, MIN/MAX, vollständige Ausgabeparität und erhaltene Mailitems sowie ON/137/TX1. Vier Rollbacks, finale OFF/-1/TX0/XactState0-Restauration, Core187, Smoke110, Runtime122 und eigener äußerer Labcleanup bestehen. Mail-XPs bleiben deaktiviert; Mailitems, Allitems und Attachments sind nach Rollback leer. Die privat gelesene native Definition ist vor und nach dem Lauf hashgebunden. Die Probe belegt weder tatsächliche Mailzustandsentstehung noch Versand, automatische Altersretention, Logretention oder andere Engines. Produktquellen, öffentliche Verträge, Fixture, Installer, Statusflags und OpenScope bleiben erhalten. Eine getrennte native SQL2025/Docker-CL170-Probe bestätigt die Auswahl nach start_time und die strikte Gleichheitsgrenze der Maintenance-Elternhistorie. Zwei injizierte Eltern beginnen eine Sekunde vor beziehungsweise exakt am Stichtag 2025-01-02T12:00:00; beide end_time-Werte liegen hinter den beiden geprüften Grenzen. Die erste Bereinigung entfernt die ältere Startzeit, die Grenze eine Sekunde später auch die gleich datierte Zeile. Counts zwei, eins und null sowie zwei native Rückgaben 0 bestehen. Jede Phase entspricht ihren vor dem ersten Purge gebundenen vollständigen identitätsbezogenen Sollwerten. Zwei frühere Läufe scheiterten mit 55205; der diagnostische Lauf belegte NULL für die leeren Snapshots in Phase 3. Beide Fehlläufe bleiben erhalten; eine gezielte private Normalisierung auf [] korrigiert ausschließlich die Testannahme. Neun NONE-/TABLE-/CONSOLE-Aufrufe bestätigen native MIN/MAX-Werte, vollständige Ausgabeparität und erhaltene Elternwerte sowie ON/137/TX1. Ein Rollback, finale OFF/-1/TX0/XactState0-Restauration, Core187, Smoke110, Runtime122 und eigener äußerer Labcleanup bestehen. Die bereits vorhandene privat gelesene native Definition ist vor und nach dem neuen Lauf hashgebunden; ein weiterer Source-Capture-Lauf wurde nicht ausgeführt. Details, Plans und Subplans bleiben leer. Tatsächliche Maintenanceausführung, unabhängige Detaildatumssemantik, automatische Altersretention und andere Engines bleiben unbelegt. Produktquellen, öffentliche Verträge, Fixture, Installer, Statusflags und OpenScope bleiben erhalten. Eine getrennte native SQL2025/Docker-CL170-Probe bestätigt die Elternzeitselektion bei gekreuzten Detailzeiten. Zwei injizierte Eltern beginnen am 2025-01-02T11:59:59 beziehungsweise exakt am Stichtag 2025-01-02T12:00:00 und enden hinter beiden geprüften Grenzen. A besitzt zwei Details aus 2030 und B zwei aus 2000. Zwei native Purges am Stichtag und eine Sekunde später bestätigen Elterncounts zwei, eins und null sowie Detailcounts vier, zwei und null mit Rückgabe 0. Vollständige vorab identitätsgebundene Sollwerte, alle 13 festen Detailfelder, genaue Elternbindungen ohne verwaiste Details und neun NONE-/TABLE-/CONSOLE-Aufrufe mit TABLE-/CONSOLE-/JSON-Parität bestehen. Ältere Details bleiben mit B am exakten Stichtag erhalten; jüngere Details verschwinden mit A. Quell- und Callererhaltung mit ON/137/TX1, ein Rollback, finale OFF/-1/TX0/XactState0-Restauration, Core187, Smoke110, Runtime122 und eigener äußerer Labcleanup bestehen. Plans und Subplans bleiben leer; die vorhandene privat gelesene native Definition ist vor und nach dem Lauf hashgebunden. Die synthetisch gekreuzten Zeiten belegen ausschließlich diese kontrollierte Auswahl, keine tatsächliche Maintenanceausführung, reale zeitliche Konsistenz oder allgemeine Detaildatumsregel. Weitere Engines und automatische Altersretention bleiben unbelegt. Produktquellen, öffentliche Verträge, Fixture, Installer, Statusflags und OpenScope bleiben erhalten.
4. `OPS-007` ergänzt die verbleibende Hochlast-Evidenz. Die ressourcenpositive eigene zweite Session und der explizite Berechtigungsfehler sind auf SQL Server 2025 belegt. `OPS-009` besitzt einen nativen SQL-Server-2025-Nachweis für positives Inventar, exakte Begrenzung, eingeschränkte und selektive Sicht sowie Leerfall. Der native SQL-Server-2022-FULL_RELEASE-Lauf vom 26. Oktober 2026 ist im [OPS-009-Evidenznachweis](OPS009_Empty_Inventory_Runtime_Evidence_2026-09-19.md) gebunden; ein weiterer nativer Lauf folgt nur bei neuem konkretem Versionsrisiko oder erforderlicher Releasequalifikation.
5. `COLL-001` setzt die begonnene objektbezogene Härtung fort. Die fünf OPS-Objekte, die Child-JSON-Aggregation von `USP_CurrentOverview` und der TABLE-Zielvertrag bilden den ersten statisch sowie auf der garantierten Collation nativ abgesicherten Slice. `USP_IndexOperationalStats` und `USP_Partitions` besitzen zusätzlich SQL-Server-2025-Nachweise mit abweichender Server-/`tempdb`-Collation für gezielte JSON-/TABLE-Ausgabe, Frameworkcollation im Export und native Gegenprüfung. Die lokalen Object-/Index-Arbeitstabellen sind explizit collatiert; 13 weitere TABLE-Exports und der normale ObjectAnalysis-Orchestrator bestehen auf SQL Server 2025 mit abweichender Server-/`tempdb`- und Quelldatenbankcollation. Die dabei gefundenen dynamischen Steuerwert-, JOIN- und CASE-Grenzen sind gehärtet. `USP_PerformanceCounters` besteht zusätzlich den gezielten Snapshot- und Ein-Sekunden-Samplevertrag mit TABLE-/JSON-Ausgabe und exaktem Counterfilter auf abweichender Server-/`tempdb`-Collation. `USP_BufferPoolAnalysis` besitzt zusätzlich den Memory-TABLE-/JSON-Nachweis sowie die Standard- und Opt-in-Verteilungsprüfung auf derselben gemischten Collation-Kombination. `USP_InternalContentionAnalysis` besteht zusätzlich den kumulativen und zeitbezogenen Latch-TABLE-/JSON-Vertrag mit nativer Klassenidentität und Prüfung der tatsächlichen Messdauer auf dieser Collation-Kombination. `USP_ServerSecurityConfiguration` besitzt zusätzlich einen TABLE-/JSON-Nachweis mit nativer Konfigurationsparität auf derselben gemischten Collation-Kombination. `USP_ServerHealthAnalysis` besteht zusätzlich den Modulstatus-Export und die gezielte Security- sowie erweiterte Child-JSON-Auswahl auf dieser Kombination. `USP_WorkerPressureAnalysis` besitzt zusätzlich sieben collatierte TABLE-Exporte, TABLE-/JSON-Parität und einen kontrollierten Zweikandidatenfall mit einheitlichem Requestlimit auf dieser Kombination. `USP_AuditConfigurationAnalysis` besitzt zusätzlich fünf collatierte TABLE-Exporte, native Spezifikationsparität und einheitliche TABLE-/JSON-Filter- und Limitverträge auf dieser Kombination. `USP_DatabaseIntegrityAnalysis` besitzt zusätzlich einen collatierten TABLE-Export, native Metadatenparität, einheitliche Integritätslimits und eine Gegenprüfung des optionalen LIMITED-Seitenheaders auf dieser Kombination. `USP_DatabaseCapacityAnalysis` besitzt zusätzlich neun collatierte TABLE-Textspalten, native Dateimetadatenparität auf einer eigenen schreibgeschützten Quelle und einheitliche TABLE-/JSON-Problemfilter und Limits auf dieser Kombination. `USP_CriticalEngineEvents` besitzt zusätzlich fünf collatierte TABLE-Textspalten, native XE-Ereignisparität und den vorhandenen Limit- und XML-Opt-in-Vertrag auf dieser Kombination. `USP_DiagnosticFindings` besitzt zusätzlich zehn collatierte TABLE-Textspalten, kontrollierte Parent-Zuordnung und partielle Wiederverwendung sowie einheitliche Prioritätsfilter und Limits bei unveränderten Zählern auf dieser Kombination. `USP_DatabaseConfigurationAnalysis` besitzt zusätzlich sechs collatierte TABLE-Exporte mit nativer Options- und Konfigurationsparität, kontrollierter Profilzuordnung, vollständigem dynamischem Katalogaufruf und einheitlichen Settings-/Driftlimits auf dieser Kombination. `USP_ErrorLogAnalysis` besitzt zusätzlich 22 collatierte TABLE-Textspalten und native Unicode-Logparität sowie einheitliche Detaillimits und das partielle Quelllimit auf dieser Kombination. `USP_BackupChainAnalysis` besitzt zusätzlich fünf collatierte TABLE-Textspalten und native Full-/Differentialmetadaten sowie einen positiven Ohne-Prüfsumme-Zähler und einheitliche Summary-/Backuplimits auf dieser Kombination. `USP_AgentStatus` und `USP_InfrastructureAnalysis` besitzen zusätzlich sechs collatierte TABLE-Textspalten, native Jobinventarparität und vier Modulstatus- und Child-JSON-Auswahlverträge auf dieser Kombination. `USP_ResourceGovernorAnalysis` besitzt zusätzlich fünf collatierte TABLE-Exporte mit 16 Textspalten, nativer Konfigurations-, Pool- und Gruppenparität sowie den vorhandenen Ausgabegrenzen und TempDB-Governance ohne konfiguriertes Limit auf dieser Kombination. `USP_BackupRecovery` besitzt zusätzlich vier collatierte TABLE-Textspalten, native Full-/Differential-/Copy-only-Metadaten und einheitliche Freshnesslimits auf dieser Kombination. `USP_DataCaptureStatus` besitzt zusätzlich fünf collatierte TABLE-Textspalten, native CT-Datenbank- und Tabellenparität, einen parametrisierten CDC-Batch sowie einheitliche Datenbanklimits mit erhaltenen Auswahlwarnings auf dieser Kombination. `USP_TemporalAnalysis` besitzt zusätzlich zwölf collatierte TABLE-Textspalten, native eigene Temporal-Paare mit Perioden-, Retention- und führenden Indexmetadaten, vier unterschiedliche Quellcodes sowie gemeinsame Findingsfilter und Limits bei vollständigen Zählern und erhaltenen Auswahlwarnings auf gemischtem SQL Server 2025 mit Compatibility Level 150, 160 und 170. `USP_ServiceBrokerAnalysis` besitzt zusätzlich zehn collatierte TABLE-Textspalten, native eigene leere Queue-Schalter und Servicemetadaten, sieben unterschiedliche Quellcodes sowie gemeinsame Findingsfilter und Limits bei vollständigen Zählern und erhaltenen Auswahlwarnings auf gemischtem SQL Server 2025 mit expliziten Framework- und Source-Compatibility-Levels 150, 160 und 170. `USP_FullTextAnalysis` besitzt zusätzlich einen SQL-Server-2025-Nachweis für einen eigenen leeren Full-Text-Katalogscope, zehn collatierte TABLE-Textspalten, acht unabhängige Quellcodes, die Akzeptanz von NULL-/0-/positiven Mengenparametern, die Ablehnung ungültiger Parameter und erhaltene Auswahlwarnings mit expliziten Framework- und Source-Compatibility-Levels 150, 160 und 170. Nichtleere Full-Text-Findings, positive Filter-/Limitwirkung und gegatete Laufzeitquellen bleiben für diesen Slice unbelegt. `USP_DataCaptureDeepAnalysis` besitzt zusätzlich einen CT-Metadatennachweis aus zwei eigenen leeren Unicode-Tabellen mit nativen Identitäten und Versionen sowie elf unabhängigen Quellstatus. Common 159 besteht 18 TABLE-/JSON-Fälle mit zehn collatierten Textspalten und 13-Felder-Parität auf gemischtem SQL Server 2025 bei expliziten Framework- und beiden Source-Compatibility-Levels 150, 160 und 170. Ein synthetischer Wasserstand über der aktuellen Version erzeugt Future-WARNs; deaktiviertes Auto-Cleanup liefert INFO-Kontext. Positive exakte Unicode-/Case-Filter, NULL-/0-/positive Limits, vollständige Zähler, Auswahlwarnings und ungültige Mehrdatenbank-Consumerstatus sind geprüft. RAW und CONSOLE sind nur mit Status und JSON-Zeilenanzahl geprüft. Integration 184 besteht auf denselben drei Frameworklevels; deren Quelldatenbanklevel wurden nicht separat gesetzt. CT-Retentionverlust, positive CDC-/Replikationsquellen und zusätzliche Berechtigungsnachweise bleiben offen. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell. `USP_EncryptionAnalysis` besitzt zusätzlich einen Nachweis aus drei eigenen unverschlüsselten Unicode-Datenbanken mit nativen Identitäten und leerem DEK-/Full-Backup-/AE-/Ledger-Scope. Common 160 besteht 22 TABLE-/JSON-Fälle mit 26-Felder-Parität einschließlich NULL-Properties und elf collatierten Textfeldern auf gemischtem SQL Server 2025 bei getrennt bestätigten Framework- und drei Source-Compatibility-Levels 150, 160 und 170. Die erwartete Backupverschlüsselung ohne vorhandene Backupmetadaten erzeugt MEDIUM-Hinweise; Unicode-/Case-Auswahl, NULL-/0-/positive Limits, sichere Ablehnung negativer Limits und erhaltene Auswahlwarnings bei drei unabhängig erfolgreichen Quellenstatus sind geprüft. Vier RAW-/CONSOLE-Aufrufe prüfen ausschließlich Status und JSON-Zeilenanzahl. Integration 185 besteht bei denselben drei Frameworklevels und umfasst vier synthetische Zustände, zwei echte Procedure-Aufrufe für Backup-Erwartung und Berechtigungsfehler, einen AE-Definitionsvertrag und einen separaten Privacy-Check. Positive TDE-, Zertifikat-, Backupverschlüsselungs-, AE-, Ledger- und Restore-Evidenz bleibt unbelegt. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell. `USP_MaintenanceOperations` besitzt zusätzlich 57 explizit collatierte lokale Textfelder und vier gemeinsame Exporte mit unveränderten 15/19/9/7 Feldern. Common 161 besteht 24 TABLE-/JSON-Fälle auf gemischtem SQL Server 2025 bei getrennt bestätigtem Framework- und drei Source-Compatibility-Levels 170. Drei eigene Unicode-Datenbanken ohne Nutzdaten mit einmal ADR-OFF und zweimal ADR-ON liefern native PVS-Metadaten und kontrollierte Schwellwert-0-MEDIUM-Hinweise. Acht PVS-Felder werden exakt verglichen; die veränderliche PVS-Größe wird numerisch durch unabhängige Messungen vor und nach dem Aufruf begrenzt. Das leere Resumable-TABLE-Schema bestätigt 15 Felder und acht Textcollations. Vier unabhängige Quellenstatus einschließlich Jobs `NOT_REQUESTED` sowie NULL-/0-/positive Limits und Unicode-/Case-Auswahl mit erhaltener Auswahlpartialität und vollständiger Modulbewertung vor Ausgabelimits sind geprüft. Sechs RAW-/CONSOLE-Aufrufe prüfen ausschließlich Status und begleitende JSON-Zeilenanzahl; deren Warningzeilen werden nicht separat abgefangen. Integration 186 besteht auf CL170 und enthält drei synthetische Definitionsfälle sowie einen echten Berechtigungsaufruf und Read-only-Prüfungen. Positive Resumable-TABLE-Filter-/Limitwirkung, Wartungsrequests, Jobs, Hochlast und neue Nachweise für ältere Engines oder CL150/160 bleiben offen. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell. `USP_AvailabilityDeepAnalysis` besitzt zusätzlich 46 explizit collatierte lokale Textfelder und einen gemeinsamen Replikaexport mit elf Feldern und zehn Textcollations. Common 162 besteht zehn TABLE-/JSON-Fälle, vier RAW-/CONSOLE-Statusaufrufe und zwei zusätzliche JSON-Verbraucherfälle auf gemischtem SQL Server 2025 mit nativ deaktiviertem HADR und Framework-Compatibility-Level 170; es wurde keine Quelldatenbankfixture benötigt. Unabhängig geprüft sind das leere TABLE-Schema, acht JSON-Topkeys, acht Metafelder und sieben leere Arrays sowie die Akzeptanz von NULL-/0-/positiven Limits und die sichere Ablehnung ungültiger Limit-/Queue-/Lag-/Ausgabeparameter. RAW und CONSOLE sind nur über Status und begleitende JSON-Mengen geprüft; die leeren Mengen belegen keine positive Limitwirkung. Integration 176 besteht auf CL170 und umfasst einen echten AG-NONE-Aufruf sowie drei synthetische Interpretationsfunktionen. Positive AG-/Replika-Limit-/Queue-/Cluster-/Seeding-/Seitenreparatur-/Netzwerk-/Berechtigungsevidenz sowie neue Nachweise für ältere Engines oder CL150/160 bleiben offen. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell. `USP_ExternalRuntimeAnalysis` besitzt zusätzlich 96 explizit collatierte lokale Textfelder und einen gemeinsamen Findings-Export mit 13 Feldern, zehn Textcollations und unverändertem Findingordinal. Common 163 besteht 22 TABLE-/JSON-Fälle und vier RAW-/CONSOLE-Statusaufrufe mit begleitender JSON-Zeilenanzahl auf gemischtem SQL Server 2025 bei getrennt bestätigten Framework- und beiden case-unterschiedlichen Unicode-CI_AS-Source-Compatibility-Levels 150, 160 und 170. Vorhandene native R-/Python-Standardregistrierungen bei deaktivierten Scripts liefern die bestehenden Registrierungs-WARNs und Startfähigkeits-INFOs ohne neue Registrierung oder externe Ausführung. Positive Problemfilter, NULL-/0-/positive Limits, sichere negative Ablehnung, exakte Case-Auswahl, erhaltene Auswahlpartialität und vollständige Datenbankzähler sind mit 13-Felder-TABLE-/JSON-Parität einschließlich NULL-Property-Auslassung geprüft. Sechs globale und zwei Katalogquellcodes je Datenbank sind unabhängig gegen native Konfiguration, Services, Katalogidentitäten, Poolkonfiguration und Counteridentitäten, Typen und Quellanzahlen geprüft. Integration 198 besteht auf denselben Frameworklevels und prüft die bestehenden External-Runtime-/CLR-Read-only-, JSON-, TABLE-, Routing-, Capability- und Lock-Timeout-Verträge. RAW-/CONSOLE-Zeilen werden nicht separat abgefangen; veränderliche kumulative Werte sind kein atomarer Punktvergleich. Aktive Featurematrix, Startfähigkeit, positive Libraries und Requests, Sampling sowie weitere Berechtigungs- und optionale Pfade bleiben offen. Der Slice liefert keine neuen nativen älteren Engine-Nachweise. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell und `RUNTIME-001` behält `IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING`. `USP_ClrAnalysis` besitzt zusätzlich 106 explizit collatierte lokale Textfelder und einen gemeinsamen nicht identitätsgenerierten Findings-Export mit 13 Feldern und zehn Textcollations bei erhaltenen ursprünglichen Ordinalen. Common 164 besteht 24 TABLE-/JSON-Fälle und vier RAW-/CONSOLE-Statusaufrufe mit begleitender JSON-Findingsanzahl 0 auf gemischtem SQL Server 2025 bei getrennt bestätigten Framework- und beiden case-unterschiedlichen Unicode-CI_AS-Source-Compatibility-Levels 150/160/170. Das leere Findingsschema und die Parität sowie NULL-/0-/positive Limitakzeptanz, exakte und LIKE-Assemblyfilterakzeptanz, sichere Parameterablehnung, exakte Datenbankauswahl und späte Auswahlpartialität sind ohne Assemblyregistrierung, CLR-Ausführung oder Konfigurations-/Truständerung geprüft. Native Konfiguration und state/version-Properties, Memory-Clerk-Identitäten und Anzahlen sowie Counteridentitäten, Typen, Anzahlen und unabhängige Sample-0-Interpretation sind mit acht globalen und drei Katalogquellcodes je Datenbank beziehungsweise einem Katalogcode ohne Modulzuordnung gegengeprüft. Integration 198 besteht auf denselben Frameworklevels. Positive Assemblies und nichtleere Findingsfilter-/Limitwirkung, Ausführung, Trust, Sampling und weitere Berechtigungspfade bleiben offen. RAW-/CONSOLE-Zeilen werden nicht separat abgefangen; variable Speicher- und Counterwerte belegen keinen atomaren Punktvergleich. Der Slice liefert keine neuen nativen älteren Engine-Nachweise. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell und `RUNTIME-001` behält `IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING`. Die drei Orchestratoren `USP_PlanCacheAnalysis`, `USP_QueryStoreAnalysis` und `USP_ExtendedEventsAnalysis` besitzen zusätzlich je sechs explizit collatierte lokale Textfelder und einen frühen gemeinsamen Modulstatusexport mit fünf Feldern und drei Textcollations. Der Nachweis auf gemischtem SQL Server 2025 mit Framework-Compatibility-Level 170 bestätigt die Reparatur des bestehenden CONSOLE-Fehlers wegen fehlender Exportquelle; die ursprünglichen TABLE-Textcollations waren bereits korrekt. Common 165 besteht 24 TABLE-/JSON-Vertragsfälle, zwölf positive und neun leere SQL-CONSOLE-Captures sowie drei direkte CONSOLE-Aufrufe. Ein zusätzlicher unabhängiger SqlClient-Capture bestätigt alle 15 positiven sechsfeldrigen und neun leeren dreifeldrigen CONSOLE-Fälle mit nativen Feldnamen, Typen, Textgrößen, ursprünglichen Ordinalen, Modulnamen, Invocationstatus und Fehlerwerten. Die Plan-Cache-JSON-Parität des vorhandenen `modules`-Arrays und die erhaltenen Query-Store-/XE-Childobjekte, Metadaten und Warnungsprojektionen sind geprüft. Die Modulstatusmenge bleibt vollständig und unbegrenzt, unabhängig von NULL-/0-/positiven Childlimits. Drei RAW-Invalid-Leerscope-Aufrufe und zwölf TABLE-Zuordnungsablehnungen bestehen. Fünf vorhandene leere dreifeldrige RequestedName-Warningproben bleiben in den drei direkten Childpfaden sichtbar. Positive RAW-Modulzeilenparität, Plan-XML, Ereignisse, `ERROR_HANDLED`- und Berechtigungspfade sowie neue native ältere Engine- oder CL150/160-Nachweise bleiben für diesen Slice unbelegt. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell. `USP_FrameworkUsageFromQueryStore` besitzt zusätzlich 15 explizite lokale Textcollations und vier unveränderte TABLE-Schemas mit insgesamt 39 Feldern und 14 expliziten Textcollations. Gültige TABLE-Zuordnungen werden vor der fachlichen Parameterprüfung vorbereitet; ungültige Parameter projizieren vollständige Schemas mit `INVALID_PARAMETER`. Common 166 besteht 19 TABLE- und drei Verbraucherfälle mit TABLE-/JSON-/OUTPUT-Parität einschließlich 13 Metafeldern und NULL-Properties sowie vier frühe Mappingablehnungen auf gemischtem SQL Server 2025 bei Framework-Compatibility-Levels 150, 160 und 170. Acht native Gegenproben verwenden zwei eigene case-unterschiedliche Unicode-monitor-Procedures bei READ_ONLY Query Store und vergleichen die elf Nutzungsfelder mit unabhängig aggregierten Katalog- und Runtime-Stats-Daten. Mindestfilter, NULL-/0-/positive Limits und der erhaltene +1-Trunkierungsmarker `HasMoreRows` sind geprüft. Drei positive zwölffeldrige und drei leere dreifeldrige SQL-CONSOLE-Captures bestehen; positive Zeilen werden als ungeordnete Mengen verglichen. Ohne die vorbereitete Fixture führt der Vertrag die allgemeinen Fälle aus und meldet den positiven Block als `NOT_EXECUTED`. Die getrennte Ownership-Gegenprobe für Test 120 weist eine vorhandene Probe mit 51000 zurück und erhält deren native Objektidentität und Body. Kanonische Installation und Smoke bestehen. QueryStore120, Integration189/196/198 und Common124 bestehen nach eigenem Fixture-Cleanup und Wiederherstellung von Query Store READ_WRITE/AUTO bei denselben drei Frameworklevels. Positive RAW-Zeilenparität, `DENIED_PERMISSION`, `ERROR_HANDLED` und neue native ältere Engine-Nachweise bleiben unbelegt; dieser Fokusnachweis enthält keine Aussage über vollständige statische Gates. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell. `USP_AgentJobs` besitzt zusätzlich elf explizite Jobs-/Steps-Textcollations und behält den Jobs-TABLE-Vertrag mit 17 Feldern und sechs Textspalten. Gültige doppelte exakte Namen werden unter Frameworkcollation zusammengeführt; `MIN(ItemOrdinal)` erhält den ersten Listenordinal. Case-unterschiedliche Namen bleiben getrennt, ungültige Elemente liefern weiter `INVALID_PARAMETER`. Common 167 besteht elf allgemeine TABLE-/JSON-Fälle, zwei Verbraucher, sechs Preflightablehnungen, 13 native vollständige Jobs-/Steps-Gegenproben und drei positive 18-feldrige sowie drei leere dreifeldrige SQL-CONSOLE-Captures auf gemischtem SQL Server 2025 bei separat bestätigtem Framework- und msdb-Compatibility-Level 170. Zwei eigene case-unterschiedliche Unicode-Jobs mit Steps, Kategorie und aktiver Zukunftsschedule liefern die native Definitionsgegenprobe ohne Jobausführung, Activity-, History- oder Jobserverzeilen. NULL-/0-/positive Limits, exakte Case-/LIKE-Filter sowie gleiche und unterschiedlich bracket-quotierte Duplikate sind mit der positiven Fixture geprüft. Ungültige Listen einschließlich Duplikat plus ungültigem Element gehören zu den allgemeinen Leerscope-Fällen. Im Problemscope bleibt der deaktivierte Job sichtbar; sein Steps-Array bleibt ohne Historyoutcome leer, obwohl der native StepCount positiv ist. Ohne Fixture laufen die allgemeinen Fälle weiter und der positive Block meldet `NOT_EXECUTED`. Zehn unabhängige direkte SqlClient-RAW-Aufrufe bestätigen alle drei Schemas mit 6/17/10 Feldern, nativen Namen, Typen, Textgrößen, Jobs-/Steps-Nullability und voller JSON-Zeilenparität; acht Aufrufe besitzen nichtleere Jobs, sieben nichtleere Steps und zwei sind leer. Kanonische Installation und Smoke bestehen. Laufende Jobs, positive History-Outcomes und Meldungen, Regex, Berechtigungen, ältere native Engines und CL150/160 bleiben unbelegt; Infrastructure110, Integration189, Integration196, Integration198 und Common124 bestehen nach eigenem Fixture-Cleanup auf CL170. Infrastructure110 prüft Hilfe und Signaturen; es liefert keine zusätzliche positive AgentJobs-Evidenz. Vollständige statische Gates werden durch diesen Fokusnachweis nicht behauptet. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell. `USP_CheckFrameworkCapabilities` besitzt zusätzlich 14 explizite Textcollations in der Feature-Arbeitstabelle und einen gemeinsamen gefilterten Export mit unveränderten 27 Feldern und 15 Textspalten. Die ursprünglichen TABLE-Textcollations waren bereits korrekt; behoben ist die abweichende Filterwirkung von TABLE und CONSOLE. Das bestehende 0-/1-/NULL-Prädikat gilt für RAW, CONSOLE, TABLE und JSON gemeinsam. Summary, Gesamtstatus, Auswahlwarnings und Probeanzahl bleiben aus dem vollständigen Scope erhalten. Common 168 besteht elf allgemeine TABLE-/JSON-Fälle, zwei Verbraucher, sechs Preflightablehnungen, elf bedingte native vollständige Gegenproben, drei leere SQL-CONSOLE-Captures und drei direkte CONSOLE-Aufrufe auf gemischtem SQL Server 2025 bei separat bestätigten Framework- und beiden Source-Compatibility-Levels 170. Zwei eigene case-unterschiedliche Unicode-Datenbanken mit Apostroph im Namen und Query Store ON/OFF liefern die native Gegenprobe ohne Fixturemutation durch den Test. Native Zustands-, Wait-Capture- und Berechtigungswerte bestimmen die 27 Capabilityfelder einschließlich NULL-Werten; QS OFF bedeutet nicht, dass alle Features deaktiviert sind. Neun unabhängige RAW- und neun CONSOLE-SqlClient-Aufrufe bestätigen native Feldnamen, Typen, Textgrößen, Nullability und vollständige Capability-/JSON-Parität sowie die erhaltenen RAW-Metadaten mit sechs Feldern, Summary mit vier und Warnings mit drei Feldern. Sechs CONSOLE-Fälle liefern 28 Felder, drei leere Fälle drei Felder; zusätzliche leere Probegrids werden separat beobachtet und bleiben erhalten. Kanonische Installation und Smoke bestehen. Common121 und Integration189/196/198 bestehen nach guardgeprüftem Cleanup der beiden eigenen Datenbanken auf CL170. Positive Nachweise für eingeschränkte Berechtigungen, Gruppensperren, Fehlerpfade und Nutzungsstichproben sowie ältere native Engines und CL150/160 bleiben offen; vollständige statische Gates werden hier nicht behauptet. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); `COLL-001` bleibt partiell. Die drei Parser `TVF_ParseBlockingResource`, `TVF_ParseStatisticsIoText` und `TVF_ParseStatisticsTimeText` besitzen zusätzlich 17 explizite Textcollations in Rückgabe- und internen Arbeitstabellen. Die 14 Rückgabetexte waren bereits durch Frameworkvererbung korrekt collatiert; Parsinglogik und die Schemas mit 12/18/8 Feldern bleiben unverändert. Common 169 besteht auf gemischtem SQL Server 2025 bei Framework-Compatibility-Level 170 insgesamt 53 vollständige synthetische Literalaufrufe mit 31 Blocking-, elf IO- und elf TIME-Fällen. Unabhängig geprüft sind 51 vollständige erwartete Zeilen mit NULL-Werten und exakten Textbytes sowie 38 Metadatenfelder und 14 Textcollations. Ein unabhängiger SqlClient bestätigt 45 Aufrufe gegen die ursprüngliche Baseline mit vollständiger nativer und JSON-Parität einschließlich NULLs, 42 Zeilen und sechs leeren IO-/TIME-Aufrufen. CurrentState110/133 und PlanCache120/128 sowie die Standalone-Installerverträge 192/193 bestehen; native Consumer- und Standalone-Läufe verwenden CL170. OPS-005 und PLAN-001 sind kanonisch synchronisiert; PLAN-001 enthält weiterhin nur IO und TIME. Dieser Nachweis betrifft ausschließlich synthetische Parsertexte. Echte Blockingressourcenauflösung, nativ erfasste STATISTICS-Workloads, ältere native Engines und CL150/160 bleiben für den Slice unbelegt; vollständige statische Gates werden hier nicht behauptet. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); `COLL-001` bleibt partiell. `USP_StatisticsDistributionAnalysis` verwendet zusätzlich einen gemeinsamen Findings-Export mit 14 Feldern und elf expliziten Frameworktextcollations. Die sechs ursprünglichen lokalen Tabellen waren bereits explizit collatiert. TABLE und CONSOLE beachten nun das bestehende Zeilenlimit; NULL und 0 bleiben unbegrenzt. Negative Limits liefern INVALID_PARAMETER ohne TOP-Ausnahme. Vollständige Statusbewertung, Zähler und Datenbankstatus bleiben erhalten. FindingOrdinal übernimmt die ursprünglichen Werte; das native RAW-/positive-CONSOLE-Merkmal IsIdentity wechselt ausdrücklich auf False, während TABLE bereits ohne Identity war. Common 170 besteht auf gemischtem SQL Server 2025 bei separat gemessenen Framework- und Source-Compatibility-Levels 170 elf allgemeine TABLE-Fälle, zehn native Gegenproben, zwei negative Consumer, fünf Preflightfälle, drei leere CONSOLE-Captures und drei direkte positive CONSOLE-Statusaufrufe. Alle 32 Verteilungsfelder und vollständige Findingswerte werden unabhängig geprüft. Zwei eigene Unicodeobjekte mit eingefrorenen FULLSCAN-Statistiken liefern die positive Fixture ohne Mutation durch den Test. Acht unabhängige RAW-/CONSOLE-Clientaufrufe bestätigen native Metadaten mit der dokumentierten Identity-Ausnahme, vollständige JSON-Parität einschließlich NULLs sowie die fünf RAW-Schemas mit 9/9/32/13/14 und die positive CONSOLE mit 15 Feldern. Integration175 besteht acht Statistikfälle; zwei direkte ObjectAnalysis-Child-Aufrufe und ObjectIndex110/Integration178/196 bestehen ebenfalls. Kanonische Installation, Smoke, identitätsgeprüftes Fixture-Cleanup und der anschließende Common170-Lauf ohne positive Fixture bestehen. Eine gemischte vorhandene/fehlende Datenbankauswahl enthält weiterhin nur den ausgewählten Child-Scope; zusätzliche Missing-Warnings und Partialität werden nicht behauptet. Gemischte Histogrammpermission, Timeout-, HIGH-/LOW-Finding- und Partitionsvariationsnachweise sowie ältere native Engines und CL150/160 bleiben unbelegt; vollständige statische Gates werden hier nicht behauptet. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); `COLL-001` bleibt partiell. Weitere Frameworkdateien und Verbrauchervarianten bleiben offen.


Die drei Showplan-Referenz-TVFs besitzen zusätzlich 30 explizite Textcollations. Ihre 53 Rückgabefelder und 23 Textcollations waren bereits durch Frameworkvererbung korrekt. Sechs gezielte RelOp-Rootschritte in `TVF_ExecutionPlanColumnReferences` reparieren den bestehenden leeren Rollenpfad bei unveränderten Schemas, Statementfiltern und Ordinalen. Common171 besteht auf gemischtem SQL Server 2025 mit CL170 51 synthetische Vollzeilenfälle mit 70 Literalzeilen und vollständiger Metadaten-/Multisetprüfung. Ein unabhängiger Client bestätigt 51 gepaarte native/JSON-Fälle mit je 102 TVF-Ausführungen für Baseline und Candidate: 27 Object- und 19 Statisticszeilen bleiben exakt, Column wechselt von null auf 24 unabhängige Sollzeilen. Eine eigene RELEVANT-Consumerfixture bestätigt genau eine Seek-Statistik statt der vorher leeren Auswahl, acht native Properties und die eigene ObjectId bei erhaltenem AVAILABLE-/nichtpartiellem Status; sie belegt nicht alle 26 Snapshotfelder. PlanCache120/123/127/128/129 und Integration192 bestehen. Ein diagnostischer Integration193-Lauf besteht nach zwei getrennten Harness-/Gatefehlern mit unverändertem Gate; die Ursache des früheren XE-Checksum-Fehlers 53633 bleibt unbekannt. OPS-005 und PLAN-001 sind kanonisch synchronisiert, eigene Fixtures und Labressourcen entfernt. Weitere DML-Varianten, isolierte case-only Sortierungen, echte Workloads, Metadaten-Berechtigungsfehler, ältere native Engines und CL150/160 bleiben unbelegt. Die vollständige statische Suite bestand am damaligen Teststand alle 75 Prüfungen mit Exitcode 0. Der erste PR242-CI-Lauf scheiterte danach in Impactstufe 3/14 an Common171 mit Msg1934 wegen QUOTED_IDENTIFIER; Standalone193 wurde nicht erreicht. Ein expliziter QI-ON-Einstiegsbatch repariert ausschließlich den Test. Ein frisches eigenes Mixed-SQL2025-Lab auf CL170 bestätigt Installation, Smoke und den korrigierten Test; ein unabhängiger QI-OFF-Aufruf reproduziert den ursprünglichen Fehler und bestätigt anschließend 51/70/53/23 sowie SESSIONPROPERTY=1. Das Reparaturlab und sein temporärer Secretwert sind entfernt. Der historische 75-PASS ist vom neuen Vollgate getrennt: Die erneute vollständige statische Suite bestand am QI-korrigierten stabilen Stand alle 75 Prüfungen mit Exitcode 0. Abschließende begrenzte Dokumentations-, Schreibstil- und Privacyprüfungen folgen nach diesem Gatezusatz. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); `COLL-001` bleibt partiell und `RUNTIME-001` sowie bestehende Maturityflags unverändert.

USP_QueryStoreForcedPlans besitzt zusätzlich einen gemeinsamen global begrenzten Export mit unveränderten 32 Feldern und zwölf expliziten Frameworktextcollations. Sieben gepaarte native Baseline-/Candidate-Aufrufe und ein unabhängiges 32-Feld-Orakel bestätigen auf gemischtem SQL Server 2025 mit getrennt gemessenen Framework-/beiden Source-CL170 die TABLE-/CONSOLE-Limitkorrektur und erhaltene RAW-/JSON-Werte. Common172 besteht zwölf allgemeine und 14 native TABLE-/JSON-Fälle sowie Verbraucher-, Mapping- und CONSOLE-Prüfungen; ohne eigene Fixture bleibt der positive Block NOT_EXECUTED. Ein direkter QueryStoreAnalysis-Consumer und zehn impact-basierte Verträge bestehen. Die eigene Fixture und das Lab sind entfernt. Falsche N''-Leerannahme und privater QI-OFF-Individualinstaller wurden im Harness korrigiert; die bestehende exakte Cross-DB-Referenzliste scheitert weiterhin mit 208 und bleibt offen. Der positive Referenz-LIKE-Fall besteht. OPS-005 ist kanonisch synchronisiert; PLAN-001 benötigte ausschließlich eine kanonische EOL-Korrektur. Die erneute vollständige statische Suite besteht alle 75 Prüfungen mit Exitcode 0; die anschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen ebenfalls. Positive Forcingfehler, QS_OFF, Berechtigungen, Timeout, ältere native Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt partiell und bestehende Statusflags unverändert.

USP_QueryStorePlanChanges besitzt einen gemeinsamen Queryexport mit unveränderten 22 Feldern und sieben Textcollations sowie 28 Planfeldern mit neun Textcollations. Die ursprünglichen Collations waren bereits korrekt. Eine eindeutige object_id-Qualifikation behebt zuvor den nativen Fehler 209; die positive Ausgabegegenprobe verwendet ausdrücklich eine separat qualifizierte private Vorstufe. Neun gepaarte Clientfälle bestätigen die TABLE-/CONSOLE-Limitkorrektur, erhaltene RAW-/JSON-Werte, vollständige Planzuordnung und alle 50 nativen Feldfacetten auf gemischtem SQL Server 2025 mit getrennt gemessenen Framework-/beiden Source-CL170. Common173 besteht elf allgemeine und 16 native Fälle einschließlich PlanCount 1 bei zwei Detailplänen im Zeitfilter; ohne Fixture bleibt der positive Block NOT_EXECUTED. Zwei TABLE-Teilmappings, drei vollständige positive CONSOLE-Mengen, ein direkter QueryStoreAnalysis-Consumer und zehn impact-basierte Verträge bestehen. Eigene Quellen, Lab und Secretwert sind entfernt. OPS-005 ist kanonisch synchronisiert, PLAN-001 bleibt semantisch unverändert. Alle 75 statischen Prüfungen und die anschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen. Sortties, Compile-Rundungsgrenzen, QS_OFF, Berechtigungen, Timeout, exakte Referenzlisten sowie ältere native Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

USP_QueryStoreHints besitzt einen gemeinsamen Export mit unveränderten 22 Feldern und neun bereits korrekten Textcollations. Dreizehn gepaarte Clientfälle mit unabhängigem nativem 22-Feld-Orakel bestätigen auf gemischtem SQL Server 2025 mit getrennt gemessenen Framework-/beiden Source-CL170 die TABLE-/CONSOLE-Limitkorrektur, erhaltene RAW-/JSON-Werte und sämtliche Feldfacetten. Zwei eigene gesunde Hints je Quelle erzeugen tatsächlich datenbankübergreifend gleiche Sortwerte; innerhalb eines Aufrufs bleibt die vollständige Consumer-/JSON-Menge gleich, getrennte Aufrufe müssen keine identische Auswahl liefern. Der erste Common174-Lauf scheitert am negativen Textlimit; eine isolierte Originalgegenprobe bestätigt den bestehenden Fehler 51021 trotz INVALID_PARAMETER. Ein minimaler Projektionsguard behebt ihn, danach bestehen alle dreizehn Clientfälle erneut und Common174 besteht elf allgemeine sowie 15 native Fälle einschließlich gesunder Fehlerfilter-1-/NULL-Leermengen. Drei vollständige positive CONSOLE-Mengen, ein direkter QueryStoreAnalysis-Hints-Consumer und neun impact-basierte Verträge bestehen. Ohne Fixture bleibt der positive Block NOT_EXECUTED. Eigene Quellen, Lab und Secretwert sind entfernt. OPS-005 ist kanonisch synchronisiert; PLAN-001 und OPS-005-Update bleiben semantisch unverändert. Alle 75 statischen Prüfungen und die anschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen. Positive Hintfehler, Fehlerpriorisierung, QS_OFF, Berechtigungen, Timeout, ältere native Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

USP_QueryStoreRegressions besitzt einen gemeinsamen Export mit unveränderten 25 Feldern und sieben bereits korrekten Textcollations. Zwei tatsächlich getrennte, direkt aufeinanderfolgende native Ein-Minuten-Intervalle erfassen je Quelle 2→8 und 2→4 Ausführungen. Zweiundzwanzig gepaarte Clientfälle mit unabhängigem nativem 25-Feld-Orakel bestätigen auf gemischtem SQL Server 2025 mit getrennt gemessenen Framework-/beiden Source-CL170 die TABLE-/CONSOLE-Limitkorrektur, erhaltene RAW-/JSON-Werte, sämtliche Feldfacetten, Ranggleichheiten und Mindestfiltergrenzen. Eine Originalgegenprobe bestätigt beim negativen Textlimit Fehler 51021; ein minimaler Projektionsguard liefert anschließend kontrolliert INVALID_PARAMETER. Common175 besteht 14 allgemeine und 20 native Fälle sowie Mapping- und Consumerprüfungen; ohne Fixture bleibt der positive Block NOT_EXECUTED. Drei vollständige positive CONSOLE-Mengen bestehen. Der Parent verwendet DURATION_AVG; seine native Gegenprobe bestätigt wegen sinkender Dauerwerte korrekt eine leere Menge und belegt keine positive Parent-Regression. Zehn impact-basierte Verträge bestehen. Eigene Quellen, Lab und Secretwert sind entfernt. Ein zunächst ungeeigneter Ein-Intervall-Fixtureaufbau wird ausschließlich privat zurückgesetzt und vor den gepaarten Produktfällen mit gemessener Wartezeit korrigiert. OPS-005 ist kanonisch synchronisiert; PLAN-001 und OPS-005-Update bleiben semantisch unverändert. Alle 75 statischen Prüfungen und die anschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen. Positive gewichtete Metriken, allgemeine Float-/Rundungsgrenzen, QS_OFF, Berechtigungen, Timeout, exakte Referenzlisten, ältere native Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

USP_QueryStoreWaitStats besitzt einen gemeinsamen Export mit unveränderten 25 Feldern und acht bereits korrekten Textcollations. Vier native Lock-/Regular-Gruppen aus einem eingefrorenen Intervall erlauben positive Vollfeldprüfungen. Das Original scheitert auf CI-Quellen mit Fehler 468 im numerischen Kategorienarm; dessen expliziter Vergleich wird gezielt korrigiert, während die native Deskriptorsemantik erhalten bleibt. Ein gesonderter positiver Originalvergleich mit vorübergehend angeglichenen eigenen Quellcollations belegt die TABLE-/CONSOLE-Limitabweichung; die Quellen werden anschließend unverändert auf CI zurückgestellt. Vierundzwanzig gepaarte Vergleichsfälle bestätigen alle 25 Felder, Schematypen, Kategorien-, Unicode-, Case- und Intervallverträge. Fehler 51021 beim negativen Textlimit wird mit einem minimalen Projektionsguard kontrolliert zu INVALID_PARAMETER. Common176 besteht 14 allgemeine und 21 native Fälle; drei vollständige positive CONSOLE-Mengen und zwei positive Parent-Aufrufe mit Child-Parität und Ordinal 3 bestehen. Ohne Fixture bleibt der native Block NOT_EXECUTED. Neun impact-basierte Verträge und alle 75 statischen Prüfungen bestehen auf dem stabilen Stand. Eigene Quellen, Lab und Secretwert sind entfernt. Eine fehlende Optionsprojektion im ersten Commonlauf wird ausschließlich im Test korrigiert und neu geprüft. OPS-005 ist kanonisch synchronisiert; sein Update und PLAN-001 bleiben semantisch unverändert. Die anschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen. Mehrere gespeicherte Durchschnittsrecords, allgemeine Rundungsgrenzen, weitere Kategorien, QS_OFF, Berechtigungen, Timeout, exakte Referenzlisten, Regex, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

USP_QueryStoreRuntimeStats besitzt einen gemeinsamen Export mit unveränderten 40 Feldern, zehn bereits korrekten Textcollations und drei NOT-NULL-Spalten. Native Originalgegenproben bestätigen Fehler 209, nach isolierter Qualifikation 207 und nach Sortaliasreparatur 169 für LAST_EXECUTION; gezielte Projektionen und das Weglassen des dort redundanten lokalen Sortschlüssels beheben diese Fehler. Eine separat markierte private positive Vorstufe erlaubt den Exportvergleich. Vierunddreißig gepaarte Fälle bestätigen alle 40 Felder und Schemafacetten, alle neun Ranks, gewichtete Metriken aus zwei tatsächlichen Intervallen mit 2→8-/2→4-Ausführungen, Unicode, ganze Randintervalle und semantisches Plan-XML. Ein privater nativer numeric-Konvertierungsbeobachter und XML-Kanonisierung korrigieren zwei Clientvergleichsannahmen ohne Produktänderung. Common177 besteht 14 allgemeine und 24 native Fälle; drei vollständige positive CONSOLE-Mengen und zwei positive Parent-Aufrufe mit Child-Parität und Ordinal 2 bestehen. Ohne Fixture bleibt der native Block NOT_EXECUTED. Zehn impact-basierte Verträge bestehen nach explizitem QI-/ANSI-ON-Einstieg im privaten Harness; der erste QI-OFF-Lauf scheitert im unveränderten Common165-XE-Teil mit 3930. Alle 75 statischen Prüfungen bestehen am stabilen Stand; ein feldbezogener Static1023-Guard samt Mutation behebt vorher einen Reviewbefund. Eigene Quellen, Lab und Secretwert sind entfernt. OPS-005 ist kanonisch synchronisiert; sein Update und PLAN-001 bleiben semantisch unverändert. Die anschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen am Lieferstand. Mehrere Records je Intervall, weitere Ausführungstypen, allgemeine Rundungsgrenzen, lokale N+1-Ties, positive Memory-/TempDB-/Logwerte, ungültiges XML, QS_OFF, Berechtigungen, Timeout, exakte Referenzlisten, Regex, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

USP_QueryStoreStatus besitzt bereits eine gemeinsame frühe Ergebnistabelle mit 27 Feldern, sieben expliziten Textcollations und ausschließlich DatabaseName als NOT-NULL-Spalte. Das vollständig geprüfte Original und 22 gepaarte native Vollfeld-/Schema-/Consumerfälle auf drei eigenen leeren CI-Quellen mit gemessenem READ_WRITE, OFF und explizitem READ_ONLY belegen keinen Produktfehler; Source, Signatur, SchemaVersion und Installer bleiben normalisiert unverändert. Der Scope enthält daher Common178, einen feldbezogenen Static1024-Guard samt 23 echten Mutationen, die sieben vorhandenen Inventarcollations und gezielte Doku-Korrekturen zu Defaultscope, Ausgabeformen, Fenster- und Limitangaben. Common178 besteht elf allgemeine und 13 native Fälle, sechs Mappingablehnungen und vollständige positive CONSOLE-Clientparität für 3/1/1 Zeilen; ohne Fixture bleibt der native Block NOT_EXECUTED. Ein erster Sollauswahlfehler und ein Reviewbefund zu doppelten JSON-Hauptschlüsseln werden ausschließlich im Test korrigiert. Sechs zusätzliche Consumerfälle und zwei positive Status-only-Parentaufrufe mit Child-Parität und Ordinal 1 bestehen; Parentlimits begrenzen den Statuschild nicht. Der einzelne impact-basierte Vertrag besteht auf CL170. Ein erster Adapter-Bytevergleich scheitert nach Windowscheckout; kanonische Neugenerierung ohne versionierten Installer-Diff behebt die lokale Repräsentation. Alle 75 statischen Prüfungen bestehen am stabilen Stand. Eigene Quellen, Lab und Secretwert sind entfernt. Die anschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen am Lieferstand. Unerwartetes READ_ONLY, ERROR, positive Speicherwarnschwellen, Berechtigungen, Timeout, Regex, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

## Exit-Kriterien

Die Welle ist abgeschlossen, wenn:

- vorhandener und offener Produktumfang in den kanonischen Statusquellen übereinstimmen;
- die vorgesehenen positiven, leeren, eingeschränkten und fehlerisolierten Fälle tatsächlich ausgeführt wurden;
- betroffene Procedure-Seiten den dokumentierten Reviewstatus inhaltlich erfüllen;
- keine allgemeine Lab-Verantwortung in dieses Repository zurückverlagert wurde;
- die impact-basierten statischen und funktionalen Gates erfolgreich sind.

Die SQL-Server-2025-Erweiterungen `WI-0002` bis `WI-0007` beginnen erst, wenn der Reifeabschluss einschließlich `COLL-001` keine ungeklärte gemeinsame Vertragsabweichung hinterlässt.

USP_IntelligentQueryProcessingAnalysis besitzt zusätzlich einen sechsfeldrigen gemeinsamen Signalexport mit drei expliziten Textcollations, fünf NOT-NULL-Feldern und ohne Identity. Das Original belegt Fehler 4191 in zwei leeren Unicode-CI-Quellen, unterschiedliche Signalmengen bei TABLE/CONSOLE gegenüber RAW/JSON und Fehler 127 bei negativen Limits. Sechs explizite Zustandsvergleiche, ein einmaliges spätes Signal-TOP und sichere interne Negative-Limits beheben diese Grenzen ohne Änderung von API, SchemaVersion oder Versionsgates. Achtundzwanzig Finalfälle prüfen alle 28 Fachwerte und Schemafacetten, vier Consumer, sechs JSON-Schlüssel mit fünf Metafeldern, Warnungen und Default-Allscope. Common179 besteht 14 allgemeine und 18 native Fälle sowie 3 Consumer, 6 Mappingablehnungen, 4 leere CONSOLE-Captures und vollständige positive CONSOLE-Clientparität für 1/2/6 Zeilen; ohne Fixture bleibt der native Block NOT_EXECUTED. Dreizehn Zusatzfälle und zwei IQP-only-Parentaufrufe mit Child-Parität und tatsächlichem Befundstatus auf Ordinal 9 bestehen. Die 14 impact-basierten Verträge bestehen auf CL170; alle 75 statischen Prüfungen und 58 echte Static1025-Mutationen bestehen am stabilen funktionalen Stand. Die eigenen Quellen bleiben nach dem Impactlauf nativ unverändert; im Framework ändern sich aggregierte Feedback-/Empfehlungszähler, ohne daraus Wirksamkeit abzuleiten. Ein Reviewbefund präzisiert ausschließlich die dokumentierte Auswahlordnung. Eigene Quellen, Lab und Secretwert sind entfernt. OPS-005 ist kanonisch synchronisiert; sein Update und PLAN bleiben normalisiert unverändert. Die abschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen am Lieferstand. Aktive IQP-Wirkung, positive Quellvarianten/Feedback, unerwartetes READ_ONLY, Berechtigungen, Timeout, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

USP_QueryStoreReplicaAnalysis besitzt bereits sieben gemeinsame Resultsets mit 105 Feldern und 45 expliziten Textcollations. Native Originalfälle belegen falsche HasMore-Flags bei negativen Limits, ungefüllte TABLE-Schemas bei ungültigen Parametern und Fehler 51010 durch wiederverwendete Ziele bei Teilmappings. Internes Limit 0, frühes TABLE-Prepare und sieben skalare Zielzuweisungen korrigieren diese Ausgabegrenzen ohne ABI-, Rollen- oder Gateänderung. Achtundzwanzig gepaarte Fälle erhalten alle 105 Schemafacetten, native 15-/21-Feld-Katalog-/Runtimewerte, acht JSON-Hauptschlüssel und 13 Metafelder. Elf positive und elf negative Teilmappings bestätigen angeforderte Schemas sowie unveränderte nicht zugeordnete Sentinelzeilen. Common180 besteht 14 allgemeine und 18 native Fälle, neun allgemeine und neun native selektive Maps, fünf Consumer, sechs Preflights und drei Invalid-CONSOLE-Captures; der unabhängige Client bestätigt drei positive CONSOLE-Aufrufe mit 18 Feldern. Zwei Collationgrenzen und eine Duplikatannahme werden ausschließlich im Test beziehungsweise privaten Prüfer korrigiert. Zwei positive Parentaufrufe besitzen Child-Parität und AVAILABLE auf Ordinal 8. Neun impact-basierte Verträge bestehen auf CL170; alle 75 statischen Prüfungen und 448 echte Static1030-Mutationen bestehen am stabilen funktionalen Stand. Die 13 nativen Quellgrids bleiben vor und nach den Prüfungen exakt gleich. Nach identitätsgeprüftem Fixture-Cleanup bestehen die allgemeinen Fälle; positive Fälle melden NOT_EXECUTED. Eigene Quellen, Lab und Secretwert sind entfernt. OPS-005 ist kanonisch synchronisiert; sein Update, PLAN und TVF005 bleiben normalisiert unverändert. Die anschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen am Lieferstand. Positive Wait-/Forcing-Limitwirkung, echte AG-/Geo-/Secondary-/Failover-Evidenz, fehlende Rollenmetadaten, weitere Zustände, Berechtigungen, Timeout, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

USP_QueryHashAnalysis besitzt bereits einen gemeinsamen Export mit 20 Feldern, zehn NOT-NULL-Feldern, einer expliziten Textcollation und ohne Identity. Native Originalgegenproben belegen falsche TOP-Rangmengen und Fehler 51021 bei negativen Textlimits. ORDER BY rn und ein einzelner Projektionsguard beheben diese Grenzen ohne ABI-, Versions-, Gate- oder Aggregationsänderung. Je dreißig synthetische und native Original-/Finalfälle bestätigen sämtliche 20 Werte und Schemafacetten, sieben Ressourcenränge, vier Consumer, drei JSON-Hauptschlüssel und neun Metafelder. Vierzig Zusatzfälle, acht Unicode-Grenzfälle und acht Gatefälle bestätigen exakte Hashauswahl, Mindestfilter, sechs Mappingablehnungen, kontrollierten fehlenden Snapshot208 und zwei tatsächliche Parentpfade auf Ordinal 2 mit Child-Parität. Zwei private Harnessfehler werden ohne Produktänderung korrigiert. Common181 besteht 27 allgemeine und 20 native Fälle, drei Consumer, sechs Preflights und drei leere CONSOLE-Captures; ohne Fixture bleibt der native Block NOT_EXECUTED. Eine eng begrenzte Static950-Ausnahme für diesen kontrollierten Test-Snapshot behebt einen vollständigen Suitebefund und besteht neun Ownershipmutationen sowie acht Kollisionsfälle; gewöhnliche Namenskollisionen bleiben Fehler. Acht impact-basierte Testdateien bestehen auf CL170; alle 75 statischen Prüfungen und 173 echte Static1036-Mutationen bestehen am stabilen funktionalen Stand. Die 90 nativen Cachefelder der drei eigenen Quellenzeilen, Datenbankidentität, Optionen und vier Tabellenwerte bleiben nach den Prüfungen exakt gleich. Eigene Quelle, Lab und Secretwert sind entfernt. OPS-005 ist kanonisch synchronisiert; sein Update und PLAN bleiben normalisiert unverändert. Die anschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen am Lieferstand. Mehrere tatsächliche Varianten je Hash, positive native Writes/Spills, allgemeine Rundungs-/Sorttiegrenzen, Cache-Eviction, Berechtigungen, Timeout, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

USP_QueryStats besitzt bereits einen gemeinsamen TABLE-Export mit 60 Feldern, fünf expliziten Textcollations, 29 NOT-NULL-Feldern und ohne Identity. RAW/JSON enthalten 59 Fachfelder und aktive positive CONSOLE 61 Felder. Native Originalgegenproben belegen die zusätzliche TABLE-/CONSOLE-Zeile bei Limits 1/2. Ein später gemeinsamer Zuschnitt behebt diese Grenze nach Textprojektion und N+1-/HasMoreRows-Bewertung ohne ABI-, Versions-, Rang-, Gate- oder Filteränderung. 36 erste native Originalfälle und je 36 gepaarte native sowie synthetische Original-/Finalfälle bestätigen sämtliche 59 Werte und Schemafacetten, dreizehn Ränge, vier Consumer, drei JSON-Hauptschlüssel und zehn Metafelder. 59 Zusatzfälle und acht Gatefälle prüfen Unicodegrenzen, Hash-/Handlefilter, Mindest-/Zeit-/LIKE-/Regexfilter, vollständige Auswahlwarnings, sechs Mappingablehnungen, fehlenden Snapshot208 und zwei tatsächliche Parentpfade auf Ordinal 1 mit Child-Parität. Common182 besteht 29 allgemeine und 28 native Fälle, drei Consumer, sechs Preflights, drei leere CONSOLE-Captures und unabhängige positive 61-Feld-CONSOLE-Parität. Ein Testsyntaxfehler und möglicher Beobachterselbstmatch werden ausschließlich im neuen Test korrigiert; kein zusätzlicher Parent-Snapshot oder Static950-Owner entsteht. Acht impact-basierte Testdateien bestehen auf CL170 nach einer nicht erneut beobachteten Common165-Metadatenabweichung; deren Ursache bleibt ungeklärt. Alle 75 statischen Prüfungen und 274 echte Static1029-Mutationen bestehen am stabilen funktionalen Stand. Die sechs ursprünglichen 92-Feld-Cachezeilen, fünf Cachepläne, 18 Attribute, Datenbankidentität und vier Tabellenwerte bleiben exakt erhalten; zusätzliche Analysecacheaktivität wird separat begrenzt. Ohne Fixture bestehen 29 allgemeine Fälle, native Fälle melden NOT_EXECUTED. Eigene Quelle, Lab und Secretwert sind entfernt. OPS-005 ist kanonisch synchronisiert; sein Update und PLAN bleiben normalisiert unverändert. Die anschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen am Lieferstand. Allgemeine Rundungs-/Sorttiegrenzen, Eviction, positive native Writes/Spills/Grants im stabilen Procedurescope, Berechtigungen, Timeout, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.


USP_CurrentMemoryGrants besitzt bereits einen gemeinsamen Export mit 63 Feldern, neun expliziten Textcollations, zwei NOT-NULL-Feldern und ohne Identity. Native Originalgegenproben belegen die zusätzliche TABLE-/CONSOLE-Zeile bei Limits 1/2; sieben Sourcezeilen begrenzen die gemeinsame Menge nach Textwarnung und N+1-Zählern ohne ABI-, Versions-, Filter- oder Parentänderung. Je 24 gepaarte Original-/Finalfälle aus einem nativ erfassten und privat eingefrorenen Quellenstand bestätigen sämtliche 63 Werte und Schemafacetten; je 60 synthetische Fälle prüfen KB-/MB-Rundungsties, wartende Grants, NULL-/Nullnenner und fehlende Joinquellen. Weitere 60 Finalfälle prüfen Unicodegrenzen bei 17/18 Zeichen. Zwölf Zusatzfälle bestätigen bestehende Parent-Partialität, ungültige Identitäten/Sessionlisten und zwei tatsächliche positive Overview-Childpfade auf Ordinal 60. Common183 besteht 14 allgemeine und 18 native Fälle, drei Consumer, sechs Preflights, drei leere SQL-CONSOLE-Captures und unabhängige vollständige 64-Feld-CONSOLE-Parität. Zwei Testprobleme werden ausschließlich im neuen Vertrag korrigiert: ein Text-CASE-Collationkonflikt und eine ungeeignete Klammer für neun nichtmonotone globale Zahlenfelder. Deren Cross-call-Werteparität bleibt ausdrücklich unbelegt; TABLE-/JSON-Parität der 63 Felder innerhalb desselben Aufrufs und die übrigen 54 Feldvergleiche bleiben aktiv. Zehn impact-basierte Testdateien und alle 75 statischen Prüfungen sowie 457 echte Static1026-Mutationen bestehen am stabilen funktionalen Stand. Eigene 50.000 Tabellenzeilen bleiben über vier Aggregate unverändert; native Grant- und Sessionidentitäten bleiben erhalten. Nach identitätsgeprüftem Cleanup bestehen die allgemeinen Fälle, native Fälle melden NOT_EXECUTED; eigene Requests, Quelle, Lab und Secretwert sind entfernt. OPS-005 ist kanonisch synchronisiert, sein Update und PLAN bleiben normalisiert unverändert. Die abschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen am Lieferstand. Echte wartende Grants, allgemeine Rundungsgrenzen, konfigurierte Resource-Governor-Wirkung, Berechtigungen, Timeout, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

Die nächste abgegrenzte Current-State-Vertragsprüfung untersucht den beobachteten SourceStatus-Zähler von InternalCaptureCurrentStateSnapshot: SESSIONS meldet 0 trotz mindestens drei eigener erfasster Sessionzeilen, weil die vorhandene Ermittlung WorkloadGroups zählt. Der Collector bleibt in diesem Slice unverändert. Die weitere autonome Fortsetzung prüft Original, betroffene Quellenzähler und Verbraucher vor einer gezielten Korrektur; übrige offene COLL-001-Verträge bleiben erhalten.


Der abgegrenzte Current-State-Quellenzähler-Slice korrigiert ausschließlich die falsche Sessions-Counttabelle im InternalCaptureCurrentStateSnapshot. Acht Original- und acht Finalcaptures prüfen je 67 Mengenrouten; fünf ursprüngliche Sessions-Abweichungen fehlen im Finalstand. Elf Statusfelder, vier Textcollations, neun NOT-NULL-Felder, 13 Parameter und Snapshotvertrag 2 bleiben erhalten. Je Suite bestehen 15 Vorprüfungen, zusätzliche positive Transaktionsmengen, Insertfehlerisolation und vollständige Erhaltung eines älteren Snapshots in 18 Tabellen. Drei leere und drei positive Parentfälle je Suite bestätigen vollständige elf-Feld-TABLE-/JSON-Statusparität; die positive Childmenge besitzt keinen vollständigen 51-Feld-Werteparitätsnachweis. Integration199 weist das Original mit 52199 zurück und besteht mit zwei zusätzlichen Sessions-only-Fällen. Static993 besteht 69 echte Mutationen einschließlich 13 unmittelbarer Zählerabnahmegrenzen; unabhängiger Review, acht impact-basierte SQL-Dateien und alle 75 statischen Prüfungen bestehen. OPS-005 ist kanonisch synchronisiert, sein Update und PLAN bleiben normalisiert unverändert; eigenes Lab, Verbindungen und Secretwert sind entfernt. Die abschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen bestehen am Lieferstand. Der zuvor getrennt offene Sessions-Zählerfehler ist für diesen Scope behoben; COLL-001 und bestehende Statusflags bleiben unverändert. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md).

Die weitere autonome Fortsetzung prüft die verbleibenden Current-State-Ausgabeverträge, beginnend mit USP_CurrentSessions. Vor einer Änderung werden Original, positive Quellen, alle Fachfelder, Ausgabeformen, Filter und Mengenlimits sowie die vorhandenen Parentverbraucher geprüft. Neue öffentliche Diagnosefläche und zusätzliche Snapshotowner sind damit nicht freigegeben; übrige offene Reifeverträge bleiben erhalten.


USP_CurrentSessions besitzt bereits eine gemeinsame Ergebnistabelle mit 51 Feldern, 22 Frameworktextcollations und fünf NOT-NULL-Feldern ohne Identity. Das vollständig geprüfte Original, 168 eingefrorene Consumerfälle, 16 tatsächliche Surrogate-Grenzfälle, 17 Filterfälle und acht Overview-Aufrufe belegen keine Produktabweichung. 42.912 Fachwerte und 357 native Schemafacetten werden unabhängig geprüft; sieben positive Parentaufrufe besitzen vollständige 51-Feld-TABLE-/JSON-Parität auf Ordinal 10. Common184 besteht 20 allgemeine und 21 native TABLE-Fälle sowie Consumer-, Mapping- und CONSOLE-Proben; ohne Fixture bleibt der native Block NOT_EXECUTED. Ein Reviewbefund ergänzt ausschließlich den Upper-idle-Guard des Tests. Static1038 besteht 380 echte Mutationen; Inventar und zwei Dokumente präzisieren die bestehenden Verträge. Source, Collector, Parent, 26 Parameter, SchemaVersion und Installer bleiben normalisiert unverändert; kein neuer Snapshotowner entsteht. CurrentState110/131 und Integration189/199, die einzelne kanonische Impact-Testdatei und alle 75 statischen Prüfungen bestehen auf CL170. Private Capture-/SQLCMD-Annahmen und eine lokale Installer-Zeilenendenabweichung werden ohne semantischen Produktdiff korrigiert. Eigenes Lab, Verbindungen und Secretwert sind entfernt. Die begrenzten abschließenden Dokumentations-, Schreibstil- und Privacyprüfungen bestehen am Lieferstand. MARS, isolierte Ranggrenzen, Berechtigungen, Timeout, weitere Tool-Regeln, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

Die weitere autonome Fortsetzung untersucht die verbleibenden Current-State-Ausgabeverträge, als Nächstes USP_CurrentRequests. Vor einer Änderung werden Original, positive eigene Requests, alle Fachfelder, Text-/Kontextprojektionen, Ausgabeformen, Filter und Mengenlimits sowie vorhandene Parentverbraucher geprüft. Neue öffentliche Diagnosefläche, zusätzliche Snapshotowner und allgemeine Lab-Verantwortung sind damit nicht freigegeben; übrige offene Reifeverträge bleiben erhalten.


USP_CurrentRequests besitzt sieben gemeinsame Exporte mit 230 Feldern und 66 Frameworktextcollations ohne Identity. Native Originalgegenproben belegen 28 Seed-only-TABLE-Ziele bei vier semantisch ungültigen Aufrufen und Fehler 8115 beim INT_MAX-Sekundenfilter. Frühes vorhandenes Prepare und ein bigint-Vergleich beheben ausschließlich diese Grenzen. Je Original- und Abschlussstand bestätigen 160 Consumerfälle, 26 Filterfälle, 32 tatsächliche Unicode-Grenzfälle und sechs positive Overview-Aufrufe insgesamt 234.358 Fachwerte und 1.610 native Schemafacetten. Parentparität umfasst die 50 gemeinsamen Legacywerte sowie vollständigen Kontext, Status und Textarrays; die übrigen 43 Legacywerte besitzen ausschließlich den unabhängigen Childnachweis. Common185 besteht 21 allgemeine und 20 native Fälle, neun selektive Maps sowie Consumer-, Preflight- und CONSOLE-Proben; ohne Fixture bleibt der native Block NOT_EXECUTED. Static1039 besteht 1.279 echte Mutationen. Alle 13 impact-basierten SQL-Dateien und alle 75 statischen Prüfungen bestehen auf CL170. Ein ursprünglicher Capture scheitert mit Lock-Timeout; die einmalige Wiederholung besteht, seine Ursache bleibt offen; private Harnessannahmen, doppeltes Testsetup und ein Shell-Exitquotingfehler werden getrennt dokumentiert. API, SchemaVersion, Collector, Parent und Snapshotowner bleiben erhalten; OPS-005 wird kanonisch synchronisiert, sein Update und PLAN bleiben normalisiert unverändert. Eigenes Lab, Verbindungen, Fixture-Modul und Secretwert sind entfernt. Die begrenzten abschließenden Dokumentations-, Schreibstil- und Privacyprüfungen bestehen am Lieferstand. MARS, isolierte Rangties, Berechtigungen, systematische Timeout-/Tool-Regeln, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

Die weitere autonome Fortsetzung untersucht die verbleibenden Current-State-Ausgabeverträge, als Nächstes USP_CurrentBlocking. Vor einer Änderung werden Original, positive eigene Blockingsituationen, alle Fachfelder, Ausgabeformen, Filter und Mengenlimits sowie vorhandene Parentverbraucher geprüft. Neue öffentliche Diagnosefläche, zusätzliche Snapshotowner und allgemeine Lab-Verantwortung sind damit nicht freigegeben; übrige offene Reifeverträge bleiben erhalten.


USP_CurrentBlocking besitzt einen gemeinsamen Kettenexport mit 67 Feldern und 38 Frameworktextcollations ohne Identity. Native Originalgegenproben belegen N+1-Ausgaben bei begrenztem TABLE, generischer CONSOLE und Parent-TABLE. Die späte gemeinsame Kettenbegrenzung behebt ausschließlich diese Grenze; Kandidatenmetadaten, Sessions, Locks, Objektauflösung und Textprojektion behalten die bisherige N+1-Verarbeitung. Je Original- und Abschlussstand bestehen 160 unterschiedliche native Fälle, darunter 90 Consumer-/Filter-/Unicodefälle, 48 Lock-/Auflösungsfälle, sechs tatsächliche Overview-Aufrufe und 16 negative Fälle. Die Orakel umfassen 106.289 beziehungsweise 104.919 Wert-, Struktur- und Facettenprüfungen, alle 67 Kettenfelder, 23 Lockfelder und 536 physische Schemafacetten. Nicht eindeutige Locksortierties erhalten ausschließlich nativ belegte Grenzoptionen. Parentparität gilt innerhalb desselben Aufrufs für alle 67 gemeinsamen TABLE-/JSON-Werte; eine weitere vollständige Parent-Snapshot-Wertparität bleibt unbelegt. Common186 besteht 18 allgemeine und 18 native TABLE-Fälle sowie Consumer-, Mapping-, Unicode- und CONSOLE-Proben; ohne Fixture bleibt der native Block NOT_EXECUTED. Sechs echte JSON-NULL-Mutationen schließen den unabhängigen Reviewbefund bei nullable Texten. Static1040 besteht 661 Mutationen. Alle elf impact-basierten SQL-Dateien bestehen in 34 Batches; alle 75 statischen Prüfungen bestehen vor der testinternen Reviewkorrektur, danach die vier betroffenen Gates erneut. API, Versionen, Collector, Parent und Snapshotowner bleiben erhalten; OPS-005 wird kanonisch synchronisiert, sein Update und PLAN bleiben normalisiert unverändert. Private Fixture-, Encoding- und Cleanupfehler werden getrennt dokumentiert und behoben. Eigene Sessions, Objekte und Regel sind nativ mit null bestätigt; das eigene Lab und die Secretdatei sind entfernt. Ein unbenutztes kanonisches OPS-Update außerhalb Git bleibt nach einer mit blocked by policy abgewiesenen Löschung erhalten. Die begrenzten abschließenden Dokumentations-, Schreibstil- und Privacyprüfungen folgen am Lieferstand. MARS, Berechtigungen, systematische Timeout-/Tool-Regeln, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

Die weitere autonome Fortsetzung untersucht die verbleibenden Current-State-Ausgabeverträge, als Nächstes USP_CurrentWaits. Vor einer Änderung werden Original, positive eigene Wait-Situationen, alle Fachfelder, Ausgabeformen, Filter und Mengenlimits sowie vorhandene Parentverbraucher geprüft. Neue öffentliche Diagnosefläche, zusätzliche Snapshotowner und allgemeine Lab-Verantwortung sind damit nicht freigegeben; übrige offene Reifeverträge bleiben erhalten.


USP_CurrentWaits besitzt 33 Taskfelder mit 22 Frameworktextcollations und 23 Instanzfelder mit elf Frameworktextcollations ohne Identity. 143 unterschiedliche Originalfälle bestehen mit 164.887 Wert-, Struktur- und Facettenprüfungen sowie 448 unterschiedlichen Schemafacetten. Neun tatsächliche Overview-Aufrufe bestätigen vollständige 33-Feld-TABLE-/JSON-Parität innerhalb desselben Aufrufs, Quellenflags, Modulordinal 40 und Caller-LOCK_TIMEOUT 137; die unabhängigen Werte eines separaten Parent-Snapshots bleiben unbelegt. Native Instanzzähler und kumulative Prozentnenner werden vor/nach begrenzt, stabile Zähler exakt geprüft und übrige Werte unabhängig abgeleitet. Der einzelne WAITFOR-Sample besitzt exakt 100 Prozent; mehrtypige Sample-Prozentnenner bleiben offen. Die bestehende Regexauswahl normalisiert ihren bereits gebildeten Nenner nicht erneut. Mengenlimits, Mappingpreflight und Unicodeprojektion bestehen bereits; keine Produktabweichung wird belegt. Common187 besteht 18 allgemeine und 18 native TABLE-/JSON-Fälle, sechs NULL-Mutationsablehnungen sowie Consumer-, Mapping-, Unicode- und CONSOLE-Proben. Ohne Fixture bleibt der positive Block NOT_EXECUTED. Static1018 besteht 493 echte Mutationen. Alle 75 statischen Prüfungen bestehen nach gezielter Wiederherstellung eines kanonischen LF-Headerübergangs im Windows-Checkout; die übrigen erfolgreichen Prüfungen werden nicht wiederholt. Der einzige impact-basierte SQL-Test besteht in fünf Batches mit sechs Resultgrids. Source, Collector, Parent und beide Adapterinstaller bleiben normalisiert unverändert. Native Abschlussprüfungen bestätigen null eigene Sessions, Tabellen und Regeln; eigenes Lab und Secretdatei sind entfernt. Private Harness-, Rang- und Checkoutgrenzen sind getrennt dokumentiert. Abschließende Dokumentations-, Schreibstil- und Privacyprüfungen gehören zum Liefergate. MARS, Reset, Berechtigungen, systematische Timeout-/Tool-Regeln, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

Die weitere autonome Fortsetzung untersucht die verbleibenden Current-State-Ausgabeverträge, als Nächstes USP_CurrentTransactions. Vor einer Änderung werden Original, positive eigene Transaktionssituationen, alle Fachfelder, Ausgabeformen, Filter und Mengenlimits sowie vorhandene Parentverbraucher geprüft. Neue öffentliche Diagnosefläche, zusätzliche Snapshotowner und allgemeine Lab-Verantwortung sind damit nicht freigegeben; übrige offene Reifeverträge bleiben erhalten.


USP_CurrentTransactions besitzt einen gemeinsamen Export mit 20 Feldern, sieben Frameworktextcollations und drei NOT-NULL-Feldern ohne Identity. Je Original- und Abschlussstand bestätigen 123 native Consumer-, Filter-, Text-, Negativ- und Parentfälle sämtliche Fachwerte, 320 unterschiedliche SQL-/SqlClient-Schemafacetten und 17.445 beziehungsweise 17.125 Orakelprüfungen. Native Originalgegenproben belegen vier TABLE-/CONSOLE-Limitüberschreitungen und fünf zusätzliche Parent-TABLE-Abweichungen; zehn Sourcezeilen begrenzen die gemeinsame Menge nach Unicodewarnung, N+1-Zählern und Fehlerbehandlung. Alle acht tatsächlichen Overview-Aufrufe am Abschlussstand bestätigen vollständige 20-Feld-TABLE-/JSON-Parität innerhalb desselben Aufrufs, Quellenflags, Modulordinal 50 und Caller-LOCK_TIMEOUT 137. Ein separater vollständiger Parent-Snapshot-Wertevergleich bleibt unbelegt. Common188 besteht 18 allgemeine und 18 native Fälle sowie NULL-Mutations-, Consumer-, Mapping-, Unicode- und CONSOLE-Proben; ohne Fixture bleibt der positive Block NOT_EXECUTED. Der neue Vertrag weist das Original nativ mit 59013 zurück und besteht am identischen finalen Stand. Static1015 besteht 251 echte Mutationen. Alle 75 statischen Prüfungen und alle zehn impact-basierten SQL-Testdateien in 30 Batches bestehen. ABI, Versionen, Collector, Parent und Snapshotowner bleiben erhalten; OPS-005 wird kanonisch synchronisiert, sein Update und PLAN bleiben normalisiert unverändert. Native Abschlussprüfungen bestätigen null eigene Sessions, Tabellen und Regeln; eigenes Lab und Secretdatei sind entfernt. Eine unbenutzte kanonische OPS-Updatedatei bleibt nach der mit blocked by policy abgewiesenen Löschung privat außerhalb Git erhalten. Private Capture- und Patchgrenzen werden getrennt dokumentiert. Abschließende Dokumentations-, Schreibstil- und Privacyprüfungen gehören zum Liefergate. MARS, gebundene Transaktionen, mehrere Datenbankbindungen, isolierte Rangties, positive Systemtransaktionen, Berechtigungen, systematische Timeoutfälle, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 und bestehende Statusflags bleiben unverändert.

Die weitere autonome Fortsetzung untersucht die verbleibenden Current-State-Ausgabeverträge, als Nächstes USP_CurrentTempDB. Vor einer Änderung werden Original, positive eigene TempDB-Nutzung, alle Fachfelder, Ausgabeformen, Filter und Mengenlimits sowie vorhandene Parentverbraucher geprüft. Neue öffentliche Diagnosefläche, zusätzliche Snapshotowner und allgemeine Lab-Verantwortung sind damit nicht freigegeben; übrige offene Reifeverträge bleiben erhalten.


USP_CurrentTempDB besitzt unveränderte Session-, Governance- und Dateischemas mit zwölf, 21 und zehn Feldern. Je Original- und Abschlussstand bestehen 165 unterschiedliche native Consumer-, Filter-, Dateiverbrauchs-, Negativ- und Parentfälle mit 968 Resultgrids, 608 unterschiedlichen physischen Schemafacetten und 34.986 beziehungsweise 34.843 Orakelprüfungen. 17 Sourcezeilen begrenzen die gemeinsame Session- und Governancemenge nach N+1-Zählerabnahme und Fehlerbehandlung; ursprüngliche direkte Governancevorauswahl, Statusbewertung, Sessionmetadaten und Filter bleiben erhalten. Sämtliche nachgewiesenen Limitabweichungen entfallen. Fünf tatsächliche Overview-Aufrufe bestätigen am Abschlussstand alle 33 TABLE-/JSON-Fachfelder desselben Aufrufs, Schemas, Quellenflags, Modulordinal 70 und Caller-LOCK_TIMEOUT 137. Ein separat erfasster atomarer vollständiger Parent-Snapshot-Vergleich bleibt unbelegt. Dateifälle bestätigen alle zehn Consumerfelder, sieben stabile native Metadaten und drei Seitenarithmetikprüfungen; ein volatiler Abschlusswert von 108 liegt außerhalb der Vorher-/Nachhergrenzen. Native NULL-Dateiverbrauchswerte werden nicht beobachtet. Common189 besteht zwölf allgemeine und 14 native Fälle sowie zwölf NULL-Mutationsablehnungen und weist das Original nativ mit 59211 zurück. Ohne Fixture bleibt der positive Block NOT_EXECUTED. Static1027 besteht 341 tatsächliche Mutationen. Der vollständige statische Lauf besteht zunächst 74 Prüfungen; Static991 besteht nach der erforderlichen gepaarten Governanceannotation gezielt samt Selbsttest. Alle 75 statischen Prüfungen sind über diese Läufe erfolgreich nachgewiesen. Alle zehn impact-selektierten SQL-Dateien bestehen in 30 Batches. ABI, Versionen und Snapshotowner bleiben unverändert. OPS-005 wird kanonisch synchronisiert; Collector, Parent, ResourceGovernor-Source, OPS-Update und EXECUTION-PLAN-001 bleiben normalisiert unverändert. Native Abschlussprüfungen bestätigen null eigene Sessions, Tabellen, Governancegruppen und Benutzer; eigenes Lab und Secretdatei sind entfernt. Private Capturekorrekturen und verbleibende Evidenzgrenzen sind unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert. Abschließende Dokumentations-, Schreibstil- und Privacyprüfungen gehören zum Liefergate. COLL-001 und bestehende Statusflags bleiben unverändert.

Die weitere autonome Fortsetzung untersucht die verbleibenden Current-State-Ausgabeverträge, als Nächstes USP_CurrentIO. Vor einer Änderung werden Original, positive eigene IO-Aktivität, alle Fachfelder, Ausgabeformen, Filter und Mengenlimits sowie vorhandene Parentverbraucher geprüft. Neue öffentliche Diagnosefläche, zusätzliche Snapshotowner und allgemeine Lab-Verantwortung sind damit nicht freigegeben; übrige offene Reifeverträge bleiben erhalten.


USP_CurrentIO besitzt unveränderte fünf Exportschemas mit 65 Feldern, 23 Textcollations und 40 NOT-NULL-Feldern. Je Original- und Abschlussstand bestehen 131 unterschiedliche native Consumer-, Filter-, Negativ-, Parent- und Stichprobenfälle mit 730 beziehungsweise 742 Resultgrids, 1.105 unterschiedlichen physischen Schemafacetten und 19.452 beziehungsweise 19.398 Orakelprüfungen. Die gemeinsame Datei- und Pendingbegrenzung folgt auf N+1-Zählerabnahme und Fehlerbehandlung. Alle nachgewiesenen Dateiüberschreitungen entfallen; positive Pendingzeilen und positive Pendinglimitwirkungen bleiben unbelegt. Die besondere zehnspaltige CONSOLE-Gesamtbegrenzung bleibt erhalten. Acht ursprüngliche NULL-Statusfehler 515 entfallen; ausschließlich zwei NOT-NULL-Modulstatusfelder erhalten typisierte 0-Werte, tatsächliche JSON-NULL-Argumente bleiben erhalten. Alle 16 Mappingfehler melden THROW 51011 vor semantischen Prüfungen und bewahren vorhandene Seedzeilen samt Schema. Fünf tatsächliche Overview-Aufrufe bestätigen am Abschlussstand alle 19 Dateifelder innerhalb desselben Aufrufs, Schemas, vier vorhandene Quellenflags und Modulordinal 80. Separate atomare volatile Parentwerte werden nicht behauptet. Alle 19 nativen Dateifelder werden durch Messklammern, Katalog- und Formelprüfungen belegt; vier Stichprobenfälle je Stand erfassen zwölf positive Operationszeilen. Common190 besteht 23 allgemeine und 14 bedingte native Fälle samt drei NULL-Mutationsablehnungen und weist das Original nativ mit 59301 zurück. Ohne Fixture bleibt der native Block NOT_EXECUTED. Static1037 besteht 524 Mutationen, ein vollständiger statischer Lauf alle 75 Prüfungen. Alle zwölf impact-selektierten SQL-Dateien bestehen am Abschlussstand in 36 Batches. ABI, Versionen, Snapshotowner und Statusflags bleiben unverändert. OPS-005 wird kanonisch synchronisiert; Collector, Parent, OPS-Update und EXECUTION-PLAN-001 bleiben normalisiert unverändert. Ursprüngliche eigene Datenbankidentitäten, Optionen und wiederhergestellte Datenzeilen sind nativ geprüft; eigene Datenbanken, Lab und Secretdatei sind entfernt. Private Orakelkorrekturen und verbleibende Evidenzgrenzen sind unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert. Abschließende Dokumentations-, Schreibstil- und Privacyprüfungen gehören zum Liefergate.

Die weitere autonome Fortsetzung untersucht die verbleibenden Current-State-Ausgabeverträge, als Nächstes USP_CurrentLog. Vor einer Änderung werden Original, positive eigene Aktivität, alle Fachfelder, Ausgabeformen, Filter und Mengenlimits sowie vorhandene Parentverbraucher geprüft. Neue öffentliche Diagnosefläche, zusätzliche Snapshotowner und allgemeine Lab-Verantwortung sind damit nicht freigegeben; übrige offene Reifeverträge bleiben erhalten.


USP_CurrentLog besitzt einen unveränderten gemeinsamen logs-Vertrag mit 19 Feldern, acht Textcollations und sechs NOT-NULL-Feldern ohne Identity. Je Original- und Abschlussstand bestehen 117 unterschiedliche Fälle mit 767 Resultgrids, 323 unterschiedlichen physischen Schemafacetten und 18.986 beziehungsweise 18.984 Orakelprüfungen. Zehn neue Sourcezeilen begrenzen die gemeinsame Logmenge erst nach vollständiger Sammlung, Prozentfilter, Zählern, Status und Detail. Alle fünf beobachteten TABLE-/CONSOLE-/Parentlimitabweichungen entfallen; vollständige Auswahlwarnings bleiben erhalten. Alle 19 Logfelder werden innerhalb desselben Aufrufs über TABLE/JSON und unabhängig gegen native Katalog-, Logspace-, Logstatistik-, VLF- und PVS-Werte geprüft. Native Zahlen verwenden Messgrenzen; ein atomarer Cross-call-Vergleich wird nicht behauptet. Je Stand werden zwei positive PVS-Consumerzeilen beobachtet. 44 Mappingfehler melden THROW 51011 und erhalten Seedwerte, Schema, Caller-OUTPUT und LOCK_TIMEOUT 137; zwei ungültige Modi ohne nichtleeres Mapping bleiben normale INVALID_PARAMETER-Ausgänge. Fünf tatsächliche Overview-Aufrufe bestätigen am Abschlussstand alle 19 Logfelder, Clientfacetten und Modulordinal 90; Logs-only besitzt keine Snapshot-ID und keine Snapshotstatuszeilen. Common191 besteht 36 allgemeine und 41 bedingte native Fälle samt sechs echten NULL-Ablehnungen, getrennten VLF-/PVS-Nachweisen und nativer Originalzurückweisung mit 59411. Ohne Fixture bleibt der native Block NOT_EXECUTED. Static1028 besteht 303 Mutationen, der vollständige statische Lauf alle 75 Prüfungen. Alle zehn impact-selektierten SQL-Dateien bestehen in 30 Batches. ABI, Versionen, Snapshotowner und Statusflags bleiben erhalten. OPS-005 wird kanonisch synchronisiert; Collector, Parent, OPS-Update und EXECUTION-PLAN-001 bleiben normalisiert unverändert. Eigene Datenbankidentitäten, Optionen und 4.000 Datenzeilen sind unverändert geprüft; eigene Datenbanken, Lab und Secretdatei sind entfernt. Private Orakelkorrekturen bei volatiler Prozentbelegung und die verbleibenden Evidenzgrenzen sind unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert. Abschließende Dokumentations-, Schreibstil- und Privacyprüfungen gehören zum Liefergate. COLL-001 und bestehende Statusflags bleiben unverändert.

Die weitere autonome Fortsetzung untersucht die verbleibenden Current-State-Ausgabeverträge, als Nächstes USP_CurrentOverview. Vor einer Änderung werden Original, alle betroffenen Fachfelder, Ausgabeformen, Filter und Mengenlimits sowie vorhandene Child- und Snapshotverträge geprüft. Neue öffentliche Diagnosefläche, zusätzliche Snapshotowner und allgemeine Lab-Verantwortung sind damit nicht freigegeben; übrige offene Reifeverträge bleiben erhalten.


USP_CurrentOverview besitzt 17 bedingte TABLE-Exporte mit 540 aktivierten Feldern. Je Original- und Abschlussstand bestätigen 105 unterschiedliche Fälle 9.720 physische Schemafacetten und 300.838 beziehungsweise 299.342 Orakelprüfungen. Die frühe vorhandene Mappingvorbereitung und die INVALID_PARAMETER-Partialitätsklausel beheben 32 unterdrückte Mappingprüfungen, sieben unvorbereitete gültige TABLE-Ablehnungen und 34 falsche JSON-Gesamtpartialitäten; diese Beobachtungsmengen überlappen. Alle 40 fehlerhaften Mappings werfen anschließend 51011. Die vier Ausgabemodi, Detailauswahl, Modulreihenfolge, Childlimits, Statuszähler, bedingte Seedziele und erhaltene Child-Fehlerisolation sind geprüft. Die private Requests-Wertparität umfasst 50 der 93 Legacy-Felder; alle 93 Schemas und die vier zusätzlichen 73/19/15/13-Feld-Mengen sind geprüft. Positive Grants und separate atomare Snapshot-/Helperwerte bleiben unbelegt. Common192 besteht 43 allgemeine und 14 native Fälle, 40 Preflights und drei echte NULL-Ablehnungen samt Originalzurückweisung mit 59505; ohne Fixture bleibt der positive Block NOT_EXECUTED. Static1041 besteht 1.083 Mutationen, alle 75 statischen Prüfungen und alle neun impact-selektierten SQL-Dateien in 28 Batches bestehen. API, Versionen, Collector, Snapshotowner und Statusflags bleiben erhalten; OPS-005 wird kanonisch synchronisiert. Eigene Sessions, Tabellen und Regel sind nativ mit null bestätigt; eigenes Lab und Secretdatei sind entfernt. Private Harness- und Reviewkorrekturen, der nicht erneut beobachtete Lock-Timeout und die verbleibenden Grenzen stehen unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md). Abschließende Dokumentations-, Schreibstil- und Privacyprüfungen gehören zum Liefergate. COLL-001 und bestehende Maturityflags bleiben unverändert.

Die weitere autonome Fortsetzung ordnet die verbleibenden gemeinsamen Ausgabe-, Auswahl- und Reifeverträge anhand der kanonischen Statusquellen und der bestehenden Exit-Kriterien. Vor einer Änderung werden Original, betroffene Fachfelder, Consumer und vorhandene Integrationen geprüft. Neue öffentliche Diagnosefläche, zusätzliche Snapshotowner und allgemeine Lab-Verantwortung sind damit nicht freigegeben; übrige offene Reifeverträge bleiben erhalten.


Die fünf bestehenden Query-Store-Referenzlistenpfade verwenden den Frameworkparser jetzt dreistellig mit dem vor dem dynamischen USE ermittelten, durch QUOTENAME geschützten Frameworknamen. Je Original- und Abschlussstand bestätigen 170 native Fälle sechs Exporte mit 172 Feldern, 53 Textcollations und 2.924 unterschiedlichen physischen Schemafacetten. Alle 105 ursprünglichen exakten Referenzfälle mit Fehler 208 bestehen anschließend ohne diese Warnungen. Native Showplanattribute liefern die unabhängige case-sensitive Referenzauswahl; doppelte Listenwerte vervielfachen keine Zeilen. Vierzehn tatsächliche Parentaufrufe und 20 zusätzliche Calleraufrufe bestätigen die bestehenden Consumerverträge. Vollständige unabhängige Zahlenformeln für alle 172 Felder und positive Standardregressionen werden nicht behauptet. Common193 besteht 45 allgemeine und 65 native Fälle sowie Consumer-, Preflight-, Parent- und fünf echte NULL-Mutationsprüfungen; das Original wird nativ mit 59620 zurückgewiesen. Ohne eigene Quellen bleibt der positive Block NOT_EXECUTED. Static1049 besteht 50 Mutationen, alle 76 statischen Prüfungen und alle 20 impact-selektierten SQL-Dateien auf SQL Server 2025 mit CL170 bestehen. Die fünf Sourceänderungen beschränken sich auf Parseradressen; ABI, Versionen, Snapshotowner und Maturityflags bleiben erhalten. OPS-005 wird kanonisch synchronisiert. Native Abschlussprüfungen bestätigen unveränderte eigene Quellen; beide Quellen, eigenes Lab und Secretdatei sind entfernt. Der unabhängige funktionale Review besitzt keine offenen Befunde. Eingeschränkte Berechtigungen, unterschiedliche Referenzmengen mehrerer Pläne desselben Querykeys, systematische Timeout-/Quellenfehler, positive Regex-Referenzfälle, ältere Engines und CL150/160 bleiben unbelegt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md); COLL-001 bleibt partiell.

Die weitere autonome Fortsetzung ordnet die verbleibenden gemeinsamen Ausgabe-, Auswahl- und Reifeverträge anhand der kanonischen Statusquellen und bestehenden Exit-Kriterien. Vor einer Änderung werden Original, betroffene Fachfelder, Consumer und vorhandene Integrationen geprüft. Neue öffentliche Diagnosefläche, zusätzliche Snapshotowner und allgemeine Lab-Verantwortung sind damit nicht freigegeben; übrige offene Reifeverträge bleiben erhalten.


PlanDetails bewahrt jetzt bei negativen Textlimits den bestehenden INVALID_PARAMETER-Vertrag in TABLE, RAW, CONSOLE und NONE. Acht tatsächliche Originalfehler51021 werden durch ein ausschließlich internes Projektionsargument behoben; öffentliche Parameter, positive/NULL-/0-Semantik und Warningparameter bleiben erhalten. Je Original- und Abschlussfassung bestehen 84 reguläre native Fälle; vier zusätzliche Kurzhandle-569-Fälle bleiben separat charakterisiert. Die drei Fachschemata mit 37 Feldern, neun Textcollations und acht SqlClient-/zehn SQL-Facetten sowie aktive CONSOLE-Schemata werden unabhängig bestätigt. Auswahlmultisets, Unicode-Offsets/-Messwerte, native Attribute und Compile-/Textpläne besitzen unabhängige Werteorakel; gleichaufrufbezogene Fachparität und 4.036 Assertions bestehen. Ein gezielt evicteter eigener Handle bewahrt seine quellenspezifischen Status. Common194 besteht 16 allgemeine und zwölf native Fälle, drei NULL-Mutationen mit identischem positivem Prüfer, Consumer- und Preflightprüfungen. Eine zusätzliche native Doppel-Auswahl-Mutation wird abgewiesen; das erneut installierte Original wird mit 51021 zurückgewiesen. Ohne Fixture bleibt der native Block NOT_EXECUTED. Static1031 besteht 243 Mutationen, alle 76 statischen Prüfungen und acht impact-selektierte SQL-Dateien auf SQL Server 2025 mit CL170 bestehen. Die sieben funktionalen Freezehashes besitzen einen unabhängigen Review ohne offene Befunde; OPS-005 ist kanonisch synchronisiert. Eigenes Lab, eigene Quelle und Secretdatei sind entfernt. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md). Rollen, positive Actual-/Live-Pläne, systematische Quellenfehler/Timeouts und zusätzliche Engines/Compatibility Levels bleiben unbelegt; COLL-001 bleibt partiell.

Die weitere autonome Fortsetzung prüft die separate kontrollierte Behandlung kurzer oder ungültiger Planhandles sowie verbleibende gemeinsame Auswahl-, Ausgabe- und Reifeverträge anhand der kanonischen Exit-Kriterien. Vor jeder Änderung bleiben Originalnachweis, fachlicher Umfang, Consumer und vorhandene Integrationen verbindlich. Neue öffentliche Diagnosefläche, Snapshotowner und allgemeine Lab-Verantwortung sind damit nicht freigegeben. Erfolgreiche CI am tatsächlich gelieferten Head, PR-Abschluss und eigener Git-Cleanup gehören weiterhin zum Lieferweg.


PlanDetails behandelt die charakterisierten Handlefehler jetzt getrennt je Kandidat und Detailquelle. Je Original- und Abschlussstand werden 128 Handlefälle, 32 ergänzende Auswahl-/NULL-/Parameterfälle und 84 reguläre Fälle geprüft. Alle 112 unkontrollierten Originalfehler 569 entfallen; fehlerhafte Kandidaten behalten ihre Rohfelder und erfolgreiche Nachbarkandidaten ihre verfügbaren Details. Der erste native Fehler bleibt im PARTIAL-Modulstatus erhalten. Zuvor erfolgreiche leere Quellen, INVALID_PARAMETER, Mengenbegrenzung, 18 Parameter und die drei öffentlichen Fachschemata mit 37 Feldern bleiben erhalten. Die unabhängigen Prüfer bestehen 12.197 Assertions; sechs tatsächliche Capturemutationen werden abgewiesen. Common194 besteht am endgültigen Freeze 17 allgemeine und zwölf native Fälle, drei NULL-Mutationen, 21 Handle-TABLE-, 80 gemischte Handle-TABLE- und 48 Handle-Consumerfälle sowie weitere Consumer-, Preflight- und leere CONSOLE-Proben. Derselbe Vertrag weist das erneut installierte Original nativ mit 569 zurück. Ohne Fixture bleiben positive native Fälle NOT_EXECUTED. Static1031 besteht 274 Mutationen, alle 76 statischen Prüfungen und acht impact-selektierte SQL-Dateien auf SQL Server 2025 mit CL170 bestehen. Die sechs funktionalen Freezehashes besitzen einen unabhängigen Review ohne offene Befunde; OPS-005 ist kanonisch synchronisiert. Die finale vollständige Definition und alle nativen Parameter werden nach Wiederherstellung und Integrationstests erneut bestätigt. Eigene Quelle, eigenes Lab samt Volume und Secretdatei sind entfernt. Ein erster einzelner Fehler 1222 und zwei zunächst beobachtete Sourceanfragen bleiben getrennt dokumentiert; die unveränderte Gesamtwiederholung beziehungsweise erneute Cleanupvorprüfung bestehen, ohne deren ursprüngliche Ursachen zu behaupten. Der begrenzte Nachweis steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md). Positive Live-/Actual-Pläne, eingeschränkte Rollen, systematische Timeouts, weitere Quellenfehler und zusätzliche Engines/Compatibility Levels bleiben unbelegt; COLL-001 bleibt partiell.

Security-Cloud-Scans werden zusätzlich berücksichtigt. Die aktuelle Befundabfrage ist leer; der einzige verfügbare Scan eines älteren Repositorycommits ist jedoch mit remote_execution_unknown und ohne Ergebnisartefakte fehlgeschlagen. Ein erfolgreicher Security-Cloud-Nachweis für den aktuellen Lieferstand bleibt offen und wird durch lokale Tests oder eine leere Befundliste nicht ersetzt.

Die weitere autonome Fortsetzung ordnet verbleibende gemeinsame Auswahl-, Ausgabe- und Reifeverträge anhand der kanonischen Statusquellen und Exit-Kriterien. Originalnachweis, fachlicher Umfang, Consumer, vorhandene Integrationen und verfügbare Security-Cloud-Befunde werden vor einer Änderung geprüft. Neue öffentliche Diagnosefläche, zusätzliche Snapshotowner und allgemeine Lab-Verantwortung bleiben außerhalb des freigegebenen Umfangs. Erfolgreiche CI am tatsächlich gelieferten Head, PR-Abschluss und eigener Git-Cleanup gehören weiterhin zum Lieferweg.


PlanCacheHealth besitzt jetzt stärkere Nachweise für seine bestehenden Ausgabe- und Detailmengenverträge. Produktionsquellen, zwölf Parameter, Versionen und Statusflags bleiben unverändert. Die native Originalmatrix besteht 64 Aufrufe, 175 Grids und 12.157 Assertions; dreizehn tatsächliche Capturemutationen werden abgewiesen. Vollständige unabhängige Werteformeln für alle 24 Fachfelder bestehen zusätzlich in zwölf separat gekennzeichneten synthetischen Clonefällen mit 4.758 Assertions, nicht als atomarer DMV-Nachweis. Runtime134 besteht 20 Kernfälle, sieben Detailflagfälle, drei Consumerstatusfälle, acht Vorprüfungen, vier Parentfälle, drei NULL-Mutationsablehnungen und positive/leere SQL-CONSOLE-Proben. Static1017 besteht 210 Mutationen, die vollständige statische Suite alle 76 Prüfungen und die einzige impact-selektierte SQL-Datei den nativen Lauf. Der unabhängige Review besitzt keine offenen Befunde; finale Definitionen, ABI und eigener Cleanup sind bestätigt. Die begrenzte Evidenz steht unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md). Rollen, systematische Quellenfehler/Timeouts, ein tatsächlich leerer nativer Cache, weitere Engines/Compatibility Levels und erfolgreiche aktuelle Security-Cloud-Evidenz bleiben offen; COLL-001 bleibt partiell.

Der zusätzliche Benutzerauftrag vom 7. Oktober 2026 ist im Arbeitselement
`WI-0011` implementiert. Der [Deploymentvertrag](../../../Documentation/Architecture/Lossless_Deployment_Contract.md)
und die [Bedienungsreferenz](../../../Documentation/Reference/Deployment.md)
beschreiben den aus kanonischen Quellen erzeugten Core- und optionalen
Snapshotumfang. Customdaten, lokale Policy und Legacytabellen bleiben
erhalten; erlaubte Default- und Versionsänderungen erhalten typgetreue
Vorzustände. Die zwölf Wait-Ergänzungen sind als bekannte additive Migration
unterstützt. Unbekannte Strukturen und Ownershipkonflikte führen vorab zum
Abbruch. Native Erstinstallations-, Wiederholungs-, Erhaltungs-, Kontext-,
Rechte-, Konkurrenz- und Rollbackgegenproben sind unter
[EXP-0001](WI0011_Deployment_Runtime_Evidence_2026-10-07.md) dokumentiert.
Erforderliche erfolgreiche Head-CI, Integration, Synchronisierung und eigener
Cleanup bleiben Liefergates. Die anschließende Benutzerpause wurde durch den
oben dokumentierten neuen Fortsetzungsauftrag aufgehoben; die übrige Reifewelle
bleibt innerhalb ihrer bestehenden Grenzen ausführbar.

## Freigegebene SSIS-Legacy-Umsetzung vom 16. Oktober 2026

Der Benutzer hat die geprüfte Revision 3 ausdrücklich freigegeben. Der [Legacy-Vertrag](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#freigegebener-legacy-kern-vom-16-oktober-2026) enthält 20 Parameter, neun Schemas und gespeicherte Meldungstexte als Default. Zusätzliche Quellindizes sind keine Voraussetzung. Produkt, synthetische Vertragsprüfung, Installer, Inventare und reguläre Integration sind geliefert. Die spätere begrenzte Providerabnahme vom 18. Oktober ist oben dokumentiert; zusätzliche Rollen und weitere Interpretationsfunktionen bleiben offen. Frühere geschlossene Budgets und WI-0009 GATE-0001 bleiben unverändert.

## Begrenzte Taskerweiterung: lokaler Abnahmeabschluss

Der freigegebene IncludeTaskAnalysis-Slice ist implementiert. Vierzehn
synthetische Fallgruppen einschließlich vier privater extrahierter S13-Pfade
und enger S06/S12-Gegenproben bestehen. Native N01/N02 bestehen auf
SQL/SSIS 17.0.5015.4 mit zehn Consumer-Captures und 1456 Prüfungen. Die
kanonische [Abnahme](../../../Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#taskintervalle-und-loggingabdeckung-abnahme-vom-18-oktober-2026)
trennt unabhängige neue 48-Feld-Prüfung, Outputparität und historische v1-
Evidenz. Windows-CL ist im Capture nicht separat erhoben und bleibt UNKNOWN.
Native Versuch 1 scheiterte vor Execute an der lokalen Hash-Cmdlet-Verfügbarkeit;
Versuch 2 führte beide neuen Pakete aus; dessen eigener Cleanup ist bestätigt.
Der frühe synthetische Arrangefehler besitzt einen separaten ID-/
Erstellungszeit-gebundenen Empty-DB-Recoverybeleg, ohne darin gespeicherte
zusätzliche native Nach-Abwesenheitsmenge; sein Originalfehler bleibt erhalten.
Weitere native Läufe werden aus dem Liefergate nicht abgeleitet. Exakte
Head-CI und reguläre PR-Integration sind vor dem Lieferabschluss noch offen.

### Verarbeitungsaufwand der SSIS-Vertrauensausnahme

Die Quelle an der eigenen Procedure benötigt READCOMMITTEDLOCK, damit ein
uncommittierter Metadatenbeleg keine Trustfreigabe erzeugt. Die eng gebundene
Ausnahme in Validator 950 besitzt positive und negative Selbsttests für Pfad,
Quelle und Hint. Der vorhandene konservative Dokumentationsworkflow führt
weiterhin seine statischen Gates aus; der zentrale Release-Runner löst das
vollständige SQL2025-Gate aus. Es entsteht keine zusätzliche Engine-Matrix.
Ein zusätzlicher begrenzter unabhängiger Check betrifft ausschließlich diese
neue Sicherheits-/Validatorgrenze. Erfolgreiche Produktprüfungen werden dadurch
nicht erneut semantisch reviewed. Token- und Geldaufwand sind UNKNOWN.


## Gesondert freigegebene SSIS-Dataflowkorrelation

Der Benutzer hat die achte SSIS-Welle mit Weiterverwendung der bestehenden
SSISDB und regulärer automatischer Integration nach erfolgreicher Abnahme
freigegeben. Dieser Auftrag ist vom Entwicklungsrangplan dieses Dokuments
getrennt. Parser, Komponentenprofile und Lineage verbleiben im Toolbelt;
Analyze konsumiert den optionalen Sidecar und Katalogcapture ohne SQL CLR.

Die Implementierung ergänzt vier opt-in Ergebnisgruppen. Die gemeinsame
Toolbelt-Konformität besteht 147 Prüfungen und die bisherigen 21
Frameworkfälle. Der unabhängige SDK-Vergleich ordnet fünf synthetische Flows,
20 Komponenten und 15 Pfade denselben Modellreferenzen zu. Der neue
SQL-Empfängervertrag besteht 41 Fälle; die bisherigen Ausführungs-, Iterations-
und Scopeempfänger bestehen ebenfalls. Sechs Adapterfälle mit simulierten
Quelltabellen prüfen den echten SQL-Empfänger einschließlich großer IDs,
Logginglücken, Fehlerisolation und ungültiger Quellformen. Diese Fälle sind
keine native SSISDB-Abnahme.

Die fünf fachlichen nativen Abnahmefälle sind belegt; die reguläre Integration
und ihre Head-/Main-Gates stehen noch aus. Der zusätzlich freigegebene
Lab-PR844 ergänzt eine an Execution-ID, Projekt-LSN, Katalogkennung und VM
gebundene lesende Diagnose. Feste Dateien und Registrierungen sowie ein
laufender Stock-ForLoop-Worker wurden beobachtet. Der Windows-Startbatch des
nativen Consumers hält seine Sitzung jetzt bis zum eigenen terminalen
Ausführungsstatus offen. Eine bestimmte Registry-/Profilursache wird dadurch
nicht als bewiesen dargestellt.

Der erste erfolgreiche neue Verboselauf zeigte eine falsche Empfängerannahme
über Kindpaketnamen. Die Korrektur bindet Phasen und Transfers an den
Archiveintrag der bereits zugeordneten Paketinstanz. Drei neue synthetische
Fälle prüfen die positive Kindpaketbindung und die Ablehnung falscher
Startpaketnamen. Der korrigierte Replay dieses echten Captures ordnet sechs
Flowinstanzen, 378 Phasen und 36 Transfers zu; jeder der drei SDK-Pfade liefert
je Vorkommen fünf Zeilen. Seine RAW-/JSON-/TABLE-Parität besteht 14553
Vergleiche. Der ursprüngliche native Harnessfehler bleibt erhalten; dieser
Nachweis ist ein Capture mit Empfängerreplay und kein erneut gestarteter
Verboselauf.

Die vollständigen nativen Harnessläufe bestehen für Performance mit 12854,
Basic mit 2095 und den eigenen SQL-Konvertierungsfehler mit 1888 Prüfungen.
Sie schließen Ausgabeparität, reales Redeployment, Ablehnung aktueller Bytes
für eine ältere Ausführung und bestätigten Cleanup ein. Der Abbruchnachlauf
besteht 1277 Prüfungen bei Status 3. Seine Phasen bleiben ohne die fehlenden
Executable-Statistiken ausdrücklich unzugeordnet; es werden weder Paket- noch
Flowinstanzen erfunden. Die ursprüngliche strengere Harnesserwartung und ihr
Fehler bleiben erhalten. Fünf gezielte Gegenprüfungen sichern die korrigierte
Abbrucherwartung; der Produktconsumer wurde dafür nicht geändert.

Die ausdrücklich freigegebene Obergrenze von 23 nativen Versuchen ist erreicht.
Alle früheren Versuche bleiben gezählt; weitere native Starts sind nicht
freigegeben. Der fünfte gezielte Review hat keine neuen materiellen Befunde
an Consumer, Windows-Startbatch oder SDK-Fixture festgestellt. Der spätere
Abbruchnachlauf präzisiert ausschließlich die Testoracle-Erwartung an eine
bereits vorgesehene partielle Ausgabe. Der lokale Kurzbericht scheiterte nach
dem erfolgreichen Abbruchharness an einem optionalen Fehlerfeld und wurde
anhand der gesicherten Receipt ohne Paketwiederholung korrigiert. Die eigenen
Consumerobjekte sind nachgewiesen bereinigt. Die bestehende SSISDB bleibt
ausdrücklich erhalten; weder ein Timer noch CI erneuert das Budget.

Der unabhängige Review hat vier Eingabebefunde geschlossen. Der zusätzliche
Errorfall des nativen Harness verlangt nun einen positiven Beleg des eigenen
SQL-Konvertierungsfehlers; drei synthetische Gegenprüfungen sichern diese
Ursachenprüfung ab. Reine Verbindungsfehler dürfen keine Error-Abnahme ergeben.
Native Abnahme, exakte Head-/Main-Gates und reguläre Integration werden erst mit
ihrer tatsächlichen Durchführung als abgeschlossen dokumentiert. Der Timer
startet keine unveränderten nativen Wiederholungen oder fremden Wellen.

## Freigegebene neunte SSIS-Welle

Der Benutzer hat die laufzeitgestützte Dataflow-Diagnose mit vier additiven
Ergebnisgruppen, endlichen Regeln und vorhandener SSISDB freigegeben. Analyze
verantwortet die Auswertung gebundener Phasen und Transfers. Das zusätzlich
benötigte Lookup-No-Match-Profil verbleibt im kanonischen Toolbelt-Kern.
Parser und Lineage werden nicht dupliziert; Analyze bleibt CLR-frei.

Der Quellstand liefert die vier Diagnosegruppen mit Quellenreferenzen und
expliziter Partialität. Der SQL-Vertrag besteht 26 gezielte Fälle und die
bisherigen Iterations-, Scope- und Pipelinegegenprüfungen. Der gemeinsame
Toolbelt-Kern besteht 165 Konformitätsprüfungen und 23 Frameworkfälle.
Die native Abnahme belegt Verbose-, Performance- und Basic-Logging, jeweils drei
Zeilen am Fehler- beziehungsweise No-Match-Ausgang und den Abbruchfall. Der
ursprüngliche Fehler der SDK-Inputdisposition bleibt im privaten Nachweis
fehlgeschlagen erhalten; die korrigierte Fixture besteht beide Routingfälle.
Der unabhängige Review hat seine konkreten Code-, Fixture- und Dokumentations-
befunde geschlossen. Die erforderlichen exakten Head-/Main-Gates gehören
weiterhin zur regulären Integration; lokale Erfolge ersetzen sie nicht.

Die frühere native Obergrenze der achten Welle bleibt geschlossen. Der eigene
begrenzte Prüfrahmen dieser Welle wird weder durch Timer noch CI zurückgesetzt.
Die bestehende SSISDB bleibt erhalten; eigene Consumerobjekte werden nach jedem
Lauf identitätsgebunden bereinigt. Reguläre automatische Integration nach
vollständiger Abnahme ist ausdrücklich autorisiert. Der begrenzte Auftrag
enthält keine weitere SSIS-Entwicklungswelle.

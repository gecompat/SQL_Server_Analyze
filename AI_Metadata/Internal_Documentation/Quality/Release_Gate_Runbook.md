# Releasevorbereitung und Abnahme

Die verbindliche Auswahl von Tests steht ausschließlich in der
[CI-Teststrategie](../../../Documentation/Quality/CI_Test_Strategy.md).
Dieser Ablauf dokumentiert die Umsetzung für Version 1.1.2 und die Bindung
zwischen Quellcommit, Produkt-ZIP, Laufzeitprüfung und Veröffentlichung.
Der Release ist abgeschlossen; die beschriebenen Schritte erteilen keine
erneute Ausführungsfreigabe. Historische CSV-Nachweise werden nicht umgedeutet.

## Releaseabschluss v1.1.2

[v1.1.2](https://github.com/gecompat/SQL_Server_Analyze/releases/tag/v1.1.2)
wurde am 23. Oktober 2026 um 19:15:59 Uhr Wien auf Commit
`fe24e7b496d2a1f221dbf44edfe96312dd4ed05a` veröffentlicht. PR #413 ist enthalten;
der [Main-Nachlauf](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/39975996941)
bestand auf diesem Commit. Der einmalige
[Matrixlauf 39986885609](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/39986885609)
qualifizierte dieselben ZIP-Bytes auf SQL Server 2019/CL150, 2022/CL160 und
2025/CL170 unter Linux. Je Engine bestanden 34 Release-Suiten und die native
Berechtigungsprüfung; der Cleanup ist für alle drei Engines bestätigt.
Auf SQL Server 2025 bestanden auch die vorgesehenen Zusatzverträge.
Der unabhängige Abschlussreview blieb ohne Befund. Die historischen
Lock-Timeout-Ursachen bleiben ungeklärt; Windows-SQL und nicht geprüfte
Featurepositivfälle erhalten durch diese Linux-Matrix keinen zusätzlichen Nachweis.

Veröffentlicht sind `SQL_Server_Analyze-1.1.2.zip` mit sechs fertigen Installern,
`SQL_Server_Analyze-1.1.2.zip.sha256` und
[release-evidence.json](https://github.com/gecompat/SQL_Server_Analyze/releases/download/v1.1.2/release-evidence.json).
Die ZIP-Prüfsumme lautet
`eb0944f95b227ddb5af240a3b4b327e09d299aa59033e62d1930f064a9e3045c`.
Alle drei veröffentlichten Downloads wurden gegen die qualifizierten Dateien
geprüft. Die [Restgrenzen](Next_Steps.md#abgeschlossen-release-v112) von
45 aktiven Minuten, vier Stunden Gesamtzeit und spätestens 22:00 Uhr Wien
wurden eingehalten. Ein ZIP-Bau, ein Matrixdispatch, ein Abschlussreview,
ein Tag, ein Entwurf und eine Veröffentlichung wurden verbraucht; der
Restauftrag änderte keine Repositorydateien und wiederholte keine Matrixjobs.

Die vorliegende Dokumentationsnachführung verändert weder den Releasecommit
noch Tag oder Releaseanhänge. Die Statusdokumente im ZIP bleiben auf ihrem
damaligen Zwischenstand. Frühere Nachweise und Budgets bleiben historisch
gebunden; die übrige autonome Verarbeitung bleibt pausiert. Weitere Läufe
oder Veröffentlichungen sind durch diesen Abschluss nicht freigegeben.

## STAT-DOMINANT-Diagnose (54901)

Der historische [Main-Lauf 40124510785](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40124510785)
scheiterte in Test 175 mit 54901; die Ursache bleibt UNKNOWN. Die gesonderte
Freigabe und ihre festen Grenzen stehen in [Next_Steps.md](Next_Steps.md#freigegeben-stat-dominant-fehlerdiagnose-54901).
Diese Diagnose korrigiert keine Statistikbewertung und erneuert keine Budgets.

Vor dem unveränderten Abbruch meldet Test 175 höchstens eine ASCII-Zeile mit
1.024 Zeichen und dem Präfix `Error: STAT_DOMINANT_FAILURE`. Prüfflags,
Rückgabe-/Metastatus, Partialität, natives Fehlerkennzeichen, Datenbankstatus
und Fehlernummern sowie Kandidaten-, Histogramm- und Befundwerte grenzen den
Fehler ein. Mehrfachzeilen bleiben durch Zähler und MULTIPLE sichtbar;
nur eine eindeutige native Fehlernummer wird ausgegeben. Fehlende Werte sind
NULL, unbekannte Statuswerte UNKNOWN. Freie Meldungen, Namen, Histogrammgrenzen
und vollständiges JSON werden nicht ausgegeben. Die Werte stammen nur aus
vorhandenen OUTPUT-/JSON-Werten. Diagnoseparsing ersetzt keinen nativen Fehler.

Die Fehlerzeile gelangt ohne Workflowänderung in Konsole und impact.log.
Erfolgskriterien, Schwelle 50, Fehler 54901 und Cleanup bleiben erhalten;
erfolgreiche Fachfälle erzeugen keine zusätzliche Diagnoseausgabe.
Zwölf vorgeschaltete synthetische Proben verwenden denselben Diagnoseblock
für Erfolg, NULL-/ungültiges JSON, falschen Status, fehlenden/falschen Befund,
abweichende Metrik/Schwelle, intern behandelten 1222, natives Fehlerkennzeichen,
unvollständige/mehrdeutige Daten und unerlaubte überlange Textwerte. Sie prüfen
Format und kontrollierten Abbruch; sie reproduzieren keinen Analyzerfehler.
Die acht bestehenden Fachfälle und zwölf Proben werden genau einmal in der
Head-Abnahme auf SQL Server 2025/CL170 geprüft; das Ergebnis ist noch ausstehend.

## FIND-CORE-Diagnose

Die Diagnose ist mit PR #413 abgeschlossen. Der folgende Sperrstand gehört
zur Zeit vor dessen Integration und vor der gesonderten Release-Restfreigabe.

### Historischer Sperrstand vor PR #413

PR #412 ist auf Main `73b9843a8cd799883d1b3d796992133020e38d97` integriert.
Der [Main-Nachlauf 39962487724](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/39962487724)
scheiterte mit 55200; die Ursache bleibt unbekannt. v1.1.2 ist unveröffentlicht.
Die nachfolgende Releasefreigabe ist gestoppt. Ihre Budgets und Frist werden
durch den getrennten Diagnoseauftrag in [Next_Steps.md](Next_Steps.md#freigegebener-folge-pr-find-core-diagnose)
nicht erneuert. Matrix, Paketbau und Veröffentlichung bleiben ausgesetzt.

### Diagnosevertrag und damalige Abnahme

Test 178 meldet vor 55200 höchstens eine ASCII-Zeile mit 1.024 Zeichen und
dem Präfix `Error: FIND_CORE_FAILURE`. Prüfflags, Gesamtstatus, Partialität,
Finding-Anzahl sowie Status und Fehlernummern des Agent-Moduls und der
JSON-Aggregation grenzen den Fehler ein. Nur feste Kennungen, erlaubte
Statuswerte und Zahlen werden ausgegeben; unbekannte Werte erscheinen als
`UNKNOWN`, fehlende als `NULL`. Freie Meldungen und JSON-Nutzdaten entfallen.
Die Zeile erscheint über den bestehenden CI-Pfad in Konsole und `impact.log`.
Sie belegt weder einen Blocker noch die Ursache eines intern gemeldeten Fehlers.

Die begrenzte Abnahme prüft offline die fünf erhaltenen Kriterien, Fehler
55200, Datenschutz, Ausgabegrenze und Lesepfade; ein unabhängiger Reviewer
prüft denselben Umfang. Genau eine Head-Abnahme auf SQL Server 2025/CL170
führt die betroffenen Verträge mit neun bisherigen P1-Findings-Fällen und
neun synthetischen Diagnoseeingaben aus. Die Gegenproben nutzen denselben
Prüfblock und prüfen Erfolg, NULL-/ungültiges JSON, falschen Status, null
Findings, fehlendes Agent-Modul, abgefangenen 1222, unerlaubte Finding-Felder
und Aggregationsfehler. Sie reproduzieren keinen ursprünglichen Fehler.
Unveränderte erfolgreiche Selbsttests werden nicht lokal wiederholt.
Ein Fehler stoppt ohne weiteren Head-Lauf; Abschluss ist der geprüfte PR.

## Historische Freigaben

Die folgenden Freigaben und Grenzen dokumentieren damalige Auftragsstände.
Der spätere Restauftrag ist im Releaseabschluss getrennt nachgeführt;
die früheren Grenzen erteilen keine neue Ausführungsbefugnis.

### Gestoppte Freigabe v1.1.2

Der Benutzer hat am 23. Oktober 2026 den begrenzten Releaseplan für v1.1.2
samt ZIP-Ausnahme freigegeben. Grundlage ist Analyze-Main `e307fea3` mit der
integrierten TABLE-Timeout-Diagnose aus PR #410. Version, Lieferpfade und
Versionsoracles werden aktualisiert. Der nachfolgende operative Ablauf gilt für v1.1.2.
Frühere Freigaben und Ergebnisse bleiben an ihren jeweiligen Stand gebunden.
Zusätzlich ist der begrenzte Temp-Tabellen-Fix in PR #412 freigegeben:
Nur die 25 eigenen Anlagen der Plananalyse erhalten 100 ms Sperrwartezeit;
danach und im Fehlerpfad gilt NOWAIT. Der fehlgeschlagene Head-Lauf
`39942902098` bleibt an `ffb8ffa4` gebunden; seine Sperrursache ist unbekannt.

Die Lieferung umfasst höchstens 25 Dateien und 400 handgeschriebene geänderte
Zeilen; nur die beiden kanonischen Adapterdiffs sind von der Zeilenzahl ausgenommen.
Ein Implementierer bearbeitet einen Umsetzungspass und drei begrenzte Korrekturpässe;
derselbe unabhängige Reviewer prüft insgesamt höchstens viermal.
Zulässig sind vier lokale Prüfblöcke, insgesamt drei lokale Prüfpakete, zwei
Head-Qualifikationen, ein Main-Nachlauf und genau ein Matrixdispatch mit allen
drei Engines. Die zweite Head-Qualifikation ist nur für einen geänderten
Korrekturstand vorgesehen. Der endgültige CI-Paketbau erfolgt genau einmal.
Die kanonische Rekonstruktion im Paketverifier ist eine Integritätsprüfung.
Der Temp-Fix erhält genau einen zusätzlichen lokalen Block, einen weiteren
Durchgang desselben Reviewers und die zweite Head-Qualifikation. Sein Umfang
bleibt auf neun Dateien, 200 zusätzliche Handzeilen und 60 weitere aktive
Minuten innerhalb der ursprünglichen 120 Minuten begrenzt. Die Gesamtfrist
endet unverändert am 23. Oktober 2026 um 17:45 Uhr Wien.
Lokal werden nur betroffene Verträge geprüft. Die bestehende CI führt wegen
des zentralen Releaseumfangs das Full Gate auf SQL Server 2025 aus; die neue
Fehlerprobe läuft darin mit. Unveränderte erfolgreiche Selbsttests entfallen lokal.

Die Obergrenzen betragen 120 Minuten aktive Bearbeitung einschließlich Review
und Koordination sowie fünf Stunden Gesamtzeit einschließlich Wartezeiten;
nach drei Stunden erfolgt ein Kontrollpunkt. Ein Matrixfehler, eine ungeklärte
Daten- oder Quellbindung oder eine überschrittene Grenze stoppt die Lieferung.
Zusätzliche native Läufe benötigen eine neue ausdrückliche Freigabe.
Die OPS-005-Windows-Budgets bleiben verbraucht; die übrige autonome Verarbeitung
bleibt pausiert. v1.1.0 und v1.1.1 werden weder ersetzt noch neu gebunden.

## Historische Freigabe v1.1.1

Der Benutzer hat am 23. Oktober 2026 die Integration der Dokumentationskorrektur
aus PR #409, den Paketbau mit zusätzlichem kombiniertem Deploymentinstaller
und die begrenzte Abnahme von v1.1.1 freigegeben. Die bisherigen Vorgaben
ohne neue Läufe sind ausschließlich für diese Lieferung aufgehoben:
erforderliche PR-/Main-Prüfungen, Paketbau und genau eine native Matrix mit
SQL Server 2019, 2022 und 2025. Die Schutzregeln bleiben unverändert;
der fehlende Pflichtcheck wird regulär ausgeführt. Die übrige autonome
Verarbeitung bleibt pausiert. v1.1.0, sein Tag, sein ZIP und sein Nachweis
werden weder ersetzt noch auf den neuen Quellstand umgedeutet.

Der zusätzliche Installer wird durch denselben vorhandenen Builder mit
`-IncludeSnapshotBaseline` unter einem getrennten Dateinamen erzeugt. Es
entsteht keine zweite handgeschriebene SQL-Implementierung. Der Paketvalidator
prüft alle sechs Installer gegen ihre kanonische Erzeugung und weist fehlende
oder veränderte kombinierte Artefakte zurück. Die SQL-Server-2025-Abnahme
verwendet diese unveränderte ausgelieferte Datei im bestehenden vollständigen
Deploymentvertrag. Dessen Oracles und Rollbackgegenprobe bleiben erhalten.

## Kandidat vorbereiten

Ein Releasebranch beginnt auf aktuellem `origin/main`. Frameworkversion,
ReleaseDate und Release Notes werden vor der Abnahme festgelegt; die
Vertragsversion bleibt 1.24. Nur der oben freigegebene Temp-Fix ergänzt den
Fachcode; weitere Fachänderungen sowie API- oder Plattformänderungen gehören
nicht zu dieser Konsolidierung. Die übrige autonome
Verarbeitung bleibt pausiert.

Der verantwortliche Implementierer prüft den Lesepfad vom Download über die
Installerwahl bis zu Erfolgskontrolle und Fehlerhilfe. Die unabhängige Prüfung
umfasst Paketvollständigkeit, Quellbindung, Datenschutz, unveränderten
Lizenzblock und die tatsächliche Abnahme des ausgelieferten ZIP.

## Produkt-ZIP erzeugen und prüfen

Der Paketbuilder benötigt Git, PowerShell 7 und Python 3.10 oder neuer.
Er exportiert den ausdrücklich ausgewählten Commit in ein temporäres
Verzeichnis, erzeugt dort die sechs vorhandenen Installerformate und ergänzt
`RELEASE.json`. SQL Server wird beim Build nicht aufgerufen. Die versionierten
Quellen und Unterlagen behalten ihre Pfade; Git-Verwaltungsdaten und lokale,
unversionierte Dateien werden nicht übernommen.

Für das freigegebene Produktrelease 1.1.2 gilt die gezielte Ausnahme zu
[Abschnitt 8 des Datenschutzvertrags](../Architecture/Runtime_Data_and_Repository_Privacy.md#8-prüfvertrag-vor-commit-und-zip):
Der ZIP-Root lautet `SQL_Server_Analyze-1.1.2`. Ausschließlich diese sechs
generierten Dateien unter `Code/Install/generated` sind zusätzlich zulässig:

- `Install_All.generated.sql`
- `Deploy_All.generated.sql`
- `Install_ExecutionPlanAnalysis.generated.sql`
- `Install_SnapshotBaseline_Target.generated.sql`
- `Install_SnapshotBaseline_Framework.generated.sql`
- `Deploy_All_WithSnapshotBaseline.generated.sql`

Die Ausnahme setzt den vollständigen Vergleich der Quellbytes mit dem exakten
Git-Commit, die unabhängige Rekonstruktion aller sechs Installer und deren
strikten Bytevergleich voraus. Sämtliche Originalquellen bleiben der
Datenschutzprüfung unterworfen; andere generierte Dateien bleiben verboten.
Der normale CLI-Aufruf des Datenschutzvalidators behält seinen bisherigen
ZIP-Vertrag. Der Releaseweg verwendet dafür ausschließlich den nachstehenden
Paketverifier. Diese Ausnahme erweitert keine Daten- oder Laufzeitfreigabe.

```powershell
./Code/Install/Build-ReleasePackage.ps1 -RepositoryRoot . -Revision HEAD `
    -OutputDirectory 'C:/Temp/SQL_Server_Analyze_Release' -PythonExecutable python
python ./Code/Tests/Static/Validate_Release_Package.py --repository-root . `
    --archive 'C:/Temp/SQL_Server_Analyze_Release/SQL_Server_Analyze-1.1.2.zip'
```

Die Prüfung verlangt den vollständigen Dateibestand des ausgewählten
Git-Commits, identische Quellbytes einschließlich Lizenz und README sowie
bytegleich kanonisch erneut erzeugbare Installer im Format UTF-8 ohne BOM
mit LF-Zeilenenden. Zusätzlich werden Inventar, Version,
Paketpfade, Prüfsumme und Datenschutz geprüft. Ein Fehler verhindert jede
Übernahme des Pakets in die Releaseveröffentlichung. Die normale statische
Prüfung und die Selbsttests geänderter Validatoren bleiben erforderlich;
ein bereits identischer erfolgreicher Prüfstand wird nicht erneut ausgeführt.

## Reguläre Integration

Der stabile Kandidat wird per PR mit den erforderlichen aktuellen Head-Gates
integriert. Der Merge-Tree und der Main-Nachlauf werden geprüft. Vor der
nativen Releasequalifikation wird der beabsichtigte Main-Commit festgehalten.
Die spätere Workflowausführung muss genau diesen Commit als `headSha` haben.
Ein abweichender Commit wird nicht stillschweigend als gleichwertig behandelt.

## Native Releasequalifikation

Der manuelle Workflow
[release-native-matrix.yml](../../../.github/workflows/release-native-matrix.yml)
wird für einen Release Candidate genau einmal mit `target=all` gestartet.
Er baut und prüft das Produkt-ZIP einmal und verteilt dieselben durch SHA-256
gebundenen Bytes an die drei nacheinander laufenden Enginejobs:

| Engine | Compatibility Level | Gemeinsamer Umfang |
|---|---|---|
| SQL Server 2019 | 150 | Installation aus dem Produkt-ZIP, vollständiges Release-Gate, native Berechtigungsprüfung |
| SQL Server 2022 | 160 | Installation aus dem Produkt-ZIP, vollständiges Release-Gate, native Berechtigungsprüfung |
| SQL Server 2025 | 170 | Installation aus dem Produkt-ZIP, vollständiges Release-Gate, native Berechtigungsprüfung |

Auf SQL Server 2025 folgen die erforderlichen Regex-, Deployment-,
Erhaltungs-, Snapshot-/Nebenläufigkeits- und Standalone-Verträge. Die
Runtimekopie ersetzt ausschließlich generische Datenbankplatzhalter und
leitet die vorhandenen Standalone- und Snapshot-Tests auf die mitgelieferten
fertigen Installer um. Das ursprüngliche Produkt-ZIP wird dabei nicht verändert.

Das Release-Gate muss bis zu seinem Abschlussresultset mit `AVAILABLE`,
`IsPartial=0` und `ExecutedSuites=34` gelangen. Begleitverträge bleiben im
Runner enthalten. Jeder erforderliche SQL- oder Shellschritt muss erfolgreich
abschließen. Der Cleanup entfernt ausschließlich den über Container-ID und
Laufkennung gebundenen eigenen Container und prüft dessen Abwesenheit.
Eine fehlgeschlagene oder unklare Bereinigung verhindert einen Erfolgsnachweis.

Es werden nur synthetische CI-Datenbanken verwendet. Eine Einzelversionsprobe
ist weiterhin für einen gezielten Versionsbefund möglich, qualifiziert aber
kein vollständiges Release. Ein fehlgeschlagener Matrixlauf wird innerhalb
dieses Releaseumfangs nicht wiederholt. Historisch erlaubte der ausdrücklich
freigegebene Korrekturschritt für v1.1.0 nach PR #407 einmalig eine neue vollständige Matrix
auf dem korrigierten Main-Commit. Der
[ursprüngliche Lauf](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/39793329967)
bleibt fehlgeschlagen. Die Erneuerung betrifft die korrigierten Backuporacles
und die Isolation der Calleroptionen von Test 198; alle übrigen Prüfungen
behalten ihren Umfang. Die Bindung an ein neues unverändertes Produkt-ZIP
und dessen Main-Commit erfordert eine vollständige Releasequalifikation.
Der neue v1.1.2-Kandidat erhält die oben gesondert freigegebene eine Matrix;
die historischen v1.1.0-Ergebnisse bleiben auf ihrem ursprünglichen Stand.

## Nachweis und Aussagegrenze

`release-evidence.json` wird erst nach erfolgreichen Enginejobs und geprüftem
Cleanup erzeugt. Es nennt Version, Quellcommit, Paketprüfsumme, tatsächliche
Buildkomponenten, Plattform, Compatibility Level, Collation, Image-Digest,
Prüfumfang und öffentliche Laufreferenz. Buildkomponenten sind technische
Nachweisdaten; sie beschränken die Installation nicht auf einen bestimmten
Build oder CU. Die dokumentierten Feature-, Berechtigungs- und Plattformgrenzen
bleiben erhalten. Windows-SQL und Featurepositivfälle erhalten durch diese
Linux-Matrix keinen zusätzlichen Nachweis.

Vollständige SQL-Ausgaben, Kennwörter, Resultsets und lokale Hostdaten gelangen
nicht in Releaseartefakte. Temporäre CI-Artefakte bleiben auf einen Tag
Retention begrenzt. Das Produkt-ZIP darf höchstens 128 MiB, sein entpackter
Inhalt höchstens 512 MiB und der zusammengeführte Nachweis höchstens 256 KiB
umfassen. Historische Nachweise bleiben auf ihrem ursprünglichen Commit.

## Veröffentlichung

Nach erfolgreicher Matrix werden der Workflowstatus, alle Zielversionen,
Source-SHA und Paketprüfsumme geprüft. Der Tag `v1.1.2` wird auf genau diesen
getesteten Main-Commit gesetzt. Ein vorhandener abweichender Tag oder ein
bereits abweichend veröffentlichtes Paket wird nicht überschrieben.

Ein GitHub-Releaseentwurf erhält das unveränderte Produkt-ZIP, dessen
`.sha256`-Datei, `release-evidence.json` und verständliche Release Notes mit
Installationsweg und Einschränkungen. Erst nach der abschließenden Bindungs-
und Datenschutzprüfung wird der Entwurf veröffentlicht. Die zusätzlich von
GitHub angebotenen Quellarchive ersetzen das Produkt-ZIP mit fertigen
Installern nicht. Der gesamte Vorgang verwendet die bestehende Lizenz;
der geschützte README-Lizenzblock bleibt unverändert.

## Begrenzung und Verarbeitungsaufwand

Dieser Abschnitt hält den ursprünglichen Planungsstand von PR #412 fest.
Das spätere Restbudget steht im Releaseabschluss; die
nachfolgenden historischen Grenzen werden weder ersetzt noch erneuert.

Ein Implementierer verantwortet den Schritt. Ein unabhängiger Reviewer prüft
höchstens viermal; der letzte Korrekturpass betrifft nur Validator und Budgettexte (20 geänderte Zeilen, 15 aktive Minuten innerhalb der 60).
Vier lokale Prüfblöcke, höchstens zwei Head-
Qualifikationen, ein Main-Nachlauf und genau eine native Matrix begrenzen die
Ausführung. Der aktuelle v1.1.2-Schritt umfasst höchstens 25 Dateien und 400 handgeschriebene geänderte Zeilen.
Die aktive Bearbeitung einschließlich Review und Koordination bleibt auf 120 Minuten begrenzt.
Nach drei Stunden erfolgt ein Kontrollpunkt, nach fünf Stunden
Gesamtzeit beginnt keine neue Arbeit. Sicherheits- und Recoveryaktionen
bleiben zulässig; ein offenes Gate wird nicht als bestanden ausgewiesen.

Die regulären PR-/Main-Gates bleiben erhalten, weil lokale Evidenz derzeit
keinen vertrauenswürdigen Remote-Verifikator besitzt. Der native Releaseweg
bleibt manuell und erzeugt keine zusätzliche automatische Matrix. Ein
Paketbau versorgt alle drei Engines; die erneute kanonische Erzeugung bei der
ZIP-Prüfung dient der Integrität der fertigen Installer. Kompakte Metadaten
ersetzen die Weitergabe vollständiger Logs. Mechanische Bindungen werden
lokal geprüft; ein erfolgreicher Lauf benötigt keine weitere Modellbestätigung.
Weitere Produktkorrekturen, native Wiederholungen oder Reviewerketten sind
kein Bestandteil dieses Releaseumfangs.

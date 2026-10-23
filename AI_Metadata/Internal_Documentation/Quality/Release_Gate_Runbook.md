# Releasevorbereitung und Abnahme

Die verbindliche Auswahl von Tests steht ausschließlich in der
[CI-Teststrategie](../../../Documentation/Quality/CI_Test_Strategy.md).
Dieser Ablauf beschreibt die Umsetzung für Version 1.1.1 und die Bindung
zwischen Quellcommit, Produkt-ZIP, Laufzeitprüfung und Veröffentlichung.
Historische CSV-Nachweise werden dadurch nicht umgedeutet.

## Freigegebene Ergänzung v1.1.1

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
Vertragsversion bleibt 1.24. Änderungen an Fachcode, APIs oder unterstützten
Plattformen gehören nicht zu dieser Konsolidierung. Die übrige autonome
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

Für das freigegebene Produktrelease 1.1.1 gilt die gezielte Ausnahme zu
[Abschnitt 8 des Datenschutzvertrags](../Architecture/Runtime_Data_and_Repository_Privacy.md#8-prüfvertrag-vor-commit-und-zip):
Der ZIP-Root lautet `SQL_Server_Analyze-1.1.1`. Ausschließlich diese sechs
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
    --archive 'C:/Temp/SQL_Server_Analyze_Release/SQL_Server_Analyze-1.1.1.zip'
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
Der neue v1.1.1-Kandidat erhält die oben gesondert freigegebene eine Matrix;
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
Source-SHA und Paketprüfsumme geprüft. Der Tag `v1.1.1` wird auf genau diesen
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

Ein Implementierer verantwortet den Schritt. Ein unabhängiger Reviewer prüft
höchstens zweimal; ein gebündelter Korrekturpass bleibt innerhalb der
freigegebenen Dateien. Zwei lokale Prüfblöcke, höchstens zwei Head-
Qualifikationen, ein Main-Nachlauf und genau eine native Matrix begrenzen die
Ausführung. Der aktuelle v1.1.1-Schritt umfasst höchstens 24 Dateien.
Nach drei Stunden erfolgt ein Kontrollpunkt, nach vier Stunden
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

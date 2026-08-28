# Lab – Diagnose-Szenarien und Orchestrierung

Dieses Verzeichnis enthält die analyserspezifischen Szenarien, Verträge und Orchestrierungslogik des `SQL_Server_Analyze`-Frameworks. Die Szenarien erzeugen gezielt synthetische Zustände, die mit den zugeordneten Analyze-Procedures beobachtet und anhand stabiler Invarianten geprüft werden können.

## SQL-Server-Testumgebung bereitstellen

Die allgemeine Erzeugung und Verwaltung von SQL-Server-Laborumgebungen (Docker, Hyper-V, Podman) liegt im zentralen Repository:

[`gecompat/SQL_Server_Lab`](https://github.com/gecompat/SQL_Server_Lab)

Dort befinden sich:

- die Ad-hoc-Erstellung von SQL-Server-Instanzen mit Docker oder Hyper-V;
- das Lifecycle-Management für Start, Stop, Status und Entfernung;
- Ressourcenprofile und Host-Assessment;
- Netzwerk- und I/O-Simulationen; und
- die scope-sichere Deinstallation.

`SQL_Server_Analyze` verwendet die bereitgestellten Instanzen, implementiert aber keine zweite allgemeine Infrastruktur-Orchestrierung. Fehlende allgemeine Lab-Funktionen werden als konkreter Änderungsvorschlag für `SQL_Server_Lab` beschrieben und nicht stillschweigend in diesem Repository ergänzt.

## Verzeichnisstruktur

| Pfad | Inhalt |
| --- | --- |
| `Contracts/` | JSON-Schemas für Szenarien, Findings, Evidenz und Runbooks |
| `Orchestration/` | DiagnosticLab-PowerShell-Modul für die Szenarioausführung |
| `Scenarios/` | Analyse-Szenarien (Core, Performance, Infrastructure) |
| `Validation/` | Wave-Tests und Fixture-Dateien |
| `Update-Framework.ps1` | Framework-Update in bestehender Instanz |
| `Run-LogShipping-Lab.ps1` | LogShipping-Szenario-Starter |

## Ergänzende Testdaten und Lastwerkzeuge

Die mitgelieferten Szenarien und ihre synthetischen Daten bleiben die kanonische Grundlage für reproduzierbare Findings, Regressionstests und Lernpfade. Externe Beispieldatenbanken oder Lastwerkzeuge sind optional. Sie eignen sich für explorative Skalierungs- und Gegenprüfungen, ersetzen aber weder die Szenarioverträge noch die verbindliche CI-Testauswahl.

| Testziel | Geeignete Ergänzung | Einsatzgrenze |
| --- | --- | --- |
| SQL-Server-Funktionen und unterschiedliche Schemamuster untersuchen | [Microsoft SQL Samples](https://learn.microsoft.com/en-us/sql/samples/sql-samples-where-are?view=sql-server-ver17), insbesondere AdventureWorks und WideWorldImporters | Die Datenbank wird nur lokal in einer isolierten Lab-Umgebung verwendet. Edition, Featurevoraussetzungen und Restoreformat sind vor dem Lauf zu prüfen. |
| Eine synthetische Abfrage mit definierter Parallelität wiederholen | [SQLQueryStress und `sqlstresscmd`](https://github.com/ErikEJ/SqlQueryStress) oder [RML Utilities mit OStress](https://learn.microsoft.com/en-us/troubleshoot/sql/tools/replay-markup-language-utility) | Query, Parameter und Verbindungsoptionen müssen synthetisch und versioniert sein. Replays aus realen Umgebungen sind keine zulässigen Repositoryartefakte. |
| Transaktionale oder analytische Mischlast erzeugen | [HammerDB](https://www.hammerdb.com/docs/) mit TPROC-C oder TPROC-H | Der Lauf dient der explorativen Lastbeobachtung. Er ist kein offizielles TPC-Ergebnis und liefert ohne einen projektspezifischen Szenariovertrag keinen stabilen Finding-Nachweis. |
| Storage- oder Netzwerkgrenzen untersuchen | [DiskSpd](https://github.com/microsoft/diskspd) beziehungsweise [Toxiproxy](https://github.com/Shopify/toxiproxy) | Diese Werkzeuge dürfen nur in einer dafür isolierten Infrastruktur eingesetzt werden. Bereitstellung, Ressourcen- und Fehlerprofile bleiben Aufgabe von `SQL_Server_Lab`. |

Bei der Auswahl gilt folgende Reihenfolge:

1. Ein vorhandenes `Lab/Scenarios`-Szenario wird verwendet, wenn es den benötigten Zustand bereits reproduzierbar erzeugt.
2. Ein externes Werkzeug wird nur ergänzt, wenn Datenvolumen, Parallelität oder Infrastrukturverhalten mit dem vorhandenen Szenario nicht ausreichend untersucht werden kann.
3. Datenbasis, Toolversion, Lastparameter, Ramp-up, Laufzeit und relevante SQL-Server-Konfiguration werden für vergleichbare Messungen festgehalten.
4. Externe Werkzeuge und Datensätze werden nicht automatisch installiert, nicht als Frameworkabhängigkeit behandelt und nicht durch die normale CI vorausgesetzt.
5. Funktionale CI-Läufe und native Versionsprüfungen werden weiterhin ausschließlich nach der [verbindlichen CI-Teststrategie](../Documentation/Quality/CI_Test_Strategy.md) ausgewählt.

## Sicherheits- und Evidenzgrenzen

Absichtlich erzeugte Blockaden, Deadlocks sowie CPU-, Speicher-, Netzwerk- oder I/O-Lasten dürfen nur auf einer wegwerfbaren und isolierten Testumgebung ausgeführt werden. Produktive Datenbanken, gemeinsam verwendete SQL-Server-Instanzen, Replikate sowie produktive Daten-, Log- und Backupvolumes sind dafür ungeeignet. Jeder Lauf benötigt begrenzte Laufzeit und Parallelität sowie einen definierten Abbruch- und Cleanup-Pfad.

In Repositoryartefakte dürfen ausschließlich synthetische Daten und generische, auf das notwendige Maß begrenzte Evidenz eingehen. Externe Datensätze, Backups, Replaydateien, Extended-Events-Ausgaben, Performance-Logs, Verbindungsdaten und vollständige Toolausgaben werden nicht eingecheckt. Diagnosewerkzeuge außerhalb des Frameworks können als Gegenprüfung dienen; ihre Ausgabe ist jedoch kein Ersatz für die im Szenario definierten Analyze-Invarianten.

## Workflow

1. Stellen Sie die SQL-Server-Umgebung mit `SQL_Server_Lab` bereit.
2. Installieren Sie das Framework über den Adapter oder `Update-Framework.ps1`.
3. Führen Sie die Szenarien mit `Orchestration/Invoke-DiagnosticLab.ps1` aus.
4. Validieren Sie die Ergebnisse mit dem zutreffenden Skript unter `Validation/`.
5. Entfernen Sie die Umgebung über `SQL_Server_Lab`.

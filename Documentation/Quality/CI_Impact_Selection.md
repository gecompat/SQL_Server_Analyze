# CI-Impact-Auswahl

Die Pull-Request-Prüfungen unterscheiden repositoryweite Schutzregeln, statische Verträge, impact-basierte SQL-Server-Laufzeitverträge und manuelle native Versionsnachweise. Der verbindliche Umfang steht in [Verbindliche CI-Teststrategie](CI_Test_Strategy.md).

## Repositoryweite Prüfungen

Repository-Datenschutz und Commit-Message-Validierung bleiben repositoryweit. Diese Prüfungen schützen den vollständigen Lieferbaum beziehungsweise den eingeführten Commitbereich und werden deshalb nicht aus SQL-Objektabhängigkeiten ausgewählt.

## Dokumentation und Metadata

Dokumentations- und Metadata-Prüfungen laufen ohne SQL-Server-Instanz. Der externe Linkcheck mit Netzwerkzugriff läuft nur, wenn eine Änderung eine HTTP(S)-Referenz einführt oder verändert, wenn der Validator selbst geändert wird oder wenn der Workflow manuell vollständig gestartet wird.

Die statische Vertragssuite verwendet für reine Foundation- und Regelkontextänderungen einen eng begrenzten Governance-Scope mit Dokumentationsstil- und Regelkontextprüfung. Alle anderen Änderungen fallen auf die vollständige statische Suite zurück, solange ihre Validatorabhängigkeiten nicht enger belegt sind. Der Workflow führt Validator-Selbsttests nur bei Änderungen am betreffenden Prüfwerkzeug oder dessen Abhängigkeiten aus; der manuelle vollständige Lauf behält alle Selbsttests. Datenschutzscan und Commit-Prüfung bleiben eigenständige repositoryweite Gates und werden nicht zusätzlich durch den Dokumentationsworkflow wiederholt.

Eine reine Dokumentations-, Kommentar- oder Metadata-Änderung startet keinen funktionalen SQL-Server-Lauf, sofern sie keinen ausführbaren Laufzeitvertrag ändert.

## Ausführbares T-SQL

`Code/Tests/Static/925_Select_CI_Impact.py` vergleicht Basis- und Zielrevision. Der Selector entfernt SQL-Kommentare und normalisiert Formatierung außerhalb von Literalen und geklammerten Identifiern. Bleibt die ausführbare Darstellung eines SQL-Skripts unverändert, wird die Änderung als rein dokumentierend behandelt.

Bei ausführbaren Änderungen führt der Selector folgende Schritte aus:

1. geänderte Objekte in den Schemas `monitor` und `snapshot` ermitteln;
2. umgekehrte Abhängigkeiten aus dem Produktionscode bilden;
3. transitiv abhängige Objekte ergänzen;
4. Tests mit Verweisen auf betroffene Objekte auswählen;
5. den betroffenen Bereichstest und den Core-Smoke-Test ergänzen; und
6. Berechtigungs-, Regex-, Standalone-, Snapshot- und Concurrency-Verträge nur bei passendem Impact auswählen.

Kann eine Produktionsänderung nicht sicher zugeordnet werden oder betrifft sie Setup, zentralen Installer, Impact-Selector oder funktionale Workflow-Infrastruktur, verwendet der Selector das vollständige funktionale Gate auf der primären SQL-Server-2025-Engine.

Die feste [AgentHistory-Fixture](../../TestLab/Scenarios/OPS-008/agent-history.sql)
besitzt den zusätzlichen Core-Schalter `ops008_agent_history`. Eine Änderung
dieser Fixture wählt den vorhandenen
[MSDB-Laufzeitvertrag](../../Code/Tests/ServerHealth/122_OPS008_Msdb_Health_Runtime_Contract.sql)
und den Fixturelauf auf SQL Server 2025; sie fordert keine weitere Engine
oder Compatibility-Level-Matrix an. Die Änderung des funktionalen Workflows
aktiviert zusätzlich dessen eigene Fixtureprüfung und behält das vollständige
SQL2025-Gate. Unbeteiligte TestLab-Fixtures aktivieren diesen Pfad nicht.

Der zusätzliche Lauf erfolgt einmal nach dem Core-Pfad auf dessen bestehender
CL170-Testdatenbank und vor der getrennten Execution-Plan-Standaloneprüfung,
die diese Datenbank anschließend neu aufbaut. Er verlangt den festen
Datenbanknamen, Engine 17, CL170, die beiden benötigten Agent-Procedures,
einen neuen Wegwerfmarker und die vorhandenen Leerstands- und Quellschutzgates.
Er verwendet den bereits eigenen CI-Container und führt keinen Agent-Job aus.
Die vollständigen Fixturelogs bleiben temporär auf dem Runner. Im Fehlerfall
werden ausschließlich feste Fehlerstufen und freigegebene SQL-Fehlercodes
mit synthetischer Fallnummer ausgegeben. Geschlossene Zeilenmengenkategorien,
Schlüsselstrukturstatus und eine auf 17 Bit begrenzte bekannte Feldmaske
können die Diagnose ergänzen; Zeilenwerte bleiben ausgeschlossen. Diese
Diagnose ersetzt keine Ursachenabnahme. Der feste Erfolgsmarker folgt erst
nach erfolgreichem SQLCMD-Abschluss. Der bestehende Containercleanup bleibt auch bei Fehlern aktiv.

Der funktionale Workflow wertet die Scopes `core` und `snapshot` getrennt aus.
Bereits ein erforderlicher Lauf in einem der beiden Scopes startet die
SQL-Server-2025-Runtime. Für Snapshot-Impact erstellt der Workflow nach dem
Core-Lauf eine frische Framework- und Snapshot-Zieldatenbank, installiert den
Core und führt dessen Smoke-Test sowie den ausgewählten Snapshot-Vertrag aus.
Der Concurrency-Vertrag startet einen eigenen Lockhalter und prüft vor der
zweiten Session, dass die Anwendungssperre tatsächlich gehalten wird. Das
abschließende Gate verlangt auch für reinen Snapshot-Impact einen erfolgreichen
Runtimejob. Die Datenbanken verbleiben ausschließlich im Testcontainer; dessen
Cleanup läuft über den vorhandenen `always()`-Schritt.

## Sperrdiagnose für die synthetischen SSIS-Verträge

Die Verträge 202 bis 207 melden Datei, Aufrufstelle, laufende Aufrufnummer,
vorhandene Schleifenwerte, UTC-Zeit, Session-ID und aktuellen Lock-Timeout
vor dem Aufruf. Ein Folgemarker mit eigener UTC-Zeit kennzeichnet den Eintritt
in die Assertions; der Dateiende-Marker beendet die Beobachtung. Der
Dateistartmarker steht in einem eigenen, mit `GO` abgeschlossenen Batch.
Die Meldungen erzeugen keine
zusätzlichen fachlichen Resultsets und verändern keine Sessionoptionen.
Der Testprozess verwendet `sqlcmd -r 1` und liest Meldungen über stderr
getrennt von stdout-Ergebniszeilen. `stdbuf -o0 -e0` deaktiviert die
Standardkanalpuffer des Clients im vorhandenen Linux-Container. Fehlt dieses
Werkzeug, bleibt dessen Startfehler als fehlgeschlagener Test sichtbar.
Ein lokaler Transportvergleich mit dem tatsächlichen Linux-SQLCMD zeigt,
dass Meldungen desselben Batches trotz dieser Einstellungen gemeinsam am
Batchende eintreffen können. Der abgeschlossene Startbatch liefert die
Session-ID vor dem Testbatch und startet damit die Erfassung. Lange oder
unvollständige Ergebniszeilen können deshalb keine Fallmarker verschlucken.
Beide Kanäle verwenden getrennte Decoder und Geheimnispuffer, aber eine
gemeinsame Größenbegrenzung für das bereinigte Log.

`CI_LockTimeout_Diagnostics.py` verwendet im isolierten SQL-Server-2025-
Container eine zusätzliche SQLCMD-Verbindung mit den vorhandenen CI-Rechten.
Der Beobachter liest ausschließlich Requests und Sperren der markierten
Session und ihrer direkten Blocker. Schlafende Blocker können über ihre
gehaltenen Sperren sichtbar bleiben. SQL-Texte und Verbindungsidentitäten
werden nicht zusätzlich gesammelt. Die Ressourcenidentität umfasst alle
Ressourcenfelder aus `sys.dm_tran_locks`, einschließlich Datenbank und Partition.
Die Stichproben sind keine atomare oder vollständige Sperrhistorie.

Abfragen beginnen frühestens alle 250 Millisekunden. Der Beobachter endet
spätestens nach zehn Minuten und behält höchstens 40 Stichproben der letzten
zehn Sekunden mit jeweils 200 Zeilen. Jede Stichprobe enthält zusätzlich die
UTC-Zeit des SQL-Servers vor der DMV-Abfrage. Neben der direkten Meldung 1222
erkennt der Beobachter den vom TABLE-Writer umverpackten Lock-Timeout:
Auf Meldung 51010 muss unmittelbar die Fehlermeldung mit dem festen Präfix
`TABLE-Ausgabe fehlgeschlagen (LOCK_TIMEOUT):` folgen. Der Bericht unterscheidet
`SQL_ERROR_1222` und `TABLE_EXPORT_LOCK_TIMEOUT` als Auslöser. Andere
51010-Fehler oder eine isolierte gleichlautende Textzeile reichen nicht aus.
Für den Blockernachweis werden nur
Stichproben derselben Session berücksichtigt, deren Serverzeit strikt nach
der Startzeit der zuletzt gemeldeten Aufruf- oder Assertionsphase liegt.
Gleiche Zeitwerte reichen als Reihenfolgenachweis nicht aus.
Der Vergleich erhält alle sieben Nachkommastellen. Damit können verspätete
Fallmarker bereits erfasste Stichproben zuordnen. Frühere oder zeitgleiche
Samples derselben Session bleiben mit `case: null` als unzugeordneter Kontext
erhalten und begründen keinen Blockernachweis für die letzte Phase.
Andere Sessions und abgelaufene Stichproben werden ausgeschlossen. Die ursprünglich
beim Erfassen bekannte Phase bleibt als `sampled_case` erkennbar. Ein Sample,
das eine Phasengrenze überlappt, kann konservativ unberücksichtigt bleiben.
`BLOCKER_NOT_CAPTURED` bedeutet
„Blocker nicht erfasst“; insbesondere ein sofortiger oder kurzer Timeout
kann zwischen Stichproben liegen. Eine fehlende Beobachtung belegt keinen
fehlenden Blocker. Fehler des Beobachters und abgeschnittene Stichproben
werden gesondert ausgewiesen; der ursprüngliche SQLCMD-Fehler bleibt erhalten.

Bei einem fehlgeschlagenen Impact-Lauf oder einem Erfassungsfehler sichert der
Workflow das bereinigte SQLCMD-Log und die Diagnose vor dem Container-Cleanup.
Das Log ist auf 44 MiB, die strukturierte Diagnose auf 5 MiB begrenzt; die
synthetische Abnahme verwendet höchstens 1 MiB. Größenüberschreitungen werden
als unvollständig ausgewiesen. Zugangsdaten werden auch über Lesepuffergrenzen
hinweg entfernt. Das Artefakt bleibt einen Tag erhalten. Ein erfolgreicher
gewöhnlicher Lauf erzeugt kein Diagnoseartefakt.

Änderungen an Beobachter oder Abnahmedatei aktivieren das vollständige
funktionale Gate auf SQL Server 2025. Die synthetische Sperrabnahme läuft nur
bei betroffener CI-Infrastruktur in Pull Requests, im vorhandenen Container
und mit einer Grenze von 60 Sekunden. Sie prüft einen bekannten schlafenden
Lockhalter, den direkten Fehler 1222, dessen Übersetzung zu Fehler 51010,
die vollständige Sperrressource, einen Soforttimeout, einen
erfolgreichen Aufruf und die Bereinigung. Eine zusätzliche Engine, ein
SSIS-Paket oder eine neue Python-Abhängigkeit wird dafür nicht benötigt.
Die separate Cleanupverbindung prüft nach dem Schließen des Halters auch bei
einer fehlgeschlagenen Assertion die Probe-Tabelle und die bekannte Halter-ID.
Ein solcher Cleanupfehler ersetzt den ursprünglichen Abnahmefehler nicht.

## Compatibility-Level-Auswahl

Der Selector aktiviert die Compatibility-Level-Matrix, wenn ausführbarer Code unter `Code/09_VersionAdaptive/`, ein Test unter `Code/Tests/VersionAdaptive/` oder ein expliziter Marker `CI: COMPATIBILITY_LEVELS=150,160,170` betroffen ist.

`.github/workflows/ci-functional-impact.yml` verwendet dafür eine SQL-Server-2025-Instanz und führt die ausgewählten Tests nacheinander mit Compatibility Level 150, 160 und 170 aus. Ohne dieses Risiko gilt ausschließlich Compatibility Level 170. Ein Pull Request kann ein nicht automatisch erkennbares Risiko zusätzlich ausdrücklich klassifizieren.

Compatibility Level 150 oder 160 auf SQL Server 2025 ist kein Nachweis für eine native SQL-Server-2019- oder SQL-Server-2022-Engine.

## Native Versionsprüfung

Ein ausführbarer Core-Change wird nicht automatisch auf allen unterstützten SQL-Server-Versionen ausgeführt. Native SQL-Server-2019- oder SQL-Server-2022-Läufe erfolgen gezielt bei Engine-Risiko. Die vollständige native Matrix ist ein manuelles Release-Candidate-Gate unter `.github/workflows/release-native-matrix.yml`.

## Aktive Zuordnung

- `.github/workflows/documentation-validation.yml`: impact-basierte statische Dokumentations- und Contract-Prüfung;
- `.github/workflows/ci-functional-impact.yml`: automatische funktionale 2025-Prüfung;
- `.github/workflows/release-native-matrix.yml`: manuelle native Versionsprüfung.

Gelöschte frühere Release-Gate- oder Pilot-Workflows sind keine gültigen Ziele des Selectors.

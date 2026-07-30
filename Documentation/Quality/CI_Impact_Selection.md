# CI-Impact-Auswahl

Die Pull-Request-Prüfungen unterscheiden repositoryweite Schutzregeln, statische Verträge, impact-basierte SQL-Server-Laufzeitverträge und manuelle native Versionsnachweise. Der verbindliche Umfang steht in [Verbindliche CI-Teststrategie](CI_Test_Strategy.md).

## Repositoryweite Prüfungen

Repository-Datenschutz und Commit-Message-Validierung bleiben repositoryweit. Diese Prüfungen schützen den vollständigen Lieferbaum beziehungsweise den eingeführten Commitbereich und werden deshalb nicht aus SQL-Objektabhängigkeiten ausgewählt.

## Dokumentation und Metadata

Dokumentations- und Metadata-Prüfungen laufen ohne SQL-Server-Instanz. Der externe Linkcheck mit Netzwerkzugriff läuft nur, wenn eine Änderung eine HTTP(S)-Referenz einführt oder verändert, wenn der Validator selbst geändert wird oder wenn der Workflow manuell vollständig gestartet wird.

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

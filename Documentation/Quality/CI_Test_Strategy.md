# Verbindliche CI-Teststrategie

**Status:** verbindlich  
**Geltungsbereich:** Testauswahl, CI-Workflows und Laufzeitnachweise  
**Maschinenlesbare Policy:** `Metadata/Quality/CI_Test_Policy.csv`

## Maßgeblichkeit

Dieses Dokument ist die einzige normative Quelle für den Umfang automatischer Tests. Projektanweisungen und interne Arbeitskontexte verweisen auf diese Strategie und dürfen keinen abweichenden Testumfang festlegen.

`Documentation/Quality/Test_Matrix.md`, `Metadata/Quality/Test_Matrix.csv` und `Metadata/Quality/Release_Gate_Evidence.csv` dokumentieren historische Ausführungsnachweise. Ein historischer Nachweis aktiviert keine CI-Matrix und verpflichtet nicht dazu, dieselbe Kombination bei jeder Änderung erneut auszuführen.

## Ziel

Die CI soll Fehler früh erkennen, ohne jede unterstützte SQL-Server-Version und jede Testsuite bei jeder Änderung auszuführen. Eine vollständige Kombination aller Versionen, Plattformen, Compatibility Levels, Berechtigungen und Features ist weder wirtschaftlich noch ein vollständiger Qualitätsnachweis.

Die Testauswahl folgt deshalb dem Modell **1+0+N**:

- **1:** Eine primäre SQL-Server-2025-Instanz führt die für die Änderung relevanten funktionalen Tests aus.
- **0:** Eine gewöhnliche Änderung startet keine zusätzliche native SQL-Server-Version.
- **N:** Zusätzliche Compatibility Levels, native SQL-Server-Versionen oder Plattformen werden nur bei einem konkreten, dokumentierten Risiko oder für einen Release Candidate geprüft.

## Verbindliche Auswahlregeln

| Änderungsklasse | Verbindliche Prüfung |
|---|---|
| Dokumentation oder Kommentare ohne ausführbare SQL-Änderung | Betroffene statische Dokumentations-, Metadata- und Contract-Validatoren; keine SQL-Server-Instanz |
| Metadata oder maschinenlesbarer Vertrag | Betroffener Validator; funktionale Tests nur bei geändertem Laufzeitvertrag |
| Generisches ausführbares T-SQL | SQL Server 2025 mit Compatibility Level 170; Framework-Smoke-Test sowie direkt und transitiv betroffene Tests |
| Compatibility-sensitive Änderung | Dieselbe SQL-Server-2025-Instanz mit den erforderlichen Compatibility Levels aus 150, 160 und 170; nur betroffene Tests |
| Änderung mit nativem Versionsrisiko | Betroffene Tests zusätzlich auf exakt den erforderlichen nativen Engines 2019 und/oder 2022 |
| Zentraler Installer, Setup, Impact-Selector oder funktionaler Workflow | Vollständiges funktionales Gate auf SQL Server 2025; keine automatische native Drei-Versionen-Matrix |
| Release Candidate | Vollständige native Linux-Matrix für SQL Server 2019, 2022 und 2025 |
| Windows-spezifischer Code oder Windows-only Featurepfad | Gezielter manueller Lauf über den dafür vorgesehenen SQL_Server_Lab- oder Remote-Runner-Pfad |

Ein Full Gate auf SQL Server 2025 und eine native Drei-Versionen-Matrix sind unterschiedliche Prüfungen. Das Full Gate erweitert den Testumfang auf der primären Engine. Die native Matrix erweitert die Zahl physischer SQL-Server-Versionen und bleibt ein separates, manuelles Release- oder Risikogate.

## Impact-Auswahl

`Code/Tests/Static/925_Select_CI_Impact.py` ist die kanonische Auswahlkomponente für funktionale Pull-Request-Tests. Der Selector:

1. unterscheidet reine Kommentar- oder Formatänderungen von ausführbaren SQL-Änderungen;
2. ermittelt geänderte Frameworkobjekte;
3. verfolgt umgekehrte Abhängigkeiten transitiv;
4. wählt direkt betroffene Tests;
5. ergänzt den Framework-Smoke-Test und den betroffenen Bereichstest;
6. aktiviert Spezialverträge nur bei passendem Impact; und
7. fällt bei nicht sicher zuordenbaren Produktionsänderungen auf das Full Gate der primären Engine zurück.

P0 bezeichnet kritische Verträge, ist aber keine Begründung, bei jeder Änderung alle P0-Fälle auszuführen. P0-, P1- und P2-Fälle werden impact-basiert ausgewählt. Die vollständige P0/P1/P2-Suite gehört zum Full Gate und nicht zum Standardlauf jeder Änderung.

## Compatibility-Level-Risiko

Eine SQL-Server-2025-Instanz mit Compatibility Level 150 oder 160 emuliert keine native SQL-Server-2019- oder SQL-Server-2022-Engine. Compatibility-Level-Läufe prüfen unter anderem Parser-, Optimizer- und Datenbankverhalten, nicht jedoch ältere DMV-Schemas, Berechtigungsmodelle, Extended-Events-Verfügbarkeit, Engine-Bugs oder versionsabhängige `SERVERPROPERTY`-Zweige.

Der zusätzliche Compatibility-Level-Lauf ist erforderlich, wenn mindestens einer der folgenden Fälle vorliegt:

- ein Objekt unter `Code/09_VersionAdaptive/` wird ausführbar geändert;
- ein betroffener Test liegt unter `Code/Tests/VersionAdaptive/`;
- die Änderung verwendet den Marker `CI: COMPATIBILITY_LEVELS=150,160,170`; oder
- ein Pull Request wird ausdrücklich als Compatibility-Level-Risiko klassifiziert.

Die automatisch ermittelte Klassifikation ist ein Sicherheitsnetz. Wer eine Änderung erstellt oder prüft, muss ein nicht automatisch erkennbares Compatibility-Level-Risiko ausdrücklich markieren.

## Natives Versionsrisiko

Native SQL-Server-2019- oder SQL-Server-2022-Läufe sind erforderlich, wenn die Änderung von Engine- statt nur von Datenbankverhalten abhängt. Dazu zählen insbesondere:

- versionsabhängige DMV- oder Systemkatalogschemas;
- Berechtigungen und Serverrollen;
- Extended Events und enginegebundene Features;
- explizite Product-Major-Version-Zweige;
- Installer- oder Capability-Logik, die eine ältere Engine anders behandelt; und
- die Korrektur eines Fehlers, der nur auf einer bestimmten nativen Version nachgewiesen wurde.

Die betroffene native Version wird gezielt über `.github/workflows/release-native-matrix.yml` gestartet. Der Workflow führt bei einem Release Candidate alle drei unterstützten Versionen aus und begrenzt die Parallelität auf einen Matrixjob.

## Aktive Workflows

| Workflow | Aufgabe | Automatischer Umfang |
|---|---|---|
| `.github/workflows/documentation-validation.yml` | Statische Dokumentations-, Metadata- und Contract-Prüfungen | Impact-basiert ohne SQL Server |
| `.github/workflows/ci-functional-impact.yml` | Funktionale Pull-Request-Prüfung | SQL Server 2025, impact-basiert; Compatibility-Level-Erweiterung bei klassifiziertem Risiko |
| `.github/workflows/release-native-matrix.yml` | Native Versionsprüfung | Ausschließlich manuell; einzelne Version oder Release-Candidate-Matrix |

Gelöschte historische Workflows sind keine gültigen CI-Ziele und dürfen weder in Anweisungen noch im Impact-Selector als aktive Infrastruktur referenziert werden.

## Evidenz und Aussagegrenze

Ein erfolgreicher Lauf belegt nur die tatsächlich ausgeführte Kombination und den ausgewählten Vertragsumfang. `NOT_EXECUTED` ist kein Nachweis. Compatibility-Level-Läufe dürfen nicht als native Engine-Nachweise verbucht werden. Neue Release-Evidenz muss Commit, Engine, ProductVersion, Compatibility Level, Plattform, Testumfang und Ergebnis eindeutig trennen.

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

Statische Validatoren prüfen den aktuellen Lieferstand für die betroffenen Verträge. Ihre Selbsttests prüfen dagegen das Prüfwerkzeug und laufen bei Änderungen an dessen Code, Abhängigkeiten oder Ausführungsumgebung sowie bei neuen Befunden oder ausdrücklichen Qualifikationspflichten. Der Dokumentationsworkflow wiederholt die eigenständigen Datenschutz- und Impact-Selector-Gates nicht. Eine unbekannte Validatorabhängigkeit führt konservativ zur vollständigen statischen Suite; der eng begrenzte Governance-Scope gilt nur für nachweislich zugeordnete Foundation- und Regelkontextdateien.

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

Für ein konkretes natives Snapshot-/Migrationsrisiko ergänzt
snapshot_risk_gate=true die Paket-, Deployment-, Snapshot- und
Nebenläufigkeitsverträge auf genau dem ausdrücklich ausgewählten target.
Der Schalter ist standardmäßig false und wird mit target=all abgelehnt.
Auf SQL2025 laufen die bereits vorgesehenen Zusatzverträge weiterhin genau
einmal. Der zusätzliche ältere Lauf verwendet das Compatibility Level seiner
nativen Engine; ein Compatibility-Level-Wechsel ersetzt diese Abnahme nicht.


qualification_scope=FULL_RELEASE bleibt der voreingestellte unveränderte
Releaseumfang. Der ausdrücklich ausgewählte Modus SNAPSHOT_SCHEMA_RISK
prüft auf genau einer nativen Engine stattdessen das commit-/paketgebundene
Installations- und Snapshotrisiko: Frameworkinstallation und Smoke,
die drei Migrationsrouten mit Daten-/Strukturerhaltung, Calleroptionen und
gezielten Installationsrechten sowie Snapshot- und Nebenläufigkeitsverträge.
Der volle SQL2025-Required-Check bleibt davon unabhängig verpflichtend.

Die Evidenz dieses Modus nennt die tatsächlich ausgeführten Vertragskennungen,
qualification_scope=SNAPSHOT_SCHEMA_RISK und core_release_gate=NOT_EXECUTED.
Der Releaseaggregator lehnt eine solche Zeile als FULL_RELEASE ab; sie bestätigt
keine vollständige native Releasematrix. Auswahl und Aggregation benötigen
positive und negative Gegenfälle, insbesondere gegen fehlende Verträge,
falsche Scopeangaben, Commit-/Paketabweichungen und unbestätigten Cleanup.
Frühere fehlgeschlagene Vollläufe bleiben FAILED mit unbekannter Ursache,
solange keine gesonderte Ursachenabnahme vorliegt.

## Aktive Workflows

| Workflow | Aufgabe | Automatischer Umfang |
|---|---|---|
| `.github/workflows/documentation-validation.yml` | Statische Dokumentations-, Metadata- und Contract-Prüfungen | Impact-basiert ohne SQL Server |
| `.github/workflows/ci-functional-impact.yml` | Funktionale Pull-Request-Prüfung | SQL Server 2025, impact-basiert; Compatibility-Level-Erweiterung bei klassifiziertem Risiko |
| `.github/workflows/release-native-matrix.yml` | Native Versionsprüfung | Ausschließlich manuell; einzelne Version oder Release-Candidate-Matrix |

Gelöschte historische Workflows sind keine gültigen CI-Ziele und dürfen weder in Anweisungen noch im Impact-Selector als aktive Infrastruktur referenziert werden.

## Evidenz und Aussagegrenze

Ein erfolgreicher Lauf belegt nur die tatsächlich ausgeführte Kombination und den ausgewählten Vertragsumfang. `NOT_EXECUTED` ist kein Nachweis. Compatibility-Level-Läufe dürfen nicht als native Engine-Nachweise verbucht werden. Neue Release-Evidenz muss Commit, Engine, ProductVersion, Compatibility Level, Plattform, Testumfang und Ergebnis eindeutig trennen.

## Deterministische lokale Testbewertung

Testauswahl, Ausführung, Soll-Ist-Vergleich, Aggregation, bekannte
Fehlerklassifikation und Cleanup verwenden vorhandene deterministische
Skripte, SQL-Assertions und CI-Werkzeuge. Ein Modell ist kein Testoracle.
Betroffene statische Python-, PowerShell-, Schema- und Installationsverträge
werden vor einer erforderlichen nativen SQL-Prüfung ausgewertet.
Native Tests verwenden ausschließlich für diesen Scope zulässige Testziele;
die Testauswahl erteilt keine Installations-, Host-, Provider- oder
Datenbankänderungsbefugnis außerhalb dieses Rahmens.

Ein Gesamterfolg verlangt alle erforderlichen Gates, die vorgesehenen
Oracles und den nachgewiesenen Cleanup. Exitcode 0, ein grüner Teiltest oder
eine synthetische Probe ersetzen keine fehlende native Abnahme. Die
betroffenen Verträge für CONSOLE, RAW, TABLE, NONE und die optionale
JSON-Ausgabe werden einschließlich Schemas, Zeilen- und Resultsetmengen,
Partialität und Berechtigungsgrenzen geprüft. JSON bleibt ein OUTPUT-Vertrag
und wird nicht zu einem zusätzlichen Wert von `@ResultSetArt`.

Die knappe Erfolgsmeldung referenziert den maschinenlesbaren Scope, die
erforderlichen Gate-IDs, Source- und Testbindung, erforderliche und
ausgeführte Testzahlen, Ergebnis, Dauer und minimale Evidenzverweise,
soweit diese zuverlässig vorliegen. Fehlende Felder bleiben ausdrücklich
unbekannt; sie werden nicht aus Exitcode oder Dateinamen abgeleitet.
Bestehende Runner und Berichte werden bevorzugt. Ein fehlendes Berichtsfeld
rechtfertigt keine neue globale Teststeuerung oder zweite Ergebnisdatenbank.
Vollständiger Erfolg löst keine zusätzliche modellbasierte Bestätigung aus.
Vorgeschriebene unabhängige Reviews und menschliche Freigaben bleiben erhalten.

Fehler werden zunächst lokal nach erster tatsächlicher Fehlerstelle,
Exitcode, Soll-Ist-Abweichung, Resultsetvollständigkeit, Timeout,
Infrastruktur, Berechtigung und Cleanup eingeordnet. An ein Modell gehen
nur notwendige bereinigte Befunde mit stabilem Reason-Code, falls ein neues
ungelöstes fachliches Problem oder eine Entscheidung verbleibt. Ungeklärte
Ursachen bleiben UNKNOWN; sie werden nicht als Infrastrukturfehler behandelt.
Ein unveränderter Blocker löst keine periodischen Modellaufrufe aus.

Berichte unterscheiden PASSED, FAILED, INCONCLUSIVE, UNKNOWN, BLOCKED,
UNAVAILABLE, NOT_EXECUTED und NOT_APPLICABLE nach ihrer Aussage. PASSED
bezeichnet den vollständigen Erfolg des benannten Scopes; INCONCLUSIVE
bezeichnet eine ausgeführte, aber nicht entscheidbare Prüfung, UNKNOWN einen
nicht festgestellten Sachverhalt. BLOCKED bezeichnet eine fehlende
Voraussetzung, UNAVAILABLE eine nicht verfügbare Prüfmöglichkeit;
NOT_APPLICABLE verlangt eine begründete Nichtanwendbarkeit. Diese Begriffe
werden bei Bedarf auf vorhandene Berichtsenumerationen abgebildet.
Produktstatuscodes und bestehende Dateiformate werden dadurch nicht geändert.

## Lokale Evidenz und erforderliche Remotechecks

Im aktuellen Workflow ist die Wiederverwendung lokaler nativer Ergebnisse
für GitHub-Required-Checks NOT_IMPLEMENTED. Die bestehende Remoteausführung
bleibt verbindlich. Die folgende Regel begrenzt eine spätere ausdrücklich
implementierte Wiederverwendung; sie schaltet keinen Reusepfad frei.

Eine native Wiederholung darf nur entfallen, wenn ein unabhängiger
vertrauenswürdiger Verifikator aktuelle lokale Evidenz für denselben
erforderlichen Scope bestätigt. Der risikogerecht vollständige Bindungsschlüssel
umfasst:

- Repository, wirksamen Source-, Build- und Abhängigkeitsbaum sowie den für das
  Ereignis erforderlichen PR-Head, Integrationsstand oder Merge-Group-SHA;
- Test-IDs, Test- und Oracleimplementierung, Runner, Harness, ausgewählten
  Gesamtumfang, Parameter, Fixtures und erwartete Ergebnisverträge;
- tatsächliche SQL-Engine und Build, Compatibility Level, Collation,
  Plattform, Provider, Image-Digest, Rechte sowie relevante Client-, Runtime-
  und TLS-Grenzen;
- befugte Host- oder CI-Identität, überprüfte Provenienz und Integrität,
  zulässige Aktualität, gegebenenfalls Widerruf sowie externen Zustandsdrift;
- erfüllte Oracles und Negativfälle, Ressourcenownership, Abschluss und Cleanup.

Ein frei erzeugbares PASS-Receipt, ein Git-Commit, ein Hash oder eine
Signatur ohne geprüfte Aussteller- und Scopeautorität genügen nicht.
Die Testsoftware darf ihre eigene Autorität nicht frei attestieren.
Der Verifikator muss aus einer vertrauenswürdigen Grenze stammen und darf
nicht durch unkontrollierten PR-Code ersetzbar sein. Ein Modell kann keine
Testausführung attestieren. Build-Provenienz allein belegt kein Testoracle.

| Entscheidung eines künftigen Verifikators | Verbindliche Bedeutung |
|---|---|
| EXECUTE_REQUIRED | Relevante Inputs sind geändert oder Herkunft, Aktualität, Umgebung, Oracle, Cleanup oder Gatebindung reichen nicht aus. Die erforderliche Prüfung wird im zulässigen Rahmen ausgeführt; andernfalls bleibt das Gate blockiert. |
| REUSED_VERIFIED | Lokale Ausführung und aktuelle Anwendbarkeit sind unabhängig bestätigt. Nur die native Wiederholung entfällt; das aktuelle erforderliche GitHub-Gate muss regulär erfolgreich abschließen. |
| NOT_REQUIRED | Die deterministische Impact-Auswahl begründet, dass die Prüfung für die Änderung nicht erforderlich ist. Das Ergebnis ist keine ausgeführte native Abnahme. |

REUSED_VERIFIED ist keine zweite Ausführung und wird von EXECUTED_REMOTE
unterschieden. Required Checks, erwartete Check-Source-Identität und
Ereignisbindung bleiben erhalten. Eine PR-Head-Evidenz gilt nicht automatisch
für einen anderen Integration- oder Merge-Group-Tree. Falls eine Merge Queue
eingeführt wird, benötigt sie eine passende eigene `merge_group`-Prüfung;
dieser Vertrag aktiviert weder Queue noch zusätzliche Trigger.
Skipanweisungen, Pathfilter und künstliche Erfolgsstatus dürfen keine
erforderliche Prüfung umgehen. Schnelle statische CI-Prüfungen werden
vorzugsweise unabhängig erneut ausgeführt, wenn Transport und Attestierung
aufwendiger wären. Release- und native Versionsgates bleiben eigenständig.

## Abnahme von Selektor- und Reuseänderungen

Eine Verengung konservativer Fallbacks benötigt belegte Positiv- und
Negativfälle. Zentrale Installer und Runner behalten erforderliche
Installations-, Upgrade-, Wiederholungs-, Erhaltungs-, Rechte- und
Cleanupprüfungen. Gemeinsame SQL-Helfer benötigen ihre transitiven Consumer
und den betroffenen Smoke-, Ergebnis- und Berechtigungsumfang.
SSIS-, Backup-, XE-, Query-Store- und VersionAdaptive-Verträge behalten ihre
jeweiligen nativen, Berechtigungs- und Versionsgrenzen. Dynamisch
zusammengesetzte SQL-Referenzen sind keine bewiesene Abhängigkeitsabdeckung;
erkannte unklare Auswirkungen verlangen einen konservativen vollständigen
Gate-Scope oder einen expliziten Abbruch. Ein Selektorfehler darf keinen
grünen Skip erzeugen.

Bei einer betroffenen Implementierung werden mindestens die folgenden
Fallgruppen geprüft. Ein noch nicht implementierter Reusepfad erhält keine
fiktive positive Abnahme; der sichere Remote-Fallback bleibt erhalten.

| Betroffener Vertrag | Erforderliche Gegenprüfung |
|---|---|
| SQL-Impact | Kommentaränderung ohne Runtime, ausführbare Änderung mit passenden Tests, TVF zu USP über mehrere Abhängigkeitsstufen sowie dynamischer oder unbekannter Impact ohne unsicheren Skip. |
| Infrastruktur und Plattform | Zentraler Installer, Standalone- und Snapshotausnahmen, Rechte sowie die fehlende automatische Gleichwertigkeit von SQL Server 2019 und SQL Server 2025 mit CL150. |
| Validator und Testscope | Geänderte Validatorbytes und Abhängigkeiten aktivieren die erforderlichen Selbsttests; gemischte Änderungen vereinigen die betroffenen Gates ohne unbegründetes Voll-Replay. |
| Oracle und Abschluss | Falsche oder fehlende JSON-, RAW- und TABLE-Ausgaben, falsche Zeilen- oder Resultsetmengen, Privacyfehler und fehlender Cleanup verhindern Gesamterfolg. |
| Künftiger Reusepfad | Befugte aktuelle lokale Ausführung wird mit regulärem Required Check akzeptiert; manipulierte, untrusted, abgelaufene, unvollständige oder modellgenerierte Herkunft wird abgewiesen. |
| Reuseinvalidierung | Änderungen an Oracle, Tests, Quellen, Abhängigkeiten, Fixtures, Verifikator, Build- oder Sicherheitskonfiguration sowie Engine, CL, Provider, Image, Runtime, Rechten, externem Zustand oder Aktualität invalidieren betroffene Nachweise. Abweichende PR-, Integrations- oder Merge-Group-Bindung ersetzt keinen aktuellen Check. |
| Lokale Bewertung | Der vollständige Erfolgsweg verlangt null zusätzliche Modellbestätigungen; Fehler werden zuerst lokal klassifiziert und bereinigt. Unveränderte Fehler erzeugen keine automatische Wiederholung. |

Vor einer technischen Optimierung werden aktuelle repräsentative Diffs und
Läufe nach Revision, Objekten, Testmethoden, Ausgabemodi, tatsächlichen
nativen Läufen, Setup, Datenbankaufbau, Rechten und Cleanup verglichen.
Eine Laufzeit von mehreren Minuten allein belegt keine Doppelprüfung.
Queue, Setup, Mutexwartezeit, Tests, Cleanup und Modell-/Reviewaufwand werden
nur bei belastbarer Messung getrennt angegeben; unbekannte Kosten und
Einsparungen bleiben UNKNOWN. Abnahme verlangt nachgewiesenen Nutzen oder
eine begründete Beibehaltung notwendiger Prüfungen.

## Ablösung und Abbruch von CI-Läufen

Die funktionale Impact-CI und die manuelle native Matrix verwenden
`cancel-in-progress: false`. Ein neuer Commit desselben Pull Requests beendet
keine laufende SQL-Validierung. Die Runtime erzeugt synthetische Datenbanken
und weitere Testressourcen in ihrem eigenen Container auf einem
GitHub-gehosteten Runner. Der vorhandene `always()`-Cleanup bleibt erhalten;
seine Wirksamkeit nach einer harten Unterbrechung wird nicht vorausgesetzt.
Lokale native Labs behalten ihren eigenen scopegebundenen Cleanup und werden
von dieser GitHub-Concurrency-Einstellung nicht gesteuert.

Die rein statischen Dokumentations-, Commit- und Datenschutzworkflows dürfen
ältere Läufe derselben Workflow-/Ref-Gruppe weiterhin automatisch ablösen.
Sie verändern keine persistenten SQL- oder externen Betriebsressourcen.
Abgebrochene, abgelöste und nicht gestartete Läufe sind keine erfolgreiche
Validierung. Vor Integration sind erfolgreiche erforderliche Checks am
exakten PR-Head zu prüfen. Eine Merge-Queue oder ein gemeinsamer getesteter
Integrationskandidat wird durch diese Strategie nicht aktiviert.

Ein expliziter Benutzerabbruch oder Infrastrukturverlust kann dennoch eine
laufende Prüfung beenden. In diesem Fall werden Cleanup und verbliebene
Ressourcen geprüft; der betroffene Lauf bleibt ohne Erfolgsnachweis.
Erforderliche CI wird nach Wiederherstellung auf dem maßgeblichen Head erneut
ausgeführt. Ein Ergebnisfehler wird nicht als Infrastrukturfehler umgedeutet.

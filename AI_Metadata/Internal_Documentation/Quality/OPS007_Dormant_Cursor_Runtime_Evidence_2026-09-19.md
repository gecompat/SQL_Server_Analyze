# OPS-007: Dormant-Cursor-Runtimeevidenz

**Stand:** 19. September 2026  
**Status:** `LOCAL_WORKTREE_EVIDENCE`  
**Datenbasis:** ausschließlich synthetische Fixtures

## Ausgeführter Nachweis

Der fokussierte OPS-007-Runtimevertrag lief auf der vorhandenen Linux-Umgebung mit SQL Server 2019. Ein lokaler statischer Cursor blieb nach dem Öffnen länger als 60 Sekunden ruhend. `USP_CurrentCursorAnalysis` lieferte für diesen Cursor `DORMANT_CONTEXT`.

Der Test prüfte zusätzlich den sicheren Default, die Einzelsessionbegrenzung, den aktiven Cursor und die eingeschränkte Sicht. Der Framework-Testscope wurde nach dem Lauf entfernt.

## Aussagegrenze

Der Nachweis belegt keine fremde Session, keinen ressourcenauffälligen Cursor und keinen eigenständigen serverweiten Berechtigungsfehler. Die Procedure verändert keine Cursor.

## Ergänzung vom 5. Oktober 2026

Der neue Runner `TestLab/Invoke-Ops007ForeignCursorScenario.ps1` bestand auf
SQL Server `17.0.4075.5` in einem ausschließlich neu erzeugten Docker-Lab.
Frameworkinstallation, Smoke-Test und der bestehende Cursorvertrag waren
erfolgreich. Eine zweite eigene Verbindung hielt einen statischen Cursor
über 10.000 synthetische Zeilen offen. Die auf eine Zeile begrenzte Analyse
lieferte exakt dessen Session, Cursorkennung und Namen mit `RESOURCE_CONTEXT`.
Öffnungs- und Fetchzustand blieben unverändert.

Eine eigene Loginfixture erhielt ausschließlich das erforderliche
Ausführungsrecht auf den Analyzer. Die gezielte DMV-Verweigerung und die
serverweite Berechtigungsverweigerung im `master`-Kontext führten zu
`DENIED_PERMISSION`, Partialstatus, einer Berechtigungsfehlernummer und
leerem JSON. Fehlende Statuswerte bestehen die Prüfung nicht. Container,
Volume, Cursorverbindung, Benutzerfixtures und temporärer State wurden
vollständig entfernt.

Zwei verworfene Testanordnungen scheiterten zuvor mit `4629` beziehungsweise
`4621`, weil die Berechtigungsverweigerungen außerhalb von `master` gesetzt
wurden. Auch deren eigene Labs wurden vollständig entfernt. Der erfolgreiche
Gesamtlauf verwendete die korrigierte Testanordnung. Positive Ressourcenzähler
belegen keine Hochlast und keinen Cursorzustand einer fremden Betriebsumgebung.
## NULL-Zeilenlimit vom 8. Oktober 2026

Die ursprüngliche Procedure auf Basis `dcc5163d47f12b91993500d3718817e2107819a3`
ließ ein explizites `@MaxZeilen=NULL` im TOP-Ausdruck unverändert. Ein neues
eigenes SQL-Server-2025-Docker-Lab bestätigte den Fehler: Für einen offenen
lokalen statischen Cursor lieferte `0` eine Zeile mit `AVAILABLE`, während
`NULL` zu `SOURCE_UNAVAILABLE`, Partialstatus, Fehler `1014` und einem leeren
JSON-Array führte. Dieser Lauf ist als `OBSERVED_DEFECT` erfasst; er ist kein
erfolgreicher Nachweis des öffentlichen NULL-Vertrags.

Die Reparatur normalisiert NULL auf 0 vor der Parameterprüfung. Sie erfüllt
den bereits bestehenden gemeinsamen Zeilenlimitvertrag; Default `200`,
Opt-in, Einzelsessionauswahl, negative Ablehnung und die zwölf Cursorfelder
bleiben erhalten. Die Procedure-Seite beschreibt auch ohne explizite Auswahl
die eigene Zielsession und enthält kein serverweites DMV-Beispiel mehr.

Ein weiteres neues eigenes Lab bestand die sechs impact-basierten Verträge
`Common/124`, `CurrentState/110`, `CurrentState/120` sowie
`Integration/110`, `Integration/196` und `Integration/198`. Der erweiterte
Test 120 hält zwei eigene statische Cursor offen und prüft sechs
NULL-/0-/Minus-eins-Aufrufe über NONE und TABLE. Die vier unbegrenzten Fälle
stimmen mit den nativen Cursoridentitäten, Offen- und Fetchzuständen überein.
Die beiden positiven TABLE-Fälle vergleichen alle zwölf Felder mit JSON und
prüfen eindeutige Cursorkennungen; die beiden negativen Fälle liefern
`INVALID_PARAMETER` mit leerem JSON und leerem TABLE-Ziel. Native Identitäten
und Calleroptionen bleiben nach jedem Aufruf erhalten. Die bisherigen
Default-, Einzelsession-, Max-eins-, kontrollierten Dormanz- und
eingeschränkten Fälle bestehen im selben Testlauf.

Eine getrennte SqlClient-Gegenprobe des reparierten Quellenstands bestätigt
für NULL und 0 jeweils eine JSON-Zeile mit `AVAILABLE`,
Nichtpartialität und NULL-Fehlernummer. Nach beiden Aufrufen sind
Locktimeout 137, XACT_ABORT OFF sowie Transaktionsanzahl `0` und
XACT_STATE `0` bestätigt. Der abschließende Callerzustand ist separat erfasst und
bestätigt Locktimeout minus eins, XACT_ABORT OFF und dieselben Nullgrenzen.
Der eigene Cursor wird geschlossen und deallokiert.

Alle nativen Läufe dieses Slices verwendeten SQL Server `17.0.4075.5` und
Framework-Compatibility-Level 170. Kanonische Installation und Smoke
bestanden. Die lokale Standalone-Installerprüfung 191, der Deploymentparser-
Selftest, die 14 Deploymentvertragsprüfungen und der statische
Nonblocking-/Temp-Namensvertrag bestanden. Beide betroffenen ignorierten
Installer wurden aus den Einzelquellen neu erzeugt.

Zwei frühere private Testanordnungen stoppten am Caller-Eintrittsguard vor
den beiden Analyzeraufrufen. Nur die zweite Anordnung lieferte dabei die
separaten Diagnosewerte Locktimeout minus eins, Transaktionsanzahl `0` und
XACT_STATE `1`. Der erfolgreiche Baseline- und Reparaturlauf verwendet
isolierte SET-Messungen sowie separate SqlClient-Eintrittsabfragen bei
unveränderten Nullgrenzen. Daraus wird weder eine allgemeine Engineursache
noch eine Produktabweichung des Callerzustands abgeleitet. Die ursprünglichen
Pakete und Fehlerbeobachtungen bleiben privat erhalten.

Eine weitere private Reparaturabnahme stoppte in Test 120 mit Fehler `51011`, weil
das TABLE-Ziel bereits zwölf Spalten besaß. Die korrigierte Fixture legt vor
jedem Aufruf eine frische leere Seed-Tabelle an und bindet ihre zwölf
Exportfelder erst nach der gemeinsamen Strukturadaption. Der verworfene Lauf
liefert keinen abschließenden Reparaturnachweis.

Jedes eigene Lab einschließlich der drei verworfenen Testanordnungen wurde
über den öffentlichen Lab-Cleanup mit zwei Schritten und null Fehlern
entfernt; die zugehörigen eigenen Stateverzeichnisse sind entfernt.
Rohlogs, Quellpins, Endpunkte und native Kennungen bleiben außerhalb von Git.
Der begrenzte lokale Nachweis stammt aus dem geprüften Arbeitsbaum; die
erforderliche CI wird getrennt an den exakten PR-Head gebunden. Er liefert
keine neue fremde Hochlast-, ältere native Engine-, CL150-/CL160- oder
zusätzliche RAW-/CONSOLE-Evidenz. OPS-007 und COLL-001 bleiben partiell.

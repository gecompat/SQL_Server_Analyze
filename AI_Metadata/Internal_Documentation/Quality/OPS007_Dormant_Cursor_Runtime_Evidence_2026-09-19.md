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

Die erste Head-CI meldete einen veralteten versionierten OPS-005-Installer.
Der kanonische Adapterbuilder erzeugte ihn neu; der normalisierte Diff
enthält ausschließlich dieselbe NULL-Normalisierung der Cursor-Procedure.
Der versionierte OPS-005-Runtimevertrag bleibt unverändert. Der lokale
Adaptervergleich bestätigt die kanonische Ableitung und besteht; der
verworfene CI-Stand ist kein erfolgreicher vollständiger statischer Nachweis.

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

## Inventar mit 250 Cursorn vom 8. Oktober 2026

Ein neues eigenes SQL-Server-2025-Docker-Lab prüfte den integrierten Stand
`f72616f549e6e1ff59d2c944286bbcccc9c191e8` mit einem größeren kontrollierten
Inventar. Eine eigene zweite SqlClient-Verbindung hielt 250 globale statische
READ_ONLY-Cursor über jeweils drei synthetische Literalzeilen offen. Jeder
Cursor besaß einen erfolgten Fetch. Der Observer verwendete eine andere eigene
Verbindung und eine explizite einzelne Zielsession.

Zehn Aufrufe über NONE und TABLE bestätigen je Ausgabeart den ausgelassenen
Default, die expliziten Grenzen 1 und 200 sowie 0 und NULL. Die Zeilenanzahlen
sind jeweils 200, 1, 200, 250 und 250. Die ausgewählten Cursorkennungen stimmen
mit dem begrenzten nativen Rang nach Worker Time, Reads und Cursorkennung
überein. Alle Aufrufe liefern `AVAILABLE`, Nichtpartialität und keine
Fehlernummer oder Fehlermeldung.

Alle zwölf fachlichen Werte sind geprüft. Zehn stabile Werte stimmen mit
der nativen Vorhermessung überein; die Dormanz liegt zwischen den nativen
Vorher- und Nachherwerten, und FindingContext folgt dem bestehenden
Schwellwert- und Ressourcenvertrag. Die 250 nativen Identitäten, Namen,
Properties, Öffnungs- und Fetchzustände sowie kumulativen Arbeitswerte
bleiben über jeden Analyzeraufruf erhalten. Die fünf TABLE-Aufrufe bestätigen
zusätzlich alle zwölf Werte gegen JSON derselben Materialisierung, exakte
Zeilenanzahl und eindeutige Cursorkennungen. Fünf physische Exportschemas
bestätigen Feldreihenfolge, Namen, Typen, Bytebreiten und die explizite
Textcollation der drei Textfelder anhand eines Literalorakels. Interne Spaltenkennungslücken
der Seed-Adaption werden ausschließlich im privaten Ordinalprüfer
normalisiert; daraus entsteht keine Produktänderung.

Der native Lauf verwendet SQL Server `17.0.4075.5` und Framework-Compatibility-
Level 170. Server und tempdb besitzen gemessen `Latin1_General_100_CS_AS`,
das Framework `SQL_Latin1_General_CP1_CS_AS`. Installation und Smoke-Test
bestehen. Jeder Analyzeraufruf erhält Locktimeout 137, XACT_ABORT OFF,
Transaktionsanzahl `0` und XACT_STATE `0`. Der abschließende Observerzustand
bestätigt separat Locktimeout minus eins und dieselben übrigen Werte.

Das eigene Cursorcleanup schließt und deallokiert alle 250 Cursor und
bestätigt ein leeres Producerinventar. Beide Verbindungen werden geschlossen;
der öffentliche Lab-Cleanup entfernt die eigenen Ressourcen in zwei Schritten
mit null Fehlern. Das eigene Stateverzeichnis ist entfernt. Quell- und
Fixturepins, Rohlog und native Kennungen bleiben privat außerhalb von Git.

Dieser begrenzte Inventar- und Consumernachweis verwendet unveränderte
Produktquellen und ergänzt keine Hochlastevidenz. RAW, CONSOLE, zusätzliche
Compatibility Levels und ältere native Engines wurden in diesem Lauf nicht
geprüft. Der bestehende sechsdateilige Runtimevertrag des vorangegangenen
Reparaturslices wird nicht erneut als ausgeführt dargestellt. OPS-007 und
COLL-001 bleiben partiell; ihre offenen Umfänge und bisherigen Statusflags
bleiben unverändert.

## Kontrollierter Ressourcenvergleich vom 8. Oktober 2026

Ein neues eigenes SQL-Server-2025-Docker-Lab prüfte den integrierten Stand
`349cbafe28d2f57c26abc78426692782aa6f29a5` mit zwei eigenen Cursorn in
einer getrennten Producerverbindung. Ein globaler SCROLL-STATIC-READ_ONLY-
Cursor materialisierte 200.000 synthetische Zeilen mit jeweils einem
Integerwert und einem 512 Byte breiten Unicode-Payload. Eine endliche
Traversierung bestätigte Zeilenanzahl, bigint-Summe, Payloadbreite und
synthetischen Payloadinhalt. FETCH FIRST setzte den Cursor anschließend auf
die erste Zeile zurück. Der zweite Cursor verwendete drei synthetische
Literalzeilen. Beide waren offen, synchron befüllt und besaßen Fetchstatus 0.

Die native DMV meldete für den größeren Cursor höhere WorkerTime- und
Reads-Werte als für die Gegenprobe; auch Writes waren positiv. Diese
gemessene relative Ressourcenwirkung wurde vor jedem Analyzeraufruf
bestätigt. Es wurde kein neuer öffentlicher Kostenschwellwert festgelegt.

Vier Aufrufe über NONE und TABLE bestätigen je Ausgabeart Limit 1 und
vollständige Ausgabe mit Limit 0. Limit 1 wählt ausschließlich den größeren
Cursor gemäß dem bestehenden nativen Rang nach WorkerTime, Reads und
Cursorkennung. Limit 0 liefert beide Cursor. Alle Aufrufe liefern
`AVAILABLE`, Nichtpartialität und keine Fehlernummer oder Fehlermeldung.
Die zehn stabilen nativen Felder, Dormanz innerhalb der Vorher-/Nachhergrenzen
und der daraus abgeleitete bestehende FindingContext sind geprüft. Alle
nativen Cursoridentitäten, Namen, Properties, Öffnungs- und Fetchzustände
sowie kumulativen Arbeitswerte bleiben über jeden Analyzeraufruf erhalten.
Die beiden TABLE-Aufrufe bestätigen alle zwölf Werte gegen JSON derselben
Materialisierung einschließlich Zeilenanzahl und eindeutiger Cursorkennungen.
Beide physischen Exportschemas bestätigen Reihenfolge, Namen, Typen,
Bytebreiten und die explizite Textcollation der drei Textfelder.

Der Lauf verwendet SQL Server `17.0.4075.5` und Framework-Compatibility-Level
170. Server und tempdb besitzen gemessen `Latin1_General_100_CS_AS`, das
Framework `SQL_Latin1_General_CP1_CS_AS`. Kanonische Installation und
Smoke-Test bestehen. Jeder Analyzeraufruf erhält Locktimeout 137,
XACT_ABORT OFF, Transaktionsanzahl 0 und XACT_STATE 0. Der abschließende
Observerzustand bestätigt separat Locktimeout minus eins und dieselben
übrigen Werte.

Vor dem Cursorcleanup bestätigt die Producerverbindung weiterhin
200.000 Quellzeilen, die ursprüngliche bigint-Summe sowie sämtliche
Payloadbreiten und synthetischen Payloadinhalte. Das eigene Cleanup schließt
und deallokiert beide Cursor, entfernt ihre eigene temporäre Quelle und
bestätigt deren Abwesenheit sowie ein leeres Producerinventar. Beide
Verbindungen sind geschlossen. Der öffentliche Lab-Cleanup entfernt die
eigenen Ressourcen in zwei Schritten mit null Fehlern; das eigene
Stateverzeichnis ist entfernt. Quellpins, Fixturepins, Rohlog, gemessene
Arbeitszähler und native Kennungen bleiben privat außerhalb von Git.

Dieser begrenzte Vergleich bestätigt eine tatsächlich größere kontrollierte
Cursorarbeit in einer zweiten eigenen Session. Er belegt keine fremde
Hochlast, Sättigung oder allgemeine Kostenschwelle. Die SQL-Kommandos sind
jeweils auf 120 Sekunden begrenzt; daraus folgt keine garantierte
Gesamtlaufgrenze. RAW, CONSOLE, weitere Compatibility Levels und ältere
native Engines wurden in diesem Lauf nicht geprüft. Das vollständige sechsdateilige Runtimepaket
des vorherigen Reparaturslices wurde nicht wiederholt; aus diesem Paket lief
in diesem Slice ausschließlich Smoke-Test 110.
OPS-007 und COLL-001 bleiben partiell; ihre offenen Umfänge und bisherigen
Statusflags bleiben unverändert.

## Direkte RAW- und CONSOLE-Ausgaben vom 8. Oktober 2026

Ein neues eigenes SQL-Server-2025-Docker-Lab prüfte den integrierten Stand
`b1b09d5a882b863e0bb8eeb107a29373a7f9bdbc` über einen direkten SqlClient-
Consumer. Zwei globale STATIC-READ_ONLY-Cursor in einer getrennten eigenen
Producerverbindung verwenden jeweils drei synthetische Literalzeilen.
Ihre Namen enthalten Unicode und ein Apostroph und unterscheiden sich in
der Groß-/Kleinschreibung. Beide Cursor sind offen und einmal erfolgreich
mit FETCH gelesen. Alle nativen Kennungen werden ausschließlich privat verwendet.

Zehn Analyzeraufrufe prüfen RAW und CONSOLE jeweils mit Limit 1, Limit 0,
leerem eigenen Observerscope, negativem Limit und deaktiviertem Opt-in.
Die Ausgaben liefern ein beziehungsweise zwei Fachzeilen, leere Mengen,
`INVALID_PARAMETER` mit Partialität und `NOT_EXECUTED` ohne Partialität.
Positive Aufrufe melden `AVAILABLE`, der leere Scope `AVAILABLE_EMPTY`.
Fehlernummern bleiben NULL; ausschließlich das negative Limit liefert die
bestehende Fehlermeldung. Der Reader wird einschließlich aller Resultsets
gelesen und geschlossen, bevor OUTPUT-Parameter geprüft werden.

RAW liefert genau ein fünfspaltiges Statusresultset sowie bei aktiviertem
Opt-in ein zwölfspaltiges Detailresultset, auch bei leerer oder ungültiger
Auswahl. Beim deaktivierten Opt-in bleibt ausschließlich das Statusresultset.
Positive CONSOLE-Ausgaben liefern zwölf Fachspalten und die Beschriftung
`Ergebnis`. Leere, ungültige und deaktivierte CONSOLE-Aufrufe liefern genau
eine dreispaltige Hinweiszeile. Deren Status- und Hinweiswerte bleiben NULL,
weil dieser Analyzer dem vorhandenen Consolehelper keinen Statuskontext
übergibt; der OUTPUT-Status wird unabhängig geprüft. Zusätzliche Resultsets
werden abgelehnt. Native Ordinale, Namen, SQL-Typen, logische Textbreiten und
Identityfacetten sämtlicher Resultsets werden geprüft. Die zwölf Fachfelder
und die CONSOLE-Felder sind nullable; die gemessenen Nullabilityfacetten des
RAW-Statusresultsets werden privat aufgezeichnet.

Alle zwölf positiven Fachwerte werden vollständig mit JSON desselben
Aufrufs verglichen, einschließlich eindeutiger Cursorkennungen, ordinaler
Unicode-/Case-Texte und Datetimewerte. Die native DMV wird
vor und nach jedem Aufruf unabhängig gelesen. Die zehn stabilen Quellwerte
bleiben für beide Cursor gegenüber dem Anfangszustand erhalten; Dormanz
liegt innerhalb der gemessenen Vorher-/Nachhergrenzen. Die bestehende
FindingContext-Ableitung und die native TOP-Auswahl nach WorkerTime, Reads
und Cursorkennung sind geprüft. Der CONSOLE-Vergleich erfolgt nach Kennung
und verspricht keine Ausgabeordnung.

Der Lauf verwendet SQL Server `17.0.4075.5`, Framework-Compatibility-Level
170 und gemessene Server-/tempdb-Collation `Latin1_General_100_CS_AS` bei
Frameworkcollation `SQL_Latin1_General_CP1_CS_AS`. Kanonische Installation
und Smoke-Test bestehen. Jeder Consumer erhält Locktimeout 137,
XACT_ABORT OFF, Transaktionsanzahl 0 und XACT_STATE 0; die Callerwerte werden
vor weiteren Leseabfragen separat erfasst. Der abschließende Locktimeout
ist minus eins; XACT_ABORT OFF, Transaktionsanzahl 0 und XACT_STATE 0
bleiben abschließend erhalten. Beide eigenen Cursor werden explizit geschlossen und
deallokiert, das Producerinventar ist anschließend leer. Beide Verbindungen
werden geschlossen. Der öffentliche Lab-Cleanup entfernt die eigenen
Ressourcen in zwei Schritten mit null Fehlern; das eigene Stateverzeichnis
ist entfernt. Quellpins, Fixturepins, Schemabelege und native Rohwerte bleiben
privat außerhalb von Git.

Der Slice ändert keinen Produktcode oder öffentlichen Vertrag. Er belegt
die beschriebenen direkten Consumerformen auf der gemessenen Kombination;
er ist kein Nachweis fremder Hochlast, allgemeiner Kostenschwellen, weiterer
Compatibility Levels oder älterer nativer Engines. Aus dem sechsdateiligen
Runtimepaket des vorherigen Reparaturslices wurde ausschließlich Smoke-Test
110 erneut ausgeführt. OPS-007 und COLL-001 bleiben partiell; offene Umfänge
und bestehende Statusflags bleiben unverändert.

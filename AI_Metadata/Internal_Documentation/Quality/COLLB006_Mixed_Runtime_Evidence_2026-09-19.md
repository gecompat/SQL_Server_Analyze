# COLL-B006: Mixed TABLE-Runtimeevidenz

**Stand:** 19. September 2026  
**Status:** `LOCAL_WORKTREE_EVIDENCE`  
**Datenbasis:** ausschließlich synthetische Fixtures

Der TABLE-Ausgabevertrag lief auf der vorhandenen Linux-Umgebung mit SQL Server 2019. Server und `tempdb` verwendeten `SQL_Latin1_General_CP1_CI_AS`; die Frameworkdatenbank verwendete `SQL_Latin1_General_CP1_CS_AS`. Der Vertrag bestätigte Strukturadaption, Collationübernahme, typisierte Inserts und die unveränderte Ablehnung nicht leerer Zieltabellen mit abweichender Collation.

Der Framework-Testscope wurde nach dem Lauf entfernt. Der Nachweis deckt keine abweichend kollatierte permanente Zieldatenbank ab.

## Performance Counters: 5. Oktober 2026

`Code/Tests/Common/130_PerformanceCounters_Collation_Runtime_Contract.sql`
bestand in einem neu erzeugten lokalen SQL-Server-2025-Docker-Container.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, die
Frameworkdatenbank `SQL_Latin1_General_CP1_CS_AS`. Die Bereitschaftsprüfung
bestätigte Majorversion 17; die konkrete ProductVersion wurde nicht erhoben.

Der unveränderte Procedure-Stand reproduzierte mit demselben Vertrag die
fremde Exportcollation (`55792`). Zwölf lokale Textspalten verwenden jetzt
die Frameworkcollation. Die anschließende Gegenprobe zeigte einen nativen
Collationkonflikt (`468`) am Join zum zweiten DMV-Snapshot; dessen drei
Textvergleiche sind ebenfalls explizit collatiert. Die absichtlich
case-insensitive Zuordnung ergänzender Basiscounter bleibt unverändert.

Der abschließende Lauf bestätigte für den nativen `User Connections`-Counter
je eine positive, nicht partielle TABLE-/JSON-Ausgabe ohne Wartezeit und mit
einer Sekunde Messintervall. Alle sechs Exporttextspalten verwendeten die
Frameworkcollation. Counteridentität und Typ stimmten mit der DMV überein;
der typisierte Rohwert entsprach dem aufgenommenen Nachherwert. Ein in der
Großschreibung abweichender Counterfilter lieferte `UNAVAILABLE_OBJECT`,
partiellen Status und ein leeres Array.

Der Testaufbau erzeugt pro TABLE-Aufruf einen neuen Seed. Ein vorheriger
Versuch mit erneut verwendeter adaptierter Tabelle scheiterte
an deren Seed-Vertrag (`51011`) und wurde korrigiert. Frameworkinstallation,
Smoke-Test und der abschließende Vertrag bestanden; alle drei eigenen
Container, Volumes und temporären Lab-States wurden entfernt. Die 75 lokalen
statischen Verträge bestanden nach der Korrektur ebenfalls. Der neue
Laufzeitvertrag belegt keine Rate-, Fraction-, Reset- oder Hochlastvariante.

## Buffer Pool: 5. Oktober 2026

`Code/Tests/Common/131_BufferPool_Collation_Runtime_Contract.sql` bestand in
einem neuen lokalen SQL-Server-2025-Docker-Container mit denselben abweichenden
Server-/`tempdb`- und Frameworkcollations. Die Bereitschaftsprüfung bestätigte
Majorversion 17; die konkrete ProductVersion wurde nicht erhoben.

Der ursprüngliche Stand reproduzierte mit demselben Vertrag die fremde
Memory-Exportcollation (`55801`). Die korrigierte Quelle versieht alle sechs
lokalen Textspalten einschließlich der Datenbanknamen mit der Frameworkcollation.
Der abschließende TABLE-Export bestätigte diese Collation für alle vier
Memory-Textspalten. Prozess- und Systemspeicher waren positiv; der
Verfügbarkeitsprozentsatz entsprach der Formel aus derselben Momentaufnahme,
und TABLE sowie JSON enthielten denselben Prozessspeicherwert.

Der Standardaufruf lieferte keine Buffer-Pool-Verteilung. Der explizite Opt-in
lieferte eine positive Verteilung mit höchstens zehn Einträgen einschließlich
mindestens einer über den nativen Datenbankkatalog auflösbaren Identität und
konsistenter Cache-MB-Berechnung. Semaphore- und Clerk-Arrays waren positiv und
hielten die jeweiligen Ausgabelimits ein. Alle geprüften Hüllen waren gültig
und nicht partiell. Ein erster Test mit nur einem Verteilungseintrag scheiterte
an der kombinierten Verteilungsassertion (`55804`); der abschließende Vertrag verlangt
innerhalb des begrenzten Arrays einen nativ auflösbaren Eintrag.

Frameworkinstallation, Smoke-Test und Laufzeitvertrag bestanden. Beide eigenen
Container, Volumes und temporären Lab-States wurden entfernt. Die 75 lokalen
statischen Verträge bestanden ebenfalls. Der Nachweis belegt weder Hochlast
noch vollständige native Werteparität der Semaphore-, Clerk- oder Cachewerte.

## Internal Contention: 5. Oktober 2026

`Code/Tests/Common/132_InternalContention_Collation_Runtime_Contract.sql`
bestand in einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Der ursprüngliche Procedure-Stand reproduzierte mit demselben Vertrag die
fremde Latchexportcollation (`55811`). Alle zwölf Textspalten der lokalen
Latch-, Spinlock- und Hot-Page-Arbeitstabellen verwenden jetzt die
Frameworkcollation. Der abschließende TABLE-Export bestätigte diese Collation
für beide Textspalten. TABLE und JSON enthielten dieselben Latchklassen,
Messarten, Warteanforderungen und Wartezeiten. Der kumulative Aufruf lieferte
positive Wartezeiten, nativ auflösbare Klassen und keine Raten.

Die Sampleprüfung verlangt die angeforderte Sekunde und eine positive
tatsächliche Messdauer. Ein vorheriger Lauf scheiterte mit `55813`; die
anschließende numerische Diagnose zeigte 0,996 Sekunden bei korrekter Messart
und Ratenformel. Die zusätzliche Mindestdauerforderung des Tests wurde
korrigiert. Eine feste Gegenprobe der vorhandenen Rechenfunktion bestätigt
für ein Delta von 10 bei 0,996 Sekunden die Rate 10,0402. Emittierte
Nichtresetwerte werden gegen die tatsächliche Messdauer geprüft; ein leeres
Samplearray bleibt zulässig. Die Produktberechnung wurde nicht geändert.

Frameworkinstallation, Smoke-Test und abschließender Laufzeitvertrag bestanden.
Alle vier eigenen Container, Volumes und temporären Lab-States wurden entfernt.
Die 75 lokalen statischen Verträge bestanden ebenfalls. Der neue Vertrag
belegt keinen tatsächlichen Zählerreset, keinen positiven Hot-Page-Fall und
keine Hochlast; Spinlocks wurden aktiviert und auf gültige begrenzte Arrays
geprüft, jedoch nicht vollständig gegen native Zählerwerte abgeglichen.

## Server Security Configuration: 5. Oktober 2026

`Code/Tests/Common/133_ServerSecurity_Collation_Runtime_Contract.sql`
bestand in einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Die ursprüngliche Quelle reproduzierte mit demselben Vertrag die fremde
Konfigurationsexportcollation (`55821`). Alle vierzehn Textspalten der lokalen
Quellenstatus-, Konfigurations-, Dienst- und Eigenschaftstabellen verwenden
jetzt die Frameworkcollation. Der abschließende TABLE-Export bestätigte diese
Collation für Optionsname und Befund. Die konfigurierten und aktiven Werte
blieben als `sql_variant` erhalten; TABLE und JSON enthielten dieselben
Optionsnamen, Werte und Befunde.

Der positive Export enthielt `xp_cmdshell` und `clr strict security`. Seine
Optionsnamen und Werte stimmten in beide Richtungen mit der festen
Sieben-Optionen-Auswahl aus `sys.configurations` überein. Der JSON-Vertrag
meldete drei verfügbare Quellen, nicht partiellen Status und eine
Servereigenschaftszeile. Die dokumentierte Source-Select-Auswahl wurde auf die
sieben tatsächlich gelesenen Optionen berichtigt.

Frameworkinstallation, Smoke-Test und Laufzeitvertrag bestanden. Der eigene
Container, sein Volume und der temporäre Lab-State wurden entfernt. Die
75 lokalen statischen Verträge bestanden ebenfalls. Der Nachweis belegt
keine vollständige native Werteparität der Dienst- oder Servereigenschaften
und keine zusätzlichen Berechtigungs- oder Fehlerfälle. Es wurde keine
Serverkonfiguration verändert.

## Server Health Orchestrator: 5. Oktober 2026

`Code/Tests/Common/134_ServerHealth_Collation_Runtime_Contract.sql`
bestand in einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Die ursprüngliche Quelle reproduzierte mit demselben Vertrag die fremde
Modulstatusexportcollation (`55831`). Die drei Textspalten der lokalen
Modulstatustabelle verwenden jetzt die Frameworkcollation; der TABLE-Export
bestätigte sie für Modulname, Statuscode und Fehlertext.

Der gezielte Aufruf nur mit Security lieferte genau das erwartete Modul.
Der erweiterte Aufruf lieferte zusätzlich Performance Counters, Internal
Contention und Buffer Pool mit den festgelegten Modulordinals und Namen.
Alle exportierten Childstatuses waren verfügbar und nicht partiell; der
Wrapper meldete `AVAILABLE` ohne Warnings. Die aktivierten JSON-Children
enthielten positive Konfiguration, begrenzte Counter, eine Memoryzeile und
ein Contention-Sample mit fünf angeforderten sowie positiven tatsächlichen
Messsekunden. Die Buffer-Pool-Verteilung blieb deaktiviert.

Der unabhängige Review ergänzte die Prüfung deaktivierter Children:
Alle erwarteten Schlüssel müssen vorhanden sein und JSON-Typ `null` haben;
fehlende Schlüssel und unerwartete skalare Werte werden damit abgelehnt.
Die korrigierte kanonische Fassung bestand die abschließende native Gegenprobe.
Das irrtümlich genannte Worker-Pressure-Modul wurde aus der
Source-Select-Beschreibung entfernt; der Orchestrator ruft es nicht auf.

Frameworkinstallation, Smoke-Test und abschließender Laufzeitvertrag bestanden.
Beide eigenen Container, Volumes und temporären Lab-States wurden entfernt.
Die 75 lokalen statischen Verträge bestanden ebenfalls. Der neue Vertrag
belegt keinen vollständigen Default- oder Opt-in-Gesamtumfang, keine Hochlast
und keine vollständige native Werteparität sämtlicher Childresultate.

## Worker Pressure: 5. Oktober 2026

`Code/Tests/Common/135_WorkerPressure_Collation_Runtime_Contract.sql`
bestand abschließend in einem neuen lokalen SQL-Server-2025-Docker-Container
mit `Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Die ursprüngliche Quelle reproduzierte die fremde Exportcollation (`55841`).
Die zusätzlichen 24 Textspalten der lokalen Snapshot-, Ergebnis- und
Statustabellen verwenden jetzt die Frameworkcollation. Der Vertrag prüft
alle 22 Textspalten der sieben TABLE-Exporte, vier verfügbare Quellen,
den nicht partiellen Modulstatus und leere Warnings. Snapshot und
Ein-Sekunden-Sample besitzen positive native Scheduleridentitäten und
Workerwerte; Kapazität und Belegungsanteil werden gegen die Rechenformeln
geprüft. Sechs Ergebnisarrays werden einschließlich Zeilenhäufigkeiten
zwischen TABLE und JSON abgeglichen.

Ein vorheriger Lauf scheiterte mit `55840`. Die kontrollierte Diagnose mit
zwei eigenen blockierten Requests bestätigte zwei TABLE-Zeilen trotz
`ReturnedRequestRows=1` und `HasMoreRequestRows=1`. Die Requesttabelle wird
jetzt nach Materialisierung der Kandidatenaggregate und des Modulstatus
mit derselben Prioritätsreihenfolge wie RAW und JSON begrenzt. Der
abschließende Lauf verwendete erneut zwei eigene blockierte Requests und
zusätzliche Assertions: Beide Messarten lieferten genau eine Ausgabezeile,
zwei Quellenkandidaten und `HasMoreRequestRows=1`. Diese kontrollierte
Fixture ergänzt den kanonischen Vertrag und wird nicht durch dessen
alleinigen Aufruf erzeugt.

Frameworkinstallation, Smoke-Test und abschließender Laufzeitvertrag bestanden.
Alle vier eigenen Container, Volumes und temporären Lab-States wurden entfernt.
Die 75 lokalen statischen Verträge und der unabhängige Review bestanden.
Der neue Nachweis belegt keinen positiven THREADPOOL-Wait, keinen tatsächlichen
Zählerreset, keine Hochlast und keine zusätzlichen Berechtigungsfehler.

## Audit Configuration: 5. Oktober 2026

`Code/Tests/Common/136_AuditConfiguration_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Die ursprüngliche Quelle reproduzierte die fremde Exportcollation (`55851`).
Die zusätzlichen 32 Textspalten der lokalen Zuordnungs-, Kandidaten-,
Ergebnis- und Statustabellen verwenden jetzt die Frameworkcollation. Der
Vertrag bestätigte sie für alle 27 Textspalten der fünf TABLE-Exporte.

Zwei synthetische, deaktivierte Audits besaßen jeweils eine Server- und
eine Datenbankspezifikation. Eine Spezifikation je Ebene war aktiviert,
die andere deaktiviert; beide Auditziele blieben deaktiviert. Vier Aufrufe
prüften unbegrenzte Fachausgabe, Limit eins, ausschließlich problematische
Konfigurationen und den bestehenden Filtervertrag bei
`@NurProblematisch=NULL`. TABLE und JSON enthielten in allen Fällen dieselben
fünf Ergebnisarrays einschließlich Zeilenhäufigkeiten. Die Quellen meldeten
weiterhin jeweils zwei Konfigurationen und Warnings vier Befunde; Auswahl
und Limit veränderten ausschließlich die Fachausgabe.

Auditidentität, Zieltyp, Fehlerverhalten, Queueverzögerung, zugeordnete
Spezifikationsanzahlen sowie Spezifikationsidentität, Aktivierungszustand
und Aktionsanzahl wurden gegen native Metadaten geprüft. Die beiden
exportierten `SpecificationId`-Spalten waren `int`; das Resultsetinventar
und der fehlerhafte Auditstatus-Beispieljoin wurden entsprechend berichtigt.

Frameworkinstallation, Smoke-Test, neuer Vertrag und bestehender
Audit-Laufzeitvertrag `124` bestanden. Ein vorheriger Versuch scheiterte
mit `33074`, weil die neue Fixture ihr Serveraudit im Datenbankkontext
löschen wollte; alle Server-DDL-Aufrufe verwenden jetzt `master`. Beide
eigenen Container, Volumes und temporären Lab-States wurden entfernt.
Der bestehende Vertrag bestätigte zusätzlich Leerinventur, verweigerte
Metadaten, deaktiviertes Audit und aktiven Runtimezustand. Der neue Vertrag
belegt keine Auditpayloads, Ereigniszustellung, Aufbewahrung oder Hochlast.
Die 75 lokalen statischen Verträge und der unabhängige Review bestanden.

## Database Integrity: 5. Oktober 2026

`Code/Tests/Common/137_DatabaseIntegrity_Collation_Runtime_Contract.sql`
bestand abschließend auf einem neuen lokalen SQL-Server-2025-Docker-Container
mit `Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Die ursprüngliche Quelle reproduzierte die fremde Exportcollation (`55861`).
Alle 15 Textspalten der lokalen Kandidaten-, Warnungs-, Integritäts- und
Seitendetailtabellen verwenden jetzt die Frameworkcollation. Der Vertrag
bestätigte sie für die fünf Textspalten des Integritäts-TABLE-Exports.

Der kontrollierte Scope umfasste die eigene Frameworkdatenbank und die
Systemdatenbank `master` im neu erzeugten Container. Ein synthetischer
`msdb.dbo.suspect_pages`-Eintrag für die Frameworkdatenbank blieb
transaktional und wurde zurückgerollt. Drei Aufrufe mit `@MaxZeilen=0`, `1` und `NULL` lieferten die erwarteten zwei, eine und zwei
Integritätszeilen. TABLE und JSON enthielten dieselben Ergebnisse
einschließlich Zeilenhäufigkeiten. Native Datenbankidentität, Status,
PAGE_VERIFY und Suspect-Page-Anzahl wurden gegengeprüft; CHECKDB-Zeit und
Nachweisalter blieben unbekannt.

Der erste Lauf und die zusätzliche numerische Diagnose scheiterten mit
`55864`: Die Seitendetailzeile und ihre native Gegenzeile waren vorhanden,
aber der Test verglich zwei unbekannte Seitenbeschreibungen mit Gleichheit.
`LIMITED` liefert Beschreibungsspalten als `NULL`. Der korrigierte Vertrag
verlangt dieses Ergebnis ausdrücklich und prüft Objekt-, Index-, Partitions-
und Allocation-Unit-Headerwerte NULL-sicher gegen `sys.dm_db_page_info`.
Der Produktmodus wurde nicht verändert. Ohne Opt-in blieb das Detailarray leer.

Die erste Head-CI scheiterte mit `55860`, weil der Test beim Ein-Zeilen-Limit
die Frameworkdatenbank unabhängig von ihrem Namen als erste Zeile erwartete.
Bei gleicher Befundpriorität entscheidet jedoch die bestehende Sortierung
nach Datenbankname und Datenbank-ID. Der korrigierte Vertrag ermittelt diese
Reihenfolge nativ und verlangt den positiven Suspect-Page-Indikator in beiden
unbegrenzten Fällen. Eine zusätzliche Gegenprüfung mit einer synthetischen
Frameworkdatenbank, die nach `master` sortiert, reproduzierte den ursprünglichen
Collationfehler und bestand mit der korrigierten Quelle und dem finalen Vertrag.
Die Produktsortierung wurde nicht verändert.

Frameworkinstallation, Smoke-Test und abschließender Laufzeitvertrag bestanden.
Alle vier eigenen Container, Volumes und temporären Lab-States wurden entfernt.
Die 75 lokalen statischen Verträge und der unabhängige Review bestanden.
Der synthetische Indikator belegt keine reale Beschädigung, keinen erfolgreichen
CHECKDB, keine HADR-Reparatur und keine positiven beschädigten Backupmetadaten.

## Database Capacity: 5. Oktober 2026

`Code/Tests/Common/138_DatabaseCapacity_Collation_Runtime_Contract.sql`
bestand abschließend auf einem neuen lokalen SQL-Server-2025-Docker-Container
mit `Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Die ursprüngliche Quelle reproduzierte die fremde Exportcollation (`55871`).
Alle 17 Textspalten der lokalen Kandidaten-, Warnungs- und Kapazitätstabellen
verwenden jetzt die Frameworkcollation. Der Vertrag bestätigte sie für die
neun Textspalten des Kapazitäts-TABLE-Exports. Die gemeinsame Ausgabemenge
berücksichtigt den vorhandenen Problemfilter und das Zeilenlimit erst nach
Quellenaggregation und Statusermittlung.

Der erste Lauf und die zusätzliche numerische Diagnose scheiterten mit
`55872`. Die Diagnose zeigte eine abweichende Dateibelegung zwischen
Procedure und Gegenprüfung; Identitäts-, Wachstums- und Volumeindikatoren
stimmten überein. Die finale Fixture erzeugt deshalb eine eigene Quelldatenbank,
deaktiviert das Wachstum ihrer Datendatei und setzt sie vor den Aufrufen
schreibgeschützt. Bestehende Datenbanken werden bei Namenskollision nicht
verwendet. Die eigene Quelldatenbank wird im Erfolgs- und Fehlerpfad entfernt.
Der exakte native Vergleich wurde beibehalten.

Vier Aufrufe prüften unbegrenzte Ausgabe, Limit eins, Problemfilter eins und
den bestehenden NULL-Problemfilter mit unbegrenztem NULL-Limit. Native
Datenbank- und Dateiidentität, Größe, Belegung, Freiraum, MaxSize,
Wachstumsbeschreibung, nächster Wachstumsschritt und Befund wurden
gegengerechnet. Der kontrollierte `GROWTH_DISABLED`-Befund blieb in allen
unbegrenzten Fällen erhalten. TABLE und JSON enthielten dieselben Ergebnisse
einschließlich Zeilenhäufigkeiten. Volumegröße, verfügbarer Platz und
Freiraumprozent wurden auf Plausibilität geprüft; eine exakte zeitgleiche
Volumeparität wird nicht behauptet.

Frameworkinstallation, Smoke-Test und finaler Laufzeitvertrag bestanden.
Alle drei eigenen Container, Volumes und temporären Lab-States wurden entfernt.
Die 75 lokalen statischen Verträge und der unabhängige Review bestanden.
Die pfad- und matchgebundene Datenschutz-Ausnahme betrifft ausschließlich
den geprüften synthetischen USE-Kontext der eigenen Testdatenbank.
Der Vertrag belegt keine reale Dateivergrößerung, Storage-Hochlast,
Wachstumsrate oder Zeit-bis-voll-Prognose.

## Critical Engine Events: 5. Oktober 2026

`Code/Tests/Common/139_CriticalEngineEvents_Collation_Runtime_Contract.sql`
bestand abschließend auf einem neuen lokalen SQL-Server-2025-Docker-Container
mit `Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Die ursprüngliche Quelle reproduzierte die fremde Exportcollation (`55881`).
Alle zwölf Textspalten der lokalen Ereignis-, Diagnostics- und
Quellenstatustabellen verwenden jetzt die Frameworkcollation. Der Vertrag
bestätigte sie für die fünf Textspalten des Ereignis-TABLE-Exports.

Die Fixture erzeugte eine eigene XE-Session mit Kollisionsprüfung und
zwei abgefangene synthetische Fehlerereignisse der Severity 16. Der
Dateipfad wurde nur im Speicher aus dem nativen Standardpfad und einer
eigenen Laufzeitkennung gebildet. Nach Flush und Sessionstopp bestätigte
der native Dateileser beide Ereignisse. Drei Aufrufe mit `@MaxZeilen=0`,
`1` und `NULL` lieferten zwei, eine und zwei Ereigniszeilen. TABLE und JSON
enthielten dieselben Ergebnisse einschließlich Zeilenhäufigkeiten; beide
unbegrenzten Fälle wurden zusätzlich als Multiset gegen die native
Ereignismenge geprüft. Zeit, Ereignisname, Fehlernummer, Severity,
optionale Komponentenfelder und Meldung wurden gegengeprüft. Der Opt-in
lieferte das native Ereignis-XML; ohne Opt-in blieb die XML-Spalte `NULL`.
Der begrenzte Fall enthielt das jüngste Ereignis.

Die ersten zwei Läufe scheiterten vor der Collationreproduktion: `1934`
wies auf das fehlende `QUOTED_IDENTIFIER ON` im XML-Test hin; `515`
zeigte eine unzulässig nicht nullable `sysname`-Spalte für ein optionales
XE-Feld. Der finale Test setzt die XML-Voraussetzung und deklariert die
nativen Vergleichsspalten explizit nullable. Die Produktänderung blieb
auf die zwölf Collationangaben beschränkt.

Frameworkinstallation, Smoke-Test und finaler Laufzeitvertrag bestanden.
Alle drei eigenen Container, Volumes und temporären Lab-States wurden entfernt.
Die 75 lokalen statischen Verträge und der unabhängige Review bestanden.
Der neue Vertrag belegt keinen realen schweren Enginefehler, keinen
Ringbufferzugriff und keinen positiven Diagnostics-One-Shot. Er ändert
weder den vorhandenen Kandidatenlimit- noch den nachfolgenden Severityfilter.

## Diagnostic Findings: 5. Oktober 2026

`Code/Tests/Common/140_DiagnosticFindings_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Die ursprüngliche Quelle reproduzierte die fremde Exportcollation (`55891`).
Die zehn Textspalten der lokalen Befundtabelle und die vier Textspalten der
Modulstatusvariable verwenden jetzt explizit die Frameworkcollation. Der
Vertrag bestätigte die zehn Textspalten des Befund-TABLE-Exports.
Die gemeinsame Prioritätsfilterung und Zeilenbegrenzung erfolgen nach
Befunderzeugung, Statusermittlung und Sicherung der bisherigen Zähler.

Drei synthetische Parent-Ergebnisse lieferten vier kontrollierte HIGH-,
MEDIUM- und LOW-Befunde. Fünf Aufrufe prüften vollständige Ausgabe, Limit eins,
MEDIUM-Auswahl, HIGH-Auswahl mit NULL-Limit und partielle Parent-Evidenz.
Die erwarteten zwölf Befundfelder einschließlich Ordinal, Unicode-Scope,
Messwert, Aussagegrenze und nächster Prüfung wurden als Multiset mit dem
TABLE-Export verglichen. TABLE und JSON enthielten dieselben Ergebnisse
einschließlich Zeilenhäufigkeiten. Die drei Modulstatuszeilen belegten
`REUSED_PARENT_RESULT`; der partielle Parent blieb als `AVAILABLE_LIMITED`
sichtbar. Bei Limit eins blieb `returnedFindingCount=4`, während das
Findingarray und TABLE eine Zeile enthielten; die bisherige Zählersemantik
wurde beibehalten.

Ein getrennt ausgeführter Integritäts-Child-Aufruf ohne Parent-Ergebnis
bestätigte `EXECUTED`, den eigenen nativen Datenbankscope und den LOW-Befund
zur nicht verfügbaren CHECKDB-Zeitevidenz. Die synthetischen Parent-Felder
belegen keine reale Beschädigung oder tatsächlichen Speicherdruck.

Frameworkinstallation, Smoke-Test und Laufzeitvertrag bestanden. Der eigene
Container, sein Volume und der temporäre Lab-State wurden entfernt.
Die 75 lokalen statischen Verträge und der unabhängige Review bestanden.
Der neue Vertrag belegt keine atomare Childerhebung und keine zusätzliche
Opt-in-, Berechtigungs- oder Hochlastvariante.

## Database Configuration: 5. Oktober 2026

`Code/Tests/Common/141_DatabaseConfiguration_Collation_Runtime_Contract.sql`
bestand in einem neu erzeugten lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Der ursprüngliche Procedure-Stand reproduzierte die fremde Exportcollation
(`55901`). Die 38 zusätzlich annotierten lokalen Textspalten verwenden jetzt
die Frameworkcollation; mit den vier bereits annotierten Spalten sind es
42 lokale Textspalten. Der abschließende Lauf bestätigte diese Collation für
alle 32 Textspalten der sechs TABLE-Exporte.

Ein vorheriger Testlauf scheiterte vor der Baseline mit `102`, weil der Test
einen Funktionsaufruf direkt als EXEC-Argument verwendete. Nach der Korrektur
reproduzierte die Baseline `55901`; der korrigierte Export scheiterte an der
Statusprüfung (`55902`). Zwei zusätzliche Diagnosen grenzten die fehlenden
lokalen Kataloge auf die dynamische Zeichenfolge ein. Deren Zwischenkürzung
führte zu `137` mit einem abgeschnittenen Variablennamen und zu `102`.
Der Ausdruck beginnt jetzt mit einem `nvarchar(max)`-Operanden. Der
abschließende Lauf bestätigte beide datenbanklokalen Quellen ohne Teilstatus.

Der Vertrag prüft die Frameworkdatenbank und `master` mit explizitem
Systemdatenbank-Opt-in. Native Datenbankoptionen, Scoped Configurations samt
Secondary-Wert und Defaultstatus sowie feste Query-Store-Optionen stimmen mit
dem Export überein. Flüchtiger Query-Store-Zustand wird auf zulässige Werte
und numerische Plausibilität geprüft; eine zeitübergreifende exakte Parität
wird dafür nicht behauptet. Alle sechs erwarteten Datenbank-/Quellenpaare
sind eindeutig und verfügbar. Der bisherige 14er-Quellenzähler für
Datenbankoptionen vor der optionalen Optimized-Locking-Zeile bleibt erhalten.

Vier synthetische Profileinträge liefern vier native Profilabweichungen,
einen passenden AUTO_CLOSE-Wert und eine Warnung für einen nicht sichtbaren
Profileintrag. Die native Collationvariation ist positiv. Die Läufe mit
`@MaxZeilen=0`, `1` und `NULL` bestätigen die gemeinsamen Settings-/Driftlimits,
Modulzähler, HasMore-Kennzeichen und ungekürzten Profil-, Quellen- und
Warnungsexporte. Bei Limit eins entspricht die erste Driftzeile der nativen
Optionsvariation. Fünf JSON-Arrays stimmen als typisierte Multimengen mit
TABLE überein; das Profil wird zusätzlich gegen das Eingabearray geprüft.

Die erste Head-CI scheiterte mit `55905`, weil der Test eine Collationvariation
auch bei identischen nativen Quelldatenbankcollations verlangte. Die
Erwartung wird jetzt aus den nativen Werten abgeleitet. Ein weiterer eigener
Misch-Collation-Lauf bestätigte den positiven Fall. Eine zusätzliche eigene
synthetische Quelldatenbank mit derselben Collation wie `master` bestätigte
den Fall ohne Collationdrift; der Aufruf verwendete die vollständig
qualifizierte Frameworkprocedure. Beide Gegenproben bestanden mit derselben
kanonischen Testdatei und unverändertem Produktcode.

Frameworkinstallation, Smoke-Test und abschließender Laufzeitvertrag bestanden.
Alle sieben eigenen Container, Volumes und temporären Lab-States wurden entfernt.
Die 75 lokalen statischen Verträge und der unabhängige Source-/Testreview
bestanden. Dieser Vertrag belegt keine Berechtigungsverweigerung, Sperrlast,
atomare datenbankübergreifende Momentaufnahme oder weitere native Engineversion.

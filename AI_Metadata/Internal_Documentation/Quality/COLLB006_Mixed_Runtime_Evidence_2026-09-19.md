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

## Error Log: 5. Oktober 2026

`Code/Tests/Common/142_ErrorLog_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Die ursprüngliche Quelle reproduzierte die fremde Exportcollation (`55911`).
Die 35 zusätzlich annotierten lokalen Textspalten verwenden jetzt die
Frameworkcollation; mit den zwei vorhandenen Mappingtextspalten sind es
37 lokale Textspalten. Der abschließende Lauf bestätigte die Collation
aller 22 Textspalten der fünf TABLE-Exporte.

Zwei eigene synthetische Unicode-Meldungen wurden mit `RAISERROR WITH LOG`
erzeugt und über einen nur im Speicher geführten eindeutigen Marker aus
`master.sys.sp_readerrorlog` gelesen. Der native Vergleich bestätigte genau
zwei getrennte Zeitpunkte sowie die Umlaute Ä und Ü. Fünf Aufrufe prüften
Summary ohne Detailtext, vollständige Details, Detaillimit eins, NULL-Limit
mit zwölf Zeichen Textprojektion und Quelllimit eins. Summary, native
Detailfelder und Unicode-Längen stimmen mit dem Export überein. Die vier
JSON-Arrays stimmen als typisierte Multimengen einschließlich
Zeilenhäufigkeiten mit TABLE überein.

Das gemeinsame Detaillimit greift nach vollständigen Modul-, Summary- und
Quellenzählern. Limit eins erhält die zwei akzeptierten Quellzeilen und den
Summaryzähler; TABLE und JSON enthalten dieselbe jüngste Detailzeile und
`HasMoreDetailRows=1`. Quelllimit eins akzeptiert nur die jüngste Zeile,
behält den nativen Lesezähler zwei und liefert `AVAILABLE_LIMITED` sowie
beide bestehenden Quelllimitwarnungen. Die Kürzungswarnung verwendet
weiterhin den vor der Detailbegrenzung gesicherten vollständigen Zähler.

Die ersten zwei Läufe scheiterten nach der Baselinereproduktion mit
`55913`. Der diagnostische zweite Lauf grenzte den Vergleich auf eine
skalare leere `FOR JSON`-Subquery im neuen Test ein: Ohne Details war deren
Wert NULL, während das Modularray korrekt `[]` enthielt. Nur diese native
Vergleichsseite wird jetzt auf das leere Array normalisiert; die vier
Modularrays bleiben obligatorisch. Der Produktcode wurde dadurch nicht
verändert.

Frameworkinstallation, Smoke-Test und abschließender Laufzeitvertrag bestanden.
Alle drei eigenen Container, Volumes und temporären Lab-States wurden entfernt.
Die 75 lokalen statischen Verträge und der unabhängige Review bestanden.
Der neue Vertrag belegt keinen realen Enginefehler, keinen Agent- oder
Archivpfad und keine zusätzliche Berechtigungs- oder Hochlastvariante.
Er rotiert keine Logs und ändert keine Logkonfiguration.

## Backup Chain: 5. Oktober 2026

`Code/Tests/Common/143_BackupChain_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Der ursprüngliche Stand reproduzierte die fremde Exportcollation (`55921`).
Alle 16 lokalen Textspalten verwenden jetzt die Frameworkcollation.
Der Vertrag bestätigte die fünf Textspalten des Summary-TABLE-Exports.
Summary und Backups werden erst nach vollständiger Kettenberechnung und
Statusermittlung gemeinsam für TABLE und JSON begrenzt.

Der Test erzeugte nach Namens- und Historienpreflight zwei eigene synthetische
Datenbanken mit SIMPLE Recovery und abweichender Quelldatenbankcollation.
Eine Quelle blieb ohne Backup. Für die andere wurden ein Full ohne
Prüfsumme, ein zweites Full mit Prüfsumme und danach ein Differential mit
Prüfsumme erstellt. Die native Differentialbasis entsprach dem Checkpoint-LSN
des zweiten Full. Native Flags bestätigten normale unbeschädigte und
unverschlüsselte Backupsets; der positive Ohne-Prüfsumme-Zähler war eins.

Vier Aufrufe mit Limit null, eins und NULL sowie eingeschalteter und
ausgeschalteter Restoreevidenz bestätigten `AVAILABLE_WITH_FINDING` ohne
Teilstatus. Die fehlende Full-Evidenz blieb HIGH; das Backup ohne Prüfsumme
blieb MEDIUM. Die 15 Summaryfelder wurden gegen native Datenbank- und
Backupmetadaten geprüft; TABLE und JSON stimmen als typisierte Multimengen
überein. Alle 19 Backupfelder einschließlich LSNs, Forkkennungen, Flags und
Datumswerten wurden gegen die drei nativen Backupsets geprüft. Bei Limit
eins blieb der vollständige Ohne-Prüfsumme-Zähler eins erhalten, obwohl das
Backup-JSON nur das jüngste checksummierte Differential enthielt.

Der unabhängige Review ergänzte strengere NULL-Prüfungen für das
obligatorische leere Warningarray und native Backupflags. Der erste native
Lauf bestand vor diesen Ergänzungen; der zweite Lauf bestätigte die
abschließende kanonische Testdatei. Der Produktcode blieb unverändert.
Eigene Datenbanken und deren msdb-Historie wurden auch beim erwarteten
Baselinefehler bereinigt. Die Backupgeräte wurden nur im Speicher geführt.

Frameworkinstallation, Smoke-Test und abschließender Laufzeitvertrag bestanden.
Beide eigenen Container, Volumes und temporären Lab-States wurden entfernt;
damit sind auch ihre eigenen Backupdateien entfernt. Die 75 lokalen
statischen Verträge und der unabhängige Review bestanden. Dieser Vertrag
belegt keinen Restore, keine Wiederherstellbarkeit, Logkettenlücke,
Beschädigung, Copy-only-Variante oder zusätzliche Berechtigungssituation.
## Agent- und Infrastrukturstatus: 5. Oktober 2026

`Code/Tests/Common/144_Infrastructure_Status_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Die ursprünglichen Prozeduren reproduzierten ihre fremde Exportcollation
getrennt mit `55931` für Agentstatus und `55933` für Infrastruktur-Modulstatus.
Alle sechs betroffenen TABLE-Textspalten verwenden jetzt die Frameworkcollation.
Die vorhandenen Ausgabe-, Status- und Auswahlverträge bleiben erhalten.

Der Test legte nach Namenspreflight zwei eigene Jobdefinitionen mit
Unicode-Namen an, eine aktiviert und eine deaktiviert. Er legte keine Schritte
oder Zeitpläne an und startete keine Jobs. Native Jobzähler und die acht
Agentstatusfelder wurden gegen den TABLE-Export geprüft; TABLE und JSON
wurden als typisierte Multimengen verglichen. Die native Abfrage lieferte
bei der getrennten Parent-Baselineprüfung eine Agentservicezeile.
`LastStartupTime` stammt weiterhin aus dem maximalen Agentstartdatum in
`msdb.dbo.syssessions`.

Vier Parent-Aufrufe prüften deaktivierte Children, Agent allein, Agent mit
BackupChain sowie einen ungültigen negativen Zeilenparameter. Die elf
Child-JSON-Schlüssel enthalten für deaktivierte Children explizit NULL.
Agentdaten und dessen Statusmetadaten stimmen mit dem direkten Child-Aufruf
überein. Der Legacy-Modulstatus `EXECUTED` bleibt von dessen fachlichem
Child-Status getrennt. BackupChain bestätigte die fehlende Full-Evidenz der
eigenen Frameworkdatenbank; dafür wurde kein Backup erzeugt. Native Jobzähler
wurden nach Entfernung ausschließlich der eigenen Jobkennungen wiederhergestellt.

Der erste Lauf bestand den SQL-Vertrag. Anschließend scheiterte die private
Hilfsrunner-Auswertung, weil die öffentliche Lab-API bei Erfolg keine rohe
SQL-Ausgabe in ihrer Erfolgsmeldung zurückgibt. Die korrigierte Auswertung
liest die Servicezeilenbeobachtung aus der erwarteten Parent-Baselinefehlermeldung;
der zweite Lauf bestand auch den Hilfsrunner. Produktcode und kanonischer
SQL-Test blieben zwischen beiden Läufen unverändert.

Frameworkinstallation, Smoke-Test und abschließender Laufzeitvertrag bestanden.
Beide eigenen Container, Volumes und temporären Lab-States wurden entfernt.
Die 75 lokalen statischen Verträge und der unabhängige Review bestanden. Dieser Vertrag belegt keinen
Joblauf, keine Jobhistorie, keinen positiven Agentstartzeitpunkt und keine
zusätzliche Berechtigungs- oder Hochlastvariante. Er ändert weder
Agentservicekonfiguration noch Startzustand.

## Resource Governor: 5. Oktober 2026

`Code/Tests/Common/145_ResourceGovernor_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Der ursprüngliche Stand reproduzierte die fremde Exportcollation (`55941`).
Weitere 26 lokale Textspalten verwenden jetzt die Frameworkcollation;
damit sind alle 28 lokalen Textspalten explizit collatiert. Der Vertrag
bestätigte die 16 Textspalten der fünf TABLE-Exports. Die vorhandene gemeinsame
Materialisierung und ihre Ausgabegrenzen bleiben unverändert.

Vier Aufrufe mit Limit null, eins und NULL sowie deaktiviertem Sessionpfad
bestätigten `AVAILABLE` ohne Teilstatus und mit leerem Warningarray. Native
Konfiguration, Poolinventar, Gruppeninventar und gespeicherte TempDB-Limits
wurden mit vier, neun, zehn beziehungsweise sechs Feldern geprüft. Bei
Limit eins wurden jeweils der erste Pool und die erste Gruppe nach Kennung
sowie genau eine Session ausgegeben; die Konfigurationszeile blieb erhalten.
Die unbegrenzten Sessionfälle enthielten die eigene Benutzersession.
Gruppen- und Poolzuordnung sowie die Umrechnung von Speicherseiten in MB
wurden geprüft. Der deaktivierte Sessionpfad lieferte ein leeres Array.
Alle fünf TABLE-/JSON-Arrays stimmen als typisierte Multimengen überein;
der vorherige `LOCK_TIMEOUT` wurde wiederhergestellt.

Die vorhandenen nativen Gruppen besaßen keine TempDB-Limits. Die Ausgabe
bestätigte `NO_LIMIT_CONFIGURED`, NULL für Wirksamkeit und Auslastung sowie
verfügbare nichtnegative Nutzungs-, Peak- und Verletzungswerte. Kumulative
Livezähler wurden nicht zwischen verschiedenen Aufrufen als identischer
Snapshot ausgegeben. Es wurden weder Pools oder Gruppen verändert noch
Resource Governor rekonfiguriert oder Statistiken zurückgesetzt.

Die ersten zwei Läufe scheiterten nach Baselinereproduktion mit `55944`.
Der private diagnostische Lauf grenzte den Unterschied auf die native
JSON-Zahl `0` gegenüber dem öffentlichen `bit`-Wert false für
`ReconfigurationPending` ein. Die native Vergleichsseite konvertiert jetzt
explizit in den bestehenden Exporttyp. Der dritte Lauf bestätigte die
abschließende kanonische Testdatei; der Produktcode blieb unverändert.

Frameworkinstallation, Smoke-Test und abschließender Laufzeitvertrag bestanden.
Alle drei eigenen Container, Volumes und temporären Lab-States wurden entfernt.
Die 75 statischen Verträge wurden ausgeführt. Nach Wiederherstellung des
vorgeschriebenen Dokumentationsmarkers und erneuter Installergenerierung nach
dem Main-Abgleich bestanden auch die beiden zunächst fehlgeschlagenen Gates
in gezielten Wiederholungen. Der unabhängige Source- und Testreview bestand.
Dieser Vertrag belegt keine aktive TempDB-Begrenzung, Limitverletzung,
Drosselungsursache oder zusätzliche Berechtigungs- und Hochlastvariante.

## Backup Recovery: 5. Oktober 2026

`Code/Tests/Common/146_BackupRecovery_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Der ursprüngliche Stand reproduzierte die fremde Exportcollation (`55951`).
Alle 20 lokalen Textspalten verwenden jetzt die Frameworkcollation;
der Vertrag bestätigte die vier Textspalten des Freshness-TABLE-Exports.
Ein zweiter kontrollierter Stand mit behobener Collation, aber unveränderter
Freshnessbegrenzung reproduzierte die ignorierte positive Ausgabegrenze
getrennt (`55952`). Freshness wird jetzt nach vollständiger Bewertung gemeinsam
für RAW, TABLE und JSON begrenzt. Der vorhandene Status- und Namensrang bleibt
maßgeblich; Backup- und Restorehistorie behalten ihre separaten Grenzen.

Der Test erzeugte nach Namens- und Historienpreflight zwei eigene synthetische
Datenbanken mit SIMPLE Recovery und abweichender Quelldatenbankcollation.
Eine Quelle blieb ohne Backup. Die andere erhielt ein normales Full, ein
Differential und danach ein Copy-only Full, jeweils mit Prüfsumme. Native
Metadaten bestätigten genau diese drei unbeschädigten Backupsets. Die letzte
normale Fullzeit und die spätere Copy-only-Fullzeit wurden getrennt geprüft.

Vier Aufrufe mit Limit null, eins und NULL sowie aktiviertem und deaktiviertem
Restorepfad bestätigten den vorhandenen Modulstatus `AVAILABLE` ohne Teilstatus.
Die Quelle ohne Full blieb `NO_FULL_BACKUP`, die gesicherte SIMPLE-Quelle `OK`.
Bei Limit eins blieb die Quelle ohne Full im Freshnessresultat; das Backup-JSON
enthielt unabhängig davon das jüngste Copy-only Full. Acht Freshnessfelder
wurden gegen native Metadaten geprüft; die drei Altersfelder lagen in den
nativen Vorher-/Nachher-Minutenintervallen oder blieben bei fehlender Quelle
NULL. Alle elf TABLE-/JSON-Freshnessfelder stimmen als typisierte Multimengen
überein. Alle 13 Backupfelder wurden gegen die eigenen Backup- und
Medienmetadaten geprüft; `IsSnapshot` bleibt gemäß bestehender Projektion NULL.
Restore- und Warningarrays waren obligatorisch leer.

Der erste Lauf bestand vor der Verlängerung der Zwischenbackup-Pausen von
250 Millisekunden auf eine Sekunde. Der zweite Lauf bestätigte die abschließende
kanonische Testdatei und die getrennte Limitreproduktion. Die Pausen sichern
unterschiedliche Full- und Copy-only-Zeitstempel; der Produktcode blieb unverändert.
Eigene Datenbanken und deren Historie wurden auch nach den erwarteten
Baselinefehlern ausschließlich über eigene Erzeugungsflags und Datenbankkennungen
entfernt. Konkrete Backupgeräte blieben im Speicher.

Frameworkinstallation, Smoke-Test und abschließender Laufzeitvertrag bestanden.
Beide eigenen Container, Volumes und temporären Lab-States wurden entfernt;
damit sind auch ihre eigenen Backupdateien entfernt. Die 75 lokalen statischen
Verträge und der unabhängige Source- und Testreview bestanden. Dieser Vertrag
belegt keinen Restore, keine Wiederherstellbarkeit, Logbackupkette, Snapshot-
oder zusätzliche Berechtigungs- und Hochlastvariante.

## Data Capture Status: 5. Oktober 2026

`Code/Tests/Common/147_DataCapture_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Der ursprüngliche Stand reproduzierte die fremde Exportcollation (`55961`).
Alle 30 lokalen Textspalten verwenden jetzt die Frameworkcollation; fünf
Textspalten des Datenbankexports wurden nativ geprüft. Die erste Erhebung
scheiterte zusätzlich an einem vorhandenen Syntaxfehler im dynamischen
CDC-Batch. Die private Diagnose bestätigte Fehler 156 auch ohne aktiviertes
CDC: Der Funktionsausdruck im verschachtelten EXEC-Argument verhinderte die
Kompilierung des gesamten Datenbankbatches. Der CDC-Aufruf verwendet jetzt
`sys.sp_executesql` mit einem gebundenen Zeilenparameter. Ein kontrollierter
Stand mit korrigierter Collation und Syntax, aber ohne gemeinsame
Datenbankbegrenzung reproduzierte anschließend getrennt `55962`.

Der Test erzeugte nach Namenspreflight zwei eigene synthetische
Unicode-Datenbanken mit abweichender Quelldatenbankcollation. Beide erhielten
Change Tracking mit zwei Tagen Retention und automatischem Cleanup sowie je
zwei eigene Tabellen. Die Aufzeichnung von Spaltenänderungen war bei einer
Tabelle pro Datenbank aktiviert. Native Metadaten bestätigten zwei CT-Datenbanken,
vier CT-Tabellen und positive aktuelle Versionen.

Vier Aufrufe mit Limit null, eins und NULL sowie einer zusätzlich angeforderten
nicht vorhandenen Datenbank bestätigten die fünf Exportcollations. Alle zehn
Datenbankfelder wurden gegen native Metadaten und zwischen TABLE und JSON
als typisierte Multimengen geprüft. Alle acht CT-Tabellenfelder wurden gegen
native Metadaten geprüft. Bei Limit eins lieferten Datenbank- und CT-Ausgabe
je eine Zeile gemäß ihrer eigenen Namenssortierung. Die zusätzliche fehlende
Datenbank blieb trotz begrenzter Ausgabe als `DATABASE_SELECTION`-Warning
mit `DATABASE_UNAVAILABLE` und im Modulstatus `PARTIAL_RESULT` sichtbar.
Die übrigen Fälle blieben `AVAILABLE`; CDC-Tabellen und CDC-Jobs waren leer.

Frameworkinstallation, Smoke-Test, abschließender Laufzeitvertrag und alle
75 lokalen statischen Verträge bestanden. Vier eigene Container, Volumes und
temporäre Lab-States wurden nach erfolgreichen oder fehlgeschlagenen Läufen
entfernt. Ein privater Diagnoselauf hatte zunächst einen Syntaxfehler in der
Diagnoseausgabe; nach dessen Korrektur wurde der Produktfehler nachgewiesen.
Die eigenen CT-Datenbanken wurden auch bei Baselinefehlern über eigene
Erzeugungsflags und Datenbankkennungen entfernt. Dieser Vertrag belegt keine
positive CDC-Erhebung, Change-Zeilenauslieferung, Consumer-Wasserstände,
Cleanup-Wirksamkeit oder zusätzliche Berechtigungs- und Hochlastvariante.

## Agent Monitoring: 5. Oktober 2026

`Code/Tests/Common/148_AgentMonitoring_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben.

Der ursprüngliche Stand reproduzierte die fremde Exportcollation (`55971`).
Alle 15 lokalen Textspalten verwenden jetzt die Frameworkcollation; sieben
Textspalten des Findings-TABLE-Exports wurden nativ geprüft. Ein kontrollierter
Stand mit korrigierter Collation, aber ohne gemeinsame Findingsbegrenzung
reproduzierte anschließend getrennt `55972`. Die vollständige Erhebung bestimmt
den Modulstatus vor der gemeinsamen Ausgabegrenze; der vorhandene Prioritäts-,
Kategorie- und Scoperang bleibt erhalten.

Der Test erzeugte nach einem Preflight auf leere Job-, Alert-, Notification-
und Mailbestände zwei eigene synthetische Unicode-Jobdefinitionen. Eine war
aktiviert, die andere deaktiviert. Beide besaßen keine Schritte, Zeitpläne
oder Historie und wurden nicht gestartet. Native Metadaten bestätigten die
beiden Jobzustände und die fehlende Abdeckung der zehn erforderlichen Alerts.

Vier Aufrufe mit Limit null, eins und NULL sowie deaktiviertem Job- und
Mailpfad bestätigten `AVAILABLE_WITH_FINDING` ohne Teilstatus oder Fehler.
Die Findingsmenge enthielt je nach Aufruf elf, eine oder zehn Zeilen; das
Job-JSON enthielt zwei, eine oder keine Zeile gemäß seinem eigenen Namensrang.
Die sechs fachlichen Findingfelder wurden gegen native Metadaten geprüft;
alle acht TABLE-/JSON-Findingfelder stimmen als typisierte Multimengen überein.
Alle zehn Jobfelder und fünf Servicefelder wurden gegen native Metadaten
geprüft. Mailstatus blieb obligatorisch leer. Evidenz und Aussagegrenze jeder
exportierten Findingzeile waren gefüllt.

Der erste Versuch scheiterte an einer ungültigen variablen LOCK_TIMEOUT-
Wiederherstellung im Test. Nach deren Korrektur bestand die abschließende
kanonische Testdatei mit beiden getrennten Baselinereproduktionen.
Frameworkinstallation, Smoke-Test und abschließender Laufzeitvertrag bestanden.
Beide eigenen Container, Volumes und temporären Lab-States wurden entfernt;
die eigenen Jobdefinitionen wurden auch bei erwarteten Baselinefehlern anhand
ihrer zurückgegebenen Kennungen gelöscht. Die 75 lokalen statischen Verträge,
der erneuerte Adaptervertrag sowie der unabhängige Source- und Testreview
bestanden. Dieser Vertrag belegt keine Jobausführung, positive Jobhistorie,
Alertzustellung, Operatorerreichbarkeit, Mailzustellung oder zusätzliche
Berechtigungs- und Hochlastvariante.

## Extended Events Target Runtime: 5. Oktober 2026

`Code/Tests/Common/149_XETargetRuntime_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben. Der ursprüngliche Stand reproduzierte die fremde
Exportcollation (`55981`). Alle acht Textspalten des Targetexports einschließlich
des optionalen MAX-Textdokuments verwenden jetzt die Frameworkcollation.

Der Test erzeugte nach Namenspreflight zwei eigene synthetische Unicode-
XE-Sessions mit Ringbuffer. Beide erfassten ausschließlich Fehlernummer 50000
mit Schweregrad 16 aus der eigenen Testsession. Zwei abgefangene synthetische
Fehler wurden in beiden nativen Targetdokumenten bestätigt. Bestehende
XE-Sessions und Targets wurden nicht verändert.

Sieben Aufrufe prüften beide Targets ohne Textdaten, mit fünf Zeichen und
unbegrenztem Text, die exakte Auswahl einer eigenen Session, einen fehlenden
Targetnamen sowie die fehlende Flush- und High-Impact-Bestätigung. Die
vorhandenen Statuswerte und Partialitätsflags blieben erhalten; deaktivierte
und bestätigungspflichtige Aufrufe lieferten keine Targetzeile. Die acht
Exportcollations und alle 18 TABLE-/JSON-Felder wurden geprüft. Die drei
nativen Zähler lagen in den Vorher-/Nachher-Intervallen. Sessionadressen blieben
zwischen den Gegenproben identisch; Erhebungszeit und feste Evidenzfelder
wurden getrennt geprüft. Textopt-out blieb NULL, fünf Zeichen erzeugten eine
gemeinsame maschinenlesbare Kürzungswarning, und unbegrenzter Text behielt
seine ursprüngliche Zeichen- und Bytezahl.

Der erste Lauf scheiterte an der angenommenen exakten Gleichheit der nativen
Sessionstartzeit. Ein separater privater Diagnoselauf zeigte eine Variation
der nativen `create_time` um einen `datetime`-Tick zwischen Reads; die Ursache
ist nicht belegt. Der abschließende Test verlangt deshalb stabile native
Sessionadressen und höchstens zehn Millisekunden Abweichung zu jeder der
beiden Zeitgegenproben. Die Zählerintervalle bleiben streng; Produktcode und
öffentlicher Zeittyp wurden nicht geändert. Der unabhängige Review ergänzte
außerdem explizite NULL-Prüfungen für angeforderte Payloadmetriken.

Frameworkinstallation, Smoke-Test, abschließender Laufzeitvertrag, 75 lokale
statische Verträge und unabhängiger Source- und Testreview bestanden. Alle
drei eigenen Container, Volumes und temporären Lab-States wurden entfernt;
die eigenen XE-Sessions wurden auch bei Baselinefehlern über Erzeugungsflags
gelöscht. Dieser Vertrag belegt keine Event-File-Ausgabe, Retention, Verlust-
oder Dropped-Event-Bewertung, Regexfilter, zusätzliche Berechtigungsprofile
oder Hochlastvariante.

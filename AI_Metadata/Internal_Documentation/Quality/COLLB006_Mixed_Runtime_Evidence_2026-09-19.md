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

## Extended Events Reader: 5. Oktober 2026

`Code/Tests/Common/150_XEReader_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben. Der ursprüngliche Stand reproduzierte die fremde
Exportcollation (`55991`). Alle zehn lokalen Textspalten verwenden jetzt die
Frameworkcollation; die drei Textspalten des TABLE-Exports wurden nativ
geprüft. Beide nativen Sessionnamenvergleiche sind explizit collatiert.

Der Test erzeugte nach Namenspreflight eine eigene synthetische Unicode-
XE-Session mit Ringbuffer und Event-File-Target. Sie erfasste ausschließlich
Fehlernummer 50000 mit Schweregrad 16 aus der eigenen Testsession. Zwei
abgefangene synthetische Fehler wurden in beiden nativen Quellen bestätigt.
Die Session wurde nur für die eigene Dateigegenprobe gestoppt. Der Dateipfad
wurde im Testcontainer aus dem nativen Logverzeichnis und einer neuen
generischen Kennung gebildet; private Pfadwerte wurden nicht übernommen.

Dreizehn Aufrufe prüften Ringbuffer, Eventdatei und automatische Dateiauswahl,
bare und geklammerte Sessionnamen, Limits null, eins und NULL, einen fehlenden
Eventnamen, UTC-Unter- und exklusive Obergrenzen sowie fehlende Flush- und
High-Impact-Bestätigung. Status, Partialitätsflags, Quellenstatus, Fehlernummer,
Schweregrad und Zeilenzahlen wurden geprüft. Die sechs rohen TABLE-Felder
und die entsprechende JSON-Kernprojektion stimmen als typisierte Multimengen
mit den nativen Ereignissen überein. Der vorhandene XML-Vertrag bleibt
erhalten: `@MitEventXml=0` entfernt XML aus JSON, während TABLE das rohe
Eventdokument weiterhin enthält. Das öffentliche JSON-Eventarray muss auch
bei leeren Ergebnissen vorhanden sein.

Der erste Lauf scheiterte am Vergleich leerer JSON-Unterabfragen, die NULL
statt eines Arrays liefern. Ein eigener Diagnoselauf grenzte den Fehler auf
den Testvergleich ein. Die abschließende Testdatei normalisiert ausschließlich
die erzeugten Vergleichsprojektionen auf leere Arrays und verlangt vorher
das öffentliche Eventarray sowie die erwarteten Zeilenzahlen. Produktcode
und öffentlicher Ausgabevertrag wurden deswegen nicht geändert.

Frameworkinstallation, Smoke-Test, abschließender Laufzeitvertrag, 75 lokale
statische Verträge und unabhängiger Source- und Testreview bestanden. Alle
drei eigenen Container, Volumes und temporären Lab-States wurden entfernt;
die eigene XE-Session wurde auch bei Baselinefehlern über ihr Erzeugungsflag
gelöscht. Eigene Eventdateien wurden mit dem eigenen Container-Volume entfernt.
Dieser Vertrag belegt keine Regexfilter, Rollover- oder Retentionbewertung,
Dropped-Event-Bewertung, zusätzliche Berechtigungsprofile oder Hochlastvariante.

## Extended Events Sessions: 5. Oktober 2026

`Code/Tests/Common/151_XESessions_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Die
Bereitschaftsprüfung bestätigte Majorversion 17; die konkrete ProductVersion
wurde nicht erhoben. Der ursprüngliche Stand reproduzierte die fremde
Exportcollation (`56001`). Alle 26 lokalen Textspalten einschließlich der
drei Namensfilter verwenden jetzt die Frameworkcollation; die sechs
Textspalten des TABLE-Exports wurden nativ geprüft.

Ein kontrollierter Stand mit korrigierten Textspalten, aber dem ursprünglichen
dynamischen Targetmemory-Join reproduzierte getrennt `56002`. Alle sechs
nativen Sessionnamenvergleiche sind jetzt explizit collatiert. Die vorhandene
Spaltenverfügbarkeitsprüfung für `total_target_memory` bleibt erhalten.

Der Test erzeugte nach Namenspreflight zwei eigene synthetische Unicode-
XE-Sessions. Beide konfigurierten `error_reported` mit Fehlernummer 50000
und eigener Sessionkennung als Predicate, die Action `session_id` sowie
einen Ringbuffer mit explizit 128 KB Targetmemory. Nur eine Session wurde
gestartet; Ereignisse wurden nicht ausgelöst und Targetdaten nicht gelesen.
Native Kataloge bestätigten die beiden Definitionen, Events, Actions und
konfigurierten Felder sowie den getrennten Laufzustand.

Neun Aufrufe prüften gemeinsame und einzelne Sessionauswahl, Limits null,
eins und NULL, deaktivierte Details, fehlende Event- und Targetnamen sowie
Laufzeit-Opt-out und Nur-laufend-Auswahl. Die 16 Konfigurations- und
Inventarfelder wurden gegen native Kataloge und bestätigte Fixturezähler
geprüft; alle 33 Session-TABLE-/JSON-Felder stimmen als typisierte Multimengen
überein. Die vier Detailarrays entsprechen ihren nativen Katalogprojektionen.
Runtime-Opt-out und gestoppte Sessions liefern NULL-Runtimefelder. Der
Laufstatus und die Startzeit der eigenen laufenden Session wurden mit
stabiler nativer Adresse und höchstens zehn Millisekunden Abweichung zu
beiden Zeitgegenproben geprüft. Dieser empirische Zeitrahmen ist keine
allgemeine Genauigkeitsgarantie.

Der vorhandene asymmetrische Vertrag bleibt erhalten: Ohne Runtimeprojektion
und mit Nur-laufend-Auswahl ist das Sessionarray leer, während aktivierte
Detailabfragen das laufende native Inventar liefern können. Status und
Zeilenzahl beziehen sich weiterhin auf Sessions; öffentliche Arrays müssen
auch bei leeren Ergebnissen vorhanden sein.

Frameworkinstallation, Smoke-Test, beide Baselinereproduktionen, abschließender
Laufzeitvertrag, 75 lokale statische Verträge und unabhängiger Source- und
Testreview bestanden. Die eigenen XE-Sessions wurden auch bei Baselinefehlern
über Erzeugungsflags gelöscht; eigener Container, Volume und temporärer
Lab-State wurden entfernt. Dieser Vertrag belegt keine Ereigniserfassung,
Targetpayloads, Runtimezählerparität, Verlustbewertung, Regexfilter,
zusätzliche Berechtigungsprofile oder Hochlastvariante.

## Snapshot Baseline: 5. Oktober 2026

Der erweiterte `Code/Tests/Integration/195_SnapshotBaseline_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb`,
`SQL_Latin1_General_CP1_CS_AS` für die eigene Frameworkdatenbank und
`Latin1_General_100_CI_AS` für das eigene Snapshotziel. Die Bereitschaftsprüfung
bestätigte Majorversion 17; die konkrete ProductVersion wurde nicht erhoben.
Die kanonischen optionalen Installer wurden für die privaten Aufrufe expandiert;
ihre bestehenden SQLCMD-Einstiegspunkte bleiben erhalten.

Der ursprüngliche Stand reproduzierte die fremde Collation der Collection-
Exporte (`53744`). Ein kontrollierter Stand mit korrigierter Collection und
ursprünglichem Purgeexport reproduzierte anschließend getrennt `53746`.
Jede Phase verwendete neu angelegte eigene Framework- und Zieldatenbanken.
Die sechs transienten Countertextspalten, elf lokalen Collectiontextspalten
und fünf lokalen Purgetextspalten verwenden jetzt die Frameworkcollation.
Bestehende persistente Zieltabellen wurden nicht geändert.

Die erste tatsächliche Sammlung exportierte `run` und `modules` gleichzeitig
nach TABLE und JSON. Die fünf beziehungsweise vier Textcollations wurden
nativ geprüft. Alle 14 Runfelder und neun Modulstatusfelder stimmen in ihrer
kanonischen JSON-Repräsentation mit den persistierten nativen Zielzeilen
überein. Schedulerarten MANUAL, EXTERNAL und SQL_AGENT, Due-Skip, Reset-Epoche,
Payloadverlustfreiheit und Reinstallation mit erhaltener eigener Policy und
Zielkonfiguration blieben Teil des vorhandenen Laufzeitvertrags.

Ein zusätzlicher eigener CaptureRun erhielt zwei synthetische Unicode-Counter,
deren Namen sich nur durch Groß-/Kleinschreibung unterscheiden. Der interne
Counterabschluss persistierte zwei getrennte gehashte Scopes und vier Samples
mit den exakten Rohwerten 17 und 29 sowie interpretierten Werten 1,25 und 2,5.
Countertyp, Einheit, Objekt- und Instanzname, Qualitätscode, Partialität,
Scopehash und gemeinsame Reset-Epoche wurden geprüft. Das komprimierte
Rohpayload stimmt nach Dekompression mit dem ursprünglichen synthetischen
JSON und dessen SHA-256 überein.

Der erzwungene positive Purge exportierte drei collatierte Textspalten und
alle 17 Felder nach TABLE und JSON; die Zusammenfassung stimmt mit dem nativen
PurgeRun überein. Der alte synthetische Run wurde entfernt, der frische Run
blieb erhalten. Der nachfolgende nicht fällige Purge liefert gemäß bestehendem
Vertrag keine persistierte Laufkennung, sondern eine TABLE-/JSON-Fallbackzeile
mit Status `SKIPPED_NOT_DUE` und null gelöschten Zeilen. Der Budgetstop sammelte
keine Metrics; die deaktivierte Zielkonfiguration blieb `DISABLED`.

Der Review ergänzte NULL-sichere Unicode-Status- und Identitätsprüfungen.
Der endgültige kanonische Teststand wurde danach separat in einem zweiten
frischen Container ausgeführt und bestand. Beide Container, Volumes und
temporären Lab-States sowie sämtliche eigenen Testdatenbanken wurden entfernt.
Frameworkinstallation, Smoke-Test und optionaler Installervertrag bestanden.
Die statische Suite bestand 74 Prüfungen; ihr Adapter-Bytevergleich scheiterte
zunächst an der Checkoutdarstellung des generierten Installers. Nach erneuter
kanonischer Generierung bestand auch dieser Adaptervertrag ohne semantischen
Repositorydiff. Datenschutz-, Dokumentations- und Statusprüfungen sowie der
unabhängige Source- und Testreview bestanden. Dieser Vertrag belegt keine
Schedulerverfügbarkeit, zusätzliche Berechtigungsprofile, Concurrency-
Gegenprobe, Hochlastvariante oder vollständige persistente Collationmigration.

### Ergänzende Snapshot-Concurrency und CI-Anbindung

Ein weiterer neuer lokaler SQL-Server-2025-Docker-Container verwendete dieselbe
gemischte Collationkombination und führte den unveränderten endgültigen
Snapshot-Laufzeitvertrag erneut erfolgreich aus. Anschließend hielt eine
eigene Session die kanonische Anwendungssperre aus Vertrag `196`. Die zweite
Session wurde erst nach einer erfolgreichen `APPLOCK_TEST`-Gegenprobe
gestartet; Vertrag `197` bestätigte `SKIPPED_CONCURRENT` ohne CaptureRunId.
Der Lockhalter endete erfolgreich nach seinem vorhandenen Zwölf-Sekunden-
Intervall. Eigene Testdatenbanken, Container, Volume und Lab-State wurden
entfernt. Dieser Nachweis aktiviert keinen Scheduler und prüft keine Hochlast.

Der funktionale Workflow wertet seit PR `221` auch den Snapshot-Scope aus.
Sein vorheriger Core-Scope übersprang reine Snapshotänderungen, obwohl der
Selector deren Laufzeit- und Concurrency-Impact erkannte. Die ergänzte
Anbindung verlangt einen erfolgreichen Runtimejob, prüft die tatsächliche
Lockbereitschaft und berücksichtigt den optionalen Installer-Builder im
Workflowtrigger. Zehn Bashblöcke bestanden die lokale Syntaxprüfung und
32 Zustandsfälle das tatsächlich ausgeführte Bash-Abschlussgate. Alle
75 statischen Verträge und der unabhängige Workflowreview bestanden. Der
GitHub-Lauf `37362107664` bestand am exakten PR-Head einschließlich des
vollständigen funktionalen 2025-Gates und der Snapshotverträge; anschließend
wurde PR `221` integriert.

## Server Feature Capabilities: 5. Oktober 2026

`Code/Tests/Common/152_FeatureCapabilities_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb`,
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank und
`Latin1_General_100_CI_AS` für die jeweils neu erzeugte synthetische
Unicode-Quelldatenbank. Majorversion 17 wurde bei der Bereitschaft geprüft;
die konkrete ProductVersion wurde nicht erhoben.

Der ursprüngliche Stand reproduzierte die fremde TABLE-Textcollation
(`56031`). Ein kontrollierter Stand mit korrigierten Textcollations und
ursprünglichem Exportlimit reproduzierte getrennt `56032`. Die 27 bisher
nicht explizit collatierten lokalen Textspalten verwenden jetzt die
Frameworkcollation. Die Capabilitymenge wird nach vollständiger
Statusbewertung einheitlich nach `(ScopeName, FeatureName)` begrenzt.

Sechs Fälle prüfen die sieben TABLE-Textspalten, alle acht Exportfelder
gegen ihre typisierte JSON-Repräsentation, neun allgemeine und vier
optionale Linux-Capabilityidentitäten sowie deren Mindesthauptversion.
Die Linux-Verfügbarkeit und Quellenidentität werden gegen den nativen
Systemkatalog geprüft. `NULL`, `0` und das Ein-Zeilen-Limit erhalten die
erwarteten Mengen und Reihenfolgen. Eine fehlende Auswahl zusammen mit
der gültigen Quelle liefert `PARTIAL_RESULT`; ausschließlich fehlende
Auswahl liefert `ERROR_HANDLED`, erhält aber die Servercapabilities.
Warnings, native Datenbankidentität, Compatibility Level und StateDesc
sowie die Wiederherstellung des vorherigen `LOCK_TIMEOUT` werden geprüft.

Alle sechs Fälle bestanden nacheinander mit Compatibility Level 150, 160
und 170 auf derselben SQL-Server-2025-Engine. Auch die jeweilige eigene
Quelldatenbank verwendete das geprüfte Compatibility Level. Diese Läufe
sind keine nativen SQL-Server-2019- oder SQL-Server-2022-Nachweise.
Installation und Smoke-Test bestanden; eigene Quelldatenbanken, Container,
Volume und temporärer Lab-State wurden entfernt. Der Vertrag prüft keine
positiven Vector-/JSON-Indizes, Replikagruppenzähler, zusätzliche
Berechtigungsprofile oder Funktionsfähigkeit externer Runtimes.

## Server Version Information: 5. Oktober 2026

`Code/Tests/Common/153_ServerVersionInformation_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb`,
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank und zwei jeweils
neu erzeugten synthetischen Unicode-Quelldatenbanken mit
`Latin1_General_100_CI_AS` beziehungsweise der Frameworkcollation.
Majorversion 17 wurde bei Bereitschaft geprüft; die konkrete ProductVersion
wurde gegen den nativen Wert geprüft, aber nicht in dieses Artefakt übernommen.

Der ursprüngliche Stand reproduzierte Fehler `468` beim Vergleich der
materialisierten Instanzbuildnummer mit dem Offline-Katalog. Die 80 bisher
nicht explizit collatierten Textspalten der elf lokalen Tabellen verwenden
jetzt die Frameworkcollation. Auch der Buildvergleich benennt die Collation
auf beiden Seiten ausdrücklich. Katalogseed, Lifecyclebewertung und
öffentliche Ausgabeformen wurden nicht geändert.

Vier Fälle exportieren alle sieben Resultsets gleichzeitig nach TABLE und
JSON. Die 64 TABLE-Textspalten und die vollständigen kanonischen
JSON-Repräsentationen aller Exportfelder wurden geprüft, einschließlich
leerer Datenbankmengen. Instanzbuild, Hauptversion, Server- und
`tempdb`-Collation stimmen mit `SERVERPROPERTY` beziehungsweise dem nativen
Datenbankkatalog überein. Alle neun Featureidentitäten und deren Werte
werden gegen `SERVERPROPERTY` geprüft. Die fünf Referenzzeilen sowie die
Instanz-, Build- und Lifecyclezeilen bleiben bei einem Datenbanklimit erhalten.

Der vollständige Datenbankfall verlangt genau die beiden eigenen
Unicode-Quelldatenbanken. Datenbank-ID, Name, Compatibility Level, Collation
und StateDesc werden gegen den nativen Katalog geprüft. Die eigene erste
Quelle verwendet Compatibility Level 150, die zweite 160. Ein Ein-Zeilen-Limit
erhält die zuerst angeforderte Quelle. Die gültige Quelle zusammen mit einer
fehlenden Auswahl liefert `AVAILABLE_LIMITED` und genau eine partielle
Auswahlwarnung mit dem bestehenden generischen `DATABASE_UNAVAILABLE`-Vertrag.

Der erste Testentwurf setzte irrtümlich einen Datenbanknamen im Warnungstext
voraus. Die Prüfung wurde an den vorhandenen generischen Vertrag angepasst;
der unabhängige Review ergänzte außerdem die exakte eigene Datenbankmenge.
Der endgültige Stand bestand danach separat mit Compatibility Level 150,
160 und 170 der Frameworkdatenbank auf derselben SQL-Server-2025-Engine.
Diese Läufe sind keine nativen 2019- oder 2022-Nachweise. Installation und
Smoke-Test bestanden. Alle eigenen Testdatenbanken, Container, Volumes und
temporären Lab-States wurden auch nach den früheren Testfehlern entfernt.
Der Vertrag belegt keine aktuelle Patchfreigabe, Online-Katalogaktualität,
Vulnerability-, Lizenz-, Neustart- oder zusätzliche Berechtigungsprüfung.

## Special Feature Inventory: 5. Oktober 2026

`Code/Tests/Common/154_SpecialFeatureInventory_Collation_Runtime_Contract.sql`
bestand auf einem neuen lokalen SQL-Server-2025-Docker-Container mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für die Frameworkdatenbank. Zwei eigene
synthetische Unicode-Quelldatenbanken verwenden `Latin1_General_100_CI_AS`
beziehungsweise die Frameworkcollation. Ihre Namen unterscheiden sich nur
in der Groß-/Kleinschreibung des Unicode-Zeichens. Majorversion 17 wurde
bei Bereitschaft geprüft; die konkrete ProductVersion wurde nicht erhoben.

Der ursprüngliche Stand reproduzierte die fremde TABLE-Textcollation
(`56051`). Ein kontrollierter Stand mit korrigierten Textcollations und
ursprünglicher Ausgabesteuerung reproduzierte getrennt `56052`. Die 17 bisher
nicht explizit collatierten Textspalten verwenden jetzt die Frameworkcollation.
Eine zusätzliche Exportmaterialisierung wendet Featurefilter und Zeilenlimit
gemeinsam auf die bereits vollständige Inventur an. Die vollständige
Quellmaterialisierung bleibt für Aufrufmetadaten und Datenbankstatus erhalten.

Sechs Fälle prüfen die neun TABLE-Textspalten und die vollständige kanonische
JSON-Repräsentation aller zehn Featurefelder. Die vollständige Auswahl enthält
genau 18 Featurecodes je eigener Quelldatenbank. Je Quelle wurden ein eigener
Aliasdatentyp und eine leere Tabelle mit XML- und Spatial-Spalte angelegt;
deren drei positive Katalogzähler betragen jeweils eins. Native JSON- und
Vector-Spalten sind in diesen Fixtures nicht vorhanden und werden mit null
erkannten Objekten ausgewiesen. Die vollständigen erkannten Gesamt- und
Datenbankzähler werden aus dem vollständigen ersten Ergebnis gesichert und
über die gefilterten und begrenzten Folgefälle unverändert verlangt; dieser
Vergleich ist eine Zählererhaltungsprüfung, keine unabhängige native Gesamtzählung.

Die Fälle decken `@NurErkannteFeatures` mit beiden Bitwerten sowie `NULL`, `0`
und ein Ein-Zeilen-Limit ab. Die erste ungefilterte Limitzeile wird unabhängig
aus der eigenen Datenbankmenge und den festen Featurecodes unter
Frameworkcollation bestimmt. Die gültigen Quellen zusammen mit einer fehlenden
Auswahl liefern `AVAILABLE_LIMITED`; ausschließlich fehlende Auswahl liefert
`DATABASE_UNAVAILABLE` mit leerem Featureexport. Die exakte Datenbankstatusmenge,
NULL-sichere Statusfelder, vollständige Zähler und Wiederherstellung des
vorherigen `LOCK_TIMEOUT` werden geprüft. Die Bereinigung entfernt ausschließlich
die nach erfolgreicher Anlage gesicherten eigenen Datenbankidentitäten.

Der unabhängige Review ergänzte Ownership-Bereinigung, NULL-sichere Status- und
Identitätsprüfungen, die exakte Statusmenge sowie die unabhängige Limitreihenfolge
und den Erhalt der erkannten Datenbankzähler. Der endgültige Vertrag bestand
danach mit Compatibility Level 150, 160 und 170 der Frameworkdatenbank auf
derselben SQL-Server-2025-Engine. Diese Läufe sind keine nativen 2019- oder
2022-Nachweise. Installation und Smoke-Test bestanden; sämtliche eigenen
Quelldatenbanken, Container, Volumes und temporären Lab-States wurden entfernt.
Der Vertrag prüft keine Featuregesundheit, tatsächliche Laufzeitnutzung,
positiven JSON-/Vector-Spalten, zusätzlichen Berechtigungsprofile oder
eigenständigen CONSOLE-Resultsetmitschnitt.

## Gemeinsame Regression der drei Versionsadaptiv-Slices: 5. Oktober 2026

Der unveränderte Kandidat `82efbcddc5355cd1f5d6f9a5f378a0fd72ac67bf`
enthält die Capability-, Serverversions- und Spezialfeature-Korrekturen.
Der kanonische Impact-Selector wählte gegenüber
`94136ff3eca0703b72600756a5c6b8b4c0e14383` elf Laufzeittestdateien:
Common `124`, `152`, `153` und `154`, Integration `110`, `168`, `179`, `190`,
`196` und `198` sowie ObjectIndex `121`. Zusätzliche native Engines,
Berechtigungs-, Regex- und Snapshotmatrizen wurden nicht ausgewählt.

Alle elf Dateien bestanden nacheinander bei Compatibility Level 150, 160
und 170 der Frameworkdatenbank auf einer neuen eigenen SQL-Server-2025-
Docker-Instanz. Die 33 erfolgreichen Dateiläufe ergänzen die gezielten
Reproduktionen und prüfen die direkt und transitiv betroffenen Verträge,
einschließlich der bestehenden Spezialfeature-, Wave-1-, Navigator-,
External-Runtime-/CLR- und JSON-Index-Verträge. Server und `tempdb` verwenden
`Latin1_General_100_CS_AS`, die Frameworkdatenbank die Frameworkcollation.
Installation und vorgelagerter Smoke-Test bestanden; eigener Container,
Volume und temporärer State wurden entfernt. Diese lokale Regression ersetzt
keine erforderliche erfolgreiche GitHub-CI am maßgeblichen PR-Head und keinen
nativen 2019- oder 2022-Nachweis.

Ein vorangegangener Start wurde beim Laufzeitkontextwechsel unterbrochen
und liefert keinen Erfolgsnachweis. Sein eigener Container und sein Volume
wurden separat entfernt. Ein temporärer lokaler Wiederherstellungsstate blieb
wegen einer abgelehnten rekursiven Dateibereinigung erhalten; er gehört nicht
zu Repository- oder GitHub-Artefakten.


## In-Memory-OLTP-Findings und Quellenstatus – 6. Oktober 2026

Die lokale Prüfung verwendet einen neu erzeugten eigenen SQL-Server-2025-Container
mit Instanz- und tempdb-Collation `Latin1_General_100_CS_AS`, einer Frameworkdatenbank
mit `SQL_Latin1_General_CP1_CS_AS` und einer synthetischen Quelldatenbank mit
`Latin1_General_100_CI_AS`. Zwei kleine SCHEMA_ONLY-Tabellen enthalten je vier
Integerzeilen und konfigurierte Hash-Bucketzahlen 8 beziehungsweise 16. Ein
speicheroptimierter Tabellentyp und eine eigene MEMORY_OPTIMIZED_DATA-Dateigruppe
vervollständigen die Fixture. Konkrete Laufzeitpfade und Secrets bleiben außerhalb
des Repositorys.

Der finale Testvertrag
`Code/Tests/Common/155_InMemoryOltpAnalysis_Collation_Runtime_Contract.sql` hat den
SHA-256 `B04BACA94786666025100B078CB74103E531D711A87D9499E8EFAB1EFE594131`.
Der tatsächlich ausgeführte dritte lokale Lauf bestand mit Exitcode 0 bei
Compatibility Level 150, 160 und 170. Jeder Level führte acht Fälle aus:
ungefilterte Ausgabe ohne Limit, Limit 1, ausschließlich problematische Findings
mit NULL-Limit, Hashstatistik opt-in, problematische Hashfindings mit Limit 1,
unbegrenzte problematische Hashfindings, enger Objektfilter und gültige plus
nicht vorhandene explizite Datenbankauswahl.

Die Prüfung vergleicht alle 14 Findingsfelder zwischen TABLE und JSON und die
Frameworkcollation der elf TABLE-Textspalten. Native eigene Tabellen- und
Hashindexidentitäten, konfigurierte Bucketzahlen, Hasharithmetik sowie unabhängige
Findingcodes, Metriknamen und Schwellenwerte werden geprüft. Vollständige
Datenbankzähler und Quellenstatus bleiben trotz Findingsfilter und Ausgabelimit erhalten.
Die fehlende explizite Datenbank behält `DATABASE_UNAVAILABLE`, Partialwert und
Fehlerzähler. Acht erwartete Quellenstatus werden vollständig geprüft; der
Hashstatistikpfad bleibt ohne Opt-in `NOT_REQUESTED`.

Vier Vorstände reproduzierten getrennte Fehler: Die unveränderte Quelle scheitert
am TABLE-Textcollationvertrag oder am nativen Datenbanknamenvergleich im Resource-Pool-Pfad; der ausschließlich
collationgehärtete Temp-Tabellenstand reproduzierte Fehler 468 am Datenbanknamenvergleich im Resource-Pool-Pfad.
Nach dessen Korrektur scheiterte der gemeinsame Findingsfilter-/Limitvertrag;
nach Exportkorrektur scheiterte der Statusvertrag der nicht vorhandenen Datenbank.
Die finale Quelle korrigiert 65 bisher implizite Textcollations, den beidseitig
collierten Datenbanknamenvergleich im Resource-Pool-Pfad, die gemeinsame Findingsauswahl und die
Statusaktualisierung bereits erfasster Auswahlwarnings.

Die eigene Quelldatenbank, der Container, das Volume und der lokale Labzustand
wurden entfernt. Frühere fehlgeschlagene Versuche sind kein Erfolgsnachweis;
auch ihre eigenen Ressourcen wurden entfernt. Der Test stellt seinen eigenen
ursprünglichen LOCK_TIMEOUT wieder her. Die bestehende Produktsemantik dieses
Sessionwertes wurde nicht geändert und ist kein neuer Restaurationsnachweis.

Die Evidenz gilt für diese kleine synthetische Fixture auf SQL Server 2025.
Sie belegt keine native ältere Engine, zusätzliche Berechtigungen, Last- oder
Speicherknappheit, dauerhafte Checkpointprobleme, Transaktionsdruck oder eine
separate CONSOLE-Erfassung. Flüchtige Speicherwerte werden nicht zwischen
verschiedenen Momentaufnahmen als identisch vorausgesetzt. Die lokale Prüfung
ersetzt die erforderliche erfolgreiche GitHub-CI am exakten PR-Head nicht.


### Ausgewählte In-Memory-Regressionskombinationen

Der Impact-Selector wählte acht Tests für den ausführbaren Kandidaten
`0fd4d256290cb9844cab9211e24fac7cf97ba93a`. Der erste eigene gemischte SQL-Server-2025-Lauf
bestand alle acht Tests bei Level 150 und sechs bei Level 160. Im bestehenden
Navigator-Vertrag trat danach Fehler 1222 in `InternalPrepareSingleResultTable`
auf; der gesamte Lauf blieb fehlgeschlagen. Nach Entfernung dieses eigenen Labs
bestand ein frisches Lab gezielt die beiden noch offenen Tests bei Level 160
und alle acht bei Level 170 mit Exitcode 0. Dieser Wiederholungskandidat
`5444d16b6604a9e147cd9086131c23382197ad31` unterscheidet sich ausschließlich durch
Evidenzpräzisierungen; SQL und Testvertrag sind identisch.

Damit liegen erfolgreiche Ergebnisse für alle 24 ausgewählten Kombinationen
vor, verteilt auf zwei Läufe. Der beobachtete Lock-Timeout wird dadurch nicht
zu einem erfolgreichen ersten Lauf umgedeutet; eine konkrete Lockursache wurde
nicht erfasst. Der begrenzte Frischlabnachweis belegt die erfolgreiche
Wiederholung. Beide eigenen Container, Volumes und lokalen Labzustände wurden
entfernt. Die erforderliche exakte GitHub-Head-CI bleibt ein gesondertes Gate.


### Geerbtes NOWAIT bei eigener TABLE-Metadatenanlage

Die erforderliche GitHub-SQL-CI am Head
`9a9d4376ce20938fe839998036ca0cebbeea9e9c` scheiterte bei Compatibility Level 150
mit Fehler 1222 in `InternalWriteResultTable` an der eigenen lokalen
Metadatenanlage. Der synthetische CI-Container wurde durch den vorhandenen
Cleanup beendet. Zusammen mit dem zuvor lokal beobachteten Fehler in
`InternalPrepareSingleResultTable` zeigt dies einen zu engen NOWAIT-Pfad für
eigene Temp-DDL; eine konkrete konkurrierende Sperrquelle wurde nicht erfasst.

Der ausführbare Korrekturcommit
`94e542ef925d67ea4172d3438cfadcaa0b1d4af5` schützt die eigene Metadatenanlage
in Writer und Mehrfach-Preflight bei eingehendem Timeout 0 mit bis zu 1000 ms
je CREATE. Andere Eingangswerte bleiben für diese Anlage erhalten. Der
Single-Preflight verwendet für seine eigene Mappinganlage bis zu 1000 ms,
auch bei anderen Eingangswerten; zuvor war diese Anlage stets NOWAIT.
Unmittelbar danach bleiben fremde Quell-, Ziel- und Mappingoperationen bei
`LOCK_TIMEOUT 0`. Ein Fehler während der eigenen Anlage stellt den gesicherten
Eingangswert wieder her und wird unverändert weitergeworfen.

Ein frisches eigenes gemischtes SQL-Server-2025-Lab bestand die Verträge
`Common/123`, `Common/155`, `Integration/188` und `Integration/196` bei
Compatibility Level 150, 160 und 170: zwölf erfolgreiche Dateiläufe mit Exitcode 0.
Der erweiterte Vertrag 123 hat SHA-256
`4E141414CFFD553DF8AB00480889A1F6FFFB3745B42F7A7124FB0709E608957F`.
Je Level prüfen 50 Single-Preflights und 50 Writer-Appends eingehende Timeoutwerte
0 und 731, die Quell-/Zielidentität, insgesamt 51 geschriebene Zeilen und zwei
abgelehnte globale Zielnamen. Der Timeout des Aufrufers bleibt nach den
geprüften Erfolgs- und Fehleraufrufen erhalten. Wiederholungen beweisen die
getesteten Aufrufe, keine bestimmte Lockursache oder garantierte Fehlerfreiheit.

Container, Volume und Zustand dieses erfolgreichen Labs wurden entfernt.
Ein vorausgegangener unterbrochener Start besitzt keinen Testerfolgsnachweis;
sein eigener Container und sein Volume wurden über die Lab-API entfernt.
Die automatische Freigabeprüfung lehnte das rekursive Entfernen seines privaten
temporären Zustands mit „blocked by policy“ ab. Dieses lokale Verzeichnis bleibt
erhalten und gehört zu keinem Repository- oder GitHub-Artefakt. Der fehlgeschlagene
GitHub-Lauf bleibt fehlgeschlagen; die erweiterte CI am neuen exakten Head ist
weiterhin erforderlich.

### Native Identitäten der CriticalEngineEvents-Fixture

Die erweiterte GitHub-CI am Head
`8e96e04e5ae55827f640077f6e445c4ad7505935` bestand die vorausgegangenen
TABLE-Verträge, scheiterte aber bei Compatibility Level 150 im ausgewählten
Vertrag `Common/139` mit Fehler 55889. Dessen zwei eigene Ereignisse wurden
nach dem zusätzlichen Wall-Clock-Filter nicht nativ bestätigt. Die konkrete
Ursache dieses Ergebnisses ist nicht belegt. Ein frisches eigenes lokales
SQL-Server-2025-Lab bestand den bisherigen Vertrag bei Level 150; zusätzliche
Diagnoseausgaben änderten dessen Assertions nicht.

Der Testcommit `fe34171633771815aa388e1dbeb8c83c337f2171` begrenzt die eigene
XE-Session zusätzlich auf die aktuelle Verbindung. Die eigene eindeutige
Eventdatei muss genau zwei Ereignisse mit Fehler 50000, Severity 16, jeweils
einer der zwei exakten synthetischen Meldungen und vorhandenen Zeitstempeln
enthalten. Das Modulzeitfenster wird aus den nativen MIN/MAX-Zeitstempeln
abgeleitet; die exklusive Obergrenze liegt eine Mikrosekunde über MAX.
Die bisherigen Status-, Limit-, XML-, Feld- und Multisetprüfungen bleiben
erhalten. Ein Zusammenhang des CI-Fehlers mit den getrennten Zeitquellen
oder der Zustellung ist damit nicht bewiesen.

Ein weiteres frisches eigenes SQL-Server-2025-Lab bestand den geänderten
Vertrag bei Compatibility Level 150, 160 und 170 mit Exitcode 0. Beide lokalen
Labs einschließlich ihrer Container, Volumes und Zustandsverzeichnisse wurden
entfernt. Der unabhängige Review des Testdeltas ergab keine Befunde.
Der anschließend gestartete gemischte lokale Impact-Lauf bestand 69 Dateien
bei Level 150, darunter den geänderten Vertrag 139. Er scheiterte danach im
unveränderten Vertrag `Integration/181` mit Fehler 55503 bei der Temporal-
Mapping-, Hidden-, Retention- oder Indexprüfung. Das Lab einschließlich
Container, Volume und Zustand wurde entfernt. Dieser Lauf ist fehlgeschlagen;
er belegt keinen abgeschlossenen Impact-Umfang. Der Temporal-Collation-Umfang
bleibt separat offen. Die lokale Lab-API lehnte die CI-Instanzcollation
`SQL_Latin1_General_CP1_CS_AS` vor der Containeranlage als nicht katalogisiert
ab; dieser Start enthält keinen Testnachweis. Ein weiterer lokaler Lauf mit
`SQL_Latin1_General_CP1_CI_AS` ist keine Nachbildung der CI-Collation. Er bestand
34 Dateien bei Level 150 und scheiterte im Vertrag `Common/154` mit Fehler 1801
an den nur durch Groß-/Kleinschreibung getrennten synthetischen Datenbanknamen.
Das Lab einschließlich Container, Volume und Zustand wurde entfernt. Dieser
Lauf ist fehlgeschlagen und kein Nachweis für die case-sensitive CI-Instanz.
Die erforderliche CI am neuen exakten Head ist noch ausstehend.

## Temporal-Findings und native Periodenmetadaten – 6. Oktober 2026

Ein frisches eigenes SQL-Server-2025-Lab unter Docker bestand den gezielten
Temporal-Vertrag mit Instanz- und tempdb-Collation `Latin1_General_100_CS_AS`,
Frameworkcollation `SQL_Latin1_General_CP1_CS_AS` und einer eigenen synthetischen
Quelldatenbank mit `Latin1_General_100_CI_AS`. Die Lab-Readiness bestätigte Major
17 und die Collation-Verifikation den angeforderten Instanzwert. Eine separate
Metadatenabfrage wurde ausgeführt; die verwendete Lab-Skript-API gab bei Erfolg
jedoch ausschließlich Status und Laufzeit zurück. Die konkrete ProductVersion
wurde daher nicht erfasst und wird nicht aus einem anderen Lauf übernommen.
Diese lokale Evidenz ergänzt keinen versionsgenauen Release-Matrixeintrag.

Der ausgeführte SQL-Quellstand hat SHA-256
`86D439DF5BDF5888D90B6D826C01C567CC2C7FFFE18EEC8D72AA9397FEDD0147`.
Die vom Runner gelesene UTF-8-Datei des neuen Vertrags
`Code/Tests/Common/156_TemporalAnalysis_Collation_Runtime_Contract.sql` besaß mit
CRLF-Zeilenenden den Bytehash SHA-256
`632B2EB7AD0A01EE9CCC7D38BDC7960D01CE34FDB92C574322B24E40A09F6D28`.
Nach ausschließlicher CRLF-zu-LF-Normalisierung besitzt dieselbe Quelle SHA-256
`41091FC85F37CFCB3531A02F2A99ABFBC29E6C89586D18FAF183B48129983D4C`;
dies entspricht dem kanonischen Gitblob. Der Procedurehash bezieht sich auf
deren UTF-8-Quelle mit LF. Der Runner ersetzte den Installationsplatzhalter und ergänzte
eine lokale Case-Ausgabe. Der installierte finale Proceduretext wurde nach
Rückersetzung des Platzhalters gegen diese kanonische Quelle verglichen.

Der Runner verwendete `New-SqlServerLab -Version 2025 -Provider docker
-Profile standard -Collation Latin1_General_100_CS_AS -NonInteractive`,
`New-AnalyzeFrameworkInstaller` und `Invoke-SqlServerLabScript -KeepConnection`.
Der aus 166 kanonischen Dateien erzeugte Gesamtinstaller und
`Integration/110_Smoke_Test.sql` bestanden. Anschließend wurden mit
`ALTER DATABASE [LabAnalyze] SET COMPATIBILITY_LEVEL` nacheinander 150, 160 und
170 ausschließlich für die Frameworkdatenbank aktiviert. Die von `Common/156`
neu erzeugte Quelldatenbank erhielt keinen expliziten Compatibility Level;
ihr Instanzdefault wurde im Lauf nicht erfasst. `Common/156` und der unveränderte
`Integration/181_P2_Temporal_Runtime_Contract.sql` bestanden je Level mit
Exitcode 0: sechs erfolgreiche Dateiläufe, acht neue Fälle und 13 bestehende
Temporal-Fälle pro Frameworklevel. Die Matrix belegt keinen Wechsel des
Compatibility Levels dieser Quelldatenbank. Ein breiter lokaler Impact-Lauf und die erforderliche
exakte GitHub-Head-CI sind dadurch nicht ersetzt.

Die leere Fixture besitzt zwei aktive Current-/History-Paare, einmal versteckte
und einmal sichtbare Periodenspalten, endliche beziehungsweise unendliche
Retention und genau je einen führenden beziehungsweise umgekehrt geordneten
History-Index. Der datenbankweite Retention-Schalter ist zunächst deaktiviert.
Die acht Fälle prüfen unbegrenzte Ausgabe mit `0`, Limit 1, problematische
Findings ohne Limit, problematische Findings mit Limit 1, das bestehende
`NULL`-Limit, einen exakten Unicode-Objektfilter, eine gültige plus fehlende
explizite Datenbank sowie einen leeren Problemscope nach Aktivierung des
Retention-Schalters für das korrekt indizierte Paar.

TABLE und JSON stimmen für alle 15 Findingsfelder einschließlich NULL-Werten
als Feldmultisets überein; alle zwölf TABLE-Textspalten besitzen Frameworkcollation.
Zusätzlich werden die genaue Vierermenge unterschiedlicher SourceCodes,
native Current-/History- und Periodenidentitäten, Hiddenflags, Retentionwerte,
History-Indexreihenfolge und leere approximative Zeilenzähler unabhängig
gegen die eigene Fixture geprüft. Eigenständige erwartete Findingcodes,
Severity, Confidence, Metrikwerte und Schwellen verhindern, dass identisch
falsche TABLE-/JSON-Ausgaben allein als Erfolg gelten. Das Limit 1 erhält
gezielt die erste Retentionwarnung. Inventur- und Findingzähler bleiben trotz
Ausgabefilter und Limit vollständig; die fehlende Datenbank erhält weiterhin
`DATABASE_UNAVAILABLE` und Partialität.

Fünf aufeinander aufbauende Vorstände reproduzierten getrennte Abweichungen:
Der mit `main` verglichene unveränderte Stand und die nur lokal collatierte
Variante scheiterten in Fall 0 mit Modulstatusfehler 56090. Nach Härtung des
dynamischen History-Indexvergleichs scheiterte Fall 1 mit Exportlimitfehler
56082. Die gemeinsame Exportauswahl scheiterte anschließend in Fall 4 am
NULL-Limit; nach dessen Korrektur scheiterte Fall 6 am Modulstatus der fehlenden
Datenbank. Beide letzten Abnahmen lieferten 56090. Der frühere private Harness
hatte den erst später geprüften Datenbankstatusfehler 56086 erwartet; dieser
Erwartungsfehler ist kein Nachweis einer final bestandenen Variante.

Die finale Quelle collatiert 53 zuvor implizite Textspalten und zwölf zusätzliche
Exportspalten; zusammen mit sechs bereits collatierten Filterspalten ergeben
sich 71 lokale Textdeklarationen mit expliziter Frameworkcollation. Der
dynamische Vergleich der führenden History-Indexspalten ist beidseitig collatiert.
Die gemeinsame Findingsauswahl wird erst nach Berechnung der vollständigen
Zähler eingefügt; ihre typisierte Temp-Struktur entsteht vor dem bestehenden
NOWAIT-Abschnitt. NULL-Limits werden akzeptiert und bereits materialisierte
Datenbankauswahlwarnungen nicht durch die spätere Statusaggregation überschrieben.
Es wurden keine Engine-Majorzweige, Berechtigungen oder Katalogschemas geändert;
ein zusätzlicher nativer 2019-/2022-Nachweis war für dieses Delta nicht erforderlich.

Ein erster neuer Runnerlauf scheiterte vor der Baselineauswertung an einem
Klammerfehler in der ergänzten Testassertion mit Fehler 102. Nach dessen
Korrektur erfolgte die oben beschriebene frische Abnahme. Der fehlgeschlagene
Lauf bleibt fehlgeschlagen. Die eigenen Container und Volumes beider Läufe
wurden jeweils über `Remove-SqlServerLab -Force -Confirm:$false` entfernt;
der erfolgreiche Lauf meldete `CLEANUP_SUCCEEDED` für zwei Schritte ohne Fehler.
Die privaten Zustandsverzeichnisse bleiben zur lokalen Nachprüfung außerhalb
von Git erhalten. Die zuvor gesperrten fremden Cleanup-Pfade wurden nicht berührt.

Diese Evidenz gilt ausschließlich für die kleine synthetische Linux-Fixture
und die angegebenen Framework-Compatibility-Levels auf SQL Server 2025 bei
nicht erfasstem Quelldatenbankdefault. Sie belegt keine
native ältere Engine, zusätzliche Berechtigungsprofile, große Historybestände,
Zeilenkonsistenz, Cleanup-Ausführung oder separate RAW-/CONSOLE-Erfassung.
Der Test stellt seinen ursprünglichen LOCK_TIMEOUT wieder her; die bestehende
Produktsemantik dieses Sessionwertes wurde nicht geändert.

### Statische Abschlussprüfung und generierter Adapterinstaller

Die fokussierten Privacy-, Dokumentationsstil-, Roadmap-, Reife- und
Statusvalidatoren bestanden einschließlich ihrer Selftests; die
Dokumentationsprüfung 900 und der Metadatenvalidator 950 bestanden ebenfalls.
Nach Ergänzung des COLL-001-Backlogs bestanden die betroffenen
Repositoryprüfungen 975, 976 und 993 erneut für dieses neue CSV-Delta.
Die einmalige vollständige `Invoke-StaticContractSuite.ps1` bestand alle
weiteren enthaltenen Prüfungen, meldete jedoch zwei Adapter-Hashabweichungen
und bleibt als gesamter Lauf fehlgeschlagen.

Der erwartete Execution-Plan-Adapterinstaller war nach ausschließlicher
LF/CRLF-Normalisierung inhaltlich unverändert; dessen Bytevergleich reagierte
auf die Windows-Checkout-/Builderrepräsentation. Die kanonische Neuausgabe
änderte deshalb keinen Git-Inhalt dieses Artefakts. Im OPS-005-Vollinstaller
wich ausschließlich der eingebettete Temporal-Quellblock ab. Dieser versionierte
Installer wurde über den vorhandenen kanonischen Builder synchronisiert;
der separate OPS-005-Updatevertrag war bereits inhaltlich unverändert.
`TestLab/Test-AnalyzeProjectAdapter.ps1` und
`TestLab/Test-AnalyzeOps005LinkedServerAdapter.ps1` bestanden anschließend
gezielt mit Exitcode 0. Builder, Testverträge und Labfunktionen wurden nicht
geändert; die unveränderte vollständige Suite wurde nicht wiederholt.
## Service-Broker-Findings auf gemischten Collations am 6. Oktober 2026

Der Slice härtet ausschließlich bestehende Verträge von
`Code/09_VersionAdaptive/050_USP_ServiceBrokerAnalysis.sql`.
48 zuvor implizite lokale Textspalten erhalten die Frameworkcollation;
sechs waren bereits explizit collatiert. Der vor dem NOWAIT-Quellabschnitt
angelegte Findingsexport ergänzt zehn Textspalten. Damit sind 64 lokale
Textdeklarationen explizit collatiert. Vier dynamische Textvergleiche werden
beidseitig collatiert. Die fachlichen Quelltimeouts bleiben erhalten.

JSON, RAW, CONSOLE und TABLE verwenden nach der vollständigen Zählerbildung
denselben gefilterten und begrenzten Findingsausschnitt. `NULL` erfüllt den
bestehenden unbegrenzten Mengenvertrag. Auswahlwarnings bleiben bei der
späteren Datenbankaggregation erhalten. Der öffentliche Findingsvertrag
behält seine 13 Spalten und zehn Textspalten. Es entstehen keine neuen
Parameter, Resultsetnamen, Quellen oder Diagnosefunktionen.

### Runtime und begrenzte Metadatenaufnahme

Die eigenen Docker-Labs verwendeten SQL Server 2025 unter Linux.
Der bestehende interne `Invoke-SqlQuery`-Helfer von SQL_Server_Lab lieferte
die Zeilenausgabe einer begrenzten Metadatenabfrage zurück. Ausgegeben wurden
ausschließlich ProductVersion, Major, Collations, Compatibility Levels und
aggregierte NULL-Zähler mit festen Rollenlabels. Es gab keine Lab-API-Änderung.

| Merkmal | Tatsächlich beobachteter Wert |
|---|---|
| Basisrevision | `dcb0b659aaf3b587ec5f89e739b037c9f16de4ae` |
| Native Engine | SQL Server 2025, Major 17 |
| ProductVersion | `17.0.4075.5` |
| Server und `tempdb` | `Latin1_General_100_CS_AS` |
| Framework | `SQL_Latin1_General_CP1_CS_AS` |
| Eigene Brokerquelle | `Latin1_General_100_CI_AS` |
| Common157 Framework und Quelle | Jeweils explizit 150, 160 und 170 gesetzt und getrennt geprüft |
| Integration182 | Frameworklevel 150, 160 und 170; die unveränderten eigenen Quelldatenbanken verwenden einen nicht separat erfassten Defaultlevel |

Der finale Common157-Lauf bei CL150 bestand im zweiten eigenen Lab. Danach
scheiterte ausschließlich das private Schreiben der Metadatenliste an einer
PowerShell-Überladung. Die SQL-Abfrage war bereits erfolgreich abgeschlossen;
Framework- und Sourcelevel standen in der begrenzten Ausgabe. Das dritte eigene
Lab führte die noch fehlenden Common157-Läufe bei CL160/170 und Integration182
bei allen drei Frameworklevels aus. Die bereits bestandene CL150-Prüfung und
die vier bestätigten Baselines wurden nicht wiederholt.

### Konkrete Baselines

Die erste Variante stammt unverändert aus dem Git-Blob der Basisrevision.
Die übrigen Varianten waren private Zwischenstände. Alle vier Fehler wurden
auf derselben zweiten eigenen Runtime mit Framework- und Sourcelevel 170
reproduziert. Die früheren Findingsprüfungen werden nicht als Nachweis einer
späteren, noch nicht erreichten Assertion ausgegeben.

| Private Variante | Erreichter Fall | Tatsächlicher Fehler |
|---|---:|---|
| Unveränderte Basis | 0 | `56112`: TABLE-Textcollation |
| Lokale Textcollations und vier dynamische Vergleiche | 1 | `56111`: Findingslimit im TABLE-Export |
| Gemeinsamer Export mit alter NULL-Abweisung | 4 | `56110`: Modulstatus beim NULL-Limit |
| NULL-fähiger Export mit alter Warningaggregation | 6 | `56110`: Modulstatus beim fehlenden Datenbanknamen |

Der erste eigene Labversuch erreichte keinen Produktaufruf. Seine Fixture
erwartete fälschlich einen verfügbaren Queue-Partitionswert von 0 und scheiterte
mit `56102`. Der finale Vertrag erhält stattdessen native NULL-Werte und
prüft deren Parität. Dieser Versuch ist kein Baseline- oder Erfolgsnachweis.

### Finale funktionale Nachweise und Grenzen

`Code/Tests/Common/157_ServiceBrokerAnalysis_Collation_Runtime_Contract.sql`
bestand neun Fälle auf jedem expliziten Framework-/Sourcelevel 150, 160 und
170. Geprüft wurden unbegrenzte, begrenzte und NULL-Mengen, WARN-Auswahl,
ein exakter Unicode-Queuename, abweichende Groß-/Kleinschreibung, ein fehlender
Datenbankname und ein leerer WARN-Ausschnitt. Der Vertrag vergleicht alle 13
Findingsfelder einschließlich NULL als beidseitige Multisets. Unabhängige
Erwartungen prüfen Findingidentitäten, Severity, Confidence, Metriken und
Schwellen gegen die eigenen nativen Queue-Schalter. Sieben unterschiedliche
Quellcodes besitzen den erwarteten Status und vollständige Zeilenzähler;
Datenbankzähler bleiben vor Ausgabegrenzen erhalten.

Native Queue-IDs, Namen, Serviceanzahlen, Queue-/Poison-/Retention-Schalter,
Aktivierungskonfiguration und die vorhandenen Partitionsfelder wurden
gegengeprüft. Bei CL160 und CL170 lieferte die begrenzte Gegenprobe für beide
Queues jeweils NULL bei `QueueRowsApprox`, `QueueReservedMb` und `QueueUsedMb`.
Die Parität belegt diese Abfragegrenze; sie belegt weder eine positive noch
eine Nullwert-Kapazitätsmessung. Die DDL-Fixture allein ist dafür kein Nachweis.

Die Queues blieben ohne Nachrichten, Dialoge oder Aktivierungsausführung.
Transmission und Conversation-Quellen wurden mit leerem Ergebnis geprüft.
Nichtleere Payload-/Dialogfälle, tatsächliche Aktivierungsfortschritte,
positive Kapazitätswerte und neue Berechtigungsvarianten gehören nicht zu
diesem Nachweis. Die unveränderte Integration182 bestand alle 15 registrierten
Fälle auf jedem Frameworklevel. Acht davon sind Runtimefälle, sechs sind
Definitionsprüfungen und einer ist das Payload-Gate; diese Unterscheidung
bleibt erhalten.

Der kanonische Installer mit 166 Quellen und Integration110-Smoke bestanden
in den eigenen Runtimes. Alle drei eigenen Container und Volumes wurden über
den Run-gebundenen Lab-Cleanup entfernt: jeweils zwei Schritte, null Fehler,
`REMOVED`. Private Zustände bleiben für Review erhalten. Die zwei früher
gesperrten Cleanup-Pfade wurden nicht angefasst; kein rekursiver Cleanup
wurde erneut versucht.

`Native additional risk: NO`: Der Diff verändert weder Katalogschemas noch
Major-Zweige, Berechtigungen, Featureverfügbarkeit oder ältere Installerzweige.
CL150/160 auf der nativen 2025-Engine sind keine nativen 2019-/2022-Nachweise.

### Quellen, Adapter und statische Prüfung

Der ausgeführte Productsource-Stand hatte den UTF-8/LF-SHA-256
`49DA4124E0E30002929CF3D270184965A8C46FC7404A6C1F285F7896C344BFD4`.
Common157 hatte den UTF-8/LF-SHA-256
`33E2BC28B211FDE0F60C0513238BD57C3D376F45B1428CBA0CBC5B4996099D5F`.
Die Raw-Workingtree-Hashes und LF-normalisierten Sourcehashes waren bei
Ausführung identisch. Der private Querylauf ersetzte den Installationsplatzhalter,
entfernte SQLCMD-Batchtrenner und ergänzte ausschließlich Fall- und
Metadatenmarker; diese Instrumentierung ist von den Sourcehashes getrennt.

`pwsh -NoProfile -File TestLab/Adapters/OPS-005/Build-AdapterInstall.ps1`
regenerierte den betroffenen versionierten Vollinstaller aus kanonischen
Quellen. Sein semantischer Diff entspricht ausschließlich dem Brokerobjekt.
Der ExecutionPlan-Installer enthält dieses Objekt nicht. Die beiden
Procedure-Dokumente und die vier kanonischen COLL-001-Statusquellen sind
synchronisiert; COLL-001 bleibt partiell.

Die Privacy-Selbstprüfung bestand mit fünf Fixtures und null Findings.
`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Darin bestanden unter
anderem Privacy mit 1.039 Repositorydateien und null Findings, Schreibstil
mit 697 Repositorydateien und null Findings, Roadmap-, Maturity- und
Partialitätsverträge, der NOWAIT-Metadatenvertrag sowie beide Adapterprüfungen.
Nach diesem Ergebnis wurden ausschließlich diese Gateergebnisse ergänzt;
die abschließenden Privacy- und Schreibstilprüfungen bestanden mit denselben
Dateizahlen und null Findings.

## Full-Text-Leerscope und Exportgrenzen am 6. Oktober 2026

Der Slice härtet ausschließlich bestehende Verträge von
`Code/09_VersionAdaptive/060_USP_FullTextAnalysis.sql`. 65 zuvor implizite
Textspalten erhalten die Frameworkcollation. Zusammen mit sechs bereits
collatierten Filterspalten und zehn Textspalten des neuen Findingsexports
besitzen alle 81 lokalen Textdeklarationen eine explizite Collation.
Vier dynamische Vergleiche zwischen Temp-Tabellen und Datenbankparametern
verwenden die Frameworkcollation. Der gemeinsame Findingsausschnitt wird
nach vollständiger Zählerbildung gefiltert und begrenzt; seine typisierte
Temp-Tabelle entsteht vor dem NOWAIT-Quellabschnitt. RAW, CONSOLE, TABLE und
JSON verwenden diesen Ausschnitt bei unveränderten 13 Findingsfeldern.
`NULL` und `0` bleiben unbegrenzt. Negative Limits liefern den bestehenden
Parameterfehler ohne zusätzliches negatives TOP. Auswahlwarnings werden
von der späteren Datenbankstatusneuberechnung ausgenommen.

### Native Runtime und Baselines

Ein eigenes Docker-Lab verwendete SQL Server 2025 unter Linux, Major 17,
ProductVersion `17.0.4075.5`. Server und `tempdb` verwendeten
`Latin1_General_100_CS_AS`, das Framework `SQL_Latin1_General_CP1_CS_AS`
und die eigene leere Testquelle `Latin1_General_100_CI_AS`.
`SERVERPROPERTY(IsFullTextInstalled)` lieferte 0. Die Werte wurden über eine
begrenzte native Metadatenabfrage erfasst; konkrete Runtimeidentitäten
bleiben außerhalb des Repositorys.

Die unveränderte Procedure aus Basisrevision
`b09cf4d81666d831fab80a99d1c8a9d817ea99b9` wurde getrennt installiert.
Vier tatsächlich ausgeführte Baselines zeigten:

| Vorhandener Vertrag | Beobachtete Abweichung der Basis |
|---|---|
| TABLE-Textcollation | Alle zehn Textspalten verwendeten die abweichende tempdb-Collation. |
| `@MaxZeilen = NULL` | `INVALID_PARAMETER` und Partialität 1. |
| Gültige plus fehlende Datenbankauswahl | `NOT_APPLICABLE`, Partialität 0 und keine erhaltene `DATABASE_UNAVAILABLE`-Warning. |
| Negatives Limit mit JSON | SQL-Fehler 127; der OUTPUT-Status blieb NULL. |

Die Baselinequelle war eine eigene leere Datenbank ohne Full-Text-DDL.
Ihr Compatibility Level wurde nicht separat erfasst. Diese Baselines sind
kein Nachweis positiver Full-Text-Katalog-, Index- oder Populationpfade.

### Finale Nachweise und Harnesskorrekturen

Der kanonische Gesamtinstaller mit 166 Quellen und
`Integration/110_Smoke_Test.sql` bestanden. Anschließend bestanden
`Common/158_FullTextAnalysis_Collation_Runtime_Contract.sql` und der
unveränderte `Integration/183_P2_FullText_Runtime_Contract.sql` jeweils
mit Framework-Compatibility-Level 150, 160 und 170: sechs erfolgreiche
Dateiläufe. Common158 setzt den Level seiner eigenen Quelle jeweils
explizit auf denselben Wert und prüft Framework- und Sourcelevel getrennt.

Common158 prüft pro Level zehn Leer- und Negativfälle sowie zusätzliche
RAW- und CONSOLE-Leeraufrufe. Native Katalogabfragen bestätigen den leeren
Scope. Assertions prüfen die unabhängige Achtmenge von Quellcodes, Status,
Partialität und Zeilenzählern, den 13-Felder-Export mit zehn explizit
collatierten Textspalten, NULL-/0-/positive und negative Mengenparameter,
weitere ungültige Parameter sowie die erhaltene Auswahlwarning.
Leere Findings- und Detailarrays belegen keine positive Filter- oder
Limitwirkung. Integration183 enthält drei Runtimeaufrufe, zwölf
Definitionsprüfungen und eine Privacy-/Read-only-Prüfung; diese 16 Fälle
werden nicht als 16 positive Featurepfade ausgewiesen.

Der erste Common158-Versuch scheiterte vor dem Produktaufruf mit 51011,
weil die Dummy-Zieltabelle fehlte. Nach ihrer Ergänzung scheiterte Case 0
mit 56214 im Quellenmengenvergleich. Eine begrenzte Gegenprobe bestätigte
alle acht korrekten Produktzeilen. Ein nativer Minimaltest verglich
SQL-NULL mit einer fehlenden JSON-Eigenschaft: Die OPENJSON-Projektion
`sysname` lieferte in diesem EXCEPT-Vergleich eine Differenzzeile,
`nvarchar(128)` keine. Beide tatsächlichen globalen Datenbankwerte waren
SQL-NULL. Die beiden nullable SourceStatus-Projektionen verwenden deshalb
im finalen Test `nvarchar(128)`. Beide fehlgeschlagenen Harnessläufe bleiben
fehlgeschlagen; sie belegen keinen Produktquellenfehler. Der unabhängige
Review prüfte den Produktstand und beide Testkorrekturen ohne offene Befunde.

Die ausgeführten kanonischen Quellen besitzen folgende UTF-8/LF-SHA-256:

| Quelle | SHA-256 |
|---|---|
| FullText060 | `9DA68A87C4CBFF613AE9D278B5F940096732B0DF3772239163A5C6B19C0E4804` |
| Common158 | `C1D561C0AA91679D6A84919AF75B94AD99B740A58502A2545818EBF240A9D7A4` |

Der native installierte Proceduretext wurde vom qualifizierten Objektnamen
bis zum abschließenden END gegen die kanonische Quelle verglichen. Nach
LF-Normalisierung und Entfernen äußerer Batchmarker stimmen die UTF-16-
Bodyhashes mit
`29D9FF0D3EEAB7EA5A895ED2F6E511E947A1DD652DD061CCB0E0614DE6F6B0DC`
überein. Die privaten Runner ersetzten den Installationsplatzhalter;
zusätzliche Diagnosemarker gehörten ausschließlich zu getrennten
Fehlergegenproben und nicht zum final bestandenen Common158-Quellstand.

### Aussagegrenze und Cleanup

Nichtleere Kataloge, Indizes, Findings, Populationen, Batches, semantische
Populationen, Memory Pools und FDHosts bleiben für diesen Slice unbelegt.
Es wurde keine Full-Text-DDL, keine Inhaltsabfrage und keine neue
Berechtigungsvariante ausgeführt. CL150/160 auf SQL Server 2025 sind keine
nativen 2019-/2022-Nachweise. Das Delta ändert keine Engine-Majorzweige,
Berechtigungen oder Katalogschemas; ein zusätzliches natives Versionsrisiko
wurde nicht festgestellt. COLL-001 bleibt partiell.

Das eigene Lab wurde über `Remove-SqlServerLab -Force -Confirm:$false`
entfernt: Container und Volume, zwei Cleanupschritte, null Fehler,
`CLEANUP_SUCCEEDED` und `REMOVED`. Der eigene verschlüsselte temporäre
Secretwert wurde danach entfernt. Private Prüfzustände bleiben außerhalb
von Git. Die zwei zuvor gesperrten Cleanup-Pfade wurden nicht berührt.

`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Darin bestanden Privacy
mit 1.041 Repositorydateien und null Findings, Schreibstil mit 698
Repositorydateien und null Findings, Roadmap-, Maturity- und
Partialitätsverträge, der NOWAIT-Metadatenvertrag sowie beide Adapterprüfungen.
Nach diesem Ergebnis wurden ausschließlich diese Gateergebnisse ergänzt.

## Data-Capture-Tiefenanalyse und positive CT-Exportgrenzen am 6. Oktober 2026

Der Slice härtet bestehende Verträge von
`Code/09_VersionAdaptive/070_USP_DataCaptureDeepAnalysis.sql`. 61 zuvor
implizite Textspalten erhalten die Frameworkcollation. Zusammen mit sechs
bereits collatierten Filterspalten und zehn Textspalten des neuen
Findingsexports besitzen alle 77 lokalen Textdeklarationen eine explizite
Collation. Katalognamenprüfungen sowie Datenbankvergleiche für CDC-Jobs und
Distributorermittlung verwenden die Frameworkcollation. Die eigene
Exporttabelle entsteht vor dem NOWAIT-Quellabschnitt. Nach vollständiger
Zählerbildung versorgt eine gefilterte und begrenzte Findingsmenge RAW,
CONSOLE, TABLE und JSON mit unveränderten 13 Feldern. NULL und 0 bleiben
unbegrenzt, negative Mengen ungültig. Auswahlwarnings und vor der
Quellenlesung gesetzte ungültige Datenbankstatus bleiben erhalten.

### Native Runtime und Baselines

Ein eigenes Docker-Lab verwendete SQL Server 2025 unter Linux, Major 17,
ProductVersion `17.0.4075.5`. Server und `tempdb` verwendeten
`Latin1_General_100_CS_AS`, das Framework `SQL_Latin1_General_CP1_CS_AS`
und die eigenen Testquellen `Latin1_General_100_CI_AS`. Die Werte wurden
nativ erfasst; konkrete Runtimeidentitäten bleiben außerhalb des Repositorys.

Die unveränderte Procedure aus Basisrevision
`b09cf4d81666d831fab80a99d1c8a9d817ea99b9` wurde getrennt installiert.
Ihre Quelle entspricht dem Stand am neuen Checkpoint
`959ff80b6a73e514c0d8e6660e5bb2de2553d33c`; beide Revisionen besitzen für
das Objekt den Git-Blob `824d3bcc219b90535cfdbd78441ae9f8e3802783`.
Die eigene Baselinequelle enthielt zwei leere CT-Tabellen und deaktiviertes
Auto-Cleanup. Ein synthetischer Wasserstand oberhalb der nativ gelesenen
aktuellen Version erzeugte zwei WARN-Findings und ein Cleanup-INFO.
Fünf tatsächlich ausgeführte Baselines zeigten:

| Vorhandener Vertrag | Beobachtete Abweichung der Basis |
|---|---|
| `@MaxZeilen = NULL` | `INVALID_PARAMETER` und Partialität 1. |
| Findingslimit 1 | TABLE lieferte drei Findings, JSON eines. |
| Problemscope | TABLE lieferte drei Findings, JSON zwei. |
| Gültige plus fehlende Datenbankauswahl | Modulstatus `AVAILABLE`, Partialität 0 und keine erhaltene `DATABASE_UNAVAILABLE`-Warning. |
| Zwei gültige Datenbanken plus Consumer-Wasserstand | Der Modulstatus blieb `INVALID_PARAMETER`; keine Datenbankstatuszeile trug diesen Status. |

Alle fünf TABLE-Exporte besaßen zehn Textspalten mit der abweichenden
tempdb-Collation. Der Frameworklevel der Baseline war 170; die Levels der
Baselinequellen wurden nicht separat erfasst.

### Finale Nachweise

Der kanonische Gesamtinstaller mit 166 Quellen und
`Integration/110_Smoke_Test.sql` bestanden. Anschließend bestanden
`Common/159_DataCaptureDeepAnalysis_Collation_Runtime_Contract.sql` und der
unveränderte `Integration/184_P2_Data_Capture_Runtime_Contract.sql` jeweils
mit Framework-Compatibility-Level 150, 160 und 170: sechs erfolgreiche
Dateiläufe. Common159 setzt beide eigenen Quellen explizit auf denselben
Level und prüft Framework- und beide Sourcelevel getrennt. Diese separate
Sourcelevelbestätigung gilt für Common159, nicht für die historischen
Fixtures von Integration184.

Common159 prüft pro Level 18 TABLE-/JSON-Fälle. Zwei leere Unicode-Tabellen
besitzen unterschiedliche native CT-Identitäten und unterschiedliche
Tracked-Columns-Schalter. Unabhängige Abfragen bestätigen Versionsmetadaten,
den aktuellen Wasserstand, deaktiviertes Auto-Cleanup und fehlende CDC- und
Replikationsrollen. Der künftige synthetische Wasserstand erzeugt zwei
objektbezogene WARNs mit passenden Versionswerten; das Cleanup-INFO bleibt
datenbankbezogen. NULL und 0 liefern drei Findings, der Problemscope zwei
WARNs, Limit 1 genau einen WARN. Die vollständigen Zähler bleiben erhalten.
Eine Gegenprobe mit dem aktuellen Wasserstand liefert keine Future- oder
Reinitialisierungswarning. Schema-, Objekt-, qualifizierte Unicode- und
case-sensitive Filter, fehlende Datenbankauswahl, Mehrdatenbank-Wasserstand
und ungültige Parameter werden getrennt geprüft.

Der Test vergleicht die Findings über alle 13 Felder und
Multimengenhäufigkeiten zwischen TABLE und JSON. Zehn Exporttextspalten
verwenden die Frameworkcollation. Native CT-Metadaten werden unabhängig
gegen die ausgegebenen Identitäten und Versionswerte geprüft; elf
Quellenstatus bilden die unabhängige Sollmenge. RAW und CONSOLE werden
zusätzlich positiv aufgerufen und über Status und JSON-Zeilenanzahl geprüft.
Ihre ausgegebenen Zeilen werden nicht separat abgefangen oder verglichen.
Integration184 enthält acht Runtimefälle, 16 Definitionsprüfungen und eine
Privacy-/Read-only-Prüfung; die 25 Fälle werden nicht als 25 positive
Featurepfade ausgewiesen. Der unabhängige stabile Diffreview meldete keine
offenen Befunde.

Die ausgeführten kanonischen Quellen besitzen folgende UTF-8/LF-SHA-256:

| Quelle | SHA-256 |
|---|---|
| DataCaptureDeep070 | `0EC424D84DDEAF846B5238EA677A6B860DCF0414979595654EF8480748B93324` |
| Common159 | `B8241C0EAF7CC58A947CA7C37EF06C09AB3BB2EC02FD1604D1AC842BF03D9CA9` |

Der native installierte Proceduretext wurde vom qualifizierten Objektnamen
bis zum abschließenden END gegen die kanonische Quelle verglichen. Nach
LF-Normalisierung und Entfernen äußerer Batchmarker stimmen die UTF-16-
Bodyhashes mit
`B17DD12E6F7452B0FCDAB229D3A0C138A3EF8500CD291F654F0F3892A7A038FB`
überein. Der private Runner ersetzte ausschließlich den
Installationsplatzhalter. Der OPS-005-Vollinstaller wurde kanonisch
regeneriert; sein semantischer Diff entspricht dem betroffenen Objekt.

`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Darin bestanden Privacy
mit 1.042 Repositorydateien und null Findings, Schreibstil mit 699
Repositorydateien und null Findings, Roadmap-, Maturity- und
Partialitätsverträge, der NOWAIT-Metadatenvertrag sowie beide Adapterprüfungen.
Nach diesem Ergebnis wurden ausschließlich diese Gateergebnisse ergänzt.

### Aussagegrenze und Cleanup

CT-Retentionverlust, positive CDC- und Replikationsquellen sowie neue
Berechtigungsvarianten bleiben für diesen Slice unbelegt. Change-Zeilen,
Replikationscommands und geschützte Inhalte wurden nicht gelesen. Das Delta
ändert keine Engine-Majorzweige, Berechtigungen oder Katalogschemas; ein
zusätzliches natives Versionsrisiko wurde nicht festgestellt. CL150/160 auf
SQL Server 2025 sind keine nativen 2019-/2022-Nachweise. COLL-001 bleibt
partiell.

Das eigene Lab wurde über `Remove-SqlServerLab -Force -Confirm:$false`
entfernt: Container und Volume, zwei Cleanupschritte, null Fehler,
`CLEANUP_SUCCEEDED` und `REMOVED`. Der eigene verschlüsselte temporäre
Secretwert wurde danach entfernt. Private Prüfzustände bleiben außerhalb
von Git. Die zwei zuvor gesperrten Cleanup-Pfade wurden nicht berührt.

## Encryption-Export und positive Backup-Erwartungsfilter am 6./7. Oktober 2026

Der Slice härtet bestehende Verträge von
`Code/09_VersionAdaptive/080_USP_EncryptionAnalysis.sql`. 22 zuvor implizite
Textspalten und elf Textspalten des neuen Exports verwenden explizit
`SQL_Latin1_General_CP1_CS_AS`. Die Exporttabelle entsteht vor dem NOWAIT-
Quellabschnitt. Nach vollständiger Bewertung versorgt eine gemeinsame
gefilterte und begrenzte Menge RAW, CONSOLE, TABLE und JSON mit unveränderten
26 Feldern. NULL und 0 bleiben unbegrenzt; negative Limits bleiben ungültig
und werden intern ohne negativen TOP-Wert behandelt. Auswahlwarnings setzen
die Modulpartialität erst nach der Quellenbewertung. Die lokale
Aggregationsquelle führt ihre Partialität unabhängig von anderen Quellen.

### Native Runtime und Baseline

Ein eigenes Docker-Lab verwendete SQL Server 2025 unter Linux, Major 17,
ProductVersion `17.0.4075.5`. Server und `tempdb` verwendeten
`Latin1_General_100_CS_AS`, das Framework `SQL_Latin1_General_CP1_CS_AS`
und die eigenen Testquellen `Latin1_General_100_CI_AS`. Die Werte wurden
nativ erfasst; konkrete Runtimeidentitäten bleiben außerhalb des Repositorys.
Die Baseline lief am 6. Oktober; der fokussierte Lauf endete nach dem
Datumswechsel am 7. Oktober 2026 in der Projektzeitzone Europe/Vienna.

Die unveränderte Procedure aus Basisrevision
`554be2c7b8a90b253df2934147e33fb549fc9a2d` wurde getrennt installiert.
Zwei eigene normale unverschlüsselte Datenbanken enthielten keine eigenen
TDE-Schlüssel oder Backupfixtures. Framework und beide Baselinequellen
verwendeten explizit Compatibility Level 170. Sechs ausgeführte
Charakterisierungen zeigten:

| Vorhandener Vertrag | Beobachtete Ausgabe der Basis |
|---|---|
| NULL-Limit mit erwarteter Backupverschlüsselung | TABLE und JSON lieferten je zwei MEDIUM-Findings. |
| Limit 1 mit erwarteter Backupverschlüsselung | TABLE lieferte zwei Findings, JSON eines. |
| Problemscope ohne Schutzvorgabe | TABLE lieferte zwei INFO-Zeilen, JSON keine. |
| Gültige plus fehlende Datenbankauswahl | Modulstatus `AVAILABLE`, Partialität 0 und eine erhaltene Auswahlwarning. |
| Ausschließlich fehlende Datenbankauswahl | Modulstatus `AVAILABLE`, Partialität 0, leere Fachergebnisse und eine Auswahlwarning. |
| Negatives Limit mit JSON-Erzeugung | Fehler 127 verließ den Aufruf; OUTPUT-Statuswerte wurden nicht verlässlich zurückgegeben. |

Alle fünf TABLE-Exporte besaßen elf Textspalten mit der abweichenden
`tempdb`-Collation. In den Auswahlwarningfällen blieben die drei Quellen
unpartiell. Beide eigenen Baselinequellen wurden anschließend entfernt.

### Finale Nachweise

Der kanonische Gesamtinstaller mit 166 Quellen und
`Integration/110_Smoke_Test.sql` bestanden. Anschließend bestanden
`Common/160_EncryptionAnalysis_Collation_Runtime_Contract.sql` und der
unveränderte `Integration/185_P2_Encryption_Runtime_Contract.sql` jeweils
mit Framework-Compatibility-Level 150, 160 und 170: sechs erfolgreiche
Dateiläufe beim ersten Versuch. Common160 setzt alle drei eigenen Quellen
explizit auf denselben Level und prüft Framework- und Sourcelevels getrennt.
Integration185 besitzt keine separate Drei-Sourcelevel-Fixture.

Common160 prüft pro Level 22 TABLE-/JSON-Fälle. Unabhängige native Abfragen
bestätigen drei Datenbankidentitäten, `is_encrypted = 0`, fehlende eigene
Encryption-Key-DMV-Zeilen und fehlende Full-Backupmetadaten im Lookback.
Eigene Column-Master-Key-, Column-Encryption-Key-, verschlüsselte-Spalten-
und Ledger-Anzahlen werden unabhängig mit 0 bestätigt. Die vorhandene
Backupverschlüsselungserwartung erzeugt pro Datenbank
`FULL_BACKUP_EVIDENCE_MISSING` mit Priorität MEDIUM. NULL und 0 liefern
drei Zeilen; Limit 1 liefert genau die erste nach Datenbank-ID. Ohne diese
Erwartung entstehen INFO-Zeilen, die der Problemscope entfernt. Exakte
Unicode- und case-sensitive Auswahlen, umgekehrte Auswahlreihenfolge,
fehlende Auswahl sowie ungültige Parameter werden getrennt geprüft.

Der Test vergleicht alle 26 Felder einschließlich JSON-Feldnamen,
NULL-Eigenschaften und Multimengenhäufigkeiten gegen unabhängige native
Erwartungen und zwischen TABLE und JSON. Elf Exporttextspalten verwenden
die Frameworkcollation. Drei Quellenstatus bilden die unabhängige Sollmenge.
Auswahlwarnings bleiben erhalten; erfolgreiche Quellen bleiben
`AVAILABLE` mit Partialität 0 bei Modulstatus `AVAILABLE_LIMITED` und
Partialität 1. Eine leere oder begrenzte Ausgabe verändert die vollständige
Bewertung und deren Status nicht. Vier zusätzliche RAW-/CONSOLE-Aufrufe
prüfen positive und negative Limits über Status und JSON-Zeilenanzahl.
Ihre ausgegebenen Zeilen werden nicht separat abgefangen oder verglichen.

Integration185 enthält vier synthetische Zustandsmodellfälle, zwei echte
Procedure-Aufrufe für Backup-Erwartung und Berechtigungsfehler sowie einen
AE-Definitionsvertrag. Die separate Privacy-Prüfung bestand ebenfalls.
Diese sieben Fälle belegen keine sieben positiven nativen Schutzfeatures.
Der unabhängige stabile SQL-/Harnessreview meldete keine offenen Befunde.

Die ausgeführten kanonischen Quellen besitzen folgende UTF-8/LF-SHA-256:

| Quelle | SHA-256 |
|---|---|
| Encryption080 | `F5C17DC84CF16E26AD6446B16A9158AD371CB4D1FE90843AA8356DB21E395F8F` |
| Common160 | `467E5B2B12309779B761B776CD45A87BB9611F5041F408046903DAB22FCEEC1A` |

Der native installierte Proceduretext wurde vom qualifizierten Objektnamen
bis zum abschließenden END gegen die kanonische Quelle verglichen. Nach
LF-Normalisierung und Entfernen äußerer Batchmarker stimmen die UTF-16-
Bodyhashes mit
`E36F3E3A37F1DFA69942BA7E65FC1664EB4E2D29D946A014E0E335253E52DFE4`
überein. Der private Runner ersetzte ausschließlich den
Installationsplatzhalter. Der OPS-005-Vollinstaller wurde kanonisch
regeneriert; sein semantischer Diff entspricht dem betroffenen Objekt.

### Aussagegrenze und Cleanup

Aktive TDE-, Zertifikat-, verschlüsselte Backup-, AE- und Ledgerzustände
sowie externe Schlüsselkopien und Restore bleiben für diesen Slice
unbelegt. Viele Verschlüsselungsfelder sind deshalb ausschließlich als
NULL oder Nullmengen geprüft. Common160 aktiviert keine Schutzfeatures,
erstellt keine Backups und liest keine Schlüssel- oder Medieninhalte.
Der Major-vor-16-Ledger-NULL-Zweig des Tests wurde nicht nativ ausgeführt.
Das Produktdelta ändert keine Engine-Majorzweige, Berechtigungen oder
Katalogschemas; ein zusätzliches natives Versionsrisiko wurde nicht
festgestellt. CL150/160 auf SQL Server 2025 sind keine nativen
2019-/2022-Nachweise. COLL-001 bleibt partiell.

Das eigene Lab wurde über `Remove-SqlServerLab -Force -Confirm:$false`
entfernt: Container und Volume, zwei Cleanupschritte, null Fehler,
`CLEANUP_SUCCEEDED` und `REMOVED`. Der eigene verschlüsselte temporäre
Secretwert wurde danach entfernt. Private Prüfzustände bleiben außerhalb
von Git. Die zwei zuvor gesperrten Cleanup-Pfade wurden nicht berührt.

`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Darin bestanden Privacy
mit 1.043 Repositorydateien und null Findings, Schreibstil mit 700
Repositorydateien und null Findings, Roadmap-, Maturity- und
Partialitätsverträge, der NOWAIT-Metadatenvertrag mit 904 Temp-Namen sowie
beide Adapterprüfungen. Nach diesem Ergebnis wurden ausschließlich diese
Gateergebnisse ergänzt.

## MaintenanceOperations: gemischter Collation- und Exportvertrag vom 7. Oktober 2026

Der Slice betrifft `Code/07_Infrastructure/130_USP_MaintenanceOperations.sql`
und Common161. Die öffentliche TABLE-Fläche bleibt auf
`resumableOperations` begrenzt. Positive resumierbare Operationen, laufende
Wartungsrequests, ausgewählte Agent-Jobs und Hochlast sind mit diesem Slice
nicht belegt. Der unveränderte Integration186-Vertrag ergänzt drei
synthetische Zustandsprüfungen, einen echten eingeschränkten Procedureaufruf
und einen separaten Read-only-Definitionscheck.

### Baseline und Produktdelta

Die kanonische Baseline stammt aus
`66b136482eef10abfe95c931e426b76311062ee2`. Sechs private kontrollierte
Aufrufe verwendeten zwei eigene Unicode-Datenbanken ohne Nutzdaten und
einen tatsächlich nicht vorhandenen synthetischen Namen. Die fünf gültigen
TABLE-Aufrufe lieferten einen leeren Resumable-Scope mit acht falsch
collatierten Textspalten. Die PVS-JSON-Mengen hatten mit unbegrenzter
Auswahl zwei Zeilen, mit Limit 1 eine und im Problemscope keine Zeile.
Bei gültiger und fehlender Auswahl sowie bei ausschließlich fehlender
Auswahl blieb der Modulstatus fälschlich `AVAILABLE/IsPartial=0`.
Der negative Mengenparameter ließ Fehler 127 entweichen; die vorher
zurückgesetzten OUTPUT-Statuswerte blieben NULL. Die Leermenge belegt
keine positive Resumable-Filter- oder Limitabweichung.

Eine anschließende native Probe aktivierte ADR in den beiden eigenen
Datenbanken ohne DML. Tatsächlich vorhandene DMV-Zeilen lieferten zu
diesem Zeitpunkt Nullzähler. Der vorhandene Schwellwert 0 erzeugte einen
`PVS_SIZE_THRESHOLD_REACHED`-Hinweis mit Priorität MEDIUM und
`AVAILABLE_WITH_FINDING/IsPartial=0`. Die Probe belegt einen kontrollierten
Schwellwertfall, keine Hochlast oder Bereinigungsstörung. Ihre eigenen
Datenbanken wurden anhand der gespeicherten Identitäten entfernt.

Das Produktdelta versieht 57 lokale Textspalten mit
`SQL_Latin1_General_CP1_CS_AS`. Vier typgleiche Exporte mit 15, 19, 9 und
7 Feldern werden vor dem Kandidatenhelper angelegt und nach vollständiger
Befundbewertung gemeinsam gefiltert und begrenzt. TABLE und aktives CONSOLE
verwenden ausschließlich den Resumable-Export. RAW und JSON verwenden
zusätzlich die bestehenden Request-, PVS- und Jobmengen. Die öffentliche
JSON-Struktur besitzt weiterhin sechs Top-Level-Properties und kein
Warning-Array. Auswahlwarnings begrenzen den Modulstatus, während
erfolgreiche Quellenstatus unabhängig erhalten bleiben. Negative Limits
verwenden intern eine sichere Nullgrenze und liefern `INVALID_PARAMETER`.

### Tatsächlich ausgeführter Runtimeumfang

Das eigene Linux-Lab verwendete SQL Server 2025, ProductVersion
`17.0.4075.5`, Server- und `tempdb`-Collation
`Latin1_General_100_CS_AS` sowie die Frameworkcollation
`SQL_Latin1_General_CP1_CS_AS`. Das Framework und alle drei eigenen
Unicode-Quellen mit `Latin1_General_100_CI_AS` wurden separat auf
Compatibility Level 170 bestätigt. Es wurden keine zusätzlichen
Compatibility Levels oder älteren nativen Engines ausgeführt.

Die Installation aus 166 kanonischen Dateien und Smoke110 bestanden.
Der abschließende fokussierte Lauf bestand Common161 mit 24
TABLE-/JSON-Fällen und sechs RAW-/CONSOLE-Statusfällen sowie Integration186.
Die TABLE-Prüfung vergleicht die relative Reihenfolge, Namen, Typen,
Längen, Precision, Scale, Nullbarkeit und Collation aller 15 Felder.
Alle acht Textspalten besitzen die garantierte Collation; der eigene
Resumable-Scope bleibt leer.

Eine Quelle bleibt ADR-OFF, zwei Quellen aktivieren ADR ohne Nutzdaten
oder DML. Die PVS-Auswahl prüft native Identitäten, ADR-Schalter,
Online-Index- und Aborted-Zähler sowie die bestehende Schwellwertbewertung.
Die veränderliche PVS-Größe wird mit nativen Messungen vor und unmittelbar
nach dem TABLE-Aufruf eingeschlossen. Ihr einzelner JSON-Knoten muss den
nativen NULL-Vertrag beziehungsweise Zahlentyp und die gemessenen Grenzen
einhalten. Erst danach wird ausschließlich dieser validierte Größenwert
für den Neun-Feld-Multimengenvergleich normalisiert. Die übrigen acht
Felder, Properties, Typen und Häufigkeiten werden exakt verglichen. Dieser
Zeitvertrag ist keine atomare Zeitpunktparität; ein Zwischenwert außerhalb
beider Endpunkte wäre zunächst zeitlich unbestimmt.

Geprüft sind positive Unicode-/Case-Auswahl, NULL-/0-/positive Limits,
gemischte INFO-/MEDIUM-Mengen, Problemfilter, die Modulbewertung vor dem
Limit, fehlende Auswahl und ungültige Parameter. Vier Quellenidentitäten
werden unabhängig gegengeprüft: drei erfolgreiche Quellen und die nicht
angeforderte Jobquelle. RAW und CONSOLE prüfen ausschließlich OUTPUT-Status
und begleitende JSON-Zeilenanzahl. Ausgegebene RAW-Zeilen und Warnings
werden damit nicht als native Zeilenparität behauptet.

Drei vorangegangene Harnessläufe schlugen fehl. Die Diagnosen belegten
interne ADR-Allokation trotz fehlender Nutzdaten, Lücken in absoluten
Spaltenkennungen nach entfernten Hilfsspalten und eine zeitlich veränderte
PVS-Größe. Die Testkorrekturen akzeptieren vorhandene nichtnegative
PVS-Werte, vergleichen relative Spaltenordinals und prüfen das native
Vorher-/Nachher-Intervall. Der Produktstand wurde dabei nicht verändert.
Erst der abschließende unveränderte fokussierte Lauf war erfolgreich.

### Quellidentität, Aussagegrenze und Cleanup

Die UTF-8/LF-Hashes betragen für die kanonische Procedure
`D5C496736BA9717943996579282222B34A9F060787C116E34715962E2404FF54`
und für Common161
`16025FC2726F2AB7BB3E690935ABA581CD6907336449AE2BCC28E766551AEB24`.
Der native installierte Body ab dem qualifizierten Objektnamen stimmt
nach LF-Normalisierung und Entfernen äußerer Batchmarker mit der
kanonischen UTF-16-Identität
`66E65F6C322727AF9C1CE4622D2BE92C0D6603A0DA35427EFFECA145B1E395B6`
überein. Der private Runner ersetzte ausschließlich den
Installationsplatzhalter. Der OPS-005-Installer wurde kanonisch regeneriert.

Positive Resumable-, Request- und Jobmengen, Aborted-Transaktionen,
PVS-Hochlast und Bereinigungsstörungen bleiben für diesen Slice unbelegt.
Der Major-vor-16-Skip von Common161 wurde nicht nativ ausgeführt.
Framework und Quellen dürfen im Harness 150, 160 oder 170 verwenden;
dieser Lauf belegt ausschließlich 170 auf SQL Server 2025. Das Produktdelta
ändert keine Engine-Majorzweige, Berechtigungen oder Katalogschemas.
Ein zusätzliches natives Versionsrisiko wurde nicht festgestellt.
COLL-001 bleibt partiell.

Nach dem erfolgreichen Lauf waren keine eigenen Fixture-Datenbanken
vorhanden. Das eigene Lab wurde mit
`Remove-SqlServerLab -Force -Confirm:$false` entfernt: Container und Volume,
zwei Cleanupschritte, null Fehler, `CLEANUP_SUCCEEDED` und `REMOVED`.
Der eigene verschlüsselte temporäre Secretwert wurde danach entfernt.
Private Prüfzustände bleiben außerhalb von Git; die zuvor gesperrten
Cleanup-Pfade wurden nicht berührt.

`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Privacy prüfte 1.044
Repositorydateien ohne Findings, Schreibstil 701 und Regex 333.
Roadmap-, Maturity- und Partialitätsverträge, der NOWAIT-Metadatenvertrag
mit 914 Temp-Namen sowie beide Adapterprüfungen bestanden ebenfalls.
Nach diesem Ergebnis wurden ausschließlich diese Gateergebnisse ergänzt.

## AvailabilityDeepAnalysis: HADR-deaktivierter Exportvertrag vom 7. Oktober 2026

Der Slice betrifft
`Code/07_Infrastructure/110_USP_AvailabilityDeepAnalysis.sql` und Common162.
Die öffentliche TABLE-Fläche bleibt auf `replicas` begrenzt. Der native
Nachweis umfasst ausschließlich das tatsächlich deaktivierte HADR,
Leermengen, Schemas, Collations, JSON-Struktur und Parameterverhalten.
Eine aktive AG-Topologie oder positive Replikabegrenzung wird nicht behauptet.

### Baseline und Produktdelta

Die Baseline stammt aus
`696c9e9835f5ea8d9e58f779ddc7a05057212ec1` und wurde im eigenen Lab
nach kanonischer Installation und Smoke110 separat installiert. Sechs
kontrollierte Aufrufe verwendeten keine Quelldatenbanken oder Clusterobjekte.
Die gültigen NULL-/0-/Limit-1-Aufrufe lieferten
`NOT_APPLICABLE/IsPartial=0`, einen leeren Replikaexport und zehn falsch
collatierte TABLE-Textspalten. NULL für die Queuegrenze und eine negative
Laggrenze lieferten bereits korrekt `INVALID_PARAMETER/IsPartial=1`,
ebenfalls mit zehn falsch collatierten TABLE-Textspalten. Ein negativer
Mengenparameter im NONE-/JSON-Pfad ließ dagegen Fehler 127 entweichen;
die zuvor zurückgesetzten OUTPUT-Statuswerte blieben NULL. Die Leermengen
belegen keine positive Replika-Limitabweichung.

Die sieben bestehenden Arbeitstabellen besitzen 36 explizit collatierte
Textspalten. Ein typgleicher Replikaexport ergänzt zehn Textspalten und
entsteht vor den Ausgabehelpern. Nach vollständiger Statusbewertung wird
die Replikamenge einmal geordnet und begrenzt. TABLE, aktives CONSOLE,
RAW und JSON verwenden diese gemeinsame Auswahl. Die übrigen
RAW-/JSON-Limits bleiben erhalten; Cluster bleibt ohne Mengenlimit.
NULL und 0 sind unbegrenzt, positive Werte begrenzen und negative Werte
verwenden intern eine sichere Nullgrenze bei `INVALID_PARAMETER`.

Die öffentliche JSON-Struktur bleibt bei `meta` und sieben Arrays.
Separate Quellenstatus- oder Warning-Arrays werden nicht eingeführt.
Die betroffenen Dokumente präzisieren den vorhandenen Modulstatus sowie
die bestehende Cluster-Ausnahme. HADR-Sammlung, Interpretationsfunktionen,
Berechtigungen, Versionszweige und Katalogschemas bleiben unverändert.

### Tatsächlich ausgeführter Runtimeumfang

Das eigene Linux-Lab verwendete SQL Server 2025, ProductVersion
`17.0.4075.5`, mit nativ bestätigtem `IsHadrEnabled=0`. Server und `tempdb`
verwendeten `Latin1_General_100_CS_AS`; das Framework verwendete
`SQL_Latin1_General_CP1_CS_AS` und separat bestätigtes Compatibility
Level 170. Es wurden keine Quelldatenbanken, Availability Groups,
Clusterobjekte, Netzwerkpfade oder Seedingzustände erzeugt.

Die Installation aus 166 kanonischen Dateien und Smoke110 bestanden.
Der fokussierte Common162-Lauf bestand im ersten Versuch zehn
TABLE-/JSON-Fälle, vier RAW-/CONSOLE-Statusfälle und zwei zusätzliche
JSON-Consumerfälle. Der TABLE-Schemavergleich prüft relative Ordinals,
Namen, Typen, Längen, Precision, Scale, Nullbarkeit und Collation aller
elf Felder. Alle zehn Textspalten besitzen die garantierte Collation.
Die JSON-Prüfung vergleicht acht Top-Level-Properties, acht Metafelder
mit ursprünglichen Typen, tatsächliche Majorversion und zeitlich
eingeschlossene Erfassungszeit. Alle sieben Arrays bleiben leer.

Gültige Aufrufe erwarten `NOT_APPLICABLE/IsPartial=0`; ungültige Queue-,
Lag-, Mengen- und Ausgabeparameter erwarten `INVALID_PARAMETER/IsPartial=1`.
NULL-/0-/positive Mengenwerte und die Netzwerkoption sind im Leerscope
auf Akzeptanz geprüft. Die Netzwerkoption aktiviert damit keine echte
Netzwerkquelle. RAW und CONSOLE werden ausschließlich über OUTPUT-Status
und begleitende JSON-Mengen geprüft; ihre ausgegebenen Zeilen werden
nicht separat abgefangen. Die zwei zusätzlichen JSON-Consumerfälle
verwenden eine NULL-Queuegrenze und eine ungültige Ausgabeart.

Integration176 bestand bei CL170 mit einem echten AG-NONE-Aufruf und
drei synthetischen Interpretationsfällen für Suspend, Queue und Seeding.
Die synthetischen TVF-Eingaben sind keine native AG-, Queue- oder
Seedingevidenz. Auf dem Lab wurde keine operative HADR-Aktion ausgeführt.

### Quellidentität, Aussagegrenze und Cleanup

Die UTF-8/LF-Hashes betragen für die kanonische Procedure
`88207C88EBE4C7F5DBB90AE856A186FE4CE836F2A0C6FE95C849FE1764FA9089`
und für den tatsächlich ausgeführten Common162-Stand
`4A3B0663C703619F300F279472994CFC49E9954B6BFBEE9C917CBAAC5D117A2F`.
Nach dem Lauf wurde ausschließlich ein Kommentar zu den beiden zusätzlichen
JSON-Verbraucher-Aufrufen korrigiert. Der finale Common162-Stand besitzt
den UTF-8/LF-Hash
`C47AD774B7F184286D93F8215BD80EF707C677F4ADCC22D7BF19F89E67B75AED`.
Der Vergleich mit `normalize_executable_sql` aus Validator925 bestätigt
die identische ausführbare SQL nach Rücksetzen des Installationsplatzhalters.
Der erfolgreiche native Lauf wurde für diese Kommentarkorrektur nicht wiederholt.
Der native installierte Body ab dem qualifizierten Objektnamen stimmt
nach LF-Normalisierung und Entfernen äußerer Batchmarker mit der
kanonischen UTF-16-Identität
`8CA30B12168DA103F27325788F53CC0D74FEE4ACC1D6704F1C8C2449AA98C15B`
überein. Der private Runner ersetzte ausschließlich den
Installationsplatzhalter. Der OPS-005-Installer wurde kanonisch regeneriert.

Positive AG-, Replika-, Queue-, Cluster-, Netzwerk-, Seeding-,
Seitenreparatur-, Berechtigungs- und Limitnachweise bleiben für diesen
Slice unbelegt. Common162 meldet bei aktiviertem oder unbekanntem HADR
vor den Testfällen `NOT_EXECUTED`; dieser Zweig wurde nicht nativ
ausgeführt. Der Harness akzeptiert Frameworklevels 150, 160 und 170;
der aktuelle Lauf belegt ausschließlich 170 auf SQL Server 2025.
Zusätzliche Compatibility Levels und ältere native Engines wurden nicht
ausgeführt. Ein zusätzliches natives Versionsrisiko wurde nicht
festgestellt. COLL-001 bleibt partiell.

Das eigene Lab wurde mit `Remove-SqlServerLab -Force -Confirm:$false`
entfernt: Container und Volume, zwei Cleanupschritte, null Fehler,
`CLEANUP_SUCCEEDED` und `REMOVED`. Der eigene verschlüsselte temporäre
Secretwert wurde danach entfernt. Private Prüfzustände bleiben außerhalb
von Git; die zuvor gesperrten Cleanup-Pfade wurden nicht berührt.

`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Privacy prüfte 1.044
Repositorydateien ohne Findings, Schreibstil 702 und Regex 334.
Roadmap-, Maturity- und Partialitätsverträge, der NOWAIT-Metadatenvertrag
mit 919 Temp-Namen sowie beide Adapterprüfungen bestanden ebenfalls.
Nach diesem Ergebnis wurden ausschließlich diese Gateergebnisse ergänzt.

## External Runtime: 7. Oktober 2026

### Ausgangsstand und Produktänderung

Der unveränderte Stand aus `5d8c3437013342067d2c3556c995f139d43928d0`
wurde auf SQL Server 2025 mit Frameworklevel 170 separat installiert.
Sechs abschließende Charakterisierungsfälle bestätigten zehn fremd
kollatierte TABLE-Textspalten. NULL als Mengenwert ergab
`INVALID_PARAMETER/IsPartial=1`; 0 lieferte drei Findings. Limit 1
lieferte weiterhin drei TABLE-Zeilen, aber nur eine JSON-Zeile.
Der Problemfilter lieferte ebenfalls drei TABLE-Zeilen gegenüber einer
JSON-Zeile. Ein negativer Mengenwert wurde mit Fehler 127 als
`ERROR_HANDLED/IsPartial=1` behandelt; JSON blieb NULL. Eine ausschließlich
fehlende Datenbankauswahl meldete trotz partiellem Datenbankstatus
`NOT_APPLICABLE/IsPartial=0` auf Modulebene.

Der private Baselineaufbau benötigte zuvor zwei Korrekturen: den
geklammerten Alias `[RowCount]` und eine neue TABLE-Zieltabelle je Aufruf.
Diese Aufbaufehler sind keine zusätzlichen Produktfehler.

Die Procedure besitzt jetzt 96 explizit collatierte lokale Textfelder.
Ein früher, nicht identitätsgenerierender Findings-Export übernimmt die
13 vorhandenen Felder und die ursprünglich gesammelten Findingordinale.
TABLE, CONSOLE, RAW und JSON verwenden dieselbe Problemfilter- und
Limitentscheidung. NULL und 0 sind unbegrenzt; negative Werte werden
mit einer sicheren internen Nullgrenze als `INVALID_PARAMETER` abgewiesen.
Modulstatus und Truncation bewerten zuvor die vollständige Sammlung.
Fehlende Datenbankauswahl fließt in die späte Modulpartialität ein;
erfolgreiche Quellenstatus und vollständige Zähler bleiben erhalten.

Die einzige Inventaränderung beschreibt die tatsächliche Exportquelle:
zehn explizite Textcollations und kein IDENTITY-Merkmal. Feldnamen,
Typen, Nullbarkeit, Versionskennung und der bestehende nicht
identitätsgenerierende TABLE-Zielvertrag bleiben erhalten. Die
Dokumentation beschreibt außerdem das bereits vorhandene Owner-Gate
für `@MitBerechtigungsanalyse` und den davon unabhängigen Opt-in
`@MitDateimetadaten`. Ein neues Gate wurde nicht eingeführt.

### Tatsächlich ausgeführter Runtimeumfang

Das eigene Linux-Lab verwendete SQL Server 2025, ProductVersion
`17.0.4075.5`. Server und `tempdb` verwendeten
`Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Installation aus 166 kanonischen Dateien
und Smoke110 bestanden. Common163 und Integration198 bestanden
anschließend auf Frameworklevels 150, 160 und 170.

Common163 erzeugte jeweils zwei eigene leere Unicode-Datenbanken mit
nur in der Großschreibung abweichenden Namen und
`Latin1_General_100_CI_AS`. Die beiden Quellenlevels wurden ausdrücklich
auf den jeweiligen Frameworklevel gesetzt und getrennt bestätigt.
Die vorhandenen nativen R-/Python-Registrierungen wurden unabhängig
gelesen. Bei deaktivierten externen Scripts liefern solche
Registrierungen vorhandene WARN-/INFO-Findings für positive Filter-
und Limitprüfungen. Neue Language- oder Libraryregistrierungen und
externe Ausführung fanden nicht statt.

Je Level bestanden 22 TABLE-/JSON-Fälle und vier RAW-/CONSOLE-Aufrufe.
Der TABLE-Vertrag prüft alle 13 Felder, relative Ordinals, Namen, Typen,
Längen, Precision, Scale, Nullbarkeit und zehn Textcollations.
Der vollständige JSON-Repräsentationsvergleich erhält die bestehende
Auslassung von NULL-Properties. Zwölf Top-Level-Properties sowie
native Quellenstatus, Katalogidentitäten, Zähler, Konfiguration,
Poolmetadaten und Counteridentitäten werden unabhängig gegengeprüft.
Nichtleere Pool-/Counterquellen werden dabei ebenso geprüft wie leere.
Veränderliche Counterwerte besitzen keinen behaupteten atomaren
Gegenprüfungszeitpunkt.

Geprüft sind NULL-/0-/positive Limits, Problemfilter, exakte
Unicode-Datenbankauswahl, fehlende und in der Großschreibung abweichende
Auswahl, leere exakte und LIKE-Sprachfilter sowie ungültige Mengen-,
Sample-, Timeout-, Filter- und Optionsparameter. Vollständige
Quellen-/Datenbankzähler und Warnungen werden vor Ausgabelimits geprüft.
RAW und CONSOLE werden ausschließlich über OUTPUT-Status und
begleitende JSON-Mengen geprüft; ihre ausgegebenen Zeilen werden
nicht separat abgefangen. Alle gültigen Common163-Analyseaufrufe verwenden
`@SampleSeconds=0`; NULL und 61 prüfen ausschließlich die
Parameterablehnung ohne Sampling.
Integration198 prüft zusätzlich die vorhandenen Installations-,
Discovery-, JSON-, TABLE- und LOCK_TIMEOUT-Verträge beider
RUNTIME-001-Procedures ohne externe oder CLR-Ausführung.

Der erste Common163-Aufbau scheiterte mit 5170/1802 an den automatisch
abgeleiteten Dateinamen der case-only Datenbanken. Getrennte synthetische
Upper-/Lower-Dateinamen mit UUID-Suffix aus den nativen Standardpfaden
beheben diese Aufbaukollision. Ein weiterer CL150-Versuch erreichte
den leeren Sprachfilter und scheiterte mit 56710: Der skalare TABLE-
JSON-Ausdruck lieferte NULL gegenüber dem korrekten Produktarray `[]`.
Der Harness normalisiert ausschließlich diese leere Darstellung auf
`[]`; nichtleere Parität und die Ablehnung fehlenden Produkt-JSON bleiben
unverändert. Nach beiden Korrekturen bestand der abschließende Lauf
auf allen drei Levels. Die Fehlerpfade entfernten ihre eigenen
Fixturedatenbanken; auch nach dem erfolgreichen Lauf waren beide
Fixtureidentitäten nativ nicht mehr vorhanden.

### Quellidentität, Aussagegrenze und Cleanup

Die tatsächlich ausgeführten UTF-8/LF-Hashes betragen für die
kanonische Procedure
`455913C2E5B6FB95F8DD004DB4B3B78540823A58F206C358F7CEDEC697C0F1DF`
und für Common163
`F7576FFEA6F2D0D632C75344C27D5DD2A51CB6AB985BB3C50BA5E1730105164D`.
Der native installierte Body ab dem qualifizierten Objektnamen stimmt
nach LF-Normalisierung und Entfernen äußerer Batchmarker mit der
kanonischen UTF-16-Identität
`23B0E565ABCFC01AAA0FC24DBECB04865BFD4E2F1B86B9C5FBE4232C594D77B2`
überein. Der private Runner ersetzte ausschließlich den
Installationsplatzhalter. Der OPS-005-Installer wurde kanonisch regeneriert.

Aktivierte Runtimefeatures, externe Ausführung oder Startfähigkeit,
positive Library-/Requestquellen, zeitbezogene Samples,
Berechtigungs-/Sitzungskontext- und Dateimetadatenoptionen bleiben für
diesen Slice unbelegt. Leere Sprachfilter belegen keine positive
Sprachfilterwirkung. Neue Nachweise für ältere native Engines wurden
nicht ausgeführt; ein zusätzliches natives Versionsrisiko wurde nicht
festgestellt. `RUNTIME-001` bleibt
`IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING`; `COLL-001` bleibt partiell.

Das eigene Lab wurde mit `Remove-SqlServerLab -Force -Confirm:$false`
entfernt: Container und Volume, zwei Cleanupschritte, null Fehler,
`CLEANUP_SUCCEEDED` und `REMOVED`. Der eigene verschlüsselte temporäre
Secretwert wurde danach entfernt. Private Prüfzustände bleiben außerhalb
von Git; die zuvor gesperrten Cleanup-Pfade wurden nicht berührt.

`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Privacy prüfte 1.046
Repositorydateien ohne Findings, Schreibstil 703 und Regex 335.
Roadmap-, Maturity- und Partialitätsverträge, der NOWAIT-Metadatenvertrag
mit 932 Temp-Namen sowie beide Adapterprüfungen bestanden ebenfalls.
Nach diesem Ergebnis wurden ausschließlich diese Gateergebnisse und
die beiden im Evidenzreview präzisierten Sample-/Ownerformulierungen
ergänzt; SQL, Tests und ihre Quellidentitäten blieben unverändert.

## SQL CLR: 7. Oktober 2026

### Ausgangsstand und Änderung

Die unveränderte Procedure aus dem Literalcommit
`75081e4e697da2ea40acbcc5b6a2154573a141f7` wurde vor der Änderung
nativ installiert. Ihr UTF-8/LF-Hash betrug
`D55F74A94099EB93EA88120BA6CE85FFD680A8CBC7C4A211A7B65B3389DA055C`.
Sechs Charakterisierungsfälle bestätigten zehn abweichende
TABLE-Textcollations. NULL als Zeilenlimit wurde als
`INVALID_PARAMETER` abgelehnt; ein negatives Limit führte zu
`ERROR_HANDLED`, Fehler 127 und fehlendem JSON. Die Limits 0 und 1
sowie der Problemfilter lieferten bei leerer Assemblyauswahl
`NOT_APPLICABLE`. Auch eine ausschließlich fehlende Datenbankauswahl
lieferte diesen Gesamtstatus ohne Partialität, obwohl ihr
Datenbankstatus partiell war. Der Charakterisierungslauf hatte keinen
Harnessfehler.

`monitor.USP_ClrAnalysis` verwendet jetzt für alle 106 lokalen
Textspalten ausdrücklich `SQL_Latin1_General_CP1_CS_AS`. Die Zahl
enthält die zehn Texte der gemeinsamen Exporttabelle. Diese Tabelle
besteht vor Helperaufrufen und NOWAIT-Meldungen. Sie besitzt die
bisherigen 13 Findingfelder ohne Identity; ursprüngliche Ordinale
werden aus der privaten Identity-Sammlung übernommen. Namen, Typen,
Längen, Nullbarkeit und SchemaVersion 1 bleiben erhalten. Die
Inventarzeile beschreibt genau diese Exportquelle.

NULL und 0 erlauben eine unbegrenzte Ausgabe. Negative Limits werden
als `INVALID_PARAMETER` abgelehnt und intern auf einen sicheren
TOP-Wert begrenzt. JSON, RAW, TABLE und CONSOLE verwenden dieselbe
gefilterte und begrenzte Findingmenge. WARN-Bewertung, Quellen- und
Datenbankzähler sowie bestehende Truncationbedingungen werden vor
Ausgabeauswahl auf der vollständigen Sammlung bewertet. Der späte
Gesamtstatus berücksichtigt zusätzlich partielle Datenbankstatus und
Auswahlwarnungen. Quellenqueries, Versionszweige, Berechtigungen und
Opt-ins wurden fachlich nicht erweitert.

### Nativer Lauf und unabhängige Gegenprüfungen

Ein eigenes SQL-Server-2025-Docker-Lab bestätigte ProductVersion
`17.0.4075.5`, Major 17 und Linux. Server und `tempdb` verwendeten
`Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Installation aus 166 kanonischen Dateien
und Smoke110 bestanden. Common164 und Integration198 bestanden
anschließend auf Frameworklevels 150, 160 und 170 ohne Laufzeitfehler.

Common164 erzeugte je Level zwei eigene leere Unicode-Datenbanken mit
nur in der Großschreibung abweichenden Namen und
`Latin1_General_100_CI_AS`. Beide Quellenlevels wurden ausdrücklich
auf den Frameworklevel gesetzt und getrennt bestätigt. Je Level
bestanden 24 TABLE-/JSON-Fälle und vier RAW-/CONSOLE-Aufrufe. Der
TABLE-Vertrag prüft alle 13 Felder, relative Ordinals, Namen, Typen,
Längen, Precision, Scale, Nullbarkeit, Identityeigenschaft und zehn
Textcollations. Leere Findingmengen wurden in TABLE und JSON verglichen.
Die bestehenden 16 JSON-Top-Level-Properties und die Auslassung von
NULL-Properties bleiben erhalten.

Geprüft sind NULL-/0-/positive und negative Limits, Problemfilter,
exakte Unicode-Datenbankauswahl, fehlende und in der Großschreibung
abweichende Auswahl, leere exakte und LIKE-Assemblyfilter,
Modulzuordnungsoption sowie ungültige Sample-, Timeout-, Filter- und
Optionsparameter. Alle gültigen Common164-Aufrufe verwenden
`@SampleSeconds=0`; NULL und 61 prüfen ausschließlich die Ablehnung.
RAW und CONSOLE werden über OUTPUT-Status und begleitende JSON-Mengen
geprüft; ihre ausgegebenen Zeilen werden nicht separat abgefangen.

Die Quellenstatus werden gegen acht unabhängige serverweite Quellen
und die sichtbaren Katalogquellen je Datenbank geprüft. Konfiguration,
CLR-Properties, Datenbankidentitäten, TRUSTWORTHY-Flags, Katalogzähler,
Memory-Clerk-Identitäten und Counteridentitäten werden unabhängig
gegengelesen. Der native Host meldete Version `v4.0.30319` und Zustand
`CLR is initialized`; zwei Memory-Clerk-Gruppen sowie ein Counter des
Typs 65792 waren vorhanden. Positive Memory-Ausgabebegrenzung und
Sample-0-Counterinterpretation sind geprüft. Veränderliche Speicher-
und Counterwerte besitzen keinen behaupteten atomaren
Gegenprüfungszeitpunkt. Vollständige Warnungen und Zähler werden
getrennt von Ausgabelimits geprüft. Integration198 prüft außerdem die
Installations-, Discovery-, JSON-, TABLE- und LOCK_TIMEOUT-Verträge
beider RUNTIME-001-Procedures ohne externe oder CLR-Ausführung.

### Quellidentität, Aussagegrenze und Cleanup

Die tatsächlich ausgeführten UTF-8/LF-Hashes betragen für die
kanonische Procedure
`862693D9293E51AF2B87E0193A4C09B37517950B18D46343F4DB18F1768B5F41`
und für Common164
`7693261E2FA4B3A6D1E5695E1EDE8CB1CE9521FF0346957325F6A402AEB58C90`.
Der native installierte Body ab dem qualifizierten Objektnamen stimmt
nach LF-Normalisierung und Entfernen äußerer Batchmarker mit der
kanonischen UTF-16-Identität
`F6421CA24373C2786B2178A11DD9EF7B6B35DF1232BD4532A3D349D18B07F433`
überein. Der private Runner ersetzte ausschließlich den
Installationsplatzhalter. Der OPS-005-Installer wurde kanonisch regeneriert.

CLR blieb deaktiviert und Strict Security aktiviert. Neue Assemblies,
CLR-Ausführung, TRUSTWORTHY- oder globale Konfigurationsänderungen
fanden nicht statt. Positive Assembly-, Modul-, Dependency-,
AppDomain-, Loaded-Assembly-, Task- und Requestquellen sowie positive
Findingfilter-/Limitwirkung bleiben unbelegt. Leere Assemblyfilter
belegen keine positive Assemblyfilterwirkung. Zeitbezogene Samples,
Berechtigungs- und Sitzungskontextoptionen bleiben für diesen Slice
unbelegt. Neue Nachweise für ältere native Engines wurden nicht
ausgeführt; ein zusätzliches natives Versionsrisiko wurde nicht
festgestellt. `RUNTIME-001` bleibt
`IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING`; `COLL-001` bleibt partiell.

Nach dem erfolgreichen Lauf waren beide Fixtureidentitäten nativ
nicht mehr vorhanden. Das eigene Lab wurde mit
`Remove-SqlServerLab -Force -Confirm:$false` entfernt: Container und
Volume, zwei Cleanupschritte, null Fehler, `CLEANUP_SUCCEEDED` und
`REMOVED`. Der eigene verschlüsselte temporäre Secretwert wurde danach
entfernt. Private Prüfzustände bleiben außerhalb von Git; die zuvor
gesperrten Cleanup-Pfade wurden nicht berührt.

`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Privacy prüfte 1.047
Repositorydateien ohne Findings, Schreibstil 704 und Regex 336.
Roadmap-, Maturity- und Partialitätsverträge, der NOWAIT-Metadatenvertrag
mit 943 Temp-Namen sowie beide Adapterprüfungen bestanden ebenfalls.
Nach diesem Ergebnis wurden ausschließlich diese Gateergebnisse
ergänzt; SQL, Tests und ihre Quellidentitäten blieben unverändert.

## Bereichsorchestratoren: 7. Oktober 2026

### Nativer Ausgangsstand

Die drei unveränderten Bereichsorchestratoren aus dem Literalcommit
`eff604c624daaac1743417022924acfeaddfef5e` wurden in einem eigenen
SQL-Server-2025-Docker-Lab mit ProductVersion `17.0.4075.5`, Major 17,
Linux und Framework-Compatibility-Level 170 installiert. Server und
`tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Installation aus 166 kanonischen Dateien
und Smoke110 bestanden.

Der Ausgangsstand reproduzierte neun Charakterisierungsfälle ohne
Harnessfehler. Für `USP_PlanCacheAnalysis`, `USP_QueryStoreAnalysis` und
`USP_ExtendedEventsAnalysis` scheiterten jeweils der leere CONSOLE-Pfad
mit allen Childschaltern 0 und ein CONSOLE-Pfad mit einem tatsächlich
ausgeführten Child an Fehler 208. Die Exportquelle wurde ausschließlich
im späteren TABLE-Zweig erzeugt und fehlte beim Console-Renderer.
Die tatsächlichen Childs waren Plan Cache Health, Query Store Status
für die eigene Frameworkdatenbank und das XE-Sessioninventar mit einem
synthetischen nicht vorhandenen Unicode-Sessionfilter. Dieselben drei
TABLE-Aufrufe bestanden jeweils mit einer vollständigen Modulstatuszeile
und null abweichenden Textcollations. Die Tablevariablen erbten bereits
die Frameworkcollation; fremde TABLE-Textcollations waren somit kein
nachgewiesener Baselinefehler dieses Slice.

Die UTF-8/LF-Hashes der tatsächlich installierten Ausgangsquellen
betrugen für PlanCacheAnalysis
`C63F0F396D5380121BC94599F50A2646A9169F6936FA15C4F4ABC5728A2AC7C3`,
für QueryStoreAnalysis
`A4073958BEBE9940A8181DCCF4DEA6AFCAA6C682664498D33B890EEFF3485A8A`
und für ExtendedEventsAnalysis
`76241D806297C4F1D08DAB0C1ABE003F8D5FDFC5A3A7044A02F3035566A47116`.

### Korrigierte Exporte und native Prüfung

Die drei Sources erzeugen den fünfteiligen Modulstatusexport jetzt vor
Helpern und Childausgaben. Je Procedure sind drei Texte im Collector
und drei im Export explizit `SQL_Latin1_General_CP1_CS_AS` collatiert.
Die vollständige Modulstatusmenge wird nach der bisherigen
Statusbewertung eingefügt und gemeinsam von TABLE, CONSOLE, RAW und
den bestehenden JSON-Projektionen gelesen. Ursprüngliche Ordinale,
Childaufrufe, Statusregeln, Warnungen und öffentliche Schemas bleiben
erhalten. Nur Plan Cache besitzt das JSON-Array `modules`; Query Store
und Extended Events behalten ihre benannten Childobjekte.
`@MaxZeilen` begrenzt weiterhin die dafür vorgesehenen Children und
nicht die Modulstatusmenge. Die bestehenden SQL-Literalsequenzen
stimmen einschließlich Unicode exakt mit dem Ausgangsstand überein.

Die korrigierte Installation aus 166 kanonischen Dateien und Smoke110
bestanden. Common165 bestand auf derselben gemischten
Collation-Kombination bei Framework-Compatibility-Level 170:

- 24 TABLE-Fälle mit unabhängiger Prüfung aller fünf Felder,
  Datentypen, Textcollations, NULL-Fähigkeit und fehlender Identity;
- zwölf tatsächlich per SQL erfasste positive CONSOLE-Fälle mit sechs
  Feldern und neun erfasste leere CONSOLE-Fälle mit drei Feldern;
- drei direkte positive CONSOLE-Aufrufe mit geprüftem JSON-Vertrag;
- drei RAW-Leerscopeaufrufe mit `INVALID_PARAMETER` im JSON;
- zwölf Mapping-Preflights mit dem bestehenden Fehler 51011.

NULL-/0-/positive Limits, sichere negative Ablehnung, alle ausgeschalteten
Children sowie ungültiger Analysemodus, Zeitraum oder Quellenmodus
sind geprüft. Modulnamen, ursprüngliche Ordinale, Invocationstatus und
Fehlerwerte stimmen mit der unabhängigen Childauswahl überein.
Vollständige Modulstatusmengen bleiben auch bei Childlimit 1 erhalten.
Die Metafelder, Topkeys, Childidentitäten und Warningprojektionen
entsprechen den drei unterschiedlichen JSON-Verträgen. Query Store
liefert die native Identität der eigenen Frameworkdatenbank. Der
synthetische Plan-Hash ist unabhängig leer; die synthetische
Unicode-XE-Session ist unabhängig nicht vorhanden. Die
Snapshotwiederverwendung besitzt damit Status- und Metadatenevidenz,
aber keine positive Plan-XML-Evidenz.

Ein separater direkter `SqlClient`-Reader bestand sämtliche 24
CONSOLE-Aufrufe: 15 nichtleere Sechs-Felder-Ausgaben und neun leere
Drei-Felder-Ausgaben. Geprüft wurden tatsächliche Spaltennamen,
native Datentypen, Textlängen und jede Modulzeile einschließlich
Reihenfolge, Label, Invocationstatus und NULL-Fehlerwerten. Beim Plan
Cache stimmt zusätzlich jede Modulzeile mit `modules` überein; die
Query-Store-Replica-/IQP-Statusübernahme stimmt mit den jeweiligen
Childmetadaten überein. Der Reader beobachtete außerdem fünf zusätzliche
leere dreifeldrige Warning-Proberesultsets: zwei beim vollständigen
Plan-Cache-Aufruf, eines beim Plan-Cache-Paar und zwei beim
vollständigen Query-Store-Aufruf. Diese vorhandenen Helperresultsets
bleiben unverändert. Die drei betroffenen SQL-Testfälle werden direkt
ausgeführt; deren tatsächliche CONSOLE-Zeilenparität ist ausschließlich
durch den separaten Client nachgewiesen.

Der erste Common165-Versuch scheiterte an einer unzulässigen variablen
`SET LOCK_TIMEOUT`-Syntax im Test. Nach numerischem dynamischem Restore
scheiterte der zweite Versuch beim SQL-Resultset-Capture des vollständigen
Plan-Cache-Aufrufs mit Fehler 3930. Der stabile Test trennt daraufhin
die drei direkten Aufrufe von den SQL-Captures. Eine verschachtelte
`INSERT EXEC`-Ursache wurde nicht nachgewiesen. Der private Client wurde
vor seiner vollständigen Abnahme wegen Connection-Builder-Zugriff,
einer Singleton-Count-Annahme und ausgelassener optionaler
JSON-Fehlerproperties korrigiert. Diese Harnessfehler sind keine
Produktfehler; nur der abschließende vollständige Lauf gilt als PASS.
Eine vor dem nativen Lauf erkannte Zeichensatzbeschädigung wurde
gezielt zurückgenommen und der Installer anschließend neu erzeugt.

Die sechs weiteren fokussierten Tests bestanden auf CL170:
PlanCache110, QueryStore110, QueryStore121, ExtendedEvents110,
Integration189 und Integration196. Childqueries, Versionsgates und
Berechtigungslogik wurden nicht geändert; ein zusätzlicher
Compatibility-Level- oder nativer älterer Engine-Lauf war gemäß der
kanonischen Teststrategie für diesen Slice nicht erforderlich.

### Quellidentität, Grenzen und Cleanup

| Quelle | UTF-8/LF-SHA-256 | Installierter Body, UTF-16/LF-SHA-256 |
|---|---|---|
| PlanCacheAnalysis | `D17DD891CF99053A1D2C2D0D5E43928C92087FDA382B904947BC00CAF94EC539` | `4ECFF877DFAE0950BC5277D5AF2037809C54BDFC93DA4F3C62C508821D93ABAF` |
| QueryStoreAnalysis | `C58BF986F6C792E9A9D4FFA411D1C1006951C54C4C01691E017300D28649930D` | `B15BA6E386C8F8C2BF7B00FACCBEA8C6D22458BF39BE8D14F1518A8690F8C27D` |
| ExtendedEventsAnalysis | `63D571683ACBD2B34CDF5C531E67168F9EFE95349BDEEAAA74C8CA02A7FB027D` | `BE687059230A59D56FB715B6914C05C98E9C3B2A2EEEC942FE2E90DA2EB201A6` |

Alle drei nativen Bodyhashes stimmen nach LF-Normalisierung ab dem
qualifizierten Objektnamen und Entfernen äußerer Batchmarker mit den
kanonischen Bodies überein. Common165 besitzt die tatsächlich ausgeführte
UTF-8/LF-Identität
`A593EA5289F7BD8064DA05908CBA76F79D6F45BE448A6DD076F5276548248991`.
Der private direkte Client besitzt die UTF-8/LF-Identität
`3B140F71C799512F7AA6366E442A460591B52484CCF5DCCCF71E9CE0A5883D89`.
Der SQL-Test ersetzte nur den Installationsplatzhalter; der Client
verwendete dieselben kanonischen Aufrufformen ohne SQL-INSERT-Capture.

Positive fachliche Ereignisse, Plan-XML-Daten, `ERROR_HANDLED`- und
zusätzliche Berechtigungspfade sowie vollständige positive
RAW-Mehrfachresultset-Parität bleiben unbelegt. Childquellen sind keine
atomare gemeinsame Messung. Es wurden keine XE-Fixtures erzeugt und
kein Target-Flush ausgeführt. Der Slice liefert keine neuen Nachweise
für CL150/160 oder ältere native Engines. `COLL-001` bleibt partiell;
bestehende Maturityflags und `RUNTIME-001` bleiben unverändert.

Das eigene Lab wurde nach den erfolgreichen Prüfungen vollständig
entfernt: Container und Volume, zwei Cleanupschritte, null Fehler,
`CLEANUP_SUCCEEDED` und `REMOVED`. Der eigene verschlüsselte temporäre
Secretwert wurde danach entfernt. Private Laufzeitdaten und
Prüfzustände bleiben außerhalb von Git; andere Labs und die zuvor
gesperrten Cleanup-Pfade wurden nicht berührt.

`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Privacy prüfte 1.047
Repositorydateien ohne Findings, Schreibstil 705 und Regex 337.
Roadmap-, Maturity- und Partialitätsverträge, der NOWAIT-Metadatenvertrag
mit 953 Temp-Namen sowie beide Adapterprüfungen bestanden ebenfalls.
Nach diesem Ergebnis wurde ausschließlich dieser Gateabsatz ergänzt;
SQL, Tests und ihre Quellidentitäten blieben unverändert. Das unabhängige
abschließende Review hatte keine offenen Findings.

## Framework-Nutzung aus Query Store: 7. Oktober 2026

### Nativer Ausgangsstand

Die unveränderte Source `500_USP_FrameworkUsageFromQueryStore.sql` aus
`d07b8ce819c6474874825adff1fd8a6e8abbe6e3` wurde aus 166 kanonischen
Dateien in einem eigenen SQL-Server-2025-Docker-Lab installiert.
Installation und Smoke110 bestanden. ProductVersion `17.0.4075.5`,
Major 17, Linux und Framework-Compatibility-Level 170 wurden nativ
bestätigt. Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`,
das Framework `SQL_Latin1_General_CP1_CS_AS`.

Drei Charakterisierungsfälle bestanden ohne Harnessfehler. Ein gültiger
TABLE-Aufruf mit allen vier Resultsetzuordnungen und unbegrenztem Limit 0
lieferte `AVAILABLE` in JSON und OUTPUT, alle 39 öffentlichen Spalten
sowie 14 von der Frameworkcollation abweichende Textcollations.
Ein negatives Limit und ein NULL-Mindestwert lieferten jeweils
`INVALID_PARAMETER` in JSON und OUTPUT. Beide TABLE-Aufrufe ließen aber
alle vier Caller-Ziele mit jeweils einer Dummyspalte unverändert.
Die semantische Parameterablehnung übersprang die spätere TABLE-Zuordnung;
Status und Quellenkontext wurden deshalb nicht in diese gültig
zugeordneten Ziele projiziert.

Die UTF-8/LF-Identität der tatsächlich installierten Ausgangssource lautet
`9DE392932BD0AC099F58EC47D78CF45D111F059455A73F174478767039550DD8`.

### Änderung und positive native Gegenprobe

Die 15 bisher impliziten Textfelder in fünf lokalen Mengen verwenden jetzt
explizit `SQL_Latin1_General_CP1_CS_AS`. Der vorhandene TABLE-Preflight läuft
vor der fachlichen Parameterprüfung. Die vier öffentlichen Schemas behalten
12/11/11/5 Felder, zusammen 39 Felder mit 14 Textfeldern. Fachlich ungültige
Parameter projizieren damit `INVALID_PARAMETER` und Quellenkontext auch in
gültig zugeordnete TABLE-Ziele. Abgelehnte Zuordnungen bleiben beim bestehenden
Fehler 51011. Quellenabfragen, gewichtete Aggregate, Mindestfilter,
NULL-/0-Limits, zusätzlicher Kandidat für `HasMoreRows`, JSON und OUTPUT sowie
LOCK_TIMEOUT-Restore bleiben fachlich unverändert.

Für die Gegenprobe bereitete der Labbetreiber ausschließlich in der eigenen
temporären Labdatenbank zwei synthetische Unicode-Procedures vor, deren Namen sich in der
Großschreibung unterscheiden. Capture Mode ALL, 100 beziehungsweise 200
Ausführungen und ein eigener Flush erzeugten je eine Query und einen Plan.
Danach wurden tatsächlicher und gewünschter Query-Store-Zustand auf READ_ONLY
stabilisiert. Die nativen Statementsummen betrugen 100 und 200. Diese Zahlen
sind Fixturebeobachtungen; der Repositorytest leitet Schwellen und Identitäten
aus nativen Metadaten ab. Das Produkt und Common166 verändern weder Query Store
noch Probeobjekte und führen keinen Flush aus.

Die abschließende Installation aus 166 kanonischen Dateien und Smoke110
bestanden. Common166 bestand auf SQL Server 2025 nacheinander auf den
Framework-Compatibility-Levels 150, 160 und 170. Je Level liefen 19 TABLE-
und drei weitere Consumerfälle, vier frühe Mappingablehnungen sowie drei
leere CONSOLE-Captures. Alle TABLE-Schemas wurden vollständig nach relativer
Feldposition, Namen, Typen, Längen, Precision, Scale, NULL-Zulässigkeit,
Collation und öffentlichem Identitymerkmal geprüft. Alle 14 Textfelder besitzen
die Frameworkcollation. JSON prüft vier Top-Level-Schlüssel, alle 13 Metafelder
einschließlich NULL-Eigenschaften und vollständige Usage-, Source- und
Warningparität; Modulstatus und OUTPUT werden ebenfalls verglichen.

Die vorhandene READ_ONLY-Fixture aktivierte zusätzlich je Level acht
unabhängige native Gegenproben für sämtliche elf Usage-Felder, gewichtete
Mittelwerte, case-sensitive Identitäten, Mindestfilter, Limits und
`HasMoreRows`. Drei positive CONSOLE-Captures vergleichen jeweils zwölf Felder
mit JSON als ungeordnete Menge. Die Procedure garantiert keine CONSOLE-
Sortierung. Die Fensterfälle prüfen Parameterakzeptanz und native Parität;
mit diesen frischen Statistiken ist keine positive Ausschlusswirkung alter
Intervalle nachgewiesen. Ohne passende READ_ONLY-Fixture führt Common166 die
allgemeinen Fälle weiter aus und meldet ausschließlich den positiven Block
als `NOT_EXECUTED`. Diese Möglichkeit ersetzt die hier ausgeführten positiven
Gegenproben nicht.

READ_ONLY/READ_ONLY/ALL und die unveränderten nativen Probeaggregate wurden
nach den drei Läufen bestätigt. Die UTF-8/LF-Quellidentitäten lauten:

| Quelle | SHA-256 |
|---|---|
| Source500 | `26506A4CF8C108DC04F2A7AF12EA8CF193BD8CEC4C6CCEEBEBB130280BB09857` |
| Common166 | `1C64A181192899F096EF1118EC3CE912A672214548900316462A920475B51121` |
| QueryStore120 | `8878303F139A060DF5EA8B848D6C18C7AB9F6A6733747B49950A0BD3CB3E387B` |

Der native Body besitzt nach LF-Normalisierung ab dem qualifizierten
Objektnamen und Entfernen äußerer Leerzeichen und Zeilenumbrüche die
UTF-16/LF-Identität
`1899BCD9DFD2ED7B55AB148C402B7784DADAA5390D8E05E99443C2FDE71402B9`.
Sie stimmt mit dem kanonischen Body überein. Der erste private Hashvergleich
entfernte abschließende Zeilenumbrüche noch nicht und brach vor weiteren
Fixtureänderungen ab. Die korrigierte Normalisierung bestand. Die SQL-
Stringliteralmenge der Source bleibt gegenüber dem Ausgangsstand identisch.

QueryStore120 verwendet für seine eigene Probe jetzt eine Abwesenheitsprüfung,
CREATE und eine erfasste Objekt-ID als Cleanupvorbehalt in beiden Pfaden.
Ein eigener nativer Gegenversuch mit bereits vorhandener Probe erhielt die
geplante Ablehnung `FRAMEWORK_USAGE_PROBE_ALREADY_EXISTS`; Objekt-ID und
Bodyhash blieben unverändert. Der Labbetreiber entfernte danach diese eigene
Guard-Probe. Die 20 regulären Testausführungen und ihr Flush schreiben eigene
Laufzeitdaten, ändern aber keine Query-Store-Konfiguration und bereinigen
keine vorhandenen Daten.

Der erste Impactlauf auf CL150 bestand QueryStore120. Integration189 lehnte
danach die zwei noch vorhandenen Unicode-Fixtures ab, weil sie das feste
Inventar öffentlicher Framework-Procedures erweiterten. Dies war kein
bestandener Impactlauf. Nach Prüfung der eigenen Objekt-IDs wurden beide
Fixtures entfernt und der ursprüngliche Zustand READ_WRITE/READ_WRITE/AUTO
wiederhergestellt. Die Produkt- und Repositorytestquellen wurden dafür nicht
geändert.

Der bereinigte Impactlauf bestand danach auf CL150, CL160 und CL170 jeweils
QueryStore120, Integration189, Integration196, Integration198 und Common124.
Die reguläre Probe von QueryStore120 wurde in diesen READ_WRITE-Läufen vom
Test erzeugt, ausgeführt und entfernt. Abschließend waren alle drei eigenen
Probenamen abwesend; der ursprüngliche Query-Store-Zustand war weiterhin
READ_WRITE/READ_WRITE/AUTO.

Vollständige positive RAW-Zeilenparität, DENIED_PERMISSION und ERROR_HANDLED
bleiben unbelegt. Der Nachweis umfasst dieselbe Frameworkdatenbank und keine
zusätzliche Quelldatenbank oder ältere native Engine. `COLL-001` bleibt
partiell; bestehende Maturityflags und `RUNTIME-001` bleiben unverändert.
Das unabhängige Review von Produkt, Tests, Inventar, Installer und
Procedure-Dokumentation hatte keine offenen Findings.

Das eigene Lab wurde vollständig entfernt: Container und Volume, zwei
Cleanupschritte, null Fehler, `CLEANUP_SUCCEEDED` und `REMOVED`. Der eigene
verschlüsselte temporäre Secretwert wurde danach entfernt. Private
Laufzeitdaten und Prüfzustände bleiben außerhalb von Git; andere Labs und
die zuvor gesperrten Cleanup-Pfade wurden nicht berührt.

`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Privacy prüfte 1.048
Repositorydateien ohne Findings, Schreibstil 706 und Regex 338.
Roadmap-, Maturity- und Partialitätsverträge, der NOWAIT-Metadatenvertrag
mit 967 Temp-Namen sowie beide Adapterprüfungen bestanden ebenfalls.
Nach diesem Ergebnis wurden dieser Gateabsatz und die abschließende
redaktionelle Begriffskorrektur aus dem unabhängigen Review übernommen.
SQL, Tests und ihre Quellidentitäten blieben unverändert. Das abschließende
unabhängige Review hatte danach keine offenen Findings.

## Agent-Jobs: 7. Oktober 2026

### Nativer Ausgangsstand

Source020 aus `f6acea6d05a2105c52558ef5477f6768db6b31bf` wurde aus
166 kanonischen Dateien im eigenen SQL-Server-2025-Docker-Lab installiert.
Installation und Smoke110 bestanden. Nativ bestätigt wurden ProductVersion
`17.0.4075.5`, Major 17, Linux und Framework-Compatibility-Level 170.
Server, `tempdb` und `msdb` verwendeten `Latin1_General_100_CS_AS`,
das Framework `SQL_Latin1_General_CP1_CS_AS`. Der eigene Ausgangsscope
enthielt keine Jobs oder Jobhistory.

Zwei TABLE-Charakterisierungsfälle mit einem fehlenden synthetischen
Unicode-Jobnamen bestanden ohne Harnessfehler. Das unbegrenzte Limit 0
lieferte `AVAILABLE`; ein negatives Limit lieferte `INVALID_PARAMETER`.
Beide Aufrufe erzeugten das bestehende Schema mit 17 Feldern und sechs
von der Frameworkcollation abweichenden Textcollations. Die JSON-Arrays
für Jobs und Steps waren jeweils leer.

Ein gesonderter Aufruf mit demselben gültigen exakten Namen zweimal in
der Pipe-Liste erzeugte Fehler 2627 mit Primary-Key-Kontext; Caller-JSON
blieb NULL. Die gültigen Parserzeilen wurden vor dem TRY-Bereich ohne
Deduplikation in den vorhandenen case-sensitiven Filter-PK eingefügt.
Der Nachweis autorisiert keine allgemeine Änderung der bestehenden frühen
Kandidatenbegrenzung, Problemsortierung oder Step-Historyfilterung.

Die UTF-8/LF-Identität der tatsächlich installierten Ausgangssource lautet
`0EAB52920DC81C0BBCEFCE574550CC378BCE7BB9EC0BB032BFA3E621458852E8`.

Der Labbetreiber bereitete danach ausschließlich eigene synthetische
Jobdefinitionen vor: zwei Unicode-Namen mit unterschiedlicher Großschreibung,
ein deaktivierter Job mit zwei Steps und ein aktivierter Job mit drei Steps.
Beide verwenden eine eigene Kategorie und denselben aktivierten einmaligen
Zukunftsschedule. Native GUIDs, Schedule-ID und Schedule-UID bleiben privat.
Für beide Jobs wurden keine Aktivitäts-, History- oder Jobserver-Zeilen
angelegt. Kein Job wurde gestartet; Stepkommandos wurden nicht ausgeführt.

### Begrenzter Endnachweis

Die Änderung collatiert elf lokale Textfelder explizit: sechs im Jobs- und
fünf im Steps-Resultset. Der registrierte TABLE-Export bleibt ausschließlich
`jobs` mit 17 Feldern. Seine drei sysname-Felder JobName, OwnerName und
CategoryName bleiben NOT NULL; die übrigen 14 Felder bleiben nullable und
alle Felder ohne Identity. Gültige doppelte exakte Namen werden unter der
Frameworkcollation zusammengeführt; der erste Listenordinal bleibt erhalten.
Ungültige Listenelemente und unterschiedliche Großschreibung behalten ihren
bisherigen Vertrag. Die frühe native Jobsauswahl, das spätere Problemranking,
die getrennte Stepsbegrenzung und die Historyfilterung bleiben unverändert.

Installation aus 166 kanonischen Dateien und Smoke110 bestanden mit der
geänderten Source. Der erste Common167-Lauf war bei
`AGENT_JOBS_EXISTING_LOCK_TIMEOUT` fehlgeschlagen: Der Test erwartete
fälschlich einen sichtbaren Callerwert 0. Eine separate native Probe mit
Callerwert 731 und erfolgreichem NONE-/JSON-Aufruf bestätigte den Wert 731
nach Return. Ausschließlich zwei Testassertions und ihr Kommentar wurden
korrigiert; das interne `SET LOCK_TIMEOUT 0` der Procedure blieb unverändert.

Common167 bestand danach auf Framework- und separat bestätigtem
msdb-Compatibility-Level 170. Die native Ergebniszeile meldete elf allgemeine
TABLE-/JSON-Fälle, zwei Verbraucherfälle, sechs Mappingablehnungen,
`PositiveFixtureStatus=PASS`, 13 positive native Gegenproben, drei positive
und drei leere SQL-CONSOLE-Captures. Die zusätzlichen Ausgaben zur Erfassung
der Ergebniszeile bestätigten dieselben Werte. Ohne beide vorbereiteten
Jobs führt der Test seine allgemeinen Fälle aus und kennzeichnet den
positiven Block als `NOT_EXECUTED`; er erzeugt oder verändert keine Fixture.

Die positiven Gegenproben vergleichen alle 17 Jobs- und zehn Stepsfelder
inklusive NULLs mit nativen msdb-Daten. Die frühe Kandidatenordnung wird
direkt aus der nativen Jobnamenordnung gewonnen; die endgültige
JSON-Reihenfolge folgt der Frameworkcollation. Die positiven Fixturefälle
belegen exakte Case-Auswahl, LIKE-Auswahl, gleiche und anders
bracket-quotierte Duplikate, NULL-/0-/positive Limits und Problemscope.
Die allgemeinen Fälle prüfen außerdem Duplikate zusammen mit einem
ungültigen Listenelement. Der deaktivierte Job bleibt ohne History
problematisch, besitzt zwei definierte Steps und liefert im Problemscope
keine Steps. Die Prüfung verspricht keine globale Problempriorisierung vor
der frühen TOP-Auswahl und keine neue CONSOLE-Sortgarantie.

Ein unabhängiger direkter SqlClient-Capture bestand zehn RAW-Aufrufe mit
allen drei Resultsets: Modulstatus mit sechs, Jobs mit 17 und Steps mit zehn
Feldern. Feldnamen, Reihenfolge, Typen und Textgrößen sowie die unveränderte
Jobs-/Steps-Nullability wurden geprüft. Alle Jobs- und Stepszeilen wurden
mit JSON einschließlich NULL-Properties vollständig verglichen; Modulname,
Timestamp, Status-, Partialitäts- und Fehlerwerte sowie Mengenzähler stimmten
überein. Acht Aufrufe enthielten Jobs, sieben enthielten Steps und zwei
lieferten leere Fachmengen. Die vollständigen Captures bleiben privat.

Die geprüften UTF-8/LF-SHA256-Identitäten lauten:

| Artefakt | SHA256 |
| --- | --- |
| Source020 | `BA4F6B9D96DF20FB82DD95FF420BF2EE8BA0B8B3DE88A3CA17B91D00757768F1` |
| Common167 | `508B34F40411201ED6A9F41FDC0723A282E20B7C9287AEC95C2E8BE047A69BCA` |
| Privater direkter RAW-Client | `EE490D9028B6E71EDFFBFC3FF107E5AE7994BFC6783AF00CFB9CD9773CC20E2B` |

Zwei erste private Bodyhashprüfungen verglichen fälschlich die gespeicherten
Installerkommentare beziehungsweise die vom Server normalisierte
CREATE-Deklaration mit dem kanonischen CREATE-OR-ALTER-Text und scheiterten.
Nach expliziter Abgrenzung von `PROCEDURE [monitor].[USP_AgentJobs]` bis zum
letzten END, LF-Normalisierung und Entfernen äußerer Leerzeichen stimmten
native und kanonische UTF-16/LF-Identität überein:
`D30F72C69572AE1E9104ABF52BD5E2134D39B62672E8741D90E068B765241092`.
Dies erforderte keine Produkt-, Installer- oder Repositoryteständerung.

Nach den positiven Läufen wurden die erfassten eigenen Job-GUIDs,
Schedule-ID/UID und Kategorieidentität erneut geprüft. History-, Aktivitäts-
und Jobserver-Zeilen waren weiter abwesend; die Stepanzahlen betrugen zwei
und drei. Die beiden Jobs wurden ohne Historylöschung oder automatische
Schedulelöschung entfernt; danach wurden der eigene nicht mehr angehängte
Schedule und die eigene Kategorie entfernt. Die abschließende native
Prüfung bestätigte die Abwesenheit aller eigenen Identitäten und null Jobs.
Kein Job, Stepkommando oder Agentdienst wurde gestartet.

Laufende Jobs, positive History-/Outcome-/Meldungsfelder, Regex,
`DENIED_PERMISSION` und `ERROR_HANDLED` bleiben unbelegt. Der Nachweis
umfasst SQL Server 2025 mit CL170 und keine neuen nativen älteren Engines
oder CL150/160. `COLL-001` bleibt partiell; bestehende Maturityflags und
`RUNTIME-001` bleiben unverändert. Das unabhängige Review des stabilen
Produkt-, Test-, Inventar-, Installer- und Procedure-Dokumentationsstands
hatte einschließlich der korrigierten Callerassertions keine offenen
Findings.
Nach dem eigenen Fixture-Cleanup bestanden Infrastructure110,
Integration189, Integration196, Integration198 und Common124 gemeinsam
auf CL170. Der bestehende Infrastructure110-Test prüft die Hilfe- und
Signaturpfade; die positive AgentJobs-Evidenz stammt aus Common167 und
dem getrennten RAW-Client. Die drei positiven SQL-CONSOLE-Captures prüfen
das bestehende 18-Feld-Schema einschließlich Ergebnisbezeichnung und volle
Zeilenparität; die drei leeren Captures prüfen das dreifeldrige Hinweisschema.

Das eigene Lab wurde vollständig entfernt: Container und Volume, zwei
Cleanupschritte, null Fehler, `CLEANUP_SUCCEEDED` und `REMOVED`. Der eigene
verschlüsselte temporäre Secretwert wurde danach entfernt. Private
Laufzeitdaten und Prüfzustände bleiben außerhalb von Git; andere Labs und
die zuvor gesperrten Cleanup-Pfade wurden nicht berührt.
`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Privacy prüfte 1.049
Repositorydateien ohne Findings, Schreibstil 707 und Regex 339.
Roadmap-, Maturity- und Partialitätsverträge, der NOWAIT-Metadatenvertrag
mit 980 Temp-Namen sowie beide Adapterprüfungen bestanden ebenfalls.
Nach diesem Ergebnis wurde ausschließlich dieser Gateabsatz ergänzt;
SQL, Tests, Statusnotizen und ihre Quellidentitäten blieben unverändert.
Das abschließende unabhängige Evidenz- und Statusreview hatte nach der
Präzisierung des allgemeinen Invalidfalls keine offenen Findings.
## Framework-Capabilities: 7. Oktober 2026

### Nativer Ausgangsstand

Source070 aus `db943ade38f48c6c2b5e5921f8b0b8011eda3e1d` wurde aus
166 kanonischen Dateien im eigenen SQL-Server-2025-Docker-Lab installiert.
Installation und Smoke110 bestanden. Nativ bestätigt wurden ProductVersion
`17.0.4075.5`, Major 17, Linux und Framework-Compatibility-Level 170.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das Framework
`SQL_Latin1_General_CP1_CS_AS`. Die UTF-8/LF-Identität der installierten
Ausgangssource lautet
`1ECD84A79C985C75D7B6ECF8B0E0C5765CAC38F972EBC9B11C88102395A90636`.

Der erste private Fixtureaufbau scheiterte bei der zweiten Datenbank mit
5170/1802: automatisch erzeugte Dateinamen kollidierten bei zwei nur in der
Großschreibung unterschiedlichen Datenbanknamen. Dieser Lauf zählt nicht
als bestandener Ausgangsnachweis. Nach Prüfung der eigenen ersten
Datenbankidentität wurde ausschließlich die fehlende eigene zweite
Datenbank mit eindeutigen logischen und physischen Dateinamen angelegt.
Keine vorhandene Datei oder fremde Datenbank wurde entfernt oder ersetzt.

Die wiederholte Ausgangsmessung bestand mit zwei eigenen case-unterschiedlichen
Unicode-Datenbanken einschließlich Apostroph im Namen. Beide verwendeten
`Latin1_General_100_CI_AS` und separat bestätigtes CL170. Die erste hatte
Query Store im tatsächlichen Zustand 2, die zweite im Zustand 0; beide
meldeten `wait_stats_capture_mode=1`. Die fünf QUERY_STORE_CURRENT-Features
je Quelle erzeugten zehn vollständige Capabilities, sieben davon nutzbar.
Der Filter 0 lieferte zehn Zeilen in JSON und TABLE; Filter 1 lieferte drei
JSON-Zeilen, jedoch weiterhin zehn TABLE-Zeilen. Beide Aufrufe behielten
`AVAILABLE_LIMITED` und zwei vollständige Summaryzeilen. Die 27 TABLE-Felder
und ihre 15 Textcollations waren bereits korrekt; ein fehlerhafter öffentlicher
Collation-Ausgangsstand wird nicht behauptet.

Ein direkter privater SqlClient erfasste zusätzlich neun RAW- und neun
CONSOLE-Aufrufe: beide Quellen, exakte Case-Einzelauswahl, Filter 0/1/NULL,
invaliden Analyseklassennamen und fehlende Quelle. RAW und JSON stimmten in
allen 27 Capabilityfeldern einschließlich NULLs sowie Summary und Warnings
überein. Die bestehenden Metadatenprobes wurden separat als leere Grids
erfasst: elf für beide Quellen, sechs für eine Quelle, null bei invalider
Analyseklasse und eines bei fehlender Quelle. Vier gefilterte CONSOLE-Fälle
enthielten gegenüber JSON noch die volle Fachmenge. Der private Client
benötigte zunächst eine Korrektur seiner Dictionary-Sortierung; die danach
bestandenen Inhaltsvergleiche erzeugen keine neue CONSOLE-Ordnungszusage.
Vollständige unmaskierte Captures und native Fixtureidentitäten bleiben privat.

### Begrenzter Endnachweis

Vierzehn bislang implizite Textfelder der internen Feature-Tabellenvariablen
verwenden nun explizit die Frameworkcollation. Eine typgleiche vollständige
Sammlung bleibt getrennt vom bestehenden registrierten Exportnamen.
Beide 27-Feld-Arbeitstabellen mit 15 Textspalten werden vor den Probes und
dem eigenen `SET LOCK_TIMEOUT 0` angelegt. Nach vollständiger Bewertung wird
das bestehende Prädikat `@NurNichtVerfuegbar=0 OR IsUsable=0` genau einmal
materialisiert. RAW, JSON, TABLE und CONSOLE verwenden diesen Export;
Summary, Gesamtstatus und Meldungsentscheidung verwenden die Vollsammlung.
Ein NULL-Filter erhält deshalb seine bisherige Unavailable-only-Semantik.
Öffentliche Feldreihenfolge, Typen, Textgrößen, Nullability und fehlende
Identity bleiben erhalten. Das Inventar dokumentiert die 15 schon zuvor
korrekten öffentlichen Textcollations. Permission-, Versions-, Probe- und
Warninglogik, Procedureversion und Parameter bleiben unverändert.

Installation aus 166 kanonischen Dateien und Smoke110 bestanden mit der
geänderten Source. Common168 bestand auf SQL Server 2025 bei separat
bestätigtem Framework- und beiden Quelllevels 170. Die native Ergebniszeile
meldete elf allgemeine TABLE-/JSON-Fälle, zwei Consumerfälle, sechs
Preflightablehnungen, `PositiveFixtureStatus=PASS`, elf positive native
TABLE-/JSON-Gegenproben, drei leere SQL-CONSOLE-Captures und drei direkte
CONSOLE-Aufrufe. Eine getrennte private Erfassung der Ergebniszeile
bestätigte diese Werte. Der Test erzeugt oder verändert keine Fixture;
ohne beide vorbereiteten Quellen bleibt der positive Block `NOT_EXECUTED`.

Die positiven Gegenproben vergleichen alle 27 Capabilityfelder mit fünf
unabhängig bezeichneten Featurecodes und ihren nativen Options-, Permission-
und erfolgreichen Katalogprobes je Quelle. Die Hints-Capability behält
`IsFeatureEnabled=NULL`; WaitCapture wird separat vom Query-Store-Zustand
bewertet. Identitäten, Quelllevels und Optionen werden vor jedem nativen
Fall erneut geprüft. Exakte Case- und LIKE-Auswahl, umgekehrte Listenreihenfolge,
Filter 0/1/NULL, vollzählige Summary und erhaltene Auswahlwarnings bestehen.
Doppelte exakte Datenbanknamen bleiben im bestehenden Kandidatenvertrag
ungültig. Der Test charakterisiert weiterhin den unveränderten Overallstatus
`AVAILABLE` einer ausschließlich fehlenden Quelle; deren Warning bleibt
separat. Die direkten SQL-CONSOLE-Aufrufe prüfen den JSON-Consumer, nicht
die fachlichen Zeilen eines positiven SQL-Captures.

Der unabhängige private Client bestand neun RAW- und neun CONSOLE-Aufrufe.
RAW bestätigt die vier öffentlichen Schemas mit 6/27/4/3 Feldern für
Modulstatus, Capabilities, Summary und Warnings. Alle 27 Fachfelder wurden
auf native Namen, Reihenfolge, Typen, Textgrößen und Nullability sowie
vollständig einschließlich NULLs gegen JSON geprüft. Status, Module- und
JSON-Identität, Zeitstempel und Partialität stimmen überein. Sechs
CONSOLE-Aufrufe lieferten die positive 28-Feld-Fachansicht und drei das
leere dreifeldrige Hinweisschema. Positive CONSOLE-Inhalte wurden nach
case-sensitiver Sortierung der Vergleichsmengen geprüft; eine neue
Ausgabeordnung wird nicht zugesagt. Die zuvor beobachteten Probegrids
blieben separat leer und mengenmäßig unverändert. JSON-Fachinhalte,
Summary, Warnings und Gesamtstatus entsprechen in allen neun Fällen dem
Ausgangsstand; die vier CONSOLE-Filterabweichungen sind behoben.

Die geprüften UTF-8/LF-SHA256-Identitäten lauten:

| Artefakt | SHA256 |
| --- | --- |
| Source070 | `114090513C5FF9E702C513FB9DE2FE09A38F9700760C394A6F303DEA30599F26` |
| Common168 | `4E48DE33000EB6ECB69C8C6D9AF6755030AF2E7192DBBBC765ECEED1E056F42F` |
| Privater direkter RAW-/CONSOLE-Client | `ABC372A7D5DE9BBFE10F17425764447323855C7C2AB7DCC95F86234D351D7464` |

Die native und kanonische Procedure stimmen von der PROCEDURE-Deklaration
bis zum letzten END nach LF-Normalisierung und Entfernen äußerer
Leerzeichen überein. Ihre UTF-16/LF-Identität lautet
`CCDAB79AB7754D98CA81DEA87A31BF8D2E9CE58CD335B24CBEAD02722E66BF99`.

Nach Prüfung der erfassten eigenen Datenbankidentitäten, unveränderten
Query-Store-Zustände und abwesender eigener Benutzertabellen wurden beide
Fixture-Datenbanken entfernt. Die abschließende native Prüfung bestätigte
ihre Abwesenheit. Danach bestanden Common121 und Integration189, 196 und
198 gemeinsam auf Framework-CL170. Das eigene Lab wurde vollständig
entfernt: Container und Volume, zwei Cleanupschritte, null Fehler,
`CLEANUP_SUCCEEDED` und `REMOVED`. Der eigene verschlüsselte temporäre
Secretwert wurde entfernt; private Captures und Prüfdaten bleiben außerhalb
von Git. Andere Labs und zuvor gesperrte Cleanup-Pfade wurden nicht berührt.

Der Nachweis umfasst keine positive eingeschränkte Berechtigungs- oder
Gruppenpolicy, keine `ERROR_HANDLED`-Probe und keine neuen nativen älteren
Engines oder CL150/160. Query-Store-Nutzungsdaten oder Hintausführung
wurden nicht erzeugt; geprüft wurden die vorhandenen Metadatenprobes.
`COLL-001` bleibt partiell und `RUNTIME-001` unverändert. Das unabhängige
Review des stabilen Produkt-, Test-, Inventar-, Installer- und
Dokumentationsstands hatte keine offenen Findings.

`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Privacy prüfte 1.050
Repositorydateien ohne Findings, Schreibstil 708 und Regex 340.
Roadmap-, Maturity- und Partialitätsverträge, der NOWAIT-Metadatenvertrag
mit 988 Temp-Namen sowie beide Adapterprüfungen bestanden ebenfalls.
Nach diesem Ergebnis wurde ausschließlich dieser Gateabsatz ergänzt;
SQL, Tests, Statusnotizen und Quellidentitäten blieben unverändert.
Das abschließende unabhängige Evidenz- und Statusreview hatte nach einer
Präzisierung der Filter-0-Beschreibung in beiden CSV-Notizen keine offenen
Findings.

## Parser-Textgrenzen: 7. Oktober 2026

### Nativer Ausgangsstand

Der begrenzte Slice umfasst `TVF_ParseBlockingResource`,
`TVF_ParseStatisticsIoText` und `TVF_ParseStatisticsTimeText`. Auf dem
Ausgangsstand waren 17 Textspalten implizit collatiert: sechs Rückgabetexte
und ein Parts-Text im Blockingparser, vier Rückgabetexte und zwei Labeltexte
im IO-Parser sowie vier Rückgabetexte im TIME-Parser. Die nativen
Rückgabeschemas enthielten bereits 12/18/8 Felder und insgesamt 14 Texte
mit der garantierten Frameworkcollation durch Datenbankvererbung; die
Baseline hatte keine abweichende Rückgabecollation.

Das ausschließlich eigene Docker-Lab verwendete SQL Server 2025
`17.0.4075.5` unter Linux mit vier GB Speicher. Server und `tempdb`
verwendeten `Latin1_General_100_CS_AS`, die Frameworkdatenbank
`SQL_Latin1_General_CP1_CS_AS` und Compatibility Level 170. Die kanonische
Vollinstallation bestand mit 166 Quelldateien und 187 Batches; der Smoke-Test
bestand ebenfalls. Die Erstaufnahme der nativen Metadaten bestätigte alle
38 Felder und 14 Textcollations. Die formatierte Lababfrage kürzte lange
JSON-Werte auf 256 Zeichen; diese Ausgabe wurde deshalb nicht als
vollständiger Zeilennachweis verwendet.

Ein unabhängiger privater SqlClient erfasste anschließend 45 Aufrufe:
23 Blocking-, elf IO- und elf TIME-Fälle. Er verglich alle 42 Rückgabezeilen
(23/10/9) feldweise einschließlich NULLs mit JSON und prüfte sechs leere
IO-/TIME-Ergebnisse. Die Eingaben umfassen englische und deutsche Texte,
Unicode einschließlich ergänzender Zeichen, Groß-/Kleinschreibung,
mehrzeilige Texte, unerkannte Eingaben und numerische Überläufe. Die erste
Clientaufnahme endete beim SQL-NULL des JSON-Subselects einer leeren
IO-Rückgabe. Nach Korrektur dieses privaten NULL- und PowerShell-Arrayhandlings
bestand die gesamte Baseline; die Parserquellen wurden dafür nicht verändert.

### Begrenzte Änderung und Endnachweis

Die drei Quellen ergänzen ausschließlich 17 explizite
`COLLATE SQL_Latin1_General_CP1_CS_AS`-Klauseln. Parsinglogik, Eingaben,
Datentypen, Feldreihenfolge, Nullability, Statuswerte, Version und Stand
bleiben unverändert. OPS-005 und EXECUTION-PLAN-001 wurden kanonisch
synchronisiert. Der Planadapter enthält weiterhin nur IO und TIME,
keinen Blockingparser. Drei bestehende Einträge der Objektreferenz
beschreiben die expliziten Textcollations.

Nach Installation der drei geänderten TVFs bestand der Smoke-Test erneut.
Der private Client bestand dieselben 45 Aufrufe, alle 42 vollständigen
Zeilen und sechs leeren Ergebnisse. Namen, Reihenfolge, native Typen,
Textgrößen und Nullability der 12/18/8-Felder-Schemas sowie sämtliche Werte
stimmen mit der Baseline und JSON überein. Dieser Vergleich begründet
keine neue Ausgabeordnung.

Common169 bestand auf Framework-CL170 mit 53 synthetischen Aufrufen:
31 Blocking-, elf IO- und elf TIME-Fälle. Der unabhängige Metadatensollvertrag
prüft alle 38 Rückgabefelder und 14 Textcollations einschließlich
Ordinals, Typkennungen, Längen, Precision, Scale, Nullability und fehlender
Identity. Manuell festgelegte Literalzeilen vergleichen sämtliche Felder
und NULLs, Textbytes sowie Fallhäufigkeiten: 51 Zeilen mit 31/11/9 Zeilen
und sechs leeren IO-/TIME-Fällen. Die Prüfung enthält CR, LF und CRLF,
EN/DE, partielle und unbekannte Formate und die vorhandene
Nicht-Erzwingung des Spracharguments. Der private direkte Capture erfasste
das PASS-Resultset ohne formatierte Kürzung in zwei Batches.

CurrentState110 und 133 sowie PlanCache120 und 128 bestanden gemeinsam
auf CL170 in 15 Batches. Diese bestehenden Aufruferverträge prüfen unter
anderem syntaktische Blockingfälle, positive strukturierte IO-/TIME-Felder
und die vorhandene Datenschutzgrenze des Evidenzerzeugers.
Integration192 bestand mit 22 kanonischen Quellen und deterministischer
zweimaliger Generierung. Eine private Kopie ergänzte ausschließlich die
Prüfung des aufgelösten temporären Cleanup-Zielpfads.
Integration193 bestand in einer eigenen neuen Datenbank mit deaktiviertem
Query Store und CL170 in 74 Batches. SQLCMD-Includes wurden aus den
kanonischen Quellen expandiert; Erstinstallation, öffentliche APIs,
berechtigungsarmer Benutzer, erneute Installation, Erhaltung synthetischer
lokaler Konfiguration und begrenzter Installationsscope bestanden.

Die geprüften UTF-8/LF-SHA256-Identitäten lauten:

| Artefakt | SHA256 |
| --- | --- |
| Blockingparser | `89E4F320914D908AC5B3AB6DE564F932FA16B401376942188D9ED10B3428912C` |
| IO-Parser | `8F652B19412532FD49E55B2B72FBBF6AC7F8F4AFE5C923E8D5D65C04EA32B123` |
| TIME-Parser | `68BFF40BE6F4380CBA780FD1CC6C53C841E071D5012C09C433AA9D6063177C24` |
| Common169 | `459146081CEEDB9FBEC0FB694A834269BD0C02B274852D3FE1C3AE7B60E2710C` |
| Privater direkter Baseline-/JSON-Client | `A87AAD3EB8BEF86DECE8D2AFBB34718A13810B476C35D54472EB362806622981` |
| Privater Runtime-Capture | `F69B928B8DD9AB34CAFB820DA61B55E71B718329A863A330D37FB751A60C0E2B` |

Die nativen und kanonischen Funktionsdefinitionen stimmen von der
FUNCTION-Deklaration bis zum letzten END nach LF-Normalisierung und
Entfernen äußerer Leerzeichen überein. Ihre UTF-16/LF-Identitäten lauten:

| Funktion | SHA256 |
| --- | --- |
| Blockingparser | `CCE63E9287770408AB9DA1A5752CBADE9635BA458F907055537548DF336362B3` |
| IO-Parser | `2B13DF4FFF576021A4AF1B81D7CD96897A1AA706095A4C6781E7366F35C04645` |
| TIME-Parser | `6B91FE0BDA84639978F508E8DDA3095DD6F8EDF4FEF0144D661CDD3183374577` |

Das eigene Lab wurde nach den Prüfungen vollständig entfernt: Container
und Volume, zwei Cleanupschritte, null Fehler, `CLEANUP_SUCCEEDED` und
`REMOVED`. Der eigene verschlüsselte temporäre Secretwert wurde entfernt.
Private Captures und Prüfdaten bleiben außerhalb von Git; andere Labs und
zuvor gesperrte Cleanup-Pfade wurden nicht berührt.

Die Parserbelege verwenden ausschließlich synthetische Eingaben. Sie
belegen keine echte Blockingtopologie oder native STATISTICS-Erfassung.
Zusätzliche native ältere Engines und CL150/160 wurden mangels konkreten
Versionsrisikos nicht ausgeführt. `COLL-001` bleibt partiell;
`RUNTIME-001` und bestehende Maturityflags bleiben unverändert. Das
unabhängige Produkt-, Test-, Installer- und Dokumentationsreview hatte
keine offenen Findings.

`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand einmalig alle 75 Prüfungen mit Exitcode 0. Privacy prüfte 1.051
Repositorydateien ohne Findings, Schreibstil 709 und Regex 341.
Roadmap-, Maturity- und Partialitätsverträge, der NOWAIT-Metadatenvertrag
mit 988 Temp-Namen sowie beide Adapterprüfungen bestanden ebenfalls.
Nach diesem Ergebnis wurde ausschließlich dieser Gateabsatz ergänzt;
SQL, Tests, Statusnotizen und Quellidentitäten blieben unverändert.
Das abschließende unabhängige Evidenz- und Statusreview hatte keine offenen
Findings.

## Gemeinsamer StatisticsDistribution-Export am 7. Oktober 2026

Der Slice korrigiert die bestehende Begrenzung von
`USP_StatisticsDistributionAnalysis`. Die sechs ursprünglichen lokalen
Tabellen besitzen bereits 36 explizite Textcollations. Der öffentliche
TABLE-Vertrag hat 14 Felder und elf Texte; seine native Collation und
fehlende Identity waren schon vor der Änderung korrekt. Die neue frühe
Exporttabelle besitzt dieselbe Form und elf explizite Frameworkcollations.
Die vollständige Sammlung bleibt für Status und Zähler erhalten; erst
danach entsteht die gemeinsame Findingsauswahl für TABLE, CONSOLE, RAW
und JSON. Histogrammzugriff, Kandidatenauswahl, Schwellen und
Datenbankstatus bleiben unverändert.

Ein eigenes SQL-Server-2025-Lab verwendete Version 17.0.4075.5 auf Linux,
abweichende Server-/tempdb-Collation `Latin1_General_100_CS_AS`, die
garantierte Frameworkcollation `SQL_Latin1_General_CP1_CS_AS` und
Framework-CL170. Eine neue eigene synthetische Quelldatenbank verwendete
`Latin1_General_100_CI_AS` und separat gemessenes CL170. Zwei Unicodeobjekte
enthielten je 110 synthetische Zeilen in einer int-Spalte: hundert gleiche
Werte und zehn weitere Werte. Zwei explizite FULLSCAN-Statistiken mit
case-unterschiedlichen Unicode-/Apostrophnamen blieben nach der Erstellung
unverändert. Die Gegenprobe las native Statistikproperties und ausschließlich
numerische Histogrammfelder; Histogrammgrenzwerte wurden nicht erfasst.
Die kanonische Installation mit 166 Quellen bestand in 187 Batches;
der Smoke-Test bestand ebenfalls.

Die Baseline lieferte acht Findings und zwei Verteilungen. Bei
`@MaxZeilen=0/1/2` schrieb TABLE immer acht Zeilen, JSON dagegen acht,
eine und zwei. CONSOLE lieferte bei Limit 1 ebenfalls acht Findings.
Negative Limits warfen in NONE mit JSON, RAW ohne JSON und TABLE mit
JSON jeweils SQL-Fehler 127; der äußere Statusoutput blieb NULL.
Zwei private positive Captureversuche scheiterten an wiederverwendeten
TABLE-Zielen: Ein geleertes vollständiges Ziel erfüllt den Seedvertrag
nicht. Neue eigene Seedziele ermöglichten den vollständigen Capture.
Diese Harnessfehler sind keine zusätzlichen Produktfehler.

Nach Installation der geänderten Procedure bestand Smoke erneut.
TABLE und JSON lieferten bei 0/1/2 exakt acht/eine/zwei Findings;
`AVAILABLE_WITH_FINDING`, `IsPartial=0` und die vollständigen Zähler
acht/zwei blieben erhalten. Alle drei negativen Ausgabewege lieferten
`INVALID_PARAMETER` ohne SQL-Ausnahme.

Ein unabhängiger SqlClient erfasste acht direkte Aufrufe: RAW und
CONSOLE jeweils mit NULL/0/1/2. Insgesamt 42 Grids enthalten native
Feldnamen, Typen, Größen, Precision, Scale, Nullability und vollständige
Zeilen sowie ungekürzte JSON-Payloads mit NULL-Werten. Vier RAW-Aufrufe
bestätigen die fünf Schemas mit 9/9/32/13/14 Feldern und vollständige
JSON-Parität der vier Facharrays. Vier positive CONSOLE-Aufrufe bestätigen
15 Felder und acht/acht/eine/zwei Findings einschließlich JSON-Parität.
Separate leere sechs-feldrige Filterprobe-Grids wurden erhalten.
Alle Fachwerte stimmen mit der Baseline überein; Erhebungszeitpunkte
wurden beim Baselinevergleich ausgenommen. Bei `FindingOrdinal` ändert
sich das native RAW-/positive-CONSOLE-Merkmal `IsIdentity` ausdrücklich
von True auf False. Der Client prüft genau diese Ausnahme; ursprüngliche
Ordinalwerte und alle übrigen Metadaten bleiben erhalten. TABLE war
bereits ohne Identity. Beide Produktdokumente nennen die Anpassung.

Integration175 bestand alle acht synthetischen Statistikfälle einschließlich
gefilterter und inkrementeller Statistiken, Kandidatenbegrenzung und
Gruppensperre. Eine vorgeschaltete Guardprüfung bestätigte, dass alle
benannten Fixtureobjekte und Principals im eigenen Lab vorher fehlten.
Danach wurden ihre vollständige Entfernung und die unveränderte Definition
der transaktional angepassten Access-Policy nativ geprüft.
Zwei direkte ObjectAnalysis-Aufrufe mit ausschließlich aktiviertem
StatisticsDistribution-Child bestanden bei 0/1: volle zwei Verteilungen,
Ausgabe zwei/eine, Child- und Parentstatus AVAILABLE. Die bestehende
Mindestzeilenzahl lässt ihre Findings leer. ObjectIndex110 und
Integration178/196 bestanden gemeinsam in sieben Batches auf CL170;
Integration178 setzte seinen eigenen Restricted-User und das temporäre
CL120 vollständig zurück.

Der neue Common-Test wurde vor seinem gültigen Lauf korrigiert:
Ein falscher Parametername wurde beim Lesen entdeckt, ein unquotierter
SQL-Bezeichner und eine erfundene gemischte Auswahlwarning scheiterten
im nativen Lauf. Isolierte Gegenproben bestätigen: Ein ausschließlich
fehlender Datenbankname liefert DATABASE_UNAVAILABLE; eine gemischte
Auswahl enthält nur den Status der vorhandenen Datenbank. Der positive
gemischte Scope liefert AVAILABLE_WITH_FINDING mit IsPartial=0.
Diese bestehende Einschränkung bleibt erhalten und wird nicht als
positive Warningisolation dargestellt.

Common170 bestand auf dem gemischten Lab mit separat gemessenem
Framework- und Source-CL170: elf allgemeine TABLE-Fälle, zehn bedingte
native TABLE-Fälle, zwei negative NONE-/RAW-Consumer, fünf Preflightfälle,
drei leere dreifeldrige SQL-CONSOLE-Captures und drei direkte positive
CONSOLE-Statusaufrufe. Alle 32 Distributionfelder werden gegen native
Properties, Katalogflags, numerische Histogrammaggregate und unabhängig
bestimmte Rankings geprüft. Vollständige Findingtexte, Metriken, NULLs,
ursprüngliche Ordinale und die 14-feldrige TABLE-/JSON-Parität gehören
zum Vertrag. Die Fixture erzeugt nur MEDIUM-Findings; sie beweist keine
zusätzliche HIGH-/LOW-Sortierung.

Nach identitätsgeprüftem Entfernen der eigenen Quelldatenbank bestand
Common170 erneut ohne Fixture: elf allgemeine Fälle, zwei negative
Consumer, fünf Preflightfälle und drei leere CONSOLE-Captures. Der
positive Block meldete ausdrücklich NOT_EXECUTED und null native Fälle.
OPS-005 ist mit den kanonischen Quellen synchronisiert. PLAN-001 enthält
keine StatisticsDistribution-Abhängigkeit und blieb unverändert.
Die native Proceduredefinition stimmt nach LF-Normalisierung von der
PROCEDURE-Deklaration bis zum letzten END mit der kanonischen Quelle
überein.

| Artefakt | SHA256 |
| --- | --- |
| Source045, UTF-8/LF | `E42281870290941118479FEBCB52AEE6361691C67051950B53D2E85AAF8D6607` |
| Common170, UTF-8/LF | `2A4170E631DCCAEF5235217EC86387524187256B8F2B3BFD00E86AF7CD66AEBD` |
| Privater vollständiger Clientcapture, UTF-8/LF | `563114C90F7EF71BC1F885895DF8C88E2BF81BB2476AE22838664BEAACD7D329` |
| Privater Baseline-/JSON-Vergleich, UTF-8/LF | `B2DC2E4C8BC9C57C7F2DEB8743D889F3B9BD11D4227586632291D5CBBC6BA6C5` |
| Nativer Procedurebody, UTF-16/LF | `A17B7329F18035B305629DB9914535F3E55FC765E4B79E6A5069B5E3D6AD0BD8` |

Das eigene Lab wurde vollständig entfernt: Container und Volume,
zwei Cleanupschritte, null Fehler, CLEANUP_SUCCEEDED und REMOVED.
Der eigene verschlüsselte temporäre Secretwert ist entfernt.
Private Captures bleiben außerhalb von Git. Andere Labs und zuvor
gesperrte Cleanup-Pfade wurden nicht berührt.

Die fokussierte Evidenz belegt keine zusätzliche Histogrammabwesenheit,
native Histogrammpermission, Timeout-, HIGH-/LOW-Finding- oder positive
Partitionsvariation unter gemischter Sourcecollation. Integration175
liefert den bestehenden synthetischen inkrementellen Nachweis im
Frameworkscope; er wird nicht auf die gemischte Sourcefixture übertragen.
Ältere native Engines und zusätzliche CL150/160-Läufe waren ohne
konkretes Versionsrisiko nicht erforderlich und wurden nicht ausgeführt.
COLL-001 bleibt partiell; RUNTIME-001 und die bestehenden Maturityflags
bleiben unverändert. Vollständige statische Gates sind durch diesen
Fokusnachweis noch nicht behauptet.

Die vollständige statische Suite scheiterte zuerst ausschließlich am
Rawbytevergleich des PLAN-Adapters. Erneute kanonische Generierung
korrigierte seine Byte-/Zeilenendenrepräsentation bei logisch unverändertem
Inhalt; sie erzeugte keinen inhaltlichen Git-Diff. Der gezielte
Adaptervertrag bestand danach. Der anschließende vollständige Lauf von
`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand alle 75 Prüfungen mit Exitcode 0. Der fehlgeschlagene erste Lauf
wird nicht als PASS gewertet. Privacy prüfte 1.052 Dateien ohne Findings,
Schreibstil 710 und Regex 342. Roadmap-, Maturity- und Partialitätsverträge,
NOWAIT mit 998 Temp-Namen sowie beide Adapterverträge bestanden.
Das unabhängige Produkt-, Test-, Installer-, Dokumentations-, Evidenz-
und Statusreview hatte keine offenen Findings. Nach dem erfolgreichen
Vollgate wurde ausschließlich dieser Gateabsatz ergänzt; SQL, Tests,
Statusnotizen und die angegebenen Quellidentitäten blieben unverändert.

## Showplan-Referenzprojektionen und RelOp-Spaltenrollen am 7. Oktober 2026

Der begrenzte Slice betrifft `TVF_ExecutionPlanObjectReferences`,
`TVF_ExecutionPlanStatisticsUsage` und `TVF_ExecutionPlanColumnReferences`.
Dreißig gezielte Textprojektionen verwenden jetzt explizit
`SQL_Latin1_General_CP1_CS_AS`. Die ursprünglichen 53 Rückgabefelder und
23 Textcollations waren durch Frameworkvererbung bereits korrekt.
Es wird deshalb keine vorherige falsche Rückgabecollation behauptet.
Numerische Parsingcasts, Statementfilter, Ordinalbildung und vorhandene
Mehrfachzeilen bleiben erhalten. Die Statementauswahl erfolgt weiterhin
vor der Ordinalbildung.

Zusätzlich korrigiert der Slice einen bestehenden Spaltenrollenfehler:
Das materialisierte XML beginnt mit einem `RelOp`-Element; die sechs
bisherigen relativen Rollenpfade übersprangen diese Dokumentwurzel nicht
korrekt. Sechs gezielte Rootschritte lesen nun SEEK, RESIDUAL, JOIN,
ORDER_BY, GROUP_BY und OUTPUT am jeweiligen Operator. Verschachtelte
Parent- und Child-Operatoren behalten getrennte Node-Kontexte. Ein
fehlender Spaltenname wird weiterhin ausgeschlossen; ein fehlender
Objektname bei vorhandenem Spaltennamen darf als NULL erhalten bleiben.

Das eigene SQL-Server-2025-Lab verwendete Version 17.0.4075.5 auf Linux,
Server-/tempdb-Collation `Latin1_General_100_CS_AS`, Frameworkcollation
`SQL_Latin1_General_CP1_CS_AS` und Framework-CL170. Kanonische Installation
und Smoke bestanden vor und nach der Änderung. OPS-005 und PLAN-001
wurden aus den kanonischen Quellen regeneriert.

Ein unabhängiger SqlClient erfasste die ursprünglichen 36 gepaarten
nativen/JSON-Fälle in 108 Grids und fünf zusätzliche gemeinsame
XML-Varianten als 15 gepaarte Fälle in 45 Grids. Baseline und Candidate
führen jeweils 102 TVF-Ausführungen für diese 51 gepaarten Fälle aus.
Object liefert 27 und Statistics 19 vollständige Zeilen: Alle Werte,
NULLs, Ordinale und nativen Schemafacets stimmen exakt mit der Baseline
und den unabhängig vorab festgelegten Literalorakeln überein.
Column liefert in der Baseline null Zeilen; der Candidate liefert die
24 unabhängig erwarteten vollständigen Spaltenrollenzeilen.
Die ursprüngliche leere Columnmenge wird ausdrücklich nicht als
positiver Rollenvertrag gewertet. Alle 53 sys.columns-Facets und die
nativen SqlClient-Schemas einschließlich 23 Textcollations bleiben exakt
zur Baseline erhalten.

Common171 bestand nativ in zwei Batches mit einem Ergebnisgrid:
`ContractStatus=PASS`, CL170, 51 synthetische Fälle, 70 Literalzeilen,
53 Metadatenfelder und 23 Textcollations. Die 17 XML-/Statementvarianten
prüfen vollständige Zeilen einschließlich NULLs, Namespaces,
Unicode-/Bracketnamen, Statementauswahl, Rollen, fehlende und leere Namen,
ungültige numerische Attribute sowie getrennte Parent-/Child-NodeIds.
Der bidirektionale Multisetvergleich prüft zusätzlich Häufigkeiten;
der einzige Fall mit vollständigen Sortties enthält identische Nutzdaten.
Das Metadatenorakel prüft Namen, Ordinale, Typen, Größen, Precision, Scale,
Nullability, Collation und fehlende Identity.

Eine zusätzliche eigene RELEVANT-Consumerfixture mit acht synthetischen
Zeilen, zwei Spalten und zwei eingefrorenen FULLSCAN-Statistiken verwendete
separat bestätigtes Source-CL170. Der Consumer blieb AVAILABLE und nicht
partiell. Seine Snapshotanzahl wechselte von null auf genau eine relevante
Seek-Statistik; die andere Statistik blieb ausgeschlossen. Acht native
Statistikproperties und die eigene ObjectId wurden exakt gegengeprüft;
das ist kein vollständiger Nachweis aller 26 Snapshotfelder. Beide nativen
Statistiken blieben unverändert. Der private Comparator wählte zuerst ein
leeres Metadatenprobegrid über StatisticsId; die eindeutige NativeRows-
Zuordnung korrigierte diesen Harnessfehler und bestand. Die eigene
Fixture wurde nach Identitätsprüfung entfernt.

PlanCache120/123/127/128/129 bestanden zusammen in 15 Batches mit 177
Grids auf CL170. Integration192 bestand mit den kanonischen Standalone-
Quellen und einem geprüften eigenen temporären Cleanup-Ziel.
Bei Integration193 scheiterte zuerst ein privater Regex-Capture an einem
GO-Token in einem bestehenden Policykommentar. Der korrekt zerlegende
Single-Connection-Labrunner scheiterte anschließend an Gate 53633 für
die XE-Konfigurationschecksumme. Das eigene partielle Testziel wurde
nach ID-/Datumguards zurückgesetzt; ein erster kulturabhängiger
Datumsvergleich scheiterte, der korrigierte Vergleich bestand.
Ein diagnostischer Lauf von 193 in einer weiteren eigenen Datenbank
mit unverändertem Gate und zusätzlichen lesenden Proben bestand laut
Runner in 74 Batches und 6,2 Sekunden. Die native Probeausgabe wurde dabei
nicht erfasst. Die Ursache des vorherigen Fehlers 53633 bleibt unbekannt;
der spätere PASS ersetzt oder erklärt diesen fehlgeschlagenen Lauf nicht.

Die fokussierten statischen Verträge 997, 1034 und 1035 sowie die
UTF-8/LF-, XML- und Literalorakelkonsistenz bestanden. Die ersten
Aufrufe von 1034/1035 fehlten ausschließlich wegen des erforderlichen
CLI-Arguments `--repository-root`; die korrekt aufgerufenen Prüfungen
bestanden. Vollständige statische Gates sind noch nicht behauptet.

Die geprüften UTF-8/LF-Quellidentitäten lauten:

| Artefakt | SHA256 |
| --- | --- |
| `046_TVF_ExecutionPlanObjectReferences.sql` | `6921F59659E38D66C80CABE449E6A319A474BDD2D35D02FBC8E5B3CFF58FA662` |
| `047_TVF_ExecutionPlanStatisticsUsage.sql` | `EB5FBBD4CC784953529B6DD9D90C3257A8A0C6CA7D56485BD543736AB0D81AF8` |
| `048_TVF_ExecutionPlanColumnReferences.sql` | `DB4DA37CB0DE034E171348298F44DCC6583553A2C0CEC6B5E4B9AA9CFA4DE02D` |
| Common171, ursprünglicher nativer Capturestand vor der QI-Korrektur | `7ECDD92E8F14917FB277371F3EC2AD2EBD2B250EAA9F98644E1E78CE29ABF48A` |
| `171_Showplan_References_Collation_Runtime_Contract.sql`, QI-korrigierter Stand | `288497A26DFEA638D20BF7D3D90978881248694D617FCF8662B43493F99AF9B8` |

Das eigene Lab wurde entfernt: Container und Volume, zwei Schritte,
null Fehler, REMOVED. Der eigene verschlüsselte temporäre Secretwert
wurde entfernt; private Captures bleiben außerhalb von Git.

Die Belege betreffen synthetisches Showplan-XML und die eng begrenzte
Metadatenfixture. Zusätzliche Insert-/Delete-/MergeJoin-Varianten,
isolierte case-only Sortschlüssel, tatsächliche Workloadmessung und
Metadaten-Berechtigungsfehler bleiben unbelegt. Ältere native Engines
und CL150/160 wurden nicht ausgeführt. COLL-001 bleibt partiell;
RUNTIME-001, bestehende Maturityflags und Registry bleiben unverändert.

Die vollständige statische Suite
`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand am damaligen Teststand alle 75 Prüfungen mit Exitcode 0. Dieser
historische Lauf ging der begrenzten Evidenz-/Statusfortschreibung und
der nachfolgenden QI-Korrektur voraus. Abschließende Dokumentations-,
Schreibstil- und Privacyprüfungen folgen getrennt; sie werden hier noch
nicht als bestanden behauptet. Bei der damaligen Evidenzfortschreibung
blieben SQL und Tests unverändert.

### Common171-Einstiegsbatch nach erstem PR242-CI-Fehler

Der erste PR242-CI-Lauf scheiterte in Impactstufe 3 von 14 an Common171
mit Msg 1934: QUOTED_IDENTIFIER war für XML-Methoden nicht korrekt
gesetzt. Der Standalonevertrag 193 wurde in diesem Lauf nicht erreicht.
Der Test hatte den callerabhängigen SET-Zustand bisher nicht selbst
hergestellt. Die einzige Reparatur ergänzt `SET QUOTED_IDENTIFIER ON`
in einem eigenen Einstiegsbatch vor den XML-methodenhaltigen dynamischen
TVF-Aufrufen. Sources und Builder bleiben unverändert.

Ein frisches eigenes Mixed-SQL-Server-2025-Lab mit Version 17.0.4075.5,
abweichender CS-Server-/tempdb-Collation und garantierter Framework-CS-
Collation auf CL170 bestätigte kanonische Installation aus 166 Quellen
und Smoke. Der korrigierte Common171 bestand im Standardaufruf in drei
Batches. Ein unabhängiger SqlClient setzte QUOTED_IDENTIFIER zuvor
explizit OFF: Der ursprüngliche PR-Test scheiterte reproduzierbar,
der korrigierte Test bestand in fünf Batches mit zwei Ergebnisgrids.
Der Vertrag meldete erneut PASS mit 51 Fällen, 70 Literalzeilen,
53 Feldern und 23 Textcollations; eine unabhängige Gegenprobe bestätigte
`SESSIONPROPERTY('QUOTED_IDENTIFIER')=1`.

Das eigene Reparaturlab wurde entfernt: Container und Volume, zwei
Schritte, null Fehler, REMOVED. Der eigene verschlüsselte temporäre
Secretwert wurde gelöscht. Der oben genannte 75-PASS-Lauf bleibt ein
historischer Nachweis des vorherigen Teststands.

Die neue vollständige statische Suite
`pwsh -NoProfile -File Code/Tests/Static/Invoke-StaticContractSuite.ps1`
bestand am QI-korrigierten stabilen Stand alle 75 Prüfungen mit Exitcode 0.
Dieser Nachweis ist vom historischen Lauf vor der Testkorrektur getrennt.
Abschließende begrenzte Dokumentations-, Schreibstil- und Privacyprüfungen
folgen nach diesem Gateabsatz; sie werden hier noch nicht als bestanden
behauptet. Source und Test bleiben unverändert.

## Query-Store-Forced-Plans: gemeinsame Ausgabe und zwölf Textcollations

Der Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Lab
mit Version 17.0.4075.5, Server-/tempdb-Collation Latin1_General_100_CS_AS
und Frameworkcollation SQL_Latin1_General_CP1_CS_AS. Framework und beide
case-unterschiedlichen Unicode-Quelldatenbanken besitzen separat gemessene
Compatibility Levels 170. Jede eigene Quelle enthält zwei synthetische
Procedures, eine Tabelle mit acht Zeilen und zwei fehlerfrei erzwungene
Pläne. Query Store wurde nach der Vorbereitung auf READ_ONLY eingefroren.
Die vier letzten Ausführungszeiten unterscheiden sich; diese Fixture
belegt keine Auswahl zwischen unterschiedlichen Zeilen mit Sortties.

Sieben identische Baseline- und Candidate-Aufrufe bestätigen den Fehler
und seine Korrektur. Bei Limit 1 lieferten TABLE und CONSOLE ursprünglich
je vier Zeilen, RAW und JSON je eine. Der gemeinsame Export begrenzt jetzt
auch TABLE und CONSOLE auf eine Zeile; der XML-/Textkürzungsfall mit Limit 2
liefert zwei statt vier Zeilen. Unbegrenzte Ausgabe, exakte Upper-DB-Auswahl
und der leere NULL-Fehlerfilter behalten ihre Werte und Mengen.

Der unabhängige SqlClient bestätigt alle 32 nativen Feldfacetten und die
vollständige native/JSON-Zeilenparität. Nur fünf TABLE-Textcollations ändern
sich von tempdb-CS auf Framework-CS; alle zwölf Textspalten sind nun
explizit collatiert. QueryStoreDatabaseName bleibt NOT NULL, die übrigen
31 Felder bleiben nullable und alle Spalten ohne Identity. Ein getrenntes
32-Feld-Orakel verbindet native Query-Store-, Objekt-, Schema- und
Datenbankwerte mit unabhängigen Unicode-/UTF16-, Kürzungs-, Provenienz-
und XML-Ableitungen. Die Capturezeit wird zwischen unabhängigen Vorher-
und Nachhermessungen begrenzt. XML wird als XML-Wert verglichen: SqlClient
und SQL-CONVERT unterscheiden die Schreibweise leerer Elemente, ohne
unterschiedlichen Textinhalt. Byteparität der XML-Serialisierung wird
nicht behauptet. Die ursprünglichen 17 nativen Planproperties einschließlich
RawPlan bleiben für alle vier Pläne exakt erhalten; beide QS-Zustände
bleiben 1/1.

Common172 besteht in drei Batches mit neun Ergebnisgrids: zwölf allgemeine
und 14 bedingte native TABLE-/JSON-Fälle, drei Verbraucherfälle, fünf
Mappingablehnungen, drei leere SQL-CONSOLE-Captures und zwei direkte
positive CONSOLE-/JSON-Aufrufe. Der unabhängige Client bestätigt zusätzlich
die beiden positiven CONSOLE-Mengen mit einer beziehungsweise zwei Zeilen
und je 33 Feldern. Die nativen Fälle prüfen NULL-/0-/positive Limits,
Unicode-/Case-/LIKE-Auswahl, QueryId, Fehlerfilter, Textkürzung und den
Referenz-LIKE-Filter. Die vollständigen JSON-Zeilenvergleiche verwenden
BIN2; fachliche Filter behalten Framework-CS. Ohne die eigene Fixture
bestehen die allgemeinen Fälle und der positive Block meldet ausdrücklich
NOT_EXECUTED mit null nativen Fällen.

Der erste Common172-Lauf scheiterte an einer falschen Leer-Scope-Annahme:
N'' bedeutet keine Datenbankeinschränkung. Die Leerfälle verwenden jetzt
einen vorher nachweislich fehlenden Namen. Ein weiterer Lauf scheiterte
bei einer exakten Cross-DB-Referenzliste mit 208, weil der bestehende
Quellbatch monitor.TVF_ParseSqlNameList in der Quelldatenbank sucht. Dieser
Pfad bleibt unverändert und ist kein positiver Nachweis; der positive
Referenzfall verwendet das öffentliche LIKE-Pattern. Danach fiel der
bereits zuvor vom privaten Individualinstaller erzeugte, von der Baseline
abweichende Module-QI-OFF-Stand durch 1934 auf. Ein expliziter QI-/ANSI-ON-Einstiegsbatch korrigiert
nur diesen privaten Harness. Die sieben finalen Gegenprüfungen und
Common172 bestehen mit Module-QI/ANSI_NULLS jeweils true. Eine zwischenzeitliche
identitätsgeprüfte QI-Optionvariation der beiden eigenen Quellen wurde
zurückgenommen; native Planmetadaten und READ_ONLY blieben unverändert.

Die erste Vorbereitung der zweiten case-unterschiedlichen Quelle scheiterte
an kollidierenden physischen Dateinamen. Nach nativer Abwesenheits- und
Ownershipprüfung wurde ausschließlich diese Quelle mit eigenen eindeutigen
Dateinamen erzeugt. Ein privater NativeOracle-Leseversuch verwendete zunächst
cp1252 statt UTF-8 und scheiterte beim USE; die explizite UTF-8-Wiederholung
bestand. Beide Fälle sind Harnessfehler und begründen keine Produktänderung.

Ein direkter QueryStoreAnalysis-Aufruf nur mit ForcedPlans besteht mit
RAW, Child-JSON, genau einer Planzeile, erhaltenem hasMoreRows und einem
EXECUTED-Modulstatus. QueryStore139/110/121 sowie Integration190/165 bestehen
am korrigierten Installationsstand. Nach identitätsgeprüftem Cleanup beider
eigenen Quellen besteht die vorhergesagte impact-basierte Auswahl aus
Common124/165/172, Integration110/190/196/198 und QueryStore110/121/139 in
37 Batches auf CL170. Die endgültige Auswahl wird zusätzlich gegen die
konkreten Commit-SHAs geprüft.

OPS-005 wurde kanonisch regeneriert. Die erste vollständige statische Suite
scheiterte ausschließlich am PLAN-001-Bytevergleich: Nach dem Checkout
war ein CR-Byte am Headerübergang hinzugekommen. Kanonische Regeneration
entfernt ausschließlich dieses Byte; nach CRLF-Normalisierung sind die
Inhalte identisch. Der fokussierte Adaptervertrag besteht. Die neue
vollständige statische Suite besteht am stabilen Source-/Teststand alle
75 Prüfungen mit Exitcode 0. Die anschließenden begrenzten Dokumentations-,
Schreibstil- und Privacyprüfungen bestehen: Dokumentation 900 sowie die
Selbst- und Repositoryprüfungen 910/915 melden keine Befunde. UTF-8-,
Quellhash- und Diffprüfungen bestehen ebenfalls.

Die UTF-8/LF-Quellidentitäten des geprüften Stands lauten:

| Artefakt | SHA256 |
| --- | --- |
| Source060 | B31D09B85774C6D5971D12CB9FAD72A9621AC727C6400B6544ADFD7A4F8A42C3 |
| Common172 | 7AB20C8E5F6CBE133CA4DBA181A64C3DAFBDA2353FE8A30064FE20F76000DC86 |

Container und Volume des eigenen Labs wurden entfernt: zwei Schritte,
null Fehler, REMOVED. Der eigene verschlüsselte temporäre Secretwert ist
entfernt. Private Captures und konkrete Runtimeidentitäten bleiben
außerhalb von Git. Positive Forcingfehler, QS_OFF, Berechtigungs- und
Timeoutpfade, exakte Cross-DB-Referenzlisten sowie ältere native Engines
und CL150/160 bleiben unbelegt. COLL-001 bleibt partiell; Registry,
RUNTIME-001 und bestehende Maturityflags bleiben unverändert.

## Query-Store-PlanChanges: gemeinsame Queryauswahl und vollständige Planzuordnung

Der Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Lab
mit Version 17.0.4075.5, Server-/tempdb-Collation Latin1_General_100_CS_AS
und Frameworkcollation SQL_Latin1_General_CP1_CS_AS. Framework und beide
case-unterschiedlichen Unicode-CI_AS-Quellen besitzen separat gemessene
Compatibility Levels 170. Jede Quelle enthält eine synthetische Tabelle
mit 4096 Zeilen und drei eigene Procedures. Zwei unveränderte Querytexte
wurden vor und nach einem eigenen Indexaufbau mit Recompile ausgeführt.
Native Kataloge bestätigen je zwei PlanIds derselben QueryId mit zwei
unterschiedlichen Planhashes; die dritte Query besitzt genau einen Plan.
Nach Bereinigung ausschließlich eigener zusätzlicher Capturezeilen wurde
Query Store mit deaktiviertem Capture auf READ_ONLY eingefroren. Die
Fixture enthält insgesamt sechs Queries und zehn Pläne. Ihre Rangwerte
unterscheiden sich; eine positive Auswahl zwischen Sortties ist unbelegt.

Das unveränderte Original scheitert im positiven Scope mit behandeltem
Fehler 209: Die object_id-Projektion ist nach dem Join auf sys.objects
mehrdeutig. Diese originale leere AVAILABLE_LIMITED-Ausgabe bleibt von
der privaten Vorstufe getrennt. Ausschließlich die Qualifikation
[Q].[object_id] ermöglicht deren positive Limitgegenprobe. Bei Limit 1
liefert diese Vorstufe vier TABLE-/CONSOLE-Queries, JSON und RAW je eine
mit zwei zugehörigen Plänen. Bei Limit 2 liefern TABLE und CONSOLE weiter
vier statt zwei Queries. Der Produktfix enthält die notwendige einzelne
Qualifikation und einen frühen typgleichen gemeinsamen Summaryexport.
Dessen globale Auswahl erfolgt einmal nach Bewertung und Zählern; Plans
werden anhand der tatsächlich exportierten Datenbank-/Querykeys beschnitten.

Neun gepaarte Clientfälle der ausdrücklich qualifizierten Vorstufe und
des Candidate bestätigen die korrigierte TABLE-/CONSOLE-Grenze sowie
erhaltene RAW-/JSON-Werte, unbegrenzte Ausgabe, Mehrplan-NULL-Semantik,
XML und Textkürzung. Alle nativen Facetten der 22 Query- und 28 Planfelder
bleiben unverändert. Die sieben beziehungsweise neun Textcollations waren
bereits Framework-CS und bleiben erhalten; beide Datenbanknamenspalten
bleiben NOT NULL, die übrigen Felder nullable und alle ohne Identity.
Ein getrenntes 50-Feld-Orakel aggregiert native Query-, Text-, Plan-,
Objekt-, Schema- und Datenbankwerte und ergänzt unabhängige Unicodecodepoint-,
UTF16-Byte-, Kürzungs-, Provenienz- und XML-Ableitungen. Capturezeiten werden
zwischen getrennten Vorher-/Nachhermessungen mit datetime2(3) begrenzt.
XML wird textinhaltserhaltend als XML-Wert verglichen; eine bytegleiche
Serialisierung wird nicht behauptet. Native Query-Store-Metadaten bleiben
vor und nach allen positiven Verträgen exakt erhalten, beide QS-Zustände
1/1, Module-QI/ANSI_NULLS true und caller-LOCK_TIMEOUT 137.

Common173 besteht in drei Batches mit zwölf Ergebnisgrids: elf allgemeine
und 16 bedingte native TABLE-/JSON-Fälle, drei Verbraucherfälle, sechs
Mappingablehnungen, drei leere SQL-CONSOLE-Captures und drei direkte
positive CONSOLE-/JSON-Aufrufe. Die nativen Fälle prüfen NULL-/0-/positive
Limits, QueryId/-Hash, exakte Case-/LIKE-Auswahl, Mehrplan-0-/1-/NULL,
Textgrenzen, XML, UTC-Grenzen und Referenz-LIKE. Der gezielte Zeitfall
bestätigt tatsächlich PlanCount 1 in der gefilterten Summary und zwei
vollständige Detailpläne derselben Query. Vollzeilenvergleiche verwenden
BIN2; fachliche Filter behalten Framework-CS. Der unabhängige Client
bestätigt zusätzlich alle drei positiven CONSOLE-Mengen mit 1/2/3 Zeilen,
je 23 Feldern und vollständigen nativen Werten sowie beide positiven
TABLE-Teilmappings queries-only und plans-only. Ohne eigene Fixture besteht
der allgemeine Vertrag in drei Batches mit neun Grids; der positive Block
meldet NOT_EXECUTED mit null nativen Fällen. Er wird nicht als PASS gezählt.

Ein direkter QueryStoreAnalysis-Aufruf nur mit PlanChanges bestätigt RAW,
Child-JSON, eine Query mit zwei Plänen, hasMoreRows und EXECUTED auf
Ordinal 4. QueryStore137/110/121 und Integration190/165 bestehen. Nach
identitätsgeprüftem Cleanup beider eigenen Quellen besteht die vorhergesagte
Auswahl aus Common124/165/173, Integration110/190/196/198 und
QueryStore110/121/137 in 28 Batches auf CL170. Die endgültige Auswahl wird
zusätzlich gegen konkrete Commit-SHAs geprüft.

Private Harnesskorrekturen betreffen ausschließlich die Vorbereitung:
TABLE-Ziele benötigen zunächst eine Seedspalte statt vorab erzeugter
Vollschemas; exakte Namenlisten verwenden Pipe statt Komma. Der erste
positive Originalaufruf belegt danach den Produktfehler 209. Das erste
Zeitgate verglich siebenstellige Vorherwerte mit gerundeten dreistelligen
Capturezeiten; beide Messgrenzen verwenden jetzt dieselbe native Präzision.
Eine anfänglich angenommene Capturemode-Zahl wurde durch den tatsächlich
beobachteten Wert 3 ersetzt. Der erste Impactaufruf fand relative :r-Dateien
nicht und startete keine ausgewählten SQL-Tests. Die private Expansion der
zehn unveränderten Includes ermöglicht den erfolgreichen Lauf. Keiner
dieser Harnessfälle begründet eine weitere Produktänderung.

OPS-005 ist kanonisch synchronisiert. PLAN-001 wurde vorsorglich kanonisch
regeneriert; daraus entsteht keine semantische Gitänderung. Die vollständige
statische Suite besteht am stabilen Source-/Teststand alle 75 Prüfungen
mit Exitcode 0. Die anschließenden begrenzten Dokumentations-, Schreibstil-
und Privacyprüfungen bestehen: 900 sowie die Selbst- und Repositoryprüfungen
910/915 melden keine Befunde. UTF-8-, Quellhash- und Diffprüfungen werden
vor dem Commit gesondert geprüft.

Die UTF-8/LF-Quellidentitäten des geprüften Stands lauten:

| Artefakt | SHA256 |
| --- | --- |
| Source040 | 3B8214FD142C95D37AB09099665254B2C0F70556B4D7444F47BAA5D9E1293919 |
| Common173 | 4D129C40ED1B2894ECB7555E5AAA4EA380DB107EC1F44160F312E9839B0413F4 |

Container und Volume des eigenen Labs sind entfernt: zwei Schritte,
null Fehler, REMOVED. Der eigene verschlüsselte temporäre Secretwert ist
entfernt. Private Captures und konkrete Runtimeidentitäten bleiben
außerhalb von Git. Positive Sortties, Compile-Rundungsgrenzen, QS_OFF,
Berechtigungen, Timeout, exakte Cross-DB-Referenzlisten, ältere native
Engines und CL150/160 bleiben unbelegt. Der bestehende unqualifizierte
Referenzlistenhelper bleibt außerhalb dieses Slices; der 208-Pfad besitzt
hier keinen neuen positiven Nachweis. COLL-001 bleibt partiell; Registry,
RUNTIME-001 und bestehende Maturityflags bleiben unverändert.

## Query-Store-Hints: gemeinsame Ausgabegrenze bei datenbanklokalen Ranggleichheiten

Der Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Lab
mit Version 17.0.4075.5, Server-/tempdb-Collation Latin1_General_100_CS_AS
und Frameworkcollation SQL_Latin1_General_CP1_CS_AS. Framework und beide
case-unterschiedlichen Unicode-CI_AS-Quellen besitzen getrennt gemessene
Compatibility Levels 170. Jede Quelle enthält eine eigene synthetische
Tabelle mit vier Zeilen und zwei eigene Procedures. Zwei erfasste Queries
erhalten jeweils OPTION(MAXDOP 1) und werden erneut ausgeführt. Danach wird
Query Store mit Capture NONE auf READ_ONLY eingefroren. Native Kataloge
bestätigen vier gespeicherte Hints, Failure Reason und Failure Count jeweils
0 sowie Source 0 mit SourceDesc User. Die beiden Hint-IDs wiederholen sich
tatsächlich über die Datenbankgrenze; die vorhandene Sortierung enthält
keinen zusätzlichen Datenbank-Tiebreaker.

Das unveränderte Original liefert bei Limit 1 oder 2 vier TABLE- und
CONSOLE-Zeilen, während RAW und JSON die verlangte Menge liefern. Der
Produktfix materialisiert früh einen typgleichen Export mit 22 Feldern
und begrenzt ihn einmal nach vollständiger Sammlung, Unicodeprojektion,
Truncationwarnungen und Zählern. Alle Ausgabeconsumer lesen dieselbe Menge.
Die neun Textcollations waren bereits Framework-CS und bleiben erhalten.
Datenbankname und Truncationflag bleiben NOT NULL, die übrigen 20 Felder
nullable; keine Spalte besitzt eine Identity.

Dreizehn gepaarte Clientfälle umfassen je vollständiger Original-/Candidate-
Suite 14 Batches und 37 Ergebnisgrids. Sie bestätigen die korrigierten
TABLE-/CONSOLE-Limits, erhaltene RAW-/JSON-Werte,
NULL-/0-Ausgabegrenzen, leere Fehlerfilter und negative Zeilenlimits.
Ein unabhängiges 22-Feld-Orakel verwendet native Hint-, Query-, Text- und
Datenbankwerte sowie eigene Unicodezeichen-, UTF16-Byte-, Kürzungs- und
Provenienzableitungen. Alle nativen Feldfacetten bleiben unverändert.
Capturezeiten liegen zwischen getrennten datetime2(3)-Messgrenzen. Innerhalb
jedes Aufrufs werden vollständige Consumer-/JSON-Multisets verglichen;
zwischen getrennten Aufrufen werden native Werte, Schlüssel und strikte
Ranggrenzen geprüft. Gleiche Sortwerte erlauben unterschiedliche gültige
Auswahlen und werden nicht als stabile Auswahlidentität ausgegeben.

Der erste Common174-Lauf scheitert am negativen Textlimit. Eine getrennte
native Gegenprobe bestätigt Fehler 51021 und NULL-JSON sowohl im
unveränderten Original als auch im ersten Exportstand: Trotz gesetztem
INVALID_PARAMETER erreicht der negative Wert den Unicodehelper. Der
zusätzliche minimale Guard überspringt ausschließlich diesen Helper bei
negativem Textlimit. Die finale Gegenprobe liefert ohne Ausnahme
INVALID_PARAMETER, leere Arrays und erhaltenen caller-LOCK_TIMEOUT 137.
Alle dreizehn gepaarten Clientfälle werden am korrigierten Stand erneut
ausgeführt und bestehen. NULL-Textlimits bleiben unverändert zulässig.

Common174 besteht mit elf allgemeinen TABLE-/JSON-Fällen, 15 bedingten
nativen Vollfeld-/Rangfällen, drei Verbrauchern, sechs Mappingablehnungen,
drei leeren SQL-CONSOLE-Captures und drei direkten positiven CONSOLE-/JSON-
Statusprüfungen. Der unabhängige Client bestätigt zusätzlich die vollständigen
nativen Werte und Facetten aller drei positiven 23-feldrigen CONSOLE-Mengen
mit 1/2/4 Zeilen. Exakte Unicode-/Case-Auswahl, LIKE, QueryId, NULL-/0-/positive
Limits, Textgrenzen und die bestehende gesunde NurMitFehler-1-/NULL-Leermenge
sind geprüft. Ohne Fixture bestehen elf allgemeine Fälle; der native Block
meldet NOT_EXECUTED mit null Fällen und wird nicht als PASS gezählt.

Ein direkter QueryStoreAnalysis-Aufruf ausschließlich mit Hints bestätigt
RAW und Child-JSON mit vollständigen 22 Feldern, einer Zeile, hasMoreRows,
EXECUTED auf Ordinal 7 und caller-LOCK_TIMEOUT 137. Native Datenbank-,
Query-Store-, Hint-, Querytext-, Hash- und Modulmetadaten bleiben vor und nach
den finalen positiven Verträgen exakt erhalten. Beide Quellen bestätigen
READ_ONLY 1/1, Capturemode 3 sowie QI/ANSI_NULLS true. Die ursprüngliche
Procedure erhält den Caller-Timeout bereits nativ; eine zusätzliche
Timeoutreparatur ist nicht Bestandteil dieses Slices.

Nach identitätsgeprüftem Cleanup beider eigenen Quellen besteht die
vorhergesagte Auswahl aus Common124/165/174, Integration110/196/198 und
QueryStore110/121/122 in 25 Batches auf CL170. Die endgültige Auswahl wird
zusätzlich gegen konkrete Commit-SHAs geprüft. Alle 75 statischen Prüfungen
bestehen am stabilen funktionalen Stand mit Exitcode 0. OPS-005 ist aus
166 kanonischen Quellen synchronisiert; sein Update und PLAN-001 bleiben
semantisch unverändert. Die anschließenden begrenzten Dokumentations-,
Schreibstil- und Privacyprüfungen bestehen: 900 sowie die Selbst- und
Repositoryprüfungen 910/915 melden keine Befunde. UTF-8-, Hash- und
Diffprüfungen werden vor dem Commit gesondert geprüft.

Private Harnesskorrekturen betreffen ausschließlich die Vorbereitung:
Der zweite case-unterschiedliche Datenbankname benötigt im eigenen Lab
einen getrennten physischen Dateinamen. Der Parentchecker liest den
Modulstatus aus dem tatsächlich vorhandenen RAW-Grid; ein modules-JSON-Array
gehört nicht zum bestehenden QueryStoreAnalysis-Vertrag. Keiner dieser
beiden Fälle begründet eine zusätzliche Produktänderung.

Die UTF-8/LF-Quellidentitäten des geprüften Stands lauten:

| Artefakt | SHA256 |
| --- | --- |
| Source070 | C6B075A87091D47A50BBC2BC7EFBD087520BE0BFD135C9C9129F630D87601044 |
| Common174 | 95729F22132A2692C00B105C5E001C40649641EBC8F5C44AEB2B8DEA63B235E6 |

Container und Volume des eigenen Labs sind entfernt: zwei Schritte,
null Fehler, REMOVED. Der eigene verschlüsselte temporäre Secretwert ist
entfernt. Private Captures und konkrete Runtimeidentitäten bleiben
außerhalb von Git. Positive Hintfehler und Fehlerpriorisierung, QS_OFF,
Berechtigungen, Timeout, ältere native Engines und CL150/160 bleiben
unbelegt. COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende
Maturityflags bleiben unverändert.

## Query-Store-Regressionen: gemeinsamer Export mit getrennten nativen Intervallen

Der Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Lab
mit Version 17.0.4075.5, Server-/tempdb-Collation Latin1_General_100_CS_AS
und Frameworkcollation SQL_Latin1_General_CP1_CS_AS. Framework und beide
case-unterschiedlichen Unicode-CI_AS-Quellen besitzen getrennt gemessene
Compatibility Levels 170. Jede Quelle enthält eine eigene synthetische
Vierzeilentabelle und zwei eigene Procedures. Zwei tatsächlich getrennte,
direkt aufeinanderfolgende Ein-Minuten-Intervalle erfassen je Query zuerst
zwei und danach acht beziehungsweise vier Ausführungen. Native Kataloge
liefern die exakten Fenstergrenzen. Query Store wird anschließend mit
Capture NONE auf READ_ONLY eingefroren; beide Quellen bestätigen 1/1 und
Capturemode 3. Die EXECUTIONS-Metrik ergibt über beide Datenbanken echte
Ranggleichheiten bei 300 Prozent mit absoluter Änderung 6 sowie 100 Prozent
mit Änderung 2.

Das unveränderte Original liefert bei Limit 1 oder 2 jeweils vier TABLE-
und CONSOLE-Zeilen; RAW und JSON liefern die verlangte Menge. Ein früher
typgleicher Export mit unveränderten 25 Feldern wird nach vollständiger
Sammlung, Unicodeprojektion, Truncationwarnungen und Zählern einmal global
begrenzt. Alle vier Ausgabeconsumer lesen diese Menge. Die sieben
Textcollations waren bereits Framework-CS. Datenbankname und Truncationbit
bleiben NOT NULL, die übrigen 23 Felder nullable; keine Spalte besitzt
eine Identity. Parameter, Intervallaggregation, Floatfilter, bestehende
Sortierung, Gates, lokale N+1-Grenze und Statusbewertung bleiben erhalten.

Zweiundzwanzig gepaarte Clientfälle umfassen je vollständiger Original-/
Candidate-Suite 23 Batches und 64 Ergebnisgrids. Ein unabhängiges natives
25-Feld-Orakel bestätigt sämtliche Werte und Feldfacetten, sieben
Textcollations, NULL-/0-/positive Limits, Textgrenzen, Mindestexecutions,
NULL-Schwellwerte, Prozentgrenzen 100/100.01/300/300.01, QueryId und Hash
sowie exakte Unicode-/Case-Auswahl. Capturezeiten liegen zwischen getrennten
datetime2(3)-Messgrenzen. Vollständige Consumer-/JSON-Multisets werden innerhalb
eines Aufrufs verglichen. Zwischen getrennten Aufrufen werden native Werte,
eindeutige Datenbank-/Queryschlüssel und strikt bessere Ranggrenzen geprüft;
gleiche Sortwerte verlangen keine identische Auswahl. Alle acht Metafelder
außer der Erzeugungszeit und die nativen Ausgabeschemas bleiben zwischen
Original und Candidate gleich. Caller-LOCK_TIMEOUT 137 bleibt in allen
22 Fällen erhalten.

Eine getrennte native Originalgegenprobe bestätigt Fehler 51021 mit NULL-
JSON beim negativen Textlimit: Der Unicodehelper wird trotz bereits
gesetztem INVALID_PARAMETER aufgerufen. Ein minimaler Guard überspringt
ausschließlich diese Projektion bei negativem Textlimit. Der finale Stand
liefert ohne Ausnahme INVALID_PARAMETER mit leeren Arrays und erhaltenem
Caller-Timeout. NULL-Textlimits bleiben unverändert zulässig.

Common175 besteht mit 14 allgemeinen TABLE-/JSON-Fällen, 20 bedingten
nativen Vollfeld-/Rangfällen, drei Verbrauchern, sechs Mappingablehnungen,
drei leeren SQL-CONSOLE-Captures und drei direkten positiven CONSOLE-/JSON-
Statusprüfungen. Der positive Block leitet Fenster und Sollwerte aus nativen
Intervall-, Runtime-, Plan-, Query-, Objekt- und Textkatalogen ab und verändert
keine Fixture. Positive Referenz-LIKE- und gemischte vorhandene/fehlende
Auswahlfälle bestehen. Ein unabhängiger Client bestätigt zusätzlich alle
25 nativen Werte und 26 CONSOLE-Feldfacetten der drei positiven Mengen mit
1/2/4 Zeilen. Ohne Fixture bestehen 14 allgemeine Fälle; der native Block
meldet NOT_EXECUTED mit null Fällen und wird nicht als positiver PASS gezählt.

Ein direkter QueryStoreAnalysis-Aufruf ausschließlich mit Regressionen
verwendet die Parentdefaults DURATION_AVG und 20 Prozent sowie die aus dem
Vergleichsfenster abgeleitete Baseline. Die unabhängig gemessenen Dauerwerte
aller vier Queries sinken; der Parent liefert daher korrekt null Regressionen,
AVAILABLE, ein leeres 25-feldriges RAW-Schema und Child-JSON sowie EXECUTED
auf Ordinal 5. Dieser Lauf belegt keine positive Parent-Regression. Native
Datenbank-, Query-Store-, Querytext-, Hash-, Runtime-, Intervall- und
Modulmetadaten bleiben vor und nach den positiven Verträgen unverändert.
QI und ANSI_NULLS bleiben true. Der Caller-Timeout bleibt auch im Parent
137; eine zusätzliche Timeoutreparatur ist nicht Bestandteil dieses Slices.

Nach identitätsgeprüftem Cleanup beider eigenen Quellen besteht die
vorhergesagte Auswahl aus Common124/165/175, Integration110/165/196/198
und QueryStore110/121/138 in 28 Batches auf CL170. Die endgültige Auswahl
wird zusätzlich gegen konkrete Commit-SHAs geprüft. Alle 75 statischen
Prüfungen bestehen am stabilen funktionalen Stand mit Exitcode 0. OPS-005
ist aus 166 kanonischen Quellen synchronisiert; sein Update und PLAN-001
bleiben semantisch unverändert. Die anschließenden begrenzten Dokumentations-,
Schreibstil- und Privacyprüfungen bestehen ebenfalls. UTF-8-, Quellhash-,
Lieferumfang- und Diffprüfungen werden vor dem Commit gesondert geprüft.

Der erste private Fixture-Aufbau erfasst beide Ausführungsgruppen noch im
selben Intervall und erfüllt den geplanten Zeitnachweis nicht. Ausschließlich
die beiden eigenen Testquellen werden zurückgesetzt; nach ausdrücklichem
Warten auf die gemessene Grenze bestätigt der neue native Aufbau zwei
getrennte Intervalle. Erst dieser Stand wird für die gepaarten Produktfälle
verwendet. Weitere private Harnesskorrekturen normalisieren äquivalente
Client-/SQL-JSON-Zeit- und Zahlendarstellungen vor dem Multisetvergleich.
Keine dieser Korrekturen begründet eine zusätzliche Produktänderung.

Die UTF-8/LF-Quellidentitäten des geprüften Stands lauten:

| Artefakt | SHA256 |
| --- | --- |
| Source050 | 27AD530CD55325E29655B409BC035E657EF6DECEFBD46C92A855948605D876EB |
| Common175 | 13C4AD104BADB7378973961A05E8BC27C6823F768B1A4DBCED460479A2A41AC7 |

Container und Volume des eigenen Labs sind entfernt: zwei Schritte,
null Fehler, REMOVED. Der eigene verschlüsselte temporäre Secretwert ist
entfernt. Private Captures und konkrete Runtimeidentitäten bleiben außerhalb
von Git. Positive gewichtete Metriken, allgemeine Float-/Rundungsgrenzen,
QS_OFF, Berechtigungen, Timeout, exakte Cross-DB-Referenzlisten, ältere native
Engines und CL150/160 bleiben unbelegt. Der bestehende unqualifizierte
Referenzlistenhelper bleibt außerhalb dieses Slices; dessen 208-Pfad erhält
hier keinen neuen positiven Nachweis. COLL-001 bleibt partiell; Registry,
RUNTIME-001 und bestehende Maturityflags bleiben unverändert.

## Query-Store-Waits: begrenzter Export und numerischer Kategorienvergleich

Der Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Lab
mit Version 17.0.4075.5, Server-/tempdb-Collation Latin1_General_100_CS_AS
und Frameworkcollation SQL_Latin1_General_CP1_CS_AS. Framework und beide
case-unterschiedlichen Unicode-CI_AS-Quellen besitzen getrennt gemessene
Compatibility Levels 170. Jede Quelle enthält eine eigene synthetische
Vierzeilentabelle und zwei eigene Procedures. Acht kontrollierte Versuche
mit Sperrwartezeit bestätigen den eigenen Blocker und die eigene wartende
Session; ROLLBACK erhält die Tabellenwerte. Nach Entfernung ausschließlich
eigener vorbereitender Query-Store-Queries liefern native Kataloge vier
positive Lock-/Regular-Gruppen mit eigenen Query-, Plan- und Objektidentitäten
in einem tatsächlichen Ein-Minuten-Intervall. Query Store ist anschließend
mit Capture NONE auf READ_ONLY eingefroren; beide Quellen bestätigen 1/1,
Capturemode 3 und Wait Capture ON.

Das unveränderte Original liefert auf den CI-Quellen Fehler 468, auch bei
NULL-Kategorie. Eine native Gegenprobe grenzt den Fehler auf den konvertierten
numerischen Kategorienarm ein; Gruppierung und alleiniger Deskriptorarm
funktionieren. Nur dieser numerische Vergleich wird beidseitig explizit
Framework-collatiert. Der Deskriptorarm bleibt unverändert mit seiner nativ
gemessenen Latin1_General_CI_AS_KS_WS-Semantik. Lock und lock passen weiterhin;
3 passt, 03, leerer Text und ein fehlender Deskriptor passen nicht.

Für einen positiven Originalvergleich werden ausschließlich die beiden
eigenen Quelldatenbankcollations vorübergehend an die Frameworkcollation
angeglichen. Das Original liefert dann bei Limit 1 oder 2 jeweils vier TABLE-
und CONSOLE-Zeilen, während RAW und JSON begrenzt sind. Die Quellen werden
danach wieder auf CI zurückgestellt; sämtliche zuvor erfassten nativen
Datenbank-, Query-Store-, Querytext-, Hash-, Wait-, Intervall- und Modulwerte
sind exakt unverändert. Originalfehler auf CI, positiver Originalvergleich
auf CS und finaler positiver Nachweis auf wiederhergestelltem CI werden
getrennt bewertet.

Ein früher typgleicher Export mit unveränderten 25 Feldern wird nach voller
Sammlung, Unicodeprojektion, Truncationwarnungen, Zählern und Status einmal
global begrenzt. Alle vier Consumer lesen diese Menge. Die acht Textcollations
waren bereits Framework-CS; Datenbankname und Truncationbit bleiben NOT NULL,
die übrigen 23 Felder nullable und alle Felder ohne Identity. Parameter,
lokale N+1-Grenze, Gates, Status, Sortierung, vollständige Intervallüberlappung,
COUNT_BIG, SUM, MAX und ungewichtetes AVG gespeicherter Durchschnittswerte
bleiben erhalten. Fenster innerhalb eines Intervalls liefern dessen ganze
Werte und native Grenzen; ein anschließendes Fenster liefert keine Zeile.

Vierundzwanzig gepaarte Vergleichsfälle umfassen je vollständiger Original-/
Finalsuite 25 Batches und 70 Ergebnisgrids. Ein unabhängiges natives 25-Feld-Orakel bestätigt alle
Werte und Facetten, acht Textcollations, NULL-/0-/positive Limits, QueryId,
Hashes, exakte Unicode-/Case-Auswahl, LIKE, Kategorien und Fenster. Capture-
zeiten liegen zwischen getrennten datetime2(3)-Messgrenzen. Vollständige
Consumer-/JSON-Multisets werden innerhalb eines Aufrufs verglichen; eindeutige
Datenbank-/Plan-/Ausführungstyp-/Kategorieschlüssel und strikt bessere
Ranggrenzen werden unabhängig geprüft. Die vier nativen Totalwerte sind
verschieden; diese Fixture belegt keine tatsächlichen Ranggleichheiten.
Alle sieben Metafelder außer der Erzeugungszeit und die nativen Ausgabeschemas
bleiben zwischen positivem Original und Finalstand gleich. Caller-
LOCK_TIMEOUT 137 bleibt in allen Fällen erhalten.

Eine getrennte Originalgegenprobe bestätigt Fehler 51021 mit NULL-JSON beim
negativen Textlimit. Ein minimaler Guard überspringt ausschließlich die
Unicodeprojektion für negative Werte. Der finale Stand liefert ohne Ausnahme
INVALID_PARAMETER mit leeren Arrays und erhaltenem Caller-Timeout. NULL-
Textlimits bleiben zulässig und erhalten den vollständigen Text.

Common176 besteht mit 14 allgemeinen TABLE-/JSON-Fällen, 21 bedingten nativen
Vollfeld-/Rangfällen, drei Verbrauchern, sechs Mappingablehnungen, drei leeren
SQL-CONSOLE-Captures und drei direkten positiven CONSOLE-/JSON-Statusprüfungen.
Der unabhängige Client bestätigt alle 25 Werte und 26 CONSOLE-Feldfacetten
der positiven Mengen mit 1/2/4 Zeilen. Der native Block liest ausschließlich
vorbereitete eigene Quellen und prüft deren CI-Collation, Katalogumfang,
Objekte, Zeilenzahl, QI/ANSI und Waitzustand. Der erste Testlauf zeigt eine
fehlende Optionsprojektion nach einer Guarderweiterung; ausschließlich der
Test wird korrigiert und vollständig neu geprüft. Die Produktquelle bleibt
unverändert. Ohne Fixture bestehen 14 allgemeine Fälle; der native Block
meldet NOT_EXECUTED mit null Fällen und wird nicht als positiver PASS gezählt.

Zwei positive direkte QueryStoreAnalysis-Aufrufe ausschließlich mit WaitStats
bestätigen Limits 1/2, weitergeleitete Innenfenster, die vollständigen 25 RAW-
Felder, Child-JSON-Parität und EXECUTED auf Ordinal 3. Parent und Child liefern
AVAILABLE mit leeren Warnungsarrays. Auch dort bleibt Caller-Timeout 137.
Alle erfassten nativen Katalogwerte bleiben nach den positiven Verträgen
unverändert; QI und ANSI_NULLS bleiben true.

Nach identitätsgeprüftem Cleanup beider eigenen Quellen besteht die
vorhergesagte Auswahl aus Common124/165/176, Integration110/196/198 und
QueryStore110/121/136 in 25 Batches auf CL170. Die endgültige Auswahl wird
zusätzlich gegen konkrete Commit-SHAs geprüft. Alle 75 statischen Prüfungen
bestehen am stabilen funktionalen Stand mit Exitcode 0. OPS-005 ist aus 166
kanonischen Quellen synchronisiert; sein Update und PLAN-001 bleiben
semantisch unverändert. Die anschließenden begrenzten Dokumentations-,
Schreibstil- und Privacyprüfungen bestehen ebenfalls. UTF-8-, Quellhash-,
Lieferumfang- und Diffprüfungen erfolgen am finalen Lieferstand vor dem Commit.

Die UTF-8/LF-Quellidentitäten des geprüften Stands lauten:

| Artefakt | SHA256 |
| --- | --- |
| Source030 | 6B3F1893A0A0DA2C55FA6CEBE80995B49BEC17E0E50F299ECCFF815644712C88 |
| Common176 | E5290FECB3EAB3D1056A9E4CB1F49B7BA5BB9C043C0134E91EE7BED72BA8E572 |

Container und Volume des eigenen Labs sind entfernt: zwei Schritte,
null Fehler, REMOVED. Der eigene verschlüsselte temporäre Secretwert ist
entfernt. Private Captures und konkrete Runtimeidentitäten bleiben außerhalb
von Git. Mehrere gespeicherte Records mit unterschiedlicher Gewichtung,
allgemeine AVG-/Rundungsgrenzen, weitere Kategorien, QS_OFF, Berechtigungen,
Timeout, exakte Cross-DB-Referenzlisten, Regex, ältere native Engines und
CL150/160 bleiben unbelegt. Der unqualifizierte Referenzlistenhelper bleibt
außerhalb dieses Slices; dessen 208-Pfad erhält hier keinen neuen positiven
Nachweis. COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende
Maturityflags bleiben unverändert.

## Query-Store-Runtime: gemeinsamer Export und native Sortprojektion

Der Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Lab
mit Version 17.0.4075.5, Server-/tempdb-Collation Latin1_General_100_CS_AS
und Frameworkcollation SQL_Latin1_General_CP1_CS_AS. Framework und beide
case-unterschiedlichen Unicode-CI_AS-Quellen besitzen getrennt gemessene
Compatibility Levels 170. Jede Quelle enthält eine synthetische
Vierzeilentabelle und zwei eigene Procedures. Zwei tatsächlich angrenzende
Ein-Minuten-Intervalle erfassen je Quelle 2→8 beziehungsweise 2→4 Ausführungen
mit unterschiedlichen gespeicherten CPU- und Dauerdurchschnittswerten.
Ausschließlich eigene vorbereitende Query-Store-Queries werden entfernt.
Der verbliebene Katalog enthält zwei eigene Query-/Planidentitäten je Quelle
mit Regular-Ausführungstyp. Capture NONE und READ_ONLY frieren die Daten ein;
beide Quellen bestätigen Actual-/Desiredstate 1/1 und Capturemode 3.

Das unveränderte Original scheitert auf beiden CI-Quellen mit Fehler 209
am unqualifizierten SELECT-Feld object_id. Eine getrennte private Vorstufe
qualifiziert ausschließlich dieses Feld; sie zeigt anschließend Fehler 207
für TotalCpuMs. Neun Aliase benennen ausschließlich die bereits bestehenden
lokalen Sortprojektionen einschließlich ihrer decimal(38,3)-Konvertierungen.
Der positive Neun-Sortierungen-Lauf zeigt danach bei LAST_EXECUTION Fehler
169 wegen derselben Expression im primären und sekundären ORDER BY.
Ausschließlich dort entfällt der redundante zweite lokale Sortausdruck.
Alle anderen Sortschlüssel bleiben erhalten. Diese drei gezielten Reparaturen
werden vom eigentlichen Exportvergleich getrennt betrachtet.

Eine private positive Vorstufe enthält genau diese Reparaturen und weiterhin
den ursprünglichen Ausgabepfad. Sie liefert bei Limit 1 oder 2 jeweils vier
TABLE- und CONSOLE-Zeilen, während RAW und JSON begrenzt sind. Der finale
Produktstand verwendet einen frühen typgleichen Export mit unveränderten
40 Feldern und zehn bereits korrekten expliziten Frameworktextcollations.
QueryStoreDatabaseName, QueryId und PlanId bleiben NOT NULL, die übrigen
37 Felder nullable und alle Felder ohne Identity. Ein einziges globales TOP
materialisiert den Export nach Textprojektion, vollständigem Plan-XML-Parsing,
Truncationwarnung, Kandidatenzählern und Status. Alle vier Consumer lesen ihn.
Parameter, lokale N+1-Grenze, Gates, Status, Sortierung und Aggregation bleiben
erhalten. Die vorhandene Statusprüfung überspringt bereits die Projektion
bei negativen Textlimits; dafür entsteht kein zusätzlicher Produktguard.

Vierunddreißig gepaarte Fälle umfassen je vollständiger privater Vorstufen-/
Finalsuite 35 Batches und 101 Ergebnisgrids. Das unabhängige native Orakel
prüft alle 40 Werte und Schemafacetten, zehn Textcollations, drei NOT-NULL-
Felder, alle neun Sortierungen, NULL-/0-/positive Limits, QueryId, Hash,
exakte Unicode-/Case-Auswahl, Quell-LIKE und Referenz-LIKE. Fehlende Quellen,
ein fehlender Case-Name sowie negative Zeilen- und Textlimits werden getrennt
bewertet. Der Mixed-Missing-Fall erhält die erfolgreiche eigene Quelle;
die bestehenden Warnungs- und Statusverträge werden unverändert geprüft.
Capturezeiten liegen zwischen getrennten datetime2(3)-Messgrenzen.
Vollständige Consumer-/JSON-Multisets stimmen innerhalb eines Aufrufs überein;
Datenbank-/Plan-/Ausführungstypkeys und bessere globale Ranggrenzen werden
unabhängig geprüft. Alle 14 Metafelder außer der Erzeugungszeit und die
nativen Ausgabeschemas bleiben zwischen Vorstufe und Finalstand gleich.
Caller-LOCK_TIMEOUT 137 bleibt in allen Fällen erhalten.

Das Orakel gewichtet native Durchschnittsrecords mit ihrer Ausführungszahl,
prüft Totals und globale Averages sowie Mikrosekunden→Millisekunden und
Seiten→KB. Die tatsächlich verschiedenen gespeicherten CPU-/Dauerwerte
und 2→8-/2→4-Gewichte unterscheiden gewichtete von ungewichteten Ergebnissen.
Python-Dezimalrundung eines serialisierten Floats weicht an einer gemessenen
Halbgrenze um 0,001 ab; ein unabhängiger nativer SQL-Aggregations-/Konvertierungs-
beobachter prüft deshalb alle 14 numeric-Ausgabewerte exakt. Die Produktquelle
wird dafür nicht verändert. Allgemeine Float-/Rundungsgrenzen sind damit
nicht vollständig belegt. Fenster innerhalb des ersten Intervalls enthalten
dessen ganze Records; ein angrenzendes Fenster enthält nur das zweite und
ein anschließendes Fenster keine Records. Erste und letzte Ausführungszeiten
bleiben native Recordzeiten, ohne zeitanteilige Kürzung.

Plan-Opt-in bestätigt AVAILABLE, ursprüngliche vollständige SC-Zeichen-/
UTF-16-Bytezahlen, natives XML und NULL-Fallback. Ohne Opt-in bleiben
NOT_REQUESTED und sämtliche Planwerte NULL. XML wird für den unabhängigen
Vergleich ohne Entfernen von Textknoten kanonisiert: SqlClient und SQL-
nvarchar verwenden unterschiedliche Leerzeichen vor selbstschließenden
Elementen. Semantische XML-Parität und exakte ursprüngliche Textgrößen sind
belegt; eine allgemeine Serialisierungsbyteparität wird nicht behauptet.

Common177 besteht 14 allgemeine TABLE-/JSON-Fälle, 24 bedingte native
Vollfeld-/Rangfälle, drei Verbraucher, sechs Mappingablehnungen, drei leere
SQL-CONSOLE-Captures und drei direkte positive CONSOLE-/JSON-Statusprüfungen.
Der unabhängige Client bestätigt alle 40 Werte und 41 CONSOLE-Feldfacetten
der positiven Mengen mit 1/2/4 Zeilen. Die Fixtureguard prüft eigene Namen,
Katalogumfang, Tabelle, QI/ANSI, CI-Collation, Optionszustand und die beiden
angrenzenden Intervalle mit ihren Ausführungszahlen. Ohne eigene Fixture
bestehen 14 allgemeine Fälle; der native Block meldet NOT_EXECUTED mit null
Fällen und wird nicht als positiver PASS gezählt.

Zwei positive QueryStoreAnalysis-Aufrufe ausschließlich mit RuntimeStats
bestätigen Limits 1/2, weitergeleitete Fenster, die vollständigen 40 RAW-
Felder, Child-JSON-Parität und EXECUTED auf Ordinal 2. Parent und Child liefern
AVAILABLE mit leeren Warnungsarrays und erhaltenem Caller-Timeout 137.
Alle erfassten nativen Katalog-, Text-, Plan-, Intervall- und Modulwerte bleiben
vor und nach sämtlichen positiven Verträgen und dem Impactlauf exakt gleich.

Die vorhergesagte Auswahl aus Common124/165/177, Integration110/190/196/198
und QueryStore110/121/140 besteht auf CL170 in 29 Batches. Ein erster lokaler
Lauf scheitert unter QI-OFF beim XE-Teil von Common165 mit Fehler 3930.
Der unveränderte Einzeltest besteht mit explizitem QI-/ANSI-ON-Einstieg;
danach besteht die vollständige Auswahl mit demselben privaten Einstieg.
Keine öffentliche Common165-Änderung folgt daraus. Die endgültige Auswahl
wird zusätzlich gegen konkrete Commit-SHAs geprüft. Alle 75 statischen
Prüfungen bestehen am stabilen funktionalen Stand mit Exitcode 0.
Ein unabhängiger Reviewbefund schärft vorher ausschließlich Static1023:
Der Guard prüft die konkrete object_id-SELECT-Projektion; eine Mutation
lässt die CASE-Qualifikation stehen und muss dennoch abgelehnt werden.
OPS-005 ist aus 166 kanonischen Quellen synchronisiert; sein Update und
PLAN-001 bleiben semantisch unverändert. Die anschließenden begrenzten
Dokumentations-, Schreibstil- und Privacyprüfungen bestehen am Lieferstand.

Die UTF-8/LF-Quellidentitäten des geprüften Stands lauten:

| Artefakt | SHA256 |
| --- | --- |
| Source020 | 885470A9920D2747BF29263682681B122291E1B85A8861057913F72A5DAD796E |
| Common177 | 1F1D81A9A44F23B59A2BF3C847E69F0CDCA6D5C14C41676EBC1164ED0DBA08EB |

Beide eigenen Quellen sind identitätsgeprüft entfernt. Container und Volume
des eigenen Labs sind entfernt: zwei Schritte, null Fehler, REMOVED.
Der eigene verschlüsselte temporäre Secretwert ist entfernt. Private Captures
und konkrete Runtimeidentitäten bleiben außerhalb von Git. Mehrere Records
innerhalb desselben Intervalls, weitere Execution Types, mehr als N+1 lokale
vollständige Sortties, positive Memory-/TempDB-/Logwerte, ungültiges Plan-XML,
QS_OFF, Berechtigungen, Timeout, exakte Cross-DB-Referenzlisten, Regex,
ältere native Engines und CL150/160 bleiben unbelegt. COLL-001 bleibt partiell;
Registry, RUNTIME-001 und bestehende Maturityflags bleiben unverändert.

## Query-Store-Status: bestehender gemeinsamer Ergebnisvertrag

Der Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Lab
mit Version 17.0.4075.5, Server-/tempdb-Collation Latin1_General_100_CS_AS
und Frameworkcollation SQL_Latin1_General_CP1_CS_AS. Framework und drei
getrennt identifizierte Unicode-CI_AS-Quellen besitzen gemessene Compatibility
Levels 170. Die Quellen enthalten weder Benutzerobjekte noch Query-Store-
Queries und führen keinen synthetischen Workload aus. Die native Gegenprobe
bestätigt READ_WRITE mit Desired-/Actualstate 2/2, OFF mit 0/0 und explizites
READ_ONLY mit 1/1. IsEnabled/IsWritable lauten entsprechend 1/1, 0/0 und 1/0.
READ_ONLY mit Desiredstate 1 belegt keinen unerwarteten Schreibverlust.

Das vollständig geprüfte Original besitzt bereits eine frühe typisierte
Ergebnisquelle mit 27 Feldern, sieben expliziten Frameworktextcollations
und ausschließlich DatabaseName als NOT-NULL-Spalte. Alle Felder sind ohne
Identity. RAW, JSON, TABLE und aktives CONSOLE lesen dieselbe Ergebnistabelle.
Ein Zeilenlimit, Zeitfenster oder Problemfilter existiert nicht. Kein
Produktfehler wird nachgewiesen; Source010, Signatur, SchemaVersion und
Installersource bleiben unverändert. Ein zusätzlicher Export ist nicht nötig.
Das Inventar beschreibt die sieben vorhandenen Collations nun ausdrücklich.
Procedure- und Bereichsdokumentation korrigieren nur den betroffenen Scope,
die Ausgabeformen sowie unzutreffende Fenster- und Limitangaben.

Die 22 gepaarten Vergleichsfälle umfassen je vollständiger Original-/
Finalsuite 23 Batches und 62 private Ergebnisgrids. Ein unabhängiges natives Orakel prüft alle 27 Werte
einschließlich NULLs, vollständige Typ-/Größen-/Präzisions-/Skalenfacetten,
relative Feldordinale, Nullability, Identity und alle sieben Textcollations.
Der Speicherquotient folgt decimal(9,2); die Warnschwelle verwendet den
ungerundeten Quotienten. Die Cases prüfen die drei tatsächlichen Zustände,
umgekehrte Listen, exakte Unicode-/Case-Auswahl, zwei getrennte LIKE-Scopes,
fehlende Namen, gemischte Auswahl und ungültige Auswahl-/Steuerparameter.
NULL, leerer String und Leerzeichen wählen in diesem eigenen Lab alle vier
sichtbaren Online-Benutzerdatenbanken einschließlich Framework aus.

Alle acht Metafelder außer der Erzeugungszeit sowie Ausgabeschemas bleiben
zwischen Original und Finalstand gleich. Capturezeiten liegen zwischen
getrennten datetime2(3)-Messgrenzen. RAW besitzt 9/27/4 Felder, positives
CONSOLE 28 und leeres CONSOLE drei Felder. JSON erhält seine drei Hauptschlüssel,
alle 27 Datenfelder und vier Warningfelder. Vollständige TABLE-/CONSOLE-/JSON-
Multisets stimmen innerhalb eines Aufrufs überein; RAW und JSON sind nach
DatabaseId geordnet. Fehlende explizite Namen erzeugen DATABASE_NOT_FOUND.
Eine gemischte Auswahl erhält die gültige Menge mit AVAILABLE_LIMITED und
Partialität; ausschließlich fehlende Namen liefern DATABASE_UNAVAILABLE.

Sechs zusätzliche direkte Fälle bestätigen vollständige RAW-Warnungen,
positive und leere CONSOLE-Ausgaben, normalisierte Steuerwerte und das
Zurücksetzen des JSON-Outputs bei deaktivierter Erzeugung. Zwei positive
QueryStoreAnalysis-Aufrufe ausschließlich mit Status bestätigen alle 27
RAW-Felder, Child-JSON-Parität und EXECUTED auf Ordinal 1. Parentlimits 1/2
begrenzen den Statuschild nicht: beide Aufrufe erhalten drei Quellenzeilen.
Caller-LOCK_TIMEOUT 137 bleibt in allen betroffenen Aufrufen erhalten.
Identitäten, vollständige Optionen und Query-Zähler der drei eigenen Quellen
bleiben vor und nach sämtlichen positiven Verträgen und Impactläufen gleich.

Common178 besteht elf allgemeine und 13 bedingte native TABLE-/JSON-Fälle,
zwei Consumer, sechs Mappingablehnungen, drei leere SQL-CONSOLE-Captures und
drei direkte positive CONSOLE-/JSON-Statusprüfungen. Ein unabhängiger Client
bestätigt dabei alle 27 Werte und 28 CONSOLE-Facetten der Mengen mit 3/1/1
Zeilen. Die Fixtureguard prüft eigene Identitäten, CI-Collation, getrennte
CL170-Werte, leere Quellen und die drei tatsächlich gemessenen Zustände.
Ohne Fixture bestehen elf allgemeine Fälle; der native Block meldet
NOT_EXECUTED mit null Fällen und null direkten positiven CONSOLE-Aufrufen.

Der erste neue Commonlauf scheitert mit STATUS_ROWS_FIELDS: Sein Soll zählt
bei einer expliziten Dreierliste zusätzlich die Frameworkdatenbank. Nur die
unabhängige Testauswahl wird auf die drei Fixtureidentitäten begrenzt;
Defaultfälle behalten alle sichtbaren Userdatenbanken. Ein unabhängiger
Review ergänzt danach ausschließlich die Ablehnung doppelter JSON-
Hauptschlüssel. Der finale Commonlauf und Impactlauf bestehen erneut.
Static1024 prüft die 27 Feldverträge, alle Hilfstexte und die vier bestehenden
Consumerquellen; sein tatsächlicher Selftest lehnt 23 Mutationen ab.

Der Selector wählt ausschließlich Common178 ohne weitere Matrixflags.
Dieser Lauf besteht auf SQL Server 2025/CL170 in fünf Batches. Die Auswahl
wird zusätzlich gegen konkrete Commit-SHAs geprüft. Ein erster voller
statischer Lauf scheitert am bytegenauen OPS-005-Installervergleich nach dem
Windowscheckout. Die kanonische Neugenerierung aus 166 Quellen korrigiert
nur die lokale Zeilenendenrepräsentation; Source010, OPS-005 install/update
und PLAN-001 bleiben normalisiert unverändert und erzeugen keinen Git-Diff.
Der isolierte Adaptervertrag und anschließend alle 75 statischen Prüfungen
bestehen. Die anschließenden begrenzten Dokumentations-, Schreibstil- und
Privacyprüfungen bestehen am Lieferstand.

Die UTF-8/LF-Quellidentitäten des geprüften Stands lauten:

| Artefakt | SHA256 |
| --- | --- |
| Source010, unverändert | 0D66DEB0F9BE8A06B28BAA8C1BD040ED8088241D7F10B6DAEBC2DB92607EBEA1 |
| Common178 | 11980BAA535025FEE3944158B0E3776D4C2D67BF0785DFE47395D1B8695EFD95 |

Die drei eigenen Quellen sind identitätsgeprüft entfernt. Container und
Volume des eigenen Labs sind entfernt: zwei Schritte, null Fehler, REMOVED.
Der eigene verschlüsselte temporäre Secretwert ist entfernt. Private Captures
und konkrete Runtimeidentitäten bleiben außerhalb von Git. Unerwartetes
READ_ONLY bei gewünschtem READ_WRITE, ERROR, positive Speicherwarnschwellen,
Berechtigungen, Timeout, Regex, ältere native Engines und CL150/160 bleiben
unbelegt. COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende
Maturityflags bleiben unverändert.

## Intelligent Query Processing: Zustandsvergleiche und gemeinsamer Signalexport

Der Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Lab
mit Version 17.0.4075.5, Server-/tempdb-Collation Latin1_General_100_CS_AS
und Frameworkcollation SQL_Latin1_General_CP1_CS_AS. Framework und zwei
getrennt identifizierte Unicode-CI_AS-Quellen besitzen gemessene Compatibility
Levels 170. Die Quellen enthalten weder Benutzerobjekte noch Query-Store-
Queries: eine Quelle verwendet READ_WRITE mit Capture NONE, die andere OFF.
Für die Fixture wird kein synthetischer Workload ausgeführt oder IQP-Feature gezielt aktiviert.

Das Original liefert bei ausschließlich ausgewählten CI-Quellen ERROR_HANDLED
mit Fehler 4191, DATABASE_UNAVAILABLE und leere Fachmengen. Die drei
Originaldefaultfälle erhalten dagegen Frameworkmengen mit 1/11/1/3 Zeilen,
AVAILABLE_LIMITED und zwei Warnungen zum Kollationsfehler. Achtundzwanzig Auswahl- und
Consumerfälle ergeben 29 Batches und 115 private Grids. Die isolierte native
Diagnose lokalisiert den Fehler im ersten OFF-Vergleich der Zustandsbewertung.
Explizite Framework-CS-Operanden in den sechs Vergleichen auf OFF, READ_ONLY
und READ_WRITE stellen die vier Fachmengen wieder her; ein unabhängiges
natives Orakel bestätigt alle 28 Werte und Typfacetten. Die numerisch
ermittelten Zustände bestimmen Finding und Severity, nicht Produkt-JSON.
Konfigurationsfilter, Versionsgates und Eligibilitylogik bleiben unverändert.

Sechzehn zusätzliche Originalfälle auf der Frameworkquelle ergeben
17 Batches und 68 Grids. Die vollständige native Gegenprobe bestätigt den
Mengenfehler: TABLE und CONSOLE liefern drei Signale, während RAW und JSON
bei Limits 1/2 nur eine beziehungsweise zwei Signalzeilen enthalten. Vier
negative Originalaufrufe mit JSON werfen Fehler 127; der Caller behält
LOCK_TIMEOUT 137, aber die Exception liefert keine gesetzten OUTPUT-Werte.

Die frühe SignalsExport besitzt sechs Felder, drei explizite Textcollations,
fünf NOT-NULL-Felder und keine Identity. EvidenceCount bleibt nullable.
Einmaliges TOP nach DatabaseId und SignalCode wählt die Signale erst nach
vollständiger Status- und Warningbewertung aus. TABLE, aktives CONSOLE, RAW
und JSON verwenden diese Menge. Die drei übrigen RAW-/JSON-Facharrays behalten
ihre unabhängigen Limits; Warnungen bleiben unbegrenzt. Negative Limits
werden ausschließlich im INVALID_PARAMETER-Zweig intern auf null Zeilen
normalisiert. NULL/0 bedeuten weiterhin unbegrenzt. Signatur mit 15 Parametern,
SchemaVersion, Sourceversion, Zeitmodell und registrierter Ergebnisname
signals bleiben unverändert; es gibt kein zusätzliches öffentliches Resultset.

Die 28 Finalfälle ergeben ebenfalls 29 Batches und 115 Grids. Alle vier
Facharrays mit 11/5/6/6 Feldern stimmen vollständig mit nativen Optionen,
elf Konfigurationen je eigener Quelle, einer Automatic-Tuning-Option je
Quelle und drei unabhängig gemessenen Evidenzzählern überein. Alle sechs
Quellsignale sind verfügbar und besitzen EvidenceCount 0; dies belegt weder
aktive PSP-/OPPO-/Feedbacknutzung noch Wirksamkeit. Die Exportfacetten
prüfen relative Ordinale, sysname, Größen, Präzision, Skalen, Nullability,
Identity und alle drei Frameworktextcollations. Positives CONSOLE besitzt
sieben geprüfte Felder, RAW acht Metafelder sowie vier Fachmengen und vier
Warningfelder. JSON erhält sechs Hauptschlüssel und fünf Metafelder; doppelte
Schlüssel werden erkannt. RAW und JSON sind ausdrücklich sortiert, während
TABLE und CONSOLE nur dieselbe geordnet ausgewählte Menge verwenden.
Das vorhandene leere dreifeldrige Helpergrid bleibt erhalten.

NULL, leerer String und Leerzeichen wählen im eigenen Lab alle drei sichtbaren
Online-Benutzerdatenbanken einschließlich Framework aus. Exakte Case- und
Unicodeauswahl, umgekehrte Listen, getrennte LIKE-Scopes, fehlende Namen,
gemischte Auswahl und das High-Impact-Gate bleiben erhalten. Ein OFF-Befund
außerhalb des sichtbaren Ausschnitts erhält AVAILABLE_WITH_FINDING; gemischte
Auswahl liefert AVAILABLE_LIMITED mit Partialität. Acht negative Finalfälle
mit beziehungsweise ohne JSON liefern INVALID_PARAMETER/IsPartial=1 ohne
Fehler 127. Dreizehn weitere Consumerfälle ergeben 14 Batches und 42 Grids.
Zwei positive IQP-only-Parentaufrufe ergeben drei Batches und 20 Grids;
Ordinal 9 übernimmt AVAILABLE_WITH_FINDING, die vier Childarrays und RAW
stimmen bei Limits 1/2 vollständig mit der nativen Auswahl überein.
Caller-LOCK_TIMEOUT 137 bleibt in allen geprüften Aufrufen erhalten.

Common179 besteht 14 allgemeine und 18 bedingte native Fälle, drei Consumer,
sechs Mappingablehnungen und vier leere SQL-CONSOLE-Captures. Ein zusätzlicher
Client prüft die drei direkten positiven CONSOLE-Mengen mit 1/2/6 Zeilen
vollständig einschließlich der Metadaten aller sieben Felder; der positive Commonlauf
liefert fünf Batches und 46 Grids. Der öffentliche native Block erzeugt
weder Quellen noch Benutzerobjekte und verändert keine Datenbankoptionen.
Nach identitätsgesicherter Entfernung der beiden Quellen bestehen 14
allgemeine Fälle; native Fälle und direkte positive CONSOLE-Aufrufe melden
NOT_EXECUTED mit null Fällen. Dieser Lauf liefert fünf Batches und 22 Grids.

Identitäten, native Optionen, Konfigurationen, Tuningoptionen und Zähler
aller drei Datenbanken bleiben vor und nach den direkten positiven Verträgen
gleich. Nach dem Impactlauf bleiben alle zehn Grids der eigenen Quellen
exakt gleich. Im Framework ändern sich aggregiertes PlanFeedback von 3 auf 4
und TuningRecommendations von 0 auf 4; die übrigen nativen Grids bleiben
unverändert. Diese Engineevidenz wird nicht als Quellmutation oder
Wirksamkeitsbeweis ausgegeben. Die 14 impact-basiert ausgewählten Testdateien
bestehen in 36 Batches auf CL170 in 22,4 Sekunden. Der private Lauf setzt
QUOTED_IDENTIFIER und ANSI_NULLS ausdrücklich; das installierte Modul besitzt
beide Optionen. Alle 75 statischen Prüfungen bestehen am stabilen funktionalen
Stand. Static1025 besteht 58 echte Mutationen. Ein Reviewbefund präzisiert
nur die dokumentierte Auswahlordnung. OPS-005 ist aus 166 kanonischen Quellen
synchronisiert; sein Update und beide PLAN-Artefakte bleiben normalisiert
unverändert. Eigene Quellen, Lab und Secretwert sind entfernt.

Die abschließenden Dokumentations-, Schreibstil- und Privacyprüfungen bestehen
am Lieferstand. Aktive IQP-Wirkung, positive Varianten-/Feedbackzähler der eigenen
Quellen, unerwartetes READ_ONLY, Berechtigungen, Timeout, ältere native Engines
und CL150/160 bleiben unbelegt. Der begrenzte Nachweis schließt weder COLL-001
noch einen Maturity- oder bestehenden Statusflag. Private Captures, lokale
Runtimeidentitäten und Umgebungsdaten verbleiben außerhalb des Repositorys.

Eingefrorene normalisierte SHA256-Werte: Source090
`960BBA39990925119E94CD93708663F0EA0D251B529E1E08F07570078153EF22`, Common179
`7E93E4B20235B0496A7F8BBD09161D9D22E6C5593CD756E0AC575F7D5D2C5DD3`, Static1025
`88C52AE46FFCF9D5B329C84BB8FC5881E8597B7C2D2549D902B762361A8D7C99`.

## Query-Store-Replica-Analyse: negative Limits und selektive TABLE-Zuordnungen

Der Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Lab
mit Version 17.0.4075.5, Server-/tempdb-Collation Latin1_General_100_CS_AS
und Frameworkcollation SQL_Latin1_General_CP1_CS_AS. Framework und zwei
getrennt identifizierte Unicode-CI_AS-Quellen besitzen gemessene Compatibility
Levels 170. HADR ist nativ deaktiviert. Jede eigene Quelle enthält eine
synthetische Tabelle mit drei Zeilen und eine Procedure; zwei beziehungsweise
drei Ausführungen liefern je eine eingefrorene Runtimegruppe. Query Store
verwendet danach READ_ONLY mit Capture NONE und eingeschaltetem Wait-Capture.

Native Katalogabfragen liefern vier vorhandene Rollenmetadaten je Quelle und
Runtimewerte ausschließlich für Gruppe 1. Diese Katalogzeilen belegen keine
AG-, Geo-, Failover- oder lesbare Secondary-Topologie. Rollenliterale prüfen
den bestehenden Produktvertrag anhand nativer Codes; ein ReplicaName wird
nicht als tatsächliche aktuelle Rolle interpretiert. Waits und Forcing-Locations
sind nativ leer und werden nicht als positive Aggregationsnachweise verbucht.

Das Original besitzt bereits elf lokale Tabellen mit 55 expliziten
Textcollations und sieben gemeinsame Resultsets. Die Schemas mit
17/15/21/19/14/13/6 Feldern umfassen insgesamt 105 Felder und 45 Textfelder.
Vier RAW- und vier TABLE-Originalfälle bestätigen vollständige Typfacetten,
native 15-Feld-Katalog- und 21-Feld-Runtimewerte, NULLs und JSON-Parität.
Die TABLE-Gegenprobe ergibt fünf Batches und 64 private Grids. Relative
Ordinale, sysname, Größen, Präzision, Skalen, Nullability, Identity und alle
45 Frameworktextcollations werden unabhängig geprüft. SourceOrdinal und
WarningOrdinal besitzen im RAW die bestehende Identity-Eigenschaft; die
TABLE-Brücke übernimmt die Werte ohne Identity.

Drei tatsächliche Ausgabeprobleme werden gezielt korrigiert. Das negative
Original-Limit liefert INVALID_PARAMETER, aber vier wahre HasMore-Flags
bei leeren Fachmengen. Gültige TABLE-Zuordnungen behalten bei ungültigen
Parametern das Dummy-Schema. Außerdem hält SELECT bei einer fehlenden
Zuordnung den vorherigen Zielwert fest: neun von elf positiven Teilmappings
werfen nativ 51010 mit TARGET_SCHEMA_MISMATCH. Sieben einzelne Zuordnungen
und vier Mehrfachzuordnungen ergeben zwölf Batches und 176 Grids; warnings
allein sowie sourceStatus zusammen mit warnings bestehen bereits im Original.
Ein erster nicht abgefangener Clientversuch zeigt denselben Fehler und wird durch die
anschließende abgefangene Originalgegenprobe eingegrenzt.

Internes Limit 0 ausschließlich im negativen INVALID_PARAMETER-Zweig,
frühes TABLE-Prepare und sieben skalare SET-Zuweisungen beheben diese Grenzen.
Nicht zugeordnete Ergebnisse setzen den internen Zielwert auf NULL und lösen
keinen Writer aus. Angeforderte Ziele erhalten auch bei ungültigen Parametern
das vollständige Schema. RequestedMaxRows bleibt unverändert negativ,
die vier HasMore-Flags werden false. LocalLimit, Major-/Katalog-/Permission-
Gates, Rollenfunktion, Mappingbewertung und fachliche Abfragen bleiben
unverändert. Die Signatur besitzt weiterhin 18 Parameter; SchemaVersion und
Sourceversion ändern sich nicht, und es entsteht kein neues Resultset.

Die achtundzwanzig gepaarten Vergleichsfälle umfassen je vollständiger
Original-/Finalsuite 29 Batches und 197 private Ergebnisgrids. RAW, TABLE,
CONSOLE und NONE erhalten dieselben Fachmengen
bei NULL/0/1/2, exakter Unicode-/Case-Auswahl, Replica-Filtern, leerem
Zeitfenster und fehlender oder gemischter Datenbankauswahl. Eine falsche
private Duplikatannahme wird anhand des Originals korrigiert: doppelte
exakte Datenbanknamen liefern INVALID_PARAMETER ohne zusätzliche Partialität.
Der Vergleich bestätigt alle 105 nativen Feldfacetten, acht JSON-Hauptschlüssel,
13 Metafelder, vollständige NULL-Properties und doppelte Schlüsselkontrolle.
Alle 13 Quellenstatusfelder werden gegen fünf unabhängige Quellcodes je
Datenbank und die nativen Sammlungsmengen 1/4/1/0/0 geprüft. Modulzähler
beschreiben die begrenzte Ausgabe; Quellenzähler bleiben vor dem globalen Limit.

Acht negative Consumerfälle, sechs Mappingablehnungen mit 51011 und zwei
Replica-only-Parentaufrufe ergeben 17 Batches und 80 Grids. Der Parent übernimmt
AVAILABLE auf Ordinal 8; Child-JSON und die sieben RAW-Schemas stimmen bei
Limits 1/2 vollständig überein. Alle elf positiven Teilmappings bestehen
nach der Reparatur. Elf zusätzliche negative Teilmappings ergeben zwölf
Batches und 165 Grids. Angeforderte Schemas und JSON bleiben korrekt;
nicht zugeordnete Dummytabellen behalten ihre Sentinelzeilen. Caller-
LOCK_TIMEOUT 137 bleibt in diesen Rand-, Teilmapping- und Parentfällen erhalten.

Common180 besteht 14 allgemeine und 18 bedingte native Fälle, neun allgemeine
und neun native selektive TABLE-Zuordnungen, fünf Consumer, sechs Preflights
und drei SQL-captured Invalid-CONSOLE-Fälle. Drei direkte positive CONSOLE-
Aufrufe prüfen im Test Status und JSON; ein unabhängiger Client bestätigt
zusätzlich sämtliche 18 CONSOLE-Facetten und Werte des Modulstatus mit Label.
Der positive Commonlauf ergibt vier Batches und 44 Grids. Der erste Lauf
scheitert an einem Test-EXCEPT zwischen JSON-Schlüsseln und tempdb-Katalognamen;
beide Seiten erhalten explizites BIN2. Danach scheitern sechs dynamische
Replica-Gruppenvergleiche an der CI-/Frameworkgrenze; beide Operanden werden
nur im Test explizit Framework-CS. Eine private Diagnose bestätigt Zeilen 14
und 30 des dynamischen Orakels. Source bleibt durch beide Testkorrekturen
unverändert. Eine private Variablenüberschattung und unterschiedliche
Offset-Zeitdarstellungen werden ausschließlich im Clientprüfer korrigiert.

Alle 13 nativen Grids der eigenen Quellen bleiben vor und nach den direkten
Verträgen sowie nach dem Impactlauf exakt gleich. Neun ausgewählte Testdateien
bestehen auf CL170 in 27 Batches und 25,7 Sekunden. Der private Einstieg setzt
QUOTED_IDENTIFIER und ANSI_NULLS ausdrücklich. Nach identitätsgesichertem
Cleanup der beiden Quellen besteht Common180 in vier Batches und zwölf Grids
mit 14 allgemeinen Fällen, neun selektiven Zuordnungen, fünf Consumern, sechs
Preflights und drei Invalid-CONSOLE-Captures. Der positive Block meldet
NOT_EXECUTED mit null Fällen und ohne gemessene Source-Compatibility-Levels.

Alle 75 statischen Prüfungen bestehen am stabilen funktionalen Stand.
Static1030 besteht 448 echte Mutationen über feldbezogene DDL-, Collation-,
Invalid-, Preflight-, Lookup- und Consumergrenzen. Der unabhängige Source-
und anschließende Sieben-Dateien-Review besitzen keine offenen Befunde.
OPS-005 ist aus 166 kanonischen Quellen synchronisiert; sein Update, beide
PLAN-Artefakte und TVF005 bleiben normalisiert unverändert. Sieben Inventarzeilen
ergänzen ausschließlich die 45 bereits vorhandenen Textcollations. Container
und Volume des eigenen Labs sind in zwei Schritten ohne Fehler entfernt;
der eigene verschlüsselte temporäre Secretwert ist entfernt.

Die abschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen
bestehen am Lieferstand. Positive Wait-/Forcing-Aggregation und deren
Limitwirkung, echte AG-/Geo-/Secondary-/Failover-Evidenz, fehlende Rollenmetadaten,
weitere Zustände, Berechtigungen, Timeout, ältere native Engines und CL150/160
bleiben unbelegt. COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende
Maturityflags bleiben unverändert. Private Captures, Runtimeidentitäten und
Umgebungsdaten verbleiben außerhalb des Repositorys.

Eingefrorene normalisierte SHA256-Werte: Source100
`724194A1F02A38EF6EECB4EFD37491FAE341EDB7E4F442498EC0381A926A8F9A`, Common180
`3F303E144103825C30E94C121A8DE343F7B52319D5BAA28EE971D79570BD0AC6`, Static1030
`7C156F844E3889B84753A0869F5EFE050EE6E77487CF44A4EB018E0A48777586`.

## Query-Hash-Analyse: Ressourcenrang und kontrollierte negative Textlimits

Der Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Lab
mit Version 17.0.4075.5, Server-/tempdb-Collation Latin1_General_100_CS_AS
und Frameworkcollation SQL_Latin1_General_CP1_CS_AS. Framework und die eigene
Unicode-CI_AS-Quelle besitzen gemessene Compatibility Levels 170. HADR ist
nativ deaktiviert; Query Store bleibt in der Quelle ausgeschaltet. Eine
synthetische Tabelle enthält vier Zeilen. Drei eigene Procedures werden
zwei-, drei- und viermal ausgeführt und liefern drei getrennte Cachezeilen.
Jede besitzt einen Hash, eine Planvariante und einen Handle. Das belegt keine
historische Planvielfalt oder positive native Write-/Spillwerte.

Das Original besitzt bereits drei lokale Tabellen mit 16/15/20 Feldern.
Die gemeinsame Ausgabe hat zehn NOT-NULL-Felder, einen explizit Framework-CS
collatierten Text und keine Identity. RAW, TABLE, aktive CONSOLE und JSON
verwenden diese vorhandene Menge. Die 15 Parameter, Sourceversion 2.1.0 und
SchemaVersion 1 bleiben unverändert; es entsteht kein neuer Export.

Zwei native Originalfehler werden gezielt korrigiert. TOP begrenzt die
Hashaggregation vor einer ausdrücklich geordneten Auswahl und kann dadurch
eine andere Menge als den angeforderten Ressourcenrang wählen. Drei
synthetische und vierzehn native Originalfälle zeigen falsche Rangmengen.
ORDER BY rn begrenzt nun nach dem vorhandenen Ressourcenwert und
LastExecutionTime. Vollständig gleiche Sortschlüssel erhalten keinen neuen
Tiebreaker. RAW und JSON sortieren die gewählte Menge ausdrücklich; TABLE
und aktive CONSOLE garantieren keine Anzeigeordnung.

Negative Textlimits werden bereits als INVALID_PARAMETER erkannt, rufen im
Original anschließend aber den Unicode-Helper mit negativem Grenzwert auf.
Vier Originalfälle je Suite werfen 51021. Ein einzelner Projektionsguard
erhält den kontrollierten leeren Status und die vollständigen TABLE-Schemas.
NULL/0-Limits bleiben unbegrenzt. Aggregationen, ganzzahlige Zwischenrechnung
der CPU-/Elapsed-Durchschnitte, Mindestfilter, Hashfilter, Sampleauswahl,
Gatepolitik und Snapshotpfade bleiben unverändert.

Je dreißig synthetische und native Fälle vergleichen Original und Finalstand.
Die synthetische Originalsuite ergibt 31 Batches und 99 private Grids, die
native 31 Batches und 100 Grids. Final ergeben sie 31/102 beziehungsweise
31/103 Batches/Grids. Ein unabhängiger Client prüft sämtliche 20 Werte und
Typfacetten einschließlich Größen, Präzision, Skalen, Nullability und Identity.
RAW besitzt neun Statusfelder, positive CONSOLE 21 Felder mit Label und die
leere CONSOLE drei bestehende Felder. TABLE-Katalogfacetten, alle sieben
Ressourcenränge, NULL/0/1/2-Limits und beide negativen Limits werden geprüft.
JSON behält drei Hauptschlüssel, neun Metafelder, vollständige NULL-Properties
und das leere Warningsarray; doppelte Schlüssel werden zurückgewiesen.

Vierzig Zusatzfälle ergeben 42 Batches und 125 Grids. Exakte Hashauswahl,
Mindestfilter, ungültige Parameter, sechs Mappingablehnungen mit 51011 und
unveränderten Sentinelzielen sowie der tatsächlich fehlende Snapshot mit 208
werden geprüft. Zwei positive Parentaufrufe bestätigen Child-Parität auf
Ordinal 2: ein einzelner Hashchild liest frisch, QueryStats zusammen mit
Hashanalyse verwendet REUSED_PARENT_SNAPSHOT. Acht separate Unicode-
Grenzfälle ergeben neun Batches und 25 Grids. Unabhängige UTF-16-Byteoffsets
und Codepointzählung bestätigen den 66 Zeichen und 134 Bytes langen eigenen
SUM-Text; Limits 30/31 liegen vor beziehungsweise einschließlich des Emoji.
Weitere acht Gatefälle in neun Batches und 33 Grids bestätigen fünf blockierte,
zwei erlaubte und einen ungültigen Pfad mit vollständiger RAW-/JSON-Parität.
Caller-LOCK_TIMEOUT 137 bleibt in den Zusatz-, Parent-, Unicode- und Gatefällen.

Private Prüfharnessfehler werden ohne Produktänderung korrigiert. Ein eigener
15-Feld-Snapshot kollidiert beim tatsächlichen Parentaufruf mit dessen
37-Feld-Snapshot und führt zu 213; die eigene Temp-Tabelle wird vorher entfernt.
Ein wörtlicher GO-Split übersieht eingerückte Trenner und erzeugt doppelte
Temp-Tabellen; der private Split verwendet danach vollständige GO-Zeilen.
Die Annahmen zu TABLE-Anzeigeordnung und leerer CONSOLE werden anhand der
vorhandenen Verträge korrigiert. Anschließend bestehen die vollständigen
Sollwertprüfungen; keine Rangabweichung des Originals wird als Erfolg gewertet.

Common181 besteht 27 allgemeine und 20 bedingte native Fälle, drei Consumer,
sechs Preflights und drei SQL-captured leere CONSOLE-Fälle. Sein unabhängiges
Schema- und Vollzeilenorakel prüft alle 20 Felder, BIN2-Häufigkeitsparität und
zulässige bestehende Sortties. Der native Block liest nur eigene vorhandene
Cachezeilen und erzeugt keinen Workload. Der positive Lauf ergibt drei Batches
und drei Grids. Acht impact-basierte Testdateien bestehen auf CL170 in
25 Batches und 15,6 Sekunden mit explizitem QI-/ANSI-ON-Einstieg.

Alle 90 Felder und Schemafacetten der drei eigenen Cachezeilen bleiben vor
und nach direkten Prüfungen sowie nach dem Impactlauf exakt gleich. Auch
Datenbankidentität, Optionen und vier Tabellenwerte bleiben gleich. Nach
identitätsgesichertem Fixture-Cleanup besteht Common181 in drei Batches und
drei Grids mit 27 allgemeinen Fällen; der native Block meldet NOT_EXECUTED
mit null Fällen und ohne gemessenen Source-Compatibility-Level.

Alle 75 statischen Prüfungen bestehen am stabilen funktionalen Stand.
Static1036 besteht 173 echte Mutationen über feldbezogene DDL-, Rang-,
Projektions-, Snapshot- und Consumergrenzen. Der erste vollständige Lauf
meldet in Static950 den kontrollierten Test-Snapshot als zweiten Erzeuger.
Eine Ausnahme ausschließlich für Source060/Common181 verlangt Fremdtabellenschutz
vor Anlage sowie eigenes Erfolgs-/CATCH-Cleanup; gewöhnliche Namenskollisionen
bleiben Fehler. Neun Ownershipmutationen und acht Kollisionsfälle bestehen.
Eine anfängliche Windows-Pfadabweichung im lokalen Validatorlauf wird vor
dem erfolgreichen Wiederholungslauf korrigiert. Source und Common bleiben
unverändert. Unabhängiger Source-, Sieben-Dateien- und ergänzender Validator-
Review besitzen keine offenen Befunde. OPS-005 ist aus
166 kanonischen Quellen synchronisiert; sein Update und beide PLAN-Artefakte
bleiben normalisiert unverändert. Eine Inventarzeile ergänzt ausschließlich
die bereits vorhandene Textcollation. Container und Volume des eigenen Labs
sind in zwei Schritten ohne Fehler entfernt; der eigene verschlüsselte
temporäre Secretwert ist entfernt.

Die abschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen
bestehen am Lieferstand. Mehrere tatsächliche native Varianten je Hash,
positive native Writes/Spills, allgemeine Rundungs- und Sorttiegrenzen,
Cache-Eviction, Berechtigungen, Timeout, ältere native Engines und CL150/160
bleiben unbelegt. COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende
Maturityflags bleiben unverändert. Private Captures, Runtimeidentitäten und
Umgebungsdaten verbleiben außerhalb des Repositorys.

Eingefrorene normalisierte SHA256-Werte: Source020
`E45385E1A65FDDDF2CCB110E4B0F6B043E486D4802A0AEC9DFB295B06EA3978B`, Common181
`1C4DF97A58AF561181431C4D79D9F1B53C084CBD24FEA23E1BD5D53FBC7D2D42`, Static1036
`4404AC73FCF20ECD4D629014289C8EF24AA46AFFF8518F428AB8E2E51DE3982E`.

## QueryStats: gemeinsames Zeilenlimit und vollständiger Feldvertrag

Der Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Lab
mit Version 17.0.4075.5. Server und tempdb besitzen Latin1_General_100_CS_AS,
das Framework SQL_Latin1_General_CP1_CS_AS. Framework und eigene Unicode-
CI_AS-Quelle besitzen gemessene Compatibility Levels 170. HADR ist deaktiviert,
Query Store bleibt in der Quelle ausgeschaltet. Die eigene Tabelle enthält
vier Werte; drei eigene Procedures werden zwei-, drei- und viermal ausgeführt.
Die Ausgangsmessung enthält drei Procedurezeilen und drei Ad-hoc-Zeilen auf
fünf Plänen. Bei den Ad-hoc-Zeilen ist die Text-Datenbank-ID NULL; das vorhandene
Planattribut löst die Quelldatenbank auf.

USP_QueryStats besitzt bereits drei lokale Tabellen mit 10/3/60 Feldern.
Der gemeinsame Resultvertrag hat fünf explizite Frameworktextcollations,
29 NOT-NULL-Felder und keine Identity. RAW und JSON projizieren 59 Fachfelder
ohne SortValue. Aktive positive CONSOLE liefert 61 Felder mit Ergebnislabel,
leere CONSOLE den bestehenden Dreifeldvertrag. TABLE enthält 60 Felder.
Die 22 Parameter, Sourceversion 2.1.0, TABLE-SchemaVersion 2 und JSON-
SchemaVersion 1 bleiben unverändert. Es entsteht kein zusätzlicher Export.

Das Original sammelt bei positivem Limit bis zu Limit plus eins. RAW und JSON
begrenzen danach ausdrücklich; TABLE und aktive CONSOLE liefern dagegen die
zusätzliche Zeile. Vier Originalfälle belegen bei Limits 1/2 jeweils 2/3
TABLE-/CONSOLE-Zeilen gegenüber 1/2 RAW-/JSON-Zeilen. Sechs neue Sourcezeilen
begrenzen die gemeinsame Tabelle nach SortValue DESC und LastExecutionTime DESC.
Textprojektion, Trunkierungswarning, RowCount und HasMoreRows werden davor
bewertet. N+1-Zähler, dreizehn Rangmetriken, Rundung, Filter und Gatepolitik
bleiben erhalten. Vollständig gleiche Sortschlüssel erhalten keinen neuen
Tiebreaker; TABLE und aktive CONSOLE versprechen keine Anzeigeordnung.
Negative Text- und Zeilenlimits liefern bereits kontrolliert INVALID_PARAMETER.

36 unveränderte Originalfälle ergeben 37 Batches und 136 private Grids.
Ein unabhängiger Client vergleicht sämtliche 59 öffentlichen Werte gegen
sechs aufgelöste native Cachezeilen, SQL-/ADO-Facetten für TABLE und CONSOLE,
dreizehn Ränge, NULL/0/1/2-Limits und negative Parameter. RAW behält neun
Statusfelder, JSON drei Hauptschlüssel, zehn Metafelder, vollständige
NULL-Properties und leere Warnings. Doppelte JSON-Schlüssel werden abgelehnt.

Smoke- und Beobachtungsabfragen vergrößern den flüchtigen Cache. Deshalb
verwenden zusätzliche gepaarte Original-/Finalmessungen einen stabilen
Batchtextscope über genau die drei eigenen Procedures. Je 36 native Fälle
ergeben 37 Batches und 136 Grids. Sämtliche Werte und Facetten bestehen;
die vier Original-Limitabweichungen fehlen im Finalstand. Ergänzend liefern
private 37-Feld-Snapshots drei synthetische Zeilen mit unterschiedlichen
CPU-, Elapsed-, Read-, Write-, Grant-, Spill- und Rowwerten sowie null
Ausführungen. Je 36 Original-/Finalfälle ergeben 38 Batches und 136 Grids.
Das bestätigt insbesondere ganzzahlige CPU-/Elapsed-Zwischenrechnung,
NULL-Durchschnitte und Ranggrenzen. Live-Text-, Cache- und Attributauflösung
bleibt getrennt; diese Mischung belegt keine atomare Snapshotmetadatenmessung.

59 Zusatzfälle ergeben 60 Batches und 186 Grids. Alle vier Consumer bestätigen
Textlimits NULL/0/30/31 und exakte QueryHash-, QueryPlanHash-, SqlHandle- und
PlanHandlefilter. Der eigene SUM-Text besitzt 66 Codepoints und 134 Bytes;
30/31 liegen vor beziehungsweise einschließlich des Emoji. Unabhängige
UTF-16-Byteoffsets erhalten den Unterschied zwischen Statement- und Batchtext.
Mindest-, Zeit-, case-sensitive LIKE- und Regexfilter, ungültige Parameter,
fehlende Datenbanken und vollständige Auswahlwarnings bestehen. Sechs
Mappingablehnungen werfen 51011 und erhalten Sentinelziele. Zwei echte
Parentaufrufe bestätigen Child-Parität auf Ordinal 1 mit EXECUTED und
REUSED_PARENT_SNAPSHOT. Ein tatsächlich fehlender Snapshot liefert kontrolliert
208. Acht Gatefälle ergeben neun Batches und 39 Grids: vier Deep-Pfade
blockieren, drei Current-Pfade sind erlaubt und ein NULL-Bestätigungsflag ist
ungültig. Caller-LOCK_TIMEOUT 137 bleibt in diesen Prüfungen erhalten.

Common182 besteht 29 allgemeine und 28 native Fälle, drei Consumer, sechs
Preflights, drei leere SQL-CONSOLE-Captures und drei direkte native CONSOLE-
Aufrufe. Die Clientmessung bestätigt dabei 61 Felder und 1/2/3 Zeilen.
Der native Test liest ausschließlich die vorbereitete eigene Fixture.
Eine überzählige Klammer im neuen Test wird nach dem ersten Parsefehler
entfernt. Der escaped CREATE-Prefix verhindert, dass Beobachterliteraltexte
den Produktfilter selbst treffen. Ein zusätzlicher Guard zählt ohne
ObjectId-Vorfilter genau drei passende Cachezeilen. Es entsteht kein weiterer
Parent-Snapshot-Erzeuger und keine Erweiterung der Static950-Ausnahme.

Acht impact-basierte Testdateien bestehen auf SQL Server 2025 und CL170
in 25 Batches. Ein erster Lauf scheitert an Common165-Metadatenprüfung 56904.
Eine private Gegenprobe ergänzt ausschließlich Diagnoseausgaben und besteht
alle 48 Orchestratorfälle bei aktiven Assertions. Der vollständige unveränderte
Impactlauf besteht anschließend. Für den ersten Fehler ist keine Ursache
nachgewiesen; eine allgemeine Aussage über seine Wiederholbarkeit entfällt.
Alle 75 statischen Prüfungen bestehen am stabilen funktionalen Stand;
Static1029 besteht 274 echte DDL-, Rang-, Auswahl- und Consumermutationen.
Der unabhängige funktionale Review besitzt keine offenen Befunde.

Die sechs ursprünglich aufgelösten Zeilen bleiben nach den Prüfungen in allen
92 nativen Feldern exakt erhalten. Dasselbe gilt für die fünf Cacheplanzeilen
mit sechs Feldern, 18 Planattribute, Datenbankidentität und vier Tabellenwerte.
Die drei Procedurezeilen stimmen zusätzlich mit allen 90 Feldern der ersten
Fixturemessung überein. Weitere Analysecachezeilen werden als Beobachtungs-
aktivität erfasst und nicht als unveränderlicher Gesamtsnapshot behauptet.
Nach identitätsgeprüftem Fixture-Cleanup besteht Common182 in drei Batches
und 27 Grids mit 29 allgemeinen Fällen. Der native Block meldet NOT_EXECUTED,
null native Fälle und keinen gemessenen Source-Compatibility-Level.
Eigener Container und Volume werden in zwei Schritten ohne Fehler entfernt;
der verschlüsselte temporäre Secretwert ist entfernt.

OPS-005 ist aus 166 kanonischen Quellen synchronisiert. Sein Update und beide
PLAN-Artefakte bleiben normalisiert unverändert. Eine bestehende Inventarzeile
ergänzt ausschließlich die fünf bereits vorhandenen Textcollations. Die
Procedure- und Bereichsdokumentation präzisiert den tatsächlichen TOP-100-
Default und Regex vor Materialisierung sowie die bestehenden Feldunterschiede.
Die abschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen
bestehen am Lieferstand. Allgemeine Rundungs-/Sorttiegrenzen, Eviction,
positive native Writes/Spills/Grants im stabilen Procedurescope, Berechtigungen,
Timeout, ältere native Engines und CL150/160 bleiben unbelegt. COLL-001 bleibt
partiell; Registry, RUNTIME-001 und bestehende Maturityflags bleiben unverändert.
Private Captures, Runtimeidentitäten und Umgebungsdaten liegen außerhalb des
Repositorys.

Eingefrorene normalisierte SHA256-Werte: Source010
`92A188803DCECF928FF6FD6673D3E74E6FCCA48558BAC522B24B618F71E33F53`, Common182
`F44B9E20C4C493CF2F304A1147B47BF3CF2495641EE0A18632B6417F56BB80CE`, Static1029
`ADA0E754C3611BA22364CF11E51A4DE0B8CBE726E6DF9EFEB5B0448D6549E6B4`.


## CurrentMemoryGrants: gemeinsames Zeilenlimit und vollständiger Feldvertrag

Der begrenzte Nachweis vom 7. Oktober 2026 verwendet ein eigenes gemischtes
SQL-Server-2025-Dockerlab mit gemessenem Build 17.0.4075.5 und CL170.
Server und tempdb verwenden Latin1_General_100_CS_AS, das Framework
SQL_Latin1_General_CP1_CS_AS. Eine eigene Unicode-CI-Quelle auf CL170 enthält
50.000 synthetische Sortzeilen. Drei eigene Sortrequests halten tatsächlich
gewährte Grants durch zurückgehaltenen Clientkonsum sichtbar. Eine vorherige
Sperrprobe wartet bereits vor Grantzuteilung und liefert keinen positiven
Grantnachweis; die erste kleinere Resultmenge wird vollständig gepuffert.
Der begrenzte größere Clientfall liefert die drei positiven Grants.

USP_CurrentMemoryGrants besitzt zehn lokale Tabellen mit 125 Feldern und
19 expliziten Textcollations. Der gemeinsame Fachvertrag hat 63 Felder,
neun Textcollations, zwei NOT-NULL-Felder und keine Identity. RAW enthält
zwölf Statusfelder und 63 Fachfelder, TABLE ebenfalls 63 Fachfelder;
aktive CONSOLE besitzt 64 Felder einschließlich Label, leere CONSOLE drei.
JSON erhält drei Hauptschlüssel, 15 Metafelder und sämtliche NULL-Properties.
Die 15 Parameter, Sourceversion 3.0.0, SchemaVersion 2 und Parentvertrag 2
bleiben unverändert. Es entsteht kein zusätzlicher Export oder Snapshotowner.

Das unveränderte Original hält bis zu Limit plus eins vor. Bei Limits 1/2
geben TABLE und CONSOLE jeweils 2/3 Zeilen gegenüber 1/2 RAW-/JSON-Zeilen aus.
Sieben Sourcezeilen schneiden die gemeinsame Tabelle nach IsWaiting DESC,
RequestedMemoryMb DESC, WaitTimeMs DESC, SessionId und RequestId zu.
Textprojektion, Trunkierungswarning, CandidateRowCount, RowCount und
HasMoreRows bleiben davor. Die bestehende Kandidatenordnung nach rohen KB
und die anschließende Ausgabeordnung nach gerundeten MB bleiben erhalten.
Negative Zeilen- und Textlimits liefern bereits kontrolliert INVALID_PARAMETER.

Eine native Erfassung liefert drei Grants, Sessions und Requests sowie
Workload-Gruppen, Pools, Semaphores und SQL-Text. Der private Client friert
diese nacheinander erfassten Quellen für wiederholbare Parentvergleiche ein;
die Erfassung ist kein atomarer Serverzustand. Je vollständiger Original- beziehungsweise Finalsuite ergeben 24 Fälle
26 Batches und 49 Grids. Ein unabhängiges 63-Feld-Orakel berechnet
Größen und Prozentwerte aus ungerundeten KB, korreliert sämtliche Identitäten
und extrahiert Text mit UTF-16-Offsets. Alle Werte und nativen Schemafacetten
bleiben erhalten; die vier Original-Limitabweichungen fehlen im Finalstand.
Ein früherer privater LIKE-Filter ließ eigene Sessionzeilen unter der
Frameworkcollation aus. Exakte Session-IDs korrigieren ausschließlich den
Beobachter; Original und Final werden mit allen drei Sessionidentitäten
erneut verglichen. Frühere Captures bleiben getrennte Diagnoseunterlagen.

Je vollständiger synthetischer Original- beziehungsweise Finalsuite ergeben
60 Fälle 62 Batches und 121 Grids. Sie prüfen wartende und gewährte Grants, KB 2050/2051 mit gleicher
MB-Rundung und entgegengesetzter Wartezeit, NULL-/Nullnenner, fehlende
Joinquellen, Mindestfilter, Sessionlisten und die bestehenden NULL-Flags.
Weitere 60 Finalfälle prüfen einen kontrollierten Unicode-Text mit
Emoji-Grenze bei 17/18 Zeichen und abschließenden Leerzeichen. Diese Werte
sind synthetisch und werden nicht als tatsächlich wartende Nativegrants
bezeichnet. Alle vier Ausgabeformen erhalten die vollständige 63-Feld-Parität.

Zwölf Zusatzfälle bestehen in 14 Batches und 28 Grids. Zwei tatsächliche
CurrentOverview-Aufrufe liefern begrenzte positive Childmengen auf Ordinal 60
mit vollständiger TABLE-/Child-JSON-Parität und gemeinsamer Snapshot-ID.
Drei ungültige Parentidentitäten liefern 51020; fünf ungültige Sessionlisten
liefern INVALID_PARAMETER. SQL_TEXT-Partialität bleibt auch bei deaktiviertem
Text erhalten. Fehlen sämtliche SourceStatuszeilen, bleibt die bestehende
NULL-Partialität erhalten. Caller-LOCK_TIMEOUT 137 wird wiederhergestellt.

Common183 besteht 14 allgemeine und 18 native TABLE-/JSON-Fälle, drei Consumer,
sechs Mappingablehnungen, drei leere SQL-CONSOLE-Captures und drei direkte
positive CONSOLE-Aufrufe. Der positive Block liest nur die ausdrücklich über
SESSION_CONTEXT vorbereiteten drei eigenen Sessions. Ein erster Testlauf
scheitert am BIN2-/SC-Konflikt zweier Text-CASE-Arme; deren explizite
Frameworkcollation repariert ausschließlich den Test. Ein weiterer Lauf
scheitert an der Vorher-/Nachher-Klammer globaler Semaphorewerte. Private
Diagnoseausgaben bei aktiven Assertions zeigen vorübergehende Beobachtergrants.
Neun ausdrücklich benannte globale Pool-/Semaphorezahlen besitzen deshalb
keinen Cross-call-Werte- oder Klammernachweis. NULL-/Typform und numerische
Konvertierbarkeit bleiben geprüft; die übrigen 54 Felder behalten exakte
nichtnumerische Vergleiche beziehungsweise numerische Messklammern.
Alle 63 TABLE-/JSON-Felder werden innerhalb desselben Aufrufs verglichen.
Die vollständigen privaten eingefrorenen Orakel bleiben davon unabhängig.
Ein zusätzlicher Client bestätigt alle 64 CONSOLE-Facetten gegenüber dem
Original und sämtliche 63 JSON-Fachwerte bei 1/2/3 ausgegebenen Zeilen.

Zehn impact-basierte Testdateien bestehen auf CL170 in 30 Batches.
Alle 75 statischen Prüfungen bestehen am stabilen funktionalen Stand;
Static1026 besteht 457 echte Feld-, Collation-, Grenz- und Auswahlmutationen.
Der unabhängige funktionale Review besitzt keine offenen Befunde.

Vor und nach den Prüfungen bleiben Datenbankidentität, Optionen und vier
Aggregate der 50.000 eigenen Tabellenzeilen exakt gleich. Drei Grantzeilen
behalten 17 stabile native Felder sowie die drei Sessionidentitätsfelder.
Laufzeit- und globale Speicherwerte bleiben veränderlich. Der Parentcollector
enthält einen getrennten offenen Fehler: SESSIONS meldet CapturedRowCount 0
trotz mindestens drei tatsächlich erfasster eigener Sessions, weil der
bestehende Collector an dieser Stelle WorkloadGroups zählt. Dieser Slice
ändert den Collector nicht; dessen Quellenzähler benötigen einen eigenen
abgegrenzten Vertrag und eine gezielte Reparatur.

Nach identitätsgeprüftem Fixture-Cleanup besteht Common183 in drei Batches
und drei Grids mit 14 allgemeinen Fällen; native Fälle melden NOT_EXECUTED.
Die eigenen Requests, Quelle, Container und Volume sind entfernt;
Lab-Cleanup besteht in zwei Schritten ohne Fehler, der temporäre Secretwert
ist entfernt. Private Captures und Runtimeidentitäten bleiben außerhalb Git.

OPS-005 ist aus 166 kanonischen Quellen synchronisiert. Sein Update und
beide PLAN-Artefakte bleiben normalisiert unverändert. Eine Inventarzeile
ergänzt ausschließlich die neun bereits vorhandenen Textcollations.
Die Dokumentation präzisiert die drei tatsächlichen Requestlimitfelder und
den Textzugriff auf alle Grant-Handles. N+1 begrenzt materialisierte Statements
und die anschließende Unicodeprojektion; eine entsprechende physische
TVF-Auswertungsgrenze wird ohne Plannachweis nicht behauptet.
Die abschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen
bestehen am Lieferstand. Echte wartende Grants, konfigurierter Resource Governor,
aktive Grantzuteilung, hohe Last, allgemeine Rundungsgrenzen, Berechtigungen,
Timeout, ältere native Engines und CL150/160 bleiben unbelegt. COLL-001 bleibt
partiell; Registry, RUNTIME-001 und bestehende Maturityflags bleiben unverändert.

Eingefrorene normalisierte SHA256-Werte: Source060
`81DBCE2295A1A2D8C2738A10187971938B6F1F335AD94E97639397FC6756D010`, Common183
`EAA263C8D0241F84792234E9B7006ED8787160E385B15C0B5DDEC6E0121164AB`, Static1026
`D51522702A5B64D3026A7B0801059EEB96292F952121CE8AFAF4BC5CE182F3DB`.


## Current-State-Snapshot: korrekter Sessions-Quellenzähler

Der begrenzte Nachweis vom 7. Oktober 2026 verwendet ein eigenes gemischtes
SQL-Server-2025-Dockerlab mit gemessenem Build 17.0.4075.5 und CL170.
Server und tempdb verwenden Latin1_General_100_CS_AS, das Framework
SQL_Latin1_General_CP1_CS_AS. Die kanonische Installation umfasst 166 Quellen;
Installation und Smoke bestehen. Es wird keine permanente Quelldatenbankfixture
benötigt. Runtimeidentitäten, Captures und Secretwerte bleiben außerhalb Git.

Das unveränderte InternalCaptureCurrentStateSnapshot zählt für SESSIONS
die WorkloadGroups-Tabelle vor deren möglicher Erfassung. Acht Originalaufrufe
ergeben 19 Grids und 67 Vergleiche zwischen CapturedRowCount und einer
unabhängigen COUNT_BIG-Ermittlung aus der jeweiligen materialisierten Tabelle
mit derselben Snapshot-ID. Fünf Sessions-Captures melden 0 statt 82 bis 84
Zeilen. Die übrigen 62 Vergleiche stimmen, einschließlich der dynamischen
WorkloadGroups-Erfassung. Der zunächst untersuchte EXEC-/@@ROWCOUNT-Verdacht
ist damit kein weiterer bestätigter Fehler und führt zu keiner Änderung.

Genau ein Tabellenname im Sessions-Zähler wird korrigiert. Der Snapshot-ID-Filter,
die 13 Helperparameter, Sourceversion 2.1.0, Snapshotvertrag 2 und alle anderen
Capture-, Quellen-, Ordinal-, Status-, Partialitäts- und Fehlerpfade bleiben
erhalten. SourceStatus und öffentlicher snapshotStatus behalten elf Felder,
vier Frameworktextcollations und neun NOT-NULL-Felder. Die Finalgegenprobe
bestätigt dieselben acht Aufrufe, 19 Grids und sämtliche 67 Mengenvergleiche
ohne Abweichung sowie erhaltene native Schemafacetten und Helperparameter.
Die Aufnahmen sind nacheinander erfasste Quellen und kein atomarer Serverzustand.

Die Fälle umfassen deaktivierte Quellen, Sessions allein, Resource Governor
allein, deren Kombination, zwei vollständige Captures mit unterschiedlichen
IDs in denselben Tabellen, angeforderte abhängige Quellen ohne Session-/Request-
Erfassung und SQL-Text mit Handlelimit 1. Deaktivierte Quellen erzeugen im
Collector keine Statuszeile; acht leere abhängige Mengen bleiben AVAILABLE
mit Count 0. SQL_TEXT zählt bei Limit 1 eine behaltene Zeile und meldet
AVAILABLE_LIMITED samt bestehendem Mengenhinweis. Ein separater Vorher-/Nachher-
Vergleich sämtlicher 18 Tabellen bestätigt pro Original- beziehungsweise
Finalsuite alle gespeicherten Werte und fachlichen Schemafacetten des älteren
Snapshots nach einem weiteren vollständigen Capture unverändert.

Je Original- und Finalsuite bestehen 15 Vorprüfungen für NULL-ID, wiederverwendete
ID, negative beziehungsweise NULL-Handlegrenze und elf NULL-Captureflags mit
51020. Contextmenge 1 und leere SourceStatusmenge bleiben erhalten.
Eine eigene lokale Temp-Tabellen-Transaktion liefert zusätzlich vier positive
Mengenrouten; drei Transaktionszähler stimmen bereits im Original, der
Sessions-Zähler erst im Finalstand. Eine lokale CHECK-Bedingung erzwingt
Insertfehler 547: SESSIONS bleibt ERROR_HANDLED, partiell und Count 0,
während REQUESTS anschließend erfolgreich und mengenrichtig erfasst wird.
Ein danach fehlender Temp-Table-Vertrag liefert 51020 vor einem weiteren Context.
Diese Fehlerprobe ist kein Berechtigungs- oder Timeoutnachweis.

Je Original- und Finalsuite bestehen drei Parentfälle mit ausgeschlossener
eigener Session und drei zusätzliche positive Parentfälle mit einer eigenen
zweiten Verbindung. Die Parentfälle verwenden Limits 0/1 sowie einmal zusätzlich
Requests. Sämtliche elf snapshotStatus-Werte einschließlich NULL-Properties
stimmen innerhalb desselben Aufrufs zwischen TABLE und JSON überein; native
TABLE-Schemafacetten bleiben gegenüber dem Original erhalten. Die positive
Verbindung liefert jeweils eine Session-Childzeile. Deren Anzahl ist kein
Quellenzählorakel und belegt keine vollständige 51-Feld-Werteparität des Childs.
Caller-LOCK_TIMEOUT 137 wird wiederhergestellt. Guid-Schreibweisen werden
typisiert verglichen. Die aktuelle Session bleibt durch den bestehenden
Childdefault ausgeschlossen; dafür wird keine Parent-API ergänzt.

Integration199 erhält die positive Sessions-Mengenassertion im bestehenden
All-Child-Aufruf und zwei Sessions-only-Parentfälle mit Max0/1, vollständiger
elf-Feld-Statusparität und getrennten Snapshot-Identitäten. Die acht bisherigen
Fremd-ID-Consumerprüfungen bleiben erhalten. Das neue Gate weist den separat
im eigenen Lab wieder installierten Originalcollector tatsächlich mit 52199
an der Sessions-Assertion zurück und besteht mit dem Finalcollector.
Es entsteht kein weiterer Snapshotowner und keine Static950-Ausnahme.
Ein zunächst doppelt angelegtes Testziel wird nach einem Static950-Befund
in zwei getrennte einmalige Ziele geändert. Private Prüferannahmen zu
Metadatengridposition, Labelgröße, aktueller Session und Guid-Schreibweise
sowie die Fehleraufnahme nach NextResult werden ausschließlich im Harness
korrigiert; daraus entsteht keine weitere Produktänderung.

Static993 schützt 17 Quellen-/Mengenrouten und besteht zwei bestehende
Statusfälle sowie 69 echte Count-, Source-, Snapshotfilter- und
Zählerabnahmemutationen. Ein unabhängiger P2-Reviewbefund ergänzt die unmittelbare
@@ROWCOUNT-Abnahme einschließlich 13 SET-Unterbrechungsmutationen.
Der finale funktionale Review besitzt keine offenen Befunde.
Acht impact-basierte SQL-Testdateien bestehen auf CL170 in 25 Batches.
Alle 75 statischen Prüfungen bestehen am eingefrorenen funktionalen Stand.

OPS-005 enthält die kanonische Ein-Tabellennamen-Korrektur; sein Update und
beide PLAN-Artefakte bleiben normalisiert unverändert. Zwei betroffene
Dokumente präzisieren die Quellenzählung vor Childfiltern und Ausgabelimits.
Das eigene Lab wird mit zwei Cleanupschritten ohne Fehler entfernt;
der temporäre Secretwert und sämtliche eigenen Verbindungen sind entfernt.
Die abschließenden begrenzten Dokumentations-, Schreibstil- und Privacyprüfungen
bestanden am Lieferstand. Eingeschränkte Berechtigungen, echte Timeouts,
konfigurierte Resource-Governor-Varianten, ältere native Engines und CL150/160
bleiben für diesen Slice unbelegt. COLL-001 bleibt partiell; Registry,
RUNTIME-001 und bestehende Maturityflags bleiben unverändert.

Eingefrorene normalisierte SHA256-Werte: Source005
`256607B77C023CB12F6B2AB770C0F5ECA25ED07A0DAC807C2122DD605E1D2E56`, Integration199
`5079B0957905A4E9A11520C7EB5F133FCF4963C7607B007AC8A67DF1D7A647A4`, Static993
`9C39A47A91C75B57B60AA459FD19D995ACDC777F7B5705772A168213FB0BDB22`.


## Current Sessions: vollständiger gemeinsamer Ausgabevertrag

Der begrenzte Nachweis vom 7. Oktober 2026 verwendet ein eigenes gemischtes
SQL-Server-2025-Dockerlab mit gemessenem Build 17.0.4075.5 und CL170.
Server und tempdb verwenden Latin1_General_100_CS_AS, das Framework
SQL_Latin1_General_CP1_CS_AS. Die kanonische Installation aus 166 Quellen und
Smoke bestehen. Drei eigene Verbindungen besitzen case-unterschiedliche
Unicode-App-/Hostwerte: eine inaktive Session ohne Transaktion, eine inaktive
Session mit eigener Temp-Tabellen-Transaktion und eine aktive WAITFOR-Session.
Es wird keine permanente Quelldatenbankfixture benötigt. Runtimeidentitäten,
Captures und Secretwerte bleiben außerhalb Git.

Das vollständig geprüfte Original besitzt bereits eine gemeinsame Ergebnistabelle
mit 51 Feldern, 22 Frameworktextcollations, fünf NOT-NULL-Feldern und ohne
Identity. TABLE verwendet diese 51 Felder, aktive CONSOLE ergänzt Ergebnis,
JSON drei Wait-Felder und RAW zehn Wait-Felder sowie einen 13-feldrigen Status.
Die 26 Parameter, Sourceversion 2.2.0, JSON-SchemaVersion 3 und Snapshotvertrag 2
bleiben erhalten. Ein N+1-Kandidat wird bereits vor Unicodeprojektion und allen
Ausgaben entfernt; eine Produktkorrektur ist für diesen Umfang nicht begründet.
Source, Collector, Parent und beide OPS-/PLAN-Installerpaare bleiben normalisiert
exakt gegenüber der Basis unverändert.

Ein unabhängig implementiertes 51-Feld-Orakel verwendet einen tatsächlich nativ
erfassten, privat eingefrorenen Stand der drei eigenen Sessions. 168 Fälle
prüfen alle fünf Sortierungen, NULL-/0-/1-/2-Limits, Text an/aus und vier
Ausgabeformen sowie Zeichenlimits 17/18. Sie vergleichen sämtliche Sessionwerte,
die drei JSON- und zehn RAW-Waitwerte, Counts, HasMoreRows und erhaltene Warnungen.
Ein gesondertes Literalorakel bestätigt 357 native Schemafacetten einschließlich
Typ, Größe, Präzision, Scale, Collation, Nullability und Identity. Die 51 nativen
Feldfacetten bleiben zwischen TABLE, RAW und aktiver CONSOLE konsistent.

Die ersten Limits 17/18 schneiden die native Fixture nicht an einem Surrogate.
Weitere 16 Fälle prüfen deshalb tatsächlich die SC-Zeichengrenzen 20/21 und
26/27 vor beziehungsweise auf dem Surrogate-Paar mit allen vier Ausgabeformen.
Siebzehn zusätzliche eingefrorene Fälle prüfen exakte Unicode-/Case-Host- und
Programmfilter, bracket-aware Duplikate, LIKE, REGEX/REGEXI, Login-Case,
Datenbankfilter und Inaktiv-/Transaktions-/Eigenmodus. Die vier erfassten
Session-, Request-, Connection- und SQL-Texttabellen bleiben nach diesen
Aufrufen mit allen gespeicherten Werten erhalten.

Sieben positive und ein leerer tatsächlicher Overview-Aufruf verwenden Limits
0/1/2, SQL-Text an/aus und einmal zusätzlich Requests. Alle 51 Childwerte
stimmen innerhalb desselben Aufrufs zwischen TABLE und JSON überein;
Snapshotzuordnung, Modulordinal 10 und vollständige elf-Feld-SourceStatus-Parität
einschließlich NULLs bleiben erhalten. Caller-LOCK_TIMEOUT 137 wird
wiederhergestellt. Die aufrufende Session bleibt nach dem vorhandenen
Childdefault ausgeschlossen; die positive Fixture verwendet andere eigene
Verbindungen. Die privaten Orakel vergleichen insgesamt 42.912 Fachwerte.
Die eingefrorenen Quellen belegen keinen atomaren Livezustand zwischen Aufrufen.

Common184 besteht 20 allgemeine TABLE-Fälle ohne positive Fixture und meldet
für deren Block NOT_EXECUTED. Mit der eigenen Fixture bestehen zusätzlich
21 native TABLE-Fälle, drei Consumer, sechs Mappingablehnungen, drei leere
SQL-CONSOLE-Captures und drei direkte positive CONSOLE-Status-/JSON-Aufrufe.
51-Feld-TABLE-/JSON-Parität, alle 54 JSON-Feldschlüssel, drei Topkeys,
zwölf Metafelder und zweifeldrige Warnungen werden einschließlich NULLs und
JSON-Typen geprüft. Dreizehn native Identitäts-/Verbindungsfelder und acht
unabhängig abgeleitete Text-/Trunkierungswerte werden separat geprüft.
Bewegliche Livezähler erhalten keinen Cross-call-Vollparitätsanspruch.
Der unabhängige Review ergänzt vor dem Freeze ausschließlich den fehlenden
Upper-idle-Guard des Tests; der finale funktionale Review hat keine offenen Befunde.

Static1038 schützt sieben Arbeitstabellen mit 104 Spalten und 39 lokalen
Textcollations sowie gemeinsame Limit-, Consumer- und Snapshotgrenzen;
380 echte Mutationen bestehen. Das Inventar ergänzt die bereits vorhandenen
22 Resultcollations. Zwei betroffene Dokumente präzisieren Quellreads vor
Filtern, deduplizierte SQL-Textauflösung vor der Ergebnisauswahl, Requestkontext,
Ausgabeformen und fehlende TABLE-/CONSOLE-Reihenfolgegarantien.
Es entsteht kein neuer Snapshotowner und keine Static950-Ausnahme.

CurrentState110/131 und Integration189/199 bestehen auf CL170 in 14 Batches.
Die kanonische Impact-Auswahl umfasst Common184; ihr Lauf besteht in fünf
Batches. Alle 75 statischen Prüfungen bestehen am stabilen funktionalen Stand.
Ein erster Volllauf scheitert am lokalen OPS-Installer-Bytevergleich nach
Windowscheckout; kanonische Neugenerierung erhält alle normalisierten Inhalte
und behebt die lokale Zeilenendenrepräsentation. Ein wiederholtes CREATE eines
privaten Captureziels und eine SQLCMD-Direktive im privaten SqlClient-Runner
werden ausschließlich im Harness korrigiert. Daraus entstehen keine Produktedits.

Vor Cleanup sind keine eigenen Fixturesessions mehr sichtbar. Das eigene Lab
wird mit zwei Cleanupschritten ohne Fehler entfernt; Secretwert und eigene
Verbindungen sind entfernt. Die anschließenden begrenzten Dokumentations-,
Schreibstil- und Privacyprüfungen bestehen am Lieferstand. MARS, isolierte
Ranking-/Rundungsgrenzen, eingeschränkte Berechtigungen, echte Timeouts,
weitere Tool-Klassifikationen, ältere native Engines und CL150/160 bleiben
für diesen Slice unbelegt. COLL-001 bleibt partiell; Registry, RUNTIME-001
und bestehende Maturityflags bleiben unverändert.

Eingefrorene normalisierte SHA256-Werte: Source010
`45C39B49981F701DAFFADB2BA67941E5328CC8C7D122C04B711CBEE4A6EBFC8C`, Common184
`743369046DE6FE350EE2E6E18930E8BC554D54CF38084D3CB50A5DEE96A978EA`, Static1038
`A51A8D9C05A215AEE4D0A100242626A838C4B95566D7C75262B672A6A16D9178`.


## Current Requests: gemeinsame Ausgaben und Laufzeitgrenzen

Der begrenzte Nachweis vom 7. Oktober 2026 verwendet ein eigenes gemischtes
SQL-Server-2025-Dockerlab mit gemessenem Build 17.0.4075.5 und CL170.
Server und tempdb verwenden Latin1_General_100_CS_AS, das Framework
SQL_Latin1_General_CP1_CS_AS. Kanonische Installation aus 166 Quellen und
Smoke bestehen. Drei eigene aktive WAITFOR-Verbindungen besitzen
case-unterschiedliche Unicode-App-/Hostwerte. Eine hält eine eigene
Temp-Tabellen-Transaktion, eine führt ein eigenes Unicode-Modul aus.
Runtimeidentitäten, vollständige native Captures und Secretwerte bleiben außerhalb Git.

Die sieben bestehenden TABLE-Exporte enthalten 93/73/11/19/15/13/6 Felder,
zusammen 230 Felder mit 66 expliziten Frameworktextcollations und ohne Identity.
Der Legacyexport besitzt 93 Felder, aktive CONSOLE ergänzt Ergebnis,
RAW zwölf Wait-Felder sowie einen separaten 13-Feld-Status. JSON-Legacy enthält
52 Felder: 50 Resultwerte und zwei Wait-Werte. Die acht JSON-Hauptschlüssel,
16 Metafelder, 34 Parameter, Sourceversion 4.0.0, JSON-SchemaVersion 4 und
Snapshotvertrag 2 bleiben erhalten. Die gemeinsame N+1-Begrenzung liegt bereits
vor Modul-/Inputbufferauflösung, Unicodeprojektion und Ausgabe.

Vier native Originalfälle mit gültigen Maps und semantisch ungültigen Parametern
lassen alle 28 TABLE-Ziele als Seedspalte stehen. Das frühe vorhandene Prepare
stellt im Abschlussstand alle 28 vollständigen Schemas bereit. Ein nativer
INT_MAX-Sekundenfilter meldet im Original ERROR_HANDLED mit Fehler 8115.
Der bigint-Vergleich meldet anschließend AVAILABLE mit leerer Menge.
Diese zwei eng begrenzten Korrekturen verändern keine ABI, Rangfolge,
Filtersemantik oder Versionsgrenze. Collector und Parent bleiben unverändert.
OPS-005 wird kanonisch synchronisiert; sein Update und beide PLAN-Installer
bleiben normalisiert gegenüber der Basis unverändert.

Ein unabhängiges Literalorakel prüft sämtliche 93 Legacywerte, 73 Kontextwerte,
elf Statuswerte und die drei vollständigen Textarrays aus tatsächlich nativ
erfassten, privat eingefrorenen Quellen. Je 160 Original- und Abschlussfälle
prüfen fünf Sortierungen, NULL-/0-/1-/2-Limits, alle 16 Kombinationen der vier
Textoptionen und TABLE/RAW/CONSOLE/NONE. Je 26 weitere Fälle prüfen exakte
Unicode-/Case-Host-, Programm-, Login- und Datenbankfilter, bracket-aware
Duplikate, LIKE, REGEX/REGEXI, Eigenmodus, Wait-/Blocking- und Mindestfilter.
Je 32 weitere Fälle schneiden tatsächliche Surrogate-Grenzen bei
20/21, 38/39, 50/51 und 97/98 Zeichen in allen vier Ausgabeformen.
Ein gesondertes Literalorakel bestätigt je 1.610 native Schemafacetten.
Alle 18 erfassten Quellentabellen bleiben mit ihren gespeicherten Werten erhalten.
Original und Abschluss verwenden jeweils eigene eingefrorene native Captures;
daraus wird kein atomarer Livezustand oder identischer Quellenstand abgeleitet.

Je sechs positive tatsächliche Overview-Aufrufe verwenden Limits 0/1/2 und
SQL-Text an/aus. Innerhalb desselben Aufrufs stimmen die 50 gemeinsamen
Legacywerte sowie vollständiger Kontext, Status und Textarrays zwischen TABLE
und JSON überein. Die übrigen 43 Legacywerte besitzen den unabhängigen
Childnachweis; vollständige Parentwerteparität dieser Felder bleibt unbelegt.
Modulordinal 20, neun Modulstatuszeilen, Child-/Parent-Quellenzuordnung und
Caller-LOCK_TIMEOUT 137 bleiben erhalten. Die positive Fixture verwendet
andere eigene Verbindungen; der vorhandene Parentdefault schließt den Caller aus.
Die Orakel prüfen je Original- und Abschlussstand insgesamt 234.358 Fachwerte.

Common185 besteht 21 allgemeine TABLE-Fälle, neun selektive Maps, drei Consumer,
sechs Mappingablehnungen und drei leere SQL-CONSOLE-Captures. Ohne Fixture
bleibt der native Block NOT_EXECUTED. Mit der eigenen Fixture bestehen
20 zusätzliche native Fälle und drei direkte positive CONSOLE-Status-/JSON-Aufrufe.
Der Vertrag prüft alle sieben Schemas, vollständige gleiche JSON-Feldmengen
und Typen, 52 Legacyfelder, 73 Kontextfelder, Textarrays, Warnungen und Status.
Elf stabile native Identitätsfelder, unabhängig abgeleitete UTF16-/SC-Textwerte
und die vorhandenen Wait-Katalogwerte erhalten zusätzliche Gegenproben.
Bewegliche Livezähler erhalten keinen Cross-call-Vollparitätsanspruch.
Static1039 schützt 27 lokale Tabellen, 99 lokale Textcollations, alle 230
Exportfelder und die beiden korrigierten Grenzen; 1.279 echte Mutationen bestehen.
Inventar und zwei betroffene Dokumente präzisieren die bestehenden Verträge.
Es entsteht kein neuer Snapshotowner und keine Static950-Ausnahme.

Die kanonische Impact-Auswahl umfasst 13 SQL-Testdateien; ihr nativer Lauf
besteht in 39 Batches. Alle 75 statischen Prüfungen bestehen am stabilen
funktionalen Stand. Ein wiederholtes CREATE eines privaten Captureziels und
mehrere private Typ-/Spaltenordnungsannahmen werden im Harness korrigiert.
Ein ursprünglicher Unicodecapture scheitert einmal mit Lock-Timeout 1222;
die einmalige Wiederholung besteht, die Ursache bleibt offen. Ein doppeltes
Setup im Common-Test wird vor Freeze entfernt. Der lokale Shellwrapper
meldet nach erfolgreichem Suiteschluss einen Exitquotingfehler; die vollständige
Suiteabschlusszeile und alle 75 Ergebnisse liegen vor. Daraus entsteht keine
zusätzliche Sourceänderung. Ein Reviewbefund präzisiert ausschließlich die
Dokumentation vollständiger INVALID_PARAMETER-Schemas bei erhaltener Status-
und Warnungsevidenz. Der unabhängige funktionale Review hat keine
offenen Befunde.

Vor Cleanup sind keine eigenen Fixture-Verbindungen oder Module mehr sichtbar.
Das eigene Lab wird mit zwei Cleanupschritten ohne Fehler entfernt; Secretwert
und eigene Verbindungen sind entfernt. Die anschließenden begrenzten
Dokumentations-, Schreibstil- und Privacyprüfungen bestehen am Lieferstand.
MARS, isolierte Rangties, eingeschränkte Berechtigungen, systematische Timeout-
und weitere Tool-Regeln, ältere native Engines und CL150/160 bleiben unbelegt.
COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende Maturityflags
bleiben unverändert.

Eingefrorene normalisierte SHA256-Werte: Source020
`be089c09f89197ba144944d0fb320d5ba1d2eef11bb07537bc4a7368253457e5`, Common185
`5c9bddd788faf9ec3453cf35ccaf856134b8fc83268d42c5dfdcdd64e5ab6cb7`, Static1039
`4f2731fcfa728cbd96cc7c48e164504036e010a8a7ed607bd7115252157ab9b4`.


## Current Blocking: gemeinsame Mengenlimits und vollständige Ausgabeverträge

Der begrenzte Nachweis vom 7. Oktober 2026 verwendet ein eigenes
SQL-Server-2025-Dockerlab mit gemessenem Build 17.0.4075.5 und CL170.
Server und tempdb verwenden Latin1_General_100_CS_AS, das Framework
SQL_Latin1_General_CP1_CS_AS. Kanonische Installation aus 166 Quellen und
Smoke bestehen. Vier eigene Verbindungen und drei eigene Unicodeobjekte
erzeugen eine Root-, Middle- und zwei Leaf-Situationen mit case-unterschiedlichen
App-/Hostwerten. Eine eigene Tool-Regel unterscheidet den Tool-Leaf.
Runtimeidentitäten, native Captures und Secretwerte bleiben außerhalb Git.

Source030 besitzt zwölf lokale Tabellen mit 158 Feldern und 82 Textcollations.
Der gemeinsame Kettenexport umfasst 67 Felder mit 38 Frameworktextcollations,
zehn NOT-NULL-Feldern und ohne Identity. RAW ergänzt bei Bedarf 23 Lockfelder,
vier Warnungsfelder und 25 Metafelder. JSON besitzt vier Hauptschlüssel und
24 Metafelder; aktive CONSOLE ergänzt Ergebnis zu den 67 Kettenfeldern.
18 Parameter, Sourceversion 3.0.0, JSON-SchemaVersion 3, Inventarversion 4,
Modulordinal 30 und Snapshotvertrag 2 bleiben unverändert.

Das Original liefert bei positiven Limits über TABLE und generische CONSOLE
eine zusätzliche N+1-Kette. RAW und JSON begrenzen bereits auf N.
Zehn zusätzliche Sourcezeilen begrenzen ausschließlich die gemeinsame
Kettentabelle nach dem Enrichment-CATCH und der Unicodewarnung, vor
Partialaggregation und Verbrauchern. MainCandidateCount, HasMore, beteiligte
Sessions, Lockmengen, Objektauflösung und Textprojektion behalten ihre vorherige
N+1-Verarbeitung. Parent-TABLE verwendet anschließend dieselbe Begrenzung.
Collector, Parent, API, Reihenfolge und Filter bleiben erhalten. OPS-005 wird
kanonisch synchronisiert; sein Update und beide PLAN-Installer bleiben
normalisiert gegenüber der Basis unverändert.

Je Original- und Abschlussstand prüft ein unabhängiges Literalorakel 160
unterschiedliche native Fälle: 90 Consumer-/Filter-/Unicodefälle, 48 Lock- und
Auflösungsfälle, sechs tatsächliche Overview-Aufrufe und 16 negative Fälle.
Die Originalprüfung umfasst 106.289, die Abschlussprüfung 104.919 Prüfungen
von Werten, Strukturen und Schemafacetten. Alle 67 Kettenfelder und 23
Lockfelder erhalten vollständige Wertgegenproben aus eigenen eingefrorenen
nativen Quellen. 536 physische Kettenschemafacetten, alle 18 ABI-Parameter
und 18 unveränderte Quellen werden gesondert geprüft. Die zwei Phasen
verwenden jeweils eigene Captures; daraus entsteht kein atomarer Cross-call-
Livezustand. Vier direkte, 16 Lock-/Auflösungs- und vier Parent-TABLE-Fälle
belegen den ursprünglichen Mengenfehler; im Abschluss bestehen alle Limits.

Die Fälle prüfen NULL-/0-/1-/2-Limits, TABLE/RAW/CONSOLE/NONE, SQL-Text und
Toolfilter, Root-/Middle-/Leaf-Sessionpfade, Mindestwartezeit sowie den
Request-Prioritäts- und WaitingTask-Fallback. Tatsächliche Surrogate liegen
bei 18, 37 und 69 UTF16-Einheiten; 24 Fälle prüfen die jeweiligen Schnitte
vor und an der Grenze in allen vier Ausgabeformen. STANDARD/NONE,
DEEP und optionale Locks erhalten native Gegenproben. 151 native Locks
bleiben als Multimenge vor und nach dem Capture stabil. Bei 16 begrenzten
Lockfällen bestehen nicht eindeutige Sortierties; das Orakel akzeptiert nur
die nativ belegten Grenzressourcen, ohne eine zusätzliche Ordnung zu erfinden.
Vorhandene PARTIAL-Metadaten bleiben erhalten. Negative Fälle prüfen
semantische Ablehnungen, bigint-Maximum, fehlende Parentquelle sowie sechs
Mappingablehnungen vor Semantik und Quellenzugriff bei unveränderten Seeds.

Sechs tatsächliche Overview-Aufrufe prüfen Limits 0/1/2 und SQL-Text an/aus.
Innerhalb desselben Parentaufrufs stimmen sämtliche 67 TABLE-/JSON-Kettenwerte
für die behaltenen Zeilen überein. Vollständige native TABLE-Schemafacetten,
neun Modulstatuszeilen, Quellenflags und Caller-LOCK_TIMEOUT 137 bleiben
erhalten. Der unabhängige Childnachweis verwendet eingefrorene native Quellen;
eine zusätzliche vollständige Parent-Snapshot-Wertparität wird nicht behauptet.

Common186 besteht 18 allgemeine TABLE-Fälle, vier Consumer, sechs
Mappingablehnungen, vier synthetische Unicodefälle und drei leere
SQL-CONSOLE-Captures. Ohne Fixture bleibt der native Block NOT_EXECUTED.
Mit eigener Fixture bestehen 18 native TABLE-Fälle, sechs echte
JSON-NULL-Mutationen und drei direkte CONSOLE-Status-/JSON-Aufrufe.
Ein unabhängiger Reviewbefund schließt die zuvor NULL-tolerante Gegenprobe
der sechs nullable Kettentexte. Der korrigierte Test prüft Feldmenge, JSON-Typ,
beide NULL-Asymmetrien und BIN2-Werte. Beide nativen Commonläufe bestehen
nach der Korrektur; der unabhängige funktionale Review hat keine offenen Befunde.

Static1040 schützt sämtliche lokalen und gemeinsamen Felder, ABI,
Prepare-Reihenfolge, Parentownership und die späte reine Kettenbegrenzung.
661 echte Mutationen bestehen. Static950 behält genau zwei Parentowner;
es entstehen weder ein weiterer Owner noch eine Ausnahme. Inventar und zwei
betroffene Dokumente präzisieren die bestehenden Verträge. Alle 75 statischen
Prüfungen bestehen vor der ausschließlich Common betreffenden Reviewkorrektur.
Danach bestehen die betroffenen Prüfungen 950, 900, 915 und 910 erneut.
Die kanonische Impact-Auswahl umfasst elf SQL-Testdateien; ihr tatsächlicher
nativer Abschlusslauf besteht in 34 Batches mit 430 Resultgrids.

Die private Zweiobjekt-Fixture erzeugt zunächst eine unerwartete Leaf-Wartekante;
ein Pooling-Cleanup-Timeout verdeckt einmal den primären Bereitschaftsfehler.
Eigene zurückgebliebene Objekte und Regel werden anhand nativer Identitäten
gezielt bereinigt. Drei unabhängige Lockressourcen und Verbindungen ohne
Pooling liefern danach die verlangte Situation. Ein privater Encodingfehler
und wiederholtes CREATE desselben Captureziels scheitern vor Ausführung und
werden im Harness korrigiert. Ein doppelter privater Cleanup-Parameter führt
einmal nach erfolgreichem Capture zum Prozessfehler; native Identitäts- und
Wertprüfungen ermöglichen die gezielte Bereinigung. Alle anschließenden
Original-, Abschluss- und korrigierten Commonläufe enden erfolgreich.
Diese Harnessfehler begründen keine zusätzliche Produktänderung.

Die native Abschlussprüfung meldet null eigene Sessions, Objekte und Regeln.
Die installierte Definition stimmt einschließlich Kommentar vollständig mit
der eingefrorenen Source überein, abgesehen vom mechanisch gespeicherten
CREATE-Prozedurkopf. Das eigene Lab wird mit zwei Cleanupschritten ohne
Fehler entfernt; die Secretdatei ist entfernt. Ein unbenutztes, außerhalb Git
erzeugtes OPS-Update bleibt erhalten: Die automatische Freigabeprüfung weist
seine Löschung mit blocked by policy zurück und nennt keinen genaueren Grund.
Der Inhalt entspricht normalisiert exakt dem kanonischen OPS-Update und
enthält keine Runtimeidentitäten oder Secrets. Die begrenzten abschließenden
Dokumentations-, Schreibstil- und Privacyprüfungen gehören zum Liefergate.

MARS, eingeschränkte Berechtigungen, systematische Timeout- und zusätzliche
Tool-Regeln, ältere native Engines und CL150/160 bleiben unbelegt.
COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende Maturityflags
bleiben unverändert.

Eingefrorene normalisierte SHA256-Werte: Source030
`d3198e0643f4e962c82a0c91d1fa729a7aa052e04f56ddec297f13da799636b3`, Common186
`44f8edf786e90530f11a0ecbb8b4cc06138266fda2d6ac7413eaa4ce599a844d`, Static1040
`598ed07dbe967f69e67b134d81b68c69c754c57a60c9ff243280ce0f2836bd0f`.


## Current Waits: vollständige bestehende Ausgabeverträge

Der begrenzte Nachweis vom 7. Oktober 2026 verwendet ein eigenes
SQL-Server-2025-Dockerlab mit gemessenem Build 17.0.4075.5 und CL170.
Server und tempdb verwenden Latin1_General_100_CS_AS, das Framework
SQL_Latin1_General_CP1_CS_AS. Kanonische Installation aus 166 Quellen und
Smoke bestehen. Vier eigene Verbindungen, drei eigene Unicodeobjekte und
eine eigene Tool-Regel erzeugen drei LCK_M_X-Tasks mit einer schlafenden
Root-, einer Middle- und zwei Leaf-Sessions. Runtimeidentitäten, native
Captures und Secretwerte bleiben außerhalb Git.

Source040 besitzt 13 lokale Tabellen mit 99 Feldern und 50 expliziten
Frameworktextcollations. Der gemeinsame Taskexport umfasst 33 Felder mit
22 Textcollations; instanzweite Waits umfassen 23 Felder mit elf
Textcollations. Beide besitzen keine Identity. RAW ergänzt 19 Status- und
zwei Warnungsfelder. JSON besitzt vier Hauptschlüssel und 13 Metafelder.
Aktive CONSOLE ergänzt eine Beschriftung zu den 33 Taskfeldern; die leere
Ausgabe besitzt drei Hinweisfelder. TABLE exportiert ausschließlich Tasks.
21 Parameter, Sourceversion 4.0.0, JSON- und Inventarschema 3,
Modulordinal 40 und Snapshotvertrag 2 bleiben unverändert.

143 unterschiedliche Originalfälle bestehen: 102 Consumer-, Filter-,
Limit- und Messfälle, acht tatsächliche Unicodegrenzfälle, 24 negative
beziehungsweise Mappingfälle und neun tatsächliche Overview-Aufrufe.
Das unabhängige Literalorakel umfasst 164.887 Wert-, Struktur- und
Facettenprüfungen sowie 448 unterschiedliche physische Schemafacetten.
Alle 33 Taskwerte werden aus eingefrorenen nativen Quellen geprüft.
Die private Parent-DDL besitzt 18 Quelltabellen; sie erzeugt keinen
zusätzlichen Repository-Snapshotowner. Katalogwerte und der bestehende
Family-Fallback werden unabhängig erwartet. Alle 23 Instanzfelder erhalten
native beziehungsweise daraus unabhängig abgeleitete Sollwerte.
14.079 native Zählergrenzen, 13.581 Gleichheiten stabiler Zähler und
4.689 Prozentgrenzen verwenden Vorher-/Nachhermessungen. Ein einzelner
WAITFOR-Waittyp besitzt exakt 100 Prozent, auch bei vier Einsekundensamples.
Mehrtypige Sample-Prozentnenner besitzen keinen unabhängigen Grenznachweis.
Ein atomarer Gleichheitsvergleich beweglicher Werte über getrennte
Aufrufe wird nicht behauptet.

Listen, Duplikate, Groß-/Kleinschreibung, LIKE, Regex und Regex-i, Waitgruppen,
Tool-Einbezug, Mindestdauer, Benignfilter, Textopt-out, positive Limits sowie
NULL und 0 als unbegrenzte Limits werden geprüft. Die native SC-Zeichenposition
34 des Supplementary Characters wird mit Grenzen 33 und 34 geprüft.
Der bestehende Prozentnenner entsteht nach Benign-, Listen- und LIKE-Auswahl;
späte Regexfilter normalisieren ihn nicht erneut. Die kumulative Summe
verwendet gerundete Einzelanteile. Quelltext wird vor Taskfiltern gelesen;
Unicodeprojektion und Verbraucher verwenden danach die begrenzte Taskmenge.
Die originalen Mengenlimits und frühen Mappingprüfungen bestehen bereits.
Es wird keine Produktabweichung belegt und keine Produktkorrektur eingeführt.

Alle 18 semantischen beziehungsweise leeren Negativfälle behalten das
vollständige leere TABLE-Schema. Sechs fehlerhafte Maps scheitern vor der
Semantik mit 51011 und erhalten eigene Seeds. NULL als Mindestdauer und
doppelte Sessionwerte bleiben im bestehenden akzeptierten Verhalten.
Alle neun Overview-Aufrufe bestätigen die vollständigen 33 TABLE-/JSON-Werte
innerhalb desselben Aufrufs, das physische Schema, Modulordinal 40,
Quellenflags, Snapshotbezug und Caller-LOCK_TIMEOUT 137. Vollständige
unabhängige Werte eines separaten Parent-Snapshots bleiben unbelegt.
Instanzmessungen behalten ihre eigenen Messpunkte.

Common187 besteht 18 allgemeine und 18 native TABLE-/JSON-Fälle, sechs echte
NULL-Mutationsablehnungen, vier Consumerfälle, sechs Mappingpreflights,
vier synthetische Unicodefälle, drei leere SQL-CONSOLE-Captures und drei
positive CONSOLE-Status-/JSON-Aufrufe. Ohne geeignete identitätsgeprüfte
Fixture bleibt der positive Block NOT_EXECUTED. Native Taskidentitäten und
Texte sind exakt; Waitdauer und kumulative Zähler werden begrenzt.
RAW und positive CONSOLE besitzen hier keine vollständige testinterne
Clientcapture; deren vollständiger Nachweis stammt aus dem privaten Orakel.
Static1018 schützt alle lokalen Felder, die ABI und bestehende Reihenfolgen;
493 echte Mutationen bestehen. Static950 behält die zwei bisherigen Owner.
Inventar und die beiden betroffenen Dokumente präzisieren die bestehenden
Verträge. Der unabhängige funktionale Review besitzt keine offenen Befunde.

Die vollständige statische Suite scheitert zunächst ausschließlich am
OPS-005-Bytevergleich: Ein Windows-Checkout ersetzt einen kanonischen
LF-Headerübergang durch CRLF. Normalisierte Inhalte bleiben identisch.
Nach Wiederherstellung der kanonischen Checkoutbytes besteht der betroffene
Adaptertest; die übrigen erfolgreichen Prüfungen werden nicht wiederholt.
Damit bestehen alle 75 statischen Prüfungen. Die kanonische Impact-Auswahl
umfasst ausschließlich Common187; der tatsächliche native Runner besteht
in fünf Batches mit sechs Resultgrids.

Ein privater EXEC-Ausdruck scheitert vor der Ausführung und wird durch eine
vorherige Variablenzuweisung ersetzt. Eine private Katalogannahme übersieht
den bestehenden Family-Fallback und wird im Orakel korrigiert. Ein nativer
Commonlauf weist einen Vorher-/Nachher-Rangwechsel nahezu gleichzeitig
gestarteter Waiter ab. Ein privater Startabstand von 150 Millisekunden macht
die Rangfolge eindeutig; der unveränderte Vertrag besteht danach. Ein
Shellwrapper scheitert vor der Suiteausführung. Keine dieser Harness- oder
Checkoutgrenzen begründet eine Produktänderung.

Source, Collector, Parent, OPS-005- und PLAN-Installer bleiben normalisiert
gegenüber der Basis unverändert. Die native Abschlussprüfung meldet null
eigene Sessions, Tabellen und Regeln. Die installierte Definition entspricht
der Source einschließlich Kommentar, abgesehen vom mechanisch gespeicherten
CREATE-Kopf und den kanonischen Installer-Grenzkommentaren. Eigenes Lab und
Secretdatei sind entfernt. Die abschließenden Dokumentations-, Schreibstil-
und Privacyprüfungen gehören zum Liefergate.

MARS, Reset, eingeschränkte Berechtigungen, systematische Timeout- und
weitere Tool-Regeln, ältere native Engines und CL150/160 bleiben unbelegt.
COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende Maturityflags
bleiben unverändert. Normalisierte SHA256: Source040
`de0ce6d84df06034ee9abf5474d9b452b7d87e3f075da2f923c64710706702af`, Common187
`6d12943ba231aab30055c9d4cb9a0126796875946f12a2f17d3a2972b694d501`, Static1018
`357383300adf82bbb2423b6e1a3399455f5cd20518da0a3b14abaa37502167f6`.


## Current Transactions: einheitliche bestehende Ausgabeverträge

Der begrenzte Nachweis vom 7. Oktober 2026 verwendet ein eigenes
SQL-Server-2025-Dockerlab mit gemessenem Build 17.0.4075.5 und CL170.
Server und tempdb verwenden Latin1_General_100_CS_AS, das Framework
SQL_Latin1_General_CP1_CS_AS. Kanonische Installation aus 166 Quellen und
Smoke bestehen. Vier eigene Verbindungen halten Transaktionen an drei
eigenen Unicodeobjekten; eine Root-Session schläft, drei Requests warten
mit LCK_M_X. Native Identitäten, Captures und Secretwerte bleiben außerhalb
Git. Eine private Harnessregel wird nicht zur Toolklassifikation verwendet;
Source050 besitzt keinen solchen Filter.

Die ursprünglichen neun lokalen Tabellen umfassen 50 Felder und 15 explizite
Frameworktextcollations. Der gemeinsame Transaktionsexport besitzt 20
Felder, sieben Textcollations, drei NOT-NULL-Felder und keine Identity.
RAW ergänzt zehn Statusfelder und drei Warningfelder. JSON besitzt drei
Hauptschlüssel und zehn Metafelder einschließlich NULL-Werten. Aktive
CONSOLE ergänzt die Beschriftung Ergebnis; die leere Ausgabe besitzt drei
Hinweisfelder. TABLE exportiert ausschließlich transactions. Die 14
Parameter, Sourceversion 3.0.0, JSON- und Inventarschema 2,
Modulordinal 50 und Snapshotvertrag 2 bleiben unverändert.

Je Original- und Abschlussstand bestehen 123 unterschiedliche Fälle:
96 Consumer-, Filter-, Limit- und Textfälle, 19 negative beziehungsweise
Mappingfälle und acht tatsächliche Overview-Aufrufe. Die unabhängigen
Orakel umfassen 17.445 beziehungsweise 17.125 Wert-, Typ-, Struktur- und
Facettenprüfungen. 320 unterschiedliche physische Facetten verteilen sich
auf je 160 SQL- und SqlClient-Schemafacetten. Alle 20 Fachwerte werden aus
vier privat eingefrorenen nativen Joinzeilen unabhängig erwartet.
Transaktionsalter besitzt 252 beziehungsweise 244 native GETDATE-Klammern;
andere Quellwerte bleiben eingefroren. Die private Parent-DDL enthält 18
Quelltabellen und erzeugt keinen neuen Repository-Snapshotowner.

Alle vier Ausgabemodi, NULL-/0-/1-/2-/INT_MAX-Zeilenlimits, Textopt-out,
Sleeping- und Systemfilter, vier einzelne Sessionfilter sowie Mindestalter
werden geprüft. Die tatsächliche SC-Zeichenposition 41 von 🔬 im laufenden
Statement wird an den Grenzen 40 und 41 geprüft. Statementextraktion wird
unabhängig über native Byteoffsets erwartet; Zeichen- und Bytezähler
behalten den ungekürzten Textumfang. Das Original überschreitet TABLE und
CONSOLE bei Limits 1/2 um jeweils eine Zeile. Weitere fünf Originalfälle
bestätigen die Überschreitung im tatsächlichen Parent-TABLE.

Zehn zusätzliche Sourcezeilen begrenzen die gemeinsame Fachmenge nach
Unicodeprojektion, Textwarnung, N+1-Zählerabnahme und Fehlerbehandlung.
HasMoreRows, Kandidatenmetadaten, ursprüngliche Filter und Rangordnung
bleiben erhalten. Die Begrenzung gilt für alle Verbraucher; finale native
Fälle besitzen keine Limitabweichung. Mehrere Datenbankbindungen werden
nicht aggregiert. Der ausgegebene Begin-Datetimewert bleibt ohne
UTC-Konvertierung; das Alter verwendet GETDATE.

Elf semantisch ungültige, fehlende Parent- oder leere Aufrufe exportieren
das vollständige leere TABLE-Schema. Sechs ungültige Maps scheitern vor
Semantik und Parentzugriff mit 51011 und erhalten eigene Seeds. Ungültiger
Ausgabemodus und JsonErzeugen=NULL werden zusätzlich mit Status geprüft.
NULL-Mindestalter und Sessionduplikate bleiben ungültig. Alle acht
Overview-Aufrufe am Abschlussstand bestätigen vollständige gemeinsame 20-Feld-TABLE-/JSON-
Werte innerhalb desselben Aufrufs, das Schema, Modulordinal 50, fünf
beziehungsweise sechs Quellenflags, Snapshotbezug und Caller-LOCK_TIMEOUT
137. Die vollständigen unabhängigen Werte eines separat aufgenommenen
Parent-Snapshots bleiben unbelegt; kein atomarer Cross-call-Vergleich wird
behauptet.

Common188 besteht 18 allgemeine und 18 native TABLE-/JSON-Fälle, sechs
gezielte NULL-Mutationsablehnungen, vier Consumerfälle, sechs Preflights,
vier synthetische Unicodefälle, drei leere SQL-CONSOLE-Captures und drei
positive direkte CONSOLE-Aufrufe. Ohne passende eigene Fixture meldet der
positive Block NOT_EXECUTED. Das Literal-Schematemplate prüft 20 Felder,
Alias, NULL-, Identity- und Collationfacetten. Native Fachwerte außer Alter
müssen im eigenen Vorher-/Nachherfenster stabil bleiben; Alter wird
begrenzt. Die drei zusätzlich abgefangenen positiven CONSOLE-Ausgaben
besitzen alle 21 Felder und die Zeilenzahlen 4/1/2. Vollständige RAW- und
CONSOLE-Fachwerte stammen aus dem privaten Consumerorakel. Mit dem
Original weist Common188 die positive Fixture nativ mit 59013
TRANSACTIONS_TABLE_JSON zurück; danach wird die finale Definition exakt
wiederhergestellt und Smoke bestätigt.

Static1015 besteht 251 tatsächliche Mutationen für lokale DDL, ABI,
Parentisolation und die späte Limitposition. Static950 behält die bisherigen
Snapshotowner. Inventar und zwei betroffene Dokumente präzisieren die
bestehenden Collations, Defaults, Joins, Zeit- und Verbraucherverträge.
Alle 75 statischen Prüfungen bestehen am eingefrorenen funktionalen Stand.
Die zehn kanonisch impact-selektierten SQL-Dateien bestehen in 30 Batches
mit 27 Resultgrids. Der unabhängige funktionale Review besitzt keine
offenen Befunde.

Private Captureannahmen werden präzisiert: Unicodepositionen beziehen sich
auf das laufende Statement statt den Batch; JsonErzeugen=NULL wird im
RAW-Modus mit Status erfasst. Eine private Patchanwendung wird vor jeder
Dateiänderung zurückgewiesen und mit einer einzelnen Updateoperation
korrigiert. Keine dieser Harnessgrenzen begründet eine weitere
Produktänderung.

OPS-005 wird kanonisch synchronisiert; Collector, Parent, OPS-Update und
beide PLAN-Installer bleiben normalisiert unverändert. Die native
Abschlussprüfung meldet null eigene Sessions, Tabellen und Regeln; die
installierte Definition entspricht der finalen Source. Eigenes Lab und
Secretdatei sind entfernt. Eine unbenutzte privat erzeugte kanonische
OPS-Updatedatei bleibt außerhalb Git erhalten, nachdem die automatische
Freigabeprüfung ihre Löschung mit blocked by policy abweist. Der Zugriff
wird nicht über einen anderen Löschweg wiederholt. Abschließende Dokumentations-, Schreibstil- und
Privacyprüfungen gehören zum Liefergate.

MARS, gebundene Transaktionen, mehrere Datenbankbindungen, isolierte
Rangties, positive Systemtransaktionen, eingeschränkte Berechtigungen,
systematische Timeoutfälle, ältere native Engines und CL150/160 bleiben
unbelegt. COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende
Maturityflags bleiben unverändert. Normalisierte SHA256: Source050
`a9a101391025f68a071c99cf1493f8a81b327ccf952975caa8fad15049c22ee1`, Common188
`8779eb12302162aef732fc71302a469a5caa486d05b444976dbc3ab1a18b26a6`, Static1015
`f88050c959f9f4a9f58775f4cf0e08946d699824fff02033f64ceb2fc73f81f9`.


## Current TempDB: einheitliche bestehende Ausgabeverträge

Der begrenzte Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Dockerlab mit gemessenem Build 17.0.4075.5 und CL170. Server und tempdb verwenden Latin1_General_100_CS_AS, das Framework SQL_Latin1_General_CP1_CS_AS. Kanonische Installation aus 166 Quellen und Smoke bestehen. Drei eigene Verbindungen halten abgeschlossene TempDB-Allokationen mit Unicodekennungen; eine zusätzliche eigene Beobachterallokation belegt den aktuellen Sessionfilter. Native Identitäten, Captures und Secretwerte bleiben außerhalb Git.

Die zwölf lokalen Tabellen umfassen 78 Felder und 23 explizite Frameworktextcollations. Sessions besitzen zwölf Felder, vier Textcollations und acht NOT-NULL-Felder; Governance besitzt 21 Felder, fünf Textcollations und drei NOT-NULL-Felder. Dateien besitzen zehn Felder, drei Textcollations und sechs NOT-NULL-Felder. Keine dieser Tabellen besitzt Identity. TABLE exportiert ausschließlich sessions und tempdbGovernance. RAW ergänzt zehn Metafelder, optionale Dateien und drei Warningfelder; JSON besitzt fünf Hauptschlüssel und elf Metafelder. CONSOLE ergänzt die bestehende Ergebnisbeschriftung. Die 13 Parameter, Sourceversion 4.0.0 mit Stand 2026-07-23, JSON-Schema 3, Inventarschema 1, Modulordinal 70 und Snapshotvertrag 2 bleiben unverändert.

Je Original- und Abschlussstand bestehen 165 unterschiedliche Fälle mit 968 Resultgrids und 34.986 beziehungsweise 34.843 Orakelprüfungen. Davon betreffen 80 Fälle eingefrorene native Consumerwerte, fünf tatsächliche Overview-Aufrufe, zwölf direkte Dateiaufrufe, 52 negative Fälle und 16 eigene beziehungsweise Systemsessionfilter. 608 unterschiedliche physische Facetten verteilen sich auf 264 SQL- und 344 SqlClient-Facetten einschließlich Dateien. Alle zwölf Sessionwerte werden unabhängig aus nativen Seitenzählern erwartet. Die 21 Governancewerte des privaten Consumerorakels stammen aus der vorhandenen nativen Collector-Snapshotprojektion; sie belegen keine neue unabhängige Governanceformel oder Durchsetzung. Alle 18 vorhandenen Quelltabellen bleiben unverändert.

Alle vier Ausgabemodi, NULL-/0-/1-/2-/INT_MAX-Limits, Dateien-, System- und aktuelle Sessionoptionen, drei einzelne Sessionfilter sowie NULL- und numerische Mindestverbrauchswerte werden geprüft. Das Original überschreitet vier TABLE-/CONSOLE-Sessionlimits und vier Governanceausgaben bei Limit 1. Tatsächliche Overview-Aufrufe bestätigen zwei weitere Sessionüberschreitungen und eine Governanceüberschreitung. 17 Sourcezeilen begrenzen die gemeinsame Menge nach N+1-Zählerabnahme und Fehlerbehandlung. HasMoreRows und ReturnedRowCount beziehen sich weiterhin ausschließlich auf Sessions. Der direkte Governancepfad behält seine frühe TOP-Vorauswahl vor der Statusbewertung; im Parentpfad folgt die gemeinsame Begrenzung auf die vollständige kopierte Governancemenge und deren Statusbewertung. Der finale Stand besitzt keine nachgewiesene Limitabweichung.

Die fünf tatsächlichen Overview-Aufrufe bestätigen am Abschlussstand alle 33 TABLE-/JSON-Fachfelder innerhalb desselben Aufrufs, vollständige Schemas, Modulordinal 70, sechs bestehende Quellenflags und Caller-LOCK_TIMEOUT 137. Ein separat erfasster atomarer vollständiger Parent-Snapshot-Wertevergleich bleibt unbelegt. Die 16 Scopefälle bestätigen sämtliche zwölf Sessionwerte sowie positive Wirkungen der aktuellen und der Systemsessionoption; ihre Erwartungen werden aus der jeweils erfassten Quelle abgeleitet, nicht durch Gleichsetzung zeitlich getrennter Original- und Abschlussquellen.

Zwölf direkte Dateifälle je Stand bestätigen alle zehn Fachfelder innerhalb desselben Consumeraufrufs, sieben stabile native Metadatenfelder und drei unabhängige Seitenarithmetikprüfungen. Je Stand werden 108 Dateizeilen erfasst. Im Original liegen 108 Verbrauchswerte innerhalb der nativen Vorher-/Nachhergrenzen; im Abschlussstand sind es 107, ein volatiler Wert liegt außerhalb. Ein atomarer vollständiger nativer Zehn-Feld-Wertevergleich wird deshalb nicht behauptet. Keine native Zeile besitzt NULL-Verbrauch; die entsprechende native Fallausprägung bleibt unbelegt.

40 semantische und acht Mappingfälle bewahren THROW 51011 und vorhandene Seedzeilen samt Schema. Vier fehlende Parentfälle melden nach Fehler 208 INVALID_PARENT_SNAPSHOT und erhalten vollständige leere TABLE-Schemas. Caller-LOCK_TIMEOUT 137 bleibt erhalten. Mindestverbrauch NULL bleibt zulässig und liefert durch den vorhandenen Vergleich eine leere verfügbare Menge; der Default 0 umfasst auch Nullverbrauch. Es entstehen keine Task- oder Version-Store-Ausgaben.

Common189 besteht zwölf allgemeine und 14 native Fälle, vier Consumerfälle, sechs Preflights, zehn Ablehnungen, drei leere SQL-CONSOLE-Captures, drei positive direkte CONSOLE-Aufrufe und zwölf gezielte NULL-Mutationsablehnungen. Ohne eigene Fixture bleibt der positive Block NOT_EXECUTED. Native Governancewerte umfassen elf unabhängig stabile Felder; alle 21 Governancefelder werden zusätzlich zwischen TABLE und JSON desselben Aufrufs verglichen. Die zusätzlich erfassten positiven CONSOLE-Schemas besitzen sämtliche 13 Session- beziehungsweise 22 Governancefelder. Der neue Vertrag weist das Original nativ mit 59211 TEMPDB_SAME_CALL_PARITY zurück; anschließend werden die finale Definition und Smoke wiederhergestellt.

Static1027 besteht 341 tatsächliche Mutationen für lokale DDL, ABI, Snapshotisolation und die späte gemeinsame Begrenzung. Der erste vollständige Lauf besteht 74 von 75 statischen Prüfungen; Static991 beanstandet die bislang ungleiche gepaarte Governanceannotation. Die bestehende ResourceGovernorAnalysis-Governancezeile erhält deshalb dieselben fünf expliziten Textcollations wie CurrentTempDBGovernance. Static991 besteht anschließend samt drei Selbsttestfällen, Static1027 erneut samt 341 Mutationen. Alle 75 Prüfungen sind damit über den vollständigen und die gezielten Folgeläufe erfolgreich nachgewiesen; ein einzelner erfolgreicher vollständiger Lauf wird nicht behauptet. Es werden genau drei Inventarzeilen mit 4/5/5 bestehenden Collations annotiert. Static950 behält sämtliche bisherigen Snapshotowner. Die zehn kanonisch impact-selektierten SQL-Dateien bestehen in 30 Batches mit 25 Resultgrids.

Private Harnesskorrekturen betreffen numerische und boolesche Typtrennung, Datums- und UUID-Normalisierung, die installerseitige CREATE-Kopfform, einen vollständig abgeschlossenen Beobachterallokationsbatch und die bit-Projektion von ReconfigurationPending im nativen Commonorakel. Die letzte Korrektur behebt eine durch gewöhnlichen Python-Wertvergleich verdeckte int-/bit-Darstellung. Diese Korrekturen erweitern den Produktumfang nicht. Der unabhängige funktionale Review besitzt keine offenen Befunde; die Dokumentation präzisiert die unterschiedliche frühe und späte Governancebegrenzung.

OPS-005 wird kanonisch synchronisiert. Collector, Parent, ResourceGovernor-Source, OPS-Update und beide EXECUTION-PLAN-001-Installer bleiben normalisiert unverändert. Die native Abschlussprüfung meldet null eigene Sessions, temporäre Tabellen, Governancegruppen und Governancebenutzer; die installierte Definition entspricht der eingefrorenen Source. Eigenes Lab und Secretdatei sind entfernt. Private erzeugte Installer- und Capturebelege bleiben außerhalb Git. Abschließende Dokumentations-, Schreibstil- und Privacyprüfungen gehören zum Liefergate.

Atomare volatile Dateiverbrauchswerte, native NULL-Dateiverbrauchswerte, zusätzliche Governancekonfigurationen und Durchsetzungsfälle, eingeschränkte Berechtigungen, systematische Timeoutfälle, ältere native Engines und CL150/160 bleiben unbelegt. COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende Maturityflags bleiben unverändert. Normalisierte SHA256: Source070 `7efb551e7c0c9094f8b061f887042911786fece3116bfb0011f51ab957791063`, Common189 `a5624ee40a8507ec8cfa195fad6d58300be29f23fba055dc9440203834d68220`, Static1027 `7db68fa946fffc40a874893c10c752679bab7e6efba05ef7f47b77b8e24f17ec`.


## Current IO: einheitliche bestehende Ausgabeverträge

Der begrenzte Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Dockerlab mit gemessenem Build 17.0.4075.5 und CL170. Server und tempdb verwenden Latin1_General_100_CS_AS, das Framework SQL_Latin1_General_CP1_CS_AS. Kanonische Installation aus 166 Quellen und Smoke bestehen. Zwei eigene Datenbanken mit unterschiedlichen Unicode-Groß-/Kleinschreibungen verwenden Latin1_General_100_CI_AS, je zwei Datendateien und eine Logdatei. Abgeschlossene eigene Schreibaktivität liefert sechs positive native Dateien; ein zeitlich begrenzter eigener Schreiber erzeugt zusätzliche Stichprobendeltas. Native Identitäten, Pfade, Captures und Secretwerte bleiben außerhalb Git.

Die 16 lokalen Tabellen besitzen 128 Felder und 35 explizite Frameworktextcollations. Die fünf bestehenden Exporte umfassen 65 Felder mit 23 Textcollations und 40 NOT-NULL-Feldern: moduleStatus 13, sourceStatus zehn, files 19, pendingIo 20 und warnings drei. Keine dieser Tabellen besitzt Identity. RAW und TABLE verwenden diese fünf Schemas; JSON besitzt fünf Hauptschlüssel und 14 Metafelder, jedoch kein separates moduleStatus-Array. CONSOLE besitzt weiterhin zehn Fachspalten mit gemeinsamer TOP-Grenze und Pending-I/O-Vorrang. Der leere CONSOLE-Ausgang besitzt drei Statusspalten. Die 18 Parameter, Sourceversion 4.0.0 mit Stand 2026-07-23, JSON-Schema 3, Inventarschema 2, Modulordinal 80 und Snapshotvertrag 2 bleiben unverändert.

Je Original- und Abschlussstand bestehen 131 unterschiedliche Fälle. Der Originalstand umfasst 730 Resultgrids und 19.452 Orakelprüfungen, der Abschlussstand 742 Grids und 19.398 Prüfungen. Davon betreffen 20 Fälle die vier Ausgabemodi mit NULL-/0-/1-/2-/INT_MAX-Limits, 88 Fälle Parameter-, Parent- und TABLE-Preflightgrenzen, 14 Fälle Datenbank- und Latenzfilter, fünf Fälle tatsächliche Overview-Aufrufe und vier Fälle Stichprobendeltas. Zusätzliche Charakterisierungsaufrufe und überlappende Negativfälle werden nicht erneut gezählt. 1.105 unterschiedliche physische Schemafacetten verteilen sich auf 585 SQL- und 520 SqlClient-Facetten aller 65 Exportfelder. SQL-Ordinale werden relativ geprüft, da die vorhandene Zieltabellenumschreibung absolute column_id-Werte verschieben darf.

Das Original überschreitet zwei direkte TABLE-Dateilimits und zwei weitere TABLE-Dateilimits im tatsächlichen Parent. Die bestehende N+1-Vorauswahl und Zählerabnahme bleiben erhalten. Eine gemeinsame späte Begrenzung der Datei- und Pendingmengen nach Fehlerbehandlung stellt die gleiche Consumergrenze her. Sämtliche nachgewiesenen Dateilimitabweichungen entfallen. Positive native Pendingzeilen werden nicht beobachtet; eine positive Wirkung ihrer Mengenbegrenzung bleibt daher unbelegt. Die bestehende CONSOLE-Gesamtgrenze wird nicht durch Addition der beiden getrennt begrenzten JSON-Arrays ersetzt.

Die native Dateiprüfung umfasst sämtliche 19 Felder. Im Original werden 159 und im Abschlussstand 157 Consumerdateizeilen geprüft. Sechs Zähler liegen jeweils innerhalb nativer Vorher-/Nachhergrenzen; stabile Quellen ermöglichen die entsprechende exakte Gleichheit. Sechs Katalogfelder und die Dateigröße werden unabhängig erwartet. Drei Latenzen stammen aus eigener Dezimalarithmetik, zwei Durchsatzfelder bleiben bei SampleSeconds 0 NULL. Die vier Stichprobenfälle je Stand erfassen zwölf positive Operationszeilen, prüfen sechs Deltazähler gegen die äußere native Messklammer sowie Katalogwerte, Größe, Latenzen und Durchsatz. Der Durchsatz verwendet die konfigurierte Sekunde, nicht die gemessene Gesamtlaufzeit. Gemessene Aufrufzeiten liegen im Original zwischen 1.041 und 1.133 Millisekunden, im Abschlussstand zwischen 1.035 und 1.274 Millisekunden. Native Logdateiwachstumswerte werden begrenzt geprüft. Ein atomarer vollständiger Vergleich zeitlich getrennter DMV-Aufnahmen wird nicht behauptet.

Die 14 Filterfälle erhalten exakte Groß-/Kleinschreibung, bracketed Namen, LIKE, fehlende und gemischte Namen, den Userdatenbankdefault und die Systemdatenbankoption. Doppelte exakte Namen bleiben INVALID_PARAMETER. Mindestlatenz NULL bleibt ungültig; Mindestlatenz 0 schließt fehlende Operationslatenzen weiterhin durch den bestehenden NULL-Vergleich aus. Positive und hohe Mindestlatenzen werden geprüft. Alle sechs nativen Dateizähler, Katalogwerte, Größen und Latenzformeln werden auch für sämtliche 61 Filterdateizeilen je Stand geprüft; 60 Zeilen besitzen stabile Zähler.

Die fünf tatsächlichen Overview-Aufrufe bestätigen am Abschlussstand alle 19 TABLE-/JSON-Dateifelder desselben Aufrufs, vollständige Schemas, Modulordinal 80, vier vorhandene Quellenflags REQUESTS, WAITING_TASKS, TASKS und SCHEDULERS sowie Caller-LOCK_TIMEOUT 137. Modul- und Snapshotstatus werden vollständig innerhalb desselben Aufrufs verglichen. Die Datei- und Pending-DMVs werden weiterhin frisch gelesen. Ein separat erfasster atomarer vollständiger Parent-Snapshot-Vergleich bleibt unbelegt; zusätzliche Snapshotowner entstehen nicht.

64 semantische Fälle, acht fehlende beziehungsweise fremde Parentfälle und 16 Mappingfälle belegen bestehende Fehlergrenzen. Das Original erzeugt bei NULL-SampleSeconds und NULL-PendingIoEinbeziehen acht Fehler 515. Der Abschlussstand normalisiert ausschließlich die beiden NOT-NULL-Modulstatusfelder auf typisierte 0-Werte; die JSON-Metadaten bewahren die tatsächlichen NULL-Argumente und INVALID_PARAMETER. Das Original überspringt acht kombinierte semantische Mappingprüfungen. Die bestehende TABLE-Vorbereitung liegt nun vor der semantischen Prüfung: alle 16 fehlerhaften Mappingfälle melden THROW 51011, Seedzeilen und Schema bleiben erhalten. Tatsächlich angeforderte, gültig gemappte negative TABLE-Ausgänge besitzen vollständige leere Schemas. Fehlende beziehungsweise fremde Parents bleiben INVALID_PARENT_SNAPSHOT nach Fehler 208 beziehungsweise 51020. Caller-LOCK_TIMEOUT 137 bleibt erhalten.

Common190 besteht 23 allgemeine und 14 bedingte native Dateifälle, vier Consumerfälle, sechs Preflights, drei leere SQL-CONSOLE-Captures, drei direkte positive CONSOLE-Statusfälle und drei tatsächliche NULL-Mutationsablehnungen. Ohne eigene Fixture bleiben die nativen Fälle NOT_EXECUTED. Der private SqlClient-Nachweis bestätigt alle zehn bestehenden CONSOLE-Felder samt Schema und die Zeilenzahlen sechs, eins und zwei. Der neue Commonvertrag weist die tatsächlich erneut installierte Originaldefinition nativ mit 59301 CURRENT_IO_LITERAL_SCHEMA zurück; anschließend werden die finale Definition und Smoke wiederhergestellt. Drei Testorakelkorrekturen betreffen den tatsächlichen UUID-String, unabhängig begrenzte Evidence- und Collection-Zeiten sowie den bestehenden Filtertext des verfügbaren leeren CONSOLE-Ausgangs. Diese Korrekturen ändern den Produktvertrag nicht.

Static1037 besteht 524 tatsächliche Mutationen für vollständige lokale DDL, ABI, Snapshotisolation, TABLE-Preflight und die späte gemeinsame Begrenzung. Ein vollständiger statischer Lauf besteht alle 75 Prüfungen. Die fünf Inventarzeilen ergänzen ausschließlich fehlende bestehende Frameworkcollations. Static950 behält sämtliche bisherigen Snapshotowner. Alle zwölf kanonisch impact-selektierten SQL-Dateien bestehen am Abschlussstand in 36 Batches mit 55 Resultgrids. Der erste Impactversuch scheitert mit dem veralteten Common-Metaguard des zuvor zusammengesetzten privaten Runners. Der anschließend aus dem eingefrorenen Abschlussstand neu erzeugte Runner besteht.

OPS-005 wird kanonisch synchronisiert. Collector, Parent, OPS-Update und beide EXECUTION-PLAN-001-Installer bleiben normalisiert unverändert. Die installierte finale Definition entspricht vollständig der eingefrorenen Source nach alleiniger Normalisierung der nativen CREATE-Kopfform. Die native Abschlussprüfung bestätigt ursprüngliche Datenbankidentitäten und Optionen, alle wiederhergestellten eigenen Datenzeilen sowie null eigene Schreibersessions und temporäre Tabellen. Beide eigenen Datenbanken werden nach erneuter Identitätsprüfung entfernt; eigenes Lab und Secretdatei sind entfernt. Private erzeugte Installer- und Capturebelege bleiben außerhalb Git. Der unabhängige funktionale Review besitzt keine offenen Befunde. Abschließende Dokumentations-, Schreibstil- und Privacyprüfungen gehören zum Liefergate.

Positive native Pending-Handle-, Scheduler-, Pfad- und Wiederholungswerte, positive Pendinglimitwirkungen, eingeschränkte Berechtigungen, systematische Timeoutfälle, ältere native Engines und CL150/160 bleiben unbelegt. COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende Maturityflags bleiben unverändert. Normalisierte SHA256: Source080 `d92dcdf38e20c8993a1a02cce9d4a77efd2b9b5541411ea3bea180a01f7d9901`, Common190 `b50dc8a10d8f2ecb9c4101353bfa2584cc873144a2318573328f66eb9625304a`, Static1037 `5d960ce5d39bc69b13557c1e6fbf822c95bb72ff87df39415b1ad09a529fa696`.


## Current Log: einheitliche bestehende Ausgabeverträge

Der begrenzte Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Dockerlab mit gemessenem Build 17.0.4075.5 und CL170. Server und tempdb verwenden Latin1_General_100_CS_AS, das Framework SQL_Latin1_General_CP1_CS_AS. Kanonische Installation aus 166 Quellen und Smoke bestehen. Zwei eigene Datenbanken mit unterschiedlichen Unicode-Groß-/Kleinschreibungen verwenden Latin1_General_100_CI_AS und CL170; ADR ist bei einer Quelle deaktiviert, bei der anderen aktiviert. Abgeschlossene eigene Schreibaktivität erzeugt positive Logwerte und PVS-Kontext. Native Identitäten, Captures, Pfade und Secretwerte bleiben außerhalb Git.

Vier lokale Tabellen besitzen 37 Felder mit 20 expliziten Frameworktextcollations und zwölf NOT-NULL-Feldern. Der bestehende logs-Export besitzt 19 Felder, acht Textcollations und sechs NOT-NULL-Felder ohne Identity. RAW liefert zehn Modulfelder, die 19 Logfelder und fünf Teilquellenfehlerfelder. JSON besitzt vier Hauptschlüssel und 13 Metafelder; databaseStatus enthält ausschließlich Teilquellenfehler. Die aktive generische CONSOLE besitzt 20 Felder einschließlich Beschriftung, ihr leerer Ausgang drei Hinweisfelder. Der private Client prüft die 19 gemeinsamen Schemafelder sowie Beschriftungs- und Leerschema getrennt. Die 14 Parameter, Sourceversion 2.0.0 mit Stand 2026-07-15, JSON- und Inventarschema 1 sowie Modulordinal 90 bleiben unverändert.

Je Original- und Abschlussstand bestehen 117 unterschiedliche Fälle mit 767 Resultgrids. Der Originalstand umfasst 18.986 Orakelprüfungen, der Abschlussstand 18.984. 63 Fälle betreffen direkte Consumer, Mengen-, Prozent- und Datenbankfilter, Parameter und optionale VLF-/PVS-Pfade; 46 weitere Fälle betreffen Mappingpriorität und vorhandene Seedziele, fünf tatsächliche Overview-Aufrufe die Parentverträge und drei Zusatzfälle positive Prozentgrenzen sowie vollständige Auswahlwarnings bei begrenzter Ausgabe. 323 unterschiedliche physische Schemafacetten verteilen sich auf 171 SQL- und 152 SqlClient-Facetten der 19 Logfelder. SQL-Ordinale werden relativ geprüft. Die Parentausgabe bestätigt zusätzlich dieselben 152 Clientfacetten; diese werden nicht erneut zur kanonischen Facettenzahl addiert.

Das Original überschreitet fünf tatsächlich beobachtete TABLE-/CONSOLE-Limits: direkte TABLE- und CONSOLE-Ausgabe, Overview-TABLE, positive Prozentgrenze mit Limit und gemischter vollständiger Datenbankscope mit fehlendem Namen. Zehn neue Sourcezeilen begrenzen ausschließlich die bestehende Logmenge nach vollständiger Sammlung, Prozentfilter, Zähler-, Status- und Detailbewertung. Die Auswahl UsedLogPercent DESC, DatabaseName bleibt erhalten; RAW und JSON sortieren ausdrücklich, TABLE und generische CONSOLE erhalten keinen zusätzlichen Zeilenordnungsvertrag. Alle nachgewiesenen Limitabweichungen entfallen. NULL und 0 bleiben unbegrenzt, negative Limits INVALID_PARAMETER mit internem Limit 0. Kandidaten, Fehler, Auswahlwarnings, Detailtexte und frühere Datenbankarbeit bleiben vollständig.

Die native Feldprüfung erfasst je Stand 65 eigene Consumerlogzeilen. Datenbankidentität, Recovery Model, Reuse-Wait und ADR stammen aus dem nativen Katalog. Vier Logspacewerte und fünf Logstatistikwerte werden unabhängig aus nativen Quellen projiziert; Prozentwerte stammen direkt aus der nativen Prozentquelle und nicht aus gerundeten MB. Zahlen liegen in gemessenen Vorher-/Nachhergrenzen, Text- und Datumswerte entsprechen beobachteten Grenzen. Die direkten Corefälle besitzen eindeutig getrennte Prozentintervalle und bestätigen dadurch den nativen Rang. Am Abschlussstand werden gleiche TABLE-/JSON-Werte desselben Aufrufs vollständig über alle 19 Felder einschließlich Typen und NULLs verglichen; das begrenzte Original besitzt ausdrücklich zusätzliche TABLE-Zeilen. Getrennte native Quellenaufnahmen werden nicht als atomare Momentaufnahme behandelt.

Der bestätigte VLF-Pfad liefert AVAILABLE und native VLF-Anzahlen; ohne Bestätigung bleibt HIGH_IMPACT_CONFIRMATION_REQUIRED mit leerer Basismenge. Damit werden in diesem verweigerten Fall auch die Basiswerte nicht erfasst. Standardmäßig bleiben VLF und PVS SKIPPED; NULL-VLF bleibt SKIPPED, NULL-PVS PENDING ohne Abfrage. Aktiviertes PVS liefert bei deaktiviertem ADR NOT_APPLICABLE und NULL, bei aktiviertem ADR AVAILABLE mit unabhängig gemessenem PVS-Wert. Je Stand werden zwei positive PVS-Consumerzeilen beobachtet. LogBackupTime übernimmt den nativen datetime-Wert ohne UTC-Umdeutung. Ein fehlender Logstatistikwert mit tatsächlich genutztem VLF-Count-Fallback bleibt unbelegt.

Exakte Groß-/Kleinschreibung, bracketed Namen, LIKE, REGEX und REGEXI, umgekehrte Reihenfolge, fehlende und gemischte Namen, doppelte Namen sowie NULL-/Leer-/Leerzeichen-Auswahl werden nativ geprüft. Fehlende Namen bleiben ERROR_HANDLED, gemischte Namen PARTIAL_RESULT mit DATABASE_UNAVAILABLE-Warnung; doppelte Namen und gleichzeitige Liste/Pattern bleiben INVALID_PARAMETER. Positive Prozentgrenze 10 und Grenze 100 verwenden eine unabhängige native Auswahlerwartung. Die Belegung verändert sich während der längeren Prüfphase: frühe Zusatzfälle wählen bei Grenze 10 eine Quelle, spätere gepaarte Aufrufe zwei Quellen. Zwei private feste Ausgabemengenannahmen scheitern deshalb und werden auf die bereits vorhandenen nativen Auswahl- und Limitbedingungen korrigiert. Der Produktcode bleibt dabei unverändert. Der abschließende Original-/Finalvergleich der drei Zusatzfälle besitzt je zwei, eine und eine JSON-Zeile; die vollständige fehlende-Datenbank-Warnung und ihr Detailtext bleiben bei Limit 1 erhalten.

44 Mappingfälle melden tatsächlich THROW 51011 vor semantischen Fehlern beziehungsweise Hilfe und erhalten Seedwert, Seedspaltenschema, Caller-OUTPUT und LOCK_TIMEOUT 137. Zwei weitere ungültige Ausgabeformen ohne nichtleeres Mapping liefern normal INVALID_PARAMETER und erhalten das vorhandene Seedziel. Gültig gemappte negative TABLE-Ausgaben besitzen das vollständige leere Logschema. Die fünf tatsächlichen Overview-Aufrufe bestätigen vollständige 19-Feld-Parität am Abschlussstand, Clientfacetten, neun Modulstatuszeilen, Modulordinal 90 und Caller-LOCK_TIMEOUT 137. Logs-only erzeugt snapshotStatus [] und evidenceSnapshotId NULL; Logs werden weiterhin frisch gelesen. Es entsteht kein zusätzlicher Snapshotowner.

Common191 besteht 36 allgemeine und 41 bedingte native Fälle, vier Consumerfälle, sechs Preflights, sechs leere SQL-CONSOLE-Captures, fünf direkte positive CONSOLE-Status-/JSON-Fälle und sechs tatsächliche NULL-Mutationsablehnungen. Der Lauf ohne Fixture besitzt 44 Grids und NOT_EXECUTED für den nativen Block, der eigene Fixturelauf 104 Grids sowie getrennte PASS-Werte für VLF und PVS. Vollständige positive Clientgrids stammen aus dem gesonderten Rootnachweis. Das tatsächlich erneut installierte Original wird nativ mit 59411 LOG_TABLE_JSON_PARITY zurückgewiesen; anschließend werden Abschlussdefinition und Smoke wiederhergestellt. Ein zusätzlicher privater RAW-Zeitvergleich normalisiert lediglich gleichwertige ISO-Darstellungen mit beziehungsweise ohne nachgestellte Bruchteilsnullen. Eine reservierte unquotierte RowCount-Testaliasstelle wird im privaten Integritätsharness korrigiert.

Static1028 besteht 303 tatsächliche Mutationen für lokale Literal-DDL, ABI, native Formeln, frühes Mapping und späte Begrenzung. Der frühere bloße Erfolgsdruck des Selbsttests entfällt. Ein vollständiger statischer Lauf besteht alle 75 Prüfungen. Alle zehn kanonisch impact-selektierten SQL-Dateien bestehen in 30 Batches mit 65 Resultgrids. Die einzelne logs-Inventarzeile ergänzt sieben bereits bestehende Frameworkcollations. Dokumentationsänderungen berichtigen Datenbankgranularität, Leerparameter, Standardgate, VLF-/PVS-Semantik und Reihenfolge der Begrenzung.

OPS-005 wird kanonisch synchronisiert; Collector, Parent, OPS-Update und beide EXECUTION-PLAN-001-Installer bleiben normalisiert unverändert. Installierte Original- und Abschlussdefinition stimmen vollständig mit den jeweiligen Sourceheadern und Bodies überein; ausschließlich kanonischer Quellenpräfix, native CREATE-Kopfform, Runtime-Datenbankplatzhalter und Zeilenenden werden normalisiert. Die Abschlussprüfung bestätigt ursprüngliche eigene Datenbankidentitäten und Optionen, 4.000 unveränderte Testzeilen, IdSum 2.001.000 je Datenbank und null offene Benutzertransaktionen. Beide eigenen Datenbanken werden identitätsgeprüft entfernt; eigenes Lab und Secretdatei sind entfernt. Private erzeugte Installer- und Capturebelege bleiben außerhalb Git. Der unabhängige funktionale Review besitzt keine offenen Befunde. Abschließende Dokumentations-, Schreibstil- und Privacyprüfungen gehören zum Liefergate.

Eingeschränkte Berechtigungen, systematische Timeout- und Quellenfehler, tatsächlich genutzter VLF-Fallback, allgemeine volatile Filter- oder Ranggleichheiten, ältere native Engines und CL150/160 bleiben unbelegt. COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende Maturityflags bleiben unverändert. Normalisierte SHA256: Source090 `0e64861c1de940c49e16db5a23cc8e82279385b645db064091d1bebcd8af87b7`, Common191 `d6249fed8c638f28b8c2e216ad15833bcdffd0dcd14a0bc0e93c982026bb41bf`, Static1028 `a5c0acadcc1c354b6b9dc19460f60a29c240d58b72b8472edd8be3042307ead8`.


## Current Overview: Mappingpriorität und partielle Parameterablehnung

Der begrenzte Nachweis vom 7. Oktober 2026 verwendet ein eigenes SQL-Server-2025-Dockerlab mit gemessenem Build 17.0.4075.5 und CL170. Server und tempdb verwenden Latin1_General_100_CS_AS, das Framework SQL_Latin1_General_CP1_CS_AS. Kanonische Installation aus 166 Quellen und Smoke bestehen. Vier eigene Unicode-Sessions erzeugen drei kontrollierte Blockingkanten und offene Transaktionen in drei eigenen Frameworktabellen. Eine eigene nicht standardmäßige Toolregel erlaubt die Prüfung der bestehenden Toolauswahl. Zusätzliche Quelldatenbanken werden nicht angelegt. Native Identitäten, Captures und Secretwerte bleiben außerhalb Git.

Die 38 lokalen Tabellen besitzen 303 Felder und 50 explizite Frameworktextcollations. Die 17 bedingten TABLE-Exporte umfassen im aktivierten Zustand 540 Felder. Parentstatus besitzt acht Felder mit vier Textcollations und sieben NOT-NULL-Feldern, Snapshotstatus elf mit vier Textcollations und neun NOT-NULL-Feldern, Warnings drei mit drei Textcollations und zwei NOT-NULL-Feldern. Die 31 Parameter, Sourceversion 4.1.0 mit Stand 2026-07-23, JSON-Schema 4, Inventarschema 1 und bestehende Snapshotowner bleiben unverändert. Alle neun Children werden weiterhin einmal und sequenziell aufgerufen.

Je Original- und Abschlussstand werden 105 unterschiedliche Fälle geprüft: 50 positive Consumer-, Detail-, Einzelmodul-, Deaktivierungs- und Optionsfälle sowie 55 negative Mapping- und Parameterfälle. Das Original besitzt 1.771 Resultgrids und 300.838 Orakelprüfungen, der Abschlussstand 1.769 Grids und 299.342 Prüfungen. 9.720 unterschiedliche physische Schemafacetten verteilen sich auf 5.400 SQL- und 4.320 SqlClient-Facetten aller 540 aktivierten Felder. SQL-Ordinale werden relativ geprüft. Wiederholte Setup- und Charakterisierungsläufe werden nicht als zusätzliche Fälle gezählt.

Das Original unterdrückt 32 fehlerhafte Mappings durch frühere Hilfe-, Parameter- oder Ausgabeentscheidungen. Sieben gültige TABLE-Mappings erhalten bei Parameterablehnung nur das Seed-Schema. 34 ungültige JSON-Ausgänge besitzen eine partielle Modulzeile, aber nichtpartielle Gesamtmetadaten. Diese drei Beobachtungsmengen überlappen; ihre 73 Einträge sind keine 73 unterschiedlichen Fälle. Die bestehende Zuordnungsvorbereitung liegt jetzt vor Hilfe und semantischer Prüfung, wenn TABLE oder eine nichtleere Zuordnung angefordert wird. Die einzige weitere Produktkorrektur berücksichtigt INVALID_PARAMETER bei JSON isPartial.

Alle 40 fehlerhaften Mappingfälle werfen am Abschlussstand 51011 und erhalten Seedwerte, Seed-Schema und Caller-LOCK_TIMEOUT 137. Die bereits bestehende frühe interne JSON-Nullung bleibt erhalten; bei einem THROW ist der außerhalb beobachtete OUTPUT-Sentinel kein Nachweis eines intern erhaltenen JSON-Wertes. Die sieben gültig gemappten TABLE-Ablehnungen besitzen sämtliche acht Statusfelder mit nativen Facetten und erwarteten Werten. Zehn verbleibende ungültige JSON-Ausgänge bestätigen sämtliche Statuswerte, zehn Metafelder, Typen, leere Snapshot-/Warningmengen und isPartial true. Hilfe exportiert nichts. Nicht-TABLE-Modi mit gültiger Zuordnung bleiben normale Parameterablehnungen, soweit keine Hilfe angefordert ist.

Die vier Ausgabemodi, SUMMARY/RELEVANT/ALL, NULL-/0-/1-/2-/INT_MAX-Limits, neun Einzelmodule, alle deaktivierten Module, Text- und Inputbufferoptionen, Toolauswahl, ungültige Sessions, doppelte Sessions, fehlende Datenbankauswahl und Blocking-DEEP mit beziehungsweise ohne Bestätigung werden geprüft. Die sechs Summaryfelder entsprechen vollständig den Statuswerten desselben Aufrufs. RAW bestätigt die elf Snapshot- und drei Warningfelder; positive CONSOLE-Details werden als vollständige erwartete Gridmenge samt Feldnamen und Werten geprüft. Mengenlimits gelten je Child und kürzen die neun Modulstatuszeilen nicht. Deaktivierte oder nicht materialisierte Childziele behalten ihre bestehenden bedingten Seed-Verträge.

Der private Client vergleicht alle gemeinsamen TABLE-/JSON-Werte derselben Aufrufe als typisierte, NULL-erhaltende Multisets. Die Legacy-Requests besitzen 93 TABLE-Felder, aber nur 50 direkte JSON-Wertprojektionen; die zusätzlichen 43 TABLE-Werte sind hier ausschließlich schemaabgesichert. Die vier zusätzlichen Requestmengen besitzen vollständige 73/19/15/13-Feld-Parität. Sessions besitzen 51 direkte Werte und drei zusätzliche Waitproperties, Requests zwei zusätzliche Waitproperties. Diese zusätzlichen Helperproperties werden im privaten Client nur über ihre Namen geprüft; ihre unabhängigen Interpretationswerte sind kein Teil dieses Nachweises. Positive Memory-Grant-Zeilen werden nicht beobachtet; dessen 63-Feld-Schema ist vollständig geprüft.

Modulreihenfolge, Status, Fehler- und Partialitätszähler, übersprungene Module, Child-Fehlerisolation, Gesamtstatus und Snapshot-ID-Wiederverwendung werden geprüft. Ungültige beziehungsweise doppelte Sessionlisten können den bestehenden TempDB-Childfehler auslösen; Overview isoliert ihn mit ERROR_HANDLED, partiellem Status und JSON null. Dieser Childvertrag wird nicht geändert. Snapshotquellenflags, Quellcodes, Ordinale und gemeinsame IDs sind geprüft. Eine separate vollständige native Snapshot-Wertprüfung, atomare Zeitgleichheit, unabhängige SourceObject-/Zeitwerte und sämtliche Helperinterpretationen bleiben unbelegt. Logs-only und alle deaktivierten Module besitzen keine Snapshot-ID und keine Snapshotstatuszeilen.

Common192 besteht 43 allgemeine und 14 bedingte native Fälle, fünf beziehungsweise sechs Consumerfälle, 40 Mappingpreflights und drei echte NULL-Mutationsablehnungen gegen eine zuvor unabhängig geprüfte echte Modulzeile. Ohne Fixture besitzt der Lauf acht Grids und NOT_EXECUTED für den positiven Block; mit eigener Fixture 25 Grids und PASS. Das tatsächlich erneut installierte Original wird nativ mit 59505 OVERVIEW_META zurückgewiesen; die Originalgegenproben belegen dabei die falsche Gesamtpartialität. Anschließend werden die eingefrorene Abschlussdefinition und Smoke wiederhergestellt. Vollständige Original- und Abschlussheader samt Bodies und alle 31 nativen Parameterfacetten sind geprüft. Die finalen Moduleinstellungen ANSI_NULLS und QUOTED_IDENTIFIER sind nativ eingeschaltet; die ursprünglichen Einstellungen wurden im ersten Originalcapture nicht erfasst.

Static1041 besteht 1.083 tatsächliche Mutationen für vollständige Literal-DDL, ABI, Childrouting, Mappingpriorität, Snapshotflags, JSON und Consumer. Doppelte identische DDL- beziehungsweise Child-Aufrufe werden explizit gezählt und abgewiesen. Ein vollständiger Lauf besteht alle 75 statischen Prüfungen. Die neun kanonisch impact-selektierten SQL-Dateien bestehen in 28 Batches mit 28 Resultgrids einschließlich der bestehenden Output- und Snapshotintegration. Drei Inventarzeilen annotieren ausschließlich zehn bisher fehlende bestehende Textcollations. Die Dokumentation berichtigt Childnamen, Statusschemas, bedingte Exporte, gemeinsame Primärquellen und Blocking-DEEP.

Private Harnesskorrekturen betreffen sechs zunächst gleich ausgeführte Detailfälle, die anschließend mit den tatsächlichen vier Modi neu erfasst werden, sowie eine PowerShell-Aufzählung leerer byte-Arrays, die fälschlich NULL lieferte. Quellenflags, SQL_TEXT-Ordinal 160 bei fehlender Erhebung und der abgefangene TempDB-Child werden gegen den bestehenden Sourcevertrag korrigiert. Der unabhängige Review schließt private Prüflücken bei Gesamtstatus, verlorenen positiven Seedexporten, fehlendem Pflicht-JSON, verkürzten Facetten und zusätzlichen Detailgrids. Geänderte Capturekopien werden im Speicher abgewiesen; doppelte verschachtelte JSON-Schlüssel und boolesche Zahlenwerte werden zusätzlich geprüft. Ein erster finaler Negativlauf enthält Lock-Timeout 1222; die anschließende sequentielle Wiederholung besteht. Die Ursache dieses Timeouts bleibt offen. Der erste private Freezeimport nimmt fälschlich eine flache JSON-Struktur an; der anschließende Import des vorhandenen normalizedSHA256-Objekts bestätigt alle sieben Dateien. Testinterne Unicode- und Mutationskorrekturen erfolgen vor dem Freeze. Keine dieser Harnesskorrekturen erweitert den Produktumfang.

OPS-005 wird kanonisch synchronisiert. Der neue Sourcebody erscheint exakt einmal; dessen Rücktausch ergibt vollständig den Basisinstaller. Collector, CurrentLog, OPS-Update und beide EXECUTION-PLAN-001-Installer bleiben normalisiert unverändert. Die native Abschlussprüfung bestätigt null eigene Sessions, Tabellen und Regeln; die Fixturetabellen werden nach Identitäts- und Wertprüfung entfernt. Die installierte Abschlussdefinition entspricht nach Regression und Impact erneut der eingefrorenen Source. Eigenes Lab und Secretdatei sind entfernt; private Installer- und Capturebelege bleiben außerhalb Git. Der unabhängige funktionale Review besitzt keine offenen Befunde. Abschließende Dokumentations-, Schreibstil- und Privacyprüfungen gehören zum Liefergate.

Positive Grants, vollständige zusätzliche Legacy-Requestwerte, unabhängige Snapshot-/Helperwerte, weitere Sample- und Rangtievarianten, eingeschränkte Berechtigungen, systematische Timeout- und Quellenfehler, ältere native Engines und CL150/160 bleiben unbelegt. COLL-001 bleibt partiell; Registry, RUNTIME-001 und bestehende Maturityflags bleiben unverändert. Normalisierte SHA256: Source100 `c5172fc2ebdfc3b90650f97cd21d7f0a055c4990decc232f2b570b001736a1a0`, Common192 `da97f09ac3e1c6a221fb6091ad5c92e83735d6e84be78d9b094cc9468f67170d`, Static1041 `462bedc99a6ae7e4cd1e00c6b8d2de627ec052a528219667464dea4788ad9e25`.

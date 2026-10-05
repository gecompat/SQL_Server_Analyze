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

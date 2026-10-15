# WI-0004: Begrenzte Columnstore-Segmentüberlappung

**Stand:** 15. Oktober 2026  
**Umfang:** der konkret freigegebene lesende Opt-in-Vertrag von
`monitor.USP_Columnstore` 1.2.0; die bestehende Ordering-Inventur bleibt erhalten.

## Qualifizierter Umfang

Eigene synthetische Columnstore-Tabellen mit 13 Spaltentypen und zwei
Bulkbatches mit jeweils 102400 Zeilen erzeugen 26 native Segmente. Die
Aufnahme wird vor den Assertions behalten. Ein unabhängiger vollständiger
Paarvergleich prüft alle vergleichbaren Gruppen gegen die begrenzte
Endpunktzählung. Die vier TABLE-/JSON-Fälle liefern auf SQL Server 2025 und
2022 jeweils 13, 13, 1 und 13 Gruppen. Sie prüfen Schlüssel, native Counts,
NULL-Metriken unvollständiger Gruppen und denselben physischen JSON-Aufruf.
Alle 19 Spalten werden mit einem unabhängig deklarierten nativen
Vertragsschema verglichen. Der Vergleich verwendet logische Ordinale;
physische Katalog-IDs und die vollständigen Metadaten bleiben diagnostisch
erhalten. Native Encodings 2 und 3 sind beobachtet; daraus folgt kein
positiver nativer Nachweis für die Encodings 1 oder 5.

Ohne Opt-in bleibt JSON-Schema 1 ohne neue Menge erhalten. Der N+1-Sentinel
unterdrückt die gesamte neue Berechnung und meldet die beobachtete
Mindestmenge als Limitüberschreitung. Ungültige Grenzen und Scopeparameter
haben Vorrang vor dem Versionsfallback. Auf SQL Server 2019 liefert der
aktivierte Pfad vier leere typisierte Exporte mit JSON-Schema 2 und
UNAVAILABLE_VERSION für die neue Quelle. Die leere native FOR-JSON-
Serialisierung ist dort NULL. Nur bei unabhängig gezählter Tabellenmenge
null, Majorversion kleiner 16 und tatsächlichem NULL-Scalar wird sie im
Test als leeres Array verglichen. Der rohe Wert, Count und JSON-Ausdruck
werden vor der Assertion gespeichert. Nichtleere NULL-Ausgaben, fehlende
JSON-Mengen und sonstige Abweichungen bleiben Fehler.

Vierzehn private Procedurekopien erhalten die tatsächliche Berechnung und
ersetzen ausschließlich die neue Quelle durch ausdrücklich synthetische
Intervalle. Sie prüfen unter anderem negative und extreme Werte,
Punktintervalle, Grenzberührungen, unvollständige Gruppen, inkonsistente
Collationwerte, doppelte Identitäten und den vollständigen Quellenverzicht
bei Überschreitung. RAW und CONSOLE prüfen an diesen Kopien acht
beziehungsweise ein Produktresultset. Diese Fälle sind keine positive
native Katalogqualifikation ihrer eingesetzten Werte oder Encodings.
Ein direkt erzeugter nativer Fehler 208 wird mit dem gleichen fehlenden
Objekt und demselben Caller-/Datenbankkontext erhoben; die Kopie erhält das
Fehlerpaar exakt und bewahrt andere Quellen. Das belegt keinen tatsächlich
erzeugten Katalog-Berechtigungsfehler. Acht ungültige Parameterfälle werden
am ursprünglichen Produkt separat geprüft.

## Native Enginebindung

| Engine | Native Version und Compatibility Level | Gesamtversuch | Beobachtete Laufzeit |
|---|---|---|---|
| SQL Server 2025 | 17.0.4075.5 / CL170 | 2 | 44.5043179 s |
| SQL Server 2022 | 16.0.4265.3 / CL160 | 5 | 42.3522217 s |
| SQL Server 2019 | 15.0.4480.2 / CL150 | 7 | 40.7042834 s |

Der zusätzliche SQL-2022-Lauf prüft die erste unterstützte native
Metadatengeneration. SQL Server 2019 prüft den echten Versionsfallback.
Beide folgen erst nach erfolgreichem SQL Server 2025. Die zusätzlichen
Engines verwenden Smoke und den vollständigen direkten WI-0004-Vertrag;
ein fachfremder Vector-Test ist kein Zusatzgate für diese Funktion.
Der breite Bereichstest bleibt auf der primären Engine geprüft.

Die Produktquelle besitzt SHA256
`35834109C154B512B84328F31E290D176929B38F7DB25F8BAFE2B12087E9A8CD`.
Der qualifizierte 2025-Producer ist `711efb07353c13cd34bf176dcc543e9c9aba14ec`;
SQL 2022 verwendet `bde041cfe23e2632163262dc7f55801bbdd369ac`, der abschließende
2019-Lauf `8cecb5482de613f6ad3144080a55ef76ca99ee09`. Die Produktberechnung
und der korrigierte Namensfilterhelper bleiben dabei byteidentisch.
Die späteren Fixtureänderungen betreffen ausschließlich den älteren
Katalogzweig beziehungsweise die streng begrenzte Leerdarstellung mit
zusätzlicher Retention. Die tatsächlich erzeugten Snapshotabfragen für
Majorversion 16 und 17 bleiben identisch. Die modernen Vergleichsorakel
werden nicht gelockert.

Die Resultat-SHA256 sind:

- SQL Server 2025, Versuch 2: `B80AC977F1A6D1A4E5E8087B1E8EBE1879D5B9A3DEAFAEE0EDA053FE125B96D5`.
- SQL Server 2022, Versuch 5: `7A75E10A6B4B16F4899E4DB6A022E1509C931C5EECE6FB59BA7ECF37C74187FA`.
- SQL Server 2019, Versuch 7: `82C92608C7CC78B9EA2770964D0CDCDC3788C46342331CB188F672C08FB31F11`.

## Fehlergeschichte und Bereinigung

Versuche 1, 3, 4 und 6 bleiben FAILED_NOT_QUALIFIED. Versuch 1 endet an
einer ungeeigneten physischen Metadatenassertion ohne separat erhaltene
Katalogdetails; die genaue damalige Abweichung bleibt unbekannt. Der
korrigierte Test vergleicht deklarierte Datentypen und logische Ordinale
statt unzulässig vorausgesetzter physischer Spaltennummern.

Versuch 3 endet vor dem WI-0004-Vertrag in einem zu breit ausgewählten
Bereichstest. Dessen Vector-Guard ist nicht versionsadaptiv; seine genaue
damalige JSON-Abweichung wurde nicht separat behalten und bleibt unbekannt.
Versuch 4 referenziert in der Testfixture eine auf SQL Server 2019 nicht
vorhandene Katalogspalte und erhält den nativen Fehler 207. Versuch 6 endet
am Vergleich eines leeren TABLE-Ergebnisses mit dem JSON-Array; sein
damaliger Scalar wurde nicht behalten und bleibt unbekannt. Frühere
qualifizierte SQL-2019-Aufnahmen belegen die legitime NULL-Leerdarstellung.
Der spätere erfolgreiche Lauf erklärt keine ungespeicherten Originalwerte.

Elf lokale relationale Gegenproben prüfen den extrahierten Schemaguard,
zwölf den extrahierten Paritätsguard. Drei tatsächlich erzeugte
Snapshotabfragen prüfen die Versionsabgrenzung. Diese lokalen Proben und
ScriptDom-Prüfungen sind kein nativer Engineersatz. Der unabhängige
Quellen-, Fixture-, Adapter- und Ergebnisreview bleibt auf die jeweiligen
offenen fachlichen Deltas begrenzt.

Die native Quelle ist nach den Consumeraufrufen unverändert. Caller-SID,
Datenbankkontext, Transaktion, Locktimeout und XACT_ABORT werden erhalten
beziehungsweise restauriert. Alle eigenen Datenbanken, Procedurekopien,
Tabellen, Container, Volumes und Stateverzeichnisse sind entfernt. Jeder
abgeschlossene tatsächliche Lauf besitzt einen erfolgreichen eigenen
öffentlichen Cleanup mit null Fehlern; Dockerinventare und Quellenpins
bleiben jeweils gleich. Fremde Ressourcen werden nicht verändert.
Das gemeinsame Budget endet bei sieben von sieben tatsächlichen Versuchen;
zurückgestellte Starts und ein vor Runtime korrigierter Zulassungscheck
werden nicht als native Starts ausgegeben. Zusätzliche Runtime verlangt
erneute konkrete Autorität.

## Liefergates und Aussagegrenze

Das erste funktionale Head-Gate endet vor dem neuen Fachtest an dessen
kombinierter Eintrittsprüfung für Transaktion, Locktimeout und XACT_ABORT.
Die einzelnen damaligen Callerwerte wurden nicht separat gespeichert;
ihre genaue Abweichung bleibt unbekannt. Der Testkörper läuft deshalb
für die Suite in einer eigenen Procedure der isolierten Frameworkdatenbank.
Die Procedure stellt ausschließlich ihren inneren Optionskontext her;
der vollständige bisherige Fachtest bleibt erhalten. Vor und nach dem
Aufruf werden der äußere Caller und seine Optionen exakt verglichen.
Die eigene Procedure wird datenbank- und objektidentitätsgebunden entfernt,
auch im Fehlerweg. Das verändert keine Produktquelle und setzt das
abgeschlossene private Runtimebudget nicht zurück.

Kanonischer Code, generierter Installer, Parameter-/Resultsetinventare,
Referenzen und Produktstatus werden gemeinsam geliefert. Die reguläre
Integration verlangt die exakte Head-CI mit funktionalem Gate, MatchHead,
Treeidentität und anschließender main-Synchronisierung. Private Nachweise
bewahren diese Bindungen; erfolgreiche unveränderte Nachweise werden nicht
allein für eine Dokumentationsänderung wiederholt.

Die Diagnose zählt ausschließlich vergleichbare Metadatenintervalle im
freigegebenen Scope. Sie liefert keine Datenwerte, Sortierqualität,
Performanceprognose, tatsächliche Segmentelimination, Rebuildempfehlung
oder allgemeine Berechtigungs- und Deadlinegarantie. SSIS und das positive
External-Table-Gate werden dadurch nicht abgeschlossen.

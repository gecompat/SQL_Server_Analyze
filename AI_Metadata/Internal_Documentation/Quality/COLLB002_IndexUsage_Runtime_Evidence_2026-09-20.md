# COLL-B002: Index Usage Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_IndexUsage`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/Common/126_IndexUsage_Collation_Runtime_Contract.sql` creates a scoped test table, invokes the public JSON path with an exact object filter, and validates the Rowstore result envelope. All character columns in the IndexUsage local work tables declare `SQL_Latin1_General_CP1_CS_AS` explicitly.

The contract passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The evidence covers the focused Rowstore path, not In-Memory OLTP collection.

## Ergänzung: Index Operational Stats vom 5. Oktober 2026

`Code/Tests/Common/127_IndexOperationalStats_Collation_Runtime_Contract.sql`
bestand in einem neuen SQL-Server-2025-Docker-Lab mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für das Framework. Frameworkinstallation und
Smoke-Test waren erfolgreich. Die vollständige Buildnummer wurde nicht
erfasst; der Lab-Readinesspfad bestätigte Engine-Major-Version `17`.

Die bisherige Procedure aus dem unveränderten `main`-Stand vor diesem Slice
wurde im eigenen Lab erneut installiert. Der neue Vertrag scheiterte erwartungsgemäß
mit `55762`, weil die sechs Textspalten im TABLE-Export die fremde
`tempdb`-Collation übernahmen. Nach Installation der korrigierten kanonischen
Procedure bestand derselbe Vertrag. Alle 16 zuvor nicht annotierten
Textspalten der Kandidaten-, Status- und Ergebnistabellen besitzen nun die
explizite Frameworkcollation.

Der Nachweis prüft die eigene Unicode-Objektfixture, gezielte JSON- und
TABLE-Ausgabe sowie den case-sensitiven negativen Objektfilter. Die sieben
Insert-, Leaf-/Nonleaf-Allocation-, Page-Latch- und Tree-Page-Latch-Zähler
stimmten mit der direkten nativen DMF-Abfrage für die kontrollierte einzelne
Indexpartition überein. Der Test belegt keine allgemeine Lastbedingung,
keine umfassende Splitklassifikation und keinen VOLL-Pfad. Eigener Container,
Volume, Fixturetabelle und temporärer Lab-State wurden vollständig entfernt.

## Ergänzung: Partitionsexport vom 5. Oktober 2026

`Code/Tests/Common/128_Partitions_Collation_Runtime_Contract.sql` bestand in
einem weiteren neuen SQL-Server-2025-Docker-Lab mit
`Latin1_General_100_CS_AS` für Server und `tempdb` sowie
`SQL_Latin1_General_CP1_CS_AS` für das Framework. Die vollständige Buildnummer
wurde nicht erfasst; der Lab-Readinesspfad bestätigte Engine-Major-Version `17`.
Vollinstallation und Smoke-Test waren erfolgreich.

Die unveränderte bisherige `USP_Partitions`-Definition reproduzierte im
gleichen Lab den neuen Fehler `55772`: Die 13 Textspalten des TABLE-Exports
übernahmen die fremde `tempdb`-Collation. Nach Installation der korrigierten
kanonischen Procedure bestand derselbe Vertrag. Alle 23 bislang nicht
annotierten Textspalten der Kandidaten-, Status- und Ergebnistabellen
verwenden jetzt die explizite Frameworkcollation. Der versionierte
OPS-005-Vollinstaller wurde regeneriert; dessen Inhaltsprüfung bestand.

Die eigene Unicode-Objektfixture verwendete RANGE RIGHT mit drei Partitionen
und je einer synthetischen Zeile. Die zweite Partition erhielt
PAGE-Kompression. JSON und TABLE enthielten exakt drei Partitionen mit
korrekten Grenzen, Inklusivität und gemischter Kompression. Zeilen- und
Kompressionswerte stimmten mit `sys.partitions` überein. Ein weiterer Aufruf
lieferte exakt zwei Zeilen; der abweichend geschriebene exakte Objektfilter
lieferte leeres JSON. Der Nachweis belegt keine RANGE-LEFT-, VOLL- oder
weitere Storagevariante. Eigene Tabelle, Partition Scheme, Partition Function,
Container, Volume und temporärer Lab-State wurden vollständig entfernt.


## Ergänzung: Object-/Index-Exportfamilie vom 5. Oktober 2026

`Code/Tests/Common/129_ObjectIndex_Export_Collation_Runtime_Contract.sql`
bestand in einem neuen SQL-Server-2025-Docker-Lab nach Vollinstallation und
Smoke-Test. Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`, das
Framework `SQL_Latin1_General_CP1_CS_AS` und die eigene synthetische
Quelldatenbank `Latin1_General_100_CI_AS`. Die vollständige Buildnummer wurde
nicht erfasst; der Lab-Readinesspfad bestätigte Engine-Major-Version `17`.

Der Vertrag prüft 13 TABLE-Exports von MissingIndexes, Statistics,
StatisticsDistributionAnalysis, Columnstore, IndexPhysicalStats,
VectorIndexAnalysis, ObjectAnalysis und SchemaDesignAnalysis. Sämtliche
Textspalten der materialisierten Exporttabellen besitzen die explizite
Frameworkcollation. Die acht Procedures erhielten insgesamt 208 zuvor
fehlende Textspaltenannotationen. Eine deterministische Bestandsprüfung fand
im Object-/Index-Bereich keine weiteren unannotierten üblichen
Textspaltendeklarationen lokaler Arbeitstabellen.

Die unveränderte MissingIndexes-Definition reproduzierte Fehler `55782`
wegen fremder Exportcollation. Die strengeren Erfolgsassertionen fanden
zusätzlich echte Fehler an dynamischen Grenzen: Der Physical-Stats-
Analysemodusvergleich scheiterte mit `468`; der ObjectInventory-Zweig des
Orchestrators scheiterte zunächst an Vergleichen und anschließend mit `457`
an einem gemischten CASE-Statusausdruck. Die betroffenen Steuerwertvergleiche,
Datenbankparameter-JOINs und Statusausdrücke verwenden jetzt explizit die
Frameworkcollation. Der direkte DMF-Aufruf blieb unverändert. Eine isolierte
Gegenprobe reproduzierte den fehlerhaften Modevergleich; die explizit
collatierte Variante bestand.

Die eigene Rowstore- und Columnstore-Fixture lieferte positive Statistics-,
Columnstore- und LIMITED-Physical-Stats-Zeilen. Der normale ObjectAnalysis-
Aufruf lieferte exakt drei Modulstatuszeilen sowie eine vollständige eigene
ObjectInventory-Objektzeile. Alle geprüften JSON-Hüllen waren gültig und
nicht partiell. Die Vector-Exports belegen ihre Schemas im kontrollierten
Scope ohne eigenen Vector-Index; MissingIndexes belegt keine positive
Optimizerempfehlung. VOLL-, Hochlast-, weitere Storage- und zusätzliche
native Versionsvarianten sind durch diesen Vertrag nicht abgedeckt.

Die isolierten Baseline-/Fix-Redeploys verwenden dieselben gespeicherten
`QUOTED_IDENTIFIER ON`- und `ANSI_NULLS ON`-Einstellungen wie der Vollinstaller.
Der erste Redeployversuch mit `QUOTED_IDENTIFIER OFF` scheiterte mit `1934`
und wurde als Fehler des Testaufbaus korrigiert. Nach der Diagnose wurde die
kanonische Quelle ohne temporäre Debugausgaben erneut installiert; derselbe
vollständige Vertrag bestand nochmals. Der versionierte OPS-005-Installer
wurde aus den kanonischen Quellen regeneriert. Sämtliche eigenen
Fixture-Datenbanken, Container, Volumes und temporären Lab-States wurden
nach den jeweiligen Läufen entfernt.

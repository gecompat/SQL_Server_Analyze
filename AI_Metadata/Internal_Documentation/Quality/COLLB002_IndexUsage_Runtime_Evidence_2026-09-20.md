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

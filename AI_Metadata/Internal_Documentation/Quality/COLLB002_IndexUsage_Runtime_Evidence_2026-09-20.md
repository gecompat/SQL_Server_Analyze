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

# WI-0004: Geordnete Columnstore-Diagnostik – Analyse

**Referenz:** `WI-0004`
**Status:** Abgeschlossen; Implementierung sowie native Runtime-Fixtures auf SQL Server 2019, 2022 und 2025 bestanden.
**Geltungsbereich:** Read-only-Erweiterung von `monitor.USP_Columnstore` für SQL Server 2019 und neuer.

## Diagnosefrage

Die bestehende Procedure zeigt Rowgroups und optionale Segmentdetails, aber
nicht, welche Columnstore-Indizes eine deklarierte Reihenfolge besitzen. Die
Erweiterung muss deklarierte Reihenfolge, SQL-Server-2025-Datenclustering und
eine optionale begrenzte Segmentbetrachtung getrennt halten. Eine deklarierte
Reihenfolge beweist weder vollständige Sortierung noch Segmentelimination oder
eine Abfrageverbesserung.

`sys.index_columns.column_store_order_ordinal` steht ab SQL Server 2022 zur
Verfügung. `data_clustering_ordinal` ist ein SQL-Server-2025-Metadatenwert.
Beide Spalten müssen daher versionsgeschützt dynamisch gelesen werden. Die
Quellen dokumentieren Metadaten, keine gemessene Ausführungswirkung.

## Entwurfsgrenzen

Der Basispfad erhält eine eigene benannte `ordering`-Menge statt zusätzlicher
Felder in den bestehenden Rowgroup-Vertrag. Sie enthält Indexidentität,
Spaltenname, Order- und Data-Clustering-Ordinal sowie einen Quellenstatus.
SQL Server 2019 liefert explizit `UNAVAILABLE_VERSION`; SQL Server 2022 liefert
Order-Ordinale ohne Data-Clustering-Wert. SQL Server 2025 kann beide Werte
ausweisen. Fehlende Metadatensicht wird isoliert gemeldet.

Eine spätere Segmentüberlappungsanalyse bleibt opt-in, `COLUMNSTORE_DEEP`
geschützt, begrenzt und getrennt von der Deklaration. Sie darf keine defekte
Ordnung, keinen Rebuildbedarf und keine Performanceaussage ableiten.

## Nachweisplan

Vor der Produktimplementierung werden der öffentliche RAW-/TABLE-/JSON-Vertrag,
der SQL-Server-2019-Fallback, eine SQL-Server-2022-Order-Fixture und eine
SQL-Server-2025-Data-Clustering-Fixture festgelegt. Alle Fixtures bleiben
synthetisch; es werden keine Produktionsobjekte verändert.

## Primärquellen

- [sys.index_columns (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-index-columns-transact-sql?view=sql-server-ver17)
- [Performance tuning with ordered columnstore indexes](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/ordered-columnstore-indexes?view=sql-server-ver17)

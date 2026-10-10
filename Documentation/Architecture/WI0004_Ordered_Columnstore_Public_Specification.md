# WI-0004: Geordnete Columnstore-Diagnostik – öffentliche Spezifikation

**Status:** Implementiert; native Runtime-Fixtures auf SQL Server 2019, 2022 und 2025 bestanden.
**Geltungsbereich:** `monitor.USP_Columnstore`, SQL Server 2019 und neuer.

## Vertrag

Die bestehende `rowgroups`-Menge bleibt unverändert. Eine additive benannte
Menge `ordering` enthält `DatabaseName`, `SchemaName`, `ObjectName`,
`ObjectId`, `IndexId`, `IndexName`, `IndexTypeDesc`, `ColumnId`, `ColumnName`,
`ColumnStoreOrderOrdinal`, `DataClusteringOrdinal`, `SourceStatus`,
`ErrorNumber`, `ErrorMessage` und `CollectionTimeUtc`.

RAW liefert die Menge separat, JSON sie unter `ordering`, und TABLE akzeptiert
die Zuordnung `ordering`. CONSOLE behält den vorhandenen Rowgroup-Fokus. Die
Ordinale beschreiben deklarierte Katalogmetadaten; sie sind keine Bewertung der
Sortierqualität, Segmentüberlappung, Abfrageleistung oder eines Rebuildbedarfs.

## Versionen und Grenzen

SQL Server 2019 meldet für die Menge `UNAVAILABLE_VERSION`. SQL Server 2022
liest `column_store_order_ordinal`; `DataClusteringOrdinal` bleibt `NULL`.
SQL Server 2025 liest zusätzlich `data_clustering_ordinal`. Fehlende Rechte,
Timeouts und Katalogfehler werden als Teilquellenstatus ausgedrückt und
unterdrücken die bestehenden Rowgroup-, Segment- und Dictionarymengen nicht.
Auf unterstützten Versionen ohne sichtbare geordnete Columnstore-Spalte ist
`ordering` leer; das ist kein Qualitätsurteil. `SourceStatus = 'AVAILABLE'`
steht nur an einer tatsächlich ausgegebenen Metadatenzeile.

Eine Segmentüberlappung bleibt ein getrenntes späteres Opt-in und wird durch
diese Spezifikation nicht eingeführt.

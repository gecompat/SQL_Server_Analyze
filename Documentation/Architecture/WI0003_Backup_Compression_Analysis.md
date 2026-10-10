# WI-0003: Backup-Kompressionsalgorithmus- und ZSTD-Evidenz – Analyse

**Referenz:** `WI-0003`
**Status:** `IMPLEMENTED_ACTIONS_GATE`.
**Geltungsbereich:** Der bestehende read-only Backup-Recovery-Pfad für SQL Server 2019 und neuer.

## Diagnosefrage und bestehende Abdeckung

`monitor.USP_BackupRecovery` liefert Backupgröße und komprimierte Größe aus
`msdb.dbo.backupset`. Die Procedure zeigt derzeit weder den in der
Backuphistorie dokumentierten Kompressionsalgorithmus noch die von einer
einzelnen Backuperstellung unabhängige Serverkonfiguration. Die vorhandene
`ZSTD_BACKUP_COMPRESSION`-Zeile von
`monitor.USP_ServerFeatureCapabilities` ist ausschließlich eine
versionsbasierte Capabilityaussage. Sie belegt weder eine konfigurierte
Voreinstellung noch die Nutzung von ZSTD durch ein sichtbares Backup.

Die Serveroption `backup compression algorithm` ist ab SQL Server 2022
verfügbar. Ihr Wert `0` verwendet die Einstellung `backup compression
default`; die Werte `1`, `2` und `3` stehen für `MS_XPRESS`, Intel QAT
beziehungsweise ZSTD. QAT ist ab SQL Server 2022 und ZSTD ab SQL Server 2025
verfügbar. Die Serveroption steuert nur den Standard für komprimierte
Backups; eine explizite BACKUP-Option kann davon abweichen. [Microsoft Learn:
Server configuration: backup compression algorithm](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/view-or-configure-the-backup-compression-algorithm-server-configuration-option?view=sql-server-ver17)

`msdb.dbo.backupset.compression_algorithm` dokumentiert den Algorithmus einer
erfolgreichen Backuperstellung und ist ab SQL Server 2022 verfügbar. Die
Spalte ist historische Metadatenevidenz. Sie beweist weder die gegenwärtige
Servereinstellung noch Medienzugriff, Restorefähigkeit, CPU-Verbrauch oder
Durchsatz. [Microsoft Learn: backupset](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backupset-transact-sql?view=sql-server-ver17)

## Architekturentscheidung für die Spezifikation

Die Erweiterung gehört in `monitor.USP_BackupRecovery`, weil dieser Pfad
bereits die ausgewählte `backupset`-Historie begrenzt und an
`monitor.USP_InfrastructureAnalysis` weitergibt. Sie ergänzt nicht die
bestehenden `freshness`-Felder und erweitert nicht das Legacy-Schema der
`backups`-Menge. Stattdessen erhält die Procedure eine eigene benannte
Kompressionsmenge. Dadurch bleiben Backupalter, Größen und Wiederherstellungs-
evidenz von Konfiguration, Capability und algorithmusspezifischer Historie
getrennt.

Der Serverdefault wird aus den beiden `sys.configurations`-Zeilen
`backup compression default` und, ab SQL Server 2022, `backup compression
algorithm` gelesen. Die tatsächlich dokumentierte Historie wird in einem
versionsgeschützten, begrenzten Zugriff aus `msdb.dbo.backupset` erhoben. Der
statische SQL-Server-2019-Pfad darf die neuere Spalte nicht kompilieren. Die
Feature-Capability bleibt ein eigener Eintrag in
`USP_ServerFeatureCapabilities`; ihre Quellenbeschreibung ist auf
Produktversion und dokumentierte Quellenfähigkeit zu beschränken.

## Nicht Bestandteil dieses Arbeitselements

Die Erweiterung ändert keine Serveroption, erzeugt oder löscht keine Backups
und liest keine Medienpfade, Backupinhalte, Anmeldeinformationen oder
Verschlüsselungsschlüssel. Sie bewertet weder die Restorefähigkeit noch die
Kosten oder Eignung eines Algorithmus. Ein fehlender Historienwert kann durch
Retention, Berechtigung, eine ältere Engine oder einen nicht sichtbaren Scope
erklärt sein und ist kein Nachweis fehlender Kompression.

## Nachweisgrenzen und nächste Schritte

Die öffentliche Spezifikation und der Produkt-Slice legen die neue
Resultsetmenge, ihre Versionserkennung, JSON-/TABLE-Route und die
Fehlerisolation fest. Der Slice ist durch gezielte native Nachweise auf SQL
Server 2019, 2022 und 2025 sowie den SQL-Server-2025-Impactlauf abgenommen.
Die positive ZSTD-Evidenz bleibt auf SQL Server 2025 begrenzt, sofern die
Laufzeitumgebung den dokumentierten Algorithmus unterstützt.

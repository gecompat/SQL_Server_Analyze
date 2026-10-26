:ON ERROR EXIT

/*
Installiert ausschließlich das optionale SC-023-Zielschema in der aktuell
verbundenen Snapshot-Datenbank. Die Betriebsstelle erstellt und wählt diese
Datenbank ausdrücklich; Systemdatenbanken sind unzulässig.
*/

:r ../10_SnapshotBaseline/030_Snapshot_Target_Schema.sql
:r ../10_SnapshotBaseline/020_InternalConfigureSnapshotPolicy.sql
:r ../10_SnapshotBaseline/040_InternalPrepareCollectionCycle.sql
:r ../10_SnapshotBaseline/050_InternalCompletePerformanceCounterCycle.sql
:r ../10_SnapshotBaseline/055_InternalCompleteWaitStatsCycle.sql
:r ../10_SnapshotBaseline/057_InternalCompleteFileIOCycle.sql
:r ../10_SnapshotBaseline/060_InternalFinalizeCollectionCycle.sql
:r ../10_SnapshotBaseline/070_InternalPurgeExpiredData.sql
:r ../10_SnapshotBaseline/075_CompleteWaitStatsInstallation.sql

:r ../10_SnapshotBaseline/078_CompleteFileIOInstallation.sql

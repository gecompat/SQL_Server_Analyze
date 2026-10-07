# Memory-Grant- und Resource-Governor-Vertrag

Stand: 2026-07-15

`monitor.USP_CurrentMemoryGrants` verbindet aktuelle/wartende Query Memory Grants mit Workload Group, Resource Pool und Resource Semaphore.

Der öffentliche Vertrag enthält unter anderem folgende kanonische Spalten:

- `RequestMaxMemoryGrantPercent decimal(9,4)`
- `ConfiguredRequestMaxGrantMemoryMb`, `TargetRequestMaxGrantMemoryMb`, `HistoricalMaxRequestGrantMemoryMb`
- `RequestedOfRequestMaxPercent`
- `GrantedOfRequestMaxPercent`
- `UsedOfRequestMaxPercent`
- `UsedOfGrantedPercent`
- `PoolMaxWorkspaceMemoryMb`, `PoolTargetWorkspaceMemoryMb`, `PoolUsedWorkspaceMemoryMb`
- `SemaphoreAvailableMemoryMb`, `SemaphoreGrantedMemoryMb`, `SemaphoreWaiterCount`

Die technische DMV-Spalte `request_max_memory_grant_percent_numeric` wird als präzise Quelle verwendet. Der Datentyp ist bewusst **nicht** Bestandteil des öffentlichen Spaltennamens. Der maximal zulässige Request-Grant ist eine Policy-Grenze des Resource Pools/der Workload Group und nicht einfach ein Anteil des physischen RAM oder von `max server memory`.

Die Prozentwerte müssen deshalb gegen die jeweilige Pool- und Workload-Group-Grenze gelesen werden. Ein hoher Anteil am Request-Maximum belegt weder allgemeinen Speicherdruck noch eine ungeeignete Serverkonfiguration; dafür sind Semaphorezustand, konkurrierende Grants, tatsächlich verwendeter Speicher und OS-/SQL-Memory-Pressure zusätzlich erforderlich.

Der gemeinsame Fachvertrag enthält 63 Felder mit neun expliziten Frameworktextcollations und ohne Identity. `IsWaiting` und `CurrentStatementIsTruncated` sind NOT NULL; fehlende Zusatzmetadaten bleiben NULL. RAW, TABLE und JSON verwenden dieselbe Fachmenge; der aktive CONSOLE-Helper ergänzt ein Label.

Das positive Zeilenlimit wirkt nach der N+1-Erfassung, Textprojektion und Mengenbewertung auf alle Ausgabeformen gemeinsam. NULL oder 0 bleibt unbegrenzt. `HasMoreRows` und die Textwarnung beziehen sich auf die erfassten Kandidaten vor diesem Zuschnitt und belegen keinen vollständigen, atomaren Serverzustand. Der Overview verwendet weiterhin seinen bestehenden Snapshotowner; der Einzelaufruf liest die flüchtigen Quellen nacheinander.

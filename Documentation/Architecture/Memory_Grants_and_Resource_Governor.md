# Memory-Grant- und Resource-Governor-Vertrag

Stand: 2026-07-15

`monitor.USP_CurrentMemoryGrants` verbindet aktuelle/wartende Query Memory Grants mit Workload Group, Resource Pool und Resource Semaphore.

Kanonische Spalten sind unter anderem:

- `RequestMaxMemoryGrantPercent decimal(9,4)`
- `RequestMaxGrantMemoryMb`
- `RequestedOfRequestMaxPercent`
- `GrantedOfRequestMaxPercent`
- `UsedOfRequestMaxPercent`
- `UsedOfGrantedPercent`
- `PoolMaxWorkspaceMemoryMb`, `PoolTargetWorkspaceMemoryMb`, `PoolUsedWorkspaceMemoryMb`
- `SemaphoreAvailableMemoryMb`, `SemaphoreGrantedMemoryMb`, `SemaphoreWaiterCount`

Die technische DMV-Spalte `request_max_memory_grant_percent_numeric` wird als präzise Quelle verwendet. Der Datentyp ist bewusst **nicht** Bestandteil des öffentlichen Spaltennamens. Der maximal zulässige Request-Grant ist eine Policy-Grenze des Resource Pools/der Workload Group und nicht einfach ein Anteil des physischen RAM oder von `max server memory`.

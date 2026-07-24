# LAB-001 Welle 4 contract foundation

This directory contains the validated contract foundation for the planned
multi-container and network-fault wave. It does not contain executable Welle 4
runtime actions and does not claim host evidence. The global Welle 4 status
therefore remains `PLANNED`, and every external gate remains `NOT_EXECUTED`.

The registry `wave4-contracts.csv` binds all 18 catalog scenarios to the
existing `CTR-SINGLE`, `CTR-PAIR`, `CTR-TRIPLE`, and
`HV-CROSS-PLATFORM` topology contracts. It defines required capabilities,
analyzer dependencies, bounded fault classes, state prerequisites, portable
assertion boundaries, and cleanup behavior. The file
`wave4-topology-profiles.json` separates management, data, and fault segments
without storing an address, endpoint, host identity, or local path.

## Safety boundary

Every mutable resource must carry the active run ID and be registered by its
complete platform object ID before it may be changed or removed. Cleanup uses
registered object IDs only; name-only deletion, wildcard deletion, broad
container prune operations, and recursive root deletion are forbidden.

Network and endpoint faults require a bounded duration. Faults that can cut the
data path require an independent management path that is proven before the
fault is applied. The cleanup path removes the exact registered rule before SQL
or container teardown continues. Exact packet counts, wait durations, queue
sizes, command counts, plan identifiers, and throughput are not portable
assertions.

## Dependency boundary

`LAB-LINK-001` remains blocked by `OPS-005`. The contract records the intended
`USP_LinkedServerAnalysis` dependency, but neither the analyzer nor a Welle 4
runtime action is represented as implemented. In particular, the contract does
not promise a per-call timeout for `sp_testlinkedserver` and does not change
server timeout configuration.

All repository values in this directory are public SQL Server identifiers or
clearly synthetic contract terms. Host identities, endpoints, addresses, local
paths, credentials, image digests, and runtime output remain outside Git.

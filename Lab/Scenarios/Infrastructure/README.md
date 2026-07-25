# LAB-001 Welle 4 multi-container runtime

This directory contains the validated contracts and the first executable runtime
foundation for Welle 4. Docker on native Linux now supports the `CTR-PAIR` and
`CTR-TRIPLE` topology actions in addition to the existing `CTR-SINGLE` path.
Native host evidence is not included in the repository, so the Welle 4 runtime
status remains `IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING` and the external gates
remain `NOT_EXECUTED`.

The registry `wave4-contracts.csv` continues to bind all 18 catalog scenarios to
`CTR-SINGLE`, `CTR-PAIR`, `CTR-TRIPLE`, and `HV-CROSS-PLATFORM`. Those scenario
actions remain `PLANNED_NOT_IMPLEMENTED`; this delivery provides their reusable
multi-container infrastructure only. The network-fault layer and the
`HV-CROSS-PLATFORM` runtime are also not implemented.

## Implemented topology boundary

`Invoke-LabMultiContainerUp` accepts `CTR-PAIR` or `CTR-TRIPLE` with SQL Server
2019, 2022, or 2025 and the `Standard` resource profile. Docker is the executable
runtime lane. Podman remains visible as `NOT_EXECUTED` and assigned to Welle 9.

The runtime:

- performs the existing read-only LAB preflight;
- checks aggregate host memory and storage reserve before mutation;
- writes `TOPOLOGY_CREATING` before image pull or Compose mutation;
- pulls one digest-bound SQL Server image;
- starts primary, secondary, and optional tertiary nodes sequentially;
- registers every container immediately by its canonical 64-character object ID;
- creates and registers exactly one `LAB_MANAGEMENT` and one `LAB_DATA` network;
- verifies run, framework-owner, topology, role, and segment labels;
- waits for SQL health, verifies `ProductMajorVersion`, installs the current
  repository framework, and requires `FRAMEWORK_READY` before starting the next
  node;
- measures effective per-container limits and writes only ignored local runtime
  measurements;
- registers discovered resources and invokes exact-ID recovery cleanup after a
  partial failure.

The management and data networks are separate internal Docker segments. LAB
control uses Docker exec as the out-of-band management path, so SQL data-path
configuration can later be changed without selecting or deleting resources by
name. This is a management-path contract, not proof of a physical independent
network.

## Safety boundary

Every mutable Docker resource carries the active run ID and the generic
`SQL_SERVER_ANALYZE` owner label. Containers additionally carry exact topology
and role labels; networks carry topology and segment labels. Cleanup uses only
registered complete object IDs. Name-only deletion, wildcard deletion, Compose
project-wide deletion, broad prune operations, and recursive root deletion are
forbidden.

Aggregate reserve checks multiply the `Standard` SQL-container memory and
storage budget by the selected node count. Nodes still start sequentially to
limit peak initialization pressure. Welle 4 does not automatically escalate to a
Stress profile.

Network and endpoint faults remain outside this runtime slice. Any later fault
that can cut a data path must have an explicit approval, bounded duration,
registered exact cleanup object, and a proven management path before activation.
Exact packet counts, waits, queue sizes, durations, and throughput remain
non-portable assertions.

## Dependency boundary

`LAB-LINK-001` remains blocked by `OPS-005`. The contract records the intended
`USP_LinkedServerAnalysis` dependency, but neither that analyzer nor any Welle 4
scenario action is represented as implemented. The contract does not promise a
per-call timeout for `sp_testlinkedserver` and does not change server timeout
configuration.

All repository values in this directory are public SQL Server identifiers or
clearly synthetic contract terms. Host identities, endpoints, addresses, local
paths, credentials, image digests, and runtime output remain outside Git.

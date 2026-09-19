# COLL-B002: Replication Runtime Evidence

**Date:** 19 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_ReplicationStatus]`
**Result:** Passed on SQL Server 2019

`Code/Tests/Infrastructure/124_ReplicationStatus_Collation_Runtime_Contract.sql` invokes the Replication status standard path and verifies its JSON status contract. The procedure uses explicitly collated local work tables for database roles, publications, subscriptions, and isolated errors.

The contract passed against a temporary SQL Server 2019 database without creating or configuring Replication. It does not establish populated optional Distribution-detail coverage or complete the remaining per-file tempdb-collation inventory.

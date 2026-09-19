# COLL-B002: Current Memory Grants Runtime Evidence

**Date:** 20 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_CurrentMemoryGrants]`
**Result:** Passed on SQL Server 2019

`Code/Tests/CurrentState/143_CurrentMemoryGrants_Collation_Runtime_Contract.sql` invokes the low-impact empty memory-grant path. The procedure explicitly collates result, warning, and local source work tables.

The contract passed against a temporary SQL Server 2019 Linux database without requesting SQL text. It does not establish populated grant, Resource Governor, or parent-snapshot paths, or complete the remaining per-file tempdb-collation inventory.

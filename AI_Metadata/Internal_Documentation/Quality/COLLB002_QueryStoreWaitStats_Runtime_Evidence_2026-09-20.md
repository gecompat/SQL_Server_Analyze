# COLL-B002: Query Store Wait Stats Runtime Evidence

**Date:** 20 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_QueryStoreWaitStats]`
**Result:** Passed on SQL Server 2019

`Code/Tests/QueryStore/136_QueryStoreWaitStats_Collation_Runtime_Contract.sql` invokes the structured empty-candidate path. The procedure explicitly collates its database-candidate, result and error work tables.

The contract passed against a temporary SQL Server 2019 Linux database without reading Query Store databases, query text or wait details. It does not establish the non-empty or deep-analysis paths, or complete the remaining per-file tempdb-collation inventory.

# COLL-B002: Query Store Runtime Stats Runtime Evidence

**Date:** 20 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_QueryStoreRuntimeStats]`
**Result:** Passed on SQL Server 2019

`Code/Tests/QueryStore/140_QueryStoreRuntimeStats_Collation_Runtime_Contract.sql` invokes the structured empty-candidate path. The procedure explicitly collates its database-candidate, result, and error work tables.

The contract passed against a temporary SQL Server 2019 Linux database without reading Query Store databases, query text, or plan XML. It does not establish non-empty or deep-analysis paths, or complete the remaining per-file tempdb-collation inventory.

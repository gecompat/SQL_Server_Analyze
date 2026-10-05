# COLL-B002: Query Store Hints Runtime Evidence

**Date:** 19 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_QueryStoreHints]`
**Result:** Passed on SQL Server 2022

`Code/Tests/QueryStore/122_QueryStoreHints_Collation_Runtime_Contract.sql` invokes the Query Store Hints path against a synthetic current database and verifies its JSON status contract. The procedure uses explicitly collated local work tables for database candidates, collected hints, and isolated errors.

The contract passed against a temporary SQL Server 2022 database. It does not establish native behavior on other SQL Server versions or complete the remaining per-file tempdb-collation inventory.

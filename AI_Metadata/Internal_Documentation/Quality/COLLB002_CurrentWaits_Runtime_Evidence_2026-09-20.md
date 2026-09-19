# COLL-B002: Current Waits Runtime Evidence

**Date:** 20 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_CurrentWaits]`
**Result:** Passed on SQL Server 2019

`Code/Tests/CurrentState/135_CurrentWaits_Collation_Runtime_Contract.sql` invokes the cumulative current-waits path with SQL-text collection disabled and verifies its structured JSON contracts. The procedure explicitly collates its task, instance, warning and source work tables.

The contract passed against a temporary SQL Server 2019 Linux database. It does not request, emit or store SQL text, wait details or session details, and it does not create a timed sampling delay. It does not establish the optional delta or regex paths, or complete the remaining per-file tempdb-collation inventory.

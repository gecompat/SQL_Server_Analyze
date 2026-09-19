# COLL-B002: Current Transactions Runtime Evidence

**Date:** 20 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_CurrentTransactions]`
**Result:** Passed on SQL Server 2019

`Code/Tests/CurrentState/132_CurrentTransactions_Collation_Runtime_Contract.sql` invokes the Current Transactions path with SQL-text collection disabled and verifies its JSON status, result and warning contracts. The procedure explicitly collates its local result, warning, session, request and SQL-text work tables.

The contract passed against a temporary SQL Server 2019 Linux database. It proves the complete structured path without requesting, emitting or storing SQL text. It does not establish every permission-limited path or complete the remaining per-file tempdb-collation inventory.

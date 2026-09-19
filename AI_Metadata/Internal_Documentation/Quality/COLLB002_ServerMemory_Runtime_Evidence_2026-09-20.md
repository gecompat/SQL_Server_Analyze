# COLL-B002: Server Memory Runtime Evidence

**Date:** 20 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_ServerMemory]`
**Result:** Passed on SQL Server 2019

`Code/Tests/ServerHealth/129_ServerMemory_Collation_Runtime_Contract.sql` invokes the Server Memory path and verifies its JSON and output-status contracts. The procedure uses explicitly collated local work tables for memory state, model, findings, and clerk types.

The contract passed against a temporary SQL Server 2019 database. It does not establish native behavior on other SQL Server versions or complete the remaining per-file tempdb-collation inventory.

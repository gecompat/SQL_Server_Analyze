# COLL-B002: Server NUMA Runtime Evidence

**Date:** 20 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_ServerNuma]`
**Result:** Passed on SQL Server 2019

`Code/Tests/ServerHealth/128_ServerNuma_Collation_Runtime_Contract.sql` invokes the NUMA path and verifies its JSON and output-status contracts. The procedure uses an explicitly collated local work table for NUMA-node state and findings.

The contract passed against a temporary SQL Server 2019 database. It does not establish native behavior on other SQL Server versions or complete the remaining per-file tempdb-collation inventory.

# COLL-B002: Server CPU Topology Runtime Evidence

**Date:** 19 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_ServerCpuTopology]`
**Result:** Passed on SQL Server 2019

`Code/Tests/ServerHealth/127_ServerCpuTopology_Collation_Runtime_Contract.sql` invokes the CPU-topology path and verifies its JSON and output-status contracts. The procedure uses explicitly collated local work tables for CPU, scheduler, and NUMA metadata.

The contract passed against a temporary SQL Server 2019 database. It does not establish native behavior on other SQL Server versions or complete the remaining per-file tempdb-collation inventory.

# COLL-B002: OS Information Runtime Evidence

**Date:** 20 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_OSInformation]`
**Result:** Passed on SQL Server 2019

`Code/Tests/ServerHealth/133_OSInformation_Collation_Runtime_Contract.sql` invokes the OS Information path and verifies its structured status and JSON collection contracts. The procedure explicitly collates its local source-status, host, memory and service work tables.

The contract passed against a temporary SQL Server 2019 Linux database. It proves the complete structured path without emitting or storing host and service details. It does not establish every permission-limited path or complete the remaining per-file tempdb-collation inventory.

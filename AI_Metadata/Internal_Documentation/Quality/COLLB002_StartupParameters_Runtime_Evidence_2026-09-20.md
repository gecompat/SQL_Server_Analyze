# COLL-B002: Startup Parameters Runtime Evidence

**Date:** 20 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_StartupParameters]`
**Result:** Passed on SQL Server 2019

`Code/Tests/ServerHealth/131_StartupParameters_Collation_Runtime_Contract.sql` invokes the Startup Parameters path and verifies its JSON and output-status contracts. The procedure uses an explicitly collated local work table for registry keys, value names, value data, and parameter types.

The contract passed against a temporary SQL Server 2019 Linux database. It proves the structured, available empty-list path without reading or exposing startup-parameter values. It does not establish Windows registry-source behavior or complete the remaining per-file tempdb-collation inventory.

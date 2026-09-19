# COLL-B002: Server Configuration Runtime Evidence

**Date:** 19 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_ServerConfiguration]`
**Result:** Passed on SQL Server 2019

`Code/Tests/ServerHealth/125_ServerConfiguration_Collation_Runtime_Contract.sql` invokes the core Server Configuration path and verifies its JSON and output-status contracts. The procedure uses an explicitly collated local work table for configuration names, findings, and interpretations.

The contract passed against a temporary SQL Server 2019 database. It does not establish native behavior on other SQL Server versions or complete the remaining per-file tempdb-collation inventory.

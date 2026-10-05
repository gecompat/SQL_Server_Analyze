# COLL-B002: Intelligent Query Processing Runtime Evidence

**Date:** 20 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_IntelligentQueryProcessingAnalysis]`
**Result:** Passed on SQL Server 2019

`Code/Tests/QueryStore/142_IntelligentQueryProcessingAnalysis_Collation_Runtime_Contract.sql` invokes the structured unknown-database path. The procedure explicitly collates its candidate, configuration, result, signal, and error work tables.

The contract passed against a temporary SQL Server 2019 Linux database without reading Query Store text or showplans. It does not establish non-empty IQP evidence paths, or complete the remaining per-file tempdb-collation inventory.

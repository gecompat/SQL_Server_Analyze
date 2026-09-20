# COLL-B002: Query Hash Analysis Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_QueryHashAnalysis`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/PlanCache/130_QueryHashAnalysis_Collation_Runtime_Contract.sql` executes a synthetic statement and invokes the public Query Hash Analysis DMV path with JSON output. The procedure materializes `SampleStatementText` in `#QueryHashAnalysis_Output` with `SQL_Latin1_General_CP1_CS_AS`.

The contract passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The evidence covers the public cache-read path and does not establish behavior after cache eviction.

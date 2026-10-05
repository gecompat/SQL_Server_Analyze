# COLL-B002: Showplan Analysis Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_ShowplanAnalysis`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/PlanCache/126_ShowplanAnalysis_Collation_Runtime_Contract.sql` executes a bounded Showplan Analysis request with an empty effective candidate selection. The procedure explicitly applies `SQL_Latin1_General_CP1_CS_AS` to every character column in its temporary mapping, candidate, status, result, and context tables.

The contract passed against the isolated SQL Server 2019 Linux adapter database. The evidence does not establish nonempty plan analysis, XML shredding, Query Store context, or runtime-feedback paths.

# COLL-B002: Query Stats Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_QueryStats`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/PlanCache/124_QueryStats_Collation_Runtime_Contract.sql` executes a bounded plan-cache request for the temporary test database with an effective empty result selection. The procedure explicitly applies `SQL_Latin1_General_CP1_CS_AS` to the database-candidate, candidate-warning, and result work tables.

The contract passed against a temporary SQL Server 2019 Linux database. The evidence does not establish nonempty plan-cache results, cross-database processing, or high-impact analysis paths.

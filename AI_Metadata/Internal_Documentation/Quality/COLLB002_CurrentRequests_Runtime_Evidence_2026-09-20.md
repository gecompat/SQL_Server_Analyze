# COLL-B002: Current Requests Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_CurrentRequests`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/CurrentState/132_CurrentRequests_Collation_Runtime_Contract.sql` invokes the public Current Requests JSON path with SQL text, batch text, input-buffer, and module resolution disabled. All character columns in the `#CurrentRequests_*` work tables declare `SQL_Latin1_General_CP1_CS_AS` explicitly.

The contract passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The evidence does not cover optional SQL-text, module-resolution, input-buffer, regex, or parent-snapshot paths.

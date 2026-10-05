# COLL-B002: Current Overview Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_CurrentOverview`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/Integration/199_CurrentState_Snapshot_Runtime_Contract.sql` passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The contract verified the Current-State primary snapshot and eight consumer boundaries.

All character columns in the `#CurrentOverview_*` work tables now declare `SQL_Latin1_General_CP1_CS_AS` explicitly. The evidence does not cover every optional child detail combination.

# COLL-B002: Current Blocking Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_CurrentBlocking`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/CurrentState/133_CurrentBlocking_Collation_Runtime_Contract.sql` invokes the public Current Blocking JSON path without SQL-text collection, lock details, or object resolution. All character columns in the `#CurrentBlocking_*` work tables declare `SQL_Latin1_General_CP1_CS_AS` explicitly.

The contract passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The evidence does not cover optional SQL-text, lock-detail, object-resolution, or parent-snapshot paths.

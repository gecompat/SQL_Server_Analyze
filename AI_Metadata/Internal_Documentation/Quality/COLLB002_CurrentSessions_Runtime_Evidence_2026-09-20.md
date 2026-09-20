# COLL-B002: Current Sessions Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_CurrentSessions`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/CurrentState/131_CurrentSessions_Collation_Runtime_Contract.sql` invokes the public Current Sessions JSON path without SQL-text collection. All character columns in the `#CurrentSessions_*` work tables declare `SQL_Latin1_General_CP1_CS_AS` explicitly.

The contract passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The evidence does not cover SQL-text collection, regex filtering, or a parent Current-State snapshot.

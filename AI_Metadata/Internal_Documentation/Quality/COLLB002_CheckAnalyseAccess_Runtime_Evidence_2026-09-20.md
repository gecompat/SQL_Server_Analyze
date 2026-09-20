# COLL-B002: Check Analyse Access Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_CheckAnalyseAccess`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/Common/120_CheckAnalyseAccess_Collation_Runtime_Contract.sql` invokes the public JSON path without specifying an analysis class or any external group identifier. All character columns in the `#CheckAnalyseAccess_*` work tables declare `SQL_Latin1_General_CP1_CS_AS` explicitly.

The contract passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The evidence does not establish individual group-policy outcomes.

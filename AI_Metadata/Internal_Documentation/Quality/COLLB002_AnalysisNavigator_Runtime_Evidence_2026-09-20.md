# COLL-B002: Analysis Navigator Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_AnalysisNavigator`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/Common/124_AnalysisNavigator_Collation_Runtime_Contract.sql` invokes the public JSON path without filters and validates the result envelope and navigation array. All character columns in `#AnalysisNavigator_Navigation` declare `SQL_Latin1_General_CP1_CS_AS` explicitly.

The contract passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The evidence covers the default navigation path, not every search and filter combination.

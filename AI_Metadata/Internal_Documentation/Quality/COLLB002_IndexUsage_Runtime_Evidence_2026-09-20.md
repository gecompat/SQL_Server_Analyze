# COLL-B002: Index Usage Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_IndexUsage`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/Common/126_IndexUsage_Collation_Runtime_Contract.sql` creates a scoped test table, invokes the public JSON path with an exact object filter, and validates the Rowstore result envelope. All character columns in the IndexUsage local work tables declare `SQL_Latin1_General_CP1_CS_AS` explicitly.

The contract passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The evidence covers the focused Rowstore path, not In-Memory OLTP collection.

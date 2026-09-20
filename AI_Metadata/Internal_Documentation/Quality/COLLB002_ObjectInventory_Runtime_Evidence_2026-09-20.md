# COLL-B002: Object Inventory Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_ObjectInventory`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/Common/125_ObjectInventory_Collation_Runtime_Contract.sql` creates a scoped test object, invokes the public JSON path with an exact object filter, and validates the result envelope and objects array. All character columns in the ObjectInventory local work tables declare `SQL_Latin1_General_CP1_CS_AS` explicitly.

The contract passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The evidence covers the focused object path, not cross-database or complete-catalog collection.

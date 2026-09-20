# COLL-B002: Current I/O Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_CurrentIO`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/CurrentState/130_CurrentIO_Collation_Runtime_Contract.sql` invokes the public Current I/O JSON path without the optional Pending-I/O collection. All character columns in the `#CurrentIO_*` work tables declare `SQL_Latin1_General_CP1_CS_AS` explicitly.

The contract passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The evidence does not cover the optional Pending-I/O DMV path or two-sample delta collection.

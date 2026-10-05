# COLL-B002: Internal Write Result Table Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.InternalWriteResultTable`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/Common/123_InternalWriteResultTable_Collation_Runtime_Contract.sql` materializes a framework-collated source table and a single-column target table. The contract verifies target adaptation and a successful result transfer. All character columns in the internal source and target schema work tables declare `SQL_Latin1_General_CP1_CS_AS` explicitly.

The contract passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The evidence covers source-schema materialization, target adaptation, and one-row transfer.

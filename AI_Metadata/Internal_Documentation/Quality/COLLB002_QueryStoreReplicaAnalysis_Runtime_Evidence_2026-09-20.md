# COLL-B002: Query Store Replica Analysis Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_QueryStoreReplicaAnalysis`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/QueryStore/143_QueryStoreReplicaAnalysis_Collation_Runtime_Contract.sql` executes the bounded SQL Server 2019 version-boundary path. The procedure explicitly applies `SQL_Latin1_General_CP1_CS_AS` to all character columns in its temporary result, status, warning, candidate, and mapping tables.

The contract passed against the isolated SQL Server 2019 Linux adapter database and returned `UNAVAILABLE_VERSION` as defined for the SQL Server 2025 replica-catalog feature boundary. The evidence does not establish SQL Server 2025 replica-catalog behavior.

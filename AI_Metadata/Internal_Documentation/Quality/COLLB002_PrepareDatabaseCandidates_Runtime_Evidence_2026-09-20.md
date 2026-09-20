# COLL-B002: Prepare Database Candidates Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_PrepareDatabaseCandidates`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/Common/122_PrepareDatabaseCandidates_Collation_Runtime_Contract.sql` supplies framework-collated candidate and warning target tables, then invokes the public candidate-preparation contract for `DeineDatenbank`. All character columns in `#PrepareDatabaseCandidates_Work` declare `SQL_Latin1_General_CP1_CS_AS` explicitly.

The contract passed against the isolated SQL Server 2019 Linux adapter database with case-insensitive server and `tempdb` collations. The evidence covers the focused single-database path, not all list and pattern variants.

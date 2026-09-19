# COLL-B005: Unicode JSON Runtime Evidence

**Date:** 19 September 2026  
**Scope:** `COLL-001`, `COLL-B005`, `[monitor].[InternalPrepareResultTables]`  
**Result:** Passed on SQL Server 2019

`Code/Tests/Integration/199_Result_Table_Json_Unicode_Collation_Runtime_Contract.sql` maps the JSON result names `Resume` and `Résumé` to distinct local TABLE targets. The contract requires both mappings to remain present and distinct under `SQL_Latin1_General_CP1_CS_AS`.

The contract passed against a temporary SQL Server 2019 database. It covers accent-distinct Unicode result names in the central mapping path. Supplementary-character fixtures and consumer-specific parser outputs remain outside this evidence.

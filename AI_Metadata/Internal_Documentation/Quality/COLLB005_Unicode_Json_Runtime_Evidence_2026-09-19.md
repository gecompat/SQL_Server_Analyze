# COLL-B005: Unicode JSON Runtime Evidence

**Date:** 19 September 2026
**Scope:** `COLL-001`, `COLL-B005`, `[monitor].[InternalPrepareResultTables]`
**Result:** Passed on SQL Server 2019

`Code/Tests/Integration/199_Result_Table_Json_Unicode_Collation_Runtime_Contract.sql` maps the accent-distinct JSON result names `Resume` and `Résumé`, plus two result names containing distinct supplementary characters, to separate local TABLE targets. The framework stores names under `SQL_Latin1_General_CP1_CS_AS` and validates mapping-key identity through the exact UTF-16 byte representation.

The contract passed against a temporary SQL Server 2019 database. It covers accent-distinct and supplementary-character Unicode result names in the central mapping path. Consumer-specific parser outputs remain outside this evidence.

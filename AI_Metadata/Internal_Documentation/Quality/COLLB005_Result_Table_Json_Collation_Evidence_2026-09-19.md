# COLL-B005: Result-Table JSON Collation Evidence

**Date:** 19 September 2026  
**Scope:** `COLL-001`, `COLL-B005`, `[monitor].[InternalPrepareResultTables]`  
**Result:** Statically enforced

`InternalPrepareResultTables` materializes `OPENJSON` keys and values only into explicitly framework-collated `ResultName` and `TargetTable` columns. `Code/Tests/Static/1004_Validate_ResultTable_Json_Collation.py` protects this central mapping contract through the repository static suite.

The contract covers source-level materialization of TABLE mapping JSON. Unicode case-, accent- and supplementary-character runtime fixtures for parser outputs remain outside this evidence.

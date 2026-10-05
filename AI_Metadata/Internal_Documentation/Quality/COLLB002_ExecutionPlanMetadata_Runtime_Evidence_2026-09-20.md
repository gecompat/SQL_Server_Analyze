# COLL-B002: Execution Plan Metadata Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.InternalCollectExecutionPlanMetadata`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/PlanCache/129_ExecutionPlanMetadata_Collation_Runtime_Contract.sql` invokes the confirmed `CURRENT_SERVER` metadata path through `monitor.USP_CreateExecutionEvidenceJson` with a synthetic, object-free Showplan document. The internal procedure explicitly applies `SQL_Latin1_General_CP1_CS_AS` to its object-reference, relevant-column, candidate-statistics, and predicate-value work tables.

The contract passed against the isolated SQL Server 2019 Linux adapter database. The evidence does not establish current metadata collection for referenced user objects or histogram steps.

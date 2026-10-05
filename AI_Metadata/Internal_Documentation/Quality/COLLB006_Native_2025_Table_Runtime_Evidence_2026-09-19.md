# COLL-B006: Native SQL Server 2025 TABLE Runtime Evidence

**Date:** 19 September 2026  
**Scope:** `COLL-001`, `COLL-B006`, `[monitor].[USP_DatabaseConfigurationAnalysis]`  
**Result:** Passed

The existing `LabAnalyze` database could not serve as a current-installer TABLE test because its historical `InternalWriteResultTable` metadata requires a different `QUOTED_IDENTIFIER` creation setting. The evidence therefore used the existing Linux SQL Server 2025 environment with temporary `ExampleCollationFramework2025` (`SQL_Latin1_General_CP1_CS_AS`) and `ExampleCollationTarget2025` (`Latin1_General_100_CI_AS`) databases. The current generated installer was directed only to the temporary framework database.

`USP_DatabaseConfigurationAnalysis` selected both databases and materialized `settings` into a local TABLE target. The result contained both database names and returned `AVAILABLE_LIMITED`, which is permitted when optional configuration sources are unavailable. Both temporary databases were removed after the run.

The evidence covers the current installer and native SQL Server 2025 Linux TABLE path. It does not establish every consumer-specific target schema or remove the need for remaining per-file collation hardening.

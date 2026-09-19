# COLL-B003: Native SQL Server 2022 Mixed Runtime Evidence

**Date:** 19 September 2026  
**Scope:** `COLL-001`, `COLL-B003`, `[monitor].[USP_DatabaseConfigurationAnalysis]`  
**Result:** Passed

The existing Linux SQL Server 2022 environment contained unrelated Toolbelt test databases without a framework installation. To avoid modifying them, the test created the temporary `ExampleCollationFramework2022` database with `SQL_Latin1_General_CP1_CS_AS` and `ExampleCollationTarget2022` with `Latin1_General_100_CI_AS`. The generated installer was directed only to the temporary framework database and both databases were removed after the test.

The procedure ran with `[ExampleCollationFramework2022]|[ExampleCollationTarget2022]`, returned valid JSON and `AVAILABLE_LIMITED`, and included both databases in `settings`. The status is permitted because optional configuration sources can be unavailable. This evidence covers the native 2022 Linux execution; remaining per-file cross-database coverage is not implied.

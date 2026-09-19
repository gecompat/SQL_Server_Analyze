# COLL-B003: Native SQL Server 2025 Mixed Runtime Evidence

**Date:** 19 September 2026  
**Scope:** `COLL-001`, `COLL-B003`, `[monitor].[USP_DatabaseConfigurationAnalysis]`  
**Result:** Passed

The existing Linux SQL Server 2025 environment was read without creating or altering databases. `LabAnalyze` uses `SQL_Latin1_General_CP1_CS_AS`; the visible target database `SQL_Server_Toolbelt` uses `SQL_Latin1_General_CP1_CI_AS`. The procedure ran from `LabAnalyze` with the exact bracket-aware filter `[LabAnalyze]|[SQL_Server_Toolbelt]`.

The call returned valid JSON and `AVAILABLE_LIMITED`. Its `settings` array contained both selected database names. `AVAILABLE_LIMITED` is permitted because an optional configuration source may be unavailable. The evidence covers this native 2025 Linux execution only; the native 2022 mixed target-database run and remaining per-file hardening remain open.

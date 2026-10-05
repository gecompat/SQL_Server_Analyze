# COLL-B003: Mixed Target-Database Runtime Evidence

**Date:** 19 September 2026  
**Scope:** `COLL-001`, `COLL-B003`, `[monitor].[USP_DatabaseConfigurationAnalysis]`  
**Result:** Passed

## Executed contract

The local Linux SQL Server 2019 environment used the server and `tempdb` collation `SQL_Latin1_General_CP1_CI_AS`. The framework was installed into a temporary `DeineDatenbank` database with `SQL_Latin1_General_CP1_CS_AS`. The test created `ExampleCollationTarget` with `Latin1_General_100_CI_AS` and called the procedure with the documented bracket-aware pipe list `[DeineDatenbank]|[ExampleCollationTarget]`.

The procedure returned valid JSON with `AVAILABLE_LIMITED`. The limited status is permitted by the procedure contract when an optional configuration source is unavailable on SQL Server 2019. The `settings` array contained both the framework database and the differently collated target database. The test removed both temporary databases after completion.

## Evidence boundary

This evidence demonstrates a SQL Server 2019 Linux execution with one framework database and one differently collated target database. It does not establish equivalent native SQL Server 2022 or SQL Server 2025 behavior, nor does it replace remaining per-file collation hardening.

## Reproducible test

`Code/Tests/ServerHealth/126_DatabaseConfigurationAnalysis_Mixed_Collation_Runtime_Contract.sql` performs the same isolated contract. It requires an installed framework in `DeineDatenbank`, permission to create and drop the synthetic target database, and an unused `ExampleCollationTarget` database name.

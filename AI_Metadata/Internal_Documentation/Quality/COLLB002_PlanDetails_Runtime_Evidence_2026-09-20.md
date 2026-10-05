# COLL-B002: Plan Details Runtime Evidence

**Date:** 2026-09-20  
**Scope:** `monitor.USP_PlanDetails`  
**Result:** Passed on SQL Server 2019 Linux

`Code/Tests/PlanCache/125_PlanDetails_Collation_Runtime_Contract.sql` executes a bounded Plan Details request without plan-source expansion. The procedure explicitly applies `SQL_Latin1_General_CP1_CS_AS` to its result-table mapping, attributes, plan, and candidates-output work tables.

The contract passed against the isolated SQL Server 2019 Linux adapter database. The evidence does not establish plan-attribute, compile-plan, text-plan, actual-plan, or live-plan result paths.

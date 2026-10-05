# COLL-B002: Log Shipping Runtime Evidence

**Date:** 19 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_LogShippingStatus]`
**Result:** Passed on SQL Server 2019

`Code/Tests/Infrastructure/123_LogShippingStatus_Collation_Runtime_Contract.sql` invokes the Log Shipping status path and verifies its JSON status contract. The procedure uses explicitly collated local work tables for primary and secondary Log Shipping metadata.

The contract passed against a temporary SQL Server 2019 database without creating or configuring Log Shipping. It accepts the feature's available and unavailable states, but does not establish populated Log Shipping source coverage or complete the remaining per-file tempdb-collation inventory.

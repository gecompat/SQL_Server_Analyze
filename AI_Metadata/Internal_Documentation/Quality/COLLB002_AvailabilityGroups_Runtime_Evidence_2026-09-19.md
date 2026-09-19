# COLL-B002: Availability Groups Runtime Evidence

**Date:** 19 September 2026
**Scope:** `COLL-001`, `COLL-B002`, `[monitor].[USP_AvailabilityGroups]`
**Result:** Passed on SQL Server 2019

`Code/Tests/Infrastructure/125_AvailabilityGroups_Collation_Runtime_Contract.sql` invokes the Availability Groups path and verifies its JSON status contract. The procedure uses explicitly collated local work tables for replicas, databases, listeners, and routing metadata.

The contract passed against a temporary SQL Server 2019 database without enabling or configuring HADR. It accepts the feature's available and unavailable states, but does not establish populated Availability Groups topology coverage or complete the remaining per-file tempdb-collation inventory.

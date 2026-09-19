# COLL-B004: Dynamic Parameter Contract Evidence

**Date:** 19 September 2026  
**Scope:** `COLL-001`, `COLL-B004`, `[monitor].[USP_PrepareDatabaseCandidates]`  
**Result:** Statically enforced

## Contract

`USP_PrepareDatabaseCandidates` is the central helper for exact database lists and regex database filters. Its dynamic SQL binds the system-database option as `@IncludeSystem bit` and binds regex input as typed `@Pattern nvarchar(4000)` and `@Flags varchar(8)` parameters. The dynamic batch does not interpolate those input values into SQL text.

`Code/Tests/Static/1003_Validate_DatabaseCandidates_Dynamic_Parameters.py` verifies these bindings and runs through the repository static contract suite. The check protects the central helper, not every dynamic SQL batch in the framework.

## Evidence boundary

The contract demonstrates source-level parameter binding for central database candidate preparation. It does not establish denied-permission behavior or case-sensitive identifier handling in every cross-database consumer; those remain tracked as `COLL-B004` evidence.

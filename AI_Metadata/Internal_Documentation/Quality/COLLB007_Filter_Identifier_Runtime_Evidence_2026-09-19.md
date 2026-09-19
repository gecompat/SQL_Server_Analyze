# COLL-B007: Filter Identifier Runtime Evidence

**Date:** 19 September 2026  
**Scope:** `COLL-001`, `COLL-B007`, `[monitor].[USP_PrepareNameFilters]`  
**Result:** Runtime contract added

`Code/Tests/Integration/166_Filter_Identifier_Collation_Runtime_Contract.sql` passes four bracket-aware synthetic names through the central filter procedure: two names differ only by case and two differ by accent. The contract requires `AVAILABLE`, preserves four rows and verifies four distinct values under `SQL_Latin1_General_CP1_CS_AS`.

The contract covers central filter parsing and duplicate validation. Individual cross-database consumers and supplementary-character fixtures remain outside this evidence.

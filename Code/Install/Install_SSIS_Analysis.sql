:ON ERROR EXIT

USE [DeineDatenbank];
GO

/*
SQLCMD-Teilinstaller für den direkten SSIS-001-DTSX-Parser und die lesende
Katalog- und Legacy-Ausführungsanalyse. Dynamische Quellen benötigen keine
vorhandenen Loggingtabellen zur Installation. Datei- und ISPAC-Adapter bleiben ausgenommen.
*/
:r ../00_Setup/000_Preflight_und_Schema.sql
:r ../01_Common/095_USP_InternalWriteResultTable.sql
:r ../01_Common/096_USP_InternalPrepareResultTables.sql
:r ../01_Common/098_USP_InternalEmitConsoleResult.sql
:r ../10_SSIS/010_USP_SsisPackageAnalysis.sql
:r ../10_SSIS/020_USP_SsisLegacyLogAnalysis.sql
:r ../10_SSIS/030_USP_SsisCatalogExecutionAnalysis.sql
:r ../10_SSIS/040_USP_SsisPackageModelAnalysis.sql

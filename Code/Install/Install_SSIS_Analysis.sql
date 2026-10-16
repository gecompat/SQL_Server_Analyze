:ON ERROR EXIT

USE [DeineDatenbank];
GO

/*
SQLCMD-Teilinstaller für den direkten SSIS-001-DTSX-Parser und die lesende
Katalogausführungsanalyse. Die dynamischen SSISDB-Abfragen benötigen keinen
Katalog zur Installation. Datei-, ISPAC- und Legacy-Adapter bleiben ausgenommen.
*/
:r ../00_Setup/000_Preflight_und_Schema.sql
:r ../01_Common/095_USP_InternalWriteResultTable.sql
:r ../01_Common/096_USP_InternalPrepareResultTables.sql
:r ../01_Common/098_USP_InternalEmitConsoleResult.sql
:r ../10_SSIS/010_USP_SsisPackageAnalysis.sql
:r ../10_SSIS/030_USP_SsisCatalogExecutionAnalysis.sql

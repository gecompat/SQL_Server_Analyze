:ON ERROR EXIT

USE [DeineDatenbank];
GO

/*
SQLCMD-Teilinstaller für den ersten statischen SSIS-001-DTSX-Parser-Slice.
Der Installer enthält nur Schema, sichere TABLE-Ausgabehelper und die direkte
XML-Analyse. Er installiert keinen Datei-, ISPAC-, SSISDB- oder Laufzeitadapter.
*/
:r ../00_Setup/000_Preflight_und_Schema.sql
:r ../01_Common/095_USP_InternalWriteResultTable.sql
:r ../01_Common/096_USP_InternalPrepareResultTables.sql
:r ../10_SSIS/010_USP_SsisPackageAnalysis.sql

USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 005_Deprecated_Object_Cleanup.sql
Stand        : 2026-07-15
Zweck        : Entfernt ausschließlich veraltete Frameworkobjekte aus früheren
               Zwischenständen. Fachliche Diagnoseobjekte und kundeneigene
               WaitTypeCatalog-Zeilen bleiben unverändert.
===============================================================================
*/

IF OBJECT_ID(N'monitor.USP_SQLServer2025Features',N'P') IS NOT NULL
    DROP PROCEDURE [monitor].[USP_SQLServer2025Features];
GO

IF OBJECT_ID(N'monitor.USP_FrameworkContractInventory',N'P') IS NOT NULL
    DROP PROCEDURE [monitor].[USP_FrameworkContractInventory];
IF OBJECT_ID(N'monitor.USP_FrameworkSelfTest',N'P') IS NOT NULL
    DROP PROCEDURE [monitor].[USP_FrameworkSelfTest];
IF OBJECT_ID(N'monitor.USP_FrameworkInstallationHistory',N'P') IS NOT NULL
    DROP PROCEDURE [monitor].[USP_FrameworkInstallationHistory];
IF OBJECT_ID(N'monitor.USP_FrameworkInstallationFinish',N'P') IS NOT NULL
    DROP PROCEDURE [monitor].[USP_FrameworkInstallationFinish];
IF OBJECT_ID(N'monitor.USP_FrameworkInstallationBegin',N'P') IS NOT NULL
    DROP PROCEDURE [monitor].[USP_FrameworkInstallationBegin];
GO

IF OBJECT_ID(N'monitor.FrameworkProcedureContract',N'U') IS NOT NULL
    DROP TABLE [monitor].[FrameworkProcedureContract];
IF OBJECT_ID(N'monitor.FrameworkExpectedObject',N'U') IS NOT NULL
    DROP TABLE [monitor].[FrameworkExpectedObject];
IF OBJECT_ID(N'monitor.FrameworkInstallationHistory',N'U') IS NOT NULL
    DROP TABLE [monitor].[FrameworkInstallationHistory];
GO

USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt/Datei : 000_Preflight_und_Schema.sql
Version      : 2.0.0
Zweck        : Prüft die SQL-Server-Baseline und die Collation der aktuell mit
               USE ausgewählten Installationsdatenbank. Legt das Schema monitor
               idempotent an. Der Platzhalter DeineDatenbank ist vor Ausführung
               durch den tatsächlichen Datenbanknamen zu ersetzen.
Voraussetzung: SQL Server 2019 oder höher; notwendige DDL-Rechte.
Seiteneffekte: Legt ausschließlich das Schema monitor an, sofern es fehlt.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ProductMajorVersion int = TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion'));
IF @ProductMajorVersion IS NULL OR @ProductMajorVersion < 15
    THROW 50001, N'Das Analyseframework unterstützt mindestens SQL Server 2019 (Major Version 15).', 1;

DECLARE @ExpectedCollation sysname = N'SQL_Latin1_General_CP1_CS_AS';
DECLARE @ServerCollation sysname = CONVERT(sysname, SERVERPROPERTY(N'Collation'));
DECLARE @TempDbCollation sysname = (SELECT [collation_name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [name]=N'tempdb');
DECLARE @TargetDatabaseCollation sysname = (SELECT [collation_name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID());

IF @ServerCollation COLLATE Latin1_General_100_BIN2 <> @ExpectedCollation COLLATE Latin1_General_100_BIN2
BEGIN
    DECLARE @ServerCollationError nvarchar(2048) = CONCAT(N'Nicht unterstützte Server-Collation: ', COALESCE(@ServerCollation,N'<NULL>'), N'. Erwartet wird SQL_Latin1_General_CP1_CS_AS.');
    THROW 50003, @ServerCollationError, 1;
END;
IF @TempDbCollation COLLATE Latin1_General_100_BIN2 <> @ExpectedCollation COLLATE Latin1_General_100_BIN2
BEGIN
    DECLARE @TempDbCollationError nvarchar(2048) = CONCAT(N'Nicht unterstützte tempdb-Collation: ', COALESCE(@TempDbCollation,N'<NULL>'), N'. Erwartet wird SQL_Latin1_General_CP1_CS_AS.');
    THROW 50004, @TempDbCollationError, 1;
END;
IF @TargetDatabaseCollation COLLATE Latin1_General_100_BIN2 <> @ExpectedCollation COLLATE Latin1_General_100_BIN2
BEGIN
    DECLARE @TargetCollationError nvarchar(2048) = CONCAT(N'Nicht unterstützte Collation der Installationsdatenbank ', QUOTENAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID())), N': ', COALESCE(@TargetDatabaseCollation,N'<NULL>'), N'. Erwartet wird SQL_Latin1_General_CP1_CS_AS.');
    THROW 50005, @TargetCollationError, 1;
END;
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[schemas] AS [s] WITH (NOLOCK) WHERE [s].[name] = N'monitor')
BEGIN
    EXEC [sys].[sp_executesql] N'CREATE SCHEMA [monitor] AUTHORIZATION [dbo];';
END;
GO

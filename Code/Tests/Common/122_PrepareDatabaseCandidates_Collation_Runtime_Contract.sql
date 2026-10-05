USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

CREATE TABLE [#PrepareDatabaseCandidates_Runtime]
(
      [DatabaseId] int NOT NULL
    , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [IsReadOnly] bit NULL
    , [CompatibilityLevel] tinyint NULL
    , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [IsSystemDatabase] bit NULL
    , [RequestedOrdinal] int NULL
);

CREATE TABLE [#PrepareDatabaseCandidates_Warnings]
(
      [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);

DECLARE @StatusCode varchar(40);
DECLARE @ErrorMessage nvarchar(2048);
DECLARE @CrossDatabaseRequested bit;
DECLARE @DatabaseName sysname = DB_NAME();

EXEC [monitor].[USP_PrepareDatabaseCandidates]
      @DatabaseNames = @DatabaseName
    , @StatusCode = @StatusCode OUTPUT
    , @ErrorMessage = @ErrorMessage OUTPUT
    , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT
    , @CandidateTable = N'#PrepareDatabaseCandidates_Runtime'
    , @WarningTable = N'#PrepareDatabaseCandidates_Warnings';

IF @StatusCode <> 'AVAILABLE'
   OR @CrossDatabaseRequested <> 0
   OR NOT EXISTS (SELECT 1 FROM [#PrepareDatabaseCandidates_Runtime])
   OR EXISTS (SELECT 1 FROM [#PrepareDatabaseCandidates_Warnings])
    THROW 55710, N'USP_PrepareDatabaseCandidates returned an unexpected runtime contract.', 1;

PRINT N'PrepareDatabaseCandidates collation runtime contract passed.';
GO

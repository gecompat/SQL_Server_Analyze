USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

CREATE TABLE [#InternalWriteResultTable_Source]
(
    [Value] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);

CREATE TABLE [#InternalWriteResultTable_Target]
(
    [Dummy] int NULL
);

INSERT [#InternalWriteResultTable_Source] ([Value]) VALUES (N'framework-collation');

DECLARE @InsertedRows bigint;
DECLARE @StatusCode varchar(40);
DECLARE @ErrorNumber int;
DECLARE @ErrorMessage nvarchar(2048);

EXEC [monitor].[InternalWriteResultTable]
      @SourceTable = N'#InternalWriteResultTable_Source'
    , @TargetTable = N'#InternalWriteResultTable_Target'
    , @InsertedRows = @InsertedRows OUTPUT
    , @StatusCode = @StatusCode OUTPUT
    , @ErrorNumber = @ErrorNumber OUTPUT
    , @ErrorMessage = @ErrorMessage OUTPUT
    , @ThrowOnError = 1;

IF @StatusCode <> 'AVAILABLE'
   OR @InsertedRows <> 1
   OR NOT EXISTS
      (
          SELECT 1
          FROM [#InternalWriteResultTable_Target]
          WHERE [Value] = N'framework-collation'
      )
    THROW 55720, N'InternalWriteResultTable returned an unexpected runtime contract.', 1;

PRINT N'InternalWriteResultTable collation runtime contract passed.';
GO

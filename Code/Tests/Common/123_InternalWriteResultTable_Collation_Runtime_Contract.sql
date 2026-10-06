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

/* Die eigenen Metadatenanlagen werden auch bei geerbtem NOWAIT geprüft.
   Wiederholungen belegen die getesteten Aufrufe, keine bestimmte Lockursache. */
CREATE TABLE [#ResultTableOwnDdl_Seed]([Seed] bit NULL);
DECLARE @OwnDdlCallerTimeout int=@@LOCK_TIMEOUT,@OwnDdlPass int=0,@OwnDdlRepeat int,@OwnDdlTarget sysname;
BEGIN TRY
    WHILE @OwnDdlPass<2
    BEGIN
        IF @OwnDdlPass=0 SET LOCK_TIMEOUT 0 ELSE SET LOCK_TIMEOUT 731;
        SET @OwnDdlRepeat=0;
        WHILE @OwnDdlRepeat<25
        BEGIN
            SET @OwnDdlTarget=NULL;
            EXEC [monitor].[InternalPrepareSingleResultTable]
                  @ResultTablesJson=N'{"findings":"#ResultTableOwnDdl_Seed"}',@ResultName=N'findings',
                  @TargetTable=@OwnDdlTarget OUTPUT,@ThrowOnError=1;
            IF COALESCE(@OwnDdlTarget,N'')<>N'#ResultTableOwnDdl_Seed'
                THROW 55721,N'Repeated TABLE preflight target identity failed.',1;
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=N'#InternalWriteResultTable_Source',@TargetTable=N'#InternalWriteResultTable_Target',
                  @InsertedRows=@InsertedRows OUTPUT,@StatusCode=@StatusCode OUTPUT,
                  @ErrorNumber=@ErrorNumber OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT,@ThrowOnError=1;
            IF COALESCE(@StatusCode,'')<>'AVAILABLE' OR COALESCE(@InsertedRows,-1)<>1
                THROW 55722,N'Repeated TABLE append failed.',1;
            IF @@LOCK_TIMEOUT<>CASE WHEN @OwnDdlPass=0 THEN 0 ELSE 731 END
                THROW 55723,N'TABLE helper changed caller timeout.',1;
            SET @OwnDdlRepeat+=1;
        END;
        DECLARE @OwnDdlRejected bit=0;
        BEGIN TRY
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=N'#InternalWriteResultTable_Source',@TargetTable=N'##ExampleInvalidTarget',@ThrowOnError=1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER()<>51010 THROW;
            SET @OwnDdlRejected=1;
        END CATCH;
        IF @OwnDdlRejected<>1 OR @@LOCK_TIMEOUT<>CASE WHEN @OwnDdlPass=0 THEN 0 ELSE 731 END
            THROW 55724,N'TABLE invalid-target or error timeout contract failed.',1;
        SET @OwnDdlPass+=1;
    END;
    DECLARE @OwnDdlRows bigint;
    EXEC [sys].[sp_executesql] N'SELECT @pRows=COUNT_BIG(*) FROM [#InternalWriteResultTable_Target];',
         N'@pRows bigint OUTPUT',@pRows=@OwnDdlRows OUTPUT;
    IF @OwnDdlRows<>51 THROW 55725,N'TABLE repeated append cardinality failed.',1;
    DECLARE @OwnDdlRestore nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OwnDdlCallerTimeout)+N';';
    EXEC [sys].[sp_executesql] @OwnDdlRestore;
END TRY
BEGIN CATCH
    DECLARE @OwnDdlErrorRestore nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OwnDdlCallerTimeout)+N';';
    EXEC [sys].[sp_executesql] @OwnDdlErrorRestore;
    THROW;
END CATCH;

PRINT N'InternalWriteResultTable collation runtime contract passed.';
GO

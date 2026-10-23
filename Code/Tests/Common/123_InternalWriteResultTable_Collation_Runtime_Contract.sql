USE [DeineDatenbank];
GO

IF OBJECT_ID(N'monitor.ExampleTableExportContract') IS NOT NULL
    THROW 55742,N'TABLE contract scope ownership conflict.',1;
GO

CREATE PROCEDURE [monitor].[ExampleTableExportContract]
AS
BEGIN
SET NOCOUNT ON;

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

/* Kontrollierte Fehlerinjektion prüft die Meldung, keinen realen Blocker.
   Nur die Testkopie ersetzt je einen dynamischen SQL-Aufruf durch Fehler 1222. */
DECLARE @TimeoutDefinition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'monitor.InternalWriteResultTable'));
DECLARE @TimeoutHeader nvarchar(128)=N'PROCEDURE [monitor].[InternalWriteResultTable]';
DECLARE @TimeoutHeaderAt int=CHARINDEX(@TimeoutHeader,@TimeoutDefinition);
IF @TimeoutDefinition IS NULL OR COALESCE(@TimeoutHeaderAt,0)=0
    THROW 55726,N'TABLE timeout source definition unavailable.',1;
IF OBJECT_ID(N'monitor.ExampleTableExportTimeoutProbe') IS NOT NULL
    THROW 55727,N'TABLE timeout probe ownership conflict.',1;
DECLARE @TimeoutOriginalText nvarchar(2048);
BEGIN TRY
    RAISERROR(1222,16,1);
END TRY
BEGIN CATCH
    IF ERROR_NUMBER()<>1222 THROW;
    SET @TimeoutOriginalText=ERROR_MESSAGE();
END CATCH;
IF @TimeoutOriginalText IS NULL OR LEN(@TimeoutOriginalText)=0
    THROW 55741,N'TABLE timeout original message unavailable.',1;
DECLARE @TimeoutBase nvarchar(max)=N'CREATE PROCEDURE [monitor].[ExampleTableExportTimeoutProbe]'
    +SUBSTRING(@TimeoutDefinition,@TimeoutHeaderAt+LEN(@TimeoutHeader),LEN(@TimeoutDefinition));
DECLARE @TimeoutStep int=0,@TimeoutThrow bit,@TimeoutProbeId int=NULL,@TimeoutNeedle nvarchar(32),
    @TimeoutAt int,@TimeoutCopy nvarchar(max),@TimeoutTarget sysname,@TimeoutSql nvarchar(max),
    @TimeoutCallerLock int=@@LOCK_TIMEOUT,@TimeoutCallerOptions int=@@OPTIONS,@TimeoutCallerTran int=@@TRANCOUNT;
BEGIN TRY
    WHILE @TimeoutStep<2
    BEGIN
        SET @TimeoutNeedle=CASE @TimeoutStep WHEN 0 THEN N'@HasRowsSql' ELSE N'@AlterSql' END;
        SET @TimeoutAt=CHARINDEX(@TimeoutNeedle,@TimeoutBase);
        SET @TimeoutAt=CHARINDEX(@TimeoutNeedle,@TimeoutBase,@TimeoutAt+LEN(@TimeoutNeedle));
        IF @TimeoutAt=0 OR CHARINDEX(@TimeoutNeedle,@TimeoutBase,@TimeoutAt+LEN(@TimeoutNeedle))<>0
            THROW 55728,N'TABLE timeout injection binding changed.',1;
        SET @TimeoutCopy=STUFF(@TimeoutBase,@TimeoutAt,LEN(@TimeoutNeedle),
            N'N''RAISERROR(1222,16,1);''');
        EXEC [sys].[sp_executesql] @TimeoutCopy;
        SET @TimeoutProbeId=OBJECT_ID(N'monitor.ExampleTableExportTimeoutProbe');
        IF @TimeoutProbeId IS NULL THROW 55729,N'TABLE timeout probe creation failed.',1;
        SET @TimeoutThrow=0;
        WHILE @TimeoutThrow IS NOT NULL
        BEGIN
            SET @TimeoutTarget=CASE @TimeoutThrow WHEN 0 THEN N'#ExampleTableExport%s'
                ELSE N'#ExampleExport] "%d'+NCHAR(13)+NCHAR(10)+NCHAR(9)+REPLICATE(N'Ä',60) END;
            SET @TimeoutSql=N'
IF OBJECT_ID(N''tempdb..''+QUOTENAME(@Name)) IS NOT NULL THROW 55730,N''TABLE timeout target collision.'',1;
CREATE TABLE '+QUOTENAME(@TimeoutTarget)+N'([Dummy] int NULL);
DECLARE @Owned int=OBJECT_ID(N''tempdb..''+QUOTENAME(@Name));
BEGIN TRY
    DECLARE @Rows bigint,@Status varchar(40),@Native int,@Message nvarchar(2048),@Caught bit=0;
    DECLARE @Expected nvarchar(1024)=CONCAT(N''TargetTable="'',REPLACE(STRING_ESCAPE(@Name,''json''),N''%'',N''\u0025''),N''"; SqlStep='',@Step,N''; '');
    DECLARE @ThrownPrefix nvarchar(1100)=N''TABLE-Ausgabe fehlgeschlagen (LOCK_TIMEOUT): ''+@Expected;
    SET LOCK_TIMEOUT 731;
    BEGIN TRY
        EXEC [monitor].[ExampleTableExportTimeoutProbe]
              @SourceTable=N''#InternalWriteResultTable_Source'',@TargetTable=@Name,
              @InsertedRows=@Rows OUTPUT,@StatusCode=@Status OUTPUT,@ErrorNumber=@Native OUTPUT,
              @ErrorMessage=@Message OUTPUT,@ThrowOnError=@Throw;
        IF @Throw=1 THROW 55731,N''TABLE timeout throw missing.'',1;
        IF COALESCE(@Status,'''')<>''LOCK_TIMEOUT'' OR COALESCE(@Native,-1)<>1222 OR COALESCE(@Rows,-1)<>0
            THROW 55732,N''TABLE timeout output status changed.'',1;
        IF @Message IS NULL OR LEFT(@Message,LEN(@Expected))<>@Expected
            THROW 55733,N''TABLE timeout output context missing.'',1;
    END TRY
    BEGIN CATCH
        IF @Throw<>1 OR ERROR_NUMBER()<>51010 THROW;
        SET @Caught=1; SET @Message=ERROR_MESSAGE();
        IF LEFT(@Message,LEN(@ThrownPrefix))<>@ThrownPrefix
            THROW 55734,N''TABLE timeout exception context missing.'',1;
    END CATCH;
    IF (@Throw=1 AND @Caught<>1) OR @@LOCK_TIMEOUT<>731 OR @@OPTIONS<>@Options OR @@TRANCOUNT<>@Tran
        THROW 55735,N''TABLE timeout caller state changed.'',1;
    IF @Message IS NULL OR @Original IS NULL OR DATALENGTH(@Message)>4096
       OR CHARINDEX(NCHAR(13),@Message)>0 OR CHARINDEX(NCHAR(10),@Message)>0
       OR CHARINDEX(NCHAR(9),@Message)>0 OR CHARINDEX(@Original,@Message)=0
        THROW 55736,N''TABLE timeout message encoding or bounds failed.'',1;
    IF EXISTS(SELECT 1 FROM '+QUOTENAME(@TimeoutTarget)+N')
       OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=@Owned)<>1
        THROW 55737,N''TABLE timeout target was changed.'',1;
    DROP TABLE '+QUOTENAME(@TimeoutTarget)+N';
END TRY
BEGIN CATCH
    IF OBJECT_ID(N''tempdb..''+QUOTENAME(@Name))=@Owned DROP TABLE '+QUOTENAME(@TimeoutTarget)+N';
    THROW;
END CATCH;';
            DECLARE @TimeoutStepName varchar(32)=CASE @TimeoutStep WHEN 0 THEN 'TARGET_EMPTY_CHECK' ELSE 'TARGET_SCHEMA_ADAPT' END;
            EXEC [sys].[sp_executesql] @TimeoutSql,
                N'@Name sysname,@Step varchar(32),@Throw bit,@Options int,@Tran int,@Original nvarchar(2048)',
                @Name=@TimeoutTarget,@Step=@TimeoutStepName,@Throw=@TimeoutThrow,
                @Options=@TimeoutCallerOptions,@Tran=@TimeoutCallerTran,@Original=@TimeoutOriginalText;
            IF OBJECT_ID(N'tempdb..'+QUOTENAME(@TimeoutTarget)) IS NOT NULL
                THROW 55738,N'TABLE timeout target cleanup failed.',1;
            SET @TimeoutThrow=CASE @TimeoutThrow WHEN 0 THEN 1 ELSE NULL END;
        END;
        IF OBJECT_ID(N'monitor.ExampleTableExportTimeoutProbe')<>@TimeoutProbeId
            THROW 55739,N'TABLE timeout probe ownership changed.',1;
        DROP PROCEDURE [monitor].[ExampleTableExportTimeoutProbe];
        SET @TimeoutProbeId=NULL;
        SET @TimeoutStep+=1;
    END;
    IF @@LOCK_TIMEOUT<>@TimeoutCallerLock OR @@OPTIONS<>@TimeoutCallerOptions OR @@TRANCOUNT<>@TimeoutCallerTran
        THROW 55740,N'TABLE timeout outer caller state changed.',1;
END TRY
BEGIN CATCH
    IF @TimeoutProbeId IS NOT NULL AND OBJECT_ID(N'monitor.ExampleTableExportTimeoutProbe')=@TimeoutProbeId
        DROP PROCEDURE [monitor].[ExampleTableExportTimeoutProbe];
    THROW;
END CATCH;

PRINT N'InternalWriteResultTable collation and timeout context runtime contracts passed.';
END;
GO

DECLARE @ContractCallerLock int=@@LOCK_TIMEOUT,@ContractCallerOptions int=@@OPTIONS,@ContractCallerTran int=@@TRANCOUNT;
DECLARE @ContractOwnedId int=OBJECT_ID(N'monitor.ExampleTableExportContract');
BEGIN TRY
    EXEC [monitor].[ExampleTableExportContract];
    IF @@LOCK_TIMEOUT<>@ContractCallerLock OR @@OPTIONS<>@ContractCallerOptions OR @@TRANCOUNT<>@ContractCallerTran
        THROW 55743,N'TABLE contract leaked caller state.',1;
    DROP PROCEDURE [monitor].[ExampleTableExportContract];
END TRY
BEGIN CATCH
    IF OBJECT_ID(N'monitor.ExampleTableExportContract')=@ContractOwnedId
        DROP PROCEDURE [monitor].[ExampleTableExportContract];
    THROW;
END CATCH;
GO

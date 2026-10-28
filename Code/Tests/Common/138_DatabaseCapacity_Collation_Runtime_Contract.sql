USE [DeineDatenbank];
GO
-- CI: COMPATIBILITY_LEVELS=150,160,170
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_ID(N'ExampleCapacityDatabase') IS NOT NULL
    THROW 55879,N'Die eigene Kapazitätsfixture darf keine bestehende Datenbank verwenden.',1;
CREATE TABLE [#ExampleCapacityContext]([ProcedureName] nvarchar(776) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
INSERT [#ExampleCapacityContext] VALUES(QUOTENAME(DB_NAME())+N'.[monitor].[USP_DatabaseCapacityAnalysis]');
DECLARE @Created bit=0,@Setup nvarchar(max),@Name sysname;
BEGIN TRY
    CREATE DATABASE [ExampleCapacityDatabase];
    SET @Created=1;
    SELECT TOP(1) @Name=[name] FROM [ExampleCapacityDatabase].[sys].[database_files] WHERE [type]=0 ORDER BY [file_id];
    SET @Setup=N'ALTER DATABASE [ExampleCapacityDatabase] MODIFY FILE(NAME=N'''+REPLACE(@Name,N'''',N'''''')+N''',FILEGROWTH=0);';
    EXEC [sys].[sp_executesql] @Setup;
    ALTER DATABASE [ExampleCapacityDatabase] SET READ_ONLY;
END TRY
BEGIN CATCH
    IF @Created=1 AND DB_ID(N'ExampleCapacityDatabase') IS NOT NULL DROP DATABASE [ExampleCapacityDatabase];
    THROW;
END CATCH;
GO
USE [ExampleCapacityDatabase];
DECLARE @Database sysname=DB_NAME(),@FileId int,
        @Json nvarchar(max),@Status varchar(40),@Partial bit,@Case tinyint=0,@Limit int,@Problems bit,@Expected bigint,
        @ProblemCount bigint,@FirstFileId int,@Procedure nvarchar(776);
SELECT @Procedure=[ProcedureName] FROM [#ExampleCapacityContext];
DECLARE @Parity TABLE([TableJson] nvarchar(max),[ModuleJson] nvarchar(max));
DECLARE @NativeOracle TABLE
(
      [FileId] int NOT NULL PRIMARY KEY
    , [DatabaseId] int NULL
    , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [LogicalFileName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [FileTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [PhysicalName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [FileSizeMb] decimal(19,2) NULL
    , [UsedInFileMb] decimal(19,2) NULL
    , [FreeInFileMb] decimal(19,2) NULL
    , [FreeInFilePercent] decimal(9,2) NULL
    , [MaxSizeMb] decimal(19,2) NULL
    , [GrowthDescription] nvarchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [NextGrowthMb] decimal(19,2) NULL
    , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
DECLARE @OracleFailureReasons TABLE
(
      [FileOrdinal] int NOT NULL
    , [ReasonOrdinal] tinyint NOT NULL
    , [ReasonKey] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
DECLARE @OracleFailureOrdinal int,@OracleFailureKeys nvarchar(max),@OracleFailureMessage nvarchar(2048);
SELECT TOP(1) @FileId=[file_id] FROM [sys].[database_files] WHERE [type]=0 ORDER BY [file_id];
BEGIN TRY
    WHILE @Case<4
    BEGIN
        SELECT @Limit=CASE WHEN @Case=1 THEN 1 WHEN @Case=3 THEN NULL ELSE 0 END,
               @Problems=CASE WHEN @Case=3 THEN NULL WHEN @Case=2 THEN 1 ELSE 0 END;
        SELECT @Expected=CASE WHEN @Case=1 THEN 1 WHEN @Case>=2 THEN @ProblemCount ELSE (SELECT COUNT_BIG(*) FROM [sys].[database_files]) END;
        CREATE TABLE [#ExampleCapacity]([Dummy] int NULL);
        SELECT @Json=NULL,@Status=NULL,@Partial=NULL;
        EXEC @Procedure @DatabaseNames=@Database,@MinVolumeFreePercent=0,
            @NurProblematisch=@Problems,@MaxZeilen=@Limit,@ResultSetArt='TABLE',@ResultTablesJson=N'{"capacity":"#ExampleCapacity"}',
            @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCapacity')
              AND [collation_name] IS NOT NULL)<>9
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCapacity')
                       AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 55871,N'Der DatabaseCapacity-Export übernimmt eine fremde tempdb-Collation.',1;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>'AVAILABLE_WITH_FINDING' OR COALESCE(@Partial,1)<>0
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
           OR JSON_VALUE(@Json,N'$.meta.errorNumber') IS NOT NULL OR JSON_VALUE(@Json,N'$.meta.errorMessage') IS NOT NULL
           OR COALESCE(JSON_QUERY(@Json,N'$.warnings'),N'')<>N'[]'
           OR (SELECT COUNT_BIG(*) FROM [#ExampleCapacity])<>@Expected
           OR (@Case<>1 AND NOT EXISTS(SELECT 1 FROM [#ExampleCapacity] WHERE [DatabaseId]=DB_ID() AND [FileId]=@FileId
                           AND [FindingCode]='GROWTH_DISABLED' AND [GrowthDescription]=N'DISABLED' AND [NextGrowthMb] IS NULL))
           OR (@Case=1 AND NOT EXISTS(SELECT 1 FROM [#ExampleCapacity] WHERE [FileId]=@FirstFileId))
           OR (@Case>=2 AND EXISTS(SELECT 1 FROM [#ExampleCapacity] WHERE [FindingCode]='NO_CAPACITY_INDICATOR' OR [FindingCode] IS NULL))
            THROW 55870,N'Der positive DatabaseCapacity-Status-, Filter- oder Limitvertrag ist verletzt.',1;
        DELETE FROM @NativeOracle;
        INSERT @NativeOracle
        (
              [FileId],[DatabaseId],[DatabaseName],[LogicalFileName],[FileTypeDesc]
            , [PhysicalName],[FileSizeMb],[UsedInFileMb],[FreeInFileMb],[FreeInFilePercent]
            , [MaxSizeMb],[GrowthDescription],[NextGrowthMb],[FindingCode]
        )
        SELECT [f].[file_id],DB_ID(),DB_NAME() COLLATE SQL_Latin1_General_CP1_CS_AS,
               [f].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,
               [f].[type_desc] COLLATE SQL_Latin1_General_CP1_CS_AS,
               [f].[physical_name] COLLATE SQL_Latin1_General_CP1_CS_AS,
               CONVERT(decimal(19,2),[f].[size]*8.0/1024.0),
               CONVERT(decimal(19,2),COALESCE(FILEPROPERTY([f].[name],'SpaceUsed'),0)*8.0/1024.0),
               CONVERT(decimal(19,2),([f].[size]-COALESCE(FILEPROPERTY([f].[name],'SpaceUsed'),0))*8.0/1024.0),
               CONVERT(decimal(9,2),100.0*([f].[size]-COALESCE(FILEPROPERTY([f].[name],'SpaceUsed'),0))/NULLIF([f].[size],0)),
               CASE WHEN [f].[max_size]=-1 THEN NULL ELSE CONVERT(decimal(19,2),[f].[max_size]*8.0/1024.0) END,
               CASE WHEN [f].[growth]=0 THEN N'DISABLED'
                    WHEN [f].[is_percent_growth]=1 THEN CONCAT([f].[growth],N' percent')
                    ELSE CONCAT(CONVERT(decimal(19,2),[f].[growth]*8.0/1024.0),N' MB') END COLLATE SQL_Latin1_General_CP1_CS_AS,
               CASE WHEN [f].[growth]=0 THEN NULL WHEN [f].[is_percent_growth]=1
                    THEN CONVERT(decimal(19,2),CEILING([f].[size]*[f].[growth]/100.0)*8.0/1024.0)
                    ELSE CONVERT(decimal(19,2),[f].[growth]*8.0/1024.0) END,
               CASE WHEN [f].[growth]=0 THEN 'GROWTH_DISABLED'
                    WHEN [f].[max_size]<>-1 AND [f].[size]>=[f].[max_size] THEN 'FILE_MAX_SIZE_REACHED'
                    WHEN (CASE WHEN [f].[is_percent_growth]=1 THEN CEILING([f].[size]*[f].[growth]/100.0)*8192.0
                               ELSE [f].[growth]*8192.0 END)>
                         [v].[available_bytes]
                         THEN 'NEXT_GROWTH_EXCEEDS_VOLUME_FREE'
                    WHEN [f].[is_percent_growth]=1 THEN 'PERCENT_GROWTH_REVIEW'
                    ELSE 'NO_CAPACITY_INDICATOR' END COLLATE SQL_Latin1_General_CP1_CS_AS
        FROM [sys].[database_files] AS [f]
        OUTER APPLY [sys].[dm_os_volume_stats](DB_ID(),[f].[file_id]) AS [v];

        IF EXISTS
        (
            SELECT 1
            FROM [#ExampleCapacity] AS [e]
            LEFT JOIN @NativeOracle AS [n] ON [n].[FileId]=[e].[FileId]
            WHERE [n].[FileId] IS NULL
               OR EXISTS
                  (SELECT [e].[DatabaseId],[e].[DatabaseName],[e].[LogicalFileName],[e].[FileTypeDesc],
                          [e].[PhysicalName],[e].[FileSizeMb],[e].[UsedInFileMb],[e].[FreeInFileMb],
                          [e].[FreeInFilePercent],[e].[MaxSizeMb],[e].[GrowthDescription],[e].[NextGrowthMb],[e].[FindingCode]
                   EXCEPT
                   SELECT [n].[DatabaseId],[n].[DatabaseName],[n].[LogicalFileName],[n].[FileTypeDesc],
                          [n].[PhysicalName],[n].[FileSizeMb],[n].[UsedInFileMb],[n].[FreeInFileMb],
                          [n].[FreeInFilePercent],[n].[MaxSizeMb],[n].[GrowthDescription],[n].[NextGrowthMb],[n].[FindingCode])
               OR COALESCE([e].[VolumeTotalMb],0)<=0
               OR COALESCE([e].[VolumeAvailableMb],-1)<0
               OR [e].[VolumeFreePercent] IS NULL
               OR [e].[VolumeFreePercent]<0
               OR [e].[VolumeFreePercent]>100
        )
        BEGIN
            DELETE FROM @OracleFailureReasons;
            ;WITH [OrderedCapacity] AS
            (
                SELECT [e].*,ROW_NUMBER() OVER
                    (ORDER BY [e].[FileId],[e].[DatabaseId],[e].[DatabaseName],[e].[LogicalFileName],
                              [e].[FileTypeDesc],[e].[PhysicalName],[e].[FileSizeMb],[e].[UsedInFileMb],
                              [e].[FreeInFileMb],[e].[FreeInFilePercent],[e].[MaxSizeMb],
                              [e].[GrowthDescription],[e].[NextGrowthMb],[e].[FindingCode]) AS [FileOrdinal]
                FROM [#ExampleCapacity] AS [e]
            )
            INSERT @OracleFailureReasons([FileOrdinal],[ReasonOrdinal],[ReasonKey])
            SELECT [e].[FileOrdinal],[r].[ReasonOrdinal],[r].[ReasonKey]
            FROM [OrderedCapacity] AS [e]
            LEFT JOIN @NativeOracle AS [n] ON [n].[FileId]=[e].[FileId]
            CROSS APPLY (VALUES
                  (CONVERT(tinyint,1),'missingFileRow',CASE WHEN [n].[FileId] IS NULL THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,2),'DatabaseId',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[DatabaseId] EXCEPT SELECT [n].[DatabaseId]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,3),'DatabaseName',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[DatabaseName] EXCEPT SELECT [n].[DatabaseName]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,4),'LogicalFileName',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[LogicalFileName] EXCEPT SELECT [n].[LogicalFileName]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,5),'FileTypeDesc',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[FileTypeDesc] EXCEPT SELECT [n].[FileTypeDesc]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,6),'PhysicalName',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[PhysicalName] EXCEPT SELECT [n].[PhysicalName]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,7),'FileSizeMb',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[FileSizeMb] EXCEPT SELECT [n].[FileSizeMb]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,8),'UsedInFileMb',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[UsedInFileMb] EXCEPT SELECT [n].[UsedInFileMb]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,9),'FreeInFileMb',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[FreeInFileMb] EXCEPT SELECT [n].[FreeInFileMb]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,10),'FreeInFilePercent',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[FreeInFilePercent] EXCEPT SELECT [n].[FreeInFilePercent]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,11),'MaxSizeMb',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[MaxSizeMb] EXCEPT SELECT [n].[MaxSizeMb]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,12),'GrowthDescription',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[GrowthDescription] EXCEPT SELECT [n].[GrowthDescription]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,13),'NextGrowthMb',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[NextGrowthMb] EXCEPT SELECT [n].[NextGrowthMb]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,14),'FindingCode',CASE WHEN [n].[FileId] IS NOT NULL AND EXISTS(SELECT [e].[FindingCode] EXCEPT SELECT [n].[FindingCode]) THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,15),'VolumeTotalMb',CASE WHEN COALESCE([e].[VolumeTotalMb],0)<=0 THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,16),'VolumeAvailableMb',CASE WHEN COALESCE([e].[VolumeAvailableMb],-1)<0 THEN 1 ELSE 0 END)
                , (CONVERT(tinyint,17),'VolumeFreePercent',CASE WHEN [e].[VolumeFreePercent] IS NULL OR [e].[VolumeFreePercent]<0 OR [e].[VolumeFreePercent]>100 THEN 1 ELSE 0 END)
            ) AS [r]([ReasonOrdinal],[ReasonKey],[IsFailure])
            WHERE [r].[IsFailure]=1;

            SELECT @OracleFailureOrdinal=MIN([FileOrdinal]) FROM @OracleFailureReasons;
            SELECT @OracleFailureKeys=STRING_AGG(CONVERT(nvarchar(max),[ReasonKey]),N'|') WITHIN GROUP(ORDER BY [ReasonOrdinal])
            FROM @OracleFailureReasons
            WHERE [FileOrdinal]=@OracleFailureOrdinal;
            SET @OracleFailureMessage=CONCAT(N'DatabaseCapacity oracle failed; testCase=',@Case,
                N'; fileOrdinal=',@OracleFailureOrdinal,N'; reasonKeys=',@OracleFailureKeys,N'.');
            THROW 55872,@OracleFailureMessage,1;
        END;
        IF @Case=0
        BEGIN
            SELECT @ProblemCount=COUNT_BIG(*) FROM [#ExampleCapacity] WHERE [FindingCode]<>'NO_CAPACITY_INDICATOR';
            SELECT TOP(1) @FirstFileId=[FileId] FROM [#ExampleCapacity]
            ORDER BY CASE WHEN [FindingCode]='NO_CAPACITY_INDICATOR' THEN 1 ELSE 0 END,
                     [VolumeFreePercent],[DatabaseName],[FileId],[DatabaseId];
        END;
        DELETE @Parity;
        INSERT @Parity VALUES((SELECT * FROM [#ExampleCapacity] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.capacity'));
    IF EXISTS(SELECT 1 FROM @Parity AS [p]
               WHERE LEFT(COALESCE([p].[ModuleJson],N''),1)<>N'['
                 OR (SELECT COUNT_BIG(*) FROM OPENJSON([p].[TableJson]))<>(SELECT COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]))
                 OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[TableJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
                           EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[ModuleJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
                 OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[ModuleJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
                           EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[TableJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS))
        THROW 55873,N'TABLE und JSON enthalten verschiedene DatabaseCapacity-Ergebnisse.',1;

        DROP TABLE [#ExampleCapacity];
        SET @Case+=1;
    END;
    USE [master];
    DROP DATABASE [ExampleCapacityDatabase];
END TRY
BEGIN CATCH
    USE [master];
    IF DB_ID(N'ExampleCapacityDatabase') IS NOT NULL
    BEGIN
        ALTER DATABASE [ExampleCapacityDatabase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleCapacityDatabase];
    END;
    THROW;
END CATCH;
IF DB_ID(N'ExampleCapacityDatabase') IS NOT NULL
    THROW 55879,N'Die eigene Kapazitätsfixture wurde nicht entfernt.',1;
DROP TABLE [#ExampleCapacityContext];
GO

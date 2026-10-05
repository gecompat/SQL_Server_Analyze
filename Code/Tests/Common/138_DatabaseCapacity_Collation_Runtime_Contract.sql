USE [DeineDatenbank];
GO
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
        IF EXISTS(SELECT 1 FROM [#ExampleCapacity] AS [e]
                  WHERE NOT EXISTS(SELECT 1 FROM [sys].[database_files] AS [f]
                                   WHERE [f].[file_id]=[e].[FileId]
                                     AND NOT EXISTS(SELECT [e].[DatabaseId],[e].[DatabaseName],[e].[LogicalFileName],[e].[FileTypeDesc],
                                                           [e].[PhysicalName],[e].[FileSizeMb],[e].[UsedInFileMb],[e].[FreeInFileMb],[e].[FreeInFilePercent],[e].[MaxSizeMb],
                                                           [e].[GrowthDescription],[e].[NextGrowthMb],[e].[FindingCode]
                                                    EXCEPT SELECT DB_ID(),DB_NAME() COLLATE SQL_Latin1_General_CP1_CS_AS,
                                                           [f].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[f].[type_desc] COLLATE SQL_Latin1_General_CP1_CS_AS,
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
                                                                     (SELECT [available_bytes] FROM [sys].[dm_os_volume_stats](DB_ID(),[f].[file_id]))
                                                                     THEN 'NEXT_GROWTH_EXCEEDS_VOLUME_FREE'
                                                                WHEN [f].[is_percent_growth]=1 THEN 'PERCENT_GROWTH_REVIEW'
                                                                ELSE 'NO_CAPACITY_INDICATOR' END COLLATE SQL_Latin1_General_CP1_CS_AS))
                    OR COALESCE([e].[VolumeTotalMb],0)<=0 OR COALESCE([e].[VolumeAvailableMb],-1)<0
                    OR [e].[VolumeFreePercent] IS NULL OR [e].[VolumeFreePercent]<0 OR [e].[VolumeFreePercent]>100)
            THROW 55872,N'Die DatabaseCapacity-Dateiwerte weichen von nativen Metadaten ab.',1;
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

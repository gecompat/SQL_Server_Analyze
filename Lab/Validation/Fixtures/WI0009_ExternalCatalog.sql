/*
Zweck: Vergleicht die Analyze-Ausgabe mit der nativen External-Data-Katalog-Fixture.
Voraussetzung: Die isolierte SQL_Server_Lab-Fixture hat die eigene externe Tabelle
angelegt und den S3-Dienst anschließend vom Testnetz getrennt.
Die Prüfung liest ausschließlich Kataloge und die lokalen Analyze-Resultsets.
*/
USE [DeineDatenbank];
GO
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 OR DB_ID(N'ExamplePolyBaseProbe') IS NULL
    THROW 56990,N'WI-0009 catalog fixture binding failed',1;

DECLARE @FixtureDatabase sysname=N'ExamplePolyBaseProbe';
DECLARE @FixtureObjectId int=OBJECT_ID(N'ExamplePolyBaseProbe.dbo.ExampleExternal');
DECLARE @DataSourceId int,@FileFormatId int,@VisibleColumnCount bigint;
DECLARE @DataSourceType tinyint,@DataSourceTypeDescription nvarchar(255),@FileFormatType tinyint;
SELECT @DataSourceId=s.data_source_id,@DataSourceType=s.[type],@DataSourceTypeDescription=s.type_desc,
    @FileFormatId=f.file_format_id,@FileFormatType=f.format_type
FROM [ExamplePolyBaseProbe].sys.external_tables AS t
INNER JOIN [ExamplePolyBaseProbe].sys.external_data_sources AS s
    ON s.data_source_id=t.data_source_id AND s.name=N'ExampleStore'
INNER JOIN [ExamplePolyBaseProbe].sys.external_file_formats AS f
    ON f.file_format_id=t.file_format_id AND f.name=N'ExampleCsv'
WHERE t.object_id=@FixtureObjectId;
SELECT @VisibleColumnCount=COUNT_BIG(*)
FROM [ExamplePolyBaseProbe].sys.columns WHERE object_id=@FixtureObjectId;
IF @FixtureObjectId IS NULL OR @DataSourceId IS NULL OR @FileFormatId IS NULL OR @VisibleColumnCount<>2
    THROW 56991,N'WI-0009 native catalog oracle failed',1;

CREATE TABLE [#WI0009_CatalogSources]([Seed] int NULL);
CREATE TABLE [#WI0009_CatalogFormats]([Seed] int NULL);
CREATE TABLE [#WI0009_CatalogTables]([Seed] int NULL);
DECLARE @Mapping nvarchar(max)=N'{"dataSources":"#WI0009_CatalogSources","fileFormats":"#WI0009_CatalogFormats","externalTables":"#WI0009_CatalogTables"}';
DECLARE @CallerDatabaseId int=DB_ID(),@CallerLockTimeout int=@@LOCK_TIMEOUT,@CallerOptions int=@@OPTIONS;
DECLARE @Json nvarchar(max),@Status varchar(40),@Partial bit;
EXEC [monitor].[USP_ExternalDataAnalysis]
    @DatabaseNames=N'[ExamplePolyBaseProbe]',@ResultSetArt='TABLE',@ResultTablesJson=@Mapping,
    @MaxZeilen=0,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
    @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;

IF @@TRANCOUNT<>0 OR DB_ID()<>@CallerDatabaseId OR @@LOCK_TIMEOUT<>@CallerLockTimeout OR @@OPTIONS<>@CallerOptions
    THROW 56992,N'WI-0009 caller state changed',1;
IF COALESCE(@Status,'')<>'AVAILABLE' OR COALESCE(CONVERT(int,@Partial),-1)<>0 OR COALESCE(ISJSON(@Json),0)<>1
    THROW 56993,N'WI-0009 module status mismatch',1;
IF ISNULL(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'AVAILABLE'
   OR ISNULL(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
   OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseStatus'))<>1
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH
      ([DatabaseName] sysname,[StatusCode] varchar(40),[DataSourceCount] bigint,[FileFormatCount] bigint,[ExternalTableCount] bigint)
      WHERE [DatabaseName]=@FixtureDatabase AND [StatusCode]='AVAILABLE'
          AND [DataSourceCount]=1 AND [FileFormatCount]=1 AND [ExternalTableCount]=1)
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>6
   OR EXISTS (SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH
      ([DatabaseName] sysname,[SourceStatus] varchar(40),[ErrorNumber] int)
      WHERE [DatabaseName] IS NULL OR [DatabaseName]<>@FixtureDatabase
          OR [SourceStatus] IS NULL OR [SourceStatus]<>'AVAILABLE' OR [ErrorNumber] IS NOT NULL)
   OR ISNULL(JSON_QUERY(@Json,N'$.warnings'),N'')<>N'[]'
    THROW 56994,N'WI-0009 native catalog status mismatch',1;

EXEC sys.sp_executesql N'
IF (SELECT COUNT_BIG(*) FROM [#WI0009_CatalogSources])<>1
   OR (SELECT COUNT_BIG(*) FROM [#WI0009_CatalogFormats])<>1
   OR (SELECT COUNT_BIG(*) FROM [#WI0009_CatalogTables])<>1
   OR NOT EXISTS (SELECT 1 FROM [#WI0009_CatalogSources] WHERE [DatabaseName]=@FixtureDatabase
      AND [DataSourceId]=@DataSourceId AND [DataSourceName]=N''ExampleStore''
      AND EXISTS (SELECT [TypeCode],[TypeDescription] COLLATE Latin1_General_100_BIN2
          INTERSECT SELECT @DataSourceType,@DataSourceTypeDescription COLLATE Latin1_General_100_BIN2))
   OR NOT EXISTS (SELECT 1 FROM [#WI0009_CatalogFormats] WHERE [DatabaseName]=@FixtureDatabase
      AND [FileFormatId]=@FileFormatId AND [FileFormatName]=N''ExampleCsv''
      AND EXISTS (SELECT [FormatTypeCode] INTERSECT SELECT @FileFormatType))
   OR NOT EXISTS (SELECT 1 FROM [#WI0009_CatalogTables] WHERE [DatabaseName]=@FixtureDatabase
      AND [ObjectId]=@FixtureObjectId AND [SchemaName]=N''dbo'' AND [TableName]=N''ExampleExternal''
      AND [DataSourceId]=@DataSourceId AND [FileFormatId]=@FileFormatId AND [VisibleColumnCount]=@VisibleColumnCount
      AND [DataSourceReferenceStatus]=''VISIBLE'' AND [FileFormatReferenceStatus]=''VISIBLE'')
    THROW 56995,N''WI-0009 Analyze TABLE catalog rows mismatch'',1;

DECLARE @Sources nvarchar(max)=(SELECT * FROM [#WI0009_CatalogSources] FOR JSON PATH,INCLUDE_NULL_VALUES);
DECLARE @Formats nvarchar(max)=(SELECT * FROM [#WI0009_CatalogFormats] FOR JSON PATH,INCLUDE_NULL_VALUES);
DECLARE @Tables nvarchar(max)=(SELECT * FROM [#WI0009_CatalogTables] FOR JSON PATH,INCLUDE_NULL_VALUES);
IF ISNULL(JSON_QUERY(@Json,N''$.dataSources''),N'''') COLLATE Latin1_General_100_BIN2<>@Sources COLLATE Latin1_General_100_BIN2
   OR ISNULL(JSON_QUERY(@Json,N''$.fileFormats''),N'''') COLLATE Latin1_General_100_BIN2<>@Formats COLLATE Latin1_General_100_BIN2
   OR ISNULL(JSON_QUERY(@Json,N''$.externalTables''),N'''') COLLATE Latin1_General_100_BIN2<>@Tables COLLATE Latin1_General_100_BIN2
    THROW 56996,N''WI-0009 TABLE and JSON catalog rows diverge'',1;',
    N'@FixtureDatabase sysname,@FixtureObjectId int,@DataSourceId int,@FileFormatId int,@VisibleColumnCount bigint,@DataSourceType tinyint,@DataSourceTypeDescription nvarchar(255),@FileFormatType tinyint,@Json nvarchar(max)',
    @FixtureDatabase=@FixtureDatabase,@FixtureObjectId=@FixtureObjectId,@DataSourceId=@DataSourceId,
    @FileFormatId=@FileFormatId,@VisibleColumnCount=@VisibleColumnCount,
    @DataSourceType=@DataSourceType,@DataSourceTypeDescription=@DataSourceTypeDescription,
    @FileFormatType=@FileFormatType,@Json=@Json;
IF CHARINDEX(N'ExampleSeven',@Json)>0 OR CHARINDEX(N'ExampleEleven',@Json)>0
   OR CHARINDEX(N'fixture.csv',@Json)>0 OR CHARINDEX(N's3://',@Json)>0 OR CHARINDEX(N'ExampleReader',@Json)>0
    THROW 56997,N'WI-0009 exposed a fixture payload or remote binding',1;

DROP TABLE [#WI0009_CatalogTables];
DROP TABLE [#WI0009_CatalogFormats];
DROP TABLE [#WI0009_CatalogSources];
SELECT 'POLYBASE_S3_CONSUMER=PASS';
GO

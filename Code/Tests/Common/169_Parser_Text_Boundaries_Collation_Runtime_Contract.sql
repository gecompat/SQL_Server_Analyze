USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 169_Parser_Text_Boundaries_Collation_Runtime_Contract.sql
Zweck        : Prüft die drei bestehenden Parser mit unabhängig festgelegten
               vollständigen Zeilen und Rückgabemetadaten.
Datenschutz  : Ausschließlich synthetische Eingabetexte; keine persistente
               Fixture, Kataloganreicherung oder Workloadausführung.
Grenzen      : Kein Nachweis echter Blockingressourcen oder nativ erfasster
               STATISTICS-Meldungen. Sprachargumente erzwingen im bestehenden
               Parservertrag keine Sprache; erkannte Texte bestimmen sie.
===============================================================================
*/
SET NOCOUNT ON;

DECLARE @FrameworkLevel int = (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN (150,160,170)
    THROW 57100,N'Parser framework compatibility level is outside the portable contract.',1;
IF CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation'))<>N'SQL_Latin1_General_CP1_CS_AS'
    THROW 57101,N'Parser framework collation is not the guaranteed contract.',1;

CREATE TABLE [#169_ExpectedMetadata]
(
      [FunctionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [ColumnOrdinal] int NOT NULL
    , [ColumnName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [SystemTypeId] int NOT NULL
    , [MaxLength] int NOT NULL
    , [PrecisionValue] int NOT NULL
    , [ScaleValue] int NOT NULL
    , [IsNullable] bit NOT NULL
    , [CollationName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [IsIdentity] bit NOT NULL
);
INSERT [#169_ExpectedMetadata] VALUES
    (N'TVF_ParseBlockingResource',1,N'RawResource',231,6144,0,0,1,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseBlockingResource',2,N'ResourceType',231,120,0,0,1,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseBlockingResource',3,N'FormatCode',167,40,0,0,0,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseBlockingResource',4,N'DatabaseId',56,4,10,0,1,NULL,0),
    (N'TVF_ParseBlockingResource',5,N'EntityId',127,8,19,0,1,NULL,0),
    (N'TVF_ParseBlockingResource',6,N'SubEntityId',127,8,19,0,1,NULL,0),
    (N'TVF_ParseBlockingResource',7,N'FileId',56,4,10,0,1,NULL,0),
    (N'TVF_ParseBlockingResource',8,N'PageId',127,8,19,0,1,NULL,0),
    (N'TVF_ParseBlockingResource',9,N'RowId',56,4,10,0,1,NULL,0),
    (N'TVF_ParseBlockingResource',10,N'MetadataSubtype',231,120,0,0,1,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseBlockingResource',11,N'ResourceQualifier',231,1024,0,0,1,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseBlockingResource',12,N'ParseStatus',167,40,0,0,0,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseStatisticsIoText',1,N'StatementOrdinal',56,4,10,0,1,NULL,0),
    (N'TVF_ParseStatisticsIoText',2,N'MessageOrdinal',56,4,10,0,0,NULL,0),
    (N'TVF_ParseStatisticsIoText',3,N'ObjectOrdinal',56,4,10,0,0,NULL,0),
    (N'TVF_ParseStatisticsIoText',4,N'ObjectDisplayName',231,1024,0,0,1,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseStatisticsIoText',5,N'ScanCount',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsIoText',6,N'LogicalReads',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsIoText',7,N'PhysicalReads',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsIoText',8,N'PageServerReads',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsIoText',9,N'ReadAheadReads',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsIoText',10,N'PageServerReadAheadReads',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsIoText',11,N'LobLogicalReads',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsIoText',12,N'LobPhysicalReads',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsIoText',13,N'LobPageServerReads',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsIoText',14,N'LobReadAheadReads',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsIoText',15,N'LobPageServerReadAheadReads',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsIoText',16,N'LanguageDetected',167,16,0,0,0,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseStatisticsIoText',17,N'ParseStatus',167,40,0,0,0,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseStatisticsIoText',18,N'RawLine',231,8000,0,0,1,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseStatisticsTimeText',1,N'StatementOrdinal',56,4,10,0,1,NULL,0),
    (N'TVF_ParseStatisticsTimeText',2,N'MessageOrdinal',56,4,10,0,0,NULL,0),
    (N'TVF_ParseStatisticsTimeText',3,N'TimeCategory',167,24,0,0,0,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseStatisticsTimeText',4,N'CpuMs',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsTimeText',5,N'ElapsedMs',127,8,19,0,1,NULL,0),
    (N'TVF_ParseStatisticsTimeText',6,N'LanguageDetected',167,16,0,0,0,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseStatisticsTimeText',7,N'ParseStatus',167,40,0,0,0,N'SQL_Latin1_General_CP1_CS_AS',0),
    (N'TVF_ParseStatisticsTimeText',8,N'RawLine',231,8000,0,0,1,N'SQL_Latin1_General_CP1_CS_AS',0);

IF (SELECT COUNT(*) FROM [sys].[objects] AS [o] JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[o].[schema_id]
    WHERE [s].[name]=N'monitor' AND [o].[type]='TF' AND [o].[name] IN (N'TVF_ParseBlockingResource',N'TVF_ParseStatisticsIoText',N'TVF_ParseStatisticsTimeText'))<>3
    THROW 57102,N'Three canonical multi-statement parser functions are required.',1;
SELECT [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [FunctionName],
       [c].[column_id] AS [ColumnOrdinal],[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ColumnName],
       CONVERT(int,[c].[system_type_id]) AS [SystemTypeId],CONVERT(int,[c].[max_length]) AS [MaxLength],
       CONVERT(int,[c].[precision]) AS [PrecisionValue],CONVERT(int,[c].[scale]) AS [ScaleValue],
       [c].[is_nullable] AS [IsNullable],[c].[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [CollationName],
       [c].[is_identity] AS [IsIdentity]
INTO [#169_ActualMetadata]
FROM [sys].[columns] AS [c]
JOIN [sys].[objects] AS [o] ON [o].[object_id]=[c].[object_id]
JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[o].[schema_id]
WHERE [s].[name]=N'monitor' AND [o].[name] IN (N'TVF_ParseBlockingResource',N'TVF_ParseStatisticsIoText',N'TVF_ParseStatisticsTimeText');
IF EXISTS(SELECT * FROM [#169_ExpectedMetadata] EXCEPT SELECT * FROM [#169_ActualMetadata])
 OR EXISTS(SELECT * FROM [#169_ActualMetadata] EXCEPT SELECT * FROM [#169_ExpectedMetadata])
 OR (SELECT COUNT(*) FROM [#169_ActualMetadata])<>38
 OR (SELECT COUNT(*) FROM [#169_ActualMetadata] WHERE [CollationName]=N'SQL_Latin1_General_CP1_CS_AS')<>14
    THROW 57103,N'Parser return names ordinals types sizes nullability identity or collations disagree.',1;

CREATE TABLE [#169_BlockingExpected]
(
    [CaseNumber] int NOT NULL
  , [RawResource] nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [ResourceType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [FormatCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [DatabaseId] int NULL
  , [EntityId] bigint NULL
  , [SubEntityId] bigint NULL
  , [FileId] int NULL
  , [PageId] bigint NULL
  , [RowId] int NULL
  , [MetadataSubtype] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [ResourceQualifier] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
CREATE TABLE [#169_BlockingInputs]
(
    [CaseNumber] int NOT NULL
  , [InputText] nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
INSERT [#169_BlockingInputs] VALUES
    (0,NULL),
    (1,N''),
    (2,N'   '),
    (3,N' OBJECT: 5:42:2 '),
    (4,N'KEY: 5:72057594000000001 (ExampleHash)'),
    (5,N'HOBT: 5:72057594000000002'),
    (6,N'OIB: 5:72057594000000003'),
    (7,N'ALLOCATION_UNIT: 5:72057594000000004'),
    (8,N'DATABASE: 5'),
    (9,N'FILE: 5:2'),
    (10,N'FILE: 5'),
    (11,N'PAGE: 5:2:104'),
    (12,N'5:2:105'),
    (13,N'RID: 5:2:106:3'),
    (14,N'EXTENT: 5:2:112'),
    (15,N'APPLICATION: 5:0:ExampleLockÄ:(ExampleHash)'),
    (16,N'XACT: 5:123:456'),
    (17,N'METADATA: database_id = 5 STATS(object_id = 42, stats_id = 2)'),
    (18,N'METADATA: database_id = 5 SCHEMA(schema_id = 3)'),
    (19,N'METADATA: database_id = 5 AUDIT(audit_id = 4)'),
    (20,N'METADATA: database_id = 5 SECURITY_CACHE(ExampleValue)'),
    (21,N'METADATA: database_id = 5 METADATA_CACHE(ExampleValue)'),
    (22,N'METADATA: database_id = 5 QDS_STATEMENT_STABILITY(ExampleValue)'),
    (23,N'METADATA: database_id = 5 ExampleUnknown(ExampleValue)'),
    (24,N'METADATA: STATS(object_id = 42, stats_id = 2)'),
    (25,N'ROW_GROUP resource_description=ExampleOpaqueÄ'),
    (26,N'ACCESS_METHODS_HOBT (ExampleAddress)'),
    (27,N'ExampleType: ExampleÄ'),
    (28,N'PAGE: 5:bad:104'),
    (29,N'OBJECT: 2147483648:42:2'),
    (30,N'page: 5:2:107 [ExampleCaseÄ]');
INSERT [#169_BlockingExpected] VALUES
    (0,NULL,NULL,N'EMPTY',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'EMPTY'),
    (1,N'',NULL,N'EMPTY',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'EMPTY'),
    (2,N'   ',NULL,N'EMPTY',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'EMPTY'),
    (3,N'OBJECT: 5:42:2',N'OBJECT',N'PREFIXED',5,42,2,NULL,NULL,NULL,NULL,NULL,N'PARSED'),
    (4,N'KEY: 5:72057594000000001 (ExampleHash)',N'KEY',N'PREFIXED',5,72057594000000001,NULL,NULL,NULL,NULL,NULL,N'(ExampleHash)',N'PARSED'),
    (5,N'HOBT: 5:72057594000000002',N'HOBT',N'PREFIXED',5,72057594000000002,NULL,NULL,NULL,NULL,NULL,NULL,N'PARSED'),
    (6,N'OIB: 5:72057594000000003',N'OIB',N'PREFIXED',5,72057594000000003,NULL,NULL,NULL,NULL,NULL,NULL,N'PARSED'),
    (7,N'ALLOCATION_UNIT: 5:72057594000000004',N'ALLOCATION_UNIT',N'PREFIXED',5,72057594000000004,NULL,NULL,NULL,NULL,NULL,NULL,N'PARSED'),
    (8,N'DATABASE: 5',N'DATABASE',N'PREFIXED',5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'PARSED'),
    (9,N'FILE: 5:2',N'FILE',N'PREFIXED',5,NULL,NULL,2,NULL,NULL,NULL,NULL,N'PARSED'),
    (10,N'FILE: 5',N'FILE',N'PREFIXED',5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'PARTIAL'),
    (11,N'PAGE: 5:2:104',N'PAGE',N'PREFIXED',5,NULL,NULL,2,104,NULL,NULL,NULL,N'PARSED'),
    (12,N'5:2:105',N'PAGE',N'NUMERIC_PAGE',5,NULL,NULL,2,105,NULL,NULL,NULL,N'PARSED'),
    (13,N'RID: 5:2:106:3',N'RID',N'PREFIXED',5,NULL,NULL,2,106,3,NULL,NULL,N'PARSED'),
    (14,N'EXTENT: 5:2:112',N'EXTENT',N'PREFIXED',5,NULL,NULL,2,112,NULL,NULL,NULL,N'PARSED'),
    (15,N'APPLICATION: 5:0:ExampleLockÄ:(ExampleHash)',N'APPLICATION',N'PREFIXED',5,NULL,NULL,NULL,NULL,NULL,NULL,N'5:0:ExampleLockÄ:(ExampleHash)',N'PARTIAL'),
    (16,N'XACT: 5:123:456',N'XACT',N'PREFIXED',5,NULL,NULL,NULL,NULL,NULL,NULL,N'5:123:456',N'PARTIAL'),
    (17,N'METADATA: database_id = 5 STATS(object_id = 42, stats_id = 2)',N'METADATA',N'METADATA',5,42,2,NULL,NULL,NULL,N'STATS',N'METADATA: database_id = 5 STATS(object_id = 42, stats_id = 2)',N'PARSED'),
    (18,N'METADATA: database_id = 5 SCHEMA(schema_id = 3)',N'METADATA',N'METADATA',5,3,NULL,NULL,NULL,NULL,N'SCHEMA',N'METADATA: database_id = 5 SCHEMA(schema_id = 3)',N'PARSED'),
    (19,N'METADATA: database_id = 5 AUDIT(audit_id = 4)',N'METADATA',N'METADATA',5,4,NULL,NULL,NULL,NULL,N'AUDIT',N'METADATA: database_id = 5 AUDIT(audit_id = 4)',N'PARSED'),
    (20,N'METADATA: database_id = 5 SECURITY_CACHE(ExampleValue)',N'METADATA',N'METADATA',5,NULL,NULL,NULL,NULL,NULL,N'SECURITY_CACHE',N'METADATA: database_id = 5 SECURITY_CACHE(ExampleValue)',N'PARSED'),
    (21,N'METADATA: database_id = 5 METADATA_CACHE(ExampleValue)',N'METADATA',N'METADATA',5,NULL,NULL,NULL,NULL,NULL,N'METADATA_CACHE',N'METADATA: database_id = 5 METADATA_CACHE(ExampleValue)',N'PARSED'),
    (22,N'METADATA: database_id = 5 QDS_STATEMENT_STABILITY(ExampleValue)',N'METADATA',N'METADATA',5,NULL,NULL,NULL,NULL,NULL,N'QDS_STATEMENT_STABILITY',N'METADATA: database_id = 5 QDS_STATEMENT_STABILITY(ExampleValue)',N'PARSED'),
    (23,N'METADATA: database_id = 5 ExampleUnknown(ExampleValue)',N'METADATA',N'METADATA',5,NULL,NULL,NULL,NULL,NULL,N'OTHER',N'METADATA: database_id = 5 ExampleUnknown(ExampleValue)',N'PARSED'),
    (24,N'METADATA: STATS(object_id = 42, stats_id = 2)',N'METADATA',N'METADATA',NULL,42,2,NULL,NULL,NULL,N'STATS',N'METADATA: STATS(object_id = 42, stats_id = 2)',N'PARTIAL'),
    (25,N'ROW_GROUP resource_description=ExampleOpaqueÄ',N'ROW_GROUP',N'NAMED_RESOURCE',NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'ROW_GROUP resource_description=ExampleOpaqueÄ',N'RAW_ONLY'),
    (26,N'ACCESS_METHODS_HOBT (ExampleAddress)',N'ACCESS_METHODS_HOBT',N'NAMED_RESOURCE',NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'ACCESS_METHODS_HOBT (ExampleAddress)',N'RAW_ONLY'),
    (27,N'ExampleType: ExampleÄ',N'EXAMPLETYPE',N'PREFIXED',NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'ExampleType: ExampleÄ',N'RAW_ONLY'),
    (28,N'PAGE: 5:bad:104',N'PAGE',N'PREFIXED',5,NULL,NULL,NULL,104,NULL,NULL,NULL,N'INVALID_FORMAT'),
    (29,N'OBJECT: 2147483648:42:2',N'OBJECT',N'PREFIXED',NULL,42,2,NULL,NULL,NULL,NULL,NULL,N'INVALID_FORMAT'),
    (30,N'page: 5:2:107 [ExampleCaseÄ]',N'PAGE',N'PREFIXED',5,NULL,NULL,2,107,NULL,NULL,N'[ExampleCaseÄ]',N'PARSED');
SELECT [c].[CaseNumber],[p].*
INTO [#169_BlockingActual]
FROM [#169_BlockingInputs] AS [c]
CROSS APPLY [monitor].[TVF_ParseBlockingResource]([c].[InputText]) AS [p];
IF EXISTS(SELECT [CaseNumber],CONVERT(varbinary(max),[RawResource]),CONVERT(varbinary(max),[ResourceType]),CONVERT(varbinary(max),[FormatCode]),[DatabaseId],[EntityId],[SubEntityId],[FileId],[PageId],[RowId],CONVERT(varbinary(max),[MetadataSubtype]),CONVERT(varbinary(max),[ResourceQualifier]),CONVERT(varbinary(max),[ParseStatus]) FROM [#169_BlockingExpected] EXCEPT SELECT [CaseNumber],CONVERT(varbinary(max),[RawResource]),CONVERT(varbinary(max),[ResourceType]),CONVERT(varbinary(max),[FormatCode]),[DatabaseId],[EntityId],[SubEntityId],[FileId],[PageId],[RowId],CONVERT(varbinary(max),[MetadataSubtype]),CONVERT(varbinary(max),[ResourceQualifier]),CONVERT(varbinary(max),[ParseStatus]) FROM [#169_BlockingActual])
 OR EXISTS(SELECT [CaseNumber],CONVERT(varbinary(max),[RawResource]),CONVERT(varbinary(max),[ResourceType]),CONVERT(varbinary(max),[FormatCode]),[DatabaseId],[EntityId],[SubEntityId],[FileId],[PageId],[RowId],CONVERT(varbinary(max),[MetadataSubtype]),CONVERT(varbinary(max),[ResourceQualifier]),CONVERT(varbinary(max),[ParseStatus]) FROM [#169_BlockingActual] EXCEPT SELECT [CaseNumber],CONVERT(varbinary(max),[RawResource]),CONVERT(varbinary(max),[ResourceType]),CONVERT(varbinary(max),[FormatCode]),[DatabaseId],[EntityId],[SubEntityId],[FileId],[PageId],[RowId],CONVERT(varbinary(max),[MetadataSubtype]),CONVERT(varbinary(max),[ResourceQualifier]),CONVERT(varbinary(max),[ParseStatus]) FROM [#169_BlockingExpected])
 OR EXISTS(SELECT [CaseNumber],COUNT_BIG(*) FROM [#169_BlockingExpected] GROUP BY [CaseNumber] EXCEPT SELECT [CaseNumber],COUNT_BIG(*) FROM [#169_BlockingActual] GROUP BY [CaseNumber])
 OR EXISTS(SELECT [CaseNumber],COUNT_BIG(*) FROM [#169_BlockingActual] GROUP BY [CaseNumber] EXCEPT SELECT [CaseNumber],COUNT_BIG(*) FROM [#169_BlockingExpected] GROUP BY [CaseNumber])
    THROW 57104,N'Blocking parser complete literal rows exact text bytes or row multiplicities disagree.',1;

CREATE TABLE [#169_IoExpected]
(
    [CaseNumber] int NOT NULL
  , [StatementOrdinal] int NULL
  , [MessageOrdinal] int NOT NULL
  , [ObjectOrdinal] int NOT NULL
  , [ObjectDisplayName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [ScanCount] bigint NULL
  , [LogicalReads] bigint NULL
  , [PhysicalReads] bigint NULL
  , [PageServerReads] bigint NULL
  , [ReadAheadReads] bigint NULL
  , [PageServerReadAheadReads] bigint NULL
  , [LobLogicalReads] bigint NULL
  , [LobPhysicalReads] bigint NULL
  , [LobPageServerReads] bigint NULL
  , [LobReadAheadReads] bigint NULL
  , [LobPageServerReadAheadReads] bigint NULL
  , [LanguageDetected] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [RawLine] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE [#169_IoInputs]
(
    [CaseNumber] int NOT NULL
  , [InputText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [LanguageArgument] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
INSERT [#169_IoInputs] VALUES
    (0,NULL,N'AUTO'),
    (1,N'',N'AUTO'),
    (2,N'Example ignored message',N'AUTO'),
    (3,N'Table ''ExampleObjectÄ''. Scan count 1, logical reads 2, physical reads 3, page server reads 4, read-ahead reads 5, page server read-ahead reads 6, lob logical reads 7, lob physical reads 8, lob page server reads 9, lob read-ahead reads 10, lob page server read-ahead reads 11.',N'AUTO'),
    (4,N'Tabelle ''exampleObjectÄ''. Scananzahl 1, logische Lesevorgänge 2, physische Lesevorgänge 3, Seitenserver-Lesevorgänge 4, vorausgelesene Seiten 5, Seitenserver-vorauslesevorgänge 6, logische LOB-Lesevorgänge 7, physische LOB-Lesevorgänge 8, LOB-Seitenserver-Lesevorgänge 9, LOB-vorauslesevorgänge 10, LOB-Seitenserver-vorauslesevorgänge 11.',N'AUTO'),
    (5,N'Table ''ExampleObjectÄ''. Scan count 1, logical reads 2, physical reads 3, page server reads 4, read-ahead reads 5, page server read-ahead reads 6, lob logical reads 7, lob physical reads 8, lob page server reads 9, lob read-ahead reads 10, lob page server read-ahead reads 11.'+NCHAR(13)+N''+NCHAR(10)+N'Tabelle ''exampleObjectÄ''. Scananzahl 1, logische Lesevorgänge 2, physische Lesevorgänge 3, Seitenserver-Lesevorgänge 4, vorausgelesene Seiten 5, Seitenserver-vorauslesevorgänge 6, logische LOB-Lesevorgänge 7, physische LOB-Lesevorgänge 8, LOB-Seitenserver-Lesevorgänge 9, LOB-vorauslesevorgänge 10, LOB-Seitenserver-vorauslesevorgänge 11.',N'EN'),
    (6,N'Scan count 1, logical reads 2.',N'AUTO'),
    (7,N'Table ''ExamplePartial''. Scan count nope, logical reads 2.',N'AUTO'),
    (8,N'Table ''ExampleObjectÄ''. Scan count 1, logical reads 2, physical reads 3, page server reads 4, read-ahead reads 5, page server read-ahead reads 6, lob logical reads 7, lob physical reads 8, lob page server reads 9, lob read-ahead reads 10, lob page server read-ahead reads 11.',N'UNKNOWN'),
    (9,N'Tabelle ''exampleObjectÄ''. Scananzahl 1, logische Lesevorgänge 2, physische Lesevorgänge 3, Seitenserver-Lesevorgänge 4, vorausgelesene Seiten 5, Seitenserver-vorauslesevorgänge 6, logische LOB-Lesevorgänge 7, physische LOB-Lesevorgänge 8, LOB-Seitenserver-Lesevorgänge 9, LOB-vorauslesevorgänge 10, LOB-Seitenserver-vorauslesevorgänge 11.',NULL),
    (10,N'  Table ''ExampleShort''. Scan count 0, logical reads 0.  '+NCHAR(13)+N'Example ignored'+NCHAR(10)+N'Table ''ExampleShort''. Scan count 0, logical reads 0.'+NCHAR(13)+N''+NCHAR(10)+N'Table ''ExampleShort''. Scan count 0, logical reads 0.',N'DE');
INSERT [#169_IoExpected] VALUES
    (3,NULL,1,1,N'ExampleObjectÄ',1,2,3,4,5,6,7,8,9,10,11,N'EN',N'PARSED',N'Table ''ExampleObjectÄ''. Scan count 1, logical reads 2, physical reads 3, page server reads 4, read-ahead reads 5, page server read-ahead reads 6, lob logical reads 7, lob physical reads 8, lob page server reads 9, lob read-ahead reads 10, lob page server read-ahead reads 11.'),
    (4,NULL,1,1,N'exampleObjectÄ',1,2,3,4,5,6,7,8,9,10,11,N'DE',N'PARSED',N'Tabelle ''exampleObjectÄ''. Scananzahl 1, logische Lesevorgänge 2, physische Lesevorgänge 3, Seitenserver-Lesevorgänge 4, vorausgelesene Seiten 5, Seitenserver-vorauslesevorgänge 6, logische LOB-Lesevorgänge 7, physische LOB-Lesevorgänge 8, LOB-Seitenserver-Lesevorgänge 9, LOB-vorauslesevorgänge 10, LOB-Seitenserver-vorauslesevorgänge 11.'),
    (5,NULL,1,1,N'ExampleObjectÄ',1,2,3,4,5,6,7,8,9,10,11,N'EN',N'PARSED',N'Table ''ExampleObjectÄ''. Scan count 1, logical reads 2, physical reads 3, page server reads 4, read-ahead reads 5, page server read-ahead reads 6, lob logical reads 7, lob physical reads 8, lob page server reads 9, lob read-ahead reads 10, lob page server read-ahead reads 11.'),
    (5,NULL,2,2,N'exampleObjectÄ',1,2,3,4,5,6,7,8,9,10,11,N'DE',N'PARSED',N'Tabelle ''exampleObjectÄ''. Scananzahl 1, logische Lesevorgänge 2, physische Lesevorgänge 3, Seitenserver-Lesevorgänge 4, vorausgelesene Seiten 5, Seitenserver-vorauslesevorgänge 6, logische LOB-Lesevorgänge 7, physische LOB-Lesevorgänge 8, LOB-Seitenserver-Lesevorgänge 9, LOB-vorauslesevorgänge 10, LOB-Seitenserver-vorauslesevorgänge 11.'),
    (6,NULL,1,1,NULL,1,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'EN',N'PARSED_PARTIAL',N'Scan count 1, logical reads 2.'),
    (7,NULL,1,1,N'ExamplePartial',NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'EN',N'PARSED_PARTIAL',N'Table ''ExamplePartial''. Scan count nope, logical reads 2.'),
    (8,NULL,1,1,N'ExampleObjectÄ',1,2,3,4,5,6,7,8,9,10,11,N'EN',N'PARSED',N'Table ''ExampleObjectÄ''. Scan count 1, logical reads 2, physical reads 3, page server reads 4, read-ahead reads 5, page server read-ahead reads 6, lob logical reads 7, lob physical reads 8, lob page server reads 9, lob read-ahead reads 10, lob page server read-ahead reads 11.'),
    (9,NULL,1,1,N'exampleObjectÄ',1,2,3,4,5,6,7,8,9,10,11,N'DE',N'PARSED',N'Tabelle ''exampleObjectÄ''. Scananzahl 1, logische Lesevorgänge 2, physische Lesevorgänge 3, Seitenserver-Lesevorgänge 4, vorausgelesene Seiten 5, Seitenserver-vorauslesevorgänge 6, logische LOB-Lesevorgänge 7, physische LOB-Lesevorgänge 8, LOB-Seitenserver-Lesevorgänge 9, LOB-vorauslesevorgänge 10, LOB-Seitenserver-vorauslesevorgänge 11.'),
    (10,NULL,1,1,N'ExampleShort',0,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'EN',N'PARSED',N'Table ''ExampleShort''. Scan count 0, logical reads 0.'),
    (10,NULL,2,2,N'ExampleShort',0,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'EN',N'PARSED',N'Table ''ExampleShort''. Scan count 0, logical reads 0.'),
    (10,NULL,3,3,N'ExampleShort',0,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,N'EN',N'PARSED',N'Table ''ExampleShort''. Scan count 0, logical reads 0.');
SELECT [c].[CaseNumber],[p].*
INTO [#169_IoActual]
FROM [#169_IoInputs] AS [c]
CROSS APPLY [monitor].[TVF_ParseStatisticsIoText]([c].[InputText],[c].[LanguageArgument]) AS [p];
IF EXISTS(SELECT [CaseNumber],[StatementOrdinal],[MessageOrdinal],[ObjectOrdinal],CONVERT(varbinary(max),[ObjectDisplayName]),[ScanCount],[LogicalReads],[PhysicalReads],[PageServerReads],[ReadAheadReads],[PageServerReadAheadReads],[LobLogicalReads],[LobPhysicalReads],[LobPageServerReads],[LobReadAheadReads],[LobPageServerReadAheadReads],CONVERT(varbinary(max),[LanguageDetected]),CONVERT(varbinary(max),[ParseStatus]),CONVERT(varbinary(max),[RawLine]) FROM [#169_IoExpected] EXCEPT SELECT [CaseNumber],[StatementOrdinal],[MessageOrdinal],[ObjectOrdinal],CONVERT(varbinary(max),[ObjectDisplayName]),[ScanCount],[LogicalReads],[PhysicalReads],[PageServerReads],[ReadAheadReads],[PageServerReadAheadReads],[LobLogicalReads],[LobPhysicalReads],[LobPageServerReads],[LobReadAheadReads],[LobPageServerReadAheadReads],CONVERT(varbinary(max),[LanguageDetected]),CONVERT(varbinary(max),[ParseStatus]),CONVERT(varbinary(max),[RawLine]) FROM [#169_IoActual])
 OR EXISTS(SELECT [CaseNumber],[StatementOrdinal],[MessageOrdinal],[ObjectOrdinal],CONVERT(varbinary(max),[ObjectDisplayName]),[ScanCount],[LogicalReads],[PhysicalReads],[PageServerReads],[ReadAheadReads],[PageServerReadAheadReads],[LobLogicalReads],[LobPhysicalReads],[LobPageServerReads],[LobReadAheadReads],[LobPageServerReadAheadReads],CONVERT(varbinary(max),[LanguageDetected]),CONVERT(varbinary(max),[ParseStatus]),CONVERT(varbinary(max),[RawLine]) FROM [#169_IoActual] EXCEPT SELECT [CaseNumber],[StatementOrdinal],[MessageOrdinal],[ObjectOrdinal],CONVERT(varbinary(max),[ObjectDisplayName]),[ScanCount],[LogicalReads],[PhysicalReads],[PageServerReads],[ReadAheadReads],[PageServerReadAheadReads],[LobLogicalReads],[LobPhysicalReads],[LobPageServerReads],[LobReadAheadReads],[LobPageServerReadAheadReads],CONVERT(varbinary(max),[LanguageDetected]),CONVERT(varbinary(max),[ParseStatus]),CONVERT(varbinary(max),[RawLine]) FROM [#169_IoExpected])
 OR EXISTS(SELECT [CaseNumber],COUNT_BIG(*) FROM [#169_IoExpected] GROUP BY [CaseNumber] EXCEPT SELECT [CaseNumber],COUNT_BIG(*) FROM [#169_IoActual] GROUP BY [CaseNumber])
 OR EXISTS(SELECT [CaseNumber],COUNT_BIG(*) FROM [#169_IoActual] GROUP BY [CaseNumber] EXCEPT SELECT [CaseNumber],COUNT_BIG(*) FROM [#169_IoExpected] GROUP BY [CaseNumber])
    THROW 57105,N'Io parser complete literal rows exact text bytes or row multiplicities disagree.',1;

CREATE TABLE [#169_TimeExpected]
(
    [CaseNumber] int NOT NULL
  , [StatementOrdinal] int NULL
  , [MessageOrdinal] int NOT NULL
  , [TimeCategory] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [CpuMs] bigint NULL
  , [ElapsedMs] bigint NULL
  , [LanguageDetected] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [RawLine] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE [#169_TimeInputs]
(
    [CaseNumber] int NOT NULL
  , [InputText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [LanguageArgument] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
INSERT [#169_TimeInputs] VALUES
    (0,NULL,N'AUTO'),
    (1,N'',N'AUTO'),
    (2,N'Example ignored message',N'AUTO'),
    (3,N'SQL Server Execution Times: CPU time = 1 ms, elapsed time = 2 ms.',N'AUTO'),
    (4,N'SQL Server-Ausführungszeiten: CPU-Zeit = 3 ms, verstrichene Zeit = 4 ms.',N'EN'),
    (5,N'SQL Server parse and compile time: CPU time = 5 ms, elapsed time = 6 ms.',N'DE'),
    (6,N'SQL Server-Analyse- und Kompilierzeit: CPU-Zeit = 7 ms, verstrichene Zeit = 8 ms.',NULL),
    (7,N'SQL Server parse and compile time:'+NCHAR(13)+N''+NCHAR(10)+N'CPU time = 5 ms, elapsed time = 6 ms.'+NCHAR(13)+N'SQL Server Execution Times:'+NCHAR(10)+N'CPU time = 1 ms, elapsed time = 2 ms.',N'UNKNOWN'),
    (8,N'CPU time = 9 ms, elapsed time = 10 ms.',N'AUTO'),
    (9,N'SQL Server Execution Times: CPU time = nope ms, elapsed time = 2 ms.',N'AUTO'),
    (10,N'SQL Server Execution Times: CPU time = 0 ms.',N'AUTO');
INSERT [#169_TimeExpected] VALUES
    (3,NULL,1,N'EXECUTION',1,2,N'EN',N'PARSED',N'SQL Server Execution Times: CPU time = 1 ms, elapsed time = 2 ms.'),
    (4,NULL,1,N'EXECUTION',3,4,N'DE',N'PARSED',N'SQL Server-Ausführungszeiten: CPU-Zeit = 3 ms, verstrichene Zeit = 4 ms.'),
    (5,NULL,1,N'PARSE_COMPILE',5,6,N'EN',N'PARSED',N'SQL Server parse and compile time: CPU time = 5 ms, elapsed time = 6 ms.'),
    (6,NULL,1,N'PARSE_COMPILE',7,8,N'DE',N'PARSED',N'SQL Server-Analyse- und Kompilierzeit: CPU-Zeit = 7 ms, verstrichene Zeit = 8 ms.'),
    (7,NULL,1,N'PARSE_COMPILE',5,6,N'EN',N'PARSED',N'CPU time = 5 ms, elapsed time = 6 ms.'),
    (7,NULL,2,N'EXECUTION',1,2,N'EN',N'PARSED',N'CPU time = 1 ms, elapsed time = 2 ms.'),
    (8,NULL,1,N'UNKNOWN',9,10,N'EN',N'PARSED_PARTIAL',N'CPU time = 9 ms, elapsed time = 10 ms.'),
    (9,NULL,1,N'EXECUTION',NULL,2,N'EN',N'PARSED_PARTIAL',N'SQL Server Execution Times: CPU time = nope ms, elapsed time = 2 ms.'),
    (10,NULL,1,N'EXECUTION',0,NULL,N'EN',N'PARSED_PARTIAL',N'SQL Server Execution Times: CPU time = 0 ms.');
SELECT [c].[CaseNumber],[p].*
INTO [#169_TimeActual]
FROM [#169_TimeInputs] AS [c]
CROSS APPLY [monitor].[TVF_ParseStatisticsTimeText]([c].[InputText],[c].[LanguageArgument]) AS [p];
IF EXISTS(SELECT [CaseNumber],[StatementOrdinal],[MessageOrdinal],CONVERT(varbinary(max),[TimeCategory]),[CpuMs],[ElapsedMs],CONVERT(varbinary(max),[LanguageDetected]),CONVERT(varbinary(max),[ParseStatus]),CONVERT(varbinary(max),[RawLine]) FROM [#169_TimeExpected] EXCEPT SELECT [CaseNumber],[StatementOrdinal],[MessageOrdinal],CONVERT(varbinary(max),[TimeCategory]),[CpuMs],[ElapsedMs],CONVERT(varbinary(max),[LanguageDetected]),CONVERT(varbinary(max),[ParseStatus]),CONVERT(varbinary(max),[RawLine]) FROM [#169_TimeActual])
 OR EXISTS(SELECT [CaseNumber],[StatementOrdinal],[MessageOrdinal],CONVERT(varbinary(max),[TimeCategory]),[CpuMs],[ElapsedMs],CONVERT(varbinary(max),[LanguageDetected]),CONVERT(varbinary(max),[ParseStatus]),CONVERT(varbinary(max),[RawLine]) FROM [#169_TimeActual] EXCEPT SELECT [CaseNumber],[StatementOrdinal],[MessageOrdinal],CONVERT(varbinary(max),[TimeCategory]),[CpuMs],[ElapsedMs],CONVERT(varbinary(max),[LanguageDetected]),CONVERT(varbinary(max),[ParseStatus]),CONVERT(varbinary(max),[RawLine]) FROM [#169_TimeExpected])
 OR EXISTS(SELECT [CaseNumber],COUNT_BIG(*) FROM [#169_TimeExpected] GROUP BY [CaseNumber] EXCEPT SELECT [CaseNumber],COUNT_BIG(*) FROM [#169_TimeActual] GROUP BY [CaseNumber])
 OR EXISTS(SELECT [CaseNumber],COUNT_BIG(*) FROM [#169_TimeActual] GROUP BY [CaseNumber] EXCEPT SELECT [CaseNumber],COUNT_BIG(*) FROM [#169_TimeExpected] GROUP BY [CaseNumber])
    THROW 57106,N'Time parser complete literal rows exact text bytes or row multiplicities disagree.',1;

SELECT N'ParserTextBoundaries' AS [ContractName],N'PASS' AS [StatusCode],@FrameworkLevel AS [FrameworkCompatibilityLevel],
       (SELECT COUNT(*) FROM [#169_ActualMetadata]) AS [ReturnFieldCount],
       (SELECT COUNT(*) FROM [#169_ActualMetadata] WHERE [CollationName] IS NOT NULL) AS [ReturnTextCount],
       (SELECT COUNT(*) FROM [#169_BlockingInputs]) AS [BlockingCalls],
       (SELECT COUNT(*) FROM [#169_IoInputs]) AS [IoCalls],
       (SELECT COUNT(*) FROM [#169_TimeInputs]) AS [TimeCalls],
       N'Synthetic complete rows and independent metadata; no workload or persistent fixture.' AS [EvidenceBoundary];
GO

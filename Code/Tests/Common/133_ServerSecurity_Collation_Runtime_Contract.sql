USE [DeineDatenbank];
GO

SET NOCOUNT ON;
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit;
DECLARE @Options TABLE([Name] sysname COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY);
INSERT @Options VALUES(N'xp_cmdshell'),(N'Ole Automation Procedures'),(N'clr enabled'),
    (N'clr strict security'),(N'external scripts enabled'),(N'remote admin connections'),
    (N'contained database authentication');
CREATE TABLE [#ExampleSecurityExport]([Dummy] int NULL);
EXEC [monitor].[USP_ServerSecurityConfiguration]
    @ResultSetArt='TABLE', @ResultTablesJson=N'{"configuration":"#ExampleSecurityExport"}',
    @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0,
    @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT;
IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
    WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleSecurityExport') AND [collation_name] IS NOT NULL)<>2
   OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
             WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleSecurityExport') AND [collation_name] IS NOT NULL
               AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
    THROW 55821,N'Der Security-Konfigurationsexport übernimmt eine fremde tempdb-Collation.',1;
IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>'AVAILABLE' OR COALESCE(@Partial,1)<>0
   OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
   OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sources'))<>3
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sources') WITH ([StatusCode] varchar(40))
             WHERE COALESCE([StatusCode],'')<>'AVAILABLE')
   OR LEFT(COALESCE(JSON_QUERY(@Json,N'$.services'),N''),1)<>N'['
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.properties'))<>1
   OR COALESCE(JSON_QUERY(@Json,N'$.warnings'),N'')<>N'[]'
    THROW 55820,N'Der Security-JSON- oder Quellenstatusvertrag ist verletzt.',1;
IF NOT EXISTS(SELECT 1 FROM [#ExampleSecurityExport] WHERE [ConfigurationName]=N'xp_cmdshell')
   OR NOT EXISTS(SELECT 1 FROM [#ExampleSecurityExport] WHERE [ConfigurationName]=N'clr strict security')
   OR EXISTS(SELECT [ConfigurationName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                    TRY_CONVERT(int,[ConfiguredValue]),TRY_CONVERT(int,[RunningValue]) FROM [#ExampleSecurityExport]
             EXCEPT SELECT [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,
                           CONVERT(int,[c].[value]),CONVERT(int,[c].[value_in_use])
                    FROM [sys].[configurations] AS [c] JOIN @Options AS [o]
                      ON [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[o].[Name])
   OR EXISTS(SELECT [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,
                    CONVERT(int,[c].[value]),CONVERT(int,[c].[value_in_use])
             FROM [sys].[configurations] AS [c] JOIN @Options AS [o]
               ON [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[o].[Name]
             EXCEPT SELECT [ConfigurationName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                           TRY_CONVERT(int,[ConfiguredValue]),TRY_CONVERT(int,[RunningValue]) FROM [#ExampleSecurityExport])
    THROW 55822,N'Die positive Security-Konfiguration stimmt nicht mit der nativen Quelle überein.',1;
IF (SELECT COUNT_BIG(*) FROM [#ExampleSecurityExport])<>(SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.configuration'))
   OR EXISTS(SELECT [ConfigurationName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                    CONVERT(nvarchar(4000),[ConfiguredValue]),CONVERT(nvarchar(4000),[RunningValue]),
                    [Finding] COLLATE SQL_Latin1_General_CP1_CS_AS FROM [#ExampleSecurityExport]
             EXCEPT SELECT [ConfigurationName],[ConfiguredValue],[RunningValue],[Finding]
                    FROM OPENJSON(@Json,N'$.configuration') WITH
                    ([ConfigurationName] nvarchar(128),[ConfiguredValue] nvarchar(4000),
                     [RunningValue] nvarchar(4000),[Finding] varchar(60)))
   OR EXISTS(SELECT [ConfigurationName],[ConfiguredValue],[RunningValue],[Finding]
             FROM OPENJSON(@Json,N'$.configuration') WITH
             ([ConfigurationName] nvarchar(128),[ConfiguredValue] nvarchar(4000),
              [RunningValue] nvarchar(4000),[Finding] varchar(60))
             EXCEPT SELECT [ConfigurationName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                           CONVERT(nvarchar(4000),[ConfiguredValue]),CONVERT(nvarchar(4000),[RunningValue]),
                           [Finding] COLLATE SQL_Latin1_General_CP1_CS_AS FROM [#ExampleSecurityExport])
    THROW 55823,N'TABLE und JSON enthalten verschiedene Security-Konfigurationen.',1;
DROP TABLE [#ExampleSecurityExport];
GO

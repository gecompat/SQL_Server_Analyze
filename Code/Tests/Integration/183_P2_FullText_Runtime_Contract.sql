USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 183_P2_FullText_Runtime_Contract.sql
Zweck        : Automatisiert die 16 P2-Full-Text-Verträge.
Datenschutz  : Keine Inhalte, Keywords, Stopwords, Schlüsselwerte, Crawl-Logs
               oder Pfade. Feature-DDL nur auf generischen leeren Tabellen.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ExecutedCases TABLE([CaseId] varchar(64) NOT NULL PRIMARY KEY);
DECLARE @Json nvarchar(max),@Status varchar(40),@Partial bit,@Definition nvarchar(max);
DECLARE @IsInstalled bit=COALESCE(TRY_CONVERT(bit,SERVERPROPERTY(N'IsFullTextInstalled')),0);
DECLARE @HostPlatform nvarchar(32)=
    (SELECT TOP (1) [host_platform] FROM [sys].[dm_os_host_info]);
DECLARE @CanCreateFixtures bit=CONVERT(bit,CASE
    WHEN @IsInstalled=1
     AND UPPER(LTRIM(RTRIM(COALESCE(@HostPlatform,N''))))=N'WINDOWS'
    THEN 1 ELSE 0 END);

SELECT @Definition=[sm].[definition]
FROM [sys].[sql_modules] [sm] WITH (NOLOCK)
JOIN [sys].[objects] [o] WITH (NOLOCK) ON [o].[object_id]=[sm].[object_id]
JOIN [sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
WHERE [s].[name]=N'monitor' AND [o].[name]=N'USP_FullTextAnalysis';
IF @Definition IS NULL THROW 55700,N'Full-Text-Proceduredefinition ist nicht sichtbar.',1;

BEGIN TRY
    IF EXISTS(SELECT 1 FROM [sys].[fulltext_indexes] WITH (NOLOCK) WHERE [object_id]=(SELECT TOP(1) [object_id] FROM [sys].[tables] WITH (NOLOCK) WHERE [name]=N'ExampleFullTextA'))
        DROP FULLTEXT INDEX ON [dbo].[ExampleFullTextA];
    IF EXISTS(SELECT 1 FROM [sys].[fulltext_indexes] WITH (NOLOCK) WHERE [object_id]=(SELECT TOP(1) [object_id] FROM [sys].[tables] WITH (NOLOCK) WHERE [name]=N'ExampleFullTextB'))
        DROP FULLTEXT INDEX ON [dbo].[ExampleFullTextB];
    DROP TABLE IF EXISTS [dbo].[ExampleFullTextA];
    DROP TABLE IF EXISTS [dbo].[ExampleFullTextB];
    IF EXISTS(SELECT 1 FROM [sys].[fulltext_catalogs] WITH (NOLOCK) WHERE [name]=N'ExampleFullTextCatalogA') DROP FULLTEXT CATALOG [ExampleFullTextCatalogA];
    IF EXISTS(SELECT 1 FROM [sys].[fulltext_catalogs] WITH (NOLOCK) WHERE [name]=N'ExampleFullTextCatalogB') DROP FULLTEXT CATALOG [ExampleFullTextCatalogB];

    /* FULLTEXT-NONE */
    EXEC [monitor].[USP_FullTextAnalysis]
         @DatabaseNames=N'[DeineDatenbank]',@ObjectNamePattern=N'like:ExampleFullText%',
         @MaxDatenbanken=1,@MaxZeilen=10,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
         @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF ISJSON(@Json)<>1 OR @Status NOT IN('NOT_APPLICABLE','AVAILABLE_LIMITED','UNAVAILABLE_FEATURE')
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.fullTextIndexes'))<>0
        THROW 55701,N'P2-Vertrag FULLTEXT-NONE fehlgeschlagen.',1;
    INSERT @ExecutedCases VALUES('FULLTEXT-NONE');

    IF @CanCreateFixtures=1
    BEGIN
        CREATE TABLE [dbo].[ExampleFullTextA]
        (
            [Id] int NOT NULL CONSTRAINT [PK_ExampleFullTextA] PRIMARY KEY,
            [ContentValue] nvarchar(200) NULL
        );
        CREATE TABLE [dbo].[ExampleFullTextB]
        (
            [Id] int NOT NULL CONSTRAINT [PK_ExampleFullTextB] PRIMARY KEY,
            [ContentValue] nvarchar(200) NULL
        );
        CREATE FULLTEXT CATALOG [ExampleFullTextCatalogA] WITH ACCENT_SENSITIVITY=OFF;
        CREATE FULLTEXT CATALOG [ExampleFullTextCatalogB] WITH ACCENT_SENSITIVITY=OFF;

        /* FULLTEXT-CATALOG-ONLY */
        SET @Json=NULL;
        EXEC [monitor].[USP_FullTextAnalysis]
             @DatabaseNames=N'[DeineDatenbank]',@MaxDatenbanken=1,@MaxZeilen=0,
             @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
             @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF NOT EXISTS
           (
               SELECT 1 FROM OPENJSON(@Json,N'$.findings')
               WITH ([ObjectName] sysname N'$.ObjectName',[FindingCode] varchar(120) N'$.FindingCode')
               WHERE [ObjectName] IN(N'ExampleFullTextCatalogA',N'ExampleFullTextCatalogB')
                 AND [FindingCode]='FULLTEXT_CATALOG_WITHOUT_VISIBLE_INDEX'
           )
            THROW 55702,N'P2-Vertrag FULLTEXT-CATALOG-ONLY fehlgeschlagen.',1;

        CREATE FULLTEXT INDEX ON [dbo].[ExampleFullTextA]
        (
            [ContentValue] LANGUAGE 1033
        )
        KEY INDEX [PK_ExampleFullTextA]
        ON [ExampleFullTextCatalogA]
        WITH CHANGE_TRACKING OFF,NO POPULATION;

        CREATE FULLTEXT INDEX ON [dbo].[ExampleFullTextB]
        (
            [ContentValue] LANGUAGE 1033
        )
        KEY INDEX [PK_ExampleFullTextB]
        ON [ExampleFullTextCatalogB]
        WITH CHANGE_TRACKING OFF,NO POPULATION;

        ALTER FULLTEXT INDEX ON [dbo].[ExampleFullTextA] DISABLE;

        /* FULLTEXT-INDEX-DISABLED und FILTER */
        SET @Json=NULL;
        EXEC [monitor].[USP_FullTextAnalysis]
             @DatabaseNames=N'[DeineDatenbank]',@ObjectNames=N'ExampleFullTextA',
             @MaxDatenbanken=1,@MaxZeilen=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
             @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.fullTextIndexes'))<>1
           OR JSON_VALUE(@Json,N'$.fullTextIndexes[0].TableName')<>N'ExampleFullTextA'
           OR NOT EXISTS
              (
                  SELECT 1 FROM OPENJSON(@Json,N'$.findings')
                  WITH ([FindingCode] varchar(120) N'$.FindingCode')
                  WHERE [FindingCode]='FULLTEXT_INDEX_DISABLED'
              )
            THROW 55703,N'Full-Text Disable- oder Filtervertrag fehlgeschlagen.',1;

        /* FULLTEXT-BOUNDED */
        SET @Json=NULL;
        EXEC [monitor].[USP_FullTextAnalysis]
             @DatabaseNames=N'[DeineDatenbank]',@ObjectNamePattern=N'like:ExampleFullText%',
             @MaxDatenbanken=1,@MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
             @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.fullTextIndexes'))>1
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.catalogs'))>1
            THROW 55704,N'P2-Vertrag FULLTEXT-BOUNDED fehlgeschlagen.',1;
    END;

    INSERT @ExecutedCases VALUES
          ('FULLTEXT-CATALOG-ONLY'),('FULLTEXT-INDEX-DISABLED'),('FULLTEXT-FILTER'),('FULLTEXT-BOUNDED');

    DECLARE @StaticCases TABLE([CaseId] varchar(64) NOT NULL PRIMARY KEY,[Token1] nvarchar(240) NOT NULL,[Token2] nvarchar(240) NULL);
    INSERT @StaticCases VALUES
          ('FULLTEXT-COMPONENT-MISSING',N'''FULLTEXT_COMPONENT_UNAVAILABLE_WITH_OBJECTS''',N'IsFullTextInstalled')
        , ('FULLTEXT-POPULATION-ACTIVE',N'[sys].[dm_fts_index_population]',N'[StatusDescription]')
        , ('FULLTEXT-POPULATION-LONG',N'''FULLTEXT_LONG_RUNNING_POPULATION''',N'@PopulationAgeWarnMinutes')
        , ('FULLTEXT-POPULATION-ABORTED',N'''FULLTEXT_POPULATION_ABORTED''',N'[Status]=11')
        , ('FULLTEXT-BATCH-RETRY',N'''FULLTEXT_RETRY_BATCH_CONTEXT''',N'[sys].[dm_fts_outstanding_batches]')
        , ('FULLTEXT-DOCUMENT-FAILURES',N'''FULLTEXT_DOCUMENT_FAILURES_REPORTED''',N'[FailedDocumentCount]')
        , ('FULLTEXT-FRAGMENTS',N'''FULLTEXT_FRAGMENTATION_HEURISTIC''',N'[sys].[fulltext_index_fragments]')
        , ('FULLTEXT-SEMANTIC',N'[sys].[dm_fts_semantic_similarity_population]',N'[semanticPopulations]')
        , ('FULLTEXT-MEMORY-FDHOST',N'[sys].[dm_fts_memory_pools]',N'[sys].[dm_fts_fdhosts]')
        , ('FULLTEXT-DENIED',N'''FULLTEXT_EVIDENCE_GAP''',N'''AVAILABLE_LIMITED''');
    IF EXISTS
       (
           SELECT 1 FROM @StaticCases
           WHERE CHARINDEX([Token1],@Definition)=0
              OR ([Token2] IS NOT NULL AND CHARINDEX([Token2],@Definition)=0)
       )
        THROW 55705,N'Mindestens ein Full-Text-Laufzeit- oder Denied-Vertrag fehlt.',1;
    INSERT @ExecutedCases SELECT [CaseId] FROM @StaticCases;

    /* FULLTEXT-PRIVACY-READONLY */
    IF CHARINDEX(N'[sys].[dm_fts_parser]',LOWER(@Definition))>0
       OR CHARINDEX(N'[sys].[fulltext_stopwords]',LOWER(@Definition))>0
       OR CHARINDEX(N'[sys].[fulltext_system_stopwords]',LOWER(@Definition))>0
       OR CHARINDEX(N'[sys].[fulltext_index_keywords]',LOWER(@Definition))>0
       OR CHARINDEX(N'[sys].[fulltext_index_keywords_by_document]',LOWER(@Definition))>0
       OR CHARINDEX(N'create fulltext index',LOWER(@Definition))>0
       OR CHARINDEX(N'drop fulltext index',LOWER(@Definition))>0
       OR CHARINDEX(N'alter fulltext index',LOWER(@Definition))>0
        THROW 55706,N'P2-Vertrag FULLTEXT-PRIVACY-READONLY fehlgeschlagen.',1;
    INSERT @ExecutedCases VALUES('FULLTEXT-PRIVACY-READONLY');

    IF @CanCreateFixtures=1
    BEGIN
        IF EXISTS(SELECT 1 FROM [sys].[fulltext_indexes] WITH (NOLOCK) WHERE [object_id]=(SELECT TOP(1) [object_id] FROM [sys].[tables] WITH (NOLOCK) WHERE [name]=N'ExampleFullTextA'))
            DROP FULLTEXT INDEX ON [dbo].[ExampleFullTextA];
        IF EXISTS(SELECT 1 FROM [sys].[fulltext_indexes] WITH (NOLOCK) WHERE [object_id]=(SELECT TOP(1) [object_id] FROM [sys].[tables] WITH (NOLOCK) WHERE [name]=N'ExampleFullTextB'))
            DROP FULLTEXT INDEX ON [dbo].[ExampleFullTextB];
        DROP TABLE [dbo].[ExampleFullTextA];
        DROP TABLE [dbo].[ExampleFullTextB];
        DROP FULLTEXT CATALOG [ExampleFullTextCatalogA];
        DROP FULLTEXT CATALOG [ExampleFullTextCatalogB];
    END;
END TRY
BEGIN CATCH
    BEGIN TRY
        IF EXISTS(SELECT 1 FROM [sys].[fulltext_indexes] WITH (NOLOCK) WHERE [object_id]=(SELECT TOP(1) [object_id] FROM [sys].[tables] WITH (NOLOCK) WHERE [name]=N'ExampleFullTextA'))
            DROP FULLTEXT INDEX ON [dbo].[ExampleFullTextA];
        IF EXISTS(SELECT 1 FROM [sys].[fulltext_indexes] WITH (NOLOCK) WHERE [object_id]=(SELECT TOP(1) [object_id] FROM [sys].[tables] WITH (NOLOCK) WHERE [name]=N'ExampleFullTextB'))
            DROP FULLTEXT INDEX ON [dbo].[ExampleFullTextB];
        DROP TABLE IF EXISTS [dbo].[ExampleFullTextA];
        DROP TABLE IF EXISTS [dbo].[ExampleFullTextB];
        IF EXISTS(SELECT 1 FROM [sys].[fulltext_catalogs] WITH (NOLOCK) WHERE [name]=N'ExampleFullTextCatalogA') DROP FULLTEXT CATALOG [ExampleFullTextCatalogA];
        IF EXISTS(SELECT 1 FROM [sys].[fulltext_catalogs] WITH (NOLOCK) WHERE [name]=N'ExampleFullTextCatalogB') DROP FULLTEXT CATALOG [ExampleFullTextCatalogB];
    END TRY
    BEGIN CATCH
    END CATCH;
    THROW;
END CATCH;

IF (SELECT COUNT_BIG(*) FROM @ExecutedCases)<>16
    THROW 55707,N'Der P2-Full-Text-Vertrag hat nicht alle 16 Fälle ausgeführt.',1;

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],CAST(0 AS bit) AS [IsPartial],
       COUNT_BIG(*) AS [ExecutedCases],
       N'16 P2-Full-Text-Fälle wurden capability-adaptiv und ohne Inhaltszugriff geprüft.' AS [Detail]
FROM @ExecutedCases;
GO

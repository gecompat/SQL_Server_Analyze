USE [DeineDatenbank];
GO

/*
Prüft die Erkennung sichtbarer Systemkataloge gegen deren native Existenz.
Die Procedure erhält ausschließlich die explizit gewählte Testdatenbank.
Der Test liest Metadaten und verändert weder Konfiguration noch Nutzdaten.
*/
SET NOCOUNT ON;

DECLARE @DatabaseName sysname=DB_NAME(),@DatabaseNames nvarchar(258)=QUOTENAME(DB_NAME());
DECLARE @HasVector bit=CASE WHEN EXISTS
(
    SELECT 1 FROM [sys].[all_views] AS [v]
    JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[v].[schema_id]
    WHERE [s].[name]=N'sys' AND [v].[name]=N'vector_indexes'
) THEN 1 ELSE 0 END;
DECLARE @HasReplicas bit=CASE WHEN EXISTS
(
    SELECT 1 FROM [sys].[all_views] AS [v]
    JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[v].[schema_id]
    WHERE [s].[name]=N'sys' AND [v].[name]=N'query_store_replicas'
) THEN 1 ELSE 0 END;
DECLARE @Json nvarchar(max),@ExpectedVectorCount bigint=0,@ExpectedReplicaCount bigint=0;

EXEC [monitor].[USP_ServerFeatureCapabilities]
      @DatabaseNames=@DatabaseNames
    , @MitSpezialindizes=1
    , @MitQueryStoreReplicas=1
    , @MitPlattformdetails=0
    , @MaxZeilen=0
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0;

IF COALESCE(ISJSON(@Json),0)<>1
   OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),'')<>'AVAILABLE'
   OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),'')<>'false'
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings'))
    THROW 54880,N'Systemkatalogprobe liefert kein vollständiges AVAILABLE-Ergebnis.',1;

IF NOT EXISTS
(
    SELECT 1 FROM OPENJSON(@Json,N'$.databaseFeatures')
    WITH ([DatabaseName] sysname,[FeatureName] nvarchar(128),[AvailabilityStatus] varchar(40)) AS [f]
    WHERE [f].[DatabaseName]=@DatabaseName
      AND [f].[FeatureName]=N'QUERY_STORE_READABLE_SECONDARY'
      AND [f].[AvailabilityStatus]=CASE WHEN @HasReplicas=1 THEN 'AVAILABLE' ELSE 'UNAVAILABLE_VERSION' END
)
    THROW 54881,N'Query-Store-Replica-Erkennung widerspricht dem nativen Systemkatalog.',1;

IF @HasVector=1 AND EXISTS
(
    SELECT 1 FROM OPENJSON(@Json,N'$.databaseFeatures')
    WITH ([FeatureName] nvarchar(128),[AvailabilityStatus] varchar(40)) AS [f]
    WHERE [f].[FeatureName]=N'VECTOR_INDEX_METADATA' AND [f].[AvailabilityStatus]='UNAVAILABLE_VERSION'
)
    THROW 54882,N'Vorhandener Vector-Systemkatalog wird als nicht verfügbar gemeldet.',1;

IF @HasVector=0 AND NOT EXISTS
(
    SELECT 1 FROM OPENJSON(@Json,N'$.databaseFeatures')
    WITH ([FeatureName] nvarchar(128),[AvailabilityStatus] varchar(40)) AS [f]
    WHERE [f].[FeatureName]=N'VECTOR_INDEX_METADATA' AND [f].[AvailabilityStatus]='UNAVAILABLE_VERSION'
)
    THROW 54883,N'Fehlender Vector-Systemkatalog erhält keinen Versionsfallback.',1;

IF @HasVector=1
    EXEC [sys].[sp_executesql]
          N'SELECT @Count=COUNT_BIG(*) FROM [sys].[vector_indexes] AS [v] JOIN [sys].[objects] AS [o] ON [o].[object_id]=[v].[object_id] JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[o].[schema_id];'
        , N'@Count bigint OUTPUT',@Count=@ExpectedVectorCount OUTPUT;

IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.specialIndexes')
    WITH ([IndexFamily] nvarchar(16)) AS [i] WHERE [i].[IndexFamily]=N'VECTOR')<>@ExpectedVectorCount
    THROW 54884,N'Vector-Indexausgabe entspricht nicht dem sichtbaren nativen Inventar.',1;

IF @HasReplicas=1
BEGIN
    EXEC [sys].[sp_executesql] N'SELECT @Count=COUNT_BIG(*) FROM [sys].[query_store_replicas];',
         N'@Count bigint OUTPUT',@Count=@ExpectedReplicaCount OUTPUT;
    IF NOT EXISTS
    (
        SELECT 1 FROM OPENJSON(@Json,N'$.databaseFeatures')
        WITH ([FeatureName] nvarchar(128),[AvailabilityStatus] varchar(40),[FeatureValue] nvarchar(100)) AS [f]
        WHERE [f].[FeatureName]=N'QUERY_STORE_REPLICA_GROUP_COUNT' AND [f].[AvailabilityStatus]='AVAILABLE'
          AND TRY_CONVERT(bigint,[f].[FeatureValue])=@ExpectedReplicaCount
    )
        THROW 54885,N'Replica-Gruppenzahl entspricht nicht dem nativen Systemkatalog.',1;
END;

EXEC [monitor].[USP_ServerFeatureCapabilities]
      @DatabaseNames=@DatabaseNames
    , @MitSpezialindizes=0
    , @MitQueryStoreReplicas=0
    , @MitPlattformdetails=0
    , @MaxZeilen=0
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0;

IF COALESCE(ISJSON(@Json),0)<>1
   OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),'')<>'AVAILABLE'
   OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),'')<>'false'
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings'))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.specialIndexes'))
   OR EXISTS
      (SELECT 1 FROM OPENJSON(@Json,N'$.databaseFeatures') WITH ([FeatureName] nvarchar(128)) AS [f]
       WHERE [f].[FeatureName] IN (N'VECTOR_INDEX_METADATA',N'QUERY_STORE_REPLICA_GROUP_COUNT'))
    THROW 54886,N'Deaktivierte Detailoptionen erzeugen unerwartete Ausgaben oder Warnungen.',1;

SELECT CAST('PASS' AS varchar(16)) AS [Status],
       @HasVector AS [VectorCatalogDetected],@HasReplicas AS [ReplicaCatalogDetected];
GO

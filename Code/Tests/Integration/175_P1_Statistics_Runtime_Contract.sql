USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 175_P1_Statistics_Runtime_Contract.sql
Zweck        : Prüft Laufzeitverträge für acht
               P1-Statistikverteilungsfälle.
Datenschutz  : Ausschließlich generische synthetische Objekte und Principals;
               Laufzeitwerte werden nicht in Repositoryartefakte übernommen.
Nebenwirkung : Erzeugt kurzlebige Tabellen, Statistiken, eine Partitionierung
               sowie transaktional einen synthetischen Berechtigungskontext.
               Sämtliche Fixtures werden im Erfolgs- und Fehlerpfad entfernt.
Kosten       : Begrenzte FULLSCAN-Statistiken auf weniger als 10.000
               synthetischen Zeilen; Histogrammzugriffe sind objektbezogen.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max),@Status varchar(40),@Partial bit;
DECLARE @ExecutedCases TABLE([CaseId] varchar(40) NOT NULL PRIMARY KEY);
DECLARE @Impersonating bit=0;

/* STAT-DOMINANT: derselbe rein lokale Formatter prüft erhaltene Werte und zwölf
   synthetische Diagnoseeingaben. Die Proben reproduzieren keinen Analyzerfehler. */
DECLARE @StatError int,@StatLine nvarchar(1024),@StatDiagnostic nvarchar(max)=N'SET @Line=NULL;
DECLARE @Valid bit=COALESCE(ISJSON(@Json),0),@Safe nvarchar(max),@ParseError int=NULL,
    @DbRows int,@DbStatus nvarchar(4000),@DbError int,@DbErrorKinds int,@Candidates bigint,@Visible bigint,
    @DistRows int,@Steps int,@HistRows decimal(38,4),@Dominant decimal(19,4),
    @FindingRows int,@Matches int,@Metric decimal(38,4),@Threshold decimal(38,4),@MetaStatus nvarchar(4000);
SET @Safe=CASE WHEN @Valid=1 THEN @Json ELSE N''{}'' END;
BEGIN TRY
    SET @MetaStatus=JSON_VALUE(@Safe,N''$.meta.statusCode'');
    SELECT @DbRows=COUNT(*),@DbStatus=CASE WHEN COUNT(*)=1 THEN MAX([StatusCode]) WHEN COUNT(*)>1 THEN N''MULTIPLE'' END,
        @DbError=CASE WHEN COUNT(DISTINCT TRY_CONVERT(int,[ErrorNumber]))=1 THEN MAX(TRY_CONVERT(int,[ErrorNumber])) END,
        @DbErrorKinds=COUNT(DISTINCT TRY_CONVERT(int,[ErrorNumber])),
        @Candidates=CASE WHEN COUNT(*)=1 THEN MAX(TRY_CONVERT(bigint,[CandidateCount])) END,
        @Visible=CASE WHEN COUNT(*)=1 THEN MAX(TRY_CONVERT(bigint,[HistogramVisibleCount])) END
    FROM OPENJSON(@Safe,N''$.databaseStatus'') WITH ([StatusCode] nvarchar(4000),[ErrorNumber] nvarchar(4000),
        [CandidateCount] nvarchar(4000),[HistogramVisibleCount] nvarchar(4000));
    SELECT @DistRows=COUNT(*),@Steps=CASE WHEN COUNT(*)=1 THEN MAX(TRY_CONVERT(int,[HistogramSteps])) END,
        @HistRows=CASE WHEN COUNT(*)=1 THEN MAX(TRY_CONVERT(decimal(38,4),[HistogramEstimatedRows])) END,
        @Dominant=CASE WHEN COUNT(*)=1 THEN MAX(TRY_CONVERT(decimal(19,4),[DominantStepPercent])) END
    FROM OPENJSON(@Safe,N''$.distribution'') WITH ([ObjectName] nvarchar(4000),[StatisticsName] nvarchar(4000),
        [HistogramSteps] nvarchar(4000),[HistogramEstimatedRows] nvarchar(4000),[DominantStepPercent] nvarchar(4000))
    WHERE [ObjectName]=N''ExampleStatisticsDominant'' AND [StatisticsName]=N''ST_ExampleStatisticsDominant'';
    SELECT @FindingRows=COUNT(*),@Matches=COALESCE(SUM(CASE WHEN TRY_CONVERT(decimal(38,4),[MetricValue])>=50
        AND TRY_CONVERT(decimal(38,4),[ThresholdValue])=50 THEN 1 ELSE 0 END),0),
        @Metric=CASE WHEN COUNT(*)=1 THEN MAX(TRY_CONVERT(decimal(38,4),[MetricValue])) END,
        @Threshold=CASE WHEN COUNT(*)=1 THEN MAX(TRY_CONVERT(decimal(38,4),[ThresholdValue])) END
    FROM OPENJSON(@Safe,N''$.findings'') WITH ([ObjectName] nvarchar(4000),[FindingCode] nvarchar(4000),
        [MetricValue] nvarchar(4000),[ThresholdValue] nvarchar(4000))
    WHERE [ObjectName]=N''ExampleStatisticsDominant'' AND [FindingCode]=N''DOMINANT_HISTOGRAM_STEP_REVIEW'';
END TRY
BEGIN CATCH
    SET @ParseError=ERROR_NUMBER();
END CATCH;
IF @Valid=0 OR @Status<>''AVAILABLE_WITH_FINDING'' OR COALESCE(@Matches,0)=0 OR @ParseError IS NOT NULL
BEGIN
DECLARE @Statuses TABLE ([Kind] char(1),[RawValue] nvarchar(max),[SafeValue] varchar(32));
INSERT @Statuses VALUES(''S'',@Status,NULL),(''M'',@MetaStatus,NULL),(''D'',@DbStatus,NULL);
UPDATE @Statuses SET [SafeValue]=CASE WHEN [RawValue] IS NULL THEN ''NULL''
    WHEN EXISTS(SELECT 1 FROM STRING_SPLIT(''AVAILABLE|AVAILABLE_EMPTY|AVAILABLE_WITH_FINDING|AVAILABLE_LIMITED|PARTIAL|TIMEOUT|DENIED_PERMISSION|ERROR_HANDLED|DATABASE_UNAVAILABLE|UNAVAILABLE_FEATURE|UNAVAILABLE_OBJECT|INVALID_PARAMETER|NOT_APPLICABLE|MULTIPLE'',''|'') [s]
        WHERE CONVERT(varbinary(max),CONVERT(nvarchar(max),[s].[value]))=CONVERT(varbinary(max),[RawValue]))
    THEN CONVERT(varchar(32),[RawValue]) ELSE ''UNKNOWN'' END;
SET @Line=CONCAT(N''Error: STAT_DOMINANT_FAILURE badJson='',1-CONVERT(int,@Valid),
    N'' badStatus='',CASE WHEN @Status<>''AVAILABLE_WITH_FINDING'' THEN 1 ELSE 0 END,
    N'' badFinding='',CASE WHEN COALESCE(@Matches,0)=0 THEN 1 ELSE 0 END,
    N'' status='',(SELECT [SafeValue] FROM @Statuses WHERE [Kind]=''S''),
    N'' metaStatus='',(SELECT [SafeValue] FROM @Statuses WHERE [Kind]=''M''),
    N'' partial='',COALESCE(CONVERT(varchar(1),@Partial),''NULL''),N'' error='',COALESCE(CONVERT(varchar(12),@Error),''NULL''),
    N'' dbRows='',COALESCE(CONVERT(varchar(12),@DbRows),''NULL''),
    N'' dbStatus='',(SELECT [SafeValue] FROM @Statuses WHERE [Kind]=''D''),N'' dbError='',COALESCE(CONVERT(varchar(12),@DbError),''NULL''),
    N'' dbErrorKinds='',COALESCE(CONVERT(varchar(12),@DbErrorKinds),''NULL''),
    N'' candidates='',COALESCE(CONVERT(varchar(20),@Candidates),''NULL''),N'' visible='',COALESCE(CONVERT(varchar(20),@Visible),''NULL''),
    N'' distributions='',COALESCE(CONVERT(varchar(12),@DistRows),''NULL''),N'' steps='',COALESCE(CONVERT(varchar(12),@Steps),''NULL''),
    N'' histogramRows='',COALESCE(CONVERT(varchar(45),@HistRows),''NULL''),N'' dominant='',COALESCE(CONVERT(varchar(24),@Dominant),''NULL''),
    N'' findings='',COALESCE(CONVERT(varchar(12),@FindingRows),''NULL''),N'' matches='',COALESCE(CONVERT(varchar(12),@Matches),''NULL''),
    N'' metric='',COALESCE(CONVERT(varchar(45),@Metric),''NULL''),N'' threshold='',COALESCE(CONVERT(varchar(45),@Threshold),''NULL''),
    N'' parseError='',COALESCE(CONVERT(varchar(12),@ParseError),''NULL''));
END;
';
DECLARE @StatParameters nvarchar(300)=N'@Json nvarchar(max),@Status varchar(max),@Partial bit,@Error int,@Line nvarchar(1024) OUTPUT';
DECLARE @SDBase nvarchar(max)=N'{"meta":{"statusCode":"AVAILABLE_WITH_FINDING"},"databaseStatus":[{"StatusCode":"AVAILABLE","ErrorNumber":null,"CandidateCount":1,"HistogramVisibleCount":1}],"distribution":[{"ObjectName":"ExampleStatisticsDominant","StatisticsName":"ST_ExampleStatisticsDominant","HistogramSteps":101,"HistogramEstimatedRows":1100,"DominantStepPercent":90.9091}],"findings":[{"ObjectName":"ExampleStatisticsDominant","FindingCode":"DOMINANT_HISTOGRAM_STEP_REVIEW","MetricValue":90.9091,"ThresholdValue":50}]}',
    @SDJson nvarchar(max),@SDStatus varchar(max),@SDPartial bit,@SDError int,@SDOrdinal int=0,@SDCaught int,@SDToken nvarchar(80),@SDCharacter int;
WHILE @SDOrdinal<12
BEGIN
    SELECT @SDJson=@SDBase,@SDStatus='AVAILABLE_WITH_FINDING',@SDPartial=0,@SDError=NULL,@SDCaught=NULL,@StatLine=NULL,
        @SDToken=CASE @SDOrdinal WHEN 1 THEN N'badJson=1' WHEN 2 THEN N'badJson=1' WHEN 3 THEN N'status=UNKNOWN'
        WHEN 4 THEN N'findings=0' WHEN 5 THEN N'findings=0' WHEN 6 THEN N'metric=49.0000' WHEN 7 THEN N'threshold=49.0000'
        WHEN 8 THEN N'dbError=1222' WHEN 9 THEN N'error=8115' WHEN 10 THEN N'dbStatus=MULTIPLE' WHEN 11 THEN N'metaStatus=UNKNOWN' END;
    IF @SDOrdinal=1 SET @SDJson=NULL;
    IF @SDOrdinal=2 SET @SDJson=N'SYNTHETIC_PRIVATE_PAYLOAD'+NCHAR(10);
    IF @SDOrdinal=3 SET @SDStatus='SYNTHETIC_PRIVATE_PAYLOAD'+CHAR(10)+'%';
    IF @SDOrdinal=4 SET @SDJson=JSON_MODIFY(@SDJson,N'$.findings',JSON_QUERY(N'[]'));
    IF @SDOrdinal=5 SET @SDJson=JSON_MODIFY(@SDJson,N'$.findings[0].FindingCode','OTHER_SYNTHETIC_FINDING');
    IF @SDOrdinal=6 SET @SDJson=JSON_MODIFY(@SDJson,N'$.findings[0].MetricValue',49);
    IF @SDOrdinal=7 SET @SDJson=JSON_MODIFY(@SDJson,N'$.findings[0].ThresholdValue',49);
    IF @SDOrdinal=8
    BEGIN
        SET @SDJson=JSON_MODIFY(JSON_MODIFY(@SDJson,N'$.databaseStatus[0].StatusCode','TIMEOUT'),N'$.databaseStatus[0].ErrorNumber',1222);
        SELECT @SDStatus='AVAILABLE_LIMITED',@SDPartial=1;
    END;
    IF @SDOrdinal=9 SELECT @SDError=8115,@SDStatus='ERROR_HANDLED',@SDPartial=1;
    IF @SDOrdinal=10
    BEGIN
        SET @SDJson=JSON_MODIFY(JSON_MODIFY(@SDJson,N'$.distribution[0].HistogramEstimatedRows','SYNTHETIC_PRIVATE_PAYLOAD'),
            N'append $.databaseStatus',JSON_QUERY(N'{"StatusCode":"TIMEOUT","ErrorNumber":1222}'));
        SET @SDJson=JSON_MODIFY(@SDJson,N'$.findings',JSON_QUERY(N'[]'));
        SET @SDJson=JSON_MODIFY(@SDJson,N'append $.databaseStatus',JSON_QUERY(N'{"StatusCode":"ERROR_HANDLED","ErrorNumber":1205}'));
        SELECT @SDStatus=NULL,@SDPartial=NULL;
    END;
    IF @SDOrdinal=11
    BEGIN
        SET @SDJson=JSON_MODIFY(JSON_MODIFY(@SDJson,N'$.meta.statusCode',N'SYNTHETIC_PRIVATE_PAYLOAD'+NCHAR(937)+NCHAR(10)),
            N'$.databaseStatus[0].ErrorMessage',REPLICATE(CONVERT(nvarchar(max),N'SYNTHETIC_PRIVATE_PAYLOAD'),300));
        SET @SDJson=JSON_MODIFY(JSON_MODIFY(@SDJson,N'$.databaseStatus[0].CandidateCount','9223372036854775807'),
            N'$.distribution[0].HistogramEstimatedRows','9999999999999999999999999999999999.9999');
        SET @SDJson=JSON_MODIFY(@SDJson,N'$.findings[0].MetricValue','9999999999999999999999999999999999.9999');
        SELECT @SDStatus='UNKNOWN'+REPLICATE('X',4096),@SDError=2147483647;
    END;
    BEGIN TRY
        EXEC [sys].[sp_executesql] @StatDiagnostic,@StatParameters,@SDJson,@SDStatus,@SDPartial,@SDError,@StatLine OUTPUT;
        IF @StatLine IS NOT NULL THROW 54901,N'P1-Vertrag STAT-DOMINANT fehlgeschlagen.',1;
    END TRY
    BEGIN CATCH
        SET @SDCaught=ERROR_NUMBER();
        IF @SDCaught<>54901 THROW;
    END CATCH;
    IF (@SDOrdinal=0 AND (@SDCaught IS NOT NULL OR @StatLine IS NOT NULL))
       OR (@SDOrdinal>0 AND (@SDCaught IS NULL OR @StatLine IS NULL OR CHARINDEX(@SDToken,@StatLine)=0
           OR CHARINDEX(N'Error: STAT_DOMINANT_FAILURE ',@StatLine)<>1 OR LEN(@StatLine)>1024
           OR CHARINDEX(N'SYNTHETIC_PRIVATE_PAYLOAD',@StatLine)>0))
        THROW 54910,N'STAT-DOMINANT Diagnosegegenprobe fehlgeschlagen.',1;
    IF (@SDOrdinal=10 AND (CHARINDEX(N'dbRows=3',@StatLine)=0 OR CHARINDEX(N'dbError=NULL',@StatLine)=0
        OR CHARINDEX(N'dbErrorKinds=2',@StatLine)=0))
       OR (@SDOrdinal=11 AND (CHARINDEX(N'candidates=9223372036854775807',@StatLine)=0 OR CHARINDEX(N'parseError=NULL',@StatLine)=0))
        THROW 54910,N'STAT-DOMINANT Diagnosegrenzen fehlgeschlagen.',1;
    SET @SDCharacter=1;
    WHILE @SDCharacter<=COALESCE(LEN(@StatLine),0)
    BEGIN
        IF UNICODE(SUBSTRING(@StatLine,@SDCharacter,1)) NOT BETWEEN 32 AND 126
            THROW 54910,N'STAT-DOMINANT Diagnose enthält unerlaubte Zeichen.',1;
        SET @SDCharacter+=1;
    END;
    SET @SDOrdinal+=1;
END;

BEGIN TRY
    DROP TABLE IF EXISTS [dbo].[ExampleStatisticsIncremental];
    DROP TABLE IF EXISTS [dbo].[ExampleStatisticsBounded];
    DROP TABLE IF EXISTS [dbo].[ExampleStatisticsFiltered];
    DROP TABLE IF EXISTS [dbo].[ExampleStatisticsModified];
    DROP TABLE IF EXISTS [dbo].[ExampleStatisticsTail];
    DROP TABLE IF EXISTS [dbo].[ExampleStatisticsDominant];
    DROP TABLE IF EXISTS [dbo].[ExampleStatisticsUniform];

    IF EXISTS(SELECT 1 FROM [sys].[partition_schemes] WITH (NOLOCK) WHERE [name]=N'PS_ExampleStatisticsIncremental')
        DROP PARTITION SCHEME [PS_ExampleStatisticsIncremental];
    IF EXISTS(SELECT 1 FROM [sys].[partition_functions] WITH (NOLOCK) WHERE [name]=N'PF_ExampleStatisticsIncremental')
        DROP PARTITION FUNCTION [PF_ExampleStatisticsIncremental];

    CREATE TABLE [#P1_Statistics_Runtime_Contract_Numbers]
    (
        [NumberValue] int NOT NULL PRIMARY KEY
    );

    ;WITH [numbers] AS
    (
        SELECT 1 AS [NumberValue]
        UNION ALL
        SELECT [NumberValue]+1
        FROM [numbers]
        WHERE [NumberValue]<2000
    )
    INSERT [#P1_Statistics_Runtime_Contract_Numbers]([NumberValue])
    SELECT [NumberValue]
    FROM [numbers]
    OPTION (MAXRECURSION 0);

    CREATE TABLE [dbo].[ExampleStatisticsUniform]
    (
        [DistributionValue] int NOT NULL
    );
    INSERT [dbo].[ExampleStatisticsUniform]([DistributionValue])
    SELECT [NumberValue]
    FROM [#P1_Statistics_Runtime_Contract_Numbers]
    WHERE [NumberValue]<=1000;
    CREATE STATISTICS [ST_ExampleStatisticsUniform]
        ON [dbo].[ExampleStatisticsUniform]([DistributionValue]) WITH FULLSCAN;

    CREATE TABLE [dbo].[ExampleStatisticsDominant]
    (
        [DistributionValue] int NOT NULL
    );
    INSERT [dbo].[ExampleStatisticsDominant]([DistributionValue])
    SELECT 1 FROM [#P1_Statistics_Runtime_Contract_Numbers] WHERE [NumberValue]<=1000
    UNION ALL
    SELECT [NumberValue]+1 FROM [#P1_Statistics_Runtime_Contract_Numbers] WHERE [NumberValue]<=100;
    CREATE STATISTICS [ST_ExampleStatisticsDominant]
        ON [dbo].[ExampleStatisticsDominant]([DistributionValue]) WITH FULLSCAN;

    CREATE TABLE [dbo].[ExampleStatisticsTail]
    (
        [DistributionValue] int NOT NULL
    );
    INSERT [dbo].[ExampleStatisticsTail]([DistributionValue])
    SELECT [NumberValue] FROM [#P1_Statistics_Runtime_Contract_Numbers] WHERE [NumberValue]<=100
    UNION ALL
    SELECT 101 FROM [#P1_Statistics_Runtime_Contract_Numbers] WHERE [NumberValue]<=1000;
    CREATE STATISTICS [ST_ExampleStatisticsTail]
        ON [dbo].[ExampleStatisticsTail]([DistributionValue]) WITH FULLSCAN;

    CREATE TABLE [dbo].[ExampleStatisticsModified]
    (
        [DistributionValue] int NOT NULL
    );
    INSERT [dbo].[ExampleStatisticsModified]([DistributionValue])
    SELECT (([NumberValue]-1)%100)+1
    FROM [#P1_Statistics_Runtime_Contract_Numbers]
    WHERE [NumberValue]<=1000;
    CREATE STATISTICS [ST_ExampleStatisticsModified]
        ON [dbo].[ExampleStatisticsModified]([DistributionValue]) WITH FULLSCAN;
    INSERT [dbo].[ExampleStatisticsModified]([DistributionValue])
    SELECT 1000+[NumberValue]
    FROM [#P1_Statistics_Runtime_Contract_Numbers]
    WHERE [NumberValue]<=500;

    CREATE TABLE [dbo].[ExampleStatisticsFiltered]
    (
          [DistributionValue] int NOT NULL
        , [IsIncluded] bit NOT NULL
    );
    INSERT [dbo].[ExampleStatisticsFiltered]([DistributionValue],[IsIncluded])
    SELECT (([NumberValue]-1)%100)+1,CONVERT(bit,1)
    FROM [#P1_Statistics_Runtime_Contract_Numbers]
    WHERE [NumberValue]<=1000
    UNION ALL
    SELECT (([NumberValue]-1)%100)+1,CONVERT(bit,0)
    FROM [#P1_Statistics_Runtime_Contract_Numbers]
    WHERE [NumberValue]<=1000;
    CREATE STATISTICS [ST_ExampleStatisticsFiltered]
        ON [dbo].[ExampleStatisticsFiltered]([DistributionValue])
        WHERE [IsIncluded]=(1) WITH FULLSCAN;

    CREATE TABLE [dbo].[ExampleStatisticsBounded]
    (
          [C1] int NOT NULL
        , [C2] int NOT NULL
        , [C3] int NOT NULL
        , [C4] int NOT NULL
        , [C5] int NOT NULL
        , [C6] int NOT NULL
    );
    INSERT [dbo].[ExampleStatisticsBounded]([C1],[C2],[C3],[C4],[C5],[C6])
    SELECT ([NumberValue]-1)%10,([NumberValue]-1)%20,([NumberValue]-1)%25,
           ([NumberValue]-1)%40,([NumberValue]-1)%50,([NumberValue]-1)%100
    FROM [#P1_Statistics_Runtime_Contract_Numbers]
    WHERE [NumberValue]<=1000;
    CREATE STATISTICS [ST_ExampleStatisticsBounded_1] ON [dbo].[ExampleStatisticsBounded]([C1]) WITH FULLSCAN;
    CREATE STATISTICS [ST_ExampleStatisticsBounded_2] ON [dbo].[ExampleStatisticsBounded]([C2]) WITH FULLSCAN;
    CREATE STATISTICS [ST_ExampleStatisticsBounded_3] ON [dbo].[ExampleStatisticsBounded]([C3]) WITH FULLSCAN;
    CREATE STATISTICS [ST_ExampleStatisticsBounded_4] ON [dbo].[ExampleStatisticsBounded]([C4]) WITH FULLSCAN;
    CREATE STATISTICS [ST_ExampleStatisticsBounded_5] ON [dbo].[ExampleStatisticsBounded]([C5]) WITH FULLSCAN;
    CREATE STATISTICS [ST_ExampleStatisticsBounded_6] ON [dbo].[ExampleStatisticsBounded]([C6]) WITH FULLSCAN;

    CREATE PARTITION FUNCTION [PF_ExampleStatisticsIncremental](int)
        AS RANGE RIGHT FOR VALUES(100,200);
    CREATE PARTITION SCHEME [PS_ExampleStatisticsIncremental]
        AS PARTITION [PF_ExampleStatisticsIncremental] ALL TO ([PRIMARY]);
    CREATE TABLE [dbo].[ExampleStatisticsIncremental]
    (
          [PartitionValue] int NOT NULL
        , [DistributionValue] int NOT NULL
    ) ON [PS_ExampleStatisticsIncremental]([PartitionValue]);
    INSERT [dbo].[ExampleStatisticsIncremental]([PartitionValue],[DistributionValue])
    SELECT CASE WHEN [NumberValue]<=100 THEN 1
                WHEN [NumberValue]<=200 THEN 150 ELSE 250 END,
           [NumberValue]
    FROM [#P1_Statistics_Runtime_Contract_Numbers]
    WHERE [NumberValue]<=300;
    CREATE STATISTICS [ST_ExampleStatisticsIncremental]
        ON [dbo].[ExampleStatisticsIncremental]([DistributionValue])
        WITH FULLSCAN,INCREMENTAL=ON;
    INSERT [dbo].[ExampleStatisticsIncremental]([PartitionValue],[DistributionValue])
    SELECT 250,1000+[NumberValue]
    FROM [#P1_Statistics_Runtime_Contract_Numbers]
    WHERE [NumberValue]<=100;

    /* STAT-UNIFORM: sichtbares, begrenztes und annähernd gleichmäßiges Histogramm. */
    EXEC [monitor].[USP_StatisticsDistributionAnalysis]
         @DatabaseNames=N'[DeineDatenbank]',@SchemaNames=N'dbo',
         @ObjectNames=N'ExampleStatisticsUniform',
         @StatisticsNames=N'ST_ExampleStatisticsUniform',@AnalyseModus='GEZIELT',
         @MaxVerteilungsStatistiken=5,@MinVerteilungsZeilen=100,
         @SkewWarnFaktor=10,@DominanterSchrittWarnPercent=50,
         @ModificationWarnPercent=100,@PartitionSpreadWarnPercent=100,
         @MaxZeilen=0,@ResultSetArt='NONE',
         @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
         @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
         @HighImpactConfirmed=1;
    IF ISJSON(@Json)<>1 OR @Status<>'AVAILABLE'
       OR NOT EXISTS
          (SELECT 1
           FROM OPENJSON(@Json,N'$.distribution')
           WITH ([ObjectName] sysname N'$.ObjectName',[HistogramSteps] int N'$.HistogramSteps',
                 [DominantStepPercent] decimal(19,4) N'$.DominantStepPercent',
                 [TailVsAverageStepRatio] decimal(19,4) N'$.TailVsAverageStepRatio',
                 [AnalysisState] varchar(40) N'$.AnalysisState')
           WHERE [ObjectName]=N'ExampleStatisticsUniform'
             AND [HistogramSteps]>0
             AND [AnalysisState]='EVIDENCE_AVAILABLE')
       OR EXISTS
          (SELECT 1
           FROM OPENJSON(@Json,N'$.findings')
           WITH ([ObjectName] sysname N'$.ObjectName',[FindingCode] varchar(120) N'$.FindingCode')
           WHERE [ObjectName]=N'ExampleStatisticsUniform'
             AND [FindingCode] IN('DOMINANT_HISTOGRAM_STEP_REVIEW','EQUALITY_FREQUENCY_SKEW_REVIEW',
                                  'RANGE_DENSITY_SKEW_REVIEW','TAIL_CONCENTRATION_REVIEW'))
        THROW 54900,N'P1-Vertrag STAT-UNIFORM fehlgeschlagen.',1;
    INSERT @ExecutedCases VALUES('STAT-UNIFORM');

    /* STAT-DOMINANT: ein Schritt enthält den überwiegenden Zeilenanteil. */
    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL; SET @StatError=NULL;
    EXEC [monitor].[USP_StatisticsDistributionAnalysis]
         @DatabaseNames=N'[DeineDatenbank]',@SchemaNames=N'dbo',
         @ObjectNames=N'ExampleStatisticsDominant',
         @StatisticsNames=N'ST_ExampleStatisticsDominant',@AnalyseModus='GEZIELT',
         @MaxVerteilungsStatistiken=5,@MinVerteilungsZeilen=100,
         @SkewWarnFaktor=100000,@DominanterSchrittWarnPercent=50,
         @ModificationWarnPercent=100,@PartitionSpreadWarnPercent=100,
         @MaxZeilen=0,@ResultSetArt='NONE',
         @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
         @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
         @HighImpactConfirmed=1,@ErrorNumberOut=@StatError OUTPUT;
    IF ISJSON(@Json)<>1 OR @Status<>'AVAILABLE_WITH_FINDING'
       OR NOT EXISTS
          (SELECT 1
           FROM OPENJSON(@Json,N'$.findings')
           WITH ([ObjectName] sysname N'$.ObjectName',[FindingCode] varchar(120) N'$.FindingCode',
                 [MetricValue] decimal(38,4) N'$.MetricValue',[ThresholdValue] decimal(38,4) N'$.ThresholdValue')
           WHERE [ObjectName]=N'ExampleStatisticsDominant'
             AND [FindingCode]='DOMINANT_HISTOGRAM_STEP_REVIEW'
             AND [MetricValue]>=50 AND [ThresholdValue]=50)
    BEGIN
        BEGIN TRY
            EXEC [sys].[sp_executesql] @StatDiagnostic,@StatParameters,@Json,@Status,@Partial,@StatError,@StatLine OUTPUT;
        END TRY
        BEGIN CATCH
            SET @StatLine=CONCAT(N'Error: STAT_DOMINANT_FAILURE diagError=',ERROR_NUMBER());
        END CATCH;
        RAISERROR(N'%s',10,1,@StatLine) WITH NOWAIT;
        THROW 54901,N'P1-Vertrag STAT-DOMINANT fehlgeschlagen.',1;
    END;
    INSERT @ExecutedCases VALUES('STAT-DOMINANT');

    /* STAT-TAIL: der letzte Histogrammschritt ist gegenüber dem Durchschnitt konzentriert. */
    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL;
    EXEC [monitor].[USP_StatisticsDistributionAnalysis]
         @DatabaseNames=N'[DeineDatenbank]',@SchemaNames=N'dbo',
         @ObjectNames=N'ExampleStatisticsTail',
         @StatisticsNames=N'ST_ExampleStatisticsTail',@AnalyseModus='GEZIELT',
         @MaxVerteilungsStatistiken=5,@MinVerteilungsZeilen=100,
         @SkewWarnFaktor=10,@DominanterSchrittWarnPercent=100,
         @ModificationWarnPercent=100,@PartitionSpreadWarnPercent=100,
         @MaxZeilen=0,@ResultSetArt='NONE',
         @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
         @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
         @HighImpactConfirmed=1;
    IF ISJSON(@Json)<>1 OR @Status<>'AVAILABLE_WITH_FINDING'
       OR NOT EXISTS
          (SELECT 1
           FROM OPENJSON(@Json,N'$.findings')
           WITH ([ObjectName] sysname N'$.ObjectName',[FindingCode] varchar(120) N'$.FindingCode',
                 [MetricValue] decimal(38,4) N'$.MetricValue',[ThresholdValue] decimal(38,4) N'$.ThresholdValue')
           WHERE [ObjectName]=N'ExampleStatisticsTail'
             AND [FindingCode]='TAIL_CONCENTRATION_REVIEW'
             AND [MetricValue]>=10 AND [ThresholdValue]=10)
        THROW 54902,N'P1-Vertrag STAT-TAIL fehlgeschlagen.',1;
    INSERT @ExecutedCases VALUES('STAT-TAIL');

    /* STAT-MODIFIED: Modification Counter bleibt Wertverteilungs-Evidenzgrenze. */
    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL;
    EXEC [monitor].[USP_StatisticsDistributionAnalysis]
         @DatabaseNames=N'[DeineDatenbank]',@SchemaNames=N'dbo',
         @ObjectNames=N'ExampleStatisticsModified',
         @StatisticsNames=N'ST_ExampleStatisticsModified',@AnalyseModus='GEZIELT',
         @MaxVerteilungsStatistiken=5,@MinVerteilungsZeilen=100,
         @SkewWarnFaktor=100000,@DominanterSchrittWarnPercent=100,
         @ModificationWarnPercent=20,@PartitionSpreadWarnPercent=100,
         @MaxZeilen=0,@ResultSetArt='NONE',
         @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
         @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
         @HighImpactConfirmed=1;
    IF ISJSON(@Json)<>1 OR @Status<>'AVAILABLE_WITH_FINDING'
       OR NOT EXISTS
          (SELECT 1
           FROM OPENJSON(@Json,N'$.findings')
           WITH ([ObjectName] sysname N'$.ObjectName',[FindingCode] varchar(120) N'$.FindingCode',
                 [MetricValue] decimal(38,4) N'$.MetricValue',[ThresholdValue] decimal(38,4) N'$.ThresholdValue')
           WHERE [ObjectName]=N'ExampleStatisticsModified'
             AND [FindingCode]='OUT_OF_RANGE_NOT_MEASURABLE_REVIEW'
             AND [MetricValue]>=20 AND [ThresholdValue]=20)
        THROW 54903,N'P1-Vertrag STAT-MODIFIED fehlgeschlagen.',1;
    INSERT @ExecutedCases VALUES('STAT-MODIFIED');

    /* STAT-FILTERED: Filterstatus wird ausgewiesen, ohne Eignungsurteil. */
    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL;
    EXEC [monitor].[USP_StatisticsDistributionAnalysis]
         @DatabaseNames=N'[DeineDatenbank]',@SchemaNames=N'dbo',
         @ObjectNames=N'ExampleStatisticsFiltered',
         @StatisticsNames=N'ST_ExampleStatisticsFiltered',@AnalyseModus='GEZIELT',
         @MaxVerteilungsStatistiken=5,@MinVerteilungsZeilen=100,
         @SkewWarnFaktor=100000,@DominanterSchrittWarnPercent=100,
         @ModificationWarnPercent=100,@PartitionSpreadWarnPercent=100,
         @MaxZeilen=0,@ResultSetArt='NONE',
         @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
         @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
         @HighImpactConfirmed=1;
    IF ISJSON(@Json)<>1 OR @Status<>'AVAILABLE'
       OR NOT EXISTS
          (SELECT 1
           FROM OPENJSON(@Json,N'$.distribution')
           WITH ([ObjectName] sysname N'$.ObjectName',[StatisticsName] sysname N'$.StatisticsName',
                 [Rows] bigint N'$.Rows',[IsFiltered] bit N'$.IsFiltered',
                 [AnalysisState] varchar(40) N'$.AnalysisState',[EvidenceLimit] nvarchar(1000) N'$.EvidenceLimit')
           WHERE [ObjectName]=N'ExampleStatisticsFiltered'
             AND [StatisticsName]=N'ST_ExampleStatisticsFiltered'
             AND [Rows]=1000 AND [IsFiltered]=1
             AND [AnalysisState]='EVIDENCE_AVAILABLE'
             AND NULLIF([EvidenceLimit],N'') IS NOT NULL)
        THROW 54904,N'P1-Vertrag STAT-FILTERED fehlgeschlagen.',1;
    INSERT @ExecutedCases VALUES('STAT-FILTERED');

    /* STAT-INCREMENTAL: unterschiedliche Änderungsanteile bleiben getrennte Partitions-Evidenz. */
    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL;
    EXEC [monitor].[USP_StatisticsDistributionAnalysis]
         @DatabaseNames=N'[DeineDatenbank]',@SchemaNames=N'dbo',
         @ObjectNames=N'ExampleStatisticsIncremental',
         @StatisticsNames=N'ST_ExampleStatisticsIncremental',@AnalyseModus='GEZIELT',
         @MaxVerteilungsStatistiken=5,@MinVerteilungsZeilen=100,
         @SkewWarnFaktor=100000,@DominanterSchrittWarnPercent=100,
         @ModificationWarnPercent=100,@PartitionSpreadWarnPercent=20,
         @MaxZeilen=0,@ResultSetArt='NONE',
         @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
         @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
         @HighImpactConfirmed=1;
    IF ISJSON(@Json)<>1 OR @Status<>'AVAILABLE_WITH_FINDING'
       OR NOT EXISTS
          (SELECT 1
           FROM OPENJSON(@Json,N'$.partitionVariation')
           WITH ([ObjectName] sysname N'$.ObjectName',[StatisticsName] sysname N'$.StatisticsName',
                 [PartitionCount] int N'$.PartitionCount',
                 [ModificationSpreadPercentPoints] decimal(19,4) N'$.ModificationSpreadPercentPoints')
           WHERE [ObjectName]=N'ExampleStatisticsIncremental'
             AND [StatisticsName]=N'ST_ExampleStatisticsIncremental'
             AND [PartitionCount]>=3 AND [ModificationSpreadPercentPoints]>=20)
       OR NOT EXISTS
          (SELECT 1
           FROM OPENJSON(@Json,N'$.findings')
           WITH ([ObjectName] sysname N'$.ObjectName',[FindingCode] varchar(120) N'$.FindingCode')
           WHERE [ObjectName]=N'ExampleStatisticsIncremental'
             AND [FindingCode]='PARTITION_MODIFICATION_SKEW_REVIEW')
        THROW 54905,N'P1-Vertrag STAT-INCREMENTAL fehlgeschlagen.',1;
    INSERT @ExecutedCases VALUES('STAT-INCREMENTAL');

    /* STAT-BOUNDED: vor Histogrammzugriff bleiben höchstens zwei Kandidaten. */
    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL;
    EXEC [monitor].[USP_StatisticsDistributionAnalysis]
         @DatabaseNames=N'[DeineDatenbank]',@SchemaNames=N'dbo',
         @ObjectNames=N'ExampleStatisticsBounded',@AnalyseModus='GEZIELT',
         @MaxVerteilungsStatistiken=2,@MinVerteilungsZeilen=0,
         @SkewWarnFaktor=100000,@DominanterSchrittWarnPercent=100,
         @ModificationWarnPercent=100,@PartitionSpreadWarnPercent=100,
         @MaxZeilen=0,@ResultSetArt='NONE',
         @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
         @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
         @HighImpactConfirmed=1;
    IF ISJSON(@Json)<>1 OR @Status NOT IN('AVAILABLE','AVAILABLE_WITH_FINDING')
       OR TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.distributionCount'))<>2
       OR EXISTS
          (SELECT 1
           FROM OPENJSON(@Json,N'$.databaseStatus')
           WITH ([DatabaseName] sysname N'$.DatabaseName',[CandidateCount] bigint N'$.CandidateCount',
                 [HistogramVisibleCount] bigint N'$.HistogramVisibleCount')
           WHERE [DatabaseName]=(SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID())
             AND ([CandidateCount]<>2 OR [HistogramVisibleCount]>2))
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.distribution'))<>2
        THROW 54906,N'P1-Vertrag STAT-BOUNDED fehlgeschlagen.',1;
    INSERT @ExecutedCases VALUES('STAT-BOUNDED');

    /* STAT-DENIED: aktives CATALOG_DEEP-Gate verweigert einem nicht passenden User den Zugriff. */
    IF USER_ID(N'ExampleStatisticsDeniedUser') IS NOT NULL
        THROW 54907,N'Der synthetische Principal für STAT-DENIED ist bereits vorhanden.',1;

    BEGIN TRANSACTION;
    BEGIN TRY
        EXEC(N'CREATE OR ALTER VIEW [monitor].[VW_AnalyseAccessPolicy]
AS
SELECT [p].[AnalysisClass],[p].[ADGroupName],[p].[IsEnabled],[p].[ValidFromUtc],
       [p].[ValidToUtc],[p].[Priority],[p].[Comment]
FROM
(
    VALUES
    (
        CAST(''CATALOG_DEEP'' AS varchar(64)),
        CAST(N''ExampleStatisticsAllowedGroup'' AS nvarchar(256)),
        CAST(1 AS bit),CAST(NULL AS datetime2(0)),CAST(NULL AS datetime2(0)),
        CAST(100 AS smallint),CAST(N''Synthetic statistics permission contract'' AS nvarchar(1000))
    )
) AS [p]([AnalysisClass],[ADGroupName],[IsEnabled],[ValidFromUtc],[ValidToUtc],[Priority],[Comment]);');

        CREATE USER [ExampleStatisticsDeniedUser] WITHOUT LOGIN;
        GRANT EXECUTE ON OBJECT::[monitor].[USP_StatisticsDistributionAnalysis]
            TO [ExampleStatisticsDeniedUser];
        GRANT SELECT ON OBJECT::[monitor].[VW_AnalyseAccessCurrent]
            TO [ExampleStatisticsDeniedUser];

        SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL;
        EXECUTE AS USER=N'ExampleStatisticsDeniedUser';
        SET @Impersonating=1;
        EXEC [monitor].[USP_StatisticsDistributionAnalysis]
             @DatabaseNames=N'[DeineDatenbank]',@SchemaNames=N'dbo',
             @ObjectNames=N'ExampleStatisticsUniform',
             @StatisticsNames=N'ST_ExampleStatisticsUniform',@AnalyseModus='GEZIELT',
             @MaxVerteilungsStatistiken=1,@MinVerteilungsZeilen=0,
             @MaxZeilen=0,@ResultSetArt='NONE',
             @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
             @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
             @HighImpactConfirmed=1;
        REVERT;
        SET @Impersonating=0;
        IF ISJSON(@Json)<>1 OR @Status<>'DENIED_GROUP' OR @Partial<>1
           OR NOT EXISTS
              (SELECT 1
               FROM OPENJSON(@Json,N'$.databaseStatus')
               WITH ([StatusCode] varchar(40) N'$.StatusCode')
               WHERE [StatusCode]='DENIED_GROUP')
            THROW 54908,N'P1-Vertrag STAT-DENIED fehlgeschlagen.',1;

        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @Impersonating=1
        BEGIN
            BEGIN TRY
                REVERT;
                SET @Impersonating=0;
            END TRY
            BEGIN CATCH
            END CATCH;
        END;
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
    INSERT @ExecutedCases VALUES('STAT-DENIED');

    DROP TABLE [dbo].[ExampleStatisticsIncremental];
    DROP PARTITION SCHEME [PS_ExampleStatisticsIncremental];
    DROP PARTITION FUNCTION [PF_ExampleStatisticsIncremental];
    DROP TABLE [dbo].[ExampleStatisticsBounded];
    DROP TABLE [dbo].[ExampleStatisticsFiltered];
    DROP TABLE [dbo].[ExampleStatisticsModified];
    DROP TABLE [dbo].[ExampleStatisticsTail];
    DROP TABLE [dbo].[ExampleStatisticsDominant];
    DROP TABLE [dbo].[ExampleStatisticsUniform];
END TRY
BEGIN CATCH
    IF @Impersonating=1
    BEGIN
        BEGIN TRY
            REVERT;
        END TRY
        BEGIN CATCH
        END CATCH;
    END;
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;

    BEGIN TRY
        DROP TABLE IF EXISTS [dbo].[ExampleStatisticsIncremental];
        DROP TABLE IF EXISTS [dbo].[ExampleStatisticsBounded];
        DROP TABLE IF EXISTS [dbo].[ExampleStatisticsFiltered];
        DROP TABLE IF EXISTS [dbo].[ExampleStatisticsModified];
        DROP TABLE IF EXISTS [dbo].[ExampleStatisticsTail];
        DROP TABLE IF EXISTS [dbo].[ExampleStatisticsDominant];
        DROP TABLE IF EXISTS [dbo].[ExampleStatisticsUniform];
        IF EXISTS(SELECT 1 FROM [sys].[partition_schemes] WITH (NOLOCK) WHERE [name]=N'PS_ExampleStatisticsIncremental')
            DROP PARTITION SCHEME [PS_ExampleStatisticsIncremental];
        IF EXISTS(SELECT 1 FROM [sys].[partition_functions] WITH (NOLOCK) WHERE [name]=N'PF_ExampleStatisticsIncremental')
            DROP PARTITION FUNCTION [PF_ExampleStatisticsIncremental];
    END TRY
    BEGIN CATCH
    END CATCH;
    THROW;
END CATCH;

IF (SELECT COUNT_BIG(*) FROM @ExecutedCases)<>8
    THROW 54909,N'Der P1-Statistikverteilungsvertrag hat nicht alle vorgesehenen Fälle ausgeführt.',1;

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],CAST(0 AS bit) AS [IsPartial],
       COUNT_BIG(*) AS [ExecutedCases],
       N'Acht synthetische P1-Statistikverteilungsfälle wurden vollständig bereinigt.' AS [Detail]
FROM @ExecutedCases;
GO

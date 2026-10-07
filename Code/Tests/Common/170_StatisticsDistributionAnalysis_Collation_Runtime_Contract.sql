USE [DeineDatenbank];
GO

/*
P3: Allgemeine Fälle prüfen den bestehenden Ausgabe- und Parametervertrag.
Die positive Gegenprobe liest ausschließlich eine vorbereitete synthetische
Statistikfixture. Sie erzeugt keine Datenbank, Tabelle, Statistik oder Daten.
Ohne Fixture bleibt dieser Block NOT_EXECUTED. Leere Mengen belegen nur
Limitakzeptanz. Positive RAW-/CONSOLE-Zeilenparität benötigt Clientcapture,
da der untergeordnete Katalogaufruf zusätzliche Probegrids ausgeben kann.
*/
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM master.sys.databases WHERE database_id=DB_ID());
DECLARE @SourceName nvarchar(128)=N'ExampleStatsSourceÄ🔬';
DECLARE @SourceId int,@SourceLevel int,@FixtureStatus varchar(24)='NOT_EXECUTED';
DECLARE @MissingName nvarchar(128)=N'ExampleMissingStatisticsDistributionÄ';
DECLARE @FrameworkName nvarchar(128)=DB_NAME();
DECLARE @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@EmptyConsoleCases int=0,@DirectConsoleCases int=0;
IF @FrameworkLevel NOT IN(150,160,170) OR @FrameworkLevel IS NULL
 THROW 57200,N'Framework compatibility level is outside the portable contract.',1;
IF CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation'))<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 57201,N'Framework collation is outside the guaranteed contract.',1;
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=@MissingName COLLATE SQL_Latin1_General_CP1_CS_AS)
 THROW 57202,N'Synthetic missing database identifier already exists.',1;
SELECT @SourceId=database_id,@SourceLevel=compatibility_level FROM master.sys.databases
WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=@SourceName COLLATE SQL_Latin1_General_CP1_CS_AS;

/* Unabhängig festgelegte öffentliche 14-Feld-Form, elf Texte, keine Identity. */
CREATE TABLE #ExampleDistributionSchema
(
 [FindingOrdinal] bigint NOT NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [StatisticsName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [MetricValue] decimal(38,4) NULL,[ThresholdValue] decimal(38,4) NULL,
 [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
CREATE TABLE #ExampleDistributionNative
(
 [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ObjectId] int NOT NULL,[StatisticsName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatisticsId] int NOT NULL,
 [LeadingColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [LeadingTypeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [Rows] bigint NOT NULL,[RowsSampled] bigint NOT NULL,[ModificationCounter] bigint NOT NULL,
 [HistogramSteps] int NOT NULL,[HistogramEstimatedRows] decimal(38,4) NOT NULL,
 [MaxEqualRows] decimal(38,4) NULL,[MaxRangeRows] decimal(38,4) NULL,[MaxStepRows] decimal(38,4) NULL,
 [DominantStepPercent] decimal(19,4) NULL,[EqualRowsSkewRatio] decimal(19,4) NULL,
 [AverageRangeRowsSkewRatio] decimal(19,4) NULL,[TailStepRows] decimal(38,4) NULL,
 [TailStepPercent] decimal(19,4) NULL,[TailVsAverageStepRatio] decimal(19,4) NULL,
 [ModificationPercent] decimal(19,4) NULL,
 [SamplePercent] decimal(9,4) NULL,[DaysSinceLastUpdate] int NULL,
 [IsFiltered] bit NOT NULL,[IsIncremental] bit NOT NULL,[HasPersistedSample] bit NOT NULL,[PersistedSamplePercent] float NULL
);
SELECT TOP(0) * INTO #ExampleDistributionExpected FROM #ExampleDistributionSchema;
CREATE TABLE #ExampleDistributionEmptyConsole
([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleDistributionPreflight([Dummy] int NULL);
CREATE TABLE #ExampleDistributionCases
([CaseNumber] int NOT NULL,[IsNative] bit NOT NULL,[Names] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [Objects] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Statistics] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [MaxRows] int NULL,[MinRows] bigint NULL,[Skew] decimal(19,4) NULL,[Dominant] decimal(9,4) NULL,[Modification] decimal(9,4) NULL,
 [Mode] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[MaxStats] int NULL,[ExpectedInvalid] bit NOT NULL,[Missing] bit NOT NULL);
INSERT #ExampleDistributionCases VALUES
 (0,0,QUOTENAME(@FrameworkName),N'[ExampleMissingDistributionObjectÄ]',NULL,NULL,0,1,0,0,'GEZIELT',2,0,0),
 (1,0,QUOTENAME(@FrameworkName),N'[ExampleMissingDistributionObjectÄ]',NULL,0,0,1,0,0,'GEZIELT',2,0,0),
 (2,0,QUOTENAME(@FrameworkName),N'[ExampleMissingDistributionObjectÄ]',NULL,1,0,1,0,0,'GEZIELT',2,0,0),
 (3,0,QUOTENAME(@FrameworkName),N'[ExampleMissingDistributionObjectÄ]',NULL,-1,0,1,0,0,'GEZIELT',2,1,0),
 (4,0,QUOTENAME(@FrameworkName),N'[ExampleMissingDistributionObjectÄ]',NULL,0,NULL,1,0,0,'GEZIELT',2,1,0),
 (5,0,QUOTENAME(@FrameworkName),N'[ExampleMissingDistributionObjectÄ]',NULL,0,0,0,0,0,'GEZIELT',2,1,0),
 (6,0,QUOTENAME(@FrameworkName),N'[ExampleMissingDistributionObjectÄ]',NULL,0,0,1,101,0,'GEZIELT',2,1,0),
 (7,0,QUOTENAME(@FrameworkName),N'[ExampleMissingDistributionObjectÄ]',NULL,0,0,1,0,0,'EXAMPLE',2,1,0),
 (8,0,QUOTENAME(@FrameworkName),N'[ExampleMissingDistributionObjectÄ]',NULL,0,0,1,0,0,'GEZIELT',0,1,0),
 (9,0,QUOTENAME(@MissingName),N'[ExampleMissingDistributionObjectÄ]',NULL,0,0,1,0,0,'GEZIELT',2,0,1),
 (10,0,QUOTENAME(@FrameworkName)+N'|'+QUOTENAME(@MissingName),N'[ExampleMissingDistributionObjectÄ]',NULL,0,0,1,0,0,'GEZIELT',2,0,1);

DECLARE @Sql nvarchar(max),@Json nvarchar(max),@TableJson nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048);
DECLARE @Case int=-1,@Native bit,@Names nvarchar(max),@Objects nvarchar(max),@Statistics nvarchar(max),@Max int,@Min bigint,@Skew decimal(19,4),@Dominant decimal(9,4),@Modification decimal(9,4),@Mode varchar(16),@MaxStats int,@Invalid bit,@Missing bit;
DECLARE @Before datetime2(3),@After datetime2(3),@ExpectedCount int,@ActualCount int;
BEGIN TRY
 IF @SourceId IS NOT NULL
 BEGIN
  IF @SourceLevel<>@FrameworkLevel OR (SELECT collation_name FROM master.sys.databases WHERE database_id=@SourceId)<>N'Latin1_General_100_CI_AS'
   THROW 57203,N'Prepared source identity collation or independently measured compatibility level disagrees.',1;
  SET @Sql=N'USE '+QUOTENAME(@SourceName)+N';
INSERT #ExampleDistributionNative
SELECT o.name,o.object_id,s.name,s.stats_id,c.name,t.name,p.rows,p.rows_sampled,p.modification_counter,
 h.Steps,h.Estimated,h.MaxEqual,h.MaxRange,h.MaxStep,
 CONVERT(decimal(19,4),CONVERT(float,h.MaxStep)*100/NULLIF(CONVERT(float,h.Estimated),0)),
 CONVERT(decimal(19,4),CONVERT(float,h.MaxEqual)/NULLIF(CONVERT(float,h.MeanEqual),0)),
 CONVERT(decimal(19,4),CONVERT(float,h.MaxAverageRange)/NULLIF(CONVERT(float,h.MeanRange),0)),
 tail.StepRows,CONVERT(decimal(19,4),CONVERT(float,tail.StepRows)*100/NULLIF(CONVERT(float,h.Estimated),0)),
 CONVERT(decimal(19,4),CONVERT(float,tail.StepRows)/NULLIF(CONVERT(float,h.Estimated)/NULLIF(CONVERT(float,h.Steps),0),0)),
 CONVERT(decimal(19,4),p.modification_counter*100.0/NULLIF(p.rows,0)),
 CONVERT(decimal(9,4),p.rows_sampled*100.0/NULLIF(p.rows,0)),DATEDIFF(DAY,p.last_updated,SYSDATETIME()),s.has_filter,s.is_incremental,s.has_persisted_sample,p.persisted_sample_percent
FROM sys.objects o JOIN sys.schemas sc ON sc.schema_id=o.schema_id
JOIN sys.stats s ON s.object_id=o.object_id
JOIN sys.stats_columns k ON k.object_id=s.object_id AND k.stats_id=s.stats_id AND k.stats_column_id=1
JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id
JOIN sys.types t ON t.user_type_id=c.user_type_id
CROSS APPLY sys.dm_db_stats_properties(s.object_id,s.stats_id) p
CROSS APPLY(SELECT COUNT(*) Steps,SUM(CONVERT(decimal(38,4),COALESCE(equal_rows,0))+CONVERT(decimal(38,4),COALESCE(range_rows,0))) Estimated,
 MAX(CONVERT(decimal(38,4),equal_rows)) MaxEqual,MAX(CONVERT(decimal(38,4),range_rows)) MaxRange,
 MAX(CONVERT(decimal(38,4),COALESCE(equal_rows,0))+CONVERT(decimal(38,4),COALESCE(range_rows,0))) MaxStep,
 AVG(NULLIF(CONVERT(decimal(38,4),equal_rows),0)) MeanEqual,
 MAX(CONVERT(decimal(38,4),average_range_rows)) MaxAverageRange,AVG(NULLIF(CONVERT(decimal(38,4),average_range_rows),0)) MeanRange
 FROM sys.dm_db_stats_histogram(s.object_id,s.stats_id)) h
CROSS APPLY(SELECT TOP(1) CONVERT(decimal(38,4),COALESCE(equal_rows,0))+CONVERT(decimal(38,4),COALESCE(range_rows,0)) StepRows FROM sys.dm_db_stats_histogram(s.object_id,s.stats_id) ORDER BY step_number DESC) tail
WHERE sc.name=N''dbo'' AND o.name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleSkewÄ🔬'',N''ExampleTailÄ🔬'') AND s.user_created=1;';
  EXEC sys.sp_executesql @Sql;
  IF (SELECT COUNT(*) FROM #ExampleDistributionNative)<>2
     OR (SELECT COUNT(DISTINCT ObjectId) FROM #ExampleDistributionNative)<>2
     OR EXISTS(SELECT 1 FROM #ExampleDistributionNative WHERE LeadingColumnName<>N'DistributionValue' OR LeadingTypeName<>N'int' OR (ObjectName=N'ExampleSkewÄ🔬' AND StatisticsName<>N'ExampleStatsÄ''🔬') OR (ObjectName=N'ExampleTailÄ🔬' AND StatisticsName<>N'exampleStatsä''🔬'))
     OR EXISTS(SELECT 1 FROM #ExampleDistributionNative WHERE [Rows]<>RowsSampled OR [Rows]<=0 OR HistogramSteps<=0 OR HistogramEstimatedRows<>[Rows] OR ModificationCounter<>0)
   THROW 57204,N'Independent prepared fullscan histogram fixture is unavailable or mutable.',1;
  INSERT #ExampleDistributionCases
  SELECT 20+v.n,1,QUOTENAME(@SourceName),N'[ExampleSkewÄ🔬]|[ExampleTailÄ🔬]',NULL,v.Lim,v.MinRows,1,0,0,'GEZIELT',2,0,0
  FROM (VALUES(0,CONVERT(int,NULL),CONVERT(bigint,0)),(1,0,0),(2,1,0),(3,2,0),(4,1,1000000)) v(n,Lim,MinRows);
  INSERT #ExampleDistributionCases VALUES
   (25,1,QUOTENAME(@SourceName),N'[ExampleSkewÄ🔬]',NULL,0,0,1,0,0,'GEZIELT',2,0,0),
   (26,1,QUOTENAME(@SourceName),N'[exampleSkewÄ🔬]',NULL,0,0,1,0,0,'GEZIELT',2,0,0),
   (27,1,QUOTENAME(@SourceName)+N'|'+QUOTENAME(@MissingName),N'[ExampleSkewÄ🔬]|[ExampleTailÄ🔬]',NULL,1,0,1,0,0,'GEZIELT',2,0,1),
   (28,1,QUOTENAME(@SourceName),N'[ExampleSkewÄ🔬]|[ExampleTailÄ🔬]',N'[ExampleStatsÄ''🔬]',0,0,1,0,0,'GEZIELT',2,0,0),
   (29,1,QUOTENAME(@SourceName),N'[ExampleSkewÄ🔬]',N'[exampleStatsÄ''🔬]',0,0,1,0,0,'GEZIELT',2,0,0);
  SET @FixtureStatus='PASS';
 END;

 WHILE EXISTS(SELECT 1 FROM #ExampleDistributionCases WHERE CaseNumber>@Case)
 BEGIN
  SELECT TOP(1) @Case=CaseNumber,@Native=IsNative,@Names=Names,@Objects=Objects,@Statistics=[Statistics],@Max=MaxRows,@Min=MinRows,@Skew=Skew,@Dominant=Dominant,@Modification=Modification,@Mode=Mode,@MaxStats=MaxStats,@Invalid=ExpectedInvalid,@Missing=Missing
  FROM #ExampleDistributionCases WHERE CaseNumber>@Case ORDER BY CaseNumber;
  CREATE TABLE #ExampleDistributionExport([Dummy] int NULL);
  SET @Json=NULL;SET @Status=NULL;SET @Partial=NULL;SET @Before=SYSUTCDATETIME();
  EXEC monitor.USP_StatisticsDistributionAnalysis @DatabaseNames=@Names,@ObjectNames=@Objects,@StatisticsNames=@Statistics,@AnalyseModus=@Mode,
   @HighImpactConfirmed=1,@MaxVerteilungsStatistiken=@MaxStats,@MinVerteilungsZeilen=@Min,@SkewWarnFaktor=@Skew,@DominanterSchrittWarnPercent=@Dominant,@ModificationWarnPercent=@Modification,
   @MaxZeilen=@Max,@ResultSetArt='TABLE',@ResultTablesJson=N'{"findings":"#ExampleDistributionExport"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
   @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
  SET @After=SYSUTCDATETIME();
  IF ISNULL(ISJSON(@Json),0)<>1 OR @Status IS NULL OR @Partial IS NULL OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status OR ISNULL((SELECT CONVERT(int,p) FROM OPENJSON(@Json,N'$.meta') WITH(p bit N'$.isPartial')),-1)<>@Partial
   THROW 57205,N'JSON and caller status contract disagree.',1;
  IF EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json)
   EXCEPT SELECT * FROM (VALUES(N'meta',5),(N'databaseStatus',4),(N'distribution',4),(N'partitionVariation',4),(N'findings',4)) k(n,t))
   OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>5
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>9
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'StatisticsDistributionAnalysis'
   OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After
   THROW 57206,N'Five-key envelope metadata contract disagrees.',1;
  IF EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json,N'$.meta')
   EXCEPT SELECT * FROM (VALUES(N'resultName',1),(N'schemaVersion',2),(N'generatedAtUtc',1),(N'statusCode',1),(N'isPartial',3),(N'maxStatisticsPerDatabase',CASE WHEN @MaxStats IS NULL THEN 0 ELSE 2 END),(N'minimumDistributionRows',CASE WHEN @Min IS NULL THEN 0 ELSE 2 END),(N'distributionCount',2),(N'findingCount',2)) k(n,t))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') d WHERE (SELECT COUNT(*) FROM OPENJSON(d.value))<>9)
   THROW 57221,N'Metadata original JSON types or database status properties disagree.',1;
  IF @Native=0 AND (JSON_QUERY(@Json,N'$.findings')<>N'[]' OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.findingCount')),-1)<>0 OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.distributionCount')),-1)<>0)
   THROW 57222,N'General empty synthetic scope counters disagree; no positive limit effect is claimed.',1;
  IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleDistributionExport')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleDistributionSchema'))
   OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleDistributionSchema')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleDistributionExport'))
   OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleDistributionExport') AND collation_name=N'SQL_Latin1_General_CP1_CS_AS')<>11
   THROW 57207,N'Independent 14-field eleven-text nonidentity TABLE schema disagrees.',1;
  EXEC sys.sp_executesql N'SELECT @j=(SELECT * FROM #ExampleDistributionExport ORDER BY CASE Severity WHEN ''HIGH'' THEN 1 WHEN ''MEDIUM'' THEN 2 WHEN ''LOW'' THEN 3 ELSE 4 END,FindingOrdinal FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@j nvarchar(max) OUTPUT',@j=@TableJson OUTPUT;
  IF COALESCE(@TableJson,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.findings'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.findings') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>14)
   THROW 57208,N'Full TABLE JSON Findings parity including NULL properties disagrees.',1;
  SELECT @ActualCount=COUNT(*) FROM OPENJSON(@Json,N'$.findings');
  IF @Invalid=1 AND (@Status<>'INVALID_PARAMETER' OR @Partial<>1 OR @ActualCount<>0 OR JSON_QUERY(@Json,N'$.distribution')<>N'[]' OR JSON_QUERY(@Json,N'$.partitionVariation')<>N'[]')
   THROW 57209,N'Invalid input must return safe empty consumer schemas and INVALID_PARAMETER.',1;
  IF @Case=9 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH(DatabaseName nvarchar(128) N'$.DatabaseName',StatusCode varchar(40) N'$.StatusCode',IsPartial bit N'$.IsPartial') WHERE DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS=@MissingName COLLATE SQL_Latin1_General_CP1_CS_AS AND StatusCode='DATABASE_UNAVAILABLE' AND IsPartial=1)
   THROW 57210,N'Existing missing selection database status was lost.',1;
  IF @Case=9 AND (@Status<>'DATABASE_UNAVAILABLE' OR @Partial<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseStatus'))<>1)
   THROW 57210,N'Sole missing scope must retain its existing unavailable status.',1;
  /* Mixed selection inherits only the selected child scope, without a missing row. */
  IF @Case=10 AND (@Status<>'SKIPPED' OR @Partial<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseStatus'))<>1
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH(DatabaseName nvarchar(128),StatusCode varchar(40),IsPartial bit,CandidateCount bigint,HistogramVisibleCount bigint)
    WHERE DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS=@FrameworkName COLLATE SQL_Latin1_General_CP1_CS_AS AND StatusCode='AVAILABLE_LIMITED' AND IsPartial=1 AND CandidateCount=0 AND HistogramVisibleCount=0))
   THROW 57210,N'Existing mixed empty selected scope contract changed.',1;
  IF @Case IN(10,27) AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH(DatabaseName nvarchar(128)) WHERE DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS=@MissingName COLLATE SQL_Latin1_General_CP1_CS_AS)
   THROW 57210,N'Mixed selection must preserve the existing absence of a missing database status row.',1;
  IF @Native=1
  BEGIN
   TRUNCATE TABLE #ExampleDistributionExpected;
   /* Native identities and metrics predict the indicators independently of output. */
   INSERT #ExampleDistributionExpected
   SELECT 0,@SourceName,N'dbo',n.ObjectName,n.StatisticsName,'MEDIUM',v.Confidence,v.Code,v.Metric,v.[Value],v.Threshold,v.Evidence,
    N'Histogrammkennzahlen betreffen nur die erste Statistikspalte und den letzten materialisierten Statistikstand; sie enthalten keinen Query-/Prädikatkontext.',v.NextCheck
   FROM #ExampleDistributionNative n
   CROSS APPLY(VALUES
    ('MEDIUM','DOMINANT_HISTOGRAM_STEP_REVIEW','DominantStepPercent',CONVERT(decimal(38,4),n.DominantStepPercent),CONVERT(decimal(38,4),@Dominant),CONCAT(N'Der größte Histogrammschritt umfasst ',n.DominantStepPercent,N' Prozent der sichtbaren Histogrammzeilen.'),N'Mit tatsächlicher Prädikatselektivität, Kardinalitätsabweichung und Planvarianten korrelieren.'),
    ('MEDIUM','EQUALITY_FREQUENCY_SKEW_REVIEW','EqualRowsSkewRatio',CONVERT(decimal(38,4),n.EqualRowsSkewRatio),CONVERT(decimal(38,4),@Skew),CONCAT(N'Maximale Gleichheitsfrequenz zu durchschnittlicher positiver Gleichheitsfrequenz: Faktor ',n.EqualRowsSkewRatio,N'.'),N'Abfrageprädikate, Parameterwerte und geschätzte gegen tatsächliche Zeilen prüfen.'),
    ('MEDIUM','RANGE_DENSITY_SKEW_REVIEW','AverageRangeRowsSkewRatio',CONVERT(decimal(38,4),n.AverageRangeRowsSkewRatio),CONVERT(decimal(38,4),@Skew),CONCAT(N'Maximale zu durchschnittlicher positiver Range-Dichte: Faktor ',n.AverageRangeRowsSkewRatio,N'.'),N'Range-Prädikate und tatsächliche Kardinalitäten für diese führende Statistikspalte prüfen.'),
    ('LOW','TAIL_CONCENTRATION_REVIEW','TailVsAverageStepRatio',CONVERT(decimal(38,4),n.TailVsAverageStepRatio),CONVERT(decimal(38,4),@Skew),CONCAT(N'Letzter Histogrammschritt zu durchschnittlichem Schritt: Faktor ',n.TailVsAverageStepRatio,N'; Tail-Anteil ',n.TailStepPercent,N' Prozent.'),N'Zeitbezug, Insert-Muster und Querywerte prüfen; Tail-Konzentration beweist keine Ascending-Key-Problematik.'),
    ('LOW','OUT_OF_RANGE_NOT_MEASURABLE_REVIEW','ModificationPercent',CONVERT(decimal(38,4),n.ModificationPercent),CONVERT(decimal(38,4),@Modification),CONCAT(N'Seit dem Statistikstand wurden ',n.ModificationPercent,N' Prozent relativ zur sichtbaren Statistikzeilenzahl geändert.'),N'Neue Werte, Queryliterale und tatsächliche Kardinalitäten kontrolliert prüfen; der Modification Counter enthält keine Wertverteilung.')
   ) v(Confidence,Code,Metric,[Value],Threshold,Evidence,NextCheck)
   WHERE n.[Rows]>=@Min AND v.[Value]>=v.Threshold AND (@Case NOT IN(25,26,28,29) OR (@Case IN(25,28) AND n.ObjectName=N'ExampleSkewÄ🔬'));
   SELECT @ExpectedCount=COUNT(*) FROM #ExampleDistributionExpected;
   IF ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.findingCount')),-1)<>@ExpectedCount
      OR @ActualCount<>CASE WHEN @Max IS NULL OR @Max=0 THEN @ExpectedCount WHEN @Max<@ExpectedCount THEN @Max ELSE @ExpectedCount END
      OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.distributionCount')),-1)<>CASE WHEN @Case IN(26,29) THEN 0 WHEN @Case IN(25,28) THEN 1 ELSE 2 END
    THROW 57211,N'Native full counters or independent positive or empty output limits disagree.',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.distribution') d WHERE (SELECT COUNT(*) FROM OPENJSON(d.value))<>32)
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.distribution'))<>CASE WHEN @Max IS NULL OR @Max=0 THEN CASE WHEN @Case IN(26,29) THEN 0 WHEN @Case IN(25,28) THEN 1 ELSE 2 END WHEN @Case IN(26,29) THEN 0 WHEN @Max=1 THEN 1 ELSE 2 END
    OR JSON_QUERY(@Json,N'$.partitionVariation')<>N'[]'
    THROW 57218,N'Native nonincremental distribution shape or separate output limit disagrees.',1;
   SELECT * INTO #ExampleDistributionActualNative FROM OPENJSON(@Json,N'$.distribution') WITH
    (ObjectName nvarchar(128),ObjectId int,StatisticsName nvarchar(128),StatisticsId int,LeadingColumnName nvarchar(128),LeadingTypeName nvarchar(128),[Rows] bigint,RowsSampled bigint,ModificationCounter bigint,HistogramSteps int,HistogramEstimatedRows decimal(38,4),MaxEqualRows decimal(38,4),MaxRangeRows decimal(38,4),MaxStepRows decimal(38,4),DominantStepPercent decimal(19,4),EqualRowsSkewRatio decimal(19,4),AverageRangeRowsSkewRatio decimal(19,4),TailStepRows decimal(38,4),TailStepPercent decimal(19,4),TailVsAverageStepRatio decimal(19,4),ModificationPercent decimal(19,4),SamplePercent decimal(9,4),DaysSinceLastUpdate int,IsFiltered bit,IsIncremental bit,HasPersistedSample bit,PersistedSamplePercent float);
   IF EXISTS(SELECT ObjectName COLLATE SQL_Latin1_General_CP1_CS_AS,ObjectId,StatisticsName COLLATE SQL_Latin1_General_CP1_CS_AS,StatisticsId,LeadingColumnName COLLATE SQL_Latin1_General_CP1_CS_AS,LeadingTypeName COLLATE SQL_Latin1_General_CP1_CS_AS,[Rows],RowsSampled,ModificationCounter,HistogramSteps,HistogramEstimatedRows,MaxEqualRows,MaxRangeRows,MaxStepRows,DominantStepPercent,EqualRowsSkewRatio,AverageRangeRowsSkewRatio,TailStepRows,TailStepPercent,TailVsAverageStepRatio,ModificationPercent,SamplePercent,DaysSinceLastUpdate,IsFiltered,IsIncremental,HasPersistedSample,PersistedSamplePercent FROM #ExampleDistributionActualNative
    EXCEPT SELECT * FROM #ExampleDistributionNative)
    OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.distribution') WITH(DatabaseName nvarchar(128),SchemaName nvarchar(128),ObjectName nvarchar(128),CandidateOrdinal int,AnalysisState varchar(40),EvidenceLimit nvarchar(1000)) WHERE COALESCE(DatabaseName,N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>@SourceName COLLATE SQL_Latin1_General_CP1_CS_AS OR COALESCE(SchemaName,N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>N'dbo' OR CandidateOrdinal IS NULL OR COALESCE(AnalysisState,'')<>CASE WHEN @Min=1000000 THEN 'SMALL_HISTOGRAM_CONTEXT' ELSE 'EVIDENCE_AVAILABLE' END OR COALESCE(EvidenceLimit,N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>N'Histogrammkennzahlen betreffen nur die erste Statistikspalte und den letzten materialisierten Statistikstand; sie enthalten keinen Query-/Prädikatkontext.')
    THROW 57219,N'Independent native statistics identities and all histogram aggregations disagree.',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.distribution') WITH(ObjectName nvarchar(128),StatisticsName nvarchar(128),CandidateOrdinal int) a
    LEFT JOIN (SELECT ObjectName,StatisticsName,ROW_NUMBER() OVER(ORDER BY CASE WHEN IsIncremental=1 THEN 1 WHEN IsFiltered=1 THEN 2 ELSE 3 END,[Rows] DESC,ModificationPercent DESC,ObjectName,StatisticsName) ExpectedOrdinal
     FROM #ExampleDistributionNative WHERE @Case NOT IN(25,26,28,29) OR (@Case IN(25,28) AND ObjectName=N'ExampleSkewÄ🔬')) n
    ON a.ObjectName COLLATE SQL_Latin1_General_CP1_CS_AS=n.ObjectName AND a.StatisticsName COLLATE SQL_Latin1_General_CP1_CS_AS=n.StatisticsName
    WHERE n.ExpectedOrdinal IS NULL OR ISNULL(a.CandidateOrdinal,-1)<>n.ExpectedOrdinal)
    THROW 57224,N'Independent native candidate ranking disagrees.',1;
   IF (SELECT COUNT(*) FROM #ExampleDistributionActualNative)=(SELECT COUNT(*) FROM #ExampleDistributionNative)
    AND EXISTS(SELECT * FROM #ExampleDistributionNative EXCEPT SELECT * FROM #ExampleDistributionActualNative)
    THROW 57219,N'Full native statistics multiset disagrees.',1;
   DROP TABLE #ExampleDistributionActualNative;
   SELECT * INTO #ExampleDistributionActual FROM OPENJSON(@Json,N'$.findings') WITH
    (FindingOrdinal bigint,DatabaseName nvarchar(128),SchemaName nvarchar(128),ObjectName nvarchar(128),StatisticsName nvarchar(128),Severity varchar(16),Confidence varchar(16),FindingCode varchar(120),MetricName varchar(80),MetricValue decimal(38,4),ThresholdValue decimal(38,4),Evidence nvarchar(1000),EvidenceLimit nvarchar(1000),RecommendedNextCheck nvarchar(1000));
   IF EXISTS(SELECT 1 FROM #ExampleDistributionActual a WHERE FindingOrdinal<1 OR FindingOrdinal>@ExpectedCount
    OR NOT EXISTS(SELECT 1 FROM #ExampleDistributionExpected e WHERE a.DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS=e.DatabaseName AND a.SchemaName COLLATE SQL_Latin1_General_CP1_CS_AS=e.SchemaName AND a.ObjectName COLLATE SQL_Latin1_General_CP1_CS_AS=e.ObjectName AND a.StatisticsName COLLATE SQL_Latin1_General_CP1_CS_AS=e.StatisticsName AND a.Severity COLLATE SQL_Latin1_General_CP1_CS_AS=e.Severity AND a.Confidence COLLATE SQL_Latin1_General_CP1_CS_AS=e.Confidence AND a.FindingCode COLLATE SQL_Latin1_General_CP1_CS_AS=e.FindingCode AND a.MetricName COLLATE SQL_Latin1_General_CP1_CS_AS=e.MetricName AND a.MetricValue=e.MetricValue AND a.ThresholdValue=e.ThresholdValue AND a.Evidence COLLATE SQL_Latin1_General_CP1_CS_AS=e.Evidence AND a.EvidenceLimit COLLATE SQL_Latin1_General_CP1_CS_AS=e.EvidenceLimit AND a.RecommendedNextCheck COLLATE SQL_Latin1_General_CP1_CS_AS=e.RecommendedNextCheck))
    OR (SELECT COUNT(DISTINCT FindingOrdinal) FROM #ExampleDistributionActual)<>@ActualCount
    OR (@ActualCount>0 AND ((SELECT MIN(FindingOrdinal) FROM #ExampleDistributionActual)<>1 OR (SELECT MAX(FindingOrdinal) FROM #ExampleDistributionActual)<>@ActualCount))
    THROW 57212,N'Native full finding identities text metrics or preserved ordinals disagree.',1;
   IF EXISTS(SELECT ObjectName COLLATE SQL_Latin1_General_CP1_CS_AS,StatisticsName COLLATE SQL_Latin1_General_CP1_CS_AS,FindingCode COLLATE SQL_Latin1_General_CP1_CS_AS FROM #ExampleDistributionActual GROUP BY ObjectName COLLATE SQL_Latin1_General_CP1_CS_AS,StatisticsName COLLATE SQL_Latin1_General_CP1_CS_AS,FindingCode COLLATE SQL_Latin1_General_CP1_CS_AS HAVING COUNT(*)>1)
    OR (@ActualCount=@ExpectedCount AND EXISTS(SELECT DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS,SchemaName COLLATE SQL_Latin1_General_CP1_CS_AS,ObjectName COLLATE SQL_Latin1_General_CP1_CS_AS,StatisticsName COLLATE SQL_Latin1_General_CP1_CS_AS,Severity COLLATE SQL_Latin1_General_CP1_CS_AS,Confidence COLLATE SQL_Latin1_General_CP1_CS_AS,FindingCode COLLATE SQL_Latin1_General_CP1_CS_AS,MetricName COLLATE SQL_Latin1_General_CP1_CS_AS,MetricValue,ThresholdValue,Evidence COLLATE SQL_Latin1_General_CP1_CS_AS,EvidenceLimit COLLATE SQL_Latin1_General_CP1_CS_AS,RecommendedNextCheck COLLATE SQL_Latin1_General_CP1_CS_AS FROM #ExampleDistributionExpected EXCEPT SELECT DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS,SchemaName COLLATE SQL_Latin1_General_CP1_CS_AS,ObjectName COLLATE SQL_Latin1_General_CP1_CS_AS,StatisticsName COLLATE SQL_Latin1_General_CP1_CS_AS,Severity COLLATE SQL_Latin1_General_CP1_CS_AS,Confidence COLLATE SQL_Latin1_General_CP1_CS_AS,FindingCode COLLATE SQL_Latin1_General_CP1_CS_AS,MetricName COLLATE SQL_Latin1_General_CP1_CS_AS,MetricValue,ThresholdValue,Evidence COLLATE SQL_Latin1_General_CP1_CS_AS,EvidenceLimit COLLATE SQL_Latin1_General_CP1_CS_AS,RecommendedNextCheck COLLATE SQL_Latin1_General_CP1_CS_AS FROM #ExampleDistributionActual))
    THROW 57220,N'Independent full finding multiset or duplicate identities disagree.',1;
   IF @Case NOT IN(26,29) AND (@Status<>CASE WHEN @ExpectedCount>0 THEN 'AVAILABLE_WITH_FINDING' ELSE 'AVAILABLE' END OR @Partial<>0)
    THROW 57213,N'Full native status was changed by an output limit.',1;
   IF @Case NOT IN(26,29) AND (NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH(DatabaseName nvarchar(128),StatusCode varchar(40),IsPartial bit,CandidateCount bigint,HistogramVisibleCount bigint,ErrorNumber int,ErrorMessage nvarchar(2048)) WHERE DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS=@SourceName COLLATE SQL_Latin1_General_CP1_CS_AS AND StatusCode='AVAILABLE' AND IsPartial=0 AND CandidateCount=CASE WHEN @Case IN(25,28) THEN 1 ELSE 2 END AND HistogramVisibleCount=CASE WHEN @Case IN(25,28) THEN 1 ELSE 2 END AND ErrorNumber IS NULL AND ErrorMessage IS NULL)
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseStatus'))<>1)
    THROW 57223,N'Full successful selected source counters or status disagree.',1;
   IF @Case=27 AND (@Status<>'AVAILABLE_WITH_FINDING' OR @Partial<>0)
    THROW 57213,N'Existing positive mixed selection child status changed.',1;
   DROP TABLE #ExampleDistributionActual;
   SET @NativeCases+=1;
  END
  ELSE SET @CoreCases+=1;
  DROP TABLE #ExampleDistributionExport;
 END;

 /* Invalid parameters avoid child probegrids and permit SQL empty capture. */
 DECLARE @i int=0;
 WHILE @i<3
 BEGIN
  TRUNCATE TABLE #ExampleDistributionEmptyConsole;
  SET @Max=CASE @i WHEN 0 THEN NULL WHEN 1 THEN 0 ELSE 1 END;
  INSERT #ExampleDistributionEmptyConsole
  EXEC monitor.USP_StatisticsDistributionAnalysis @AnalyseModus='EXAMPLE',@MaxZeilen=@Max,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleDistributionEmptyConsole)<>1 OR EXISTS(SELECT 1 FROM #ExampleDistributionEmptyConsole WHERE Ergebnis<>N'Keine fachlichen Ergebnisse' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
   OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_QUERY(@Json,N'$.findings')<>N'[]'
   THROW 57214,N'Empty CONSOLE schema or invalid status disagrees.',1;
  SET @i+=1;SET @EmptyConsoleCases+=1;
 END;
 DECLARE @GenerateJson bit;
 SET @i=0;
 WHILE @i<2
 BEGIN
  SET @Mode=CASE @i WHEN 0 THEN 'NONE' ELSE 'RAW' END;SET @GenerateJson=CASE @i WHEN 0 THEN 1 ELSE 0 END;
  EXEC monitor.USP_StatisticsDistributionAnalysis @MaxZeilen=-1,@ResultSetArt=@Mode,@JsonErzeugen=@GenerateJson,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
  IF @Status<>'INVALID_PARAMETER' OR @Partial<>1 OR (@GenerateJson=1 AND (COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'INVALID_PARAMETER' OR COALESCE(JSON_QUERY(@Json,N'$.findings'),N'')<>N'[]')) OR (@GenerateJson=0 AND @Json IS NOT NULL)
   THROW 57215,N'Negative limit consumer must return INVALID_PARAMETER without TOP exception.',1;
  SET @i+=1;SET @ConsumerCases+=1;
 END;
 IF @FixtureStatus='PASS'
 BEGIN
  SET @i=0;
  WHILE @i<3
  BEGIN
   SET @Max=CASE @i WHEN 0 THEN NULL WHEN 1 THEN 1 ELSE 2 END;
   SET @Names=QUOTENAME(@SourceName);
   EXEC monitor.USP_StatisticsDistributionAnalysis @DatabaseNames=@Names,@ObjectNames=N'[ExampleSkewÄ🔬]|[ExampleTailÄ🔬]',@HighImpactConfirmed=1,@MaxVerteilungsStatistiken=2,@MinVerteilungsZeilen=0,@SkewWarnFaktor=1,@DominanterSchrittWarnPercent=0,@ModificationWarnPercent=0,@MaxZeilen=@Max,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
   IF @Status<>'AVAILABLE_WITH_FINDING' OR @Partial<>0 OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.findings'))<>CASE WHEN @Max IS NULL THEN TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.findingCount')) ELSE @Max END
    THROW 57216,N'Direct CONSOLE status or JSON count disagrees; rows require client capture.',1;
   SET @i+=1;SET @DirectConsoleCases+=1;
  END;
 END;
 DECLARE @Map nvarchar(max),@Caught int;
 SET @i=0;
 WHILE @i<5
 BEGIN
  SET @Map=CASE @i WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleDistributionPreflight"}' WHEN 2 THEN N'{"findings":"ExampleDistributionPreflight"}' WHEN 3 THEN N'{"findings":"#ExampleMissingDistributionTarget"}' ELSE N'{"findings":"#ExampleDistributionPreflight"}' END;
  SET @Mode=CASE WHEN @i=4 THEN 'NONE' ELSE 'TABLE' END;SET @Caught=NULL;
  BEGIN TRY
   EXEC monitor.USP_StatisticsDistributionAnalysis @AnalyseModus='EXAMPLE',@ResultSetArt=@Mode,@ResultTablesJson=@Map,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER(); END CATCH;
  IF ISNULL(@Caught,0)<>51011 THROW 57217,N'TABLE mapping preflight must retain error 51011.',1;
  SET @i+=1;SET @PreflightCases+=1;
 END;
 SELECT @FrameworkLevel [FrameworkCompatibilityLevel],@SourceLevel [SourceCompatibilityLevel],@CoreCases [CoreCases],@ConsumerCases [ConsumerCases],@PreflightCases [PreflightCases],@FixtureStatus [PositiveFixtureStatus],@NativeCases [NativeCases],@EmptyConsoleCases [EmptySqlConsoleCases],@DirectConsoleCases [DirectConsoleStatusCases];
END TRY
BEGIN CATCH
 THROW;
END CATCH;
GO

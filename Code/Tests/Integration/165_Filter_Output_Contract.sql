USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 165_Filter_Output_Contract.sql
Zweck        : Prüft zentrale Listen-, Pattern-, Ausgabe- und JSON-Verträge
               gegen eine installierte Frameworkinstanz. Der Test ist lesend;
               er begrenzt Datenbank-, Analyseobjekt- und Ergebnisumfang.
Voraussetzung: Vollständige Frameworkinstallation. SQL Server 2019 oder neuer.
Hinweis      : regex:/regexi: werden auf Servern unter SQL Server 2025 mit
               Compatibility Level 170 erwartungsgemäß als UNAVAILABLE_FEATURE
               geprüft. Der Test erzeugt keine dauerhaften Objekte.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET LOCK_TIMEOUT 5000;
GO

CREATE TABLE [#Failure]
(
      [TestName] sysname NOT NULL
    , [Detail] nvarchar(2048) NOT NULL
);

CREATE TABLE [#PublicProcedureResult]
(
      [ProcedureName] sysname NOT NULL
    , [TestStatus] varchar(16) NOT NULL
    , [JsonStatus] varchar(32) NULL
    , [ErrorNumber] int NULL
    , [ErrorMessage] nvarchar(2048) NULL
);

/* Bracket-aware Pipe-Listen: Trennung nur außerhalb von [ ... ]. */
IF (SELECT COUNT(*) FROM [monitor].[TVF_ParsePipeList](N'[A|B]|[C]]D]|E') WHERE [IsValid]=1) <> 3
    INSERT [#Failure] VALUES(N'TVF_ParsePipeList_valid',N'Gültige bracket-aware Pipe-Liste wurde nicht in drei Elemente zerlegt.');

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[TVF_ParsePipeList](N'[A|B]|[C]]D]|E')
    WHERE [ItemOrdinal]=1 AND [ItemText]=N'[A|B]' AND [IsBracketQuoted]=1 AND [IsValid]=1
)
    INSERT [#Failure] VALUES(N'TVF_ParsePipeList_bracket_pipe',N'Pipe innerhalb eines bracket-quotierten Elements wurde nicht erhalten.');

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[TVF_ParsePipeList](N'A||B')
    WHERE [ItemOrdinal]=2 AND [IsValid]=0 AND [ErrorCode]='EMPTY_ITEM'
)
    INSERT [#Failure] VALUES(N'TVF_ParsePipeList_empty_item',N'Leeres Pipe-Listenelement wurde nicht als ungültig erkannt.');

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[TVF_ParsePipeList](N'[A|B')
    WHERE [IsValid]=0 AND [ErrorCode]='INVALID_BRACKET_SYNTAX'
)
    INSERT [#Failure] VALUES(N'TVF_ParsePipeList_bracket_syntax',N'Nicht geschlossene Klammer wurde nicht als ungültig erkannt.');

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[TVF_ParseSqlNameList](N'[A|B]|[C]]D]')
    WHERE [ItemOrdinal]=1 AND [NameValue]=N'A|B' AND [IsValid]=1
)
    INSERT [#Failure] VALUES(N'TVF_ParseSqlNameList',N'Bracket-quotierter einteiliger SQL-Name wurde nicht korrekt entquotet.');

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[TVF_ParseFullObjectNameList](N'[ExampleDatabase].[dbo].[A|B]|[dbo].[C]')
    WHERE [ItemOrdinal]=1 AND [DatabaseName]=N'ExampleDatabase' AND [SchemaName]=N'dbo' AND [ObjectName]=N'A|B' AND [IsValid]=1
)
    INSERT [#Failure] VALUES(N'TVF_ParseFullObjectNameList',N'Dreiteiliger bracket-aware Objektname wurde nicht korrekt verarbeitet.');

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[TVF_ParseFullObjectNameList](N'[Server].[DeineDatenbank].[dbo].[Objekt]')
    WHERE [IsValid]=0 AND [ErrorCode]='FOUR_PART_NAME_NOT_ALLOWED'
)
    INSERT [#Failure] VALUES(N'TVF_ParseFullObjectNameList_four_part',N'Verbotener vierteiliger Objektname wurde nicht abgelehnt.');

/* Pattern-Präfixe sind case-insensitiv, der Patterninhalt bleibt unverändert. */
IF NOT EXISTS
(
    SELECT 1 FROM [monitor].[TVF_ParsePattern](N'LiKe:Ab_%')
    WHERE [PatternMode]='LIKE' AND [PatternValue]=N'Ab_%' AND [IsValid]=1
)
    INSERT [#Failure] VALUES(N'TVF_ParsePattern_like',N'LIKE-Pattern wurde nicht korrekt normalisiert.');

IF NOT EXISTS
(
    SELECT 1 FROM [monitor].[TVF_ParsePattern](N'ReGeX:^Ab.+$')
    WHERE [PatternMode]='REGEX' AND [RegexFlags]='c' AND [IsValid]=1
)
    INSERT [#Failure] VALUES(N'TVF_ParsePattern_regex',N'regex:-Pattern wurde nicht korrekt normalisiert.');

IF NOT EXISTS
(
    SELECT 1 FROM [monitor].[TVF_ParsePattern](N'ReGeXi:^ab.+$')
    WHERE [PatternMode]='REGEXI' AND [RegexFlags]='i' AND [IsValid]=1
)
    INSERT [#Failure] VALUES(N'TVF_ParsePattern_regexi',N'regexi:-Pattern wurde nicht korrekt normalisiert.');

IF NOT EXISTS
(
    SELECT 1 FROM [monitor].[TVF_ParsePattern](N'regex:')
    WHERE [IsValid]=0 AND [ErrorCode]='EMPTY_PATTERN'
)
    INSERT [#Failure] VALUES(N'TVF_ParsePattern_empty',N'Leeres Pattern nach Präfix wurde nicht abgelehnt.');

/* Repräsentative reale Consumer: exakte Listen, LIKE und Konfliktvalidierung. */
DECLARE @SelfSessionIds nvarchar(20)=CONVERT(nvarchar(20),@@SPID);
DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_CurrentSessions]
      @SessionIds=@SelfSessionIds
    , @AktuelleSessionEinbeziehen=1
    , @MaxZeilen=1
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0;
IF ISJSON(@Json)<>1
    INSERT [#Failure] VALUES(N'USP_CurrentSessions_exact_list',N'Exakte Sessionliste erzeugte kein gültiges JSON.');

SET @Json=NULL;
EXEC [monitor].[USP_CurrentSessions]
      @SessionIds=@SelfSessionIds
    , @LoginNamePattern=N'like:%'
    , @MaxZeilen=1
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0;
IF ISJSON(@Json)<>1
    INSERT [#Failure] VALUES(N'USP_CurrentSessions_like',N'LIKE-Filter erzeugte kein gültiges JSON.');

SET @Json=NULL;
EXEC [monitor].[USP_CurrentSessions]
      @LoginNames=N'[NoSuchLogin]'
    , @LoginNamePattern=N'like:%'
    , @MaxZeilen=1
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0;
IF JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER'
    INSERT [#Failure] VALUES(N'USP_CurrentSessions_list_pattern_conflict',N'Gleichzeitige exakte Liste und Pattern wurden nicht als INVALID_PARAMETER zurückgewiesen.');

SET @Json=NULL;
EXEC [monitor].[USP_CurrentWaits]
      @WaitTypes=N'[__MonitorTestWaitA]|[__MonitorTestWaitB]'
    , @MaxZeilen=1
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0;
IF ISJSON(@Json)<>1
    INSERT [#Failure] VALUES(N'USP_CurrentWaits_exact_list',N'Exakte Waitliste erzeugte kein gültiges JSON.');

SET @Json=NULL;
EXEC [monitor].[USP_CurrentWaits]
      @WaitTypePattern=N'like:__MonitorTestWait%'
    , @MaxZeilen=1
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0;
IF ISJSON(@Json)<>1
    INSERT [#Failure] VALUES(N'USP_CurrentWaits_like',N'LIKE-Waitfilter erzeugte kein gültiges JSON.');

SET @Json=NULL;
EXEC [monitor].[USP_CurrentWaits]
      @WaitTypePattern=N'regex:^__MonitorTestWait.*$'
    , @MaxZeilen=1
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0;
IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17
   AND JSON_VALUE(@Json,N'$.meta.statusCode')<>N'UNAVAILABLE_FEATURE'
    INSERT [#Failure] VALUES(N'USP_CurrentWaits_regex_version_fallback',N'Regex wurde auf einem Server vor SQL Server 2025 nicht als UNAVAILABLE_FEATURE ausgewiesen.');
IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))>=17 AND ISJSON(@Json)<>1
    INSERT [#Failure] VALUES(N'USP_CurrentWaits_regex',N'Regex-Waitfilter erzeugte kein gültiges JSON.');

SET @Json=NULL;
EXEC [monitor].[USP_CheckFrameworkCapabilities]
      @DatabaseNames=N''
    , @MaxDatenbanken=1
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0;
IF ISJSON(@Json)<>1
    INSERT [#Failure] VALUES(N'USP_CheckFrameworkCapabilities_database_scope',N'Aktueller Datenbankscope erzeugte kein gültiges JSON.');

SET @Json=NULL;
EXEC [monitor].[USP_CheckFrameworkCapabilities]
      @DatabaseNamePattern=N'like:%'
    , @MaxDatenbanken=1
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0;
IF ISJSON(@Json)<>1
    INSERT [#Failure] VALUES(N'USP_CheckFrameworkCapabilities_database_like',N'Datenbank-LIKE-Filter erzeugte kein gültiges JSON.');

/* Query Store: dynamische Regressionsermittlung muss ohne abgefangene SQL-Fehler laufen. */
SET @Json=NULL;
EXEC [monitor].[USP_QueryStoreRegressions]
      @QueryStoreDatabaseNames=N''
    , @MaxDatenbanken=1
    , @MaxZeilen=10
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0;
IF ISJSON(@Json)<>1
    INSERT [#Failure] VALUES(N'USP_QueryStoreRegressions_json',N'Query-Store-Regressionsanalyse erzeugte kein gültiges JSON.');
ELSE IF JSON_VALUE(@Json,N'$.meta.statusCode')=N'ERROR_HANDLED'
     OR EXISTS
     (
         SELECT 1
         FROM OPENJSON(@Json,N'$.warnings')
         WITH
         (
               [StatusCode] varchar(40) N'$.StatusCode'
             , [ErrorNumber] int N'$.ErrorNumber'
         ) AS [w]
         WHERE [w].[StatusCode]=N'ERROR_HANDLED' OR [w].[ErrorNumber]=209
     )
    INSERT [#Failure] VALUES(N'USP_QueryStoreRegressions_dynamic_sql',N'Query-Store-Regressionsanalyse enthielt einen abgefangenen dynamischen SQL-Fehler.');

/* Alle öffentlichen Procedures: NONE+JSON mit sicheren Begrenzungen. */
DECLARE @ProcedureName sysname,@ObjectId int,@Sql nvarchar(max),@Arguments nvarchar(max);
DECLARE [ProcedureCursor] CURSOR LOCAL FAST_FORWARD FOR
SELECT [p].[name],[p].[object_id]
FROM [sys].[procedures] AS [p]
JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[p].[schema_id]
WHERE [s].[name]=N'monitor'
  AND [p].[name] NOT IN(N'USP_PrepareDatabaseCandidates',N'USP_PrepareNameFilters')
ORDER BY [p].[name];

OPEN [ProcedureCursor];
FETCH NEXT FROM [ProcedureCursor] INTO @ProcedureName,@ObjectId;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @Arguments=N'@ResultSetArt=N''NONE'',@JsonErzeugen=1,@Json=@Json OUTPUT';
    IF EXISTS(SELECT 1 FROM [sys].[parameters] WHERE [object_id]=@ObjectId AND [name]=N'@DatabaseNames') SET @Arguments+=N',@DatabaseNames=N''''';
    IF EXISTS(SELECT 1 FROM [sys].[parameters] WHERE [object_id]=@ObjectId AND [name]=N'@QueryStoreDatabaseNames') SET @Arguments+=N',@QueryStoreDatabaseNames=N''''';
    IF EXISTS(SELECT 1 FROM [sys].[parameters] WHERE [object_id]=@ObjectId AND [name]=N'@MaxDatenbanken') SET @Arguments+=N',@MaxDatenbanken=1';
    IF EXISTS(SELECT 1 FROM [sys].[parameters] WHERE [object_id]=@ObjectId AND [name]=N'@MaxZeilen') SET @Arguments+=N',@MaxZeilen=1';
    IF EXISTS(SELECT 1 FROM [sys].[parameters] WHERE [object_id]=@ObjectId AND [name]=N'@MaxAnalyseobjekte') SET @Arguments+=N',@MaxAnalyseobjekte=1';
    IF EXISTS(SELECT 1 FROM [sys].[parameters] WHERE [object_id]=@ObjectId AND [name]=N'@LockTimeoutMs') SET @Arguments+=N',@LockTimeoutMs=5000';
    IF EXISTS(SELECT 1 FROM [sys].[parameters] WHERE [object_id]=@ObjectId AND [name]=N'@PrintMeldungen') SET @Arguments+=N',@PrintMeldungen=0';

    SET @Sql=N'
BEGIN TRY
    DECLARE @Json nvarchar(max);
    EXEC [monitor].'+QUOTENAME(@ProcedureName)+N' '+@Arguments+N';
    INSERT [#PublicProcedureResult]([ProcedureName],[TestStatus],[JsonStatus])
    VALUES(N'''+REPLACE(@ProcedureName,N'''',N'''''')+N''',''PASS'',CASE WHEN ISJSON(@Json)=1 THEN ''VALID_JSON'' ELSE ''MISSING_OR_INVALID_JSON'' END);
END TRY
BEGIN CATCH
    INSERT [#PublicProcedureResult]([ProcedureName],[TestStatus],[ErrorNumber],[ErrorMessage])
    VALUES(N'''+REPLACE(@ProcedureName,N'''',N'''''')+N''',''FAIL'',ERROR_NUMBER(),ERROR_MESSAGE());
END CATCH;';
    EXEC [sys].[sp_executesql] @Sql;
    FETCH NEXT FROM [ProcedureCursor] INTO @ProcedureName,@ObjectId;
END;
CLOSE [ProcedureCursor];
DEALLOCATE [ProcedureCursor];

INSERT [#Failure]([TestName],[Detail])
SELECT [ProcedureName],CONCAT(N'NONE/JSON-Laufzeittest fehlgeschlagen: ',COALESCE([ErrorMessage],[JsonStatus],N'Unbekannter Fehler.'))
FROM [#PublicProcedureResult]
WHERE [TestStatus]<>'PASS' OR [JsonStatus]<>'VALID_JSON';

/* Repräsentative RAW- und CONSOLE-Ausführung derselben öffentlichen API. */
BEGIN TRY
    EXEC [monitor].[USP_CurrentRequests]
          @SessionIds=@SelfSessionIds
        , @AktuelleSessionEinbeziehen=1
        , @MaxZeilen=1
        , @ResultSetArt='RAW'
        , @PrintMeldungen=0;
    EXEC [monitor].[USP_CurrentRequests]
          @SessionIds=@SelfSessionIds
        , @AktuelleSessionEinbeziehen=1
        , @MaxZeilen=1
        , @ResultSetArt='CONSOLE'
        , @PrintMeldungen=0;
    EXEC [monitor].[USP_CheckFrameworkCapabilities]
          @DatabaseNames=N''
        , @MaxDatenbanken=1
        , @ResultSetArt='RAW'
        , @PrintMeldungen=0;
    EXEC [monitor].[USP_CheckFrameworkCapabilities]
          @DatabaseNames=N''
        , @MaxDatenbanken=1
        , @ResultSetArt='CONSOLE'
        , @PrintMeldungen=0;
END TRY
BEGIN CATCH
    INSERT [#Failure] VALUES(N'RAW_CONSOLE_contract',CONCAT(N'RAW- oder CONSOLE-Ausführung fehlgeschlagen: ',ERROR_MESSAGE()));
END CATCH;

SELECT [TestName],[Detail] FROM [#Failure] ORDER BY [TestName];
SELECT [TestStatus],[JsonStatus],COUNT(*) AS [ProcedureCount]
FROM [#PublicProcedureResult]
GROUP BY [TestStatus],[JsonStatus]
ORDER BY [TestStatus],[JsonStatus];

IF EXISTS(SELECT 1 FROM [#Failure])
    THROW 54130,N'Der Filter-, Ausgabe- oder JSON-Vertrag ist verletzt.',1;
GO

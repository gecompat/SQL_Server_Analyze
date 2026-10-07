USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Unabhängiger Literalvertrag für 20 Felder, sieben Frameworktexte,
drei NOT-NULL-Felder und keine Identity. TABLE/JSON werden innerhalb desselben
Aufrufs vollständig mit NULLs, JSON-Typen und BIN2-Häufigkeiten verglichen.
Der optionale Context ExampleCurrentTransactionsFixtureIds enthält
Root|Middle|Leaf|ToolLeaf der vier eigenen Verbindungen. Der Test liest nur
native Metadaten; er erzeugt weder Fixture noch Parent-Snapshottabellen.
Ohne geeigneten Context bleibt der positive Block NOT_EXECUTED.
Native Identitäten, Joinwerte und Unicode-Text werden unabhängig geprüft;
Alter wird über GETDATE vor/nach geklammert. Andere Quellwerte müssen im
kontrollierten Fixturefenster stabil bleiben; kein allgemeiner atomarer
Cross-call-Snapshot wird behauptet. RAW/positive CONSOLE prüfen hier Status
und JSON; vollständige Clientzeilen sind ein gesonderter Rootnachweis.
*/
SET NOCOUNT ON;
DECLARE @Level int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @Level IS NULL OR @Level NOT IN(150,160,170) THROW 59000,N'TRANSACTIONS_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS' THROW 59001,N'TRANSACTIONS_FRAMEWORK_COLLATION',1;
IF EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE session_id=32767) THROW 59002,N'TRANSACTIONS_EMPTY_SESSION_GUARD',1;
IF OBJECT_ID(N'tempdb..#ExampleMissingTarget188') IS NOT NULL THROW 59002,N'TRANSACTIONS_FOREIGN_TARGET',1;
DECLARE @OriginalTimeout int=@@LOCK_TIMEOUT,@Json nvarchar(max),@TableJson nvarchar(max),@Sql nvarchar(max),
 @Case int,@Native bit,@Ids nvarchar(max),@Max int,@Text int,@WithText bit,@Sleeping bit,@System bit,@Min int,@Status varchar(40),
 @Core int=0,@NativeCount int=0,@Consumer int=0,@Preflight int=0,@EmptyConsole int=0,@DirectConsole int=0,@NullMutations int=0,
 @FixtureStatus varchar(24)='NOT_EXECUTED',@Before datetime,@After datetime,@Rows int,@Total int;
CREATE TABLE #ExampleCurrentTransactionsSchema
(
          [SessionId]                smallint       NOT NULL
        , [TransactionId]            bigint         NOT NULL
        , [TransactionBeginTimeUtc]  datetime       NULL
        , [TransactionAgeSeconds]    bigint         NULL
        , [TransactionType]          int            NULL
        , [TransactionState]         int            NULL
        , [OpenTransactionCount]     int            NULL
        , [LoginName]                nvarchar(128)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HostName]                 nvarchar(128)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProgramName]              nvarchar(128)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SessionStatus]            nvarchar(30)   COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RequestStatus]            nvarchar(30)   COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DatabaseId]               int            NULL
        , [DatabaseName]             sysname        COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LogBytesUsed]             bigint         NULL
        , [LogBytesReserved]         bigint         NULL
        , [StatementTextCharacters]  bigint         NULL
        , [StatementTextBytes]       bigint         NULL
        , [StatementTextIsTruncated] bit            NOT NULL DEFAULT(0)
        , [StatementText]            nvarchar(max)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
SELECT TOP(0) * INTO #ExampleCurrentTransactionsNative FROM #ExampleCurrentTransactionsSchema;
SELECT TOP(0) * INTO #ExampleCurrentTransactionsAfter FROM #ExampleCurrentTransactionsSchema;
CREATE TABLE #ExampleCurrentTransactionsIds(RoleOrdinal int NOT NULL PRIMARY KEY,SessionId smallint NOT NULL UNIQUE);
CREATE TABLE #ExampleCurrentTransactionsProbe(OwnObjects int NOT NULL);
CREATE TABLE #ExampleCurrentTransactionsExpectedFields(RowOrdinal int NOT NULL,FieldName nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 FieldValue nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,JsonType int NOT NULL);
CREATE TABLE #ExampleCurrentTransactionsEmptyConsole(Ergebnis nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 Status varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Hinweis nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleCurrentTransactionsPreflight(Dummy int NULL);
CREATE TABLE #ExampleCurrentTransactionsCases(CaseNumber int NOT NULL PRIMARY KEY,Native bit NOT NULL,
 Ids nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,MaxRows int NULL,MaxText int NULL,WithText bit NULL,
 Sleeping bit NULL,SystemSessions bit NULL,MinAge int NULL,ExpectedStatus varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
INSERT #ExampleCurrentTransactionsCases VALUES
 (0,0,N'32767',NULL,NULL,1,0,0,0,'AVAILABLE'),(1,0,N'32767',0,0,0,0,0,0,'AVAILABLE'),
 (2,0,N'32767',1,1,1,0,0,0,'AVAILABLE'),(3,0,N'32767',2,2,1,0,0,0,'AVAILABLE'),
 (4,0,N'32767',-1,0,0,0,0,0,'INVALID_PARAMETER'),(5,0,N'32767',0,-1,1,0,0,0,'INVALID_PARAMETER'),
 (6,0,N'32767',0,0,0,0,0,-1,'INVALID_PARAMETER'),(7,0,N'32767',0,0,0,0,0,NULL,'INVALID_PARAMETER'),
 (8,0,N'ExampleInvalid',0,0,0,0,0,0,'INVALID_PARAMETER'),(9,0,N'32768',0,0,0,0,0,0,'INVALID_PARAMETER'),
 (10,0,N'-1',0,0,0,0,0,0,'INVALID_PARAMETER'),(11,0,N'32767|32767',0,0,0,0,0,0,'INVALID_PARAMETER'),
 (12,0,N'',0,0,0,0,0,0,'INVALID_PARAMETER'),(13,0,N'32767,32767',0,0,0,0,0,0,'INVALID_PARAMETER'),
 (14,0,N'32767',2147483647,0,0,0,0,2147483647,'AVAILABLE'),
 (15,0,N'32767',0,0,0,1,1,0,'AVAILABLE'),(16,0,N'32767',0,0,NULL,0,0,0,'AVAILABLE'),
 (17,0,N'32767',0,0,0,NULL,NULL,0,'AVAILABLE');
DECLARE @Context nvarchar(max)=TRY_CONVERT(nvarchar(max),SESSION_CONTEXT(N'ExampleCurrentTransactionsFixtureIds')),
 @ContextJson nvarchar(max),@Root smallint,@Middle smallint,@Leaf smallint,@Tool smallint,@FixtureIds nvarchar(max),@FixtureDb sysname;
SET @ContextJson=N'['+REPLACE(@Context,N'|',N',')+N']';
IF @Context IS NOT NULL AND ISJSON(@ContextJson)=1 AND (SELECT COUNT(*) FROM OPENJSON(@ContextJson))=4
 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@ContextJson) WHERE type<>2 OR TRY_CONVERT(int,value) IS NULL OR TRY_CONVERT(int,value) NOT BETWEEN 1 AND 32767)
 AND (SELECT COUNT(DISTINCT TRY_CONVERT(int,value)) FROM OPENJSON(@ContextJson))=4
BEGIN
 INSERT #ExampleCurrentTransactionsIds SELECT CONVERT(int,[key])+1,CONVERT(smallint,value) FROM OPENJSON(@ContextJson);
 SELECT @Root=MAX(CASE RoleOrdinal WHEN 1 THEN SessionId END),@Middle=MAX(CASE RoleOrdinal WHEN 2 THEN SessionId END),
  @Leaf=MAX(CASE RoleOrdinal WHEN 3 THEN SessionId END),@Tool=MAX(CASE RoleOrdinal WHEN 4 THEN SessionId END) FROM #ExampleCurrentTransactionsIds;
 IF (SELECT COUNT(DISTINCT database_id) FROM sys.dm_exec_requests WHERE session_id IN(@Middle,@Leaf,@Tool))=1
  SELECT @FixtureDb=DB_NAME(MAX(database_id)) FROM sys.dm_exec_requests WHERE session_id IN(@Middle,@Leaf,@Tool);
 IF @FixtureDb IS NOT NULL
 BEGIN
  SET @Sql=N'USE '+QUOTENAME(@FixtureDb)+N';INSERT #ExampleCurrentTransactionsProbe SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
   WHERE s.name COLLATE Latin1_General_100_BIN2=N''dbo'' AND t.name COLLATE Latin1_General_100_BIN2 IN(N''ExampleTransactionsSourceÄ🔬A'',N''ExampleTransactionsSourceä🔬B'',N''ExampleTransactionsSourceÖ🔬C'');';
  EXEC sys.sp_executesql @Sql;
 END;
 IF EXISTS(SELECT 1 FROM #ExampleCurrentTransactionsProbe WHERE OwnObjects=3)
  AND (SELECT COUNT(*) FROM sys.dm_exec_sessions s JOIN #ExampleCurrentTransactionsIds i ON i.SessionId=s.session_id
   WHERE s.is_user_process=1 AND s.original_login_name COLLATE Latin1_General_100_BIN2=ORIGINAL_LOGIN() COLLATE Latin1_General_100_BIN2
    AND s.host_name COLLATE Latin1_General_100_BIN2=s.program_name COLLATE Latin1_General_100_BIN2
    AND s.program_name COLLATE Latin1_General_100_BIN2=CASE i.RoleOrdinal WHEN 1 THEN N'ExampleTransactionsToolRootÄ🔬' WHEN 2 THEN N'ExampleTransactionsToolMiddleÄ🔬'
     WHEN 3 THEN N'ExampleTransactionsLeafÄ🔬' ELSE N'ExampleTransactionsToolLeafä🔬' END COLLATE Latin1_General_100_BIN2)=4
  AND EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE session_id=@Root AND status=N'sleeping' AND open_transaction_count>0)
  AND NOT EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE session_id=@Root)
  AND (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE session_id IN(@Middle,@Leaf,@Tool))=3
  AND EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE session_id=@Middle AND blocking_session_id=@Root AND wait_type=N'LCK_M_X')
  AND EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE session_id=@Leaf AND blocking_session_id=@Middle AND wait_type=N'LCK_M_X')
  AND EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE session_id=@Tool AND blocking_session_id=@Middle AND wait_type=N'LCK_M_X')
  AND (SELECT COUNT(DISTINCT st.session_id) FROM sys.dm_tran_session_transactions st JOIN #ExampleCurrentTransactionsIds i ON i.SessionId=st.session_id)=4
 BEGIN
  SET @FixtureStatus='PASS';SET @FixtureIds=@Context;
  INSERT #ExampleCurrentTransactionsCases VALUES
   (20,1,@FixtureIds,NULL,NULL,1,0,0,0,'AVAILABLE'),(21,1,@FixtureIds,0,0,1,0,0,0,'AVAILABLE'),
   (22,1,@FixtureIds,1,0,1,0,0,0,'AVAILABLE'),(23,1,@FixtureIds,2,0,1,0,0,0,'AVAILABLE'),
   (24,1,@FixtureIds,0,1,1,0,0,0,'AVAILABLE'),(25,1,@FixtureIds,2,20,1,0,0,0,'AVAILABLE'),
   (26,1,@FixtureIds,0,0,0,0,0,0,'AVAILABLE'),(27,1,@FixtureIds,0,NULL,1,1,0,0,'AVAILABLE'),
   (28,1,CONVERT(nvarchar(10),@Root),1,0,1,0,0,0,'AVAILABLE'),
   (29,1,CONVERT(nvarchar(10),@Middle),1,0,1,0,0,0,'AVAILABLE'),
   (30,1,CONVERT(nvarchar(10),@Leaf),1,0,1,0,0,0,'AVAILABLE'),
   (31,1,CONVERT(nvarchar(10),@Tool),1,0,1,0,0,0,'AVAILABLE'),
   (32,1,@FixtureIds,0,0,1,0,1,0,'AVAILABLE'),(33,1,@FixtureIds,0,0,1,0,0,2147483647,'AVAILABLE'),
   (34,1,@FixtureIds,0,0,1,NULL,0,0,'AVAILABLE'),(35,1,@FixtureIds,0,0,NULL,0,0,0,'AVAILABLE'),
   (36,1,CONCAT(@Tool,N'|',@Leaf,N'|',@Middle,N'|',@Root),2,0,1,0,0,0,'AVAILABLE'),
   (37,1,CONCAT(@Root,N',',@Middle,N';',@Leaf,N'|',@Tool),0,0,1,0,0,0,'AVAILABLE');
 END;
END;

DECLARE @NativeSql nvarchar(max)=N'
 INSERT #ExampleCurrentTransactionsNative
 SELECT s.session_id,a.transaction_id,a.transaction_begin_time,DATEDIFF_BIG(SECOND,a.transaction_begin_time,GETDATE()),a.transaction_type,a.transaction_state,
  s.open_transaction_count,s.login_name,s.host_name,s.program_name,s.status,r.status,COALESCE(r.database_id,d.database_id),DB_NAME(COALESCE(r.database_id,d.database_id)),
  d.database_transaction_log_bytes_used,d.database_transaction_log_bytes_reserved,
  CASE WHEN @text=1 THEN CONVERT(bigint,LEN((e.StatementText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1) END,
  CASE WHEN @text=1 THEN CONVERT(bigint,DATALENGTH(e.StatementText)) END,
  CONVERT(bit,CASE WHEN @text=1 AND @maxtext>0 AND LEN((e.StatementText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1>@maxtext THEN 1 ELSE 0 END),
  CASE WHEN @text=1 THEN CASE WHEN @maxtext IS NULL OR @maxtext=0 THEN e.StatementText COLLATE SQL_Latin1_General_CP1_CS_AS
   ELSE LEFT(e.StatementText COLLATE Latin1_General_100_CI_AS_SC,@maxtext) COLLATE SQL_Latin1_General_CP1_CS_AS END END
 FROM sys.dm_tran_session_transactions st JOIN sys.dm_tran_active_transactions a ON a.transaction_id=st.transaction_id
 JOIN sys.dm_exec_sessions s ON s.session_id=st.session_id
 LEFT JOIN sys.dm_exec_requests r ON r.session_id=st.session_id
 LEFT JOIN sys.dm_tran_database_transactions d ON d.transaction_id=st.transaction_id
 OUTER APPLY sys.dm_exec_sql_text(CASE WHEN @text=1 THEN r.sql_handle END) t
 OUTER APPLY(SELECT StatementText=CASE WHEN t.text IS NOT NULL AND COALESCE(r.statement_start_offset,0)>=0
  AND COALESCE(r.statement_start_offset,0)<=CASE WHEN r.statement_end_offset IS NULL OR r.statement_end_offset=-1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END
  AND COALESCE(r.statement_start_offset,0)<=DATALENGTH(t.text)
  AND (r.statement_end_offset IS NULL OR r.statement_end_offset=-1 OR r.statement_end_offset<=DATALENGTH(t.text))
  AND COALESCE(r.statement_start_offset,0)%2=0 AND COALESCE(NULLIF(r.statement_end_offset,-1),DATALENGTH(t.text))%2=0
  THEN CONVERT(nvarchar(max),SUBSTRING(CONVERT(varbinary(max),t.text),COALESCE(r.statement_start_offset,0)+1,
   CASE WHEN r.statement_end_offset IS NULL OR r.statement_end_offset=-1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END-COALESCE(r.statement_start_offset,0)+2)) END) e
 WHERE s.session_id IN(SELECT TRY_CONVERT(smallint,value) FROM OPENJSON(@ids))
 AND (@sleeping=0 OR s.status=N''sleeping'') AND (@system=1 OR s.is_user_process=1)
 AND DATEDIFF_BIG(SECOND,a.transaction_begin_time,GETDATE())>=@min;';
DECLARE @NativeParams nvarchar(400)=N'@ids nvarchar(max),@text bit,@maxtext int,@sleeping bit,@system bit,@min int',@NativeIds nvarchar(max),@ExpectedJson nvarchar(max),@ActualJson nvarchar(max),@NativeBeforeJson nvarchar(max),@NativeAfterJson nvarchar(max);
BEGIN TRY
 SET LOCK_TIMEOUT 731;
 SET @Case=-1;
 WHILE 1=1
 BEGIN
  SELECT @Case=MIN(CaseNumber) FROM #ExampleCurrentTransactionsCases WHERE CaseNumber>@Case;
  IF @Case IS NULL BREAK;
  SELECT @Native=Native,@Ids=Ids,@Max=MaxRows,@Text=MaxText,@WithText=WithText,@Sleeping=Sleeping,@System=SystemSessions,@Min=MinAge,@Status=ExpectedStatus
   FROM #ExampleCurrentTransactionsCases WHERE CaseNumber=@Case;
  DELETE #ExampleCurrentTransactionsNative;DELETE #ExampleCurrentTransactionsAfter;DELETE #ExampleCurrentTransactionsExpectedFields;
  SET @NativeIds=N'['+REPLACE(REPLACE(REPLACE(@Ids,N'|',N','),N';',N','),N' ',N'')+N']';
  IF @Native=1
  BEGIN
   SET @Before=GETDATE();
   EXEC sys.sp_executesql @NativeSql,@NativeParams,@ids=@NativeIds,@text=@WithText,@maxtext=@Text,@sleeping=@Sleeping,@system=@System,@min=@Min;
   SELECT @Total=COUNT(*) FROM #ExampleCurrentTransactionsNative;
   IF @Min=0 AND @Sleeping=0 AND @WithText IS NOT NULL AND @Total<1 THROW 59003,N'TRANSACTIONS_NATIVE_FIXTURE_DISAPPEARED',1;
  END;
  CREATE TABLE #ExampleCurrentTransactionsExport(Dummy int NULL);
  SET @Json=NULL;
  EXEC monitor.USP_CurrentTransactions @SessionIds=@Ids,@MinAlterSekunden=@Min,@NurSleeping=@Sleeping,@SystemSessionsEinbeziehen=@System,
   @MitSqlText=@WithText,@MaxSqlTextZeichen=@Text,@MaxZeilen=@Max,@ResultSetArt='TABLE',
   @ResultTablesJson=N'{"transactions":"#ExampleCurrentTransactionsExport"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @@LOCK_TIMEOUT<>731 THROW 59004,N'TRANSACTIONS_CALLER_TIMEOUT',1;
  IF @Native=1
  BEGIN
   INSERT #ExampleCurrentTransactionsAfter SELECT * FROM #ExampleCurrentTransactionsNative;
   DELETE #ExampleCurrentTransactionsNative;
   EXEC sys.sp_executesql @NativeSql,@NativeParams,@ids=@NativeIds,@text=@WithText,@maxtext=@Text,@sleeping=@Sleeping,@system=@System,@min=@Min;
   SET @After=GETDATE();
   -- All native fields except increasing age must remain stable in this owned fixture.
   SELECT @NativeBeforeJson=(SELECT * FROM #ExampleCurrentTransactionsAfter FOR JSON PATH,INCLUDE_NULL_VALUES);
   SELECT @NativeAfterJson=(SELECT * FROM #ExampleCurrentTransactionsNative FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF EXISTS(SELECT JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@NativeBeforeJson,N'[]')) GROUP BY JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@NativeAfterJson,N'[]')) GROUP BY JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@NativeAfterJson,N'[]')) GROUP BY JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@NativeBeforeJson,N'[]')) GROUP BY JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2)
    THROW 59005,N'TRANSACTIONS_NATIVE_VALUES_CHANGED',1;
  END;
  IF ISNULL(ISJSON(@Json),0)<>1 OR ISNULL(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>@Status THROW 59006,N'TRANSACTIONS_JSON_STATUS',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>3 OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@Json) EXCEPT SELECT k.name,k.type FROM (VALUES(N'meta',5),(N'transactions',4),(N'warnings',4)) k(name,type))
   THROW 59007,N'TRANSACTIONS_JSON_TOP',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.meta'))<>10 OR EXISTS(SELECT [key] FROM OPENJSON(@Json,'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json,'$.meta') EXCEPT SELECT name COLLATE Latin1_General_100_BIN2 FROM (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'evidenceSnapshotStartedAtUtc'),(N'evidenceSnapshotId'),(N'statusCode'),(N'isPartial'),(N'requestedMaxRows'),(N'returnedRows'),(N'hasMoreRows')) k(name))
   OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.schemaVersion')),-1)<>2 OR ISNULL(JSON_VALUE(@Json,'$.meta.resultName'),'')<>N'CurrentTransactions'
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@Json,'$.meta.evidenceSnapshotId')) IS NULL
   OR TRY_CONVERT(datetime2,JSON_VALUE(@Json,'$.meta.generatedAtUtc')) IS NULL OR TRY_CONVERT(datetime2,JSON_VALUE(@Json,'$.meta.evidenceSnapshotStartedAtUtc')) IS NULL
   THROW 59008,N'TRANSACTIONS_META',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.meta') m WHERE m.type<>CASE WHEN m.[key] IN('schemaVersion','returnedRows') THEN 2 WHEN m.[key] IN('isPartial','hasMoreRows') THEN 3 WHEN m.[key]='requestedMaxRows' THEN CASE WHEN @Max IS NULL THEN 0 ELSE 2 END ELSE 1 END)
   THROW 59008,N'TRANSACTIONS_META_FULL_TYPES',1;
  IF NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.meta') WHERE [key]='requestedMaxRows' AND ([type]=0 AND @Max IS NULL OR [type]=2 AND TRY_CONVERT(int,value)=@Max))
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.meta') WHERE [key]='isPartial' AND [type]=3 AND value=CASE WHEN @Status='AVAILABLE' THEN N'false' ELSE N'true' END)
   THROW 59008,N'TRANSACTIONS_META_TYPES',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.warnings') a WHERE [type]<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>3
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT k.name FROM (VALUES(N'StatusCode'),(N'ErrorNumber'),(N'ErrorMessage')) k(name)))
   THROW 59009,N'TRANSACTIONS_WARNING_FIELDS',1;
  SELECT @Rows=COUNT(*) FROM #ExampleCurrentTransactionsExport;
  IF @Native=0 AND (@Rows<>0 OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.returnedRows')),-1)<>0 OR ISNULL(JSON_VALUE(@Json,'$.meta.hasMoreRows'),'')<>N'false') THROW 59010,N'TRANSACTIONS_EMPTY_SCOPE',1;
  IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentTransactionsExport')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentTransactionsSchema'))
   OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentTransactionsSchema')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentTransactionsExport'))
   THROW 59011,N'TRANSACTIONS_TABLE_SCHEMA',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.transactions') a WHERE type<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>20
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentTransactionsSchema')))
   THROW 59012,N'TRANSACTIONS_ROW_FIELDS',1;
  SET @Sql=N'SELECT @j=(SELECT * FROM #ExampleCurrentTransactionsExport ORDER BY TransactionAgeSeconds DESC,SessionId,TransactionId FOR JSON PATH,INCLUDE_NULL_VALUES);';
  EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT',@j=@TableJson OUTPUT;
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.transactions') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.transactions') GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
   THROW 59013,N'TRANSACTIONS_TABLE_JSON',1;
  IF @Native=1
  BEGIN
   IF @Rows<>CASE WHEN @Max>0 AND @Total>@Max THEN @Max ELSE @Total END
    OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.returnedRows')),-1)<>@Rows
    OR ISNULL(JSON_VALUE(@Json,'$.meta.hasMoreRows'),'')<>CASE WHEN @Max>0 AND @Total>@Max THEN N'true' ELSE N'false' END THROW 59014,N'TRANSACTIONS_NATIVE_LIMIT',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.transactions') a WHERE NOT EXISTS(SELECT 1 FROM OPENJSON(a.value) WHERE [key]='TransactionAgeSeconds' AND type=2)
    OR TRY_CONVERT(bigint,JSON_VALUE(a.value,'$.TransactionAgeSeconds')) IS NULL
    OR TRY_CONVERT(bigint,JSON_VALUE(a.value,'$.TransactionAgeSeconds'))<DATEDIFF_BIG(SECOND,TRY_CONVERT(datetime,JSON_VALUE(a.value,'$.TransactionBeginTimeUtc')),@Before)
    OR TRY_CONVERT(bigint,JSON_VALUE(a.value,'$.TransactionAgeSeconds'))>DATEDIFF_BIG(SECOND,TRY_CONVERT(datetime,JSON_VALUE(a.value,'$.TransactionBeginTimeUtc')),@After)) THROW 59015,N'TRANSACTIONS_NATIVE_AGE_BOUND',1;
   SELECT @ExpectedJson=(SELECT TOP(CASE WHEN @Max>0 THEN CONVERT(bigint,@Max) ELSE CONVERT(bigint,9223372036854775807) END) * FROM #ExampleCurrentTransactionsAfter ORDER BY TransactionAgeSeconds DESC,SessionId,TransactionId FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF EXISTS(SELECT JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.transactions') GROUP BY JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.transactions') GROUP BY JSON_MODIFY(value,'strict $.TransactionAgeSeconds',0) COLLATE Latin1_General_100_BIN2)
    THROW 59016,N'TRANSACTIONS_NATIVE_FULL_VALUES',1;
   INSERT #ExampleCurrentTransactionsExpectedFields SELECT CONVERT(int,a.[key]),b.[key],b.value,b.type FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) a CROSS APPLY OPENJSON(a.value) b;
   -- Six strict NULL mutations must be rejected against independent non-NULL evidence.
   IF @Case=20
   BEGIN
    DECLARE @Field nvarchar(128),@Mutated nvarchar(max),@FieldOrdinal int=0;
    WHILE @FieldOrdinal<6
    BEGIN
     SET @FieldOrdinal+=1;
     SET @Field=CASE @FieldOrdinal WHEN 1 THEN N'LoginName' WHEN 2 THEN N'HostName' WHEN 3 THEN N'ProgramName' WHEN 4 THEN N'SessionStatus' WHEN 5 THEN N'DatabaseName' ELSE N'StatementText' END;
     DECLARE @MutationRow int=(SELECT MIN(RowOrdinal) FROM #ExampleCurrentTransactionsExpectedFields WHERE FieldName=@Field COLLATE Latin1_General_100_BIN2 AND JsonType<>0);
     IF @MutationRow IS NULL THROW 59017,N'TRANSACTIONS_NULL_MUTATION_EVIDENCE_MISSING',1;
     SET @Mutated=JSON_MODIFY(COALESCE(@ExpectedJson,N'[]'),N'strict $['+CONVERT(nvarchar(10),@MutationRow)+N'].'+@Field,NULL);
     IF NOT EXISTS(SELECT 1 FROM OPENJSON(@Mutated) a CROSS APPLY OPENJSON(a.value) b JOIN #ExampleCurrentTransactionsExpectedFields e ON e.RowOrdinal=CONVERT(int,a.[key]) AND e.FieldName=b.[key] COLLATE Latin1_General_100_BIN2
      WHERE b.type<>e.JsonType OR b.value IS NULL AND e.FieldValue IS NOT NULL OR b.value IS NOT NULL AND e.FieldValue IS NULL OR b.value COLLATE Latin1_General_100_BIN2<>e.FieldValue)
      THROW 59018,N'TRANSACTIONS_NULL_MUTATION_ACCEPTED',1;
     SET @NullMutations+=1;
    END;
   END;
   SET @NativeCount+=1;
  END
  ELSE SET @Core+=1;
  DROP TABLE #ExampleCurrentTransactionsExport;
 END;

 DECLARE @C int=0,@Mode varchar(16),@Parent uniqueidentifier=NULL;
 WHILE @C<4
 BEGIN
  SET @Json=N'ExampleOldValue';SET @Parent=NULL;SET @Mode=CASE @C WHEN 0 THEN 'RAW' WHEN 1 THEN 'NONE' WHEN 2 THEN 'ExampleInvalid' ELSE 'NONE' END;
  IF @C=3 SET @Parent=NEWID();
  EXEC monitor.USP_CurrentTransactions @SessionIds=N'32767',@MitSqlText=0,@MaxZeilen=1,@ResultSetArt=@Mode,
   @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@ParentCurrentStateSnapshotId=@Parent;
  IF ISNULL(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>CASE @C WHEN 2 THEN 'INVALID_PARAMETER' WHEN 3 THEN 'INVALID_PARENT_SNAPSHOT' ELSE 'AVAILABLE' END
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.transactions'))<>0 OR @@LOCK_TIMEOUT<>731 THROW 59019,N'TRANSACTIONS_CONSUMER',1;
  IF @C=3 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.warnings') WHERE JSON_VALUE(value,'$.StatusCode')='INVALID_PARENT_SNAPSHOT' AND JSON_VALUE(value,'$.ErrorNumber')='208')
   THROW 59019,N'TRANSACTIONS_MISSING_PARENT',1;
  SET @Consumer+=1;SET @C+=1;
 END;
 SET @C=0;
 WHILE @C<6
 BEGIN
  DECLARE @Map nvarchar(max)=CASE @C WHEN 0 THEN N'[]' WHEN 1 THEN N'{}' WHEN 2 THEN N'{"ExampleUnknown":"#ExampleCurrentTransactionsPreflight"}'
   WHEN 3 THEN N'{"transactions":"##ExampleForbidden188"}' WHEN 4 THEN N'{"transactions":"#ExampleMissingTarget188"}'
   ELSE N'{"transactions":"#ExampleCurrentTransactionsPreflight"}' END,@Caught bit=0;
  IF @C=5 INSERT #ExampleCurrentTransactionsPreflight VALUES(4242);
  BEGIN TRY
   EXEC monitor.USP_CurrentTransactions @SessionIds=N'ExampleInvalid',@MinAlterSekunden=NULL,@ParentCurrentStateSnapshotId=@Parent,
    @ResultSetArt='TABLE',@ResultTablesJson=@Map,@PrintMeldungen=0;
  END TRY
  BEGIN CATCH
   IF ERROR_NUMBER()<>51011 THROW;
   SET @Caught=1;
  END CATCH;
  IF @Caught=0 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentTransactionsPreflight'))<>1
   OR (@C=5 AND NOT EXISTS(SELECT 1 FROM #ExampleCurrentTransactionsPreflight WHERE Dummy=4242)) THROW 59020,N'TRANSACTIONS_PREFLIGHT',1;
  DELETE #ExampleCurrentTransactionsPreflight;SET @Preflight+=1;SET @C+=1;
 END;
 SET @C=0;
 WHILE @C<3
 BEGIN
  DELETE #ExampleCurrentTransactionsEmptyConsole;
  INSERT #ExampleCurrentTransactionsEmptyConsole
  EXEC monitor.USP_CurrentTransactions @SessionIds=N'32767',@MinAlterSekunden=0,@MitSqlText=0,@MaxZeilen=@C,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleCurrentTransactionsEmptyConsole)<>1
   OR NOT EXISTS(SELECT 1 FROM #ExampleCurrentTransactionsEmptyConsole WHERE Ergebnis=N'Keine aktiven Transaktionen' AND Status IS NULL AND Hinweis IS NULL)
   OR @@LOCK_TIMEOUT<>731 THROW 59021,N'TRANSACTIONS_EMPTY_CONSOLE',1;
  SET @EmptyConsole+=1;SET @C+=1;
 END;
 IF @FixtureStatus='PASS'
 BEGIN
  SET @C=0;
  WHILE @C<3
  BEGIN
   SET @Max=CASE WHEN @C=0 THEN 0 ELSE @C END;
   EXEC monitor.USP_CurrentTransactions @SessionIds=@FixtureIds,@MinAlterSekunden=0,@MitSqlText=1,@MaxSqlTextZeichen=0,@MaxZeilen=@Max,
    @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF ISNULL(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>'AVAILABLE' OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.transactions'))<1
    OR @Max>0 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.transactions'))<>@Max OR @@LOCK_TIMEOUT<>731 THROW 59022,N'TRANSACTIONS_DIRECT_CONSOLE',1;
   SET @DirectConsole+=1;SET @C+=1;
  END;
 END;
 DECLARE @Literal nvarchar(max)=N'ExampleÄ🔬  ',@UnicodeCases int=0;
 SET @C=0;
 WHILE @C<4
 BEGIN
  SET @Text=CASE @C WHEN 0 THEN 8 WHEN 1 THEN 9 WHEN 2 THEN 0 ELSE NULL END;
  IF NOT EXISTS(SELECT 1 FROM monitor.TVF_ProjectUnicodeText(@Literal,@Text)
   WHERE OriginalCharacters=11 AND OriginalBytes=24 AND IsTruncated=CASE WHEN @Text=8 OR @Text=9 THEN 1 ELSE 0 END
    AND ProjectedValue COLLATE Latin1_General_100_BIN2=CASE WHEN @Text=8 THEN N'ExampleÄ' WHEN @Text=9 THEN N'ExampleÄ🔬' ELSE @Literal END COLLATE Latin1_General_100_BIN2)
   THROW 59023,N'TRANSACTIONS_SYNTHETIC_UNICODE',1;
  SET @UnicodeCases+=1;SET @C+=1;
 END;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalTimeout)+N';';EXEC sys.sp_executesql @Sql;
 DROP TABLE #ExampleCurrentTransactionsSchema;DROP TABLE #ExampleCurrentTransactionsNative;DROP TABLE #ExampleCurrentTransactionsAfter;
 DROP TABLE #ExampleCurrentTransactionsIds;DROP TABLE #ExampleCurrentTransactionsProbe;DROP TABLE #ExampleCurrentTransactionsExpectedFields;
 DROP TABLE #ExampleCurrentTransactionsEmptyConsole;DROP TABLE #ExampleCurrentTransactionsPreflight;DROP TABLE #ExampleCurrentTransactionsCases;
 SELECT N'PASS' AS ContractStatus,@Level AS FrameworkLevel,@Core AS CoreCases,@FixtureStatus AS PositiveFixtureStatus,@NativeCount AS NativeCases,
  @Consumer AS ConsumerCases,@Preflight AS PreflightCases,@EmptyConsole AS EmptyConsoleCases,@DirectConsole AS DirectConsoleCases,
  @UnicodeCases AS SyntheticUnicodeCases,@NullMutations AS NullMutationRejections,20 AS Fields,7 AS TextCollations;
END TRY
BEGIN CATCH
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalTimeout)+N';';EXEC sys.sp_executesql @Sql;
 DROP TABLE IF EXISTS #ExampleCurrentTransactionsExport;
 DROP TABLE IF EXISTS #ExampleCurrentTransactionsSchema;DROP TABLE IF EXISTS #ExampleCurrentTransactionsNative;DROP TABLE IF EXISTS #ExampleCurrentTransactionsAfter;
 DROP TABLE IF EXISTS #ExampleCurrentTransactionsIds;DROP TABLE IF EXISTS #ExampleCurrentTransactionsProbe;DROP TABLE IF EXISTS #ExampleCurrentTransactionsExpectedFields;
 DROP TABLE IF EXISTS #ExampleCurrentTransactionsEmptyConsole;DROP TABLE IF EXISTS #ExampleCurrentTransactionsPreflight;DROP TABLE IF EXISTS #ExampleCurrentTransactionsCases;
 THROW;
END CATCH;
GO

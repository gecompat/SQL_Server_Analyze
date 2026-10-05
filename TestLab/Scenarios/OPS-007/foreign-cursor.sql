USE [DeineDatenbank];
GO

SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM [sys].[extended_properties]
               WHERE [class]=0 AND [name]=N'SQLANALYZE.Ops007Disposable' AND CONVERT(int,[value])=1)
    THROW 54900, N'Der Marker des neuen Cursor-Labs fehlt.', 1;
DECLARE @Target int = CONVERT(int,N'__OPS007_SESSION_ID__');
IF @Target <= 50 OR @Target = @@SPID
    THROW 54901, N'Die eigene zweite Fixture-Session ist nicht eindeutig.', 1;
DECLARE @CursorId int, @FetchStatus int;
SELECT @CursorId=[cursor_id], @FetchStatus=[fetch_status]
    FROM [sys].[dm_exec_cursors](@Target)
    WHERE [name]=N'ExampleOps007ForeignCursor' AND [is_open]=1
      AND ([worker_time]>0 OR [reads]>0 OR [writes]>0);
IF @CursorId IS NULL
    THROW 54902, N'Die ressourcenpositive Cursorfixture fehlt in der zweiten Session.', 1;
DECLARE @Selection nvarchar(20)=CONVERT(nvarchar(20),@Target);
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int;
EXEC [monitor].[USP_CurrentCursorAnalysis]
    @IncludeCursorDetails=1, @SessionIds=@Selection, @MaxZeilen=1,
    @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT,
    @PrintMeldungen=0, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT;
IF COALESCE(@Status,'') <> 'AVAILABLE' OR COALESCE(@Partial,1) <> 0
   OR COALESCE(ISJSON(@Json),0) <> 1
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) <> 1
   OR NOT EXISTS
      (SELECT 1 FROM OPENJSON(@Json)
       WITH ([SessionId] int, [CursorId] int, [CursorName] nvarchar(256),
             [FindingContext] varchar(40), [IsOpen] bit)
       WHERE [SessionId]=@Target AND [CursorId]=@CursorId
         AND [CursorName]=N'ExampleOps007ForeignCursor'
         AND [FindingContext]='RESOURCE_CONTEXT' AND [IsOpen]=1)
    THROW 54903, N'Die begrenzte ressourcenpositive Fremdsession-Evidenz ist verletzt.', 1;
IF NOT EXISTS (SELECT 1 FROM [sys].[dm_exec_cursors](@Target)
               WHERE [cursor_id]=@CursorId AND [is_open]=1 AND [fetch_status]=@FetchStatus)
    THROW 54904, N'Der Analyzer hat den Cursorzustand der eigenen zweiten Session verändert.', 1;

IF EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE [name]=N'ExampleOps007DeniedLogin')
   OR USER_ID(N'ExampleOps007DeniedUser') IS NOT NULL
   OR EXISTS (SELECT 1 FROM [master].[sys].[database_principals] WHERE [name]=N'ExampleOps007DeniedUser')
    THROW 54905, N'Die ausschließlich eigenen Berechtigungsfixture-Namen sind belegt.', 1;
DECLARE @LoginCreated bit=0, @UserCreated bit=0, @MasterUserCreated bit=0;
DECLARE @LoginPassword nvarchar(128)=N'Synthetic!'+CONVERT(nvarchar(64),CRYPT_GEN_RANDOM(32),2);
DECLARE @Sql nvarchar(max)=N'CREATE LOGIN [ExampleOps007DeniedLogin] WITH PASSWORD=N'''
    +REPLACE(@LoginPassword,N'''',N'''''')+N''';';
BEGIN TRY
    EXEC [sys].[sp_executesql] @Sql;
    SET @LoginCreated=1;
    SET @LoginPassword=NULL;
    SET @Sql=NULL;
    CREATE USER [ExampleOps007DeniedUser] FOR LOGIN [ExampleOps007DeniedLogin];
    SET @UserCreated=1;
    GRANT EXECUTE ON [monitor].[USP_CurrentCursorAnalysis] TO [ExampleOps007DeniedUser];
    EXEC [master].[sys].[sp_executesql] N'CREATE USER [ExampleOps007DeniedUser] FOR LOGIN [ExampleOps007DeniedLogin];';
    SET @MasterUserCreated=1;
    EXEC [master].[sys].[sp_executesql] N'DENY SELECT ON [sys].[dm_exec_cursors] TO [ExampleOps007DeniedUser];';
    EXEC [master].[sys].[sp_executesql] N'DENY VIEW SERVER PERFORMANCE STATE TO [ExampleOps007DeniedLogin];';
    EXECUTE AS LOGIN=N'ExampleOps007DeniedLogin';
    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL; SET @Error=NULL;
    EXEC [monitor].[USP_CurrentCursorAnalysis]
        @IncludeCursorDetails=1, @SessionIds=@Selection,
        @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT,
        @PrintMeldungen=0, @StatusCodeOut=@Status OUTPUT,
        @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT;
    REVERT;
    IF COALESCE(@Status,'') <> 'DENIED_PERMISSION' OR COALESCE(@Partial,0) <> 1
       OR COALESCE(@Error,0) NOT IN (229,297,300,371,916)
       OR COALESCE(ISJSON(@Json),0) <> 1 OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) <> 0
        THROW 54906, N'Der ausdrückliche Berechtigungsfehler wird nicht eindeutig abgegrenzt.', 1;
    DROP USER [ExampleOps007DeniedUser]; SET @UserCreated=0;
    EXEC [master].[sys].[sp_executesql] N'DROP USER [ExampleOps007DeniedUser];'; SET @MasterUserCreated=0;
    DROP LOGIN [ExampleOps007DeniedLogin]; SET @LoginCreated=0;
END TRY
BEGIN CATCH
    IF SUSER_SNAME()=N'ExampleOps007DeniedLogin' REVERT;
    IF @UserCreated=1 DROP USER [ExampleOps007DeniedUser];
    IF @MasterUserCreated=1 EXEC [master].[sys].[sp_executesql] N'DROP USER [ExampleOps007DeniedUser];';
    IF @LoginCreated=1 DROP LOGIN [ExampleOps007DeniedLogin];
    THROW;
END CATCH;
GO

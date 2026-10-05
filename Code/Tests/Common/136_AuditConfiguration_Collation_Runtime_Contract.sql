USE [DeineDatenbank];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM [sys].[server_audits] WHERE [name] IN(N'ExampleCollAuditOne',N'ExampleCollAuditTwo'))
   OR EXISTS(SELECT 1 FROM [sys].[server_audit_specifications] WHERE [name] IN(N'ExampleCollServerOne',N'ExampleCollServerTwo'))
   OR EXISTS(SELECT 1 FROM [sys].[database_audit_specifications] WHERE [name] IN(N'ExampleCollDatabaseOne',N'ExampleCollDatabaseTwo'))
    THROW 55859,N'Ein eigener synthetischer Audit-Fixturename ist bereits belegt.',1;
DECLARE @Path nvarchar(4000)=CONVERT(nvarchar(4000),SERVERPROPERTY(N'InstanceDefaultDataPath'));
IF NULLIF(@Path,N'') IS NULL THROW 55859,N'Der Datenpfad für die eigene Audit-Fixture fehlt.',1;
DECLARE @Create nvarchar(max),@Json nvarchar(max),@Status varchar(40),@Partial bit,@Case tinyint=0,
        @Limit int,@Problems bit,@ExpectedAudits int,@ExpectedSpecs int,@Database sysname=DB_NAME();
DECLARE @Parity TABLE([TableJson] nvarchar(max),[ModuleJson] nvarchar(max));
BEGIN TRY
    SET @Create=N'CREATE SERVER AUDIT [ExampleCollAuditOne] TO FILE(FILEPATH=N'''+REPLACE(@Path,N'''',N'''''')+N''') WITH(ON_FAILURE=CONTINUE);'
               +N'CREATE SERVER AUDIT [ExampleCollAuditTwo] TO FILE(FILEPATH=N'''+REPLACE(@Path,N'''',N'''''')+N''') WITH(ON_FAILURE=CONTINUE);';
    EXEC [master].[sys].[sp_executesql] @Create;
    EXEC [master].[sys].[sp_executesql] N'CREATE SERVER AUDIT SPECIFICATION [ExampleCollServerOne] FOR SERVER AUDIT [ExampleCollAuditOne] ADD(FAILED_LOGIN_GROUP) WITH(STATE=ON);';
    EXEC [master].[sys].[sp_executesql] N'CREATE SERVER AUDIT SPECIFICATION [ExampleCollServerTwo] FOR SERVER AUDIT [ExampleCollAuditTwo] ADD(FAILED_LOGIN_GROUP) WITH(STATE=OFF);';
    CREATE DATABASE AUDIT SPECIFICATION [ExampleCollDatabaseOne] FOR SERVER AUDIT [ExampleCollAuditOne] ADD(DATABASE_OBJECT_CHANGE_GROUP) WITH(STATE=ON);
    CREATE DATABASE AUDIT SPECIFICATION [ExampleCollDatabaseTwo] FOR SERVER AUDIT [ExampleCollAuditTwo] ADD(DATABASE_OBJECT_CHANGE_GROUP) WITH(STATE=OFF);
    WHILE @Case<4
    BEGIN
        SELECT @Limit=CASE WHEN @Case=1 THEN 1 ELSE 0 END,@Problems=CASE WHEN @Case=3 THEN NULL WHEN @Case=2 THEN 1 ELSE 0 END,
               @ExpectedAudits=CASE WHEN @Case=1 THEN 1 ELSE 2 END,@ExpectedSpecs=CASE WHEN @Case=0 THEN 2 ELSE 1 END;
        CREATE TABLE [#ExampleAuditAudits]([Dummy] int NULL);
        CREATE TABLE [#ExampleAuditServer]([Dummy] int NULL);
        CREATE TABLE [#ExampleAuditDatabase]([Dummy] int NULL);
        CREATE TABLE [#ExampleAuditSources]([Dummy] int NULL);
        CREATE TABLE [#ExampleAuditWarnings]([Dummy] int NULL);
        SELECT @Json=NULL,@Status=NULL,@Partial=NULL;
        EXEC [monitor].[USP_AuditConfigurationAnalysis] @DatabaseNames=@Database,
            @AuditNames=N'ExampleCollAuditOne|ExampleCollAuditTwo',@MaxZeilen=@Limit,@NurProblematisch=@Problems,
            @ResultSetArt='TABLE',
            @ResultTablesJson=N'{"audits":"#ExampleAuditAudits","serverSpecifications":"#ExampleAuditServer","databaseSpecifications":"#ExampleAuditDatabase","sourceStatus":"#ExampleAuditSources","warnings":"#ExampleAuditWarnings"}',
            @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
            WHERE [object_id] IN(OBJECT_ID(N'tempdb..#ExampleAuditAudits'),OBJECT_ID(N'tempdb..#ExampleAuditServer'),
                  OBJECT_ID(N'tempdb..#ExampleAuditDatabase'),OBJECT_ID(N'tempdb..#ExampleAuditSources'),OBJECT_ID(N'tempdb..#ExampleAuditWarnings'))
              AND [collation_name] IS NOT NULL)<>27
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
                     WHERE [object_id] IN(OBJECT_ID(N'tempdb..#ExampleAuditAudits'),OBJECT_ID(N'tempdb..#ExampleAuditServer'),
                           OBJECT_ID(N'tempdb..#ExampleAuditDatabase'),OBJECT_ID(N'tempdb..#ExampleAuditSources'),OBJECT_ID(N'tempdb..#ExampleAuditWarnings'))
                       AND [collation_name] IS NOT NULL
                       AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 55851,N'Ein AuditConfiguration-Export übernimmt eine fremde tempdb-Collation.',1;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>'AVAILABLE_WITH_FINDING' OR COALESCE(@Partial,1)<>0
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
           OR (SELECT COUNT_BIG(*) FROM [#ExampleAuditAudits])<>@ExpectedAudits
           OR (SELECT COUNT_BIG(*) FROM [#ExampleAuditServer])<>@ExpectedSpecs
           OR (SELECT COUNT_BIG(*) FROM [#ExampleAuditDatabase])<>@ExpectedSpecs
           OR (SELECT COUNT_BIG(*) FROM [#ExampleAuditSources])<>3
           OR EXISTS(SELECT 1 FROM [#ExampleAuditSources] WHERE [StatusCode]<>'AVAILABLE' OR [IsPartial]<>0 OR COALESCE([ReturnedRowCount],-1)<>2)
           OR (SELECT COUNT_BIG(*) FROM [#ExampleAuditWarnings])<>4
           OR ((@Problems=1 OR @Problems IS NULL) AND (EXISTS(SELECT 1 FROM [#ExampleAuditServer] WHERE [FindingSeverity]='INFO')
                                OR EXISTS(SELECT 1 FROM [#ExampleAuditDatabase] WHERE [FindingSeverity]='INFO')))
            THROW 55850,N'Der AuditConfiguration-Status-, Filter- oder Limitvertrag ist verletzt.',1;
        IF EXISTS(SELECT 1 FROM [#ExampleAuditAudits] AS [e]
                  WHERE COALESCE([e].[IsEnabled],1)<>0 OR [e].[FindingCode]<>'AUDIT_DISABLED' OR [e].[FindingSeverity]<>'MEDIUM'
                    OR COALESCE([e].[ServerSpecificationCount],-1)<>1 OR COALESCE([e].[DatabaseSpecificationCount],-1)<>1
                    OR NOT EXISTS(SELECT 1 FROM [sys].[server_audits] AS [a]
                                   WHERE [a].[audit_guid]=[e].[AuditId] AND [a].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[AuditName]
                                     AND [a].[type_desc] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[AuditTargetType]
                                     AND [a].[on_failure_desc] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[OnFailure]
                                     AND [a].[queue_delay]=[e].[QueueDelayMilliseconds]))
           OR EXISTS(SELECT 1 FROM [#ExampleAuditServer] AS [e]
                     WHERE COALESCE([e].[ActionCount],-1)<>1 OR NOT EXISTS(SELECT 1 FROM [sys].[server_audit_specifications] AS [s]
                        WHERE [s].[server_specification_id]=[e].[SpecificationId] AND [s].[audit_guid]=[e].[AuditId]
                          AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[SpecificationName] AND [s].[is_state_enabled]=[e].[IsEnabled]))
           OR EXISTS(SELECT 1 FROM [#ExampleAuditDatabase] AS [e]
                     WHERE [e].[DatabaseId]<>DB_ID() OR [e].[DatabaseName]<>DB_NAME() COLLATE SQL_Latin1_General_CP1_CS_AS
                       OR COALESCE([e].[ActionCount],-1)<>1 OR NOT EXISTS(SELECT 1 FROM [sys].[database_audit_specifications] AS [s]
                        WHERE [s].[database_specification_id]=[e].[SpecificationId] AND [s].[audit_guid]=[e].[AuditId]
                          AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[SpecificationName] AND [s].[is_state_enabled]=[e].[IsEnabled]))
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
                     WHERE [object_id] IN(OBJECT_ID(N'tempdb..#ExampleAuditServer'),OBJECT_ID(N'tempdb..#ExampleAuditDatabase'))
                       AND [name]=N'SpecificationId' AND [system_type_id]<>56)
            THROW 55852,N'Die positive AuditConfiguration-Ausgabe weicht von nativen Metadaten ab.',1;
        DELETE @Parity;
        INSERT @Parity VALUES
            ((SELECT * FROM [#ExampleAuditAudits] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.audits')),
            ((SELECT * FROM [#ExampleAuditServer] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.serverSpecifications')),
            ((SELECT * FROM [#ExampleAuditDatabase] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.databaseSpecifications')),
            ((SELECT * FROM [#ExampleAuditSources] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.sourceStatus')),
            ((SELECT * FROM [#ExampleAuditWarnings] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.warnings'));
    IF EXISTS(SELECT 1 FROM @Parity AS [p]
               WHERE LEFT(COALESCE([p].[ModuleJson],N''),1)<>N'['
                 OR (SELECT COUNT_BIG(*) FROM OPENJSON([p].[TableJson]))<>(SELECT COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]))
                 OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[TableJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
                           EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[ModuleJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
                 OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[ModuleJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
                           EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[TableJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS))
        THROW 55853,N'TABLE und JSON enthalten verschiedene AuditConfiguration-Ergebnisse.',1;

        DROP TABLE [#ExampleAuditAudits]; DROP TABLE [#ExampleAuditServer]; DROP TABLE [#ExampleAuditDatabase];
        DROP TABLE [#ExampleAuditSources]; DROP TABLE [#ExampleAuditWarnings];
        SET @Case+=1;
    END;
    ALTER DATABASE AUDIT SPECIFICATION [ExampleCollDatabaseOne] WITH(STATE=OFF);
    DROP DATABASE AUDIT SPECIFICATION [ExampleCollDatabaseOne]; DROP DATABASE AUDIT SPECIFICATION [ExampleCollDatabaseTwo];
    EXEC [master].[sys].[sp_executesql] N'ALTER SERVER AUDIT SPECIFICATION [ExampleCollServerOne] WITH(STATE=OFF);';
    EXEC [master].[sys].[sp_executesql] N'DROP SERVER AUDIT SPECIFICATION [ExampleCollServerOne];'; EXEC [master].[sys].[sp_executesql] N'DROP SERVER AUDIT SPECIFICATION [ExampleCollServerTwo];';
    EXEC [master].[sys].[sp_executesql] N'DROP SERVER AUDIT [ExampleCollAuditOne];'; EXEC [master].[sys].[sp_executesql] N'DROP SERVER AUDIT [ExampleCollAuditTwo];';
END TRY
BEGIN CATCH
    IF EXISTS(SELECT 1 FROM [sys].[database_audit_specifications] WHERE [name]=N'ExampleCollDatabaseOne')
    BEGIN ALTER DATABASE AUDIT SPECIFICATION [ExampleCollDatabaseOne] WITH(STATE=OFF); DROP DATABASE AUDIT SPECIFICATION [ExampleCollDatabaseOne]; END;
    IF EXISTS(SELECT 1 FROM [sys].[database_audit_specifications] WHERE [name]=N'ExampleCollDatabaseTwo')
        DROP DATABASE AUDIT SPECIFICATION [ExampleCollDatabaseTwo];
    IF EXISTS(SELECT 1 FROM [sys].[server_audit_specifications] WHERE [name]=N'ExampleCollServerOne')
    BEGIN EXEC [master].[sys].[sp_executesql] N'ALTER SERVER AUDIT SPECIFICATION [ExampleCollServerOne] WITH(STATE=OFF);'; EXEC [master].[sys].[sp_executesql] N'DROP SERVER AUDIT SPECIFICATION [ExampleCollServerOne];'; END;
    IF EXISTS(SELECT 1 FROM [sys].[server_audit_specifications] WHERE [name]=N'ExampleCollServerTwo')
        EXEC [master].[sys].[sp_executesql] N'DROP SERVER AUDIT SPECIFICATION [ExampleCollServerTwo];';
    IF EXISTS(SELECT 1 FROM [sys].[server_audits] WHERE [name]=N'ExampleCollAuditOne') EXEC [master].[sys].[sp_executesql] N'DROP SERVER AUDIT [ExampleCollAuditOne];';
    IF EXISTS(SELECT 1 FROM [sys].[server_audits] WHERE [name]=N'ExampleCollAuditTwo') EXEC [master].[sys].[sp_executesql] N'DROP SERVER AUDIT [ExampleCollAuditTwo];';
    THROW;
END CATCH;
GO

USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_AuditConfigurationAnalysis
Version      : 1.0.0
Stand        : 2026-09-19
Zweck        : Inventarisiert die sichtbare SQL-Server-Auditkonfiguration und
               deren zur Laufzeit gemeldeten Zustand.
Datenquellen : sys.server_audits, sys.server_audit_specifications,
               sys.server_audit_specification_details,
               sys.database_audit_specifications,
               sys.database_audit_specification_details, optional
               sys.dm_server_audit_status.
Datenschutz  : Liest weder Auditdateien noch Auditlog-Payloads, Dateipfade,
               Ereignisinhalte oder überwachte Nutzdaten.
Nebenwirkung : Read-only. Es werden keine Auditobjekte erstellt, gestartet,
               gestoppt, geändert oder gelöscht.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_AuditConfigurationAnalysis]
      @DatabaseNames                nvarchar(max) = NULL
    , @SystemdatenbankenEinbeziehen bit           = 0
    , @DatabaseNamePattern          nvarchar(4000)= NULL
    , @HighImpactConfirmed          bit           = 0
    , @AuditNames                   nvarchar(max) = NULL
    , @AuditNamePattern             nvarchar(4000)= NULL
    , @NurProblematisch             bit           = 0
    , @MaxZeilen                    int           = 1000
    , @LockTimeoutMs                int           = 0
    , @ResultSetArt                 varchar(16)   = 'CONSOLE'
    , @ResultTablesJson             nvarchar(max) = NULL
    , @JsonErzeugen                 bit           = 0
    , @Json                         nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen               bit           = 1
    , @Hilfe                        bit           = 0
    , @StatusCodeOut                varchar(40)   = NULL OUTPUT
    , @IsPartialOut                 bit           = NULL OUTPUT
    , @ErrorNumberOut               int           = NULL OUTPUT
    , @ErrorMessageOut              nvarchar(2048)= NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME();
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableRequested bit=CASE WHEN @OutputMode='TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0,@ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@CrossDatabaseRequested bit=0;
    DECLARE @AuditPatternMode varchar(8),@AuditPatternValue nvarchar(4000),@AuditPatternFlags varchar(8),@AuditPatternValid bit;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_AuditConfigurationAnalysis';
        PRINT N'Inventarisiert sichtbare Audit-, Spezifikations- und Runtime-Metadaten; Auditlog-Payloads, Dateipfade und Ereignisinhalte bleiben ausgeschlossen.';
        PRINT N'@DatabaseNames und @AuditNames verwenden bracket-aware Pipe-Listen; die Patternparameter unterstützen LIKE.';
        PRINT N'@MaxZeilen begrenzt jedes Fachresultset; NULL oder 0 bedeutet unbegrenzt.';
        PRINT N'TABLE erwartet Zuordnungen für audits, serverSpecifications, databaseSpecifications, sourceStatus oder warnings.';
        RETURN;
    END;

    CREATE TABLE [#AuditConfigurationAnalysis_ResultTables]([ResultName] sysname NOT NULL,[TargetTable] sysname NOT NULL);
    IF @TableRequested=1
        EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
             @AllowedResultNames=N'audits|serverSpecifications|databaseSpecifications|sourceStatus|warnings',
             @MappingTable=N'#AuditConfigurationAnalysis_ResultTables',@ThrowOnError=1;
    IF @TableRequested=1 OR @ConsoleResultRequested=1 SET @OutputMode='NONE';

    CREATE TABLE [#AuditConfigurationAnalysis_DatabaseCandidates]
    (
        [DatabaseId] int NOT NULL PRIMARY KEY,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StateDesc] nvarchar(60) NULL,[UserAccessDesc] nvarchar(60) NULL,[IsReadOnly] bit NULL,[CompatibilityLevel] tinyint NULL,
        [CollationName] sysname NULL,[RecoveryModelDesc] nvarchar(60) NULL,[IsSystemDatabase] bit NULL,[RequestedOrdinal] int NULL
    );
    CREATE TABLE [#AuditConfigurationAnalysis_DatabaseWarnings]([RequestedName] sysname NULL,[StatusCode] varchar(40) NOT NULL,[ErrorMessage] nvarchar(2048) NULL);
    CREATE TABLE [#AuditConfigurationAnalysis_AuditFilter]([NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY);
    CREATE TABLE [#AuditConfigurationAnalysis_Audits]
    (
        [AuditId] uniqueidentifier NOT NULL PRIMARY KEY,[AuditName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [AuditTargetType] nvarchar(60) NULL,[OnFailure] nvarchar(60) NULL,[QueueDelayMilliseconds] int NULL,
        [IsEnabled] bit NULL,[RuntimeStatus] nvarchar(60) NULL,[RuntimeStatusTime] datetime NULL,
        [ServerSpecificationCount] bigint NULL,[DatabaseSpecificationCount] bigint NULL,[FindingCode] varchar(64) NOT NULL,[FindingSeverity] varchar(16) NOT NULL,
        [EvidenceLimit] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#AuditConfigurationAnalysis_ServerSpecifications]
    (
        [SpecificationId] int NOT NULL PRIMARY KEY,[SpecificationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [AuditId] uniqueidentifier NULL,[AuditName] sysname NULL,[IsEnabled] bit NULL,[ActionCount] bigint NULL,
        [HasAllServerScope] bit NULL,[FindingCode] varchar(64) NOT NULL,[FindingSeverity] varchar(16) NOT NULL,[EvidenceLimit] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#AuditConfigurationAnalysis_DatabaseSpecifications]
    (
        [DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SpecificationId] int NOT NULL,[SpecificationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [AuditId] uniqueidentifier NULL,[AuditName] sysname NULL,[IsEnabled] bit NULL,[ActionCount] bigint NULL,
        [HasAllDatabaseScope] bit NULL,[FindingCode] varchar(64) NOT NULL,[FindingSeverity] varchar(16) NOT NULL,[EvidenceLimit] nvarchar(1000) NOT NULL,
        PRIMARY KEY([DatabaseId],[SpecificationId])
    );
    CREATE TABLE [#AuditConfigurationAnalysis_SourceStatus]
    (
        [SourceName] nvarchar(160) NOT NULL PRIMARY KEY,[StatusCode] varchar(40) NOT NULL,[IsPartial] bit NOT NULL,
        [ReturnedRowCount] bigint NULL,[Detail] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#AuditConfigurationAnalysis_Warnings]
    (
        [WarningScope] varchar(32) NOT NULL,[DatabaseName] sysname NULL,[AuditName] sysname NULL,
        [WarningCode] varchar(64) NOT NULL,[WarningSeverity] varchar(16) NOT NULL,[Detail] nvarchar(1000) NOT NULL
    );

    SELECT @AuditPatternMode=[PatternMode],@AuditPatternValue=[PatternValue],@AuditPatternFlags=[RegexFlags],@AuditPatternValid=[IsValid]
    FROM [monitor].[TVF_ParsePattern](@AuditNamePattern);
    IF @MaxZeilen<0 OR @LockTimeoutMs<0 OR @OutputMode NOT IN('RAW','CONSOLE','NONE')
       OR @AuditPatternValid=0 OR @AuditPatternMode IN('REGEX','REGEXI')
       OR (@AuditNames IS NOT NULL AND @AuditNamePattern IS NOT NULL)
       OR (@AuditNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@AuditNames) WHERE [IsValid]=0))
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'Ungueltiger Ausgabe-, Limit-, Auditnamen- oder Patternparameter. Regex wird von dieser Procedure nicht unterstuetzt.';

    IF @AuditNames IS NOT NULL
        INSERT [#AuditConfigurationAnalysis_AuditFilter]([NameValue])
        SELECT [NameValue] FROM [monitor].[TVF_ParseSqlNameList](@AuditNames) WHERE [IsValid]=1 GROUP BY [NameValue];

    IF @StatusCode='AVAILABLE'
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,
              @DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed,@AnalysisClass=NULL,
              @StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,
              @CandidateTable=N'#AuditConfigurationAnalysis_DatabaseCandidates',@WarningTable=N'#AuditConfigurationAnalysis_DatabaseWarnings';

    SET LOCK_TIMEOUT 0;
    IF @StatusCode='AVAILABLE'
    BEGIN
        BEGIN TRY
            INSERT [#AuditConfigurationAnalysis_Audits]
            ([AuditId],[AuditName],[AuditTargetType],[OnFailure],[QueueDelayMilliseconds],[IsEnabled],[RuntimeStatus],[RuntimeStatusTime],[ServerSpecificationCount],[DatabaseSpecificationCount],[FindingCode],[FindingSeverity],[EvidenceLimit])
            SELECT [a].[audit_guid],[a].[name],[a].[type_desc],[a].[on_failure_desc],[a].[queue_delay],[a].[is_state_enabled],
                   [r].[status_desc],[r].[status_time],
                   (SELECT COUNT_BIG(*) FROM [sys].[server_audit_specifications] [ss] WITH(NOLOCK) WHERE [ss].[audit_guid]=[a].[audit_guid]),
                   NULL,
                   CASE WHEN [a].[is_state_enabled]=0 THEN 'AUDIT_DISABLED' WHEN [r].[status_desc] IS NOT NULL AND [r].[status_desc] NOT IN(N'STARTED',N'RUNNING') THEN 'AUDIT_RUNTIME_NOT_STARTED' ELSE 'AUDIT_CONFIGURED' END,
                   CASE WHEN [a].[is_state_enabled]=0 THEN 'MEDIUM' WHEN [r].[status_desc] IS NOT NULL AND [r].[status_desc] NOT IN(N'STARTED',N'RUNNING') THEN 'MEDIUM' ELSE 'INFO' END,
                   N'Auditziele, Dateipfade und Auditereignisse werden nicht gelesen oder ausgegeben.'
            FROM [sys].[server_audits] [a] WITH(NOLOCK)
            LEFT JOIN [sys].[dm_server_audit_status] [r] WITH(NOLOCK) ON [r].[audit_id]=[a].[audit_id]
            WHERE (@AuditNames IS NULL OR EXISTS(SELECT 1 FROM [#AuditConfigurationAnalysis_AuditFilter] [f] WHERE [f].[NameValue]=[a].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))
              AND (@AuditPatternMode IN('NONE','REGEX','REGEXI') OR [a].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @AuditPatternValue COLLATE SQL_Latin1_General_CP1_CS_AS);
            INSERT [#AuditConfigurationAnalysis_SourceStatus] VALUES(N'sys.server_audits + sys.dm_server_audit_status','AVAILABLE',0,@@ROWCOUNT,N'Konfiguration und sichtbarer Runtimezustand; keine Auditpayloads oder Pfade.');
        END TRY
        BEGIN CATCH
            INSERT [#AuditConfigurationAnalysis_SourceStatus] VALUES(N'sys.server_audits + sys.dm_server_audit_status',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,15562) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,NULL,N'Auditkonfiguration oder Runtimezustand war nicht vollstaendig lesbar.');
            SELECT @IsPartial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
        END CATCH;

        BEGIN TRY
            INSERT [#AuditConfigurationAnalysis_ServerSpecifications]
            ([SpecificationId],[SpecificationName],[AuditId],[AuditName],[IsEnabled],[ActionCount],[HasAllServerScope],[FindingCode],[FindingSeverity],[EvidenceLimit])
            SELECT [s].[server_specification_id],[s].[name],[s].[audit_guid],[a].[name],[s].[is_state_enabled],COUNT_BIG([d].[audit_action_id]),
                   CONVERT(bit,MAX(CASE WHEN [d].[audit_action_name] LIKE N'%ALL SERVER%' THEN 1 ELSE 0 END)),
                   CASE WHEN [s].[is_state_enabled]=0 THEN 'SERVER_SPECIFICATION_DISABLED' WHEN COUNT_BIG([d].[audit_action_id])=0 THEN 'SERVER_SPECIFICATION_WITHOUT_ACTION' ELSE 'SERVER_SPECIFICATION_CONFIGURED' END,
                   CASE WHEN [s].[is_state_enabled]=0 OR COUNT_BIG([d].[audit_action_id])=0 THEN 'MEDIUM' ELSE 'INFO' END,
                   N'Nur Aktionsanzahl und Scopehinweis; keine Auditereignisse oder ueberwachten Nutzdaten.'
            FROM [sys].[server_audit_specifications] [s] WITH(NOLOCK)
            LEFT JOIN [sys].[server_audits] [a] WITH(NOLOCK) ON [a].[audit_guid]=[s].[audit_guid]
            LEFT JOIN [sys].[server_audit_specification_details] [d] WITH(NOLOCK) ON [d].[server_specification_id]=[s].[server_specification_id]
            WHERE @AuditNames IS NULL OR EXISTS(SELECT 1 FROM [#AuditConfigurationAnalysis_AuditFilter] [f] WHERE [f].[NameValue]=[a].[name] COLLATE SQL_Latin1_General_CP1_CS_AS)
            GROUP BY [s].[server_specification_id],[s].[name],[s].[audit_guid],[a].[name],[s].[is_state_enabled];
            INSERT [#AuditConfigurationAnalysis_SourceStatus] VALUES(N'sys.server_audit_specifications + sys.server_audit_specification_details','AVAILABLE',0,@@ROWCOUNT,N'Serverseitige Spezifikationsmetadaten werden aggregiert; Detailaktionen werden nicht ausgegeben.');
        END TRY
        BEGIN CATCH
            INSERT [#AuditConfigurationAnalysis_SourceStatus] VALUES(N'sys.server_audit_specifications + sys.server_audit_specification_details',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,15562) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,NULL,N'Serverseitige Spezifikationsmetadaten waren nicht vollstaendig lesbar.');
            SELECT @IsPartial=1,@ErrorNumber=COALESCE(@ErrorNumber,ERROR_NUMBER()),@ErrorMessage=COALESCE(@ErrorMessage,ERROR_MESSAGE());
        END CATCH;

        DECLARE @DatabaseId int,@DatabaseName sysname,@Sql nvarchar(max),@HasAuditNames bit=CASE WHEN @AuditNames IS NULL THEN 0 ELSE 1 END;
        DECLARE [audit_database_cursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId],[DatabaseName] FROM [#AuditConfigurationAnalysis_DatabaseCandidates] WHERE [StateDesc]=N'ONLINE' ORDER BY [DatabaseId];
        OPEN [audit_database_cursor]; FETCH NEXT FROM [audit_database_cursor] INTO @DatabaseId,@DatabaseName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            BEGIN TRY
                SET @Sql=N'INSERT [#AuditConfigurationAnalysis_DatabaseSpecifications]([DatabaseId],[DatabaseName],[SpecificationId],[SpecificationName],[AuditId],[AuditName],[IsEnabled],[ActionCount],[HasAllDatabaseScope],[FindingCode],[FindingSeverity],[EvidenceLimit])
                SELECT @pDatabaseId,@pDatabaseName,[s].[database_specification_id],[s].[name],[s].[audit_guid],[a].[name],[s].[is_state_enabled],COUNT_BIG([d].[audit_action_id]),CONVERT(bit,MAX(CASE WHEN [d].[audit_action_name] LIKE N''%ALL DATABASE%'' THEN 1 ELSE 0 END)),
                CASE WHEN [s].[is_state_enabled]=0 THEN ''DATABASE_SPECIFICATION_DISABLED'' WHEN COUNT_BIG([d].[audit_action_id])=0 THEN ''DATABASE_SPECIFICATION_WITHOUT_ACTION'' ELSE ''DATABASE_SPECIFICATION_CONFIGURED'' END,
                CASE WHEN [s].[is_state_enabled]=0 OR COUNT_BIG([d].[audit_action_id])=0 THEN ''MEDIUM'' ELSE ''INFO'' END,N''Nur Aktionsanzahl und Scopehinweis; keine Auditereignisse oder ueberwachten Nutzdaten.''
                FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[database_audit_specifications] [s] WITH(NOLOCK)
                LEFT JOIN [sys].[server_audits] [a] WITH(NOLOCK) ON [a].[audit_guid]=[s].[audit_guid]
                LEFT JOIN '+QUOTENAME(@DatabaseName)+N'.[sys].[database_audit_specification_details] [d] WITH(NOLOCK) ON [d].[database_specification_id]=[s].[database_specification_id]
                WHERE (@pAuditNames=0 OR EXISTS(SELECT 1 FROM [#AuditConfigurationAnalysis_AuditFilter] [f] WHERE [f].[NameValue]=[a].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))
                GROUP BY [s].[database_specification_id],[s].[name],[s].[audit_guid],[a].[name],[s].[is_state_enabled];';
                EXEC [sys].[sp_executesql] @Sql,N'@pDatabaseId int,@pDatabaseName sysname,@pAuditNames bit',@pDatabaseId=@DatabaseId,@pDatabaseName=@DatabaseName,@pAuditNames=@HasAuditNames;
            END TRY
            BEGIN CATCH
                SET @IsPartial=1;
                INSERT [#AuditConfigurationAnalysis_DatabaseWarnings] VALUES(@DatabaseName,CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916,15562) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,N'Datenbank-Auditspezifikationen waren fuer diese Datenbank nicht lesbar.');
            END CATCH;
            FETCH NEXT FROM [audit_database_cursor] INTO @DatabaseId,@DatabaseName;
        END;
        CLOSE [audit_database_cursor]; DEALLOCATE [audit_database_cursor];
        INSERT [#AuditConfigurationAnalysis_SourceStatus]
        SELECT N'sys.database_audit_specifications + sys.database_audit_specification_details',CASE WHEN @IsPartial=1 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END,@IsPartial,COUNT_BIG(*),N'Datenbanklokale Spezifikationsmetadaten werden je sichtbarer Online-Datenbank isoliert gelesen.'
        FROM [#AuditConfigurationAnalysis_DatabaseSpecifications];

        UPDATE [a] SET [DatabaseSpecificationCount]=[x].[CountValue]
        FROM [#AuditConfigurationAnalysis_Audits] [a]
        OUTER APPLY(SELECT COUNT_BIG(*) [CountValue] FROM [#AuditConfigurationAnalysis_DatabaseSpecifications] [d] WHERE [d].[AuditId]=[a].[AuditId]) [x];
        INSERT [#AuditConfigurationAnalysis_Warnings]
        SELECT 'AUDIT',NULL,[AuditName],[FindingCode],[FindingSeverity],[EvidenceLimit] FROM [#AuditConfigurationAnalysis_Audits] WHERE [FindingSeverity]<>'INFO'
        UNION ALL SELECT 'SERVER_SPECIFICATION',NULL,[AuditName],[FindingCode],[FindingSeverity],[EvidenceLimit] FROM [#AuditConfigurationAnalysis_ServerSpecifications] WHERE [FindingSeverity]<>'INFO'
        UNION ALL SELECT 'DATABASE_SPECIFICATION',[DatabaseName],[AuditName],[FindingCode],[FindingSeverity],[EvidenceLimit] FROM [#AuditConfigurationAnalysis_DatabaseSpecifications] WHERE [FindingSeverity]<>'INFO';

        IF EXISTS(SELECT 1 FROM [#AuditConfigurationAnalysis_SourceStatus] WHERE [IsPartial]=1) SELECT @StatusCode='AVAILABLE_LIMITED',@IsPartial=1;
        ELSE IF EXISTS(SELECT 1 FROM [#AuditConfigurationAnalysis_Warnings] WHERE [WarningSeverity]='MEDIUM') SET @StatusCode='AVAILABLE_WITH_FINDING';
    END;

    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
    IF @JsonErzeugen=1
    BEGIN
        DECLARE @Meta nvarchar(max)=(SELECT N'AuditConfigurationAnalysis' [resultName],1 [schemaVersion],@Now [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@CrossDatabaseRequested [crossDatabaseRequested] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"audits":',COALESCE((SELECT TOP(@Limit) * FROM [#AuditConfigurationAnalysis_Audits] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [AuditName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),N',"serverSpecifications":',COALESCE((SELECT TOP(@Limit) * FROM [#AuditConfigurationAnalysis_ServerSpecifications] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [SpecificationName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),N',"databaseSpecifications":',COALESCE((SELECT TOP(@Limit) * FROM [#AuditConfigurationAnalysis_DatabaseSpecifications] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [DatabaseName],[SpecificationName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),N',"sourceStatus":',COALESCE((SELECT * FROM [#AuditConfigurationAnalysis_SourceStatus] ORDER BY [SourceName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),N',"warnings":',COALESCE((SELECT * FROM [#AuditConfigurationAnalysis_Warnings] ORDER BY [WarningScope],[DatabaseName],[AuditName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),N'}');
    END;
    IF @OutputMode='RAW'
    BEGIN
        SELECT N'USP_AuditConfigurationAnalysis' [ModuleName],@Now [CollectionTimeUtc],@StatusCode [StatusCode],@IsPartial [IsPartial],@ErrorNumber [ErrorNumber],@ErrorMessage [ErrorMessage];
        SELECT TOP(@Limit) * FROM [#AuditConfigurationAnalysis_Audits] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [AuditName];
        SELECT TOP(@Limit) * FROM [#AuditConfigurationAnalysis_ServerSpecifications] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [SpecificationName];
        SELECT TOP(@Limit) * FROM [#AuditConfigurationAnalysis_DatabaseSpecifications] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [DatabaseName],[SpecificationName];
        SELECT * FROM [#AuditConfigurationAnalysis_SourceStatus] ORDER BY [SourceName]; SELECT * FROM [#AuditConfigurationAnalysis_Warnings] ORDER BY [WarningScope],[DatabaseName],[AuditName];
    END
    ELSE IF @OutputMode='CONSOLE'
    BEGIN
        SELECT N'Auditkonfiguration' [Ergebnis],@Now [Stand_UTC],@StatusCode [Status],@IsPartial [Teilweise],@ErrorMessage [Hinweis];
        SELECT TOP(@Limit) N'Audit' [Ergebnis],[AuditName] [Audit],[AuditTargetType] [Zieltyp],[IsEnabled] [Aktiv],[RuntimeStatus] [Runtime_Status],[ServerSpecificationCount] [Server_Spezifikationen],[DatabaseSpecificationCount] [Datenbank_Spezifikationen],[FindingCode] [Befund],[FindingSeverity] [Prioritaet],[EvidenceLimit] [Evidenzgrenze] FROM [#AuditConfigurationAnalysis_Audits] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [AuditName];
        SELECT TOP(@Limit) N'Server-Auditspezifikation' [Ergebnis],[SpecificationName] [Spezifikation],[AuditName] [Audit],[IsEnabled] [Aktiv],[ActionCount] [Aktionsanzahl],[FindingCode] [Befund],[FindingSeverity] [Prioritaet] FROM [#AuditConfigurationAnalysis_ServerSpecifications] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [SpecificationName];
        SELECT TOP(@Limit) N'Datenbank-Auditspezifikation' [Ergebnis],[DatabaseName] [Datenbank],[SpecificationName] [Spezifikation],[AuditName] [Audit],[IsEnabled] [Aktiv],[ActionCount] [Aktionsanzahl],[FindingCode] [Befund],[FindingSeverity] [Prioritaet] FROM [#AuditConfigurationAnalysis_DatabaseSpecifications] WHERE @NurProblematisch=0 OR [FindingSeverity]<>'INFO' ORDER BY [DatabaseName],[SpecificationName];
        SELECT N'Quellenstatus' [Ergebnis],[SourceName] [Quelle],[StatusCode] [Status],[IsPartial] [Teilweise],[Detail] [Hinweis] FROM [#AuditConfigurationAnalysis_SourceStatus] ORDER BY [SourceName];
        SELECT N'Warnung' [Ergebnis],[WarningScope] [Scope],[DatabaseName] [Datenbank],[AuditName] [Audit],[WarningCode] [Code],[WarningSeverity] [Prioritaet],[Detail] [Hinweis] FROM [#AuditConfigurationAnalysis_Warnings] ORDER BY [WarningScope],[DatabaseName],[AuditName];
    END;
    IF @ConsoleResultRequested=1 EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#AuditConfigurationAnalysis_Audits',@ResultLabel=N'AuditConfigurationAnalysis',@EmptyMessage=N'Keine sichtbaren Auditkonfigurationen';
    IF @TableRequested=1
    BEGIN
        DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
        DECLARE [audit_table_cursor] CURSOR LOCAL FAST_FORWARD FOR SELECT [ResultName],[TargetTable] FROM [#AuditConfigurationAnalysis_ResultTables] ORDER BY [ResultName];
        OPEN [audit_table_cursor]; FETCH NEXT FROM [audit_table_cursor] INTO @ResultName,@TargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @SourceTable=CASE @ResultName WHEN N'audits' THEN N'#AuditConfigurationAnalysis_Audits' WHEN N'serverSpecifications' THEN N'#AuditConfigurationAnalysis_ServerSpecifications' WHEN N'databaseSpecifications' THEN N'#AuditConfigurationAnalysis_DatabaseSpecifications' WHEN N'sourceStatus' THEN N'#AuditConfigurationAnalysis_SourceStatus' ELSE N'#AuditConfigurationAnalysis_Warnings' END;
            EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,@ThrowOnError=1;
            FETCH NEXT FROM [audit_table_cursor] INTO @ResultName,@TargetTable;
        END;
        CLOSE [audit_table_cursor]; DEALLOCATE [audit_table_cursor];
    END;
END;
GO

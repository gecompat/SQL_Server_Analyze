USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentSessions
Version      : 2.1.0
Stand        : 2026-07-21
Typ          : Stored Procedure
Zweck        : Liefert aktuelle Sessions mit exakten Mehrfachfiltern, Pattern-
               Filtern und RAW-, CONSOLE- oder JSON-Ausgabe.
SQL-Version  : SQL Server 2019 oder neuer; Regex ab SQL Server 2025 und
               Compatibility Level 170.
Listen       : | trennt außerhalb von [...]. Werte bleiben case-sensitiv.
Steuerwerte  : werden getrimmt und case-insensitiv normalisiert.
Resultsets   : RAW: Status, Sessions. CONSOLE: lesbare Status-/Sessionansicht.
               NONE: keine Resultsets. JSON: meta, sessions, warnings.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentSessions]
      @SessionIds                   nvarchar(max)  = NULL
    , @EigeneSessionsModus          varchar(16)    = 'ALLE'
    , @AktuelleSessionEinbeziehen   bit            = 0
    , @SystemSessionsEinbeziehen    bit            = 0
    , @ToolHintergrundabfragenEinbeziehen bit       = 0
    , @InaktiveSessionsEinbeziehen  bit            = 1
    , @LoginNames                   nvarchar(max)  = NULL
    , @LoginNamePattern             nvarchar(4000) = NULL
    , @HostNames                    nvarchar(max)  = NULL
    , @HostNamePattern              nvarchar(4000) = NULL
    , @ProgramNames                 nvarchar(max)  = NULL
    , @ProgramNamePattern           nvarchar(4000) = NULL
    , @DatabaseNames                nvarchar(max)  = NULL
    , @DatabaseNamePattern          nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @MitSqlText                   bit            = 0
    , @MaxSqlTextZeichen            int            = 2000
    , @MaxZeilen                    int            = 500
    , @Sortierung                   varchar(32)    = 'CPU'
    , @ResultSetArt                 varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                 bit            = 0
    , @Json                         nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen               bit            = 1
    , @Hilfe                        bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json = NULL;

    DECLARE @ModuleName sysname = N'USP_CurrentSessions';
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @RowCount bigint = 0;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Detail nvarchar(2000) = NULL;
    DECLARE @RequiredPermission nvarchar(256) = CASE WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) >= 16 THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END;
    DECLARE @HasFullView bit = CASE WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1 THEN 1 WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) >= 16 THEN COALESCE(HAS_PERMS_BY_NAME(NULL,N'SERVER',N'VIEW SERVER PERFORMANCE STATE'),0) ELSE COALESCE(HAS_PERMS_BY_NAME(NULL,N'SERVER',N'VIEW SERVER STATE'),0) END;
    DECLARE @ResultSetArtNormalisiert varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'sessions',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @CandidateMaxZeilen bigint;
    DECLARE @MonitorPrintMessage nvarchar(2048);

    SET @EigeneSessionsModus = UPPER(LTRIM(RTRIM(COALESCE(@EigeneSessionsModus,'ALLE'))));
    SET @Sortierung = UPPER(LTRIM(RTRIM(COALESCE(@Sortierung,'CPU'))));

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CurrentSessions';
        PRINT N'@SessionIds: Pipe-Liste, z. B. N''57|61''.';
        PRINT N'@ToolHintergrundabfragenEinbeziehen=0 blendet erkannte Object-Explorer-, Copilot- und SQL-Prompt-Hintergrundsessions standardmäßig aus; 1 zeigt sie samt Klassifikation.';
        PRINT N'@LoginNames/@HostNames/@ProgramNames/@DatabaseNames: exakte bracket-aware Pipe-Listen.';
        PRINT N'Die jeweiligen ...Pattern-Parameter akzeptieren LIKE, like:, regex: oder regexi: und sind mit der exakten Liste gegenseitig exklusiv.';
        PRINT N'@MaxZeilen: positiv begrenzt; NULL/0 = unbegrenzt; negativ = INVALID_PARAMETER.';
        PRINT N'@MaxSqlTextZeichen: positiv begrenzt die Darstellung; NULL/0 liefert vollständige Texte.';
        PRINT N'@ResultSetArt: CONSOLE (Default), RAW, TABLE oder NONE; Groß-/Kleinschreibung ist egal.';
        PRINT N'@JsonErzeugen=1 erzeugt ein JSON-Envelope in @Json OUTPUT.';
        RETURN;
    END;

    CREATE TABLE [#CurrentSessions_SessionIdFilter]
    (
        [SessionId] smallint NOT NULL PRIMARY KEY
    );
    CREATE TABLE [#CurrentSessions_StringFilter]
    (
          [FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StringValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([FilterType],[StringValue])
    );

    DECLARE @LoginMode varchar(8), @LoginPattern nvarchar(4000), @LoginFlags varchar(8), @LoginValid bit;
    DECLARE @HostMode varchar(8), @HostPattern nvarchar(4000), @HostFlags varchar(8), @HostValid bit;
    DECLARE @ProgramMode varchar(8), @ProgramPattern nvarchar(4000), @ProgramFlags varchar(8), @ProgramValid bit;
    DECLARE @DatabaseMode varchar(8), @DatabasePattern nvarchar(4000), @DatabaseFlags varchar(8), @DatabaseValid bit;

    BEGIN TRY
        SELECT @LoginMode=[PatternMode],@LoginPattern=[PatternValue],@LoginFlags=[RegexFlags],@LoginValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@LoginNamePattern);
        SELECT @HostMode=[PatternMode],@HostPattern=[PatternValue],@HostFlags=[RegexFlags],@HostValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@HostNamePattern);
        SELECT @ProgramMode=[PatternMode],@ProgramPattern=[PatternValue],@ProgramFlags=[RegexFlags],@ProgramValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ProgramNamePattern);
        SELECT @DatabaseMode=[PatternMode],@DatabasePattern=[PatternValue],@DatabaseFlags=[RegexFlags],@DatabaseValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@DatabaseNamePattern);
    END TRY
    BEGIN CATCH
        SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@IsPartial=1,
               @StatusCode=CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                                WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                                ELSE 'ERROR_HANDLED' END;
    END CATCH;

    IF @StatusCode='AVAILABLE' AND @SessionIds IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM [monitor].[TVF_ParseBigintList](@SessionIds) WHERE [IsValid]=0 OR [NumberValue] NOT BETWEEN 1 AND 32767)
            SET @StatusCode='INVALID_PARAMETER';
        ELSE
            INSERT [#CurrentSessions_SessionIdFilter]([SessionId])
            SELECT CONVERT(smallint,[NumberValue]) FROM [monitor].[TVF_ParseBigintList](@SessionIds)
            GROUP BY [NumberValue];
    END;

    IF @StatusCode='AVAILABLE'
       AND ((@LoginNames IS NOT NULL AND @LoginNamePattern IS NOT NULL)
         OR (@HostNames IS NOT NULL AND @HostNamePattern IS NOT NULL)
         OR (@ProgramNames IS NOT NULL AND @ProgramNamePattern IS NOT NULL)
         OR (@DatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL)
         OR @LoginValid=0 OR @HostValid=0 OR @ProgramValid=0 OR @DatabaseValid=0)
        SET @StatusCode='INVALID_PARAMETER';

    IF @StatusCode='AVAILABLE'
       AND ((@LoginNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseStringList](@LoginNames) WHERE [IsValid]=0 OR LEN([StringValue])>128))
         OR (@HostNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseStringList](@HostNames) WHERE [IsValid]=0 OR LEN([StringValue])>128))
         OR (@ProgramNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseStringList](@ProgramNames) WHERE [IsValid]=0 OR LEN([StringValue])>128))
         OR (@DatabaseNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@DatabaseNames) WHERE [IsValid]=0)))
        SET @StatusCode='INVALID_PARAMETER';

    IF @StatusCode='AVAILABLE'
    BEGIN
        INSERT [#CurrentSessions_StringFilter]([FilterType],[StringValue]) SELECT 'LOGIN',[StringValue] FROM [monitor].[TVF_ParseStringList](@LoginNames) WHERE [IsValid]=1 GROUP BY [StringValue];
        INSERT [#CurrentSessions_StringFilter]([FilterType],[StringValue]) SELECT 'HOST',[StringValue] FROM [monitor].[TVF_ParseStringList](@HostNames) WHERE [IsValid]=1 GROUP BY [StringValue];
        INSERT [#CurrentSessions_StringFilter]([FilterType],[StringValue]) SELECT 'PROGRAM',[StringValue] FROM [monitor].[TVF_ParseStringList](@ProgramNames) WHERE [IsValid]=1 GROUP BY [StringValue];
        INSERT [#CurrentSessions_StringFilter]([FilterType],[StringValue]) SELECT 'DATABASE',[NameValue] FROM [monitor].[TVF_ParseSqlNameList](@DatabaseNames) WHERE [IsValid]=1 GROUP BY [NameValue];
    END;

    DECLARE @HasRegex bit = CASE WHEN @LoginMode IN('REGEX','REGEXI') OR @HostMode IN('REGEX','REGEXI') OR @ProgramMode IN('REGEX','REGEXI') OR @DatabaseMode IN('REGEX','REGEXI') THEN 1 ELSE 0 END;
    IF @StatusCode='AVAILABLE' AND @HasRegex=1
       AND (TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17 OR COALESCE((SELECT [compatibility_level] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID()),0)<170)
    BEGIN
        SET @StatusCode='UNAVAILABLE_FEATURE';
        SET @ErrorMessage=N'Regex benötigt SQL Server 2025 und Compatibility Level 170 für die Installationsdatenbank.';
    END;

    IF @StatusCode='AVAILABLE'
       AND (@EigeneSessionsModus NOT IN('ALLE','NUR','AUSSCHLIESSEN') OR @Sortierung NOT IN('CPU','READS','WRITES','LOGIN','SESSION') OR @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') OR @MaxZeilen<0 OR @MaxSqlTextZeichen<0 OR @ToolHintergrundabfragenEinbeziehen IS NULL OR @ToolHintergrundabfragenEinbeziehen NOT IN(0,1))
    BEGIN
        SET @StatusCode='INVALID_PARAMETER';
        SET @ErrorMessage=N'Mindestens ein Steuerparameter ist ungültig.';
    END;

    IF @StatusCode='INVALID_PARAMETER' AND @ErrorMessage IS NULL
        SET @ErrorMessage=N'Ungültige Liste, Kombination oder Patternangabe.';

    CREATE TABLE [#CurrentSessions_Result]
    (
          [SessionId] smallint NOT NULL, [RequestId] int NULL, [IsUserProcess] bit NOT NULL
        , [SessionStatus] nvarchar(30) NULL, [RequestStatus] nvarchar(30) NULL
        , [LoginName] nvarchar(128) NULL, [OriginalLoginName] nvarchar(128) NULL
        , [HostName] nvarchar(128) NULL, [ProgramName] nvarchar(128) NULL
        , [IsToolBackgroundQuery] bit NOT NULL
        , [ToolBackgroundRuleCode] varchar(64) NULL
        , [ToolBackgroundCategory] varchar(40) NULL
        , [ToolBackgroundDetection] varchar(40) NULL
        , [ToolBackgroundConfidence] varchar(16) NULL
        , [ClientInterfaceName] nvarchar(32) NULL, [LoginTime] datetime NULL
        , [LastRequestStartTime] datetime NULL, [LastRequestEndTime] datetime NULL
        , [DatabaseId] smallint NULL, [DatabaseName] sysname NULL
        , [OpenTransactionCount] int NULL, [TransactionIsolationLevel] nvarchar(40) NULL
        , [SessionCpuMs] int NULL, [SessionReads] bigint NULL, [SessionWrites] bigint NULL
        , [SessionLogicalReads] bigint NULL, [SessionMemoryMb] decimal(19,2) NULL
        , [SessionRowCount] bigint NULL, [RequestCpuMs] int NULL, [RequestElapsedMs] int NULL
        , [RequestLogicalReads] bigint NULL, [RequestReads] bigint NULL, [RequestWrites] bigint NULL
        , [BlockingSessionId] smallint NULL, [WaitType] nvarchar(120) NULL, [WaitTimeMs] int NULL
        , [WaitResource] nvarchar(256) NULL, [PercentComplete] real NULL
        , [ClientNetAddress] varchar(48) NULL, [NetTransport] nvarchar(40) NULL
        , [ProtocolType] nvarchar(40) NULL, [EncryptOption] nvarchar(40) NULL
        , [AuthScheme] nvarchar(40) NULL
        , [CurrentStatementCharacters] bigint NULL, [CurrentStatementBytes] bigint NULL
        , [CurrentStatementIsTruncated] bit NOT NULL DEFAULT(0), [CurrentStatement] nvarchar(max) NULL
        , [BatchTextCharacters] bigint NULL, [BatchTextBytes] bigint NULL
        , [BatchTextIsTruncated] bit NOT NULL DEFAULT(0), [BatchText] nvarchar(max) NULL
    );

    SET @CandidateMaxZeilen = CASE WHEN @HasRegex=1 OR @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen)+1 END;

    IF @StatusCode='AVAILABLE'
    BEGIN TRY
        INSERT [#CurrentSessions_Result]
        SELECT TOP (@CandidateMaxZeilen)
              [s].[session_id],[r].[request_id],[s].[is_user_process],[s].[status],[r].[status]
            , [s].[login_name],[s].[original_login_name],[s].[host_name],[s].[program_name]
            , [tool].[IsToolBackgroundQuery],[tool].[ToolBackgroundRuleCode]
            , [tool].[ToolBackgroundCategory]
            , [tool].[ToolBackgroundDetection],[tool].[ToolBackgroundConfidence]
            , [s].[client_interface_name]
            , [s].[login_time],[s].[last_request_start_time],[s].[last_request_end_time],[r].[database_id],[d].[name]
            , [s].[open_transaction_count]
            , CASE [s].[transaction_isolation_level] WHEN 0 THEN N'Unspecified' WHEN 1 THEN N'ReadUncommitted' WHEN 2 THEN N'ReadCommitted' WHEN 3 THEN N'RepeatableRead' WHEN 4 THEN N'Serializable' WHEN 5 THEN N'Snapshot' END
            , [s].[cpu_time],[s].[reads],[s].[writes],[s].[logical_reads],CONVERT(decimal(19,2),[s].[memory_usage]*8.0/1024.0),[s].[row_count]
            , [r].[cpu_time],[r].[total_elapsed_time],[r].[logical_reads],[r].[reads],[r].[writes],NULLIF([r].[blocking_session_id],0)
            , [r].[wait_type],[r].[wait_time],[r].[wait_resource],[r].[percent_complete]
            , [c].[client_net_address],[c].[net_transport],[c].[protocol_type],[c].[encrypt_option],[c].[auth_scheme]
            , NULL,NULL,CONVERT(bit,0),CASE WHEN @MitSqlText=1 THEN [st].[StatementText] END
            , NULL,NULL,CONVERT(bit,0),CASE WHEN @MitSqlText=1 THEN [t].[text] END
        FROM [sys].[dm_exec_sessions] AS [s] WITH (NOLOCK)
        LEFT JOIN [sys].[dm_exec_connections] AS [c] WITH (NOLOCK) ON [c].[session_id]=[s].[session_id]
        OUTER APPLY (SELECT TOP (1) [rr].* FROM [sys].[dm_exec_requests] AS [rr] WITH (NOLOCK) WHERE [rr].[session_id]=[s].[session_id] ORDER BY [rr].[request_id]) AS [r]
        LEFT JOIN [sys].[databases] AS [d] WITH (NOLOCK) ON [d].[database_id]=[r].[database_id]
        OUTER APPLY [sys].[dm_exec_sql_text](CASE WHEN @MitSqlText=1 THEN COALESCE([r].[sql_handle],[c].[most_recent_sql_handle]) END) AS [t]
        OUTER APPLY [monitor].[TVF_StatementText]([t].[text],[r].[statement_start_offset],[r].[statement_end_offset]) AS [st]
        CROSS APPLY [monitor].[TVF_ToolBackgroundQueryInfo]([s].[program_name]) AS [tool]
        WHERE (NOT EXISTS(SELECT 1 FROM [#CurrentSessions_SessionIdFilter]) OR EXISTS(SELECT 1 FROM [#CurrentSessions_SessionIdFilter] AS [f] WHERE [f].[SessionId]=[s].[session_id]))
          AND (@AktuelleSessionEinbeziehen=1 OR [s].[session_id]<>@@SPID)
          AND (@SystemSessionsEinbeziehen=1 OR [s].[is_user_process]=1)
          AND (@ToolHintergrundabfragenEinbeziehen=1 OR [tool].[IsToolBackgroundQuery]=0)
          AND (@InaktiveSessionsEinbeziehen=1 OR [r].[session_id] IS NOT NULL OR [s].[open_transaction_count]>0)
          AND (@EigeneSessionsModus='ALLE' OR (@EigeneSessionsModus='NUR' AND [s].[original_login_name]=ORIGINAL_LOGIN()) OR (@EigeneSessionsModus='AUSSCHLIESSEN' AND ISNULL([s].[original_login_name],N'')<>ORIGINAL_LOGIN()))
          AND (NOT EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] WHERE [FilterType]='LOGIN') OR EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] AS [f] WHERE [f].[FilterType]='LOGIN' AND [f].[StringValue]=[s].[login_name] COLLATE SQL_Latin1_General_CP1_CS_AS))
          AND (NOT EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] WHERE [FilterType]='HOST') OR EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] AS [f] WHERE [f].[FilterType]='HOST' AND [f].[StringValue]=[s].[host_name] COLLATE SQL_Latin1_General_CP1_CS_AS))
          AND (NOT EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] WHERE [FilterType]='PROGRAM') OR EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] AS [f] WHERE [f].[FilterType]='PROGRAM' AND [f].[StringValue]=[s].[program_name] COLLATE SQL_Latin1_General_CP1_CS_AS))
          AND (NOT EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] WHERE [FilterType]='DATABASE') OR EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] AS [f] WHERE [f].[FilterType]='DATABASE' AND [f].[StringValue]=[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))
          AND (@LoginMode<>'LIKE' OR [s].[login_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @LoginPattern COLLATE SQL_Latin1_General_CP1_CS_AS)
          AND (@HostMode<>'LIKE' OR [s].[host_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @HostPattern COLLATE SQL_Latin1_General_CP1_CS_AS)
          AND (@ProgramMode<>'LIKE' OR [s].[program_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @ProgramPattern COLLATE SQL_Latin1_General_CP1_CS_AS)
          AND (@DatabaseMode<>'LIKE' OR [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @DatabasePattern COLLATE SQL_Latin1_General_CP1_CS_AS)
        ORDER BY CASE WHEN @Sortierung='CPU' THEN COALESCE([r].[cpu_time],[s].[cpu_time]) END DESC,
                 CASE WHEN @Sortierung='READS' THEN COALESCE([r].[logical_reads],[s].[logical_reads]) END DESC,
                 CASE WHEN @Sortierung='WRITES' THEN COALESCE([r].[writes],[s].[writes]) END DESC,
                 CASE WHEN @Sortierung='LOGIN' THEN DATEDIFF_BIG(SECOND,'20000101',[s].[login_time]) END DESC,
                 CASE WHEN @Sortierung='SESSION' THEN [s].[session_id] END,[s].[session_id];

        IF @HasRegex=1
        BEGIN
            DECLARE @Sql nvarchar(max)=N'';
            IF @LoginMode IN('REGEX','REGEXI') SET @Sql+=N'DELETE FROM [#CurrentSessions_Result] WHERE [LoginName] IS NULL OR NOT REGEXP_LIKE([LoginName],@LoginPattern,@LoginFlags);';
            IF @HostMode IN('REGEX','REGEXI') SET @Sql+=N'DELETE FROM [#CurrentSessions_Result] WHERE [HostName] IS NULL OR NOT REGEXP_LIKE([HostName],@HostPattern,@HostFlags);';
            IF @ProgramMode IN('REGEX','REGEXI') SET @Sql+=N'DELETE FROM [#CurrentSessions_Result] WHERE [ProgramName] IS NULL OR NOT REGEXP_LIKE([ProgramName],@ProgramPattern,@ProgramFlags);';
            IF @DatabaseMode IN('REGEX','REGEXI') SET @Sql+=N'DELETE FROM [#CurrentSessions_Result] WHERE [DatabaseName] IS NULL OR NOT REGEXP_LIKE([DatabaseName],@DatabasePattern,@DatabaseFlags);';
            EXEC [sys].[sp_executesql] @Sql,N'@LoginPattern nvarchar(4000),@LoginFlags varchar(8),@HostPattern nvarchar(4000),@HostFlags varchar(8),@ProgramPattern nvarchar(4000),@ProgramFlags varchar(8),@DatabasePattern nvarchar(4000),@DatabaseFlags varchar(8)',@LoginPattern,@LoginFlags,@HostPattern,@HostFlags,@ProgramPattern,@ProgramFlags,@DatabasePattern,@DatabaseFlags;
        END;

        IF @MaxZeilen IS NOT NULL AND @MaxZeilen>0
        BEGIN
            IF (SELECT COUNT_BIG(*) FROM [#CurrentSessions_Result])>@MaxZeilen SET @HasMoreRows=1;
            ;WITH [R] AS
            (
                SELECT [rn]=ROW_NUMBER() OVER(ORDER BY CASE WHEN @Sortierung='CPU' THEN COALESCE([RequestCpuMs],[SessionCpuMs]) END DESC,CASE WHEN @Sortierung='READS' THEN COALESCE([RequestLogicalReads],[SessionLogicalReads]) END DESC,CASE WHEN @Sortierung='WRITES' THEN COALESCE([RequestWrites],[SessionWrites]) END DESC,CASE WHEN @Sortierung='LOGIN' THEN DATEDIFF_BIG(SECOND,'20000101',[LoginTime]) END DESC,[SessionId]),*
                FROM [#CurrentSessions_Result]
            )
            DELETE FROM [R] WHERE [rn]>@MaxZeilen;
        END;

        DECLARE @TruncatedValueCount bigint=0,@LargestRequiredCharacters bigint=NULL;
        DECLARE @ColumnTruncatedCount bigint=0,@ColumnLargestCharacters bigint=NULL;
        EXEC [monitor].[InternalProjectUnicodeTextColumn]
              @SourceTable=N'#CurrentSessions_Result',@TextColumn=N'CurrentStatement'
            , @CharactersColumn=N'CurrentStatementCharacters',@BytesColumn=N'CurrentStatementBytes'
            , @IsTruncatedColumn=N'CurrentStatementIsTruncated',@MaxCharacters=@MaxSqlTextZeichen
            , @TruncatedValueCount=@ColumnTruncatedCount OUTPUT,@LargestRequiredCharacters=@ColumnLargestCharacters OUTPUT;
        SELECT @TruncatedValueCount=@TruncatedValueCount+@ColumnTruncatedCount,
               @LargestRequiredCharacters=CASE WHEN @LargestRequiredCharacters IS NULL OR @ColumnLargestCharacters>@LargestRequiredCharacters THEN @ColumnLargestCharacters ELSE @LargestRequiredCharacters END;
        EXEC [monitor].[InternalProjectUnicodeTextColumn]
              @SourceTable=N'#CurrentSessions_Result',@TextColumn=N'BatchText'
            , @CharactersColumn=N'BatchTextCharacters',@BytesColumn=N'BatchTextBytes'
            , @IsTruncatedColumn=N'BatchTextIsTruncated',@MaxCharacters=@MaxSqlTextZeichen
            , @TruncatedValueCount=@ColumnTruncatedCount OUTPUT,@LargestRequiredCharacters=@ColumnLargestCharacters OUTPUT;
        SELECT @TruncatedValueCount=@TruncatedValueCount+@ColumnTruncatedCount,
               @LargestRequiredCharacters=CASE WHEN @LargestRequiredCharacters IS NULL OR @ColumnLargestCharacters>@LargestRequiredCharacters THEN @ColumnLargestCharacters ELSE @LargestRequiredCharacters END;
        EXEC [monitor].[InternalEmitTruncationWarning]
              @TruncatedValueCount=@TruncatedValueCount,@ParameterName=N'@MaxSqlTextZeichen'
            , @ParameterValue=@MaxSqlTextZeichen,@LargestRequiredCharacters=@LargestRequiredCharacters
            , @PrintMeldungen=@PrintMeldungen;

        SELECT @RowCount=COUNT_BIG(*) FROM [#CurrentSessions_Result];
        IF @HasFullView=0 BEGIN SET @StatusCode='AVAILABLE_LIMITED';SET @IsPartial=1;SET @Detail=N'Ohne vollständige Server-State-Berechtigung kann die Sicht auf eigene Sessions begrenzt sein.';END
        ELSE SET @Detail=N'Current-State-Sessions erfolgreich gelesen.';
    END TRY
    BEGIN CATCH
        SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();SET @IsPartial=1;
        SET @StatusCode=CASE WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(207,208,4121) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END;
    END CATCH;

    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE')
    BEGIN
        SET @MonitorPrintMessage=FORMATMESSAGE(N'WARNUNG %s: %s',@StatusCode,COALESCE(@ErrorMessage,@Detail,N'eingeschränkte Sicht'));
        RAISERROR(N'%s',10,1,@MonitorPrintMessage) WITH NOWAIT;
    END;

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=(SELECT @ModuleName AS [resultName],2 AS [schemaVersion],@CollectionTimeUtc AS [generatedAtUtc],@StatusCode AS [statusCode],@IsPartial AS [isPartial],@ErrorNumber AS [errorNumber],@MaxZeilen AS [requestedMaxRows],@RowCount AS [returnedRows],@HasMoreRows AS [hasMoreRows],@ToolHintergrundabfragenEinbeziehen AS [toolBackgroundQueriesIncluded] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @SessionsJson nvarchar(max)=(SELECT [r].*,[wi].[WaitGroup] AS [waitGroup],[wi].[Severity] AS [waitSeverity],[wi].[Meaning] AS [waitMeaning] FROM [#CurrentSessions_Result] AS [r] CROSS APPLY [monitor].[TVF_WaitTypeInfo]([r].[WaitType]) AS [wi] ORDER BY [SessionId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@MetaJson,N'{}'),N',"sessions":',COALESCE(@SessionsJson,N'[]'),N',"warnings":',CASE WHEN @ErrorMessage IS NULL AND @Detail IS NULL THEN N'[]' ELSE (SELECT @StatusCode AS [code],COALESCE(@ErrorMessage,@Detail) AS [message] FOR JSON PATH,INCLUDE_NULL_VALUES) END,N'}');
    END;

    IF @ResultSetArtNormalisiert='RAW'
    BEGIN
        SELECT @ModuleName AS [ModuleName],@CollectionTimeUtc AS [CollectionTimeUtc],@StatusCode AS [StatusCode],@IsPartial AS [IsPartial],@RowCount AS [RowCount],@MaxZeilen AS [RequestedMaxRows],@HasMoreRows AS [HasMoreRows],@RequiredPermission AS [RequiredPermission],@ErrorNumber AS [ErrorNumber],@ErrorMessage AS [ErrorMessage],@Detail AS [Detail];
        SELECT [r].*,[wi].[WaitGroup],[wi].[Severity] AS [WaitSeverity],[wi].[IsGenerallyBenign],[wi].[Meaning] AS [WaitMeaning],[wi].[TypicalOccurrence] AS [WaitTypicalOccurrence],[wi].[HighWaitImpact],[wi].[RecommendedChecks],[wi].[HelpUrl] AS [WaitHelpUrl],[wi].[InterpretationScope],[wi].[CatalogMatchType]
        FROM [#CurrentSessions_Result] AS [r] CROSS APPLY [monitor].[TVF_WaitTypeInfo]([r].[WaitType]) AS [wi]
        ORDER BY CASE WHEN @Sortierung='CPU' THEN COALESCE([RequestCpuMs],[SessionCpuMs]) END DESC,CASE WHEN @Sortierung='READS' THEN COALESCE([RequestLogicalReads],[SessionLogicalReads]) END DESC,CASE WHEN @Sortierung='WRITES' THEN COALESCE([RequestWrites],[SessionWrites]) END DESC,CASE WHEN @Sortierung='LOGIN' THEN DATEDIFF_BIG(SECOND,'20000101',[LoginTime]) END DESC,[SessionId];
    END
    ELSE IF @ResultSetArtNormalisiert='CONSOLE'
    BEGIN
        SELECT N'Modulstatus' AS [Ergebnis],@ModuleName AS [Modul],@StatusCode AS [Status],CASE WHEN @IsPartial=1 THEN N'Ja' ELSE N'Nein' END AS [Teilergebnis],@RowCount AS [Zeilen],@Detail AS [Hinweis],@ErrorMessage AS [Fehler];
        SELECT N'Aktuelle Session' AS [Ergebnis],[SessionId] AS [Session],[RequestId] AS [Request],[LoginName] AS [Login],[HostName] AS [Host],[ProgramName] AS [Programm],[DatabaseName] AS [Datenbank],[SessionStatus] AS [Sessionstatus],[RequestStatus] AS [Requeststatus],CONCAT(CONVERT(decimal(19,2),COALESCE([RequestElapsedMs],0)/1000.0),N' s') AS [Laufzeit],COALESCE([RequestCpuMs],[SessionCpuMs]) AS [CPU_ms],COALESCE([RequestLogicalReads],[SessionLogicalReads]) AS [Logical_Reads],COALESCE([RequestWrites],[SessionWrites]) AS [Writes],[SessionId] AS [Session_Wait],[WaitType] AS [Wait],[WaitTimeMs] AS [Wait_ms],[BlockingSessionId] AS [Blockiert_durch],[CurrentStatement] AS [Aktuelles_Statement]
        FROM [#CurrentSessions_Result]
        ORDER BY CASE WHEN @Sortierung='CPU' THEN COALESCE([RequestCpuMs],[SessionCpuMs]) END DESC,CASE WHEN @Sortierung='READS' THEN COALESCE([RequestLogicalReads],[SessionLogicalReads]) END DESC,CASE WHEN @Sortierung='WRITES' THEN COALESCE([RequestWrites],[SessionWrites]) END DESC,[SessionId];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#CurrentSessions_Result'
            , @ResultLabel=N'Aktuelle Sessions'
            , @EmptyMessage=N'Keine aktiven Sessions';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#CurrentSessions_Result'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

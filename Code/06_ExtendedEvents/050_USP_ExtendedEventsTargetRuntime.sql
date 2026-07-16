USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ExtendedEventsTargetRuntime
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Liest Laufzeitmetriken bereits laufender Extended-Events-Targets
               wie execution_count, execution_duration_ms und bytes_written.
               Targetdaten können optional begrenzt ausgegeben werden.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_xe_sessions, sys.dm_xe_session_targets.
Parameter    : @ExtendedEventSessionNamePattern, @TargetNamePattern, @MitTargetData,
               @MaxTargetDataZeichen, @BestaetigeTargetFlush,
               @PrintMeldungen, @Hilfe.
Resultsets   : 1. Modulstatus. 2. Target-Laufzeitdaten.
Berechtigung : SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE
               STATE oder höher. Das Framework vergibt keine Rechte.
Eigenlast    : Normalerweise gering, kann aber durch große target_data-Inhalte
               sowie einen Target-Flush merkbar werden.
Locking      : LOCK_TIMEOUT 0; keine Benutzerobjekte und keine Änderungen.
Nebenwirkung : Das Lesen von sys.dm_xe_session_targets erzwingt laut Microsoft
               einen Flush gesammelter Sessiondaten zum Target. Daher ist eine
               explizite Bestätigung zwingend.
Partial      : Fehlende Rechte oder gestoppte Sessions werden strukturiert gemeldet.
Beispiele    : EXEC monitor.USP_ExtendedEventsTargetRuntime
                   @ExtendedEventSessionNamePattern=N'system_health', @BestaetigeTargetFlush=1;
               EXEC monitor.USP_ExtendedEventsTargetRuntime @Hilfe=1;
Änderungen   : 1.0.0 - Erstfassung Phase 5.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ExtendedEventsTargetRuntime]
      @ExtendedEventSessionNames       nvarchar(max)  = NULL
    , @ExtendedEventSessionNamePattern nvarchar(4000) = NULL
    , @TargetNames                     nvarchar(max)  = NULL
    , @TargetNamePattern               nvarchar(4000) = NULL
    , @MitTargetData           bit           = 0
    , @MaxTargetDataZeichen    int           = 4000
    , @BestaetigeTargetFlush   bit           = 0
    , @ResultSetArt                   varchar(16)    = 'CONSOLE'
    , @JsonErzeugen                   bit            = 0
    , @Json                            nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen          bit           = 1
    , @Hilfe                   bit           = 0
AS
BEGIN
    SET NOCOUNT ON;SET @Json=NULL;DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));DECLARE @SessionMode varchar(8),@SessionValue nvarchar(4000),@SessionFlags varchar(8),@SessionValid bit,@TargetMode varchar(8),@TargetValue nvarchar(4000),@TargetFlags varchar(8),@TargetValid bit;
    DECLARE @MonitorPrintMessage nvarchar(2048);

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ExtendedEventsTargetRuntime';
        PRINT N'@ExtendedEventSessionNamePattern nvarchar(256)=NULL: LIKE-Filter auf laufende Sessionnamen.';
        PRINT N'@TargetNamePattern nvarchar(256)=NULL: LIKE-Filter auf Targetnamen.';
        PRINT N'@MitTargetData bit=0: 1 gibt target_data begrenzt als nvarchar aus.';
        PRINT N'@MaxTargetDataZeichen int=4000: 0 bis 1000000; bei 0 wird target_data auch mit @MitTargetData=1 nicht übertragen.';
        PRINT N'@BestaetigeTargetFlush bit=0: muss 1 sein; sys.dm_xe_session_targets kann einen Target-Flush auslösen.';
        PRINT N'@PrintMeldungen bit=1: Warnungen Severity 10; @Hilfe bit=0: 1 zeigt diese Hilfe.';
        PRINT N'Es werden keine Sessions oder Targets verändert.';
        RETURN;
    END;

    DECLARE @CollectionTimeUtc datetime2(3)=SYSUTCDATETIME(),@StatusCode varchar(40)='AVAILABLE',
            @IsPartial bit=0,@ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@RowCount bigint=0,
            @Allowed bit=1;

    SELECT @SessionMode=[PatternMode],@SessionValue=[PatternValue],@SessionFlags=[RegexFlags],@SessionValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ExtendedEventSessionNamePattern);
    SELECT @TargetMode=[PatternMode],@TargetValue=[PatternValue],@TargetFlags=[RegexFlags],@TargetValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@TargetNamePattern);
    IF @SessionValid=0 OR @TargetValid=0 OR (@ExtendedEventSessionNames IS NOT NULL AND @ExtendedEventSessionNamePattern IS NOT NULL) OR (@TargetNames IS NOT NULL AND @TargetNamePattern IS NOT NULL) OR (@ExtendedEventSessionNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@ExtendedEventSessionNames) WHERE [IsValid]=0)) OR (@TargetNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@TargetNames) WHERE [IsValid]=0)) SET @StatusCode='INVALID_PARAMETER';
    CREATE TABLE [#Result]
    (
        [SessionName] nvarchar(256) NOT NULL,
        [TargetName] nvarchar(60) NOT NULL,
        [SessionCreateTime] datetime NULL,
        [ExecutionCount] bigint NOT NULL,
        [ExecutionDurationMs] bigint NOT NULL,
        [BytesWritten] bigint NOT NULL,
        [TargetDataCharacters] int NULL,
        [TargetDataPrefix] nvarchar(max) NULL
    );

    IF @MaxTargetDataZeichen NOT BETWEEN 0 AND 1000000 OR @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE')
    BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'@MaxTargetDataZeichen muss zwischen 0 und 1000000 liegen.';END;

    IF @StatusCode='AVAILABLE'
    BEGIN
        SELECT @Allowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0)
        FROM [monitor].[VW_AnalyseAccessCurrent] WHERE [AnalysisClass]='EXTENDED_EVENTS_FORENSICS_DEEP';
        IF @Allowed=0 BEGIN SET @StatusCode='DENIED_GROUP';SET @ErrorMessage=N'EXTENDED_EVENTS_FORENSICS_DEEP ist nicht freigegeben.';END;
    END;

    IF @StatusCode='AVAILABLE' AND @BestaetigeTargetFlush=0
    BEGIN
        SET @StatusCode='AVAILABLE_DISABLED';
        SET @ErrorMessage=N'@BestaetigeTargetFlush=1 ist erforderlich. sys.dm_xe_session_targets wurde nicht gelesen.';
    END;

    SET LOCK_TIMEOUT 0;
    IF @StatusCode='AVAILABLE'
    BEGIN
        BEGIN TRY
            INSERT [#Result]
            SELECT
                [s].[name],[t].[target_name],[s].[create_time],[t].[execution_count],[t].[execution_duration_ms],[t].[bytes_written],
                LEN([t].[target_data]),
                CASE WHEN @MitTargetData=1 AND @MaxTargetDataZeichen>0
                     THEN CONVERT(nvarchar(max),LEFT([t].[target_data],@MaxTargetDataZeichen)) END
            FROM [sys].[dm_xe_session_targets] AS t
            JOIN [sys].[dm_xe_sessions] AS s ON [s].[address]=[t].[event_session_address]
            WHERE ((@ExtendedEventSessionNames IS NULL OR EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@ExtendedEventSessionNames) [sf] WHERE [sf].[IsValid]=1 AND [sf].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS)) AND (@SessionMode IN('NONE','REGEX','REGEXI') OR [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @SessionValue COLLATE SQL_Latin1_General_CP1_CS_AS))
              AND ((@TargetNames IS NULL OR EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@TargetNames) [tf] WHERE [tf].[IsValid]=1 AND [tf].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS=[t].[target_name] COLLATE SQL_Latin1_General_CP1_CS_AS)) AND (@TargetMode IN('NONE','REGEX','REGEXI') OR [t].[target_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @TargetValue COLLATE SQL_Latin1_General_CP1_CS_AS))
            ORDER BY [s].[name],[t].[target_name];
            SELECT @RowCount=COUNT_BIG(*) FROM [#Result];
            IF @RowCount=0
            BEGIN SET @StatusCode='AVAILABLE_LIMITED';SET @IsPartial=1;SET @ErrorMessage=N'Keine passenden laufenden Targets gefunden.';END;
        END TRY
        BEGIN CATCH
            SET @StatusCode=CASE WHEN ERROR_NUMBER() IN(229,262,297,300) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END;
            SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();
        END CATCH;
    END;
    

    IF @StatusCode='AVAILABLE' AND (@SessionMode IN('REGEX','REGEXI') OR @TargetMode IN('REGEX','REGEXI'))
    BEGIN
      IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17 OR NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] [d] WITH(NOLOCK) WHERE [d].[database_id]=DB_ID() AND [d].[compatibility_level]>=170) BEGIN SET @StatusCode='UNAVAILABLE_FEATURE';SET @ErrorMessage=N'Regex benötigt SQL Server 2025 und Compatibility Level 170.';END
      ELSE BEGIN DECLARE @FilterSql nvarchar(max)=N'';IF @SessionMode IN('REGEX','REGEXI') SET @FilterSql+=N'DELETE FROM [#Result] WHERE REGEXP_LIKE([SessionName],@SP,@SF)=0;';IF @TargetMode IN('REGEX','REGEXI') SET @FilterSql+=N'DELETE FROM [#Result] WHERE REGEXP_LIKE([TargetName],@TP,@TF)=0;';EXEC [sys].[sp_executesql] @FilterSql,N'@SP nvarchar(4000),@SF varchar(8),@TP nvarchar(4000),@TF varchar(8)',@SP=@SessionValue,@SF=@SessionFlags,@TP=@TargetValue,@TF=@TargetFlags;END
    END;
    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE','AVAILABLE_LIMITED')
        BEGIN
    SET @MonitorPrintMessage = FORMATMESSAGE(N'WARNUNG USP_ExtendedEventsTargetRuntime: %s - %s', @StatusCode, COALESCE(@ErrorMessage,N'Keine Details.'));
    RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
END;

    IF @ResultSetArtNormalisiert<>'NONE' BEGIN SELECT N'USP_ExtendedEventsTargetRuntime' [ModuleName],@CollectionTimeUtc [CollectionTimeUtc],@StatusCode [StatusCode],@IsPartial [IsPartial],@ErrorNumber [ErrorNumber],@ErrorMessage [ErrorMessage];IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#Result] ORDER BY [SessionName],[TargetName];ELSE SELECT N'Extended-Events Target Runtime' [Ergebnis],[SessionName] [Session],[TargetName] [Target],[ExecutionCount] [Ausführungen],[ExecutionDurationMs] [Dauer ms],[TargetData] [Targetdaten] FROM [#Result] ORDER BY [SessionName],[TargetName];END;
    IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'ExtendedEventsTargetRuntime' [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@ErrorNumber [errorNumber],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@Data nvarchar(max)=(SELECT * FROM [#Result] ORDER BY [SessionName],[TargetName] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"targets":',COALESCE(@Data,N'[]'),N',"warnings":[]}');END;
END;
GO

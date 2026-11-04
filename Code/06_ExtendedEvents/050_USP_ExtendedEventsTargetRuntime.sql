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
    , @HighImpactConfirmed     bit           = 0
    , @ResultSetArt                   varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                   bit            = 0
    , @Json                            nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen          bit           = 1
    , @Hilfe                   bit           = 0
AS
BEGIN
    SET NOCOUNT ON;SET @Json=NULL;DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'targets',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';DECLARE @SessionMode varchar(8),@SessionValue nvarchar(4000),@SessionFlags varchar(8),@SessionValid bit,@TargetMode varchar(8),@TargetValue nvarchar(4000),@TargetFlags varchar(8),@TargetValid bit;
    DECLARE @MonitorPrintMessage nvarchar(2048);

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ExtendedEventsTargetRuntime';
        PRINT N'@ExtendedEventSessionNames nvarchar(max). Default ist NULL. NULL deaktiviert den Exaktnamenfilter. Andernfalls pipe-getrennte Liste exakter einteiliger SQL-Namen; geklammerte Namen und maskierte ]] sind zulässig. Leere Listen und ungültige Namen werden abgelehnt. Nicht mit ExtendedEventSessionNamePattern kombinierbar.';
        PRINT N'@ExtendedEventSessionNamePattern nvarchar(4000). Default ist NULL. NULL deaktiviert den Musterfilter. Andernfalls nichtleeres LIKE-Muster, optional mit LIKE:, REGEX: oder REGEXI:; äußere Leerzeichen werden entfernt. Leeres Muster oder leerer Präfixwert ist ungültig. LIKE unterstützt % und _. Regex benötigt SQL Server 2025 mit Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit ExtendedEventSessionNames kombinierbar.';
        PRINT N'@TargetNames nvarchar(max). Default ist NULL. NULL deaktiviert den Exaktnamenfilter. Andernfalls pipe-getrennte Liste exakter einteiliger SQL-Namen; geklammerte Namen und maskierte ]] sind zulässig. Leere Listen und ungültige Namen werden abgelehnt. Nicht mit TargetNamePattern kombinierbar.';
        PRINT N'@TargetNamePattern nvarchar(4000). Default ist NULL. NULL deaktiviert den Musterfilter. Andernfalls nichtleeres Muster mit optionalem LIKE:, REGEX: oder REGEXI:-Präfix; äußere Leerzeichen werden getrimmt. Leeres Muster oder leerer Präfixwert ungültig. LIKE verwendet % und _. Regex benötigt SQL Server 2025 / Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit TargetNames kombinierbar.';
        PRINT N'@MitTargetData bit. Default ist 0. 1 projiziert target_data und Zeichen-/Byteumfang; 0 setzt TargetData NULL und TargetDataStatus auf NOT_REQUESTED.';
        PRINT N'@MaxTargetDataZeichen int. Default ist 4000. Negative Werte ungültig. 0 bedeutet unbegrenzte nvarchar(max)-Projektion; positiver Wert begrenzt Ausgabezeichen. Gilt nur bei MitTargetData=1; gekürzte Werte erhalten OUTPUT_VALUE_TRUNCATED und können Warnung auslösen.';
        PRINT N'@BestaetigeTargetFlush bit. Default ist 0. 1 bestätigt den möglichen Flush beim Lesen von sys.dm_xe_session_targets. 0 sperrt den Zugriff. NULL kann die bestehende Prüfung auf 0 passieren und den DMV-Zugriff auslösen. Verwenden Sie ausdrücklich 0 oder 1.';
        PRINT N'@HighImpactConfirmed bit. Default ist 0. Bestätigung für den Policycheck EXTENDED_EVENTS_FORENSICS_DEEP; Standard 0.';
        PRINT N'@ResultSetArt varchar(16). Default ist ''CONSOLE''. Wird getrimmt und großgeschrieben. Zulässig: RAW, CONSOLE, NONE, TABLE. RAW gibt Status und rohe Targets aus; CONSOLE Status und lesbare Übersicht; NONE unterdrückt Resultsets; TABLE schreibt targets. Andere Werte sind ungültig.';
        PRINT N'@ResultTablesJson nvarchar(max). Default ist NULL. Nur mit ResultSetArt=TABLE zulässig. Nichtleeres JSON-Objekt mit genau dem Schlüssel targets und dem Namen einer vorhandenen, leeren lokalen #temp-Tabelle mit genau einer NULL-zulässigen Seed-Spalte. NULL/Leerwert, fehlerhafte Zuordnung, Zusatzschlüssel, befülltes Ziel, globale/permanente Tabelle und #Monitor-Präfix werden abgelehnt. Der Writer passt das Ziel an das Resultatschema an.';
        PRINT N'@JsonErzeugen bit. Default ist 0. 1 erstellt JSON unabhängig von ResultSetArt; 0 lässt @Json NULL.';
        PRINT N'@Json nvarchar(max). Default ist NULL. OUTPUT, anfangs NULL; bei JsonErzeugen=1 JSON-Objekt mit meta, targets und warnings.';
        PRINT N'@PrintMeldungen bit. Default ist 1. 1 gibt Warnungen als Severity-10-Meldungen aus; 0 unterdrückt sie.';
        PRINT N'@Hilfe bit. Default ist 0. 1 druckt Hilfe und kehrt vor der Ausführung zurück.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_ExtendedEventsTargetRuntime] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_ExtendedEventsTargetRuntime] @ExtendedEventSessionNames=N''ExampleXeSession'', @TargetNames=N''ring_buffer'', @BestaetigeTargetFlush=1, @HighImpactConfirmed=1, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3: DECLARE @xeJson nvarchar(max); EXEC [monitor].[USP_ExtendedEventsTargetRuntime] @ExtendedEventSessionNames=N''ExampleXeSession'', @TargetNames=N''ring_buffer'', @BestaetigeTargetFlush=1, @HighImpactConfirmed=1, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@xeJson OUTPUT; SELECT @xeJson AS JsonResult;';
        PRINT N'Beispiel 4: CREATE TABLE #ExtendedEventsTargetRuntime_HelpExample (Seed int NULL); BEGIN TRY EXEC [monitor].[USP_ExtendedEventsTargetRuntime] @ExtendedEventSessionNames=N''ExampleXeSession'', @TargetNames=N''ring_buffer'', @BestaetigeTargetFlush=1, @HighImpactConfirmed=1, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"targets":"#ExtendedEventsTargetRuntime_HelpExample"}''; SELECT * FROM #ExtendedEventsTargetRuntime_HelpExample; END TRY BEGIN CATCH IF OBJECT_ID(''tempdb..#ExtendedEventsTargetRuntime_HelpExample'') IS NOT NULL DROP TABLE #ExtendedEventsTargetRuntime_HelpExample; THROW; END CATCH; DROP TABLE #ExtendedEventsTargetRuntime_HelpExample;';
        RETURN;
    END;

    DECLARE @CollectionTimeUtc datetime2(3)=SYSUTCDATETIME(),@StatusCode varchar(40)='AVAILABLE',
            @IsPartial bit=0,@ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@RowCount bigint=0,
            @Allowed bit=1;

    SELECT @SessionMode=[PatternMode],@SessionValue=[PatternValue],@SessionFlags=[RegexFlags],@SessionValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ExtendedEventSessionNamePattern);
    SELECT @TargetMode=[PatternMode],@TargetValue=[PatternValue],@TargetFlags=[RegexFlags],@TargetValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@TargetNamePattern);
    IF @SessionValid=0 OR @TargetValid=0 OR (@ExtendedEventSessionNames IS NOT NULL AND @ExtendedEventSessionNamePattern IS NOT NULL) OR (@TargetNames IS NOT NULL AND @TargetNamePattern IS NOT NULL) OR (@ExtendedEventSessionNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@ExtendedEventSessionNames) WHERE [IsValid]=0)) OR (@TargetNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@TargetNames) WHERE [IsValid]=0)) SET @StatusCode='INVALID_PARAMETER';
    CREATE TABLE [#ExtendedEventsTargetRuntime_Result]
    (
        [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CapturedAtUtc] datetime2(3) NOT NULL,
        [EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsCurrent] bit NOT NULL,
        [IsCumulative] bit NOT NULL,
        [ValueStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SessionName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [TargetName] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SessionCreateTime] datetime NULL,
        [ExecutionCount] bigint NOT NULL,
        [ExecutionDurationMs] bigint NOT NULL,
        [BytesWritten] bigint NOT NULL,
        [TargetDataCharacters] bigint NULL,
        [TargetDataBytes] bigint NULL,
        [TargetDataIsTruncated] bit NOT NULL,
        [TargetDataStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [TargetData] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @MaxTargetDataZeichen < 0 OR @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE')
    BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'@MaxTargetDataZeichen darf nicht negativ sein; 0 bedeutet unbegrenzt.';END;

    IF @StatusCode='AVAILABLE'
        EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='EXTENDED_EVENTS_FORENSICS_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT;

    IF @StatusCode='AVAILABLE' AND @BestaetigeTargetFlush=0
    BEGIN
        SET @StatusCode='AVAILABLE_DISABLED';
        SET @ErrorMessage=N'@BestaetigeTargetFlush=1 ist erforderlich. sys.dm_xe_session_targets wurde nicht gelesen.';
    END;

    SET LOCK_TIMEOUT 0;
    IF @StatusCode='AVAILABLE'
    BEGIN
        BEGIN TRY
            INSERT [#ExtendedEventsTargetRuntime_Result]
            SELECT
                'LIVE_DMV',N'sys.dm_xe_session_targets',@CollectionTimeUtc,'SERVER_XE_TARGET',
                CONVERT(bit,1),CONVERT(bit,1),'AVAILABLE',
                [s].[name],[t].[target_name],[s].[create_time],[t].[execution_count],[t].[execution_duration_ms],[t].[bytes_written],
                CASE WHEN @MitTargetData=1 THEN [projection].[OriginalCharacters] END,
                CASE WHEN @MitTargetData=1 THEN [projection].[OriginalBytes] END,
                CONVERT(bit,CASE WHEN @MitTargetData=1 THEN [projection].[IsTruncated] ELSE 0 END),
                CASE WHEN @MitTargetData=0 THEN 'NOT_REQUESTED'
                     WHEN [t].[target_data] IS NULL THEN 'SOURCE_NULL'
                     WHEN [projection].[IsTruncated]=1 THEN 'OUTPUT_VALUE_TRUNCATED'
                     ELSE 'AVAILABLE' END,
                CASE WHEN @MitTargetData=1 THEN [projection].[ProjectedValue] END
            FROM [sys].[dm_xe_session_targets] AS t WITH (NOLOCK)
            JOIN [sys].[dm_xe_sessions] AS s WITH (NOLOCK) ON [s].[address]=[t].[event_session_address]
            CROSS APPLY [monitor].[TVF_ProjectUnicodeText]
            (
                  CONVERT(nvarchar(max),[t].[target_data])
                , @MaxTargetDataZeichen
            ) AS [projection]
            WHERE ((@ExtendedEventSessionNames IS NULL OR EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@ExtendedEventSessionNames) [sf] WHERE [sf].[IsValid]=1 AND [sf].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS)) AND (@SessionMode IN('NONE','REGEX','REGEXI') OR [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @SessionValue COLLATE SQL_Latin1_General_CP1_CS_AS))
              AND ((@TargetNames IS NULL OR EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@TargetNames) [tf] WHERE [tf].[IsValid]=1 AND [tf].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS=[t].[target_name] COLLATE SQL_Latin1_General_CP1_CS_AS)) AND (@TargetMode IN('NONE','REGEX','REGEXI') OR [t].[target_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @TargetValue COLLATE SQL_Latin1_General_CP1_CS_AS))
            ORDER BY [s].[name],[t].[target_name];
            SELECT @RowCount=COUNT_BIG(*) FROM [#ExtendedEventsTargetRuntime_Result];
            IF @RowCount=0
            BEGIN SET @StatusCode='AVAILABLE_LIMITED';SET @IsPartial=1;SET @ErrorMessage=N'Keine passenden laufenden Targets gefunden.';END;
        END TRY
        BEGIN CATCH
            SET @StatusCode=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END;
            SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();
        END CATCH;
    END;

    IF @StatusCode='AVAILABLE' AND (@SessionMode IN('REGEX','REGEXI') OR @TargetMode IN('REGEX','REGEXI'))
    BEGIN
      IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17 OR NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] [d] WITH(NOLOCK) WHERE [d].[database_id]=DB_ID() AND [d].[compatibility_level]>=170) BEGIN SET @StatusCode='UNAVAILABLE_FEATURE';SET @ErrorMessage=N'Regex benötigt SQL Server 2025 und Compatibility Level 170.';END
      ELSE BEGIN DECLARE @FilterSql nvarchar(max)=N'';IF @SessionMode IN('REGEX','REGEXI') SET @FilterSql+=N'DELETE FROM [#ExtendedEventsTargetRuntime_Result] WHERE NOT REGEXP_LIKE([SessionName],@SP,@SF);';IF @TargetMode IN('REGEX','REGEXI') SET @FilterSql+=N'DELETE FROM [#ExtendedEventsTargetRuntime_Result] WHERE NOT REGEXP_LIKE([TargetName],@TP,@TF);';EXEC [sys].[sp_executesql] @FilterSql,N'@SP nvarchar(4000),@SF varchar(8),@TP nvarchar(4000),@TF varchar(8)',@SP=@SessionValue,@SF=@SessionFlags,@TP=@TargetValue,@TF=@TargetFlags;END
    END;
    SELECT @RowCount=COUNT_BIG(*) FROM [#ExtendedEventsTargetRuntime_Result];
    DECLARE @TruncatedValueCount bigint=0,@LargestRequiredCharacters bigint=NULL;
    SELECT @TruncatedValueCount=COUNT_BIG(*),@LargestRequiredCharacters=MAX([TargetDataCharacters])
    FROM [#ExtendedEventsTargetRuntime_Result]
    WHERE [TargetDataIsTruncated]=1;
    EXEC [monitor].[InternalEmitTruncationWarning]
          @TruncatedValueCount=@TruncatedValueCount,@ParameterName=N'@MaxTargetDataZeichen'
        , @ParameterValue=@MaxTargetDataZeichen,@LargestRequiredCharacters=@LargestRequiredCharacters
        , @PrintMeldungen=@PrintMeldungen;
    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE','AVAILABLE_LIMITED')
        BEGIN
    SET @MonitorPrintMessage = FORMATMESSAGE(N'WARNUNG USP_ExtendedEventsTargetRuntime: %s - %s', @StatusCode, COALESCE(@ErrorMessage,N'Keine Details.'));
    RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
END;

    IF @ResultSetArtNormalisiert<>'NONE' BEGIN SELECT N'USP_ExtendedEventsTargetRuntime' [ModuleName],@CollectionTimeUtc [CollectionTimeUtc],@StatusCode [StatusCode],@IsPartial [IsPartial],@ErrorNumber [ErrorNumber],@ErrorMessage [ErrorMessage];IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#ExtendedEventsTargetRuntime_Result] ORDER BY [SessionName],[TargetName];ELSE SELECT N'Extended-Events Target Runtime' [Ergebnis],[SessionName] [Session],[TargetName] [Target],[ExecutionCount] [Ausführungen],[ExecutionDurationMs] [Dauer ms],[TargetDataCharacters] [Targetdaten Zeichen],[TargetDataBytes] [Targetdaten Bytes],[TargetDataIsTruncated] [Targetdaten gekürzt],[TargetData] [Targetdaten] FROM [#ExtendedEventsTargetRuntime_Result] ORDER BY [SessionName],[TargetName];END;
    IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'ExtendedEventsTargetRuntime' [resultName],2 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@ErrorNumber [errorNumber],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@Data nvarchar(max)=(SELECT * FROM [#ExtendedEventsTargetRuntime_Result] ORDER BY [SessionName],[TargetName] FOR JSON PATH,INCLUDE_NULL_VALUES),@Warnings nvarchar(max)=(SELECT 'OUTPUT_VALUE_TRUNCATED' [code],@TruncatedValueCount [truncatedValueCount],N'@MaxTargetDataZeichen' [parameterName],@MaxTargetDataZeichen [parameterValue],@LargestRequiredCharacters [largestRequiredCharacters] WHERE @TruncatedValueCount>0 FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"targets":',COALESCE(@Data,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ExtendedEventsTargetRuntime_Result'
            , @ResultLabel=N'ExtendedEventsTargetRuntime'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ExtendedEventsTargetRuntime_Result'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

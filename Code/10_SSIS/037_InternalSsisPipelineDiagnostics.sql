USE [DeineDatenbank];
GO

/* Auswertung bereits gebundener Pipelinebelege. Portrollen stammen aus dem
   validierten Toolbelt-Modell. Summen gelten ausschließlich im beobachteten
   Instanzscope; überlappende Intervalle sind weder CPU- noch Paketlaufzeit.
   Eigene Temp-Tabellen werden vom Scopeconsumer angelegt und ausgegeben. */
CREATE OR ALTER PROCEDURE [monitor].[InternalSsisPipelineDiagnostics]
    @Models nvarchar(max), @Bound bit, @Deadline datetime2(3), @Limit int,
    @PipelinePhaseThresholdMs bigint = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@LockTimeoutSql nvarchar(80);
    DECLARE @DiagnosticError int=NULL,@DiagnosticReason varchar(40)=NULL;
    IF @Bound=1 AND NOT EXISTS(SELECT 1 FROM #InternalSsisExecutionScopes_PipelineCoverage WHERE [StatusCode]='PIPELINE_BINDING_UNPROVEN')
    BEGIN TRY
    IF SYSUTCDATETIME() >= @Deadline THROW 57920,N'PIPELINE_DIAGNOSTIC_TIME_LIMIT',1;

    ;WITH [intervals] AS
    (
        SELECT [p].*,
            MAX(CASE WHEN [ObservedDurationMs] IS NOT NULL THEN [EndTime] END) OVER(PARTITION BY [FlowStatisticsId],[ComponentNodeId],[PhaseName] COLLATE Latin1_General_100_BIN2,DATALENGTH([PhaseName])
                ORDER BY [StartTime],[EndTime],[PhaseStatsId] ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS [PriorEnd],
            ROW_NUMBER() OVER(PARTITION BY [FlowStatisticsId],[ComponentNodeId],[PhaseName] COLLATE Latin1_General_100_BIN2,DATALENGTH([PhaseName])
                ORDER BY [ObservedDurationMs] DESC,[PhaseStatsId]) AS [DurationOrder]
        FROM #InternalSsisExecutionScopes_ComponentPhases AS [p]
        WHERE [ComponentNodeId] IS NOT NULL AND [CorrelationStatus]='SCOPED_EXACT_COMPONENT_NAME'
    ), [groups] AS
    (
        SELECT [FlowStatisticsId],[InvocationId],[PackageKey],[FlowNodeId],[ComponentNodeId],[PhaseName] COLLATE Latin1_General_100_BIN2 AS [PhaseName],
            COUNT(*) AS [ObservedIntervalCount],COUNT([ObservedDurationMs]) AS [ValidIntervalCount],
            SUM(CONVERT(decimal(38,0),[ObservedDurationMs])) AS [ObservedIntervalSumMs],
            MAX([ObservedDurationMs]) AS [LongestIntervalMs],
            MIN(CASE WHEN [ObservedDurationMs] IS NOT NULL THEN [StartTime] END) AS [FirstStartTime],
            MAX(CASE WHEN [ObservedDurationMs] IS NOT NULL THEN [EndTime] END) AS [LastEndTime],
            MAX(CASE WHEN [ObservedDurationMs] IS NOT NULL AND [StartTime]<[PriorEnd] THEN 1 ELSE 0 END) AS [OverlapObserved],
            MAX(CASE WHEN [DurationOrder]=1 AND [ObservedDurationMs] IS NOT NULL THEN [PhaseStatsId] END) AS [EvidencePhaseStatsId]
        FROM [intervals]
        GROUP BY [FlowStatisticsId],[InvocationId],[PackageKey],[FlowNodeId],[ComponentNodeId],[PhaseName] COLLATE Latin1_General_100_BIN2,DATALENGTH([PhaseName])
    )
    INSERT #InternalSsisExecutionScopes_PhaseSummary
    SELECT [FlowStatisticsId],[InvocationId],[PackageKey],[FlowNodeId],[ComponentNodeId],[PhaseName],
        [ObservedIntervalCount],[ValidIntervalCount],[ObservedIntervalCount]-[ValidIntervalCount],
        [ObservedIntervalSumMs],[LongestIntervalMs],DATEDIFF_BIG(millisecond,[FirstStartTime],[LastEndTime]),
        [FirstStartTime],[LastEndTime],[OverlapObserved],
        CASE WHEN [LongestIntervalMs] IS NOT NULL THEN DENSE_RANK() OVER(PARTITION BY [FlowStatisticsId],[PhaseName] COLLATE Latin1_General_100_BIN2,DATALENGTH([PhaseName]) ORDER BY [LongestIntervalMs] DESC) END,
        [EvidencePhaseStatsId],1
    FROM [groups];

    IF SYSUTCDATETIME() >= @Deadline THROW 57920,N'PIPELINE_DIAGNOSTIC_TIME_LIMIT',1;
    ;WITH [ports] AS
    (
        SELECT JSON_VALUE([p].[value],'$.packageKey') AS [PackageKey],[n].[NodeId],[n].[PortRole]
        FROM OPENJSON(@Models,'$.packages') AS [p]
        CROSS APPLY OPENJSON([p].[value],'$.model.nodes') WITH
            ([NodeId] varchar(128) '$.id',[Kind] varchar(16) '$.kind',[PortRole] varchar(16) '$.attributes.portRole') AS [n]
        WHERE [n].[Kind]='PORT'
    ), [edges] AS
    (
        SELECT JSON_VALUE([p].[value],'$.packageKey') AS [PackageKey],[e].[EdgeId],[e].[FromId]
        FROM OPENJSON(@Models,'$.packages') AS [p]
        CROSS APPLY OPENJSON([p].[value],'$.model.edges') WITH
            ([EdgeId] varchar(128) '$.id',[Kind] varchar(32) '$.kind',[FromId] varchar(128) '$.fromId') AS [e]
        WHERE [e].[Kind]='PIPELINE_PATH'
    )
    INSERT #InternalSsisExecutionScopes_TransferSummary
    SELECT [r].[FlowStatisticsId],[r].[InvocationId],[r].[PackageKey],[r].[FlowNodeId],[r].[ModelEdgeId],
        COALESCE([p].[PortRole],'UNKNOWN'),COUNT(*),COUNT([r].[RowsSent]),COUNT(*)-COUNT([r].[RowsSent]),
        SUM(CONVERT(decimal(38,0),[r].[RowsSent])),MIN([r].[CreatedTime]),MAX([r].[CreatedTime]),
        MIN([r].[DataStatsId]),MIN(CASE WHEN [r].[RowsSent]>0 THEN [r].[DataStatsId] END),1
    FROM #InternalSsisExecutionScopes_PathTransfers AS [r]
    JOIN [edges] AS [e] ON [e].[PackageKey] COLLATE SQL_Latin1_General_CP1_CS_AS=[r].[PackageKey]
        AND [e].[EdgeId]=[r].[ModelEdgeId]
    LEFT JOIN [ports] AS [p] ON [p].[PackageKey] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[PackageKey] COLLATE SQL_Latin1_General_CP1_CS_AS AND [p].[NodeId]=[e].[FromId]
    WHERE [r].[ModelEdgeId] IS NOT NULL AND [r].[CorrelationStatus]='SCOPED_EXACT_PATH_REFERENCE'
    GROUP BY [r].[FlowStatisticsId],[r].[InvocationId],[r].[PackageKey],[r].[FlowNodeId],[r].[ModelEdgeId],[p].[PortRole];

    INSERT #InternalSsisExecutionScopes_PipelineFindings
    SELECT [rules].[RuleId],'1.0.0','INFO','OBSERVED_SCOPED',[t].[PackageKey],[t].[InvocationId],
        [t].[FlowStatisticsId],[t].[FlowNodeId],NULL,[t].[ModelEdgeId],'pathTransfers',
        CASE WHEN [rules].[RuleId]='SSIS_PIPELINE_ZERO_OBSERVED_TRANSFER' THEN [t].[FirstDataStatsId] ELSE [t].[PositiveDataStatsId] END,
        [t].[ObservedRowsSent],NULL,[p].[PackageSha256],[b].[SourceBindingSha256],1
    FROM #InternalSsisExecutionScopes_TransferSummary AS [t]
    CROSS APPLY(VALUES
        ('SSIS_PIPELINE_ERROR_OUTPUT_OBSERVED',CASE WHEN [t].[PortRole]='ERROR' AND [t].[PositiveDataStatsId] IS NOT NULL THEN 1 ELSE 0 END),
        ('SSIS_PIPELINE_NO_MATCH_OBSERVED',CASE WHEN [t].[PortRole]='NO_MATCH' AND [t].[PositiveDataStatsId] IS NOT NULL THEN 1 ELSE 0 END),
        ('SSIS_PIPELINE_ZERO_OBSERVED_TRANSFER',CASE WHEN [t].[UnknownRowCount]=0 AND [t].[ObservedRowsSent]=0 THEN 1 ELSE 0 END)
    ) AS [rules]([RuleId],[Applies])
    JOIN #InternalSsisExecutionScopes_Packages AS [p] ON [p].[PackageKey]=[t].[PackageKey]
    CROSS JOIN #InternalSsisExecutionScopes_Binding AS [b]
    WHERE [rules].[Applies]=1;

    INSERT #InternalSsisExecutionScopes_PipelineFindings
    SELECT 'SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED','1.0.0','INFO','OBSERVED_SCOPED',
        [s].[PackageKey],[s].[InvocationId],[s].[FlowStatisticsId],[s].[FlowNodeId],[s].[ComponentNodeId],NULL,
        'componentPhases',[s].[EvidencePhaseStatsId],[s].[LongestIntervalMs],@PipelinePhaseThresholdMs,
        [p].[PackageSha256],[b].[SourceBindingSha256],1
    FROM #InternalSsisExecutionScopes_PhaseSummary AS [s]
    JOIN #InternalSsisExecutionScopes_Packages AS [p] ON [p].[PackageKey]=[s].[PackageKey]
    CROSS JOIN #InternalSsisExecutionScopes_Binding AS [b]
    WHERE @PipelinePhaseThresholdMs IS NOT NULL AND [s].[LongestIntervalMs]>@PipelinePhaseThresholdMs;

    IF SYSUTCDATETIME() >= @Deadline THROW 57920,N'PIPELINE_DIAGNOSTIC_TIME_LIMIT',1;
    END TRY
    BEGIN CATCH
        SELECT @DiagnosticError=ERROR_NUMBER(),@DiagnosticReason=CASE WHEN ERROR_NUMBER()=57920 THEN 'DIAGNOSTIC_TIME_LIMIT' ELSE 'DIAGNOSTIC_INPUT_REJECTED' END;
        DELETE #InternalSsisExecutionScopes_PhaseSummary;
        DELETE #InternalSsisExecutionScopes_TransferSummary;
        DELETE #InternalSsisExecutionScopes_PipelineFindings;
    END CATCH;

    INSERT #InternalSsisExecutionScopes_DiagnosticCoverage
    SELECT [c].[SourceName],COALESCE(@DiagnosticReason,[c].[StatusCode]),COALESCE(@DiagnosticError,[c].[SourceErrorNumber]),[c].[ObservedRowCount],
        [c].[MappedRowCount],[c].[UnassignedRowCount],
        CASE WHEN [c].[SourceName]='componentPhases' THEN (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_PhaseSummary)
             ELSE (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_TransferSummary) END,
        CASE WHEN [c].[SourceName]='componentPhases' THEN (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_ComponentPhases WHERE [ComponentNodeId] IS NOT NULL AND [ObservedDurationMs] IS NULL)
             ELSE (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_PathTransfers WHERE [ModelEdgeId] IS NOT NULL AND [RowsSent] IS NULL) END,
        CASE WHEN [c].[SourceName]='pathTransfers' THEN (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_TransferSummary WHERE [PortRole] IN('UNKNOWN') OR [PortRole] IS NULL) ELSE 0 END,
        [c].[LoggingLevel],1,[c].[OutputTruncated],
        CASE WHEN @DiagnosticReason IS NOT NULL THEN @DiagnosticReason WHEN [c].[StatusCode] NOT IN('AVAILABLE','AVAILABLE_EMPTY') THEN 'SOURCE_NOT_AVAILABLE'
             WHEN [c].[ObservedRowCount]=0 THEN 'NO_OBSERVATIONS'
             WHEN [c].[OutputTruncated]=1 THEN 'SOURCE_OUTPUT_TRUNCATED'
             WHEN [c].[UnassignedRowCount]>0 THEN 'UNASSIGNED_OBSERVATIONS'
             ELSE 'OBSERVED_PARTIAL' END
    FROM #InternalSsisExecutionScopes_PipelineCoverage AS [c];

    INSERT #InternalSsisExecutionScopes_PipelineFindings
    SELECT 'SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED','1.0.0','INFO','SOURCE_COVERAGE',NULL,NULL,NULL,NULL,NULL,NULL,
        [SourceName],NULL,NULL,NULL,NULL,[b].[SourceBindingSha256],1
    FROM #InternalSsisExecutionScopes_DiagnosticCoverage AS [c]
    CROSS JOIN #InternalSsisExecutionScopes_Binding AS [b]
    WHERE [c].[ReasonCode]<>'OBSERVED_PARTIAL' OR [c].[UnknownValueCount]>0 OR [c].[UnknownRoleCount]>0;

    UPDATE #InternalSsisExecutionScopes_DiagnosticCoverage SET [OutputTruncated]=CASE
        WHEN [OutputTruncated]=1 OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_PhaseSummary)>@Limit
          OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_TransferSummary)>@Limit
          OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_PipelineFindings)>@Limit
          OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_DiagnosticCoverage)>@Limit THEN 1 ELSE 0 END;
    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;
END;
GO

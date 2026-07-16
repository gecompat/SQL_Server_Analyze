USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_PrepareNameFilters
Version      : 1.0.0
Stand        : 2026-07-15
Typ          : Interne Stored Procedure
Zweck        : Validiert bracket-aware Pipe-Listen für einteilige SQL-Namen und
               vollständige Objektbezüge und befüllt die vom Aufrufer angelegte
               Temp-Tabelle #NameFilters.
Voraussetzung: #NameFilters(FilterType, ItemOrdinal, NameValue, DatabaseName,
               SchemaName, ObjectName).
Hinweis      : Werte werden exakt case-sensitiv unter
               SQL_Latin1_General_CP1_CS_AS behandelt.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_PrepareNameFilters]
      @SchemaNames       nvarchar(max)  = NULL
    , @ObjectNames       nvarchar(max)  = NULL
    , @FullObjectNames   nvarchar(max)  = NULL
    , @IndexNames        nvarchar(max)  = NULL
    , @StatisticsNames   nvarchar(max)  = NULL
    , @ColumnNames       nvarchar(max)  = NULL
    , @StatusCode        varchar(40)    OUTPUT
    , @ErrorMessage      nvarchar(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @StatusCode = 'AVAILABLE';
    SET @ErrorMessage = NULL;

    IF OBJECT_ID(N'tempdb..#NameFilters') IS NULL
    BEGIN
        SET @StatusCode = 'INTERNAL_ERROR';
        SET @ErrorMessage = N'Die Temp-Tabelle #NameFilters wurde nicht angelegt.';
        RETURN;
    END;

    IF (@SchemaNames IS NOT NULL AND EXISTS (SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@SchemaNames) WHERE [IsValid] = 0))
       OR (@ObjectNames IS NOT NULL AND EXISTS (SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@ObjectNames) WHERE [IsValid] = 0))
       OR (@FullObjectNames IS NOT NULL AND EXISTS (SELECT 1 FROM [monitor].[TVF_ParseFullObjectNameList](@FullObjectNames) WHERE [IsValid] = 0))
       OR (@IndexNames IS NOT NULL AND EXISTS (SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@IndexNames) WHERE [IsValid] = 0))
       OR (@StatisticsNames IS NOT NULL AND EXISTS (SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@StatisticsNames) WHERE [IsValid] = 0))
       OR (@ColumnNames IS NOT NULL AND EXISTS (SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@ColumnNames) WHERE [IsValid] = 0))
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Mindestens eine Namensliste ist syntaktisch ungültig.';
        RETURN;
    END;

    IF @FullObjectNames IS NOT NULL
       AND (@SchemaNames IS NOT NULL OR @ObjectNames IS NOT NULL)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@FullObjectNames ist mit @SchemaNames und @ObjectNames gegenseitig exklusiv.';
        RETURN;
    END;

    INSERT [#NameFilters]([FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName])
    SELECT 'SCHEMA',[ItemOrdinal],[NameValue],NULL,NULL,NULL
    FROM [monitor].[TVF_ParseSqlNameList](@SchemaNames) WHERE [IsValid] = 1
    UNION ALL
    SELECT 'OBJECT',[ItemOrdinal],[NameValue],NULL,NULL,NULL
    FROM [monitor].[TVF_ParseSqlNameList](@ObjectNames) WHERE [IsValid] = 1
    UNION ALL
    SELECT 'INDEX',[ItemOrdinal],[NameValue],NULL,NULL,NULL
    FROM [monitor].[TVF_ParseSqlNameList](@IndexNames) WHERE [IsValid] = 1
    UNION ALL
    SELECT 'STATISTICS',[ItemOrdinal],[NameValue],NULL,NULL,NULL
    FROM [monitor].[TVF_ParseSqlNameList](@StatisticsNames) WHERE [IsValid] = 1
    UNION ALL
    SELECT 'COLUMN',[ItemOrdinal],[NameValue],NULL,NULL,NULL
    FROM [monitor].[TVF_ParseSqlNameList](@ColumnNames) WHERE [IsValid] = 1;

    INSERT [#NameFilters]([FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName])
    SELECT 'FULL_OBJECT',[ItemOrdinal],NULL,[DatabaseName],[SchemaName],[ObjectName]
    FROM [monitor].[TVF_ParseFullObjectNameList](@FullObjectNames)
    WHERE [IsValid] = 1;

    IF EXISTS
    (
        SELECT 1
        FROM [#NameFilters]
        GROUP BY [FilterType],
                 [NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS,
                 [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                 [SchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                 [ObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS
        HAVING COUNT(*) > 1
    )
    BEGIN
        DELETE FROM [#NameFilters];
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Eine Namensliste enthält case-sensitiv doppelte Werte.';
    END;
END;
GO

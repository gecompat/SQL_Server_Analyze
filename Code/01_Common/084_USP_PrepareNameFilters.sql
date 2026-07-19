USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_PrepareNameFilters
Version      : 1.0.0
Stand        : 2026-07-15
Typ          : Interne Stored Procedure
Zweck        : Validiert bracket-aware Pipe-Listen für einteilige SQL-Namen und
               vollständige Objektbezüge und befüllt die vom Aufrufer benannte
               Temp-Tabelle.
Voraussetzung: @FilterTable(FilterType, ItemOrdinal, NameValue, DatabaseName,
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
    , @FilterTable       sysname        = N'#PrepareNameFilters_Result'
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @StatusCode = 'AVAILABLE';
    SET @ErrorMessage = NULL;

    IF @FilterTable IS NULL
       OR LEFT(@FilterTable,1)<>N'#'
       OR LEFT(@FilterTable,2)=N'##'
       OR LEN(@FilterTable)>116
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@FilterTable muss einen gültigen lokalen #Temp-Tabellennamen enthalten.';
        RETURN;
    END;

    DECLARE @FilterTableQuoted nvarchar(258)=QUOTENAME(@FilterTable);
    DECLARE @Sql nvarchar(max);

    BEGIN TRY
        SET @Sql=N'SELECT TOP (0) [FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName] FROM '+@FilterTableQuoted+N';';
        EXEC [sys].[sp_executesql] @Sql;
    END TRY
    BEGIN CATCH
        SET @StatusCode = 'INTERNAL_ERROR';
        SET @ErrorMessage = N'Die über @FilterTable benannte Temp-Tabelle wurde nicht angelegt.';
        RETURN;
    END CATCH;

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

    SET @Sql=N'INSERT '+@FilterTableQuoted+N' ([FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName])
    SELECT ''SCHEMA'',[ItemOrdinal],[NameValue],NULL,NULL,NULL
    FROM [monitor].[TVF_ParseSqlNameList](@pSchemaNames) WHERE [IsValid] = 1
    UNION ALL
    SELECT ''OBJECT'',[ItemOrdinal],[NameValue],NULL,NULL,NULL
    FROM [monitor].[TVF_ParseSqlNameList](@pObjectNames) WHERE [IsValid] = 1
    UNION ALL
    SELECT ''INDEX'',[ItemOrdinal],[NameValue],NULL,NULL,NULL
    FROM [monitor].[TVF_ParseSqlNameList](@pIndexNames) WHERE [IsValid] = 1
    UNION ALL
    SELECT ''STATISTICS'',[ItemOrdinal],[NameValue],NULL,NULL,NULL
    FROM [monitor].[TVF_ParseSqlNameList](@pStatisticsNames) WHERE [IsValid] = 1
    UNION ALL
    SELECT ''COLUMN'',[ItemOrdinal],[NameValue],NULL,NULL,NULL
    FROM [monitor].[TVF_ParseSqlNameList](@pColumnNames) WHERE [IsValid] = 1;

    INSERT '+@FilterTableQuoted+N' ([FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName])
    SELECT ''FULL_OBJECT'',[ItemOrdinal],NULL,[DatabaseName],[SchemaName],[ObjectName]
    FROM [monitor].[TVF_ParseFullObjectNameList](@pFullObjectNames)
    WHERE [IsValid] = 1;';

    EXEC [sys].[sp_executesql]
          @Sql
        , N'@pSchemaNames nvarchar(max),@pObjectNames nvarchar(max),@pFullObjectNames nvarchar(max),@pIndexNames nvarchar(max),@pStatisticsNames nvarchar(max),@pColumnNames nvarchar(max)'
        , @pSchemaNames=@SchemaNames
        , @pObjectNames=@ObjectNames
        , @pFullObjectNames=@FullObjectNames
        , @pIndexNames=@IndexNames
        , @pStatisticsNames=@StatisticsNames
        , @pColumnNames=@ColumnNames;

    DECLARE @HasDuplicates bit=0;
    SET @Sql=N'SELECT @pHasDuplicates=CONVERT(bit,CASE WHEN EXISTS
    (
        SELECT 1 FROM '+@FilterTableQuoted+N'
        GROUP BY [FilterType],
                 [NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS,
                 [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                 [SchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                 [ObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS
        HAVING COUNT(*) > 1
    ) THEN 1 ELSE 0 END);';
    EXEC [sys].[sp_executesql] @Sql,N'@pHasDuplicates bit OUTPUT',@pHasDuplicates=@HasDuplicates OUTPUT;

    IF @HasDuplicates=1
    BEGIN
        SET @Sql=N'DELETE FROM '+@FilterTableQuoted+N';';
        EXEC [sys].[sp_executesql] @Sql;
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Eine Namensliste enthält case-sensitiv doppelte Werte.';
    END;
END;
GO

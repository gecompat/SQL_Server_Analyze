USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_PrepareNameFilters
Version      : 1.0.0
Stand        : 2026-07-15
Typ          : Öffentlicher Vorbereitungshelfer
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
    , @Hilfe             bit            = 0
AS
BEGIN
    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_PrepareNameFilters validiert Namensfilter und befüllt eine vom Aufrufer angelegte lokale Temp-Tabelle. Die Procedure liefert keine Analyse-Resultsets. Hilfe beendet die fachliche Verarbeitung vor Temp-Tabellen-, Parameter- und Namenslistenverarbeitung.';
        PRINT N'@SchemaNames nvarchar(max) = NULL: optionale Liste einteiliger SQL-Schemanamen, zum Beispiel N''[dbo]|[Sales]''. NULL bedeutet keine Einschränkung. Die Pipe trennt nur außerhalb von [...]; ]] maskiert innerhalb der Klammern eine schließende Klammer. Nach dem Entquoten muss jedes Element genau ein gültiger SQL-Bezeichner mit höchstens 128 Zeichen sein. Leere Elemente, nicht geschlossene Klammern und nicht maskierte schließende Klammern sind ungültig.';
        PRINT N'@ObjectNames nvarchar(max) = NULL: optionale Liste einteiliger SQL-Objektnamen; gleicher Klammer-, Pipe-, Entquotungs- und 128-Zeichen-Vertrag wie @SchemaNames.';
        PRINT N'@FullObjectNames nvarchar(max) = NULL: optionale Liste aus Objekt, Schema.Objekt oder Datenbank.Schema.Objekt, zum Beispiel N''[dbo].[TableA]|[DatabaseA].[sales].[TableB]''. Bei drei Teilen ist das Schema erforderlich; vierteilige Linked-Server-Namen sind ungültig. Jeder Bestandteil darf nach dem Entquoten höchstens 128 Zeichen haben. Derselbe Klammer- und Pipe-Vertrag wie bei @SchemaNames gilt. Nicht kombinierbar mit @SchemaNames oder @ObjectNames.';
        PRINT N'@IndexNames nvarchar(max) = NULL: optionale Liste einteiliger SQL-Indexnamen; gleicher Klammer-, Pipe-, Entquotungs- und 128-Zeichen-Vertrag wie @SchemaNames.';
        PRINT N'@StatisticsNames nvarchar(max) = NULL: optionale Liste einteiliger SQL-Statistiknamen; gleicher Klammer-, Pipe-, Entquotungs- und 128-Zeichen-Vertrag wie @SchemaNames.';
        PRINT N'@ColumnNames nvarchar(max) = NULL: optionale Liste einteiliger SQL-Spaltennamen; gleicher Klammer-, Pipe-, Entquotungs- und 128-Zeichen-Vertrag wie @SchemaNames.';
        PRINT N'@StatusCode varchar(40) OUTPUT: erforderlich. Die vollständigen Statuswerte dieser Procedure sind AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR, TIMEOUT, DENIED_PERMISSION und ERROR_HANDLED.';
        PRINT N'@ErrorMessage nvarchar(2048) OUTPUT: erforderlich; NULL bei erfolgreicher Vorbereitung, sonst die zugehörige Fehlerbeschreibung.';
        PRINT N'@FilterTable sysname = N''#PrepareNameFilters_Result'': Name einer vom Aufrufer angelegten lokalen #Temp-Tabelle mit FilterType varchar(20) (SCHEMA, OBJECT, INDEX, STATISTICS, COLUMN oder FULL_OBJECT), ItemOrdinal int, NameValue sysname NULL, DatabaseName sysname NULL, SchemaName sysname NULL, ObjectName sysname NULL. Der Name darf höchstens 116 Zeichen haben; globale ##Temp-Namen sind unzulässig.';
        PRINT N'@Hilfe bit = 0: 0 führt die Filtervalidierung aus; 1 gibt diese Hilfe aus und kehrt ohne fachliche Verarbeitung zurück; NULL folgt dem normalen Verarbeitungspfad.';
        PRINT N'Listenparser: Pipe trennt nur außerhalb von [...]; ]] maskiert darin eine schließende Klammer. Leere Elemente, nicht geschlossene Klammern und nicht maskierte schließende Klammern sind ungültig. Werte werden entquotet und case-sensitiv ausgewertet; Duplikate innerhalb desselben Filtertyps sind ungültig. Beispiel: N''[ColumnA]|[Column|WithPipe]''.';
        PRINT N'Gültiger Hilfeaufruf (alle Pflichtparameter gebunden): DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048); EXEC [monitor].[USP_PrepareNameFilters] @StatusCode=@StatusCode OUTPUT, @ErrorMessage=@ErrorMessage OUTPUT, @Hilfe=1;';
        RETURN;
    END;

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

    CREATE TABLE [#PrepareNameFilters_Work]
    (
          [FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ItemOrdinal] int NOT NULL
        , [NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsValid] bit NOT NULL
    );

    BEGIN TRY
        SET @Sql=N'DECLARE @ProbeType varchar(20),@ProbeOrdinal int,@ProbeName sysname,@ProbeDatabase sysname,@ProbeSchema sysname,@ProbeObject sysname;
SELECT TOP (0) @ProbeType=[FilterType],@ProbeOrdinal=[ItemOrdinal],@ProbeName=[NameValue],@ProbeDatabase=[DatabaseName],@ProbeSchema=[SchemaName],@ProbeObject=[ObjectName] FROM '+@FilterTableQuoted+N';';
        EXEC [sys].[sp_executesql] @Sql;
    END TRY
    BEGIN CATCH
        SET @StatusCode = 'INTERNAL_ERROR';
        SET @ErrorMessage = N'Die über @FilterTable benannte Temp-Tabelle wurde nicht angelegt.';
        RETURN;
    END CATCH;

    IF @FullObjectNames IS NOT NULL
       AND (@SchemaNames IS NOT NULL OR @ObjectNames IS NOT NULL)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@FullObjectNames ist mit @SchemaNames und @ObjectNames gegenseitig exklusiv.';
        RETURN;
    END;

    BEGIN TRY
        INSERT [#PrepareNameFilters_Work]
        ([FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName],[IsValid])
        SELECT 'SCHEMA',[ItemOrdinal],[NameValue],NULL,NULL,NULL,[IsValid]
        FROM [monitor].[TVF_ParseSqlNameList](@SchemaNames)
        UNION ALL
        SELECT 'OBJECT',[ItemOrdinal],[NameValue],NULL,NULL,NULL,[IsValid]
        FROM [monitor].[TVF_ParseSqlNameList](@ObjectNames)
        UNION ALL
        SELECT 'INDEX',[ItemOrdinal],[NameValue],NULL,NULL,NULL,[IsValid]
        FROM [monitor].[TVF_ParseSqlNameList](@IndexNames)
        UNION ALL
        SELECT 'STATISTICS',[ItemOrdinal],[NameValue],NULL,NULL,NULL,[IsValid]
        FROM [monitor].[TVF_ParseSqlNameList](@StatisticsNames)
        UNION ALL
        SELECT 'COLUMN',[ItemOrdinal],[NameValue],NULL,NULL,NULL,[IsValid]
        FROM [monitor].[TVF_ParseSqlNameList](@ColumnNames);

        INSERT [#PrepareNameFilters_Work]
        ([FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName],[IsValid])
        SELECT 'FULL_OBJECT',[ItemOrdinal],NULL,[DatabaseName],[SchemaName],[ObjectName],[IsValid]
        FROM [monitor].[TVF_ParseFullObjectNameList](@FullObjectNames);
    END TRY
    BEGIN CATCH
        SET @StatusCode = CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                               WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                               ELSE 'ERROR_HANDLED' END;
        SET @ErrorMessage = ERROR_MESSAGE();
        RETURN;
    END CATCH;

    IF EXISTS(SELECT 1 FROM [#PrepareNameFilters_Work] WHERE [IsValid]=0)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Mindestens eine Namensliste ist syntaktisch ungültig.';
        RETURN;
    END;

    DECLARE @HasDuplicates bit=0;
    SELECT @HasDuplicates=CONVERT(bit,CASE WHEN EXISTS
    (
        SELECT 1 FROM [#PrepareNameFilters_Work] WHERE [IsValid]=1
        GROUP BY [FilterType],
                 [NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS,
                 [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                 [SchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                 [ObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS
        HAVING COUNT(*) > 1
    ) THEN 1 ELSE 0 END);

    IF @HasDuplicates=1
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Eine Namensliste enthält case-sensitiv doppelte Werte.';
        RETURN;
    END;

    SET @Sql=N'INSERT '+@FilterTableQuoted+N'
([FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName])
SELECT [FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName]
FROM [#PrepareNameFilters_Work]
WHERE [IsValid]=1;';
    EXEC [sys].[sp_executesql] @Sql;
END;
GO

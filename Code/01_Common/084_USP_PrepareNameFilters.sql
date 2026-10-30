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
        PRINT N'monitor.USP_PrepareNameFilters validiert Namenslisten und ergänzt eine vorhandene lokale Filtertabelle. Sie liefert keine Analyse-Resultsets.';
        PRINT N'@SchemaNames nvarchar(max)=NULL: optionale Liste einteiliger Schemanamen, etwa N''[dbo]|[Sales]''. NULL bedeutet kein Filter. Pipe trennt außerhalb von [...]; ]] maskiert darin ]. Die Prüfung verlangt einen von PARSENAME(ItemText,1) gelieferten Wert und NULL für PARSENAME(ItemText,2); Teile 3 und 4 werden nicht gesondert geprüft. Das ist keine vollständige SQL-Bezeichnergrammatik. Leere Elemente und fehlerhafte Klammerung sind ungültig.';
        PRINT N'@ObjectNames nvarchar(max)=NULL: optionale Liste einteiliger Objektnamen; gleicher Listenvertrag wie @SchemaNames.';
        PRINT N'@FullObjectNames nvarchar(max)=NULL: optionale Liste mit Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. Bei drei Teilen ist das Schema erforderlich; vier Teile sind ungültig. PARSENAME zerlegt die Teile; bei überlangen Bestandteilen ist kein bestimmter Fehlercode zugesichert. Beispiel: N''[dbo].[ExampleObject]|[ExampleDatabase].[sales].[ExampleTable]''. Nicht mit @SchemaNames oder @ObjectNames kombinierbar.';
        PRINT N'@IndexNames, @StatisticsNames und @ColumnNames nvarchar(max)=NULL: optionale Listen einteiliger Namen; gleicher Listenvertrag wie @SchemaNames.';
        PRINT N'Einzelne Werte werden entquotet und case-sensitiv unter SQL_Latin1_General_CP1_CS_AS verglichen. Parser prüfen Struktur und PARSENAME-Ergebnisse; das ist keine vollständige SQL-Bezeichnergrammatik. Katalogexistenz und Berechtigungen werden nicht geprüft. Duplikate je Filtertyp sind ungültig.';
        PRINT N'@StatusCode varchar(40) OUTPUT und @ErrorMessage nvarchar(2048) OUTPUT: erforderlich; @ErrorMessage ist bei erfolgreicher Vorbereitung NULL. Statuswerte: AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR, TIMEOUT, DENIED_PERMISSION, ERROR_HANDLED.';
        PRINT N'@FilterTable sysname=N''#PrepareNameFilters_Result'': vorhandene lokale Tabelle mit FilterType varchar(20), ItemOrdinal int, NameValue sysname NULL, DatabaseName sysname NULL, SchemaName sysname NULL, ObjectName sysname NULL. Kein globales ##; Name höchstens 116 Zeichen.';
        PRINT N'Die Zieltabelle wird nicht vorab geleert. Gültige Zeilen werden angehängt. Ein Fehler vor dem abschließenden Insert lässt vorhandene Zeilen bestehen; der Insert ist nicht umfassend abgefangen. NULL in allen sechs Listen fügt keine Zeilen hinzu und setzt AVAILABLE.';
        PRINT N'@Hilfe bit=0: 0 verarbeitet; 1 druckt Hilfe und kehrt vor Initialisierung der OUTPUT-Werte zurück; NULL folgt dem normalen Verarbeitungspfad. OUTPUT-Bindungen sind auch bei Hilfe erforderlich; deren Werte bleiben dann unverändert.';
        PRINT N'Beispiel: ausführbarer Aufruf mit frischer, korrekt typisierter lokaler Tabelle und synthetischen Namen:';
        PRINT N'CREATE TABLE #PrepareNameFilters_HelpExample (FilterType varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, SchemaName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ObjectName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);';
        PRINT N'DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048);';
        PRINT N'EXEC [monitor].[USP_PrepareNameFilters] @SchemaNames=N''[ExampleSchema]'', @ObjectNames=N''[ExampleObject]'', @StatusCode=@StatusCode OUTPUT, @ErrorMessage=@ErrorMessage OUTPUT, @FilterTable=N''#PrepareNameFilters_HelpExample'';';
        PRINT N'SELECT @StatusCode AS StatusCode, @ErrorMessage AS ErrorMessage;';
        PRINT N'SELECT * FROM #PrepareNameFilters_HelpExample ORDER BY FilterType, ItemOrdinal;';
        PRINT N'DROP TABLE #PrepareNameFilters_HelpExample;';
        PRINT N'Bei Fehlern vor dem Insert bleibt das Ziel unverändert; es wird nicht geleert. Eine leere Tabelle kann auch einen erfolgreichen Aufruf mit ausschließlich NULL-Listen bedeuten.';
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

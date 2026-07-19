USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalWriteResultTable
Version      : 1.0.0
Stand        : 2026-07-19
Typ          : Interne Stored Procedure
Zweck        : Kopiert genau ein bereits materialisiertes Analyseergebnis in
               eine lokale Temp-Tabelle des Aufrufers. Eine leere Tabelle mit
               der Spalte [__MonitorPlaceholder] wird sicher an die native
               Quellstruktur angepasst; eine bereits passende Struktur wird
               zum Anhängen verwendet.
Sicherheit   : Ausschließlich lokale #Temp-Tabellen. Globale ##Temp-Tabellen
               und permanente Tabellen sind bewusst nicht zugelassen.
===============================================================================
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [monitor].[InternalWriteResultTable]
      @SourceTable  sysname
    , @ResultTable  sysname
    , @InsertedRows bigint         = NULL OUTPUT
    , @StatusCode   varchar(40)    = NULL OUTPUT
    , @ErrorNumber  int            = NULL OUTPUT
    , @ErrorMessage nvarchar(2048) = NULL OUTPUT
    , @ThrowOnError bit            = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TableThrowMessage nvarchar(2048);

    SELECT
          @InsertedRows = 0
        , @StatusCode = 'AVAILABLE'
        , @ErrorNumber = NULL
        , @ErrorMessage = NULL;

    IF @ThrowOnError IS NULL OR @ThrowOnError NOT IN (0,1)
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @ErrorMessage = N'@ThrowOnError muss 0 oder 1 enthalten.';
        GOTO TableWriteFailed;
    END;

    IF @SourceTable IS NULL
       OR LEFT(@SourceTable, 1) <> N'#'
       OR LEFT(@SourceTable, 2) = N'##'
       OR @ResultTable IS NULL
       OR LEFT(@ResultTable, 1) <> N'#'
       OR LEFT(@ResultTable, 2) = N'##'
       OR @ResultTable LIKE N'#Monitor%' COLLATE Latin1_General_100_CI_AS
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @ErrorMessage = N'@SourceTable und @ResultTable müssen lokale #Temp-Tabellen bezeichnen; ##Temp-, permanente Tabellen und das reservierte Präfix #Monitor sind nicht zulässig.';
        GOTO TableWriteFailed;
    END;

    DECLARE @SourceObjectId int = OBJECT_ID(N'tempdb..' + @SourceTable, N'U');
    DECLARE @TargetObjectId int = OBJECT_ID(N'tempdb..' + @ResultTable, N'U');

    IF @SourceObjectId IS NULL
    BEGIN
        SELECT
              @StatusCode = 'SOURCE_NOT_FOUND'
            , @ErrorMessage = N'Die interne Quelltabelle des ausgewählten Resultsets wurde nicht gefunden.';
        GOTO TableWriteFailed;
    END;

    IF @TargetObjectId IS NULL
    BEGIN
        SELECT
              @StatusCode = 'TARGET_NOT_FOUND'
            , @ErrorMessage = N'@ResultTable muss vor dem EXEC als lokale #Temp-Tabelle in derselben Sitzung angelegt werden.';
        GOTO TableWriteFailed;
    END;

    IF @SourceObjectId = @TargetObjectId
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @ErrorMessage = N'Quell- und Zieltabelle dürfen nicht identisch sein.';
        GOTO TableWriteFailed;
    END;

    CREATE TABLE [#MonitorSourceSchema]
    (
          [ColumnId] int NOT NULL
        , [ColumnName] sysname NOT NULL
        , [TypeName] sysname NOT NULL
        , [SystemTypeId] tinyint NOT NULL
        , [MaxLength] smallint NOT NULL
        , [Precision] tinyint NOT NULL
        , [Scale] tinyint NOT NULL
        , [CollationName] sysname NULL
        , [IsNullable] bit NOT NULL
        , [IsIdentity] bit NOT NULL
        , [IsComputed] bit NOT NULL
        , [IsUserDefined] bit NOT NULL
        , [IsAssemblyType] bit NOT NULL
        , [XmlCollectionId] int NOT NULL
    );

    CREATE TABLE [#MonitorTargetSchema]
    (
          [ColumnId] int NOT NULL
        , [ColumnName] sysname NOT NULL
        , [TypeName] sysname NOT NULL
        , [SystemTypeId] tinyint NOT NULL
        , [MaxLength] smallint NOT NULL
        , [Precision] tinyint NOT NULL
        , [Scale] tinyint NOT NULL
        , [CollationName] sysname NULL
        , [IsNullable] bit NOT NULL
        , [IsIdentity] bit NOT NULL
        , [IsComputed] bit NOT NULL
        , [IsUserDefined] bit NOT NULL
        , [IsAssemblyType] bit NOT NULL
        , [XmlCollectionId] int NOT NULL
    );

    INSERT [#MonitorSourceSchema]
    (
          [ColumnId], [ColumnName], [TypeName], [SystemTypeId], [MaxLength]
        , [Precision], [Scale], [CollationName], [IsNullable], [IsIdentity]
        , [IsComputed], [IsUserDefined], [IsAssemblyType], [XmlCollectionId]
    )
    SELECT
          [c].[column_id]
        , [c].[name]
        , [t].[name]
        , [c].[system_type_id]
        , [c].[max_length]
        , [c].[precision]
        , [c].[scale]
        , [c].[collation_name]
        , [c].[is_nullable]
        , [c].[is_identity]
        , [c].[is_computed]
        , [t].[is_user_defined]
        , [t].[is_assembly_type]
        , [c].[xml_collection_id]
    FROM [tempdb].[sys].[columns] AS [c]
    JOIN [tempdb].[sys].[types] AS [t]
      ON [t].[user_type_id] = [c].[user_type_id]
    WHERE [c].[object_id] = @SourceObjectId;

    IF NOT EXISTS (SELECT 1 FROM [#MonitorSourceSchema])
    BEGIN
        SELECT
              @StatusCode = 'UNSUPPORTED_SOURCE_SCHEMA'
            , @ErrorMessage = N'Das ausgewählte Resultset besitzt keine exportierbaren Spalten.';
        GOTO TableWriteFailed;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM [#MonitorSourceSchema]
        WHERE [IsComputed] = 1
           OR [IsUserDefined] = 1
           OR [IsAssemblyType] = 1
           OR [XmlCollectionId] <> 0
           OR [TypeName] IN (N'timestamp', N'rowversion')
           OR [ColumnName] = N'__MonitorPlaceholder'
    )
    BEGIN
        SELECT
              @StatusCode = 'UNSUPPORTED_SOURCE_SCHEMA'
            , @ErrorMessage = N'Das ausgewählte Resultset enthält einen nicht sicher reproduzierbaren Datentyp, eine berechnete Spalte oder den reservierten Platzhalternamen.';
        GOTO TableWriteFailed;
    END;

    DECLARE @TargetColumnCount int;
    DECLARE @IsPlaceholderTarget bit = 0;
    DECLARE @TargetHasRows bit = 0;

    SELECT
          @TargetColumnCount = COUNT(*)
        , @IsPlaceholderTarget = CONVERT
          (
              bit,
              CASE
                  WHEN COUNT(*) = 1
                   AND MAX(CASE
                               WHEN [c].[name] = N'__MonitorPlaceholder'
                                AND [c].[system_type_id] = 104
                                AND [c].[is_nullable] = 1
                                AND [c].[is_identity] = 0
                                AND [c].[is_computed] = 0
                                   THEN 1
                               ELSE 0
                           END) = 1
                      THEN 1
                  ELSE 0
              END
          )
    FROM [tempdb].[sys].[columns] AS [c]
    WHERE [c].[object_id] = @TargetObjectId;

    IF @IsPlaceholderTarget = 1
    BEGIN
        DECLARE @HasRowsSql nvarchar(max) =
            N'SELECT @HasRows = CONVERT(bit, CASE WHEN EXISTS (SELECT 1 FROM '
            + QUOTENAME(@ResultTable)
            + N') THEN 1 ELSE 0 END);';

        EXEC [sys].[sp_executesql]
              @HasRowsSql
            , N'@HasRows bit OUTPUT'
            , @HasRows = @TargetHasRows OUTPUT;

        IF @TargetHasRows = 1
        BEGIN
            SELECT
                  @StatusCode = 'TARGET_SCHEMA_MISMATCH'
                , @ErrorMessage = N'Die Platzhalter-Zieltabelle muss leer sein, bevor ihre Struktur angepasst werden kann.';
            GOTO TableWriteFailed;
        END;

        DECLARE @ColumnDefinitions nvarchar(max);

        SELECT @ColumnDefinitions = STUFF
        (
            (
                SELECT
                      N', '
                    + QUOTENAME([s].[ColumnName])
                    + N' '
                    + CASE
                          WHEN [s].[TypeName] IN (N'varchar', N'char', N'varbinary', N'binary')
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CASE WHEN [s].[MaxLength] = -1 THEN N'MAX' ELSE CONVERT(nvarchar(10), [s].[MaxLength]) END + N')'
                          WHEN [s].[TypeName] IN (N'nvarchar', N'nchar')
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CASE WHEN [s].[MaxLength] = -1 THEN N'MAX' ELSE CONVERT(nvarchar(10), [s].[MaxLength] / 2) END + N')'
                          WHEN [s].[TypeName] IN (N'decimal', N'numeric')
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CONVERT(nvarchar(10), [s].[Precision]) + N',' + CONVERT(nvarchar(10), [s].[Scale]) + N')'
                          WHEN [s].[TypeName] IN (N'datetime2', N'datetimeoffset', N'time')
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CONVERT(nvarchar(10), [s].[Scale]) + N')'
                          WHEN [s].[TypeName] = N'float'
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CONVERT(nvarchar(10), [s].[Precision]) + N')'
                          ELSE QUOTENAME([s].[TypeName])
                      END
                    + CASE WHEN [s].[CollationName] IS NULL THEN N'' ELSE N' COLLATE ' + [s].[CollationName] END
                    + CASE WHEN [s].[IsNullable] = 1 THEN N' NULL' ELSE N' NOT NULL' END
                FROM [#MonitorSourceSchema] AS [s]
                ORDER BY [s].[ColumnId]
                FOR XML PATH(N''), TYPE
            ).value(N'.', N'nvarchar(max)')
            , 1
            , 2
            , N''
        );

        BEGIN TRY
            DECLARE @AlterSql nvarchar(max) =
                  N'ALTER TABLE ' + QUOTENAME(@ResultTable) + N' ADD ' + @ColumnDefinitions + N';'
                + N' ALTER TABLE ' + QUOTENAME(@ResultTable) + N' DROP COLUMN [__MonitorPlaceholder];';

            EXEC [sys].[sp_executesql] @AlterSql;
        END TRY
        BEGIN CATCH
            SELECT
                  @StatusCode = 'TABLE_WRITE_ERROR'
                , @ErrorNumber = ERROR_NUMBER()
                , @ErrorMessage = ERROR_MESSAGE();
            GOTO TableWriteFailed;
        END CATCH;

        SET @TargetObjectId = OBJECT_ID(N'tempdb..' + @ResultTable, N'U');
    END
    ELSE IF @TargetColumnCount = 1
            AND EXISTS
            (
                SELECT 1
                FROM [tempdb].[sys].[columns]
                WHERE [object_id] = @TargetObjectId
                  AND [name] = N'__MonitorPlaceholder'
            )
    BEGIN
        SELECT
              @StatusCode = 'TARGET_SCHEMA_MISMATCH'
            , @ErrorMessage = N'Der Platzhalter muss exakt als [__MonitorPlaceholder] bit NULL definiert sein.';
        GOTO TableWriteFailed;
    END;

    INSERT [#MonitorTargetSchema]
    (
          [ColumnId], [ColumnName], [TypeName], [SystemTypeId], [MaxLength]
        , [Precision], [Scale], [CollationName], [IsNullable], [IsIdentity]
        , [IsComputed], [IsUserDefined], [IsAssemblyType], [XmlCollectionId]
    )
    SELECT
          [c].[column_id]
        , [c].[name]
        , [t].[name]
        , [c].[system_type_id]
        , [c].[max_length]
        , [c].[precision]
        , [c].[scale]
        , [c].[collation_name]
        , [c].[is_nullable]
        , [c].[is_identity]
        , [c].[is_computed]
        , [t].[is_user_defined]
        , [t].[is_assembly_type]
        , [c].[xml_collection_id]
    FROM [tempdb].[sys].[columns] AS [c]
    JOIN [tempdb].[sys].[types] AS [t]
      ON [t].[user_type_id] = [c].[user_type_id]
    WHERE [c].[object_id] = @TargetObjectId;

    IF EXISTS
    (
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#MonitorSourceSchema]
        EXCEPT
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#MonitorTargetSchema]
    )
    OR EXISTS
    (
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#MonitorTargetSchema]
        EXCEPT
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#MonitorSourceSchema]
    )
    OR EXISTS
    (
        SELECT 1
        FROM [#MonitorTargetSchema]
        WHERE [IsIdentity] = 1
           OR [IsComputed] = 1
           OR [IsUserDefined] = 1
           OR [IsAssemblyType] = 1
           OR [XmlCollectionId] <> 0
    )
    BEGIN
        SELECT
              @StatusCode = 'TARGET_SCHEMA_MISMATCH'
            , @ErrorMessage = N'Die vorhandene Struktur von @ResultTable stimmt nicht exakt mit dem ausgewählten Resultset überein.';
        GOTO TableWriteFailed;
    END;

    DECLARE @ColumnList nvarchar(max);

    SELECT @ColumnList = STUFF
    (
        (
            SELECT N', ' + QUOTENAME([s].[ColumnName])
            FROM [#MonitorSourceSchema] AS [s]
            ORDER BY [s].[ColumnId]
            FOR XML PATH(N''), TYPE
        ).value(N'.', N'nvarchar(max)')
        , 1
        , 2
        , N''
    );

    BEGIN TRY
        DECLARE @InsertSql nvarchar(max) =
              N'INSERT ' + QUOTENAME(@ResultTable) + N' (' + @ColumnList + N')'
            + N' SELECT ' + @ColumnList + N' FROM ' + QUOTENAME(@SourceTable) + N';'
            + N' SET @Rows = @@ROWCOUNT;';

        EXEC [sys].[sp_executesql]
              @InsertSql
            , N'@Rows bigint OUTPUT'
            , @Rows = @InsertedRows OUTPUT;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = 'TABLE_WRITE_ERROR'
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = ERROR_MESSAGE();
    END CATCH;

    IF @StatusCode <> 'AVAILABLE'
        GOTO TableWriteFailed;

    RETURN;

TableWriteFailed:
    IF @ThrowOnError = 1
    BEGIN
        SET @TableThrowMessage = CONCAT
        (
              N'TABLE-Ausgabe fehlgeschlagen ('
            , COALESCE(@StatusCode, N'UNKNOWN')
            , N'): '
            , COALESCE(@ErrorMessage, N'Unbekannter Fehler.')
        );
        THROW 51010, @TableThrowMessage, 1;
    END;
END;
GO

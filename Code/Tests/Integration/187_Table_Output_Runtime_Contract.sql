USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 187_Table_Output_Runtime_Contract.sql
Zweck        : Prüft Strukturadaption, typisierten Insert, Append, kontrollierte
               Schemaabweichung und die öffentliche TABLE-Ausgabe ausschließlich
               mit synthetischen lokalen #Temp-Tabellen.
Datenschutz  : Keine realen Laufzeitwerte werden persistiert oder ausgegeben.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

CREATE TABLE [#TableOutputFailure]
(
      [TestName] sysname NOT NULL
    , [Detail] nvarchar(2048) NOT NULL
);

CREATE TABLE [#TableContractSource]
(
      [Id] int NOT NULL
    , [Name] nvarchar(40) COLLATE Latin1_General_100_CI_AS NULL
    , [Amount] decimal(19,4) NULL
    , [CapturedUtc] datetime2(3) NOT NULL
);

INSERT [#TableContractSource] ([Id],[Name],[Amount],[CapturedUtc])
VALUES
      (1,N'Example A',CONVERT(decimal(19,4),12.3456),CONVERT(datetime2(3),'2026-01-01T00:00:00.000'))
    , (2,N'Example B',NULL,CONVERT(datetime2(3),'2026-01-02T00:00:00.000'));

CREATE TABLE [#TableContractTarget] ([__MonitorPlaceholder] bit NULL);

DECLARE @Rows bigint,@Status varchar(40),@ErrorNumber int,@ErrorMessage nvarchar(2048);

EXEC [monitor].[InternalWriteResultTable]
      @SourceTable=N'#TableContractSource'
    , @ResultTable=N'#TableContractTarget'
    , @InsertedRows=@Rows OUTPUT
    , @StatusCode=@Status OUTPUT
    , @ErrorNumber=@ErrorNumber OUTPUT
    , @ErrorMessage=@ErrorMessage OUTPUT;

IF @Status<>'AVAILABLE' OR @Rows<>2
    INSERT [#TableOutputFailure] VALUES(N'PLACEHOLDER_ADAPT',CONCAT(N'Erwartet AVAILABLE/2, erhalten ',COALESCE(@Status,N'NULL'),N'/',COALESCE(CONVERT(nvarchar(30),@Rows),N'NULL'),N': ',COALESCE(@ErrorMessage,N'')));

IF COL_LENGTH(N'tempdb..#TableContractTarget',N'__MonitorPlaceholder') IS NOT NULL
   OR COL_LENGTH(N'tempdb..#TableContractTarget',N'Id') IS NULL
   OR COL_LENGTH(N'tempdb..#TableContractTarget',N'Name')<>80
    INSERT [#TableOutputFailure] VALUES(N'NATIVE_COLUMN_SHAPE',N'Platzhalter oder native int-/nvarchar-Struktur stimmt nach der Adaption nicht.');

IF NOT EXISTS
(
    SELECT 1
    FROM [tempdb].[sys].[columns] AS [c]
    WHERE [c].[object_id]=OBJECT_ID(N'tempdb..#TableContractTarget')
      AND [c].[name]=N'Amount'
      AND [c].[precision]=19
      AND [c].[scale]=4
      AND [c].[is_nullable]=1
)
    INSERT [#TableOutputFailure] VALUES(N'DECIMAL_SHAPE',N'Precision, Scale oder Nullability der decimal-Spalte wurden nicht erhalten.');

IF NOT EXISTS
(
    SELECT 1
    FROM [tempdb].[sys].[columns] AS [c]
    WHERE [c].[object_id]=OBJECT_ID(N'tempdb..#TableContractTarget')
      AND [c].[name]=N'CapturedUtc'
      AND [c].[scale]=3
      AND [c].[is_nullable]=0
)
    INSERT [#TableOutputFailure] VALUES(N'DATETIME_SHAPE',N'Scale oder Nullability der datetime2-Spalte wurden nicht erhalten.');

IF (SELECT COUNT_BIG(*) FROM [#TableContractTarget])<>2
    INSERT [#TableOutputFailure] VALUES(N'PLACEHOLDER_ROWS',N'Die Struktur wurde angepasst, aber die erwarteten zwei synthetischen Zeilen wurden nicht geschrieben.');

CREATE TABLE [#TableContractExactTarget]
(
      [Id] int NOT NULL
    , [Name] nvarchar(40) COLLATE Latin1_General_100_CI_AS NULL
    , [Amount] decimal(19,4) NULL
    , [CapturedUtc] datetime2(3) NOT NULL
);

SET @Rows=NULL;SET @Status=NULL;SET @ErrorNumber=NULL;SET @ErrorMessage=NULL;
EXEC [monitor].[InternalWriteResultTable]
      @SourceTable=N'#TableContractSource'
    , @ResultTable=N'#TableContractExactTarget'
    , @InsertedRows=@Rows OUTPUT
    , @StatusCode=@Status OUTPUT
    , @ErrorNumber=@ErrorNumber OUTPUT
    , @ErrorMessage=@ErrorMessage OUTPUT;

IF @Status<>'AVAILABLE'
   OR @Rows<>2
   OR (SELECT COUNT_BIG(*) FROM [#TableContractExactTarget])<>2
   OR NOT EXISTS
      (
          SELECT 1
          FROM [#TableContractExactTarget]
          WHERE [Id]=1
            AND [Name]=N'Example A'
            AND [Amount]=CONVERT(decimal(19,4),12.3456)
      )
    INSERT [#TableOutputFailure] VALUES(N'TYPED_INSERT',N'Die synthetischen typisierten Zeilen wurden nicht unverändert in eine exakt passende Zieltabelle kopiert.');

SET @Rows=NULL;SET @Status=NULL;SET @ErrorNumber=NULL;SET @ErrorMessage=NULL;
EXEC [monitor].[InternalWriteResultTable]
      @SourceTable=N'#TableContractSource'
    , @ResultTable=N'#TableContractExactTarget'
    , @InsertedRows=@Rows OUTPUT
    , @StatusCode=@Status OUTPUT
    , @ErrorNumber=@ErrorNumber OUTPUT
    , @ErrorMessage=@ErrorMessage OUTPUT;

IF @Status<>'AVAILABLE' OR @Rows<>2 OR (SELECT COUNT_BIG(*) FROM [#TableContractExactTarget])<>4
    INSERT [#TableOutputFailure] VALUES(N'EXACT_SCHEMA_APPEND',N'Eine bereits exakt passende Zieltabelle wurde nicht korrekt ergänzt.');

CREATE TABLE [#TableContractMismatch] ([Id] bigint NOT NULL);
INSERT [#TableContractMismatch] VALUES(99);
SET @Rows=NULL;SET @Status=NULL;SET @ErrorNumber=NULL;SET @ErrorMessage=NULL;
EXEC [monitor].[InternalWriteResultTable]
      @SourceTable=N'#TableContractSource'
    , @ResultTable=N'#TableContractMismatch'
    , @InsertedRows=@Rows OUTPUT
    , @StatusCode=@Status OUTPUT
    , @ErrorNumber=@ErrorNumber OUTPUT
    , @ErrorMessage=@ErrorMessage OUTPUT;

IF @Status<>'TARGET_SCHEMA_MISMATCH'
   OR (SELECT COUNT_BIG(*) FROM [#TableContractMismatch])<>1
   OR COL_LENGTH(N'tempdb..#TableContractMismatch',N'Name') IS NOT NULL
    INSERT [#TableOutputFailure] VALUES(N'SCHEMA_MISMATCH_SAFE',N'Eine gefüllte abweichende Zieltabelle wurde nicht kontrolliert und unverändert abgelehnt.');

CREATE TABLE [#TableContractNonEmptyPlaceholder] ([__MonitorPlaceholder] bit NULL);
INSERT [#TableContractNonEmptyPlaceholder] VALUES(NULL);
SET @Rows=NULL;SET @Status=NULL;SET @ErrorNumber=NULL;SET @ErrorMessage=NULL;
EXEC [monitor].[InternalWriteResultTable]
      @SourceTable=N'#TableContractSource'
    , @ResultTable=N'#TableContractNonEmptyPlaceholder'
    , @InsertedRows=@Rows OUTPUT
    , @StatusCode=@Status OUTPUT
    , @ErrorNumber=@ErrorNumber OUTPUT
    , @ErrorMessage=@ErrorMessage OUTPUT;

IF @Status<>'TARGET_SCHEMA_MISMATCH'
   OR COL_LENGTH(N'tempdb..#TableContractNonEmptyPlaceholder',N'__MonitorPlaceholder') IS NULL
    INSERT [#TableOutputFailure] VALUES(N'NONEMPTY_PLACEHOLDER_SAFE',N'Ein gefüllter Platzhalter wurde nicht kontrolliert und unverändert abgelehnt.');

SET @Status=NULL;SET @ErrorMessage=NULL;
EXEC [monitor].[InternalWriteResultTable]
      @SourceTable=N'#TableContractSource'
    , @ResultTable=N'dbo.ExamplePermanentTarget'
    , @StatusCode=@Status OUTPUT
    , @ErrorMessage=@ErrorMessage OUTPUT;
IF @Status<>'INVALID_PARAMETER'
    INSERT [#TableOutputFailure] VALUES(N'LOCAL_TEMP_ONLY',N'Ein permanenter Tabellenname wurde nicht abgelehnt.');

CREATE TABLE [#PublicTableTarget] ([__MonitorPlaceholder] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_CheckAnalyseAccess]
          @ResultSetArt=' table '
        , @ResultTable=N'#PublicTableTarget'
        , @PrintMeldungen=0;

    IF COL_LENGTH(N'tempdb..#PublicTableTarget',N'__MonitorPlaceholder') IS NOT NULL
       OR COL_LENGTH(N'tempdb..#PublicTableTarget',N'AnalysisClass') IS NULL
       OR COL_LENGTH(N'tempdb..#PublicTableTarget',N'StatusCode') IS NULL
        INSERT [#TableOutputFailure] VALUES(N'PUBLIC_TABLE_MODE',N'Die öffentliche Procedure hat ihre primäre native Ergebnisstruktur nicht in @ResultTable geschrieben.');
END TRY
BEGIN CATCH
    INSERT [#TableOutputFailure] VALUES(N'PUBLIC_TABLE_MODE',CONCAT(N'Öffentlicher TABLE-Aufruf fehlgeschlagen: ',ERROR_MESSAGE()));
END CATCH;

CREATE TABLE [#PublicTableMismatch] ([WrongColumn] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_CheckAnalyseAccess]
          @ResultSetArt='TABLE'
        , @ResultTable=N'#PublicTableMismatch'
        , @PrintMeldungen=0;
    INSERT [#TableOutputFailure] VALUES(N'PUBLIC_SCHEMA_ERROR',N'Die öffentliche Procedure hat eine abweichende Zielstruktur nicht mit Fehler 51010 abgelehnt.');
END TRY
BEGIN CATCH
    IF ERROR_NUMBER()<>51010
        INSERT [#TableOutputFailure] VALUES(N'PUBLIC_SCHEMA_ERROR',CONCAT(N'Erwartet Fehler 51010, erhalten ',ERROR_NUMBER(),N': ',ERROR_MESSAGE()));
END CATCH;

IF COL_LENGTH(N'tempdb..#PublicTableMismatch',N'WrongColumn') IS NULL
   OR COL_LENGTH(N'tempdb..#PublicTableMismatch',N'AnalysisClass') IS NOT NULL
    INSERT [#TableOutputFailure] VALUES(N'PUBLIC_SCHEMA_UNCHANGED',N'Die öffentliche Procedure hat eine abweichende Zielstruktur verändert.');

SELECT [TestName],[Detail] FROM [#TableOutputFailure] ORDER BY [TestName];
IF EXISTS(SELECT 1 FROM [#TableOutputFailure])
    THROW 54700,N'Der TABLE-Ausgabevertrag ist verletzt.',1;
GO

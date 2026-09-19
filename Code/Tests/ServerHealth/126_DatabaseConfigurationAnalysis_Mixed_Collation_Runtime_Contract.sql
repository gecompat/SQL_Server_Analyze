USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 126_DatabaseConfigurationAnalysis_Mixed_Collation_Runtime_Contract.sql
Zweck        : Der Test prueft die Datenbankkonfigurationsanalyse mit einer
               Framework- und einer abweichend kollierten Zieldatenbank.
Datenschutz  : Verwendet ausschliesslich synthetische Datenbanknamen und liest
               nur Systemkataloge.
Nebenwirkung : Erstellt und entfernt [ExampleCollationTarget]. Der Lauf setzt
               voraus, dass dieser Name vor dem Start nicht vorhanden ist.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;
DECLARE @StatusCode varchar(60) = NULL;
DECLARE @IsPartial bit = NULL;
DECLARE @TargetDatabase sysname = N'ExampleCollationTarget';

IF DB_ID(@TargetDatabase) IS NOT NULL
    THROW 54760,N'Die synthetische Zieldatenbank ExampleCollationTarget ist bereits vorhanden.',1;

BEGIN TRY
    EXEC(N'CREATE DATABASE [ExampleCollationTarget] COLLATE Latin1_General_100_CI_AS;');

    EXEC [monitor].[USP_DatabaseConfigurationAnalysis]
          @DatabaseNames = N'[DeineDatenbank]|[ExampleCollationTarget]'
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @StatusCode OUTPUT
        , @IsPartialOut = @IsPartial OUTPUT;

    IF @StatusCode NOT IN ('AVAILABLE','AVAILABLE_LIMITED')
        THROW 54761,N'Die Datenbankkonfigurationsanalyse lieferte keinen verfuegbaren Status.',1;
    IF ISJSON(@Json) <> 1
        THROW 54762,N'Die Datenbankkonfigurationsanalyse lieferte kein gueltiges JSON.',1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM OPENJSON(@Json,N'$.settings')
             WITH ([DatabaseName] sysname N'$.DatabaseName') AS [s]
        WHERE [s].[DatabaseName] = N'DeineDatenbank'
    )
        THROW 54763,N'Die Frameworkdatenbank fehlt im Einstellungsinventar.',1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM OPENJSON(@Json,N'$.settings')
             WITH ([DatabaseName] sysname N'$.DatabaseName') AS [s]
        WHERE [s].[DatabaseName] = N'ExampleCollationTarget'
    )
        THROW 54764,N'Die abweichend kollierte Zieldatenbank fehlt im Einstellungsinventar.',1;
END TRY
BEGIN CATCH
    IF DB_ID(@TargetDatabase) IS NOT NULL
    BEGIN
        ALTER DATABASE [ExampleCollationTarget] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleCollationTarget];
    END;
    THROW;
END CATCH;

ALTER DATABASE [ExampleCollationTarget] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE [ExampleCollationTarget];
GO

USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 199_Result_Table_Json_Unicode_Collation_Runtime_Contract.sql
Zweck        : Der Test prueft akzent- und supplementaerzeichenunterschiedliche
               JSON-Resultsetnamen im zentralen TABLE-Mappingvertrag.
Datenschutz  : Der Test verwendet nur synthetische Namen und Temp-Tabellen.
Nebenwirkung : Keine dauerhaften Objekte oder Datenbankaenderungen.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

CREATE TABLE [#ResultTableJsonUnicodeMap]
(
      [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
CREATE TABLE [#ResultTableJsonUnicodeResume]([Seed] bit NULL);
CREATE TABLE [#ResultTableJsonUnicodeResumeAccent]([Seed] bit NULL);
CREATE TABLE [#ResultTableJsonUnicodeFaceSmiling]([Seed] bit NULL);
CREATE TABLE [#ResultTableJsonUnicodeFaceGrinning]([Seed] bit NULL);

DECLARE @StatusCode varchar(40) = NULL;
DECLARE @ErrorMessage nvarchar(2048) = NULL;

EXEC [monitor].[InternalPrepareResultTables]
      @ResultTablesJson = N'{"Resume":"#ResultTableJsonUnicodeResume","Résumé":"#ResultTableJsonUnicodeResumeAccent"}'
    , @AllowedResultNames = N'Resume|Résumé'
    , @MappingTable = N'#ResultTableJsonUnicodeMap'
    , @StatusCode = @StatusCode OUTPUT
    , @ErrorMessage = @ErrorMessage OUTPUT
    , @ThrowOnError = 0;

IF @StatusCode <> 'AVAILABLE'
    THROW 54895,N'Der JSON-TABLE-Mappingvertrag lehnte akzentunterschiedliche Resultsetnamen ab.',1;
IF (SELECT COUNT(*) FROM [#ResultTableJsonUnicodeMap]) <> 2
    THROW 54896,N'Der JSON-TABLE-Mappingvertrag materialisierte nicht beide Resultsetnamen.',1;
IF (SELECT COUNT(DISTINCT CONVERT(varbinary(256),[ResultName])) FROM [#ResultTableJsonUnicodeMap]) <> 2
    THROW 54897,N'Der JSON-TABLE-Mappingvertrag hat akzentunterschiedliche Resultsetnamen zusammengeführt.',1;

DELETE FROM [#ResultTableJsonUnicodeMap];
SET @StatusCode = NULL;
SET @ErrorMessage = NULL;

EXEC [monitor].[InternalPrepareResultTables]
      @ResultTablesJson = N'{"Face😀":"#ResultTableJsonUnicodeFaceSmiling","Face😃":"#ResultTableJsonUnicodeFaceGrinning"}'
    , @AllowedResultNames = N'Face😀|Face😃'
    , @MappingTable = N'#ResultTableJsonUnicodeMap'
    , @StatusCode = @StatusCode OUTPUT
    , @ErrorMessage = @ErrorMessage OUTPUT
    , @ThrowOnError = 0;

IF @StatusCode <> 'AVAILABLE'
    THROW 54898,N'Der JSON-TABLE-Mappingvertrag lehnte supplementaerzeichenunterschiedliche Resultsetnamen ab.',1;
IF (SELECT COUNT(*) FROM [#ResultTableJsonUnicodeMap]) <> 2
    THROW 54899,N'Der JSON-TABLE-Mappingvertrag materialisierte nicht beide supplementaerzeichenunterschiedlichen Resultsetnamen.',1;
IF (SELECT COUNT(DISTINCT CONVERT(varbinary(256),[ResultName])) FROM [#ResultTableJsonUnicodeMap]) <> 2
    THROW 54900,N'Der JSON-TABLE-Mappingvertrag hat supplementaerzeichenunterschiedliche Resultsetnamen zusammengeführt.',1;
GO

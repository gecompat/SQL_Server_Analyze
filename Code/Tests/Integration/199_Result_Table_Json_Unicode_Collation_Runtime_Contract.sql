USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 199_Result_Table_Json_Unicode_Collation_Runtime_Contract.sql
Zweck        : Der Test prueft akzentunterschiedliche JSON-Resultsetnamen im
               zentralen TABLE-Mappingvertrag.
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
IF (SELECT COUNT(DISTINCT [ResultName] COLLATE SQL_Latin1_General_CP1_CS_AS) FROM [#ResultTableJsonUnicodeMap]) <> 2
    THROW 54897,N'Der JSON-TABLE-Mappingvertrag hat akzentunterschiedliche Resultsetnamen zusammengeführt.',1;
GO

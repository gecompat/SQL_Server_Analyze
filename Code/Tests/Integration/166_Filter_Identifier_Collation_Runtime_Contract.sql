USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 166_Filter_Identifier_Collation_Runtime_Contract.sql
Zweck        : Der Test prueft case-sensitive und akzentunterschiedliche
               bracket-aware Namensfilter der zentralen Filterprocedure.
Datenschutz  : Der Test verwendet nur synthetische Namen und Temp-Tabellen.
Nebenwirkung : Keine dauerhaften Objekte oder Datenbankaenderungen.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

CREATE TABLE [#FilterIdentifierCollation_Result]
(
      [FilterType] varchar(20) NOT NULL
    , [ItemOrdinal] int NOT NULL
    , [NameValue] sysname NULL
    , [DatabaseName] sysname NULL
    , [SchemaName] sysname NULL
    , [ObjectName] sysname NULL
);

DECLARE @StatusCode varchar(40) = NULL;
DECLARE @ErrorMessage nvarchar(2048) = NULL;

EXEC [monitor].[USP_PrepareNameFilters]
      @SchemaNames = N'[ExampleCase]|[examplecase]|[Café]|[Cafe]'
    , @StatusCode = @StatusCode OUTPUT
    , @ErrorMessage = @ErrorMessage OUTPUT
    , @FilterTable = N'#FilterIdentifierCollation_Result';

IF @StatusCode <> 'AVAILABLE'
    THROW 54770,N'Der zentrale Filtervertrag lehnte case- oder akzentunterschiedliche Namen ab.',1;

IF (SELECT COUNT(*) FROM [#FilterIdentifierCollation_Result]) <> 4
    THROW 54771,N'Der zentrale Filtervertrag erhielt nicht alle vier Namen.',1;

IF (SELECT COUNT(DISTINCT [NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS) FROM [#FilterIdentifierCollation_Result]) <> 4
    THROW 54772,N'Der zentrale Filtervertrag hat case- oder akzentunterschiedliche Namen zusammengeführt.',1;
GO

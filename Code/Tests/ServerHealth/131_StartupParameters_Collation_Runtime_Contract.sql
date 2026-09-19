USE [DeineDatenbank];
GO

/*
Datei: 131_StartupParameters_Collation_Runtime_Contract.sql
Zweck: Prüft den strukturierten Leerlistenvertrag von USP_StartupParameters auf Linux.
Datenschutz: Es werden keine Startparameterwerte ausgegeben oder gespeichert.
Nebenwirkung: Keine.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;
DECLARE @StatusCode varchar(40) = NULL;
DECLARE @IsPartial bit = NULL;
DECLARE @ErrorNumber int = NULL;
DECLARE @ErrorMessage nvarchar(2048) = NULL;

EXEC [monitor].[USP_StartupParameters]
    @PrintMeldungen = 0,
    @ResultSetArt = 'NONE',
    @JsonErzeugen = 1,
    @Json = @Json OUTPUT,
    @StatusCodeOut = @StatusCode OUTPUT,
    @IsPartialOut = @IsPartial OUTPUT,
    @ErrorNumberOut = @ErrorNumber OUTPUT,
    @ErrorMessageOut = @ErrorMessage OUTPUT;

IF ISJSON(@Json) <> 1
    THROW 54920, N'Der Startparameter-Collationvertrag lieferte kein JSON-Ergebnis.', 1;

IF @StatusCode <> 'AVAILABLE'
    OR @IsPartial <> 0
    OR @ErrorNumber IS NOT NULL
    OR @ErrorMessage IS NOT NULL
    THROW 54921, N'Der Startparameter-Collationvertrag lieferte keinen erwarteten Linux-Leerlistenstatus.', 1;
GO

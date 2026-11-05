USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalPrepareSingleResultTable
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Interne Stored Procedure
Zweck        : Leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter
               und gibt bei erfolgreicher Namensauflösung das lokale Ziel
               zurück. Der JSON-Vertrag kann mehrere Schlüssel-Wert-Paare
               enthalten.
Parameter:
@ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). JSON-Objekt, keine Liste; NULL, leerer Text, {} oder kein Paar ist ungültig. Werte und Schlüssel müssen Zeichenketten sein. Der Mehrfachbaustein konvertiert Schlüssel und Ziel nach sysname vor seinen Guards. Zielwerte müssen rohe, unqualifizierte lokale #Temp-Namen ohne ## oder #Monitor-Präfix (CI) mit LEN höchstens 116 sein; sie werden nicht getrimmt. Doppelte konvertierte Schlüssel werden binär und doppelte Ziele unter Latin1_General_100_CI_AS erkannt. Ziele müssen existieren, leer sein und genau eine Seed-Spalte besitzen. Der Schlüssel wird gegen die normalisierte Whitelist geprüft; die spätere Einzelauflösung nutzt den ursprünglichen @ResultName unter CS-Kollation, weshalb trotz AVAILABLE @TargetTable NULL bleiben kann.
@ResultName sysname, Default: kein Default (Pflichtparameter). Wird als @AllowedResultNames weitergereicht. NULL, leer oder nur leere Tokens ergibt keine zulässigen Namen. Der Wert wird als Pipe-Liste verarbeitet; | wird nicht escaped, nur U+0020 am Rand jedes Tokens wird entfernt. Der spätere Lookup vergleicht den ursprünglichen Wert unter CS-Kollation. Normalisierung oder Pipe-Aufteilung kann daher trotz AVAILABLE zu keinem Treffer und NULL in @TargetTable führen.
@TargetTable sysname, Default: kein Default, OUTPUT (Pflichtparameter). Argument muss angegeben werden; zum Empfang wird eine Aufrufervariable mit OUTPUT gebunden; Eingabewert wird ignoriert und beim Eintritt auf NULL gesetzt. Der sysname-Typ begrenzt die Länge bereits bei der Parameterbindung. Bei unterdrücktem Fehler oder fehlendem originalen CS-Lookup-Treffer bleibt der Wert NULL. Ein übergebener NULL-, Leertext- oder anderer Anfangswert wird nicht ausgewertet.
@ThrowOnError bit, Default: 1. Kann ausgelassen werden. 0 unterdrückt nur behandelte Fehler des weitergeleiteten Preflights; 1 lässt für solche Fehler 51011 auslösen. NULL wird als INVALID_PARAMETER behandelt, löst aber wegen NULL keinen Fehler 51011 aus. Leerer Text ist keine unterstützte Bit-Eingabe.
Fehler- und Seiteneffektgrenzen: Eigene Mapping-Temp-DDL erfolgt vor dem Aufruf des Mehrfachbausteins und dessen Statusinitialisierung; Fehler werden erneut ausgelöst. Das Ziel wird durch den Mehrfachbaustein mit einer temporären Marker-Spalte geprüft; ADD/DROP sind reale temporäre Schemaänderungen mit best-effort Bereinigung. Es erfolgt keine Erstellung oder dauerhafte Anpassung an Resultatspalten, keine atomare Rücknahmezusage. Eigene Mapping-DDL erhält 1000 ms; im CATCH wird der zuvor erfasste LOCK_TIMEOUT-Wert wieder gesetzt und der Fehler erneut ausgelöst. Nach Erfolg wird LOCK_TIMEOUT 0 gesetzt, Zielauflösung bleibt NOWAIT.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalPrepareSingleResultTable]
      @ResultTablesJson  nvarchar(max)
    , @ResultName        sysname
    , @TargetTable       sysname        OUTPUT
    , @ThrowOnError      bit            = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET @TargetTable=NULL;

    -- Ein geerbter NOWAIT-Wert darf die eigene TempDB-Metadatenanlage
    -- nicht wegen einer kurzzeitigen Kollision abbrechen. Nur diese lokale
    -- Anlage erhält ein Zeitbudget von 1000 ms; die nachfolgende
    -- Auflösung fremder Tabellen bleibt bei LOCK_TIMEOUT 0.
    DECLARE @OwnDdlOriginalLockTimeout int=@@LOCK_TIMEOUT;
    BEGIN TRY
        SET LOCK_TIMEOUT 1000;
        CREATE TABLE [#InternalPrepareSingleResultTable_Map]
        (
              [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
            , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE
        );
    END TRY
    BEGIN CATCH
        DECLARE @OwnDdlRestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OwnDdlOriginalLockTimeout)+N';';
        EXEC [sys].[sp_executesql] @OwnDdlRestoreSql;
        THROW;
    END CATCH;

    SET LOCK_TIMEOUT 0;

    DECLARE @StatusCode varchar(40),@ErrorMessage nvarchar(2048);
    EXEC [monitor].[InternalPrepareResultTables]
          @ResultTablesJson=@ResultTablesJson
        , @AllowedResultNames=@ResultName
        , @MappingTable=N'#InternalPrepareSingleResultTable_Map'
        , @StatusCode=@StatusCode OUTPUT
        , @ErrorMessage=@ErrorMessage OUTPUT
        , @ThrowOnError=@ThrowOnError;

    IF @StatusCode='AVAILABLE'
        SELECT @TargetTable=[TargetTable]
        FROM [#InternalPrepareSingleResultTable_Map]
        WHERE [ResultName]=@ResultName COLLATE SQL_Latin1_General_CP1_CS_AS;
END;
GO

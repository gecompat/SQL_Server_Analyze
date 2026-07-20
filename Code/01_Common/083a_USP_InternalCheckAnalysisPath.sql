USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalCheckAnalysisPath
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Interne Stored Procedure
Zweck        : Prüft einen tatsächlich aktivierten Analysepfad auf bekannte
               Klasse, High-Impact-Bestätigung und aktuelle Freigabe, bevor
               fachliche DMV-, Cache-, Query-Store- oder Katalogzugriffe
               beginnen.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalCheckAnalysisPath]
      @AnalysisClass        varchar(64)
    , @HighImpactConfirmed  bit
    , @StatusCode           varchar(40)    OUTPUT
    , @ErrorMessage         nvarchar(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    SELECT @StatusCode='AVAILABLE',@ErrorMessage=NULL;

    IF NULLIF(@AnalysisClass,'') IS NULL
       OR @HighImpactConfirmed IS NULL
       OR @HighImpactConfirmed NOT IN (0,1)
    BEGIN
        SET @StatusCode='INVALID_PARAMETER';
        SET @ErrorMessage=N'Analyseklasse oder High-Impact-Bestätigung ist ungültig.';
        RETURN;
    END;

    DECLARE @RequiresHighImpact bit=0,@Allowed bit=0;
    SELECT
          @RequiresHighImpact=COALESCE(MAX(CONVERT(tinyint,[c].[RequiresGroupGate])),0)
        , @Allowed=COALESCE(MAX(CONVERT(tinyint,[a].[IsAllowed])),0)
    FROM [monitor].[VW_AnalyseClassCatalog] AS [c]
    LEFT JOIN [monitor].[VW_AnalyseAccessCurrent] AS [a]
      ON [a].[AnalysisClass]=[c].[AnalysisClass]
    WHERE [c].[AnalysisClass]=@AnalysisClass;

    IF NOT EXISTS
       (
           SELECT 1
           FROM [monitor].[VW_AnalyseClassCatalog]
           WHERE [AnalysisClass]=@AnalysisClass
       )
    BEGIN
        SET @StatusCode='INVALID_PARAMETER';
        SET @ErrorMessage=CONCAT(N'Unbekannte Analyseklasse: ',@AnalysisClass,N'.');
        RETURN;
    END;

    IF @RequiresHighImpact=1 AND @HighImpactConfirmed<>1
    BEGIN
        SET @StatusCode='HIGH_IMPACT_CONFIRMATION_REQUIRED';
        SET @ErrorMessage=CONCAT(N'Der aktivierte Analysepfad ',@AnalysisClass,N' erfordert @HighImpactConfirmed=1.');
        RETURN;
    END;

    IF @Allowed<>1
    BEGIN
        SET @StatusCode='DENIED_GROUP';
        SET @ErrorMessage=CONCAT(@AnalysisClass,N' ist nicht freigegeben.');
    END;
END;
GO

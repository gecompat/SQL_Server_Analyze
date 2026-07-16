USE [DeineDatenbank];
GO

-- Sichere Signatur-/Hilfeprüfung; keine ressourcenintensive Analyse.
EXEC [monitor].[USP_CurrentSessions] @Hilfe=1;
EXEC [monitor].[USP_CurrentRequests] @Hilfe=1;
EXEC [monitor].[USP_CurrentMemoryGrants] @Hilfe=1;
EXEC [monitor].[USP_CurrentOverview] @Hilfe=1;
GO

-- BEGIN STATEMENT-OFFSET-LAUFZEITTEST

-- Statement-Offset-Vertrag
DECLARE @OffsetTestStatement nvarchar(max);
SELECT @OffsetTestStatement=[StatementText]
FROM [monitor].[TVF_StatementText](N'SELECT 1; SELECT 2;',20,-1);
IF @OffsetTestStatement<>N'SELECT 2;'
    THROW 54110,N'Fehler im Statement-Offset-Vertrag.',1;

-- Eng begrenzter Laufzeittest auf der aktuellen Session
DECLARE @SelfSessionIds nvarchar(20)=CONVERT(nvarchar(20),@@SPID);
DECLARE @SelfJson nvarchar(max);
EXEC [monitor].[USP_CurrentRequests]
      @SessionIds=@SelfSessionIds
    , @AktuelleSessionEinbeziehen=1
    , @GesamtenSqlTextEinbeziehen=1
    , @InputBufferEinbeziehen=1
    , @MaxSqlTextZeichen=0
    , @MaxZeilen=1
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@SelfJson OUTPUT;
IF COALESCE(ISJSON(@SelfJson),0)<>1
    THROW 54111,N'USP_CurrentRequests JSON-Laufzeittest fehlgeschlagen.',1;
GO

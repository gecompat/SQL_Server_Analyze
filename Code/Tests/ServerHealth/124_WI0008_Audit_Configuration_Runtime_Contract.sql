USE [DeineDatenbank];
GO

/* Prueft die read-only Leerinventur fuer einen reservierten, nicht vorhandenen Auditnamen. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;
DECLARE @Status varchar(40) = NULL;

EXEC [monitor].[USP_AuditConfigurationAnalysis]
      @DatabaseNames = N'DeineDatenbank'
    , @AuditNames = N'ExampleWi0008AbsentAudit'
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0
    , @StatusCodeOut = @Status OUTPUT;

IF @Status <> 'AVAILABLE'
   OR COALESCE(ISJSON(@Json), 0) <> 1
   OR JSON_VALUE(@Json, '$.meta.statusCode') <> 'AVAILABLE'
   OR EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.audits'))
   OR EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.serverSpecifications'))
   OR EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.databaseSpecifications'))
   OR
      (
          SELECT COUNT_BIG(*)
          FROM OPENJSON(@Json, '$.sourceStatus')
          WITH
          (
                [SourceName] nvarchar(160) '$.SourceName'
              , [StatusCode] varchar(40) '$.StatusCode'
              , [IsPartial] bit '$.IsPartial'
          ) AS [s]
          WHERE [s].[StatusCode] = 'AVAILABLE'
            AND [s].[IsPartial] = 0
      ) <> 3
    THROW 54910, N'Der WI-0008-Leerinventarvertrag fuer Auditkonfigurationen ist verletzt.', 1;

DECLARE @RestrictedJson nvarchar(max) = NULL;
DECLARE @RestrictedStatus varchar(40) = NULL;

BEGIN TRY
    CREATE USER [ExampleWi0008RestrictedUser] WITHOUT LOGIN;
    GRANT EXECUTE ON [monitor].[USP_AuditConfigurationAnalysis] TO [ExampleWi0008RestrictedUser];
    EXECUTE AS USER = N'ExampleWi0008RestrictedUser';
    EXEC [monitor].[USP_AuditConfigurationAnalysis]
          @DatabaseNames = N'DeineDatenbank'
        , @AuditNames = N'ExampleWi0008AbsentAudit'
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @RestrictedJson OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @RestrictedStatus OUTPUT;
    REVERT;

    IF @RestrictedStatus <> 'AVAILABLE_LIMITED'
       OR COALESCE(ISJSON(@RestrictedJson), 0) <> 1
       OR JSON_VALUE(@RestrictedJson, '$.meta.statusCode') <> 'AVAILABLE_LIMITED'
       OR NOT EXISTS
          (
              SELECT 1
              FROM OPENJSON(@RestrictedJson, '$.sourceStatus')
              WITH
              (
                    [StatusCode] varchar(40) '$.StatusCode'
                  , [IsPartial] bit '$.IsPartial'
              ) AS [s]
              WHERE [s].[StatusCode] = 'DENIED_PERMISSION'
                AND [s].[IsPartial] = 1
          )
        THROW 54911, N'Der WI-0008-Vertrag fuer verweigerte Auditmetadaten ist verletzt.', 1;

    DROP USER [ExampleWi0008RestrictedUser];
END TRY
BEGIN CATCH
    IF USER_NAME() = N'ExampleWi0008RestrictedUser' REVERT;
    DROP USER IF EXISTS [ExampleWi0008RestrictedUser];
    THROW;
END CATCH;
GO

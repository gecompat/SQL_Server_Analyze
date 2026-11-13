USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 126_AgentProxyInventory_Runtime_Contract.sql
Zweck        : Prüft den lesenden Proxy-Katalogvertrag ohne Proxyfixture.
Grenze      : Eine leere Live-Instanz belegt keinen positiven Proxyfall.
Nebenwirkung : Keine Agent-, Credential- oder Berechtigungsänderung.
===============================================================================
*/
SET NOCOUNT ON;

DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit,
        @Error int, @Message nvarchar(2048);
DECLARE @Observed bigint, @Returned bigint, @Truncated bit, @RowCount bigint;
DECLARE @BeforeOptions int = @@OPTIONS, @BeforeTransactions int = @@TRANCOUNT,
        @BeforeLockTimeout int = @@LOCK_TIMEOUT;

EXEC [monitor].[USP_AgentProxyInventory]
     @MaxZeilen = 0, @ResultSetArt = 'NONE', @JsonErzeugen = 1,
     @Json = @Json OUTPUT, @StatusCodeOut = @Status OUTPUT,
     @IsPartialOut = @Partial OUTPUT, @ErrorNumberOut = @Error OUTPUT,
     @ErrorMessageOut = @Message OUTPUT;

IF COALESCE(ISJSON(@Json), 0) <> 1 OR @Status IS NULL
   OR COALESCE(@Status, '') <> COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), '')
   OR @Partial IS NULL
   OR @Partial <> CASE JSON_VALUE(@Json, '$.meta.isPartial') WHEN 'true' THEN 1 WHEN 'false' THEN 0 ELSE 2 END
   OR JSON_QUERY(@Json, '$.proxies') IS NULL
   OR JSON_QUERY(@Json, '$.proxySubsystems') IS NULL
   OR @@TRANCOUNT <> @BeforeTransactions OR @@OPTIONS <> @BeforeOptions
   OR @@LOCK_TIMEOUT <> @BeforeLockTimeout
    THROW 55260, N'Proxyinventur: JSON-, Status- oder Calleroptionenvertrag verletzt.', 1;

IF COALESCE(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
BEGIN
    IF COALESCE(@Status, '') <> 'DENIED_PERMISSION' OR COALESCE(@Partial, 2) <> 1
       OR COALESCE(JSON_VALUE(@Json, '$.meta.proxySourceStatus'), '') <> 'NOT_READ'
       OR JSON_VALUE(@Json, '$.meta.totalProxyCount') IS NOT NULL
       OR JSON_VALUE(@Json, '$.meta.returnedProxyCount') IS NOT NULL
        THROW 55261, N'Proxyinventur: fehlende sysadmin-Sicht nicht fail-closed.', 1;
END
ELSE
BEGIN
    IF COALESCE(@Status, '') <> 'AVAILABLE' OR COALESCE(@Partial, 2) <> 0 OR @Error IS NOT NULL
       OR COALESCE(JSON_VALUE(@Json, '$.meta.proxySourceStatus'), '') <> 'AVAILABLE'
       OR COALESCE(JSON_VALUE(@Json, '$.meta.credentialSourceStatus'), '') <> 'AVAILABLE'
       OR COALESCE(JSON_VALUE(@Json, '$.meta.subsystemSourceStatus'), '') <> 'AVAILABLE'
        THROW 55262, N'Proxyinventur: privilegierter Katalogzugriff unvollständig.', 1;

    SELECT @Observed = TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.totalProxyCount')),
           @Returned = TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.returnedProxyCount')),
           @Truncated = CASE JSON_VALUE(@Json, '$.meta.isTruncated') WHEN 'true' THEN 1 WHEN 'false' THEN 0 ELSE NULL END;
    SELECT @RowCount = COUNT_BIG(*) FROM OPENJSON(@Json, '$.proxies');
    IF @Observed IS NULL OR @Returned IS NULL OR @Truncated IS NULL
       OR @Observed <> @Returned OR @Returned <> @RowCount OR @Truncated <> 0
        THROW 55263, N'Proxyinventur: unbegrenzte Proxyzählung oder JSON-Menge falsch.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM OPENJSON(@Json, '$.proxies')
        WITH ([ProxyId] int '$.ProxyId',
              [CredentialId] int '$.CredentialId',
              [CredentialReferencePresent] bit '$.CredentialReferencePresent',
              [CredentialCatalogStatus] varchar(24) '$.CredentialCatalogStatus') AS [p]
        WHERE [p].[CredentialCatalogStatus] IS NULL
           OR [p].[CredentialCatalogStatus] NOT IN ('VISIBLE', 'NOT_VISIBLE_OR_MISSING')
           OR [p].[CredentialReferencePresent] IS NULL
           OR [p].[CredentialReferencePresent] <>
              CASE WHEN [p].[CredentialId] IS NULL THEN 0 ELSE 1 END
    )
        THROW 55264, N'Proxyinventur: Credentialreferenzvertrag verletzt.', 1;

    DECLARE @OneJson nvarchar(max), @OneStatus varchar(40);
    EXEC [monitor].[USP_AgentProxyInventory]
         @MaxZeilen = 1, @ResultSetArt = 'NONE', @JsonErzeugen = 1,
         @Json = @OneJson OUTPUT, @StatusCodeOut = @OneStatus OUTPUT;
    IF COALESCE(ISJSON(@OneJson), 0) <> 1
       OR COALESCE(@OneStatus, '') <> 'AVAILABLE'
       OR JSON_QUERY(@OneJson, '$.proxies') IS NULL
       OR JSON_QUERY(@OneJson, '$.proxySubsystems') IS NULL
       OR TRY_CONVERT(bigint, JSON_VALUE(@OneJson, '$.meta.returnedProxyCount')) IS NULL
       OR TRY_CONVERT(bigint, JSON_VALUE(@OneJson, '$.meta.returnedProxyCount')) <>
          CASE WHEN @Observed = 0 THEN 0 ELSE 1 END
       OR CASE JSON_VALUE(@OneJson, '$.meta.isTruncated') WHEN 'true' THEN 1 WHEN 'false' THEN 0 ELSE 2 END <>
          CASE WHEN @Observed > 1 THEN 1 ELSE 0 END
        THROW 55265, N'Proxyinventur: positives Proxyzeilenlimit falsch.', 1;

    CREATE TABLE #AgentProxyContractTarget ([Seed] int NULL);
    EXEC [monitor].[USP_AgentProxyInventory]
         @MaxZeilen = 0, @ResultSetArt = 'TABLE',
         @ResultTablesJson = N'{"proxies":"#AgentProxyContractTarget"}',
         @JsonErzeugen = 1, @Json = @Json OUTPUT,
         @StatusCodeOut = @Status OUTPUT;
    IF COALESCE(ISJSON(@Json), 0) <> 1
       OR COALESCE(@Status, '') <> 'AVAILABLE'
       OR JSON_QUERY(@Json, '$.proxies') IS NULL
       OR JSON_QUERY(@Json, '$.proxySubsystems') IS NULL
       OR TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.returnedProxyCount')) IS NULL
       OR (SELECT COUNT_BIG(*) FROM #AgentProxyContractTarget) <>
          TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.returnedProxyCount'))
        THROW 55266, N'Proxyinventur: TABLE-/JSON-Proxymenge falsch.', 1;
    DROP TABLE #AgentProxyContractTarget;
END;

EXEC [monitor].[USP_AgentProxyInventory]
     @MaxZeilen = -1, @ResultSetArt = 'NONE', @JsonErzeugen = 1,
     @Json = @Json OUTPUT, @StatusCodeOut = @Status OUTPUT,
     @IsPartialOut = @Partial OUTPUT;
IF COALESCE(ISJSON(@Json), 0) <> 1
   OR COALESCE(@Status, '') <> 'INVALID_PARAMETER' OR COALESCE(@Partial, 2) <> 1
   OR COALESCE(JSON_VALUE(@Json, '$.meta.proxySourceStatus'), '') <> 'NOT_READ'
    THROW 55267, N'Proxyinventur: negativer Grenzwert wurde nicht vor Quellenzugriff abgewiesen.', 1;

EXEC [monitor].[USP_AgentProxyInventory]
     @ResultSetArt = NULL, @JsonErzeugen = 1,
     @Json = @Json OUTPUT, @StatusCodeOut = @Status OUTPUT;
IF COALESCE(ISJSON(@Json), 0) <> 1
   OR COALESCE(@Status, '') <> 'INVALID_PARAMETER'
   OR COALESCE(JSON_VALUE(@Json, '$.meta.proxySourceStatus'), '') <> 'NOT_READ'
    THROW 55268, N'Proxyinventur: NULL-Ausgabemodus wurde nicht abgewiesen.', 1;

EXEC [sys].[sp_executesql] N'
    SET LOCK_TIMEOUT 137;
    SET XACT_ABORT ON;
    BEGIN TRAN;
    DECLARE @BeforeCount int = @@TRANCOUNT;
    DECLARE @Discard nvarchar(max), @Code varchar(40);
    EXEC [monitor].[USP_AgentProxyInventory]
         @ResultSetArt = ''NONE'', @JsonErzeugen = 1,
         @Json = @Discard OUTPUT, @StatusCodeOut = @Code OUTPUT;
    IF @@LOCK_TIMEOUT <> 137 OR (@@OPTIONS & 16384) <> 16384
       OR @@TRANCOUNT <> @BeforeCount OR XACT_STATE() <> 1
       OR COALESCE(ISJSON(@Discard), 0) <> 1
       OR COALESCE(@Code, '''') NOT IN (''AVAILABLE'', ''DENIED_PERMISSION'')
       OR COALESCE(JSON_VALUE(@Discard, ''$.meta.statusCode''), '''') <> COALESCE(@Code, '''')
       OR JSON_QUERY(@Discard, ''$.proxies'') IS NULL
       OR JSON_QUERY(@Discard, ''$.proxySubsystems'') IS NULL
    BEGIN
        ROLLBACK;
        THROW 55269, N''Proxyinventur: Caller-Transaktion oder Optionen verletzt.'', 1;
    END;
    ROLLBACK;';

/* Eigener WITHOUT LOGIN-User lebt ausschließlich im Rollback der Wegwerf-Testdatenbank. */
IF @BeforeTransactions <> 0
    THROW 55271, N'Proxyinventur: eingeschränkte Fixture benötigt eigenen Transaktionsscope.', 1;
IF EXISTS
(
    SELECT 1 FROM [sys].[database_principals] WITH (NOLOCK)
    WHERE [name] = N'AgentProxyInventoryContractUser_126'
)
    THROW 55272, N'Proxyinventur: synthetischer Fixturebenutzer kollidiert.', 1;

DECLARE @BeforeUser sysname = USER_NAME(), @Impersonated bit = 0;
BEGIN TRY
    BEGIN TRAN;
    CREATE USER [AgentProxyInventoryContractUser_126] WITHOUT LOGIN;
    GRANT EXECUTE ON OBJECT::[monitor].[USP_AgentProxyInventory]
        TO [AgentProxyInventoryContractUser_126];
    EXECUTE AS USER = 'AgentProxyInventoryContractUser_126';
    SET @Impersonated = 1;
    SET @Json = NULL;
    SET @Status = NULL;
    SET @Partial = NULL;
    EXEC [monitor].[USP_AgentProxyInventory]
         @ResultSetArt = 'NONE', @JsonErzeugen = 1,
         @Json = @Json OUTPUT, @StatusCodeOut = @Status OUTPUT,
         @IsPartialOut = @Partial OUTPUT;
    IF COALESCE(@Status, '') <> 'DENIED_PERMISSION' OR COALESCE(@Partial, 2) <> 1
       OR COALESCE(ISJSON(@Json), 0) <> 1
       OR COALESCE(JSON_VALUE(@Json, '$.meta.proxySourceStatus'), '') <> 'NOT_READ'
       OR COALESCE(JSON_VALUE(@Json, '$.meta.credentialSourceStatus'), '') <> 'NOT_READ'
       OR COALESCE(JSON_VALUE(@Json, '$.meta.subsystemSourceStatus'), '') <> 'NOT_READ'
       OR JSON_QUERY(@Json, '$.proxies') IS NULL
       OR JSON_QUERY(@Json, '$.proxySubsystems') IS NULL
       OR JSON_VALUE(@Json, '$.meta.totalProxyCount') IS NOT NULL
       OR JSON_VALUE(@Json, '$.meta.returnedProxyCount') IS NOT NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.proxies')) <> 0
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.proxySubsystems')) <> 0
        THROW 55273, N'Proxyinventur: eigener Testbenutzer sah keinen fail-closed Status.', 1;
    REVERT;
    SET @Impersonated = 0;
    IF USER_NAME() <> @BeforeUser OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
       OR @@OPTIONS <> @BeforeOptions OR @@LOCK_TIMEOUT <> @BeforeLockTimeout
        THROW 55274, N'Proxyinventur: Fixture-Callerzustand vor Rollback verletzt.', 1;
    ROLLBACK;
END TRY
BEGIN CATCH
    IF @Impersonated = 1
    BEGIN
        REVERT;
        SET @Impersonated = 0;
    END;
    IF @@TRANCOUNT > @BeforeTransactions ROLLBACK;
    THROW;
END CATCH;

IF USER_NAME() <> @BeforeUser OR @@TRANCOUNT <> @BeforeTransactions
   OR @@OPTIONS <> @BeforeOptions OR @@LOCK_TIMEOUT <> @BeforeLockTimeout
   OR EXISTS
      (
          SELECT 1 FROM [sys].[database_principals] WITH (NOLOCK)
          WHERE [name] = N'AgentProxyInventoryContractUser_126'
      )
    THROW 55275, N'Proxyinventur: Fixture-Rollback oder Callerzustand verletzt.', 1;

IF @@TRANCOUNT <> @BeforeTransactions OR @@OPTIONS <> @BeforeOptions
    THROW 55270, N'Proxyinventur: Testcallerzustand nicht wiederhergestellt.', 1;

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],
       CAST(0 AS bit) AS [IsPartial],
       N'Lesender Proxy-Katalogvertrag ohne Agent- oder Credentialänderung geprüft.' AS [Detail];
GO

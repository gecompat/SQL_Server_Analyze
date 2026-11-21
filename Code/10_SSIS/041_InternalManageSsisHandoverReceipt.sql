USE [DeineDatenbank];
GO

-- USAGE_SKILL_BEGIN monitor.InternalManageSsisHandoverReceipt 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalManageSsisHandoverReceipt"
-- schema_name: "monitor"
-- object_name: "InternalManageSsisHandoverReceipt"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "framework"
-- is_internal: true
-- description: "Registriert oder widerruft einen qualifizierten lokalen SSIS-Übergabebeleg."
-- source_path: "Code/10_SSIS/041_InternalManageSsisHandoverReceipt.sql"
-- ---
-- 
-- # monitor.InternalManageSsisHandoverReceipt
-- 
-- ## Zweck und Einsatz
-- 
-- Registriert oder widerruft einen qualifizierten lokalen SSIS-Übergabebeleg.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Autorisierte Aussteller benötigen `EXECUTE` auf dieser Prozedur und `ALTER` auf `monitor.USP_SsisPackageModelAnalysis`. Die Prüfung verwendet die Rechte des Aufrufers. Der gemeinsame Eigentümer erlaubt den statischen Tabellenzugriff der Prozedur. Eine aktive Aufrufertransaktion oder `IMPLICIT_TRANSACTIONS ON` verhindert die Ausführung.
-- 
-- ## Parameter und Eingabe
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @Action | varchar(64) | nein | NULL |
-- | @HandoverId | uniqueidentifier | nein | NULL |
-- | @RuntimeHandoverId | uniqueidentifier | nein | NULL |
-- | @ReceiptKind | tinyint | nein | NULL |
-- | @ModelJson | nvarchar(max) | nein | NULL |
-- | @PackageBytes | varbinary(max) | nein | NULL |
-- | @CaptureJson | nvarchar(max) | nein | NULL |
-- | @ValidHours | int | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@Action:** `varchar(64)`, Default NULL. `REGISTER_MODEL` registriert einen Modellbeleg mit optionalem Laufzeitbeleg. `REGISTER_SCOPE` registriert einen Scopebeleg. `REVOKE` widerruft einen Beleg der ausdrücklich gewählten Belegart. Der Vergleich folgt der Datenbankkollation. NULL und Leertext sind im Fachpfad ungültig.
-- 
-- **@HandoverId:** `uniqueidentifier`, Default NULL. Jede Aktion benötigt eine UUID. Bei `REGISTER_MODEL` bezeichnet sie den Modellbeleg, bei `REGISTER_SCOPE` den Scopebeleg und bei `REVOKE` zusammen mit `@ReceiptKind` den zu widerrufenden Beleg. Zulässig ist ein typisierter Wert oder ein konvertierbares GUID-Literal. NULL ist ungültig.
-- 
-- **@RuntimeHandoverId:** `uniqueidentifier`, Default NULL. `REGISTER_MODEL` benötigt eine typisierte UUID oder ein konvertierbares GUID-Literal, wenn `@CaptureJson` eine Laufzeitaufnahme enthält. Ohne Laufzeitaufnahme und bei den übrigen Aktionen ist NULL erforderlich.
-- 
-- **@ReceiptKind:** `tinyint`, Default NULL. `REVOKE` akzeptiert 1 für Modell, 2 für Laufzeit und 3 für Scope. NULL und andere Werte sind beim Widerruf ungültig. Beide Registrierungsaktionen verlangen NULL.
-- 
-- **@ModelJson:** `nvarchar(max)`, Default NULL. Bei `REGISTER_MODEL` muss der Unicode-Text ein qualifiziertes neutrales SSIS-Paketmodell enthalten. Die öffentliche Analyseprozedur validiert das Modell und die Originalbytes vor der Registrierung. Bei `REGISTER_SCOPE` muss der Wert ein gültiger JSON-Paketsatz mit höchstens 16 MiB nach `DATALENGTH` sein. Ein fehlender oder leerer Text ist bei Registrierung ungültig. `REVOKE` verlangt NULL.
-- 
-- **@PackageBytes:** `varbinary(max)`, Default NULL. `REGISTER_MODEL` benötigt die unveränderten Originalbytes des Pakets. Die Analyse prüft Länge und Paketdigest gegen das Modell. Fehlende oder abweichende Bytes führen zur Ablehnung. `REGISTER_SCOPE` und `REVOKE` verlangen NULL.
-- 
-- **@CaptureJson:** `nvarchar(max)`, Default NULL. Bei `REGISTER_SCOPE` ist die qualifizierte Scopeaufnahme als Unicode-JSON erforderlich. Bei `REGISTER_MODEL` ist mit `@RuntimeHandoverId` die zugehörige Laufzeitaufnahme erforderlich. Gültiger JSON-Text darf höchstens 16 MiB nach `DATALENGTH` umfassen. Leerer Text ist ungültig. Ohne Laufzeitbeleg und beim Widerruf ist NULL erforderlich.
-- 
-- **@ValidHours:** `int`, Default 1. Registrierungen akzeptieren ganze Stunden von 1 bis 24 einschließlich. Die Laufzeit beginnt am UTC-Zeitstempel der Ausstellung. NULL und Werte außerhalb des Bereichs sind bei Registrierung ungültig. Beim Widerruf wird der Wert nicht ausgewertet.
-- 
-- **@Hilfe:** `bit`, Default 0. 1 liefert den Usage Skill vor Fachzugriff, Autorisierungsprüfung und Eingabekontrolle. 0 oder NULL aktiviert den Fachpfad. SQL konvertiert numerische Werte ungleich 0 zu 1.
-- 
-- ## Resultate und Ausgabe
-- 
-- Der Fachpfad erzeugt kein Resultset. Ein Modell- und ein optionaler Laufzeitbeleg werden atomar registriert. Ein Widerruf löscht die angegebene UUID der angegebenen Belegart, sofern sie vorhanden ist.
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Die Prozedur setzt im Fachpfad `ROWCOUNT 0` und `LOCK_TIMEOUT 0` im lokalen Prozedurkontext. Die Registrierung eines Modells prüft Struktur und Originalbytes. Bei einer Scopeaufnahme prüft der qualifizierte Erfassungsworkflow die Einzelmodelle vor dem Aufruf. Er speichert die Aufnahme und den Paketsatz nicht in der Belegtabelle. Eine Belegkollision bricht die Registrierung ab.
-- USAGE_SKILL_END monitor.InternalManageSsisHandoverReceipt

CREATE OR ALTER PROCEDURE [monitor].[InternalManageSsisHandoverReceipt]
      @Action varchar(64) = NULL
    , @HandoverId uniqueidentifier = NULL
    , @RuntimeHandoverId uniqueidentifier = NULL
    , @ReceiptKind tinyint = NULL
    , @ModelJson nvarchar(max) = NULL
    , @PackageBytes varbinary(max) = NULL
    , @CaptureJson nvarchar(max) = NULL
    , @ValidHours int = 1
    , @Hilfe bit = 0
AS
BEGIN
    IF @Hilfe = 1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN monitor.InternalManageSsisHandoverReceipt
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'InternalManageSsisHandoverReceipt') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.InternalManageSsisHandoverReceipt"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "InternalManageSsisHandoverReceipt"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Registriert oder widerruft einen qualifizierten lokalen SSIS-Übergabebeleg."'
            + NCHAR(10)
            + N'source_path: "Code/10_SSIS/041_InternalManageSsisHandoverReceipt.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.InternalManageSsisHandoverReceipt'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Registriert oder widerruft einen qualifizierten lokalen SSIS-Übergabebeleg.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Autorisierte Aussteller benötigen `EXECUTE` auf dieser Prozedur und `ALTER` auf `monitor.USP_SsisPackageModelAnalysis`. Die Prüfung verwendet die Rechte des Aufrufers. Der gemeinsame Eigentümer erlaubt den statischen Tabellenzugriff der Prozedur. Eine aktive Aufrufertransaktion oder `IMPLICIT_TRANSACTIONS ON` verhindert die Ausführung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @Action | varchar(64) | nein | NULL |'
            + NCHAR(10)
            + N'| @HandoverId | uniqueidentifier | nein | NULL |'
            + NCHAR(10)
            + N'| @RuntimeHandoverId | uniqueidentifier | nein | NULL |'
            + NCHAR(10)
            + N'| @ReceiptKind | tinyint | nein | NULL |'
            + NCHAR(10)
            + N'| @ModelJson | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @PackageBytes | varbinary(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @CaptureJson | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @ValidHours | int | nein | 1 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Action:** `varchar(64)`, Default NULL. `REGISTER_MODEL` registriert einen Modellbeleg mit optionalem Laufzeitbeleg. `REGISTER_SCOPE` registriert einen Scopebeleg. `REVOKE` widerruft einen Beleg der ausdrücklich gewählten Belegart. Der Vergleich folgt der Datenbankkollation. NULL und Leertext sind im Fachpfad ungültig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@HandoverId:** `uniqueidentifier`, Default NULL. Jede Aktion benötigt eine UUID. Bei `REGISTER_MODEL` bezeichnet sie den Modellbeleg, bei `REGISTER_SCOPE` den Scopebeleg und bei `REVOKE` zusammen mit `@ReceiptKind` den zu widerrufenden Beleg. Zulässig ist ein typisierter Wert oder ein konvertierbares GUID-Literal. NULL ist ungültig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@RuntimeHandoverId:** `uniqueidentifier`, Default NULL. `REGISTER_MODEL` benötigt eine typisierte UUID oder ein konvertierbares GUID-Literal, wenn `@CaptureJson` eine Laufzeitaufnahme enthält. Ohne Laufzeitaufnahme und bei den übrigen Aktionen ist NULL erforderlich.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ReceiptKind:** `tinyint`, Default NULL. `REVOKE` akzeptiert 1 für Modell, 2 für Laufzeit und 3 für Scope. NULL und andere Werte sind beim Widerruf ungültig. Beide Registrierungsaktionen verlangen NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ModelJson:** `nvarchar(max)`, Default NULL. Bei `REGISTER_MODEL` muss der Unicode-Text ein qualifiziertes neutrales SSIS-Paketmodell enthalten. Die öffentliche Analyseprozedur validiert das Modell und die Originalbytes vor der Registrierung. Bei `REGISTER_SCOPE` muss der Wert ein gültiger JSON-Paketsatz mit höchstens 16 MiB nach `DATALENGTH` sein. Ein fehlender oder leerer Text ist bei Registrierung ungültig. `REVOKE` verlangt NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PackageBytes:** `varbinary(max)`, Default NULL. `REGISTER_MODEL` benötigt die unveränderten Originalbytes des Pakets. Die Analyse prüft Länge und Paketdigest gegen das Modell. Fehlende oder abweichende Bytes führen zur Ablehnung. `REGISTER_SCOPE` und `REVOKE` verlangen NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureJson:** `nvarchar(max)`, Default NULL. Bei `REGISTER_SCOPE` ist die qualifizierte Scopeaufnahme als Unicode-JSON erforderlich. Bei `REGISTER_MODEL` ist mit `@RuntimeHandoverId` die zugehörige Laufzeitaufnahme erforderlich. Gültiger JSON-Text darf höchstens 16 MiB nach `DATALENGTH` umfassen. Leerer Text ist ungültig. Ohne Laufzeitbeleg und beim Widerruf ist NULL erforderlich.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ValidHours:** `int`, Default 1. Registrierungen akzeptieren ganze Stunden von 1 bis 24 einschließlich. Die Laufzeit beginnt am UTC-Zeitstempel der Ausstellung. NULL und Werte außerhalb des Bereichs sind bei Registrierung ungültig. Beim Widerruf wird der Wert nicht ausgewertet.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** `bit`, Default 0. 1 liefert den Usage Skill vor Fachzugriff, Autorisierungsprüfung und Eingabekontrolle. 0 oder NULL aktiviert den Fachpfad. SQL konvertiert numerische Werte ungleich 0 zu 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der Fachpfad erzeugt kein Resultset. Ein Modell- und ein optionaler Laufzeitbeleg werden atomar registriert. Ein Widerruf löscht die angegebene UUID der angegebenen Belegart, sofern sie vorhanden ist.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Prozedur setzt im Fachpfad `ROWCOUNT 0` und `LOCK_TIMEOUT 0` im lokalen Prozedurkontext. Die Registrierung eines Modells prüft Struktur und Originalbytes. Bei einer Scopeaufnahme prüft der qualifizierte Erfassungsworkflow die Einzelmodelle vor dem Aufruf. Er speichert die Aufnahme und den Paketsatz nicht in der Belegtabelle. Eine Belegkollision bricht die Registrierung ab.'
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.InternalManageSsisHandoverReceipt
        RETURN;
    END;

    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET ROWCOUNT 0;
    IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2) <> 0
    BEGIN
        SET XACT_ABORT OFF;
        RAISERROR(N'SSIS_HANDOVER_CALLER_TRANSACTION_NOT_ALLOWED',16,1);
        RETURN;
    END;
    IF ISNULL(HAS_PERMS_BY_NAME(N'monitor.USP_SsisPackageModelAnalysis', N'OBJECT', N'ALTER'), 0) <> 1
    BEGIN
        IF @Action = 'REGISTER_SCOPE' THROW 57410, N'SSIS_SCOPE_REGISTRATION_AUTHORITY_REQUIRED', 1;
        THROW 57400, N'SSIS_HANDOVER_ALTER_AUTHORITY_REQUIRED', 1;
    END;
    IF @HandoverId IS NULL THROW 57400, N'SSIS_HANDOVER_ID_REQUIRED', 1;
    IF @Action = 'REVOKE'
    BEGIN
        IF @ReceiptKind IS NULL OR @ReceiptKind NOT IN (1, 2, 3)
            OR @RuntimeHandoverId IS NOT NULL OR @ModelJson IS NOT NULL OR @PackageBytes IS NOT NULL OR @CaptureJson IS NOT NULL
            THROW 57400, N'SSIS_HANDOVER_REVOKE_INVALID', 1;
        DELETE FROM [monitor].[SsisHandoverReceipt]
        WHERE [ReceiptKind] = @ReceiptKind AND [HandoverId] = @HandoverId;
        RETURN;
    END;

    IF @ValidHours IS NULL OR @ValidHours NOT BETWEEN 1 AND 24 OR @ReceiptKind IS NOT NULL
        THROW 57400, N'SSIS_HANDOVER_REGISTRATION_INVALID', 1;

    DECLARE @Issued datetime2(3), @Receipt nvarchar(3000), @RuntimeReceipt nvarchar(3000);
    IF @Action = 'REGISTER_MODEL'
    BEGIN
        IF @ModelJson IS NULL OR @PackageBytes IS NULL THROW 57400, N'SSIS_HANDOVER_MODEL_REJECTED', 1;
        IF (@CaptureJson IS NULL AND @RuntimeHandoverId IS NOT NULL)
            OR (@CaptureJson IS NOT NULL AND (@RuntimeHandoverId IS NULL OR ISJSON(@CaptureJson) <> 1 OR DATALENGTH(@CaptureJson) > 16777216))
            THROW 57400, N'SSIS_HANDOVER_SNAPSHOT_REJECTED', 1;

        DECLARE @Status varchar(40);
        EXEC [monitor].[USP_SsisPackageModelAnalysis]
             @PackageModelJson = @ModelJson, @PackageBytes = @PackageBytes, @ResultSetArt = 'NONE', @StatusCodeOut = @Status OUTPUT;
        IF ISNULL(@Status, '') <> 'AVAILABLE_LIMITED' THROW 57400, N'SSIS_HANDOVER_MODEL_REJECTED', 1;

        SET @Issued = SYSUTCDATETIME();
        SET @Receipt = (SELECT 'ssis-local-handover' AS [contract], '1.0.0' AS [version], 'QUALIFIED_HOST_SNAPSHOT' AS [method],
            CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @ModelJson)), 2) AS [modelSha256],
            JSON_VALUE(@ModelJson, '$.source.packageSha256') AS [packageSha256], DATALENGTH(@PackageBytes) AS [byteLength],
            JSON_VALUE(@ModelJson, '$.producer.buildSha256') AS [buildSha256], JSON_VALUE(@ModelJson, '$.producer.sourceCommit') AS [sourceCommit],
            CONVERT(varchar(24), @Issued, 127) + 'Z' AS [issuedUtc], CONVERT(varchar(24), DATEADD(hour, @ValidHours, @Issued), 127) + 'Z' AS [expiresUtc]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        IF @RuntimeHandoverId IS NOT NULL
            SET @RuntimeReceipt = (SELECT 'ssis-local-runtime-handover' AS [contract], '1.0.0' AS [version],
                CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @CaptureJson)), 2) AS [snapshotSha256],
                CONVERT(varchar(24), @Issued, 127) + 'Z' AS [issuedUtc], CONVERT(varchar(24), DATEADD(hour, @ValidHours, @Issued), 127) + 'Z' AS [expiresUtc]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        INSERT [monitor].[SsisHandoverReceipt] ([ReceiptKind], [HandoverId], [ReceiptJson])
        SELECT [ReceiptKind], [HandoverId], [ReceiptJson]
        FROM (VALUES (1, @HandoverId, @Receipt), (2, @RuntimeHandoverId, @RuntimeReceipt))
            AS [issued] ([ReceiptKind], [HandoverId], [ReceiptJson])
        WHERE [HandoverId] IS NOT NULL;
        RETURN;
    END;

    IF @Action = 'REGISTER_SCOPE'
    BEGIN
        IF @PackageBytes IS NOT NULL OR @RuntimeHandoverId IS NOT NULL
            OR ISNULL(ISJSON(@ModelJson), 0) <> 1 OR DATALENGTH(@ModelJson) > 16777216
            OR ISNULL(ISJSON(@CaptureJson), 0) <> 1 OR DATALENGTH(@CaptureJson) > 16777216
            THROW 57410, N'SSIS_SCOPE_REGISTRATION_INVALID', 1;
        SET @Issued = SYSUTCDATETIME();
        SET @Receipt = (SELECT 'ssis-local-scope-handover' AS [contract], '1.0.0' AS [version],
            CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @ModelJson)), 2) AS [modelSetSha256],
            CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @CaptureJson)), 2) AS [captureSha256],
            CONVERT(varchar(24), @Issued, 127) + 'Z' AS [issuedUtc], CONVERT(varchar(24), DATEADD(hour, @ValidHours, @Issued), 127) + 'Z' AS [expiresUtc]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        INSERT [monitor].[SsisHandoverReceipt] ([ReceiptKind], [HandoverId], [ReceiptJson])
        VALUES (3, @HandoverId, @Receipt);
        RETURN;
    END;
    THROW 57400, N'SSIS_HANDOVER_ACTION_INVALID', 1;
END;
GO

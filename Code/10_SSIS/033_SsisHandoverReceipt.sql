USE [DeineDatenbank];
GO

-- USAGE_SKILL_BEGIN monitor.SsisHandoverReceipt 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.SsisHandoverReceipt"
-- schema_name: "monitor"
-- object_name: "SsisHandoverReceipt"
-- object_type: "TABLE"
-- database_role: "framework"
-- is_internal: false
-- description: "Speichert die zeitlich begrenzten lokalen Belege für SSIS-Modelle und Laufzeitaufnahmen."
-- source_path: "Code/10_SSIS/033_SsisHandoverReceipt.sql"
-- ---
-- 
-- # monitor.SsisHandoverReceipt
-- 
-- ## Zweck und Einsatz
-- 
-- Speichert die zeitlich begrenzten lokalen Belege für SSIS-Modelle und Laufzeitaufnahmen.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Die Tabelle gehört über das Schema `monitor` zu `dbo`. Registrierung und Widerruf erfolgen über `monitor.InternalManageSsisHandoverReceipt`. Die Analyseprozeduren lesen die Belege mit statischem SQL. Der Installer verweigert `public` INSERT und DELETE auf der Tabelle und UPDATE auf jeder der drei Spalten. Die Sperren gelten auch für geerbte Schreibrechte und spaltenbezogene UPDATE-Grants. Erstellung und Schreibschutz erfolgen in derselben Transaktion. Bei erneuter Installation muss eine vorhandene Tabelle den Struktur- und Berechtigungsvertrag bereits erfüllen. Der Eigentümer und entsprechend privilegierte Administratoren verwalten die Schutzgrenze.
-- 
-- ## Parameter und Eingabe
-- 
-- Keine Aufrufparameter.
-- 
-- ## Resultate und Ausgabe
-- 
-- `ReceiptKind` ist ein `tinyint`. 1 bezeichnet einen Modellbeleg, 2 einen Laufzeitbeleg und 3 einen Scopebeleg. Gemeinsam mit der UUID `HandoverId` bildet die Belegart den Primärschlüssel. `ReceiptJson` ist ein JSON-Text in `nvarchar(3000)` mit Vertragsversion, Hashwerten, Ausstellungszeit und Ablaufzeit. Der Modellbeleg enthält auch Paketlänge, Erzeugungsmethode, Buildhash und Source-Commit.
-- 
-- ## Beispiel
-- 
-- Ein Administrator mit SELECT-Recht auf der Tabelle kann prüfen, ob ein Modellbeleg zur angegebenen UUID gespeichert ist. Die Abfrage gibt höchstens eine Zeile zurück. Ersetze die synthetische UUID durch die zu prüfende UUID. Eine gefundene Zeile belegt die Speicherung. Die fachliche Gültigkeit prüft die jeweilige Analyseprozedur anhand des Beleginhalts.
-- 
-- ```sql
-- DECLARE @HandoverId uniqueidentifier = '00000000-0000-4000-8000-000000000001';
-- 
-- SELECT [ReceiptKind], [HandoverId]
-- FROM [monitor].[SsisHandoverReceipt] WITH (READCOMMITTEDLOCK)
-- WHERE [ReceiptKind] = 1 AND [HandoverId] = @HandoverId;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Leser suchen einen Beleg je Art und UUID mit `READCOMMITTEDLOCK`. Die Tabelle enthält keine Paketbytes, Modelle oder Laufzeitaufnahmen. Die Belegprüfung lehnt abgelaufene, widerrufene und unpassende IDs ab. Belegzeilen laufen fachlich ab. Es gibt keine automatische Löschung.
-- USAGE_SKILL_END monitor.SsisHandoverReceipt

IF (@@OPTIONS & 2) <> 0 THROW 57400, N'SSIS_HANDOVER_RECEIPT_IMPLICIT_TRANSACTION', 1;

DECLARE @ReceiptSchemaOwner int, @ReceiptObjectId int, @ReceiptObjectType char(2), @ReceiptObjectOwner int;
SELECT @ReceiptSchemaOwner = [s].[principal_id], @ReceiptObjectId = [o].[object_id], @ReceiptObjectType = [o].[type],
       @ReceiptObjectOwner = COALESCE([o].[principal_id], [s].[principal_id])
FROM sys.schemas AS [s] WITH (NOLOCK)
LEFT JOIN sys.objects AS [o] WITH (NOLOCK)
    ON [o].[schema_id] = [s].[schema_id] AND [o].[name] = N'SsisHandoverReceipt'
WHERE [s].[name] = N'monitor';

IF ISNULL(@ReceiptSchemaOwner, -1) <> DATABASE_PRINCIPAL_ID(N'dbo')
    OR (@ReceiptObjectType IS NOT NULL AND (@ReceiptObjectType <> 'U' OR @ReceiptObjectOwner <> DATABASE_PRINCIPAL_ID(N'dbo')))
    THROW 57400, N'SSIS_HANDOVER_RECEIPT_OBJECT_MISMATCH', 1;

IF @ReceiptObjectType IS NULL
BEGIN
    DECLARE @ReceiptOwnTransaction bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @ReceiptRestoreXactAbort bit = CASE WHEN @ReceiptOwnTransaction = 1 AND (@@OPTIONS & 16384) = 0 THEN 1 ELSE 0 END;
    IF @ReceiptOwnTransaction = 0 SAVE TRANSACTION SQLSA_SsisReceiptDdl;
    BEGIN TRY
        IF @ReceiptRestoreXactAbort = 1 SET XACT_ABORT ON;
        IF @ReceiptOwnTransaction = 1 BEGIN TRANSACTION;
        CREATE TABLE [monitor].[SsisHandoverReceipt]
        (
              [ReceiptKind] tinyint NOT NULL
            , [HandoverId] uniqueidentifier NOT NULL
            , [ReceiptJson] nvarchar(3000) NOT NULL
            , CONSTRAINT [PK_SsisHandoverReceipt] PRIMARY KEY CLUSTERED ([ReceiptKind], [HandoverId])
            , CONSTRAINT [CK_SsisHandoverReceipt_Kind] CHECK ([ReceiptKind] = 1 OR [ReceiptKind] = 2 OR [ReceiptKind] = 3)
            , CONSTRAINT [CK_SsisHandoverReceipt_Json] CHECK (ISJSON([ReceiptJson]) = 1)
        );
        EXEC(N'DENY INSERT, DELETE ON OBJECT::[monitor].[SsisHandoverReceipt] TO [public]; DENY UPDATE ([ReceiptKind], [HandoverId], [ReceiptJson]) ON OBJECT::[monitor].[SsisHandoverReceipt] TO [public];');
        IF @ReceiptOwnTransaction = 1 COMMIT TRANSACTION;
        IF @ReceiptRestoreXactAbort = 1 SET XACT_ABORT OFF;
    END TRY
    BEGIN CATCH
        IF @ReceiptOwnTransaction = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @ReceiptOwnTransaction = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION SQLSA_SsisReceiptDdl;
        IF @ReceiptRestoreXactAbort = 1 SET XACT_ABORT OFF;
        THROW;
    END CATCH;

END
ELSE
BEGIN
    IF (SELECT COUNT(*) FROM sys.columns AS [c] WITH (NOLOCK) WHERE [c].[object_id] = @ReceiptObjectId) <> 3
        OR
        (
            SELECT COUNT(*)
            FROM sys.columns AS [c] WITH (NOLOCK)
            WHERE [c].[object_id] = @ReceiptObjectId
                AND [c].[system_type_id] = [c].[user_type_id]
                AND [c].[is_nullable] = 0 AND [c].[is_identity] = 0 AND [c].[is_computed] = 0
                AND [c].[is_hidden] = 0 AND [c].[is_sparse] = 0 AND [c].[is_column_set] = 0
                AND [c].[generated_always_type] = 0 AND [c].[encryption_type] IS NULL
                AND [c].[default_object_id] = 0 AND [c].[rule_object_id] = 0
                AND
                (
                    ([c].[column_id] = 1 AND [c].[name] COLLATE Latin1_General_100_BIN2 = N'ReceiptKind' AND [c].[system_type_id] = 48 AND [c].[max_length] = 1)
                    OR ([c].[column_id] = 2 AND [c].[name] COLLATE Latin1_General_100_BIN2 = N'HandoverId' AND [c].[system_type_id] = 36 AND [c].[max_length] = 16)
                    OR ([c].[column_id] = 3 AND [c].[name] COLLATE Latin1_General_100_BIN2 = N'ReceiptJson' AND [c].[system_type_id] = 231 AND [c].[max_length] = 6000
                        AND [c].[collation_name] = CONVERT(sysname, SQL_VARIANT_PROPERTY(CONVERT(sql_variant, N''), 'Collation')))
                )
        ) <> 3
        THROW 57400, N'SSIS_HANDOVER_RECEIPT_COLUMN_MISMATCH', 1;

    IF (SELECT COUNT(*) FROM sys.indexes AS [i] WITH (NOLOCK) WHERE [i].[object_id] = @ReceiptObjectId) <> 1
        OR NOT EXISTS
        (
            SELECT 1
            FROM sys.indexes AS [i] WITH (NOLOCK)
            WHERE [i].[object_id] = @ReceiptObjectId AND [i].[index_id] = 1
                AND [i].[name] COLLATE Latin1_General_100_BIN2 = N'PK_SsisHandoverReceipt'
                AND [i].[type] = 1 AND [i].[is_primary_key] = 1 AND [i].[is_unique] = 1 AND [i].[ignore_dup_key] = 0
                AND [i].[is_disabled] = 0 AND [i].[is_hypothetical] = 0 AND [i].[has_filter] = 0
        )
        OR (SELECT COUNT(*) FROM sys.index_columns AS [ic] WITH (NOLOCK) WHERE [ic].[object_id] = @ReceiptObjectId AND [ic].[index_id] = 1) <> 2
        OR
        (
            SELECT COUNT(*) FROM sys.index_columns AS [ic] WITH (NOLOCK)
            WHERE [ic].[object_id] = @ReceiptObjectId AND [ic].[index_id] = 1 AND [ic].[is_descending_key] = 0
                AND [ic].[is_included_column] = 0 AND [ic].[partition_ordinal] = 0
                AND [ic].[key_ordinal] IN (1, 2) AND [ic].[column_id] = [ic].[key_ordinal]
        ) <> 2
        THROW 57400, N'SSIS_HANDOVER_RECEIPT_KEY_MISMATCH', 1;

    DECLARE @ReceiptReferenceId int, @ReceiptReferenceCount int;
    DECLARE @ReceiptKindDefinition nvarchar(max), @ReceiptJsonDefinition nvarchar(max);
    DECLARE @ReceiptKindColumnId int, @ReceiptJsonColumnId int;
    IF OBJECT_ID(N'tempdb..#SsisHandoverReceipt_CheckReference') IS NOT NULL
        THROW 57400, N'SSIS_HANDOVER_RECEIPT_REFERENCE_IN_USE', 1;

    BEGIN TRY
        CREATE TABLE #SsisHandoverReceipt_CheckReference
        (
              [ReceiptKind] tinyint NOT NULL
            , [HandoverId] uniqueidentifier NOT NULL
            , [ReceiptJson] nvarchar(3000) COLLATE DATABASE_DEFAULT NOT NULL
            , CHECK ([ReceiptKind] = 1 OR [ReceiptKind] = 2 OR [ReceiptKind] = 3)
            , CHECK (ISJSON([ReceiptJson]) = 1)
        );
        SET @ReceiptReferenceId = OBJECT_ID(N'tempdb..#SsisHandoverReceipt_CheckReference');
        SELECT @ReceiptReferenceCount = COUNT(*),
               @ReceiptKindDefinition = MAX(CASE WHEN [cc].[definition] COLLATE Latin1_General_100_BIN2
                   LIKE N'%ReceiptKind%' THEN [cc].[definition] END),
               @ReceiptJsonDefinition = MAX(CASE WHEN [cc].[definition] COLLATE Latin1_General_100_BIN2
                   LIKE N'%ReceiptJson%' THEN [cc].[definition] END),
               @ReceiptKindColumnId = MAX(CASE WHEN [cc].[definition] COLLATE Latin1_General_100_BIN2
                   LIKE N'%ReceiptKind%' THEN [cc].[parent_column_id] END),
               @ReceiptJsonColumnId = MAX(CASE WHEN [cc].[definition] COLLATE Latin1_General_100_BIN2
                   LIKE N'%ReceiptJson%' THEN [cc].[parent_column_id] END)
        FROM tempdb.sys.check_constraints AS [cc] WITH (NOLOCK)
        WHERE [cc].[parent_object_id] = @ReceiptReferenceId;
        DROP TABLE #SsisHandoverReceipt_CheckReference;
    END TRY
    BEGIN CATCH
        -- The caller's rollback removes the reference if its transaction is doomed.
        IF XACT_STATE() <> -1 AND OBJECT_ID(N'tempdb..#SsisHandoverReceipt_CheckReference') IS NOT NULL
            DROP TABLE #SsisHandoverReceipt_CheckReference;
        THROW;
    END CATCH;

    IF @ReceiptReferenceCount <> 2 OR @ReceiptKindDefinition IS NULL OR @ReceiptJsonDefinition IS NULL
        OR CONVERT(varbinary(max), @ReceiptKindDefinition) = CONVERT(varbinary(max), @ReceiptJsonDefinition)
        THROW 57400, N'SSIS_HANDOVER_RECEIPT_REFERENCE_UNAVAILABLE', 1;

    DECLARE @ReceiptCheckCount int, @ReceiptKindCheck int, @ReceiptJsonCheck int;
    DECLARE @ReceiptBindingMismatch int, @ReceiptStateMismatch int;
    SELECT @ReceiptCheckCount = COUNT(*),
           @ReceiptKindCheck = COALESCE(MAX(CASE WHEN [n].[Name] = N'CK_SsisHandoverReceipt_Kind'
               AND CONVERT(varbinary(max), [cc].[definition]) = CONVERT(varbinary(max), @ReceiptKindDefinition)
               THEN 1 ELSE 0 END), 0),
           @ReceiptJsonCheck = COALESCE(MAX(CASE WHEN [n].[Name] = N'CK_SsisHandoverReceipt_Json'
               AND CONVERT(varbinary(max), [cc].[definition]) = CONVERT(varbinary(max), @ReceiptJsonDefinition)
               THEN 1 ELSE 0 END), 0),
           @ReceiptBindingMismatch = COALESCE(MAX(CASE
               WHEN [n].[Name] = N'CK_SsisHandoverReceipt_Kind' AND [cc].[parent_column_id] <> @ReceiptKindColumnId THEN 1
               WHEN [n].[Name] = N'CK_SsisHandoverReceipt_Json' AND [cc].[parent_column_id] <> @ReceiptJsonColumnId THEN 1
               ELSE 0 END), 0),
           @ReceiptStateMismatch = COALESCE(MAX(CASE WHEN [cc].[is_disabled] <> 0 OR [cc].[is_not_trusted] <> 0
               OR [cc].[is_not_for_replication] <> 0 THEN 1 ELSE 0 END), 0)
    FROM sys.check_constraints AS [cc] WITH (NOLOCK)
    CROSS APPLY (VALUES ([cc].[name] COLLATE Latin1_General_100_BIN2)) AS [n]([Name])
    WHERE [cc].[parent_object_id] = @ReceiptObjectId;

    -- State bits: count (1), kind (2), JSON (4), trigger (8), foreign key (16), security predicate (32), binding (64), state (128).
    DECLARE @ReceiptConstraintFlags tinyint = CASE WHEN @ReceiptCheckCount = 2 THEN 0 ELSE 1 END
        + CASE WHEN @ReceiptKindCheck = 1 THEN 0 ELSE 2 END + CASE WHEN @ReceiptJsonCheck = 1 THEN 0 ELSE 4 END
        + 64 * @ReceiptBindingMismatch + 128 * @ReceiptStateMismatch;
    IF EXISTS (SELECT 1 FROM sys.triggers AS [t] WITH (NOLOCK) WHERE [t].[parent_id] = @ReceiptObjectId)
        SET @ReceiptConstraintFlags += 8;
    IF EXISTS (SELECT 1 FROM sys.foreign_keys AS [fk] WITH (NOLOCK) WHERE [fk].[parent_object_id] = @ReceiptObjectId OR [fk].[referenced_object_id] = @ReceiptObjectId)
        SET @ReceiptConstraintFlags += 16;
    IF EXISTS (SELECT 1 FROM sys.security_predicates AS [sp] WITH (NOLOCK) WHERE [sp].[target_object_id] = @ReceiptObjectId)
        SET @ReceiptConstraintFlags += 32;
    IF @ReceiptConstraintFlags <> 0
        THROW 57400, N'SSIS_HANDOVER_RECEIPT_CONSTRAINT_MISMATCH', @ReceiptConstraintFlags;
    IF
    (
        SELECT COUNT(DISTINCT CONCAT([dp].[permission_name], N':', [dp].[minor_id]))
        FROM sys.database_permissions AS [dp] WITH (READCOMMITTEDLOCK)
        WHERE [dp].[class] = 1 AND [dp].[major_id] = @ReceiptObjectId
            AND [dp].[grantee_principal_id] = DATABASE_PRINCIPAL_ID(N'public')
            AND [dp].[state] = 'D'
            AND
            (
                ([dp].[minor_id] = 0 AND [dp].[permission_name] IN (N'INSERT', N'DELETE'))
                OR ([dp].[minor_id] IN (1, 2, 3) AND [dp].[permission_name] = N'UPDATE')
            )
    ) <> 5
        THROW 57400, N'SSIS_HANDOVER_RECEIPT_PERMISSIONS_MISMATCH', 1;
END;
GO

USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_EndpointTransportAnalysis
Version      : 1.0.0
Stand        : 2026-10-25
Zweck        : Die Procedure zeigt sichtbare Engineendpoints, TCP-/Mirroringkonfiguration
               und gruppierte native Verschlüsselungsflags bestehender Verbindungen.
Quellen      : sys.endpoints, sys.tcp_endpoints, sys.database_mirroring_endpoints
               und sys.dm_exec_connections.
Grenzen      : Kein TLS-, Cipher-, Zertifikatsvertrauens- oder Erreichbarkeitsbeweis.
               HADR-Flags und MARS-Zeilen besitzen eigene Aussagegrenzen.
Nebenwirkung : Liest Enginemetadaten und DMV-Zeilen; verändert keine Endpoints,
               Rechte oder Hostwerte.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_EndpointTransportAnalysis]
      @MaxZeilen int = 1000
    , @LockTimeoutMs int = 0
    , @ResultSetArt varchar(16) = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen bit = 0
    , @Json nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen bit = 1
    , @Hilfe bit = 0
    , @StatusCodeOut varchar(40) = NULL OUTPUT
    , @IsPartialOut bit = NULL OUTPUT
    , @ErrorNumberOut int = NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),
        @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
        @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END,
        @PreviousLockTimeout int=@@LOCK_TIMEOUT,
        @PreviousXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
        @RestoreLock nvarchar(100),@SetLock nvarchar(100),@Batch nvarchar(max),@Started datetime2(3),@Observed bigint,
        @Status varchar(40)='AVAILABLE_LIMITED',@Error int=NULL,@Message nvarchar(2048)=NULL,
        @TableStatus varchar(40),@TableMessage nvarchar(2048),@TableError int,@TableFailureError int=NULL;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_EndpointTransportAnalysis';
        PRINT N'Zeigt SQL-sichtbare Endpointkonfiguration und gruppierte native Verbindungsflags; keine TLS-, Zertifikatsvertrauens- oder externe Erreichbarkeitsprüfung.';
        PRINT N'Kataloge und Verbindungen werden getrennt erfasst; die sichtbaren Momentaufnahmen sind nicht atomar und nicht zwingend vollständig.';
        PRINT N'CONSOLE, RAW, TABLE und NONE steuern die Ausgabe; @MaxZeilen begrenzt vier Fachmengen getrennt, 0 und NULL bedeuten unbegrenzt.';
        PRINT N'@LockTimeoutMs muss 0 bis 60000 sein; ConnectionRows zählt DMV-Zeilen einschließlich möglicher MARS-Zeilen.';
        PRINT N'Fachliche Quellenfehler stehen in Status und sourceStatus; ungültige Parameter und TABLE-Vorprüfungsfehler liefern RETURN 51011 und JSON-NULL. HADR encrypt_option=FALSE ist kein Negativbeweis.';
        PRINT N'@MaxZeilen int; Default: 1000. Ganze Zahl als Zeilenlimit je Fachmenge: endpoints, tcpEndpoints, mirroringEndpoints und connectionEncryptionSummary werden unabhängig begrenzt. Positiv begrenzt; NULL oder 0 bedeutet unbegrenzt, negativ ist ungültig. Vollständige Aufnahme und Gruppierung erfolgen davor; sourceStatus.IsLimited zeigt Kürzung. moduleStatus.RowCount summiert ausgegebene Fachzeilen; moduleStatus, sourceStatus und warnings bleiben ungekürzt. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@LockTimeoutMs int; Default: 0. Timeout in ms je Quellenbatch: 0–60000; 0 wartet nicht, NULL/außerhalb ungültig. Kein Gesamtzeitlimit. Eigene Temp-DDL erhält 1000 ms. SET im dynamischen Batch gilt nur dort und wird bei Rückkehr zurückgenommen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Ein einzelner Textwert wird mit LTRIM/RTRIM um U+0020-Leerzeichen bereinigt und mit UPPER normalisiert. NULL, Leerstring und reine Leerzeichen sind ungültig. Sämtliche erlaubten Werte: CONSOLE liefert Fach-, Quellen- und Warnzeilen in einer formatierten Menge, RAW sieben native Resultsets, TABLE nur die benannten ausgewählten Zielmengen, NONE keine fachlichen Resultsets. Die optionale JSON-Erzeugung bleibt unabhängig. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Bei TABLE ein JSON-Objekt mit mindestens einem Schlüssel-Ziel-Paar und Stringwerten. Alle zulässigen Schlüssel mit exakter Schreibweise: moduleStatus liefert den Gesamtstatus, endpoints die sichtbaren Endpoints, tcpEndpoints die TCP-Port-/IP-Konfiguration, mirroringEndpoints die Mirroringkonfiguration, connectionEncryptionSummary gruppierte Verbindungsflags, sourceStatus Quellenstatus und Zählwerte, warnings Hinweise und Grenzen. Jeder Schlüssel ist einzeln optional; doppelte Schlüssel werden abgelehnt. Ziele müssen vorhandene, leere lokale #Temp-Tabellen mit genau einer Seed-Spalte sein; höchstens 116 Zeichen, kein ## und kein reserviertes Präfix #Monitor (case-insensitiv). Doppelte Ziele werden case-insensitiv abgelehnt. Bei TABLE sind NULL, Leerstring und Leerzeichen ungültig; außerhalb TABLE sind nur NULL, Leerstring oder U+0020-Leerzeichen erlaubt. Die Vorprüfung erfolgt vor den Fachquellen; nacheinander geschriebene Mengen werden bei späterem Fehler nicht zurückgenommen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit; Default: 0. 0 unterdrückt, 1 erzeugt meta und sieben Arrays: moduleStatus, endpoints, tcpEndpoints, mirroringEndpoints, connectionEncryptionSummary, sourceStatus, warnings. Bit-Konvertierung: Ein numerischer Wert ungleich 0 wird bei der bit-Konvertierung 1; NULL erzeugt nichts. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT nvarchar(max), anfangs NULL. Bei @JsonErzeugen=1 normal meta (resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber, errorMessage) plus sieben Arrays, auch bei Quellenfehlern; sonst und im CATCH NULL. Empfang per nvarchar(max)-Variable OUTPUT. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@PrintMeldungen bit; Default: 1. 0 unterdrückt, 1 gibt RAISERROR-Meldungen niedriger Schwere bei Parameter-, Quellen- und äußeren Fehlern aus. Bit-Konvertierung: Ein numerischer Wert ungleich 0 wird bei der bit-Konvertierung 1; NULL wirkt 0. Hilfe-PRINTs sind unabhängig. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit; Default: 0. Konvertierter Wert 1 gibt vor Prüfung/Zugriff die Hilfetexte aus, setzt Status AVAILABLE und Partial 0, dann vorzeitiges RETURN ohne ausdrücklich angegebenen Wert. NULL wirkt 0; Ein numerischer Wert ungleich 0 wird bei der bit-Konvertierung 1. Andere Outputs bleiben NULL. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine varchar(40)-Variable; der Eingangswert wird auf NULL gesetzt. Alle möglichen Werte: AVAILABLE kennzeichnet den Hilfeabbruch ohne Analyse; INVALID_PARAMETER kennzeichnet ungültige Eingaben beziehungsweise den gespeicherten TABLE-Fehlercode 51011; AVAILABLE_LIMITED bezeichnet mindestens eine erfolgreiche nichtleere native Quelle; EMPTY_UNPROVEN mindestens eine erfolgreiche leere Quelle, sofern keine native Quelle nichtleer erfolgreich ist. Erst ohne erfolgreiche native Quelle wird der erste Fehler nach ENDPOINTS, TCP_ENDPOINTS, MIRRORING_ENDPOINTS, CONNECTIONS übernommen: DENIED_PERMISSION bedeutet einen als Berechtigungsfehler eingestuften Fehler (229, 297, 300, 371), TIMEOUT einen Sperrtimeout 1222 und ERROR_HANDLED einen sonstigen abgefangenen Fehler. Im äußeren CATCH gilt INVALID_PARAMETER bei gespeichertem TABLE-Fehlercode 51011, sonst ERROR_HANDLED. Reguläre Quellenfehler liefern weiterhin RETURN 0; Status und Fehler-OUTPUTs sind getrennt zu lesen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine bit-Variable; der Eingangswert wird auf NULL gesetzt. Hilfe liefert 0, da keine Analyse ausgeführt wird. Parameterfehler, regulärer Bericht und äußerer CATCH liefern 1; eine normale Analyse bleibt wegen begrenzter Metadatensicht ausdrücklich partiell. 0 aus der Hilfe bestätigt keine vollständige Inventur. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT int, anfangs NULL: Parameterfehler 51011; normal erster Quellenfehler nach ENDPOINTS, TCP_ENDPOINTS, MIRRORING_ENDPOINTS, CONNECTIONS, danach Ableitungsfehler. TABLE: Vorprüfung 51011, Writerfehler dessen Code oder 51010; CATCH Fehlercode. Empfang int-Variable OUTPUT. Im äußeren CATCH ist dieser Wert zugleich der Diagnose-RETURN-Wert; reguläre Quellenfehler ändern den normalen RETURN 0 nicht. Ohne erfassten Fehler bleibt der Wert NULL. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT nvarchar(2048), anfangs NULL; erhält Validierungs-, priorisierten Quellen-/Ableitungs- oder CATCH-Text. Hilfe belässt NULL. Empfang nvarchar(2048)-Variable OUTPUT. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'EXEC [monitor].[USP_EndpointTransportAnalysis] @MaxZeilen=200, @LockTimeoutMs=0, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_EndpointTransportAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];';
        PRINT N'CREATE TABLE [#EndpointTransportAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_EndpointTransportAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"endpoints":"#EndpointTransportAnalysis_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM [#EndpointTransportAnalysis_HelpExample]; DROP TABLE IF EXISTS [#EndpointTransportAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#EndpointTransportAnalysis_HelpExample]; THROW; END CATCH;';
        PRINT N'EXEC [monitor].[USP_EndpointTransportAnalysis] @Hilfe=1;';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN;
    END;
    IF @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE') OR @MaxZeilen<0
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs<0 OR @LockTimeoutMs>60000
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Ungültiger Ausgabe-, Limit-, Locktimeout- oder TABLE-Parameter.';
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@ErrorMessageOut) WITH NOWAIT;
        RETURN 51011;
    END;
    BEGIN TRY
        SET XACT_ABORT OFF;
        SET LOCK_TIMEOUT 1000;
        CREATE TABLE [#EndpointTransportAnalysis_moduleStatus]
        (
    [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsPartial] bit NOT NULL,
    [RowCount] bigint NOT NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#EndpointTransportAnalysis_endpoints]
        (
    [EndpointId] int NOT NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [PrincipalId] int NULL,
    [Protocol] tinyint NOT NULL,
    [ProtocolDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EndpointType] tinyint NOT NULL,
    [EndpointTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EndpointState] tinyint NULL,
    [EndpointStateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [IsAdminEndpoint] bit NOT NULL
        );
        CREATE TABLE [#EndpointTransportAnalysis_tcpEndpoints]
        (
    [EndpointId] int NOT NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [Port] int NOT NULL,
    [IsDynamicPort] bit NOT NULL,
    [IpAddress] nvarchar(45) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#EndpointTransportAnalysis_mirroringEndpoints]
        (
    [EndpointId] int NOT NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [MirroringRole] tinyint NULL,
    [MirroringRoleDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [IsEncryptionEnabled] bit NOT NULL,
    [ConnectionAuthentication] tinyint NOT NULL,
    [ConnectionAuthenticationDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [CertificateId] int NOT NULL,
    [EncryptionAlgorithm] tinyint NOT NULL,
    [EncryptionAlgorithmDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#EndpointTransportAnalysis_connectionEncryptionSummary]
        (
    [EndpointId] int NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EndpointType] tinyint NULL,
    [NetTransport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ProtocolType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EncryptOption] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [AuthenticationScheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ConnectionRows] bigint NOT NULL,
    [EndpointContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [EncryptionEvidence] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#EndpointTransportAnalysis_sourceStatus]
        (
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [RowUnit] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [StartedAtUtc] datetime2(3) NOT NULL,
    [CompletedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ObservedRows] bigint NULL,
    [ReturnedRows] bigint NULL,
    [IsLimited] bit NOT NULL,
    [ErrorNumber] int NULL,
    [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#EndpointTransportAnalysis_warnings]
        (
    [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#EndpointTransportAnalysis_Map]
        (
            [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#EndpointTransportAnalysis_ConnectionsCache]
        (
            [EndpointId] int NULL,
            [NetTransport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [ProtocolType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [EncryptOption] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [AuthenticationScheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|endpoints|tcpEndpoints|mirroringEndpoints|connectionEncryptionSummary|sourceStatus|warnings',
                @MappingTable=N'#EndpointTransportAnalysis_Map',@StatusCode=@TableStatus OUTPUT,
                @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE'
            BEGIN
                SET @TableFailureError=51011;
                RAISERROR(N'%s',16,1,@TableMessage);
            END;
        END;
        SET LOCK_TIMEOUT 0;
        SET @SetLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; ';
        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @Batch=@SetLock+N'INSERT [#EndpointTransportAnalysis_endpoints]
                SELECT [p].[endpoint_id],[p].[name],[p].[principal_id],[p].[protocol],[p].[protocol_desc],[p].[type],[p].[type_desc],[p].[state],[p].[state_desc],[p].[is_admin_endpoint] FROM [sys].[endpoints] AS [p] WITH (NOLOCK); SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @Batch,N'@Rows bigint OUTPUT',@Rows=@Observed OUTPUT;
            INSERT [#EndpointTransportAnalysis_sourceStatus] VALUES
                ('ENDPOINTS','NATIVE','CATALOG_ROW',@Started,SYSUTCDATETIME(),
                 CASE WHEN @Observed=0 THEN 'EMPTY_UNPROVEN' ELSE 'AVAILABLE_LIMITED' END,'VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#EndpointTransportAnalysis_endpoints];
            INSERT [#EndpointTransportAnalysis_sourceStatus] VALUES
                ('ENDPOINTS','NATIVE','CATALOG_ROW',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @Batch=@SetLock+N'INSERT [#EndpointTransportAnalysis_tcpEndpoints]
                SELECT [p].[endpoint_id],[p].[name],[p].[port],[p].[is_dynamic_port],CONVERT(nvarchar(45),[p].[ip_address]) FROM [sys].[tcp_endpoints] AS [p] WITH (NOLOCK); SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @Batch,N'@Rows bigint OUTPUT',@Rows=@Observed OUTPUT;
            INSERT [#EndpointTransportAnalysis_sourceStatus] VALUES
                ('TCP_ENDPOINTS','NATIVE','CATALOG_ROW',@Started,SYSUTCDATETIME(),
                 CASE WHEN @Observed=0 THEN 'EMPTY_UNPROVEN' ELSE 'AVAILABLE_LIMITED' END,'VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#EndpointTransportAnalysis_tcpEndpoints];
            INSERT [#EndpointTransportAnalysis_sourceStatus] VALUES
                ('TCP_ENDPOINTS','NATIVE','CATALOG_ROW',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @Batch=@SetLock+N'INSERT [#EndpointTransportAnalysis_mirroringEndpoints]
                SELECT [p].[endpoint_id],[p].[name],[p].[role],[p].[role_desc],[p].[is_encryption_enabled],[p].[connection_auth],[p].[connection_auth_desc],[p].[certificate_id],[p].[encryption_algorithm],[p].[encryption_algorithm_desc] FROM [sys].[database_mirroring_endpoints] AS [p] WITH (NOLOCK); SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @Batch,N'@Rows bigint OUTPUT',@Rows=@Observed OUTPUT;
            INSERT [#EndpointTransportAnalysis_sourceStatus] VALUES
                ('MIRRORING_ENDPOINTS','NATIVE','CATALOG_ROW',@Started,SYSUTCDATETIME(),
                 CASE WHEN @Observed=0 THEN 'EMPTY_UNPROVEN' ELSE 'AVAILABLE_LIMITED' END,'VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#EndpointTransportAnalysis_mirroringEndpoints];
            INSERT [#EndpointTransportAnalysis_sourceStatus] VALUES
                ('MIRRORING_ENDPOINTS','NATIVE','CATALOG_ROW',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @Batch=@SetLock+N'INSERT [#EndpointTransportAnalysis_ConnectionsCache]
                SELECT [p].[endpoint_id],[p].[net_transport],[p].[protocol_type],[p].[encrypt_option],[p].[auth_scheme] FROM [sys].[dm_exec_connections] AS [p] WITH (NOLOCK); SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @Batch,N'@Rows bigint OUTPUT',@Rows=@Observed OUTPUT;
            INSERT [#EndpointTransportAnalysis_sourceStatus] VALUES
                ('CONNECTIONS','NATIVE','CONNECTION_ROW',@Started,SYSUTCDATETIME(),
                 CASE WHEN @Observed=0 THEN 'EMPTY_UNPROVEN' ELSE 'AVAILABLE_LIMITED' END,'VISIBLE_ONLY',@Observed,NULL,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#EndpointTransportAnalysis_ConnectionsCache];
            INSERT [#EndpointTransportAnalysis_sourceStatus] VALUES
                ('CONNECTIONS','NATIVE','CONNECTION_ROW',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        SET @Started=SYSUTCDATETIME();
        IF EXISTS(SELECT 1 FROM [#EndpointTransportAnalysis_sourceStatus] WHERE [SourceKey]='CONNECTIONS' AND [ErrorNumber] IS NULL)
        BEGIN
            BEGIN TRY
                ;WITH [Groups] AS
                (
                    SELECT [EndpointId],[NetTransport],[ProtocolType],[EncryptOption],[AuthenticationScheme],COUNT_BIG(*) AS [ConnectionRows]
                    FROM [#EndpointTransportAnalysis_ConnectionsCache]
                    GROUP BY [EndpointId],[NetTransport],[ProtocolType],[EncryptOption],[AuthenticationScheme]
                )
                INSERT [#EndpointTransportAnalysis_connectionEncryptionSummary]
                SELECT [g].[EndpointId],[e].[EndpointName],[e].[EndpointType],[g].[NetTransport],[g].[ProtocolType],
                       [g].[EncryptOption],[g].[AuthenticationScheme],[g].[ConnectionRows],
                       CASE WHEN [g].[EndpointId] IS NULL THEN 'ENDPOINT_ID_NULL'
                            WHEN EXISTS(SELECT 1 FROM [#EndpointTransportAnalysis_sourceStatus] WHERE [SourceKey]='ENDPOINTS' AND [ErrorNumber] IS NOT NULL) THEN 'ENDPOINT_SOURCE_UNAVAILABLE'
                            WHEN [e].[EndpointId] IS NOT NULL THEN 'MATCHED_VISIBLE_ENDPOINT' ELSE 'NO_VISIBLE_ENDPOINT_MATCH' END,
                       CASE WHEN [e].[EndpointType]=4 OR UPPER([g].[ProtocolType]) COLLATE SQL_Latin1_General_CP1_CS_AS=N'DATABASE MIRRORING' THEN 'HADR_FLAG_NOT_APPLICABLE'
                            WHEN UPPER([g].[ProtocolType]) COLLATE SQL_Latin1_General_CP1_CS_AS=N'TSQL' THEN 'TSQL_FLAG_ONLY' ELSE 'NATIVE_FLAG_UNQUALIFIED' END
                FROM [Groups] AS [g] LEFT JOIN [#EndpointTransportAnalysis_endpoints] AS [e] ON [e].[EndpointId]=[g].[EndpointId];
                SET @Observed=@@ROWCOUNT;
                INSERT [#EndpointTransportAnalysis_sourceStatus] VALUES
                    ('CONNECTION_ENCRYPTION_SUMMARY','DERIVED','SUMMARY_GROUP',@Started,SYSUTCDATETIME(),
                     CASE WHEN @Observed=0 THEN 'EMPTY_UNPROVEN' ELSE 'AVAILABLE_LIMITED' END,'VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#EndpointTransportAnalysis_connectionEncryptionSummary];
                INSERT [#EndpointTransportAnalysis_sourceStatus] VALUES
                    ('CONNECTION_ENCRYPTION_SUMMARY','DERIVED','SUMMARY_GROUP',@Started,SYSUTCDATETIME(),
                     'ERROR_HANDLED','UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
            END CATCH;
        END
        ELSE
            INSERT [#EndpointTransportAnalysis_sourceStatus] VALUES
                ('CONNECTION_ENCRYPTION_SUMMARY','DERIVED','SUMMARY_GROUP',@Started,SYSUTCDATETIME(),
                 'SOURCE_UNAVAILABLE','UNPROVEN',NULL,NULL,0,NULL,NULL);
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [EndpointId]) AS [OutputOrdinal] FROM [#EndpointTransportAnalysis_endpoints])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [#EndpointTransportAnalysis_sourceStatus] SET [ReturnedRows]=(SELECT COUNT_BIG(*) FROM [#EndpointTransportAnalysis_endpoints]),
            [IsLimited]=CASE WHEN [ObservedRows]>(SELECT COUNT_BIG(*) FROM [#EndpointTransportAnalysis_endpoints]) THEN 1 ELSE 0 END
        WHERE [SourceKey]='ENDPOINTS' AND [ErrorNumber] IS NULL AND [StatusCode]<>'SOURCE_UNAVAILABLE';
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [EndpointId]) AS [OutputOrdinal] FROM [#EndpointTransportAnalysis_tcpEndpoints])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [#EndpointTransportAnalysis_sourceStatus] SET [ReturnedRows]=(SELECT COUNT_BIG(*) FROM [#EndpointTransportAnalysis_tcpEndpoints]),
            [IsLimited]=CASE WHEN [ObservedRows]>(SELECT COUNT_BIG(*) FROM [#EndpointTransportAnalysis_tcpEndpoints]) THEN 1 ELSE 0 END
        WHERE [SourceKey]='TCP_ENDPOINTS' AND [ErrorNumber] IS NULL AND [StatusCode]<>'SOURCE_UNAVAILABLE';
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [EndpointId]) AS [OutputOrdinal] FROM [#EndpointTransportAnalysis_mirroringEndpoints])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [#EndpointTransportAnalysis_sourceStatus] SET [ReturnedRows]=(SELECT COUNT_BIG(*) FROM [#EndpointTransportAnalysis_mirroringEndpoints]),
            [IsLimited]=CASE WHEN [ObservedRows]>(SELECT COUNT_BIG(*) FROM [#EndpointTransportAnalysis_mirroringEndpoints]) THEN 1 ELSE 0 END
        WHERE [SourceKey]='MIRRORING_ENDPOINTS' AND [ErrorNumber] IS NULL AND [StatusCode]<>'SOURCE_UNAVAILABLE';
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [EndpointId],[NetTransport],[ProtocolType],[EncryptOption],[AuthenticationScheme]) AS [OutputOrdinal] FROM [#EndpointTransportAnalysis_connectionEncryptionSummary])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [#EndpointTransportAnalysis_sourceStatus] SET [ReturnedRows]=(SELECT COUNT_BIG(*) FROM [#EndpointTransportAnalysis_connectionEncryptionSummary]),
            [IsLimited]=CASE WHEN [ObservedRows]>(SELECT COUNT_BIG(*) FROM [#EndpointTransportAnalysis_connectionEncryptionSummary]) THEN 1 ELSE 0 END
        WHERE [SourceKey]='CONNECTION_ENCRYPTION_SUMMARY' AND [ErrorNumber] IS NULL AND [StatusCode]<>'SOURCE_UNAVAILABLE';
        INSERT [#EndpointTransportAnalysis_warnings] VALUES
            ('METADATA_COMPLETENESS_UNPROVEN',NULL,N'Nur getrennte sichtbare Engineaufnahmen; keine atomare oder vollständige Endpointsicht und keine externe Erreichbarkeitsprobe.'),
            ('TLS_DETAILS_UNPROVEN','CONNECTIONS',N'Native Verschlüsselungsflags belegen weder TLS-Version oder Cipher noch Zertifikatskette, Hostnamenprüfung, Extended Protection oder Treiberkonfiguration.'),
            ('CONNECTION_ROW_SEMANTICS','CONNECTIONS',N'ConnectionRows zählt native DMV-Zeilen. MARS kann zusätzliche logische Session-Zeilen erzeugen; die Summe ist keine Zahl physischer Kanäle oder Clients.'),
            ('HADR_FLAG_BOUNDARY','CONNECTIONS',N'Für HADR-Mirroring liefert encrypt_option nativ FALSE. Dies ist kein Nachweis unverschlüsselten Transports; die Endpointkonfiguration ist getrennte Evidenz.'),
            ('TCP_CONFIGURATION_BOUNDARY','TCP_ENDPOINTS',N'Katalogport und LISTENER_IP können von der tatsächlichen Protokollkonfiguration abweichen. Endpointzustände beweisen keine externe Erreichbarkeit.'),
            ('MIRRORING_CONFIGURATION_BOUNDARY','MIRRORING_ENDPOINTS',N'Konfigurierte Authentifizierung, Algorithmus und Zertifikats-ID sind kein Nachweis eines konkreten Handshakes. MirroringRole betrifft Database Mirroring, nicht eine AG-Replikarolle.');
        INSERT [#EndpointTransportAnalysis_warnings]
            SELECT 'OUTPUT_LIMIT',[SourceKey],N'Das Fachresultset ist gekappt; native Aufnahme und Verknüpfung verwenden vollständige Caches. Quellen- und Warnzeilen bleiben ungekürzt.'
            FROM [#EndpointTransportAnalysis_sourceStatus] WHERE [IsLimited]=1;
        INSERT [#EndpointTransportAnalysis_warnings]
            SELECT 'EMPTY_UNPROVEN',[SourceKey],N'Die sichtbare Quelle ist leer. Dies beweist keine instanzweite Abwesenheit.'
            FROM [#EndpointTransportAnalysis_sourceStatus] WHERE [StatusCode]='EMPTY_UNPROVEN';
        INSERT [#EndpointTransportAnalysis_warnings]
            SELECT 'SOURCE_UNAVAILABLE',[SourceKey],N'Die Quelle oder ihre Ableitung ist nicht verfügbar; native Details stehen im Quellenstatus.'
            FROM [#EndpointTransportAnalysis_sourceStatus] WHERE [ErrorNumber] IS NOT NULL OR [StatusCode]='SOURCE_UNAVAILABLE';
        IF NOT EXISTS(SELECT 1 FROM [#EndpointTransportAnalysis_sourceStatus] WHERE [SourceKind]='NATIVE' AND [StatusCode]='AVAILABLE_LIMITED')
        BEGIN
            IF EXISTS(SELECT 1 FROM [#EndpointTransportAnalysis_sourceStatus] WHERE [SourceKind]='NATIVE' AND [StatusCode]='EMPTY_UNPROVEN') SET @Status='EMPTY_UNPROVEN';
            ELSE SELECT TOP (1) @Status=[StatusCode] FROM [#EndpointTransportAnalysis_sourceStatus]
                WHERE [SourceKind]='NATIVE' ORDER BY CASE [SourceKey] WHEN 'ENDPOINTS' THEN 1 WHEN 'TCP_ENDPOINTS' THEN 2 WHEN 'MIRRORING_ENDPOINTS' THEN 3 ELSE 4 END;
        END;
        SELECT TOP (1) @Error=[ErrorNumber],@Message=[ErrorMessage] FROM [#EndpointTransportAnalysis_sourceStatus]
            WHERE [ErrorNumber] IS NOT NULL ORDER BY CASE [SourceKey] WHEN 'ENDPOINTS' THEN 1 WHEN 'TCP_ENDPOINTS' THEN 2 WHEN 'MIRRORING_ENDPOINTS' THEN 3 WHEN 'CONNECTIONS' THEN 4 ELSE 5 END;
        DECLARE @Rows bigint=(SELECT COUNT_BIG(*) FROM [#EndpointTransportAnalysis_endpoints])+
            (SELECT COUNT_BIG(*) FROM [#EndpointTransportAnalysis_tcpEndpoints])+
            (SELECT COUNT_BIG(*) FROM [#EndpointTransportAnalysis_mirroringEndpoints])+
            (SELECT COUNT_BIG(*) FROM [#EndpointTransportAnalysis_connectionEncryptionSummary]);
        INSERT [#EndpointTransportAnalysis_moduleStatus] VALUES
            (N'USP_EndpointTransportAnalysis',@CapturedAtUtc,@Status,1,@Rows,
             N'SQL-sichtbare Endpointkonfiguration und gruppierte native Verbindungsflags; getrennte Momentaufnahmen ohne TLS-, Cipher-, Zertifikatsvertrauens- oder Erreichbarkeitsbeweis.');
        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'EndpointTransportAnalysis' AS [resultName],1 AS [schemaVersion],
                @CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],CAST(1 AS bit) AS [isPartial],
                @Error AS [errorNumber],@Message AS [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=(SELECT * FROM [#EndpointTransportAnalysis_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_endpoints nvarchar(max)=(SELECT * FROM [#EndpointTransportAnalysis_endpoints] ORDER BY [EndpointId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_tcpEndpoints nvarchar(max)=(SELECT * FROM [#EndpointTransportAnalysis_tcpEndpoints] ORDER BY [EndpointId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_mirroringEndpoints nvarchar(max)=(SELECT * FROM [#EndpointTransportAnalysis_mirroringEndpoints] ORDER BY [EndpointId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_connectionEncryptionSummary nvarchar(max)=(SELECT * FROM [#EndpointTransportAnalysis_connectionEncryptionSummary] ORDER BY [EndpointId],[NetTransport],[ProtocolType],[EncryptOption],[AuthenticationScheme] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=(SELECT * FROM [#EndpointTransportAnalysis_sourceStatus] ORDER BY [SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=(SELECT * FROM [#EndpointTransportAnalysis_warnings] ORDER BY [WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),N',"endpoints":',COALESCE(@Json_endpoints,N'[]'),N',"tcpEndpoints":',COALESCE(@Json_tcpEndpoints,N'[]'),N',"mirroringEndpoints":',COALESCE(@Json_mirroringEndpoints,N'[]'),N',"connectionEncryptionSummary":',COALESCE(@Json_connectionEncryptionSummary,N'[]'),N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;
        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#EndpointTransportAnalysis_moduleStatus];
            SELECT * FROM [#EndpointTransportAnalysis_endpoints] ORDER BY [EndpointId];
            SELECT * FROM [#EndpointTransportAnalysis_tcpEndpoints] ORDER BY [EndpointId];
            SELECT * FROM [#EndpointTransportAnalysis_mirroringEndpoints] ORDER BY [EndpointId];
            SELECT * FROM [#EndpointTransportAnalysis_connectionEncryptionSummary] ORDER BY [EndpointId],[NetTransport],[ProtocolType],[EncryptOption],[AuthenticationScheme];
            SELECT * FROM [#EndpointTransportAnalysis_sourceStatus] ORDER BY [SourceKey];
            SELECT * FROM [#EndpointTransportAnalysis_warnings] ORDER BY [WarningCode],[SourceKey];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [EndpointTransportOutput] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [ResultName],[TargetTable] FROM [#EndpointTransportAnalysis_Map] ORDER BY [ResultName];
            OPEN [EndpointTransportOutput];
            FETCH NEXT FROM [EndpointTransportOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#EndpointTransportAnalysis_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                    @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,
                    @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN
                    SET @TableFailureError=COALESCE(@TableError,51010);
                    RAISERROR(N'%s',16,1,@TableMessage);
                END;
                FETCH NEXT FROM [EndpointTransportOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [EndpointTransportOutput]; DEALLOCATE [EndpointTransportOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            SET LOCK_TIMEOUT 1000;
            CREATE TABLE [#EndpointTransportAnalysis_Console]
            (
                [Scope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
                [EndpointId] int NULL,
                [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [Detail] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            );
            INSERT [#EndpointTransportAnalysis_Console]
                SELECT 'ENDPOINT',[EndpointId],[EndpointName],NULL,CONCAT(N'Typ=',[EndpointTypeDescription],N'; Protokoll=',[ProtocolDescription],N'; Zustand=',[EndpointStateDescription],N'; PrincipalId=',[PrincipalId]) FROM [#EndpointTransportAnalysis_endpoints];
            INSERT [#EndpointTransportAnalysis_Console]
                SELECT 'TCP',[EndpointId],[EndpointName],NULL,CONCAT(N'Katalogport=',[Port],N'; dynamisch=',[IsDynamicPort],N'; LISTENER_IP=',[IpAddress]) FROM [#EndpointTransportAnalysis_tcpEndpoints];
            INSERT [#EndpointTransportAnalysis_Console]
                SELECT 'MIRRORING',[EndpointId],[EndpointName],NULL,CONCAT(N'Verschlüsselung konfiguriert=',[IsEncryptionEnabled],N'; Algorithmus=',[EncryptionAlgorithmDescription],N'; Authentifizierung=',[ConnectionAuthenticationDescription],N'; CertificateId=',[CertificateId],N'; Mirroringrolle=',[MirroringRoleDescription]) FROM [#EndpointTransportAnalysis_mirroringEndpoints];
            INSERT [#EndpointTransportAnalysis_Console]
                SELECT 'CONNECTION_GROUP',[EndpointId],[EndpointName],[EncryptionEvidence],CONCAT(N'NetTransport=',[NetTransport],N'; Protokoll=',[ProtocolType],N'; encrypt_option=',[EncryptOption],N'; Authentifizierung=',[AuthenticationScheme],N'; DMV-Zeilen=',[ConnectionRows],N'; Endpointkontext=',[EndpointContextStatus]) FROM [#EndpointTransportAnalysis_connectionEncryptionSummary];
            INSERT [#EndpointTransportAnalysis_Console]
                SELECT 'SOURCE',NULL,NULL,[StatusCode],CONCAT([SourceKey],N'; Einheit=',[RowUnit],N'; beobachtet=',[ObservedRows],N'; Ausgabe=',[ReturnedRows],N'; Fehler=',[ErrorNumber],N'; ',[ErrorMessage]) FROM [#EndpointTransportAnalysis_sourceStatus];
            INSERT [#EndpointTransportAnalysis_Console]
                SELECT 'WARNING',NULL,NULL,NULL,CONCAT([WarningCode],N'; ',[SourceKey],N'; ',[Detail]) FROM [#EndpointTransportAnalysis_warnings];
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#EndpointTransportAnalysis_Console',
                @ResultLabel=N'Sichtbare Endpoints und begrenzte Transportverschlüsselungsevidenz',
                @EmptyMessage=N'Keine sichtbaren Endpoint- oder Verbindungszeilen; Quellenstatus beachten.';
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL
            RAISERROR(N'USP_EndpointTransportAnalysis: mindestens eine Quelle ist nicht verfügbar; siehe sourceStatus.',10,1) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    END TRY
    BEGIN CATCH
        SELECT @Error=COALESCE(@TableFailureError,ERROR_NUMBER()),@Message=ERROR_MESSAGE(),@Json=NULL;
        SELECT @StatusCodeOut=CASE WHEN @TableFailureError=51011 THEN 'INVALID_PARAMETER' ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO

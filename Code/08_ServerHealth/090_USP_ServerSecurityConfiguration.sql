USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ServerSecurityConfiguration
Version      : 2.0.1
Stand        : 2026-07-15
Zweck        : Die Procedure liest ausgewählte sicherheitsrelevante Serveroptionen,
               Dienstinformationen und Servereigenschaften, ohne sie zu verändern.
Datenquellen : sys.configurations, sys.dm_server_services, SERVERPROPERTY
Vertrag      : Resultset 1 ist immer Modulstatus; @ResultSetArt=NONE unterdrückt
               Resultsets und liefert Status ausschließlich über OUTPUT-Parameter.
===============================================================================
*/

CREATE OR ALTER PROCEDURE [monitor].[USP_ServerSecurityConfiguration]
    @PrintMeldungen  bit = 1,
    @Hilfe           bit = 0,
    @ResultSetArt    varchar(16) = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen    bit = 0,
    @Json             nvarchar(max) = NULL OUTPUT,
    @StatusCodeOut   varchar(40) = NULL OUTPUT,
    @IsPartialOut    bit = NULL OUTPUT,
    @ErrorNumberOut  int = NULL OUTPUT,
    @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;SET @Json=NULL;DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'configuration',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @MonitorPrintMessage nvarchar(2048);

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_ServerSecurityConfiguration';
        PRINT N'Erfasst ausgewählte sicherheitsrelevante Serveroptionen, SQL-Dienste und Servereigenschaften lesend.';
        PRINT N'Die Hilfe läuft nach einem eventuellen TABLE-Preflight und vor der Erhebung. Befunde sind Prüfsignale, keine automatische Richtlinienentscheidung.';
        PRINT N'@PrintMeldungen bit; Default: 1. 1 gibt nach der Quellenprüfung bei einem Status ungleich AVAILABLE eine Statusmeldung aus; 0 unterdrückt sie. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1, da nur der Vergleich mit 1 die Ausgabe auslöst.';
        PRINT N'@Hilfe bit; Default: 0. 1 gibt die Parameterhilfe aus und beendet vor den Fachquellen; 0 erhebt Daten. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Bei ResultSetArt TABLE wird der Ziel-Preflight vor der Hilfe ausgeführt.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Bindung an varchar(16): CONSOLE gibt ausschließlich die Sicherheitskonfiguration unter dem Label ServerSecurityConfiguration aus; bei leerer Konfiguration liefert der Helfer eine Leerzeile; Quellenstatus, Dienste und Eigenschaften stehen in RAW beziehungsweise JSON; RAW liefert technische Resultsets; TABLE exportiert nur configuration; NONE unterdrückt Resultsets. Äußere U+0020-Leerzeichen werden entfernt, Großschreibung vereinheitlicht; NULL wird leer und ist ungültig. TABLE/CONSOLE werden für reguläre Resultsets zu NONE und separat ausgegeben. Ungültige Werte setzen INVALID_PARAMETER und IsPartial=1; Quellprüfung läuft dennoch.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Bei TABLE ist ein JSON-Objekt mit dem einzelnen Resultatnamen configuration erforderlich, abgebildet auf eine vorhandene, leere lokale #temp-Tabelle mit genau einer Seed-Spalte. Permanente und globale ##-Tabellen, nichtleere Ziele und Ziele mit fertigem Ausgabeschema werden vom Preflight zurückgewiesen; er läuft vor der Hilfe und Fehler lösen 51011 aus. Außerhalb von TABLE sind NULL, Leertext oder Leerzeichen erlaubt; sonst wird 51011 ausgelöst.';
        PRINT N'@JsonErzeugen bit; Default: 0. 1 erstellt JSON mit meta, sources, configuration, services, properties und warnings als leerem Array; 0 bzw. NULL unterdrückt die Erstellung. NULL wirkt wie 0; numerische 0 bleibt bit 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück; @Json ist beim Eintritt bereits auf NULL gesetzt.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(max)-Variable binden, z. B. @Json=@j OUTPUT. Der Eingangswert wird zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 wird nach der Sammlung das JSON-Dokument geschrieben; sonst bleibt er NULL. Der Hilfezweig beendet vor der Erzeugung.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine varchar(40)-Variable binden. AVAILABLE bei Erfolg, PARTIAL bei gemischter Quellenverfügbarkeit, INVALID_PARAMETER bei ungültiger ResultSetArt. Bei Gesamtausfall gilt der alphabetisch erste Quellenfehler: DENIED_PERMISSION (229/297/300/371), TIMEOUT (1222) oder ERROR_HANDLED (sonst). Ein ungültiger Modus wird durch Quellenfehlerstatus ersetzt. Zuweisung nach Quellenversuchen, nicht bei Hilfe; eine gebundene, mit NULL initialisierte Variable bleibt NULL.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine bit-Variable binden. 0 bei AVAILABLE, sonst 1 für invaliden Modus oder mindestens einen ausgefallenen Quellzweig. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine int-Variable binden. Fehlernummer des alphabetisch ersten ausgefallenen Quellenzweigs, sonst NULL. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(2048)-Variable binden. Fehlermeldung des alphabetisch ersten ausgefallenen Quellenzweigs, Validierungstext oder NULL bei Erfolg. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.';
        PRINT N'EXEC [monitor].[USP_ServerSecurityConfiguration] @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @j nvarchar(max); EXEC [monitor].[USP_ServerSecurityConfiguration] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;';
        PRINT N'CREATE TABLE [#ServerSecurityConfiguration_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_ServerSecurityConfiguration] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"configuration":"#ServerSecurityConfiguration_HelpExample"}''; END TRY BEGIN CATCH DROP TABLE [#ServerSecurityConfiguration_HelpExample]; THROW; END CATCH; DROP TABLE [#ServerSecurityConfiguration_HelpExample];';
        PRINT N'EXEC [monitor].[USP_ServerSecurityConfiguration] @Hilfe=1;';










        RETURN;
    END;

    DECLARE
        @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME(),
        @StatusCode        varchar(40) = 'AVAILABLE',
        @IsPartial         bit = 0,
        @ErrorNumber       int = NULL,
        @ErrorMessage      nvarchar(2048) = NULL;

    IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') BEGIN SET @StatusCode='INVALID_PARAMETER';SET @IsPartial=1;SET @ErrorMessage=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';END;

    CREATE TABLE [#ServerSecurityConfiguration_SourceStatus]
    (
        [SourceName]   sysname COLLATE SQL_Latin1_General_CP1_CS_AS        NOT NULL,
        [StatusCode]   varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS    NOT NULL,
        [ErrorNumber]  int            NULL,
        [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#ServerSecurityConfiguration_Configuration]
    (
        [ConfigurationName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ConfiguredValue]   sql_variant   NULL,
        [RunningValue]      sql_variant   NULL,
        [Finding]           varchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS   NOT NULL
    );

    CREATE TABLE [#ServerSecurityConfiguration_Services]
    (
        [ServiceName]                      nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ServiceAccount]                   nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [StartupTypeDescription]           nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS  NULL,
        [StatusDescription]                nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS  NULL,
        [InstantFileInitializationEnabled] nvarchar(10) COLLATE SQL_Latin1_General_CP1_CS_AS  NULL,
        [InstantFileInitializationFinding] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS   NOT NULL
    );

    CREATE TABLE [#ServerSecurityConfiguration_Properties]
    (
        [MachineName]                 sysname COLLATE SQL_Latin1_General_CP1_CS_AS       NULL,
        [ServerName]                  sysname COLLATE SQL_Latin1_General_CP1_CS_AS       NULL,
        [Edition]                     nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsWindowsAuthenticationOnly] int           NULL,
        [CallerIsSysadmin]            int           NULL
    );

    SET LOCK_TIMEOUT 0;

    BEGIN TRY
        INSERT [#ServerSecurityConfiguration_Configuration]
        (
            [ConfigurationName],
            [ConfiguredValue],
            [RunningValue],
            [Finding]
        )
        SELECT
            [c].[name],
            [c].[value],
            [c].[value_in_use],
            CASE
                WHEN [c].[name] = N'xp_cmdshell'
                     AND CONVERT(int, [c].[value_in_use]) = 1
                    THEN 'XPCMDSHELL_ENABLED'
                WHEN [c].[name] = N'Ole Automation Procedures'
                     AND CONVERT(int, [c].[value_in_use]) = 1
                    THEN 'OLE_AUTOMATION_ENABLED'
                WHEN [c].[name] = N'clr strict security'
                     AND CONVERT(int, [c].[value_in_use]) = 0
                    THEN 'CLR_STRICT_SECURITY_OFF'
                WHEN [c].[name] = N'external scripts enabled'
                     AND CONVERT(int, [c].[value_in_use]) = 1
                    THEN 'EXTERNAL_SCRIPTS_ENABLED'
                ELSE 'OK_OR_CONTEXT_DEPENDENT'
            END
        FROM [sys].[configurations] AS c WITH (NOLOCK)
        WHERE [c].[name] IN
        (
            N'xp_cmdshell',
            N'Ole Automation Procedures',
            N'clr enabled',
            N'clr strict security',
            N'external scripts enabled',
            N'remote admin connections',
            N'contained database authentication'
        );

        INSERT [#ServerSecurityConfiguration_SourceStatus] VALUES
            (N'sys.configurations', 'AVAILABLE', NULL, NULL);
    END TRY
    BEGIN CATCH
        INSERT [#ServerSecurityConfiguration_SourceStatus] VALUES
        (
            N'sys.configurations',
            CASE
                WHEN ERROR_NUMBER() IN (229, 297, 300, 371) THEN 'DENIED_PERMISSION'
                WHEN ERROR_NUMBER() = 1222 THEN 'TIMEOUT'
                ELSE 'ERROR_HANDLED'
            END,
            ERROR_NUMBER(),
            ERROR_MESSAGE()
        );
    END CATCH;

    BEGIN TRY
        INSERT [#ServerSecurityConfiguration_Services]
        (
            [ServiceName],
            [ServiceAccount],
            [StartupTypeDescription],
            [StatusDescription],
            [InstantFileInitializationEnabled],
            [InstantFileInitializationFinding]
        )
        SELECT
            [s].[servicename],
            [s].[service_account],
            [s].[startup_type_desc],
            [s].[status_desc],
            CONVERT(nvarchar(10), [s].[instant_file_initialization_enabled]),
            CASE
                WHEN CONVERT(nvarchar(10), [s].[instant_file_initialization_enabled]) = N'Y'
                    THEN 'IFI_ENABLED'
                ELSE 'IFI_NOT_CONFIRMED'
            END
        FROM [sys].[dm_server_services] AS s WITH (NOLOCK);

        INSERT [#ServerSecurityConfiguration_SourceStatus] VALUES
            (N'sys.dm_server_services', 'AVAILABLE', NULL, NULL);
    END TRY
    BEGIN CATCH
        INSERT [#ServerSecurityConfiguration_SourceStatus] VALUES
        (
            N'sys.dm_server_services',
            CASE
                WHEN ERROR_NUMBER() IN (229, 297, 300, 371) THEN 'DENIED_PERMISSION'
                WHEN ERROR_NUMBER() = 1222 THEN 'TIMEOUT'
                ELSE 'ERROR_HANDLED'
            END,
            ERROR_NUMBER(),
            ERROR_MESSAGE()
        );
    END CATCH;

    BEGIN TRY
        INSERT [#ServerSecurityConfiguration_Properties]
        (
            [MachineName],
            [ServerName],
            [Edition],
            [IsWindowsAuthenticationOnly],
            [CallerIsSysadmin]
        )
        SELECT
            CONVERT(sysname, SERVERPROPERTY(N'MachineName')),
            CONVERT(sysname, SERVERPROPERTY(N'ServerName')),
            CONVERT(nvarchar(128), SERVERPROPERTY(N'Edition')),
            CONVERT(int, SERVERPROPERTY(N'IsIntegratedSecurityOnly')),
            CONVERT(int, IS_SRVROLEMEMBER(N'sysadmin'));

        INSERT [#ServerSecurityConfiguration_SourceStatus] VALUES
            (N'SERVERPROPERTY', 'AVAILABLE', NULL, NULL);
    END TRY
    BEGIN CATCH
        INSERT [#ServerSecurityConfiguration_SourceStatus] VALUES
        (
            N'SERVERPROPERTY',
            'ERROR_HANDLED',
            ERROR_NUMBER(),
            ERROR_MESSAGE()
        );
    END CATCH;



    IF EXISTS
    (
        SELECT 1
        FROM [#ServerSecurityConfiguration_SourceStatus] AS s
        WHERE [s].[StatusCode] <> 'AVAILABLE'
    )
    BEGIN
        SELECT
            @IsPartial = 1,
            @StatusCode = CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM [#ServerSecurityConfiguration_SourceStatus] AS s
                    WHERE [s].[StatusCode] = 'AVAILABLE'
                )
                    THEN 'PARTIAL'
                ELSE
                (
                    SELECT TOP (1) [s].[StatusCode]
                    FROM [#ServerSecurityConfiguration_SourceStatus] AS s
                    WHERE [s].[StatusCode] <> 'AVAILABLE'
                    ORDER BY [s].[SourceName]
                )
            END,
            @ErrorNumber =
            (
                SELECT TOP (1) [s].[ErrorNumber]
                FROM [#ServerSecurityConfiguration_SourceStatus] AS s
                WHERE [s].[StatusCode] <> 'AVAILABLE'
                ORDER BY [s].[SourceName]
            ),
            @ErrorMessage =
            (
                SELECT TOP (1) [s].[ErrorMessage]
                FROM [#ServerSecurityConfiguration_SourceStatus] AS s
                WHERE [s].[StatusCode] <> 'AVAILABLE'
                ORDER BY [s].[SourceName]
            );
    END;

    SELECT
        @StatusCodeOut = @StatusCode,
        @IsPartialOut = @IsPartial,
        @ErrorNumberOut = @ErrorNumber,
        @ErrorMessageOut = @ErrorMessage;

    IF @PrintMeldungen = 1
       AND @StatusCode <> 'AVAILABLE'
    BEGIN
        BEGIN
    SET @MonitorPrintMessage = FORMATMESSAGE(N'USP_ServerSecurityConfiguration: %s', COALESCE(@ErrorMessage, N'eine Quelle ist nicht verfügbar'));
    RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
END;
    END;

    IF @ResultSetArtNormalisiert<>'NONE'
    BEGIN
      SELECT CAST('2.0' AS varchar(16)) [ContractVersion],@CollectionTimeUtc [CollectionTimeUtc],N'monitor.USP_ServerSecurityConfiguration' [ModuleName],@StatusCode [StatusCode],@IsPartial [IsPartial],@ErrorNumber [ErrorNumber],@ErrorMessage [ErrorMessage];
      IF @ResultSetArtNormalisiert='RAW' BEGIN SELECT * FROM [#ServerSecurityConfiguration_SourceStatus] ORDER BY [SourceName];SELECT * FROM [#ServerSecurityConfiguration_Configuration] ORDER BY [ConfigurationName];SELECT * FROM [#ServerSecurityConfiguration_Services] ORDER BY [ServiceName];SELECT * FROM [#ServerSecurityConfiguration_Properties];END
      ELSE BEGIN SELECT N'Sicherheitsquelle' [Ergebnis],[x].* FROM [#ServerSecurityConfiguration_SourceStatus] [x] ORDER BY [SourceName];SELECT N'Sicherheitskonfiguration' [Ergebnis],[ConfigurationName] [Einstellung],CONVERT(nvarchar(4000),[ConfiguredValue]) [konfiguriert],CONVERT(nvarchar(4000),[RunningValue]) [aktiv],[Finding] [Bewertung] FROM [#ServerSecurityConfiguration_Configuration] ORDER BY [ConfigurationName];SELECT N'SQL-Dienst' [Ergebnis],[x].* FROM [#ServerSecurityConfiguration_Services] [x] ORDER BY [ServiceName];SELECT N'Server-Eigenschaft' [Ergebnis],[x].* FROM [#ServerSecurityConfiguration_Properties] [x];END;
    END;
    IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'ServerSecurityConfiguration' [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@ErrorNumber [errorNumber],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@Sources nvarchar(max)=(SELECT * FROM [#ServerSecurityConfiguration_SourceStatus] ORDER BY [SourceName] FOR JSON PATH,INCLUDE_NULL_VALUES),@Cfg nvarchar(max)=(SELECT [ConfigurationName],CONVERT(nvarchar(4000),[ConfiguredValue]) [ConfiguredValue],CONVERT(nvarchar(4000),[RunningValue]) [RunningValue],[Finding] FROM [#ServerSecurityConfiguration_Configuration] ORDER BY [ConfigurationName] FOR JSON PATH,INCLUDE_NULL_VALUES),@Services nvarchar(max)=(SELECT * FROM [#ServerSecurityConfiguration_Services] ORDER BY [ServiceName] FOR JSON PATH,INCLUDE_NULL_VALUES),@Props nvarchar(max)=(SELECT * FROM [#ServerSecurityConfiguration_Properties] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"sources":',COALESCE(@Sources,N'[]'),N',"configuration":',COALESCE(@Cfg,N'[]'),N',"services":',COALESCE(@Services,N'[]'),N',"properties":',COALESCE(@Props,N'[]'),N',"warnings":[]}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ServerSecurityConfiguration_Configuration'
            , @ResultLabel=N'ServerSecurityConfiguration'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ServerSecurityConfiguration_Configuration'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

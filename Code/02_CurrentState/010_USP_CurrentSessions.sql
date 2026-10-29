USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentSessions
Version      : 2.2.0
Stand        : 2026-07-22
Typ          : Stored Procedure
Zweck        : Liefert aktuelle Sessions mit exakten Mehrfachfiltern, Pattern-
               Filtern und RAW-, CONSOLE- oder JSON-Ausgabe.
SQL-Version  : SQL Server 2019 oder neuer; Regex ab SQL Server 2025 und
               Compatibility Level 170.
Listen       : | trennt außerhalb von [...]. Werte bleiben case-sensitiv.
Steuerwerte  : werden getrimmt und case-insensitiv normalisiert.
Resultsets   : RAW: Status, Sessions. CONSOLE: lesbare Status-/Sessionansicht.
               NONE: keine Resultsets. JSON: meta, sessions, warnings.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentSessions]
      @SessionIds                   nvarchar(max)  = NULL
    , @EigeneSessionsModus          varchar(16)    = 'ALLE'
    , @AktuelleSessionEinbeziehen   bit            = 0
    , @SystemSessionsEinbeziehen    bit            = 0
    , @ToolHintergrundabfragenEinbeziehen bit       = 0
    , @InaktiveSessionsEinbeziehen  bit            = 1
    , @LoginNames                   nvarchar(max)  = NULL
    , @LoginNamePattern             nvarchar(4000) = NULL
    , @HostNames                    nvarchar(max)  = NULL
    , @HostNamePattern              nvarchar(4000) = NULL
    , @ProgramNames                 nvarchar(max)  = NULL
    , @ProgramNamePattern           nvarchar(4000) = NULL
    , @DatabaseNames                nvarchar(max)  = NULL
    , @DatabaseNamePattern          nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @MitSqlText                   bit            = 0
    , @MaxSqlTextZeichen            int            = 2000
    , @MaxZeilen                    int            = 500
    , @Sortierung                   varchar(32)    = 'CPU'
    , @ResultSetArt                 varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                 bit            = 0
    , @Json                         nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen               bit            = 1
    , @Hilfe                        bit            = 0
    , @ParentCurrentStateSnapshotId uniqueidentifier = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json = NULL;

    DECLARE @ModuleName sysname = N'USP_CurrentSessions';
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @RowCount bigint = 0;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Detail nvarchar(2000) = NULL;
    DECLARE @RequiredPermission nvarchar(256) = CASE WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) >= 16 THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END;
    DECLARE @HasFullView bit = CASE WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1 THEN 1 WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) >= 16 THEN COALESCE(HAS_PERMS_BY_NAME(NULL,N'SERVER',N'VIEW SERVER PERFORMANCE STATE'),0) ELSE COALESCE(HAS_PERMS_BY_NAME(NULL,N'SERVER',N'VIEW SERVER STATE'),0) END;
    DECLARE @ResultSetArtNormalisiert varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'sessions',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @CandidateMaxZeilen bigint;
    DECLARE @EvidenceSnapshotStartedAtUtc datetime2(3)=@CollectionTimeUtc;
    DECLARE @ParentSnapshotIsPartial bit=0;
    DECLARE @MonitorPrintMessage nvarchar(2048);

    SET @EigeneSessionsModus = UPPER(LTRIM(RTRIM(COALESCE(@EigeneSessionsModus,'ALLE'))));
    SET @Sortierung = UPPER(LTRIM(RTRIM(COALESCE(@Sortierung,'CPU'))));

    IF @Hilfe = 1
    BEGIN
        PRINT N'Diese Hilfe beschreibt die aktuelle Sessioninventarisierung, ihre Quellen und ihre Ausgabeformen.';
        PRINT N'@SessionIds nvarchar(max) = NULL wählt mit einer Pipe-Liste wie N''57|61'' Session-IDs von 1 bis 32767 aus; doppelte IDs werden zusammengefasst, ungültige Einträge führen zu INVALID_PARAMETER.';
        PRINT N'@EigeneSessionsModus varchar(16) = ''ALLE'' wählt alle sichtbaren Sessions, ''NUR'' nur Sessions mit OriginalLoginName = ORIGINAL_LOGIN() und ''AUSSCHLIESSEN'' Sessions mit einem abweichenden OriginalLoginName; zulässig sind genau ALLE, NUR und AUSSCHLIESSEN.';
        PRINT N'@AktuelleSessionEinbeziehen bit = 0 nimmt die aufrufende Session bei 1 in den direkten Aufruf auf; der Overview-Consumer reicht diesen Schalter nicht weiter.';
        PRINT N'@SystemSessionsEinbeziehen bit = 0 beschränkt den Scope standardmäßig auf User-Sessions; bei 1 werden auch sichtbare System-Sessions berücksichtigt.';
        PRINT N'@ToolHintergrundabfragenEinbeziehen bit = 0 blendet Sessions aus, deren ProgramName zu einer aktivierten ToolBackgroundQueryPattern-Regel passt; bei 1 bleiben sie mit Regelcode, Kategorie, Erkennungsart und Konfidenz sichtbar.';
        PRINT N'@InaktiveSessionsEinbeziehen bit = 1 lässt auch Sessions ohne Request und ohne offene Transaktion passieren; bei 0 bleiben solche inaktiven Sessions ausgeschlossen, Sessions mit Request oder offener Transaktion jedoch im Scope.';
        PRINT N'@LoginNames nvarchar(max) = NULL filtert nach einer Pipe-Liste exakter LoginName-Werte; die Einträge werden case-sensitive verglichen und sind mit @LoginNamePattern exklusiv.';
        PRINT N'@LoginNamePattern nvarchar(4000) = NULL filtert LoginName mit einem unpräfixierten LIKE-Muster oder mit like:, regex: oder regexi:; das Pattern ist mit @LoginNames exklusiv und Regex benötigt SQL Server 2025 sowie Compatibility Level 170 der Installationsdatenbank.';
        PRINT N'@HostNames nvarchar(max) = NULL filtert nach einer Pipe-Liste exakter HostName-Werte; die Einträge werden case-sensitive verglichen und sind mit @HostNamePattern exklusiv.';
        PRINT N'@HostNamePattern nvarchar(4000) = NULL filtert HostName mit einem unpräfixierten LIKE-Muster oder mit like:, regex: oder regexi:; das Pattern ist mit @HostNames exklusiv und Regex benötigt SQL Server 2025 sowie Compatibility Level 170 der Installationsdatenbank.';
        PRINT N'@ProgramNames nvarchar(max) = NULL filtert nach einer Pipe-Liste exakter ProgramName-Werte; die Einträge werden case-sensitive verglichen und sind mit @ProgramNamePattern exklusiv.';
        PRINT N'@ProgramNamePattern nvarchar(4000) = NULL filtert ProgramName mit einem unpräfixierten LIKE-Muster oder mit like:, regex: oder regexi:; das Pattern ist mit @ProgramNames exklusiv und Regex benötigt SQL Server 2025 sowie Compatibility Level 170 der Installationsdatenbank.';
        PRINT N'@DatabaseNames nvarchar(max) = NULL filtert nach einer Pipe-Liste bracket-aware geparster Datenbanknamen; die Einträge werden case-sensitive verglichen und sind mit @DatabaseNamePattern exklusiv.';
        PRINT N'@DatabaseNamePattern nvarchar(4000) = NULL filtert DatabaseName mit einem unpräfixierten LIKE-Muster oder mit like:, regex: oder regexi:; das Pattern ist mit @DatabaseNames exklusiv und Regex benötigt SQL Server 2025 sowie Compatibility Level 170 der Installationsdatenbank.';
        PRINT N'@HighImpactConfirmed bit = 0 wird nur aus Signaturkompatibilität angenommen und im Procedure-Body nicht ausgewertet; der Wert bestätigt oder verändert keine Ausführung.';
        PRINT N'@MitSqlText bit = 0 verzichtet standardmäßig auf Textauflösung; bei 1 werden deduplizierte Handles der Request- und letzten Connection-Statements vor Ergebnisfilter und Zeilenlimit aufgelöst.';
        PRINT N'@MaxSqlTextZeichen int = 2000 begrenzt die Unicodeprojektion von CurrentStatement und BatchText je behaltenem Wert; NULL oder 0 lässt Texte ungekürzt, ein negativer Wert führt zu INVALID_PARAMETER und Kürzungen werden gemeldet.';
        PRINT N'@MaxZeilen int = 500 begrenzt die zurückgegebenen Sessionzeilen; NULL oder 0 bedeutet unbegrenzt, ein negativer Wert führt zu INVALID_PARAMETER und hasMoreRows zeigt bei positivem Limit weitere passende Kandidaten an; ohne Regex gilt frühes TOP (N+1), mit Regex wird erst nach der Kandidatenmaterialisierung gefiltert.';
        PRINT N'@Sortierung varchar(32) = ''CPU'' sortiert CPU, logische Reads und Writes absteigend, Loginzeit absteigend oder Session-ID aufsteigend; Requestwerte werden auf Sessionwerte zurückgeführt, zulässige Werte sind CPU, READS, WRITES, LOGIN und SESSION.';
        PRINT N'@ResultSetArt varchar(16) = ''CONSOLE'' wählt CONSOLE, RAW, TABLE oder NONE ohne Beachtung der Groß-/Kleinschreibung; CONSOLE zeigt Status und Sessionübersicht, RAW liefert Status plus fachliche Zeilen, TABLE exportiert sessions und NONE unterdrückt Resultsets.';
        PRINT N'@ResultTablesJson nvarchar(max) = NULL ordnet ausschließlich bei @ResultSetArt = ''TABLE'' das Resultset sessions genau einer leeren lokalen #Temp-Tabelle zu; die JSON-Eigenschaft muss sessions heißen, Ziele müssen eindeutig sein und dürfen weder ##-Tabellen noch das reservierte Präfix #Monitor verwenden.';
        PRINT N'@JsonErzeugen bit = 0 erzeugt bei 1 das JSON-Envelope unabhängig von der gewählten Resultsetart in @Json; @ResultSetArt = ''NONE'' unterdrückt Resultsets, nicht aber den OUTPUT-Wert.';
        PRINT N'@Json nvarchar(max) = NULL OUTPUT nimmt bei @JsonErzeugen = 1 das JSON-Envelope mit meta, sessions und warnings auf; der Einstieg setzt den Wert zunächst auf NULL.';
        PRINT N'@PrintMeldungen bit = 1 gibt bei nicht verfügbarem Status eine Severity-10-Warnung aus; bei 0 wird diese zusätzliche Meldung unterdrückt.';
        PRINT N'@Hilfe bit = 0 gibt bei 1 diese Hilfe aus und kehrt vor Parameterprüfung, Quellenzugriff und Fachresultaten zurück.';
        PRINT N'@ParentCurrentStateSnapshotId uniqueidentifier = NULL ist ein interner USP_CurrentOverview-Parameter; NULL liest direkt frisch, eine gesetzte ID muss zur aufrufenden Session und zum gültigen Snapshotvertrag passen.';
        PRINT N'Der direkte Aufruf liest sys.dm_exec_sessions, sys.dm_exec_requests und sys.dm_exec_connections nacheinander mit NOLOCK; optional löst sys.dm_exec_sql_text die eindeutigen Request- und letzten Connection-Handles auf.';
        PRINT N'Sessionzähler wie SessionCpuMs, SessionReads, SessionWrites und SessionLogicalReads kumulieren seit Sessionbeginn, während Requestwerte und Verbindungsdaten den Lesezeitpunkt beschreiben; die nacheinander gelesenen Quellen bilden keinen atomaren Snapshot.';
        PRINT N'Pro Session wird der Request mit der kleinsten sichtbaren request_id korreliert; eine inaktive Session kann deshalb Request- und DatabaseName-Werte als NULL liefern, und mehrere sichtbare Connections können die Zeilengranularität beeinflussen.';
        PRINT N'Der sichtbare Scope hängt von Serverberechtigungen ab: ab SQL Server 2022 wird VIEW SERVER PERFORMANCE STATE benötigt, auf früheren Versionen VIEW SERVER STATE; sysadmin gilt als Vollsicht, eingeschränkte Quellensicht kann AVAILABLE_LIMITED ergeben.';
        PRINT N'Tool-Erkennung ist eine Diagnoseheuristik aus aktivierten LIKE-Regeln und kein Sicherheitsmerkmal; die Klassifikation liefert TVF_ToolBackgroundQueryInfo mit RuleCode, Category, Detection und Confidence.';
        PRINT N'Die Filter verwenden TVF_ParseBigintList, TVF_ParseStringList, TVF_ParseSqlNameList und TVF_ParsePattern; Statementprojektion und Warnungen nutzen TVF_StatementText, TVF_WaitTypeInfo, InternalProjectUnicodeTextColumn und InternalEmitTruncationWarning.';
        PRINT N'Für TABLE prüft InternalPrepareSingleResultTable die Zuordnung sessions. InternalWriteResultTable passt ein bereits vorhandenes, leeres lokales #Temp-Ziel mit genau einer Seedspalte an das exportierte Schema an. Fehlende, nichtleere oder anders aufgebaute Ziele sowie unzulässige Zuordnungen werden abgelehnt.';
        PRINT N'Im JSON enthält meta unter anderem Status, Teilstatus, Snapshot-ID, angeforderte und gelieferte Zeilen sowie hasMoreRows; sessions enthält die Sessionwerte und drei Wait-Einordnungen, warnings kann auch einen erfolgreichen Detailhinweis enthalten.';
        PRINT N'RAW gibt zuerst den Status mit 13 Feldern und danach Sessionwerte mit 51 Feldern sowie zehn Wait-Feldern aus; TABLE exportiert die 51 Sessionfelder, CONSOLE ergänzt Status und eine lesbare Übersicht, und die Tabellenreihenfolge ist für TABLE nicht zugesichert.';
        PRINT N'Mögliche Statuswerte sind AVAILABLE, AVAILABLE_LIMITED, INVALID_PARAMETER, UNAVAILABLE_FEATURE, DENIED_PERMISSION, TIMEOUT, UNAVAILABLE_OBJECT, ERROR_HANDLED und ein abgelehnter Parent-Kontext; Fehlerdetails erscheinen in Status, JSON-Metadaten oder warnings, sofern ein JSON angefordert wurde.';
        PRINT N'Bei AVAILABLE_LIMITED sind mindestens eine relevante Quelle oder der Parent-Snapshot eingeschränkt; eine leere oder gefilterte Menge beweist nicht, dass außerhalb des sichtbaren Scopes keine Session existiert.';
        PRINT N'Beispiel CONSOLE-Aufruf:';
        PRINT N'EXEC [monitor].[USP_CurrentSessions] @ResultSetArt = ''CONSOLE'';';
        PRINT N'Beispiel TABLE-Aufruf; das leere Seed-Ziel wird vom Writer an das sessions-Schema angepasst:';
        PRINT N'CREATE TABLE #CurrentSessions_HelpExample ([Seed] int NULL);';
        PRINT N'EXEC [monitor].[USP_CurrentSessions] @ResultSetArt = ''TABLE'', @ResultTablesJson = N''{"sessions":"#CurrentSessions_HelpExample"}'';';
        PRINT N'SELECT * FROM #CurrentSessions_HelpExample;';
        PRINT N'DROP TABLE #CurrentSessions_HelpExample;';
        PRINT N'Beispiel JSON-OUTPUT ohne Resultset:';
        PRINT N'DECLARE @CurrentSessionsJson nvarchar(max);';
        PRINT N'EXEC [monitor].[USP_CurrentSessions] @ResultSetArt = ''NONE'', @JsonErzeugen = 1, @Json = @CurrentSessionsJson OUTPUT;';
        PRINT N'SELECT @CurrentSessionsJson AS SessionJson;';
        PRINT N'Parameterdefinitionen einschließlich Typ und Standardwert stehen in Metadata/Inventory/Parameters.csv.';
        PRINT N'Bei bit-Parametern wandelt SQL Server numerische Nichtnullwerte vor Procedure-Eintritt in 0 oder 1 um; NULL wird nur beim Tool-Schalter als ungültig geprüft und folgt bei den übrigen Schaltern den jeweiligen Bedingungen.';
        RETURN;
    END;

    CREATE TABLE [#CurrentSessions_SessionIdFilter]
    (
        [SessionId] smallint NOT NULL PRIMARY KEY
    );
    CREATE TABLE [#CurrentSessions_StringFilter]
    (
          [FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StringValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([FilterType],[StringValue])
    );

    DECLARE @LoginMode varchar(8), @LoginPattern nvarchar(4000), @LoginFlags varchar(8), @LoginValid bit;
    DECLARE @HostMode varchar(8), @HostPattern nvarchar(4000), @HostFlags varchar(8), @HostValid bit;
    DECLARE @ProgramMode varchar(8), @ProgramPattern nvarchar(4000), @ProgramFlags varchar(8), @ProgramValid bit;
    DECLARE @DatabaseMode varchar(8), @DatabasePattern nvarchar(4000), @DatabaseFlags varchar(8), @DatabaseValid bit;

    BEGIN TRY
        SELECT @LoginMode=[PatternMode],@LoginPattern=[PatternValue],@LoginFlags=[RegexFlags],@LoginValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@LoginNamePattern);
        SELECT @HostMode=[PatternMode],@HostPattern=[PatternValue],@HostFlags=[RegexFlags],@HostValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@HostNamePattern);
        SELECT @ProgramMode=[PatternMode],@ProgramPattern=[PatternValue],@ProgramFlags=[RegexFlags],@ProgramValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ProgramNamePattern);
        SELECT @DatabaseMode=[PatternMode],@DatabasePattern=[PatternValue],@DatabaseFlags=[RegexFlags],@DatabaseValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@DatabaseNamePattern);
    END TRY
    BEGIN CATCH
        SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@IsPartial=1,
               @StatusCode=CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                                WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                                ELSE 'ERROR_HANDLED' END;
    END CATCH;

    IF @StatusCode='AVAILABLE' AND @SessionIds IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM [monitor].[TVF_ParseBigintList](@SessionIds) WHERE [IsValid]=0 OR [NumberValue] NOT BETWEEN 1 AND 32767)
            SET @StatusCode='INVALID_PARAMETER';
        ELSE
            INSERT [#CurrentSessions_SessionIdFilter]([SessionId])
            SELECT CONVERT(smallint,[NumberValue]) FROM [monitor].[TVF_ParseBigintList](@SessionIds)
            GROUP BY [NumberValue];
    END;

    IF @StatusCode='AVAILABLE'
       AND ((@LoginNames IS NOT NULL AND @LoginNamePattern IS NOT NULL)
         OR (@HostNames IS NOT NULL AND @HostNamePattern IS NOT NULL)
         OR (@ProgramNames IS NOT NULL AND @ProgramNamePattern IS NOT NULL)
         OR (@DatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL)
         OR @LoginValid=0 OR @HostValid=0 OR @ProgramValid=0 OR @DatabaseValid=0)
        SET @StatusCode='INVALID_PARAMETER';

    IF @StatusCode='AVAILABLE'
       AND ((@LoginNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseStringList](@LoginNames) WHERE [IsValid]=0 OR LEN([StringValue])>128))
         OR (@HostNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseStringList](@HostNames) WHERE [IsValid]=0 OR LEN([StringValue])>128))
         OR (@ProgramNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseStringList](@ProgramNames) WHERE [IsValid]=0 OR LEN([StringValue])>128))
         OR (@DatabaseNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@DatabaseNames) WHERE [IsValid]=0)))
        SET @StatusCode='INVALID_PARAMETER';

    IF @StatusCode='AVAILABLE'
    BEGIN
        INSERT [#CurrentSessions_StringFilter]([FilterType],[StringValue]) SELECT 'LOGIN',[StringValue] FROM [monitor].[TVF_ParseStringList](@LoginNames) WHERE [IsValid]=1 GROUP BY [StringValue];
        INSERT [#CurrentSessions_StringFilter]([FilterType],[StringValue]) SELECT 'HOST',[StringValue] FROM [monitor].[TVF_ParseStringList](@HostNames) WHERE [IsValid]=1 GROUP BY [StringValue];
        INSERT [#CurrentSessions_StringFilter]([FilterType],[StringValue]) SELECT 'PROGRAM',[StringValue] FROM [monitor].[TVF_ParseStringList](@ProgramNames) WHERE [IsValid]=1 GROUP BY [StringValue];
        INSERT [#CurrentSessions_StringFilter]([FilterType],[StringValue]) SELECT 'DATABASE',[NameValue] FROM [monitor].[TVF_ParseSqlNameList](@DatabaseNames) WHERE [IsValid]=1 GROUP BY [NameValue];
    END;

    DECLARE @HasRegex bit = CASE WHEN @LoginMode IN('REGEX','REGEXI') OR @HostMode IN('REGEX','REGEXI') OR @ProgramMode IN('REGEX','REGEXI') OR @DatabaseMode IN('REGEX','REGEXI') THEN 1 ELSE 0 END;
    IF @StatusCode='AVAILABLE' AND @HasRegex=1
       AND (TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17 OR COALESCE((SELECT [compatibility_level] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID()),0)<170)
    BEGIN
        SET @StatusCode='UNAVAILABLE_FEATURE';
        SET @ErrorMessage=N'Regex benötigt SQL Server 2025 und Compatibility Level 170 für die Installationsdatenbank.';
    END;

    IF @StatusCode='AVAILABLE'
       AND (@EigeneSessionsModus NOT IN('ALLE','NUR','AUSSCHLIESSEN') OR @Sortierung NOT IN('CPU','READS','WRITES','LOGIN','SESSION') OR @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') OR @MaxZeilen<0 OR @MaxSqlTextZeichen<0 OR @ToolHintergrundabfragenEinbeziehen IS NULL OR @ToolHintergrundabfragenEinbeziehen NOT IN(0,1))
    BEGIN
        SET @StatusCode='INVALID_PARAMETER';
        SET @ErrorMessage=N'Mindestens ein Steuerparameter ist ungültig.';
    END;

    IF @StatusCode='INVALID_PARAMETER' AND @ErrorMessage IS NULL
        SET @ErrorMessage=N'Ungültige Liste, Kombination oder Patternangabe.';

    CREATE TABLE [#CurrentSessions_Result]
    (
          [SessionId] smallint NOT NULL, [RequestId] int NULL, [IsUserProcess] bit NOT NULL
        , [SessionStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OriginalLoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsToolBackgroundQuery] bit NOT NULL
        , [ToolBackgroundRuleCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ToolBackgroundCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ToolBackgroundDetection] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ToolBackgroundConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ClientInterfaceName] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [LoginTime] datetime NULL
        , [LastRequestStartTime] datetime NULL, [LastRequestEndTime] datetime NULL
        , [DatabaseId] smallint NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [OpenTransactionCount] int NULL, [TransactionIsolationLevel] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SessionCpuMs] int NULL, [SessionReads] bigint NULL, [SessionWrites] bigint NULL
        , [SessionLogicalReads] bigint NULL, [SessionMemoryMb] decimal(19,2) NULL
        , [SessionRowCount] bigint NULL, [RequestCpuMs] int NULL, [RequestElapsedMs] int NULL
        , [RequestLogicalReads] bigint NULL, [RequestReads] bigint NULL, [RequestWrites] bigint NULL
        , [BlockingSessionId] smallint NULL, [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WaitTimeMs] int NULL
        , [WaitResource] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PercentComplete] real NULL
        , [ClientNetAddress] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [NetTransport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProtocolType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [EncryptOption] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AuthScheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CurrentStatementCharacters] bigint NULL, [CurrentStatementBytes] bigint NULL
        , [CurrentStatementIsTruncated] bit NOT NULL DEFAULT(0), [CurrentStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [BatchTextCharacters] bigint NULL, [BatchTextBytes] bigint NULL
        , [BatchTextIsTruncated] bit NOT NULL DEFAULT(0), [BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#CurrentSessions_SourceSessions]
    (
          [session_id] smallint NOT NULL PRIMARY KEY
        , [is_user_process] bit NOT NULL
        , [status] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [login_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [original_login_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [host_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [program_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [client_interface_name] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [login_time] datetime NOT NULL
        , [last_request_start_time] datetime NOT NULL
        , [last_request_end_time] datetime NULL
        , [open_transaction_count] int NOT NULL
        , [transaction_isolation_level] smallint NOT NULL
        , [cpu_time] int NOT NULL
        , [reads] bigint NOT NULL
        , [writes] bigint NOT NULL
        , [logical_reads] bigint NOT NULL
        , [memory_usage] int NOT NULL
        , [row_count] bigint NOT NULL
    );
    CREATE TABLE [#CurrentSessions_SourceRequests]
    (
          [session_id] smallint NOT NULL
        , [request_id] int NOT NULL
        , [status] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [database_id] smallint NOT NULL
        , [cpu_time] int NOT NULL
        , [total_elapsed_time] int NOT NULL
        , [logical_reads] bigint NOT NULL
        , [reads] bigint NOT NULL
        , [writes] bigint NOT NULL
        , [blocking_session_id] smallint NULL
        , [wait_type] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [wait_time] int NOT NULL
        , [wait_resource] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [percent_complete] real NOT NULL
        , [sql_handle] varbinary(64) NULL
        , [statement_start_offset] int NULL
        , [statement_end_offset] int NULL
        , PRIMARY KEY ([session_id],[request_id])
    );
    CREATE TABLE [#CurrentSessions_SourceConnections]
    (
          [session_id] int NULL
        , [connection_id] uniqueidentifier NOT NULL PRIMARY KEY
        , [most_recent_sql_handle] varbinary(64) NULL
        , [client_net_address] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [net_transport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [protocol_type] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [encrypt_option] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [auth_scheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE INDEX [IX_CurrentSessions_SourceConnections_SessionId]
        ON [#CurrentSessions_SourceConnections]([session_id]);
    CREATE TABLE [#CurrentSessions_SourceSqlText]
    (
          [SqlHandle] varbinary(64) NOT NULL PRIMARY KEY
        , [text] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [dbid] int NULL
        , [objectid] int NULL
        , [number] smallint NULL
        , [encrypted] bit NULL
    );

    IF @StatusCode='AVAILABLE' AND @ParentCurrentStateSnapshotId IS NOT NULL
    BEGIN
        BEGIN TRY
            EXEC [sys].[sp_executesql] N'
                DECLARE @Probe int;
                SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Context] WHERE 1=0;
                SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_SourceStatus] WHERE 1=0;
                SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Sessions] WHERE 1=0;
                SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Requests] WHERE 1=0;
                SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Connections] WHERE 1=0;
                SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_SqlText] WHERE 1=0;';

            IF NOT EXISTS
            (
                SELECT 1
                FROM [#CurrentOverview_CurrentStateSnapshot_Context]
                WHERE [SnapshotId]=@ParentCurrentStateSnapshotId
                  AND [OwnerSessionId]=CONVERT(smallint,@@SPID)
                  AND [ContractVersion]=2
            )
            BEGIN
                SET @StatusCode='INVALID_PARENT_SNAPSHOT';
                SET @IsPartial=1;
                SET @ErrorMessage=N'Die Parent-Snapshot-ID gehört nicht zum aktuellen Aufruf.';
            END
            ELSE
            BEGIN
                INSERT [#CurrentSessions_SourceSessions]
                SELECT
                      [session_id],[is_user_process],[status],[login_name],[original_login_name]
                    , [host_name],[program_name],[client_interface_name],[login_time]
                    , [last_request_start_time],[last_request_end_time],[open_transaction_count]
                    , [transaction_isolation_level],[cpu_time],[reads],[writes],[logical_reads]
                    , [memory_usage],[row_count]
                FROM [#CurrentOverview_CurrentStateSnapshot_Sessions]
                WHERE [SnapshotId]=@ParentCurrentStateSnapshotId;

                INSERT [#CurrentSessions_SourceRequests]
                SELECT
                      [session_id],[request_id],[status],[database_id],[cpu_time]
                    , [total_elapsed_time],[logical_reads],[reads],[writes]
                    , [blocking_session_id],[wait_type],[wait_time],[wait_resource]
                    , [percent_complete],[sql_handle],[statement_start_offset],[statement_end_offset]
                FROM [#CurrentOverview_CurrentStateSnapshot_Requests]
                WHERE [SnapshotId]=@ParentCurrentStateSnapshotId;

                INSERT [#CurrentSessions_SourceConnections]
                SELECT
                      [session_id],[connection_id],[most_recent_sql_handle],[client_net_address]
                    , [net_transport],[protocol_type],[encrypt_option],[auth_scheme]
                FROM [#CurrentOverview_CurrentStateSnapshot_Connections]
                WHERE [SnapshotId]=@ParentCurrentStateSnapshotId;

                IF @MitSqlText=1
                    INSERT [#CurrentSessions_SourceSqlText]
                    SELECT [SqlHandle],[Text],[DatabaseId],[ObjectId],[ObjectNumber],[IsEncrypted]
                    FROM [#CurrentOverview_CurrentStateSnapshot_SqlText]
                    WHERE [SnapshotId]=@ParentCurrentStateSnapshotId;

                SELECT
                      @EvidenceSnapshotStartedAtUtc=MIN([CapturedAtUtc])
                    , @ParentSnapshotIsPartial=CONVERT(bit,MAX(CONVERT(int,[IsPartial])))
                FROM [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
                WHERE [SnapshotId]=@ParentCurrentStateSnapshotId
                  AND [SourceCode] IN ('SESSIONS','REQUESTS','CONNECTIONS','SQL_TEXT');
            END;
        END TRY
        BEGIN CATCH
            SELECT
                  @ErrorNumber=ERROR_NUMBER()
                , @ErrorMessage=ERROR_MESSAGE()
                , @IsPartial=1
                , @StatusCode=CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                    WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                    ELSE 'INVALID_PARENT_SNAPSHOT' END;
        END CATCH;
    END
    ELSE IF @StatusCode='AVAILABLE'
    BEGIN TRY
        SET @EvidenceSnapshotStartedAtUtc=SYSUTCDATETIME();

        INSERT [#CurrentSessions_SourceSessions]
        SELECT
              [session_id],[is_user_process],[status],[login_name],[original_login_name]
            , [host_name],[program_name],[client_interface_name],[login_time]
            , [last_request_start_time],[last_request_end_time],[open_transaction_count]
            , [transaction_isolation_level],[cpu_time],[reads],[writes],[logical_reads]
            , [memory_usage],[row_count]
        FROM [sys].[dm_exec_sessions] WITH (NOLOCK);

        INSERT [#CurrentSessions_SourceRequests]
        SELECT
              [session_id],[request_id],[status],[database_id],[cpu_time]
            , [total_elapsed_time],[logical_reads],[reads],[writes]
            , [blocking_session_id],[wait_type],[wait_time],[wait_resource]
            , [percent_complete],[sql_handle],[statement_start_offset],[statement_end_offset]
        FROM [sys].[dm_exec_requests] WITH (NOLOCK);

        INSERT [#CurrentSessions_SourceConnections]
        SELECT
              [session_id],[connection_id],[most_recent_sql_handle],[client_net_address]
            , [net_transport],[protocol_type],[encrypt_option],[auth_scheme]
        FROM [sys].[dm_exec_connections] WITH (NOLOCK);

        IF @MitSqlText=1
        BEGIN
            INSERT [#CurrentSessions_SourceSqlText]
            (
                [SqlHandle],[text],[dbid],[objectid],[number],[encrypted]
            )
            SELECT
                  [h].[SqlHandle],[t].[text],[t].[dbid],[t].[objectid],[t].[number],[t].[encrypted]
            FROM
            (
                SELECT [sql_handle] AS [SqlHandle]
                FROM [#CurrentSessions_SourceRequests]
                WHERE [sql_handle] IS NOT NULL
                UNION
                SELECT [most_recent_sql_handle]
                FROM [#CurrentSessions_SourceConnections]
                WHERE [most_recent_sql_handle] IS NOT NULL
            ) AS [h]
            OUTER APPLY [sys].[dm_exec_sql_text]([h].[SqlHandle]) AS [t];
        END;
    END TRY
    BEGIN CATCH
        SELECT
              @ErrorNumber=ERROR_NUMBER()
            , @ErrorMessage=ERROR_MESSAGE()
            , @IsPartial=1
            , @StatusCode=CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                ELSE 'ERROR_HANDLED' END;
    END CATCH;

    SET @CandidateMaxZeilen = CASE WHEN @HasRegex=1 OR @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen)+1 END;

    IF @StatusCode='AVAILABLE'
    BEGIN TRY
        INSERT [#CurrentSessions_Result]
        SELECT TOP (@CandidateMaxZeilen)
              [s].[session_id],[r].[request_id],[s].[is_user_process],[s].[status],[r].[status]
            , [s].[login_name],[s].[original_login_name],[s].[host_name],[s].[program_name]
            , [tool].[IsToolBackgroundQuery],[tool].[ToolBackgroundRuleCode]
            , [tool].[ToolBackgroundCategory]
            , [tool].[ToolBackgroundDetection],[tool].[ToolBackgroundConfidence]
            , [s].[client_interface_name]
            , [s].[login_time],[s].[last_request_start_time],[s].[last_request_end_time],[r].[database_id],[d].[name]
            , [s].[open_transaction_count]
            , CASE [s].[transaction_isolation_level] WHEN 0 THEN N'Unspecified' WHEN 1 THEN N'ReadUncommitted' WHEN 2 THEN N'ReadCommitted' WHEN 3 THEN N'RepeatableRead' WHEN 4 THEN N'Serializable' WHEN 5 THEN N'Snapshot' END
            , [s].[cpu_time],[s].[reads],[s].[writes],[s].[logical_reads],CONVERT(decimal(19,2),[s].[memory_usage]*8.0/1024.0),[s].[row_count]
            , [r].[cpu_time],[r].[total_elapsed_time],[r].[logical_reads],[r].[reads],[r].[writes],NULLIF([r].[blocking_session_id],0)
            , [r].[wait_type],[r].[wait_time],[r].[wait_resource],[r].[percent_complete]
            , [c].[client_net_address],[c].[net_transport],[c].[protocol_type],[c].[encrypt_option],[c].[auth_scheme]
            , NULL,NULL,CONVERT(bit,0),CASE WHEN @MitSqlText=1 THEN [st].[StatementText] END
            , NULL,NULL,CONVERT(bit,0),CASE WHEN @MitSqlText=1 THEN [t].[text] END
        FROM [#CurrentSessions_SourceSessions] AS [s]
        LEFT JOIN [#CurrentSessions_SourceConnections] AS [c] ON [c].[session_id]=[s].[session_id]
        OUTER APPLY (SELECT TOP (1) [rr].* FROM [#CurrentSessions_SourceRequests] AS [rr] WHERE [rr].[session_id]=[s].[session_id] ORDER BY [rr].[request_id]) AS [r]
        LEFT JOIN [sys].[databases] AS [d] WITH (NOLOCK) ON [d].[database_id]=[r].[database_id]
        LEFT JOIN [#CurrentSessions_SourceSqlText] AS [t] ON [t].[SqlHandle]=CASE WHEN @MitSqlText=1 THEN COALESCE([r].[sql_handle],[c].[most_recent_sql_handle]) END
        OUTER APPLY [monitor].[TVF_StatementText]([t].[text],[r].[statement_start_offset],[r].[statement_end_offset]) AS [st]
        CROSS APPLY [monitor].[TVF_ToolBackgroundQueryInfo]([s].[program_name]) AS [tool]
        WHERE (NOT EXISTS(SELECT 1 FROM [#CurrentSessions_SessionIdFilter]) OR EXISTS(SELECT 1 FROM [#CurrentSessions_SessionIdFilter] AS [f] WHERE [f].[SessionId]=[s].[session_id]))
          AND (@AktuelleSessionEinbeziehen=1 OR [s].[session_id]<>@@SPID)
          AND (@SystemSessionsEinbeziehen=1 OR [s].[is_user_process]=1)
          AND (@ToolHintergrundabfragenEinbeziehen=1 OR [tool].[IsToolBackgroundQuery]=0)
          AND (@InaktiveSessionsEinbeziehen=1 OR [r].[session_id] IS NOT NULL OR [s].[open_transaction_count]>0)
          AND (@EigeneSessionsModus='ALLE' OR (@EigeneSessionsModus='NUR' AND [s].[original_login_name]=ORIGINAL_LOGIN()) OR (@EigeneSessionsModus='AUSSCHLIESSEN' AND ISNULL([s].[original_login_name],N'')<>ORIGINAL_LOGIN()))
          AND (NOT EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] WHERE [FilterType]='LOGIN') OR EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] AS [f] WHERE [f].[FilterType]='LOGIN' AND [f].[StringValue]=[s].[login_name] COLLATE SQL_Latin1_General_CP1_CS_AS))
          AND (NOT EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] WHERE [FilterType]='HOST') OR EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] AS [f] WHERE [f].[FilterType]='HOST' AND [f].[StringValue]=[s].[host_name] COLLATE SQL_Latin1_General_CP1_CS_AS))
          AND (NOT EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] WHERE [FilterType]='PROGRAM') OR EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] AS [f] WHERE [f].[FilterType]='PROGRAM' AND [f].[StringValue]=[s].[program_name] COLLATE SQL_Latin1_General_CP1_CS_AS))
          AND (NOT EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] WHERE [FilterType]='DATABASE') OR EXISTS(SELECT 1 FROM [#CurrentSessions_StringFilter] AS [f] WHERE [f].[FilterType]='DATABASE' AND [f].[StringValue]=[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))
          AND (@LoginMode<>'LIKE' OR [s].[login_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @LoginPattern COLLATE SQL_Latin1_General_CP1_CS_AS)
          AND (@HostMode<>'LIKE' OR [s].[host_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @HostPattern COLLATE SQL_Latin1_General_CP1_CS_AS)
          AND (@ProgramMode<>'LIKE' OR [s].[program_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @ProgramPattern COLLATE SQL_Latin1_General_CP1_CS_AS)
          AND (@DatabaseMode<>'LIKE' OR [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @DatabasePattern COLLATE SQL_Latin1_General_CP1_CS_AS)
        ORDER BY CASE WHEN @Sortierung='CPU' THEN COALESCE([r].[cpu_time],[s].[cpu_time]) END DESC,
                 CASE WHEN @Sortierung='READS' THEN COALESCE([r].[logical_reads],[s].[logical_reads]) END DESC,
                 CASE WHEN @Sortierung='WRITES' THEN COALESCE([r].[writes],[s].[writes]) END DESC,
                 CASE WHEN @Sortierung='LOGIN' THEN DATEDIFF_BIG(SECOND,'20000101',[s].[login_time]) END DESC,
                 CASE WHEN @Sortierung='SESSION' THEN [s].[session_id] END,[s].[session_id];

        IF @HasRegex=1
        BEGIN
            DECLARE @Sql nvarchar(max)=N'';
            IF @LoginMode IN('REGEX','REGEXI') SET @Sql+=N'DELETE FROM [#CurrentSessions_Result] WHERE [LoginName] IS NULL OR NOT REGEXP_LIKE([LoginName],@LoginPattern,@LoginFlags);';
            IF @HostMode IN('REGEX','REGEXI') SET @Sql+=N'DELETE FROM [#CurrentSessions_Result] WHERE [HostName] IS NULL OR NOT REGEXP_LIKE([HostName],@HostPattern,@HostFlags);';
            IF @ProgramMode IN('REGEX','REGEXI') SET @Sql+=N'DELETE FROM [#CurrentSessions_Result] WHERE [ProgramName] IS NULL OR NOT REGEXP_LIKE([ProgramName],@ProgramPattern,@ProgramFlags);';
            IF @DatabaseMode IN('REGEX','REGEXI') SET @Sql+=N'DELETE FROM [#CurrentSessions_Result] WHERE [DatabaseName] IS NULL OR NOT REGEXP_LIKE([DatabaseName],@DatabasePattern,@DatabaseFlags);';
            EXEC [sys].[sp_executesql] @Sql,N'@LoginPattern nvarchar(4000),@LoginFlags varchar(8),@HostPattern nvarchar(4000),@HostFlags varchar(8),@ProgramPattern nvarchar(4000),@ProgramFlags varchar(8),@DatabasePattern nvarchar(4000),@DatabaseFlags varchar(8)',@LoginPattern,@LoginFlags,@HostPattern,@HostFlags,@ProgramPattern,@ProgramFlags,@DatabasePattern,@DatabaseFlags;
        END;

        IF @MaxZeilen IS NOT NULL AND @MaxZeilen>0
        BEGIN
            IF (SELECT COUNT_BIG(*) FROM [#CurrentSessions_Result])>@MaxZeilen SET @HasMoreRows=1;
            ;WITH [R] AS
            (
                SELECT [rn]=ROW_NUMBER() OVER(ORDER BY CASE WHEN @Sortierung='CPU' THEN COALESCE([RequestCpuMs],[SessionCpuMs]) END DESC,CASE WHEN @Sortierung='READS' THEN COALESCE([RequestLogicalReads],[SessionLogicalReads]) END DESC,CASE WHEN @Sortierung='WRITES' THEN COALESCE([RequestWrites],[SessionWrites]) END DESC,CASE WHEN @Sortierung='LOGIN' THEN DATEDIFF_BIG(SECOND,'20000101',[LoginTime]) END DESC,[SessionId]),*
                FROM [#CurrentSessions_Result]
            )
            DELETE FROM [R] WHERE [rn]>@MaxZeilen;
        END;

        DECLARE @TruncatedValueCount bigint=0,@LargestRequiredCharacters bigint=NULL;
        DECLARE @ColumnTruncatedCount bigint=0,@ColumnLargestCharacters bigint=NULL;
        EXEC [monitor].[InternalProjectUnicodeTextColumn]
              @SourceTable=N'#CurrentSessions_Result',@TextColumn=N'CurrentStatement'
            , @CharactersColumn=N'CurrentStatementCharacters',@BytesColumn=N'CurrentStatementBytes'
            , @IsTruncatedColumn=N'CurrentStatementIsTruncated',@MaxCharacters=@MaxSqlTextZeichen
            , @TruncatedValueCount=@ColumnTruncatedCount OUTPUT,@LargestRequiredCharacters=@ColumnLargestCharacters OUTPUT;
        SELECT @TruncatedValueCount=@TruncatedValueCount+@ColumnTruncatedCount,
               @LargestRequiredCharacters=CASE WHEN @LargestRequiredCharacters IS NULL OR @ColumnLargestCharacters>@LargestRequiredCharacters THEN @ColumnLargestCharacters ELSE @LargestRequiredCharacters END;
        EXEC [monitor].[InternalProjectUnicodeTextColumn]
              @SourceTable=N'#CurrentSessions_Result',@TextColumn=N'BatchText'
            , @CharactersColumn=N'BatchTextCharacters',@BytesColumn=N'BatchTextBytes'
            , @IsTruncatedColumn=N'BatchTextIsTruncated',@MaxCharacters=@MaxSqlTextZeichen
            , @TruncatedValueCount=@ColumnTruncatedCount OUTPUT,@LargestRequiredCharacters=@ColumnLargestCharacters OUTPUT;
        SELECT @TruncatedValueCount=@TruncatedValueCount+@ColumnTruncatedCount,
               @LargestRequiredCharacters=CASE WHEN @LargestRequiredCharacters IS NULL OR @ColumnLargestCharacters>@LargestRequiredCharacters THEN @ColumnLargestCharacters ELSE @LargestRequiredCharacters END;
        EXEC [monitor].[InternalEmitTruncationWarning]
              @TruncatedValueCount=@TruncatedValueCount,@ParameterName=N'@MaxSqlTextZeichen'
            , @ParameterValue=@MaxSqlTextZeichen,@LargestRequiredCharacters=@LargestRequiredCharacters
            , @PrintMeldungen=@PrintMeldungen;

        SELECT @RowCount=COUNT_BIG(*) FROM [#CurrentSessions_Result];
        IF @HasFullView=0 OR @ParentSnapshotIsPartial=1
        BEGIN
            SET @StatusCode='AVAILABLE_LIMITED';
            SET @IsPartial=1;
            SET @Detail=N'Mindestens eine Current-State-Quelle war nur eingeschränkt verfügbar.';
        END
        ELSE SET @Detail=N'Current-State-Sessions aus einer frischen laufinternen Evidenzbasis gelesen.';
    END TRY
    BEGIN CATCH
        SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();SET @IsPartial=1;
        SET @StatusCode=CASE WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(207,208,4121) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END;
    END CATCH;

    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE')
    BEGIN
        SET @MonitorPrintMessage=FORMATMESSAGE(N'WARNUNG %s: %s',@StatusCode,COALESCE(@ErrorMessage,@Detail,N'eingeschränkte Sicht'));
        RAISERROR(N'%s',10,1,@MonitorPrintMessage) WITH NOWAIT;
    END;

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=(SELECT @ModuleName AS [resultName], 3 AS [schemaVersion],@CollectionTimeUtc AS [generatedAtUtc],@EvidenceSnapshotStartedAtUtc AS [evidenceSnapshotStartedAtUtc],@ParentCurrentStateSnapshotId AS [evidenceSnapshotId],@StatusCode AS [statusCode],@IsPartial AS [isPartial],@ErrorNumber AS [errorNumber],@MaxZeilen AS [requestedMaxRows],@RowCount AS [returnedRows],@HasMoreRows AS [hasMoreRows],@ToolHintergrundabfragenEinbeziehen AS [toolBackgroundQueriesIncluded] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @SessionsJson nvarchar(max)=(SELECT [r].*,[wi].[WaitGroup] AS [waitGroup],[wi].[Severity] AS [waitSeverity],[wi].[Meaning] AS [waitMeaning] FROM [#CurrentSessions_Result] AS [r] CROSS APPLY [monitor].[TVF_WaitTypeInfo]([r].[WaitType]) AS [wi] ORDER BY [SessionId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@MetaJson,N'{}'),N',"sessions":',COALESCE(@SessionsJson,N'[]'),N',"warnings":',CASE WHEN @ErrorMessage IS NULL AND @Detail IS NULL THEN N'[]' ELSE (SELECT @StatusCode AS [code],COALESCE(@ErrorMessage,@Detail) AS [message] FOR JSON PATH,INCLUDE_NULL_VALUES) END,N'}');
    END;

    IF @ResultSetArtNormalisiert='RAW'
    BEGIN
        SELECT @ModuleName AS [ModuleName],@CollectionTimeUtc AS [CollectionTimeUtc],@EvidenceSnapshotStartedAtUtc AS [EvidenceSnapshotStartedAtUtc],@ParentCurrentStateSnapshotId AS [EvidenceSnapshotId],@StatusCode AS [StatusCode],@IsPartial AS [IsPartial],@RowCount AS [RowCount],@MaxZeilen AS [RequestedMaxRows],@HasMoreRows AS [HasMoreRows],@RequiredPermission AS [RequiredPermission],@ErrorNumber AS [ErrorNumber],@ErrorMessage AS [ErrorMessage],@Detail AS [Detail];
        SELECT [r].*,[wi].[WaitGroup],[wi].[Severity] AS [WaitSeverity],[wi].[IsGenerallyBenign],[wi].[Meaning] AS [WaitMeaning],[wi].[TypicalOccurrence] AS [WaitTypicalOccurrence],[wi].[HighWaitImpact],[wi].[RecommendedChecks],[wi].[HelpUrl] AS [WaitHelpUrl],[wi].[InterpretationScope],[wi].[CatalogMatchType]
        FROM [#CurrentSessions_Result] AS [r] CROSS APPLY [monitor].[TVF_WaitTypeInfo]([r].[WaitType]) AS [wi]
        ORDER BY CASE WHEN @Sortierung='CPU' THEN COALESCE([RequestCpuMs],[SessionCpuMs]) END DESC,CASE WHEN @Sortierung='READS' THEN COALESCE([RequestLogicalReads],[SessionLogicalReads]) END DESC,CASE WHEN @Sortierung='WRITES' THEN COALESCE([RequestWrites],[SessionWrites]) END DESC,CASE WHEN @Sortierung='LOGIN' THEN DATEDIFF_BIG(SECOND,'20000101',[LoginTime]) END DESC,[SessionId];
    END
    ELSE IF @ResultSetArtNormalisiert='CONSOLE'
    BEGIN
        SELECT N'Modulstatus' AS [Ergebnis],@ModuleName AS [Modul],@StatusCode AS [Status],CASE WHEN @IsPartial=1 THEN N'Ja' ELSE N'Nein' END AS [Teilergebnis],@RowCount AS [Zeilen],@Detail AS [Hinweis],@ErrorMessage AS [Fehler];
        SELECT N'Aktuelle Session' AS [Ergebnis],[SessionId] AS [Session],[RequestId] AS [Request],[LoginName] AS [Login],[HostName] AS [Host],[ProgramName] AS [Programm],[DatabaseName] AS [Datenbank],[SessionStatus] AS [Sessionstatus],[RequestStatus] AS [Requeststatus],CONCAT(CONVERT(decimal(19,2),COALESCE([RequestElapsedMs],0)/1000.0),N' s') AS [Laufzeit],COALESCE([RequestCpuMs],[SessionCpuMs]) AS [CPU_ms],COALESCE([RequestLogicalReads],[SessionLogicalReads]) AS [Logical_Reads],COALESCE([RequestWrites],[SessionWrites]) AS [Writes],[SessionId] AS [Session_Wait],[WaitType] AS [Wait],[WaitTimeMs] AS [Wait_ms],[BlockingSessionId] AS [Blockiert_durch],[CurrentStatement] AS [Aktuelles_Statement]
        FROM [#CurrentSessions_Result]
        ORDER BY CASE WHEN @Sortierung='CPU' THEN COALESCE([RequestCpuMs],[SessionCpuMs]) END DESC,CASE WHEN @Sortierung='READS' THEN COALESCE([RequestLogicalReads],[SessionLogicalReads]) END DESC,CASE WHEN @Sortierung='WRITES' THEN COALESCE([RequestWrites],[SessionWrites]) END DESC,[SessionId];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#CurrentSessions_Result'
            , @ResultLabel=N'Aktuelle Sessions'
            , @EmptyMessage=N'Keine aktiven Sessions';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#CurrentSessions_Result'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO


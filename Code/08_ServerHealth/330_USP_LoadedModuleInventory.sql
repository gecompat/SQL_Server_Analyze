USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_LoadedModuleInventory
Version      : 1.0.0
Stand        : 2026-11-14
Zweck        : Inventarisiert native Metadaten der in den SQL-Server-Prozess
               geladenen Module zum Aufnahmezeitpunkt.
Quelle       : sys.dm_os_loaded_modules.
Datenschutz  : ModuleName enthaelt den unveraenderten nativen DMV-Namen
               einschliesslich moeglichem Pfad; Laufzeitwerte werden nicht als
               Repository-Artefakte gespeichert. BaseAddress, Company und
               Description werden fachlich nicht gelesen.
Grenze       : Kein Host-, Filtertreiber-, Signatur-, Malware- oder Gesundheitsurteil.
Nebenwirkung : Nur lesender DMV-Zugriff im Caller-Kontext; keine Modulaktion.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_LoadedModuleInventory]
      @NurBuildFlags bit = 0
    , @MaxZeilen int = 1000
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
    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
    DECLARE @OriginalXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END;
    DECLARE @LockTimeoutSql nvarchar(100);
    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),
            @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
            @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0
                               THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END,
            @Observed bigint=NULL,@Matched bigint=NULL,@Returned bigint=NULL,
            @SourceStatus varchar(40)='SOURCE_UNAVAILABLE',
            @SourceState varchar(16)='NOT_STARTED',
            @SourceError int=NULL,
            @Status varchar(40)='ERROR_HANDLED',
            @Error int=NULL,@Message nvarchar(2048)=NULL,
            @TableStatus varchar(40),@TableMessage nvarchar(2048),@TableError int,
            @TechnicalError int=NULL,@ResultName sysname,@TargetTable sysname,
            @SourceTable sysname,@GroupOrdinal int=1;
    DECLARE @ConsoleRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_LoadedModuleInventory';
        PRINT N'Ein SQL-Prozess-Snapshot aus sys.dm_os_loaded_modules. ModuleName ist der unveraenderte native DMV-Name einschliesslich moeglichem Pfad; ModuleBasename ist eine zusaetzliche Komfortprojektion. Keine Host- oder Filtertreiberinventur und keine Signatur-, Vertrauens-, Malware- oder Gesundheitsbewertung.';
        PRINT N'SQL Server 2019 benötigt für die DMV VIEW SERVER STATE; SQL Server 2022 und neuer VIEW SERVER PERFORMANCE STATE. Die Procedure erteilt keine Rechte und führt als Caller aus.';
        PRINT N'@NurBuildFlags bit; Default: 0. 0 gibt alle projizierbaren DMV-Zeilen aus, 1 nur Zeilen mit mindestens einem nativen Flag debug, patched, prerelease, private_build oder special_build = 1. NULL ist im normalen Pfad INVALID_PARAMETER. Numerische 0 wird 0, andere bitkonvertierbare Nichtnullwerte werden 1. Die Flag-Auswahl folgt erst auf den vollständigen DMV-Read und bezeichnet kein Risiko.';
        PRINT N'@MaxZeilen int; Default: 1000. NULL oder 0 bedeuten unbegrenzte Ausgabe; negative Werte sind INVALID_PARAMETER. Positive Werte 1 bis 2147483647 begrenzen nur die nach allen öffentlich ausgegebenen Fachfeldern sortierte loadedModules-Ausgabe nach vollständigem Quellenread und Flag-Auswahl. Leertext ist keine eigene int-Eingabeform; SQL Server konvertiert ihn vor dem Aufruf.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. SQL Server bindet oder kuerzt auf varchar(16) vor der Validierung. Nach aeusserem U+0020-Trimmen und UPPER sind CONSOLE, RAW, TABLE und NONE zulaessig; NULL und leer sind INVALID_PARAMETER. RAW gibt moduleStatus, loadedModules, sourceStatus und warnings in dieser Reihenfolge aus; TABLE schreibt benannte Gruppen in Caller-Temp-Tabellen; CONSOLE liefert eine formatierte Fachmenge; NONE liefert keine Fachresultsets. Optionales JSON ist unabhaengig davon.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE: nichtleeres JSON-Objekt mit mindestens einem exakt geschriebenen Schluessel moduleStatus, loadedModules, sourceStatus oder warnings. Werte sind unqualifizierte lokale #Temp-Namen, weder ## noch #Monitor; Konvertierung zu sysname erfolgt vor der Pruefung, Laenge danach hoechstens 116 Zeichen. Gruppen sind binaer verschieden, Ziele case-insensitiv verschieden. Jedes Ziel existiert leer mit genau einer beliebigen Seed-Spalte. Teilmapping ist erlaubt. NULL, leer oder nur U+0020 sind ausserhalb TABLE ohne Wirkung; andere Werte INVALID_PARAMETER. Preflightfehler vor DMV-Read sind INVALID_PARAMETER; spaetere Writerfehler sind technisch und koennen fruehere Zielschreibungen belassen.';
        PRINT N'@JsonErzeugen bit; Default: 0. 1 erzeugt unabhängig von ResultSetArt JSON mit meta und vier benannten Arrays, 0 keines; NULL ist INVALID_PARAMETER. Numerische 0 wird 0, andere bitkonvertierbare Nichtnullwerte werden 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optional an eine nvarchar(max)-Variable mit OUTPUT binden; der Eingangswert wird auf NULL zurückgesetzt. Normale Läufe mit JsonErzeugen=1 liefern JSON; Hilfe, direkte Parameterfehler und technische Ausgabefehler liefern NULL. Eine behandelte DMV-Störung kann ein JSON mit Quellenstatus und leeren Fachzeilen liefern.';
        PRINT N'@PrintMeldungen bit; Default: 1. 1 gibt zusaetzliche Severity-10-Meldungen mit dem nativen beziehungsweise Framework-Fehlertext aus, 0 keine; NULL ist im normalen Pfad INVALID_PARAMETER. Numerische 0 wird 0, andere bitkonvertierbare Nichtnullwerte werden 1. Hilfe-PRINT bleibt unabhaengig.';
        PRINT N'@Hilfe bit; Default: 0. 1 gibt Hilfe vor Parametervalidierung, TABLE-Preflight und DMV-Read aus und kehrt mit 0, Status AVAILABLE und IsPartial 0 zurueck; auch in einer Callertransaktion. 0 fuehrt die Analyse aus, NULL ist INVALID_PARAMETER. Normale Aufnahme verlangt @@TRANCOUNT=0 und IMPLICIT_TRANSACTIONS OFF; bei Verletzung INVALID_PARAMETER 51011 ohne Quellenread. Andere bitkonvertierbare Nichtnullwerte werden 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optional an varchar(40) mit OUTPUT binden; Eingang wird zurückgesetzt. AVAILABLE nur Hilfe; AVAILABLE_LIMITED erfolgreiche nichtleere Momentaufnahme; EMPTY_UNPROVEN erfolgreicher leerer DMV-Read; DENIED_PERMISSION tatsächlicher Rechtefehler; UNAVAILABLE_OBJECT fehlende DMV; ERROR_HANDLED sonstiger Quellen-/Technikfehler; INVALID_PARAMETER ungültige Eingabe.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optional an bit mit OUTPUT binden; Eingang wird zurückgesetzt. Hilfe 0; jeder normale Lauf und Fehlerpfad 1. Partialität bezeichnet die Momentaufnahme und die Aussagegrenze zum Host.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optional an int mit OUTPUT binden; Eingang wird zurückgesetzt. Hilfe und erfolgreicher Read NULL; ungültige Eingabe 51011; behandelte Quellenfehler ihre native SQL-Fehlernummer; technische Fehler deren tatsächliche oder Writer-Fehlernummer.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optional an nvarchar(2048) mit OUTPUT binden; Eingang wird zurueckgesetzt. Erfolg NULL; native Quellen- und Technikfehler liefern den auf 2048 Zeichen begrenzten ERROR_MESSAGE-Text, TABLE-Helfer ihren begrenzten Fehlertext. Laufzeittexte koennen Pfade enthalten und gehoeren nicht ungeprueft in Repository-Artefakte.';
        PRINT N'EXEC [monitor].[USP_LoadedModuleInventory] @NurBuildFlags=0,@MaxZeilen=100,@ResultSetArt=''RAW'';';
        PRINT N'DECLARE @j nvarchar(max); EXEC [monitor].[USP_LoadedModuleInventory] @ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@j OUTPUT; SELECT @j AS [Json];';
        PRINT N'CREATE TABLE #LoadedModuleExample([Seed] int NULL); EXEC [monitor].[USP_LoadedModuleInventory] @ResultSetArt=''TABLE'',@ResultTablesJson=N''{"loadedModules":"#LoadedModuleExample"}''; SELECT * FROM #LoadedModuleExample;';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN 0;
    END;

    IF @Hilfe IS NULL OR @NurBuildFlags IS NULL OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
       OR @Mode NOT IN('CONSOLE','RAW','TABLE','NONE') OR @MaxZeilen<0
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
       OR @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorNumberOut=51011,
               @ErrorMessageOut=N'Ungueltiger Filter-, Ausgabe-, Limit- oder Callertransaktionszustand.';
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@ErrorMessageOut) WITH NOWAIT;
        RETURN 51011;
    END;

    BEGIN TRY
        SET XACT_ABORT OFF;
        CREATE TABLE [#LoadedModuleInventory_moduleStatus]
        (
            [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [CapturedAtUtc] datetime2(3) NOT NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsPartial] bit NOT NULL,
            [RowCount] bigint NOT NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#LoadedModuleInventory_loadedModules]
        (
            [ModuleName] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ModuleBasename] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [FileVersion] varchar(23) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ProductVersion] varchar(23) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Debug] bit NULL,[Patched] bit NULL,[Prerelease] bit NULL,
            [PrivateBuild] bit NULL,[SpecialBuild] bit NULL,
            [Language] int NULL
        );
        CREATE TABLE [#LoadedModuleInventory_Raw]
        (
            [ModuleName] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ModuleBasename] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [FileVersion] varchar(23) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ProductVersion] varchar(23) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Debug] bit NULL,[Patched] bit NULL,[Prerelease] bit NULL,
            [PrivateBuild] bit NULL,[SpecialBuild] bit NULL,
            [Language] int NULL
        );
        CREATE TABLE [#LoadedModuleInventory_Matched]
        (
            [ModuleName] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ModuleBasename] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [FileVersion] varchar(23) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ProductVersion] varchar(23) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Debug] bit NULL,[Patched] bit NULL,[Prerelease] bit NULL,
            [PrivateBuild] bit NULL,[SpecialBuild] bit NULL,
            [Language] int NULL
        );
        CREATE TABLE [#LoadedModuleInventory_sourceStatus]
        (
            [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [CapturedAtUtc] datetime2(3) NOT NULL,
            [NativeReadState] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [ObservedRows] bigint NULL,[MatchedRows] bigint NULL,[ReturnedRows] bigint NULL,
            [IsLimited] bit NOT NULL,[ErrorNumber] int NULL,
            [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#LoadedModuleInventory_warnings]
        (
            [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#LoadedModuleInventory_Map]
        (
            [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#LoadedModuleInventory_Console]
        (
            [Bereich] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [Objekt] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );

        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables]
                @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|loadedModules|sourceStatus|warnings',
                @MappingTable=N'#LoadedModuleInventory_Map',
                @StatusCode=@TableStatus OUTPUT,
                @ErrorMessage=@TableMessage OUTPUT,
                @ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE'
            BEGIN
                SET @TechnicalError=51011;
                RAISERROR(N'Ungueltiges TABLE-Ziel fuer LoadedModuleInventory.',16,1);
            END;
        END;

        BEGIN TRY
            INSERT [#LoadedModuleInventory_Raw]
                ([ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
                 [Prerelease],[PrivateBuild],[SpecialBuild],[Language])
            SELECT [m].[name],CASE WHEN [b].[BaseName] IS NULL
                          OR NULLIF(LTRIM(RTRIM([b].[BaseName])),N'') IS NULL
                          OR CHARINDEX(N':',[b].[BaseName])>0
                        THEN NULL ELSE [b].[BaseName] END,
                   [m].[file_version],[m].[product_version],[m].[debug],[m].[patched],
                   [m].[prerelease],[m].[private_build],[m].[special_build],
                   [m].[language]
            FROM [sys].[dm_os_loaded_modules] AS [m] WITH (NOLOCK)
            CROSS APPLY
            (
                SELECT RIGHT([m].[name],
                    CHARINDEX(N'\',REVERSE(REPLACE([m].[name],N'/',N'\'))+N'\')-1)
                    AS [BaseName]
            ) AS [b];
            SET @Observed=@@ROWCOUNT;
            SET @SourceState='SUCCEEDED';
            SET @SourceStatus=CASE WHEN @Observed=0 THEN 'EMPTY_UNPROVEN' ELSE 'AVAILABLE_LIMITED' END;
        END TRY
        BEGIN CATCH
            SET @SourceError=ERROR_NUMBER();
            SET @Message=LEFT(ERROR_MESSAGE(),2048);
            SET @SourceState='FAILED';
            SET @SourceStatus=CASE WHEN @SourceError IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                                   WHEN @SourceError IN(207,208) THEN 'UNAVAILABLE_OBJECT'
                                   ELSE 'ERROR_HANDLED' END;
            SET @Observed=NULL;
        END CATCH;

        IF @SourceState='SUCCEEDED'
        BEGIN
            INSERT [#LoadedModuleInventory_Matched]
                ([ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
                 [Prerelease],[PrivateBuild],[SpecialBuild],[Language])
            SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
                   [Prerelease],[PrivateBuild],[SpecialBuild],[Language]
            FROM [#LoadedModuleInventory_Raw]
            WHERE @NurBuildFlags=0 OR [Debug]=1 OR [Patched]=1 OR [Prerelease]=1
                  OR [PrivateBuild]=1 OR [SpecialBuild]=1;
            SET @Matched=@@ROWCOUNT;
            INSERT [#LoadedModuleInventory_loadedModules]
                ([ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
                 [Prerelease],[PrivateBuild],[SpecialBuild],[Language])
            SELECT TOP(@Limit) [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],
                   [Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language]
            FROM [#LoadedModuleInventory_Matched]
            ORDER BY [ModuleName] COLLATE Latin1_General_100_BIN2,
                     [ModuleBasename] COLLATE Latin1_General_100_BIN2,
                     [FileVersion] COLLATE Latin1_General_100_BIN2,
                     [ProductVersion] COLLATE Latin1_General_100_BIN2,
                     [Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language];
            SET @Returned=@@ROWCOUNT;
            SET @Status=@SourceStatus;
        END
        ELSE
        BEGIN
            SET @Status=@SourceStatus;
            SET @Error=@SourceError;
        END;

        INSERT [#LoadedModuleInventory_sourceStatus]
            ([SourceKey],[SourceKind],[CapturedAtUtc],[NativeReadState],[StatusCode],
             [ObservedRows],[MatchedRows],[ReturnedRows],[IsLimited],[ErrorNumber],[ErrorMessage])
        VALUES('SYS_DM_OS_LOADED_MODULES','DMV',@CapturedAtUtc,@SourceState,@SourceStatus,
               @Observed,@Matched,@Returned,
               CASE WHEN @Matched IS NOT NULL AND @Returned<@Matched THEN 1 ELSE 0 END,
               @SourceError,@Message);
        INSERT [#LoadedModuleInventory_warnings]
        VALUES('SQL_PROCESS_ONLY','SYS_DM_OS_LOADED_MODULES',
               N'Nur Module im SQL-Server-Adressraum zum Aufnahmezeitpunkt; keine Host- oder Filtertreiberinventur.');
        INSERT [#LoadedModuleInventory_warnings]
        VALUES('NATIVE_NAME_IN_RUNTIME','SYS_DM_OS_LOADED_MODULES',
               N'ModuleName ist der native DMV-Name und kann einen vollstaendigen Pfad enthalten; Export vor Speicherung pruefen.');
        IF @SourceState='SUCCEEDED' AND EXISTS
            (SELECT 1 FROM [#LoadedModuleInventory_Raw] WHERE [ModuleBasename] IS NULL)
            INSERT [#LoadedModuleInventory_warnings]
            VALUES('BASENAME_UNAVAILABLE','SYS_DM_OS_LOADED_MODULES',
                   N'Mindestens ein nativer Name lieferte keinen eindeutigen pfadfreien Basenamen.');
        IF @SourceState='SUCCEEDED' AND EXISTS
            (SELECT 1 FROM [#LoadedModuleInventory_Raw]
             WHERE [Debug] IS NULL OR [Patched] IS NULL OR [Prerelease] IS NULL
                OR [PrivateBuild] IS NULL OR [SpecialBuild] IS NULL)
            INSERT [#LoadedModuleInventory_warnings]
            VALUES('BUILD_FLAG_UNKNOWN','SYS_DM_OS_LOADED_MODULES',
                   N'Mindestens ein natives Build-Flag ist NULL; die Flag-Auswahl wertet nur explizite Einsen.');

        INSERT [#LoadedModuleInventory_moduleStatus]
        VALUES(N'USP_LoadedModuleInventory',@CapturedAtUtc,@Status,1,COALESCE(@Returned,0),
               N'Begrenzte SQL-Prozess-Momentaufnahme; kein Host-, Filtertreiber-, Signatur- oder Gesundheitsurteil.');

        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=
                (SELECT N'LoadedModuleInventory' AS [resultName],1 AS [schemaVersion],
                        @CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],
                        CAST(1 AS bit) AS [isPartial],@Error AS [errorNumber],
                        @Message AS [errorMessage]
                 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=
                (SELECT * FROM [#LoadedModuleInventory_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_loadedModules nvarchar(max)=
                (SELECT * FROM [#LoadedModuleInventory_loadedModules]
                 ORDER BY [ModuleName] COLLATE Latin1_General_100_BIN2,
                     [ModuleBasename] COLLATE Latin1_General_100_BIN2,
                          [FileVersion] COLLATE Latin1_General_100_BIN2,
                          [ProductVersion] COLLATE Latin1_General_100_BIN2,
                          [Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language]
                 FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=
                (SELECT * FROM [#LoadedModuleInventory_sourceStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=
                (SELECT * FROM [#LoadedModuleInventory_warnings] ORDER BY [WarningCode]
                 FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,
                N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),
                N',"loadedModules":',COALESCE(@Json_loadedModules,N'[]'),
                N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),
                N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;

        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#LoadedModuleInventory_moduleStatus];
            SELECT * FROM [#LoadedModuleInventory_loadedModules]
            ORDER BY [ModuleName] COLLATE Latin1_General_100_BIN2,
                     [ModuleBasename] COLLATE Latin1_General_100_BIN2,
                     [FileVersion] COLLATE Latin1_General_100_BIN2,
                     [ProductVersion] COLLATE Latin1_General_100_BIN2,
                     [Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language];
            SELECT * FROM [#LoadedModuleInventory_sourceStatus];
            SELECT * FROM [#LoadedModuleInventory_warnings] ORDER BY [WarningCode];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            WHILE @GroupOrdinal<=4
            BEGIN
                SET @ResultName=CASE @GroupOrdinal WHEN 1 THEN N'moduleStatus'
                                    WHEN 2 THEN N'loadedModules'
                                    WHEN 3 THEN N'sourceStatus' ELSE N'warnings' END;
                SELECT @TargetTable=[TargetTable] FROM [#LoadedModuleInventory_Map]
                WHERE [ResultName]=@ResultName;
                IF @TargetTable IS NOT NULL
                BEGIN
                    SET @SourceTable=N'#LoadedModuleInventory_'+@ResultName;
                    EXEC [monitor].[InternalWriteResultTable]
                        @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                        @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,
                        @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                    IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                    BEGIN
                        SET @TechnicalError=COALESCE(@TableError,51010);
                        RAISERROR(N'LoadedModuleInventory TABLE-Ausgabe fehlgeschlagen.',16,1);
                    END;
                END;
                SET @TargetTable=NULL;
                SET @GroupOrdinal+=1;
            END;
        END
        ELSE IF @ConsoleRequested=1
        BEGIN
            INSERT [#LoadedModuleInventory_Console]
            SELECT N'Geladenes Modul',[ModuleName],
                   CONCAT(N'Basename=',COALESCE([ModuleBasename],N'NULL'),
                          N'; Dateiversion=',COALESCE(CONVERT(nvarchar(23),[FileVersion]),N'NULL'),
                          N'; Produktversion=',COALESCE(CONVERT(nvarchar(23),[ProductVersion]),N'NULL'),
                          N'; Buildflags=',COALESCE(CONVERT(nvarchar(1),[Debug]),N'NULL'),N'/',
                          COALESCE(CONVERT(nvarchar(1),[Patched]),N'NULL'),N'/',
                          COALESCE(CONVERT(nvarchar(1),[Prerelease]),N'NULL'),N'/',
                          COALESCE(CONVERT(nvarchar(1),[PrivateBuild]),N'NULL'),N'/',
                          COALESCE(CONVERT(nvarchar(1),[SpecialBuild]),N'NULL'),
                          N'; Sprache=',COALESCE(CONVERT(nvarchar(20),[Language]),N'NULL'))
            FROM [#LoadedModuleInventory_loadedModules]
            ORDER BY [ModuleName] COLLATE Latin1_General_100_BIN2,
                     [ModuleBasename] COLLATE Latin1_General_100_BIN2,
                     [FileVersion] COLLATE Latin1_General_100_BIN2,
                     [ProductVersion] COLLATE Latin1_General_100_BIN2,
                     [Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language];
            INSERT [#LoadedModuleInventory_Console]
            SELECT N'Quelle',N'sys.dm_os_loaded_modules',
                   CONCAT([StatusCode],N'; beobachtet=',
                          COALESCE(CONVERT(nvarchar(30),[ObservedRows]),N'NULL'),
                          N'; nach Flag-Auswahl=',COALESCE(CONVERT(nvarchar(30),[MatchedRows]),N'NULL'),
                          N'; ausgegeben=',COALESCE(CONVERT(nvarchar(30),[ReturnedRows]),N'NULL'))
            FROM [#LoadedModuleInventory_sourceStatus];
            INSERT [#LoadedModuleInventory_Console]
            SELECT N'Aussagegrenze',[WarningCode],[Detail]
            FROM [#LoadedModuleInventory_warnings];
            EXEC [monitor].[InternalEmitConsoleResult]
                @SourceTable=N'#LoadedModuleInventory_Console',
                @ResultLabel=N'Geladene SQL-Prozessmodule',
                @EmptyMessage=N'Keine projizierte Modulzeile; Quellenstatus und Filter pruefen.';
        END;

        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL
            RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @LockTimeoutSql;
        IF @OriginalXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        RETURN 0;
    END TRY
    BEGIN CATCH
        SELECT @Error=COALESCE(@TechnicalError,ERROR_NUMBER()),
               @Message=LEFT(CASE WHEN @TechnicalError IS NOT NULL THEN COALESCE(@TableMessage,ERROR_MESSAGE())
                                   ELSE ERROR_MESSAGE() END,2048),
               @Json=NULL;
        SELECT @StatusCodeOut=CASE WHEN @TechnicalError=51011 THEN 'INVALID_PARAMETER' ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @LockTimeoutSql;
        IF @OriginalXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO

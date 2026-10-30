USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ServerVersionInformation
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Stored Procedure
Zweck        : Liefert Instanzversion, Offline-Buildbewertung, Lifecycle,
               Featureflags und optional sichtbaren Datenbank-Kompatibilitäts-
               kontext mit expliziter Provenienz und Evidenzgrenzen.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : SERVERPROPERTY, sys.dm_os_sys_info, sys.dm_os_host_info,
               master.sys.databases sowie monitor.SqlServer*Catalog.
Eigenlast    : Gering; kein Plan-Cache-, Query-Store- oder Benutzerdatenzugriff.
Datenschutz  : Normale Ausgabe enthält keine Server-, Host-, Instanz-, Konto-
               oder Pfadidentität. Datenbanknamen erscheinen nur im explizit
               aktivierten Kompatibilitätsresultset.
Grenze       : Offline-Katalog; kein Vulnerability-, Neustart-, Lizenz- oder
               betrieblicher Freigabenachweis.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ServerVersionInformation]
      @MitDatenbankKompatibilitaet bit            = 0
    , @DatabaseNames                nvarchar(max)  = NULL
    , @DatabaseNamePattern          nvarchar(4000) = NULL
    , @SystemdatenbankenEinbeziehen bit            = 0
    , @MaxZeilen                    int            = 2000
    , @ResultSetArt                 varchar(16)    = 'CONSOLE'
    , @ResultTablesJson             nvarchar(max)  = NULL
    , @JsonErzeugen                 bit            = 0
    , @Json                         nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen               bit            = 1
    , @Hilfe                        bit            = 0
    , @StatusCodeOut                varchar(40)    = NULL OUTPUT
    , @IsPartialOut                 bit            = NULL OUTPUT
    , @ErrorNumberOut               int            = NULL OUTPUT
    , @ErrorMessageOut              nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;

    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME();
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ConsoleResultRequested bit=CASE WHEN UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))))='CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @StatusCode varchar(40)='AVAILABLE';
    DECLARE @IsPartial bit=0;
    DECLARE @ErrorNumber int=NULL;
    DECLARE @ErrorMessage nvarchar(2048)=NULL;
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0
                               THEN CONVERT(bigint,9223372036854775807)
                               ELSE CONVERT(bigint,@MaxZeilen) END;

    IF @Hilfe=1
    BEGIN
        PRINT N'Die Procedure ordnet aktuellen Build, offline mitgelieferten Servicing-Katalog und Lifecycle getrennt ein. Sie führt keinen Onlinezugriff aus.';
        PRINT N'@DatabaseNames ist eine bracket-aware Pipe-Liste: | trennt außerhalb von [...], ]] maskiert ], Pipe innerhalb von [...] bleibt Bestandteil; nur einteilige SQL-Namen.';
        PRINT N'@ResultSetArt: CONSOLE=Build-/Lifecyclezusammenfassung, RAW=sieben Resultsets, TABLE=gemappte Resultsetziele, NONE=keine fachlichen Resultsets.';
        PRINT N'CONSOLE verdichtet zu einer Zeile. Die sieben Resultsets heißen serverVersion, buildAssessment, lifecycle, instanceFeatures, databaseCompatibility, references und warnings. JSON verwendet gleichnamige Arrays unter meta.';
        PRINT N'@ResultTablesJson wird bei TABLE als eindeutige Zuordnung dieser sieben Schlüssel zu vorhandenen leeren lokalen #Temp-Tabellen geprüft; ein leeres Einspalten-Dummyziel kann der Writer anpassen. Mapping-Preflight kommt nach dem Help-Return.';
        PRINT N'databaseCompatibility ist opt-in. Bei @MitDatenbankKompatibilitaet=0 müssen @DatabaseNames und @DatabaseNamePattern NULL bleiben; der Systemdatenbankwert muss dennoch im normalen Aufruf nicht-NULL sein.';
        PRINT N'@MaxZeilen begrenzt ausschließlich databaseCompatibility; ein negativer Wert wird auch ohne aktivierte Compatibility-Ausgabe abgelehnt.';
        PRINT N'@Json wird gleich beim Eintritt auf NULL gesetzt. Help lässt Status-/Fehler-OUTPUT-Werte unverändert und liegt vor Tabellenmapping.';
        PRINT N'Der Offline-Katalog beweist weder vollständige Security-Patches, Verwundbarkeit, Neustartbedarf, Supportentitlement noch betriebliche Freigabe.';
        PRINT N'EXEC [monitor].[USP_ServerVersionInformation] @ResultSetArt=''CONSOLE'';';
        PRINT N'DECLARE @Status varchar(40), @Partial bit, @ErrNo int, @ErrMsg nvarchar(2048);';
        PRINT N'EXEC [monitor].[USP_ServerVersionInformation] @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@ErrNo OUTPUT, @ErrorMessageOut=@ErrMsg OUTPUT;';
        PRINT N'DECLARE @VersionJson nvarchar(max);';
        PRINT N'EXEC [monitor].[USP_ServerVersionInformation] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@VersionJson OUTPUT;';
        PRINT N'CREATE TABLE #ServerVersionInformation_HelpExample (Placeholder int NULL);';
        PRINT N'EXEC [monitor].[USP_ServerVersionInformation] @MitDatenbankKompatibilitaet=1, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"databaseCompatibility":"#ServerVersionInformation_HelpExample"}'';';
        PRINT N'@MitDatenbankKompatibilitaet (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. 1 aktiviert databaseCompatibility. 0 überspringt dessen Kandidatenpfad; dann müssen @DatabaseNames und @DatabaseNamePattern NULL bleiben, sonst INVALID_PARAMETER. NULL ist im normalen Pfad INVALID_PARAMETER. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.';
        PRINT N'@DatabaseNames (nvarchar(max); Default: NULL; ausgelassen = Default): Ausgelassen = NULL. Nur bei aktivierter Compatibility-Ausgabe ausgewertet; NULL bedeutet keine Listenbegrenzung, sonst bracket-aware Pipe-Liste einteiliger SQL-Namen (Pipe trennt nur außerhalb von [...], ]] maskiert ]). Wenn Compatibility deaktiviert ist, muss der Parameter NULL sein.';
        PRINT N'@DatabaseNamePattern (nvarchar(4000); Default: NULL; ausgelassen = Default): Ausgelassen = NULL. Nur bei aktivierter Compatibility-Ausgabe; alternativ zur Liste. Äußere Leerzeichen werden entfernt, Präfixe sind case-insensitiv: like: (SQL-LIKE), regex: (case-sensitive Regex, Flag c), regexi: (case-insensitive Regex, Flag i); ohne Präfix gilt SQL-LIKE. LIKE verwendet %, _ und SQL-Zeichenklassen [...] unter SQL_Latin1_General_CP1_CS_AS. Leerer Patterninhalt ist ungültig. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Bei deaktivierter Compatibility-Ausgabe muss der Wert NULL sein.';
        PRINT N'@SystemdatenbankenEinbeziehen (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. Nur bei aktivierter Compatibility-Ausgabe bewirkt 0 den Ausschluss und 1 die Zulassung von master, tempdb, model und msdb. NULL ist auch bei deaktivierter Compatibility-Ausgabe im normalen Pfad INVALID_PARAMETER. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.';
        PRINT N'@MaxZeilen (int; Default: 2000; ausgelassen = Default): Ausgelassen = 2000. NULL oder 0 bedeutet unbegrenzt; positiv begrenzt nur databaseCompatibility nach der Auswahl; negativ setzt INVALID_PARAMETER, auch wenn Compatibility deaktiviert ist.';
        PRINT N'@ResultSetArt (varchar(16); Default: CONSOLE; ausgelassen = Default): Ausgelassen = CONSOLE. Äußere Leerzeichen entfernen, großschreiben. Die vollständigen Werte sind CONSOLE (verdichtete Consolezeile), RAW (alle sieben technischen Resultsets), TABLE (gemappte Ziele) und NONE (keine fachlichen Resultsets). NULL, leer und andere Werte sind im normalen Pfad INVALID_PARAMETER.';
        PRINT N'@ResultTablesJson (nvarchar(max); Default: NULL; ausgelassen = Default): Ausgelassen = NULL. Nur TABLE erlaubt; ein JSON-Objekt mit eindeutiger Teilmenge der sieben exakten Schlüssel serverVersion, buildAssessment, lifecycle, instanceFeatures, databaseCompatibility, references und warnings. Jeder Schlüssel erhält ein vorhandenes lokales #Temp-Ziel; alle Ziele sind eindeutig und leer und die JSON-Zuordnung ist vor Quellenzugriff geprüft. Eine leere Einspalten-Dummytabelle kann der Writer an das Quellschema anpassen. Nicht-TABLE mit nichtleerem Mapping ist INVALID_PARAMETER. Der Help-RETURN liegt vor diesem Mapping-Preflight.';
        PRINT N'@JsonErzeugen (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. 1 erzeugt JSON unabhängig von ResultSetArt; 0 lässt JSON aus. NULL ist im normalen Pfad INVALID_PARAMETER. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.';
        PRINT N'@Json (nvarchar(max) OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter. Mit OUTPUT binden. Der Eingabewert wird gleich bei Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 enthält JSON meta und die benannten Ergebnisarrays. Hilfe lässt @Json bei NULL, nachdem es geleert wurde.';
        PRINT N'@PrintMeldungen (bit; Default: 1; ausgelassen = Default): Ausgelassen = 1. 1 gibt normale Warnmeldungen bei Status ungleich AVAILABLE aus; 0 unterdrückt sie. NULL ist im normalen Pfad INVALID_PARAMETER. Hilfe-PRINT bleibt aktiv. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.';
        PRINT N'@Hilfe (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. Nur 1 druckt Hilfe und kehrt vor Bewertung, normaler Parameter-/Filtervalidierung und TABLE-Mapping-Preflight zurück; 0 und NULL führen normal weiter. @Json ist davor bereits NULL; die Status-/Fehler-OUTPUT-Werte bleiben beim Help-RETURN unverändert. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.';
        PRINT N'@StatusCodeOut (varchar(40) OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Wird im normalen Abschluss mit dem tatsächlichen Modulstatus belegt. Die Procedure setzt unter anderem AVAILABLE, AVAILABLE_LIMITED und INVALID_PARAMETER; abgefangene Quellenfehler behalten ihren jeweiligen tatsächlichen Status. Beim Help-RETURN bleibt der übergebene Wert unverändert.';
        PRINT N'@IsPartialOut (bit OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Liefert im normalen Abschluss 0 für vollständige bzw. 1 für partielle Ausgabe. Beim Help-RETURN bleibt der übergebene Wert unverändert.';
        PRINT N'@ErrorNumberOut (int OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Liefert die tatsächlich abgefangene Fehlernummer oder NULL, wenn kein Fehler erfasst wurde. Beim Help-RETURN bleibt der übergebene Wert unverändert.';
        PRINT N'@ErrorMessageOut (nvarchar(2048) OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Liefert den tatsächlich erfassten Fehlertext oder NULL, wenn kein Fehler erfasst wurde. Beim Help-RETURN bleibt der übergebene Wert unverändert.';
        RETURN;
    END;

    CREATE TABLE [#ServerVersionInformation_ResultTableMap]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServerVersionInformation_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL
        , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsSystemDatabase] bit NULL
        , [RequestedOrdinal] int NULL
    );
    CREATE TABLE [#ServerVersionInformation_CandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServerVersionInformation_ServerVersion]
    (
          [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsCurrent] bit NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ProductVersion] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProductMajorVersion] int NULL
        , [ProductMinorVersion] int NULL
        , [ProductBuild] int NULL
        , [ProductRevision] int NULL
        , [ProductLevel] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProductUpdateLevel] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProductUpdateReference] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProductBuildType] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ResourceVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ResourceLastUpdateDateTime] datetime NULL
        , [BuildClrVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Edition] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EditionId] bigint NULL
        , [EngineEdition] int NULL
        , [EngineClass] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HostPlatform] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HostDistribution] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HostRelease] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HostServicePackLevel] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HostSku] int NULL
        , [OsLanguageVersion] int NULL
        , [SqlServerStartTimeUtc] datetime NULL
        , [UptimeMilliseconds] bigint NULL
        , [ProcessId] int NULL
        , [IsClustered] bit NULL
        , [IsHadrEnabled] bit NULL
        , [HadrManagerStatus] int NULL
        , [IsLocalDb] bit NULL
        , [ServerCollation] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [TempDbCollation] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServerVersionInformation_BuildAssessment]
    (
          [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AssessmentStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CatalogFreshnessStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ProductVersion] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [KnownReleaseName] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ServicingBranch] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [KnowledgeBaseNumber] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ReleaseDate] date NULL
        , [IsSecurityRelease] bit NULL
        , [LatestKnownBuildInBranch] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LatestKnownBuildForMajor] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CatalogAsOfDate] date NULL
        , [BuildOverviewUrl] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [KnowledgeBaseUrl] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServerVersionInformation_Lifecycle]
    (
          [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [LifecycleStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ProductMajorVersion] int NULL
        , [ProductName] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StartDate] date NULL
        , [MainstreamEndDate] date NULL
        , [ExtendedEndDate] date NULL
        , [LifecyclePolicy] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CatalogAsOfDate] date NULL
        , [LifecycleUrl] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServerVersionInformation_InstanceFeatures]
    (
          [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FeatureName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FeatureValue] int NULL
        , [ValueStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServerVersionInformation_DatabaseCompatibility]
    (
          [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsCurrent] bit NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CompatibilityLevel] tinyint NULL
        , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsReadOnly] bit NULL
        , [IsSystemDatabase] bit NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServerVersionInformation_References]
    (
          [ReferenceType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ProductMajorVersion] int NULL
        , [Title] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Url] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CatalogAsOfDate] date NOT NULL
    );
    CREATE TABLE [#ServerVersionInformation_Warnings]
    (
          [WarningOrdinal] bigint IDENTITY(1,1) NOT NULL
        , [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [ErrorNumber] int NULL
        , [Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServerVersionInformation_Console]
    (
          [Build] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Release] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ServicingBranch] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [BuildStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CatalogStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LifecycleStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MainstreamEndDate] date NULL
        , [ExtendedEndDate] date NULL
        , [LatestKnownBuildInBranch] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [BuildOverviewUrl] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ModuleStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
    );

    SET LOCK_TIMEOUT 0;

    IF @MitDatenbankKompatibilitaet IS NULL OR @SystemdatenbankenEinbeziehen IS NULL
       OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
       OR @MaxZeilen<0 OR @OutputMode NOT IN('CONSOLE','RAW','TABLE','NONE')
       OR (@MitDatenbankKompatibilitaet=0 AND (@DatabaseNames IS NOT NULL OR @DatabaseNamePattern IS NOT NULL))
       OR (@DatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL)
       OR (@OutputMode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,
               @ErrorMessage=N'Ungültiger Bit-, Zeilen-, Filter- oder Ausgabeparameter.';
    END;

    IF @StatusCode='AVAILABLE' AND @OutputMode='TABLE'
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'serverVersion|buildAssessment|lifecycle|instanceFeatures|databaseCompatibility|references|warnings'
            , @MappingTable=N'#ServerVersionInformation_ResultTableMap'
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @ThrowOnError=1;
    END;

    IF @StatusCode='AVAILABLE'
    BEGIN
        INSERT [#ServerVersionInformation_ServerVersion]
        SELECT
              'SERVERPROPERTY',N'SERVERPROPERTY',@CapturedAtUtc,'INSTANCE',CONVERT(bit,1),'AVAILABLE'
            , CONVERT(varchar(32),SERVERPROPERTY(N'ProductVersion'))
            , TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))
            , TRY_CONVERT(int,SERVERPROPERTY(N'ProductMinorVersion'))
            , TRY_CONVERT(int,SERVERPROPERTY(N'ProductBuild'))
            , TRY_CONVERT(int,PARSENAME(CONVERT(varchar(32),SERVERPROPERTY(N'ProductVersion')),1))
            , CONVERT(nvarchar(128),SERVERPROPERTY(N'ProductLevel'))
            , CONVERT(nvarchar(128),SERVERPROPERTY(N'ProductUpdateLevel'))
            , CONVERT(nvarchar(128),SERVERPROPERTY(N'ProductUpdateReference'))
            , CONVERT(nvarchar(128),SERVERPROPERTY(N'ProductBuildType'))
            , CONVERT(nvarchar(128),SERVERPROPERTY(N'ResourceVersion'))
            , TRY_CONVERT(datetime,SERVERPROPERTY(N'ResourceLastUpdateDateTime'))
            , CONVERT(nvarchar(128),SERVERPROPERTY(N'BuildClrVersion'))
            , CONVERT(nvarchar(128),SERVERPROPERTY(N'Edition'))
            , TRY_CONVERT(bigint,SERVERPROPERTY(N'EditionID'))
            , TRY_CONVERT(int,SERVERPROPERTY(N'EngineEdition'))
            , CASE TRY_CONVERT(int,SERVERPROPERTY(N'EngineEdition'))
                  WHEN 2 THEN 'STANDARD_CLASS' WHEN 3 THEN 'ENTERPRISE_CLASS'
                  WHEN 4 THEN 'EXPRESS_CLASS' WHEN 5 THEN 'AZURE_SQL_DATABASE'
                  WHEN 6 THEN 'SYNAPSE' WHEN 8 THEN 'AZURE_SQL_MI'
                  WHEN 9 THEN 'AZURE_SQL_EDGE' WHEN 11 THEN 'FABRIC_OR_SERVERLESS'
                  WHEN 12 THEN 'FABRIC_SQL_DATABASE' ELSE 'UNKNOWN_ENGINE_CLASS' END
            , NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
            , TRY_CONVERT(int,SERVERPROPERTY(N'ProcessID'))
            , TRY_CONVERT(bit,SERVERPROPERTY(N'IsClustered'))
            , TRY_CONVERT(bit,SERVERPROPERTY(N'IsHadrEnabled'))
            , TRY_CONVERT(int,SERVERPROPERTY(N'HadrManagerStatus'))
            , TRY_CONVERT(bit,SERVERPROPERTY(N'IsLocalDB'))
            , CONVERT(sysname,SERVERPROPERTY(N'Collation'))
            , (SELECT [d].[collation_name] FROM [master].[sys].[databases] AS [d] WITH (NOLOCK) WHERE [d].[database_id]=2)
            , N'Direkte Instanzeigenschaften und leichter OS-Kontext; keine Serveridentität, Pfade, Konten oder Lizenzbehauptung.';

        BEGIN TRY
            UPDATE [v]
            SET [HostPlatform]=[h].[host_platform],
                [HostDistribution]=[h].[host_distribution],
                [HostRelease]=[h].[host_release],
                [HostServicePackLevel]=[h].[host_service_pack_level],
                [HostSku]=[h].[host_sku],
                [OsLanguageVersion]=[h].[os_language_version],
                [SqlServerStartTimeUtc]=[o].[sqlserver_start_time],
                [UptimeMilliseconds]=[o].[ms_ticks]
            FROM [#ServerVersionInformation_ServerVersion] AS [v]
            CROSS JOIN [sys].[dm_os_host_info] AS [h] WITH (NOLOCK)
            CROSS JOIN [sys].[dm_os_sys_info] AS [o] WITH (NOLOCK);
        END TRY
        BEGIN CATCH
            INSERT [#ServerVersionInformation_Warnings]
            SELECT 'LIVE_DMV',N'sys.dm_os_host_info|sys.dm_os_sys_info',@CapturedAtUtc,
                   CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
                   CONVERT(bit,1),ERROR_NUMBER(),ERROR_MESSAGE(),
                   N'SERVERPROPERTY- und Offline-Katalogevidenz bleiben verfügbar; OS- und Startzeitkontext fehlt.';
            SET @IsPartial=1;
        END CATCH;

        INSERT [#ServerVersionInformation_BuildAssessment]
        SELECT
              'OFFLINE_CATALOG',N'monitor.SqlServerBuildCatalog',@CapturedAtUtc,'INSTANCE_BUILD'
            , CASE WHEN [v].[ProductLevel] LIKE N'CTP%' THEN 'PREVIEW_BUILD'
                   WHEN [v].[ProductBuildType]='OD' THEN 'ON_DEMAND_BUILD'
                   WHEN [exact].[BuildVersion] IS NOT NULL AND [exact].[IsLatestInBranch]=1 THEN 'EXACT_MATCH'
                   WHEN [exact].[BuildVersion] IS NOT NULL THEN 'OLDER_KNOWN_BUILD'
                   WHEN [latestMajor].[BuildVersion] IS NULL THEN 'UNKNOWN_BUILD'
                   WHEN [v].[ProductBuild]>[latestMajor].[BuildNumber]
                     OR ([v].[ProductBuild]=[latestMajor].[BuildNumber] AND [v].[ProductRevision]>[latestMajor].[RevisionNumber])
                     THEN 'BUILD_NEWER_THAN_OFFLINE_CATALOG'
                   ELSE 'UNKNOWN_BUILD' END
            , CASE WHEN DATEDIFF(DAY,[catalog].[CatalogAsOfDate],CONVERT(date,@CapturedAtUtc))>120 THEN 'CATALOG_STALE' ELSE 'CATALOG_CURRENT' END
            , [v].[ProductVersion],[exact].[ReleaseName],[exact].[ServicingBranch]
            , [exact].[KnowledgeBaseNumber],[exact].[ReleaseDate],[exact].[IsSecurityRelease]
            , [latestBranch].[BuildVersion],[latestMajor].[BuildVersion],[catalog].[CatalogAsOfDate]
            , COALESCE([exact].[BuildOverviewUrl],[latestMajor].[BuildOverviewUrl])
            , [exact].[KnowledgeBaseUrl]
            , N'Offline-Einordnung nach exakter Buildnummer und dokumentiertem Servicing-Zweig; kein Vulnerability-, Patchvollständigkeits-, Neustart- oder Freigabenachweis.'
        FROM [#ServerVersionInformation_ServerVersion] AS [v]
        LEFT JOIN [monitor].[SqlServerBuildCatalog] AS [exact] WITH (NOLOCK)
          ON [exact].[BuildVersion] COLLATE SQL_Latin1_General_CP1_CS_AS=[v].[ProductVersion] COLLATE SQL_Latin1_General_CP1_CS_AS
        OUTER APPLY
        (
            SELECT TOP(1) [c].[BuildVersion],[c].[BuildNumber],[c].[RevisionNumber],[c].[BuildOverviewUrl]
            FROM [monitor].[SqlServerBuildCatalog] AS [c] WITH (NOLOCK)
            WHERE [c].[ProductMajorVersion]=[v].[ProductMajorVersion]
            ORDER BY [c].[BuildNumber] DESC,[c].[RevisionNumber] DESC
        ) AS [latestMajor]
        OUTER APPLY
        (
            SELECT TOP(1) [c].[BuildVersion]
            FROM [monitor].[SqlServerBuildCatalog] AS [c] WITH (NOLOCK)
            WHERE [c].[ProductMajorVersion]=[v].[ProductMajorVersion]
              AND [c].[ServicingBranch]=[exact].[ServicingBranch]
              AND [c].[IsLatestInBranch]=1
            ORDER BY [c].[BuildNumber] DESC,[c].[RevisionNumber] DESC
        ) AS [latestBranch]
        OUTER APPLY
        (
            SELECT MAX([c].[CatalogAsOfDate]) AS [CatalogAsOfDate]
            FROM [monitor].[SqlServerBuildCatalog] AS [c] WITH (NOLOCK)
            WHERE [c].[ProductMajorVersion]=[v].[ProductMajorVersion]
        ) AS [catalog];

        INSERT [#ServerVersionInformation_Lifecycle]
        SELECT
              'OFFLINE_CATALOG',N'monitor.SqlServerLifecycleCatalog',@CapturedAtUtc,'PRODUCT_MAJOR_VERSION'
            , CASE WHEN [l].[ProductMajorVersion] IS NULL THEN 'UNKNOWN_LIFECYCLE'
                   WHEN CONVERT(date,@CapturedAtUtc)<[l].[StartDate] THEN 'NOT_YET_STARTED'
                   WHEN CONVERT(date,@CapturedAtUtc)<=[l].[MainstreamEndDate] THEN 'MAINSTREAM_SUPPORT'
                   WHEN CONVERT(date,@CapturedAtUtc)<=[l].[ExtendedEndDate] THEN 'EXTENDED_SUPPORT'
                   ELSE 'OUT_OF_SUPPORT' END
            , [v].[ProductMajorVersion],[l].[ProductName],[l].[StartDate]
            , [l].[MainstreamEndDate],[l].[ExtendedEndDate],[l].[LifecyclePolicy]
            , [l].[CatalogAsOfDate],[l].[LifecycleUrl]
            , N'Produktweiter Microsoft-Lifecycle; editions-, ESU-, Plattform- und organisationsspezifische Supportverträge bleiben unbewertet.'
        FROM [#ServerVersionInformation_ServerVersion] AS [v]
        LEFT JOIN [monitor].[SqlServerLifecycleCatalog] AS [l] WITH (NOLOCK)
          ON [l].[ProductMajorVersion]=[v].[ProductMajorVersion];

        INSERT [#ServerVersionInformation_InstanceFeatures]
        SELECT 'SERVERPROPERTY',N'SERVERPROPERTY',@CapturedAtUtc,'INSTANCE_FEATURE',
               [f].[FeatureName],[f].[FeatureValue],
               CASE WHEN [f].[FeatureValue] IS NULL THEN 'UNAVAILABLE_OR_NOT_APPLICABLE' ELSE 'AVAILABLE' END,
               N'SERVERPROPERTY-Flag; Installation oder Konfiguration beweist keine aktuelle Nutzung und keinen fehlerfreien Zustand.'
        FROM
        (
            VALUES
              (CONVERT(sysname,N'IsClustered'),TRY_CONVERT(int,SERVERPROPERTY(N'IsClustered')))
            , (CONVERT(sysname,N'IsHadrEnabled'),TRY_CONVERT(int,SERVERPROPERTY(N'IsHadrEnabled')))
            , (CONVERT(sysname,N'HadrManagerStatus'),TRY_CONVERT(int,SERVERPROPERTY(N'HadrManagerStatus')))
            , (CONVERT(sysname,N'IsLocalDB'),TRY_CONVERT(int,SERVERPROPERTY(N'IsLocalDB')))
            , (CONVERT(sysname,N'IsFullTextInstalled'),TRY_CONVERT(int,SERVERPROPERTY(N'IsFullTextInstalled')))
            , (CONVERT(sysname,N'IsPolyBaseInstalled'),TRY_CONVERT(int,SERVERPROPERTY(N'IsPolyBaseInstalled')))
            , (CONVERT(sysname,N'IsXTPSupported'),TRY_CONVERT(int,SERVERPROPERTY(N'IsXTPSupported')))
            , (CONVERT(sysname,N'IsAdvancedAnalyticsInstalled'),TRY_CONVERT(int,SERVERPROPERTY(N'IsAdvancedAnalyticsInstalled')))
            , (CONVERT(sysname,N'IsTempDbMetadataMemoryOptimized'),TRY_CONVERT(int,SERVERPROPERTY(N'IsTempDbMetadataMemoryOptimized')))
        ) AS [f]([FeatureName],[FeatureValue]);

        INSERT [#ServerVersionInformation_References]
        VALUES
          ('LATEST_UPDATES',NULL,N'Latest updates and version history for SQL Server',N'https://learn.microsoft.com/en-us/troubleshoot/sql/releases/download-and-install-latest-updates','2026-07-21')
        , ('SERVERPROPERTY',NULL,N'SERVERPROPERTY (Transact-SQL)',N'https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql','2026-07-21')
        , ('BUILD_OVERVIEW',15,N'SQL Server 2019 build versions',N'https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/build-versions','2026-07-21')
        , ('BUILD_OVERVIEW',16,N'SQL Server 2022 build versions',N'https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/build-versions','2026-07-21')
        , ('BUILD_OVERVIEW',17,N'SQL Server 2025 build versions',N'https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2025/build-versions','2026-07-21');

        IF EXISTS
        (
            SELECT 1 FROM [#ServerVersionInformation_BuildAssessment]
            WHERE [AssessmentStatus] NOT IN('EXACT_MATCH','OLDER_KNOWN_BUILD')
               OR [CatalogFreshnessStatus]='CATALOG_STALE'
        )
            INSERT [#ServerVersionInformation_Warnings]
            SELECT 'OFFLINE_CATALOG',N'monitor.SqlServerBuildCatalog',@CapturedAtUtc,
                   [AssessmentStatus],CONVERT(bit,0),NULL,
                   N'Die Buildnummer ist nicht als aktueller exakter Katalogtreffer einordenbar; die verlinkte Microsoft-Buildübersicht ist vor einer Patchentscheidung zu prüfen.',
                   [EvidenceLimit]
            FROM [#ServerVersionInformation_BuildAssessment]
            WHERE [AssessmentStatus] NOT IN('EXACT_MATCH','OLDER_KNOWN_BUILD')
               OR [CatalogFreshnessStatus]='CATALOG_STALE';

        IF @MitDatenbankKompatibilitaet=1
        BEGIN
            DECLARE @CrossDatabaseRequested bit=0;
            EXEC [monitor].[USP_PrepareDatabaseCandidates]
                  @DatabaseNames=@DatabaseNames
                , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern=@DatabaseNamePattern
                , @AnalysisClass='STANDARD_CURRENT'
                , @StatusCode=@StatusCode OUTPUT
                , @ErrorMessage=@ErrorMessage OUTPUT
                , @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT
                , @CandidateTable=N'#ServerVersionInformation_DatabaseCandidates'
                , @WarningTable=N'#ServerVersionInformation_CandidateWarnings';

            INSERT [#ServerVersionInformation_DatabaseCompatibility]
            SELECT TOP(@Limit) 'SYSTEM_CATALOG',N'master.sys.databases',@CapturedAtUtc,'VISIBLE_DATABASE',
                   CONVERT(bit,1),'AVAILABLE',[DatabaseId],[DatabaseName],[CompatibilityLevel],
                   [CollationName],[StateDesc],[IsReadOnly],[IsSystemDatabase],
                   N'Sichtbarer aktueller Katalogzustand; keine datenbanklokale Abfrage und keine Aussage zur Workload-Eignung des Compatibility Levels.'
            FROM [#ServerVersionInformation_DatabaseCandidates]
            ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];

            INSERT [#ServerVersionInformation_Warnings]
            SELECT 'SYSTEM_CATALOG',N'master.sys.databases',@CapturedAtUtc,[StatusCode],
                   CONVERT(bit,1),NULL,[ErrorMessage],
                   N'Explizit angeforderter Datenbankkontext war nicht sichtbar, nicht zugreifbar oder ohne Opt-in ausgeschlossen.'
            FROM [#ServerVersionInformation_CandidateWarnings];
        END;
    END;

    IF EXISTS(SELECT 1 FROM [#ServerVersionInformation_Warnings] WHERE [IsPartial]=1)
    BEGIN
        SET @IsPartial=1;
        IF @StatusCode='AVAILABLE' SET @StatusCode='AVAILABLE_LIMITED';
    END;

    SELECT TOP(1) @ErrorNumber=COALESCE(@ErrorNumber,[ErrorNumber]),
                  @ErrorMessage=COALESCE(@ErrorMessage,[Message])
    FROM [#ServerVersionInformation_Warnings]
    WHERE [IsPartial]=1
    ORDER BY [WarningOrdinal];

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=(SELECT N'ServerVersionInformation' [resultName],1 [schemaVersion],@CapturedAtUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@ErrorNumber [errorNumber],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @ServerJson nvarchar(max)=(SELECT * FROM [#ServerVersionInformation_ServerVersion] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @BuildJson nvarchar(max)=(SELECT * FROM [#ServerVersionInformation_BuildAssessment] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @LifecycleJson nvarchar(max)=(SELECT * FROM [#ServerVersionInformation_Lifecycle] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @FeaturesJson nvarchar(max)=(SELECT * FROM [#ServerVersionInformation_InstanceFeatures] ORDER BY [FeatureName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @DatabasesJson nvarchar(max)=(SELECT TOP(@Limit) * FROM [#ServerVersionInformation_DatabaseCompatibility] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @ReferencesJson nvarchar(max)=(SELECT * FROM [#ServerVersionInformation_References] ORDER BY [ReferenceType],[ProductMajorVersion] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max)=(SELECT * FROM [#ServerVersionInformation_Warnings] ORDER BY [WarningOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@MetaJson,N'{}'),N',"serverVersion":',COALESCE(@ServerJson,N'[]'),N',"buildAssessment":',COALESCE(@BuildJson,N'[]'),N',"lifecycle":',COALESCE(@LifecycleJson,N'[]'),N',"instanceFeatures":',COALESCE(@FeaturesJson,N'[]'),N',"databaseCompatibility":',COALESCE(@DatabasesJson,N'[]'),N',"references":',COALESCE(@ReferencesJson,N'[]'),N',"warnings":',COALESCE(@WarningsJson,N'[]'),N'}');
    END;

    IF @ConsoleResultRequested=1
    BEGIN
        INSERT [#ServerVersionInformation_Console]
        SELECT [b].[ProductVersion],[b].[KnownReleaseName],[b].[ServicingBranch],
               [b].[AssessmentStatus],[b].[CatalogFreshnessStatus],
               [l].[LifecycleStatus],[l].[MainstreamEndDate],[l].[ExtendedEndDate],
               [b].[LatestKnownBuildInBranch],[b].[BuildOverviewUrl],
               @StatusCode,@IsPartial
        FROM [#ServerVersionInformation_BuildAssessment] AS [b]
        CROSS JOIN [#ServerVersionInformation_Lifecycle] AS [l];

        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ServerVersionInformation_Console'
            , @ResultLabel=N'Serverversion'
            , @EmptyMessage=N'Keine Serverversionsinformation';
    END
    ELSE IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#ServerVersionInformation_ServerVersion];
        SELECT * FROM [#ServerVersionInformation_BuildAssessment];
        SELECT * FROM [#ServerVersionInformation_Lifecycle];
        SELECT * FROM [#ServerVersionInformation_InstanceFeatures] ORDER BY [FeatureName];
        SELECT TOP(@Limit) * FROM [#ServerVersionInformation_DatabaseCompatibility] ORDER BY [DatabaseName];
        SELECT * FROM [#ServerVersionInformation_References] ORDER BY [ReferenceType],[ProductMajorVersion];
        SELECT * FROM [#ServerVersionInformation_Warnings] ORDER BY [WarningOrdinal];
    END
    ELSE IF @OutputMode='TABLE'
    BEGIN
        DECLARE @TargetTable sysname;
        DECLARE [ResultCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [ResultName],[TargetTable]
            FROM [#ServerVersionInformation_ResultTableMap]
            ORDER BY [ResultName];
        DECLARE @ResultName sysname;
        OPEN [ResultCursor];
        FETCH NEXT FROM [ResultCursor] INTO @ResultName,@TargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            DECLARE @SourceTable sysname=CASE @ResultName
                WHEN N'serverVersion' THEN N'#ServerVersionInformation_ServerVersion'
                WHEN N'buildAssessment' THEN N'#ServerVersionInformation_BuildAssessment'
                WHEN N'lifecycle' THEN N'#ServerVersionInformation_Lifecycle'
                WHEN N'instanceFeatures' THEN N'#ServerVersionInformation_InstanceFeatures'
                WHEN N'databaseCompatibility' THEN N'#ServerVersionInformation_DatabaseCompatibility'
                WHEN N'references' THEN N'#ServerVersionInformation_References'
                WHEN N'warnings' THEN N'#ServerVersionInformation_Warnings' END;
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=@SourceTable,@TargetTable=@TargetTable,@ThrowOnError=1;
            FETCH NEXT FROM [ResultCursor] INTO @ResultName,@TargetTable;
        END;
        CLOSE [ResultCursor];
        DEALLOCATE [ResultCursor];
    END;

    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE')
    BEGIN
        DECLARE @PrintMessage nvarchar(2048)=LEFT(CONCAT(N'USP_ServerVersionInformation: ',@StatusCode,N'. ',COALESCE(@ErrorMessage,N'Siehe warnings-Resultset.')),2048);
        RAISERROR(N'%s',10,1,@PrintMessage) WITH NOWAIT;
    END;

    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,
           @ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
END;
GO

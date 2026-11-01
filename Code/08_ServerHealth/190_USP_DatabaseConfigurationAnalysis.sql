USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_DatabaseConfigurationAnalysis
Version      : 1.0.0
Stand        : 2026-07-21
Zweck        : Die Procedure inventarisiert sichtbare, online befindliche
               und zugreifbare Datenbankoptionen, Database Scoped Configurations
               sowie Query-Store-Einstellungen. Ohne explizites Sollprofil
               weist sie Unterschiede als lokale Variation aus; ein Profil
               ergänzt getrennte Abweichungsbefunde.
Profil       : JSON-Array aus settingScope, settingName und expectedValue.
               Ohne Profil wird ausschließlich lokale Variation ausgewiesen.
Abgrenzung   : Variation oder Profilabweichung ist ein Review-Befund, keine
               universelle Fehlkonfiguration und keine automatische DDL-Anweisung.
Eigenlast    : Serverkatalog einmal; je sichtbarer Datenbank zwei kleine
               Katalogabfragen mit LOCK_TIMEOUT 0 und isoliertem Partialstatus.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_DatabaseConfigurationAnalysis]
      @DatabaseNames                  nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @ProfileJson                    nvarchar(max)  = NULL
    , @MaxZeilen                      int            = 2000
    , @ResultSetArt                   varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max)  = NULL
    , @JsonErzeugen                   bit            = 0
    , @Json                           nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                 bit            = 1
    , @Hilfe                          bit            = 0
    , @StatusCodeOut                  varchar(40)    = NULL OUTPUT
    , @IsPartialOut                   bit            = NULL OUTPUT
    , @ErrorNumberOut                 int            = NULL OUTPUT
    , @ErrorMessageOut                nvarchar(2048) = NULL OUTPUT
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
    DECLARE @CrossDatabaseRequested bit=0;
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_DatabaseConfigurationAnalysis';
        PRINT N'Inventarisiert sichtbare, online befindliche und zugreifbare Datenbanken sowie Optionen, Database Scoped Configurations und Query-Store-Einstellungen.';
        PRINT N'Ohne Profil ist ein häufiger Wert nur eine lokale Vergleichsreferenz, kein Sollwert. Ein explizites Profil ergänzt Abweichungsbefunde, aber keine Änderungsanweisung.';
        PRINT N'Exakte Namensliste und Pattern sind alternative Filter. Nicht sichtbare oder nicht zugreifbare Datenbanken können fehlen.';
        PRINT N'Katalogzugriffe warten nicht auf Sperren. Berechtigungs- und Quellenfehler werden soweit möglich als Teilstatus erfasst.';
        PRINT N'LIKE wird case-sensitiv ausgewertet. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank.';
        PRINT N'@ResultSetArt: CONSOLE, RAW, TABLE oder NONE. JSON wird unabhängig mit @JsonErzeugen und @Json angefordert.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste exakter, einteiliger SQL-Datenbanknamen, z. B. N''AppDb|[Reporting Db]''. | trennt außerhalb von [...]; ]] maskiert eine schließende Klammer. Äußere Elementleerzeichen werden entfernt. Leere Elemente, ungültige Klammerung, mehrteilige oder überlange Namen und doppelte gültige Namen sind ungültig. NULL, leerer Text oder nur U+0020-Leerzeichen bedeuten keinen Namensfilter; dann gelten alle sichtbaren, online befindlichen und zugreifbaren Kandidaten ohne Datenbanksnapshots. Nur eine nach Entfernung äußerer U+0020-Leerzeichen nichtleere Liste ist mit einem nicht-NULL-Pattern unvereinbar. Nicht vorhandene, ausgeschlossene, offline befindliche oder für den Login nicht zugreifbare explizite Namen erzeugen DATABASE_UNAVAILABLE; explizite Systemnamen master, tempdb, model und msdb ohne Opt-in erzeugen SYSTEM_DATABASE_EXCLUDED. Namen und Duplikate werden case-sensitiv verglichen.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt Systemdatenbanken mit ID 1 bis 4 aus; 1 bezieht sie zusätzlich zu Datenbanken mit ID über 4 ein. NULL ist ungültig. Der Wert wird auf bit konvertiert: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. Auch einbezogene Systemdatenbanken müssen sichtbar, online und zugreifbar sein.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Filtert Datenbanknamen. NULL bedeutet kein Pattern. Nach Entfernung äußerer U+0020-Leerzeichen wird optional ohne Beachtung der Groß-/Kleinschreibung ein Präfix entfernt: LIKE: für SQL-LIKE, REGEX: für case-sensitive Regex oder REGEXI: für case-insensitive Regex. Ohne Präfix gilt LIKE. Der Rest wird nach Präfixentfernung nicht erneut getrimmt; leerer Eingang und leeres Präfixergebnis sind ungültig. LIKE wird case-sensitiv ausgewertet. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; der Parser validiert die Regex-Syntax nicht vorab. Der Kandidatenhelper führt REGEXP_LIKE aus; eine fehlerhafte Regex kann dabei einen nicht abgefangenen Laufzeitfehler auslösen, ohne normalen Statusabschluss. Nur eine aktive, nichtleere Datenbankliste ist mit einem nicht-NULL-Pattern unvereinbar.';
        PRINT N'@ProfileJson nvarchar(max); Default: NULL. NULL verwendet ausschließlich den lokalen Vergleich; Leertext, U+0020-Leertext und ein leeres Array sind ungültig. Ansonsten ein JSON-Array eindeutiger Objekte mit exakt den case-sensitiven Feldnamen settingScope, settingName und expectedValue, z. B. [{"settingScope":"DATABASE","settingName":"AUTO_CLOSE","expectedValue":"OFF"}]. settingScope wird getrimmt und großgeschrieben; erlaubt sind ausschließlich DATABASE für Datenbankoptionen, SCOPED für Database Scoped Configurations und QUERY_STORE für Query-Store-Optionen. settingName wird zu nvarchar(128) konvertiert, getrimmt und muss nichtleer sein. expectedValue wird zu nvarchar(4000) konvertiert und darf nicht NULL sein; leerer Text ist zulässig. Nicht konvertierbare Einträge, ungültiges/leer strukturiertes Array, NULL-Felder, unbekannte Scopes und doppelte Scope/Name-Paare unter case-sensitivem Vergleich sind ungültig. Zusätzliche JSON-Felder werden ignoriert. Einstellungsnamen und Soll-/Istwerte werden mit SQL_Latin1_General_CP1_CI_AS verglichen; reine Unterschiede der Groß-/Kleinschreibung erzeugen keine Abweichung. Ein Name ohne sichtbare passende Einstellung erzeugt PROFILE_SETTING_NOT_VISIBLE. Ohne Profil wird lokale Variation, mit Profil zusätzlich DriftType PROFILE_MISMATCH mit FindingCode EXPLICIT_PROFILE_MISMATCH ausgewiesen; keine Konfiguration wird geändert.';
        PRINT N'@MaxZeilen int; Default: 2000. Begrenzt settings- und drift-Zeilen jeweils separat, nicht die Inventarisierung oder andere Gruppen. Positive Werte sind das jeweilige Maximum; 0 oder NULL bedeutet unbegrenzt. Negative Werte sind ungültig. Die vollständigen Einstellungen und Befunde werden zunächst berechnet und materialisiert, danach werden Zeilen über dem Limit entfernt. settings wird nach DatabaseName, SettingScope und SettingName sortiert; drift nach DriftType, SettingScope, SettingName und DatabaseName. HasMoreSettingRows und HasMoreDriftRows melden erkannte Kürzungen; Die Statuszählung erfolgt vor dem Entfernen überzähliger Zeilen; SettingRowCount und DriftRowCount geben jeweils das Minimum aus Vollmenge und Limit an. Profil, Quellenstatus und Warnungen bleiben ungekürzt.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Wählt reguläre Resultsets. Nach Trim und Umwandlung in Großbuchstaben sind genau CONSOLE, RAW, TABLE und NONE zulässig. CONSOLE liefert eine beschriftete Driftansicht; RAW liefert sechs Resultsets in Reihenfolge moduleStatus, settings, drift, profile, sourceStatus, warnings. TABLE schreibt angeforderte Gruppen in vorhandene lokale #Temp-Tabellen. NONE liefert keine regulären Resultsets. NULL, Leertext und andere Werte sind ungültig. @JsonErzeugen steuert unabhängig den JSON-OUTPUT-Parameter.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE ist ein JSON-Objekt mit Resultatnamen und vorhandenen lokalen #Temp-Zielen erforderlich, z. B. {"settings":"#DbSettings"}. Erlaubt sind moduleStatus, settings, drift, profile, sourceStatus und warnings; Namen werden case-sensitiv verglichen. Ziele müssen vorhandene leere lokale #Temp-Tabellen mit genau einer Seed-Spalte sein. ##Tabellen, reservierte #Monitor-Namen, doppelte Zuordnungen/Ziele und unbekannte Resultatnamen sind ungültig. In TABLE muss die Zuordnung nichtleer und gültig sein. Außerhalb von TABLE sind NULL, Leertext und nur U+0020-Leerzeichen zulässig; ein anderer nichtleerer Wert ist ungültig. Zielnamen sind höchstens 116 Zeichen lang. Der Preflight prüft die Zuordnung und Ziele; der spätere Writer ersetzt die Seed-Spalte durch das Ergebnisschema. Die Gruppen bedeuten: moduleStatus Modulstatus, settings Einstellungen, drift Unterschiede, profile Sollprofil, sourceStatus Quellenstatus, warnings Warnungen.';
        PRINT N'@JsonErzeugen bit; Default: 0. 0 lässt @Json auf NULL; 1 befüllt es mit meta, settings, drift, profile, sourceStatus und warnings. settings und drift beachten jeweils @MaxZeilen. NULL ist ungültig. Konvertierung auf bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter für das optionale JSON-Ergebnis. Wird vor Hilfe- und Analyseverzweigung auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Zum Empfangen ist OUTPUT zu binden; der Parameter kann ausgelassen werden, wenn kein JSON benötigt wird.';
        PRINT N'@PrintMeldungen bit; Default: 1. Steuert nur die zusätzliche Meldung mit RAISERROR-Schweregrad 10 und NOWAIT bei Modulstatus ungleich AVAILABLE. 0 unterdrückt die Meldung, 1 gibt sie aus; Resultsets und Status-OUTPUT-Werte bleiben unabhängig. NULL ist ungültig. Konvertierung auf bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Hilfe bit; Default: 0. Bei 1 wird PRINT-Hilfe ausgegeben und vor Validierung sowie Katalogzugriff zurückgekehrt. @Json wurde zuvor auf NULL gesetzt; Status-OUTPUT-Parameter werden in diesem Pfad nicht beschrieben. Bei 0 oder NULL läuft die Analyse. Konvertierung auf bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Status im normalen Analysepfad: AVAILABLE bedeutet keine Teilquellenwarnung; AVAILABLE_LIMITED bedeutet, dass mindestens eine Quelle oder Kandidat eingeschränkt war; INVALID_PARAMETER bezeichnet ungültige Auswahl-, Profil-, Zeilen- oder Ausgabeparameter; INTERNAL_ERROR bezeichnet einen internen Kandidaten-/Temp-Tabellenfehler; UNAVAILABLE_FEATURE meldet nicht verfügbare Regex-Funktionalität (SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank erforderlich). DENIED_PERMISSION und TIMEOUT sind Quellenstatus und führen regelmäßig zu AVAILABLE_LIMITED, nicht zu globalen Statuswerten. Der Parameter kann ausgelassen werden; nur beim Empfangen ist OUTPUT-Bindung nötig. Hilfe weist den Parameter nicht zu und erhält den vorherigen Variableninhalt.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. OUTPUT-Bit: 0 bei AVAILABLE, 1 bei eingeschränktem oder fehlgeschlagenem Ergebnis. Der Parameter kann ausgelassen werden; nur beim Empfangen ist OUTPUT-Bindung nötig. Hilfe weist ihn nicht zu, daher bleibt ein gebundener NULL-Eingang NULL und ein anderer Anfangswert erhalten.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT-Fehlernummer aus der ersten maßgeblichen Warnung, falls vorhanden, sonst NULL. Der Parameter kann ausgelassen werden; nur beim Empfangen ist OUTPUT-Bindung nötig. Hilfe weist ihn nicht zu und erhält den vorherigen Variableninhalt.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT-Fehler- oder Hinweismeldung aus der ersten maßgeblichen Warnung, falls vorhanden, sonst NULL. Der Parameter kann ausgelassen werden; nur beim Empfangen ist OUTPUT-Bindung nötig. Hilfe weist ihn nicht zu und erhält den vorherigen Variableninhalt.';
        PRINT N'EXEC [monitor].[USP_DatabaseConfigurationAnalysis] @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @Json nvarchar(max); DECLARE @Profile nvarchar(max)=N''[{"settingScope":"DATABASE","settingName":"AUTO_CLOSE","expectedValue":"OFF"}]''; EXEC [monitor].[USP_DatabaseConfigurationAnalysis] @ProfileJson=@Profile, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'CREATE TABLE #DatabaseConfigurationAnalysis_HelpExample (Seed int NULL);
DECLARE @ConfigurationTableMap nvarchar(max)=N''{"settings":"#DatabaseConfigurationAnalysis_HelpExample"}'';
BEGIN TRY
    EXEC [monitor].[USP_DatabaseConfigurationAnalysis]
          @ResultSetArt=''TABLE''
        , @ResultTablesJson=@ConfigurationTableMap;
    SELECT * FROM #DatabaseConfigurationAnalysis_HelpExample;
    DROP TABLE IF EXISTS #DatabaseConfigurationAnalysis_HelpExample;
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS #DatabaseConfigurationAnalysis_HelpExample;
    THROW;
END CATCH;';
        PRINT N'EXEC [monitor].[USP_DatabaseConfigurationAnalysis] @Hilfe=1;';





        RETURN;
    END;

    CREATE TABLE [#DatabaseConfigurationAnalysis_ResultTableMap]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE
    );
    CREATE TABLE [#DatabaseConfigurationAnalysis_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY
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
    CREATE TABLE [#DatabaseConfigurationAnalysis_CandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#DatabaseConfigurationAnalysis_Profile]
    (
          [ProfileOrdinal] int NOT NULL PRIMARY KEY
        , [SettingScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SettingName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ExpectedValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#DatabaseConfigurationAnalysis_Settings]
    (
          [CapturedAtUtc] datetime2(3) NOT NULL
        , [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SettingScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SettingName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ActualValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SecondaryValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsDefault] bit NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE INDEX [IX_DatabaseConfiguration_Settings]
      ON [#DatabaseConfigurationAnalysis_Settings]([SettingScope],[SettingName],[DatabaseId]);
    CREATE TABLE [#DatabaseConfigurationAnalysis_Drift]
    (
          [CapturedAtUtc] datetime2(3) NOT NULL
        , [DriftType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [DatabaseId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SettingScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SettingName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ActualValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ReferenceValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MatchingDatabaseCount] int NULL
        , [ComparedDatabaseCount] int NOT NULL
        , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#DatabaseConfigurationAnalysis_SourceStatus]
    (
          [SourceOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [DatabaseId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [ReturnedRowCount] bigint NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#DatabaseConfigurationAnalysis_Warnings]
    (
          [WarningOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#DatabaseConfigurationAnalysis_ModuleStatus]
    (
          [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [CrossDatabaseRequested] bit NOT NULL
        , [DatabaseCount] int NOT NULL
        , [SettingRowCount] bigint NOT NULL
        , [DriftRowCount] bigint NOT NULL
        , [ProfileEntryCount] int NOT NULL
        , [HasMoreSettingRows] bit NOT NULL
        , [HasMoreDriftRows] bit NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @MaxZeilen<0 OR @SystemdatenbankenEinbeziehen IS NULL OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
       OR @OutputMode NOT IN('CONSOLE','RAW','TABLE','NONE')
       OR (@DatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL)
       OR (@OutputMode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
       OR (@ProfileJson IS NOT NULL AND
           (ISJSON(@ProfileJson)<>1 OR LEFT(LTRIM(@ProfileJson),1)<>N'['))
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,
               @ErrorMessage=N'Ungültiger Filter-, Profil-, Zeilen- oder Ausgabeparameter.';
    END;

    IF @StatusCode='AVAILABLE' AND @ProfileJson IS NOT NULL
    BEGIN
        BEGIN TRY
            INSERT [#DatabaseConfigurationAnalysis_Profile]([ProfileOrdinal],[SettingScope],[SettingName],[ExpectedValue])
            SELECT TRY_CONVERT(int,[j].[key])+1,UPPER(LTRIM(RTRIM([p].[SettingScope]))),
                   LTRIM(RTRIM([p].[SettingName])),[p].[ExpectedValue]
            FROM OPENJSON(@ProfileJson) AS [j]
            CROSS APPLY OPENJSON([j].[value])
            WITH
            (
                  [SettingScope] varchar(32) '$.settingScope'
                , [SettingName] nvarchar(128) '$.settingName'
                , [ExpectedValue] nvarchar(4000) '$.expectedValue'
            ) AS [p];
        END TRY
        BEGIN CATCH
            SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,
                   @ErrorNumber=ERROR_NUMBER(),
                   @ErrorMessage=N'@ProfileJson enthält keinen gültigen Arrayeintrag.';
        END CATCH;

        IF @StatusCode='AVAILABLE' AND
           (NOT EXISTS(SELECT 1 FROM [#DatabaseConfigurationAnalysis_Profile])
           OR EXISTS
              (
                  SELECT 1 FROM [#DatabaseConfigurationAnalysis_Profile]
                  WHERE [SettingScope] NOT IN('DATABASE','SCOPED','QUERY_STORE')
                     OR NULLIF([SettingName],N'') IS NULL OR [ExpectedValue] IS NULL
              )
           OR EXISTS
              (
                  SELECT [SettingScope],[SettingName]
                  FROM [#DatabaseConfigurationAnalysis_Profile]
                  GROUP BY [SettingScope],[SettingName]
                  HAVING COUNT_BIG(*)>1
              ))
            SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,
                   @ErrorMessage=N'@ProfileJson muss ein nicht leeres Array eindeutiger DATABASE-, SCOPED- oder QUERY_STORE-Einträge sein.';
    END;

    IF @StatusCode='AVAILABLE' AND @OutputMode='TABLE'
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'moduleStatus|settings|drift|profile|sourceStatus|warnings'
            , @MappingTable=N'#DatabaseConfigurationAnalysis_ResultTableMap'
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @ThrowOnError=1;

    IF @StatusCode='AVAILABLE'
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames=@DatabaseNames
            , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern=@DatabaseNamePattern
            , @AnalysisClass='STANDARD_CURRENT'
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT
            , @CandidateTable=N'#DatabaseConfigurationAnalysis_DatabaseCandidates'
            , @WarningTable=N'#DatabaseConfigurationAnalysis_CandidateWarnings';

    SET LOCK_TIMEOUT 0;

    IF @StatusCode='AVAILABLE'
    BEGIN TRY
        INSERT [#DatabaseConfigurationAnalysis_Settings]
        SELECT @CapturedAtUtc,[d].[database_id],[d].[name],'DATABASE',[v].[SettingName],[v].[ActualValue],NULL,NULL,
               N'master.sys.databases','AVAILABLE',
               N'Sichtbarer aktueller Serverkatalogzustand; Wertunterschiede sind ohne Workload- und Betriebsprofil keine Fehlkonfiguration.'
        FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
        INNER JOIN [#DatabaseConfigurationAnalysis_DatabaseCandidates] AS [c] ON [c].[DatabaseId]=[d].[database_id]
        CROSS APPLY
        (
            VALUES
              (CONVERT(nvarchar(128),N'COMPATIBILITY_LEVEL'),CONVERT(nvarchar(4000),[d].[compatibility_level]))
            , (N'COLLATION',CONVERT(nvarchar(4000),[d].[collation_name]))
            , (N'RECOVERY_MODEL',CONVERT(nvarchar(4000),[d].[recovery_model_desc]))
            , (N'PAGE_VERIFY',CONVERT(nvarchar(4000),[d].[page_verify_option_desc]))
            , (N'AUTO_CLOSE',CASE [d].[is_auto_close_on] WHEN 1 THEN N'ON' ELSE N'OFF' END)
            , (N'AUTO_SHRINK',CASE [d].[is_auto_shrink_on] WHEN 1 THEN N'ON' ELSE N'OFF' END)
            , (N'AUTO_CREATE_STATS',CASE [d].[is_auto_create_stats_on] WHEN 1 THEN N'ON' ELSE N'OFF' END)
            , (N'AUTO_UPDATE_STATS',CASE [d].[is_auto_update_stats_on] WHEN 1 THEN N'ON' ELSE N'OFF' END)
            , (N'AUTO_UPDATE_STATS_ASYNC',CASE [d].[is_auto_update_stats_async_on] WHEN 1 THEN N'ON' ELSE N'OFF' END)
            , (N'READ_COMMITTED_SNAPSHOT',CASE [d].[is_read_committed_snapshot_on] WHEN 1 THEN N'ON' ELSE N'OFF' END)
            , (N'SNAPSHOT_ISOLATION',CONVERT(nvarchar(4000),[d].[snapshot_isolation_state_desc]))
            , (N'PARAMETERIZATION',CASE [d].[is_parameterization_forced] WHEN 1 THEN N'FORCED' ELSE N'SIMPLE' END)
            , (N'QUERY_STORE',CASE [d].[is_query_store_on] WHEN 1 THEN N'ON' ELSE N'OFF' END)
            , (N'ACCELERATED_DATABASE_RECOVERY',CASE [d].[is_accelerated_database_recovery_on] WHEN 1 THEN N'ON' ELSE N'OFF' END)
        ) AS [v]([SettingName],[ActualValue]);

        INSERT [#DatabaseConfigurationAnalysis_SourceStatus]
        SELECT [DatabaseId],[DatabaseName],N'databaseOptions',N'master.sys.databases',@CapturedAtUtc,'AVAILABLE',0,
               (SELECT COUNT_BIG(*) FROM [#DatabaseConfigurationAnalysis_Settings] AS [s] WHERE [s].[DatabaseId]=[c].[DatabaseId] AND [s].[SettingScope]='DATABASE'),
               NULL,NULL,N'Ein Katalogsnapshot; nicht sichtbare Datenbanken fehlen und einzelne Optionen bleiben workloadabhängig.'
        FROM [#DatabaseConfigurationAnalysis_DatabaseCandidates] AS [c];
    END TRY
    BEGIN CATCH
        INSERT [#DatabaseConfigurationAnalysis_SourceStatus]
        VALUES(NULL,NULL,N'databaseOptions',N'master.sys.databases',@CapturedAtUtc,
               CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
               1,0,ERROR_NUMBER(),ERROR_MESSAGE(),N'Datenbanklokale Quellen können unabhängig davon teilweise verfügbar bleiben.');
    END CATCH;

    IF @StatusCode='AVAILABLE' AND EXISTS
    (
        SELECT 1
        FROM [master].[sys].[all_columns] AS [ac] WITH (NOLOCK)
        INNER JOIN [master].[sys].[all_objects] AS [ao] WITH (NOLOCK) ON [ao].[object_id]=[ac].[object_id]
        INNER JOIN [master].[sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[ao].[schema_id]
        WHERE [s].[name]=N'sys' AND [ao].[name]=N'databases' AND [ac].[name]=N'is_optimized_locking_on'
    )
    BEGIN TRY
        EXEC [sys].[sp_executesql]
            N'INSERT [#DatabaseConfigurationAnalysis_Settings]
              SELECT @CapturedAtUtc,[d].[database_id],[d].[name],''DATABASE'',N''OPTIMIZED_LOCKING'',
                     CASE [d].[is_optimized_locking_on] WHEN 1 THEN N''ON'' ELSE N''OFF'' END,NULL,NULL,
                     N''master.sys.databases'',''AVAILABLE'',
                     N''Versionsabhängiger sichtbarer Katalogzustand; Aktivierung ist ohne Workloadkontext keine automatische Empfehlung.''
              FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
              INNER JOIN [#DatabaseConfigurationAnalysis_DatabaseCandidates] AS [c] ON [c].[DatabaseId]=[d].[database_id];',
            N'@CapturedAtUtc datetime2(3)',@CapturedAtUtc=@CapturedAtUtc;
    END TRY
    BEGIN CATCH
        INSERT [#DatabaseConfigurationAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
        VALUES(NULL,N'databaseOptions',CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,ERROR_NUMBER(),ERROR_MESSAGE());
    END CATCH;

    IF @StatusCode='AVAILABLE'
    BEGIN
        DECLARE @DatabaseId int,@DatabaseName sysname,@Sql nvarchar(max);
        DECLARE [DatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId],[DatabaseName]
            FROM [#DatabaseConfigurationAnalysis_DatabaseCandidates]
            ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];
        OPEN [DatabaseCursor]; FETCH NEXT FROM [DatabaseCursor] INTO @DatabaseId,@DatabaseName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Sql=CONVERT(nvarchar(max),N'')+N'
            BEGIN TRY
                INSERT [#DatabaseConfigurationAnalysis_Settings]
                SELECT @CapturedAtUtc,@DatabaseId,@DatabaseName,''SCOPED'',CONVERT(nvarchar(128),[name]),
                       CONVERT(nvarchar(4000),[value]),CONVERT(nvarchar(4000),[value_for_secondary]),[is_value_default],
                       N''sys.database_scoped_configurations'',''AVAILABLE'',
                       N''Datenbanklokaler Katalogzustand; Wert, Secondary-Wert und Defaultstatus werden getrennt erhalten.''
                FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[database_scoped_configurations] WITH (NOLOCK);
                DECLARE @ScopedRows bigint=@@ROWCOUNT;
                INSERT [#DatabaseConfigurationAnalysis_SourceStatus]
                VALUES(@DatabaseId,@DatabaseName,N''scopedConfigurations'',N''sys.database_scoped_configurations'',@CapturedAtUtc,''AVAILABLE'',0,@ScopedRows,NULL,NULL,
                       N''Eine Zeile je verfügbarer Scoped Configuration; Einstellungen können versionsabhängig hinzukommen.'');
            END TRY
            BEGIN CATCH
                INSERT [#DatabaseConfigurationAnalysis_SourceStatus]
                VALUES(@DatabaseId,@DatabaseName,N''scopedConfigurations'',N''sys.database_scoped_configurations'',@CapturedAtUtc,
                       CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN ''DENIED_PERMISSION'' WHEN ERROR_NUMBER()=1222 THEN ''TIMEOUT'' ELSE ''ERROR_HANDLED'' END,
                       1,0,ERROR_NUMBER(),ERROR_MESSAGE(),N''Andere Datenbanken und Quellen werden weiter verarbeitet.'');
            END CATCH;
            BEGIN TRY
                INSERT [#DatabaseConfigurationAnalysis_Settings]
                SELECT @CapturedAtUtc,@DatabaseId,@DatabaseName,''QUERY_STORE'',[v].[SettingName],[v].[ActualValue],NULL,NULL,
                       N''sys.database_query_store_options'',''AVAILABLE'',
                       N''Aktueller Query-Store-Konfigurations- und Zustandswert; gewünschter und tatsächlicher Zustand sind getrennt zu bewerten.''
                FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[database_query_store_options] AS [q] WITH (NOLOCK)
                CROSS APPLY
                (VALUES
                    (CONVERT(nvarchar(128),N''DESIRED_STATE''),CONVERT(nvarchar(4000),[q].[desired_state_desc])),
                    (N''ACTUAL_STATE'',CONVERT(nvarchar(4000),[q].[actual_state_desc])),
                    (N''READONLY_REASON'',CONVERT(nvarchar(4000),[q].[readonly_reason])),
                    (N''CURRENT_STORAGE_SIZE_MB'',CONVERT(nvarchar(4000),[q].[current_storage_size_mb])),
                    (N''MAX_STORAGE_SIZE_MB'',CONVERT(nvarchar(4000),[q].[max_storage_size_mb])),
                    (N''STALE_QUERY_THRESHOLD_DAYS'',CONVERT(nvarchar(4000),[q].[stale_query_threshold_days])),
                    (N''FLUSH_INTERVAL_SECONDS'',CONVERT(nvarchar(4000),[q].[flush_interval_seconds])),
                    (N''INTERVAL_LENGTH_MINUTES'',CONVERT(nvarchar(4000),[q].[interval_length_minutes])),
                    (N''QUERY_CAPTURE_MODE'',CONVERT(nvarchar(4000),[q].[query_capture_mode_desc])),
                    (N''SIZE_BASED_CLEANUP_MODE'',CONVERT(nvarchar(4000),[q].[size_based_cleanup_mode_desc])),
                    (N''WAIT_STATS_CAPTURE_MODE'',CONVERT(nvarchar(4000),[q].[wait_stats_capture_mode_desc]))
                ) AS [v]([SettingName],[ActualValue]);
                DECLARE @QueryStoreRows bigint=@@ROWCOUNT;
                INSERT [#DatabaseConfigurationAnalysis_SourceStatus]
                VALUES(@DatabaseId,@DatabaseName,N''queryStoreOptions'',N''sys.database_query_store_options'',@CapturedAtUtc,''AVAILABLE'',0,@QueryStoreRows,NULL,NULL,
                       N''Konfiguration und aktueller Zustand; Query-Store-Inhalt und Workloadwirkung werden nicht gelesen.'');
            END TRY
            BEGIN CATCH
                INSERT [#DatabaseConfigurationAnalysis_SourceStatus]
                VALUES(@DatabaseId,@DatabaseName,N''queryStoreOptions'',N''sys.database_query_store_options'',@CapturedAtUtc,
                       CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN ''DENIED_PERMISSION'' WHEN ERROR_NUMBER()=1222 THEN ''TIMEOUT'' ELSE ''ERROR_HANDLED'' END,
                       1,0,ERROR_NUMBER(),ERROR_MESSAGE(),N''Andere Datenbanken und Quellen werden weiter verarbeitet.'');
            END CATCH;';
            BEGIN TRY
                EXEC [sys].[sp_executesql] @Sql,
                     N'@DatabaseId int,@DatabaseName sysname,@CapturedAtUtc datetime2(3)',
                     @DatabaseId=@DatabaseId,@DatabaseName=@DatabaseName,@CapturedAtUtc=@CapturedAtUtc;
            END TRY
            BEGIN CATCH
                INSERT [#DatabaseConfigurationAnalysis_SourceStatus]
                VALUES(@DatabaseId,@DatabaseName,N'databaseLocalCatalogs',N'sys.database_scoped_configurations|sys.database_query_store_options',@CapturedAtUtc,
                       CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                       1,0,ERROR_NUMBER(),ERROR_MESSAGE(),N'Dynamische Kompilierungs- oder Zustandsänderung; andere Datenbanken werden weiter verarbeitet.');
            END CATCH;
            FETCH NEXT FROM [DatabaseCursor] INTO @DatabaseId,@DatabaseName;
        END;
        CLOSE [DatabaseCursor]; DEALLOCATE [DatabaseCursor];
    END;

    IF @StatusCode='AVAILABLE'
    BEGIN
        ;WITH [ValueCounts] AS
        (
            SELECT [SettingScope],[SettingName],[ActualValue],COUNT(*) AS [ValueDatabaseCount]
            FROM [#DatabaseConfigurationAnalysis_Settings]
            GROUP BY [SettingScope],[SettingName],[ActualValue]
        ),
        [RankedValues] AS
        (
            SELECT [SettingScope],[SettingName],[ActualValue],[ValueDatabaseCount],
                   SUM([ValueDatabaseCount]) OVER(PARTITION BY [SettingScope],[SettingName]) AS [ComparedDatabaseCount],
                   ROW_NUMBER() OVER(PARTITION BY [SettingScope],[SettingName] ORDER BY [ValueDatabaseCount] DESC,[ActualValue]) AS [ReferenceRank],
                   COUNT(*) OVER(PARTITION BY [SettingScope],[SettingName]) AS [DistinctValueCount]
            FROM [ValueCounts]
        ),
        [ReferenceValues] AS
        (
            SELECT [SettingScope],[SettingName],[ActualValue] AS [ReferenceValue],[ValueDatabaseCount],[ComparedDatabaseCount]
            FROM [RankedValues] WHERE [ReferenceRank]=1 AND [DistinctValueCount]>1
        )
        INSERT [#DatabaseConfigurationAnalysis_Drift]
        SELECT @CapturedAtUtc,'LOCAL_VARIATION',[s].[DatabaseId],[s].[DatabaseName],[s].[SettingScope],[s].[SettingName],
               [s].[ActualValue],[r].[ReferenceValue],[vc].[ValueDatabaseCount],[r].[ComparedDatabaseCount],
               'LOCAL_CONFIGURATION_VARIATION',
               N'Der häufigste sichtbare Wert ist nur eine lokale Vergleichsreferenz und kein Sollwert; Gleichstand wird deterministisch nach Wert aufgelöst.'
        FROM [#DatabaseConfigurationAnalysis_Settings] AS [s]
        INNER JOIN [ReferenceValues] AS [r] ON [r].[SettingScope]=[s].[SettingScope] AND [r].[SettingName]=[s].[SettingName]
        INNER JOIN [ValueCounts] AS [vc] ON [vc].[SettingScope]=[s].[SettingScope] AND [vc].[SettingName]=[s].[SettingName]
                                        AND ISNULL([vc].[ActualValue],N'<NULL>')=ISNULL([s].[ActualValue],N'<NULL>')
        WHERE ISNULL([s].[ActualValue],N'<NULL>') COLLATE SQL_Latin1_General_CP1_CI_AS
             <>ISNULL([r].[ReferenceValue],N'<NULL>') COLLATE SQL_Latin1_General_CP1_CI_AS;

        INSERT [#DatabaseConfigurationAnalysis_Drift]
        SELECT @CapturedAtUtc,'PROFILE_MISMATCH',[s].[DatabaseId],[s].[DatabaseName],[s].[SettingScope],[s].[SettingName],
               [s].[ActualValue],[p].[ExpectedValue],NULL,1,'EXPLICIT_PROFILE_MISMATCH',
               N'Explizit geliefertes Sollprofil; der Befund ist eine Abweichung, aber ohne Change-Freigabe keine Änderungsanweisung.'
        FROM [#DatabaseConfigurationAnalysis_Settings] AS [s]
        INNER JOIN [#DatabaseConfigurationAnalysis_Profile] AS [p]
          ON [p].[SettingScope]=[s].[SettingScope]
         AND [p].[SettingName] COLLATE SQL_Latin1_General_CP1_CI_AS=[s].[SettingName] COLLATE SQL_Latin1_General_CP1_CI_AS
        WHERE ISNULL([s].[ActualValue],N'<NULL>') COLLATE SQL_Latin1_General_CP1_CI_AS
             <>ISNULL([p].[ExpectedValue],N'<NULL>') COLLATE SQL_Latin1_General_CP1_CI_AS;

        INSERT [#DatabaseConfigurationAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
        SELECT NULL,N'profile','PROFILE_SETTING_NOT_VISIBLE',NULL,
               CONCAT(N'Profileintrag nicht in sichtbarer Evidenz gefunden: ',[p].[SettingScope],N'/',[p].[SettingName],N'.')
        FROM [#DatabaseConfigurationAnalysis_Profile] AS [p]
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [#DatabaseConfigurationAnalysis_Settings] AS [s]
            WHERE [s].[SettingScope]=[p].[SettingScope]
              AND [s].[SettingName] COLLATE SQL_Latin1_General_CP1_CI_AS=[p].[SettingName] COLLATE SQL_Latin1_General_CP1_CI_AS
        );
    END;

    INSERT [#DatabaseConfigurationAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
    SELECT [DatabaseName],[SourceName],[StatusCode],[ErrorNumber],COALESCE([ErrorMessage],N'Quelle nicht verfügbar.')
    FROM [#DatabaseConfigurationAnalysis_SourceStatus] WHERE [IsPartial]=1;
    INSERT [#DatabaseConfigurationAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
    SELECT [RequestedName],N'databaseCandidates',[StatusCode],NULL,COALESCE([ErrorMessage],N'Datenbank nicht verarbeitet.')
    FROM [#DatabaseConfigurationAnalysis_CandidateWarnings];

    IF @StatusCode='AVAILABLE' AND EXISTS(SELECT 1 FROM [#DatabaseConfigurationAnalysis_Warnings] WHERE [StatusCode] NOT IN('PROFILE_SETTING_NOT_VISIBLE'))
        SELECT @StatusCode='AVAILABLE_LIMITED',@IsPartial=1;

    IF @StatusCode NOT IN('AVAILABLE','AVAILABLE_LIMITED')
        SET @IsPartial=1;

    SELECT TOP(1) @ErrorNumber=[ErrorNumber],@ErrorMessage=[Message]
    FROM [#DatabaseConfigurationAnalysis_Warnings]
    WHERE [StatusCode] NOT IN('PROFILE_SETTING_NOT_VISIBLE')
    ORDER BY [WarningOrdinal];

    DECLARE @SettingRows bigint=(SELECT COUNT_BIG(*) FROM [#DatabaseConfigurationAnalysis_Settings]);
    DECLARE @DriftRows bigint=(SELECT COUNT_BIG(*) FROM [#DatabaseConfigurationAnalysis_Drift]);
    INSERT [#DatabaseConfigurationAnalysis_ModuleStatus]
    VALUES(N'USP_DatabaseConfigurationAnalysis',@CapturedAtUtc,@StatusCode,@IsPartial,@CrossDatabaseRequested,
           (SELECT COUNT(*) FROM [#DatabaseConfigurationAnalysis_DatabaseCandidates]),
           CASE WHEN @SettingRows>@Limit THEN @Limit ELSE @SettingRows END,
           CASE WHEN @DriftRows>@Limit THEN @Limit ELSE @DriftRows END,
           (SELECT COUNT(*) FROM [#DatabaseConfigurationAnalysis_Profile]),
           CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @SettingRows>@Limit THEN 1 ELSE 0 END),
           CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @DriftRows>@Limit THEN 1 ELSE 0 END),
           @ErrorNumber,@ErrorMessage);

    ;WITH [RankedSettings] AS
    (
        SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseName],[SettingScope],[SettingName]) AS [OutputOrdinal]
        FROM [#DatabaseConfigurationAnalysis_Settings]
    )
    DELETE FROM [RankedSettings] WHERE [OutputOrdinal]>@Limit;
    ;WITH [RankedDrift] AS
    (
        SELECT *,ROW_NUMBER() OVER(ORDER BY [DriftType],[SettingScope],[SettingName],[DatabaseName]) AS [OutputOrdinal]
        FROM [#DatabaseConfigurationAnalysis_Drift]
    )
    DELETE FROM [RankedDrift] WHERE [OutputOrdinal]>@Limit;
    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=(SELECT N'DatabaseConfigurationAnalysis' [resultName],1 [schemaVersion],@CapturedAtUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],CASE WHEN @ProfileJson IS NULL THEN 'LOCAL_COMPARISON' ELSE 'LOCAL_AND_EXPLICIT_PROFILE' END [comparisonMode],@ErrorNumber [errorNumber],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @SettingsJson nvarchar(max)=(SELECT TOP(@Limit) * FROM [#DatabaseConfigurationAnalysis_Settings] ORDER BY [DatabaseName],[SettingScope],[SettingName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @DriftJson nvarchar(max)=(SELECT TOP(@Limit) * FROM [#DatabaseConfigurationAnalysis_Drift] ORDER BY [DriftType],[SettingScope],[SettingName],[DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @ProfileOutputJson nvarchar(max)=(SELECT * FROM [#DatabaseConfigurationAnalysis_Profile] ORDER BY [ProfileOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @SourceJson nvarchar(max)=(SELECT * FROM [#DatabaseConfigurationAnalysis_SourceStatus] ORDER BY [SourceOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max)=(SELECT * FROM [#DatabaseConfigurationAnalysis_Warnings] ORDER BY [WarningOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@MetaJson,N'{}'),N',"settings":',COALESCE(@SettingsJson,N'[]'),N',"drift":',COALESCE(@DriftJson,N'[]'),N',"profile":',COALESCE(@ProfileOutputJson,N'[]'),N',"sourceStatus":',COALESCE(@SourceJson,N'[]'),N',"warnings":',COALESCE(@WarningsJson,N'[]'),N'}');
    END;

    IF @ConsoleResultRequested=1
        EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#DatabaseConfigurationAnalysis_Drift',@ResultLabel=N'Datenbankkonfiguration und Drift',@EmptyMessage=N'Keine lokale Variation oder Profilabweichung sichtbar';
    ELSE IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#DatabaseConfigurationAnalysis_ModuleStatus];
        SELECT TOP(@Limit) * FROM [#DatabaseConfigurationAnalysis_Settings] ORDER BY [DatabaseName],[SettingScope],[SettingName];
        SELECT TOP(@Limit) * FROM [#DatabaseConfigurationAnalysis_Drift] ORDER BY [DriftType],[SettingScope],[SettingName],[DatabaseName];
        SELECT * FROM [#DatabaseConfigurationAnalysis_Profile] ORDER BY [ProfileOrdinal];
        SELECT * FROM [#DatabaseConfigurationAnalysis_SourceStatus] ORDER BY [SourceOrdinal];
        SELECT * FROM [#DatabaseConfigurationAnalysis_Warnings] ORDER BY [WarningOrdinal];
    END
    ELSE IF @OutputMode='TABLE'
    BEGIN
        DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
        DECLARE [ResultCursor] CURSOR LOCAL FAST_FORWARD FOR SELECT [ResultName],[TargetTable] FROM [#DatabaseConfigurationAnalysis_ResultTableMap] ORDER BY [ResultName];
        OPEN [ResultCursor]; FETCH NEXT FROM [ResultCursor] INTO @ResultName,@TargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @SourceTable=CASE @ResultName WHEN N'moduleStatus' THEN N'#DatabaseConfigurationAnalysis_ModuleStatus' WHEN N'settings' THEN N'#DatabaseConfigurationAnalysis_Settings' WHEN N'drift' THEN N'#DatabaseConfigurationAnalysis_Drift' WHEN N'profile' THEN N'#DatabaseConfigurationAnalysis_Profile' WHEN N'sourceStatus' THEN N'#DatabaseConfigurationAnalysis_SourceStatus' WHEN N'warnings' THEN N'#DatabaseConfigurationAnalysis_Warnings' END;
            EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,@ThrowOnError=1;
            FETCH NEXT FROM [ResultCursor] INTO @ResultName,@TargetTable;
        END;
        CLOSE [ResultCursor]; DEALLOCATE [ResultCursor];
    END;

    IF @PrintMeldungen=1 AND @StatusCode<>'AVAILABLE'
    BEGIN
        DECLARE @PrintMessage nvarchar(2048)=LEFT(CONCAT(N'USP_DatabaseConfigurationAnalysis: ',@StatusCode,N'. ',COALESCE(@ErrorMessage,N'Siehe warnings-Resultset.')),2048);
        RAISERROR(N'%s',10,1,@PrintMessage) WITH NOWAIT;
    END;
    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
END;
GO

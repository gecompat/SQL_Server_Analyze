USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentWaits
Version      : 4.0.0
Stand        : 2026-07-23
Zweck        : Liefert aktuelle Waiting Tasks sowie kumulativen oder
               gesampelten instanzweiten Wait-Kontext mit Listen- und
               Patternfiltern.
Ausgabe      : RAW, CONSOLE, NONE und optionales JSON mit currentTasks,
               instanceWaits und warnings.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentWaits]
      @SessionIds                    nvarchar(max)  = NULL
    , @MinWaitMs                    bigint         = 0
    , @WaitTypes                    nvarchar(max)  = NULL
    , @WaitTypePattern              nvarchar(4000) = NULL
    , @WaitGroups                   nvarchar(max)  = NULL
    , @WaitGroupPattern             nvarchar(4000) = NULL
    , @SystemSessionsEinbeziehen    bit            = 0
    , @ToolHintergrundabfragenEinbeziehen bit       = 0
    , @MitSqlText                   bit            = 1
    , @MaxSqlTextZeichen            int            = 2000
    , @SampleSeconds                tinyint        = 0
    , @UnkritischeWaitsEinbeziehen  bit            = 0
    , @TopWaitPercentage            decimal(5,2)   = 95.00
    , @MaxZeilen                    int            = 1000
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
    SET @Json=NULL;
    DECLARE @ModuleName sysname=N'USP_CurrentWaits',@CollectionTimeUtc datetime2(3)=SYSUTCDATETIME(),@MeasurementStartUtc datetime2(3)=NULL,@MeasurementEndUtc datetime2(3)=NULL;
    DECLARE @StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0,@TaskRowCount bigint=0,@InstanceRowCount bigint=0,@ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@Detail nvarchar(2000)=NULL,@DeltaStatus varchar(40)=CASE WHEN @SampleSeconds=0 THEN 'CUMULATIVE_CONTEXT' ELSE 'SKIPPED' END,@DeltaDetail nvarchar(2000)=NULL;
    DECLARE @RequiredPermission nvarchar(256)=CASE WHEN TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END;
    DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'currentTasks',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @EffectiveMaxZeilen bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen>0 THEN CONVERT(bigint,@MaxZeilen) ELSE CONVERT(bigint,0) END;
    DECLARE @CandidateMaxZeilen bigint,@MonitorPrintMessage nvarchar(2048),@StartBefore datetime,@StartAfter datetime;
    DECLARE @EvidenceSnapshotId uniqueidentifier=COALESCE(@ParentCurrentStateSnapshotId,NEWID());
    DECLARE @EvidenceSnapshotStartedAtUtc datetime2(3)=@CollectionTimeUtc;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_CurrentWaits; Snapshotdiagnostik, keine Historie.';
        PRINT N'Daten: sys.dm_os_waiting_tasks plus sys.dm_os_wait_stats kumulativ oder gesampelt.';
        PRINT N'Berechtigung: VIEW SERVER STATE bis 2019, VIEW SERVER PERFORMANCE STATE ab 2022.';
        PRINT N'@SessionIds: nvarchar(max); Default=NULL. Ausgelassen entspricht NULL und deaktiviert den Filter. TVF_ParseBigintList ersetzt jedes Komma und Semikolon durch Pipe (auch innerhalb von Klammern), danach trennt | außerhalb von [...]; ]] maskiert dort ]. Äußere Segmentleerzeichen werden getrimmt, Klammern werden für Zahlen nicht entquotet. Leere Liste/Elemente, fehlerhafte Klammern, Rohsegmente über 4000 UTF-16-Codeeinheiten, nicht bigint-konvertierbare Werte sowie IDs außerhalb 1..32767 ergeben INVALID_PARAMETER; Duplikate werden gruppiert. IDs beschränken nur Tasks; NULL lässt alle sichtbaren Session-IDs passieren.';
        PRINT N'@MinWaitMs: bigint; Default=0 ms. Ausgelassen nutzt 0. Ganze Zahlen ab 0 sind zulässig; negativ ist INVALID_PARAMETER. NULL wird nicht eigens abgelehnt, aber der Taskvergleich WaitDurationMs >= NULL ist nicht TRUE und lässt keine Taskzeile passieren. Begrenzt die Mindestdauer aktueller Waiting Tasks, nicht Instanz-Wait-Stats.';
        PRINT N'@WaitTypes: nvarchar(max); Default=NULL. Ausgelassen/NULL deaktiviert die exakte WaitType-Auswahl. Sonst bracket-aware Pipe-Liste nach TVF_ParseStringList: Pipe trennt außerhalb [...], innerhalb ist es Inhalt, ]] maskiert ]; getrimmte Einträge werden bei bracket-quotierten Einträgen entklammert/entmaskiert. Leere Liste/Elemente, ungültige Klammern, Rohsegment über 4000 UTF-16-Codeeinheiten oder Wertlänge über 120 ergeben INVALID_PARAMETER. Gültige Duplikate werden gruppiert. Vergleich ist exakt und case-sensitive unter SQL_Latin1_General_CP1_CS_AS; Typen müssen nicht im Katalog stehen. Exklusiv mit @WaitTypePattern, sobald beide nicht NULL sind. Filtert Task- und Instanzmengen.';
        PRINT N'@WaitTypePattern: nvarchar(4000); Default=NULL. Ausgelassen/NULL deaktiviert das Pattern. TVF_ParsePattern trimmt äußere Eingabezeichen, erkennt case-insensitiv regexi:, regex: und like:, entfernt genau das Präfix ohne erneutes Trimmen des Rests; ohne Präfix gilt LIKE. LIKE ist case-sensitive SQL-LIKE mit %, _ und []-Klassen; like: wählt denselben Modus. regex: ist case-sensitive (Flag c), regexi: case-insensitive (Flag i). Leere Eingabe oder leerer Präfixrest ist INVALID_PARAMETER; Leerzeichen nach Präfix bleiben Musterinhalt. Exklusiv mit @WaitTypes. Regex erfordert SQL Server 2025/Majorversion 17 und Compatibility Level >=170 der aktuellen Datenbank, sonst UNAVAILABLE_FEATURE. Wird spät auf Task-/Instanzkandidaten angewandt; Regex hebt das frühe Taskkandidatenlimit auf und normalisiert den Instanz-Prozentnenner danach nicht neu.';
        PRINT N'@WaitGroups: nvarchar(max); Default=NULL. Ausgelassen/NULL deaktiviert die exakte WaitGroup-Auswahl. Sonst gilt die bracket-aware Pipe-Liste von TVF_ParseStringList: | trennt außerhalb von [...], innerhalb ist es Literalinhalt und ]] maskiert eine schließende Klammer; äußere Leerzeichen der Segmente werden getrimmt. Bei bracket-quotierten Elementen werden die äußeren Klammern entfernt und ]] zu ] entmaskiert. Leere Gesamtliste, leere Elemente, fehlerhafte Klammern, Rohsegmente über 4000 UTF-16-Codeeinheiten und nach Entquotung leere Werte sind ungültig; Wertlänge über 64 ergibt INVALID_PARAMETER. Gültige Duplikate werden gruppiert. Beliebige syntaktisch gültige Namen sind als Filterwert zulässig; Treffer entstehen nur bei exakter case-sensitiver Übereinstimmung mit einer WaitGroup, die TVF_WaitTypeInfo für die jeweilige Waittypzeile liefert. Ein endlicher erlaubter Namenskatalog ist nicht im Parameterparser festgelegt. Exklusiv mit @WaitGroupPattern, wenn beide nicht NULL sind. Begrenzt Tasks und Instanz-Waits.';
        PRINT N'@WaitGroupPattern: nvarchar(4000); Default=NULL. Ausgelassen/NULL deaktiviert. Präfix-, Trim-, LIKE-/Regex-, Leerwert- und Regexvoraussetzungen entsprechen @WaitTypePattern; LIKE und Regex vergleichen case-sensitive/case-insensitive gemäß Modus mit der Katalog-WaitGroup. Exklusiv mit @WaitGroups. Regex wird spät angewandt, hebt das frühe Tasklimit auf und entfernt Instanzzeilen nach der Prozentberechnung, ohne den Nenner neu zu normalisieren.';
        PRINT N'@SystemSessionsEinbeziehen: bit; Default=0. Ausgelassen ergibt 0. 0 schließt Tasks von System-Sessions aus (is_user_process=0); 1 bezieht sie ein. NULL ist nicht als ungültig validiert und wird wie nicht gleich 1 behandelt: User-Sessions passieren, System-Sessions nicht. Numerische Eingaben werden vor Procedure-Eintritt zu bit konvertiert (0→0, Nichtnull→1). Nur Taskpfad.';
        PRINT N'@ToolHintergrundabfragenEinbeziehen: bit; Default=0. Ausgelassen ergibt 0. 0 blendet als Tool-Hintergrundabfrage erkannte Tasks aus; 1 bezieht sie mit Klassifikationsfeldern ein. NULL und jeder nach Konvertierung nicht als 0/1 zulässige Wert führen zu INVALID_PARAMETER. Numerische Eingaben konvertieren vor Eintritt zu bit (0→0, Nichtnull→1). Filter betrifft Tasks, nicht Instanz-Wait-Stats; Erkennung beruht auf dem Toolklassifikationshelper und ist keine Sicherheitsgrenze.';
        PRINT N'@MitSqlText: bit; Default=1. Ausgelassen ergibt 1. 1 versucht den aktuellen Statementtext für Taskzeilen aus dem jeweiligen Requestkontext zu ergänzen; 0 unterdrückt Textzugriff/-projektion. NULL ist nicht eigens ungültig und folgt den IF/CASE-Gleich-1-Pfaden, damit wird Text nicht ergänzt. Numerische Werte werden vor Eintritt zu bit konvertiert. Bei Parent-Snapshot wird vorhandener gemeinsamer Text nur bei Aktivierung konsumiert; die Taskquellen können unabhängig vom Filter bereits materialisiert sein.';
        PRINT N'@MaxSqlTextZeichen: int; Default=2000 Zeichen. Ausgelassen nutzt 2000. Nichtnegative Ganzzahl zulässig; negativ ist INVALID_PARAMETER. NULL und 0 heben die durch diesen Grenzwert bewirkte Zeichenbegrenzung auf. Positive Werte begrenzen/kürzen CurrentStatement nach dieser Zahl und können Trunkierungswarnungen erzeugen. Steuert Textbreite, nicht Kandidatenzahl.';
        PRINT N'@SampleSeconds: tinyint; Default=0 Sekunden. Ausgelassen ergibt 0; zulässiger Bereich 0..60, Werte über 60 ergeben INVALID_PARAMETER (tinyint-Konvertierung erfolgt vor Eintritt). 0 liefert kumulative sys.dm_os_wait_stats; 1..60 liest Wait-Stats vor und nach WAITFOR DELAY der entsprechenden Sekundenzahl und bildet daraus das Delta; aktuelle Tasks werden zuvor einmal als Snapshot erfasst und nicht erneut gesampelt. NULL besteht die Vergleichsvalidierung, wird als Nicht-0 in den Delta-Zweig geleitet und erzeugt bei DATEADD/WAITFOR-Konvertierung einen behandelten Samplingfehler/partielle Delta-Sicht. Bei ParentCurrentStateSnapshotId werden Tasks/Sessions/Requests/Text aus dem Elternsnapshot bezogen, Wait-Stats-Sampling bleibt ein eigener Messpunkt.';
        PRINT N'@UnkritischeWaitsEinbeziehen: bit; Default=0. Ausgelassen ergibt 0. 0 schließt Instanz-Waitzeilen aus, deren Katalogfeld IsGenerallyBenign=1 ist; 1 lässt sie in die Instanzstatistik ein. Das ist keine globale Aussage, dass ein Wait bei konkreter Workloadauswirkung unkritisch wäre. NULL wird nicht abgelehnt und der Vergleich =1 ist nicht TRUE, daher werden nur Katalogzeilen mit IsGenerallyBenign=0 aufgenommen; NULL-Katalogklassifikation passiert ebenfalls nicht. Numerische Eingaben werden vor Eintritt zu bit konvertiert. Taskfilter werden davon nicht verändert.';
        PRINT N'@TopWaitPercentage: decimal(5,2); Default=95.00 Prozent. Ausgelassen nutzt 95.00. Zulässig ist >0 und <=100; 0, negative oder >100 ergeben INVALID_PARAMETER. NULL wird nicht eigens abgelehnt; Validierungsvergleiche sind UNKNOWN und der spätere Cutoffvergleich entfernt keine Zeilen. Die Prozentwerte und ihr Nenner entstehen nach Benign-, exakten Listen- und LIKE-Filtern. Danach entfernt Regex weitere Zeilen ohne Neuberechnung dieser Prozentwerte; erst anschließend folgen Kumulierung und der Cutoff CumulativePercentage - WaitPercentage >= Wert.';
        PRINT N'@MaxZeilen: int; Default=1000 Zeilen je Fachmenge. Ausgelassen nutzt 1000; negativ ist INVALID_PARAMETER; NULL oder 0 bedeutet unbegrenzt. Positiver Wert begrenzt Tasks und Instanz-Waits jeweils separat nach ihrer Auswahlordnung. Beim einfachen Taskpfad werden höchstens N+1 Kandidaten gelesen, um Abschneidung zu erkennen; bei N=int-Max wird Kandidatengrenze als bigint N+1 berechnet und ist daher 2147483648, kein int-Überlauf. Regex oder unbegrenzte Ausgabe hebt dieses frühe Kandidatenlimit auf; spätere Zeilenbegrenzung bleibt. Instanzwerte werden vollständig aggregiert und danach begrenzt.';
        PRINT N'@ResultSetArt: varchar(16); Default=''CONSOLE''. Ausgelassen nutzt CONSOLE. Nach LTRIM/RTRIM und UPPER sind genau RAW (Status, Task-/Instanzdaten, Warnings), CONSOLE (Taskgrid mit Beschriftung; bei leerer Menge Hinweiszeile), TABLE (Export nur currentTasks in geprüftes Ziel) und NONE (keine fachlichen Resultsets) zulässig; sonst INVALID_PARAMETER. NULL wird zu leerem Text normalisiert und ist ungültig. Werte sind case-insensitive. Nichtleeres @ResultTablesJson außerhalb TABLE wirft vor Hilfe 51011.';
        PRINT N'@ResultTablesJson: nvarchar(max); Default=NULL. Bei @ResultSetArt=TABLE erforderlich: gültiges, nichtleeres JSON-Objekt mit exakt case-sensitivem Schlüssel currentTasks und einem nichtleeren JSON-String als Wert. Der String benennt exakt (ohne Trim-Normalisierung) eine vorhandene lokale #Temp-Tabelle; LTRIM/RTRIM mit SQL-Standard-Leerzeichen U+0020 prüft nur, ob der Zielname leer ist. Zulässig sind Namen mit führendem #, nicht ##, höchstens 116 Zeichen gemäß SQL-LEN-Prüfung und nicht mit #Monitor beginnend (Präfixprüfung case-insensitiv); Ziel muss leer sein und genau eine Seed-Spalte beliebigen Typs haben. Unbekannter/duplizierter Schlüssel oder Ziel, falscher JSON-Werttyp, ungültige JSON-Form, fehlendes oder unzulässiges Ziel sowie befülltes oder abweichend spaltiges Ziel werfen beim Preflight 51011. Außerhalb TABLE müssen NULL, leer oder nach LTRIM/RTRIM nur gewöhnliche U+0020-Leerzeichen stehen; eine danach nichtleere Map wirft vor Hilfe 51011.';
        PRINT N'@JsonErzeugen: bit; Default=0. Ausgelassen ergibt 0. 0 deaktiviert JSON; 1 erzeugt unabhängig von ResultSetArt ein JSON-Objekt mit meta, currentTasks, instanceWaits und warnings. NULL wird nicht eigens abgelehnt und der IF-Gleich-1-Zweig wird nicht ausgeführt, sodass kein JSON erzeugt wird. Numerische Eingaben werden vor Eintritt zu bit konvertiert (0→0, Nichtnull→1).';
        PRINT N'@Json: nvarchar(max) OUTPUT; Default=NULL. Zum Empfang muss eine nvarchar(max)-Variable gebunden und im EXEC mit OUTPUT markiert werden. Procedure setzt den Parameter beim Eintritt auf NULL; mit @JsonErzeugen=1 enthält er das Envelope, sonst bleibt er NULL. Ohne Bindung kann der Wert nicht empfangen werden.';
        PRINT N'@PrintMeldungen: bit; Default=1. Ausgelassen ergibt 1. 1 erlaubt optionale Zusatz-/Warnmeldungen, 0 unterdrückt sie; Ergebnissets und JSON bleiben davon unabhängig. NULL wird nicht validiert und die Gleich-1-Ausgabezweige bleiben aus. Numerische Werte werden vor Eintritt zu bit konvertiert (0→0, Nichtnull→1).';
        PRINT N'@Hilfe: bit; Default=0. Ausgelassen ergibt 0. Genau 1 druckt Hilfe und beendet vor fachlicher Analyse; 0 führt regulär aus. NULL wird nicht als Hilfe erkannt und ist nicht ungültig; numerische Werte werden vor Eintritt zu bit konvertiert. Vor diesem Zweig gilt: Bei nicht-TABLE ist eine nach LTRIM/RTRIM (gewöhnliche U+0020-Leerzeichen) nichtleere @ResultTablesJson-Map unzulässig und wirft 51011; bei TABLE läuft der Einzelziel-Preflight und kann ebenfalls 51011 werfen. Daher kann eine unzulässige Map auch mit Hilfe den Aufruf abbrechen.';
        PRINT N'@ParentCurrentStateSnapshotId: uniqueidentifier; Default=NULL. Ausgelassen/NULL erzeugt eine eigene Snapshot-ID und liest Quellen selbst. Ein GUID bindet Tasks, Sessions, Requests und gegebenenfalls SQL-Text an die gleichnamige, im aufrufenden Sessionkontext vorhandene Parent-Snapshot-ID mit OwnerSessionId=@@SPID und ContractVersion=2; fehlender/fremder/unpassender Kontext führt zu behandelten Fehler-/Partialstatus. Instanzweite Wait-Stats werden weiterhin separat kumulativ oder im Sample gelesen. Ungültig formatierte Eingaben scheitern bereits bei SQL-Konvertierung zu uniqueidentifier.';
        PRINT N'Regex benötigt SQL Server 2025 und Compatibility Level 170.';
        PRINT N'RAW/JSON enthalten Status und Warnungen; ungültige Kombinationen ergeben INVALID_PARAMETER, Regex ohne Voraussetzung UNAVAILABLE_FEATURE. JSON enthält meta, currentTasks, instanceWaits und warnings. TABLE-Preflight läuft vor der Hilfe und kann bei ungültigem Mapping werfen.';
        PRINT N'CONSOLE:';
        PRINT N'EXEC [monitor].[USP_CurrentWaits] @ResultSetArt=''CONSOLE'';';
        PRINT N'TABLE-Mapping separat deklarieren; lokale Ziele müssen leere Einspalten-#Temp-Tabellen sein:';
        PRINT N'DECLARE @Tables nvarchar(max);';
        PRINT N'SELECT @Tables=(SELECT N''#CurrentWaits_HelpExample'' AS [currentTasks] FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);';
        PRINT N'CREATE TABLE #CurrentWaits_HelpExample (Seed int NULL);';
        PRINT N'EXEC [monitor].[USP_CurrentWaits] @ResultSetArt=''TABLE'', @ResultTablesJson=@Tables;';
        PRINT N'SELECT * FROM #CurrentWaits_HelpExample;';
        PRINT N'DROP TABLE #CurrentWaits_HelpExample;';
        PRINT N'JSON:';
        PRINT N'DECLARE @Json nvarchar(max);';
        PRINT N'EXEC [monitor].[USP_CurrentWaits] @JsonErzeugen=1, @Json=@Json OUTPUT;';
        PRINT N'SELECT @Json AS [Json];';
        RETURN;
    END;

    CREATE TABLE [#CurrentWaits_SessionIdFilter]([SessionId] smallint NOT NULL PRIMARY KEY);
    CREATE TABLE [#CurrentWaits_WaitTypeFilter]([WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY);
    CREATE TABLE [#CurrentWaits_WaitGroupFilter]([WaitGroup] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY);
    DECLARE @WaitTypeMode varchar(8),@WaitTypeValue nvarchar(4000),@WaitTypeFlags varchar(8),@WaitTypeValid bit;
    DECLARE @WaitGroupMode varchar(8),@WaitGroupValue nvarchar(4000),@WaitGroupFlags varchar(8),@WaitGroupValid bit;
    SELECT @WaitTypeMode=[PatternMode],@WaitTypeValue=[PatternValue],@WaitTypeFlags=[RegexFlags],@WaitTypeValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@WaitTypePattern);
    SELECT @WaitGroupMode=[PatternMode],@WaitGroupValue=[PatternValue],@WaitGroupFlags=[RegexFlags],@WaitGroupValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@WaitGroupPattern);

    IF @SessionIds IS NOT NULL
    BEGIN
        IF EXISTS(SELECT 1 FROM [monitor].[TVF_ParseBigintList](@SessionIds) WHERE [IsValid]=0 OR [NumberValue] NOT BETWEEN 1 AND 32767) SET @StatusCode='INVALID_PARAMETER';
        ELSE INSERT [#CurrentWaits_SessionIdFilter] SELECT CONVERT(smallint,[NumberValue]) FROM [monitor].[TVF_ParseBigintList](@SessionIds) GROUP BY [NumberValue];
    END;
    IF @StatusCode='AVAILABLE' AND ((@WaitTypes IS NOT NULL AND @WaitTypePattern IS NOT NULL) OR (@WaitGroups IS NOT NULL AND @WaitGroupPattern IS NOT NULL) OR @WaitTypeValid=0 OR @WaitGroupValid=0) SET @StatusCode='INVALID_PARAMETER';
    IF @StatusCode='AVAILABLE' AND ((@WaitTypes IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseStringList](@WaitTypes) WHERE [IsValid]=0 OR LEN([StringValue])>120)) OR (@WaitGroups IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseStringList](@WaitGroups) WHERE [IsValid]=0 OR LEN([StringValue])>64))) SET @StatusCode='INVALID_PARAMETER';
    IF @StatusCode='AVAILABLE'
    BEGIN
        INSERT [#CurrentWaits_WaitTypeFilter] SELECT CONVERT(nvarchar(120),[StringValue]) FROM [monitor].[TVF_ParseStringList](@WaitTypes) WHERE [IsValid]=1 GROUP BY [StringValue];
        INSERT [#CurrentWaits_WaitGroupFilter] SELECT CONVERT(nvarchar(64),[StringValue]) FROM [monitor].[TVF_ParseStringList](@WaitGroups) WHERE [IsValid]=1 GROUP BY [StringValue];
    END;
    DECLARE @HasRegex bit=CASE WHEN @WaitTypeMode IN('REGEX','REGEXI') OR @WaitGroupMode IN('REGEX','REGEXI') THEN 1 ELSE 0 END;
    IF @StatusCode='AVAILABLE' AND @HasRegex=1 AND (TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17 OR (SELECT [compatibility_level] FROM [master].[sys].[databases] WITH(NOLOCK) WHERE [database_id]=DB_ID())<170) BEGIN SET @StatusCode='UNAVAILABLE_FEATURE';SET @ErrorMessage=N'Regex benötigt SQL Server 2025 und Compatibility Level 170.';END;
    IF @StatusCode='AVAILABLE' AND (@MinWaitMs<0 OR @SampleSeconds>60 OR @TopWaitPercentage<=0 OR @TopWaitPercentage>100 OR @MaxZeilen<0 OR @MaxSqlTextZeichen<0 OR @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') OR @ToolHintergrundabfragenEinbeziehen IS NULL OR @ToolHintergrundabfragenEinbeziehen NOT IN(0,1)) SET @StatusCode='INVALID_PARAMETER';
    IF @StatusCode='INVALID_PARAMETER' SET @ErrorMessage=COALESCE(@ErrorMessage,N'Ungültige Liste, Kombination, Pattern- oder Steuerangabe.');

    CREATE TABLE [#CurrentWaits_Tasks]
    (
        [SessionId] smallint NULL,[ExecContextId] int NULL,[WaitDurationMs] bigint NULL,[WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BlockingSessionId] smallint NULL,[ResourceDescription] nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SessionStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsToolBackgroundQuery] bit NOT NULL,[ToolBackgroundRuleCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ToolBackgroundCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ToolBackgroundDetection] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ToolBackgroundConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DatabaseId] smallint NULL,[Command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CurrentStatementCharacters] bigint NULL,[CurrentStatementBytes] bigint NULL,[CurrentStatementIsTruncated] bit NOT NULL DEFAULT(0),[CurrentStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitGroup] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitSeverity] tinyint NULL,[IsGenerallyBenign] bit NULL,[WaitMeaning] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitTypicalOccurrence] nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[HighWaitImpact] nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RecommendedChecks] nvarchar(1500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitHelpUrl] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DescriptionSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DescriptionQuality] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CatalogMatchType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#CurrentWaits_A]([WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY,[WaitingTasksCount] bigint,[WaitTimeMs] bigint,[SignalWaitTimeMs] bigint);
    CREATE TABLE [#CurrentWaits_B]([WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY,[WaitingTasksCount] bigint,[WaitTimeMs] bigint,[SignalWaitTimeMs] bigint);
    CREATE TABLE [#CurrentWaits_RawInstance]([WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[WaitingTasksCount] bigint NULL,[WaitTimeMs] bigint NULL,[SignalWaitTimeMs] bigint NULL,[ResourceWaitTimeMs] bigint NULL,[SampleSeconds] int NULL,[MeasurementType] varchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#CurrentWaits_Instance]
    (
        [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[WaitingTasksCount] bigint NULL,[WaitTimeMs] bigint NULL,[SignalWaitTimeMs] bigint NULL,[ResourceWaitTimeMs] bigint NULL,[SampleSeconds] int NULL,[MeasurementType] varchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[WaitGroup] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitSeverity] tinyint NULL,[IsGenerallyBenign] bit NULL,[WaitMeaning] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitTypicalOccurrence] nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[HighWaitImpact] nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RecommendedChecks] nvarchar(1500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitHelpUrl] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DescriptionSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DescriptionQuality] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CatalogMatchType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitPercentage] decimal(9,4) NULL,[CumulativePercentage] decimal(9,4) NULL,[AverageWaitMs] decimal(19,4) NULL,[AverageResourceWaitMs] decimal(19,4) NULL,[AverageSignalWaitMs] decimal(19,4) NULL
    );
    CREATE TABLE [#CurrentWaits_Warnings]([WarningCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[WarningMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#CurrentWaits_SourceWaitingTasks]
    (
          [waiting_task_address] varbinary(8) NOT NULL
        , [session_id] smallint NULL
        , [exec_context_id] int NULL
        , [wait_duration_ms] bigint NOT NULL
        , [wait_type] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [blocking_session_id] smallint NULL
        , [resource_description] nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#CurrentWaits_SourceSessions]
    (
          [session_id] smallint NOT NULL PRIMARY KEY
        , [is_user_process] bit NOT NULL
        , [status] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [login_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [host_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [program_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#CurrentWaits_SourceRequests]
    (
          [session_id] smallint NOT NULL
        , [request_id] int NOT NULL
        , [status] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [database_id] smallint NOT NULL
        , [command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [sql_handle] varbinary(64) NULL
        , [statement_start_offset] int NULL
        , [statement_end_offset] int NULL
        , PRIMARY KEY([session_id],[request_id])
    );
    CREATE TABLE [#CurrentWaits_SourceSqlText]
    (
          [SqlHandle] varbinary(64) NOT NULL PRIMARY KEY
        , [Text] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    SET @CandidateMaxZeilen=CASE WHEN @HasRegex=1 OR @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen)+1 END;

    IF @StatusCode='AVAILABLE'
    BEGIN
        BEGIN TRY
            IF @ParentCurrentStateSnapshotId IS NOT NULL
            BEGIN
                EXEC [sys].[sp_executesql] N'
                    DECLARE @Probe int;
                    SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Context] WHERE 1=0;
                    SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_SourceStatus] WHERE 1=0;
                    SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_WaitingTasks] WHERE 1=0;
                    SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Sessions] WHERE 1=0;
                    SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Requests] WHERE 1=0;
                    SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_SqlText] WHERE 1=0;';

                IF NOT EXISTS
                (
                    SELECT 1
                    FROM [#CurrentOverview_CurrentStateSnapshot_Context]
                    WHERE [SnapshotId]=@ParentCurrentStateSnapshotId
                      AND [OwnerSessionId]=CONVERT(smallint,@@SPID)
                      AND [ContractVersion]=2
                )
                    THROW 51020,N'Die Parent-Snapshot-ID gehört nicht zum aktuellen Aufruf.',1;

                INSERT [#CurrentWaits_SourceWaitingTasks]
                SELECT
                      [waiting_task_address],[session_id],[exec_context_id],[wait_duration_ms]
                    , [wait_type],[blocking_session_id],[resource_description]
                FROM [#CurrentOverview_CurrentStateSnapshot_WaitingTasks]
                WHERE [SnapshotId]=@ParentCurrentStateSnapshotId;

                INSERT [#CurrentWaits_SourceSessions]
                SELECT [session_id],[is_user_process],[status],[login_name],[host_name],[program_name]
                FROM [#CurrentOverview_CurrentStateSnapshot_Sessions]
                WHERE [SnapshotId]=@ParentCurrentStateSnapshotId;

                INSERT [#CurrentWaits_SourceRequests]
                SELECT
                      [session_id],[request_id],[status],[database_id],[command],[sql_handle]
                    , [statement_start_offset],[statement_end_offset]
                FROM [#CurrentOverview_CurrentStateSnapshot_Requests]
                WHERE [SnapshotId]=@ParentCurrentStateSnapshotId;

                IF @MitSqlText=1
                    INSERT [#CurrentWaits_SourceSqlText]
                    SELECT [SqlHandle],[Text]
                    FROM [#CurrentOverview_CurrentStateSnapshot_SqlText]
                    WHERE [SnapshotId]=@ParentCurrentStateSnapshotId;

                SELECT
                      @EvidenceSnapshotStartedAtUtc=MIN([CapturedAtUtc])
                    , @IsPartial=CONVERT(bit,MAX(CONVERT(int,[IsPartial])))
                FROM [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
                WHERE [SnapshotId]=@ParentCurrentStateSnapshotId
                  AND [SourceCode] IN ('WAITING_TASKS','SESSIONS','REQUESTS','SQL_TEXT');
            END
            ELSE
            BEGIN
                SET @EvidenceSnapshotStartedAtUtc=SYSUTCDATETIME();
                INSERT [#CurrentWaits_SourceWaitingTasks]
                SELECT
                      [waiting_task_address],[session_id],[exec_context_id],[wait_duration_ms]
                    , [wait_type],[blocking_session_id],[resource_description]
                FROM [sys].[dm_os_waiting_tasks] WITH (NOLOCK);

                INSERT [#CurrentWaits_SourceSessions]
                SELECT [session_id],[is_user_process],[status],[login_name],[host_name],[program_name]
                FROM [sys].[dm_exec_sessions] WITH (NOLOCK);

                INSERT [#CurrentWaits_SourceRequests]
                SELECT
                      [session_id],[request_id],[status],[database_id],[command],[sql_handle]
                    , [statement_start_offset],[statement_end_offset]
                FROM [sys].[dm_exec_requests] WITH (NOLOCK);

                IF @MitSqlText=1
                    INSERT [#CurrentWaits_SourceSqlText]
                    SELECT [h].[SqlHandle],[t].[text]
                    FROM
                    (
                        SELECT [sql_handle] AS [SqlHandle]
                        FROM [#CurrentWaits_SourceRequests]
                        WHERE [sql_handle] IS NOT NULL
                        GROUP BY [sql_handle]
                    ) AS [h]
                    OUTER APPLY [sys].[dm_exec_sql_text]([h].[SqlHandle]) AS [t];
            END;
        END TRY
        BEGIN CATCH
            SET @ErrorNumber=ERROR_NUMBER();
            SET @ErrorMessage=ERROR_MESSAGE();
            SET @IsPartial=1;
            SET @StatusCode=CASE
                WHEN @ErrorNumber=1222 THEN 'TIMEOUT'
                WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                WHEN @ParentCurrentStateSnapshotId IS NOT NULL
                 AND @ErrorNumber IN(208,51020) THEN 'INVALID_PARENT_SNAPSHOT'
                ELSE 'ERROR_HANDLED' END;
            INSERT [#CurrentWaits_Warnings] VALUES(@StatusCode,@ErrorMessage);
        END CATCH;

        BEGIN TRY
            INSERT [#CurrentWaits_Tasks]
            SELECT TOP(@CandidateMaxZeilen) [w].[session_id],[w].[exec_context_id],[w].[wait_duration_ms],[w].[wait_type],NULLIF([w].[blocking_session_id],0),[w].[resource_description],[s].[status],[r].[status],[s].[login_name],[s].[host_name],[s].[program_name],[tool].[IsToolBackgroundQuery],[tool].[ToolBackgroundRuleCode],[tool].[ToolBackgroundCategory],[tool].[ToolBackgroundDetection],[tool].[ToolBackgroundConfidence],[r].[database_id],[r].[command],NULL,NULL,CONVERT(bit,0),CASE WHEN @MitSqlText=1 THEN [st].[StatementText] END,[wi].[WaitGroup],[wi].[Severity],[wi].[IsGenerallyBenign],[wi].[Meaning],[wi].[TypicalOccurrence],[wi].[HighWaitImpact],[wi].[RecommendedChecks],[wi].[HelpUrl],[wi].[DescriptionSource],[wi].[DescriptionQuality],[wi].[CatalogMatchType]
            FROM [#CurrentWaits_SourceWaitingTasks] AS [w]
            LEFT JOIN [#CurrentWaits_SourceSessions] AS [s] ON [s].[session_id]=[w].[session_id]
            LEFT JOIN [#CurrentWaits_SourceRequests] AS [r] ON [r].[session_id]=[w].[session_id]
            CROSS APPLY [monitor].[TVF_ToolBackgroundQueryInfo]([s].[program_name]) AS [tool]
            LEFT JOIN [#CurrentWaits_SourceSqlText] AS [t]
              ON [t].[SqlHandle]=CASE WHEN @MitSqlText=1 THEN [r].[sql_handle] END
            OUTER APPLY [monitor].[TVF_StatementText]([t].[Text],[r].[statement_start_offset],[r].[statement_end_offset]) AS [st]
            CROSS APPLY [monitor].[TVF_WaitTypeInfo]([w].[wait_type]) AS [wi]
            WHERE (NOT EXISTS(SELECT 1 FROM [#CurrentWaits_SessionIdFilter]) OR EXISTS(SELECT 1 FROM [#CurrentWaits_SessionIdFilter] AS [f] WHERE [f].[SessionId]=[w].[session_id]))
              AND [w].[wait_duration_ms]>=@MinWaitMs AND (@SystemSessionsEinbeziehen=1 OR COALESCE([s].[is_user_process],1)=1)
              AND (@ToolHintergrundabfragenEinbeziehen=1 OR [tool].[IsToolBackgroundQuery]=0)
              AND (NOT EXISTS(SELECT 1 FROM [#CurrentWaits_WaitTypeFilter]) OR EXISTS(SELECT 1 FROM [#CurrentWaits_WaitTypeFilter] AS [f] WHERE [f].[WaitType]=[w].[wait_type] COLLATE SQL_Latin1_General_CP1_CS_AS))
              AND (NOT EXISTS(SELECT 1 FROM [#CurrentWaits_WaitGroupFilter]) OR EXISTS(SELECT 1 FROM [#CurrentWaits_WaitGroupFilter] AS [f] WHERE [f].[WaitGroup]=[wi].[WaitGroup] COLLATE SQL_Latin1_General_CP1_CS_AS))
              AND (@WaitTypeMode<>'LIKE' OR [w].[wait_type] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @WaitTypeValue COLLATE SQL_Latin1_General_CP1_CS_AS)
              AND (@WaitGroupMode<>'LIKE' OR [wi].[WaitGroup] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @WaitGroupValue COLLATE SQL_Latin1_General_CP1_CS_AS)
            ORDER BY [w].[wait_duration_ms] DESC,[w].[session_id];
            SET @Detail=CASE WHEN @@ROWCOUNT=0 THEN N'Aktuell keine passende wartende Task sichtbar.' ELSE N'Aktuelle Waiting Tasks erfolgreich gelesen.' END;
        END TRY
        BEGIN CATCH
            SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();SET @IsPartial=1;SET @StatusCode=CASE WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN @ErrorNumber=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END;INSERT [#CurrentWaits_Warnings] VALUES(@StatusCode,@ErrorMessage);
        END CATCH;

        IF @SampleSeconds=0
        BEGIN TRY
            SET @MeasurementStartUtc=SYSUTCDATETIME();
            INSERT [#CurrentWaits_RawInstance] SELECT [wait_type],[waiting_tasks_count],[wait_time_ms],[signal_wait_time_ms],[wait_time_ms]-[signal_wait_time_ms],NULL,'INSTANCE_CUMULATIVE' FROM [sys].[dm_os_wait_stats] WITH (NOLOCK) WHERE [waiting_tasks_count]>0;
            SET @MeasurementEndUtc=SYSUTCDATETIME();SET @DeltaStatus='CUMULATIVE_CONTEXT';SET @DeltaDetail=N'Kumulativ seit SQL-Server-Start oder letztem Reset.';
        END TRY BEGIN CATCH SET @DeltaStatus='ERROR_HANDLED';SET @DeltaDetail=ERROR_MESSAGE();SET @IsPartial=1;INSERT [#CurrentWaits_Warnings] VALUES(@DeltaStatus,@DeltaDetail);END CATCH;
        ELSE
        BEGIN TRY
            SET @MeasurementStartUtc=SYSUTCDATETIME();SELECT @StartBefore=[sqlserver_start_time] FROM [sys].[dm_os_sys_info] WITH (NOLOCK);INSERT [#CurrentWaits_A] SELECT [wait_type],[waiting_tasks_count],[wait_time_ms],[signal_wait_time_ms] FROM [sys].[dm_os_wait_stats] WITH (NOLOCK);DECLARE @Delay char(8)=CONVERT(char(8),DATEADD(SECOND,@SampleSeconds,CONVERT(datetime,'19000101',112)),108);WAITFOR DELAY @Delay;SELECT @StartAfter=[sqlserver_start_time] FROM [sys].[dm_os_sys_info] WITH (NOLOCK);INSERT [#CurrentWaits_B] SELECT [wait_type],[waiting_tasks_count],[wait_time_ms],[signal_wait_time_ms] FROM [sys].[dm_os_wait_stats] WITH (NOLOCK);SET @MeasurementEndUtc=SYSUTCDATETIME();
            IF @StartBefore<>@StartAfter OR EXISTS(SELECT 1 FROM [#CurrentWaits_A] AS [a] JOIN [#CurrentWaits_B] AS [b] ON [b].[WaitType]=[a].[WaitType] WHERE [b].[WaitTimeMs]<[a].[WaitTimeMs] OR [b].[WaitingTasksCount]<[a].[WaitingTasksCount] OR [b].[SignalWaitTimeMs]<[a].[SignalWaitTimeMs]) BEGIN SET @DeltaStatus='MEASUREMENT_RESET';SET @DeltaDetail=N'Serverneustart oder Wait-Zählerreset während des Messfensters erkannt.';SET @IsPartial=1;INSERT [#CurrentWaits_Warnings] VALUES(@DeltaStatus,@DeltaDetail);END
            ELSE BEGIN INSERT [#CurrentWaits_RawInstance] SELECT [b].[WaitType],[b].[WaitingTasksCount]-COALESCE([a].[WaitingTasksCount],0),[b].[WaitTimeMs]-COALESCE([a].[WaitTimeMs],0),[b].[SignalWaitTimeMs]-COALESCE([a].[SignalWaitTimeMs],0),([b].[WaitTimeMs]-COALESCE([a].[WaitTimeMs],0))-([b].[SignalWaitTimeMs]-COALESCE([a].[SignalWaitTimeMs],0)),@SampleSeconds,'INSTANCE_DELTA' FROM [#CurrentWaits_B] AS [b] LEFT JOIN [#CurrentWaits_A] AS [a] ON [a].[WaitType]=[b].[WaitType] WHERE [b].[WaitTimeMs]-COALESCE([a].[WaitTimeMs],0)>0;SET @DeltaStatus='AVAILABLE';SET @DeltaDetail=CONCAT(N'Gültiges Wait-Delta über ',@SampleSeconds,N' Sekunden.');END;
        END TRY BEGIN CATCH SET @DeltaStatus='ERROR_HANDLED';SET @DeltaDetail=ERROR_MESSAGE();SET @IsPartial=1;INSERT [#CurrentWaits_Warnings] VALUES(@DeltaStatus,@DeltaDetail);END CATCH;

        INSERT [#CurrentWaits_Instance]
        SELECT [x].[WaitType],[x].[WaitingTasksCount],[x].[WaitTimeMs],[x].[SignalWaitTimeMs],[x].[ResourceWaitTimeMs],[x].[SampleSeconds],[x].[MeasurementType],[wi].[WaitGroup],[wi].[Severity],[wi].[IsGenerallyBenign],[wi].[Meaning],[wi].[TypicalOccurrence],[wi].[HighWaitImpact],[wi].[RecommendedChecks],[wi].[HelpUrl],[wi].[DescriptionSource],[wi].[DescriptionQuality],[wi].[CatalogMatchType],CONVERT(decimal(9,4),100.0*[x].[WaitTimeMs]/NULLIF(SUM([x].[WaitTimeMs]) OVER(),0)),NULL,CONVERT(decimal(19,4),1.0*[x].[WaitTimeMs]/NULLIF([x].[WaitingTasksCount],0)),CONVERT(decimal(19,4),1.0*[x].[ResourceWaitTimeMs]/NULLIF([x].[WaitingTasksCount],0)),CONVERT(decimal(19,4),1.0*[x].[SignalWaitTimeMs]/NULLIF([x].[WaitingTasksCount],0))
        FROM [#CurrentWaits_RawInstance] AS [x] CROSS APPLY [monitor].[TVF_WaitTypeInfo]([x].[WaitType]) AS [wi]
        WHERE (@UnkritischeWaitsEinbeziehen=1 OR [wi].[IsGenerallyBenign]=0)
          AND (NOT EXISTS(SELECT 1 FROM [#CurrentWaits_WaitTypeFilter]) OR EXISTS(SELECT 1 FROM [#CurrentWaits_WaitTypeFilter] AS [f] WHERE [f].[WaitType]=[x].[WaitType] COLLATE SQL_Latin1_General_CP1_CS_AS))
          AND (NOT EXISTS(SELECT 1 FROM [#CurrentWaits_WaitGroupFilter]) OR EXISTS(SELECT 1 FROM [#CurrentWaits_WaitGroupFilter] AS [f] WHERE [f].[WaitGroup]=[wi].[WaitGroup] COLLATE SQL_Latin1_General_CP1_CS_AS))
          AND (@WaitTypeMode<>'LIKE' OR [x].[WaitType] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @WaitTypeValue COLLATE SQL_Latin1_General_CP1_CS_AS)
          AND (@WaitGroupMode<>'LIKE' OR [wi].[WaitGroup] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @WaitGroupValue COLLATE SQL_Latin1_General_CP1_CS_AS);

        IF @HasRegex=1
        BEGIN
            DECLARE @Sql nvarchar(max)=N'';
            IF @WaitTypeMode IN('REGEX','REGEXI') SET @Sql=N'DELETE FROM [#CurrentWaits_Tasks] WHERE [WaitType] IS NULL OR NOT REGEXP_LIKE([WaitType],@WaitType,@WaitTypeFlags);DELETE FROM [#CurrentWaits_Instance] WHERE NOT REGEXP_LIKE([WaitType],@WaitType,@WaitTypeFlags);';
            IF @WaitGroupMode IN('REGEX','REGEXI') SET @Sql+=N'DELETE FROM [#CurrentWaits_Tasks] WHERE [WaitGroup] IS NULL OR NOT REGEXP_LIKE([WaitGroup],@WaitGroup,@WaitGroupFlags);DELETE FROM [#CurrentWaits_Instance] WHERE [WaitGroup] IS NULL OR NOT REGEXP_LIKE([WaitGroup],@WaitGroup,@WaitGroupFlags);';
            EXEC [sys].[sp_executesql] @Sql,N'@WaitType nvarchar(4000),@WaitTypeFlags varchar(8),@WaitGroup nvarchar(4000),@WaitGroupFlags varchar(8)',@WaitTypeValue,@WaitTypeFlags,@WaitGroupValue,@WaitGroupFlags;
        END;

        ;WITH [C] AS (SELECT [WaitType],CONVERT(decimal(9,4),SUM([WaitPercentage]) OVER(ORDER BY [WaitTimeMs] DESC,[WaitType] ROWS UNBOUNDED PRECEDING)) AS [Cum] FROM [#CurrentWaits_Instance]) UPDATE [i] SET [CumulativePercentage]=[c].[Cum] FROM [#CurrentWaits_Instance] AS [i] JOIN [C] AS [c] ON [c].[WaitType]=[i].[WaitType];
        DELETE FROM [#CurrentWaits_Instance] WHERE [CumulativePercentage]-[WaitPercentage]>=@TopWaitPercentage;
        IF @MaxZeilen IS NOT NULL AND @MaxZeilen>0
        BEGIN
            ;WITH [T] AS (SELECT ROW_NUMBER() OVER(ORDER BY [WaitDurationMs] DESC,[SessionId]) AS [rn],* FROM [#CurrentWaits_Tasks]) DELETE FROM [T] WHERE [rn]>@MaxZeilen;
            ;WITH [I] AS (SELECT ROW_NUMBER() OVER(ORDER BY [WaitTimeMs] DESC,[WaitType]) AS [rn],* FROM [#CurrentWaits_Instance]) DELETE FROM [I] WHERE [rn]>@MaxZeilen;
        END;
        DECLARE @TruncatedValueCount bigint=0,@LargestRequiredCharacters bigint=NULL;
        EXEC [monitor].[InternalProjectUnicodeTextColumn]
              @SourceTable=N'#CurrentWaits_Tasks',@TextColumn=N'CurrentStatement'
            , @CharactersColumn=N'CurrentStatementCharacters',@BytesColumn=N'CurrentStatementBytes'
            , @IsTruncatedColumn=N'CurrentStatementIsTruncated',@MaxCharacters=@MaxSqlTextZeichen
            , @TruncatedValueCount=@TruncatedValueCount OUTPUT,@LargestRequiredCharacters=@LargestRequiredCharacters OUTPUT;
        EXEC [monitor].[InternalEmitTruncationWarning]
              @TruncatedValueCount=@TruncatedValueCount,@ParameterName=N'@MaxSqlTextZeichen'
            , @ParameterValue=@MaxSqlTextZeichen,@LargestRequiredCharacters=@LargestRequiredCharacters
            , @PrintMeldungen=@PrintMeldungen;
        SELECT @TaskRowCount=COUNT_BIG(*) FROM [#CurrentWaits_Tasks];SELECT @InstanceRowCount=COUNT_BIG(*) FROM [#CurrentWaits_Instance];
        IF @IsPartial=1 AND @StatusCode='AVAILABLE' SET @StatusCode='AVAILABLE_LIMITED';
    END;

    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE') BEGIN SET @MonitorPrintMessage=FORMATMESSAGE(N'WARNUNG %s: %s',@StatusCode,COALESCE(@ErrorMessage,@DeltaDetail,@Detail,N'eingeschränkte Sicht'));RAISERROR(N'%s',10,1,@MonitorPrintMessage) WITH NOWAIT;END;
    IF @JsonErzeugen=1
    BEGIN
        DECLARE @Meta nvarchar(max)=(SELECT @ModuleName AS [resultName],3 AS [schemaVersion],@CollectionTimeUtc AS [generatedAtUtc],@EvidenceSnapshotStartedAtUtc AS [evidenceSnapshotStartedAtUtc],@EvidenceSnapshotId AS [evidenceSnapshotId],@MeasurementStartUtc AS [measurementStartUtc],@MeasurementEndUtc AS [measurementEndUtc],@StatusCode AS [statusCode],@IsPartial AS [isPartial],@DeltaStatus AS [measurementStatusCode],@TaskRowCount AS [currentTaskRows],@InstanceRowCount AS [instanceWaitRows],@ToolHintergrundabfragenEinbeziehen AS [toolBackgroundQueriesIncluded] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@Tasks nvarchar(max)=(SELECT * FROM [#CurrentWaits_Tasks] ORDER BY [WaitDurationMs] DESC,[SessionId] FOR JSON PATH,INCLUDE_NULL_VALUES),@Instance nvarchar(max)=(SELECT * FROM [#CurrentWaits_Instance] ORDER BY [WaitTimeMs] DESC,[WaitType] FOR JSON PATH,INCLUDE_NULL_VALUES),@Warnings nvarchar(max)=(SELECT [WarningCode] AS [code],[WarningMessage] AS [message] FROM [#CurrentWaits_Warnings] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"currentTasks":',COALESCE(@Tasks,N'[]'),N',"instanceWaits":',COALESCE(@Instance,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');
    END;
    IF @ResultSetArtNormalisiert='RAW'
    BEGIN
        SELECT N'2.0' AS [ContractVersion],@ModuleName AS [ModuleName],@CollectionTimeUtc AS [CollectionTimeUtc],@EvidenceSnapshotStartedAtUtc AS [EvidenceSnapshotStartedAtUtc],@EvidenceSnapshotId AS [EvidenceSnapshotId],@MeasurementStartUtc AS [MeasurementStartUtc],@MeasurementEndUtc AS [MeasurementEndUtc],@StatusCode AS [StatusCode],@IsPartial AS [IsPartial],@TaskRowCount AS [CurrentTaskRowCount],@InstanceRowCount AS [InstanceWaitRowCount],@RequiredPermission AS [RequiredPermission],@ErrorNumber AS [ErrorNumber],@ErrorMessage AS [ErrorMessage],@Detail AS [Detail],@DeltaStatus AS [DeltaStatusCode],@DeltaDetail AS [DeltaDetail],@StartBefore AS [ServerStartTimeBefore],@StartAfter AS [ServerStartTimeAfter];
        SELECT * FROM [#CurrentWaits_Tasks] ORDER BY [WaitDurationMs] DESC,[SessionId];SELECT * FROM [#CurrentWaits_Instance] ORDER BY [WaitTimeMs] DESC,[WaitType];SELECT * FROM [#CurrentWaits_Warnings] ORDER BY [WarningCode];
    END
    ELSE IF @ResultSetArtNormalisiert='CONSOLE'
    BEGIN
        SELECT N'Wait-Analyse' AS [Ergebnis],@StatusCode AS [Status],@DeltaStatus AS [Messstatus],@TaskRowCount AS [Aktuelle_Tasks],@InstanceRowCount AS [Instanz_Waits],@DeltaDetail AS [Messhinweis],@ErrorMessage AS [Fehler];
        SELECT N'Aktuelle wartende Task' AS [Ergebnis],[SessionId] AS [Session],[ExecContextId] AS [Exec_Context],[LoginName] AS [Login],[HostName] AS [Host],[ProgramName] AS [Programm],[Command] AS [Befehl],[WaitType] AS [Wait],CONCAT(CONVERT(varchar(40),[WaitDurationMs]),N' ms') AS [Wartezeit],[BlockingSessionId] AS [Blockiert_durch],[WaitGroup] AS [Wait_Gruppe],[WaitMeaning] AS [Bedeutung],[CurrentStatement] AS [Aktuelles_Statement] FROM [#CurrentWaits_Tasks] ORDER BY [WaitDurationMs] DESC,[SessionId];
        SELECT N'Instanzweite Wait-Messung' AS [Ergebnis],[WaitType] AS [Wait],[WaitGroup] AS [Wait_Gruppe],[MeasurementType] AS [Messart],[WaitingTasksCount] AS [Tasks],CONCAT(CONVERT(varchar(40),[WaitTimeMs]),N' ms') AS [Wartezeit],CONCAT(CONVERT(varchar(40),[WaitPercentage]),N' %') AS [Anteil],CONCAT(CONVERT(varchar(40),[AverageWaitMs]),N' ms') AS [Durchschnitt],[WaitMeaning] AS [Bedeutung],[RecommendedChecks] AS [Empfohlene_Pruefung] FROM [#CurrentWaits_Instance] ORDER BY [WaitTimeMs] DESC,[WaitType];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#CurrentWaits_Tasks'
            , @ResultLabel=N'Aktuelle Waits'
            , @EmptyMessage=N'Keine aktiven Waits';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#CurrentWaits_Tasks'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

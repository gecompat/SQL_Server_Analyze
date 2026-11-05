USE [DeineDatenbank];
GO

/* Bounded SC-023-Retentionlauf; löscht niemals nicht abgelaufene Evidenz. */
CREATE OR ALTER PROCEDURE [monitor].[USP_PurgeSnapshotData]
      @MaxBatches       int            = 10
    , @Force            bit            = 0
    , @ResultSetArt     varchar(16)    = 'CONSOLE'
    , @ResultTablesJson nvarchar(max)  = NULL
    , @JsonErzeugen     bit            = 0
    , @Json             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen   bit            = 1
    , @Hilfe            bit            = 0
    , @PurgeRunIdOut    bigint         = NULL OUTPUT
    , @StatusCodeOut    varchar(40)    = NULL OUTPUT
    , @IsPartialOut     bit            = NULL OUTPUT
    , @ErrorNumberOut   int            = NULL OUTPUT
    , @ErrorMessageOut  nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    CREATE TABLE [#PurgeSnapshotData_Result]
    (
          [PurgeRunId] bigint NULL
        , [TargetDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StartedAtUtc] datetime2(3) NULL
        , [EndedAtUtc] datetime2(3) NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [BatchesExecuted] int NOT NULL
        , [MetricRowsDeleted] bigint NOT NULL
        , [PayloadRowsDeleted] bigint NOT NULL
        , [ModuleRowsDeleted] bigint NOT NULL
        , [CaptureRunsDeleted] bigint NOT NULL
        , [ScopeRowsDeleted] bigint NOT NULL
        , [UsedDataMbBefore] decimal(19,3) NULL
        , [UsedDataMbAfter] decimal(19,3) NULL
        , [SoftBudgetMb] bigint NULL
        , [BudgetExceeded] bit NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#PurgeSnapshotData_TableMap]
    ([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);

    SET @Json=NULL;
    SELECT @PurgeRunIdOut=NULL,@StatusCodeOut='AVAILABLE',@IsPartialOut=0,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_PurgeSnapshotData erläutert alle Parameter; Hilfe bestätigt weder Target noch erfolgreichen Lauf.';
        PRINT N'@MaxBatches: Datentyp int. Ganzzahl von 1 bis 1000 einschließlich; Obergrenze der Child-first-Schleifendurchläufe, keine globale Zeilenzahl. Je Durchlauf erfolgen begrenzte Deletes für MetricSample, PayloadSnapshot, ModuleStatus, CaptureRun und verwaiste Nicht-Server-Scopes; PurgeBatchRows begrenzt jedes Delete. Ein Durchlauf ohne Deletes beendet früher. NULL oder Werte außerhalb 1 bis 1000 sind ungültig. Default: 10.';
        PRINT N'@Force: Datentyp bit. 0 beachtet Purgeintervall; 1 umgeht nur dieses Intervall. Nicht abgelaufene Daten bleiben geschützt. NULL ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.';
        PRINT N'@ResultSetArt: Datentyp varchar(16). CONSOLE zeigt die priorisierte Purge-Laufzusammenfassung; RAW liefert die technische purge-Zeile; TABLE schreibt diese Zeile in das gemappte lokale Temp-Ziel; JSON stellt den JSON-Vertrag im @Json-OUTPUT bereit; NONE unterdrückt reguläre Resultsets. Zulässige Werte ausschließlich CONSOLE, RAW, TABLE, JSON, NONE. Außen getrimmt, Groß-/Kleinschreibung ignoriert; NULL/leer ungültig. Default: ''CONSOLE''.';
        PRINT N'@ResultTablesJson: Datentyp nvarchar(max). Nur TABLE: JSON-Objekt mit genau dem Schlüssel purge und einem Textwert als lokalem Temp-Tabellennamen, etwa N''{"purge":"#MyPurge"}''. Die Zieltabelle muss in derselben Sitzung vorhanden, leer und mit genau einer Seed-Spalte angelegt sein; der Writer passt sie an das Ergebnis an. Leeres Objekt, unbekannte oder doppelte Schlüssel, Nicht-Textwerte, ##- oder permanente Tabellen, Namen über 116 Zeichen sowie das reservierte Präfix #Monitor (ohne Beachtung der Großschreibung) sind unzulässig. Der Schlüssel purge ist case-sensitive. Bei TABLE sind NULL/leer/Leerzeichen ungültig; außerhalb TABLE sind sie zulässig, nichtleere Werte ungültig. Default: NULL.';
        PRINT N'@JsonErzeugen: Datentyp bit. 0 erzeugt JSON nur bei ResultSetArt JSON; 1 befüllt JSON-OUTPUT zusätzlich zu anderer Ausgabeart. NULL ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.';
        PRINT N'@Json: Datentyp nvarchar(max) OUTPUT. nvarchar(max)-Variable mit OUTPUT; am Eintritt NULL. Bei JsonErzeugen=1 oder Ausgabeart JSON enthält das Objekt meta (contractVersion 1, resultName SnapshotPurge) und purge als Objekt, jeweils mit enthaltenen NULL-Werten. Bei Hilfe bleibt NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@PrintMeldungen: Datentyp bit. 1 gibt am Ende für Statuswerte außer AVAILABLE, AVAILABLE_LIMITED und SKIPPED_NOT_DUE RAISERROR severity 10 mit NOWAIT aus; 0 unterdrückt. NULL wird nicht validiert und löst die IF-Ausgabe nicht aus. Default: 1. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.';
        PRINT N'@Hilfe: Datentyp bit. 1 druckt Hilfe und kehrt mit RETURN zurück; 0 normaler Ablauf. NULL wird nicht als 1 behandelt. OUTPUTs werden zuvor initialisiert. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.';
        PRINT N'@PurgeRunIdOut: Datentyp bigint OUTPUT. bigint-Variable mit OUTPUT; initial NULL, enthält PurgeRun-ID falls vorhanden. Bei Hilfe NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@StatusCodeOut: Datentyp varchar(40) OUTPUT. varchar(40)-Variable mit OUTPUT; initial AVAILABLE, danach tatsächlicher Status. Bei Hilfe AVAILABLE. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@IsPartialOut: Datentyp bit OUTPUT. bit-Variable mit OUTPUT; initial 0, danach gemäß Fehler-/Laufpfad. Bei Hilfe 0. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@ErrorNumberOut: Datentyp int OUTPUT. int-Variable mit OUTPUT; initial NULL, bei Fehler gegebenenfalls Fehlernummer. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@ErrorMessageOut: Datentyp nvarchar(2048) OUTPUT. OUTPUT-Parameter nvarchar(2048), mit nvarchar(2048)-Variable und OUTPUT zu binden; Kapazität entspricht 2048 UTF-16-Codeeinheiten. Initial NULL, bei Fehler gegebenenfalls Meldung. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'Ausgelassene Argumente verwenden den jeweiligen Signaturdefault. Zeichenfolgen werden als T-SQL-Literale, Unicodewerte mit N-Präfix übergeben; Zahlen und bit-Werte als skalare Werte. Typkonvertierungen erfolgen vor der Procedure. Der normale Aufruf kann im optionalen Snapshotziel schreiben; @Hilfe=1 beendet vor diesen fachlichen Writes.';
        PRINT N'Sichere Hilfeaufrufe ohne Collection beziehungsweise Purge:';
        PRINT N'EXEC [monitor].[USP_PurgeSnapshotData] @Hilfe=1;';
        PRINT N'EXEC [monitor].[USP_PurgeSnapshotData] @Hilfe=1, @MaxBatches=1;';
        PRINT N'EXEC [monitor].[USP_PurgeSnapshotData] @Hilfe=1, @Force=1;';
        PRINT N'EXEC [monitor].[USP_PurgeSnapshotData] @Hilfe=1, @ResultSetArt=''RAW'';';
        RETURN;
    END;

    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
            @TargetTable sysname,@TableStatus varchar(40),@TableMessage nvarchar(2048);

    IF @OutputMode NOT IN ('CONSOLE','RAW','TABLE','JSON','NONE')
       OR @MaxBatches IS NULL OR @MaxBatches NOT BETWEEN 1 AND 1000
       OR @Force IS NULL OR @Force NOT IN (0,1)
       OR @JsonErzeugen IS NULL OR @JsonErzeugen NOT IN (0,1)
       OR (@OutputMode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Ungültiger Purge-, Ausgabe- oder Force-Parameter.';
        GOTO EmitResults;
    END;

    IF @OutputMode='TABLE'
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
             @ResultTablesJson=@ResultTablesJson,@AllowedResultNames=N'purge',
             @MappingTable=N'#PurgeSnapshotData_TableMap',
             @StatusCode=@TableStatus OUTPUT,@ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable]
        FROM [#PurgeSnapshotData_TableMap]
        WHERE [ResultName]=N'purge';
    END;

    DECLARE @TargetDatabaseName sysname,@TargetQuoted nvarchar(258),@Sql nvarchar(max),
            @IsEnabled bit,@AppLockResult int,@AppLockHeld bit=0,@BudgetExceeded bit=0;
    SELECT @TargetDatabaseName=[TargetDatabaseName],@IsEnabled=[IsEnabled]
    FROM [monitor].[SnapshotTargetConfiguration]
    WHERE [ConfigurationId]=1;

    IF COALESCE(@IsEnabled,0)<>1
    BEGIN
        SELECT @StatusCodeOut='DISABLED',@IsPartialOut=1,
               @ErrorMessageOut=N'Das optionale Snapshotpaket ist nicht aktiviert.';
        GOTO EmitResults;
    END;
    IF NOT EXISTS
    (
        SELECT 1
        FROM [master].[sys].[databases] WITH (NOLOCK)
        WHERE [name]=@TargetDatabaseName AND [state]=0 AND [is_read_only]=0
    )
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,
               @ErrorMessageOut=N'Die konfigurierte Snapshot-Datenbank ist nicht online und schreibbar.';
        GOTO EmitResults;
    END;
    SET @TargetQuoted=QUOTENAME(@TargetDatabaseName);

    EXEC @AppLockResult=[sys].[sp_getapplock]
         @Resource=N'SQL_Server_Analyze.SC023.CollectionCycle',@LockMode='Exclusive',
         @LockOwner='Session',@LockTimeout=0,@DbPrincipal=N'public';
    IF @AppLockResult<0
    BEGIN
        SELECT @StatusCodeOut='SKIPPED_CONCURRENT',@IsPartialOut=1,
               @ErrorMessageOut=N'Ein anderer Snapshotlauf oder Purge besitzt bereits die Paket-Applock.';
        GOTO EmitResults;
    END;
    SET @AppLockHeld=1;

    BEGIN TRY
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalPurgeExpiredData]
             @MaxBatches=@Max,@Force=@ForceValue,@PurgeRunIdOut=@RunId OUTPUT,
             @StatusCodeOut=@Status OUTPUT,@BudgetExceededOut=@Budget OUTPUT,
             @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;';
        EXEC [sys].[sp_executesql] @Sql,
             N'@Max int,@ForceValue bit,@RunId bigint OUTPUT,@Status varchar(40) OUTPUT,@Budget bit OUTPUT,@Error int OUTPUT,@Message nvarchar(2048) OUTPUT',
             @Max=@MaxBatches,@ForceValue=@Force,@RunId=@PurgeRunIdOut OUTPUT,
             @Status=@StatusCodeOut OUTPUT,@Budget=@BudgetExceeded OUTPUT,
             @Error=@ErrorNumberOut OUTPUT,@Message=@ErrorMessageOut OUTPUT;
        SET @IsPartialOut=CASE WHEN @StatusCodeOut IN ('AVAILABLE','SKIPPED_NOT_DUE') THEN 0 ELSE 1 END;

        IF @PurgeRunIdOut IS NOT NULL
        BEGIN
            SET @Sql=N'INSERT [#PurgeSnapshotData_Result]
([PurgeRunId],[TargetDatabaseName],[StartedAtUtc],[EndedAtUtc],[StatusCode],[BatchesExecuted],[MetricRowsDeleted],[PayloadRowsDeleted],[ModuleRowsDeleted],[CaptureRunsDeleted],[ScopeRowsDeleted],[UsedDataMbBefore],[UsedDataMbAfter],[SoftBudgetMb],[BudgetExceeded],[ErrorNumber],[ErrorMessage])
SELECT [PurgeRunId],@Target,[StartedAtUtc],[EndedAtUtc],[StatusCode],[BatchesExecuted],[MetricRowsDeleted],[PayloadRowsDeleted],[ModuleRowsDeleted],[CaptureRunsDeleted],[ScopeRowsDeleted],[UsedDataMbBefore],[UsedDataMbAfter],[SoftBudgetMb],@Budget,[ErrorNumber],[ErrorMessage]
FROM '+@TargetQuoted+N'.[snapshot].[PurgeRun] WHERE [PurgeRunId]=@RunId;';
            EXEC [sys].[sp_executesql] @Sql,N'@Target sysname,@Budget bit,@RunId bigint',
                 @Target=@TargetDatabaseName,@Budget=@BudgetExceeded,@RunId=@PurgeRunIdOut;
        END;
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE(),@BudgetExceeded=1;
    END CATCH;

    IF @AppLockHeld=1
    BEGIN
        EXEC [sys].[sp_releaseapplock]
             @Resource=N'SQL_Server_Analyze.SC023.CollectionCycle',@LockOwner='Session',@DbPrincipal=N'public';
        SET @AppLockHeld=0;
    END;

EmitResults:
    IF NOT EXISTS (SELECT 1 FROM [#PurgeSnapshotData_Result])
        INSERT [#PurgeSnapshotData_Result]
        ([PurgeRunId],[TargetDatabaseName],[StatusCode],[BatchesExecuted],[MetricRowsDeleted],[PayloadRowsDeleted],[ModuleRowsDeleted],[CaptureRunsDeleted],[ScopeRowsDeleted],[BudgetExceeded],[ErrorNumber],[ErrorMessage])
        VALUES (@PurgeRunIdOut,@TargetDatabaseName,@StatusCodeOut,0,0,0,0,0,0,COALESCE(@BudgetExceeded,0),@ErrorNumberOut,@ErrorMessageOut);

    IF @JsonErzeugen=1 OR @OutputMode='JSON'
    BEGIN
        DECLARE @PurgeJson nvarchar(max)=(SELECT * FROM [#PurgeSnapshotData_Result] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":{"contractVersion":1,"resultName":"SnapshotPurge"},"purge":',COALESCE(@PurgeJson,N'{}'),N'}');
    END;

    IF @OutputMode='RAW' SELECT * FROM [#PurgeSnapshotData_Result];
    ELSE IF @OutputMode='CONSOLE'
        EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#PurgeSnapshotData_Result',
             @ResultLabel=N'Snapshot Purge',@EmptyMessage=N'Kein Purge-Lauf',
             @StatusCode=@StatusCodeOut,@StatusMessage=@ErrorMessageOut;
    ELSE IF @OutputMode='TABLE'
        EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#PurgeSnapshotData_Result',@TargetTable=@TargetTable,@ThrowOnError=1;

    IF @PrintMeldungen=1 AND @StatusCodeOut NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED_NOT_DUE')
    BEGIN
        DECLARE @PrintMessage nvarchar(2048)=COALESCE(@ErrorMessageOut,CONVERT(nvarchar(2048),@StatusCodeOut));
        RAISERROR(N'USP_PurgeSnapshotData: %s',10,1,@PrintMessage) WITH NOWAIT;
    END;
END;
GO

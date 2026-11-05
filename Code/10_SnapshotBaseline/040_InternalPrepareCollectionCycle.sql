/*
===============================================================================
Objekt       : snapshot.InternalPrepareCollectionCycle
Version      : 1.2.0
Stand        : 2026-10-26
Zweck        : Prüft Zielidentität, Collectorvertrag, Aktivierung, Datenbudget
               und Fälligkeit; eröffnet abhängig vom Collector einen Lauf.
===============================================================================

Schnittstelle und Parameter
---------------------------
`@SourceDatabaseName` sysname; Default: Kein Default. Weglassen ist nicht zulässig. Obligatorischer Rohname
der Quellmetadaten, ohne Datenbankwechsel oder Datenbanklookup. Leertext wird unverändert gespeichert; NULL scheitert bei einem tatsächlich ausgeführten INSERT an
NOT NULL. Ohne INSERT wird er nicht geschrieben; das Argument bleibt Pflicht.

`@SchedulerType` varchar(16); Default: Kein Default. Weglassen ist nicht zulässig. MANUAL (manueller Aufruf),
EXTERNAL (externer Scheduler), SQL_AGENT (SQL Server Agent). Nur Herkunftslabel;
startet oder prüft keinen Scheduler. Keine explizite Normalisierung. NULL,
Leertext oder ein anderer Wert kann beim INSERT an NOT NULL/CHECK scheitern
(nativer SQL-Fehler, kein INVALID_PARAMETER); ohne
INSERT bleibt der Wert ungenutzt.

`@RunEvenIfNotDue` bit; Default: Kein Default. Weglassen ist nicht zulässig. 0 prüft Fälligkeit, 1 umgeht nur
die Due-Prüfung. Leertext ist keine unterstützte Eingabe. NULL wird nicht validiert und umgeht wegen des Tests = 0
ebenfalls die Prüfung. Disabled-, Budget- und Target-Gates bleiben wirksam.

`@CaptureRunIdOut` bigint OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Beim Eintritt NULL;
Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben. Zuweisung erst nach CaptureRun-INSERT. PERFORMANCE_COUNTERS legt
bei Disabled-, Budget- oder Due-Abbruch einen beendeten partiellen Lauf samt
ModuleStatus an; ID beweist keine Sammlung. WAIT_STATS/FILE_IO liefern bei
frühem Abbruch keine ID. PolicyOnly=1 legt nie einen Lauf an.

`@ShouldCollectOut` bit OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Beim Eintritt 0;
Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben.
Nach INSERT nur bei AVAILABLE 1; PolicyOnly bleibt immer 0.

`@StatusCodeOut` varchar(40) OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Eintritt AVAILABLE;
Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben.
Ausgaben genau: AVAILABLE (Admission bereit), INVALID_PARAMETER (Collector,
PolicyOnly-Kombination oder Wait-Transaktionszustand ungültig),
TARGET_UNAVAILABLE (Ziel/erforderlicher Vertrag fehlt), DISABLED (Policy
deaktiviert/fehlt), STOPPED_SIZE_BUDGET (Softbudget überschritten),
SKIPPED_NOT_DUE (Intervall nicht abgelaufen). RUNNING ist nur der Status der
eingefügten CaptureRun-Zeile, kein Ausgabe-Status. Native Fehler werden nicht
allgemein in diese Statuswerte übersetzt.

`@ErrorMessageOut` nvarchar(2048) OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Eintritt NULL;
Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben.
Diagnose eines erkannten Statuspfads oder NULL; native SQL-Fehler können
direkt abbrechen.

`@CollectorCode` varchar(64); Default: PERFORMANCE_COUNTERS. Weglassen verwendet den Default. Einzelcode;
NULL wird leer, dann UPPER und äußere U+0020-Leerzeichen entfernt. Zulässig:
PERFORMANCE_COUNTERS (Performance Counter), WAIT_STATS (Wait-Statistiken),
FILE_IO (Datei-I/O). Leertext/anderer normalisierter Wert ergibt
INVALID_PARAMETER.

`@ExpectedTargetDatabaseId` int; Default: NULL. Weglassen verwendet NULL. Teil der Zielidentität. NULL
nur im identitätslosen PERFORMANCE_COUNTERS-Fall; sobald eine Komponente
gesetzt ist und bei WAIT_STATS/FILE_IO alle drei Angaben erforderlich. ID >4,
die ID muss DB_ID() der aktuellen Datenbank entsprechen; Ziel in master online und beschreibbar. Leertext ist keine unterstützte Ganzzahleingabe.
Abweichung ergibt TARGET_UNAVAILABLE.

`@ExpectedTargetDatabaseName` sysname; Default: NULL. Weglassen verwendet den Default. Rohname der Zielidentität,
binär verglichen. NULL nur beim identitätslosen PERFORMANCE_COUNTERS-Fall;
sonst alle drei Werte Pflicht. Leertext passt nicht und ergibt
TARGET_UNAVAILABLE.

`@ExpectedTargetCreateDate` datetime; Default: NULL. Weglassen verwendet den Default. Ein typisierter datetime-Wert aus master.sys.databases.create_date, ohne UTC-Konvertierung; Leertext ist keine unterstützte Datumsangabe. NULL nur beim identitätslosen PERFORMANCE_COUNTERS-Fall;
sonst alle drei Werte Pflicht. Abweichung ergibt TARGET_UNAVAILABLE.

`@PolicyOnly` bit; Default: 0. Weglassen verwendet den Default. 0 normaler Admission-Pfad mit Budgetermittlung
und vorgesehenen Writes. 1 nur WAIT_STATS/FILE_IO: Enabled und Due aus
abgeschlossener Historie prüfen. Der SoftBudgetMB-Policywert wird zuvor
mit der Policyquelle gelesen; Dateigrößenmessung, Budgetvergleich und Writes entfallen; keine
Run-ID, ShouldCollect bleibt 0, auch bei AVAILABLE. NULL ergibt
INVALID_PARAMETER; leerer Text ist keine unterstützte Eingabe. Wait-/File-Aufrufe erfordern auch hier keine
Callertransaktion und keine aktivierten impliziten Transaktionen.

Verhalten und Grenzen
---------------------
Erste Parameterprüfung liefert zusätzlich RETURN 51011. WAIT_STATS/FILE_IO
prüfen den installierten SC-023-Vertrag: genau eine PackageVersion mit
1.2.1/Schema 2 oder 1.3.0 beziehungsweise 1.3.1/Schema 3, außerdem
InternalCompleteWaitStatsCycle und Parameter `@ContractOnly` von
InternalPurgeExpiredData. FILE_IO benötigt zusätzlich 1.3.1/Schema 3.
Die Prüfung führt kein Purge aus.

Das Budget berechnet SUM(size) aus sys.database_files für type=0,
multipliziert mit 8.0 und dividiert durch 1024.0. Das sind allokierte
Datendatei-MB der aktuellen Datenbank. Logdateien gehen nicht in die Summe
ein; der Wert misst keine tatsächlich belegten Snapshot- oder Payloadbytes. Nur strikt größer stoppt; Gleichheit passiert. Due verwendet die jüngste
CaptureRun-ID mit EndedAtUtc. PERFORMANCE_COUNTERS zählt nur AVAILABLE/PARTIAL;
WAIT_STATS, FILE_IO und PolicyOnly jeden beendeten Lauf. RunEvenIfNotDue=1
übergeht allein diese Prüfung.

WAIT_STATS/FILE_IO kehren bei Nicht-AVAILABLE vor dem INSERT ohne Lauf zurück.
PERFORMANCE_COUNTERS schreibt bei Disabled, Budgetstopp oder Due-Skip einen
beendeten partiellen Lauf plus ModuleStatus ohne Quellread. PolicyOnly schreibt
nie. Keine eigene Transaktion, kein CATCH, keine Reservierung/Serialisierung;
Mehrstatement-Schreiben kann bei nativen Fehlern partiell sein. Keine global
exakt einmalige Admission.
*/
CREATE OR ALTER PROCEDURE [snapshot].[InternalPrepareCollectionCycle]
      @SourceDatabaseName sysname
    , @SchedulerType      varchar(16)
    , @RunEvenIfNotDue    bit
    , @CaptureRunIdOut    bigint OUTPUT
    , @ShouldCollectOut   bit OUTPUT
    , @StatusCodeOut      varchar(40) OUTPUT
    , @ErrorMessageOut    nvarchar(2048) OUTPUT
    , @CollectorCode      varchar(64) = 'PERFORMANCE_COUNTERS'
    , @ExpectedTargetDatabaseId int = NULL
    , @ExpectedTargetDatabaseName sysname = NULL
    , @ExpectedTargetCreateDate datetime = NULL
    , @PolicyOnly bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME(),
            @IntervalSeconds smallint,
            @SoftBudgetMB bigint,
            @UsedDataMB decimal(19,3),
            @LastCompletedUtc datetime2(3);

    SELECT @CaptureRunIdOut=NULL,@ShouldCollectOut=0,
           @StatusCodeOut='AVAILABLE',@ErrorMessageOut=NULL;

    SET @CollectorCode=UPPER(LTRIM(RTRIM(COALESCE(@CollectorCode,''))));
    IF @CollectorCode NOT IN ('PERFORMANCE_COUNTERS','WAIT_STATS','FILE_IO')
       OR @PolicyOnly IS NULL OR (@PolicyOnly=1 AND @CollectorCode NOT IN('WAIT_STATS','FILE_IO'))
       OR (@CollectorCode IN('WAIT_STATS','FILE_IO') AND (@@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',
               @ErrorMessageOut=N'Ungültiger Collector oder unzulässiger Wait-Callertransaktionszustand.';
        RETURN 51011;
    END;
    IF @CollectorCode IN('WAIT_STATS','FILE_IO') OR @ExpectedTargetDatabaseId IS NOT NULL
       OR @ExpectedTargetDatabaseName IS NOT NULL OR @ExpectedTargetCreateDate IS NOT NULL
    BEGIN
        IF @ExpectedTargetDatabaseId IS NULL OR @ExpectedTargetDatabaseName IS NULL
           OR @ExpectedTargetCreateDate IS NULL OR @ExpectedTargetDatabaseId<=4
           OR DB_ID()<>@ExpectedTargetDatabaseId
               OR NOT EXISTS
           (
               SELECT 1 FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
               WHERE [d].[database_id]=@ExpectedTargetDatabaseId
                 AND CONVERT(varbinary(max),[d].[name])=CONVERT(varbinary(max),@ExpectedTargetDatabaseName)
                 AND [d].[create_date]=@ExpectedTargetCreateDate
                 AND [d].[state]=0 AND [d].[is_read_only]=0
           )
        BEGIN
            SELECT @StatusCodeOut='TARGET_UNAVAILABLE',
                   @ErrorMessageOut=N'Die erwartete Snapshot-Zielidentität stimmt nicht mehr überein.';
            RETURN;
        END;
    END;
    IF @CollectorCode IN('WAIT_STATS','FILE_IO') AND
       ((SELECT COUNT_BIG(*) FROM [snapshot].[PackageVersion])<>1 OR NOT EXISTS
          (SELECT 1 FROM [snapshot].[PackageVersion] WHERE CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')
           AND ((CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') AND [SchemaVersion]=2) OR (CONVERT(varbinary(max),[PackageVersion]) IN(CONVERT(varbinary(max),'1.3.0'),CONVERT(varbinary(max),'1.3.1')) AND [SchemaVersion]=3)))
        OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS [wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH (NOLOCK) ON [ws].[schema_id]=[wp].[schema_id] WHERE CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') AND CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))
        OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS [p] WITH (NOLOCK)
                      WHERE [p].[object_id] IN(SELECT [hp].[object_id] FROM [sys].[procedures] AS [hp] WITH (NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON [hs].[schema_id]=[hp].[schema_id] WHERE CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') AND CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))
                        AND CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),N'@ContractOnly')))
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',
               @ErrorMessageOut=N'Das vollständig installierte Wait-Target 1.2.1 fehlt.';
        RETURN;
    END;

    IF @CollectorCode='FILE_IO' AND NOT EXISTS(SELECT 1 FROM [snapshot].[PackageVersion] WHERE CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.1') AND [SchemaVersion]=3)
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@ErrorMessageOut=N'Datei-I/O benötigt das vollständige Schema-3-Target.';
        RETURN;
    END;

    SELECT @IntervalSeconds=[c].[CollectionIntervalSeconds],
           @SoftBudgetMB=[r].[SoftBudgetMB]
    FROM [snapshot].[CollectorPolicy] AS [c]
    JOIN [snapshot].[RetentionPolicy] AS [r]
      ON [r].[RetentionPolicyCode]=[c].[RetentionPolicyCode]
    WHERE [c].[CollectorCode]=@CollectorCode
      AND [c].[IsEnabled]=1;

    IF @IntervalSeconds IS NULL
        SELECT @StatusCodeOut='DISABLED',@ErrorMessageOut=CASE WHEN @CollectorCode='PERFORMANCE_COUNTERS' THEN N'Der Performance-Counter-Sammler ist deaktiviert.' ELSE N'Der Wait-Sammler ist deaktiviert.' END;

    IF @PolicyOnly=1
    BEGIN
        SELECT TOP(1) @LastCompletedUtc=[EndedAtUtc]
        FROM [snapshot].[CaptureRun]
        WHERE [CollectorCode]=@CollectorCode AND [EndedAtUtc] IS NOT NULL
        ORDER BY [CaptureRunId] DESC;
        IF @StatusCodeOut='AVAILABLE' AND @RunEvenIfNotDue=0 AND @LastCompletedUtc IS NOT NULL
           AND DATEADD(SECOND,@IntervalSeconds,@LastCompletedUtc)>@Now
            SELECT @StatusCodeOut='SKIPPED_NOT_DUE',@ErrorMessageOut=N'Das konfigurierte Sammlerintervall ist noch nicht abgelaufen.';
        -- Budget is checked after the real purge in the normal preparation path.
        RETURN;
    END;

    SELECT @UsedDataMB=CONVERT(decimal(19,3),COALESCE(SUM(CONVERT(decimal(38,3),[size]))*8.0/1024.0,0))
    FROM [sys].[database_files] WITH (NOLOCK)
    WHERE [type]=0;

    IF @StatusCodeOut='AVAILABLE' AND @UsedDataMB>@SoftBudgetMB
        SELECT @StatusCodeOut='STOPPED_SIZE_BUDGET',
               @ErrorMessageOut=N'Das konfigurierte weiche Datenbudget ist nach dem Purge weiterhin überschritten.';

    SELECT TOP (1) @LastCompletedUtc=[EndedAtUtc]
    FROM [snapshot].[CaptureRun]
    WHERE [CollectorCode]=@CollectorCode
      AND (@CollectorCode IN('WAIT_STATS','FILE_IO') OR [StatusCode] IN ('AVAILABLE','PARTIAL'))
      AND [EndedAtUtc] IS NOT NULL
    ORDER BY [CaptureRunId] DESC;

    IF @StatusCodeOut='AVAILABLE'
       AND @RunEvenIfNotDue=0
       AND @LastCompletedUtc IS NOT NULL
       AND DATEADD(SECOND,@IntervalSeconds,@LastCompletedUtc)>@Now
        SELECT @StatusCodeOut='SKIPPED_NOT_DUE',
               @ErrorMessageOut=N'Das konfigurierte Sammlerintervall ist noch nicht abgelaufen.';

    IF @CollectorCode IN('WAIT_STATS','FILE_IO') AND @StatusCodeOut<>'AVAILABLE' RETURN;

    INSERT [snapshot].[CaptureRun]
    (
          [CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc]
        , [SourceDatabaseName],[ContractVersion],[StatusCode],[IsPartial]
        , [ErrorMessage],[MetricSampleCount],[PayloadCount]
    )
    VALUES
    (
          @CollectorCode,@SchedulerType,@Now
        , CASE WHEN @StatusCodeOut='AVAILABLE' THEN NULL ELSE @Now END
        , @SourceDatabaseName,1
        , CASE WHEN @StatusCodeOut='AVAILABLE' THEN 'RUNNING' ELSE @StatusCodeOut END
        , CASE WHEN @StatusCodeOut='AVAILABLE' THEN 0 ELSE 1 END
        , @ErrorMessageOut,0,0
    );

    SET @CaptureRunIdOut=CONVERT(bigint,SCOPE_IDENTITY());
    SET @ShouldCollectOut=CASE WHEN @StatusCodeOut='AVAILABLE' THEN 1 ELSE 0 END;

    IF @ShouldCollectOut=0
    BEGIN
        INSERT [snapshot].[ModuleStatus]
        ([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorMessage],[EvidenceLimit])
        VALUES
        (@CaptureRunIdOut,N'monitor.USP_PerformanceCounters',@Now,@StatusCodeOut,1,@ErrorMessageOut,
         N'Kein Quellread wurde ausgeführt.');
    END;
END;
GO

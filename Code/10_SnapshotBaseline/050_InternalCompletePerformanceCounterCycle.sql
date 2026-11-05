/*
===============================================================================
Objekt       : snapshot.InternalCompletePerformanceCounterCycle
Version      : 1.0.0
Stand        : 2026-07-21
Zweck        : Persistiert einen transient übergebenen Performance-Counter-
               JSON-Vertrag als typisierte Samples und optionales Rohpayload.
===============================================================================


Vertrag
-------
Alle zehn Parameter sind Pflichtargumente; die Signatur definiert keinen
SQL-Default. Ausgelassene Argumente verursachen einen Aufruffehler. Auch
NULL-fähige Argumente müssen angegeben werden.

Parameter
---------
@CaptureRunId bigint
Default: Kein Default; Pflichtargument.
Ordnet Samples, Payload und Modulstatus einer vorhandenen CaptureRunId zu.
Leerer Text ist keine vorgesehene Ganzzahleingabe.
Das Objekt erzeugt keine CaptureRun-Zeile und garantiert weder Laufexistenz,
CollectorCode noch einen offenen Lauf oder Quellenbezug. NULL oder eine
fehlende Zielzeile kann an Constraints scheitern; Wiederholungen können
eindeutige Run-/Metrik- oder Run-/Modul-Bindungen verletzen. EndedAtUtc wird
nicht gesetzt; ein separater Finalisierer schließt den Lauf.

@CollectorJson nvarchar(max)
Default: Kein Default; Pflichtargument.
Erwartet einen einzelnen JSON-Text, keinen Dateinamen oder Pfad. NULL, leerer
Text oder ISJSON(...) <> 1 gilt als ungültig. OPENJSON projiziert aus
$.counters genau diese case-sensitiven Felder und SQL-Typen: ObjectName,
CounterName und InstanceName als nvarchar(128); CounterType als int;
MetricValue als decimal(38,6); MetricUnit als varchar(40); AfterValue als
bigint; FindingCode als varchar(80). Native Konvertierungen gelten. Es gibt
keine strikte Schema- oder Array-Validierung. Zusätzliche Schlüssel werden
für Samples ignoriert, bleiben aber im optionalen Rohpayload erhalten.
ObjectName, CounterName, InstanceName und CounterType müssen nach der
Projektion nicht-NULL sein, sonst wird die Zeile still herausgefiltert;
leere Namen sind zulässig. Fehlende Counter oder Pflichtwerte können ohne
Fehler oder Partial-Markierung null Samples ergeben. Gültiges JSON kann die
erwartete Form dennoch verfehlen. MetricValue und MetricUnit stammen vom
Collector, werden nicht berechnet. AfterValue erzeugt ein RAW-, MetricValue
ein INTERPRETED-Sample; beides erzeugt beide. FindingCode NULL oder SQL-leer
wird MEASURED, sonst ungeprüft übernommen. $.meta.sqlServerStartTime wird
mit TRY_CONVERT als datetime2(3) gelesen; fehlend/ungültig ergibt NULL, ohne
UTC-Umrechnung.

@SourceStatusCode varchar(40)
Default: Kein Default; Pflichtargument.
Gültiges JSON leitet den Wert weiter; NULL wird initial ERROR_HANDLED, leer
bleibt leer. Keine Enum-Prüfung oder geschlossene Ausgabemenge. Bei
ungültigem JSON bleiben nur DENIED_PERMISSION und UNAVAILABLE_OBJECT
erhalten, sonst folgt ERROR_HANDLED.

@SourceIsPartial bit
Default: Kein Default; Pflichtargument.
Akzeptiert 0 (als nicht partiell markiert), 1 (als partiell markiert) oder NULL.
Leerer Text ist keine vorgesehene Bit-Eingabeform. NULL wird zur Laufzeit initial zu 1, kein SQL-Default.
Ungültiges JSON setzt 1. Keine Status-/Partial-Konsistenzprüfung.

@SourceErrorNumber int
Default: Kein Default; Pflichtargument.
Akzeptiert NULL oder eine vorzeichenbehaftete int-Diagnosezahl.
Leerer Text ist keine vorgesehene Ganzzahleingabe. Löst selbst
keinen SQL-Fehler aus und wird initial weitergereicht. Ungültiges JSON ändert
ihn nicht; ein abgefangener SQL-Fehler ersetzt ihn durch seine Fehlernummer.

@SourceErrorMessage nvarchar(2048)
Default: Kein Default; Pflichtargument.
Akzeptiert NULL oder Aufrufertext bis nvarchar(2048); SQL-leer bleibt leer. Initiale Weitergabe.
Bei ungültigem JSON ersetzt der eingebaute Text nur NULL. Ein abgefangener
SQL-Fehler setzt ERROR_MESSAGE().

@StatusCodeOut varchar(40) OUTPUT
Default: Kein Default; Pflichtargument.
Argumenttyp varchar(40); eingehender Variablenwert wird ignoriert und darf
uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT kann das
Pflichtargument übergeben und der Rückgabewert verworfen werden. Initialwert
COALESCE(@SourceStatusCode,'ERROR_HANDLED'). Ungültiges JSON folgt obiger
Regel. Abgefangene Fehler 229, 262, 297, 300, 371 setzen DENIED_PERMISSION,
andere ERROR_HANDLED. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.

@IsPartialOut bit OUTPUT
Default: Kein Default; Pflichtargument.
Argumenttyp bit; eingehender Wert wird ignoriert und darf uninitialisiert sein.
OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden.
0 markiert nicht partiell, 1 partiell; eine Vollständigkeitsprüfung erfolgt nicht.
Initialwert COALESCE(@SourceIsPartial,1); ungültiges JSON und abgefangene
Fehler setzen 1. Keine Konsistenzprüfung.

@ErrorNumberOut int OUTPUT
Default: Kein Default; Pflichtargument.
Argumenttyp int; eingehender Wert ignoriert, darf uninitialisiert sein.
OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden.
Initialwert @SourceErrorNumber; ungültiges JSON ändert ihn nicht, abgefangene
Fehler überschreiben ihn. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.

@ErrorMessageOut nvarchar(2048) OUTPUT
Default: Kein Default; Pflichtargument.
Argumenttyp nvarchar(2048); eingehender Wert ignoriert, darf uninitialisiert
sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen
werden. Initialwert @SourceErrorMessage; ungültiges JSON verwendet den
eingebauten Text nur bei NULL; abgefangene Fehler überschreiben mit
ERROR_MESSAGE(). Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.

Seiteneffekte und Fehlergrenzen
-------------------------------
Vor TRY initialisiert das Objekt OUTPUT-Werte und erstellt bei
LOCK_TIMEOUT 0 eine lokale Temp-Tabelle; deren Anlagefehler kann entweichen.
Im TRY-Pfad werden SERVER-/Counter-Scope-Zeilen wiederverwendet oder ergänzt,
feste RAW-/INTERPRETED-MetricDefinitionen nachgeschlagen und MetricSamples
geschrieben. Bei PERFORMANCE_COUNTERS PayloadEnabled wird das Original-JSON
ohne Kanonisierung samt Hash als GZIP-Payload gespeichert. LEN zählt Zeichen
und nicht alle Speicherbytes. CaptureRun.SqlServerStartTimeUtc wird auf die geparste Serverstartzeit
gesetzt und CaptureRun.ResetEpochId wird aktualisiert. Die Epoch stammt aus der höchsten
CaptureRunId mit gleicher Startzeit und nicht-NULL Epoch, sonst aus NEWID();
das belegt keine Quellserveridentität. ModuleStatus wird geschrieben. Es gibt
keine eigene Transaktion, Atomaritäts- oder Rollback-Zusage. Der CATCH setzt
Status/Partial/Fehlerwerte nach nativem Fehler und versucht ModuleStatus
erneut einzufügen; auch dieser INSERT kann scheitern. Fehler werden nicht
allgemein kontrolliert in Statuswerte umgewandelt. Quellmessung und
Ratenberechnung finden nicht statt. CollectorPolicy.MaxRows wird nicht
durchgesetzt und muss vom Produzenten eingehalten werden. EndedAtUtc setzt
ein separater Finalisierer.
*/
CREATE OR ALTER PROCEDURE [snapshot].[InternalCompletePerformanceCounterCycle]
      @CaptureRunId       bigint
    , @CollectorJson      nvarchar(max)
    , @SourceStatusCode   varchar(40)
    , @SourceIsPartial    bit
    , @SourceErrorNumber  int
    , @SourceErrorMessage nvarchar(2048)
    , @StatusCodeOut      varchar(40) OUTPUT
    , @IsPartialOut       bit OUTPUT
    , @ErrorNumberOut     int OUTPUT
    , @ErrorMessageOut    nvarchar(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    SELECT @StatusCodeOut=COALESCE(@SourceStatusCode,'ERROR_HANDLED'),
           @IsPartialOut=COALESCE(@SourceIsPartial,1),
           @ErrorNumberOut=@SourceErrorNumber,
           @ErrorMessageOut=@SourceErrorMessage;

    CREATE TABLE [#InternalCompletePerformanceCounterCycle_Counters]
    (
          [ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterType] int NOT NULL
        , [MetricValue] decimal(38,6) NULL
        , [MetricUnit] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AfterValue] bigint NULL
        , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ScopeKeyHash] varbinary(32) NULL
        , [ScopeIdentityJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    BEGIN TRY
        IF @CollectorJson IS NULL OR ISJSON(@CollectorJson)<>1
        BEGIN
            SELECT @StatusCodeOut=CASE WHEN @SourceStatusCode IN ('DENIED_PERMISSION','UNAVAILABLE_OBJECT')
                                       THEN @SourceStatusCode ELSE 'ERROR_HANDLED' END,
                   @IsPartialOut=1,
                   @ErrorMessageOut=COALESCE(@SourceErrorMessage,N'Der Collector lieferte keinen gültigen JSON-Vertrag.');
        END
        ELSE
        BEGIN
            INSERT [#InternalCompletePerformanceCounterCycle_Counters]
            (
                  [ObjectName],[CounterName],[InstanceName],[CounterType]
                , [MetricValue],[MetricUnit],[AfterValue],[FindingCode]
            )
            SELECT
                  [ObjectName],[CounterName],[InstanceName],[CounterType]
                , [MetricValue],[MetricUnit],[AfterValue],[FindingCode]
            FROM OPENJSON(@CollectorJson,N'$.counters')
            WITH
            (
                  [ObjectName] nvarchar(128) N'$.ObjectName'
                , [CounterName] nvarchar(128) N'$.CounterName'
                , [InstanceName] nvarchar(128) N'$.InstanceName'
                , [CounterType] int N'$.CounterType'
                , [MetricValue] decimal(38,6) N'$.MetricValue'
                , [MetricUnit] varchar(40) N'$.MetricUnit'
                , [AfterValue] bigint N'$.AfterValue'
                , [FindingCode] varchar(80) N'$.FindingCode'
            )
            WHERE [ObjectName] IS NOT NULL
              AND [CounterName] IS NOT NULL
              AND [InstanceName] IS NOT NULL
              AND [CounterType] IS NOT NULL;

            UPDATE [c]
            SET [ScopeIdentityJson]=[j].[ScopeIdentityJson],
                [ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),[j].[ScopeIdentityJson]))
            FROM [#InternalCompletePerformanceCounterCycle_Counters] AS [c]
            CROSS APPLY
            (
                SELECT
                (
                    SELECT [c].[ObjectName] AS [objectName],
                           [c].[CounterName] AS [counterName],
                           [c].[InstanceName] AS [instanceName],
                           [c].[CounterType] AS [counterType],
                           [c].[MetricUnit] AS [metricUnit]
                    FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
                ) AS [ScopeIdentityJson]
            ) AS [j];

            DECLARE @SqlServerStartTimeUtc datetime2(3)=TRY_CONVERT(datetime2(3),JSON_VALUE(@CollectorJson,N'$.meta.sqlServerStartTime')),
                    @ResetEpochId uniqueidentifier,
                    @Now datetime2(3)=SYSUTCDATETIME(),
                    @ServerScopeId bigint,
                    @RawMetricDefinitionId bigint,
                    @InterpretedMetricDefinitionId bigint,
                    @PayloadEnabled bit=0;

            SELECT TOP (1) @ResetEpochId=[ResetEpochId]
            FROM [snapshot].[CaptureRun]
            WHERE [SqlServerStartTimeUtc]=@SqlServerStartTimeUtc
              AND [ResetEpochId] IS NOT NULL
            ORDER BY [CaptureRunId] DESC;
            IF @ResetEpochId IS NULL SET @ResetEpochId=NEWID();

            IF NOT EXISTS
            (
                SELECT 1
                FROM [snapshot].[Scope]
                WHERE [ScopeType]='SERVER'
                  AND [ParentScopeId] IS NULL
                  AND [ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),N'{"scope":"SERVER"}'))
            )
                INSERT [snapshot].[Scope]
                ([ScopeType],[ParentScopeId],[ScopeKeyHash],[ScopeIdentityJson],[CreatedAtUtc])
                VALUES
                ('SERVER',NULL,HASHBYTES('SHA2_256',CONVERT(varbinary(max),N'{"scope":"SERVER"}')),N'{"scope":"SERVER"}',@Now);

            SELECT @ServerScopeId=[ScopeId]
            FROM [snapshot].[Scope]
            WHERE [ScopeType]='SERVER'
              AND [ParentScopeId] IS NULL
              AND [ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),N'{"scope":"SERVER"}'));

            INSERT [snapshot].[Scope]
            ([ScopeType],[ParentScopeId],[ScopeKeyHash],[ScopeIdentityJson],[CreatedAtUtc])
            SELECT 'PERFORMANCE_COUNTER',@ServerScopeId,[c].[ScopeKeyHash],[c].[ScopeIdentityJson],@Now
            FROM [#InternalCompletePerformanceCounterCycle_Counters] AS [c]
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [snapshot].[Scope] AS [s]
                WHERE [s].[ScopeType]='PERFORMANCE_COUNTER'
                  AND [s].[ParentScopeId]=@ServerScopeId
                  AND [s].[ScopeKeyHash]=[c].[ScopeKeyHash]
            )
            GROUP BY [c].[ScopeKeyHash],[c].[ScopeIdentityJson];

            SELECT @RawMetricDefinitionId=[MetricDefinitionId]
            FROM [snapshot].[MetricDefinition]
            WHERE [MetricCode]='PERFORMANCE_COUNTER_RAW';
            SELECT @InterpretedMetricDefinitionId=[MetricDefinitionId]
            FROM [snapshot].[MetricDefinition]
            WHERE [MetricCode]='PERFORMANCE_COUNTER_INTERPRETED';

            INSERT [snapshot].[MetricSample]
            (
                  [CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc]
                , [ResetEpochId],[BigintValue],[QualityCode],[IsPartial]
            )
            SELECT @CaptureRunId,[s].[ScopeId],@RawMetricDefinitionId,@Now,@ResetEpochId,
                   [c].[AfterValue],COALESCE(NULLIF([c].[FindingCode],''),'MEASURED'),@IsPartialOut
            FROM [#InternalCompletePerformanceCounterCycle_Counters] AS [c]
            JOIN [snapshot].[Scope] AS [s]
              ON [s].[ScopeType]='PERFORMANCE_COUNTER'
             AND [s].[ParentScopeId]=@ServerScopeId
             AND [s].[ScopeKeyHash]=[c].[ScopeKeyHash]
            WHERE [c].[AfterValue] IS NOT NULL;

            INSERT [snapshot].[MetricSample]
            (
                  [CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc]
                , [ResetEpochId],[NumericValue],[QualityCode],[IsPartial]
            )
            SELECT @CaptureRunId,[s].[ScopeId],@InterpretedMetricDefinitionId,@Now,@ResetEpochId,
                   [c].[MetricValue],COALESCE(NULLIF([c].[FindingCode],''),'MEASURED'),@IsPartialOut
            FROM [#InternalCompletePerformanceCounterCycle_Counters] AS [c]
            JOIN [snapshot].[Scope] AS [s]
              ON [s].[ScopeType]='PERFORMANCE_COUNTER'
             AND [s].[ParentScopeId]=@ServerScopeId
             AND [s].[ScopeKeyHash]=[c].[ScopeKeyHash]
            WHERE [c].[MetricValue] IS NOT NULL;

            SELECT @PayloadEnabled=[PayloadEnabled]
            FROM [snapshot].[CollectorPolicy]
            WHERE [CollectorCode]='PERFORMANCE_COUNTERS';

            IF @PayloadEnabled=1
                INSERT [snapshot].[PayloadSnapshot]
                (
                      [CaptureRunId],[ModuleName],[CapturedAtUtc],[PayloadFormat]
                    , [PayloadContractVersion],[CompressionType],[PayloadHash]
                    , [Payload],[UncompressedCharacterCount]
                )
                VALUES
                (
                      @CaptureRunId,N'monitor.USP_PerformanceCounters',@Now,'JSON',1,'GZIP'
                    , HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CollectorJson))
                    , COMPRESS(@CollectorJson),CONVERT(bigint,LEN(@CollectorJson))
                );

            UPDATE [snapshot].[CaptureRun]
            SET [SqlServerStartTimeUtc]=@SqlServerStartTimeUtc,
                [ResetEpochId]=@ResetEpochId
            WHERE [CaptureRunId]=@CaptureRunId;
        END;

        INSERT [snapshot].[ModuleStatus]
        (
              [CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode]
            , [IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
        )
        VALUES
        (
              @CaptureRunId,N'monitor.USP_PerformanceCounters',SYSUTCDATETIME(),@StatusCodeOut
            , @IsPartialOut,@ErrorNumberOut,@ErrorMessageOut
            , N'@SampleSeconds=0; CollectorPolicy.MaxRows begrenzt die persistierte Collectorprojektion.'
        );
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
        INSERT [snapshot].[ModuleStatus]
        ([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
        VALUES
        (@CaptureRunId,N'monitor.USP_PerformanceCounters',SYSUTCDATETIME(),@StatusCodeOut,1,@ErrorNumberOut,@ErrorMessageOut,
         N'Persistenz wurde kontrolliert als partiell markiert.');
    END CATCH;
END;
GO

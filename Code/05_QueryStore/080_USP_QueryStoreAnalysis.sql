USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_QueryStoreAnalysis
Version      : 2.2.0
Stand        : 2026-07-27
Zweck        : Orchestriert Query-Store-Module mit einheitlichem Quell- und
               Referenzdatenbankvertrag. JSON enthält benannte Modulobjekte.
Änderungen   : 2.2.0 - SQL25-005 Replica-Kontext als versionsadaptives Standardteilmodul.
                2.1.0 - IQP-Evidenz als kostenbewusstes opt-in Teilmodul.
               2.0.1 - IF/TRY/CATCH-Blöcke syntaktisch eindeutig strukturiert.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_QueryStoreAnalysis]
      @QueryStoreDatabaseNames          nvarchar(max)  = NULL
    , @QueryStoreDatabaseNamePattern    nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @ReferencedDatabaseNames          nvarchar(max)  = NULL
    , @ReferencedDatabaseNamePattern    nvarchar(4000) = NULL
    , @VonUtc                           datetime2(7)   = NULL
    , @BisUtc                           datetime2(7)   = NULL
    , @MitStatus                        bit            = 1
    , @MitRuntimeStats                  bit            = 1
    , @MitWaitStats                     bit            = 0
    , @MitPlanChanges                   bit            = 0
    , @MitRegressionen                  bit            = 0
    , @MitForcedPlans                   bit            = 0
    , @MitHints                         bit            = 0
    , @MitReplicaKontext                bit            = 1
    , @MitIQP                           bit            = 0
    , @MaxZeilen                        int            = 100
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    CREATE TABLE [#QueryStoreAnalysis_MonitorTableResult]
    (
          [ExecutionOrdinal] tinyint NOT NULL
        , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    SET LOCK_TIMEOUT 0;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'moduleStatus',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @StatusJson nvarchar(max);
    DECLARE @RuntimeJson nvarchar(max);
    DECLARE @WaitJson nvarchar(max);
    DECLARE @PlanJson nvarchar(max);
    DECLARE @RegressionJson nvarchar(max);
    DECLARE @ForcedJson nvarchar(max);
    DECLARE @HintsJson nvarchar(max);
    DECLARE @ReplicaJson nvarchar(max);
    DECLARE @ReplicaStatus varchar(40)=NULL;
    DECLARE @ReplicaPartial bit=NULL;
    DECLARE @ReplicaErrorNumber int=NULL;
    DECLARE @ReplicaErrorMessage nvarchar(2048)=NULL;
    DECLARE @IqpJson nvarchar(max);
    DECLARE @IqpStatus varchar(40) = NULL;
    DECLARE @IqpPartial bit = NULL;
    DECLARE @IqpErrorNumber int = NULL;
    DECLARE @IqpErrorMessage nvarchar(2048) = NULL;

    DECLARE @ModuleStatus TABLE
    (
          [ExecutionOrdinal] tinyint        NOT NULL
        , [ModuleName]       sysname COLLATE SQL_Latin1_General_CP1_CS_AS        NOT NULL
        , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS    NOT NULL
        , [ErrorNumber]      int            NULL
        , [ErrorMessage]     nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_QueryStoreAnalysis';
        PRINT N'Orchestriert neun Query-Store-Teilmodule in fester Reihenfolge: Status, Runtime, Waits, Planwechsel, Regressionen, Forced Plans, Hints, Replica-Kontext und IQP. Standardmäßig aktiv sind Status, Runtime und Replica-Kontext; es entsteht keine atomare Gesamtaufnahme.';
        PRINT N'Die normalen Orchestratorprüfungen betreffen nur negative @MaxZeilen, den Ausgabemodus, VonUtc > BisUtc bei zwei gesetzten Grenzen und neun exakt ausgeschaltete Modulschalter. Weitere Parameterprüfungen und Datenbankfreigaben erfolgen nur in tatsächlich aktivierten Teilmodulen. Hilfe kehrt nach den frühen Mappingprüfungen davor zurück.';
        PRINT N'Bei den ersten sieben Teilmodulen bedeutet EXECUTED nur eine Rückkehr ohne THROW, auch bei kontrollierter fachlicher Ablehnung. Replica-Kontext und IQP liefern eigene Status-OUTPUTs. RAW liefert Teilmodulresultsets vor Orchestratormetadaten und Aufrufjournal; CONSOLE/TABLE zeigen ausschließlich das Journal. Fachresultate bleiben bei aktivierter JSON-Erzeugung in benannten Teilmodulobjekten erhalten.';
        PRINT N'@QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'''' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N''[ExampleDatabase]|[OtherDatabase]''; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen. Unveränderte Weitergabe an alle neun Teilmodule; eigene Namensprüfung und kontrollierter Auswahlstatus liegen beim tatsächlich aktivierten Teilmodul.';
        PRINT N'@QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert. Weitergabe an alle neun Teilmodule. Bei gleichzeitig effektiver nichtleerer Namensliste wird der Aufruf dort abgewiesen, keine Liste bevorzugt. LIKE unterstützt %, _ und Zeichenklassen [...].';
        PRINT N'@HighImpactConfirmed bit; Default: 0. Ausgelassen/0: keine High-Impact-Bestätigung. 1 bestätigt einen tatsächlich aktivierten gruppengeschützten Pfad, ohne Modul oder Rechte zu aktivieren. Der Orchestrator prüft NULL nicht selbst; bei erreichter Datenbankvorbereitung eines aktivierten Teilmoduls ist es INVALID_PARAMETER. Alle neun Teilmodule erhalten den Wert. Die Query-Store-Basisklasse hat kein Gruppengate; Referenzfilter, breite Zeitfenster und >1000/unbegrenzte Limits können je Teilmodul QUERY_STORE_DEEP verlangen. Replica-Kontext aktiviert keinen Deep-Pfad; IQP verlangt unabhängig vom Limit CATALOG_DEEP mit Bestätigung und Gruppenfreigabe. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@ReferencedDatabaseNames nvarchar(max); Default: NULL. ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; | trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein; Teile 3/4 werden nicht gesondert geprüft. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus. Weitergabe nur an RuntimeStats, WaitStats, PlanChanges, Regressions und ForcedPlans; Status, Hints, Replica-Kontext und IQP erhalten diesen Filter nicht. Ohne eines der fünf aktivierten Teilmodule wird er nicht verarbeitet.';
        PRINT N'@ReferencedDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert. Weitergabe nur an RuntimeStats, WaitStats, PlanChanges, Regressions und ForcedPlans; die anderen vier Teilmodule erhalten ihn nicht. LIKE unterstützt %, _ und Zeichenklassen [...].';
        PRINT N'@VonUtc datetime2(7); Default: NULL. Ausgelassen/NULL wird unverändert weitergegeben, keine globale offene Untergrenze. UTC-datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T12:00:00.0000000 übergeben; keine Zeitzonenumrechnung. Bei zwei gesetzten Grenzen lehnt der Orchestrator nur VonUtc > BisUtc ab; Gleichheit passiert diese Prüfung, kann im Teilmodul aber ungültig sein. Runtime, Waits und Replica-Kontext setzen NULL auf eine Stunde vor ihrem effektiven Ende und berücksichtigen vollständige überlappende Intervalle. PlanChanges erhält nur VonUtc; dort bedeutet NULL kein Zeitfilter. Regressionen erhalten ihn als Vergleichsbeginn und leiten die Baseline standardmäßig aus der Stunde davor ab. Status, ForcedPlans, Hints und IQP erhalten keinen Zeitparameter. DATEADD-Defaults an frühen datetime2-Grenzen können im Teilmodul überlaufen und werden dann als Aufruffehler erfasst.';
        PRINT N'@BisUtc datetime2(7); Default: NULL. Ausgelassen/NULL wird unverändert weitergegeben, keine globale offene Obergrenze. UTC-datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T13:00:00.0000000 übergeben; keine Zeitzonenumrechnung. Runtime, Waits, Replica-Kontext und Regressionen lösen NULL jeweils auf ihren eigenen aktuellen UTC-Endzeitpunkt auf; bei zugleich NULLem Beginn gilt dort die letzte Stunde. Getrennte Aufrufe garantieren keinen identischen Endzeitpunkt. Regressionen verwenden ihn als Vergleichsende; die Baseline liegt standardmäßig in der Stunde vor Vergleichsbeginn. PlanChanges und die übrigen Teilmodule erhalten BisUtc nicht. Der Orchestrator lehnt nur zwei gesetzte Grenzen mit VonUtc > BisUtc ab; strengere Teilmodulprüfungen bleiben wirksam.';
        PRINT N'@MitStatus bit; Default: 1. 0 deaktiviert, 1 aktiviert USP_QueryStoreStatus; ausgelassen ergibt 1. NULL wird nicht zu 0 normalisiert und die IF-Bedingung aktiviert das Teilmodul nur bei genau 1; außerdem verhindert NULL im Schalterbündel, dass dessen All-aus-Guard TRUE wird. Die Orchestratorprüfung prüft nur, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert Query-Store-Zustand, Capture- und Retentioneinstellungen. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@MitRuntimeStats bit; Default: 1. 0 deaktiviert, 1 aktiviert USP_QueryStoreRuntimeStats; ausgelassen ergibt 1. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert aggregierte Runtime- und Ressourcenwerte je Query/Plan. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@MitWaitStats bit; Default: 0. 0 deaktiviert, 1 aktiviert USP_QueryStoreWaitStats; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert aggregierte Query-Store-Waitkategorien. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@MitPlanChanges bit; Default: 0. 0 deaktiviert, 1 aktiviert USP_QueryStorePlanChanges; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert Querysummaries und gespeicherte Pläne von Queries mit mehreren Plänen. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@MitRegressionen bit; Default: 0. 0 deaktiviert, 1 aktiviert USP_QueryStoreRegressions; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert gewichteten Metrikvergleich von Baseline und Vergleichsfenster. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@MitForcedPlans bit; Default: 0. 0 deaktiviert, 1 aktiviert USP_QueryStoreForcedPlans; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert Inventar erzwungener Pläne und Force-Fehler ohne Änderung der Planbindungen. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@MitHints bit; Default: 0. 0 deaktiviert, 1 aktiviert USP_QueryStoreHints; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert gespeicherte Query-Store-Hints und deren Fehlerstatus ab SQL Server 2022 ohne Setzen von Hints. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@MitReplicaKontext bit; Default: 1. 0 deaktiviert, 1 aktiviert USP_QueryStoreReplicaAnalysis; ausgelassen ergibt 1. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Vor SQL Server 2025 kann das aktivierte Teilmodul den tatsächlichen Status UNAVAILABLE_VERSION melden. Das Teilmodul liefert rollengetrennte Query-Store-Runtime-, Wait- und Forcing-Evidenz; vor SQL Server 2025 kontrolliert UNAVAILABLE_VERSION, kein aktueller AG-Gesundheitsnachweis. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@MitIQP bit; Default: 0. 0 deaktiviert, 1 aktiviert USP_IntelligentQueryProcessingAnalysis; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Das Teilmodul liefert einen eigenen tatsächlichen Status. Das Teilmodul liefert datenbankweite IQP-Konfiguration und Feedback-/Tuningevidenz; dieser Pfad verlangt CATALOG_DEEP-Freigabe und HighImpactConfirmed=1. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@MaxZeilen int; Default: 100. Ausgelassen: 100. Positive ganze int-Werte von 1 bis 2147483647 sind das weitergereichte Limit; NULL/0 bedeutet in den empfangenden Teilmodulen unbegrenzt. Negative Werte lehnt der Orchestrator vor allen Teilmodulaufrufen als INVALID_PARAMETER ab. Weitergabe an acht Teilmodule außer Status; jedes begrenzt eigene Ergebnismengen nach seinem Aggregations-/Kandidatenvertrag. Kein Gesamtlimit über alle Teilmodulzeilen und kein Limit für das Aufrufjournal mit höchstens neun Zeilen. >1000 beziehungsweise NULL/0 kann in unterstützenden Query-Store-Teilmodulen Deep aktivieren; das IQP-Gate ist ohnehin erforderlich.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Ausgelassen: CONSOLE. Nach äußerem U+0020-Trim und Großschreibung genau vier Werte: RAW wird an ausgewählte Teilmodule weitergegeben und liefert deren Resultsets vor zwei Orchestratorresultsets (Metadaten und Aufrufjournal); CONSOLE führt Teilmodule mit NONE aus und zeigt nur das Journal mit Ergebnislabel oder bei Leere eine Hinweiszeile; TABLE führt Teilmodule mit NONE aus und schreibt nur das Journal in moduleStatus; NONE unterdrückt normale Resultsets aller Teilmodule und des Orchestrators. JSON ist unabhängig, technische Meldungen werden separat gesteuert. NULL, leer, nur U+0020 oder andere Werte sind im normalen Ablauf INVALID_PARAMETER. Die Bindung an varchar(16) erfolgt vor der Prüfung.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Ausgelassen/NULL, leer oder nur äußere U+0020-Leerzeichen sind außerhalb TABLE zulässig; anderer nichtleerer Inhalt wirft dort vor Hilfe Fehler 51011. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem binär exakten Schlüssel moduleStatus erforderlich. Der Stringwert benennt ein vorhandenes, leeres lokales #Temp-Ziel mit genau einer beliebigen Seed-Spalte und keiner Seed-Zeile; kein ##, LEN höchstens 116, kein reserviertes #Monitor-Präfix. Unbekannte/doppelte Schlüssel oder ungültige Ziele scheitern im frühen ThrowOnError-Preflight vor Hilfe und Fachvalidierung. Der Writer ersetzt die Seed-Struktur. moduleStatus enthält nur die fünf Journalfelder ExecutionOrdinal, ModuleName, InvocationStatus, ErrorNumber und ErrorMessage, weder Teilmodul-Fachdaten noch übergeordnete Metadaten.';
        PRINT N'@JsonErzeugen bit; Default: 0. Ausgelassen/0: @Json bleibt NULL. 1 erzeugt das Gesamt-JSON unabhängig vom Ausgabemodus und wird auch an jedes aktivierte Teilmodul weitergegeben. NULL wird vom Orchestrator nicht selbst abgewiesen und erzeugt kein Gesamt-JSON; Teilmodule behandeln ihn nach eigenem Vertrag, Replica-Kontext meldet dabei INVALID_PARAMETER. Das Objekt enthält meta (Orchestratorstatus), status (Statusmodul), runtimeStats, waitStats, planChanges, regressions, forcedPlans, queryHints, replicaContext, intelligentQueryProcessing sowie warnings (gefiltertes Aufrufjournal). Nicht ausgeführte oder ohne JSON zurückgekehrte Teilmodule erscheinen als JSON null. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Parameter; eine nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Der Eingabewert wird beim Eintritt stets durch NULL ersetzt; nur JsonErzeugen=1 füllt das Gesamtobjekt. Bei Hilfe bleibt NULL. Ohne OUTPUT-Bindung wird kein Wert an den Aufrufer übernommen. Bei ungefangenem Fehler, etwa frühem Mapping-THROW, ist keine OUTPUT-Rückübertragung zugesichert.';
        PRINT N'@PrintMeldungen bit; Default: 1. Ausgelassen: 1. 0 unterdrückt unterstützte optionale Severity-10-Quellen-/Truncationmeldungen, 1 erlaubt sie. Der Orchestrator hat keinen eigenen Meldungszweig, sondern gibt den Wert an alle neun aktivierten Teilmodule weiter. Replica-Kontext und IQP besitzen derzeit keinen solchen Meldungszweig; Replica-Kontext wertet NULL im normalen Ablauf trotzdem als INVALID_PARAMETER. In den übrigen unterstützenden Meldungszweigen unterdrückt NULL die Ausgabe; der Orchestrator normalisiert ihn nicht. Resultset-/JSON-Daten und Hilfe-PRINTs sind unabhängig. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@Hilfe bit; Default: 0. Ausgelassen/0 oder NULL: normaler Ablauf. 1 druckt Hilfe und Beispiele und beendet vor normalen Orchestratorprüfungen und Teilmodulaufrufen. SQL-Typbindung, Json=NULL, lokale Journaltabelle, SET LOCK_TIMEOUT 0, Ablehnung nichtleerer Mappings außerhalb TABLE und TABLE-Preflight liegen davor; ein Mappingfehler kann deshalb die Hilfe verhindern. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'EXEC [monitor].[USP_QueryStoreAnalysis] @Hilfe=1;';
        PRINT N'EXEC [monitor].[USP_QueryStoreAnalysis] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreAnalysis] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];';
        PRINT N'CREATE TABLE [#QueryStoreAnalysis_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreAnalysis] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"moduleStatus":"#QueryStoreAnalysis_HelpExample"}'';
 SELECT * FROM [#QueryStoreAnalysis_HelpExample];
 DROP TABLE IF EXISTS [#QueryStoreAnalysis_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreAnalysis_HelpExample];
 THROW;
END CATCH;';
        RETURN;
    END;

    IF @MaxZeilen < 0
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR (@VonUtc IS NOT NULL AND @BisUtc IS NOT NULL AND @VonUtc > @BisUtc)
       OR (@MitStatus = 0 AND @MitRuntimeStats = 0 AND @MitWaitStats = 0
           AND @MitPlanChanges = 0 AND @MitRegressionen = 0
           AND @MitForcedPlans = 0 AND @MitHints = 0 AND @MitReplicaKontext = 0 AND @MitIQP = 0)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitStatus = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_QueryStoreStatus]
                  @QueryStoreDatabaseNames = @QueryStoreDatabaseNames
                , @QueryStoreDatabaseNamePattern = @QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @StatusJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @ModuleStatus VALUES (1, N'USP_QueryStoreStatus', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (1, N'USP_QueryStoreStatus', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitRuntimeStats = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_QueryStoreRuntimeStats]
                  @QueryStoreDatabaseNames = @QueryStoreDatabaseNames
                , @QueryStoreDatabaseNamePattern = @QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @ReferencedDatabaseNames = @ReferencedDatabaseNames
                , @ReferencedDatabaseNamePattern = @ReferencedDatabaseNamePattern
                , @VonUtc = @VonUtc
                , @BisUtc = @BisUtc

                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @RuntimeJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @ModuleStatus VALUES (2, N'USP_QueryStoreRuntimeStats', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (2, N'USP_QueryStoreRuntimeStats', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitWaitStats = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_QueryStoreWaitStats]
                  @QueryStoreDatabaseNames = @QueryStoreDatabaseNames
                , @QueryStoreDatabaseNamePattern = @QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @ReferencedDatabaseNames = @ReferencedDatabaseNames
                , @ReferencedDatabaseNamePattern = @ReferencedDatabaseNamePattern
                , @VonUtc = @VonUtc
                , @BisUtc = @BisUtc

                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @WaitJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @ModuleStatus VALUES (3, N'USP_QueryStoreWaitStats', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (3, N'USP_QueryStoreWaitStats', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitPlanChanges = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_QueryStorePlanChanges]
                  @QueryStoreDatabaseNames = @QueryStoreDatabaseNames
                , @QueryStoreDatabaseNamePattern = @QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @ReferencedDatabaseNames = @ReferencedDatabaseNames
                , @ReferencedDatabaseNamePattern = @ReferencedDatabaseNamePattern
                , @VonUtc = @VonUtc

                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @PlanJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @ModuleStatus VALUES (4, N'USP_QueryStorePlanChanges', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (4, N'USP_QueryStorePlanChanges', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitRegressionen = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_QueryStoreRegressions]
                  @QueryStoreDatabaseNames = @QueryStoreDatabaseNames
                , @QueryStoreDatabaseNamePattern = @QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @ReferencedDatabaseNames = @ReferencedDatabaseNames
                , @ReferencedDatabaseNamePattern = @ReferencedDatabaseNamePattern
                , @VergleichVonUtc = @VonUtc
                , @VergleichBisUtc = @BisUtc

                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @RegressionJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @ModuleStatus VALUES (5, N'USP_QueryStoreRegressions', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (5, N'USP_QueryStoreRegressions', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitForcedPlans = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_QueryStoreForcedPlans]
                  @QueryStoreDatabaseNames = @QueryStoreDatabaseNames
                , @QueryStoreDatabaseNamePattern = @QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @ReferencedDatabaseNames = @ReferencedDatabaseNames
                , @ReferencedDatabaseNamePattern = @ReferencedDatabaseNamePattern

                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ForcedJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @ModuleStatus VALUES (6, N'USP_QueryStoreForcedPlans', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (6, N'USP_QueryStoreForcedPlans', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitHints = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_QueryStoreHints]
                  @QueryStoreDatabaseNames = @QueryStoreDatabaseNames
                , @QueryStoreDatabaseNamePattern = @QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @HintsJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @ModuleStatus VALUES (7, N'USP_QueryStoreHints', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (7, N'USP_QueryStoreHints', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;


    IF @StatusCode = 'AVAILABLE' AND @MitReplicaKontext = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_QueryStoreReplicaAnalysis]
                  @QueryStoreDatabaseNames = @QueryStoreDatabaseNames
                , @QueryStoreDatabaseNamePattern = @QueryStoreDatabaseNamePattern
                , @HighImpactConfirmed = @HighImpactConfirmed
                , @VonUtc = @VonUtc
                , @BisUtc = @BisUtc
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ReplicaJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ReplicaStatus OUTPUT
                , @IsPartialOut = @ReplicaPartial OUTPUT
                , @ErrorNumberOut = @ReplicaErrorNumber OUTPUT
                , @ErrorMessageOut = @ReplicaErrorMessage OUTPUT;

            INSERT @ModuleStatus VALUES
            (8, N'USP_QueryStoreReplicaAnalysis', COALESCE(@ReplicaStatus, 'ERROR_HANDLED'), @ReplicaErrorNumber, @ReplicaErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (8, N'USP_QueryStoreReplicaAnalysis', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitIQP = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis]
                  @DatabaseNames = @QueryStoreDatabaseNames
                , @DatabaseNamePattern = @QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @IqpJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @IqpStatus OUTPUT
                , @IsPartialOut = @IqpPartial OUTPUT
                , @ErrorNumberOut = @IqpErrorNumber OUTPUT
                , @ErrorMessageOut = @IqpErrorMessage OUTPUT;

            INSERT @ModuleStatus VALUES
            (9, N'USP_IntelligentQueryProcessingAnalysis', COALESCE(@IqpStatus, 'ERROR_HANDLED'), @IqpErrorNumber, @IqpErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (9, N'USP_IntelligentQueryProcessingAnalysis', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF EXISTS (SELECT 1 FROM @ModuleStatus
               WHERE [InvocationStatus] NOT IN ('EXECUTED','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE','UNAVAILABLE_VERSION','UNAVAILABLE_FEATURE','FEATURE_DISABLED'))
       AND @StatusCode = 'AVAILABLE'
    BEGIN
        SET @StatusCode = 'AVAILABLE_LIMITED';
    END
    ELSE IF EXISTS (SELECT 1 FROM @ModuleStatus WHERE [InvocationStatus] = 'AVAILABLE_WITH_FINDING')
         AND @StatusCode = 'AVAILABLE'
        SET @StatusCode = 'AVAILABLE_WITH_FINDING';

    INSERT [#QueryStoreAnalysis_MonitorTableResult]
        ([ExecutionOrdinal],[ModuleName],[InvocationStatus],[ErrorNumber],[ErrorMessage])
    SELECT [ExecutionOrdinal],[ModuleName],[InvocationStatus],[ErrorNumber],[ErrorMessage]
    FROM @ModuleStatus;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT
              N'USP_QueryStoreAnalysis' AS [ModuleName]
            , @Now                     AS [CollectionTimeUtc]
            , @StatusCode              AS [StatusCode]
            , CONVERT(bit, CASE WHEN @StatusCode IN ('AVAILABLE','AVAILABLE_WITH_FINDING') THEN 0 ELSE 1 END) AS [IsPartial]
            , (SELECT COUNT_BIG(*) FROM [#QueryStoreAnalysis_MonitorTableResult]
               WHERE [InvocationStatus] NOT IN ('EXECUTED','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE','UNAVAILABLE_VERSION','UNAVAILABLE_FEATURE','FEATURE_DISABLED')) AS [ErrorCount]
            , N'Orchestrator; Teilmodule liefern eigene benannte Resultsets.' AS [Detail];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT * FROM [#QueryStoreAnalysis_MonitorTableResult] ORDER BY [ExecutionOrdinal];
        END
        ELSE
        BEGIN
            SELECT
                  N'Query-Store Teilmodul' AS [Ergebnis]
                , [ExecutionOrdinal]       AS [Reihenfolge]
                , [ModuleName]             AS [Modul]
                , [InvocationStatus]       AS [Status]
                , [ErrorMessage]           AS [Fehler]
            FROM [#QueryStoreAnalysis_MonitorTableResult]
            ORDER BY [ExecutionOrdinal];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @Warnings nvarchar(max);
        DECLARE @Meta nvarchar(max);

        SELECT @Warnings =
        (
            SELECT *
            FROM [#QueryStoreAnalysis_MonitorTableResult]
            WHERE [InvocationStatus] NOT IN ('EXECUTED','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE','UNAVAILABLE_VERSION','UNAVAILABLE_FEATURE','FEATURE_DISABLED')
            ORDER BY [ExecutionOrdinal]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SELECT @Meta =
        (
            SELECT
                  N'QueryStoreAnalysis' AS [resultName]
                , 1                     AS [schemaVersion]
                , @Now                  AS [generatedAtUtc]
                , @StatusCode           AS [statusCode]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@Meta, N'{}')
            , N',"status":', COALESCE(JSON_QUERY(@StatusJson), N'null')
            , N',"runtimeStats":', COALESCE(JSON_QUERY(@RuntimeJson), N'null')
            , N',"waitStats":', COALESCE(JSON_QUERY(@WaitJson), N'null')
            , N',"planChanges":', COALESCE(JSON_QUERY(@PlanJson), N'null')
            , N',"regressions":', COALESCE(JSON_QUERY(@RegressionJson), N'null')
            , N',"forcedPlans":', COALESCE(JSON_QUERY(@ForcedJson), N'null')
            , N',"queryHints":', COALESCE(JSON_QUERY(@HintsJson), N'null')
            , N',"replicaContext":', COALESCE(JSON_QUERY(@ReplicaJson), N'null')
            , N',"intelligentQueryProcessing":', COALESCE(JSON_QUERY(@IqpJson), N'null')
            , N',"warnings":', COALESCE(@Warnings, N'[]')
            , N'}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#QueryStoreAnalysis_MonitorTableResult'
            , @ResultLabel=N'QueryStoreAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#QueryStoreAnalysis_MonitorTableResult'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

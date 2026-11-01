USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_DistributedTransactionInventory
Version      : 1.0.0
Stand        : 2026-10-27
Zweck        : Die Procedure inventarisiert caller-sichtbare lokale MSDTC-Konfiguration und
               aktive Transaktionsmetadaten mit transaction_type = 4.
Quellen      : sys.configurations, sys.servers und
               sys.dm_tran_active_transactions.
Grenzen      : Caller-sichtbare SQL-Metadaten; kein Dienst-, Netzwerk-,
               Teilnehmer-, Commit- oder Recovery-Nachweis.
Datenschutz  : Keine Transaktionsnamen, UOWs, SQL-Texte, Identitäten,
               Linked-Servernamen oder Endpunktdaten.
Nebenwirkung : Rein lesend; keine Berechtigungs-, Konfigurations- oder
               Transaktionsänderung.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_DistributedTransactionInventory]
      @MaxZeilen int = 1000
    , @LockTimeoutMs int = 0
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
    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),
        @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
        @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END,
        @ProbeLimit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen)+1 END,
        @PreviousLockTimeout int=@@LOCK_TIMEOUT,
        @PreviousXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
        @RestoreLock nvarchar(100),@SetLock nvarchar(100),@SetLockSource nvarchar(max),
        @Started datetime2(3),@Observed bigint,@Returned bigint,
        @Status varchar(40)='AVAILABLE_LIMITED',@Error int=NULL,@Message nvarchar(2048)=NULL,
        @ConfigurationValue sql_variant=NULL,@ConfigurationValueInUse sql_variant=NULL,
        @ConfigurationIsDynamic bit=NULL,@ConfiguredInt int=NULL,@RunningInt int=NULL,
        @ConfiguredBaseType nvarchar(128),@RunningBaseType nvarchar(128);
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableStatus varchar(40),@TableMessage nvarchar(2048),
        @TableError int,@TableFailureError int=NULL;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_DistributedTransactionInventory';
        PRINT N'Erfasst getrennte caller-sichtbare lokale SQL-Momentaufnahmen: die einzelne remote proc trans-Konfigurationszeile, Linked-Server-Promotionflags und aktive lokale Transaktionsmetadaten mit transaction_type = 4.';
        PRINT N'Die sieben Mengen heißen moduleStatus, serverContext, promotionConfiguration, linkedServerPromotion, activeDistributedTransactions, sourceStatus und warnings; RAW liefert sie in dieser Reihenfolge, JSON fasst sie unter denselben Schlüsseln zusammen.';
        PRINT N'Das Inventar belegt weder den Zustand des MSDTC-Dienstes noch Netzwerk- oder Teilnehmererreichbarkeit, Commit, Rollback oder Recovery. Ein leerer DMV-Bestand beweist keine instanzweite Abwesenheit.';
        PRINT N'@Hilfe=1 gibt diese Hinweise aus und beendet die Procedure vor Validierung und Quellenzugriff.';
        PRINT N'@MaxZeilen int; Default: 1000. Die Fachmengen linkedServerPromotion und activeDistributedTransactions werden jeweils mit TOP (@MaxZeilen + 1) materialisiert, wenn ein positiver Wert angegeben ist; die zusätzliche Zeile dient nur dazu, eine Überschreitung zu erkennen. Anschließend werden beide Ausgabemengen auf @MaxZeilen gekürzt. NULL oder 0 steht für unbegrenzt; negative Werte werden vor Quellenzugriff mit INVALID_PARAMETER und RETURN 51011 abgelehnt. Die Konfigurationsquelle enthält höchstens die einzelne passende sys.configurations-Zeile und wird nicht über dieses Limit gekappt. Das Limit begrenzt die ausgegebenen und für die zwei Mengen materialisierten Zeilen, nicht garantiert den Aufwand der Quellermittlung. RowsReturned enthält nach der Kappung die ausgegebene Zeilenzahl; LimitApplied ist nur 1, wenn die Probe mehr Zeilen als die Ausgabe enthielt. Ein leerer sichtbarer Bestand belegt keine instanzweite Abwesenheit. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@LockTimeoutMs int; Default: 0. Steuert das in jedem dynamischen Quellenbatch gesetzte LOCK_TIMEOUT in Millisekunden. Zulässig sind 0 bis 60000 einschließlich; NULL und Werte außerhalb des Bereichs werden vor Quellenzugriff mit INVALID_PARAMETER und RETURN 51011 abgelehnt. 0 bedeutet für die Quellenbatches NOWAIT. Der Wert ist kein globales Zeitbudget. Bei einem eingehenden Sitzungswert von 0 schützt die Procedure ihre eigene anfängliche Temp-Tabellenanlage bedingt mit 1000 ms; vor den fachlichen Quellen setzt sie LOCK_TIMEOUT 0, und erst der jeweilige dynamische Quellenbatch verwendet diesen Parameter. Die erfolgreiche Rückkehr stellt den zuvor gespeicherten Locktimeout wieder her; SET-Werte aus dynamischen Batches belegen keine weiterreichende Sessionwirkung. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Wählt genau einen Ausgabemodus. Erlaubt sind CONSOLE (eine kompakte beschriftete Zusammenfassung), RAW (sieben Resultsets in der Reihenfolge moduleStatus, serverContext, promotionConfiguration, linkedServerPromotion, activeDistributedTransactions, sourceStatus, warnings), TABLE (schreibt die zugeordneten Mengen in Aufrufer-Temp-Tabellen) und NONE (unterdrückt Resultsets). Die Eingabe wird mit LTRIM/RTRIM von Rand-Leerzeichen bereinigt und mit UPPER großgeschrieben; der Vergleich ist damit unabhängig von Groß-/Kleinschreibung. NULL und Leertext werden zu einem ungültigen leeren Modus; jeder andere Wert liefert INVALID_PARAMETER und RETURN 51011. Außerhalb von TABLE muss @ResultTablesJson NULL oder nach Rand-Leerzeichen leer sein. JSON-Erzeugung ist unabhängig vom Resultsetmodus. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE: ein nicht leeres JSON-Objekt, dessen Eigenschaftsnamen exakt und groß-/kleinschreibungsgenau zu den erlaubten Resultsetnamen moduleStatus, serverContext, promotionConfiguration, linkedServerPromotion, activeDistributedTransactions, sourceStatus oder warnings passen; ein Teil der sieben Zuordnungen genügt. Jeder Eigenschaftswert muss eine Zeichenfolge mit dem Namen eines Ziels sein. Die Schlüssel bezeichnen jeweils: Gesamtstatus/Partialität/ausgegebene Fachzeilensumme; Server-Produktversion; konfigurierte und laufende remote proc trans-Werte samt is_dynamic; sichtbare Linked-Server-Promotionflags; sichtbare aktive Transaktionen vom Typ 4; die drei separaten Quellzustände; Warnungen. Zielnamen müssen eindeutige, vorhandene, leere lokale #Temp-Tabellen mit genau einer Seed-Spalte sein, höchstens 116 Zeichen lang. ##Temp, #Monitor*-Namen und permanente Ziele sind unzulässig. Resultset-Schlüssel werden binär exakt auf Duplikate geprüft; Zielnamen auf Duplikate ohne Beachtung der Groß-/Kleinschreibung. Alle Zuordnungen werden vor dem fachlichen Quellenzugriff vorgeprüft. Danach schreibt die Procedure die Resultsets nacheinander; ein späterer Schreibfehler kann bereits geschriebene frühere Ziele zurücklassen. Bei Nicht-TABLE muss der Parameter NULL oder leer sein, sonst INVALID_PARAMETER/RETURN 51011. Im TABLE-Modus sind NULL, Leerstring und ein Objekt ohne Zuordnungen ungültig. Außerhalb TABLE sind NULL, Leerstring oder reine U+0020-Leerzeichen erlaubt. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit; Default: 0. Bit-Schalter: 0 unterdrückt die JSON-Erzeugung, jeder numerische Wert ungleich 0 wird in den Bit-Parameter als 1 konvertiert und erzeugt das Diagnose-JSON unabhängig von @ResultSetArt; NULL verhält sich wie 0, weil IF @JsonErzeugen=1 dann nicht ausgeführt wird. Das JSON enthält meta sowie alle sieben benannten Mengen, auch wenn Mengen leer sind. Der Schalter erzeugt selbst kein separates Resultset. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang für das bei @JsonErzeugen=1 erzeugte JSON. Binden Sie eine Variable vom Typ nvarchar(max) mit OUTPUT. Der Eingangswert wird am Prozedureintritt auf NULL gesetzt; bei Hilfe, ungültigen Parametern oder einem äußeren Fehler bleibt beziehungsweise wird er NULL. Ohne JSON-Anforderung wird keine JSON-Zeichenfolge erzeugt. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@PrintMeldungen bit; Default: 1. Bit-Schalter: 0 unterdrückt die bedingten RAISERROR-Hinweise der normalen Parameterprüfung, der Quellenfehler-Meldung und des äußeren Fehlerpfads; jeder numerische Wert ungleich 0 konvertiert zu 1 und lässt diese Hinweise zu. NULL verhält sich wegen IF @PrintMeldungen=1 wie 0. Die PRINT-Ausgabe des Hilfezweigs sind davon nicht abhängig und werden bei @Hilfe=1 ausgegeben. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit; Default: 0. Bit-Schalter: 0 führt die normale Inventarisierung aus; jeder numerische Wert ungleich 0 wird zu 1 und gibt die eingebaute Hilfe aus, setzt @StatusCodeOut auf AVAILABLE und @IsPartialOut auf 0 und beendet die Procedure vor Validierung und Quellenzugriff. NULL verhält sich wie 0. Der Hilfezweig setzt die drei übrigen OUTPUT-Werte nicht neu, nachdem sie am Eintritt zurückgesetzt wurden: @Json bleibt NULL, @ErrorNumberOut und @ErrorMessageOut bleiben NULL. Der normale EXIT-RETURN ist 0; dies ist kein Fehler- oder Diagnose-Rückgabecode. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionales OUTPUT für den Statuscode als varchar(40); binden Sie eine entsprechende Caller-Variable mit OUTPUT. Der Wert wird bei Eintritt auf NULL gesetzt. Hilfe liefert AVAILABLE; ungültige Parameter liefern INVALID_PARAMETER; der reguläre Ausführungspfad beginnt mit AVAILABLE_LIMITED und übernimmt bei mindestens einem Quellenfehler den Status der alphabetisch ersten fehlerhaften Quelle (Sortierung nach SourceName: ACTIVE_DISTRIBUTED_TRANSACTIONS vor LINKED_SERVER_PROMOTION vor SERVER_CONFIGURATION). Quellenfehler sind DENIED_PERMISSION für Fehlernummern 229, 297, 300 oder 371, TIMEOUT für 1222, sonst ERROR_HANDLED. Ein äußerer Fehler, einschließlich eines fehlgeschlagenen TABLE-Schreibens, überschreibt den OUTPUT-Status mit ERROR_HANDLED. Erfolg im normalen Pfad bleibt AVAILABLE_LIMITED, da das Modul stets als partiell gekennzeichnet wird. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionales OUTPUT-Bit; binden Sie eine Bit-Variable mit OUTPUT. Der Wert wird bei Eintritt NULL. Hilfe setzt 0; ungültige Parameter und der normale Quellenpfad sowie der äußere Fehlerpfad setzen 1. Die normale Ausführung ist stets partiell, weil Caller-Sichtbarkeit und externe Dienst-, Netzwerk-, Teilnehmer-, Commit- und Recovery-Grenzen offenbleiben; ein leerer sichtbarer Bestand hebt dies nicht auf. Numerische Nichtnull-Eingaben sind für diesen reinen OUTPUT-Parameter kein Eingabeschalter. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optionales OUTPUT für die gewählte native oder diagnostische Fehlernummer; binden Sie eine int-Variable mit OUTPUT. Der Wert wird am Eintritt NULL. Für Hilfe und fehlerfreie normale Ausführung bleibt er NULL; ungültige Parameter setzen 51011. Bei mehreren Quellenfehlern werden Nummer und Meldung aus der alphabetisch ersten fehlerhaften Quelle übernommen. Beim äußeren Fehlerpfad enthält er die abgefangene SQL-Fehlernummer, außer dass ein gesetzter TABLE-Fehler die zuvor gespeicherte Tabellenfehlernummer bevorzugt; fehlt diese, wird die native SQL-Fehlernummer verwendet. TABLE-Vorprüfung liefert 51011, Writerfehler die gespeicherte Nummer oder 51010; der äußere CATCH setzt diese Nummer zugleich als Diagnose-RETURN. Reguläre Quellenfehler ändern den normalen RETURN 0 nicht. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionales OUTPUT für die zugehörige Meldung als nvarchar(2048); binden Sie eine entsprechende Variable mit OUTPUT. Der Wert wird am Eintritt NULL. Hilfe und fehlerfreie Ausführung lassen ihn NULL; ungültige Parameter setzen die feste Validierungsmeldung. Bei mehreren Quellenfehlern wird die Meldung der alphabetisch ersten fehlerhaften Quelle übernommen. Ein äußerer Fehler liefert den nativen SQL-Fehlertext; bei TABLE-Fehlern stammt die Meldung aus dem äußeren CATCH, dessen RAISERROR zuvor den TableMessage-Text erhalten hat; die gespeicherte TABLE-Fehlernummer priorisiert nur die Nummer. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'EXEC [monitor].[USP_DistributedTransactionInventory] @MaxZeilen=200, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_DistributedTransactionInventory] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];';
        PRINT N'CREATE TABLE [#DistributedTransactionInventory_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DistributedTransactionInventory] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"linkedServerPromotion":"#DistributedTransactionInventory_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM [#DistributedTransactionInventory_HelpExample]; DROP TABLE IF EXISTS [#DistributedTransactionInventory_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#DistributedTransactionInventory_HelpExample]; THROW; END CATCH;';
        PRINT N'EXEC [monitor].[USP_DistributedTransactionInventory] @Hilfe=1;';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN;
    END;
    IF @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE') OR @MaxZeilen<0
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs<0 OR @LockTimeoutMs>60000
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorNumberOut=51011,@ErrorMessageOut=N'Ungültiger Ausgabe-, Limit-, Locktimeout- oder TABLE-Parameter.';
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@ErrorMessageOut) WITH NOWAIT;
        RETURN 51011;
    END;

    BEGIN TRY
        SET XACT_ABORT OFF;
        IF @PreviousLockTimeout=0 SET LOCK_TIMEOUT 1000;
        CREATE TABLE [#DistributedTransactionInventory_moduleStatus]
        (
            [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [CapturedAtUtc] datetime2(3) NOT NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsPartial] bit NOT NULL,
            [RowCount] bigint NOT NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_serverContext]
        (
            [ProductMajorVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_promotionConfiguration]
        (
            [ConfiguredValue] int NULL,
            [RunningValue] int NULL,
            [IsDynamic] bit NOT NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_linkedServerPromotion]
        (
            [ServerId] int NOT NULL,
            [RemoteProcTransactionPromotionEnabled] bit NOT NULL,
            [ModifiedAt] datetime NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_activeDistributedTransactions]
        (
            [TransactionId] bigint NOT NULL,
            [TransactionType] int NOT NULL,
            [TransactionBeginTime] datetime NULL,
            [TransactionState] int NOT NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_sourceStatus]
        (
            [SourceName] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [CaptureStartedAtUtc] datetime2(3) NOT NULL,
            [CaptureEndedAtUtc] datetime2(3) NOT NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsPartial] bit NOT NULL,
            [RowsReturned] bigint NULL,
            [LimitApplied] bit NOT NULL,
            [ErrorNumber] int NULL,
            [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [VisibilityLimit] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_warnings]
        (
            [WarningCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [SourceName] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_Map]
        (
            [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_Console]
        (
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsPartial] bit NOT NULL,
            [ProductMajorVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ConfiguredValue] int NULL,
            [RunningValue] int NULL,
            [LinkedServerRowsReturned] bigint NOT NULL,
            [ActiveTransactionRowsReturned] bigint NOT NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        INSERT [#DistributedTransactionInventory_serverContext]([ProductMajorVersion])
        VALUES(CONVERT(nvarchar(128),SERVERPROPERTY(N'ProductMajorVersion')) COLLATE SQL_Latin1_General_CP1_CS_AS);

        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|serverContext|promotionConfiguration|linkedServerPromotion|activeDistributedTransactions|sourceStatus|warnings',
                @MappingTable=N'#DistributedTransactionInventory_Map',@StatusCode=@TableStatus OUTPUT,
                @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE'
            BEGIN
                SET @TableFailureError=51011;
                RAISERROR(N'%s',16,1,@TableMessage);
            END;
        END;
        SET LOCK_TIMEOUT 0;
        SET @SetLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; ';

        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @Observed=0;
            SET @SetLockSource=@SetLock+N'SELECT @ConfiguredValue=[c].[value],@RunningValue=[c].[value_in_use],@IsDynamic=[c].[is_dynamic]
                FROM [sys].[configurations] AS [c] WITH (NOLOCK)
                WHERE [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''remote proc trans'' COLLATE SQL_Latin1_General_CP1_CS_AS;
                SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @SetLockSource,
                N'@ConfiguredValue sql_variant OUTPUT,@RunningValue sql_variant OUTPUT,@IsDynamic bit OUTPUT,@Rows bigint OUTPUT',
                @ConfiguredValue=@ConfigurationValue OUTPUT,@RunningValue=@ConfigurationValueInUse OUTPUT,
                @IsDynamic=@ConfigurationIsDynamic OUTPUT,@Rows=@Observed OUTPUT;
            IF @Observed>0
            BEGIN
                SET @ConfiguredBaseType=CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY(@ConfigurationValue,N'BaseType'));
                SET @RunningBaseType=CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY(@ConfigurationValueInUse,N'BaseType'));
                SET @ConfiguredInt=CASE WHEN @ConfigurationValue IS NULL THEN NULL
                    WHEN @ConfiguredBaseType COLLATE SQL_Latin1_General_CP1_CS_AS=N'int' COLLATE SQL_Latin1_General_CP1_CS_AS
                    THEN CONVERT(int,@ConfigurationValue) ELSE NULL END;
                SET @RunningInt=CASE WHEN @ConfigurationValueInUse IS NULL THEN NULL
                    WHEN @RunningBaseType COLLATE SQL_Latin1_General_CP1_CS_AS=N'int' COLLATE SQL_Latin1_General_CP1_CS_AS
                    THEN CONVERT(int,@ConfigurationValueInUse) ELSE NULL END;
                INSERT [#DistributedTransactionInventory_promotionConfiguration]
                    ([ConfiguredValue],[RunningValue],[IsDynamic])
                VALUES(@ConfiguredInt,@RunningInt,@ConfigurationIsDynamic);
                IF (@ConfigurationValue IS NOT NULL AND (@ConfiguredBaseType IS NULL OR @ConfiguredBaseType COLLATE SQL_Latin1_General_CP1_CS_AS<>N'int' COLLATE SQL_Latin1_General_CP1_CS_AS))
                   OR (@ConfigurationValueInUse IS NOT NULL AND (@RunningBaseType IS NULL OR @RunningBaseType COLLATE SQL_Latin1_General_CP1_CS_AS<>N'int' COLLATE SQL_Latin1_General_CP1_CS_AS))
                    INSERT [#DistributedTransactionInventory_warnings]
                        VALUES('CONFIG_VALUE_TYPE_UNSUPPORTED','SERVER_CONFIGURATION',
                               N'Der native sql_variant-Wert konnte nicht typgetreu als int abgebildet werden; das betroffene Ausgabefeld bleibt NULL.');
            END;
            INSERT [#DistributedTransactionInventory_sourceStatus]
            VALUES('SERVER_CONFIGURATION',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED',1,@Observed,0,NULL,NULL,
                   N'Caller-sichtbare sys.configurations-Zeile; nur der Serverdefault für remote proc trans.');
        END TRY
        BEGIN CATCH
            DELETE FROM [#DistributedTransactionInventory_promotionConfiguration];
            INSERT [#DistributedTransactionInventory_sourceStatus]
            VALUES('SERVER_CONFIGURATION',@Started,SYSUTCDATETIME(),
                CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                     WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                1,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE(),N'UNPROVEN');
        END CATCH;

        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @SetLockSource=@SetLock+N'INSERT [#DistributedTransactionInventory_linkedServerPromotion]
                ([ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt])
                SELECT TOP (@ProbeLimit) [s].[server_id],[s].[is_remote_proc_transaction_promotion_enabled],[s].[modify_date]
                FROM [sys].[servers] AS [s] WITH (NOLOCK)
                WHERE [s].[is_linked]=1
                ORDER BY [s].[server_id];
                SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @SetLockSource,N'@ProbeLimit bigint,@Rows bigint OUTPUT',@ProbeLimit=@ProbeLimit,@Rows=@Observed OUTPUT;
            INSERT [#DistributedTransactionInventory_sourceStatus]
            VALUES('LINKED_SERVER_PROMOTION',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED',1,@Observed,0,NULL,NULL,
                   N'Nur caller-sichtbare Linked-Serverflags; Namen und Verbindungseigenschaften sind ausgeschlossen.');
        END TRY
        BEGIN CATCH
            DELETE FROM [#DistributedTransactionInventory_linkedServerPromotion];
            INSERT [#DistributedTransactionInventory_sourceStatus]
            VALUES('LINKED_SERVER_PROMOTION',@Started,SYSUTCDATETIME(),
                CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                     WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                1,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE(),N'UNPROVEN');
        END CATCH;

        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @SetLockSource=@SetLock+N'INSERT [#DistributedTransactionInventory_activeDistributedTransactions]
                ([TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState])
                SELECT TOP (@ProbeLimit) [t].[transaction_id],[t].[transaction_type],[t].[transaction_begin_time],[t].[transaction_state]
                FROM [sys].[dm_tran_active_transactions] AS [t] WITH (NOLOCK)
                WHERE [t].[transaction_type]=4
                ORDER BY [t].[transaction_begin_time],[t].[transaction_id];
                SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @SetLockSource,N'@ProbeLimit bigint,@Rows bigint OUTPUT',@ProbeLimit=@ProbeLimit,@Rows=@Observed OUTPUT;
            INSERT [#DistributedTransactionInventory_sourceStatus]
            VALUES('ACTIVE_DISTRIBUTED_TRANSACTIONS',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED',1,@Observed,0,NULL,NULL,
                   N'Nur sichtbare lokale Transaktionsmetadaten mit transaction_type = 4; kein Teilnehmer- oder Commitnachweis.');
        END TRY
        BEGIN CATCH
            DELETE FROM [#DistributedTransactionInventory_activeDistributedTransactions];
            INSERT [#DistributedTransactionInventory_sourceStatus]
            VALUES('ACTIVE_DISTRIBUTED_TRANSACTIONS',@Started,SYSUTCDATETIME(),
                CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                     WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                1,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE(),N'UNPROVEN');
        END CATCH;

        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [ServerId]) AS [OutputOrdinal]
         FROM [#DistributedTransactionInventory_linkedServerPromotion])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        SELECT @Returned=COUNT_BIG(*) FROM [#DistributedTransactionInventory_linkedServerPromotion];
        UPDATE [#DistributedTransactionInventory_sourceStatus]
           SET [RowsReturned]=@Returned,
               [LimitApplied]=CASE WHEN [RowsReturned]>@Returned THEN 1 ELSE 0 END
         WHERE [SourceName]='LINKED_SERVER_PROMOTION';

        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [TransactionBeginTime],[TransactionId]) AS [OutputOrdinal]
         FROM [#DistributedTransactionInventory_activeDistributedTransactions])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        SELECT @Returned=COUNT_BIG(*) FROM [#DistributedTransactionInventory_activeDistributedTransactions];
        UPDATE [#DistributedTransactionInventory_sourceStatus]
           SET [RowsReturned]=@Returned,
               [LimitApplied]=CASE WHEN [RowsReturned]>@Returned THEN 1 ELSE 0 END
         WHERE [SourceName]='ACTIVE_DISTRIBUTED_TRANSACTIONS';

        INSERT [#DistributedTransactionInventory_warnings]
        VALUES('METADATA_COMPLETENESS_UNPROVEN',NULL,
               N'Alle Mengen beschreiben ausschließlich caller-sichtbare lokale SQL-Metadaten. Sie belegen weder MSDTC-Gesundheit noch Teilnehmererreichbarkeit, Commit oder Recovery.');
        INSERT [#DistributedTransactionInventory_warnings]
            SELECT 'OUTPUT_LIMIT',[SourceName],
                   N'Das Fachresultset ist gekappt. Das Zeilenlimit begrenzt die Ausgabe, nicht garantiert die vorgelagerte Katalog- oder DMV-Lesearbeit.'
            FROM [#DistributedTransactionInventory_sourceStatus] WHERE [LimitApplied]=1;
        INSERT [#DistributedTransactionInventory_warnings]
            SELECT 'SOURCE_UNAVAILABLE',[SourceName],
                   N'Die Quelle konnte nicht gelesen werden; andere sichtbare Quellen bleiben separat auswertbar.'
            FROM [#DistributedTransactionInventory_sourceStatus] WHERE [ErrorNumber] IS NOT NULL;
        SELECT TOP (1) @Error=[ErrorNumber],@Message=[ErrorMessage]
          FROM [#DistributedTransactionInventory_sourceStatus] WHERE [ErrorNumber] IS NOT NULL
          ORDER BY [SourceName];
        SELECT TOP (1) @Status=[StatusCode]
          FROM [#DistributedTransactionInventory_sourceStatus] WHERE [ErrorNumber] IS NOT NULL
          ORDER BY [SourceName];
        SET @Status=COALESCE(@Status,'AVAILABLE_LIMITED');
        DECLARE @Rows bigint=(SELECT COUNT_BIG(*) FROM [#DistributedTransactionInventory_promotionConfiguration])+
            (SELECT COUNT_BIG(*) FROM [#DistributedTransactionInventory_linkedServerPromotion])+
            (SELECT COUNT_BIG(*) FROM [#DistributedTransactionInventory_activeDistributedTransactions]);
        INSERT [#DistributedTransactionInventory_moduleStatus]
        VALUES(N'USP_DistributedTransactionInventory',@CapturedAtUtc,@Status,1,@Rows,
               N'Getrennte lokale serverweite Konfigurations- und Transaktionsmetadatenaufnahmen im Caller-Kontext; kein DTC-Dienst- oder Commitnachweis.');

        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'DistributedTransactionInventory' AS [resultName],1 AS [schemaVersion],
                @CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],CAST(1 AS bit) AS [isPartial],
                @Error AS [errorNumber],@Message AS [errorMessage]
                FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_serverContext nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_serverContext] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_promotionConfiguration nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_promotionConfiguration] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_linkedServerPromotion nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_linkedServerPromotion] ORDER BY [ServerId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_activeDistributedTransactions nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_activeDistributedTransactions] ORDER BY [TransactionBeginTime],[TransactionId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_sourceStatus] ORDER BY [SourceName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_warnings] ORDER BY [WarningCode],[SourceName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),
                N',"serverContext":',COALESCE(@Json_serverContext,N'[]'),
                N',"promotionConfiguration":',COALESCE(@Json_promotionConfiguration,N'[]'),
                N',"linkedServerPromotion":',COALESCE(@Json_linkedServerPromotion,N'[]'),
                N',"activeDistributedTransactions":',COALESCE(@Json_activeDistributedTransactions,N'[]'),
                N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),
                N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;

        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#DistributedTransactionInventory_moduleStatus];
            SELECT * FROM [#DistributedTransactionInventory_serverContext];
            SELECT * FROM [#DistributedTransactionInventory_promotionConfiguration];
            SELECT * FROM [#DistributedTransactionInventory_linkedServerPromotion] ORDER BY [ServerId];
            SELECT * FROM [#DistributedTransactionInventory_activeDistributedTransactions] ORDER BY [TransactionBeginTime],[TransactionId];
            SELECT * FROM [#DistributedTransactionInventory_sourceStatus] ORDER BY [SourceName];
            SELECT * FROM [#DistributedTransactionInventory_warnings] ORDER BY [WarningCode],[SourceName];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [DistributedTransactionOutput] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [ResultName],[TargetTable] FROM [#DistributedTransactionInventory_Map] ORDER BY [ResultName];
            OPEN [DistributedTransactionOutput];
            FETCH NEXT FROM [DistributedTransactionOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#DistributedTransactionInventory_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                    @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,
                    @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN
                    SET @TableFailureError=COALESCE(@TableError,51010);
                    RAISERROR(N'%s',16,1,@TableMessage);
                END;
                FETCH NEXT FROM [DistributedTransactionOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [DistributedTransactionOutput]; DEALLOCATE [DistributedTransactionOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            INSERT [#DistributedTransactionInventory_Console]
            SELECT @Status,CONVERT(bit,1),[ctx].[ProductMajorVersion],
                   [cfg].[ConfiguredValue],[cfg].[RunningValue],
                   (SELECT COUNT_BIG(*) FROM [#DistributedTransactionInventory_linkedServerPromotion]),
                   (SELECT COUNT_BIG(*) FROM [#DistributedTransactionInventory_activeDistributedTransactions]),
                   N'Caller-sichtbare lokale SQL-Metadaten; keine DTC-Dienst-, Teilnehmer-, Commit- oder Recoveryprüfung.'
            FROM [#DistributedTransactionInventory_serverContext] AS [ctx]
            LEFT JOIN [#DistributedTransactionInventory_promotionConfiguration] AS [cfg] ON 1=1;
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#DistributedTransactionInventory_Console',
                @ResultLabel=N'Sichtbare MSDTC-Konfiguration und aktive Transaktionsmetadaten',
                @EmptyMessage=N'Keine sichtbaren SQL-Metadaten.';
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL
            RAISERROR(N'USP_DistributedTransactionInventory: mindestens eine Quelle ist nicht verfügbar; siehe sourceStatus.',10,1) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    END TRY
    BEGIN CATCH
        SELECT @Error=COALESCE(@TableFailureError,ERROR_NUMBER()),@Message=ERROR_MESSAGE(),@Json=NULL;
        SELECT @StatusCodeOut='ERROR_HANDLED',@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO
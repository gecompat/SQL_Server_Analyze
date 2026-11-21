/*
===============================================================================
Objekt       : snapshot.InternalConfigureSnapshotPolicy
Version      : 1.2.0
Stand        : 2026-10-26
Zweck        : Schreibt und prüft typisierte Collector- und Shared-Policies in
               der aktuell verbundenen Snapshot-Datenbank.
===============================================================================

Interner Aufrufvertrag

Die Procedure aktualisiert vorhandene Zeilen in [snapshot].[CollectorPolicy] und bei wirksamem Shared-Update die vorhandene DEFAULT-Zeile in [snapshot].[RetentionPolicy]. Sie fügt keine Zeilen ein, erfasst keine Daten, bereinigt keine Daten und führt kein DDL aus. Sie arbeitet in der aktuell verbundenen Snapshot-Datenbank. Defaults sind Konfigurationswerte und starten keine Erfassung oder Bereinigung.

Erweiterte Aufrufe verlangen IMPLICIT_TRANSACTIONS OFF. Erweiterte WAIT_STATS/FILE_IO-Aufrufe mit Join=0 verlangen keine Callertransaktion. Join=1 ist nur für WAIT_STATS/FILE_IO mit wirksamem @UpdateSharedPolicy=1, genau einer committable Callertransaktion (XACT_STATE()=1) und IMPLICIT_TRANSACTIONS OFF zulässig. Der Eigentümer behält COMMIT/ROLLBACK; die Procedure erstellt keinen Savepoint. Erweiterte PERFORMANCE_COUNTERS-Aufrufe können eine eigene Transaktion oder bei Callertransaktion einen Savepoint nutzen; Rollback zum Savepoint erfolgt nur bei XACT_STATE()=1. Der Legacy-Standardaufruf PERFORMANCE_COUNTERS mit @CollectorEnabled=1, wirksamem @UpdateSharedPolicy=1 (explizit oder automatisch), allen drei Identitätswerten NULL und @JoinFrameworkTransaction=0 führt BEGIN TRANSACTION und bei Erfolg COMMIT TRANSACTION auch innerhalb einer bestehenden Transaktion aus; CATCH kann die gesamte Callertransaktion zurückrollen. Andere gültige Einstellungen wählen erweiterte Prüfungen; die optionale vollständig NULL gesetzte PC-Identität allein aktiviert sie nicht.

Parametervertrag

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
| --- | --- | --- | --- |
| `@CollectionIntervalSeconds` | smallint | Kein Default; Pflichtargument | Erwartet eine ganze Sekundenzahl von 1 bis 3600. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Im erweiterten Pfad wird NULL ausdrücklich zurückgewiesen. Im Legacy-Pfad gibt es keine ausdrückliche NULL-Prüfung; NULL kann die Bereichsprüfung passieren und erst beim NOT-NULL-Schreiben einen abgefangenen Fehler auslösen. |
| `@MaxRows` | int | Kein Default; Pflichtargument | Erwartet eine ganze Zeilenzahl von 1 bis 100000. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Im erweiterten Pfad wird NULL ausdrücklich zurückgewiesen. Im Legacy-Pfad gibt es keine ausdrückliche NULL-Prüfung; NULL kann die Bereichsprüfung passieren und erst beim NOT-NULL-Schreiben einen abgefangenen Fehler auslösen. |
| `@PayloadEnabled` | bit | Kein Default; Pflichtargument | 0 speichert eine deaktivierte Payloadpolicy, 1 eine aktivierte Payloadpolicy. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Im erweiterten Pfad wird NULL ausdrücklich zurückgewiesen. Im Legacy-Pfad gibt es keine ausdrückliche NULL-Prüfung; NULL kann die Bereichsprüfung passieren und erst beim NOT-NULL-Schreiben einen abgefangenen Fehler auslösen. |
| `@RawRetentionDays` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 3650 Tagen. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |
| `@PayloadRetentionDays` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 3650 Tagen. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |
| `@RollupRetentionDays` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 3650 Tagen. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |
| `@SoftBudgetMB` | int | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 2147483647 MB. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |
| `@PurgeIntervalMinutes` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 1440 Minuten. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |
| `@PurgeBatchRows` | int | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zeilenzahl von 1 bis 100000 als gespeicherte Purge-Batchgröße. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |
| `@BudgetAction` | varchar(32) | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 ist ausschließlich `PURGE_EXPIRED_THEN_STOP` zulässig; dies bezeichnet die gespeicherte Aktion zur Bereinigung abgelaufener Daten vor einem budgetbedingten Sammelstopp. Die Procedure speichert den Wert, führt selbst jedoch keine Bereinigung aus. Das Argument darf nicht ausgelassen werden. Bei wirksamem `@UpdateSharedPolicy`=1 ist Leertext ungültig; erweiterte Aufrufe weisen NULL ausdrücklich zurück. Im Legacy-Pfad kann NULL die Dreiwertlogik der Wertprüfung passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL oder Leertext ignoriert; das Argument bleibt erforderlich. |
| `@StatusCodeOut` | varchar(40) OUTPUT | Kein Default; Pflichtargument | Das Argument darf nicht ausgelassen werden. Eine gebundene Variable muss mit OUTPUT übergeben werden, um den Wert zu empfangen; ohne OUTPUT wird die Ausgabe verworfen. Eingehende NULL-, Leer- oder sonstige Anfangswerte werden ignoriert; die Variable wird auf `AVAILABLE` zurückgesetzt. Geschlossene Statuswerte: `AVAILABLE` (verfügbar/erfolgreich), `INVALID_PARAMETER` (ungültiger Parameter oder Aufrufvertrag), `TARGET_UNAVAILABLE` (Zielidentität oder Paket nicht verfügbar), `DENIED_PERMISSION` (abgefangener Berechtigungsfehler), `ERROR_HANDLED` (sonstiger abgefangener Fehler). |
| `@ErrorNumberOut` | int OUTPUT | Kein Default; Pflichtargument | Das Argument darf nicht ausgelassen werden. Eine gebundene Variable muss mit OUTPUT übergeben werden, um die Nummer oder NULL zu empfangen; ohne OUTPUT wird die Ausgabe verworfen. Eingehende NULL-, Leer- oder sonstige Anfangswerte werden ignoriert; die Variable wird auf NULL zurückgesetzt. Frühe Vertragsfehler setzen 51011 und RETURN 51011; Bereichsfehler setzen keine Fehlernummer und führen dieses RETURN nicht aus. 53764 bezeichnet eine abweichende Zielidentität, 53761 einen fehlenden erweiterten Paketvertrag und 53781 die fehlende `FILE_IO`-Version. Abgefangene Fehler 229, 262, 297, 300 und 371 ergeben `DENIED_PERMISSION`; sonstige abgefangene Fehler ergeben `ERROR_HANDLED`. Fehler 53700 bezeichnet eine fehlende Collectorzeile. Nicht alle nativen Fehler werden abgefangen; die Fehlernummer ist daher kein geschlossenes Set. |
| `@ErrorMessageOut` | nvarchar(2048) OUTPUT | Kein Default; Pflichtargument | Das Argument darf nicht ausgelassen werden. Eine gebundene Variable muss mit OUTPUT übergeben werden, um Meldung oder NULL zu empfangen; ohne OUTPUT wird die Ausgabe verworfen. Eingehende NULL-, Leer- oder sonstige Anfangswerte werden ignoriert; die Variable wird auf NULL zurückgesetzt. Bei behandelten Fehlern enthält der Parameter den Meldungstext; bei regulärem Erfolg bleibt NULL. Identitäts-, Paket- und Modulprüfungen können vor TRY zurückkehren. |
| `@CollectorCode` | varchar(64) | `'PERFORMANCE_COUNTERS'` | Ein einzelner Code, keine Liste und kein Pattern. Beim Auslassen gilt der Default `PERFORMANCE_COUNTERS`. Normalisierung erfolgt mit UPPER(LTRIM(RTRIM(COALESCE(Wert,'')))); getrimmt wird das SQL-Leerzeichen U+0020. NULL sowie leerer oder nur aus Leerzeichen bestehender Text werden zu leer und sind ungültig; sie lösen nicht den Default aus. Zulässige Werte und Bedeutung: `PERFORMANCE_COUNTERS` (Performance Counter), `WAIT_STATS` (Wartestatistik), `FILE_IO` (Datei-I/O). |
| `@CollectorEnabled` | bit | 1 | Default 1. 0 deaktiviert die Collectorpolicy, 1 aktiviert sie. NULL ist ungültig; leerer Text ist keine unterstützte Eingabeform. Das Argument kann wegen des Defaults ausgelassen werden. Der Wert konfiguriert nur die Policy und startet keine Erfassung. |
| `@UpdateSharedPolicy` | bit | NULL | Beim Auslassen gilt Default NULL. NULL wählt automatisch 1 für `PERFORMANCE_COUNTERS` und 0 für `WAIT_STATS`/`FILE_IO`. 0 aktualisiert nur den Collector, erhält dessen bestehendes RetentionPolicyCode und ignoriert alle sieben Shared-Parameter einschließlich NULL; diese Argumente bleiben dennoch erforderlich. 1 aktualisiert die `DEFAULT`-Retentionpolicy und weist dem Collector `DEFAULT` zu; dies wirkt auf weitere Collector, die `DEFAULT` verwenden. Erweiterte Aufrufe weisen NULL für wirksame Shared-Werte ausdrücklich zurück. Im Legacy-Pfad können NULL-Werte die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Leertext ist keine unterstützte Eingabeform. Konfigurationswerte starten keine Erfassung oder Bereinigung. |
| `@ExpectedTargetDatabaseId` | int | NULL | Default NULL; das Argument kann ausgelassen werden. Für `PERFORMANCE_COUNTERS` darf das gesamte Identitätstripel auch im erweiterten Pfad NULL sein. `WAIT_STATS`/`FILE_IO` benötigen ID, Name und CreateDate; sobald irgendein Identitätsfeld ungleich NULL ist, müssen alle drei vorliegen. Die ID muss größer als 4 und gleich `DB_ID()` der aktuell verbundenen Datenbank sein. Leertext ist keine unterstützte Eingabeform. |
| `@ExpectedTargetDatabaseName` | sysname | NULL | Default NULL; das Argument kann ausgelassen werden. Für `PERFORMANCE_COUNTERS` darf das gesamte Identitätstripel auch im erweiterten Pfad NULL sein. `WAIT_STATS`/`FILE_IO` benötigen ID, Name und CreateDate; sobald irgendein Identitätsfeld ungleich NULL ist, müssen alle drei vorliegen. Verglichen wird der rohe Datenbankname binär exakt mit `master.sys.databases.name`, ohne Trim oder Groß-/Kleinschreibungsnormalisierung. Ein leerer Name kann den Vergleich nicht erfüllen. |
| `@ExpectedTargetCreateDate` | datetime | NULL | Default NULL; das Argument kann ausgelassen werden. Für `PERFORMANCE_COUNTERS` darf das gesamte Identitätstripel auch im erweiterten Pfad NULL sein. `WAIT_STATS`/`FILE_IO` benötigen ID, Name und CreateDate; sobald irgendein Identitätsfeld ungleich NULL ist, müssen alle drei vorliegen. Leertext ist keine unterstützte Datumseingabe. Erwartet wird der typisierte, als datetime erfasste Erstellungswert; er muss exakt dem als datetime erfassten `master.sys.databases.create_date` entsprechen; keine UTC-Konvertierung. Die Zieldatenbank muss ONLINE und schreibbar sein. Das Tripel schützt vor Wiederverwendung einer Datenbank; die Procedure wechselt die Datenbank nicht. |
| `@JoinFrameworkTransaction` | bit | 0 | Default 0; das Argument kann ausgelassen werden. NULL ist ungültig; leerer Text ist keine unterstützte Eingabeform. 1 ist nur für `WAIT_STATS`/`FILE_IO` bei wirksamem `@UpdateSharedPolicy`=1, genau einer committable Callertransaktion (`XACT_STATE()`=1) und `IMPLICIT_TRANSACTIONS` OFF zulässig. Der Eigentümer behält COMMIT/ROLLBACK; bei Join=1 erstellt die Procedure keinen Savepoint. Bei Join=0 verlangen erweiterte `WAIT_STATS`/`FILE_IO`-Aufrufe keine Callertransaktion. Alle erweiterten Aufrufe verlangen `IMPLICIT_TRANSACTIONS` OFF. Erweiterte `PERFORMANCE_COUNTERS`-Aufrufe können eine eigene Transaktion oder bei Callertransaktion einen Savepoint nutzen; Rollback zum Savepoint erfolgt ausschließlich bei `XACT_STATE()`=1. Der Legacy-Standardaufruf `PERFORMANCE_COUNTERS` mit CollectorEnabled=1, wirksamem Shared=1 (explizit oder automatisch), allen Identitätswerten NULL und Join=0 führt BEGIN TRANSACTION und bei Erfolg COMMIT TRANSACTION auch innerhalb einer bestehenden Transaktion aus; CATCH kann die gesamte Callertransaktion zurückrollen. Andere gültige Einstellungen wählen erweiterte Prüfungen; die optionale PC-Identität allein aktiviert sie nicht. |

Der erweiterte Paketvertrag erfordert genau eine SC-023-Zeile mit Version 1.2.1/Schema 2 oder 1.3.0 beziehungsweise 1.3.1/Schema 3, außerdem InternalCompleteWaitStatsCycle und InternalPurgeExpiredData mit @ContractOnly. FILE_IO erfordert Version 1.3.1/Schema 3. Die Procedure aktualisiert genau eine vorhandene CollectorPolicy-Zeile; andernfalls entsteht Fehler 53700.

NULL-Prüfungen unterscheiden sich je Pfad: erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück. Im Legacy-Pfad können NULL-Werte bei den drei Collectorwerten und den Shared-Parametern wegen SQL-Dreiwertlogik Bereichsprüfungen passieren und erst beim NOT-NULL-Schreiben im CATCH scheitern. Daher gilt dafür keine einheitliche INVALID_PARAMETER-Zusage. Frühe Vertragsfehler setzen 51011 und RETURN 51011; Bereichsfehler setzen keine Fehlernummer und führen dieses RETURN nicht aus. Identitäts- und Paketprüfungen erfolgen vor TRY; nicht alle nativen Fehler werden abgefangen.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [snapshot].[InternalConfigureSnapshotPolicy]
      @CollectionIntervalSeconds smallint
    , @MaxRows                  int
    , @PayloadEnabled           bit
    , @RawRetentionDays         smallint
    , @PayloadRetentionDays     smallint
    , @RollupRetentionDays      smallint
    , @SoftBudgetMB             int
    , @PurgeIntervalMinutes     smallint
    , @PurgeBatchRows           int
    , @BudgetAction             varchar(32)
    , @StatusCodeOut            varchar(40) OUTPUT
    , @ErrorNumberOut           int OUTPUT
    , @ErrorMessageOut          nvarchar(2048) OUTPUT
    , @CollectorCode            varchar(64) = 'PERFORMANCE_COUNTERS'
    , @CollectorEnabled         bit = 1
    , @UpdateSharedPolicy       bit = NULL
    , @ExpectedTargetDatabaseId int = NULL
    , @ExpectedTargetDatabaseName sysname = NULL
    , @ExpectedTargetCreateDate datetime = NULL
    , @JoinFrameworkTransaction bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    SELECT @StatusCodeOut='AVAILABLE',@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    SET @CollectorCode=UPPER(LTRIM(RTRIM(COALESCE(@CollectorCode,''))));
    IF @UpdateSharedPolicy IS NULL
        SET @UpdateSharedPolicy=CASE WHEN @CollectorCode='PERFORMANCE_COUNTERS' THEN 1 ELSE 0 END;
    DECLARE @UseV2Contract bit=CASE WHEN @CollectorCode<>'PERFORMANCE_COUNTERS'
             OR @CollectorEnabled<>1 OR @CollectorEnabled IS NULL OR @UpdateSharedPolicy<>1
             OR @ExpectedTargetDatabaseId IS NOT NULL OR @ExpectedTargetDatabaseName IS NOT NULL
             OR @ExpectedTargetCreateDate IS NOT NULL OR @JoinFrameworkTransaction<>0 THEN 1 ELSE 0 END,
            @OwnTransaction bit=0,@SavepointCreated bit=0;

    IF @JoinFrameworkTransaction IS NULL OR
       (@JoinFrameworkTransaction=1 AND
         (@CollectorCode NOT IN('WAIT_STATS','FILE_IO') OR @UpdateSharedPolicy<>1 OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR (@@OPTIONS & 2)<>0))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Die ausdrückliche Transaktionsbeteiligung benötigt WAIT_STATS oder FILE_IO mit Shared1 und eine committable Besitzertransaktion.';
        RETURN 51011;
    END;

    IF @UseV2Contract=1 AND ((@@OPTIONS & 2)<>0 OR (@CollectorCode IN('WAIT_STATS','FILE_IO') AND @@TRANCOUNT<>0 AND @JoinFrameworkTransaction=0))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der Collectorvertrag benötigt IMPLICIT_TRANSACTIONS OFF und außerhalb der Besitzerbeteiligung keine Callertransaktion.';
        RETURN 51011;
    END;

    IF @CollectorCode NOT IN ('PERFORMANCE_COUNTERS','WAIT_STATS','FILE_IO') OR @CollectorEnabled IS NULL
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Ungültiger Collector oder Aktivierungswert.';
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
            SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53764,
                   @ErrorMessageOut=N'Die erwartete Snapshot-Zielidentität stimmt nicht mehr überein.';
            RETURN;
        END;
    END;

    IF @UseV2Contract=1
    BEGIN
        IF @CollectionIntervalSeconds IS NULL OR @MaxRows IS NULL OR @PayloadEnabled IS NULL
           OR (@UpdateSharedPolicy=1 AND (@RawRetentionDays IS NULL OR @PayloadRetentionDays IS NULL
               OR @RollupRetentionDays IS NULL OR @SoftBudgetMB IS NULL OR @PurgeIntervalMinutes IS NULL
               OR @PurgeBatchRows IS NULL OR @BudgetAction IS NULL))
        BEGIN
            SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
                   @ErrorMessageOut=N'Eine wirksame Policyeigenschaft darf nicht NULL sein.';
            RETURN 51011;
        END;
        IF (SELECT COUNT_BIG(*) FROM [snapshot].[PackageVersion])<>1 OR NOT EXISTS
           (SELECT 1 FROM [snapshot].[PackageVersion] WHERE CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')
            AND ((CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') AND [SchemaVersion]=2) OR (CONVERT(varbinary(max),[PackageVersion]) IN(CONVERT(varbinary(max),'1.3.0'),CONVERT(varbinary(max),'1.3.1')) AND [SchemaVersion]=3)))
           OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS [wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH (NOLOCK) ON [ws].[schema_id]=[wp].[schema_id] WHERE CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') AND CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))
           OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS [p] WITH (NOLOCK)
                         WHERE [p].[object_id] IN(SELECT [hp].[object_id] FROM [sys].[procedures] AS [hp] WITH (NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON [hs].[schema_id]=[hp].[schema_id] WHERE CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') AND CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))
                           AND CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),N'@ContractOnly'))
        BEGIN
            SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53761,
                   @ErrorMessageOut=N'Das vollständig installierte kompatible Collector-Target fehlt.';
            RETURN;
        END;
    END;

    IF @CollectorCode='FILE_IO' AND NOT EXISTS(SELECT 1 FROM [snapshot].[PackageVersion] WHERE CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.1') AND [SchemaVersion]=3)
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53781,@ErrorMessageOut=N'Das vollständige Datei-I/O-Target 1.3.1 mit Schema 3 fehlt.';
        RETURN;
    END;

    IF @CollectionIntervalSeconds NOT BETWEEN 1 AND 3600
       OR @MaxRows NOT BETWEEN 1 AND 100000
       OR (@UpdateSharedPolicy=1 AND
          (@RawRetentionDays NOT BETWEEN 1 AND 3650
       OR @PayloadRetentionDays NOT BETWEEN 1 AND 3650
       OR @RollupRetentionDays NOT BETWEEN 1 AND 3650
       OR @SoftBudgetMB<1
       OR @PurgeIntervalMinutes NOT BETWEEN 1 AND 1440
       OR @PurgeBatchRows NOT BETWEEN 1 AND 100000
       OR @BudgetAction<>'PURGE_EXPIRED_THEN_STOP'))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',
               @ErrorMessageOut=N'Ungültige Snapshot-, Retention- oder Budgetpolicy.';
        RETURN;
    END;

    BEGIN TRY
        IF @UseV2Contract=0
            BEGIN TRANSACTION;
        ELSE IF @@TRANCOUNT=0
        BEGIN
            BEGIN TRANSACTION;
            SET @OwnTransaction=1;
        END
        ELSE IF @JoinFrameworkTransaction=0
        BEGIN
            SAVE TRANSACTION SQLSA_SnapshotPolicy;
            SET @SavepointCreated=1;
        END;

        IF @UpdateSharedPolicy=1
        UPDATE [snapshot].[RetentionPolicy]
        SET [RawRetentionDays]=@RawRetentionDays,
            [PayloadRetentionDays]=@PayloadRetentionDays,
            [RollupRetentionDays]=@RollupRetentionDays,
            [SoftBudgetMB]=@SoftBudgetMB,
            [PurgeIntervalMinutes]=@PurgeIntervalMinutes,
            [PurgeBatchRows]=@PurgeBatchRows,
            [BudgetAction]=@BudgetAction,
            [LastUpdatedUtc]=SYSUTCDATETIME()
        WHERE [RetentionPolicyCode]='DEFAULT';

        UPDATE [snapshot].[CollectorPolicy]
        SET [IsEnabled]=@CollectorEnabled,
            [CollectionIntervalSeconds]=@CollectionIntervalSeconds,
            [MaxRows]=@MaxRows,
            [PayloadEnabled]=@PayloadEnabled,
            [RetentionPolicyCode]=CASE WHEN @UpdateSharedPolicy=1 THEN 'DEFAULT' ELSE [RetentionPolicyCode] END,
            [LastUpdatedUtc]=SYSUTCDATETIME()
        WHERE [CollectorCode]=@CollectorCode;

        IF @@ROWCOUNT<>1
        BEGIN
            IF @CollectorCode='PERFORMANCE_COUNTERS'
                THROW 53700,N'Die Performance-Counter-Policy fehlt.',1;
            THROW 53700,N'Die Wait-Policy fehlt.',1;
        END;

        IF @UseV2Contract=0 OR @OwnTransaction=1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (@UseV2Contract=0 OR @OwnTransaction=1) AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        ELSE IF @SavepointCreated=1 AND XACT_STATE()=1
            ROLLBACK TRANSACTION SQLSA_SnapshotPolicy;
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @ErrorNumberOut=ERROR_NUMBER(),
               @ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;
END;
GO

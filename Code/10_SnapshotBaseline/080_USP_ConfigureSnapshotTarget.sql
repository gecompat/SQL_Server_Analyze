USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ConfigureSnapshotTarget
Version      : 1.2.0
Stand        : 2026-10-26
Zweck        : Aktiviert ein explizit installiertes SC-023-Ziel und schreibt
               alle bekannten Collector-/Retentionwerte typisiert.
Nebenwirkung : Persistente Konfiguration in Framework- und Snapshot-Datenbank.
Rechte       : Vergibt keine Rechte; DDL-/DML- und EXECUTE-Rechte sind extern.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ConfigureSnapshotTarget]
      @TargetDatabaseName       sysname
    , @IsEnabled                bit          = 1
    , @SchedulerType            varchar(16)  = 'EXTERNAL'
    , @CollectionIntervalSeconds smallint     = 30
    , @MaxRows                  int           = 1000
    , @PayloadEnabled           bit           = 0
    , @RawRetentionDays         smallint      = 14
    , @PayloadRetentionDays     smallint      = 7
    , @RollupRetentionDays      smallint      = 180
    , @SoftBudgetMB             int           = 10240
    , @PurgeIntervalMinutes     smallint      = 60
    , @PurgeBatchRows           int           = 10000
    , @BudgetAction             varchar(32)   = 'PURGE_EXPIRED_THEN_STOP'
    , @PrintMeldungen           bit           = 1
    , @Hilfe                    bit           = 0
    , @StatusCodeOut            varchar(40)   = NULL OUTPUT
    , @IsPartialOut             bit           = NULL OUTPUT
    , @ErrorNumberOut           int           = NULL OUTPUT
    , @ErrorMessageOut          nvarchar(2048)= NULL OUTPUT
    , @CollectorCode            varchar(64) = 'PERFORMANCE_COUNTERS'
    , @CollectorEnabled         bit = 1
    , @UpdateSharedPolicy       bit = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    SET @CollectorCode=UPPER(LTRIM(RTRIM(COALESCE(@CollectorCode,''))));
    IF @UpdateSharedPolicy IS NULL SET @UpdateSharedPolicy=CASE WHEN @CollectorCode='PERFORMANCE_COUNTERS' THEN 1 ELSE 0 END;
    DECLARE @NewPolicyContract bit=CASE WHEN @CollectorCode<>'PERFORMANCE_COUNTERS' OR @CollectorEnabled<>1
       OR @CollectorEnabled IS NULL OR @UpdateSharedPolicy<>1 THEN 1 ELSE 0 END;
    IF @Hilfe=1 AND (@NewPolicyContract=1 OR @CollectorCode NOT IN('PERFORMANCE_COUNTERS','WAIT_STATS','FILE_IO'))
    BEGIN
        PRINT N'monitor.USP_ConfigureSnapshotTarget';
        PRINT N'@TargetDatabaseName sysname. Kein Default; Pflichtargument. Pflichtargument ohne Default, auch bei Hilfe: ein einzelner Datenbankname als sysname mit höchstens 128 Zeichen, ohne Server-/Schemaqualifier oder Liste. Der übergebene Name wird als Datenwert mit QUOTENAME verwendet; Bezeichnerklammern sind keine automatisch entfernte Eingabemaskierung. Normalaufrufe benötigen einen nicht-NULL, nicht nur aus Leerzeichen bestehenden Namen eines separat installierten, erreichbaren, online befindlichen und schreibbaren SC-023-Ziels. Bei neuen Collectoroptionen werden Systemdatenbanken, Frameworkselbstziel und eine nicht passende Zielidentität abgewiesen; Datenbank-ID und Erstellungszeitpunkt werden vor dem Write gebunden. Es wird keine Datenbank angelegt.';
        PRINT N'@IsEnabled bit. Default ist 1. bit-Schalter für die gemeinsame Framework-Zielkonfiguration: 0 deaktiviert sie, 1 aktiviert sie. NULL ist in der gemeinsamen Aktualisierung ungültig. Bei @UpdateSharedPolicy=0 bleibt dieser gemeinsam gespeicherte Wert unberührt und wird nicht wirksam verwendet; bei Collector-only-Konfiguration gilt die bestehende Bindung. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.';
        PRINT N'@SchedulerType varchar(16). Default ist ''EXTERNAL''. Ein Code: MANUAL kennzeichnet manuellen Aufruf, EXTERNAL einen externen Scheduler und SQL_AGENT einen SQL-Server-Agent-Aufruf. Äußere Leerzeichen werden entfernt und Großschreibung normalisiert. NULL wird zu leer normalisiert; bei gemeinsamer Aktualisierung sind leere oder unbekannte Codes ungültig. Bei UpdateSharedPolicy=0 wird der Wert nicht geprüft oder geschrieben. Es werden weder Schedulerobjekte noch Agent-Jobs erzeugt oder gestartet.';
        PRINT N'@CollectionIntervalSeconds smallint. Default ist 30. Ganzzahlige Sekunden von 1 bis 3600 für die ausgewählte Collectorpolicy. Der Wert wird auch bei UpdateSharedPolicy=0 geschrieben; er ist keine gemeinsame Retentionseinstellung. Er speichert den Mindestabstand für spätere Zyklen, startet aber keinen Collector und wartet nicht. NULL ist im neuen Policyvertrag explizit ungültig; der Legacy-Pfad prüft NULL nicht vollständig vor dem Zielwrite. 0 ist nicht unbegrenzt.';
        PRINT N'@MaxRows int. Default ist 1000. int, positive ganze Zeilenzahl von 1 bis 100000 je Collection-Grenze. NULL ist im neuen Policyvertrag ungültig, Werte außerhalb des Bereichs ungültig. Gilt für die ausgewählte Collectorpolicy. Bei shared=0 wird diese Collectorgrenze aktualisiert; der Parameter ist wirksam.';
        PRINT N'@PayloadEnabled bit. Default ist 0. 0 speichert keine Payloadfreigabe, 1 erlaubt optionale Payloads nach dem Collectorvertrag. Es wird ausschließlich PayloadEnabled der ausgewählten Collectorpolicy geschrieben, auch bei UpdateSharedPolicy=0; dieser Konfigurationsaufruf erfasst keine Payloaddaten. NULL ist im neuen Policyvertrag explizit ungültig und kann im Legacy-Pfad erst am Zielwrite scheitern. T-SQL konvertiert numerische Nichtnullwerte zuvor zu bit 1; verwenden Sie 0 oder 1.';
        PRINT N'@RawRetentionDays smallint. Default ist 14. smallint in Tagen, im Bereich 1 bis 3650. NULL und Bereichsverletzung sind ungültig, wenn @UpdateSharedPolicy=1; andernfalls bleibt die gemeinsame Retention erhalten und der übergebene Wert wird ignoriert. Bestimmt die Aufbewahrungsdauer der Rohdaten. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.';
        PRINT N'@PayloadRetentionDays smallint. Default ist 7. smallint in Tagen, 1 bis 3650. Bei shared=1 darf der Wert nicht NULL und nicht außerhalb des Bereichs sein; bei shared=0 wird er ignoriert. Bestimmt die Payload-Aufbewahrung. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.';
        PRINT N'@RollupRetentionDays smallint. Default ist 180. smallint in Tagen, 1 bis 3650. Bei shared=1 erforderlich und im Bereich; bei shared=0 wirkungslos und die vorhandene gemeinsame Rollup-Retention bleibt bestehen. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.';
        PRINT N'@SoftBudgetMB int. Default ist 10240. int in MiB, von 1 bis 2147483647. Bei shared=1 darf der Wert nicht NULL oder kleiner 1 sein. Bei shared=0 wird das gemeinsame Budget nicht geändert und der Wert ignoriert. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.';
        PRINT N'@PurgeIntervalMinutes smallint. Default ist 60. smallint in Minuten, 1 bis 1440. Bei shared=1 erforderlich und bereichsgeprüft; bei shared=0 bleibt der gemeinsame Purge-Takt unverändert und der Wert wird ignoriert. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.';
        PRINT N'@PurgeBatchRows int. Default ist 10000. int, Zeilen je Purge-Batch, 1 bis 100000. Bei shared=1 erforderlich und bereichsgeprüft; bei shared=0 wird die gemeinsame Purge-Batchgrenze nicht geändert. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.';
        PRINT N'@BudgetAction varchar(32). Default ist ''PURGE_EXPIRED_THEN_STOP''. varchar(32), nach Trimmen und Großschreibung ausschließlich PURGE_EXPIRED_THEN_STOP. Der Wert bezeichnet das Löschen abgelaufener Daten vor dem Anhalten bei weiterhin überschrittenem Softbudget. NULL oder ein anderer Text ist bei shared=1 ungültig; bei shared=0 ignoriert, da die gemeinsame Budgetpolicy unverändert bleibt. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default. Dieser Aufruf speichert nur den Aktionscode und führt keinen Purge aus.';
        PRINT N'@PrintMeldungen bit. Default ist 1. bit-Ausgabeschalter: 0 unterdrückt die abschließende Severity-10-Statusmeldung bei Fehlern; 1 gibt sie mit RAISERROR ... WITH NOWAIT aus. NULL verhält sich nicht wie 1 und unterdrückt die Bedingung (SQL NULL-Vergleich); beeinflusst weder Status-OUTPUT noch Persistenz. Hilfe-PRINTs werden hiervon nicht gesteuert. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.';
        PRINT N'@Hilfe bit. Default ist 0. 1 druckt die Hilfe und kehrt vor Zielprüfung und persistenten Konfigurationswrites zurück; 0 oder NULL folgt dem normalen Pfad. TargetDatabaseName bleibt als Pflichtargument erforderlich. Der frühe Hilfezweig für neue oder ungültige Collectoroptionen liegt vor der Collector-/Transaktionsvalidierung und vor SET XACT_ABORT/LOCK_TIMEOUT. Der Legacy-Hilfezweig liegt nach SET XACT_ABORT ON und LOCK_TIMEOUT 0. NOCOUNT und die initialisierten Status-OUTPUTs werden bereits zuvor gesetzt. Ein Hilfeaufruf belegt deshalb keine zulässige normale Konfiguration. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT. Default ist NULL. varchar(40) OUTPUT; als Variable binden und nach dem EXEC auslesen. Liefert den Status dieses Aufrufs, anfänglich AVAILABLE, bei Fehlerpfaden unter anderem INVALID_PARAMETER, TARGET_UNAVAILABLE oder DENIED_PERMISSION. Im Hilfezweig bleibt der initialisierte Wert AVAILABLE. Kein Resultset. Der Anfangswert wird überschrieben; für Rückgabe die Variable mit OUTPUT übergeben. Ohne Bindung wird kein Wert beim Aufrufer empfangen.';
        PRINT N'@IsPartialOut bit OUTPUT. Default ist NULL. bit OUTPUT; als Variable binden. 0 bedeutet kein als partiell markierter Fehler, 1 kennzeichnet einen Fehler-/Teilstatus. Wird beim Eintritt auf 0 gesetzt und in den Fehlerpfaden typischerweise auf 1; im Hilfezweig bleibt es 0. Kein separates Resultset. Der Anfangswert wird überschrieben; für Rückgabe die Variable mit OUTPUT übergeben. Ohne Bindung wird kein Wert beim Aufrufer empfangen.';
        PRINT N'@ErrorNumberOut int OUTPUT. Default ist NULL. int OUTPUT; als Variable binden. NULL bedeutet, dass beim initialisierten Status keine Fehlernummer gesetzt ist; Fehlerpfade liefern die ermittelte SQL- oder Vertragsfehlernummer, soweit vorhanden. Wird beim Eintritt auf NULL gesetzt und bei Hilfe nicht geändert. Der Anfangswert wird überschrieben; für Rückgabe die Variable mit OUTPUT übergeben. Ohne Bindung wird kein Wert beim Aufrufer empfangen.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT. Default ist NULL. Optionaler nvarchar(2048)-OUTPUT-Empfang für Unicode-Fehlertext mit höchstens 2048 UTF-16-Codeeinheiten. Der Anfangswert wird auf NULL gesetzt. Ohne Fehler kann NULL zurückkommen; eine Meldung allein ersetzt nicht die Statusprüfung. Aufruf als Variable mit OUTPUT, sonst wird beim Aufrufer kein Wert empfangen.';
        PRINT N'@CollectorCode varchar(64). Default ist ''PERFORMANCE_COUNTERS''. Nach Trim und Großschreibung sind genau PERFORMANCE_COUNTERS (Performance-Counter-Policy), WAIT_STATS (Wait-Statistik-Policy) und FILE_IO (Datei-I/O-Policy) zulässig. NULL wird zu leer und ist bei normalem Aufruf ungültig. Für WAIT_STATS erkennt die Admission die Version/Schema-Paare 1.2.1/2, 1.3.0/3 und 1.3.1/3 und fordert dazu Retentionsvertrag 1, 2 beziehungsweise 3 sowie passende Signaturen. Das Versionsetikett allein reicht nicht: der aktuelle Purge-Helfer liefert bei 1.3.0/3 Vertrag 3 statt 2; diese Kombination wird abgewiesen. Eine funktionsfähige historische 1.3.0-Closure wird hier nicht qualifiziert. FILE_IO verlangt 1.3.1/3 mit Retentionsvertrag 3. PERFORMANCE_COUNTERS mit CollectorEnabled=1 und wirksamem UpdateSharedPolicy=1 nimmt den Legacy-Pfad; andere Performance-Counter-Kombinationen benötigen ebenfalls die neue Admission. Die Auswahl startet keine Sammlung.';
        PRINT N'@CollectorEnabled bit. Default ist 1. bit-Schalter: 0 deaktiviert, 1 aktiviert ausschließlich den ausgewählten Collector. NULL ist ungültig. Kombinationen mit CollectorCode und UpdateSharedPolicy bestimmen den neuen Policyvertrag; ein deaktivierter Collector erzwingt diesen Vertrag. Der Wert aktiviert weder Datenbank noch Job. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.';
        PRINT N'@UpdateSharedPolicy bit. Default ist NULL. 0 erhält Framework-Singleton und gemeinsame Retention/Budget/Purgewerte sowie die bisherige Retentionszuordnung. CollectorEnabled, CollectionIntervalSeconds, MaxRows und PayloadEnabled der gewählten Policy werden trotzdem geschrieben. IsEnabled, SchedulerType und gemeinsame Retentions-/Budget-/Purgeargumente werden bei 0 ignoriert. 1 ändert gemeinsame Werte und gewählte Policy atomar. NULL löst vor der Hilfe zu 1 für PERFORMANCE_COUNTERS, sonst zu 0 für WAIT_STATS oder FILE_IO auf. Neue Varianten mit 0 benötigen eine bereits passende Framework-Zielbindung. Der normale neue Vertrag weist Callertransaktionen und IMPLICIT_TRANSACTIONS ON zurück; der Legacy-Pfad hat keine entsprechende Vorabablehnung und sollte ebenfalls außerhalb eigener Transaktionen aufgerufen werden. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.';
        PRINT N'Beispiel 1. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''ExampleSnapshotDatabase'', @Hilfe=1, @CollectorCode=''PERFORMANCE_COUNTERS'', @CollectorEnabled=1, @UpdateSharedPolicy=1;';
        PRINT N'Beispiel 2. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''ExampleSnapshotDatabase'', @Hilfe=1, @CollectorCode=''WAIT_STATS'', @CollectorEnabled=1, @UpdateSharedPolicy=0;';
        PRINT N'Beispiel 3. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''ExampleSnapshotDatabase'', @Hilfe=1, @CollectorCode=''WAIT_STATS'', @CollectorEnabled=0, @UpdateSharedPolicy=1;';
        PRINT N'Beispiel 4. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''ExampleSnapshotDatabase'', @Hilfe=1, @CollectorCode=''FILE_IO'', @CollectorEnabled=1, @UpdateSharedPolicy=1;';
        RETURN;
    END;
    IF @CollectorCode NOT IN('PERFORMANCE_COUNTERS','WAIT_STATS','FILE_IO') OR @CollectorEnabled IS NULL
       OR (@NewPolicyContract=1 AND (@@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Neue Collectoroptionen benötigen einen gültigen Collector ohne Callertransaktion oder implizite Transaktionen.';
        RETURN 51011;
    END;
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET LOCK_TIMEOUT 0;

    SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ConfigureSnapshotTarget';
        PRINT N'@TargetDatabaseName sysname. Kein Default; Pflichtargument. Pflichtargument ohne Default, auch bei Hilfe: ein einzelner Datenbankname als sysname mit höchstens 128 Zeichen, ohne Server-/Schemaqualifier oder Liste. Der übergebene Name wird als Datenwert mit QUOTENAME verwendet; Bezeichnerklammern sind keine automatisch entfernte Eingabemaskierung. Normalaufrufe benötigen einen nicht-NULL, nicht nur aus Leerzeichen bestehenden Namen eines separat installierten, erreichbaren, online befindlichen und schreibbaren SC-023-Ziels. Bei neuen Collectoroptionen werden Systemdatenbanken, Frameworkselbstziel und eine nicht passende Zielidentität abgewiesen; Datenbank-ID und Erstellungszeitpunkt werden vor dem Write gebunden. Es wird keine Datenbank angelegt.';
        PRINT N'@IsEnabled bit. Default ist 1. bit-Schalter für die gemeinsame Framework-Zielkonfiguration: 0 deaktiviert sie, 1 aktiviert sie. NULL ist in der gemeinsamen Aktualisierung ungültig. Bei @UpdateSharedPolicy=0 bleibt dieser gemeinsam gespeicherte Wert unberührt und wird nicht wirksam verwendet; bei Collector-only-Konfiguration gilt die bestehende Bindung. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.';
        PRINT N'@SchedulerType varchar(16). Default ist ''EXTERNAL''. Ein Code: MANUAL kennzeichnet manuellen Aufruf, EXTERNAL einen externen Scheduler und SQL_AGENT einen SQL-Server-Agent-Aufruf. Äußere Leerzeichen werden entfernt und Großschreibung normalisiert. NULL wird zu leer normalisiert; bei gemeinsamer Aktualisierung sind leere oder unbekannte Codes ungültig. Bei UpdateSharedPolicy=0 wird der Wert nicht geprüft oder geschrieben. Es werden weder Schedulerobjekte noch Agent-Jobs erzeugt oder gestartet.';
        PRINT N'@CollectionIntervalSeconds smallint. Default ist 30. Ganzzahlige Sekunden von 1 bis 3600 für die ausgewählte Collectorpolicy. Der Wert wird auch bei UpdateSharedPolicy=0 geschrieben; er ist keine gemeinsame Retentionseinstellung. Er speichert den Mindestabstand für spätere Zyklen, startet aber keinen Collector und wartet nicht. NULL ist im neuen Policyvertrag explizit ungültig; der Legacy-Pfad prüft NULL nicht vollständig vor dem Zielwrite. 0 ist nicht unbegrenzt.';
        PRINT N'@MaxRows int. Default ist 1000. int, positive ganze Zeilenzahl von 1 bis 100000 je Collection-Grenze. NULL ist im neuen Policyvertrag ungültig, Werte außerhalb des Bereichs ungültig. Gilt für die ausgewählte Collectorpolicy. Bei shared=0 wird diese Collectorgrenze aktualisiert; der Parameter ist wirksam.';
        PRINT N'@PayloadEnabled bit. Default ist 0. 0 speichert keine Payloadfreigabe, 1 erlaubt optionale Payloads nach dem Collectorvertrag. Es wird ausschließlich PayloadEnabled der ausgewählten Collectorpolicy geschrieben, auch bei UpdateSharedPolicy=0; dieser Konfigurationsaufruf erfasst keine Payloaddaten. NULL ist im neuen Policyvertrag explizit ungültig und kann im Legacy-Pfad erst am Zielwrite scheitern. T-SQL konvertiert numerische Nichtnullwerte zuvor zu bit 1; verwenden Sie 0 oder 1.';
        PRINT N'@RawRetentionDays smallint. Default ist 14. smallint in Tagen, im Bereich 1 bis 3650. NULL und Bereichsverletzung sind ungültig, wenn @UpdateSharedPolicy=1; andernfalls bleibt die gemeinsame Retention erhalten und der übergebene Wert wird ignoriert. Bestimmt die Aufbewahrungsdauer der Rohdaten. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.';
        PRINT N'@PayloadRetentionDays smallint. Default ist 7. smallint in Tagen, 1 bis 3650. Bei shared=1 darf der Wert nicht NULL und nicht außerhalb des Bereichs sein; bei shared=0 wird er ignoriert. Bestimmt die Payload-Aufbewahrung. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.';
        PRINT N'@RollupRetentionDays smallint. Default ist 180. smallint in Tagen, 1 bis 3650. Bei shared=1 erforderlich und im Bereich; bei shared=0 wirkungslos und die vorhandene gemeinsame Rollup-Retention bleibt bestehen. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.';
        PRINT N'@SoftBudgetMB int. Default ist 10240. int in MiB, von 1 bis 2147483647. Bei shared=1 darf der Wert nicht NULL oder kleiner 1 sein. Bei shared=0 wird das gemeinsame Budget nicht geändert und der Wert ignoriert. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.';
        PRINT N'@PurgeIntervalMinutes smallint. Default ist 60. smallint in Minuten, 1 bis 1440. Bei shared=1 erforderlich und bereichsgeprüft; bei shared=0 bleibt der gemeinsame Purge-Takt unverändert und der Wert wird ignoriert. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.';
        PRINT N'@PurgeBatchRows int. Default ist 10000. int, Zeilen je Purge-Batch, 1 bis 100000. Bei shared=1 erforderlich und bereichsgeprüft; bei shared=0 wird die gemeinsame Purge-Batchgrenze nicht geändert. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.';
        PRINT N'@BudgetAction varchar(32). Default ist ''PURGE_EXPIRED_THEN_STOP''. varchar(32), nach Trimmen und Großschreibung ausschließlich PURGE_EXPIRED_THEN_STOP. Der Wert bezeichnet das Löschen abgelaufener Daten vor dem Anhalten bei weiterhin überschrittenem Softbudget. NULL oder ein anderer Text ist bei shared=1 ungültig; bei shared=0 ignoriert, da die gemeinsame Budgetpolicy unverändert bleibt. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default. Dieser Aufruf speichert nur den Aktionscode und führt keinen Purge aus.';
        PRINT N'@PrintMeldungen bit. Default ist 1. bit-Ausgabeschalter: 0 unterdrückt die abschließende Severity-10-Statusmeldung bei Fehlern; 1 gibt sie mit RAISERROR ... WITH NOWAIT aus. NULL verhält sich nicht wie 1 und unterdrückt die Bedingung (SQL NULL-Vergleich); beeinflusst weder Status-OUTPUT noch Persistenz. Hilfe-PRINTs werden hiervon nicht gesteuert. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.';
        PRINT N'@Hilfe bit. Default ist 0. 1 druckt die Hilfe und kehrt vor Zielprüfung und persistenten Konfigurationswrites zurück; 0 oder NULL folgt dem normalen Pfad. TargetDatabaseName bleibt als Pflichtargument erforderlich. Der frühe Hilfezweig für neue oder ungültige Collectoroptionen liegt vor der Collector-/Transaktionsvalidierung und vor SET XACT_ABORT/LOCK_TIMEOUT. Der Legacy-Hilfezweig liegt nach SET XACT_ABORT ON und LOCK_TIMEOUT 0. NOCOUNT und die initialisierten Status-OUTPUTs werden bereits zuvor gesetzt. Ein Hilfeaufruf belegt deshalb keine zulässige normale Konfiguration. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT. Default ist NULL. varchar(40) OUTPUT; als Variable binden und nach dem EXEC auslesen. Liefert den Status dieses Aufrufs, anfänglich AVAILABLE, bei Fehlerpfaden unter anderem INVALID_PARAMETER, TARGET_UNAVAILABLE oder DENIED_PERMISSION. Im Hilfezweig bleibt der initialisierte Wert AVAILABLE. Kein Resultset. Der Anfangswert wird überschrieben; für Rückgabe die Variable mit OUTPUT übergeben. Ohne Bindung wird kein Wert beim Aufrufer empfangen.';
        PRINT N'@IsPartialOut bit OUTPUT. Default ist NULL. bit OUTPUT; als Variable binden. 0 bedeutet kein als partiell markierter Fehler, 1 kennzeichnet einen Fehler-/Teilstatus. Wird beim Eintritt auf 0 gesetzt und in den Fehlerpfaden typischerweise auf 1; im Hilfezweig bleibt es 0. Kein separates Resultset. Der Anfangswert wird überschrieben; für Rückgabe die Variable mit OUTPUT übergeben. Ohne Bindung wird kein Wert beim Aufrufer empfangen.';
        PRINT N'@ErrorNumberOut int OUTPUT. Default ist NULL. int OUTPUT; als Variable binden. NULL bedeutet, dass beim initialisierten Status keine Fehlernummer gesetzt ist; Fehlerpfade liefern die ermittelte SQL- oder Vertragsfehlernummer, soweit vorhanden. Wird beim Eintritt auf NULL gesetzt und bei Hilfe nicht geändert. Der Anfangswert wird überschrieben; für Rückgabe die Variable mit OUTPUT übergeben. Ohne Bindung wird kein Wert beim Aufrufer empfangen.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT. Default ist NULL. Optionaler nvarchar(2048)-OUTPUT-Empfang für Unicode-Fehlertext mit höchstens 2048 UTF-16-Codeeinheiten. Der Anfangswert wird auf NULL gesetzt. Ohne Fehler kann NULL zurückkommen; eine Meldung allein ersetzt nicht die Statusprüfung. Aufruf als Variable mit OUTPUT, sonst wird beim Aufrufer kein Wert empfangen.';
        PRINT N'@CollectorCode varchar(64). Default ist ''PERFORMANCE_COUNTERS''. Nach Trim und Großschreibung sind genau PERFORMANCE_COUNTERS (Performance-Counter-Policy), WAIT_STATS (Wait-Statistik-Policy) und FILE_IO (Datei-I/O-Policy) zulässig. NULL wird zu leer und ist bei normalem Aufruf ungültig. Für WAIT_STATS erkennt die Admission die Version/Schema-Paare 1.2.1/2, 1.3.0/3 und 1.3.1/3 und fordert dazu Retentionsvertrag 1, 2 beziehungsweise 3 sowie passende Signaturen. Das Versionsetikett allein reicht nicht: der aktuelle Purge-Helfer liefert bei 1.3.0/3 Vertrag 3 statt 2; diese Kombination wird abgewiesen. Eine funktionsfähige historische 1.3.0-Closure wird hier nicht qualifiziert. FILE_IO verlangt 1.3.1/3 mit Retentionsvertrag 3. PERFORMANCE_COUNTERS mit CollectorEnabled=1 und wirksamem UpdateSharedPolicy=1 nimmt den Legacy-Pfad; andere Performance-Counter-Kombinationen benötigen ebenfalls die neue Admission. Die Auswahl startet keine Sammlung.';
        PRINT N'@CollectorEnabled bit. Default ist 1. bit-Schalter: 0 deaktiviert, 1 aktiviert ausschließlich den ausgewählten Collector. NULL ist ungültig. Kombinationen mit CollectorCode und UpdateSharedPolicy bestimmen den neuen Policyvertrag; ein deaktivierter Collector erzwingt diesen Vertrag. Der Wert aktiviert weder Datenbank noch Job. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.';
        PRINT N'@UpdateSharedPolicy bit. Default ist NULL. 0 erhält Framework-Singleton und gemeinsame Retention/Budget/Purgewerte sowie die bisherige Retentionszuordnung. CollectorEnabled, CollectionIntervalSeconds, MaxRows und PayloadEnabled der gewählten Policy werden trotzdem geschrieben. IsEnabled, SchedulerType und gemeinsame Retentions-/Budget-/Purgeargumente werden bei 0 ignoriert. 1 ändert gemeinsame Werte und gewählte Policy atomar. NULL löst vor der Hilfe zu 1 für PERFORMANCE_COUNTERS, sonst zu 0 für WAIT_STATS oder FILE_IO auf. Neue Varianten mit 0 benötigen eine bereits passende Framework-Zielbindung. Der normale neue Vertrag weist Callertransaktionen und IMPLICIT_TRANSACTIONS ON zurück; der Legacy-Pfad hat keine entsprechende Vorabablehnung und sollte ebenfalls außerhalb eigener Transaktionen aufgerufen werden. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.';
        PRINT N'Beispiel 1. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''ExampleSnapshotDatabase'', @Hilfe=1, @CollectorCode=''PERFORMANCE_COUNTERS'', @CollectorEnabled=1, @UpdateSharedPolicy=1;';
        PRINT N'Beispiel 2. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''ExampleSnapshotDatabase'', @Hilfe=1, @CollectorCode=''WAIT_STATS'', @CollectorEnabled=1, @UpdateSharedPolicy=0;';
        PRINT N'Beispiel 3. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''ExampleSnapshotDatabase'', @Hilfe=1, @CollectorCode=''WAIT_STATS'', @CollectorEnabled=0, @UpdateSharedPolicy=1;';
        PRINT N'Beispiel 4. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''ExampleSnapshotDatabase'', @Hilfe=1, @CollectorCode=''FILE_IO'', @CollectorEnabled=1, @UpdateSharedPolicy=1;';
        RETURN;
    END;

    SET @SchedulerType=UPPER(LTRIM(RTRIM(COALESCE(@SchedulerType,''))));
    SET @BudgetAction=UPPER(LTRIM(RTRIM(COALESCE(@BudgetAction,''))));

    IF @NewPolicyContract=1
    BEGIN
        DECLARE @NewTargetId int,@NewTargetCreated datetime,@NewTargetStatus varchar(40),@NewTargetError int,
                @NewTargetMessage nvarchar(2048),@NewSql nvarchar(max),@NewJoin bit,
                @NewPrint nvarchar(2048),@AdmissionCollector varchar(64)=CASE WHEN @CollectorCode='FILE_IO' THEN 'FILE_IO' ELSE 'WAIT_STATS' END;
        BEGIN TRY
            IF NULLIF(LTRIM(RTRIM(@TargetDatabaseName)),N'') IS NULL
               OR (@UpdateSharedPolicy=1 AND (@IsEnabled IS NULL OR @SchedulerType NOT IN('MANUAL','EXTERNAL','SQL_AGENT')))
            BEGIN
                SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
                       @ErrorMessageOut=N'Ungültige wirksame Ziel-, Aktivierungs- oder Scheduleroption.';
                RETURN 51011;
            END;
            IF @UpdateSharedPolicy=0 AND NOT EXISTS
               (SELECT 1 FROM [monitor].[SnapshotTargetConfiguration]
                WHERE [ConfigurationId]=1 AND CONVERT(varbinary(max),[TargetDatabaseName])=CONVERT(varbinary(max),@TargetDatabaseName))
            BEGIN
                SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,@ErrorNumberOut=53764,
                       @ErrorMessageOut=N'Collector-only-Konfiguration benötigt die passende bestehende Framework-Zielbindung.';
                RETURN;
            END;
            EXEC [monitor].[InternalValidateSnapshotWaitTarget]
                 @TargetDatabaseName=@TargetDatabaseName,@TargetDatabaseIdOut=@NewTargetId OUTPUT,
                 @TargetCreateDateOut=@NewTargetCreated OUTPUT,@StatusCodeOut=@NewTargetStatus OUTPUT,
                 @ErrorNumberOut=@NewTargetError OUTPUT,@ErrorMessageOut=@NewTargetMessage OUTPUT,@CollectorCode=@AdmissionCollector;
            IF COALESCE(@NewTargetStatus,'')<>'AVAILABLE' OR @NewTargetError IS NOT NULL
            BEGIN
                SELECT @StatusCodeOut=COALESCE(NULLIF(@NewTargetStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                       @ErrorNumberOut=@NewTargetError,@ErrorMessageOut=@NewTargetMessage;
                RETURN;
            END;
            IF @UpdateSharedPolicy=1 BEGIN TRANSACTION;
            SET @NewJoin=CASE WHEN @CollectorCode IN('WAIT_STATS','FILE_IO') AND @UpdateSharedPolicy=1 THEN 1 ELSE 0 END;
            SET @NewSql=N'EXEC '+QUOTENAME(@TargetDatabaseName)+N'.[snapshot].[InternalConfigureSnapshotPolicy]
 @CollectionIntervalSeconds=@Interval,@MaxRows=@MaxRows,@PayloadEnabled=@Payload,
 @RawRetentionDays=@RawDays,@PayloadRetentionDays=@PayloadDays,@RollupRetentionDays=@RollupDays,
 @SoftBudgetMB=@Budget,@PurgeIntervalMinutes=@PurgeMinutes,@PurgeBatchRows=@Batch,@BudgetAction=@Action,
 @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,
 @CollectorCode=@Collector,@CollectorEnabled=@Enabled,@UpdateSharedPolicy=@Shared,
 @ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Target,@ExpectedTargetCreateDate=@Created,
 @JoinFrameworkTransaction=@Join;';
            EXEC [sys].[sp_executesql] @NewSql,
 N'@Interval smallint,@MaxRows int,@Payload bit,@RawDays smallint,@PayloadDays smallint,@RollupDays smallint,@Budget int,@PurgeMinutes smallint,@Batch int,@Action varchar(32),@Status varchar(40) OUTPUT,@Error int OUTPUT,@Message nvarchar(2048) OUTPUT,@Collector varchar(64),@Enabled bit,@Shared bit,@Id int,@Target sysname,@Created datetime,@Join bit',
 @Interval=@CollectionIntervalSeconds,@MaxRows=@MaxRows,@Payload=@PayloadEnabled,@RawDays=@RawRetentionDays,
 @PayloadDays=@PayloadRetentionDays,@RollupDays=@RollupRetentionDays,@Budget=@SoftBudgetMB,
 @PurgeMinutes=@PurgeIntervalMinutes,@Batch=@PurgeBatchRows,@Action=@BudgetAction,
 @Status=@NewTargetStatus OUTPUT,@Error=@NewTargetError OUTPUT,@Message=@NewTargetMessage OUTPUT,
 @Collector=@CollectorCode,@Enabled=@CollectorEnabled,@Shared=@UpdateSharedPolicy,@Id=@NewTargetId,
 @Target=@TargetDatabaseName,@Created=@NewTargetCreated,@Join=@NewJoin;
            IF COALESCE(@NewTargetStatus,'')<>'AVAILABLE' OR @NewTargetError IS NOT NULL
            BEGIN
                -- Entry admitted no Caller transaction; any remaining TX belongs to this operation.
                IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
                SELECT @StatusCodeOut=COALESCE(NULLIF(@NewTargetStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                       @ErrorNumberOut=@NewTargetError,@ErrorMessageOut=@NewTargetMessage;
                RETURN;
            END;
            IF @UpdateSharedPolicy=1
            BEGIN
                IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 53768,N'Die eigene Konfigurationstransaktion hat ihren Zustand geändert.',1;
                UPDATE [monitor].[SnapshotTargetConfiguration]
                SET [TargetDatabaseName]=@TargetDatabaseName,[IsEnabled]=@IsEnabled,[DefaultSchedulerType]=@SchedulerType,
                    [PackageContractVersion]=1,[LastUpdatedUtc]=SYSUTCDATETIME()
                WHERE [ConfigurationId]=1;
                IF @@ROWCOUNT<>1 THROW 53701,N'Die Framework-Zielkonfiguration fehlt.',1;
                IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 53768,N'Der Frameworkwrite hat den Transaktionszustand geändert.',1;
                COMMIT TRANSACTION;
            END
            ELSE IF @@TRANCOUNT<>0 THROW 53768,N'Der Collector-only-Aufruf hat eine unerwartete Transaktion hinterlassen.',1;
        END TRY
        BEGIN CATCH
            IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
            SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'TARGET_UNAVAILABLE' END,
                   @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=CONVERT(nvarchar(2048),ERROR_MESSAGE());
        END CATCH;
        IF @PrintMeldungen=1 AND @StatusCodeOut<>'AVAILABLE'
        BEGIN
            SET @NewPrint=COALESCE(@ErrorMessageOut,CONVERT(nvarchar(2048),@StatusCodeOut));
            RAISERROR(N'USP_ConfigureSnapshotTarget: %s',10,1,@NewPrint) WITH NOWAIT;
        END;
        RETURN;
    END;

    IF NULLIF(LTRIM(RTRIM(@TargetDatabaseName)),N'') IS NULL
       OR @SchedulerType NOT IN ('MANUAL','EXTERNAL','SQL_AGENT')
       OR @IsEnabled IS NULL OR @IsEnabled NOT IN (0,1)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Ungültiger Zielname, Aktivierungswert oder Scheduler-Typ.';
        RETURN;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [master].[sys].[databases] WITH (NOLOCK)
        WHERE [name]=@TargetDatabaseName
          AND [state]=0
          AND [is_read_only]=0
    )
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,
               @ErrorMessageOut=N'Die konfigurierte Snapshot-Datenbank ist nicht online und schreibbar.';
        RETURN;
    END;

    DECLARE @Sql nvarchar(max),@TargetQuoted nvarchar(258)=QUOTENAME(@TargetDatabaseName),
            @TargetStatus varchar(40),@TargetError int,@TargetMessage nvarchar(2048);

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalConfigureSnapshotPolicy]
              @CollectionIntervalSeconds=@p1,@MaxRows=@p2,@PayloadEnabled=@p3,
              @RawRetentionDays=@p4,@PayloadRetentionDays=@p5,@RollupRetentionDays=@p6,
              @SoftBudgetMB=@p7,@PurgeIntervalMinutes=@p8,@PurgeBatchRows=@p9,
              @BudgetAction=@p10,@StatusCodeOut=@s OUTPUT,@ErrorNumberOut=@e OUTPUT,
              @ErrorMessageOut=@m OUTPUT;';
        EXEC [sys].[sp_executesql] @Sql,
             N'@p1 smallint,@p2 int,@p3 bit,@p4 smallint,@p5 smallint,@p6 smallint,@p7 int,@p8 smallint,@p9 int,@p10 varchar(32),@s varchar(40) OUTPUT,@e int OUTPUT,@m nvarchar(2048) OUTPUT',
             @CollectionIntervalSeconds,@MaxRows,@PayloadEnabled,@RawRetentionDays,@PayloadRetentionDays,@RollupRetentionDays,
             @SoftBudgetMB,@PurgeIntervalMinutes,@PurgeBatchRows,@BudgetAction,
             @s=@TargetStatus OUTPUT,@e=@TargetError OUTPUT,@m=@TargetMessage OUTPUT;

        IF @TargetStatus<>'AVAILABLE'
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT @StatusCodeOut=@TargetStatus,@IsPartialOut=1,@ErrorNumberOut=@TargetError,@ErrorMessageOut=@TargetMessage;
            RETURN;
        END;

        UPDATE [monitor].[SnapshotTargetConfiguration]
        SET [TargetDatabaseName]=@TargetDatabaseName,[IsEnabled]=@IsEnabled,
            [DefaultSchedulerType]=@SchedulerType,[PackageContractVersion]=1,
            [LastUpdatedUtc]=SYSUTCDATETIME()
        WHERE [ConfigurationId]=1;

        IF @@ROWCOUNT<>1
            THROW 53701,N'Die Framework-Zielkonfiguration fehlt.',1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'TARGET_UNAVAILABLE' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;

    IF @PrintMeldungen=1 AND @StatusCodeOut<>'AVAILABLE'
    BEGIN
        DECLARE @PrintMessage nvarchar(2048)=COALESCE(@ErrorMessageOut,CONVERT(nvarchar(2048),@StatusCodeOut));
        RAISERROR(N'USP_ConfigureSnapshotTarget: %s',10,1,@PrintMessage) WITH NOWAIT;
    END;
END;
GO

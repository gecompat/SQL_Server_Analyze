USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ExternalRuntimeAnalysis
Version      : 1.0.0
Stand        : 2026-07-22
Typ          : Stored Procedure
Zweck        : Die Procedure analysiert Konfiguration, registrierte Sprachen und Libraries,
               aktive External-Script-Requests, External Resource Pools sowie
               kumulative Runtime- und Performance-Counter-Evidenz.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : SERVERPROPERTY, sys.configurations, sys.dm_server_services,
               sys.external_languages, sys.external_language_files,
               sys.external_libraries, sys.external_library_files,
               sys.dm_external_script_requests, sys.dm_exec_requests,
               sys.dm_exec_sessions,
               sys.dm_external_script_execution_stats,
               sys.dm_resource_governor_external_resource_pools und
               sys.dm_os_performance_counters.
Datenschutz  : Liest keine Scripttexte, Parameter, Environment Variables,
               Binärinhalte oder Dateipfade. Konten und Clientkontext werden
               ausschließlich mit @MitSitzungskontext=1 ausgegeben.
Methodik     : Jede optionale Quelle wird einmal je Messpunkt materialisiert.
               Ein Sample verwendet ein gemeinsames Intervall und verwirft
               Deltas bei Reset, Zählerrückgang oder Poolversionswechsel.
Grenzen      : Registrierung und Konfiguration beweisen weder Installation
               noch Startfähigkeit einer konkreten Runtime. Request-CPU ist
               Engine-Evidenz und enthält keine belegte externe Prozess-CPU.
Kosten       : MEDIUM; optionales Sampling wartet höchstens 60 Sekunden.
Nebenwirkung : Rein lesend; führt kein externes Script aus und ändert weder
               Launchpad-, Resource-Governor- noch Serverkonfiguration.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ExternalRuntimeAnalysis]
      @DatabaseNames                    nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @LanguageNames                    nvarchar(max)  = NULL
    , @LanguageNamePattern              nvarchar(4000) = NULL
    , @SampleSeconds                    tinyint         = 0
    , @MitDateimetadaten                bit             = 0
    , @MitBerechtigungsanalyse          bit             = 0
    , @MitSitzungskontext               bit             = 0
    , @NurProblematisch                 bit             = 0
    , @MaxZeilen                        int             = 100
    , @LockTimeoutMs                    int             = 0
    , @ResultSetArt                     varchar(16)     = 'CONSOLE'
    , @ResultTablesJson                 nvarchar(max)   = NULL
    , @JsonErzeugen                     bit             = 0
    , @Json                             nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                   bit             = 1
    , @Hilfe                            bit             = 0
    , @StatusCodeOut                    varchar(40)     = NULL OUTPUT
    , @IsPartialOut                     bit             = NULL OUTPUT
    , @ErrorNumberOut                   int             = NULL OUTPUT
    , @ErrorMessageOut                  nvarchar(2048)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    /* Der öffentliche Findings-Export entsteht vor Ausgabehelpern und NOWAIT. */
    CREATE TABLE [#ExternalRuntimeAnalysis_Findings]
    (
          [FindingOrdinal] bigint NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MetricValue] decimal(38,4) NULL
        , [ThresholdValue] decimal(38,4) NULL
        , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    SET @Json=NULL;

    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
    DECLARE @LockTimeoutSql nvarchar(100);
    DECLARE @Now datetime2(3)=SYSUTCDATETIME();
    DECLARE @MeasurementStartUtc datetime2(3)=NULL,@MeasurementEndUtc datetime2(3)=NULL;
    DECLARE @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
    DECLARE @HostPlatform nvarchar(60)=TRY_CONVERT(nvarchar(60),SERVERPROPERTY(N'HostPlatform'));
    DECLARE @OutputModeRequested varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @OutputMode varchar(16)=@OutputModeRequested;
    DECLARE @TableResultRequested bit=CONVERT(bit,CASE WHEN @OutputModeRequested='TABLE' THEN 1 ELSE 0 END);
    DECLARE @ConsoleResultRequested bit=CONVERT(bit,CASE WHEN @OutputModeRequested='CONSOLE' THEN 1 ELSE 0 END);
    DECLARE @TableTarget sysname=NULL;
    DECLARE @StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0;
    DECLARE @ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@PrintMessage nvarchar(2048)=NULL;
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0
                               THEN CONVERT(bigint,9223372036854775807)
                               WHEN @MaxZeilen>0 THEN CONVERT(bigint,@MaxZeilen)
                               ELSE CONVERT(bigint,0) END;
    DECLARE @RequiredPerformancePermission nvarchar(128)=CASE WHEN COALESCE(@Major,0)>=16 THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END;
    DECLARE @RequiredServicePermission nvarchar(128)=CASE WHEN COALESCE(@Major,0)>=16 THEN N'VIEW SERVER SECURITY STATE' ELSE N'VIEW SERVER STATE' END;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ExternalRuntimeAnalysis';
        PRINT N'Die Procedure erfasst lesend External-Runtime-Konfiguration, sichtbare Language- und Libraryregistrierungen, aktive Requests, Pools und Counter. Sie führt keinen externen Code aus, installiert oder aktiviert keine Runtime.';
        PRINT N'Der Basispfad prüft EXTERNAL_RUNTIME_CURRENT ohne High-Impact-Gate. Ownernamen aktivieren zusätzlich CATALOG_DEEP und verlangen @HighImpactConfirmed=1 sowie aktuelle Policyfreigabe.';
        PRINT N'Datenbankname und Datenbankpattern sowie LanguageNames und LanguageNamePattern sind jeweils exklusiv. LanguageNames wird direkt als bracket-aware Pipe-Liste einteiliger SQL-Namen geparst.';
        PRINT N'@SampleSeconds=0 liefert eine Momentaufnahme; 1 bis 60 wartet auf den zweiten Messpunkt. Reset, Zählerrückgang, Versionswechsel oder fehlendes T2 verhindern Deltas.';
        PRINT N'@NurProblematisch=1 filtert nur WARN-Findings. @MaxZeilen=0 oder NULL ist unbegrenzt; positive Limits greifen nach Materialisierung.';
        PRINT N'@ResultSetArt: CONSOLE, RAW, TABLE oder NONE. TABLE exportiert nur findings in ein vorab geprüftes lokales #Temp-Ziel; JSON ist unabhängig steuerbar.';
        PRINT N'Globale Statuscodes: AVAILABLE, AVAILABLE_WITH_FINDING, AVAILABLE_LIMITED, FEATURE_DISABLED, NOT_APPLICABLE, INVALID_PARAMETER, UNAVAILABLE_FEATURE, HIGH_IMPACT_CONFIRMATION_REQUIRED, DENIED_GROUP, INTERNAL_ERROR, LOCK_TIMEOUT und ERROR_HANDLED.';
        PRINT N'@DatabaseNames nvarchar(max)=NULL; Default: NULL. NULL, leerer oder nur aus Leerzeichen bestehender Wert bedeutet keine Namensbeschränkung. Sonst Pipe-Liste einteiliger Datenbanknamen; | trennt außerhalb eckiger Klammern, ]] maskiert darin ]. Äußere Elementleerzeichen werden entfernt. Ein Rohsegment darf vor dem Trimmen höchstens 4000 UTF-16-Codeeinheiten umfassen; Elemente müssen gültige einzelne PARSENAME-Namen bis 128 Zeichen sein. Leere Elemente, fehlerhafte Klammerung, Mehrfachnamen und exakt doppelte gültige Namen sind ungültig. Vergleich erfolgt case-sensitiv. Fehlende, nicht online befindliche, nicht zugreifbare oder ohne Systemdatenbank-Opt-in ausgeschlossene gültige Namen werden als Datenbankwarnung geführt und können den Lauf partiell machen. Exakte Namensliste und @DatabaseNamePattern sind exklusiv. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@SystemdatenbankenEinbeziehen bit=0; Default: 0. 0 schließt database_id 1 bis 4 aus; 1 schließt sie ein, wenn sie sichtbar, online und zugreifbar sind. NULL ist im normalen Lauf ungültig. Der Parameterwert 0 bedeutet aus und 1 bedeutet ein; bei numerischer Übergabe wird 0 zu 0 und jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Das Opt-in setzt keine Rechte und macht eine nicht verfügbare Datenbank nicht verfügbar. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. NULL bedeutet kein Pattern. Sonst werden äußere Leerzeichen getrimmt und das Präfix ohne Beachtung der Großschreibung erkannt: regexi: bedeutet Regex mit Flag i, regex: Regex mit Flag c, like: SQL-LIKE; ohne Präfix gilt ebenfalls LIKE. Der Rest nach einem Präfix wird nicht erneut getrimmt und darf nicht leer sein. LIKE wird case-sensitiv auf den Datenbanknamen angewandt. Regex-Syntax wird nicht vorab validiert; Regex erfordert SQL Server 2025 (Major 17) und Compatibility Level 170 in der Framework- beziehungsweise Installationsdatenbank. Die Compatibility-Level-Prüfung für Zieldatenbanken gehört zum separaten @LanguageNamePattern-Pfad. Leere Eingaben und leere Präfixinhalte sind ungültig. Exakte Namensliste und Pattern sind exklusiv. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@HighImpactConfirmed bit=0; Default: 0. 0 bestätigt keinen High-Impact-Aufruf; 1 bestätigt ihn. NULL ist im normalen Lauf ungültig. Die Bestätigung ist keine Berechtigung. Der Basispfad verwendet EXTERNAL_RUNTIME_CURRENT mit RequiresGroupGate=0. Nur wenn @MitBerechtigungsanalyse=1, wird zusätzlich CATALOG_DEEP geprüft; diese Klasse verlangt Bestätigung 1 und eine aktuelle Policyfreigabe. 0 bedeutet keine Bestätigung und 1 bedeutet Bestätigung; bei numerischer Übergabe wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@LanguageNames nvarchar(max)=NULL; Default: NULL. NULL bedeutet keine Language-Einschränkung. Sonst eine Pipe-Liste einteiliger SQL-Namen angeben; der Parameter wird direkt durch TVF_ParseSqlNameList geprüft. | trennt außerhalb von [...], ]] maskiert darin ], Rand-Leerzeichen an Elementen werden entfernt. Rohsegmentgrenze 4000 UTF-16-Codeeinheiten, Namensgrenze 128 Zeichen. Leere Elemente, falsche Klammerung und mehrteilige Namen sind ungültig. Anders als @DatabaseNames bedeuten Leertext und Leerraumelemente keinen fehlenden Filter, sondern ungültige Eingabe. Doppelte Namen bleiben im Parser, duplizieren aber wegen des EXISTS-Abgleichs keine Ergebniszeilen. Der Language-Abgleich ist case-sensitiv. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@LanguageNamePattern nvarchar(4000)=NULL; Default: NULL. NULL bedeutet kein Pattern. Ansonsten gelten die Präfixe regexi: (Regex-Flag i), regex: (Regex-Flag c), like: (SQL-LIKE) sowie unpräfigiertes LIKE; Präfixerkennung ist case-insensitiv, nur äußerer Leerraum wird vorab getrimmt. LIKE-Vergleich ist case-sensitiv. Das Pattern filtert Languages, Libraries, passende aktive Requests und Execution Stats. Leerer Eingang oder leerer Präfixinhalt ist ungültig. Regex erfordert SQL Server 2025 (Major 17), Compatibility Level 170 in Framework- und Zieldatenbanken; Syntaxfehler werden erst beim Ausführen erkannt. Exklusiv zu @LanguageNames. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@SampleSeconds tinyint=0; Default: 0. 0 liefert einen Momentaufnahmepunkt ohne WAITFOR oder Deltas. Jeder Wert von 1 bis 60 einschließlich fordert T1/T2-Messpunkte mit WAITFOR DELAY für die angeforderte Intervallzeit an; SQL-Abfragezeit kommt hinzu. NULL und Werte über 60 sind ungültig. Pools, Performance Counter und Execution Stats sind serverweit; der Languagefilter beschränkt nicht alle serverweiten Zugriffe. Pooldeltas verlangen gleiche statistics_start_time und pool_version sowie nicht fallende Zähler; Reset, Versionswechsel, Rückgang oder fehlendes T2 verwerfen Deltas. Execution-Stats- und Counterdeltas werden bei Reset/Rückgang oder fehlendem T2 nicht ausgewiesen. Countertyp 65792 liefert RAW_SNAPSHOT; 272696320 und 272696576 liefern bei positivem und gültigem Sample RATE_PER_SECOND. 537003264 ist als FRACTION_DELTA_PERCENT und 1073874176 als AVERAGE_DELTA_RATIO klassifiziert, aber diese Procedure übergibt keine Basiszähler; deshalb bleibt ihre Metrik NULL und der Helper meldet BASE_COUNTER_MISSING, wenn ein gültiges Sample vorliegt. Weitere Typen bleiben RAW_UNINTERPRETED. Tatsächliche Messzeitstempel und Deltas sind keine atomare Messung, kein SLA und kein Nachweis externer Prozess-CPU. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MitDateimetadaten bit=0; Default: 0. 0 lässt Datei-Metadatenabfragen aus. 1 ergänzt für Language Files Dateiname und Plattform sowie für Library Files die Plattform. Datei- und Libraryinhalte, Pfade, Parameterspalten und Environment Variables werden nicht gelesen; Metadaten beweisen keine Installation oder Startfähigkeit. NULL ist im normalen Lauf ungültig. Das Opt-in aktiviert nicht CATALOG_DEEP und kein High-Impact-Gate; fehlende Rechte erscheinen als Quellenstatus. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MitBerechtigungsanalyse bit=0; Default: 0. 0 lässt Ownernamen aus. 1 ergänzt sichtbare database_principals-Namen der registrierten Languages und Libraries. Vor dem Katalogzugriff wird zusätzlich CATALOG_DEEP policygeprüft; diese Klasse erfordert @HighImpactConfirmed=1 und eine aktuelle Freigabe. Bestätigung allein erlaubt den Zugriff nicht. Eine Gateverweigerung stoppt den fachlichen Pfad. NULL ist im normalen Lauf ungültig; Metadatenrechte können die Sichtbarkeit begrenzen. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MitSitzungskontext bit=0; Default: 0. 0 projiziert Login, Host, Clientprogramm und External Worker Account für activeRequests als NULL. 1 ergänzt diese vier Felder aus dm_exec_sessions beziehungsweise dm_external_script_requests für sichtbare aktive Requests; keine historischen Identitäten. NULL ist im normalen Lauf ungültig. DMV-Rechte und Sichtbarkeit gelten unabhängig vom Opt-in. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@NurProblematisch bit=0; Default: 0. 0 übernimmt alle Findings-Schweregrade; 1 filtert ausschließlich Findings mit Severity=WARN. Dasselbe Prädikat gilt für CONSOLE, RAW, TABLE und JSON. Es filtert keine Katalog-, Request-, Pool-, Counter-, Quellenstatus-, Datenbankstatus- oder Warning-Ausgabe. NULL ist im normalen Lauf ungültig. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MaxZeilen int=100; Default: 100. NULL oder 0 bedeutet unbegrenzt. Positive Werte begrenzen nach vollständiger Materialisierung und jeweiliger Sortierung Findings, Languages, Libraries, activeRequests, externalPools, Execution Stats und Performance Counters; configuration, databaseStatus, sourceStatus und warnings sind nicht begrenzt. Findings werden nach @NurProblematisch gefiltert, WARN vor anderen Schweregraden sortiert und innerhalb dessen nach ursprünglichem FindingOrdinal begrenzt. Negative Werte setzen INVALID_PARAMETER; bei @JsonErzeugen=1 entsteht dennoch JSON mit Fehlerstatus. Die RESULTSET_TRUNCATED-Warnung zählt externalPools nicht, deshalb meldet eine alleinige Kürzung dieses Resultsets derzeit nicht zwingend eine Truncation. Ein positives Limit verringert nicht die vorgelagerte Quellarbeit. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@LockTimeoutMs int=0; Default: 0. Zulässig sind 0 bis 60000 Millisekunden einschließlich. 0 setzt LOCK_TIMEOUT 0 und wartet bei blockierten fachlichen Zugriffen nicht. NULL oder andere Werte sind ungültig. Der gesetzte Wert gilt für den Lauf und die ursprüngliche Sitzungseinstellung wird danach wiederhergestellt. Isolierte Quelltimeouts erscheinen als Quellenstatus; nicht isolierte Timeouts ergeben global LOCK_TIMEOUT. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. Zulässige Werte: CONSOLE rendert ein menschenlesbares Findingsresultset; RAW liefert zuerst Metadaten, danach configuration, databaseStatus, sourceStatus, findings, languages, libraries, activeRequests, externalPools, executionStats, performanceCounters und warnings in dieser Reihenfolge; TABLE schreibt ausschließlich findings in das lokale Ziel; NONE unterdrückt diese fachlichen Resultsets. Werte werden getrimmt und mit UPPER normalisiert. NULL oder andere Werte ergeben INVALID_PARAMETER. JSON ist unabhängig über @JsonErzeugen steuerbar. Nichtleeres @ResultTablesJson außerhalb TABLE löst 51011 vor dem Quellenzugriff aus. Leeres CONSOLE-Findingsresultat erzeugt eine verständliche Console-Zeile. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL; Default: NULL. Nur mit @ResultSetArt=TABLE ist ein nichtleeres Mapping gültig. NULL, leer oder nur Leerzeichen ist kein Mapping; nichtleerer Text bei anderem ResultSetArt wirft 51011. Für die Procedure wird ein JSON-Objekt mit exakt kleingeschriebenem, case-sensitivem Schlüssel findings und JSON-String als Ziel erwartet. Das Ziel ist eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. ##Temp, permanente Ziele, Präfix #Monitor (case-insensitiv) und Namen über 116 Zeichen sind unzulässig. Unbekannter/duplizierter Schlüssel, dupliziertes Ziel, falscher JSON-Werttyp, leeres Ziel oder ungültiges Ziel scheitert im vollständigen Preflight vor fachlichen Quellenzugriffen mit 51011. Erfolgreich schreibt der Helper die 13 findings-Spalten; späterer Writerfehler wirft 51010. Nach THROW sind OUTPUT-Übergaben nicht zugesichert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit=0; Default: 0. 0 erzeugt kein JSON und lässt @Json NULL. 1 erzeugt unabhängig von @ResultSetArt ein JSON-Objekt mit meta als Objekt sowie den Arrays configuration, databaseStatus, sourceStatus, findings, languages, libraries, activeRequests, externalPools, executionStats, performanceCounters und warnings. Leere Arrays sind []; NULL-Properties werden in der bestehenden FOR JSON PATH-Semantik ausgelassen. Auch bei INVALID_PARAMETER wird das JSON erzeugt, wenn 1 gewählt wurde. NULL ist im normalen Lauf ungültig. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT enthält bei @JsonErzeugen=1 das erzeugte JSON in einer nvarchar(max)-Variable, gebunden als @Json=@JsonVar OUTPUT; sonst bleibt es NULL. Es umfasst meta als Objekt und die Arrays configuration, databaseStatus, sourceStatus, findings, languages, libraries, activeRequests, externalPools, executionStats, performanceCounters und warnings; NULL-Properties sind ausgelassen. Beim Eintritt wird @Json auf NULL gesetzt. Beim frühen Hilfereturn bleibt es NULL. Vor Abschluss ausgelöste Fehler garantieren keine OUTPUT-Zustellung. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@PrintMeldungen bit=1; Default: 1. 0 unterdrückt Statusmeldungen und den Hinweis RESULTSET_TRUNCATED. 1 sendet beide möglichen Meldungen per RAISERROR mit Severity 10 und NOWAIT; fachliche Resultsets und OUTPUT-Werte bleiben davon getrennt. NULL ist im normalen Lauf ungültig. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit=0; Default: 0. 1 gibt eingebaute PRINT-Hilfe aus und kehrt vor Parameterprüfung, Quellenzugriff, fachlichen Resultsets und OUTPUT-Zuweisung zurück; @Json wurde zuvor auf NULL gesetzt. 0 und NULL führen zum normalen Pfad, sofern dessen Eingaben gültig sind. Hilfe liefert keinen Status oder Daten-Resultset. 0 bedeutet aus und 1 bedeutet Hilfe; bei numerischer Übergabe wird 0 zu 0 und jeder numerische Wert ungleich 0 wird zu 1 konvertiert. NULL wird durch IF nicht als Hilfeaufruf behandelt. Die TABLE-Zielvorprüfung läuft davor und kann auch bei einem Hilfeaufruf Fehler 51011 auslösen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. OUTPUT liefert den globalen Laufstatus in einer varchar(40)-Variable, die mit @StatusCodeOut=@StatusVar OUTPUT gebunden wird; Quellen- und Datenbankstatus sind davon getrennt. AVAILABLE bedeutet Abschluss ohne Warn-Finding und ohne Partialität; AVAILABLE_WITH_FINDING meldet mindestens ein WARN-Finding; AVAILABLE_LIMITED meldet teilweise Auswertung durch Quelle, Datenbank oder Auswahlwarnung. FEATURE_DISABLED bedeutet deaktivierte Option bei sichtbarer Registrierungs- oder Execution-Stats-Evidenz; NOT_APPLICABLE bedeutet deaktivierte Option ohne diese sichtbare Evidenz. INVALID_PARAMETER meldet ungültige Eingaben; UNAVAILABLE_FEATURE unerfüllte Regexversions-/Compatibility-Voraussetzung. HIGH_IMPACT_CONFIRMATION_REQUIRED meldet fehlende Bestätigung für den aktivierten CATALOG_DEEP-Pfad; DENIED_GROUP fehlende Policyfreigabe. INTERNAL_ERROR wird übernommen, wenn der Datenbankvorbereitungshelfer einen Fehler seiner Temp-Tabellenprobe meldet; dies ist kein regulärer fachlicher Auswahlwert. Die Procedure setzt die Partialität und lässt diesen globalen Status bestehen. LOCK_TIMEOUT ist ein nicht isoliert abgefangener Locktimeout; ERROR_HANDLED ein sonstiger nicht isolierter Fehler. Quell-/Datenbankcodes wie DENIED_PERMISSION, SOURCE_UNAVAILABLE, SYSTEM_DATABASE_EXCLUDED und DATABASE_UNAVAILABLE bleiben separat. Bei @Hilfe=1 erfolgt keine Zuweisung; nach THROW, einschließlich 51011/51010, ist keine OUTPUT-Zustellung garantiert. Frühe Parameter-, Gate- und Helfercodes bleiben bestehen. Solange der Status AVAILABLE ist, haben partielle Quellen oder Datenbanken Vorrang vor WARN-Findings; danach wird bei deaktivierter External-Scripts-Option zwischen FEATURE_DISABLED und NOT_APPLICABLE anhand der sichtbaren Evidenz unterschieden. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@IsPartialOut bit=NULL OUTPUT; Default: NULL. OUTPUT liefert die Partialität in einer bit-Variablen, gebunden als @IsPartialOut=@PartialVar OUTPUT. 1 kennzeichnet eingeschränkte oder teilweise Auswertung, unter anderem AVAILABLE_LIMITED, ungültige Eingaben, nicht verfügbare Regexvoraussetzungen, Gateverweigerung und INTERNAL_ERROR des Kandidatenhelfers; sonst 0. Isolierte Quellenfehler fließen in die Partialitätsbewertung ein. Das Feld ist vom separat ausgewiesenen IsPartial pro Quelle und Datenbank zu unterscheiden. Bei @Hilfe=1 erfolgt keine Zuweisung; nach THROW ist keine OUTPUT-Zustellung garantiert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@ErrorNumberOut int=NULL OUTPUT; Default: NULL. OUTPUT liefert die Fehlernummer in einer int-Variablen, gebunden als @ErrorNumberOut=@ErrorNoVar OUTPUT. Enthalten ist ein nicht isoliert abgefangener SQL-Fehler oder, falls der globale Wert noch NULL ist, der kleinste ErrorNumber-Wert aus partiellen Quellen; sonst NULL. Validierungs- und Gatefehler können eine Meldung ohne SQL-Fehlernummer haben. Bei @Hilfe=1 erfolgt keine Zuweisung; nach THROW, einschließlich 51011/51010, ist keine OUTPUT-Zustellung garantiert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. OUTPUT liefert die Fehlermeldung in einer nvarchar(2048)-Variable, gebunden als @ErrorMessageOut=@ErrorMsgVar OUTPUT. Enthalten ist die globale Fehlermeldung oder, falls noch keine vorhanden ist, der lexikalisch kleinste ErrorMessage-Wert einer partiellen Quelle; sonst NULL. Isolierte Details bleiben zusätzlich in sourceStatus und databaseStatus. Bei @Hilfe=1 erfolgt keine Zuweisung; nach THROW ist keine OUTPUT-Zustellung garantiert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_ExternalRuntimeAnalysis] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @LanguageNames=N''[ExampleLanguage]'', @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'Beispiel 3: DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];';
        PRINT N'Beispiel 4: CREATE TABLE [#ExternalRuntimeAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"findings":"#ExternalRuntimeAnalysis_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM [#ExternalRuntimeAnalysis_HelpExample]; DROP TABLE IF EXISTS [#ExternalRuntimeAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#ExternalRuntimeAnalysis_HelpExample]; THROW; END CATCH;';
        PRINT N'Beispiel 5: EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNamePattern=N''like:ExampleDatabase%'', @LanguageNamePattern=N''like:ExampleLanguage%'', @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'Beispiel 6: EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @SampleSeconds=1, @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'Beispiel 7: EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @MitBerechtigungsanalyse=1, @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        RETURN;
    END;

    IF @OutputModeRequested NOT IN('CONSOLE','RAW','TABLE','NONE')
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE sein.';
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL
        THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1
        EXEC [monitor].[InternalPrepareSingleResultTable]
              @ResultTablesJson=@ResultTablesJson
            , @ResultName=N'findings'
            , @TargetTable=@TableTarget OUTPUT
            , @ThrowOnError=1;
    IF @TableResultRequested=1 OR @ConsoleResultRequested=1 SET @OutputMode='NONE';

    IF @StatusCode='AVAILABLE'
       AND (@SystemdatenbankenEinbeziehen IS NULL OR @HighImpactConfirmed IS NULL
            OR @MitDateimetadaten IS NULL OR @MitBerechtigungsanalyse IS NULL
            OR @MitSitzungskontext IS NULL OR @NurProblematisch IS NULL
            OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
            OR @SampleSeconds IS NULL OR @SampleSeconds>60
            OR @MaxZeilen<0
            OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000)
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'Ungültiger Bit-, Sample-, Zeilen- oder Lock-Timeout-Parameter.';

    CREATE TABLE [#ExternalRuntimeAnalysis_DatabaseCandidates]
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
    CREATE TABLE [#ExternalRuntimeAnalysis_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_LanguageFilters]
    (
          [ItemOrdinal] int NOT NULL
        , [LanguageName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([LanguageName])
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_Configuration]
    (
          [CollectedAtUtc] datetime2(3) NOT NULL
        , [ProductMajorVersion] int NULL
        , [HostPlatform] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsAdvancedAnalyticsInstalled] int NULL
        , [ExternalScriptsConfiguredValue] int NULL
        , [ExternalScriptsValueInUse] int NULL
        , [LaunchpadServiceCount] int NULL
        , [LaunchpadRunningCount] int NULL
        , [LaunchpadStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RequiredPerformancePermission] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RequiredServicePermission] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_DatabaseStatus]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [LanguageCount] bigint NOT NULL
        , [LibraryCount] bigint NOT NULL
        , [SourceFailureCount] int NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_SourceStatus]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [RowCount] bigint NOT NULL
        , [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ReadAtUtc] datetime2(3) NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_Languages]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ExternalLanguageId] int NOT NULL
        , [LanguageName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CreateDate] datetime2 NULL
        , [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FileName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FilePlatformDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FileMetadataStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AssessmentStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_Libraries]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ExternalLibraryId] int NOT NULL
        , [LibraryName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [LanguageName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ScopeDesc] varchar(7) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FilePlatformDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FileMetadataStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AssessmentStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_ActiveRequests]
    (
          [ExternalScriptRequestId] uniqueidentifier NOT NULL
        , [LanguageName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DegreeOfParallelism] int NULL
        , [SessionId] smallint NULL
        , [RequestId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [BlockingSessionId] smallint NULL
        , [WaitType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [WaitTimeMs] int NULL
        , [ElapsedTimeMs] int NULL
        , [EngineCpuTimeMs] int NULL
        , [Reads] bigint NULL
        , [LogicalReads] bigint NULL
        , [Writes] bigint NULL
        , [LoginName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ExternalWorkerAccount] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_PoolSamples]
    (
          [SamplePoint] char(2) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ReadAtUtc] datetime2(3) NOT NULL
        , [ExternalPoolId] int NOT NULL
        , [PoolName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PoolVersion] int NULL
        , [MaxCpuPercent] int NULL
        , [MaxProcesses] int NULL
        , [MaxMemoryPercent] int NULL
        , [StatisticsStartTime] datetime NULL
        , [PeakMemoryKb] bigint NULL
        , [WriteIoCount] bigint NULL
        , [ReadIoCount] bigint NULL
        , [TotalCpuKernelMs] bigint NULL
        , [TotalCpuUserMs] bigint NULL
        , [ActiveProcessesCount] int NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_ExternalPools]
    (
          [ExternalPoolId] int NOT NULL
        , [PoolName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MaxCpuPercent] int NULL
        , [MaxProcesses] int NULL
        , [MaxMemoryPercent] int NULL
        , [StatisticsStartTime] datetime NULL
        , [PeakMemoryKb] bigint NULL
        , [ActiveProcessesCount] int NULL
        , [SampleSeconds] decimal(19,6) NULL
        , [CpuKernelDelta] bigint NULL
        , [CpuUserDelta] bigint NULL
        , [ReadIoDelta] bigint NULL
        , [WriteIoDelta] bigint NULL
        , [DeltaStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_ExecutionStatSamples]
    (
          [SamplePoint] char(2) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ReadAtUtc] datetime2(3) NOT NULL
        , [LanguageName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterValue] bigint NOT NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_ExecutionStats]
    (
          [LanguageName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterValue] bigint NOT NULL
        , [CounterDelta] bigint NULL
        , [DeltaStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_CounterSamples]
    (
          [SamplePoint] char(2) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ReadAtUtc] datetime2(3) NOT NULL
        , [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterType] int NOT NULL
        , [CounterValue] bigint NOT NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_PerformanceCounters]
    (
          [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterType] int NOT NULL
        , [CounterValue] bigint NOT NULL
        , [CounterDelta] bigint NULL
        , [DeltaStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Interpretation] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricValue] decimal(38,6) NULL
        , [MetricUnit] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_FindingsCollected]
    (
          [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MetricValue] decimal(38,4) NULL
        , [ThresholdValue] decimal(38,4) NULL
        , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExternalRuntimeAnalysis_Warnings]
    (
          [WarningCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    BEGIN TRY
        DECLARE @LanguagePatternMode varchar(8),@LanguagePatternValue nvarchar(4000),@LanguageRegexFlags varchar(8),@LanguagePatternValid bit;
        SELECT @LanguagePatternMode=[PatternMode],@LanguagePatternValue=[PatternValue],
               @LanguageRegexFlags=[RegexFlags],@LanguagePatternValid=[IsValid]
        FROM [monitor].[TVF_ParsePattern](@LanguageNamePattern);

        IF @StatusCode='AVAILABLE'
           AND (@LanguagePatternValid=0 OR (@LanguageNames IS NOT NULL AND @LanguageNamePattern IS NOT NULL))
            SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@LanguageNamePattern ist ungültig oder wurde zusammen mit @LanguageNames angegeben.';
        IF @StatusCode='AVAILABLE' AND @LanguagePatternMode IN('REGEX','REGEXI')
           AND
           (
               COALESCE(@Major,0)<17
               OR NOT EXISTS
                  (
                      SELECT 1
                      FROM [master].[sys].[databases] [d] WITH (NOLOCK)
                      WHERE [d].[database_id]=DB_ID() AND [d].[compatibility_level]>=170
                  )
           )
            SELECT @StatusCode='UNAVAILABLE_FEATURE',@IsPartial=1,@ErrorMessage=N'Regex-Pattern benötigen SQL Server 2025 und Compatibility Level 170 in der Frameworkdatenbank.';

        IF @StatusCode='AVAILABLE'
        BEGIN
            INSERT [#ExternalRuntimeAnalysis_LanguageFilters]([ItemOrdinal],[LanguageName])
            SELECT [ItemOrdinal],[NameValue]
            FROM [monitor].[TVF_ParseSqlNameList](@LanguageNames)
            WHERE [IsValid]=1;
            IF EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@LanguageNames) WHERE [IsValid]=0)
                SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@LanguageNames enthält mindestens einen ungültigen SQL-Namen.';
        END;

        IF @StatusCode='AVAILABLE' AND @MitBerechtigungsanalyse=1
        BEGIN
            EXEC [monitor].[InternalCheckAnalysisPath]
                  @AnalysisClass='CATALOG_DEEP'
                , @HighImpactConfirmed=@HighImpactConfirmed
                , @StatusCode=@StatusCode OUTPUT
                , @ErrorMessage=@ErrorMessage OUTPUT;
            IF @StatusCode<>'AVAILABLE' SET @IsPartial=1;
        END;

        DECLARE @CrossDatabaseRequested bit=0;
        IF @StatusCode='AVAILABLE'
        BEGIN
            EXEC [monitor].[USP_PrepareDatabaseCandidates]
                  @DatabaseNames=@DatabaseNames
                , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern=@DatabaseNamePattern
                , @HighImpactConfirmed=@HighImpactConfirmed
                , @AnalysisClass='EXTERNAL_RUNTIME_CURRENT'
                , @StatusCode=@StatusCode OUTPUT
                , @ErrorMessage=@ErrorMessage OUTPUT
                , @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT
                , @CandidateTable=N'#ExternalRuntimeAnalysis_DatabaseCandidates'
                , @WarningTable=N'#ExternalRuntimeAnalysis_DatabaseCandidateWarnings';
            IF @StatusCode<>'AVAILABLE' SET @IsPartial=1;
        END;

        INSERT [#ExternalRuntimeAnalysis_DatabaseStatus]
        ([DatabaseName],[StatusCode],[IsPartial],[LanguageCount],[LibraryCount],[SourceFailureCount],[EvidenceLimit])
        SELECT [DatabaseName],'PENDING',0,0,0,0,N'Sichtbare Datenbankkataloge; fehlende Metadatenrechte können zu Unterzählung führen.'
        FROM [#ExternalRuntimeAnalysis_DatabaseCandidates];
        INSERT [#ExternalRuntimeAnalysis_DatabaseStatus]
        ([DatabaseName],[StatusCode],[IsPartial],[LanguageCount],[LibraryCount],[SourceFailureCount],[ErrorMessage],[EvidenceLimit])
        SELECT [RequestedName],[StatusCode],1,0,0,1,[ErrorMessage],N'Explizit angeforderte Datenbank war nicht auswertbar.'
        FROM [#ExternalRuntimeAnalysis_DatabaseCandidateWarnings];

        SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';
        EXEC [sys].[sp_executesql] @LockTimeoutSql;

        IF @StatusCode='AVAILABLE'
        BEGIN
            INSERT [#ExternalRuntimeAnalysis_Configuration]
            ([CollectedAtUtc],[ProductMajorVersion],[HostPlatform],[IsAdvancedAnalyticsInstalled],
             [ExternalScriptsConfiguredValue],[ExternalScriptsValueInUse],[LaunchpadServiceCount],
             [LaunchpadRunningCount],[LaunchpadStatus],[RequiredPerformancePermission],
             [RequiredServicePermission],[EvidenceLimit])
            SELECT @Now,@Major,@HostPlatform,
                   TRY_CONVERT(int,SERVERPROPERTY(N'IsAdvancedAnalyticsInstalled')),
                   MAX(CASE WHEN [name]=N'external scripts enabled' THEN TRY_CONVERT(int,[value]) END),
                   MAX(CASE WHEN [name]=N'external scripts enabled' THEN TRY_CONVERT(int,[value_in_use]) END),
                   NULL,NULL,'SOURCE_PENDING',@RequiredPerformancePermission,@RequiredServicePermission,
                   N'Konfiguration, Installationsproperty und Servicestatus sind getrennte Evidenz und beweisen keine Runtime-Startfähigkeit.'
            FROM [sys].[configurations] WITH (NOLOCK)
            WHERE [name]=N'external scripts enabled';
            INSERT [#ExternalRuntimeAnalysis_SourceStatus]
            VALUES(NULL,'SERVER_CONFIGURATION','AVAILABLE',0,1,N'VIEW SERVER STATE beziehungsweise Metadatensichtbarkeit',SYSUTCDATETIME(),NULL,NULL,
                   N'Nur external scripts enabled und SERVERPROPERTY(IsAdvancedAnalyticsInstalled).');

            BEGIN TRY
                DECLARE @LaunchpadServiceCount int,@LaunchpadRunningCount int;
                SELECT @LaunchpadServiceCount=COUNT_BIG(*),
                       @LaunchpadRunningCount=COALESCE(SUM(CASE WHEN [status]=4 THEN 1 ELSE 0 END),0)
                FROM [sys].[dm_server_services] WITH (NOLOCK)
                WHERE [servicename] LIKE N'%Launchpad%';
                UPDATE [#ExternalRuntimeAnalysis_Configuration]
                SET [LaunchpadServiceCount]=@LaunchpadServiceCount,
                    [LaunchpadRunningCount]=@LaunchpadRunningCount,
                    [LaunchpadStatus]=CASE WHEN @LaunchpadServiceCount=0 THEN 'NOT_VISIBLE'
                                           WHEN @LaunchpadRunningCount=@LaunchpadServiceCount THEN 'RUNNING'
                                           WHEN @LaunchpadRunningCount=0 THEN 'STOPPED'
                                           ELSE 'PARTIALLY_RUNNING' END;
                INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                VALUES(NULL,'LAUNCHPAD_SERVICE','AVAILABLE',0,@LaunchpadServiceCount,@RequiredServicePermission,SYSUTCDATETIME(),NULL,NULL,
                       N'Nur aggregierter Launchpad-Servicezustand; Dienstkonto, Pfad und Instanzname werden nicht ausgegeben.');
            END TRY
            BEGIN CATCH
                UPDATE [#ExternalRuntimeAnalysis_Configuration] SET [LaunchpadStatus]='SOURCE_UNAVAILABLE';
                INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                VALUES(NULL,'LAUNCHPAD_SERVICE',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,
                       @RequiredServicePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Launchpad-Status konnte nicht gelesen werden; andere Evidenz bleibt gültig.');
            END CATCH;
        END;

        DECLARE @Db sysname,@CompatibilityLevel int,@Sql nvarchar(max),@Rows bigint;
        DECLARE @LanguagePredicate nvarchar(max)=
            N' AND (NOT EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_LanguageFilters]) OR EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_LanguageFilters] [f] WHERE [f].[LanguageName]=[el].[language] COLLATE SQL_Latin1_General_CP1_CS_AS))';
        DECLARE @LibraryLanguagePredicate nvarchar(max)=
            N' AND (NOT EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_LanguageFilters]) OR EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_LanguageFilters] [f] WHERE [f].[LanguageName]=[lib].[language] COLLATE SQL_Latin1_General_CP1_CS_AS))';
        IF @LanguagePatternMode='LIKE'
        BEGIN
            SET @LanguagePredicate+=N' AND [el].[language] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @pPattern COLLATE SQL_Latin1_General_CP1_CS_AS';
            SET @LibraryLanguagePredicate+=N' AND [lib].[language] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @pPattern COLLATE SQL_Latin1_General_CP1_CS_AS';
        END;
        IF @LanguagePatternMode IN('REGEX','REGEXI')
        BEGIN
            SET @LanguagePredicate+=N' AND REGEXP_LIKE([el].[language],@pPattern,@pRegexFlags)';
            SET @LibraryLanguagePredicate+=N' AND REGEXP_LIKE([lib].[language],@pPattern,@pRegexFlags)';
        END;

        IF @StatusCode='AVAILABLE'
        BEGIN
            DECLARE [DatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [DatabaseName],[CompatibilityLevel]
                FROM [#ExternalRuntimeAnalysis_DatabaseCandidates]
                ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];
            OPEN [DatabaseCursor];
            FETCH NEXT FROM [DatabaseCursor] INTO @Db,@CompatibilityLevel;
            WHILE @@FETCH_STATUS=0
            BEGIN
                IF @LanguagePatternMode IN('REGEX','REGEXI') AND COALESCE(@CompatibilityLevel,0)<170
                BEGIN
                    UPDATE [#ExternalRuntimeAnalysis_DatabaseStatus]
                    SET [StatusCode]='UNAVAILABLE_FEATURE',[IsPartial]=1,[SourceFailureCount]=[SourceFailureCount]+1,
                        [ErrorMessage]=N'Regex-Pattern benötigen Compatibility Level 170.'
                    WHERE [DatabaseName]=@Db;
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(@Db,'FILTER_CONTRACT','UNAVAILABLE_FEATURE',1,0,N'Compatibility Level 170',SYSUTCDATETIME(),NULL,N'Regex-Pattern nicht ausführbar.',N'Keine Katalogquelle wurde für diese Datenbank gelesen.');
                    FETCH NEXT FROM [DatabaseCursor] INTO @Db,@CompatibilityLevel;
                    CONTINUE;
                END;

                BEGIN TRY
                    SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#ExternalRuntimeAnalysis_Languages]
([DatabaseName],[ExternalLanguageId],[LanguageName],[CreateDate],[OwnerName],[FileName],[FilePlatformDesc],[FileMetadataStatus],[AssessmentStatus],[EvidenceLimit])
SELECT @pDatabaseName,[el].[external_language_id],[el].[language],[el].[create_date],'
 + CASE WHEN @MitBerechtigungsanalyse=1 THEN N'[dp].[name]' ELSE N'CONVERT(sysname,NULL)' END + N',
       NULL,NULL,'+CASE WHEN @MitDateimetadaten=1 THEN N'''PENDING''' ELSE N'''NOT_REQUESTED''' END+N',
       ''REGISTERED_STARTABILITY_UNVERIFIED'',
       N''Registrierung beweist weder installierte Runtime noch erfolgreiche Initialisierung.''
FROM [sys].[external_languages] [el] WITH (NOLOCK) '
 + CASE WHEN @MitBerechtigungsanalyse=1 THEN N'LEFT JOIN [sys].[database_principals] [dp] WITH (NOLOCK) ON [dp].[principal_id]=[el].[principal_id] ' ELSE N'' END
 + N'WHERE 1=1 '+@LanguagePredicate+N'; SET @pRows=@@ROWCOUNT;';
                    SET @Rows=0;
                    EXEC [sys].[sp_executesql] @Sql,
                         N'@pDatabaseName sysname,@pPattern nvarchar(4000),@pRegexFlags varchar(8),@pRows bigint OUTPUT',
                         @pDatabaseName=@Db,@pPattern=@LanguagePatternValue,@pRegexFlags=@LanguageRegexFlags,@pRows=@Rows OUTPUT;
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(@Db,'EXTERNAL_LANGUAGES','AVAILABLE',0,@Rows,N'Metadatensichtbarkeit',SYSUTCDATETIME(),NULL,NULL,N'Keine Binärinhalte, Parameter oder Environment Variables.');
                END TRY
                BEGIN CATCH
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(@Db,'EXTERNAL_LANGUAGES',CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER() IN(207,208) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,1,0,N'Metadatensichtbarkeit',SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Sprachenkatalog isoliert fehlgeschlagen.');
                END CATCH;

                IF @MitDateimetadaten=1
                BEGIN TRY
                    SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#ExternalRuntimeAnalysis_Languages]
([DatabaseName],[ExternalLanguageId],[LanguageName],[CreateDate],[OwnerName],[FileName],[FilePlatformDesc],[FileMetadataStatus],[AssessmentStatus],[EvidenceLimit])
SELECT @pDatabaseName,[el].[external_language_id],[el].[language],[el].[create_date],'
 + CASE WHEN @MitBerechtigungsanalyse=1 THEN N'[dp].[name]' ELSE N'CONVERT(sysname,NULL)' END + N',
       [elf].[file_name],[elf].[platform_desc],''AVAILABLE'',''REGISTERED_STARTABILITY_UNVERIFIED'',
       N''Nur Dateiname und Plattform; content, parameters und environment_variables sind ausgeschlossen.''
FROM [sys].[external_languages] [el] WITH (NOLOCK)
JOIN [sys].[external_language_files] [elf] WITH (NOLOCK) ON [elf].[external_language_id]=[el].[external_language_id] '
 + CASE WHEN @MitBerechtigungsanalyse=1 THEN N'LEFT JOIN [sys].[database_principals] [dp] WITH (NOLOCK) ON [dp].[principal_id]=[el].[principal_id] ' ELSE N'' END
 + N'WHERE 1=1 '+@LanguagePredicate+N';
SET @pRows=@@ROWCOUNT;
DELETE [base] FROM [#ExternalRuntimeAnalysis_Languages] [base]
WHERE [base].[DatabaseName]=@pDatabaseName AND [base].[FileMetadataStatus]=''PENDING''
  AND EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_Languages] [f]
             WHERE [f].[DatabaseName]=[base].[DatabaseName] AND [f].[ExternalLanguageId]=[base].[ExternalLanguageId]
               AND [f].[FileMetadataStatus]=''AVAILABLE'');
UPDATE [#ExternalRuntimeAnalysis_Languages] SET [FileMetadataStatus]=''NO_FILE_ROW_VISIBLE''
WHERE [DatabaseName]=@pDatabaseName AND [FileMetadataStatus]=''PENDING'';';
                    SET @Rows=0;
                    EXEC [sys].[sp_executesql] @Sql,
                         N'@pDatabaseName sysname,@pPattern nvarchar(4000),@pRegexFlags varchar(8),@pRows bigint OUTPUT',
                         @pDatabaseName=@Db,@pPattern=@LanguagePatternValue,@pRegexFlags=@LanguageRegexFlags,@pRows=@Rows OUTPUT;
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(@Db,'EXTERNAL_LANGUAGE_FILES','AVAILABLE',0,@Rows,N'Metadatensichtbarkeit',SYSUTCDATETIME(),NULL,NULL,N'content, parameters und environment_variables werden nicht referenziert.');
                END TRY
                BEGIN CATCH
                    UPDATE [#ExternalRuntimeAnalysis_Languages] SET [FileMetadataStatus]='ERROR_HANDLED'
                    WHERE [DatabaseName]=@Db AND [FileMetadataStatus]='PENDING';
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(@Db,'EXTERNAL_LANGUAGE_FILES',CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER() IN(207,208) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,1,0,N'Metadatensichtbarkeit',SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Dateimetadaten isoliert fehlgeschlagen; Sprachzeilen bleiben erhalten.');
                END CATCH;

                BEGIN TRY
                    SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#ExternalRuntimeAnalysis_Libraries]
([DatabaseName],[ExternalLibraryId],[LibraryName],[LanguageName],[ScopeDesc],[OwnerName],[FilePlatformDesc],[FileMetadataStatus],[AssessmentStatus],[EvidenceLimit])
SELECT @pDatabaseName,[lib].[external_library_id],[lib].[name],[lib].[language],[lib].[scope_desc],'
 + CASE WHEN @MitBerechtigungsanalyse=1 THEN N'[dp].[name]' ELSE N'CONVERT(sysname,NULL)' END + N',
       NULL,'+CASE WHEN @MitDateimetadaten=1 THEN N'''PENDING''' ELSE N'''NOT_REQUESTED''' END+N',
       ''REGISTERED_STARTABILITY_UNVERIFIED'',
       N''Libraryregistrierung beweist weder Packageinstallation außerhalb des Katalogs noch erfolgreiche Ausführung.''
FROM [sys].[external_libraries] [lib] WITH (NOLOCK) '
 + CASE WHEN @MitBerechtigungsanalyse=1 THEN N'LEFT JOIN [sys].[database_principals] [dp] WITH (NOLOCK) ON [dp].[principal_id]=[lib].[principal_id] ' ELSE N'' END
 + N'WHERE 1=1 '+@LibraryLanguagePredicate+N'; SET @pRows=@@ROWCOUNT;';
                    SET @Rows=0;
                    EXEC [sys].[sp_executesql] @Sql,
                         N'@pDatabaseName sysname,@pPattern nvarchar(4000),@pRegexFlags varchar(8),@pRows bigint OUTPUT',
                         @pDatabaseName=@Db,@pPattern=@LanguagePatternValue,@pRegexFlags=@LanguageRegexFlags,@pRows=@Rows OUTPUT;
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(@Db,'EXTERNAL_LIBRARIES','AVAILABLE',0,@Rows,N'Metadatensichtbarkeit',SYSUTCDATETIME(),NULL,NULL,N'Libraryinhalt wird nicht gelesen.');
                END TRY
                BEGIN CATCH
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(@Db,'EXTERNAL_LIBRARIES',CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER() IN(207,208) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,1,0,N'Metadatensichtbarkeit',SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Librarykatalog isoliert fehlgeschlagen.');
                END CATCH;

                IF @MitDateimetadaten=1
                BEGIN TRY
                    SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#ExternalRuntimeAnalysis_Libraries]
([DatabaseName],[ExternalLibraryId],[LibraryName],[LanguageName],[ScopeDesc],[OwnerName],[FilePlatformDesc],[FileMetadataStatus],[AssessmentStatus],[EvidenceLimit])
SELECT @pDatabaseName,[lib].[external_library_id],[lib].[name],[lib].[language],[lib].[scope_desc],'
 + CASE WHEN @MitBerechtigungsanalyse=1 THEN N'[dp].[name]' ELSE N'CONVERT(sysname,NULL)' END + N',
       [lf].[platform_desc],''AVAILABLE'',''REGISTERED_STARTABILITY_UNVERIFIED'',
       N''Nur Plattformmetadaten; content ist ausgeschlossen.''
FROM [sys].[external_libraries] [lib] WITH (NOLOCK)
JOIN [sys].[external_library_files] [lf] WITH (NOLOCK) ON [lf].[external_library_id]=[lib].[external_library_id] '
 + CASE WHEN @MitBerechtigungsanalyse=1 THEN N'LEFT JOIN [sys].[database_principals] [dp] WITH (NOLOCK) ON [dp].[principal_id]=[lib].[principal_id] ' ELSE N'' END
 + N'WHERE 1=1 '+@LibraryLanguagePredicate+N';
SET @pRows=@@ROWCOUNT;
DELETE [base] FROM [#ExternalRuntimeAnalysis_Libraries] [base]
WHERE [base].[DatabaseName]=@pDatabaseName AND [base].[FileMetadataStatus]=''PENDING''
  AND EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_Libraries] [f]
             WHERE [f].[DatabaseName]=[base].[DatabaseName] AND [f].[ExternalLibraryId]=[base].[ExternalLibraryId]
               AND [f].[FileMetadataStatus]=''AVAILABLE'');
UPDATE [#ExternalRuntimeAnalysis_Libraries] SET [FileMetadataStatus]=''NO_FILE_ROW_VISIBLE''
WHERE [DatabaseName]=@pDatabaseName AND [FileMetadataStatus]=''PENDING'';';
                    SET @Rows=0;
                    EXEC [sys].[sp_executesql] @Sql,
                         N'@pDatabaseName sysname,@pPattern nvarchar(4000),@pRegexFlags varchar(8),@pRows bigint OUTPUT',
                         @pDatabaseName=@Db,@pPattern=@LanguagePatternValue,@pRegexFlags=@LanguageRegexFlags,@pRows=@Rows OUTPUT;
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(@Db,'EXTERNAL_LIBRARY_FILES','AVAILABLE',0,@Rows,N'Metadatensichtbarkeit',SYSUTCDATETIME(),NULL,NULL,N'content wird nicht referenziert.');
                END TRY
                BEGIN CATCH
                    UPDATE [#ExternalRuntimeAnalysis_Libraries] SET [FileMetadataStatus]='ERROR_HANDLED'
                    WHERE [DatabaseName]=@Db AND [FileMetadataStatus]='PENDING';
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(@Db,'EXTERNAL_LIBRARY_FILES',CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER() IN(207,208) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,1,0,N'Metadatensichtbarkeit',SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Library-Dateimetadaten isoliert fehlgeschlagen.');
                END CATCH;

                UPDATE [ds]
                SET [LanguageCount]=(SELECT COUNT_BIG(DISTINCT [ExternalLanguageId]) FROM [#ExternalRuntimeAnalysis_Languages] [l] WHERE [l].[DatabaseName]=[ds].[DatabaseName]),
                    [LibraryCount]=(SELECT COUNT_BIG(DISTINCT [ExternalLibraryId]) FROM [#ExternalRuntimeAnalysis_Libraries] [l] WHERE [l].[DatabaseName]=[ds].[DatabaseName])
                FROM [#ExternalRuntimeAnalysis_DatabaseStatus] [ds]
                WHERE [ds].[DatabaseName]=@Db;

                FETCH NEXT FROM [DatabaseCursor] INTO @Db,@CompatibilityLevel;
            END;
            CLOSE [DatabaseCursor]; DEALLOCATE [DatabaseCursor];
        END;

        DECLARE @RuntimeLanguagePredicate nvarchar(max)=
            N' AND (NOT EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_LanguageFilters]) OR EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_LanguageFilters] [f] WHERE [f].[LanguageName]=[er].[language] COLLATE SQL_Latin1_General_CP1_CS_AS))';
        DECLARE @StatsLanguagePredicate nvarchar(max)=
            N' AND (NOT EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_LanguageFilters]) OR EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_LanguageFilters] [f] WHERE [f].[LanguageName]=[es].[language] COLLATE SQL_Latin1_General_CP1_CS_AS))';
        IF @LanguagePatternMode='LIKE'
        BEGIN
            SET @RuntimeLanguagePredicate+=N' AND [er].[language] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @pPattern COLLATE SQL_Latin1_General_CP1_CS_AS';
            SET @StatsLanguagePredicate+=N' AND [es].[language] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @pPattern COLLATE SQL_Latin1_General_CP1_CS_AS';
        END;
        IF @LanguagePatternMode IN('REGEX','REGEXI')
        BEGIN
            SET @RuntimeLanguagePredicate+=N' AND REGEXP_LIKE([er].[language],@pPattern,@pRegexFlags)';
            SET @StatsLanguagePredicate+=N' AND REGEXP_LIKE([es].[language],@pPattern,@pRegexFlags)';
        END;

        IF @StatusCode='AVAILABLE'
        BEGIN
            BEGIN TRY
                SET @Sql=N'INSERT [#ExternalRuntimeAnalysis_ActiveRequests]
([ExternalScriptRequestId],[LanguageName],[DegreeOfParallelism],[SessionId],[RequestId],[DatabaseName],[RequestStatus],[Command],
 [BlockingSessionId],[WaitType],[WaitTimeMs],[ElapsedTimeMs],[EngineCpuTimeMs],[Reads],[LogicalReads],[Writes],
 [LoginName],[HostName],[ProgramName],[ExternalWorkerAccount],[EvidenceLimit])
SELECT [er].[external_script_request_id],[er].[language],[er].[degree_of_parallelism],
       [r].[session_id],[r].[request_id],[d].[name],[r].[status],[r].[command],[r].[blocking_session_id],
       [r].[wait_type],[r].[wait_time],[r].[total_elapsed_time],[r].[cpu_time],[r].[reads],[r].[logical_reads],[r].[writes],'
 + CASE WHEN @MitSitzungskontext=1 THEN N'[s].[login_name],[s].[host_name],[s].[program_name],[er].[external_user_name]' ELSE N'NULL,NULL,NULL,NULL' END + N',
       N''Aktive Momentaufnahme; Engine-CPU enthält keine belegte externe Prozess-CPU und abgeschlossene Requests fehlen.''
FROM [sys].[dm_external_script_requests] [er] WITH (NOLOCK)
LEFT JOIN [sys].[dm_exec_requests] [r] WITH (NOLOCK) ON [r].[external_script_request_id]=[er].[external_script_request_id]
LEFT JOIN [sys].[dm_exec_sessions] [s] WITH (NOLOCK) ON [s].[session_id]=[r].[session_id]
LEFT JOIN [sys].[databases] [d] WITH (NOLOCK) ON [d].[database_id]=COALESCE([r].[database_id],[s].[database_id])
WHERE 1=1 '+@RuntimeLanguagePredicate+N'
  AND (COALESCE([r].[database_id],[s].[database_id]) IS NULL
       OR EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_DatabaseCandidates] [c]
                 WHERE [c].[DatabaseId]=COALESCE([r].[database_id],[s].[database_id]))); SET @pRows=@@ROWCOUNT;';
                SET @Rows=0;
                EXEC [sys].[sp_executesql] @Sql,
                     N'@pPattern nvarchar(4000),@pRegexFlags varchar(8),@pRows bigint OUTPUT',
                     @pPattern=@LanguagePatternValue,@pRegexFlags=@LanguageRegexFlags,@pRows=@Rows OUTPUT;
                INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                VALUES(NULL,'ACTIVE_EXTERNAL_REQUESTS','AVAILABLE',0,@Rows,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Dokumentierter Join über external_script_request_id; keine Script- oder Batchtexte.');
            END TRY
            BEGIN CATCH
                INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                VALUES(NULL,'ACTIVE_EXTERNAL_REQUESTS',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER() IN(207,208) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Aktive Requests isoliert fehlgeschlagen.');
            END CATCH;

            SET @MeasurementStartUtc=SYSUTCDATETIME();
            BEGIN TRY
                INSERT [#ExternalRuntimeAnalysis_PoolSamples]
                SELECT 'T1',SYSUTCDATETIME(),[external_pool_id],[name],[pool_version],[max_cpu_percent],[max_processes],[max_memory_percent],
                       [statistics_start_time],[peak_memory_kb],[write_io_count],[read_io_count],[total_cpu_kernel_ms],[total_cpu_user_ms],[active_processes_count]
                FROM [sys].[dm_resource_governor_external_resource_pools] WITH (NOLOCK);
                INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                VALUES(NULL,'EXTERNAL_POOLS_T1','AVAILABLE',0,@@ROWCOUNT,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Kumulative Poolwerte; Linux-Einheiten benötigen die dokumentierte Plattformgegenprüfung.');
            END TRY
            BEGIN CATCH
                INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                VALUES(NULL,'EXTERNAL_POOLS_T1',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER() IN(207,208) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Poolquelle isoliert fehlgeschlagen.');
            END CATCH;

            BEGIN TRY
                SET @Sql=N'INSERT [#ExternalRuntimeAnalysis_ExecutionStatSamples]
SELECT ''T1'',SYSUTCDATETIME(),[es].[language],[es].[counter_name],CONVERT(bigint,[es].[counter_value])
FROM [sys].[dm_external_script_execution_stats] [es] WITH (NOLOCK)
WHERE 1=1 '+@StatsLanguagePredicate+N'; SET @pRows=@@ROWCOUNT;';
                SET @Rows=0;
                EXEC [sys].[sp_executesql] @Sql,N'@pPattern nvarchar(4000),@pRegexFlags varchar(8),@pRows bigint OUTPUT',
                     @pPattern=@LanguagePatternValue,@pRegexFlags=@LanguageRegexFlags,@pRows=@Rows OUTPUT;
                INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                VALUES(NULL,'EXECUTION_STATS_T1','AVAILABLE',0,@Rows,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Featuretelemetrie registrierter Funktionen; keine allgemeine Script-Ausführungshistorie.');
            END TRY
            BEGIN CATCH
                INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                VALUES(NULL,'EXECUTION_STATS_T1',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER() IN(207,208) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Execution-Stats-Quelle isoliert fehlgeschlagen.');
            END CATCH;

            BEGIN TRY
                INSERT [#ExternalRuntimeAnalysis_CounterSamples]
                SELECT 'T1',SYSUTCDATETIME(),[counter_name],[instance_name],[cntr_type],[cntr_value]
                FROM [sys].[dm_os_performance_counters] WITH (NOLOCK)
                WHERE [object_name] LIKE N'%External Scripts%';
                INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                VALUES(NULL,'EXTERNAL_COUNTERS_T1','AVAILABLE',0,@@ROWCOUNT,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Originale SQL-Server-Counterwerte; cntr_type steuert die Interpretation.');
            END TRY
            BEGIN CATCH
                INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                VALUES(NULL,'EXTERNAL_COUNTERS_T1',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Performance-Counter-Quelle isoliert fehlgeschlagen.');
            END CATCH;

            IF @SampleSeconds>0
            BEGIN
                DECLARE @Delay char(8)=CONVERT(char(8),DATEADD(SECOND,@SampleSeconds,CONVERT(datetime,'19000101',112)),108);
                WAITFOR DELAY @Delay;

                BEGIN TRY
                    INSERT [#ExternalRuntimeAnalysis_PoolSamples]
                    SELECT 'T2',SYSUTCDATETIME(),[external_pool_id],[name],[pool_version],[max_cpu_percent],[max_processes],[max_memory_percent],
                           [statistics_start_time],[peak_memory_kb],[write_io_count],[read_io_count],[total_cpu_kernel_ms],[total_cpu_user_ms],[active_processes_count]
                    FROM [sys].[dm_resource_governor_external_resource_pools] WITH (NOLOCK);
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(NULL,'EXTERNAL_POOLS_T2','AVAILABLE',0,@@ROWCOUNT,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Zweiter Messpunkt desselben Samplefensters.');
                END TRY
                BEGIN CATCH
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(NULL,'EXTERNAL_POOLS_T2',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER() IN(207,208) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Zweiter Poolmesspunkt isoliert fehlgeschlagen.');
                END CATCH;

                BEGIN TRY
                    SET @Sql=N'INSERT [#ExternalRuntimeAnalysis_ExecutionStatSamples]
SELECT ''T2'',SYSUTCDATETIME(),[es].[language],[es].[counter_name],CONVERT(bigint,[es].[counter_value])
FROM [sys].[dm_external_script_execution_stats] [es] WITH (NOLOCK)
WHERE 1=1 '+@StatsLanguagePredicate+N'; SET @pRows=@@ROWCOUNT;';
                    SET @Rows=0;
                    EXEC [sys].[sp_executesql] @Sql,N'@pPattern nvarchar(4000),@pRegexFlags varchar(8),@pRows bigint OUTPUT',
                         @pPattern=@LanguagePatternValue,@pRegexFlags=@LanguageRegexFlags,@pRows=@Rows OUTPUT;
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(NULL,'EXECUTION_STATS_T2','AVAILABLE',0,@Rows,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Zweiter Messpunkt der persistenten Featuretelemetrie.');
                END TRY
                BEGIN CATCH
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(NULL,'EXECUTION_STATS_T2',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER() IN(207,208) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Zweiter Execution-Stats-Messpunkt isoliert fehlgeschlagen.');
                END CATCH;

                BEGIN TRY
                    INSERT [#ExternalRuntimeAnalysis_CounterSamples]
                    SELECT 'T2',SYSUTCDATETIME(),[counter_name],[instance_name],[cntr_type],[cntr_value]
                    FROM [sys].[dm_os_performance_counters] WITH (NOLOCK)
                    WHERE [object_name] LIKE N'%External Scripts%';
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(NULL,'EXTERNAL_COUNTERS_T2','AVAILABLE',0,@@ROWCOUNT,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Zweiter Messpunkt desselben Samplefensters.');
                END TRY
                BEGIN CATCH
                    INSERT [#ExternalRuntimeAnalysis_SourceStatus]
                    VALUES(NULL,'EXTERNAL_COUNTERS_T2',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Zweiter Countermesspunkt isoliert fehlgeschlagen.');
                END CATCH;
            END;
            SET @MeasurementEndUtc=SYSUTCDATETIME();
        END;

        INSERT [#ExternalRuntimeAnalysis_ExternalPools]
        SELECT [a].[ExternalPoolId],[a].[PoolName],COALESCE([b].[MaxCpuPercent],[a].[MaxCpuPercent]),
               COALESCE([b].[MaxProcesses],[a].[MaxProcesses]),COALESCE([b].[MaxMemoryPercent],[a].[MaxMemoryPercent]),
               COALESCE([b].[StatisticsStartTime],[a].[StatisticsStartTime]),COALESCE([b].[PeakMemoryKb],[a].[PeakMemoryKb]),
               COALESCE([b].[ActiveProcessesCount],[a].[ActiveProcessesCount]),
               CONVERT(decimal(19,6),CASE WHEN @SampleSeconds>0 THEN DATEDIFF_BIG(MICROSECOND,[a].[ReadAtUtc],[b].[ReadAtUtc])/1000000.0 END),
               CASE WHEN [b].[ExternalPoolId] IS NOT NULL AND [a].[StatisticsStartTime]=[b].[StatisticsStartTime]
                          AND [a].[PoolVersion]=[b].[PoolVersion] AND [b].[TotalCpuKernelMs]>=[a].[TotalCpuKernelMs]
                    THEN [b].[TotalCpuKernelMs]-[a].[TotalCpuKernelMs] END,
               CASE WHEN [b].[ExternalPoolId] IS NOT NULL AND [a].[StatisticsStartTime]=[b].[StatisticsStartTime]
                          AND [a].[PoolVersion]=[b].[PoolVersion] AND [b].[TotalCpuUserMs]>=[a].[TotalCpuUserMs]
                    THEN [b].[TotalCpuUserMs]-[a].[TotalCpuUserMs] END,
               CASE WHEN [b].[ExternalPoolId] IS NOT NULL AND [a].[StatisticsStartTime]=[b].[StatisticsStartTime]
                          AND [a].[PoolVersion]=[b].[PoolVersion] AND [b].[ReadIoCount]>=[a].[ReadIoCount]
                    THEN [b].[ReadIoCount]-[a].[ReadIoCount] END,
               CASE WHEN [b].[ExternalPoolId] IS NOT NULL AND [a].[StatisticsStartTime]=[b].[StatisticsStartTime]
                          AND [a].[PoolVersion]=[b].[PoolVersion] AND [b].[WriteIoCount]>=[a].[WriteIoCount]
                    THEN [b].[WriteIoCount]-[a].[WriteIoCount] END,
               CASE WHEN @SampleSeconds=0 THEN 'NOT_SAMPLED'
                    WHEN [b].[ExternalPoolId] IS NULL THEN 'T2_UNAVAILABLE'
                    WHEN [a].[StatisticsStartTime]<>[b].[StatisticsStartTime] OR [a].[PoolVersion]<>[b].[PoolVersion] THEN 'RESET_BOUNDARY'
                    WHEN [b].[TotalCpuKernelMs]<[a].[TotalCpuKernelMs] OR [b].[TotalCpuUserMs]<[a].[TotalCpuUserMs]
                      OR [b].[ReadIoCount]<[a].[ReadIoCount] OR [b].[WriteIoCount]<[a].[WriteIoCount] THEN 'RESET_BOUNDARY'
                    ELSE 'DELTA_AVAILABLE' END,
               CASE WHEN UPPER(COALESCE(@HostPlatform,N''))='LINUX'
                    THEN N'Linux bezieht Poolwerte aus cgroups; die herstellerdokumentierte Einheitenabweichung ist vor plattformübergreifenden Vergleichen zu berücksichtigen.'
                    ELSE N'Kumulative Poolwerte gelten seit statistics_start_time; Deltas werden nur innerhalb derselben Resetepoche berechnet.' END
        FROM [#ExternalRuntimeAnalysis_PoolSamples] [a]
        LEFT JOIN [#ExternalRuntimeAnalysis_PoolSamples] [b]
          ON [b].[SamplePoint]='T2' AND [b].[ExternalPoolId]=[a].[ExternalPoolId]
        WHERE [a].[SamplePoint]='T1';

        INSERT [#ExternalRuntimeAnalysis_ExecutionStats]
        SELECT [a].[LanguageName],[a].[CounterName],COALESCE([b].[CounterValue],[a].[CounterValue]),
               CASE WHEN [b].[CounterValue]>=[a].[CounterValue] THEN [b].[CounterValue]-[a].[CounterValue] END,
               CASE WHEN @SampleSeconds=0 THEN 'NOT_SAMPLED' WHEN [b].[CounterName] IS NULL THEN 'T2_UNAVAILABLE'
                    WHEN [b].[CounterValue]<[a].[CounterValue] THEN 'RESET_BOUNDARY' ELSE 'DELTA_AVAILABLE' END,
               N'Die Werte erfassen registrierte Featurefunktionen und sind keine vollständige Historie beliebiger Scripts oder Packages.'
        FROM [#ExternalRuntimeAnalysis_ExecutionStatSamples] [a]
        LEFT JOIN [#ExternalRuntimeAnalysis_ExecutionStatSamples] [b]
          ON [b].[SamplePoint]='T2' AND [b].[LanguageName]=[a].[LanguageName] AND [b].[CounterName]=[a].[CounterName]
        WHERE [a].[SamplePoint]='T1';

        INSERT [#ExternalRuntimeAnalysis_PerformanceCounters]
        SELECT [a].[CounterName],[a].[InstanceName],[a].[CounterType],COALESCE([b].[CounterValue],[a].[CounterValue]),
               CASE WHEN @SampleSeconds>0 AND [b].[CounterValue]>=[a].[CounterValue]
                    THEN [b].[CounterValue]-[a].[CounterValue] END,
               CASE WHEN @SampleSeconds=0 THEN 'NOT_SAMPLED'
                    WHEN [b].[CounterName] IS NULL THEN 'T2_UNAVAILABLE'
                    WHEN [b].[CounterValue]<[a].[CounterValue] THEN 'RESET_BOUNDARY'
                    ELSE 'DELTA_AVAILABLE' END,
               [i].[Interpretation],[i].[MetricValue],[i].[MetricUnit],[i].[FindingCode],
               N'Counterinterpretation basiert auf cntr_type; bei fehlendem zweiten Messpunkt bleibt eine Deltaaussage aus.'
        FROM [#ExternalRuntimeAnalysis_CounterSamples] [a]
        LEFT JOIN [#ExternalRuntimeAnalysis_CounterSamples] [b]
          ON [b].[SamplePoint]='T2' AND [b].[CounterName]=[a].[CounterName]
         AND [b].[InstanceName]=[a].[InstanceName] AND [b].[CounterType]=[a].[CounterType]
        CROSS APPLY [monitor].[TVF_InterpretPerformanceCounter]
        (
              [a].[CounterType],[a].[CounterValue],COALESCE([b].[CounterValue],[a].[CounterValue])
            , NULL,NULL
            , CONVERT(decimal(19,6),CASE WHEN @SampleSeconds>0 THEN DATEDIFF_BIG(MICROSECOND,[a].[ReadAtUtc],[b].[ReadAtUtc])/1000000.0 ELSE 0 END)
        ) [i]
        WHERE [a].[SamplePoint]='T1';

        INSERT [#ExternalRuntimeAnalysis_FindingsCollected]
        ([DatabaseName],[ObjectType],[ObjectName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
        SELECT NULL,'SERVER_CONFIGURATION',NULL,'WARN','HIGH','EXTERNAL_SCRIPTS_ENABLED_WITHOUT_INSTALLED_FEATURE_EVIDENCE',
               'IsAdvancedAnalyticsInstalled',[IsAdvancedAnalyticsInstalled],1,
               N'external scripts enabled ist aktiv, SERVERPROPERTY(IsAdvancedAnalyticsInstalled) liefert jedoch nicht 1.',
               N'Die Property beweist keine konkrete Runtimeinstallation; der Widerspruch ist eine Konfigurationsprüfung.',
               N'Installationsumfang und Launchpad-Konfiguration auf dem Host getrennt prüfen.'
        FROM [#ExternalRuntimeAnalysis_Configuration]
        WHERE [ExternalScriptsValueInUse]=1 AND COALESCE([IsAdvancedAnalyticsInstalled],0)<>1;

        INSERT [#ExternalRuntimeAnalysis_FindingsCollected]
        SELECT NULL,'LAUNCHPAD',NULL,'WARN','HIGH','LAUNCHPAD_NOT_RUNNING',
               'LaunchpadRunningCount',[LaunchpadRunningCount],[LaunchpadServiceCount],
               N'External Scripts ist aktiv, aber keine sichtbare Launchpad-Servicezeile ist im Status Running.',
               N'Der Befund setzt eine erfolgreich gelesene Servicequelle voraus; er führt keinen Starttest aus.',
               N'Servicezustand, Event Log und externe Extensibility Logs auf dem Host prüfen.'
        FROM [#ExternalRuntimeAnalysis_Configuration]
        WHERE [ExternalScriptsValueInUse]=1 AND [LaunchpadStatus] IN('NOT_VISIBLE','STOPPED','PARTIALLY_RUNNING');

        INSERT [#ExternalRuntimeAnalysis_FindingsCollected]
        SELECT [x].[DatabaseName],'DATABASE_REGISTRATION',NULL,'WARN','HIGH','REGISTERED_RUNTIME_WHILE_EXTERNAL_SCRIPTS_DISABLED',
               'RegisteredObjectCount',[x].[RegisteredObjectCount],1,
               N'Mindestens eine External Language oder Library ist sichtbar, während external scripts enabled nicht aktiv ist.',
               N'Registrierung beweist keine frühere oder aktuelle erfolgreiche Ausführung.',
               N'Prüfen, ob die Deaktivierung beabsichtigt ist und ob die registrierten Objekte noch benötigt werden.'
        FROM
        (
            SELECT [r].[DatabaseName],COUNT_BIG(*) AS [RegisteredObjectCount]
            FROM
            (
                SELECT DISTINCT [DatabaseName],'LANGUAGE' AS [ObjectType],[ExternalLanguageId] AS [ObjectId]
                FROM [#ExternalRuntimeAnalysis_Languages]
                UNION ALL
                SELECT DISTINCT [DatabaseName],'LIBRARY',[ExternalLibraryId]
                FROM [#ExternalRuntimeAnalysis_Libraries]
            ) [r]
            GROUP BY [r].[DatabaseName]
        ) [x]
        CROSS JOIN [#ExternalRuntimeAnalysis_Configuration] [c]
        WHERE COALESCE([c].[ExternalScriptsValueInUse],0)=0;

        INSERT [#ExternalRuntimeAnalysis_FindingsCollected]
        SELECT [DatabaseName],'EXTERNAL_LANGUAGE',[LanguageName],'WARN','HIGH','LANGUAGE_FILE_PLATFORM_MISMATCH',
               'PlatformMismatch',1,0,
               CONCAT(N'Die registrierte Dateiplattform ',[FilePlatformDesc],N' stimmt nicht mit HostPlatform ',COALESCE(@HostPlatform,N'<unbekannt>'),N' überein.'),
               N'Nur die registrierte Plattformmetadatenzeile wird verglichen; Binärinhalt und reale Ladefähigkeit bleiben ungeprüft.',
               N'Language-Extension-Paket und plattformspezifische Registrierung prüfen.'
        FROM [#ExternalRuntimeAnalysis_Languages]
        WHERE [FileMetadataStatus]='AVAILABLE' AND [FilePlatformDesc] IS NOT NULL
          AND UPPER([FilePlatformDesc])<>UPPER(COALESCE(@HostPlatform,N''));

        INSERT [#ExternalRuntimeAnalysis_FindingsCollected]
        SELECT [DatabaseName],'ACTIVE_REQUEST',CONVERT(nvarchar(36),[ExternalScriptRequestId]),'WARN','HIGH','ACTIVE_EXTERNAL_REQUEST_BLOCKED',
               'BlockingSessionId',[BlockingSessionId],0,
               CONCAT(N'Der aktive External-Script-Request ist durch Session ',CONVERT(nvarchar(20),[BlockingSessionId]),N' geblockt.'),
               N'Momentaufnahme; der Blockingzustand kann unmittelbar wechseln.',
               N'USP_CurrentBlocking für die vollständige Blockerkette ausführen.'
        FROM [#ExternalRuntimeAnalysis_ActiveRequests]
        WHERE COALESCE([BlockingSessionId],0)>0;

        INSERT [#ExternalRuntimeAnalysis_FindingsCollected]
        SELECT NULL,'EXTERNAL_POOL',[PoolName],'WARN','HIGH','EXTERNAL_POOL_PROCESS_LIMIT_REACHED',
               'ActiveProcessesCount',[ActiveProcessesCount],[MaxProcesses],
               N'Die aktive Prozesszahl erreicht oder überschreitet das konfigurierte, von null verschiedene max_processes.',
               N'Ein einzelner Messpunkt beweist keine anhaltende Sättigung; max_processes=0 bedeutet unbegrenzt.',
               N'Wiederholt messen und Warteschlangen, Laufzeiten sowie Resource-Governor-Zuordnung prüfen.'
        FROM [#ExternalRuntimeAnalysis_ExternalPools]
        WHERE COALESCE([MaxProcesses],0)>0 AND [ActiveProcessesCount]>=[MaxProcesses];

        INSERT [#ExternalRuntimeAnalysis_FindingsCollected]
        SELECT NULL,'PERFORMANCE_COUNTER',[CounterName],'WARN','HIGH','EXTERNAL_SCRIPT_EXECUTION_ERRORS_IN_SAMPLE',
               'CounterDelta',[CounterDelta],0,
               N'Der Counter Execution Errors ist im gültigen Samplefenster gestiegen.',
               N'Der Counter schließt laut Herstellerdokumentation nicht alle R- oder Python-Fehler ein und enthält keine Fehlerursache.',
               N'Errorlog, vorhandene Extended Events und externe Launchpad-Logs im gleichen Zeitfenster prüfen.'
        FROM [#ExternalRuntimeAnalysis_PerformanceCounters]
        WHERE [CounterName]=N'Execution Errors' AND [CounterDelta]>0
          AND [DeltaStatus]='DELTA_AVAILABLE';

        INSERT [#ExternalRuntimeAnalysis_FindingsCollected]
        SELECT [DatabaseName],'EXTERNAL_LANGUAGE',[LanguageName],'INFO','MEDIUM','REGISTERED_RUNTIME_STARTABILITY_UNVERIFIED',
               NULL,NULL,NULL,
               N'Die Language Extension ist im Datenbankkatalog registriert.',
               N'Die Analyse führt keinen externen Code aus; Installation, Abhängigkeiten und Startfähigkeit bleiben daher unverifiziert.',
               N'Installations- und Betriebsnachweise der konkreten Runtime außerhalb dieses T-SQL-Moduls prüfen.'
        FROM [#ExternalRuntimeAnalysis_Languages]
        WHERE [FileName] IS NULL OR [FileMetadataStatus]<>'AVAILABLE';

        IF UPPER(COALESCE(@HostPlatform,N''))='LINUX'
            INSERT [#ExternalRuntimeAnalysis_Warnings]
            VALUES('LINUX_EXTERNAL_POOL_UNIT_CONTRACT',N'External-Pool-Statistiken werden auf Linux aus cgroups bezogen; dokumentierte Einheitenabweichungen verhindern ungeprüfte plattformübergreifende Vergleiche.',N'Rohwerte und Deltas bleiben sichtbar, werden aber nicht pauschal als KB-, I/O- oder Millisekunden-SLA klassifiziert.');
        INSERT [#ExternalRuntimeAnalysis_Warnings]
        VALUES('EXECUTION_STATS_SCOPE',N'sys.dm_external_script_execution_stats erfasst registrierte Featurefunktionen und keine allgemeine Historie beliebiger Scripts.',N'Ein fehlender Zähler beweist weder fehlende Runtimeaktivität noch fehlerfreie Ausführung.');

        UPDATE [ds]
        SET [SourceFailureCount]=(SELECT COUNT(*) FROM [#ExternalRuntimeAnalysis_SourceStatus] [ss] WHERE [ss].[DatabaseName]=[ds].[DatabaseName] AND [ss].[IsPartial]=1),
            [IsPartial]=CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_SourceStatus] [ss] WHERE [ss].[DatabaseName]=[ds].[DatabaseName] AND [ss].[IsPartial]=1) THEN 1 ELSE 0 END),
            [StatusCode]=CASE WHEN EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_SourceStatus] [ss] WHERE [ss].[DatabaseName]=[ds].[DatabaseName] AND [ss].[IsPartial]=1) THEN 'AVAILABLE_LIMITED'
                              WHEN [LanguageCount]+[LibraryCount]=0 THEN 'NOT_APPLICABLE_VISIBLE_SCOPE' ELSE 'AVAILABLE' END
        FROM [#ExternalRuntimeAnalysis_DatabaseStatus] [ds]
        WHERE [StatusCode]='PENDING';

        IF @StatusCode='AVAILABLE'
        BEGIN
            IF EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_SourceStatus] WHERE [IsPartial]=1)
               OR EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_DatabaseStatus] WHERE [IsPartial]=1)
               OR EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_DatabaseCandidateWarnings])
                SELECT @StatusCode='AVAILABLE_LIMITED',@IsPartial=1;
            ELSE IF EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_FindingsCollected] WHERE [Severity]='WARN')
                SET @StatusCode='AVAILABLE_WITH_FINDING';
            ELSE IF EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_Configuration] WHERE COALESCE([ExternalScriptsValueInUse],0)=0)
                SET @StatusCode=CASE WHEN EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_Languages]) OR EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_Libraries]) OR EXISTS(SELECT 1 FROM [#ExternalRuntimeAnalysis_ExecutionStats]) THEN 'FEATURE_DISABLED' ELSE 'NOT_APPLICABLE' END;
        END;

        SELECT @ErrorNumber=COALESCE(@ErrorNumber,MIN([ErrorNumber])),@ErrorMessage=COALESCE(@ErrorMessage,MIN([ErrorMessage]))
        FROM [#ExternalRuntimeAnalysis_SourceStatus] WHERE [IsPartial]=1;

        IF @MaxZeilen>0 AND
           (
               (SELECT COUNT_BIG(*) FROM [#ExternalRuntimeAnalysis_FindingsCollected] WHERE @NurProblematisch=0 OR [Severity]='WARN')>@Limit
            OR (SELECT COUNT_BIG(*) FROM [#ExternalRuntimeAnalysis_Languages])>@Limit
            OR (SELECT COUNT_BIG(*) FROM [#ExternalRuntimeAnalysis_Libraries])>@Limit
            OR (SELECT COUNT_BIG(*) FROM [#ExternalRuntimeAnalysis_ActiveRequests])>@Limit
            OR (SELECT COUNT_BIG(*) FROM [#ExternalRuntimeAnalysis_ExecutionStats])>@Limit
            OR (SELECT COUNT_BIG(*) FROM [#ExternalRuntimeAnalysis_PerformanceCounters])>@Limit
           )
        BEGIN
            INSERT [#ExternalRuntimeAnalysis_Warnings]
            VALUES('RESULTSET_TRUNCATED',N'Mindestens ein fachliches Resultset enthält mehr Zeilen als @MaxZeilen und wird erst nach globaler Sortierung begrenzt.',N'@MaxZeilen=0 liefert alle materialisierten Zeilen.');
            IF @PrintMeldungen=1 RAISERROR(N'RESULTSET_TRUNCATED: Verwenden Sie @MaxZeilen=0 oder einen höheren Wert für die vollständige Ausgabe.',10,1) WITH NOWAIT;
        END;

        /* Status und Truncation bewerten die volle Sammlung; alle Ausgaben teilen diese Auswahl. */
        INSERT [#ExternalRuntimeAnalysis_Findings]
        SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_FindingsCollected]
        WHERE @NurProblematisch=0 OR [Severity]='WARN'
        ORDER BY CASE [Severity] WHEN 'WARN' THEN 1 ELSE 2 END,[FindingOrdinal];

        IF @JsonErzeugen=1
        BEGIN
            SELECT @Json=(
                SELECT
                    JSON_QUERY((SELECT N'USP_ExternalRuntimeAnalysis' AS [module],@Now AS [collectedAtUtc],@MeasurementStartUtc AS [measurementStartUtc],@MeasurementEndUtc AS [measurementEndUtc],@StatusCode AS [statusCode],@IsPartial AS [isPartial],@ErrorNumber AS [errorNumber],@ErrorMessage AS [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) AS [meta],
                    JSON_QUERY(COALESCE((SELECT * FROM [#ExternalRuntimeAnalysis_Configuration] FOR JSON PATH),N'[]')) AS [configuration],
                    JSON_QUERY(COALESCE((SELECT * FROM [#ExternalRuntimeAnalysis_DatabaseStatus] ORDER BY [DatabaseName] FOR JSON PATH),N'[]')) AS [databaseStatus],
                    JSON_QUERY(COALESCE((SELECT * FROM [#ExternalRuntimeAnalysis_SourceStatus] ORDER BY [DatabaseName],[SourceCode],[ReadAtUtc] FOR JSON PATH),N'[]')) AS [sourceStatus],
                    JSON_QUERY(COALESCE((SELECT * FROM [#ExternalRuntimeAnalysis_Findings] ORDER BY CASE [Severity] WHEN 'WARN' THEN 1 ELSE 2 END,[FindingOrdinal] FOR JSON PATH),N'[]')) AS [findings],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_Languages] ORDER BY [DatabaseName],[LanguageName],[FileName] FOR JSON PATH),N'[]')) AS [languages],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_Libraries] ORDER BY [DatabaseName],[LanguageName],[LibraryName] FOR JSON PATH),N'[]')) AS [libraries],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_ActiveRequests] ORDER BY [WaitTimeMs] DESC,[SessionId] FOR JSON PATH),N'[]')) AS [activeRequests],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_ExternalPools] ORDER BY [ActiveProcessesCount] DESC,[PoolName] FOR JSON PATH),N'[]')) AS [externalPools],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_ExecutionStats] ORDER BY [LanguageName],[CounterName] FOR JSON PATH),N'[]')) AS [executionStats],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_PerformanceCounters] ORDER BY [CounterName],[InstanceName] FOR JSON PATH),N'[]')) AS [performanceCounters],
                    JSON_QUERY(COALESCE((SELECT * FROM [#ExternalRuntimeAnalysis_Warnings] ORDER BY [WarningCode] FOR JSON PATH),N'[]')) AS [warnings]
                FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
        END;

        IF @OutputMode='RAW'
        BEGIN
            SELECT N'USP_ExternalRuntimeAnalysis' AS [Module],@Now AS [CollectedAtUtc],@MeasurementStartUtc AS [MeasurementStartUtc],@MeasurementEndUtc AS [MeasurementEndUtc],@StatusCode AS [StatusCode],@IsPartial AS [IsPartial],@ErrorNumber AS [ErrorNumber],@ErrorMessage AS [ErrorMessage],N'Read-only External-Runtime-Evidenz; keine Scripttexte, Parameter, Environment Variables, Binärinhalte oder Testausführung.' AS [EvidenceLimit];
            SELECT * FROM [#ExternalRuntimeAnalysis_Configuration];
            SELECT * FROM [#ExternalRuntimeAnalysis_DatabaseStatus] ORDER BY [DatabaseName];
            SELECT * FROM [#ExternalRuntimeAnalysis_SourceStatus] ORDER BY [DatabaseName],[SourceCode],[ReadAtUtc];
            SELECT * FROM [#ExternalRuntimeAnalysis_Findings] ORDER BY CASE [Severity] WHEN 'WARN' THEN 1 ELSE 2 END,[FindingOrdinal];
            SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_Languages] ORDER BY [DatabaseName],[LanguageName],[FileName];
            SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_Libraries] ORDER BY [DatabaseName],[LanguageName],[LibraryName];
            SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_ActiveRequests] ORDER BY [WaitTimeMs] DESC,[SessionId];
            SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_ExternalPools] ORDER BY [ActiveProcessesCount] DESC,[PoolName];
            SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_ExecutionStats] ORDER BY [LanguageName],[CounterName];
            SELECT TOP(@Limit) * FROM [#ExternalRuntimeAnalysis_PerformanceCounters] ORDER BY [CounterName],[InstanceName];
            SELECT * FROM [#ExternalRuntimeAnalysis_Warnings] ORDER BY [WarningCode];
        END;
    END TRY
    BEGIN CATCH
        SELECT @StatusCode=CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' ELSE 'ERROR_HANDLED' END,
               @IsPartial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
    END CATCH;

    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @LockTimeoutSql;

    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE','NOT_APPLICABLE')
    BEGIN
        SET @PrintMessage=LEFT(CONCAT(N'USP_ExternalRuntimeAnalysis: ',@StatusCode,N'. ',COALESCE(@ErrorMessage,N'Siehe strukturierte Quellenstatus.')),2048);
        RAISERROR(N'%s',10,1,@PrintMessage) WITH NOWAIT;
    END;

    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
    IF @ConsoleResultRequested=1
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ExternalRuntimeAnalysis_Findings'
            , @ResultLabel=N'ExternalRuntimeAnalysis'
            , @EmptyMessage=N'Keine External-Runtime-Findings im gewählten Scope';
    IF @TableResultRequested=1
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable=N'#ExternalRuntimeAnalysis_Findings'
            , @TargetTable=@TableTarget
            , @ThrowOnError=1;
END;
GO

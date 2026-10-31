USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ServerConfiguration
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Die Procedure liest Serverkonfigurationswerte und ergänzt
               kontextabhängige Reviewhinweise als aktuellen Katalogsnapshot.
Datenquellen : sys.configurations, sys.dm_os_sys_info
Vertrag      : Resultset 1 ist immer Modulstatus; @ResultSetArt=NONE unterdrückt Resultsets; RAW und CONSOLE liefern unterschiedliche Projektionen. Optional JSON.
===============================================================================
*/

CREATE OR ALTER PROCEDURE [monitor].[USP_ServerConfiguration]
 @NurKernparameter bit=1,@PrintMeldungen bit=1,@Hilfe bit=0,@ResultSetArt varchar(16)='CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen bit=0,@Json nvarchar(max)=NULL OUTPUT,
 @StatusCodeOut varchar(40)=NULL OUTPUT,@IsPartialOut bit=NULL OUTPUT,@ErrorNumberOut int=NULL OUTPUT,@ErrorMessageOut nvarchar(2048)=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON;SET @Json=NULL;DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'configuration',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';IF @Hilfe=1 BEGIN PRINT N'monitor.USP_ServerConfiguration';
        PRINT N'Die Procedure USP_ServerConfiguration erstellt einen read-only Snapshot; die Quellansichten sind zeitlich nicht atomar.';
        PRINT N'Parameterformen und Defaults: @PrintMeldungen bit=1, @Hilfe bit=0, @ResultSetArt varchar(16)=CONSOLE (CONSOLE, RAW, TABLE, NONE; trimmen und Großschreibung normalisieren).';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL ist nur für TABLE nötig; zuvor eine leere lokale #temp-Tabelle mit einer Seed-Spalte anlegen. Bei Nicht-TABLE sind nur NULL oder leer zulässig.';
        PRINT N'@JsonErzeugen bit=0 erzeugt bei 1 unabhängig von der ResultSetArt ein JSON-Dokument in @Json nvarchar(max)=NULL OUTPUT.';
        PRINT N'AVAILABLE bei erfolgreicher Erhebung; INVALID_PARAMETER bei ungültigem ResultSetArt; DENIED_PERMISSION für Fehlernummern 229, 297, 300 oder 371; TIMEOUT bei 1222; sonst ERROR_HANDLED. Jeder abgefangene Quellfehler setzt IsPartial=1 sowie ErrorNumber/ErrorMessage. Statusoutputs werden nach dem TRY/CATCH gesetzt.';
        PRINT N'Die Procedure liefert konfigurierte und aktive Serverwerte samt kontextabhängigen Reviewhinweisen. Der Default liest eine fest kuratierte Konfigurationsliste; 0 liest alle sys.configurations-Einträge. JSON enthält meta, configuration und warnings; TABLE registriert configuration.';
        PRINT N'Quellen: sys.configurations sowie sys.dm_os_sys_info.scheduler_count als Kontext für MAXDOP.. Es gibt kein Zeilenlimit. Ausgabeunterdrückung verhindert die Quellabfrage nicht.';
        PRINT N'@Hilfe=1 beendet nach einem gegebenenfalls erforderlichen TABLE-Preflight vor der Datenerhebung; dabei bleibt @Json auf NULL, während die übrigen OUTPUT-Parameter nicht neu zugewiesen werden.';
        PRINT N'@NurKernparameter bit; Default: 1. Eingabeform: SQL-bit; 0 bedeutet der Filterausdruck wählt alle sys.configurations-Zeilen, weil `@NurKernparameter=0` wahr ist, 1 bedeutet der IN-Filter wählt nur die folgende kuratierte Liste: max degree of parallelism; cost threshold for parallelism; max server memory (MB); min server memory (MB); optimize for ad hoc workloads; backup compression default; remote admin connections; contained database authentication; clr enabled; clr strict security; xp_cmdshell; Ole Automation Procedures; external scripts enabled; blocked process threshold (s); query wait (s); affinity mask; affinity64 mask. NULL wirkt ebenfalls wie die Kernliste: für diese Namen ist die IN-Bedingung wahr, für andere bleibt `NULL=0 OR false` unbekannt und die Zeile wird herausgefiltert.. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default.';
        PRINT N'@PrintMeldungen bit; Default: 1. Eingabeform: SQL-bit; 0 bedeutet unterdrückt die Informationsmeldung bei einem Nicht-AVAILABLE-Status, 1 bedeutet gibt eine Severity-10-Meldung mit Modulname und Fehlertext aus. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default.';
        PRINT N'@Hilfe bit; Default: 0. Eingabeform: SQL-bit; 0 bedeutet führt die Erhebung ohne Hilfetext fort, 1 bedeutet druckt Hilfe und beendet die Procedure vor Erhebung und Statusoutputs. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Eingabeform: ein einzelner Code CONSOLE, RAW, TABLE oder NONE; führende/abschließende Leerzeichen werden entfernt und Groß-/Kleinschreibung wird mit UPPER vereinheitlicht. NULL wird durch COALESCE zu leerem Text, ein leerer oder nur aus Leerzeichen bestehender Wert bleibt leer; alle drei Fälle sind ungültig. Nur die vier genannten Werte sind gültig. CONSOLE und TABLE wählen ihre Fachprojektion und setzen den internen Modus anschließend auf NONE, damit kein generisches Fachresultset zusätzlich ausgegeben wird; RAW liefert rohe Fachresultsets, NONE unterdrückt Resultsets. Ungültige Codes (einschließlich NULL/leer) setzen INVALID_PARAMETER und IsPartial=1; intern werden wegen des nicht-NONE-Modus Status und die nicht-RAW-Fachprojektion ausgegeben. Bei TABLE erfolgt zuerst der Ziel-Preflight; sein Fehler wird geworfen. JSON-Erzeugung ist unabhängig vom ResultSetArt.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Eingabeform: ein gültiges JSON-Objekt mit genau einer Eigenschaft, deren Name exakt configuration lautet und deren Stringwert eine vorhandene lokale #temp-Tabelle bezeichnet. Das Ziel muss vor dem Aufruf existieren, leer sein und genau eine Seed-/Platzhalterspalte besitzen; globale ##-Tabellen, permanente Tabellen, Namen mit reserviertem Präfix #Monitor und Namen über 116 Zeichen sind unzulässig. Der Helper ergänzt das Ausgabeschema. Nur bei ResultSetArt=TABLE erforderlich. Außerhalb TABLE werden NULL, leerer oder nur aus Leerzeichen bestehender Inhalt akzeptiert; nichtleerer Inhalt wirft Fehler 51011. Bei TABLE validiert der Preflight JSON und Ziel und wirft bei ungültiger oder fehlender Angabe Fehler 51011; Status-OUTPUT-Parameter werden dann nicht zugewiesen.';
        PRINT N'@JsonErzeugen bit; Default: 0. Eingabeform: SQL-bit; 0 bedeutet lässt @Json nach dem anfänglichen Zurücksetzen auf NULL, 1 bedeutet erstellt JSON mit meta, configuration und warnings. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang des JSON-Dokuments, etwa @Json=@Payload OUTPUT mit einer nvarchar(max)-Variablen. Der Eingabewert wird beim Eintritt vor TABLE-Preflight und Hilfe auf NULL gesetzt. Bei erfolgreicher Hilfe-Rückkehr bleibt @Json NULL; andere Status-/Fehler-OUTPUTs werden dort nicht zugewiesen. Im normalen Pfad wird @Json nur bei @JsonErzeugen=1 nach der Quellverarbeitung befüllt; sonst bleibt es NULL. Ohne OUTPUT-Bindung wird kein Wert empfangen.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang, etwa @StatusCodeOut=@Status OUTPUT mit einer varchar(40)-Variablen. Werte und Bedeutungen: AVAILABLE (kein festgestellter Eingabe- oder abgefangener Quellfehler), INVALID_PARAMETER (ungültige ResultSetArt), DENIED_PERMISSION (abgefangene Quellfehler 229, 297, 300 oder 371), TIMEOUT (Quellfehler 1222), ERROR_HANDLED (übrige abgefangene Quellfehler). Die reguläre Zuweisung erfolgt nach der Quellverarbeitung; Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert und ein früher Preflight-THROW erreicht die Zuweisung nicht. Ohne OUTPUT-Bindung wird kein Wert empfangen.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Parameter für die Teilstatuskennzeichnung: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER oder behandeltem Quellfehler. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @IsPartialOut=@Empfaenger OUTPUT angeben; die Variable muss bit sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optionaler OUTPUT-Parameter für bei abgefangenem Quellfehler die Quellfehlernummer; sonst NULL. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @ErrorNumberOut=@Empfaenger OUTPUT angeben; die Variable muss int sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler OUTPUT-Parameter für bei Fehler den Quelltext beziehungsweise bei INVALID_PARAMETER den Hinweis auf die zulässigen ResultSetArt-Werte; sonst NULL. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @ErrorMessageOut=@Empfaenger OUTPUT angeben; die Variable muss nvarchar(2048) sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird.';
        PRINT N'EXEC [monitor].[USP_ServerConfiguration] @ResultSetArt=''CONSOLE'';';
        PRINT N'EXEC [monitor].[USP_ServerConfiguration] @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_ServerConfiguration] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'EXEC [monitor].[USP_ServerConfiguration] @Hilfe=1;';








        RETURN;END;
 DECLARE @T datetime2(3)=SYSUTCDATETIME(),@S varchar(40)='AVAILABLE',@P bit=0,@E int=NULL,@M nvarchar(2048)=NULL,@Schedulers int=NULL;
 IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') SELECT @S='INVALID_PARAMETER',@P=1,@M=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
 CREATE TABLE [#ServerConfiguration_C]([configuration_id] int,[name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[minimum] sql_variant,[maximum] sql_variant,[ConfiguredValue] sql_variant,[RunningValue] sql_variant,[is_dynamic] bit,[is_advanced] bit,[Finding] varchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[Interpretation] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS);
 SET LOCK_TIMEOUT 0;BEGIN TRY
  SELECT @Schedulers=[scheduler_count] FROM [sys].[dm_os_sys_info] WITH (NOLOCK);
  INSERT [#ServerConfiguration_C] SELECT [configuration_id],[name],[minimum],[maximum],[value],[value_in_use],[is_dynamic],[is_advanced],
   CASE WHEN [value]<>[value_in_use] THEN'RECONFIGURE_OR_RESTART_PENDING' WHEN [name]='cost threshold for parallelism'AND CONVERT(int,[value_in_use])<=5 THEN'LOW_DEFAULT_REVIEW' WHEN [name]='max server memory (MB)'AND CONVERT(bigint,[value_in_use])>=2147483647 THEN'UNBOUNDED_MEMORY_REVIEW' WHEN [name] IN('xp_cmdshell','Ole Automation Procedures')AND CONVERT(int,[value_in_use])=1 THEN'SECURITY_REVIEW' ELSE'OK_OR_CONTEXT_DEPENDENT'END,
   CASE WHEN [name]='max degree of parallelism'THEN CONCAT(N'0 bedeutet automatische Nutzung bis zur Enginegrenze; gegen NUMA, Scheduleranzahl ',@Schedulers,N', Workload und Parallelism-Waits bewerten.') WHEN [name]='cost threshold for parallelism'THEN N'Der Standardwert 5 ist häufig nur ein Ausgangspunkt; Änderungen ausschließlich workloadbasiert.' WHEN [name]='max server memory (MB)'THEN N'OS-, Agent-, SSIS-/ETL- und sonstige Prozessreserve berücksichtigen.' ELSE N'Kontext-, Sicherheits- und Herstelleranforderungen prüfen; keine automatische Änderung.'END
  FROM [sys].[configurations] WITH (NOLOCK) WHERE @NurKernparameter=0 OR [name] IN('max degree of parallelism','cost threshold for parallelism','max server memory (MB)','min server memory (MB)','optimize for ad hoc workloads','backup compression default','remote admin connections','contained database authentication','clr enabled','clr strict security','xp_cmdshell','Ole Automation Procedures','external scripts enabled','blocked process threshold (s)','query wait (s)','affinity mask','affinity64 mask');
 END TRY BEGIN CATCH SELECT @S=CASE WHEN ERROR_NUMBER()IN(229,297,300,371)THEN'DENIED_PERMISSION'WHEN ERROR_NUMBER()=1222 THEN'TIMEOUT'ELSE'ERROR_HANDLED'END,@P=1,@E=ERROR_NUMBER(),@M=ERROR_MESSAGE();END CATCH;
 SELECT @StatusCodeOut=@S,@IsPartialOut=@P,@ErrorNumberOut=@E,@ErrorMessageOut=@M;IF @PrintMeldungen=1 AND @S<>'AVAILABLE'RAISERROR(N'USP_ServerConfiguration: %s',10,1,@M) WITH NOWAIT;
 IF @ResultSetArtNormalisiert<>'NONE' BEGIN SELECT CAST('2.0' AS varchar(16)) [ContractVersion],@T [CollectionTimeUtc],N'monitor.USP_ServerConfiguration' [ModuleName],@S [StatusCode],@P [IsPartial],@E [ErrorNumber],@M [ErrorMessage];IF @ResultSetArtNormalisiert='RAW' BEGIN SELECT * FROM [#ServerConfiguration_C] ORDER BY [name]; END ELSE BEGIN SELECT N'configuration' [Ergebnis],[x].* FROM [#ServerConfiguration_C] [x] ORDER BY [name]; END;END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'ServerConfiguration' [resultName],1 [schemaVersion],@T [generatedAtUtc],@S [statusCode],@P [isPartial],@E [errorNumber],@M [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@J0 nvarchar(max)=(SELECT [configuration_id],[name],CONVERT(nvarchar(4000),[minimum]) [minimum],CONVERT(nvarchar(4000),[maximum]) [maximum],CONVERT(nvarchar(4000),[ConfiguredValue]) [ConfiguredValue],CONVERT(nvarchar(4000),[RunningValue]) [RunningValue],[is_dynamic],[is_advanced],[Finding],[Interpretation] FROM [#ServerConfiguration_C] ORDER BY [name] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"configuration":',COALESCE(@J0,N'[]'),N',"warnings":[]}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ServerConfiguration_C'
            , @ResultLabel=N'ServerConfiguration'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ServerConfiguration_C'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

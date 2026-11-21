---
skill_format_version: "1.0.0"
name: "monitor.USP_ExternalRuntimeAnalysis"
schema_name: "monitor"
object_name: "USP_ExternalRuntimeAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure analysiert Konfiguration, registrierte Sprachen und Libraries, aktive External-Script-Requests, External Resource Pools sowie kumulative Runtime- und Performance-Counter-Evidenz."
source_path: "Code/09_VersionAdaptive/090_USP_ExternalRuntimeAnalysis.sql"
---

# monitor.USP_ExternalRuntimeAnalysis

## Zweck und Einsatz

Die Procedure analysiert Konfiguration, registrierte Sprachen und Libraries, aktive External-Script-Requests, External Resource Pools sowie kumulative Runtime- und Performance-Counter-Evidenz.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

SERVERPROPERTY, sys.configurations, sys.dm_server_services, sys.external_languages, sys.external_language_files, sys.external_libraries, sys.external_library_files, sys.dm_external_script_requests, sys.dm_exec_requests, sys.dm_exec_sessions, sys.dm_external_script_execution_stats, sys.dm_resource_governor_external_resource_pools und sys.dm_os_performance_counters.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @LanguageNames | nvarchar(max) | nein | NULL |
| @LanguageNamePattern | nvarchar(4000) | nein | NULL |
| @SampleSeconds | tinyint | nein | 0 |
| @MitDateimetadaten | bit | nein | 0 |
| @MitBerechtigungsanalyse | bit | nein | 0 |
| @MitSitzungskontext | bit | nein | 0 |
| @NurProblematisch | bit | nein | 0 |
| @MaxZeilen | int | nein | 100 |
| @LockTimeoutMs | int | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@DatabaseNames:** @DatabaseNames nvarchar(max)=NULL; Default: NULL. NULL, leerer oder nur aus Leerzeichen bestehender Wert bedeutet keine Namensbeschränkung. Sonst Pipe-Liste einteiliger Datenbanknamen; | trennt außerhalb eckiger Klammern, ]] maskiert darin ]. Äußere Elementleerzeichen werden entfernt. Ein Rohsegment darf vor dem Trimmen höchstens 4000 UTF-16-Codeeinheiten umfassen; Elemente müssen gültige einzelne PARSENAME-Namen bis 128 Zeichen sein. Leere Elemente, fehlerhafte Klammerung, Mehrfachnamen und exakt doppelte gültige Namen sind ungültig. Vergleich erfolgt case-sensitiv. Fehlende, nicht online befindliche, nicht zugreifbare oder ohne Systemdatenbank-Opt-in ausgeschlossene gültige Namen werden als Datenbankwarnung geführt und können den Lauf partiell machen. Exakte Namensliste und @DatabaseNamePattern sind exklusiv. Bei ausgelassenem Argument gilt der angegebene Default.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit=0; Default: 0. 0 schließt database_id 1 bis 4 aus; 1 schließt sie ein, wenn sie sichtbar, online und zugreifbar sind. NULL ist im normalen Lauf ungültig. Der Parameterwert 0 bedeutet aus und 1 bedeutet ein; bei numerischer Übergabe wird 0 zu 0 und jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Das Opt-in setzt keine Rechte und macht eine nicht verfügbare Datenbank nicht verfügbar. Bei ausgelassenem Argument gilt der angegebene Default.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. NULL bedeutet kein Pattern. Sonst werden äußere Leerzeichen getrimmt und das Präfix ohne Beachtung der Großschreibung erkannt: regexi: bedeutet Regex mit Flag i, regex: Regex mit Flag c, like: SQL-LIKE; ohne Präfix gilt ebenfalls LIKE. Der Rest nach einem Präfix wird nicht erneut getrimmt und darf nicht leer sein. LIKE wird case-sensitiv auf den Datenbanknamen angewandt. Regex-Syntax wird nicht vorab validiert; Regex erfordert SQL Server 2025 (Major 17) und Compatibility Level 170 in der Framework- beziehungsweise Installationsdatenbank. Die Compatibility-Level-Prüfung für Zieldatenbanken gehört zum separaten @LanguageNamePattern-Pfad. Leere Eingaben und leere Präfixinhalte sind ungültig. Exakte Namensliste und Pattern sind exklusiv. Bei ausgelassenem Argument gilt der angegebene Default.

**@HighImpactConfirmed:** @HighImpactConfirmed bit=0; Default: 0. 0 bestätigt keinen High-Impact-Aufruf; 1 bestätigt ihn. NULL ist im normalen Lauf ungültig. Die Bestätigung ist keine Berechtigung. Der Basispfad verwendet EXTERNAL_RUNTIME_CURRENT mit RequiresGroupGate=0. Nur wenn @MitBerechtigungsanalyse=1, wird zusätzlich CATALOG_DEEP geprüft; diese Klasse verlangt Bestätigung 1 und eine aktuelle Policyfreigabe. 0 bedeutet keine Bestätigung und 1 bedeutet Bestätigung; bei numerischer Übergabe wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.

**@LanguageNames:** @LanguageNames nvarchar(max)=NULL; Default: NULL. NULL bedeutet keine Language-Einschränkung. Sonst eine Pipe-Liste einteiliger SQL-Namen angeben; der Parameter wird direkt durch TVF_ParseSqlNameList geprüft. | trennt außerhalb von [...], ]] maskiert darin ], Rand-Leerzeichen an Elementen werden entfernt. Rohsegmentgrenze 4000 UTF-16-Codeeinheiten, Namensgrenze 128 Zeichen. Leere Elemente, falsche Klammerung und mehrteilige Namen sind ungültig. Anders als @DatabaseNames bedeuten Leertext und Leerraumelemente keinen fehlenden Filter, sondern ungültige Eingabe. Doppelte Namen bleiben im Parser, duplizieren aber wegen des EXISTS-Abgleichs keine Ergebniszeilen. Der Language-Abgleich ist case-sensitiv. Bei ausgelassenem Argument gilt der angegebene Default.

**@LanguageNamePattern:** @LanguageNamePattern nvarchar(4000)=NULL; Default: NULL. NULL bedeutet kein Pattern. Ansonsten gelten die Präfixe regexi: (Regex-Flag i), regex: (Regex-Flag c), like: (SQL-LIKE) sowie unpräfigiertes LIKE; Präfixerkennung ist case-insensitiv, nur äußerer Leerraum wird vorab getrimmt. LIKE-Vergleich ist case-sensitiv. Das Pattern filtert Languages, Libraries, passende aktive Requests und Execution Stats. Leerer Eingang oder leerer Präfixinhalt ist ungültig. Regex erfordert SQL Server 2025 (Major 17), Compatibility Level 170 in Framework- und Zieldatenbanken; Syntaxfehler werden erst beim Ausführen erkannt. Exklusiv zu @LanguageNames. Bei ausgelassenem Argument gilt der angegebene Default.

**@SampleSeconds:** @SampleSeconds tinyint=0; Default: 0. 0 liefert einen Momentaufnahmepunkt ohne WAITFOR oder Deltas. Jeder Wert von 1 bis 60 einschließlich fordert T1/T2-Messpunkte mit WAITFOR DELAY für die angeforderte Intervallzeit an; SQL-Abfragezeit kommt hinzu. NULL und Werte über 60 sind ungültig. Pools, Performance Counter und Execution Stats sind serverweit; der Languagefilter beschränkt nicht alle serverweiten Zugriffe. Pooldeltas verlangen gleiche statistics_start_time und pool_version sowie nicht fallende Zähler; Reset, Versionswechsel, Rückgang oder fehlendes T2 verwerfen Deltas. Execution-Stats- und Counterdeltas werden bei Reset/Rückgang oder fehlendem T2 nicht ausgewiesen. Countertyp 65792 liefert RAW_SNAPSHOT; 272696320 und 272696576 liefern bei positivem und gültigem Sample RATE_PER_SECOND. 537003264 ist als FRACTION_DELTA_PERCENT und 1073874176 als AVERAGE_DELTA_RATIO klassifiziert, aber diese Procedure übergibt keine Basiszähler; deshalb bleibt ihre Metrik NULL und der Helper meldet BASE_COUNTER_MISSING, wenn ein gültiges Sample vorliegt. Weitere Typen bleiben RAW_UNINTERPRETED. Tatsächliche Messzeitstempel und Deltas sind keine atomare Messung, kein SLA und kein Nachweis externer Prozess-CPU. Bei ausgelassenem Argument gilt der angegebene Default.

**@MitDateimetadaten:** @MitDateimetadaten bit=0; Default: 0. 0 lässt Datei-Metadatenabfragen aus. 1 ergänzt für Language Files Dateiname und Plattform sowie für Library Files die Plattform. Datei- und Libraryinhalte, Pfade, Parameterspalten und Environment Variables werden nicht gelesen; Metadaten beweisen keine Installation oder Startfähigkeit. NULL ist im normalen Lauf ungültig. Das Opt-in aktiviert nicht CATALOG_DEEP und kein High-Impact-Gate; fehlende Rechte erscheinen als Quellenstatus. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.

**@MitBerechtigungsanalyse:** @MitBerechtigungsanalyse bit=0; Default: 0. 0 lässt Ownernamen aus. 1 ergänzt sichtbare database_principals-Namen der registrierten Languages und Libraries. Vor dem Katalogzugriff wird zusätzlich CATALOG_DEEP policygeprüft; diese Klasse erfordert @HighImpactConfirmed=1 und eine aktuelle Freigabe. Bestätigung allein erlaubt den Zugriff nicht. Eine Gateverweigerung stoppt den fachlichen Pfad. NULL ist im normalen Lauf ungültig; Metadatenrechte können die Sichtbarkeit begrenzen. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.

**@MitSitzungskontext:** @MitSitzungskontext bit=0; Default: 0. 0 projiziert Login, Host, Clientprogramm und External Worker Account für activeRequests als NULL. 1 ergänzt diese vier Felder aus dm_exec_sessions beziehungsweise dm_external_script_requests für sichtbare aktive Requests; keine historischen Identitäten. NULL ist im normalen Lauf ungültig. DMV-Rechte und Sichtbarkeit gelten unabhängig vom Opt-in. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.

**@NurProblematisch:** @NurProblematisch bit=0; Default: 0. 0 übernimmt alle Findings-Schweregrade; 1 filtert ausschließlich Findings mit Severity=WARN. Dasselbe Prädikat gilt für CONSOLE, RAW, TABLE und JSON. Es filtert keine Katalog-, Request-, Pool-, Counter-, Quellenstatus-, Datenbankstatus- oder Warning-Ausgabe. NULL ist im normalen Lauf ungültig. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int=100; Default: 100. NULL oder 0 bedeutet unbegrenzt. Positive Werte begrenzen nach vollständiger Materialisierung und jeweiliger Sortierung Findings, Languages, Libraries, activeRequests, externalPools, Execution Stats und Performance Counters; configuration, databaseStatus, sourceStatus und warnings sind nicht begrenzt. Findings werden nach @NurProblematisch gefiltert, WARN vor anderen Schweregraden sortiert und innerhalb dessen nach ursprünglichem FindingOrdinal begrenzt. Negative Werte setzen INVALID_PARAMETER; bei @JsonErzeugen=1 entsteht dennoch JSON mit Fehlerstatus. Die RESULTSET_TRUNCATED-Warnung zählt externalPools nicht, deshalb meldet eine alleinige Kürzung dieses Resultsets derzeit nicht zwingend eine Truncation. Ein positives Limit verringert nicht die vorgelagerte Quellarbeit. Bei ausgelassenem Argument gilt der angegebene Default.

**@LockTimeoutMs:** @LockTimeoutMs int=0; Default: 0. Zulässig sind 0 bis 60000 Millisekunden einschließlich. 0 setzt LOCK_TIMEOUT 0 und wartet bei blockierten fachlichen Zugriffen nicht. NULL oder andere Werte sind ungültig. Der gesetzte Wert gilt für den Lauf und die ursprüngliche Sitzungseinstellung wird danach wiederhergestellt. Isolierte Quelltimeouts erscheinen als Quellenstatus; nicht isolierte Timeouts ergeben global LOCK_TIMEOUT. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt: CONSOLE, RAW, TABLE oder NONE. TABLE exportiert nur findings in ein vorab geprüftes lokales #Temp-Ziel; JSON ist unabhängig steuerbar.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Nur mit @ResultSetArt=TABLE ist ein nichtleeres Mapping gültig. NULL, leer oder nur Leerzeichen ist kein Mapping; nichtleerer Text bei anderem ResultSetArt wirft 51011. Für die Procedure wird ein JSON-Objekt mit exakt kleingeschriebenem, case-sensitivem Schlüssel findings und JSON-String als Ziel erwartet. Das Ziel ist eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. ##Temp, permanente Ziele, Präfix #Monitor (case-insensitiv) und Namen über 116 Zeichen sind unzulässig. Unbekannter/duplizierter Schlüssel, dupliziertes Ziel, falscher JSON-Werttyp, leeres Ziel oder ungültiges Ziel scheitert im vollständigen Preflight vor fachlichen Quellenzugriffen mit 51011. Erfolgreich schreibt der Helper die 13 findings-Spalten; späterer Writerfehler wirft 51010. Nach THROW sind OUTPUT-Übergaben nicht zugesichert. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 0 erzeugt kein JSON und lässt @Json NULL. 1 erzeugt unabhängig von @ResultSetArt ein JSON-Objekt mit meta als Objekt sowie den Arrays configuration, databaseStatus, sourceStatus, findings, languages, libraries, activeRequests, externalPools, executionStats, performanceCounters und warnings. Leere Arrays sind []; NULL-Properties werden in der bestehenden FOR JSON PATH-Semantik ausgelassen. Auch bei INVALID_PARAMETER wird das JSON erzeugt, wenn 1 gewählt wurde. NULL ist im normalen Lauf ungültig. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT enthält bei @JsonErzeugen=1 das erzeugte JSON in einer nvarchar(max)-Variable, gebunden als @Json=@JsonVar OUTPUT; sonst bleibt es NULL. Es umfasst meta als Objekt und die Arrays configuration, databaseStatus, sourceStatus, findings, languages, libraries, activeRequests, externalPools, executionStats, performanceCounters und warnings; NULL-Properties sind ausgelassen. Beim Eintritt wird @Json auf NULL gesetzt. Beim frühen Hilfereturn bleibt es NULL. Vor Abschluss ausgelöste Fehler garantieren keine OUTPUT-Zustellung. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. 0 unterdrückt Statusmeldungen und den Hinweis RESULTSET_TRUNCATED. 1 sendet beide möglichen Meldungen per RAISERROR mit Severity 10 und NOWAIT; fachliche Resultsets und OUTPUT-Werte bleiben davon getrennt. NULL ist im normalen Lauf ungültig. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. 1 gibt eingebaute PRINT-Hilfe aus und kehrt vor Parameterprüfung, Quellenzugriff, fachlichen Resultsets und OUTPUT-Zuweisung zurück; @Json wurde zuvor auf NULL gesetzt. 0 und NULL führen zum normalen Pfad, sofern dessen Eingaben gültig sind. Hilfe liefert keinen Status oder Daten-Resultset. 0 bedeutet aus und 1 bedeutet Hilfe; bei numerischer Übergabe wird 0 zu 0 und jeder numerische Wert ungleich 0 wird zu 1 konvertiert. NULL wird durch IF nicht als Hilfeaufruf behandelt. Die TABLE-Zielvorprüfung läuft davor und kann auch bei einem Hilfeaufruf Fehler 51011 auslösen. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. OUTPUT liefert den globalen Laufstatus in einer varchar(40)-Variable, die mit @StatusCodeOut=@StatusVar OUTPUT gebunden wird; Quellen- und Datenbankstatus sind davon getrennt. AVAILABLE bedeutet Abschluss ohne Warn-Finding und ohne Partialität; AVAILABLE_WITH_FINDING meldet mindestens ein WARN-Finding; AVAILABLE_LIMITED meldet teilweise Auswertung durch Quelle, Datenbank oder Auswahlwarnung. FEATURE_DISABLED bedeutet deaktivierte Option bei sichtbarer Registrierungs- oder Execution-Stats-Evidenz; NOT_APPLICABLE bedeutet deaktivierte Option ohne diese sichtbare Evidenz. INVALID_PARAMETER meldet ungültige Eingaben; UNAVAILABLE_FEATURE unerfüllte Regexversions-/Compatibility-Voraussetzung. HIGH_IMPACT_CONFIRMATION_REQUIRED meldet fehlende Bestätigung für den aktivierten CATALOG_DEEP-Pfad; DENIED_GROUP fehlende Policyfreigabe. INTERNAL_ERROR wird übernommen, wenn der Datenbankvorbereitungshelfer einen Fehler seiner Temp-Tabellenprobe meldet; dies ist kein regulärer fachlicher Auswahlwert. Die Procedure setzt die Partialität und lässt diesen globalen Status bestehen. LOCK_TIMEOUT ist ein nicht isoliert abgefangener Locktimeout; ERROR_HANDLED ein sonstiger nicht isolierter Fehler. Quell-/Datenbankcodes wie DENIED_PERMISSION, SOURCE_UNAVAILABLE, SYSTEM_DATABASE_EXCLUDED und DATABASE_UNAVAILABLE bleiben separat. Bei @Hilfe=1 erfolgt keine Zuweisung; nach THROW, einschließlich 51011/51010, ist keine OUTPUT-Zustellung garantiert. Frühe Parameter-, Gate- und Helfercodes bleiben bestehen. Solange der Status AVAILABLE ist, haben partielle Quellen oder Datenbanken Vorrang vor WARN-Findings; danach wird bei deaktivierter External-Scripts-Option zwischen FEATURE_DISABLED und NOT_APPLICABLE anhand der sichtbaren Evidenz unterschieden. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT; Default: NULL. OUTPUT liefert die Partialität in einer bit-Variablen, gebunden als @IsPartialOut=@PartialVar OUTPUT. 1 kennzeichnet eingeschränkte oder teilweise Auswertung, unter anderem AVAILABLE_LIMITED, ungültige Eingaben, nicht verfügbare Regexvoraussetzungen, Gateverweigerung und INTERNAL_ERROR des Kandidatenhelfers; sonst 0. Isolierte Quellenfehler fließen in die Partialitätsbewertung ein. Das Feld ist vom separat ausgewiesenen IsPartial pro Quelle und Datenbank zu unterscheiden. Bei @Hilfe=1 erfolgt keine Zuweisung; nach THROW ist keine OUTPUT-Zustellung garantiert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT; Default: NULL. OUTPUT liefert die Fehlernummer in einer int-Variablen, gebunden als @ErrorNumberOut=@ErrorNoVar OUTPUT. Enthalten ist ein nicht isoliert abgefangener SQL-Fehler oder, falls der globale Wert noch NULL ist, der kleinste ErrorNumber-Wert aus partiellen Quellen; sonst NULL. Validierungs- und Gatefehler können eine Meldung ohne SQL-Fehlernummer haben. Bei @Hilfe=1 erfolgt keine Zuweisung; nach THROW, einschließlich 51011/51010, ist keine OUTPUT-Zustellung garantiert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. OUTPUT liefert die Fehlermeldung in einer nvarchar(2048)-Variable, gebunden als @ErrorMessageOut=@ErrorMsgVar OUTPUT. Enthalten ist die globale Fehlermeldung oder, falls noch keine vorhanden ist, der lexikalisch kleinste ErrorMessage-Wert einer partiellen Quelle; sonst NULL. Isolierte Details bleiben zusätzlich in sourceStatus und databaseStatus. Bei @Hilfe=1 erfolgt keine Zuweisung; nach THROW ist keine OUTPUT-Zustellung garantiert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| findings | 1 | 1 | [FindingOrdinal] bigint NOT NULL PRIMARY KEY , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ObjectType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ObjectName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [MetricValue] decimal(38,4) NULL , [ThresholdValue] decimal(38,4) NULL , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ExternalRuntimeAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Registrierung und Konfiguration beweisen weder Installation noch Startfähigkeit einer konkreten Runtime. Request-CPU ist Engine-Evidenz und enthält keine belegte externe Prozess-CPU.

MEDIUM; optionales Sampling wartet höchstens 60 Sekunden.

Rein lesend; führt kein externes Script aus und ändert weder Launchpad-, Resource-Governor- noch Serverkonfiguration.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
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
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ExternalRuntimeAnalysis
Die Procedure erfasst lesend External-Runtime-Konfiguration, sichtbare Language- und Libraryregistrierungen, aktive Requests, Pools und Counter. Sie führt keinen externen Code aus, installiert oder aktiviert keine Runtime.
Der Basispfad prüft EXTERNAL_RUNTIME_CURRENT ohne High-Impact-Gate. Ownernamen aktivieren zusätzlich CATALOG_DEEP und verlangen @HighImpactConfirmed=1 sowie aktuelle Policyfreigabe.
Datenbankname und Datenbankpattern sowie LanguageNames und LanguageNamePattern sind jeweils exklusiv. LanguageNames wird direkt als bracket-aware Pipe-Liste einteiliger SQL-Namen geparst.
Globale Statuscodes: AVAILABLE, AVAILABLE_WITH_FINDING, AVAILABLE_LIMITED, FEATURE_DISABLED, NOT_APPLICABLE, INVALID_PARAMETER, UNAVAILABLE_FEATURE, HIGH_IMPACT_CONFIRMATION_REQUIRED, DENIED_GROUP, INTERNAL_ERROR, LOCK_TIMEOUT und ERROR_HANDLED.
Beispiel 1: EXEC [monitor].[USP_ExternalRuntimeAnalysis] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N'[ExampleDatabase]', @LanguageNames=N'[ExampleLanguage]', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
Beispiel 3: DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
Beispiel 4: CREATE TABLE [#ExternalRuntimeAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#ExternalRuntimeAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#ExternalRuntimeAnalysis_HelpExample]; DROP TABLE IF EXISTS [#ExternalRuntimeAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#ExternalRuntimeAnalysis_HelpExample]; THROW; END CATCH;
Beispiel 5: EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNamePattern=N'like:ExampleDatabase%', @LanguageNamePattern=N'like:ExampleLanguage%', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
Beispiel 6: EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N'[ExampleDatabase]', @SampleSeconds=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
Beispiel 7: EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N'[ExampleDatabase]', @MitBerechtigungsanalyse=1, @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
```


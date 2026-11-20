---
skill_format_version: "1.0.0"
name: "monitor.USP_AuditConfigurationAnalysis"
schema_name: "monitor"
object_name: "USP_AuditConfigurationAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure inventarisiert die sichtbare SQL-Server-Auditkonfiguration und deren zur Laufzeit gemeldeten Zustand."
source_path: "Code/08_ServerHealth/240_USP_AuditConfigurationAnalysis.sql"
---

# monitor.USP_AuditConfigurationAnalysis

## Zweck und Einsatz

Die Procedure inventarisiert die sichtbare SQL-Server-Auditkonfiguration und deren zur Laufzeit gemeldeten Zustand. Datenbankspezifikationen werden je ausgewählter sichtbarer Online-Datenbank gelesen.

## Voraussetzungen und Rechte

sys.server_audits, sys.server_audit_specifications, sys.server_audit_specification_details, sys.database_audit_specifications, sys.database_audit_specification_details, optional sys.dm_server_audit_status.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @AuditNames | nvarchar(max) | nein | NULL |
| @AuditNamePattern | nvarchar(4000) | nein | NULL |
| @NurProblematisch | bit | nein | 0 |
| @MaxZeilen | int | nein | 1000 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Filter für lokale Spezifikationen. NULL, Leertext oder nur U+0020-Leerzeichen: sichtbare, zugreifbare ONLINE-Benutzerdatenbanken ohne Datenbanksnapshots; Systemdatenbanken nur mit Opt-in. Sonst bracket-aware Pipe-Liste exakter SQL-Namen; Pipes in [Klammern] trennen nicht, ]] maskiert ]. Leere/ungültige Segmente oder Namen sind ungültig. Nur eine aktive, nichtleere Liste ist mit einem nicht-NULL-Pattern unvereinbar. Fehlende, offline oder nicht zugängliche Namen erzeugen interne Kandidatenwarnungen, die diese Procedure nicht ausgibt und nicht allein in ihre Partialitätsbewertung übernimmt. Eine leere Spezifikationsmenge belegt deshalb keine vollständige Auswahl.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt master, tempdb, model und msdb aus; 1 erlaubt sie. NULL ist im Kandidatenhelper ungültig und setzt INVALID_PARAMETER. Explizit angeforderte Systemdatenbanken ohne Opt-in erzeugen intern SYSTEM_DATABASE_EXCLUDED; diese Auswahlwarnung wird nicht ausgegeben. Weitergabe an den Kandidatenhelper. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Alternativer Datenbankfilter, unvereinbar mit einer aktiven nichtleeren Datenbankliste. NULL: kein Pattern. Helper trimmt außen; erkennt LIKE:, REGEX:, REGEXI: ohne Beachtung der Großschreibung, sonst LIKE. Rest wird nicht erneut getrimmt. REGEX arbeitet case-sensitiv (Flag c), REGEXI ohne Beachtung der Groß-/Kleinschreibung (Flag i); leerer Rest ungültig. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE; Syntax wird nicht vorab geprüft. Eine fehlerhafte Regex kann bei REGEXP_LIKE im Kandidatenhelper einen nicht abgefangenen Fehler auslösen und den normalen Modulabschluss umgehen.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. 0 und 1 sind gültige Bestätigungswerte, werden in diesem Aufruf aber keinem Analyseklassen-/Gruppengate vorgelegt: AnalysisClass ist fest NULL. Beide Werte aktivieren dasselbe lesende Inventar. NULL ist im Kandidatenhelper ungültig und setzt INVALID_PARAMETER; der Wert ist keine Berechtigungserteilung. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@AuditNames:** @AuditNames nvarchar(max); Default: NULL. Exakte Auditnamen für audits und beide Spezifikationsscopes als bracket-aware Pipe-Liste; NULL: kein Filter. Pipes in [Klammern] trennen nicht, ]] maskiert ]. Leere Segmente und ungültige SQL-Namen sind ungültig; gültige Werte werden dedupliziert. Exklusiv mit @AuditNamePattern. Vergleich ist SQL_Latin1_General_CP1_CS_AS (case-sensitive); kein Treffer erzeugt keinen eigenen Fehlerstatus.

**@AuditNamePattern:** @AuditNamePattern nvarchar(4000); Default: NULL. Alternativer Auditnamenfilter mit LIKE, exklusiv mit @AuditNames. NULL: kein Filter. Parser trimmt außen, entfernt optional LIKE: ohne Groß-/Kleinschreibung und trimmt danach nicht erneut. REGEX:/REGEXI: werden erkannt, aber von dieser Procedure als INVALID_PARAMETER zurückgewiesen. Leerwert/Leerrest ungültig. Vergleich case-sensitive. Dieses Pattern begrenzt ausschließlich audits; serverSpecifications und databaseSpecifications werden dadurch nicht gefiltert. Für einen Namensfilter in allen drei Fachmengen ist stattdessen @AuditNames zu verwenden.

**@NurProblematisch:** @NurProblematisch bit; Default: 0. 0 lässt INFO und MEDIUM in den drei Fachresultaten zu. 1 entfernt INFO; NULL entfernt INFO ebenfalls und wirkt wie 1. Quellenstatus und Warnings bleiben ungefiltert; Warnings entstehen vor diesem INFO-Filter. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@MaxZeilen:** @MaxZeilen begrenzt jedes Fachresultat; Status und Warnings bleiben ungekürzt.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Wird nur auf negative Werte geprüft; im Body aber nicht zum Setzen eines Timeouts genutzt. NULL besteht den Negativtest und wird nicht angewendet. Die Procedure setzt danach LOCK_TIMEOUT 0; SET-Werte werden bei Rückkehr aus der Procedure zurückgenommen.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach Entfernen äußerer U+0020-Leerzeichen und Großschreibung sind genau RAW, CONSOLE, TABLE und NONE erlaubt. RAW liefert Modulstatus und danach audits, serverSpecifications, databaseSpecifications, sourceStatus, warnings. CONSOLE wird intern auf NONE normalisiert und zeigt ausschließlich die beschriftete audits-Ansicht, ohne separates Modulstatusresultset. TABLE schreibt nur zugeordnete Gruppen, NONE liefert keine regulären Resultsets. JSON wird unabhängig gesteuert. NULL, Leertext und andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE; gültiges JSON-Objekt mit mindestens einer Zuordnung aus exakt audits, serverSpecifications, databaseSpecifications, sourceStatus, warnings zu einem Ziel. Keys binär exakt, keine doppelten Keys/Ziele. Ziel: vorhandene leere lokale #Temp mit genau einer Seed-Spalte, max. 116 Zeichen, kein ##- oder reserviertes #Monitor-Präfix. Mapping wird vor fachlichem Zugriff validiert; Bei einem ungültigen Ziel kann der Helper mit Fehler 51011 abbrechen; dann ist die abschließende Zuweisung der Modul-OUTPUTs nicht garantiert. audits bedeutet Auditkonfigurationen, serverSpecifications Serverspezifikationen, databaseSpecifications Datenbankspezifikationen, sourceStatus Quellenstatus und warnings Warnungen. In TABLE sind NULL, Leertext und ein leeres Objekt ungültig. Außerhalb von TABLE bleiben NULL, Leertext und nur U+0020-Leerzeichen unbeachtet; ein anderer nichtleerer Wert kann vor der Analyse Fehler 51011 auslösen.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erstellt JSON in @Json; 0 oder NULL erzeugt keines. Unabhängig von Resultsetart; für JSON ohne Resultsets NONE verwenden. Dokument enthält meta und fünf Arrays audits, serverSpecifications, databaseSpecifications, sourceStatus, warnings. meta: resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, crossDatabaseRequested. Facharrays wenden Filter und Limit an; Status/Warnungen bleiben vollständig. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Empfänger. Zu Beginn NULL; bei JsonErzeugen=1 Dokument, sonst NULL. OUTPUT-Variable nvarchar(max) mit OUTPUT im EXEC binden. Hilfe kehrt vorher zurück und lässt den Wert NULL. Der Empfänger kann ausgelassen werden, wenn kein JSON empfangen werden soll.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Der Parameter wird im Procedure-Body nicht gelesen und beeinflusst weder PRINT-Meldungen noch Resultsets. Der Hilfezweig gibt seine PRINT-Zeilen unabhängig von diesem Eingabewert aus. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@Hilfe:** @Hilfe bit; Default: 0. 1 gibt PRINT-Hilfe aus und kehrt ohne Analyse und abschließende OUTPUT-Zuweisung zurück. Die Hilfe erklärt Zweck, Parameterverträge und Beispielaufrufe. 0 führt aus; NULL löst Früh-Rückkehr nicht aus. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Bei regulärem Abschluss: AVAILABLE ohne gemeldeten Befund, AVAILABLE_WITH_FINDING bei MEDIUM-Warnungen ohne Partialität, AVAILABLE_LIMITED bei partiellen Quellen, INVALID_PARAMETER bei ungültigen Modul-/Kandidatenparametern, INTERNAL_ERROR bei internem Kandidatenschemafehler, UNAVAILABLE_FEATURE bei fehlender Regex-Voraussetzung. Behandelte Quellenfehler stehen in Quellenstatus/Warnungen; Partialität setzt AVAILABLE_LIMITED. Zuweisung erfolgt am normalen Ende. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Im Hilfezweig bleibt ein anfänglicher NULL- oder anderer Empfängerwert erhalten.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT-Bit der Partialität: 0 ohne partielle Quellenlesung, 1 bei behandelten unvollständigen Lesungen. Normale Endzuweisung; Hilfe weist nicht zu. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Im Hilfezweig bleibt ein anfänglicher NULL- oder anderer Empfängerwert erhalten. Interne Kandidatenwarnungen über fehlende oder ausgeschlossene Namen werden hierbei nicht ausgewertet; 0 belegt keine vollständige Datenbanksicht.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT int der zuerst gespeicherten behandelten Serverquellen-Fehlernummer. Zweiter Server-CATCH setzt nur bei noch NULL. Datenbank-CATCHes setzen Partialität und schreiben interne, nicht ausgegebene Warnungen, aber keine Modulnummer. Parameterfehler haben keine Fehlernummer; Hilfe weist nicht zu. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Im Hilfezweig bleibt ein anfänglicher NULL- oder anderer Empfängerwert erhalten.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT nvarchar(2048) zur zuerst gespeicherten Serverquellenstörung; spätere Serverfehler überschreiben sie nicht. Datenbankfehler setzen Partialität und schreiben interne, nicht ausgegebene Warnungen statt einer Modulmeldung. Ungültige Parameter liefern Validierungstext; Hilfe weist nicht zu. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Im Hilfezweig bleibt ein anfänglicher NULL- oder anderer Empfängerwert erhalten.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| audits | 1 | 1 | [AuditId] uniqueidentifier NOT NULL, [AuditName] sysname NOT NULL, [AuditTargetType] nvarchar(60) NULL, [OnFailure] nvarchar(60) NULL, [QueueDelayMilliseconds] int NULL, [IsEnabled] bit NULL, [RuntimeStatus] nvarchar(60) NULL, [RuntimeStatusTime] datetime NULL, [ServerSpecificationCount] bigint NULL, [DatabaseSpecificationCount] bigint NULL, [FindingCode] varchar(64) NOT NULL, [FindingSeverity] varchar(16) NOT NULL, [EvidenceLimit] nvarchar(1000) NOT NULL |
| serverSpecifications | 1 | 1 | [SpecificationId] int NOT NULL, [SpecificationName] sysname NOT NULL, [AuditId] uniqueidentifier NULL, [AuditName] sysname NULL, [IsEnabled] bit NULL, [ActionCount] bigint NULL, [HasAllServerScope] bit NULL, [FindingCode] varchar(64) NOT NULL, [FindingSeverity] varchar(16) NOT NULL, [EvidenceLimit] nvarchar(1000) NOT NULL |
| databaseSpecifications | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname NOT NULL, [SpecificationId] int NOT NULL, [SpecificationName] sysname NOT NULL, [AuditId] uniqueidentifier NULL, [AuditName] sysname NULL, [IsEnabled] bit NULL, [ActionCount] bigint NULL, [HasAllDatabaseScope] bit NULL, [FindingCode] varchar(64) NOT NULL, [FindingSeverity] varchar(16) NOT NULL, [EvidenceLimit] nvarchar(1000) NOT NULL |
| sourceStatus | 1 | 1 | [SourceName] nvarchar(160) NOT NULL, [StatusCode] varchar(40) NOT NULL, [IsPartial] bit NOT NULL, [ReturnedRowCount] bigint NULL, [Detail] nvarchar(1000) NOT NULL |
| warnings | 1 | 1 | [WarningScope] varchar(32) NOT NULL, [DatabaseName] sysname NULL, [AuditName] sysname NULL, [WarningCode] varchar(64) NOT NULL, [WarningSeverity] varchar(16) NOT NULL, [Detail] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_AuditConfigurationAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Read-only. Es werden keine Auditobjekte erstellt, gestartet, gestoppt, geändert oder gelöscht.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_AuditConfigurationAnalysis
Version      : 1.0.0
Stand        : 2026-09-19
Zweck        : Die Procedure inventarisiert die sichtbare SQL-Server-Auditkonfiguration
               und deren zur Laufzeit gemeldeten Zustand. Datenbankspezifikationen
               werden je ausgewählter sichtbarer Online-Datenbank gelesen.
Datenquellen : sys.server_audits, sys.server_audit_specifications,
               sys.server_audit_specification_details,
               sys.database_audit_specifications,
               sys.database_audit_specification_details, optional
               sys.dm_server_audit_status.
Datenschutz  : Liest weder Auditdateien noch Auditlog-Payloads, Dateipfade,
               Ereignisinhalte oder überwachte Nutzdaten.
Nebenwirkung : Read-only. Es werden keine Auditobjekte erstellt, gestartet,
               gestoppt, geändert oder gelöscht.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_AuditConfigurationAnalysis
Inventarisiert sichtbare Auditkonfiguration, Spezifikationen und verfügbaren Runtimezustand; Dateien, Pfade, Ereignisinhalte und überwachte Nutzdaten werden nicht gelesen.
Datenbank- und Auditnamenfilter sind jeweils exklusiv mit ihrem Pattern. Auditpattern unterstützen nur LIKE.
RAW, CONSOLE, TABLE und NONE steuern Resultsets; JSON wird mit @JsonErzeugen angefordert.
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_AuditConfigurationAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
CREATE TABLE [#AuditConfigurationAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N'{"audits":"#AuditConfigurationAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_AuditConfigurationAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
    SELECT * FROM [#AuditConfigurationAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#AuditConfigurationAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#AuditConfigurationAnalysis_HelpExample];
    THROW;
END CATCH;
```


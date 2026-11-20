---
skill_format_version: "1.0.0"
name: "monitor.USP_RowLevelSecurityAndMaskingInventory"
schema_name: "monitor"
object_name: "USP_RowLevelSecurityAndMaskingInventory"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure inventarisiert sichtbare RLS-Policies, Predicate-Metadaten und Masked Columns."
source_path: "Code/08_ServerHealth/285_USP_RowLevelSecurityAndMaskingInventory.sql"
---

# monitor.USP_RowLevelSecurityAndMaskingInventory

## Zweck und Einsatz

Die Procedure inventarisiert sichtbare RLS-Policies, Predicate-Metadaten und Masked Columns.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_RowLevelSecurityAndMaskingInventory]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[sys].[databases]`, `[master].[sys].[databases]`, `[sys].[sp_executesql]`, `[sys].[all_objects]`, `[sys].[schemas]`, `[sys].[all_columns]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. NULL, leerer Text oder nur äußere U+0020-Leerzeichen heben den exakten Filter auf. Eine aktive Pipe-Liste enthält einfache SQL-Namen; Pipes innerhalb bracket-quotierter Elemente bleiben Inhalt, ]] maskiert dort eine schließende Klammer. Der Parser trimmt Elementränder und prüft Struktur. Leere Elemente, ungültige Klammern, Rohsegmente über 4000 UTF-16-Codeeinheiten, ungültige PARSENAME-Teil-1-Werte, vorhandene Teil 2, Namen mit LEN über 128 sowie Duplikate werden abgewiesen. Eine aktive Liste ist mit jedem nicht-NULL-Pattern unzulässig. Kandidaten müssen sichtbar, ONLINE und mit HAS_DBACCESS zugreifbar sein; Snapshots und standardmäßig Systemdatenbanken werden ausgeschlossen. Nicht verfügbare explizite Namen erzeugen Auswahlwarnungen.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. 1 nimmt Systemdatenbanken mit database_id bis einschließlich 4 auf; 0 schließt IDs bis 4 aus. NULL wird vom Auswahlhelfer als INVALID_PARAMETER zurückgewiesen. Der Schalter ändert keine Metadatensicht und prüft keine Berechtigungen. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Nur NULL bedeutet kein Pattern. Ein nicht-NULL-Leertext, nur U+0020-Leerzeichen und leere LIKE:/REGEX:/REGEXI:-Inhalte sind INVALID_PARAMETER. Ein nicht-NULL-Pattern ist mit aktiver @DatabaseNames-Liste unzulässig. Der Parser trimmt zuerst außen und entfernt danach höchstens eines der Präfixe regexi:, regex: oder like: ohne erneutes Trimmen. Ohne Präfix gilt LIKE; leerer Rest ist ungültig. LIKE wird case-sensitive angewandt. regex: arbeitet case-sensitiv mit Flag c und regexi: ohne Beachtung der Groß-/Kleinschreibung mit Flag i; der Auswahlhelfer wertet diese Modi mit REGEXP_LIKE aus und verlangt SQL Server 2025 (Major Version 17) sowie Compatibility Level 170 der Installationsdatenbank. Fehlt die Voraussetzung, löscht er Kandidaten und liefert UNAVAILABLE_FEATURE. LIKE-Inhalte verwenden SQL-LIKE-Syntax (% beliebige Folge, _ ein Zeichen, [...] Zeichenklasse; keine eigene ESCAPE-Klausel). Regexinhalte werden unverändert an REGEXP_LIKE übergeben, ohne Syntaxvorprüfung; eine fehlerhafte Regex kann erst bei der Ausführung scheitern.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. NULL und 0 bedeuten unbegrenzt. 1 bis 2147483647 begrenzt jeweils securityPolicies, securityPredicates und maskedColumns separat über alle ausgewählten Datenbanken; negative Werte liefern INVALID_PARAMETER und Fehlernummer 51011. Die Grenze wird nach allen Fachabfragen angewandt und begrenzt keine Quellarbeit. Sortierschlüssel: Policies DatabaseId/PolicyObjectId, Predicates DatabaseId/PolicyObjectId/PredicateId, Masked Columns DatabaseId/ObjectId/ColumnId. sourceStatus weist beobachtete und je Datenbank zurückgegebene Mengen aus; moduleStatus.RowCount summiert zurückgegebene Fachzeilen.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Zulässig sind 0 bis einschließlich 60000 Millisekunden. NULL, negative Werte und Werte über 60000 liefern INVALID_PARAMETER mit 51011. Der Wert gilt je dynamischer Kontext- oder Katalogbatch; 0 bedeutet NOWAIT, positive Werte begrenzen eine jeweilige Sperrwartezeit, nicht die Gesamtdauer. Bei eingehendem LOCK_TIMEOUT 0 erhält eigene Temp-DDL vorübergehend 1000 ms; der TABLE-Helfer gewährt eigener Temp-DDL ebenfalls bis zu 1000 ms je Anlage und setzt anschließend 0. Am normalen Ende und im äußeren CATCH stellt der Aufrufer eingehenden LOCK_TIMEOUT und XACT_ABORT wieder her. Caller-Transaktion bleibt Caller-eigen; kein COMMIT oder ROLLBACK.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Der Wert wird mit leerem Fallback, äußerem U+0020-Trimmen und Großschreibung normalisiert. Genau CONSOLE, RAW, TABLE und NONE sind erlaubt; sonst INVALID_PARAMETER/51011. CONSOLE zeigt Policies sowie Kontext, Quellenstatus und Warnungen, jedoch keine Predicate- oder Masked-Column-Fachzeilen. RAW liefert sieben getrennte Mengen in der Reihenfolge moduleStatus, databaseContext, securityPolicies, securityPredicates, maskedColumns, sourceStatus, warnings. TABLE schreibt angeforderte Teilmengen in vorbereitete lokale Temp-Tabellen. NONE liefert keine Resultsets. JSON und OUTPUTs sind unabhängig davon.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Außer bei TABLE sind NULL, leerer Text oder nur äußere U+0020-Leerzeichen zulässig; sonst INVALID_PARAMETER/51011. TABLE verlangt ein gültiges JSON-Objekt mit mindestens einer Zuordnung. Zulässige Schlüssel sind exakt moduleStatus, databaseContext, securityPolicies, securityPredicates, maskedColumns, sourceStatus und warnings; jeder Wert ist ein nichtleerer String mit vorhandenem lokalen #Temp-Ziel. Schlüssel- oder Zielduplikate und unbekannte Namen werden abgewiesen. ##, Namen über 116 Zeichen und #Monitor-Präfix sind unzulässig. Jedes Ziel muss leer sein und genau eine Seed-Spalte haben. Der Helfer prüft alle Ziele vor fachlichen Systemzugriffen; der spätere Writer ersetzt die Seed-Spalte durch das native Ergebnisschema. Die Schlüssel bedeuten: moduleStatus Modulstatus, databaseContext Datenbankkontext, securityPolicies sichtbare RLS-Policies, securityPredicates Predicate-Metadaten, maskedColumns Metadaten maskierter Spalten, sourceStatus Quellenstatus und warnings Warnungen.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Nur 1 erzeugt im normalen Pfad das JSON-Objekt mit meta und allen sieben Arrays: moduleStatus, databaseContext, securityPolicies, securityPredicates, maskedColumns, sourceStatus und warnings. NULL und 0 überspringen die Erzeugung. Die Resultsetart bleibt davon unabhängig; im äußeren Fehlerpfad wird @Json auf NULL gesetzt. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Als OUTPUT-Variable binden, um den JSON-Text zu empfangen. Der eingehende Wert wird am Aufrufanfang auf NULL zurückgesetzt; nur bei @JsonErzeugen=1 wird er im normalen Pfad gesetzt. Ohne Erzeugung, bei frühem Parameterfehler oder im äußeren CATCH bleibt er NULL. Die Hilfe erzeugt kein JSON. Optionaler Empfänger: Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden, andernfalls das Argument auslassen.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 1 gibt Meldungen an den vorgesehenen Parameterfehler-, Quellenfehler- und äußeren Fehlerstellen mit NOWAIT aus. NULL und 0 unterdrücken sie. Status, OUTPUT-Werte und Rückgabecode werden dadurch nicht geändert. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.

**@Hilfe:** @Hilfe bit; Default: 0. 1 beendet nach der Parameterhilfe und den Beispielen vor Validierung und Aufnahme. @StatusCodeOut wird AVAILABLE, @IsPartialOut 0; zuvor zurückgesetzte Fehler- und JSON-OUTPUTs bleiben NULL. Der bare RETURN ergibt Rückgabecode 0. NULL und 0 führen den normalen Pfad aus. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Als OUTPUT-Variable binden. Der Wert wird beim Eintritt zurückgesetzt. Hilfe liefert AVAILABLE; direkte Parameterfehler INVALID_PARAMETER; normale Aufnahmen liefern AVAILABLE_LIMITED, sobald mindestens eine der drei Fachquellen erfolgreich abgefragt wurde. AVAILABLE_LIMITED ist außerdem der Initialwert und bleibt erhalten, wenn ohne Kandidaten und ohne Auswahlwarnungen keine passende Statuszeile für die Fallback-Auswahl existiert; dieser Wert belegt daher keine erfolgreiche Katalogabfrage. Wenn keine Quelle diesen Status erreicht, übernimmt die Procedure den ersten Status ungleich AVAILABLE_LIMITED und SKIPPED nach DatabaseName und SourceKey; zwischen solchen Quellen gibt es keine Vorrangregel. Tatsächlich mögliche Werte: AVAILABLE (Hilfe), AVAILABLE_LIMITED (mindestens eine Fachquelle), DATABASE_UNAVAILABLE (Datenbankkontext/-quelle), SOURCE_UNAVAILABLE (Katalogquelle), SYSTEM_DATABASE_EXCLUDED (Auswahlwarnung), INVALID_PARAMETER (Vorprüfung/Helfer), INTERNAL_ERROR (Kandidaten-Temp-Schema), UNAVAILABLE_FEATURE (Regex-Voraussetzung), STATUS_UNAVAILABLE (fehlender Helferstatus), ERROR_HANDLED (äußerer CATCH ohne FailureStatus). Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Als bit-OUTPUT binden. Startwert wird NULL, bei Hilfe 0, bei direkter Parameterinvalidierung, normalem Ende und äußerem CATCH 1. Normale Erfolge bleiben partiell, weil Caller-Metadatensicht und vollständige RLS-/Maskingabdeckung unbewiesen sind und getrennte Quellen keinen gemeinsamen Snapshot bilden. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Als int-OUTPUT binden. Startwert NULL, auch bei Hilfe. Direkte Parameterfehler liefern 51011. Beim normalen Ende wird die erste nicht-NULL-Fehlernummer nach DatabaseId und SourceKey aus sourceStatus verwendet; ohne Quellenfehler bleibt NULL. Im äußeren CATCH hat FailureError Vorrang, sonst wird die abgefangene SQL-Fehlernummer ausgegeben. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Als OUTPUT-Variable binden. Startwert NULL, auch bei Hilfe. Direkte Parameterfehler liefern eine feste Parameterdiagnose. Normale Quellenfehler übernehmen die Meldung des ersten sourceStatus-Eintrags mit Fehlernummer nach DatabaseId und SourceKey. Im äußeren CATCH wird die vorbereitete Diagnose oder die native SQL-Fehlermeldung auf 2048 Zeichen begrenzt. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| databaseContext | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ContainmentDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| securityPolicies | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PolicyObjectId] int NOT NULL, [PolicyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SchemaId] int NOT NULL, [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [IsEnabled] bit NOT NULL, [IsNotForReplication] bit NOT NULL, [UsesDatabaseCollation] bit NOT NULL, [IsSchemabindingEnabled] bit NULL, [CreateDate] datetime NOT NULL, [ModifyDate] datetime NOT NULL |
| securityPredicates | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PolicyObjectId] int NOT NULL, [PredicateId] int NOT NULL, [TargetObjectId] int NOT NULL, [PredicateType] int NOT NULL, [PredicateTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [Operation] int NULL, [OperationDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| maskedColumns | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObjectId] int NOT NULL, [ColumnId] int NOT NULL, [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [TableName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsMasked] bit NOT NULL |
| sourceStatus | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| warnings | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory] @ResultSetArt='RAW', @MaxZeilen=100;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Getrennte lokale Katalogaufnahmen im Ausführungskontext des Callers; eingeschränkte Metadatensicht, Abdeckung und Richtlinienwirksamkeit bleiben unbewiesen.

Rein lesend; keine Berechtigungs- oder Policyaenderung.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_RowLevelSecurityAndMaskingInventory
Version      : 1.0.0
Stand        : 2026-10-26
Zweck        : Die Procedure inventarisiert sichtbare RLS-Policies, Predicate-Metadaten und Masked Columns.
Grenzen      : Getrennte lokale Katalogaufnahmen im Ausführungskontext des Callers; eingeschränkte Metadatensicht, Abdeckung und Richtlinienwirksamkeit bleiben unbewiesen.
Datenschutz  : Keine Predicate-Definitionen, Maskingfunktionen oder Tabellenwerte.
Nebenwirkung : Rein lesend; keine Berechtigungs- oder Policyaenderung.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_RowLevelSecurityAndMaskingInventory
Sichtbare RLS-Policies, Predicate-Metadaten und Masked Columns aus lokalen Katalogen der ausgewählten Datenbanken im aktuellen Ausführungskontext.
Die Aufnahme liest keine Tabellenwerte, Predicate-Definitionen oder Maskingfunktionen und bewertet weder Richtlinienwirksamkeit noch vollständige Metadatensicht.
RAW und JSON enthalten moduleStatus, databaseContext, securityPolicies, securityPredicates, maskedColumns, sourceStatus und warnings; TABLE schreibt nur die angeforderte gemappte Teilmenge; CONSOLE zeigt Policies, Kontext, Quellenstatus und Warnungen.
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
EXEC @ReturnCode=[monitor].[USP_RowLevelSecurityAndMaskingInventory]
      @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT
    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];
CREATE TABLE [#RowLevelSecurityAndMaskingInventory_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N'{"securityPolicies":"#RowLevelSecurityAndMaskingInventory_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
    SELECT * FROM [#RowLevelSecurityAndMaskingInventory_HelpExample];
    DROP TABLE IF EXISTS [#RowLevelSecurityAndMaskingInventory_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#RowLevelSecurityAndMaskingInventory_HelpExample];
    THROW;
END CATCH;
```


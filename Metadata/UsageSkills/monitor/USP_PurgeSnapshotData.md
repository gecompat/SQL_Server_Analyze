---
skill_format_version: "1.0.0"
name: "monitor.USP_PurgeSnapshotData"
schema_name: "monitor"
object_name: "USP_PurgeSnapshotData"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Bounded SC-023-Retentionlauf; löscht niemals nicht abgelaufene Evidenz."
source_path: "Code/10_SnapshotBaseline/100_USP_PurgeSnapshotData.sql"
---

# monitor.USP_PurgeSnapshotData

## Zweck und Einsatz

Bounded SC-023-Retentionlauf; löscht niemals nicht abgelaufene Evidenz.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_PurgeSnapshotData]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[monitor].[SnapshotTargetConfiguration]`, `[master].[sys].[databases]`, `[sys].[sp_getapplock]`, `[snapshot].[InternalPurgeExpiredData]`, `[sys].[sp_executesql]`, `[snapshot].[PurgeRun]`, `[sys].[sp_releaseapplock]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MaxBatches | int | nein | 10 |
| @Force | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @PurgeRunIdOut | bigint | nein | NULL OUTPUT |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@MaxBatches:** @MaxBatches: Datentyp int. Ganzzahl von 1 bis 1000 einschließlich; Obergrenze der Child-first-Schleifendurchläufe, keine globale Zeilenzahl. Je Durchlauf erfolgen begrenzte Deletes für MetricSample, PayloadSnapshot, ModuleStatus, CaptureRun und verwaiste Nicht-Server-Scopes; PurgeBatchRows begrenzt jedes Delete. Ein Durchlauf ohne Deletes beendet früher. NULL oder Werte außerhalb 1 bis 1000 sind ungültig. Default: 10.

**@Force:** @Force: Datentyp bit. 0 beachtet Purgeintervall; 1 umgeht nur dieses Intervall. Nicht abgelaufene Daten bleiben geschützt. NULL ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@ResultSetArt:** @ResultSetArt: Datentyp varchar(16). CONSOLE zeigt die priorisierte Purge-Laufzusammenfassung; RAW liefert die technische purge-Zeile; TABLE schreibt diese Zeile in das gemappte lokale Temp-Ziel; JSON stellt den JSON-Vertrag im @Json-OUTPUT bereit; NONE unterdrückt reguläre Resultsets. Zulässige Werte ausschließlich CONSOLE, RAW, TABLE, JSON, NONE. Außen getrimmt, Groß-/Kleinschreibung ignoriert; NULL/leer ungültig. Default: 'CONSOLE'.

**@ResultTablesJson:** @ResultTablesJson: Datentyp nvarchar(max). Nur TABLE: JSON-Objekt mit genau dem Schlüssel purge und einem Textwert als lokalem Temp-Tabellennamen, etwa N'{"purge":"#MyPurge"}'. Die Zieltabelle muss in derselben Sitzung vorhanden, leer und mit genau einer Seed-Spalte angelegt sein; der Writer passt sie an das Ergebnis an. Leeres Objekt, unbekannte oder doppelte Schlüssel, Nicht-Textwerte, ##- oder permanente Tabellen, Namen über 116 Zeichen sowie das reservierte Präfix #Monitor (ohne Beachtung der Großschreibung) sind unzulässig. Der Schlüssel purge ist case-sensitive. Bei TABLE sind NULL/leer/Leerzeichen ungültig; außerhalb TABLE sind sie zulässig, nichtleere Werte ungültig. Default: NULL.

**@JsonErzeugen:** @JsonErzeugen: Datentyp bit. 0 erzeugt JSON nur bei ResultSetArt JSON; 1 befüllt JSON-OUTPUT zusätzlich zu anderer Ausgabeart. NULL ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@Json:** @Json: Datentyp nvarchar(max) OUTPUT. nvarchar(max)-Variable mit OUTPUT; am Eintritt NULL. Bei JsonErzeugen=1 oder Ausgabeart JSON enthält das Objekt meta (contractVersion 1, resultName SnapshotPurge) und purge als Objekt, jeweils mit enthaltenen NULL-Werten. Bei Hilfe bleibt NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

**@PrintMeldungen:** @PrintMeldungen: Datentyp bit. 1 gibt am Ende für Statuswerte außer AVAILABLE, AVAILABLE_LIMITED und SKIPPED_NOT_DUE RAISERROR severity 10 mit NOWAIT aus; 0 unterdrückt. NULL wird nicht validiert und löst die IF-Ausgabe nicht aus. Default: 1. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@Hilfe:** @Hilfe: Datentyp bit. 1 druckt Hilfe und kehrt mit RETURN zurück; 0 normaler Ablauf. NULL wird nicht als 1 behandelt. OUTPUTs werden zuvor initialisiert. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@PurgeRunIdOut:** @PurgeRunIdOut: Datentyp bigint OUTPUT. bigint-Variable mit OUTPUT; initial NULL, enthält PurgeRun-ID falls vorhanden. Bei Hilfe NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

**@StatusCodeOut:** @StatusCodeOut: Datentyp varchar(40) OUTPUT. varchar(40)-Variable mit OUTPUT; initial AVAILABLE, danach tatsächlicher Status. Bei Hilfe AVAILABLE. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

**@IsPartialOut:** @IsPartialOut: Datentyp bit OUTPUT. bit-Variable mit OUTPUT; initial 0, danach gemäß Fehler-/Laufpfad. Bei Hilfe 0. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

**@ErrorNumberOut:** @ErrorNumberOut: Datentyp int OUTPUT. int-Variable mit OUTPUT; initial NULL, bei Fehler gegebenenfalls Fehlernummer. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

**@ErrorMessageOut:** @ErrorMessageOut: Datentyp nvarchar(2048) OUTPUT. OUTPUT-Parameter nvarchar(2048), mit nvarchar(2048)-Variable und OUTPUT zu binden; Kapazität entspricht 2048 UTF-16-Codeeinheiten. Initial NULL, bei Fehler gegebenenfalls Meldung. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| purge | 1 | 1 | [PurgeRunId] bigint NULL,[TargetDatabaseName] sysname NULL,[StartedAtUtc] datetime2(3) NULL,[EndedAtUtc] datetime2(3) NULL,[StatusCode] varchar(40) NOT NULL,[BatchesExecuted] int NOT NULL,[MetricRowsDeleted] bigint NOT NULL,[PayloadRowsDeleted] bigint NOT NULL,[ModuleRowsDeleted] bigint NOT NULL,[CaptureRunsDeleted] bigint NOT NULL,[ScopeRowsDeleted] bigint NOT NULL,[UsedDataMbBefore] decimal(19,3) NULL,[UsedDataMbAfter] decimal(19,3) NULL,[SoftBudgetMb] bigint NULL,[BudgetExceeded] bit NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_PurgeSnapshotData] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_PurgeSnapshotData erläutert alle Parameter; Hilfe bestätigt weder Target noch erfolgreichen Lauf.

Ausgelassene Argumente verwenden den jeweiligen Signaturdefault. Zeichenfolgen werden als T-SQL-Literale, Unicodewerte mit N-Präfix übergeben; Zahlen und bit-Werte als skalare Werte. Typkonvertierungen erfolgen vor der Procedure. Der normale Aufruf kann im optionalen Snapshotziel schreiben; @Hilfe=1 beendet vor diesen fachlichen Writes.

Sichere Hilfeaufrufe ohne Collection beziehungsweise Purge:


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Bounded SC-023-Retentionlauf; löscht niemals nicht abgelaufene Evidenz.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_PurgeSnapshotData erläutert alle Parameter; Hilfe bestätigt weder Target noch erfolgreichen Lauf.
Ausgelassene Argumente verwenden den jeweiligen Signaturdefault. Zeichenfolgen werden als T-SQL-Literale, Unicodewerte mit N-Präfix übergeben; Zahlen und bit-Werte als skalare Werte. Typkonvertierungen erfolgen vor der Procedure. Der normale Aufruf kann im optionalen Snapshotziel schreiben; @Hilfe=1 beendet vor diesen fachlichen Writes.
Sichere Hilfeaufrufe ohne Collection beziehungsweise Purge:
```


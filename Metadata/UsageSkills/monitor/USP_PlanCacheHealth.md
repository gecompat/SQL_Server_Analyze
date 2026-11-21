---
skill_format_version: "1.0.0"
name: "monitor.USP_PlanCacheHealth"
schema_name: "monitor"
object_name: "USP_PlanCacheHealth"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Bewertet Größe, Wiederverwendung und Zusammensetzung des aktuellen Plan Cache ohne Showplan-XML."
source_path: "Code/04_PlanCache/030_USP_PlanCacheHealth.sql"
---

# monitor.USP_PlanCacheHealth

## Zweck und Einsatz

Bewertet Größe, Wiederverwendung und Zusammensetzung des aktuellen Plan Cache ohne Showplan-XML.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.dm_exec_cached_plans, sys.dm_exec_sql_text, sys.dm_exec_plan_attributes, sys.configurations.

VIEW SERVER STATE bzw. SQL Server 2022+ VIEW SERVER PERFORMANCE STATE.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @AnalyseModus | varchar(16) | nein | 'SUMMARY' |
| @MitDatenbankVerteilung | bit | nein | 0 |
| @MitSingleUseDetails | bit | nein | 0 |
| @MaxZeilen | int | nein | 100 |
| @HighImpactConfirmed | bit | nein | 0 |
| @MaxSqlTextZeichen | int | nein | 4000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@AnalyseModus:** @AnalyseModus varchar(16). Default ist 'SUMMARY'. SUMMARY liefert Gesamtübersicht und Kategorien. VOLL prüft PLAN_CACHE_DEEP und erlaubt optionale Details. NULL entspricht SUMMARY. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte ergeben INVALID_PARAMETER.

**@MitDatenbankVerteilung:** @MitDatenbankVerteilung bit. Default ist 0. Bei 1 ergänzt die Zuordnung der gecachten Pläne nach dbid/Datenbank und aktiviert PLAN_CACHE_DEEP; nur zusammen mit @AnalyseModus=VOLL gültig. Bei 0 wird dieses Resultset ausgelassen. NULL verhält sich wie 0.

**@MitSingleUseDetails:** @MitSingleUseDetails bit. Default ist 0. Bei 1 ergänzt bis zu @MaxZeilen Single-use-Pläne samt SQL-Text, absteigend nach Cachegröße, und aktiviert PLAN_CACHE_DEEP; nur mit VOLL gültig. Bei 0 werden keine Einzeltexte geladen. NULL verhält sich wie 0.

**@MaxZeilen:** @MaxZeilen int. Default ist 100. Begrenzt die Anzahl der Single-use-Detailpläne in der Detailausgabe. Positiv begrenzt; NULL oder 0 bedeutet unbegrenzt. Negative Werte sind ungültig. In SUMMARY ohne Detailausgabe hat der Wert keine fachliche Wirkung.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 1 bestätigt den geschützten Pfad für VOLL oder angeforderte Details. Die Berechtigung wird zusätzlich geprüft. 0 bestätigt ihn nicht und NULL ist für die Pfadprüfung ungültig. Bei SUMMARY ohne Details wird diese Prüfung nicht aufgerufen.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int. Default ist 4000. Maximale Unicode-Zeichenlänge der SQL-Texte in der optionalen Single-use-Detailausgabe. Positiv kürzt und kennzeichnet; NULL oder 0 lässt vollständig. Negative Werte sind ungültig. Ohne Details wird kein SQL-Text projiziert.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. CONSOLE zeigt beschriftete Cachekategorien. RAW liefert Modulstatus, Gesamtübersicht, Kategorien und angeforderte Details. TABLE schreibt die Kategorien unter dem Schlüssel overview. NONE unterdrückt die fachlichen Resultsets. Rand-Leerzeichen werden entfernt und die Groß- und Kleinschreibung normalisiert. NULL, leere Eingaben und andere Werte ergeben INVALID_PARAMETER.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein JSON-Objekt mit genau dem Schlüssel overview und einem Tabellennamen als Zeichenfolgenwert erforderlich. Verwenden Sie eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und das Präfix #Monitor sind ausgeschlossen. Bei den übrigen Ausgabearten sind nur NULL, die leere Zeichenfolge und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in @Json zusätzlich zur gewählten Ausgabeart. 0 oder NULL deaktiviert JSON.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL. Bei @JsonErzeugen=1 enthält sie das JSON-Dokument mit Statusmetadaten, Gesamtübersicht, Kategorien und optionalen Details.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 gibt informative Meldungen zu Status und gegebenenfalls Textkürzung aus. 0 und NULL unterdrücken diese Meldungen.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 gibt die Hilfe aus und beendet den Aufruf vor der fachlichen Analyse. Die Initialisierung von @Json und die Prüfung der TABLE-Zuordnung laufen zuerst. 0 und NULL setzen den regulären Aufruf fort.

## Resultate und Ausgabe

1. Modulstatus. 2. Gesamtkennzahlen. 3. Verteilung nach Cache-/Objekttyp. 4. optionale Datenbankverteilung. 5. optionale Single-use-Details.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| overview | 1 | 1 | [CacheObjectType] nvarchar(34) COLLATE SQL_Latin1_General_CP1_CS_AS,[ObjectType] nvarchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS,[PlanCount] bigint,[TotalSizeBytes] bigint,[SingleUsePlanCount] bigint,[SingleUseSizeBytes] bigint,[TotalUseCounts] bigint,[AverageUseCount] decimal(19,4) |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC monitor.USP_PlanCacheHealth; EXEC monitor.USP_PlanCacheHealth @AnalyseModus='VOLL',@MitDatenbankVerteilung=1,@MitSingleUseDetails=1; EXEC monitor.USP_PlanCacheHealth @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_PlanCacheHealth

Die Procedure zeigt Größe und Zusammensetzung des sichtbaren Plan Cache und kann Single-Use-Pläne und Datenbankverteilung aufschlüsseln. Showplan-Nutzung kann usecounts beeinflussen.

Hilfe anzeigen. EXEC [monitor].[USP_PlanCacheHealth] @Hilfe=1;

Technische Resultsets lesen. EXEC [monitor].[USP_PlanCacheHealth] @AnalyseModus='SUMMARY', @ResultSetArt='RAW';

Nur JSON ausgeben. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_PlanCacheHealth] @AnalyseModus='SUMMARY', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_PlanCacheHealth
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Bewertet Größe, Wiederverwendung und Zusammensetzung des aktuellen
               Plan Cache ohne Showplan-XML.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_exec_cached_plans, sys.dm_exec_sql_text,
               sys.dm_exec_plan_attributes, sys.configurations.
Parameter    : @AnalyseModus, @MitDatenbankVerteilung, @MitSingleUseDetails,
               @MaxZeilen, @MaxSqlTextZeichen, @PrintMeldungen, @Hilfe.
Resultsets   : 1. Modulstatus. 2. Gesamtkennzahlen. 3. Verteilung nach Cache-/Objekttyp.
               4. optionale Datenbankverteilung. 5. optionale Single-use-Details.
Berechtigung : VIEW SERVER STATE bzw. SQL Server 2022+ VIEW SERVER PERFORMANCE STATE.
Eigenlast    : Basis gruppiert die Plan-Cache-DMV. Datenbankverteilung und Details
               sind opt-in und PLAN_CACHE_DEEP-geschützt.
Locking      : Keine Benutzerobjekte.
Partial      : Optionale Resultsets werden unabhängig behandelt.
Beispiele    : EXEC monitor.USP_PlanCacheHealth;
               EXEC monitor.USP_PlanCacheHealth @AnalyseModus='VOLL',@MitDatenbankVerteilung=1,@MitSingleUseDetails=1;
               EXEC monitor.USP_PlanCacheHealth @Hilfe=1;
Änderungen   : 1.0.1 - Stabile Summenzeile auch bei leerem Zwischenergebnis.
               1.0.0 - Erstfassung Phase 3.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_PlanCacheHealth
Die Procedure zeigt Größe und Zusammensetzung des sichtbaren Plan Cache und kann Single-Use-Pläne und Datenbankverteilung aufschlüsseln. Showplan-Nutzung kann usecounts beeinflussen.
Hilfe anzeigen. EXEC [monitor].[USP_PlanCacheHealth] @Hilfe=1;
Technische Resultsets lesen. EXEC [monitor].[USP_PlanCacheHealth] @AnalyseModus='SUMMARY', @ResultSetArt='RAW';
Nur JSON ausgeben. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_PlanCacheHealth] @AnalyseModus='SUMMARY', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];
Benanntes Resultset in eine lokale Temp-Tabelle schreiben. CREATE TABLE #PlanCacheHealth_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_PlanCacheHealth] @AnalyseModus='SUMMARY', @ResultSetArt='TABLE', @ResultTablesJson=N'{"overview":"#PlanCacheHealth_HelpExample"}'; SELECT * FROM #PlanCacheHealth_HelpExample; DROP TABLE #PlanCacheHealth_HelpExample; END TRY BEGIN CATCH DROP TABLE #PlanCacheHealth_HelpExample; THROW; END CATCH;
```


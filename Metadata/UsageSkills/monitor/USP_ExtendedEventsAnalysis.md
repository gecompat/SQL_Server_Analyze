---
skill_format_version: "1.0.0"
name: "monitor.USP_ExtendedEventsAnalysis"
schema_name: "monitor"
object_name: "USP_ExtendedEventsAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Orchestriert Extended-Events-Inventar und Forensik mit einheitlichem Ausgabe- und Namensvertrag."
source_path: "Code/06_ExtendedEvents/060_USP_ExtendedEventsAnalysis.sql"
---

# monitor.USP_ExtendedEventsAnalysis

## Zweck und Einsatz

Orchestriert Extended-Events-Inventar und Forensik mit einheitlichem Ausgabe- und Namensvertrag.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_ExtendedEventsAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[USP_ExtendedEventsSessions]`, `[monitor].[USP_ExtendedEventsTargetRuntime]`, `[monitor].[USP_ExtendedEventsReadEvents]`, `[monitor].[USP_ExtendedEventsDeadlocks]`, `[monitor].[USP_ExtendedEventsBlockedProcesses]`, `[monitor].[InternalEmitConsoleResult]`, `[monitor].[InternalWriteResultTable]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SourceExtendedEventSessionName | nvarchar(258) | nein | N'system_health' |
| @ExtendedEventSessionNames | nvarchar(max) | nein | NULL |
| @ExtendedEventSessionNamePattern | nvarchar(4000) | nein | NULL |
| @EventNames | nvarchar(max) | nein | NULL |
| @EventNamePattern | nvarchar(4000) | nein | NULL |
| @TargetNames | nvarchar(max) | nein | NULL |
| @TargetNamePattern | nvarchar(4000) | nein | NULL |
| @Quelle | varchar(20) | nein | 'AUTO' |
| @FilePath | nvarchar(4000) | nein | NULL |
| @VonUtc | datetime2(7) | nein | NULL |
| @BisUtc | datetime2(7) | nein | NULL |
| @MitSessionInventar | bit | nein | 1 |
| @MitTargetRuntime | bit | nein | 0 |
| @MitEvents | bit | nein | 0 |
| @MitDeadlocks | bit | nein | 0 |
| @MitBlockedProcesses | bit | nein | 0 |
| @MaxZeilen | int | nein | 100 |
| @BestaetigeTargetFlush | bit | nein | 0 |
| @HighImpactConfirmed | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@SourceExtendedEventSessionName:** @SourceExtendedEventSessionName nvarchar(258). Default ist N'system_health'. Einzelner Forensik-Quell-Sessionsname, Standard system_health. Nur an aktivierte ReadEvents-, Deadlocks- und BlockedProcesses-Children; nicht an Inventar-Children. ReadEvents und Deadlocks lehnen NULL/leeren/ungültigen/mehrteiligen Namen ab. BlockedProcesses verwendet NULL zur automatischen Auswahl und lehnt leere/ungültige explizite Namen ab.

**@ExtendedEventSessionNames:** @ExtendedEventSessionNames nvarchar(max). Default ist NULL. NULL deaktiviert den Exaktnamenfilter. Sonst pipe-getrennte Liste exakter einteiliger SQL-Namen; Klammerung und ]] Escape unterstützt. Leere Liste/ungültige Namen ungültig. Nicht kombinierbar mit ExtendedEventSessionNamePattern. Wird an Sessions- und TargetRuntime-Children geleitet.

**@ExtendedEventSessionNamePattern:** @ExtendedEventSessionNamePattern nvarchar(4000). Default ist NULL. NULL deaktiviert den Musterfilter. Andernfalls nichtleeres LIKE-Muster, optional mit LIKE:, REGEX: oder REGEXI:; äußere Leerzeichen werden entfernt. Leeres Muster oder leerer Präfixwert ist ungültig. LIKE unterstützt % und _. Regex benötigt SQL Server 2025 mit Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit ExtendedEventSessionNames kombinierbar. Wird an Sessions-/TargetRuntime-Children geleitet.

**@EventNames:** @EventNames nvarchar(max). Default ist NULL. NULL deaktiviert den exakten Eventnamenfilter. Andernfalls pipe-getrennte Liste exakter einteiliger SQL-Namen; leere Liste/ungültige Namen werden abgelehnt. Nicht mit EventNamePattern kombinierbar. Wird an Sessions- und ReadEvents-Children geleitet.

**@EventNamePattern:** @EventNamePattern nvarchar(4000). Default ist NULL. NULL deaktiviert den Musterfilter. Andernfalls nichtleeres Muster mit optionalem LIKE:, REGEX: oder REGEXI:-Präfix; äußere Leerzeichen werden getrimmt. Leeres Muster/Präfixwert ungültig. LIKE unterstützt % und _. Regex erfordert SQL Server 2025 / Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit EventNames kombinierbar.

**@TargetNames:** @TargetNames nvarchar(max). Default ist NULL. NULL deaktiviert den Exaktnamenfilter. Sonst pipe-getrennte Liste exakter einteiliger SQL-Namen; Klammerung und ]] Escape unterstützt. Leere Liste/ungültige Namen ungültig. Nicht kombinierbar mit TargetNamePattern. Wird an Sessions-/TargetRuntime-Children geleitet.

**@TargetNamePattern:** @TargetNamePattern nvarchar(4000). Default ist NULL. NULL deaktiviert den Musterfilter. Andernfalls nichtleeres Muster mit optionalem LIKE:, REGEX: oder REGEXI:-Präfix; äußere Leerzeichen werden getrimmt. Leeres Muster oder leerer Präfixwert ungültig. LIKE verwendet % und _. Regex benötigt SQL Server 2025 / Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit TargetNames kombinierbar. Wird an Sessions-/TargetRuntime-Children geleitet.

**@Quelle:** @Quelle varchar(20). Default ist 'AUTO'. Getrimmt/großgeschrieben; zulässig AUTO, EVENT_FILE, RING_BUFFER. Quellwahl für Forensik-Children.

**@FilePath:** @FilePath nvarchar(4000). Default ist NULL. Optionaler XEL-Dateipfad, an aktivierte Forensik-Children geleitet; NULL überlässt Pfadauswahl dem Child. Leerverhalten childabhängig.

**@VonUtc:** @VonUtc datetime2(7). Default ist NULL. Unverändert an ReadEvents, Deadlocks und BlockedProcesses geleitet. ReadEvents: NULL lässt untere inklusive Grenze aus. Deadlocks/BlockedProcesses: NULL bedeutet UTC jetzt minus 24 Stunden.

**@BisUtc:** @BisUtc datetime2(7). Default ist NULL. Unverändert an die aktivierten Forensik-Children geleitet. NULL lässt die exklusive obere Grenze aus.

**@MitSessionInventar:** @MitSessionInventar bit. Default ist 1. Eingabe als bit-Wert 0 oder 1. Andere SQL-Argumente unterliegen vor Prozedureintritt der bit-Typkonvertierung; die Procedure besitzt keine eigene Leertextnormalisierung. 0 deaktiviert das Teilmodul. NULL aktiviert es nicht und wird nicht normalisiert. Die Leerscope-Prüfung lehnt nur fünf exakte 0-Werte ab. Enthält eine sonst inaktive Auswahl NULL, kann der Parent AVAILABLE ohne Kindaufruf liefern. 1 ruft USP_ExtendedEventsSessions mit Session-, Event- und Targetfiltern sowie MaxZeilen auf; SourceExtendedEventSessionName wird nicht weitergeleitet.

**@MitTargetRuntime:** @MitTargetRuntime bit. Default ist 0. Eingabe als bit-Wert 0 oder 1. Andere SQL-Argumente unterliegen vor Prozedureintritt der bit-Typkonvertierung; die Procedure besitzt keine eigene Leertextnormalisierung. 0 deaktiviert das Teilmodul. NULL aktiviert es nicht und wird nicht normalisiert. Die Leerscope-Prüfung lehnt nur fünf exakte 0-Werte ab. Enthält eine sonst inaktive Auswahl NULL, kann der Parent AVAILABLE ohne Kindaufruf liefern. 1 ruft USP_ExtendedEventsTargetRuntime mit Session- und Targetfiltern auf. Das DMV-Lesen verlangt Flushbestätigung 1 und das Deep-Analysis-Gate.

**@MitEvents:** @MitEvents bit. Default ist 0. Eingabe als bit-Wert 0 oder 1. Andere SQL-Argumente unterliegen vor Prozedureintritt der bit-Typkonvertierung; die Procedure besitzt keine eigene Leertextnormalisierung. 0 deaktiviert das Teilmodul. NULL aktiviert es nicht und wird nicht normalisiert. Die Leerscope-Prüfung lehnt nur fünf exakte 0-Werte ab. Enthält eine sonst inaktive Auswahl NULL, kann der Parent AVAILABLE ohne Kindaufruf liefern. 1 ruft USP_ExtendedEventsReadEvents auf und leitet SourceExtendedEventSessionName, Quelle, FilePath, Eventfilter, UTC-Grenzen, MaxZeilen sowie BestaetigeTargetFlush und HighImpactConfirmed weiter.

**@MitDeadlocks:** @MitDeadlocks bit. Default ist 0. Eingabe als bit-Wert 0 oder 1. Andere SQL-Argumente unterliegen vor Prozedureintritt der bit-Typkonvertierung; die Procedure besitzt keine eigene Leertextnormalisierung. 0 deaktiviert das Teilmodul. NULL aktiviert es nicht und wird nicht normalisiert. Die Leerscope-Prüfung lehnt nur fünf exakte 0-Werte ab. Enthält eine sonst inaktive Auswahl NULL, kann der Parent AVAILABLE ohne Kindaufruf liefern. 1 ruft USP_ExtendedEventsDeadlocks auf und leitet SourceExtendedEventSessionName, Quelle, FilePath, UTC-Grenzen, MaxZeilen sowie BestaetigeTargetFlush und HighImpactConfirmed weiter.

**@MitBlockedProcesses:** @MitBlockedProcesses bit. Default ist 0. Eingabe als bit-Wert 0 oder 1. Andere SQL-Argumente unterliegen vor Prozedureintritt der bit-Typkonvertierung; die Procedure besitzt keine eigene Leertextnormalisierung. 0 deaktiviert das Teilmodul. NULL aktiviert es nicht und wird nicht normalisiert. Die Leerscope-Prüfung lehnt nur fünf exakte 0-Werte ab. Enthält eine sonst inaktive Auswahl NULL, kann der Parent AVAILABLE ohne Kindaufruf liefern. 1 ruft USP_ExtendedEventsBlockedProcesses auf und leitet SourceExtendedEventSessionName, Quelle, FilePath, UTC-Grenzen, MaxZeilen sowie BestaetigeTargetFlush und HighImpactConfirmed weiter.

**@MaxZeilen:** @MaxZeilen int. Default ist 100. Negative Werte ungültig. An Children weitergeleitet; NULL oder 0 bedeutet dort unbegrenzt. Ein Zeilenlimit garantiert kein vorzeitiges oder vollständiges Überspringen des physischen XEL-Lesens. Modulstatus wird nicht gekürzt.

**@BestaetigeTargetFlush:** @BestaetigeTargetFlush bit. Default ist 0. Explizit 0 oder 1 übergeben; nicht NULL. An Children geleitet. 1 nur nach bewusster Bestätigung setzen, weil Targetzugriffe einen Flush auslösen können.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. An aktivierte Forensikchildren und TargetRuntime geleitete Policybestätigung für Deep-Analysis.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. Getrimmt/großgeschrieben; zulässig RAW, CONSOLE, NONE, TABLE. TABLE schreibt moduleStatus; CONSOLE/TABLE unterdrücken Child-Resultsets intern.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Nur mit TABLE. Nichtleeres JSON-Objekt mit genau dem Schlüssel moduleStatus und dem Namen einer vorhandenen, leeren lokalen #temp-Tabelle mit genau einer NULL-zulässigen Seed-Spalte. NULL/Leerwert, fehlerhafte Zuordnung, Zusatzschlüssel, befülltes Ziel, globale/permanente Tabelle und #Monitor-Präfix werden abgelehnt.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt Parent-JSON-Hülle mit meta, inventory, targetRuntime, events, deadlocks, blockedProcesses und warnings; 0 lässt @Json NULL.

**@Json:** @Json nvarchar(max). Default ist NULL. OUTPUT, wird anfangs NULL gesetzt; enthält bei JsonErzeugen=1 die Parent-JSON-Hülle.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 aktiviert Child-/Parent-Warnmeldungen; 0 unterdrückt sie.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 druckt Kurzhilfe und kehrt vor Ausführung zurück.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ExecutionOrdinal] tinyint NOT NULL , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ExtendedEventsAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_ExtendedEventsAnalysis

Beispiel 1: EXEC [monitor].[USP_ExtendedEventsAnalysis] @Hilfe=1;

Beispiel 2: EXEC [monitor].[USP_ExtendedEventsAnalysis] @ExtendedEventSessionNames=N'ExampleXeSession', @MitSessionInventar=1, @MitTargetRuntime=0, @MitEvents=0, @MitDeadlocks=0, @MitBlockedProcesses=0, @ResultSetArt='RAW';

Beispiel 3: DECLARE @xeFrom datetime2(7)=DATEADD(hour,-1,SYSUTCDATETIME()), @xeTo datetime2(7)=SYSUTCDATETIME(), @xeJson nvarchar(max); EXEC [monitor].[USP_ExtendedEventsAnalysis] @SourceExtendedEventSessionName=N'ExampleXeSession', @Quelle='AUTO', @VonUtc=@xeFrom, @BisUtc=@xeTo, @MitSessionInventar=0, @MitEvents=1, @MaxZeilen=50, @BestaetigeTargetFlush=1, @HighImpactConfirmed=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@xeJson OUTPUT; SELECT @xeJson AS JsonResult;

Beispiel 4: CREATE TABLE #ExtendedEventsAnalysis_HelpExample (Seed int NULL); BEGIN TRY EXEC [monitor].[USP_ExtendedEventsAnalysis] @MitSessionInventar=1, @MitTargetRuntime=0, @MitEvents=0, @MitDeadlocks=0, @MitBlockedProcesses=0, @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#ExtendedEventsAnalysis_HelpExample"}'; SELECT * FROM #ExtendedEventsAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #ExtendedEventsAnalysis_HelpExample; THROW; END CATCH; DROP TABLE #ExtendedEventsAnalysis_HelpExample;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ExtendedEventsAnalysis
Version      : 2.0.1
Stand        : 2026-07-16
Zweck        : Orchestriert Extended-Events-Inventar und Forensik mit
               einheitlichem Ausgabe- und Namensvertrag.
Änderungen   : 2.0.1 - IF/TRY/CATCH-Blöcke syntaktisch eindeutig strukturiert.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ExtendedEventsAnalysis
Beispiel 1: EXEC [monitor].[USP_ExtendedEventsAnalysis] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_ExtendedEventsAnalysis] @ExtendedEventSessionNames=N'ExampleXeSession', @MitSessionInventar=1, @MitTargetRuntime=0, @MitEvents=0, @MitDeadlocks=0, @MitBlockedProcesses=0, @ResultSetArt='RAW';
Beispiel 3: DECLARE @xeFrom datetime2(7)=DATEADD(hour,-1,SYSUTCDATETIME()), @xeTo datetime2(7)=SYSUTCDATETIME(), @xeJson nvarchar(max); EXEC [monitor].[USP_ExtendedEventsAnalysis] @SourceExtendedEventSessionName=N'ExampleXeSession', @Quelle='AUTO', @VonUtc=@xeFrom, @BisUtc=@xeTo, @MitSessionInventar=0, @MitEvents=1, @MaxZeilen=50, @BestaetigeTargetFlush=1, @HighImpactConfirmed=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@xeJson OUTPUT; SELECT @xeJson AS JsonResult;
Beispiel 4: CREATE TABLE #ExtendedEventsAnalysis_HelpExample (Seed int NULL); BEGIN TRY EXEC [monitor].[USP_ExtendedEventsAnalysis] @MitSessionInventar=1, @MitTargetRuntime=0, @MitEvents=0, @MitDeadlocks=0, @MitBlockedProcesses=0, @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#ExtendedEventsAnalysis_HelpExample"}'; SELECT * FROM #ExtendedEventsAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #ExtendedEventsAnalysis_HelpExample; THROW; END CATCH; DROP TABLE #ExtendedEventsAnalysis_HelpExample;
```


---
skill_format_version: "1.0.0"
name: "monitor.USP_PerformanceCounters"
schema_name: "monitor"
object_name: "USP_PerformanceCounters"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liest gefilterte Performance-Counter und interpretiert unterstützte cntr_type-Werte; unbekannte Typen bleiben Rohwerte."
source_path: "Code/08_ServerHealth/130_USP_PerformanceCounters.sql"
---

# monitor.USP_PerformanceCounters

## Zweck und Einsatz

Liest gefilterte Performance-Counter und interpretiert unterstützte cntr_type-Werte; unbekannte Typen bleiben Rohwerte.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_PerformanceCounters] im vorgesehenen Datenbankkontext. Die Procedure liest `sys.dm_os_performance_counters` und `sys.dm_os_sys_info` sowie Frameworkparser; bei Sampling erfolgen zwei Quellaufnahmen, keine aktive Workload-Ausführung.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @ObjectNames | nvarchar(max) | nein | NULL |
| @CounterNames | nvarchar(max) | nein | NULL |
| @SampleSeconds | tinyint | nein | 0 |
| @MaxZeilen | int | nein | 1000 |
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

**@ObjectNames:** @ObjectNames nvarchar(max); Default: NULL. Optionaler Filter auf Objektbezeichnungen aus sys.dm_os_performance_counters. Mehrere Werte werden als bracket-aware Pipe-Liste durch monitor.TVF_ParseStringList geparst. Äußere Leerzeichen werden entfernt; Pipe-Zeichen in eckig geklammerten Werten bleiben erhalten, ]] maskiert eine schließende Klammer. Der entquotierte StringValue wird case-sensitive verglichen. NULL lässt alle Objekte zu. Leerstring, leeres Element, ungültige Klammerstruktur, leerer entquotierter Wert oder ein Segment über 4000 UTF-16-Codeeinheiten ergibt INVALID_PARAMETER. Duplikate bleiben erhalten, ändern den EXISTS-Filter aber nicht. Wildcards sind Literale.

**@CounterNames:** @CounterNames nvarchar(max); Default: NULL. Optionaler Filter auf Counterbezeichnungen mit derselben bracket-aware Pipe-Syntax und denselben Parsergrenzen. NULL lässt alle Counter zu. Der direkte Vergleich ist case-sensitive; zusätzlich wird Name plus N' base' case-insensitive einbezogen, damit die Basiscounter für Quotienten verfügbar sind. Ungültige Listenelemente ergeben INVALID_PARAMETER. Duplikate ändern den EXISTS-Filter nicht; Wildcards werden nicht als Muster ausgewertet.

**@SampleSeconds:** @SampleSeconds tinyint; Default: 0. Angabe in Sekunden. 0 liest zwei unmittelbar aufeinanderfolgende DMV-Stände ohne WAITFOR und erzwingt für Delta-Typen SAMPLE_REQUIRED_FOR_DELTA_METRIC. 1 bis 60 wartet zwischen den Messungen; verwendet wird die tatsächlich gemessene Dauer. Zulässig sind gebundene tinyint-Werte von 0 bis 60; Wird nach dem TABLE-Preflight kein Hilfezweig ausgeführt, ergeben Werte über 60 oder NULL vor beiden DMV-Messständen INVALID_PARAMETER mit IsPartial=1. Textwerte durchlaufen vor Prozedureintritt die SQL-Typkonvertierung; Leertext hat keinen eigenen Sonderdefault. Der SQL-Typ tinyint erlaubt 0 bis 255, der Procedure-Vertrag nur 0 bis 60. Typen: 65792 RAW_SNAPSHOT; 272696320 und 272696576 RATE_PER_SECOND (Delta geteilt durch Samplesekunden); 537003264 FRACTION_DELTA_PERCENT (100 mal Zählerdelta geteilt durch Basisdelta); 1073874176 AVERAGE_DELTA_RATIO (Zählerdelta geteilt durch Basisdelta); weitere Typen RAW_UNINTERPRETED. Deltas erfordern einen nicht fallenden Zähler; Quotienten zusätzlich eine vorhandene, steigende Basis. Basiscountertypen 1073939458 und 1073939712 werden nicht als Ergebniszeilen ausgegeben. Keine Persistenz. Die gemessene Dauer beginnt vor dem Temp-Tabellenaufbau und dem ersten DMV-Lesen und endet vor dem zweiten Lesen; sie ist keine reine WAITFOR-Dauer.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. Nichtnegative int-Anzahl. Werte unter 0 ergeben INVALID_PARAMETER. Werte von 1 bis 2147483647 begrenzen RAW-Counterzeilen und JSON-Countereinträge; CONSOLE und TABLE geben alle materialisierten Counter aus. 0 und NULL werden für RAW/JSON auf die größte bigint-TOP-Grenze abgebildet. TOP greift erst nach beiden Snapshots, Interpretation und Materialisierung; Quellarbeit wird nicht begrenzt. RAW und JSON sind nach ObjectName, CounterName und InstanceName sortiert; keine repräsentative Stichprobe.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Ausgabeart, normalisiert mit LTRIM/RTRIM und UPPER. RAW liefert Status und technische Counterzeilen; CONSOLE gibt alle materialisierten Counter über den Helfer aus, ohne separates Statusresultset (bei leerer Quelle kann der Helfer eine Hinweiszeile liefern); TABLE gibt alle materialisierten Counter als Resultset counters in das zugeordnete lokale Ziel aus, ohne separates Statusresultset; NONE unterdrückt reguläre Resultsets. Gültig sind ausschließlich RAW, CONSOLE, TABLE und NONE; NULL oder Leertext ist ungültig. CONSOLE und TABLE werden intern als NONE verarbeitet und anschließend über Helfer beziehungsweise Ziel ausgegeben. JSON ist unabhängig von ResultSetArt. Das TOP-Limit und die genannte Sortierung gelten nur für RAW-/JSON-Counterausgaben.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Optionales JSON-Mapping auf das lokale #temp-Ziel des einzigen TABLE-Resultsets counters. Nur bei ResultSetArt=TABLE zulässig; ein nichtleerer, getrimmter Wert in einer anderen Ausgabeart löst Fehler 51011 vor Hilfe- und Statusverarbeitung aus. NULL, leer oder nur Leerzeichen bedeutet kein Mapping. Der TABLE-Preflight läuft vor dem Hilfezweig und kann daher auch bei Hilfe scheitern.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit-Schalter: 0 unterdrückt JSON, 1 erzeugt es; NULL aktiviert den Zweig nicht. Das Objekt enthält meta, counters und warnings; warnings ist ein leeres Array, counters unterliegt MaxZeilen. JSON kann mit jeder Ausgabeart erzeugt werden.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Empfänger vom Typ nvarchar(max). Der Eingabewert wird beim Eintritt auf NULL gesetzt, auch bei Hilfe. Mit JsonErzeugen=1 wird später JSON mit meta, counters und warnings zugewiesen; andernfalls bleibt der Wert NULL. Im EXEC mit einer nvarchar(max)-Variablen und OUTPUT binden.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit-Schalter: 0 unterdrückt Meldungen; 1 sendet bei StatusCode ungleich AVAILABLE eine Severity-10-Meldung mit RAISERROR ... WITH NOWAIT. NULL aktiviert die Meldung nicht. Der Text ist ErrorMessage oder ersatzweise der Statuscode. Die Meldung steuert die Resultsets nicht.

**@Hilfe:** @Hilfe bit; Default: 0. Bit-Schalter: 1 druckt Kurzinfos und kehrt vor dem Sampling sowie vor allen vier Status-OUTPUT-Zuweisungen zurück; NULL/0 führt regulär aus. Json wird zuvor bereits auf NULL gesetzt. Ein unzulässiges nichtleeres ResultTablesJson außerhalb TABLE sowie der TABLE-Preflight werden vor dem Hilfezweig verarbeitet.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT varchar(40) mit globalem Status: AVAILABLE bei erfolgreichem Pfad; INVALID_PARAMETER bei ungültigen Listen-, Sample-, Zeilen- oder Ausgabeangaben; UNAVAILABLE_OBJECT ohne Counterzeilen oder nach Ausschluss nicht auswertbarer Basiscounter; DENIED_PERMISSION bei abgefangenen Fehlernummern 229, 262, 297, 300 oder 371; sonst ERROR_HANDLED. Hilfe lässt den Empfänger unverändert. Mit @StatusCodeOut=@Variable OUTPUT binden.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT bit: 1 bei INVALID_PARAMETER, UNAVAILABLE_OBJECT oder abgefangenem Fehler, sonst 0. Das Flag beschreibt nur den vom Modul erkannten Partialzustand und beweist keine allgemeine Vollständigkeit. Hilfe lässt den Empfänger unverändert; mit OUTPUT binden.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT int mit abgefangener SQL-Fehlernummer; im normalen Pfad NULL. Hilfe weist den Wert nicht zu und lässt den Empfänger unverändert. Mit @ErrorNumberOut=@Variable OUTPUT binden.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT nvarchar(2048) mit Validierungs-/Unavailable-Text oder abgefangener ERROR_MESSAGE; im regulären AVAILABLE-Pfad NULL. Hilfe weist den Wert nicht zu und lässt den Empfänger unverändert. Mit @ErrorMessageOut=@Variable OUTPUT binden.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| counters | 1 | 1 | [ObjectName] nvarchar(128) NOT NULL , [CounterName] nvarchar(128) NOT NULL , [InstanceName] nvarchar(128) NOT NULL , [CounterType] int NOT NULL , [Interpretation] varchar(40) NOT NULL , [MetricValue] decimal(38,6) NULL , [MetricUnit] varchar(40) NOT NULL , [BeforeValue] bigint NULL , [AfterValue] bigint NOT NULL , [BaseBeforeValue] bigint NULL , [BaseAfterValue] bigint NULL , [DeltaValue] bigint NULL , [BaseDeltaValue] bigint NULL , [SampleSeconds] decimal(19,6) NULL , [SqlServerStartTime] datetime2(3) NULL , [FindingCode] varchar(80) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_PerformanceCounters] @ObjectNames=N'[SQL Statistics]',@CounterNames=N'Batch Requests/sec',@SampleSeconds=5,@ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Universelle Alarmgrenzen werden nicht behauptet. Rate-Counter benötigen ein Sample; Counterreset wird als solcher markiert.

Optionales WAITFOR für 1 bis 60 Sekunden; keine Persistenz.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_PerformanceCounters
Version      : 1.1.0
Stand        : 2026-07-18
Zweck        : Liest gefilterte Performance-Counter und interpretiert
               unterstützte cntr_type-Werte; unbekannte Typen bleiben Rohwerte.
Datenquellen : sys.dm_os_performance_counters, sys.dm_os_sys_info.
Grenzen      : Universelle Alarmgrenzen werden nicht behauptet. Rate-Counter
               benötigen ein Sample; Counterreset wird als solcher markiert.
Nebenwirkung : Optionales WAITFOR für 1 bis 60 Sekunden; keine Persistenz.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_PerformanceCounters
Objekt-/Counterfilter sind bracket-aware Pipe-Listen; Wildcards werden als Literale behandelt.
SampleSeconds 0 liest zweimal unmittelbar nacheinander; 1..60 wartet zwischen Messpunkten.
Delta-, Reset- und Basisfehler erhalten eigene FindingCodes.
Unterstützte cntr_type-Werte liefern Snapshot, Rate, Prozent oder Quotient; übrige bleiben Rohwerte.
MaxZeilen begrenzt nur RAW-Counterzeilen und JSON-Countereinträge nach Messung und Interpretation; CONSOLE und TABLE geben alle materialisierten Counter aus.
TABLE exportiert counters; JSON kann parallel zu jeder Ausgabeart erzeugt werden.
Hilfe kehrt vor Sampling und Status-OUTPUT-Zuweisung zurück.
DECLARE @ExampleJson nvarchar(max)=NULL; EXEC [monitor].[USP_PerformanceCounters] @JsonErzeugen=1,@Json=@ExampleJson OUTPUT,@ResultSetArt='NONE'; SELECT @ExampleJson;
DECLARE @ExampleMap nvarchar(max)=CONCAT(N'{',NCHAR(34),N'counters',NCHAR(34),N':',NCHAR(34),N'#PerformanceCounters_HelpExample',NCHAR(34),N'}'); CREATE TABLE #PerformanceCounters_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_PerformanceCounters] @ResultSetArt='TABLE',@ResultTablesJson=@ExampleMap; SELECT * FROM #PerformanceCounters_HelpExample; DROP TABLE #PerformanceCounters_HelpExample; END TRY BEGIN CATCH DROP TABLE IF EXISTS #PerformanceCounters_HelpExample; THROW; END CATCH;
```


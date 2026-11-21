---
skill_format_version: "1.0.0"
name: "monitor.USP_StatisticsDistributionAnalysis"
schema_name: "monitor"
object_name: "USP_StatisticsDistributionAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Analysiert begrenzt und opt-in die Verteilung sichtbarer Statistikhistogramme sowie die Änderungsvariation inkrementeller Statistikpartitionen."
source_path: "Code/03_ObjectIndex/045_USP_StatisticsDistributionAnalysis.sql"
---

# monitor.USP_StatisticsDistributionAnalysis

## Zweck und Einsatz

Analysiert begrenzt und opt-in die Verteilung sichtbarer Statistikhistogramme sowie die Änderungsvariation inkrementeller Statistikpartitionen.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_StatisticsDistributionAnalysis] im vorgesehenen Datenbankkontext. Die Procedure liest Statistik-/Spaltenkataloge und `sys.dm_db_stats_histogram` in den ausgewählten Datenbanken. Metadatenverbergung und Berechtigungen können eine Datenbank/Statistik auslassen oder als Fehler begrenzen.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @SchemaNames | nvarchar(max) | nein | NULL |
| @SchemaNamePattern | nvarchar(4000) | nein | NULL |
| @ObjectNames | nvarchar(max) | nein | NULL |
| @ObjectNamePattern | nvarchar(4000) | nein | NULL |
| @FullObjectNames | nvarchar(max) | nein | NULL |
| @StatisticsNames | nvarchar(max) | nein | NULL |
| @StatisticsNamePattern | nvarchar(4000) | nein | NULL |
| @AnalyseModus | varchar(16) | nein | 'GEZIELT' |
| @MaxVerteilungsStatistiken | int | nein | 50 |
| @MinVerteilungsZeilen | bigint | nein | 1000 |
| @SkewWarnFaktor | decimal(19,4) | nein | 10 |
| @DominanterSchrittWarnPercent | decimal(9,4) | nein | 50 |
| @ModificationWarnPercent | decimal(9,4) | nein | 20 |
| @PartitionSpreadWarnPercent | decimal(9,4) | nein | 20 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Ein einzelner Datenbankname oder eine bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder eine nach äußerem Trimmen leere Eingabe bedeutet keine explizite Auswahl; der Kandidatenhelfer wählt alle zulässigen sichtbaren Online-Benutzerdatenbanken, soweit kein Pattern einschränkt. Pipe trennt nur außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt. Leere Elemente, ungültige SQL-Namen, case-sensitive Duplikate und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Eine nichtleere Liste ist mit einem nicht-NULL-Datenbankpattern exklusiv.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. Bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt deren Aufnahme, soweit sichtbar und online. NULL ist im Datenbankkandidatenhelfer ungültig. Beim Binden zu bit konvertierbare numerische Nichtnullwerte werden zu 0 oder 1 konvertiert.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Datenbanknamen-Pattern. NULL deaktiviert es; leer oder nach Präfixentfernung leer ist ungültig. Äußere Leerzeichen werden getrimmt; die Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt, ohne Präfix gilt LIKE; danach wird nicht erneut getrimmt. LIKE verwendet %, _ und [...] mit case-sensitiver Framework-Collation. regex: verwendet Flag c, regexi: Flag i. Für Datenbanknamen prüft der Kandidatenhelfer Regex-Unterstützung im Installationsdatenbankkontext; erforderlich sind SQL Server 2025 und Compatibility Level 170. Nicht mit einer nichtleeren @DatabaseNames-Liste kombinieren.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. SQL-bit-Bestätigung mit 0 oder 1; 0 bleibt 0, von 0 verschiedene konvertierbare Zahlenwerte werden 1. In beiden Modi wird nach der eigenen Validierung CATALOG_DEEP geprüft: 0 führt im erreichbaren Gate zu HIGH_IMPACT_CONFIRMATION_REQUIRED, NULL zu INVALID_PARAMETER, 1 erfüllt die Bestätigung. Danach wird die aktuelle Gruppen-/Tokenberechtigung getrennt geprüft; 1 verleiht weder Rolle noch SQL-Rechte, ohne Freigabe folgt DENIED_GROUP. Bei erfolgreichem Gate wird derselbe Wert an USP_Statistics weitergereicht.

**@SchemaNames:** @SchemaNames nvarchar(max); Default: NULL. Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere oder nur aus Leerzeichen bestehende Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen validiert und case-sensitive verglichen. Doppelte Werte derselben Namensart und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit @SchemaNamePattern kombinieren; bei nicht-NULL @FullObjectNames ist diese Kombination ebenfalls ungültig.

**@SchemaNamePattern:** @SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Pattern für Schemanamen. NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere Leerzeichen werden vor der Erkennung eines Präfixes like:, regex: oder regexi: entfernt; danach bleibt das Pattern unverändert. Ohne Präfix und mit like: gilt case-sensitives SQL-LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Feldregex wird inline in der jeweiligen Quelldatenbank ausgeführt; dafür gibt es keine eigene Versionsvorprüfung, sodass fehlende Unterstützung als datenbankweise isolierter Fehler auftreten kann. Nicht mit nicht-NULL @SchemaNames kombinieren.

**@ObjectNames:** @ObjectNames nvarchar(max); Default: NULL. Exakte einteilige Objektnamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, mit höchstens 128 Zeichen geprüft und case-sensitive verglichen. Doppelte Objektnamen und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit @ObjectNamePattern kombinieren; bei nicht-NULL @FullObjectNames ist diese Kombination ebenfalls ungültig.

**@ObjectNamePattern:** @ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objektnamen-Pattern. NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere Leerzeichen werden vor dem Erkennen von like:, regex: oder regexi: entfernt; danach wird nicht erneut getrimmt. Ohne Präfix/like: gilt case-sensitives LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Feldregex läuft inline je Quelldatenbank ohne eigene Versionsvorprüfung; fehlende Unterstützung kann als isolierter Datenbankfehler erscheinen. Nicht mit nicht-NULL @ObjectNames kombinieren.

**@FullObjectNames:** @FullObjectNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. Bei einem Datenbankteil ist das Schema erforderlich; vierteilige Linked-Server-Bezüge sind unzulässig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt und nach PARSENAME/sysname-Grenzen geprüft. NULL bedeutet kein Filter; ein leerer nvarchar-String ist EMPTY_LIST, Leerzeichen ergibt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemanamen bleiben offen. Duplikate und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit nicht-NULL @SchemaNames oder @ObjectNames kombinieren.

**@StatisticsNames:** @StatisticsNames nvarchar(max); Default: NULL. Exakte einteilige Statistiknamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, als einteilige SQL-Namen bis 128 Zeichen validiert und case-sensitive verglichen. Duplikate sowie Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit nicht-NULL @StatisticsNamePattern kombinieren.

**@StatisticsNamePattern:** @StatisticsNamePattern nvarchar(4000); Default: NULL. Optionales Statistiknamen-Pattern. NULL deaktiviert den Filter; leere Eingabe oder leeres Präfix ist ungültig. Äußere Leerzeichen werden vor Erkennung von like:, regex: oder regexi: getrimmt; der Rest wird nicht erneut getrimmt. Ohne Präfix/like: gilt case-sensitives LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Regex wird im jeweiligen Quelldatenbankbatch ausgewertet und hat keine separate Versionsvorprüfung; Fehler können pro Datenbank isoliert werden. Nicht mit nicht-NULL @StatisticsNames kombinieren. Ein Statistikpattern allein erfüllt den GEZIELT-Filter von USP_Statistics nicht; ein zusätzlicher Schema-/Objektfilter ist erforderlich. Das gilt auch beim weitergereichten Aufruf aus der Verteilungsanalyse.

**@AnalyseModus:** @AnalyseModus varchar(16); Default: 'GEZIELT'. Text wird getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind ausschließlich GEZIELT und VOLL; NULL wird als GEZIELT behandelt. Bei USP_Statistics verlangt GEZIELT mindestens eine exakte Schema-/Objekt-/Statistikliste, @FullObjectNames oder ein Schema-/Objektpattern; nur eine Datenbank genügt nicht. VOLL prüft CATALOG_DEEP. Die Verteilungsanalyse prüft CATALOG_DEEP unabhängig vom Modus; GEZIELT verlangt dort einen Objekt-, Schema- oder Statistikfilter. Ein gültiger Scope bleibt erforderlich.

**@MaxVerteilungsStatistiken:** @MaxVerteilungsStatistiken int; Default: 50. Anzahl der vor dem Histogrammzugriff ausgewählten Statistiken je Datenbank; zulässig sind ganze Zahlen von 1 bis 250 einschließlich. NULL und Werte außerhalb des Bereichs sind ungültig. Die Auswahlgrenze begrenzt Kandidaten vor dem Histogrammzugriff; die interne Vorpoolgröße beträgt höchstens 1000 (vierfach, maximal). Sie ist kein globales Datenbanklimit.

**@MinVerteilungsZeilen:** @MinVerteilungsZeilen bigint; Default: 1000. Nichtnegative Kontext-/Findingschwelle von 0 bis 9223372036854775807 Zeilen; NULL oder negative Werte sind INVALID_PARAMETER. Dominanz-, Skew- und Tail-Findings verwenden HistogramEstimatedRows, der Änderungshinweis verwendet Rows bei vorhandenem Histogramm und der Partitionsvergleich TotalRows. Ein kleiner Histogrammkontext wird als SMALL_HISTOGRAM_CONTEXT gekennzeichnet. Histogrammabruf und Distribution-Zeilen werden nicht unterdrückt; fehlende Histogrammsichtbarkeit bleibt eine unabhängige Meldung. Die Schwelle begrenzt weder Kandidaten noch Histogrammsteps.

**@SkewWarnFaktor:** @SkewWarnFaktor decimal(19,4); Default: 10. decimal(19,4)-Mindestfaktor; bei der Parameterbindung wird auf vier Nachkommastellen konvertiert. für Skew- und Tail-Hinweise, zulässig von 1 bis 100000 einschließlich. NULL oder Werte außerhalb des Bereichs sind ungültig. Er wird mit EqualRowsSkewRatio, AverageRangeRowsSkewRatio und TailVsAverageStepRatio verglichen; höhere Schwellen erzeugen weniger entsprechende Findings.

**@DominanterSchrittWarnPercent:** @DominanterSchrittWarnPercent decimal(9,4); Default: 50. decimal(9,4)-Grenzwert; bei der Parameterbindung wird auf vier Nachkommastellen konvertiert. für den Anteil des dominanten Histogrammschritts, 0 bis 100 einschließlich. NULL oder Werte außerhalb dieses Bereichs sind ungültig. Er steuert den Hinweis auf einen dominanten Schritt, sofern die Mindestzeilenzahl erfüllt ist.

**@ModificationWarnPercent:** @ModificationWarnPercent decimal(9,4); Default: 20. decimal(9,4)-Grenzwert; bei der Parameterbindung wird auf vier Nachkommastellen konvertiert. für ModificationPercent, 0 bis 100 einschließlich. NULL oder Werte außerhalb dieses Bereichs sind ungültig. Der Hinweis wird nur bei Histogrammsteps > 0 und Rows mindestens @MinVerteilungsZeilen erzeugt; er belegt keine Wertverteilung außerhalb des Histogramms.

**@PartitionSpreadWarnPercent:** @PartitionSpreadWarnPercent decimal(9,4); Default: 20. decimal(9,4)-Grenzwert; bei der Parameterbindung wird auf vier Nachkommastellen konvertiert. für die Streuung der Änderungsanteile inkrementeller Statistikpartitionen, 0 bis 100 einschließlich. NULL oder Werte außerhalb dieses Bereichs sind ungültig. Ein Finding entsteht, wenn TotalRows mindestens @MinVerteilungsZeilen und ModificationSpreadPercentPoints mindestens diesen Wert erreicht.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. Nichtnegative int-Obergrenze von 0 bis 2147483647 für fertige Findings sowie Distribution- und PartitionVariation-Zeilen in RAW/JSON/CONSOLE. NULL oder 0 bedeutet unbegrenzt; negative Werte sind ungültig. Findings werden nach Severity (HIGH, MEDIUM, LOW, danach weitere) und FindingOrdinal ausgewählt. Datenbankstatus und vollständige Zähler bleiben unbegrenzt; die Grenze beschränkt keine Kandidaten oder Histogrammsteps.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Ganzzahlige Metadatenlock-Wartezeit in Millisekunden von 0 bis 60000 einschließlich; 0 wartet nicht. Werte außerhalb des Bereichs sind ungültig. Der Wert wird an USP_Statistics für deren dynamische Datenbankbatches weitergereicht. Die Verteilungsprocedure setzt ihr eigenes LOCK_TIMEOUT im Prozedurscope auf 0; SET-Werte aus Procedure-/dynamischem Batchscope werden bei Rückkehr zurückgenommen.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Wird getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind CONSOLE, RAW, TABLE und NONE. RAW gibt Meta-/Datenbankstatus, Verteilung, Partitionsvariation und Findings aus; CONSOLE liefert beschriftete Fassungen; TABLE schreibt ausschließlich findings nach Preflight in das typisierte lokale Ziel; NONE unterdrückt Resultsets. NULL/leer ist ungültig. Nichtleeres @ResultTablesJson ist nur mit TABLE erlaubt.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. JSON-Zielzuordnung für TABLE. Bei TABLE muss die Zuordnung findings auf eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte abbilden; Preflightfehler treten vor der Analyse als Fehler auf. Bei anderen Ausgabearten ist nur NULL/leer zulässig. Das TABLE-Ergebnis enthält die begrenzte Findingsmenge.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit-Schalter: 0 lässt @Json nach anfänglicher NULL-Zuweisung NULL; 1 erzeugt JSON mit meta, databaseStatus, distribution, partitionVariation und findings. NULL wird nicht als ungültig abgefangen und aktiviert die IF-Bedingung nicht.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter vom Typ nvarchar(max); optional an eine nvarchar(max)-OUTPUT-Variable zu binden. Wird beim Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 erhält er das JSON-Objekt mit meta, databaseStatus, distribution, partitionVariation und findings; andernfalls bleibt er NULL. Meta enthält resultName, schemaVersion=1, generatedAtUtc, statusCode, isPartial, maxStatisticsPerDatabase, minimumDistributionRows, distributionCount und findingCount.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit-Schalter für Warnmeldungen mit Severity 10 und NOWAIT. 1 gibt die Meldung aus, wenn Status nicht AVAILABLE, AVAILABLE_WITH_FINDING oder NOT_APPLICABLE ist; 0 unterdrückt sie. NULL aktiviert die IF-Bedingung nicht. Resultsets, JSON und OUTPUT-Status bleiben davon getrennt.

**@Hilfe:** @Hilfe bit; Default: 0. Bit-Schalter; 1 druckt die eingebaute PRINT-Hilfe und kehrt vor Validierung und Analyse zurück, 0 führt den Ablauf aus. NULL wird nicht als Hilfe behandelt. Die TABLE-Zuordnungsprüfung findet vor dem Hilfezweig statt; @ResultTablesJson darf daher auch bei Hilfe nicht als nichtleere Angabe mit einer anderen Ausgabeart kombiniert werden.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Status varchar(40), optional an eine varchar(40)-OUTPUT-Variable zu binden. Erhält am Ende den Modulstatus, z. B. AVAILABLE, AVAILABLE_WITH_FINDING, NOT_APPLICABLE, INVALID_PARAMETER, HIGH_IMPACT_CONFIRMATION_REQUIRED, DENIED_GROUP, UNAVAILABLE_FEATURE, AVAILABLE_LIMITED, PARTIAL, SKIPPED, TIMEOUT, DENIED_PERMISSION, ERROR_HANDLED oder einen weitergereichten Kandidaten-/Datenbankstatus. Die Zuweisung erfolgt nach der Analyse; ein früher Hilfe-RETURN überspringt sie.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionaler bit-OUTPUT-Empfänger; zum Empfang eine Variable mit OUTPUT binden. Am Ende wird das interne Partial-Flag übergeben: es übernimmt den Quellenstatus von USP_Statistics und wird bei den behandelten Fehler-/Verfügbarkeitspfaden gesetzt. Das Kappen durch @MaxVerteilungsStatistiken oder @MaxZeilen setzt das Flag für sich nicht; 0 ist deshalb kein Nachweis einer ungekürzten Kandidaten- oder Ergebnismenge. Hilfe kehrt vor der Zuweisung zurück und lässt den übergebenen Variablenwert unverändert.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT-Fehlernummer int, optional an int-OUTPUT-Variable zu binden. Erhält die im Modulstatus gespeicherte SQL-Fehlernummer oder NULL, wenn kein Fehlercode gesetzt wurde. Die Zuweisung erfolgt am Ende nach der Analyse; bei Hilfe-RETURN wird sie nicht ausgeführt.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT-Fehlertext nvarchar(2048), optional an eine nvarchar(2048)-OUTPUT-Variable zu binden. Erhält die Statusfehlermeldung oder NULL, wenn keine gesetzt ist. Die Zuweisung erfolgt am Ende nach der Analyse; bei Hilfe-RETURN wird sie nicht ausgeführt.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| findings | 1 | 1 | [FindingOrdinal] bigint NOT NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [StatisticsName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [MetricValue] decimal(38,4) NULL , [ThresholdValue] decimal(38,4) NULL , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_StatisticsDistributionAnalysis] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @MaxVerteilungsStatistiken=10, @MaxZeilen=100, @ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Skew, Tail-Konzentration und Änderungen seit dem Statistikstand sind Prüfhinweise, kein Beweis für einen schlechten Plan oder Werte außerhalb des Histogramms. Query-/Prädikatkontext und tatsächliche Kardinalitätsabweichungen müssen separat korreliert werden. Es werden keine Statistiken aktualisiert und keine Daten aus Benutzertabellen gelesen.

HIGH_OPT_IN. Beide Modi prüfen CATALOG_DEEP; GEZIELT verlangt einen Objekt-, Schema- oder Statistikfilter. Die Kandidatenzahl ist je Datenbank vor Histogrammzugriff begrenzt.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_StatisticsDistributionAnalysis
Version      : 1.0.0
Stand        : 2026-07-17
Typ          : Stored Procedure
Zweck        : Analysiert begrenzt und opt-in die Verteilung sichtbarer
               Statistikhistogramme sowie die Änderungsvariation inkrementeller
               Statistikpartitionen.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : monitor.USP_Statistics, sys.stats_columns, sys.columns,
               sys.types und sys.dm_db_stats_histogram.
Methodik     : Die Kandidatenmenge wird je Datenbank vor dem Histogrammzugriff
               begrenzt. Bewertet werden ausschließlich numerische Verteilungs-
               kennzahlen; konkrete Histogrammgrenzwerte sind für diese
               Auswertung nicht erforderlich.
Grenzen      : Skew, Tail-Konzentration und Änderungen seit dem Statistikstand
               sind Prüfhinweise, kein Beweis für einen schlechten Plan oder
               Werte außerhalb des Histogramms. Query-/Prädikatkontext und
               tatsächliche Kardinalitätsabweichungen müssen separat korreliert
               werden. Es werden keine Statistiken aktualisiert und keine Daten
               aus Benutzertabellen gelesen.
Kosten       : HIGH_OPT_IN. Beide Modi prüfen CATALOG_DEEP; GEZIELT verlangt einen Objekt-, Schema- oder Statistikfilter. Die Kandidatenzahl ist je Datenbank vor Histogrammzugriff begrenzt.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_StatisticsDistributionAnalysis
Analysiert eine vorab begrenzte Statistik-Kandidatenmenge und numerische Histogramm- sowie inkrementelle Partitionskennzahlen; Statistikdefinitionen werden nicht geändert.
Beide Modi prüfen CATALOG_DEEP. GEZIELT verlangt einen Objekt-, Schema- oder Statistikfilter; die Bestätigung ersetzt den Scope nicht.
RAW, CONSOLE, TABLE und NONE steuern Resultsets; JSON und vier OUTPUT-Statuswerte sind davon unabhängig. TABLE schreibt findings.
Beispiel: EXEC [monitor].[USP_StatisticsDistributionAnalysis] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @ResultSetArt='RAW';
OUTPUT: DECLARE @ExampleStatus varchar(40), @ExamplePartial bit, @ExampleError int, @ExampleMessage nvarchar(2048); EXEC [monitor].[USP_StatisticsDistributionAnalysis] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @StatusCodeOut=@ExampleStatus OUTPUT, @IsPartialOut=@ExamplePartial OUTPUT, @ErrorNumberOut=@ExampleError OUTPUT, @ErrorMessageOut=@ExampleMessage OUTPUT;
DECLARE @ExampleJson nvarchar(max), @ExampleStatus varchar(40), @ExamplePartial bit, @ExampleError int, @ExampleMessage nvarchar(2048); EXEC [monitor].[USP_StatisticsDistributionAnalysis] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @MaxVerteilungsStatistiken=10, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT, @StatusCodeOut=@ExampleStatus OUTPUT, @IsPartialOut=@ExamplePartial OUTPUT, @ErrorNumberOut=@ExampleError OUTPUT, @ErrorMessageOut=@ExampleMessage OUTPUT; SELECT @ExampleJson AS [ExampleJson], @ExampleStatus AS [StatusCode], @ExamplePartial AS [IsPartial], @ExampleError AS [ErrorNumber], @ExampleMessage AS [ErrorMessage];
CREATE TABLE [#StatisticsDistributionAnalysis_HelpExample]([Seed] int NULL); BEGIN TRY     EXEC [monitor].[USP_StatisticsDistributionAnalysis] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @MaxVerteilungsStatistiken=10, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#StatisticsDistributionAnalysis_HelpExample"}'; END TRY BEGIN CATCH     DROP TABLE [#StatisticsDistributionAnalysis_HelpExample];     THROW; END CATCH; DROP TABLE [#StatisticsDistributionAnalysis_HelpExample];
```


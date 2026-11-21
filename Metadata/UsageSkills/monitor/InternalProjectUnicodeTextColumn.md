---
skill_format_version: "1.0.0"
name: "monitor.InternalProjectUnicodeTextColumn"
schema_name: "monitor"
object_name: "InternalProjectUnicodeTextColumn"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Projiziert eine bereits materialisierte nvarchar(max)-Spalte Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten."
source_path: "Code/01_Common/098_USP_InternalProjectUnicodeTextColumn.sql"
---

# monitor.InternalProjectUnicodeTextColumn

## Zweck und Einsatz

Projiziert eine bereits materialisierte nvarchar(max)-Spalte Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalProjectUnicodeTextColumn]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `monitor.TVF_ProjectUnicodeText`, `[monitor].[TVF_ProjectUnicodeText]`, `[sys].[sp_executesql]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SourceTable | sysname | ja | kein Default |
| @TextColumn | sysname | ja | kein Default |
| @CharactersColumn | sysname | ja | kein Default |
| @BytesColumn | sysname | ja | kein Default |
| @IsTruncatedColumn | sysname | ja | kein Default |
| @MaxCharacters | int | ja | kein Default |
| @TruncatedValueCount | bigint OUTPUT | ja | kein Default |
| @LargestRequiredCharacters | bigint OUTPUT | ja | kein Default |
| @Hilfe | bit | nein | 0 |

**@SourceTable:** @SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne # und ##Name lösen Guard-Fehler 51021 aus. Keine Liste oder SQL-Ausdruck. Der Projektor prüft keine eigene 116-Zeichen-Grenze und validiert Existenz/Schema nicht vorab.

**@TextColumn:** @TextColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus. QUOTENAME wird angewandt; Listen und SQL-Ausdrücke sind keine Eingabeform. Muss auf die bereits materialisierte nvarchar(max)-Textspalte zeigen, die IN PLACE überschrieben wird.

**@CharactersColumn:** @CharactersColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalCharacters als bigint: Anzahl der Originalzeichen nach TVF_ProjectUnicodeText unter Latin1_General_100_CI_AS_SC, einschließlich nachgestellter Leerzeichen; Surrogatpaare zählen als ein Zeichen.

**@BytesColumn:** @BytesColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalBytes als bigint, entsprechend DATALENGTH des Originalwerts.

**@IsTruncatedColumn:** @IsTruncatedColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile IsTruncated als bit aus der TVF-Kürzungsentscheidung.

**@MaxCharacters:** @MaxCharacters int. Default: keiner; Pflichtargument. Negativ löst 51021 aus. NULL passiert den Guard und wird unverändert an die TVF übergeben; diese behandelt NULL ebenso wie 0 als unbegrenzt; positive Werte begrenzen auf diese Anzahl SC-Zeichen. Die TVF zählt Surrogatpaare als ein Zeichen und schneidet nicht innerhalb des Paars; Zeichen sind keine Grapheme.

**@TruncatedValueCount:** @TruncatedValueCount bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @TruncatedValueCount=@bigintVariable OUTPUT binden. Nach erfolgreicher Parameterprüfung und vor der dynamischen Ausführung 0; nach Verarbeitung COUNT_BIG ausschließlich der gekürzten Zeilen, bei keiner Kürzung 0. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@LargestRequiredCharacters:** @LargestRequiredCharacters bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @LargestRequiredCharacters=@bigintVariable OUTPUT binden. Nach erfolgreicher Guard-Initialisierung NULL; nach Verarbeitung MAX der OriginalCharacters ausschließlich gekürzter Zeilen, bei keiner Kürzung NULL. Abhängigkeit: monitor.TVF_ProjectUnicodeText bestimmt Zeichen-, Byte- und Kürzungssemantik. Surrogatpaare zählen als ein SC-Zeichen, nachgestellte Leerzeichen werden gezählt, Bytes entsprechen DATALENGTH; es gibt keine Graphemgarantie. Die vollständige fachliche Quelle muss der interne Caller vorab materialisieren. Alle drei Metadatenspalten werden für jede Zeile aktualisiert. Nicht vorhandene, leere oder typinkompatible Spalten werden nicht vorab geprüft; dynamisches SQL kann normale native Fehler auslösen. Es gibt keine eigene Transaktion oder CATCH-Behandlung. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Kein Fach-Resultset. Der Helper aktualisiert die benannte Text-/Längen-/Kürzungs-Spalte der lokalen #Quelle. `@TruncatedValueCount bigint OUTPUT` ist nach erfolgreicher Verarbeitung die Zahl gekürzter Zeilen (sonst 0), `@LargestRequiredCharacters bigint OUTPUT` das Maximum der ursprünglichen Zeichenzahl unter diesen Zeilen (sonst NULL). Er erzeugt keine zusätzliche Nutzdaten-Ausgabe; bei nativem Fehler ist keine abgeschlossene Projektion zugesichert.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalProjectUnicodeTextColumn';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalProjectUnicodeTextColumn] @SourceTable=NULL, @TextColumn=NULL, @CharactersColumn=NULL, @BytesColumn=NULL, @IsTruncatedColumn=NULL, @MaxCharacters=NULL, @TruncatedValueCount=NULL, @LargestRequiredCharacters=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

===============================================================================
Objekt       : monitor.InternalProjectUnicodeTextColumn
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Projiziert eine bereits materialisierte nvarchar(max)-Spalte
               Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten.
Grenze       : Liest ausschließlich die übergebene lokale Temp-Tabelle; kein
               erneuter Zugriff auf die fachliche Systemquelle.
Parameterverträge:
@SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne # und ##Name lösen Guard-Fehler 51021 aus. Keine Liste oder SQL-Ausdruck. Der Projektor prüft keine eigene 116-Zeichen-Grenze und validiert Existenz/Schema nicht vorab.
@TextColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus. QUOTENAME wird angewandt; Listen und SQL-Ausdrücke sind keine Eingabeform. Muss auf die bereits materialisierte nvarchar(max)-Textspalte zeigen, die IN PLACE überschrieben wird.
@CharactersColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Sp

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.InternalProjectUnicodeTextColumn
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Projiziert eine bereits materialisierte nvarchar(max)-Spalte
               Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten.
Grenze       : Liest ausschließlich die übergebene lokale Temp-Tabelle; kein
               erneuter Zugriff auf die fachliche Systemquelle.
Parameterverträge:
@SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne # und ##Name lösen Guard-Fehler 51021 aus. Keine Liste oder SQL-Ausdruck. Der Projektor prüft keine eigene 116-Zeichen-Grenze und validiert Existenz/Schema nicht vorab.
@TextColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus. QUOTENAME wird angewandt; Listen und SQL-Ausdrücke sind keine Eingabeform. Muss auf die bereits materialisierte nvarchar(max)-Textspalte zeigen, die IN PLACE überschrieben wird.
@CharactersColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalCharacters als bigint: Anzahl der Originalzeichen nach TVF_ProjectUnicodeText unter Latin1_General_100_CI_AS_SC, einschließlich nachgestellter Leerzeichen; Surrogatpaare zählen als ein Zeichen.
@BytesColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalBytes als bigint, entsprechend DATALENGTH des Originalwerts.
@IsTruncatedColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile IsTruncated als bit aus der TVF-Kürzungsentscheidung.
@MaxCharacters int. Default: keiner; Pflichtargument. Negativ löst 51021 aus. NULL passiert den Guard und wird unverändert an die TVF übergeben; diese behandelt NULL ebenso wie 0 als unbegrenzt; positive Werte begrenzen auf diese Anzahl SC-Zeichen. Die TVF zählt Surrogatpaare als ein Zeichen und schneidet nicht innerhalb des Paars; Zeichen sind keine Grapheme.
@TruncatedValueCount bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @TruncatedValueCount=@bigintVariable OUTPUT binden. Nach erfolgreicher Parameterprüfung und vor der dynamischen Ausführung 0; nach Verarbeitung COUNT_BIG ausschließlich der gekürzten Zeilen, bei keiner Kürzung 0.
@LargestRequiredCharacters bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @LargestRequiredCharacters=@bigintVariable OUTPUT binden. Nach erfolgreicher Guard-Initialisierung NULL; nach Verarbeitung MAX der OriginalCharacters ausschließlich gekürzter Zeilen, bei keiner Kürzung NULL.
Abhängigkeit: monitor.TVF_ProjectUnicodeText bestimmt Zeichen-, Byte- und Kürzungssemantik. Surrogatpaare zählen als ein SC-Zeichen, nachgestellte Leerzeichen werden gezählt, Bytes entsprechen DATALENGTH; es gibt keine Graphemgarantie.
Die vollständige fachliche Quelle muss der interne Caller vorab materialisieren. Alle drei Metadatenspalten werden für jede Zeile aktualisiert. Nicht vorhandene, leere oder typinkompatible Spalten werden nicht vorab geprüft; dynamisches SQL kann normale native Fehler auslösen. Es gibt keine eigene Transaktion oder CATCH-Behandlung.
```


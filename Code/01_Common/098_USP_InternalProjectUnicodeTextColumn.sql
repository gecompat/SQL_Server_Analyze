USE [DeineDatenbank];
GO

/*
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
@CharactersColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalCharacters als bigint: Anzahl der Originalzeichen nach TVF_ProjectUnicodeText unter Latin1_General_100_CI_AS_SC, einschließlich nachgestellter Leerzeichen; Surrogatpaare zählen als ein Zeichen.
@BytesColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalBytes als bigint, entsprechend DATALENGTH des Originalwerts.
@IsTruncatedColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile IsTruncated als bit aus der TVF-Kürzungsentscheidung.
@MaxCharacters int. Default: keiner; Pflichtargument. Negativ löst 51021 aus. NULL passiert den Guard und wird unverändert an die TVF übergeben; diese behandelt NULL ebenso wie 0 als unbegrenzt; positive Werte begrenzen auf diese Anzahl SC-Zeichen. Die TVF zählt Surrogatpaare als ein Zeichen und schneidet nicht innerhalb des Paars; Zeichen sind keine Grapheme.
@TruncatedValueCount bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @TruncatedValueCount=@bigintVariable OUTPUT binden. Nach erfolgreicher Parameterprüfung und vor der dynamischen Ausführung 0; nach Verarbeitung COUNT_BIG ausschließlich der gekürzten Zeilen, bei keiner Kürzung 0.
@LargestRequiredCharacters bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @LargestRequiredCharacters=@bigintVariable OUTPUT binden. Nach erfolgreicher Guard-Initialisierung NULL; nach Verarbeitung MAX der OriginalCharacters ausschließlich gekürzter Zeilen, bei keiner Kürzung NULL.
Abhängigkeit: monitor.TVF_ProjectUnicodeText bestimmt Zeichen-, Byte- und Kürzungssemantik. Surrogatpaare zählen als ein SC-Zeichen, nachgestellte Leerzeichen werden gezählt, Bytes entsprechen DATALENGTH; es gibt keine Graphemgarantie.
Die vollständige fachliche Quelle muss der interne Caller vorab materialisieren. Alle drei Metadatenspalten werden für jede Zeile aktualisiert. Nicht vorhandene, leere oder typinkompatible Spalten werden nicht vorab geprüft; dynamisches SQL kann normale native Fehler auslösen. Es gibt keine eigene Transaktion oder CATCH-Behandlung.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.InternalProjectUnicodeTextColumn 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalProjectUnicodeTextColumn"
-- schema_name: "monitor"
-- object_name: "InternalProjectUnicodeTextColumn"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "framework"
-- is_internal: true
-- description: "Projiziert eine bereits materialisierte nvarchar(max)-Spalte Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten."
-- source_path: "Code/01_Common/098_USP_InternalProjectUnicodeTextColumn.sql"
-- ---
-- 
-- # monitor.InternalProjectUnicodeTextColumn
-- 
-- ## Zweck und Einsatz
-- 
-- Projiziert eine bereits materialisierte nvarchar(max)-Spalte Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalProjectUnicodeTextColumn]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `monitor.TVF_ProjectUnicodeText`, `[monitor].[TVF_ProjectUnicodeText]`, `[sys].[sp_executesql]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @SourceTable | sysname | ja | kein Default |
-- | @TextColumn | sysname | ja | kein Default |
-- | @CharactersColumn | sysname | ja | kein Default |
-- | @BytesColumn | sysname | ja | kein Default |
-- | @IsTruncatedColumn | sysname | ja | kein Default |
-- | @MaxCharacters | int | ja | kein Default |
-- | @TruncatedValueCount | bigint OUTPUT | ja | kein Default |
-- | @LargestRequiredCharacters | bigint OUTPUT | ja | kein Default |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@SourceTable:** @SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne # und ##Name lösen Guard-Fehler 51021 aus. Keine Liste oder SQL-Ausdruck. Der Projektor prüft keine eigene 116-Zeichen-Grenze und validiert Existenz/Schema nicht vorab.
-- 
-- **@TextColumn:** @TextColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus. QUOTENAME wird angewandt; Listen und SQL-Ausdrücke sind keine Eingabeform. Muss auf die bereits materialisierte nvarchar(max)-Textspalte zeigen, die IN PLACE überschrieben wird.
-- 
-- **@CharactersColumn:** @CharactersColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalCharacters als bigint: Anzahl der Originalzeichen nach TVF_ProjectUnicodeText unter Latin1_General_100_CI_AS_SC, einschließlich nachgestellter Leerzeichen; Surrogatpaare zählen als ein Zeichen.
-- 
-- **@BytesColumn:** @BytesColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalBytes als bigint, entsprechend DATALENGTH des Originalwerts.
-- 
-- **@IsTruncatedColumn:** @IsTruncatedColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile IsTruncated als bit aus der TVF-Kürzungsentscheidung.
-- 
-- **@MaxCharacters:** @MaxCharacters int. Default: keiner; Pflichtargument. Negativ löst 51021 aus. NULL passiert den Guard und wird unverändert an die TVF übergeben; diese behandelt NULL ebenso wie 0 als unbegrenzt; positive Werte begrenzen auf diese Anzahl SC-Zeichen. Die TVF zählt Surrogatpaare als ein Zeichen und schneidet nicht innerhalb des Paars; Zeichen sind keine Grapheme.
-- 
-- **@TruncatedValueCount:** @TruncatedValueCount bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @TruncatedValueCount=@bigintVariable OUTPUT binden. Nach erfolgreicher Parameterprüfung und vor der dynamischen Ausführung 0; nach Verarbeitung COUNT_BIG ausschließlich der gekürzten Zeilen, bei keiner Kürzung 0. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@LargestRequiredCharacters:** @LargestRequiredCharacters bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @LargestRequiredCharacters=@bigintVariable OUTPUT binden. Nach erfolgreicher Guard-Initialisierung NULL; nach Verarbeitung MAX der OriginalCharacters ausschließlich gekürzter Zeilen, bei keiner Kürzung NULL. Abhängigkeit: monitor.TVF_ProjectUnicodeText bestimmt Zeichen-, Byte- und Kürzungssemantik. Surrogatpaare zählen als ein SC-Zeichen, nachgestellte Leerzeichen werden gezählt, Bytes entsprechen DATALENGTH; es gibt keine Graphemgarantie. Die vollständige fachliche Quelle muss der interne Caller vorab materialisieren. Alle drei Metadatenspalten werden für jede Zeile aktualisiert. Nicht vorhandene, leere oder typinkompatible Spalten werden nicht vorab geprüft; dynamisches SQL kann normale native Fehler auslösen. Es gibt keine eigene Transaktion oder CATCH-Behandlung. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Kein Fach-Resultset. Der Helper aktualisiert die benannte Text-/Längen-/Kürzungs-Spalte der lokalen #Quelle. `@TruncatedValueCount bigint OUTPUT` ist nach erfolgreicher Verarbeitung die Zahl gekürzter Zeilen (sonst 0), `@LargestRequiredCharacters bigint OUTPUT` das Maximum der ursprünglichen Zeichenzahl unter diesen Zeilen (sonst NULL). Er erzeugt keine zusätzliche Nutzdaten-Ausgabe; bei nativem Fehler ist keine abgeschlossene Projektion zugesichert.
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalProjectUnicodeTextColumn';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [monitor].[InternalProjectUnicodeTextColumn] @SourceTable=NULL, @TextColumn=NULL, @CharactersColumn=NULL, @BytesColumn=NULL, @IsTruncatedColumn=NULL, @MaxCharacters=NULL, @TruncatedValueCount=NULL, @LargestRequiredCharacters=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- ===============================================================================
-- Objekt       : monitor.InternalProjectUnicodeTextColumn
-- Version      : 1.0.0
-- Stand        : 2026-07-21
-- Typ          : Interne Stored Procedure
-- Zweck        : Projiziert eine bereits materialisierte nvarchar(max)-Spalte
--                Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten.
-- Grenze       : Liest ausschließlich die übergebene lokale Temp-Tabelle; kein
--                erneuter Zugriff auf die fachliche Systemquelle.
-- Parameterverträge:
-- @SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne # und ##Name lösen Guard-Fehler 51021 aus. Keine Liste oder SQL-Ausdruck. Der Projektor prüft keine eigene 116-Zeichen-Grenze und validiert Existenz/Schema nicht vorab.
-- @TextColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus. QUOTENAME wird angewandt; Listen und SQL-Ausdrücke sind keine Eingabeform. Muss auf die bereits materialisierte nvarchar(max)-Textspalte zeigen, die IN PLACE überschrieben wird.
-- @CharactersColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Sp
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.InternalProjectUnicodeTextColumn
-- Version      : 1.0.0
-- Stand        : 2026-07-21
-- Typ          : Interne Stored Procedure
-- Zweck        : Projiziert eine bereits materialisierte nvarchar(max)-Spalte
--                Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten.
-- Grenze       : Liest ausschließlich die übergebene lokale Temp-Tabelle; kein
--                erneuter Zugriff auf die fachliche Systemquelle.
-- Parameterverträge:
-- @SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne # und ##Name lösen Guard-Fehler 51021 aus. Keine Liste oder SQL-Ausdruck. Der Projektor prüft keine eigene 116-Zeichen-Grenze und validiert Existenz/Schema nicht vorab.
-- @TextColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus. QUOTENAME wird angewandt; Listen und SQL-Ausdrücke sind keine Eingabeform. Muss auf die bereits materialisierte nvarchar(max)-Textspalte zeigen, die IN PLACE überschrieben wird.
-- @CharactersColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalCharacters als bigint: Anzahl der Originalzeichen nach TVF_ProjectUnicodeText unter Latin1_General_100_CI_AS_SC, einschließlich nachgestellter Leerzeichen; Surrogatpaare zählen als ein Zeichen.
-- @BytesColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalBytes als bigint, entsprechend DATALENGTH des Originalwerts.
-- @IsTruncatedColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile IsTruncated als bit aus der TVF-Kürzungsentscheidung.
-- @MaxCharacters int. Default: keiner; Pflichtargument. Negativ löst 51021 aus. NULL passiert den Guard und wird unverändert an die TVF übergeben; diese behandelt NULL ebenso wie 0 als unbegrenzt; positive Werte begrenzen auf diese Anzahl SC-Zeichen. Die TVF zählt Surrogatpaare als ein Zeichen und schneidet nicht innerhalb des Paars; Zeichen sind keine Grapheme.
-- @TruncatedValueCount bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @TruncatedValueCount=@bigintVariable OUTPUT binden. Nach erfolgreicher Parameterprüfung und vor der dynamischen Ausführung 0; nach Verarbeitung COUNT_BIG ausschließlich der gekürzten Zeilen, bei keiner Kürzung 0.
-- @LargestRequiredCharacters bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @LargestRequiredCharacters=@bigintVariable OUTPUT binden. Nach erfolgreicher Guard-Initialisierung NULL; nach Verarbeitung MAX der OriginalCharacters ausschließlich gekürzter Zeilen, bei keiner Kürzung NULL.
-- Abhängigkeit: monitor.TVF_ProjectUnicodeText bestimmt Zeichen-, Byte- und Kürzungssemantik. Surrogatpaare zählen als ein SC-Zeichen, nachgestellte Leerzeichen werden gezählt, Bytes entsprechen DATALENGTH; es gibt keine Graphemgarantie.
-- Die vollständige fachliche Quelle muss der interne Caller vorab materialisieren. Alle drei Metadatenspalten werden für jede Zeile aktualisiert. Nicht vorhandene, leere oder typinkompatible Spalten werden nicht vorab geprüft; dynamisches SQL kann normale native Fehler auslösen. Es gibt keine eigene Transaktion oder CATCH-Behandlung.
-- ```
-- 
-- USAGE_SKILL_END monitor.InternalProjectUnicodeTextColumn
CREATE OR ALTER PROCEDURE [monitor].[InternalProjectUnicodeTextColumn]
      @SourceTable               sysname
    , @TextColumn                sysname
    , @CharactersColumn          sysname
    , @BytesColumn               sysname
    , @IsTruncatedColumn         sysname
    , @MaxCharacters             int
    , @TruncatedValueCount       bigint OUTPUT
    , @LargestRequiredCharacters bigint OUTPUT
    , @Hilfe bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN monitor.InternalProjectUnicodeTextColumn
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'InternalProjectUnicodeTextColumn') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.InternalProjectUnicodeTextColumn"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "InternalProjectUnicodeTextColumn"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Projiziert eine bereits materialisierte nvarchar(max)-Spalte Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten."'
            + NCHAR(10)
            + N'source_path: "Code/01_Common/098_USP_InternalProjectUnicodeTextColumn.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.InternalProjectUnicodeTextColumn'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Projiziert eine bereits materialisierte nvarchar(max)-Spalte Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalProjectUnicodeTextColumn]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `monitor.TVF_ProjectUnicodeText`, `[monitor].[TVF_ProjectUnicodeText]`, `[sys].[sp_executesql]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @SourceTable | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @TextColumn | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @CharactersColumn | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @BytesColumn | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @IsTruncatedColumn | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @MaxCharacters | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @TruncatedValueCount | bigint OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @LargestRequiredCharacters | bigint OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SourceTable:** @SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne # und ##Name lösen Guard-Fehler 51021 aus. Keine Liste oder SQL-Ausdruck. Der Projektor prüft keine eigene 116-Zeichen-Grenze und validiert Existenz/Schema nicht vorab.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@TextColumn:** @TextColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus. QUOTENAME wird angewandt; Listen und SQL-Ausdrücke sind keine Eingabeform. Muss auf die bereits materialisierte nvarchar(max)-Textspalte zeigen, die IN PLACE überschrieben wird.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CharactersColumn:** @CharactersColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalCharacters als bigint: Anzahl der Originalzeichen nach TVF_ProjectUnicodeText unter Latin1_General_100_CI_AS_SC, einschließlich nachgestellter Leerzeichen; Surrogatpaare zählen als ein Zeichen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@BytesColumn:** @BytesColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalBytes als bigint, entsprechend DATALENGTH des Originalwerts.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsTruncatedColumn:** @IsTruncatedColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile IsTruncated als bit aus der TVF-Kürzungsentscheidung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxCharacters:** @MaxCharacters int. Default: keiner; Pflichtargument. Negativ löst 51021 aus. NULL passiert den Guard und wird unverändert an die TVF übergeben; diese behandelt NULL ebenso wie 0 als unbegrenzt; positive Werte begrenzen auf diese Anzahl SC-Zeichen. Die TVF zählt Surrogatpaare als ein Zeichen und schneidet nicht innerhalb des Paars; Zeichen sind keine Grapheme.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@TruncatedValueCount:** @TruncatedValueCount bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @TruncatedValueCount=@bigintVariable OUTPUT binden. Nach erfolgreicher Parameterprüfung und vor der dynamischen Ausführung 0; nach Verarbeitung COUNT_BIG ausschließlich der gekürzten Zeilen, bei keiner Kürzung 0. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@LargestRequiredCharacters:** @LargestRequiredCharacters bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @LargestRequiredCharacters=@bigintVariable OUTPUT binden. Nach erfolgreicher Guard-Initialisierung NULL; nach Verarbeitung MAX der OriginalCharacters ausschließlich gekürzter Zeilen, bei keiner Kürzung NULL. Abhängigkeit: monitor.TVF_ProjectUnicodeText bestimmt Zeichen-, Byte- und Kürzungssemantik. Surrogatpaare zählen als ein SC-Zeichen, nachgestellte Leerzeichen werden gezählt, Bytes entsprechen DATALENGTH; es gibt keine Graphemgarantie. Die vollständige fachliche Quelle muss der interne Caller vorab materialisieren. Alle drei Metadatenspalten werden für jede Zeile aktualisiert. Nicht vorhandene, leere oder typinkompatible Spalten werden nicht vorab geprüft; dynamisches SQL kann normale native Fehler auslösen. Es gibt keine eigene Transaktion oder CATCH-Behandlung. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Init'
            + N'ialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein Fach-Resultset. Der Helper aktualisiert die benannte Text-/Längen-/Kürzungs-Spalte der lokalen #Quelle. `@TruncatedValueCount bigint OUTPUT` ist nach erfolgreicher Verarbeitung die Zahl gekürzter Zeilen (sonst 0), `@LargestRequiredCharacters bigint OUTPUT` das Maximum der ursprünglichen Zeichenzahl unter diesen Zeilen (sonst NULL). Er erzeugt keine zusätzliche Nutzdaten-Ausgabe; bei nativem Fehler ist keine abgeschlossene Projektion zugesichert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''monitor'' AND [ObjectName]=N''InternalProjectUnicodeTextColumn'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[InternalProjectUnicodeTextColumn] @SourceTable=NULL, @TextColumn=NULL, @CharactersColumn=NULL, @BytesColumn=NULL, @IsTruncatedColumn=NULL, @MaxCharacters=NULL, @TruncatedValueCount=NULL, @LargestRequiredCharacters=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + N'Objekt       : monitor.InternalProjectUnicodeTextColumn'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-21'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Projiziert eine bereits materialisierte nvarchar(max)-Spalte'
            + NCHAR(10)
            + N'               Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten.'
            + NCHAR(10)
            + N'Grenze       : Liest ausschließlich die übergebene lokale Temp-Tabelle; kein'
            + NCHAR(10)
            + N'               erneuter Zugriff auf die fachliche Systemquelle.'
            + NCHAR(10)
            + N'Parameterverträge:'
            + NCHAR(10)
            + N'@SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne # und ##Name lösen Guard-Fehler 51021 aus. Keine Liste oder SQL-Ausdruck. Der Projektor prüft keine eigene 116-Zeichen-Grenze und validiert Existenz/Schema nicht vorab.'
            + NCHAR(10)
            + N'@TextColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus. QUOTENAME wird angewandt; Listen und SQL-Ausdrücke sind keine Eingabeform. Muss auf die bereits materialisierte nvarchar(max)-Textspalte zeigen, die IN PLACE überschrieben wird.'
            + NCHAR(10)
            + N'@CharactersColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Sp'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : monitor.InternalProjectUnicodeTextColumn'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-21'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Projiziert eine bereits materialisierte nvarchar(max)-Spalte'
            + NCHAR(10)
            + N'               Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten.'
            + NCHAR(10)
            + N'Grenze       : Liest ausschließlich die übergebene lokale Temp-Tabelle; kein'
            + NCHAR(10)
            + N'               erneuter Zugriff auf die fachliche Systemquelle.'
            + NCHAR(10)
            + N'Parameterverträge:'
            + NCHAR(10)
            + N'@SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne # und ##Name lösen Guard-Fehler 51021 aus. Keine Liste oder SQL-Ausdruck. Der Projektor prüft keine eigene 116-Zeichen-Grenze und validiert Existenz/Schema nicht vorab.'
            + NCHAR(10)
            + N'@TextColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus. QUOTENAME wird angewandt; Listen und SQL-Ausdrücke sind keine Eingabeform. Muss auf die bereits materialisierte nvarchar(max)-Textspalte zeigen, die IN PLACE überschrieben wird.'
            + NCHAR(10)
            + N'@CharactersColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalCharacters als bigint: Anzahl der Originalzeichen nach TVF_ProjectUnicodeText unter Latin1_General_100_CI_AS_SC, einschließlich nachgestellter Leerzeichen; Surrogatpaare zählen als ein Zeichen.'
            + NCHAR(10)
            + N'@BytesColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalBytes als bigint, entsprechend DATALENGTH des Originalwerts.'
            + NCHAR(10)
            + N'@IsTruncatedColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile IsTruncated als bit aus der TVF-Kürzungsentscheidung.'
            + NCHAR(10)
            + N'@MaxCharacters int. Default: keiner; Pflichtargument. Negativ löst 51021 aus. NULL passiert den Guard und wird unverändert an die TVF übergeben; diese behandelt NULL ebenso wie 0 als unbegrenzt; positive Werte begrenzen auf diese Anzahl SC-Zeichen. Die TVF zählt Surrogatpaare als ein Zeichen und schneidet nicht innerhalb des Paars; Zeichen sind keine Grapheme.'
            + NCHAR(10)
            + N'@TruncatedValueCount bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @TruncatedValueCount=@bigintVariable OUTPUT binden. Nach erfolgreicher Parameterprüfung und vor der dynamischen Ausführung 0; nach Verarbeitung COUNT_BIG ausschließlich der gekürzten Zeilen, bei keiner Kürzung 0.'
            + NCHAR(10)
            + N'@LargestRequiredCharacters bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @LargestRequiredCharacters=@bigintVariable OUTPUT binden. Nach erfolgreicher Guard-Initialisierung NULL; nach Verarbeitung MAX der OriginalCharacters ausschließlich gekürzter Zeilen, bei keiner Kürzung NULL.'
            + NCHAR(10)
            + N'Abhängigkeit: monitor.TVF_ProjectUnicodeText bestimmt Zeichen-, Byte- und Kürzungssemantik. Surrogatpaare zählen als ein SC-Zeichen, nachgestellte Leerzeichen werden gezählt, Bytes entsprechen DATALENGTH; es gibt keine Graphemgarantie.'
            + NCHAR(10)
            + N'Die vollständige fachliche Quelle muss der interne Caller vorab materialisieren. Alle drei Metadatenspalten werden für jede Zeile aktualisiert. Nicht vorhandene, leere oder typinkompatible Spalten werden nicht vorab geprüft; dynamisches SQL kann normale native Fehler auslösen. Es gibt keine eigene Transaktion oder CATCH-Behandlung.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.InternalProjectUnicodeTextColumn
        RETURN;
    END;

    SET LOCK_TIMEOUT 0;

    IF @SourceTable IS NULL OR LEFT(@SourceTable,1)<>N'#'
       OR LEFT(@SourceTable,2)=N'##'
       OR @TextColumn IS NULL OR @CharactersColumn IS NULL
       OR @BytesColumn IS NULL OR @IsTruncatedColumn IS NULL
       OR @MaxCharacters<0
        THROW 51021,N'InternalProjectUnicodeTextColumn benötigt eine lokale Temp-Tabelle, gültige Spalten und einen nichtnegativen Grenzwert.',1;

    DECLARE @Sql nvarchar(max)=N'
UPDATE [source]
SET '+QUOTENAME(@CharactersColumn)+N'=[projection].[OriginalCharacters],
    '+QUOTENAME(@BytesColumn)+N'=[projection].[OriginalBytes],
    '+QUOTENAME(@IsTruncatedColumn)+N'=[projection].[IsTruncated],
    '+QUOTENAME(@TextColumn)+N'=[projection].[ProjectedValue]
FROM '+QUOTENAME(@SourceTable)+N' AS [source]
CROSS APPLY [monitor].[TVF_ProjectUnicodeText]([source].'+QUOTENAME(@TextColumn)+N',@Limit) AS [projection];

SELECT @Count=COUNT_BIG(*),@Largest=MAX('+QUOTENAME(@CharactersColumn)+N')
FROM '+QUOTENAME(@SourceTable)+N'
WHERE '+QUOTENAME(@IsTruncatedColumn)+N'=1;';

    SET @TruncatedValueCount=0;
    SET @LargestRequiredCharacters=NULL;
    EXEC [sys].[sp_executesql]
          @Sql
        , N'@Limit int,@Count bigint OUTPUT,@Largest bigint OUTPUT'
        , @Limit=@MaxCharacters
        , @Count=@TruncatedValueCount OUTPUT
        , @Largest=@LargestRequiredCharacters OUTPUT;
END;
GO

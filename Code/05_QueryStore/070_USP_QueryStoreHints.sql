USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_QueryStoreHints
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Liefert Query-Store-Hints aus einer oder mehreren
               Quelldatenbanken mit globaler Top-N-Ausgabe. Die Funktion ist
               ab SQL Server 2022 verfügbar.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_QueryStoreHints 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_QueryStoreHints"
-- schema_name: "monitor"
-- object_name: "USP_QueryStoreHints"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Liefert Query-Store-Hints aus einer oder mehreren Quelldatenbanken mit globaler Top-N-Ausgabe."
-- source_path: "Code/05_QueryStore/070_USP_QueryStoreHints.sql"
-- ---
-- 
-- # monitor.USP_QueryStoreHints
-- 
-- ## Zweck und Einsatz
-- 
-- Liefert Query-Store-Hints aus einer oder mehreren Quelldatenbanken mit globaler Top-N-Ausgabe. Die Funktion ist ab SQL Server 2022 verfügbar.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_QueryStoreHints]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[monitor].[InternalCheckAnalysisPath]`, `[sys].[all_objects]`, `[sys].[schemas]`, `[master].[sys].[databases]`, `[sys].[query_store_query_hints]`, `[sys].[query_store_query]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @QueryStoreDatabaseNames | nvarchar(max) | nein | NULL |
-- | @QueryStoreDatabaseNamePattern | nvarchar(4000) | nein | NULL |
-- | @HighImpactConfirmed | bit | nein | 0 |
-- | @QueryId | bigint | nein | NULL |
-- | @NurMitFehler | bit | nein | 0 |
-- | @MaxZeilen | int | nein | 100 |
-- | @MaxSqlTextZeichen | int | nein | 4000 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@QueryStoreDatabaseNames:** @QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]|[OtherDatabase]'; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen.
-- 
-- **@QueryStoreDatabaseNamePattern:** @QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert.
-- 
-- **@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. In diesem Modul wird Deep ausschließlich bei normalisiertem Zeilenlimit >1000, also auch NULL/0 unbegrenzt, zusätzlich geprüft.
-- 
-- **@QueryId:** @QueryId bigint; Default: NULL. Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch.
-- 
-- **@NurMitFehler:** @NurMitFehler bit; Default: 0. Ausgelassen/0: alle gespeicherten Hints. 1 oder NULL: nur Hints mit QueryHintFailureCount > 0 ODER LastQueryHintFailureReason ungleich 0; NULL wird nicht auf 0 normalisiert, sondern wirkt durch SQL-Dreiwertlogik wie der Fehlerfilter. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.
-- 
-- **@MaxZeilen:** @MaxZeilen int; Default: 100. Weglassen verwendet 100. NULL oder 0 bedeutet unbegrenzt; ein positiver Wert ist die globale Höchstzahl exportierter Zeilen. Pro Datenbank wird bei endlichem Limit lokal bis zu Limit+1 gelesen, anschließend wird global sortiert und begrenzt. Negative Werte liefern INVALID_PARAMETER. Wenn das normalisierte Limit > 1000 ist, wird nach QUERY_STORE_CURRENT zusätzlich QUERY_STORE_DEEP geprüft; NULL/0 normalisieren auf unbegrenzt und lösen diese Prüfung ebenfalls aus. Bei int-Maximum 2147483647 wird lokal N ohne +1 verwendet. Ganze Zahlen von 1 bis 2147483647 sind positive Limits. Lokal und global werden Fehlergrund ungleich 0 zuerst, dann QueryHintFailureCount absteigend und QueryHintId aufsteigend gereiht. Hint-IDs sind quellenspezifisch, gleiche Sortwerte zwischen Quellen legen keine eindeutige Auswahl fest. Textprojektion, Warnungen und Zähler beziehen sich auf alle lokalen Kandidaten vor dem globalen Limit.
-- 
-- **@MaxSqlTextZeichen:** @MaxSqlTextZeichen int; Default: 4000. Weglassen verwendet 4000 Zeichen. NULL oder 0 bedeutet unbegrenzten QuerySqlText; ein positiver Wert begrenzt nur den projizierten Querytext nach dem Einlesen und Join. QueryHintText wird nicht gekürzt; das Limit begrenzt weder die Quelllesung noch die Hinttextlänge. Negative Werte liefern INVALID_PARAMETER. Gekürzte Querytexte erhalten Längen-/Byte-/Truncationmetadaten; bei aktivierten Meldungen erscheint höchstens eine Kürzungswarnung. Als positive ganze Zahl bis 2147483647 übergeben. Unicode-SC-Zählung lässt Surrogatpaare zusammen und zählt keine Grapheme.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Weglassen verwendet CONSOLE. Zulässige feste Werte sind RAW, CONSOLE, TABLE und NONE; Groß-/Kleinschreibung wird ignoriert und äußere Leerzeichen werden entfernt. NULL sowie leerer/nur aus Leerzeichen bestehender Text und alle anderen Werte liefern INVALID_PARAMETER. CONSOLE gibt nur die fachliche Hint-Tabelle über den aktiven Console-Helper aus; RAW liefert Statusmetadaten, vollständige Exportdaten und Warnungen als Resultsets; TABLE schreibt das vollständige fachliche Exportset in das zugeordnete Ziel; NONE gibt keine Resultsets aus. Die Bindung an varchar(16) erfolgt vor der Prüfung; LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen. CONSOLE ergänzt bei nichtleerer Fachmenge das Ergebnislabel; bei Leere liefert es eine Hinweiszeile. JSON bleibt unabhängig.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. außerhalb TABLE nur NULL, leer oder äußere U+0020-Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel queryHints und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Ausgelassen/0 oder NULL: kein JSON. 1 erzeugt @Json als Objekt mit meta (Metadaten), queryHints (globale Hint-Exportmenge) und warnings (Warnungen), unabhängig von @ResultSetArt. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.
-- 
-- **@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit; Default: 1. ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.
-- 
-- **@Hilfe:** @Hilfe bit; Default: 0. ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.
-- 
-- ## Resultate und Ausgabe
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | queryHints | 1 | 1 | [QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryHintId] bigint,[QueryId] bigint,[ReplicaGroupId] bigint,[QueryHash] binary(8),[QueryHintText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[LastQueryHintFailureReason] int,[LastQueryHintFailureReasonDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryHintFailureCount] bigint,[Source] int,[SourceDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsCurrent] bit NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL DEFAULT(0),[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_QueryStoreHints] @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_QueryStoreHints
-- 
-- monitor.USP_QueryStoreHints inventarisiert gespeicherte Query-Store-Hints und deren Fehlerstatus. Gespeicherte Konfiguration belegt nicht die Wirkung künftiger Ausführungen. Verfügbar ab SQL Server 2022; Systemdatenbanken sind ausgeschlossen.
-- 
-- Die fachlichen Validierungsregeln gelten im normalen Analysepfad. @Hilfe=1 kehrt davor zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt jeweils der ausdrücklich angegebene Default.
-- 
-- DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
-- 
-- CREATE TABLE [#QueryStoreHints_HelpExample]([Seed] int NULL);
-- BEGIN TRY
--  EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"queryHints":"#QueryStoreHints_HelpExample"}';
--  SELECT * FROM [#QueryStoreHints_HelpExample];
--  DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];
-- END TRY
-- BEGIN CATCH
--  DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];
--  THROW;
-- END CATCH;
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_QueryStoreHints
-- Version      : 2.0.0
-- Stand        : 2026-07-15
-- Zweck        : Liefert Query-Store-Hints aus einer oder mehreren
--                Quelldatenbanken mit globaler Top-N-Ausgabe. Die Funktion ist
--                ab SQL Server 2022 verfügbar.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_QueryStoreHints
-- monitor.USP_QueryStoreHints inventarisiert gespeicherte Query-Store-Hints und deren Fehlerstatus. Gespeicherte Konfiguration belegt nicht die Wirkung künftiger Ausführungen. Verfügbar ab SQL Server 2022; Systemdatenbanken sind ausgeschlossen.
-- Die fachlichen Validierungsregeln gelten im normalen Analysepfad. @Hilfe=1 kehrt davor zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt jeweils der ausdrücklich angegebene Default.
-- DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
-- CREATE TABLE [#QueryStoreHints_HelpExample]([Seed] int NULL);
-- BEGIN TRY
--  EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"queryHints":"#QueryStoreHints_HelpExample"}';
--  SELECT * FROM [#QueryStoreHints_HelpExample];
--  DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];
-- END TRY
-- BEGIN CATCH
--  DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];
--  THROW;
-- END CATCH;
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_QueryStoreHints
CREATE OR ALTER PROCEDURE [monitor].[USP_QueryStoreHints]
      @QueryStoreDatabaseNames          nvarchar(max)  = NULL
    , @QueryStoreDatabaseNamePattern    nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @QueryId                          bigint         = NULL
    , @NurMitFehler                     bit            = 0
    , @MaxZeilen                        int            = 100
    , @MaxSqlTextZeichen                int            = 4000
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
AS
BEGIN
 SET NOCOUNT ON;

    IF @Hilfe=1
 BEGIN
        SET @Json=NULL;
        PRINT N'monitor.USP_QueryStoreHints';
        PRINT N'monitor.USP_QueryStoreHints inventarisiert gespeicherte Query-Store-Hints und deren Fehlerstatus. Gespeicherte Konfiguration belegt nicht die Wirkung künftiger Ausführungen. Verfügbar ab SQL Server 2022; Systemdatenbanken sind ausgeschlossen.';
        PRINT N'Die fachlichen Validierungsregeln gelten im normalen Analysepfad. @Hilfe=1 kehrt davor zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt jeweils der ausdrücklich angegebene Default.';
        PRINT N'@QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'''' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N''[ExampleDatabase]|[OtherDatabase]''; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen.';
        PRINT N'@QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. In diesem Modul wird Deep ausschließlich bei normalisiertem Zeilenlimit >1000, also auch NULL/0 unbegrenzt, zusätzlich geprüft.';
        PRINT N'@QueryId bigint; Default: NULL. Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch.';
        PRINT N'@NurMitFehler bit; Default: 0. Ausgelassen/0: alle gespeicherten Hints. 1 oder NULL: nur Hints mit QueryHintFailureCount > 0 ODER LastQueryHintFailureReason ungleich 0; NULL wird nicht auf 0 normalisiert, sondern wirkt durch SQL-Dreiwertlogik wie der Fehlerfilter. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@MaxZeilen int; Default: 100. Weglassen verwendet 100. NULL oder 0 bedeutet unbegrenzt; ein positiver Wert ist die globale Höchstzahl exportierter Zeilen. Pro Datenbank wird bei endlichem Limit lokal bis zu Limit+1 gelesen, anschließend wird global sortiert und begrenzt. Negative Werte liefern INVALID_PARAMETER. Wenn das normalisierte Limit > 1000 ist, wird nach QUERY_STORE_CURRENT zusätzlich QUERY_STORE_DEEP geprüft; NULL/0 normalisieren auf unbegrenzt und lösen diese Prüfung ebenfalls aus. Bei int-Maximum 2147483647 wird lokal N ohne +1 verwendet. Ganze Zahlen von 1 bis 2147483647 sind positive Limits. Lokal und global werden Fehlergrund ungleich 0 zuerst, dann QueryHintFailureCount absteigend und QueryHintId aufsteigend gereiht. Hint-IDs sind quellenspezifisch, gleiche Sortwerte zwischen Quellen legen keine eindeutige Auswahl fest. Textprojektion, Warnungen und Zähler beziehen sich auf alle lokalen Kandidaten vor dem globalen Limit.';
        PRINT N'@MaxSqlTextZeichen int; Default: 4000. Weglassen verwendet 4000 Zeichen. NULL oder 0 bedeutet unbegrenzten QuerySqlText; ein positiver Wert begrenzt nur den projizierten Querytext nach dem Einlesen und Join. QueryHintText wird nicht gekürzt; das Limit begrenzt weder die Quelllesung noch die Hinttextlänge. Negative Werte liefern INVALID_PARAMETER. Gekürzte Querytexte erhalten Längen-/Byte-/Truncationmetadaten; bei aktivierten Meldungen erscheint höchstens eine Kürzungswarnung. Als positive ganze Zahl bis 2147483647 übergeben. Unicode-SC-Zählung lässt Surrogatpaare zusammen und zählt keine Grapheme.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Weglassen verwendet CONSOLE. Zulässige feste Werte sind RAW, CONSOLE, TABLE und NONE; Groß-/Kleinschreibung wird ignoriert und äußere Leerzeichen werden entfernt. NULL sowie leerer/nur aus Leerzeichen bestehender Text und alle anderen Werte liefern INVALID_PARAMETER. CONSOLE gibt nur die fachliche Hint-Tabelle über den aktiven Console-Helper aus; RAW liefert Statusmetadaten, vollständige Exportdaten und Warnungen als Resultsets; TABLE schreibt das vollständige fachliche Exportset in das zugeordnete Ziel; NONE gibt keine Resultsets aus. Die Bindung an varchar(16) erfolgt vor der Prüfung; LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen. CONSOLE ergänzt bei nichtleerer Fachmenge das Ergebnislabel; bei Leere liefert es eine Hinweiszeile. JSON bleibt unabhängig.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. außerhalb TABLE nur NULL, leer oder äußere U+0020-Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel queryHints und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema.';
        PRINT N'@JsonErzeugen bit; Default: 0. Ausgelassen/0 oder NULL: kein JSON. 1 erzeugt @Json als Objekt mit meta (Metadaten), queryHints (globale Hint-Exportmenge) und warnings (Warnungen), unabhängig von @ResultSetArt. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung.';
        PRINT N'@PrintMeldungen bit; Default: 1. ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.';
        PRINT N'@Hilfe bit; Default: 0. ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.';
        PRINT N'EXEC [monitor].[USP_QueryStoreHints] @Hilfe=1;';
        PRINT N'EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];';
        PRINT N'CREATE TABLE [#QueryStoreHints_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"queryHints":"#QueryStoreHints_HelpExample"}'';
 SELECT * FROM [#QueryStoreHints_HelpExample];
 DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];
 THROW;
END CATCH;';
  -- USAGE_SKILL_HELP_BEGIN monitor.USP_QueryStoreHints
  SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_QueryStoreHints') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_QueryStoreHints"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_QueryStoreHints"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Liefert Query-Store-Hints aus einer oder mehreren Quelldatenbanken mit globaler Top-N-Ausgabe."'
            + NCHAR(10)
            + N'source_path: "Code/05_QueryStore/070_USP_QueryStoreHints.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_QueryStoreHints'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Liefert Query-Store-Hints aus einer oder mehreren Quelldatenbanken mit globaler Top-N-Ausgabe. Die Funktion ist ab SQL Server 2022 verfügbar.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_QueryStoreHints]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[monitor].[InternalCheckAnalysisPath]`, `[sys].[all_objects]`, `[sys].[schemas]`, `[master].[sys].[databases]`, `[sys].[query_store_query_hints]`, `[sys].[query_store_query]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
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
            + N'| @QueryStoreDatabaseNames | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @QueryStoreDatabaseNamePattern | nvarchar(4000) | nein | NULL |'
            + NCHAR(10)
            + N'| @HighImpactConfirmed | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @QueryId | bigint | nein | NULL |'
            + NCHAR(10)
            + N'| @NurMitFehler | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @MaxZeilen | int | nein | 100 |'
            + NCHAR(10)
            + N'| @MaxSqlTextZeichen | int | nein | 4000 |'
            + NCHAR(10)
            + N'| @ResultSetArt | varchar(16) | nein | ''CONSOLE'' |'
            + NCHAR(10)
            + N'| @ResultTablesJson | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @JsonErzeugen | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @Json | nvarchar(max) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @PrintMeldungen | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@QueryStoreDatabaseNames:** @QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'''' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N''[ExampleDatabase]|[OtherDatabase]''; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@QueryStoreDatabaseNamePattern:** @QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. In diesem Modul wird Deep ausschließlich bei normalisiertem Zeilenlimit >1000, also auch NULL/0 unbegrenzt, zusätzlich geprüft.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@QueryId:** @QueryId bigint; Default: NULL. Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@NurMitFehler:** @NurMitFehler bit; Default: 0. Ausgelassen/0: alle gespeicherten Hints. 1 oder NULL: nur Hints mit QueryHintFailureCount > 0 ODER LastQueryHintFailureReason ungleich 0; NULL wird nicht auf 0 normalisiert, sondern wirkt durch SQL-Dreiwertlogik wie der Fehlerfilter. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxZeilen:** @MaxZeilen int; Default: 100. Weglassen verwendet 100. NULL oder 0 bedeutet unbegrenzt; ein positiver Wert ist die globale Höchstzahl exportierter Zeilen. Pro Datenbank wird bei endlichem Limit lokal bis zu Limit+1 gelesen, anschließend wird global sortiert und begrenzt. Negative Werte liefern INVALID_PARAMETER. Wenn das normalisierte Limit > 1000 ist, wird nach QUERY_STORE_CURRENT zusätzlich QUERY_STORE_DEEP geprüft; NULL/0 normalisieren auf unbegrenzt und lösen diese Prüfung ebenfalls aus. Bei int-Maximum 2147483647 wird lokal N ohne +1 verwendet. Ganze Zahlen von 1 bis 2147483647 sind positive Limits. Lokal und global werden Fehlergrund ungleich 0 zuerst, dann QueryHintFailureCount absteigend und QueryHintId aufsteigend gereiht. Hint-IDs sind quellenspezifisch, gleiche Sortwerte zwischen Quellen legen keine eindeutige Auswahl fest. Textprojektion, Warnungen und Zähler beziehen sich auf alle lokalen Kandidaten vor dem globalen Limit.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int; Default: 4000. Weglassen verwendet 4000 Zeichen. NULL oder 0 bedeutet unbegrenzten QuerySqlText; ein positiver Wert begrenzt nur den projizierten Querytext nach dem Einlesen und Join. QueryHintText wird nicht gekürzt; das Limit begrenzt weder die Quelllesung noch die Hinttextlänge. Negative Werte liefern INVALID_PARAMETER. Gekürzte Querytexte erhalten Längen-/Byte-/Truncationmetadaten; bei aktivierten Meldungen erscheint höchstens eine Kürzungswarnung. Als positive ganze Zahl bis 2147483647 übergeben. Unicode-SC-Zählung lässt Surrogatpaare zusammen und zählt keine Grapheme.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16); Default: ''CONSOLE''. Weglassen verwendet CONSOLE. Zulässige feste Werte sind RAW, CONSOLE, TABLE und NONE; Groß-/Kleinschreibung wird ignoriert und äußere Leerzeichen werden entfernt. NULL sowie leerer/nur aus Leerzeichen bestehender Text und alle anderen Werte liefern INVALID_PARAMETER. CONSOLE gibt nur die fachliche Hint-Tabelle über den aktiven Console-Helper aus; RAW liefert Statusmetadaten, vollständige Exportdaten und Warnungen als Resultsets; TABLE schreibt das vollständige fachliche Exportset in das zugeordnete Ziel; NONE gibt keine Resultsets aus. Die Bindung an varchar(16) erfolgt vor der Prüfung; LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen. CONSOLE ergänzt bei nichtleerer Fachmenge das Ergebnislabel; bei Leere liefert es eine Hinweiszeile. JSON bleibt unabhängig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. außerhalb TABLE nur NULL, leer oder äußere U+0020-Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel queryHints und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Ausgelassen/0 oder NULL: kein JSON. 1 erzeugt @Json als Objekt mit meta (Metadaten), queryHints (globale Hint-Exportmenge) und warnings (Warnungen), unabhängig von @ResultSetArt. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit; Default: 0. ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| queryHints | 1 | 1 | [QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryHintId] bigint,[QueryId] bigint,[ReplicaGroupId] bigint,[QueryHash] binary(8),[QueryHintText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[LastQueryHintFailureReason] int,[LastQueryHintFailureReasonDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryHintFailureCount] bigint,[Source] int,[SourceDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsCurrent] bit NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL DEFAULT(0),[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_Genera'
            + N'l_CP1_CS_AS NULL |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[USP_QueryStoreHints] @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_QueryStoreHints'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_QueryStoreHints inventarisiert gespeicherte Query-Store-Hints und deren Fehlerstatus. Gespeicherte Konfiguration belegt nicht die Wirkung künftiger Ausführungen. Verfügbar ab SQL Server 2022; Systemdatenbanken sind ausgeschlossen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die fachlichen Validierungsregeln gelten im normalen Analysepfad. @Hilfe=1 kehrt davor zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt jeweils der ausdrücklich angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];'
            + NCHAR(10)
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE [#QueryStoreHints_HelpExample]([Seed] int NULL);'
            + NCHAR(10)
            + N'BEGIN TRY'
            + NCHAR(10)
            + N' EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"queryHints":"#QueryStoreHints_HelpExample"}'';'
            + NCHAR(10)
            + N' SELECT * FROM [#QueryStoreHints_HelpExample];'
            + NCHAR(10)
            + N' DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];'
            + NCHAR(10)
            + N'END TRY'
            + NCHAR(10)
            + N'BEGIN CATCH'
            + NCHAR(10)
            + N' DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];'
            + NCHAR(10)
            + N' THROW;'
            + NCHAR(10)
            + N'END CATCH;'
            + NCHAR(10)
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
            + N'Objekt       : monitor.USP_QueryStoreHints'
            + NCHAR(10)
            + N'Version      : 2.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-15'
            + NCHAR(10)
            + N'Zweck        : Liefert Query-Store-Hints aus einer oder mehreren'
            + NCHAR(10)
            + N'               Quelldatenbanken mit globaler Top-N-Ausgabe. Die Funktion ist'
            + NCHAR(10)
            + N'               ab SQL Server 2022 verfügbar.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_QueryStoreHints'
            + NCHAR(10)
            + N'monitor.USP_QueryStoreHints inventarisiert gespeicherte Query-Store-Hints und deren Fehlerstatus. Gespeicherte Konfiguration belegt nicht die Wirkung künftiger Ausführungen. Verfügbar ab SQL Server 2022; Systemdatenbanken sind ausgeschlossen.'
            + NCHAR(10)
            + N'Die fachlichen Validierungsregeln gelten im normalen Analysepfad. @Hilfe=1 kehrt davor zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt jeweils der ausdrücklich angegebene Default.'
            + NCHAR(10)
            + N'DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];'
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE [#QueryStoreHints_HelpExample]([Seed] int NULL);'
            + NCHAR(10)
            + N'BEGIN TRY'
            + NCHAR(10)
            + N' EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"queryHints":"#QueryStoreHints_HelpExample"}'';'
            + NCHAR(10)
            + N' SELECT * FROM [#QueryStoreHints_HelpExample];'
            + NCHAR(10)
            + N' DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];'
            + NCHAR(10)
            + N'END TRY'
            + NCHAR(10)
            + N'BEGIN CATCH'
            + NCHAR(10)
            + N' DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];'
            + NCHAR(10)
            + N' THROW;'
            + NCHAR(10)
            + N'END CATCH;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
  -- USAGE_SKILL_HELP_END monitor.USP_QueryStoreHints
        RETURN;
 END
SET @Json=NULL;DECLARE @Out varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),@Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen>0 THEN @MaxZeilen ELSE 0 END,@Local bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen<2147483647 THEN CONVERT(bigint,@MaxZeilen)+1 ELSE @MaxZeilen END;
 CREATE TABLE [#QueryStoreHints_Export]([QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryHintId] bigint,[QueryId] bigint,[ReplicaGroupId] bigint,[QueryHash] binary(8),[QueryHintText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[LastQueryHintFailureReason] int,[LastQueryHintFailureReasonDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryHintFailureCount] bigint,[Source] int,[SourceDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsCurrent] bit NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL DEFAULT(0),[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    DECLARE @TableResultRequested bit = CASE WHEN @Out = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @Out = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'queryHints',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @Out = 'NONE';
 ;
 DECLARE @Now datetime2(3)=SYSUTCDATETIME(),@Status varchar(40)='AVAILABLE',@Partial bit=0,@Error nvarchar(2048)=NULL,@Cross bit=0,@Allowed bit=1,@Db sysname,@Sql nvarchar(max),@Count bigint=0,@HasMore bit=0,@Msg nvarchar(2048);
 CREATE TABLE [#QueryStoreHints_DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsSystemDatabase] bit,[RequestedOrdinal] int);
 CREATE TABLE [#QueryStoreHints_Result]([QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryHintId] bigint,[QueryId] bigint,[ReplicaGroupId] bigint,[QueryHash] binary(8),[QueryHintText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[LastQueryHintFailureReason] int,[LastQueryHintFailureReasonDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryHintFailureCount] bigint,[Source] int,[SourceDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsCurrent] bit NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL DEFAULT(0),[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 CREATE TABLE [#QueryStoreHints_Errors]([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS);
 IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<16 BEGIN SET @Status='UNAVAILABLE_VERSION';SET @Error=N'Query Store Hints sind erst ab SQL Server 2022 verfügbar.';END;
 IF @MaxZeilen<0 OR @MaxSqlTextZeichen < 0 OR @Out NOT IN('RAW','CONSOLE','NONE') BEGIN SET @Status='INVALID_PARAMETER';SET @Error=N'Ungültiger Parameter.';END;
 IF @Status='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@QueryStoreDatabaseNames,@SystemdatenbankenEinbeziehen=0,@DatabaseNamePattern=@QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed,@AnalysisClass='QUERY_STORE_CURRENT',@StatusCode=@Status OUTPUT,@ErrorMessage=@Error OUTPUT,@CrossDatabaseRequested=@Cross OUTPUT,@CandidateTable=N'#QueryStoreHints_DatabaseCandidates';
 IF @Status='AVAILABLE' AND @Limit>1000 EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='QUERY_STORE_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@Status OUTPUT,@ErrorMessage=@Error OUTPUT;
 SET LOCK_TIMEOUT 0;
 IF @Status='AVAILABLE' BEGIN DECLARE [c] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName] FROM [#QueryStoreHints_DatabaseCandidates] ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];OPEN [c];FETCH NEXT FROM [c] INTO @Db;WHILE @@FETCH_STATUS=0 BEGIN BEGIN TRY SET @Sql=N'USE '+QUOTENAME(@Db)+N';IF EXISTS(SELECT 1 FROM [sys].[all_objects] AS [o] WITH (NOLOCK) JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id] WHERE [s].[name]=N''sys'' AND [o].[name]=N''query_store_query_hints'') INSERT [#QueryStoreHints_Result]([QueryStoreDatabaseId],[QueryStoreDatabaseName],[QueryHintId],[QueryId],[ReplicaGroupId],[QueryHash],[QueryHintText],[LastQueryHintFailureReason],[LastQueryHintFailureReasonDesc],[QueryHintFailureCount],[Source],[SourceDesc],[QuerySqlText]) SELECT TOP(@TopRows) DB_ID(),(SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()),[h].[query_hint_id],[h].[query_id],[h].[replica_group_id],[q].[query_hash],[h].[query_hint_text],[h].[last_query_hint_failure_reason],[h].[last_query_hint_failure_reason_desc],[h].[query_hint_failure_count],[h].[source],[h].[source_desc],[qt].[query_sql_text] FROM [sys].[query_store_query_hints] [h] WITH (NOLOCK) LEFT JOIN [sys].[query_store_query] [q] WITH (NOLOCK) ON [q].[query_id]=[h].[query_id] LEFT JOIN [sys].[query_store_query_text] [qt] WITH (NOLOCK) ON [qt].[query_text_id]=[q].[query_text_id] WHERE (@QueryId IS NULL OR [h].[query_id]=@QueryId) AND (@OnlyErrors=0 OR [h].[query_hint_failure_count]>0 OR [h].[last_query_hint_failure_reason]<>0) ORDER BY CASE WHEN [h].[last_query_hint_failure_reason]<>0 THEN 0 ELSE 1 END,[h].[query_hint_failure_count] DESC,[h].[query_hint_id];';EXEC [sys].[sp_executesql] @Sql,N'@TopRows bigint,@QueryId bigint,@OnlyErrors bit',@Local,@QueryId,@NurMitFehler;END TRY BEGIN CATCH INSERT [#QueryStoreHints_Errors] VALUES(@Db,CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN(207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,ERROR_NUMBER(),ERROR_MESSAGE());SET @Partial=1;IF @PrintMeldungen=1 BEGIN SET @Msg=FORMATMESSAGE(N'WARNUNG USP_QueryStoreHints [%s]: %s',@Db,ERROR_MESSAGE());RAISERROR(N'%s',10,1,@Msg) WITH NOWAIT;END;END CATCH;FETCH NEXT FROM [c] INTO @Db;END;CLOSE [c];DEALLOCATE [c];END;
 UPDATE [#QueryStoreHints_Result]
 SET [SourceType]='QUERY_STORE',[SourceObject]=N'sys.query_store_query_hints|sys.query_store_query_text',
     [CapturedAtUtc]=@Now,[EvidenceScope]='DATABASE_QUERY_HINT',[IsCurrent]=1,
     [EvidenceLimit]=N'Aktueller gespeicherter Query-Store-Hintstatus; keine Aussage über die Wirksamkeit jeder zukünftigen Ausführung.';
 DECLARE @TruncatedValueCount bigint=0,@LargestRequiredCharacters bigint=NULL;
 IF @MaxSqlTextZeichen IS NULL OR @MaxSqlTextZeichen>=0
 EXEC [monitor].[InternalProjectUnicodeTextColumn] @SourceTable=N'#QueryStoreHints_Result',@TextColumn=N'QuerySqlText',@CharactersColumn=N'QuerySqlTextCharacters',@BytesColumn=N'QuerySqlTextBytes',@IsTruncatedColumn=N'QuerySqlTextIsTruncated',@MaxCharacters=@MaxSqlTextZeichen,@TruncatedValueCount=@TruncatedValueCount OUTPUT,@LargestRequiredCharacters=@LargestRequiredCharacters OUTPUT;
 EXEC [monitor].[InternalEmitTruncationWarning] @TruncatedValueCount=@TruncatedValueCount,@ParameterName=N'@MaxSqlTextZeichen',@ParameterValue=@MaxSqlTextZeichen,@LargestRequiredCharacters=@LargestRequiredCharacters,@PrintMeldungen=@PrintMeldungen;
 SELECT @Count=COUNT_BIG(*) FROM [#QueryStoreHints_Result];SET @HasMore=CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @Count>@Limit THEN 1 ELSE 0 END);IF @Partial=1 AND @Status='AVAILABLE' SET @Status='AVAILABLE_LIMITED';
 INSERT [#QueryStoreHints_Export] SELECT TOP(@Limit) * FROM [#QueryStoreHints_Result] ORDER BY CASE WHEN [LastQueryHintFailureReason]<>0 THEN 0 ELSE 1 END,[QueryHintFailureCount] DESC,[QueryHintId];
 IF @Out<>'NONE' BEGIN SELECT N'USP_QueryStoreHints' [ModuleName],@Now [CollectionTimeUtc],@Status [StatusCode],@Partial [IsPartial],CASE WHEN @Count>@Limit THEN @Limit ELSE @Count END [ReturnedRowCount],@HasMore [HasMoreRows],@Error [ErrorMessage];IF @Out='RAW' SELECT * FROM [#QueryStoreHints_Export] ORDER BY CASE WHEN [LastQueryHintFailureReason]<>0 THEN 0 ELSE 1 END,[QueryHintFailureCount] DESC,[QueryHintId];ELSE SELECT N'Query-Store Hint' [Ergebnis],[QueryStoreDatabaseName] [Query-Store-Datenbank],[QueryId] [Query],[QueryHintText] [Hint],[LastQueryHintFailureReasonDesc] [letzter Fehler],[QueryHintFailureCount] [Fehleranzahl],[QueryStoreDatabaseName] [Quelle],[QuerySqlText] [SQL-Text] FROM [#QueryStoreHints_Export] ORDER BY CASE WHEN [LastQueryHintFailureReason]<>0 THEN 0 ELSE 1 END,[QueryHintFailureCount] DESC,[QueryHintId];SELECT * FROM [#QueryStoreHints_Errors] ORDER BY [DatabaseName];END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'QueryStoreHints' [resultName],1 [schemaVersion],@Now [generatedAtUtc],@Status [statusCode],@MaxZeilen [requestedMaxRows],CASE WHEN @Count>@Limit THEN @Limit ELSE @Count END [returnedRows],@HasMore [hasMoreRows] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@Data nvarchar(max)=(SELECT * FROM [#QueryStoreHints_Export] ORDER BY CASE WHEN [LastQueryHintFailureReason]<>0 THEN 0 ELSE 1 END,[QueryHintFailureCount] DESC,[QueryHintId] FOR JSON PATH,INCLUDE_NULL_VALUES),@Warnings nvarchar(max)=(SELECT * FROM [#QueryStoreHints_Errors] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"queryHints":',COALESCE(@Data,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#QueryStoreHints_Export'
            , @ResultLabel=N'QueryStoreHints'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#QueryStoreHints_Export'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

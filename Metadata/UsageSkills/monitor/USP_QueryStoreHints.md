---
skill_format_version: "1.0.0"
name: "monitor.USP_QueryStoreHints"
schema_name: "monitor"
object_name: "USP_QueryStoreHints"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert Query-Store-Hints aus einer oder mehreren Quelldatenbanken mit globaler Top-N-Ausgabe."
source_path: "Code/05_QueryStore/070_USP_QueryStoreHints.sql"
---

# monitor.USP_QueryStoreHints

## Zweck und Einsatz

Liefert Query-Store-Hints aus einer oder mehreren Quelldatenbanken mit globaler Top-N-Ausgabe. Die Funktion ist ab SQL Server 2022 verfügbar.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_QueryStoreHints]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[monitor].[InternalCheckAnalysisPath]`, `[sys].[all_objects]`, `[sys].[schemas]`, `[master].[sys].[databases]`, `[sys].[query_store_query_hints]`, `[sys].[query_store_query]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @QueryStoreDatabaseNames | nvarchar(max) | nein | NULL |
| @QueryStoreDatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @QueryId | bigint | nein | NULL |
| @NurMitFehler | bit | nein | 0 |
| @MaxZeilen | int | nein | 100 |
| @MaxSqlTextZeichen | int | nein | 4000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@QueryStoreDatabaseNames:** @QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]|[OtherDatabase]'; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen.

**@QueryStoreDatabaseNamePattern:** @QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. In diesem Modul wird Deep ausschließlich bei normalisiertem Zeilenlimit >1000, also auch NULL/0 unbegrenzt, zusätzlich geprüft.

**@QueryId:** @QueryId bigint; Default: NULL. Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch.

**@NurMitFehler:** @NurMitFehler bit; Default: 0. Ausgelassen/0: alle gespeicherten Hints. 1 oder NULL: nur Hints mit QueryHintFailureCount > 0 ODER LastQueryHintFailureReason ungleich 0; NULL wird nicht auf 0 normalisiert, sondern wirkt durch SQL-Dreiwertlogik wie der Fehlerfilter. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@MaxZeilen:** @MaxZeilen int; Default: 100. Weglassen verwendet 100. NULL oder 0 bedeutet unbegrenzt; ein positiver Wert ist die globale Höchstzahl exportierter Zeilen. Pro Datenbank wird bei endlichem Limit lokal bis zu Limit+1 gelesen, anschließend wird global sortiert und begrenzt. Negative Werte liefern INVALID_PARAMETER. Wenn das normalisierte Limit > 1000 ist, wird nach QUERY_STORE_CURRENT zusätzlich QUERY_STORE_DEEP geprüft; NULL/0 normalisieren auf unbegrenzt und lösen diese Prüfung ebenfalls aus. Bei int-Maximum 2147483647 wird lokal N ohne +1 verwendet. Ganze Zahlen von 1 bis 2147483647 sind positive Limits. Lokal und global werden Fehlergrund ungleich 0 zuerst, dann QueryHintFailureCount absteigend und QueryHintId aufsteigend gereiht. Hint-IDs sind quellenspezifisch, gleiche Sortwerte zwischen Quellen legen keine eindeutige Auswahl fest. Textprojektion, Warnungen und Zähler beziehen sich auf alle lokalen Kandidaten vor dem globalen Limit.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int; Default: 4000. Weglassen verwendet 4000 Zeichen. NULL oder 0 bedeutet unbegrenzten QuerySqlText; ein positiver Wert begrenzt nur den projizierten Querytext nach dem Einlesen und Join. QueryHintText wird nicht gekürzt; das Limit begrenzt weder die Quelllesung noch die Hinttextlänge. Negative Werte liefern INVALID_PARAMETER. Gekürzte Querytexte erhalten Längen-/Byte-/Truncationmetadaten; bei aktivierten Meldungen erscheint höchstens eine Kürzungswarnung. Als positive ganze Zahl bis 2147483647 übergeben. Unicode-SC-Zählung lässt Surrogatpaare zusammen und zählt keine Grapheme.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Weglassen verwendet CONSOLE. Zulässige feste Werte sind RAW, CONSOLE, TABLE und NONE; Groß-/Kleinschreibung wird ignoriert und äußere Leerzeichen werden entfernt. NULL sowie leerer/nur aus Leerzeichen bestehender Text und alle anderen Werte liefern INVALID_PARAMETER. CONSOLE gibt nur die fachliche Hint-Tabelle über den aktiven Console-Helper aus; RAW liefert Statusmetadaten, vollständige Exportdaten und Warnungen als Resultsets; TABLE schreibt das vollständige fachliche Exportset in das zugeordnete Ziel; NONE gibt keine Resultsets aus. Die Bindung an varchar(16) erfolgt vor der Prüfung; LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen. CONSOLE ergänzt bei nichtleerer Fachmenge das Ergebnislabel; bei Leere liefert es eine Hinweiszeile. JSON bleibt unabhängig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. außerhalb TABLE nur NULL, leer oder äußere U+0020-Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel queryHints und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Ausgelassen/0 oder NULL: kein JSON. 1 erzeugt @Json als Objekt mit meta (Metadaten), queryHints (globale Hint-Exportmenge) und warnings (Warnungen), unabhängig von @ResultSetArt. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

**@Hilfe:** @Hilfe bit; Default: 0. ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| queryHints | 1 | 1 | [QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryHintId] bigint,[QueryId] bigint,[ReplicaGroupId] bigint,[QueryHash] binary(8),[QueryHintText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[LastQueryHintFailureReason] int,[LastQueryHintFailureReasonDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryHintFailureCount] bigint,[Source] int,[SourceDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsCurrent] bit NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL DEFAULT(0),[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_QueryStoreHints] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_QueryStoreHints

monitor.USP_QueryStoreHints inventarisiert gespeicherte Query-Store-Hints und deren Fehlerstatus. Gespeicherte Konfiguration belegt nicht die Wirkung künftiger Ausführungen. Verfügbar ab SQL Server 2022; Systemdatenbanken sind ausgeschlossen.

Die fachlichen Validierungsregeln gelten im normalen Analysepfad. @Hilfe=1 kehrt davor zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt jeweils der ausdrücklich angegebene Default.

DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];

CREATE TABLE [#QueryStoreHints_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"queryHints":"#QueryStoreHints_HelpExample"}';
 SELECT * FROM [#QueryStoreHints_HelpExample];
 DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];
 THROW;
END CATCH;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_QueryStoreHints
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Liefert Query-Store-Hints aus einer oder mehreren
               Quelldatenbanken mit globaler Top-N-Ausgabe. Die Funktion ist
               ab SQL Server 2022 verfügbar.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_QueryStoreHints
monitor.USP_QueryStoreHints inventarisiert gespeicherte Query-Store-Hints und deren Fehlerstatus. Gespeicherte Konfiguration belegt nicht die Wirkung künftiger Ausführungen. Verfügbar ab SQL Server 2022; Systemdatenbanken sind ausgeschlossen.
Die fachlichen Validierungsregeln gelten im normalen Analysepfad. @Hilfe=1 kehrt davor zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt jeweils der ausdrücklich angegebene Default.
DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
CREATE TABLE [#QueryStoreHints_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"queryHints":"#QueryStoreHints_HelpExample"}';
 SELECT * FROM [#QueryStoreHints_HelpExample];
 DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];
 THROW;
END CATCH;
```


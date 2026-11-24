---
skill_format_version: "1.0.0"
name: "monitor.USP_QueryStoreForcedPlans"
schema_name: "monitor"
object_name: "USP_QueryStoreForcedPlans"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert erzwungene Query-Store-Pläne aus mehreren Quelldatenbanken mit globaler Top-N-Ausgabe und optionalem Referenzdatenbankfilter."
source_path: "Code/05_QueryStore/060_USP_QueryStoreForcedPlans.sql"
---

# monitor.USP_QueryStoreForcedPlans

## Zweck und Einsatz

Liefert erzwungene Query-Store-Pläne aus mehreren Quelldatenbanken mit globaler Top-N-Ausgabe und optionalem Referenzdatenbankfilter.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_QueryStoreForcedPlans]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[TVF_ParsePattern]`, `[monitor].[TVF_ParseSqlNameList]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[monitor].[InternalCheckAnalysisPath]`, `[master].[sys].[databases]`, `[sys].[database_query_store_options]`, `[sys].[query_store_plan]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @QueryStoreDatabaseNames | nvarchar(max) | nein | NULL |
| @QueryStoreDatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @ReferencedDatabaseNames | nvarchar(max) | nein | NULL |
| @ReferencedDatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @QueryId | bigint | nein | NULL |
| @NurMitFehler | bit | nein | 0 |
| @MitPlanXml | bit | nein | 0 |
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

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

**@ReferencedDatabaseNames:** @ReferencedDatabaseNames nvarchar(max); Default: NULL. ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; | trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus.

**@ReferencedDatabaseNamePattern:** @ReferencedDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert.

**@QueryId:** @QueryId bigint; Default: NULL. Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch.

**@NurMitFehler:** @NurMitFehler bit; Default: 0. Weglassen ergibt 0. Numerisches 0 wird zu 0, jeder numerische Nichtnullwert zu 1. 0 zeigt alle als erzwungen markierten Pläne; 1 beschränkt auf ForceFailureCount > 0 oder LastForceFailureReason <> 0. NULL ist nicht als 0 behandelt und lässt durch SQL-NULL-Semantik praktisch nur Zeilen mit erfüllter Fehlerbedingung passieren.

**@MitPlanXml:** @MitPlanXml bit; Default: 0. Ausgelassen/0: keine exportierte Plan-XML und kein XML-Parsing; QueryPlanStatus ist NOT_REQUESTED. 1 aktiviert Ausgabe und Parsing des gespeicherten historischen Query-Store-Plans für alle lokal gesammelten Kandidaten vor dem globalen Limit und löst Deep aus; kein aktueller Laufzeitplan. NULL aktiviert weder Ausgabe/Parsing noch allein Deep, hat aber PENDING statt NOT_REQUESTED. Referenzfilter können Plan-XML unabhängig vom Ausgabeschalter lesen. Ungültiges XML bleibt als Rohtext mit Fehler-/Partialhinweis erhalten. Als bit 0/1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@MaxZeilen:** @MaxZeilen int; Default: 100. Weglassen ergibt globales Exportlimit 100. NULL oder 0 bedeutet unbegrenzt; positive Werte sind das globale Ausgabelimit. Negative Werte sind im normalen Aufruf ungültig. Je Datenbank wird lokal mit N+1 (bei int-Maximum höchstens int-Maximum) gelesen und die gemeinsame Menge anschließend global begrenzt; es handelt sich nicht um ein globales TOP im Quellzugriff. Ein normalisiertes Limit über 1000, auch NULL/0, aktiviert den Deep-Check. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben. Lokales und globales Ranking stellen Pläne mit LastForceFailureReason ungleich 0 voran, danach LastExecutionTimeUtc absteigend. ForceFailureCount ist kein Sortierschlüssel; Sortties garantieren keine bestimmte Auswahl. Textprojektion, XML-Parsing, Warnungen und Zähler betreffen alle lokalen Kandidaten vor dem globalen Limit.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int; Default: 4000. Weglassen begrenzt den projizierten Query-Text auf 4000 Zeichen. NULL oder 0 bedeutet unbegrenzt; ein positiver Wert ist die Unicode-sichere Zeichengrenze. Negative Werte sind im normalen Aufruf ungültig. Bei Kürzung kann abhängig von @PrintMeldungen eine Truncationwarnung erscheinen; die Grenze beschränkt die Ausgabeprojektion, nicht die Quellabfrage. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben. SC-Collation zählt ein Surrogatpaar als ein Zeichen; keine Graphemzählung, keine Kürzung des Plan-XML.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Ausgelassen: CONSOLE. Nach U+0020-Trim/Großschreibung sind genau vier Werte erlaubt: RAW liefert drei Resultsets (Metadaten, forcedPlans, Warnungen); CONSOLE liefert die fachliche Exportmenge mit Ergebnislabel oder bei Leere eine Hinweiszeile, ohne zusätzliche Metadaten-/Warnungsgrids; TABLE schreibt nur forcedPlans ins geprüfte lokale Temp-Ziel; NONE unterdrückt normale Fachresultsets. JSON ist unabhängig. NULL, leer, nur Leerzeichen und andere Werte sind im normalen Analysepfad ungültig. Der TABLE-Preflight liegt vor Hilfe und Fachvalidierung. Der Eingabewert unterliegt der varchar(16)-Bindungsbreite.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. außerhalb TABLE nur NULL, leer oder Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel forcedPlans und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Weglassen ergibt 0; numerisches 0 wird 0, jeder numerische Nichtnullwert wird zu 1. NULL aktiviert JSON nicht. Bei 1 wird das JSON-Objekt mit meta, forcedPlans und warnings erzeugt; dies ist unabhängig von @ResultSetArt.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

**@Hilfe:** @Hilfe bit; Default: 0. ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| forcedPlans | 1 | 1 | [QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[QueryId] bigint,[PlanId] bigint,[QueryHash] binary(8),[QueryPlanHash] binary(8),[ObjectId] bigint NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsForcedPlan] bit,[PlanForcingTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[ForceFailureCount] bigint,[LastForceFailureReason] int,[LastForceFailureReasonDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[CountCompiles] bigint,[LastCompileStartTimeUtc] datetimeoffset,[LastExecutionTimeUtc] datetimeoffset,[EngineVersion] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS,[CompatibilityLevel] smallint,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryPlanTextFallback] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NULL,[QueryPlanStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QueryPlanCharacters] bigint NULL,[QueryPlanBytes] bigint NULL,[QueryPlan] xml NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_QueryStoreForcedPlans] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_QueryStoreForcedPlans

monitor.USP_QueryStoreForcedPlans inventarisiert aktuell erzwungene Query-Store-Pläne, Force-Fehler und zugehörige Metadaten in ausgewählten Quelldatenbanken. Der persistierte Status belegt weder eine künftige erfolgreiche Bindung noch die betriebliche Eignung eines Plans.

Datenbankauswahl: @QueryStoreDatabaseNames ist eine bracket-aware Pipe-Liste; NULL, leer oder nur Leerzeichen wählt alle sichtbaren Online-Benutzerdatenbanken. Alternativ dient @QueryStoreDatabaseNamePattern mit SQL-LIKE (ohne Präfix oder like:), regex: oder regexi:. Liste und Pattern sind exklusiv; Systemdatenbanken bleiben ausgeschlossen. Regex für die Quellauswahl benötigt SQL Server 2025 und Compatibility Level 170 in der Installationsdatenbank.

Referenzfilter: @ReferencedDatabaseNames prüft Plan-XML-Objektreferenzen mit einer bracket-aware Pipe-Liste; NULL lässt den Filter weg, leer ist ungültig. Alternativ dient @ReferencedDatabaseNamePattern mit LIKE, regex: oder regexi:. Regex benötigt SQL Server 2025 und Compatibility Level 170 je geprüfter Quelldatenbank. Referenzfilter und Plan-XML aktivieren QUERY_STORE_DEEP.

Die beschriebenen fachlichen Validierungen gelten im normalen Analysepfad. @Hilfe=1 kehrt vorher zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt bei jedem Parameter der ausdrücklich angegebene Default.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_QueryStoreForcedPlans
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Liefert erzwungene Query-Store-Pläne aus mehreren
               Quelldatenbanken mit globaler Top-N-Ausgabe und optionalem
               Referenzdatenbankfilter.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_QueryStoreForcedPlans
monitor.USP_QueryStoreForcedPlans inventarisiert aktuell erzwungene Query-Store-Pläne, Force-Fehler und zugehörige Metadaten in ausgewählten Quelldatenbanken. Der persistierte Status belegt weder eine künftige erfolgreiche Bindung noch die betriebliche Eignung eines Plans.
Datenbankauswahl: @QueryStoreDatabaseNames ist eine bracket-aware Pipe-Liste; NULL, leer oder nur Leerzeichen wählt alle sichtbaren Online-Benutzerdatenbanken. Alternativ dient @QueryStoreDatabaseNamePattern mit SQL-LIKE (ohne Präfix oder like:), regex: oder regexi:. Liste und Pattern sind exklusiv; Systemdatenbanken bleiben ausgeschlossen. Regex für die Quellauswahl benötigt SQL Server 2025 und Compatibility Level 170 in der Installationsdatenbank.
Referenzfilter: @ReferencedDatabaseNames prüft Plan-XML-Objektreferenzen mit einer bracket-aware Pipe-Liste; NULL lässt den Filter weg, leer ist ungültig. Alternativ dient @ReferencedDatabaseNamePattern mit LIKE, regex: oder regexi:. Regex benötigt SQL Server 2025 und Compatibility Level 170 je geprüfter Quelldatenbank. Referenzfilter und Plan-XML aktivieren QUERY_STORE_DEEP.
Die beschriebenen fachlichen Validierungen gelten im normalen Analysepfad. @Hilfe=1 kehrt vorher zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt bei jedem Parameter der ausdrücklich angegebene Default.
DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
CREATE TABLE [#QueryStoreForcedPlans_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"forcedPlans":"#QueryStoreForcedPlans_HelpExample"}';
 SELECT * FROM [#QueryStoreForcedPlans_HelpExample];
 DROP TABLE IF EXISTS [#QueryStoreForcedPlans_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreForcedPlans_HelpExample];
 THROW;
END CATCH;
```


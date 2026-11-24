---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentCallerPermissionAnalysis"
schema_name: "monitor"
object_name: "USP_CurrentCallerPermissionAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure zeigt native SERVER- und DATABASE-Rechte des aktuellen Ausfuehrungskontexts mit getrennten Quellen und Kontext-IDs."
source_path: "Code/08_ServerHealth/280_USP_CurrentCallerPermissionAnalysis.sql"
---

# monitor.USP_CurrentCallerPermissionAnalysis

## Zweck und Einsatz

Die Procedure zeigt native SERVER- und DATABASE-Rechte des aktuellen Ausfuehrungskontexts mit getrennten Quellen und Kontext-IDs.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_CurrentCallerPermissionAnalysis]. Die Quelle nennt insbesondere `sys.fn_my_permissions`, `[monitor].[InternalPrepareResultTables]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[sys].[databases]`, `[sys].[fn_my_permissions]`, `[sys].[sp_executesql]`, `[master].[sys].[databases]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @ServerrechteEinbeziehen | bit | nein | 1 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Nicht angegeben oder NULL, N'' und ausschließlich äußere U+0020-Leerzeichen bedeuten keine Einschränkung; interne Leerzeichen bleiben Bestandteil der Eingabe. Andernfalls eine bracket-aware Pipe-Liste einteiliger Datenbanknamen: | trennt außerhalb von [...], innerhalb ist es Inhalt, ]] maskiert dort ]. Der Parser trimmt Segmentränder, prüft rohe Segmente bis 4000 Zeichen; danach verlangt die Namensprüfung PARSENAME-Teil 1 ≠ NULL, Teil 2 = NULL und LEN(Teil 1) ≤ 128. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Exakte Namen werden case-sensitive verglichen. Mit aktivem nichtleerem Listenfilter muss @DatabaseNamePattern NULL sein; case-sensitive doppelte Listennamen werden als INVALID_PARAMETER zurückgewiesen. Ungültige Listenelemente werden als INVALID_PARAMETER zurückgewiesen. Syntaktisch gültige, aber nicht verfügbare explizite Namen erscheinen als Auswahlwarnungen; sie beweisen nicht, dass eine Datenbank fehlt. Ohne Filter gilt die Kandidatenauswahl nach sichtbaren, ONLINE- und zugänglichen Nicht-Snapshot-Datenbanken.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. 0 lässt Datenbank-IDs bis 4 aus; 1 erlaubt Systemdatenbanken. NULL wird vor dem regulären Auswahlpfad als INVALID_PARAMETER abgewiesen. Auch mit 1 bleiben Sichtbarkeit, ONLINE-Zustand und HAS_DBACCESS=1 Voraussetzungen; die Auswahl ist kein vollständiger Datenbankkatalog. SQL bindet numerische 0 als 0 und sonstige konvertierbare Nichtnullwerte als 1.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. NULL bedeutet kein Pattern. Sonst trimmt der Parser äußere Leerzeichen und erkennt case-insensitive die Präfixe LIKE:, REGEX: und REGEXI:; ohne Präfix gilt LIKE. Nach dem Präfix wird nicht erneut getrimmt. Leerer Inhalt oder nur U+0020-Leerzeichen einschließlich leerem Präfixinhalt ist ungültig. Aktive nichtleere @DatabaseNames und ein nicht-NULL-Pattern sind unvereinbar. LIKE wird case-sensitive mit SQL-LIKE-Syntax (% beliebige Folge, _ ein Zeichen, [...] Zeichenklasse; keine eigene ESCAPE-Klausel) ausgewertet. REGEX übergibt das Muster an REGEXP_LIKE mit Flag c, REGEXI mit Flag i; beides verlangt SQL Server 2025 und Compatibility Level 170 in der Installationsdatenbank. Parservalidierung prüft weder Regexsyntax noch Treffer; Ausführungsfehler werden in der jeweiligen Quell-/Auswahlbehandlung sichtbar.

**@ServerrechteEinbeziehen:** @ServerrechteEinbeziehen bit; Default: 1. 1 ruft sys.fn_my_permissions(NULL,N'SERVER') im tatsächlich aktiven Kontext auf; 0 überspringt nur diese Quelle und trägt für SERVER_CURRENT_PERMISSIONS den Quellstatus SKIPPED ein. NULL wird in der Parameterprüfung als INVALID_PARAMETER zurückgewiesen. Das Abschalten der Serverquelle verhindert nicht die getrennten Datenbankquellen und macht die Gesamtausgabe nicht automatisch zu einer Fehlerausgabe. SQL bindet numerische 0 als 0 und sonstige konvertierbare Nichtnullwerte als 1.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. NULL oder 0 bedeutet unbegrenzt; negative Werte sind INVALID_PARAMETER. Ein positiver Wert begrenzt die Serverrechtemenge global und separat jede Datenbankrechtemenge global über alle gewählten Datenbanken. Gekürzt wird nach EntityName, SubentityName, PermissionName (Datenbankmenge zusätzlich zuerst DatabaseId); für identische Sortierschlüssel ist keine weitere Tie-Break-Reihenfolge zugesichert. Die native Quelle wird zuvor vollständig aufgenommen; das Limit reduziert weder Zielauswahl noch Funktionsaufrufe. ObservedRows bleibt die aufgenommene Menge, ReturnedRows zeigt die Ausgabe, IsLimited markiert eine Kürzung. Kontext-, Status- und Warnungszeilen werden nicht gekappt.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Gültig sind 0 bis 60000 Millisekunden einschließlich beider Grenzen; NULL, negative Werte und größere Werte werden als INVALID_PARAMETER abgewiesen. Der Wert wird für die dynamischen fachlichen Quellenbatches als LOCK_TIMEOUT verwendet; 0 bedeutet NOWAIT. Eigene vorbereitende Temp-DDL erhält bei eingehendem Caller-LOCK_TIMEOUT 0 separat bis zu 1000 ms pro Statement. Die Procedure stellt den eingehenden LOCK_TIMEOUT am regulären Ende und im äußeren CATCH wieder her. Dies ist keine Gesamtzeitgrenze und kein atomarer Snapshot.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. NULL und leer normalisieren zu leer und sind ungültig. Nach LTRIM/RTRIM äußerer U+0020-Leerzeichen und UPPER sind ausschließlich CONSOLE (ein fachliches, beschriftetes Ergebnis über Console-Helper), RAW (sechs getrennte Resultsets), TABLE (angeforderte benannte Mengen in lokale Temp-Ziele), NONE (keine fachlichen Resultsets) zulässig. Bei CONSOLE wird keine eigene Modulstatusmenge ergänzt; leere Console-Ansicht erhält die Helper-Zeile. JSON ist davon unabhängig. Außerhalb TABLE muss @ResultTablesJson NULL, leer oder nur U+0020-Leerzeichen sein; sonst INVALID_PARAMETER.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Außerhalb TABLE sind NULL, leer oder nur U+0020-Leerzeichen zulässig; anderer Inhalt wird als INVALID_PARAMETER mit Fehler 51011 abgelehnt. In TABLE muss die gemeinsame Vorprüfung ein JSON-Objekt mit mindestens einer Zuordnung aus den exakten Schlüsseln moduleStatus, callerContexts, serverPermissions, databasePermissions, sourceStatus und warnings erhalten. Schlüssel dürfen nicht doppelt vorkommen; Zielnamen dürfen nicht mehrfach vorkommen (case-insensitive). Werte müssen eindeutige, vorhandene, leere lokale #Temp-Tabellen mit genau einer Seed-Spalte und höchstens 116 Zeichen bezeichnen. ##-Ziele und reservierte #Monitor*-Ziele sind unzulässig. Die Vorprüfung erfolgt vor Quellzugriff; der Helper wird mit ThrowOnError=0 aufgerufen. Bei abgelehntem Ziel löst die Procedure selbst ihren äußeren CATCH aus; dieser setzt ERROR_HANDLED, Partialität und Diagnose-OUTPUTs und liefert für die TABLE-Vorprüfung RETURN 51011. Jede Zuordnung schreibt nur die entsprechende Menge; nicht angeforderte Mengen werden nicht geschrieben. Die Schlüssel bedeuten: moduleStatus Modulstatus, callerContexts aktive Ausführungskontexte, serverPermissions native SERVER-Rechte, databasePermissions native DATABASE-Rechte, sourceStatus Quellenstatus und warnings Warnungen.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erzeugt zusätzlich das JSON-Dokument in @Json, unabhängig von der ResultSetArt; 0 oder NULL erzeugt keines (NULL aktiviert die IF-Bedingung nicht). Bei erfolgreichem regulärem Pfad enthält es meta mit resultName, schemaVersion=1, generatedAtUtc, statusCode, isPartial=1, errorNumber und errorMessage sowie die sechs Arrays moduleStatus, callerContexts, serverPermissions, databasePermissions, sourceStatus und warnings; NULL-Felder bleiben enthalten. Ein äußerer Fehler lässt @Json NULL. Die Dokumenterzeugung vereinigt die getrennten zeitlichen Quellen nicht zu einem Snapshot. Numerische 0 wird beim Binden zu 0, jeder nach bit konvertierbare von 0 verschiedene numerische Wert zu 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger des JSON-Dokuments: zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; Argument kann ausgelassen werden. Die Procedure setzt @Json beim Eintritt auf NULL, setzt es nur bei aktiviertem @JsonErzeugen im regulären Pfad und lässt es bei Hilfe, Validierungsfehler und gefangenem äußerem Fehler NULL. Optionaler Empfänger: Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden, andernfalls das Argument auslassen.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 1 erlaubt die vorgesehenen Meldungen niedriger Severity: bei @Hilfe werden die Hilfetexte unabhängig von diesem Schalter ausgegeben; bei ungültigen Parametern, Quellenfehlern mit ermitteltem Fehler und äußerem Fehler kann RAISERROR Severity 10 mit NOWAIT folgen. 0 unterdrückt diese Diagnosemeldungen, nicht Resultsets oder OUTPUTs. NULL löst die IF-Bedingung für 1 nicht aus. Numerische 0 wird beim Binden zu 0, jeder nach bit konvertierbare von 0 verschiedene numerische Wert zu 1.

**@Hilfe:** @Hilfe bit; Default: 0. 1 druckt die eingebaute Parameterhilfe und Beispiele und setzt @StatusCodeOut=AVAILABLE sowie @IsPartialOut=0; anschließend RETURN 0, ohne reguläre Eingabeprüfung, Kandidatenauswahl oder Quellenlesung. Die beim Eintritt bereits auf NULL gesetzten @Json- und Fehler-OUTPUTs bleiben NULL. Vor diesem Zweig läuft keine TABLE-Vorprüfung: diese erfolgt erst nach Hilfe, während ungültige Nicht-TABLE-Mappings ebenfalls erst danach geprüft werden. 0 oder NULL führt zum normalen Pfad. Numerische 0 wird beim Binden zu 0, jeder nach bit konvertierbare von 0 verschiedene numerische Wert zu 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger varchar(40); binde eine Variable mit OUTPUT. Alle Statuswerte und ihre Priorität: Hilfe setzt AVAILABLE (vor Quellenprüfung). Parameterprüfung setzt INVALID_PARAMETER und RETURN 51011. Fehler der Kandidatenvorbereitung werden als deren Status weitergegeben: INVALID_PARAMETER (ungültige Auswahl), INTERNAL_ERROR (interner Schemafehler), UNAVAILABLE_FEATURE (Regexvoraussetzung fehlt) oder STATUS_UNAVAILABLE als Fallback; äußerer CATCH setzt dazu den passenden Fehlercode. Im regulären Bericht gilt AVAILABLE_LIMITED, sobald mindestens eine native SERVER-/DATABASE-Rechtemenge nichtleer erfolgreich aufgenommen wurde. Andernfalls hat EMPTY_UNPROVEN Vorrang, sobald mindestens eine erfolgreiche native Menge leer ist. Wenn keine erfolgreiche leere Menge existiert, wird der nach DatabaseId und SourceKey erste native Fehlerstatus gewählt: DENIED_PERMISSION (Enginefehler 229, 297, 300, 371 oder 916), TIMEOUT (1222), DATABASE_UNAVAILABLE (konkret erkannte Kontext-/DB-Fehler) oder ERROR_HANDLED (sonstiger abgefangener Quellenfehler). Gibt es auch keinen solchen Fehler, gilt NO_TARGETS (z.B. keine Ziele oder nur übersprungene Quellen). Kandidatenfehler geben den gesetzten Helferstatus weiter. TABLE-Vorprüfungs- oder Schreibfehler setzen dagegen keinen FailureStatus und ergeben im äußeren CATCH ERROR_HANDLED mit vorbereitetem Diagnosecode; Schreibfehler verwenden den Helpercode oder 51010. Andere äußere Fehler ergeben ebenfalls ERROR_HANDLED, sofern kein Kandidaten-FailureStatus gesetzt wurde. Reguläre Fachquellenfehler ändern RETURN 0 nicht; Status, Fehler-OUTPUTs und sourceStatus getrennt prüfen. Beim Eintritt wird ein vorhandener Empfänger zurückgesetzt; Hilfe überschreibt Status/Partial, lässt die übrigen Fehler-OUTPUTs NULL. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger bit; eine Variable mit OUTPUT binden. Bei Eintritt NULL, bei Hilfe 0, bei ungültiger Eingabe, regulärem Bericht und äußerem Fehler 1. Auch AVAILABLE_LIMITED ist immer partiell: leere Quellen beweisen keine Abwesenheit, Sichtbarkeit ist begrenzt, und getrennte Aufnahmen sind nicht atomar. RETURN 0 kann trotz Quellenfehler auftreten. Beim Eintritt wird ein anfänglicher Empfängerwert zurückgesetzt. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionaler int-OUTPUT-Empfänger. Beim Eintritt NULL. Bei Parameterablehnung 51011; im regulären Bericht Nummer der fehlerhaften Quelle mit der ersten Sortierung nach DatabaseId und SourceKey, sonst NULL. Beim äußeren CATCH Fehlercode des vorbereiteten Fehlerpfads, andernfalls ERROR_NUMBER(); erfolgreicher Hilfspfad lässt NULL. Eine reguläre Quellenstörung ändert RETURN 0 nicht. Zum Empfangen Variable mit OUTPUT binden. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler nvarchar(2048)-OUTPUT-Empfänger. Beim Eintritt NULL. Bei Parameterablehnung feste Diagnose; im regulären Bericht Meldung der ersten fehlerhaften Quelle nach DatabaseId und SourceKey, sonst NULL. Beim äußeren CATCH abgefangene Meldung; Quellen-/Enginefehler bleiben diagnostisch erhalten. Eine reguläre Quellenstörung ändert RETURN 0 nicht. Zum Empfangen Variable mit OUTPUT binden. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| callerContexts | 1 | 1 | [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ContextDatabaseId] int NOT NULL, [ServerPrincipalId] int NULL, [DatabasePrincipalId] int NULL, [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL |
| serverPermissions | 1 | 1 | [EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| databasePermissions | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| sourceStatus | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| warnings | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Bericht beweist keinen konkreten Objekt- oder Statementzugriff.

Der Bericht liest nur und wechselt keine Identitaet.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CurrentCallerPermissionAnalysis
Version      : 1.0.0
Stand        : 2026-10-25
Zweck        : Die Procedure zeigt native SERVER- und DATABASE-Rechte des aktuellen
               Ausfuehrungskontexts mit getrennten Quellen und Kontext-IDs.
Grenzen      : Der Bericht beweist keinen konkreten Objekt- oder Statementzugriff.
Nebenwirkung : Der Bericht liest nur und wechselt keine Identitaet.
Datenschutz  : Der Bericht erfragt keine SID- oder Tokenquellen. Native Namen
               und diagnostische Fehlermeldungen bleiben erhalten.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CurrentCallerPermissionAnalysis
Liest native SERVER- und DATABASE-Rechte des tatsächlich aktiven Ausführungskontexts über sys.fn_my_permissions und zeigt getrennte Quellenzustände sowie numerische Kontext-IDs. Die Procedure wechselt keine Identität und prüft keinen konkreten Objektzugriff.
Ohne wirksame Auswahlfilter werden sichtbare, ONLINE befindliche und für den Aufrufer zugängliche Benutzerdatenbanken untersucht; Systemdatenbanken bleiben standardmäßig ausgeschlossen. Die Serverrechtequelle ist separat abschaltbar.
RAW liefert sechs benannte Mengen; JSON enthält dieselben sechs Arrays und meta. TABLE schreibt ausschließlich die per Mapping angeforderte Teilmenge. CONSOLE rendert eine beschriftete fachliche Sicht, NONE unterdrückt Resultsets. Prüfen Sie Status und Fehler-OUTPUTs auch bei RETURN 0.
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
EXEC @ReturnCode=[monitor].[USP_CurrentCallerPermissionAnalysis]
      @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT
    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];
CREATE TABLE [#CurrentCallerPermissionAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N'{"databasePermissions":"#CurrentCallerPermissionAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
    SELECT * FROM [#CurrentCallerPermissionAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#CurrentCallerPermissionAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#CurrentCallerPermissionAnalysis_HelpExample];
    THROW;
END CATCH;
```


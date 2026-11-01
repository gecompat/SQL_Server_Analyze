# [monitor].[USP_DatabaseMirroringInventory]

## Zweck

Das Verfahren liefert caller-sichtbare SQL-Server-Katalogwerte zu Database Mirroring für ausgewählte Datenbanken. Es liest master.sys.databases und master.sys.database_mirroring mit NOLOCK. Das Ergebnis ist immer als begrenzte Metadatensicht markiert.

Database Mirroring ist veraltet und für eine künftige SQL-Server-Version zur Entfernung vorgesehen. Diese Analyse plant oder führt keine Migration aus. Auf SQL Server unter Linux ist Database Mirroring nicht verfügbar. Ein leeres Linux-Ergebnis ist keine positive Funktionsqualifikation.

## Auswahl und Aussagegrenzen

Ohne Filter wählt das gemeinsame Framework alle sichtbaren, ONLINE befindlichen Benutzerdatenbanken. Systemdatenbanken sind mit @SystemdatenbankenEinbeziehen=1 opt-in. @DatabaseNames und @DatabaseNamePattern verwenden die vorhandenen, voneinander getrennten Filterverträge. Nicht ONLINE befindliche Datenbanken wie eine RESTORING-Mirror-Datenbank liegen außerhalb der Auswahl. V1 belegt daher keine positive Mirror-Rollenbeobachtung auf dieser Partnerseite.

Das Verfahren liefert eine Zeile je ausgewählter Datenbank. Die native Quelle enthält auch für nicht gespiegelte Datenbanken eine Zeile; ihre mirroring_-Spalten sind dort NULL. NULL-Werte werden unverändert ausgegeben und unterscheiden keine Ursache. Metadaten sind auf für den Caller sichtbare Datenbanken beschränkt. Ein leerer Filtertreffer beweist keine instanzweite Abwesenheit.

[Microsofts sys.database_mirroring-Dokumentation](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-mirroring-transact-sql?view=sql-server-ver17) beschreibt die native Zeilen-, NULL-, Sichtbarkeits- und Versionsberechtigungssemantik. Für Datenbanken außer master und tempdb muss der Caller Datenbankbesitzer sein oder ALTER ANY DATABASE, VIEW ANY DATABASE oder CREATE DATABASE in master besitzen. Ab SQL Server 2022 ist VIEW SERVER PERFORMANCE STATE erforderlich; die Quelle spezifiziert keine weitere Serverberechtigung für SQL Server 2019. Nicht-NULL-Werte auf einer Mirror-Datenbank erfordern sysadmin. Das Framework vergibt keine Berechtigungen.

## Ausgabe

Der öffentliche Vertrag enthält genau vier Resultsets:

| Resultset | Inhalt |
|---|---|
| moduleStatus | Modulergebnis, Zeilenzahl und Begrenzungshinweis |
| databaseMirroring | Die zwölf nativen Katalogwerte |
| sourceStatus | Datenbankauswahl und Status der nativen Katalogquelle |
| warnings | Metadatensicht, NULL-Interpretation, Limit und ONLINE-Auswahlgrenze |

Die Fachmenge databaseMirroring verwendet diese stabile Feldfolge und nativen Typen:

| Feld | Typ | Bedeutung |
|---|---|---|
| DatabaseId | int NOT NULL | Datenbank-ID und Join-Schlüssel |
| DatabaseName | sysname NOT NULL | Caller-sichtbarer Datenbankname |
| MirroringState | tinyint NULL | Nativer Sitzungszustand |
| MirroringStateDesc | nvarchar(60) NULL | Native Zustandsbeschreibung |
| MirroringRole | tinyint NULL | Nativer lokaler Rollenwert |
| MirroringRoleDesc | nvarchar(60) NULL | Native Rollenbeschreibung |
| MirroringSafetyLevel | tinyint NULL | Nativer Safety-Wert |
| MirroringSafetyLevelDesc | nvarchar(60) NULL | Native Safety-Beschreibung |
| MirroringWitnessState | tinyint NULL | Nativer Witness-Zustand |
| MirroringWitnessStateDesc | nvarchar(60) NULL | Native Witness-Beschreibung |
| ConfiguredRedoQueueLimitMb | int NULL | Konfiguriertes Redo-Limit, keine beobachtete Queue |
| RedoQueueLimitType | nvarchar(60) NULL | Nativer Typ des Redo-Limits |

Partner- und Witness-Namen, GUIDs und LSNs werden nicht ausgegeben. Zustands- und Rollenwerte sind keine Gesundheits- oder Failoverbewertung. Das konfigurierte Redo-Limit ist keine aktuelle Queue-Messung. Es gibt keine externe Verbindung, Probeoperation, Schreibaktion oder Statusinferenz.

RAW liefert die vier Resultsets in Vertragsreihenfolge. TABLE verwendet ResultTablesJson für dieselben physischen Schemas. CONSOLE stellt eine formatierte Einzelansicht bereit. NONE unterdrückt Resultsets. JsonErzeugen=1 liefert unabhängig von der Ausgabeart über Json die bestehende Metahülle mit schemaVersion=1 und databaseMirroring als Array. Der JSON-Schalter erzeugt keinen zusätzlichen Resultsetnamen.

Ein erfolgreicher normaler Lauf meldet AVAILABLE_LIMITED und IsPartial=1,
auch bei leerer Katalogmenge. Auswahl- und Quellenfehler bleiben über Status,
Fehler-OUTPUTs und sourceStatus sichtbar. Ohne früher gesetzten Fehler wird
die erste Fehlerzeile nach SourceKey, DatabaseId und DatabaseName übernommen;
auch DATABASE_UNAVAILABLE oder SYSTEM_DATABASE_EXCLUDED aus Auswahlwarnungen
können so den globalen Status mit Fehlernummer 51011 setzen. Diese inneren
Fehlerpfade liefern weiterhin einen Bericht, optional JSON und RETURN 0.
Direkte Validierungsfehler liefern INVALID_PARAMETER und RETURN 51011.
Jeder äußere CATCH, auch nach TABLE-Vorprüfung oder -Schreiben, liefert
ERROR_HANDLED und JSON-NULL; ErrorNumberOut und RETURN bevorzugen den
gespeicherten TABLE-Fehlercode (Vorprüfung 51011, Writercode oder 51010),
sonst die native Fehlernummer.

## Parameter und Aufruf

MaxZeilen begrenzt die Fachmenge nach DatabaseId; NULL oder 0 bedeutet unbegrenzt, ein negativer Wert ist ungültig. Das Limit begrenzt die Ausgabe, nicht garantiert die vorgelagerte Kataloglesearbeit. Alle Parameter, Defaults und Ausgabeoptionen stehen in Hilfe.

    EXEC [monitor].[USP_DatabaseMirroringInventory] @ResultSetArt='CONSOLE';

    EXEC [monitor].[USP_DatabaseMirroringInventory]
        @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW', @JsonErzeugen=1;

Das Verfahren setzt keine Caller-Transaktion voraus und beginnt, bestätigt oder verwirft keine Transaktion. Es ändert weder Isolationsstufe noch Caller-LOCK_TIMEOUT; die Quellphase verwendet SET LOCK_TIMEOUT 0 und stellt den ursprünglichen Wert wieder her. NOLOCK kann inkonsistente, fehlende oder doppelte Zeilen liefern. Es verhindert keine Sch-S-Sperren und garantiert keine Nichtblockierung.

### Individuelle Parameterverträge

Die folgenden Einträge erklären jeden Parameter mit Datentyp, Eingabeform und ausdrücklich bezeichnetem Default. OUTPUT-Werte werden nur bei passender, mit OUTPUT gebundener Variable empfangen.

| Parameter und Typ | Default | Eingabeform, Wirkung und Grenzen |
|---|---|---|
| `@DatabaseNames nvarchar(max)` | `NULL` | Die Liste schränkt die Auswahl auf angeforderte, gültige einteilige Datenbanknamen ein; NULL, eine exakt leere Eingabe oder ausschließlich äußere U+0020-Leerzeichen werden vom Auswahlhelfer zu keiner Einschränkung normalisiert. Eine aktive Liste muss bracket-aware mit \| getrennt sein: \| innerhalb [..] gehört zum Namen, ]] maskiert dort eine schließende Klammer. Segmente werden außen getrimmt; doppelte Namen und ungültige Elemente machen die Auswahl ungültig. Die Prüfung nutzt TVF_ParseSqlNameList/PARSENAME: Teil 1 muss vorhanden, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein; das ist keine vollständige SQL-Namens-, Existenz- oder Berechtigungsprüfung. Aktive Liste und nicht-NULL @DatabaseNamePattern sind unzulässig zusammen. Auswahl umfasst nur sichtbare, ONLINE befindliche, zugreifbare, nicht als Snapshot markierte Datenbanken. Jedes rohe Listensegment darf höchstens 4000 UTF-16-Codeeinheiten enthalten; längere Segmente sind INVALID_PARAMETER. Diese Grenze gilt je Segment, nicht für die Gesamtlänge der nvarchar(max)-Liste. Doppelte Namen werden case-sensitiv geprüft. |
| `@SystemdatenbankenEinbeziehen bit` | `0` | Steuert den Datenbank-ID-Filter: 0 schließt Systemdatenbanken mit IDs bis 4 aus, 1 nimmt sie in die Kandidatenmenge auf; andere numerische Bit-Eingaben werden durch den Bit-Parametertyp als 0 oder 1 abgebildet. NULL ist ausdrücklich ungültig und liefert INVALID_PARAMETER vor Quellenlesung. Der Schalter garantiert weder Sichtbarkeit noch Online-Status oder HAS_DBACCESS. Bei der bit-Konvertierung wird die numerische 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. |
| `@DatabaseNamePattern nvarchar(4000)` | `NULL` | NULL bedeutet kein Pattern. Optionaler zusätzlicher Namensfilter; nicht-NULL ist mit einer aktiven exakten @DatabaseNames-Liste unzulässig. Der Parser trimmt zuerst äußere Leerzeichen, entfernt danach ohne Beachtung der Groß-/Kleinschreibung höchstens das Präfix regexi:, regex: oder like:; der Rest wird nicht erneut getrimmt. Ohne Präfix gilt LIKE. LIKE verwendet SQL-LIKE-Syntax und wird case-sensitive ausgewertet. regex: führt case-sensitives Regex mit Flag c, regexi: case-insensitives Regex mit Flag i aus; Regex-Syntax wird vom Parser nicht validiert. Ein leerer Eingang oder leeres Präfix-Ergebnis ist ungültig. Regex setzt SQL Server 2025 (Major Version mindestens 17) und Compatibility Level 170 der Installationsdatenbank voraus; bei Nichterfüllung löscht der Helper Kandidaten und gibt UNAVAILABLE_FEATURE zurück. Der gemeinsame Kandidatenhelfer führt den Regexabgleich dynamisch aus; Fehler dabei werden vom Auswahl-CATCH als DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED eingeordnet. SQL-LIKE unterstützt Prozentzeichen für beliebig viele Zeichen, Unterstrich für ein Zeichen und Zeichenklassen in [...]; der Aufruf definiert keine eigene ESCAPE-Klausel. |
| `@MaxZeilen int` | `1000` | Globales Ausgabelimit für databaseMirroring nach der vollständigen Kandidaten- und Katalogermittlung, sortiert nach DatabaseId; es begrenzt weder Kandidatenermittlung noch vorgelagerte Kataloglesearbeit. NULL oder 0 setzt das Limit auf bigint-Maximum und wirkt damit unbegrenzt; negative Werte sind INVALID_PARAMETER. sourceStatus unterscheidet beobachtete Auswahl-/Quellzeilen und tatsächlich ausgegebene Mirroringzeilen; OUTPUT_LIMIT wird nur bei tatsächlich abgeschnittenen Fachzeilen angelegt. |
| `@ResultSetArt varchar(16)` | `'CONSOLE'` | Wählt die Resultset-Ausgabe. Nach LTRIM/RTRIM und UPPER sind genau CONSOLE, RAW, TABLE und NONE zulässig; NULL oder Leertext wird zu leer und ist INVALID_PARAMETER. CONSOLE erzeugt eine formatierte Einzelansicht über InternalEmitConsoleResult. RAW liefert die vier Resultsets moduleStatus, databaseMirroring, sourceStatus und warnings in dieser Reihenfolge. TABLE schreibt die angeforderten benannten Resultsets in Caller-Temp-Tabellen; die Zuordnung ist Pflicht. NONE unterdrückt Resultsets. Json-Erzeugen ist unabhängig von dieser Auswahl. |
| `@ResultTablesJson nvarchar(max)` | `NULL` | Wird nur mit ResultSetArt TABLE verarbeitet; außerhalb TABLE ist ein nicht-NULL, nach Trim nicht-leerer Wert INVALID_PARAMETER. In TABLE ist ein gültiges JSON-Objekt mit mindestens einem Schlüssel und Textwerten erforderlich. Erlaubte, exakt groß-/kleinschreibungssensitive Schlüssel sind moduleStatus, databaseMirroring, sourceStatus und warnings; jeder benennt eine jeweils unterschiedliche lokale #Temp-Zieltabelle. Doppelte Resultset-Schlüssel werden binär verglichen, Zielnamen dagegen case-insensitive; unbekannte Schlüssel, doppelte Ziele, Nicht-Textwerte und ungültige Ziele werden vor fachlichem Quellenzugriff abgelehnt. Zielname maximal 116 Zeichen, lokal mit #, nicht ## und nicht mit reserviertem #Monitor-Präfix. Jedes Ziel muss vorher vorhanden, leer und mit genau einer Seed-Spalte versehen sein. Die Vorprüfung validiert die Zuordnung und Seed-Ziele; der Writer passt die einzelne Dummy-Spalte an das Quellschema an; öffentlich sind gefüllte Ziele wegen der Vorprüfung unzulässig. Ein späterer Writer-Fehler kann nach früheren erfolgreichen Zielen auftreten; der Aufruf kann daher teilweise geschriebene Ziele hinterlassen. Die vier Schlüssel bedeuten einzeln: moduleStatus liefert Modulstatus, Partialität und Zeilenzahl; databaseMirroring caller-sichtbare Mirroring-Katalogwerte je ausgewählter Online-Datenbank; sourceStatus Auswahl- und Katalogquellenstatus mit beobachteten und ausgegebenen Zeilen sowie Fehlern; warnings Warnungen und Aussagegrenzen. NULL und leere Werte sind im TABLE-Modus ungültig; außerhalb TABLE sind NULL, Leerstring und reine U+0020-Leerzeichen erlaubt. |
| `@JsonErzeugen bit` | `0` | Schaltet die JSON-Ausgabe unabhängig von ResultSetArt ein: Wert 1 erzeugt die schemaVersion-1-Metahülle mit moduleStatus, databaseMirroring, sourceStatus und warnings; NULL oder 0 erzeugt kein JSON und @Json bleibt NULL. Numerische Bit-Eingaben werden vom Parametertyp auf 0/1 abgebildet. Der Schalter ist nicht als ungültig validiert. Bei der bit-Konvertierung wird die numerische 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. |
| `@Json nvarchar(max) OUTPUT` | `NULL` | OUTPUT nvarchar(max); der Aufrufer bindet eine nvarchar(max)-Variable mit OUTPUT. Die Variable wird beim Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 wird JSON auch dann erzeugt, wenn Auswahlstatus, Quellfehler oder Auswahlwarnungen als innerer Fehlerstatus erfasst wurden; diese Fälle laufen bis zur JSON-Erzeugung weiter und erscheinen in meta sowie den Arrays. Bei Hilfe, ohne JSON-Anforderung und bei jedem äußeren CATCH bleibt @Json NULL; ein äußerer Fehler nach der JSON-Erzeugung, etwa ein TABLE-Schreibfehler, setzt es erneut auf NULL. Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. |
| `@PrintMeldungen bit` | `1` | Steuert zusätzliche Meldungen mit niedriger Severity: 1 gibt sie an den Client aus, 0 unterdrückt sie; NULL verhält sich wegen der IF-Prüfungen wie unterdrückt. Numerische Bit-Eingaben werden als 0/1 übernommen. Die Auswahl-/Katalogstatus und OUTPUT-Fehlerdaten werden unabhängig davon gesetzt; dieser Schalter ändert keine Resultsets. Bei der bit-Konvertierung wird die numerische 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. |
| `@Hilfe bit` | `0` | Bei 1 gibt die Procedure die eingebaute Hilfe per PRINT aus, setzt StatusCodeOut auf AVAILABLE und IsPartialOut auf 0 und kehrt vor Auswahl, Temp-Tabellen und Katalogzugriff mit RETURN zurück. NULL oder 0 führen den normalen Ablauf aus. Die Hilfe-Ausgabe ist keine Quellen- oder Plattformqualifikation; numerische Bit-Eingaben werden vom Parametertyp auf 0/1 abgebildet. Bei der bit-Konvertierung wird die numerische 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. |
| `@StatusCodeOut varchar(40) OUTPUT` | `NULL` | Optionale OUTPUT-Bindung an eine varchar(40)-Variable; der Eingangswert wird auf NULL gesetzt. Sämtliche Statuswerte und Bedeutungen: AVAILABLE kennzeichnet die Hilfe ohne Quellenanalyse; AVAILABLE_LIMITED eine erfolgreiche, stets partielle normale Katalogsicht, auch ohne Fachzeilen; INVALID_PARAMETER ungültige direkte Eingaben oder einen ungültigen Auswahlvertrag; INTERNAL_ERROR einen internen Vorbereitungsfehler des Auswahlhelfers; UNAVAILABLE_FEATURE einen hier nicht verfügbaren Regexfilter; SELECTION_UNAVAILABLE den Fallback bei NULL als Auswahlstatus; DENIED_PERMISSION einen abgefangenen Berechtigungsfehler 229, 297, 300 oder 371; TIMEOUT einen Sperrtimeout 1222; ERROR_HANDLED einen sonstigen abgefangenen Auswahl-/Katalogfehler oder jeden äußeren Fehler; DATABASE_UNAVAILABLE einen explizit angeforderten fehlenden, nicht online befindlichen oder nicht zugreifbaren Namen; SYSTEM_DATABASE_EXCLUDED eine explizit angeforderte Systemdatenbank ohne Opt-in. Die normale Auswahl übernimmt einen nicht-AVAILABLE-Helferstatus oder den NULL-Fallback; Auswahl- und Katalog-CATCH setzen ihren Fehler sofort. Nur solange kein Fehler gesetzt ist, übernimmt die spätere Fehlerauswahl die erste sourceStatus-Zeile mit ErrorNumber nach SourceKey, DatabaseId und DatabaseName: DATABASE_MIRRORING_CATALOG vor DATABASE_SELECTION. Auswahlwarnungen tragen 51011 und können so den globalen Status setzen, obwohl der Katalog gelesen wurde. Ein äußerer CATCH, auch nach TABLE-Vorprüfung oder -Schreiben, überschreibt den Status mit ERROR_HANDLED. Hilfe und normale innere Fehlerpfade liefern RETURN 0; direkte Validierung RETURN 51011. Der äußere CATCH liefert den gespeicherten TABLE-Fehlercode (Vorprüfung 51011, Writercode oder 51010), sonst die native Fehlernummer. Ein Status beweist weder Gesundheit noch vollständige Sicht. Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. |
| `@IsPartialOut bit OUTPUT` | `NULL` | OUTPUT-Bit; wird beim Eintritt auf NULL zurückgesetzt. Hilfe setzt 0. Jeder normale Lauf sowie INVALID_PARAMETER und der äußere Fehler-CATCH setzen 1, auch wenn die Fachmenge leer ist. Numerische Bit-Ausgabe; kennzeichnet keine bestimmte Fehlerursache. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. |
| `@ErrorNumberOut int OUTPUT` | `NULL` | Optionales OUTPUT int; wird am Eintritt auf NULL gesetzt. Hilfe und fehlerfreier normaler Lauf lassen NULL. Direkte ungültige Eingaben liefern 51011. Ein nicht-AVAILABLE-Auswahlstatus liefert 51011 aus den Auswahlwarnungen oder als Fallback; Auswahl-/Katalog-CATCH liefert die SQL-Fehlernummer. Fehlende, ausgeschlossene oder nicht zugreifbare explizite Datenbanknamen werden als sourceStatus-Warnungen mit 51011 eingetragen und können bei der globalen Fehlerauswahl übernommen werden. Ohne vorher gesetzten Fehler werden Nummer und Meldung aus der ersten Zeile mit ErrorNumber nach SourceKey, DatabaseId und DatabaseName übernommen. Der äußere CATCH priorisiert TableFailureError: 51011 bei TABLE-Preflight, sonst Writer-Fehlernummer oder 51010; andernfalls native SQL-Fehlernummer. Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. |
| `@ErrorMessageOut nvarchar(2048) OUTPUT` | `NULL` | Optionales OUTPUT nvarchar(2048); wird beim Eintritt auf NULL gesetzt. Hilfe und fehlerfreier normaler Lauf lassen NULL. Direkte ungültige Eingaben liefern den Validierungstext. Bei Auswahlstatusfehlern kommt der Auswahlhelper-Text oder der Fallbacktext; Auswahl-/Katalog-CATCH liefert den abgefangenen SQL-Text, auf 2048 Zeichen begrenzt. Auswahlwarnungen für nicht verfügbare, ausgeschlossene oder nicht zugreifbare explizite Namen werden mit ihrer Warnmeldung in sourceStatus aufgenommen und können über die sortierte Fehlerauswahl ausgegeben werden. Bei mehreren Fehlern gehört die Meldung zur ersten sourceStatus-Zeile nach SourceKey, DatabaseId und DatabaseName. Im äußeren CATCH ist @ErrorMessageOut der abgefangene SQL-Fehlertext, links auf 2048 Zeichen begrenzt; bei TABLE-Fehlern stammt er aus dem ausgelösten Fehlertext, die TableFailureError-Priorität beeinflusst nur @ErrorNumberOut und den RETURN-Wert. Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. |

### Kopierbare Aufrufbeispiele

Die getrennten Beispiele zeigen RAW, typisierte Diagnose-OUTPUTs mit RETURN, einen TABLE-Teilexport und die Hilfe. Das TABLE-Ziel wird mit einer Seed-Spalte angelegt und in beiden Abschlusswegen entfernt.

```sql
EXEC [monitor].[USP_DatabaseMirroringInventory] @MaxZeilen=200, @ResultSetArt='RAW', @PrintMeldungen=0;
```

```sql
DECLARE @DiagnosticJson nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_DatabaseMirroringInventory] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@DiagnosticJson OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @DiagnosticJson AS [DiagnosticJson];
```

```sql
CREATE TABLE [#DatabaseMirroringInventory_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DatabaseMirroringInventory] @ResultSetArt='TABLE', @ResultTablesJson=N'{"databaseMirroring":"#DatabaseMirroringInventory_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#DatabaseMirroringInventory_HelpExample]; DROP TABLE IF EXISTS [#DatabaseMirroringInventory_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#DatabaseMirroringInventory_HelpExample]; THROW; END CATCH;
```

```sql
EXEC [monitor].[USP_DatabaseMirroringInventory] @Hilfe=1;
```

## Eine Zeile bedeutet

Eine Zeile in databaseMirroring gehört zu einer vom gemeinsamen Selektor gelieferten, caller-sichtbaren ONLINE-Datenbank. Sie verbindet die Datenbank-ID und den nativen Namen mit den Feldern aus sys.database_mirroring. Native NULLs bleiben unverändert. Ein fehlender Treffer belegt keine instanzweite Abwesenheit; das globale MaxZeilen-Limit wird erst nach vollständiger Kandidaten- und Quellermittlung angewendet.

## So lesen

Lies zuerst moduleStatus und sourceStatus. AVAILABLE_LIMITED und IsPartial=1 kennzeichnen die erfolgreiche, caller-sichtbare Teilansicht. Danach folgt databaseMirroring mit zwölf Feldern; warnings erläutert Metadatensicht, native NULLs, ONLINE-Auswahl und ein tatsächlich angewendetes Ausgabelimit.

RAW liefert die vier Resultsets moduleStatus, databaseMirroring, sourceStatus und warnings in dieser Reihenfolge. TABLE schreibt die per ResultTablesJson ausgewählten, erlaubten Resultsetnamen in die jeweils zugeordneten lokalen #Temp-Ziele; jeder Zielname ist eindeutig und jede ausgegebene Tabelle hat das Quellschema. CONSOLE rendert die materialisierte Übersicht. NONE unterdrückt Resultsets. JsonErzeugen=1 erzeugt unabhängig von der Ausgabeart die JSON-Metahülle mit schemaVersion=1 und allen vier Arrays. JSON ist kein fünftes Resultset.

## Warum kann das problematisch sein?

Native mirroring_-NULLs unterscheiden nicht zwischen nicht gespiegelt, nicht verfügbar und für den Caller nicht sichtbar. Eingeschränkte Metadatensicht kann Datenbanken verbergen. Quellenfehler bleiben Fehlerstatus und dürfen nicht als erfolgreich leere Menge interpretiert werden.

NOLOCK kann inkonsistente, fehlende oder doppelte Zeilen liefern und verhindert keine Sch-S-Sperren. MirroringState und MirroringRole sind lokale Katalogwerte und belegen weder Partnergesundheit noch Synchronität, Failoverfähigkeit, Commit oder Witness-Erreichbarkeit. ConfiguredRedoQueueLimitMb ist die konfigurierte Obergrenze, keine Messung der aktuellen Redo-Queue.

## Wann ist es kein Problem?

NULL-Mirroringfelder sind für eine nicht gespiegelte Datenbank ein erwarteter nativer Wert. Ein leeres Ergebnis kann korrekt sein, wenn keine Datenbank die explizite sichtbare ONLINE-Auswahl erfüllt. Lies beide Fälle zusammen mit sourceStatus und warnings; sie beweisen keine globale Abwesenheit.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche lokalen Mirroring-Katalogwerte gehören zu den sichtbaren ONLINE-Datenbanken, die der Aufrufer ausgewählt hat?

### Technischer Hintergrund

sys.database_mirroring liefert eine native Zeile je Datenbank. Für eine nicht gespiegelte Datenbank sind Felder mit Präfix mirroring_ NULL. Eine Mirror-Datenbank im Zustand RESTORING liegt außerhalb des gemeinsamen ONLINE-Selektors; dieses Verfahren behauptet deshalb keine positive Mirroring-Rolle auf dieser Partnerseite.

### Datenkette

TVF_DatabaseCandidates → USP_PrepareDatabaseCandidates → Kandidatentabelle → master.sys.databases → LEFT JOIN master.sys.database_mirroring auf database_id → globales Ausgabelimit → vier Resultsets beziehungsweise JSON.

### Source Select

Die Quellprojektion verbindet die zuvor vollständig erstellte Kandidatenmenge mit der lokalen Datenbankzeile und übernimmt native Mirroringwerte ohne Normalisierung:

```sql
SELECT [c].[DatabaseId],[c].[DatabaseName],
       [m].[mirroring_state],[m].[mirroring_state_desc],
       [m].[mirroring_role],[m].[mirroring_role_desc],
       [m].[mirroring_safety_level],[m].[mirroring_safety_level_desc],
       [m].[mirroring_witness_state],[m].[mirroring_witness_state_desc],
       [m].[mirroring_redo_queue],[m].[mirroring_redo_queue_type]
FROM [#DatabaseMirroringInventory_Candidates] AS [c]
INNER JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[database_id]=[c].[DatabaseId]
 AND [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
     =[c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
LEFT JOIN [master].[sys].[database_mirroring] AS [m] WITH (NOLOCK)
  ON [m].[database_id]=[d].[database_id];
```

**Wichtig für die Eigenlast:** MaxZeilen begrenzt die Ausgabe nach der Katalogabfrage. Das Limit begrenzt weder Kandidatenermittlung noch vorgelagerte Kataloglesearbeit.

### Zeit- und Scope-Modell

Kandidatenauswahl und native Mirroringabfrage werden getrennt zeitlich geklammert. Sie bilden keinen gemeinsamen Transaktionssnapshot. Die Quellphase verwendet NOLOCK und SET LOCK_TIMEOUT 0; anschließend werden Caller-Timeout und XACT_ABORT wiederhergestellt. Das Verfahren beginnt, bestätigt oder verwirft keine Caller-Transaktion und ändert deren Isolationsstufe nicht.

### Bewertung und Gegenprobe

Vergleiche die nativen Werte bei einer gezielten Prüfung anhand der Datenbank-ID mit der [Microsoft-Dokumentation zu sys.database_mirroring](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-mirroring-transact-sql?view=sql-server-ver17). Prüfe sourceStatus und warnings, bevor du aus leeren oder partiellen Zeilen Schlüsse ziehst.

### Typische Fehlinterpretation

NULL wird als Beweis für nicht konfiguriertes Mirroring gelesen; eine nicht sichtbare RESTORING-Partnerdatenbank wird als negativer Rollenbefund behandelt; die konfigurierte Redo-Obergrenze wird als aktuelle Queue-Messung bezeichnet; oder AVAILABLE_LIMITED wird als vollständige Serverinventur missverstanden.

### Folgeanalyse

Die [Infrastructure-Analyse](USP_InfrastructureAnalysis.md) ergänzt den übrigen sichtbaren HA/DR-Kontext. Eine Mirroring-Partnerschaft, Witness-Verfügbarkeit, Failover oder aktuelle Redo-Latenz benötigt eigene geeignete Laufzeitevidenz.

[Technische Detailbeschreibung](../../Reference/Procedure_Reference.md) · [Microsoft: sys.database_mirroring](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-mirroring-transact-sql?view=sql-server-ver17)

## Qualifikationsstatus

Das Runtimefixture lässt sich in den vorhandenen nativen Release-Gates für SQL Server 2019, 2022 und 2025 ausführen; Auswahl, native NULLs, Limits, Ausgabe-ABI, Callerzustand und Cleanup laufen dort versionsübergreifend. Der gezielte Quellberechtigungstest mit VIEW SERVER PERFORMANCE STATE gilt erst ab SQL Server 2022; für SQL Server 2019 wird keine nicht dokumentierte Mindestberechtigung behauptet und dieser Teilfall ausdrücklich übersprungen. Diese Ausführbarkeit ist kein Laufnachweis: Native SQL-Server-2019- und SQL-Server-2022-Qualifikation sowie eine Windows-Mirroring-Topologie bleiben offen. Das Fixture erzeugt keine Mirroring-Partnerschaft und behauptet keine positive Mirror-Rollenzeile.

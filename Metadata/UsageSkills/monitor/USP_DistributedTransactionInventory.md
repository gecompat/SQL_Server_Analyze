---
skill_format_version: "1.0.0"
name: "monitor.USP_DistributedTransactionInventory"
schema_name: "monitor"
object_name: "USP_DistributedTransactionInventory"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure inventarisiert caller-sichtbare lokale MSDTC-Konfiguration und aktive Transaktionsmetadaten mit transaction_type = 4."
source_path: "Code/08_ServerHealth/300_USP_DistributedTransactionInventory.sql"
---

# monitor.USP_DistributedTransactionInventory

## Zweck und Einsatz

Die Procedure inventarisiert caller-sichtbare lokale MSDTC-Konfiguration und aktive Transaktionsmetadaten mit transaction_type = 4.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_DistributedTransactionInventory]. Die Quelle nennt insbesondere `sys.configurations`, `sys.servers`, `[monitor].[InternalPrepareResultTables]`, `[sys].[configurations]`, `[sys].[sp_executesql]`, `[sys].[servers]`, `[sys].[dm_tran_active_transactions]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
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

**@MaxZeilen:** @MaxZeilen int; Default: 1000. Die Fachmengen linkedServerPromotion und activeDistributedTransactions werden jeweils mit TOP (@MaxZeilen + 1) materialisiert, wenn ein positiver Wert angegeben ist; die zusätzliche Zeile dient nur dazu, eine Überschreitung zu erkennen. Anschließend werden beide Ausgabemengen auf @MaxZeilen gekürzt. NULL oder 0 steht für unbegrenzt; negative Werte werden vor Quellenzugriff mit INVALID_PARAMETER und RETURN 51011 abgelehnt. Die Konfigurationsquelle enthält höchstens die einzelne passende sys.configurations-Zeile und wird nicht über dieses Limit gekappt. Das Limit begrenzt die ausgegebenen und für die zwei Mengen materialisierten Zeilen, nicht garantiert den Aufwand der Quellermittlung. RowsReturned enthält nach der Kappung die ausgegebene Zeilenzahl; LimitApplied ist nur 1, wenn die Probe mehr Zeilen als die Ausgabe enthielt. Ein leerer sichtbarer Bestand belegt keine instanzweite Abwesenheit. Bei ausgelassenem Argument gilt der angegebene Default.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Steuert das in jedem dynamischen Quellenbatch gesetzte LOCK_TIMEOUT in Millisekunden. Zulässig sind 0 bis 60000 einschließlich; NULL und Werte außerhalb des Bereichs werden vor Quellenzugriff mit INVALID_PARAMETER und RETURN 51011 abgelehnt. 0 bedeutet für die Quellenbatches NOWAIT. Der Wert ist kein globales Zeitbudget. Bei einem eingehenden Sitzungswert von 0 schützt die Procedure ihre eigene anfängliche Temp-Tabellenanlage bedingt mit 1000 ms; vor den fachlichen Quellen setzt sie LOCK_TIMEOUT 0, und erst der jeweilige dynamische Quellenbatch verwendet diesen Parameter. Die erfolgreiche Rückkehr stellt den zuvor gespeicherten Locktimeout wieder her; SET-Werte aus dynamischen Batches belegen keine weiterreichende Sessionwirkung. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Wählt genau einen Ausgabemodus. Erlaubt sind CONSOLE (eine kompakte beschriftete Zusammenfassung), RAW (sieben Resultsets in der Reihenfolge moduleStatus, serverContext, promotionConfiguration, linkedServerPromotion, activeDistributedTransactions, sourceStatus, warnings), TABLE (schreibt die zugeordneten Mengen in Aufrufer-Temp-Tabellen) und NONE (unterdrückt Resultsets). Die Eingabe wird mit LTRIM/RTRIM von Rand-Leerzeichen bereinigt und mit UPPER großgeschrieben; der Vergleich ist damit unabhängig von Groß-/Kleinschreibung. NULL und Leertext werden zu einem ungültigen leeren Modus; jeder andere Wert liefert INVALID_PARAMETER und RETURN 51011. Außerhalb von TABLE muss @ResultTablesJson NULL oder nach Rand-Leerzeichen leer sein. JSON-Erzeugung ist unabhängig vom Resultsetmodus. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE: ein nicht leeres JSON-Objekt, dessen Eigenschaftsnamen exakt und groß-/kleinschreibungsgenau zu den erlaubten Resultsetnamen moduleStatus, serverContext, promotionConfiguration, linkedServerPromotion, activeDistributedTransactions, sourceStatus oder warnings passen; ein Teil der sieben Zuordnungen genügt. Jeder Eigenschaftswert muss eine Zeichenfolge mit dem Namen eines Ziels sein. Die Schlüssel bezeichnen jeweils: Gesamtstatus/Partialität/ausgegebene Fachzeilensumme; Server-Produktversion; konfigurierte und laufende remote proc trans-Werte samt is_dynamic; sichtbare Linked-Server-Promotionflags; sichtbare aktive Transaktionen vom Typ 4; die drei separaten Quellzustände; Warnungen. Zielnamen müssen eindeutige, vorhandene, leere lokale #Temp-Tabellen mit genau einer Seed-Spalte sein, höchstens 116 Zeichen lang. ##Temp, #Monitor*-Namen und permanente Ziele sind unzulässig. Resultset-Schlüssel werden binär exakt auf Duplikate geprüft; Zielnamen auf Duplikate ohne Beachtung der Groß-/Kleinschreibung. Alle Zuordnungen werden vor dem fachlichen Quellenzugriff vorgeprüft. Danach schreibt die Procedure die Resultsets nacheinander; ein späterer Schreibfehler kann bereits geschriebene frühere Ziele zurücklassen. Bei Nicht-TABLE muss der Parameter NULL oder leer sein, sonst INVALID_PARAMETER/RETURN 51011. Im TABLE-Modus sind NULL, Leerstring und ein Objekt ohne Zuordnungen ungültig. Außerhalb TABLE sind NULL, Leerstring oder reine U+0020-Leerzeichen erlaubt. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit-Schalter: 0 unterdrückt die JSON-Erzeugung, jeder numerische Wert ungleich 0 wird in den Bit-Parameter als 1 konvertiert und erzeugt das Diagnose-JSON unabhängig von @ResultSetArt; NULL verhält sich wie 0, weil IF @JsonErzeugen=1 dann nicht ausgeführt wird. Das JSON enthält meta sowie alle sieben benannten Mengen, auch wenn Mengen leer sind. Der Schalter erzeugt selbst kein separates Resultset. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang für das bei @JsonErzeugen=1 erzeugte JSON. Binden Sie eine Variable vom Typ nvarchar(max) mit OUTPUT. Der Eingangswert wird am Prozedureintritt auf NULL gesetzt; bei Hilfe, ungültigen Parametern oder einem äußeren Fehler bleibt beziehungsweise wird er NULL. Ohne JSON-Anforderung wird keine JSON-Zeichenfolge erzeugt. Bei ausgelassenem Argument gilt der angegebene Default.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit-Schalter: 0 unterdrückt die bedingten RAISERROR-Hinweise der normalen Parameterprüfung, der Quellenfehler-Meldung und des äußeren Fehlerpfads; jeder numerische Wert ungleich 0 konvertiert zu 1 und lässt diese Hinweise zu. NULL verhält sich wegen IF @PrintMeldungen=1 wie 0. Die PRINT-Ausgabe des Hilfezweigs sind davon nicht abhängig und werden bei @Hilfe=1 ausgegeben. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit; Default: 0. Bit-Schalter: 0 führt die normale Inventarisierung aus; jeder numerische Wert ungleich 0 wird zu 1 und gibt die eingebaute Hilfe aus, setzt @StatusCodeOut auf AVAILABLE und @IsPartialOut auf 0 und beendet die Procedure vor Validierung und Quellenzugriff. NULL verhält sich wie 0. Der Hilfezweig setzt die drei übrigen OUTPUT-Werte nicht neu, nachdem sie am Eintritt zurückgesetzt wurden: @Json bleibt NULL, @ErrorNumberOut und @ErrorMessageOut bleiben NULL. Der normale EXIT-RETURN ist 0; dies ist kein Fehler- oder Diagnose-Rückgabecode. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionales OUTPUT für den Statuscode als varchar(40); binden Sie eine entsprechende Caller-Variable mit OUTPUT. Der Wert wird bei Eintritt auf NULL gesetzt. Hilfe liefert AVAILABLE; ungültige Parameter liefern INVALID_PARAMETER; der reguläre Ausführungspfad beginnt mit AVAILABLE_LIMITED und übernimmt bei mindestens einem Quellenfehler den Status der alphabetisch ersten fehlerhaften Quelle (Sortierung nach SourceName: ACTIVE_DISTRIBUTED_TRANSACTIONS vor LINKED_SERVER_PROMOTION vor SERVER_CONFIGURATION). Quellenfehler sind DENIED_PERMISSION für Fehlernummern 229, 297, 300 oder 371, TIMEOUT für 1222, sonst ERROR_HANDLED. Ein äußerer Fehler, einschließlich eines fehlgeschlagenen TABLE-Schreibens, überschreibt den OUTPUT-Status mit ERROR_HANDLED. Erfolg im normalen Pfad bleibt AVAILABLE_LIMITED, da das Modul stets als partiell gekennzeichnet wird. Bei ausgelassenem Argument gilt der angegebene Default.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionales OUTPUT-Bit; binden Sie eine Bit-Variable mit OUTPUT. Der Wert wird bei Eintritt NULL. Hilfe setzt 0; ungültige Parameter und der normale Quellenpfad sowie der äußere Fehlerpfad setzen 1. Die normale Ausführung ist stets partiell, weil Caller-Sichtbarkeit und externe Dienst-, Netzwerk-, Teilnehmer-, Commit- und Recovery-Grenzen offenbleiben; ein leerer sichtbarer Bestand hebt dies nicht auf. Numerische Nichtnull-Eingaben sind für diesen reinen OUTPUT-Parameter kein Eingabeschalter. Bei ausgelassenem Argument gilt der angegebene Default.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionales OUTPUT für die gewählte native oder diagnostische Fehlernummer; binden Sie eine int-Variable mit OUTPUT. Der Wert wird am Eintritt NULL. Für Hilfe und fehlerfreie normale Ausführung bleibt er NULL; ungültige Parameter setzen 51011. Bei mehreren Quellenfehlern werden Nummer und Meldung aus der alphabetisch ersten fehlerhaften Quelle übernommen. Beim äußeren Fehlerpfad enthält er die abgefangene SQL-Fehlernummer, außer dass ein gesetzter TABLE-Fehler die zuvor gespeicherte Tabellenfehlernummer bevorzugt; fehlt diese, wird die native SQL-Fehlernummer verwendet. TABLE-Vorprüfung liefert 51011, Writerfehler die gespeicherte Nummer oder 51010; der äußere CATCH setzt diese Nummer zugleich als Diagnose-RETURN. Reguläre Quellenfehler ändern den normalen RETURN 0 nicht. Bei ausgelassenem Argument gilt der angegebene Default.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionales OUTPUT für die zugehörige Meldung als nvarchar(2048); binden Sie eine entsprechende Variable mit OUTPUT. Der Wert wird am Eintritt NULL. Hilfe und fehlerfreie Ausführung lassen ihn NULL; ungültige Parameter setzen die feste Validierungsmeldung. Bei mehreren Quellenfehlern wird die Meldung der alphabetisch ersten fehlerhaften Quelle übernommen. Ein äußerer Fehler liefert den nativen SQL-Fehlertext; bei TABLE-Fehlern stammt die Meldung aus dem äußeren CATCH, dessen RAISERROR zuvor den TableMessage-Text erhalten hat; die gespeicherte TABLE-Fehlernummer priorisiert nur die Nummer. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| serverContext | 1 | 1 | [ProductMajorVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| promotionConfiguration | 1 | 1 | [ConfiguredValue] int NULL, [RunningValue] int NULL, [IsDynamic] bit NOT NULL |
| linkedServerPromotion | 1 | 1 | [ServerId] int NOT NULL, [RemoteProcTransactionPromotionEnabled] bit NOT NULL, [ModifiedAt] datetime NULL |
| activeDistributedTransactions | 1 | 1 | [TransactionId] bigint NOT NULL, [TransactionType] int NOT NULL, [TransactionBeginTime] datetime NULL, [TransactionState] int NOT NULL |
| sourceStatus | 1 | 1 | [SourceName] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CaptureStartedAtUtc] datetime2(3) NOT NULL, [CaptureEndedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowsReturned] bigint NULL, [LimitApplied] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [VisibilityLimit] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| warnings | 1 | 1 | [WarningCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceName] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_DistributedTransactionInventory] @MaxZeilen=200, @ResultSetArt='RAW', @PrintMeldungen=0;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Caller-sichtbare SQL-Metadaten; kein Dienst-, Netzwerk-, Teilnehmer-, Commit- oder Recovery-Nachweis.

Rein lesend; keine Berechtigungs-, Konfigurations- oder Transaktionsänderung.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_DistributedTransactionInventory
Version      : 1.0.0
Stand        : 2026-10-27
Zweck        : Die Procedure inventarisiert caller-sichtbare lokale MSDTC-Konfiguration und
               aktive Transaktionsmetadaten mit transaction_type = 4.
Quellen      : sys.configurations, sys.servers und
               sys.dm_tran_active_transactions.
Grenzen      : Caller-sichtbare SQL-Metadaten; kein Dienst-, Netzwerk-,
               Teilnehmer-, Commit- oder Recovery-Nachweis.
Datenschutz  : Keine Transaktionsnamen, UOWs, SQL-Texte, Identitäten,
               Linked-Servernamen oder Endpunktdaten.
Nebenwirkung : Rein lesend; keine Berechtigungs-, Konfigurations- oder
               Transaktionsänderung.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_DistributedTransactionInventory
Erfasst getrennte caller-sichtbare lokale SQL-Momentaufnahmen: die einzelne remote proc trans-Konfigurationszeile, Linked-Server-Promotionflags und aktive lokale Transaktionsmetadaten mit transaction_type = 4.
Die sieben Mengen heißen moduleStatus, serverContext, promotionConfiguration, linkedServerPromotion, activeDistributedTransactions, sourceStatus und warnings; RAW liefert sie in dieser Reihenfolge, JSON fasst sie unter denselben Schlüsseln zusammen.
Das Inventar belegt weder den Zustand des MSDTC-Dienstes noch Netzwerk- oder Teilnehmererreichbarkeit, Commit, Rollback oder Recovery. Ein leerer DMV-Bestand beweist keine instanzweite Abwesenheit.
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_DistributedTransactionInventory] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
CREATE TABLE [#DistributedTransactionInventory_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DistributedTransactionInventory] @ResultSetArt='TABLE', @ResultTablesJson=N'{"linkedServerPromotion":"#DistributedTransactionInventory_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#DistributedTransactionInventory_HelpExample]; DROP TABLE IF EXISTS [#DistributedTransactionInventory_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#DistributedTransactionInventory_HelpExample]; THROW; END CATCH;
```


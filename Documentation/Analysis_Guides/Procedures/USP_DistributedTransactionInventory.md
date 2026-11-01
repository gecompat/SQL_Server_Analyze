# [monitor].[USP_DistributedTransactionInventory]

**Bereich:** Server Health und Hochverfügbarkeit.
**Zweck:** Zeigt caller-sichtbare SQL-Konfiguration und aktive verteilte Transaktionsmetadaten.
**Beobachtungsart:** getrennte lokale Katalog- und DMV-Momentaufnahmen.
**Kostenklasse:** LOW.

## Diagnosefrage und Grenzen

Die Procedure zeigt getrennte Momentaufnahmen der caller-sichtbaren einzelnen remote proc trans-Konfigurationszeile, der Linked-Server-Promotionflags und der aktiven Zeilen aus sys.dm_tran_active_transactions mit transaction_type = 4. Sie prüft weder MSDTC-Dienstzustand noch Netzwerk, Teilnehmer, Commit, Recovery oder HADR-Verfügbarkeit. Ein leerer DMV-Bestand beweist keine instanzweite Abwesenheit aktiver verteilter Transaktionen.

Die Option remote proc trans betrifft alte Remote-Prozeduraufrufe mit sp_addserver; sie ist nicht die Linked-Server-Promotionoption. SET REMOTE_PROC_TRANSACTIONS kann verbindungsbezogen abweichen. Die Linked-Serverzeilen werden separat aus sys.servers gelesen. Keine Quelle wird geändert und kein entfernter Aufruf ausgeführt.

## Voraussetzungen und Last

Die Procedure besitzt SERVER-Scope ohne Datenbankauswahl. Sie liest sys.configurations, sys.servers und sys.dm_tran_active_transactions im Caller-Kontext. Die Ausgabe enthält keine Transaktionsnamen, UOW/GUIDs, Linked-Servernamen, Provider, Endpunkte, SQL-Texte, Anmeldungen oder Zugangsdaten.

Für `sys.dm_tran_active_transactions` wird `VIEW SERVER STATE` auf SQL Server 2019 benötigt; ab SQL Server 2022 ist `VIEW SERVER PERFORMANCE STATE` erforderlich. `sys.configurations` ist auf älteren Versionen öffentlich sichtbar; ab SQL Server 2022 ist dafür ebenfalls `VIEW SERVER PERFORMANCE STATE` erforderlich. `sys.servers`-Metadaten folgen der Katalogsichtbarkeit; ab SQL Server 2022 kann für eingeschränkte Servermetadaten `VIEW SERVER SECURITY STATE` erforderlich sein. Quellenrechte werden nicht erteilt oder geändert. Prüfen Sie `sourceStatus`, wenn eine Quelle nicht verfügbar ist.

Die Konfigurationsquelle liefert höchstens die einzelne passende sys.configurations-Zeile. Bei positivem @MaxZeilen materialisieren die Linked-Server- und DMV-Abfragen jeweils höchstens @MaxZeilen plus eine Probezeile; danach werden die Mengen auf @MaxZeilen gekürzt. NULL oder 0 bedeutet unbegrenzt. Ein negatives Limit wird vor Quellenzugriff abgelehnt. Der Standardwert von @LockTimeoutMs ist 0; zulässig sind 0 bis 60000 Millisekunden. Das Limit begrenzt die ausgegebenen und materialisierten Zeilen dieser beiden Mengen, nicht garantiert den Aufwand der Quellermittlung.

Die drei Quellen werden in getrennten TRY/CATCH-Pfaden aufgenommen. Ein Quellenfehler leert nur die betroffene Fachmenge und wird mit Fehlernummer und Meldung in ihrem sourceStatus-Eintrag festgehalten; erfolgreiche andere Mengen bleiben erhalten. Der Modulstatus übernimmt bei mehreren Fehlern den Status der alphabetisch ersten fehlerhaften Quelle. Die Ausgabe setzt IsPartial stets auf 1, weil Caller-Sichtbarkeit und externe Gesundheitsgrenzen offen sind.

## Einstieg und Ausgabearten

    EXEC [monitor].[USP_DistributedTransactionInventory]
        @MaxZeilen=100, @LockTimeoutMs=0, @ResultSetArt='CONSOLE';

    DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit;
    EXEC [monitor].[USP_DistributedTransactionInventory]
        @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT,
        @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT;
    SELECT @Status AS [StatusCode], @Partial AS [IsPartial], @Json AS [DiagnosticJson];

CONSOLE gibt eine kompakte Zusammenfassung aus; RAW liefert sieben Resultsets in der unten genannten Reihenfolge. NONE unterdrückt Resultsets, optionales JSON bleibt verfügbar. TABLE prüft die nicht leere JSON-Zuordnung vor dem fachlichen Quellenzugriff. Jeder angegebene, exakt geschriebene Resultsetname wird einer eindeutigen vorhandenen, leeren lokalen #Temp-Tabelle mit genau einer Seed-Spalte zugeordnet. Die Ziele werden anschließend nacheinander beschrieben; ein Fehler kann vorher geschriebene Ziele zurücklassen. Alle Ausgabearten verwenden dieselbe Materialisierung innerhalb des jeweiligen Aufrufs. Der vollständige Signaturvertrag steht im [Procedure-Referenzhandbuch](../../Reference/Procedure_Reference.md#monitorusp_distributedtransactioninventory).

### Individuelle Parameterverträge

Die folgenden Einträge erklären jeden Parameter mit Datentyp, Eingabeform und ausdrücklich bezeichnetem Default. OUTPUT-Werte werden nur bei passender, mit OUTPUT gebundener Variable empfangen.

| Parameter und Typ | Default | Eingabeform, Wirkung und Grenzen |
|---|---|---|
| `@MaxZeilen int` | `1000` | Die Fachmengen linkedServerPromotion und activeDistributedTransactions werden jeweils mit TOP (@MaxZeilen + 1) materialisiert, wenn ein positiver Wert angegeben ist; die zusätzliche Zeile dient nur dazu, eine Überschreitung zu erkennen. Anschließend werden beide Ausgabemengen auf @MaxZeilen gekürzt. NULL oder 0 steht für unbegrenzt; negative Werte werden vor Quellenzugriff mit INVALID_PARAMETER und RETURN 51011 abgelehnt. Die Konfigurationsquelle enthält höchstens die einzelne passende sys.configurations-Zeile und wird nicht über dieses Limit gekappt. Das Limit begrenzt die ausgegebenen und für die zwei Mengen materialisierten Zeilen, nicht garantiert den Aufwand der Quellermittlung. RowsReturned enthält nach der Kappung die ausgegebene Zeilenzahl; LimitApplied ist nur 1, wenn die Probe mehr Zeilen als die Ausgabe enthielt. Ein leerer sichtbarer Bestand belegt keine instanzweite Abwesenheit. |
| `@LockTimeoutMs int` | `0` | Steuert das in jedem dynamischen Quellenbatch gesetzte LOCK_TIMEOUT in Millisekunden. Zulässig sind 0 bis 60000 einschließlich; NULL und Werte außerhalb des Bereichs werden vor Quellenzugriff mit INVALID_PARAMETER und RETURN 51011 abgelehnt. 0 bedeutet für die Quellenbatches NOWAIT. Der Wert ist kein globales Zeitbudget. Bei einem eingehenden Sitzungswert von 0 schützt die Procedure ihre eigene anfängliche Temp-Tabellenanlage bedingt mit 1000 ms; vor den fachlichen Quellen setzt sie LOCK_TIMEOUT 0, und erst der jeweilige dynamische Quellenbatch verwendet diesen Parameter. Die erfolgreiche Rückkehr stellt den zuvor gespeicherten Locktimeout wieder her; SET-Werte aus dynamischen Batches belegen keine weiterreichende Sessionwirkung. |
| `@ResultSetArt varchar(16)` | `'CONSOLE'` | Wählt genau einen Ausgabemodus. Erlaubt sind CONSOLE (eine kompakte beschriftete Zusammenfassung), RAW (sieben Resultsets in der Reihenfolge moduleStatus, serverContext, promotionConfiguration, linkedServerPromotion, activeDistributedTransactions, sourceStatus, warnings), TABLE (schreibt die zugeordneten Mengen in Aufrufer-Temp-Tabellen) und NONE (unterdrückt Resultsets). Die Eingabe wird mit LTRIM/RTRIM von Rand-Leerzeichen bereinigt und mit UPPER großgeschrieben; der Vergleich ist damit unabhängig von Groß-/Kleinschreibung. NULL und Leertext werden zu einem ungültigen leeren Modus; jeder andere Wert liefert INVALID_PARAMETER und RETURN 51011. Außerhalb von TABLE muss @ResultTablesJson NULL oder nach Rand-Leerzeichen leer sein. JSON-Erzeugung ist unabhängig vom Resultsetmodus. |
| `@ResultTablesJson nvarchar(max)` | `NULL` | Nur für TABLE: ein nicht leeres JSON-Objekt, dessen Eigenschaftsnamen exakt und groß-/kleinschreibungsgenau zu den erlaubten Resultsetnamen moduleStatus, serverContext, promotionConfiguration, linkedServerPromotion, activeDistributedTransactions, sourceStatus oder warnings passen; ein Teil der sieben Zuordnungen genügt. Jeder Eigenschaftswert muss eine Zeichenfolge mit dem Namen eines Ziels sein. Die Schlüssel bezeichnen jeweils: Gesamtstatus/Partialität/ausgegebene Fachzeilensumme; Server-Produktversion; konfigurierte und laufende remote proc trans-Werte samt is_dynamic; sichtbare Linked-Server-Promotionflags; sichtbare aktive Transaktionen vom Typ 4; die drei separaten Quellzustände; Warnungen. Zielnamen müssen eindeutige, vorhandene, leere lokale #Temp-Tabellen mit genau einer Seed-Spalte sein, höchstens 116 Zeichen lang. ##Temp, #Monitor*-Namen und permanente Ziele sind unzulässig. Resultset-Schlüssel werden binär exakt auf Duplikate geprüft; Zielnamen auf Duplikate ohne Beachtung der Groß-/Kleinschreibung. Alle Zuordnungen werden vor dem fachlichen Quellenzugriff vorgeprüft. Danach schreibt die Procedure die Resultsets nacheinander; ein späterer Schreibfehler kann bereits geschriebene frühere Ziele zurücklassen. Bei Nicht-TABLE muss der Parameter NULL oder leer sein, sonst INVALID_PARAMETER/RETURN 51011. Im TABLE-Modus sind NULL, Leerstring und ein Objekt ohne Zuordnungen ungültig. Außerhalb TABLE sind NULL, Leerstring oder reine U+0020-Leerzeichen erlaubt. |
| `@JsonErzeugen bit` | `0` | Bit-Schalter: 0 unterdrückt die JSON-Erzeugung, jeder numerische Wert ungleich 0 wird in den Bit-Parameter als 1 konvertiert und erzeugt das Diagnose-JSON unabhängig von @ResultSetArt; NULL verhält sich wie 0, weil IF @JsonErzeugen=1 dann nicht ausgeführt wird. Das JSON enthält meta sowie alle sieben benannten Mengen, auch wenn Mengen leer sind. Der Schalter erzeugt selbst kein separates Resultset. |
| `@Json nvarchar(max) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang für das bei @JsonErzeugen=1 erzeugte JSON. Binden Sie eine Variable vom Typ nvarchar(max) mit OUTPUT. Der Eingangswert wird am Prozedureintritt auf NULL gesetzt; bei Hilfe, ungültigen Parametern oder einem äußeren Fehler bleibt beziehungsweise wird er NULL. Ohne JSON-Anforderung wird keine JSON-Zeichenfolge erzeugt. |
| `@PrintMeldungen bit` | `1` | Bit-Schalter: 0 unterdrückt die bedingten RAISERROR-Hinweise der normalen Parameterprüfung, der Quellenfehler-Meldung und des äußeren Fehlerpfads; jeder numerische Wert ungleich 0 konvertiert zu 1 und lässt diese Hinweise zu. NULL verhält sich wegen IF @PrintMeldungen=1 wie 0. Die PRINT-Ausgabe des Hilfezweigs sind davon nicht abhängig und werden bei @Hilfe=1 ausgegeben. |
| `@Hilfe bit` | `0` | Bit-Schalter: 0 führt die normale Inventarisierung aus; jeder numerische Wert ungleich 0 wird zu 1 und gibt die eingebaute Hilfe aus, setzt @StatusCodeOut auf AVAILABLE und @IsPartialOut auf 0 und beendet die Procedure vor Validierung und Quellenzugriff. NULL verhält sich wie 0. Der Hilfezweig setzt die drei übrigen OUTPUT-Werte nicht neu, nachdem sie am Eintritt zurückgesetzt wurden: @Json bleibt NULL, @ErrorNumberOut und @ErrorMessageOut bleiben NULL. Der normale EXIT-RETURN ist 0; dies ist kein Fehler- oder Diagnose-Rückgabecode. |
| `@StatusCodeOut varchar(40) OUTPUT` | `NULL` | Optionales OUTPUT für den Statuscode als varchar(40); binden Sie eine entsprechende Caller-Variable mit OUTPUT. Der Wert wird bei Eintritt auf NULL gesetzt. Hilfe liefert AVAILABLE; ungültige Parameter liefern INVALID_PARAMETER; der reguläre Ausführungspfad beginnt mit AVAILABLE_LIMITED und übernimmt bei mindestens einem Quellenfehler den Status der alphabetisch ersten fehlerhaften Quelle (Sortierung nach SourceName: ACTIVE_DISTRIBUTED_TRANSACTIONS vor LINKED_SERVER_PROMOTION vor SERVER_CONFIGURATION). Quellenfehler sind DENIED_PERMISSION für Fehlernummern 229, 297, 300 oder 371, TIMEOUT für 1222, sonst ERROR_HANDLED. Ein äußerer Fehler, einschließlich eines fehlgeschlagenen TABLE-Schreibens, überschreibt den OUTPUT-Status mit ERROR_HANDLED. Erfolg im normalen Pfad bleibt AVAILABLE_LIMITED, da das Modul stets als partiell gekennzeichnet wird. |
| `@IsPartialOut bit OUTPUT` | `NULL` | Optionales OUTPUT-Bit; binden Sie eine Bit-Variable mit OUTPUT. Der Wert wird bei Eintritt NULL. Hilfe setzt 0; ungültige Parameter und der normale Quellenpfad sowie der äußere Fehlerpfad setzen 1. Die normale Ausführung ist stets partiell, weil Caller-Sichtbarkeit und externe Dienst-, Netzwerk-, Teilnehmer-, Commit- und Recovery-Grenzen offenbleiben; ein leerer sichtbarer Bestand hebt dies nicht auf. Numerische Nichtnull-Eingaben sind für diesen reinen OUTPUT-Parameter kein Eingabeschalter. |
| `@ErrorNumberOut int OUTPUT` | `NULL` | Optionales OUTPUT für die gewählte native oder diagnostische Fehlernummer; binden Sie eine int-Variable mit OUTPUT. Der Wert wird am Eintritt NULL. Für Hilfe und fehlerfreie normale Ausführung bleibt er NULL; ungültige Parameter setzen 51011. Bei mehreren Quellenfehlern werden Nummer und Meldung aus der alphabetisch ersten fehlerhaften Quelle übernommen. Beim äußeren Fehlerpfad enthält er die abgefangene SQL-Fehlernummer, außer dass ein gesetzter TABLE-Fehler die zuvor gespeicherte Tabellenfehlernummer bevorzugt; fehlt diese, wird die native SQL-Fehlernummer verwendet. TABLE-Vorprüfung liefert 51011, Writerfehler die gespeicherte Nummer oder 51010; der äußere CATCH setzt diese Nummer zugleich als Diagnose-RETURN. Reguläre Quellenfehler ändern den normalen RETURN 0 nicht. |
| `@ErrorMessageOut nvarchar(2048) OUTPUT` | `NULL` | Optionales OUTPUT für die zugehörige Meldung als nvarchar(2048); binden Sie eine entsprechende Variable mit OUTPUT. Der Wert wird am Eintritt NULL. Hilfe und fehlerfreie Ausführung lassen ihn NULL; ungültige Parameter setzen die feste Validierungsmeldung. Bei mehreren Quellenfehlern wird die Meldung der alphabetisch ersten fehlerhaften Quelle übernommen. Ein äußerer Fehler liefert den nativen SQL-Fehlertext; bei TABLE-Fehlern stammt die Meldung aus dem äußeren CATCH, dessen RAISERROR zuvor den TableMessage-Text erhalten hat; die gespeicherte TABLE-Fehlernummer priorisiert nur die Nummer. |

### Kopierbare Aufrufbeispiele

Die getrennten Beispiele zeigen RAW, typisierte Diagnose-OUTPUTs mit RETURN, einen TABLE-Teilexport und die Hilfe. Das TABLE-Ziel wird mit einer Seed-Spalte angelegt und in beiden Abschlusswegen entfernt.

```sql
EXEC [monitor].[USP_DistributedTransactionInventory] @MaxZeilen=200, @ResultSetArt='RAW', @PrintMeldungen=0;
```

```sql
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_DistributedTransactionInventory] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
```

```sql
CREATE TABLE [#DistributedTransactionInventory_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DistributedTransactionInventory] @ResultSetArt='TABLE', @ResultTablesJson=N'{"linkedServerPromotion":"#DistributedTransactionInventory_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#DistributedTransactionInventory_HelpExample]; DROP TABLE IF EXISTS [#DistributedTransactionInventory_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#DistributedTransactionInventory_HelpExample]; THROW; END CATCH;
```

```sql
EXEC [monitor].[USP_DistributedTransactionInventory] @Hilfe=1;
```

## Eine Zeile bedeutet

| Menge | Inhalt und Zähleinheit |
|---|---|
| moduleStatus | Gesamtstatus, Partialität und Summe der ausgegebenen Fachzeilen. |
| serverContext | SERVERPROPERTY ProductMajorVersion, ohne Host- oder Instanzidentität. |
| promotionConfiguration | Konfigurierte und laufende Werte der einzelnen remote proc trans-Zeile sowie is_dynamic. |
| linkedServerPromotion | Caller-sichtbare Standard-Linked-Serverzeilen: server_id, is_remote_proc_transaction_promotion_enabled und modify_date; Namen und Verbindungsdaten bleiben ausgeschlossen. |
| activeDistributedTransactions | Sichtbare sys.dm_tran_active_transactions-Zeilen mit transaction_type=4 und nur transaction_id, transaction_type, transaction_begin_time sowie transaction_state. |
| sourceStatus | Drei getrennte Quellzustände mit Counts, Limitstatus und nativer Fehlernummer beziehungsweise -meldung. |
| warnings | Vollständigkeits-, Limit- und Werte-Typwarnungen. |

Die sql_variant-Werte aus sys.configurations werden nur dann als int ausgegeben, wenn `SQL_VARIANT_PROPERTY(..., N'BaseType')` exakt `int` ergibt. Ein nativer NULL-Wert bleibt NULL. Ein nicht-NULL-Wert mit anderem oder nicht auswertbarem Basistyp bleibt als typisiertes NULL und erzeugt die feste Warnung `CONFIG_VALUE_TYPE_UNSUPPORTED`; bloße Konvertierbarkeit reicht nicht aus. Es wird keine Null durch 0 ersetzt.

## So lesen

Prüfen Sie moduleStatus und sourceStatus, bevor Sie die Fachzeilen interpretieren. Vergleichen Sie configured und running value getrennt. Linked-Server-Promotion ist eine Konfigurationseigenschaft; aktive DMV-Metadaten beschreiben einen anderen Moment. Der transaction_id ist nur innerhalb einer SQL-Server-Instanz eindeutig und wird nicht mit externen Teilnehmern korreliert.

## Warum kann das problematisch sein?

Eine Konfigurationseinstellung beweist weder eine aktive verteilte Transaktion noch eine Verbindung zum Koordinator. Eine aktive DMV-Zeile beweist weder den Erfolg aller Teilnehmer noch einen abgeschlossenen Commit oder Recovery.

## Wann ist es kein Problem?

Ein leerer sichtbarer DMV-Bestand kann mit dem aktuellen SQL-Metadatenstand übereinstimmen. Er ist keine Aussage über externe Dienste, nicht sichtbare Quellen oder eine globale Abwesenheit verteilter Arbeit. Ohne getrennte positive Evidenz ist keine MSDTC-Gesundheitsbewertung abzuleiten.

## Stabiler Feldvertrag

Die sieben Resultsets besitzen SchemaVersion 1. Textfelder verwenden SQL_Latin1_General_CP1_CS_AS. Native Felder behalten die dokumentierten Typen; nur die beiden sql_variant-Konfigurationswerte werden ausdrücklich zu int normalisiert. TABLE verwendet den gemeinsamen [Output RAW/CONSOLE/JSON-Vertrag](../../Architecture/Output_RAW_CONSOLE_JSON.md).

## Gegenprüfung und nächste Schritte

Microsoft beschreibt die nativen Spalten und Versionsrechte in den Primärquellen am Seitenende. Eine echte positive aktive DTC-Zeile, ein verteilter Commit-/Rollback und externe Dienst-/Netzwerkgesundheit benötigen vorbereitete DTC- und Teilnehmerinfrastruktur. Diese Abnahme ist nicht Teil der SQL-2025-CI.

## Technische Vertiefung

### Leitfrage

Welche lokale Konfiguration und welche aktiven transaction_type=4-Metadaten zeigt der SQL-Server-Caller im Moment der getrennten Aufnahmen?

### Technischer Hintergrund

sys.configurations.value und value_in_use sind sql_variant; ihre native Typinformation wird nicht pauschal als int vorausgesetzt. sys.servers kennzeichnet Standard-Linked-Server mit is_linked=1. Die DMV-Klassifikation transaction_type=4 bedeutet laut Microsoft verteilte Transaktion. Keine dieser Eigenschaften meldet Dienst- oder Teilnehmergesundheit.

### Datenkette

Die Procedure liest genau die definierte Konfigurationszeile, caller-sichtbare Linked-Server-Promotionflags und aktive DTC-Metadaten. Jede Quelle hat einen eigenen Fehlerpfad. Für Linked-Server und DMV wird eine zusätzliche Probezeile gelesen, um ein tatsächlich überschrittenes Limit zu kennzeichnen. Nur die fachliche Ausgabe wird gekappt.

### Source Select

**Wichtig für die Eigenlast:** Die drei Quellen werden separat im Caller-Kontext gelesen. Die begrenzten Projektionen zeigen ausschließlich die vertraglich freigegebenen Felder; die Implementierung setzt das Quellen-Locktimeout und meldet jeden Quellenfehler separat.

```sql
SELECT [c].[value], [c].[value_in_use], [c].[is_dynamic]
    FROM [sys].[configurations] AS [c] WITH (NOLOCK)
WHERE [c].[name]=N'remote proc trans';

SELECT TOP (@ProbeLimit) [s].[server_id],
           [s].[is_remote_proc_transaction_promotion_enabled], [s].[modify_date]
FROM [sys].[servers] AS [s] WITH (NOLOCK)
WHERE [s].[is_linked]=1
ORDER BY [s].[server_id];

SELECT TOP (@ProbeLimit) [t].[transaction_id], [t].[transaction_type],
           [t].[transaction_begin_time], [t].[transaction_state]
FROM [sys].[dm_tran_active_transactions] AS [t]
WHERE [t].[transaction_type]=4
ORDER BY [t].[transaction_begin_time], [t].[transaction_id];
```

### Zeit- und Scope-Modell

Alle Quellen sind lokale, nicht atomare SQL-Momentaufnahmen. Der Scope bleibt SERVER und Caller-sichtbar; bei eingeschränkter Sicht können einzelne Mengen leer oder fehlgeschlagen sein. Es gibt keine Datenbankauswahl und keine Remote-Probe.

### Bewertung und Gegenprobe

SQL Server 2025 CI kann echte Konfigurationswerte, sichtbare Linked-Servermetadaten und leere oder eingeschränkte DMV-Pfade prüfen. Ohne vorhandene DTC-Infrastruktur wird kein positiver aktiver Transaktionsdatensatz als Abnahme beansprucht. Ein nichtleeres Ergebnis bleibt SQL-Metadatenevidenz und kein Commitnachweis.

### Typische Fehlinterpretation

remote proc trans und is_remote_proc_transaction_promotion_enabled sind nicht dasselbe Signal. Ein auf 1 gesetztes Feld ist kein Nachweis, dass eine verteilte Transaktion gestartet, verbunden oder committed wurde. Ein leerer DMV-Bestand ist keine globale Abwesenheits- oder Gesundheitsbehauptung.

### Folgeanalyse

Für Linked-Server-Konfiguration siehe [USP_LinkedServerAnalysis](USP_LinkedServerAnalysis.md); für lokal sichtbare Transaktionen siehe [USP_CurrentTransactions](USP_CurrentTransactions.md). Die [Technische Detailbeschreibung](../../Reference/Procedure_Reference.md#monitorusp_distributedtransactioninventory) und das [Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md) ergänzen den Aufrufvertrag.

## Primärquellen

- [sys.configurations](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-configurations-transact-sql?view=sql-server-ver17)
- [sys.servers](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-servers-transact-sql?view=sql-server-ver17)
- [sys.dm_tran_active_transactions](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-tran-active-transactions-transact-sql?view=sql-server-ver17)
- [SET REMOTE_PROC_TRANSACTIONS](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-remote-proc-transactions-transact-sql?view=sql-server-ver15)
- [sp_serveroption](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-serveroption-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Das [Gemeinsame Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md) erläutert quellenbezogene Zeit- und Partialitätsgrenzen.

Siehe [Analysis Navigator](../../Reference/Analysis_Navigator.md) und [Server Health](../08_Server_Health.md).

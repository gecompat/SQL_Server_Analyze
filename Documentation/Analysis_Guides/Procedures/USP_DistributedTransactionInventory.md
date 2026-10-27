# [monitor].[USP_DistributedTransactionInventory]

**Bereich:** Server Health und Hochverfügbarkeit.
**Zweck:** Zeigt caller-sichtbare SQL-Konfiguration und aktive verteilte Transaktionsmetadaten.
**Beobachtungsart:** getrennte lokale Katalog- und DMV-Momentaufnahmen.
**Kostenklasse:** LOW.

## Diagnosefrage und Grenzen

Die Procedure beantwortet, welche lokale Promotionkonfiguration, Linked-Server-Promotionflags und aktive Transaktionsmetadaten der aktuelle Caller sehen kann. Sie prüft weder MSDTC-Dienstzustand noch Netzwerk, Teilnehmer, Commit, Recovery oder HADR-Verfügbarkeit. Ein leerer DMV-Bestand beweist keine instanzweite Abwesenheit aktiver verteilter Transaktionen.

Die Option remote proc trans betrifft alte Remote-Prozeduraufrufe mit sp_addserver; sie ist nicht die Linked-Server-Promotionoption. SET REMOTE_PROC_TRANSACTIONS kann verbindungsbezogen abweichen. Die Linked-Serverzeilen werden separat aus sys.servers gelesen. Keine Quelle wird geändert und kein entfernter Aufruf ausgeführt.

## Voraussetzungen und Last

Die Procedure besitzt SERVER-Scope ohne Datenbankauswahl. Sie liest sys.configurations, sys.servers und sys.dm_tran_active_transactions im Caller-Kontext. Die Ausgabe enthält keine Transaktionsnamen, UOW/GUIDs, Linked-Servernamen, Provider, Endpunkte, SQL-Texte, Anmeldungen oder Zugangsdaten.

Für `sys.dm_tran_active_transactions` wird `VIEW SERVER STATE` auf SQL Server 2019 benötigt; ab SQL Server 2022 ist `VIEW SERVER PERFORMANCE STATE` erforderlich. `sys.configurations` ist auf älteren Versionen öffentlich sichtbar; ab SQL Server 2022 ist dafür ebenfalls `VIEW SERVER PERFORMANCE STATE` erforderlich. `sys.servers`-Metadaten folgen der Katalogsichtbarkeit; ab SQL Server 2022 kann für eingeschränkte Servermetadaten `VIEW SERVER SECURITY STATE` erforderlich sein. Quellenrechte werden nicht erteilt oder geändert. Prüfen Sie `sourceStatus`, wenn eine Quelle nicht verfügbar ist.

Die Konfigurationsquelle ist eine einzelne Zeile. Linked-Server- und DMV-Abfragen materialisieren höchstens das angeforderte Limit plus eine Erkennungszeile. NULL oder 0 bedeutet unbegrenzt; ein negatives Limit wird vor dem Quellenzugriff abgelehnt. Der Standard-Locktimeout ist 0; zulässig sind 0 bis 60000 Millisekunden. Die Limitierung beschränkt die Ausgabemenge, nicht garantiert die Arbeit zum Ermitteln nativer Quellzeilen.

Die Quellen werden getrennt aufgenommen. Ein Lesefehler bleibt im eigenen sourceStatus sichtbar und entfernt keine erfolgreichen anderen Mengen. Das Modul bleibt mit IsPartial=1 partiell, weil Metadatensicht und externe Gesundheitsgrenzen offen sind.

## Einstieg und Ausgabearten

    EXEC [monitor].[USP_DistributedTransactionInventory]
        @MaxZeilen=100, @LockTimeoutMs=0, @ResultSetArt='CONSOLE';

    DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit;
    EXEC [monitor].[USP_DistributedTransactionInventory]
        @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT,
        @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT;
    SELECT @Status AS [StatusCode], @Partial AS [IsPartial], @Json AS [DiagnosticJson];

CONSOLE gibt eine kompakte Zusammenfassung aus; RAW liefert sieben Resultsets in der unten genannten Reihenfolge. NONE unterdrückt Resultsets, optionales JSON bleibt verfügbar. TABLE schreibt in sieben vom Aufrufer bereitgestellte leere lokale Temporärtabellen gemäß ResultTablesJson. Alle Ausgabearten verwenden dieselbe Materialisierung innerhalb des jeweiligen Aufrufs. Der vollständige Signaturvertrag steht im [Procedure-Referenzhandbuch](../../Reference/Procedure_Reference.md#monitorusp_distributedtransactioninventory).

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

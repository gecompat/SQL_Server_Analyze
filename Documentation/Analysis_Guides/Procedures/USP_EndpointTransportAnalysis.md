# [monitor].[USP_EndpointTransportAnalysis]

**Bereich:** Server Health und Sicherheitsdiagnostik.
**Zweck:** Zeigt sichtbare Engineendpoints, native TCP-/Mirroringkonfiguration
und gruppierte Verschlüsselungsflags bestehender Verbindungen.
**Beobachtungsart:** getrennte Katalog- und DMV-Momentaufnahmen.
**Kostenklasse:** LOW_MEDIUM.

## Diagnosefrage und Grenzen

Der Bericht beantwortet, welche Endpoints der Caller sehen kann und welche
Transport-/Authentifizierungs-/Verschlüsselungswerte vorhandene DMV-Zeilen
melden. Die Ausgabe verbindet diese Beobachtungen über native Endpoint-IDs.
Sie ergänzt die [EncryptionAnalysis](USP_EncryptionAnalysis.md), deren
Schwerpunkt Daten-, Backup- und Always-Encrypted-Konfiguration ist.

Ein encrypt_option-Wert beweist keine TLS-Version, keinen ausgehandelten
Cipher, keine vertrauenswürdige Zertifikatskette, Hostnamenprüfung, Extended
Protection oder sichere Treiberkonfiguration. Der Bericht liest keine
Hostdateien, Registry, privaten Schlüssel, Credentials oder Zertifikatsinhalte
und verändert weder Endpoints noch Rechte oder Hostoptionen. Er öffnet keine
zusätzliche Verbindung. Force Encryption, Strict Encryption und TLS 1.3
benötigen getrennte Konfigurations- und Verbindungsnachweise.

Die Mirroringkonfiguration gilt für den sichtbaren Endpoint. Sie beweist
keinen erfolgreichen Handshake. Die MirroringRole beschreibt Database
Mirroring und keine AG-Replikarolle. Für HADR-Mirroring meldet die native
Verbindungs-DMV encrypt_option stets als FALSE; dieser Wert darf nicht als
Nachweis unverschlüsselten HADR-Transports interpretiert werden.

Katalogport und LISTENER_IP können von der tatsächlichen Protokollkonfiguration
abweichen. Ein nativer Endpointzustand ist keine externe Erreichbarkeitsprobe.
Die getrennten Quellen sind keine atomare Topologieaufnahme und enthalten
keinen pauschalen Gesundheits- oder Sicherheitsstatus.

## Voraussetzungen und Last

Die Procedure besitzt SERVER-Scope und keine künstliche Datenbankauswahl.
Sie liest sys.endpoints, sys.tcp_endpoints, sys.database_mirroring_endpoints
und sys.dm_exec_connections im aktiven Caller-Kontext. Die Metadatensicht kann
leere oder eingeschränkte Mengen ergeben. Ab SQL2022 nennen die Endpointkataloge
VIEW SERVER SECURITY STATE; die Verbindungs-DMV benötigt auf SQL2019 VIEW SERVER
STATE und ab SQL2022 VIEW SERVER PERFORMANCE STATE. Das Framework erteilt
keine Rechte und wechselt keine Identität.

Die Aufnahme benötigt Arbeit proportional zu den sichtbaren Katalog- und
DMV-Zeilen. Vollständige temporäre Caches entstehen vor Verknüpfung und
Ausgabelimit. MaxZeilen begrenzt daher die Ausgabe und nicht die Lese- oder
Aggregationsarbeit. LockTimeoutMs begrenzt Quellenbatches zwischen 0 und
60000 Millisekunden; 0 verlangt sofortige Rückgabe bei einer Sperre. Eigene
temporäre DDL besitzt einen getrennten begrenzten Schutz. Der Bericht
übernimmt weder Commit noch Rollback einer Callertransaktion.

## Einstieg und Ausgabearten

```sql
EXEC [monitor].[USP_EndpointTransportAnalysis]
    @MaxZeilen=200, @LockTimeoutMs=0, @ResultSetArt='CONSOLE';
```

CONSOLE verwendet den gemeinsamen Renderer für Fachzeilen, Quellenzustände
und Warnungen. RAW liefert in
Reihenfolge moduleStatus, endpoints, tcpEndpoints, mirroringEndpoints,
connectionEncryptionSummary, sourceStatus und warnings. NONE unterdrückt
fachliche Resultsets. JSON besitzt SchemaVersion 1, meta mit resultName,
schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und
errorMessage sowie dieselben sieben Arrays. TABLE schreibt nur gewählte Mengen.
Quellenstatus und Warnungen werden nicht durch @MaxZeilen gekappt.

```sql
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int;
EXEC [monitor].[USP_EndpointTransportAnalysis]
    @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT,
    @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT,
    @ErrorNumberOut=@Error OUTPUT, @PrintMeldungen=0;
SELECT @Status AS [StatusCode], @Partial AS [IsPartial],
       @Error AS [ErrorNumber], @Json AS [DiagnosticJson];
```

TABLE verwendet ResultTablesJson als JSON-Objekt mit mindestens einem Paar aus
Resultsetname und Stringwert für ein vorhandenes lokales #Temp-Ziel. Jedes Ziel
muss leer sein und genau eine Seed-Spalte besitzen; der Name darf höchstens
116 Zeichen lang sein und weder ## noch das reservierte Präfix #Monitor
verwenden. Doppelte Schlüssel werden abgelehnt, doppelte Ziele werden
case-insensitiv geprüft. Die Schlüssel sind in exakter Schreibweise unten
einzeln erklärt. Ziele werden nacheinander beschrieben; ein späterer
Writerfehler kann bereits geschriebene Mengen stehen lassen; die Zielfelder werden entsprechend dem
[gemeinsamen TABLE-Vertrag](../../Architecture/Output_RAW_CONSOLE_JSON.md) geprüft.
MaxZeilen ist standardmäßig 1000, 0 oder NULL bedeutet unbegrenzt; negative
Werte sind ungültig. Jedes der vier Fachresultsets erhält sein eigenes Limit.
moduleStatus, sourceStatus und warnings bleiben ungekürzt.

### Individuelle Parameterverträge

Die folgenden Einträge erklären jeden Parameter einschließlich Eingabeform und Default. OUTPUT-Werte werden nur mit einer passenden, mit OUTPUT gebundenen Variable empfangen.

| Parameter und Typ | Default | Eingabeform, Wirkung und Grenzen |
|---|---|---|
| `@MaxZeilen int` | `1000` | Ganze Zahl als Zeilenlimit je Fachmenge: endpoints, tcpEndpoints, mirroringEndpoints und connectionEncryptionSummary werden unabhängig begrenzt. Positiv begrenzt; NULL oder 0 bedeutet unbegrenzt, negativ ist ungültig. Vollständige Aufnahme und Gruppierung erfolgen davor; sourceStatus.IsLimited zeigt Kürzung. moduleStatus.RowCount summiert ausgegebene Fachzeilen; moduleStatus, sourceStatus und warnings bleiben ungekürzt. |
| `@LockTimeoutMs int` | `0` | Timeout in ms je Quellenbatch: 0–60000; 0 wartet nicht, NULL/außerhalb ungültig. Kein Gesamtzeitlimit. Eigene Temp-DDL erhält 1000 ms. SET im dynamischen Batch gilt nur dort und wird bei Rückkehr zurückgenommen. |
| `@ResultSetArt varchar(16)` | `'CONSOLE'` | Ein einzelner Textwert wird mit LTRIM/RTRIM um U+0020-Leerzeichen bereinigt und mit UPPER normalisiert. NULL, Leerstring und reine Leerzeichen sind ungültig. Sämtliche erlaubten Werte: CONSOLE liefert Fach-, Quellen- und Warnzeilen in einer formatierten Menge, RAW sieben native Resultsets, TABLE nur die benannten ausgewählten Zielmengen, NONE keine fachlichen Resultsets. Die optionale JSON-Erzeugung bleibt unabhängig. |
| `@ResultTablesJson nvarchar(max)` | `NULL` | Bei TABLE ein JSON-Objekt mit mindestens einem Schlüssel-Ziel-Paar und Stringwerten. Alle zulässigen Schlüssel mit exakter Schreibweise: moduleStatus liefert den Gesamtstatus, endpoints die sichtbaren Endpoints, tcpEndpoints die TCP-Port-/IP-Konfiguration, mirroringEndpoints die Mirroringkonfiguration, connectionEncryptionSummary gruppierte Verbindungsflags, sourceStatus Quellenstatus und Zählwerte, warnings Hinweise und Grenzen. Jeder Schlüssel ist einzeln optional; doppelte Schlüssel werden abgelehnt. Ziele müssen vorhandene, leere lokale #Temp-Tabellen mit genau einer Seed-Spalte sein; höchstens 116 Zeichen, kein ## und kein reserviertes Präfix #Monitor (case-insensitiv). Doppelte Ziele werden case-insensitiv abgelehnt. Bei TABLE sind NULL, Leerstring und Leerzeichen ungültig; außerhalb TABLE sind nur NULL, Leerstring oder U+0020-Leerzeichen erlaubt. Die Vorprüfung erfolgt vor den Fachquellen; nacheinander geschriebene Mengen werden bei späterem Fehler nicht zurückgenommen. |
| `@JsonErzeugen bit` | `0` | 0 unterdrückt, 1 erzeugt meta und sieben Arrays: moduleStatus, endpoints, tcpEndpoints, mirroringEndpoints, connectionEncryptionSummary, sourceStatus, warnings. Bit-Konvertierung: Ein numerischer Wert ungleich 0 wird bei der bit-Konvertierung 1; NULL erzeugt nichts. |
| `@Json nvarchar(max) OUTPUT` | `NULL` | OUTPUT nvarchar(max), anfangs NULL. Bei @JsonErzeugen=1 normal meta (resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber, errorMessage) plus sieben Arrays, auch bei Quellenfehlern; sonst und im CATCH NULL. Empfang per nvarchar(max)-Variable OUTPUT. |
| `@PrintMeldungen bit` | `1` | 0 unterdrückt, 1 gibt RAISERROR-Meldungen niedriger Schwere bei Parameter-, Quellen- und äußeren Fehlern aus. Bit-Konvertierung: Ein numerischer Wert ungleich 0 wird bei der bit-Konvertierung 1; NULL wirkt 0. Hilfe-PRINTs sind unabhängig. |
| `@Hilfe bit` | `0` | Konvertierter Wert 1 gibt vor Prüfung/Zugriff die Hilfetexte aus, setzt Status AVAILABLE und Partial 0, dann vorzeitiges RETURN ohne ausdrücklich angegebenen Wert. NULL wirkt 0; Ein numerischer Wert ungleich 0 wird bei der bit-Konvertierung 1. Andere Outputs bleiben NULL. |
| `@StatusCodeOut varchar(40) OUTPUT` | `NULL` | Optionale OUTPUT-Bindung an eine varchar(40)-Variable; der Eingangswert wird auf NULL gesetzt. Alle möglichen Werte: AVAILABLE kennzeichnet den Hilfeabbruch ohne Analyse; INVALID_PARAMETER kennzeichnet ungültige Eingaben beziehungsweise den gespeicherten TABLE-Fehlercode 51011; AVAILABLE_LIMITED bezeichnet mindestens eine erfolgreiche nichtleere native Quelle; EMPTY_UNPROVEN mindestens eine erfolgreiche leere Quelle, sofern keine native Quelle nichtleer erfolgreich ist. Erst ohne erfolgreiche native Quelle wird der erste Fehler nach ENDPOINTS, TCP_ENDPOINTS, MIRRORING_ENDPOINTS, CONNECTIONS übernommen: DENIED_PERMISSION bedeutet einen als Berechtigungsfehler eingestuften Fehler (229, 297, 300, 371), TIMEOUT einen Sperrtimeout 1222 und ERROR_HANDLED einen sonstigen abgefangenen Fehler. Im äußeren CATCH gilt INVALID_PARAMETER bei gespeichertem TABLE-Fehlercode 51011, sonst ERROR_HANDLED. Reguläre Quellenfehler liefern weiterhin RETURN 0; Status und Fehler-OUTPUTs sind getrennt zu lesen. |
| `@IsPartialOut bit OUTPUT` | `NULL` | Optionale OUTPUT-Bindung an eine bit-Variable; der Eingangswert wird auf NULL gesetzt. Hilfe liefert 0, da keine Analyse ausgeführt wird. Parameterfehler, regulärer Bericht und äußerer CATCH liefern 1; eine normale Analyse bleibt wegen begrenzter Metadatensicht ausdrücklich partiell. 0 aus der Hilfe bestätigt keine vollständige Inventur. |
| `@ErrorNumberOut int OUTPUT` | `NULL` | OUTPUT int, anfangs NULL: Parameterfehler 51011; normal erster Quellenfehler nach ENDPOINTS, TCP_ENDPOINTS, MIRRORING_ENDPOINTS, CONNECTIONS, danach Ableitungsfehler. TABLE: Vorprüfung 51011, Writerfehler dessen Code oder 51010; CATCH Fehlercode. Empfang int-Variable OUTPUT. Im äußeren CATCH ist dieser Wert zugleich der Diagnose-RETURN-Wert; reguläre Quellenfehler ändern den normalen RETURN 0 nicht. Ohne erfassten Fehler bleibt der Wert NULL. |
| `@ErrorMessageOut nvarchar(2048) OUTPUT` | `NULL` | OUTPUT nvarchar(2048), anfangs NULL; erhält Validierungs-, priorisierten Quellen-/Ableitungs- oder CATCH-Text. Hilfe belässt NULL. Empfang nvarchar(2048)-Variable OUTPUT. |

### Kopierbare Aufrufbeispiele

Die Beispiele verwenden getrennte Aufrufe für RAW, Diagnose-JSON, einen TABLE-Teilexport und die Hilfe. Das TABLE-Ziel wird vor dem Aufruf mit einer Seed-Spalte angelegt und in beiden Abschlusswegen entfernt.

```sql
EXEC [monitor].[USP_EndpointTransportAnalysis] @MaxZeilen=200, @LockTimeoutMs=0, @ResultSetArt='RAW', @PrintMeldungen=0;
```

```sql
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_EndpointTransportAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
```

```sql
CREATE TABLE [#EndpointTransportAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_EndpointTransportAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=N'{"endpoints":"#EndpointTransportAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#EndpointTransportAnalysis_HelpExample]; DROP TABLE IF EXISTS [#EndpointTransportAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#EndpointTransportAnalysis_HelpExample]; THROW; END CATCH;
```

```sql
EXEC [monitor].[USP_EndpointTransportAnalysis] @Hilfe=1;
```

## Eine Zeile bedeutet

| Menge | Inhalt und Zähleinheit |
|---|---|
| moduleStatus | Gesamtstatus und Summe der vier ausgegebenen Fachmengen; keine Zahl unterschiedlicher Endpoints oder Verbindungen. |
| endpoints | Sichtbare native Endpointidentität, Owner-ID, Protokoll, Typ, Zustand und Adminflag. |
| tcpEndpoints | Native Endpoint-ID und Name mit Katalogport, Dynamic-Port-Flag und LISTENER_IP. |
| mirroringEndpoints | Native Authentifizierungs-, Zertifikats-ID-, Algorithmus-, Rollen- und Verschlüsselungskonfiguration. |
| connectionEncryptionSummary | Gruppen aus EndpointId, NetTransport, ProtocolType, EncryptOption und AuthenticationScheme mit nativer ConnectionRows-Summe. |
| sourceStatus | Vier NATIVE-Quellen und eine DERIVED-Zusammenfassung mit Zeit, Sichtbarkeitsgrenze, Counts und unveränderten nativen Fehlerdetails. |
| warnings | Leere Quellen, Ausgabelimits, Quellenfehler und dauerhafte Aussagegrenzen. |

ConnectionRows zählt DMV-Zeilen einschließlich zusätzlicher logischer
MARS-Zeilen mit NetTransport=Session. Es ist weder die Anzahl physischer
Kanäle noch unterschiedlicher Clients. Die native CONNECTIONS-Quelle zählt
CONNECTION_ROW und besitzt ReturnedRows=NULL, weil keine Rohverbindungsliste
ausgegeben wird. Die abgeleitete Quelle zählt SUMMARY_GROUP. Aggregation
allein setzt IsLimited nicht; erst ein tatsächliches Ausgabelimit tut dies.
Die drei Katalogquellen zählen CATALOG_ROW.

EndpointContextStatus unterscheidet ENDPOINT_ID_NULL,
ENDPOINT_SOURCE_UNAVAILABLE, MATCHED_VISIBLE_ENDPOINT und
NO_VISIBLE_ENDPOINT_MATCH. Der Name stammt aus der vollständigen sichtbaren
Endpointaufnahme vor deren Ausgabelimit. Eine fehlende sichtbare Nachbarzeile
löscht keine Verbindung. EncryptionEvidence lautet bei nativem ProtocolType
Database Mirroring oder sichtbarem EndpointType 4 HADR_FLAG_NOT_APPLICABLE,
bei TSQL TSQL_FLAG_ONLY und sonst NATIVE_FLAG_UNQUALIFIED. Fehlende Metadaten
werden nicht durch eine geratene Protokollklassifikation ersetzt.

Mindestens eine erfolgreiche nichtleere native Quelle ergibt insgesamt
AVAILABLE_LIMITED und IsPartial=1. Wenn keine native Quelle nichtleer verfügbar
ist, ergibt mindestens eine erfolgreiche leere Quelle EMPTY_UNPROVEN; erst wenn
keine Quelle leer oder nichtleer erfolgreich ist, übernimmt der erste native
Fehler in der Reihenfolge ENDPOINTS, TCP_ENDPOINTS, MIRRORING_ENDPOINTS,
CONNECTIONS den Gesamtstatus. Die abgeleitete Zeile verdeckt diesen
Fehler nicht. sourceStatus enthält auch erfolgreich leere Quellen ausdrücklich;
eine leere Sicht beweist keine instanzweite Abwesenheit.

Quellenfehler behalten unbekannte Counts. Die abhängige Zusammenfassung ist
bei fehlgeschlagener CONNECTIONS-Quelle SOURCE_UNAVAILABLE; andere Quellen
bleiben auswertbar. Ein eigener Ableitungsfehler besitzt ERROR_HANDLED mit
nativen Fehlerdetails. Error-OUTPUT nennt den ersten Fehler nach ENDPOINTS, TCP_ENDPOINTS,
MIRRORING_ENDPOINTS, CONNECTIONS und danach einen Ableitungsfehler. Fachliche
Quellenfehler liefern den materialisierten Bericht mit RETURN 0. Ungültige
Parameter und TABLE-Vorprüfungsfehler liefern INVALID_PARAMETER, RETURN 51011
und JSON-NULL. Ein TABLE-Writerfehler setzt ErrorNumberOut und RETURN auf den gespeicherten
Writerfehler (Fallback 51010), StatusCodeOut auf ERROR_HANDLED und Json auf NULL; andere gefangene
äußere Fehler liefern ebenfalls Diagnose-RETURN und JSON-NULL. Status, Error-OUTPUT, sourceStatus und warnings sind gemeinsam
zu lesen. Ein Engine- oder Verbindungsabbruch erhält keine erfundene
Wiederherstellungsgarantie.

## So lesen

Lesen Sie zuerst moduleStatus und sourceStatus, danach die Endpoints und
ihre Detailmengen. Vergleichen Sie EncryptionEvidence mit ProtocolType,
bevor Sie einen nativen Verschlüsselungswert interpretieren. warnings hält
Limits, leere Quellen und dauerhafte Aussagegrenzen sichtbar.

## Warum kann das problematisch sein?

Eine fehlgeschlagene Verbindungsquelle lässt einen Konfigurationsbericht
ohne beobachtete Verbindungsflags übrig. Ein unqualifiziertes FALSE kann
bei HADR zu einem falschen Sicherheitsbefund führen; ein TRUE ersetzt keine
Zertifikats- oder Treiberprüfung.

## Wann ist es kein Problem?

Ein leerer Mirroringkatalog kann zur sichtbaren Instanz passen. Der Bericht
bewertet dies als leere Metadatensicht und verlangt ohne zusätzliche Frage
keine Konfigurationsänderung. Fehlende externe Evidenz ist ausdrücklich
kein automatisch erkannter Defekt.

## Stabiler Feldvertrag

Die sieben Schemas besitzen SchemaVersion 1. Textfelder verwenden
SQL_Latin1_General_CP1_CS_AS. Die Endpoint-IP wird verlustfrei als nvarchar(45)
ausgegeben, auch wenn die Enginequelle varchar(45) liefert.

```sql
CREATE TABLE #Example_moduleStatus
(
    [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsPartial] bit NOT NULL,
    [RowCount] bigint NOT NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
CREATE TABLE #Example_endpoints
(
    [EndpointId] int NOT NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [PrincipalId] int NULL,
    [Protocol] tinyint NOT NULL,
    [ProtocolDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EndpointType] tinyint NOT NULL,
    [EndpointTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EndpointState] tinyint NULL,
    [EndpointStateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [IsAdminEndpoint] bit NOT NULL
);
CREATE TABLE #Example_tcpEndpoints
(
    [EndpointId] int NOT NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [Port] int NOT NULL,
    [IsDynamicPort] bit NOT NULL,
    [IpAddress] nvarchar(45) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE #Example_mirroringEndpoints
(
    [EndpointId] int NOT NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [MirroringRole] tinyint NULL,
    [MirroringRoleDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [IsEncryptionEnabled] bit NOT NULL,
    [ConnectionAuthentication] tinyint NOT NULL,
    [ConnectionAuthenticationDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [CertificateId] int NOT NULL,
    [EncryptionAlgorithm] tinyint NOT NULL,
    [EncryptionAlgorithmDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE #Example_connectionEncryptionSummary
(
    [EndpointId] int NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EndpointType] tinyint NULL,
    [NetTransport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ProtocolType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EncryptOption] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [AuthenticationScheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ConnectionRows] bigint NOT NULL,
    [EndpointContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [EncryptionEvidence] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
CREATE TABLE #Example_sourceStatus
(
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [RowUnit] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [StartedAtUtc] datetime2(3) NOT NULL,
    [CompletedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ObservedRows] bigint NULL,
    [ReturnedRows] bigint NULL,
    [IsLimited] bit NOT NULL,
    [ErrorNumber] int NULL,
    [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE #Example_warnings
(
    [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
```

## Gegenprüfung und nächste Schritte

Vergleichen Sie native Quellzeilen im selben Caller-Kontext und beachten Sie
den Zeitabstand zwischen Aufrufen. Für Zertifikatsvertrauen, tatsächliche
TLS-Version, Cipher oder externe Erreichbarkeit ist ein eigener autorisierter
Host-/Treiber-/Verbindungsnachweis erforderlich. Die Procedure führt solche
Proben nicht aus. Weitere Einstiege stehen im [Analysis Navigator](../../Reference/Analysis_Navigator.md).

Microsoft-Referenzen: [Endpoints](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-endpoints-transact-sql), [TCP-Endpoints](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-tcp-endpoints-transact-sql), [Mirroring-Endpoints](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-mirroring-endpoints-transact-sql) und [Verbindungs-DMV](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-connections-transact-sql).

## Technische Vertiefung

### Leitfrage

Welche sichtbare Endpointkonfiguration und welche nativen Verbindungsflags
liegen im aktiven Kontext zum Zeitpunkt der getrennten Quellenaufnahme vor?

### Technischer Hintergrund

Die vier Quellen besitzen getrennte Berechtigungs- und Fehlergrenzen.
Verschlüsselungskonfiguration und beobachtetes Flag bleiben getrennte
Evidenz; keine Quelle beweist Zertifikatsvertrauen oder ausgehandelte TLSdetails.

### Datenkette

Vier native Caches entstehen vor der Ableitung. Die Verbindungsquelle wird
nach ihren fünf nativen Dimensionen gruppiert und danach mit dem vollständigen
Endpointcache verbunden. Erst danach greifen die vier Ausgabelimits.

### Source Select

**Wichtig für die Eigenlast:** Die serverweiten Quellen werden getrennt gelesen; die folgenden Projektionen
zeigen die benötigten Felder. Die Implementierung materialisiert sie im
Caller-Kontext mit dem konfigurierten Locktimeout. Einzelne Lesefehler
verwerfen nur ihren Quellencache.

```sql
SELECT [endpoint_id],[name],[principal_id],[protocol],[protocol_desc],
       [type],[type_desc],[state],[state_desc],[is_admin_endpoint]
FROM [sys].[endpoints] WITH (NOLOCK);
SELECT [endpoint_id],[name],[port],[is_dynamic_port],[ip_address]
FROM [sys].[tcp_endpoints] WITH (NOLOCK);
SELECT [endpoint_id],[name],[role],[role_desc],[is_encryption_enabled],
       [connection_auth],[connection_auth_desc],[certificate_id],
       [encryption_algorithm],[encryption_algorithm_desc]
FROM [sys].[database_mirroring_endpoints] WITH (NOLOCK);
SELECT [endpoint_id],[net_transport],[protocol_type],[encrypt_option],[auth_scheme]
FROM [sys].[dm_exec_connections] WITH (NOLOCK);
```

### Zeit- und Scope-Modell

Die Aufnahmen sind serverweit, kurzlebig und nicht atomar. Quellenzeiten und
modulweiter UTC-Zeitpunkt bezeichnen denselben Aufruf, aber keine garantierte
Gleichzeitigkeit. Die Procedure schreibt keine Snapshots oder Historie.

### Bewertung und Gegenprobe

Native Katalogprojektionen erlauben einen Vergleich im selben Caller-Kontext.
Die eigene aktuelle Verbindung kann ihre Gruppenzuordnung bestätigen;
zwischenzeitliche andere Verbindungen können Zählwerte verändern. Für
TLSversion und Zertifikatsvertrauen ist eine getrennte Verbindungsprobe nötig.

### Typische Fehlinterpretation

Eine Gruppe ist kein einzelner Client. Ein HADR-FALSE ist kein Negativbeweis.
Eine Zertifikats-ID beweist weder Verfügbarkeit des privaten Schlüssels noch
Vertrauen eines externen Clients.

### Folgeanalyse

Nutzen Sie die native Endpointkonfiguration zur gezielten Gegenprüfung.
Trennen Sie Datenverschlüsselung und Transport über EncryptionAnalysis und
prüfen Sie Host-, Treiber- und Zertifikatsfragen in einem eigenen autorisierten
Scope. Der Bericht erzeugt keine automatische Korrektur oder DDL.

[Technische Detailbeschreibung](../../Reference/Procedure_Reference.md#monitorusp_endpointtransportanalysis)
[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

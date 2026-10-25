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

CONSOLE verwendet den gemeinsamen Renderer und enthält Fachzeilen,
Quellenzustände und Warnungen in einer formatierten Menge. RAW liefert die
sieben nachfolgend benannten nativen Schemas in der angegebenen Reihenfolge.
NONE unterdrückt fachliche Resultsets; optionales JSON bleibt über den
OUTPUT-Parameter verfügbar. JSON besitzt SchemaVersion 1 und die sieben
benannten Arrays neben meta. Alle Ausgabearten verwenden dieselbe
Materialisierung innerhalb eines Aufrufs.

```sql
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int;
EXEC [monitor].[USP_EndpointTransportAnalysis]
    @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT,
    @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT,
    @ErrorNumberOut=@Error OUTPUT, @PrintMeldungen=0;
SELECT @Status AS [StatusCode], @Partial AS [IsPartial],
       @Error AS [ErrorNumber], @Json AS [DiagnosticJson];
```

TABLE verwendet ausschließlich ResultTablesJson mit benannten lokalen
Temp-Tabellen. Unbekannte Namen, doppelte Ziele und ungültige Zuordnungen
werden vor Fachzugriff abgelehnt; die Zielfelder werden entsprechend dem
[gemeinsamen TABLE-Vertrag](../../Architecture/Output_RAW_CONSOLE_JSON.md) geprüft.
MaxZeilen ist standardmäßig 1000, 0 oder NULL bedeutet unbegrenzt; negative
Werte sind ungültig. Jedes der vier Fachresultsets erhält sein eigenes Limit.
moduleStatus, sourceStatus und warnings bleiben ungekürzt.

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
AVAILABLE_LIMITED und IsPartial=1. Nur erfolgreiche leere native Quellen
ergeben EMPTY_UNPROVEN. Bei vier fehlgeschlagenen nativen Quellen gilt der
erste konkrete Fehler in der Reihenfolge ENDPOINTS, TCP_ENDPOINTS,
MIRRORING_ENDPOINTS, CONNECTIONS. Die abgeleitete Zeile verdeckt diesen
Fehler nicht. sourceStatus enthält auch erfolgreich leere Quellen ausdrücklich;
eine leere Sicht beweist keine instanzweite Abwesenheit.

Quellenfehler behalten unbekannte Counts. Die abhängige Zusammenfassung ist
bei fehlgeschlagener CONNECTIONS-Quelle SOURCE_UNAVAILABLE; andere Quellen
bleiben auswertbar. Ein eigener Ableitungsfehler besitzt ERROR_HANDLED mit
nativen Fehlerdetails. Error-OUTPUT nennt den ersten Fehler in der genannten
Quellenreihenfolge, danach einen eigenen Ableitungsfehler. Fachliche
Quellenfehler liefern den materialisierten Bericht mit RETURN 0. Erwartete
API-/TABLE-Ablehnungen und gefangene äußere Fehler liefern Diagnose-RETURN
und JSON-NULL. Status, Error-OUTPUT, sourceStatus und warnings sind gemeinsam
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

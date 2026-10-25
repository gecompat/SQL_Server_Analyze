# SQL-sichtbare Endpoints und Transportverschlüsselung

**Stand:** 25. Oktober 2026.
**Status:** erste Produktimplementierung und unabhängiger Produktreview bestehen; lokale SQL2025-Fixture besteht. Gebundene Liefergates bleiben offen.
**Artefakt-UID:** `urn:uuid:01a172d8-177b-70e6-81a8-a09b4120e159`.
**Registrierung:** `DEFERRED`; keine finale lesbare Arbeitselementkennung vergeben.
**Intake:** TLS_NETWORK_ENDPOINTS, Rang 7 der
[Entwicklungswellen](../Quality/Development_Waves_2026-10.md).

## Diagnosefrage und bestehende Abdeckung

Die nächste Grundlieferung soll sichtbare Engineendpoints, deren native
TCP- und Mirroringkonfiguration und beobachtete Verschlüsselungsflags
bestehender Verbindungen gemeinsam lesbar machen. Vorgeschlagen wird
monitor.USP_EndpointTransportAnalysis. Die vorhandene EncryptionAnalysis
betrifft TDE, Backupverschlüsselung und Always Encrypted. Die Sicherheits-
konfiguration und HADR-Berichte liefern nur einzelne angrenzende Befunde;
sie werden durch diese Welle nicht neu implementiert.

Die ersten drei SQL-sichtbaren Sicherheitsbausteine von Rang 6 sind über die
[Principal-Dossiers](Database_Principal_Analysis_Dossier.md) und das
[Callerrechte-Dossier](Caller_Permission_Analysis_Dossier.md) geliefert.
Objekt-/Spalten-/Statementrechte, fremde Principals und externe Identitäten
bleiben getrennte offene Teile. Als nächste vertikale Grundlieferung folgt
nun der bisher nicht eigenständig umgesetzte Transport-Intake von Rang 7.
Dies ist kein pauschaler Abschluss der gesamten Sicherheitsdiagnostik.

## Ausdrückliche Enginegrenze

Die erste Welle liest ausschließlich SQL-sichtbare Metadaten. Sie liest
keine Registry, mssql.conf, Zertifikatsdateien, privaten Schlüssel,
Credentialinhalte, Passwortwerte oder Directorydaten. Sie ändert keine
Endpoints, Netzwerkprotokolle, Berechtigungen oder Verschlüsselungsoptionen
und öffnet keine zusätzlichen Verbindungen zu lokalen oder fremden Zielen.
Ein Hostadapter und echte TLS-/Zertifikats-Verbindungsproben benötigen
später einen eigenen begrenzten Vertrag.

Ein nativer encrypt_option-Wert ist kein Beweis einer bestimmten TLS-Version,
eines Ciphers, einer vertrauenswürdigen Zertifikatskette, einer Hostnamenprüfung,
von Extended Protection oder einer sicheren Treiberkonfiguration. protocol_version
beschreibt das Datenzugriffsprotokoll und wird nicht als TLS-Version interpretiert.
TLS 1.3, TDS 8, Force Encryption und Strict Encryption werden aus diesen Quellen
nicht geraten. Fehlende externe Evidenz wird ausdrücklich sichtbar gehalten.

Für HADR-Mirroringverbindungen liefert dm_exec_connections.encrypt_option
laut Microsoft immer FALSE. Dieser Wert darf dort nicht als Nachweis
unverschlüsselten Transports gewertet werden. Die getrennte
Mirroringendpoint-Konfiguration zeigt nur ihre native Konfiguration;
sie beweist keinen konkreten ausgehandelten Cipher einer Verbindung.

TCP-Katalogports und LISTENER_IP-Werte können von der tatsächlichen
Protokollkonfiguration abweichen. Ein STARTED-, STOPPED- oder DISABLED-Befund
beschreibt den nativen Endpointzustand und keine externe Erreichbarkeitsprobe.
Der erste Bericht stellt kein allgemeines IsSecure-/IsHealthy-Urteil her.

## Quellen und Auswahl

Der Bericht besitzt SERVER-Scope. Der feste Datenbankauswahlvertrag ist für
seine serverweiten Quellen nicht erforderlich; eine künstliche CURRENT-
Datenbankauswahl wird nicht eingeführt.

Die vier getrennten Quellen sind sys.endpoints, sys.tcp_endpoints,
sys.database_mirroring_endpoints und sys.dm_exec_connections. Native IDs
bleiben auch bei fehlender sichtbarer Nachbarmetadatenzeile erhalten.
Verknüpfungen verwenden sichtbare vollständige Caches vor jedem Ausgabelimit.
Ein Quellenfehler wird unabhängig von anderen Quellen dokumentiert.

Die Kataloge unterliegen Metadatensichtbarkeit. Ab SQL2022 nennen die
Endpointkataloge VIEW SERVER SECURITY STATE. Die Verbindungs-DMV benötigt
auf SQL2019 VIEW SERVER STATE und ab SQL2022 VIEW SERVER PERFORMANCE STATE.
Diese Unterschiede sind konkrete Abnahmefragen; der Bericht gewährt keine
Rechte. Leere oder eingeschränkte Sicht ist kein Abwesenheitsnachweis.

Die Verbindungsquelle liest nur die zur Zusammenfassung erforderlichen
nativen Dimensionen, insbesondere endpoint_id, net_transport, protocol_type,
encrypt_option und auth_scheme. Sie liefert gruppierte ConnectionRows statt
einer einzelnen Verbindungsliste. MARS kann zusätzliche logische Zeilen mit
net_transport=Session erzeugen. ConnectionRows bedeutet deshalb weder eine
Anzahl physischer Kanäle noch eine Zahl unterschiedlicher Clients.
Native Verschlüsselungswerte werden unverändert übernommen. HADR-Gruppen
erhalten eine eigene Aussagegrenze, statt FALSE in einen Sicherheitsfehler
umzudeuten. Die Endpointnamen und benötigten nativen Katalogwerte bleiben in
der Laufzeitausgabe erhalten; versionierte Beispiele sind synthetisch.

## Vorgesehene API und Ausgabe

Die gemeinsame API übernimmt @MaxZeilen int=1000, @LockTimeoutMs int=0,
@ResultSetArt varchar(16)='CONSOLE', @ResultTablesJson nvarchar(max)=NULL,
@JsonErzeugen bit=0, @Json nvarchar(max)=NULL OUTPUT, @PrintMeldungen bit=1,
@Hilfe bit=0 und die vier Status-/Fehler-OUTPUT-Parameter. MaxZeilen 0 oder
NULL ist unbegrenzt; negative Werte werden abgelehnt. LockTimeoutMs akzeptiert
0 bis 60000 und steht im jeweiligen Quellenbatch. Eigene temporäre DDL
besitzt ihren getrennten begrenzten Schutz.

Vorgesehen sind sieben benannte Mengen: moduleStatus, endpoints,
tcpEndpoints, mirroringEndpoints, connectionEncryptionSummary, sourceStatus
und warnings. Die vier fachlichen Mengen erhalten getrennte abschließende
Ausgabelimits. Kontext-, Quellen- und Warnzeilen werden dadurch nicht gekürzt.
Der genaue Feldvertrag ist nachfolgend festgelegt und vor Implementierung
unabhängig geprüft; native Schemaproben konkretisieren seine Quellfacetten.

NATIVE kennzeichnet Katalog- oder DMV-Aufnahme, DERIVED die gruppierte
Zusammenfassung. Die native DMV-Zeilenmenge und die abgeleitete Gruppenzahl
werden als unterschiedliche Einheiten behandelt: Die native Quelle besitzt
ObservedRows und mangels Rohresultset keine erfundene ReturnedRows-Menge;
die abgeleitete Quelle besitzt beobachtete und ausgegebene Gruppen. Eine
Aggregation allein ist kein Ausgabelimit.

RAW, TABLE, NONE und optionales JSON verwenden dieselbe Materialisierung.
CONSOLE verwendet den gemeinsamen Renderer und zeigt Quellenprobleme und
Warnungen auch neben erfolgreichen Fachzeilen. TABLE besitzt ausschließlich
die gemeinsame benannte Mehrfachzuordnung mit Vorprüfung vor Fachzugriff.

Ein erfolgreicher begrenzter Befund bleibt AVAILABLE_LIMITED mit IsPartial=1.
Bei ausschließlich fehlgeschlagenen Quellen verdecken benachbarte Metadaten
den konkreten Fehler nicht. Für fehlgeschlagene Mengen bleiben Counts
unbekannt. Fachliche Quellenfehler kehren mit einem materialisierten Bericht
und RETURN 0 zurück; Status, Error-OUTPUT und Quellenzeilen sind zu prüfen.
Erwartete API-/TABLE-Ablehnungen und gefangene äußere Fehler liefern dagegen
Diagnose-RETURN und JSON-NULL. Native Meldungen bleiben diagnostisch vollständig.
Die Procedure übernimmt weder Commit noch Rollback einer Callertransaktion.

## Typisierter Vorvertrag und Statusbildung

Die sieben Mengen erhalten SchemaVersion 1 in dieser RAW-Reihenfolge.
Alle Textspalten verwenden explizit SQL_Latin1_General_CP1_CS_AS. Die
folgenden Schemas sind vor Implementierung festgelegt; der Laufzeittest
übernimmt die geprüften Sollschemas und beschreibt sie nicht aus der SUT.

```sql
CREATE TABLE #Contract_moduleStatus
(
    [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsPartial] bit NOT NULL,
    [RowCount] bigint NOT NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
CREATE TABLE #Contract_endpoints
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
CREATE TABLE #Contract_tcpEndpoints
(
    [EndpointId] int NOT NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [Port] int NOT NULL,
    [IsDynamicPort] bit NOT NULL,
    [IpAddress] nvarchar(45) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE #Contract_mirroringEndpoints
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
CREATE TABLE #Contract_connectionEncryptionSummary
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
CREATE TABLE #Contract_sourceStatus
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
CREATE TABLE #Contract_warnings
(
    [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
```

Die vorbereitende native SQL2025-Schemaprobe bestätigt diese nativen
Datentypen und Nullfähigkeiten. tcp_endpoints.ip_address liegt dort als
nullable varchar(45) vor; die Ausgabe erweitert verlustfrei auf nvarchar(45).
Eine Microsoft-Referenz nennt nvarchar(45); die unterschiedliche Quelle wird
nicht als identische native Typisierung ausgegeben. Die Probe endete bewusst
mit Diagnosecode 57292, um den privaten Facettenbeleg auszugeben. Sie ist
keine bestandene Produktabnahme; die eigene Instanz und ihr Volume wurden
anschließend entfernt. Positive Mirroring- oder Verbindungswerte wurden
dabei nicht qualifiziert.

Es gibt die vier NATIVE-Quellenschlüssel ENDPOINTS, TCP_ENDPOINTS,
MIRRORING_ENDPOINTS und CONNECTIONS sowie den DERIVED-Schlüssel
CONNECTION_ENCRYPTION_SUMMARY. Die ersten drei zählen CATALOG_ROW,
CONNECTIONS zählt CONNECTION_ROW und die Ableitung SUMMARY_GROUP.
Leere erfolgreich gelesene Quellen erhalten EMPTY_UNPROVEN; nichtleere
native Quellen AVAILABLE_LIMITED. Die native Verbindungsquelle besitzt
ReturnedRows=NULL und IsLimited=0. Die Ableitung bildet alle Gruppen aus
ihrem vollständigen Cache und aktualisiert erst nach dem eigenen Ausgabelimit
ReturnedRows und IsLimited. Ohne verfügbare Verbindungsquelle erhält sie
SOURCE_UNAVAILABLE mit unbekannten Counts; der native Fehler bleibt bei
CONNECTIONS erhalten. Ein eigener Ableitungsfehler erhält ERROR_HANDLED
und seinen nativen Diagnosefehler.

Die Namen und Typen einer Verbindungsgruppe stammen aus der vollständigen
Endpointaufnahme. EndpointContextStatus unterscheidet ENDPOINT_ID_NULL,
ENDPOINT_SOURCE_UNAVAILABLE, MATCHED_VISIBLE_ENDPOINT und
NO_VISIBLE_ENDPOINT_MATCH. Ein fehlender sichtbarer Nachbar löscht keine
Verbindungsgruppe. Die getrennten Quellen sind keine atomare Topologie-
Momentaufnahme. Eine HADR-Kennung folgt nur aus dem nativen ProtocolType
Database Mirroring oder dem sichtbaren EndpointType 4. EncryptionEvidence
lautet dann HADR_FLAG_NOT_APPLICABLE. Für das native TSQL-Protokoll lautet
sie TSQL_FLAG_ONLY; sonst NATIVE_FLAG_UNQUALIFIED. Unbekannte Endpoints
oder Protokolle erhalten keine geratene Verschlüsselungsbewertung.

Mindestens eine erfolgreiche nichtleere native Quelle begründet insgesamt
AVAILABLE_LIMITED. Sind nur erfolgreiche leere native Quellen verfügbar,
lautet der Gesamtstatus EMPTY_UNPROVEN. Bei vier fehlgeschlagenen nativen
Quellen wird der erste native Fehlerstatus in der genannten Quellenreihenfolge
übernommen; eine Ableitungszeile verdeckt ihn nicht. Error-OUTPUT nennt den
ersten vorhandenen Fehler in derselben Reihenfolge, danach einen eigenen
Ableitungsfehler. IsPartial bleibt 1. RowCount ist die Summe der vier
zurückgegebenen Fachmengen; es ist keine Zahl unterschiedlicher Endpoints
oder physischer Verbindungen. Alle sourceStatus-Zeilen und Warnungen bleiben
ungekürzt. MaxZeilen begrenzt keine Aufnahme- oder Aggregationsarbeit.

Die Abnahme verwendet keine neu erstellten TSQL-Endpunkte: Deren mögliche
Seiteneffekte auf bestehende Default-Endpointrechte passen nicht zum
Fixturevertrag. Ein positiver Mirroring-Katalogfall entsteht nur auf einer eigenen isolierten
sysadmin-Testinstanz ohne Ambienttransaktion. Die frühere Anordnungsprobe
mit DISABLED wurde mit 7871 abgelehnt. Ein STOPPED-Endpoint mit nur
passwortgeschütztem Zertifikat wurde mit 28055 abgelehnt: Der private
Schlüssel muss durch den Datenbank-Master-Key geschützt sein. Beide
Fehlläufe sind bereinigt und keine positive Produktabnahme.

Die geprüfte Fixturegrenze verwendet einen eigenen STOPPED-Mirroringendpoint
mit Zertifikatauthentifizierung und einem freien Katalogport aus 32700 bis
32767. Ein bestehender Endpoint oder Master-Key wird weder ersetzt, geöffnet
noch geändert. Falls master keinen DMK besitzt, wird ausschließlich in der
eigenen Labinstanz ein eigener Schlüssel mit flüchtigem Kennwort erzeugt und
sofort an key_guid, symmetric_key_id und create_date gebunden. Ein eigenes
Zertifikat nutzt den DMK und wird sofort an certificate_id, Name und Thumbprint
gebunden. Der Endpoint wird vor nachfolgenden Änderungen an ID, Name,
principal_id und Typ 4 gebunden.

Bestandssnapshots umfassen Endpoints, Endpointrechte, master-Schlüssel,
Zertifikate, asymmetrische Schlüssel und datenbankbezogene Credentials.
Nach Arrange und Cleanup müssen die vorbestehenden Werte unverändert sein.
Cleanup versucht gebundenen Endpoint, eigenes Zertifikat und gegebenenfalls
eigenen DMK getrennt auch nach einem Primärfehler. Vor dem DMK-DROP werden
neue fremde Abhängigkeiten gegenüber der Baseline ausgeschlossen; eine
abweichende Bindung oder neue Abhängigkeit erzeugt Recoverybedarf statt
eines ungebundenen DROP. Der äußere Cleanup bleibt auf das eigene Lab gebunden.
Alle Endpoint-DDL liegt außerhalb einer Usertransaktion. Der Bericht wird
zusätzlich in einer committable Ambienttransaktion geprüft. Die Fixture setzt
keinen Endpoint auf STARTED, öffnet keinen Port im Provider oder Host und
erzeugt keinen externen Handshake. STOPPED wird nicht als pauschales Versprechen
eines fehlenden Listeners interpretiert. Die engere Anordnungsgrenze wurde
unabhängig geprüft. Vertrag 138 bestätigt ihren positiven Katalogfall
und Cleanup auf der eigenen SQL2025-Instanz; ein Handshake ist damit nicht belegt.

## Unabhängige Abnahme und Liefergrenze

Die Fixture benötigt eigene synthetische Endpoints, sofern die native Engine
deren zulässige Erstellung unterstützt. Erstellung, unmittelbare ID-/Name-/
Owner-/Typbindung und spätere Änderungen werden getrennt behandelt. Eine
Berechtigung oder Zustandsänderung an bestehenden Endpoints ist ausgeschlossen.
Cleanup prüft die erfassten nativen Bindungen und löscht keinen unbekannten
Ersatz. Eigene Principals werden unmittelbar vor nachfolgenden Grants gebunden.

Unabhängige native Sollwerte und typisierte Schemas prüfen die Endpointmengen,
Gruppen und Einheiten. Kontrollierte Sichtbarkeit beziehungsweise reale
Berechtigungsfehler, native Leerquellen, Limits ohne verfälschte Verknüpfungen,
JSON-Parität und CONSOLE-Teilfehler gehören zur Abnahme. SQL2025 bleibt die
primäre Engine; die konkrete Grenze der Endpoint-/DMV-Berechtigungen verlangt
einen gezielten älteren nativen Gegenlauf gemäß
[CI-Teststrategie](../../../Documentation/Quality/CI_Test_Strategy.md).
Compatibility Levels ersetzen keinen nativen Versionsnachweis.

Calleroptionen, reguläre Fehler-OUTPUTs, committable Ambienttransaktion und
unabhängige Sentinels werden erhalten. Erfolg und Fehlerabschluss bereinigen
eigene Ressourcen; fremde Endpoints, Rechte und bestehende Hostkonfiguration
bleiben außerhalb der Fixture. Nicht verfügbare positive HADR-, Host- oder
Handshakefälle werden als offene Abnahme erhalten und nicht aus einem leeren
Linux-Katalog als bestanden ausgegeben.

Zur Lieferung gehören Einzelquelle, Installer, Navigator, Inventare,
öffentlicher Lesepfad und die betroffenen Tests gemeinsam. Ein erster
Katalog-/Flag-Slice begründet keinen vollständigen TLS- oder Reifeabschluss.

## Lokale Entwicklung und offene Liefergates

Die erste Implementierung liegt als USP_EndpointTransportAnalysis mit
zwölf Parametern und sieben benannten Mengen vor. Vertrag 138 verwendet
sieben vorab festgelegte native Sollschemas, drei direkte Katalogprojektionen
und die unabhängig gelesene eigene Verbindungsgruppe. Vier TABLE-/JSON-Fälle
prüfen unbegrenzte und begrenzte Ausgabe, volle Caches vor Limits sowie den
Caller mit und ohne committable Ambienttransaktion. Die positive eigene
Mirroringkonfiguration, eingeschränkte DMV-Sicht, echte SELECT-Denials,
partielle CONSOLE-Evidenz und vier gleichzeitig fehlgeschlagene native Quellen
bestehen im lokalen SQL2025-Lauf bei abweichenden Instanz-/Frameworkcollations.
SQL-seitiger Cleanup und die Entfernung der eigenen Instanz samt Volume bestehen.

Frühere Entwicklungsversuche sind keine bestandene Abnahme: Die variable
LOCK_TIMEOUT-Syntax wurde korrigiert; eine explizite Kollation behebt einen
Temp-Procedure-Ausdruckskonflikt. Eine Testannahme verlangte ohne Ambient
XACT_STATE=0, obwohl nativ bei TRANCOUNT=0 im Prüfausdruck 1 beobachtet wurde.
Das geprüfte Oracle verlangt jetzt unveränderten TRANCOUNT und zusätzlich
keine native Benutzertransaktion; Ambientfälle verlangen weiterhin
XACT_STATE=1 und unabhängige Sentinelwerte. Ein weiterer Cast-basierter
JSON-null-Prüfausdruck widersprach dem tatsächlich ausgegebenen Payload.
Die strengere Prüfung verlangt das vorhandene EndpointName-Mitglied mit
JSON-Typ 0 in derselben korrekt gebundenen Gruppe. Die Ursachen dieser beiden
Oraclebeobachtungen werden nicht aus dem späteren Erfolg geraten.

Vorvertrag, Fixturegrenze, Produkt und die konkreten Oracle-/Timeoutdeltas
sind unabhängig geprüft. Die statische Suite meldete zunächst nur den
fehlenden äußeren nichtblockierenden Timeoutmarker und einen mit dem falschen
Builder erzeugten OPS-Installer. Der Produktmarker und der zuständige
Adapterbuilder sind korrigiert; die betroffenen Prüfungen bestehen.
Die übrigen erfolgreichen unveränderten statischen Gates werden nicht
allein wegen dieser Korrekturen wiederholt.

Der lokale Entwicklungsnachweis ersetzt noch keinen commitgebundenen
PR-Nachweis. Der zentrale Installer verlangt das vollständige SQL2025-Gate.
Die ältere native SQL2019-Berechtigungsgrenze wird gezielt separat geprüft;
SQL2025 deckt den verwendeten 2022+-Berechtigungszweig ab. Ein separater
SQL2022-Lauf, echte HADR-/MARS-Verbindungen, Host-/Handshakequalifikation
und eine vollständige separate RAW-Streamzählung bleiben unbelegt.

## Primärquellen

- Microsoft Learn: [sys.endpoints](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-endpoints-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [sys.tcp_endpoints](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-tcp-endpoints-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [sys.database_mirroring_endpoints](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-mirroring-endpoints-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [sys.dm_exec_connections](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-connections-transact-sql?view=sql-server-ver17).

- Microsoft Learn: [CREATE ENDPOINT](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-endpoint-transact-sql).
- Microsoft Learn: [Availability Groups unter Linux](https://learn.microsoft.com/en-us/sql/linux/high-availability/availability-groups-configure?view=sql-server-linux-ver17).

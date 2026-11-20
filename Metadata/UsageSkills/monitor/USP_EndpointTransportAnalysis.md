---
skill_format_version: "1.0.0"
name: "monitor.USP_EndpointTransportAnalysis"
schema_name: "monitor"
object_name: "USP_EndpointTransportAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure zeigt sichtbare Engineendpoints, TCP-/Mirroringkonfiguration und gruppierte native Verschlüsselungsflags bestehender Verbindungen."
source_path: "Code/08_ServerHealth/290_USP_EndpointTransportAnalysis.sql"
---

# monitor.USP_EndpointTransportAnalysis

## Zweck und Einsatz

Die Procedure zeigt sichtbare Engineendpoints, TCP-/Mirroringkonfiguration und gruppierte native Verschlüsselungsflags bestehender Verbindungen.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_EndpointTransportAnalysis]. Die Quelle nennt insbesondere `sys.endpoints`, `sys.tcp_endpoints`, `sys.database_mirroring_endpoints`, `[monitor].[InternalPrepareResultTables]`, `[sys].[endpoints]`, `[sys].[sp_executesql]`, `[sys].[tcp_endpoints]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

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

**@MaxZeilen:** @MaxZeilen int; Default: 1000. Ganze Zahl als Zeilenlimit je Fachmenge: endpoints, tcpEndpoints, mirroringEndpoints und connectionEncryptionSummary werden unabhängig begrenzt. Positiv begrenzt; NULL oder 0 bedeutet unbegrenzt, negativ ist ungültig. Vollständige Aufnahme und Gruppierung erfolgen davor; sourceStatus.IsLimited zeigt Kürzung. moduleStatus.RowCount summiert ausgegebene Fachzeilen; moduleStatus, sourceStatus und warnings bleiben ungekürzt. Bei ausgelassenem Argument gilt der angegebene Default.

**@LockTimeoutMs:** @LockTimeoutMs muss 0 bis 60000 sein; ConnectionRows zählt DMV-Zeilen einschließlich möglicher MARS-Zeilen.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Ein einzelner Textwert wird mit LTRIM/RTRIM um U+0020-Leerzeichen bereinigt und mit UPPER normalisiert. NULL, Leerstring und reine Leerzeichen sind ungültig. Sämtliche erlaubten Werte: CONSOLE liefert Fach-, Quellen- und Warnzeilen in einer formatierten Menge, RAW sieben native Resultsets, TABLE nur die benannten ausgewählten Zielmengen, NONE keine fachlichen Resultsets. Die optionale JSON-Erzeugung bleibt unabhängig. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Bei TABLE ein JSON-Objekt mit mindestens einem Schlüssel-Ziel-Paar und Stringwerten. Alle zulässigen Schlüssel mit exakter Schreibweise: moduleStatus liefert den Gesamtstatus, endpoints die sichtbaren Endpoints, tcpEndpoints die TCP-Port-/IP-Konfiguration, mirroringEndpoints die Mirroringkonfiguration, connectionEncryptionSummary gruppierte Verbindungsflags, sourceStatus Quellenstatus und Zählwerte, warnings Hinweise und Grenzen. Jeder Schlüssel ist einzeln optional; doppelte Schlüssel werden abgelehnt. Ziele müssen vorhandene, leere lokale #Temp-Tabellen mit genau einer Seed-Spalte sein; höchstens 116 Zeichen, kein ## und kein reserviertes Präfix #Monitor (case-insensitiv). Doppelte Ziele werden case-insensitiv abgelehnt. Bei TABLE sind NULL, Leerstring und Leerzeichen ungültig; außerhalb TABLE sind nur NULL, Leerstring oder U+0020-Leerzeichen erlaubt. Die Vorprüfung erfolgt vor den Fachquellen; nacheinander geschriebene Mengen werden bei späterem Fehler nicht zurückgenommen. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 unterdrückt, 1 erzeugt meta und sieben Arrays: moduleStatus, endpoints, tcpEndpoints, mirroringEndpoints, connectionEncryptionSummary, sourceStatus, warnings. Bit-Konvertierung: Ein numerischer Wert ungleich 0 wird bei der bit-Konvertierung 1; NULL erzeugt nichts. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT nvarchar(max), anfangs NULL. Bei @JsonErzeugen=1 normal meta (resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber, errorMessage) plus sieben Arrays, auch bei Quellenfehlern; sonst und im CATCH NULL. Empfang per nvarchar(max)-Variable OUTPUT. Bei ausgelassenem Argument gilt der angegebene Default.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 0 unterdrückt, 1 gibt RAISERROR-Meldungen niedriger Schwere bei Parameter-, Quellen- und äußeren Fehlern aus. Bit-Konvertierung: Ein numerischer Wert ungleich 0 wird bei der bit-Konvertierung 1; NULL wirkt 0. Hilfe-PRINTs sind unabhängig. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit; Default: 0. Konvertierter Wert 1 gibt vor Prüfung/Zugriff die Hilfetexte aus, setzt Status AVAILABLE und Partial 0, dann vorzeitiges RETURN ohne ausdrücklich angegebenen Wert. NULL wirkt 0; Ein numerischer Wert ungleich 0 wird bei der bit-Konvertierung 1. Andere Outputs bleiben NULL. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine varchar(40)-Variable; der Eingangswert wird auf NULL gesetzt. Alle möglichen Werte: AVAILABLE kennzeichnet den Hilfeabbruch ohne Analyse; INVALID_PARAMETER kennzeichnet ungültige Eingaben beziehungsweise den gespeicherten TABLE-Fehlercode 51011; AVAILABLE_LIMITED bezeichnet mindestens eine erfolgreiche nichtleere native Quelle; EMPTY_UNPROVEN mindestens eine erfolgreiche leere Quelle, sofern keine native Quelle nichtleer erfolgreich ist. Erst ohne erfolgreiche native Quelle wird der erste Fehler nach ENDPOINTS, TCP_ENDPOINTS, MIRRORING_ENDPOINTS, CONNECTIONS übernommen: DENIED_PERMISSION bedeutet einen als Berechtigungsfehler eingestuften Fehler (229, 297, 300, 371), TIMEOUT einen Sperrtimeout 1222 und ERROR_HANDLED einen sonstigen abgefangenen Fehler. Im äußeren CATCH gilt INVALID_PARAMETER bei gespeichertem TABLE-Fehlercode 51011, sonst ERROR_HANDLED. Reguläre Quellenfehler liefern weiterhin RETURN 0; Status und Fehler-OUTPUTs sind getrennt zu lesen. Bei ausgelassenem Argument gilt der angegebene Default.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine bit-Variable; der Eingangswert wird auf NULL gesetzt. Hilfe liefert 0, da keine Analyse ausgeführt wird. Parameterfehler, regulärer Bericht und äußerer CATCH liefern 1; eine normale Analyse bleibt wegen begrenzter Metadatensicht ausdrücklich partiell. 0 aus der Hilfe bestätigt keine vollständige Inventur. Bei ausgelassenem Argument gilt der angegebene Default.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT int, anfangs NULL: Parameterfehler 51011; normal erster Quellenfehler nach ENDPOINTS, TCP_ENDPOINTS, MIRRORING_ENDPOINTS, CONNECTIONS, danach Ableitungsfehler. TABLE: Vorprüfung 51011, Writerfehler dessen Code oder 51010; CATCH Fehlercode. Empfang int-Variable OUTPUT. Im äußeren CATCH ist dieser Wert zugleich der Diagnose-RETURN-Wert; reguläre Quellenfehler ändern den normalen RETURN 0 nicht. Ohne erfassten Fehler bleibt der Wert NULL. Bei ausgelassenem Argument gilt der angegebene Default.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT nvarchar(2048), anfangs NULL; erhält Validierungs-, priorisierten Quellen-/Ableitungs- oder CATCH-Text. Hilfe belässt NULL. Empfang nvarchar(2048)-Variable OUTPUT. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| endpoints | 1 | 1 | [EndpointId] int NOT NULL, [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalId] int NULL, [Protocol] tinyint NOT NULL, [ProtocolDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [EndpointType] tinyint NOT NULL, [EndpointTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [EndpointState] tinyint NULL, [EndpointStateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [IsAdminEndpoint] bit NOT NULL |
| tcpEndpoints | 1 | 1 | [EndpointId] int NOT NULL, [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [Port] int NOT NULL, [IsDynamicPort] bit NOT NULL, [IpAddress] nvarchar(45) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| mirroringEndpoints | 1 | 1 | [EndpointId] int NOT NULL, [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [MirroringRole] tinyint NULL, [MirroringRoleDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [IsEncryptionEnabled] bit NOT NULL, [ConnectionAuthentication] tinyint NOT NULL, [ConnectionAuthenticationDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CertificateId] int NOT NULL, [EncryptionAlgorithm] tinyint NOT NULL, [EncryptionAlgorithmDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| connectionEncryptionSummary | 1 | 1 | [EndpointId] int NULL, [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [EndpointType] tinyint NULL, [NetTransport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ProtocolType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [EncryptOption] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [AuthenticationScheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ConnectionRows] bigint NOT NULL, [EndpointContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [EncryptionEvidence] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| sourceStatus | 1 | 1 | [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [RowUnit] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| warnings | 1 | 1 | [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_EndpointTransportAnalysis] @MaxZeilen=200, @LockTimeoutMs=0, @ResultSetArt='RAW', @PrintMeldungen=0;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Kein TLS-, Cipher-, Zertifikatsvertrauens- oder Erreichbarkeitsbeweis. HADR-Flags und MARS-Zeilen besitzen eigene Aussagegrenzen.

Liest Enginemetadaten und DMV-Zeilen; verändert keine Endpoints, Rechte oder Hostwerte.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_EndpointTransportAnalysis
Version      : 1.0.0
Stand        : 2026-10-25
Zweck        : Die Procedure zeigt sichtbare Engineendpoints, TCP-/Mirroringkonfiguration
               und gruppierte native Verschlüsselungsflags bestehender Verbindungen.
Quellen      : sys.endpoints, sys.tcp_endpoints, sys.database_mirroring_endpoints
               und sys.dm_exec_connections.
Grenzen      : Kein TLS-, Cipher-, Zertifikatsvertrauens- oder Erreichbarkeitsbeweis.
               HADR-Flags und MARS-Zeilen besitzen eigene Aussagegrenzen.
Nebenwirkung : Liest Enginemetadaten und DMV-Zeilen; verändert keine Endpoints,
               Rechte oder Hostwerte.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_EndpointTransportAnalysis
Zeigt SQL-sichtbare Endpointkonfiguration und gruppierte native Verbindungsflags; keine TLS-, Zertifikatsvertrauens- oder externe Erreichbarkeitsprüfung.
Kataloge und Verbindungen werden getrennt erfasst; die sichtbaren Momentaufnahmen sind nicht atomar und nicht zwingend vollständig.
CONSOLE, RAW, TABLE und NONE steuern die Ausgabe; @MaxZeilen begrenzt vier Fachmengen getrennt, 0 und NULL bedeuten unbegrenzt.
Fachliche Quellenfehler stehen in Status und sourceStatus; ungültige Parameter und TABLE-Vorprüfungsfehler liefern RETURN 51011 und JSON-NULL. HADR encrypt_option=FALSE ist kein Negativbeweis.
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_EndpointTransportAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
CREATE TABLE [#EndpointTransportAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_EndpointTransportAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=N'{"endpoints":"#EndpointTransportAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#EndpointTransportAnalysis_HelpExample]; DROP TABLE IF EXISTS [#EndpointTransportAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#EndpointTransportAnalysis_HelpExample]; THROW; END CATCH;
```


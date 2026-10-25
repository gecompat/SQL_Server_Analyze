# SQL-sichtbare Endpoints und Transportverschlüsselung

**Stand:** 25. Oktober 2026.
**Status:** konkretisierter erster SQL-Scope; unabhängiger Vertragsreview und Produktimplementierung offen.
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
Der genaue Feldvertrag wird vor Implementierung unabhängig geprüft und
anhand nativer Schemaproben konkretisiert.

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

## Primärquellen

- Microsoft Learn: [sys.endpoints](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-endpoints-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [sys.tcp_endpoints](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-tcp-endpoints-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [sys.database_mirroring_endpoints](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-mirroring-endpoints-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [sys.dm_exec_connections](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-connections-transact-sql?view=sql-server-ver17).

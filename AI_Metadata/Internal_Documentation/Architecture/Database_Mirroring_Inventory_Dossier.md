# SQL-sichtbares Inventar für Database Mirroring

**Stand:** 27. Oktober 2026.
**Status:** begrenztes V1-Dossier; keine Produktimplementierung oder positive Mirroring-Qualifikation.
**Artefakt-UID:** urn:uuid:01a17ef8-7d19-7e63-9c8a-7d33cb449857.
**Registrierung:** DEFERRED; keine lesbare Kennung vergeben.
**Arbeitselement:** kontinuierlicher WI-0010-Intake; kein neues Arbeitselement.
**Planung:** Schritt 42 der [Entwicklungswellen](../Quality/Development_Waves_2026-10.md); Intake bleibt RESEARCHED_NOT_IMPLEMENTED.

## Diagnosefrage und Grenzen

Ein späterer read-only-Slice soll die für den Aufrufer sichtbaren Datenbank-Mirroring-Zustände,
lokale Rolle, Transaktionssicherheit, Witness-Zustand und die konfigurierte Redo-Queue-Obergrenze je
Datenbank zeigen. Er stellt native Metadaten unverändert bereit; er bildet weder eine
Gesundheitsbewertung noch ein Urteil über Failover oder Migration.

Microsoft kennzeichnet Database Mirroring als veraltet und zur Entfernung in einer künftigen
SQL-Server-Version vorgesehen; neue Entwicklung soll es vermeiden und bestehende Installationen
sollen eine Migration planen. Database Mirroring ist unter SQL Server auf Linux nicht verfügbar. Das
Produktinventar soll diese Einordnung anzeigen, aber keine AG-Migration planen oder ausführen.

Ausgeschlossen sind Änderungen, Restore, DBCC, Endpoint- oder Partnerprobes, Verbindungen zu anderen
Instanzen, Netzwerk-, Witness-, Dienst-, Cluster- oder Hostgesundheit, LSN-Auswertung, automatische
HA-/Failoverurteile, Enforcement und Migrationsrisiko-Scores. Die native Spalte mirroring_redo_queue
ist laut Definition eine konfigurierte maximale Redo-Menge in MB oder NULL bei unbegrenzt/offline;
sie ist keine Messung einer aktuellen Queue. Witness-Zustand beschreibt die vom lokalen
Engine-Katalog dargestellte Session-Information und beweist weder Witness-Hostgesundheit noch
Quorum-/Failoverfähigkeit. Partner-/Witness-Namen, Mirroring-GUIDs und LSNs werden nicht ausgegeben.

## Quellenprüfung

| Native Quelle und geprüfte Spalten | Native Typen und Bedeutung | Sichtbarkeit / Grenze |
|---|---|---|
| sys.databases: database_id int, name sysname | Lokale ID und Name zur Benennung der Datenbankzeile. | Nur vom Aufrufer sichtbare Datenbankmetadaten; kein Vollständigkeitsbeweis. |
| sys.database_mirroring: database_id int; mirroring_state tinyint, mirroring_state_desc nvarchar(60); mirroring_role tinyint, mirroring_role_desc nvarchar(60); mirroring_safety_level tinyint, mirroring_safety_level_desc nvarchar(60); mirroring_witness_state tinyint, mirroring_witness_state_desc nvarchar(60); mirroring_redo_queue int, mirroring_redo_queue_type nvarchar(60). | Lokaler Sitzungszustand/Rolle, Safety-Konfiguration, Witness-Zustand und konfigurierte Redo-Obergrenze. | Eine Zeile je Datenbank. Für andere Datenbanken als master/tempdb muss der Caller Datenbankbesitzer oder berechtigt sein über ALTER ANY DATABASE, VIEW ANY DATABASE oder CREATE DATABASE in master. Nicht-NULL-Werte auf einer Mirror-Datenbank erfordern sysadmin. Die Microsoft-Seite nennt für SQL Server 2022+ VIEW SERVER PERFORMANCE STATE. Metadatensicht bleibt zusätzlich auf Securables beschränkt, die der Caller besitzt oder für die er eine Berechtigung hat. Die offizielle Katalogdokumentation nennt ab SQL Server 2022 VIEW SERVER PERFORMANCE STATE. Für SQL Server 2019 spezifiziert sie keine weitere Serverberechtigung; eine solche Anforderung wird nicht aus DMV-Regeln abgeleitet. Nicht-NULL-Werte einer Mirror-Datenbank erfordern sysadmin. [Microsoft Learn: sys.database_mirroring](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-mirroring-transact-sql?view=sql-server-ver17). |

sys.database_mirroring liefert nur database_id, wenn eine Datenbank nicht ONLINE oder nicht
gespiegelt ist; alle mirroring_-Spalten sind in diesen Fällen NULL. Bei einer sichtbaren, nicht
gespiegelten Datenbank sind die Mirroring-Spalten ebenfalls NULL. Der Vertrag unterscheidet diese
dokumentierten nativen NULL-Fälle nicht in erfundene Statuswerte. sys.databases enthält nur vom
Caller sichtbare Zeilen; insbesondere ist eine OFFLINE-Datenbank für niedrig privilegierte Caller
nicht sichtbar. Ein fehlendes Resultat beweist daher keine globale Abwesenheit. Die Microsoft-Dokumentation bestätigt eine Zeile je Datenbank, NULL-Werte für nicht ONLINE befindliche Datenbanken und die Metadatensichtgrenze; siehe [sys.database_mirroring](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-mirroring-transact-sql?view=sql-server-ver17). Der Resultatvertrag
verbindet name und database_id aus sys.databases mit dem Mirroring-Katalog über database_id, aber
deutet NULL-Metadaten nicht in „gesund“ oder „nicht gespiegelt“ um.

Die nativen Codes werden ohne Bewertung ausgegeben: mirroring_state 0–6 steht für SUSPENDED,
DISCONNECTED, SYNCHRONIZING, PENDING_FAILOVER, SYNCHRONIZED, UNSYNCHRONIZED und einen weiteren
SYNCHRONIZED-Zustand; mirroring_role 1/2 für PRINCIPAL/MIRROR; Safety 0/1/2 für UNKNOWN/OFF/FULL;
Witness 0/1/2 für UNKNOWN/CONNECTED/DISCONNECTED. Diese Werte allein belegen weder Gesundheit noch
automatische Failoverfähigkeit. Microsoft verlangt für automatisches Failover unter anderem FULL,
bereits synchronisierte Datenbanken und einen verbundenen Witness.

Die geprüfte sys.dm_db_mirroring_connections liefert unter anderem connection_id uniqueidentifier,
state smallint, state_desc nvarchar(60), is_accept bit, login_state smallint und address
nvarchar(256), aber keinen database_id. Ihre Zeilen lassen sich nicht sicher einer Datenbank
zuordnen und werden daher aus V1 ausgeschlossen. Für die server-scoped DMV-Abfrage gilt SELECT plus
VIEW SERVER STATE bis SQL Server 2019 und VIEW SERVER PERFORMANCE STATE ab SQL Server 2022.
Remote-Identität und Adresse werden nicht benötigt.

sys.dm_os_wait_stats liefert wait_type nvarchar(60) sowie waiting_tasks_count, wait_time_ms,
max_wait_time_ms und signal_wait_time_ms als bigint. Die Werte sind abgeschlossene, kumulative
Instanz-Wartezähler seit Neustart oder Reset, keine aktuellen oder datenbankbezogenen
Queue-Messungen. DBMIRROR-Waits bleiben deshalb außerhalb des Vertrags. Insbesondere sind
Leerlauf-Waits kein Gesundheitsurteil.

## Vorgeschlagener Produktvertrag

Vorgeschlagene Procedure: monitor.USP_DatabaseMirroringInventory. V1 liest nur die beiden oben genannten Kataloge im durch monitor.USP_PrepareDatabaseCandidates
bestimmten Datenbankumfang. Ohne Filter umfasst er alle sichtbaren ONLINE-Benutzerdatenbanken;
Systemdatenbanken sind standardmäßig ausgeschlossen und werden nur mit
@SystemdatenbankenEinbeziehen=1 einbezogen. Der gemeinsame Selektor nimmt nur ONLINE-Datenbanken auf. Eine Mirror-Datenbank im Zustand RESTORING ist daher nicht Teil der V1-Auswahl; V1 belegt keine positive Mirror-Rollenbeobachtung auf dieser Partnerseite. Die vorhandenen Selektionsparameter @DatabaseNames
und @DatabaseNamePattern sowie ihr Fehler- und Filtervertrag werden unverändert übernommen. Es
werden keine neuen Current-/Max-Datenbankparameter eingeführt. Das Verfahren verwendet feste,
explizit benannte Spalten, keine SELECT *, keine dynamischen Datenbanknamen, keine Rechtevergabe,
kein EXECUTE AS und keine Signatur.

Der öffentliche Parametervertrag übernimmt die Selektions- und Ausgabeparameter des vorhandenen Per-Datenbank-Verfahrens. Es werden keine Parameter für Current-Datenbank, maximale Datenbankzahl oder Locktimeout ergänzt.

| Parameter | Typ, Default und Verhalten |
|---|---|
| @DatabaseNames | nvarchar(max) = NULL; vorhandene Auswahl mehrerer Datenbanken |
| @SystemdatenbankenEinbeziehen | bit = 0; Systemdatenbanken nur opt-in |
| @DatabaseNamePattern | nvarchar(4000) = NULL; vorhandener Namensfilter |
| @MaxZeilen | int = 1000; globales Limit für databaseMirroring; NULL oder 0 unbegrenzt, negativ ungültig |
| @ResultSetArt | varchar(16) = 'CONSOLE'; RAW, TABLE, CONSOLE oder NONE gemäß Framework |
| @ResultTablesJson | nvarchar(max) = NULL; nur für TABLE |
| @JsonErzeugen | bit = 0 |
| @Json | nvarchar(max) = NULL OUTPUT |
| @PrintMeldungen | bit = 1 |
| @Hilfe | bit = 0; Hilfe beendet fachliche Verarbeitung ohne Quellenlesung |
| @StatusCodeOut | varchar(40) = NULL OUTPUT |
| @IsPartialOut | bit = NULL OUTPUT |
| @ErrorNumberOut | int = NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) = NULL OUTPUT |

Die Selektionssemantiken und Validierungen werden aus USP_DatabasePrincipalAnalysis und USP_PrepareDatabaseCandidates übernommen. Filterkombinationen, ungültige, nicht sichtbare oder nicht verfügbare Zielnamen behalten deren vorhandenes Fehler- und Warnverhalten; V1 ergänzt keine Fallbackauswahl. Die Fachmenge ist nach DatabaseId sortiert; ein angewandtes Limit wird im Frameworkstatus kenntlich gemacht.

Die einzige fachliche Menge heißt databaseMirroring. RAW gibt diese Menge zusätzlich zu den
üblichen Framework-Status-, Quellenstatus- und Warnmengen aus. TABLE exportiert dieselbe Feldfolge
und dieselben physischen Typen für databaseMirroring; JSON verwendet schemaVersion=1, die
vorhandene Meta-Hülle und databaseMirroring als Array; CONSOLE folgt dem bestehenden
Einzelmodul-Vertrag; NONE unterdrückt Resultsets und behält OUTPUT-Status sowie optionales JSON.
Die vorhandenen Frameworkschemas, Fehler- und JSON-Verträge bleiben maßgeblich. Alle Textspalten
verwenden die im Servermodulstandard festgelegte SQL_Latin1_General_CP1_CS_AS-Kollation.

| Feldfolge | Physischer Typ | Native Quelle |
|---|---|---|
| DatabaseId | int NOT NULL | sys.database_mirroring.database_id / Join-Schlüssel |
| DatabaseName | sysname NOT NULL | sys.databases.name |
| MirroringState | tinyint NULL | mirroring_state |
| MirroringStateDesc | nvarchar(60) NULL | mirroring_state_desc |
| MirroringRole | tinyint NULL | mirroring_role |
| MirroringRoleDesc | nvarchar(60) NULL | mirroring_role_desc |
| MirroringSafetyLevel | tinyint NULL | mirroring_safety_level |
| MirroringSafetyLevelDesc | nvarchar(60) NULL | mirroring_safety_level_desc |
| MirroringWitnessState | tinyint NULL | mirroring_witness_state |
| MirroringWitnessStateDesc | nvarchar(60) NULL | mirroring_witness_state_desc |
| ConfiguredRedoQueueLimitMb | int NULL | mirroring_redo_queue; configured cap, not observed queue backlog |
| RedoQueueLimitType | nvarchar(60) NULL | mirroring_redo_queue_type |

Der Aufruf übernimmt keine Caller-Transaktion und startet, bestätigt oder verwirft keine
Transaktion. Er ändert weder die Isolationsstufe noch den Callerwert von LOCK_TIMEOUT. Die
Quellphase verwendet das Projektmuster SET LOCK_TIMEOUT 0 und stellt den ursprünglichen Wert auch
nach abgefangenen Fehlern wieder her. Katalogzugriffe verwenden NOLOCK gemäß
Requirements_and_Decisions.md. Dirty Reads können dadurch inkonsistente, fehlende oder doppelte
Zeilen liefern; die Quellen bilden keine zugesicherte atomare Momentaufnahme. NOLOCK verhindert
keine Sch-S-Sperren und schließt ein Warten auf eine konkurrierende Sch-M-Sperre nicht aus. Der
Vertrag verspricht deshalb keine absolute Nichtblockierung.
Ein fehlgeschlagener oder verweigerter Zugriff bleibt ein expliziter Quellenfehler und wird nie als
leere Menge ausgegeben. Eine leere Menge bedeutet, dass unter dem ausgewählten Filter keine
Benutzer-Datenbankzeilen für diesen Caller sichtbar waren; sie beweist keine instanzweite
Abwesenheit von Mirroring. Die Ergebnisse bleiben AVAILABLE_LIMITED/partial, weil die
Vollständigkeit der Katalogsicht nicht bewiesen ist.

## Liefergates und offene positive Qualifikation

Schritt 43 implementiert diesen Scope als monitor.USP_DatabaseMirroringInventory. Der öffentliche Vertragsumfang enthält moduleStatus, genau eine Fachmenge databaseMirroring, sourceStatus und warnings; die zwölf Fachspalten folgen der nativen Feldfolge. Der ONLINE-Selektor kann eine RESTORING-Mirror-Datenbank ausschließen. Produkt und Tests dürfen deshalb keine positive Mirror-Rollenbeobachtung für diese Partnerseite behaupten.

Die Produktimplementierung kann unabhängig von einer echten Mirroring-Topologie an den
SQL-sichtbaren Grenzen abgenommen werden: genaue Quellen-/Spaltenprüfung, statische und
Datenschutzprüfung, SQL-Server-2025-Tests für Standardauswahl, leere und eingeschränkte Sicht,
explizite Quellenverweigerung, nicht verfügbare Quelle, Limitverhalten, RAW/TABLE/JSON/NONE-ABI,
physische Typen, Caller-Transaktion/Isolation/LOCK_TIMEOUT-Wiederherstellung sowie keine Schreib-
oder externen Probeoperationen. NOLOCK-Lesegrenzen und mögliches Warten auf Schemaänderungen sind
als Ergebnisgrenze dokumentiert; der Test darf daraus keine Nichtblockierungsgarantie ableiten. Ein leeres Linux-Ergebnis prüft nur die Plattform-/Leergrenze,
nicht die Windows-Funktion. Versionsrechte sind anhand der offiziellen Katalogquelle zu binden:
VIEW SERVER PERFORMANCE STATE ab SQL Server 2022. Die SQL-Server-2019-Katalogquelle spezifiziert
keine weitere Serverberechtigung; die versionsspezifische native Qualifikation bleibt offen.

Eine positive Mirroring-Qualifikation bleibt separat offen. Im Repository ist keine konfigurierte
Windows Principal-/Mirror-/Witness-Umgebung vorhanden. Das Dossier liefert daher weder eine positive
Mirroring-Zeile noch einen positiven PASS. Eine spätere, eigens autorisierte und verfügbare
Windows-SQL-Server-Topologie muss unabhängig Principal-/Mirror-Rollen, Safety-/State-Kombinationen,
Witness vorhanden/fehlend und die konfigurierte Redo-Obergrenze prüfen. SQL Server unter Linux kann
keine positive Mirroring-Session qualifizieren.

WI-0010 bleibt RESEARCHED_NOT_IMPLEMENTED, bis eine Implementierung durch genaue Quellenprüfung,
unabhängigen statischen Review, ausgewählte Funktions- und Nativgates sowie die Bindung im
Produktionsinventar belegt ist. Reife, Vollständigkeit, Gesundheit, automatisches Failover, aktuelle
Queue-Größe, externe Konnektivität, Migrationssicherheit und positives Mirroring werden nicht
behauptet.

## Primärquellen

- Microsoft Learn, [sys.databases (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql?view=sql-server-ver17) — Spaltentypen und Sichtbarkeit, insbesondere OFFLINE-Datenbanken.

- Microsoft Learn, [Table Hints (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17) — Dirty-Read- und Sch-S/Sch-M-Grenzen von NOLOCK.

- Microsoft Learn, [sys.database_mirroring (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-mirroring-transact-sql?view=sql-server-ver17) — native Spalten, Statuscodes, Sichtbarkeit und 2022+-Berechtigung.

- Microsoft Learn, [sys.dm_db_mirroring_connections](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/database-mirroring-sys-dm-db-mirroring-connections?view=sql-server-ver17) — Verbindungsschema ohne Datenbankschlüssel.

- Microsoft Learn, [Dynamic management objects](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/system-dynamic-management-objects?view=sql-server-ver17) und [sys.dm_os_wait_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql?view=sql-server-ver17) — Scope-/Versionsrechte und Grenzen kumulativer Waits.

- Microsoft Learn, [Mirroring States (SQL Server)](https://learn.microsoft.com/en-us/sql/database-engine/database-mirroring/mirroring-states-sql-server?view=sql-server-ver17) — Bedeutung und zeitlicher Bezug der Sessionzustände.

- Microsoft Learn, [Database Mirroring](https://learn.microsoft.com/en-us/sql/database-engine/database-mirroring/database-mirroring-sql-server?view=sql-server-ver17) und [Operating Modes](https://learn.microsoft.com/en-us/sql/database-engine/database-mirroring/database-mirroring-operating-modes?view=sql-server-ver15) — Veraltung, Datenbankumfang und Bedeutung von Safety/Witness.

- Microsoft Learn, [Business Continuity and Database Recovery for SQL Server on Linux](https://learn.microsoft.com/sql/linux/sql-server-linux-business-continuity-dr) — Mirroring ist auf SQL Server Linux nicht verfügbar.

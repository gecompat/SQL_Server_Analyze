# WI-0009: Lokale External-Data-Analyse

Status: APPROVED. Der Benutzer hat den konkreten Vertrag am 14. Oktober 2026 freigegeben.

## Zweck und Scope

`monitor.USP_ExternalDataAnalysis` liest die sichtbaren lokalen Kataloge ausgewählter Datenbanken. Die Ausgabe trennt Datenquellen, Dateiformate, externe Tabellen und eine aggregierte Modellanzahl. Sie verbindet ausschließlich lokal sichtbare Objektkennungen. Eine Katalogzeile beweist weder Erreichbarkeit noch Nutzbarkeit einer externen Datenquelle.

Es gibt keinen Remotezugriff, SELECT auf externe Tabellen, OPENROWSET, Inferenzaufruf, Konfigurationswechsel, Credentialzugriff oder DDL im Produktcode. Locations, Verbindungsoptionen, Credentialkennungen und -namen, Remote-Datenbank-/Schema-/Objektnamen, Modellnamen, Modellparameter und Payloads werden nicht gelesen. Lokale Datenbank-, Schema-, Tabellen-, Datenquellen- und Dateiformatnamen bleiben diagnostische Identitäten.

## Parameter

| Parameter | Typ und Default | Bedeutung |
|---|---|---|
| @DatabaseNames | nvarchar(max)=NULL | Exakte bracket-aware Pipe-Liste. |
| @DatabaseNamePattern | nvarchar(4000)=NULL | Bestehender LIKE-/versionsabhängiger Regexvertrag. |
| @SystemdatenbankenEinbeziehen | bit=0 | Systemdatenbanken bleiben opt-in. |
| @MaxZeilen | int=2000 | Positive Grenze je fachlicher Detailmenge; 0/NULL vollständig, negativ ungültig. |
| @ResultSetArt | varchar(16)='CONSOLE' | Bestehende RAW/TABLE/CONSOLE/NONE-Verträge. |
| @ResultTablesJson | nvarchar(max)=NULL | Benannter TABLE-Export. |
| @JsonErzeugen | bit=0 | Optionales JSON. |
| @Json | nvarchar(max)=NULL OUTPUT | JSON-Schema 1. |
| @PrintMeldungen | bit=1 | Bestehender Meldevertrag. |
| @Hilfe | bit=0 | Hilfepfad ohne fachliche Quellenzugriffe. |
| @StatusCodeOut | varchar(40)=NULL OUTPUT | Modulstatus. |
| @IsPartialOut | bit=NULL OUTPUT | Quellen- oder Scope-Unvollständigkeit. |

Der Standard verarbeitet sichtbare, online befindliche Benutzerdatenbanken. Es gibt keinen impliziten CURRENT-Scope und keine Begrenzung der Zahl ausgewählter Datenbanken.

## Native Ausgabeschemas

RAW liefert die folgenden Mengen in dieser Reihenfolge; TABLE verwendet dieselben Namen und nativen Spalten. JSON enthält Metadaten mit SchemaVersion 1 und gleichnamige Arrays. Alle Textvergleiche und temporären Textspalten verwenden die Framework-Collation SQL_Latin1_General_CP1_CS_AS.

| Menge | Spalten in Reihenfolge |
|---|---|
| moduleStatus | ModuleName sysname, StatusCode varchar(40), IsPartial bit, ErrorNumber int NULL, ErrorMessage nvarchar(4000) NULL, CollectionTimeUtc datetime2(3) |
| databaseStatus | DatabaseName sysname, StatusCode varchar(40), IsPartial bit, DataSourceCount bigint NULL, FileFormatCount bigint NULL, ExternalTableCount bigint NULL, ExternalModelCount bigint NULL, ErrorNumber int NULL, ErrorMessage nvarchar(4000) NULL |
| dataSources | DatabaseName sysname, DataSourceId int, DataSourceName sysname, TypeCode tinyint NULL, TypeDescription nvarchar(255) NULL |
| fileFormats | DatabaseName sysname, FileFormatId int, FileFormatName sysname, FormatTypeCode tinyint NULL |
| externalTables | DatabaseName sysname, ObjectId int, SchemaName sysname NULL, TableName sysname, DataSourceId int NULL, FileFormatId int NULL, DataSourceReferenceStatus varchar(40), FileFormatReferenceStatus varchar(40), VisibleColumnCount bigint NULL |
| modelSummary | DatabaseName sysname, VisibleModelCount bigint NULL, SourceStatus varchar(40) |
| sourceStatus | DatabaseName sysname, SourceName sysname, SourceStatus varchar(40), ErrorNumber int NULL, ErrorMessage nvarchar(4000) NULL, CollectionTimeUtc datetime2(3) |
| warnings | DatabaseName sysname NULL, WarningCode varchar(64), Detail nvarchar(2000) |

Textspalten, die im nativen Katalog NULL zulassen, bleiben NULL. Tabellenstatus, Counts und Quellenstatus beziehen sich auf die unlimitierte Sammlung; Detailarrays werden anschließend stabil nach Datenbank und nativer Kennung begrenzt. Zeilenlimits erzeugen keine Fehler und kein IsPartial. CONSOLE liefert eine formatierte fachliche Menge einschließlich einer verständlichen Leerzeile.

## Quellen, Fehler und Referenzen

Die unabhängige Quellenfolge je Datenbank ist `sys.external_data_sources`, `sys.external_file_formats`, `sys.external_tables`, `sys.schemas`, `sys.columns`, `sys.external_models`. Ausgewählte Datenbanken werden nach DatabaseName mit Framework-Collation aufsteigend verarbeitet. Die erste tatsächliche native Fehlerpaarung ergibt sich aus dieser Datenbankreihenfolge, anschließend aus der festen Quellenfolge. Fehler der vorangestellten Datenbankauswahl haben Vorrang, weil dann keine verlässliche Datenbanksammlung vorliegt. Konfigurationswerte werden nicht in Findings umgedeutet. Jede Quellenabfrage ist separat behandelt; ein tatsächlicher Fehler erhält seine native Nummer und Meldung, macht das Modul partiell und löscht keine Ergebnisse anderer Quellen. Die erste native Fehlerpaarung in der festen Quellenfolge bleibt erhalten.

Models werden ab Major 17 dynamisch gelesen. Ältere Engines liefern für diese Quelle UNAVAILABLE_VERSION und NULL-Anzahl ohne künstliche Partialität. Ein unbekannter Major oder unerwartet fehlendes aktuelles Katalogobjekt ist SOURCE_UNAVAILABLE mit IsPartial=1. Leere erfolgreich gelesene Kataloge liefern AVAILABLE und Anzahl 0. Sichtbare Metadaten sind kein Vollständigkeitsbeweis; fehlende Berechtigungen können auch eine leere Menge verursachen.

Die Statusmatrix ist verbindlich:

| Situation | Quellenstatus | Datenbank- und Modulstatus |
|---|---|---|
| Erfolgreiche Katalogabfrage, auch leer | AVAILABLE | AVAILABLE ohne Fehler und ohne Partialität, sofern alle erwarteten Quellen erfolgreich sind. |
| Models auf Major 15/16 | UNAVAILABLE_VERSION, NULL-Anzahl, kein natives Fehlerpaar | Kein Fehler und keine zusätzliche Partialität. |
| Native Permissionfehler 229/262/297/300/371 | DENIED_PERMISSION, natives Fehlerpaar, NULL-Anzahl | Bei erhaltenen anderen Quellen AVAILABLE_LIMITED; bei keiner erfolgreichen erwarteten Quelle Status der ersten fehlgeschlagenen Quelle. IsPartial=1. |
| Native 1222 | ERROR_HANDLED, natives Fehlerpaar, NULL-Anzahl | Gleiche Teilmengenregel und IsPartial=1. |
| Unerwartete native 208/207 einer aktuellen Quelle | SOURCE_UNAVAILABLE, natives Fehlerpaar, NULL-Anzahl | Gleiche Teilmengenregel und IsPartial=1. |
| Anderer nativer Quellenfehler | ERROR_HANDLED, natives Fehlerpaar, NULL-Anzahl | Gleiche Teilmengenregel und IsPartial=1. |
| Major unbekannt für Models | SOURCE_UNAVAILABLE, NULL-Anzahl, NULL-Fehlerpaar | Teilmengenregel und IsPartial=1; keine erfundene Fehlernummer. |
| Explizit ausgewählte Datenbank fehlt oder ist nicht zugänglich | DATABASE_UNAVAILABLE, NULL-Anzahlen | DATABASE_UNAVAILABLE in databaseStatus und IsPartial=1; kein erfundenes natives Fehlerpaar. |

Der Modulstatus ist AVAILABLE_LIMITED, wenn mindestens eine erwartete Quelle einer ausgewählten Datenbank erfolgreich gelesen wurde und zugleich ein Datenbank-/Quellenproblem vorliegt. Ohne erfolgreich gelesene erwartete Quelle erhält er die Klassifikation des ersten Problems gemäß der festgelegten Reihenfolge. Ein leerer ungefilterter Benutzerdatenbankscope ist AVAILABLE mit leeren fachlichen Arrays; explizit fehlende Auswahl erhält DATABASE_UNAVAILABLE. Ausschließlich UNAVAILABLE_VERSION ist kein Problem. Der erste tatsächliche native Fehler wird separat erhalten, auch wenn ein früheres Problem keine native Fehlernummer hatte.

Jeder Fehler betrifft nur die Anzahl und Detailmenge seiner Quelle. Fehler von sys.schemas erhalten Tabellenzeilen mit NULL-SchemaName; Fehler von sys.columns erhalten sie mit NULL-VisibleColumnCount. Die unabhängigen Quellen erhalten jeweils eigene sourceStatus-Zeilen; keine Ersatznull wird als erfolgreich gemessene Anzahl 0 ausgegeben.

Eine externe Tabelle mit einer positiven Referenzkennung erhält VISIBLE, wenn die entsprechende Kennung in der erfolgreich gelesenen lokalen Quelle vorhanden ist. Fehlt sie dort, lautet der Status NOT_VISIBLE_IN_SCOPE; das ist keine Orphan- oder Defektbehauptung. Eine NULL-/0-Kennung erhält immer zuerst NOT_APPLICABLE, auch bei ausgefallener Referenzquelle. Ausschließlich eine positive Kennung erhält bei fehlgeschlagener Referenzquelle SOURCE_UNAVAILABLE. Sichtbare Spalten werden nur aus sys.columns aggregiert; Spaltennamen und Datenwerte bleiben ausgeschlossen. Fehler der Spaltenquelle erhalten die Tabellenidentitäten und liefern NULL-Anzahl.

Der Analyzer erhält TranCount, LOCK_TIMEOUT und XACT_ABORT des Callers. Er startet keine Transaktion. Katalogzugriffe minimieren Blockierung nach dem vorhandenen Nonblocking-Vertrag. Die Eigenlast besteht aus begrenzten lokalen Katalogabfragen pro ausgewählter Datenbank und der Aggregation sichtbarer Spalten, ohne Sampling oder Remote-I/O. Geldkosten bleiben UNKNOWN; der technische Umfang ist LOW_TO_MEDIUM.

## Implementierung und Abnahme

WI-0007 muss vor Lieferung dieser Funktion integriert sein. Implementierung, Installer, Inventare und Referenzen werden gemeinsam aktualisiert. Der zunächst gewählte native Umfang bleibt endlich und wird vor Ausführung gebunden. SQL Server 2025 prüft positive eigene lokale Kataloge, leere Mengen, Filter, Limit, Physical-TABLE-/JSON-Parität und Callerrestaurierung. Compatibility Levels 150/160/170 und eine gezielte ältere Engine prüfen die tatsächlichen betroffenen Verträge. Private Fehlersimulationen werden ausdrücklich von echten Quellen- und Berechtigungsnachweisen getrennt.

Positive Testobjekte dürfen ausschließlich in eigenen synthetischen Datenbanken entstehen. Keine Query einer externen Tabelle und keine Verbindung zum hinterlegten synthetischen Ort ist zulässig. Wenn eine notwendige DDL auf der vorhandenen öffentlichen Lab-Engine nicht ohne Installation oder Remoteaktion möglich ist, bleibt der positive Nachweis offen; keine neue Infrastruktur oder Featureinstallation wird stillschweigend gestartet. Ein erfolgreicher Katalogtest belegt keinen Remoteabruf.

## Primärquellen

- [Datenquellenkatalog](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-data-sources-transact-sql?view=sql-server-ver17)
- [Dateiformatkatalog](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-file-formats-transact-sql?view=sql-server-ver17)
- [Externe Tabellen](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-tables-transact-sql?view=sql-server-ver17)
- [Externe Modelle](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-models-transact-sql?view=sql-server-ver17)
- [PolyBase und native Dateikonnektoren in SQL Server 2025](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-guide?view=sql-server-ver17)

Die Microsoft-Quellen dokumentieren die sichtbaren lokalen Kataloge und die Trennung von nativen Dateikonnektoren und installierten Datenbankkonnektoren. Daraus wird keine Freigabe für Installation, Netzwerkzugriff oder konkrete positive DDL-Abnahme abgeleitet.

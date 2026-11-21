---
skill_format_version: "1.0.0"
name: "monitor.USP_LogShippingStatus"
schema_name: "monitor"
object_name: "USP_LogShippingStatus"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure liest vorhandene Log-Shipping-Konfiguration und Monitorzustände für Primary- und Secondary-Datenbanken."
source_path: "Code/07_Infrastructure/060_USP_LogShippingStatus.sql"
---

# monitor.USP_LogShippingStatus

## Zweck und Einsatz

Die Procedure liest vorhandene Log-Shipping-Konfiguration und Monitorzustände für Primary- und Secondary-Datenbanken.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

msdb.dbo.log_shipping_primary_databases, log_shipping_monitor_primary, log_shipping_monitor_secondary, log_shipping_secondary_databases

Nur lesender Zugriff auf die genannten Systemobjekte. Das Framework vergibt keine Rechte und ändert keine Konfiguration.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MaxZeilen | int | nein | 5000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@MaxZeilen:** @MaxZeilen int=5000; Default: 5000. Eine positive Grenze ist eine ganze Zeilenzahl von 1 bis 2147483647. Negative Werte setzen `INVALID_PARAMETER`; NULL oder 0 werden als unbegrenzte Obergrenze interpretiert. Ein positiver Wert wird getrennt als TOP-Grenze auf Primary- und Secondary-Resultat angewandt, nicht als gemeinsames Gesamtlimit; nach der jeweiligen Sortierung können später eingeordnete Konfigurationen fehlen. Die Eingabe begrenzt nur die ausgegebenen lokalen Konfigurations-/Monitorzeilen, nicht Backup- oder Jobhistory, da solche Quellen nicht abgefragt werden. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. Nach Trim und Umwandlung in Großbuchstaben sind ausschließlich `CONSOLE`, `RAW`, `TABLE` und `NONE` gültig; NULL und andere Werte erzeugen `INVALID_PARAMETER`. CONSOLE liefert ausschließlich eine formatierte Primary-Ausgabe ohne zusätzliches Modulstatus- oder Secondary-Resultset; bei leerer Primary-Menge erscheint eine verständliche Hinweiszeile, RAW liefert technische Resultsets, TABLE schreibt das registrierte `primary`-Resultset, NONE unterdrückt Resultsets. CONSOLE und TABLE setzen den internen Resultsetpfad zunächst auf NONE und laufen danach über ihren Ausgabeadapter. Diese Auswahl steuert JSON nicht. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Bei `TABLE` ist ein nichtleeres JSON-Objekt erforderlich, in der Form {"primary":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel mit einem lokalen Zielnamen als JSON-Stringwert, keine weiteren Eigenschaften. Das Ziel muss leer sein und genau eine Seed-Spalte besitzen. Unbekannte oder doppelte Resultsetnamen, doppelte Ziele, globale/reservierte Ziele, ungültige Namen/Schemas oder fehlende Ziele lösen den TABLE-Preflightfehler 51011 aus. Der Preflight fügt dem Ziel vorübergehend eine Marker-Spalte hinzu und entfernt sie wieder. Außerhalb von TABLE sind NULL und Leer-/Whitespacewerte zulässig; ein nichtleeres Mapping löst 51011 aus. Die Zielnamen dürfen höchstens 116 Zeichen lang sein. Zielnamen-Duplikate werden ohne Beachtung der Groß-/Kleinschreibung geprüft; Resultset-Schlüssel müssen dagegen exakt einschließlich Groß-/Kleinschreibung stimmen. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 1 erzeugt JSON; 0 oder NULL lässt `@Json` nach der initialen Rücksetzung NULL. Das Root-Objekt enthält `meta` (u. a. resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage), `primary` und `secondary`. Die JSON-Ausgabe ist unabhängig von der Resultsetart. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT-Empfangsparameter für das erzeugte JSON. Zu Beginn wird er auf NULL gesetzt; nur bei `@JsonErzeugen = 1` weist die Procedure den JSON-Text zu. Die Struktur ist im Vertrag von `@JsonErzeugen` beschrieben. Bei HELP oder deaktivierter JSON-Erzeugung bleibt der Wert NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. 1 lässt bei einem behandelten Lesefehler eine Severity-10-Informationsmeldung mit `RAISERROR ... WITH NOWAIT` ausgeben; 0 unterdrückt diese Meldung. NULL wird durch `IF @PrintMeldungen = 1` nicht aktiviert. Der Schalter ändert weder Status noch Resultset-/JSON-Ausgabe. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. 1 gibt die Hilfe mit PRINT aus und kehrt vor Quellenverfügbarkeitsprüfung, Primary-/Secondary-Abfrage und Resultset-/JSON-Erzeugung zurück; 0 führt den normalen Ablauf aus. NULL aktiviert die Hilfe nicht. Die Prüfung von @ResultTablesJson sowie der TABLE-Zielpreflight liegen vor dem Hilfezweig. Ein ungültiges Mapping kann deshalb auch mit @Hilfe=1 Fehler 51011 auslösen; ein gültiges TABLE-Ziel wird bereits vor dem Hilferücksprung durch temporäres Hinzufügen und Entfernen einer Marker-Spalte geprüft. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

RAW: Modulstatus, Primary und Secondary. CONSOLE/TABLE: Primary.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| primary | 1 | 1 | [PrimaryServer] sysname,[PrimaryDatabase] sysname,[BackupDirectory] nvarchar(500),[BackupShare] nvarchar(500),[BackupRetentionPeriod] int,[BackupThreshold] int,[ThresholdAlertEnabled] bit,[LastBackupFile] nvarchar(500),[LastBackupDate] datetime,[BackupAgeMinutes] int,[LastBackupDateUtc] datetime,[HistoryRetentionPeriod] int |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_LogShippingStatus] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_LogShippingStatus

Die Hilfe kehrt vor Verfügbarkeitsprüfung, Quellenabfrage und Ergebnisausgabe zurück. Die TABLE-Zielprüfung läuft davor, auch bei @Hilfe=1.

Der normale Pfad liest ausschließlich lokale Log-Shipping-Konfigurations- und Monitorzeilen aus msdb. Er fragt keine Jobhistory, Backuphistory, Remoteinstanz oder Logdatei ab und löst keine Backup-, Copy- oder Restoreaktion aus.

Primary- und Secondary-Zeilen werden getrennt begrenzt und ausgegeben. Die Ergebnisse sind ein nicht atomarer Snapshot lokaler Konfigurations-/Monitorwerte und belegen keine vollständige Datenbewegung.

Beispiel 1: EXEC [monitor].[USP_LogShippingStatus] @Hilfe=1;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_LogShippingStatus
Version      : 1.0.1
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Die Procedure liest vorhandene Log-Shipping-Konfiguration und Monitorzustände für Primary- und Secondary-Datenbanken.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : msdb.dbo.log_shipping_primary_databases, log_shipping_monitor_primary, log_shipping_monitor_secondary, log_shipping_secondary_databases
Parameter    : @MaxZeilen, @ResultSetArt, @ResultTablesJson, @JsonErzeugen,
               @Json OUTPUT, @PrintMeldungen, @Hilfe
Resultsets   : RAW: Modulstatus, Primary und Secondary. CONSOLE/TABLE: Primary.
               NONE: keine Resultsets.
Berechtigung : Nur lesender Zugriff auf die genannten Systemobjekte. Das
               Framework vergibt keine Rechte und ändert keine Konfiguration.
Eigenlast    : Gering.
Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.
Partial      : Fehlende erforderliche Tabellen ergeben UNAVAILABLE_FEATURE
               ohne Partialflag. Abgefangene Lesefehler ergeben ERROR_HANDLED
               mit IsPartial=1; andere Module bleiben ausführbar.
Änderungen   : 1.0.1 - Alertschwellen und History-Retention aus den
               Log-Shipping-Monitor-Tabellen gelesen.
               1.0.0 - Erstfassung Phase 6.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_LogShippingStatus
Die Hilfe kehrt vor Verfügbarkeitsprüfung, Quellenabfrage und Ergebnisausgabe zurück. Die TABLE-Zielprüfung läuft davor, auch bei @Hilfe=1.
Der normale Pfad liest ausschließlich lokale Log-Shipping-Konfigurations- und Monitorzeilen aus msdb. Er fragt keine Jobhistory, Backuphistory, Remoteinstanz oder Logdatei ab und löst keine Backup-, Copy- oder Restoreaktion aus.
Primary- und Secondary-Zeilen werden getrennt begrenzt und ausgegeben. Die Ergebnisse sind ein nicht atomarer Snapshot lokaler Konfigurations-/Monitorwerte und belegen keine vollständige Datenbewegung.
Beispiel 1: EXEC [monitor].[USP_LogShippingStatus] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt='RAW';
Beispiel 3: DECLARE @LogShippingJson nvarchar(max); EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@LogShippingJson OUTPUT; SELECT @LogShippingJson AS [Json];
Beispiel 4: CREATE TABLE #LogShippingStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"primary":"#LogShippingStatus_HelpExample"}'; SELECT * FROM #LogShippingStatus_HelpExample; DROP TABLE #LogShippingStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #LogShippingStatus_HelpExample; THROW; END CATCH;
```


---
skill_format_version: "1.0.0"
name: "monitor.USP_AvailabilityDeepAnalysis"
schema_name: "monitor"
object_name: "USP_AvailabilityDeepAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure vertieft Always-On-Evidenz um Replikazustand, Warteschlangen, Clusterquorum, Seeding und automatische Seitenreparatur."
source_path: "Code/07_Infrastructure/110_USP_AvailabilityDeepAnalysis.sql"
---

# monitor.USP_AvailabilityDeepAnalysis

## Zweck und Einsatz

Die Procedure vertieft Always-On-Evidenz um Replikazustand, Warteschlangen, Clusterquorum, Seeding und automatische Seitenreparatur.

## Voraussetzungen und Rechte

sys.availability_groups, sys.availability_replicas, sys.dm_hadr_availability_replica_states, sys.dm_hadr_database_replica_states, sys.dm_hadr_cluster, sys.dm_hadr_cluster_members, optional sys.dm_hadr_cluster_networks, sys.dm_hadr_physical_seeding_stats und sys.dm_hadr_auto_page_repair.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @QueueWarnMb | bigint | nein | 1024 |
| @SecondaryLagWarnSeconds | int | nein | 60 |
| @MitClusterNetzwerken | bit | nein | 0 |
| @MaxZeilen | int | nein | 1000 |
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

**@QueueWarnMb:** @QueueWarnMb bigint; Default: 1024. Der SQL-bigint-Bereich reicht von -9.223.372.036.854.775.808 bis 9.223.372.036.854.775.807. NULL und negative Werte ergeben INVALID_PARAMETER; 0 ist erlaubt. Der inklusive Sichtungsschwellwert vergleicht COALESCE(Queue-KB, 0) >= decimal(38,0)(MB) * 1024. Die Multiplikation in decimal vermeidet einen bigint-Überlauf. Der Wert ist kein universelles SLO. Die Schwelle gilt getrennt für Send- und Redo-Queue. Bei Schwelle 0 kann auch ein fehlender oder mit 0 gemessener Wert einen Befund auslösen. Suspendierung, ungesunder oder nicht synchronisierender Zustand haben Vorrang. Bei ausgelassenem Argument gilt der angegebene Default.

**@SecondaryLagWarnSeconds:** @SecondaryLagWarnSeconds int; Default: 60. Der SQL-int-Bereich reicht von -2.147.483.648 bis 2.147.483.647. NULL und negative Werte ergeben INVALID_PARAMETER; 0 ist erlaubt. Der inklusive Vergleich lautet COALESCE(Lagsekunden, 0) >= Grenzwert. Einheit ist Sekunden. Bei Schwelle 0 kann auch ein fehlender oder mit 0 gemessener Wert einen Befund auslösen. Suspendierung, ungesunder oder nicht synchronisierender Zustand haben Vorrang. Bei ausgelassenem Argument gilt der angegebene Default.

**@MitClusterNetzwerken:** @MitClusterNetzwerken bit; Default: 0. SQL Server konvertiert das Argument vor Aufruf; nur ein Argument, das zu bit 1 wird, liest sys.dm_hadr_cluster_networks. 0 und NULL lassen diese optionale Detailabfrage aus. Dies ist ein Read-only-Katalog-Opt-in, keine Netzwerkerreichbarkeitsprüfung und keine Konfigurationsänderung. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. Der SQL-int-Bereich reicht von -2.147.483.648 bis 2.147.483.647. Negative Werte sind ungültig; NULL oder 0 bedeuten durch BIGINT-Maximalwert unbegrenzt. Positive Werte begrenzen die Replikat-Auswahl sowie Mitglieder, Netzwerke, Datenbanken, Seeding und Page Repair bei der Ausgabe; die Cluster-Menge bleibt unbegrenzt. Quellenerfassung und Statusfindings erfolgen vor diesem Ausgabelimit. Einheit ist Zeilen. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach SQL-Konvertierung werden Leerzeichen an den Rändern entfernt und der Wert großgeschrieben. Vorgesehen sind CONSOLE, RAW, TABLE und NONE; NULL, leer oder unbekannt ist ungültig. RAW liefert Modulstatus, Cluster, Mitglieder, Netzwerke, Replikate, Datenbanken, Seeding und Seitenreparatur; NONE unterdrückt diese. CONSOLE wird intern zu NONE und anschließend vom erreichbaren gemeinsamen Console-Adapter für die begrenzte Replikamenge ausgegeben. TABLE unterdrückt normale Sets und schreibt nur replicas. Außerhalb TABLE muss ResultTablesJson NULL oder leer sein. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Außerhalb TABLE löst ein nach Trimmen nichtleerer Wert sofort Fehler 51011 aus; NULL, leer und Whitespace sind erlaubt. Im TABLE-Modus ist genau ein JSON-Objekt mit dem erlaubten Zeichenketten-Schlüssel replicas auf eine bereits angelegte, leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte erforderlich. Doppelte Schlüssel/Ziele, ##Temp und permanente Ziele sind unzulässig; der Name ist auf 116 Zeichen begrenzt. Der Helper prüft die Seed-Struktur durch temporäres Hinzufügen und Entfernen einer Markerspalte. Das Mapping wird vor HELP validiert. Das Präfix #Monitor ist unabhängig von Groß- und Kleinschreibung reserviert. Der Preflight kann vor HELP vorübergehend eine Markerspalte hinzufügen und entfernen. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Nur der nach SQL-Konvertierung vorliegende Wert 1 erzeugt JSON im OUTPUT-Parameter Json; NULL wirkt wie deaktiviert. Der Schalter ist unabhängig vom ResultSetArt-Modus. Der gebundene Wert 0 deaktiviert die JSON-Erzeugung. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Er wird am Eintritt auf NULL gesetzt und nur bei JsonErzeugen=1 befüllt. Das JSON-Objekt hat genau die Schlüssel meta, cluster, members, networks, replicas, databases, seeding und pageRepair; separate Quellenstatus- oder Warning-Arrays werden nicht erzeugt. Ohne Netzwerke-Opt-in ist das networks-Array leer. Binden Sie eine Variable des deklarierten Typs mit OUTPUT.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Die Procedure wertet diesen Parameter nicht aus. Die gebundenen Werte 0, 1 und NULL ändern die Ausgabe nicht. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit; Default: 0. Nur der gebundene bit-Wert 1 gibt die Hilfe mit PRINT aus und kehrt vor der Erfassung zurück. 0 und NULL aktivieren die Hilfe nicht. Json wird vorher auf NULL gesetzt; auch die TABLE-Vorprüfung findet bereits statt. Status- und Fehler-OUTPUTs bleiben beim Hilferücksprung unverändert. Vor HELP wird nur die lokale Replikat-Exporttabelle angelegt; die übrigen Ergebnistabellen folgen erst danach. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Die Procedure setzt den Status vor JSON und den Ausgabeadaptern. AVAILABLE steht für eine erfolgreiche Erfassung ohne Befund, AVAILABLE_WITH_FINDING für eine erfolgreiche Erfassung mit Befund vor der Ausgabegrenze. INVALID_PARAMETER meldet ungültige Schwellen-, Zeilen- oder Ausgabeparameter. NOT_APPLICABLE bedeutet, dass die Instanzprüfung HADR nicht als aktiviert bestätigt. DENIED_PERMISSION ist die CATCH-Klassifikation für SQL-Fehler 229, 297, 300 und 371; ERROR_HANDLED bezeichnet andere abgefangene Erfassungsfehler. HELP und ein früher TABLE-Preflight-Fehler lassen die gebundene Variable unverändert. INVALID_PARAMETER, DENIED_PERMISSION und ERROR_HANDLED setzen IsPartial=1; die übrigen drei Statuswerte lassen IsPartial=0. Im CATCH werden die erfasste Fehlernummer und Meldung weitergegeben; die Zuordnung belegt keine Fehlerursache. Binden Sie eine Variable des deklarierten Typs mit OUTPUT.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Er wird zusammen mit den Statuswerten nach der Erfassung gesetzt; HELP kehrt vorher zurück. Ungültige Parameter und abgefangene Runtimefehler setzen 1; NOT_APPLICABLE lässt den Wert 0. Binden Sie eine Variable des deklarierten Typs mit OUTPUT.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Nur der Runtime-CATCH übernimmt ERROR_NUMBER(); sonst bleibt der Wert NULL. Die Zuweisung erfolgt vor Resultsets; HELP kehrt vorher zurück. Binden Sie eine Variable des deklarierten Typs mit OUTPUT.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Der Runtime-CATCH übernimmt ERROR_MESSAGE(); ungültige Parameter und NOT_APPLICABLE verwenden eine feste deutsche Meldung, regulär verfügbare Statuswerte lassen NULL stehen. Die Zuweisung erfolgt vor Resultsets; HELP kehrt vorher zurück. Binden Sie eine Variable des deklarierten Typs mit OUTPUT.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| replicas | 1 | 1 | [AvailabilityGroupName] sysname NULL , [ReplicaServerName] nvarchar(256) NULL , [IsLocal] bit NULL , [RoleDesc] nvarchar(60) NULL , [OperationalStateDesc] nvarchar(60) NULL , [ConnectedStateDesc] nvarchar(60) NULL , [SynchronizationHealthDesc] nvarchar(60) NULL , [AvailabilityModeDesc] nvarchar(60) NULL , [FailoverModeDesc] nvarchar(60) NULL , [SeedingModeDesc] nvarchar(60) NULL , [FindingCode] varchar(80) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_AvailabilityDeepAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Momentaufnahme; Netzpfad, Clusterlog und Betriebssystemereignisse sind nicht enthalten. Keine Failover- oder Konfigurationsaktion.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_AvailabilityDeepAnalysis
Version      : 1.1.0
Stand        : 2026-07-18
Zweck        : Die Procedure vertieft Always-On-Evidenz um Replikazustand, Warteschlangen,
               Clusterquorum, Seeding und automatische Seitenreparatur.
Datenquellen : sys.availability_groups, sys.availability_replicas,
               sys.dm_hadr_availability_replica_states,
               sys.dm_hadr_database_replica_states, sys.dm_hadr_cluster,
               sys.dm_hadr_cluster_members, optional sys.dm_hadr_cluster_networks,
               sys.dm_hadr_physical_seeding_stats und sys.dm_hadr_auto_page_repair.
Methodik     : Datenbank- und Seedingzustände werden über dieselben reinen
               Interpretationsfunktionen klassifiziert, die auch der
               deterministische Laufzeitvertrag verwendet.
Grenzen      : Momentaufnahme; Netzpfad, Clusterlog und Betriebssystemereignisse
               sind nicht enthalten. Keine Failover- oder Konfigurationsaktion.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_AvailabilityDeepAnalysis
Die Procedure liefert eine rein lesende Always-On-Momentaufnahme und löst weder ein Failover noch eine Konfigurationsänderung aus.
Queue- und Laggrenzen sind Sichtungswerte und keine universellen SLOs.
Cluster-Netzwerkdetails sind ein optionaler Read-only-Katalogpfad.
Beispiel 1: EXEC [monitor].[USP_AvailabilityDeepAnalysis] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_AvailabilityDeepAnalysis] @MitClusterNetzwerken=0, @MaxZeilen=100, @ResultSetArt='RAW';
Beispiel 3: DECLARE @AgDeepJson nvarchar(max); EXEC [monitor].[USP_AvailabilityDeepAnalysis] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@AgDeepJson OUTPUT; SELECT @AgDeepJson AS [Json];
Beispiel 4: CREATE TABLE #AvailabilityDeepAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AvailabilityDeepAnalysis] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"replicas":"#AvailabilityDeepAnalysis_HelpExample"}'; SELECT * FROM #AvailabilityDeepAnalysis_HelpExample; DROP TABLE #AvailabilityDeepAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #AvailabilityDeepAnalysis_HelpExample; THROW; END CATCH;
```


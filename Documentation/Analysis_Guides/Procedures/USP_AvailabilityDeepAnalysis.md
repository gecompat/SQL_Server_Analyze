# [monitor].[USP_AvailabilityDeepAnalysis]

**Bereich:** Infrastruktur<br>
**Zweck:** Vertieft Availability Groups mit Send-/Redo-Queues, Lag, Cluster- und Replica-Evidenz.<br>
**Beobachtungsart:** verteilter, nicht atomarer Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Warum ist eine AG/Replica nicht gesund, welche Datenbewegungsstufe staut und welche Risiken entstehen?** Sie unterstützt die Entscheidung, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AvailabilityDeepAnalysis]
      @MitClusterNetzwerken = 0,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameterverträge

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@QueueWarnMb` | `bigint` | Default: `1024` | Der SQL-bigint-Bereich reicht von -9.223.372.036.854.775.808 bis 9.223.372.036.854.775.807. NULL und negative Werte ergeben INVALID_PARAMETER; 0 ist erlaubt. Der inklusive Sichtungsschwellwert vergleicht COALESCE(Queue-KB, 0) >= decimal(38,0)(MB) * 1024. Die Multiplikation in decimal vermeidet einen bigint-Überlauf. Der Wert ist kein universelles SLO. Die Schwelle gilt getrennt für Send- und Redo-Queue. Bei Schwelle 0 kann auch ein fehlender oder mit 0 gemessener Wert einen Befund auslösen. Suspendierung, ungesunder oder nicht synchronisierender Zustand haben Vorrang. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SecondaryLagWarnSeconds` | `int` | Default: `60` | Der SQL-int-Bereich reicht von -2.147.483.648 bis 2.147.483.647. NULL und negative Werte ergeben INVALID_PARAMETER; 0 ist erlaubt. Der inklusive Vergleich lautet COALESCE(Lagsekunden, 0) >= Grenzwert. Einheit ist Sekunden. Bei Schwelle 0 kann auch ein fehlender oder mit 0 gemessener Wert einen Befund auslösen. Suspendierung, ungesunder oder nicht synchronisierender Zustand haben Vorrang. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MitClusterNetzwerken` | `bit` | Default: `0` | SQL Server konvertiert das Argument vor Aufruf; nur ein Argument, das zu bit 1 wird, liest sys.dm_hadr_cluster_networks. 0 und NULL lassen diese optionale Detailabfrage aus. Dies ist ein Read-only-Katalog-Opt-in, keine Netzwerkerreichbarkeitsprüfung und keine Konfigurationsänderung. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MaxZeilen` | `int` | Default: `1000` | Der SQL-int-Bereich reicht von -2.147.483.648 bis 2.147.483.647. Negative Werte sind ungültig; NULL oder 0 bedeuten durch BIGINT-Maximalwert unbegrenzt. Positive Werte begrenzen die Replikat-Auswahl sowie Mitglieder, Netzwerke, Datenbanken, Seeding und Page Repair bei der Ausgabe; die Cluster-Menge bleibt unbegrenzt. Quellenerfassung und Statusfindings erfolgen vor diesem Ausgabelimit. Einheit ist Zeilen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultSetArt` | `varchar(16)` | Default: `'CONSOLE'` | Nach SQL-Konvertierung werden Leerzeichen an den Rändern entfernt und der Wert großgeschrieben. Vorgesehen sind CONSOLE, RAW, TABLE und NONE; NULL, leer oder unbekannt ist ungültig. RAW liefert Modulstatus, Cluster, Mitglieder, Netzwerke, Replikate, Datenbanken, Seeding und Seitenreparatur; NONE unterdrückt diese. CONSOLE wird intern zu NONE und anschließend vom erreichbaren gemeinsamen Console-Adapter für die begrenzte Replikamenge ausgegeben. TABLE unterdrückt normale Sets und schreibt nur replicas. Außerhalb TABLE muss ResultTablesJson NULL oder leer sein. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultTablesJson` | `nvarchar(max)` | Default: `NULL` | Außerhalb TABLE löst ein nach Trimmen nichtleerer Wert sofort Fehler 51011 aus; NULL, leer und Whitespace sind erlaubt. Im TABLE-Modus ist genau ein JSON-Objekt mit dem erlaubten Zeichenketten-Schlüssel replicas auf eine bereits angelegte, leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte erforderlich. Doppelte Schlüssel/Ziele, ##Temp und permanente Ziele sind unzulässig; der Name ist auf 116 Zeichen begrenzt. Der Helper prüft die Seed-Struktur durch temporäres Hinzufügen und Entfernen einer Markerspalte. Das Mapping wird vor HELP validiert. Das Präfix #Monitor ist unabhängig von Groß- und Kleinschreibung reserviert. Der Preflight kann vor HELP vorübergehend eine Markerspalte hinzufügen und entfernen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@JsonErzeugen` | `bit` | Default: `0` | Nur der nach SQL-Konvertierung vorliegende Wert 1 erzeugt JSON im OUTPUT-Parameter Json; NULL wirkt wie deaktiviert. Der Schalter ist unabhängig vom ResultSetArt-Modus. Der gebundene Wert 0 deaktiviert die JSON-Erzeugung. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Json` | `nvarchar(max) OUTPUT` | Default: `NULL` | Er wird am Eintritt auf NULL gesetzt und nur bei JsonErzeugen=1 befüllt. Das JSON-Objekt hat genau die Schlüssel meta, cluster, members, networks, replicas, databases, seeding und pageRepair; separate Quellenstatus- oder Warning-Arrays werden nicht erzeugt. Ohne Netzwerke-Opt-in ist das networks-Array leer. Binden Sie eine Variable des deklarierten Typs mit OUTPUT. |
| `@PrintMeldungen` | `bit` | Default: `1` | Die Procedure wertet diesen Parameter nicht aus. Die gebundenen Werte 0, 1 und NULL ändern die Ausgabe nicht. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Hilfe` | `bit` | Default: `0` | Nur der gebundene bit-Wert 1 gibt die Hilfe mit PRINT aus und kehrt vor der Erfassung zurück. 0 und NULL aktivieren die Hilfe nicht. Json wird vorher auf NULL gesetzt; auch die TABLE-Vorprüfung findet bereits statt. Status- und Fehler-OUTPUTs bleiben beim Hilferücksprung unverändert. Vor HELP wird nur die lokale Replikat-Exporttabelle angelegt; die übrigen Ergebnistabellen folgen erst danach. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | Default: `NULL` | Die Procedure setzt den Status vor JSON und den Ausgabeadaptern. AVAILABLE steht für eine erfolgreiche Erfassung ohne Befund, AVAILABLE_WITH_FINDING für eine erfolgreiche Erfassung mit Befund vor der Ausgabegrenze. INVALID_PARAMETER meldet ungültige Schwellen-, Zeilen- oder Ausgabeparameter. NOT_APPLICABLE bedeutet, dass die Instanzprüfung HADR nicht als aktiviert bestätigt. DENIED_PERMISSION ist die CATCH-Klassifikation für SQL-Fehler 229, 297, 300 und 371; ERROR_HANDLED bezeichnet andere abgefangene Erfassungsfehler. HELP und ein früher TABLE-Preflight-Fehler lassen die gebundene Variable unverändert. INVALID_PARAMETER, DENIED_PERMISSION und ERROR_HANDLED setzen IsPartial=1; die übrigen drei Statuswerte lassen IsPartial=0. Im CATCH werden die erfasste Fehlernummer und Meldung weitergegeben; die Zuordnung belegt keine Fehlerursache. Binden Sie eine Variable des deklarierten Typs mit OUTPUT. |
| `@IsPartialOut` | `bit OUTPUT` | Default: `NULL` | Er wird zusammen mit den Statuswerten nach der Erfassung gesetzt; HELP kehrt vorher zurück. Ungültige Parameter und abgefangene Runtimefehler setzen 1; NOT_APPLICABLE lässt den Wert 0. Binden Sie eine Variable des deklarierten Typs mit OUTPUT. |
| `@ErrorNumberOut` | `int OUTPUT` | Default: `NULL` | Nur der Runtime-CATCH übernimmt ERROR_NUMBER(); sonst bleibt der Wert NULL. Die Zuweisung erfolgt vor Resultsets; HELP kehrt vorher zurück. Binden Sie eine Variable des deklarierten Typs mit OUTPUT. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | Default: `NULL` | Der Runtime-CATCH übernimmt ERROR_MESSAGE(); ungültige Parameter und NOT_APPLICABLE verwenden eine feste deutsche Meldung, regulär verfügbare Statuswerte lassen NULL stehen. Die Zuweisung erfolgt vor Resultsets; HELP kehrt vorher zurück. Binden Sie eine Variable des deklarierten Typs mit OUTPUT. |

## Aufrufbeispiele zu den Parameterverträgen

Das TABLE-Beispiel erwartet einen freien lokalen Tabellennamen. Es legt das leere Ziel mit einer Seed-Spalte an und entfernt es nach dem Aufruf oder bei einem Aufruffehler.

```sql
EXEC [monitor].[USP_AvailabilityDeepAnalysis] @Hilfe=1;

EXEC [monitor].[USP_AvailabilityDeepAnalysis] @MitClusterNetzwerken=0, @MaxZeilen=100, @ResultSetArt='RAW';

DECLARE @AgDeepJson nvarchar(max); EXEC [monitor].[USP_AvailabilityDeepAnalysis] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@AgDeepJson OUTPUT; SELECT @AgDeepJson AS [Json];

CREATE TABLE #AvailabilityDeepAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AvailabilityDeepAnalysis] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"replicas":"#AvailabilityDeepAnalysis_HelpExample"}'; SELECT * FROM #AvailabilityDeepAnalysis_HelpExample; DROP TABLE #AvailabilityDeepAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #AvailabilityDeepAnalysis_HelpExample; THROW; END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert ausschließlich `replicas` mit elf Feldern und zehn explizit mit `SQL_Latin1_General_CP1_CS_AS` collatierten Textspalten. CONSOLE verwendet den erreichbaren gemeinsamen Console-Adapter für dieselbe begrenzte Replikamenge. RAW liefert Modulstatus, Cluster, Mitglieder, Netzwerke, Replikate, Datenbanken, Seeding und Seitenreparatur; TABLE exportiert nur `replicas`. JSON ist unabhängig davon optional und enthält `meta` sowie die sieben Arrays `cluster`, `members`, `networks`, `replicas`, `databases`, `seeding` und `pageRepair`; separate Quellenstatus- oder Warning-Arrays gehören nicht zu diesem Vertrag. Modulstatus und Partialität sind vor den Fachergebnissen zu lesen. `NOT_APPLICABLE` bedeutet, dass die Instanzprüfung HADR nicht als aktiviert bestätigt hat; `AVAILABLE_WITH_FINDING` bedeutet, dass im vollständigen Scope vor dem Ausgabelimit mindestens ein Finding vorlag. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden. Die Procedure setzt den Status vor JSON und den Ausgabeadaptern. AVAILABLE steht für eine erfolgreiche Erfassung ohne Befund, AVAILABLE_WITH_FINDING für eine erfolgreiche Erfassung mit Befund vor der Ausgabegrenze. INVALID_PARAMETER meldet ungültige Schwellen-, Zeilen- oder Ausgabeparameter. NOT_APPLICABLE bedeutet, dass die Instanzprüfung HADR nicht als aktiviert bestätigt. DENIED_PERMISSION ist die CATCH-Klassifikation für SQL-Fehler 229, 297, 300 und 371; ERROR_HANDLED bezeichnet andere abgefangene Erfassungsfehler. HELP und ein früher TABLE-Preflight-Fehler lassen die gebundene Variable unverändert. INVALID_PARAMETER, DENIED_PERMISSION und ERROR_HANDLED setzen IsPartial=1; die übrigen drei Statuswerte lassen IsPartial=0. Im CATCH werden die erfasste Fehlernummer und Meldung weitergegeben; die Zuordnung belegt keine Fehlerursache.

Nach vollständiger Statusbewertung wird die Replikamenge einmal nach AG- und Replikaservername geordnet und durch `@MaxZeilen` ausgewählt. TABLE, CONSOLE, RAW und JSON verwenden anschließend dieselbe Auswahl. `NULL` und `0` sind unbegrenzt; positive Werte begrenzen. Negative Limits liefern sicher `INVALID_PARAMETER` und leere Fachmengen. Die übrigen RAW-/JSON-Limits bleiben je fachlicher Menge erhalten; Cluster ist weiterhin ohne Zeilenlimit.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Replica-/Datenbank-Beziehung, Queue-/Lagmetrik, Clusterkomponente oder ein Finding.

## So lesen

Berücksichtigen Sie Send Queue, Redo Queue, geschätzte Lagzeit, Synchronisierungszustand, Rolle und Trend gemeinsam.

## Warum kann das problematisch sein?

Wachsende Send Queue weist eher auf Transport/Primary hin; wachsende Redo Queue auf Secondary-Redo, I/O oder CPU.

## Wann ist es kein Problem?

Ein kurzer Peak nach großer Transaktion kann sich normal abbauen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Send Queue stabil klein, Redo Queue wächst über mehrere Messungen: Fokus auf Secondary-I/O/CPU/Redo statt Netzwerk. Prüfen Sie Counter, Storage und Cluster.

**Ähnlich aussehender Gegenfall:** Ein kurzer Peak nach großer Transaktion kann sich normal abbauen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Eine leere Deep-Sicht kann bedeuten, dass keine AG konfiguriert ist oder dass lokale Rolle, Plattform, Version beziehungsweise Berechtigung Cluster-, Seeding- oder Reparatur-DMVs nicht verfügbar machen. Der Modulstatus und seine Partialität kennzeichnen deshalb die Aussagegrenze; ein separater Quellenstatus wird nicht ausgegeben.

Für `USP_AvailabilityDeepAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Lokaler HADR-/Clustersnapshot mit `@MitClusterNetzwerken = 0` und Standardlimit. |
| Teuerster Pfad | Unbegrenzte RAW-Ausgabe mit Cluster-Netzwerken über viele AGs, Replicas, Datenbanken, Seeding- und Page-Repair-Zeilen. |
| Haupttreiber | Zahl lokaler AGs, Replicas und Availability-Datenbanken sowie Seeding-, Auto-Page-Repair-, Cluster- und optional Netzwerkzeilen. Ohne AG-/Datenbankfilter wird dieser lokale Gesamtbestand vor den Resultsetlimits erhoben. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_AvailabilityDeepAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | Geringe bis mittlere CPU für lokale HADR-/Cluster-DMVs und Temp-Tabellen; kein Remotequery, Nutzdaten-, Log- oder Storage-Scan. |
| Begrenzungswirkung | `@MaxZeilen` begrenzt Replikas, Mitglieder, Netzwerke, Datenbankzustände, Seeding und Seitenreparatur bei der Ausgabe. Cluster bleibt ohne Mengenlimit. Die Quellen werden vor den Ausgabelimits erhoben; die zeitliche Nicht-Atomarität bleibt bestehen. |
| Locking und Nebenwirkungen | Read-only. Zustände ändern sich während der verteilten Erfassung; nicht erreichbare Komponenten liefern partielle Evidenz statt eines konsistenten Gesamtsnapshots. |
| Schutzmechanismus | Kein High-Impact-Gate. `@MitClusterNetzwerken = 0` lässt die optionale Netzwerksicht aus, Schwellen priorisieren Findings und `@MaxZeilen` begrenzt die fachlichen Mengen mit Ausnahme von Cluster. Da weder Datenbank- noch AG-Filter existieren, schützt das Limit nicht vor dem vollständigen lokalen HADR-/Cluster-Snapshot. |
| Sicherer Einsatz | Mit `@MitClusterNetzwerken = 0` und Standardlimit beginnen; lokale Rolle dokumentieren und Netzwerkdetails nur bei passender Clusterhypothese aktivieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „verteilter, nicht atomarer Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Warum ist eine AG/Replica nicht gesund, welche Datenbewegungsstufe staut und welche Risiken entstehen?

### Technischer Hintergrund

Vertiefung kombiniert Cluster-/Replica-/Databasezustand, Send/Redo, Flow Control, Suspend Reason, Seeding, Page Repair und gegebenenfalls Read-only Routing. Logproduktion, Capture, Send, Harden und Redo sind getrennte Pipelineabschnitte.

### Datenkette

`sys.availability_groups`, `sys.availability_replicas`, `sys.dm_hadr_auto_page_repair`, `sys.dm_hadr_availability_replica_states`, `sys.dm_hadr_cluster`, `sys.dm_hadr_cluster_members`, `sys.dm_hadr_cluster_networks`, `sys.dm_hadr_database_replica_states`, `sys.dm_hadr_physical_seeding_stats`.

### Source Select

Das Grundselect zeigt die zentrale AG-Kette von Gruppe über Replikat bis zur lokalen Datenbank-Replikatzustandszeile:

```sql
SELECT
      [ag].[name] AS [AvailabilityGroupName]
    , [ar].[replica_server_name]
    , [ars].[role_desc]
    , [d].[name] AS [DatabaseName]
    , [drs].[synchronization_state_desc]
    , [drs].[log_send_queue_size]
    , [drs].[redo_queue_size]
FROM [sys].[availability_groups] AS [ag] WITH (NOLOCK)
JOIN [sys].[availability_replicas] AS [ar] WITH (NOLOCK)
  ON [ar].[group_id] = [ag].[group_id]
LEFT JOIN [sys].[dm_hadr_availability_replica_states] AS [ars] WITH (NOLOCK)
  ON [ars].[replica_id] = [ar].[replica_id]
LEFT JOIN [sys].[dm_hadr_database_replica_states] AS [drs] WITH (NOLOCK)
  ON [drs].[group_id] = [ag].[group_id]
 AND [drs].[replica_id] = [ar].[replica_id]
LEFT JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[database_id] = [drs].[database_id]
WHERE [ag].[name] = N'ExampleAvailabilityGroup';
```

**Wichtig für die Eigenlast:** Gruppe oder Datenbank vor Physical-Seeding- und Auto-Page-Repair-Historie eingrenzen. Die synthetische Gruppe `ExampleAvailabilityGroup` ist nur ein Platzhalter.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen verteilungsabhängigen Snapshot; einige Daten sind nur auf dem Primary oder der lokalen Replica verfügbar.

Common 162 prüft den Leerscope nur bei nativ bestätigtem `IsHadrEnabled=0`. Der Vertrag kontrolliert das Elf-Felder-TABLE-Schema, zehn Textcollations, die acht JSON-Topkeys, Metadaten und leere Arrays sowie die Akzeptanz oder Ablehnung von Parametern. Bei aktiviertem oder unbekanntem HADR meldet er `NOT_EXECUTED`. Leere Mengen liefern keine positive AG-, Replika-, Queue-, Cluster-, Seeding-, Seitenreparatur-, Berechtigungs- oder Limitwirkung. RAW und CONSOLE werden nur über Status und begleitende JSON-Mengen geprüft.

### Bewertung und Gegenprobe

Lokalisieren Sie die Pipeline anhand von Log Send Queue und Redo Queue, Rate und Trend, Connected und Suspended, Last Hardened und Redone, Sync Commit Waits sowie Disk- und Networkkontext. Kennzeichnen Sie eine partielle Sichtbarkeit ausdrücklich.

### Typische Fehlinterpretation

Estimated catch-up time aus Queue/aktueller Rate ist bei Rateänderung instabil. `NOT_HEALTHY` ist Folge, nicht Root Cause.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Current Log/I/O/Waits, Clusterlog, OS-/Netzwerktelemetrie.

## Primärquellen

- [Always On Availability Groups](https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/monitor-availability-groups-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#10-monitorusp_availabilitydeepanalysis)

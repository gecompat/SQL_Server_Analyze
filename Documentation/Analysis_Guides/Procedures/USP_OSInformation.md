# [monitor].[USP_OSInformation]

**Bereich:** Server Health<br>
**Zweck:** Zeigt Betriebssystem, Virtualisierung, Speicher, Zeit, Uptime und Plattformgrenzen.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Betriebssystem-, Host-, Virtualisierungs- und Ressourceninformationen sieht SQL Server?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Externe Linux-cgroup-Gegenprobe

Ein separater [Linux-cgroup-Reader](../Linux_Cgroup_Reader.md) kann die begrenzten cgroup-v2-Werte eines ausdrücklich ausgewählten Linux-Prozesses beobachten. Diese Ausgabe gehört nicht zum SQL-Resultset von `USP_OSInformation` und bindet den Prozess nicht automatisch an die SQL-Instanz. Vergleichen Sie beide Beobachtungen nur mit einer unabhängigen Prüfung der Prozessidentität.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_OSInformation]
      @ResultSetArt = 'CONSOLE';
```

Die Parameterhilfe ohne Datenerhebung zeigt `EXEC [monitor].[USP_OSInformation] @Hilfe = 1;` an.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@PrintMeldungen` | `bit` | `1` | 1 gibt nach der Quellenprüfung bei einem Status ungleich AVAILABLE eine Statusmeldung aus; 0 unterdrückt sie. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1, da nur der Vergleich mit 1 die Ausgabe auslöst. |
| `@Hilfe` | `bit` | `0` | 1 gibt die Parameterhilfe aus und beendet vor den Fachquellen; 0 erhebt Daten. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Bei ResultSetArt TABLE wird der Ziel-Preflight vor der Hilfe ausgeführt. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach Bindung an varchar(16): CONSOLE gibt ausschließlich host unter dem Label OSInformation aus; bei leerer host-Tabelle liefert der Helfer eine Leerzeile; die weiteren Quellresultate stehen in RAW beziehungsweise JSON; RAW liefert technische Resultsets; TABLE exportiert nur host; NONE unterdrückt Resultsets. Äußere U+0020-Leerzeichen werden entfernt, Großschreibung vereinheitlicht; NULL wird leer und ist ungültig. TABLE/CONSOLE werden für reguläre Resultsets zu NONE und separat ausgegeben. Ungültige Werte setzen INVALID_PARAMETER und IsPartial=1; Quellprüfung läuft dennoch. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Bei TABLE ist ein JSON-Objekt mit dem einzelnen Resultatnamen host erforderlich, abgebildet auf eine vorhandene, leere lokale #temp-Tabelle mit genau einer Seed-Spalte. Permanente und globale ##-Tabellen, nichtleere Ziele und Ziele mit fertigem Ausgabeschema werden vom Preflight zurückgewiesen; er läuft vor der Hilfe und Fehler lösen 51011 aus. Außerhalb von TABLE sind NULL, Leertext oder Leerzeichen erlaubt; sonst wird 51011 ausgelöst. |
| `@JsonErzeugen` | `bit` | `0` | 1 erstellt JSON mit meta, sources, host, systemMemory, processMemory, services und warnings als leerem Array; 0 bzw. NULL unterdrückt die Erstellung; numerische 0 bleibt 0 und von 0 verschiedene konvertierbare Zahlen werden bit 1. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück; @Json ist beim Eintritt bereits auf NULL gesetzt. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(max)-Variable binden, z. B. @Json=@j OUTPUT. Der Eingangswert wird zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 wird nach der Sammlung das JSON-Dokument geschrieben; sonst bleibt er NULL. Der Hilfezweig beendet vor der Erzeugung. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine varchar(40)-Variable binden. AVAILABLE bei vier verfügbaren Quellen; PARTIAL bei mindestens einer verfügbaren und einer fehlgeschlagenen Quelle; INVALID_PARAMETER für ungültige ResultSetArt; bei Gesamtausfall DENIED_PERMISSION für Fehler 229/297/300/371, sonst ERROR_HANDLED. Zuweisung nach Quellversuchen, nicht bei Hilfe; eine gebundene, mit NULL initialisierte Variable bleibt NULL. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine bit-Variable binden. 0 bei AVAILABLE, sonst 1 sobald eine Quelle ausfällt oder ResultSetArt ungültig ist. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine int-Variable binden. Fehlernummer des ersten Fehlers aus einer fehlgeschlagenen Quelle; die Auswahl ist ohne explizite Sortierung, sonst NULL; im Hilfezweig keine Zuweisung. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(2048)-Variable binden. Meldung der ersten fehlgeschlagenen Quelle oder Validierungstext, sonst NULL; im Hilfezweig keine Zuweisung. |

```sql
EXEC [monitor].[USP_OSInformation] @ResultSetArt = 'RAW';
```

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_OSInformation]
      @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT;
SELECT @Json AS [Json];
```

```sql
CREATE TABLE [#OSInformation_HelpExample]([Seed] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_OSInformation]
          @ResultSetArt = 'TABLE'
        , @ResultTablesJson = N'{"host":"#OSInformation_HelpExample"}';
END TRY
BEGIN CATCH
    DROP TABLE [#OSInformation_HelpExample];
    THROW;
END CATCH;
DROP TABLE [#OSInformation_HelpExample];
```

```sql
EXEC [monitor].[USP_OSInformation] @Hilfe = 1;
```

## Resultsets und Leserichtung

Der TABLE-Vertrag exportiert host. Bei RAW steht das Modulstatusresultset vor den Fachergebnissen; CONSOLE liefert nur die jeweilige lesbare Fachansicht und TABLE schreibt nur das benannte Ziel. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine OS-/Plattformeigenschaft oder eine Zusammenfassung.

## So lesen

Berücksichtigen Sie OS-Version, Virtualisierung, Speicher, Zeit, Uptime und Plattform gemeinsam.

## Warum kann das problematisch sein?

Sehr geringe Uptime erklärt resetete DMVs; Zeitabweichungen erschweren Ereigniskorrelation; Memory-/VM-Grenzen beeinflussen SQL.

## Wann ist es kein Problem?

Virtualisierung ist nicht automatisch langsam.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Index Usage zeigt 0 Reads, OS Uptime zwei Stunden: Beobachtungsfenster zu kurz für eine Löschung. Korrelieren Sie CPU, Memory, I/O und Hypervisor-Monitoring.

**Ähnlich aussehender Gegenfall:** Virtualisierung ist nicht automatisch langsam. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für USP_OSInformation bedeutet eine fehlende Host-, Speicher- oder Dienstzeile, dass die betreffende Quelltabelle keine ausgabefähige Zeile lieferte; prüfen Sie dazu den Eintrag in sources. Die vier Quellen werden unabhängig abgefragt und es gibt kein Zeilenlimit. Mindestens ein Quellenfehler bei gleichzeitig erfolgreicher Quelle ergibt PARTIAL; bei Gesamtausfall gilt der Status der ersten fehlgeschlagenen Quelle ohne explizite Sortierung. NULL ist kein gemessener Nullwert.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Liest vier unabhängige Quellen: Host, OS-Speicher, SQL-Prozessspeicher und Dienststatus. Jede Quelle hat eigenen Status, sodass fehlende Serviceberechtigung die Memorysicht nicht verdeckt. |
| Teuerster Pfad | Kein Deep-Pfad. RAW/JSON geben alle vier kleinen Resultsets plus SourceStatus aus; die Zahl SQL-bezogener Dienste ist gewöhnlich einstellig. |
| Haupttreiber | Feste Ein-Zeilen-DMVs und Zahl der SQL-Dienste in `sys.dm_server_services`. Datenbanken, Sessions und OS-Prozesse außerhalb SQL Server werden nicht enumeriert. |
| Skalierung | Praktisch konstant pro Instanz. Serialisierung wächst gering mit Dienstzeilen; Memorygröße beeinflusst nur Werte, nicht Abfragearbeit. |
| Ressourcen | Vier kurze SQLOS-/Service-DMV-Lesezugriffe und kleine Temp-Tabellen. Kein WMI, Registryscan, Dateisystem-I/O oder WAITFOR. |
| Begrenzungswirkung | Kein Scope-/Zeilenlimit nötig. `NONE` unterdrückt Resultsets, die vier Quellen werden für Status/JSON-Vertrag weiterhin versucht. |
| Locking und Nebenwirkungen | Read-only ohne Nutzdatenlocks. Speicherzustand und Dienststatus sind getrennte Momentaufnahmen; partieller SourceStatus ist erwartbarer als ein Abbruch des Gesamtmoduls. |
| Schutzmechanismus | Kein Gate und kein Scopeparameter. Die Procedure ist durch vier fest gewählte SQL-seitige Quellen mit eigener Statusbehandlung begrenzt; sie startet weder WMI-/Shellaufrufe noch eine Enumeration fremder Prozesse oder Dateisysteme. |
| Sicherer Einsatz | CONSOLE direkt nutzen; Dienstkonto, Prozess-ID und Hostdetails aus RAW/JSON nur im geschützten Betriebskontext teilen. SourceStatus je Teilquelle mit speichern. |
| Aussagegrenze | Die Procedure zeigt SQL-seitig sichtbare OS-/Prozesswerte, keine vollständige Hosttelemetrie, VM-Steal-Time oder Containerlimits. Ein momentaner Low-Memory-Flag benötigt Verlauf und OS-Gegenprobe. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Betriebssystem-, Host-, Virtualisierungs- und Ressourceninformationen sieht SQL Server?

### Technischer Hintergrund

Host-/Windows-/Linux-DMVs liefern OS-Version, Hostplattform, Memory/Pagefile, Startzeit und Virtualization/Containerhinweise soweit verfügbar. SQL Server sieht im Gast nicht zwingend Hypervisor-Steal, SAN- oder Hostcontention vollständig.

### Datenkette

`sys.dm_os_host_info`, `sys.dm_os_process_memory`, `sys.dm_os_sys_memory`, `sys.dm_server_services`.

### Source Select

Die wichtigsten Host-, System- und Prozessspeicherwerte sind jeweils Singleton-DMVs und können ohne Nutzdatenjoin kombiniert werden:

```sql
SELECT
      [h].[host_platform]
    , [h].[host_distribution]
    , [sm].[total_physical_memory_kb]
    , [sm].[available_physical_memory_kb]
    , [pm].[physical_memory_in_use_kb]
    , [pm].[process_physical_memory_low]
FROM [sys].[dm_os_host_info] AS [h] WITH (NOLOCK)
CROSS JOIN [sys].[dm_os_sys_memory] AS [sm] WITH (NOLOCK)
CROSS JOIN [sys].[dm_os_process_memory] AS [pm] WITH (NOLOCK);
```

**Wichtig für die Eigenlast:** Diese Quellen liefern wenige Zeilen. Dienstinformationen aus `sys.dm_server_services` sind ein getrennter kleiner Zweig; es werden keine OS-Dateien oder externen Befehle ausgeführt.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Gast-/Instanzkontext; OS-/Engine-Startzeiten können verschieden sein.

### Bewertung und Gegenprobe

Korrelieren Sie Betriebssystem- und Buildsupport, virtuelle beziehungsweise physische Plattform, Memory und Commit, Pagefile, Uptime und Instanzbuild. Ergänzen Sie für eine Performanceanalyse CPU-, Storage- und Memorytelemetrie außerhalb von SQL Server.

### Typische Fehlinterpretation

Unauffällige Gastwerte schließen Hostengpass nicht aus. Pagefile vorhanden/benutzt ist allein keine SQL-Memorydiagnose.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Server CPU/Memory/IO und OS-/Hypervisormonitoring.

## Primärquellen

- [sys.dm_os_host_info](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-host-info-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#8-monitorusp_osinformation)

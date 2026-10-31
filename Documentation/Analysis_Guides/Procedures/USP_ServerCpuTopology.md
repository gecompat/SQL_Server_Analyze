# [monitor].[USP_ServerCpuTopology]

**Bereich:** Server Health<br>
**Zweck:** Zeigt CPU-, Socket-, Core-, Scheduler- und NUMA-Topologie.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche CPU-, Socket-, Core-, Hyperthread-, Scheduler- und Affinitystruktur sieht SQL Server?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerCpuTopology]
      @ResultSetArt = 'CONSOLE';
```

Die Parameterhilfe ohne Datenerhebung zeigt `EXEC [monitor].[USP_ServerCpuTopology] @Hilfe = 1;` an.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@PrintMeldungen` | `bit` | `1` | Bei 1 (auch Default) wird bei einem Status ungleich AVAILABLE eine Meldung niedriger Severity mit dem Fehlertext ausgegeben; 0 unterdrückt sie. NULL löst die IF-Bedingung ebenfalls nicht aus. Die Meldung erfolgt nach Befüllung der OUTPUT-Parameter und vor den Resultsets. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1. |
| `@Hilfe` | `bit` | `0` | 0 oder NULL nimmt den normalen Analysepfad. 1 gibt die PRINT-Hilfe aus und kehrt vor Quellzugriff, regulärer Statusinitialisierung und allen vier Status-/Fehler-OUTPUT-Zuweisungen zurück. Zuvor laufen ein angeforderter TABLE-Preflight oder die Ablehnung eines nicht leeren TABLE-Mappings außerhalb TABLE; diese können bereits werfen. @Json ist beim Eintritt auf NULL gesetzt. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach Trim von U+0020-Leerzeichen und UPPER gelten CONSOLE, RAW, TABLE und NONE; NULL wird wie leer behandelt. CONSOLE gibt nur die Console-Helferausgabe der ersten Fachquelle aus, ohne separates Modulstatusresultset; eine Leerzeile des Helfers hat hier NULL für Status und Hinweis. RAW gibt Modulstatus und unbeschriftete Fachresultsets aus. TABLE schreibt ausschließlich die benannte Fachmenge in das gemappte Ziel und gibt kein separates Modulstatusresultset aus. NONE unterdrückt Resultsets. CONSOLE und TABLE werden vor dem regulären Ausgabezweig intern zu NONE. Andere Texte, leer und NULL ergeben INVALID_PARAMETER/IsPartial=1; der nicht normalisierte ungültige Modus gibt dennoch Modulstatus und beschriftete Fachresultsets des ELSE-Zweigs aus. JSON ist davon unabhängig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Als TABLE-Eingabe ist ein JSON-Objekt mit genau einem Mapping für den registrierten Namen cpuTopology auf eine vorhandene, leere lokale #temp-Tabelle nötig; diese muss genau eine Seed-/Platzhalterspalte besitzen. Das Ziel wird vor Hilfe und Quellerhebung geprüft; fehlerhafte oder fehlende TABLE-Ziele werfen beim Preflight Fehler 51011, daher werden Status-OUTPUTs nicht regulär gesetzt. Außerhalb von TABLE sind nur NULL, leer oder Leerzeichen erlaubt; jeder andere Inhalt wirft Fehler 51011 vor Hilfe und OUTPUT-Zuweisung. |
| `@JsonErzeugen` | `bit` | `0` | Im normalen Pfad erzeugt 1 unabhängig von @ResultSetArt das JSON-Dokument in @Json; 0 oder NULL erzeugt keines. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück. Leere Fachmengen werden als leere Arrays ausgegeben. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Empfänger für das JSON-Dokument; bei Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Bindung erfolgt optional mit @Json=@Empfaenger OUTPUT; die Empfängervariable muss nvarchar(max) sein. Ohne OUTPUT-Bindung wird kein Rückgabewert an eine Aufrufervariable übertragen. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger für AVAILABLE, INVALID_PARAMETER, DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED. AVAILABLE bedeutet kein abgefangener Quellfehler und keine festgestellte ungültige Eingabe; INVALID_PARAMETER bezeichnet ungültige ResultSetArt; DENIED_PERMISSION klassifiziert Quellfehler 229, 297, 300 oder 371; TIMEOUT klassifiziert Fehler 1222; ERROR_HANDLED steht für sonstige im Quell-TRY abgefangene Fehler. Bei Quellfehlern ist IsPartial=1. Bindung z.B. @StatusCodeOut=@Status OUTPUT mit varchar(40)-Variable. Zuweisung geschieht nach Quellversuch/Validierung, vor Meldung und Resultsetausgabe; bei frühem Preflight-THROW oder Hilfe keine reguläre Zuweisung. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER und bei abgefangenen Quellfehlern. Das Bit bezeichnet den implementierten Status-/Fehlerpfad, nicht Vollständigkeit einzelner leerer Quellgruppen. Bindung z.B. @IsPartialOut=@Partial OUTPUT mit bit-Variable; Zuweisung gemeinsam mit StatusCodeOut vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger für die SQL-Fehlernummer eines im Quell-TRY abgefangenen Fehlers; bei AVAILABLE und INVALID_PARAMETER bleibt der Wert NULL. Die bekannten Berechtigungs-/Timeoutnummern werden zugleich klassifiziert. Bindung z.B. @ErrorNumberOut=@ErrorNumber OUTPUT mit int-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger für den Text des im Quell-TRY abgefangenen Fehlers oder die konkrete INVALID_PARAMETER-Begründung; bei AVAILABLE bleibt er NULL. Bindung z.B. @ErrorMessageOut=@ErrorMessage OUTPUT mit nvarchar(2048)-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen. |

**RAW:**

```sql
EXEC [monitor].[USP_ServerCpuTopology] @ResultSetArt=N'RAW';
```

**JSON:**

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_ServerCpuTopology] @JsonErzeugen=1,@Json=@Json OUTPUT,@ResultSetArt=N'NONE';
SELECT @Json AS [JsonDocument];
```

**TABLE:**

```sql
CREATE TABLE [#ServerCpuTopology_HelpExample]([Seed] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_ServerCpuTopology] @ResultSetArt=N'TABLE',@ResultTablesJson=N'{"cpuTopology":"#ServerCpuTopology_HelpExample"}';
END TRY
BEGIN CATCH
    DROP TABLE [#ServerCpuTopology_HelpExample];
    THROW;
END CATCH;
DROP TABLE [#ServerCpuTopology_HelpExample];
```

**Hilfe:**

```sql
EXEC [monitor].[USP_ServerCpuTopology] @Hilfe=1;
```

## Resultsets und Leserichtung

Der TABLE-Vertrag registriert ausschließlich `cpuTopology`. RAW liefert nach dem Modulstatus die unbeschrifteten Fachergebnissets; CONSOLE liefert ohne separates Modulstatusresultset eine Console-Ausgabe der CPU-Topologie, JSON enthält Meta, die Arrays Scheduler und NUMA-Nodes und ein leeres warnings-Array. TABLE schreibt ausschließlich `cpuTopology`. Die JSON-Erzeugung im normalen Pfad ist unabhängig von @ResultSetArt; Hilfe kehrt davor zurück; NONE unterdrückt reguläre Resultsets, nicht aber JSON, wenn @JsonErzeugen=1. Die Resultsets besitzen unterschiedliche Zeilengranularitäten und dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Topologiezusammenfassung, einen Scheduler oder einen NUMA-Knoten.

## So lesen

Vergleichen Sie logische CPUs, Sockets, Cores, sichtbare/online Scheduler, Soft-NUMA und aktuelle Last.

## Warum kann das problematisch sein?

Unerwartet offline oder hidden Scheduler und ungewöhnliche Topologie können Parallelität, Lizenzierung und Lastverteilung beeinflussen.

## Wann ist es kein Problem?

Soft-NUMA und bestimmte Schedulerzustände können absichtlich von SQL Server erzeugt werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 64 OS-CPUs, aber 32 online sichtbar: Lizenz-, Affinity-, Edition- und VM-Kontext prüfen, nicht sofort Hardwarefehler annehmen. Korrelieren Sie NUMA und OS.

**Ähnlich aussehender Gegenfall:** Soft-NUMA und bestimmte Schedulerzustände können absichtlich von SQL Server erzeugt werden. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für diese Procedure bedeutet **keine Zeile**, dass die jeweilige Quelle im sichtbaren und gefilterten Scope keinen Datensatz lieferte; **0** bleibt ein gemessener Wert, **NULL** kennzeichnet unbekannt oder nicht anwendbar. Die Statusausgabe kennzeichnet INVALID_PARAMETER oder einen abgefangenen Quellfehler als partiell. Die Procedure setzt kein Zeilenlimit; bei einem Quellfehler können bereits gelesene Tabellen gefüllt sein, während spätere Tabellen leer bleiben.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Liest eine `dm_os_sys_info`-Topologiezeile, gruppiert alle regulären Scheduler nach Node/Status und ergänzt SQLOS-Nodes. Keine Option verändert den Quellpfad. |
| Teuerster Pfad | RAW/JSON geben zusätzlich Scheduler- und Nodegrids aus, doch die gleiche kleine DMV-Menge wurde bereits erhoben. Es gibt kein Sample, Cross-Database oder Detailscan. |
| Haupttreiber | Anzahl der Scheduler und Nodes; physische Datenmenge oder Workloadhistorie spielen keine Rolle. Interne Scheduler ab ID 1048576 und der DAC-Node werden ausgeschlossen. |
| Skalierung | Der Scheduler-Scan ist linear, Gruppierung/Sortierung klein. Die Instanzsummary bleibt eine Zeile, Nodes/Schedulergruppen wachsen nur mit Hardware-/SQLOS-Topologie. |
| Ressourcen | Geringe CPU auf drei SQLOS-DMVs und kleine Temp-Tabellen. Kein Katalog-I/O, XML, WAITFOR oder Ergebnistexte. |
| Begrenzungswirkung | Kein `@MaxZeilen`, weil vollständige Topologie benötigt wird. CONSOLE/TABLE zeigen primär `cpuTopology`; RAW/JSON machen die bereits erhobenen Details sichtbar. |
| Locking und Nebenwirkungen | Read-only ohne Nutzdatenlocks. Topologie ist meist stabil, momentane Task-/Runnable-Zähler können sich während der drei Abfragen ändern. |
| Schutzmechanismus | Kein Gate und bewusst kein Zeilenlimit. Der feste Pfad liest eine Topologiezeile sowie die reale Scheduler-/Node-Menge; keine Option öffnet Sampling, Cross-Database- oder Detailfunktionen. |
| Sicherer Einsatz | CONSOLE ist vollständig und kostengünstig. Runnable-Findings nur zusammen mit wiederholter CPU-/Waitmessung und dem NUMA-Child bewerten. |
| Aussagegrenze | SQL Server meldet seine sichtbare Topologie, nicht zwingend die physische Host-/VM-Zuordnung. Ein einzelner Runnable Task ist kein Beweis für CPU-Sättigung; Affinity und Soft-NUMA benötigen Kontext. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche CPU-, Socket-, Core-, Hyperthread-, Scheduler- und Affinitystruktur sieht SQL Server?

### Technischer Hintergrund

SQL Server erstellt SQLOS-Scheduler für sichtbare logische CPUs unter Berücksichtigung von Edition, Lizenz-/Affinitykonfiguration und Onlinezustand. Sockets, NUMA Nodes, Cores und Hyperthreading beeinflussen Parallelität, Lizenzierung und Memorylocality.

### Datenkette

`sys.dm_os_nodes`, `sys.dm_os_schedulers`, `sys.dm_os_sys_info`.

### Source Select

Die momentane Schedulerlast wird nach NUMA-Parent-Node gruppiert und mit dem Nodekatalog verbunden:

```sql
SELECT
      [n].[node_id]
    , [n].[node_state_desc]
    , COUNT_BIG(*) AS [SchedulerCount]
    , SUM(CONVERT(bigint, [s].[runnable_tasks_count])) AS [RunnableTasks]
    , SUM(CONVERT(bigint, [s].[active_workers_count])) AS [ActiveWorkers]
FROM [sys].[dm_os_nodes] AS [n] WITH (NOLOCK)
LEFT JOIN [sys].[dm_os_schedulers] AS [s] WITH (NOLOCK)
  ON [s].[parent_node_id] = [n].[node_id]
 AND [s].[scheduler_id] < 1048576
WHERE [n].[node_state_desc] <> N'ONLINE DAC'
GROUP BY [n].[node_id], [n].[node_state_desc];
```

**Wichtig für die Eigenlast:** DAC- und interne Scheduler bereits an der Quelle ausschließen. Die DMVs sind klein; Werte sind ein flüchtiger Snapshot und keine CPU-Historie.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Instanz-/Startzustand; Hardwarezuweisung in VM/Container kann sich erst nach Neustart vollständig widerspiegeln.

### Bewertung und Gegenprobe

Berücksichtigen Sie Visible und Online Schedulers, Physical und Logical CPU, das Socket-Core-Verhältnis, Hyperthread Ratio, Affinity und Edition gemeinsam. Eine ungleiche Schedulerverfügbarkeit oder eine unerwartete CPU-Anzahl ist ein Konfigurationshinweis.

### Typische Fehlinterpretation

Viele CPUs bedeuten nicht automatisch mehr Queryleistung. MAXDOP, Cost Threshold, NUMA, Lizenzgrenze und Workloadparallelität bestimmen Nutzung.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_ServerNuma`, Performance Counters, Current Requests/Waits.

## Primärquellen

- [sys.dm_os_sys_info](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-sys-info-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#1-monitorusp_servercputopology)

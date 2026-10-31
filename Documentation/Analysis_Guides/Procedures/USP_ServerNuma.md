# [monitor].[USP_ServerNuma]

**Bereich:** Server Health<br>
**Zweck:** Zeigt NUMA-Nodes, Schedulerverteilung und Memory-Node-Kontext.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Wie sind Scheduler und Memory auf SQLOS-/Hardware-NUMA-Nodes verteilt und gibt es sichtbare Ungleichgewichte?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerNuma]
      @ResultSetArt = 'CONSOLE';
```

Die Parameterhilfe ohne Datenerhebung zeigt `EXEC [monitor].[USP_ServerNuma] @Hilfe = 1;` an.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@PrintMeldungen` | `bit` | `1` | Bei 1 (auch Default) wird bei einem Status ungleich AVAILABLE eine Meldung niedriger Severity mit dem Fehlertext ausgegeben; 0 unterdrückt sie. NULL löst die IF-Bedingung ebenfalls nicht aus. Die Meldung erfolgt nach Befüllung der OUTPUT-Parameter und vor den Resultsets. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1. |
| `@Hilfe` | `bit` | `0` | 0 oder NULL nimmt den normalen Analysepfad. 1 gibt die PRINT-Hilfe aus und kehrt vor Quellzugriff, regulärer Statusinitialisierung und allen vier Status-/Fehler-OUTPUT-Zuweisungen zurück. Zuvor laufen ein angeforderter TABLE-Preflight oder die Ablehnung eines nicht leeren TABLE-Mappings außerhalb TABLE; diese können bereits werfen. @Json ist beim Eintritt auf NULL gesetzt. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach Trim von U+0020-Leerzeichen und UPPER gelten CONSOLE, RAW, TABLE und NONE; NULL wird wie leer behandelt. CONSOLE gibt nur die Console-Helferausgabe der ersten Fachquelle aus, ohne separates Modulstatusresultset; eine Leerzeile des Helfers hat hier NULL für Status und Hinweis. RAW gibt Modulstatus und unbeschriftete Fachresultsets aus. TABLE schreibt ausschließlich die benannte Fachmenge in das gemappte Ziel und gibt kein separates Modulstatusresultset aus. NONE unterdrückt Resultsets. CONSOLE und TABLE werden vor dem regulären Ausgabezweig intern zu NONE. Andere Texte, leer und NULL ergeben INVALID_PARAMETER/IsPartial=1; der nicht normalisierte ungültige Modus gibt dennoch Modulstatus und beschriftete Fachresultsets des ELSE-Zweigs aus. JSON ist davon unabhängig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Als TABLE-Eingabe ist ein JSON-Objekt mit genau einem Mapping für den registrierten Namen numaNodes auf eine vorhandene, leere lokale #temp-Tabelle nötig; diese muss genau eine Seed-/Platzhalterspalte besitzen. Das Ziel wird vor Hilfe und Quellerhebung geprüft; fehlerhafte oder fehlende TABLE-Ziele werfen beim Preflight Fehler 51011, daher werden Status-OUTPUTs nicht regulär gesetzt. Außerhalb von TABLE sind nur NULL, leer oder Leerzeichen erlaubt; jeder andere Inhalt wirft Fehler 51011 vor Hilfe und OUTPUT-Zuweisung. |
| `@JsonErzeugen` | `bit` | `0` | Im normalen Pfad erzeugt 1 unabhängig von @ResultSetArt das JSON-Dokument in @Json; 0 oder NULL erzeugt keines. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück. Leere Fachmengen werden als leere Arrays ausgegeben. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Empfänger für das JSON-Dokument; bei Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Bindung erfolgt optional mit @Json=@Empfaenger OUTPUT; die Empfängervariable muss nvarchar(max) sein. Ohne OUTPUT-Bindung wird kein Rückgabewert an eine Aufrufervariable übertragen. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger für AVAILABLE, INVALID_PARAMETER, DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED. AVAILABLE bedeutet kein abgefangener Quellfehler und keine festgestellte ungültige Eingabe; INVALID_PARAMETER bezeichnet ungültige ResultSetArt; DENIED_PERMISSION klassifiziert Quellfehler 229, 297, 300 oder 371; TIMEOUT klassifiziert Fehler 1222; ERROR_HANDLED steht für sonstige im Quell-TRY abgefangene Fehler. Bei Quellfehlern ist IsPartial=1. Bindung z.B. @StatusCodeOut=@Status OUTPUT mit varchar(40)-Variable. Zuweisung geschieht nach Quellversuch/Validierung, vor Meldung und Resultsetausgabe; bei frühem Preflight-THROW oder Hilfe keine reguläre Zuweisung. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER und bei abgefangenen Quellfehlern. Das Bit bezeichnet den implementierten Status-/Fehlerpfad, nicht Vollständigkeit einzelner leerer Quellgruppen. Bindung z.B. @IsPartialOut=@Partial OUTPUT mit bit-Variable; Zuweisung gemeinsam mit StatusCodeOut vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger für die SQL-Fehlernummer eines im Quell-TRY abgefangenen Fehlers; bei AVAILABLE und INVALID_PARAMETER bleibt der Wert NULL. Die bekannten Berechtigungs-/Timeoutnummern werden zugleich klassifiziert. Bindung z.B. @ErrorNumberOut=@ErrorNumber OUTPUT mit int-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger für den Text des im Quell-TRY abgefangenen Fehlers oder die konkrete INVALID_PARAMETER-Begründung; bei AVAILABLE bleibt er NULL. Bindung z.B. @ErrorMessageOut=@ErrorMessage OUTPUT mit nvarchar(2048)-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen. |

**RAW:**

```sql
EXEC [monitor].[USP_ServerNuma] @ResultSetArt=N'RAW';
```

**JSON:**

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_ServerNuma] @JsonErzeugen=1,@Json=@Json OUTPUT,@ResultSetArt=N'NONE';
SELECT @Json AS [JsonDocument];
```

**TABLE:**

```sql
CREATE TABLE [#ServerNuma_HelpExample]([Seed] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_ServerNuma] @ResultSetArt=N'TABLE',@ResultTablesJson=N'{"numaNodes":"#ServerNuma_HelpExample"}';
END TRY
BEGIN CATCH
    DROP TABLE [#ServerNuma_HelpExample];
    THROW;
END CATCH;
DROP TABLE [#ServerNuma_HelpExample];
```

**Hilfe:**

```sql
EXEC [monitor].[USP_ServerNuma] @Hilfe=1;
```

## Resultsets und Leserichtung

Der TABLE-Vertrag registriert ausschließlich `numaNodes`. RAW liefert nach dem Modulstatus die unbeschrifteten Fachergebnissets; CONSOLE liefert ohne separates Modulstatusresultset eine Console-Ausgabe der NUMA-Nodes, JSON enthält Meta, die Arrays Memory Nodes und ein leeres warnings-Array. TABLE schreibt ausschließlich `numaNodes`. Die JSON-Erzeugung im normalen Pfad ist unabhängig von @ResultSetArt; Hilfe kehrt davor zurück; NONE unterdrückt reguläre Resultsets, nicht aber JSON, wenn @JsonErzeugen=1. Die Resultsets besitzen unterschiedliche Zeilengranularitäten und dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem NUMA-/Memory-Node oder einem Scheduler.

## So lesen

Vergleichen Sie Schedulerzahl, Online-/Idle-Zustand, Memory Node, Foreign Memory und Last je Node.

## Warum kann das problematisch sein?

Persistente Asymmetrie kann lokale CPU-Engpässe und Remote-Memory-Zugriffe begünstigen.

## Wann ist es kein Problem?

Momentan unterschiedliche Last je Node ist normal; erst wiederholte Asymmetrie ist belastbar.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Wenn ein Node dauerhaft voll ausgelastet ist, ein anderer nahezu idle bleibt und Sessions konzentriert sind, müssen Affinity, Verbindungslast, Soft-NUMA und Schedulerwaits geprüft werden.

**Ähnlich aussehender Gegenfall:** Momentan unterschiedliche Last je Node ist normal; erst wiederholte Asymmetrie ist belastbar. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für diese Procedure bedeutet **keine Zeile**, dass die jeweilige Quelle im sichtbaren und gefilterten Scope keinen Datensatz lieferte; **0** bleibt ein gemessener Wert, **NULL** kennzeichnet unbekannt oder nicht anwendbar. Die Statusausgabe kennzeichnet INVALID_PARAMETER oder einen abgefangenen Quellfehler als partiell. Die Procedure setzt kein Zeilenlimit; bei einem Quellfehler können bereits gelesene Tabellen gefüllt sein, während spätere Tabellen leer bleiben.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Aggregiert sichtbare Scheduler je Parent-NUMA-Node und liest anschließend SQLOS- sowie Memory-Nodes. RAW/JSON zeigen beide Granularitäten, TABLE nur `numaNodes`. |
| Teuerster Pfad | Es gibt keinen optionalen Deep-Pfad. Die maximale Quellmenge ist durch Scheduler- und Nodezahl der Instanz begrenzt; auch große Server bleiben gegenüber Workload-DMVs klein. |
| Haupttreiber | Zahl der SQLOS-Scheduler und NUMA-/Memory-Nodes. `scheduler_id >= 1048576` und der DAC-Node werden aus der fachlichen Sicht ausgeschlossen; Memory Nodes sind auf IDs unter 64 begrenzt. |
| Skalierung | Ein vollständiger Scheduler-Snapshot wird nach Parent gruppiert; CPU wächst linear mit der Schedulerzahl, Resultzeilen nur mit Nodes. |
| Ressourcen | Geringe SQLOS-DMV-CPU und kleine Temp-Tabellen. Keine Datenbankkataloge, Historie, XML oder Samplingverbindung. |
| Begrenzungswirkung | Es existiert kein Zeilen-/Scopeparameter, weil eine Teilmenge der NUMA-Topologie irreführend wäre. Ausgabeunterdrückung mit `NONE` spart die Quellerhebung nicht. |
| Locking und Nebenwirkungen | Read-only ohne Nutzdatenlocks. Schedulerlast kann sich zwischen Scheduler- und Nodeabfrage ändern; `RunnablePerScheduler` bleibt ein Momentwert, keine Intervallrate. |
| Schutzmechanismus | Kein Gate und bewusst kein Teil-Scope. Die reale Scheduler-/SQLOS-/Memory-Node-Zahl begrenzt die Quelle konstruktiv; eine künstliche TOP-Auswahl würde die Topologie eher verfälschen als die ohnehin kleine Abfrage sinnvoll schützen. |
| Sicherer Einsatz | CONSOLE direkt verwenden und Runnable-Signale mit wiederholten Messpunkten sowie CPU-/Wait-Evidenz gegenprüfen; ein eigener Scope ist nicht erforderlich. |
| Aussagegrenze | Der Snapshot zeigt SQLOS-Zuordnung und momentane Runnable Tasks, aber weder historische CPU-Sättigung noch VM-vNUMA-/Hosttopologie. Ein einzelner unbalancierter Moment beweist kein dauerhaftes NUMA-Problem. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie sind Scheduler und Memory auf SQLOS-/Hardware-NUMA-Nodes verteilt und gibt es sichtbare Ungleichgewichte?

### Technischer Hintergrund

NUMA hält CPU und lokal angebundenes Memory zusammen. SQLOS-Nodes/Scheduler verteilen Workers; Memory Nodes verwalten Locality. Soft-NUMA kann zusätzliche logische Gruppen erzeugen. Remote Memory Access kann teurer sein.

### Datenkette

`sys.dm_os_memory_nodes`, `sys.dm_os_nodes`, `sys.dm_os_schedulers`.

### Source Select

Scheduler werden nach Parent-Node aggregiert und dem NUMA-Node zugeordnet:

```sql
SELECT
      [n].[node_id]
    , [n].[memory_node_id]
    , [n].[node_state_desc]
    , COUNT_BIG([s].[scheduler_id]) AS [SchedulerCount]
    , SUM(CONVERT(bigint, [s].[runnable_tasks_count])) AS [RunnableTasks]
    , SUM(CONVERT(bigint, [s].[active_workers_count])) AS [ActiveWorkers]
FROM [sys].[dm_os_nodes] AS [n] WITH (NOLOCK)
LEFT JOIN [sys].[dm_os_schedulers] AS [s] WITH (NOLOCK)
  ON [s].[parent_node_id] = [n].[node_id]
 AND [s].[scheduler_id] < 1048576
WHERE [n].[node_state_desc] <> N'ONLINE DAC'
GROUP BY [n].[node_id], [n].[memory_node_id], [n].[node_state_desc];
```

**Wichtig für die Eigenlast:** Interne/DAC-Scheduler an der Quelle ausschließen. `sys.dm_os_memory_nodes` ist eine separate Zeilengranularität und wird nur über Node-IDs interpretiert, nicht ungeprüft mit Schedulerzählern summiert.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Node-/Schedulerzustand; Loadcounter sind Momentaufnahme oder kumulativ je Quelle.

### Bewertung und Gegenprobe

Vergleichen Sie Online/Idle Schedulers, Runnable Tasks, Active Workers, Load Factor, Memory Nodezuordnung und wiederholte Samples. Ein persistentes einseitiges Muster ist relevanter als ein Snapshot.

### Typische Fehlinterpretation

Ungleiche Momentaufnahme ist bei zufälliger Workload normal. Node ID ist kein direkter physischer Socketbeweis bei Soft-NUMA/VM.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_ServerCpuTopology`, Current Requests und Server Memory.

## Primärquellen

- [sys.dm_os_nodes](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-nodes-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#2-monitorusp_servernuma)

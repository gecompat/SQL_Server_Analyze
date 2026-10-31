# [monitor].[USP_ServerMemory]

**Bereich:** Server Health<br>
**Zweck:** Verknüpft OS-, SQL-Prozess-, Target-/Total-Memory- und Clerk-Evidenz.<br>
**Beobachtungsart:** Snapshot + kumulative Runtimezähler<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Hat SQL Server oder das Betriebssystem Memory Pressure, und welche Clerks/Komponenten verwenden Speicher?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerMemory]
      @ResultSetArt = 'CONSOLE';
```

Die Parameterhilfe ohne Datenerhebung zeigt `EXEC [monitor].[USP_ServerMemory] @Hilfe = 1;` an.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@MaxZeilen` | `int` | `100` | int-Eingabe: NULL oder 0 bedeutet unbegrenzt; positive Werte von 1 bis 2147483647 begrenzen die ausgewählten Clerk-Typgruppen. Die TOP-Mitgliedschaft wird nach absteigender Summe aus pages_kb und virtual_memory_committed_kb gewählt; die materialisierten Clerk-Zeilen werden anschließend nach pages_kb DESC ausgegeben beziehungsweise im JSON geordnet. TOP folgt auf den vollständigen Scan und GROUP BY von sys.dm_os_memory_clerks und begrenzt daher weder Scan noch Aggregationsaufwand. Summary und Grants bleiben ungekürzt. Negative Werte setzen INVALID_PARAMETER/IsPartial=1 und überspringen sämtliche Quellabfragen; Hilfe kehrt vor dieser Prüfung zurück. |
| `@PrintMeldungen` | `bit` | `1` | Bei 1 (auch Default) wird bei einem Status ungleich AVAILABLE eine Meldung niedriger Severity mit dem Fehlertext ausgegeben; 0 unterdrückt sie. NULL löst die IF-Bedingung ebenfalls nicht aus. Die Meldung erfolgt nach Befüllung der OUTPUT-Parameter und vor den Resultsets. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1. |
| `@Hilfe` | `bit` | `0` | 0 oder NULL nimmt den normalen Analysepfad. 1 gibt die PRINT-Hilfe aus und kehrt vor Quellzugriff, regulärer Statusinitialisierung und allen vier Status-/Fehler-OUTPUT-Zuweisungen zurück. Zuvor laufen ein angeforderter TABLE-Preflight oder die Ablehnung eines nicht leeren TABLE-Mappings außerhalb TABLE; diese können bereits werfen. @Json ist beim Eintritt auf NULL gesetzt. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach Trim von U+0020-Leerzeichen und UPPER gelten CONSOLE, RAW, TABLE und NONE; NULL wird wie leer behandelt. CONSOLE gibt nur die Console-Helferausgabe der ersten Fachquelle aus, ohne separates Modulstatusresultset; eine Leerzeile des Helfers hat hier NULL für Status und Hinweis. RAW gibt Modulstatus und unbeschriftete Fachresultsets aus. TABLE schreibt ausschließlich die benannte Fachmenge in das gemappte Ziel und gibt kein separates Modulstatusresultset aus. NONE unterdrückt Resultsets. CONSOLE und TABLE werden vor dem regulären Ausgabezweig intern zu NONE. Andere Texte, leer und NULL ergeben INVALID_PARAMETER/IsPartial=1; der nicht normalisierte ungültige Modus gibt dennoch Modulstatus und beschriftete Fachresultsets des ELSE-Zweigs aus. JSON ist davon unabhängig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Als TABLE-Eingabe ist ein JSON-Objekt mit genau einem Mapping für den registrierten Namen summary auf eine vorhandene, leere lokale #temp-Tabelle nötig; diese muss genau eine Seed-/Platzhalterspalte besitzen. Das Ziel wird vor Hilfe und Quellerhebung geprüft; fehlerhafte oder fehlende TABLE-Ziele werfen beim Preflight Fehler 51011, daher werden Status-OUTPUTs nicht regulär gesetzt. Außerhalb von TABLE sind nur NULL, leer oder Leerzeichen erlaubt; jeder andere Inhalt wirft Fehler 51011 vor Hilfe und OUTPUT-Zuweisung. |
| `@JsonErzeugen` | `bit` | `0` | Im normalen Pfad erzeugt 1 unabhängig von @ResultSetArt das JSON-Dokument in @Json; 0 oder NULL erzeugt keines. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück. Leere Fachmengen werden als leere Arrays ausgegeben. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Empfänger für das JSON-Dokument; bei Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Bindung erfolgt optional mit @Json=@Empfaenger OUTPUT; die Empfängervariable muss nvarchar(max) sein. Ohne OUTPUT-Bindung wird kein Rückgabewert an eine Aufrufervariable übertragen. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger für AVAILABLE, INVALID_PARAMETER, DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED. AVAILABLE bedeutet kein abgefangener Quellfehler und keine festgestellte ungültige Eingabe; INVALID_PARAMETER bezeichnet ungültige ResultSetArt oder negatives @MaxZeilen; DENIED_PERMISSION klassifiziert Quellfehler 229, 297, 300 oder 371; TIMEOUT klassifiziert Fehler 1222; ERROR_HANDLED steht für sonstige im Quell-TRY abgefangene Fehler. Bei Quellfehlern ist IsPartial=1. Bindung z.B. @StatusCodeOut=@Status OUTPUT mit varchar(40)-Variable. Zuweisung geschieht nach Quellversuch/Validierung, vor Meldung und Resultsetausgabe; bei frühem Preflight-THROW oder Hilfe keine reguläre Zuweisung. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER und bei abgefangenen Quellfehlern. Das Bit bezeichnet den implementierten Status-/Fehlerpfad, nicht Vollständigkeit einzelner leerer Quellgruppen. Bindung z.B. @IsPartialOut=@Partial OUTPUT mit bit-Variable; Zuweisung gemeinsam mit StatusCodeOut vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger für die SQL-Fehlernummer eines im Quell-TRY abgefangenen Fehlers; bei AVAILABLE und INVALID_PARAMETER bleibt der Wert NULL. Die bekannten Berechtigungs-/Timeoutnummern werden zugleich klassifiziert. Bindung z.B. @ErrorNumberOut=@ErrorNumber OUTPUT mit int-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger für den Text des im Quell-TRY abgefangenen Fehlers oder die konkrete INVALID_PARAMETER-Begründung; bei AVAILABLE bleibt er NULL. Bindung z.B. @ErrorMessageOut=@ErrorMessage OUTPUT mit nvarchar(2048)-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, auch nach erfolgreichem TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen. |

**RAW:**

```sql
EXEC [monitor].[USP_ServerMemory] @ResultSetArt=N'RAW';
```

**JSON:**

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_ServerMemory] @JsonErzeugen=1,@Json=@Json OUTPUT,@ResultSetArt=N'NONE';
SELECT @Json AS [JsonDocument];
```

**TABLE:**

```sql
CREATE TABLE [#ServerMemory_HelpExample]([Seed] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_ServerMemory] @ResultSetArt=N'TABLE',@ResultTablesJson=N'{"summary":"#ServerMemory_HelpExample"}';
END TRY
BEGIN CATCH
    DROP TABLE [#ServerMemory_HelpExample];
    THROW;
END CATCH;
DROP TABLE [#ServerMemory_HelpExample];
```

**Hilfe:**

```sql
EXEC [monitor].[USP_ServerMemory] @Hilfe=1;
```

## Resultsets und Leserichtung

Der TABLE-Vertrag registriert ausschließlich `summary`. RAW liefert nach dem Modulstatus die unbeschrifteten Fachergebnissets; CONSOLE liefert ohne separates Modulstatusresultset eine Console-Ausgabe der Memory-Summary, JSON enthält Meta, die Arrays Memory Clerks und Grants und ein leeres warnings-Array. TABLE schreibt ausschließlich `summary`. Die JSON-Erzeugung im normalen Pfad ist unabhängig von @ResultSetArt; Hilfe kehrt davor zurück; NONE unterdrückt reguläre Resultsets, nicht aber JSON, wenn @JsonErzeugen=1. Die Resultsets besitzen unterschiedliche Zeilengranularitäten und dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Memory-Zusammenfassung, Prozess-/OS-Signal oder einen Memory Clerk.

## So lesen

Berücksichtigen Sie OS Available Memory, SQL Process Memory, Target/Total Server Memory, Pressure-Signale und größte Clerks gemeinsam.

## Warum kann das problematisch sein?

OS- und SQL-Druck gleichzeitig kann Paging, Cacheverdrängung und Grantknappheit verursachen.

## Wann ist es kein Problem?

Total Server Memory nahe Target ist im Steady State normal: SQL Server soll zugewiesenen Speicher nutzen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Total≈Target allein ist gesund. Total≈Target plus kaum OS-Reserve, Physical Memory Low und Grantwaits ist problematisch. Prüfen Sie Grants, Buffer Pool und max server memory.

**Ähnlich aussehender Gegenfall:** Total Server Memory nahe Target ist im Steady State normal: SQL Server soll zugewiesenen Speicher nutzen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für diese Procedure bedeutet **keine Zeile**, dass die jeweilige Quelle im sichtbaren Scope keinen Datensatz lieferte; **0** bleibt ein gemessener Wert, **NULL** kennzeichnet unbekannt oder nicht anwendbar. INVALID_PARAMETER bei negativem @MaxZeilen setzt IsPartial=1 und überspringt Quellabfragen. Ein abgefangener Quellfehler setzt ebenfalls IsPartial=1; zuvor gelesene Tabellen können gefüllt sein und spätere leer bleiben. Ein positives @MaxZeilen begrenzt nur die ausgegebenen aggregierten Clerk-Typen, nicht deren Scan/Aggregation, Summary oder Grants.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Ein Instanzsnapshot aus je einer OS-/Prozess-/SQLOS-Summaryzeile, den Top 100 aggregierten Memory-Clerk-Typen und einer aggregierten Memory-Grant-Zeile. |
| Teuerster Pfad | `@MaxZeilen = 0` auf einer Instanz mit sehr vielen Clerktypen; alle Clerkzeilen werden gruppiert und ausgegeben. Die Grantquelle bleibt eine Aggregatzeile, nicht ein Detailinventar. |
| Haupttreiber | Zahl der Memory-Clerk-Zeilen und -Typen; OS-, Prozess-, SQLOS- und Grantzusammenfassung besitzen feste Granularität. Das Clerk-TOP greift erst nach der Typaggregation. |
| Skalierung | Dominant ist Gruppierung/Sortierung von `sys.dm_os_memory_clerks`; die anderen DMVs und zwei Konfigurationszeilen sind klein. Keine Datenbank-, Datei- oder Cross-Database-Schleife. |
| Ressourcen | Geringe bis mittlere CPU/SQLOS-DMV-Arbeit und Speicher für Clerkaggregation; kein Volume-, msdb-, Benutzerdaten- oder Textzugriff. |
| Begrenzungswirkung | `@MaxZeilen` wird als TOP erst nach Gruppierung der Clerkzeilen angewandt. Es begrenzt ausgegebene Clerktypen, nicht den Scan/Aggregationsaufwand; Summary und Grantaggregat bleiben unabhängig davon vollständig. |
| Locking und Nebenwirkungen | Read-only; kurze Metadatenzugriffe und nicht atomare Runtime-DMVs. Es wird weder CHECKDB noch Growth noch Konfigurationsänderung ausgeführt. |
| Schutzmechanismus | Kein Gate. Die drei Summaryquellen und das Grantaggregat haben feste Granularität; nur die Clerktypen sind variabel und werden standardmäßig auf 100 Ausgaberänge begrenzt. Dieses TOP ist kein Schutz vor der vorherigen Clerkaggregation. |
| Sicherer Einsatz | Defaultlimit 100. Ein unbegrenztes Clerkresultset nur bei konkreter Clerkfrage und nach Prüfung der vorhandenen Typanzahl anfordern. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + kumulative Runtimezähler“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Hat SQL Server oder das Betriebssystem Memory Pressure, und welche Clerks/Komponenten verwenden Speicher?

### Technischer Hintergrund

SQL Server Memory Manager balanciert Buffer Pool, Plan Cache, Query Execution Memory und weitere Clerks unter Min/Max Server Memory. OS-/Process-DMVs zeigen physisches Memory, Commit/Pagefile und Process Working Set. Target versus Total Server Memory und Memory Notifications liefern Drucksignale.

### Datenkette

`sys.configurations`, `sys.dm_exec_query_memory_grants`, `sys.dm_os_memory_clerks`, `sys.dm_os_process_memory`, `sys.dm_os_sys_info`, `sys.dm_os_sys_memory`.

### Source Select

Die zusammenfassende Speicherzeile kombiniert drei Singleton-DMVs mit den zwei relevanten Serverkonfigurationen:

```sql
SELECT
      [sm].[total_physical_memory_kb]
    , [sm].[available_physical_memory_kb]
    , [pm].[physical_memory_in_use_kb]
    , [pm].[process_physical_memory_low]
    , [si].[committed_kb]
    , [si].[committed_target_kb]
    , MAX(CASE WHEN [c].[name] = N'max server memory (MB)'
               THEN [c].[value_in_use] END) AS [MaxServerMemoryMb]
FROM [sys].[dm_os_sys_memory] AS [sm] WITH (NOLOCK)
CROSS JOIN [sys].[dm_os_process_memory] AS [pm] WITH (NOLOCK)
CROSS JOIN [sys].[dm_os_sys_info] AS [si] WITH (NOLOCK)
CROSS JOIN [sys].[configurations] AS [c] WITH (NOLOCK)
WHERE [c].[name] IN (N'min server memory (MB)', N'max server memory (MB)')
GROUP BY
      [sm].[total_physical_memory_kb], [sm].[available_physical_memory_kb]
    , [pm].[physical_memory_in_use_kb], [pm].[process_physical_memory_low]
    , [si].[committed_kb], [si].[committed_target_kb];
```

**Wichtig für die Eigenlast:** Summary ist klein. `dm_os_memory_clerks` wird vollständig gelesen und sofort nach Typ aggregiert; `@MaxZeilen` begrenzt dort das Ranking, nicht den DMV-Scan. Vertiefen Sie Grantdetails nur bei passendem Symptom.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Zustand; Clerk-/Processwerte verändern sich, einzelne Counter seit Start.

### Bewertung und Gegenprobe

Berücksichtigen Sie OS Available/Commit, process physical/virtual low flags, Total/Target, Max Server Memory, locked pages, clerk distribution, pending grants und paging gemeinsam. Hoher SQL-Memoryverbrauch allein ist erwartbar.

### Typische Fehlinterpretation

`Available MBytes` oder PLE besitzen keine universellen Einzelgrenzen. Buffer Pool und Query Grants sind unterschiedliche Verbraucher; VM Ballooning kann außerhalb SQL-Sicht liegen.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_BufferPoolAnalysis`, Current Memory Grants, Performance Counters und OS/Hypervisor-Telemetrie.

## Primärquellen

- [sys.dm_os_process_memory](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-process-memory-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#3-monitorusp_servermemory)

# [monitor].[USP_CriticalEngineEvents]

**Bereich:** Server Health<br>
**Zweck:** Liest ausgewählte kritische Ereignisse aus vorhandenen serverseitigen XEL-Dateien der genau benannten Extended-Events-Session und optional einen einmaligen sys.sp_server_diagnostics-Snapshot.
**Beobachtungsart:** retentionbegrenzte Ereignishistorie + Diagnostiksnapshot<br>
**Kostenklasse:** MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche kritischen Engineereignisse sind in den ausgewählten XE-Dateien erhalten und welche Komponenten meldet der optionale Diagnostics-One-Shot?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -24, SYSUTCDATETIME());

EXEC [monitor].[USP_CriticalEngineEvents]
      @VonUtc = @ExampleVonUtc,
      @MitEventXml = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@SourceExtendedEventSessionName` | `nvarchar(258)` | `N'system_health'` | Ein einzelner, einteiliger SQL-Name der Extended-Events-Session. monitor.TVF_ParseSqlNameList verarbeitet bracket-aware Pipe-Listen, äußerer Whitespace wird entfernt, ]] maskiert ], aber dieser Parameter akzeptiert genau einen gültigen Listeneintrag; multipart-Namen und Namen über 128 Zeichen sind ungültig. NULL, leere Eingabe, leere/fehlerhafte Elemente oder mehr als ein gültiger Name führen zu INVALID_PARAMETER. Der Default system_health wird durch die Procedure-Signatur gesetzt. Der Name wird für die Katalogsuche des event_file-Targets verwendet; die Procedure startet oder ändert die Session nicht. |
| `@FilePath` | `nvarchar(4000)` | `NULL` | Optionaler serverseitiger Dateipfad oder XEL-Muster. NULL oder leerer String verwendet den im Katalog für die angegebene Session konfigurierten event_file-Dateinamen; der Eingabewert wird nicht mit LTRIM/RTRIM normalisiert. Ein Suffix .xel wird durch Basisname plus *.xel ersetzt (case-insensitiv); ohne * und ohne .xel wird *.xel angefügt; vorhandenes * bleibt erhalten. Ein expliziter Pfad ersetzt den konfigurierten Pfad und muss für den SQL-Server-Dienstprozess lesbar sein. Gelesen wird mit sys.fn_xe_file_target_read_file; kein Clientpfad und kein Ringbuffer-Fallback. |
| `@VonUtc` | `datetime2(7)` | `NULL` | datetime2(7)-Zeitpunkt in UTC als inklusiver Unterrand: Eventzeitstempel müssen &gt;= VonUtc sein. NULL lässt die Untergrenze offen. Kein Zeitzonenoffset/keine Konvertierung; UTC liefert der Aufrufer. Wird unabhängig von BisUtc vor XML-Parsing angewandt. |
| `@BisUtc` | `datetime2(7)` | `NULL` | datetime2(7)-Zeitpunkt in UTC als exklusiver Oberrand: Eventzeitstempel müssen &lt; BisUtc sein. NULL lässt die Obergrenze offen. Kein Zeitzonenoffset/keine Konvertierung; UTC liefert der Aufrufer. Wird unabhängig von VonUtc vor XML-Parsing angewandt. Sind beide gesetzt, muss VonUtc strikt kleiner sein. |
| `@MinErrorSeverity` | `tinyint` | `20` | Severity-Schwelle 0 bis 25; tinyint lässt keine negativen Eingaben zu, Werte &gt;25 sind INVALID_PARAMETER. Betrifft nur error_reported und wird nach dem TOP-Kandidatenset angewandt. Fehlernummern 701, 802, 823, 824, 825, 832, 833, 8645, 8651 und 17803 passieren unabhängig von der Severity. NULL umgeht die &gt;25-Prüfung; der Severityvergleich ergibt UNKNOWN, sodass normale error_reported-Einträge entfallen und nur die Nummernausnahmen verbleiben. Andere ausgewählte Eventnamen werden nicht nach Severity gefiltert. |
| `@MitSystemHealth` | `bit` | `1` | Bit-Schalter: 1 liest das vorhandene event_file-Target der benannten Session; 0 überspringt die XEL-Quelle. Es werden ausschließlich error_reported, scheduler_monitor_non_yielding_ring_buffer_recorded, scheduler_monitor_non_yielding_iocp_ring_buffer_recorded, scheduler_monitor_stalled_dispatcher_ring_buffer_recorded, sp_server_diagnostics_component_result, memory_broker_ring_buffer_recorded, resource_monitor_ring_buffer_recorded, connectivity_ring_buffer_recorded und xml_deadlock_report berücksichtigt. NULL aktiviert die Quelle nicht und ist nicht eigenständig ungültig. Keine XE-Änderung; kein Ringbuffer-Fallback. Sind beide Quellflags explizit 0, ist die Eingabe INVALID_PARAMETER. Sind Flags NULL/0, kann der Validierungsvergleich UNKNOWN sein und beide Quellen überspringen, während der globale Status AVAILABLE bleibt. |
| `@MitServerDiagnostics` | `bit` | `0` | Bit-Schalter: 1 führt sys.sp_server_diagnostics 0 einmalig ohne Repeat-Modus aus; 0 überspringt die Quelle. NULL aktiviert sie nicht und ist nicht eigenständig ungültig. Vollständige Daten können laut SourceStatus mindestens fünf Sekunden benötigen. Der Aufruf bildet einen separaten aktuellen Snapshot und ist kein XEL-Ereignis. |
| `@MitEventXml` | `bit` | `0` | Bit-Schalter: 1 gibt das vollständige EventXml und Diagnostics-Data aus (einschließlich JSON); 0 oder NULL liefert diese XML-Ausgabefelder als NULL. Event-XML wird für extrahierte Felder und Filter auch ohne Opt-in gelesen und geparst; Diagnostics Data wird durch den One-Shot geliefert, aber nur mit Opt-in ausgegeben. Das Flag reduziert vollständigen XML-Transfer, nicht Parsing oder MessageText (nvarchar(4000)). MessageText/EventXml können sensible Runtimeinhalte enthalten; es gibt keine Persistenz. |
| `@MaxZeilen` | `int` | `500` | Nichtnegative int-Obergrenze. Werte &lt;0 sind INVALID_PARAMETER. Werte 1..2147483647 begrenzen mit TOP das nach Zeit/Eventnamen gefilterte XEL-Kandidatenset, bevor XML extrahiert und Severity angewandt wird. 0 und NULL nutzen die größte bigint-TOP-Grenze. Sortiert wird nach Zeitstempel absteigend, Dateiname und Dateioffset absteigend. Das begrenzt weder das physische Lesen aller passenden Rolloverdateien noch ungefilterte Diagnostics-/SourceStatus-Zeilen; viele neuere Events können ältere relevante Fehler verdrängen. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach LTRIM/RTRIM und UPPER normalisierte Ausgabeart. RAW liefert Status und drei technische Resultsets: Events, Diagnostics, SourceStatus. CONSOLE wird intern NONE und danach über InternalEmitConsoleResult ausschließlich aus der Ereignistabelle gerendert; ein Status- oder Diagnostics-Resultset sowie der im Branch vorhandene CONSOLE-Formatierungszweig werden nicht ausgegeben. Leere Ereignisse erzeugen die Helper-Hinweiszeile. TABLE wird intern NONE und schreibt nur events in das lokale Ziel. NONE unterdrückt reguläre Resultsets. Zulässig: RAW, CONSOLE, TABLE, NONE; NULL/Leertext/andere Werte ergeben INVALID_PARAMETER. JSON kann unabhängig erstellt werden. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | TABLE-Aufrufe benötigen ein gültiges JSON-Objekt mit dem Schlüssel events und dem Wert eines bereits angelegten zulässigen lokalen #Temp-Ziels. Der Single-Result-Preflight läuft vor Hilfe und validiert Zuordnung und Ziel; NULL, leerer Text, ungültiges JSON oder fehlendes events-Mapping schlagen im TABLE-Modus fehl. Außerhalb TABLE ist NULL/leer zulässig; ein nichtleerer Wert löst wegen der Caller-Prüfung Fehler 51011 aus. |
| `@JsonErzeugen` | `bit` | `0` | Bit: 0 unterdrückt JSON, 1 erstellt es; NULL aktiviert den IF-Zweig nicht. JSON-Gruppen: meta, events, serverDiagnostics, sources und warnings (leeres Array). Events und Diagnostics stammen aus denselben materialisierten Tabellen wie übrige Ausgaben; der Eventkandidatensatz ist bereits durch MaxZeilen begrenzt. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT nvarchar(max), beim Eintritt auf NULL gesetzt. Mit JsonErzeugen=1 wird später das JSON-Objekt meta/events/serverDiagnostics/sources/warnings zugewiesen, sonst bleibt NULL. Hilfe kehrt nach dem Reset zurück. EXEC mit nvarchar(max)-Empfängervariable und OUTPUT binden. |
| `@PrintMeldungen` | `bit` | `1` | Bit: 0 unterdrückt Meldungen, 1 sendet bei globalem Status ungleich AVAILABLE eine Severity-10-RAISERROR-Meldung WITH NOWAIT. NULL aktiviert die IF nicht. Da Quellenfehler im SourceStatus protokolliert werden, während globale ErrorMessage NULL bleiben kann, meldet dieser Pfad dann den globalen Statuscode. JSON/Resultsets bleiben unabhängig. |
| `@Hilfe` | `bit` | `0` | Bit: 1 druckt Kurzinfos und kehrt vor Sessionparser, Quellenzugriff und Status-OUTPUT-Zuweisungen zurück; NULL/0 läuft regulär. @Json wurde beim Eintritt bereits auf NULL gesetzt. Ungültiges ResultTablesJson außerhalb TABLE sowie TABLE-Preflight werden vorher ausgeführt. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | OUTPUT varchar(40) mit globalem Status: INVALID_PARAMETER bei ungültiger Session/Zeit/Severity/Quell-/Ausgabeangabe; AVAILABLE_LIMITED bei markierter Teilquelle oder SourceStatus ungleich AVAILABLE; AVAILABLE_WITH_FINDING wenn Events vorhanden und keine Teilquelle gemeldet ist; sonst AVAILABLE. Per-source Codes: UNAVAILABLE_OBJECT bei fehlendem Dateipfad; AVAILABLE bei erfolgreicher Quelle; DENIED_PERMISSION für SQL-Fehler 229/262/297/300/371; XML_UNAVAILABLE_LIMIT für 6335/6336/6337; XML_INVALID für 9400..9431; ERROR_HANDLED für sonstige Quellfehler (Diagnostics nutzt DENIED_PERMISSION oder ERROR_HANDLED). Quellenfehler bleiben im SourceStatus und setzen nicht notwendigerweise globale ErrorNumber/ErrorMessage. Hilfe lässt den Empfänger unverändert. Mit @StatusCodeOut=@Variable OUTPUT binden. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | OUTPUT bit: 1 bei ungültigen Eingaben oder markierten/fehlgeschlagenen Teilquellen; sonst 0. 0 beweist nicht, dass system_health-Retention oder Eventauswahl vollständig ist. Teilquellenfehler führen global zu AVAILABLE_LIMITED. Hilfe lässt Empfänger unverändert; mit OUTPUT binden. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | OUTPUT int für einen global gesetzten Fehler; im Quellen-CATCH werden Fehlernummern stattdessen je Quelle in SourceStatus erfasst, daher kann dieser Empfänger NULL bleiben. Hilfe weist ihn nicht zu. Mit @ErrorNumberOut=@Variable OUTPUT binden. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | OUTPUT nvarchar(2048) für globale Validierungs-/Fehlermeldung. Fehlertexte einzelner XEL-/Diagnostics-Quellen stehen im SourceStatus und setzen diesen Wert nicht zwingend; dann bleibt er NULL. Hilfe weist ihn nicht zu. Mit @ErrorMessageOut=@Variable OUTPUT binden. |

### Beispiele und Ausgabearten
Die Werte sind synthetisch. Jeder Block ist eigenständig; XEL-Pfade müssen auf dem SQL-Server verfügbar sein.
#### RAW
```sql
DECLARE @ExampleFromUtc datetime2(7)=DATEADD(HOUR,-24,SYSUTCDATETIME());
EXEC [monitor].[USP_CriticalEngineEvents] @VonUtc=@ExampleFromUtc,@MaxZeilen=100,@ResultSetArt='RAW';
```
#### JSON
```sql
DECLARE @ExampleEventsJson nvarchar(max)=NULL;
DECLARE @ExampleFromUtc datetime2(7)=DATEADD(HOUR,-24,SYSUTCDATETIME());
EXEC [monitor].[USP_CriticalEngineEvents] @VonUtc=@ExampleFromUtc,@JsonErzeugen=1,@Json=@ExampleEventsJson OUTPUT,@ResultSetArt='NONE';
SELECT @ExampleEventsJson AS [ExampleJson];
```
#### TABLE
```sql
DECLARE @ExampleEventsMap nvarchar(max)=CONCAT(N'{',NCHAR(34),N'events',NCHAR(34),N':',NCHAR(34),N'#CriticalEngineEvents_HelpExample',NCHAR(34),N'}');
CREATE TABLE #CriticalEngineEvents_HelpExample ([Seed] int NULL);
BEGIN TRY
 DECLARE @ExampleFromUtc datetime2(7)=DATEADD(HOUR,-24,SYSUTCDATETIME());
EXEC [monitor].[USP_CriticalEngineEvents] @VonUtc=@ExampleFromUtc,@ResultSetArt='TABLE',@ResultTablesJson=@ExampleEventsMap;
 SELECT * FROM #CriticalEngineEvents_HelpExample;
 DROP TABLE #CriticalEngineEvents_HelpExample;
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS #CriticalEngineEvents_HelpExample;
 THROW;
END CATCH;
```
#### Hilfe
```sql
EXEC [monitor].[USP_CriticalEngineEvents] @Hilfe=1;
```

## Resultsets und Leserichtung

RAW liefert Status, Events, Diagnostics und SourceStatus; CONSOLE zeigt nur die Ereignistabelle mit dem Console-Helper und bei leerer Tabelle eine Hinweiszeile; TABLE exportiert nur events. JSON enthält meta, events, serverDiagnostics, sources und warnings. CONSOLE und TABLE geben kein Statusresultset aus.

Die zwölf Textspalten der lokalen Ereignis-, Diagnostics- und
Quellenstatustabellen verwenden explizit `SQL_Latin1_General_CP1_CS_AS`.
Die fünf Textspalten des Ereignis-TABLE-Exports behalten diese
Frameworkcollation auch bei einer abweichenden Server- oder
`tempdb`-Collation. Das vorhandene Zeilenlimit gilt bereits im XE-Kandidatenset
vor dem nachfolgenden Severityfilter. TABLE und JSON verwenden dieselben
materialisierten Ereignisse. `@MitEventXml=0` liefert für die XML-Spalte `NULL`;
der Opt-in überträgt das gelesene Ereignis-XML. Ringbuffer sind keine Quelle
dieser Procedure.

## Eine Zeile bedeutet

Eine Zeile entspricht einem erfassten Engine-Ereignis; SourceStatus beschreibt die Verfügbarkeit der Quelle.

## So lesen

Vergleichen Sie Eventtyp, Severity, Zeit, Quelle, Wiederholung und Begleitsymptome.

## Warum kann das problematisch sein?

Schwere Fehler, Schedulerprobleme oder Dumps können Engine-, Hardware- oder I/O-Risiken anzeigen.

## Wann ist es kein Problem?

Ein einzelnes altes Ereignis kann bereits behoben sein; aktuelle Wiederholung entscheidet über Dringlichkeit.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Mehrere Severity-20+-Fehler in kurzer Zeit plus suspect pages sind deutlich kritischer als ein einzelnes altes Ereignis. Prüfen Sie Error Log, Integrität und Infrastruktur.

**Ähnlich aussehender Gegenfall:** Ein einzelnes altes Ereignis kann bereits behoben sein; aktuelle Wiederholung entscheidet über Dringlichkeit. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Keine Zeile bedeutet, dass im sichtbaren, gefilterten Kandidatensatz kein ausgabefähiges Ereignis entstand. NULL steht für unbekannte oder nicht aktivierte Felder, etwa XML ohne Opt-in. IsPartial=1 kennzeichnet ungültige Eingaben oder markierte Teilquellen; AVAILABLE_LIMITED enthält quellbezogene Fehler in SourceStatus. Das Limit kann ältere Ereignisse aus der Kandidatenmenge verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Das begrenzte Lesen von Eventfiles besitzt die Kostenklasse MEDIUM; der XML-Transfer ist ein Opt-in.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM |
| Standardpfad | Löst den event_file-Pfad für die benannte Session auf (oder nutzt den expliziten Pfad), liest bis zu MaxZeilen zeitlich gefilterte Kandidaten aus den festgelegten Eventnamen, extrahiert XML-Felder und wendet danach Severity und Fehlerausnahmen an. EventXml bleibt ohne Opt-in NULL. |
| Teuerster Pfad | `@MaxZeilen = 0`, vollständige Event-XML und optional `sp_server_diagnostics`; XEL-Rollover-Dateien können vor TOP breit gelesen werden. |
| Haupttreiber | Zahl/Größe der durch den Wildcardpfad erfassten XEL-Rolloverdateien und passende Events im UTC-Fenster. `sp_server_diagnostics` ist ein einzelner zusätzlicher One-Shot-Aufruf. |
| Skalierung | XEL-Lesen kann mit der Rollovermenge wachsen, auch wenn TOP nur wenige neueste Treffer behält. XML wird für die ausgewählten Events immer in Fehler-, Severity-, Komponenten- und Meldungsfelder zerlegt; vollständige XML-Ausgabe erhöht danach primär Speicher/Transfer. |
| Ressourcen | Datei-I/O über das SQL-Server-Dienstkonto, CPU/Speicher für XML-Parsing, TempDB/Transfer für zerlegte Ereignisse. |
| Begrenzungswirkung | MaxZeilen ist TOP vor XML-Parsing und Severityfilter, nicht vor dem physischen XEL-Rollover-Scan. Severity kann die Ergebnismenge verkleinern. Diagnostics und SourceStatus werden davon nicht begrenzt. |
| Locking und Nebenwirkungen | Keine Änderung an XE-Sessions. Filezugriff konkurriert mit Storage-I/O; Runtimequellen sind flüchtig. Ein einmaliger server_diagnostics-Aufruf liest aktuellen Zustand. |
| Schutzmechanismus | Diese Procedure besitzt trotz XEL-Lesen kein High-Impact-Gate. Schutz liefern eine konkrete Quelle, ein enges UTC-Fenster, Severity-/Eventfilter, endliches Limit sowie ausgeschaltete Voll-XML- und Server-Diagnostics-Ausgabe; TOP garantiert dennoch keinen kleinen physischen Rollover-Scan. |
| Sicherer Einsatz | Standardlimit und `@MitEventXml = 0` beibehalten; `sp_server_diagnostics` nur bei konkreter Fragestellung aktivieren und breite XEL-Läufe betrieblich abstimmen. |
| Aussagegrenze | XEL enthält nur konfigurierte und noch erhaltene Ereignisse. TOP vor Severity kann ältere schwere Fehler verdrängen. Teilquellenfehler erscheinen in SourceStatus; global kann AVAILABLE_LIMITED gelten, obwohl globale ErrorNumber/ErrorMessage NULL sind. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche kritischen Engineereignisse sind in den ausgewählten XE-Dateien erhalten und welche Komponenten meldet der optionale Diagnostics-One-Shot?

### Technischer Hintergrund

`system_health` erfasst ausgewählte Errors, Scheduler-/Memory-/Connectivity-/Deadlock- und Diagnoseereignisse. Die Procedure liest vorhandene XE-Dateien; `sp_server_diagnostics` liefert optional einen separaten aktuellen Komponentenstatus. Event-XML und Datenfelder sind versionsabhängig.

### Datenkette

`sys.fn_xe_file_target_read_file`, `sys.server_event_session_fields`, `sys.server_event_session_targets`, `sys.server_event_sessions`, `sys.sp_server_diagnostics`.

### Source Select

Der XE-Dateipfad liest nur die relevanten System-Health-Events im benötigten Zeitfenster:

```sql
SELECT
      [x].[timestamp_utc]
    , [x].[object_name]
    , TRY_CAST([x].[event_data] AS xml) AS [EventXml]
FROM [sys].[fn_xe_file_target_read_file]
     (@EventFilePattern, NULL, NULL, NULL) AS [x]
WHERE [x].[object_name] IN
      (N'error_reported', N'scheduler_monitor_non_yielding_ring_buffer_recorded')
  AND [x].[timestamp_utc] >= @VonUtc;
```

**Wichtig für die Eigenlast:** Zeitfenster und Eventnamen beim Dateizugriff einschränken, bevor XML zerlegt wird. `sys.sp_server_diagnostics` ist ein separater aktueller Snapshot und keine zweite Dateiquelle.

### Zeit- und Scope-Modell

Die Auswertung berücksichtigt nur erhaltene Ereignisse seit der Session-, Engine- oder Rollovergrenze und den aktuellen Diagnostikstatus.

### Bewertung und Gegenprobe

Korrelieren Sie Eventtyp, Severity und State, Timestamp, Component, Wiederholung sowie gleichzeitige Errorlog-, Betriebssystem- und Clusterereignisse. Behandeln Sie Scheduler Non-Yielding, Memory Error und I/O Stall als unterschiedliche Ereignisklassen.

### Typische Fehlinterpretation

Keine Zeile ist keine Entwarnung. system_health ist bewusst begrenzt und kann Rollover/Targets verlieren.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: XE Target Runtime/Read Events, Errorlog, OS/Cluster/Storagediagnostik.

## Primärquellen

- [system_health session](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/use-the-system-health-session?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#14-monitorusp_criticalengineevents)

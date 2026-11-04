# [monitor].[USP_ExtendedEventsAnalysis]

**Bereich:** Extended Events, Orchestrator<br>
**Zweck:** Orchestriert Inventar, Targetruntime, generische Events, Deadlocks und Blocked Processes.<br>
**Beobachtungsart:** nicht atomarer Mix aus Runtime-Snapshot und Ereignishistorie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche XE-Konfigurations-, Runtime- und Ereignisperspektiven sollen gemeinsam geprüft werden?** Sie unterstützt die Entscheidung, ob die konfigurierte Ereignisquelle die gesuchte Situation erfasst hat und welche einzelne Datei, Session oder XML-Struktur anschließend vertieft wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ereignisse, die nicht konfiguriert, vor Sessionstart aufgetreten oder durch Rollover/Targetgrenzen verloren gegangen sind. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExtendedEventsAnalysis]
      @MitSessionInventar = 1,
      @MitTargetRuntime = 0,
      @MitEvents = 0,
      @MitDeadlocks = 0,
      @MitBlockedProcesses = 0,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parametervertrag

| Parameter | Typ | Default | Vertrag |
|---|---|---|---|
| `@SourceExtendedEventSessionName` | `nvarchar(258)` | `N'system_health'` | Einzelner Forensik-Quell-Sessionsname, Standard system_health. Nur an aktivierte ReadEvents-, Deadlocks- und BlockedProcesses-Children; nicht an Inventar-Children. ReadEvents und Deadlocks lehnen NULL/leeren/ungültigen/mehrteiligen Namen ab. BlockedProcesses verwendet NULL zur automatischen Auswahl und lehnt leere/ungültige explizite Namen ab. |
| `@ExtendedEventSessionNames` | `nvarchar(max)` | `NULL` | NULL deaktiviert den Exaktnamenfilter. Sonst pipe-getrennte Liste exakter einteiliger SQL-Namen; Klammerung und ]] Escape unterstützt. Leere Liste/ungültige Namen ungültig. Nicht kombinierbar mit ExtendedEventSessionNamePattern. Wird an Sessions- und TargetRuntime-Children geleitet. |
| `@ExtendedEventSessionNamePattern` | `nvarchar(4000)` | `NULL` | NULL deaktiviert den Musterfilter. Andernfalls nichtleeres LIKE-Muster, optional mit LIKE:, REGEX: oder REGEXI:; äußere Leerzeichen werden entfernt. Leeres Muster oder leerer Präfixwert ist ungültig. LIKE unterstützt % und _. Regex benötigt SQL Server 2025 mit Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit ExtendedEventSessionNames kombinierbar. Wird an Sessions-/TargetRuntime-Children geleitet. |
| `@EventNames` | `nvarchar(max)` | `NULL` | NULL deaktiviert den exakten Eventnamenfilter. Andernfalls pipe-getrennte Liste exakter einteiliger SQL-Namen; leere Liste/ungültige Namen werden abgelehnt. Nicht mit EventNamePattern kombinierbar. Wird an Sessions- und ReadEvents-Children geleitet. |
| `@EventNamePattern` | `nvarchar(4000)` | `NULL` | NULL deaktiviert den Musterfilter. Andernfalls nichtleeres Muster mit optionalem LIKE:, REGEX: oder REGEXI:-Präfix; äußere Leerzeichen werden getrimmt. Leeres Muster/Präfixwert ungültig. LIKE unterstützt % und _. Regex erfordert SQL Server 2025 / Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit EventNames kombinierbar. |
| `@TargetNames` | `nvarchar(max)` | `NULL` | NULL deaktiviert den Exaktnamenfilter. Sonst pipe-getrennte Liste exakter einteiliger SQL-Namen; Klammerung und ]] Escape unterstützt. Leere Liste/ungültige Namen ungültig. Nicht kombinierbar mit TargetNamePattern. Wird an Sessions-/TargetRuntime-Children geleitet. |
| `@TargetNamePattern` | `nvarchar(4000)` | `NULL` | NULL deaktiviert den Musterfilter. Andernfalls nichtleeres Muster mit optionalem LIKE:, REGEX: oder REGEXI:-Präfix; äußere Leerzeichen werden getrimmt. Leeres Muster oder leerer Präfixwert ungültig. LIKE verwendet % und _. Regex benötigt SQL Server 2025 / Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit TargetNames kombinierbar. Wird an Sessions-/TargetRuntime-Children geleitet. |
| `@Quelle` | `varchar(20)` | `'AUTO'` | Getrimmt/großgeschrieben; zulässig AUTO, EVENT_FILE, RING_BUFFER. Quellwahl für Forensik-Children. |
| `@FilePath` | `nvarchar(4000)` | `NULL` | Optionaler XEL-Dateipfad, an aktivierte Forensik-Children geleitet; NULL überlässt Pfadauswahl dem Child. Leerverhalten childabhängig. |
| `@VonUtc` | `datetime2(7)` | `NULL` | Unverändert an ReadEvents, Deadlocks und BlockedProcesses geleitet. ReadEvents: NULL lässt untere inklusive Grenze aus. Deadlocks/BlockedProcesses: NULL bedeutet UTC jetzt minus 24 Stunden. |
| `@BisUtc` | `datetime2(7)` | `NULL` | Unverändert an die aktivierten Forensik-Children geleitet. NULL lässt die exklusive obere Grenze aus. |
| `@MitSessionInventar` | `bit` | `1` | 1 ruft USP_ExtendedEventsSessions mit Session-/Event-/Targetfiltern und MaxZeilen auf; erhält SourceExtendedEventSessionName nicht. |
| `@MitTargetRuntime` | `bit` | `0` | 1 ruft USP_ExtendedEventsTargetRuntime mit Session-/Targetfiltern auf. Das DMV-Lesen verlangt Flushbestätigung 1 und Deep-Analysis-Gate. |
| `@MitEvents` | `bit` | `0` | 1 ruft USP_ExtendedEventsReadEvents auf und leitet SourceExtendedEventSessionName, Quelle, FilePath, Eventfilter, UTC-Grenzen, MaxZeilen sowie Schutzbestätigungen weiter. |
| `@MitDeadlocks` | `bit` | `0` | 1 ruft USP_ExtendedEventsDeadlocks auf und leitet Session, Quelle, Datei, UTC-Grenzen, MaxZeilen und Schutzbestätigungen weiter. |
| `@MitBlockedProcesses` | `bit` | `0` | 1 ruft USP_ExtendedEventsBlockedProcesses auf und leitet Session, Quelle, Datei, UTC-Grenzen, MaxZeilen und Schutzbestätigungen weiter. |
| `@MaxZeilen` | `int` | `100` | Negative Werte ungültig. An Children weitergeleitet; NULL oder 0 bedeutet dort unbegrenzt. Ein Zeilenlimit garantiert kein vorzeitiges oder vollständiges Überspringen des physischen XEL-Lesens. Modulstatus wird nicht gekürzt. |
| `@BestaetigeTargetFlush` | `bit` | `0` | Explizit 0 oder 1 übergeben; nicht NULL. An Children geleitet. 1 nur nach bewusster Bestätigung setzen, weil Targetzugriffe einen Flush auslösen können. |
| `@HighImpactConfirmed` | `bit` | `0` | An aktivierte Forensikchildren und TargetRuntime geleitete Policybestätigung für Deep-Analysis. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Getrimmt/großgeschrieben; zulässig RAW, CONSOLE, NONE, TABLE. TABLE schreibt moduleStatus; CONSOLE/TABLE unterdrücken Child-Resultsets intern. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur mit TABLE. Nichtleeres JSON-Objekt mit genau dem Schlüssel moduleStatus und dem Namen einer vorhandenen, leeren lokalen #temp-Tabelle mit genau einer NULL-zulässigen Seed-Spalte. NULL/Leerwert, fehlerhafte Zuordnung, Zusatzschlüssel, befülltes Ziel, globale/permanente Tabelle und #Monitor-Präfix werden abgelehnt. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt Parent-JSON-Hülle mit meta, inventory, targetRuntime, events, deadlocks, blockedProcesses und warnings; 0 lässt @Json NULL. |
| `@Json` | `nvarchar(max)` | `NULL` | OUTPUT, wird anfangs NULL gesetzt; enthält bei JsonErzeugen=1 die Parent-JSON-Hülle. |
| `@PrintMeldungen` | `bit` | `1` | 1 aktiviert Child-/Parent-Warnmeldungen; 0 unterdrückt sie. |
| `@Hilfe` | `bit` | `0` | 1 druckt Kurzhilfe und kehrt vor Ausführung zurück. |

## Beispiele

### Beispiel 1

```sql
EXEC [monitor].[USP_ExtendedEventsAnalysis] @Hilfe=1;
```

### Beispiel 2

```sql
EXEC [monitor].[USP_ExtendedEventsAnalysis] @ExtendedEventSessionNames=N'ExampleXeSession', @MitSessionInventar=1, @MitTargetRuntime=0, @MitEvents=0, @MitDeadlocks=0, @MitBlockedProcesses=0, @ResultSetArt='RAW';
```

### Beispiel 3

```sql
DECLARE @xeFrom datetime2(7)=DATEADD(hour,-1,SYSUTCDATETIME()), @xeTo datetime2(7)=SYSUTCDATETIME(), @xeJson nvarchar(max);
EXEC [monitor].[USP_ExtendedEventsAnalysis] @SourceExtendedEventSessionName=N'ExampleXeSession', @Quelle='AUTO', @VonUtc=@xeFrom, @BisUtc=@xeTo, @MitSessionInventar=0, @MitEvents=1, @MaxZeilen=50, @BestaetigeTargetFlush=1, @HighImpactConfirmed=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@xeJson OUTPUT;
SELECT @xeJson AS JsonResult;
```

### Beispiel 4

```sql
CREATE TABLE #USP_ExtendedEventsAnalysis_moduleStatus (Seed int NULL);
BEGIN TRY
 EXEC [monitor].[USP_ExtendedEventsAnalysis] @MitSessionInventar=1, @MitTargetRuntime=0, @MitEvents=0, @MitDeadlocks=0, @MitBlockedProcesses=0, @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#USP_ExtendedEventsAnalysis_moduleStatus"}';
 SELECT * FROM #USP_ExtendedEventsAnalysis_moduleStatus;
END TRY
BEGIN CATCH
 IF OBJECT_ID('tempdb..#USP_ExtendedEventsAnalysis_moduleStatus') IS NOT NULL DROP TABLE #USP_ExtendedEventsAnalysis_moduleStatus;
 THROW;
END CATCH;
DROP TABLE #USP_ExtendedEventsAnalysis_moduleStatus;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `moduleStatus`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

TABLE und CONSOLE verwenden dieselbe vollständig materialisierte Modulstatusmenge mit fünf Feldern. Die drei Textfelder besitzen explizit `SQL_Latin1_General_CP1_CS_AS`. CONSOLE ergänzt bei vorhandenen Modulzeilen die Ergebnisbeschriftung; bei leerer Menge liefert es genau die bestehende dreifeldrige Leeranzeige. Der Parentstatus steht im RAW-Metaresultset beziehungsweise in `meta.statusCode` des JSON.

JSON enthält weiterhin benannte Childobjekte und `warnings`; ein `modules`-Array gehört nicht zu diesem Vertrag.

## Eine Zeile bedeutet

In TABLE und CONSOLE bedeutet eine Modulstatuszeile einen tatsächlich aufgerufenen Childpfad mit seiner Aufrufreihenfolge und seinem Invocationstatus. Die fachlichen RAW- und JSON-Childresultate behalten ihre jeweils eigene Granularität.

## So lesen

Berücksichtigen Sie Inventar und Source-/Targetstatus vor Ereignisparsern. Childstatus bestimmt, ob leere Fachdaten interpretierbar sind.

## Warum kann das problematisch sein?

Deadlock- oder Blockinganalyse ohne verlässliche Quelle kann falsche Entwarnung erzeugen.

## Wann ist es kein Problem?

Nicht aktivierte Event-Children fehlen absichtlich.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Session gestoppt und Deadlockresultset leer bedeutet „keine Evidenz erfasst“, nicht „keine Deadlocks“. Prüfen Sie Vorhandene XEL-Dateien oder Konfiguration.

**Ähnlich aussehender Gegenfall:** Nicht aktivierte Event-Children fehlen absichtlich. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Eine laufende Session kann ohne passendes Ereignis leer sein; außerdem können Target, Dateipfad, Rollover, Flushzustand und Berechtigung die Sicht einschränken.

Für `USP_ExtendedEventsAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

`@MaxZeilen` wird an die dafür vorgesehenen Children weitergereicht; NULL und 0 bleiben ohne Zeilenlimit. Die Modulstatusmenge wird dadurch nicht gekürzt. Ein negativer Wert wird vor der Childausführung als `INVALID_PARAMETER` abgelehnt und lässt die Modulstatusmenge leer. Ein `EXECUTED`-Eintrag bestätigt den abgeschlossenen Childaufruf; dessen fachlicher Status ist zusätzlich im Child-JSON zu lesen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Nur `USP_ExtendedEventsSessions` ist aktiviert. Er inventarisiert Definition und Laufzeitstatus mit `@MaxZeilen = 100`, liest aber weder Ereignisdateien noch Targetdaten. |
| Teuerster Pfad | `@MitTargetRuntime`, `@MitEvents`, `@MitDeadlocks` und `@MitBlockedProcesses` gemeinsam: Eventdatei oder Ring Buffer werden je Forensik-Child separat gelesen und XML mehrfach für unterschiedliche Granularitäten zerlegt. Targetruntime kann zusätzlich einen ausdrücklich bestätigten Target-Flush auslösen. |
| Haupttreiber | Größe und Rollover der gewählten XEL-Dateien beziehungsweise des Ring Buffers, Anzahl der Ereignisse im Zeitfenster und XML-Komplexität von Deadlock-/Blocked-Process-Reports. Das Sessioninventar ist gegenüber diesen Pfaden meist klein. |
| Skalierung | Die Children laufen nacheinander und teilen keinen materialisierten Ereignissnapshot. Drei aktivierte Ereignis-Children können dieselbe Quelle daher dreimal lesen und parsen; breite Reports erhöhen CPU, Arbeitsspeicher, TempDB und Transfer. |
| Ressourcen | Im Standard nur XE-Katalog-/Runtime-CPU. Optional kommen Datei-I/O über `sys.fn_xe_file_target_read_file`, Ring-Buffer-/Targetzugriff und XML-Shredding hinzu; `msdb` und Datenbankscans gehören nicht zu diesem Orchestrator. |
| Begrenzungswirkung | Session-/Event-/Targetfilter gelten nicht für jedes Child gleich: Inventarfilter steuern Katalogresultsets, die Forensikchildren verwenden die einzelne `@SourceExtendedEventSessionName`, Quelle, Datei und Zeitgrenzen. `@MaxZeilen` wird an Ereignischildren weitergegeben, begrenzt aber nicht zwingend das vorgelagerte Datei- und XML-Lesen; Targetruntime besitzt kein Parent-Zeilenlimit. |
| Locking und Nebenwirkungen | Keine Nutzdatenänderung. TargetRuntime und bestätigte Ringbuffer-Lesezugriffe können durch das Lesen von `sys.dm_xe_session_targets` einen Flush auslösen. Geben Sie die Bestätigung ausdrücklich als 0 oder 1 an. NULL kann bei TargetRuntime sowie den expliziten Deadlock- und Blocking-Ringbufferpfaden die Prüfung auf 0 passieren. Die sequenziellen Childresultate sind kein atomarer Ereignissnapshot. |
| Schutzmechanismus | Ereignisforensik und Targetruntime prüfen `EXTENDED_EVENTS_FORENSICS_DEEP` über `@HighImpactConfirmed`. Für Targetruntime ist die Flushbestätigung ein zweites, unabhängiges Gate. Keiner der beiden Schalter ist ein Laufzeit- oder Mengenlimit. |
| Sicherer Einsatz | Zuerst nur das Inventar ausführen. Danach genau ein Forensik-Child, eine `ExampleSession`, einen engen UTC-Zeitraum und ein kleines `@MaxZeilen` wählen; Targetruntime erst nach bewusster Flushentscheidung aktivieren. |
| Aussagegrenze | Ein erfolgreiches Inventar beweist keine Ereigniserfassung. Ein begrenztes Ereignisresultset beschreibt nur die noch vorhandene gewählte Quelle; Rollover, Drops und ein spätes Zeilenlimit können relevante Events unsichtbar machen. Childresultate dürfen wegen getrennter Lesezeitpunkte nicht als transaktional konsistent behandelt werden. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche XE-Konfigurations-, Runtime- und Ereignisperspektiven sollen gemeinsam geprüft werden?

### Technischer Hintergrund

Der Wrapper ruft Sessions, allgemeine Events, Deadlocks, Blocked Processes und Target Runtime auf. Eventlesen kann Datei-I/O und XML-Parsing verursachen; Filter/MaxRows begrenzen den Pfad.

### Datenkette

Die Datenkette besteht aus frameworkinterner Orchestrierung; die Quellen liegen in den Childmodulen.

### Source Select

Kein einzelnes Grundselect wird verwendet. Die Procedure orchestriert `USP_ExtendedEventsSessions`, `USP_ExtendedEventsTargetRuntime`, `USP_ExtendedEventsReadEvents`, `USP_ExtendedEventsDeadlocks` und `USP_ExtendedEventsBlockedProcesses`. Katalog-, Runtime-, Datei- und XML-Quellen bleiben bewusst getrennte Childpfade.

**Wichtig für die Eigenlast:** Berücksichtigen Sie zuerst nur das Sessioninventar. Aktivieren Sie Targetdaten, XEL-Dateien und XML-Forensik gezielt je Session und Zeitfenster; ein spätes Ergebnislimit ersetzt diese Quellbegrenzung nicht.

### Zeit- und Scope-Modell

Die Auswertung kombiniert den aktuellen Zustand und die Targethistorie nicht atomar.

### Bewertung und Gegenprobe

Bewerten Sie zuerst Session/Targetstatus, erst danach leere/gefüllte Ereignisresultsets. Vertiefen Sie Spezialevents nach Triage separat.

### Typische Fehlinterpretation

Ein leeres Gesamtbild kann durch deaktivierte Session oder Retention entstehen und ist keine Systemgesundheitsaussage.

### Folgeanalyse

Führen Sie das Child gezielt mit Session, Zeitraum, Eventname und einer begrenzten Dateimenge erneut aus.

## Primärquellen

- [Extended Events](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/extended-events?view=sql-server-ver17)

[Technische Detailbeschreibung](../06_Extended_Events.md#6-monitorusp_extendedeventsanalysis)

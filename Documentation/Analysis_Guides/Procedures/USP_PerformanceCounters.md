# [monitor].[USP_PerformanceCounters]

**Bereich:** Server Health<br>
**Zweck:** Liest typisierte SQL-Server-Performance-Counter und berechnet bei Bedarf Sample-/Delta-Werte.<br>
**Beobachtungsart:** kumulative Datei-/Counterwerte + optionale Stichprobe<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Wie werden SQL-Server-Performance-Counter korrekt als Raw, Ratio, Rate oder Delta interpretiert?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure liest sys.dm_os_performance_counters und sys.dm_os_sys_info, erstellt zwei Messstände und wartet nur bei positivem SampleSeconds. Sie persistiert keinen Verlauf und bestimmt keine vollständige OS-/Hypervisorursache.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PerformanceCounters]
      @SampleSeconds = 5,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@ObjectNames` | `nvarchar(max)` | `NULL` | Optionaler Filter auf Objektbezeichnungen aus sys.dm_os_performance_counters. Mehrere Werte werden als bracket-aware Pipe-Liste durch monitor.TVF_ParseStringList geparst. Äußere Leerzeichen werden entfernt; Pipe-Zeichen in eckig geklammerten Werten bleiben erhalten, ]] maskiert eine schließende Klammer. Der entquotierte StringValue wird case-sensitive verglichen. NULL lässt alle Objekte zu. Leerstring, leeres Element, ungültige Klammerstruktur, leerer entquotierter Wert oder ein Segment über 4000 UTF-16-Codeeinheiten ergibt INVALID_PARAMETER. Duplikate bleiben erhalten, ändern den EXISTS-Filter aber nicht. Wildcards sind Literale. |
| `@CounterNames` | `nvarchar(max)` | `NULL` | Optionaler Filter auf Counterbezeichnungen mit derselben bracket-aware Pipe-Syntax und denselben Parsergrenzen. NULL lässt alle Counter zu. Der direkte Vergleich ist case-sensitive; zusätzlich wird Name plus N' base' case-insensitive einbezogen, damit die Basiscounter für Quotienten verfügbar sind. Ungültige Listenelemente ergeben INVALID_PARAMETER. Duplikate ändern den EXISTS-Filter nicht; Wildcards werden nicht als Muster ausgewertet. |
| `@SampleSeconds` | `tinyint` | `0` | Angabe in Sekunden. 0 liest zwei unmittelbar aufeinanderfolgende DMV-Stände ohne WAITFOR und erzwingt für Delta-Typen SAMPLE_REQUIRED_FOR_DELTA_METRIC. 1 bis 60 wartet zwischen den Messungen; verwendet wird die tatsächlich gemessene Dauer. Werte über 60 sind INVALID_PARAMETER; tinyint erlaubt 0 bis 255. NULL passiert die &gt;60-Prüfung und löst kein WAITFOR aus; weil der Caller nur bei exakt 0 die Sampledauer auf 0 setzt, wird bei NULL die gemessene UTC-Dauer an die Interpretationsfunktion übergeben. Typen: 65792 RAW_SNAPSHOT; 272696320 und 272696576 RATE_PER_SECOND (Delta geteilt durch Samplesekunden); 537003264 FRACTION_DELTA_PERCENT (100 mal Zählerdelta geteilt durch Basisdelta); 1073874176 AVERAGE_DELTA_RATIO (Zählerdelta geteilt durch Basisdelta); weitere Typen RAW_UNINTERPRETED. Deltas erfordern einen nicht fallenden Zähler; Quotienten zusätzlich eine vorhandene, steigende Basis. Basiscountertypen 1073939458 und 1073939712 werden nicht als Ergebniszeilen ausgegeben. Keine Persistenz. Die gemessene Dauer beginnt vor dem Temp-Tabellenaufbau und dem ersten DMV-Lesen und endet vor dem zweiten Lesen; sie ist keine reine WAITFOR-Dauer. |
| `@MaxZeilen` | `int` | `1000` | Nichtnegative int-Anzahl. Werte unter 0 ergeben INVALID_PARAMETER. Werte von 1 bis 2147483647 begrenzen RAW-/CONSOLE-Zeilen und JSON-Countereinträge; 0 und NULL werden auf die größte bigint-TOP-Grenze abgebildet. Die Begrenzung greift erst nach beiden Snapshots, Interpretation und Materialisierung und begrenzt keine Quellarbeit. TABLE exportiert die materialisierten Counter ohne dieses TOP-Limit. Sortierung nach ObjectName, CounterName und InstanceName; keine repräsentative Stichprobe. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Ausgabeart, normalisiert mit LTRIM/RTRIM und UPPER. RAW liefert Status und technische Counterzeilen; CONSOLE Status und eine beschriftete Helferansicht; TABLE schreibt das einzelne Resultset counters in ein lokales Ziel; NONE unterdrückt reguläre Resultsets. Gültig sind ausschließlich RAW, CONSOLE, TABLE und NONE; NULL oder Leertext ist ungültig. CONSOLE und TABLE werden intern als NONE verarbeitet und anschließend über separate Helfer ausgegeben. JSON ist davon unabhängig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Optionales JSON-Mapping auf das lokale #temp-Ziel des einzigen TABLE-Resultsets counters. Nur bei ResultSetArt=TABLE zulässig; ein nichtleerer, getrimmter Wert in einer anderen Ausgabeart löst Fehler 51011 vor Hilfe- und Statusverarbeitung aus. NULL, leer oder nur Leerzeichen bedeutet kein Mapping. Der TABLE-Preflight läuft vor dem Hilfezweig und kann daher auch bei Hilfe scheitern. |
| `@JsonErzeugen` | `bit` | `0` | Bit-Schalter: 0 unterdrückt JSON, 1 erzeugt es; NULL aktiviert den Zweig nicht. Das Objekt enthält meta, counters und warnings; warnings ist ein leeres Array, counters unterliegt MaxZeilen. JSON kann mit jeder Ausgabeart erzeugt werden. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Empfänger vom Typ nvarchar(max). Der Eingabewert wird beim Eintritt auf NULL gesetzt, auch bei Hilfe. Mit JsonErzeugen=1 wird später JSON mit meta, counters und warnings zugewiesen; andernfalls bleibt der Wert NULL. Im EXEC mit einer nvarchar(max)-Variablen und OUTPUT binden. |
| `@PrintMeldungen` | `bit` | `1` | Bit-Schalter: 0 unterdrückt Meldungen; 1 sendet bei StatusCode ungleich AVAILABLE eine Severity-10-Meldung mit RAISERROR ... WITH NOWAIT. NULL aktiviert die Meldung nicht. Der Text ist ErrorMessage oder ersatzweise der Statuscode. Die Meldung steuert die Resultsets nicht. |
| `@Hilfe` | `bit` | `0` | Bit-Schalter: 1 druckt Kurzinfos und kehrt vor dem Sampling sowie vor allen vier Status-OUTPUT-Zuweisungen zurück; NULL/0 führt regulär aus. Json wird zuvor bereits auf NULL gesetzt. Ein unzulässiges nichtleeres ResultTablesJson außerhalb TABLE sowie der TABLE-Preflight werden vor dem Hilfezweig verarbeitet. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | OUTPUT varchar(40) mit globalem Status: AVAILABLE bei erfolgreichem Pfad; INVALID_PARAMETER bei ungültigen Listen-, Sample-, Zeilen- oder Ausgabeangaben; UNAVAILABLE_OBJECT ohne Counterzeilen oder nach Ausschluss nicht auswertbarer Basiscounter; DENIED_PERMISSION bei abgefangenen Fehlernummern 229, 262, 297, 300 oder 371; sonst ERROR_HANDLED. Hilfe lässt den Empfänger unverändert. Mit @StatusCodeOut=@Variable OUTPUT binden. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | OUTPUT bit: 1 bei INVALID_PARAMETER, UNAVAILABLE_OBJECT oder abgefangenem Fehler, sonst 0. Das Flag beschreibt nur den vom Modul erkannten Partialzustand und beweist keine allgemeine Vollständigkeit. Hilfe lässt den Empfänger unverändert; mit OUTPUT binden. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | OUTPUT int mit abgefangener SQL-Fehlernummer; im normalen Pfad NULL. Hilfe weist den Wert nicht zu und lässt den Empfänger unverändert. Mit @ErrorNumberOut=@Variable OUTPUT binden. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | OUTPUT nvarchar(2048) mit Validierungs-/Unavailable-Text oder abgefangener ERROR_MESSAGE; im regulären AVAILABLE-Pfad NULL. Hilfe weist den Wert nicht zu und lässt den Empfänger unverändert. Mit @ErrorMessageOut=@Variable OUTPUT binden. |

### Beispiele und Ausgabearten
Alle Werte sind synthetisch; jeder Block ist eigenständig.
#### RAW
```sql
EXEC [monitor].[USP_PerformanceCounters] @ObjectNames=N'[SQL Statistics]',@CounterNames=N'Batch Requests/sec',@SampleSeconds=5,@MaxZeilen=100,@ResultSetArt='RAW';
```
#### JSON
```sql
DECLARE @ExampleJson nvarchar(max)=NULL;
EXEC [monitor].[USP_PerformanceCounters] @SampleSeconds=5,@JsonErzeugen=1,@Json=@ExampleJson OUTPUT,@ResultSetArt='NONE';
SELECT @ExampleJson AS [ExampleJson];
```
#### TABLE
```sql
DECLARE @ExampleMap nvarchar(max)=CONCAT(N'{',NCHAR(34),N'counters',NCHAR(34),N':',NCHAR(34),N'#PerformanceCounters_HelpExample',NCHAR(34),N'}');
CREATE TABLE #PerformanceCounters_HelpExample ([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_PerformanceCounters] @ResultSetArt='TABLE',@ResultTablesJson=@ExampleMap;
 SELECT * FROM #PerformanceCounters_HelpExample;
 DROP TABLE #PerformanceCounters_HelpExample;
END TRY
BEGIN CATCH
 IF OBJECT_ID(N'tempdb..#PerformanceCounters_HelpExample') IS NOT NULL DROP TABLE #PerformanceCounters_HelpExample;
 THROW;
END CATCH;
```
#### Hilfe
```sql
EXEC [monitor].[USP_PerformanceCounters] @Hilfe=1;
```

## Resultsets und Leserichtung

TABLE exportiert counters. RAW und CONSOLE geben zusätzlich Status aus; JSON enthält Status/Samplerahmen in meta, Counter in counters und ein leeres warnings-Array.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Counter beziehungsweise einer normalisierten Countermessung für eine Instanzbezeichnung.

## So lesen

`UNAVAILABLE_OBJECT` mit `IsPartial=1` bedeutet, dass die Instanz keine aktivierten oder nach Ausschluss alleinstehender Basiscounter keine auswertbaren Zeilen aus `sys.dm_os_performance_counters` bereitstellt. In diesem Zustand werden weder Snapshotwerte noch Raten synthetisiert.

Objektname, Countername und Instanzname allein sind nicht die vollständige technische Identität: `cntr_type` gehört zum Schlüssel. Gleich benannte Zeilen unterschiedlicher Typen werden deshalb getrennt gesampelt und nicht miteinander verrechnet.

Die reine Funktion `monitor.TVF_InterpretPerformanceCounter` kapselt denselben Rechenpfad. Sie ermöglicht einen deterministischen Resetnachweis mit fallendem Vorher-/Nachher-Wert, ohne einen Serverneustart während einer laufenden Procedure zu simulieren.

Die Textspalten beider Counter-Snapshots und der Ergebnisarbeitstabelle verwenden
`SQL_Latin1_General_CP1_CS_AS`. Dieselbe Collation gilt am Join zum zweiten
DMV-Snapshot und für die sechs Textspalten des TABLE-Exports, auch bei abweichender
Server- oder `tempdb`-Collation. Objekt- und Counterfilter bleiben exakt; die
Zuordnung ergänzender `base`-Counter bleibt ausdrücklich case-insensitive.

Unterscheiden Sie Countertyp, Raw Value, Base, Delta, Samplezeit und normalisierten Wert.

## Warum kann das problematisch sein?

Rate- und Fraction-Counter werden ohne Typ/Base schnell falsch interpretiert. Kumulative Rohwerte spiegeln oft nur Uptime wider.

## Wann ist es kein Problem?

Ein einzelner hoher kumulativer Wert oder eine alte Faustregel ohne Baseline ist keine Diagnose.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Page Life Expectancy besitzt keine universelle feste Grenze. Ein abrupter Einbruch plus Memory Pressure und I/O ist relevanter als ein einzelner Wert. Prüfen Sie Memory, I/O und Workload.

**Ähnlich aussehender Gegenfall:** Ein einzelner hoher kumulativer Wert oder eine alte Faustregel ohne Baseline ist keine Diagnose. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Keine Zeile bedeutet, dass im gefilterten DMV-Scope kein auswertbarer Counter entstand. 0 ist ein gelesener Counterwert. NULL kennzeichnet nicht verfügbare Metriken oder Basen. IsPartial=1 steht für Invalid, Unavailable oder abgefangenen Fehler. MaxZeilen kann RAW/CONSOLE/JSON-Einträge ausblenden, begrenzt keine Quellarbeit und greift nicht auf den TABLE-Export.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | SampleSeconds=0 liest zwei unmittelbar folgende Counterstände ohne WAITFOR. Delta-Typen melden ohne positives Sample SAMPLE_REQUIRED_FOR_DELTA_METRIC. |
| Teuerster Pfad | Alle Counter/Instanzen, 60 Sekunden und unbegrenzte Ausgabe. Die gefilterte Countermenge wird zweimal gelesen; parallele Aufrufe halten jeweils eine Session und duplizieren die Snapshotarbeit. |
| Haupttreiber | Anzahl ausgewählter `(object_name, counter_name, instance_name)`-Kombinationen. Objekt-/Counternamen filtern bereits den ersten Snapshot; benötigte `base`-Counter werden automatisch mit aufgenommen. |
| Skalierung | Der zweite Snapshot joint nur auf die im ersten gefundenen Schlüssel. Berechnung und Speicher wachsen daher mit der gefilterten Countermenge; Sampledauer erhöht die Verbindungszeit linear, nicht die Anzahl der Counter. |
| Ressourcen | Zwei Lesezugriffe auf `sys.dm_os_performance_counters`, ein kleiner Startzeitlookup, Temp-Tabellen und CPU für typabhängige Delta-/Ratiointerpretation; optional eine wartende Verbindung. |
| Begrenzungswirkung | Objekt-/Counterlisten filtern den ersten Snapshot. MaxZeilen wirkt nach beiden Snapshots und Interpretation auf RAW/CONSOLE/JSON-Ausgabe; TABLE exportiert die materialisierten Zeilen ohne dieses Limit. |
| Locking und Nebenwirkungen | Read-only. WAITFOR hält keine Nutzdatenlocks absichtlich, belegt aber die Session. Restart oder Counterrückgang zwischen den Messpunkten wird als Resetkontext behandelt; die Procedure setzt keine Counter zurück. |
| Schutzmechanismus | Kein High-Impact-Gate. Objekt-/Counterlisten reduzieren beide Snapshots früh und `@SampleSeconds` ist auf 60 begrenzt; `@MaxZeilen` ist ausdrücklich nur ein Ausgabelimit. Mehrere parallele Sampler werden durch die Procedure nicht zentral verhindert. |
| Sicherer Einsatz | Fünf Sekunden, `@MaxZeilen = 100`, möglichst konkrete Objekt-/Counternamen und nur ein Sampler. Für eine Baseline mehrere getrennte Intervalle mit identischem Filter erfassen. |
| Aussagegrenze | Ein Rohwert ohne Countertyp/Base ist nicht interpretierbar. Kurze Samples können Bursts überbetonen, lange Samples Spitzen glätten. Das Ausgabelimit ist keine repräsentative Stichprobe und kann zusammengehörige Zähler-/Basezeilen unterschiedlich sichtbar machen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie werden SQL-Server-Performance-Counter korrekt als Raw, Ratio, Rate oder Delta interpretiert?

### Technischer Hintergrund

`sys.dm_os_performance_counters` enthält Counter mit `cntr_type`. Manche sind Momentwerte, manche kumulative Zähler, manche benötigen Basecounter und manche Differenz/Zeit. Instanznamen trennen Total, DB, Buffer Node oder Objektinstanzen.

### Datenkette

`sys.dm_os_performance_counters`, `sys.dm_os_sys_info`.

### Source Select

Der direkte Grundzugriff liest nur die benötigten Counter- und Instanznamen:

```sql
SELECT
      [pc].[object_name]
    , [pc].[counter_name]
    , [pc].[instance_name]
    , [pc].[cntr_value]
    , [pc].[cntr_type]
FROM [sys].[dm_os_performance_counters] AS [pc] WITH (NOLOCK)
WHERE [pc].[counter_name] IN
      (N'Page life expectancy',
       N'Batch Requests/sec',
       N'Page reads/sec')
  AND [pc].[instance_name] IN (N'', N'_Total');
```

**Wichtig für die Eigenlast:** Counter- und Instanzlisten in der DMV-Abfrage anwenden. Base-Counter und zwei Messpunkte nur für Countertypen lesen, die diese Berechnung benötigen; `@MaxZeilen` ist sonst lediglich ein Ausgabelimit.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Rohstand oder ein Frameworksample; der Resetzeitpunkt entspricht typischerweise dem Engine-Start.

### Bewertung und Gegenprobe

Prüfen Sie zuerst den Countertyp. Bewerten Sie eine Ratio mit der passenden Base, eine Rate als Delta pro Zeit und kumulative Counter zusammen mit der Uptime. Dokumentieren Sie Instance Name und Units. Verwenden Sie mehrere Counter als zusammenhängende Evidenzkette.

### Typische Fehlinterpretation

Raw `cntr_value` ist nicht allgemein Prozent oder pro Sekunde. Basecounter aus anderer Instanz/Probe erzeugt falsche Ratio.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Server Memory/CPU/IO, Current State und OS-Counter.

## Primärquellen

- [sys.dm_os_performance_counters](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-performance-counters-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#13-monitorusp_performancecounters)

# [monitor].[USP_SsisCatalogExecutionAnalysis]

**Bereich:** SSIS<br>
**Zweck:** Zeigt strukturierte Metadaten einer expliziten SSISDB-Ausführung.<br>
**Beobachtungsart:** Mehrere getrennte Katalogmomentaufnahmen<br>
**Kostenklasse:** LOW_MEDIUM; Umfang hängt von der sichtbaren Logginghistorie ab.

## Entscheidungsfrage und Einsatz

Die Procedure untersucht eine bekannte lokale Execution-ID. Sie zeigt native
Ausführungszustände und dazu sichtbare Statistik-, Ereignis-, Parameter-,
Phasen- und Row-Flow-Metadaten. Der Analyzer startet oder stoppt keine Pakete.

## Nicht beantwortete Fragen

Der Vertrag bewertet keine Ursache, Paketkorrektheit, Datenqualität oder
Performance. Meldungstexte, Kontextwerte, Parameterwerte, Pfade und
Host-/Loginidentitäten werden nicht gelesen. Datei-, ISPAC- und Legacy-Logs
gehören zu anderen Verfahren. Fehlende Sichtbarkeit ist kein Abwesenheitsbeweis.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SsisCatalogExecutionAnalysis]
    @ExecutionId=1, @MaxZeilen=200, @ResultSetArt='CONSOLE';
```

Die ID ist ein synthetisches Beispiel und muss durch eine bekannte sichtbare
Ausführung ersetzt werden. NULL oder eine nicht positive ID ist ungültig.
Der Aufruf erteilt keine Rechte und ändert weder Logging noch Retention.

## Resultsets und Leserichtung

RAW liefert `moduleStatus`, `execution`, `executables`, `messages`, `parameters`,
`phases`, `rowFlow`, `findings`, `sourceStatus` und `warnings` in dieser Reihenfolge.
Lesen Sie zuerst Status, Partialität und die einzelnen Quellen. TABLE schreibt
ausschließlich benannte Ziele aus `@ResultTablesJson`. JSON enthält dieselben
materialisierten Zeilen, einschließlich NULL-Feldern und leerer Arrays.
NONE unterdrückt fachliche Grids; CONSOLE zeigt genau eine Übersicht.
Die nativen Schemas und alle Parameter stehen im
[freigegebenen Vertrag](../../Architecture/SSIS_001_Phase0_Public_Contract.md#konkreter-katalogvertrag-vom-16-oktober-2026).

## Eine Zeile bedeutet

`execution` enthält höchstens eine sichtbare Katalogausführung. Eine Zeile in
`executables` entspricht einer nativen Statistikzeile, einschließlich wiederholter
Ausführungen desselben Executables. Namen werden über ExecutionId und
ExecutableId links ergänzt; fehlende Namen entfernen keine Statistikzeile.
`parameters` enthält Definition und Flags, keinen Wert. Phasen und Row-Flow
sind jeweils native Loggingzeilen, keine Schätzungen fehlender Aktivität.

## So lesen

ExecutionStatus bleibt unverändert. Findings benennen nur beobachtete Zustände:
3 ist abgebrochen, 4 fehlgeschlagen, 6 unerwartet beendet, 1 noch nicht gestartet
und 2/5/8 nicht terminal. Auch eine fehlgeschlagene Ausführung kann erfolgreich
und ohne Partialität gesammelt werden. Statistikdauer und RowsSent bleiben
native Werte; der Analyzer erfindet keine Dauer oder Durchsatzrate.

## Warum kann das problematisch sein?

RLS kann eine vorhandene Ausführung ausblenden. Getrennte Katalogabfragen sind
nicht atomar; eine laufende Ausführung kann sich zwischen ihnen verändern.
Ein positiver Zeilencap liefert einen geordneten N+1-Präfix und keine globale
Anzahl. Quellenfehler oder Limits dürfen nicht als erfolgreiche Leermengen
oder als Ausführungsfehler interpretiert werden.

## Wann ist es kein Problem?

Erfolgreich leere Performancequellen können vom erfassten Loggingumfang abhängen.
LOGGING_EVIDENCE_NOT_OBSERVED behauptet keine bestimmte Loggingstufe oder
Defektursache. Deaktivierte Quellen und erfolgreiche Leerquellen setzen keine
Partialität. Der native Ausführungsstatus allein ist kein Analyzerfehler.

## Beispiele und Gegenbeispiele

```sql
DECLARE @ExampleJson nvarchar(max);
EXEC [monitor].[USP_SsisCatalogExecutionAnalysis]
    @ExecutionId=1, @IncludePerformance=0, @ResultSetArt='NONE',
    @JsonErzeugen=1, @Json=@ExampleJson OUTPUT;
SELECT @ExampleJson AS [Json];
```

Die deaktivierten Quellen werden nicht angesprochen. Leere Arrays sind kein
Nachweis dafür, dass keine Tasks oder Datenbewegungen ausgeführt wurden.

## Leere oder partielle Ausgabe

Ohne sichtbare Execution meldet der Analyzer EXECUTION_NOT_VISIBLE_OR_ABSENT
und lässt die Childquellen ungelesen. Eine nicht sichtbare SSISDB führt nur bei
tatsächlich beobachtetem Linux zu UNAVAILABLE_PLATFORM; sonst bleibt
SOURCE_UNAVAILABLE. Native Fehler werden je Quelle mit Nummer und vollständiger
Meldung erhalten. Das erste tatsächliche Fehlerpaar folgt der festen Quellenfolge.
TRUNCATED, Deadline oder ein Quellenproblem begrenzen die Sammlung; andere
bereits gelesene Mengen bleiben erhalten. Ungültige TABLE-Mappings werfen 51011.

## Eigenlast und Grenzen

Kostenklasse: LOW_MEDIUM. Standardpfad: sieben auf eine Execution-ID gefilterte
Metadatenquellen. Teuerster Pfad: unbegrenzte Detailquellen einer großen
Logginghistorie. Haupttreiber: Ereignis-, Statistik- und Datenflusszeilen.
Skalierung: mit der sichtbaren Historie dieser Execution, ohne globalen Scan.
Ressourcen: temporäre Tabellen und JSON im Speicher beziehungsweise tempdb.
Begrenzungswirkung: @MaxZeilen begrenzt jede Detailquelle mit Sentinel; NULL/0
bedeutet unbegrenzt. Locking und Nebenwirkungen: lesende Katalogzugriffe mit
begrenzter Sperrwartezeit und unverändertem Callerzustand. Schutzmechanismus:
positive ID, 1–60 Sekunden kooperatives Zeitbudget zwischen Quellen und
0–60000 ms Locktimeout. Sicherer Einsatz: bekannte ID mit kleiner Detailgrenze.
Aussagegrenze: keine harte Deadline für eine laufende SQL-Abfrage und keine
atomare Gesamtsicht. Keine Pakete, Rechte oder Serveroptionen werden geändert.

## Technische Vertiefung

[Technische Detailbeschreibung](../../Architecture/SSIS_001_Phase0_Public_Contract.md#konkreter-katalogvertrag-vom-16-oktober-2026)

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche strukturierten Loggingmetadaten sind für diese sichtbare Ausführung vorhanden?

### Technischer Hintergrund

SSISDB stellt zeilenweise sichtbare catalog-Views bereit. Mehrere Statistikzeilen
können zu demselben Executable gehören; Namen sind keine Statistikidentität.

### Datenkette

Aus der Execution folgen Statistik und Namen, Ereignisse, Parameterdefinitionen,
Phasen und Row-Flow. Jede Quelle besitzt eine eigene Fehler- und Limitgrenze.

### Source Select

```sql
SELECT [execution_id], [status], [start_time], [end_time]
FROM [SSISDB].[catalog].[executions] WITH (NOLOCK)
WHERE [execution_id]=@ExecutionId;
```

**Wichtig für die Eigenlast:** Jede Detailquelle ist auf dieselbe Execution-ID
gefiltert. Der N+1-Präfix ersetzt keine globale Zählung.

Die festen dynamischen Projektionen lesen catalog.executions,
catalog.executable_statistics, catalog.executables, catalog.event_messages,
catalog.execution_parameter_values, catalog.execution_component_phases und
catalog.execution_data_statistics. Die Ereignisquelle bindet operation_id an
ExecutionId; alle übrigen Quellen filtern execution_id. Eine frei benannte
oder entfernte Quelle wird nicht akzeptiert.

### Zeit- und Scope-Modell

Native Zeiten bleiben datetimeoffset(7); CollectionTimeUtc bezeichnet die
Aufnahme. Der kooperative Timer wird zwischen den Quellen geprüft. Die
einzelnen Aufnahmen besitzen keine gemeinsame Transaktionsatomarität.

### Bewertung und Gegenprobe

Vergleichen Sie die native Statuszeile und die separat lesbaren Katalogquellen
unter denselben Rechten. Performance- und Verbose-Logging benötigen geeignete
positive Quellen; Basic-Leerfälle ersetzen diese Abnahme nicht.

### Typische Fehlinterpretation

AVAILABLE bezeichnet erfolgreiche Sammlung, keinen erfolgreichen Paketlauf.
ObservedRowCount=N+1 ist eine Untergrenze und kein Totalcount.

### Folgeanalyse

Der direkte DTSX-Parser ergänzt statische Paketmetadaten. Meldungsursachen und
Legacy-Logs sind kein Bestandteil dieses Katalogvertrags.

## Primärquellen

- [catalog.executions und Sichtbarkeit](https://learn.microsoft.com/sql/integration-services/system-views/catalog-executions-ssisdb-database?view=sql-server-ver17)
- [Executable-Statistik](https://learn.microsoft.com/sql/integration-services/system-views/catalog-executable-statistics?view=sql-server-ver17)
- [Phasen und Logginggrenzen](https://learn.microsoft.com/sql/integration-services/system-views/catalog-execution-component-phases?view=sql-server-ver17)
- [Native Datenflussstatistik](https://learn.microsoft.com/sql/integration-services/system-views/catalog-execution-data-statistics?view=sql-server-ver17)

## Nachweisgrenze

Der [begrenzte Windows-Katalogkernnachweis](../../Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#katalogkernabnahme-vom-16-oktober-2026) trennt positive Basic-Metadaten und Consumerparität von offenen Task-, Phasen-, RowFlow-, Legacy- und Berechtigungsnachweisen. Er ersetzt kein erforderliches Head-CI.

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

## Parametervertrag

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@ExecutionId` | `bigint` | `NULL` | Einzelne positive Ganzzahl 1 bis 9223372036854775807 als bigint für genau eine lokale SSISDB-Ausführung. Keine Liste oder freie Textquelle. NULL, ausgelassen oder kleiner als 1 ist im normalen Analysepfad ungültig und verhindert fachliche Quellenzugriffe. Wert 1 in Beispielen ist synthetisch und muss durch eine bekannte sichtbare ID ersetzt werden. Ausgelassen gilt der deklarierte Default NULL. |
| `@IncludeMessages` | `bit` | `1` | 1 fordert bei sichtbarer Ausführung und noch verfügbarem Zeitbudget den Read an: Ereignismetadaten aus catalog.event_messages; 0 überspringt die Quelle und markiert sie als nicht angefordert. NULL wird zu 1. Meldungstexte werden nicht gelesen. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@IncludeParameters` | `bit` | `1` | 1 fordert bei sichtbarer Ausführung und noch verfügbarem Zeitbudget den Read an: Definitionen und Flags aus catalog.execution_parameter_values; 0 überspringt die Quelle und markiert sie als nicht angefordert. NULL wird zu 1. Parameterwerte werden nicht gelesen. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@IncludePerformance` | `bit` | `1` | 1 liest Executable-Statistik, Executable-Namen, Phasen und Row-Flow, soweit die Ausführung sichtbar ist; 0 überspringt diese Quellen. NULL wird zu 1. Execution-, Meldungs- und Parameterquellen sind davon unabhängig. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@MaxZeilen` | `int` | `1000` | Einzelner SQL-int-Wert 0 bis 2147483647 oder NULL als Obergrenze je Detailquelle. Positives N liest höchstens N+1 geordnete Zeilen einschließlich Sentinel und gibt bei Überschreitung höchstens N zurück. NULL/0 bedeutet unbegrenzt; negativ ist ungültig. N+1 wird nach bigint-Konvertierung berechnet, daher kein int-Maximum-Überlauf. Betroffen sind nur Executable-Statistik, Executable-Namen, Meldungen, Parameter, Phasen und Row-Flow (Ordinale 2–7); nicht die einzelne Execution-Kopfzeile, Plattformprobe, Findings, warnings, sourceStatus oder moduleStatus. Ausgelassen gilt der deklarierte Default 1000. |
| `@MaxDurationSeconds` | `int` | `30` | Einzelner SQL-int-Wert in Sekunden. Kooperatives Gesamtzeitbudget zwischen den sieben SSISDB-Quellen, Bereich 1–60 Sekunden. NULL oder außerhalb ist ungültig. Die Deadline wird zwischen Quellen geprüft; eine laufende SQL-Abfrage wird nicht hart abgebrochen. Erschöpfung kann spätere Quellen auslassen und Partialität verursachen. Ausgelassen gilt der deklarierte Default 30. |
| `@LockTimeoutMs` | `int` | `0` | Einzelner SQL-int-Wert. Katalog-Sperrwartezeit in Millisekunden, Bereich 0–60000. NULL oder außerhalb ist ungültig. 0 bedeutet NOWAIT; positive Werte begrenzen die Wartezeit. Der eingehende LOCK_TIMEOUT wird nach dem Erfassungspfad wiederhergestellt. TABLE-Vorprüfung folgt zusätzlich dem Vertrag der internen Helfer. Ausgelassen gilt der deklarierte Default 0. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Textwert wird an varchar(16) gebunden und kann dabei auf diese Typbreite gekürzt werden; dann werden mit LTRIM/RTRIM U+0020-Randzeichen entfernt, UPPER angewandt und mit SQL_Latin1_General_CP1_CS_AS verglichen. Vollständige Wertemenge: CONSOLE = eine Übersicht; RAW = zehn geordnete Resultsets; TABLE = benannte lokale Temp-Tabellen; NONE = keine fachlichen Grids. Erst der nach Typzuweisung normalisierte Wert wird geprüft. NULL, leer oder nur U+0020 sind ungültig; weitere Whitespacezeichen werden nicht allgemein entfernt. Ausgelassen gilt der deklarierte Default 'CONSOLE'. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | JSON-Objekt mit Resultsetnamen als Schlüssel und lokalen #Temp-Tabellennamen als Stringwert. Alle erlaubten Schlüssel: moduleStatus (Modulstatus), execution (Ausführung), executables (Executable-Statistik), messages (Ereignismetadaten), parameters (Parameterdefinitionen), phases (Phasen), rowFlow (Datenflussstatistik), findings (Befunde), sourceStatus (Quellenstatus), warnings (Warnungen). Mindestens ein Schlüssel ist erforderlich; eine beliebige nichtleere Teilmenge dieser zehn Schlüssel genügt. Schlüssel werden binär einschließlich Groß-/Kleinschreibung verglichen; doppelte Schlüssel sind ungültig. Ziele müssen auch bei case-insensitivem Vergleich eindeutig sein, lokal und mit LEN höchstens 116, nicht ##Temp und nicht Präfix #Monitor. Jedes Ziel existiert bereits, ist leer und hat genau eine beliebige Seed-Spalte. TABLE verlangt gültige nichtleere Zuordnung; außerhalb TABLE sind NULL, leer oder nur U+0020-Leerzeichen erlaubt, nichtleerer Wert ungültig. Vorprüfung läuft nach Hilfe-Return, vor Hauptvalidierung, mit @ThrowOnError=1; Fehler können THROW entweichen und werden nicht als OUTPUT-Fehler garantiert. Ausgelassen gilt der deklarierte Default NULL. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt JSON mit denselben zehn Mengen einschließlich NULL-Feldern und leeren Arrays; 0 erzeugt kein JSON. NULL wirkt wie 0. JSON kann zusätzlich zu jedem ResultSetArt-Modus angefordert werden. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionales nvarchar(max) OUTPUT für das durch @JsonErzeugen=1 erzeugte Objekt. Empfänger als nvarchar(max)-Variable mit OUTPUT binden. Wird zu Beginn auf NULL gesetzt und bleibt ohne JSON-Erzeugung sowie bei Hilfe NULL. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL. |
| `@PrintMeldungen` | `bit` | `1` | Deklarierter bit-Eingabeparameter, nach der Signatur im Prozedurkörper nicht referenziert. Für 0, 1, NULL oder Auslassen ist daher keine Wirkung belegt; keine Funktion aus dem Namen ableiten. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@Hilfe` | `bit` | `0` | 0 oder NULL führt normal aus; NULL wird wie 0 behandelt. 1 druckt Hilfe und kehrt sofort zurück. Zuvor setzt die Procedure @Json, @StatusCodeOut, @IsPartialOut, @ErrorNumberOut und @ErrorMessageOut auf NULL. Hilfe umgeht TABLE-Vorprüfung, normale Parametervalidierung und Quellenzugriffe. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler varchar(40) OUTPUT für Sammelstatus; mit OUTPUT empfangen. Beim Eintritt NULL, bei Hilfe weiterhin NULL. Erreichbare Werte im normalen Ablauf: AVAILABLE (vollständig gesammelt), AVAILABLE_LIMITED (sichtbare Ausführung mit partieller Sammlung oder ohne nachweisbar sichtbare Ausführung nach leerem beziehungsweise wegen Zeitbudget ausgelassenem Kopfread), INVALID_PARAMETER (Hauptvalidierung verhindert Quellenzugriff), DENIED_PERMISSION (Zugriff verweigert), SOURCE_UNAVAILABLE (Katalog/Quelle nicht verfügbar), UNAVAILABLE_PLATFORM (nicht unterstützte Linux-Plattformbeobachtung), ERROR_HANDLED (behandelter sonstiger Fehler der Katalogsichtbarkeits- oder Execution-Quelle). TABLE-Preflight kann vorher THROW auslösen; dann ist kein Status-OUTPUT garantiert. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler bit OUTPUT für Partialität, mit OUTPUT empfangen. Beim Eintritt NULL und bei Hilfe NULL. Im normalen Ablauf 0 = vollständig, 1 = teilweise oder durch Hauptparameterfehler verhindert. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionaler int OUTPUT für die maßgebliche erfasste SQL-Fehlernummer, mit OUTPUT empfangen. Beim Eintritt NULL und bei Hilfe NULL; bei fehlerfreier Sammlung NULL. TABLE-Vorprüfungsfehler können THROW auslösen statt diesen OUTPUT zu befüllen. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL. Die Quellenfolge bestimmt das erste tatsächliche Fehlerpaar; reine Hauptparameterfehler und reine Limit-/Sichtbarkeitswarnungen setzen keine synthetische Fehlernummer. |
| `@ErrorMessageOut` | `nvarchar(4000) OUTPUT` | `NULL` | Optionales nvarchar(4000) OUTPUT für die maßgebliche erfasste SQL-Fehlermeldung, mit OUTPUT empfangen. Beim Eintritt NULL und bei Hilfe NULL; bei fehlerfreier Sammlung NULL. TABLE-Vorprüfungsfehler sind nicht als hier abgefangene Ausgabe garantiert. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL. Zusammen mit @ErrorNumberOut wird das erste tatsächliche native Fehlerpaar nach Quellenfolge projiziert; eine reine Hauptparameterablehnung setzt hier keinen synthetischen Text. |

## Weitere Aufrufbeispiele

Die Aufrufe verwenden den synthetischen Beispielwert @ExecutionId=1; sie behaupten nicht, dass die ID in der lokalen SSISDB existiert oder sichtbar ist. Ersetzen Sie ihn durch eine bekannte positive ID.

Hilfe; alle fünf OUTPUT-Werte bleiben NULL:

```sql
EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @Hilfe=1;
```

Zehn RAW-Resultsets in dokumentierter Reihenfolge:

```sql
EXEC [monitor].[USP_SsisCatalogExecutionAnalysis]
    @ExecutionId=1, @MaxZeilen=200, @ResultSetArt='RAW';
```

JSON bei unterdrückten fachlichen Resultsets empfangen:

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_SsisCatalogExecutionAnalysis]
    @ExecutionId=1, @ResultSetArt='NONE',
    @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json AS [Json];
```

Eine TABLE-Menge in ein vorab angelegtes leeres lokales Ziel schreiben:

```sql
CREATE TABLE #SsisExecution (Seed int NULL);
DECLARE @Map nvarchar(max)=N'{"execution":"#SsisExecution"}';
EXEC [monitor].[USP_SsisCatalogExecutionAnalysis]
    @ExecutionId=1, @ResultSetArt='TABLE', @ResultTablesJson=@Map;
SELECT * FROM #SsisExecution;
DROP TABLE #SsisExecution;
```

Das TABLE-Ziel muss vor dem Aufruf existieren, leer sein und genau eine Seed-Spalte besitzen. Die Vorprüfung läuft vor der Hauptparameterprüfung; ein Fehler kann als THROW entweichen. JSON entsteht nur, wenn @JsonErzeugen zusätzlich 1 ist.

## Resultsets und Leserichtung

RAW liefert `moduleStatus`, `execution`, `executables`, `messages`, `parameters`,
`phases`, `rowFlow`, `findings`, `sourceStatus` und `warnings` in dieser Reihenfolge.
Lesen Sie zuerst Status, Partialität und die einzelnen Quellen. TABLE schreibt
ausschließlich benannte Ziele aus `@ResultTablesJson`. JSON enthält dieselben
materialisierten Zeilen, einschließlich NULL-Feldern und leerer Arrays.
NONE unterdrückt fachliche Grids; CONSOLE zeigt genau eine Übersicht. @JsonErzeugen=1 liefert unabhängig von der Resultatart zusätzlich JSON; NULL verhält sich bei diesem Schalter wie 0.
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

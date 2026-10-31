# [monitor].[USP_SsisLegacyLogAnalysis]

**Bereich:** SSIS<br>
**Zweck:** Analysiert gespeicherte Legacy-Logereignisse einer expliziten GUID.<br>
**Beobachtungsart:** Begrenzter historischer Logausschnitt ohne Snapshotgarantie<br>
**Kostenklasse:** LOW_HIGH_OPT_IN; fehlende Filterindizes können auch begrenzte Aufrufe verteuern.

## Entscheidungsfrage und Einsatz

Welche Ereignisse, konkreten Meldungen und eindeutig zuordenbaren Zeitpaare
sind für eine bekannte Legacy-Ausführung gespeichert? Die Procedure liest
eine explizite lokale Loggingdatenbank und Execution-ID. Sie verändert weder
die vom Provider angelegte Tabelle noch deren Indizes oder Protokollierung.

## Nicht beantwortete Fragen

Zeitliche Nachbarschaft beweist keine Fehlerursache oder Fehlerpropagation.
Wiederholte Paare beweisen keine Schleife. Der Analyzer interpretiert keine
beliebigen Zahlen aus Meldungstexten als Lookup-Mengen oder Phasenzeiten.
Gespeicherte Informations-, Warn- und Fehlertexte bleiben dennoch vollständig
für die Diagnose verfügbar. Dedizierte computer-, operator- und databytes-Werte
werden nicht gelesen. Der Meldungstext selbst kann sensible Werte enthalten;
eine automatische Anonymisierung wird nicht zugesagt.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SsisLegacyLogAnalysis]
    @LoggingDatabase=N'ExampleSsisLogs',
    @ExecutionId='00000000-0000-0000-0000-000000000001',
    @MaxZeilen=200;
```

Datenbankname und GUID sind synthetische Platzhalter. Die Datenbank wird nicht
implizit aus dem Aufrufkontext abgeleitet; dbo.sysssislog ist der Default für
Schema und Tabelle. Zusätzliche Indizes sind keine Voraussetzung. Optionale
abweichende Namen adressieren eine bereits vorhandene kompatible Quelle;
sie konfigurieren keine Umbenennung des nativen SSIS-Providers.

## Parametervertrag

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@LoggingDatabase` | `sysname` | `NULL` | Im normalen Analysepfad ist die Quelldatenbank ausdrücklich anzugeben; Default NULL ist dafür ungültig. Einzelnes sysname-Datenbanksegment, Punkte werden nicht als mehrteilige Adressierung zerlegt; NULL oder nach LTRIM/RTRIM leer ist ungültig. QUOTENAME quotiert es separat. Wirkung: wählt die explizite Quelldatenbank. Beim Auslassen gilt der deklarierte Default NULL. Als ungeklammerten Unicode-Namen ohne zusätzliche SQL-Identifierklammerung übergeben, zum Beispiel N'dbo' für das Schema; vorhandene Punkte oder Klammerzeichen sind wörtliche Teile dieses einzelnen Segments. sysname bindet höchstens 128 Zeichen und kann längere Textargumente kürzen. Nur die Leerprüfung entfernt äußere U+0020-Leerzeichen; der adressierte Name selbst wird nicht getrimmt. |
| `@LoggingSchema` | `sysname` | `N'dbo'` | Auslassen verwendet dbo. Einzelnes sysname-Schemasegment; NULL oder nach LTRIM/RTRIM leer ist ungültig. Separates QUOTENAME. Beim Auslassen gilt der deklarierte Default N'dbo'. Als ungeklammerten Unicode-Namen ohne zusätzliche SQL-Identifierklammerung übergeben, zum Beispiel N'dbo' für das Schema; vorhandene Punkte oder Klammerzeichen sind wörtliche Teile dieses einzelnen Segments. sysname bindet höchstens 128 Zeichen und kann längere Textargumente kürzen. Nur die Leerprüfung entfernt äußere U+0020-Leerzeichen; der adressierte Name selbst wird nicht getrimmt. |
| `@LoggingTable` | `sysname` | `N'sysssislog'` | Auslassen verwendet sysssislog. Einzelnes sysname-Tabellensegment; NULL oder nach LTRIM/RTRIM leer ist ungültig. Separates QUOTENAME; ändert keinen Provider. Beim Auslassen gilt der deklarierte Default N'sysssislog'. Als ungeklammerten Unicode-Namen ohne zusätzliche SQL-Identifierklammerung übergeben, zum Beispiel N'dbo' für das Schema; vorhandene Punkte oder Klammerzeichen sind wörtliche Teile dieses einzelnen Segments. sysname bindet höchstens 128 Zeichen und kann längere Textargumente kürzen. Nur die Leerprüfung entfernt äußere U+0020-Leerzeichen; der adressierte Name selbst wird nicht getrimmt. |
| `@ExecutionId` | `uniqueidentifier` | `NULL` | Beim Auslassen ungültig. Erfordert eine Nicht-Null-GUID; NULL und 00000000-0000-0000-0000-000000000000 sind ungültig. Begrenzt die Analyse auf genau diese Ausführung. Beim Auslassen gilt der deklarierte Default NULL. Eingabeform: ein typisierter uniqueidentifier oder eine konvertierbare GUID-Zeichenfolge in der Form 00000000-0000-0000-0000-000000000001; keine Liste. |
| `@IncludeTimeline` | `bit` | `1` | Auslassen: 1. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Werte: 0 deaktiviert nur den Timeline-Export, 1 aktiviert ihn. NULL wird zu 1. Beim Auslassen gilt der deklarierte Default 1. |
| `@IncludeMessages` | `bit` | `1` | Auslassen: 1. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). 0 schaltet Meldungstextzugriff/-ausgabe ab; textabhängige Opt-in-Ableitungen können nicht verfügbar oder partiell werden, ohne diesen Parameter abzulehnen. 1 schließt Meldungstexte ein; bei message nvarchar(max) nur mit @HighImpactConfirmed=1. NULL wird zu 1. Texte können sensible Werte enthalten. Beim Auslassen gilt der deklarierte Default 1. |
| `@HighImpactConfirmed` | `bit` | `0` | Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Werte: 0 bestätigt nicht, 1 bestätigt die erforderliche Bedingung. NULL wird zu 0. Erforderlich bei @MaxZeilen NULL/0 oder eingeschlossenem message nvarchar(max); keine weitere Freigabe oder Laufzeitgarantie. Beim Auslassen gilt der deklarierte Default 0. |
| `@MaxZeilen` | `int` | `1000` | Auslassen: 1000. SQL-int-Ganzzahl bis 2147483647; negative Werte ungültig. NULL verhält sich wie 0; NULL/0 bedeutet unbegrenzte Ereignissammlung und erfordert @HighImpactConfirmed=1. Bei positivem N liest ein einzelner Ereignispuffer höchstens N+1 Einträge zur Trunkierungserkennung; abgeleitet werden die ersten N Ereignisse. Zusätzlich werden nur timeline, errorChain, iterations, loggingQuality, findings und rowFlowThroughput jeweils separat auf N Zeilen begrenzt. Andere optionale Arrays erhalten dadurch keine behauptete Einzelbegrenzung. Beim Auslassen gilt der deklarierte Default 1000. |
| `@MaxDurationSeconds` | `int` | `30` | Auslassen: 30. Ganze Zahl 1 bis 60 einschließlich; NULL, 0 und Werte außerhalb sind ungültig. Kooperative Deadline, die an Schritten/Ableitungen geprüft wird; kein harter Abbruch. Beim Auslassen gilt der deklarierte Default 30. |
| `@LockTimeoutMs` | `int` | `0` | Auslassen: 0. Ganze Zahl 0 bis 60000 Millisekunden einschließlich; NULL/außerhalb ungültig. 0 bedeutet NOWAIT. Wird für Quellzugriffe gesetzt; ursprüngliche Sitzungseinstellung wird vor Ausgabe wiederhergestellt. Eigene lokale Temp-DDL erhält bei geerbtem NOWAIT bis zu 1000 ms je Anlage. Gilt nicht als Timeout für TABLE-Ziele. Beim Auslassen gilt der deklarierte Default 0. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Auslassen: CONSOLE. Der Eingang wird zuerst in varchar(16) gespeichert, danach um äußere U+0020-Leerzeichen gekürzt und mit UPPER normalisiert; verglichen wird unter SQL_Latin1_General_CP1_CS_AS. Gültige Werte: CONSOLE (Übersicht), RAW (native Resultsets), TABLE (benannte Ausgabe), NONE (fachliche Grids unterdrücken). NULL, leer, nur U+0020 oder ein anderer normalisierter Wert ist ungültig. Vorherige Kürzung auf varchar(16) beachten; längere Eingabe ist nicht automatisch ungültig, wenn gespeicherter Wert einem Modus entspricht. Beim Auslassen gilt der deklarierte Default 'CONSOLE'. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Auslassen/NULL ist außerhalb TABLE gültig; dort ist auch leer oder nur U+0020-Leerzeichen erlaubt, nichtleerer Inhalt ungültig. In TABLE: gültiges nichtleeres JSON-Objekt von Resultsetnamen auf Zielnamen. Mindestens ein aktiver Schlüssel ist erforderlich; jede nichtleere Teilmenge der aktiven Basis- und Optionalnamen ist erlaubt; optionale Namen nur bei aktivem Opt-in. Vollständiger Preflight vor fachlichem Quellenzugriff. Ziele: vorhandene leere lokale #Temp-Tabellen mit genau einer Seed-Spalte beliebigen Namens und Typs ohne Seed-Zeile; keine ##Temp oder permanenten Tabellen. Unbekannte/inaktive Schlüssel, binär doppelte Schlüssel, case-insensitiv doppelte Ziele und unzulässige Ziele werden abgelehnt. Preflight wirft; OUTPUT ist nicht zugesichert. Zusätzlich gilt für rowFlowThroughput: @IncludeThroughputAnalysis=1 und zugleich @IncludeRowFlowAnalysis=1, weil beide Flags gemeinsam erforderlich sind. Beim Auslassen gilt der deklarierte Default NULL. Schlüssel werden binär einschließlich Groß-/Kleinschreibung verglichen. Zielnamen müssen Strings mit LEN höchstens 116 sein; #Monitor-Präfix ist case-insensitiv ausgeschlossen. Die Vorprüfung erfolgt nach Hilfe, vor der normalen Parameterprüfung; ein inaktiver optionaler Schlüssel ist auch dann ungültig, wenn die Tabelle existiert.<br>moduleStatus = Modulstatus, Laufkennung, Quellnamen und Gesamtergebnis (immer); execution = beobachtete Ausführungskennzahlen (immer); timeline = Ereignisfolge mit optionalem Meldungstext (immer); errorChain = zeitlich geordnete Fehler-/Warnereignisse, keine Kausalitätskette (immer); iterations = konservative zeitliche Ereignispaare (immer); loggingQuality = Beobachtbarkeit und Grenzen der Logdaten (immer); findings = beobachtete oder abgeleitete Befunde (immer); sourceStatus = Status angeforderter Analyseschritte (immer); warnings = Warnungen und Begrenzungen (immer).<br>taskDurations = beobachtete Tasklaufzeitaggregate (nur wenn @IncludeTaskAnalysis=1); taskLoggingCoverage = Loggingabdeckung je Task-Source-ID (nur wenn @IncludeTaskAnalysis=1); rowFlowEvents = einzelne OnPipelineRowsSent-Berichte (nur wenn @IncludeRowFlowAnalysis=1); rowFlow = abgeleiteter Zeilenfluss je Pfad (nur wenn @IncludeRowFlowAnalysis=1); componentPhaseEvents = einzelne PipelineComponentTime-Berichte (nur wenn @IncludeComponentPhaseAnalysis=1).<br>componentPhaseTimes = abgeleitete Komponentenphasenzeiten (nur wenn @IncludeComponentPhaseAnalysis=1); lookupCacheEvents = einzelne Lookup-/Cacheprofile (nur wenn @IncludeLookupCacheAnalysis=1); rowsWrittenEvents = einzelne Schreibmengenberichte (nur wenn @IncludeRowsWrittenAnalysis=1); rowFlowThroughput = gemeldete Pfadübertragungen je EXECUTE-Intervall (nur wenn @IncludeThroughputAnalysis=1 und @IncludeRowFlowAnalysis=1); finalCommitEvents = einzelne Final-Commit-Berichte (nur wenn @IncludeFinalCommitAnalysis=1); pipelinePhaseBeginEvents = einzelne Phasenbeginnprofile (nur wenn @IncludePipelinePhaseBeginAnalysis=1). |
| `@JsonErzeugen` | `bit` | `0` | Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Werte: 0 erzeugt kein JSON, 1 befüllt @Json. NULL verhält sich wie 0. Beim Auslassen gilt der deklarierte Default 0. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Auslassen: Default NULL. Zur Übernahme OUTPUT-Variable übergeben. Eintritt setzt NULL zurück, auch bei Hilfe; nur mit @JsonErzeugen=1 am Ende befüllt. Die Eingabe steuert den Aufruf nicht und wird beim Eintritt verworfen; nur für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. Beim Auslassen gilt der deklarierte Default NULL. |
| `@PrintMeldungen` | `bit` | `1` | Auslassen: 1. Format SQL bit; NULL bleibt als ungenutzter Wert ohne Wirkung. Die Werte 0 und 1 bewirken beide nichts, da der Parameter im Prozedurkörper nicht verwendet wird. Beim Auslassen gilt der deklarierte Default 1. |
| `@Hilfe` | `bit` | `0` | Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Werte: 0 normaler Pfad, 1 PRINT-Hilfe und RETURN vor TABLE-Vorprüfung sowie normaler Parameter-/Quellvalidierung. NULL wird zu 0. Alle fünf OUTPUTs werden zuerst auf NULL gesetzt und bleiben NULL; normaler SQL-Fehler-/PRINT-Vertrag bleibt unverändert. Beim Auslassen gilt der deklarierte Default 0. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Auslassen: Default NULL. Eintritt setzt NULL; Hilfe lässt NULL. Erreichbare Modulwerte: AVAILABLE = Ausführungseintrag vorhanden, nicht partiell; AVAILABLE_EMPTY = kein Ausführungseintrag, nicht partiell; AVAILABLE_LIMITED = partieller/begrenzter Lauf; INVALID_PARAMETER = ungültige Eingabe oder erforderliche Bestätigung fehlt; SOURCE_UNAVAILABLE = Quelle nicht verfügbar; DENIED = Quellzugriff verweigert; ERROR_HANDLED = behandelter Quellenfehler, geänderte Quellenidentität oder verworfener Puffer. Native SQL-Fehler/THROW können OUTPUT unerreichbar machen. Die Eingabe steuert den Aufruf nicht und wird beim Eintritt verworfen; nur für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. Beim Auslassen gilt der deklarierte Default NULL. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Auslassen: Default NULL. Eintritt setzt NULL. Normaler Pfad: 0 bedeutet nicht als partiell markiert, 1 partiell/begrenzt oder ungültige Eingabe. Hilfe lässt NULL; SQL-Fehler/THROW können OUTPUT unerreichbar machen. Die Eingabe steuert den Aufruf nicht und wird beim Eintritt verworfen; nur für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. Beim Auslassen gilt der deklarierte Default NULL. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Auslassen: Default NULL. Eintritt setzt NULL. Normaler Pfad: erfasste Fehlernummer, falls gesetzt, sonst NULL. Hilfe lässt NULL; SQL-Fehler/THROW können OUTPUT unerreichbar machen. Die Eingabe steuert den Aufruf nicht und wird beim Eintritt verworfen; nur für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. Beim Auslassen gilt der deklarierte Default NULL. |
| `@ErrorMessageOut` | `nvarchar(4000) OUTPUT` | `NULL` | Auslassen: Default NULL. Eintritt setzt NULL. Normaler Pfad: erfasster Fehlertext, falls gesetzt, sonst NULL. Hilfe lässt NULL; SQL-Fehler/THROW können OUTPUT unerreichbar machen. Die Eingabe steuert den Aufruf nicht und wird beim Eintritt verworfen; nur für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. Beim Auslassen gilt der deklarierte Default NULL. |
| `@IncludeTaskAnalysis` | `bit` | `0` | Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Bei den Optionen gilt: 0 deaktiviert, 1 aktiviert beobachtete Tasklaufzeiten und Loggingabdeckung je Source-ID; NULL wird zu 0. Fügt taskDurations/taskLoggingCoverage hinzu. Keine Tasktyp-/Konfigurationsbestimmung. Keine Nachrichtenabhängigkeit für diesen Scope. Beim Auslassen gilt der deklarierte Default 0. |
| `@IncludeRowFlowAnalysis` | `bit` | `0` | Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Bei den Optionen gilt: 0 deaktiviert, 1 aktiviert OnPipelineRowsSent-Pfade und Zeilenfluss; NULL wird zu 0. Fügt rowFlowEvents/rowFlow hinzu; keine Paketgesamtmenge. Nachrichten-Opt-out oder fehlende Voraussetzungen können den Scope nicht verfügbar oder partiell machen. Beim Auslassen gilt der deklarierte Default 0. |
| `@IncludeComponentPhaseAnalysis` | `bit` | `0` | Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Bei den Optionen gilt: 0 deaktiviert, 1 aktiviert PipelineComponentTime ProcessInput/PrimeOutput-Berichte; NULL wird zu 0. Fügt componentPhaseEvents/componentPhaseTimes hinzu; keine CPU- oder exklusive Zeit. Beim Auslassen gilt der deklarierte Default 0. |
| `@IncludeComponentLifecyclePhases` | `bit` | `0` | Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Bei den Optionen gilt: 0 deaktiviert, 1 aktiviert Validate/PreExecute/PostExecute-Berichte; NULL wird zu 0. Erfordert @IncludeComponentPhaseAnalysis=1, sonst INVALID_PARAMETER vor Quellenzugriff. Getrennte VALIDATE-/EXECUTE-Kontexte. Beim Auslassen gilt der deklarierte Default 0. |
| `@IncludeLookupCacheAnalysis` | `bit` | `0` | Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Bei den Optionen gilt: 0 deaktiviert, 1 aktiviert sechs einzelne Lookup-/Cacheprofile; NULL wird zu 0. Fügt lookupCacheEvents hinzu; keine Hit-Rate oder Gesamtmengenaddition. Beim Auslassen gilt der deklarierte Default 0. |
| `@IncludeRowsWrittenAnalysis` | `bit` | `0` | Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Bei den Optionen gilt: 0 deaktiviert, 1 aktiviert einzelne Schreibberichte; NULL wird zu 0. Fügt rowsWrittenEvents hinzu; keine Summen-/Commitgarantie. Beim Auslassen gilt der deklarierte Default 0. |
| `@IncludeThroughputAnalysis` | `bit` | `0` | Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Bei den Optionen gilt: 0 deaktiviert, 1 aktiviert gemeldete Pfadübertragungen je beobachtetem EXECUTE-Intervall; NULL wird zu 0. Fügt rowFlowThroughput hinzu. Erfordert @IncludeRowFlowAnalysis=1, sonst INVALID_PARAMETER vor Quellenzugriff. Beim Auslassen gilt der deklarierte Default 0. |
| `@IncludeFinalCommitAnalysis` | `bit` | `0` | Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Bei den Optionen gilt: 0 deaktiviert, 1 aktiviert einzelne Final-Commit-Berichte; NULL wird zu 0. Fügt finalCommitEvents hinzu; keine Persistenz-/Erfolgsgarantie. Beim Auslassen gilt der deklarierte Default 0. |
| `@IncludePipelinePhaseBeginAnalysis` | `bit` | `0` | Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Bei den Optionen gilt: 0 deaktiviert, 1 aktiviert sechs Phasenbeginnprofile; NULL wird zu 0. Fügt pipelinePhaseBeginEvents hinzu; keine Phasendauer-/Abschlussgarantie. Beim Auslassen gilt der deklarierte Default 0. |

### Aufrufbeispiele

Synthetische Namen und GUID vor Ausführung durch eine vorhandene kompatible Loggingquelle und konkrete Nicht-Null-GUID ersetzen.

```sql
EXEC [monitor].[USP_SsisLegacyLogAnalysis]
    @LoggingDatabase=N'ExampleSsisLogs',
    @ExecutionId='00000000-0000-0000-0000-000000000001',
    @Hilfe=1;
```

```sql
EXEC [monitor].[USP_SsisLegacyLogAnalysis]
    @LoggingDatabase=N'ExampleSsisLogs',
    @ExecutionId='00000000-0000-0000-0000-000000000001',
    @ResultSetArt='RAW', @IncludeMessages=0, @MaxZeilen=100;
```

```sql
DECLARE @JsonOut nvarchar(max);
EXEC [monitor].[USP_SsisLegacyLogAnalysis]
    @LoggingDatabase=N'ExampleSsisLogs',
    @ExecutionId='00000000-0000-0000-0000-000000000001',
    @ResultSetArt='NONE', @IncludeMessages=0,
    @JsonErzeugen=1, @Json=@JsonOut OUTPUT;
SELECT @JsonOut AS JsonOutput;
```

```sql
CREATE TABLE #ModuleStatus (Seed bit NULL);
CREATE TABLE #Warnings (Seed bit NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis]
    @LoggingDatabase=N'ExampleSsisLogs',
    @ExecutionId='00000000-0000-0000-0000-000000000001',
    @ResultSetArt='TABLE',
    @ResultTablesJson=N'{"moduleStatus":"#ModuleStatus","warnings":"#Warnings"}',
    @IncludeMessages=0, @MaxZeilen=100;
SELECT * FROM #ModuleStatus;
SELECT * FROM #Warnings;
DROP TABLE #Warnings;
DROP TABLE #ModuleStatus;
```

## Resultsets und Leserichtung

RAW liefert moduleStatus, execution, timeline, errorChain, iterations,
loggingQuality, findings, sourceStatus und warnings. Lesen Sie zunächst den
Modulstatus und die vier Kernquellenstatuszeilen; aktive Opt-ins ergänzen weitere Statuszeilen. CONSOLE liefert eine Übersicht
mit vollständigem erstem beobachtetem Fehlertext. TABLE schreibt ausschließlich
benannte Ziele; JSON enthält denselben begrenzten Exportstand einschließlich
NULL-Feldern und leerer Arrays. NONE unterdrückt fachliche Grids.

Der bisherige Vertrag mit neun Schemas bleibt ohne Opt-in erhalten.
Version 1.1.0 ergänzt ausschließlich an Position 21 `@IncludeTaskAnalysis bit=0`.
Bei 1 folgen `taskDurations` und `taskLoggingCoverage`: RAW11, elf TABLE-Namen
und JSON-Arrays, SchemaVersion 2 und eine fünfte Quellenstatuszeile.
CONSOLE ergänzt im selben Grid die drei Zähler BeobachteteQuellen,
GueltigeIntervalle und UngeklaerteGrenzereignisse. Ohne erfolgreiche
Zusatzableitung sind diese Zähler NULL. Die exakten 23-/25-Spaltenschemas
stehen in der [freigegebenen Erweiterung](../../Architecture/SSIS_001_Phase0_Public_Contract.md#freigegebene-erweiterung-legacy-tasklaufzeiten-und-loggingabdeckung-vom-18-oktober-2026).

Version 1.2.0 ergänzt unabhängig davon an Position 22
`@IncludeRowFlowAnalysis bit=0`. Bei 1 folgen rowFlowEvents und rowFlow mit
19 beziehungsweise 25 Feldern; SchemaVersion ist 3. RAW liefert dann elf
Mengen, bei beiden Opt-ins dreizehn. JSON und TABLE verwenden dieselben Namen.
sourceStatus ergänzt das feste Ordinal 6 rowFlowAnalysis auch ohne Ordinal 5.
CONSOLE ergänzt im selben Grid RowFlowMeldungen, RowFlowGeleseneMeldungen und
RowFlowZugeordneteMeldungen als nullable bigint; dies sind Meldungszähler.
Die [exakten Verträge](../../Architecture/SSIS_001_Phase0_Public_Contract.md#freigegebene-erweiterung-legacy-zeilenfluss-aus-onpipelinerowssent-vom-18-oktober-2026)
definieren die vier Kombinationen und alle Felder.

Version 1.3.0 ergänzt an Position 23 `@IncludeComponentPhaseAnalysis bit=0`.
Bei 1 folgen componentPhaseEvents mit 18 und componentPhaseTimes mit 24 Feldern
als letzte Mengen. SchemaVersion4 und ComponentPhaseCatalogVersion1 erscheinen
nur bei diesem Opt-in; alle acht Kombinationen stehen im
[freigegebenen Vertrag](../../Architecture/SSIS_001_Phase0_Public_Contract.md#freigegebene-erweiterung-legacy-komponentenphasenzeiten-aus-pipelinecomponenttime-vom-18-oktober-2026).
sourceStatus ergänzt das feste Ordinal 7 componentPhaseAnalysis unabhängig von
den optionalen Ordinalen 5/6. CONSOLE ergänzt im selben Grid PhasenMeldungen,
PhasenGeleseneMeldungen und PhasenKontextMeldungen als nullable bigint-Zähler.

Eine componentPhaseEvents-Zeile entspricht einer exakt benannten gespeicherten
PipelineComponentTime- oder User:PipelineComponentTime-Meldung. PCT_EN_1 und
PCT_EN_2 für ProcessInput/PrimeOutput werden
interpretiert; andere Formen bleiben ohne Teilpayload sichtbar. Der Byteguard
gilt wie beim Zeilenfluss auch für Endleerzeichen. componentPhaseTimes gruppiert
nur geparste Meldungen mit eindeutigem EXECUTE-Berichtskontext je Source,
Kontext, Methode und profilspezifischem Komponenten-/Outputschlüssel.
PCT_EN_1 verwendet berichtete numerische IDs, PCT_EN_2 binäre berichtete Namen.
ProcessInput hat NULL-Output.
OutputId ist keine RowFlow-PathId. Zeitwerte sind gemeldete Millisekunden;
Summen und Mittelwerte sind keine CPU-, exklusive oder Komponentengesamtzeit.
EventTime ist der Meldungszeitpunkt und erzeugt kein rückgerechnetes Intervall.
Auch ein passender Berichtskontext beweist keine vollständige Zuordnung der
gemessenen internen Arbeit zu diesem Vorkommen. Explizite 0 bleibt 0;
fehlende Meldungen erzeugen keine künstlichen Gruppen. Meldungs-Opt-out,
fehlende v1-Ableitung, Fehler und Deadline verwerfen beide neuen Mengen
atomar, behalten zuvor gültige Mengen und setzen neue Zähler NULL.

Version 1.4.0 ergänzt an Position 24 `@IncludeComponentLifecyclePhases bit=0`.
Der Wert 1 erfordert IncludeComponentPhaseAnalysis=1; andernfalls gilt
INVALID_PARAMETER vor jedem Quellenzugriff. NULL entspricht 0. Der
[freigegebene L1–L9-Vertrag](../../Architecture/SSIS_001_Phase0_Public_Contract.md#freigegebene-erweiterung-legacy-lifecycle-methodenberichte-vom-19-oktober-2026)
verwendet bei diesem Opt-in SchemaVersion5 und ComponentPhaseCatalogVersion2.
PCT_EN_3 interpretiert zusätzlich die exakten englischen Validate-, PreExecute-
und PostExecute-Texte unter User:PipelineComponentTime. Validate benötigt ein
eindeutiges VALIDATE-Paar derselben Source; die anderen vier Methoden benötigen
EXECUTE. Zuerst werden einschließende Log-ID-Paare gezählt, danach wird bei
genau einem Paar die Meldungszeit geprüft. Ein anderer Paartyp ist kein Ersatz.

Die bestehenden 18 Ereignis- und 24 Gruppenfelder, RAW-Mengen und Konsolenzähler
bleiben unverändert. Nicht berichtete IDs bleiben NULL; binäre Namen kennzeichnen
berichtete Labels innerhalb des jeweiligen Kontexts und keine bewiesene
Runtimekomponentenidentität. Ohne den neuen Opt-in bleibt PCT_EN_2 erhalten;
der nackte Ereignisname PipelineComponentTime behält ausschließlich PCT_EN_1.

## Lookup- und Cacheberichte als Opt-in

Version 1.5.0 ergänzt an Position 25 `@IncludeLookupCacheAnalysis bit=0`.
NULL entspricht 0. Der unabhängige Opt-in ergänzt genau eine letzte Menge
lookupCacheEvents mit 23 Feldern, SchemaVersion6, LookupCacheCatalogVersion1
und SourceOrdinal8 lookupCacheAnalysis. Die bisherigen 24 Positionen und
Schemas1–5 bleiben ohne den neuen Opt-in erhalten. RAW liefert dann
10/12/14/16 Mengen, abhängig von den übrigen Opt-ins. TABLE und JSON
verwenden denselben Namen; CONSOLE ergänzt im einzigen Grid die drei
nullable bigint-Zähler LookupCacheMeldungen, LookupCacheGeleseneMeldungen
und LookupCacheKontextMeldungen. NONE unterdrückt fachliche Grids.

Der [freigegebene K1–K9-Vertrag](../../Architecture/SSIS_001_Phase0_Public_Contract.md#freigegebene-erweiterung-legacy-lookup-und-cachemeldungen-vom-19-oktober-2026)
begrenzt die Interpretation auf sechs genaue englische Code-/Event-/Textformen
mit CRLF-Ende. Fortschritt, Gesamtmenge, hinzugefügte Unique-Zeilen und
verarbeitete Cachezeilen mit gemeldeten Sekunden und Byte bleiben getrennte
Berichte. Duplicate-/Missdiagnosen erhalten keine erfundenen Zeilenzähler;
Unique-/Missberichte ohne Namen behalten ComponentName=NULL. Dieselben Texte
auf Paket- und Data-Flow-Sources werden weder addiert noch dedupliziert.
SourceId bezeichnet das protokollierende Executable, ein Name nur ein Label.

Ein geparster Bericht kann ohne eindeutiges internes EXECUTE-Paar derselben
Source sichtbar bleiben; beide Kontext-IDs sind dann NULL. Fehlende Texte,
Kapazitätsgrenzen, unbekannte Formen und Code-/Eventwidersprüche ergeben
keine Teilpayloads. Die neue Stufe verwendet den freigegebenen N+1-Puffer,
prüft die gemeinsame kooperative Deadline und verwirft bei Fehlern atomar
ihre Menge und Zähler; gültige alte Ausgaben bleiben erhalten. IncludeMessages0
greift fachlich nicht auf message zu. Separate Vorbereitungszeiten und
Partial-Cache-Operationen bleiben mangels positiver Originale uninterpretiert.
Die Ausgabe beweist keine Cache-Hit-Rate, Konfigurationsvollständigkeit,
Datenqualität, physische Speichermessung oder technische Ursache.

## Gemeldete Schreibmengen als Opt-in

Objektversion 1.6.0 ergänzt `@IncludeRowsWrittenAnalysis bit=0` an Position 26.
Bei aktiviertem Opt-in liefert SchemaVersion 7 die letzte Menge
rowsWrittenEvents mit 21 Feldern. Der Quellenstatus rowsWrittenAnalysis besitzt
SourceOrdinal 9. RAW enthält eine zusätzliche Menge; TABLE verwendet denselben
Resultsetnamen und JSON dasselbe Array mit RowsWrittenCatalogVersion 1.
CONSOLE behält ein Grid und ergänzt die drei Berichtsanzahlen Schreibmeldungen,
GeleseneSchreibmeldungen und ZugeordneteSchreibmeldungen. NONE unterdrückt Grids.

Das [genaue Meldungsprofil](../../Architecture/SSIS_001_Phase0_Public_Contract.md#schreibmengen-aus-erhaltenen-legacy-meldungen-vom-23-oktober-2026)
interpretiert ausschließlich OnInformation mit DataCode 1074016267 und der
vollständigen englischen Schreibmeldung einschließlich CRLF. ReportedRows=0
bezeichnet eine ausdrücklich gemeldete Null; fehlende Meldungen liefern keine
solche Zeile. Nicht unterstützte Texte bleiben mit NULL-Payloadwerten sichtbar.
Ein eindeutiges beobachtetes EXECUTE-Paar liefert nur äußere Kontextgrenzen.

Die gleiche Meldung kann auf Data-Flow- und Paketebene vorkommen. Beide LogIds
bleiben einzeln erhalten. Weder Addition noch Deduplizierung erzeugen daraus
eine Paketgesamtmenge; die Meldung bestätigt keinen dauerhaften Commit.
Der Opt-in verwendet ausschließlich den bereits begrenzten Puffer. Bei
IncludeMessages=0 findet keine Textinterpretation statt. Deadline und native
Fehler verwerfen die neue Ableitung atomar und erhalten gültige andere Mengen.

Ein synthetisches Beispiel mit explizitem Loggingziel lautet:

```sql
EXEC [monitor].[USP_SsisLegacyLogAnalysis]
    @LoggingDatabase=N'ExampleLogging',
    @ExecutionId='11111111-1111-1111-1111-111111111111',
    @IncludeRowsWrittenAnalysis=1,
    @ResultSetArt='RAW';
```

Ohne passende Quelle oder ohne zugelassenen Text bleibt die Aussage begrenzt.
Quellenstatus und ParseStatus erklären die Abweichung; zusätzliche Provider-
oder Paketaktionen werden durch den Analyzer nicht ausgelöst.

## Eine Zeile bedeutet

Eine Timelinezeile entspricht einer materialisierten Logzeile. errorChain
enthält die zeitliche Folge von OnError, OnTaskFailed, OnWarning und OnQueryCancel.
execution fasst ausschließlich den analysierten Puffer zusammen. iterations
enthält konservative Start-/Endpaare oder ausdrücklich ungepaarte Ereignisse.
loggingQuality beschreibt konkrete Interpretationsgrenzen dieses Ausschnitts.

Eine taskDurations-Zeile fasst die konservativen EXECUTE- oder VALIDATE-Paare
einer beobachteten Source-ID zusammen. Nur zeitlich gültige Paare gehen in
Summe, Mittelwert, Minimum und Maximum ein. Echte 0 ms bleiben 0; ohne gültiges
Paar bleiben die vier Kennzahlen NULL. taskLoggingCoverage beschreibt
beobachtete Ereignisarten und konkrete Zuordnungsgrenzen. NULL-Source-IDs
bleiben einzelne ursprüngliche Log-IDs. Namen sind keine Identität;
ordinal verschiedene Namen einer ID setzen das Konfliktflag.

## So lesen

IncludeMessages=1 ist der Default für alle Ereignisarten. Dadurch bleiben auch
Lookup-Cachemeldungen, Zeilenmengen, Komponentenzeittexte und Duplicate-Warnungen
in der Timeline erhalten. Die erste OnError-Zeile bestimmt FirstErrorLogId
und FirstErrorMessage; nur ohne OnError wird OnTaskFailed verwendet. Ein leerer
Text wird nicht durch einen späteren Text ersetzt. Das ist kein Root-Cause-Nachweis.

## Warum kann das problematisch sein?

Ein positiver Zeilencap kann spätere Ereignisse ausschließen. NOLOCK kann bei
gleichzeitigen Änderungen Zeilen auslassen oder doppelt beobachten. Doppelte
IDs im gesamten N+1-Puffer verwerfen die Aufnahme vor der Sentinelentfernung.
Mehrdeutige Start-/Endfolgen werden nicht willkürlich verbunden. Die native
endtime-Spalte ist kein verwendbarer Laufzeitendpunkt.

## Wann ist es kein Problem?

Ein fehlender beobachteter Filterindex blockiert die Analyse nicht. OnError
ist ein fachlich protokolliertes Ereignis und kein SQL-Fehler des Analyzers.
Eine gültige fehlgeschlagene Ausführung kann AVAILABLE ohne Partialität ergeben.
IncludeTimeline=0 und IncludeMessages=0 sind bewusste Exportentscheidungen und
erzeugen für sich allein keine Partialität.

## Beispiele und Gegenbeispiele

```sql
DECLARE @ExampleJson nvarchar(max);
EXEC [monitor].[USP_SsisLegacyLogAnalysis]
    @LoggingDatabase=N'ExampleSsisLogs',
    @ExecutionId='00000000-0000-0000-0000-000000000001',
    @IncludeMessages=0, @ResultSetArt='NONE',
    @JsonErzeugen=1, @Json=@ExampleJson OUTPUT;
SELECT @ExampleJson AS [Json];
```

Dieser Opt-out liest message nicht fachlich; selbst eine fehlende oder
berechnete message-Spalte verhindert dann die strukturierte Analyse nicht.
Ein fehlender Fehlertext bei eingeschalteten Meldungen wird dagegen sichtbar
als ERROR_MESSAGE_MISSING ausgewiesen. Fehlende Duplicate-Warnungen beweisen
keine eindeutigen Lookup-Referenzdaten; die Warnung hängt vom Cachemodus ab.

Mit `@IncludeTaskAnalysis=1` können wiederholte beobachtete Intervalle verglichen
werden. Ihre Summe ist weder Paket-, CPU- noch exklusive Taskzeit. SourceType
bleibt UNRESOLVED; die Quelle kann auch ein Container oder Paket sein.
Ein nicht protokollierter Task erhält keine erfundene Zeile. Die Auswertung
bestätigt keine vollständige Loggingkonfiguration, Loop- oder Retryanzahl.
EvidenceLogIdsJson enthält einen JSON-Arraystring mit den ursprünglichen
Log-IDs; der äußere JSON-Vertrag transportiert diesen Wert als String.

Mit `@IncludeRowFlowAnalysis=1` wird jede exakt benannte OnPipelineRowsSent-
Meldung zunächst als Kandidat mit ParseStatus und GroupingStatus ausgegeben.
Nur die eng festgelegten englischen Profile ORPS_EN_1 und ORPS_EN_2 werden
interpretiert. ORPS_EN_2 verlangt zehn Felder und einen Endtrenner; die drei
Zusatztexte werden vollständig ordinal beziehungsweise auf die festgelegte
Form geprüft. Die Ausgabe behält die tatsächlichen numerischen Runtime-IDs.
Eine gespeicherte
Bytezahl ab der kleineren positiven Spaltenkapazität oder 4096 bleibt
POTENTIALLY_TRUNCATED; der vollständige Rawtext bleibt bei angefordertem
Timelineexport erhalten.
Andere Formate und Sprachen bleiben sichtbar, erhalten aber keine Payloadwerte.

rowFlow summiert ausschließlich erfolgreich geparste, eindeutig einem
abgeschlossenen EXECUTE-Paar zugeordnete Meldungen je Source, Vorkommen,
PathId, Zielkomponente und InputId. PathId ist keine OutputId. Gleichnamige
Sources und verschiedene Multicastpfade bleiben getrennt; ein Paketgesamtwert,
Commitnachweis oder Durchsatz wird nicht berechnet. Explizite 0 bleibt 0;
fehlende Meldungen erzeugen keine künstliche Nullsummengruppe. Namenskonflikte
werden ordinal erkannt und lassen den jeweiligen Gruppennamen NULL.

## Leere oder partielle Ausgabe

AVAILABLE_EMPTY bedeutet keine sichtbaren Ereignisse für diese GUID; die
Ausführung ist dadurch nicht sicher abwesend. Nicht unterstützte Schemas,
native Quellenfehler und Integritätsbefunde bleiben von erfolgreichen Leermengen
getrennt. Indexmetadaten sind beratend; ihr Fehler beendet die gültige
Ereignissammlung nicht. Das erste tatsächliche native SQL-Fehlerpaar bleibt
in den Modul-OUTPUTs erhalten. SSIS-Meldungstexte werden nicht als SQL-Exception
umgedeutet. Ungültige TABLE-Mappings werfen Frameworkfehler 51011.

Der Zusatzschritt verwendet denselben N+1-Puffer und die vollständig
abgeschlossene bisherige Ableitung. Bei ungültigem Puffer oder gescheiterter
vorheriger Ableitung bleiben die neuen Mengen leer und ihre Counts NULL;
PRIOR_DERIVATION_NOT_COMPLETED wird nicht als erfolgreiche Nullmenge ausgegeben.
Ein eigener Zusatzfehler verwirft beide neuen Mengen gemeinsam und erhält
gültige bisherige Ergebnisse sowie das erste tatsächlich erhobene Fehlerpaar.
Das gemeinsame kooperative Zeitbudget wird vor Beginn und vor Übernahme geprüft.

Die Zeilenflussstufe benötigt eingeschlossene Meldungen und einen gültigen
Puffer mit vollständig abgeschlossener ursprünglicher Ereignisableitung.
IncludeMessages=0 ergibt MESSAGES_DISABLED ohne fachlichen message-Zugriff.
Neue Mengen bleiben bei fehlender Zulassung oder Fehler gemeinsam leer,
Counts NULL; zuvor gültige Mengen und das erste native Fehlerpaar bleiben
erhalten. Die gemeinsame kooperative Deadline gilt vor Beginn und Übernahme.
Fehlende Ereignisse beweisen weder eine Nullmenge noch deaktiviertes Logging.

## Eigenlast und Grenzen

Kostenklasse: LOW_HIGH_OPT_IN. Standardpfad: Objekt- und Spaltenmetadaten,
beratende Indexmetadaten und eine auf die GUID gefilterte Ereignisabfrage.
Teuerster Pfad: unbegrenzte Sammlung oder eingeschlossene MAX-Meldungstexte.
Haupttreiber: Tabellengröße, Zugriffspfad, Pufferzeilen und Textvolumen.
Skalierung: Ein fehlender Index kann trotz TOP(N+1) zum globalen Scan führen.
Ressourcen: tempdb für Materialisierung und Ableitungen sowie Speicher für JSON.
Begrenzungswirkung: Zeilencaps begrenzen Aufnahme und fünf Fachdetailmengen,
garantieren jedoch keine bestimmte physische Lese- oder CPU-Menge.
Locking und Nebenwirkungen: NOLOCK ohne konsistente Momentaufnahme; keine
Quellschreiboperationen. Schutzmechanismus: explizite GUID und Datenbank,
kooperatives Zeitbudget und Locktimeout; unbegrenzt oder eingeschlossenes
nvarchar(max) benötigen HighImpactConfirmed=1. Sicherer Einsatz: ruhender
bekannter Slice mit kleinem Cap und geprüfter Berechtigung.
Aussagegrenze: keine harte Deadline einer laufenden Abfrage und keine
Wiederherstellung zuvor vom Provider gekappter Meldungen.

## Technische Vertiefung

[Technische Detailbeschreibung](../../Architecture/SSIS_001_Phase0_Public_Contract.md#konkreter-legacy-vertrag-vom-16-oktober-2026)

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Beobachtungen erlaubt genau dieser gespeicherte Logausschnitt?

### Technischer Hintergrund

Der SQL-Log-Provider schreibt sysssislog in die konfigurierte Zieldatenbank.
Die Procedure unterstützt gespeicherte kompatible Spalten einschließlich
einer als Systemtabelle sichtbaren nativen Providerquelle.

### Datenkette

Quellenmetadaten und Identität gehen der einen Materialisierung voraus.
Die vollständige N+1-Aufnahme wird geprüft, danach wird der Sentinel entfernt.
Alle weiteren fachlichen Ableitungen verwenden ausschließlich diesen Puffer.

### Source Select

```sql
SELECT [id], [event], [source], [sourceid], [executionid],
       [starttime], [endtime], [datacode], [message]
FROM [ExampleSsisLogs].[dbo].[sysssislog] WITH (NOLOCK)
WHERE [executionid]=@ExecutionId;
```

Die feste Projektion liest id, event, source, sourceid, executionid, starttime,
endtime und datacode sowie bei eingeschalteten Meldungen message. Getrennt
quotierte Datenbank-, Schema- und Tabellenbezeichner werden dynamisch gebunden;
executionid bleibt ein typisierter GUID-Parameter. Ein SELECT * auf der Quelle
ist ausgeschlossen.

**Wichtig für die Eigenlast:** TOP begrenzt die aufgenommenen Zeilen und
ersetzt weder einen günstigen Zugriffspfad noch eine physische IO-Grenze.

### Zeit- und Scope-Modell

Zeitpaare verwenden starttime der beiden Ereignisse. RawEndTime wird nicht
zur Dauerberechnung verwendet. Native datetime-Werte erhalten keine erfundene
Zeitzone. CollectionTimeUtc bezeichnet die getrennte Analyseaufnahme.

### Bewertung und Gegenprobe

Vergleichen Sie die ruhende Quelle unter denselben Rechten und derselben GUID.
Prüfen Sie Logs, Eventauswahl und Textspeichergrenzen, bevor aus fehlenden
Ereignissen ein tatsächlicher Paket- oder Datenfehler abgeleitet wird.

### Typische Fehlinterpretation

Ein PackageStart-/PackageEnd-Paar beweist keinen erfolgreichen Paketlauf.
Ein begrenzter Puffer liefert keine globale Zeilenzahl oder garantierte Erstursache.

### Folgeanalyse

Der direkte DTSX-Parser ergänzt statische Paketmetadaten. Der Kataloganalyzer
untersucht getrennt eine SSISDB-Execution; GUID und Katalog-ID werden nicht
automatisch miteinander verbunden.

## Zeilenfluss-Durchsatz mit beobachteter Zeitbasis

@IncludeThroughputAnalysis=1 benötigt @IncludeRowFlowAnalysis=1 und ergänzt
rowFlowThroughput mit SchemaVersion 8. Jede vorhandene Pfadgruppe erhält ihre
gemeldete Übertragungsmenge, das zugeordnete Pre-/Post-Execute-Zeitfenster
und gegebenenfalls ReportedTransferRowsPerSecond. Die Zeitbasis ist das
beobachtete EXECUTE-Intervall des Source-Vorkommens, keine gemessene exklusive
Komponentenzeit. RawEndTime dient nicht zur Dauerberechnung.

```sql
EXEC [monitor].[USP_SsisLegacyLogAnalysis]
    @LoggingDatabase = N'ExampleLogging',
    @ExecutionId = '00000000-0000-0000-0000-000000000001',
    @IncludeRowFlowAnalysis = 1,
    @IncludeThroughputAnalysis = 1,
    @HighImpactConfirmed = 1,
    @ResultSetArt = 'RAW';
```

Der Aufruf verwendet eine eigene bereits vorhandene kompatible Loggingquelle.
Bei ZERO_DURATION, unvollständiger Abdeckung oder einem ungeklärten Intervall
bleibt die Rate NULL; RateStatus erklärt die Grenze. Null gemeldete Zeilen
mit positiver Dauer ergeben dagegen die Rate null. Prüfen Sie dafür außerdem
rowFlowEvents und sourceStatus. Fehlendes Logging wird nicht als null Zeilen
oder vollständige Ausführung interpretiert. Pfade und Multicastzweige dürfen
nicht zu einer Paketgesamtmenge addiert werden. Die sechs rechnerischen
Nachkommastellen der Rate geben keine entsprechende Messgenauigkeit an.

RAW hängt die neue Menge zuletzt an; TABLE verwendet den Schlüssel
rowFlowThroughput. JSON liefert dieselben Felder über @Json OUTPUT.
CONSOLE ergänzt drei Bestandszähler; NONE bleibt ohne fachliche Grids.
Der [öffentliche Vertrag](../../Architecture/SSIS_001_Phase0_Public_Contract.md#zeilenfluss-durchsatz-aus-erhaltenen-originaldaten-vom-24-oktober-2026)
beschreibt alle Felder, Statusprioritäten und Aussagegrenzen.

## Primärquellen

- [Microsoft: sysssislog-Felder und Zeitgrenzen](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/sysssislog-transact-sql?view=sql-server-ver17)
- [Microsoft: SSIS Logging](https://learn.microsoft.com/en-us/sql/integration-services/performance/integration-services-ssis-logging?view=sql-server-ver17)
- [Microsoft: Lookup und cacheabhängige Duplicate-Warnungen](https://learn.microsoft.com/sql/integration-services/data-flow/transformations/lookup-transformation)

## Nachweisgrenze

Integrationstest 202 verwendet ausschließlich synthetische kompatible Tabellen.
Die getrennte [Providerabnahme vom 18. Oktober 2026](../../Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#legacy-providerabnahme-vom-18-oktober-2026)
verwendet tatsächlich ausgeführte eigene Pakete und native SQL-Log-Providerzeilen
auf Windows SQL/SSIS 17.0.1000.7 mit beobachtetem sysadmin. Vier Fälle besitzen
zwölf erfolgreiche Cap-Prüfungen mit Parität aller 94 TABLE-/JSON-Felder.
Eine getrennte native Gegenprüfung deckt gespeicherte Timelinefelder,
ausgewählte Mengen, Erstfehler- und Diagnosetexte, Paarzeiten sowie N+1 ab;
sie ist kein unabhängiges Orakel für alle abgeleiteten Felder.
Neun Cap-Prüfungen werden gebunden wiederverwendet. Native11 und Native12 bleiben
insgesamt FAILED_NOT_QUALIFIED, Native13 besteht. RAW mit neun, CONSOLE mit
einem und NONE ohne Resultset sowie der vollständige erste Fehlertext sind
geprüft. Weitere Rollen, native Engines und vertiefte Interpretation bleiben
offen. SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION.

## Abnahme der Taskerweiterung

Die [abgegrenzte Abnahme von v1.1.0](../../Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#taskintervalle-und-loggingabdeckung-abnahme-vom-18-oktober-2026)
bestätigt die neuen synthetischen Vertragsfälle und zwei tatsächlich
ausgeführte Windows-Szenarien für Wiederholung, gleiche Anzeigenamen,
Parallelität und selektives Logging. Das unabhängige native Orakel prüft
die 48 neuen Felder; Ausgabeparität und historische v1-Nachweise bleiben
getrennte Aussagen. Der Compatibility Level der privaten Windows-Captures
ist UNKNOWN. Weitere Engines und allgemeine Rollen sind damit nicht qualifiziert.

PCT_EN_2 übernimmt nur die ausdrücklich freigegebenen englischen Namensformen
unter User:PipelineComponentTime. Nicht berichtete Komponenten- und Output-IDs
bleiben NULL. Die Gruppen beziehen sich auf binär gleiche berichtete Labels
im Source-/EXECUTE-Kontext und beweisen keine eindeutige Runtimekomponente.
PCT_EN_1 behält seine numerischen Gruppenschlüssel; Profile werden nicht
zusammengeführt. Ohne den gesonderten Lifecycle-Opt-in bleiben andere Methoden sichtbar
abgelehnte Kandidaten.

## Abnahme der Komponentenmethodenberichte

Die [begrenzte Phasenabnahme](../../Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#legacy-komponentenphasenzeiten-begrenzte-abnahme-vom-18-oktober-2026)
prüft die 42 neuen Felder unabhängig gegen native Originalproviderzeilen.
Sechs gebundene P-N01-Consumer werden unverändert wiederverwendet; genau zwei
P-N02-Consumer ergänzen Wiederholung, gleiche Anzeigenamen mit getrennten IDs,
überlappende Ausführung und Präfixgrenzen. Die neue Quelle ist Windows
SQL/SSIS 17.0.5015.4 mit CL170 und beobachtetem sysadmin. Die Aussage betrifft
berichtete Methodenwerte und beobachtete Berichtskontexte; weitere Methoden,
Komponentenintervalle, CPU, exklusive Zeit und allgemeine Rollen sind nicht
qualifiziert. Historische Fehlversuche bleiben erhalten; exakte Head-CI und
Integration sind eigene Liefergates.

## Abnahme der Lifecycle-Erweiterung

Die [begrenzte Consumerabnahme](../../Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#legacy-lifecycle-methoden-begrenzte-consumerabnahme-vom-19-oktober-2026)
prüft sechs neue Aufrufkonstellationen anhand unverändert restaurierter eigener
Originalproviderzeilen. Alle 42 Felder werden unabhängig verglichen; physische
Schemas, TABLE/JSON, Präfixgrenze, Meldungs-Opt-out und Ausgabearten sind geprüft.
Es gibt keine neue Paket- oder SDK-Ausführung. Berichtete Validate-, PreExecute-
und PostExecute-Werte erweitern den begrenzten Methodenbestand, qualifizieren
aber keine internen Intervalle, CPU-/exklusive Zeiten oder allgemeinen Rollen.

Die begrenzte [Lookup-/Cacheabnahme](../../Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#begrenzte-lookup-cacheabnahme-vom-19-oktober-2026)
bestätigt Integration207, zwölf getrennte extrahierte Stufen und acht neue
Restoreconsumer aus erhaltenen Originaldaten. Neue Paket- und SDK-Aufrufe
sind 0; dies ist keine frische Provider- oder allgemeine Rollenqualifikation.

## Einzelne Final-Commit-Berichte lesen

@IncludeFinalCommitAnalysis=1 ergänzt finalCommitEvents mit SchemaVersion 9.
ObservationKind unterscheidet gemeldeten Start und gemeldetes Ende; LogId,
SourceId und MessageText erhalten die beobachtete Herkunft. ContextStatus
beschreibt die Zuordnung zum vorhandenen EXECUTE-Zeitfenster derselben Source.
ComponentName ist ein Meldungsname und kein verifizierter Tabellenname.

```sql
EXEC [monitor].[USP_SsisLegacyLogAnalysis]
      @LoggingDatabase = N'ExampleLogging'
    , @ExecutionId = '00000000-0000-0000-0000-000000000001'
    , @IncludeFinalCommitAnalysis = 1
    , @ResultSetArt = 'RAW';
```

Die Werte im Beispiel sind synthetisch und müssen durch die eigene Quelle
ersetzt werden. RAW hängt die neue Menge zuletzt an; TABLE verwendet den
Mappingnamen finalCommitEvents und eine eigene Caller-Temp-Tabelle. JSON
liefert dieselben 19 Felder einschließlich NULL. CONSOLE zählt Berichte in
einem Grid; NONE unterdrückt fachliche Grids.

Weitergereichte Meldungen auf Paketebene bleiben separate Zeilen. Start und
Ende werden nicht zu Commitoperationen gepaart oder gezählt. Eine Endmeldung
belegt keinen dauerhaft bestätigten Commit oder Paketerfolg. Leere Mengen,
fehlender Kontext und gekappte Aufnahmen begrenzen die Aussage. Bei
@IncludeMessages=0 bleibt die Interpretation mit MESSAGES_DISABLED aus.
Der [öffentliche Vertrag](../../Architecture/SSIS_001_Phase0_Public_Contract.md#final-commit-meldungen-aus-erhaltenen-originaldaten-vom-24-oktober-2026)
beschreibt Profile, ParseStatus, Schema und Grenzen.

## Pipeline-Phasenbeginnmeldungen lesen

@IncludePipelinePhaseBeginAnalysis=1 ergänzt pipelinePhaseBeginEvents mit
SchemaVersion 10. PhaseName unterscheidet Validation, Prepare for Execute,
Pre-Execute, Execute, Post Execute und Cleanup. Es handelt sich um gespeicherte
Beginnmeldungen, getrennt von den vorhandenen Komponentenphasenzeiten.

```sql
EXEC [monitor].[USP_SsisLegacyLogAnalysis]
      @LoggingDatabase = N'ExampleLogging'
    , @ExecutionId = '00000000-0000-0000-0000-000000000001'
    , @IncludePipelinePhaseBeginAnalysis = 1
    , @HighImpactConfirmed = 1
    , @MaxZeilen = 1000
    , @ResultSetArt = 'RAW';
```

Die Beispielwerte sind synthetisch und müssen durch die eigene Quelle ersetzt
werden. HighImpactConfirmed bestätigt hier das Lesen einer message-Spalte mit
nvarchar(max); MaxZeilen begrenzt den Ausschnitt. RAW hängt die Menge zuletzt
an. TABLE verwendet den Mappingnamen
pipelinePhaseBeginEvents und eine eigene Caller-Temp-Tabelle; JSON enthält
dieselben 19 Felder einschließlich NULL. CONSOLE zählt Berichte in einem Grid;
NONE unterdrückt fachliche Grids.

Validation wird nur einem VALIDATE-Paar derselben Source zugeordnet, andere
Phasen einem EXECUTE-Paar. Eine weitergeleitete Paketmeldung ohne passenden
Kontext bleibt sichtbar und unzugeordnet. Weitergeleitete Berichte werden
nicht dedupliziert oder summiert. Beginnmeldungen beweisen keinen Abschluss,
Fortschritt oder eine Phasendauer. Bei @IncludeMessages=0 ist die Interpretation
mit MESSAGES_DISABLED ausgeschaltet. Der [öffentliche Vertrag](../../Architecture/SSIS_001_Phase0_Public_Contract.md#pipeline-phasenbeginnmeldungen-aus-erhaltenen-originaldaten-vom-24-oktober-2026)
beschreibt genaue Profile, Status, Typen und Grenzen.

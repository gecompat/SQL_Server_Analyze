# SSIS-Paket-Analyse

Der [Abgrenzungs- und Austauschvertrag mit Toolbelt](../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)
beschreibt die gemeinsame Parser- und Lineagepflege bei weiterhin
eigenständigem Analyze-Betrieb ohne CLR. Der additive native Modellimport
verändert die bisherigen Paket- und Logschnittstellen nicht.

Die [iterationsgebundene Ausführungskorrelation](Procedures/USP_SsisPackageModelAnalysis.md#iterationsgebundene-ausführungskorrelation)
ordnet beobachtete For-/Foreach-Instanzen optional dem importierten Modell zu.
Sie zeigt Instanzzahlen, objektbezogene Dauern und die Grenzen der
Loggingbeobachtung. Die Containerklassifikation stammt aus Toolbelt;
Analyze benötigt weiterhin keine SQL-CLR-Installation.

## [monitor].[USP_SsisPackageAnalysis]

Der erste SSIS-001-Slice liest ausschließlich direkt übergebenes DTSX-v2-XML. Er inventarisiert Paket, Executables mit direkten Parent-Containern, direkte Precedence Constraints, Paket-Connection-Manager, Paketparameter, Variablendefinitionen, Pipeline-Komponenten, direkte Property-Expressions und direkte Pipeline-Komponentenlinien. Für Pipeline-Komponenten gibt er ausschließlich Namen und Klassenkennungen aus; für Expressions nur Scope und Eigenschaftsname. Connection Strings, Parameterwerte, Komponenteneigenschaften, Expressiontexte und sonstige sensitive Werte bleiben aus der Ausgabe ausgeschlossen. Weitergehende Lineage, Regeln sowie Datei-, ISPAC- und SSISDB-Adapter bleiben ausdrücklich ausgenommen.

Schema v3 ergänzt `variables` als dreizehntes RAW-Resultset. TABLE und JSON verwenden denselben begrenzten Variablenexport mit Scopezuordnung, Namespace, Name, Datentypcode und Booleanmetadaten. Event-Handler-Scope bleibt ausdrücklich begrenzt; Variablenwerte werden nicht gelesen oder ausgegeben. Der [öffentliche Vertrag](../Architecture/SSIS_001_Phase0_Public_Contract.md) beschreibt Schema, Defaults, NULL-Werte und Partialität.

## [monitor].[USP_SsisCatalogExecutionAnalysis]

Der Kataloganalyzer liest genau eine explizite lokale SSISDB-Ausführung. Er trennt Ausführungsstatus, Executable-Statistik, strukturierte Ereignisse, Parameterdefinitionen, Phasen und Row-Flow von Quellenfehlern. Meldungstexte, Parameterwerte, Pfade und Identitäten bleiben ausgeschlossen. Der [freigegebene Katalogvertrag](../Architecture/SSIS_001_Phase0_Public_Contract.md#konkreter-katalogvertrag-vom-16-oktober-2026) und die [Procedure-Anleitung](Procedures/USP_SsisCatalogExecutionAnalysis.md) beschreiben Limits, Sichtbarkeit und Aussagegrenzen. Der separate Legacy-Analyzer besitzt den nachfolgend beschriebenen freigegebenen Umfang.

### Parametervertrag

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

### Weitere Aufrufbeispiele

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

## [monitor].[USP_SsisLegacyLogAnalysis]

Der Legacy-Analyzer liest eine explizite Datenbank und genau eine GUID aus einer vorhandenen sysssislog-kompatiblen Tabelle. Meldungstexte aller Ereignisarten bleiben standardmäßig erhalten. Zusätzliche Indizes sind keine Voraussetzung. Die [Anleitung](Procedures/USP_SsisLegacyLogAnalysis.md) und der [freigegebene Vertrag](../Architecture/SSIS_001_Phase0_Public_Contract.md#konkreter-legacy-vertrag-vom-16-oktober-2026) trennen beobachtete Ereignisse von konservativen Zeitpaaren. Die [begrenzte Providerabnahme](../Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#legacy-providerabnahme-vom-18-oktober-2026) bestätigt vier synthetische Paketfälle mit zwölf gebundenen Cap-Prüfungen auf Windows SQL/SSIS 17.0.1000.7; neun Einzelbelege werden aus früheren insgesamt fehlgeschlagenen Versuchen wiederverwendet. Weitere Funktionen und Rollen bleiben offen; SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION.

Version 1.1.0 ergänzt mit `@IncludeTaskAnalysis=1` beobachtete EXECUTE-/VALIDATE-
Daueraggregate und Ereignisabdeckung je Source-ID. Ohne Opt-in bleiben die
bisherigen neun Ausgabegruppen erhalten. Die [Taskintervall-Abnahme](../Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#taskintervalle-und-loggingabdeckung-abnahme-vom-18-oktober-2026)
trennt synthetische Gegenproben, zwei neue native Szenarien und
Ausgabeparität. SourceType bleibt UNRESOLVED; weder vollständige Tasklisten
noch Loggingkonfiguration, Schleifenanzahl oder CPU-Zeit werden behauptet.


### Parametervertrag

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

## [monitor].[USP_SsisPackageModelAnalysis]

Der [native Modellimport](Procedures/USP_SsisPackageModelAnalysis.md) validiert
optional übergebenes JSON ohne CLR oder Toolbelt-Installation. Er prüft Felder,
Kennungen, Scopes und Referenzen; Originalbytes erlauben einen unabhängigen
Paketbytevergleich. Die Producerherkunft bleibt UNVERIFIED. Der Importer
berechnet keine neue Lineage und führt weder Pakete noch enthaltenes SQL aus.
Mit `@IncludePackageViews=1` kommen Paketübersicht, Executables, beobachtete
Datenflussscopes, Komponenten und direkte Spaltenbeziehungen hinzu. Die
Projektionen verwenden den vollständigen validierten Graphen; das Zeilenlimit
begrenzt anschließend jede Detailausgabe.

Die Modellanalyse bietet mit `@IncludeObjectRules=1` zusätzlich
objektbezogene statische Hinweise. Die [Regelreferenz](Procedures/USP_SsisPackageModelAnalysis.md#objektbezogene-regeln)
beschreibt ihre konkreten Belege und Abdeckungsgrenzen. Die Regeln
interpretieren keine neuen Komponenten und berechnen keine Lineage.

Eine [kontrollierte lokale Übergabe](Procedures/USP_SsisPackageModelAnalysis.md#kontrollierte-lokale-übergabe)
kann den tatsächlichen Producerbuild und das konkrete Modellergebnis an die
Originalpaketbytes binden. Der Betriebsweg benötigt ausdrücklich vorhandene
Metadatenänderungsrechte des Zulieferers; gewöhnliche Analysecaller benötigen
sie nicht. Ohne Übergabe-ID bleibt die Analyse eigenständig mit `UNVERIFIED`.

Der optionale [Kindpaket-/Handlerpfad](Procedures/USP_SsisPackageModelAnalysis.md#kindpaket-und-ereignishandlerkorrelation)
verknüpft feste projektlokale Aufrufe desselben gebundenen Archivs mit
beobachteten Paketinstanzen. Er trennt Paketidentitäten und Handlerbelege;
mehrdeutige Pfade und unbekannte Auslöser bleiben ausdrücklich unbewiesen.
Die sieben eigenen Ergebnisgruppen ersetzen in diesem Opt-in die bisherigen
Einzelmodellausgaben. Analyze bleibt ohne SQL CLR eigenständig nutzbar.

Die zusätzliche [Dataflow-Korrelation](Procedures/USP_SsisPackageModelAnalysis.md#optionale-dataflow-ausführungskorrelation)
ordnet Komponentenphasen und Pfadtransfers erst nach eindeutiger Bindung einer
Statistikinstanz zu. Sie erhält Einzelintervalle und Transferzähler samt
Logginggrenzen. Komponenten-, Port- und Kantenreferenzen stammen aus dem
Toolbelt; Analyze berechnet keine zusätzliche Lineage.

Die optionale [Dataflow-Diagnose](Procedures/USP_SsisPackageModelAnalysis.md#optionale-dataflow-diagnose)
fasst diese gebundenen Einzelbelege je Aufrufinstanz zusammen. Sie zeigt
Phasenkennzahlen, Pfadtransfers und versionierte Regelhinweise mit Quellenbezug.
Fehlende Beobachtungen und unbekannte Rollen bleiben als Evidenzgrenzen sichtbar.

Der [gebundene Ausführungsvergleich](Procedures/USP_SsisExecutionComparison.md) vergleicht zwei Captures desselben exakten Modellexports. Herkunft, Version, Laufzeitkontext und Coverage begrenzen die Aussage; Parser und Lineage bleiben in Toolbelt.

Die [Mehrlauf-Baseline](Procedures/USP_SsisExecutionBaseline.md) ergänzt den Paarvergleich für eine explizite Kohorte von bis zu 20 Basisläufen. Verwendbare Laufzahl, Median und Spannweite gelten je Kennzahl; Ausschlüsse bleiben einzeln nachvollziehbar.

Der [Vertrag für eigene Kennzahlenproduzenten](../Architecture/SSIS_Custom_Metrics_Producer_Contract.md) beschreibt optionale `DELTA`-, `CUMULATIVE`-, `GAUGE`- und `FINAL`-Beobachtungen sowie ihre Bindungs- und Vergleichsgrenzen. Ein begrenzter Offline-Validator prüft `ssis-reported-metrics/v1`-Berichte syntaktisch und auf deklarierte Konsistenz. Er verifiziert weder Capture- oder Producerherkunft noch Wahrheitsgehalt und bildet keine Laufwerte, Vergleiche oder Baselines.

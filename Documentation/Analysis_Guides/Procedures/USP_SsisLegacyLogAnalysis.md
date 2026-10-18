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

## Resultsets und Leserichtung

RAW liefert moduleStatus, execution, timeline, errorChain, iterations,
loggingQuality, findings, sourceStatus und warnings. Lesen Sie zunächst den
Modulstatus und die vier Quellenstatuszeilen. CONSOLE liefert eine Übersicht
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

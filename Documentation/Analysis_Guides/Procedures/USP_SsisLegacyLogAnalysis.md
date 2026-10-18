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

Die 20 Parameter und neun nativen Schemas stehen im
[freigegebenen Vertrag](../../Architecture/SSIS_001_Phase0_Public_Contract.md#konkreter-legacy-vertrag-vom-16-oktober-2026).

## Eine Zeile bedeutet

Eine Timelinezeile entspricht einer materialisierten Logzeile. errorChain
enthält die zeitliche Folge von OnError, OnTaskFailed, OnWarning und OnQueryCancel.
execution fasst ausschließlich den analysierten Puffer zusammen. iterations
enthält konservative Start-/Endpaare oder ausdrücklich ungepaarte Ereignisse.
loggingQuality beschreibt konkrete Interpretationsgrenzen dieses Ausschnitts.

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

## Leere oder partielle Ausgabe

AVAILABLE_EMPTY bedeutet keine sichtbaren Ereignisse für diese GUID; die
Ausführung ist dadurch nicht sicher abwesend. Nicht unterstützte Schemas,
native Quellenfehler und Integritätsbefunde bleiben von erfolgreichen Leermengen
getrennt. Indexmetadaten sind beratend; ihr Fehler beendet die gültige
Ereignissammlung nicht. Das erste tatsächliche native SQL-Fehlerpaar bleibt
in den Modul-OUTPUTs erhalten. SSIS-Meldungstexte werden nicht als SQL-Exception
umgedeutet. Ungültige TABLE-Mappings werfen Frameworkfehler 51011.

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

# [monitor].[USP_DatabaseCapacityAnalysis]

**Bereich:** Server Health<br>
**Zweck:** Bewertet Dateien, Volumes, freien Platz, Autogrowth, MaxSize und Wachstumsspielraum.<br>
**Beobachtungsart:** Snapshot ohne Wachstumsprognose<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Wie viel Datei-/Volumeplatz bleibt, wie sind Growth/MaxSize konfiguriert und welche Kapazitätsrisiken sind sichtbar?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DatabaseCapacityAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Für vollständige Volumenevidenz ist auf SQL Server 2019 `VIEW SERVER STATE`, ab SQL Server 2022 `VIEW SERVER PERFORMANCE STATE` erforderlich. Fehlt dieses Recht, bleibt zulässige Dateievidenz sichtbar, der Status lautet jedoch ausdrücklich `AVAILABLE_LIMITED` mit `IsPartial=1`.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Eingabe ist eine bracket-aware Pipe-Liste einteiliger Datenbanknamen: &#124; trennt außerhalb von [...], ]] maskiert ] innen. Äußere Leerzeichen je Element werden entfernt; Rohsegment höchstens 4000 UTF-16-Codeeinheiten, Name höchstens 128 Zeichen. Leere/fehlerhaft geklammerte Elemente, mehrteilige Namen und case-sensitive Duplikate desselben Filtertyps sind ungültig. NULL, leer oder nur Leerzeichen bedeutet keine Namensbegrenzung; ausgelassen entspricht NULL. Nicht mit einem nichtleeren Pattern kombinierbar. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | Bit-Schalter: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL ist ungültig; ausgelassen = 0. Nach bit-Konvertierung bleibt numerisch 0 aus, ein konvertierbarer Nichtnullwert wird 1. Verändert Kandidatenauswahl und systemdatenbankbezogene Warnungen. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Ein Pattern (nvarchar(4000)); NULL/ausgelassen bedeutet kein Pattern; leer oder nach LTRIM/RTRIM von U+0020-Leerzeichen leer ist ungültig. Andere Whitespacezeichen wie Tabulatoren werden nicht allgemein normalisiert. Äußere U+0020-Leerzeichen werden getrimmt. Unterstützte Modi: LIKE (ohne Präfix oder like:), regex: (case-sensitive, Flag c), regexi: (case-insensitive, Flag i); Präfixerkennung ignoriert Groß-/Kleinschreibung. Der Inhalt nach Präfixentfernung wird nicht erneut getrimmt. LIKE nutzt %, _ und [...] unter SQL_Latin1_General_CP1_CS_AS. Regexsyntax/Treffer werden durch Präfixprüfung nicht validiert. Regexausführung erfordert SQL Server 2025 sowie Compatibility Level mindestens 170 der Installationsdatenbank; sonst wird der Kandidatenpfad mit UNAVAILABLE_FEATURE beendet. Ein nicht-NULL Pattern und eine wirksame Namensliste schließen einander aus. Das Pattern begrenzt Kandidaten, setzt aber keine Mengenobergrenze. |
| `@HighImpactConfirmed` | `bit` | `0` | Bit-Bestätigung der fest verdrahteten Analyseklasse SERVER_HEALTH_CURRENT; 0 = nicht bestätigt, 1 = bestätigt. NULL ungültig; ausgelassen = 0. Numerische Werte werden als bit konvertiert: 0 bleibt 0, konvertierbarer Nichtnullwert wird 1. Die Bestätigung selbst erteilt weder Gruppenmitgliedschaft noch Berechtigung; der Helper prüft zusätzlich die aktivierte Klassen-/Gruppenpolicy. |
| `@MinVolumeFreePercent` | `decimal(9,2)` | `10.00` | decimal(9,2) Prozent-Schwelle, gültig 0 bis 100; ausgelassen = 10.00. NULL passiert die Rangeprüfungen, ergibt beim Vergleich UNKNOWN. LOW_VOLUME_FREE_PERCENT entsteht nur bei bekannter Volume-Gesamtgröße &gt; 0 und wenn freier Prozentanteil &lt; Schwelle ist; Gleichheit löst keinen Befund aus. Übergabe an dynamisches SQL als decimal(9,2). |
| `@NurProblematisch` | `bit` | `0` | Bit-Schalter: 0 behält auch NO_CAPACITY_INDICATOR; 1 entfernt NULL-FindingCode und NO_CAPACITY_INDICATOR. NULL erfüllt ebenfalls die IF-Bedingung und löst denselben DELETE-Pfad aus. Die anschließenden WHERE-Vergleiche mit NULL sind UNKNOWN; nach dem DELETE verbleiben reguläre Findingzeilen. Ausgelassen = 0; numerische Nichtnullwerte werden nach bit-Konvertierung 1. Filter erfolgt nach Aggregation und Status, begrenzt keine Scans. |
| `@MaxZeilen` | `int` | `1000` | Ganzzahlig; negative Werte ungültig, NULL/0 unbegrenzt, ausgelassen = 1000. Nach der Datei-Bewertung Findings zuerst, dann VolumeFreePercent, DatabaseName, FileId, DatabaseId. Dieselbe gefilterte und begrenzte Menge gilt für RAW, CONSOLE, TABLE und JSON. Begrenzt nicht Kandidaten, FILEPROPERTY-/Volumeabfragen, Quellenarbeit oder Laufzeit. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach Bindung an varchar(16), Trim von U+0020-Leerzeichen und UPPER gelten RAW, CONSOLE, TABLE und NONE. NULL, leer und andere Texte sind INVALID_PARAMETER; ausgelassen = CONSOLE. RAW liefert Status und die technischen Fachresultsets. CONSOLE liefert nur die lesbare capacity-Fachmenge über den Console-Helfer, ohne separates Statusresultset; TABLE schreibt nur diese benannte Fachmenge in das Ziel. NONE unterdrückt normale Resultsets. TABLE-Zielvorprüfung oder Ablehnung eines nicht leeren Mappings außerhalb TABLE laufen vor @Hilfe=1 und können werfen. Hilfe kehrt danach vor der Analyse und JSON-Erzeugung zurück; angefordertes JSON im normalen Pfad ist unabhängig vom Ausgabemodus. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Für TABLE ist ein JSON-Objekt mit genau dem Schlüssel capacity erforderlich; der Wert muss ein String mit dem Namen einer vorhandenen lokalen #Temp-Tabelle sein, etwa N'{"capacity":"#DatabaseCapacityAnalysis_HelpExample"}'. Das Ziel muss leer sein und genau eine beliebig typisierte Seed-Spalte besitzen; beim TABLE-Schreiben richtet der Ausgabehelfer daraus die Zielspalten ein. NULL oder nach Trim von U+0020 leere Eingabe ist in TABLE ungültig. Außerhalb TABLE sind nur NULL oder nach diesem Trim leere Werte zulässig; andere Werte werfen 51011. Diese Prüfung läuft auch bei TABLE zusammen mit @Hilfe=1 vor der Hilfe-Rückkehr. Ausgelassen = NULL. |
| `@JsonErzeugen` | `bit` | `0` | Bit-Schalter 0 = kein JSON, 1 = JSON erzeugen; NULL wirkt wegen IF wie aus; ausgelassen = 0. Zahlen folgen bit-Konvertierung (0 bleibt 0, konvertierbarer Nichtnullwert wird 1). JSON ist unabhängig vom ResultSetArt-Modus. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionales nvarchar(max)-OUTPUT. Beim Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 enthält es meta, capacity und warnings, sonst bleibt es NULL. Als Variable mit OUTPUT binden; Eingabewert bleibt nicht erhalten. |
| `@PrintMeldungen` | `bit` | `1` | Bit-Schalter für Severity-10-RAISERROR mit NOWAIT bei globalem Status ungleich AVAILABLE: 1 aktiviert, 0 unterdrückt; NULL wirkt wie aus; ausgelassen = 1. Kandidatenwarnungen sind davon getrennte Resultate. |
| `@Hilfe` | `bit` | `0` | Bit-Schalter: 1 druckt Hilfe und kehrt vor Analyse-Resultaten zurück, 0 führt Analyse aus; NULL wirkt wie aus; ausgelassen = 0. OUTPUT-Ziele, die erst am normalen Ende gesetzt werden, bleiben im HELP-Pfad unverändert. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionales varchar(40)-OUTPUT. Im normalen Pfad wird am Ende gesetzt; vor dieser Zuweisung initialisiert die Procedure das Outputziel nicht, und HELP kehrt vorher zurück, sodass ein gebundener vorhandener Variablenwert erhalten bleibt. Globale Werte: AVAILABLE = kein gesetzter Finding- oder Teilstatus; AVAILABLE_WITH_FINDING = mindestens ein Finding ohne Teilstatus; AVAILABLE_LIMITED = Teilquelle oder Kandidatenwarnung begrenzt die Vollständigkeit; INVALID_PARAMETER = ungültige Eingabe; DENIED_GROUP = Analyseklasse laut aktueller Policy nicht freigegeben; DENIED_PERMISSION = erforderliche Abfrage verweigert; ERROR_HANDLED = sonstiger behandelter Analysefehler; INTERNAL_ERROR = interner Kandidatenvorbereitungsfehler; UNAVAILABLE_FEATURE = Regexmodus auf nicht unterstützter Engine-/Installationsdatenbank-Kompatibilität. Beide fest verdrahteten Klassen haben RequiresGroupGate=0, daher verlangen sie keine High-Impact-Bestätigung. Per-Datenbank-Warnungen wie SYSTEM_DATABASE_EXCLUDED (Systemdatenbank aus Scope ausgelassen) und DATABASE_UNAVAILABLE (Kandidat nicht verfügbar) sind Warnungszeilen, keine globalen Codes; Kapazitätsabfragefehler werden ebenfalls dort je Datenbank erfasst. Teilstatus wird zusätzlich über @IsPartialOut signalisiert. Als Variable mit OUTPUT-Bindung übergeben; ausgelassen wird kein Wert zurückgegeben. Optionaler Empfang mit @StatusCodeOut=@Empfaenger OUTPUT; die Variable muss varchar(40) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionales bit-OUTPUT zur Teilvollständigkeit (0 vollständig, 1 Teilquelle/Berechtigungs-/Warnungseinschränkung). HELP erreicht die normale Zuweisung nicht und lässt den bisherigen Variablenwert unverändert. Als Variable mit OUTPUT binden. Optionaler Empfang mit @IsPartialOut=@Empfaenger OUTPUT; die Variable muss bit sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionales int-OUTPUT für die gespeicherte SQL-Fehlernummer; NULL, wenn keine gespeichert wurde. HELP weist nicht zu. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorNumberOut=@Empfaenger OUTPUT; die Variable muss int sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionales nvarchar(2048)-OUTPUT für gespeicherten Fehler-/Teilhinweis; ohne Hinweis NULL. HELP weist nicht zu. Kandidatenwarnungen bleiben separat. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorMessageOut=@Empfaenger OUTPUT; die Variable muss nvarchar(2048) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung. |

```sql
DECLARE @CapacityJson nvarchar(max)=NULL;
EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW';

EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW', @JsonErzeugen=1, @Json=@CapacityJson OUTPUT;
SELECT @CapacityJson AS [DatabaseCapacityAnalysisJson];

CREATE TABLE [#DatabaseCapacityAnalysis_HelpExample] ([Seed] bit NULL);
DECLARE @Tables nvarchar(max)=N'{"capacity":"#DatabaseCapacityAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=@Tables;
    DROP TABLE [#DatabaseCapacityAnalysis_HelpExample];
END TRY
BEGIN CATCH
    IF OBJECT_ID('tempdb..#DatabaseCapacityAnalysis_HelpExample') IS NOT NULL DROP TABLE [#DatabaseCapacityAnalysis_HelpExample];
    THROW;
END CATCH;

EXEC [monitor].[USP_DatabaseCapacityAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `capacity`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Die 17 Textspalten der lokalen Kandidaten-, Warnungs- und Kapazitätstabellen
verwenden explizit `SQL_Latin1_General_CP1_CS_AS`. Die neun Textspalten des
Kapazitäts-TABLE-Exports behalten diese Frameworkcollation auch bei einer
abweichenden Server- oder `tempdb`-Collation. Nach Quellenaggregation und
Statusermittlung wird die gemeinsame Ausgabemenge nach `@NurProblematisch`
gefiltert und nach `@MaxZeilen` begrenzt. RAW, CONSOLE, TABLE und JSON verwenden
dieselbe Menge; ein positives Limit reduziert weder Quellenarbeit noch
Statusumfang. `NULL` und `0` bedeuten für `@MaxZeilen` unbegrenzte Ausgabe.

## Eine Zeile bedeutet

Eine Kapazitätszeile entspricht einer Datei in einer ausgewählten Datenbank.
Volumeinformationen werden für jede zugehörige Datei wiederholt. Freiraum und
Gesamtgröße eines mehrfach vorkommenden Volumes dürfen deshalb nicht über
Dateizeilen summiert werden.

## So lesen

Berücksichtigen Sie Dateigröße, belegt/frei, Volume Free, Growthsetting, MaxSize und absoluten Wachstumsspielraum gemeinsam.

## Warum kann das problematisch sein?

Wenig freier Raum plus kleine häufige Autogrowths kann Pausen erzeugen; MaxSize oder volles Volume kann Wachstum vollständig verhindern.

## Wann ist es kein Problem?

Niedriger Prozentwert bei sehr großem Volume kann absolut ausreichend sein; hoher Prozentwert auf kleinem Volume nicht.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 5 % von 20 TB = 1 TB; 20 % von 10 GB = 2 GB. Berücksichtigen Sie Prozent und absolute Menge gemeinsam. Prüfen Sie Wachstumstrend, Log-/Backupstatus und Storage.

**Ähnlich aussehender Gegenfall:** Niedriger Prozentwert bei sehr großem Volume kann absolut ausreichend sein; hoher Prozentwert auf kleinem Volume nicht. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_DatabaseCapacityAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Alle sichtbaren, online befindlichen Benutzerdatenbanken; pro Datei werden Kataloggröße, `FILEPROPERTY(...,'SpaceUsed')`, Volume-Freiraum und der nächste Autogrowth-Schritt als Snapshot bewertet. Exakte Namen und Pattern schränken den Scope ein. |
| Teuerster Pfad | Alle sichtbaren Datenbanken, unbegrenzte Ausgabe und viele Daten-/Logdateien auf zahlreichen Volumes. Es gibt keinen History-, Growth- oder Benutzerdatenscan. |
| Haupttreiber | Zahl gewählter Datenbanken und ihrer Daten-/Logdateien; für jede Datei werden Kataloggröße, belegte Seiten und Volumeinformationen korreliert. Dateigröße verändert die Werte, nicht proportional die Metadatenarbeit. |
| Skalierung | Aufwand wächst ungefähr mit Datenbanken und Dateien. Volumeabfragen können je Datei wiederholt werden; Sortierung und Resultat bleiben im Verhältnis zur Dateimenge klein. |
| Ressourcen | Katalog-/Dateimetadaten-I/O, CPU für dynamische Datenbankabfragen und `sys.dm_os_volume_stats`; kleine temporäre Ergebnistabelle. Keine msdb- oder Memory-Clerk-Abfrage. |
| Begrenzungswirkung | Datenbankliste/-pattern begrenzen den Cursor früh. `@NurProblematisch` und `@MaxZeilen` wirken erst auf die vollständig erzeugten Dateibewertungen und begrenzen `FILEPROPERTY`-/Volumezugriffe nicht. |
| Locking und Nebenwirkungen | Read-only; kurze Metadatenzugriffe und nicht atomare Runtime-DMVs. Es wird weder CHECKDB noch Growth noch Konfigurationsänderung ausgeführt. |
| Schutzmechanismus | `SERVER_HEALTH_CURRENT` muss freigegeben sein, verlangt laut Klassenkatalog keine High-Impact-Bestätigung. Wirksamer Schutz ist eine einzelne Datenbank; `@HighImpactConfirmed` öffnet keinen weiteren Pfad. |
| Sicherer Einsatz | Eine `ExampleDatabase`, Problemscope und endliches Limit; erst nach Sichtung von Dateianzahl und Laufzeit weitere Datenbanken aufnehmen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot ohne Wachstumsprognose“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie viel Datei-/Volumeplatz bleibt, wie sind Growth/MaxSize konfiguriert und welche Kapazitätsrisiken sind sichtbar?

### Technischer Hintergrund

Database Files wachsen innerhalb Volume-/MaxSizegrenzen. Percent Growth erzeugt mit wachsender Datei zunehmend große Schritte; kleine Growthsteps erzeugen häufige Growth Events. Loggrowth/Zero Initialization und Datafile IFI unterscheiden sich.

### Datenkette

`sys.database_files`, `sys.dm_os_volume_stats`, `sys.sp_executesql`.

### Source Select

Im Kontext einer bereits ausgewählten Datenbank werden Dateikatalog und Volume-Information verbunden:

```sql
SELECT
      DB_NAME() AS [DatabaseName]
    , [f].[file_id]
    , [f].[name] AS [LogicalFileName]
    , [f].[type_desc]
    , [f].[size] * 8.0 / 1024.0 AS [SizeMb]
    , [v].[volume_mount_point]
    , [v].[available_bytes]
FROM [sys].[database_files] AS [f] WITH (NOLOCK)
OUTER APPLY [sys].[dm_os_volume_stats](DB_ID(), [f].[file_id]) AS [v]
WHERE [f].[state] = 0;
```

**Wichtig für die Eigenlast:** Begrenzen Sie zuerst die Datenbankkandidaten. `dm_os_volume_stats` nur für deren Dateien aufrufen; `@MaxZeilen` reduziert sonst gegebenenfalls nur die spätere Ausgabe, nicht die Zahl der Volume-Auflösungen.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Snapshot. Ohne historische Messpunkte lässt sich weder eine Wachstumsrate noch eine Prognose ableiten.

### Bewertung und Gegenprobe

Berücksichtigen Sie absolute freie MB und Prozent, Dateigröße, Growthtyp und -schritt, MaxSize, Volume Free, Dateityp und geplante Workloadspitzen gemeinsam. Autogrowth dient als Sicherheitsnetz; die Kapazität sollte proaktiv geplant werden.

### Typische Fehlinterpretation

Viel freier Platz im File bedeutet nicht freien Volumeplatz; viel Volumeplatz bedeutet nicht passende MaxSize/Growth. Forecast aus einem Snapshot ist Heuristik.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Current Log/IO, Backup-/Loadplanung und externes Capacitytrendmonitoring.

## Primärquellen

- [sys.dm_os_volume_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-volume-stats-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#12-monitorusp_databasecapacityanalysis)

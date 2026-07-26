# [monitor].[USP_FrameworkUsageFromQueryStore]

**Bereich:** Versionsadaptive Spezialanalysen
**Zweck:** Aggregiert die sichtbare Nutzung installierter `monitor`-Procedures aus dem Query Store der Frameworkdatenbank.
**Beobachtungsart:** begrenzter Query-Store-Katalogsnapshot
**Kostenklasse:** LOW_TO_MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Frage: **Welche Framework-Procedures wurden im sichtbaren Query-Store-Zeitraum ausgeführt, wie häufig und mit welcher aggregierten Last?**

Sie eignet sich für Nutzungsinventur, Schulungs- und Dokumentationspriorisierung sowie eine erste Eigenlastprüfung des Frameworks. Sie erzeugt keine eigene Historie und ändert keine Query-Store-Einstellung.

## Voraussetzungen

- SQL Server 2019 oder neuer.
- Query Store ist in der Frameworkdatenbank lesbar aktiv.
- Der Aufrufer besitzt ausreichende Metadatensichtbarkeit für die Query-Store-Systemviews.
- Retention, Capture Mode, Cleanup und Flushzeitpunkt bestimmen, welche Ausführungen sichtbar sind.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_FrameworkUsageFromQueryStore];
```

Der Standardaufruf liefert höchstens 100 Procedures mit mindestens einer sichtbaren Ausführung.

## Parameter

| Parameter | Typ | Default | Bedeutung |
|---|---|---|---|
| `@MaxZeilen` | int | 100 | Positive Werte begrenzen. `NULL` oder `0` bedeutet unbegrenzt. Negativ ist ungültig. |
| `@MinAusfuehrungen` | bigint | 1 | Mindestanzahl sichtbarer Ausführungen je Procedure. Muss mindestens 1 sein. |
| `@ZeitraumTage` | int | NULL | `NULL` oder `0` verwendet den gesamten sichtbaren Query-Store-Zeitraum. |
| `@LockTimeoutMs` | int | 0 | Lokaler Lock-Timeout für die Katalogzugriffe; 0 bis 60000. Der ursprüngliche Wert wird wiederhergestellt. |
| `@ResultSetArt` | varchar(16) | CONSOLE | `CONSOLE`, `RAW`, `TABLE` oder `NONE`. |
| `@ResultTablesJson` | nvarchar(max) | NULL | Benannte TABLE-Ziele: `moduleStatus`, `usage`, `sourceStatus`, `warnings`. |
| `@JsonErzeugen` | bit | 0 | Erzeugt bei 1 das versionierte JSON-Dokument. |
| `@Json` | nvarchar(max) OUTPUT | NULL | JSON-Ausgabe mit `meta`, `usage`, `sourceStatus` und `warnings`. |
| `@PrintMeldungen` | bit | 1 | Gibt kontrollierte Statusmeldungen mit Severity 10 aus. |
| `@Hilfe` | bit | 0 | Gibt die Hilfe aus und beendet den fachlichen Pfad. |
| `@StatusCodeOut` | varchar(40) OUTPUT | NULL | Gesamtstatus. |
| `@IsPartialOut` | bit OUTPUT | NULL | Kennzeichnet unvollständige Fehler- oder Berechtigungspfade. |
| `@ErrorNumberOut` | int OUTPUT | NULL | Kontrolliert abgefangene Fehlernummer. |
| `@ErrorMessageOut` | nvarchar(2048) OUTPUT | NULL | Kontrolliert abgefangene Fehlermeldung. |

## Resultsets

### `moduleStatus`

Enthält Erfassungszeit, Query-Store-Zustand, Zeitraum, Mindestanzahl, Zeilenanzahl, `HasMoreRows` sowie den Gesamtstatus.

### `usage`

| Spalte | Bedeutung |
|---|---|
| `ProcedureName` | Sichtbare Procedure im Schema `monitor`. |
| `ExecutionCount` | Summe der Query-Store-Ausführungsanzahlen aller erfassten Statements der Procedure. |
| `LastExecutionTime` | Letzter sichtbarer Ausführungszeitpunkt. |
| `AvgDurationMs` | Nach `count_executions` gewichtete durchschnittliche Dauer in Millisekunden. |
| `AvgCpuMs` | Nach `count_executions` gewichtete durchschnittliche CPU-Zeit in Millisekunden. |
| `AvgLogicalReads` | Gewichtete durchschnittliche logische Reads. |
| `AvgMemoryGrantKB` | Gewichteter durchschnittlicher maximal verwendeter Query-Speicher in KB. |
| `PlanCount` | Anzahl unterschiedlicher sichtbarer Query-Store-Pläne. |
| `QueryCount` | Anzahl unterschiedlicher sichtbarer Query-Store-Queries. |
| `FirstSeen` / `LastSeen` | Sichtbare zeitliche Evidenzgrenze. |

### `sourceStatus`

Trennt die Zustandsprüfung des Query Store von der eigentlichen Laufzeitaggregation. Ein fehlgeschlagener Quellenpfad wird nicht als leere Nutzung ausgegeben.

### `warnings`

Enthält kontrollierte Berechtigungs-, Feature- und Lesefehler. Freie Query-Texte und Benutzeridentitäten werden nicht gelesen.

## Leserichtung

1. Zuerst `moduleStatus.StatusCode` und `QueryStoreActualStateDesc` prüfen.
2. `HasMoreRows=1` bedeutet ausschließlich, dass `@MaxZeilen` die Projektion begrenzt hat.
3. `ExecutionCount` ist eine Statement-Aggregation je Procedure und keine Anzahl äußerer `EXEC`-Aufrufe.
4. Dauer, CPU, Reads und Speicher sind gewichtete Query-Store-Intervallaggregate und keine einzelnen Laufzeitmessungen.
5. Mehrere Pläne sind ein Prüfhinweis, aber kein automatischer Nachweis für Parameter-Sensitivität oder Regression.

## Aussagegrenzen und Fehlinterpretationen

- Eine fehlende Procedure beweist nicht, dass sie nie ausgeführt wurde. Capture Mode, Retention, Cleanup, Query-Store-Reset und Metadatensichtbarkeit können Evidenz entfernen oder verhindern.
- Query Store liefert keine Benutzerattribution und keinen verlässlichen Erfolgs- oder Fehlerstatus des äußeren Procedure-Aufrufs.
- Hohe Nutzung oder hohe Durchschnittswerte sind keine automatische Fehlerklassifikation.
- `READ_ONLY` kann weiterhin lesbare Historie liefern; es sagt nichts über die Vollständigkeit zukünftiger Erfassung aus.
- Die Procedure führt kein Flush, Cleanup, `ALTER DATABASE` oder sonstige Schreiboperation aus.

## Beispielaufrufe

```sql
EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @ZeitraumTage=30
    , @MaxZeilen=10;

EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @MaxZeilen=0
    , @ResultSetArt='RAW';

DECLARE @UsageJson nvarchar(max);
EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @ZeitraumTage=7
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@UsageJson OUTPUT;
SELECT @UsageJson;

CREATE TABLE #ModuleStatus([Seed] bit NULL);
CREATE TABLE #Usage([Seed] bit NULL);
CREATE TABLE #SourceStatus([Seed] bit NULL);
CREATE TABLE #Warnings([Seed] bit NULL);

EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @ResultSetArt='TABLE'
    , @ResultTablesJson=N'{
        "moduleStatus":"#ModuleStatus",
        "usage":"#Usage",
        "sourceStatus":"#SourceStatus",
        "warnings":"#Warnings"
      }';
```

## Nächste Gegenprüfungen

- `USP_QueryStoreStatus` für Zustand, Größe, Retention und Capture Mode.
- `USP_QueryStoreAnalysis` für detaillierte Query-Store-Evidenz.
- `USP_ServerVersionInformation` für Versions- und Buildkontext.
- `USP_CheckFrameworkCapabilities` für Berechtigungs- und Capability-Grenzen.

## Weiterführend

- [Query Store](../05_Query_Store.md)
- [Scope und Grenzen](../../Reference/Scope_and_Limitations.md)
- [TABLE-Ausgabevertrag](../../Architecture/Database_Console_Table_Contract.md)

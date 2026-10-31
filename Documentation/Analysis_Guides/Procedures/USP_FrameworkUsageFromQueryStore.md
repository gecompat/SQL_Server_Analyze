# [monitor].[USP_FrameworkUsageFromQueryStore]

**Bereich:** Query Store<br>
**Zweck:** Aggregiert die sichtbare Nutzung installierter `monitor`-Procedures aus dem Query Store der Frameworkdatenbank.<br>
**Beobachtungsart:** begrenzter persistierter Laufzeitsnapshot<br>
**Kostenklasse:** LOW_MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Framework-Procedures wurden im sichtbaren Query-Store-Zeitraum ausgeführt, wie häufig und mit welcher aggregierten Last?** Sie unterstützt Nutzungsinventur, Schulungs- und Dokumentationspriorisierung sowie eine erste Eigenlastbewertung des Frameworks.

## Nicht beantwortete Fragen

Die Procedure zeigt weder den aufrufenden Benutzer noch den Erfolg des äußeren Procedure-Aufrufs. Sie beweist nicht, dass eine fehlende Procedure nie ausgeführt wurde. Capture Mode, Retention, Cleanup, Query-Store-Reset, Read-only-Zustand und Metadatensichtbarkeit können Evidenz begrenzen oder entfernen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Der Standardpfad liest keine Query-Texte, Pläne als XML oder Benutzeridentitäten und ändert keine Query-Store-Einstellung.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@MaxZeilen` | `int` | `100` | NULL oder 0 bedeutet unbegrenzt; positive Werte begrenzen nur usage nach Aggregation und Mindestfilter. Negative Werte sind ungültig. HasMoreRows nutzt einen zusätzlichen Kandidaten mit BIGINT-Arithmetik, auch bei int.MaxValue; ReturnedRowCount ist die endgültige usage-Anzahl. Der frameworkUsage-Eintrag im sourceStatus meldet ebenfalls nur die endgültige ausgegebene Anzahl, nicht die vollständige Kandidatenmenge. Als positive ganze Zahl von 1 bis 2147483647 übergeben. Sortierung nach ExecutionCount absteigend, danach ProcedureName aufsteigend. Status- und Warningmengen werden nicht begrenzt; ein Limit allein setzt IsPartial nicht. |
| `@MinAusfuehrungen` | `bigint` | `1` | Mindestens 1; NULL und kleinere Werte sind ungültig. Filtert nach Aggregation je Procedure anhand der Summe erfasster Statementausführungen, nicht äußerer EXEC-Aufrufe. Als ganze bigint-Zahl von 1 bis 9223372036854775807 übergeben. |
| `@ZeitraumTage` | `int` | `NULL` | NULL oder 0 bedeutet gesamte sichtbare Retention; 1 bis 365000 ist zulässig. Negative Werte und größere Werte sind ungültig. Positiv berechnet CutoffUtc aus SYSUTCDATETIME() und verwendet last_execution_time &gt;= CutoffUtc; die vollständige Runtime-Stats-Zeile zählt, keine anteilige Intervallüberlappung. Ganze Tage übergeben. NULL und 0 erscheinen in der Fenstermetadatenangabe als NULL; die Procedure setzt weder Retention noch Query-Store-Capture um. |
| `@LockTimeoutMs` | `int` | `0` | 0 bis 60000 zulässig; NULL und Werte außerhalb ungültig. 0 bedeutet kein Warten auf gesperrte Ressourcen. Setzt ein SQL-Lock-Timeout, kein Ausführungszeitbudget; im regulären Finalize-Pfad wird der vorherige @@LOCK_TIMEOUT wiederhergestellt. Positive ganze Millisekunden von 1 bis 60000 übergeben; eine allgemeine Wiederherstellungszusage bei ungefangenen Fehlern folgt daraus nicht. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Trimmen und Großschreibung. Geschlossene Werte: CONSOLE liefert nur usage mit Ergebnislabel oder Leeranzeige; RAW liefert moduleStatus, usage, sourceStatus, warnings; TABLE schreibt eine nichtleere Teilmenge der vier erlaubten Gruppen in lokale Ziele; NONE unterdrückt fachliche Resultsets. NULL, leerer Text und andere Werte sind ungültig. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen; ein solcher Leerwert ist ungültig. Die SQL-Bindung an varchar(16) erfolgt vor der Prüfung. JSON und technische Meldungen werden unabhängig gesteuert. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Ausgelassen/NULL, leer oder nur äußere U+0020-Leerzeichen sind außerhalb TABLE zulässig; anderer nichtleerer Inhalt liefert dort im normalen Ablauf INVALID_PARAMETER, keinen frühen Mapping-THROW. Bei TABLE ist ein nichtleeres JSON-Objekt mit einer nichtleeren Teilmenge von vier binär exakten Schlüsseln erforderlich: moduleStatus (Gesamtstatus und Zähler), usage (Nutzungsaggregate), sourceStatus (Quellenstatus), warnings (Warnungen). Jeder Stringwert benennt ein eigenes vorhandenes, leeres lokales #Temp-Ziel mit genau einer beliebigen Seed-Spalte und keiner Seed-Zeile; kein ##, LEN höchstens 116 und kein reserviertes #Monitor-Präfix. Unbekannte/doppelte Schlüssel, case-insensitiv doppelte Ziele, Nicht-Stringwerte oder ungültige Ziele scheitern im ThrowOnError-Preflight nach Hilfe, aber vor normaler Fachvalidierung. Der Writer ersetzt die Seed-Struktur; nicht angeforderte Ziele werden nicht verändert. |
| `@JsonErzeugen` | `bit` | `0` | NULL ungültig. 0 erzeugt kein JSON; 1 erzeugt meta, usage, sourceStatus und warnings, kein moduleStatus-Array. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. JSON ist unabhängig von ResultSetArt. meta beschreibt Gesamtstatus/Zähler, usage die begrenzte Nutzungsmenge, sourceStatus die Quellenlage und warnings Warnungen. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT wird am Aufrufanfang auf NULL gesetzt, auch bei HELP. Bei normaler Ausführung wird es nur mit @JsonErzeugen=1 als JSON-Objekt gesetzt. Zum Empfang eine nvarchar(max)-Variable als Json=@Variable OUTPUT binden; der Eingabewert wird verworfen. Ohne OUTPUT-Bindung gibt es keinen übernommenen Wert; ungefangene Fehler garantieren keine OUTPUT-Rückübertragung. |
| `@PrintMeldungen` | `bit` | `1` | NULL ungültig. 0 ist still; 1 gibt nur bei Status außerhalb AVAILABLE und AVAILABLE_EMPTY eine Meldung mit Schweregrad 10 aus. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@Hilfe` | `bit` | `0` | Nur 1 aktiviert HELP. HELP beendet nach Hilfetexten vor TABLE-Preflight und regulärer Parameterprüfung; @Json ist bereits NULL, die vier Status-/Fehler-OUTPUT-Parameter bleiben unverändert. NULL aktiviert HELP nicht und wird nicht separat geprüft. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | OUTPUT des abschließenden Modulstatus, kein Eingabefilter. Eine varchar(40)-Variable mit OUTPUT binden. Vollständige aktuelle Statusmenge: AVAILABLE (ausgabefähige Nutzung), AVAILABLE_EMPTY (lesbarer Query Store ohne Treffer nach Filtern), INVALID_PARAMETER (ungültiger Aufruf), UNAVAILABLE_FEATURE (Query Store nicht lesbar aktiv), DENIED_PERMISSION (kontrollierter Berechtigungsfehler) und ERROR_HANDLED (anderer kontrollierter Quellenfehler, auch Locktimeout 1222). Bei Hilfe bleibt der Eingabewert unverändert; im normalen Ablauf wird erst nach Resultset-/TABLE-/Meldungsausgabe zugewiesen. Bei ungefangenem THROW keine zugesicherte Rückübertragung. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | OUTPUT der abschließenden Partialität; eine bit-Variable mit OUTPUT binden, kein Eingabeschalter. 1 steht bei ungültigen Parametern und kontrolliertem Quellenfehler; 0 bei regulären Nutzungsdaten, leerem Ergebnis und UNAVAILABLE_FEATURE. Das Zeilenlimit allein setzt das Bit nicht. Bei Hilfe bleibt der Eingabewert einschließlich NULL unverändert. Normale Zuweisung erst am Ende nach der Ausgabe; bei ungefangenem THROW keine zugesicherte Rückübertragung. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | OUTPUT der Modulfehlernummer; eine int-Variable mit OUTPUT binden, kein Eingabefilter. Im normalen Ablauf enthält sie bei kontrolliertem Quellenfehler ERROR_NUMBER(), sonst NULL; ein Validierungs- oder Featurestatus benötigt keine technische Fehlernummer. Bei Hilfe bleibt der Eingabewert unverändert. Zuweisung erst am Ende nach der Ausgabe; bei ungefangenem THROW keine zugesicherte Rückübertragung. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | OUTPUT des Modulfehlertexts; eine nvarchar(2048)-Variable mit OUTPUT binden, kein Eingabefilter. Im normalen Ablauf NULL ohne Modulfehler; sonst gesetzte Validierungs-/Featuremeldung oder Meldung des kontrollierten Quellenfehlers, nötigenfalls erste Warning nach WarningOrdinal. Bei Hilfe bleibt der Eingabewert unverändert. Zuweisung erst am Ende nach der Ausgabe; bei ungefangenem THROW keine zugesicherte Rückübertragung. |

```sql
EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @Hilfe = 1;
```

```sql
EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @MaxZeilen = 100,
      @MinAusfuehrungen = 1,
      @ResultSetArt = 'RAW';
```

```sql
DECLARE @FrameworkUsageHelpJson nvarchar(max);
EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @ResultSetArt = 'NONE',
      @JsonErzeugen = 1,
      @Json = @FrameworkUsageHelpJson OUTPUT;
SELECT @FrameworkUsageHelpJson AS [Json];
```

```sql
CREATE TABLE [#FrameworkUsageFromQueryStore_HelpExample]
(
    [Seed] int NULL
);
BEGIN TRY
    EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
          @ResultSetArt = 'TABLE',
          @ResultTablesJson = N'{"usage":"#FrameworkUsageFromQueryStore_HelpExample"}';
    SELECT * FROM [#FrameworkUsageFromQueryStore_HelpExample];
    DROP TABLE [#FrameworkUsageFromQueryStore_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#FrameworkUsageFromQueryStore_HelpExample];
    THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der technische Vertrag besteht aus `moduleStatus`, `usage`, `sourceStatus` und `warnings`. Zuerst sind Status und Quellenlage zu prüfen. CONSOLE zeigt nur das fachliche `usage`-Resultset; RAW gibt alle vier Resultsets aus. TABLE schreibt ausschließlich benannte lokale `#Temp`-Ziele. NONE unterdrückt fachliche Resultsets, kann aber JSON und OUTPUT-Parameter liefern.

Die vier TABLE-Schemas besitzen unverändert 12/11/11/5 Felder. Ihre 14 Textfelder verwenden explizit `SQL_Latin1_General_CP1_CS_AS`; auch die lokalen Zwischenmengen sind explizit collatiert. Nach dem HELP-Zweig prüft TABLE eine nichtleere Zuordnung vor der regulären Parameterprüfung; außerhalb von TABLE führt eine nichtleere Zuordnung zu INVALID_PARAMETER. Ungültige Fachparameter liefern daher die vollständigen Schemas mit `INVALID_PARAMETER`, einer Modulstatus- und einer Parameterquellenzeile sowie leeren Nutzungs- und Warningmengen. Ungültige Zuordnungen werden durch den bestehenden TABLE-Preflight abgelehnt.

## Eine Zeile bedeutet

Eine `usage`-Zeile entspricht einer sichtbaren Procedure im Schema `monitor`. Die Werte aggregieren alle sichtbaren Query-Store-Queries und Pläne, deren `object_id` auf diese Procedure verweist. Eine Zeile ist daher keine einzelne Ausführung und keine einzelne Query-Store-Query.

## So lesen

1. Prüfen Sie `moduleStatus.StatusCode`, `QueryStoreActualStateDesc` und `IsPartial`.
2. Prüfen Sie `sourceStatus`, bevor ein leeres `usage`-Resultset interpretiert wird.
3. `ExecutionCount` ist die Summe der erfassten Statementausführungen je Procedure.
4. Dauer, CPU, Reads und Speicher sind nach `count_executions` gewichtete Query-Store-Intervallaggregate.
5. `HasMoreRows = 1` bedeutet ausschließlich, dass `@MaxZeilen` die Projektion begrenzt hat. `NULL` und 0 lassen die Menge unbegrenzt; ein zusätzlicher interner Kandidat erkennt die Trunkierung. TABLE, RAW, CONSOLE und JSON verwenden dieselbe materialisierte Nutzungsmenge.
6. Mehrere Pläne oder Queries sind ein Vertiefungshinweis, aber keine automatische Regression oder Parameter-Sensitivität.

## Warum kann das problematisch sein?

Eine häufig genutzte Procedure mit dauerhaft hoher CPU-, I/O- oder Laufzeitevidenz kann relevante Eigenlast erzeugen. Eine erwartete Kernanalyse ohne sichtbare Nutzung kann auf fehlende Schulung, fehlende Berechtigung, deaktivierte Capability oder eine Query-Store-Evidenzlücke hinweisen. Erst Status, Scope und eine unabhängige Gegenprüfung entscheiden, welche Erklärung zutrifft.

## Wann ist es kein Problem?

Spezialanalysen werden absichtlich selten ausgeführt. Mehrere Pläne können durch Schemaänderungen, Recompile, unterschiedliche SET-Optionen oder legitime Varianten entstehen. Hohe Nutzung ist bei einer bewusst regelmäßig aufgerufenen leichten Procedure erwartbar und allein kein Optimierungsauftrag.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** `USP_ExampleHeavyAnalysis` besitzt im gewählten Fenster viele Ausführungen, hohe gewichtete CPU und Reads. Prüfen Sie danach Query-Store-Details, Waits und Aufrufrhythmus; ändern Sie die Procedure nicht allein aufgrund dieser Aggregation.

**Ähnlich aussehender Gegenfall:** `USP_ExampleHealthCheck` wird häufig aufgerufen, bleibt aber kurz und verursacht geringe Reads. Die hohe Ausführungsanzahl beschreibt dann den Betriebsrhythmus und keinen Defekt.

## Leere oder partielle Ausgabe

`AVAILABLE_EMPTY` bedeutet, dass der Query Store lesbar war, aber im gewählten Zeitraum und Mindestfilter keine ausgabefähige Procedure entstand. `UNAVAILABLE_FEATURE` bedeutet, dass Query Store nicht lesbar aktiv war. `DENIED_PERMISSION` oder `ERROR_HANDLED` kennzeichnen einen kontrolliert fehlgeschlagenen Quellenpfad. `NULL` in einer Kennzahl bedeutet fehlende oder nicht ableitbare Evidenz und ist nicht mit dem gemessenen Wert 0 gleichzusetzen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW_MEDIUM |
| Standardpfad | Query-Store-Zustand lesen und höchstens 100 sichtbare Procedures projizieren. |
| Teuerster Pfad | Unbegrenztes Zeitfenster bei großem Query Store und `@MaxZeilen = 0`; die Aggregation muss alle passenden Runtime-Stats-Intervalle und Pläne gruppieren. |
| Haupttreiber | Anzahl passender Query-Store-Queries, Pläne, Runtime-Stats-Intervalle und Länge des sichtbaren Retentionsfensters. |
| Skalierung | Die Aggregationskosten wachsen mit dem gespeicherten Query-Store-Volumen, nicht nur mit der Anzahl ausgegebener Procedures. |
| Ressourcen | Katalog-I/O, CPU für Gruppierung und eine kleine lokale TempDB-Projektion; keine Plan-XML- oder Query-Text-Verarbeitung. |
| Begrenzungswirkung | Ein positives @ZeitraumTage verwendet last_execution_time >= CutoffUtc auf der gespeicherten Runtime-Stats-Zeile und übernimmt deren vollständige Statistik, ohne anteilige Intervallzerlegung. @MinAusfuehrungen filtert nach der Aggregation; @MaxZeilen begrenzt die sortierte usage-Projektion und setzt bei weiteren Kandidaten HasMoreRows. |
| Locking und Nebenwirkungen | Read-only mit `NOLOCK` auf den verwendeten Katalogviews und lokalem `LOCK_TIMEOUT`; keine Query-Store-Konfigurationsänderung, kein Flush und kein Cleanup. |
| Schutzmechanismus | HELP beendet sich vor TABLE-Preflight und regulärer Parameterprüfung. Im normalen TABLE-Aufruf läuft der Zuordnungs-Preflight vor der regulären Parameterprüfung; danach folgen kontrollierte Quellenpfade, sichtbare Quellenstatus und die Wiederherstellung des ursprünglichen LOCK_TIMEOUT im regulären Finalize-Pfad. |
| Sicherer Einsatz | Mit kurzem Zeitraum und begrenzter Ausgabe beginnen; bei großem Query Store erst danach das Fenster erweitern. |
| Aussagegrenze | Query Store ist eine persistierte, aber konfigurations- und retentionabhängige Evidenzquelle. Fehlende Daten sind keine Nutzungs- oder Gesundheitsgarantie. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche `monitor`-Procedures besitzen im sichtbaren Query-Store-Scope belastbare Nutzungs- und Lastindikatoren?

### Technischer Hintergrund

`sys.query_store_query.object_id` ordnet erfasste Statements einem Datenbankobjekt zu. Die Procedure verbindet diese Zuordnung mit `sys.objects` und `sys.schemas`, beschränkt auf Procedures im Schema `monitor`, und aggregiert anschließend Pläne und Runtime-Stats-Intervalle. Die Mittelwerte werden mit `count_executions` gewichtet, damit Intervalle mit wenigen und vielen Ausführungen nicht gleich stark zählen.

### Datenkette

`sys.database_query_store_options` → `sys.query_store_query` → `sys.query_store_plan` → `sys.query_store_runtime_stats`; Objektfilter über `sys.objects` und `sys.schemas`; begrenzte Projektion in lokale Temp-Tabellen.

### Source Select

Der Kernzugriff verwendet ausschließlich Katalog- und Query-Store-Metadaten:

```sql
SELECT
      [o].[name]
    , [q].[query_id]
    , [p].[plan_id]
    , [rs].[count_executions]
    , [rs].[avg_duration]
    , [rs].[avg_cpu_time]
    , [rs].[avg_logical_io_reads]
FROM [sys].[query_store_query] AS [q] WITH (NOLOCK)
INNER JOIN [sys].[objects] AS [o] WITH (NOLOCK)
    ON [o].[object_id] = [q].[object_id]
INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
    ON [s].[schema_id] = [o].[schema_id]
INNER JOIN [sys].[query_store_plan] AS [p] WITH (NOLOCK)
    ON [p].[query_id] = [q].[query_id]
INNER JOIN [sys].[query_store_runtime_stats] AS [rs] WITH (NOLOCK)
    ON [rs].[plan_id] = [p].[plan_id]
WHERE [s].[name] = N'monitor';
```

Query-Store-Texte, Parameterwerte, Plan-XML, Benutzeridentitäten und freie Payloads werden nicht gelesen.

**Wichtig für die Eigenlast:** Der Ressourcenscope bleibt auf die aktuelle Frameworkdatenbank und deren Query-Store-Katalog beschränkt. Es gibt keinen Cross-Database- oder Server-Wildcard-Zugriff; das Retentionsvolumen der aktuellen Datenbank bestimmt dennoch die Aggregationskosten.

### Zeit- und Scope-Modell

Der Scope ist die Frameworkdatenbank, in der die Procedure ausgeführt wird. `@ZeitraumTage` begrenzt anhand des letzten Ausführungszeitpunkts der Runtime-Stats-Intervalle. Die zeitliche Genauigkeit bleibt durch Query-Store-Intervalle, Flushzeitpunkt, Retention und Cleanup begrenzt.

### Bewertung und Gegenprobe

Vergleichen Sie Nutzung und Last mit `USP_QueryStoreStatus`, detaillierten Query-Store-Analysen, Current Requests und der dokumentierten Capability. Für eine Lastbewertung sind mindestens Zeitfenster, Ausführungsanzahl, CPU, Reads und unabhängige aktuelle oder historische Evidenz gemeinsam zu betrachten.

### Typische Fehlinterpretation

`PlanCount > 1` beweist keine Regression. `ExecutionCount` entspricht nicht zwingend der Anzahl äußerer `EXEC`-Aufrufe, weil eine Procedure mehrere erfasste Statements besitzen kann. Eine nicht sichtbare Procedure ist nicht automatisch ungenutzt.

### Folgeanalyse

Prüfen Sie zunächst Query-Store-Zustand und Retention. Vertiefen Sie auffällige Procedures anschließend über `USP_QueryStoreAnalysis`, `USP_QueryStoreRegressions`, `USP_CurrentRequests` und `USP_PlanDetails`.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)
- [Query-Store-Katalogsichten](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/query-store-catalog-views-transact-sql?view=sql-server-ver17)
- [sys.query_store_runtime_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#framework-nutzung-aus-query-store)

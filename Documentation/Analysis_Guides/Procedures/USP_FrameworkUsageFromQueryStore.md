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

## Resultsets und Leserichtung

Der technische Vertrag besteht aus `moduleStatus`, `usage`, `sourceStatus` und `warnings`. Zuerst sind Status und Quellenlage zu prüfen. CONSOLE zeigt nur das fachliche `usage`-Resultset; RAW gibt alle vier Resultsets aus. TABLE schreibt ausschließlich benannte lokale `#Temp`-Ziele. NONE unterdrückt fachliche Resultsets, kann aber JSON und OUTPUT-Parameter liefern.

## Eine Zeile bedeutet

Eine `usage`-Zeile entspricht einer sichtbaren Procedure im Schema `monitor`. Die Werte aggregieren alle sichtbaren Query-Store-Queries und Pläne, deren `object_id` auf diese Procedure verweist. Eine Zeile ist daher keine einzelne Ausführung und keine einzelne Query-Store-Query.

## So lesen

1. Prüfen Sie `moduleStatus.StatusCode`, `QueryStoreActualStateDesc` und `IsPartial`.
2. Prüfen Sie `sourceStatus`, bevor ein leeres `usage`-Resultset interpretiert wird.
3. `ExecutionCount` ist die Summe der erfassten Statementausführungen je Procedure.
4. Dauer, CPU, Reads und Speicher sind nach `count_executions` gewichtete Query-Store-Intervallaggregate.
5. `HasMoreRows = 1` bedeutet ausschließlich, dass `@MaxZeilen` die Projektion begrenzt hat.
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
| Begrenzungswirkung | `@ZeitraumTage` begrenzt Runtime-Stats-Intervalle; `@MinAusfuehrungen` filtert nach der Aggregation; `@MaxZeilen` begrenzt die sortierte Projektion und setzt `HasMoreRows`. |
| Locking und Nebenwirkungen | Read-only mit `NOLOCK` auf den verwendeten Katalogviews und lokalem `LOCK_TIMEOUT`; keine Query-Store-Konfigurationsänderung, kein Flush und kein Cleanup. |
| Schutzmechanismus | Parameterprüfung vor dem fachlichen Zugriff, isolierte TRY/CATCH-Quellen, sichtbare Quellenstatus und Wiederherstellung des ursprünglichen `LOCK_TIMEOUT`. |
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

[Technische Detailbeschreibung](../05_Query_Store.md)

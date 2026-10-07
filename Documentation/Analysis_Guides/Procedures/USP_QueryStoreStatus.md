# [monitor].[USP_QueryStoreStatus]

**Bereich:** Query Store<br>
**Zweck:** Zeigt Zustand, Capture, Retention, Speicher, Cleanup und Wait-Capture je Datenbank.<br>
**Beobachtungsart:** Konfigurationssnapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Ist Query Store aktiviert, schreibfähig, ausreichend dimensioniert und für den gewünschten Evidenztyp konfiguriert?** Sie unterstützt die Entscheidung, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStoreStatus]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `queryStoreStatus` mit 27 Feldern und sieben expliziten Frameworktextcollations. `DatabaseName` ist die einzige NOT-NULL-Spalte; das Schema enthält keine Identity. RAW, CONSOLE, TABLE und JSON verwenden dieselbe früh angelegte Ergebnistabelle. RAW liefert zusätzlich Meta/Status und Fehler/Warnungen, JSON die Objekte `meta`, `queryStoreStatus` und `warnings`. Die aktive CONSOLE zeigt die Statusdaten mit einem zusätzlichen `Ergebnis`-Feld; bei leerer Menge liefert sie eine dreifeldrige Hinweiszeile. TABLE schreibt ausschließlich die fachliche Statusmenge. Lesen Sie den Modulstatus und die Warnungen aus RAW oder JSON vor der fachlichen Interpretation.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Query-Store-Datenbank. Status- und Warnresultsets besitzen separate Zeilen.

## So lesen

Prüfen Sie `ActualStateDesc`, Readonly Reason, Storage Used, Capture Mode, Cleanup, Interval Length und Wait Capture.

## Warum kann das problematisch sein?

Read-only, voller Speicher oder Capture-Regeln können Historienlücken erzeugen. Fehlende Queries sind dann keine Entwarnung.

## Wann ist es kein Problem?

Capture Mode AUTO lässt billige oder seltene Queries absichtlich aus.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Leeres Waitresultset plus Wait Capture OFF ist erwartbar. Starten Sie erst bei geeignetem Status Runtime-, Wait- oder Plananalyse.

**Ähnlich aussehender Gegenfall:** Capture Mode AUTO lässt billige oder seltene Queries absichtlich aus. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Die Procedure liest aktuelle Optionen und besitzt kein Zeitfenster. Eine OFF-Datenbank kann eine Statuszeile mit `IsEnabled=0` und dem entsprechenden `StatusHint` liefern; OFF bedeutet daher keine leere Ausgabe.

Für `USP_QueryStoreStatus` bedeutet **keine Zeile**, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur bei verfügbarer Quellspalte; **NULL** bezeichnet unbekannte oder nicht anwendbare Werte. Eine gültige und eine fehlende explizite Auswahl erhalten die gültige Statuszeile und eine `DATABASE_NOT_FOUND`-Warnung; der Modulstatus wird `AVAILABLE_LIMITED` mit `isPartial=1`. Bei ausschließlich fehlender Auswahl bleibt die Statusmenge leer und der Modulstatus ist `DATABASE_UNAVAILABLE`. Ein Zeilenlimit oder Problemfilter existiert nicht.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Die Eigenlast ist sehr gering; je Datenbank entsteht eine Statuszeile.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Ohne Filter werden alle sichtbaren Online-Benutzerdatenbanken ausgewählt. Je ausgewählter Datenbank wird `sys.database_query_store_options` dynamisch gelesen. Es gibt weder Zeitfenster noch Query-/Plan- oder XML-Zugriff. |
| Teuerster Pfad | Keine Datenbankeinschränkung, sodass alle sichtbaren Online-Userdatenbanken nacheinander geprüft werden. Die Quellmenge bleibt eine Statuszeile je Datenbank. |
| Haupttreiber | Zahl ausgewählter Datenbanken; je Datenbank wird im Wesentlichen eine Query-Store-Optionszeile plus Feature-/Statuskontext gelesen. Query-, Plan-, Text- und Runtime-Tabellen liegen ausdrücklich außerhalb dieses Statuspfads. |
| Skalierung | Laufzeit und dynamischer Compileaufwand wachsen annähernd linear mit der Zahl ausgewählter Datenbanken, nicht mit Query-Store-Retention oder Capturevolumen. |
| Ressourcen | Sehr geringe CPU- und Katalog-I/O-Last; ein kurzer dynamischer Kontextwechsel und eine Optionszeile je Datenbank. Keine TempDB-Fensteraggregation, Texte oder Pläne. |
| Begrenzungswirkung | Datenbankliste/-pattern sind die einzigen Mengengrenzen und wirken vor dem Cursor. Einen `@MaxZeilen`-Parameter gibt es absichtlich nicht, weil pro Datenbank genau eine Statuszeile entsteht. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | `QUERY_STORE_CURRENT` muss im Framework freigegeben sein, verlangt laut Klassenkatalog aber keine High-Impact-Bestätigung. `@HighImpactConfirmed` aktiviert in dieser Procedure keinen Deep-Pfad. |
| Sicherer Einsatz | Eine `ExampleDatabase` und CONSOLE; danach nur bei Bedarf weitere Datenbanken ergänzen. Statuszeile und Warnungen vor fachlicher Interpretation sichern. |
| Aussagegrenze | Explizite Listen und Pattern schränken den Datenbankscope ein. Der Konfigurationssnapshot belegt weder erfasste Ausführungen noch Capture-Vollständigkeit oder die Ursache eines Zustands. Ein ausgeschlossener Datenbankscope bleibt unbeurteilt. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist Query Store aktiviert, schreibfähig, ausreichend dimensioniert und für den gewünschten Evidenztyp konfiguriert?

### Technischer Hintergrund

`sys.database_query_store_options` trennt gewünschten und tatsächlichen Zustand, Operation Mode, Capture Mode, Interval Length, Retention, Current/Max Size, Cleanup und Wait Stats Capture. READ_ONLY kann aus administrativer Konfiguration oder internen Gründen wie Größenlimit entstehen.

### Datenkette

`sys.database_query_store_options`, `sys.sp_executesql`.

### Source Select

Der Status ist eine direkte datenbanklokale Katalogabfrage:

```sql
SELECT
      [actual_state_desc]
    , [desired_state_desc]
    , [current_storage_size_mb]
    , [max_storage_size_mb]
    , [readonly_reason]
    , [stale_query_threshold_days]
    , [interval_length_minutes]
FROM [sys].[database_query_store_options] WITH (NOLOCK);
```

**Wichtig für die Eigenlast:** Die Quelle ist klein. Die Datenbankauswahl muss trotzdem vor dem Kontextwechsel erfolgen; Statusprüfung erfordert weder Runtime-Stats noch Query Text oder Plan-XML.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Zustand je ausgewählter Datenbank. Status sagt nichts über bereits gelöschte oder nie erfasste Historie.

### Bewertung und Gegenprobe

Berücksichtigen Sie Actual vs Desired State, Readonly Reason, Current/Max Size, Stale Query Threshold, Cleanup und Capture Mode gemeinsam. Waitanalyse benötigt aktiviertes Wait Capture.

### Typische Fehlinterpretation

`READ_WRITE` beweist weder Vollständigkeit noch repräsentative Capture-Auswahl. `OFF` zum Analysezeitpunkt erklärt nicht immer, ob frühere Daten noch vorhanden sind.

### Folgeanalyse

Führen Sie diese Prüfung vor allen Query-Store-Fachanalysen aus. Prüfen Sie bei Problemen Konfiguration, Storage und Capturepolicy.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#1-monitorusp_querystorestatus)

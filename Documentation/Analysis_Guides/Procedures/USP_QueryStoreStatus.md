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

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@QueryStoreDatabaseNames` | `nvarchar(max)` | `NULL` | Im normalen Analysepfad: Bei Auslassung gilt NULL. NULL sowie N'', N' ' oder ausschließlich äußere U+0020-Leerzeichen bedeuten keine Namenseinschränkung; damit werden alle sichtbaren, zugreifbaren Online-Datenbanken im durch @SystemdatenbankenEinbeziehen bestimmten Scope gewählt, sofern kein Pattern gesetzt ist. Sonst eine bracket-aware Pipe-Liste eintragen: &#124; trennt Elemente nur außerhalb von eckigen Klammern, ]] maskiert eine schließende Klammer; äußere Leerzeichen je Element werden entfernt. Vorgesehen ist ein einteiliger SQL-Name je Element; leere Elemente, ungültige Klammern und ungültige Namen sind INVALID_PARAMETER. Die Liste wird gegen sichtbare Datenbanknamen verglichen; die Parsefunktion ist keine allgemeine Bezeichnervalidierung und prüft weder Existenz noch Zugriff. Doppelte gültige Namen werden vom Auswahlhelfer abgelehnt (Vergleich mit SQL_Latin1_General_CP1_CS_AS). Eine wirksame nichtleere explizite Liste und ein nicht-NULL Pattern sind unzulässig zusammen. Eine nicht auffindbare/offline/nicht zugreifbare explizite Datenbank erzeugt eine Warnung; gültige übrige Treffer können als AVAILABLE_LIMITED ausgegeben werden. Ausgelassen gilt der deklarierte Default NULL. Die tatsächliche Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und höchstens 128 Zeichen für Teil 1; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | Im normalen Analysepfad: Bei Auslassung gilt 0. 0 schließt Systemdatenbanken mit database_id 1 bis 4 aus; 1 bezieht diese ein. NULL ist INVALID_PARAMETER und wird nicht als 0 behandelt. Der Wert muss als bit 0 oder 1 gebunden werden. Leere Textwerte sind keine bit-Eingabeform. Bei @Hilfe=1 kehrt die Procedure vor dem Aufruf von 083 zurück; die NULL-Prüfung des normalen Auswahlpfads wird im Hilfezweig übersprungen. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@QueryStoreDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Im normalen Analysepfad: Bei Auslassung gilt NULL und es wird kein Pattern angewandt. NULL ist gültig; leerer Text oder ein nach äußerem LTRIM/RTRIM leerer Wert ist INVALID_PARAMETER. Alle erlaubten Präfixe werden ohne Beachtung der Groß-/Kleinschreibung erkannt: kein Präfix oder like: wählt SQL-LIKE-Modus (case-sensitive Vergleich); regex: wählt case-sensitive Regex (Flag c); regexi: wählt case-insensitive Regex (Flag i). Nach dem Präfix wird der Inhalt nicht erneut getrimmt und darf nicht leer sein. Regex wird nur auf SQL Server 2025 bei Compatibility Level 170 der Installationsdatenbank ausgeführt; diese Voraussetzung wird nicht je Quelldatenbank geprüft. Die Regex-Syntax wird vom Parser nicht vorab validiert. Das Pattern wirkt auf die Kandidatennamen im Frameworkhelfer und ist keine pro Quelldatenbank erneut ausgeführte Patternabfrage. Ein nicht-NULL Pattern und eine nichtleere explizite Namensliste sind gegenseitig exklusiv. Ausgelassen gilt der deklarierte Default NULL. LIKE verwendet %, _ und Zeichenklassen [...]. Präfix- und Eingabeformat sind Textwerte, zum Beispiel N'like:App%'; nach Präfixentfernung bleiben Inhalt und Groß-/Kleinschreibung erhalten. |
| `@HighImpactConfirmed` | `bit` | `0` | Im normalen Auswahlpfad: Default: 0. Bei Auslassung gilt 0. 0 übergibt keine High-Impact-Bestätigung; 1 übergibt den gesetzten Bestätigungswert an InternalCheckAnalysisPath. NULL ist INVALID_PARAMETER und wird nicht als Default behandelt. QUERY_STORE_CURRENT ist in diesem Quellstand keine gruppengeschützte Analyseklasse (RequiresGroupGate=0); 1 löst in dieser Procedure keinen zusätzlichen Deep-Pfad aus und ist kein Nachweis, dass ein Gate erforderlich war oder passiert wurde. Leere Textwerte sind keine bit-Eingabeform. Bei @Hilfe=1 wird 083 nicht aufgerufen; diese normale Validierung wird dann übersprungen. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Im normalen Analysepfad: Bei Auslassung gilt CONSOLE. Der Eingabetext wird vor der Auswertung mit LTRIM/RTRIM und UPPER normalisiert (nach Bindung an varchar(16)); NULL wird zu leerem Text und ist INVALID_PARAMETER. Zulässig sind genau CONSOLE, RAW, TABLE und NONE, jeweils ohne Beachtung der Groß-/Kleinschreibung: CONSOLE ruft InternalEmitConsoleResult auf und liefert die fachliche Statusdatenmenge oder bei Leere einen formatierten Hinweis; RAW liefert drei Resultsets mit Modulmetadaten/-status, queryStoreStatus-Daten und Fehlern; TABLE schreibt ausschließlich das Resultset queryStoreStatus in das vorab gemappte Ziel; NONE unterdrückt Grid-Resultsets. JSON-Erzeugung ist unabhängig von dieser Auswahl. Andere Werte sind INVALID_PARAMETER. Ausgelassen gilt der deklarierte Default 'CONSOLE'. Maßgeblich ist der bereits an varchar(16) zugewiesene Wert; eine längere Textangabe kann davor auf die Typbreite gekürzt werden. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Bei Auslassung gilt NULL. Nur für TABLE ist eine nichtleere Zuordnung zulässig und dort zwingend erforderlich. Sie muss ein gültiges, nichtleeres JSON-Objekt mit genau einem Schlüssel queryStoreStatus und einem nichtleeren Stringwert sein, z. B. N'{"queryStoreStatus":"#QueryStoreStatusTarget"}'. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle sein, die genau eine beliebige Seed-Spalte hat; das vollständige Ergebnisschema wird nicht als Seed angelegt. Das Mapping wird vor HELP und vor fachlichen Quellenzugriffen validiert; Fehler werfen bei dieser Procedure. Bei CONSOLE, RAW oder NONE führt eine nicht-NULL, nicht nur aus äußerem LTRIM/RTRIM-Leerraum bestehende Zuordnung zu THROW 51011. NULL oder leerer/U+0020-Leerzeichen-Wert ist außerhalb TABLE zulässig, erfüllt aber die TABLE-Pflicht nicht. Ausgelassen gilt der deklarierte Default NULL. Schlüssel werden binär einschließlich Groß-/Kleinschreibung verglichen; doppelte Schlüssel sind ungültig. Zielnamen sind Strings mit LEN höchstens 116, beginnen mit #, aber nicht ## oder case-insensitiv #Monitor; doppelte Ziele werden case-insensitiv abgewiesen. Die einzelne Seed-Spalte hat einen beliebigen Namen und Typ; eine Seed-Zeile ist nicht zulässig. |
| `@JsonErzeugen` | `bit` | `0` | Im normalen Analysepfad: Bei Auslassung gilt 0. 0 oder NULL erzeugt kein JSON; 1 erzeugt im @Json-OUTPUT-Parameter das JSON-Objekt mit meta, queryStoreStatus und warnings, unabhängig von @ResultSetArt. Der Parameter wird nur auf =1 geprüft; NULL wird daher wie ausgeschaltet behandelt und ist kein INVALID_PARAMETER. Als Eingabeform ist ein bit-Wert 0 oder 1 vorgesehen; leere Textwerte sind keine bit-Eingabeform. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Bei Auslassung gilt NULL und es gibt keinen Empfänger für den Output. Zur Übernahme ist eine nvarchar(max)-kompatible lokale Variable mit OUTPUT zu binden. Die Procedure setzt den Parameter am Anfang auf NULL; nur wenn @JsonErzeugen=1 wird anschließend das JSON mit meta, queryStoreStatus und warnings zugewiesen. Ohne JSON-Erzeugung bleibt der gebundene Output NULL. Ein nicht gebundener OUTPUT-Aufruf kann kein JSON zurückgeben. Ausgelassen gilt der deklarierte Default NULL. Der Eingabewert dient nicht als Steuerwert; bei Hilfe bleibt der intern zurückgesetzte Wert NULL. Bei vorzeitigem THROW ist kein übernommener OUTPUT zugesichert. |
| `@PrintMeldungen` | `bit` | `1` | Bei Auslassung gilt 1. 1 gibt die normalen Warn-/Statusmeldungen als RAISERROR severity 10 aus, wenn der jeweilige Fehler-/Warnpfad erreicht wird; 0 unterdrückt diese Meldungen. NULL wird nur auf =1 geprüft und unterdrückt daher ebenfalls. Der Schalter ändert weder gespeicherte Error-/Warning-Daten noch Resultsets oder JSON; der HELP-Zweig verwendet PRINT unabhängig davon. Als Eingabeform ist ein bit-Wert 0 oder 1 vorgesehen; leere Textwerte sind keine bit-Eingabeform. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@Hilfe` | `bit` | `0` | Bei Auslassung gilt 0. 1 druckt die eingebaute Parameterhilfe und beendet die Procedure danach; 0 führt die Statusprüfung aus. NULL erfüllt die Prüfung =1 nicht und führt deshalb die normale Verarbeitung aus. Bei @ResultSetArt=TABLE wird das Mapping vor der Hilfe validiert und kann vor dem PRINT mit Fehler abbrechen. Als Eingabeform ist ein bit-Wert 0 oder 1 vorgesehen; leere Textwerte sind keine bit-Eingabeform. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. Die normale Validierung von Ausgabemodus, Pattern, Namenslisten und Auswahlhelferparametern wird im Hilfezweig übersprungen; der frühe Nicht-TABLE-Mappingguard und TABLE-Zielpreflight bleiben aktiv. |

```sql
EXEC [monitor].[USP_QueryStoreStatus] @Hilfe = 1;
```

```sql
EXEC [monitor].[USP_QueryStoreStatus] @QueryStoreDatabaseNames = N'[ExampleDatabase]', @ResultSetArt = 'RAW';
```

```sql
DECLARE @Json nvarchar(max) = NULL;
EXEC [monitor].[USP_QueryStoreStatus]
      @QueryStoreDatabaseNames=N'[ExampleDatabase]'
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT;
SELECT @Json AS [JsonPayload];
```

```sql
CREATE TABLE [#QueryStoreStatusTarget] ([Seed] bit NULL);
EXEC [monitor].[USP_QueryStoreStatus]
      @ResultSetArt = 'TABLE'
    , @ResultTablesJson = N'{"queryStoreStatus":"#QueryStoreStatusTarget"}';
SELECT * FROM [#QueryStoreStatusTarget];
DROP TABLE [#QueryStoreStatusTarget];
```

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

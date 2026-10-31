# [monitor].[USP_QueryStoreAnalysis]

**Bereich:** Query Store, Orchestrator<br>
**Zweck:** Orchestriert Status, Runtime, Waits, Planwechsel, Regressionen, Forced Plans, Hints, Replica-Kontext und IQP.<br>
**Beobachtungsart:** nicht atomare Folge persistierter Query-Store-Historien<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Query-Store-Perspektiven sollen kontrolliert in einem Lauf ausgeführt werden?** Sie unterstützt die Entscheidung, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

EXEC [monitor].[USP_QueryStoreAnalysis]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @VonUtc = @ExampleVonUtc,
      @BisUtc = @ExampleBisUtc,
      @MitStatus = 1,
      @MitRuntimeStats = 1,
      @MitReplicaKontext = 1,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Wenn `@VonUtc` und `@BisUtc` NULL bleiben, verwendet das Runtime-Child standardmäßig ein Fenster der letzten Stunde. Ein ausdrücklich gesetztes kurzes Fenster begrenzt Quellkosten und Aussage-Scope; es ist nicht nur ein Ausgabefilter.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@QueryStoreDatabaseNames` | `nvarchar(max)` | `NULL` | Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]&#124;[OtherDatabase]'; &#124; trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen. Unveränderte Weitergabe an alle neun Teilmodule; eigene Namensprüfung und kontrollierter Auswahlstatus liegen beim tatsächlich aktivierten Teilmodul. |
| `@QueryStoreDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert. Weitergabe an alle neun Teilmodule. Bei gleichzeitig effektiver nichtleerer Namensliste wird der Aufruf dort abgewiesen, keine Liste bevorzugt. LIKE unterstützt %, _ und Zeichenklassen [...]. |
| `@HighImpactConfirmed` | `bit` | `0` | Ausgelassen/0: keine High-Impact-Bestätigung. 1 bestätigt einen tatsächlich aktivierten gruppengeschützten Pfad, ohne Modul oder Rechte zu aktivieren. Der Orchestrator prüft NULL nicht selbst; bei erreichter Datenbankvorbereitung eines aktivierten Teilmoduls ist es INVALID_PARAMETER. Alle neun Teilmodule erhalten den Wert. Die Query-Store-Basisklasse hat kein Gruppengate; Referenzfilter, breite Zeitfenster und &gt;1000/unbegrenzte Limits können je Teilmodul QUERY_STORE_DEEP verlangen. Replica-Kontext aktiviert keinen Deep-Pfad; IQP verlangt unabhängig vom Limit CATALOG_DEEP mit Bestätigung und Gruppenfreigabe. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@ReferencedDatabaseNames` | `nvarchar(max)` | `NULL` | ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; &#124; trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein; Teile 3/4 werden nicht gesondert geprüft. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus. Weitergabe nur an RuntimeStats, WaitStats, PlanChanges, Regressions und ForcedPlans; Status, Hints, Replica-Kontext und IQP erhalten diesen Filter nicht. Ohne eines der fünf aktivierten Teilmodule wird er nicht verarbeitet. |
| `@ReferencedDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert. Weitergabe nur an RuntimeStats, WaitStats, PlanChanges, Regressions und ForcedPlans; die anderen vier Teilmodule erhalten ihn nicht. LIKE unterstützt %, _ und Zeichenklassen [...]. |
| `@VonUtc` | `datetime2(7)` | `NULL` | Ausgelassen/NULL wird unverändert weitergegeben, keine globale offene Untergrenze. UTC-datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T12:00:00.0000000 übergeben; keine Zeitzonenumrechnung. Bei zwei gesetzten Grenzen lehnt der Orchestrator nur VonUtc &gt; BisUtc ab; Gleichheit passiert diese Prüfung, kann im Teilmodul aber ungültig sein. Runtime, Waits und Replica-Kontext setzen NULL auf eine Stunde vor ihrem effektiven Ende und berücksichtigen vollständige überlappende Intervalle. PlanChanges erhält nur VonUtc; dort bedeutet NULL kein Zeitfilter. Regressionen erhalten ihn als Vergleichsbeginn und leiten die Baseline standardmäßig aus der Stunde davor ab. Status, ForcedPlans, Hints und IQP erhalten keinen Zeitparameter. DATEADD-Defaults an frühen datetime2-Grenzen können im Teilmodul überlaufen und werden dann als Aufruffehler erfasst. |
| `@BisUtc` | `datetime2(7)` | `NULL` | Ausgelassen/NULL wird unverändert weitergegeben, keine globale offene Obergrenze. UTC-datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T13:00:00.0000000 übergeben; keine Zeitzonenumrechnung. Runtime, Waits, Replica-Kontext und Regressionen lösen NULL jeweils auf ihren eigenen aktuellen UTC-Endzeitpunkt auf; bei zugleich NULLem Beginn gilt dort die letzte Stunde. Getrennte Aufrufe garantieren keinen identischen Endzeitpunkt. Regressionen verwenden ihn als Vergleichsende; die Baseline liegt standardmäßig in der Stunde vor Vergleichsbeginn. PlanChanges und die übrigen Teilmodule erhalten BisUtc nicht. Der Orchestrator lehnt nur zwei gesetzte Grenzen mit VonUtc &gt; BisUtc ab; strengere Teilmodulprüfungen bleiben wirksam. |
| `@MitStatus` | `bit` | `1` | 0 deaktiviert, 1 aktiviert USP_QueryStoreStatus; ausgelassen ergibt 1. NULL wird nicht zu 0 normalisiert und die IF-Bedingung aktiviert das Teilmodul nur bei genau 1; außerdem verhindert NULL im Schalterbündel, dass dessen All-aus-Guard TRUE wird. Die Orchestratorprüfung prüft nur, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert Query-Store-Zustand, Capture- und Retentioneinstellungen. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@MitRuntimeStats` | `bit` | `1` | 0 deaktiviert, 1 aktiviert USP_QueryStoreRuntimeStats; ausgelassen ergibt 1. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert aggregierte Runtime- und Ressourcenwerte je Query/Plan. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@MitWaitStats` | `bit` | `0` | 0 deaktiviert, 1 aktiviert USP_QueryStoreWaitStats; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert aggregierte Query-Store-Waitkategorien. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@MitPlanChanges` | `bit` | `0` | 0 deaktiviert, 1 aktiviert USP_QueryStorePlanChanges; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert Querysummaries und gespeicherte Pläne von Queries mit mehreren Plänen. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@MitRegressionen` | `bit` | `0` | 0 deaktiviert, 1 aktiviert USP_QueryStoreRegressions; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert gewichteten Metrikvergleich von Baseline und Vergleichsfenster. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@MitForcedPlans` | `bit` | `0` | 0 deaktiviert, 1 aktiviert USP_QueryStoreForcedPlans; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert Inventar erzwungener Pläne und Force-Fehler ohne Änderung der Planbindungen. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@MitHints` | `bit` | `0` | 0 deaktiviert, 1 aktiviert USP_QueryStoreHints; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert gespeicherte Query-Store-Hints und deren Fehlerstatus ab SQL Server 2022 ohne Setzen von Hints. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@MitReplicaKontext` | `bit` | `1` | 0 deaktiviert, 1 aktiviert USP_QueryStoreReplicaAnalysis; ausgelassen ergibt 1. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Vor SQL Server 2025 kann das aktivierte Teilmodul den tatsächlichen Status UNAVAILABLE_VERSION melden. Das Teilmodul liefert rollengetrennte Query-Store-Runtime-, Wait- und Forcing-Evidenz; vor SQL Server 2025 kontrolliert UNAVAILABLE_VERSION, kein aktueller AG-Gesundheitsnachweis. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@MitIQP` | `bit` | `0` | 0 deaktiviert, 1 aktiviert USP_IntelligentQueryProcessingAnalysis; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Das Teilmodul liefert einen eigenen tatsächlichen Status. Das Teilmodul liefert datenbankweite IQP-Konfiguration und Feedback-/Tuningevidenz; dieser Pfad verlangt CATALOG_DEEP-Freigabe und HighImpactConfirmed=1. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@MaxZeilen` | `int` | `100` | Ausgelassen: 100. Positive ganze int-Werte von 1 bis 2147483647 sind das weitergereichte Limit; NULL/0 bedeutet in den empfangenden Teilmodulen unbegrenzt. Negative Werte lehnt der Orchestrator vor allen Teilmodulaufrufen als INVALID_PARAMETER ab. Weitergabe an acht Teilmodule außer Status; jedes begrenzt eigene Ergebnismengen nach seinem Aggregations-/Kandidatenvertrag. Kein Gesamtlimit über alle Teilmodulzeilen und kein Limit für das Aufrufjournal mit höchstens neun Zeilen. &gt;1000 beziehungsweise NULL/0 kann in unterstützenden Query-Store-Teilmodulen Deep aktivieren; das IQP-Gate ist ohnehin erforderlich. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Ausgelassen: CONSOLE. Nach äußerem U+0020-Trim und Großschreibung genau vier Werte: RAW wird an ausgewählte Teilmodule weitergegeben und liefert deren Resultsets vor zwei Orchestratorresultsets (Metadaten und Aufrufjournal); CONSOLE führt Teilmodule mit NONE aus und zeigt nur das Journal mit Ergebnislabel oder bei Leere eine Hinweiszeile; TABLE führt Teilmodule mit NONE aus und schreibt nur das Journal in moduleStatus; NONE unterdrückt normale Resultsets aller Teilmodule und des Orchestrators. JSON ist unabhängig, technische Meldungen werden separat gesteuert. NULL, leer, nur U+0020 oder andere Werte sind im normalen Ablauf INVALID_PARAMETER. Die Bindung an varchar(16) erfolgt vor der Prüfung. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Ausgelassen/NULL, leer oder nur äußere U+0020-Leerzeichen sind außerhalb TABLE zulässig; anderer nichtleerer Inhalt wirft dort vor Hilfe Fehler 51011. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem binär exakten Schlüssel moduleStatus erforderlich. Der Stringwert benennt ein vorhandenes, leeres lokales #Temp-Ziel mit genau einer beliebigen Seed-Spalte und keiner Seed-Zeile; kein ##, LEN höchstens 116, kein reserviertes #Monitor-Präfix. Unbekannte/doppelte Schlüssel oder ungültige Ziele scheitern im frühen ThrowOnError-Preflight vor Hilfe und Fachvalidierung. Der Writer ersetzt die Seed-Struktur. moduleStatus enthält nur die fünf Journalfelder ExecutionOrdinal, ModuleName, InvocationStatus, ErrorNumber und ErrorMessage, weder Teilmodul-Fachdaten noch übergeordnete Metadaten. |
| `@JsonErzeugen` | `bit` | `0` | Ausgelassen/0: @Json bleibt NULL. 1 erzeugt das Gesamt-JSON unabhängig vom Ausgabemodus und wird auch an jedes aktivierte Teilmodul weitergegeben. NULL wird vom Orchestrator nicht selbst abgewiesen und erzeugt kein Gesamt-JSON; Teilmodule behandeln ihn nach eigenem Vertrag, Replica-Kontext meldet dabei INVALID_PARAMETER. Das Objekt enthält meta (Orchestratorstatus), status (Statusmodul), runtimeStats, waitStats, planChanges, regressions, forcedPlans, queryHints, replicaContext, intelligentQueryProcessing sowie warnings (gefiltertes Aufrufjournal). Nicht ausgeführte oder ohne JSON zurückgekehrte Teilmodule erscheinen als JSON null. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler OUTPUT-Parameter; eine nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Der Eingabewert wird beim Eintritt stets durch NULL ersetzt; nur JsonErzeugen=1 füllt das Gesamtobjekt. Bei Hilfe bleibt NULL. Ohne OUTPUT-Bindung wird kein Wert an den Aufrufer übernommen. Bei ungefangenem Fehler, etwa frühem Mapping-THROW, ist keine OUTPUT-Rückübertragung zugesichert. |
| `@PrintMeldungen` | `bit` | `1` | Ausgelassen: 1. 0 unterdrückt unterstützte optionale Severity-10-Quellen-/Truncationmeldungen, 1 erlaubt sie. Der Orchestrator hat keinen eigenen Meldungszweig, sondern gibt den Wert an alle neun aktivierten Teilmodule weiter. Replica-Kontext und IQP besitzen derzeit keinen solchen Meldungszweig; Replica-Kontext wertet NULL im normalen Ablauf trotzdem als INVALID_PARAMETER. In den übrigen unterstützenden Meldungszweigen unterdrückt NULL die Ausgabe; der Orchestrator normalisiert ihn nicht. Resultset-/JSON-Daten und Hilfe-PRINTs sind unabhängig. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@Hilfe` | `bit` | `0` | Ausgelassen/0 oder NULL: normaler Ablauf. 1 druckt Hilfe und Beispiele und beendet vor normalen Orchestratorprüfungen und Teilmodulaufrufen. SQL-Typbindung, Json=NULL, lokale Journaltabelle, SET LOCK_TIMEOUT 0, Ablehnung nichtleerer Mappings außerhalb TABLE und TABLE-Preflight liegen davor; ein Mappingfehler kann deshalb die Hilfe verhindern. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |

```sql
EXEC [monitor].[USP_QueryStoreAnalysis] @Hilfe=1;
```

```sql
EXEC [monitor].[USP_QueryStoreAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW';
```

```sql
DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
```

```sql
CREATE TABLE [#QueryStoreAnalysis_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#QueryStoreAnalysis_HelpExample"}';
 SELECT * FROM [#QueryStoreAnalysis_HelpExample];
 DROP TABLE IF EXISTS [#QueryStoreAnalysis_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreAnalysis_HelpExample];
 THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `moduleStatus`. Bei RAW kommen zuerst die Resultsets der ausgewählten Teilmodule, danach Wrapper-Meta und Moduljournal. CONSOLE zeigt nur das Wrapperjournal; TABLE schreibt nur dessen fünf Statusspalten in `moduleStatus`. JSON enthält benannte Teilmodulobjekte, `meta.statusCode` und `warnings`. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

TABLE und CONSOLE verwenden dieselbe vollständig materialisierte Modulstatusmenge mit fünf Feldern. Die drei Textfelder besitzen explizit `SQL_Latin1_General_CP1_CS_AS`. CONSOLE ergänzt bei vorhandenen Modulzeilen die Ergebnisbeschriftung; bei leerer Menge liefert es genau die bestehende dreifeldrige Leeranzeige. Der Parentstatus steht im RAW-Metaresultset beziehungsweise in `meta.statusCode` des JSON.

JSON enthält weiterhin benannte Childobjekte und `warnings`; ein `modules`-Array gehört nicht zu diesem Vertrag.

## Eine Zeile bedeutet

In TABLE und CONSOLE bedeutet eine Modulstatuszeile einen tatsächlich aufgerufenen Childpfad mit seiner Aufrufreihenfolge und seinem Invocationstatus. Die fachlichen RAW- und JSON-Childresultate behalten ihre jeweils eigene Granularität.

## So lesen

Prüfen Sie zuerst das Status-Child und danach nur die aktivierten Children. Beachten Sie Zeitfenster und Wrappersemantik der Regressionen.

## Warum kann das problematisch sein?

Ein historisches Ergebnis kann durch Capture, Retention oder Wrapperfenster falsch eingeordnet werden. Der Wrapper übergibt das Fenster als Vergleichsfenster; die Baseline liegt davor.

## Wann ist es kein Problem?

Deaktivierte Teilmodule werden nicht aufgerufen; ihre benannten JSON-Werte sind null.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Letzte Stunde als Eingabefenster bedeutet: Vergleich letzte Stunde, Baseline die Stunde davor. Wiederholen Sie Auffälliges Child mit QueryId/Hash und engem Zeitraum.

**Ähnlich aussehender Gegenfall:** Deaktivierte Teilmodule werden nicht aufgerufen; ihre benannten JSON-Werte sind null. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Query Store kann nutzbar sein, obwohl das gewählte Fenster leer ist. Prüfen Sie zuerst Capturemodus, Read-only-Status, Retention und UTC-Fenster.

Für `USP_QueryStoreAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

@MaxZeilen wird an acht Teilmodule weitergereicht; Status erhält den Parameter nicht. Der Wrapper begrenzt weder die Gesamtzahl der Childzeilen noch die Modulstatusmenge. Nur negative Werte weist er vor der Teilmodulausführung als INVALID_PARAMETER ab. NULL und 0 werden unverändert an die Teilmodule übergeben und gelten nach deren jeweiligem Vertrag. Bei den ersten sieben Teilmodule bedeutet EXECUTED nur, dass der Aufruf ohne THROW zurückkehrte; der Eintrag belegt keinen fachlichen Erfolg. Replica-Kontext und IQP liefern tatsächliche Statuswerte.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Status, Runtime Stats und Replica-Kontext. Wenn `@VonUtc = NULL` und `@BisUtc = NULL`, verwendet das Runtime-Child standardmäßig das letzte Stundenfenster. |
| Teuerster Pfad | Alle neun Teilmodule über mehrere große Query Stores und mit Referenzdatenbankfiltern: Query-/Plan-/Runtimebereiche werden mehrfach verarbeitet. Einige Teilmodule lesen gespeichertes Showplan-XML intern zur Referenzauflösung; der Wrapper hat dafür keinen Plan-XML-Ausgabeschalter. Zeit- und Zeilenparameter gelten nur für Teilmodule, die sie erhalten. |
| Haupttreiber | Zahl der Query-Store-Datenbanken, Queries, Pläne, Runtime-/Wait-Intervalle und Breite der tatsächlich an Zeitfenster gebundenen Auswertungen. Referenzdatenbankfilter bewirken in den unterstützenden Teilmodule interne Showplan-XML-Auswertung; IQP ergänzt datenbankweite Konfigurations-/Feedbackaggregation. |
| Skalierung | Children laufen nacheinander ohne gemeinsamen Query-Store-Snapshot. Status ist klein, Runtime/Wait/Regressionen skalieren mit Intervallen, und PlanChanges/ForcedPlans mit Plananzahl. Dasselbe Zeitfenster wird je aktiviertem Historienchild separat verarbeitet. |
| Ressourcen | I/O und CPU in den persistenten `sys.query_store_*`-Views, Sortierung/Aggregation, dynamisches Cross-Database-SQL, optional Plan-XML und JSON/Transfer. Kein `msdb`, XEL oder WAITFOR. |
| Begrenzungswirkung | @VonUtc und @BisUtc gehen beide an Runtime, Waits und Replica-Kontext; PlanChanges erhält nur @VonUtc, Regressionen beide als Vergleichsfenster. Status, Forced Plans, Hints und IQP erhalten kein Zeitfenster. @MaxZeilen wird an acht Teilmodule übergeben, gilt dort nach Teilmodulvertrag und begrenzt weder global noch das Statusjournal. |
| Locking und Nebenwirkungen | Read-only; es werden weder Pläne erzwungen noch Hints gesetzt. Query Store erfasst während des sequenziellen Laufs weiter, daher können Childnenner und „letzte“ Zeitpunkte voneinander abweichen. |
| Schutzmechanismus | Childscope und High-Impact-Gates werden je tatsächlich aktiviertem Analysepfad geprüft. Status, Runtime und Replica-Kontext sind standardmäßig aktiv; Waits, PlanChanges, Regressionen, Forced Plans, Hints und IQP standardmäßig aus. @HighImpactConfirmed aktiviert kein Child und ersetzt weder Zeit- noch Zeilenbegrenzung. |
| Sicherer Einsatz | Eine Query-Store-Datenbank, ein enges UTC-Fenster, Status, Runtime und Replica-Kontext und `@MaxZeilen = 100`. Referenzdatenbankfilter sowie weitere Children erst nach einem konkreten Query-/Planbefund aktivieren. |
| Aussagegrenze | Zeitfilter und Retention bestimmen gemeinsam, was historisch sichtbar ist. Ein Top-N je Child kann unterschiedliche Queries zeigen; Planwechsel, Regression und Waits dürfen nur über Query-/Plan-ID plus Fenster korreliert werden, nicht über Zeilenposition. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Query-Store-Perspektiven sollen kontrolliert in einem Lauf ausgeführt werden?

### Technischer Hintergrund

Der Wrapper orchestriert Status, Runtime, Waits, PlanChanges, Regressions, Forced Plans, Hints, Replica-Kontext und IQP. Quellenauswahl und High-Impact-Bestätigung gehen an alle neun Teilmodule; Referenzdatenbankfilter nur an Runtime, Waits, PlanChanges, Regressions und Forced Plans. Beide Zeitgrenzen gehen an Runtime, Waits und Replica-Kontext; PlanChanges erhält nur VonUtc, Regressionen nutzen beide Grenzen als Vergleichsfenster. Status, Forced Plans, Hints und IQP erhalten kein Zeitfenster. Child-NULL-Werte und Defaults werden nicht global vereinheitlicht.

### Datenkette

Die Datenkette besteht aus frameworkinterner Orchestrierung; die Quellen liegen in den Childmodulen.

### Source Select

Kein einzelnes Grundselect wird verwendet. Die Procedure orchestriert Status, Runtime Stats, Wait Stats, Planwechsel, Regressionen, Forced Plans, Hints, Replica-Kontext und IQP. Alle ausgewählten Teilmodule lesen ihre Quellen separat; ihre Zeit-, Filter- und Statusverträge bleiben jeweils eigenständig.

**Wichtig für die Eigenlast:** Legen Sie Datenbank, Zeitfenster und benötigte Childmodule vor jeder Query-Store-Abfrage fest. Ein finales Ergebnislimit verhindert weder Interval-/Runtime-Joins noch Plan-XML-Auflösung in den Childpfaden.

### Zeit- und Scope-Modell

Die Auswertung führt Teilmodule nacheinander ohne atomare Gesamtaufnahme aus. Das Aufrufjournal gilt je Teilmodul; detaillierte Datenbank- und Quellenstatus stehen in dessen eigenen Ausgaben.

### Bewertung und Gegenprobe

Prüfen Sie zuerst den Status. Priorisieren Sie danach die Runtime und vertiefen Sie Wait, Plan, Regression und Intervention nur bei Bedarf. Deep-Optionen, Plan-XML und viele Datenbanken erhöhen die Kosten.

### Typische Fehlinterpretation

Ein Wrapperfenster kann für Regression als Comparison Window verwendet werden, während die Baseline davor abgeleitet wird. Führen Sie Resultsets nicht ohne Childnamen und Childstatus zusammen.

### Folgeanalyse

Führen Sie das betroffene Child gezielt erneut aus.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#9-monitorusp_querystoreanalysis)
Für einen in den Query-Store-Children ausgewählten Plan liefert
`USP_ExecutionPlanAnalysis` den gezielten DIAG-005-Vertrag mit
`queryStoreContext` und `feedbackAndVariants`. Dieser Folgepfad liest keinen
Querytext und behandelt persistierte Hint-/Feedbackpayloads nach dem
angeforderten Evidenzdatenschutzmodus.


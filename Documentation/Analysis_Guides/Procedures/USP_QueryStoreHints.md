# [monitor].[USP_QueryStoreHints]

**Bereich:** Query Store<br>
**Zweck:** Inventarisiert Query Store Hints, Herkunft und Anwendungsfehler.<br>
**Beobachtungsart:** persistierter Konfigurationsstand<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Query Store Hints greifen auf Queries ein, und schlagen sie fehl oder überdecken sie inzwischen bessere Optimizerentscheidungen?** Sie unterstützt die Entscheidung, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

`EXEC [monitor].[USP_QueryStoreHints] @Hilfe = 1;` beschreibt alle Parameter, Filter- und Ausgabeoptionen sowie Beispielaufrufe direkt in der Procedure.

```sql
EXEC [monitor].[USP_QueryStoreHints]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@QueryStoreDatabaseNames` | `nvarchar(max)` | `NULL` | Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]&#124;[OtherDatabase]'; &#124; trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen. |
| `@QueryStoreDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert. |
| `@HighImpactConfirmed` | `bit` | `0` | ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. In diesem Modul wird Deep ausschließlich bei normalisiertem Zeilenlimit &gt;1000, also auch NULL/0 unbegrenzt, zusätzlich geprüft. |
| `@QueryId` | `bigint` | `NULL` | Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch. |
| `@NurMitFehler` | `bit` | `0` | Ausgelassen/0: alle gespeicherten Hints. 1 oder NULL: nur Hints mit QueryHintFailureCount &gt; 0 ODER LastQueryHintFailureReason ungleich 0; NULL wird nicht auf 0 normalisiert, sondern wirkt durch SQL-Dreiwertlogik wie der Fehlerfilter. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@MaxZeilen` | `int` | `100` | Weglassen verwendet 100. NULL oder 0 bedeutet unbegrenzt; ein positiver Wert ist die globale Höchstzahl exportierter Zeilen. Pro Datenbank wird bei endlichem Limit lokal bis zu Limit+1 gelesen, anschließend wird global sortiert und begrenzt. Negative Werte liefern INVALID_PARAMETER. Wenn das normalisierte Limit &gt; 1000 ist, wird nach QUERY_STORE_CURRENT zusätzlich QUERY_STORE_DEEP geprüft; NULL/0 normalisieren auf unbegrenzt und lösen diese Prüfung ebenfalls aus. Bei int-Maximum 2147483647 wird lokal N ohne +1 verwendet. Ganze Zahlen von 1 bis 2147483647 sind positive Limits. Lokal und global werden Fehlergrund ungleich 0 zuerst, dann QueryHintFailureCount absteigend und QueryHintId aufsteigend gereiht. Hint-IDs sind quellenspezifisch, gleiche Sortwerte zwischen Quellen legen keine eindeutige Auswahl fest. Textprojektion, Warnungen und Zähler beziehen sich auf alle lokalen Kandidaten vor dem globalen Limit. |
| `@MaxSqlTextZeichen` | `int` | `4000` | Weglassen verwendet 4000 Zeichen. NULL oder 0 bedeutet unbegrenzten QuerySqlText; ein positiver Wert begrenzt nur den projizierten Querytext nach dem Einlesen und Join. QueryHintText wird nicht gekürzt; das Limit begrenzt weder die Quelllesung noch die Hinttextlänge. Negative Werte liefern INVALID_PARAMETER. Gekürzte Querytexte erhalten Längen-/Byte-/Truncationmetadaten; bei aktivierten Meldungen erscheint höchstens eine Kürzungswarnung. Als positive ganze Zahl bis 2147483647 übergeben. Unicode-SC-Zählung lässt Surrogatpaare zusammen und zählt keine Grapheme. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Weglassen verwendet CONSOLE. Zulässige feste Werte sind RAW, CONSOLE, TABLE und NONE; Groß-/Kleinschreibung wird ignoriert und äußere Leerzeichen werden entfernt. NULL sowie leerer/nur aus Leerzeichen bestehender Text und alle anderen Werte liefern INVALID_PARAMETER. CONSOLE gibt nur die fachliche Hint-Tabelle über den aktiven Console-Helper aus; RAW liefert Statusmetadaten, vollständige Exportdaten und Warnungen als Resultsets; TABLE schreibt das vollständige fachliche Exportset in das zugeordnete Ziel; NONE gibt keine Resultsets aus. Die Bindung an varchar(16) erfolgt vor der Prüfung; LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen. CONSOLE ergänzt bei nichtleerer Fachmenge das Ergebnislabel; bei Leere liefert es eine Hinweiszeile. JSON bleibt unabhängig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | außerhalb TABLE nur NULL, leer oder äußere U+0020-Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel queryHints und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema. |
| `@JsonErzeugen` | `bit` | `0` | Ausgelassen/0 oder NULL: kein JSON. 1 erzeugt @Json als Objekt mit meta (Metadaten), queryHints (globale Hint-Exportmenge) und warnings (Warnungen), unabhängig von @ResultSetArt. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung. |
| `@PrintMeldungen` | `bit` | `1` | ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |
| `@Hilfe` | `bit` | `0` | ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |

```sql
EXEC [monitor].[USP_QueryStoreHints] @Hilfe=1;
```

```sql
EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW';
```

```sql
DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
```

```sql
CREATE TABLE [#QueryStoreHints_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"queryHints":"#QueryStoreHints_HelpExample"}';
 SELECT * FROM [#QueryStoreHints_HelpExample];
 DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreHints_HelpExample];
 THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag ordnet das Resultset `queryHints` einem bereits vorhandenen, leeren lokalen #Temp-Ziel mit genau einer Seed-Spalte zu; die Procedure erstellt das Ziel nicht. CONSOLE gibt nur die fachliche Hint-Tabelle über den Console-Helper aus. RAW liefert Statusmetadaten, die vollständigen Exportdaten und Warnungen. JSON wird auf Wunsch als Ausgabeparameter `@Json` mit `meta`, `queryHints` und `warnings` zurückgegeben. TABLE schreibt die vollständigen Exportdaten in das zugeordnete Ziel.

RAW, CONSOLE, TABLE und JSON verwenden denselben global begrenzten Export mit 22 Feldern und neun expliziten Frameworktextcollations. `QuerySqlTextIsTruncated` ist NOT NULL; die übrigen 21 Felder einschließlich `QueryStoreDatabaseName` sind nullable. Keine Spalte ist eine Identity. NULL und 0 bei `@MaxZeilen` bleiben unbegrenzt; negative Zeilen- oder Textlimits liefern kontrolliert `INVALID_PARAMETER` mit leerem Export. NULL und 0 bei `@MaxSqlTextZeichen` erhalten den ungekürzten Querytext. Die Auswahl priorisiert einen Fehlergrund ungleich 0, danach `QueryHintFailureCount` absteigend und `QueryHintId` aufsteigend. Hint-IDs sind datenbanklokal; gleiche Sortwerte zwischen Datenbanken erlauben unterschiedliche gültige Auswahlen in getrennten Aufrufen. Innerhalb eines Aufrufs bleibt die exportierte Menge für alle Ausgabearten identisch.

Status, `hasMoreRows` und Truncationwarnungen entstehen vor der globalen Ausgabegrenze aus der lokal mit N+1 gesammelten Menge. Der Fehlerfilter bleibt unverändert: 0 umfasst alle Hints; 1 oder NULL behält nur positive Failurecounts oder einen Fehlergrund ungleich 0.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Query Store Hint für eine Query und gegebenenfalls Replica-Gruppe.

## So lesen

Berücksichtigen Sie Hinttext, Quelle, Failure Count/Reason, Queryidentität und letzte Relevanz gemeinsam.

## Warum kann das problematisch sein?

Ein Hint begrenzt Optimizerfreiheit und kann nach Daten-, Schema- oder Versionsänderungen schädlich werden.

## Wann ist es kein Problem?

Ein dokumentierter, getesteter Hint kann eine bewusste Maßnahme sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Fehlerfrei angewendet bedeutet nur „wirksam“, nicht „weiterhin nützlich“. Prüfen Sie Runtime, Regression, Plan Changes, Owner und Reviewdatum.

**Ähnlich aussehender Gegenfall:** Ein dokumentierter, getesteter Hint kann eine bewusste Maßnahme sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Eine leere Ausgabe bedeutet, dass im ausgewählten und gefilterten Datenbank-Scope keine Hintzeile exportiert wurde. Prüfen Sie die Datenbankauswahl, QueryId und Fehlerfilter; bei Teilstatus zusätzlich die ausgegebenen Warnungen und den Zugriffsstatus der ausgewählten Datenbanken. Diese Procedure wertet kein Zeitfenster aus.

Für `USP_QueryStoreHints` bedeutet **keine Zeile**, dass im sichtbaren und gefilterten Datenbank-Scope kein ausgabefähiger Hint exportiert wurde; der Fehlerfilter mit NULL lässt nur Hints mit positivem Failurecount oder Fehlergrund ungleich 0 durch. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. Ein partieller Status oder eine Warnung weist auf mindestens eine nicht lesbare oder fehlende Datenbankteilquelle hin. Ein globales Limit kann vorhandene Hintzeilen aus dem Export ausschließen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Alle sichtbaren online befindlichen Benutzerdatenbanken, TOP 100 und auf 4000 Zeichen gekürzter Querytext. Eine explizite `ExampleDatabase` begrenzt diesen Standardscope. Die Procedure liest Hinttext und Anwendungsfehler, aber weder Zeitfenster noch Plan XML. |
| Teuerster Pfad | Viele Datenbanken, unbegrenztes/hohes Limit und ungekürzte Hint-/Querytexte bei sehr vielen gespeicherten Query Store Hints. |
| Haupttreiber | Zahl gewählter Query Stores und vorhandener Hintzeilen samt zugehörigem Querytext. Ungekürzte Texte erhöhen die Ausgabebreite; Datenbankpattern begrenzen die ausgewählten Quellen; Runtimeintervalle und Plan-XML werden in diesem Inventarpfad nicht gelesen. |
| Skalierung | Aufwand wächst mit Hintzeilen, Query-/Textjoins und Datenbanken; ungekürzte Hint- und Querytexte erhöhen Arbeitsspeicher und Ergebnistransfer. |
| Ressourcen | Geringe bis mittlere Query-Store-I/O-/CPU-Last für Hint-/Query-/Textjoin und Ranking; keine Intervallaggregation oder XML-Verarbeitung. |
| Begrenzungswirkung | QueryId und Fehlerfilter wirken vor dem lokalen TOP N+1; danach wird global begrenzt. Das Zeichenlimit reduziert nur Querytextbreite, nicht Hinttext oder Quelllesung. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `QUERY_STORE_CURRENT`, `QUERY_STORE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, `@NurMitFehler = 1`, TOP 100 und gekürzter Text. Erst bei Bedarf alle Hints zeigen; >1000/unbegrenzt erfordert `QUERY_STORE_DEEP`. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierter Konfigurationsstand“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Query Store Hints greifen auf Queries ein, und schlagen sie fehl oder überdecken sie inzwischen bessere Optimizerentscheidungen?

### Technischer Hintergrund

Query Store Hints hängen an QueryId und injizieren unterstützte Queryoptionen ohne Textänderung. Source, Hinttext, Failure Reason/Count und Replica Group liefern Governance-/Fehlerkontext. Verfügbarkeit ist versionsabhängig.

### Datenkette

`sys.query_store_query`, `sys.query_store_query_hints`, `sys.query_store_query_text`, `sys.sp_executesql`.

### Source Select

Query Store Hints werden über `query_id` mit Query- und Textkatalog verbunden. LEFT JOIN erhält sichtbare Hintzeilen auch bei fehlendem Query- oder Textkontext; die zugehörigen Werte bleiben dann NULL:

```sql
SELECT
      [h].[query_id]
    , [h].[query_hint_text]
    , [h].[last_query_hint_failure_reason_desc]
    , [q].[object_id]
    , [qt].[query_sql_text]
FROM [sys].[query_store_query_hints] AS [h] WITH (NOLOCK)
LEFT JOIN [sys].[query_store_query] AS [q] WITH (NOLOCK)
  ON [q].[query_id] = [h].[query_id]
LEFT JOIN [sys].[query_store_query_text] AS [qt] WITH (NOLOCK)
  ON [qt].[query_text_id] = [q].[query_text_id]
WHERE @QueryId IS NULL OR [h].[query_id] = @QueryId;
```

**Wichtig für die Eigenlast:** Setzen Sie eine bekannte `query_id` vor der Textprojektion. Query Store Hints sind ab SQL Server 2022 verfügbar; fehlende Sicht oder Version wird als Status behandelt, nicht durch einen Ersatzscan kompensiert.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuell persistierten Hintbestand; `QueryId` ist datenbanklokal.

### Bewertung und Gegenprobe

Korrelieren Sie Hint, Zielquery, Failure Count, letzte Runtime, Planveränderung, Version/Compatibility und Begründung. Jede Intervention benötigt Owner, Reviewdatum und Rücknahmepfad.

### Typische Fehlinterpretation

Fehlerfrei bedeutet nicht sinnvoll. Nach Upgrade kann ein alter Hint Adaptive/IQP-Verbesserungen verhindern.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: RuntimeStats, Regressions, PlanChanges und Change-Dokumentation.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#7-monitorusp_querystorehints)

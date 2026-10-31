# [monitor].[USP_QueryStoreRegressions]

**Bereich:** Query Store<br>
**Zweck:** Vergleicht zwei Zeitfenster nach Dauer, CPU, Reads, Writes oder Ausführungen.<br>
**Beobachtungsart:** persistierte, retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Hat sich eine gewählte Metrik zwischen Baseline- und Vergleichsfenster belastbar verschlechtert?** Sie unterstützt die Entscheidung, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

`EXEC [monitor].[USP_QueryStoreRegressions] @Hilfe = 1;` beschreibt alle Parameter, Filter- und Ausgabeoptionen sowie Beispielaufrufe direkt in der Procedure.

```sql
EXEC [monitor].[USP_QueryStoreRegressions]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @MinAusfuehrungenJeFenster = 10,
      @MinRegressionProzent = 20,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@QueryStoreDatabaseNames` | `nvarchar(max)` | `NULL` | Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]&#124;[OtherDatabase]'; &#124; trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen. |
| `@QueryStoreDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert. |
| `@HighImpactConfirmed` | `bit` | `0` | ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |
| `@ReferencedDatabaseNames` | `nvarchar(max)` | `NULL` | ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; &#124; trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein; Teile 3/4 werden nicht gesondert geprüft. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus. |
| `@ReferencedDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert. |
| `@QueryId` | `bigint` | `NULL` | Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch. |
| `@QueryHash` | `binary(8)` | `NULL` | Ausgelassen/NULL: kein Hashfilter. Acht Byte als Binärwert übergeben, zum Beispiel 0x0123456789ABCDEF; exakter Vergleich ohne zusätzliche Werte- oder Existenzprüfung. SQL-Typkonvertierungen erfolgen vor dem Procedurekörper. |
| `@BaselineVonUtc` | `datetime2(7)` | `NULL` | Optionale UTC-Untergrenze des Baselinefensters. Jede gesetzte Grenze bleibt erhalten. Wenn NULL, wird eine Stunde vor @BaselineBisUtc berechnet; fehlt auch @BaselineBisUtc, ist dessen Default @VergleichVonUtc. Die Grenze muss vor @BaselineBisUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig. |
| `@BaselineBisUtc` | `datetime2(7)` | `NULL` | Optionale UTC-Obergrenze des Baselinefensters. Wenn NULL, gilt @VergleichVonUtc. Die Grenze muss nach @BaselineVonUtc liegen und darf nicht nach @VergleichVonUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig. |
| `@VergleichVonUtc` | `datetime2(7)` | `NULL` | Optionale UTC-Untergrenze des Vergleichsfensters. Wenn NULL, wird eine Stunde vor @VergleichBisUtc berechnet; wenn auch das Ende NULL ist, gilt zunächst jetzt in UTC. Die Grenze muss vor @VergleichBisUtc liegen. Baseline und Vergleich dürfen sich nicht überlappen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig. |
| `@VergleichBisUtc` | `datetime2(7)` | `NULL` | Optionale UTC-Obergrenze des Vergleichsfensters. Wenn NULL, gilt SYSUTCDATETIME() zum Aufruf. Jede gesetzte Grenze bleibt erhalten; aus den vier einzeln abgeleiteten Grenzen entsteht keine automatische Gleichlängenregel. Die Grenze muss nach @VergleichVonUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig. |
| `@Metrik` | `varchar(32)` | `'DURATION_AVG'` | NULL wird wie DURATION_AVG behandelt; außen getrimmt und in Großbuchstaben normalisiert. Zulässige geschlossene Werte: DURATION_AVG = ausführungsgewichtete durchschnittliche Dauer in ms je Ausführung; CPU_AVG = gewichtete durchschnittliche CPU-Zeit in ms je Ausführung; READS_AVG = gewichtete durchschnittliche logische Reads je Ausführung; WRITES_AVG = gewichtete durchschnittliche logische Writes je Ausführung; EXECUTIONS = Ausführungszahl im Fenster. Für Dauer/CPU werden Quellwerte in Mikrosekunden durch 1000 in ms umgerechnet. Es werden nur Queries mit Werten in beiden Fenstern und einer berechneten Änderung mindestens @MinRegressionProzent ausgegeben. Prozent = 100 × (Vergleich − Baseline) / ABS(Baseline); bei Baseline 0 ist der Prozentwert NULL und erfüllt den Mindestfilter nicht. Der Schwellenwert wird mit dem vor der Ausgabe-Rundung berechneten Float-Prozentwert verglichen; Baselinewert 0 ergibt durch NULLIF NULL und wird durch das WHERE-Prädikat ausgeschlossen. Maßgeblich ist der bei SQL-Bindung auf die deklarierte Typbreite zugewiesene Wert; LTRIM/RTRIM entfernt äußere U+0020-Leerzeichen. Leer, nur U+0020 oder andere Werte sind im normalen Analysepfad ungültig. |
| `@MinAusfuehrungenJeFenster` | `bigint` | `1` | Mindestzahl der Ausführungen in jedem der beiden Fenster; Werte kleiner 1 sind ungültig. SQL-Prädikate filtern je Fenster vor dem Vergleich. NULL führt nicht pauschal zu INVALID_PARAMETER, erfüllt aber den Mindestvergleich nicht und ergibt damit keine Regressionstreffer. Als ganze Zahl von 1 bis 9223372036854775807 übergeben. |
| `@MinRegressionProzent` | `decimal(9,2)` | `20.0` | Mindestwert für die prozentuale Änderung der ausgewählten Metrik, verglichen mit 100 × (Vergleich − Baseline) / ABS(Baseline). Negative Werte sind ungültig. NULL ist kein allgemeiner Parameterfehler, lässt das SQL-Schwellenprädikat aber UNKNOWN werden und liefert daher keine Regressionstreffer. Als dezimalen Zahlenwert von 0.00 bis 9999999.99 übergeben, zum Beispiel 20.00. Zuweisung an decimal(9,2) erfolgt vor der Prüfung und kann zusätzliche Nachkommastellen runden. |
| `@AnalyseModus` | `varchar(16)` | `'TOP'` | NULL wird wie TOP behandelt; außen getrimmt und großgeschrieben. Geschlossene Optionen: TOP nutzt den rangbegrenzten lokalen Kandidatenpfad je Quelle; VOLL aktiviert den Deep-Check. Beide liefern weiterhin nur die nach Kriterien berechneten Regressionen. Maßgeblich ist der bei SQL-Bindung auf die deklarierte Typbreite zugewiesene Wert; LTRIM/RTRIM entfernt äußere U+0020-Leerzeichen. VOLL hebt das Zeilenlimit nicht auf. Leer, nur U+0020 oder andere Werte sind ungültig. |
| `@MaxZeilen` | `int` | `100` | Globale Ausgabegrenze nach lokaler N+1-Kandidatensammlung je Quelle, Textprojektion, Truncationwarnung und Mengen-/Statuszählung. Positiver Wert begrenzt die abschließende, global nach RegressionPercent DESC und AbsoluteChange DESC sortierte Exportmenge; Gleichstände bestimmen keine eindeutige Auswahl. NULL oder 0 bedeutet unbegrenzt. Negative Werte sind ungültig. Der lokale TOP ist bei positivem Wert höchstens @MaxZeilen+1 (bei int-Maximalwert ohne Addition); er begrenzt nicht pauschal alle gelesenen Query-Store-Runtimezeilen. @Limit &gt; 1000 aktiviert QUERY_STORE_DEEP; bei NULL/0 ist das Limit maximal und Deep daher aktiv. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben. |
| `@MaxSqlTextZeichen` | `int` | `4000` | Begrenzt die projizierte Länge von QuerySqlText in den lokal gesammelten Ergebnissen. NULL oder 0 bedeutet unbegrenzt; negative Werte sind ungültig. Projektion und Truncationmetadaten/-warnung werden vor der abschließenden globalen @MaxZeilen-Ausgabegrenze berechnet; die Begrenzung spart daher nicht die vorherige Quellaggregation. Die Unicode-Projektion zählt Zeichen mit SC-Collation und schneidet Surrogatpaare nicht auseinander. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Ausgelassen: CONSOLE. Nach U+0020-Trim/Großschreibung sind genau vier Werte erlaubt: RAW liefert drei Resultsets (Metadaten, regressions, Warnungen); CONSOLE liefert die fachliche Exportmenge mit Ergebnislabel oder bei Leere eine Hinweiszeile, ohne zusätzliche Metadaten-/Warnungsgrids; TABLE schreibt nur regressions ins geprüfte lokale Temp-Ziel; NONE unterdrückt normale Fachresultsets. JSON ist unabhängig. NULL, leer, nur Leerzeichen und andere Werte sind im normalen Analysepfad ungültig. Der TABLE-Preflight liegt vor Hilfe und Fachvalidierung. Der Eingabewert unterliegt der varchar(16)-Bindungsbreite. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | außerhalb TABLE nur NULL, leer oder Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel regressions und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema. |
| `@JsonErzeugen` | `bit` | `0` | Steuert unabhängig von @ResultSetArt, ob JSON in @Json aufgebaut wird. SQL-bit-Konvertierung: numerische Eingaben ungleich 0 werden 1, 0 wird 0; NULL erzeugt kein JSON. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung. |
| `@PrintMeldungen` | `bit` | `1` | ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |
| `@Hilfe` | `bit` | `0` | ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |

```sql
EXEC [monitor].[USP_QueryStoreRegressions] @Hilfe=1;
```

```sql
EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW';
```

```sql
DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
```

```sql
CREATE TABLE [#QueryStoreRegressions_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"regressions":"#QueryStoreRegressions_HelpExample"}';
 SELECT * FROM [#QueryStoreRegressions_HelpExample];
 DROP TABLE IF EXISTS [#QueryStoreRegressions_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreRegressions_HelpExample];
 THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `regressions`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

RAW, CONSOLE, TABLE und JSON lesen dieselbe spät materialisierte Exportmenge mit 25 Feldern und sieben expliziten Textcollations `SQL_Latin1_General_CP1_CS_AS`. `QueryStoreDatabaseName` und `QuerySqlTextIsTruncated` sind NOT NULL; die übrigen 23 Felder sind nullable. Der Export besitzt keine Identity. Das globale Limit wird einmal nach SQL-Textprojektion, Truncationwarnung, N+1-Zählung und Statusbewertung angewandt. NULL und 0 bei `@MaxZeilen` bleiben unbegrenzt. Die bestehende Sortierung verwendet `RegressionPercent DESC, AbsoluteChange DESC`; gleiche Sortwerte legen keine eindeutige Auswahl zwischen getrennten Aufrufen fest.

Status, `hasMoreRows` und Truncationwarnungen stammen weiterhin aus der vollständig lokal mit N+1 gesammelten Menge. Die Ausgabegrenze verändert diese Bewertung nicht. Negative Zeilen- oder Textlimits liefern kontrolliert `INVALID_PARAMETER` mit leerem Export. NULL und 0 beim Textlimit lassen den Text vollständig; NULL bei einem Mindestfilter liefert nach dem bestehenden SQL-Prädikat eine leere fachliche Menge, ohne daraus einen Parameterfehler abzuleiten. Die vorhandene Auswahl- und Quellenfehlerbehandlung bleibt erhalten; eine fehlende Auswahl erhält keine zusätzliche Warningzeile.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Query mit aggregierter Baseline und aggregiertem Vergleichsfenster. Sie ist kein Vergleich zweier Einzelaufrufe.

## So lesen

Berücksichtigen Sie Fenstergrenzen, Ausführungsanzahl, absolute Werte, Plananzahl und Prozentänderung gemeinsam.

## Warum kann das problematisch sein?

Bei DURATION_AVG, CPU_AVG, READS_AVG und WRITES_AVG zeigt ein höherer Wert mehr Zeit beziehungsweise logische Zugriffe je Ausführung im gefilterten Vergleich. EXECUTIONS misst dagegen eine höhere Ausführungszahl; das kann ein Lastanstieg ohne schlechtere Queryeffizienz sein. Vergleichbarer Workload und eine ausreichende Stichprobe müssen gesondert geprüft werden.

## Wann ist es kein Problem?

Große Prozentwerte bei sehr kleiner Stichprobe können durch Parameter, Datenmenge oder Zufall entstehen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 100 ms → 150 ms bei je 100.000 Ausführungen: belastbare 50-%-Regression. 1 ms → 10 ms bei je einer Ausführung: 900 %, aber schwache Evidenz.

**Bisher dokumentierter Folgeschritt:** Verwenden Sie Plan Changes, Wait Stats und konkrete Parameter-/Plananalyse. Keine automatische Plan-Forcing-Entscheidung.

**Ähnlich aussehender Gegenfall:** Große Prozentwerte bei sehr kleiner Stichprobe können durch Parameter, Datenmenge oder Zufall entstehen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Query Store kann nutzbar sein, obwohl das gewählte Fenster leer ist. Prüfen Sie zuerst Capturemodus, Read-only-Status, Retention und UTC-Fenster.

Für `USP_QueryStoreRegressions` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Ohne exakten Datenbankfilter werden alle sichtbaren geeigneten Online-Benutzerdatenbanken geprüft; zwei aufeinanderfolgende Stunden, TOP 100 und kein Referenzdatenbankfilter. Der sichere Beispielaufruf begrenzt diese Auswahl ausdrücklich auf `ExampleDatabase`. |
| Teuerster Pfad | Viele Datenbanken, `VOLL`/unbegrenztes Limit, `DATEDIFF(HOUR,@BaselineVonUtc,@VergleichBisUtc)>24` und Referenzdatenbank-/Regexfilter; dafür wird gespeichertes Showplan-XML intern zerlegt. |
| Haupttreiber | Zahl gewählter Query Stores, Runtimeintervalle und Query-/Plan-Kombinationen in beiden Vergleichsfenstern. Ein Referenzdatenbankfilter kann zusätzlich gespeicherte Showplan-XML laden und zerlegen, bevor die Regressionen rangiert werden. |
| Skalierung | Zwei Fenster müssen je Query/Plan aggregiert und verglichen werden; Aufwand wächst mit Intervallen, Queries, Datenbanken und Gesamtspanne. Referenzfilter addieren Plan-XML-Parsing. |
| Ressourcen | Query-Store-I/O, CPU/TempDB für zwei Aggregationen, Join und Regressionranking; SQL-Texttransfer sowie optional XML-CPU für Referenzobjektfilter. |
| Begrenzungswirkung | Fenster, QueryId/-Hash und Mindestexecutions reduzieren Quell-/Ergebnisarbeit. N+1/Global-TOP greifen erst nach beiden Fensteraggregationen und begrenzen die zuvor gelesenen Runtimezeilen nicht. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `QUERY_STORE_CURRENT`, `QUERY_STORE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, gleichartige kurze Fenster und TOP 100; Queryfilter bevorzugen. `DATEDIFF(HOUR,@BaselineVonUtc,@VergleichBisUtc)>24`, `VOLL`, Referenzfilter oder >1000/unbegrenzt nur nach Deep-Gate. DATEDIFF zählt überschrittene Stundengrenzen; dies ist keine Prüfung der exakten verstrichenen Dauer. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierte, retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Hat sich eine gewählte Metrik zwischen Baseline- und Vergleichsfenster belastbar verschlechtert?

### Technischer Hintergrund

Die Procedure aggregiert zwei nicht überlappende Zeiträume und vergleicht Duration, CPU, Reads, Writes oder Executions. Prozentänderung teilt die absolute Änderung durch den Baselinewert; Baseline nahe null macht Prozent instabil. Intervalle können Fenstergrenzen überlappen.

### Datenkette

`sys.database_query_store_options`, `sys.objects`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.query_store_runtime_stats`, `sys.query_store_runtime_stats_interval`, `sys.schemas`, `sys.sp_executesql`.

### Source Select

Der kostenbestimmende Join verbindet Runtime-Statistik, Intervall, Plan und Query; beide Vergleichsfenster müssen früh begrenzt werden:

```sql
SELECT
      [q].[query_id]
    , [p].[plan_id]
    , [i].[start_time]
    , [i].[end_time]
    , [rs].[count_executions]
    , [rs].[avg_duration]
    , [rs].[avg_cpu_time]
    , [rs].[avg_logical_io_reads]
FROM [sys].[query_store_runtime_stats] AS [rs] WITH (NOLOCK)
JOIN [sys].[query_store_runtime_stats_interval] AS [i] WITH (NOLOCK)
  ON [i].[runtime_stats_interval_id] = [rs].[runtime_stats_interval_id]
JOIN [sys].[query_store_plan] AS [p] WITH (NOLOCK)
  ON [p].[plan_id] = [rs].[plan_id]
JOIN [sys].[query_store_query] AS [q] WITH (NOLOCK)
  ON [q].[query_id] = [p].[query_id]
WHERE ([i].[end_time] > @BaselineVonUtc AND [i].[start_time] < @BaselineBisUtc)
   OR ([i].[end_time] > @VergleichVonUtc AND [i].[start_time] < @VergleichBisUtc);
```

Der tatsächliche Quellpfad verbindet zusätzlich `sys.query_store_query_text`. Nach der Fensteraggregation wird der Modulbezug über `LEFT JOIN sys.objects` und `LEFT JOIN sys.schemas` aufgelöst; ein nicht auflösbarer Objektname bleibt NULL.

**Wichtig für die Eigenlast:** Setzen Sie Baseline- und Vergleichsfenster sowie Datenbank vor Aggregation, Ranking und SQL-Text. `@MaxZeilen` wirkt erst nach dem Vergleich und spart die Interval-Joins nicht.

### Zeit- und Scope-Modell

Exakte `@ReferencedDatabaseNames` werden mit dem Parser der Frameworkdatenbank geprüft und in den dynamischen Quellabfragen über dessen dreigliedrigen Namen aufgelöst. Der Frameworkname wird vor `USE` aus `master.sys.databases` mit `NOLOCK` gelesen und mit `QUOTENAME` geschützt. Die Liste filtert Datenbankreferenzen im Showplan, nicht die Query-Store-Quelldatenbanken. `NULL` lässt diesen Referenzfilter weg; eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Gültige doppelte Namen bleiben erlaubt und vervielfachen wegen `EXISTS` keine Zeilen. Die dekodierten XML-Namen werden weiterhin mit der expliziten Framework-CS-Collation verglichen; LIKE- und Regexpfade behalten ihre bisherigen Verträge.

Die Auswertung vergleicht zwei persistierte Query-Store-Fenster innerhalb der Retention; der Standardvergleich und die abgeleitete Baseline müssen im Wrapperkontext dokumentiert sein.

Ein Runtimeintervall wird anhand seiner Start-/Endgrenzen jedem überlappenden Fenster zugeordnet. Die enthaltenen Ausführungen werden nicht anteilig auf scharfe Fenstergrenzen umgerechnet. Ausführungszahlen und gewichtete Messwerte werden je Query/Fenster summiert; Duration und CPU werden anschließend von Mikrosekunden in Millisekunden umgerechnet. Plananzahlen zählen unterschiedliche PlanIds im jeweiligen Fenster. Ein Zeitfilter auf `last_execution_time` ersetzt dieses Intervallmodell nicht.

### Bewertung und Gegenprobe

Berücksichtigen Sie Baseline/Comparison Executions, PlanCount, absolute Änderung, Prozent, Datenvolumen und Workloadmix gemeinsam. Erhöhen Sie Mindestexecutionzahl passend zur Workload.

### Typische Fehlinterpretation

900 Prozent bei je einer Ausführung ist schwache Evidenz. Geänderte Parameter-/Datenmengen können Effizienz- statt Planregression vortäuschen.

### Folgeanalyse

Verwenden Sie für die weitere Analyse PlanChanges, WaitStats, RuntimeStats und Showplan. Erzwingen Sie einen Plan nicht ohne fachliche Prüfung.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#5-monitorusp_querystoreregressions)

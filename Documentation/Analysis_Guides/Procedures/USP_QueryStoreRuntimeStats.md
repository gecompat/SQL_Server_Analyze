# [monitor].[USP_QueryStoreRuntimeStats]

**Bereich:** Query Store<br>
**Zweck:** Aggregiert historische Laufzeit- und Ressourcenwerte je Query und Plan über Query-Store-Intervalle.<br>
**Beobachtungsart:** persistierte, retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Query-/Plan-Kombinationen verursachten im gewählten historischen Fenster Ausführungen, Dauer, CPU, I/O, Memory, TempDB oder Loglast?** Sie unterstützt die Entscheidung, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

EXEC [monitor].[USP_QueryStoreRuntimeStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @VonUtc = @ExampleVonUtc,
      @BisUtc = @ExampleBisUtc,
      @Sortierung = 'CPU_TOTAL',
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@QueryStoreDatabaseNames` | `nvarchar(max)` | `NULL` | Im normalen Analysepfad: Gibt exakte Query-Store-Quelldatenbanken als bracket-aware Pipe-Liste an; jedes Element ist ein einteiliger SQL-Name. Pipe trennt außerhalb von [...], ]] maskiert dort eine schließende Klammer, Rand-Leerzeichen je Element werden entfernt. Ausgelassen oder NULL sowie N'' oder nur äußere Leerzeichen: keine Namenseinschränkung, also alle sichtbaren geeigneten Online-Benutzerdatenbanken. Nichtleere Liste: ungültige Elemente und doppelte gültige Namen ergeben INVALID_PARAMETER; Liste und @QueryStoreDatabaseNamePattern dürfen nicht gleichzeitig aktiv sein. Dies filtert Quell-Datenbanken, nicht Showplan-Referenzen. Ausgelassen gilt der deklarierte Default NULL. Die tatsächliche Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und höchstens 128 Zeichen für Teil 1; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. |
| `@QueryStoreDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Im normalen Analysepfad: Alternativer Patternfilter für Query-Store-Quelldatenbanken. NULL: kein Pattern. Äußere Leerzeichen werden getrimmt; optionale Präfixe LIKE/Regex werden ohne Beachtung der Großschreibung erkannt, der Patternwert danach nicht erneut getrimmt. Unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE; regex: case-sensitive (Flag c); regexi: case-insensitive (Flag i). Leer/U+0020-Leerzeichen und leeres Präfixergebnis sind ungültig. Nicht-NULL Pattern und wirksame exakte Quellliste schließen einander aus. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; der Auswahlhelfer führt den Regexfilter dort auf Kandidatennamen aus. Dies ist nicht die spätere Regexprüfung je Query-Store-Quelldatenbank. Filtert keine Showplan-Referenzen. Ausgelassen gilt der deklarierte Default NULL. LIKE verwendet %, _ und Zeichenklassen [...]. Präfix- und Eingabeformat sind Textwerte, zum Beispiel N'like:App%'; nach Präfixentfernung bleiben Inhalt und Groß-/Kleinschreibung erhalten. |
| `@HighImpactConfirmed` | `bit` | `0` | Im normalen Auswahlpfad: Bestätigt einen tatsächlich aktivierten High-Impact-Pfad mit 1. NULL ist INVALID_PARAMETER durch 083, unabhängig davon, ob die Analyseklasse ein Gruppengate verlangt; 0 lässt Bestätigung aus. QUERY_STORE_CURRENT verlangt derzeit kein Gruppengate; QUERY_STORE_DEEP hat RequiresGroupGate=1. Bestätigung aktiviert Deep nicht und gewährt keine Gruppen- oder SQL-Berechtigung; Freigabe und Rechte werden getrennt geprüft. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@ReferencedDatabaseNames` | `nvarchar(max)` | `NULL` | Im normalen Analysepfad: Filtert Querys anhand einteiliger Namen in gespeicherten Showplans, nicht die Quell-Datenbanken. NULL/ausgelassen: kein Referenzfilter. Nicht-NULL muss eine gültige bracket-aware Pipe-Liste sein; N''/nur Leerzeichen und ungültige Parserwerte sind INVALID_PARAMETER. Gültige Duplikate sind zulässig; EXISTS vervielfacht Treffer nicht. Exakte Liste und @ReferencedDatabaseNamePattern dürfen nicht gleichzeitig non-NULL sein. Jedes gesetzte Referenzlistenfilter ist Deep und erfordert gespeicherte Showplan-XML. Ausgelassen gilt der deklarierte Default NULL. Die tatsächliche Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und höchstens 128 Zeichen für Teil 1; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. |
| `@ReferencedDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Im normalen Analysepfad: Filtert nach in gespeicherten Showplans referenzierten Datenbanknamen; keine Quell-DB-Auswahl. NULL: kein Pattern. Unpräfigiert oder like: case-sensitive LIKE; regex: case-sensitive mit Flag c; regexi: case-insensitive mit Flag i. Äußere Leerzeichen werden vor Präfixerkennung getrimmt, danach der Inhalt nicht erneut. Leer/U+0020-Leerzeichen oder leeres Präfixergebnis ungültig. Jeder gesetzte Referenzpatternwert ist exklusiv zu @ReferencedDatabaseNames und löst Deep aus. Regex benötigt SQL Server 2025 und Compatibility Level 170 je Quelldatenbank. Ausgelassen gilt der deklarierte Default NULL. LIKE verwendet %, _ und Zeichenklassen [...]. Präfix- und Eingabeformat sind Textwerte, zum Beispiel N'like:App%'; nach Präfixentfernung bleiben Inhalt und Groß-/Kleinschreibung erhalten. |
| `@QueryId` | `bigint` | `NULL` | Filtert auf die exakte QueryId in jeder gewählten Query-Store-Quelldatenbank. NULL/ausgelassen: kein QueryId-Filter. Jeder signed-bigint-Wert ist zulässig; keine zusätzliche Positivitätsprüfung. Wirkung bleibt auf Quellen, Zeitfenster und übrige Filter beschränkt. |
| `@QueryHash` | `binary(8)` | `NULL` | Filtert exakt auf den 8-Byte-QueryHash. NULL/ausgelassen: kein Hashfilter. Der Wert muss zu binary(8) konvertierbar sein; Hexwerte als 0x plus 16 Hexziffern angeben. Hash ersetzt nicht die Identität aus Quelldatenbank und QueryId. |
| `@TextPattern` | `nvarchar(4000)` | `NULL` | Im normalen Analysepfad: Filtert den gespeicherten SQL-Text. NULL/ausgelassen: kein Filter. Unpräfigiert oder like: SQL-LIKE unter expliziter case-sensitive Framework-Collation; regex: case-sensitive Regex (Flag c); regexi: case-insensitive Regex (Flag i). Präfixerkennung case-insensitive; äußere Leerzeichen werden zuerst getrimmt, nach Präfixentfernung der Wert nicht erneut. Leerer/U+0020-Leerzeichen Wert oder leeres Präfixergebnis ungültig. Regex benötigt SQL Server 2025 und Compatibility Level 170 in jeder Quelldatenbank und aktiviert Deep; unpassende Quelle wird als unavailable/partial gemeldet. Ausgelassen gilt der deklarierte Default NULL. LIKE verwendet %, _ und Zeichenklassen [...]. Präfix- und Eingabeformat sind Textwerte, zum Beispiel N'like:App%'; nach Präfixentfernung bleiben Inhalt und Groß-/Kleinschreibung erhalten. |
| `@VonUtc` | `datetime2(7)` | `NULL` | Im normalen Analysepfad: UTC-Untergrenze; caller liefert UTC, datetime2 hat keinen Offset und es erfolgt keine Zeitzonenkonvertierung. NULL wird nach Auflösung von @BisUtc auf BisUtc minus eine Stunde gesetzt. Erforderlich ist VonUtc &lt; BisUtc; Gleichheit oder größer ist ungültig. Intervalle werden bei end_time &gt; VonUtc und start_time &lt; BisUtc vollständig berücksichtigt, ohne anteilige Kürzung; gemeldete Execution-Zeiten können außerhalb des Fensters liegen. Ausgelassen gilt der deklarierte Default NULL. Übergabeform zum Beispiel '2026-01-01T12:00:00.0000000' als UTC-datetime2(7); kein Offset wird umgerechnet. Ist @VonUtc NULL, muss das effektive Ende mindestens 0001-01-01T01:00:00.0000000 betragen, damit DATEADD eine Stunde abziehen kann. Frühere Endwerte können vor der normalen Fachvalidierung ungefangen überlaufen. Vollständig gesetzte gültige Grenzen bleiben zulässig. |
| `@BisUtc` | `datetime2(7)` | `NULL` | UTC-Obergrenze; caller liefert UTC ohne Offsetkonvertierung. NULL/ausgelassen wird zu SYSUTCDATETIME() aufgelöst; zugleich NULLes @VonUtc ergibt eine Stunde Fenster. Muss größer als @VonUtc sein. Mit end_time &gt; VonUtc und start_time &lt; BisUtc schneiden Intervalle das Fenster; sie werden vollständig und nicht anteilig einbezogen. Ausgelassen gilt der deklarierte Default NULL. Übergabeform zum Beispiel '2026-01-01T12:00:00.0000000' als UTC-datetime2(7); kein Offset wird umgerechnet. Ist @VonUtc NULL, muss das effektive Ende mindestens 0001-01-01T01:00:00.0000000 betragen, damit DATEADD eine Stunde abziehen kann. Frühere Endwerte können vor der normalen Fachvalidierung ungefangen überlaufen. Vollständig gesetzte gültige Grenzen bleiben zulässig. |
| `@Sortierung` | `varchar(32)` | `'CPU_TOTAL'` | Im normalen Analysepfad: Werte werden getrimmt und großgeschrieben; NULL/ausgelassen wird CPU_TOTAL, leer oder unbekannt ist ungültig. Geschlossene Wertemenge mit tatsächlichem Rank-Ausdruck, jeweils DESC: CPU_TOTAL=TotalCpuMs (gesamte CPU ms); DURATION_TOTAL=TotalDurationMs (Gesamtdauer ms); READS_TOTAL=TotalLogicalReads (aggregierte logische Lesezugriffe); WRITES_TOTAL=TotalLogicalWrites (aggregierte logische Schreibzugriffe); EXECUTIONS=ExecutionCount (Ausführungsanzahl); MEMORY_MAX=MaxMemoryGrantKb (größter beobachteter Query-Speicherwert in KB); TEMPDB_TOTAL=TotalTempdbKb (aggregierte TempDB-Menge in KB); LOG_BYTES_TOTAL=TotalLogBytes (aggregierte Logbytes); LAST_EXECUTION=LastExecutionTimeUtc (letzte Ausführung). Im globalen Ranking folgen letzter Ausführungszeitpunkt DESC, Query-Store-Datenbankname, QueryId und PlanId; lokal wird nach Rang und gegebenenfalls letztem Ausführungszeitpunkt geordnet. Bestimmt den globalen Ausschnitt; RAW und JSON ordnen ausdrücklich. Für TABLE und die aktive CONSOLE besteht keine zusätzliche physische Reihenfolgegarantie. Ausgelassen gilt der deklarierte Default 'CPU_TOTAL'. Maßgeblich ist der bereits an varchar(32) zugewiesene Wert; eine längere Textangabe kann davor auf die Typbreite gekürzt werden. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen. |
| `@AnalyseModus` | `varchar(16)` | `'TOP'` | Im normalen Analysepfad: Werte werden getrimmt und großgeschrieben; NULL/ausgelassen wird TOP. Geschlossene Menge: TOP ist der Standard-Rankingpfad und fordert allein keinen Deep-Pfad an; VOLL aktiviert QUERY_STORE_DEEP und dessen High-Impact-/Zugriffsgate, hebt aber nicht das Zeilenlimit auf. Leer/unbekannt ist ungültig. Unabhängige Deep-Auslöser: MitPlanXml=1, effektives MaxZeilen &gt;1000, DATEDIFF(HOUR,VonUtc,BisUtc)&gt;24, nicht-NULL Referenznamen/-pattern oder Querytext-REGEX/REGEXI. Ausgelassen gilt der deklarierte Default 'TOP'. Maßgeblich ist der bereits an varchar(16) zugewiesene Wert; eine längere Textangabe kann davor auf die Typbreite gekürzt werden. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen. |
| `@MaxZeilen` | `int` | `100` | Im normalen Analysepfad: Globales Ergebnislimit nach lokalem Ranking. Ausgelassen: 100; NULL/0 unbegrenzt; positiver int 1 bis 2147483647 begrenzt; negative Werte INVALID_PARAMETER. Je Quelle werden höchstens N+1 lokale Kandidaten gelesen, außer int-Maximum verwendet N; NULL/0 nutzt unbegrenzte lokale Kandidaten. Nach Quellenaggregation/-sortierung folgen Textprojektion, Plan-XML-Parsing, Warnungen und Zähler für alle Kandidaten vor dem globalen TOP. Effektives Limit &gt;1000 sowie unbegrenzt (NULL/0) aktivieren Deep. ResultLimited/hasMoreRows zeigt global abgeschnittene Treffer an. |
| `@MitPlanXml` | `bit` | `0` | Nur genau 1 aktiviert Planausgabe und XML-Parsen gespeicherter Plantexte für ausgewählte Kandidaten und löst Deep aus. 0 unterdrückt Planausgabe und XML-Parsen, QueryPlan bleibt NULL und QueryPlanStatus wird NOT_REQUESTED. NULL aktiviert weder Planausgabe/XML-Parsen noch Deep, erhält aber durch den Status-CASE PENDING statt NOT_REQUESTED. Nur bei 1 werden Plantexte tatsächlich geparst; XML-Inhalt kann AVAILABLE/XML_EMPTY/SOURCE_NULL oder Fehlerstatus liefern. Erhöht Quell- und Parseaufwand. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. Der Quell-CTE referenziert und gruppiert den gespeicherten Plantexteintrag unabhängig vom Schalter; 0 oder NULL garantiert deshalb keine Vermeidung nativer Plantexte-Zugriffe. |
| `@MaxSqlTextZeichen` | `int` | `4000` | Im normalen Analysepfad: Maximale exportierte SQL-Textlänge je Treffer. Default 4000; NULL/0: vollständig; positiv: Grenze in Unicode-Zeichen unter SC-Collation, Surrogatpaar zählt als ein Zeichen und wird nicht geteilt; Graphemcluster werden nicht gezählt. Negativ ist INVALID_PARAMETER. QuerySqlTextCharacters/QuerySqlTextBytes bleiben verfügbar und QuerySqlTextIsTruncated kennzeichnet Kürzung. Eine zusammengefasste Warnung wird bei Kürzung nur mit @PrintMeldungen=1 ausgegeben. Die Grenze projiziert nach Materialisierung des Quelltexts. Ausgelassen gilt der deklarierte Default 4000. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Im normalen Analysepfad: Werte werden getrimmt und großgeschrieben, daher case-insensitiv. Geschlossene Menge: CONSOLE formatiert nur die fachliche Exportmenge oder bei Leere einen Hinweis; RAW liefert drei technische Resultsets (Metadaten, runtimeStats, Warnungen); TABLE schreibt nur runtimeStats ins benannte Ziel und unterdrückt Grids; NONE unterdrückt Resultsetgrids. JSON über @JsonErzeugen/@Json ist unabhängig davon. Nur TABLE erlaubt nichtleeres @ResultTablesJson. TABLE verlangt eine gültige Zuordnung und bestehende leere lokale #Temp-Zieltabelle mit genau einer beliebigen Seed-Spalte; Helper-Preflight erfolgt vor fachlichem Zugriff. NULL wird zu leer und ist wie leer/unbekannt ungültig. Ausgelassen gilt der deklarierte Default 'CONSOLE'. Maßgeblich ist der bereits an varchar(16) zugewiesene Wert; eine längere Textangabe kann davor auf die Typbreite gekürzt werden. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | JSON-Zuordnung für das einzelne TABLE-Resultset runtimeStats. Bei TABLE ist ein gültiges nichtleeres JSON-Objekt erforderlich; NULL/ausgelassen, leer/U+0020-Leerzeichen oder ungültiges JSON schlägt den Preflight fehl. Das Objekt muss genau den Schlüssel runtimeStats auf ein vorhandenes, eindeutiges lokales #Temp-Ziel abbilden; unbekannte/doppelte Namen oder Ziele sind ungültig. Ziel muss bereits existieren und leer sein, mit genau einer beliebigen Seed-Spalte; es braucht nicht die volle RuntimeStats-Zielstruktur. Preflight vor fachlichen Datenquellen. Nichtleeres Mapping ausschließlich mit TABLE; für andere ResultSetArt wird es vor dem fachlichen Zugriff abgewiesen. Ausgelassen gilt der deklarierte Default NULL. Schlüssel werden binär einschließlich Groß-/Kleinschreibung verglichen; doppelte Schlüssel sind ungültig. Zielnamen sind Strings mit LEN höchstens 116, beginnen mit #, aber nicht ## oder case-insensitiv #Monitor; doppelte Ziele werden case-insensitiv abgewiesen. Die einzelne Seed-Spalte hat einen beliebigen Namen und Typ; eine Seed-Zeile ist nicht zulässig. Sowohl diese TABLE-Vorprüfung als auch die Ablehnung eines nichtleeren Mappings außerhalb TABLE liegen vor dem Hilfezweig. |
| `@JsonErzeugen` | `bit` | `0` | Nur genau 1 baut @Json als Objekt mit meta, runtimeStats und warnings. 0 oder NULL erzeugt kein JSON; der Parameter ist nicht abhängig von @ResultSetArt, daher auch mit NONE möglich. Die JSON-Daten reflektieren die gemeinsame Exportmenge, Sortierung und globale Begrenzung. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionale OUTPUT-Bindung zum Empfang des JSON. Beim Procedure-Eintritt wird der Ausgabewert immer auf NULL zurückgesetzt; ohne callerseitige OUTPUT-Bindung gibt es keinen empfangenen Wert. Nur mit @JsonErzeugen=1 wird das meta/runtimeStats/warnings-Objekt zugewiesen; ansonsten bleibt NULL. Im EXEC-Aufruf muss auch die empfangende Variable mit OUTPUT gebunden werden. Ausgelassen gilt der deklarierte Default NULL. Der Eingabewert dient nicht als Steuerwert; bei Hilfe bleibt der intern zurückgesetzte Wert NULL. Bei vorzeitigem THROW ist kein übernommener OUTPUT zugesichert. |
| `@PrintMeldungen` | `bit` | `1` | Steuert Severity-10-Meldungen, nicht Warning-Datensätze oder JSON. Default/1: erlaubte Quellenfehler und Truncationwarnung werden als Meldungen ausgegeben. 0/NULL: Meldungen unterdrückt; Fehler-/Warning-Daten in RAW und JSON warnings bleiben erhalten; die aktive CONSOLE hat kein separates Warnungsresultset. Nur genau 1 aktiviert die Meldungsausgabe. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. |
| `@Hilfe` | `bit` | `0` | Genau 1 druckt integrierte Parameterhilfe via PRINT und kehrt unmittelbar zurück, vor Zeitauflösung, Datenbankkandidaten, fachlichen Quellen und Ausgabe. Default/0 führt Analyse aus; NULL löst den Hilfezweig nicht aus. Hilfe erzeugt keine fachlichen Resultsets. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. Die nichtleere Mappingzuordnung außerhalb TABLE wird ebenso wie der TABLE-Zielpreflight bereits vor der Hilfe geprüft; ein Mappingfehler kann den Hilfereturn verhindern. Die normale Validierung von Ausgabemodus, Sortierung, Analysemodus, Namen, Pattern, Zeitfenster, Zeilen-/Textgrenzen und Analysefreigaben entfällt im Hilfezweig; die frühen Mappingprüfungen bleiben aktiv. |

```sql
EXEC [monitor].[USP_QueryStoreRuntimeStats] @Hilfe=1;
```

```sql
DECLARE @BisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @VonUtc datetime2(7) = DATEADD(HOUR, -1, @BisUtc);
EXEC [monitor].[USP_QueryStoreRuntimeStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @VonUtc = @VonUtc,
      @BisUtc = @BisUtc,
      @Sortierung = 'CPU_TOTAL',
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_QueryStoreRuntimeStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'NONE',
      @JsonErzeugen = 1,
      @Json = @Json OUTPUT;
SELECT @Json AS [Json];
```

```sql
CREATE TABLE [#QueryStoreRuntimeStats_HelpExample] ([seed] int NULL); EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"runtimeStats":"#QueryStoreRuntimeStats_HelpExample"}'; SELECT * FROM [#QueryStoreRuntimeStats_HelpExample]; DROP TABLE [#QueryStoreRuntimeStats_HelpExample];
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `runtimeStats` mit 40 Feldern und zehn explizit Framework-collatierten Textspalten. `QueryStoreDatabaseName`, `QueryId` und `PlanId` sind NOT NULL; alle übrigen Felder sind nullable, alle Spalten ohne Identity. RAW, CONSOLE, TABLE und JSON lesen dieselbe spät materialisierte Exportmenge. Ein positives `@MaxZeilen` begrenzt diese Menge einmal global nach der gewählten Sortierung und den bestehenden Secondarykeys; NULL und 0 bleiben unbegrenzt.

Textprojektion, Plan-XML-Parsing, Truncationwarnung, Kandidatenzähler, Status und `hasMoreRows` entstehen vorher aus allen gesammelten lokalen N+1-Kandidaten. Ungültige Zeilen- oder Textlimits ergeben `INVALID_PARAMETER` mit leerer Fachmenge; die bereits vorhandene Statusprüfung überspringt dann die Projektion. NULL und 0 als Textlimit erhalten den vollständigen Text. Die lokale dynamische Projektion qualifiziert `A.object_id` eindeutig und benennt die neun vorhandenen Rankausdrücke. Bei `LAST_EXECUTION` wird dieselbe lokale Sortexpression einmal verwendet; die übrigen lokalen und globalen Sortschlüssel bleiben erhalten. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Aggregation je Query, Plan und Ausführungstyp über alle berücksichtigten Runtime-Intervalle. Sie ist keine einzelne Ausführung.

## So lesen

Vergleichen Sie Zeitfenster und Intervalllänge, `ExecutionCount`, Total- und Averagewerte sowie `PlanId`.

## Warum kann das problematisch sein?

Mehrere Pläne derselben Query mit stark unterschiedlichen Werten können Regression oder Parameter Sensitivity anzeigen.

## Wann ist es kein Problem?

Hohe Total-CPU bei sehr vielen Ausführungen kann pro Aufruf klein sein. Hohe Average-Dauer bei einer Ausführung ist schwache Evidenz.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Plan A: 10 ms × 100.000; Plan B: 500 ms × 20. B ist pro Aufruf schlechter, A kann aber mehr Gesamtlast erzeugen. Prüfen Sie Waits, Plan Changes und Showplan.

**Ähnlich aussehender Gegenfall:** Hohe Total-CPU bei sehr vielen Ausführungen kann pro Aufruf klein sein. Hohe Average-Dauer bei einer Ausführung ist schwache Evidenz. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Query Store kann nutzbar sein, obwohl das gewählte Fenster leer ist. Prüfen Sie zuerst Capturemodus, Read-only-Status, Retention und UTC-Fenster.

Für `USP_QueryStoreRuntimeStats` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Randintervalle können Messanteile außerhalb des exakten Fensters enthalten.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Ohne expliziten Datenbankfilter werden alle sichtbaren, geeigneten Online-Benutzerdatenbanken betrachtet, mit einstündigem UTC-Fenster, TOP 100, ohne Plan XML und Referenzdatenbankauflösung. Lokal werden höchstens N+1 gerankte Kandidaten übernommen. Das Einstiegsbeispiel wählt ausdrücklich `ExampleDatabase`. |
| Teuerster Pfad | Viele Datenbanken, `VOLL` beziehungsweise unbegrenztes/hohes Limit, langer Zeitraum, Plan XML und Referenzdatenbank-/Regexfilter. Aggregation und XML-Prüfung können große Retentionsbestände berühren. |
| Haupttreiber | Zahl der gewählten Query Stores, überlappenden Runtimeintervalle, Query-/Plan-Kombinationen und Ausführungsstatistikzeilen. Ohne enges UTC-Fenster wächst die Aggregation mit der gesamten aufbewahrten Historie; Referenzfilter können Plan-XML ergänzen. |
| Skalierung | Quellarbeit wächst mit überlappenden Runtimeintervallen, Queries/Plänen und Datenbanken. Plan-XML-/Referenzfilter erhöhen CPU und Speicher; Text-/Planbreite erhöht Transfer. |
| Ressourcen | CPU und I/O auf Query-Store-internen Tabellen, TempDB für Fensteraggregation und Transfer für Texte/Pläne; Umfang folgt Retention und Capturevolumen. |
| Begrenzungswirkung | Datenbank, UTC-Fenster, QueryId/-Hash und Textfilter begrenzen die Quelle. N+1 wird jedoch erst nach Intervallaggregation und Sortierung je Datenbank angewandt; es begrenzt nicht die dafür gelesenen Historyzeilen. Das globale TOP wird anschließend über lokale Kandidaten gebildet. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `QUERY_STORE_CURRENT`, `QUERY_STORE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, einstündiges UTC-Fenster, TOP 100 und kein XML. `VOLL`, Plan-XML, >1000/unbegrenzt, Querytext-Regex- oder Referenzfilter und mehr als 24 gezählte Stundengrenzen erst nach `QUERY_STORE_DEEP`-Bestätigung und erforderlicher Gruppenfreigabe. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierte, retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Query-/Plan-Kombinationen verursachten im gewählten historischen Fenster Ausführungen, Dauer, CPU, I/O, Memory, TempDB oder Loglast?

### Technischer Hintergrund

Runtime Stats speichern aggregierte Messwerte je Plan, Intervall und Execution Type. Der Code gewichtet die gespeicherten Durchschnittswerte mit `count_executions`, summiert zuerst je Intervall und anschließend je Query, Plan und Ausführungstyp und dividiert die gewichteten Totals für Averagewerte durch die gesamte Ausführungszahl. Dauer und CPU werden von Mikrosekunden in Millisekunden, Memory- und TempDB-Seiten mit Faktor 8 in KB umgerechnet. Der Memory-Maxwert verwendet `max_query_max_used_memory`. Query, Plan und Text werden über IDs verbunden, die nur innerhalb der Query-Store-Datenbank eindeutig sind.

### Datenkette

`sys.database_query_store_options`, `sys.objects`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.query_store_runtime_stats`, `sys.query_store_runtime_stats_interval`, `sys.schemas`, `sys.sp_executesql`.

### Source Select

Runtimewerte werden über Intervall, Plan, Query und Query Text verbunden:

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
WHERE [i].[end_time] > @VonUtc
  AND [i].[start_time] < @BisUtc;
```

**Wichtig für die Eigenlast:** Zeitfenster und optional `query_id`/Query Hash vor Text- und Planprojektion anwenden. Die Intervallmenge bestimmt CPU und Speicher; ein späteres Top-N reduziert nur das Ergebnisranking.

### Zeit- und Scope-Modell

Exakte `@ReferencedDatabaseNames` werden mit dem Parser der Frameworkdatenbank geprüft und in den dynamischen Quellabfragen über dessen dreigliedrigen Namen aufgelöst. Der Frameworkname wird vor `USE` aus `master.sys.databases` mit `NOLOCK` gelesen und mit `QUOTENAME` geschützt. Die Liste filtert Datenbankreferenzen im Showplan, nicht die Query-Store-Quelldatenbanken. `NULL` lässt diesen Referenzfilter weg; eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Gültige doppelte Namen bleiben erlaubt und vervielfachen wegen `EXISTS` keine Zeilen. Die dekodierten XML-Namen werden weiterhin mit der expliziten Framework-CS-Collation verglichen; LIKE- und Regexpfade behalten ihre bisherigen Verträge.

Die Auswertung verwendet eine persistierte, nach Intervallen aggregierte Historie innerhalb der Retention. Intervalle mit `end_time > @VonUtc AND start_time < @BisUtc` werden vollständig einbezogen, ohne zeitanteilige Kürzung. Die ausgegebenen ersten und letzten Ausführungszeiten stammen aus den Runtime-Records und können außerhalb eines schmalen Fensters liegen.

Die neun Sortierungen bleiben `CPU_TOTAL`, `DURATION_TOTAL`, `READS_TOTAL`, `WRITES_TOTAL`, `EXECUTIONS`, `MEMORY_MAX`, `TEMPDB_TOTAL`, `LOG_BYTES_TOTAL` und `LAST_EXECUTION`. Global folgen das letzte Ausführungsdatum absteigend, der Query-Store-Datenbankname, QueryId und PlanId; zusätzliche Sorttie-Schlüssel werden nicht eingeführt. Eine feste Auswahl zwischen getrennten Aufrufen bei vollständigen Sortties wird nicht zugesichert.

Common177 prüft bedingt eine extern vorbereitete, schreibgeschützte synthetische Fixture. Der positive Block liest native Runtime-Records, Katalogidentitäten, Texte und gespeicherte Pläne; ohne passende Fixture meldet er `NOT_EXECUTED`, während allgemeine Verträge weiterlaufen. XML wird als Wert verglichen; native SqlClient- und SQL-Serialisierungen müssen keine identischen Textbytes besitzen. Exakte Cross-DB-Referenzlisten, Regex, Berechtigungsfehler und ältere native Engines sind nicht Bestandteil dieses positiven Fixturevertrags.

### Bewertung und Gegenprobe

Berücksichtigen Sie Total und Average stets zusammen mit Execution Count, PlanId, Execution Type und Zeitspanne. Eine hohe Total-CPU bei niedriger Average-CPU ist eine kumulative Optimierungschance; eine hohe Average-Duration bei niedriger CPU verlangt Wait-, Blocking- und I/O-Kontext.

### Typische Fehlinterpretation

Durchschnittswerte verdecken P95/P99, multimodale Parametergruppen und Ausreißer. Query Store Runtime ist keine Storage-Latenzmessung.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_QueryStoreWaitStats`, PlanChanges, Regressions und Showplan.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#2-monitorusp_querystoreruntimestats)

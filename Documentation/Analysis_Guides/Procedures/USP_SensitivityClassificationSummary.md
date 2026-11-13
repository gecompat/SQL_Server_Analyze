# [monitor].[USP_SensitivityClassificationSummary]

Die Procedure zählt je ausgewählter, für den Caller sichtbarer ONLINE-Datenbank sichtbare Tabellen, deren Spalten und die klassifizierte Teilmenge. Sie liest keine Tabellenwerte, Labels, Informationstypen, deren IDs oder Ränge. Die drei Zahlen sind eine Katalogaufnahme ohne Aussage über Datenqualität, Schutzwirkung oder Vollständigkeit. Ein erfolgreiches Nullergebnis bedeutet ausschließlich, dass im sichtbaren Scope keine passende Zeile gezählt wurde.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SensitivityClassificationSummary]
    @DatabaseNames=N'[ExampleDatabase]',
    @ResultSetArt='CONSOLE',
    @PrintMeldungen=0;
```

Der Caller benötigt Zugriff auf die ausgewählte Datenbank und `VIEW ANY SENSITIVITY CLASSIFICATION` für einen erfolgreichen Klassifikationszähler. `HAS_PERMS_BY_NAME` prüft das effektive Datenbankrecht vor den Katalogzählungen. Ohne belegtes Recht bleiben alle drei Zähler NULL. Das Framework vergibt keine Rechte.

## Eine Zeile bedeutet

Eine `classificationSummary`-Zeile beschreibt eine ausgewählte, beim Aufruf sichtbare ONLINE-Datenbank. `DatabaseId` und `DatabaseName` binden die drei Zähler an diese Aufnahme. Es gibt keine Objekt- oder Spaltenzeilen. `NULL` bei allen Zählern bedeutet, dass die Quelle nicht erfolgreich gelesen wurde; drei Nullen sind nur bei `AVAILABLE_LIMITED` ein sichtbares Nullergebnis.

## So lesen

Lesen Sie zuerst `StatusCode`, `VisibilityScope`, `sourceStatus` und `warnings`. Prüfen Sie danach die drei Zahlen als caller-sichtbare Katalogaufnahme. Ein kleinerer klassifizierter Zähler ist keine Qualitätsbewertung. Wegen nacheinander ausgeführter Abfragen darf aus den drei Zählern kein zeitpunktgleicher Quotient oder eine stabile Ungleichung abgeleitet werden. Prüfen Sie einen unerwarteten Berechtigungsstatus im Zielkontext; die Procedure selbst vergibt keine Rechte.

## Warum kann das problematisch sein?

Eine nicht klassifizierte sichtbare Spalte kann aus fachlich unterschiedlichen Gründen ohne Katalogeintrag sein. Aus den Zählern lässt sich weder der Inhalt der Spalte noch die fachliche Notwendigkeit eines Labels ableiten. Fehlt `VIEW ANY SENSITIVITY CLASSIFICATION`, ist ein Nullzähler besonders irreführend; deshalb liefert die Procedure in diesem Fall NULL und einen Fehlerstatus.

## Wann ist es kein Problem?

Ein sichtbarer Nullzähler kann für eine neu angelegte, leere oder bewusst nicht klassifizierte synthetische Datenbank erwartbar sein. Auch ein kleiner klassifizierter Anteil ist ohne fachlichen Sollkatalog keine Abweichung. Diese Procedure setzt keinen Sollwert und empfiehlt keine Klassifikationsänderung.

## Technische Vertiefung

### Leitfrage

Welche sichtbaren Tabellenspalten der ausgewählten Datenbank haben zur Aufnahmezeit einen Klassifikationseintrag im nativen SQL-Server-Katalog?

### Technischer Hintergrund

SQL Server 2019 und neuer stellt `sys.sensitivity_classifications` bereit. Die Sicht enthält `class=1` für Spalten und verbindet `major_id` und `minor_id` mit Objekt- und Spalten-ID. Der Produktcode prüft nur diese Schlüssel und liest weder Label noch Informationstyp, deren IDs oder Rang. Sichtbare Tabellen und Spalten stammen aus `sys.tables` und `sys.columns`. Die Berechtigung ist datenbankbezogen; `HAS_PERMS_BY_NAME` wird im Zielkontext geprüft.

### Datenkette

Der gemeinsame Kandidatenhelfer wählt sichtbare ONLINE-Datenbanken. Je Datenbank prüft die Procedure Identität und effektives Klassifikationsrecht. Bei 1 folgen drei `COUNT_BIG`-Abfragen; bei 0 oder NULL bleiben alle Zähler NULL. `classificationSummary` und `sourceStatus` halten Erfolg oder Fehler getrennt. Das Ausgabelimit wird erst danach angewandt. JSON und TABLE übernehmen die benannten Mengen mit denselben NULL-Feldern.

### Source Select

Die fachliche Zählung entspricht diesem vereinfachten, rein lesenden SQL im ausgewählten Datenbankkontext:

```sql
SELECT COUNT_BIG(*) AS VisibleTableCount FROM sys.tables;
SELECT COUNT_BIG(*) AS VisibleTableColumnCount
FROM sys.tables AS t
JOIN sys.columns AS c ON c.object_id=t.object_id;
SELECT COUNT_BIG(*) AS ClassifiedVisibleTableColumnCount
FROM sys.tables AS t
JOIN sys.columns AS c ON c.object_id=t.object_id
WHERE EXISTS
(
    SELECT 1 FROM sys.sensitivity_classifications AS sc
    WHERE sc.class=1 AND sc.major_id=t.object_id AND sc.minor_id=c.column_id
);
```

**Wichtig für die Eigenlast:** Drei Katalogzählungen laufen je ausgewählter Datenbank. `@MaxZeilen` begrenzt die ausgegebenen Datenbankzeilen, nicht die Kataloglesearbeit. `@LockTimeoutMs` begrenzt einzelne Sperrwartezeiten, nicht die Gesamtdauer. Die Procedure greift auf keine Benutzertabellenwerte zu.

### Zeit- und Scope-Modell

Die Katalogzählungen erfolgen nacheinander und bilden keinen atomaren Snapshot. Sie verwenden `WITH (NOLOCK)` und können uncommittete oder wechselnde Metadaten beobachten; Schema-Stability-Wartezeiten bleiben möglich. Der Datenbank-ID-/Name-/Erstellzeitabgleich begrenzt Identitätswechsel, beweist aber keinen durchgehend stabilen Datenbankzustand. Gleichzeitige Metadatenänderungen können die Werte gegeneinander verschieben. Die sichtbare Menge hängt vom Ausführungskontext ab. `SKIPPED` bei keiner Kandidatendatenbank ist keine erfolgreiche leere Katalogaufnahme.

### Bewertung und Gegenprobe

Vergleichen Sie bei Bedarf die drei nativen Katalogzählungen mit demselben Caller in derselben Datenbank. Für fachliche Klassifikationsqualität ist ein separater genehmigter Sollkatalog erforderlich; dieser Bericht stellt ihn nicht bereit. Bei `DENIED_PERMISSION` prüfen Sie das effektive Datenbankrecht unabhängig von diesem Modul.

### Typische Fehlinterpretation

`ClassifiedVisibleTableColumnCount=0` bedeutet weder, dass keine sensiblen Daten vorhanden sind, noch dass alle anderen Spalten keine Klassifikation benötigen. NULL-Zähler bedeuten Quellenfehler oder fehlende nachweisbare Berechtigung, keine gezählte Null. Die Baseline umfasst alle sichtbaren `sys.tables`-Spalten und ist kein geprüfter Katalog ausschließlich klassifizierbarer Spalten.

### Folgeanalyse

[USP_DatabasePrincipalAnalysis](USP_DatabasePrincipalAnalysis.md) kann direkte Datenbankrechte getrennt darstellen. Der [Klassifikations-Dossiervertrag](../../../AI_Metadata/Internal_Documentation/Architecture/Sensitivity_Classification_Summary_Dossier.md) dokumentiert die Grenzen des neuen Slices. Diese Folgeanalyse berechnet keine Schutzwirkung und ersetzt keine fachliche Datenklassifikationsentscheidung.

[Technische Detailbeschreibung](../../../AI_Metadata/Internal_Documentation/Architecture/Sensitivity_Classification_Summary_Dossier.md) und [Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md) ergänzen den Resultsetvertrag.

## Parameter

Jeder Parameter kann ausgelassen werden; dann gilt sein angegebener **Default**. Die Ausgabeparameter werden beim Eintritt zurückgesetzt. Die Form der Listen und Pattern entspricht dem gemeinsamen Datenbankkandidatenhelfer.

| Parameter | Typ | Eingabe, Default und Wirkung |
|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | **Default:** `NULL`. NULL, leerer Text oder äußere U+0020-Leerzeichen bedeuten keine exakte Einschränkung. Eine aktive bracket-aware Pipe-Liste enthält einteilige Datenbanknamen; \| innerhalb [...] ist Namensinhalt und ]] maskiert ]. Äußere Leerzeichen werden getrimmt; leere oder doppelte Segmente und Namen über 128 Zeichen sind ungültig. Jedes rohe Segment darf höchstens 4000 UTF-16-Codeeinheiten enthalten; diese Grenze gilt nicht für die Gesamtliste. Eine aktive Liste und ein nicht-NULL-Pattern sind unzulässig. Standardauswahl: caller-sichtbare, zugreifbare ONLINE-Benutzerdatenbanken ohne Snapshots. |
| `@SystemdatenbankenEinbeziehen` | `bit` | **Default:** `0`. 0 schließt Datenbank-IDs bis 4 aus, 1 lässt sie als Kandidaten zu. NULL ist INVALID_PARAMETER. Numerische 0 wird 0, andere numerische Werte werden 1. Sichtbarkeit und Zugriff bleiben erforderlich. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | **Default:** `NULL`. NULL bedeutet kein Pattern; nicht-NULL-Leertext ist ungültig. Optionales like:, regex: oder regexi: vor einem nichtleeren Pattern; ohne Präfix gilt LIKE. LIKE und regex sind case-sensitiv, regexi ist case-insensitiv. LIKE verwendet SQL-LIKE-Syntax mit %, _, Zeichenklassen und ohne eigene ESCAPE-Klausel. Regex-Syntax wird vom Parser nicht vorvalidiert. Regex verlangt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Eine aktive exakte Liste und Pattern sind unzulässig. |
| `@MaxZeilen` | `int` | **Default:** `1000`. NULL und 0 bedeuten unbegrenzt, negative Werte INVALID_PARAMETER, positive Werte 1 bis 2147483647 begrenzen ausschließlich ausgegebene classificationSummary-Datenbankzeilen nach DatabaseId. Die Kandidatenermittlung und Kataloglesearbeit werden nicht begrenzt. Ein abgeschnittenes Ergebnis erhält OUTPUT_LIMIT. |
| `@LockTimeoutMs` | `int` | **Default:** `0`. Nur 0 bis 60000 Millisekunden sind zulässig; NULL ist INVALID_PARAMETER. 0 ist NOWAIT. Der Wert gilt je dynamischem Datenbank-Katalogbatch und ist keine Gesamtdauergrenze. Der vorherige Sessionwert wird wiederhergestellt. |
| `@ResultSetArt` | `varchar(16)` | **Default:** `'CONSOLE'`. Nach äußerem U+0020-Trimmen und Großschreibung sind ausschließlich CONSOLE, RAW, TABLE und NONE zulässig; NULL/leer ist ungültig. CONSOLE zeigt genau eine formatierte Fachmenge. RAW liefert moduleStatus, classificationSummary, sourceStatus, warnings. TABLE schreibt gemappte Mengen; NONE liefert keine Resultsets. JSON bleibt unabhängig. |
| `@ResultTablesJson` | `nvarchar(max)` | **Default:** `NULL`. Nur TABLE nimmt ein JSON-Objekt mit wenigstens einer Zuordnung an. Schlüssel sind exakt moduleStatus, classificationSummary, sourceStatus, warnings; Werte sind unterschiedliche lokale #Temp-Namen. Zielnamen sind maximal 116 Zeichen lang, beginnen mit #, nicht mit ## oder dem reservierten #Monitor-Präfix. Die Ziele müssen vorhanden, leer und mit genau einer Seed-Spalte ausgestattet sein. Doppelte Schlüssel werden binär, doppelte Zielnamen case-insensitiv geprüft; ungültige, doppelte oder unbekannte Schlüssel/Ziele werden vor der fachlichen Quellenlesung abgewiesen. Ein späterer Writer-Fehler kann bereits geschriebene Ziele hinterlassen. Außerhalb TABLE sind nur NULL, leer oder U+0020-Leerzeichen zulässig. |
| `@JsonErzeugen` | `bit` | **Default:** `0`. 1 erzeugt unabhängig von ResultSetArt JSON mit schemaVersion 1, meta und allen vier Arrays; NULL und 0 erzeugen kein JSON. Numerische 0 wird 0, andere numerische Werte werden 1. |
| `@Json` | `nvarchar(max) OUTPUT` | **Default:** `NULL`. Optional an eine nvarchar(max)-Variable mit OUTPUT binden. Eingang wird auf NULL gesetzt; JSON entsteht nur bei JsonErzeugen=1 im normalen Pfad. Hilfe, frühe Parameterfehler und äußerer CATCH lassen NULL. |
| `@PrintMeldungen` | `bit` | **Default:** `1`. 1 gibt zusätzliche niedrige Severity-Meldungen zu Fehlern aus; 0 und NULL unterdrücken sie. Status, Resultsets und OUTPUT-Werte bleiben davon unabhängig. Numerische 0 wird 0, andere numerische Werte werden 1. |
| `@Hilfe` | `bit` | **Default:** `0`. 1 gibt diese Hilfe vor Auswahl und Katalogzugriff aus, setzt StatusCodeOut=AVAILABLE und IsPartialOut=0 und kehrt mit 0 zurück. NULL und 0 führen den normalen Pfad aus. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | **Default:** `NULL`. Optional mit OUTPUT binden; Eingang wird zurückgesetzt. AVAILABLE bedeutet nur Hilfe; AVAILABLE_LIMITED erfolgreiche sichtbare Quelle; SKIPPED keine Kandidatendatenbank und keine Katalogaufnahme; INVALID_PARAMETER direkte Eingabe oder Auswahlvertrag; INTERNAL_ERROR interner Kandidaten-Vorbereitungsfehler; SELECTION_UNAVAILABLE fehlender Helferstatus als Fallback; UNAVAILABLE_FEATURE fehlende Regexvoraussetzung; DATABASE_UNAVAILABLE nicht erreichbare Datenbank; SYSTEM_DATABASE_EXCLUDED ausgeschlossene explizite Systemdatenbank; DENIED_PERMISSION negative effektive Rechteprüfung oder native Berechtigungsfehler; SOURCE_UNAVAILABLE unbekanntes Prüfergebnis oder Quellenfehler; TIMEOUT SQL 1222; ERROR_HANDLED äußerer Fehler. Der erste relevante Quellenfehler bestimmt den globalen Status. |
| `@IsPartialOut` | `bit OUTPUT` | **Default:** `NULL`. Optional mit OUTPUT binden; Eingang wird zurückgesetzt. Hilfe liefert 0, jeder normale Lauf und Fehlerpfad 1, weil Metadatensicht begrenzt sein kann. |
| `@ErrorNumberOut` | `int OUTPUT` | **Default:** `NULL`. Optional mit OUTPUT binden; Eingang wird zurückgesetzt. Erfolgreicher Lauf/Hilfe lassen NULL. Direkte Eingabefehler liefern 51011; Preflight-Rechteprüfung ohne nativen Fehler lässt NULL. Gefangene SQL-Fehler liefern die echte Fehlernummer. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | **Default:** `NULL`. Optional mit OUTPUT binden; Eingang wird zurückgesetzt. Bei negativer/unklarer Rechteprüfung gibt es einen festen Text; gefangene SQL-Fehler bewahren ERROR_MESSAGE links auf 2048 Zeichen. Hilfe/erfolgreicher Lauf lassen NULL. |

## Ausgabe und Interpretation

`RAW` liefert `moduleStatus`, `classificationSummary`, `sourceStatus` und `warnings` in dieser Reihenfolge. `CONSOLE` liefert genau eine formatierte Menge. `TABLE` schreibt nur ausdrücklich gemappte Mengen nach der Seed-Tabellen-Vorprüfung; `NONE` liefert keine Resultsets. `@JsonErzeugen=1` erzeugt unabhängig davon ein JSON-Objekt mit `meta.schemaVersion=1` und den vier gleichnamigen Arrays. NULL-Felder erscheinen explizit.

`classificationSummary` hat die Spalten `DatabaseId int NOT NULL`, `DatabaseName sysname NOT NULL`, `VisibleTableCount bigint NULL`, `VisibleTableColumnCount bigint NULL`, `ClassifiedVisibleTableColumnCount bigint NULL`, `StatusCode varchar(40) NOT NULL`, `VisibilityScope varchar(32) NOT NULL`, `ErrorNumber int NULL` und `ErrorMessage nvarchar(2048) NULL`. Die Zählung umfasst alle caller-sichtbaren `sys.tables` und deren `sys.columns`, einschließlich gegebenenfalls vorhandener hidden oder systemerzeugter Spalten. Es gibt keinen gesonderten Ausschluss für Microsoft-shipped-Tabellen. Eine passende Klassifikation wird nur über `class=1`, `major_id` und `minor_id` geprüft; `EXISTS` zählt jede sichtbare Tabellenspalte höchstens einmal. Die Baseline beweist nicht, dass jede Spalte klassifizierbar ist. Die drei Zählabfragen laufen nacheinander ohne atomaren Snapshot; gleichzeitige Metadatenänderungen können ihre Werte gegeneinander verschieben.

Ohne ausgewählte Datenbank bleibt die Klassifikationsquelle SKIPPED und es gibt keine erfolgreiche Zählung. Erfolgreich leer heißt `AVAILABLE_LIMITED`/`VISIBLE_ONLY`, drei Zähler 0 und `IsPartial=1`. 0 bei der Rechteprüfung heißt `DENIED_PERMISSION`, NULL heißt `SOURCE_UNAVAILABLE`; beide Fälle haben NULL-Zähler und keine erfundene native Fehlernummer. Gefangene SQL-Fehler behalten tatsächliche Nummer und Meldung. Verlorene Datenbankidentität führt zu `DATABASE_UNAVAILABLE`. `@MaxZeilen` kann Summary-Zeilen aus der Fachmenge entfernen; `sourceStatus` meldet den Ausgabelimitfall weiterhin.

`moduleStatus` enthält `ModuleName sysname`, `CapturedAtUtc datetime2(3)`, `StatusCode varchar(40)`, `IsPartial bit`, `RowCount bigint` und `Detail nvarchar(1000)`. `sourceStatus` enthält `DatabaseId int NULL`, `DatabaseName sysname NULL`, `SourceKey varchar(64)`, `SourceKind varchar(16)`, `StartedAtUtc datetime2(3)`, `CompletedAtUtc datetime2(3)`, `StatusCode varchar(40)`, `VisibilityScope varchar(32)`, `ObservedRows bigint NULL`, `ReturnedRows bigint NULL`, `IsLimited bit`, `ErrorNumber int NULL` und `ErrorMessage nvarchar(2048) NULL`. `warnings` enthält `DatabaseId int NULL`, `DatabaseName sysname NULL`, `WarningCode varchar(64)`, `SourceKey varchar(64) NULL` und `Detail nvarchar(1000)`. Textspalten verwenden `SQL_Latin1_General_CP1_CS_AS`.

## Weitere Aufrufe

```sql
EXEC [monitor].[USP_SensitivityClassificationSummary] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW', @PrintMeldungen=0;
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SensitivityClassificationSummary] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
CREATE TABLE #SensitivitySummaryExample ([Seed] int NULL); EXEC [monitor].[USP_SensitivityClassificationSummary] @ResultSetArt='TABLE', @ResultTablesJson=N'{"classificationSummary":"#SensitivitySummaryExample"}'; SELECT * FROM #SensitivitySummaryExample; DROP TABLE #SensitivitySummaryExample;
```

Eine [technische Abgrenzung und Fixture-Spezifikation](../../../AI_Metadata/Internal_Documentation/Architecture/Sensitivity_Classification_Summary_Dossier.md) erläutert Quelle, Rechte, Aufwand und Aussagegrenzen. [Microsoft Learn: sys.sensitivity_classifications](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sensitivity-classifications-transact-sql?view=sql-server-ver17) beschreibt die native Katalogsicht.

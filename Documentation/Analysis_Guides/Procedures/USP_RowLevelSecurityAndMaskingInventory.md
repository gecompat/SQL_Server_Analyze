# [monitor].[USP_RowLevelSecurityAndMaskingInventory]

**Bereich:** Server Health und Datenbanksicherheit
**Zweck:** Zeigt sichtbare RLS-Policies, Predicate-Metadaten und Masked Columns.
**Beobachtungsart:** getrennte lokale Katalogaufnahmen im Caller-Kontext
**Kostenklasse:** LOW_MEDIUM.

## Entscheidungsfrage und Grenzen

Welche Row-Level-Security-Policies, zugehörigen Predicate-Metadaten und Dynamic-Data-Masking-Spalten sind im gewählten Datenbankkontext sichtbar? Die Procedure liest ausschließlich lokale Katalogmetadaten. Sie liest keine geschützten Tabellenzeilen und gibt keine Predicate-Definitionen oder Maskingfunktionen aus.

Eine erfolgreiche leere Quelle belegt keine Abwesenheit, wenn Metadaten nur eingeschränkt sichtbar sind. Der Bericht bewertet weder Richtlinienwirksamkeit noch Gesundheit oder Vollständigkeit, berechnet keine effektiven Rechte und führt keine Zugriffsprobe aus. Die Procedure erstellt temporäre Tabellen für die Resultatmaterialisierung, ändert aber keine Zielobjekte dauerhaft und nimmt keine Berechtigungsänderungen vor. Sichtbare Policy- und Maskingzeilen beweisen keine Abdeckung aller Objekte oder Principals.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory]
    @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=200,
    @ResultSetArt='CONSOLE', @PrintMeldungen=0;
```

Der Beispielname ist synthetisch. Ohne aktive Namensliste und Pattern wählt der gemeinsame Helfer sichtbare, zugreifbare Online-Datenbanken aus; Snapshots und standardmäßig Systemdatenbanken werden ausgeschlossen. Eine aktive exakte Liste und ein nicht-NULL-Pattern sind gegenseitig ausgeschlossen. Die Pipe-Liste enthält einfache SQL-Namen; ungültige oder doppelte Elemente führen zu INVALID_PARAMETER. Ohne Präfix gilt LIKE, das case-sensitive ausgewertet wird; regex: und regexi: verwenden die Flags c beziehungsweise i und benötigen SQL Server 2025 sowie Compatibility Level 170 der Installationsdatenbank. Das globale Limit wird nach den Katalogabfragen getrennt auf Policies, Predicates und Masked Columns angewandt. NULL oder 0 bedeutet unbegrenzt; negative Werte werden abgewiesen. Das Limit begrenzt die Ausgabe, nicht die Katalogarbeit.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | NULL, leerer Text oder nur äußere U+0020-Leerzeichen heben den exakten Filter auf. Eine aktive Pipe-Liste enthält einfache SQL-Namen; Pipes innerhalb bracket-quotierter Elemente bleiben Inhalt, ]] maskiert dort eine schließende Klammer. Der Parser trimmt Elementränder und prüft Struktur. Leere Elemente, ungültige Klammern, Rohsegmente über 4000 UTF-16-Codeeinheiten, ungültige PARSENAME-Teil-1-Werte, vorhandene Teil 2, Namen mit LEN über 128 sowie Duplikate werden abgewiesen. Eine aktive Liste ist mit jedem nicht-NULL-Pattern unzulässig. Kandidaten müssen sichtbar, ONLINE und mit HAS_DBACCESS zugreifbar sein; Snapshots und standardmäßig Systemdatenbanken werden ausgeschlossen. Nicht verfügbare explizite Namen erzeugen Auswahlwarnungen. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 1 nimmt Systemdatenbanken mit database_id bis einschließlich 4 auf; 0 schließt IDs bis 4 aus. NULL wird vom Auswahlhelfer als INVALID_PARAMETER zurückgewiesen. Der Schalter ändert keine Metadatensicht und prüft keine Berechtigungen. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Nur NULL bedeutet kein Pattern. Ein nicht-NULL-Leertext, nur U+0020-Leerzeichen und leere LIKE:/REGEX:/REGEXI:-Inhalte sind INVALID_PARAMETER. Ein nicht-NULL-Pattern ist mit aktiver @DatabaseNames-Liste unzulässig. Der Parser trimmt zuerst außen und entfernt danach höchstens eines der Präfixe regexi:, regex: oder like: ohne erneutes Trimmen. Ohne Präfix gilt LIKE; leerer Rest ist ungültig. LIKE wird case-sensitive angewandt. regex: arbeitet case-sensitiv mit Flag c und regexi: ohne Beachtung der Groß-/Kleinschreibung mit Flag i; der Auswahlhelfer wertet diese Modi mit REGEXP_LIKE aus und verlangt SQL Server 2025 (Major Version 17) sowie Compatibility Level 170 der Installationsdatenbank. Fehlt die Voraussetzung, löscht er Kandidaten und liefert UNAVAILABLE_FEATURE. LIKE-Inhalte verwenden SQL-LIKE-Syntax (% beliebige Folge, _ ein Zeichen, [...] Zeichenklasse; keine eigene ESCAPE-Klausel). Regexinhalte werden unverändert an REGEXP_LIKE übergeben, ohne Syntaxvorprüfung; eine fehlerhafte Regex kann erst bei der Ausführung scheitern. |
| `@MaxZeilen` | `int` | `1000` | NULL und 0 bedeuten unbegrenzt. 1 bis 2147483647 begrenzt jeweils securityPolicies, securityPredicates und maskedColumns separat über alle ausgewählten Datenbanken; negative Werte liefern INVALID_PARAMETER und Fehlernummer 51011. Die Grenze wird nach allen Fachabfragen angewandt und begrenzt keine Quellarbeit. Sortierschlüssel: Policies DatabaseId/PolicyObjectId, Predicates DatabaseId/PolicyObjectId/PredicateId, Masked Columns DatabaseId/ObjectId/ColumnId. sourceStatus weist beobachtete und je Datenbank zurückgegebene Mengen aus; moduleStatus.RowCount summiert zurückgegebene Fachzeilen. |
| `@LockTimeoutMs` | `int` | `0` | Zulässig sind 0 bis einschließlich 60000 Millisekunden. NULL, negative Werte und Werte über 60000 liefern INVALID_PARAMETER mit 51011. Der Wert gilt je dynamischer Kontext- oder Katalogbatch; 0 bedeutet NOWAIT, positive Werte begrenzen eine jeweilige Sperrwartezeit, nicht die Gesamtdauer. Bei eingehendem LOCK_TIMEOUT 0 erhält eigene Temp-DDL vorübergehend 1000 ms; der TABLE-Helfer gewährt eigener Temp-DDL ebenfalls bis zu 1000 ms je Anlage und setzt anschließend 0. Am normalen Ende und im äußeren CATCH stellt der Aufrufer eingehenden LOCK_TIMEOUT und XACT_ABORT wieder her. Caller-Transaktion bleibt Caller-eigen; kein COMMIT oder ROLLBACK. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Der Wert wird mit leerem Fallback, äußerem U+0020-Trimmen und Großschreibung normalisiert. Genau CONSOLE, RAW, TABLE und NONE sind erlaubt; sonst INVALID_PARAMETER/51011. CONSOLE zeigt Policies sowie Kontext, Quellenstatus und Warnungen, jedoch keine Predicate- oder Masked-Column-Fachzeilen. RAW liefert sieben getrennte Mengen in der Reihenfolge moduleStatus, databaseContext, securityPolicies, securityPredicates, maskedColumns, sourceStatus, warnings. TABLE schreibt angeforderte Teilmengen in vorbereitete lokale Temp-Tabellen. NONE liefert keine Resultsets. JSON und OUTPUTs sind unabhängig davon. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Außer bei TABLE sind NULL, leerer Text oder nur äußere U+0020-Leerzeichen zulässig; sonst INVALID_PARAMETER/51011. TABLE verlangt ein gültiges JSON-Objekt mit mindestens einer Zuordnung. Zulässige Schlüssel sind exakt moduleStatus, databaseContext, securityPolicies, securityPredicates, maskedColumns, sourceStatus und warnings; jeder Wert ist ein nichtleerer String mit vorhandenem lokalen #Temp-Ziel. Schlüssel- oder Zielduplikate und unbekannte Namen werden abgewiesen. ##, Namen über 116 Zeichen und #Monitor-Präfix sind unzulässig. Jedes Ziel muss leer sein und genau eine Seed-Spalte haben. Der Helfer prüft alle Ziele vor fachlichen Systemzugriffen; der spätere Writer ersetzt die Seed-Spalte durch das native Ergebnisschema. Die Schlüssel bedeuten: moduleStatus Modulstatus, databaseContext Datenbankkontext, securityPolicies sichtbare RLS-Policies, securityPredicates Predicate-Metadaten, maskedColumns Metadaten maskierter Spalten, sourceStatus Quellenstatus und warnings Warnungen. |
| `@JsonErzeugen` | `bit` | `0` | Nur 1 erzeugt im normalen Pfad das JSON-Objekt mit meta und allen sieben Arrays: moduleStatus, databaseContext, securityPolicies, securityPredicates, maskedColumns, sourceStatus und warnings. NULL und 0 überspringen die Erzeugung. Die Resultsetart bleibt davon unabhängig; im äußeren Fehlerpfad wird @Json auf NULL gesetzt. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Als OUTPUT-Variable binden, um den JSON-Text zu empfangen. Der eingehende Wert wird am Aufrufanfang auf NULL zurückgesetzt; nur bei @JsonErzeugen=1 wird er im normalen Pfad gesetzt. Ohne Erzeugung, bei frühem Parameterfehler oder im äußeren CATCH bleibt er NULL. Die Hilfe erzeugt kein JSON. Optionaler Empfänger: Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden, andernfalls das Argument auslassen. |
| `@PrintMeldungen` | `bit` | `1` | 1 gibt Meldungen an den vorgesehenen Parameterfehler-, Quellenfehler- und äußeren Fehlerstellen mit NOWAIT aus. NULL und 0 unterdrücken sie. Status, OUTPUT-Werte und Rückgabecode werden dadurch nicht geändert. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@Hilfe` | `bit` | `0` | 1 beendet nach der Parameterhilfe und den Beispielen vor Validierung und Aufnahme. @StatusCodeOut wird AVAILABLE, @IsPartialOut 0; zuvor zurückgesetzte Fehler- und JSON-OUTPUTs bleiben NULL. Der bare RETURN ergibt Rückgabecode 0. NULL und 0 führen den normalen Pfad aus. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Als OUTPUT-Variable binden. Der Wert wird beim Eintritt zurückgesetzt. Hilfe liefert AVAILABLE; direkte Parameterfehler INVALID_PARAMETER; normale Aufnahmen liefern AVAILABLE_LIMITED, sobald mindestens eine der drei Fachquellen erfolgreich abgefragt wurde. AVAILABLE_LIMITED ist außerdem der Initialwert und bleibt erhalten, wenn ohne Kandidaten und ohne Auswahlwarnungen keine passende Statuszeile für die Fallback-Auswahl existiert; dieser Wert belegt daher keine erfolgreiche Katalogabfrage. Wenn keine Quelle diesen Status erreicht, übernimmt die Procedure den ersten Status ungleich AVAILABLE_LIMITED und SKIPPED nach DatabaseName und SourceKey; zwischen solchen Quellen gibt es keine Vorrangregel. Tatsächlich mögliche Werte: AVAILABLE (Hilfe), AVAILABLE_LIMITED (mindestens eine Fachquelle), DATABASE_UNAVAILABLE (Datenbankkontext/-quelle), SOURCE_UNAVAILABLE (Katalogquelle), SYSTEM_DATABASE_EXCLUDED (Auswahlwarnung), INVALID_PARAMETER (Vorprüfung/Helfer), INTERNAL_ERROR (Kandidaten-Temp-Schema), UNAVAILABLE_FEATURE (Regex-Voraussetzung), STATUS_UNAVAILABLE (fehlender Helferstatus), ERROR_HANDLED (äußerer CATCH ohne FailureStatus). Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Als bit-OUTPUT binden. Startwert wird NULL, bei Hilfe 0, bei direkter Parameterinvalidierung, normalem Ende und äußerem CATCH 1. Normale Erfolge bleiben partiell, weil Caller-Metadatensicht und vollständige RLS-/Maskingabdeckung unbewiesen sind und getrennte Quellen keinen gemeinsamen Snapshot bilden. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Als int-OUTPUT binden. Startwert NULL, auch bei Hilfe. Direkte Parameterfehler liefern 51011. Beim normalen Ende wird die erste nicht-NULL-Fehlernummer nach DatabaseId und SourceKey aus sourceStatus verwendet; ohne Quellenfehler bleibt NULL. Im äußeren CATCH hat FailureError Vorrang, sonst wird die abgefangene SQL-Fehlernummer ausgegeben. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Als OUTPUT-Variable binden. Startwert NULL, auch bei Hilfe. Direkte Parameterfehler liefern eine feste Parameterdiagnose. Normale Quellenfehler übernehmen die Meldung des ersten sourceStatus-Eintrags mit Fehlernummer nach DatabaseId und SourceKey. Im äußeren CATCH wird die vorbereitete Diagnose oder ERROR_MESSAGE() auf 2048 Zeichen begrenzt. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt. |

### RAW-Ausgabe

```sql
EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory] @ResultSetArt='RAW', @MaxZeilen=100;
```

### JSON und Diagnose-OUTPUTs

```sql
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
EXEC @ReturnCode=[monitor].[USP_RowLevelSecurityAndMaskingInventory]
      @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT
    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];
```

### TABLE-Ausgabe

```sql
CREATE TABLE [#RowLevelSecurityAndMaskingInventory_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N'{"securityPolicies":"#RowLevelSecurityAndMaskingInventory_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
    SELECT * FROM [#RowLevelSecurityAndMaskingInventory_HelpExample];
    DROP TABLE IF EXISTS [#RowLevelSecurityAndMaskingInventory_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#RowLevelSecurityAndMaskingInventory_HelpExample];
    THROW;
END CATCH;
```

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory] @Hilfe=1;
```

## Resultsets

CONSOLE zeigt Policy-Zeilen sowie Datenbankkontext, Quellenstatus und Warnungen; Predicate- und Masked-Column-Fachzeilen bleiben dort verborgen. RAW liefert die sieben Resultsets einzeln. TABLE ordnet eine nichtleere JSON-Teilmenge vorhandenen, leeren lokalen #Temp-Tabellen mit einer Seed-Spalte zu. NONE unterdrückt Resultsets. Status, Partialität, Diagnose und optionales JSON können unabhängig über OUTPUT empfangen werden.

| Resultset | Inhalt |
|---|---|
| `moduleStatus` | Aufrufstatus, Partialität und Summe der zurückgegebenen Policy-, Predicate- und Maskingzeilen. |
| `databaseContext` | Datenbankbindung, Zustand, Containment und Kontextstatus je ausgewähltem Ziel. |
| `securityPolicies` | Sichtbare Policy-ID, Name, Schema, Schalter und Zeitfelder; `IsSchemabindingEnabled` erhält den rohen Katalogwert einschließlich NULL. Wenn die Katalogansicht dieses Feld nicht bereitstellt, bleibt es NULL und `warnings` meldet `SOURCE_UNAVAILABLE` für `SECURITY_POLICIES`. |
| `securityPredicates` | Policy- und Predicate-IDs, Zielobjekt-ID, Typ und Operation. Definitionstext bleibt ausgeschlossen. |
| `maskedColumns` | Objekt-/Spalten-ID, sichtbare Schema-, Tabellen- und Spaltennamen sowie `IsMasked`. Maskingfunktion und Werte bleiben ausgeschlossen. |
| `sourceStatus` | Getrennte Zeitklammer, Status, Sichtbarkeitsgrenze und beobachtete beziehungsweise zurückgegebene Zeilen pro Quelle. |
| `warnings` | Ungekürzte Auswahl-, Quellen-, Limit- und Aussagegrenzen. |

Die stabilen Feldfolgen, Typen, Nullbarkeit und Collation stehen im [Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv). IDs sind nur mit Datenbank- und Aufnahmebindung interpretierbar. Nicht auflösbare Namen bleiben NULL; die native ID-Zeile wird erhalten.

## Eine Zeile bedeutet

Eine Policy-Zeile, Predicate-Zeile oder Masked-Column-Zeile ist ein im Caller-Kontext sichtbarer Katalogeintrag. Datenbank-, Objekt- und Spalten-IDs gelten nur innerhalb der zugehörigen Datenbank. Die drei Quellen werden getrennt gelesen und bilden keinen atomaren Snapshot.

## So lesen

Prüfen Sie zuerst `databaseContext`, `sourceStatus` und `warnings`. Danach ordnen Sie Fachzeilen über Datenbank- und native Objekt-IDs ein. `VISIBLE_ONLY` beschreibt die tatsächlich abgefragte Sicht; es bestätigt keine vollständige Metadatenberechtigung. `IsSchemabindingEnabled` bleibt der rohe Katalogwert einschließlich NULL; fehlt das Katalogfeld, kennzeichnet `SOURCE_UNAVAILABLE` in `warnings` die fehlende Metadatenangabe.

## Aufnahme und Datenschutz

`SECURITY_POLICIES`, `SECURITY_PREDICATES` und `MASKED_COLUMNS` werden je Datenbank isoliert gelesen. Fehler und Timeouts erzeugen Quellenstatus mit unbekannten Mengen und werden nicht als leere erfolgreiche Quelle ausgegeben. Eine erfolgreiche Aufnahme erhält `AVAILABLE_LIMITED` und `VISIBLE_ONLY`; eingeschränkte Metadatensicht bleibt dauerhaft unbewiesen.

Katalogquellenfehler werden je Quelle mit Fehlernummer und fester Diagnoseformulierung protokolliert; Auswahl- und äußere Fehlerpfade können Helfer- beziehungsweise SQL-Fehlermeldungen in OUTPUT und Status weitergeben. Die Katalogabfragen laufen im tatsächlichen Ausführungskontext und übernehmen dessen SQL Server-Metadatensicht. Die Procedure setzt keinen eigenen Identitätskontext und führt keine Objektzugriffsprobe aus. Sie liest keine geschützten Tabellenwerte, ändert weder Policies noch Berechtigungen und bewertet weder effektive Rechte noch Durchsetzung. Jede dynamische Katalogbatch prüft Datenbank-ID, Namen und create_date erneut; die drei Quellen bilden keinen gemeinsamen Snapshot.

@LockTimeoutMs erlaubt 0 bis 60000 Millisekunden und gilt je dynamischer Kontext- oder Katalogbatch; 0 setzt NOWAIT, der Wert begrenzt nicht die Gesamtdauer. Eigene Temp-DDL erhält bei eingehendem LOCK_TIMEOUT 0 vorübergehend bis zu 1000 ms; der TABLE-Helfer gewährt eigenen Anlagen ebenfalls bis zu 1000 ms und setzt anschließend 0. Der Aufrufer stellt LOCK_TIMEOUT und XACT_ABORT am regulären Ende und im äußeren Fehlerpfad wieder her. Eine Caller-Transaktion bleibt Caller-eigen; es gibt weder COMMIT noch ROLLBACK.

## Interpretation

AVAILABLE_LIMITED bedeutet, dass mindestens eine der drei Katalogquellen im aktuellen Ausführungskontext abgefragt wurde. Es beweist weder vollständige Metadatensicht noch vollständige RLS- oder Maskingabdeckung. Eine erfolgreich leere sichtbare Quelle belegt keine Abwesenheit. Jeder Fachbereich wird nach allen Quellenabfragen separat und global begrenzt; OUTPUT_LIMIT wird je betroffener Datenbank und Quelle gemeldet. Kontext, Quellenstatus und Warnungen werden nicht durch @MaxZeilen gekürzt. moduleStatus.IsPartial bleibt bei normalen Aufrufen 1.

## Warum kann das problematisch sein?

Eingeschränkte Katalogsicht kann Policies oder Spalten verbergen. Getrennte Quellen können außerdem unterschiedliche Zustände zu verschiedenen Aufnahmezeitpunkten zeigen. Ein sichtbarer Predicate-Eintrag belegt weder die tatsächliche Durchsetzung noch die Abdeckung aller Principals oder Tabellen.

## Wann ist es kein Problem?

Eine leere sichtbare Teilmenge ist ein gültiges Beobachtungsergebnis, wenn `sourceStatus` die Quelle als verfügbar kennzeichnet und die Ausgabegrenze erhalten bleibt. Ein gesetztes `OUTPUT_LIMIT` ist ebenfalls erwartbar, sofern die gekürzte Fachmenge nicht als vollständiger Bestand interpretiert wird.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Policy-, Predicate- und Masked-Column-Katalogzeilen sind im gewählten Caller-Kontext sichtbar?

### Technischer Hintergrund

Die Aufnahme liest drei getrennte lokale Katalogquellen. Sie gibt ausschließlich native Identitäten und ausgewählte beschreibende Metadaten aus. Die Procedure liest keine geschützten Tabellenwerte und übernimmt keine Ausdruckstexte in Resultsets, Warnungen oder Fehlerdiagnosen.

### Datenkette

`sys.security_policies`, `sys.schemas`, `sys.security_predicates`, `sys.masked_columns`, `sys.tables` und `USP_PrepareDatabaseCandidates`.

### Source Select

Der folgende Quellpfad zeigt Policy-Identitäten und sichtbare Schemanamen. Die beiden anderen Fachquellen werden separat abgefragt. Das optionale Katalogfeld `is_schemabinding_enabled` wird nur gelesen, wenn die Zielansicht es bereitstellt; andernfalls bleibt `IsSchemabindingEnabled` NULL und `warnings` nennt `SOURCE_UNAVAILABLE` für `SECURITY_POLICIES`.

```sql
SELECT
      [p].[object_id]
    , [p].[name]
    , [p].[schema_id]
    , [s].[name] AS [SchemaName]
    , [p].[is_enabled]
    , [p].[is_not_for_replication]
    , [p].[uses_database_collation]
    , [p].[create_date]
    , [p].[modify_date]
FROM [sys].[security_policies] AS [p] WITH (NOLOCK)
LEFT JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [p].[schema_id];
```

**Wichtig für die Eigenlast:** Die Katalogquellen werden je ausgewählter Datenbank separat gelesen und erst danach pro Inventar global begrenzt. Das Limit begrenzt die ausgegebenen Zeilen, nicht die Katalogabfrage.

### Zeit- und Scope-Modell

Der Scope folgt der gemeinsamen Datenbankauswahl. Jede Katalogquelle erhält eine eigene Zeitklammer; die drei Klammern sind kein gemeinsamer Transaktionssnapshot.

### Bewertung und Gegenprobe

Vergleichen Sie bei einer gezielten Prüfung die native Policy- und Objekt-ID mit der jeweiligen Datenbankkatalogsicht. Leiten Sie aus diesem Inventar keine Durchsetzungs- oder Zugriffsentscheidung ab.

### Typische Fehlinterpretation

Eine leere sichtbare Katalogmenge beweist keine Abwesenheit, wenn der Caller nur eingeschränkte Metadatensicht besitzt.

### Folgeanalyse

Verwenden Sie die [Datenbankprincipal-Analyse](USP_DatabasePrincipalAnalysis.md), wenn direkte Principals, Rollen oder explizite Rechte getrennt betrachtet werden müssen.

[Technische Detailbeschreibung](../../Reference/Procedure_Reference.md) · [Spezialfeatureinventur](USP_SpecialFeatureInventory.md) · [Datenbankprincipal-Analyse](USP_DatabasePrincipalAnalysis.md)

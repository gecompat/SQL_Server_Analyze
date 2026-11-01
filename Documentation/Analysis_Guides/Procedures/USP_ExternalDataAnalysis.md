# [monitor].[USP_ExternalDataAnalysis]

**Bereich:** Versionsadaptive lokale Kataloge<br>
**Zweck:** Sichtbare externe Datenobjekte und lokale Referenzen einordnen.<br>
**Beobachtungsart:** Lokale Katalogaufnahme<br>
**Kostenklasse:** LOW_MEDIUM.

## Entscheidungsfrage und Einsatz

Die Procedure zeigt lokale Datenquellen, Dateiformate, externe Tabellen und eine aggregierte Modellanzahl je ausgewählter Datenbank. Datenbankfilter verwenden den bestehenden exklusiven Namens-/Patternvertrag. Ohne Filter werden sichtbare Online-Benutzerdatenbanken verarbeitet; Systemdatenbanken bleiben opt-in.

## Nicht beantwortete Fragen

Die Ausgabe prüft keine Verbindung, Authentifizierung, externen Dateninhalte oder Modellinferenz. Locations, Credentialkennungen und -namen, Remoteidentitäten, Modellnamen und Payloads bleiben ausgeschlossen. Eine lokale Definition beweist keine externe Nutzbarkeit.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExternalDataAnalysis]
      @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=200,
      @ResultSetArt='CONSOLE';
```

Es gibt keinen impliziten CURRENT-Scope, kein Datenbankanzahllimit und keinen aktivierten Remote- oder DDL-Pfad. Die Procedure vergibt keine Berechtigungen.

### Individuelle Parameterverträge

Die folgenden Einträge erklären jeden Parameter mit Datentyp, Eingabeform und ausdrücklich bezeichnetem Default. OUTPUT-Werte werden nur mit einer passenden, mit OUTPUT gebundenen Variable empfangen.

| Parameter und Typ | Default | Eingabeform, Wirkung und Grenzen |
|---|---|---|
| `@DatabaseNames nvarchar(max)` | `NULL` | NULL, Leerstring oder ausschließlich äußere U+0020-Leerzeichen bedeuten keine exakte Einschränkung. Sonst eine bracket-aware Pipe-Liste: \| trennt außerhalb von [...], ]] maskiert innen eine schließende Klammer; äußere U+0020-Leerzeichen je Element werden entfernt. Jedes rohe Segment darf höchstens 4000 UTF-16-Codeeinheiten umfassen. TVF_ParseSqlNameList prüft PARSENAME-Teil 1 auf einen nicht-NULL Namen, Teil 2 auf NULL und LEN(Teil 1) auf höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Dies ist keine vollständige SQL-Bezeichnergrammatik, Existenz- oder Berechtigungsprüfung. Leere/fehlerhaft geklammerte Elemente, Parserablehnung und case-sensitive doppelte gültige Namen ergeben INVALID_PARAMETER. Eine wirksame Liste und jeder nicht-NULL @DatabaseNamePattern-Wert sind zusammen ungültig. Nur sichtbare, ONLINE befindliche, zugreifbare Datenbanken ohne Snapshotmarkierung werden Kandidaten; Systemdatenbanken bleiben ohne Opt-in ausgeschlossen. Nicht verfügbare explizit angeforderte Namen können Auswahlwarnungen liefern. |
| `@DatabaseNamePattern nvarchar(4000)` | `NULL` | NULL oder ausgelassen bedeutet kein Pattern. Ein nicht-NULL Wert wird außen mit LTRIM/RTRIM getrimmt. Zulässige Eingabe ist ein LIKE-Pattern (case-sensitive SQL_Latin1_General_CP1_CS_AS; SQL-LIKE-Metazeichen %, _, [...] gelten) oder ein optionales Präfix LIKE:, REGEX: oder REGEXI:, dessen Erkennung nicht auf Groß-/Kleinschreibung achtet. Nach Entfernen des Präfixes wird der Rest nicht erneut getrimmt. Ein leerer oder nur aus U+0020-Leerzeichen bestehender Eingang oder leeres Präfixergebnis ist ungültig und führt zu INVALID_PARAMETER. Eine wirksame @DatabaseNames-Liste und jeder nicht-NULL Patternwert sind zusammen ungültig. REGEX verwendet Flag c, REGEXI Flag i; Regex-Syntax wird nicht vorab validiert. Regexausführung benötigt SQL Server 2025 (Major 17) und Compatibility Level 170 der Installationsdatenbank; andernfalls UNAVAILABLE_FEATURE. |
| `@SystemdatenbankenEinbeziehen bit` | `0` | Numerische 0 schließt Systemdatenbanken mit IDs bis 4 (master, tempdb, model, msdb) aus; jeder numerische Wert ungleich 0 wird als 1 behandelt und lässt sie in die Auswahl ein. NULL ist ungültig und führt zu INVALID_PARAMETER; ausgelassen gilt 0. Ausgeschlossene explizit angeforderte Systemdatenbanken können als SYSTEM_DATABASE_EXCLUDED-Warnung gemeldet werden. Beeinflusst nur Kandidatenauswahl. |
| `@MaxZeilen int` | `2000` | NULL oder 0 hebt das Ausgabelimit praktisch auf. Positive Werte begrenzen jeweils getrennt die ausgegebenen Zeilen in dataSources, fileFormats, externalTables, modelSummary, sourceStatus und warnings; die Sortierschlüssel sind Datenbankname plus jeweilige Kennung/Quelle beziehungsweise Warnung. Negative Werte führen zu INVALID_PARAMETER. Die Grenze steuert weder Datenbankscope, Sammelarbeit noch Counts: DataSourceCount, FileFormatCount, ExternalTableCount, ExternalModelCount und RowCount beruhen auf der Sammlung vor Ausgabelimits. moduleStatus und databaseStatus werden nicht durch dieses Detailgruppenlimit abgeschnitten. |
| `@ResultSetArt varchar(16)` | `'CONSOLE'` | NULL wird wie leer behandelt, danach werden äußere Leerzeichen entfernt und in Großbuchstaben normalisiert; ausgelassen gilt CONSOLE. Zulässige endliche Werte: RAW gibt die acht nativen Resultsets aus (moduleStatus, databaseStatus, dataSources, fileFormats, externalTables, modelSummary, sourceStatus, warnings); TABLE schreibt die ausgewählten Resultsets in Caller-Temp-Tabellen; CONSOLE gibt eine menschenlesbare Ansicht von databaseStatus aus; NONE unterdrückt fachliche Resultsets. Jeder andere Wert einschließlich JSON führt zu INVALID_PARAMETER. JSON wird unabhängig davon mit @JsonErzeugen angefordert und kann zusätzlich zu jeder zulässigen Ausgabeart erzeugt werden. |
| `@ResultTablesJson nvarchar(max)` | `NULL` | NULL, N'' oder nur Leerzeichen bedeutet keine Zuordnung; ausgelassen gilt NULL. Nur TABLE darf eine nicht-leere JSON-Zuordnung erhalten; bei anderer @ResultSetArt wirft die Procedure Fehler 51011. Das JSON-Objekt muss mindestens ein Schlüssel-Wert-Paar enthalten; jeder Schlüssel muss exakt (case-sensitive, binärer Vergleich) einer der acht Namen moduleStatus, databaseStatus, dataSources, fileFormats, externalTables, modelSummary, sourceStatus oder warnings entsprechen. Jeder Wert muss eine nicht-leere Zeichenfolge mit dem Namen einer vorhandenen lokalen #Temp-Tabelle sein. Resultset-Schlüsseldubletten werden binär erkannt; doppelte Zieltabellennamen sind unter Latin1_General_100_CI_AS unzulässig. Zielname muss mit # beginnen, darf nicht ## sein, höchstens 116 Zeichen lang sein und nicht mit dem reservierten Präfix #Monitor beginnen (case-insensitive). Jede Zieltemp-Tabelle muss beim Aufruf leer sein und genau eine Seed-Spalte besitzen; die Vorprüfung erkennt dies, indem sie temporär eine Marker-Spalte hinzufügt und insgesamt zwei Spalten erwartet. Der Seedname/-typ wird dabei nicht als Quellschema vorgegeben: InternalWriteResultTable passt die leere Ein-Spalten-Tabelle an das native Schema des jeweiligen Resultsets an und fügt dessen Zeilen ein. Vorprüfung läuft für alle Ziele vor dem Schreiben. Schreibvorgänge erfolgen je Mapping nacheinander ohne behauptete Gesamttransaktion/atomare Mehrzieltabelle; ein späterer Fehler kann bereits geschriebene frühere Ziele belassen. Ungültige Zuordnung oder Ziele werden vor dem Schreiben mit 51011 abgelehnt. Alle acht Schlüssel mit jeweiligem Inhalt: moduleStatus liefert Modulstatus und Partialität; databaseStatus Datenbankstatus und ungekürzte Counts; dataSources sichtbare lokale Datenquellen; fileFormats sichtbare Dateiformate; externalTables externe Tabellen mit Referenzsichtbarkeit und Spaltenanzahl; modelSummary Modellanzahl und Modellquellenstatus; sourceStatus Quellenstatus mit nativen Fehlerfeldern; warnings Auswahl-/Quellenwarnungen. Jede nichtleere Teilmenge der acht Schlüssel genügt. Im TABLE-Modus sind NULL, Leerstring und ein leeres Objekt ungültig. Vorprüfungsablehnungen werfen 51011; Writerablehnungen werfen 51010. |
| `@JsonErzeugen bit` | `0` | Numerische 0 deaktiviert JSON; jeder numerische Wert ungleich 0 aktiviert es. NULL ist ungültig und führt zu INVALID_PARAMETER; ausgelassen gilt 0. Die JSON-Ausgabe ist zusätzlich zu RAW/TABLE/CONSOLE/NONE und enthält meta sowie stets acht Arrays: moduleStatus, databaseStatus, dataSources, fileFormats, externalTables, modelSummary, sourceStatus und warnings. Die sechs Detailgruppen dataSources, fileFormats, externalTables, modelSummary, sourceStatus und warnings sind bereits je @MaxZeilen begrenzt; JSON enthält NULL-Spalten ausdrücklich. Wird JSON nicht angefordert, wird @Json zu Beginn auf NULL gesetzt. |
| `@Json nvarchar(max) OUTPUT` | `NULL` | OUTPUT nvarchar(max), ohne Eingabeparameterwirkung. Beim regulären Eintritt wird die Ausgabebindung vor dem Hilfezweig auf NULL gesetzt; bei @JsonErzeugen=1 wird sie am regulären JSON-Zweig mit dem JSON-Dokument belegt, sonst bleibt sie NULL. Zum Empfang muss eine Caller-Variable vom Typ nvarchar(max) mit OUTPUT gebunden werden; ohne OUTPUT-Bindung wird der Wert nicht zurückgegeben. Bei ungefangenen Fehlern ist keine reguläre Ausgabegarantie beschrieben. |
| `@PrintMeldungen bit` | `1` | Numerische 0 unterdrückt die Statusmeldung per RAISERROR severity 10; jeder numerische Wert ungleich 0 aktiviert sie. NULL ist ungültig und führt zu INVALID_PARAMETER; ausgelassen gilt 1. Eine Meldung wird nur erzeugt, wenn der abschließende Status nicht AVAILABLE ist, und enthält Status sowie Kurztext, nicht ein zusätzliches Resultset. |
| `@Hilfe bit` | `0` | Numerische 0 führt die Analyse aus; jeder numerische Wert ungleich 0 aktiviert die Hilfe. NULL aktiviert die Hilfe nicht und wird in der anschließenden normalen Parameterprüfung als ungültig behandelt; ausgelassen gilt 0. Der Hilfezweig druckt die Hilfetexte, setzt @StatusCodeOut auf AVAILABLE und @IsPartialOut auf 0 und kehrt vor Katalogaufnahme zurück. @Json bleibt wegen der Initialisierung NULL. Der Zweig validiert keine übrigen Parameter. |
| `@StatusCodeOut varchar(40) OUTPUT` | `NULL` | OUTPUT varchar(40). Regulärer Rückgabestatus nach Auswertung der Datenbank-/Quellenaufnahme; bei @Hilfe=1 ausdrücklich AVAILABLE. Sämtliche Modulstatuswerte und ihre Bedeutung/Priorität: AVAILABLE = regulärer Abschluss ohne festgestellte Partialität; AVAILABLE_LIMITED = mindestens ein Datenbank-/Quellenbefund ist partiell und mindestens eine Quelle ist AVAILABLE; sonst wird der erste partielle Datenbankstatus nach Datenbankname übernommen. INVALID_PARAMETER = ungültige Ausgabeart, negatives @MaxZeilen oder NULL in den geprüften Bitparametern; dieser Parameterfehlerstatus hat vor der Kandidatenermittlung Vorrang. INTERNAL_ERROR = der Kandidatenhelfer kann die erwartete Kandidatentabelle nicht verwenden; dieser Status wird unverändert übernommen. DENIED_PERMISSION = Kandidatenvorbereitung oder Quelle scheitert mit einer der explizit klassifizierten Berechtigungsfehlernummern 229, 262, 297, 300, 371. SOURCE_UNAVAILABLE = Fehler 207 oder 208 beim Kandidaten-/Quellenzugriff. ERROR_HANDLED = sonstiger abgefangener Fehler der Kandidatenvorbereitung/Quelle. DATABASE_UNAVAILABLE = explizit angeforderte Datenbank wurde nicht als Kandidat verarbeitet. UNAVAILABLE_FEATURE = Regex kann wegen fehlender SQL Server 2025-/Compatibility-Level-170-Voraussetzung nicht ausgeführt werden. Auf Quellenebene zusätzlich: UNAVAILABLE_VERSION = external_models wird bei ProductMajorVersion <17 nicht gelesen und allein daraus folgt keine Partialität; AVAILABLE bedeutet erfolgreiche Quellenabfrage, auch bei null Zeilen; DENIED_PERMISSION, SOURCE_UNAVAILABLE und ERROR_HANDLED kennzeichnen fehlgeschlagene Abfragen. Partielle Datenbank ohne erfolgreiche Quelle übernimmt den ersten nicht erfolgreichen Quellenstatus nach fester Quellenrangfolge; bei mindestens einer erfolgreichen Quelle wird sie AVAILABLE_LIMITED. Der erste native Fehlerwert für das Top-Level wird nach Datenbankname und Quellenrangfolge gewählt. Ausgabe-/Mapping-Preflight kann Fehler werfen (51011), bevor reguläre Outputzuweisung erfolgt; der äußere Catch wirft wieder und setzt keine Status-Outputs. Für den Empfang Caller-Variable varchar(40) mit OUTPUT binden; ohne OUTPUT wird der Wert nicht empfangen. SYSTEM_DATABASE_EXCLUDED ist hier ein Auswahlwarnungscode, kein zusätzlicher Modulstatus: die zugehörige nicht verarbeitete angeforderte Datenbank wird als DATABASE_UNAVAILABLE in databaseStatus aufgenommen und kann zur Modulaggregation DATABASE_UNAVAILABLE oder AVAILABLE_LIMITED beitragen. Die feste Klasse STANDARD_CURRENT verlangt im Katalog kein Gruppengate; ihr Freigabepfad ergänzt keine Gruppen-/High-Impact-Statuswerte. |
| `@IsPartialOut bit OUTPUT` | `NULL` | Optionale OUTPUT-Bindung an eine bit-Variable. Hilfe liefert ausdrücklich 0. Die lokale Prüfung von Ausgabeart, Zeilenlimit und geprüften Bit-NULLs setzt INVALID_PARAMETER und 1. Eine partielle Datenbank-/Quellenaufnahme setzt ebenfalls 1. Zurückgegebene Statuswerte des Kandidatenhelfers, darunter INVALID_PARAMETER, INTERNAL_ERROR und UNAVAILABLE_FEATURE, setzen die anfangs mit 0 belegte Partialvariable dagegen nicht automatisch auf 1. Ein solcher Status kann daher mit 0 enden; 0 allein ist kein Nachweis einer erfolgreichen vollständigen Aufnahme. Ohne OUTPUT-Bindung wird der Wert nicht empfangen. Bei geworfenen Fehlern einschließlich TABLE-Vorprüfungsfehlern ist keine reguläre abschließende OUTPUT-Zuweisung garantiert. |

### Kopierbare Aufrufbeispiele

Die getrennten Aufrufe zeigen RAW, JSON mit den tatsächlich vorhandenen Diagnose-OUTPUTs und RETURN, einen TABLE-Teilexport und die Hilfe. Das TABLE-Ziel wird mit einer Seed-Spalte angelegt und in beiden Abschlusswegen entfernt.

```sql
EXEC [monitor].[USP_ExternalDataAnalysis] @MaxZeilen=200, @ResultSetArt='RAW', @PrintMeldungen=0;
```

```sql
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_ExternalDataAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Json AS [DiagnosticJson];
```

```sql
CREATE TABLE [#ExternalDataAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ExternalDataAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=N'{"databaseStatus":"#ExternalDataAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#ExternalDataAnalysis_HelpExample]; DROP TABLE IF EXISTS [#ExternalDataAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#ExternalDataAnalysis_HelpExample]; THROW; END CATCH;
```

```sql
EXEC [monitor].[USP_ExternalDataAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

RAW gibt moduleStatus, databaseStatus, dataSources, fileFormats, externalTables, modelSummary, sourceStatus und warnings als acht Resultsets in dieser Reihenfolge aus. TABLE schreibt die ausgewählten Resultsets in lokale, vorab geprüfte Temp-Tabellen. CONSOLE gibt eine formatierte Ansicht von databaseStatus aus; NONE unterdrückt fachliche Resultsets. Mit @JsonErzeugen=1 entsteht zusätzlich ein JSON-Dokument mit meta und denselben acht benannten Arrays; eine ResultSetArt JSON gibt es nicht. Die vollständigen Schemas stehen im [freigegebenen Vertrag](../../Architecture/WI0009_External_Data_Public_Specification.md).

Prüfen Sie zuerst moduleStatus, databaseStatus und sourceStatus, danach die Datenbankcounts und anschließend die Detailmengen. @MaxZeilen begrenzt je Ausgabegruppe dataSources, fileFormats, externalTables, modelSummary, sourceStatus und warnings; Counts beruhen auf der Sammlung vor diesen Ausgabelimits. Eine fehlgeschlagene Zählquelle liefert NULL für ihren Count; erfolgreich gelesene andere Quellen bleiben erhalten. Der erste native Fehlerwert auf Modulebene folgt Datenbankname und fester Quellenrangfolge.

## Eine Zeile bedeutet

Eine Quellen- oder Formatzeile beschreibt ein sichtbares lokales Katalogobjekt. Eine Tabellenzeile verbindet ausschließlich lokal sichtbare Kennungen. modelSummary zählt sichtbare Modelle ohne Modellidentitäten oder Inhalte.

## So lesen

VISIBLE bedeutet eine positive Kennung mit sichtbarer lokaler Gegenzeile. NOT_VISIBLE_IN_SCOPE beschreibt eine im erfolgreich gelesenen Katalog nicht sichtbare Gegenzeile. NULL/0-Kennungen sind NOT_APPLICABLE. Bei ausgefallener Referenzquelle erhalten positive Kennungen SOURCE_UNAVAILABLE. VisibleColumnCount zählt nur sichtbare sys.columns-Zeilen.

## Warum kann das problematisch sein?

Metadatenrechte begrenzen die Sichtbarkeit. Ein leerer erfolgreich gelesener Katalog belegt keine allgemeine Abwesenheit; eine nicht sichtbare Referenz beweist keinen defekten Fremdschlüssel. Ein Quellenfehler verhindert eine belastbare Anzahl dieser Quelle.

## Wann ist es kein Problem?

UNAVAILABLE_VERSION und NULL-Modellanzahl sind vor SQL Server 2025 erwartbar und setzen allein keine Partialität. NOT_APPLICABLE kann bei Quellen ohne Dateiformatreferenz korrekt sein. Keine dieser Aussagen erzeugt ein Gesundheitsurteil.

## Beispiele und Gegenbeispiele

```sql
DECLARE @ExampleJson nvarchar(max);
EXEC [monitor].[USP_ExternalDataAnalysis]
      @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE',
      @JsonErzeugen=1, @Json=@ExampleJson OUTPUT;
SELECT @ExampleJson AS [Json];
```

Eine sichtbare externe Tabelle ist eine lokale Definition. Ihre Zeile beweist weder erfolgreiche Abrufe noch erfolgreiche Authentifizierung.

## Leere oder partielle Ausgabe

Die sechs lokalen Quellen werden getrennt behandelt. Tatsächliche Fehlernummern und Meldungen bleiben in sourceStatus erhalten; Warnungstexte können verkürzt sein. Eine Quelle mit Status AVAILABLE kann null Zeilen liefern; der zugehörige Count ist dann 0. Für ProductMajorVersion unter 17 erhält external_models UNAVAILABLE_VERSION; dies allein setzt keine Partialität und die Modellanzahl bleibt NULL. Eine unbekannte Major-Version oder ein nicht verfügbarer aktueller Katalog kann SOURCE_UNAVAILABLE ergeben. Ein leeres ungefiltertes Datenbankscope kann AVAILABLE sein; explizit angeforderte, nicht verarbeitete Datenbanken werden DATABASE_UNAVAILABLE.

## Eigenlast und Grenzen

Die Eigenlast wächst mit der Zahl ausgewählter Datenbanken, Katalogzeilen und sichtbarer Spalten externer Tabellen. @MaxZeilen begrenzt Ausgaben, nicht die Sammlung oder Zahl der Datenbanken. Es gibt kein Sampling und keinen Remote-I/O-Pfad. Nonblocking-Katalogzugriffe und restaurierte LOCK_TIMEOUT-/XACT_ABORT-Werte begrenzen Nebenwirkungen; eine atomare Mehrquellenaufnahme wird nicht behauptet.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche lokalen externen Objekte und Referenzen sind im aktuellen sichtbaren Datenbankscope vorhanden?

### Technischer Hintergrund

Die Kataloge sind datenbanklokal. Schema- und Spaltenmetadaten werden getrennt aggregiert; die Modellquelle wird erst ab Major 17 dynamisch gelesen.

### Datenkette

sys.external_data_sources, sys.external_file_formats, sys.external_tables, sys.schemas, sys.columns und sys.external_models werden isoliert gesammelt. Counts beziehen sich auf die Sammlung vor Ausgabelimits.

### Source Select

```sql
SELECT [data_source_id], [name], [type], [type_desc]
FROM [sys].[external_data_sources] WITH(NOLOCK);
```

**Wichtig für die Eigenlast:** Die Quelle liest nur lokale Metadaten. Es wird weder eine externe Tabelle ausgewählt noch eine Location oder ein Credential gelesen.

### Zeit- und Scope-Modell

Quellenzeitpunkte beschreiben getrennte Katalogaufnahmen. Zwischen ihnen können Definitionen oder Sichtbarkeit wechseln. Die Ausgabe behauptet keinen atomaren Zustand und keine historische Nutzung.

### Bewertung und Gegenprobe

Vergleichen Sie native Kennungen und sichtbare Gegenzeilen im selben Datenbankscope. Eine gesondert autorisierte externe Nutzbarkeitsprüfung wäre eine andere Aufgabe und wird hier nicht ausgelöst.

### Typische Fehlinterpretation

Nicht sichtbare Referenzen sind keine nachgewiesenen Orphans. NULL-Anzahlen sind keine gemessenen Nullen. Erfolgreiche Metadatenabfragen sind keine erfolgreichen Remoteabfragen.

### Folgeanalyse

Die bestehende USP_SpecialFeatureInventory ergänzt aggregierten Featurekontext. Die neue Procedure verändert deren freigegebenen EXTERNAL_MODELS-Zeilenvertrag nicht.

## Primärquellen

- [Lokale Datenquellen](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-data-sources-transact-sql?view=sql-server-ver17)
- [Lokale Dateiformate](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-file-formats-transact-sql?view=sql-server-ver17)
- [Lokale externe Tabellen](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-tables-transact-sql?view=sql-server-ver17)
- [Lokale Modelle](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-models-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#monitorusp_externaldataanalysis)

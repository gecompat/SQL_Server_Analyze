# [monitor].[USP_IntelligentQueryProcessingAnalysis]

**Bereich:** Query Store und IQP<br>
**Zweck:** Zeigt Featureeignung, datenbankbezogene Konfiguration und aggregierte Feedbacksignale.<br>
**Beobachtungsart:** Konfigurationssnapshot + persistierte Feedbackhistorie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche IQP-Funktionen sind technisch möglich, konfiguriert und durch sichtbare Query-/Planfeedbacksignale belegt?** Sie unterstützt die Entscheidung, welche Konfiguration und welche aggregierte Evidenz anschließend mit einer konkreten Query-/Plananalyse geprüft werden sollen.

## Nicht beantwortete Fragen

Die Procedure bewertet weder einzelne Ausführungen noch die Wirksamkeit eines Features. Sie besitzt kein Zeitfenster und liest keine Query-Texte oder Showplans. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'RAW';
```

Der Procedurepfad ist immer als `CATALOG_DEEP` klassifiziert. `@HighImpactConfirmed = 1` ist unabhängig von Datenbankzahl und Zeilenlimit erforderlich; die Bestätigung ersetzt keine eigenständige Gruppenfreigabe. Ein Datenbankfilter begrenzt den Scope, `@MaxZeilen` wirkt erst nach vollständiger Sammlung.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Eingabe: optionale bracket-aware Pipe-Liste exakter Datenbanknamen; jeder Name kann als [Name] geklammert sein. NULL, leerer String oder nur äußere U+0020-Leerzeichen bedeuten keine Listenbegrenzung und wählen zusammen mit fehlendem Pattern alle sichtbaren, online befindlichen Datenbanken entsprechend dem Systemdatenbankschalter. Nichtleere Liste und Pattern sind exklusiv; leere Elemente und doppelte Namen sind ungültig. Nicht verfügbare Namen werden Warnungen. Systemdatenbanken erfordern zusätzlich @SystemdatenbankenEinbeziehen=1. CATALOG_DEEP ist immer aktiv und braucht @HighImpactConfirmed=1, auch bei einer Datenbank und kleinem Limit. Pipe trennt nur außerhalb von [...]; ]] maskiert eine schließende Klammer. Ein gültiger Name benötigt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | Eingabe: 0 schließt Systemdatenbanken aus; 1 nimmt sie in den Kandidatenscope auf. NULL ist ungültig. Gilt für Listen- und Patternauswahl; Opt-in erteilt keine CATALOG_DEEP-Bestätigung. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. 1 umgeht weder Online-/Sichtbarkeitsfilter noch Namens-/Patternauswahl. Die NULL-Prüfung erfolgt bei erreichter Datenbankvorbereitung. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Eingabe: optionaler Datenbanknamenfilter, exklusiv zu jeder nichtleeren @DatabaseNames-Liste. NULL bedeutet kein Pattern; ohne Liste werden sichtbare, online befindliche Datenbanken entsprechend dem Systemdatenbankschalter gewählt. Leeres oder nur aus äußeren U+0020-Leerzeichen bestehendes Pattern ist ungültig. Standardmodus LIKE mit den üblichen Wildcards % für beliebig viele und _ für genau ein Zeichen; Präfix LIKE:, REGEX: oder REGEXI: wählt LIKE, case-sensitive Regex (Flag c) oder case-insensitive Regex (Flag i). Außenliegende Leerzeichen werden entfernt; Inhalt nach Präfix nicht erneut. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Pattern begrenzt Datenbankkandidaten, nicht Feedbackzeilen. LIKE wird mit expliziter Framework-CS-Collation verglichen; auch Zeichenklassen [...] sind möglich. Präfixerkennung ist case-insensitiv. Leerer Rest nach jedem Präfix ist ungültig; Regex-Syntax wird nicht vorab geprüft. Die Zuweisung an nvarchar(4000) erfolgt vor der Parameterprüfung. |
| `@HighImpactConfirmed` | `bit` | `0` | Eingabe: 0 verweigert den stets aktivierten CATALOG_DEEP-Pfad mit Status HIGH_IMPACT_CONFIRMATION_REQUIRED; 1 bestätigt ihn. NULL ist ungültig. Die Bestätigung ist unabhängig von Zeilenlimit, Scopebreite und Gruppenzugehörigkeit; sie erteilt keine fehlende Gruppenfreigabe. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. Die Statusfolge setzt voraus, dass keine frühere Parameterablehnung die Auswahl verhindert; Hilfe kehrt vorher zurück. |
| `@MaxZeilen` | `int` | `1000` | Eingabe: ganzzahlig von 0 bis 2.147.483.647. Positive Werte begrenzen nach vollständiger Sammlung in RAW und JSON die Fachmengen databaseState, configuration, automaticTuning und signals jeweils getrennt mit TOP; Signale werden einmal materialisiert. NULL und 0 bedeuten unbegrenzt. Negative Werte liefern INVALID_PARAMETER, IsPartial=1 und leere Fachsammlungen. Das Limit begrenzt weder Datenbankauswahl/-cursor noch vorgelagerte Abfragen/Zählungen; Warnungen bleiben unbegrenzt. Kein HasMore-Indikator. Datenbankzustand wird nach DatabaseId, Konfiguration nach DatabaseId/ConfigurationName, Automatic Tuning nach DatabaseId/OptionName und Signale nach DatabaseId/SignalCode gewählt, jeweils aufsteigend. TABLE und aktive CONSOLE geben nur signals aus und versprechen keine physische Reihenfolge. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Eingabe: nach Trim und Großschreibung nur CONSOLE, RAW, TABLE oder NONE; NULL, leerer String und andere Werte sind ungültig. CONSOLE gibt ausschließlich Signals mit Ergebnisbeschriftung aus; leer erscheint eine verständliche Leerzeile. RAW gibt sechs Resultsets: Meta, DatabaseState, Configuration, AutomaticTuning, Signals und Errors. TABLE exportiert ausschließlich Signals. NONE erzeugt keine Resultsets. Ein nichtleeres @ResultTablesJson ist nur mit TABLE zulässig und löst sonst vor der Hilfeprüfung einen Fehler aus. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen; ein solcher Leerwert ist ungültig. Die Bindung an varchar(16) erfolgt vor der Prüfung. JSON bleibt unabhängig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Außerhalb TABLE sind ausgelassen/NULL, leer oder nur äußere U+0020-Leerzeichen zulässig; anderer nichtleerer Inhalt wirft vor Hilfe Fehler 51011. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem binär exakten Schlüssel signals (aggregierte IQP-Signale) erforderlich. Der Stringwert benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte und keiner Seed-Zeile; kein ##, LEN höchstens 116 und kein reserviertes #Monitor-Präfix. Unbekannte/doppelte Schlüssel, Nicht-Stringwerte oder ungültige Ziele scheitern im frühen ThrowOnError-Preflight vor Hilfe und Fachvalidierung. Der Writer ersetzt die Seed-Struktur durch die sechs Signalfelder. Andere IQP-Ergebnisgruppen können nicht über TABLE gemappt werden. |
| `@JsonErzeugen` | `bit` | `0` | Eingabe: 1 erzeugt unabhängig von ResultSetArt das JSON; 0 deaktiviert es. NULL verhält sich wie deaktiviert und wird nicht eigens validiert. Hilfe kehrt vorher zurück. JSON enthält meta, databaseState, configuration, automaticTuning, signals und warnings; Fachsammlungen folgen ihrem Limit. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. meta enthält Modulstatus/Partialität; databaseState die Eignung/Zustände, configuration die erfassten Optionen, automaticTuning die Tuningzustände, signals die aggregierten Zähler und warnings die Quellenfehler. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Ausgabe: wird sofort auf NULL zurückgesetzt. Bei normalem Lauf wird bei @JsonErzeugen=1 das Dokument gesetzt, sonst bleibt es NULL. Eingabewert wird ignoriert. Bei Hilfe bleibt es NULL; Parameter darf weggelassen werden. Zum Empfang eine nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Ohne OUTPUT-Bindung wird kein Wert an den Aufrufer übernommen. Bei ungefangenem THROW keine zugesicherte OUTPUT-Rückübertragung. |
| `@PrintMeldungen` | `bit` | `1` | Eingabe: derzeit vollständig unbenutzt. 0, 1 und NULL ändern weder PRINT-, Resultset-, JSON- noch Fehlerverhalten; keine Auswirkung auf Validierung. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@Hilfe` | `bit` | `0` | Eingabe: genau 1 gibt Hilfe per PRINT aus und kehrt vor normaler Validierung/Quellensammlung zurück; NULL oder 0 führen den normalen Pfad aus. @Json wird vorher auf NULL gesetzt; die vier Status-/Fehler-OUTPUT-Werte bleiben im Hilfepfad unverändert. Vor Hilfe kann ein nichtleeres Mapping bei Nicht-TABLE bereits einen Fehler werfen; TABLE führt zuerst den signals-Preflight aus. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | OUTPUT des abschließenden Modulstatus, kein Eingabefilter. Vollständige aktuelle Statusmenge: AVAILABLE (Sammlung ohne festgestellten Befund), AVAILABLE_WITH_FINDING (Sammlung mit Konfigurationsbefund), AVAILABLE_LIMITED (verfügbare, aber partielle Sammlung), DATABASE_UNAVAILABLE (kein auswertbarer Datenbankzustand), DENIED_PERMISSION (keine Zustandsmenge bei erfasstem Berechtigungsfehler), INVALID_PARAMETER (ungültiger Aufruf). Der Vorbereitungshelfer kann zusätzlich HIGH_IMPACT_CONFIRMATION_REQUIRED (fehlende Bestätigung), DENIED_GROUP (fehlende Gruppenfreigabe), UNAVAILABLE_FEATURE (nicht unterstützter Quellregex) oder INTERNAL_ERROR (interner Helfer-/Tabellenfehler) liefern. ERROR_HANDLED ist nur Quellenstatus, kein Modulstatus. Eine varchar(40)-Variable mit OUTPUT binden. Zuweisung vor JSON und fachlicher Ausgabe; bei Hilfe bleibt der Eingabewert unverändert. Bei ungefangenem THROW keine zugesicherte Rückübertragung. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | OUTPUT der Partialität, kein Eingabeschalter. 1 bei eigenem ungültigem Zeilenlimit/Ausgabemodus sowie erfassten Datenbank-/Quellfehlern oder Kandidatenwarnungen; 0 bei keiner festgestellten Partialität, auch eine Helfer-Gate-Ablehnung kann 0 behalten. Ein Limit allein setzt das Bit nicht. Eine bit-Variable mit OUTPUT binden. Zuweisung vor JSON und Ausgabe; bei Hilfe bleibt der Eingabewert einschließlich NULL unverändert. Bei ungefangenem THROW keine zugesicherte Rückübertragung. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Ausgabe: interne ErrorNumber wird im aktuellen Implementierungsstand nie gesetzt; normal daher NULL. Quellfehlernummern stehen in RAW Errors bzw. JSON warnings, nicht hier. Bei Hilfe bleibt Wert unverändert; Argument kann entfallen. Eine int-Variable mit OUTPUT binden; kein Eingabefilter. Zuweisung vor JSON und Ausgabe; bei ungefangenem THROW keine zugesicherte Rückübertragung. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Ausgabe: Modulvalidierungs- oder Helfermeldung, falls gesetzt; Meldung des ersten Quellfehlers wird nicht hierher kopiert. Quellfehler stehen in RAW Errors bzw. JSON warnings. Sonst normal NULL. Bei Hilfe bleibt Wert unverändert; Argument kann entfallen. Eine nvarchar(2048)-Variable mit OUTPUT binden; kein Eingabefilter. Zuweisung vor JSON und Ausgabe; bei ungefangenem THROW keine zugesicherte Rückübertragung. |

```sql
EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @Hilfe = 1;
```

```sql
EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames = N'[ExampleDatabase]', @HighImpactConfirmed = 1, @MaxZeilen = 100, @ResultSetArt = 'RAW';
```

```sql
DECLARE @JsonOut nvarchar(max);
EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames = N'[ExampleDatabase]', @HighImpactConfirmed = 1, @MaxZeilen = 100, @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @JsonOut OUTPUT;
SELECT @JsonOut AS [Json];
```

```sql
CREATE TABLE [#IntelligentQueryProcessingAnalysis_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='TABLE', @ResultTablesJson=N'{"signals":"#IntelligentQueryProcessingAnalysis_HelpExample"}';
 SELECT * FROM [#IntelligentQueryProcessingAnalysis_HelpExample];
 DROP TABLE IF EXISTS [#IntelligentQueryProcessingAnalysis_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#IntelligentQueryProcessingAnalysis_HelpExample];
 THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert ausschließlich `signals`: `DatabaseId`, `DatabaseName`, `SignalCode`, `IsSourceAvailable`, `EvidenceCount`, `Interpretation`. Nur `EvidenceCount` ist nullable; die drei Textspalten sind explizit `SQL_Latin1_General_CP1_CS_AS` collatiert. Die Exportquelle besitzt keine Identity. TABLE, CONSOLE, RAW und JSON verwenden dieselbe begrenzte Signalauswahl nach `DatabaseId, SignalCode`. CONSOLE ergänzt die Ergebnisbeschriftung; bei leerer Menge bleibt die dreifeldrige Leeranzeige erhalten. RAW liefert zusätzlich Meta, Datenbankzustand, Konfiguration, Automatic Tuning und Warnungen. JSON enthält `meta`, die vier Facharrays und `warnings`. Modulstatus und Partialität stammen aus der vollständigen Sammlung, einschließlich nicht ausgegebener Datenbankbefunde und Auswahlwarnings. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Datenbank, einer Configuration, Automatic-Tuning-Option oder einem aggregierten Signal.

## So lesen

Betrachten Sie Eligibility, Compatibility, Database-scoped Configurations, Query-Store-Zustand und Evidence Counts getrennt.

## Warum kann das problematisch sein?

Ein Feature kann versionsseitig geeignet, aber deaktiviert sein. Query Store OFF oder READ_ONLY kann persistentes Feedback begrenzen.

## Wann ist es kein Problem?

`EvidenceCount=0` beweist weder Erfolg noch Misserfolg; eventuell existierte keine geeignete Query oder keine persistierte Evidenz.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** PSP eligible, aber keine Query Variants: kein Fehler. Erst eine bekannte parameter-sensitive Query liefert eine sinnvolle Gegenprobe. Prüfen Sie Query Store und Showplan.

**Ähnlich aussehender Gegenfall:** `EvidenceCount=0` beweist weder Erfolg noch Misserfolg; eventuell existierte keine geeignete Query oder keine persistierte Evidenz. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Query Store kann nutzbar sein, obwohl Varianten-, Feedback- oder Empfehlungszähler null ergeben. Prüfen Sie Version, Compatibility Level, Capturemodus und Zustand; der Aufruf besitzt kein UTC-Fenster.

Für `USP_IntelligentQueryProcessingAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Ohne explizite Datenbankauswahl alle sichtbaren online befindlichen Benutzerdatenbanken und ein Ausgabelimit von 1000; gelesen werden IQP-/Query-Store-/Automatic-Tuning-Konfiguration und aggregierte Varianten-/Feedbacksignale, ohne Query-Text oder Showplan. |
| Teuerster Pfad | Alle sichtbaren Datenbanken und `@MaxZeilen = 0` bei sehr vielen Query-Store-Varianten, Plan-Feedbackzeilen und Tuningempfehlungen. Ein Zeitfenster- oder XML-Pfad existiert nicht. |
| Haupttreiber | Zahl gewählter Datenbanken sowie Query-Store-Varianten, Plan-Feedback- und Automatic-Tuning-Empfehlungszeilen. Konfigurationsquellen sind klein; unbegrenzte Feedback-/Variantenbestände dominieren, obwohl weder Querytext noch Showplan gelesen wird. |
| Skalierung | Feste Konfigurationszeilen bleiben klein; Aufwand wächst mit ausgewählten Datenbanken und sichtbaren Query-Variant-/Plan-Feedback-/Tuningzeilen. Keine Text-, Plan-XML- oder Intervallaggregation. |
| Ressourcen | CPU und Katalog-/Query-Store-Metadaten-I/O sowie dynamisches SQL/temporäre Signalresultate; Ergebnistransfer wächst mit der Signalmenge. |
| Begrenzungswirkung | Der Datenbankscope begrenzt Quellarbeit. `@MaxZeilen` begrenzt nach vollständiger Sammlung jedes der vier Fachresultsets getrennt. Für Signale wird die Menge einmal materialisiert und von allen Ausgabearten verwendet. NULL/0 bedeuten unbegrenzt; negative Werte liefern `INVALID_PARAMETER` mit `IsPartial=1` und leeren Fachmengen. Warnungen bleiben unbegrenzt. Das Limit begrenzt weder Datenbankcursor noch vorgelagerte Feedbackabfragen. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Procedurepfad ist immer als `CATALOG_DEEP` klassifiziert und verlangt `@HighImpactConfirmed = 1`; die Bestätigung ersetzt keine erforderliche Gruppenfreigabe und begrenzt den Scope nicht. |
| Sicherer Einsatz | Eine `ExampleDatabase`, Standardlimit und RAW zur Sicht auf Modulstatus und Warnungen. Die zwingende `CATALOG_DEEP`-Bestätigung nicht mit einer Freigabe für alle Datenbanken verwechseln; zunächst Status-/Versionspfad lesen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Konfigurationssnapshot + persistierte Feedbackhistorie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche IQP-Funktionen sind technisch möglich, konfiguriert und durch sichtbare Query-/Planfeedbacksignale belegt?

### Technischer Hintergrund

IQP umfasst unter anderem PSP, OPPO, Memory Grant Feedback, DOP/CE Feedback, Adaptive Joins, Deferred Compilation und weitere versions-/compatibilityabhängige Features. Database Scoped Configurations und Query-Store-basierte Feedbacks sind getrennte Ebenen.

### Datenkette

`sys.database_automatic_tuning_options`, `sys.database_query_store_options`, `sys.database_scoped_configurations`, `sys.databases`, `sys.dm_db_tuning_recommendations`, `sys.query_store_plan_feedback`, `sys.query_store_query_variant`, `sys.sp_executesql`.

### Source Select

Der Konfigurationspfad liest die ausgewählten IQP-Optionen im bestätigten Datenbankscope:

```sql
SELECT [name], CONVERT(nvarchar(4000), [value]) AS [ConfigurationValue],
       [is_value_default]
FROM [sys].[database_scoped_configurations] WITH (NOLOCK)
WHERE [name] IN
      (N'PARAMETER_SENSITIVE_PLAN_OPTIMIZATION', N'OPTIONAL_PARAMETER_OPTIMIZATION',
       N'MEMORY_GRANT_FEEDBACK_PERSISTENCE', N'MEMORY_GRANT_FEEDBACK_PERCENTILE_GRANT',
       N'DOP_FEEDBACK', N'CE_FEEDBACK', N'BATCH_MODE_MEMORY_GRANT_FEEDBACK',
       N'ROW_MODE_MEMORY_GRANT_FEEDBACK', N'BATCH_MODE_ADAPTIVE_JOINS',
       N'INTERLEAVED_EXECUTION_TVF', N'DEFERRED_COMPILATION_TV');
```

Version 16+ liest zusätzlich die Varianten- und Feedbackkataloge; ältere Engines liefern dafür `IsSourceAvailable=0` und `EvidenceCount=NULL`. Automatic-Tuning-Optionen und die Zahl aktueller Empfehlungen werden getrennt erfasst. Diese Abfragen sind nicht durch einen Query-Store-ON-Gate begrenzt. Die sechs Zustandsvergleiche auf OFF, READ_ONLY und READ_WRITE verwenden explizit Framework-CS, damit ein dynamischer Datenbankwechsel die Bewertung nicht durch kollidierende Kollationen verhindert.

**Wichtig für die Eigenlast:** Der Datenbankscope begrenzt die Quellarbeit. Das Ausgabelimit wird erst nach den vollständigen Varianten-, Feedback- und Empfehlungszählungen angewandt.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Versions-, Compatibility- und Configurationzustand sowie die persistierte, sichtbare Feedback- und Variantenevidenz.

### Bewertung und Gegenprobe

Trennen Sie `Eligible`, Configuration Value, Query Store State und Evidence Count. Ein Signal führt zur konkreten Query-/Plananalyse, nicht zur pauschalen Aktivierung/Deaktivierung.

### Typische Fehlinterpretation

`Eligible=1` ist kein Wirksamkeitsbeweis; `EvidenceCount=0` beweist weder fehlendes Problem noch Featureversagen.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Query Store Runtime/PlanChanges, Showplan und konkrete Parameterworkload.

## Primärquellen

- [Intelligent query processing](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#8-monitorusp_intelligentqueryprocessinganalysis)

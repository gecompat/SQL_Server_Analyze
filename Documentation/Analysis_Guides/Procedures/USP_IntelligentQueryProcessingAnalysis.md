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
      @ResultSetArt = 'CONSOLE';
```

Der datenbankweise IQP-Katalogpfad ist als `CATALOG_DEEP` geschützt. `@HighImpactConfirmed = 1` bestätigt die Policyfreigabe, begrenzt aber weder die Zahl der Datenbanken noch die dort vorhandenen Feedbackzeilen.

Alle `Example*`-Werte im Aufruf sind synthetisch.

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
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, Standardlimit und CONSOLE. Die zwingende `CATALOG_DEEP`-Bestätigung nicht mit einer Freigabe für alle Datenbanken verwechseln; zunächst Status-/Versionspfad lesen. |
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

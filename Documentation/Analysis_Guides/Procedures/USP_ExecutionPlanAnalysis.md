# [monitor].[USP_ExecutionPlanAnalysis]

**Bereich:** Plan Cache und Showplan<br>
**Zweck:** Analysiert genau ein direkt übergebenes oder gezielt beschafftes Showplan-XML statement- und operatorbezogen.<br>
**Beobachtungsart:** importierter, gecachter, letzter tatsächlicher, aktueller oder Query-Store-Plan<br>
**Kostenklasse:** MEDIUM bis HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure ist der eigenständig installierbare Einstieg für eine Plananalyse. Der direkte `@PlanXml`-Pfad benötigt weder Plan Cache noch Query Store. Statements, Operatoren, Runtime-Counter, Access Paths, verwendete Statistiken, Parameter, Planwarnungen, Optimizer-/Cachekontext, Feedback-/Variantenmerkmale, Memory Grants, Spills und Findings werden über dieselbe zentrale Engine verarbeitet wie der Framework-Multi-Plan-Pfad.

## Nicht beantwortete Fragen

Ein Plan allein liefert keine vollständige Workloadhistorie, keinen sicheren Geschäftsnutzen eines Indexes und keine Ursache außerhalb der sichtbaren Plan- und Runtimeevidenz. Estimated Cost ist keine gemessene Zeit. Query-Store- oder Compilepläne besitzen keine Actual Rows, wenn diese nicht aus einer getrennten Evidenzquelle stammen.

## Sicherer Einstieg

```sql
DECLARE @ExamplePlanXml xml = N'<ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" />';
EXEC [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml = @ExamplePlanXml
    , @AnalyseTiefe = 'STANDARD'
    , @WorkloadProfil = 'BALANCED'
    , @EvidenzDatenschutzModus = 'DERIVED_ONLY'
    , @ResultSetArt = 'CONSOLE';
```

Das Minimal-XML dient nur als synthetischer Aufrufrahmen; für fachliche Ergebnisse ist ein vollständiger Example-Showplan erforderlich. `FULL`, breite Statistikmodi und Histogramm-Steps benötigen `@HighImpactConfirmed = 1`.

`@MitSqlText = 1` gibt potentiell literalen oder proprietären SQL-Text aus und benötigt deshalb `@SensitiveDataConfirmed = 1`. Dasselbe gilt für `@EvidenzDatenschutzModus = 'RAW'`. Direkt übergebenes `@EvidenzJson` wird unabhängig von seiner Herkunft immer erneut auf den angeforderten Evidenz- und Identifier-Datenschutzmodus normalisiert; `DERIVED_ONLY` bleibt der Standard.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@PlanXml` | `xml` | `NULL` | Optionales bereits vorhandenes Plan-XML als SQL-Typ xml oder in diesen Typ konvertierbarer Text. Ein gesetzter Wert wählt IMPORTED exklusiv gegenüber PlanHandle, SessionIds und Query-Store-Paar. NULL wählt diese Quelle nicht; dann muss genau eine andere Quelle gesetzt sein. Leeres XML zählt als gesetzte Quelle, garantiert aber keinen auswertbaren Showplan. Wohlgeformte XML-Typkonvertierung ersetzt keine Showplan-Schemaprüfung. Die enthaltene Query wird niemals ausgeführt. |
| `@PlanHandle` | `varbinary(64)` | `NULL` | Binärwert als T-SQL-Hexliteral 0x… oder varbinary-Variable; der Typ fasst höchstens 64 Bytes. Kürzere Werte einschließlich 0x werden nicht separat abgewiesen und zählen als gesetzte Quelle. NULL lässt die Handlequelle ungesetzt. Ein unbekannter Handle liefert keinen Plan; die Beschaffung folgt @PlanQuelle. Es wird weder kompiliert noch SQL ausgeführt. Genau eine der Quellen PlanXml, PlanHandle, SessionIds oder vollständiges Query-Store-Paar darf gesetzt sein. |
| `@SessionIds` | `nvarchar(max)` | `NULL` | Optionale Liste genau einer Session-ID im Bereich 1 bis 32767. Der Parser akzeptiert Pipe, Komma und Semikolon als Trennzeichen sowie Leerraum um Elemente; eine leere gesamte Eingabe wird wie nicht gesetzt behandelt. Ungültige Elemente, mehrere IDs oder Werte außerhalb des Bereichs ergeben INVALID_PARAMETER. NULL/Leerwert lässt die Quelle ungesetzt. |
| `@RequestId` | `int` | `NULL` | Optionale ganze Request-ID ohne zusätzliche Bereichsprüfung. Sie filtert die aktuelle Planbeschaffung der gewählten Session. NULL ist bei höchstens einem verfügbaren Request zulässig; mehrere aktive Requests ohne RequestId erzeugen den intern abgefangenen Fehler 51031 und ERROR_HANDLED. Ohne Session wählt dieser Wert keine eigene Quelle; er wird aber als Parameter-Evidenzkontext an die Engine weitergegeben. |
| `@QueryStoreDatabaseName` | `sysname` | `NULL` | Ein einzelner Datenbankname als sysname, keine Liste oder Qualifierkette. Der Name wird als Datenwert mit QUOTENAME in den Datenbankkontext eingesetzt; äußere Klammern werden nicht als Bezeichnermaskierung entfernt. NULL wählt diese Quellhälfte nicht, leerer Text wird nicht in NULL normalisiert und kann bei der Beschaffung scheitern. QueryStorePlanId muss gemeinsam gesetzt sein, andere Planquellen sind ausgeschlossen. Quellenfehler werden abgefangen; Verfügbarkeit und Berechtigungen bleiben erforderlich. |
| `@QueryStorePlanId` | `bigint` | `NULL` | Ganze bigint-Plan-ID im Query Store der angegebenen Datenbank. NULL lässt diese Quellhälfte ungesetzt; QueryStoreDatabaseName muss gemeinsam gesetzt sein. Es besteht keine zusätzliche positive Bereichsprüfung. Nicht vorhandene IDs liefern ohne verfügbares XML UNAVAILABLE_OBJECT; Berechtigungsfehler werden gesondert ausgewiesen. |
| `@PlanQuelle` | `varchar(24)` | `'AUTO'` | Geschlossene Auswahl AUTO, COMPILE, LAST_ACTUAL; NULL wird wie AUTO behandelt; Trim/Großschreibung werden normalisiert, leer/unbekannt ergibt INVALID_PARAMETER. Nur für @PlanHandle: AUTO versucht zuerst sys.dm_exec_query_plan_stats mit dem letzten tatsächlichen Plan und fällt auf COMPILE zurück; COMPILE liest den kompilierten Plan mit sys.dm_exec_query_plan und kompiliert oder führt keine Abfrage aus; LAST_ACTUAL fordert den letzten tatsächlichen Plan an. Die effektive Planquelle kann IMPORTED, COMPILE, LAST_ACTUAL, CURRENT_ACTUAL oder QUERY_STORE sein. |
| `@StatementId` | `int` | `NULL` | Optionale ganze Statement-ID ohne zusätzliche Bereichsvalidierung. NULL deaktiviert den Filter. Der Wert wird für die Statistik-Evidenz und AUTO-Profilzuordnung benutzt und filtert danach fertige Statements samt abhängigen Ergebniszeilen. Er begrenzt nicht die vorgelagerte vollständige XML-Analyse der Engine. Eine nicht vorhandene ID kann leere Statement-/Detailmengen ergeben. |
| `@StatementQueryHash` | `binary(8)` | `NULL` | Optionaler 8-Byte-Queryhash als binary(8), vorzugsweise Hexliteral 0x mit genau 16 Hexziffern. NULL deaktiviert den Filter. SQL-Typkonvertierungen können kürzere oder längere Werte anpassen; es gibt keine zusätzliche Inhaltsprüfung. Der Hash beeinflusst AUTO-Profilzuordnungen und filtert nach der Analyse fertige Statements und abhängige Details, nicht die Beschaffung der Planquelle. |
| `@StatementQueryPlanHash` | `binary(8)` | `NULL` | Optionaler 8-Byte-Planhash als binary(8), vorzugsweise Hexliteral 0x mit genau 16 Hexziffern. NULL deaktiviert den Filter. SQL-Typkonvertierungen können Werte auffüllen oder kürzen; eine eigene Inhaltsprüfung fehlt. Er filtert nach der Analyse fertige Statements und abhängige Details und beschafft keinen Plan. |
| `@EvidenzJson` | `nvarchar(max)` | `NULL` | Optionales Execution-Evidence-JSON als Ausgangshülle; kein SQL-Befehl. NULL bedeutet keine importierte Evidenz, leerer Text ist ungültig. Erkannte Wurzelabschnitte sind statisticsIo, statisticsTime, statistics, objectReferences und predicateHistogramMappings; statistics enthält planUsage, currentSnapshot, histogramSummaries und histogramSteps. Die nachfolgenden JSON-Eingabeformen nennen alle projizierten Felder und SQL-Zieltypen. Die Hülle wird vor der Analyse immer durch USP_CreateExecutionEvidenceJson mit StrictValidation=1, RawTextHandling=HASH_ONLY und intern RAW-Identifikatoren normalisiert; die abschließende Analyseprojektion verwendet den angeforderten Identifikatormodus. Mit dem beschafften Plan stammen PlanUsage und Objektbezüge aus diesem XML; aktuelle importierte Arrays werden bei CURRENT_SERVER nicht geladen. Syntaxfehler werden im Helfer als INVALID_EVIDENCE_JSON abgefangen und markieren die Analyse partiell; die Analyse kann mit noch vorhandenen Daten fortfahren. Unbekannte Eigenschaften werden nicht als beliebige Zusatzdaten exportiert. Dies ist ein Eingabeformat des Evidence-Generators und kein erneut einzulesendes schemaVersion-3-Analyseergebnis. |
| `@StatisticsIoText` | `nvarchar(max)` | `NULL` | Optionaler, bereits erfasster STATISTICS IO-Meldungstext. NULL/Auslassen oder Leertext liefert keine daraus geparsten Zeilen. Der Text wird mit @StatisticsLanguage geparst; Teil- und Nicht-Erkennung bleibt als ParseStatus sichtbar. 053 setzt keine StatementOrdinal-Zuordnung und hat keinen öffentlichen Rohtextmodus; exportierter Rohtext wird nicht durch diesen Parameter gesteuert. |
| `@StatisticsTimeText` | `nvarchar(max)` | `NULL` | Optionaler, bereits erfasster STATISTICS TIME-Meldungstext. NULL/Auslassen oder Leertext liefert keine daraus geparsten Zeilen. Der Parser kennzeichnet teilweise oder unbekannte Formate statt fehlende Messwerte zu erfinden; er erkennt englische/deutsche Textteile. 053 setzt keine StatementOrdinal-Zuordnung und hat keinen öffentlichen Rohtextmodus. |
| `@StatisticsLanguage` | `varchar(16)` | `'AUTO'` | AUTO erkennt unterstützte Meldungsteile automatisch; EN bezeichnet Englisch und DE Deutsch. Der IO-Parser normalisiert Groß-/Kleinschreibung und fällt bei NULL, leerem oder unbekanntem Code auf AUTO zurück. Der TIME-Parser verwendet die Kennung nicht und erkennt seine englischen/deutschen Textteile selbst. Es entsteht kein INVALID_PARAMETER für einen unbekannten Sprachcode. |
| `@StatistikEvidenzModus` | `varchar(16)` | `'PLAN_ONLY'` | Zulässig sind NONE, PLAN_ONLY, USED, RELEVANT und OBJECT_ALL. NONE überspringt die Extraktion von Statistiknutzung aus dem übergebenen Plan. PLAN_ONLY extrahiert diese Compile-Evidenz ohne aktuelle Katalogabfrage. USED ergänzt aktuelle Metadaten der im Plan verwendeten Statistiken. RELEVANT ergänzt diese um Statistiken, deren führende Spalte einer im Plan referenzierten Predicate-Spalte entspricht. OBJECT_ALL ergänzt alle Statistiken der referenzierten Planobjekte. Aktuelle Ergänzungen benötigen aufgelöstes Plan-XML und CURRENT_SERVER; die beiden breiten Modi benötigen High-Impact-Bestätigung. Importierte Statistikarrays werden durch NONE nicht pauschal entfernt. NULL fällt auf PLAN_ONLY zurück; äußere Leerzeichen und Groß-/Kleinschreibung werden normalisiert. Leerer oder unbekannter Code ist INVALID_PARAMETER. RELEVANT und OBJECT_ALL lösen das äußere High-Impact-Gate schon bei Anforderung aus, auch mit EVIDENCE_ONLY. |
| `@HistogrammModus` | `varchar(16)` | `'NONE'` | geschlossene Auswahl NONE, SUMMARY, STEPS. NULL wird wie NONE behandelt; Trim und Großschreibung normalisieren Werte, unbekannte Werte sind INVALID_PARAMETER. NONE erhebt keine Histogramme; SUMMARY liefert Zusammenfassungen; STEPS liefert Histogrammschritte. SUMMARY und STEPS benötigen @MetadatenQuellenmodus=CURRENT_SERVER sowie @StatistikEvidenzModus USED, RELEVANT oder OBJECT_ALL; sonst INVALID_PARAMETER. |
| `@MetadatenQuellenmodus` | `varchar(16)` | `'EVIDENCE_ONLY'` | Zulässig sind EVIDENCE_ONLY und CURRENT_SERVER. EVIDENCE_ONLY verarbeitet übergebene Plan-/JSON-/Meldungsevidenz ohne aktuelle Statistikabfragen. CURRENT_SERVER ruft die aktuelle Erhebung nur mit aufgelöstem Plan-XML und Statistikmodus USED, RELEVANT oder OBJECT_ALL auf; importierte currentSnapshot-, Histogramm- und Predicate-Mapping-Arrays werden dann nicht geladen, auch wenn keine Erhebung stattfindet. 0 bei @QuellumgebungBestaetigt führt zu SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED; NULL kann den Vergleich <>1 umgehen. NULL als Quellenmodus bedeutet EVIDENCE_ONLY; Trim und Großschreibung werden normalisiert. Leerer oder unbekannter Code ist INVALID_PARAMETER. |
| `@QuellumgebungBestaetigt` | `bit` | `0` | 0 bestätigt die Quellumgebung nicht; 1 bestätigt, dass CURRENT_SERVER der tatsächlichen Quelle entspricht. CURRENT_SERVER wird bei 0 mit SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED abgewiesen. NULL wird wegen des Vergleichs <>1 nicht zuverlässig abgewiesen und darf nicht als Bestätigung verwendet werden. Ohne CURRENT_SERVER ist der Schalter ohne Erhebungswirkung. Die Bestätigung ersetzt weder Berechtigungen noch einen Herkunftsnachweis. T-SQL konvertiert numerische Nichtnullwerte vor der Procedureprüfung zu bit 1; verwenden Sie ausdrücklich 0 oder 1. |
| `@MitPredicateHistogramMap` | `bit` | `1` | 0 überspringt den Collector-Pfad für Predicate-/Histogrammzuordnung; 1 aktiviert ihn bei tatsächlich aufgerufener aktueller Erhebung. NULL passiert die NOT-IN-Prüfung und aktiviert IF=1 nicht. Der Schalter unterdrückt keine bereits importierten Mappingzeilen. T-SQL konvertiert numerische Nichtnullwerte vor der Procedureprüfung zu bit 1; verwenden Sie ausdrücklich 0 oder 1. |
| `@AnalyseTiefe` | `varchar(16)` | `'STANDARD'` | Geschlossene Auswahl SUMMARY, STANDARD, FULL. NULL wird wie STANDARD behandelt; Trim/Großschreibung normalisieren, leer/unbekannt ergibt INVALID_PARAMETER. 053 übergibt die normalisierte Tiefe nicht an 051; FULL fordert zusätzlich die High-Impact-Klasse SHOWPLAN_XML_DEEP an. Wenn der optionale Pfadprüfer installiert ist, wird HighImpactConfirmed=NULL dort abgewiesen; ohne diesen Prüfer ist keine zusätzliche NULL-Bestätigung garantiert. |
| `@WorkloadProfil` | `varchar(32)` | `'AUTO'` | AUTO oder Profilcode; NULL wird wie AUTO behandelt, Trim/Großschreibung normalisieren. AUTO löst lokale enabled Zuordnungen anhand Plan- und Kontextmerkmalen auf; ein QueryHash kann dabei zuordnen. Seed-Codes: LATENCY_SENSITIVE gewichtet interaktive/häufige Zugriffe stärker; BALANCED ist neutral; THROUGHPUT gewichtet absolute Ressourcen/Datenmengen; MAINTENANCE berücksichtigt erwartbare große Scans/Sorts; UNKNOWN kennzeichnet geringe Zuordnungssicherheit. Weitere lokal konfigurierte Profile bilden eine offene Menge. Unbekannte oder deaktivierte Codes lösen keinen INVALID_PARAMETER aus, sondern fallen auf BALANCED zurück. |
| `@Regelsatz` | `varchar(32)` | `'DEFAULT'` | Ausschließlich DEFAULT ist unterstützt. NULL wird wie DEFAULT behandelt; Trim/Großschreibung normalisieren. Andere Codes ergeben INVALID_PARAMETER; ein konfigurierbarer zusätzlicher Regelsatz ist nicht implementiert. |
| `@MinSchweregrad` | `varchar(16)` | `'INFO'` | Geschlossene Auswahl INFO, LOW, MEDIUM, HIGH, CRITICAL; NULL wird wie INFO behandelt. Trim/Großschreibung normalisieren; leer/unbekannt ist INVALID_PARAMETER. Legt die untere Findings-Schweregradgrenze fest, nicht die Analysequelle. |
| `@MitThreadRuntime` | `bit` | `0` | 0 entfernt die bereits materialisierten Thread-Laufzeitzeilen vor der Ausgabe; 1 behält vorhandene Threadzähler bei. NULL passiert NOT IN (0,1) und führt die IF=0-Löschung nicht aus: vorhandene Threadzeilen können bleiben, obwohl die THREAD_RUNTIME-Capability bei IF=1 nicht als angefordert gilt. NULL ist deshalb kein verlässlicher Ausschalter. T-SQL konvertiert numerische Nichtnullwerte vor der Procedureprüfung zu bit 1; verwenden Sie ausdrücklich 0 oder 1. |
| `@MitSqlText` | `bit` | `0` | 0 setzt StatementText vor der Ausgabe auf NULL. 1 behält Statementtext bei und prüft SensitiveDataConfirmed; bei 0 als Bestätigung folgt SENSITIVE_DATA_CONFIRMATION_REQUIRED. NULL passiert NOT IN (0,1), aktiviert die IF=1-Bestätigungsprüfung nicht und auch die IF=0-Unterdrückung nicht: Statementtext kann damit ohne ausdrückliche Bestätigung ausgegeben werden. Dies ist eine bestehende Prüflücke, keine empfohlene Eingabe. Verwenden Sie ausdrücklich 0 oder 1. T-SQL konvertiert numerische Nichtnullwerte vor der Procedureprüfung zu bit 1; verwenden Sie ausdrücklich 0 oder 1. |
| `@EvidenzDatenschutzModus` | `varchar(24)` | `'DERIVED_ONLY'` | Geschlossene Auswahl DERIVED_ONLY, TOKENIZED, STRUCTURE_ONLY, RAW. NULL wird wie DERIVED_ONLY behandelt; Trim/Großschreibung normalisieren, unbekannter Code ergibt INVALID_PARAMETER. DERIVED_ONLY gibt abgeleitete Werte ohne konkrete Parameter-/Predicate-/Histogrammgrenzwerte aus; TOKENIZED ersetzt sensible Werte durch laufzeitlokale Tokens; STRUCTURE_ONLY beschränkt sensible Inhalte auf Struktur; RAW gibt konkrete Werte aus und benötigt @SensitiveDataConfirmed=1. Der Schalter beeinflusst die Analyseausgabe, nicht die Beschaffung der Planquelle. |
| `@IdentifierDatenschutzModus` | `varchar(16)` | `'RAW'` | Geschlossene Auswahl RAW, TOKENIZED, OMIT. NULL wird wie RAW behandelt; Trim/Großschreibung normalisieren, unbekannter Code ergibt INVALID_PARAMETER. RAW erhält Objekt-/Identifikatorwerte, TOKENIZED ersetzt sie durch laufzeitlokale Tokens, OMIT lässt sie aus. Ein zusätzlicher Rohtextmodus ist in 053 nicht vorhanden. |
| `@SensitiveDataConfirmed` | `bit` | `0` | Bit-Bestätigung: 1 erlaubt die angeforderten sensiblen Ausgaben, insbesondere Evidenzmodus RAW und @MitSqlText=1; 0 bestätigt nicht und führt für diese Pfade zu SENSITIVE_DATA_CONFIRMATION_REQUIRED. NULL kann wegen SQL-UNKNOWN Vergleiche <>1 umgehen und ist keine ausdrückliche Bestätigung; die Laufzeitlücke wird hier nur dokumentiert. Es gibt in 053 keinen INCLUDE-Rohzeilenmodus und keine additionalEvidence-Einbettung. T-SQL konvertiert numerische Nichtnullwerte vor der Procedureprüfung zu bit 1; verwenden Sie ausdrücklich 0 oder 1. |
| `@MaxOperatoren` | `int` | `50000` | Positive ganze Zahl; NULL oder Wert <1 ergibt INVALID_PARAMETER, eine obere Grenze wird nicht validiert. Die Operatorbegrenzung wird nach der Analyse angewandt und bereinigt abhängige Detailzeilen; sie begrenzt nicht die vorgelagerte Analysearbeit. |
| `@MaxFindings` | `int` | `5000` | Positive ganze Zahl als Höchstzahl der Findings; NULL oder Wert <1 ergibt INVALID_PARAMETER. Es gibt keine obere Bereichsvalidierung; weitere Findings können dadurch außerhalb der Ausgabe bleiben. |
| `@MaxStatistiken` | `int` | `100` | Begrenzung der Zahl aktueller Statistiken. NULL ist unzulässig; gültiger Bereich 1 bis 1000 einschließlich, andernfalls INVALID_PARAMETER. Der Grenzwert wirkt auf die zielgerichtete aktuelle Statistikerhebung. |
| `@MaxHistogrammSchritte` | `int` | `20000` | Begrenzung der erhobenen Histogrammschritte. NULL ist unzulässig; gültiger Bereich 0 bis 200000 einschließlich, andernfalls INVALID_PARAMETER. Der Grenzwert beschränkt Histogrammvertiefung; 0 erlaubt keine Histogrammschritte. |
| `@MaxDurationSeconds` | `int` | `30` | Ganzzahlige Deadline in Sekunden, gültig 1 bis 3600 einschließlich; NULL/außerhalb ergibt INVALID_PARAMETER. Die Prozedur prüft kooperativ einmal nach Analyse und Capability-Ermittlung gegen diese Deadline; sie bricht die Analyse nicht hart ab und erzwingt keine frühe Unterbrechung. |
| `@LockTimeoutMs` | `int` | `0` | Ganzzahlige Zeitgrenze in Millisekunden für optionale aktuelle Metadatenerhebung, gültig 0 bis 60000 einschließlich; NULL/außerhalb ergibt INVALID_PARAMETER. An den Collector weitergereicht. Die anfängliche eigene Temp-Tabellenanlage setzt im TRY LOCK_TIMEOUT 100 ms und setzt danach beziehungsweise im Fehlerpfad auf 0 zurück. |
| `@HighImpactConfirmed` | `bit` | `0` | 0 bestätigt nicht; 1 bestätigt den angeforderten High-Impact-Pfad, verleiht aber keine Berechtigung. Schon die Anforderung FULL, Statistikmodus RELEVANT oder OBJECT_ALL oder Histogrammmodus STEPS löst das äußere Gate aus, auch ohne aktuelle Metadatenerhebung. Bei 0 folgt HIGH_IMPACT_CONFIRMATION_REQUIRED. Ist InternalCheckAnalysisPath installiert, prüft er zusätzlich SHOWPLAN_XML_DEEP und weist NULL ausdrücklich als INVALID_PARAMETER ab. In der eigenständigen Installation ohne diesen Helfer kann NULL den äußeren <>1-Vergleich umgehen; es ist keine Bestätigung. T-SQL konvertiert numerische Nichtnullwerte vor der Procedureprüfung zu bit 1; verwenden Sie ausdrücklich 0 oder 1. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Geschlossene Auswahl CONSOLE, RAW, TABLE, NONE. NULL/Leertext/anderer Code ergibt INVALID_PARAMETER; Trim/Großschreibung normalisieren. CONSOLE ruft den Console-Helper mit findings als Eingabe auf; RAW gibt 22 benannte Tabellen als getrennte Resultsets aus; TABLE schreibt die angeforderten Resultate in benannte Ziele; NONE emittiert keine Resultsets. Die JSON-Ausgabe ist davon unabhängig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Im TABLE-Modus erforderliches JSON-Objekt mit mindestens einer Zuordnung von erlaubtem Resultatnamen auf vorhandene, leere lokale #Temp-Zieltabelle mit genau einer Seed-Spalte. Geschlossene Schlüssel: moduleStatus, capabilities, planDocuments, statements, operatorTree, operatorRuntime, operatorThreadRuntime, accessPaths, statisticsUsage, parametersAndVariants, parameters, planWarnings, optimizerContext, runtimeFeedback, queryStoreContext, feedbackAndVariants, memoryAndSpills, executionEvidence, histogramSummaries, histogramSteps, predicateHistogramMappings, findings. Zeichenkettenwerte nennen Zieltabellen; Helperregeln zu vorhandenen Tabellen/Spalten, Namen und eindeutigen Zuordnungen gelten. NULL/Auslassen in TABLE ist ungültig; außerhalb TABLE führt ein gesetztes Argument zu INVALID_PARAMETER. Vorbereitungsfehler werden vor dem Analyse-CATCH ausgelöst. Zielnamen dürfen höchstens 116 Zeichen lang sein; keine globalen ##-, permanenten oder reservierten #Monitor*-Tabellen. Doppelte Schlüssel oder gleiche Ziele für mehrere Resultate werden abgelehnt. Die Vorbereitung liegt nach dem Hilfe-RETURN. |
| `@JsonErzeugen` | `bit` | `0` | Bit-Schalter: 1 erzeugt das kanonische Analyse-JSON im OUTPUT-Parameter @Json; 0 lässt ihn NULL. NULL passiert die NOT IN Prüfung und erzeugt wegen IF=1 kein JSON. Das JSON wird unabhängig von ResultSetArt erzeugt. T-SQL konvertiert numerische Nichtnullwerte vor der Procedureprüfung zu bit 1; verwenden Sie ausdrücklich 0 oder 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Als nvarchar(max)-Variable mit OUTPUT binden; der Anfangswert wird beim Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 enthält es schemaVersion 3 und meta sowie Arrays capabilities, planDocuments, statements, operatorTree, operatorRuntime, operatorThreadRuntime, accessPaths, statisticsUsage, parametersAndVariants, parameters, planWarnings, optimizerContext, runtimeFeedback, queryStoreContext, feedbackAndVariants, memoryAndSpills, executionEvidence, histogramSummaries, histogramSteps, predicateHistogramMappings und findings. Bei 0/NULL bleibt der Wert NULL. Ohne OUTPUT-Bindung empfängt der Aufrufer ihn nicht; ResultSetArt ist unabhängig. |
| `@PrintMeldungen` | `bit` | `1` | 1 gibt bei Status außerhalb AVAILABLE eine Severity-10-Meldung mit RAISERROR WITH NOWAIT aus; 0 oder NULL unterdrückt diese zusätzliche Statusmeldung. Die Ausgabe von @Hilfe bleibt davon unabhängig. T-SQL konvertiert numerische Nichtnullwerte vor der Procedureprüfung zu bit 1; verwenden Sie ausdrücklich 0 oder 1. |
| `@Hilfe` | `bit` | `0` | 1 druckt die eingebaute Kurzreferenz und kehrt vor Parameterprüfung, TABLE-Vorbereitung und Erhebung zurück; 0 oder NULL folgt dem normalen Pfad. Beim Eintritt wird @Json auf NULL sowie Status-OUTPUTs auf AVAILABLE, 0, NULL und NULL gesetzt. Der vorangestellte SET LOCK_TIMEOUT 0 bleibt wirksam. T-SQL konvertiert numerische Nichtnullwerte vor der Procedureprüfung zu bit 1; verwenden Sie ausdrücklich 0 oder 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Als varchar(40)-Variable mit OUTPUT binden. Beginnt mit AVAILABLE und enthält den abschließenden Maschinenstatus der Prozedur, unter anderem Validierungs-, Bestätigungs- oder Analysefehler. Der Status steht in der Tabelle moduleStatus und im meta.statusCode des JSON; er ist nicht Teil von captureStatus. Der Anfangswert wird auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert empfangen. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Als bit-Variable mit OUTPUT binden. Beginnt mit 0 und markiert bei 1 eine begrenzte/unvollständige Analyse, etwa nach Status- oder Fehlerfällen. Im JSON und moduleStatus wird der Partialstatus ebenfalls geführt. Anfangswert wird auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert empfangen. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Als int-Variable mit OUTPUT binden. Anfangs NULL; bei abgefangener Analyseausnahme wird die SQL-Fehlernummer ausgegeben. Ohne abgefangenen Fehler bleibt NULL. Der Anfangswert wird auch im Hilfepfad zurückgesetzt. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Als nvarchar(2048)-Variable mit OUTPUT binden. Anfangs NULL; bei Verarbeitungsfehlern wird eine begrenzte Fehlermeldung ausgegeben. Ohne Fehler bleibt NULL. Der Anfangswert wird auch im Hilfepfad zurückgesetzt. |

## JSON-Eingabeformen

Die folgenden JSON-Pfade beschreiben die erkannten Objektfelder und SQL-Zieltypen, keine strikte JSON-Schema-Validierung. Zahlen werden in die angegebenen SQL-Zahltypen, bit in 0/1, Texte in die angegebenen Zeichenlängen und Zeitstempel in datetime2 konvertiert. sysname entspricht nvarchar(128). Namen und Pfade sind in der angegebenen Schreibweise zu übergeben. Fehlende Eigenschaften werden als NULL projiziert; Konvertierungs- oder NOT-NULL-Zielverletzungen können im Evidence-Helfer ERROR_HANDLED auslösen; die Einplananalyse weist dessen Fehler als partielle Evidenz aus. Nicht erkannte Eigenschaften werden ignoriert. Arrays enthalten jeweils Objekte; importierte Status-/Kategorietexte besitzen hier keine geschlossene validierte Wertemenge.

### `$.statisticsIo`

`statementOrdinal` hat SQL-Zieltyp `int`. `messageOrdinal` hat SQL-Zieltyp `int`. `objectOrdinal` hat SQL-Zieltyp `int`. `objectDisplayName` hat SQL-Zieltyp `nvarchar(512)`. `scanCount` hat SQL-Zieltyp `bigint`. `logicalReads` hat SQL-Zieltyp `bigint`. `physicalReads` hat SQL-Zieltyp `bigint`. `pageServerReads` hat SQL-Zieltyp `bigint`. `readAheadReads` hat SQL-Zieltyp `bigint`. `pageServerReadAheadReads` hat SQL-Zieltyp `bigint`. `lobLogicalReads` hat SQL-Zieltyp `bigint`. `lobPhysicalReads` hat SQL-Zieltyp `bigint`. `lobPageServerReads` hat SQL-Zieltyp `bigint`. `lobReadAheadReads` hat SQL-Zieltyp `bigint`. `lobPageServerReadAheadReads` hat SQL-Zieltyp `bigint`. `languageDetected` hat SQL-Zieltyp `varchar(16)`. `parseStatus` hat SQL-Zieltyp `varchar(40)`.

### `$.statisticsTime`

`statementOrdinal` hat SQL-Zieltyp `int`. `messageOrdinal` hat SQL-Zieltyp `int`. `timeCategory` hat SQL-Zieltyp `varchar(24)`. `cpuMs` hat SQL-Zieltyp `bigint`. `elapsedMs` hat SQL-Zieltyp `bigint`. `languageDetected` hat SQL-Zieltyp `varchar(16)`. `parseStatus` hat SQL-Zieltyp `varchar(40)`.

### `$.statistics.planUsage`

`statisticsUsageOrdinal` hat SQL-Zieltyp `bigint`. `statementOrdinal` hat SQL-Zieltyp `int`. `statementId` hat SQL-Zieltyp `int`. `statementCompId` hat SQL-Zieltyp `int`. `databaseName` hat SQL-Zieltyp `sysname`. `schemaName` hat SQL-Zieltyp `sysname`. `objectName` hat SQL-Zieltyp `sysname`. `statisticsName` hat SQL-Zieltyp `sysname`. `lastUpdateAtCompile` hat SQL-Zieltyp `datetime2(7)`. `modificationCountAtCompile` hat SQL-Zieltyp `bigint`. `samplingPercentAtCompile` hat SQL-Zieltyp `decimal(19,6)`. `sourceElement` hat SQL-Zieltyp `nvarchar(128)`. `parseStatus` hat SQL-Zieltyp `varchar(40)`.

### `$.objectReferences`

`referenceOrdinal` hat SQL-Zieltyp `bigint`. `statementOrdinal` hat SQL-Zieltyp `int`. `statementId` hat SQL-Zieltyp `int`. `statementCompId` hat SQL-Zieltyp `int`. `nodeId` hat SQL-Zieltyp `int`. `referenceType` hat SQL-Zieltyp `varchar(40)`. `referenceSource` hat SQL-Zieltyp `varchar(40)`. `databaseName` hat SQL-Zieltyp `sysname`. `schemaName` hat SQL-Zieltyp `sysname`. `objectName` hat SQL-Zieltyp `sysname`. `indexName` hat SQL-Zieltyp `sysname`. `aliasName` hat SQL-Zieltyp `sysname`. `storageType` hat SQL-Zieltyp `nvarchar(128)`. `planObjectId` hat SQL-Zieltyp `int`. `planIndexId` hat SQL-Zieltyp `int`. `isTemporaryObject` hat SQL-Zieltyp `bit`. `isTableVariable` hat SQL-Zieltyp `bit`. `isRemoteObject` hat SQL-Zieltyp `bit`. `isDmlTarget` hat SQL-Zieltyp `bit`. `resolutionCapability` hat SQL-Zieltyp `varchar(40)`. `sourceElement` hat SQL-Zieltyp `nvarchar(128)`.

### `$.statistics.currentSnapshot`

`databaseName` hat SQL-Zieltyp `sysname`. `schemaName` hat SQL-Zieltyp `sysname`. `objectName` hat SQL-Zieltyp `sysname`. `objectId` hat SQL-Zieltyp `int`. `statisticsName` hat SQL-Zieltyp `sysname`. `statisticsId` hat SQL-Zieltyp `int`. `isIndexStatistics` hat SQL-Zieltyp `bit`. `isAutoCreated` hat SQL-Zieltyp `bit`. `isUserCreated` hat SQL-Zieltyp `bit`. `isFiltered` hat SQL-Zieltyp `bit`. `filterDefinition` hat SQL-Zieltyp `nvarchar(max)`. `noRecompute` hat SQL-Zieltyp `bit`. `isIncremental` hat SQL-Zieltyp `bit`. `hasPersistedSample` hat SQL-Zieltyp `bit`. `leadingColumnName` hat SQL-Zieltyp `sysname`. `lastUpdated` hat SQL-Zieltyp `datetime2(7)`. `rows` hat SQL-Zieltyp `bigint`. `rowsSampled` hat SQL-Zieltyp `bigint`. `samplePercent` hat SQL-Zieltyp `decimal(19,6)`. `steps` hat SQL-Zieltyp `int`. `unfilteredRows` hat SQL-Zieltyp `bigint`. `modificationCounter` hat SQL-Zieltyp `bigint`. `modificationPercent` hat SQL-Zieltyp `decimal(19,6)`. `persistedSamplePercent` hat SQL-Zieltyp `float`. `collectionStatus` hat SQL-Zieltyp `varchar(40)`.

### `$.statistics.histogramSummaries`

`databaseName` hat SQL-Zieltyp `sysname`. `schemaName` hat SQL-Zieltyp `sysname`. `objectName` hat SQL-Zieltyp `sysname`. `statisticsName` hat SQL-Zieltyp `sysname`. `statisticsId` hat SQL-Zieltyp `int`. `leadingColumnName` hat SQL-Zieltyp `sysname`. `histogramSteps` hat SQL-Zieltyp `int`. `histogramEstimatedRows` hat SQL-Zieltyp `float`. `maxEqualRows` hat SQL-Zieltyp `float`. `maxRangeRows` hat SQL-Zieltyp `float`. `maxStepRows` hat SQL-Zieltyp `float`. `dominantStepPercent` hat SQL-Zieltyp `decimal(19,6)`. `tailStepRows` hat SQL-Zieltyp `float`. `tailStepPercent` hat SQL-Zieltyp `decimal(19,6)`. `collectionStatus` hat SQL-Zieltyp `varchar(40)`.

### `$.statistics.histogramSteps`

`databaseName` hat SQL-Zieltyp `sysname`. `schemaName` hat SQL-Zieltyp `sysname`. `objectName` hat SQL-Zieltyp `sysname`. `statisticsName` hat SQL-Zieltyp `sysname`. `statisticsId` hat SQL-Zieltyp `int`. `leadingColumnName` hat SQL-Zieltyp `sysname`. `stepOrdinal` hat SQL-Zieltyp `int`. `rangeHighKey` hat SQL-Zieltyp `nvarchar(4000)`. `rangeRows` hat SQL-Zieltyp `float`. `equalRows` hat SQL-Zieltyp `float`. `distinctRangeRows` hat SQL-Zieltyp `bigint`. `averageRangeRows` hat SQL-Zieltyp `float`. `isPredicateTarget` hat SQL-Zieltyp `bit`. `predicateMatchCount` hat SQL-Zieltyp `int`.

### `$.predicateHistogramMappings`

`predicateReferenceId` hat SQL-Zieltyp `bigint`. `statementOrdinal` hat SQL-Zieltyp `int`. `nodeId` hat SQL-Zieltyp `int`. `databaseName` hat SQL-Zieltyp `sysname`. `schemaName` hat SQL-Zieltyp `sysname`. `objectName` hat SQL-Zieltyp `sysname`. `columnName` hat SQL-Zieltyp `sysname`. `statisticsName` hat SQL-Zieltyp `sysname`. `predicateKind` hat SQL-Zieltyp `varchar(40)`. `valueSource` hat SQL-Zieltyp `varchar(32)`. `mappingStatus` hat SQL-Zieltyp `varchar(48)`. `mappingConfidence` hat SQL-Zieltyp `varchar(16)`. `matchedStepOrdinal` hat SQL-Zieltyp `int`. `matchesRangeHighKey` hat SQL-Zieltyp `bit`. `isBelowHistogram` hat SQL-Zieltyp `bit`. `isAboveHistogram` hat SQL-Zieltyp `bit`. `sensitiveValueStatus` hat SQL-Zieltyp `varchar(40)`.

## Aufrufbeispiele

```sql
EXEC [monitor].[USP_ExecutionPlanAnalysis] @Hilfe=1;
```

```sql
DECLARE @SyntheticPlan xml = N'<ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.2" Build="16.0.1000.6"><BatchSequence><Batch><Statements><StmtSimple StatementId="1" StatementType="SELECT" StatementText="SELECT 1"><QueryPlan><RelOp NodeId="0" PhysicalOp="Constant Scan" LogicalOp="Constant Scan" EstimateRows="1" /></QueryPlan></StmtSimple></Statements></Batch></BatchSequence></ShowPlanXML>';
EXEC [monitor].[USP_ExecutionPlanAnalysis] @PlanXml=@SyntheticPlan, @ResultSetArt='RAW';
```

```sql
DECLARE @SyntheticPlan xml = N'<ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.2" Build="16.0.1000.6"><BatchSequence><Batch><Statements><StmtSimple StatementId="1" StatementType="SELECT" StatementText="SELECT 1"><QueryPlan><RelOp NodeId="0" PhysicalOp="Constant Scan" LogicalOp="Constant Scan" EstimateRows="1" /></QueryPlan></StmtSimple></Statements></Batch></BatchSequence></ShowPlanXML>';
DECLARE @JsonOutput nvarchar(max);
EXEC [monitor].[USP_ExecutionPlanAnalysis] @PlanXml=@SyntheticPlan, @JsonErzeugen=1, @Json=@JsonOutput OUTPUT, @ResultSetArt='NONE';
SELECT @JsonOutput AS [SyntheticAnalysisJson];
```

```sql
CREATE TABLE #ExecutionPlanAnalysis_HelpExample ([Seed] int NULL);
DECLARE @SyntheticPlan xml = N'<ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.2" Build="16.0.1000.6"><BatchSequence><Batch><Statements><StmtSimple StatementId="1" StatementType="SELECT" StatementText="SELECT 1"><QueryPlan><RelOp NodeId="0" PhysicalOp="Constant Scan" LogicalOp="Constant Scan" EstimateRows="1" /></QueryPlan></StmtSimple></Statements></Batch></BatchSequence></ShowPlanXML>';
EXEC [monitor].[USP_ExecutionPlanAnalysis] @PlanXml=@SyntheticPlan, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#ExecutionPlanAnalysis_HelpExample"}';
DROP TABLE #ExecutionPlanAnalysis_HelpExample;
```

Bei `@MitSqlText=NULL` greifen weder die Bestätigungsprüfung für 1 noch die Unterdrückung für 0. Dadurch kann Statementtext ohne ausdrückliche Bestätigung ausgegeben werden. Verwenden Sie deshalb ausdrücklich 0 oder 1; diese Dokumentationsänderung behebt die bestehende Prüflücke nicht.

## Resultsets und Leserichtung

CONSOLE zeigt priorisierte `findings`. RAW liefert 22 getrennte Resultsets einschließlich `moduleStatus`; TABLE exportiert die explizit benannten Ziele. Das JSON besitzt `meta` und 21 fachliche Arrays, aber kein eigenes `moduleStatus`-Array. Die Parameterreferenz nennt alle Ausgabenamen und die getrennten Eingabeformen für Execution-Evidence-JSON.

## Beispiele und Gegenbeispiele

Ein geeigneter Example-Fall übergibt genau ein vollständiges synthetisches Showplan-XML und beginnt mit `STANDARD`, begrenzten Operatoren sowie `DERIVED_ONLY`. Ein zweiter kontrollierter Fall kann einen gezielten Planhandle oder eine Query-Store-Identität verwenden und muss die abweichende Planquelle beibehalten. Ein Gegenbeispiel ist die Behandlung eines Estimated Plans als aktuelle Ausführung oder die direkte Umsetzung eines Missing-Index-Fragments als DDL. Ebenso dürfen Operatoren verschiedener Statements nicht allein über `NodeId` zusammengeführt werden.

## Leere oder partielle Ausgabe

Ein syntaktisch gültiger Plan kann keine Findings oder keine Runtime-Counter enthalten. Das ist kein Parsererfolg mit gemessener Laufzeit, sondern ein planquellenabhängiger Leer- beziehungsweise Nicht-verfügbar-Zustand. Erreicht die Analyse ein Operator-, Finding- oder Zeitlimit, bleiben `moduleStatus`, Collection-Status und bereits materialisierte Resultsets konsistent partiell. Eine nicht angeforderte Query-Store-Vertiefung erscheint als `NOT_APPLICABLE`, nicht als leeres Gesundheitsurteil.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `MEDIUM` bis `HIGH_OPT_IN` |
| Standardpfad | Genau ein Plan mit begrenzter Statement- und Operatoranalyse |
| Teuerster Pfad | Explizit gewählte aktuelle Statistik- und Histogrammvertiefung; `FULL` allein wählt keinen anderen Enginepfad |
| Haupttreiber | XML-Größe, Operatorzahl, Statementzahl und aktivierte Quellen |
| Skalierung | Grenzen wirken je Plan; breite Plansuche gehört nicht in diese Procedure |
| Ressourcen | XML-CPU und Speicher; optional Katalog- und Query-Store-I/O |
| Begrenzungswirkung | Statementfilter und Kappen nach der Analyse; abschließende kooperative Zeitprüfung ohne Abbruchgarantie |
| Locking und Nebenwirkungen | Keine Planausführung, kein Forcing und keine fachliche DDL; nur eigene lokale Temp-Tabellen |
| Schutzmechanismus | Eindeutige Planquelle, High-Impact-Gate und Datenschutzmodi |
| Sicherer Einsatz | Direkter Plan, `STANDARD`, kleine Grenzen und `DERIVED_ONLY` |
| Aussagegrenze | Plan- und Runtimeevidenz ersetzt keine Workload- und Wirkungsprüfung |

Die Anlage der eigenen Temp-Tabellen erhält je Statement bis zu 100 ms
Sperrwartezeit. Anschließend und im Fehlerpfad gilt wieder `LOCK_TIMEOUT 0`;
ein Fehler wird unverändert weitergegeben. Dieses Fenster umfasst keine
fachlichen Zugriffe und ist keine allgemeine Laufzeitgarantie.

## Eine Zeile bedeutet

Je nach Resultset beschreibt eine Zeile einen Plan, ein Statement, einen Operator innerhalb eines Statements, einen Threadcounter, einen Access Path, eine Statistik, einen Parameter, eine dokumentierte Parameterevidenzgrenze oder ein Finding. `NodeId` ist nur zusammen mit `StatementOrdinal` eindeutig. In `parameters` trennt `EvidenceKind = 'PARAMETER'` fachliche Parameterzeilen von `SOURCE_BOUNDARY` und `SOURCE_STATUS`.

## So lesen

Berücksichtigen Sie zuerst die Planquelle und `RuntimeCounterScope`, danach die
Statements und den Operatorbaum. In `parameters` prüfen Sie anschließend
`ValueSource`, die Presence-/SQL-NULL-Flags, `ValueStatus`,
`SourceObservedAtUtc`, Aktualitätskennzeichen und `IsComplete`.
`NOT_COLLECTED` ist kein SQL-`NULL`; `LAST_ACTUAL_PLAN` ist nicht der
aktuelle Aufruf. Prüfen Sie absolute Zeilen- und Readmengen vor Ratios.
Bewerten Sie Findings erst mit Severity, Confidence, Workloadprofil und
Evidenzgrenze.

Lesen Sie `planWarnings` zusammen mit `FalsePositiveGuard`,
`optimizerContext` zusammen mit Planquelle und Cachezeit sowie
`runtimeFeedback` zusammen mit `RuntimeCounterScope`. `queryStoreContext` ist
bei nicht angeforderter Query-Store-Quelle ausdrücklich `NOT_APPLICABLE`.
`feedbackAndVariants` belegt nur sichtbare Planmerkmale beziehungsweise
persistierte Beziehungen; es bewertet weder Featurewirksamkeit noch
Tuningnutzen.

## Warum kann das problematisch sein?

Statementvermischung, unvollständige Runtime-Counter oder pauschale Schwellen erzeugen falsche Diagnosen. Große Estimate-Abweichungen können Joinwahl und Grants beeinflussen; hohe Rows-Read-Discard-Mengen, Spills oder Millionen Lookups können erhebliche CPU-, IO- oder TempDB-Last verursachen.

## Wann ist es kein Problem?

Ein Scan, Lookup, Sort oder paralleler Plan ist nicht grundsätzlich fehlerhaft. Kleine absolute Mengen, Maintenance-Workloads oder bewusst durchsatzorientierte Verarbeitung können dieselbe Planform legitimieren.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche objektiven Plan- und Runtimewerte liegen je Statement und Operator vor, und welche Auffälligkeiten sind unter dem gewählten Workloadprofil relevant?

### Technischer Hintergrund

Die Ausführung ist pull-basiert; ein Plan ist keine lineare zeitliche Schrittfolge. Die Analyse hält StatementOrdinal und NodeId gemeinsam, paart ActualRows und ActualRowsRead je Runtime-Counter-Zeile und berechnet erst danach aggregierte Kennzahlen.

### Datenkette

Die Procedure verwendet direktes Showplan XML oder die gezielten Quellen `sys.dm_exec_query_plan`, `sys.dm_exec_query_plan_stats`, `sys.dm_exec_query_statistics_xml` beziehungsweise `sys.query_store_plan`; Evidence JSON ist optional. Bei einem Query-Store-Plan werden Runtimeaggregate und auf SQL Server 2022 oder neuer Feedback-, Hint- und Variantenkataloge gezielt ergänzt, ohne Querytext zu lesen. Importierte Histogramm- und Predicate-Mappings passieren vor jeder Ausgabe erneut die öffentliche Privacy-Grenze.

Query-Store-Hint- und Feedbackpayloads sind in `DERIVED_ONLY` und
`STRUCTURE_ONLY` ausgelassen. `TOKENIZED` liefert nur Hash und Länge; RAW
benötigt `@SensitiveDataConfirmed=1`.

### Source Select

Bei einem gezielten Plan-Handle wird genau dieses Cacheobjekt aufgelöst; der direkte `@PlanXml`-Pfad überspringt die Cachequelle vollständig:

```sql
SELECT
      [qp].[query_plan]
FROM [sys].[dm_exec_query_plan](@PlanHandle) AS [qp]
WHERE @PlanHandle IS NOT NULL;
```

Für einen aktuellen tatsächlichen Plan verwendet der alternative Pfad eine exakt bestimmte Session beziehungsweise ein exakt bestimmtes Handle und `sys.dm_exec_query_statistics_xml` oder `sys.dm_exec_query_plan_stats`.

**Wichtig für die Eigenlast:** Genau eine Planquelle bestimmen, bevor XML analysiert wird. Statementfilter sowie Operator- und Findingskappen wirken nach der Engineanalyse. Das Zeitbudget wird einmal abschließend geprüft und kann partielle Ausgabe markieren; es unterbricht weder eine laufende XML-Analyse noch eine Quellabfrage. Die Größe des übergebenen Plans bleibt daher ein eigenständiger Lasttreiber.

### Zeit- und Scope-Modell

Compile-, Last-Actual-, Current-Actual-, Query-Store- und importierte Evidenz
bleiben getrennt. `SourceObservedAtUtc` bezeichnet den Zeitpunkt, zu dem die
Quelle im Frameworkaufruf gelesen wurde. `ValueCapturedAtUtc` wird nur
gesetzt, wenn der Zeitpunkt für den Live-Plan tatsächlich aus dem aktuellen
Abruf ableitbar ist. Ein Last-Actual-Plan ist der letzte bekannte Aufruf, nicht
zwingend der aktuelle.

### Bewertung und Gegenprobe

Berücksichtigen Sie die relative Abweichung, die absolute Arbeit je Ausführung, die Wiederholung und die kumulative Wirkung gemeinsam. Statistiken, Query Store, IO/TIME und Indexkataloge dienen als unabhängige Gegenprobe.

### Typische Fehlinterpretation

Ein 100-facher Estimatefehler bei wenigen Zeilen ist nicht automatisch kritischer als ein zehnfacher Fehler bei Millionen Zeilen. Missing-Index-XML ist keine fertige DDL.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_CreateExecutionEvidenceJson`, `USP_ShowplanAnalysis`, Query Store Regressionen, Index Usage und Statistics Distribution.

## Primärquellen

- [Showplan logical and physical operators](https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference?view=sql-server-ver17)
- [sys.dm_exec_query_plan](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-query-plan-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../04_Plan_Cache.md#standalone-execution-plan-analysis)

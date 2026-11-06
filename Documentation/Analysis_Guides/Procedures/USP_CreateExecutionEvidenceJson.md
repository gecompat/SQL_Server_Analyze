# [monitor].[USP_CreateExecutionEvidenceJson]

**Bereich:** Plan Cache und Showplan<br>
**Zweck:** Normalisiert bereits erfasste Plan-, STATISTICS-IO-, STATISTICS-TIME- und Statistik-/Histogrammevidenz in ein versioniertes JSON.<br>
**Beobachtungsart:** importierte oder gezielt ergänzte Ausführungsevidenz<br>
**Kostenklasse:** LOW bis HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure ist passend, wenn vorhandene Laufzeitinformationen derselben oder einer nachvollziehbar zugeordneten Ausführung in ein gemeinsames Format überführt werden sollen. Sie führt die analysierte Query niemals aus. Der Standardmodus `DERIVED_ONLY` entfernt konkrete Parameter-, Predicate- und Histogrammgrenzwerte aus dem exportierbaren Ergebnis, nachdem eine mögliche lokale Zuordnung zu Histogrammschritten erfolgt ist.

## Nicht beantwortete Fragen

Das JSON beweist nicht automatisch, dass Plan, IO- und TIME-Meldungen aus derselben Ausführung stammen. Diese Beziehung wird über `SameExecutionConfidence` ausgewiesen. Ein aktueller Statistikzustand beweist zudem nicht, dass derselbe Zustand bei der Plankompilierung vorlag.

## Sicherer Einstieg

```sql
DECLARE @EvidenceJson nvarchar(max);
EXEC [monitor].[USP_CreateExecutionEvidenceJson]
      @StatisticsIoText = N'Table ''ExampleObject''. Scan count 1, logical reads 8, physical reads 0, read-ahead reads 0, lob logical reads 0.'
    , @StatisticsTimeText = N'SQL Server Execution Times: CPU time = 1 ms, elapsed time = 2 ms.'
    , @EvidenzDatenschutzModus = 'DERIVED_ONLY'
    , @ResultSetArt = 'NONE'
    , @Json = @EvidenceJson OUTPUT;
```

`@RawTextHandling = 'INCLUDE'` ist nur zusammen mit `@SensitiveDataConfirmed = 1` und `@IdentifierDatenschutzModus = 'RAW'` zulässig, weil Meldungsrohtext vertrauliche Werte und nicht zuverlässig einzeln anonymisierbare Identifikatoren enthalten kann. Die Wert- und Identifikatormodi sind getrennt: `DERIVED_ONLY` entfernt konkrete Werte, behält mit dem Identifier-Default `RAW` aber Namen bei. Der Identifikatormodus `TOKENIZED` erzeugt capture-lokale Tokens; `OMIT` lässt Namen aus.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@PlanXml` | `xml` | `NULL` | Optionales bereits vorhandenes Plan-XML als SQL-Typ xml; Text kann durch SQL in diesen Typ konvertiert werden. NULL lässt die planbezogene Extraktion aus. Leeres XML oder XML ohne passende Showplan-Knoten kann keine passenden Bezüge liefern; die XML-Typprüfung ersetzt keine vollständige Showplan-Schemaprüfung. @StatementId begrenzt passende Extraktoren; die beschriebene Query wird niemals ausgeführt. |
| `@StatisticsIoText` | `nvarchar(max)` | `NULL` | optionaler, bereits erfasster STATISTICS-IO-Meldungstext. NULL oder Auslassen erzeugt keine aus diesem Argument geparsten Zeilen. Nicht erkannte oder teilweise lesbare Zeilen bleiben mit ParseStatus sichtbar; der Text wird mit @StatisticsLanguage geparst und StatementOrdinal kann fehlende Zuordnungen ergänzen. Rohtext wird abhängig von @RawTextHandling behandelt. Leerer oder nur aus Leerzeichen bestehender Text liefert keine Parserzeilen. |
| `@StatisticsTimeText` | `nvarchar(max)` | `NULL` | optionaler, bereits erfasster STATISTICS-TIME-Meldungstext. NULL oder Auslassen erzeugt keine daraus geparsten Zeilen. Der Parser kennzeichnet teilweise oder unbekannte Formate, statt fehlende Messwerte als Null zu erfinden; die Sprache richtet sich nach @StatisticsLanguage und @StatementOrdinal kann fehlende Zuordnung ergänzen. Rohtextbehandlung folgt @RawTextHandling. Leerer oder nur aus Leerzeichen bestehender Text liefert keine Parserzeilen. |
| `@StatisticsLanguage` | `varchar(16)` | `'AUTO'` | AUTO erkennt unterstützte Meldungsteile automatisch; EN bezeichnet Englisch und DE Deutsch. Der IO-Parser normalisiert Groß-/Kleinschreibung und fällt bei NULL, leerem oder unbekanntem Code auf AUTO zurück. Der TIME-Parser verwendet die Kennung nicht und erkennt seine englischen/deutschen Textteile selbst. Es entsteht kein INVALID_PARAMETER für einen unbekannten Sprachcode. |
| `@StatisticsEvidenceJson` | `nvarchar(max)` | `NULL` | Optionaler Statistikabschnitt als JSON-Objekt mit statistics oder unmittelbar als Statistikobjekt. Unter statistics werden planUsage nur ohne @PlanXml und currentSnapshot, histogramSummaries sowie histogramSteps nur außerhalb CURRENT_SERVER als Arrays von Objekten projiziert; deren Feldnamen und SQL-Zieltypen stehen in den nachfolgenden JSON-Eingabeformen. Ein expliziter statistics-Abschnitt ersetzt den gleichnamigen Abschnitt aus @ExistingEvidenceJson. NULL importiert nichts; leerer Text ist ungültiges JSON. JSON_QUERY akzeptiert hier Objekt oder Array, eine strikte Objekt-/Feldprüfung findet nicht statt. Unbekannte Eigenschaften werden nicht übernommen. Bei ungültigem JSON oder fehlendem extrahierbarem Abschnitt führt @StrictValidation=1 intern zu 51021 und dem abgefangenen Status INVALID_EVIDENCE_JSON; andernfalls folgen Warnung und partielle Ausgabe. statisticsIo und statisticsTime an dieser Eingabewurzel werden nicht importiert. |
| `@ObjectMetadataJson` | `nvarchar(max)` | `NULL` | Optionales JSON-Array von Objektbezügen oder Objekt mit objectReferences. Die 21 erkannten Eintragsfelder und SQL-Zieltypen stehen in den nachfolgenden JSON-Eingabeformen. Der Abschnitt ersetzt objectReferences aus @ExistingEvidenceJson und wird nur ohne @PlanXml importiert. NULL importiert nichts; leerer Text ist ungültig. JSON_QUERY akzeptiert Objekt oder Array unter objectReferences; die Implementierung erzwingt keine strikte Array-/Feldstruktur und ignoriert unbekannte Eigenschaften. Ungültiges JSON oder eine nicht extrahierbare Form führt bei @StrictValidation=1 intern zu 51022 und zum abgefangenen Status INVALID_EVIDENCE_JSON; andernfalls folgen Warnung und partielle Ausgabe. |
| `@StatistikEvidenzModus` | `varchar(16)` | `'PLAN_ONLY'` | Zulässig sind NONE, PLAN_ONLY, USED, RELEVANT und OBJECT_ALL. NONE überspringt die Extraktion von Statistiknutzung aus dem übergebenen Plan. PLAN_ONLY extrahiert diese Compile-Evidenz ohne aktuelle Katalogabfrage. USED ergänzt aktuelle Metadaten der im Plan verwendeten Statistiken. RELEVANT ergänzt diese um Statistiken, deren führende Spalte einer im Plan referenzierten Predicate-Spalte entspricht. OBJECT_ALL ergänzt alle Statistiken der referenzierten Planobjekte. Aktuelle Ergänzungen benötigen @PlanXml und CURRENT_SERVER; die beiden breiten Modi benötigen High-Impact-Bestätigung. Importierte Statistikarrays werden durch NONE nicht pauschal entfernt. NULL fällt auf PLAN_ONLY zurück; äußere Leerzeichen und Groß-/Kleinschreibung werden normalisiert. Leerer oder unbekannter Code ist INVALID_PARAMETER. |
| `@HistogrammModus` | `varchar(16)` | `'NONE'` | geschlossene Auswahl NONE, SUMMARY, STEPS. NULL wird wie NONE behandelt; Trim und Großschreibung normalisieren Werte, unbekannte Werte sind INVALID_PARAMETER. NONE erhebt keine Histogramme; SUMMARY liefert Zusammenfassungen; STEPS liefert Histogrammschritte. SUMMARY und STEPS benötigen @MetadatenQuellenmodus=CURRENT_SERVER sowie @StatistikEvidenzModus USED, RELEVANT oder OBJECT_ALL; sonst INVALID_PARAMETER. |
| `@MetadatenQuellenmodus` | `varchar(16)` | `'EVIDENCE_ONLY'` | Zulässig sind EVIDENCE_ONLY und CURRENT_SERVER. EVIDENCE_ONLY verarbeitet übergebene Plan-/JSON-/Meldungsevidenz ohne aktuelle Statistikabfragen. CURRENT_SERVER ruft die aktuelle Erhebung nur mit @PlanXml und Statistikmodus USED, RELEVANT oder OBJECT_ALL auf; importierte currentSnapshot-, Histogramm- und Predicate-Mapping-Arrays werden dann nicht geladen, auch wenn keine Erhebung stattfindet. 0 bei @QuellumgebungBestaetigt führt zu SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED; NULL kann die äußere Prüfung umgehen; eine tatsächlich angeforderte aktuelle Erhebung wird jedoch vom internen Collector als INVALID_PARAMETER abgewiesen und als CURRENT_METADATA_COLLECTION_LIMITED mit Partialität gemeldet. NULL als Quellenmodus bedeutet EVIDENCE_ONLY; Trim und Großschreibung werden normalisiert. Leerer oder unbekannter Code ist INVALID_PARAMETER. |
| `@QuellumgebungBestaetigt` | `bit` | `0` | 0 bestätigt die Quellumgebung nicht; 1 bestätigt, dass CURRENT_SERVER der tatsächlichen Quelle entspricht. CURRENT_SERVER wird bei 0 mit SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED abgewiesen. NULL kann die äußere Vorprüfung passieren. Bei tatsächlich angeforderter aktueller Erhebung weist der Collector NULL als INVALID_PARAMETER zurück; der Capture wird mit CURRENT_METADATA_COLLECTION_LIMITED partiell und liest dabei keine aktuellen Metadaten. NULL ist keine Bestätigung. Ohne CURRENT_SERVER ist der Schalter ohne Erhebungswirkung. Die Bestätigung ersetzt weder Berechtigungen noch einen Herkunftsnachweis. |
| `@EvidenzDatenschutzModus` | `varchar(24)` | `'DERIVED_ONLY'` | geschlossene Auswahl DERIVED_ONLY, TOKENIZED, STRUCTURE_ONLY, RAW. NULL wird wie DERIVED_ONLY behandelt; Trim und Großschreibung normalisieren Werte, sonst INVALID_PARAMETER. DERIVED_ONLY entfernt konkrete Parameter-, Predicate- und Histogrammgrenzwerte aus dem exportierbaren Ergebnis; TOKENIZED ersetzt solche Werte durch capture-lokale Tokens; STRUCTURE_ONLY beschränkt die Ausgabe auf Struktur; RAW lässt Werte zu und erfordert @SensitiveDataConfirmed=1, bei 0 folgt SENSITIVE_DATA_CONFIRMATION_REQUIRED; NULL kann die <>1-Prüfung umgehen. Bei NULL als Bestätigung kann RAW trotz fehlender ausdrücklicher Zustimmung konkrete Werte ausgeben; verwenden Sie für die Bestätigung ausdrücklich 0 oder 1. |
| `@IdentifierDatenschutzModus` | `varchar(16)` | `'RAW'` | geschlossene Auswahl RAW, TOKENIZED, OMIT. NULL wird wie RAW behandelt; Trim und Großschreibung normalisieren, unbekannte Werte führen zu INVALID_PARAMETER. RAW erhält Identifikatoren, TOKENIZED ersetzt sie durch capture-lokale Tokens und OMIT lässt sie aus. Für @RawTextHandling=INCLUDE ist ausschließlich RAW zusammen mit @SensitiveDataConfirmed=1 zulässig. |
| `@SensitiveDataConfirmed` | `bit` | `0` | 0 bestätigt sensible Ausgabe nicht; 1 bestätigt die Ausgabe konkreter Werte bei RAW-Evidenz beziehungsweise Meldungsrohtext bei INCLUDE. Bei 0 folgen SENSITIVE_DATA_CONFIRMATION_REQUIRED für diese Pfade; INCLUDE benötigt zusätzlich IdentifierDatenschutzModus=RAW. NULL kann die Vergleiche <>1 wegen SQL-UNKNOWN umgehen und löst diesen Status deshalb nicht zuverlässig aus; NULL ist keine ausdrückliche Bestätigung. additionalEvidence wird ausschließlich bei RAW und exakt 1 eingebettet. Bei NULL kann die Verarbeitung im Status AVAILABLE fortgesetzt werden und angeforderte Rohwerte oder Rohzeilen ausgeben; diese Validierungslücke wird durch die Hilfeänderung nicht behoben. |
| `@MitPredicateHistogramMap` | `bit` | `1` | 0 überspringt den Collector-Pfad für Predicate-/Histogrammzuordnung; 1 aktiviert ihn bei tatsächlich aufgerufener aktueller Erhebung. NULL kann die öffentliche NOT-IN-Prüfung passieren. Bei tatsächlich angeforderter aktueller Erhebung weist der interne Collector NULL als INVALID_PARAMETER zurück; der Capture meldet CURRENT_METADATA_COLLECTION_LIMITED und wird partiell. Der Schalter unterdrückt keine bereits importierten Mappingzeilen. |
| `@StatementId` | `int` | `NULL` | optionale Statement-ID zum Begrenzen der Planextraktion und Statistikverwendung. NULL/Auslassen verarbeitet den Plan ohne diese Eingrenzung. Der Wert wird an die Plan-Extraktoren übergeben; ein nicht vorhandenes oder nicht zuordenbares Statement liefert entsprechend keine passenden Planbezüge. Für diese Eingabe besteht keine zusätzliche Bereichsvalidierung. |
| `@StatementOrdinal` | `int` | `NULL` | Optionale ganze Ordnungsnummer ohne zusätzliche Bereichsprüfung. Nur mit @PlanXml füllt ein gesetzter Wert fehlende StatementOrdinal in geparsten IO-/TIME-Zeilen. Ohne Wert setzt ein Einzelstatementplan diese Zeilen auf 1; ein Mehrstatementplan lässt die Zuordnung offen und warnt bei vorhandenen Meldungszeilen mit partieller Ausgabe. Ohne @PlanXml hat der Parameter keine Zuordnungswirkung. NULL bedeutet keine explizite Zuordnung. |
| `@SameExecutionAsPlanConfirmed` | `bit` | `NULL` | optionale Bestätigung, dass Meldungsevidenz derselben Ausführung wie der Plan entstammt. NULL/Auslassen bedeutet unbestätigt; 0 bedeutet ausdrücklich UNCONFIRMED; 1 bedeutet CONFIRMED. Andere Bitwerte sind nicht als eigene Validierungsbedingung implementiert. Diese Angabe beweist die Ausführungsbeziehung nicht selbst. |
| `@CapturedAtUtc` | `datetime2(3)` | `NULL` | optionaler UTC-Zeitpunkt der Erfassung. NULL/Auslassen setzt capturedAtUtc auf die aktuelle UTC-Systemzeit; ein gesetzter Wert wird als Erfassungszeit übernommen. SQL konvertiert die Eingabe auf Millisekundenpräzision gemäß datetime2(3). |
| `@SourceProductVersion` | `nvarchar(128)` | `NULL` | optionale Produktversionsangabe der Quellumgebung für sourceEnvironment.productVersion. NULL/Auslassen bleibt im JSON null; keine Formatprüfung ist implementiert. Leerer Text wird unverändert als Text übergeben und nicht als NULL normalisiert. |
| `@SourceCompatibilityLevel` | `smallint` | `NULL` | optionales Quell-Compatibility-Level. NULL/Auslassen bleibt null; erlaubter Zahlenbereich ist 80 bis 200 einschließlich. Werte außerhalb des Bereichs ergeben INVALID_PARAMETER. Der Wert wird als sourceEnvironment.compatibilityLevel ausgegeben. |
| `@SourceEngineEdition` | `int` | `NULL` | optionale Engine-Edition-Kennung der Quelle für sourceEnvironment.engineEdition. NULL/Auslassen bleibt null; es ist keine abgeschlossene Wertemenge oder separate Wertebereichsprüfung implementiert. |
| `@MaxStatistiken` | `int` | `100` | Begrenzung der Zahl aktueller Statistiken. NULL ist unzulässig; gültiger Bereich 1 bis 1000 einschließlich, andernfalls INVALID_PARAMETER. Der Grenzwert wirkt auf die zielgerichtete aktuelle Statistikerhebung. |
| `@MaxHistogrammSchritte` | `int` | `20000` | Begrenzung der erhobenen Histogrammschritte. NULL ist unzulässig; gültiger Bereich 0 bis 200000 einschließlich, andernfalls INVALID_PARAMETER. Der Grenzwert beschränkt Histogrammvertiefung; 0 erlaubt keine Histogrammschritte. |
| `@LockTimeoutMs` | `int` | `0` | Wartezeitgrenze in Millisekunden für die optionale Metadatenerhebung. NULL ist unzulässig; gültiger Bereich 0 bis 60000 einschließlich, sonst INVALID_PARAMETER. 0 bedeutet keine Wartezeit auf gesperrte Ressourcen; ein positiver Wert begrenzt das Warten auf die angegebene Zahl Millisekunden. |
| `@HighImpactConfirmed` | `bit` | `0` | 0 bestätigt keinen High-Impact-Pfad; 1 bestätigt die tatsächlich angeforderte breite Statistik- oder Histogrammerhebung. Der Collector verlangt diese Bestätigung für RELEVANT, OBJECT_ALL oder STEPS nur, wenn er mit @PlanXml, CURRENT_SERVER und einem aktuellen Statistikmodus aufgerufen wird; Berechtigungen werden dadurch nicht erteilt. NULL passiert die äußere NOT-IN-Prüfung, wird bei jeder tatsächlich angeforderten aktuellen Erhebung jedoch vom internen Collector als INVALID_PARAMETER zurückgewiesen; der Capture meldet dann CURRENT_METADATA_COLLECTION_LIMITED und Partialität. Ohne Collector-Aufruf ist daraus keine zusätzliche Gate-Prüfung abzuleiten. NULL ist keine ausdrückliche Bestätigung. |
| `@AdditionalEvidenceJson` | `nvarchar(max)` | `NULL` | optionales zusätzliches JSON, das unverändert als importierter Abschnitt nur bei @EvidenzDatenschutzModus=RAW und @SensitiveDataConfirmed=1 in additionalEvidence eingebettet wird; andernfalls ist dieser JSON-Schlüssel null. NULL/Auslassen markiert keine zusätzliche Evidenz. Ungültiges JSON führt bei @StrictValidation=1 zu Fehler 51023; sonst wird es verworfen, gewarnt und IsPartial gesetzt. Ein spezifisches geschlossenes Schlüsselschema wird hier nicht validiert; der Wert muss syntaktisch gültiges JSON sein. Ohne hinreichend strikte Datenschutzfreigabe werden zusätzliche Inhalte nicht in den Ausgabeabschnitt übernommen. |
| `@ExistingEvidenceJson` | `nvarchar(max)` | `NULL` | Optionale Ausgangshülle als Execution-Evidence-JSON. Die ausgewerteten Wurzelabschnitte sind statisticsIo, statisticsTime, statistics, objectReferences und predicateHistogramMappings; statistics besitzt planUsage, currentSnapshot, histogramSummaries und histogramSteps. Die erkannten Objektfelder und SQL-Zieltypen stehen nachfolgend. Unbekannte Eigenschaften und bisherige meta-/capture-/Warnungsabschnitte werden nicht unverändert exportiert. Eigene Statistik-/Objektparameter ersetzen gleichnamige Abschnitte. Mit @PlanXml stammen planUsage und objectReferences aus dem Plan; ohne CURRENT_SERVER werden aktuelle Statistik-, Histogramm- und Mappingarrays importiert. Importierte IO-/TIME-Zeilen werden zusätzlich zu geparsten Textzeilen eingefügt, mit RawLine=NULL; Dubletten werden nicht automatisch entfernt. NULL startet eine leere Hülle; leerer Text ist ungültiges JSON. Ungültiges JSON führt bei StrictValidation=1 intern zu 51024 und dem abgefangenen Status INVALID_EVIDENCE_JSON, sonst zu Warnung und partieller Ausgabe. |
| `@RawTextHandling` | `varchar(16)` | `'HASH_ONLY'` | geschlossene Auswahl NONE, HASH_ONLY, INCLUDE. NULL wird wie HASH_ONLY behandelt; Trim und Großschreibung normalisieren Werte, andere Werte ergeben INVALID_PARAMETER. NONE entfernt Rohzeilen und gibt keine Eingabehashes aus; HASH_ONLY entfernt Rohzeilen und gibt Eingabelängen sowie SHA-256-Hashes der IO-/TIME-Texte aus; INCLUDE erhält geparste Rohzeilen im Ergebnis und gibt Eingabehashes aus. INCLUDE erfordert @SensitiveDataConfirmed=1 und @IdentifierDatenschutzModus=RAW, andernfalls SENSITIVE_DATA_CONFIRMATION_REQUIRED. |
| `@StrictValidation` | `bit` | `1` | 1 behandelt ungültiges importiertes JSON oder nicht extrahierbare Teilpayloads als interne Fehler 51021 bis 51024; der CATCH liefert INVALID_EVIDENCE_JSON, Partialität und die Fehler-OUTPUTs. 0 verwirft diese Payloads mit Warnung und partieller Ausgabe. NULL passiert NOT IN (0,1) und folgt bei IF=1 dem nicht strikten Zweig. Typkonvertierungs- und Zieltabellenfehler können auch mit 0 in ERROR_HANDLED enden; TABLE-Vorbereitungsfehler liegen außerhalb dieses CATCH. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | geschlossene Auswahl CONSOLE, RAW, TABLE, NONE. NULL und Leertext normalisieren zu leer und führen INVALID_PARAMETER. Werte werden getrimmt und großgeschrieben. CONSOLE ruft InternalEmitConsoleResult mit captureStatus als Quelle auf; RAW gibt die elf benannten Tabellen als elf Resultsets aus; TABLE schreibt angeforderte Resultate in ausdrücklich zugeordnete Ziele; NONE emittiert keine Resultsets. Unbekannte Werte sind INVALID_PARAMETER. CONSOLE ist die getrennte Konsolenausgabe, nicht ein JSON-Resultset. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | optionales JSON-Objekt, dessen Schlüssel die Resultatnamen und dessen Zeichenkettenwerte vorhandene lokale Zieltabellen bezeichnen, zum Beispiel {"captureStatus":"#Capture"}. Es darf mindestens eine Zuordnung enthalten; alle Namen müssen aus der geschlossenen Liste captureStatus, statisticsIo, statisticsTime, planStatisticsUsage, objectReferences, currentStatistics, histogramSummaries, histogramSteps, predicateHistogramMappings, collectionStatus und warnings stammen. Jede Zieltabelle muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale Temp-Tabellen, Namen über 116 Zeichen, Ziele mit Präfix #Monitor, doppelte Namen oder Ziele und andere JSON-Werttypen werden abgelehnt. NULL/Auslassen wird im TABLE-Modus als ungültige Zuordnung abgelehnt; außerhalb TABLE führt ein gesetzter Wert zu INVALID_PARAMETER. Helper-Fehler werden als Fehler 51011 ausgelöst. |
| `@JsonErzeugen` | `bit` | `1` | Schalter zur Erzeugung des kanonischen JSON in @Json. 1 erzeugt das JSON, 0 lässt @Json auf NULL. 0 und 1 steuern die Ausgabe; NULL passiert NOT IN (0,1), erzeugt bei IF=1 aber kein JSON. Das JSON ist ein eigener OUTPUT-Parameter und wird bei @ResultSetArt=CONSOLE nicht als Resultset ausgegeben. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang als nvarchar(max)-Variable mit OUTPUT; ein übergebener Anfangswert wird auf NULL zurückgesetzt. JsonErzeugen=1 erzeugt das versionierte Execution-Evidence-Objekt, 0 oder NULL lässt den Ausgang NULL. Wurzelkeys sind meta, capture, sourceEnvironment, planIdentity, statisticsIo, statisticsTime, statistics, objectReferences, predicateHistogramMappings, collectionStatus, warnings, rawInput, importedEvidence und additionalEvidence. statistics enthält planUsage, currentSnapshot, histogramSummaries und histogramSteps als Arrays. IO, TIME, Objektbezüge, Mappings, Collection-Status und Warnings sind Arrays; fehlende optionale Skalare bleiben JSON-null. ResultSetArt ist davon unabhängig. Ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen. |
| `@PrintMeldungen` | `bit` | `1` | 1 gibt bei Status außerhalb AVAILABLE eine Severity-10-Meldung über RAISERROR WITH NOWAIT aus. 0 oder NULL unterdrückt diese Meldung. Die Hilfsausgabe wird dadurch nicht deaktiviert. |
| `@Hilfe` | `bit` | `0` | 1 druckt die Parameterhilfe und kehrt vor Parameterprüfung, TABLE-Vorbereitung und Erhebung zurück. 0 oder NULL folgt dem normalen Pfad. Zuvor werden @Json auf NULL und die vier Status-OUTPUTs auf AVAILABLE, 0, NULL und NULL gesetzt; auch SET LOCK_TIMEOUT 0 liegt vor dem Hilfe-RETURN. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | als varchar(40)-Variable mit OUTPUT zu binden. Erhält den StatusCode der Ausführung, anfänglich AVAILABLE und bei Validierungs-, Datenschutz-, Quellumgebungs- oder Verarbeitungsfällen entsprechend ersetzt. Der Status ist maschinenlesbar und Teil von captureStatus; der Aufrufende soll den gelieferten Wert auswerten. Der Anfangswert wird beim Einstieg auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | als bit-Variable mit OUTPUT zu binden. 0 bedeutet zunächst nicht partiell; ungültige/verworfene optionale Evidenz oder andere begrenzte Verarbeitung kann auf 1 setzen. Der Wert beschreibt die Vollständigkeit der erzeugten Evidenz, nicht den Erfolg eines ausgeführten Workloads. Der Anfangswert wird beim Einstieg auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | als int-Variable mit OUTPUT zu binden. Zu Beginn NULL; bei abgefangenen Fehlern wird die SQL-Fehlernummer ausgegeben. Ohne solchen Fehler bleibt der Wert NULL. Der Anfangswert wird beim Einstieg auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | als nvarchar(2048)-Variable mit OUTPUT zu binden. Zu Beginn NULL; bei Status- oder Verarbeitungsfehlern wird eine begrenzte Meldung ausgegeben. Ohne Fehler bleibt der Wert NULL. Der Anfangswert wird beim Einstieg auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen. |

## JSON-Eingabeformen

Die folgenden JSON-Pfade beschreiben die erkannten Objektfelder und SQL-Zieltypen, keine strikte JSON-Schema-Validierung. Zahlen werden in die angegebenen SQL-Zahltypen, bit in 0/1, Texte in die angegebenen Zeichenlängen und Zeitstempel in datetime2 konvertiert. sysname entspricht nvarchar(128). Namen und Pfade sind in der angegebenen Schreibweise zu übergeben. Fehlende Eigenschaften werden als NULL projiziert; Konvertierungs- oder NOT-NULL-Zielverletzungen können ERROR_HANDLED auslösen. Nicht erkannte Eigenschaften werden ignoriert. Arrays enthalten jeweils Objekte; importierte Status-/Kategorietexte besitzen hier keine geschlossene validierte Wertemenge.

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
EXEC [monitor].[USP_CreateExecutionEvidenceJson] @Hilfe=1;
```

```sql
DECLARE @EvidenceJson nvarchar(max);
EXEC [monitor].[USP_CreateExecutionEvidenceJson] @StatisticsIoText=N'Table ''[demo].[Orders]''. Scan count 1, logical reads 2, physical reads 0, read-ahead reads 0, lob logical reads 0.', @StatisticsLanguage='AUTO', @ResultSetArt='NONE', @Json=@EvidenceJson OUTPUT;
```

```sql
DECLARE @EvidenceJson nvarchar(max);
EXEC [monitor].[USP_CreateExecutionEvidenceJson] @ExistingEvidenceJson=N'{"statisticsIo":[],"statisticsTime":[]}', @JsonErzeugen=1, @ResultSetArt='NONE', @Json=@EvidenceJson OUTPUT;
```

```sql
CREATE TABLE #CreateExecutionEvidenceJson_HelpExample (Seed bit NULL);
EXEC [monitor].[USP_CreateExecutionEvidenceJson] @ResultSetArt='TABLE', @ResultTablesJson=N'{"captureStatus":"#CreateExecutionEvidenceJson_HelpExample"}', @JsonErzeugen=0;
DROP TABLE #CreateExecutionEvidenceJson_HelpExample;
```

## Resultsets und Leserichtung

`captureStatus` beschreibt Umfang, Partialität und Datenschutzmodus. Danach folgen `statisticsIo`, `statisticsTime`, `planStatisticsUsage`, `objectReferences`, optionale aktuelle Statistiken und Histogramme, Predicate-Mappings, Collection-Status und Warnings. TABLE exportiert ausschließlich ausdrücklich benannte Ziele.

## Beispiele und Gegenbeispiele

Ein passender Example-Aufruf kombiniert einen bekannten Showplan mit den im selben Messfenster erfassten STATISTICS-IO- und STATISTICS-TIME-Blöcken und kennzeichnet die Zuordnung trotzdem nur mit der tatsächlich belegten `SameExecutionConfidence`. Ein Gegenbeispiel ist das Zusammenführen eines gecachten Plans mit einem später kopierten Meldungsblock ohne Quellenhinweis. Ebenso darf ein aktuelles Histogramm nicht als historischer Compilezustand ausgegeben werden.

## Leere oder partielle Ausgabe

Fehlende optionale Eingaben erzeugen leere benannte Arrays oder explizite Collection-Statuszeilen. Ein partiell geparster Meldungsblock bleibt als partiell sichtbar; unbekannte Formate werden nicht in erfundene Nullwerte umgedeutet. Wenn eine angeforderte aktuelle Statistikquelle nicht lesbar ist, bleiben bereits normalisierte Plan- und Meldungsevidenz erhalten. TABLE und RAW erzeugen keine künstliche fachliche Datenzeile für einen Leerfall.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `LOW` bis `HIGH_OPT_IN` |
| Standardpfad | Parsing bereits übergebener Texte und eines begrenzten Plan-XML |
| Teuerster Pfad | Gezielte aktuelle Statistik- und Histogrammabfragen |
| Haupttreiber | XML-Größe, Meldungsumfang, Statistikzahl und Histogrammschritte |
| Skalierung | Statement-, Statistik- und Schrittgrenzen wirken vor teuren Vertiefungen |
| Ressourcen | CPU und Speicher für XML/JSON; optional datenbanklokale Katalog-I/O |
| Begrenzungswirkung | `@StatementId`, `@MaxStatistiken` und `@MaxHistogrammSchritte` begrenzen Arbeit |
| Locking und Nebenwirkungen | Read-only; die analysierte Query wird nicht ausgeführt |
| Schutzmechanismus | Datenschutzmodi, Bestätigung für Rohdaten und begrenzte Quellmengen |
| Sicherer Einsatz | Mit eindeutig zugeordneten importierten Belegen und `DERIVED_ONLY` beginnen |
| Aussagegrenze | Normalisierung stellt keine fehlende Same-Execution-Beziehung her |

## Eine Zeile bedeutet

Die Granularität hängt vom Resultset ab: eine Capture-Zusammenfassung, eine IO-Objektzeile, ein TIME-Block, eine verwendete Statistik, eine Objektreferenz, ein Histogrammschritt oder eine Mappingbeziehung. Diese Zeilen dürfen nicht ohne Statement- und Quellenbezug zusammengeführt werden.

## So lesen

Prüfen Sie zuerst `captureStatus`, `SameExecutionConfidence` und ParseStatus. Berücksichtigen Sie danach IO und TIME auf Statementebene. Bewerten Sie Statistik- und Histogrammevidenz erst mit Compilezeit, Capturezeit und Datenschutzstatus.

## Warum kann das problematisch sein?

Ohne ein gemeinsames Evidenzformat werden Planoperatoren, objektbezogene Reads und Gesamtlaufzeit leicht aus unterschiedlichen Ausführungen vermischt. Rohwerte können außerdem vertrauliche Geschäftsdaten enthalten.

## Wann ist es kein Problem?

Fehlende optionale Statistik- oder Histogrammabschnitte sind im Standardpfad normal. Für viele Planfragen reichen Operator- und Runtime-Counter aus. `NULL` bedeutet unbekannt oder nicht erhoben und nicht gemessene Null.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche zusätzliche Ausführungsevidenz ist vorhanden, wie sicher ist ihre Zuordnung und welche Werte dürfen exportiert werden?

### Technischer Hintergrund

`SET STATISTICS IO` und `SET STATISTICS TIME` liefern Meldungstext, kein relationales Resultset. Die Parser sind deshalb best effort und markieren unbekannte oder partielle Formate. Histogrammgrenzwerte und Parameterwerte werden erst nach lokaler Korrelation entfernt oder tokenisiert. Bereits vorhandenes Evidence JSON wird ebenfalls erneut normalisiert und nicht als vorab vertrauenswürdig behandelt.

### Datenkette

Bereits übergebenes Showplan XML, `TVF_ParseStatisticsIoText`, `TVF_ParseStatisticsTimeText`, Plan-Extractor-Funktionen und optional gezielte Statistik-/Histogrammmetadaten.

### Source Select

Die Procedure führt keinen Workload aus. Ein zentraler Extraktionspfad liest Objektbezüge direkt aus bereits übergebenem Showplan-XML:

```sql
SELECT
      [r].[StatementId]
    , [r].[NodeId]
    , [r].[DatabaseName]
    , [r].[SchemaName]
    , [r].[ObjectName]
    , [r].[IndexName]
FROM [monitor].[TVF_ExecutionPlanObjectReferences]
     (@PlanXml, @StatementId) AS [r];
```

**Wichtig für die Eigenlast:** Setzen Sie `@StatementId` vor der XML-Knotenextraktion und aktivieren Sie nur benötigte Evidenzpfade. Führen Sie Histogrammzugriffe erst nach der aus dem Plan abgeleiteten kleinen Statistikmenge aus; `@MaxStatistiken` und `@MaxHistogrammSchritte` begrenzen diese Vertiefung.

### Zeit- und Scope-Modell

Jeder Abschnitt besitzt einen eigenen Capture- oder Compilezeitbezug. Aktuelle Statistics Properties sind nicht rückwirkend der Compilezustand.

### Bewertung und Gegenprobe

Prüfen Sie Same-Execution-Status, Statementzuordnung, Planhash, Capturezeit und Parameterkontext gemeinsam. Bestätigen Sie bei importierter Evidenz die Quellumgebung ausdrücklich.

### Typische Fehlinterpretation

Ein geparster Textblock ist nicht automatisch derselben Planexecution zugeordnet. Ein tokenisierter oder ausgelassener Wert ist auch kein SQL-NULL.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_ExecutionPlanAnalysis`, Query Store Runtime/Regression und gezielte Statistikverteilungsanalyse.

## Primärquellen

- [SET STATISTICS IO](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-statistics-io-transact-sql?view=sql-server-ver17)
- [SET STATISTICS TIME](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-statistics-time-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../04_Plan_Cache.md#execution-evidence-json)

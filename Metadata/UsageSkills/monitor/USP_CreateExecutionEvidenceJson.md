---
skill_format_version: "1.0.0"
name: "monitor.USP_CreateExecutionEvidenceJson"
schema_name: "monitor"
object_name: "USP_CreateExecutionEvidenceJson"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Erzeugt und validiert ein versioniertes Execution-Evidence-JSON aus Plan-XML, bereits erfassten STATISTICS IO/TIME-Meldungen und optional zielgerichteter Statistik-/Histogrammevidenz."
source_path: "Code/04_PlanCache/052_USP_CreateExecutionEvidenceJson.sql"
---

# monitor.USP_CreateExecutionEvidenceJson

## Zweck und Einsatz

Erzeugt und validiert ein versioniertes Execution-Evidence-JSON aus Plan-XML, bereits erfassten STATISTICS IO/TIME-Meldungen und optional zielgerichteter Statistik-/Histogrammevidenz.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_CreateExecutionEvidenceJson] im vorgesehenen Datenbankkontext. Die Procedure verwendet eigene Statistiktextparser und Plan-XML-Tabellenfunktionen auf den übergebenen Daten; sie liest nicht selbst fremde Planhandles oder Workloadtabellen.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @PlanXml | xml | nein | NULL |
| @StatisticsIoText | nvarchar(max) | nein | NULL |
| @StatisticsTimeText | nvarchar(max) | nein | NULL |
| @StatisticsLanguage | varchar(16) | nein | 'AUTO' |
| @StatisticsEvidenceJson | nvarchar(max) | nein | NULL |
| @ObjectMetadataJson | nvarchar(max) | nein | NULL |
| @StatistikEvidenzModus | varchar(16) | nein | 'PLAN_ONLY' |
| @HistogrammModus | varchar(16) | nein | 'NONE' |
| @MetadatenQuellenmodus | varchar(16) | nein | 'EVIDENCE_ONLY' |
| @QuellumgebungBestaetigt | bit | nein | 0 |
| @EvidenzDatenschutzModus | varchar(24) | nein | 'DERIVED_ONLY' |
| @IdentifierDatenschutzModus | varchar(16) | nein | 'RAW' |
| @SensitiveDataConfirmed | bit | nein | 0 |
| @MitPredicateHistogramMap | bit | nein | 1 |
| @StatementId | int | nein | NULL |
| @StatementOrdinal | int | nein | NULL |
| @SameExecutionAsPlanConfirmed | bit | nein | NULL |
| @CapturedAtUtc | datetime2(3) | nein | NULL |
| @SourceProductVersion | nvarchar(128) | nein | NULL |
| @SourceCompatibilityLevel | smallint | nein | NULL |
| @SourceEngineEdition | int | nein | NULL |
| @MaxStatistiken | int | nein | 100 |
| @MaxHistogrammSchritte | int | nein | 20000 |
| @LockTimeoutMs | int | nein | 0 |
| @HighImpactConfirmed | bit | nein | 0 |
| @AdditionalEvidenceJson | nvarchar(max) | nein | NULL |
| @ExistingEvidenceJson | nvarchar(max) | nein | NULL |
| @RawTextHandling | varchar(16) | nein | 'HASH_ONLY' |
| @StrictValidation | bit | nein | 1 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 1 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@PlanXml:** @PlanXml xml. Default ist NULL. Optionales bereits vorhandenes Plan-XML als SQL-Typ xml; Text kann durch SQL in diesen Typ konvertiert werden. NULL lässt die planbezogene Extraktion aus. Leeres XML oder XML ohne passende Showplan-Knoten kann keine passenden Bezüge liefern; die XML-Typprüfung ersetzt keine vollständige Showplan-Schemaprüfung. @StatementId begrenzt passende Extraktoren; die beschriebene Query wird niemals ausgeführt.

**@StatisticsIoText:** @StatisticsIoText nvarchar(max). Default ist NULL. optionaler, bereits erfasster STATISTICS-IO-Meldungstext. NULL oder Auslassen erzeugt keine aus diesem Argument geparsten Zeilen. Nicht erkannte oder teilweise lesbare Zeilen bleiben mit ParseStatus sichtbar; der Text wird mit @StatisticsLanguage geparst und StatementOrdinal kann fehlende Zuordnungen ergänzen. Rohtext wird abhängig von @RawTextHandling behandelt. Leerer oder nur aus Leerzeichen bestehender Text liefert keine Parserzeilen.

**@StatisticsTimeText:** @StatisticsTimeText nvarchar(max). Default ist NULL. optionaler, bereits erfasster STATISTICS-TIME-Meldungstext. NULL oder Auslassen erzeugt keine daraus geparsten Zeilen. Der Parser kennzeichnet teilweise oder unbekannte Formate, statt fehlende Messwerte als Null zu erfinden; die Sprache richtet sich nach @StatisticsLanguage und @StatementOrdinal kann fehlende Zuordnung ergänzen. Rohtextbehandlung folgt @RawTextHandling. Leerer oder nur aus Leerzeichen bestehender Text liefert keine Parserzeilen.

**@StatisticsLanguage:** @StatisticsLanguage varchar(16). Default ist 'AUTO'. AUTO erkennt unterstützte Meldungsteile automatisch; EN bezeichnet Englisch und DE Deutsch. Der IO-Parser normalisiert Groß-/Kleinschreibung und fällt bei NULL, leerem oder unbekanntem Code auf AUTO zurück. Der TIME-Parser verwendet die Kennung nicht und erkennt seine englischen/deutschen Textteile selbst. Es entsteht kein INVALID_PARAMETER für einen unbekannten Sprachcode.

**@StatisticsEvidenceJson:** @StatisticsEvidenceJson nvarchar(max). Default ist NULL. Optionaler Statistikabschnitt als JSON-Objekt mit statistics oder unmittelbar als Statistikobjekt. Unter statistics werden planUsage nur ohne @PlanXml und currentSnapshot, histogramSummaries sowie histogramSteps nur außerhalb CURRENT_SERVER als Arrays von Objekten projiziert; deren Feldnamen und SQL-Zieltypen stehen in den nachfolgenden JSON-Eingabeformen. Ein expliziter statistics-Abschnitt ersetzt den gleichnamigen Abschnitt aus @ExistingEvidenceJson. NULL importiert nichts; leerer Text ist ungültiges JSON. JSON_QUERY akzeptiert hier Objekt oder Array, eine strikte Objekt-/Feldprüfung findet nicht statt. Unbekannte Eigenschaften werden nicht übernommen. Bei ungültigem JSON oder fehlendem extrahierbarem Abschnitt führt @StrictValidation=1 intern zu 51021 und dem abgefangenen Status INVALID_EVIDENCE_JSON; andernfalls folgen Warnung und partielle Ausgabe. statisticsIo und statisticsTime an dieser Eingabewurzel werden nicht importiert.

**@ObjectMetadataJson:** @ObjectMetadataJson nvarchar(max). Default ist NULL. Optionales JSON-Array von Objektbezügen oder Objekt mit objectReferences. Die 21 erkannten Eintragsfelder und SQL-Zieltypen stehen in den nachfolgenden JSON-Eingabeformen. Der Abschnitt ersetzt objectReferences aus @ExistingEvidenceJson und wird nur ohne @PlanXml importiert. NULL importiert nichts; leerer Text ist ungültig. JSON_QUERY akzeptiert Objekt oder Array unter objectReferences; die Implementierung erzwingt keine strikte Array-/Feldstruktur und ignoriert unbekannte Eigenschaften. Ungültiges JSON oder eine nicht extrahierbare Form führt bei @StrictValidation=1 intern zu 51022 und zum abgefangenen Status INVALID_EVIDENCE_JSON; andernfalls folgen Warnung und partielle Ausgabe.

**@StatistikEvidenzModus:** @StatistikEvidenzModus varchar(16). Default ist 'PLAN_ONLY'. Zulässig sind NONE, PLAN_ONLY, USED, RELEVANT und OBJECT_ALL. NONE überspringt die Extraktion von Statistiknutzung aus dem übergebenen Plan. PLAN_ONLY extrahiert diese Compile-Evidenz ohne aktuelle Katalogabfrage. USED ergänzt aktuelle Metadaten der im Plan verwendeten Statistiken. RELEVANT ergänzt diese um Statistiken, deren führende Spalte einer im Plan referenzierten Predicate-Spalte entspricht. OBJECT_ALL ergänzt alle Statistiken der referenzierten Planobjekte. Aktuelle Ergänzungen benötigen @PlanXml und CURRENT_SERVER; die beiden breiten Modi benötigen High-Impact-Bestätigung. Importierte Statistikarrays werden durch NONE nicht pauschal entfernt. NULL fällt auf PLAN_ONLY zurück; äußere Leerzeichen und Groß-/Kleinschreibung werden normalisiert. Leerer oder unbekannter Code ist INVALID_PARAMETER.

**@HistogrammModus:** @HistogrammModus varchar(16). Default ist 'NONE'. geschlossene Auswahl NONE, SUMMARY, STEPS. NULL wird wie NONE behandelt; Trim und Großschreibung normalisieren Werte, unbekannte Werte sind INVALID_PARAMETER. NONE erhebt keine Histogramme; SUMMARY liefert Zusammenfassungen; STEPS liefert Histogrammschritte. SUMMARY und STEPS benötigen @MetadatenQuellenmodus=CURRENT_SERVER sowie @StatistikEvidenzModus USED, RELEVANT oder OBJECT_ALL; sonst INVALID_PARAMETER.

**@MetadatenQuellenmodus:** @MetadatenQuellenmodus varchar(16). Default ist 'EVIDENCE_ONLY'. Zulässig sind EVIDENCE_ONLY und CURRENT_SERVER. EVIDENCE_ONLY verarbeitet übergebene Plan-/JSON-/Meldungsevidenz ohne aktuelle Statistikabfragen. CURRENT_SERVER ruft die aktuelle Erhebung nur mit @PlanXml und Statistikmodus USED, RELEVANT oder OBJECT_ALL auf; importierte currentSnapshot-, Histogramm- und Predicate-Mapping-Arrays werden dann nicht geladen, auch wenn keine Erhebung stattfindet. CURRENT_SERVER verlangt unabhängig von einer tatsächlichen Erhebung @QuellumgebungBestaetigt=1; 0 und NULL führen zu SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED. Die Bestätigung des Aufrufers ist kein Herkunftsnachweis und keine Berechtigung. NULL als Quellenmodus bedeutet EVIDENCE_ONLY; Trim und Großschreibung werden normalisiert. Leerer oder unbekannter Code ist INVALID_PARAMETER.

**@QuellumgebungBestaetigt:** @QuellumgebungBestaetigt bit. Default ist 0. Eingabeform ist ein einzelner SQL-bit-Wert oder eine bit-Variable; leerer Text ist keine vorgesehene Eingabeform. SQL Server konvertiert Argumente vor Procedure-Eintritt zu bit; numerische Nichtnullwerte ergeben bit 1, daher ausdrücklich 0 oder 1 übergeben. Bei CURRENT_SERVER bestätigen 0 und NULL die Quelle nicht und führen unabhängig von einer tatsächlichen Erhebung zu SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED. 1 ist die Bestätigung des Aufrufers, dass CURRENT_SERVER der tatsächlichen Quelle entspricht; sie ist kein Herkunftsnachweis und erteilt keine Berechtigung. Ohne CURRENT_SERVER hat der Schalter keine Erhebungswirkung.

**@EvidenzDatenschutzModus:** @EvidenzDatenschutzModus varchar(24). Default ist 'DERIVED_ONLY'. geschlossene Auswahl DERIVED_ONLY, TOKENIZED, STRUCTURE_ONLY, RAW. NULL wird wie DERIVED_ONLY behandelt; Trim und Großschreibung normalisieren Werte, sonst INVALID_PARAMETER. DERIVED_ONLY entfernt konkrete Parameter-, Predicate- und Histogrammgrenzwerte aus dem exportierbaren Ergebnis; TOKENIZED ersetzt solche Werte durch capture-lokale Tokens; STRUCTURE_ONLY beschränkt die Ausgabe auf Struktur; RAW lässt Werte zu und erfordert @SensitiveDataConfirmed=1. Bei 0 oder NULL als Bestätigung folgt auf einem angeforderten RAW-Pfad SENSITIVE_DATA_CONFIRMATION_REQUIRED.

**@IdentifierDatenschutzModus:** @IdentifierDatenschutzModus varchar(16). Default ist 'RAW'. geschlossene Auswahl RAW, TOKENIZED, OMIT. NULL wird wie RAW behandelt; Trim und Großschreibung normalisieren, unbekannte Werte führen zu INVALID_PARAMETER. RAW erhält Identifikatoren, TOKENIZED ersetzt sie durch capture-lokale Tokens und OMIT lässt sie aus. Für @RawTextHandling=INCLUDE ist ausschließlich RAW zusammen mit @SensitiveDataConfirmed=1 zulässig.

**@SensitiveDataConfirmed:** @SensitiveDataConfirmed bit. Default ist 0. 0 bestätigt sensible Ausgabe nicht; 1 bestätigt die Ausgabe konkreter Werte bei RAW-Evidenz beziehungsweise Meldungsrohtext bei INCLUDE. Auf angeforderten RAW- oder INCLUDE-Pfaden führen 0 oder NULL zu SENSITIVE_DATA_CONFIRMATION_REQUIRED; INCLUDE benötigt zusätzlich IdentifierDatenschutzModus=RAW. Außerhalb dieser sensiblen Pfade wird NULL nicht global als ungültiger Parameter abgewiesen. additionalEvidence wird ausschließlich bei RAW und exakt 1 eingebettet.

**@MitPredicateHistogramMap:** @MitPredicateHistogramMap bit. Default ist 1. Eingabeform ist ein einzelner SQL-bit-Wert oder eine bit-Variable; leerer Text ist keine vorgesehene Eingabeform. SQL Server konvertiert Argumente vor Procedure-Eintritt zu bit; numerische Nichtnullwerte ergeben bit 1, daher ausdrücklich 0 oder 1 übergeben. 0 überspringt die Predicate-/Histogrammzuordnung im Collector; 1 aktiviert sie bei tatsächlich aufgerufenem Collector. Ohne Collector-Aufruf ist NULL unbenutzt und wird nicht global abgewiesen. Bei tatsächlicher aktueller Erhebung weist InternalCollectExecutionPlanMetadata NULL als INVALID_PARAMETER zurück; 052 meldet CURRENT_METADATA_COLLECTION_LIMITED mit Teilstatus. Der Schalter unterdrückt keine bereits importierten Mappingzeilen.

**@StatementId:** @StatementId int. Default ist NULL. optionale Statement-ID zum Begrenzen der Planextraktion und Statistikverwendung. NULL/Auslassen verarbeitet den Plan ohne diese Eingrenzung. Der Wert wird an die Plan-Extraktoren übergeben; ein nicht vorhandenes oder nicht zuordenbares Statement liefert entsprechend keine passenden Planbezüge. Für diese Eingabe besteht keine zusätzliche Bereichsvalidierung.

**@StatementOrdinal:** @StatementOrdinal int. Default ist NULL. Optionale ganze Ordnungsnummer ohne zusätzliche Bereichsprüfung. Nur mit @PlanXml füllt ein gesetzter Wert fehlende StatementOrdinal in geparsten IO-/TIME-Zeilen. Ohne Wert setzt ein Einzelstatementplan diese Zeilen auf 1; ein Mehrstatementplan lässt die Zuordnung offen und warnt bei vorhandenen Meldungszeilen mit partieller Ausgabe. Ohne @PlanXml hat der Parameter keine Zuordnungswirkung. NULL bedeutet keine explizite Zuordnung.

**@SameExecutionAsPlanConfirmed:** @SameExecutionAsPlanConfirmed bit. Default ist NULL. optionale Bestätigung, dass Meldungsevidenz derselben Ausführung wie der Plan entstammt. NULL/Auslassen bedeutet unbestätigt; 0 bedeutet ausdrücklich UNCONFIRMED; 1 bedeutet CONFIRMED. Andere Bitwerte sind nicht als eigene Validierungsbedingung implementiert. Diese Angabe beweist die Ausführungsbeziehung nicht selbst.

**@CapturedAtUtc:** @CapturedAtUtc datetime2(3). Default ist NULL. optionaler UTC-Zeitpunkt der Erfassung. NULL/Auslassen setzt capturedAtUtc auf die aktuelle UTC-Systemzeit; ein gesetzter Wert wird als Erfassungszeit übernommen. SQL konvertiert die Eingabe auf Millisekundenpräzision gemäß datetime2(3).

**@SourceProductVersion:** @SourceProductVersion nvarchar(128). Default ist NULL. optionale Produktversionsangabe der Quellumgebung für sourceEnvironment.productVersion. NULL/Auslassen bleibt im JSON null; keine Formatprüfung ist implementiert. Leerer Text wird unverändert als Text übergeben und nicht als NULL normalisiert.

**@SourceCompatibilityLevel:** @SourceCompatibilityLevel smallint. Default ist NULL. optionales Quell-Compatibility-Level. NULL/Auslassen bleibt null; erlaubter Zahlenbereich ist 80 bis 200 einschließlich. Werte außerhalb des Bereichs ergeben INVALID_PARAMETER. Der Wert wird als sourceEnvironment.compatibilityLevel ausgegeben.

**@SourceEngineEdition:** @SourceEngineEdition int. Default ist NULL. optionale Engine-Edition-Kennung der Quelle für sourceEnvironment.engineEdition. NULL/Auslassen bleibt null; es ist keine abgeschlossene Wertemenge oder separate Wertebereichsprüfung implementiert.

**@MaxStatistiken:** @MaxStatistiken int. Default ist 100. Begrenzung der Zahl aktueller Statistiken. NULL ist unzulässig; gültiger Bereich 1 bis 1000 einschließlich, andernfalls INVALID_PARAMETER. Der Grenzwert wirkt auf die zielgerichtete aktuelle Statistikerhebung.

**@MaxHistogrammSchritte:** @MaxHistogrammSchritte int. Default ist 20000. Begrenzung der erhobenen Histogrammschritte. NULL ist unzulässig; gültiger Bereich 0 bis 200000 einschließlich, andernfalls INVALID_PARAMETER. Der Grenzwert beschränkt Histogrammvertiefung; 0 erlaubt keine Histogrammschritte.

**@LockTimeoutMs:** @LockTimeoutMs int. Default ist 0. Wartezeitgrenze in Millisekunden für die optionale Metadatenerhebung. NULL ist unzulässig; gültiger Bereich 0 bis 60000 einschließlich, sonst INVALID_PARAMETER. 0 bedeutet keine Wartezeit auf gesperrte Ressourcen; ein positiver Wert begrenzt das Warten auf die angegebene Zahl Millisekunden.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 0 bestätigt keinen High-Impact-Pfad; 1 bestätigt die tatsächlich angeforderte breite Statistik- oder Histogrammerhebung. Der Collector verlangt diese Bestätigung für RELEVANT, OBJECT_ALL oder STEPS nur, wenn er mit @PlanXml, CURRENT_SERVER und einem aktuellen Statistikmodus aufgerufen wird; Berechtigungen werden dadurch nicht erteilt. NULL passiert die äußere NOT-IN-Prüfung, wird bei jeder tatsächlich angeforderten aktuellen Erhebung jedoch vom internen Collector als INVALID_PARAMETER zurückgewiesen; der Capture meldet dann CURRENT_METADATA_COLLECTION_LIMITED und Partialität. Ohne Collector-Aufruf ist daraus keine zusätzliche Gate-Prüfung abzuleiten. NULL ist keine ausdrückliche Bestätigung.

**@AdditionalEvidenceJson:** @AdditionalEvidenceJson nvarchar(max). Default ist NULL. optionales zusätzliches JSON, das unverändert als importierter Abschnitt nur bei @EvidenzDatenschutzModus=RAW und @SensitiveDataConfirmed=1 in additionalEvidence eingebettet wird; andernfalls ist dieser JSON-Schlüssel null. NULL/Auslassen markiert keine zusätzliche Evidenz. Ungültiges JSON führt bei @StrictValidation=1 zu Fehler 51023; sonst wird es verworfen, gewarnt und IsPartial gesetzt. Ein spezifisches geschlossenes Schlüsselschema wird hier nicht validiert; der Wert muss syntaktisch gültiges JSON sein. Ohne hinreichend strikte Datenschutzfreigabe werden zusätzliche Inhalte nicht in den Ausgabeabschnitt übernommen.

**@ExistingEvidenceJson:** @ExistingEvidenceJson nvarchar(max). Default ist NULL. Optionale Ausgangshülle als Execution-Evidence-JSON. Die ausgewerteten Wurzelabschnitte sind statisticsIo, statisticsTime, statistics, objectReferences und predicateHistogramMappings; statistics besitzt planUsage, currentSnapshot, histogramSummaries und histogramSteps. Die erkannten Objektfelder und SQL-Zieltypen stehen nachfolgend. Unbekannte Eigenschaften und bisherige meta-/capture-/Warnungsabschnitte werden nicht unverändert exportiert. Eigene Statistik-/Objektparameter ersetzen gleichnamige Abschnitte. Mit @PlanXml stammen planUsage und objectReferences aus dem Plan; ohne CURRENT_SERVER werden aktuelle Statistik-, Histogramm- und Mappingarrays importiert. Importierte IO-/TIME-Zeilen werden zusätzlich zu geparsten Textzeilen eingefügt, mit RawLine=NULL; Dubletten werden nicht automatisch entfernt. NULL startet eine leere Hülle; leerer Text ist ungültiges JSON. Ungültiges JSON führt bei StrictValidation=1 intern zu 51024 und dem abgefangenen Status INVALID_EVIDENCE_JSON, sonst zu Warnung und partieller Ausgabe.

**@RawTextHandling:** @RawTextHandling varchar(16). Default ist 'HASH_ONLY'. geschlossene Auswahl NONE, HASH_ONLY, INCLUDE. NULL wird wie HASH_ONLY behandelt; Trim und Großschreibung normalisieren Werte, andere Werte ergeben INVALID_PARAMETER. NONE entfernt Rohzeilen und gibt keine Eingabehashes aus; HASH_ONLY entfernt Rohzeilen und gibt Eingabelängen sowie SHA-256-Hashes der IO-/TIME-Texte aus; INCLUDE erhält geparste Rohzeilen im Ergebnis und gibt Eingabehashes aus. INCLUDE erfordert @SensitiveDataConfirmed=1 und @IdentifierDatenschutzModus=RAW; 0 oder NULL als Bestätigung führt zu SENSITIVE_DATA_CONFIRMATION_REQUIRED.

**@StrictValidation:** @StrictValidation bit. Default ist 1. 1 behandelt ungültiges importiertes JSON oder nicht extrahierbare Teilpayloads als interne Fehler 51021 bis 51024; der CATCH liefert INVALID_EVIDENCE_JSON, Partialität und die Fehler-OUTPUTs. 0 verwirft diese Payloads mit Warnung und partieller Ausgabe. NULL passiert NOT IN (0,1) und folgt bei IF=1 dem nicht strikten Zweig. Typkonvertierungs- und Zieltabellenfehler können auch mit 0 in ERROR_HANDLED enden; TABLE-Vorbereitungsfehler liegen außerhalb dieses CATCH.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. geschlossene Auswahl CONSOLE, RAW, TABLE, NONE. NULL und Leertext normalisieren zu leer und führen INVALID_PARAMETER. Werte werden getrimmt und großgeschrieben. CONSOLE ruft InternalEmitConsoleResult mit captureStatus als Quelle auf; RAW gibt die elf benannten Tabellen als elf Resultsets aus; TABLE schreibt angeforderte Resultate in ausdrücklich zugeordnete Ziele; NONE emittiert keine Resultsets. Unbekannte Werte sind INVALID_PARAMETER. CONSOLE ist die getrennte Konsolenausgabe, nicht ein JSON-Resultset.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. optionales JSON-Objekt, dessen Schlüssel die Resultatnamen und dessen Zeichenkettenwerte vorhandene lokale Zieltabellen bezeichnen, zum Beispiel {"captureStatus":"#Capture"}. Es darf mindestens eine Zuordnung enthalten; alle Namen müssen aus der geschlossenen Liste captureStatus, statisticsIo, statisticsTime, planStatisticsUsage, objectReferences, currentStatistics, histogramSummaries, histogramSteps, predicateHistogramMappings, collectionStatus und warnings stammen. Jede Zieltabelle muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale Temp-Tabellen, Namen über 116 Zeichen, Ziele mit Präfix #Monitor, doppelte Namen oder Ziele und andere JSON-Werttypen werden abgelehnt. NULL/Auslassen wird im TABLE-Modus als ungültige Zuordnung abgelehnt; außerhalb TABLE führt ein gesetzter Wert zu INVALID_PARAMETER. Helper-Fehler werden als Fehler 51011 ausgelöst.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 1. Schalter zur Erzeugung des kanonischen JSON in @Json. 1 erzeugt das JSON, 0 lässt @Json auf NULL. 0 und 1 steuern die Ausgabe; NULL passiert NOT IN (0,1), erzeugt bei IF=1 aber kein JSON. Das JSON ist ein eigener OUTPUT-Parameter und wird bei @ResultSetArt=CONSOLE nicht als Resultset ausgegeben.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Optionaler OUTPUT-Empfang als nvarchar(max)-Variable mit OUTPUT; ein übergebener Anfangswert wird auf NULL zurückgesetzt. JsonErzeugen=1 erzeugt das versionierte Execution-Evidence-Objekt, 0 oder NULL lässt den Ausgang NULL. Wurzelkeys sind meta, capture, sourceEnvironment, planIdentity, statisticsIo, statisticsTime, statistics, objectReferences, predicateHistogramMappings, collectionStatus, warnings, rawInput, importedEvidence und additionalEvidence. statistics enthält planUsage, currentSnapshot, histogramSummaries und histogramSteps als Arrays. IO, TIME, Objektbezüge, Mappings, Collection-Status und Warnings sind Arrays; fehlende optionale Skalare bleiben JSON-null. ResultSetArt ist davon unabhängig. Ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 gibt bei Status außerhalb AVAILABLE eine Severity-10-Meldung über RAISERROR WITH NOWAIT aus. 0 oder NULL unterdrückt diese Meldung. Die Hilfsausgabe wird dadurch nicht deaktiviert.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 druckt die Parameterhilfe und kehrt vor Parameterprüfung, TABLE-Vorbereitung und Erhebung zurück. 0 oder NULL folgt dem normalen Pfad. Zuvor werden @Json auf NULL und die vier Status-OUTPUTs auf AVAILABLE, 0, NULL und NULL gesetzt; auch SET LOCK_TIMEOUT 0 liegt vor dem Hilfe-RETURN.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT. Default ist NULL. als varchar(40)-Variable mit OUTPUT zu binden. Erhält den StatusCode der Ausführung, anfänglich AVAILABLE und bei Validierungs-, Datenschutz-, Quellumgebungs- oder Verarbeitungsfällen entsprechend ersetzt. Der Status ist maschinenlesbar und Teil von captureStatus; der Aufrufende soll den gelieferten Wert auswerten. Der Anfangswert wird beim Einstieg auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen.

**@IsPartialOut:** @IsPartialOut bit OUTPUT. Default ist NULL. als bit-Variable mit OUTPUT zu binden. 0 bedeutet zunächst nicht partiell; ungültige/verworfene optionale Evidenz oder andere begrenzte Verarbeitung kann auf 1 setzen. Der Wert beschreibt die Vollständigkeit der erzeugten Evidenz, nicht den Erfolg eines ausgeführten Workloads. Der Anfangswert wird beim Einstieg auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT. Default ist NULL. als int-Variable mit OUTPUT zu binden. Zu Beginn NULL; bei abgefangenen Fehlern wird die SQL-Fehlernummer ausgegeben. Ohne solchen Fehler bleibt der Wert NULL. Der Anfangswert wird beim Einstieg auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT. Default ist NULL. als nvarchar(2048)-Variable mit OUTPUT zu binden. Zu Beginn NULL; bei Status- oder Verarbeitungsfehlern wird eine begrenzte Meldung ausgegeben. Ohne Fehler bleibt der Wert NULL. Der Anfangswert wird beim Einstieg auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| captureStatus | 1 | 1 | [ModuleName] sysname NOT NULL , [GeneratedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [SchemaVersion] int NOT NULL , [StatisticsIoRowCount] bigint NOT NULL , [StatisticsTimeRowCount] bigint NOT NULL , [PlanStatisticsUsageCount] bigint NOT NULL , [CurrentStatisticsCount] bigint NOT NULL , [HistogramStepCount] bigint NOT NULL , [PredicateMappingCount] bigint NOT NULL , [EvidencePrivacyMode] varchar(24) NOT NULL , [IdentifierPrivacyMode] varchar(16) NOT NULL , [SameExecutionConfidence] varchar(40) NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL |
| statisticsIo | 1 | 1 | [StatementOrdinal] int NULL,[MessageOrdinal] int NOT NULL,[ObjectOrdinal] int NOT NULL , [ObjectDisplayName] nvarchar(512) NULL,[ScanCount] bigint NULL,[LogicalReads] bigint NULL , [PhysicalReads] bigint NULL,[PageServerReads] bigint NULL,[ReadAheadReads] bigint NULL , [PageServerReadAheadReads] bigint NULL,[LobLogicalReads] bigint NULL,[LobPhysicalReads] bigint NULL , [LobPageServerReads] bigint NULL,[LobReadAheadReads] bigint NULL,[LobPageServerReadAheadReads] bigint NULL , [LanguageDetected] varchar(16) NOT NULL,[ParseStatus] varchar(40) NOT NULL,[RawLine] nvarchar(4000) NULL |
| statisticsTime | 1 | 1 | [StatementOrdinal] int NULL,[MessageOrdinal] int NOT NULL,[TimeCategory] varchar(24) NOT NULL , [CpuMs] bigint NULL,[ElapsedMs] bigint NULL,[LanguageDetected] varchar(16) NOT NULL , [ParseStatus] varchar(40) NOT NULL,[RawLine] nvarchar(4000) NULL |
| planStatisticsUsage | 1 | 1 | [StatisticsUsageOrdinal] bigint NOT NULL,[StatementOrdinal] int NOT NULL , [StatementId] int NULL,[StatementCompId] int NULL , [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[StatisticsName] sysname NULL , [LastUpdateAtCompile] datetime2(7) NULL,[ModificationCountAtCompile] bigint NULL , [SamplingPercentAtCompile] decimal(19,6) NULL,[SourceElement] nvarchar(128) NOT NULL,[ParseStatus] varchar(40) NOT NULL |
| objectReferences | 1 | 1 | [ReferenceOrdinal] bigint NOT NULL,[StatementOrdinal] int NOT NULL,[StatementId] int NULL,[StatementCompId] int NULL , [NodeId] int NULL,[ReferenceType] varchar(40) NOT NULL,[ReferenceSource] varchar(40) NOT NULL , [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[IndexName] sysname NULL , [AliasName] sysname NULL,[StorageType] nvarchar(128) NULL,[PlanObjectId] int NULL,[PlanIndexId] int NULL , [IsTemporaryObject] bit NOT NULL,[IsTableVariable] bit NOT NULL,[IsRemoteObject] bit NOT NULL,[IsDmlTarget] bit NOT NULL , [ResolutionCapability] varchar(40) NOT NULL,[SourceElement] nvarchar(128) NOT NULL |
| currentStatistics | 1 | 1 | [DatabaseName] sysname NULL, [SchemaName] sysname NULL, [ObjectName] sysname NULL, [ObjectId] int NOT NULL, [StatisticsName] sysname NULL, [StatisticsId] int NOT NULL, [IsIndexStatistics] bit NOT NULL, [IsAutoCreated] bit NULL, [IsUserCreated] bit NULL, [IsFiltered] bit NULL, [FilterDefinition] nvarchar(max) NULL, [FilterDefinitionStatus] varchar(40) NOT NULL, [NoRecompute] bit NULL, [IsIncremental] bit NULL, [HasPersistedSample] bit NULL, [LeadingColumnName] sysname NULL, [LastUpdated] datetime2(7) NULL, [Rows] bigint NULL, [RowsSampled] bigint NULL, [SamplePercent] decimal(19,6) NULL, [Steps] int NULL, [UnfilteredRows] bigint NULL, [ModificationCounter] bigint NULL, [ModificationPercent] decimal(19,6) NULL, [PersistedSamplePercent] float NULL, [CollectionStatus] varchar(40) NOT NULL |
| histogramSummaries | 1 | 1 | [DatabaseName] sysname NOT NULL,[SchemaName] sysname NOT NULL,[ObjectName] sysname NOT NULL , [StatisticsName] sysname NOT NULL,[StatisticsId] int NOT NULL,[LeadingColumnName] sysname NULL , [HistogramSteps] int NOT NULL,[HistogramEstimatedRows] float NULL,[MaxEqualRows] float NULL , [MaxRangeRows] float NULL,[MaxStepRows] float NULL,[DominantStepPercent] decimal(19,6) NULL , [TailStepRows] float NULL,[TailStepPercent] decimal(19,6) NULL,[CollectionStatus] varchar(40) NOT NULL |
| histogramSteps | 1 | 1 | [DatabaseName] sysname NULL, [SchemaName] sysname NULL, [ObjectName] sysname NULL, [StatisticsName] sysname NULL, [StatisticsId] int NOT NULL, [LeadingColumnName] sysname NULL, [StepOrdinal] int NOT NULL, [RangeHighKey] nvarchar(4000) NULL, [RangeHighKeyToken] varbinary(32) NULL, [RangeRows] float NULL, [EqualRows] float NULL, [DistinctRangeRows] bigint NULL, [AverageRangeRows] float NULL, [IsPredicateTarget] bit NOT NULL, [PredicateMatchCount] int NOT NULL, [SensitiveValueStatus] varchar(40) NOT NULL |
| predicateHistogramMappings | 1 | 1 | [PredicateReferenceId] bigint NOT NULL,[StatementOrdinal] int NOT NULL,[NodeId] int NULL , [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[ColumnName] sysname NULL , [StatisticsName] sysname NULL,[PredicateKind] varchar(40) NULL,[ValueSource] varchar(32) NOT NULL , [MappingStatus] varchar(48) NOT NULL,[MappingConfidence] varchar(16) NOT NULL,[MatchedStepOrdinal] int NULL , [MatchesRangeHighKey] bit NOT NULL,[IsBelowHistogram] bit NOT NULL,[IsAboveHistogram] bit NOT NULL , [SensitiveValueStatus] varchar(40) NOT NULL |
| collectionStatus | 1 | 1 | [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[StatisticsName] sysname NULL , [StatusCode] varchar(40) NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) NULL |
| warnings | 1 | 1 | [WarningCode] varchar(80) NOT NULL , [Severity] varchar(16) NOT NULL , [Detail] nvarchar(2048) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CreateExecutionEvidenceJson] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CreateExecutionEvidenceJson

Die folgenden JSON-Pfade beschreiben die erkannten Objektfelder und SQL-Zieltypen, keine strikte JSON-Schema-Validierung. Zahlen werden in die angegebenen SQL-Zahltypen, bit in 0/1, Texte in die angegebenen Zeichenlängen und Zeitstempel in datetime2 konvertiert. sysname entspricht nvarchar(128). Namen und Pfade sind in der angegebenen Schreibweise zu übergeben. Fehlende Eigenschaften werden als NULL projiziert; Konvertierungs- oder NOT-NULL-Zielverletzungen können ERROR_HANDLED auslösen. Nicht erkannte Eigenschaften werden ignoriert. Arrays enthalten jeweils Objekte; importierte Status-/Kategorietexte besitzen hier keine geschlossene validierte Wertemenge.

JSON-Eingabe $.statisticsIo: statementOrdinal int, messageOrdinal int, objectOrdinal int, objectDisplayName nvarchar(512), scanCount bigint, logicalReads bigint, physicalReads bigint, pageServerReads bigint, readAheadReads bigint, pageServerReadAheadReads bigint, lobLogicalReads bigint, lobPhysicalReads bigint, lobPageServerReads bigint, lobReadAheadReads bigint, lobPageServerReadAheadReads bigint, languageDetected varchar(16), parseStatus varchar(40).

JSON-Eingabe $.statisticsTime: statementOrdinal int, messageOrdinal int, timeCategory varchar(24), cpuMs bigint, elapsedMs bigint, languageDetected varchar(16), parseStatus varchar(40).

JSON-Eingabe $.statistics.planUsage: statisticsUsageOrdinal bigint, statementOrdinal int, statementId int, statementCompId int, databaseName sysname, schemaName sysname, objectName sysname, statisticsName sysname, lastUpdateAtCompile datetime2(7), modificationCountAtCompile bigint, samplingPercentAtCompile decimal(19,6), sourceElement nvarchar(128), parseStatus varchar(40).


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CreateExecutionEvidenceJson
Version      : 1.0.2
Stand        : 2026-07-21
Typ          : Stored Procedure
Zweck        : Erzeugt und validiert ein versioniertes Execution-Evidence-JSON
               aus Plan-XML, bereits erfassten STATISTICS IO/TIME-Meldungen und
               optional zielgerichteter Statistik-/Histogrammevidenz.
Sicherheit   : Führt niemals übergebenes SQL aus. Histogramm-, Parameter- und
               Predicatewerte werden standardmäßig DERIVED_ONLY verarbeitet.
SQL-Version  : SQL Server 2019 oder neuer.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CreateExecutionEvidenceJson
Die folgenden JSON-Pfade beschreiben die erkannten Objektfelder und SQL-Zieltypen, keine strikte JSON-Schema-Validierung. Zahlen werden in die angegebenen SQL-Zahltypen, bit in 0/1, Texte in die angegebenen Zeichenlängen und Zeitstempel in datetime2 konvertiert. sysname entspricht nvarchar(128). Namen und Pfade sind in der angegebenen Schreibweise zu übergeben. Fehlende Eigenschaften werden als NULL projiziert; Konvertierungs- oder NOT-NULL-Zielverletzungen können ERROR_HANDLED auslösen. Nicht erkannte Eigenschaften werden ignoriert. Arrays enthalten jeweils Objekte; importierte Status-/Kategorietexte besitzen hier keine geschlossene validierte Wertemenge.
JSON-Eingabe $.statisticsIo: statementOrdinal int, messageOrdinal int, objectOrdinal int, objectDisplayName nvarchar(512), scanCount bigint, logicalReads bigint, physicalReads bigint, pageServerReads bigint, readAheadReads bigint, pageServerReadAheadReads bigint, lobLogicalReads bigint, lobPhysicalReads bigint, lobPageServerReads bigint, lobReadAheadReads bigint, lobPageServerReadAheadReads bigint, languageDetected varchar(16), parseStatus varchar(40).
JSON-Eingabe $.statisticsTime: statementOrdinal int, messageOrdinal int, timeCategory varchar(24), cpuMs bigint, elapsedMs bigint, languageDetected varchar(16), parseStatus varchar(40).
JSON-Eingabe $.statistics.planUsage: statisticsUsageOrdinal bigint, statementOrdinal int, statementId int, statementCompId int, databaseName sysname, schemaName sysname, objectName sysname, statisticsName sysname, lastUpdateAtCompile datetime2(7), modificationCountAtCompile bigint, samplingPercentAtCompile decimal(19,6), sourceElement nvarchar(128), parseStatus varchar(40).
JSON-Eingabe $.objectReferences: referenceOrdinal bigint, statementOrdinal int, statementId int, statementCompId int, nodeId int, referenceType varchar(40), referenceSource varchar(40), databaseName sysname, schemaName sysname, objectName sysname, indexName sysname, aliasName sysname, storageType nvarchar(128), planObjectId int, planIndexId int, isTemporaryObject bit, isTableVariable bit, isRemoteObject bit, isDmlTarget bit, resolutionCapability varchar(40), sourceElement nvarchar(128).
JSON-Eingabe $.statistics.currentSnapshot: databaseName sysname, schemaName sysname, objectName sysname, objectId int, statisticsName sysname, statisticsId int, isIndexStatistics bit, isAutoCreated bit, isUserCreated bit, isFiltered bit, filterDefinition nvarchar(max), noRecompute bit, isIncremental bit, hasPersistedSample bit, leadingColumnName sysname, lastUpdated datetime2(7), rows bigint, rowsSampled bigint, samplePercent decimal(19,6), steps int, unfilteredRows bigint, modificationCounter bigint, modificationPercent decimal(19,6), persistedSamplePercent float, collectionStatus varchar(40).
JSON-Eingabe $.statistics.histogramSummaries: databaseName sysname, schemaName sysname, objectName sysname, statisticsName sysname, statisticsId int, leadingColumnName sysname, histogramSteps int, histogramEstimatedRows float, maxEqualRows float, maxRangeRows float, maxStepRows float, dominantStepPercent decimal(19,6), tailStepRows float, tailStepPercent decimal(19,6), collectionStatus varchar(40).
JSON-Eingabe $.statistics.histogramSteps: databaseName sysname, schemaName sysname, objectName sysname, statisticsName sysname, statisticsId int, leadingColumnName sysname, stepOrdinal int, rangeHighKey nvarchar(4000), rangeRows float, equalRows float, distinctRangeRows bigint, averageRangeRows float, isPredicateTarget bit, predicateMatchCount int.
JSON-Eingabe $.predicateHistogramMappings: predicateReferenceId bigint, statementOrdinal int, nodeId int, databaseName sysname, schemaName sysname, objectName sysname, columnName sysname, statisticsName sysname, predicateKind varchar(40), valueSource varchar(32), mappingStatus varchar(48), mappingConfidence varchar(16), matchedStepOrdinal int, matchesRangeHighKey bit, isBelowHistogram bit, isAboveHistogram bit, sensitiveValueStatus varchar(40).
Beispiel 1. EXEC [monitor].[USP_CreateExecutionEvidenceJson] @Hilfe=1;
Beispiel 2. DECLARE @EvidenceJson nvarchar(max); EXEC [monitor].[USP_CreateExecutionEvidenceJson] @StatisticsIoText=N'Table ''[demo].[Orders]''. Scan count 1, logical reads 2, physical reads 0, read-ahead reads 0, lob logical reads 0.', @StatisticsLanguage='AUTO', @ResultSetArt='NONE', @Json=@EvidenceJson OUTPUT;
Beispiel 3. DECLARE @EvidenceJson nvarchar(max); EXEC [monitor].[USP_CreateExecutionEvidenceJson] @ExistingEvidenceJson=N'{"statisticsIo":[],"statisticsTime":[]}', @JsonErzeugen=1, @ResultSetArt='NONE', @Json=@EvidenceJson OUTPUT;
Beispiel 4. CREATE TABLE #CreateExecutionEvidenceJson_HelpExample (Seed bit NULL); EXEC [monitor].[USP_CreateExecutionEvidenceJson] @ResultSetArt='TABLE', @ResultTablesJson=N'{"captureStatus":"#CreateExecutionEvidenceJson_HelpExample"}', @JsonErzeugen=0; DROP TABLE #CreateExecutionEvidenceJson_HelpExample;
```


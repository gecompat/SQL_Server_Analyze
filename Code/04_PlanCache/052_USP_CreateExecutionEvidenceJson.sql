USE [DeineDatenbank];
GO

/*
===============================================================================
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
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CreateExecutionEvidenceJson]
      @PlanXml                       xml             = NULL
    , @StatisticsIoText              nvarchar(max)   = NULL
    , @StatisticsTimeText            nvarchar(max)   = NULL
    , @StatisticsLanguage            varchar(16)     = 'AUTO'
    , @StatisticsEvidenceJson        nvarchar(max)   = NULL
    , @ObjectMetadataJson            nvarchar(max)   = NULL
    , @StatistikEvidenzModus         varchar(16)     = 'PLAN_ONLY'
    , @HistogrammModus               varchar(16)     = 'NONE'
    , @MetadatenQuellenmodus         varchar(16)     = 'EVIDENCE_ONLY'
    , @QuellumgebungBestaetigt       bit             = 0
    , @EvidenzDatenschutzModus       varchar(24)     = 'DERIVED_ONLY'
    , @IdentifierDatenschutzModus    varchar(16)     = 'RAW'
    , @SensitiveDataConfirmed        bit             = 0
    , @MitPredicateHistogramMap      bit             = 1
    , @StatementId                   int             = NULL
    , @StatementOrdinal              int             = NULL
    , @SameExecutionAsPlanConfirmed  bit             = NULL
    , @CapturedAtUtc                 datetime2(3)    = NULL
    , @SourceProductVersion          nvarchar(128)   = NULL
    , @SourceCompatibilityLevel      smallint        = NULL
    , @SourceEngineEdition           int             = NULL
    , @MaxStatistiken                int             = 100
    , @MaxHistogrammSchritte         int             = 20000
    , @LockTimeoutMs                 int             = 0
    , @HighImpactConfirmed           bit             = 0
    , @AdditionalEvidenceJson        nvarchar(max)   = NULL
    , @ExistingEvidenceJson          nvarchar(max)   = NULL
    , @RawTextHandling               varchar(16)     = 'HASH_ONLY'
    , @StrictValidation              bit             = 1
    , @ResultSetArt                  varchar(16)     = 'CONSOLE'
    , @ResultTablesJson              nvarchar(max)   = NULL
    , @JsonErzeugen                  bit             = 1
    , @Json                          nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                bit             = 1
    , @Hilfe                         bit             = 0
    , @StatusCodeOut                 varchar(40)     = NULL OUTPUT
    , @IsPartialOut                  bit             = NULL OUTPUT
    , @ErrorNumberOut                int             = NULL OUTPUT
    , @ErrorMessageOut               nvarchar(2048)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json=NULL;

    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ConsoleResultRequested bit=CONVERT(bit,CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END);
    DECLARE @TableRequested bit=CONVERT(bit,CASE WHEN @OutputMode='TABLE' THEN 1 ELSE 0 END);
    DECLARE @StatisticsMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@StatistikEvidenzModus,'PLAN_ONLY'))));
    DECLARE @HistogramMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@HistogrammModus,'NONE'))));
    DECLARE @MetadataSourceMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@MetadatenQuellenmodus,'EVIDENCE_ONLY'))));
    DECLARE @PrivacyMode varchar(24)=UPPER(LTRIM(RTRIM(COALESCE(@EvidenzDatenschutzModus,'DERIVED_ONLY'))));
    DECLARE @IdentifierMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@IdentifierDatenschutzModus,'RAW'))));
    DECLARE @RawMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@RawTextHandling,'HASH_ONLY'))));
    DECLARE @GeneratedAtUtc datetime2(3)=COALESCE(@CapturedAtUtc,SYSUTCDATETIME());
    DECLARE @TokenSalt varbinary(32)=CRYPT_GEN_RANDOM(32);
    DECLARE @SameExecutionConfidence varchar(40)=CASE
        WHEN @SameExecutionAsPlanConfirmed=1 THEN 'CONFIRMED'
        WHEN @SameExecutionAsPlanConfirmed=0 THEN 'UNCONFIRMED'
        ELSE 'UNCONFIRMED' END;

    SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_CreateExecutionEvidenceJson';
        PRINT N'@PlanXml xml. Default ist NULL. Optionales bereits vorhandenes Plan-XML als SQL-Typ xml; Text kann durch SQL in diesen Typ konvertiert werden. NULL lässt die planbezogene Extraktion aus. Leeres XML oder XML ohne passende Showplan-Knoten kann keine passenden Bezüge liefern; die XML-Typprüfung ersetzt keine vollständige Showplan-Schemaprüfung. @StatementId begrenzt passende Extraktoren; die beschriebene Query wird niemals ausgeführt.';
        PRINT N'@StatisticsIoText nvarchar(max). Default ist NULL. optionaler, bereits erfasster STATISTICS-IO-Meldungstext. NULL oder Auslassen erzeugt keine aus diesem Argument geparsten Zeilen. Nicht erkannte oder teilweise lesbare Zeilen bleiben mit ParseStatus sichtbar; der Text wird mit @StatisticsLanguage geparst und StatementOrdinal kann fehlende Zuordnungen ergänzen. Rohtext wird abhängig von @RawTextHandling behandelt. Leerer oder nur aus Leerzeichen bestehender Text liefert keine Parserzeilen.';
        PRINT N'@StatisticsTimeText nvarchar(max). Default ist NULL. optionaler, bereits erfasster STATISTICS-TIME-Meldungstext. NULL oder Auslassen erzeugt keine daraus geparsten Zeilen. Der Parser kennzeichnet teilweise oder unbekannte Formate, statt fehlende Messwerte als Null zu erfinden; die Sprache richtet sich nach @StatisticsLanguage und @StatementOrdinal kann fehlende Zuordnung ergänzen. Rohtextbehandlung folgt @RawTextHandling. Leerer oder nur aus Leerzeichen bestehender Text liefert keine Parserzeilen.';
        PRINT N'@StatisticsLanguage varchar(16). Default ist ''AUTO''. AUTO erkennt unterstützte Meldungsteile automatisch; EN bezeichnet Englisch und DE Deutsch. Der IO-Parser normalisiert Groß-/Kleinschreibung und fällt bei NULL, leerem oder unbekanntem Code auf AUTO zurück. Der TIME-Parser verwendet die Kennung nicht und erkennt seine englischen/deutschen Textteile selbst. Es entsteht kein INVALID_PARAMETER für einen unbekannten Sprachcode.';
        PRINT N'@StatisticsEvidenceJson nvarchar(max). Default ist NULL. Optionaler Statistikabschnitt als JSON-Objekt mit statistics oder unmittelbar als Statistikobjekt. Unter statistics werden planUsage nur ohne @PlanXml und currentSnapshot, histogramSummaries sowie histogramSteps nur außerhalb CURRENT_SERVER als Arrays von Objekten projiziert; deren Feldnamen und SQL-Zieltypen stehen in den nachfolgenden JSON-Eingabeformen. Ein expliziter statistics-Abschnitt ersetzt den gleichnamigen Abschnitt aus @ExistingEvidenceJson. NULL importiert nichts; leerer Text ist ungültiges JSON. JSON_QUERY akzeptiert hier Objekt oder Array, eine strikte Objekt-/Feldprüfung findet nicht statt. Unbekannte Eigenschaften werden nicht übernommen. Bei ungültigem JSON oder fehlendem extrahierbarem Abschnitt führt @StrictValidation=1 intern zu 51021 und dem abgefangenen Status INVALID_EVIDENCE_JSON; andernfalls folgen Warnung und partielle Ausgabe. statisticsIo und statisticsTime an dieser Eingabewurzel werden nicht importiert.';
        PRINT N'@ObjectMetadataJson nvarchar(max). Default ist NULL. Optionales JSON-Array von Objektbezügen oder Objekt mit objectReferences. Die 21 erkannten Eintragsfelder und SQL-Zieltypen stehen in den nachfolgenden JSON-Eingabeformen. Der Abschnitt ersetzt objectReferences aus @ExistingEvidenceJson und wird nur ohne @PlanXml importiert. NULL importiert nichts; leerer Text ist ungültig. JSON_QUERY akzeptiert Objekt oder Array unter objectReferences; die Implementierung erzwingt keine strikte Array-/Feldstruktur und ignoriert unbekannte Eigenschaften. Ungültiges JSON oder eine nicht extrahierbare Form führt bei @StrictValidation=1 intern zu 51022 und zum abgefangenen Status INVALID_EVIDENCE_JSON; andernfalls folgen Warnung und partielle Ausgabe.';
        PRINT N'@StatistikEvidenzModus varchar(16). Default ist ''PLAN_ONLY''. Zulässig sind NONE, PLAN_ONLY, USED, RELEVANT und OBJECT_ALL. NONE überspringt die Extraktion von Statistiknutzung aus dem übergebenen Plan. PLAN_ONLY extrahiert diese Compile-Evidenz ohne aktuelle Katalogabfrage. USED ergänzt aktuelle Metadaten der im Plan verwendeten Statistiken. RELEVANT ergänzt diese um Statistiken, deren führende Spalte einer im Plan referenzierten Predicate-Spalte entspricht. OBJECT_ALL ergänzt alle Statistiken der referenzierten Planobjekte. Aktuelle Ergänzungen benötigen @PlanXml und CURRENT_SERVER; die beiden breiten Modi benötigen High-Impact-Bestätigung. Importierte Statistikarrays werden durch NONE nicht pauschal entfernt. NULL fällt auf PLAN_ONLY zurück; äußere Leerzeichen und Groß-/Kleinschreibung werden normalisiert. Leerer oder unbekannter Code ist INVALID_PARAMETER.';
        PRINT N'@HistogrammModus varchar(16). Default ist ''NONE''. geschlossene Auswahl NONE, SUMMARY, STEPS. NULL wird wie NONE behandelt; Trim und Großschreibung normalisieren Werte, unbekannte Werte sind INVALID_PARAMETER. NONE erhebt keine Histogramme; SUMMARY liefert Zusammenfassungen; STEPS liefert Histogrammschritte. SUMMARY und STEPS benötigen @MetadatenQuellenmodus=CURRENT_SERVER sowie @StatistikEvidenzModus USED, RELEVANT oder OBJECT_ALL; sonst INVALID_PARAMETER.';
        PRINT N'@MetadatenQuellenmodus varchar(16). Default ist ''EVIDENCE_ONLY''. Zulässig sind EVIDENCE_ONLY und CURRENT_SERVER. EVIDENCE_ONLY verarbeitet übergebene Plan-/JSON-/Meldungsevidenz ohne aktuelle Statistikabfragen. CURRENT_SERVER ruft die aktuelle Erhebung nur mit @PlanXml und Statistikmodus USED, RELEVANT oder OBJECT_ALL auf; importierte currentSnapshot-, Histogramm- und Predicate-Mapping-Arrays werden dann nicht geladen, auch wenn keine Erhebung stattfindet. CURRENT_SERVER verlangt unabhängig von einer tatsächlichen Erhebung @QuellumgebungBestaetigt=1; 0 und NULL führen zu SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED. Die Bestätigung des Aufrufers ist kein Herkunftsnachweis und keine Berechtigung. NULL als Quellenmodus bedeutet EVIDENCE_ONLY; Trim und Großschreibung werden normalisiert. Leerer oder unbekannter Code ist INVALID_PARAMETER.';
        PRINT N'@QuellumgebungBestaetigt bit. Default ist 0. Eingabeform ist ein einzelner SQL-bit-Wert oder eine bit-Variable; leerer Text ist keine vorgesehene Eingabeform. SQL Server konvertiert Argumente vor Procedure-Eintritt zu bit; numerische Nichtnullwerte ergeben bit 1, daher ausdrücklich 0 oder 1 übergeben. Bei CURRENT_SERVER bestätigen 0 und NULL die Quelle nicht und führen unabhängig von einer tatsächlichen Erhebung zu SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED. 1 ist die Bestätigung des Aufrufers, dass CURRENT_SERVER der tatsächlichen Quelle entspricht; sie ist kein Herkunftsnachweis und erteilt keine Berechtigung. Ohne CURRENT_SERVER hat der Schalter keine Erhebungswirkung.';
        PRINT N'@EvidenzDatenschutzModus varchar(24). Default ist ''DERIVED_ONLY''. geschlossene Auswahl DERIVED_ONLY, TOKENIZED, STRUCTURE_ONLY, RAW. NULL wird wie DERIVED_ONLY behandelt; Trim und Großschreibung normalisieren Werte, sonst INVALID_PARAMETER. DERIVED_ONLY entfernt konkrete Parameter-, Predicate- und Histogrammgrenzwerte aus dem exportierbaren Ergebnis; TOKENIZED ersetzt solche Werte durch capture-lokale Tokens; STRUCTURE_ONLY beschränkt die Ausgabe auf Struktur; RAW lässt Werte zu und erfordert @SensitiveDataConfirmed=1. Bei 0 oder NULL als Bestätigung folgt auf einem angeforderten RAW-Pfad SENSITIVE_DATA_CONFIRMATION_REQUIRED.';
        PRINT N'@IdentifierDatenschutzModus varchar(16). Default ist ''RAW''. geschlossene Auswahl RAW, TOKENIZED, OMIT. NULL wird wie RAW behandelt; Trim und Großschreibung normalisieren, unbekannte Werte führen zu INVALID_PARAMETER. RAW erhält Identifikatoren, TOKENIZED ersetzt sie durch capture-lokale Tokens und OMIT lässt sie aus. Für @RawTextHandling=INCLUDE ist ausschließlich RAW zusammen mit @SensitiveDataConfirmed=1 zulässig.';
        PRINT N'@SensitiveDataConfirmed bit. Default ist 0. 0 bestätigt sensible Ausgabe nicht; 1 bestätigt die Ausgabe konkreter Werte bei RAW-Evidenz beziehungsweise Meldungsrohtext bei INCLUDE. Auf angeforderten RAW- oder INCLUDE-Pfaden führen 0 oder NULL zu SENSITIVE_DATA_CONFIRMATION_REQUIRED; INCLUDE benötigt zusätzlich IdentifierDatenschutzModus=RAW. Außerhalb dieser sensiblen Pfade wird NULL nicht global als ungültiger Parameter abgewiesen. additionalEvidence wird ausschließlich bei RAW und exakt 1 eingebettet.';
        PRINT N'@MitPredicateHistogramMap bit. Default ist 1. 0 überspringt den Collector-Pfad für Predicate-/Histogrammzuordnung; 1 aktiviert ihn bei tatsächlich aufgerufener aktueller Erhebung. NULL kann die öffentliche NOT-IN-Prüfung passieren. Bei tatsächlich angeforderter aktueller Erhebung weist der interne Collector NULL als INVALID_PARAMETER zurück; der Capture meldet CURRENT_METADATA_COLLECTION_LIMITED und wird partiell. Der Schalter unterdrückt keine bereits importierten Mappingzeilen.';
        PRINT N'@StatementId int. Default ist NULL. optionale Statement-ID zum Begrenzen der Planextraktion und Statistikverwendung. NULL/Auslassen verarbeitet den Plan ohne diese Eingrenzung. Der Wert wird an die Plan-Extraktoren übergeben; ein nicht vorhandenes oder nicht zuordenbares Statement liefert entsprechend keine passenden Planbezüge. Für diese Eingabe besteht keine zusätzliche Bereichsvalidierung.';
        PRINT N'@StatementOrdinal int. Default ist NULL. Optionale ganze Ordnungsnummer ohne zusätzliche Bereichsprüfung. Nur mit @PlanXml füllt ein gesetzter Wert fehlende StatementOrdinal in geparsten IO-/TIME-Zeilen. Ohne Wert setzt ein Einzelstatementplan diese Zeilen auf 1; ein Mehrstatementplan lässt die Zuordnung offen und warnt bei vorhandenen Meldungszeilen mit partieller Ausgabe. Ohne @PlanXml hat der Parameter keine Zuordnungswirkung. NULL bedeutet keine explizite Zuordnung.';
        PRINT N'@SameExecutionAsPlanConfirmed bit. Default ist NULL. optionale Bestätigung, dass Meldungsevidenz derselben Ausführung wie der Plan entstammt. NULL/Auslassen bedeutet unbestätigt; 0 bedeutet ausdrücklich UNCONFIRMED; 1 bedeutet CONFIRMED. Andere Bitwerte sind nicht als eigene Validierungsbedingung implementiert. Diese Angabe beweist die Ausführungsbeziehung nicht selbst.';
        PRINT N'@CapturedAtUtc datetime2(3). Default ist NULL. optionaler UTC-Zeitpunkt der Erfassung. NULL/Auslassen setzt capturedAtUtc auf die aktuelle UTC-Systemzeit; ein gesetzter Wert wird als Erfassungszeit übernommen. SQL konvertiert die Eingabe auf Millisekundenpräzision gemäß datetime2(3).';
        PRINT N'@SourceProductVersion nvarchar(128). Default ist NULL. optionale Produktversionsangabe der Quellumgebung für sourceEnvironment.productVersion. NULL/Auslassen bleibt im JSON null; keine Formatprüfung ist implementiert. Leerer Text wird unverändert als Text übergeben und nicht als NULL normalisiert.';
        PRINT N'@SourceCompatibilityLevel smallint. Default ist NULL. optionales Quell-Compatibility-Level. NULL/Auslassen bleibt null; erlaubter Zahlenbereich ist 80 bis 200 einschließlich. Werte außerhalb des Bereichs ergeben INVALID_PARAMETER. Der Wert wird als sourceEnvironment.compatibilityLevel ausgegeben.';
        PRINT N'@SourceEngineEdition int. Default ist NULL. optionale Engine-Edition-Kennung der Quelle für sourceEnvironment.engineEdition. NULL/Auslassen bleibt null; es ist keine abgeschlossene Wertemenge oder separate Wertebereichsprüfung implementiert.';
        PRINT N'@MaxStatistiken int. Default ist 100. Begrenzung der Zahl aktueller Statistiken. NULL ist unzulässig; gültiger Bereich 1 bis 1000 einschließlich, andernfalls INVALID_PARAMETER. Der Grenzwert wirkt auf die zielgerichtete aktuelle Statistikerhebung.';
        PRINT N'@MaxHistogrammSchritte int. Default ist 20000. Begrenzung der erhobenen Histogrammschritte. NULL ist unzulässig; gültiger Bereich 0 bis 200000 einschließlich, andernfalls INVALID_PARAMETER. Der Grenzwert beschränkt Histogrammvertiefung; 0 erlaubt keine Histogrammschritte.';
        PRINT N'@LockTimeoutMs int. Default ist 0. Wartezeitgrenze in Millisekunden für die optionale Metadatenerhebung. NULL ist unzulässig; gültiger Bereich 0 bis 60000 einschließlich, sonst INVALID_PARAMETER. 0 bedeutet keine Wartezeit auf gesperrte Ressourcen; ein positiver Wert begrenzt das Warten auf die angegebene Zahl Millisekunden.';
        PRINT N'@HighImpactConfirmed bit. Default ist 0. 0 bestätigt keinen High-Impact-Pfad; 1 bestätigt die tatsächlich angeforderte breite Statistik- oder Histogrammerhebung. Der Collector verlangt diese Bestätigung für RELEVANT, OBJECT_ALL oder STEPS nur, wenn er mit @PlanXml, CURRENT_SERVER und einem aktuellen Statistikmodus aufgerufen wird; Berechtigungen werden dadurch nicht erteilt. NULL passiert die äußere NOT-IN-Prüfung, wird bei jeder tatsächlich angeforderten aktuellen Erhebung jedoch vom internen Collector als INVALID_PARAMETER zurückgewiesen; der Capture meldet dann CURRENT_METADATA_COLLECTION_LIMITED und Partialität. Ohne Collector-Aufruf ist daraus keine zusätzliche Gate-Prüfung abzuleiten. NULL ist keine ausdrückliche Bestätigung.';
        PRINT N'@AdditionalEvidenceJson nvarchar(max). Default ist NULL. optionales zusätzliches JSON, das unverändert als importierter Abschnitt nur bei @EvidenzDatenschutzModus=RAW und @SensitiveDataConfirmed=1 in additionalEvidence eingebettet wird; andernfalls ist dieser JSON-Schlüssel null. NULL/Auslassen markiert keine zusätzliche Evidenz. Ungültiges JSON führt bei @StrictValidation=1 zu Fehler 51023; sonst wird es verworfen, gewarnt und IsPartial gesetzt. Ein spezifisches geschlossenes Schlüsselschema wird hier nicht validiert; der Wert muss syntaktisch gültiges JSON sein. Ohne hinreichend strikte Datenschutzfreigabe werden zusätzliche Inhalte nicht in den Ausgabeabschnitt übernommen.';
        PRINT N'@ExistingEvidenceJson nvarchar(max). Default ist NULL. Optionale Ausgangshülle als Execution-Evidence-JSON. Die ausgewerteten Wurzelabschnitte sind statisticsIo, statisticsTime, statistics, objectReferences und predicateHistogramMappings; statistics besitzt planUsage, currentSnapshot, histogramSummaries und histogramSteps. Die erkannten Objektfelder und SQL-Zieltypen stehen nachfolgend. Unbekannte Eigenschaften und bisherige meta-/capture-/Warnungsabschnitte werden nicht unverändert exportiert. Eigene Statistik-/Objektparameter ersetzen gleichnamige Abschnitte. Mit @PlanXml stammen planUsage und objectReferences aus dem Plan; ohne CURRENT_SERVER werden aktuelle Statistik-, Histogramm- und Mappingarrays importiert. Importierte IO-/TIME-Zeilen werden zusätzlich zu geparsten Textzeilen eingefügt, mit RawLine=NULL; Dubletten werden nicht automatisch entfernt. NULL startet eine leere Hülle; leerer Text ist ungültiges JSON. Ungültiges JSON führt bei StrictValidation=1 intern zu 51024 und dem abgefangenen Status INVALID_EVIDENCE_JSON, sonst zu Warnung und partieller Ausgabe.';
        PRINT N'@RawTextHandling varchar(16). Default ist ''HASH_ONLY''. geschlossene Auswahl NONE, HASH_ONLY, INCLUDE. NULL wird wie HASH_ONLY behandelt; Trim und Großschreibung normalisieren Werte, andere Werte ergeben INVALID_PARAMETER. NONE entfernt Rohzeilen und gibt keine Eingabehashes aus; HASH_ONLY entfernt Rohzeilen und gibt Eingabelängen sowie SHA-256-Hashes der IO-/TIME-Texte aus; INCLUDE erhält geparste Rohzeilen im Ergebnis und gibt Eingabehashes aus. INCLUDE erfordert @SensitiveDataConfirmed=1 und @IdentifierDatenschutzModus=RAW; 0 oder NULL als Bestätigung führt zu SENSITIVE_DATA_CONFIRMATION_REQUIRED.';
        PRINT N'@StrictValidation bit. Default ist 1. 1 behandelt ungültiges importiertes JSON oder nicht extrahierbare Teilpayloads als interne Fehler 51021 bis 51024; der CATCH liefert INVALID_EVIDENCE_JSON, Partialität und die Fehler-OUTPUTs. 0 verwirft diese Payloads mit Warnung und partieller Ausgabe. NULL passiert NOT IN (0,1) und folgt bei IF=1 dem nicht strikten Zweig. Typkonvertierungs- und Zieltabellenfehler können auch mit 0 in ERROR_HANDLED enden; TABLE-Vorbereitungsfehler liegen außerhalb dieses CATCH.';
        PRINT N'@ResultSetArt varchar(16). Default ist ''CONSOLE''. geschlossene Auswahl CONSOLE, RAW, TABLE, NONE. NULL und Leertext normalisieren zu leer und führen INVALID_PARAMETER. Werte werden getrimmt und großgeschrieben. CONSOLE ruft InternalEmitConsoleResult mit captureStatus als Quelle auf; RAW gibt die elf benannten Tabellen als elf Resultsets aus; TABLE schreibt angeforderte Resultate in ausdrücklich zugeordnete Ziele; NONE emittiert keine Resultsets. Unbekannte Werte sind INVALID_PARAMETER. CONSOLE ist die getrennte Konsolenausgabe, nicht ein JSON-Resultset.';
        PRINT N'@ResultTablesJson nvarchar(max). Default ist NULL. optionales JSON-Objekt, dessen Schlüssel die Resultatnamen und dessen Zeichenkettenwerte vorhandene lokale Zieltabellen bezeichnen, zum Beispiel {"captureStatus":"#Capture"}. Es darf mindestens eine Zuordnung enthalten; alle Namen müssen aus der geschlossenen Liste captureStatus, statisticsIo, statisticsTime, planStatisticsUsage, objectReferences, currentStatistics, histogramSummaries, histogramSteps, predicateHistogramMappings, collectionStatus und warnings stammen. Jede Zieltabelle muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale Temp-Tabellen, Namen über 116 Zeichen, Ziele mit Präfix #Monitor, doppelte Namen oder Ziele und andere JSON-Werttypen werden abgelehnt. NULL/Auslassen wird im TABLE-Modus als ungültige Zuordnung abgelehnt; außerhalb TABLE führt ein gesetzter Wert zu INVALID_PARAMETER. Helper-Fehler werden als Fehler 51011 ausgelöst.';
        PRINT N'@JsonErzeugen bit. Default ist 1. Schalter zur Erzeugung des kanonischen JSON in @Json. 1 erzeugt das JSON, 0 lässt @Json auf NULL. 0 und 1 steuern die Ausgabe; NULL passiert NOT IN (0,1), erzeugt bei IF=1 aber kein JSON. Das JSON ist ein eigener OUTPUT-Parameter und wird bei @ResultSetArt=CONSOLE nicht als Resultset ausgegeben.';
        PRINT N'@Json nvarchar(max) OUTPUT. Default ist NULL. Optionaler OUTPUT-Empfang als nvarchar(max)-Variable mit OUTPUT; ein übergebener Anfangswert wird auf NULL zurückgesetzt. JsonErzeugen=1 erzeugt das versionierte Execution-Evidence-Objekt, 0 oder NULL lässt den Ausgang NULL. Wurzelkeys sind meta, capture, sourceEnvironment, planIdentity, statisticsIo, statisticsTime, statistics, objectReferences, predicateHistogramMappings, collectionStatus, warnings, rawInput, importedEvidence und additionalEvidence. statistics enthält planUsage, currentSnapshot, histogramSummaries und histogramSteps als Arrays. IO, TIME, Objektbezüge, Mappings, Collection-Status und Warnings sind Arrays; fehlende optionale Skalare bleiben JSON-null. ResultSetArt ist davon unabhängig. Ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen.';
        PRINT N'@PrintMeldungen bit. Default ist 1. 1 gibt bei Status außerhalb AVAILABLE eine Severity-10-Meldung über RAISERROR WITH NOWAIT aus. 0 oder NULL unterdrückt diese Meldung. Die Hilfsausgabe wird dadurch nicht deaktiviert.';
        PRINT N'@Hilfe bit. Default ist 0. 1 druckt die Parameterhilfe und kehrt vor Parameterprüfung, TABLE-Vorbereitung und Erhebung zurück. 0 oder NULL folgt dem normalen Pfad. Zuvor werden @Json auf NULL und die vier Status-OUTPUTs auf AVAILABLE, 0, NULL und NULL gesetzt; auch SET LOCK_TIMEOUT 0 liegt vor dem Hilfe-RETURN.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT. Default ist NULL. als varchar(40)-Variable mit OUTPUT zu binden. Erhält den StatusCode der Ausführung, anfänglich AVAILABLE und bei Validierungs-, Datenschutz-, Quellumgebungs- oder Verarbeitungsfällen entsprechend ersetzt. Der Status ist maschinenlesbar und Teil von captureStatus; der Aufrufende soll den gelieferten Wert auswerten. Der Anfangswert wird beim Einstieg auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen.';
        PRINT N'@IsPartialOut bit OUTPUT. Default ist NULL. als bit-Variable mit OUTPUT zu binden. 0 bedeutet zunächst nicht partiell; ungültige/verworfene optionale Evidenz oder andere begrenzte Verarbeitung kann auf 1 setzen. Der Wert beschreibt die Vollständigkeit der erzeugten Evidenz, nicht den Erfolg eines ausgeführten Workloads. Der Anfangswert wird beim Einstieg auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen.';
        PRINT N'@ErrorNumberOut int OUTPUT. Default ist NULL. als int-Variable mit OUTPUT zu binden. Zu Beginn NULL; bei abgefangenen Fehlern wird die SQL-Fehlernummer ausgegeben. Ohne solchen Fehler bleibt der Wert NULL. Der Anfangswert wird beim Einstieg auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT. Default ist NULL. als nvarchar(2048)-Variable mit OUTPUT zu binden. Zu Beginn NULL; bei Status- oder Verarbeitungsfehlern wird eine begrenzte Meldung ausgegeben. Ohne Fehler bleibt der Wert NULL. Der Anfangswert wird beim Einstieg auch im Hilfepfad zurückgesetzt; ohne OUTPUT-Bindung wird kein Wert beim Aufrufer empfangen.';
        PRINT N'Die folgenden JSON-Pfade beschreiben die erkannten Objektfelder und SQL-Zieltypen, keine strikte JSON-Schema-Validierung. Zahlen werden in die angegebenen SQL-Zahltypen, bit in 0/1, Texte in die angegebenen Zeichenlängen und Zeitstempel in datetime2 konvertiert. sysname entspricht nvarchar(128). Namen und Pfade sind in der angegebenen Schreibweise zu übergeben. Fehlende Eigenschaften werden als NULL projiziert; Konvertierungs- oder NOT-NULL-Zielverletzungen können ERROR_HANDLED auslösen. Nicht erkannte Eigenschaften werden ignoriert. Arrays enthalten jeweils Objekte; importierte Status-/Kategorietexte besitzen hier keine geschlossene validierte Wertemenge.';
        PRINT N'JSON-Eingabe $.statisticsIo: statementOrdinal int, messageOrdinal int, objectOrdinal int, objectDisplayName nvarchar(512), scanCount bigint, logicalReads bigint, physicalReads bigint, pageServerReads bigint, readAheadReads bigint, pageServerReadAheadReads bigint, lobLogicalReads bigint, lobPhysicalReads bigint, lobPageServerReads bigint, lobReadAheadReads bigint, lobPageServerReadAheadReads bigint, languageDetected varchar(16), parseStatus varchar(40).';
        PRINT N'JSON-Eingabe $.statisticsTime: statementOrdinal int, messageOrdinal int, timeCategory varchar(24), cpuMs bigint, elapsedMs bigint, languageDetected varchar(16), parseStatus varchar(40).';
        PRINT N'JSON-Eingabe $.statistics.planUsage: statisticsUsageOrdinal bigint, statementOrdinal int, statementId int, statementCompId int, databaseName sysname, schemaName sysname, objectName sysname, statisticsName sysname, lastUpdateAtCompile datetime2(7), modificationCountAtCompile bigint, samplingPercentAtCompile decimal(19,6), sourceElement nvarchar(128), parseStatus varchar(40).';
        PRINT N'JSON-Eingabe $.objectReferences: referenceOrdinal bigint, statementOrdinal int, statementId int, statementCompId int, nodeId int, referenceType varchar(40), referenceSource varchar(40), databaseName sysname, schemaName sysname, objectName sysname, indexName sysname, aliasName sysname, storageType nvarchar(128), planObjectId int, planIndexId int, isTemporaryObject bit, isTableVariable bit, isRemoteObject bit, isDmlTarget bit, resolutionCapability varchar(40), sourceElement nvarchar(128).';
        PRINT N'JSON-Eingabe $.statistics.currentSnapshot: databaseName sysname, schemaName sysname, objectName sysname, objectId int, statisticsName sysname, statisticsId int, isIndexStatistics bit, isAutoCreated bit, isUserCreated bit, isFiltered bit, filterDefinition nvarchar(max), noRecompute bit, isIncremental bit, hasPersistedSample bit, leadingColumnName sysname, lastUpdated datetime2(7), rows bigint, rowsSampled bigint, samplePercent decimal(19,6), steps int, unfilteredRows bigint, modificationCounter bigint, modificationPercent decimal(19,6), persistedSamplePercent float, collectionStatus varchar(40).';
        PRINT N'JSON-Eingabe $.statistics.histogramSummaries: databaseName sysname, schemaName sysname, objectName sysname, statisticsName sysname, statisticsId int, leadingColumnName sysname, histogramSteps int, histogramEstimatedRows float, maxEqualRows float, maxRangeRows float, maxStepRows float, dominantStepPercent decimal(19,6), tailStepRows float, tailStepPercent decimal(19,6), collectionStatus varchar(40).';
        PRINT N'JSON-Eingabe $.statistics.histogramSteps: databaseName sysname, schemaName sysname, objectName sysname, statisticsName sysname, statisticsId int, leadingColumnName sysname, stepOrdinal int, rangeHighKey nvarchar(4000), rangeRows float, equalRows float, distinctRangeRows bigint, averageRangeRows float, isPredicateTarget bit, predicateMatchCount int.';
        PRINT N'JSON-Eingabe $.predicateHistogramMappings: predicateReferenceId bigint, statementOrdinal int, nodeId int, databaseName sysname, schemaName sysname, objectName sysname, columnName sysname, statisticsName sysname, predicateKind varchar(40), valueSource varchar(32), mappingStatus varchar(48), mappingConfidence varchar(16), matchedStepOrdinal int, matchesRangeHighKey bit, isBelowHistogram bit, isAboveHistogram bit, sensitiveValueStatus varchar(40).';
        PRINT N'Beispiel 1. EXEC [monitor].[USP_CreateExecutionEvidenceJson] @Hilfe=1;';
        PRINT N'Beispiel 2. DECLARE @EvidenceJson nvarchar(max); EXEC [monitor].[USP_CreateExecutionEvidenceJson] @StatisticsIoText=N''Table ''''[demo].[Orders]''''. Scan count 1, logical reads 2, physical reads 0, read-ahead reads 0, lob logical reads 0.'', @StatisticsLanguage=''AUTO'', @ResultSetArt=''NONE'', @Json=@EvidenceJson OUTPUT;';
        PRINT N'Beispiel 3. DECLARE @EvidenceJson nvarchar(max); EXEC [monitor].[USP_CreateExecutionEvidenceJson] @ExistingEvidenceJson=N''{"statisticsIo":[],"statisticsTime":[]}'', @JsonErzeugen=1, @ResultSetArt=''NONE'', @Json=@EvidenceJson OUTPUT;';
        PRINT N'Beispiel 4. CREATE TABLE #CreateExecutionEvidenceJson_HelpExample (Seed bit NULL); EXEC [monitor].[USP_CreateExecutionEvidenceJson] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"captureStatus":"#CreateExecutionEvidenceJson_HelpExample"}'', @JsonErzeugen=0; DROP TABLE #CreateExecutionEvidenceJson_HelpExample;';
        RETURN;
    END;

    CREATE TABLE [#CreateExecutionEvidenceJson_TableMap]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_CaptureStatus]
    (
          [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [GeneratedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [SchemaVersion] int NOT NULL
        , [StatisticsIoRowCount] bigint NOT NULL
        , [StatisticsTimeRowCount] bigint NOT NULL
        , [PlanStatisticsUsageCount] bigint NOT NULL
        , [CurrentStatisticsCount] bigint NOT NULL
        , [HistogramStepCount] bigint NOT NULL
        , [PredicateMappingCount] bigint NOT NULL
        , [EvidencePrivacyMode] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IdentifierPrivacyMode] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SameExecutionConfidence] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_StatisticsIo]
    (
          [StatementOrdinal] int NULL,[MessageOrdinal] int NOT NULL,[ObjectOrdinal] int NOT NULL
        , [ObjectDisplayName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ScanCount] bigint NULL,[LogicalReads] bigint NULL
        , [PhysicalReads] bigint NULL,[PageServerReads] bigint NULL,[ReadAheadReads] bigint NULL
        , [PageServerReadAheadReads] bigint NULL,[LobLogicalReads] bigint NULL,[LobPhysicalReads] bigint NULL
        , [LobPageServerReads] bigint NULL,[LobReadAheadReads] bigint NULL,[LobPageServerReadAheadReads] bigint NULL
        , [LanguageDetected] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RawLine] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_StatisticsTime]
    (
          [StatementOrdinal] int NULL,[MessageOrdinal] int NOT NULL,[TimeCategory] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CpuMs] bigint NULL,[ElapsedMs] bigint NULL,[LanguageDetected] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RawLine] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_PlanStatisticsUsage]
    (
          [StatisticsUsageOrdinal] bigint NOT NULL,[StatementOrdinal] int NOT NULL
        , [StatementId] int NULL,[StatementCompId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatisticsName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LastUpdateAtCompile] datetime2(7) NULL,[ModificationCountAtCompile] bigint NULL
        , [SamplingPercentAtCompile] decimal(19,6) NULL,[SourceElement] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_ObjectReferences]
    (
          [ReferenceOrdinal] bigint NOT NULL,[StatementOrdinal] int NOT NULL,[StatementId] int NULL,[StatementCompId] int NULL
        , [NodeId] int NULL,[ReferenceType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ReferenceSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AliasName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StorageType] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanObjectId] int NULL,[PlanIndexId] int NULL
        , [IsTemporaryObject] bit NOT NULL,[IsTableVariable] bit NOT NULL,[IsRemoteObject] bit NOT NULL,[IsDmlTarget] bit NOT NULL
        , [ResolutionCapability] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceElement] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_StatisticsCurrent]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectId] int NOT NULL
        , [StatisticsName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatisticsId] int NOT NULL,[IsIndexStatistics] bit NOT NULL
        , [IsAutoCreated] bit NULL,[IsUserCreated] bit NULL,[IsFiltered] bit NULL,[FilterDefinition] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [NoRecompute] bit NULL,[IsIncremental] bit NULL,[HasPersistedSample] bit NULL,[LeadingColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LastUpdated] datetime2(7) NULL,[Rows] bigint NULL,[RowsSampled] bigint NULL,[SamplePercent] decimal(19,6) NULL
        , [Steps] int NULL,[UnfilteredRows] bigint NULL,[ModificationCounter] bigint NULL,[ModificationPercent] decimal(19,6) NULL
        , [PersistedSamplePercent] float NULL,[CollectionStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_HistogramSteps]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatisticsName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatisticsId] int NOT NULL,[LeadingColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StepOrdinal] int NOT NULL,[RangeHighKeyRaw] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RangeRows] float NULL,[EqualRows] float NULL,[DistinctRangeRows] bigint NULL,[AverageRangeRows] float NULL
        , [IsPredicateTarget] bit NULL,[PredicateMatchCount] int NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_HistogramSummary]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatisticsName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatisticsId] int NOT NULL,[LeadingColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HistogramSteps] int NOT NULL,[HistogramEstimatedRows] float NULL,[MaxEqualRows] float NULL
        , [MaxRangeRows] float NULL,[MaxStepRows] float NULL,[DominantStepPercent] decimal(19,6) NULL
        , [TailStepRows] float NULL,[TailStepPercent] decimal(19,6) NULL,[CollectionStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_PredicateHistogramMappings]
    (
          [PredicateReferenceId] bigint NOT NULL,[StatementOrdinal] int NOT NULL,[NodeId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatisticsName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PredicateKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ValueSource] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MappingStatus] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[MappingConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[MatchedStepOrdinal] int NULL
        , [MatchesRangeHighKey] bit NOT NULL,[IsBelowHistogram] bit NOT NULL,[IsAboveHistogram] bit NOT NULL
        , [SensitiveValueStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_CollectionStatus]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatisticsName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_Warnings]
    (
          [WarningCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Detail] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    IF @OutputMode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR @StatisticsMode NOT IN ('NONE','PLAN_ONLY','USED','RELEVANT','OBJECT_ALL')
       OR @HistogramMode NOT IN ('NONE','SUMMARY','STEPS')
       OR @MetadataSourceMode NOT IN ('EVIDENCE_ONLY','CURRENT_SERVER')
       OR @PrivacyMode NOT IN ('DERIVED_ONLY','TOKENIZED','RAW','STRUCTURE_ONLY')
       OR @IdentifierMode NOT IN ('RAW','TOKENIZED','OMIT')
       OR @RawMode NOT IN ('NONE','HASH_ONLY','INCLUDE')
       OR @StrictValidation NOT IN (0,1) OR @JsonErzeugen NOT IN (0,1)
       OR @MitPredicateHistogramMap NOT IN (0,1)
       OR @MaxStatistiken IS NULL OR @MaxStatistiken NOT BETWEEN 1 AND 1000
       OR @MaxHistogrammSchritte IS NULL OR @MaxHistogrammSchritte NOT BETWEEN 0 AND 200000
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @HighImpactConfirmed NOT IN (0,1)
       OR @SourceCompatibilityLevel IS NOT NULL AND @SourceCompatibilityLevel NOT BETWEEN 80 AND 200
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Ungültiger Modus-, Grenzwert-, Ausgabe-, Datenschutz- oder Versionsparameter.';
    END;

    IF @StatusCodeOut='AVAILABLE' AND @PrivacyMode='RAW'
       AND (@SensitiveDataConfirmed IS NULL OR @SensitiveDataConfirmed<>1)
    BEGIN
        SELECT @StatusCodeOut='SENSITIVE_DATA_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'RAW-Evidenz kann Parameter-, Predicate-, Filter- oder Histogrammwerte enthalten und benötigt @SensitiveDataConfirmed=1.';
    END;

    IF @StatusCodeOut='AVAILABLE'
       AND @RawMode='INCLUDE'
       AND (@SensitiveDataConfirmed IS NULL OR @SensitiveDataConfirmed<>1 OR @IdentifierMode<>'RAW')
    BEGIN
        SELECT @StatusCodeOut='SENSITIVE_DATA_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'Rohtext kann sensible Werte und nicht zuverlässig einzeln anonymisierbare Identifikatoren enthalten. INCLUDE benötigt @SensitiveDataConfirmed=1 und @IdentifierDatenschutzModus=RAW.';
    END;

    IF @StatusCodeOut='AVAILABLE'
       AND @MetadataSourceMode='CURRENT_SERVER'
       AND (@QuellumgebungBestaetigt IS NULL OR @QuellumgebungBestaetigt<>1)
    BEGIN
        SELECT @StatusCodeOut='SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'CURRENT_SERVER-Anreicherung benötigt @QuellumgebungBestaetigt=1.';
    END;

    IF @StatusCodeOut='AVAILABLE'
       AND @HistogramMode<>'NONE'
       AND (@MetadataSourceMode<>'CURRENT_SERVER' OR @StatisticsMode IN ('NONE','PLAN_ONLY'))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Histogramme benötigen CURRENT_SERVER und Statistikmodus USED, RELEVANT oder OBJECT_ALL.';
    END;

    IF @StatusCodeOut='AVAILABLE' AND @TableRequested=1
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'captureStatus|statisticsIo|statisticsTime|planStatisticsUsage|objectReferences|currentStatistics|histogramSummaries|histogramSteps|predicateHistogramMappings|collectionStatus|warnings'
            , @MappingTable=N'#CreateExecutionEvidenceJson_TableMap'
            , @ThrowOnError=1;
        SET @OutputMode='NONE';
    END
    ELSE IF @StatusCodeOut='AVAILABLE' AND @ResultTablesJson IS NOT NULL
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.';
    END;
    IF @ConsoleResultRequested=1 SET @OutputMode='NONE';

    IF @StatusCodeOut='AVAILABLE'
    BEGIN TRY
        INSERT [#CreateExecutionEvidenceJson_StatisticsIo]
        SELECT * FROM [monitor].[TVF_ParseStatisticsIoText](@StatisticsIoText,@StatisticsLanguage);

        INSERT [#CreateExecutionEvidenceJson_StatisticsTime]
        SELECT * FROM [monitor].[TVF_ParseStatisticsTimeText](@StatisticsTimeText,@StatisticsLanguage);

        DECLARE @PlanStatementCount int=0;
        IF @PlanXml IS NOT NULL
        BEGIN
            SELECT @PlanStatementCount=COUNT(*)
            FROM @PlanXml.nodes('//*[local-name(.)="StmtSimple"]') AS [s]([n]);

            IF @StatementOrdinal IS NOT NULL
            BEGIN
                UPDATE [#CreateExecutionEvidenceJson_StatisticsIo] SET [StatementOrdinal]=@StatementOrdinal WHERE [StatementOrdinal] IS NULL;
                UPDATE [#CreateExecutionEvidenceJson_StatisticsTime] SET [StatementOrdinal]=@StatementOrdinal WHERE [StatementOrdinal] IS NULL;
            END
            ELSE IF @PlanStatementCount=1
            BEGIN
                UPDATE [#CreateExecutionEvidenceJson_StatisticsIo] SET [StatementOrdinal]=1 WHERE [StatementOrdinal] IS NULL;
                UPDATE [#CreateExecutionEvidenceJson_StatisticsTime] SET [StatementOrdinal]=1 WHERE [StatementOrdinal] IS NULL;
            END
            ELSE IF @PlanStatementCount>1 AND (EXISTS(SELECT 1 FROM [#CreateExecutionEvidenceJson_StatisticsIo]) OR EXISTS(SELECT 1 FROM [#CreateExecutionEvidenceJson_StatisticsTime]))
            BEGIN
                INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('AMBIGUOUS_STATEMENT_MAPPING','MEDIUM',N'STATISTICS IO/TIME wurde für einen Mehrstatementplan ohne explizite @StatementOrdinal übergeben. Die Werte bleiben planbezogen.');
                SET @IsPartialOut=1;
            END;

            IF @StatisticsMode<>'NONE'
            BEGIN
                INSERT [#CreateExecutionEvidenceJson_PlanStatisticsUsage]
                SELECT * FROM [monitor].[TVF_ExecutionPlanStatisticsUsage](@PlanXml,@StatementId);
            END;

            INSERT [#CreateExecutionEvidenceJson_ObjectReferences]
            SELECT * FROM [monitor].[TVF_ExecutionPlanObjectReferences](@PlanXml,@StatementId);
        END;

        IF @StatisticsEvidenceJson IS NOT NULL AND ISJSON(@StatisticsEvidenceJson)<>1
        BEGIN
            IF @StrictValidation=1 THROW 51021,N'@StatisticsEvidenceJson ist kein gültiges JSON.',1;
            INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('INVALID_STATISTICS_EVIDENCE_JSON','MEDIUM',N'Externes Statistik-Evidenz-JSON wurde verworfen.');
            SET @IsPartialOut=1;
        END;
        IF @ObjectMetadataJson IS NOT NULL AND ISJSON(@ObjectMetadataJson)<>1
        BEGIN
            IF @StrictValidation=1 THROW 51022,N'@ObjectMetadataJson ist kein gültiges JSON.',1;
            INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('INVALID_OBJECT_METADATA_JSON','MEDIUM',N'Externes Objektmetadaten-JSON wurde verworfen.');
            SET @IsPartialOut=1;
        END;
        IF @AdditionalEvidenceJson IS NOT NULL AND ISJSON(@AdditionalEvidenceJson)<>1
        BEGIN
            IF @StrictValidation=1 THROW 51023,N'@AdditionalEvidenceJson ist kein gültiges JSON.',1;
            INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('INVALID_ADDITIONAL_EVIDENCE_JSON','MEDIUM',N'Zusätzliche Evidenz wurde verworfen.');
            SET @IsPartialOut=1;
        END;
        IF @ExistingEvidenceJson IS NOT NULL AND ISJSON(@ExistingEvidenceJson)<>1
        BEGIN
            IF @StrictValidation=1 THROW 51024,N'@ExistingEvidenceJson ist kein gültiges JSON.',1;
            INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('INVALID_EXISTING_EVIDENCE_JSON','MEDIUM',N'Bestehende Evidenz wurde verworfen.');
            SET @IsPartialOut=1;
        END;

        /* Separate Statistik- und Objektpayloads werden in eine kanonische
           Evidence-Hülle überführt. Explizit übergebene Teilpayloads haben
           Vorrang vor gleichnamigen Abschnitten aus @ExistingEvidenceJson. */
        DECLARE @CanonicalEvidenceJson nvarchar(max)=
            CASE WHEN @ExistingEvidenceJson IS NOT NULL AND ISJSON(@ExistingEvidenceJson)=1
                 THEN @ExistingEvidenceJson ELSE N'{}' END;

        IF @StatisticsEvidenceJson IS NOT NULL AND ISJSON(@StatisticsEvidenceJson)=1
        BEGIN
            DECLARE @StatisticsSection nvarchar(max)=JSON_QUERY(@StatisticsEvidenceJson,N'$.statistics');
            IF @StatisticsSection IS NULL AND LEFT(LTRIM(@StatisticsEvidenceJson),1)=N'{'
                SET @StatisticsSection=JSON_QUERY(@StatisticsEvidenceJson);
            IF @StatisticsSection IS NULL
            BEGIN
                IF @StrictValidation=1 THROW 51021,N'@StatisticsEvidenceJson muss ein JSON-Objekt mit Statistikabschnitten enthalten.',1;
                INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('INVALID_STATISTICS_EVIDENCE_SHAPE','MEDIUM',N'Externes Statistik-Evidenz-JSON besitzt keine unterstützte Objektstruktur.');
                SET @IsPartialOut=1;
            END
            ELSE
                SET @CanonicalEvidenceJson=JSON_MODIFY(@CanonicalEvidenceJson,N'$.statistics',JSON_QUERY(@StatisticsSection));
        END;

        IF @ObjectMetadataJson IS NOT NULL AND ISJSON(@ObjectMetadataJson)=1
        BEGIN
            DECLARE @ObjectSection nvarchar(max)=JSON_QUERY(@ObjectMetadataJson,N'$.objectReferences');
            IF @ObjectSection IS NULL AND LEFT(LTRIM(@ObjectMetadataJson),1)=N'['
                SET @ObjectSection=JSON_QUERY(@ObjectMetadataJson);
            IF @ObjectSection IS NULL
            BEGIN
                IF @StrictValidation=1 THROW 51022,N'@ObjectMetadataJson muss ein JSON-Array oder objectReferences enthalten.',1;
                INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('INVALID_OBJECT_METADATA_SHAPE','MEDIUM',N'Externes Objektmetadaten-JSON besitzt keine unterstützte Arraystruktur.');
                SET @IsPartialOut=1;
            END
            ELSE
                SET @CanonicalEvidenceJson=JSON_MODIFY(@CanonicalEvidenceJson,N'$.objectReferences',JSON_QUERY(@ObjectSection));
        END;

        /* Bestehende kanonische Evidenz wird strukturell zusammengeführt. Plan-
           referenzen werden bei vorhandenem @PlanXml neu und damit eindeutiger
           aufgebaut; bereits erfasste IO-/TIME-Werte bleiben erhalten. */
        IF ISJSON(@CanonicalEvidenceJson)=1
        BEGIN
            INSERT [#CreateExecutionEvidenceJson_StatisticsIo]
            SELECT [StatementOrdinal],[MessageOrdinal],[ObjectOrdinal],[ObjectDisplayName],
                   [ScanCount],[LogicalReads],[PhysicalReads],[PageServerReads],[ReadAheadReads],
                   [PageServerReadAheadReads],[LobLogicalReads],[LobPhysicalReads],[LobPageServerReads],
                   [LobReadAheadReads],[LobPageServerReadAheadReads],[LanguageDetected],[ParseStatus],NULL
            FROM OPENJSON(@CanonicalEvidenceJson,N'$.statisticsIo')
            WITH
            (
                  [StatementOrdinal] int N'$.statementOrdinal',[MessageOrdinal] int N'$.messageOrdinal'
                , [ObjectOrdinal] int N'$.objectOrdinal',[ObjectDisplayName] nvarchar(512) N'$.objectDisplayName'
                , [ScanCount] bigint N'$.scanCount',[LogicalReads] bigint N'$.logicalReads'
                , [PhysicalReads] bigint N'$.physicalReads',[PageServerReads] bigint N'$.pageServerReads'
                , [ReadAheadReads] bigint N'$.readAheadReads',[PageServerReadAheadReads] bigint N'$.pageServerReadAheadReads'
                , [LobLogicalReads] bigint N'$.lobLogicalReads',[LobPhysicalReads] bigint N'$.lobPhysicalReads'
                , [LobPageServerReads] bigint N'$.lobPageServerReads',[LobReadAheadReads] bigint N'$.lobReadAheadReads'
                , [LobPageServerReadAheadReads] bigint N'$.lobPageServerReadAheadReads'
                , [LanguageDetected] varchar(16) N'$.languageDetected',[ParseStatus] varchar(40) N'$.parseStatus'
            );

            INSERT [#CreateExecutionEvidenceJson_StatisticsTime]
            SELECT [StatementOrdinal],[MessageOrdinal],[TimeCategory],[CpuMs],[ElapsedMs],[LanguageDetected],[ParseStatus],NULL
            FROM OPENJSON(@CanonicalEvidenceJson,N'$.statisticsTime')
            WITH
            (
                  [StatementOrdinal] int N'$.statementOrdinal',[MessageOrdinal] int N'$.messageOrdinal'
                , [TimeCategory] varchar(24) N'$.timeCategory',[CpuMs] bigint N'$.cpuMs'
                , [ElapsedMs] bigint N'$.elapsedMs',[LanguageDetected] varchar(16) N'$.languageDetected'
                , [ParseStatus] varchar(40) N'$.parseStatus'
            );

            IF @PlanXml IS NULL
            BEGIN
                INSERT [#CreateExecutionEvidenceJson_PlanStatisticsUsage]
                SELECT [StatisticsUsageOrdinal],[StatementOrdinal],[StatementId],[StatementCompId],
                       [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[LastUpdateAtCompile],
                       [ModificationCountAtCompile],[SamplingPercentAtCompile],[SourceElement],[ParseStatus]
                FROM OPENJSON(@CanonicalEvidenceJson,N'$.statistics.planUsage')
                WITH
                (
                      [StatisticsUsageOrdinal] bigint N'$.statisticsUsageOrdinal',[StatementOrdinal] int N'$.statementOrdinal'
                    , [StatementId] int N'$.statementId',[StatementCompId] int N'$.statementCompId'
                    , [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
                    , [ObjectName] sysname N'$.objectName',[StatisticsName] sysname N'$.statisticsName'
                    , [LastUpdateAtCompile] datetime2(7) N'$.lastUpdateAtCompile'
                    , [ModificationCountAtCompile] bigint N'$.modificationCountAtCompile'
                    , [SamplingPercentAtCompile] decimal(19,6) N'$.samplingPercentAtCompile'
                    , [SourceElement] nvarchar(128) N'$.sourceElement',[ParseStatus] varchar(40) N'$.parseStatus'
                );
          

                INSERT [#CreateExecutionEvidenceJson_ObjectReferences]
                SELECT [ReferenceOrdinal],[StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
                       [ReferenceType],[ReferenceSource],[DatabaseName],[SchemaName],[ObjectName],[IndexName],
                       [AliasName],[StorageType],[PlanObjectId],[PlanIndexId],[IsTemporaryObject],
                       [IsTableVariable],[IsRemoteObject],[IsDmlTarget],[ResolutionCapability],[SourceElement]
                FROM OPENJSON(@CanonicalEvidenceJson,N'$.objectReferences')
                WITH
                (
                      [ReferenceOrdinal] bigint N'$.referenceOrdinal',[StatementOrdinal] int N'$.statementOrdinal'
                    , [StatementId] int N'$.statementId',[StatementCompId] int N'$.statementCompId',[NodeId] int N'$.nodeId'
                    , [ReferenceType] varchar(40) N'$.referenceType',[ReferenceSource] varchar(40) N'$.referenceSource'
                    , [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
                    , [ObjectName] sysname N'$.objectName',[IndexName] sysname N'$.indexName'
                    , [AliasName] sysname N'$.aliasName',[StorageType] nvarchar(128) N'$.storageType'
                    , [PlanObjectId] int N'$.planObjectId',[PlanIndexId] int N'$.planIndexId'
                    , [IsTemporaryObject] bit N'$.isTemporaryObject',[IsTableVariable] bit N'$.isTableVariable'
                    , [IsRemoteObject] bit N'$.isRemoteObject',[IsDmlTarget] bit N'$.isDmlTarget'
                    , [ResolutionCapability] varchar(40) N'$.resolutionCapability',[SourceElement] nvarchar(128) N'$.sourceElement'
                );
            END;

            IF @MetadataSourceMode<>'CURRENT_SERVER'
            BEGIN
                INSERT [#CreateExecutionEvidenceJson_StatisticsCurrent]
                SELECT *
                FROM OPENJSON(@CanonicalEvidenceJson,N'$.statistics.currentSnapshot')
                WITH
                (
                      [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
                    , [ObjectName] sysname N'$.objectName',[ObjectId] int N'$.objectId'
                    , [StatisticsName] sysname N'$.statisticsName',[StatisticsId] int N'$.statisticsId'
                    , [IsIndexStatistics] bit N'$.isIndexStatistics',[IsAutoCreated] bit N'$.isAutoCreated'
                    , [IsUserCreated] bit N'$.isUserCreated',[IsFiltered] bit N'$.isFiltered'
                    , [FilterDefinition] nvarchar(max) N'$.filterDefinition',[NoRecompute] bit N'$.noRecompute'
                    , [IsIncremental] bit N'$.isIncremental',[HasPersistedSample] bit N'$.hasPersistedSample'
                    , [LeadingColumnName] sysname N'$.leadingColumnName',[LastUpdated] datetime2(7) N'$.lastUpdated'
                    , [Rows] bigint N'$.rows',[RowsSampled] bigint N'$.rowsSampled'
                    , [SamplePercent] decimal(19,6) N'$.samplePercent',[Steps] int N'$.steps'
                    , [UnfilteredRows] bigint N'$.unfilteredRows',[ModificationCounter] bigint N'$.modificationCounter'
                    , [ModificationPercent] decimal(19,6) N'$.modificationPercent'
                    , [PersistedSamplePercent] float N'$.persistedSamplePercent',[CollectionStatus] varchar(40) N'$.collectionStatus'
                );

                INSERT [#CreateExecutionEvidenceJson_HistogramSummary]
                SELECT *
                FROM OPENJSON(@CanonicalEvidenceJson,N'$.statistics.histogramSummaries')
                WITH
                (
                      [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
                    , [ObjectName] sysname N'$.objectName',[StatisticsName] sysname N'$.statisticsName'
                    , [StatisticsId] int N'$.statisticsId',[LeadingColumnName] sysname N'$.leadingColumnName'
                    , [HistogramSteps] int N'$.histogramSteps',[HistogramEstimatedRows] float N'$.histogramEstimatedRows'
                    , [MaxEqualRows] float N'$.maxEqualRows',[MaxRangeRows] float N'$.maxRangeRows'
                    , [MaxStepRows] float N'$.maxStepRows',[DominantStepPercent] decimal(19,6) N'$.dominantStepPercent'
                    , [TailStepRows] float N'$.tailStepRows',[TailStepPercent] decimal(19,6) N'$.tailStepPercent'
                    , [CollectionStatus] varchar(40) N'$.collectionStatus'
                );

                INSERT [#CreateExecutionEvidenceJson_HistogramSteps]
                SELECT [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StatisticsId],[LeadingColumnName],
                       [StepOrdinal],CASE WHEN @PrivacyMode IN ('RAW','TOKENIZED') THEN [RangeHighKey] END,[RangeRows],[EqualRows],
                       [DistinctRangeRows],[AverageRangeRows],[IsPredicateTarget],[PredicateMatchCount]
                FROM OPENJSON(@CanonicalEvidenceJson,N'$.statistics.histogramSteps')
                WITH
                (
                      [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
                    , [ObjectName] sysname N'$.objectName',[StatisticsName] sysname N'$.statisticsName'
                    , [StatisticsId] int N'$.statisticsId',[LeadingColumnName] sysname N'$.leadingColumnName'
                    , [StepOrdinal] int N'$.stepOrdinal',[RangeHighKey] nvarchar(4000) N'$.rangeHighKey'
                    , [RangeRows] float N'$.rangeRows',[EqualRows] float N'$.equalRows'
                    , [DistinctRangeRows] bigint N'$.distinctRangeRows',[AverageRangeRows] float N'$.averageRangeRows'
                    , [IsPredicateTarget] bit N'$.isPredicateTarget',[PredicateMatchCount] int N'$.predicateMatchCount'
                );

                INSERT [#CreateExecutionEvidenceJson_PredicateHistogramMappings]
                SELECT [PredicateReferenceId],[StatementOrdinal],[NodeId],[DatabaseName],[SchemaName],[ObjectName],
                       [ColumnName],[StatisticsName],[PredicateKind],[ValueSource],[MappingStatus],[MappingConfidence],
                       [MatchedStepOrdinal],COALESCE([MatchesRangeHighKey],0),COALESCE([IsBelowHistogram],0),
                       COALESCE([IsAboveHistogram],0),COALESCE([SensitiveValueStatus],'IMPORTED_DERIVED')
                FROM OPENJSON(@CanonicalEvidenceJson,N'$.predicateHistogramMappings')
                WITH
                (
                      [PredicateReferenceId] bigint N'$.predicateReferenceId',[StatementOrdinal] int N'$.statementOrdinal'
                    , [NodeId] int N'$.nodeId',[DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
                    , [ObjectName] sysname N'$.objectName',[ColumnName] sysname N'$.columnName'
                    , [StatisticsName] sysname N'$.statisticsName',[PredicateKind] varchar(40) N'$.predicateKind'
                    , [ValueSource] varchar(32) N'$.valueSource',[MappingStatus] varchar(48) N'$.mappingStatus'
                    , [MappingConfidence] varchar(16) N'$.mappingConfidence',[MatchedStepOrdinal] int N'$.matchedStepOrdinal'
                    , [MatchesRangeHighKey] bit N'$.matchesRangeHighKey',[IsBelowHistogram] bit N'$.isBelowHistogram'
                    , [IsAboveHistogram] bit N'$.isAboveHistogram',[SensitiveValueStatus] varchar(40) N'$.sensitiveValueStatus'
                );
            END;
        END;

        IF @PlanXml IS NOT NULL
           AND @MetadataSourceMode='CURRENT_SERVER'
           AND @StatisticsMode IN ('USED','RELEVANT','OBJECT_ALL')
        BEGIN
            DECLARE @CollectionStatus varchar(40),@CollectionPartial bit,@CollectionError int,@CollectionMessage nvarchar(2048);
            EXEC [monitor].[InternalCollectExecutionPlanMetadata]
                  @PlanXml=@PlanXml
                , @StatistikEvidenzModus=@StatisticsMode
                , @HistogrammModus=@HistogramMode
                , @QuellumgebungBestaetigt=@QuellumgebungBestaetigt
                , @MitPredicateHistogramMap=@MitPredicateHistogramMap
                , @MaxStatistiken=@MaxStatistiken
                , @MaxHistogrammSchritte=@MaxHistogrammSchritte
                , @LockTimeoutMs=@LockTimeoutMs
                , @HighImpactConfirmed=@HighImpactConfirmed
                , @StatusCodeOut=@CollectionStatus OUTPUT
                , @IsPartialOut=@CollectionPartial OUTPUT
                , @ErrorNumberOut=@CollectionError OUTPUT
                , @ErrorMessageOut=@CollectionMessage OUTPUT;

            IF @CollectionStatus<>'AVAILABLE'
            BEGIN
                SET @IsPartialOut=1;
                INSERT [#CreateExecutionEvidenceJson_Warnings]
                VALUES('CURRENT_METADATA_COLLECTION_LIMITED','MEDIUM',CONCAT(N'Status=',COALESCE(@CollectionStatus,N'<NULL>'),N'; ',COALESCE(@CollectionMessage,N'')));
            END;
        END;

        UPDATE [h]
        SET [h].[IsPredicateTarget]=CONVERT(bit,CASE WHEN [m].[PredicateMatchCount]>0 THEN 1 ELSE 0 END),
            [h].[PredicateMatchCount]=COALESCE([m].[PredicateMatchCount],0)
        FROM [#CreateExecutionEvidenceJson_HistogramSteps] AS [h]
        OUTER APPLY
        (
            SELECT COUNT(*) [PredicateMatchCount]
            FROM [#CreateExecutionEvidenceJson_PredicateHistogramMappings] AS [p]
            WHERE [p].[DatabaseName]=[h].[DatabaseName]
              AND [p].[SchemaName]=[h].[SchemaName]
              AND [p].[ObjectName]=[h].[ObjectName]
              AND [p].[StatisticsName]=[h].[StatisticsName]
              AND [p].[MatchedStepOrdinal]=[h].[StepOrdinal]
        ) AS [m];

        IF @RawMode<>'INCLUDE'
        BEGIN
            UPDATE [#CreateExecutionEvidenceJson_StatisticsIo] SET [RawLine]=NULL;
            UPDATE [#CreateExecutionEvidenceJson_StatisticsTime] SET [RawLine]=NULL;
        END;

        IF EXISTS(SELECT 1 FROM [#CreateExecutionEvidenceJson_StatisticsIo] WHERE [ParseStatus]<>'PARSED')
           OR EXISTS(SELECT 1 FROM [#CreateExecutionEvidenceJson_StatisticsTime] WHERE [ParseStatus]<>'PARSED')
        BEGIN
            INSERT [#CreateExecutionEvidenceJson_Warnings] VALUES('MESSAGE_PARSE_PARTIAL','LOW',N'Mindestens eine STATISTICS IO/TIME-Zeile konnte nur teilweise geparst werden.');
            SET @IsPartialOut=1;
        END;
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() BETWEEN 51021 AND 51024 THEN 'INVALID_EVIDENCE_JSON' ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;

    IF @IsPartialOut=1 AND @StatusCodeOut='AVAILABLE' SET @StatusCodeOut='PARTIAL';

    /* Datenschutzgerechte Ausgabeprojektionen. Rohwerte bleiben nur bis hier lokal. */
    SELECT
          [StatementOrdinal],[MessageOrdinal],[ObjectOrdinal]
        , [ObjectDisplayName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectDisplayName]
             WHEN 'TOKENIZED' THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([ObjectDisplayName],N''))),1)
             ELSE NULL END
        , [ScanCount],[LogicalReads],[PhysicalReads],[PageServerReads],[ReadAheadReads],[PageServerReadAheadReads]
        , [LobLogicalReads],[LobPhysicalReads],[LobPageServerReads],[LobReadAheadReads],[LobPageServerReadAheadReads]
        , [LanguageDetected],[ParseStatus],[RawLine]
    INTO [#CreateExecutionEvidenceJson_StatisticsIoOutput]
    FROM [#CreateExecutionEvidenceJson_StatisticsIo];

    SELECT * INTO [#CreateExecutionEvidenceJson_StatisticsTimeOutput] FROM [#CreateExecutionEvidenceJson_StatisticsTime];

    SELECT
          [StatisticsUsageOrdinal],[StatementOrdinal],[StatementId],[StatementCompId]
        , [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([DatabaseName],N''))),1)) ELSE NULL END
        , [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([SchemaName],N''))),1)) ELSE NULL END
        , [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([ObjectName],N''))),1)) ELSE NULL END
        , [StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([StatisticsName],N''))),1)) ELSE NULL END
        , [LastUpdateAtCompile],[ModificationCountAtCompile],[SamplingPercentAtCompile],[SourceElement],[ParseStatus]
    INTO [#CreateExecutionEvidenceJson_PlanStatisticsUsageOutput]
    FROM [#CreateExecutionEvidenceJson_PlanStatisticsUsage];

    SELECT
          [ReferenceOrdinal],[StatementOrdinal],[StatementId],[StatementCompId],[NodeId],[ReferenceType],[ReferenceSource]
        , [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([DatabaseName],N''))),1)) ELSE NULL END
        , [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([SchemaName],N''))),1)) ELSE NULL END
        , [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([ObjectName],N''))),1)) ELSE NULL END
        , [IndexName]=CASE @IdentifierMode WHEN 'RAW' THEN [IndexName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([IndexName],N''))),1)) ELSE NULL END
        , [AliasName]=CASE @IdentifierMode WHEN 'RAW' THEN [AliasName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([AliasName],N''))),1)) ELSE NULL END
        , [StorageType],[PlanObjectId],[PlanIndexId],[IsTemporaryObject],[IsTableVariable],[IsRemoteObject],[IsDmlTarget]
        , [ResolutionCapability],[SourceElement]
    INTO [#CreateExecutionEvidenceJson_ObjectReferencesOutput]
    FROM [#CreateExecutionEvidenceJson_ObjectReferences];

    SELECT
          [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1)) ELSE NULL END
        , [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1)) ELSE NULL END
        , [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1)) ELSE NULL END
        , [ObjectId],[StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[StatisticsName])),1)) ELSE NULL END
        , [StatisticsId],[IsIndexStatistics],[IsAutoCreated],[IsUserCreated],[IsFiltered]
        , [FilterDefinition]=CASE WHEN @PrivacyMode='RAW' THEN [FilterDefinition] END
        , [FilterDefinitionStatus]=CONVERT(varchar(40),CASE WHEN [IsFiltered]=0 THEN 'NOT_FILTERED' WHEN @PrivacyMode='RAW' THEN 'AVAILABLE_RAW' ELSE 'OMITTED_SENSITIVE' END)
        , [NoRecompute],[IsIncremental],[HasPersistedSample]
        , [LeadingColumnName]=CASE @IdentifierMode WHEN 'RAW' THEN [LeadingColumnName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([LeadingColumnName],N''))),1)) ELSE NULL END
        , [LastUpdated],[Rows],[RowsSampled],[SamplePercent],[Steps],[UnfilteredRows]
        , [ModificationCounter],[ModificationPercent],[PersistedSamplePercent],[CollectionStatus]
    INTO [#CreateExecutionEvidenceJson_StatisticsCurrentOutput]
    FROM [#CreateExecutionEvidenceJson_StatisticsCurrent];

    SELECT
          [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1)) ELSE NULL END
        , [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1)) ELSE NULL END
        , [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1)) ELSE NULL END
        , [StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[StatisticsName])),1)) ELSE NULL END
        , [StatisticsId]
        , [LeadingColumnName]=CASE @IdentifierMode WHEN 'RAW' THEN [LeadingColumnName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([LeadingColumnName],N''))),1)) ELSE NULL END
        , [HistogramSteps],[HistogramEstimatedRows],[MaxEqualRows],[MaxRangeRows],[MaxStepRows]
        , [DominantStepPercent],[TailStepRows],[TailStepPercent],[CollectionStatus]
    INTO [#CreateExecutionEvidenceJson_HistogramSummaryOutput]
    FROM [#CreateExecutionEvidenceJson_HistogramSummary];

    SELECT
          [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1)) ELSE NULL END
        , [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1)) ELSE NULL END
        , [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1)) ELSE NULL END
        , [StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[StatisticsName])),1)) ELSE NULL END
        , [StatisticsId]
        , [LeadingColumnName]=CASE @IdentifierMode WHEN 'RAW' THEN [LeadingColumnName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([LeadingColumnName],N''))),1)) ELSE NULL END
        , [StepOrdinal]
        , [RangeHighKey]=CASE WHEN @PrivacyMode='RAW' THEN [RangeHighKeyRaw] END
        , [RangeHighKeyToken]=CASE WHEN @PrivacyMode='TOKENIZED' AND [RangeHighKeyRaw] IS NOT NULL
            THEN HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[RangeHighKeyRaw])) END
        , [RangeRows],[EqualRows],[DistinctRangeRows],[AverageRangeRows]
        , [IsPredicateTarget]=COALESCE([IsPredicateTarget],0),[PredicateMatchCount]=COALESCE([PredicateMatchCount],0)
        , [SensitiveValueStatus]=CONVERT(varchar(40),CASE @PrivacyMode WHEN 'RAW' THEN 'AVAILABLE_RAW'
             WHEN 'TOKENIZED' THEN 'TOKENIZED_CAPTURE_LOCAL' WHEN 'STRUCTURE_ONLY' THEN 'OMITTED_STRUCTURE_ONLY'
             ELSE 'OMITTED_DERIVED_ONLY' END)
    INTO [#CreateExecutionEvidenceJson_HistogramStepsOutput]
    FROM [#CreateExecutionEvidenceJson_HistogramSteps];

    SELECT
          [PredicateReferenceId],[StatementOrdinal],[NodeId]
        , [DatabaseName]=CASE @IdentifierMode WHEN 'RAW' THEN [DatabaseName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([DatabaseName],N''))),1)) ELSE NULL END
        , [SchemaName]=CASE @IdentifierMode WHEN 'RAW' THEN [SchemaName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([SchemaName],N''))),1)) ELSE NULL END
        , [ObjectName]=CASE @IdentifierMode WHEN 'RAW' THEN [ObjectName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([ObjectName],N''))),1)) ELSE NULL END
        , [ColumnName]=CASE @IdentifierMode WHEN 'RAW' THEN [ColumnName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([ColumnName],N''))),1)) ELSE NULL END
        , [StatisticsName]=CASE @IdentifierMode WHEN 'RAW' THEN [StatisticsName] WHEN 'TOKENIZED' THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),COALESCE([StatisticsName],N''))),1)) ELSE NULL END
        , [PredicateKind],[ValueSource],[MappingStatus],[MappingConfidence],[MatchedStepOrdinal]
        , [MatchesRangeHighKey],[IsBelowHistogram],[IsAboveHistogram],[SensitiveValueStatus]
    INTO [#CreateExecutionEvidenceJson_PredicateMappingsOutput]
    FROM [#CreateExecutionEvidenceJson_PredicateHistogramMappings];

    INSERT [#CreateExecutionEvidenceJson_CaptureStatus]
    SELECT
          N'USP_CreateExecutionEvidenceJson',@GeneratedAtUtc,@StatusCodeOut,@IsPartialOut,1
        , (SELECT COUNT_BIG(*) FROM [#CreateExecutionEvidenceJson_StatisticsIoOutput])
        , (SELECT COUNT_BIG(*) FROM [#CreateExecutionEvidenceJson_StatisticsTimeOutput])
        , (SELECT COUNT_BIG(*) FROM [#CreateExecutionEvidenceJson_PlanStatisticsUsageOutput])
        , (SELECT COUNT_BIG(*) FROM [#CreateExecutionEvidenceJson_StatisticsCurrentOutput])
        , (SELECT COUNT_BIG(*) FROM [#CreateExecutionEvidenceJson_HistogramStepsOutput])
        , (SELECT COUNT_BIG(*) FROM [#CreateExecutionEvidenceJson_PredicateMappingsOutput])
        , @PrivacyMode,@IdentifierMode,@SameExecutionConfidence,@ErrorNumberOut,@ErrorMessageOut;

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @PlanDocumentHash nvarchar(130)=CASE WHEN @PlanXml IS NOT NULL
            THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),CONVERT(nvarchar(max),@PlanXml))),1) END;
        DECLARE @MetaJson nvarchar(max)=(SELECT N'ExecutionEvidence' [resultName],1 [schemaVersion],N'USP_CreateExecutionEvidenceJson' [generator],N'1.0.0' [generatorVersion],@GeneratedAtUtc [generatedAtUtc],@StatusCodeOut [statusCode],@IsPartialOut [isPartial] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @CaptureJson nvarchar(max)=(SELECT @GeneratedAtUtc [capturedAtUtc],@SameExecutionAsPlanConfirmed [sameExecutionAsPlan],@SameExecutionConfidence [sameExecutionConfidence],@StatementOrdinal [statementOrdinal],@StatisticsLanguage [statisticsLanguage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @EnvironmentJson nvarchar(max)=(SELECT @SourceProductVersion [productVersion],@SourceCompatibilityLevel [compatibilityLevel],@SourceEngineEdition [engineEdition] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @IdentityJson nvarchar(max)=(SELECT @PlanDocumentHash [planDocumentHash],@StatementId [statementId] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @IoJson nvarchar(max)=(SELECT
              [StatementOrdinal] [statementOrdinal],[MessageOrdinal] [messageOrdinal],[ObjectOrdinal] [objectOrdinal]
            , [ObjectDisplayName] [objectDisplayName],[ScanCount] [scanCount],[LogicalReads] [logicalReads]
            , [PhysicalReads] [physicalReads],[PageServerReads] [pageServerReads],[ReadAheadReads] [readAheadReads]
            , [PageServerReadAheadReads] [pageServerReadAheadReads],[LobLogicalReads] [lobLogicalReads]
            , [LobPhysicalReads] [lobPhysicalReads],[LobPageServerReads] [lobPageServerReads]
            , [LobReadAheadReads] [lobReadAheadReads],[LobPageServerReadAheadReads] [lobPageServerReadAheadReads]
            , [LanguageDetected] [languageDetected],[ParseStatus] [parseStatus],[RawLine] [rawLine]
            FROM [#CreateExecutionEvidenceJson_StatisticsIoOutput] ORDER BY [MessageOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @TimeJson nvarchar(max)=(SELECT
              [StatementOrdinal] [statementOrdinal],[MessageOrdinal] [messageOrdinal],[TimeCategory] [timeCategory]
            , [CpuMs] [cpuMs],[ElapsedMs] [elapsedMs],[LanguageDetected] [languageDetected]
            , [ParseStatus] [parseStatus],[RawLine] [rawLine]
            FROM [#CreateExecutionEvidenceJson_StatisticsTimeOutput] ORDER BY [MessageOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @PlanStatsJson nvarchar(max)=(SELECT
              [StatisticsUsageOrdinal] [statisticsUsageOrdinal],[StatementOrdinal] [statementOrdinal]
            , [StatementId] [statementId],[StatementCompId] [statementCompId]
            , [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [StatisticsName] [statisticsName],[LastUpdateAtCompile] [lastUpdateAtCompile]
            , [ModificationCountAtCompile] [modificationCountAtCompile]
            , [SamplingPercentAtCompile] [samplingPercentAtCompile],[SourceElement] [sourceElement]
            , [ParseStatus] [parseStatus]
            FROM [#CreateExecutionEvidenceJson_PlanStatisticsUsageOutput] ORDER BY [StatementOrdinal],[StatisticsUsageOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @ObjectsJson nvarchar(max)=(SELECT
              [ReferenceOrdinal] [referenceOrdinal],[StatementOrdinal] [statementOrdinal]
            , [StatementId] [statementId],[StatementCompId] [statementCompId],[NodeId] [nodeId]
            , [ReferenceType] [referenceType],[ReferenceSource] [referenceSource]
            , [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [IndexName] [indexName],[AliasName] [aliasName],[StorageType] [storageType]
            , [PlanObjectId] [planObjectId],[PlanIndexId] [planIndexId]
            , [IsTemporaryObject] [isTemporaryObject],[IsTableVariable] [isTableVariable]
            , [IsRemoteObject] [isRemoteObject],[IsDmlTarget] [isDmlTarget]
            , [ResolutionCapability] [resolutionCapability],[SourceElement] [sourceElement]
            FROM [#CreateExecutionEvidenceJson_ObjectReferencesOutput] ORDER BY [StatementOrdinal],[ReferenceOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @CurrentStatsJson nvarchar(max)=(SELECT
              [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [ObjectId] [objectId],[StatisticsName] [statisticsName],[StatisticsId] [statisticsId]
            , [IsIndexStatistics] [isIndexStatistics],[IsAutoCreated] [isAutoCreated],[IsUserCreated] [isUserCreated]
            , [IsFiltered] [isFiltered],[FilterDefinition] [filterDefinition],[FilterDefinitionStatus] [filterDefinitionStatus]
            , [NoRecompute] [noRecompute],[IsIncremental] [isIncremental],[HasPersistedSample] [hasPersistedSample]
            , [LeadingColumnName] [leadingColumnName],[LastUpdated] [lastUpdated],[Rows] [rows]
            , [RowsSampled] [rowsSampled],[SamplePercent] [samplePercent],[Steps] [steps]
            , [UnfilteredRows] [unfilteredRows],[ModificationCounter] [modificationCounter]
            , [ModificationPercent] [modificationPercent],[PersistedSamplePercent] [persistedSamplePercent]
            , [CollectionStatus] [collectionStatus]
            FROM [#CreateExecutionEvidenceJson_StatisticsCurrentOutput] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @HistogramSummaryJson nvarchar(max)=(SELECT
              [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [StatisticsName] [statisticsName],[StatisticsId] [statisticsId],[LeadingColumnName] [leadingColumnName]
            , [HistogramSteps] [histogramSteps],[HistogramEstimatedRows] [histogramEstimatedRows]
            , [MaxEqualRows] [maxEqualRows],[MaxRangeRows] [maxRangeRows],[MaxStepRows] [maxStepRows]
            , [DominantStepPercent] [dominantStepPercent],[TailStepRows] [tailStepRows]
            , [TailStepPercent] [tailStepPercent],[CollectionStatus] [collectionStatus]
            FROM [#CreateExecutionEvidenceJson_HistogramSummaryOutput] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @HistogramStepsJson nvarchar(max)=(SELECT
              [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [StatisticsName] [statisticsName],[StatisticsId] [statisticsId],[LeadingColumnName] [leadingColumnName]
            , [StepOrdinal] [stepOrdinal],[RangeHighKey] [rangeHighKey],[RangeHighKeyToken] [rangeHighKeyToken]
            , [RangeRows] [rangeRows],[EqualRows] [equalRows],[DistinctRangeRows] [distinctRangeRows]
            , [AverageRangeRows] [averageRangeRows],[IsPredicateTarget] [isPredicateTarget]
            , [PredicateMatchCount] [predicateMatchCount],[SensitiveValueStatus] [sensitiveValueStatus]
            FROM [#CreateExecutionEvidenceJson_HistogramStepsOutput] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StepOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @MappingsJson nvarchar(max)=(SELECT
              [PredicateReferenceId] [predicateReferenceId],[StatementOrdinal] [statementOrdinal],[NodeId] [nodeId]
            , [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [ColumnName] [columnName],[StatisticsName] [statisticsName],[PredicateKind] [predicateKind]
            , [ValueSource] [valueSource],[MappingStatus] [mappingStatus],[MappingConfidence] [mappingConfidence]
            , [MatchedStepOrdinal] [matchedStepOrdinal],[MatchesRangeHighKey] [matchesRangeHighKey]
            , [IsBelowHistogram] [isBelowHistogram],[IsAboveHistogram] [isAboveHistogram]
            , [SensitiveValueStatus] [sensitiveValueStatus]
            FROM [#CreateExecutionEvidenceJson_PredicateMappingsOutput] ORDER BY [StatementOrdinal],[PredicateReferenceId],[ValueSource] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @StatusJson nvarchar(max)=(SELECT
              [DatabaseName] [databaseName],[SchemaName] [schemaName],[ObjectName] [objectName]
            , [StatisticsName] [statisticsName],[StatusCode] [statusCode],[ErrorNumber] [errorNumber]
            , [ErrorMessage] [errorMessage]
            FROM [#CreateExecutionEvidenceJson_CollectionStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max)=(SELECT
              [WarningCode] [warningCode],[Severity] [severity],[Detail] [detail]
            FROM [#CreateExecutionEvidenceJson_Warnings] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @RawInputJson nvarchar(max)=(SELECT
              LEN(@StatisticsIoText) [statisticsIoCharacters]
            , CASE WHEN @RawMode IN ('HASH_ONLY','INCLUDE') AND @StatisticsIoText IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@StatisticsIoText)),1) END [statisticsIoHash]
            , LEN(@StatisticsTimeText) [statisticsTimeCharacters]
            , CASE WHEN @RawMode IN ('HASH_ONLY','INCLUDE') AND @StatisticsTimeText IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@StatisticsTimeText)),1) END [statisticsTimeHash]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);

        SET @Json=CONCAT
        (
              N'{"meta":',COALESCE(@MetaJson,N'{}')
            , N',"capture":',COALESCE(@CaptureJson,N'{}')
            , N',"sourceEnvironment":',COALESCE(@EnvironmentJson,N'{}')
            , N',"planIdentity":',COALESCE(@IdentityJson,N'{}')
            , N',"statisticsIo":',COALESCE(@IoJson,N'[]')
            , N',"statisticsTime":',COALESCE(@TimeJson,N'[]')
            , N',"statistics":{"planUsage":',COALESCE(@PlanStatsJson,N'[]')
            , N',"currentSnapshot":',COALESCE(@CurrentStatsJson,N'[]')
            , N',"histogramSummaries":',COALESCE(@HistogramSummaryJson,N'[]')
            , N',"histogramSteps":',COALESCE(@HistogramStepsJson,N'[]'),N'}'
            , N',"objectReferences":',COALESCE(@ObjectsJson,N'[]')
            , N',"predicateHistogramMappings":',COALESCE(@MappingsJson,N'[]')
            , N',"collectionStatus":',COALESCE(@StatusJson,N'[]')
            , N',"warnings":',COALESCE(@WarningsJson,N'[]')
            , N',"rawInput":',COALESCE(@RawInputJson,N'{}')
            , N',"importedEvidence":'
            , COALESCE
              (
                  (
                      SELECT
                            CONVERT(bit,CASE WHEN @StatisticsEvidenceJson IS NOT NULL THEN 1 ELSE 0 END) [statisticsEvidenceProvided]
                          , CASE WHEN @StatisticsEvidenceJson IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@StatisticsEvidenceJson)),1) END [statisticsEvidenceHash]
                          , CONVERT(bit,CASE WHEN @ObjectMetadataJson IS NOT NULL THEN 1 ELSE 0 END) [objectMetadataProvided]
                          , CASE WHEN @ObjectMetadataJson IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ObjectMetadataJson)),1) END [objectMetadataHash]
                          , CONVERT(bit,CASE WHEN @ExistingEvidenceJson IS NOT NULL AND ISJSON(@ExistingEvidenceJson)=1 THEN 1 ELSE 0 END) [existingEvidenceMerged]
                          , CASE WHEN @ExistingEvidenceJson IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ExistingEvidenceJson)),1) END [existingEvidenceHash]
                          , CONVERT(bit,CASE WHEN @AdditionalEvidenceJson IS NOT NULL THEN 1 ELSE 0 END) [additionalEvidenceProvided]
                          , CASE WHEN @AdditionalEvidenceJson IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@AdditionalEvidenceJson)),1) END [additionalEvidenceHash]
                      FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
                  )
                , N'{}'
              )
            , N',"additionalEvidence":'
            , CASE WHEN @PrivacyMode='RAW' AND @SensitiveDataConfirmed=1
                   THEN COALESCE(JSON_QUERY(@AdditionalEvidenceJson),N'null') ELSE N'null' END
            , N'}'
        );
    END;

    IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#CreateExecutionEvidenceJson_CaptureStatus];
        SELECT * FROM [#CreateExecutionEvidenceJson_StatisticsIoOutput] ORDER BY [MessageOrdinal];
        SELECT * FROM [#CreateExecutionEvidenceJson_StatisticsTimeOutput] ORDER BY [MessageOrdinal];
        SELECT * FROM [#CreateExecutionEvidenceJson_PlanStatisticsUsageOutput] ORDER BY [StatementOrdinal],[StatisticsUsageOrdinal];
        SELECT * FROM [#CreateExecutionEvidenceJson_ObjectReferencesOutput] ORDER BY [StatementOrdinal],[ReferenceOrdinal];
        SELECT * FROM [#CreateExecutionEvidenceJson_StatisticsCurrentOutput] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName];
        SELECT * FROM [#CreateExecutionEvidenceJson_HistogramSummaryOutput] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName];
        SELECT * FROM [#CreateExecutionEvidenceJson_HistogramStepsOutput] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StepOrdinal];
        SELECT * FROM [#CreateExecutionEvidenceJson_PredicateMappingsOutput] ORDER BY [StatementOrdinal],[PredicateReferenceId],[ValueSource];
        SELECT * FROM [#CreateExecutionEvidenceJson_CollectionStatus];
        SELECT * FROM [#CreateExecutionEvidenceJson_Warnings];
    END;

    IF @ConsoleResultRequested=1
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#CreateExecutionEvidenceJson_CaptureStatus'
            , @ResultLabel=N'Execution Evidence'
            , @EmptyMessage=N'Keine Evidenz erzeugt'
            , @StatusCode=@StatusCodeOut
            , @StatusMessage=@ErrorMessageOut;

    IF @TableRequested=1
    BEGIN
        DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
        DECLARE [MapCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [ResultName],[TargetTable] FROM [#CreateExecutionEvidenceJson_TableMap] ORDER BY [ResultName];
        OPEN [MapCursor];
        FETCH NEXT FROM [MapCursor] INTO @ResultName,@TargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @SourceTable=CASE @ResultName
                WHEN N'captureStatus' THEN N'#CreateExecutionEvidenceJson_CaptureStatus'
                WHEN N'statisticsIo' THEN N'#CreateExecutionEvidenceJson_StatisticsIoOutput'
                WHEN N'statisticsTime' THEN N'#CreateExecutionEvidenceJson_StatisticsTimeOutput'
                WHEN N'planStatisticsUsage' THEN N'#CreateExecutionEvidenceJson_PlanStatisticsUsageOutput'
                WHEN N'objectReferences' THEN N'#CreateExecutionEvidenceJson_ObjectReferencesOutput'
                WHEN N'currentStatistics' THEN N'#CreateExecutionEvidenceJson_StatisticsCurrentOutput'
                WHEN N'histogramSummaries' THEN N'#CreateExecutionEvidenceJson_HistogramSummaryOutput'
                WHEN N'histogramSteps' THEN N'#CreateExecutionEvidenceJson_HistogramStepsOutput'
                WHEN N'predicateHistogramMappings' THEN N'#CreateExecutionEvidenceJson_PredicateMappingsOutput'
                WHEN N'collectionStatus' THEN N'#CreateExecutionEvidenceJson_CollectionStatus'
                WHEN N'warnings' THEN N'#CreateExecutionEvidenceJson_Warnings' END;
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=@SourceTable,@TargetTable=@TargetTable,@ThrowOnError=1;
            FETCH NEXT FROM [MapCursor] INTO @ResultName,@TargetTable;
        END;
        CLOSE [MapCursor];DEALLOCATE [MapCursor];
    END;

    IF @PrintMeldungen=1 AND @StatusCodeOut NOT IN ('AVAILABLE')
    BEGIN
        DECLARE @Message nvarchar(2048)=FORMATMESSAGE(N'WARNUNG USP_CreateExecutionEvidenceJson: %s - %s',@StatusCodeOut,COALESCE(@ErrorMessageOut,N'partielle Evidenz'));
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;
END;
GO

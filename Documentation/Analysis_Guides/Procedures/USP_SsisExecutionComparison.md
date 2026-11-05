# [monitor].[USP_SsisExecutionComparison]

**Bereich:** SSIS<br>
**Zweck:** Vergleicht genau eine Basisausführung und einen Kandidaten desselben exakten Paketmodellexports.<br>
**Beobachtungsart:** Zwei lokal gebundene historische Katalogcaptures.<br>
**Kostenklasse:** LOW_MEDIUM; JSON-Validierung, vorhandene Scopeauflösung und Kennzahlenpaarung bestimmen den Aufwand.

## Entscheidungsfrage und Einsatz

Die Procedure zeigt Änderungen beobachteter Status-, Dauer- und Pfadwerte. Sie verwendet die bestehenden Modell-, Scope- und Diagnoseconsumer. Parser, Komponentenprofile und Lineage verbleiben in Toolbelt; auf dem Analyze-Server sind weder Toolbelt noch SQL CLR erforderlich. Die API gehört zum Quellstand und ist über den [SSIS-Installer](../../../Code/Install/Install_SSIS_Analysis.sql) verfügbar; das Produkt-ZIP 1.1.2 enthält sie noch nicht.

Beide Seiten benötigen eine unabhängig registrierte lokale Scopeübergabe. Die Aufnahme erfolgt mit `Invoke-SsisCatalogHandover.ps1 -IncludeExecutionScopes -IncludePipelineCorrelation -IncludeComparisonContext`. Das neue Opt-in übernimmt ausschließlich die vor und nach der Aufnahme übereinstimmende 32-/64-Bit-Kennung aus `catalog.executions`. Es überträgt keine Parameterwerte oder Verbindungszeichenfolgen.

## Nicht beantwortete Fragen

Der Vergleich beweist weder Arbeitslastgleichheit noch eine Regressionsursache. Gleiche Pfade und Iterationsnummern bezeichnen beobachtete Positionen; sie identifizieren keine gleiche Datei oder Datenzeile. Unterschiedliche Paketrevisionen, Expressionauswertung und Paketausführung gehören nicht zu diesem Vertrag. `WorkloadEquivalence` bleibt `UNPROVEN`; alle Ergebnisse bleiben partiell.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SsisExecutionComparison] @Hilfe = 1;

-- Die Eingabewerte stammen aus zwei getrennten lokalen Übergaben.
EXEC [monitor].[USP_SsisExecutionComparison]
      @BaselineProjectModelsJson=@BaselineModels,
      @BaselineScopeSnapshotJson=@BaselineCapture,
      @BaselineScopeHandoverId=@BaselineHandover,
      @BaselineExecutionId=@BaselineExecution,
      @CandidateProjectModelsJson=@CandidateModels,
      @CandidateScopeSnapshotJson=@CandidateCapture,
      @CandidateScopeHandoverId=@CandidateHandover,
      @CandidateExecutionId=@CandidateExecution,
      @MaxZeilen=200, @ResultSetArt='CONSOLE';
```

Die Ausführungskennungen müssen positiv und verschieden sein. Beide Captures müssen dieselbe Quellbindung, Katalog-GUID, Projektkennung, Projekt-LSN, Archivkennung und Rootpaketdatei belegen. Beide Modelltexte müssen bytegleich in UTF-16LE sein; andere Leerzeichen führen bereits zu `COMPARISON_MODEL_EXPORT_DIFFERENT`. Diese konservative Bindung verhindert einen Vergleich unterschiedlicher Modell- oder Producerprofile. Unterschiedlich serialisierte Exporte werden nicht als semantisch gleich qualifiziert.

## Parameter und Eingabeformen

Jeder Eintrag nennt den SQL-Datentyp, den ausdrücklich bezeichneten Default und die tatsächlich verarbeitete Form. Ausgelassene Argumente verwenden den Signaturdefault. Unicode-JSON wird als nvarchar(max)-Variable oder T-SQL-Literal mit N-Präfix übergeben; ein Dateipfad wird nicht geöffnet. DATALENGTH misst SQL-UTF-16-Bytes. Die lokalen Scopebelege werden auf monitor.USP_SsisPackageModelAnalysis registriert; die Vergleichsprocedure fordert keine eigene Registrierung auf ihrem Objekt. Zum Empfangen eines OUTPUT-Werts wird am Aufruf eine passend typisierte Variable mit OUTPUT gebunden. Hilfe setzt nur @Json=NULL; die vier Status-/Fehler-OUTPUTs bleiben unverändert.

### @BaselineProjectModelsJson

**Datentyp:** `nvarchar(max)`; **Default:** `NULL`. Als einzelne nvarchar(max)-Variable oder N'…'-Literal übergeben, nicht als Dateipfad. Erforderlich für die Basis-Seite. JSON-Objekt mit contract="ssis-project-model-set", version="1.0.0", rootPackageKey als String und packages als Array mit 1 bis 16 eindeutigen Paketen. Jedes Paket enthält packageKey und entryName als Strings, model als vollständiges Objekt mit contract="ssis-package-model" und version="1.0.0" sowie identities als Objekt mit contract="ssis-object-identities" und version="1.2.0". Für diesen Consumer müssen zusätzlich pipelineIdentities als Objekt mit contract="ssis-pipeline-identities" und version="1.0.0" vorhanden und an dieselben Paket-/Modellidentitäten gebunden sein. Der gemeinsame Consumer aktiviert Scope-, Pipelinekorrelations- und Pipeline-Diagnosepfade; dieses Argument ergänzt keine eigene Parser- oder Lineageauswertung. Das unveränderte Modellobjekt muss auf allen verglichenen Seiten bytegenau gleich sein: SHA-256 wird über die exakten nvarchar-UTF-16-Bytes gebildet; Neu-Serialisierung, geänderte Whitespace-/Property-Reihenfolge oder andere Bytes ändern den Exporthash. Höchstens 16.777.216 Bytes je Modell, gemessen mit SQL Server DATALENGTH(nvarchar), also UTF-16-Bytes und nicht UTF-8-Dateigröße. JSON-Objektschlüssel und Identitäten werden streng geprüft. NULL, Leerstring und ungültiges JSON sind unzulässig. Siehe den bestehenden SsisPackageModelAnalysis-Vertrag für vollständige Parser-/Modellregeln.

### @BaselineScopeSnapshotJson

**Datentyp:** `nvarchar(max)`; **Default:** `NULL`. Als einzelne nvarchar(max)-Variable oder N'…'-Literal übergeben. Erforderlich ist ein JSON-Objekt mit contract="ssis-execution-scopes", version="1.1.0", method="SSISDB_CURRENT_PROJECT_PIPELINES_V1", gebunden an project-model-set und passende pipelineIdentities; gültige Wurzel-/Ausführungsbindung umfasst execution als Objekt mit executionId, projectId, projectLsn, catalogDatabaseGuid, sourceBindingSha256 und packageFileName; archiveSha256 und modelSetSha256 liegen auf Wurzelebene (SHA-256 der exakten Basis-Model-JSON-Bytes). Enthält observations- und events-Arrays sowie componentPhases- und pathTransfers-Arrays und genau die zwei pipelineSources-Einträge für componentPhases und pathTransfers; deren Statuswerte und Fehlernummern müssen dem Capturevertrag entsprechen. Alle Schlüssel, Namen, Pfade, IDs, Zeit-/Ergebniswerte und Quellgrenzen müssen die von 035–037 geprüften Formen erfüllen; höchstens 50.000 Einträge im Scope-/Pipeline-Capture. Der Transport muss bytegenau dem lokal registrierten Scope-Handover entsprechen; nicht neu serialisieren. Höchstens 16.777.216 Bytes je Capture, gemessen durch DATALENGTH(nvarchar) in SQL-UTF-16-Bytes. NULL, Leerstring und ungültiges JSON sind unzulässig. Vergleichsseiten werden unabhängig attestiert. Optional kann comparisonContext genau ein Objekt mit genau contract="ssis-comparison-context", version="1.0.0" und use32BitRuntime als JSON-Boolean enthalten; fehlt diese Zusatzinformation oder ist sie ungültig, bleibt der Capture nicht automatisch ungebunden, aber der Laufzeitkontext ist unbewiesen. Beide Seiten müssen dieselben exakten Export- und Quell-/Projektversionsfelder einschließlich archiveSha256 aufweisen.

### @BaselineScopeHandoverId

**Datentyp:** `uniqueidentifier`; **Default:** `NULL`. Als uniqueidentifier-Parameter im üblichen GUID-Format übergeben. Erforderliche UUID eines lokal auf monitor.USP_SsisPackageModelAnalysis registrierten SSIS_SCOPE_<UUID> Extended-Property-Handover; die Registrierung bindet die exakten UTF-16-Bytes des zugehörigen ProjectModelsJson und ScopeSnapshotJson und ist zeitlich gültig. Die UUID ist nur der lokale Belegschlüssel, kein JSON-Trustflag und keine selbst behauptete Attestation; eine frei erfundene oder auf einem anderen Objekt registrierte ID genügt nicht. Jede Seite wird unabhängig gegen den zu ihren Dokumentbytes passenden registrierten Beleg geprüft. Die Procedure verlangt keine gesonderte Ungleichheit der GUIDs; die Execution-IDs müssen verschieden sein. NULL ist ungültig. Der Belegname verwendet die GUID in Kleinschreibung. issuedUtc muss höchstens beim Analysebeginn liegen; expiresUtc danach und höchstens 24 Stunden nach issuedUtc. Es gibt keine Mindestgültigkeitsdauer. Als uniqueidentifier-Variable oder konvertierbares GUID-Literal der Form 00000000-0000-0000-0000-000000000000 übergeben; die Null-GUID ersetzt keinen registrierten Beleg.

### @BaselineExecutionId

**Datentyp:** `bigint`; **Default:** `NULL`. Einzelne positive SSISDB Execution-ID im Wertebereich 1 bis 9.223.372.036.854.775.807. Muss mit der Basis-Capture-Bindung übereinstimmen und von @CandidateExecutionId verschieden sein. NULL, 0, negative Werte und Duplikat zum Kandidaten sind ungültig. Als bigint-Zahl binden, keine Liste oder Text-Identität.

### @CandidateProjectModelsJson

**Datentyp:** `nvarchar(max)`; **Default:** `NULL`. Als einzelne nvarchar(max)-Variable oder N'…'-Literal übergeben, nicht als Dateipfad. Erforderlich für die Kandidaten-Seite. JSON-Objekt mit contract="ssis-project-model-set", version="1.0.0", rootPackageKey als String und packages als Array mit 1 bis 16 eindeutigen Paketen. Jedes Paket enthält packageKey und entryName als Strings, model als vollständiges Objekt mit contract="ssis-package-model" und version="1.0.0" sowie identities als Objekt mit contract="ssis-object-identities" und version="1.2.0". Für diesen Consumer müssen zusätzlich pipelineIdentities als Objekt mit contract="ssis-pipeline-identities" und version="1.0.0" vorhanden und an dieselben Paket-/Modellidentitäten gebunden sein. Der gemeinsame Consumer aktiviert Scope-, Pipelinekorrelations- und Pipeline-Diagnosepfade; dieses Argument ergänzt keine eigene Parser- oder Lineageauswertung. Das unveränderte Modellobjekt muss auf allen verglichenen Seiten bytegenau gleich sein: SHA-256 wird über die exakten nvarchar-UTF-16-Bytes gebildet; Neu-Serialisierung, geänderte Whitespace-/Property-Reihenfolge oder andere Bytes ändern den Exporthash. Höchstens 16.777.216 Bytes je Modell, gemessen mit SQL Server DATALENGTH(nvarchar), also UTF-16-Bytes und nicht UTF-8-Dateigröße. JSON-Objektschlüssel und Identitäten werden streng geprüft. NULL, Leerstring und ungültiges JSON sind unzulässig. Siehe den bestehenden SsisPackageModelAnalysis-Vertrag für vollständige Parser-/Modellregeln.

### @CandidateScopeSnapshotJson

**Datentyp:** `nvarchar(max)`; **Default:** `NULL`. Als einzelne nvarchar(max)-Variable oder N'…'-Literal übergeben. Erforderlich ist ein JSON-Objekt mit contract="ssis-execution-scopes", version="1.1.0", method="SSISDB_CURRENT_PROJECT_PIPELINES_V1", gebunden an project-model-set und passende pipelineIdentities; gültige Wurzel-/Ausführungsbindung umfasst execution als Objekt mit executionId, projectId, projectLsn, catalogDatabaseGuid, sourceBindingSha256 und packageFileName; archiveSha256 und modelSetSha256 liegen auf Wurzelebene (SHA-256 der exakten Kandidaten-Model-JSON-Bytes). Enthält observations- und events-Arrays sowie componentPhases- und pathTransfers-Arrays und genau die zwei pipelineSources-Einträge für componentPhases und pathTransfers; deren Statuswerte und Fehlernummern müssen dem Capturevertrag entsprechen. Alle Schlüssel, Namen, Pfade, IDs, Zeit-/Ergebniswerte und Quellgrenzen müssen die von 035–037 geprüften Formen erfüllen; höchstens 50.000 Einträge im Scope-/Pipeline-Capture. Der Transport muss bytegenau dem lokal registrierten Scope-Handover entsprechen; nicht neu serialisieren. Höchstens 16.777.216 Bytes je Capture, gemessen durch DATALENGTH(nvarchar) in SQL-UTF-16-Bytes. NULL, Leerstring und ungültiges JSON sind unzulässig. Vergleichsseiten werden unabhängig attestiert. Optional kann comparisonContext genau ein Objekt mit genau contract="ssis-comparison-context", version="1.0.0" und use32BitRuntime als JSON-Boolean enthalten; fehlt diese Zusatzinformation oder ist sie ungültig, bleibt der Capture nicht automatisch ungebunden, aber der Laufzeitkontext ist unbewiesen. Beide Seiten müssen dieselben exakten Export- und Quell-/Projektversionsfelder einschließlich archiveSha256 aufweisen.

### @CandidateScopeHandoverId

**Datentyp:** `uniqueidentifier`; **Default:** `NULL`. Als uniqueidentifier-Parameter im üblichen GUID-Format übergeben. Erforderliche UUID eines lokal auf monitor.USP_SsisPackageModelAnalysis registrierten SSIS_SCOPE_<UUID> Extended-Property-Handover; die Registrierung bindet die exakten UTF-16-Bytes des zugehörigen ProjectModelsJson und ScopeSnapshotJson und ist zeitlich gültig. Die UUID ist nur der lokale Belegschlüssel, kein JSON-Trustflag und keine selbst behauptete Attestation; eine frei erfundene oder auf einem anderen Objekt registrierte ID genügt nicht. Jede Seite wird unabhängig gegen den zu ihren Dokumentbytes passenden registrierten Beleg geprüft. Die Procedure verlangt keine gesonderte Ungleichheit der GUIDs; die Execution-IDs müssen verschieden sein. NULL ist ungültig. Der Belegname verwendet die GUID in Kleinschreibung. issuedUtc muss höchstens beim Analysebeginn liegen; expiresUtc danach und höchstens 24 Stunden nach issuedUtc. Es gibt keine Mindestgültigkeitsdauer. Als uniqueidentifier-Variable oder konvertierbares GUID-Literal der Form 00000000-0000-0000-0000-000000000000 übergeben; die Null-GUID ersetzt keinen registrierten Beleg.

### @CandidateExecutionId

**Datentyp:** `bigint`; **Default:** `NULL`. Einzelne positive SSISDB Execution-ID im bigint-Bereich 1 bis 9.223.372.036.854.775.807. Muss zum Kandidaten-Capture passen und von @BaselineExecutionId verschieden sein. NULL, 0, negative Werte oder gleiche ID wie die Basis sind ungültig.

### @MinDurationDeltaMs

**Datentyp:** `bigint`; **Default:** `NULL`. Optionale nichtnegative Dauergrenze in Millisekunden (ganzzahlig, 0 bis 9.223.372.036.854.775.807). NULL deaktiviert diese Grenze; 0 lässt nur positive Daueränderungen über 0 passieren. Ein Dauerhinweis entsteht nur bei vergleichbarer bekannter Dauer und wenn die Kandidatenänderung strikt größer als jede gesetzte Grenze ist. Sind beide Grenzen gesetzt, müssen beide überschritten sein. Zeilen- und Statusänderungshinweise sind von dieser Dauerschwelle unabhängig. Negative Werte sind ungültig. Sind beide Dauergrenzen NULL, werden keine Dauergrenzhinweise erzeugt; andere Hinweisarten bleiben davon unabhängig.

### @MinDurationDeltaPercent

**Datentyp:** `decimal(9,4)`; **Default:** `NULL`. Optionale nichtnegative Prozentgrenze als Zahl in Prozent relativer Zunahme ohne %-Zeichen, mit höchstens vier Dezimalstellen und Präzision 9: 0.0000 bis 99999.9999 (z. B. 10.0000 bedeutet zehn Prozent; SQL-Typkonvertierung/Rundung erfolgt vor Eintritt in die Procedure). NULL deaktiviert die Prozentgrenze. Maßgeblich ist eine strikt größere relative Zunahme; bei Basisdauer 0 bleibt die Prozentänderung unbekannt und erfüllt die Grenze nicht. Bei zwei gesetzten Dauerschwellen müssen beide strikt überschritten sein. Negative Werte sind ungültig. Sind beide Dauergrenzen NULL, werden keine Dauergrenzhinweise erzeugt; andere Hinweisarten bleiben davon unabhängig.

### @MaxZeilen

**Datentyp:** `int`; **Default:** `1000`. Maximale ausgegebene Zeilen je Resultgruppe, als int-Zahl. Positive Werte 1 bis 2.147.483.647 begrenzen JSON-, RAW-, TABLE- und Console-Ausgabe; darüber hinaus vorhandene Zeilen werden abgeschnitten und die Ausgabe bleibt partiell. NULL und 0 werden intern als unbegrenzte int-Obergrenze behandelt. Negative Werte sind ungültig.

### @MaxDurationSeconds

**Datentyp:** `int`; **Default:** `30`. Gemeinsames kooperatives Gesamtzeitbudget für beide Seiten und nachfolgende Vergleichsschritte, in Sekunden. Zulässig sind 1 bis 60. Ausgelassen ergibt 30; explizites NULL ist trotz internem COALESCE ungültig. Bei Fristüberschreitung wird die Bindung als nicht belegt ausgegeben und ein Zeitlimitgrund gemeldet.

### @LockTimeoutMs

**Datentyp:** `int`; **Default:** `0`. SQL-Server-Sitzungs-Locktimeout in Millisekunden; zulässig sind 0 bis 60000. 0 bedeutet NOWAIT (nicht auf eine Sperre warten). Positive Werte begrenzen das Warten. NULL und Werte außerhalb des Bereichs sind ungültig; -1 für unbegrenztes Warten ist ausdrücklich unzulässig. Der ursprüngliche Sitzungswert wird anschließend wiederhergestellt.

### @ResultSetArt

**Datentyp:** `varchar(16)`; **Default:** `CONSOLE`. Ein Auswahlcode als Text; Rand-Leerzeichen werden entfernt und die Prüfung normalisiert auf Großbuchstaben. Geschlossene Wertemenge: CONSOLE (kompakte Console-Ausgabe des Binding-Resultsets), RAW (separates Resultset je aktivierter Gruppe mit Rohspalten), TABLE (schreibt ausgewählte Gruppen in lokale Seed-Temp-Tabellen), NONE (keine Resultsets/Consoleausgabe). NULL oder jeder andere Wert ist ungültig. Leerwert ist ungültig; das Trim entfernt U+0020-Leerzeichen, keine beliebigen Whitespacezeichen. JSON ist kein Ausgabeartcode; verwenden Sie @JsonErzeugen.

### @ResultTablesJson

**Datentyp:** `nvarchar(max)`; **Default:** `NULL`. Nur bei ResultSetArt=TABLE zulässig und dann erforderlich: nichtleeres JSON-Objekt aus case-sensitiven Gruppennamen auf Stringwerte lokaler Temp-Tabellennamen, z. B. {"comparisonBinding":"#SeedBinding"}. Erlaubte Gruppenschlüssel samt Bedeutung: comparisonBinding (ein Bindungs-/Statusdatensatz), objectComparison (Objekt-/Kennzahlzuordnung und beobachtete Werte/Deltas), comparisonFindings (versionierte INFO-Beobachtungshinweise), comparisonCoverage (Quell-, Vergleichs- und Ausgabedeckung). Jede beliebige nichtleere Teilmenge dieser vier Gruppen ist zulässig. Ziele müssen unterschiedliche, bereits vorhandene, leere lokale #Temp-Tabellen (keine ##, kein reserviertes #Monitor-Präfix, maximal 116 Zeichen) mit genau einer Seed-Spalte sein; unbekannte oder doppelte Schlüssel/Ziele, JSON-Null, Leerwerte, ungültige Ziele und leeres Objekt werden abgewiesen. Für CONSOLE/RAW/NONE muss der Parameter NULL sein. Keine zusätzliche Eingabegrößengrenze im Consumer belegt. Doppelte Zielnamen und das reservierte Präfix #Monitor werden ohne Beachtung der Großschreibung geprüft.

### @JsonErzeugen

**Datentyp:** `bit`; **Default:** `0`. Schalter: 0 erzeugt keinen JSON-OUTPUT-Vertrag; 1 erzeugt @Json als JSON-Objekt. NULL ist im normalen Aufruf ungültig. SQL-bit-Konvertierungen sind vor der Procedure wirksam. Das JSON enthält meta mit schemaVersion=1, comparisonSchemaVersion=1, isPartial=true sowie die aktivierten/ausgegebenen Arraygruppen comparisonBinding, objectComparison, comparisonFindings und comparisonCoverage. Meta enthält im aktuellen SQL kein statusCode; der Status steht in @StatusCodeOut und in Binding-/Coverage-Daten. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @Json

**Datentyp:** `nvarchar(max) OUTPUT`; **Default:** `NULL OUTPUT`. OUTPUT-Textvariable vom Typ nvarchar(max), am Aufruf mit OUTPUT zu binden, wenn das JSON empfangen werden soll. Beim Eintritt wird der Parameter auf NULL gesetzt; mit @JsonErzeugen=1 wird ein JSON-Objekt mit meta und Gruppenarrays (inklusive JSON-null-Werten, nicht als JSON-Zeichenketten eingebettete Arrays) ausgegeben. Jede Gruppenproperty ist ein Array, auch bei null Zeilen: []. Ohne JSON-Erzeugung bleibt NULL. Im Hilfezweig bleibt der beim Einstieg gesetzte NULL-Wert.

### @PrintMeldungen

**Datentyp:** `bit`; **Default:** `1`. Im Quelltext nicht gelesen oder geprüft; 0, 1 und NULL haben keine unterschiedliche Wirkung. NULL wird nicht als ungültig abgewiesen. Keine Ausgabeunterdrückung darüber dokumentieren; Consoleausgabe wird durch @ResultSetArt gesteuert. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @Hilfe

**Datentyp:** `bit`; **Default:** `0`. Schalter für den reinen Hilfezweig: 1 druckt die eingebauten PRINT-Hinweise und kehrt vor Parametervalidierung, Capture-/Handoverprüfung und fachlicher Analyse zurück. 0 führt den normalen Pfad aus. NULL erfüllt IF @Hilfe=1 nicht und verhält sich wie kein Hilfeaufruf. SQL-bit-Konvertierungen gelten vor dem Eintritt. @Json wird zuvor auf NULL gesetzt; die übrigen OUTPUT-Parameter werden im Hilfezweig nicht neu initialisiert/zugewiesen. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @StatusCodeOut

**Datentyp:** `varchar(40) OUTPUT`; **Default:** `NULL OUTPUT`. Als varchar(40)-Variable mit OUTPUT binden; der Eingabewert steuert die Analyse nicht. Geschlossene globale Rückgabemenge: COMPARISON_CAPTURE_BOUND (beide Seiten unabhängig gebunden, exakt gleicher Export sowie gleiche geprüfte Quell-/Projektversion; Aussage bleibt beobachtungs- und kontextbegrenzt), COMPARISON_BINDING_UNPROVEN (Bindung oder Eingabeverarbeitung nicht belegt) und INVALID_PARAMETER (ungültige Steuerwerte/-kombination). Im aktuellen JSON meta gibt es kein statusCode-Feld; der Laufstatus ist hier sowie in den Bindungs-/Coverage-Daten. Im Hilfezweig unverändert. Eine ungefangene Ausnahme kann Zuweisung umgehen.

### @IsPartialOut

**Datentyp:** `bit OUTPUT`; **Default:** `NULL OUTPUT`. Mit bit-Variable und OUTPUT binden. Bei normalem Abschluss wird stets 1 ausgegeben, auch bei gebundener Eingabe, weil Auswertung und Datenabdeckung partiell sind; Vorabschneidung/Limit wird zusätzlich in Coverage kenntlich. Im Hilfezweig bleibt der übergebene Eingangswert unverändert; ungefangene Fehler können die Zuweisung umgehen.

### @ErrorNumberOut

**Datentyp:** `int OUTPUT`; **Default:** `NULL OUTPUT`. Mit int-Variable und OUTPUT binden. NULL bedeutet, dass kein abgefangener fachlicher Eingabefehler protokolliert wurde; bei abgefangener Validierungs-/Bindungs-/Zeitgrenze wird die SQL-Fehlernummer ausgegeben. Vorzeitige/ungefangene Fehler, insbesondere geworfene TABLE-Mappingfehler, können die OUTPUT-Zuweisung umgehen. Im Hilfezweig unverändert.

### @ErrorMessageOut

**Datentyp:** `nvarchar(2048) OUTPUT`; **Default:** `NULL OUTPUT`. Mit nvarchar(2048)-Variable und OUTPUT binden. Enthält bei abgefangenem Fehler den knappen Reason-/Fehlercode (kein frei formulierter Eingabetext), sonst NULL. Im Hilfezweig unverändert; ungefangene Ausnahmen können die Zuweisung umgehen. nvarchar(2048) umfasst höchstens 2048 UTF-16-Codeeinheiten.

Die [vollständigen Modell- und Scopeformen](USP_SsisPackageModelAnalysis.md#parameter-und-eingabeformen) erläutern die gemeinsamen JSON-Objekte, Pipelineidentitäten und lokalen Herkunftsbindungen. Die hier geltenden zusätzlichen Vergleichs-/Kohortenbedingungen bleiben maßgeblich.

## Hilfe ohne Quellenprüfung

Alle vier Aufrufe kehren vor Capture- und Handoverprüfung zurück. Sie führen kein Paket aus und starten keine Runtime.

```sql
EXEC [monitor].[USP_SsisExecutionComparison] @Hilfe=1;

EXEC [monitor].[USP_SsisExecutionComparison] @ResultSetArt='NONE', @Hilfe=1;

DECLARE @HelpJson nvarchar(max)=N'vorbelegt';
EXEC [monitor].[USP_SsisExecutionComparison] @Hilfe=1, @JsonErzeugen=1, @Json=@HelpJson OUTPUT;
SELECT @HelpJson AS HelpJson;

DECLARE @Code varchar(40)='CALLER', @Partial bit=0, @Error int=0;
EXEC [monitor].[USP_SsisExecutionComparison] @Hilfe=1, @StatusCodeOut=@Code OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT;
SELECT @Code AS StatusCodeOut, @Partial AS IsPartialOut, @Error AS ErrorNumberOut;
```

## Resultsets und Leserichtung

RAW, TABLE und JSON verwenden Schemaversion 1 und dieselben vier Gruppen. CONSOLE liefert genau eine Bindungsübersicht, NONE keine fachlichen Resultsets. JSON wird mit `@JsonErzeugen=1` über `@Json OUTPUT` geliefert. TABLE verwendet vom Caller erstellte lokale Temp-Tabellen und eine benannte Zuordnung in `@ResultTablesJson`; ungültige Zuordnungen werfen Frameworkfehler 51011.

| Gruppe | Bedeutung einer Zeile |
|---|---|
| `comparisonBinding` | Bindung beider Ausführungen, Versionen, Exportidentität, Protokollierung und Bitness mit übergeordnetem Status. |
| `objectComparison` | Eine Modell-/Aufrufposition und Kennzahl mit beiden Werten, Quellenkennungen, Trefferzahlen und gegebenenfalls Delta. |
| `comparisonFindings` | Ein versionierter INFO-Hinweis mit Kennzahl- und Quellenbezug oder eine ausdrückliche Evidenzgrenze. |
| `comparisonCoverage` | Quellenabdeckung je Seite oder Paarungszahlen vor der Ausgabekürzung. |

Lesen Sie zuerst Binding, dann Coverage und danach einzelne Deltas. `ComparisonKeySha256` bindet Objektart, Paket, Modellobjekt, Flow, qualifizierten Ausführungspfad, Phase und Kennzahl. Native Statistikkennungen bleiben Belege je Seite und werden nicht laufübergreifend verbunden. Schleifen und verschiedene Kindpaketaufrufstellen bleiben getrennt. Phasennamen und Pfade werden ordinal einschließlich nachlaufender Leerzeichen unterschieden.

## Eine Zeile bedeutet

Die Objektgruppe enthält Flowdauer und Ergebnis, Phasenintervallsumme, längstes Intervall, Spannweite und Anzahl sowie Pfadzeilen und Transferanzahl. Die gelieferte Portrolle bleibt erhalten. Eine Intervallsumme ist keine CPU-Zeit; Pfadzeilen werden nicht zu einer vermeintlichen Paketzeilenzahl summiert.

## So lesen

`COMPARABLE_OBSERVATION` verlangt je Seite genau einen bekannten, quellenqualifizierten Treffer, gleichen bekannten Protokollierungsgrad 1, 2 oder 3, gleiche attestierte Bitness und zwei erfolgreiche Ausführungen. `STATUS_ONLY` vergleicht Statuswerte ohne numerische Deltas. `BASELINE_ONLY` und `CANDIDATE_ONLY` erhalten die fehlende Gegenseite als NULL. `AMBIGUOUS` unterdrückt Wert und Quellen-ID einer mehrdeutigen Seite. `NOT_COMPARABLE` und `CONTEXT_LIMITED` liefern keine numerischen Deltas.

`DeltaValue` ist Kandidat minus Basis. `DeltaPercent` verwendet die Basis und wird auf sechs Nachkommastellen gerundet; bei Basis null bleibt der Prozentwert unbekannt. Die strikte Prozentgrenze wird unabhängig von dieser Rundung geprüft. Dauerzeilen mit fehlenden, unbekannten oder geänderten beobachteten Pfadzeilensets erhalten `VOLUME_CONTEXT_LIMITED`. Deren bereits berechnete Deltas bleiben beschreibend sichtbar; die Dauergrenzwertregel wird unterdrückt.

## Warum kann das problematisch sein?

Gleiche Paketbytes, Zähler und Laufzeitkontexte beweisen keine gleichen Daten, Parameter, Ressourcen oder Cachezustände. Unterschiedliche Protokollierung verändert Sichtbarkeit und Eigenlast. Ein Abbruch kann vor dem ersten qualifizierbaren Statistikbeleg erfolgen. Fehlende Ereignisse dürfen deshalb weder zu null noch zu erfundenen Aufrufen werden.

## Wann ist es kein Problem?

Ein positiver No-Match-Zähler oder eine längere Dauer kann zur beabsichtigten Verarbeitung gehören. Ein INFO-Hinweis verlangt eine fachliche Gegenprobe. Die Procedure verändert keinen Paketstatus und gibt keine automatische Optimierungs- oder Wiederholungsaktion frei.

## Beispiele und Gegenbeispiele

Die optionalen nichtnegativen Grenzen `@MinDurationDeltaMs` und `@MinDurationDeltaPercent` aktivieren `SSIS_COMPARISON_DURATION_THRESHOLD_EXCEEDED`. Eine bekannte positive Daueränderung muss jede gesetzte Grenze strikt überschreiten. Bei NULL für beide Grenzen entsteht kein Dauerhinweis; Gleichheit genügt nicht. Ein Basiswert null erfüllt keine relative Grenze, kann aber eine allein gesetzte absolute Grenze erfüllen.

`SSIS_COMPARISON_STATUS_CHANGED` zeigt unterschiedliche Statuswerte. `SSIS_COMPARISON_OBSERVED_ROWS_CHANGED` zeigt unterschiedliche bekannte Pfadzähler bei passendem Kontext. `SSIS_COMPARISON_EVIDENCE_LIMITED` benennt begrenzte Bindung, Quelle, Paarung oder Vergleichbarkeit. Alle Regeln tragen Version 1.0.0 und Severity INFO. Quellenkennungen referenzieren den ursprünglichen Capture und beweisen keine Ursache.

## Leere oder partielle Ausgabe

Bei ungültiger Bindung bleibt die Objektgruppe leer; Binding und Coverage erklären die Grenze. Alte Captures ohne optionalen Vergleichskontext bleiben für die Einzelanalyse gültig, erhalten hier jedoch `RUNTIME_CONTEXT_UNPROVEN`. Unbekannter Kontext wird nicht ergänzt.

`@MaxZeilen` begrenzt jede Gruppe erst nach der Berechnung; 0 und NULL bedeuten ungekürzt, negative Werte sind ungültig. Coverage zählt das gesamte berechnete Set und meldet eine Ausgabekürzung. Ein referenzierter Beleg kann außerhalb der ausgegebenen Detailzeilen liegen.

## Eigenlast und Grenzen

Der Standardpfad validiert zwei Modelle und zwei Captures mit jeweils höchstens 16 MiB. Je Seite gelten die bestehenden Quellgrenzen von 50000 Belegen und höchstens 200000 normalisierte Kennzahlen. Das gemeinsame kooperative Budget beträgt standardmäßig 30, höchstens 60 Sekunden. JSON, lokale Temp-Objekte, Hashes und Gruppierungen sind die Haupttreiber; die gelieferte Beobachtungsmenge bestimmt die Skalierung.

Der teuerste Pfad bleibt auf zwei Captures beschränkt und liest weder SSISDB noch externe Datenbanken. EXECUTE und sichtbare lokale Übergabeatteste sind erforderlich. Geschrieben werden eigene Temp-Objekte und ausdrücklich zugeordnete TABLE-Ziele. Caller-Locktimeout und XACT_ABORT werden wiederhergestellt. Das kooperative Zeitbudget ist keine harte CPU- oder Speichergrenze. Begrenzte Eingaben und zunächst kleine Ausgaben ermöglichen einen sicheren Einstieg; der Ausgabegrenzwert reduziert nicht den Validierungsaufwand.

## Technische Vertiefung

### Leitfrage

Sind zwei unabhängig belegte Beobachtungssets derselben Modellrevision an derselben Aufrufposition vergleichbar?

### Technischer Hintergrund

Die bestehende `USP_SsisPackageModelAnalysis` übernimmt Bindung, Pfadauflösung und Diagnoseaggregation je Seite. Der gemeinsame `InternalSsisExecutionMetrics` projiziert diese Ergebnisse und bildet Positionsschlüssel für Paarvergleich und [Mehrlauf-Baseline](USP_SsisExecutionBaseline.md). Er ergänzt keine zweite Parser- oder Lineageimplementierung.

### Datenkette

Toolbelt-Export und Archivbytes werden lokal qualifiziert. Der Adapter registriert zwei getrennte hashgebundene Scopebelege. Die vorhandenen Consumer prüfen sie, bevor der Vergleich Schlüssel und Kennzahlen bildet.

### Source Select

Kein einzelnes Grundselect bildet den Vergleich ab. **Wichtig für die Eigenlast:** Beide vollständigen Captures werden vor der Ausgabekürzung lokal validiert und gruppiert.

Der Vergleich verarbeitet Caller-JSON und lokale Übergabeatteste. Die vorgeschaltete Aufnahme filtert strukturierte Katalogquellen auf genau eine Ausführung; nur dort werden `catalog.executions.use32bitruntime`, Phasen und Transfers gelesen.

### Zeit- und Scope-Modell

Captures gelten zum Aufnahmezeitpunkt und innerhalb ihrer lokalen Gültigkeit. Projekt-LSN und Archivbindung verhindern einen Vergleich aktueller Bytes mit einer fremden historischen Revision. Zwei Zeitpunkte bilden keine Zeitreihe.

### Bewertung und Gegenprobe

Prüfen Sie beide Einzelanalysen, die Belege, Protokollierungsstufen und beobachteten Mengen. Prüfen Sie zusätzlich die fachlichen Eingaben außerhalb dieses Vertrags, bevor Sie gleiche Arbeitslast annehmen.

### Typische Fehlinterpretation

Ein positiver Prozentwert belegt eine Differenz, keine softwarebedingte Regression. Eine gleich nummerierte Iteration muss nicht dieselbe Eingabe verarbeitet haben.

### Folgeanalyse

Die [Einzelanalyse](USP_SsisPackageModelAnalysis.md) zeigt Scopes, Phasen und Transfers. Die [Kataloganalyse](USP_SsisCatalogExecutionAnalysis.md) ergänzt strukturierte Metadaten einer Ausführung.

## Primärquellen

- [Austauschvertrag](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)
- [Kanonische Implementierung](../../../Code/10_SSIS/050_USP_SsisExecutionComparison.sql)
- [Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv)
- [SSISDB-Ausführungsmetadaten](https://learn.microsoft.com/en-us/sql/integration-services/system-views/catalog-executions-ssisdb-database)

[Technische Detailbeschreibung](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

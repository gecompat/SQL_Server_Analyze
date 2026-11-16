# [monitor].[USP_SsisExecutionBaseline]

**Bereich:** SSIS<br>
**Zweck:** Vergleicht einen Kandidaten mit einer expliziten Kohorte unabhängig gebundener Ausführungen derselben Modellrevision.<br>
**Beobachtungsart:** Lokal attestierte historische Katalogcaptures.<br>
**Kostenklasse:** LOW_MEDIUM; die Zahl der Captures und Kennzahlen bestimmt Validierungs-, TempDB- und Gruppierungsaufwand.

## Entscheidungsfrage und Einsatz

Die Procedure zeigt, wie eine beobachtete Kennzahl des Kandidaten zum Median und Wertebereich ausgewählter Basisläufe steht. Die Kohorte enthält 1 bis 20 explizite Basisläufe und genau einen verschiedenen Kandidaten. Es erfolgt keine automatische Suche nach geeigneten Ausführungen. Der [SSIS-Installer](../../../Code/Install/Install_SSIS_Analysis.sql) enthält die API im Quellstand; das Produkt-ZIP 1.1.2 enthält sie noch nicht.

Jeder Capture benötigt eine eigene lokale Scopeübergabe. Die Aufnahme verwendet `Invoke-SsisCatalogHandover.ps1 -IncludeExecutionScopes -IncludePipelineCorrelation -IncludeComparisonContext`. Die Aufnahmeanleitung der [Einzelanalyse](USP_SsisPackageModelAnalysis.md) erläutert Toolbelt-Exporthost, Quellbindung und lokale Attestierung. Die Übergaben müssen auf dem Analyze-Ziel sichtbar und gültig sein. Auf dem Analyze-Server sind weder Toolbelt noch SQL CLR erforderlich. Parser, Komponentenprofile und Lineage werden ausschließlich in Toolbelt gepflegt.

## Nicht beantwortete Fragen

Die API beweist weder gleiche Arbeitslast noch statistische Signifikanz, SLA-Einhaltung oder Regressionsursachen. Gleiche Paketbytes, Aufrufpositionen und Pfadzähler belegen keine gleichen Eingaben, Parameter, Datenzeilen, Ressourcen oder Cachezustände. Persistente Historisierung, automatische Baselineauswahl und Paketausführung gehören nicht zu diesem Vertrag. `WorkloadEquivalence` bleibt `UNPROVEN`; alle Ergebnisse bleiben partiell.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SsisExecutionBaseline] @Hilfe = 1;

-- Modell- und Capturetexte bleiben Strings, damit ihre exakten Bytes erhalten bleiben.
-- Für weitere Basisläufe enthält das Array entsprechend weitere getrennte Einträge.
DECLARE @Baselines nvarchar(max)=(
 SELECT @BaselineModels AS projectModelsJson,
        @BaselineCapture AS scopeSnapshotJson,
        CONVERT(varchar(36),@BaselineHandover) AS scopeHandoverId,
        CONVERT(varchar(20),@BaselineExecution) AS executionId
 FOR JSON PATH);

EXEC [monitor].[USP_SsisExecutionBaseline]
      @BaselineExecutionsJson=@Baselines,
      @CandidateProjectModelsJson=@CandidateModels,
      @CandidateScopeSnapshotJson=@CandidateCapture,
      @CandidateScopeHandoverId=@CandidateHandover,
      @CandidateExecutionId=@CandidateExecution,
      @MaxZeilen=200, @ResultSetArt='CONSOLE';
```

Jedes Arrayelement enthält genau die vier genannten Stringfelder. Ausführungskennungen sind positive kanonische Dezimalstrings ohne Vorzeichen oder führende Nullen. Sie müssen innerhalb der gesamten Kohorte einschließlich Kandidat verschieden sein. Übergabekennungen sind gültige GUIDs; zu jedem Eintrag muss der passende lokale Scopebeleg vorliegen. Das Einführungsbeispiel liefert einen deskriptiven Vergleich mit zu kleiner Basis für fachliche Hinweise. Mindestens fünf verwendbare Werte sind je Kennzahl erforderlich.

Quelle, Katalog-GUID, Projektkennung, Projekt-LSN, Archiv und Rootpaketdatei müssen übereinstimmen. Alle Modelltexte müssen bytegleich in UTF-16LE sein. Schon andere Leerzeichen führen zu `BASELINE_MODEL_EXPORT_DIFFERENT`. Unterschiedliche Quell- oder Projektversionen liefern `BASELINE_SOURCE_VERSION_DIFFERENT`; eine gesamte Kohorte wird abgelehnt. Die API qualifiziert keine semantische Gleichheit unterschiedlich serialisierter Exporte.

## Parameter und Eingabeformen

Jeder Eintrag nennt den SQL-Datentyp, den ausdrücklich bezeichneten Default und die tatsächlich verarbeitete Form. Ausgelassene Argumente verwenden den Signaturdefault. Unicode-JSON wird als nvarchar(max)-Variable oder T-SQL-Literal mit N-Präfix übergeben; ein Dateipfad wird nicht geöffnet. DATALENGTH misst SQL-UTF-16-Bytes. Die lokalen Scopebelege werden auf monitor.USP_SsisPackageModelAnalysis registriert; die Baselineprocedure fordert keine eigene Registrierung auf ihrem Objekt. Zum Empfangen eines OUTPUT-Werts wird am Aufruf eine passend typisierte Variable mit OUTPUT gebunden. Hilfe setzt nur @Json=NULL; die vier Status-/Fehler-OUTPUTs bleiben unverändert.

### @BaselineExecutionsJson

**Datentyp:** `nvarchar(max)`; **Default:** `NULL`. Äußeres JSON muss ein Array mit 1 bis 20 Einträgen sein. Jeder Eintrag ist ein JSON-Objekt mit genau vier case-sensitiven Schlüsseln; jeder der vier Werte ist ein JSON-String, nicht ein eingebettetes Objekt/Array: projectModelsJson (als String serialisierte vollständige Model-Set-JSON), scopeSnapshotJson (als String serialisiertes Scope-/Pipeline-Capture-JSON), scopeHandoverId (GUID-String zur lokal registrierten Handover-ID), executionId (positive kanonische Dezimalzeichenfolge). Die vier Namen sind vollständig, ohne Zusatzschlüssel; ihre Reihenfolge ist beliebig. Die beiden inneren JSON-Dokumente bleiben in ihren Stringwerten byte-/textgetreu erhalten. Jede Basisausführung wird anhand ihres Captures und des auf monitor.USP_SsisPackageModelAnalysis registrierten, dazu passenden lokalen Handover-Belegs unabhängig geprüft. executionId muss kanonisch dezimal sein: keine führenden Nullen, kein Pluszeichen, keine Leerzeichen, positive Ziffernfolge bis 9223372036854775807. Jeder Execution-ID-Wert muss von Kandidaten-ID und allen anderen Basis-IDs verschieden sein. Modelle/Captures sind gültiges JSON, pro Modell und Capture höchstens 16.777.216 DATALENGTH-Bytes (SQL-UTF-16). Gesamte Eingabegrenze: Summe DATALENGTH von BaselineExecutionsJson, CandidateProjectModelsJson und CandidateScopeSnapshotJson höchstens 67.108.864 Bytes (64 MiB, nvarchar UTF-16 Bytes, keine UTF-8-Dateigröße). Zusammengenommen höchstens 100.000 observations/events/componentPhases/pathTransfers-Quellzeilen, 400.000 materialisierte Kennzahlen und höchstens 400.000 Kennzahl-/Laufzellen; gemeinsames kooperatives Zeitbudget höchstens 60 Sekunden. NULL, Leerstring, Objekt statt äußerem Array, 0 oder mehr als 20 Einträge sowie falsche Transporttypen sind ungültig. projectModelsJson enthält ssis-project-model-set 1.0.0 mit rootPackageKey und packages (1 bis 16), einschließlich ssis-object-identities 1.2.0 und ssis-pipeline-identities 1.0.0; scopeSnapshotJson enthält ssis-execution-scopes 1.1.0 mit method SSISDB_CURRENT_PROJECT_PIPELINES_V1. Diese inneren Dokumente werden im äußeren JSON als korrekt maskierte JSON-Strings erhalten, nicht neu erzeugt oder als JSON-Objekte eingebettet. Der GUID-Beleg liegt auf dem Modellconsumer, nicht auf der Baselineprocedure. Einzelheiten entsprechen den separat erläuterten Kandidatenparametern und dem Modellvertrag.

### @CandidateProjectModelsJson

**Datentyp:** `nvarchar(max)`; **Default:** `NULL`. Als einzelne nvarchar(max)-Variable oder N'…'-Literal übergeben, nicht als Dateipfad. Erforderlich für die Kandidat-Seite. JSON-Objekt mit contract="ssis-project-model-set", version="1.0.0", rootPackageKey als String und packages als Array mit 1 bis 16 eindeutigen Paketen. Jedes Paket enthält packageKey und entryName als Strings, model als vollständiges Objekt mit contract="ssis-package-model" und version="1.0.0" sowie identities als Objekt mit contract="ssis-object-identities" und version="1.2.0". Für diesen Consumer müssen zusätzlich pipelineIdentities als Objekt mit contract="ssis-pipeline-identities" und version="1.0.0" vorhanden und an dieselben Paket-/Modellidentitäten gebunden sein. Der gemeinsame Consumer aktiviert Scope-, Pipelinekorrelations- und Pipeline-Diagnosepfade; dieses Argument ergänzt keine eigene Parser- oder Lineageauswertung. Das unveränderte Modellobjekt muss auf allen verglichenen Seiten bytegenau gleich sein: SHA-256 wird über die exakten nvarchar-UTF-16-Bytes gebildet; Neu-Serialisierung, geänderte Whitespace-/Property-Reihenfolge oder andere Bytes ändern den Exporthash. Höchstens 16.777.216 Bytes je Modell, gemessen mit SQL Server DATALENGTH(nvarchar), also UTF-16-Bytes und nicht UTF-8-Dateigröße. JSON-Objektschlüssel und Identitäten werden streng geprüft. NULL, Leerstring und ungültiges JSON sind unzulässig. Siehe den bestehenden SsisPackageModelAnalysis-Vertrag für vollständige Parser-/Modellregeln.

### @CandidateScopeSnapshotJson

**Datentyp:** `nvarchar(max)`; **Default:** `NULL`. Als einzelne nvarchar(max)-Variable oder N'…'-Literal übergeben. Erforderlich ist ein JSON-Objekt mit contract="ssis-execution-scopes", version="1.1.0", method="SSISDB_CURRENT_PROJECT_PIPELINES_V1", gebunden an project-model-set und passende pipelineIdentities; gültige Wurzel-/Ausführungsbindung umfasst execution als Objekt mit executionId, projectId, projectLsn, catalogDatabaseGuid, sourceBindingSha256 und packageFileName; archiveSha256 und modelSetSha256 liegen auf Wurzelebene (SHA-256 der exakten Kandidaten-Model-JSON-Bytes). Enthält observations- und events-Arrays sowie componentPhases- und pathTransfers-Arrays und genau die zwei pipelineSources-Einträge für componentPhases und pathTransfers; deren Statuswerte und Fehlernummern müssen dem Capturevertrag entsprechen. Alle Schlüssel, Namen, Pfade, IDs, Zeit-/Ergebniswerte und Quellgrenzen müssen die von 035–037 geprüften Formen erfüllen; höchstens 50.000 Einträge im Scope-/Pipeline-Capture. Der Transport muss bytegenau dem lokal registrierten Scope-Handover entsprechen; nicht neu serialisieren. Höchstens 16.777.216 Bytes je Capture, gemessen durch DATALENGTH(nvarchar) in SQL-UTF-16-Bytes. NULL, Leerstring und ungültiges JSON sind unzulässig. Vergleichsseiten werden unabhängig attestiert. Optional kann comparisonContext genau ein Objekt mit genau contract="ssis-comparison-context", version="1.0.0" und use32BitRuntime als JSON-Boolean enthalten; fehlt diese Zusatzinformation oder ist sie ungültig, bleibt der Capture nicht automatisch ungebunden, aber der Laufzeitkontext ist unbewiesen. Beide Seiten müssen dieselben exakten Export- und Quell-/Projektversionsfelder einschließlich archiveSha256 aufweisen.

### @CandidateScopeHandoverId

**Datentyp:** `uniqueidentifier`; **Default:** `NULL`. Als uniqueidentifier-Parameter im üblichen GUID-Format übergeben. Erforderliche UUID eines lokal auf monitor.USP_SsisPackageModelAnalysis registrierten SSIS_SCOPE_<UUID> Extended-Property-Handover; die Registrierung bindet die exakten UTF-16-Bytes des zugehörigen ProjectModelsJson und ScopeSnapshotJson und ist zeitlich gültig. Die UUID ist nur der lokale Belegschlüssel, kein JSON-Trustflag und keine selbst behauptete Attestation; eine frei erfundene oder auf einem anderen Objekt registrierte ID genügt nicht. Jede Seite wird unabhängig gegen den zu ihren Dokumentbytes passenden registrierten Beleg geprüft. Die Procedure verlangt keine gesonderte Ungleichheit der GUIDs; die Execution-IDs müssen verschieden sein. NULL ist ungültig. Der Belegname verwendet die GUID in Kleinschreibung. issuedUtc muss höchstens beim Analysebeginn liegen; expiresUtc danach und höchstens 24 Stunden nach issuedUtc. Es gibt keine Mindestgültigkeitsdauer. Als uniqueidentifier-Variable oder konvertierbares GUID-Literal der Form 00000000-0000-0000-0000-000000000000 übergeben; die Null-GUID ersetzt keinen registrierten Beleg.

### @CandidateExecutionId

**Datentyp:** `bigint`; **Default:** `NULL`. Einzelne positive SSISDB Execution-ID im bigint-Bereich 1 bis 9.223.372.036.854.775.807. Muss zum Kandidaten-Capture passen und von sämtlichen Basis-Execution-IDs verschieden sein. NULL, 0, negative Werte oder jede Wiederholung einer Basis-ID sind ungültig.

### @MinDurationDeltaMs

**Datentyp:** `bigint`; **Default:** `NULL`. Optionale nichtnegative Dauergrenze in Millisekunden (ganzzahlig, 0 bis 9.223.372.036.854.775.807). NULL deaktiviert die Dauergrenze. Für einen Dauerhinweis muss die Kandidatendauer strikt größer als Median der verwendbaren Basiswerte plus dieser Grenzwert sein; bei gesetzter Prozentgrenze muss zugleich auch diese strikt überschritten sein. Zeilenänderungshinweise sind unabhängig von beiden Dauergrenzen. Negative Werte sind ungültig. Sind beide Dauergrenzen NULL, werden keine Dauergrenzhinweise erzeugt; andere Hinweisarten bleiben davon unabhängig.

### @MinDurationDeltaPercent

**Datentyp:** `decimal(9,4)`; **Default:** `NULL`. Optionale nichtnegative Prozentgrenze als Zahl in Prozent relativer Zunahme ohne %-Zeichen, bis vier Dezimalstellen: 0.0000 bis 99999.9999 (10.0000 entspricht zehn Prozent; SQL-Typkonvertierung/Rundung geschieht vor Procedure). NULL deaktiviert die Prozentgrenze. Die relative Dauerabweichung wird strikt geprüft; Median 0 bedeutet unbekannte Prozentabweichung und erfüllt sie nicht. Wenn zusätzlich Millisekunden gesetzt sind, müssen beide Dauergrenzen überschritten sein. Zeilenänderungshinweise bleiben unabhängig. Sind beide Dauergrenzen NULL, werden keine Dauergrenzhinweise erzeugt; andere Hinweisarten bleiben davon unabhängig.

### @MaxZeilen

**Datentyp:** `int`; **Default:** `1000`. Maximale ausgegebene Zeilen je Resultgruppe, int. Zulässig sind positive Werte; NULL und 0 werden als unbegrenzte int-Obergrenze behandelt. Negative Werte sind ungültig. Die Grenze begrenzt Ausgabe, nicht die Kohorten-/Materialisierungslimits; abgeschnittene Ausgabe bleibt als partiell markiert. Der positive Wertebereich beträgt 1 bis 2147483647.

### @MaxDurationSeconds

**Datentyp:** `int`; **Default:** `30`. Gemeinsames kooperatives Zeitbudget für alle Basisläufe, Kandidat und Zusammenfassung, Sekunden; 1 bis 60. Ausgelassen bedeutet 30; explizites NULL ist ungültig. Bei überschrittener Frist wird keine Bindung behauptet und ein Zeitlimitgrund ausgegeben.

### @LockTimeoutMs

**Datentyp:** `int`; einzelner skalarer SQL-int-Wert in Millisekunden. **Default:** `0`; ausgelassen ergibt `0`. NULL oder Werte außerhalb 0 bis 60000 sind ungültig; Leertext kann vor Eintritt durch implizite SQL-Konvertierung zu `0` werden. Der SQL-Wert `0` bedeutet `NOWAIT`, positive Werte erlauben begrenztes Warten und `-1` für unbegrenztes Warten ist unzulässig. Die Procedure prüft den Bereich und übergibt den Wert für jede Captureanalyse an `InternalSsisExecutionMetrics`. Ihr eigenes `SET LOCK_TIMEOUT` läuft in einem separaten dynamischen `sp_executesql`-Batch; es begrenzt daher nicht die anschließenden direkten Kohorten- und Ausgabeanweisungen. `InternalSsisExecutionMetrics` führt ebenfalls ein dynamisches `SET` aus und übergibt den Wert an `USP_SsisPackageModelAnalysis` im Scope-Modus. Diese delegiert an `InternalSsisExecutionScopes`, das den Wert validiert und `SET LOCK_TIMEOUT` ebenfalls dynamisch ausführt; diese Einstellung begrenzt die anschließenden direkten Anweisungen des Scopes-Helpers nicht.

### @ResultSetArt

**Datentyp:** `varchar(16)`; **Default:** `CONSOLE`. Textauswahl nach Entfernen äußerer Leerzeichen und Großschreibung. Geschlossene Menge: CONSOLE (kompakte Bindingausgabe), RAW (separate rohe Resultsets), TABLE (in lokale Zieltabellen schreiben), NONE (keine Resultsets). NULL/andere Werte sind ungültig. Leerwert ist ungültig; das Trim entfernt U+0020-Leerzeichen, keine beliebigen Whitespacezeichen. JSON ist kein Ausgabeartcode; verwenden Sie @JsonErzeugen.

### @ResultTablesJson

**Datentyp:** `nvarchar(max)`; **Default:** `NULL`. Nur bei TABLE zulässig und erforderlich: nichtleeres JSON-Objekt aus case-sensitiven Gruppennamen auf lokale Temp-Tabellennamen als Stringwerte, z. B. {"baselineBinding":"#SeedBinding"}. Zulässige Gruppen: baselineBinding (Kandidaten-/Kohortenbindung und Status), executionCohort (eine Zeile pro Basis-/Kandidatenlauf mit Rolle und Laufabdeckung), metricBaseline (Kennzahl je Vergleichsschlüssel mit Median/Min/Max, gültiger Basiszahl und Kandidatendelta), baselineFindings (versionierte INFO-Beobachtungshinweise), baselineCoverage (Quell-, Lauf-, Einschluss-/Ausschluss- und Ausgabedeckung). Jede beliebige nichtleere Teilmenge der fünf Gruppen ist zulässig. Jedes Ziel muss eine eindeutige bereits vorhandene, leere lokale #Temp-Tabelle sein (keine globale ##, kein reserviertes #Monitor-Präfix, höchstens 116 Zeichen) mit genau einer Seed-Spalte. Unbekannte Schlüssel, doppelte Namen/Ziele, Null-/Leerwerte oder ungültige Ziele werden vor fachlicher Verarbeitung abgewiesen. Außerhalb TABLE muss NULL übergeben werden. Keine gesonderte JSON-Größengrenze im Consumer belegt. Doppelte Zielnamen und das reservierte Präfix #Monitor werden ohne Beachtung der Großschreibung geprüft.

### @JsonErzeugen

**Datentyp:** `bit`; **Default:** `0`. 0 deaktiviert JSON-OUTPUT, 1 erzeugt ein JSON-Objekt in @Json; NULL ist im normalen Pfad ungültig. JSON hat meta.schemaVersion=1, meta.baselineSchemaVersion=1 und meta.isPartial=true sowie top-level Arrays baselineBinding, executionCohort, metricBaseline, baselineFindings, baselineCoverage. Der aktuelle SQL-Meta-Block enthält kein statusCode; Status wird über @StatusCodeOut und Binding-/Coverage-Daten geliefert. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @Json

**Datentyp:** `nvarchar(max) OUTPUT`; **Default:** `NULL OUTPUT`. OUTPUT-Textparameter vom Typ nvarchar(max), mit OUTPUT an eine entsprechende Variable binden. Beim Eintritt wird @Json auf NULL gesetzt. Bei @JsonErzeugen=1 enthält es meta und echte JSON-Arrays für die fünf Gruppen, mit JSON-null-Werten statt Stringrepräsentation und [] bei leeren Gruppen. Ohne Erzeugung beziehungsweise im Hilfezweig bleibt es NULL.

### @PrintMeldungen

**Datentyp:** `bit`; **Default:** `1`. Wird im Procedure-Quelltext weder gelesen noch validiert; 0, 1 oder NULL ändern das Verhalten nicht. Keine andere Wirkung behaupten. Consoleausgabe richtet sich nach @ResultSetArt. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @Hilfe

**Datentyp:** `bit`; **Default:** `0`. 1 druckt die eingebaute Hilfe und kehrt vor Parameter-/Transportvalidierung, lokaler Handoverprüfung und Auswertung zurück; 0 folgt dem normalen Pfad. NULL erfüllt die IF-Bedingung nicht und verhält sich wie ausgeschaltet. Der JSON-OUTPUT wird vorher auf NULL gesetzt, die anderen OUTPUT-Werte bleiben im Hilfezweig unverändert. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @StatusCodeOut

**Datentyp:** `varchar(40) OUTPUT`; **Default:** `NULL OUTPUT`. Als varchar(40)-Variable mit OUTPUT binden; Eingangswert hat keine Steuerwirkung. Geschlossene globale Ergebniswerte: BASELINE_CAPTURE_BOUND (alle expliziten Basis-Captures und Kandidat sind unabhängig gebunden, gleicher exakter Modell-Export und gleiche geprüfte Quell-/Projektversion; keine Vollständigkeits-/Kausalitätsaussage), BASELINE_BINDING_UNPROVEN (mindestens eine Bindung oder Eingabeverarbeitung blieb unbelegt) und INVALID_PARAMETER (ungültige Steuerwerte oder Kombination). Im aktuellen JSON meta ist kein statusCode vorhanden; maßgeblicher Gesamtstatus steht in diesem OUTPUT und in Bindungs-/Coverage-Arrays. Hilfezweig lässt den Wert unverändert; ungefangene Fehler können Zuweisung umgehen.

### @IsPartialOut

**Datentyp:** `bit OUTPUT`; **Default:** `NULL OUTPUT`. Mit bit-Variable und OUTPUT binden. Nach normaler Verarbeitung immer 1, da Scopeauswertung und Beobachtungsabdeckung partiell sind; Kohorten-/Kennzahl-/Quellenabdeckung erläutert Einschränkungen. Hilfezweig belässt den Eingangswert; ungefangene Fehler können Zuweisung umgehen.

### @ErrorNumberOut

**Datentyp:** `int OUTPUT`; **Default:** `NULL OUTPUT`. Mit int-Variable und OUTPUT binden. NULL bei keinem abgefangenen fachlichen Fehler; sonst SQL-Fehlernummer der zurückgehaltenen Eingabe-/Bindungs-/Grenzverletzung. Ungefangene Ausnahmen und geworfene TABLE-Mappingfehler können die Zuweisung umgehen; im Hilfezweig keine Zuweisung.

### @ErrorMessageOut

**Datentyp:** `nvarchar(2048) OUTPUT`; **Default:** `NULL OUTPUT`. Mit nvarchar(2048)-Variable und OUTPUT binden. Bei abgefangenem Fehler ein kurzer Reason-Code, sonst NULL; enthält nicht notwendigerweise ausführliche SQL-Fehlermeldung. Hilfezweig unverändert; ungefangene Ausnahmen können Zuweisung umgehen. nvarchar(2048) umfasst höchstens 2048 UTF-16-Codeeinheiten.

Die [vollständigen Modell- und Scopeformen](USP_SsisPackageModelAnalysis.md#parameter-und-eingabeformen) erläutern die gemeinsamen JSON-Objekte, Pipelineidentitäten und lokalen Herkunftsbindungen. Die hier geltenden zusätzlichen Vergleichs-/Kohortenbedingungen bleiben maßgeblich.

## Hilfe ohne Quellenprüfung

Alle vier Aufrufe kehren vor Capture- und Handoverprüfung zurück. Sie führen kein Paket aus und starten keine Runtime.

```sql
EXEC [monitor].[USP_SsisExecutionBaseline] @Hilfe=1;

EXEC [monitor].[USP_SsisExecutionBaseline] @ResultSetArt='NONE', @Hilfe=1;

DECLARE @HelpJson nvarchar(max)=N'vorbelegt';
EXEC [monitor].[USP_SsisExecutionBaseline] @Hilfe=1, @JsonErzeugen=1, @Json=@HelpJson OUTPUT;
SELECT @HelpJson AS HelpJson;

DECLARE @Code varchar(40)='CALLER', @Partial bit=0, @Error int=0;
EXEC [monitor].[USP_SsisExecutionBaseline] @Hilfe=1, @StatusCodeOut=@Code OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT;
SELECT @Code AS StatusCodeOut, @Partial AS IsPartialOut, @Error AS ErrorNumberOut;
```

## Resultsets und Leserichtung

RAW, TABLE und JSON verwenden dieselben fünf nativen Gruppen in Schemaversion 1. CONSOLE liefert eine Bindungsübersicht; NONE liefert keine fachlichen Resultsets. JSON entsteht mit `@JsonErzeugen=1` über `@Json OUTPUT`. TABLE verwendet lokale, vom Caller erstellte Temp-Tabellen und `@ResultTablesJson`. Fehlerhafte Zuordnungen werfen Frameworkfehler 51011.

| Gruppe | Bedeutung einer Zeile |
|---|---|
| `baselineBinding` | Kohortenbindung, Kandidat, Zahl der Eingabe- und analysierten Läufe, Projekt-/Exportbindung und Mindestzahl für Hinweise. |
| `executionCohort` | Ein expliziter Lauf mit Rolle, Abschlussstatus, Logging, Bitness, Kontext sowie Zahl einbezogener und ausgeschlossener Kennzahlen. Ordinal 0 bezeichnet den Kandidaten. |
| `metricBaseline` | Eine Modell-/Aufrufposition und numerische Kennzahl mit verwendbarer Laufzahl, Median, Minimum, Maximum, Spannweite und Kandidatendelta. |
| `baselineFindings` | Ein versionierter INFO-Hinweis oder eine ausdrückliche Evidenzgrenze. |
| `baselineCoverage` | Ein Ein-/Ausschluss je Lauf und Kennzahl, Quellenbeleg oder Kohortenübersicht mit Ausgabekürzung. |

Lesen Sie zuerst Binding, danach Kohorte und Coverage und anschließend die Statistik. `AnalyzedExecutionCount` zählt die erfolgreich zurückgegebenen Einzelanalysen; jeder Eingabecapture wird einmal analysiert. Die Coverage nennt bei Kennzahlen Quellen-ID und beobachteten Wert. Bei mehrdeutigen Beobachtungen bleiben beide NULL. Quellen-IDs werden ausschließlich innerhalb des jeweiligen Captures ausgewertet.

## Eine Zeile bedeutet

`ComparisonKeySha256` bindet Objektart, Paket, Modellobjekt, Flow, qualifizierten Aufrufpfad, Phase und Kennzahl. Native Statistikkennungen bilden keinen laufübergreifenden Schlüssel. Schleifen und unterschiedliche Kindpaketaufrufe bleiben getrennt. Pfad- und Phasentext werden ordinal einschließlich nachlaufender Leerzeichen unterschieden.

Die Statistik umfasst Flowdauer, Phasenintervallsumme, längstes Intervall, Phasenspannweite und Intervallanzahl sowie Pfadzeilen und Transferanzahl. Statuswerte werden nicht gemittelt; der Abschlussstatus steht in der Laufkohorte. Phasensummen sind keine CPU-Zeit, und Pfadzähler ergeben keine globale Paketzeilenzahl. Die Portrolle stammt unverändert aus dem Toolbelt-Modell.

## So lesen

Jede Kennzahl erhält ihre eigene verwendbare Basiszahl `ValidBaselineCount`. Einbezogen werden nur eindeutige, bekannte und quellenqualifizierte Beobachtungen bei gleichem bekannten Logginggrad 1, 2 oder 3, gleicher attestierter Bitness und erfolgreichem Abschluss von Basis und Kandidat. Dauerwerte verlangen zusätzlich dasselbe bekannte beobachtete Pfadzeilenset innerhalb der konkreten Flowinstanz. Diese Einschränkung kann die verwendbare Laufzahl je Kennzahl verändern.

`MedianValue`, `MinValue`, `MaxValue` und `SpreadValue` beschreiben ausschließlich einbezogene Basiswerte. Bei einer geraden Zahl ist der Median das exakte Mittel der beiden mittleren Werte einschließlich halber Einheiten. `SpreadValue` ist Maximum minus Minimum. Die Berechnung verwendet keine Gleitkommaarithmetik. Fehlende Beobachtungen sind unbekannt und werden nicht zu null ergänzt.

`DeltaValue` ist Kandidat minus Median. `DeltaPercent` verwendet den Median als Nenner und wird auf sechs Nachkommastellen gerundet; bei Median null bleibt der Prozentwert NULL. Strikte Grenzwerte werden unabhängig von der Anzeigerundung geprüft. Bei keinem verwendbaren Basiswert bleiben Statistik und Deltas NULL. Bei einem unbekannten Kandidaten kann die deskriptive Basisstatistik weiterhin vorliegen, das Kandidatendelta bleibt NULL.

`COMPARABLE_OBSERVATION` verlangt mindestens fünf verwendbare Basiswerte und einen verwendbaren Kandidaten. `INSUFFICIENT_BASELINE_COUNT` erlaubt deskriptive Statistik und Deltas bei weniger als fünf Werten, erzeugt aber keinen fachlichen Grenzwerthinweis. `NO_BASELINE_OBSERVATIONS` und `CANDIDATE_EVIDENCE_LIMITED` benennen die jeweilige Grenze. Die Ausschlussgründe stehen je Lauf und Kennzahl in Coverage; fehlendes Logging, Bitness, Quellenzugriff, Mehrdeutigkeit und unbekannte Werte werden nicht ergänzt.

## Warum kann das problematisch sein?

Eine vom Anwender ausgewählte kleine Kohorte kann ungeeignet oder verzerrt sein. Eine Mindestzahl von fünf belegt keine statistische Stabilität. Unterschiedliche Loggingstufen verändern Sichtbarkeit und Eigenlast; Fehler und Abbrüche können vor den ersten Statistikbelegen liegen. Ein geändertes beobachtetes Volumen verhindert belastbare Dauerhinweise für diese Instanz.

## Wann ist es kein Problem?

Eine höhere beobachtete Dauer oder ein anderer Pfadzähler kann beabsichtigte Verarbeitung beschreiben. Ein INFO-Hinweis verlangt eine fachliche Gegenprobe. Die API verändert weder Logging noch Paketstatus und gibt keine automatische Optimierungs-, Wiederholungs- oder Abbruchaktion frei.

## Beispiele und Gegenbeispiele

`@MinDurationDeltaMs` und `@MinDurationDeltaPercent` sind optionale nichtnegative Grenzen. `SSIS_BASELINE_DURATION_THRESHOLD_EXCEEDED` verlangt mindestens fünf verwendbare Basiswerte, einen verwendbaren Kandidaten, eine positive Daueränderung und striktes Überschreiten jeder gesetzten Grenze. Ohne Grenzen entsteht kein Dauerhinweis. Ein Median null kann eine alleinige absolute Grenze erfüllen, aber keine relative Grenze.

`SSIS_BASELINE_OBSERVED_ROWS_CHANGED` beschreibt einen vom Median verschiedenen bekannten Pfadzähler ab fünf verwendbaren Basiswerten. Die Regel verwendet die explizite Bedingung Delta ungleich null und behauptet keine Volumenregression. `SSIS_BASELINE_EVIDENCE_LIMITED` meldet eine begrenzte Bindung, ausgeschlossene Läufe oder Kennzahlen und zu kleine verwendbare Mengen. Alle Regeln tragen Version 1.0.0 und Severity INFO.

## Leere oder partielle Ausgabe

Ein ungültiger Capture, doppelte Ausführungskennungen oder eine abweichende Modell-/Quellversion verhindern die gesamte Kohortenbindung. Die Kennzahlengruppe bleibt leer; Binding und Coverage nennen die Grenze. Alte Captures ohne optionalen Vergleichskontext bleiben für die Einzelanalyse gültig, liefern hier jedoch `RUNTIME_CONTEXT_UNPROVEN`.

`@MaxZeilen` begrenzt jede Gruppe nach der Berechnung; 0 und NULL bedeuten ungekürzt. Negative Werte sind ungültig. `baselineBinding.MetricCount` und die Kohortenzähler beschreiben das ungekürzte Set. Coverage meldet eine Kürzung ausdrücklich. Ein referenzierter Quellenbeleg kann außerhalb der ausgegebenen Zeilen liegen.

## Eigenlast und Grenzen

Die gesamte Eingabe ist auf 64 MiB begrenzt, jeder Modell- und Capturetext zusätzlich auf 16 MiB. Je Capture gelten die bestehenden 50000 Quellbelege und 200000 normalisierten Kennzahlen. Die gesamte Kohorte erlaubt höchstens 100000 Quellzeilen, 400000 Kennzahlen und 400000 Kombinationen aus Lauf und unterschiedlicher Kennzahl. Damit wird auch die Darstellung fehlender Beobachtungen begrenzt. Die Ausgabegrenze senkt den Validierungsaufwand nicht.

Das gemeinsame kooperative Zeitbudget beträgt standardmäßig 30, höchstens 60 Sekunden. Jeder Eingabecapture wird einmal durch den gemeinsamen nativen Kennzahlconsumer geprüft. JSON, lokale Temp-Tabellen, Hashes, Aufrufzuordnung und Sortierungen bestimmen die Eigenlast; das Budget ist keine harte CPU- oder Speichergrenze. Beginnen Sie mit einer kleinen expliziten Kohorte und begrenzter Ausgabe.

Die Procedure liest keine SSISDB und öffnet keine externe Verbindung. EXECUTE und sichtbare gültige lokale Scopebelege sind erforderlich. Geschrieben werden eigene Temp-Objekte und explizite TABLE-Ziele. Locktimeout und XACT_ABORT des Callers werden wiederhergestellt. Eine fehlende oder abgelehnte Herkunft wird nicht durch zusätzliche Berechtigungen oder automatische Infrastrukturänderungen repariert.

## Technische Vertiefung

### Leitfrage

Welche Kennzahlen des Kandidaten lassen sich mit mindestens fünf verwendbaren Beobachtungen derselben gebundenen Modellrevision vergleichen?

### Technischer Hintergrund

`InternalSsisExecutionMetrics` validiert und projiziert jeden Capture für Paarvergleich und Baseline. Der bestehende Modell-/Scopeconsumer übernimmt Herkunft, Version, Aufrufauflösung und Diagnoseaggregation. Die Baseline bildet daraus eine endliche explizite Kohorte; sie ergänzt keinen Parser und keine Lineageimplementierung.

### Datenkette

Toolbelt exportiert das Modell. Der Katalogadapter nimmt jeden Lauf getrennt auf und registriert den hashgebundenen lokalen Scopebeleg. Analyze prüft jeden Capture einmal, bildet gemeinsame Positionsschlüssel und bewertet die Einbeziehbarkeit je Kennzahl.

### Source Select

Kein einzelnes Grundselect bildet die Mehrlaufstatistik ab. **Wichtig für die Eigenlast:** Alle Eingabecaptures werden vor der Ausgabekürzung validiert. Die Statistik verbindet ausschließlich aufgelöste Modell-/Aufrufschlüssel; Quellen-IDs bleiben lauflokal.

### Zeit- und Scope-Modell

Die Captures gelten zu ihren Aufnahmezeitpunkten und innerhalb der lokalen Attestgültigkeit. Projekt-LSN und Archivbindung verhindern die Vermischung verschiedener Revisionen. Die explizite Kohorte ist keine persistent verwaltete Zeitreihe.

### Bewertung und Gegenprobe

Prüfen Sie Ausschlüsse und verwendbare Laufzahl für genau die betroffene Kennzahl. Vergleichen Sie ausgewählte Paare mit der unveränderten [Paar-API](USP_SsisExecutionComparison.md) und prüfen Sie die Einzelbelege. Die fachlichen Eingaben und Ressourcenbedingungen müssen außerhalb dieses Vertrags beurteilt werden.

### Typische Fehlinterpretation

Ein positiver Abstand zum Median beweist keine softwarebedingte Regression. Gleiche Iterationsnummern können unterschiedliche Eingaben enthalten; fünf Läufe garantieren keine belastbare Verteilung.

### Folgeanalyse

Die [Einzelanalyse](USP_SsisPackageModelAnalysis.md) zeigt Scopes, Phasen, Transfers und Herkunft. Die [Kataloganalyse](USP_SsisCatalogExecutionAnalysis.md) ergänzt strukturierte Metadaten eines konkreten Laufs.

## Primärquellen

- [Austauschvertrag](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)
- [Kanonische Implementierung](../../../Code/10_SSIS/060_USP_SsisExecutionBaseline.sql)
- [Gemeinsamer Kennzahlconsumer](../../../Code/10_SSIS/045_InternalSsisExecutionMetrics.sql)
- [Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv)

[Technische Detailbeschreibung](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

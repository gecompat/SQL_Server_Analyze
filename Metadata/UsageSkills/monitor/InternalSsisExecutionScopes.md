---
skill_format_version: "1.0.0"
name: "monitor.InternalSsisExecutionScopes"
schema_name: "monitor"
object_name: "InternalSsisExecutionScopes"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Der Consumer validiert lokal attestierte SSIS-Paketsätze und ordnet gebundene Statistik- und Ereignisbeobachtungen Paketaufrufen und Handlerkörpern zu."
source_path: "Code/10_SSIS/035_InternalSsisExecutionScopes.sql"
---

# monitor.InternalSsisExecutionScopes

## Zweck und Einsatz

Der Consumer validiert lokal attestierte SSIS-Paketsätze und ordnet gebundene Statistik- und Ereignisbeobachtungen Paketaufrufen und Handlerkörpern zu. Pipelinekorrelation und Diagnose sind optionale Erweiterungen.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalSsisExecutionScopes]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `sys.sp_executesql`, `monitor.InternalPrepareResultTables`, `monitor.USP_SsisPackageModelAnalysis`, `[monitor].[SsisHandoverReceipt]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @IncludePipelineCorrelation | bit | nein | 0 |
| @Models | nvarchar(max) | ja | kein Default |
| @Capture | nvarchar(max) | ja | kein Default |
| @Handover | uniqueidentifier | ja | kein Default |
| @ExecutionId | bigint | ja | kein Default |
| @MaxZeilen | int | nein | 1000 |
| @MaxDurationSeconds | int | nein | 30 |
| @LockTimeoutMs | int | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) OUTPUT | nein | NULL |
| @StatusCodeOut | varchar(40) OUTPUT | nein | NULL |
| @IsPartialOut | bit OUTPUT | nein | NULL |
| @ErrorNumberOut | int OUTPUT | nein | NULL |
| @ErrorMessageOut | nvarchar(2048) OUTPUT | nein | NULL |
| @IncludePipelineDiagnostics | bit | nein | 0 |
| @PipelinePhaseThresholdMs | bigint | nein | NULL |
| @Hilfe | bit | nein | 0 |

**@IncludePipelineCorrelation:** @IncludePipelineCorrelation: bit; Default: 0. Skalarer Schalter: 0 verwendet Scope-Capture 1.0.0 und SSISDB_CURRENT_PROJECT_SCOPES_V1; 1 verlangt 1.1.0 und SSISDB_CURRENT_PROJECT_PIPELINES_V1 samt Pipelineidentitäten und -quellen. 1 ergänzt die unten beschriebenen vier Pipelinegruppen. Auslassen verwendet 0; NULL ist ungültig. SQL Server konvertiert numerische Werte ungleich 0 zu 1 und leeren Text vor dem Procedure-Eintritt zu 0.

**@Models:** @Models: nvarchar(max); Default: keiner, Pflichtargument. Erwartet wird ein JSON-Objekt als Unicode-Text, kein Dateipfad: contract="ssis-project-model-set", version="1.0.0", rootPackageKey und ein packages-Array mit 1–16 Einträgen. Jeder Eintrag enthält packageKey (eindeutige alphanumerische Kennung, höchstens 16 Zeichen), entryName (exakter eindeutiger Archivdateiname ohne /, \ oder :, 6–260 Zeichen), model als eingebettetes ssis-package-model 1.0.0 und identities als ssis-object-identities 1.2.0 mit passendem packageSha256 und objects-Array. rootPackageKey bezeichnet ein vorhandenes Paket. Die Identitäten binden nodeId, parentId, nodeKind (PACKAGE: Paket; EXECUTABLE: ausführbarer Knoten), nullable dtsId/packagePath, scopeKind (PACKAGE: Paketwurzel; CALL: Kindpaketaufruf; LOOP: Schleife; HANDLER: Ereignishandler; EXECUTABLE: sonstiger ausführbarer Scope), steps, profileStatus (SUPPORTED: qualifiziertes Profil; UNQUALIFIED: unqualifiziert), nullable eventName/callTarget an die Modellknoten. steps enthält höchstens 32 Objekte mit genau text (nichtleerer String, 2–8000 SQL-Bytes) und counter (JSON-Boolean true oder false). Qualifizierte Handler erlauben OnPreExecute (vor Ausführung), OnPostExecute (nach Ausführung) und OnError (Fehlerereignis); das beweist keinen konkreten Auslöser. Bei Pipelinekorrelation ist zusätzlich pipelineIdentities je Paket erforderlich. Höchstens 16 MiB nach DATALENGTH. Auslassen scheitert an der Pflichtsignatur; NULL, Leertext und ungültiges JSON ergeben keine belegte Bindung. Weitere eingebettete Felder beschreibt das Austauschschema.

**@Capture:** @Capture: nvarchar(max); Default: keiner, Pflichtargument. Erwartet wird ein JSON-Objekt als Unicode-Text mit contract="ssis-execution-scopes"; ohne Pipelinekorrelation gelten version="1.0.0" und method="SSISDB_CURRENT_PROJECT_SCOPES_V1", mit Pipelinekorrelation 1.1.0 und SSISDB_CURRENT_PROJECT_PIPELINES_V1. execution enthält die passende positive executionId, den exakten Root-packageFileName, positive projectId/projectLsn, catalogDatabaseGuid, sourceBindingSha256 sowie optionale loggingLevel/executionStatus; die Wurzel enthält archiveSha256, den SHA-256 der exakten @Models-Bytes als modelSetSha256 und die Arrays observations und events. Beobachtungen enthalten passende executionId, positive statisticsId/executableId, packageName, packagePath, executionPath und nullable executableGuid, startTime, endTime, durationMs, executionResult. Ereignisse enthalten positive eventMessageId, Paket/Pfade sowie nullable executableGuid, eventName, messageCode, messageTime. Bei Pipelinekorrelation kommen componentPhases, pathTransfers und ein pipelineSources-Array mit genau je einem Eintrag für componentPhases und pathTransfers hinzu; die öffentliche Scope-Referenz beschreibt deren Feldform. Für Pipelinequellen gelten source=componentPhases oder pathTransfers und status=AVAILABLE (vorhanden), AVAILABLE_EMPTY (vorhanden, leer), UNAVAILABLE (nicht verfügbar) oder DENIED_PERMISSION (Berechtigung fehlt); errorNumber ist bei den letzten beiden positiv, sonst NULL. Höchstens 16 MiB je Dokument; zusammen höchstens 50000 Statistik-/Ereigniszeilen und bei Pipelinekorrelation einschließlich Phasen-/Transferzeilen. Doppelte Objektschlüssel und Verschachtelung jenseits der Tiefe 32 werden verworfen; unbekannte Schlüssel sind nicht pauschal verboten. Optionale, mit TRY_CONVERT projizierte Werte können bei Konvertierungsfehler NULL werden. Auslassen scheitert an der Pflichtsignatur; NULL, Leertext und ungültiges JSON ergeben keine belegte Bindung. Fehler innerhalb der optionalen Pipelinekorrelation oder -diagnose werden in deren Coverage-Gruppen dargestellt und ändern nicht zwangsläufig den Basisstatus oder die bereits erzeugten Grundgruppen.

**@Handover:** @Handover: uniqueidentifier; Default: keiner, Pflichtargument. Skalarer UUID-Wert, etwa eine entsprechend typisierte Variable oder konvertierbare UUID-Zeichenfolge. Er wählt einen Beleg der Art 3 in [monitor].[SsisHandoverReceipt]. Der lokale Beleg enthält genau contract="ssis-local-scope-handover", version="1.0.0", issuedUtc, expiresUtc, modelSetSha256, captureSha256; er muss aktuell gültig sein, höchstens 24 Stunden gelten und die exakten UTF-16-Dokumentbytes binden. Die Prüfung liest mit READCOMMITTEDLOCK. Auslassen scheitert an der Pflichtsignatur; NULL oder fehlender/ungültiger Beleg lässt die Bindung unbelegt. Leertext ist keine UUID und kann bereits bei der SQL-Parameterkonvertierung scheitern. Eine beliebige UUID oder ein JSON-Vertrauensfeld ersetzt den lokalen Beleg nicht.

**@ExecutionId:** @ExecutionId: bigint; Default: keiner, Pflichtargument. Skalarer ganzzahliger Wert von 1 bis 9223372036854775807, gleich der Execution-ID im Capture. Auslassen scheitert an der Pflichtsignatur; NULL und Werte unter 1 sind ungültig. Leerer Text kann vor dem Eintritt nach 0 konvertiert werden und ist dann ungültig.

**@MaxZeilen:** @MaxZeilen: int; Default: 1000. Skalarer ganzzahliger Wert. Positive Werte bis 2147483647 begrenzen jede Ausgabegruppe nach der Analyse. NULL und 0 setzen intern 2147483647 und damit keine zusätzliche kleinere Ausgabegrenze; negative Werte sind ungültig. Auslassen verwendet 1000. Leerer Text kann vor Eintritt nach 0 konvertiert werden und wirkt dann wie 0. Die Coverage-Zahlen entstehen vor der Kürzung.

**@MaxDurationSeconds:** @MaxDurationSeconds: int; Default: 30. Skalarer ganzzahliger Sekundenwert von 1 bis 60; Auslassen verwendet 30. NULL und Werte außerhalb dieses Bereichs sind ungültig. Leerer Text kann nach 0 konvertiert werden und ist dann ungültig. Das gemeinsame Zeitbudget ist kooperativ; die Deadline wird vor der ersten TRY-Strecke berechnet, weshalb ein Fehler dabei nicht als regulärer Parameterstatus zugesagt wird.

**@LockTimeoutMs:** @LockTimeoutMs: int; Default: 0. Skalarer ganzzahliger Millisekundenwert von 0 bis 60000. 0 setzt LOCK_TIMEOUT 0 und bedeutet für eine Sperre NOWAIT; positive Werte setzen den entsprechenden Millisekundenwert. Auslassen verwendet 0; NULL und Werte außerhalb sind ungültig. Leerer Text kann nach 0 konvertiert werden. Der Consumer führt SET LOCK_TIMEOUT in einem separaten dynamischen Batch aus; dessen Einstellung endet bei Rückkehr aus sp_executesql und bestimmt keine nachfolgenden direkten Anweisungen. Die Wiederherstellungsbatches führen SET LOCK_TIMEOUT auf den erreichten normalen und abschließenden CATCH-Wegen erneut mit dem vorherigen Sitzungswert aus.

**@ResultSetArt:** @ResultSetArt: varchar(16); Default: 'CONSOLE'. Skalarer Moduscode. Vollständige Wertemenge: CONSOLE gibt die Bindungsübersicht über den Console-Helper aus; RAW gibt jede freigeschaltete typisierte Gruppe als Resultset aus; TABLE schreibt ausdrücklich zugeordnete Gruppen in lokale Temp-Tabellen; NONE unterdrückt diese Ausgaben. Auslassen verwendet CONSOLE. Der Wert wird mit UPPER normalisiert, ohne ausdrückliches Trimmen; der anschließende SQL-Stringvergleich folgt seiner Padding-Semantik. NULL, Leertext und Werte, die keinem Code entsprechen, sind ungültig. JSON-Erzeugung ist davon unabhängig.

**@ResultTablesJson:** @ResultTablesJson: nvarchar(max); Default: NULL. Bei CONSOLE/RAW/NONE muss NULL vorliegen. TABLE verlangt ein nichtleeres JSON-Objekt, zum Beispiel {"scopeBinding":"#ScopeBinding"}; Schlüssel sind exakt die unten taxativ beschriebenen freigeschalteten Gruppennamen, Stringwerte unqualifizierte rohe lokale #Temp-Namen. Eine Teilmenge genügt; nicht zugeordnete Gruppen werden nicht geschrieben. Kein ##, kein #Monitor-Präfix (CI), höchstens 116 Zeichen nach sysname-Konvertierung; keine Klammer-/Schemaform und kein Trimmen. Schlüssel werden nach sysname-Konvertierung binär verglichen; doppelte Schlüssel und CI-gleiche Ziele sind ungültig. Ziele müssen vorhanden, leer und mit genau einer Seed-Spalte angelegt sein. Die Prüfung verändert vorübergehend das Zielschema durch eine Markerspalte; es gibt keine atomare Rücknahmezusage. Auslassen verwendet NULL; NULL, Leertext, {} und Arrays sind im TABLE-Modus ungültig.

**@JsonErzeugen:** @JsonErzeugen: bit; Default: 0. Skalarer Schalter: 0 erzeugt kein JSON und lässt den eingehenden @Json-Wert unverändert; 1 erzeugt Metadaten und die begrenzten Gruppenarrays unabhängig vom Ausgabemodus. Auslassen verwendet 0; NULL ist ungültig. Numerische Werte ungleich 0 konvertiert SQL Server nach 1, leeren Text nach 0.

**@Json:** @Json: nvarchar(max) OUTPUT; Default: NULL. Skalarer Unicode-Ausgabespeicher; zum Empfang eine passende Variable mit OUTPUT binden, ohne OUTPUT kann ein typisierter Wert übergeben und die Ausgabe verworfen werden. Auslassen verwendet NULL. Bei @JsonErzeugen=1 wird der Eingangswert einschließlich NULL, Leertext oder sonstigem Inhalt durch ein Objekt mit meta.schemaVersion=1, meta.executionScopesSchemaVersion=1, meta.isPartial=true und den freigeschalteten Arrays ersetzt; Pipelineopt-ins ergänzen ihre Schemaversion jeweils 1. Bei @JsonErzeugen=0 bleibt der Eingangswert einschließlich NULL/Leertext unverändert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@StatusCodeOut:** @StatusCodeOut: varchar(40) OUTPUT; Default: NULL. Skalarer Statusausgang; passende Variable mit OUTPUT bindet die Ausgabe, ein typisierter Wert ohne OUTPUT verwirft sie. Auslassen verwendet NULL. Bei regulärer Ausgabe werden eingehende NULL-, Leertext- oder sonstige Werte überschrieben: SCOPE_CAPTURE_BOUND bedeutet Capturebindung hergestellt, SCOPE_BINDING_UNPROVEN Bindung unbelegt beziehungsweise verworfene Bindungseingabe, INVALID_PARAMETER ungültiger Parameterwert oder Kombination. Außerhalb regulärer Rückgaben ist kein aktualisierter Status garantiert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@IsPartialOut:** @IsPartialOut: bit OUTPUT; Default: NULL. Skalarer Flag-Ausgang; zum Empfang eine passende Variable mit OUTPUT binden, sonst wird die Ausgabe verworfen. Auslassen verwendet NULL. Bei regulärer Ausgabe wird jeder konvertierbare Eingangswert einschließlich NULL oder nach 0 konvertiertem Leertext durch 1 ersetzt: Das Ergebnis ist partiell. 0 wird regulär nicht ausgegeben. Fehler vor der Ausgabe garantieren keine Aktualisierung. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorNumberOut:** @ErrorNumberOut: int OUTPUT; Default: NULL. Skalarer Fehlernummernausgang; zum Empfang eine passende Variable mit OUTPUT binden, sonst wird die Ausgabe verworfen. Auslassen verwendet NULL. Bei regulärer Ausgabe werden Eingangswerte einschließlich NULL oder nach 0 konvertiertem Leertext überschrieben: NULL bedeutet kein erfasster Bindungsfehler; sonst steht hier die SQL-Fehlernummer, bei eigenen Bindungsprüfungen 57900. Native Fehlernummern sind keine geschlossene Menge. Neu geworfene Ausgabefehler werden nicht als regulärer Ausgang zugesagt. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessageOut:** @ErrorMessageOut: nvarchar(2048) OUTPUT; Default: NULL. Skalarer Unicode-Textausgang; passende Variable mit OUTPUT bindet die Ausgabe, sonst wird sie verworfen. Auslassen verwendet NULL. Bei regulärer Ausgabe werden eingehende NULL-, Leertext- oder andere Werte überschrieben: NULL bedeutet kein erfasster Grund; bei Fehler 57900 folgt dessen Reason-Text, bei anderen im ersten TRY abgefangenen Fehlern SCOPE_INPUT_REJECTED. Fehler vor der regulären Ausgabe garantieren keine Aktualisierung. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@IncludePipelineDiagnostics:** @IncludePipelineDiagnostics: bit; Default: 0. Skalarer Schalter: 0 lässt die vier Diagnosegruppen weg; 1 verlangt @IncludePipelineCorrelation=1 und ergänzt die unten beschriebenen vier Diagnosegruppen. Auslassen verwendet 0; NULL und 1 ohne Pipelinekorrelation sind ungültig. Numerische Werte ungleich 0 konvertiert SQL Server nach 1, leeren Text nach 0.

**@PipelinePhaseThresholdMs:** @PipelinePhaseThresholdMs: bigint; Default: NULL. Skalarer Millisekundenwert von 0 bis 9223372036854775807. Auslassen beziehungsweise NULL deaktiviert den Befund SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED. Ein gesetzter Wert verlangt @IncludePipelineDiagnostics=1 und erzeugt den Befund nur, wenn ein bekanntes einzelnes Phasenintervall den Wert strikt überschreitet; Gleichheit genügt nicht. Negative Werte und gesetzte Werte ohne Diagnoseopt-in sind ungültig. Leerer Text kann nach 0 konvertiert werden und aktiviert dann den Grenzwert, sofern das Diagnoseopt-in gesetzt ist.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Die Ausgabegruppen heißen `scopeBinding`, `packageScopes`, `packageInvocations`, `scopeObservations`, `handlerActivity`, `scopeObjectSummary` und `scopeCoverage`; bei Pipelinekorrelation kommen `pipelineInstances`, `componentPhases`, `pathTransfers` und `pipelineCoverage` hinzu, bei Diagnose außerdem `componentPhaseSummary`, `pathTransferSummary`, `pipelineFindings` und `pipelineDiagnosticCoverage`. CONSOLE gibt die gewählten Gruppen als Resultsets aus; TABLE schreibt in vom Aufrufer bereitgestellte lokale Ziele, JSON liefert Gruppen über `@Json` (nvarchar(max) OUTPUT) nur bei `@JsonErzeugen=1`. `@StatusCodeOut` (varchar(40) OUTPUT) meldet SCOPE_CAPTURE_BOUND, SCOPE_BINDING_UNPROVEN oder INVALID_PARAMETER auf regulären Pfaden; `@IsPartialOut` (bit OUTPUT) kennzeichnet Teilbefunde. `@ErrorNumberOut` (int OUTPUT) und `@ErrorMessageOut` (nvarchar(2048) OUTPUT) melden behandelte Fehler; bei frühen nativen Ausnahmen ist keine aktualisierte Ausgabe zugesichert. Coveragezahlen entstehen vor dem Ausgabelimit, und Handlerbelege beweisen keinen Auslöser.

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.


## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalSsisExecutionScopes';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalSsisExecutionScopes] @Models=NULL, @Capture=NULL, @Handover=NULL, @ExecutionId=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Maximal 16 Pakete, acht Aufrufebenen, 1024 beobachtete Paketinstanzen, JSON-Tiefe 32 und das gemeinsame kooperative Zeitbudget. Die normale Ausgabe bleibt partiell. Deadlineberechnung und eigene Temp-DDL liegen vor dem ersten TRY. Der abschließende Ausgabe-CATCH führt SET LOCK_TIMEOUT in einem separaten dynamischen Batch mit dem vorherigen Wert aus und stellt XACT_ABORT wieder her; das SET LOCK_TIMEOUT dieses Batches endet mit dessen Rückkehr. Er wirft erneut; keine allgemeine Status-, Wiederherstellungs- oder atomare Rücknahmezusage. Mehrdeutige Pfade bleiben unzugeordnet; Handlerbelege beweisen keine Auslöserkausalität. Parser und Lineage bleiben im Toolbelt, Analyze bleibt ohne SQL CLR oder LLM-Installationspflicht.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt: monitor.InternalSsisExecutionScopes.
Typ: Interne Stored Procedure.
Zweck: Der Consumer validiert lokal attestierte SSIS-Paketsätze und ordnet gebundene Statistik- und Ereignisbeobachtungen Paketaufrufen und Handlerkörpern zu. Pipelinekorrelation und Diagnose sind optionale Erweiterungen.

Parameter:
@IncludePipelineCorrelation: bit; Default: 0. Skalarer Schalter: 0 verwendet Scope-Capture 1.0.0 und SSISDB_CURRENT_PROJECT_SCOPES_V1; 1 verlangt 1.1.0 und SSISDB_CURRENT_PROJECT_PIPELINES_V1 samt Pipelineidentitäten und -quellen. 1 ergänzt die unten beschriebenen vier Pipelinegruppen. Auslassen verwendet 0; NULL ist ungültig. SQL Server konvertiert numerische Werte ungleich 0 zu 1 und leeren Text vor dem Procedure-Eintritt zu 0.

@Models: nvarchar(max); Default: keiner, Pflichtargument. Erwartet wird ein JSON-Objekt als Unicode-Text, kein Dateipfad: contract="ssis-project-model-set", version="1.0.0", rootPackageKey und ein packages-Array mit 1–16 Einträgen. Jeder Eintrag enthält packageKey (eindeutige alphanumerische Kennung, höchstens 16 Zeichen), entryName (exakter eindeutiger Archivdateiname ohne /, \ oder :, 6–260 Zeichen), model als eingebettetes ssis-package-model 1.0.0 und identities als ssis-object-identities 1.2.0 mit passendem packageSha256 und objects-Array. rootPackageKey bezeichnet ein vorhandenes Paket. Die Identitäten binden nodeId, parentId, nodeKind (PACKAGE: Paket; EXECUTABLE: ausführbarer Knoten), nullable dtsId/packagePath, scopeKind (PACKAGE: Paketwurzel; CALL: Kindpaketaufruf; LOOP: Schleife; HANDLER: Ereignishandler; EXECUTABLE: sonstiger ausführbarer Scope), steps, profileStatus (SUPPORTED: qualifiziertes Profil; UNQUALIFIED: unqualifiziert), nullable eventName/callTarget an die Modellknoten. steps enthält höchstens 32 Objekte mit genau text (nichtleerer String, 2–8000 SQL-Bytes) und counter (JSON-Boolean true oder false). Qualifizierte Handler erlauben OnPreExecute (vor Ausführung), OnPostExecute (nach Ausführung) und OnError (Fehlerereignis); das beweist keinen konkreten Auslöser. Bei Pipelinekorrelation ist zusätzlich pipelineIdentities je Paket erforderlich. Höchstens 16 MiB nach DATALENGTH. Auslassen scheitert an der Pflichtsignatur; NULL, Leertext und ungültiges JSON ergeben keine belegte Bindung. Weitere eingebettete Felder beschreibt das Austauschschema.

@Capture: nvarchar(max); Default: keiner, Pflichtargument. Erwartet wird ein JSON-Objekt als Unicode-Text mit contract="ssis-execution-scopes"; ohne Pipelinekorrelation gelten version="1.0.0" und method="SSISDB_CURRENT_PROJECT_SCOPES_V1", mit Pipelinekorrelation 1.1.0 und SSISDB_CURRENT_PROJECT_PIPELINES_V1. execution enthält die passende positive executionId, den exakten Root-packageFileName, positive projectId/projectLsn, catalogDatabaseGuid, sourceBindingSha256 sowie optionale loggingLevel/executionStatus; die Wurzel enthält archiveSha256, den SHA-256 der exakten @Models-Bytes als modelSetSha256 und die Arrays observations und events. Beobachtungen enthalten passende executionId, positive statisticsId/executableId, packageName, packagePath, executionPath und nullable executableGuid, startTime, endTime, durationMs, executionResult. Ereignisse enthalten positive eventMessageId, Paket/Pfade sowie nullable executableGuid, eventName, messageCode, messageTime. Bei Pipelinekorrelation kommen componentPhases, pathTransfers und ein pipelineSources-Array mit genau je einem Eintrag für componentPhases und pathTransfers hinzu; die öffentliche Scope-Referenz beschreibt deren Feldform. Für Pipelinequellen gelten source=componentPhases oder pathTransfers und status=AVAILABLE (vorhanden), AVAILABLE_EMPTY (vorhanden, leer), UNAVAILABLE (nicht verfügbar) oder DENIED_PERMISSION (Berechtigung fehlt); errorNumber ist bei den letzten beiden positiv, sonst NULL. Höchstens 16 MiB je Dokument; zusammen höchstens 50000 Statistik-/Ereigniszeilen und bei Pipelinekorrelation einschließlich Phasen-/Transferzeilen. Doppelte Objektschlüssel und Verschachtelung jenseits der Tiefe 32 werden verworfen; unbekannte Schlüssel sind nicht pauschal verboten. Optionale, mit TRY_CONVERT projizierte Werte können bei Konvertierungsfehler NULL werden. Auslassen scheitert an der Pflichtsignatur; NULL, Leertext und ungültiges JSON ergeben keine belegte Bindung. Fehler innerhalb der optionalen Pipelinekorrelation oder -diagnose werden in deren Coverage-Gruppen dargestellt und ändern nicht zwangsläufig den Basisstatus oder die bereits erzeugten Grundgruppen.

@Handover: uniqueidentifier; Default: keiner, Pflichtargument. Skalarer UUID-Wert, etwa eine entsprechend typisierte Variable oder konvertierbare UUID-Zeichenfolge. Er wählt einen Beleg der Art 3 in [monitor].[SsisHandoverReceipt]. Der lokale Beleg enthält genau contract="ssis-local-scope-handover", version="1.0.0", issuedUtc, expiresUtc, modelSetSha256, captureSha256; er muss aktuell gültig sein, höchstens 24 Stunden gelten und die exakten UTF-16-Dokumentbytes binden. Die Prüfung liest mit READCOMMITTEDLOCK. Auslassen scheitert an der Pflichtsignatur; NULL oder fehlender/ungültiger Beleg lässt die Bindung unbelegt. Leertext ist keine UUID und kann bereits bei der SQL-Parameterkonvertierung scheitern. Eine beliebige UUID oder ein JSON-Vertrauensfeld ersetzt den lokalen Beleg nicht.

@ExecutionId: bigint; Default: keiner, Pflichtargument. Skalarer ganzzahliger Wert von 1 bis 9223372036854775807, gleich der Execution-ID im Capture. Auslassen scheitert an der Pflichtsignatur; NULL und Werte unter 1 sind ungültig. Leerer Text kann vor dem Eintritt nach 0 konvertiert werden und ist dann ungültig.

@MaxZeilen: int; Default: 1000. Skalarer ganzzahliger Wert. Positive Werte bis 2147483647 begrenzen jede Ausgabegruppe nach der Analyse. NULL und 0 setzen intern 2147483647 und damit keine zusätzliche kleinere Ausgabegrenze; negative Werte sind ungültig. Auslassen verwendet 1000. Leerer Text kann vor Eintritt nach 0 konvertiert werden und wirkt dann wie 0. Die Coverage-Zahlen entstehen vor der Kürzung.

@MaxDurationSeconds: int; Default: 30. Skalarer ganzzahliger Sekundenwert von 1 bis 60; Auslassen verwendet 30. NULL und Werte außerhalb dieses Bereichs sind ungültig. Leerer Text kann nach 0 konvertiert werden und ist dann ungültig. Das gemeinsame Zeitbudget ist kooperativ; die Deadline wird vor der ersten TRY-Strecke berechnet, weshalb ein Fehler dabei nicht als regulärer Parameterstatus zugesagt wird.

@LockTimeoutMs: int; Default: 0. Skalarer ganzzahliger Millisekundenwert von 0 bis 60000. 0 setzt LOCK_TIMEOUT 0 und bedeutet für eine Sperre NOWAIT; positive Werte setzen den entsprechenden Millisekundenwert. Auslassen verwendet 0; NULL und Werte außerhalb sind ungültig. Leerer Text kann nach 0 konvertiert werden. Der Consumer führt SET LOCK_TIMEOUT in einem separaten dynamischen Batch aus; dessen Einstellung endet bei Rückkehr aus sp_executesql und bestimmt keine nachfolgenden direkten Anweisungen. Die Wiederherstellungsbatches führen SET LOCK_TIMEOUT auf den erreichten normalen und abschließenden CATCH-Wegen erneut mit dem vorherigen Sitzungswert aus.

@ResultSetArt: varchar(16); Default: 'CONSOLE'. Skalarer Moduscode. Vollständige Wertemenge: CONSOLE gibt die Bindungsübersicht über den Console-Helper aus; RAW gibt jede freigeschaltete typisierte Gruppe als Resultset aus; TABLE schreibt ausdrücklich zugeordnete Gruppen in lokale Temp-Tabellen; NONE unterdrückt diese Ausgaben. Auslassen verwendet CONSOLE. Der Wert wird mit UPPER normalisiert, ohne ausdrückliches Trimmen; der anschließende SQL-Stringvergleich folgt seiner Padding-Semantik. NULL, Leertext und Werte, die keinem Code entsprechen, sind ungültig. JSON-Erzeugung ist davon unabhängig.

@ResultTablesJson: nvarchar(max); Default: NULL. Bei CONSOLE/RAW/NONE muss NULL vorliegen. TABLE verlangt ein nichtleeres JSON-Objekt, zum Beispiel {"scopeBinding":"#ScopeBinding"}; Schlüssel sind exakt die unten taxativ beschriebenen freigeschalteten Gruppennamen, Stringwerte unqualifizierte rohe lokale #Temp-Namen. Eine Teilmenge genügt; nicht zugeordnete Gruppen werden nicht geschrieben. Kein ##, kein #Monitor-Präfix (CI), höchstens 116 Zeichen nach sysname-Konvertierung; keine Klammer-/Schemaform und kein Trimmen. Schlüssel werden nach sysname-Konvertierung binär verglichen; doppelte Schlüssel und CI-gleiche Ziele sind ungültig. Ziele müssen vorhanden, leer und mit genau einer Seed-Spalte angelegt sein. Die Prüfung verändert vorübergehend das Zielschema durch eine Markerspalte; es gibt keine atomare Rücknahmezusage. Auslassen verwendet NULL; NULL, Leertext, {} und Arrays sind im TABLE-Modus ungültig.

@JsonErzeugen: bit; Default: 0. Skalarer Schalter: 0 erzeugt kein JSON und lässt den eingehenden @Json-Wert unverändert; 1 erzeugt Metadaten und die begrenzten Gruppenarrays unabhängig vom Ausgabemodus. Auslassen verwendet 0; NULL ist ungültig. Numerische Werte ungleich 0 konvertiert SQL Server nach 1, leeren Text nach 0.

@Json: nvarchar(max) OUTPUT; Default: NULL. Skalarer Unicode-Ausgabespeicher; zum Empfang eine passende Variable mit OUTPUT binden, ohne OUTPUT kann ein typisierter Wert übergeben und die Ausgabe verworfen werden. Auslassen verwendet NULL. Bei @JsonErzeugen=1 wird der Eingangswert einschließlich NULL, Leertext oder sonstigem Inhalt durch ein Objekt mit meta.schemaVersion=1, meta.executionScopesSchemaVersion=1, meta.isPartial=true und den freigeschalteten Arrays ersetzt; Pipelineopt-ins ergänzen ihre Schemaversion jeweils 1. Bei @JsonErzeugen=0 bleibt der Eingangswert einschließlich NULL/Leertext unverändert.

@StatusCodeOut: varchar(40) OUTPUT; Default: NULL. Skalarer Statusausgang; passende Variable mit OUTPUT bindet die Ausgabe, ein typisierter Wert ohne OUTPUT verwirft sie. Auslassen verwendet NULL. Bei regulärer Ausgabe werden eingehende NULL-, Leertext- oder sonstige Werte überschrieben: SCOPE_CAPTURE_BOUND bedeutet Capturebindung hergestellt, SCOPE_BINDING_UNPROVEN Bindung unbelegt beziehungsweise verworfene Bindungseingabe, INVALID_PARAMETER ungültiger Parameterwert oder Kombination. Außerhalb regulärer Rückgaben ist kein aktualisierter Status garantiert.

@IsPartialOut: bit OUTPUT; Default: NULL. Skalarer Flag-Ausgang; zum Empfang eine passende Variable mit OUTPUT binden, sonst wird die Ausgabe verworfen. Auslassen verwendet NULL. Bei regulärer Ausgabe wird jeder konvertierbare Eingangswert einschließlich NULL oder nach 0 konvertiertem Leertext durch 1 ersetzt: Das Ergebnis ist partiell. 0 wird regulär nicht ausgegeben. Fehler vor der Ausgabe garantieren keine Aktualisierung.

@ErrorNumberOut: int OUTPUT; Default: NULL. Skalarer Fehlernummernausgang; zum Empfang eine passende Variable mit OUTPUT binden, sonst wird die Ausgabe verworfen. Auslassen verwendet NULL. Bei regulärer Ausgabe werden Eingangswerte einschließlich NULL oder nach 0 konvertiertem Leertext überschrieben: NULL bedeutet kein erfasster Bindungsfehler; sonst steht hier die SQL-Fehlernummer, bei eigenen Bindungsprüfungen 57900. Native Fehlernummern sind keine geschlossene Menge. Neu geworfene Ausgabefehler werden nicht als regulärer Ausgang zugesagt.

@ErrorMessageOut: nvarchar(2048) OUTPUT; Default: NULL. Skalarer Unicode-Textausgang; passende Variable mit OUTPUT bindet die Ausgabe, sonst wird sie verworfen. Auslassen verwendet NULL. Bei regulärer Ausgabe werden eingehende NULL-, Leertext- oder andere Werte überschrieben: NULL bedeutet kein erfasster Grund; bei Fehler 57900 folgt dessen Reason-Text, bei anderen im ersten TRY abgefangenen Fehlern SCOPE_INPUT_REJECTED. Fehler vor der regulären Ausgabe garantieren keine Aktualisierung.

@IncludePipelineDiagnostics: bit; Default: 0. Skalarer Schalter: 0 lässt die vier Diagnosegruppen weg; 1 verlangt @IncludePipelineCorrelation=1 und ergänzt die unten beschriebenen vier Diagnosegruppen. Auslassen verwendet 0; NULL und 1 ohne Pipelinekorrelation sind ungültig. Numerische Werte ungleich 0 konvertiert SQL Server nach 1, leeren Text nach 0.

@PipelinePhaseThresholdMs: bigint; Default: NULL. Skalarer Millisekundenwert von 0 bis 9223372036854775807. Auslassen beziehungsweise NULL deaktiviert den Befund SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED. Ein gesetzter Wert verlangt @IncludePipelineDiagnostics=1 und erzeugt den Befund nur, wenn ein bekanntes einzelnes Phasenintervall den Wert strikt überschreitet; Gleichheit genügt nicht. Negative Werte und gesetzte Werte ohne Diagnoseopt-in sind ungültig. Leerer Text kann nach 0 konvertiert werden und aktiviert dann den Grenzwert, sofern das Diagnoseopt-in gesetzt ist.

Ergebnisgruppen:
scopeBinding: Bindungs- und Herkunftsstatus (Grundumfang).
packageScopes: Paketmodelle und Hashes (Grundumfang).
packageInvocations: Belegte Paketaufrufe mit Eltern- und Aufruferstatistik (Grundumfang).
scopeObservations: Statistik- und Ereignisbelege mit möglicher Modellzuordnung (Grundumfang).
handlerActivity: Handlerkörperbelege ohne bewiesenen Auslöser (Grundumfang).
scopeObjectSummary: Statistikanzahlen und inklusive Dauer je Modellknoten (Grundumfang).
scopeCoverage: Quell- und Zuordnungszahlen vor Ausgabekürzung (Grundumfang).
pipelineInstances: Gebundene Dataflow-Statistikinstanzen (Pipelinekorrelation).
componentPhases: Phasenbelege mit möglicher Komponentenzuordnung (Pipelinekorrelation).
pathTransfers: Transferbelege mit möglicher Modellkantenzuordnung (Pipelinekorrelation).
pipelineCoverage: Status und Zählungen je Pipelinequelle (Pipelinekorrelation).
componentPhaseSummary: Phasenkennzahlen je Dataflowinstanz und Komponente (Diagnose).
pathTransferSummary: Transferkennzahlen je Kante und Instanz (Diagnose).
pipelineFindings: Versionierte Hinweise mit Quellenbezug (Diagnose).
pipelineDiagnosticCoverage: Diagnoseabdeckung und unbekannte Werte (Diagnose).

Grenzen: Maximal 16 Pakete, acht Aufrufebenen, 1024 beobachtete Paketinstanzen, JSON-Tiefe 32 und das gemeinsame kooperative Zeitbudget. Die normale Ausgabe bleibt partiell. Deadlineberechnung und eigene Temp-DDL liegen vor dem ersten TRY. Der abschließende Ausgabe-CATCH führt SET LOCK_TIMEOUT in einem separaten dynamischen Batch mit dem vorherigen Wert aus und stellt XACT_ABORT wieder her; das SET LOCK_TIMEOUT dieses Batches endet mit dessen Rückkehr. Er wirft erneut; keine allgemeine Status-, Wiederherstellungs- oder atomare Rücknahmezusage. Mehrdeutige Pfade bleiben unzugeordnet; Handlerbelege beweisen keine Auslöserkausalität. Parser und Lineage bleiben im Toolbelt, Analyze bleibt ohne SQL CLR oder LLM-Installationspflicht.
```


USE [DeineDatenbank];
GO

/*
Objekt: [monitor].[InternalSsisPipelineDiagnostics].
Typ: Interne Stored Procedure.
Zweck: Die Procedure bildet aus bereits vom Scopeconsumer gebundenen Phasen- und Transferbelegen partielle Kennzahlen und versionierte Hinweise für den jeweiligen beobachteten Pipelineinstanzscope. Phasengruppen verwenden die gemessenen Intervalle; Transfergruppen verwenden gemeldete Zeilenzahlen und eine Portrolle aus dem gelieferten Toolbelt-Modell. Überlappende Intervalle sind weder CPU-Zeit noch kritischer Pfad oder Paketlaufzeit. Die Procedure lädt keine Paketdateien und führt keine erneute Modell- oder Lineageanalyse aus.

Parameter:
@Models: nvarchar(max); Default: keiner, Pflichtargument. Erwartet wird das Unicode-JSON-Dokument des bereits geprüften Paketsatzes. Der Helper liest je Paket model.nodes mit id, kind und attributes.portRole für Knoten des Typs PORT sowie model.edges mit id, kind und fromId für Kanten des Typs PIPELINE_PATH. Er ordnet dadurch die Quellportrolle einer bereits korrelierten Modellkante zu. Die Portrollen kommen aus dem Toolbelt-Modell und bilden hier keine geschlossene Eingabewerteliste; ERROR und NO_MATCH lösen jeweils einen Hinweis aus, während fehlende Rollen als UNKNOWN und andere Rollen unverändert in der Zusammenfassung erscheinen. Die öffentliche Procedure prüft Paketmodell und Transportgrenzen einschließlich Dokumentgröße, JSON-Tiefe und doppelter Schlüssel; dies sind keine unabhängigen Vertrauensprüfungen dieser internen Procedure. Auslassen scheitert an der Pflichtsignatur. Bei NULL liefern die JSON-OPENJSON-Joins keine Modellkanten und Ports, während eine Zusammenfassung aus bereits zugeordneten Phasenbelegen weiterhin entstehen kann. Leertext oder ungültiges JSON kann im TRY als Diagnoseeingabefehler erfasst werden.

@Bound: bit; Default: keiner, Pflichtargument. Skalarer interner Übergabeflag aus der lokalen Bindungsprüfung des Scopeconsumers. Diagnoseanalyse beginnt nur bei @Bound=1 und ohne PIPELINE_BINDING_UNPROVEN in der bereits vorhandenen Pipeline-Coverage. Bei 0 oder NULL wird die Analyse übersprungen; die Procedure schreibt dennoch Diagnose-Coverage aus den vorhandenen Coverage- und Belegtabellen und kann einen Coveragehinweis erzeugen. Der Flag allein ist kein Beleg und die Procedure prüft weder Handover noch Capturebindung. Auslassen scheitert an der Pflichtsignatur. Die vollständige bit-Wertemenge ist 0 (nicht gebunden) und 1 (vom Aufrufer als gebunden markiert). SQL Server konvertiert numerische Werte ungleich 0 zu 1 und leeren Text zu 0 vor dem Procedure-Eintritt.

@Deadline: datetime2(3); Default: keiner, Pflichtargument. Enthält dieselbe absolute UTC-Deadline, die der Scopeconsumer an die Korrelation übergeben hat. Die Procedure prüft sie vor und nach wesentlichen Diagnosephasen; ein erkanntes Überschreiten wird als DIAGNOSTIC_TIME_LIMIT in Diagnose-Coverage dargestellt. NULL unterdrückt die Vergleiche wegen SQL-NULL-Semantik und wird hier nicht als ungültiger Wert abgefangen. Auslassen scheitert an der Pflichtsignatur. Als datetime2(3)-Variable oder konvertierbaren ISO-Zeitpunkt übergeben, beispielsweise 2026-11-06T13:00:00.000; der Wert selbst trägt keine Zeitzone und muss UTC repräsentieren. Leerer Text kann zum Zeitpunkt 1900-01-01 konvertiert werden und ist dann abgelaufen; nicht konvertierbarer Text scheitert vor dem Eintritt.

@Limit: int; Default: keiner, Pflichtargument. Enthält das vom Scopeconsumer abgeleitete Zeilenlimit. Der Helper kürzt keine Ergebnis- oder Diagnosezeilen; er setzt OutputTruncated in Diagnose-Coverage, wenn die Anzahl der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen, Hinweise oder Coveragezeilen das Limit überschreitet. Die eigentliche Ausgabe kürzt der Scopeconsumer. Der Helper validiert den Wert nicht: Bei NULL ergibt der Vergleich keinen Treffer und das Flag wird wegen dieses Vergleichs nicht gesetzt; 0 oder negative Werte können bei vorhandenen Zeilen das Flag setzen. Negative Werte sind bei Umgehung der öffentlichen Guard-Prüfung kein gültiger Aufrufvertrag. Auslassen scheitert an der Pflichtsignatur. Als skalaren ganzzahligen int-Wert von -2147483648 bis 2147483647 übergeben; der Scopeconsumer liefert ein positives wirksames Limit. Leerer Text kann vor dem Eintritt nach 0 konvertiert werden.

@PipelinePhaseThresholdMs: bigint; Default: NULL. Skalarer Millisekunden-Grenzwert für den Hinweis SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED. NULL deaktiviert diesen Hinweis; ein nicht-NULL-Wert erzeugt ihn, wenn das längste bekannte einzelne Phasenintervall einer Komponentengruppe strikt größer ist als der Grenzwert. Gleichheit genügt nicht. Die interne Procedure selbst akzeptiert auch negative Werte, wenn der öffentliche Scopeconsumer umgangen wird; dann können bekannte nichtnegative Intervalle den Grenzwert überschreiten. Die öffentliche Procedure verwirft negative Werte und gesetzte Werte ohne Diagnoseopt-in. Auslassen verwendet NULL. Leerer Text wird bei erfolgreicher SQL-Typkonvertierung zu bigint regelmäßig als 0 übergeben und aktiviert dann den Vergleich; nicht konvertierbarer Text scheitert bereits bei der Parameterbindung. Der SQL-Typ erlaubt ganze Werte von -9223372036854775808 bis 9223372036854775807; der öffentliche Vertrag beschränkt gesetzte Werte auf den nichtnegativen Bereich.

Ergebnis- und Temp-Vertrag: Die Procedure erzeugt kein Resultset und hat keine OUTPUT-Parameter. Sie liest die vom Scopeconsumer bereitgestellten Temp-Tabellen #InternalSsisExecutionScopes_PipelineCoverage, #InternalSsisExecutionScopes_ComponentPhases, #InternalSsisExecutionScopes_PathTransfers, #InternalSsisExecutionScopes_Packages und #InternalSsisExecutionScopes_Binding und schreibt in #InternalSsisExecutionScopes_PhaseSummary, #InternalSsisExecutionScopes_TransferSummary, #InternalSsisExecutionScopes_PipelineFindings und #InternalSsisExecutionScopes_DiagnosticCoverage. Die Gruppen componentPhaseSummary enthalten je Pipelineinstanz, Komponente und Phasenname ObservedIntervalCount, ValidIntervalCount, UnknownIntervalCount, ObservedIntervalSumMs, LongestIntervalMs, SpanMs, FirstStartTime, LastEndTime, OverlapObserved, RankWithinFlowPhase, EvidencePhaseStatsId und IsPartial. Summen und Rangfolge berücksichtigen gültige zugeordnete Beobachtungen; SpanMs reicht vom frühesten bekannten Start bis zum spätesten bekannten Ende und kann Überlappungen enthalten. pathTransferSummary enthält je Pipelineinstanz und Kante PortRole, ObservedTransferCount, KnownRowCount, UnknownRowCount, ObservedRowsSent, FirstCreatedTime, LastCreatedTime, FirstDataStatsId, PositiveDataStatsId und IsPartial. pipelineFindings enthält RuleId, RuleVersion, Severity, EvidenceLevel, Paket-/Aufruf-/Flow-/Knoten-/Kantenbezug, SourceName, SourceId, ObservedValue, ThresholdMs, PackageSha256, SourceBindingSha256 und IsPartial. pipelineDiagnosticCoverage enthält SourceName, StatusCode, SourceErrorNumber, ObservedRowCount, MappedRowCount, UnassignedRowCount, SummaryRowCount, UnknownValueCount, UnknownRoleCount, LoggingLevel, IsPartial, OutputTruncated und ReasonCode. Die fünf möglichen RuleId-Werte lauten SSIS_PIPELINE_ERROR_OUTPUT_OBSERVED für positive beobachtete Zeilen auf einer ERROR-Ausgabe, SSIS_PIPELINE_NO_MATCH_OBSERVED für positive beobachtete Zeilen auf einer NO_MATCH-Ausgabe, SSIS_PIPELINE_ZERO_OBSERVED_TRANSFER für einen Transfer mit vollständig bekannten Zeilenwerten und Summe null, SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED für ein bekanntes einzelnes Phasenintervall oberhalb des gesetzten Grenzwerts sowie SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED für Diagnosequellen mit eingeschränkter Abdeckung oder unbekannten Werten beziehungsweise Rollen. Hinweise tragen Version 1.0.0 und Severity INFO. Fehlerhinweise sind Evidenzhinweise und keine Aussagen über Ursache oder Auswirkung außerhalb der beobachteten Daten. Der Aufrufer kürzt alle Ergebnisgruppen später und kennzeichnet tatsächliche Ausgabekürzung.

Fehlergrenzen: Während der Diagnoseanalyse erfasste Fehler werden durch Löschen der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen und bis dahin erzeugten Hinweise zurückgenommen. Fehlernummer 57920 wird als DIAGNOSTIC_TIME_LIMIT mit gleicher Fehlernummer abgebildet; sonstige abgefangene Fehler erhalten DIAGNOSTIC_INPUT_REJECTED mit ihrer ursprünglichen Fehlernummer. Diagnose-Coverage wird danach aus den Pipeline-Coveragewerten geschrieben und erhält bei Fehlern den jeweiligen Diagnose-Reason-Code. Nach dem CATCH liegen Coverage-Schreiben, Erzeugung des Hinweises SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED, OutputTruncated-Aktualisierung und Wiederherstellung des vorherigen LOCK_TIMEOUT außerhalb der Abfangstrecke und können selbst fehlschlagen. Daher besteht keine universelle Fehler- oder Wiederherstellungszusage und keine atomare Gesamttransaktion.
*/
-- USAGE_SKILL_BEGIN monitor.InternalSsisPipelineDiagnostics 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalSsisPipelineDiagnostics"
-- schema_name: "monitor"
-- object_name: "InternalSsisPipelineDiagnostics"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "framework"
-- is_internal: true
-- description: "Die Procedure bildet aus bereits vom Scopeconsumer gebundenen Phasen- und Transferbelegen partielle Kennzahlen und versionierte Hinweise für den jeweiligen beobachteten Pipelineinstanzscope."
-- source_path: "Code/10_SSIS/037_InternalSsisPipelineDiagnostics.sql"
-- ---
-- 
-- # monitor.InternalSsisPipelineDiagnostics
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure bildet aus bereits vom Scopeconsumer gebundenen Phasen- und Transferbelegen partielle Kennzahlen und versionierte Hinweise für den jeweiligen beobachteten Pipelineinstanzscope. Phasengruppen verwenden die gemessenen Intervalle; Transfergruppen verwenden gemeldete Zeilenzahlen und eine Portrolle aus dem gelieferten Toolbelt-Modell. Überlappende Intervalle sind weder CPU-Zeit noch kritischer Pfad oder Paketlaufzeit. Die Procedure lädt keine Paketdateien und führt keine erneute Modell- oder Lineageanalyse aus.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalSsisPipelineDiagnostics]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `sys.sp_executesql`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @Models | nvarchar(max) | ja | kein Default |
-- | @Bound | bit | ja | kein Default |
-- | @Deadline | datetime2(3) | ja | kein Default |
-- | @Limit | int | ja | kein Default |
-- | @PipelinePhaseThresholdMs | bigint | nein | NULL |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@Models:** @Models: nvarchar(max); Default: keiner, Pflichtargument. Erwartet wird das Unicode-JSON-Dokument des bereits geprüften Paketsatzes. Der Helper liest je Paket model.nodes mit id, kind und attributes.portRole für Knoten des Typs PORT sowie model.edges mit id, kind und fromId für Kanten des Typs PIPELINE_PATH. Er ordnet dadurch die Quellportrolle einer bereits korrelierten Modellkante zu. Die Portrollen kommen aus dem Toolbelt-Modell und bilden hier keine geschlossene Eingabewerteliste; ERROR und NO_MATCH lösen jeweils einen Hinweis aus, während fehlende Rollen als UNKNOWN und andere Rollen unverändert in der Zusammenfassung erscheinen. Die öffentliche Procedure prüft Paketmodell und Transportgrenzen einschließlich Dokumentgröße, JSON-Tiefe und doppelter Schlüssel; dies sind keine unabhängigen Vertrauensprüfungen dieser internen Procedure. Auslassen scheitert an der Pflichtsignatur. Bei NULL liefern die JSON-OPENJSON-Joins keine Modellkanten und Ports, während eine Zusammenfassung aus bereits zugeordneten Phasenbelegen weiterhin entstehen kann. Leertext oder ungültiges JSON kann im TRY als Diagnoseeingabefehler erfasst werden.
-- 
-- **@Bound:** @Bound: bit; Default: keiner, Pflichtargument. Skalarer interner Übergabeflag aus der lokalen Bindungsprüfung des Scopeconsumers. Diagnoseanalyse beginnt nur bei @Bound=1 und ohne PIPELINE_BINDING_UNPROVEN in der bereits vorhandenen Pipeline-Coverage. Bei 0 oder NULL wird die Analyse übersprungen; die Procedure schreibt dennoch Diagnose-Coverage aus den vorhandenen Coverage- und Belegtabellen und kann einen Coveragehinweis erzeugen. Der Flag allein ist kein Beleg und die Procedure prüft weder Handover noch Capturebindung. Auslassen scheitert an der Pflichtsignatur. Die vollständige bit-Wertemenge ist 0 (nicht gebunden) und 1 (vom Aufrufer als gebunden markiert). SQL Server konvertiert numerische Werte ungleich 0 zu 1 und leeren Text zu 0 vor dem Procedure-Eintritt.
-- 
-- **@Deadline:** @Deadline: datetime2(3); Default: keiner, Pflichtargument. Enthält dieselbe absolute UTC-Deadline, die der Scopeconsumer an die Korrelation übergeben hat. Die Procedure prüft sie vor und nach wesentlichen Diagnosephasen; ein erkanntes Überschreiten wird als DIAGNOSTIC_TIME_LIMIT in Diagnose-Coverage dargestellt. NULL unterdrückt die Vergleiche wegen SQL-NULL-Semantik und wird hier nicht als ungültiger Wert abgefangen. Auslassen scheitert an der Pflichtsignatur. Als datetime2(3)-Variable oder konvertierbaren ISO-Zeitpunkt übergeben, beispielsweise 2026-11-06T13:00:00.000; der Wert selbst trägt keine Zeitzone und muss UTC repräsentieren. Leerer Text kann zum Zeitpunkt 1900-01-01 konvertiert werden und ist dann abgelaufen; nicht konvertierbarer Text scheitert vor dem Eintritt.
-- 
-- **@Limit:** @Limit: int; Default: keiner, Pflichtargument. Enthält das vom Scopeconsumer abgeleitete Zeilenlimit. Der Helper kürzt keine Ergebnis- oder Diagnosezeilen; er setzt OutputTruncated in Diagnose-Coverage, wenn die Anzahl der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen, Hinweise oder Coveragezeilen das Limit überschreitet. Die eigentliche Ausgabe kürzt der Scopeconsumer. Der Helper validiert den Wert nicht: Bei NULL ergibt der Vergleich keinen Treffer und das Flag wird wegen dieses Vergleichs nicht gesetzt; 0 oder negative Werte können bei vorhandenen Zeilen das Flag setzen. Negative Werte sind bei Umgehung der öffentlichen Guard-Prüfung kein gültiger Aufrufvertrag. Auslassen scheitert an der Pflichtsignatur. Als skalaren ganzzahligen int-Wert von -2147483648 bis 2147483647 übergeben; der Scopeconsumer liefert ein positives wirksames Limit. Leerer Text kann vor dem Eintritt nach 0 konvertiert werden.
-- 
-- **@PipelinePhaseThresholdMs:** @PipelinePhaseThresholdMs: bigint; Default: NULL. Skalarer Millisekunden-Grenzwert für den Hinweis SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED. NULL deaktiviert diesen Hinweis; ein nicht-NULL-Wert erzeugt ihn, wenn das längste bekannte einzelne Phasenintervall einer Komponentengruppe strikt größer ist als der Grenzwert. Gleichheit genügt nicht. Die interne Procedure selbst akzeptiert auch negative Werte, wenn der öffentliche Scopeconsumer umgangen wird; dann können bekannte nichtnegative Intervalle den Grenzwert überschreiten. Die öffentliche Procedure verwirft negative Werte und gesetzte Werte ohne Diagnoseopt-in. Auslassen verwendet NULL. Leerer Text wird bei erfolgreicher SQL-Typkonvertierung zu bigint regelmäßig als 0 übergeben und aktiviert dann den Vergleich; nicht konvertierbarer Text scheitert bereits bei der Parameterbindung. Der SQL-Typ erlaubt ganze Werte von -9223372036854775808 bis 9223372036854775807; der öffentliche Vertrag beschränkt gesetzte Werte auf den nichtnegativen Bereich.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Kein direktes Resultset und keine OUTPUT-Parameter. Der Helper schreibt die vorgegebenen lokalen Ziele für Phasen- und Transferzusammenfassungen, Findings und DiagnosticCoverage. `OutputTruncated` ist ein Statushinweis beim Überschreiten von `@Limit`; der Helper kappt selbst keine Ergebniszeilen. Die öffentliche SSIS-Procedure wählt und exportiert die fertigen Gruppen.
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalSsisPipelineDiagnostics';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [monitor].[InternalSsisPipelineDiagnostics] @Models=NULL, @Bound=NULL, @Deadline=NULL, @Limit=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Während der Diagnoseanalyse erfasste Fehler werden durch Löschen der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen und bis dahin erzeugten Hinweise zurückgenommen. Fehlernummer 57920 wird als DIAGNOSTIC_TIME_LIMIT mit gleicher Fehlernummer abgebildet; sonstige abgefangene Fehler erhalten DIAGNOSTIC_INPUT_REJECTED mit ihrer ursprünglichen Fehlernummer. Diagnose-Coverage wird danach aus den Pipeline-Coveragewerten geschrieben und erhält bei Fehlern den jeweiligen Diagnose-Reason-Code. Nach dem CATCH liegen Coverage-Schreiben, Erzeugung des Hinweises SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED, OutputTruncated-Aktualisierung und Wiederherstellung des vorherigen LOCK_TIMEOUT außerhalb der Abfangstrecke und können selbst fehlschlagen. Daher besteht keine universelle Fehler- oder Wiederherstellungszusage und keine atomare Gesamttransaktion.
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt: [monitor].[InternalSsisPipelineDiagnostics].
-- Typ: Interne Stored Procedure.
-- Zweck: Die Procedure bildet aus bereits vom Scopeconsumer gebundenen Phasen- und Transferbelegen partielle Kennzahlen und versionierte Hinweise für den jeweiligen beobachteten Pipelineinstanzscope. Phasengruppen verwenden die gemessenen Intervalle; Transfergruppen verwenden gemeldete Zeilenzahlen und eine Portrolle aus dem gelieferten Toolbelt-Modell. Überlappende Intervalle sind weder CPU-Zeit noch kritischer Pfad oder Paketlaufzeit. Die Procedure lädt keine Paketdateien und führt keine erneute Modell- oder Lineageanalyse aus.
-- 
-- Parameter:
-- @Models: nvarchar(max); Default: keiner, Pflichtargument. Erwartet wird das Unicode-JSON-Dokument des bereits geprüften Paketsatzes. Der Helper liest je Paket model.nodes mit id, kind und attributes.portRole für Knoten des Typs PORT sowie model.edges mit id, kind und fromId für Kanten des Typs PIPELINE_PATH. Er ordnet dadurch die Quellportrolle einer bereits korrelierten Modellkante zu. Die Portrollen kommen aus dem Toolbelt-Modell und bilden hier keine geschlossene Eingabewerteliste; ERROR und NO_MATCH lösen jeweils einen Hinweis aus, während fehlende Rollen als UNKNOWN und andere Rollen unverändert in der Zusammenfassung erscheinen. Die öffentliche Procedure prüft Paketmodell und Transportgrenzen einschließlich Dokumentgröße, JSON-Tiefe und doppelter Schlüssel; dies sind keine unabhängigen Vertrauensprüfungen dieser internen Procedure. Auslassen scheitert an der Pflichtsignatur. Bei NULL liefern die JSON-OPENJSON-Joins keine Modellkanten und Ports, während eine Zusammenfassung aus bereits zugeordneten Phasenbelegen weiterhin entstehen kann. Leertext oder ungültiges JSON kann im TRY als Diagnoseeingabefehler erfasst werden.
-- 
-- @Bound: bit; Default: keiner, Pflichtargument. Skalarer interner Übergabeflag aus der lokalen Bindungsprüfung des Scopeconsumers. Diagnoseanalyse beginnt nur bei @Bound=1 und ohne PIPELINE_BINDING_UNPROVEN in der bereits vorhandenen Pipeline-Coverage. Bei 0 oder NULL wird die Analyse übersprungen; die Procedure schreibt dennoch Diagnose-Coverage aus den vorhandenen Coverage- und Belegtabellen und kann einen Coveragehinweis erzeugen. Der Flag allein ist kein Beleg und die Procedure prüft weder Handover noch Capturebindung. Auslassen scheitert an der Pflichtsignatur. Die vollständige bit-Wertemenge ist 0 (nicht gebunden) und 1 (vom Aufrufer als gebunden markiert). SQL Server konvertiert numerische Werte ungleich 0 zu 1 und leeren Text zu 0 vor dem Procedure-Eintritt.
-- 
-- @Deadline: datetime2(3); Default: keiner, Pflichtargument. Enthält dieselbe absolute UTC-Deadline, die der Scopeconsumer an die Korrelation übergeben hat. Die Procedure prüft sie vor und nach wesentlichen Diagnosephasen; ein erkanntes Überschreiten wird als DIAGNOSTIC_TIME_LIMIT in Diagnose-Coverage dargestellt. NULL unterdrückt die Vergleiche wegen SQL-NULL-Semantik und wird hier nicht als ungültiger Wert abgefangen. Auslassen scheitert an der Pflichtsignatur. Als datetime2(3)-Variable oder konvertierbaren ISO-Zeitpunkt übergeben, beispielsweise 2026-11-06T13:00:00.000; der Wert selbst trägt keine Zeitzone und muss UTC repräsentieren. Leerer Text kann zum Zeitpunkt 1900-01-01 konvertiert werden und ist dann abgelaufen; nicht konvertierbarer Text scheitert vor dem Eintritt.
-- 
-- @Limit: int; Default: keiner, Pflichtargument. Enthält das vom Scopeconsumer abgeleitete Zeilenlimit. Der Helper kürzt keine Ergebnis- oder Diagnosezeilen; er setzt OutputTruncated in Diagnose-Coverage, wenn die Anzahl der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen, Hinweise oder Coveragezeilen das Limit überschreitet. Die eigentliche Ausgabe kürzt der Scopeconsumer. Der Helper validiert den Wert nicht: Bei NULL ergibt der Vergleich keinen Treffer und das Flag wird wegen dieses Vergleichs nicht gesetzt; 0 oder negative Werte können bei vorhandenen Zeilen das Flag setzen. Negative Werte sind bei Umgehung der öffentlichen Guard-Prüfung kein gültiger Aufrufvertrag. Auslassen scheitert an der Pflichtsignatur. Als skalaren ganzzahligen int-Wert von -2147483648 bis 2147483647 übergeben; der Scopeconsumer liefert ein positives wirksames Limit. Leerer Text kann vor dem Eintritt nach 0 konvertiert werden.
-- 
-- @PipelinePhaseThresholdMs: bigint; Default: NULL. Skalarer Millisekunden-Grenzwert für den Hinweis SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED. NULL deaktiviert diesen Hinweis; ein nicht-NULL-Wert erzeugt ihn, wenn das längste bekannte einzelne Phasenintervall einer Komponentengruppe strikt größer ist als der Grenzwert. Gleichheit genügt nicht. Die interne Procedure selbst akzeptiert auch negative Werte, wenn der öffentliche Scopeconsumer umgangen wird; dann können bekannte nichtnegative Intervalle den Grenzwert überschreiten. Die öffentliche Procedure verwirft negative Werte und gesetzte Werte ohne Diagnoseopt-in. Auslassen verwendet NULL. Leerer Text wird bei erfolgreicher SQL-Typkonvertierung zu bigint regelmäßig als 0 übergeben und aktiviert dann den Vergleich; nicht konvertierbarer Text scheitert bereits bei der Parameterbindung. Der SQL-Typ erlaubt ganze Werte von -9223372036854775808 bis 9223372036854775807; der öffentliche Vertrag beschränkt gesetzte Werte auf den nichtnegativen Bereich.
-- 
-- Ergebnis- und Temp-Vertrag: Die Procedure erzeugt kein Resultset und hat keine OUTPUT-Parameter. Sie liest die vom Scopeconsumer bereitgestellten Temp-Tabellen #InternalSsisExecutionScopes_PipelineCoverage, #InternalSsisExecutionScopes_ComponentPhases, #InternalSsisExecutionScopes_PathTransfers, #InternalSsisExecutionScopes_Packages und #InternalSsisExecutionScopes_Binding und schreibt in #InternalSsisExecutionScopes_PhaseSummary, #InternalSsisExecutionScopes_TransferSummary, #InternalSsisExecutionScopes_PipelineFindings und #InternalSsisExecutionScopes_DiagnosticCoverage. Die Gruppen componentPhaseSummary enthalten je Pipelineinstanz, Komponente und Phasenname ObservedIntervalCount, ValidIntervalCount, UnknownIntervalCount, ObservedIntervalSumMs, LongestIntervalMs, SpanMs, FirstStartTime, LastEndTime, OverlapObserved, RankWithinFlowPhase, EvidencePhaseStatsId und IsPartial. Summen und Rangfolge berücksichtigen gültige zugeordnete Beobachtungen; SpanMs reicht vom frühesten bekannten Start bis zum spätesten bekannten Ende und kann Überlappungen enthalten. pathTransferSummary enthält je Pipelineinstanz und Kante PortRole, ObservedTransferCount, KnownRowCount, UnknownRowCount, ObservedRowsSent, FirstCreatedTime, LastCreatedTime, FirstDataStatsId, PositiveDataStatsId und IsPartial. pipelineFindings enthält RuleId, RuleVersion, Severity, EvidenceLevel, Paket-/Aufruf-/Flow-/Knoten-/Kantenbezug, SourceName, SourceId, ObservedValue, ThresholdMs, PackageSha256, SourceBindingSha256 und IsPartial. pipelineDiagnosticCoverage enthält SourceName, StatusCode, SourceErrorNumber, ObservedRowCount, MappedRowCount, UnassignedRowCount, SummaryRowCount, UnknownValueCount, UnknownRoleCount, LoggingLevel, IsPartial, OutputTruncated und ReasonCode. Die fünf möglichen RuleId-Werte lauten SSIS_PIPELINE_ERROR_OUTPUT_OBSERVED für positive beobachtete Zeilen auf einer ERROR-Ausgabe, SSIS_PIPELINE_NO_MATCH_OBSERVED für positive beobachtete Zeilen auf einer NO_MATCH-Ausgabe, SSIS_PIPELINE_ZERO_OBSERVED_TRANSFER für einen Transfer mit vollständig bekannten Zeilenwerten und Summe null, SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED für ein bekanntes einzelnes Phasenintervall oberhalb des gesetzten Grenzwerts sowie SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED für Diagnosequellen mit eingeschränkter Abdeckung oder unbekannten Werten beziehungsweise Rollen. Hinweise tragen Version 1.0.0 und Severity INFO. Fehlerhinweise sind Evidenzhinweise und keine Aussagen über Ursache oder Auswirkung außerhalb der beobachteten Daten. Der Aufrufer kürzt alle Ergebnisgruppen später und kennzeichnet tatsächliche Ausgabekürzung.
-- 
-- Fehlergrenzen: Während der Diagnoseanalyse erfasste Fehler werden durch Löschen der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen und bis dahin erzeugten Hinweise zurückgenommen. Fehlernummer 57920 wird als DIAGNOSTIC_TIME_LIMIT mit gleicher Fehlernummer abgebildet; sonstige abgefangene Fehler erhalten DIAGNOSTIC_INPUT_REJECTED mit ihrer ursprünglichen Fehlernummer. Diagnose-Coverage wird danach aus den Pipeline-Coveragewerten geschrieben und erhält bei Fehlern den jeweiligen Diagnose-Reason-Code. Nach dem CATCH liegen Coverage-Schreiben, Erzeugung des Hinweises SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED, OutputTruncated-Aktualisierung und Wiederherstellung des vorherigen LOCK_TIMEOUT außerhalb der Abfangstrecke und können selbst fehlschlagen. Daher besteht keine universelle Fehler- oder Wiederherstellungszusage und keine atomare Gesamttransaktion.
-- ```
-- 
-- USAGE_SKILL_END monitor.InternalSsisPipelineDiagnostics
CREATE OR ALTER PROCEDURE [monitor].[InternalSsisPipelineDiagnostics]
    @Models nvarchar(max), @Bound bit, @Deadline datetime2(3), @Limit int,
    @PipelinePhaseThresholdMs bigint = NULL
    , @Hilfe bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN monitor.InternalSsisPipelineDiagnostics
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'InternalSsisPipelineDiagnostics') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.InternalSsisPipelineDiagnostics"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "InternalSsisPipelineDiagnostics"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Die Procedure bildet aus bereits vom Scopeconsumer gebundenen Phasen- und Transferbelegen partielle Kennzahlen und versionierte Hinweise für den jeweiligen beobachteten Pipelineinstanzscope."'
            + NCHAR(10)
            + N'source_path: "Code/10_SSIS/037_InternalSsisPipelineDiagnostics.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.InternalSsisPipelineDiagnostics'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure bildet aus bereits vom Scopeconsumer gebundenen Phasen- und Transferbelegen partielle Kennzahlen und versionierte Hinweise für den jeweiligen beobachteten Pipelineinstanzscope. Phasengruppen verwenden die gemessenen Intervalle; Transfergruppen verwenden gemeldete Zeilenzahlen und eine Portrolle aus dem gelieferten Toolbelt-Modell. Überlappende Intervalle sind weder CPU-Zeit noch kritischer Pfad oder Paketlaufzeit. Die Procedure lädt keine Paketdateien und führt keine erneute Modell- oder Lineageanalyse aus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalSsisPipelineDiagnostics]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `sys.sp_executesql`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @Models | nvarchar(max) | ja | kein Default |'
            + NCHAR(10)
            + N'| @Bound | bit | ja | kein Default |'
            + NCHAR(10)
            + N'| @Deadline | datetime2(3) | ja | kein Default |'
            + NCHAR(10)
            + N'| @Limit | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @PipelinePhaseThresholdMs | bigint | nein | NULL |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Models:** @Models: nvarchar(max); Default: keiner, Pflichtargument. Erwartet wird das Unicode-JSON-Dokument des bereits geprüften Paketsatzes. Der Helper liest je Paket model.nodes mit id, kind und attributes.portRole für Knoten des Typs PORT sowie model.edges mit id, kind und fromId für Kanten des Typs PIPELINE_PATH. Er ordnet dadurch die Quellportrolle einer bereits korrelierten Modellkante zu. Die Portrollen kommen aus dem Toolbelt-Modell und bilden hier keine geschlossene Eingabewerteliste; ERROR und NO_MATCH lösen jeweils einen Hinweis aus, während fehlende Rollen als UNKNOWN und andere Rollen unverändert in der Zusammenfassung erscheinen. Die öffentliche Procedure prüft Paketmodell und Transportgrenzen einschließlich Dokumentgröße, JSON-Tiefe und doppelter Schlüssel; dies sind keine unabhängigen Vertrauensprüfungen dieser internen Procedure. Auslassen scheitert an der Pflichtsignatur. Bei NULL liefern die JSON-OPENJSON-Joins keine Modellkanten und Ports, während eine Zusammenf'
            + N'assung aus bereits zugeordneten Phasenbelegen weiterhin entstehen kann. Leertext oder ungültiges JSON kann im TRY als Diagnoseeingabefehler erfasst werden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Bound:** @Bound: bit; Default: keiner, Pflichtargument. Skalarer interner Übergabeflag aus der lokalen Bindungsprüfung des Scopeconsumers. Diagnoseanalyse beginnt nur bei @Bound=1 und ohne PIPELINE_BINDING_UNPROVEN in der bereits vorhandenen Pipeline-Coverage. Bei 0 oder NULL wird die Analyse übersprungen; die Procedure schreibt dennoch Diagnose-Coverage aus den vorhandenen Coverage- und Belegtabellen und kann einen Coveragehinweis erzeugen. Der Flag allein ist kein Beleg und die Procedure prüft weder Handover noch Capturebindung. Auslassen scheitert an der Pflichtsignatur. Die vollständige bit-Wertemenge ist 0 (nicht gebunden) und 1 (vom Aufrufer als gebunden markiert). SQL Server konvertiert numerische Werte ungleich 0 zu 1 und leeren Text zu 0 vor dem Procedure-Eintritt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Deadline:** @Deadline: datetime2(3); Default: keiner, Pflichtargument. Enthält dieselbe absolute UTC-Deadline, die der Scopeconsumer an die Korrelation übergeben hat. Die Procedure prüft sie vor und nach wesentlichen Diagnosephasen; ein erkanntes Überschreiten wird als DIAGNOSTIC_TIME_LIMIT in Diagnose-Coverage dargestellt. NULL unterdrückt die Vergleiche wegen SQL-NULL-Semantik und wird hier nicht als ungültiger Wert abgefangen. Auslassen scheitert an der Pflichtsignatur. Als datetime2(3)-Variable oder konvertierbaren ISO-Zeitpunkt übergeben, beispielsweise 2026-11-06T13:00:00.000; der Wert selbst trägt keine Zeitzone und muss UTC repräsentieren. Leerer Text kann zum Zeitpunkt 1900-01-01 konvertiert werden und ist dann abgelaufen; nicht konvertierbarer Text scheitert vor dem Eintritt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Limit:** @Limit: int; Default: keiner, Pflichtargument. Enthält das vom Scopeconsumer abgeleitete Zeilenlimit. Der Helper kürzt keine Ergebnis- oder Diagnosezeilen; er setzt OutputTruncated in Diagnose-Coverage, wenn die Anzahl der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen, Hinweise oder Coveragezeilen das Limit überschreitet. Die eigentliche Ausgabe kürzt der Scopeconsumer. Der Helper validiert den Wert nicht: Bei NULL ergibt der Vergleich keinen Treffer und das Flag wird wegen dieses Vergleichs nicht gesetzt; 0 oder negative Werte können bei vorhandenen Zeilen das Flag setzen. Negative Werte sind bei Umgehung der öffentlichen Guard-Prüfung kein gültiger Aufrufvertrag. Auslassen scheitert an der Pflichtsignatur. Als skalaren ganzzahligen int-Wert von -2147483648 bis 2147483647 übergeben; der Scopeconsumer liefert ein positives wirksames Limit. Leerer Text kann vor dem Eintritt nach 0 konvertiert werden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PipelinePhaseThresholdMs:** @PipelinePhaseThresholdMs: bigint; Default: NULL. Skalarer Millisekunden-Grenzwert für den Hinweis SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED. NULL deaktiviert diesen Hinweis; ein nicht-NULL-Wert erzeugt ihn, wenn das längste bekannte einzelne Phasenintervall einer Komponentengruppe strikt größer ist als der Grenzwert. Gleichheit genügt nicht. Die interne Procedure selbst akzeptiert auch negative Werte, wenn der öffentliche Scopeconsumer umgangen wird; dann können bekannte nichtnegative Intervalle den Grenzwert überschreiten. Die öffentliche Procedure verwirft negative Werte und gesetzte Werte ohne Diagnoseopt-in. Auslassen verwendet NULL. Leerer Text wird bei erfolgreicher SQL-Typkonvertierung zu bigint regelmäßig als 0 übergeben und aktiviert dann den Vergleich; nicht konvertierbarer Text scheitert bereits bei der Parameterbindung. Der SQL-Typ erlaubt ganze Werte von -9223372036854775808 bis 9223372036854775807; der öffentliche Vertrag beschränkt gesetzte W'
            + N'erte auf den nichtnegativen Bereich.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein direktes Resultset und keine OUTPUT-Parameter. Der Helper schreibt die vorgegebenen lokalen Ziele für Phasen- und Transferzusammenfassungen, Findings und DiagnosticCoverage. `OutputTruncated` ist ein Statushinweis beim Überschreiten von `@Limit`; der Helper kappt selbst keine Ergebniszeilen. Die öffentliche SSIS-Procedure wählt und exportiert die fertigen Gruppen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''monitor'' AND [ObjectName]=N''InternalSsisPipelineDiagnostics'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[InternalSsisPipelineDiagnostics] @Models=NULL, @Bound=NULL, @Deadline=NULL, @Limit=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Während der Diagnoseanalyse erfasste Fehler werden durch Löschen der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen und bis dahin erzeugten Hinweise zurückgenommen. Fehlernummer 57920 wird als DIAGNOSTIC_TIME_LIMIT mit gleicher Fehlernummer abgebildet; sonstige abgefangene Fehler erhalten DIAGNOSTIC_INPUT_REJECTED mit ihrer ursprünglichen Fehlernummer. Diagnose-Coverage wird danach aus den Pipeline-Coveragewerten geschrieben und erhält bei Fehlern den jeweiligen Diagnose-Reason-Code. Nach dem CATCH liegen Coverage-Schreiben, Erzeugung des Hinweises SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED, OutputTruncated-Aktualisierung und Wiederherstellung des vorherigen LOCK_TIMEOUT außerhalb der Abfangstrecke und können selbst fehlschlagen. Daher besteht keine universelle Fehler- oder Wiederherstellungszusage und keine atomare Gesamttransaktion.'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt: [monitor].[InternalSsisPipelineDiagnostics].'
            + NCHAR(10)
            + N'Typ: Interne Stored Procedure.'
            + NCHAR(10)
            + N'Zweck: Die Procedure bildet aus bereits vom Scopeconsumer gebundenen Phasen- und Transferbelegen partielle Kennzahlen und versionierte Hinweise für den jeweiligen beobachteten Pipelineinstanzscope. Phasengruppen verwenden die gemessenen Intervalle; Transfergruppen verwenden gemeldete Zeilenzahlen und eine Portrolle aus dem gelieferten Toolbelt-Modell. Überlappende Intervalle sind weder CPU-Zeit noch kritischer Pfad oder Paketlaufzeit. Die Procedure lädt keine Paketdateien und führt keine erneute Modell- oder Lineageanalyse aus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Parameter:'
            + NCHAR(10)
            + N'@Models: nvarchar(max); Default: keiner, Pflichtargument. Erwartet wird das Unicode-JSON-Dokument des bereits geprüften Paketsatzes. Der Helper liest je Paket model.nodes mit id, kind und attributes.portRole für Knoten des Typs PORT sowie model.edges mit id, kind und fromId für Kanten des Typs PIPELINE_PATH. Er ordnet dadurch die Quellportrolle einer bereits korrelierten Modellkante zu. Die Portrollen kommen aus dem Toolbelt-Modell und bilden hier keine geschlossene Eingabewerteliste; ERROR und NO_MATCH lösen jeweils einen Hinweis aus, während fehlende Rollen als UNKNOWN und andere Rollen unverändert in der Zusammenfassung erscheinen. Die öffentliche Procedure prüft Paketmodell und Transportgrenzen einschließlich Dokumentgröße, JSON-Tiefe und doppelter Schlüssel; dies sind keine unabhängigen Vertrauensprüfungen dieser internen Procedure. Auslassen scheitert an der Pflichtsignatur. Bei NULL liefern die JSON-OPENJSON-Joins keine Modellkanten und Ports, während eine Zusammenfassung aus be'
            + N'reits zugeordneten Phasenbelegen weiterhin entstehen kann. Leertext oder ungültiges JSON kann im TRY als Diagnoseeingabefehler erfasst werden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@Bound: bit; Default: keiner, Pflichtargument. Skalarer interner Übergabeflag aus der lokalen Bindungsprüfung des Scopeconsumers. Diagnoseanalyse beginnt nur bei @Bound=1 und ohne PIPELINE_BINDING_UNPROVEN in der bereits vorhandenen Pipeline-Coverage. Bei 0 oder NULL wird die Analyse übersprungen; die Procedure schreibt dennoch Diagnose-Coverage aus den vorhandenen Coverage- und Belegtabellen und kann einen Coveragehinweis erzeugen. Der Flag allein ist kein Beleg und die Procedure prüft weder Handover noch Capturebindung. Auslassen scheitert an der Pflichtsignatur. Die vollständige bit-Wertemenge ist 0 (nicht gebunden) und 1 (vom Aufrufer als gebunden markiert). SQL Server konvertiert numerische Werte ungleich 0 zu 1 und leeren Text zu 0 vor dem Procedure-Eintritt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@Deadline: datetime2(3); Default: keiner, Pflichtargument. Enthält dieselbe absolute UTC-Deadline, die der Scopeconsumer an die Korrelation übergeben hat. Die Procedure prüft sie vor und nach wesentlichen Diagnosephasen; ein erkanntes Überschreiten wird als DIAGNOSTIC_TIME_LIMIT in Diagnose-Coverage dargestellt. NULL unterdrückt die Vergleiche wegen SQL-NULL-Semantik und wird hier nicht als ungültiger Wert abgefangen. Auslassen scheitert an der Pflichtsignatur. Als datetime2(3)-Variable oder konvertierbaren ISO-Zeitpunkt übergeben, beispielsweise 2026-11-06T13:00:00.000; der Wert selbst trägt keine Zeitzone und muss UTC repräsentieren. Leerer Text kann zum Zeitpunkt 1900-01-01 konvertiert werden und ist dann abgelaufen; nicht konvertierbarer Text scheitert vor dem Eintritt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@Limit: int; Default: keiner, Pflichtargument. Enthält das vom Scopeconsumer abgeleitete Zeilenlimit. Der Helper kürzt keine Ergebnis- oder Diagnosezeilen; er setzt OutputTruncated in Diagnose-Coverage, wenn die Anzahl der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen, Hinweise oder Coveragezeilen das Limit überschreitet. Die eigentliche Ausgabe kürzt der Scopeconsumer. Der Helper validiert den Wert nicht: Bei NULL ergibt der Vergleich keinen Treffer und das Flag wird wegen dieses Vergleichs nicht gesetzt; 0 oder negative Werte können bei vorhandenen Zeilen das Flag setzen. Negative Werte sind bei Umgehung der öffentlichen Guard-Prüfung kein gültiger Aufrufvertrag. Auslassen scheitert an der Pflichtsignatur. Als skalaren ganzzahligen int-Wert von -2147483648 bis 2147483647 übergeben; der Scopeconsumer liefert ein positives wirksames Limit. Leerer Text kann vor dem Eintritt nach 0 konvertiert werden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@PipelinePhaseThresholdMs: bigint; Default: NULL. Skalarer Millisekunden-Grenzwert für den Hinweis SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED. NULL deaktiviert diesen Hinweis; ein nicht-NULL-Wert erzeugt ihn, wenn das längste bekannte einzelne Phasenintervall einer Komponentengruppe strikt größer ist als der Grenzwert. Gleichheit genügt nicht. Die interne Procedure selbst akzeptiert auch negative Werte, wenn der öffentliche Scopeconsumer umgangen wird; dann können bekannte nichtnegative Intervalle den Grenzwert überschreiten. Die öffentliche Procedure verwirft negative Werte und gesetzte Werte ohne Diagnoseopt-in. Auslassen verwendet NULL. Leerer Text wird bei erfolgreicher SQL-Typkonvertierung zu bigint regelmäßig als 0 übergeben und aktiviert dann den Vergleich; nicht konvertierbarer Text scheitert bereits bei der Parameterbindung. Der SQL-Typ erlaubt ganze Werte von -9223372036854775808 bis 9223372036854775807; der öffentliche Vertrag beschränkt gesetzte Werte auf den nichtnegativen Ber'
            + N'eich.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ergebnis- und Temp-Vertrag: Die Procedure erzeugt kein Resultset und hat keine OUTPUT-Parameter. Sie liest die vom Scopeconsumer bereitgestellten Temp-Tabellen #InternalSsisExecutionScopes_PipelineCoverage, #InternalSsisExecutionScopes_ComponentPhases, #InternalSsisExecutionScopes_PathTransfers, #InternalSsisExecutionScopes_Packages und #InternalSsisExecutionScopes_Binding und schreibt in #InternalSsisExecutionScopes_PhaseSummary, #InternalSsisExecutionScopes_TransferSummary, #InternalSsisExecutionScopes_PipelineFindings und #InternalSsisExecutionScopes_DiagnosticCoverage. Die Gruppen componentPhaseSummary enthalten je Pipelineinstanz, Komponente und Phasenname ObservedIntervalCount, ValidIntervalCount, UnknownIntervalCount, ObservedIntervalSumMs, LongestIntervalMs, SpanMs, FirstStartTime, LastEndTime, OverlapObserved, RankWithinFlowPhase, EvidencePhaseStatsId und IsPartial. Summen und Rangfolge berücksichtigen gültige zugeordnete Beobachtungen; SpanMs reicht vom frühesten bekannten St'
            + N'art bis zum spätesten bekannten Ende und kann Überlappungen enthalten. pathTransferSummary enthält je Pipelineinstanz und Kante PortRole, ObservedTransferCount, KnownRowCount, UnknownRowCount, ObservedRowsSent, FirstCreatedTime, LastCreatedTime, FirstDataStatsId, PositiveDataStatsId und IsPartial. pipelineFindings enthält RuleId, RuleVersion, Severity, EvidenceLevel, Paket-/Aufruf-/Flow-/Knoten-/Kantenbezug, SourceName, SourceId, ObservedValue, ThresholdMs, PackageSha256, SourceBindingSha256 und IsPartial. pipelineDiagnosticCoverage enthält SourceName, StatusCode, SourceErrorNumber, ObservedRowCount, MappedRowCount, UnassignedRowCount, SummaryRowCount, UnknownValueCount, UnknownRoleCount, LoggingLevel, IsPartial, OutputTruncated und ReasonCode. Die fünf möglichen RuleId-Werte lauten SSIS_PIPELINE_ERROR_OUTPUT_OBSERVED für positive beobachtete Zeilen auf einer ERROR-Ausgabe, SSIS_PIPELINE_NO_MATCH_OBSERVED für positive beobachtete Zeilen auf einer NO_MATCH-Ausgabe, SSIS_PIPELINE_ZERO_OB'
            + N'SERVED_TRANSFER für einen Transfer mit vollständig bekannten Zeilenwerten und Summe null, SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED für ein bekanntes einzelnes Phasenintervall oberhalb des gesetzten Grenzwerts sowie SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED für Diagnosequellen mit eingeschränkter Abdeckung oder unbekannten Werten beziehungsweise Rollen. Hinweise tragen Version 1.0.0 und Severity INFO. Fehlerhinweise sind Evidenzhinweise und keine Aussagen über Ursache oder Auswirkung außerhalb der beobachteten Daten. Der Aufrufer kürzt alle Ergebnisgruppen später und kennzeichnet tatsächliche Ausgabekürzung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Fehlergrenzen: Während der Diagnoseanalyse erfasste Fehler werden durch Löschen der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen und bis dahin erzeugten Hinweise zurückgenommen. Fehlernummer 57920 wird als DIAGNOSTIC_TIME_LIMIT mit gleicher Fehlernummer abgebildet; sonstige abgefangene Fehler erhalten DIAGNOSTIC_INPUT_REJECTED mit ihrer ursprünglichen Fehlernummer. Diagnose-Coverage wird danach aus den Pipeline-Coveragewerten geschrieben und erhält bei Fehlern den jeweiligen Diagnose-Reason-Code. Nach dem CATCH liegen Coverage-Schreiben, Erzeugung des Hinweises SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED, OutputTruncated-Aktualisierung und Wiederherstellung des vorherigen LOCK_TIMEOUT außerhalb der Abfangstrecke und können selbst fehlschlagen. Daher besteht keine universelle Fehler- oder Wiederherstellungszusage und keine atomare Gesamttransaktion.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.InternalSsisPipelineDiagnostics
        RETURN;
    END;

    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@LockTimeoutSql nvarchar(80);
    DECLARE @DiagnosticError int=NULL,@DiagnosticReason varchar(40)=NULL;
    IF @Bound=1 AND NOT EXISTS(SELECT 1 FROM #InternalSsisExecutionScopes_PipelineCoverage WHERE [StatusCode]='PIPELINE_BINDING_UNPROVEN')
    BEGIN TRY
    IF SYSUTCDATETIME() >= @Deadline THROW 57920,N'PIPELINE_DIAGNOSTIC_TIME_LIMIT',1;

    ;WITH [intervals] AS
    (
        SELECT [p].*,
            MAX(CASE WHEN [ObservedDurationMs] IS NOT NULL THEN [EndTime] END) OVER(PARTITION BY [FlowStatisticsId],[ComponentNodeId],[PhaseName] COLLATE Latin1_General_100_BIN2,DATALENGTH([PhaseName])
                ORDER BY [StartTime],[EndTime],[PhaseStatsId] ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS [PriorEnd],
            ROW_NUMBER() OVER(PARTITION BY [FlowStatisticsId],[ComponentNodeId],[PhaseName] COLLATE Latin1_General_100_BIN2,DATALENGTH([PhaseName])
                ORDER BY [ObservedDurationMs] DESC,[PhaseStatsId]) AS [DurationOrder]
        FROM #InternalSsisExecutionScopes_ComponentPhases AS [p]
        WHERE [ComponentNodeId] IS NOT NULL AND [CorrelationStatus]='SCOPED_EXACT_COMPONENT_NAME'
    ), [groups] AS
    (
        SELECT [FlowStatisticsId],[InvocationId],[PackageKey],[FlowNodeId],[ComponentNodeId],[PhaseName] COLLATE Latin1_General_100_BIN2 AS [PhaseName],
            COUNT(*) AS [ObservedIntervalCount],COUNT([ObservedDurationMs]) AS [ValidIntervalCount],
            SUM(CONVERT(decimal(38,0),[ObservedDurationMs])) AS [ObservedIntervalSumMs],
            MAX([ObservedDurationMs]) AS [LongestIntervalMs],
            MIN(CASE WHEN [ObservedDurationMs] IS NOT NULL THEN [StartTime] END) AS [FirstStartTime],
            MAX(CASE WHEN [ObservedDurationMs] IS NOT NULL THEN [EndTime] END) AS [LastEndTime],
            MAX(CASE WHEN [ObservedDurationMs] IS NOT NULL AND [StartTime]<[PriorEnd] THEN 1 ELSE 0 END) AS [OverlapObserved],
            MAX(CASE WHEN [DurationOrder]=1 AND [ObservedDurationMs] IS NOT NULL THEN [PhaseStatsId] END) AS [EvidencePhaseStatsId]
        FROM [intervals]
        GROUP BY [FlowStatisticsId],[InvocationId],[PackageKey],[FlowNodeId],[ComponentNodeId],[PhaseName] COLLATE Latin1_General_100_BIN2,DATALENGTH([PhaseName])
    )
    INSERT #InternalSsisExecutionScopes_PhaseSummary
    SELECT [FlowStatisticsId],[InvocationId],[PackageKey],[FlowNodeId],[ComponentNodeId],[PhaseName],
        [ObservedIntervalCount],[ValidIntervalCount],[ObservedIntervalCount]-[ValidIntervalCount],
        [ObservedIntervalSumMs],[LongestIntervalMs],DATEDIFF_BIG(millisecond,[FirstStartTime],[LastEndTime]),
        [FirstStartTime],[LastEndTime],[OverlapObserved],
        CASE WHEN [LongestIntervalMs] IS NOT NULL THEN DENSE_RANK() OVER(PARTITION BY [FlowStatisticsId],[PhaseName] COLLATE Latin1_General_100_BIN2,DATALENGTH([PhaseName]) ORDER BY [LongestIntervalMs] DESC) END,
        [EvidencePhaseStatsId],1
    FROM [groups];

    IF SYSUTCDATETIME() >= @Deadline THROW 57920,N'PIPELINE_DIAGNOSTIC_TIME_LIMIT',1;
    ;WITH [ports] AS
    (
        SELECT JSON_VALUE([p].[value],'$.packageKey') AS [PackageKey],[n].[NodeId],[n].[PortRole]
        FROM OPENJSON(@Models,'$.packages') AS [p]
        CROSS APPLY OPENJSON([p].[value],'$.model.nodes') WITH
            ([NodeId] varchar(128) '$.id',[Kind] varchar(16) '$.kind',[PortRole] varchar(16) '$.attributes.portRole') AS [n]
        WHERE [n].[Kind]='PORT'
    ), [edges] AS
    (
        SELECT JSON_VALUE([p].[value],'$.packageKey') AS [PackageKey],[e].[EdgeId],[e].[FromId]
        FROM OPENJSON(@Models,'$.packages') AS [p]
        CROSS APPLY OPENJSON([p].[value],'$.model.edges') WITH
            ([EdgeId] varchar(128) '$.id',[Kind] varchar(32) '$.kind',[FromId] varchar(128) '$.fromId') AS [e]
        WHERE [e].[Kind]='PIPELINE_PATH'
    )
    INSERT #InternalSsisExecutionScopes_TransferSummary
    SELECT [r].[FlowStatisticsId],[r].[InvocationId],[r].[PackageKey],[r].[FlowNodeId],[r].[ModelEdgeId],
        COALESCE([p].[PortRole],'UNKNOWN'),COUNT(*),COUNT([r].[RowsSent]),COUNT(*)-COUNT([r].[RowsSent]),
        SUM(CONVERT(decimal(38,0),[r].[RowsSent])),MIN([r].[CreatedTime]),MAX([r].[CreatedTime]),
        MIN([r].[DataStatsId]),MIN(CASE WHEN [r].[RowsSent]>0 THEN [r].[DataStatsId] END),1
    FROM #InternalSsisExecutionScopes_PathTransfers AS [r]
    JOIN [edges] AS [e] ON [e].[PackageKey] COLLATE SQL_Latin1_General_CP1_CS_AS=[r].[PackageKey]
        AND [e].[EdgeId]=[r].[ModelEdgeId]
    LEFT JOIN [ports] AS [p] ON [p].[PackageKey] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[PackageKey] COLLATE SQL_Latin1_General_CP1_CS_AS AND [p].[NodeId]=[e].[FromId]
    WHERE [r].[ModelEdgeId] IS NOT NULL AND [r].[CorrelationStatus]='SCOPED_EXACT_PATH_REFERENCE'
    GROUP BY [r].[FlowStatisticsId],[r].[InvocationId],[r].[PackageKey],[r].[FlowNodeId],[r].[ModelEdgeId],[p].[PortRole];

    INSERT #InternalSsisExecutionScopes_PipelineFindings
    SELECT [rules].[RuleId],'1.0.0','INFO','OBSERVED_SCOPED',[t].[PackageKey],[t].[InvocationId],
        [t].[FlowStatisticsId],[t].[FlowNodeId],NULL,[t].[ModelEdgeId],'pathTransfers',
        CASE WHEN [rules].[RuleId]='SSIS_PIPELINE_ZERO_OBSERVED_TRANSFER' THEN [t].[FirstDataStatsId] ELSE [t].[PositiveDataStatsId] END,
        [t].[ObservedRowsSent],NULL,[p].[PackageSha256],[b].[SourceBindingSha256],1
    FROM #InternalSsisExecutionScopes_TransferSummary AS [t]
    CROSS APPLY(VALUES
        ('SSIS_PIPELINE_ERROR_OUTPUT_OBSERVED',CASE WHEN [t].[PortRole]='ERROR' AND [t].[PositiveDataStatsId] IS NOT NULL THEN 1 ELSE 0 END),
        ('SSIS_PIPELINE_NO_MATCH_OBSERVED',CASE WHEN [t].[PortRole]='NO_MATCH' AND [t].[PositiveDataStatsId] IS NOT NULL THEN 1 ELSE 0 END),
        ('SSIS_PIPELINE_ZERO_OBSERVED_TRANSFER',CASE WHEN [t].[UnknownRowCount]=0 AND [t].[ObservedRowsSent]=0 THEN 1 ELSE 0 END)
    ) AS [rules]([RuleId],[Applies])
    JOIN #InternalSsisExecutionScopes_Packages AS [p] ON [p].[PackageKey]=[t].[PackageKey]
    CROSS JOIN #InternalSsisExecutionScopes_Binding AS [b]
    WHERE [rules].[Applies]=1;

    INSERT #InternalSsisExecutionScopes_PipelineFindings
    SELECT 'SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED','1.0.0','INFO','OBSERVED_SCOPED',
        [s].[PackageKey],[s].[InvocationId],[s].[FlowStatisticsId],[s].[FlowNodeId],[s].[ComponentNodeId],NULL,
        'componentPhases',[s].[EvidencePhaseStatsId],[s].[LongestIntervalMs],@PipelinePhaseThresholdMs,
        [p].[PackageSha256],[b].[SourceBindingSha256],1
    FROM #InternalSsisExecutionScopes_PhaseSummary AS [s]
    JOIN #InternalSsisExecutionScopes_Packages AS [p] ON [p].[PackageKey]=[s].[PackageKey]
    CROSS JOIN #InternalSsisExecutionScopes_Binding AS [b]
    WHERE @PipelinePhaseThresholdMs IS NOT NULL AND [s].[LongestIntervalMs]>@PipelinePhaseThresholdMs;

    IF SYSUTCDATETIME() >= @Deadline THROW 57920,N'PIPELINE_DIAGNOSTIC_TIME_LIMIT',1;
    END TRY
    BEGIN CATCH
        SELECT @DiagnosticError=ERROR_NUMBER(),@DiagnosticReason=CASE WHEN ERROR_NUMBER()=57920 THEN 'DIAGNOSTIC_TIME_LIMIT' ELSE 'DIAGNOSTIC_INPUT_REJECTED' END;
        DELETE #InternalSsisExecutionScopes_PhaseSummary;
        DELETE #InternalSsisExecutionScopes_TransferSummary;
        DELETE #InternalSsisExecutionScopes_PipelineFindings;
    END CATCH;

    INSERT #InternalSsisExecutionScopes_DiagnosticCoverage
    SELECT [c].[SourceName],COALESCE(@DiagnosticReason,[c].[StatusCode]),COALESCE(@DiagnosticError,[c].[SourceErrorNumber]),[c].[ObservedRowCount],
        [c].[MappedRowCount],[c].[UnassignedRowCount],
        CASE WHEN [c].[SourceName]='componentPhases' THEN (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_PhaseSummary)
             ELSE (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_TransferSummary) END,
        CASE WHEN [c].[SourceName]='componentPhases' THEN (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_ComponentPhases WHERE [ComponentNodeId] IS NOT NULL AND [ObservedDurationMs] IS NULL)
             ELSE (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_PathTransfers WHERE [ModelEdgeId] IS NOT NULL AND [RowsSent] IS NULL) END,
        CASE WHEN [c].[SourceName]='pathTransfers' THEN (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_TransferSummary WHERE [PortRole] IN('UNKNOWN') OR [PortRole] IS NULL) ELSE 0 END,
        [c].[LoggingLevel],1,[c].[OutputTruncated],
        CASE WHEN @DiagnosticReason IS NOT NULL THEN @DiagnosticReason WHEN [c].[StatusCode] NOT IN('AVAILABLE','AVAILABLE_EMPTY') THEN 'SOURCE_NOT_AVAILABLE'
             WHEN [c].[ObservedRowCount]=0 THEN 'NO_OBSERVATIONS'
             WHEN [c].[OutputTruncated]=1 THEN 'SOURCE_OUTPUT_TRUNCATED'
             WHEN [c].[UnassignedRowCount]>0 THEN 'UNASSIGNED_OBSERVATIONS'
             ELSE 'OBSERVED_PARTIAL' END
    FROM #InternalSsisExecutionScopes_PipelineCoverage AS [c];

    INSERT #InternalSsisExecutionScopes_PipelineFindings
    SELECT 'SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED','1.0.0','INFO','SOURCE_COVERAGE',NULL,NULL,NULL,NULL,NULL,NULL,
        [SourceName],NULL,NULL,NULL,NULL,[b].[SourceBindingSha256],1
    FROM #InternalSsisExecutionScopes_DiagnosticCoverage AS [c]
    CROSS JOIN #InternalSsisExecutionScopes_Binding AS [b]
    WHERE [c].[ReasonCode]<>'OBSERVED_PARTIAL' OR [c].[UnknownValueCount]>0 OR [c].[UnknownRoleCount]>0;

    UPDATE #InternalSsisExecutionScopes_DiagnosticCoverage SET [OutputTruncated]=CASE
        WHEN [OutputTruncated]=1 OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_PhaseSummary)>@Limit
          OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_TransferSummary)>@Limit
          OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_PipelineFindings)>@Limit
          OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_DiagnosticCoverage)>@Limit THEN 1 ELSE 0 END;
    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;
END;
GO
